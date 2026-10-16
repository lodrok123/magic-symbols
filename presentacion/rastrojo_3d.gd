class_name Rastrojo3D
extends Node3D
## El rastrojo: lo que queda donde había una mata de hierba y se quemó o se cortó (Fase 14.2 · P3, Pipeline).
##
## POR QUÉ. En Echoes of Wisdom la hierba cortada deja cuadraditos oscuros en el suelo: el mundo recuerda lo que hiciste. Hoy, al quemar,
## el shader de la hierba la encoge a un 12 % y la tiñe de pajizo (el canal R de la textura de estado), pero no deja NADA: ni tallos, ni
## mancha, y el estado se pierde en cuanto se apaga el canal. Esto es la parte que se DIBUJA de la casilla «segada».
##
## QUÉ DIBUJA, por casilla: tres matitas de tallos cortos (cada una, 6 tallos de 4–14 cm con el corte plano) y una MANCHA bajo ellas
## (un degradado irregular: oscura y densa si se quemó, verde pardo y suave si se cortó). Todo en DOS MultiMesh (matas y manchas), da
## igual cuántas casillas haya. Es solo dibujo: no colisiona ni cambia nada de la lógica.
##
## QUIÉN LO USA. La maqueta (`prueba_test2.gd`) lo cuelga y lo mueve desde `marcar_segada(c, si, quemada)`. El Juego no toca esta
## clase: marca el hecho en `EstadosSuelo3D` (estado «segada») y la maqueta lo ve por `Mundo3D.estados.cambio` (ver diario).

const TIPO_CORTADO: String = "cortado"
const TIPO_QUEMADO: String = "quemado"
const MATAS_POR_CASILLA: int = 3
const TALLOS_POR_MATA: int = 6

## Colores: el cortado sale de la hierba de la paleta (pajizo cuando se seca); el quemado, de carbón con la punta clara.
const COLOR_CORTADO: Color = Color(0.45, 0.52, 0.24)
const COLOR_QUEMADO: Color = Color(0.17, 0.14, 0.12)
const MANCHA_CORTADO: Color = Color(0.24, 0.30, 0.10, 0.34)
const MANCHA_QUEMADO: Color = Color(0.06, 0.05, 0.04, 0.58)

const CODIGO_MANCHA: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
varying vec2 uv_m;
void vertex() { uv_m = UV; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = uv_m * 2.0 - 1.0;
	float r = length(p);
	// El borde se desflecca con ruido: no es un círculo, es una mancha.
	float lim = 0.72 + 0.28 * ruido(p * 3.2 + COLOR.rg * 9.0);
	float m = 1.0 - smoothstep(lim * 0.45, lim, r);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * m;
}
"""

var lado: float = 2.3                       ## lado de la casilla (S de la maqueta)
var _casillas: Dictionary = {}              ## Vector2i -> {"tipo": String, "y": float}
var _sucio: bool = false
var _mm_matas: MultiMeshInstance3D = null
var _mm_manchas: MultiMeshInstance3D = null
var _n_matas: int = 0
var _n_manchas: int = 0
static var _malla_cache: ArrayMesh = null


## Pone (o cambia) el rastrojo de una casilla. `y` = la cara de arriba del suelo ahí.
func poner(c: Vector2i, y: float, tipo: String = TIPO_CORTADO) -> void:
	if _casillas.has(c) and (_casillas[c] as Dictionary)["tipo"] == tipo and is_equal_approx(float((_casillas[c] as Dictionary)["y"]), y):
		return
	_casillas[c] = {"tipo": tipo, "y": y}
	_pedir_reconstruir()


func quitar(c: Vector2i) -> void:
	if _casillas.erase(c):
		_pedir_reconstruir()


func limpiar() -> void:
	_casillas.clear()
	_pedir_reconstruir()


func hay(c: Vector2i) -> bool:
	return _casillas.has(c)


func tipo_de(c: Vector2i) -> String:
	return String((_casillas.get(c, {}) as Dictionary).get("tipo", ""))


func numero() -> int:
	return _casillas.size()


func n_matas() -> int:
	return _n_matas


func n_manchas() -> int:
	return _n_manchas


## Reconstruye ya, sin esperar al fin del fotograma (para las pruebas y para quien cambie muchas casillas de golpe).
func reconstruir_ahora() -> void:
	_sucio = false
	_reconstruir()


func _pedir_reconstruir() -> void:
	if _sucio:
		return
	_sucio = true
	if is_inside_tree():
		call_deferred("reconstruir_ahora")


func _enter_tree() -> void:
	if _sucio:
		call_deferred("reconstruir_ahora")


## Hash estable de la casilla: la misma casilla da siempre las mismas matas (no cambian al reconstruir).
static func _h(c: Vector2i, sal: int) -> float:
	var n: int = absi((c.x * 73856093) ^ (c.y * 19349663) ^ (sal * 83492791))
	return float(n % 10007) / 10006.0


func _reconstruir() -> void:
	for h in get_children():
		remove_child(h)          # fuera ya (no solo en cola): así los nodos nuevos conservan su nombre «matas» y «manchas»
		h.queue_free()
	_mm_matas = null
	_mm_manchas = null
	_n_matas = _casillas.size() * MATAS_POR_CASILLA
	_n_manchas = _casillas.size()
	if _casillas.is_empty():
		return
	var matas := MultiMesh.new()
	matas.transform_format = MultiMesh.TRANSFORM_3D
	matas.use_colors = true
	matas.mesh = _malla_mata()
	matas.instance_count = _n_matas
	var manchas := MultiMesh.new()
	manchas.transform_format = MultiMesh.TRANSFORM_3D
	manchas.use_colors = true
	manchas.mesh = _malla_mancha()
	manchas.instance_count = _n_manchas
	var im: int = 0
	var ik: int = 0
	for c in _casillas:
		var d: Dictionary = _casillas[c]
		var y: float = float(d["y"])
		var quemado: bool = String(d["tipo"]) == TIPO_QUEMADO
		var centro := Vector3((float(c.x) + 0.5) * lado, y, (float(c.y) + 0.5) * lado)
		# La mancha: algo mayor que la casilla en una dirección y torcida; 1 cm sobre el suelo (por encima de la sombra de contacto).
		var giro: float = _h(c, 1) * TAU
		var diam: float = lado * (0.95 + 0.25 * _h(c, 2)) * (1.0 if quemado else 0.8)
		var base := Basis(Vector3.UP, giro).scaled(Vector3(diam, 1.0, diam * (0.8 + 0.2 * _h(c, 3))))
		manchas.set_instance_transform(ik, Transform3D(base, centro + Vector3(0.0, 0.012, 0.0)))
		var mc: Color = MANCHA_QUEMADO if quemado else MANCHA_CORTADO
		manchas.set_instance_color(ik, Color(mc.r + _h(c, 4) * 0.04, mc.g + _h(c, 5) * 0.04, mc.b, mc.a))
		ik += 1
		for k in MATAS_POR_CASILLA:
			var ang: float = (float(k) + _h(c, 10 + k) * 0.7) / float(MATAS_POR_CASILLA) * TAU
			var rad: float = lado * (0.18 + 0.20 * _h(c, 20 + k))
			var pos: Vector3 = centro + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
			var esc: float = 1.1 + 0.6 * _h(c, 30 + k)
			var bm := Basis(Vector3.UP, _h(c, 40 + k) * TAU).scaled(Vector3(esc, esc * (0.8 + 0.4 * _h(c, 50 + k)), esc))
			matas.set_instance_transform(im, Transform3D(bm, pos))
			var col: Color = COLOR_QUEMADO if quemado else COLOR_CORTADO
			var v: float = 0.88 + 0.24 * _h(c, 60 + k)
			matas.set_instance_color(im, Color(col.r * v, col.g * v, col.b * v))
			im += 1
	_mm_matas = MultiMeshInstance3D.new()
	_mm_matas.name = "matas"
	_mm_matas.multimesh = matas
	add_child(_mm_matas)
	_mm_manchas = MultiMeshInstance3D.new()
	_mm_manchas.name = "manchas"
	_mm_manchas.multimesh = manchas
	_mm_manchas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm_manchas)


static func _malla_mancha() -> QuadMesh:
	var sh := Shader.new()
	sh.code = CODIGO_MANCHA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = -1
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = mat
	return q


## Una mata: TALLOS_POR_MATA prismas de tres caras que se estrechan un poco, de 4 a 14 cm, algo inclinados y con el corte plano. Los
## vértices llevan color (base más oscura, punta más clara: el corte se ve pajizo) y el color de cada instancia lo multiplica.
static func _malla_mata() -> ArrayMesh:
	if _malla_cache != null:
		return _malla_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in TALLOS_POR_MATA:
		var f: float = float(i) / float(TALLOS_POR_MATA)
		var ang: float = f * TAU + 0.4
		var r: float = 0.05 + 0.10 * fmod(f * 7.31, 1.0)
		var base := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var alto: float = 0.04 + 0.10 * fmod(f * 5.17 + 0.3, 1.0)
		var inclina := Vector3(cos(ang + 1.3), 0.0, sin(ang + 1.3)) * (alto * 0.35)
		var ancho: float = 0.018 + 0.010 * fmod(f * 3.9, 1.0)
		var b: Array[Vector3] = []
		var t: Array[Vector3] = []
		for k in 3:
			var a: float = float(k) / 3.0 * TAU + ang
			var off := Vector3(cos(a) * ancho, 0.0, sin(a) * ancho)
			b.append(base + off)
			t.append(base + off * 0.6 + Vector3(0.0, alto, 0.0) + inclina)
		var cb := Color(0.7, 0.7, 0.7)
		var ct := Color(1.0, 1.0, 1.0)
		for k in 3:
			var k2: int = (k + 1) % 3
			for q in [[b[k], cb], [b[k2], cb], [t[k2], ct], [b[k], cb], [t[k2], ct], [t[k], ct]]:
				st.set_color(q[1] as Color)
				st.add_vertex(q[0] as Vector3)
		for q in [[t[0], ct], [t[1], ct], [t[2], ct]]:         # el corte (la tapa de arriba)
			st.set_color(Color(1.0, 0.96, 0.8))
			st.add_vertex(q[0] as Vector3)
	st.generate_normals()
	var m: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	_malla_cache = m
	return m
