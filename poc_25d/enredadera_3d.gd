class_name Enredadera3D
extends Node3D

## ENREDADERA que brota del suelo, arde y se deshace. La usa el elemental de bosque (hechizo `cast`) y vale para cualquier
## enredadera del nivel. Es un nodo suelto: se añade donde se quiere, mirando hacia donde se quiera (rotation.y), y se maneja con
## tres órdenes — `brotar()`, `quemar()` y (si hace falta) `deshacer()`.
##
## (La fase actual está en `fase`; el enum no se llama Estado porque ese nombre es el autoload del juego.)
## Ciclo de vida (lo pidió Pablo el 8/10):
##   1. BROTANDO   sale de la tierra: sube desde debajo del suelo y no se ve nada por debajo de él (el shader recorta bajo `corte_y`).
##   2. VIVA       la malla verde. Aquí se queda hasta que algo la quema.
##   3. ARDIENDO   `quemar()`: SIGUE VERDE, sin alterarse, pero el fuego va generando focos nuevos (llamas sueltas sobre ella,
##                 cada 0,4 s, hasta MAX_FOCOS). Cada foco nuevo emite `foco(punto)`: el Juego lo usa para prender lo que haya cerca.
##   4. QUEMADA    cambia a la malla quemada (oscura, con brasas) y las llamas se reducen a una.
##   5. DESHACIENDO se desintegra de arriba abajo con un borde de brasa y se hunde un poco; al acabar se borra sola (`deshecha`).
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

signal brotada
signal ardiendo
signal foco(punto: Vector3)     ## nace una llama nueva (punto del mundo): el Juego puede prender lo que haya cerca
signal quemada
signal deshecha

enum Fase { OCULTA, BROTANDO, VIVA, ARDIENDO, QUEMADA, DESHACIENDO, DESHECHA }

const GLB: String = "res://poc_25d/meshy/enredadera/enredadera.glb"
const DURA_BROTE: float = 0.75
const HUNDIDA: float = 0.32          ## cuánto empieza por debajo del suelo (la malla mide ~0,3 de alto a escala 1)
const INTERVALO_FOCO: float = 0.4
const MAX_FOCOS: int = 5
const DURA_ARDER: float = 2.2        ## verde y con focos, antes de quemarse del todo
const DURA_QUEMADA: float = 1.6      ## quemada y quieta, antes de deshacerse
const DURA_DESHACER: float = 1.7

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D t_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float corte_y = -1000.0;     // por debajo de esta altura del MUNDO no se dibuja (el suelo)
uniform float disolver = 0.0;        // 0 = entera, 1 = deshecha
uniform float alto = 0.3;
varying vec3 lp;
varying float wy;
float hash(vec3 p) { p = fract(p * 0.3183 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void vertex() { lp = VERTEX; wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	if (wy < corte_y) discard;
	vec3 a = texture(t_albedo, UV).rgb;
	// se deshace de arriba abajo con ruido: n pequeño = se va antes
	float n = hash(floor(lp * 38.0)) * 0.45 + (1.0 - clamp(lp.y / alto, 0.0, 1.0)) * 0.55;
	float d = n - disolver * 1.1;
	if (d < 0.0) discard;
	float borde = smoothstep(0.07, 0.0, d) * step(0.001, disolver);
	ALBEDO = a;
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.45, 0.08) * borde * 2.2;
}
"""

var fase: Fase = Fase.OCULTA
var ancho: float = 1.3                ## ancho en el mundo (la malla mide 1,0 a escala 1)
var _fx: Vfx3D = null
var _viva: MeshInstance3D = null
var _quemada: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _tw: Tween = null
var _llamas: Array = []
var _alto_real: float = 0.3


## `fx`: el Vfx3D para las llamas (opcional). Carga las dos mallas y las deja ocultas.
func preparar(fx: Vfx3D = null, p_ancho: float = 1.3) -> void:
	_fx = fx
	ancho = p_ancho
	var ps: PackedScene = load(GLB) as PackedScene
	if ps == null:
		push_warning("Enredadera3D: falta " + GLB)
		return
	var m: Node3D = ps.instantiate() as Node3D
	m.scale = Vector3.ONE * ancho
	add_child(m)
	_viva = m.find_child("viva", true, false) as MeshInstance3D
	_quemada = m.find_child("quemada", true, false) as MeshInstance3D
	var base: BaseMaterial3D = _viva.mesh.surface_get_material(0) as BaseMaterial3D if _viva != null else null
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CODIGO
	_mat.shader = sh
	if base != null:
		_mat.set_shader_parameter("t_albedo", base.albedo_texture)
	_alto_real = _viva.mesh.get_aabb().size.y if _viva != null else 0.3
	_mat.set_shader_parameter("alto", maxf(_quemada.mesh.get_aabb().size.y, _alto_real) if _quemada != null else _alto_real)
	for n in [_viva, _quemada]:
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
	_mat.set_shader_parameter("corte_y", global_position.y - 0.005)
	_tw = create_tween()
	_tw.tween_property(_viva.get_parent(), "position:y", 0.0, DURA_BROTE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void:
		fase = Fase.VIVA
		_mat.set_shader_parameter("corte_y", -1000.0)
		brotada.emit())


## Le llega el fuego: arde sin alterarse, genera focos, se quema y se deshace. Una sola vez.
func quemar() -> void:
	if fase != Fase.VIVA and fase != Fase.BROTANDO:
		return
	if _tw != null:
		_tw.kill()
	_mat.set_shader_parameter("corte_y", -1000.0)
	(_viva.get_parent() as Node3D).position.y = 0.0
	fase = Fase.ARDIENDO
	ardiendo.emit()
	_tw = create_tween()
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
	_tw = create_tween()
	_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("disolver", v), 0.0, 1.0, DURA_DESHACER)
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
	quemada.emit()


func _mostrar(quemada_: bool) -> void:
	if _viva != null:
		_viva.visible = not quemada_
	if _quemada != null:
		_quemada.visible = quemada_


func _apagar_llamas() -> void:
	for l in _llamas:
		if _fx != null and is_instance_valid(_fx) and is_instance_valid(l):
			_fx.apagar(l as Node3D)
	_llamas.clear()
