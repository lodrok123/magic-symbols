extends Node3D

## HUMO TOON POR CPU (6/11/2026, docs/HUMO_TOON_2026-11-06.md). Módulo COMPARTIDO de VientoToy (jirones pálidos), TierraToy (polvo pardo) y quien quiera: un MultiMesh de quads billboard
## con humo_toon.gdshader (dos tonos planos, borde duro, erosión al morir) que mueve este nodo: NO es un GPUParticles3D y su estado se mide en las pruebas (`estados()`).
## Se usa con `const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")` (sin class_name). Pocas bocanadas (10-20 por chorro), grandes.
## CICLO de una bocanada: nace pequeña (`tam_ini`), CRECE hasta `tam_fin` (~×2,5) con una curva rápida al principio, DERIVA en curva (su velocidad gira despacio sobre el eje Y y recibe `deriva`
## como empuje constante, p. ej. hacia arriba), vira al color viejo por edad (en el shader) y se EROSIONA al final de su `vida` (umbral que sube con la edad).
## PARÁMETROS (`montar(n, p)`; p es un diccionario con cualquiera de):
##   claro, sombra, viejo (Color) · tam_ini, tam_fin (m, diámetro) · vida (s) · deriva (Vector3, m/s² de empuje constante) · erosion (0..1) · giro_vel (rad/s del billboard) · curva (rad/s del rizo)
##   · estirado (0,2..1: pompas finas a lo ancho, jirones) · umbral · ruido_borde · mundo (true: top_level, las bocanadas se quedan en el MUNDO aunque el dueño se mueva o muera) · prioridad
## `poner(...)` también sirve para quien coloque las bocanadas con su propia fórmula (carga, barrera).

const DIR: String = "res://presentacion/vfx/toy/"
const SH_HUMO: String = DIR + "humo_toon.gdshader"
const TEX_RUIDO: String = "res://assets/vfx/lelu_noise/T_CloudNoise_Tiled.png"
const POR_DEFECTO: Dictionary = {
	"claro": Color(0.93, 0.93, 0.95), "sombra": Color(0.62, 0.62, 0.70), "viejo": Color(0.55, 0.52, 0.58), "tam_ini": 0.25, "tam_fin": 0.62, "vida": 1.1,
	"deriva": Vector3(0, 0.6, 0), "erosion": 0.8, "giro_vel": 0.5, "curva": 0.9, "estirado": 1.0, "umbral": 0.42, "ruido_borde": 0.22, "mundo": true, "prioridad": 1, "friccion": 1.2}

var p: Dictionary = {}
var _mi: MultiMeshInstance3D = null
var _s: Array = []
var _cursor: int = 0
var _t: float = 0.0
static var _quad: QuadMesh = null


static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## ShaderMaterial del humo toon con sus colores y su ruido.
static func material(q: Dictionary = {}, prioridad: int = 1) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HUMO)
	m.render_priority = prioridad
	m.set_shader_parameter("ruido", load(TEX_RUIDO))
	m.set_shader_parameter("color_claro", q.get("claro", POR_DEFECTO["claro"]))
	m.set_shader_parameter("color_sombra", q.get("sombra", POR_DEFECTO["sombra"]))
	m.set_shader_parameter("color_viejo", q.get("viejo", POR_DEFECTO["viejo"]))
	m.set_shader_parameter("erosion", float(q.get("erosion", POR_DEFECTO["erosion"])))
	m.set_shader_parameter("estirado", float(q.get("estirado", POR_DEFECTO["estirado"])))
	m.set_shader_parameter("umbral", float(q.get("umbral", POR_DEFECTO["umbral"])))
	m.set_shader_parameter("ruido_borde", float(q.get("ruido_borde", POR_DEFECTO["ruido_borde"])))
	return m


## Un MultiMesh de `n` bocanadas (todas ocultas) con el material del humo.
static func crear_mm(nombre: String, n: int, q: Dictionary = {}) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad()
	mm.instance_count = maxi(n, 1)
	for i in mm.instance_count:
		ocultar(mm, i)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(q, int(q.get("prioridad", POR_DEFECTO["prioridad"])))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


static func ocultar(mm: MultiMesh, i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	mm.set_instance_custom_data(i, Color(0, 0, 0, 0))


## Pone la bocanada `i`: centro `pos`, `ancho` × `alto` (m), `giro` (rad, en pantalla), `edad` 0..1, `semilla` 0..1, `alfa` 0..1 (0 = oculta).
static func poner(mm: MultiMesh, i: int, pos: Vector3, ancho: float, alto: float, giro: float, edad: float, semilla: float, alfa: float = 1.0) -> void:
	if alfa <= 0.001 or ancho <= 0.0005:
		ocultar(mm, i)
		return
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(ancho, alto, 1.0)), pos))
	mm.set_instance_custom_data(i, Color(clampf(edad, 0.0, 1.0), fposmod(semilla, 1.0), fposmod(giro / TAU, 1.0), clampf(alfa, 0.0, 1.0)))


## Prepara la reserva de `n` bocanadas con los parámetros `q` (ver arriba).
func montar(n: int, q: Dictionary = {}) -> void:
	p = POR_DEFECTO.duplicate()
	for k in q:
		p[k] = q[k]
	top_level = bool(p["mundo"])
	if top_level:
		transform = Transform3D.IDENTITY           # en el mundo: sin heredar la posición que tenía el dueño al montar
	if _mi != null:
		remove_child(_mi)
		_mi.free()
	_mi = crear_mm("Bocanadas", n, p)
	add_child(_mi)
	_s.clear()
	for i in n:
		_s.append({"vivo": false})
	_cursor = 0


func capacidad() -> int:
	return _s.size()


func vivas() -> int:
	var k: int = 0
	for d in _s:
		if bool(d["vivo"]):
			k += 1
	return k


func multimesh() -> MultiMesh:
	return _mi.multimesh if _mi != null else null


## Cambia un color o un número del material después de montar (p. ej. `aparicion`).
func poner_param(nombre: String, v: Variant) -> void:
	p[nombre] = v
	if _mi != null:
		var m: ShaderMaterial = _mi.material_override as ShaderMaterial
		match nombre:
			"claro": m.set_shader_parameter("color_claro", v)
			"sombra": m.set_shader_parameter("color_sombra", v)
			"viejo": m.set_shader_parameter("color_viejo", v)
			"erosion", "estirado", "umbral", "ruido_borde": m.set_shader_parameter(nombre, float(v))


## Una bocanada nueva en `pos` (mundo si `mundo`, si no local) con velocidad `vel`. `vida_k` y `tam_k` multiplican la vida y el tamaño de la reserva; `giro` = orientación inicial en pantalla (rad);
## `alargado` = relación alto/ancho (1 redonda, 2 el doble de alta: jirón). Devuelve el hueco o -1 si no hay sitio.
func emitir(pos: Vector3, vel: Vector3, vida_k: float = 1.0, tam_k: float = 1.0, giro: float = -1.0, alargado: float = 1.0) -> int:
	if _s.is_empty():
		return -1
	var hueco: int = -1
	for k in _s.size():
		var j: int = (_cursor + k) % _s.size()
		if not bool((_s[j] as Dictionary)["vivo"]):
			hueco = j
			break
	if hueco < 0:
		return -1
	_cursor = (hueco + 1) % _s.size()
	var sem: float = randf()
	_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(float(p["vida"]) * vida_k, 0.05), "tam_k": tam_k, "sem": sem,
		"giro": giro if giro >= 0.0 else randf() * TAU, "giro_vel": float(p["giro_vel"]) * (1.0 if sem < 0.5 else -1.0) * randf_range(0.6, 1.4),
		"curva": float(p["curva"]) * (1.0 if fposmod(sem * 7.0, 1.0) < 0.5 else -1.0) * randf_range(0.5, 1.3), "alargado": alargado}
	return hueco


func vaciar() -> void:
	for i in _s.size():
		_s[i] = {"vivo": false}
	if _mi != null:
		for i in _s.size():
			ocultar(_mi.multimesh, i)


func _process(delta: float) -> void:
	avanzar(delta)


## Tamaño (diámetro, m) de una bocanada con edad `u` 0..1: nace en tam_ini y se hincha hasta tam_fin, deprisa al principio.
func tamano(u: float, tam_k: float = 1.0) -> float:
	var g: float = 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.2)
	return lerpf(float(p["tam_ini"]), float(p["tam_fin"]), g) * tam_k


## Mueve todas `delta` s. Las pruebas pueden llamarla a mano.
func avanzar(delta: float) -> void:
	if _mi == null:
		return
	_t += delta
	var mm: MultiMesh = _mi.multimesh
	var der: Vector3 = p["deriva"]
	var fr: float = float(p["friccion"])
	for i in _s.size():
		var d: Dictionary = _s[i]
		if not bool(d["vivo"]):
			continue
		d["edad"] = float(d["edad"]) + delta
		var u: float = float(d["edad"]) / float(d["vida"])
		if u >= 1.0:
			d["vivo"] = false
			ocultar(mm, i)
			continue
		var v: Vector3 = d["vel"]
		v = v.rotated(Vector3.UP, float(d["curva"]) * delta)              # rizo: la velocidad gira despacio
		v += der * delta
		v *= maxf(1.0 - fr * delta, 0.0)
		d["vel"] = v
		d["pos"] = (d["pos"] as Vector3) + v * delta
		d["giro"] = float(d["giro"]) + float(d["giro_vel"]) * delta
		var tam: float = tamano(u, float(d["tam_k"]))
		var al: float = float(d["alargado"])
		poner(mm, i, d["pos"], tam / sqrt(al), tam * sqrt(al), float(d["giro"]), u, float(d["sem"]), 1.0)


## Medición para las pruebas: una entrada por bocanada viva: {hueco, pos, vel, u, edad, tam (m), erosion (0..1: cuánto se ha carcomido ya)}.
func estados() -> Array:
	var r: Array = []
	for i in _s.size():
		var d: Dictionary = _s[i]
		if bool(d["vivo"]):
			var u: float = float(d["edad"]) / float(d["vida"])
			r.append({"hueco": i, "pos": d["pos"], "vel": d["vel"], "u": u, "edad": float(d["edad"]), "tam": tamano(u, float(d["tam_k"])), "erosion": smoothstep(0.45, 1.0, u) * float(p["erosion"])})
	return r
