class_name Enredadera3D
extends Node3D

## ENREDADERA que brota del suelo, arde y se deshace. La usa el elemental de bosque (hechizo `cast`) y vale para cualquier
## enredadera del nivel. Es un nodo suelto: se añade donde se quiere, mirando hacia donde se quiera (rotation.y), y se maneja con
## tres órdenes — `brotar()`, `quemar()` y (si hace falta) `deshacer()`.
##
## (La fase actual está en `fase`; el enum no se llama Estado porque ese nombre es el autoload del juego.)
## Ciclo de vida (lo pidió Pablo el 8/10):
##   1. BROTANDO   sale de la tierra: sube desde debajo del suelo y no se ve nada por debajo de él (el shader común recorta bajo `corte_y`).
##   2. VIVA       la malla verde. Aquí se queda hasta que algo la quema.
##   3. ARDIENDO   `quemar()`: el fuego va generando focos nuevos (llamas sueltas sobre ella, cada 0,4 s, hasta MAX_FOCOS). Cada foco nuevo emite
##                 `foco(punto)`: el Juego lo usa para prender lo que haya cerca. V6: el `quemado` común sube 0 → QUEMADO_AL_ARDER (carbón con frente de brasas).
##   4. QUEMADA    cambia a la malla quemada (oscura, retorcida) y las llamas se reducen a una; `quemado` sigue hasta 1 (ceniza gris).
##   5. DESHACIENDO V6: `disolver` por celdas con borde brillante (el mismo de seto y tronco) y se hunde un poco; al acabar se borra sola (`deshecha`).
##
## Por qué dos mallas y no un fundido de textura: Meshy las modeló distintas (la quemada tiene las raíces retorcidas y partidas);
## cambiar de malla se ve como «se ha quemado» y un tinte no lo conseguiría. El GLB trae las dos (`viva`, `quemada`) apoyadas en y = 0.
##
## Uso:
##   var e := Enredadera3D.new(); add_child(e)
##   e.position = punto_en_el_suelo; e.rotation.y = giro
##   e.preparar(fx)              # fx: el Vfx3D del nivel (para las llamas); sin él arde sin llamas visibles
##   e.brotar()
##   e.quemar()                  # cuando le llegue el fuego
##
## VARIANTE «bloqueo» (16/10, Pipeline, ARTE §15): el matorral que corta un paso. Usa las piezas de `PiezaBosque3D` (`bloqueo_enredaderas` vivo y
## `bloqueo_enredaderas_quemado`, 2,2 × 1,08 y 1,83 × 0,66, mismo factor de escala) y, al quemarse, deja `enredadera_quemada_a/_b` y
## `ceniza_enredadera` en el suelo. `ancho` sigue siendo el ancho del VIVO en el mundo (2,2 a escala 1). Si falta la lámina, no se crea (aviso).

signal brotada
signal ardiendo
signal foco(punto: Vector3)     ## nace una llama nueva (punto del mundo): el Juego puede prender lo que haya cerca
signal quemada
signal deshecha

enum Fase { OCULTA, BROTANDO, VIVA, ARDIENDO, QUEMADA, DESHACIENDO, DESHECHA }

const GLB: String = "res://arte/meshy/enredadera/enredadera.glb"
const GLB_ESPINOSA: String = "res://arte/meshy/enredadera/enredadera_espinosa.glb"
## Ancho de la malla `viva` tal como viene en cada GLB (para que `ancho` signifique siempre «ancho en el mundo»).
const ANCHO_BASE: float = 1.0
const ANCHO_BASE_ESPINOSA: float = 0.767
const ANCHO_BASE_BLOQUEO: float = 2.2
## Dónde caen los restos de la variante «bloqueo», en coordenadas de la pieza a escala 1 (x, z) y giro (rad): a ambos lados del quemado y la ceniza delante.
const RESTOS_BLOQUEO: Array = [["enredadera_quemada_a", Vector3(-0.95, 0.0, 0.5), 0.6], ["enredadera_quemada_b", Vector3(0.9, 0.0, -0.45), -0.8],
		["ceniza_enredadera", Vector3(0.1, 0.0, 0.75), 0.0]]
const DURA_BROTE: float = 0.75
const HUNDIDA: float = 0.32          ## cuánto empieza por debajo del suelo (la malla mide ~0,3 de alto a escala 1)
const INTERVALO_FOCO: float = 0.4
const MAX_FOCOS: int = 5
const DURA_ARDER: float = 2.2        ## verde y con focos, antes de quemarse del todo
const DURA_QUEMADA: float = 1.6      ## quemada y quieta, antes de deshacerse
const DURA_DESHACER: float = 1.7

## V6 (restos): ya no lleva shader propio. Usa el material común de `Ocluso3D` (presentacion/ocluso_3d.gd): `corte_y` (recorte del suelo al brotar),
## `quemado` (carbón + frente de brasas + ceniza) y `disolver` (celdas Voronoi con borde brillante), igual que el seto y el tronco.
const QUEMADO_AL_ARDER: float = 0.55      ## `quemado` al acabar ARDIENDO (carbón con brasas); de ahí sube a 1 (ceniza) durante QUEMADA
const CELDA_DISOLVER: float = 0.08        ## m; la enredadera mide ~0,3 de alto: con la celda de serie (0,2) serían dos celdas
const SIN_CORTE: float = -1000.0
var fase: Fase = Fase.OCULTA
var ancho: float = 1.3                ## ancho en el mundo (la malla mide 1,0 a escala 1)
var _fx: Vfx3D = null
var _viva: MeshInstance3D = null
var _quemada: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _tw: Tween = null
var _tw_q: Tween = null               ## el avance de `quemado`
var _llamas: Array = []
var _alto_real: float = 0.3
var _restos: Array = []               ## MeshInstance3D de los restos (solo variante «bloqueo»): se ven al quemarse


## `fx`: el Vfx3D para las llamas (opcional). `variante`: "" = la enredadera normal; "espinosa" = la grande con espinas y restos
## quemados (Meshy «Thornvine and Ashes»). Carga las dos mallas y las deja ocultas.
func preparar(fx: Vfx3D = null, p_ancho: float = 1.3, variante: String = "") -> void:
	_fx = fx
	ancho = p_ancho
	var ruta: String = GLB_ESPINOSA if variante == "espinosa" else GLB
	var ancho_modelo: float = ANCHO_BASE_ESPINOSA if variante == "espinosa" else ANCHO_BASE
	var m: Node3D = null
	if variante == "bloqueo":
		var v: MeshInstance3D = PiezaBosque3D.crear("bloqueo_enredaderas")
		var q: MeshInstance3D = PiezaBosque3D.crear("bloqueo_enredaderas_quemado")
		if v == null or q == null:
			push_warning("Enredadera3D: falta la lámina res://arte/meshy/bosque/bosque_ruinas.glb (variante bloqueo)")
			return
		v.name = "viva"
		q.name = "quemada"
		m = Node3D.new()
		m.add_child(v)
		m.add_child(q)
		m.scale = Vector3.ONE * (ancho / ANCHO_BASE_BLOQUEO)
		for d in RESTOS_BLOQUEO:
			var resto: MeshInstance3D = PiezaBosque3D.crear(String(d[0]))
			if resto != null:
				resto.position = d[1]
				resto.rotation.y = float(d[2])
				resto.visible = false
				m.add_child(resto)
				_restos.append(resto)
		add_child(m)
	else:
		var ps: PackedScene = load(ruta) as PackedScene
		if ps == null:
			push_warning("Enredadera3D: falta " + ruta)
			return
		m = ps.instantiate() as Node3D
		m.scale = Vector3.ONE * (ancho / ancho_modelo)
		add_child(m)
	_viva = m.find_child("viva", true, false) as MeshInstance3D
	_quemada = m.find_child("quemada", true, false) as MeshInstance3D
	var base: BaseMaterial3D = _viva.mesh.surface_get_material(0) as BaseMaterial3D if _viva != null else null
	# Un único material común (como el de antes: la textura de la malla viva vale para las demás piezas del mismo atlas).
	Ocluso3D.preparar()                   # idempotente: registra el parámetro global de la oclusión si nadie lo había hecho
	var origen: StandardMaterial3D = (base.duplicate() as StandardMaterial3D) if base != null else StandardMaterial3D.new()
	origen.cull_mode = BaseMaterial3D.CULL_DISABLED          # el shader de antes dibujaba las dos caras (hojas finas)
	_mat = Ocluso3D.convertir(origen) as ShaderMaterial
	if _mat == null:                      # transparente o sin sombreado: no es un material que se pueda convertir
		push_warning("Enredadera3D: no se pudo pasar al material común; se usa uno liso")
		_mat = Ocluso3D.convertir(StandardMaterial3D.new()) as ShaderMaterial
	_alto_real = _viva.mesh.get_aabb().size.y if _viva != null else 0.3
	var y0: float = _viva.mesh.get_aabb().position.y if _viva != null else 0.0
	var alto_max: float = maxf(_quemada.mesh.get_aabb().size.y, _alto_real) if _quemada != null else _alto_real
	_mat.set_shader_parameter("caja_y", Vector2(y0, alto_max))
	_mat.set_shader_parameter("corte_y", SIN_CORTE)
	Ocluso3D.configurar_disolver(_mat, Ocluso3D.DISOLVER_COLOR, CELDA_DISOLVER)
	for n in [_viva, _quemada] + _restos:
		if n != null:
			(n as MeshInstance3D).material_override = _mat
			(n as MeshInstance3D).visible = false


## Sale de la tierra: sube desde debajo del suelo con un pequeño rebote.
func brotar() -> void:
	if fase != Fase.OCULTA or _viva == null:
		return
	fase = Fase.BROTANDO
	_viva.visible = true
	var hundida: float = HUNDIDA * ancho
	(_viva.get_parent() as Node3D).position.y = -hundida
	Ocluso3D.poner_corte_y(_mat, global_position.y - 0.005)
	_tw = create_tween()
	_tw.tween_property(_viva.get_parent(), "position:y", 0.0, DURA_BROTE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void:
		fase = Fase.VIVA
		Ocluso3D.poner_corte_y(_mat, SIN_CORTE)
		brotada.emit())


## Le llega el fuego: arde sin alterarse, genera focos, se quema y se deshace. Una sola vez.
func quemar() -> void:
	if fase != Fase.VIVA and fase != Fase.BROTANDO:
		return
	if _tw != null:
		_tw.kill()
	Ocluso3D.poner_corte_y(_mat, SIN_CORTE)
	(_viva.get_parent() as Node3D).position.y = 0.0
	fase = Fase.ARDIENDO
	ardiendo.emit()
	_tw = create_tween()
	# V6: mientras arde, el carbón con brasas avanza por la malla viva (0 → QUEMADO_AL_ARDER) en lugar de seguir verde.
	if Ocluso3D.usar_quemado_disolver:
		_animar_quemado(QUEMADO_AL_ARDER, DURA_ARDER, 0.0)
	# 1) focos: uno al empezar y otro cada INTERVALO_FOCO, hasta MAX_FOCOS
	for i in range(MAX_FOCOS):
		_tw.tween_callback(_nuevo_foco)
		if i < MAX_FOCOS - 1:
			_tw.tween_interval(INTERVALO_FOCO)
	_tw.tween_interval(maxf(DURA_ARDER - INTERVALO_FOCO * float(MAX_FOCOS - 1), 0.1))
	# 2) cambia a la malla quemada; quedan pocas llamas
	_tw.tween_callback(_pasar_a_quemada)
	_tw.tween_interval(DURA_QUEMADA)
	# 3) se deshace
	_tw.tween_callback(deshacer)


## Salta directamente a deshacerse (p. ej. si muere el elemental que la lanzó).
func deshacer() -> void:
	if fase == Fase.DESHACIENDO or fase == Fase.DESHECHA or fase == Fase.OCULTA:
		return
	if _tw != null:
		_tw.kill()
	if fase != Fase.QUEMADA and fase != Fase.ARDIENDO:
		_mostrar(false)
	fase = Fase.DESHACIENDO
	_apagar_llamas()
	if _tw_q != null:
		_tw_q.kill()
	_tw = create_tween()
	if Ocluso3D.usar_quemado_disolver:
		# V6: el disolver por celdas común (el mismo del seto y el tronco), no el de arriba abajo propio de antes.
		_tw.tween_method(func(v: float) -> void: Ocluso3D.poner_disolver(_mat, v), 0.0, 1.0, DURA_DESHACER)
	else:
		# Interruptor apagado: como el resto del decorado antes de V6, se aplasta.
		var m: Node3D = _viva.get_parent() as Node3D
		_tw.tween_property(m, "scale:y", m.scale.y * 0.05, DURA_DESHACER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(self, "position:y", position.y - 0.08, DURA_DESHACER)
	_tw.tween_callback(func() -> void:
		fase = Fase.DESHECHA
		deshecha.emit()
		queue_free())


func _nuevo_foco() -> void:
	if _viva == null:
		return
	# un punto al azar sobre la enredadera (largo en x, un poco de fondo en z), a media altura
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 131.0 + global_position.z * 71.0) + _llamas.size() * 977
	var local := Vector3(rng.randf_range(-0.42, 0.42) * ancho, 0.08 * ancho, rng.randf_range(-0.07, 0.07) * ancho)
	var p: Vector3 = global_transform * local
	if _fx != null and is_instance_valid(_fx):
		var l: Node3D = _fx.llamas(Vector3(p.x, global_position.y, p.z), 0.6, 0.22, 1)
		_llamas.append(l)
	foco.emit(p)


func _pasar_a_quemada() -> void:
	fase = Fase.QUEMADA
	_mostrar(true)
	# se apagan todas las llamas menos la última: lo quemado sigue humeando un poco
	while _llamas.size() > 1:
		var l: Node3D = _llamas.pop_front()
		if _fx != null and is_instance_valid(_fx) and is_instance_valid(l):
			_fx.apagar(l)
	if Ocluso3D.usar_quemado_disolver:
		_animar_quemado(1.0, DURA_QUEMADA, QUEMADO_AL_ARDER)       # de carbón con brasas a ceniza mientras está quieta
	quemada.emit()


## Lleva `quemado` (uniform común) de `desde` a `hasta` en `dur` s, en un tween aparte para que no estorbe a la secuencia de focos.
func _animar_quemado(hasta: float, dur: float, desde: float) -> void:
	if _tw_q != null:
		_tw_q.kill()
	_tw_q = create_tween()
	_tw_q.tween_method(func(v: float) -> void: Ocluso3D.poner_quemado(_mat, v), desde, hasta, dur)


func _mostrar(quemada_: bool) -> void:
	if _viva != null:
		_viva.visible = not quemada_
	if _quemada != null:
		_quemada.visible = quemada_
	for r in _restos:
		(r as MeshInstance3D).visible = quemada_


func _apagar_llamas() -> void:
	for l in _llamas:
		if _fx != null and is_instance_valid(_fx) and is_instance_valid(l):
			_fx.apagar(l as Node3D)
	_llamas.clear()
