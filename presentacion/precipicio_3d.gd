class_name Precipicio3D
extends Node3D

## PRECIPICIO (24/11/2026, Pablo: «haz el aspecto del precipicio en 3D»). Lo que se ve en las casillas « » (sin suelo) que quedan DENTRO del mapa
## (el paso de tierra del generador de bosques). Las del relleno de fuera del cuadrado no: esas no se ven y no son precipicio.
##   · PAREDES DE ROCA: desde el pie de cada bloque de suelo que da al hueco bajan `PROFUNDIDAD` m de roca. La pared no es plana: sus vértices
##     salen hacia el hueco con un ruido (salientes, nunca entrantes: detrás no hay nada que tape) que se anula en los cantos de cada cara, así
##     dos caras que se juntan en una esquina no dejan rendija. La textura se proyecta en el mundo (no estira) y se OSCURECE con la hondura
##     hasta el color del fondo: de arriba se ve roca, y abajo, negro.
##   · FONDO: un plano casi negro al pie de las paredes.
## Solo dibujo: la regla de qué se pisa sigue en `Terreno3D` (`es_vacio`, `pisable`).

const PROFUNDIDAD: float = 9.0            ## m que bajan las paredes desde el pie del bloque de suelo (y = 0)
const SALIENTE: float = 0.32              ## lo más que sale la roca hacia el hueco, en fracción de casilla
const TRAMOS_LADO: int = 4                ## subdivisiones de cada cara a lo ancho
const TRAMOS_ALTO: int = 7                ## y a lo alto
const COLOR_FONDO: Color = Color(0.015, 0.013, 0.02)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const CODIGO_PARED: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tinte = vec3(1.0);
uniform float escala = 0.2;
uniform float y_arriba = 0.0;
uniform float profundidad = 9.0;
uniform vec3 color_fondo : source_color = vec3(0.015, 0.013, 0.02);
uniform float luz_propia = 0.45;
varying vec3 wpos;
varying vec3 wnor;
varying float ly;          // la y de la malla (0 = pie del bloque de suelo), no la del mundo: la maqueta no tiene por qué estar en y = 0
void vertex() {
	ly = VERTEX.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = abs(wnor.x) > abs(wnor.z) ? wpos.zy : wpos.xy;
	vec3 c = texture(tex, uv * escala).rgb * tinte;
	// vetas horizontales suaves: la roca se lee en capas
	c *= 0.88 + 0.12 * sin(wpos.y * 2.1 + sin(uv.x * 0.7) * 1.3);
	// Arriba, la roca con su color; en el primer tramo se enfría (sombra azulada) y, más abajo, se va al color del fondo.
	// En metros, no en fracción de la profundidad: con la cámara del juego, a través de un hueco de 2 casillas, solo se ve el metro y medio de
	// arriba de la pared de enfrente (el resto lo tapa el borde de este lado); ahí tiene que pasar todo el degradado para que se lea hondo.
	float frio = smoothstep(y_arriba - 0.05, y_arriba - 0.6, ly);
	float hondo = pow(smoothstep(y_arriba - 0.1, y_arriba - 1.3, ly), 0.7);
	c = mix(c, c * vec3(0.45, 0.5, 0.7), frio);
	ALBEDO = mix(c, color_fondo, hondo);
	// Un poco de luz propia en la parte alta: la pared mira al hueco y la luz de la escena apenas le llega; sin esto, desde la cámara es un
	// rectángulo negro. Se apaga con la hondura.
	EMISSION = c * luz_propia * (1.0 - hondo) * (1.0 - frio * 0.6);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

var n_caras: int = 0                      ## caras de pared montadas (para las pruebas)
var n_huecos: int = 0                     ## casillas de precipicio con fondo


## Las casillas « » que NO están unidas al borde del cuadrado del mapa: los huecos de dentro. `letra` es la función del mapa (Vector2i -> String).
static func huecos_interiores(lado: int, letra: Callable) -> Array[Vector2i]:
	var fuera: Dictionary = {}
	var pila: Array[Vector2i] = []
	for i in range(lado):
		for c in [Vector2i(i, 0), Vector2i(i, lado - 1), Vector2i(0, i), Vector2i(lado - 1, i)]:
			if String(letra.call(c)) == " ":
				pila.append(c)
	while not pila.is_empty():
		var c: Vector2i = pila.pop_back()
		if fuera.has(c):
			continue
		fuera[c] = true
		for d in DIRS:
			var v: Vector2i = c + d
			if v.x >= 0 and v.y >= 0 and v.x < lado and v.y < lado and not fuera.has(v) and String(letra.call(v)) == " ":
				pila.append(v)
	var res: Array[Vector2i] = []
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if not fuera.has(c) and String(letra.call(c)) == " ":
				res.append(c)
	return res


## Monta paredes y fondo para `huecos`. `centro` (Vector2i, y) -> Vector3 es el centro de la casilla a esa altura (el de la maqueta).
## `textura`: la de la roca (null = color liso); `tinte`: su color.
func construir(huecos: Array[Vector2i], letra: Callable, centro: Callable, lado: float, textura: Texture2D, tinte: Color) -> void:
	for h in get_children():
		h.queue_free()
	n_caras = 0
	n_huecos = huecos.size()
	if huecos.is_empty():
		return
	var es_hueco: Dictionary = {}
	for c in huecos:
		es_hueco[c] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in huecos:
		for d in DIRS:
			var v: Vector2i = c + d
			if es_hueco.has(v) or String(letra.call(v)) == " ":
				continue
			_cara(st, centro.call(c, 0.0) as Vector3, d, lado)
			n_caras += 1
	st.generate_normals()
	var paredes := MeshInstance3D.new()
	paredes.name = "Paredes"
	paredes.mesh = st.commit()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CODIGO_PARED
	mat.shader = sh
	if textura != null:
		mat.set_shader_parameter("tex", textura)
	mat.set_shader_parameter("tinte", Vector3(tinte.r, tinte.g, tinte.b))
	mat.set_shader_parameter("escala", 1.0 / (lado * 1.5))
	mat.set_shader_parameter("y_arriba", 0.0)
	mat.set_shader_parameter("profundidad", PROFUNDIDAD)
	mat.set_shader_parameter("color_fondo", Vector3(COLOR_FONDO.r, COLOR_FONDO.g, COLOR_FONDO.b))
	paredes.material_override = mat
	paredes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paredes)
	# El fondo: una losa negra por casilla, al pie de las paredes.
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = lado * 0.5
	for c in huecos:
		var o: Vector3 = (centro.call(c, 0.0) as Vector3) + Vector3(0.0, -PROFUNDIDAD + 0.05, 0.0)
		var a: Vector3 = o + Vector3(-r, 0, -r)
		var b: Vector3 = o + Vector3(r, 0, -r)
		var e: Vector3 = o + Vector3(r, 0, r)
		var f: Vector3 = o + Vector3(-r, 0, r)
		for p in [a, b, e, a, e, f]:
			sf.add_vertex(p)
	var fondo := MeshInstance3D.new()
	fondo.name = "Fondo"
	fondo.mesh = sf.commit()
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = COLOR_FONDO
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	fondo.material_override = mf
	fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fondo)


## Una cara de pared: en el lado `d` de la casilla hueca de centro `o` (a la altura y = 0), mirando hacia dentro del hueco.
func _cara(st: SurfaceTool, o: Vector3, d: Vector2i, lado: float) -> void:
	var r: float = lado * 0.5
	var fuera := Vector3(d.x, 0.0, d.y)                  # hacia el suelo que hay al otro lado
	var dentro: Vector3 = -fuera                         # la roca sale hacia el hueco
	var a := Vector3(-d.y, 0.0, d.x)                     # a lo largo de la cara
	var base: Vector3 = o + fuera * r
	var puntos: Array = []
	for j in range(TRAMOS_ALTO + 1):
		var fila: Array = []
		var t_y: float = float(j) / TRAMOS_ALTO
		var y: float = 0.03 - t_y * PROFUNDIDAD              # un pelo por encima del pie del bloque: sin rendija con su costado
		for i in range(TRAMOS_LADO + 1):
			var t_a: float = float(i) / TRAMOS_LADO
			var p: Vector3 = base + a * (t_a * 2.0 - 1.0) * r + Vector3(0.0, y, 0.0)
			# Saliente: ruido por posición en el mundo (igual en las dos caras de una esquina), nulo en los cantos de la cara y arriba del todo.
			var sale: float = _ruido(p) * sin(PI * t_a) * minf(1.0, t_y * 4.0)
			fila.append(p + dentro * sale * SALIENTE * lado)
		puntos.append(fila)
	for j in range(TRAMOS_ALTO):
		for i in range(TRAMOS_LADO):
			var p00: Vector3 = puntos[j][i]
			var p10: Vector3 = puntos[j][i + 1]
			var p01: Vector3 = puntos[j + 1][i]
			var p11: Vector3 = puntos[j + 1][i + 1]
			for p in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(p)


static var _ruido_roca: FastNoiseLite = null


## 0..1, suave y estable para un punto del mundo (bultos de roca, no pinchos).
static func _ruido(p: Vector3) -> float:
	if _ruido_roca == null:
		_ruido_roca = FastNoiseLite.new()
		_ruido_roca.seed = 2411
		_ruido_roca.frequency = 0.32
		_ruido_roca.fractal_octaves = 2
	return clampf(_ruido_roca.get_noise_3dv(p) * 0.9 + 0.5, 0.0, 1.0)
