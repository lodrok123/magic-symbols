class_name Cofre3D
extends Node3D

## COFRE QUE SE ABRE (15/10, Pipeline; encargo del Juego). Controla el modelo animado `cofre_anim.glb` (nodos `cofre_cuerpo` y `cofre_tapa`, pivote de la
## tapa en la bisagra, origen en el centro de la base, clips «cerrado» y «abrir» de 0,55 s) y le pone el «game feel»:
##   1. ANTICIPACIÓN (T_ANTICIPA, 0,4 s): el cofre se encoge un poco (squash), la tapa tiembla hacia arriba dos veces como si empujara desde dentro, una luz
##      dorada sube y motas doradas se reúnen desde fuera hacia la juntura.
##   2. APERTURA: se emite `abriendo`, suena el clip «abrir» y sale una ráfaga de oro por el interior. La malla del cofre es una cáscara ABIERTA por dentro
##      (386 aristas abiertas): se ve hueca al girar la tapa, así que una cubierta dorada tapa el hueco hasta que acaba el clip (+ MARGEN_VFX).
##   3. ABIERTO: al acabar el clip se emite `abierto`; es el momento de soltar el botín. Después, el interior queda oscuro (la cubierta se deshace).
## Sin AnimationPlayer o sin el clip «abrir» (modelo viejo o por probar) gira la tapa a mano T_ABRIR_SIN_CLIP s: el contrato es el mismo.
##
## CONTRATO CON EL JUEGO (a aprobar por Pablo):
##   var c := Cofre3D.en(pieza)       # `pieza` = la instancia de piezas/cofre.tscn (o su `modelo`); crea el controlador la primera vez
##   c.abrir()                        # arranca la secuencia; false si ya se está abriendo o ya está abierto (idempotente)
##   c.abierto.connect(soltar_botin)  # fin del clip: aquí cae el botín
##   c.esta_abierto() -> bool         # para guardar/restaurar la partida
##   c.abrir_ya()                     # al cargar una partida con el cofre ya abierto: pone la pose final sin animación ni efectos (no emite `abierto`)
##   c.cerrar()                       # lo deja cerrado sin animación (reiniciar el nivel)
## Señales: `abriendo` (la tapa empieza a girar: p. ej. el sonido) y `abierto`.
##
## ESTADOS PARA «COFRE QUE APARECE CUANDO SE CUMPLE UNA CONDICIÓN» (21/10, PLAN_EOW C3; el Juego decide CUÁNDO, esto solo lo dibuja). Cuatro estados:
##   oculto → (aparecer) → cerrado → (abrir) → abierto        [`cerrar()` y `ocultar()` los deshacen sin animación]
##   c.ocultar()                      # invisible y NO se puede abrir (abrir() devuelve false). Es el estado de partida de un cofre con `aparece_si=`
##   c.aparecer() -> bool             # oculto → cerrado CON efecto (pop con rebote, destello dorado, motas); emite `aparecido` al acabar. false si no estaba oculto
##   c.aparecer_ya()                  # oculto → cerrado sin efecto (cargar una partida donde la condición ya se cumplía)
##   c.esta_oculto() -> bool
##   c.estado_nombre() -> StringName  # &"oculto" | &"cerrado" | &"abierto" (mientras anima: &"apareciendo" / &"abriendo")
##   c.poner_estado(&"oculto"|&"cerrado"|&"abierto")   # restaurar de golpe desde el guardado (la flag `abierto` manda sobre `aparece_si`)
## OJO, la colisión y la interacción NO son de aquí: al ocultar solo se apaga `visible` de la pieza. Quien tenga el `StaticBody3D`/«Area» de pulsar E
## (Juego) debe apagarlo mientras `esta_oculto()` y encenderlo con la señal `aparecido` (o mirar `esta_oculto()` antes de ofrecer «abrir»).
## Señal nueva: `aparecido` (ya es cerrado y se puede abrir).

signal abriendo
signal abierto
signal aparecido

const CLIP_CERRADO: String = "cerrado"
const CLIP_ABRIR: String = "abrir"
const NODO_CUERPO: String = "cofre_cuerpo"
const NODO_TAPA: String = "cofre_tapa"

const T_ANTICIPA: float = 0.4                ## s de anticipación antes de girar la tapa
const T_ABRIR_SIN_CLIP: float = 0.55
const ANGULO_SIN_CLIP: float = 105.0         ## grados, solo si no hay clip
const MARGEN_VFX: float = 0.35               ## s que la cubierta dorada se queda tras acabar el clip
const SQUASH: Vector3 = Vector3(1.04, 0.93, 1.04)
const TEMBLOR: float = 0.07                  ## fracción del ángulo de apertura que sube la tapa en cada temblor
const COLOR_LUZ: Color = Color(1.0, 0.78, 0.3)

const T_APARECE: float = 0.55                ## s del «pop» de aparición
const ESCALA_APARECE: float = 0.55           ## de qué tamaño (fracción) empieza a crecer

## cofre disolver (V6 restos): el cofre se MATERIALIZA con el `disolver` común de Ocluso3D al revés (de 1 a 0: celdas que aparecen con su borde brillante) en lugar
## del pop con escala. Mientras dura (APARECIENDO) NO se puede abrir (`abrir()` solo vale en CERRADO). Sin material común (Ocluso3D apagado o el modelo
## no trae materiales convertibles, p. ej. un cofre sintético de prueba) se vuelve al pop de arriba.
const T_APARECE_DISOLVER: float = 0.9        ## s de la materialización por celdas
const CELDA_APARECE: float = 0.07            ## m; el cofre mide ~0,75: con la celda de serie (0,2) saldrían cuatro trozos
static var aparecer_disolviendo: bool = true ## interruptor: false = el pop con escala de siempre

## OCULTO y APARECIENDO van al final para no mover los valores que ya existían.
enum Estado { CERRADO, ANTICIPANDO, ABRIENDO, ABIERTO, OCULTO, APARECIENDO }

var _estado: int = Estado.CERRADO
var _raiz: Node3D = null                     ## la pieza que se enciende/apaga (el padre al preparar)
var _anim: AnimationPlayer = null
var _cuerpo: Node3D = null
var _tapa: Node3D = null
var _asa: Node3D = null                      ## el padre de cuerpo y tapa: lo que se encoge en la anticipación
var _escala0: Vector3 = Vector3.ONE
var _q_reposo: Quaternion = Quaternion.IDENTITY
var _giro_abrir: Quaternion = Quaternion.IDENTITY     ## la rotación (en el espacio del padre de la tapa) que hace el clip al abrir
var _luz: OmniLight3D = null
var _mats_disolver: Array[ShaderMaterial] = []       ## cofre disolver: copias comunes de los materiales del cofre (se crean la primera vez que aparece)
var _tw_disolver: Tween = null
var disolver_v: float = 0.0                          ## cofre disolver: valor actual del `disolver` (1 = invisible … 0 = entero); para pruebas


## El controlador de `nodo` (lo crea y lo prepara la primera vez). Null si `nodo` no tiene cuerpo ni tapa del cofre.
static func en(nodo: Node) -> Cofre3D:
	if nodo == null:
		return null
	for h in nodo.find_children("*", "Cofre3D", true, false):
		return h as Cofre3D
	var c := Cofre3D.new()
	c.name = "Cofre3D"
	nodo.add_child(c)
	# Si `nodo` ya está en el árbol, el `_ready` de `c` lo acaba de preparar; si no, se prepara aquí (y el `_ready` posterior no repite).
	if c._tapa == null and not c.preparar(nodo):
		c.queue_free()
		return null
	return c


## 16/10 (Pablo, Bosque 01: «el cofre estaba abierto inicialmente»): el GLB sale con la tapa ABIERTA y solo `preparar` lo deja en «cerrado», pero
## `preparar` solo se llamaba al pulsar E (`Cofre3D.en`): hasta entonces el cofre se veía abierto. Ahora `arte/piezas/cofre.tscn` trae este nodo como hijo
## de la pieza y se prepara solo al entrar en el árbol: el cofre nace cerrado se coloque quien lo coloque. (Medido: sin preparar, la tapa queda a 0° y el
## cofre mide 0,85 de alto; preparado, la tapa gira y mide 0,75.)
func _ready() -> void:
	if _tapa == null and get_parent() != null:
		preparar(get_parent())


## Busca en `raiz` el cuerpo, la tapa y el AnimationPlayer. false si no está la tapa (no hay nada que abrir).
func preparar(raiz: Node) -> bool:
	_raiz = raiz as Node3D
	_cuerpo = raiz.find_child(NODO_CUERPO, true, false) as Node3D
	_tapa = raiz.find_child(NODO_TAPA, true, false) as Node3D
	if _tapa == null:
		return false
	_asa = (_tapa.get_parent() as Node3D) if _tapa.get_parent() is Node3D else null
	if _asa != null:
		_escala0 = _asa.scale
	for a in raiz.find_children("*", "AnimationPlayer", true, false):
		if (a as AnimationPlayer).has_animation(CLIP_ABRIR):
			_anim = a as AnimationPlayer
			break
	# La pose de reposo del GLB NO es la cerrada (la tapa sale ya girada): se parte de la del clip «cerrado», que es la que se ve y a la que se vuelve.
	if _anim != null and _anim.has_animation(CLIP_CERRADO):
		_anim.play(CLIP_CERRADO)
		_anim.seek(0.0, true)
		_anim.pause()
	_q_reposo = _tapa.quaternion
	_giro_abrir = _giro_del_clip()
	add_to_group("cofre_3d")
	return true


func esta_abierto() -> bool:
	return _estado == Estado.ABIERTO


func esta_oculto() -> bool:
	return _estado == Estado.OCULTO


func estado_nombre() -> StringName:
	match _estado:
		Estado.OCULTO: return &"oculto"
		Estado.APARECIENDO: return &"apareciendo"
		Estado.ABIERTO: return &"abierto"
		Estado.CERRADO: return &"cerrado"
	return &"abriendo"      # ANTICIPANDO y ABRIENDO: para fuera es lo mismo


## Lo deja invisible y sin poder abrirse, sin animación. Si estaba abierto o abriéndose, la pose se queda como esté (al reaparecer se parte de «cerrado»).
func ocultar() -> void:
	if _tapa == null:
		return
	cerrar()
	_estado = Estado.OCULTO
	if _raiz != null:
		_raiz.visible = false


## oculto → cerrado con efecto. false si no estaba oculto (idempotente: llamarlo dos veces no repite el efecto).
func aparecer() -> bool:
	if _estado != Estado.OCULTO or _tapa == null or not is_inside_tree():
		return false
	_estado = Estado.APARECIENDO
	if _raiz != null:
		_raiz.visible = true
	var caja: AABB = _caja()
	var centro: Vector3 = caja.position + caja.size * 0.5
	var dur: float = T_APARECE                   # cofre disolver: duración de esta aparición (la del pop o la del disolver)
	# 1) Pop: crece desde ESCALA_APARECE con un pequeño rebote (TRANS_BACK pasa de 1 y vuelve). Se parte del tamaño de reposo, no de 1, por si el nodo viene escalado.
	if _empezar_disolver():                      # cofre disolver: materialización por celdas en lugar del pop
		dur = T_APARECE_DISOLVER
	elif _asa != null:
		_asa.scale = _escala0 * ESCALA_APARECE
		var ts: Tween = _asa.create_tween()
		ts.tween_property(_asa, "scale", _escala0, T_APARECE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) Destello dorado que sube y se apaga (misma luz y color que la anticipación, para que se lea como «lo mismo que se abre»).
	var luz := OmniLight3D.new()
	luz.light_color = COLOR_LUZ
	luz.light_energy = 0.0
	luz.omni_range = maxf(caja.size.x, caja.size.z) * 3.5
	luz.shadow_enabled = false
	luz.position = centro
	add_child(luz)
	var tl: Tween = luz.create_tween()
	tl.tween_property(luz, "light_energy", 2.4, dur * 0.25)
	tl.tween_property(luz, "light_energy", 0.0, dur * 1.2).set_trans(Tween.TRANS_SINE)
	tl.tween_callback(luz.queue_free)
	# 3) Motas doradas que salen hacia fuera (las de la anticipación entran; estas salen: el gesto es el contrario).
	VfxKit3D.oro_motas(self, centro, 36, 0.8, 0.08, 1.8, false, false, maxf(caja.size.x, caja.size.z) * 0.4, Vector3.UP, 70.0)
	var fin: Tween = create_tween()
	fin.tween_interval(dur)
	fin.tween_callback(_terminar_aparicion)
	return true


func _terminar_aparicion() -> void:
	if _estado != Estado.APARECIENDO:        # alguien llamó a ocultar()/poner_estado() mientras animaba
		return
	_poner_disolver(0.0)                         # cofre disolver: entero (por si el tween no llegó exacto)
	_estado = Estado.CERRADO
	aparecido.emit()


## oculto → cerrado sin efecto ni señal (cargar una partida). No hace nada si no estaba oculto.
func aparecer_ya() -> void:
	if _estado != Estado.OCULTO:
		return
	cerrar()
	if _raiz != null:
		_raiz.visible = true


## Restaura de golpe un estado guardado. Nombre desconocido: no hace nada (mejor que adivinar).
func poner_estado(nombre: StringName) -> void:
	match nombre:
		&"oculto": ocultar()
		&"cerrado":
			cerrar()
			if _raiz != null:
				_raiz.visible = true
		&"abierto":
			if _raiz != null:
				_raiz.visible = true
			abrir_ya()


## La rotación que hace el clip «abrir» sobre la tapa: la del último fotograma respecto a la del primero. Sirve para saber el eje de la bisagra
## sin suponerlo (varía con cómo se exportó el modelo) y cuánto sube. Sin clip: ANGULO_SIN_CLIP sobre X.
func _giro_del_clip() -> Quaternion:
	if _anim != null:
		var an: Animation = _anim.get_animation(CLIP_ABRIR)
		var raiz_anim: Node = _anim.get_node_or_null(_anim.root_node)
		for i in range(an.get_track_count()):
			if an.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var ruta: String = String(an.track_get_path(i))
			if not ruta.ends_with(NODO_TAPA) and not ruta.contains(NODO_TAPA + ":"):
				continue
			var n: int = an.track_get_key_count(i)
			if n >= 2:
				var q0: Quaternion = an.track_get_key_value(i, 0)
				var q1: Quaternion = an.track_get_key_value(i, n - 1)
				return (q1 * q0.inverse()).normalized()
	return Quaternion(Vector3.RIGHT, deg_to_rad(-ANGULO_SIN_CLIP))


## Caja del cuerpo en el espacio de este nodo (donde cuelgan las partículas y la luz). El borde de arriba es donde sale el oro.
func _caja() -> AABB:
	var base: Node = _cuerpo if _cuerpo != null else (_asa if _asa != null else self)
	var caja := AABB()
	var primero: bool = true
	var a_local: Transform3D = global_transform.affine_inverse()
	# find_children no incluye al propio nodo, y en el GLB real `cofre_cuerpo` ES la malla (sin hijos): se añade a mano.
	var mallas: Array = base.find_children("*", "MeshInstance3D", true, false)
	if base is MeshInstance3D:
		mallas.push_front(base)
	for mi in mallas:
		var m := mi as MeshInstance3D
		var c: AABB = (a_local * m.global_transform) * m.get_aabb()
		caja = c if primero else caja.merge(c)
		primero = false
	if primero:
		caja = AABB(Vector3(-0.4, 0.0, -0.3), Vector3(0.8, 0.45, 0.6))
	return caja


## Arranca la secuencia. Devuelve false si el cofre ya se está abriendo o ya está abierto.
func abrir() -> bool:
	if _estado != Estado.CERRADO or _tapa == null or not is_inside_tree():
		return false
	_estado = Estado.ANTICIPANDO
	_anticipacion()
	var tw: Tween = create_tween()
	tw.tween_interval(T_ANTICIPA)
	tw.tween_callback(_girar_tapa)
	return true


func _anticipacion() -> void:
	var caja: AABB = _caja()
	var centro_alto: Vector3 = caja.position + Vector3(caja.size.x * 0.5, caja.size.y, caja.size.z * 0.5)
	# 1) Luz dorada que sube.
	_luz = OmniLight3D.new()
	_luz.light_color = COLOR_LUZ
	_luz.light_energy = 0.0
	_luz.omni_range = maxf(caja.size.x, caja.size.z) * 3.5
	_luz.shadow_enabled = false
	_luz.position = centro_alto
	add_child(_luz)
	var tl: Tween = _luz.create_tween()
	tl.tween_property(_luz, "light_energy", 1.2, T_ANTICIPA).set_trans(Tween.TRANS_QUAD)
	# 2) Motas que se reúnen desde fuera hacia la juntura (acaban justo cuando se abre).
	var radio: float = maxf(caja.size.x, caja.size.z) * 0.85
	VfxKit3D.oro_motas(self, centro_alto - Vector3(0.0, caja.size.y * 0.1, 0.0), 44, T_ANTICIPA * 1.1, 0.1, radio / (T_ANTICIPA * 0.8), true, false, radio)
	# 3) El cofre se encoge (squash) y recupera, y la tapa tiembla hacia arriba dos veces (nunca hacia abajo: se metería en el cuerpo).
	if _asa != null:
		var ts: Tween = _asa.create_tween()
		ts.tween_property(_asa, "scale", _escala0 * SQUASH, T_ANTICIPA * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ts.tween_property(_asa, "scale", _escala0, T_ANTICIPA * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tt: Tween = _tapa.create_tween()
	var eje: Vector3 = _giro_abrir.get_axis()
	var ang: float = _giro_abrir.get_angle() * TEMBLOR
	for par in [[0.0, 1.0], [1.0, 0.0], [0.0, 0.6], [0.6, 0.0]]:
		tt.tween_method(_inclinar_tapa.bind(eje, ang), float(par[0]), float(par[1]), T_ANTICIPA * 0.25)


func _inclinar_tapa(f: float, eje: Vector3, ang: float) -> void:
	_tapa.quaternion = Quaternion(eje, ang * f) * _q_reposo


func _girar_tapa() -> void:
	_estado = Estado.ABRIENDO
	_tapa.quaternion = _q_reposo
	abriendo.emit()
	var dura: float = T_ABRIR_SIN_CLIP
	if _anim != null:
		dura = _anim.get_animation(CLIP_ABRIR).length
		_anim.play(CLIP_ABRIR)
	else:
		var tw: Tween = _tapa.create_tween()
		tw.tween_method(func(f: float) -> void: _tapa.quaternion = _giro_abrir.slerp(Quaternion.IDENTITY, 1.0 - f) * _q_reposo, 0.0, 1.0, dura)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Ráfaga dorada por el interior, que se alarga mientras gira la tapa, y la cubierta que tapa el hueco.
	var caja: AABB = _caja()
	var borde: Vector3 = caja.position + Vector3(caja.size.x * 0.5, caja.size.y * 0.92, caja.size.z * 0.5)
	VfxKit3D.oro_motas(self, borde, 44, 0.95, 0.085, 2.4, false, false, minf(caja.size.x, caja.size.z) * 0.3, Vector3.UP, 32.0)
	var continuo: GPUParticles3D = VfxKit3D.oro_motas(self, borde, 36, 0.7, 0.07, 1.6, false, true, minf(caja.size.x, caja.size.z) * 0.32, Vector3.UP, 28.0)
	get_tree().create_timer(dura * 0.9, false).timeout.connect(func() -> void:
		if is_instance_valid(continuo):
			continuo.emitting = false
			get_tree().create_timer(1.0, false).timeout.connect(continuo.queue_free))
	VfxKit3D.oro_cubierta(self, caja.position + Vector3(caja.size.x * 0.5, caja.size.y * 0.9, caja.size.z * 0.5),
			caja.size.x * 1.15, caja.size.z * 1.15, dura + MARGEN_VFX)
	if _luz != null:
		var tl: Tween = _luz.create_tween()
		tl.tween_property(_luz, "light_energy", 3.0, 0.08)
		tl.tween_property(_luz, "light_energy", 0.0, dura + MARGEN_VFX + 0.2).set_trans(Tween.TRANS_SINE)
		tl.tween_callback(_luz.queue_free)
	var fin: Tween = create_tween()
	fin.tween_interval(dura)
	fin.tween_callback(_terminar)


func _terminar() -> void:
	_estado = Estado.ABIERTO
	abierto.emit()


## Pone el cofre ya abierto sin animación ni efectos (cargar una partida). No emite `abierto`: el botín ya se soltó.
func abrir_ya() -> void:
	if _tapa == null:
		return
	_parar_disolver()                            # cofre disolver
	_estado = Estado.ABIERTO
	if _raiz != null:
		_raiz.visible = true
	if _anim != null:
		_anim.play(CLIP_ABRIR)
		_anim.seek(_anim.get_animation(CLIP_ABRIR).length, true)
		_anim.pause()
	else:
		_tapa.quaternion = _giro_abrir * _q_reposo


## Lo deja cerrado sin animación (reiniciar el nivel).
func cerrar() -> void:
	if _tapa == null:
		return
	_parar_disolver()                            # cofre disolver
	_estado = Estado.CERRADO
	if _raiz != null:
		_raiz.visible = true       # cerrado = visible; para esconderlo está ocultar()
	if _anim != null:
		_anim.stop()
		if _anim.has_animation(CLIP_CERRADO):
			_anim.play(CLIP_CERRADO)
			_anim.seek(0.0, true)
			_anim.pause()
	_tapa.quaternion = _q_reposo
	if _asa != null:
		_asa.scale = _escala0

## --- cofre disolver (V6 restos) ---

## Arranca la materialización por celdas (disolver 1 → 0 en T_APARECE_DISOLVER). false si no se puede (interruptor apagado, sin materiales convertibles):
## quien llama usa entonces el pop con escala.
func _empezar_disolver() -> bool:
	if not aparecer_disolviendo or not Ocluso3D.usar_quemado_disolver or _raiz == null:
		return false
	if _mats_disolver.is_empty():
		Ocluso3D.preparar()                      # idempotente
		_mats_disolver = Ocluso3D.convertir_nodo(_raiz)
		for m in _mats_disolver:
			Ocluso3D.configurar_disolver(m, Ocluso3D.DISOLVER_COLOR, CELDA_APARECE)
	if _mats_disolver.is_empty():
		return false
	_poner_disolver(1.0)
	_tw_disolver = create_tween()
	_tw_disolver.tween_method(_poner_disolver, 1.0, 0.0, T_APARECE_DISOLVER)
	return true


func _poner_disolver(v: float) -> void:
	disolver_v = v
	for m in _mats_disolver:
		Ocluso3D.poner_disolver(m, v)


## Corta la materialización (si la había) y deja el cofre entero.
func _parar_disolver() -> void:
	if _tw_disolver != null and _tw_disolver.is_valid():
		_tw_disolver.kill()
	_tw_disolver = null
	_poner_disolver(0.0)
