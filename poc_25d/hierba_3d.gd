class_name Hierba3D
extends Node3D

## HIERBA CON VOLUMEN sobre el suelo pintado: matojos de briznas (3D de verdad, se mecen con el viento)
## y florecitas sueltas, todo en MultiMesh (miles de copias en una sola llamada de dibujo).
## En BLOQUES de `lado_bloque` (docs/HIERBA_OPTIMIZACION.md): cada bloque tiene sus MultiMesh y su caja, así que
## Godot no dibuja los que quedan fuera de cámara; y con `actualizar(pos)` solo existen los de alrededor del
## jugador (se crean al acercarse, uno por fotograma, y se liberan al alejarse; con la misma semilla salen iguales).
## Antes: un MultiMesh para todo el mapa (~40 000 matojos dibujados siempre). Sin sombras.
##
## Uso:
##   var h := Hierba3D.new()
##   add_child(h)
##   h.sembrar(Rect2(x0, z0, ancho, fondo), altura_del_suelo, func(x, z): return peso_de_hierba)
## `peso` devuelve 0..1: 1 = hierba plena, 0 = nada (camino, piedra). En los bordes (0,3-0,7) los matojos
## salen más altos y juntos: es lo que dibuja el borde ondulado entre hierba y camino.
##
## Dos capas, que se pueden ver juntas o por separado (`set_modo`):
##   briznas  matojos 3D de color liso, hechos por código (muchos y pequeños)
##   tarjetas matojos PINTADOS (suelo_meshy/hierba_matojos.png, 2 x 2 dibujos) que miran a la cámara

## Densidad y tamaño de bloque bajados el 6/10 (Pipeline): a zoom 6 se ven ~11x7 u y se generaban 25 bloques de 9,2 u
## (~2.100 u2) con 10 matojos/u2 x 9 briznas = ~5,7 M de triángulos y un tirón de CPU (8.460 matojos por bloque nuevo).
## Ahora 3,5 matojos/u2 x 5 briznas (más anchas, para que la mata siga tapando) y bloques de 4,6 u: ~5x menos triángulos,
## el recorte por bloque es más fino y cada bloque nuevo cuesta ~1/10. El volumen lo ponen las tarjetas pintadas.
@export var densidad: float = 5.0           ## matojos por unidad cuadrada en hierba plena
@export var flores_por_unidad: float = 0.18
@export var alto_matojo: float = 0.30      ## la chibi mide ~1
@export var color_base: Color = Color(0.50, 0.72, 0.40)
@export var color_punta: Color = Color(0.86, 0.96, 0.62)
@export var viento: float = 1.0
@export var semilla: int = 7
@export var modo: int = 2                    ## 0 briznas · 1 tarjetas pintadas · 2 las dos
@export var densidad_tarjetas: float = 5.5   ## matojos pintados por unidad cuadrada
@export var alto_tarjeta: float = 0.55
@export var atlas_tarjetas: String = "res://poc_25d/suelo_meshy/hierba_matojos.png"
@export var lado_bloque: float = 4.6         ## lado de cada bloque, en unidades (2 casillas de la maqueta)
@export var radio_sembrar: int = 2           ## con actualizar(): bloques alrededor del jugador que se siembran
@export var radio_liberar: int = 4           ## ... y a partir de cuántos se liberan
@export var bloques_por_fotograma: int = 2   ## como mucho, para repartir el coste al andar (bloques pequeños: 2 cuestan menos que 1 de los viejos)
@export var brillo: float = 1.0              ## multiplica el color (la maqueta oscurece el suelo y la hierba igual)

const NOMBRES_MODO: Array = ["briznas", "tarjetas pintadas", "briznas + tarjetas"]

const COLORES_FLOR: Array = [Color(1.0, 0.78, 0.86), Color(1.0, 1.0, 0.96), Color(1.0, 0.93, 0.55),
	Color(0.80, 0.78, 1.0), Color(1.0, 0.70, 0.62)]

const CODIGO_MATOJO: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec3 base : source_color = vec3(0.50, 0.72, 0.40);
uniform vec3 punta : source_color = vec3(0.86, 0.96, 0.62);
uniform float viento = 1.0;
uniform float brillo = 1.0;
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;     // R quemado · G mojado · B helado · A pisado
uniform sampler2D crecida : hint_default_black, filter_linear, repeat_disable;    // R: 1 = hierba crecida (alta y tupida)
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform vec3 posicion_jugador = vec3(-1000.0, 0.0, -1000.0);
uniform float radio_pisar = 0.7;
varying float alto;
varying vec3 tinte;
varying float quemado;
void vertex() {
	alto = UV.y;
	tinte = INSTANCE_CUSTOM.rgb;
	vec3 origen = MODEL_MATRIX[3].xyz;
	vec2 uv_e = origen.xz / (celda * lado);
	vec4 e = texture(estado, uv_e);
	quemado = e.r;
	// Quemada: se queda en un cuarto de alto. Crecida (el agua la hace brotar): el doble de alta.
	float cre = texture(crecida, uv_e).r;
	VERTEX.y *= mix(1.0, 0.12, smoothstep(0.2, 0.8, e.r)) * mix(1.0, 1.7, cre);   // 6.14: quemada = rastrojo muy corto
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.7 + mundo.x * 0.55 + mundo.z * 0.35;
	float empuje = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * viento * alto * alto;
	float inv_x = 1.0 / max(length(MODEL_MATRIX[0].xyz), 0.001);
	float inv_z = 1.0 / max(length(MODEL_MATRIX[2].xyz), 0.001);
	VERTEX.x += empuje * 0.05 * inv_x;
	VERTEX.z += empuje * 0.025 * inv_z;
	// Pisada por celda (canal A, solo aspecto): se tumba hacia +x+z.
	float tumbar = e.a * alto * alto;
	VERTEX.x += tumbar * 0.18 * inv_x;
	VERTEX.z += tumbar * 0.10 * inv_z;
	// Se aparta de la chibi en radial.
	vec2 d = origen.xz - posicion_jugador.xz;
	float cerca = 1.0 - smoothstep(0.0, radio_pisar, length(d));
	vec2 apartar = normalize(d + vec2(0.001, 0.0)) * cerca * alto * alto * 0.3;
	VERTEX.x += apartar.x * inv_x;
	VERTEX.z += apartar.y * inv_z;
}
void fragment() {
	// La normal se fija aquí (no en vertex) porque con cull_disabled la cara de atrás la invertiría.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 c = mix(base, punta, smoothstep(0.0, 1.0, alto));
	c = mix(c, vec3(0.55, 0.49, 0.30), quemado * 0.7);   // 6.14: rastrojo pajizo, no negro
	ALBEDO = c * tinte * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## Tarjeta pintada: un cuadrado que mira siempre a la cámara, apoyado por abajo en el suelo, con uno de los
## cuatro dibujos del atlas (INSTANCE_CUSTOM.a) y la punta meciéndose con el viento.
const CODIGO_TARJETA: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float viento = 1.0;
uniform float brillo = 1.0;
uniform sampler2D estado : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D crecida : hint_default_black, filter_linear, repeat_disable;
uniform float celda = 2.3;
uniform float lado = 40.0;
uniform vec3 posicion_jugador = vec3(-1000.0, 0.0, -1000.0);
uniform float radio_pisar = 0.7;
varying vec3 tinte;
varying float quemado;
void vertex() {
	tinte = INSTANCE_CUSTOM.rgb;
	float fila = floor(INSTANCE_CUSTOM.a * 3.99);
	float alto = 1.0 - UV.y;
	UV = (UV + vec2(mod(fila, 2.0), floor(fila / 2.0))) * 0.5;
	vec3 origen = MODEL_MATRIX[3].xyz;
	vec2 uv_e = origen.xz / (celda * lado);
	vec4 e = texture(estado, uv_e);
	quemado = e.r;
	float cre = texture(crecida, uv_e).r;
	float escala_y = mix(1.0, 0.1, smoothstep(0.2, 0.8, e.r)) * mix(1.0, 1.6, cre);   // 6.14
	vec2 d = origen.xz - posicion_jugador.xz;
	float cerca = 1.0 - smoothstep(0.0, radio_pisar, length(d));
	float tumbar = (e.a + cerca) * alto * alto * 0.25;
	float esc = length(MODEL_MATRIX[0].xyz);
	vec3 der = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 arr = normalize(INV_VIEW_MATRIX[1].xyz);
	float t = TIME * 1.7 + origen.x * 0.55 + origen.z * 0.35;
	float empuje = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * viento * alto * alto * 0.12;
	vec3 mundo = origen + (der * (VERTEX.x + empuje + tumbar) + arr * VERTEX.y * escala_y) * esc;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(mundo, 1.0)).xyz;
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec4 c = texture(atlas, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = mix(c.rgb * tinte, vec3(0.55, 0.49, 0.30), quemado * 0.7) * brillo;   // 6.14: pajizo, no negro
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const CODIGO_FLOR: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D forma : filter_linear_mipmap;
uniform float brillo = 1.0;
varying vec3 tinte;
void vertex() {
	tinte = INSTANCE_CUSTOM.rgb;
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec4 f = texture(forma, UV);
	if (f.a < 0.5) {
		discard;
	}
	ALBEDO = (f.r * tinte + f.g * vec3(1.0, 0.82, 0.30)) * brillo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

var _mat_matojo: ShaderMaterial = null
var _mat_tarjeta: ShaderMaterial = null
var _mat_flor: ShaderMaterial = null
var _img_crecida: Image = null
var _tex_crecida: ImageTexture = null
var _crecida_sucia: bool = false
var _malla: ArrayMesh = null
var _quad_tarjeta: QuadMesh = null
var _quad_flor: QuadMesh = null
var _zona: Rect2 = Rect2()
var _y: float = 0.0
var _peso: Callable
var _bloques: Dictionary = {}              ## Vector2i -> Node3D con los MultiMesh del bloque (briznas, tarjetas, flores)
var _pendientes: Array[Vector2i] = []
var _centro: Vector2i = Vector2i(999999, 999999)


## Prepara materiales y mallas (una vez) y siembra. Con `alrededor = true` NO siembra nada todavía: los bloques
## salen con `actualizar(posición del jugador)` y se liberan al alejarse (docs/HIERBA_OPTIMIZACION.md §2.2).
## Con false siembra el mapa entero, igualmente en bloques (laboratorio de VFX, prerender del Test 2D).
func sembrar(zona: Rect2, y: float, peso: Callable, alrededor: bool = false) -> void:
	_zona = zona
	_y = y
	_peso = peso
	_preparar()
	if not alrededor:
		for bz in range(ceili(zona.size.y / lado_bloque)):
			for bx in range(ceili(zona.size.x / lado_bloque)):
				_crear_bloque(Vector2i(bx, bz))
		set_modo(modo)


## Llamar a menudo (cada fotograma vale: solo trabaja al cambiar de bloque) con la posición del jugador.
## Encola los bloques que faltan en `radio_sembrar` (del más cercano al más lejano), libera los que pasan de
## `radio_liberar` y crea como mucho `bloques_por_fotograma`, para repartir el coste al andar.
func actualizar(pos: Vector3, todos: bool = false) -> void:
	var c := Vector2i(floori((pos.x - _zona.position.x) / lado_bloque), floori((pos.z - _zona.position.y) / lado_bloque))
	if c != _centro:
		_centro = c
		_pendientes.clear()
		for dz in range(-radio_sembrar, radio_sembrar + 1):
			for dx in range(-radio_sembrar, radio_sembrar + 1):
				var b := c + Vector2i(dx, dz)
				if _dentro(b) and not _bloques.has(b):
					_pendientes.append(b)
		_pendientes.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool:
			return (a - c).length_squared() < (b2 - c).length_squared())
		for b in _bloques.keys():
			if ((b as Vector2i) - c).length_squared() > radio_liberar * radio_liberar:
				(_bloques[b] as Node3D).queue_free()
				_bloques.erase(b)
	var n: int = 0
	while (todos or n < bloques_por_fotograma) and not _pendientes.is_empty():
		_crear_bloque(_pendientes.pop_front())
		n += 1


## Cambia el radio (p. ej. al alejar la cámara) y vuelve a mirar qué falta en el próximo actualizar().
func set_radio(r: int) -> void:
	if r == radio_sembrar:
		return
	radio_sembrar = r
	radio_liberar = r + 2
	_centro = Vector2i(999999, 999999)


func _dentro(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and float(b.x) * lado_bloque < _zona.size.x and float(b.y) * lado_bloque < _zona.size.y


func _preparar() -> void:
	if _malla != null:
		return
	_mat_matojo = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CODIGO_MATOJO
	_mat_matojo.shader = sh
	_mat_matojo.set_shader_parameter("base", color_base)
	_mat_matojo.set_shader_parameter("punta", color_punta)
	_mat_matojo.set_shader_parameter("viento", viento)
	_mat_matojo.set_shader_parameter("brillo", brillo)
	_malla = _malla_matojo()
	_malla.surface_set_material(0, _mat_matojo)
	if ResourceLoader.exists(atlas_tarjetas):
		_mat_tarjeta = ShaderMaterial.new()
		var sht := Shader.new()
		sht.code = CODIGO_TARJETA
		_mat_tarjeta.shader = sht
		_mat_tarjeta.set_shader_parameter("atlas", load(atlas_tarjetas) as Texture2D)
		_mat_tarjeta.set_shader_parameter("viento", viento)
		_mat_tarjeta.set_shader_parameter("brillo", brillo)
		_quad_tarjeta = QuadMesh.new()
		_quad_tarjeta.size = Vector2(1.0, 1.0)
		_quad_tarjeta.center_offset = Vector3(0.0, 0.5, 0.0)
		_quad_tarjeta.material = _mat_tarjeta
	_mat_flor = ShaderMaterial.new()
	var shf := Shader.new()
	shf.code = CODIGO_FLOR
	_mat_flor.shader = shf
	_mat_flor.set_shader_parameter("forma", _textura_flor())
	_mat_flor.set_shader_parameter("brillo", brillo)
	_quad_flor = QuadMesh.new()
	_quad_flor.size = Vector2(1.0, 1.0)
	_quad_flor.orientation = PlaneMesh.FACE_Y
	_quad_flor.material = _mat_flor


## Un bloque: briznas, tarjetas y flores de su rectángulo, con semilla propia (sale igual si se vuelve a crear).
func _crear_bloque(b: Vector2i) -> void:
	var rect := Rect2(_zona.position + Vector2(b) * lado_bloque, Vector2(lado_bloque, lado_bloque)).intersection(_zona)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, b.x, b.y])
	var padre := Node3D.new()
	padre.name = "Bloque_%d_%d" % [b.x, b.y]
	add_child(padre)
	_bloques[b] = padre
	# Briznas: rejilla con jitter; en el borde (peso 0,3-0,7) más altas, la "franja" que pisa el camino.
	var matojos: Array[Transform3D] = []
	var tintes_m: PackedColorArray = PackedColorArray()
	var paso: float = 1.0 / sqrt(maxf(densidad, 0.01))
	for iz in range(int(rect.size.y / paso)):
		for ix in range(int(rect.size.x / paso)):
			var x: float = rect.position.x + (float(ix) + rng.randf()) * paso
			var z: float = rect.position.y + (float(iz) + rng.randf()) * paso
			var w: float = float(_peso.call(x, z))
			if w <= 0.02 or rng.randf() > w * 1.15:
				continue
			var borde: float = 1.0 - absf(w - 0.5) * 2.0
			var s: float = alto_matojo * (0.75 + rng.randf() * 0.5) * (1.0 + borde * 0.6)
			matojos.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, _y, z)))
			var v: float = 0.9 + rng.randf() * 0.2
			tintes_m.append(Color(v, v * (0.97 + rng.randf() * 0.06), v * (0.95 + rng.randf() * 0.08)))
	_multimalla(_malla, matojos, tintes_m, padre, "briznas")
	# Tarjetas pintadas: menos y algo más grandes; también más altas en el borde.
	if _quad_tarjeta != null:
		var trs: Array[Transform3D] = []
		var tintes: PackedColorArray = PackedColorArray()
		var paso_t: float = 1.0 / sqrt(maxf(densidad_tarjetas, 0.01))
		for iz in range(int(rect.size.y / paso_t)):
			for ix in range(int(rect.size.x / paso_t)):
				var x2: float = rect.position.x + (float(ix) + rng.randf()) * paso_t
				var z2: float = rect.position.y + (float(iz) + rng.randf()) * paso_t
				var w2: float = float(_peso.call(x2, z2))
				if w2 <= 0.05 or rng.randf() > w2 * 1.1:
					continue
				var borde2: float = 1.0 - absf(w2 - 0.5) * 2.0
				var s2: float = alto_tarjeta * (0.8 + rng.randf() * 0.45) * (1.0 + borde2 * 0.35)
				trs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s2, s2, s2)), Vector3(x2, _y, z2)))
				var v2: float = 0.92 + rng.randf() * 0.14
				# Los dibujos con flor (0 y 1) salen menos que los de solo hierba (2 y 3).
				var celda: float = [0.0, 1.0, 2.0, 2.0, 3.0, 3.0, 3.0][rng.randi() % 7]
				tintes.append(Color(v2, v2, v2 * (0.96 + rng.randf() * 0.06), (celda + 0.5) / 4.0))
		_multimalla(_quad_tarjeta, trs, tintes, padre, "tarjetas")
	# Flores: pocas, solo en hierba plena, a veces en grupitos de 2-3.
	var flores: Array[Transform3D] = []
	var tintes_f: PackedColorArray = PackedColorArray()
	for i in range(int(rect.get_area() * flores_por_unidad)):
		var x3: float = rect.position.x + rng.randf() * rect.size.x
		var z3: float = rect.position.y + rng.randf() * rect.size.y
		if float(_peso.call(x3, z3)) < 0.85:
			continue
		var col: Color = COLORES_FLOR[rng.randi() % COLORES_FLOR.size()]
		for k in range(1 + rng.randi() % 3):
			var p := Vector3(x3 + rng.randf_range(-0.18, 0.18), _y + 0.07 + rng.randf() * 0.05,
				z3 + rng.randf_range(-0.18, 0.18))
			var sf: float = 0.15 + rng.randf() * 0.06
			var bf := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			flores.append(Transform3D(bf.scaled(Vector3(sf, sf, sf)), p))
			tintes_f.append(col)
	_multimalla(_quad_flor, flores, tintes_f, padre, "flores")
	# Caja del bloque: el rectángulo + 1 u de margen (el viento y las tarjetas que miran a la cámara sobresalen).
	var caja := AABB(Vector3(rect.position.x - 1.0, _y - 0.5, rect.position.y - 1.0),
		Vector3(rect.size.x + 2.0, 2.5, rect.size.y + 2.0))
	for h in padre.get_children():
		(h as MultiMeshInstance3D).custom_aabb = caja
	_aplicar_modo(padre)


## 0 briznas · 1 tarjetas pintadas · 2 las dos.
func set_modo(m: int) -> void:
	modo = posmod(m, 3)
	for b in _bloques:
		_aplicar_modo(_bloques[b] as Node3D)


func _aplicar_modo(padre: Node3D) -> void:
	var hay_tarjetas: bool = _quad_tarjeta != null
	for h in padre.get_children():
		if h.name == "briznas":
			(h as Node3D).visible = modo != 1 or not hay_tarjetas
		elif h.name == "tarjetas":
			(h as Node3D).visible = modo != 0


## Matojos (briznas) de los bloques que hay ahora mismo.
func numero_de_matojos() -> int:
	var n: int = 0
	for b in _bloques:
		var br: Node = (_bloques[b] as Node).get_node_or_null("briznas")
		if br != null:
			n += (br as MultiMeshInstance3D).multimesh.instance_count
	return n


## Bloques de hierba creados ahora mismo (con `actualizar`, solo los de alrededor del jugador).
func numero_de_bloques() -> int:
	return _bloques.size()


## Textura de estado del suelo (R quemado · G mojado · B helado · A pisado) y la rejilla que la indexa.
## También crea la capa de hierba CRECIDA (un estado del objeto hierba, no del suelo: ESTADOS_SUELO.md §4.4).
func set_estado(tex: Texture2D, celda: float, lado: float) -> void:
	_img_crecida = Image.create_empty(int(lado), int(lado), false, Image.FORMAT_R8)
	_img_crecida.fill(Color(0.0, 0.0, 0.0, 1.0))
	_tex_crecida = ImageTexture.create_from_image(_img_crecida)
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("estado", tex)
			m.set_shader_parameter("crecida", _tex_crecida)
			m.set_shader_parameter("celda", celda)
			m.set_shader_parameter("lado", lado)


## Dónde está la chibi: las matas cercanas se apartan.
func set_posicion_jugador(p: Vector3) -> void:
	for m in [_mat_matojo, _mat_tarjeta]:
		if m != null:
			m.set_shader_parameter("posicion_jugador", p)


## Hierba crecida de una casilla (0 = fina, 1 = alta). Se sube a la GPU al llamar a `subir_crecida()`.
func set_crecida(c: Vector2i, valor: float) -> void:
	if _img_crecida == null or c.x < 0 or c.y < 0 or c.x >= _img_crecida.get_width() or c.y >= _img_crecida.get_height():
		return
	_img_crecida.set_pixel(c.x, c.y, Color(valor, 0.0, 0.0, 1.0))
	_crecida_sucia = true


func subir_crecida() -> void:
	if _crecida_sucia and _tex_crecida != null:
		_tex_crecida.update(_img_crecida)
		_crecida_sucia = false


func set_viento(v: float) -> void:
	viento = v
	if _mat_matojo != null:
		_mat_matojo.set_shader_parameter("viento", v)
	if _mat_tarjeta != null:
		_mat_tarjeta.set_shader_parameter("viento", v)


## Un matojo: 5 briznas curvadas que salen del centro (alto 1, se escala por copia). UV.y = altura 0..1.
func _malla_matojo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(5):
		var ang: float = float(i) / 5.0 * TAU + rng.randf() * 0.5
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var lado := Vector3(-dir.z, 0.0, dir.x)
		var alto: float = 0.7 + rng.randf() * 0.5
		var inclin: float = 0.18 + rng.randf() * 0.3
		var ancho: float = 0.21 + rng.randf() * 0.06     ## más ancha: son 5 briznas y no 9
		var base: Vector3 = dir * 0.12 * rng.randf()
		var medio: Vector3 = base + dir * inclin * 0.35 + Vector3.UP * alto * 0.55
		var punta: Vector3 = base + dir * inclin + Vector3.UP * alto
		# Dos tramos (base ancha -> medio -> punta) para que la brizna se curve.
		var a0: Vector3 = base - lado * ancho
		var a1: Vector3 = base + lado * ancho
		var m0: Vector3 = medio - lado * ancho * 0.6
		var m1: Vector3 = medio + lado * ancho * 0.6
		for v in [[a0, 0.0], [a1, 0.0], [m1, 0.55], [a0, 0.0], [m1, 0.55], [m0, 0.55],
				[m0, 0.55], [m1, 0.55], [punta, 1.0]]:
			st.set_uv(Vector2(0.5, float(v[1])))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0] as Vector3)
	return st.commit()


## Flor de 5 pétalos: R = pétalo (se tiñe), G = centro (amarillo), A = recorte.
func _textura_flor() -> ImageTexture:
	var n: int = 64
	var img := Image.create_empty(n, n, true, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in range(n):
		for x in range(n):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r: float = p.length() / (float(n) * 0.5)
			var ang: float = atan2(p.y, p.x)
			var petalo: float = 0.62 + 0.36 * absf(cos(ang * 2.5))
			var col := Color(0, 0, 0, 0)
			if r < 0.26:
				col = Color(0.0, 1.0, 0.0, 1.0)
			elif r < petalo:
				var sombra: float = 0.82 + 0.18 * (r / petalo)
				col = Color(sombra, 0.0, 0.0, 1.0)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _multimalla(malla: Mesh, trs: Array[Transform3D], tintes: PackedColorArray, padre: Node3D, nombre: String) -> void:
	if trs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = trs.size()
	for i in range(trs.size()):
		mm.set_instance_transform(i, trs[i])
		mm.set_instance_custom_data(i, tintes[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
