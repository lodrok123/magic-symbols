class_name ArbolAnimPj
extends AnimationTree

## A1 (20/10, PLAN_TRES_FRENTES §1) · LA ÚNICA FUENTE DE VERDAD de la animación de un `Pj3D`.
##
## Antes el `AnimationPlayer` se tocaba desde cinco funciones de `Pj3D` (jugar, giro_al_andar, beber, apuntar_clip, el nado) y desde `Jugador3D.una_vez`:
## quien llamaba último ganaba y no había forma de saber en qué estado estaba el personaje. Ahora hay un `AnimationNodeStateMachine` con un estado por
## animación y TODO pasa por `pedir()`; nadie fuera de esta clase llama a `play`/`seek`/`speed_scale` de un AnimationPlayer.
##
## Cómo está montado (medido con el GLB real de la elfa, Godot 4.7):
##   BlendTree = [ StateMachine "SM" ] → [ TimeScale "TS" ] → salida
##   · cada estado de "SM" es un `AnimationNodeAnimation` con `use_custom_timeline`: `start_offset` y `timeline_length` recortan el clip (cast points,
##     beber, el fotograma de apuntado del arquero) y `loop_mode` es PROPIO del estado, así que ya no se toca el recurso `Animation` que comparten todas
##     las copias del mismo GLB.
##   · un solo `TimeScale` después de la máquina: velocidad = `vel_estado` (la de cada reproducción) × `vel_global` (la del mundo/hitstop) o 0 si
##     `retenido` (cast point sostenido, apuntado del arquero). Es lo que antes era `AnimationPlayer.speed_scale` + `custom_speed`.
##   · las transiciones entre estados son de `travel()` (modo ENABLED) con mezcla `MEZCLA_DEFECTO`; se crean al dar de alta un estado (todos con todos).
##
## Los nombres de estado los pone `Pj3D` (idle, andar, correr, nadar, apuntar, lanzar…, golpeado, rodar, beber, muerto…). Aquí viven las REGLAS:
##   · `muerto` solo sale hacia `idle` (reaparecer);
##   · no se entra en `rodar` ni `beber` ni en un lanzar/apuntar estando en `nadar` o `muerto`;
##   · con el grafo REDUCIDO (enemigos de `Combate3D`) solo existen idle, andar, correr, atacar, lanzar, golpeado y muerto.
## Una petición prohibida NO cambia nada: devuelve false, cuenta en `rechazos`, queda en `historial` y emite `rechazado`.

signal estado_cambiado(de: String, a: String)
signal rechazado(de: String, a: String, motivo: String)

const MEZCLA_DEFECTO: float = 0.15
const GRAFO_HEROE: String = "heroe"
const GRAFO_REDUCIDO: String = "reducido"
## Los estados que existen en el grafo reducido de los enemigos (A2). `lanzar*` = cualquier subestado de lanzar.
## `drown` (21/10, diario 231 + 238): el clip «Drowning» de los goblins. Lo pide `Combate3D._animar_ahogo` al hundirse; sin esta entrada el grafo reducido lo
## rechazaba (`motivo_prohibida`) y el goblin caía con la pose de muerte de siempre. El estado se llama como el rol (`Pj3D.estado_de("drown")` = «drown»).
const ESTADOS_REDUCIDO: PackedStringArray = ["idle", "andar", "correr", "atacar", "lanzar", "golpeado", "muerto", "drown", "empujado", "levantarse"]
## `empujado` y `levantarse` (22/10): ser despedido por un empuje (BeHit_FlyUp) y volver a ponerse de pie (Stand_Up1); los pide `Combate3D` (ver `Pj3D._preparar_empujado`).
const ENTRADAS_BLOQUEADAS_AL_NADAR: PackedStringArray = ["rodar", "beber", "apuntar", "lanzar"]
const MAX_HISTORIAL: int = 16

var grafo: String = GRAFO_HEROE
var estado: String = ""                  ## el estado al que se ha pedido ir (el destino); `estado_real()` es el que la máquina tiene ahora
var vel_estado: float = 1.0              ## la velocidad con que se pidió la reproducción actual (VEL_CLIP, vel de `jugar`...)
var rechazos: int = 0
var historial: Array = []                ## [{de, a, ok, motivo}] los últimos MAX_HISTORIAL cambios y rechazos (para la pestaña F5 del lab)
var vel_global: float = 1.0:
	set(v):
		vel_global = v
		_aplicar_escala()
var retenido: bool = false:
	set(v):
		retenido = v
		_aplicar_escala()

var _ap: AnimationPlayer = null
var _sm: AnimationNodeStateMachine = null
var _def: Dictionary = {}                ## estado → {clip, desde, hasta, bucle}
var _pendiente: Dictionary = {}          ## la petición hecha antes de que el árbol pudiera arrancar (el personaje aún no estaba en la escena)
var _viejo: bool = false                 ## true entre `pedir()` y la siguiente actualización del árbol: ahí `posicion()` aún es la del estado anterior


## Monta el árbol sobre el AnimationPlayer `ap` del modelo. Hay que llamarlo con el árbol ya colgado del mismo padre que `ap`.
func montar(ap: AnimationPlayer, p_grafo: String = GRAFO_HEROE) -> void:
	_ap = ap
	grafo = p_grafo
	root_node = get_path_to(ap.get_node(ap.root_node))
	anim_player = get_path_to(ap)
	var bt := AnimationNodeBlendTree.new()
	_sm = AnimationNodeStateMachine.new()
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("SM", _sm, Vector2(0, 0))
	bt.add_node("TS", ts, Vector2(220, 0))
	bt.connect_node("TS", 0, "SM")
	bt.connect_node("output", 0, "TS")
	tree_root = bt
	# El árbol manda; el reproductor propio se queda quieto (si no, los dos escribirían las mismas pistas).
	ap.stop()
	ap.active = false
	active = true


func _process(_delta: float) -> void:
	# (El proceso interno del AnimationTree ya se ejecutó este fotograma: lo pedido antes de él ya está aplicado.)
	_viejo = false
	if not _pendiente.is_empty() and _playback() != null:
		var p: Dictionary = _pendiente
		_pendiente = {}
		_viajar(String(p["a"]), float(p["mezcla"]), bool(p["reiniciar"]))
		_viejo = true


## Avanza el árbol a mano `delta` s (las pruebas sin ventana; en juego lo hace el motor cada fotograma).
func avanzar(delta: float) -> void:
	if not _pendiente.is_empty() and _playback() != null:
		var p: Dictionary = _pendiente
		_pendiente = {}
		_viajar(String(p["a"]), float(p["mezcla"]), bool(p["reiniciar"]))
	advance(delta)
	_viejo = false


## ¿Lo que dicen `posicion()`/`largo()` es ya del estado pedido? (false en el mismo fotograma de `pedir`, y mientras no haya arrancado el árbol.)
func listo() -> bool:
	return _pendiente.is_empty() and not _viejo and _playback() != null


func _playback() -> AnimationNodeStateMachinePlayback:
	return get("parameters/SM/playback") as AnimationNodeStateMachinePlayback if _sm != null else null


## Pide el estado `p_estado`, que reproduce `clip`. Opciones: `desde`/`hasta` (s del clip; 0 = entero), `bucle` (Animation.LoopMode, por defecto
## LOOP_LINEAR), `vel` (1), `mezcla` (MEZCLA_DEFECTO), `reiniciar` (true = empieza de cero aunque ya esté en ese estado), `retenido` (false).
## Devuelve false si la regla lo prohíbe (no cambia nada).
func pedir(p_estado: String, clip: String, o: Dictionary = {}) -> bool:
	if _ap == null or p_estado == "" or not _ap.has_animation(clip):
		return false
	var motivo: String = motivo_prohibida(estado, p_estado)
	if motivo != "":
		_anotar(estado, p_estado, false, motivo)
		rechazos += 1
		rechazado.emit(estado, p_estado, motivo)
		return false
	var largo: float = _ap.get_animation(clip).length
	var desde: float = clampf(float(o.get("desde", 0.0)), 0.0, maxf(largo - 0.001, 0.0))
	var hasta: float = float(o.get("hasta", 0.0))
	if hasta <= 0.0 or hasta > largo:
		hasta = largo
	hasta = maxf(hasta, desde + 0.001)
	_alta(p_estado, clip, desde, hasta, int(o.get("bucle", Animation.LOOP_LINEAR)))
	var anterior: String = estado
	estado = p_estado
	_viejo = true
	vel_estado = float(o.get("vel", 1.0))
	retenido = bool(o.get("retenido", false))                  # (recalcula la escala)
	_anotar(anterior, p_estado, true, "")
	if _playback() == null:
		_pendiente = {"a": p_estado, "mezcla": float(o.get("mezcla", MEZCLA_DEFECTO)), "reiniciar": true}
	else:
		_viajar(p_estado, float(o.get("mezcla", MEZCLA_DEFECTO)), bool(o.get("reiniciar", false)) or anterior == p_estado)
	# Se aplica YA (advance 0): el estado nuevo arranca en su segundo 0 en este mismo fotograma, sin perder uno por el camino. Así `posicion()` es la
	# del estado pedido y el instante de un cast point sale cuando toca (con el AnimationPlayer era igual de inmediato).
	# (Dos veces: con `travel` el primer paso solo hace el cambio y el segundo coloca el estado en su segundo 0; medido, si no se pierde un fotograma.)
	if _pendiente.is_empty() and is_inside_tree() and active:
		advance(0.0)
		advance(0.0)
		_viejo = false
	if anterior != p_estado:
		estado_cambiado.emit(anterior, p_estado)
	return true


## ¿Por qué NO se puede ir de `de` a `a`? "" si se puede. Es la tabla de reglas del grafo (la usa también la prueba).
func motivo_prohibida(de: String, a: String) -> String:
	if grafo == GRAFO_REDUCIDO and not _en_reducido(a):
		return "«%s» no está en el grafo reducido de los enemigos" % a
	if de == "muerto" and a != "idle" and a != "muerto":
		return "desde «muerto» solo se sale a «idle» (reaparecer)"
	if de == "nadar" or de == "muerto":
		for e in ENTRADAS_BLOQUEADAS_AL_NADAR:
			if a == e or a.begins_with(e + "_"):
				return "no se entra en «%s» estando en «%s»" % [a, de]
	return ""


func _en_reducido(a: String) -> bool:
	for e in ESTADOS_REDUCIDO:
		if a == e or a.begins_with(e + "_"):
			return true
	return false


## Da de alta (o actualiza) el estado: su clip, el recorte y el bucle. Y las transiciones con todos los demás.
func _alta(nombre: String, clip: String, desde: float, hasta: float, bucle: int) -> void:
	var nodo: AnimationNodeAnimation = null
	if _sm.has_node(nombre):
		nodo = _sm.get_node(nombre) as AnimationNodeAnimation
	else:
		nodo = AnimationNodeAnimation.new()
		nodo.use_custom_timeline = true
		nodo.stretch_time_scale = false
		_sm.add_node(nombre, nodo)
		for otro in _def:
			_transicion(otro, nombre)
			_transicion(nombre, otro)
	var d: Dictionary = {"clip": clip, "desde": desde, "hasta": hasta, "bucle": bucle}
	if _def.get(nombre, {}) != d:
		nodo.animation = StringName(clip)
		nodo.start_offset = desde
		nodo.timeline_length = hasta - desde
		nodo.loop_mode = bucle as Animation.LoopMode
		_def[nombre] = d


func _transicion(de: String, a: String) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = MEZCLA_DEFECTO
	t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	_sm.add_transition(de, a, t)


func _viajar(destino: String, mezcla: float, reiniciar: bool) -> void:
	var pb: AnimationNodeStateMachinePlayback = _playback()
	if pb == null:
		return
	if reiniciar or not pb.is_playing() or String(pb.get_current_node()) in ["", "Start", "End"]:
		pb.start(destino, true)
		return
	# La mezcla se mide en segundos REALES: el TimeScale de después de la máquina también acelera el fundido, así que se alarga lo mismo
	# (a 1,6× un fundido de 0,15 s duraba 0,09 s y el lanzar entraba en pose de golpe).
	var xfade: float = mezcla * clampf(vel_estado * vel_global, 0.05, 10.0)
	for i in range(_sm.get_transition_count()):
		if _sm.get_transition_to(i) == StringName(destino):
			_sm.get_transition(i).xfade_time = xfade
	# Un `travel` pedido en mitad de un fundido espera a que ACABE el fundido (medido: pedir `run` a los 0 s de `walk` lo aplica a los 0,15 s). Con la
	# velocidad a 0 (hitstop, pose retenida) ese fundido no acaba nunca: ahí se corta en seco para que la petición no se pierda.
	if vel_estado * vel_global <= 0.05 and String(pb.get_fading_from_node()) != "":
		pb.start(destino, true)
		return
	pb.travel(destino)


func _aplicar_escala() -> void:
	if tree_root != null:
		set("parameters/TS/scale", 0.0 if retenido else vel_estado * vel_global)


func _anotar(de: String, a: String, ok: bool, motivo: String) -> void:
	historial.append({"de": de, "a": a, "ok": ok, "motivo": motivo})
	if historial.size() > MAX_HISTORIAL:
		historial.pop_front()


## --- Lectura ---

## El estado en que está la máquina de verdad ahora (tras el último `advance`/fotograma). "" si aún no arrancó.
func estado_real() -> String:
	var pb: AnimationNodeStateMachinePlayback = _playback()
	return String(pb.get_current_node()) if pb != null else ""


## Segundos recorridos del recorte del estado actual (0 … `largo()`), medidos en tiempo de clip (ya con la velocidad aplicada).
func posicion() -> float:
	var pb: AnimationNodeStateMachinePlayback = _playback()
	return pb.get_current_play_position() if pb != null and listo() else 0.0


func largo() -> float:
	var pb: AnimationNodeStateMachinePlayback = _playback()
	return pb.get_current_length() if pb != null and listo() else 0.0


## ¿Un estado sin bucle ya ha llegado a su último fotograma? (se queda ahí: muerte, golpe, disparo)
func terminado() -> bool:
	var d: Dictionary = _def.get(estado, {})
	if d.is_empty() or int(d["bucle"]) != Animation.LOOP_NONE:
		return false
	return posicion() >= largo() - 0.001


func clip_actual() -> String:
	return String((_def.get(estado, {}) as Dictionary).get("clip", ""))


func estados() -> PackedStringArray:
	return PackedStringArray(_def.keys())


func definicion(nombre: String) -> Dictionary:
	return (_def.get(nombre, {}) as Dictionary).duplicate()
