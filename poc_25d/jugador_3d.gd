class_name Jugador3D
extends Node3D

## EL JUGADOR DEL TEST 3 (4.3 jugador mínimo, 4.4 altura, 4.4b agua). Dueño: Juego.
##
## No es un modelo nuevo: gobierna al `Pj3D` que PruebaTest2 ya crea (`_jugador`) y le quita el control. Ese nodo sigue
## siendo del Pipeline (el modelo, la escala, la luz); aquí vive lo que el Juego decide: moverse por NIVELES de casilla,
## saltar, nadar, la vida, la muerte y el modo apuntar. Su `position` es la de los pies y se copia a `pj` cada fotograma;
## si algo externo mueve `pj.position` (PruebaTest2.ir_a) se adopta la nueva posición.
##
## Lo monta una sola línea al final de PruebaTest2._ready():   Jugador3D.montar(self)
## (y PruebaTest2 deja de mover al jugador con `externo = true`: ver el diario del 6/10).
##
## ALTURA (4.4). Un nivel = ALTO_NIVEL (un bloque). Se sube a una casilla un nivel más alta SALTANDO; no se puede
## estar a más de MAX_NIVELES_SUBIBLES niveles. Caer no hace daño. Lo que dice cuántos niveles tiene cada casilla es
## Lanzador3D.alturas (tierra apilada, columnas de barrera + levitación, cornisas del nivel).
##
## AGUA (4.4b). Si el suelo bajo los pies pasa a ser agua (se derrite el hielo, o se pisa agua) el jugador cae y pasa a
## `nadando`: velocidad x0,4, sin lanzar ni saltar, clip swim_forward (si el modelo no lo tiene, walk), sin daño. Sale
## al tocar una casilla de suelo llano.

const MAX_NIVELES_SUBIBLES: int = 1
const GRAVEDAD: float = 22.0
const VEL_SALTO: float = 8.4
const TOLERANCIA_SUELO: float = 0.55        ## desnivel que se camina sin saltar (de puente a suelo, escalón)
const TOLERANCIA_AIRE: float = 0.35         ## lo que una casilla puede estar por encima de tus pies en el aire
const MULT_NADO: float = 0.4
const HUNDIDO: float = 0.35                 ## 6.8: los pies quedan a ALTO_AGUA - 0,35 (flota en la superficie)
const INVULNERABLE: float = 0.7
const TIEMPO_REAPARECER: float = 2.2
const T_GOLPE: float = 0.35
const T_LANZAR: float = 0.9
## --- 6.6 Voltereta: ≤ 1 casilla, colisiona paso a paso, sin daño mientras dura, reutilización larga ---
const TIEMPO_VOLTERETA: float = 4.0          ## segundos hasta poder repetirla
const DIST_VOLTERETA: float = 1.0            ## casillas
## --- 6.7 Beber poción: bloqueado mientras bebe; cura al terminar; un golpe la interrumpe ---
const T_BEBER: float = 1.5
const CURA_POCION: float = 40.0

signal murio
signal reaparecio
signal nado_cambiado(nadando: bool)
signal vida_cambiada(vida: float, maxima: float)

var pj: Pj3D = null
var mundo: Node3D = null
var lanz: Lanzador3D = null

var vida: float = 100.0
var muerto: bool = false
var nadando: bool = false
var en_suelo: bool = true
var bloqueado: bool = false
var vy: float = 0.0
var puntos_inicio: Vector3 = Vector3.ZERO

var _mirada: Vector3 = Vector3(0, 0, 1)
var _empuje: Vector3 = Vector3.ZERO
var _t_lanzar: float = 0.0
var _lanzando: bool = false
var _t_golpe: float = 0.0
var _t_inv: float = 0.0
var _t_muerte: float = 0.0
var _ultima: Vector3 = Vector3.ZERO
var _salto_antes: bool = false
var _vel_andar: float = 1.6
var _vel_correr: float = 3.0
var _hud_barra: ColorRect = null
var _hud_marco: ColorRect = null
var _hud_texto: Label = null
var caidas_al_agua: int = 0
var saltos: int = 0
var _t_roll: float = 0.0                     ## lo que queda de voltereta (0 = no ruedas)
var _roll_dir: Vector3 = Vector3.ZERO
var _roll_vel: float = 0.0
var _roll_cd: float = 0.0                    ## reutilización
var _roll_previa: bool = false
var _t_beber: float = 0.0
var _beber_previa: bool = false
var _f8_previa: bool = false


## Lo monta todo: Lanzador3D, Jugador3D, los goblins con Combate3D, las mediciones y la vida en pantalla.
## Devuelve null si el mundo no tiene jugador.
static func montar(p_mundo: Node3D) -> Jugador3D:
	var modelo: Pj3D = p_mundo.get("_jugador")
	if modelo == null:
		push_warning("Jugador3D.montar: el mundo no tiene jugador (_jugador)")
		return null
	Lanzador3D.configurar(p_mundo)
	var j := Jugador3D.new()
	j.name = "Jugador3D"
	j.mundo = p_mundo
	j.pj = modelo
	j.position = modelo.position
	j.puntos_inicio = modelo.position
	j._ultima = modelo.position
	var k: Dictionary = p_mundo.get_script().get_script_constant_map()
	j._vel_andar = float(k.get("VEL_ANDAR", 1.6))
	j._vel_correr = float(k.get("VEL_CORRER", 3.0))
	j.vida = Estado.i().vida_max
	p_mundo.add_child(j)
	p_mundo.set("externo", true)

	var l := Lanzador3D.new()
	l.name = "Lanzador3D"
	l.mundo = p_mundo
	l.fx = p_mundo.get("_fx")
	l.jugador = j
	l.camara = p_mundo.get("_camara")
	j.lanz = l
	p_mundo.add_child(l)
	l.construir_interfaz()
	if l.fx != null:
		# H4: el impacto pasa por el Lanzador, que descarta agua/hielo sobre casillas elevadas y luego llama a
		# PruebaTest2._al_impactar y a su propio al_impactar (el orden de siempre). Se sustituye la conexion del mundo.
		var directo := Callable(p_mundo, "_al_impactar")
		if l.fx.impacto.is_connected(directo):
			l.fx.impacto.disconnect(directo)
			l.fx.impacto.connect(l.impacto_filtrado)
		else:
			l.fx.impacto.connect(l.al_impactar)     # el mundo no la habia conectado: no se duplica nada

	# Los objetos del Pipeline (Reactivo3D) nacen sin capa (layer 0) hasta que existe el Lanzador: se les da CAPA_REACTIVO.
	for n in p_mundo.get_tree().get_nodes_in_group("reactivo3d"):
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer |= Lanzador3D.CAPA_REACTIVO
	Lanzador3D.colocar_barreras(p_mundo)
	Lanzador3D.calcular_huellas(p_mundo)
	PlayLog.nueva_partida()
	PlayLog3D.montar(p_mundo, l)
	for g in (p_mundo.get("_goblins") as Array):
		Combate3D.equipar(g as Pj3D, p_mundo, j, l)
	j._construir_hud()
	return j


## =====================================================================================================
##  Lo que pregunta Lanzador3D
## =====================================================================================================

func puede_lanzar() -> bool:
	return not muerto and not nadando and en_suelo and mundo.get("_velo") == null and _t_roll <= 0.0 and _t_beber <= 0.0


func bloquear(b: bool) -> void:
	bloqueado = b
	_empuje = Vector3.ZERO


## Entra en el modo apuntar: la elfa pone el clip de lanzar de la forma y las motas del elemento en la mano (Pj3D.lanzar,
## del Pipeline) y sigue animada a velocidad normal aunque el mundo vaya al 70 %.
func apuntar_lanzar(elemento: String, _forma: String, ralentizado: float) -> void:
	# 6.2: mientras se apunta se SOSTIENE readandwrite en bucle (una forma vacía no está en ANIM_CAST: Pj3D usa "leer") y
	# las motas del elemento en la mano. El clip de la forma (`cast`) sale solo al soltar (lanzar_clip).
	pj.apuntar()                                   # 6.11: libro en las manos + readandwrite sostenido
	pj.set_velocidad_animacion(1.0 / maxf(ralentizado, 0.1))


## Sale del modo apuntar (al soltar o al cancelar): vuelve a idle. Si se soltó, lanzar_clip vuelve a poner el clip.
func terminar_apuntar() -> void:
	pj.set_velocidad_animacion(1.0)
	pj.soltar_lanzar()
	_lanzando = false


func mirar_hacia(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	_mirada = d.normalized()
	pj.mirar(_mirada, 0.08)


func mirada() -> Vector3:
	return _mirada


## Al soltar: el clip de la forma (Pj3D.ANIM_CAST, o readandwrite) y las motas, lo que dure el clip (entre 0,5 y 1,4 s).
func lanzar_clip(elemento: String, forma: String) -> void:
	pj.mirar(_mirada, 1.0)
	pj.lanzar(forma, elemento)                 # pone las motas del elemento y el clip de la forma (en bucle)
	# 6.2: el clip de la forma se reproduce UNA vez entera y el jugador espera a que acabe antes de volver a idle.
	var rol: String = String(Pj3D.ANIM_CAST.get(forma, "leer"))
	if pj.duracion(rol) <= 0.0:
		rol = "leer"
	pj.animacion_actual = ""
	pj.jugar(rol, true)
	var dur: float = pj.duracion(rol)
	_t_lanzar = clampf(dur if dur > 0.0 else T_LANZAR, 0.4, 2.5)
	_lanzando = true
	PlayLog.event("cast_clip", {"forma": forma, "clip": rol, "duracion": snappedf(_t_lanzar, 0.01)})


func y_pies_actual() -> float:
	var c: Vector2i = Lanzador3D.celda_de(position)
	return Lanzador3D.alto_agua if nadando else Lanzador3D.y_pies(c)


## ¿Está el jugador en esa casilla? Impide construir tierra debajo de él.
func ocupa(c: Vector2i) -> bool:
	return Lanzador3D.celda_de(position) == c


func nivel_actual() -> int:
	return Lanzador3D.altura_en(Lanzador3D.celda_de(position))


## =====================================================================================================
##  Vida
## =====================================================================================================

func recibir_dano(cantidad: float, desde: Vector3 = Vector3.ZERO) -> void:
	if muerto or _t_inv > 0.0 or cantidad <= 0.0:
		return
	if lanz != null and lanz.absorber_golpe(cantidad, desde):
		return                                   # la barrera cúpula lo ha parado (6.3)
	if _t_beber > 0.0:
		_cancelar_beber()                       # 6.7: si te golpean mientras bebes, no curas
	vida = maxf(0.0, vida - cantidad)
	_t_inv = INVULNERABLE
	_t_golpe = T_GOLPE
	Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(round(cantidad))), Color(1, 0.4, 0.35))
	var d: Vector3 = position - desde
	d.y = 0.0
	if desde != Vector3.ZERO and d.length() > 0.01:
		push(d.normalized(), 4.5)
	PlayLog.event("dano_jugador", {"cantidad": cantidad, "vida": vida})
	vida_cambiada.emit(vida, Estado.i().vida_max)
	if vida <= 0.0:
		_morir()
	else:
		pj.animacion_actual = ""
		pj.jugar("hit")


func curar(cantidad: float) -> void:
	vida = minf(Estado.i().vida_max, vida + cantidad)
	vida_cambiada.emit(vida, Estado.i().vida_max)


## Contrato push: viento y atracción (y los golpes de los goblins) empujan a quien lo implemente.
## `fuerza` llega en unidades del 2D (2600 el viento): se baja a metros por segundo del 3D.
func push(direccion: Vector3, fuerza: float) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() < 0.01 or muerto:
		return
	var f: float = fuerza * 0.0036 if fuerza > 100.0 else fuerza
	_empuje += d.normalized() * f


func _morir() -> void:
	_t_roll = 0.0
	_t_beber = 0.0
	muerto = true
	nadando = false
	_lanzando = false
	pj.soltar_lanzar()
	_t_muerte = TIEMPO_REAPARECER
	if lanz != null and lanz.modo_lanzar:
		lanz.call("_cancelar_modo")
	Jugador3D.una_vez(pj, "death")
	PlayLog.event("muerte", {"celda": [Lanzador3D.celda_de(position).x, Lanzador3D.celda_de(position).y]})
	murio.emit()
	if lanz != null:
		lanz.avisar("Has caído", Color(1, 0.5, 0.45))


func reaparecer() -> void:
	muerto = false
	nadando = false
	vida = Estado.i().vida_max
	position = puntos_inicio
	vy = 0.0
	en_suelo = true
	_empuje = Vector3.ZERO
	_t_inv = 1.2
	pj.animacion_actual = ""
	pj.jugar("idle")
	PlayLog.event("reaparece")
	vida_cambiada.emit(vida, Estado.i().vida_max)
	reaparecio.emit()
	if lanz != null:
		lanz.avisar("Reapareces", Color(0.7, 1, 0.8))


## Reproduce un clip y lo deja en su último fotograma (los clips de Pj3D son bucles). No toca el recurso de animación,
## que comparten todas las copias del personaje: solo pausa SU AnimationPlayer.
static func una_vez(pj_: Pj3D, nombre: String) -> void:
	pj_.animacion_actual = ""
	pj_.jugar(nombre)
	if pj_.animacion_actual != nombre:
		return
	var ap: AnimationPlayer = pj_.get("_ap")
	if ap == null or not ap.is_inside_tree():
		return
	var clip: String = ap.current_animation
	if clip == "" or not ap.has_animation(clip):
		return
	var largo: float = ap.get_animation(clip).length / maxf(ap.speed_scale, 0.1)
	ap.get_tree().create_timer(maxf(largo - 0.05, 0.05), false).timeout.connect(
		Jugador3D._congelar_si.bind(weakref(pj_), weakref(ap), nombre))


static func _congelar_si(modelo: WeakRef, reproductor: WeakRef, nombre: String) -> void:
	var m: Pj3D = modelo.get_ref() as Pj3D
	var ap: AnimationPlayer = reproductor.get_ref() as AnimationPlayer
	if m != null and ap != null and m.animacion_actual == nombre:
		ap.pause()


## =====================================================================================================
##  Movimiento por niveles
## =====================================================================================================

func _process(delta: float) -> void:
	if mundo == null or pj == null or not is_instance_valid(pj):
		return
	if pj.position.distance_to(_ultima) > 0.05:
		position = pj.position              # lo han movido desde fuera (ir_a)
		vy = 0.0
	_t_lanzar = maxf(0.0, _t_lanzar - delta)
	if _lanzando and _t_lanzar <= 0.0:
		_lanzando = false
		pj.soltar_lanzar()                  # quita las motas y vuelve a idle
	_t_golpe = maxf(0.0, _t_golpe - delta)
	_t_inv = maxf(0.0, _t_inv - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	if _t_beber > 0.0:
		_t_beber = maxf(0.0, _t_beber - delta)
		if _t_beber <= 0.0:
			_terminar_beber()
	if _t_roll > 0.0:
		_t_roll = maxf(0.0, _t_roll - delta)

	if muerto:
		_t_muerte -= delta
		if _t_muerte <= 0.0:
			reaparecer()
		_sincronizar()
		_actualizar_hud()
		return

	var entrada := Vector2.ZERO
	var libre: bool = not bloqueado and mundo.get("_velo") == null and not get_tree().paused \
			and not (lanz != null and lanz.libro_abierto())     # con el libro abierto el tiempo corre, pero tú estás escribiendo
	if libre:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			entrada.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			entrada.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			entrada.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			entrada.y += 1.0
	var correr: bool = libre and Input.is_key_pressed(KEY_SHIFT)
	var salto: bool = libre and Input.is_key_pressed(KEY_SPACE)
	var mov := Vector3(entrada.x, 0.0, entrada.y).normalized()
	_gestionar_acciones(libre, mov)
	var vel: float = (_vel_correr if correr else _vel_andar) * (MULT_NADO if nadando else 1.0)
	if _t_golpe > 0.0 or _t_beber > 0.0 or _lanzando:
		mov = Vector3.ZERO           # el golpe te frena; beber y el clip de lanzar (6.2b) te dejan quieto hasta que acaban
	var paso: Vector3 = mov * vel * delta + _empuje * delta
	if _t_roll > 0.0:
		mov = Vector3.ZERO
		paso = _roll_dir * _roll_vel * delta       # voltereta: sustituye al andar
	_empuje = _empuje.lerp(Vector3.ZERO, clampf(7.0 * delta, 0.0, 1.0))
	if paso.length() > 0.0001:
		var antes: Vector3 = position
		_mover_con_choque(paso)
		if _t_roll > 0.0 and position.distance_to(antes) < 0.0001:
			_t_roll = 0.0                           # choca con algo: la voltereta se acaba ahí
	if mov != Vector3.ZERO:
		_mirada = mov
		pj.mirar(mov, delta)
		if mundo.has_method("marcar_estado") and not nadando:
			mundo.call("marcar_estado", Lanzador3D.celda_de(position), 3, 0.35)

	_vertical(delta, salto)
	_animar(mov, correr)
	_sincronizar()
	_actualizar_hud()


## Intenta el paso entero y, si no cabe, cada eje por separado (para deslizar por las paredes).
## 6.6 y 6.7: Ctrl = voltereta, Q = beber. Se disparan al PULSAR (no mientras se mantiene).
func _gestionar_acciones(libre: bool, mov: Vector3) -> void:
	var ctrl: bool = libre and Input.is_key_pressed(KEY_CTRL)
	var q: bool = libre and Input.is_key_pressed(KEY_Q)
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or (lanz != null and lanz.modo_lanzar)
	if ctrl and not _roll_previa and _roll_cd <= 0.0 and _t_roll <= 0.0 and _t_beber <= 0.0 \
			and not ocupado and not nadando and en_suelo:
		_iniciar_voltereta(mov)
	if q and not _beber_previa and _t_beber <= 0.0 and _t_roll <= 0.0 and not ocupado and not nadando \
			and en_suelo and vida < Estado.i().vida_max and Estado.i().cuenta("pocion") > 0:
		_iniciar_beber()
	# F8: invoca un elemental de bosque 6 u por delante (banco de pruebas; los niveles lo traerán con su marcador)
	var f8: bool = libre and Input.is_key_pressed(KEY_F8)
	if f8 and not _f8_previa and lanz != null:
		var m: Vector3 = _mirada.normalized()
		var destino: Vector3 = position + m * 6.0
		var cc: Vector2i = Lanzador3D.celda_de(destino)
		if Lanzador3D.en_mapa(cc) and not Lanzador3D.es_agua(cc) and not Lanzador3D.bloqueada(cc):
			destino.y = Lanzador3D.y_pies(cc)
			Combate3D.invocar_elemental(mundo, self, lanz, destino)
		else:
			lanz.avisar("No cabe un elemental ahí delante", Color(1, 0.7, 0.5))
	_f8_previa = f8
	_roll_previa = ctrl
	_beber_previa = q


func _iniciar_voltereta(mov: Vector3) -> void:
	_roll_dir = mov if mov != Vector3.ZERO else _mirada
	_roll_dir = Vector3(_roll_dir.x, 0.0, _roll_dir.z).normalized()
	var dur: float = clampf(pj.duracion("roll"), 0.35, 1.0) if pj.duracion("roll") > 0.0 else 0.6
	_t_roll = dur
	_roll_vel = DIST_VOLTERETA * Lanzador3D.casilla / dur
	_roll_cd = TIEMPO_VOLTERETA
	_t_inv = maxf(_t_inv, dur)                     # sin daño por contacto mientras dura
	_mirada = _roll_dir
	pj.mirar(_roll_dir, 1.0)
	pj.rodar()                                     # 6.12: roll sin desplazamiento de cadera (lo movemos nosotros)
	PlayLog.event("voltereta", {"dir": [_roll_dir.x, _roll_dir.z], "dur": dur})


func _iniciar_beber() -> void:
	_t_beber = T_BEBER
	if pj.beber(T_BEBER) <= 0.0:                   # Pipeline: stand_drink recortado + poción en la mano
		pj.jugar("drink", true)                    # sin clip: al menos que dure lo mismo
	PlayLog.event("beber_inicio", {"pociones": Estado.i().cuenta("pocion")})


func _terminar_beber() -> void:
	if pj.has_method("desequipar"):
		pj.call("desequipar")
	if Estado.i().quitar("pocion"):
		curar(CURA_POCION)
		Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), "+%d" % int(CURA_POCION), Color(0.5, 1.0, 0.55))
		PlayLog.event("beber_fin", {"vida": vida})
	pj.animacion_actual = ""


func _cancelar_beber() -> void:
	_t_beber = 0.0
	if pj.has_method("desequipar"):
		pj.call("desequipar")
	pj.animacion_actual = ""
	PlayLog.event("beber_interrumpido", {})


func _mover_con_choque(paso: Vector3) -> void:
	for v in [paso, Vector3(paso.x, 0.0, 0.0), Vector3(0.0, 0.0, paso.z)]:
		var destino: Vector3 = position + (v as Vector3)
		if (v as Vector3).length() > 0.0001 and _puede_estar(destino):
			position.x = destino.x
			position.z = destino.z
			return


## ¿Cabe el jugador (de pie, a su altura actual) en esa posición?
func _puede_estar(p: Vector3) -> bool:
	var c: Vector2i = Lanzador3D.celda_de(p)
	var actual: Vector2i = Lanzador3D.celda_de(position)
	var parcial: bool = Lanzador3D.es_parcial(c)
	if c == actual:
		if parcial and Lanzador3D.choca_huella(c, p) and not Lanzador3D.choca_huella(c, position):
			return false                   # dentro de una casilla bloqueada solo se roza lo que no es el objeto
		return Lanzador3D.en_mapa(c)
	if parcial and Lanzador3D.choca_huella(c, p):
		return false
	var nivel: int = Lanzador3D.altura_en(actual)
	if not Lanzador3D.pisable(c, nivel, true, MAX_NIVELES_SUBIBLES, true, parcial):
		return false
	if nadando:
		return Lanzador3D.altura_en(c) == 0          # del agua solo se sale a suelo llano
	var y_dest: float = Lanzador3D.y_pies(c)
	var tolerancia: float = TOLERANCIA_SUELO if en_suelo else TOLERANCIA_AIRE
	return y_dest <= position.y + tolerancia


func _vertical(delta: float, salto: bool) -> void:
	var c: Vector2i = Lanzador3D.celda_de(position)
	var agua: bool = Lanzador3D.es_agua(c)

	if nadando:
		if not agua:
			_cambiar_nado(false)                       # tocó suelo, puente o hielo: sale
			position.y = Lanzador3D.y_pies(c)
		else:
			position.y = move_toward(position.y, Lanzador3D.alto_agua - HUNDIDO, 3.0 * delta)
			vy = 0.0
			en_suelo = true
			_salto_antes = salto
			return

	var suelo: float = Lanzador3D.y_pies(c)
	if en_suelo:
		if position.y > suelo + TOLERANCIA_SUELO:
			en_suelo = false                           # se acabó el suelo (bloque caducado): cae
			vy = 0.0
		else:
			position.y = move_toward(position.y, suelo, 9.0 * delta)
			if salto and not _salto_antes and absf(position.y - suelo) < 0.05:
				vy = VEL_SALTO
				en_suelo = false
				saltos += 1
	if not en_suelo:
		vy -= GRAVEDAD * delta
		position.y += vy * delta
		if position.y <= suelo and vy <= 0.0:
			position.y = suelo
			vy = 0.0
			en_suelo = true
			if agua:
				_cambiar_nado(true)
	_salto_antes = salto
	# Por si algo ha cambiado el suelo justo debajo (el hielo se derrite bajo los pies ya apoyados)
	if en_suelo and agua and not nadando and position.y <= Lanzador3D.alto_agua + 0.3:
		_cambiar_nado(true)


func _cambiar_nado(n: bool) -> void:
	if nadando == n:
		return
	nadando = n
	if n:
		caidas_al_agua += 1
		PlayLog.event("nada", {"celda": [Lanzador3D.celda_de(position).x, Lanzador3D.celda_de(position).y]})
		if lanz != null:
			lanz.avisar("Nadas: lento y sin lanzar", Color(0.6, 0.85, 1.0))
	else:
		PlayLog.event("sale_del_agua")
	nado_cambiado.emit(n)


func _animar(mov: Vector3, correr: bool) -> void:
	if _t_roll > 0.0 or _t_beber > 0.0:
		return                                         # el clip de voltereta / beber ya está sonando
	if _t_lanzar > 0.0 or _t_golpe > 0.0 or (lanz != null and lanz.modo_lanzar):
		return
	if nadando:
		pj.jugar("swim")                               # swim_forward (rol "swim" de Pj3D); si no existe, walk
		if pj.animacion_actual != "swim":
			pj.jugar("walk")
		pj.set_velocidad_animacion(1.0 if mov != Vector3.ZERO else 0.4)
		return
	pj.set_velocidad_animacion(1.0)
	if not en_suelo:
		return                                         # en el aire se queda con la pose que tenía
	if mov == Vector3.ZERO:
		pj.jugar("idle")
	else:
		pj.jugar("run" if correr else "walk")


func _sincronizar() -> void:
	pj.position = position
	_ultima = position
	if _t_inv > 0.0 and not muerto and _t_roll <= 0.0:
		pj.visible = int(_t_inv * 14.0) % 2 == 0       # parpadea mientras es invulnerable
	else:
		pj.visible = true


## =====================================================================================================
##  Vida en pantalla
## =====================================================================================================

func _construir_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	_hud_marco = ColorRect.new()
	_hud_marco.color = Color(0, 0, 0, 0.7)
	_hud_marco.size = Vector2(244, 20)
	_hud_marco.position = Vector2(14, 0)
	_hud_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_hud_marco)
	_hud_marco.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_marco.offset_left = 14.0
	_hud_marco.offset_top = -36.0
	_hud_marco.offset_right = 258.0
	_hud_marco.offset_bottom = -16.0
	_hud_barra = ColorRect.new()
	_hud_barra.color = Color(0.35, 0.85, 0.4)
	_hud_barra.position = Vector2(2, 2)
	_hud_barra.size = Vector2(240, 16)
	_hud_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_marco.add_child(_hud_barra)
	_hud_texto = Label.new()
	_hud_texto.add_theme_font_size_override("font_size", 14)
	_hud_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_texto.add_theme_constant_override("outline_size", 5)
	_hud_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_hud_texto)
	_hud_texto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_texto.offset_left = 14.0
	_hud_texto.offset_top = -82.0
	_hud_texto.offset_right = 560.0
	_hud_texto.offset_bottom = -40.0


func _actualizar_hud() -> void:
	if _hud_barra == null:
		return
	var fr: float = clampf(vida / maxf(Estado.i().vida_max, 1.0), 0.0, 1.0)
	_hud_barra.size.x = 240.0 * fr
	_hud_barra.color = Color(0.35, 0.85, 0.4) if fr > 0.5 else (Color(1.0, 0.8, 0.25) if fr > 0.25 else Color(1.0, 0.3, 0.25))
	var extra: String = ""
	if nadando:
		extra = " · nadando"
	elif not en_suelo:
		extra = " · en el aire"
	elif nivel_actual() > 0:
		extra = " · nivel %d" % nivel_actual()
	_hud_texto.text = "Vida %d/%d · oro %d%s\nT libro · 1/2/3 lanzar página · Espacio saltar · F12 medición" % [
		int(vida), int(Estado.i().vida_max), Estado.i().oro, extra]
