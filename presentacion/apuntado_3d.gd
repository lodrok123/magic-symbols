class_name Apuntado3D
extends Node3D

## EL ASPECTO DEL APUNTADO (28/10, Pablo: «darle un aspecto mejor y previsualizar mejor el apuntado»). Dueño: Juego.
##
## Qué dibuja y de dónde sale cada cosa (NADA se calcula aquí: todo viene del Lanzador o de la previsión en seco):
##   · el RECORRIDO real de cada proyectil (`PrevisionHechizo.ultimo_recorrido.caminos`, el vuelo de `HechizoVivo` en seco: arco, choque, copias), como una cinta con
##     galones que avanzan hacia donde va, y su SOMBRA punteada en el suelo cuando vuela alto (así se lee el arco en la vista isométrica);
##   · una RETÍCULA donde se para cada uno (`fines`), con cuatro marcas; en rojo y con una X si no se lanzaría, y el motivo debajo;
##   · si el hechizo no vuela (haz, volumen quieto), una cinta recta del largo de la flecha del indicador, sin retícula.
## Y presta los materiales del resto del indicador, que sigue montando `Lanzador3D` (sus nodos los miran las pruebas de A1):
##   · `material_casilla` para las casillas que ocupará (`_prev_casillas`): un FANTASMA con aristas marcadas y contorno oscuro, del alto real del hechizo (la barrera se ve
##     como un bloque, no como una alfombra); rayado en rojo si no se puede;
##   · `disco` para el origen (anillo macizo pequeño) y el alcance (anillo de guiones que gira despacio, solo si el hechizo nace donde apuntas).
## Todos los colores salen de `color_de(elemento)`: más vivos que los de las runas, porque la tierra parda o el agua sobre el agua no se veían; y todo lleva un contorno oscuro.
## Segunda tanda (28/10, «cursor y fantasma»):
##   · el FANTASMA del hechizo donde se quedará: lo que se anunciaría al dibujo (`ultimo_recorrido.volumenes`, el mismo diccionario que `hechizo_v2`), como una cúpula translúcida
##     con la textura viva de su elemento (llamas que suben, agua que corre, facetas de hielo, chispas, vetas, piedra), del tamaño de lo que golpea y en cada sitio donde nace
##     (copias, viaje). No es el VFX real (ese anima, suena y caduca): es su silueta;
##   · `imagen_cursor` para el CURSOR del ratón mientras se apunta (lo pone `Lanzador3D._poner_cursor`): una retícula del color del elemento, o roja con X.

## Color del indicador por elemento (el de la runa, pero legible sobre tierra, hierba y agua).
const COLORES: Dictionary = {
	"fuego": Color(1.0, 0.5, 0.18),
	"agua": Color(0.32, 0.68, 1.0),
	"hielo": Color(0.62, 0.96, 1.0),
	"rayo": Color(1.0, 0.92, 0.28),
	"viento": Color(0.72, 1.0, 0.78),
	"tierra": Color(0.98, 0.84, 0.48),
	"tiempo": Color(0.82, 0.62, 1.0),
}
const COLOR_NO: Color = Color(1.0, 0.25, 0.22)        ## lo que no se lanzaría
const ANCHO_CINTA: float = 0.26                        ## u
const ALTO_PARA_SOMBRA: float = 0.35                   ## u por encima del suelo: más alto que esto, el recorrido dibuja su sombra
const RADIO_RETICULA: float = 0.36                     ## en casillas
const CONTORNO_U: float = 0.035                        ## grosor del contorno oscuro de anillos y retículas (u)
const TAM_CURSOR: int = 48                             ## px del cursor (la punta, en el centro)
## Qué textura viva lleva el fantasma de cada elemento (`CODIGO_FANTASMA`, uniform `tipo`).
const TIPO_FANTASMA: Dictionary = {"fuego": 0, "agua": 1, "hielo": 2, "rayo": 3, "viento": 4, "tierra": 5}
const MAX_FANTASMAS: int = 8

const CODIGO_FANTASMA: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform int tipo = 6;
varying vec3 wp;
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float borde = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float n = 0.5;
	if (tipo == 0) {                    // fuego: lenguas que suben
		n = smoothstep(0.4, 0.75, ruido(wp * vec3(4.5, 2.4, 4.5) - vec3(0.0, TIME * 2.6, 0.0)));
	} else if (tipo == 1) {             // agua: ondas que corren
		n = 0.5 + 0.5 * sin(wp.x * 4.0 + wp.z * 3.0 + TIME * 2.5 + ruido(wp * 2.0) * 3.0);
	} else if (tipo == 2) {             // hielo: facetas quietas que destellan
		n = h3(floor(wp * 2.5));
		n = mix(n, 1.0, step(0.94, fract(n * 7.0 + TIME * 0.25)));
	} else if (tipo == 3) {             // rayo: chispas que parpadean
		n = step(0.78, ruido(wp * 4.0 + vec3(TIME * 9.0)));
	} else if (tipo == 4) {             // viento: vetas que corren en diagonal
		n = smoothstep(0.6, 0.95, 0.5 + 0.5 * sin((wp.x + wp.z) * 3.0 - wp.y * 2.0 + TIME * 4.0));
	} else if (tipo == 5) {             // tierra: piedra a trozos
		n = 0.3 + 0.7 * h3(floor(wp * vec3(3.0, 2.0, 3.0)));
	}
	float pulso = 0.9 + 0.1 * sin(TIME * 4.0);
	ALBEDO = mix(color.rgb * 0.4, min(color.rgb * 1.5, vec3(1.0)), n);
	ALPHA = clamp((0.06 + 0.5 * n + 0.55 * borde) * pulso, 0.0, 0.85);
}
"""

const CODIGO_CASILLA: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform bool invalido = false;
instance uniform vec3 tam = vec3(1.0);
varying vec3 loc;
void vertex() { loc = VERTEX; }
void fragment() {
	vec3 d = max(tam * 0.5 - abs(loc), vec3(0.0));
	float mn = min(d.x, min(d.y, d.z));
	float mx = max(d.x, max(d.y, d.z));
	float e = d.x + d.y + d.z - mn - mx;                    // distancia a la arista más cercana de la cara
	float oscuro = 1.0 - smoothstep(0.012, 0.03, e);
	float borde = 1.0 - smoothstep(0.075, 0.1, e);
	float pulso = 0.82 + 0.18 * sin(TIME * 4.0);
	float relleno = 0.18;
	if (invalido) {
		relleno = 0.32 * step(0.5, fract((loc.x + loc.z) * 2.2));
	}
	ALBEDO = mix(color.rgb, color.rgb * 0.18, oscuro);
	ALPHA = max(relleno * pulso, max(borde * 0.95 * pulso, oscuro * 0.8));
}
"""

const CODIGO_DISCO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float ancho = 0.18;        // del anillo, en radios (lo calcula `disco` desde u: el mismo grosor en un disco grande y en uno pequeño)
uniform float contorno_r = 0.05;   // el contorno oscuro, en radios
uniform float guiones = 0.0;       // 0 = anillo entero
uniform bool marcas = false;       // cuatro marcas hacia dentro (retícula)
uniform bool cruz = false;         // una X (no se puede)
uniform float giro = 0.0;          // vueltas por segundo de los guiones
float caja(vec2 p, vec2 b) { vec2 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float sd = abs(r - (1.0 - ancho * 0.5 - 0.06)) - ancho * 0.5;
	if (guiones > 0.0) {
		float a = atan(p.y, p.x) / 6.28318 + TIME * giro;
		float g = abs(fract(a * guiones) - 0.5) - 0.22;
		sd = max(sd, g * 6.28318 * r / guiones);
	}
	if (marcas) {
		float m = min(caja(abs(p) - vec2(0.0, 0.55), vec2(ancho * 0.4, 0.14)), caja(abs(p) - vec2(0.55, 0.0), vec2(0.14, ancho * 0.4)));
		sd = min(sd, m);
	}
	if (cruz) {
		float x = abs(abs(p.x) - abs(p.y)) * 0.7071 - ancho * 0.45;
		sd = min(sd, max(x, r - 0.55));
	}
	float aa = fwidth(r) * 1.5;
	float lleno = 1.0 - smoothstep(0.0, aa, sd);
	float contorno = 1.0 - smoothstep(0.0, aa, sd - contorno_r);
	float pulso = 0.85 + 0.15 * sin(TIME * 4.0);
	ALBEDO = mix(color.rgb * 0.15, color.rgb, lleno);
	ALPHA = max(lleno * 0.95, contorno * 0.65) * pulso * color.a;
}
"""

const CODIGO_CINTA: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform bool sombra = false;
uniform float largo = 1.0;
void fragment() {
	float y = abs(UV.y - 0.5) * 2.0;                       // 0 en el centro, 1 en el borde
	float u = UV.x;                                         // u recorridas desde el origen
	float entrada = smoothstep(0.0, 0.35, u) * (1.0 - smoothstep(largo - 0.1, largo, u) * 0.5);
	if (sombra) {
		float punto = step(0.5, fract(u * 3.0)) * (1.0 - smoothstep(0.35, 0.6, y));
		ALBEDO = vec3(0.05);
		ALPHA = punto * 0.45 * entrada;
	} else {
		float s = fract((u - TIME * 1.4) / 0.6);
		float galon = abs(s - y * 0.3 - 0.45) - 0.11;           // una V que avanza hacia donde va
		float aa = fwidth(u) * 2.0 / 0.6 + 0.01;
		float lleno = (1.0 - smoothstep(0.0, aa, galon)) * (1.0 - smoothstep(0.78, 0.9, y));
		float base = (1.0 - smoothstep(0.18, 0.3, y)) * 0.55;  // el hilo del centro, siempre
		float borde = smoothstep(0.82, 0.9, y) * (1.0 - smoothstep(0.95, 1.0, y));
		float pulso = 0.85 + 0.15 * sin(TIME * 4.0);
		ALBEDO = mix(color.rgb, color.rgb * 0.15, borde);
		ALPHA = max(max(lleno, base), borde * 0.6) * entrada * pulso;
	}
}
"""

static var _sh_casilla: Shader = null
static var _sh_disco: Shader = null
static var _sh_cinta: Shader = null
static var _sh_fantasma: Shader = null

## Para las pruebas: lo dibujado en el último `mostrar`.
var caminos_dibujados: Array = []          ## [PackedVector3Array]
var reticulas: Array[Vector3] = []         ## dónde quedó cada retícula (en el suelo)
var motivo_visible: String = ""

var _cintas: MeshInstance3D = null
var _sombras: MeshInstance3D = null
var _mat_cinta: ShaderMaterial = null
var _mat_sombra: ShaderMaterial = null
var _discos: Array[MeshInstance3D] = []
var _rotulo: Label3D = null
var _fantasmas: Array[MeshInstance3D] = []
## Para las pruebas: cada fantasma dibujado: {pie (en el suelo), radio, alto (u), elemento}.
var fantasmas_dibujados: Array[Dictionary] = []


static func color_de(elemento: String, reserva: Color = Color.WHITE) -> Color:
	return COLORES.get(elemento, reserva)


static func _shader(cual: String) -> Shader:
	match cual:
		"casilla":
			if _sh_casilla == null:
				_sh_casilla = Shader.new()
				_sh_casilla.code = CODIGO_CASILLA
			return _sh_casilla
		"disco":
			if _sh_disco == null:
				_sh_disco = Shader.new()
				_sh_disco.code = CODIGO_DISCO
			return _sh_disco
	if cual == "fantasma":
		if _sh_fantasma == null:
			_sh_fantasma = Shader.new()
			_sh_fantasma.code = CODIGO_FANTASMA
		return _sh_fantasma
	if _sh_cinta == null:
		_sh_cinta = Shader.new()
		_sh_cinta.code = CODIGO_CINTA
	return _sh_cinta


## La imagen del cursor de apuntar: una retícula (anillo, cuatro marcas y un punto) del color dado con contorno oscuro; con `cruz`, una X en vez de marcas y punto.
static func imagen_cursor(color: Color, cruz: bool = false) -> Image:
	var n: int = TAM_CURSOR
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = (float(n) - 1.0) * 0.5
	var oscuro := Color(0.05, 0.05, 0.08, 0.9)
	for y in range(n):
		for x in range(n):
			var p := Vector2(float(x) - c, float(y) - c)
			var r: float = p.length()
			var sd: float = absf(r - 15.0) - 2.4                                     # el anillo
			if cruz:
				sd = minf(sd, maxf(absf(absf(p.x) - absf(p.y)) * 0.7071 - 1.8, r - 11.0))
			else:
				var marca: float = minf(maxf(absf(p.x) - 1.4, absf(absf(p.y) - 7.5) - 3.0), maxf(absf(p.y) - 1.4, absf(absf(p.x) - 7.5) - 3.0))
				sd = minf(minf(sd, marca), r - 2.0)                               # las cuatro marcas y el punto del centro
			if sd <= 0.0:
				img.set_pixel(x, y, Color(color, 1.0 if sd < -0.5 else 0.7))
			elif sd <= 1.2:
				img.set_pixel(x, y, oscuro)
	return img


## El material de una casilla del hechizo. El tamaño de cada caja va por instancia: `mi.set_instance_shader_parameter("tam", tamaño)`.
static func material_casilla(color: Color, invalido: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("casilla")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("invalido", invalido)
	return m


## Un disco plano de `diametro` u, tumbado en el suelo: anillo (macizo o de guiones) de `ancho_u` u de grosor, con marcas de retícula o con una X. El contorno oscuro mide
## siempre `CONTORNO_U`, sea cual sea el tamaño.
static func disco(diametro: float, color: Color, ancho_u: float = 0.1, guiones: float = 0.0, marcas: bool = false, cruz: bool = false, giro: float = 0.0) -> MeshInstance3D:
	var radio: float = maxf(diametro * 0.5, 0.01)
	var ancho: float = ancho_u / radio
	var p := PlaneMesh.new()
	p.size = Vector2(diametro, diametro)
	var m := ShaderMaterial.new()
	m.shader = _shader("disco")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("ancho", ancho)
	m.set_shader_parameter("contorno_r", CONTORNO_U / radio)
	m.set_shader_parameter("guiones", guiones)
	m.set_shader_parameter("marcas", marcas)
	m.set_shader_parameter("cruz", cruz)
	m.set_shader_parameter("giro", giro)
	p.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func pintar_disco(mi: MeshInstance3D, color: Color, cruz: bool = false) -> void:
	var m: ShaderMaterial = (mi.mesh as PlaneMesh).material as ShaderMaterial
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("cruz", cruz)


func _ready() -> void:
	_mat_cinta = ShaderMaterial.new()
	_mat_cinta.shader = _shader("cinta")
	_mat_sombra = ShaderMaterial.new()
	_mat_sombra.shader = _shader("cinta")
	_mat_sombra.set_shader_parameter("sombra", true)
	_cintas = _malla(_mat_cinta)
	_sombras = _malla(_mat_sombra)
	_rotulo = Label3D.new()
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.no_depth_test = true
	_rotulo.font_size = 40
	_rotulo.outline_size = 12
	_rotulo.outline_modulate = Color(0, 0, 0, 0.9)
	_rotulo.pixel_size = 0.005
	_rotulo.modulate = COLOR_NO
	_rotulo.visible = false
	add_child(_rotulo)


func _malla(m: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Dibuja el recorrido. `recorrido` = `PrevisionHechizo.ultimo_recorrido`. Si no trae caminos (el hechizo no vuela): con `largo` > 0, una cinta recta de `origen` a lo largo de `dir`
## (lo que se desplaza un haz o un volumen que viaja); con `desde` (no INF), una cinta de `desde` (la jugadora) a `origen` (nace donde apuntas); si no, nada.
## `motivo` no vacío = no se lanzaría: retícula roja con X en el origen y el motivo escrito.
func mostrar(recorrido: Dictionary, origen: Vector3, dir: Vector3, largo: float, color: Color, motivo: String = "", desde: Vector3 = Vector3.INF) -> void:
	caminos_dibujados.clear()
	reticulas.clear()
	var col: Color = COLOR_NO if motivo != "" else color
	_mat_cinta.set_shader_parameter("color", col)
	var caminos: Array = recorrido.get("caminos", [])
	if motivo == "":
		for c in caminos:
			if (c as PackedVector3Array).size() >= 2:
				caminos_dibujados.append(c)
	if caminos_dibujados.is_empty() and (largo > 0.0 or desde != Vector3.INF):
		var a: Vector3 = origen if largo > 0.0 else desde
		var b: Vector3 = origen + Vector3(dir.x, 0.0, dir.z).normalized() * largo if largo > 0.0 else origen
		a.y = _y_suelo(a) + 0.12
		b.y = _y_suelo(b) + 0.12
		if Vector2(b.x - a.x, b.z - a.z).length() > 0.3:
			caminos_dibujados.append(PackedVector3Array([a, b]))
	var largo_max: float = 0.0
	var im: ImmediateMesh = _cintas.mesh as ImmediateMesh
	var sm: ImmediateMesh = _sombras.mesh as ImmediateMesh
	im.clear_surfaces()
	sm.clear_surfaces()
	var con_sombra: bool = false
	for c in caminos_dibujados:
		largo_max = maxf(largo_max, _cinta(im, c, false))
		if _vuela_alto(c):
			_cinta(sm, _a_ras(c), true)
			con_sombra = true
	_mat_cinta.set_shader_parameter("largo", largo_max)
	_mat_sombra.set_shader_parameter("largo", largo_max)
	_sombras.visible = con_sombra
	# retículas: donde se para cada proyectil (si vuela); si no se puede lanzar, una sola en el origen, con X
	var puntos: Array = []
	if motivo != "":
		puntos.append(origen)
	elif not caminos.is_empty():
		for c in caminos_dibujados:                         # donde acaba cada recorrido: lo que choca o cae (proyectil) o la punta (haz)
			var pc: PackedVector3Array = c
			puntos.append(pc[pc.size() - 1])
	var i: int = 0
	for p in puntos:
		var d: MeshInstance3D = _disco(i, col)
		pintar_disco(d, col, motivo != "")
		var pv: Vector3 = p as Vector3
		var suelo: Vector3 = Vector3(pv.x, _y_suelo(pv) + 0.1, pv.z)
		d.global_position = suelo
		d.scale = Vector3.ONE * (1.0 if puntos.size() == 1 else 0.6)       # varias copias: retículas pequeñas, que no se tapen unas a otras
		reticulas.append(suelo)
		i += 1
	for k in range(i, _discos.size()):
		_discos[k].visible = false
	_pintar_fantasmas(recorrido.get("volumenes", []) if motivo == "" else [])
	motivo_visible = motivo
	_rotulo.visible = motivo != ""
	if motivo != "":
		_rotulo.text = motivo
		_rotulo.global_position = Vector3(origen.x, _y_suelo(origen) + 0.9, origen.z)


## Los fantasmas: una cúpula por casilla que ocuparía cada volumen (`volumen.celdas`, las mismas en las que actúa), a ras de su suelo. Un haz no deja fantasma: ya se ve su recta.
func _pintar_fantasmas(volumenes: Array) -> void:
	fantasmas_dibujados.clear()
	var i: int = 0
	for vol in volumenes:
		var g: Dictionary = (vol as Dictionary).get("volumen", {})
		if g.is_empty() or g.has("haz"):
			continue
		var el: String = String((vol as Dictionary).get("elemento", ""))
		var cas: float = Terreno3D.casilla
		# Lo que ocupa de verdad son sus CASILLAS (los semiejes de una barrera son 0,1: el volumen se rasteriza y siempre incluye la del origen): una cúpula por casilla,
		# casi del ancho de la casilla y del alto de sus niveles (como mínimo, media casilla, para que se lea).
		var r_u: float = maxf(maxf(float(g.get("x", 0.0)), float(g.get("z", 0.0))) * cas, 0.42 * cas)
		var alto_u: float = clampf(maxf(float(g.get("niveles", 1)) * Terreno3D.ALTO_NIVEL, float(g.get("y", 0.0)) * cas), 0.5 * cas, 2.0 * cas)
		var origen: Vector3 = (vol as Dictionary).get("origen", Vector3.ZERO)
		var sitios: Array = []
		for c in (g.get("celdas", []) as Array):
			sitios.append(Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)))
		if sitios.is_empty():
			sitios.append(Vector3(origen.x, float(g.get("suelo", origen.y)), origen.z))
		if sitios.size() > 1:
			r_u = 0.42 * cas                                 # varias casillas: una cúpula por casilla, que no se pisen
		for st in sitios:
			if i >= MAX_FANTASMAS:
				break
			var pie: Vector3 = st
			var f: MeshInstance3D = _fantasma(i)
			var m: ShaderMaterial = f.material_override as ShaderMaterial
			m.set_shader_parameter("color", color_de(el, Color.WHITE))
			m.set_shader_parameter("tipo", int(TIPO_FANTASMA.get(el, 6)))
			f.global_position = pie
			f.scale = Vector3(r_u, alto_u, r_u)
			fantasmas_dibujados.append({"pie": pie, "radio": r_u, "alto": alto_u, "elemento": el})
			i += 1
	for k in range(i, _fantasmas.size()):
		_fantasmas[k].visible = false


## Una media esfera de radio 1 con la base en y = 0 (se escala a radio × alto × radio).
func _fantasma(i: int) -> MeshInstance3D:
	while _fantasmas.size() <= i:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 1.0
		s.is_hemisphere = true
		s.radial_segments = 24
		s.rings = 8
		var m := ShaderMaterial.new()
		m.shader = _shader("fantasma")
		var mi := MeshInstance3D.new()
		mi.mesh = s
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_fantasmas.append(mi)
	_fantasmas[i].visible = true
	return _fantasmas[i]


func _disco(i: int, col: Color) -> MeshInstance3D:
	while _discos.size() <= i:
		var d: MeshInstance3D = disco(RADIO_RETICULA * 2.0 * Terreno3D.casilla, col, 0.075, 0.0, true)
		add_child(d)
		_discos.append(d)
	_discos[i].visible = true
	return _discos[i]


## Una cinta horizontal que sigue los puntos (con UV.x = u recorridas). Devuelve su largo.
func _cinta(im: ImmediateMesh, pts: PackedVector3Array, sombra: bool) -> float:
	if pts.size() < 2:
		return 0.0
	var ancho: float = ANCHO_CINTA * (0.6 if sombra else 1.0)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var acum: float = 0.0
	for k in range(pts.size()):
		var p: Vector3 = pts[k]
		var t: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
		t.y = 0.0
		if t.length() < 0.0001:
			t = Vector3(1, 0, 0)
		var lado: Vector3 = t.normalized().cross(Vector3.UP) * ancho * 0.5
		if k > 0:
			acum += pts[k].distance_to(pts[k - 1])
		im.surface_set_uv(Vector2(acum, 0.0))
		im.surface_add_vertex(to_local(p + lado))
		im.surface_set_uv(Vector2(acum, 1.0))
		im.surface_add_vertex(to_local(p - lado))
	im.surface_end()
	return acum


func _vuela_alto(pts: PackedVector3Array) -> bool:
	for p in pts:
		if p.y - _y_suelo(p) > ALTO_PARA_SOMBRA:
			return true
	return false


func _a_ras(pts: PackedVector3Array) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(p.x, _y_suelo(p) + 0.08, p.z))
	return r


static func _y_suelo(p: Vector3) -> float:
	return Terreno3D.y_pies(Terreno3D.celda_de(p))
