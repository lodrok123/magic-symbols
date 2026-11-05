class_name NaturalezaHojas
extends Node3D

## HOJAS POR CPU (5/11/2026, naturaleza «toy» del chamán goblin; el equivalente de hielo_esquirlas.gd / agua_gotas.gd). Un MultiMesh de quads con forma de hoja (naturaleza_hoja.gdshader) que
## mueve este nodo: NO es un GPUParticles3D y las pruebas pueden leer posición, color y vida de cada hoja (`estados()`), porque en headless el MultiMesh no guarda datos.
## El nodo es top_level: las hojas viven en el MUNDO. CAEN despacio (velocidad límite baja y balanceo, como una hoja de verdad), giran, al tocar `suelo_y` se quedan un momento y se
## apagan (se encogen y pasan de su color a `col_fin`: de verde a verde pardo, o de naranja a negro si ardían).
## Una hoja puede ir «atada» a algo (`atada` = Callable que devuelve su posición cada fotograma, para las que giran alrededor del goblin) hasta que `soltar(i)` la deja caer.

const PALETA_VERDES: Array = [
	Color(0.15, 0.50, 0.21), Color(0.26, 0.66, 0.26), Color(0.40, 0.78, 0.32), Color(0.52, 0.86, 0.38)
]
const FINAL_VERDE: Color = Color(0.34, 0.40, 0.14)             ## una hoja que se apaga se va a verde pardo
const NARANJA_FUEGO: Color = Color(0.95, 0.42, 0.10)
const NEGRO_CENIZA: Color = Color(0.10, 0.07, 0.05)

var gravedad: float = 2.2                    ## m/s² (suave: es una hoja)
var v_limite: float = 1.15                   ## m/s: velocidad de caída máxima
var suelo_y: float = -1.0e9
var _mi: MultiMeshInstance3D = null
var _s: Array = []
var _cursor: int = 0
static var _malla: QuadMesh = null
static var _material: ShaderMaterial = null


static func malla_hoja() -> QuadMesh:
	if _malla == null:
		_malla = QuadMesh.new()
		_malla.size = Vector2(1.0, 1.0)
		_malla.center_offset = Vector3(0, 0.5, 0)       # el origen en la base: igual que la brizna
		_malla.subdivide_width = 4
		_malla.subdivide_depth = 4
	return _malla


static func material(forma: int = 0, curva: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://presentacion/vfx/toy/naturaleza_hoja.gdshader") as Shader
	m.set_shader_parameter("forma", forma)
	m.set_shader_parameter("curva", curva)
	return m


## Un MultiMesh de `cantidad` quads con colores por instancia. `forma` 0 hoja, 1 brizna. Todos ocultos (escala 0).
static func crear_mm(nombre: String, cantidad: int, forma: int = 0, curva: float = 0.35) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.center_offset = Vector3(0, 0.5, 0)
	q.subdivide_width = 4
	q.subdivide_depth = 4
	mm.mesh = q
	mm.instance_count = cantidad
	var inst := MultiMeshInstance3D.new()
	inst.name = nombre
	inst.multimesh = mm
	inst.material_override = material(forma, curva)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 4.0
	for i in cantidad:
		ocultar(mm, i)
	return inst


static func ocultar(mm: MultiMesh, i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -1000, 0)))


## Pone la instancia `i`: `pos` es el CENTRO de la hoja, `rot` su orientación, `tam` el largo (m) y `ancho_rel` lo ancha que es respecto a su largo.
static func poner(mm: MultiMesh, i: int, pos: Vector3, rot: Basis, tam: float, color: Color, ancho_rel: float = 0.62) -> void:
	var b: Basis = rot * Basis.from_scale(Vector3(tam * ancho_rel, tam, tam))        # escala LOCAL (Basis.scaled escalaría en ejes del mundo y deformaría)
	mm.set_instance_transform(i, Transform3D(b, pos - rot.y * (tam * 0.5)))
	mm.set_instance_color(i, color.srgb_to_linear())                                # el color de instancia va en lineal


static func color_aleatorio(rng: RandomNumberGenerator = null) -> Color:
	var r: float = rng.randf() if rng != null else randf()
	var i: int = clampi(int(r * PALETA_VERDES.size()), 0, PALETA_VERDES.size() - 1)
	return PALETA_VERDES[i]


## Prepara la reserva: `n` huecos. El nodo pasa a top_level.
func montar(n: int, curva: float = 0.35) -> void:
	top_level = true
	transform = Transform3D.IDENTITY                 # top_level conserva la posición global que tuviera: se vuelve al origen del mundo
	_mi = crear_mm("Hojas", n, 0, curva)
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


## Una hoja nueva en `pos` (mundo) con velocidad `vel`; `vida` s; `tam` = largo en m; `col` al nacer y `col_fin` al apagarse. `giro` rad/s. Devuelve el hueco o -1 si no hay sitio.
func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, col: Color, col_fin: Color = FINAL_VERDE, giro: Vector3 = Vector3.ZERO) -> int:
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
	var g: Vector3 = giro if giro.length() > 0.01 else Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))
	_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "col": col, "col_fin": col_fin, "giro": g,
		"rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), "fase": randf() * TAU, "quieta": false, "atada": Callable(), "rozada": 0.0,
		"t_suelo": 0.0}
	return hueco


## Una hoja que sigue a `donde` (Callable -> Vector3 mundo) hasta `soltar`. Su vida no corre mientras va atada.
func emitir_atada(donde: Callable, tam: float, col: Color, vida_suelta: float = 1.2, col_fin: Color = FINAL_VERDE) -> int:
	var i: int = emitir(donde.call(), Vector3.ZERO, vida_suelta, tam, col, col_fin)
	if i >= 0:
		(_s[i] as Dictionary)["atada"] = donde
	return i


func soltar(i: int, vel: Vector3 = Vector3.ZERO) -> void:
	if i < 0 or i >= _s.size():
		return
	var d: Dictionary = _s[i]
	if bool(d["vivo"]):
		d["atada"] = Callable()
		d["vel"] = vel


func fijar_vida(i: int, vida: float) -> void:
	if i >= 0 and i < _s.size() and bool((_s[i] as Dictionary)["vivo"]):
		(_s[i] as Dictionary)["vida"] = maxf(vida, 0.05)


func poner_escala(i: int, k: float) -> void:
	if i >= 0 and i < _s.size() and bool((_s[i] as Dictionary)["vivo"]):
		(_s[i] as Dictionary)["esc"] = k


func cambiar_color(i: int, col: Color, col_fin: Color) -> void:
	if i >= 0 and i < _s.size() and bool((_s[i] as Dictionary)["vivo"]):
		(_s[i] as Dictionary)["col"] = col
		(_s[i] as Dictionary)["col_fin"] = col_fin


func vaciar() -> void:
	for i in _s.size():
		_s[i] = {"vivo": false}
	if _mi != null:
		for i in _s.size():
			ocultar(_mi.multimesh, i)


func _process(delta: float) -> void:
	avanzar(delta)


## Mueve todas `delta` s. Las pruebas pueden llamarla a mano.
func avanzar(delta: float) -> void:
	if _mi == null:
		return
	var mm: MultiMesh = _mi.multimesh
	for i in _s.size():
		var d: Dictionary = _s[i]
		if not bool(d["vivo"]):
			continue
		var atada: Callable = d["atada"]
		if atada.is_valid():
			d["pos"] = atada.call()
			var g0: Vector3 = d["giro"]
			d["rot"] = (Basis(g0.normalized(), g0.length() * delta) * (d["rot"] as Basis)).orthonormalized()
			d["edad_atada"] = float(d.get("edad_atada", 0.0)) + delta
			var esc_a: float = float(d.get("esc", 1.0)) * smoothstep(0.0, 0.3, float(d["edad_atada"]))
			poner(mm, i, d["pos"], d["rot"], float(d["tam"]) * esc_a, d["col"])
			continue
		d["edad"] = float(d["edad"]) + delta
		var u: float = float(d["edad"]) / float(d["vida"])
		if u >= 1.0:
			d["vivo"] = false
			ocultar(mm, i)
			continue
		if not bool(d["quieta"]):
			var v: Vector3 = d["vel"]
			v.y = maxf(v.y - gravedad * delta, -v_limite)
			v.x = lerpf(v.x, 0.0, clampf(1.6 * delta, 0.0, 1.0))      # el aire la frena
			v.z = lerpf(v.z, 0.0, clampf(1.6 * delta, 0.0, 1.0))
			var f: float = float(d["fase"]) + float(d["edad"]) * 4.2
			var balanceo := Vector3(sin(f), 0.0, cos(f * 0.83)) * 0.32 * (1.0 if v.y < -0.3 else 0.3)   # se mece mientras cae
			var p: Vector3 = (d["pos"] as Vector3) + (v + balanceo) * delta
			if p.y <= suelo_y:
				p.y = suelo_y + 0.01
				d["quieta"] = true
				d["vel"] = Vector3.ZERO
				# se tumba: su plano a ras del suelo
				var yaw: float = randf() * TAU
				d["rot"] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(80.0))
			else:
				d["vel"] = v
				var g: Vector3 = d["giro"]
				d["rot"] = (Basis(g.normalized(), g.length() * delta) * (d["rot"] as Basis)).orthonormalized()
			d["pos"] = p
		_pintar(mm, i, d, u)


func _pintar(mm: MultiMesh, i: int, d: Dictionary, u: float) -> void:
	var k_col: float = smoothstep(0.25, 0.95, u)
	var col: Color = (d["col"] as Color).lerp(d["col_fin"], k_col)
	var esc: float = smoothstep(1.0, 0.72, u) * smoothstep(0.0, 0.05, u)         # nace y se apaga encogiéndose (la hoja es opaca)
	poner(mm, i, d["pos"], d["rot"], float(d["tam"]) * esc, col)


## Medición para las pruebas: una entrada por hoja viva (`pos`, `col`, `edad`, `vida`, `atada`, `quieta`, `tam`).
func estados() -> Array:
	var res: Array = []
	for d in _s:
		if bool((d as Dictionary)["vivo"]):
			res.append({"pos": d["pos"], "col": d["col"], "col_fin": d["col_fin"], "edad": d["edad"], "vida": d["vida"], "atada": (d["atada"] as Callable).is_valid(), "quieta": d["quieta"], "tam": d["tam"], "vel": d["vel"]})
	return res
