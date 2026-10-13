class_name PuenteReactivo3D
extends Node3D

## PUENTE REACTIVO PERMANENTE: una fila de losas de piedra flotantes que aparece sobre el agua cuando se activa algo
## (tótem, placa, brasero). Va con un marcador `P` (Marcador3D) que dice dónde y cuántas casillas (`largo`) y qué lo activa.
##
## Por qué losas sueltas y no un puente plegado: el plegado (Reactivo3D «puente») es una pieza grande que gira; esto se
## repite casilla a casilla, así que vale para cualquier largo y se puede ver cómo «crece» desde el agua.
##
## Secuencia de cada losa (i = orden de aparición):
##   t = RETRASO_INICIAL + i·RETRASO_LOSA  salpicadura en el agua (Vfx3D.salpicadura) mientras la losa sigue sumergida
##   +0,08 s                                la losa emerge con rebote (TRANS_BACK: se pasa un poco y se asienta)
##   al terminar de subir                   `losa_lista(celda)`: la casilla pasa a ser andable (lo hace quien carga el nivel)
##   después                                la runa se enciende (de oscura a brillante, del color del elemento)
## Entre losas 0,12 s: con menos parece una sola; con más, el jugador se impacienta.
##
## Modelo: si existe `meshy/puente/losa_runica.glb` (la que genere Pablo) se usa; si no, una losa de caja con la textura
## provisional `losa_albedo.png` + `losa_emision.png` (la máscara de las runas: el brillo sale de ahí y se tiñe por código).

signal losa_lista(celda: Vector2i)
signal completo

const LOSA_GLB: String = "res://poc_25d/meshy/puente/losa_runica.glb"
const TEX_ALBEDO: String = "res://poc_25d/meshy/puente/losa_albedo.png"
const TEX_EMISION: String = "res://poc_25d/meshy/puente/losa_emision.png"
const CASILLA: float = 2.3
const GROSOR: float = 0.28
const HUNDIDA: float = 0.75              ## cuánto más abajo que su sitio final empieza la losa (bajo la superficie)
const RETRASO_INICIAL: float = 0.45
const RETRASO_LOSA: float = 0.12
const DURA_SUBIDA: float = 0.5
const ENERGIA_RUNA: float = 1.0

var tendido: bool = false
var _losas: Array = []                   ## {celda, centro, nodo, mat}
var _fx: Vfx3D = null
var _color: Color = Color(0.2, 0.9, 1.0)
var _y_tope: float = 0.0
var _y_agua: float = 0.0
var _mat_cuerpo: StandardMaterial3D = null
var _hilo: HiloLuz3D = null
var _dura_hilo: float = 0.0


## `celdas` y `centros` (sobre la superficie del agua) van en el orden del marcador. `y_tope` = altura de la cara superior
## de la losa ya puesta; `y_agua` = superficie del agua (donde salpica).
func preparar(celdas: Array, centros: Array, y_tope: float, y_agua: float, fx: Vfx3D, color: Color) -> void:
	_fx = fx
	_color = color
	_y_tope = y_tope
	_y_agua = y_agua
	for i in range(celdas.size()):
		var c: Vector2i = celdas[i]
		var p: Vector3 = centros[i]
		var nodo: Node3D = Node3D.new()
		nodo.name = "losa_%d_%d" % [c.x, c.y]
		nodo.position = Vector3(p.x, y_tope - GROSOR * 0.5 - HUNDIDA, p.z)
		nodo.visible = false
		add_child(nodo)
		var mat: Material = _montar_losa(nodo)
		_losas.append({"celda": c, "centro": p, "nodo": nodo, "mat": mat})


## Un hilo de luz que va del activador al puente: al tender, la luz recorre el hilo (`dura` s) y SOLO cuando llega empiezan a subir
## las losas.
func poner_hilo(hilo: HiloLuz3D, dura: float) -> void:
	_hilo = hilo
	_dura_hilo = dura


## Tiende el puente. `desde` es el punto de lo que lo activó: las losas aparecen desde la más cercana a él (si no se da,
## en el orden del marcador). Una sola vez: es permanente.
func tender(desde: Vector3 = Vector3.INF) -> void:
	if tendido or _losas.is_empty():
		return
	tendido = true
	if _hilo != null:
		_hilo.viajar(_dura_hilo)
	var orden: Array = _losas.duplicate()
	if desde != Vector3.INF:
		orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["centro"] as Vector3).distance_squared_to(desde) < (b["centro"] as Vector3).distance_squared_to(desde))
	for i in range(orden.size()):
		_secuencia(orden[i] as Dictionary, i, i == orden.size() - 1)


func _secuencia(l: Dictionary, i: int, ultima: bool) -> void:
	var nodo: Node3D = l["nodo"]
	var mat: Material = l["mat"]
	var y_final: float = _y_tope - GROSOR * 0.5
	var tw := create_tween()
	tw.tween_interval(RETRASO_INICIAL + _dura_hilo + float(i) * RETRASO_LOSA)
	tw.tween_callback(_salpicar.bind(l["centro"] as Vector3))
	tw.tween_interval(0.08)
	tw.tween_callback(nodo.set.bind("visible", true))
	tw.tween_property(nodo, "position:y", y_final, DURA_SUBIDA).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(losa_lista.emit.bind(l["celda"] as Vector2i))
	if mat is ShaderMaterial:
		tw.tween_method(func(v: float) -> void: (mat as ShaderMaterial).set_shader_parameter("energia", v), 0.0, ENERGIA_RUNA, 0.25)
	elif mat != null:
		tw.tween_property(mat, "emission_energy_multiplier", ENERGIA_RUNA, 0.25)
	if ultima:
		tw.tween_callback(completo.emit)


func _salpicar(p: Vector3) -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.salpicadura(Vector3(p.x, _y_agua, p.z), 1.0)


## La losa: el GLB de Pablo si existe; si no, caja con textura. Devuelve el material que brilla (la energía de la runa).
## Con el GLB las runas salen de la propia textura (el cian se detecta en el shader, ver CODIGO_LOSA) y se tiñen del color
## del elemento; por eso no hace falta un mapa de emisión aparte.
func _montar_losa(nodo: Node3D) -> Material:
	if ResourceLoader.exists(LOSA_GLB):
		var ps: PackedScene = load(LOSA_GLB) as PackedScene
		if ps != null:
			var m: Node3D = ps.instantiate() as Node3D
			if m != null:
				_ajustar_a_casilla(m)
				nodo.add_child(m)
				return _material_runico(m)
	var cuerpo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CASILLA * 0.97, GROSOR, CASILLA * 0.97)
	bm.material = _material_cuerpo()
	cuerpo.mesh = bm
	nodo.add_child(cuerpo)
	var tapa := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CASILLA * 0.97, CASILLA * 0.97)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	if ResourceLoader.exists(TEX_ALBEDO):
		mat.albedo_texture = load(TEX_ALBEDO) as Texture2D
	mat.emission_enabled = true
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission = _color
	mat.emission_energy_multiplier = 0.0
	if ResourceLoader.exists(TEX_EMISION):
		mat.emission_texture = load(TEX_EMISION) as Texture2D
	pm.material = mat
	tapa.mesh = pm
	tapa.position.y = GROSOR * 0.5 + 0.003      # justo sobre la cara de arriba (evita el parpadeo de caras coincidentes)
	nodo.add_child(tapa)
	return mat


## Cian de la textura = runa. El resto del color se queda; las runas se apagan (piedra oscura) y brillan con `energia`.
const CODIGO_LOSA: String = """
shader_type spatial;
uniform sampler2D t_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 color_runa : source_color = vec3(0.1, 0.9, 1.0);
uniform float energia = 0.0;
void fragment() {
	vec3 a = texture(t_albedo, UV).rgb;
	float c = clamp(((a.g + a.b) * 0.5 - a.r - 0.10) / 0.25, 0.0, 1.0) * step(a.g - 0.08, a.b);   // el musgo (verde) no cuenta
	ALBEDO = mix(a, vec3(0.10, 0.15, 0.18), c);
	NORMAL_MAP = texture(t_normal, UV).rgb;
	ROUGHNESS = 0.9;
	EMISSION = color_runa * c * energia;
}
"""


## Cambia el material del GLB por el que enciende las runas (con la misma textura y normal que traía). Devuelve null si el
## GLB no trae una textura que reutilizar (entonces se ve tal cual, sin brillo propio).
func _material_runico(m: Node3D) -> Material:
	var res: ShaderMaterial = null
	for h in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		var base: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D if mi.mesh != null else null
		if base == null or base.albedo_texture == null:
			continue
		if res == null:
			var sh := Shader.new()
			sh.code = CODIGO_LOSA
			res = ShaderMaterial.new()
			res.shader = sh
			res.set_shader_parameter("t_albedo", base.albedo_texture)
			if base.normal_texture != null:
				res.set_shader_parameter("t_normal", base.normal_texture)
			res.set_shader_parameter("color_runa", _color)
		mi.material_override = res
	return res


func _material_cuerpo() -> StandardMaterial3D:
	if _mat_cuerpo == null:
		_mat_cuerpo = StandardMaterial3D.new()
		_mat_cuerpo.roughness = 1.0
		_mat_cuerpo.albedo_color = Color(0.42, 0.45, 0.43)
		if ResourceLoader.exists(TEX_ALBEDO):
			_mat_cuerpo.albedo_texture = load(TEX_ALBEDO) as Texture2D
		_mat_cuerpo.uv1_triplanar = true
		_mat_cuerpo.uv1_scale = Vector3(0.45, 0.45, 0.45)
	return _mat_cuerpo


## Un modelo propio (el GLB): lo encoge o agranda hasta ocupar una casilla de ancho y apoya su cara superior en y = 0 local…
## salvo que el modelo ya traiga su grosor: se centra en el nodo para que `y_tope - GROSOR/2` siga siendo su centro.
func _ajustar_a_casilla(m: Node3D) -> void:
	var caja: AABB = _caja(m)
	if caja.size.x <= 0.0001:
		return
	# x y z por separado: la losa de Meshy no es exactamente cuadrada (0,47 × 0,44) y así las vecinas encajan sin hueco.
	var fx: float = CASILLA * 0.97 / caja.size.x
	var fz: float = CASILLA * 0.97 / maxf(caja.size.z, 0.0001)
	m.scale = Vector3(fx, fx, fz)
	var centro: Vector3 = caja.get_center()
	m.position = Vector3(-centro.x * fx, -centro.y * fx, -centro.z * fz)


func _caja(n: Node) -> AABB:
	var r := AABB()
	var primero: bool = true
	for h in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = mi.mesh.get_aabb()
		var t: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		a = t * a
		r = a if primero else r.merge(a)
		primero = false
	return r
