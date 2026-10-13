class_name VfxKit3D
extends RefCounted

## KIT DE EFECTOS LUMINOSOS (9/10, Pipeline). Antes se llamaba Fuego3D (fuego_3d.gd); a las 12:10 Pablo pidió separarlo: este archivo
## es lo COMÚN (shader, mallas, partículas, charco, luz y las formas: bola, impacto, haz, onda, cúpula, muro, pilar) y cada elemento
## vive en `vfx_elementos/<elemento>.gd` (ElementoVfx: su rampa, su perfil y sus piezas propias). El Vfx3D pone `VfxKit3D.elemento`.
##
## Nació como FUEGO LUMINOSO (9/10, encargo de Pablo): estilo nuevo del fuego, que sustituye al facetado de tres tonos con contorno
## (decisión del 6/10) SOLO para el fuego. Es fuego aditivo: degradado blanco-amarillo → naranja → rojo en HDR (brillo > 1, para
## que el bloom del WorldEnvironment lo recoja), bordes que se deshacen por erosión de un ruido que se desplaza, un charco de luz
## en el suelo (Decal) y un quemado oscuro que se queda.
##
## 9/10 10:30: la llama pasa de aditiva (blend_add) a mezcla (blend_mix): sumada sobre el suelo claro todo el naranja viraba a
## amarillo (medido: naranja 0,8·(1, 0,48, 0,08) + hierba ≈ (1,27, 0,88, 0,39) → amarillo). Con mezcla el degradado naranja se ve
## tal cual. El brillo > 1 sigue alimentando el bloom. El anillo de luz, las brasas y el charco siguen aditivos (son luz).
##
## KIT COMÚN, pensado para reutilizarlo con los demás elementos cambiando solo la rampa (`rampa_de()`):
##   1. Un shader `spatial` de llama (CODIGO): unshaded + blend_add + depth_draw_never + cull_disabled. Ruido sin costuras que se
##      desplaza, erosión con smoothstep, rampa de color con `brillo`.
##   2. Mallas primitivas de Godot con ese shader: esfera (bola), cono (cola), cilindro (haz), media esfera (cúpula), cinta (aro de
##      la cúpula) y quads verticales (muro). Cada una dice en su doc qué `eje` del shader usa.
##   3. Pocas partículas: brasas aditivas y chispas con estela.
##   4. Decal de luz bajo el hechizo y Decal de quemado.
##   5. OmniLight3D con parpadeo (`parpadeo`) y `activar_glow(env)` para el WorldEnvironment.
##
## Todo son funciones estáticas que cuelgan nodos de `padre` (el Vfx3D) y se limpian solas; no guardan estado salvo texturas. Los
## nodos que crean llevan sus Tween atados a sí mismos, así que desaparecen con ellos.

## Ejes del shader (uniform `eje`): de dónde sale la «altura de la llama» (1 = base caliente, 0 = punta que se deshace).
const EJE_UV_Y: int = 0         ## cono, cilindro, cinta, quads: UV.y = 1 en la base y 0 en la punta
const EJE_CENTRO: int = 2       ## esfera: el centro (mirando a cámara) es la base, la silueta se deshace
const EJE_BORDE: int = 3        ## cúpula: la silueta es la base (borde brillante) y el interior se deshace

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D ruido : filter_linear, repeat_enable;
uniform sampler2D rampa : filter_linear, repeat_disable;
uniform vec2 escala_ruido = vec2(1.0, 0.6);
uniform vec2 velocidad = vec2(0.0, 0.9);      // cuánto se desplaza el ruido por segundo (y > 0 = la llama sube)
uniform float erosion = 0.4;                  // por encima de este valor se ve; más alto = llama más comida
uniform float suave = 0.15;                   // anchura del borde que se deshace
uniform float brillo = 2.4;                   // HDR: > 1 para que el bloom lo recoja
uniform float calor_max = 0.8;                // hasta dónde de la rampa llega esta capa (0,6 = naranja; 1 = blanco)
uniform int eje = 0;
uniform float base_min = 0.0;                 // suelo de la «altura»: > 0 = la punta no se come del todo (haz)
uniform float lado_ruido = 0.0;               // > 0 = la llama también se come por los costados (ruido en X, no solo en Y): contorno irregular
uniform float lateral = 0.0;                  // > 0 = los costados y el pie del quad se difuminan (tira de muro)
uniform float peso_ruido = 0.7;               // cuánto manda el ruido frente a la «altura» (bajo = degradado limpio)
uniform float potencia = 1.0;                 // cómo cae la «altura» de la llama (1 lineal, > 1 más afilada)
uniform float fresnel_pot = 2.5;
uniform float borde = 0.0;                    // brillo extra del borde por fresnel (cúpula)
uniform float corte = 2.0;                    // fracción de la altura local por encima de la cual no se pinta (< 1 = cúpula subiendo)
uniform float altura_local = 1.0;
uniform float ondula = 0.0;                   // ondulación de los vértices (haz)
uniform float ondula_freq = 5.0;
uniform float fade = 1.0;                     // 1 visible · 0 deshecha del todo
uniform float fase = 0.0;                     // desfase del ruido: que dos llamas vecinas no sean idénticas
uniform float burbujas = 0.0;                 // > 0 = segunda capa de ruido fino: huecos pequeños con borde claro (agua)
uniform float opacidad = 1.0;                 // < 1 = translúcido (agua)
uniform float curva = 0.0;                    // quads: comba en planta (unidades): el centro sale hacia delante (+Z) y los extremos no
uniform float inclina = 0.0;                  // quads: la parte de arriba se adelanta (unidades), como una ola que rompe o una llama que se dobla
uniform float ondas = 0.0;                    // > 0 = el borde de arriba hace arcos (crestas de ola): número de arcos a lo ancho del quad
uniform float borde_claro = 0.0;              // > 0 = el contorno se aclara (vidrio/agua) en vez de oscurecerse (fuego)
varying float v_alto;

void vertex() {
	v_alto = VERTEX.y / max(altura_local, 0.001);
	// Contoneo del contorno: una onda + ruido que se desplaza, para que la silueta «baile» como una llama.
	float nv = textureLod(ruido, UV * vec2(2.0, 1.0) + vec2(TIME * 0.35, -TIME * 0.9) + vec2(fase), 0.0).r - 0.5;
	float o = (sin(TIME * ondula_freq + VERTEX.y * 5.0 + VERTEX.x * 3.0 + fase * 7.0) * 0.5 + nv * 2.0) * ondula;
	VERTEX += NORMAL * o;
	// Curva ligera (Pablo, 9/10 12:58): solo se nota en quads subdivididos (la tira del muro). UV.x 0..1 a lo largo, UV.y 0 arriba.
	float cx = UV.x * 2.0 - 1.0;
	VERTEX.z += curva * (1.0 - cx * cx) + inclina * (1.0 - UV.y) * (1.0 - UV.y);
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fr = pow(1.0 - ndv, fresnel_pot);
	float base = UV.y;
	if (eje == 2) {
		base = 1.0 - fr;
	} else if (eje == 3) {
		base = fr;
	}
	if (lado_ruido > 0.0) {
		// Perfil en X: 1 en el centro del quad, 0 en los bordes. Multiplica la «altura» y el ruido muerde los lados igual que la punta.
		float sx = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 1.6);
		base *= mix(1.0, sx, lado_ruido);
	}
	if (ondas > 0.0) {
		// Ola: 1 en lo alto de cada arco y 0 en la junta entre dos; las juntas bajan, y el borde de arriba dibuja crestas.
		float arco = pow(abs(sin(UV.x * ondas * 3.14159)), 0.3);
		base -= (1.0 - arco) * 0.15;
	}
	base = pow(clamp(base, 0.0, 1.0), potencia);
	base = mix(base_min, 1.0, base);
	vec2 uv = UV * escala_ruido + TIME * velocidad + vec2(fase, fase * 0.37);
	float n = texture(ruido, uv).r;
	float f = n * peso_ruido + base * (1.25 - peso_ruido);
	float umbral = erosion + (1.0 - fade) * 0.9;
	float a = smoothstep(umbral, umbral + suave, f);
	float calor = clamp((f - umbral) / max(1.1 - umbral, 0.2), 0.0, 1.0);
	vec3 col = texture(rampa, vec2(pow(calor, 0.6) * calor_max, 0.5)).rgb * brillo;
	col += vec3(1.0, 0.55, 0.2) * fr * borde;
	if (corte < 1.5) {
		a *= 1.0 - smoothstep(corte - 0.04, corte, v_alto);
		float lin = 1.0 - smoothstep(0.0, 0.06, abs(v_alto - corte));
		col += vec3(1.0, 0.8, 0.4) * lin * brillo * 0.5;
		a = max(a, lin * 0.6 * fade);
	}
	if (lateral > 0.0) {
		// OJO: smoothstep con edge0 > edge1 es indefinido en GLSL: en Compatibilidad funcionaba y en Forward+ (Vulkan) dejaba el quad
		// lleno (el «error» del muro, 9/10). Siempre edge0 < edge1 y se invierte con 1.0 - ...
		a *= smoothstep(0.0, lateral, UV.x) * (1.0 - smoothstep(1.0 - lateral, 1.0, UV.x)) * (1.0 - smoothstep(1.0 - lateral * 0.5, 1.0, UV.y));
	}
	a *= smoothstep(0.0, 0.25, fade);
	if (borde_claro > 0.0) {
		float filo = 1.0 - smoothstep(umbral, umbral + suave + 0.1, f);
		col = mix(col, vec3(0.92, 0.98, 1.0) * brillo, filo * borde_claro);
	}
	if (burbujas > 0.0) {
		// Burbujas: ruido 4 veces más fino que sube más deprisa; donde pasa de 0,7 se abre un hueco y su borde se aclara.
		float nb = texture(ruido, UV * escala_ruido * 4.0 + vec2(fase * 1.3, -TIME * 0.9)).r;
		float hueco = smoothstep(0.66, 0.74, nb);
		float borde_b = smoothstep(0.6, 0.66, nb) * (1.0 - hueco);
		a *= 1.0 - hueco * burbujas * 0.85;
		col += vec3(0.6, 0.9, 0.9) * borde_b * burbujas * 0.6;
	}
	ALBEDO = col;
	ALPHA = clamp(a * opacidad, 0.0, 1.0);
}
"""

## Plano plano (anillo de luz, destello): textura × color × brillo, aditivo y sin luz.
const CODIGO_PLANO: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D tex : filter_linear;
uniform vec3 color = vec3(1.0, 0.6, 0.2);
uniform float brillo = 2.0;
uniform float alfa = 1.0;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * color * brillo * t.a * alfa;
	ALPHA = 1.0;
}
"""

## Elementos del kit: cada uno vive en su archivo de `vfx_elementos/` (rampa de color, perfil y, si hace falta, sus piezas propias).
## Para añadir uno: crear `vfx_elementos/<nombre>.gd` que extienda `ElementoVfx` y añadirlo aquí.
const ELEMENTOS: Dictionary = {
	"fuego": "res://poc_25d/vfx_elementos/fuego.gd",
	"agua": "res://poc_25d/vfx_elementos/agua.gd",
}
static var _elementos: Dictionary = {}       ## nombre -> ElementoVfx (instancia, se crea la primera vez)

## Elemento con el que se construye lo siguiente (rampa, luz, partículas, marca). El Vfx3D lo pone justo antes de llamar a una de
## estas funciones; todas leen el perfil al crear sus materiales, así que no importa que cambie después.
static var elemento: String = "fuego"


## ¿El kit sabe dibujar este elemento?
static func tiene(nombre: String) -> bool:
	return ELEMENTOS.has(nombre)


## El ElementoVfx de `nombre` (por defecto, el actual). Si no existe, el de fuego.
static func de(nombre: String = "") -> ElementoVfx:
	var n: String = nombre if nombre != "" else elemento
	if not ELEMENTOS.has(n):
		n = "fuego"
	if not _elementos.has(n):
		_elementos[n] = (load(String(ELEMENTOS[n])) as GDScript).new()
	return _elementos[n]


static func perfil() -> Dictionary:
	return de().perfil()

static var _sh: Shader = null
static var _sh_cerrado: Shader = null   ## la misma llama con cull_back, para mallas cerradas (ver material())
static var _sh_plano: Shader = null
static var _t_ruido: Texture2D = null
static var _t_rampas: Dictionary = {}
static var _t_mancha: Texture2D = null
static var _t_aro: Texture2D = null
static var _t_quemado: Texture2D = null
static var _m_particula: Dictionary = {}     ## elemento -> StandardMaterial3D


## --- Recursos compartidos ---

static func _shader(cerrado: bool = false) -> Shader:
	if cerrado:
		if _sh_cerrado == null:
			_sh_cerrado = Shader.new()
			_sh_cerrado.code = CODIGO.replace("cull_disabled", "cull_back")
		return _sh_cerrado
	if _sh == null:
		_sh = Shader.new()
		_sh.code = CODIGO
	return _sh


## Ruido sin costuras de 256×256. Se genera de una vez (sin NoiseTexture2D, que lo hace en otro hilo y deja unos fotogramas la
## llama sin textura la primera vez que sale).
static func ruido() -> Texture2D:
	if _t_ruido == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.022
		fn.fractal_type = FastNoiseLite.FRACTAL_FBM
		fn.fractal_octaves = 3
		fn.seed = 11
		var img: Image = fn.get_seamless_image(256, 256)
		_t_ruido = ImageTexture.create_from_image(img)
	return _t_ruido


static func rampa_de(nombre: String = "fuego") -> Texture2D:
	if not _t_rampas.has(nombre):
		var g := Gradient.new()
		var lista: Array = de(nombre).rampa()
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for e in lista:
			offs.append(float((e as Array)[0]))
			cols.append((e as Array)[1] as Color)
		g.offsets = offs
		g.colors = cols
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 128
		_t_rampas[nombre] = gt
	return _t_rampas[nombre]


static func _radial(offs: Array, alfas: Array, tam: int = 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	var cols := PackedColorArray()
	for a in alfas:
		cols.append(Color(1, 1, 1, float(a)))
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = tam
	t.height = tam
	return t


static func mancha() -> Texture2D:
	if _t_mancha == null:
		_t_mancha = _radial([0.0, 0.35, 1.0], [1.0, 0.45, 0.0])
	return _t_mancha


static func aro() -> Texture2D:
	if _t_aro == null:
		_t_aro = _radial([0.0, 0.6, 0.78, 0.9, 1.0], [0.0, 0.0, 1.0, 0.25, 0.0], 256)
	return _t_aro


## Marca de chamusco: una mancha oscura de borde irregular (el ruido muerde el contorno).
static func quemado() -> Texture2D:
	if _t_quemado == null:
		var tam: int = 128
		var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
		var fn := FastNoiseLite.new()
		fn.frequency = 0.05
		fn.seed = 5
		for y in range(tam):
			for x in range(tam):
				var d: float = Vector2(float(x) / float(tam) - 0.5, float(y) / float(tam) - 0.5).length() * 2.0
				var r: float = d + fn.get_noise_2d(float(x), float(y)) * 0.45
				var a: float = clampf((0.95 - r) / 0.45, 0.0, 1.0)
				var tono: float = 0.05 + 0.07 * clampf(r, 0.0, 1.0)
				img.set_pixel(x, y, Color(tono, tono * 0.8, tono * 0.7, a * 0.75))
		_t_quemado = ImageTexture.create_from_image(img)
	return _t_quemado


## Material de llama. `opc` pisa cualquier uniform del shader (ver CODIGO).
static func material(opc: Dictionary = {}, elem: String = "") -> ShaderMaterial:
	# `"cerrado": true` = malla cerrada (esfera, cono, cilindro): sin caras traseras. Con mezcla (blend_mix) y las dos caras, las de
	# detrás se pintan a veces encima de las de delante y salen rayas (medido en el haz).
	var m := ShaderMaterial.new()
	m.shader = _shader(bool(opc.get("cerrado", false)))
	m.set_shader_parameter("ruido", ruido())
	m.set_shader_parameter("rampa", rampa_de(elem if elem != "" else elemento))
	for k in opc:
		if String(k) != "cerrado":
			m.set_shader_parameter(String(k), opc[k])
	# Ajustes del elemento (su perfil()["mult"]): multiplican lo pedido o, si la pieza no lo pidió, el valor por defecto del shader.
	var mult: Dictionary = perfil().get("mult", {})
	for k in mult:
		var v: Variant = opc.get(k, POR_DEFECTO.get(k, 1.0))
		m.set_shader_parameter(String(k), v * float(mult[k]))
	var fijar: Dictionary = perfil().get("fijar", {})
	for k in fijar:
		m.set_shader_parameter(String(k), fijar[k])
	return m


## Valores por defecto de los uniforms que puede multiplicar un perfil (los mismos que en CODIGO).
const POR_DEFECTO: Dictionary = {"velocidad": Vector2(0.0, 0.9), "escala_ruido": Vector2(1.0, 0.6), "suave": 0.15, "potencia": 1.0,
	"ondula": 0.0}


static func _material_plano(tex: Texture2D, color: Color, brillo: float) -> ShaderMaterial:
	if _sh_plano == null:
		_sh_plano = Shader.new()
		_sh_plano.code = CODIGO_PLANO
	var m := ShaderMaterial.new()
	m.shader = _sh_plano
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("brillo", brillo)
	return m


## Calienta el shader: pinta una vez cada recurso para que el primer hechizo no dé tirón de compilación.
static func precalentar(padre: Node3D) -> void:
	ruido()
	rampa_de()
	mancha()
	aro()
	quemado()
	var r := Node3D.new()
	r.position = Vector3(0.0, -50.0, 0.0)
	padre.add_child(r)
	_malla(r, _cono(0.1, 0.3), material())
	_malla(r, _esfera(0.1), material({"eje": EJE_CENTRO}))
	var q := _quad(Vector2(0.2, 0.2), true)
	_malla(r, q, _material_plano(aro(), Color.WHITE, 1.0))
	padre.get_tree().create_timer(0.3, false).timeout.connect(r.queue_free)


## --- Mallas primitivas ---

static func _malla(padre: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


## Esfera de baja resolución (la bola de fuego es pequeña; no hace falta más). `r` = radio.
static func _esfera(r: float, mitad: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if mitad else r * 2.0
	s.is_hemisphere = mitad
	s.radial_segments = 24 if mitad else 16
	s.rings = 12 if mitad else 8
	return s


## Cono con la punta en +Y y la base en -Y (UV.y = 0 en la punta): la llama sube hacia la punta.
static func _cono(r: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = alto
	c.radial_segments = 10
	c.rings = 4
	c.cap_top = false
	c.cap_bottom = false
	return c


static func _quad(tam: Vector2, plano_suelo: bool = false, subdiv: Vector2i = Vector2i.ZERO) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = tam
	q.subdivide_width = subdiv.x            # con vértices por dentro el shader puede curvarlo (curva, inclina, ondula)
	q.subdivide_depth = subdiv.y
	if plano_suelo:
		q.orientation = PlaneMesh.FACE_Y
	else:
		q.center_offset = Vector3(0.0, tam.y * 0.5, 0.0)     # la base en y = 0
	return q


## Cinta de llama que recorre un arco de `span` radianes de radio `r`, en el plano XZ (y = 0 en el borde de abajo, `alto` arriba).
## UV.x a lo largo, UV.y de arriba (0) a abajo (1): el shader la quema por arriba. El alto se afina en las puntas.
static func _cinta(r: float, span: float, alto: float, n: int = 28, afinar: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n):
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var p: Array = []
		for t in [t0, t1]:
			var ang: float = (float(t) - 0.5) * span
			var h: float = alto * pow(sin(PI * clampf(float(t), 0.02, 0.98)), 0.6) if afinar else alto
			var radial := Vector3(cos(ang), 0.0, sin(ang))
			p.append([radial * r, radial * r + Vector3(0.0, h, 0.0), float(t)])
		var a: Array = p[0]
		var b: Array = p[1]
		var n_: Vector3 = ((a[0] as Vector3) * Vector3(1, 0, 1)).normalized()
		st.set_normal(n_)
		st.set_uv(Vector2(float(a[2]), 1.0))
		st.add_vertex(a[0] as Vector3)
		st.set_uv(Vector2(float(b[2]), 1.0))
		st.add_vertex(b[0] as Vector3)
		st.set_uv(Vector2(float(b[2]), 0.0))
		st.add_vertex(b[1] as Vector3)
		st.set_uv(Vector2(float(a[2]), 1.0))
		st.add_vertex(a[0] as Vector3)
		st.set_uv(Vector2(float(b[2]), 0.0))
		st.add_vertex(b[1] as Vector3)
		st.set_uv(Vector2(float(a[2]), 0.0))
		st.add_vertex(a[1] as Vector3)
	return st.commit()


## --- Utilidades ---

## Anima un uniform del shader de `desde` a `hasta` en `dura` s dentro de un Tween ya creado (se encadena o va en paralelo).
static func _param(tw: Tween, mat: ShaderMaterial, nombre: String, desde: float, hasta: float, dura: float) -> void:
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(nombre, v), desde, hasta, dura)


## Luz anaranjada que parpadea (energía ±25 % a ritmo irregular). Se queda hasta que se borra el nodo.
static func parpadeo(luz: OmniLight3D) -> void:
	var e: float = luz.light_energy
	var tw := luz.create_tween().set_loops()
	for i in range(4):
		tw.tween_property(luz, "light_energy", e * randf_range(0.75, 1.2), randf_range(0.05, 0.12))


static func _luz(padre: Node3D, pos: Vector3, energia: float, rango: float, color: Color = Color(0, 0, 0, 0)) -> OmniLight3D:
	if color.a == 0.0:
		color = perfil()["luz"]
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	l.position = pos
	padre.add_child(l)
	parpadeo(l)
	return l


## ¿Se pueden usar Decals? Sí en Forward+ y Mobile (el renderer del proyecto). En Compatibilidad no se dibujan (medido en la nube,
## 4.7): ahí el charco y el quemado caen a un plano plano pegado al suelo, que se ve parecido en suelo llano.
static func _usa_decal() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Charco de luz naranja bajo el hechizo: un Decal que solo emite (no pinta albedo) y se apaga con `modulate`.
static func charco(padre: Node3D, suelo: Vector3, radio: float, energia: float = 1.6, dura: float = 0.0) -> Node3D:
	if not _usa_decal():
		var q: MeshInstance3D = _malla(padre, _quad(Vector2(radio * 2.0, radio * 2.0), true), _material_plano(mancha(), perfil()["charco"], energia * 0.55))
		q.position = suelo + Vector3(0.0, 0.04, 0.0)
		if dura > 0.0:
			var twq := q.create_tween()
			twq.tween_method(func(v: float) -> void: (q.material_override as ShaderMaterial).set_shader_parameter("alfa", v), 1.0, 0.0, dura).set_ease(Tween.EASE_IN)
			twq.tween_callback(q.queue_free)
		return q
	var d := Decal.new()
	d.size = Vector3(radio * 2.0, 1.4, radio * 2.0)
	d.position = suelo + Vector3(0.0, 0.5, 0.0)
	d.texture_albedo = mancha()
	d.texture_emission = mancha()
	d.emission_energy = energia
	d.albedo_mix = 0.0
	var cc: Color = perfil()["charco"]
	d.modulate = Color(cc.r, cc.g, cc.b, 1.0)
	d.cull_mask = 1                        # solo la capa 1: no se pinta sobre los efectos
	padre.add_child(d)
	if dura > 0.0:
		var tw := d.create_tween()
		tw.tween_property(d, "modulate:a", 0.0, dura).set_ease(Tween.EASE_IN)
		tw.tween_callback(d.queue_free)
	return d


## Quemado oscuro que se queda `dura` s y se desvanece. Devuelve el Decal (o el plano de Compatibilidad).
static func chamusco(padre: Node3D, suelo: Vector3, radio: float, dura: float = 10.0, tinte: Color = Color.WHITE) -> Node3D:
	## `tinte` multiplica la marca: blanco = quemado; azul grisáceo translúcido = mojado (agua).
	var giro: float = randf() * TAU
	if not _usa_decal():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = quemado()
		m.albedo_color = tinte
		var q: MeshInstance3D = _malla(padre, _quad(Vector2(radio * 2.0, radio * 2.0), true), m)
		q.position = suelo + Vector3(0.0, 0.035, 0.0)
		q.rotation.y = giro
		var twq := q.create_tween()
		twq.tween_interval(maxf(dura - 2.5, 0.1))
		twq.tween_property(m, "albedo_color:a", 0.0, 2.5)
		twq.tween_callback(q.queue_free)
		return q
	var d := Decal.new()
	d.size = Vector3(radio * 2.0, 1.4, radio * 2.0)
	d.position = suelo + Vector3(0.0, 0.5, 0.0)
	d.rotation.y = giro
	d.texture_albedo = quemado()
	d.modulate = tinte
	d.albedo_mix = 1.0
	d.cull_mask = 1
	padre.add_child(d)
	var tw := d.create_tween()
	tw.tween_interval(maxf(dura - 2.5, 0.1))
	tw.tween_property(d, "modulate:a", 0.0, 2.5)
	tw.tween_callback(d.queue_free)
	return d


## Brasas (puntos aditivos que suben y se apagan) o chispas con estela (`chispas` = true: lazos rápidos con cola).
## Un solo GPUParticles3D, de un disparo o continuo. `pos` en coordenadas de `padre`.
static func particulas(padre: Node3D, pos: Vector3, n: int, vida: float, tam: float, vel: float, chispas: bool = false,
		continuo: bool = false, radio_emision: float = 0.1, gravedad: float = -1.5, direccion: Vector3 = Vector3.UP,
		abanico: float = 60.0) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = vida
	gp.one_shot = not continuo
	gp.explosiveness = 0.0 if continuo else 0.85
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 9, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = direccion
	pm.spread = abanico
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0.0, gravedad, 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radio_emision
	pm.scale_min = tam * 0.6
	pm.scale_max = tam * 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(0.7, 0.8))
	curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray(perfil()["particula"])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	if chispas:
		pm.particle_flag_align_y = true
	gp.process_material = pm
	if not _m_particula.has(elemento):
		# Punto/mancha aditivo que mira a cámara; el color de la partícula (rampa de arriba) multiplica, y el albedo > 1 es el HDR.
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bool(perfil()["particula_aditiva"]) else BaseMaterial3D.BLEND_MODE_MIX
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.no_depth_test = false
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.billboard_keep_scale = true
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = mancha()
		sm.albedo_color = perfil()["particula_albedo"]
		_m_particula[elemento] = sm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 1.2) if chispas else Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Z
	if chispas:
		# Chispa alargada con estela: un quad estirado en la dirección de la velocidad (align_y), siempre mirando a cámara.
		q.size = Vector2(0.12, 0.7)
	q.material = _m_particula[elemento]
	gp.draw_pass_1 = q
	gp.position = pos
	padre.add_child(gp)
	gp.emitting = true
	if not continuo:
		padre.get_tree().create_timer(vida + 0.3, false).timeout.connect(gp.queue_free)
	return gp


## --- 1. Llamita en la mano ---

## La llama pequeña que se enciende en la mano antes de soltar la bola (~0,15 s).
static func llamita(padre: Node3D, pos: Vector3, esc: float, dura: float = 0.15) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	padre.add_child(raiz)
	var mat: ShaderMaterial = material({"erosion": 0.3, "brillo": 1.3, "escala_ruido": Vector2(0.9, 0.6), "velocidad": Vector2(0.0, 1.4),
		"fade": 0.0})
	_malla(raiz, _cono(0.07 * esc, 0.32 * esc), mat).position = Vector3(0.0, 0.1 * esc, 0.0)
	var tw := raiz.create_tween()
	_param(tw, mat, "fade", 0.0, 1.0, dura * 0.6)
	tw.tween_interval(dura * 0.4)
	tw.tween_callback(raiz.queue_free)
	_luz(raiz, Vector3.ZERO, 0.8, 1.6 * esc)


## --- 2. Bola con cola de cometa ---

## La bola de fuego: núcleo que se deshace por los bordes (esfera, EJE_CENTRO), un núcleo más pequeño y blanco, y una cola de cometa
## (cono hacia atrás + dos conos laterales más finos) que se estira con la velocidad. `cabeza` es el nodo que viaja; `avance` la
## dirección del vuelo (unitaria); `f` = radio / 0,22; `vel` = unidades por segundo.
static func bola(cabeza: Node3D, avance: Vector3, f: float, esc: float, vel: float) -> void:
	var r: float = 0.3 * f * esc
	if de().bola(cabeza, avance, r, esc, vel):
		return                              # el elemento dibuja su propia bola (el agua: una burbuja)
	var envoltura: ShaderMaterial = material({"cerrado": true, "eje": EJE_CENTRO, "erosion": 0.3, "suave": 0.3, "brillo": 1.05, "calor_max": 0.95, "peso_ruido": 0.35, "potencia": 2.4, "fresnel_pot": 1.3, "ondula": 0.05 * esc, "ondula_freq": 7.0,
		"escala_ruido": Vector2(2.0, 1.4), "velocidad": Vector2(0.3, 1.2)})
	_malla(cabeza, _esfera(r * 1.15), envoltura)
	var nucleo: ShaderMaterial = material({"cerrado": true, "eje": EJE_CENTRO, "erosion": 0.42, "suave": 0.45, "brillo": 1.25, "calor_max": 1.0, "peso_ruido": 0.3, "fresnel_pot": 1.0,
		"escala_ruido": Vector2(1.5, 1.0), "velocidad": Vector2(0.0, 0.8)})
	nucleo.render_priority = 2          # con mezcla, el núcleo se pinta encima de la envoltura (si no, la envoltura lo tapa)
	_malla(cabeza, _esfera(r * 0.5), nucleo)
	# Cola: la punta mira hacia atrás (-avance). Se estira con la velocidad: ~0,7 u a 7 u/s.
	var largo: float = r * (4.0 + clampf(vel, 2.0, 16.0) * 0.45)
	var y: Vector3 = -avance.normalized()
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	var base := Basis(x, y, z)
	var colas: Array = [[0.0, 1.0, 0.0], [0.5, 0.7, 1.0], [-0.5, 0.7, -1.0]]
	for c in colas:
		var ang: float = float(c[0])
		var k: float = float(c[1])
		var mat_c: ShaderMaterial = material({"cerrado": true, "erosion": 0.36, "brillo": 1.05, "calor_max": 0.85, "peso_ruido": 0.5, "ondula": 0.05 * esc, "ondula_freq": 9.0, "escala_ruido": Vector2(0.9, 0.5),
			"velocidad": Vector2(0.0, 2.0), "fase": float(c[2]) * 0.37})
		mat_c.render_priority = -1         # la cola, por debajo de la bola
		var mi: MeshInstance3D = _malla(cabeza, _cono(r * 1.0 * k, largo * k), mat_c)
		var inclina := Basis(z, ang * 0.35)           # las laterales se abren un poco, como lenguas
		mi.basis = inclina * base
		mi.position = y * (largo * k * 0.5 + r * 0.35) + x * ang * r * 0.4   # empiezan detrás de la bola: si se solapan, la suma aditiva vira a amarillo
	particulas(cabeza, Vector3.ZERO, 22, 0.55, 0.09 * f * esc, 0.3, false, true, r * 0.8, 0.4, Vector3.UP, 180.0)
	particulas(cabeza, Vector3.ZERO, 8, 0.45, 0.1 * f * esc, 1.2, true, true, r * 0.5, -0.6, Vector3.UP, 180.0)


## --- 3. Impacto ---

## Impacto de la bola en `p`: lenguas verticales en estrella (quads que se cruzan), anillo de luz que se abre, destello, charco de
## luz y quemado en el suelo, brasas y chispas. `bucle` > 0 = lo deja ardiendo ese tiempo (extremo del haz continuo: las lenguas
## latiendo sin parar, sin quemado nuevo en cada ciclo). Devuelve la raíz (se borra sola).
static func impacto(padre: Node3D, p: Vector3, y_suelo: float, esc: float, bucle: float = 0.0) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = Vector3(p.x, y_suelo + 0.02, p.z)
	padre.add_child(raiz)
	var vida: float = 0.6 if bucle <= 0.0 else bucle
	# Lenguas
	var n: int = 6
	for i in range(n):
		var pivote := Node3D.new()
		pivote.rotation.y = float(i) / float(n) * PI + randf_range(-0.15, 0.15)
		raiz.add_child(pivote)
		var alto: float = randf_range(1.0, 1.7) * esc
		var ancho: float = randf_range(0.8, 1.2) * esc
		var mat: ShaderMaterial = material({"erosion": 0.4, "brillo": 1.1, "calor_max": 1.0, "ondula": 0.06, "ondula_freq": 8.0, "escala_ruido": Vector2(0.6, 0.45), "velocidad": Vector2(0.0, 1.5),
			"fase": randf(), "fade": 0.0})
		var mi: MeshInstance3D = _malla(pivote, _quad(Vector2(ancho, alto)), mat)
		mi.position.x = randf_range(-0.12, 0.12) * esc
		mi.rotation.z = randf_range(-0.45, 0.45)
		pivote.scale = Vector3(1.0, 0.15, 1.0)
		var tw := pivote.create_tween()
		tw.tween_property(pivote, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_param(tw, mat, "fade", 0.0, 1.0, 0.1)
		if bucle > 0.0:
			var latido := pivote.create_tween().set_loops()
			var fase_t: float = randf() * 0.2
			latido.tween_interval(fase_t)
			latido.tween_property(pivote, "scale", Vector3(1.0, randf_range(0.7, 0.9), 1.0), randf_range(0.12, 0.2))
			latido.tween_property(pivote, "scale", Vector3(1.0, randf_range(1.0, 1.15), 1.0), randf_range(0.12, 0.2))
		var tw2 := pivote.create_tween()
		tw2.tween_interval(vida * 0.45)
		_param(tw2, mat, "fade", 1.0, 0.0, vida * 0.55)
	# Anillo de luz
	var anillo: MeshInstance3D = _malla(raiz, _quad(Vector2(1.0, 1.0), true), _material_plano(aro(), perfil()["aro"], 2.2))
	anillo.scale = Vector3.ONE * 0.4 * esc
	anillo.position.y = 0.03
	var twa := anillo.create_tween().set_parallel(true)
	twa.tween_property(anillo, "scale", Vector3.ONE * 3.0 * esc, 0.45).set_ease(Tween.EASE_OUT)
	twa.tween_method(func(v: float) -> void: (anillo.material_override as ShaderMaterial).set_shader_parameter("alfa", v), 1.0, 0.0, 0.5)
	# Destello
	var flash: MeshInstance3D = _malla(raiz, _esfera(0.3 * esc), material({"eje": EJE_CENTRO, "erosion": 0.1, "brillo": 1.3, "calor_max": 1.0, "fresnel_pot": 1.0}))
	flash.position.y = 0.25 * esc
	var twf := flash.create_tween()
	twf.tween_property(flash, "scale", Vector3.ONE * 1.5, 0.1)
	twf.tween_property(flash, "scale", Vector3.ZERO, 0.12)
	twf.tween_callback(flash.queue_free)
	# Suelo: charco de luz y quemado
	charco(padre, Vector3(p.x, y_suelo, p.z), 1.7 * esc, 1.8, vida + 0.4)
	if bucle <= 0.0:
		match String(perfil()["marca"]):
			"quemado":
				chamusco(padre, Vector3(p.x, y_suelo, p.z), 0.6 * esc, 10.0)
			"mojado":
				chamusco(padre, Vector3(p.x, y_suelo, p.z), 0.7 * esc, 5.0, Color(0.35, 0.45, 0.6, 0.55))
	# Brasas y chispas
	particulas(padre, raiz.position + Vector3(0.0, 0.15, 0.0), 22, 1.1, 0.12 * esc, 3.2, false, bucle > 0.0, 0.2 * esc, -2.0, Vector3.UP, 70.0)
	particulas(padre, raiz.position + Vector3(0.0, 0.15, 0.0), 10, 0.9, 0.1 * esc, 5.0, true, bucle > 0.0, 0.15 * esc, -6.0, Vector3.UP, 55.0)
	_luz(raiz, Vector3(0.0, 0.5, 0.0), 2.4, 4.0 * esc)
	var tl := raiz.create_tween()
	tl.tween_interval(vida + 0.3)
	tl.tween_callback(raiz.queue_free)
	return raiz


## --- 4. Haz continuo (línea sola, `chorro`) ---

## Haz de llama continuo de `origen` (la mano) a `fin`, de `dura` s. La textura avanza por el haz (el ruido sube por el cilindro) y los
## vértices ondulan. Dos capas: el haz rojizo ancho y el corazón blanco fino. Crece desde la mano en ~0,25 s, y en el extremo arde el
## impacto en bucle mientras dure. Se deshace al final.
static func haz(padre: Node3D, origen: Vector3, fin: Vector3, dura: float, esc: float, y_suelo: float) -> Node3D:
	var d: Vector3 = fin - origen
	var largo: float = maxf(d.length(), 0.5)
	var dir: Vector3 = d / largo
	var raiz := Node3D.new()
	raiz.position = origen
	padre.add_child(raiz)
	var y: Vector3 = dir
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	var pivote := Node3D.new()
	pivote.basis = Basis(x, y, z)
	raiz.add_child(pivote)
	var capas: Array = [[0.42, 0.44, 1.1, 0.0, 0.92], [0.22, 0.3, 1.1, 1.7, 0.92]]   # 9/10: más grueso; 11:05 mismo color en las dos capas (Pablo: «homogeneizar»)
	var mats: Array[ShaderMaterial] = []
	var cuna_largo: float = minf(0.55 * esc + 0.15, largo * 0.3)   # la cuña ocupa el principio; el haz empieza detrás de ella
	for c in capas:
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(c[0]) * esc
		mesh.bottom_radius = float(c[0]) * 0.25 * esc
		mesh.height = largo - cuna_largo
		mesh.radial_segments = 16
		mesh.rings = 40                     # con pocos anillos la ondulación se ve a escalones
		mesh.cap_top = false
		mesh.cap_bottom = false
		var mat: ShaderMaterial = material({"cerrado": true, "erosion": float(c[1]), "brillo": float(c[2]), "calor_max": float(c[4]), "peso_ruido": 0.4, "base_min": 0.6, "escala_ruido": Vector2(0.8, largo * 0.3),
			"velocidad": Vector2(0.0, 2.6 + float(c[3]) * 0.4), "ondula": 0.035, "ondula_freq": 9.0, "fase": float(c[3]) * 0.3, "fade": 0.0,
			"potencia": 0.8})
		mats.append(mat)
		var mi: MeshInstance3D = _malla(pivote, mesh, mat)
		mi.position = Vector3(0.0, cuna_largo + (largo - cuna_largo) * 0.5, 0.0)
	# Cuña en el origen (Pablo, 9/10): el haz no sale cortado de la mano, sale de una punta. Un cono corto con la punta en la mano
	# y la base pegada al principio del haz, con el mismo material que el corazón del haz.
	var r0: float = float((capas[0] as Array)[0]) * 0.25 * esc
	var cuna := CylinderMesh.new()
	cuna.top_radius = r0
	cuna.bottom_radius = 0.0
	cuna.height = cuna_largo
	cuna.radial_segments = 16
	cuna.rings = 4
	cuna.cap_top = false
	cuna.cap_bottom = false
	var cm: MeshInstance3D = _malla(pivote, cuna, mats[mats.size() - 1])
	cm.position = Vector3(0.0, cuna_largo * 0.5, 0.0)        # punta en la mano (y = 0), base donde empieza el haz
	pivote.scale = Vector3(1.0, 0.04, 1.0)
	var tw := pivote.create_tween().set_parallel(true)
	tw.tween_property(pivote, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for m in mats:
		_param(tw, m, "fade", 0.0, 1.0, 0.22)
	# La punta que avanza: la misma bola con cola que la flecha, de la mano al extremo mientras el haz crece (lámina, fotograma 2).
	var cabeza := Node3D.new()
	cabeza.position = origen
	padre.add_child(cabeza)
	bola(cabeza, dir, 1.0, esc, largo / 0.25)
	var tc := cabeza.create_tween()
	tc.tween_property(cabeza, "position", fin, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tc.tween_callback(cabeza.queue_free)
	var fin_t: float = maxf(dura - 0.3, 0.3)
	var tw2 := raiz.create_tween()
	tw2.tween_interval(fin_t)
	for m in mats:
		_param(tw2, m, "fade", 1.0, 0.0, 0.3)
	tw2.tween_callback(raiz.queue_free)
	_luz(raiz, dir * largo * 0.5, 1.4, 3.0 + largo * 0.4)
	# Impacto en el extremo, en bucle mientras dura el haz
	var tx := padre.create_tween()
	tx.tween_interval(0.25)
	tx.tween_callback(func() -> void:
		if is_instance_valid(padre):
			impacto(padre, fin, y_suelo, esc, maxf(fin_t - 0.25, 0.2)))
	particulas(raiz, Vector3.ZERO, 14, 0.5, 0.08 * esc, 0.6, false, true, 0.05, 0.0, dir, 25.0)
	return raiz


## --- 4b. Onda ---

## Onda de fuego (Pablo, 9/10: «mete ruido en la onda»): un aro de llamas que nace en `centro` y se abre hasta `r` (unidades), con el
## borde de arriba comido por el ruido y contoneándose; deja un charco de luz y unas brasas. `dura` = lo que vive en total.
static func onda(padre: Node3D, centro: Vector3, r: float, dura: float, esc: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = centro
	padre.add_child(raiz)
	var t_total: float = maxf(dura, 0.8)
	var mat: ShaderMaterial = material({"erosion": 0.38, "brillo": 1.1, "calor_max": 0.95, "suave": 0.2, "potencia": 1.1,
		"escala_ruido": Vector2(6.0, 0.6), "velocidad": Vector2(0.25, 1.6), "ondula": 0.05, "ondula_freq": 8.0, "fade": 0.0})
	# Radio 1 y se escala: el aro crece sin rehacer la malla. El ruido da 6 vueltas enteras (sin costura).
	var aro_mi: MeshInstance3D = _malla(raiz, _cinta(1.0, TAU, 0.55 * esc + 0.15, 64, false), mat)
	aro_mi.scale = Vector3(0.15, 1.0, 0.15)
	var tw := aro_mi.create_tween().set_parallel(true)
	tw.tween_property(aro_mi, "scale", Vector3(r, 1.0, r), t_total * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_param(tw, mat, "fade", 0.0, 1.0, 0.12)
	var tf := aro_mi.create_tween()
	tf.tween_interval(t_total * 0.55)
	_param(tf, mat, "fade", 1.0, 0.0, t_total * 0.45)
	tf.tween_callback(raiz.queue_free)
	charco(raiz, Vector3.ZERO, r * 1.1, 1.3, t_total)
	particulas(raiz, Vector3(0.0, 0.1, 0.0), 24, 0.9, 0.07 * esc, r / 0.7, false, false, 0.2, -0.8, Vector3.UP, 85.0)
	_luz(raiz, Vector3(0.0, 0.5, 0.0), 1.6, 2.5 + r)
	return raiz


## --- 5. Cúpula ---

## Barrera de fuego: 2–3 cintas curvas que giran y convergen en un aro en el suelo, y luego media esfera que sube con un corte por
## altura y borde brillante por fresnel. Una sola capa por superficie (son grandes y aditivas: lo que más cuesta).
static func cupula(padre: Node3D, suelo: Vector3, r: float, dura: float, esc: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = suelo
	padre.add_child(raiz)
	var mats: Array[ShaderMaterial] = []
	# Cintas
	var cintas := Node3D.new()
	raiz.add_child(cintas)
	cintas.position.y = 0.6 * r
	var n: int = 3
	for i in range(n):
		var mat: ShaderMaterial = material({"erosion": 0.34, "brillo": 1.05, "calor_max": 0.9, "ondula": 0.05, "ondula_freq": 7.0, "escala_ruido": Vector2(1.5, 0.7), "velocidad": Vector2(0.4, 1.3),
			"fase": float(i) * 0.31, "fade": 0.0})
		mats.append(mat)
		var pivote := Node3D.new()
		pivote.rotation.y = float(i) / float(n) * TAU
		pivote.rotation.x = deg_to_rad(28.0) * (1.0 if i % 2 == 0 else -1.0)
		cintas.add_child(pivote)
		_malla(pivote, _cinta(r * 0.86, deg_to_rad(150.0), 0.5 * r + 0.3), mat)
		# Al converger se tumban al suelo y se alargan hasta cerrar el aro
		var tw := pivote.create_tween().set_parallel(true)
		tw.tween_property(pivote, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(pivote, "scale", Vector3(1.16, 0.55, 1.16), 0.5).set_trans(Tween.TRANS_QUAD)
	var giro := cintas.create_tween()
	giro.tween_property(cintas, "rotation:y", TAU * 1.3, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	giro.tween_property(cintas, "rotation:y", TAU * 1.3 + TAU * 2.0, maxf(dura, 1.0)).set_trans(Tween.TRANS_LINEAR)
	var tc := cintas.create_tween().set_parallel(true)
	tc.tween_property(cintas, "position:y", 0.04, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for m in mats:
		_param(tc, m, "fade", 0.0, 1.0, 0.25)
	# Media esfera
	var dm: ShaderMaterial = material({"eje": EJE_BORDE, "erosion": 0.42, "suave": 0.2, "brillo": 1.0, "calor_max": 0.85, "fresnel_pot": 2.0, "potencia": 0.8,
		"borde": 0.7, "escala_ruido": Vector2(3.0, 2.0), "velocidad": Vector2(0.06, 0.55), "altura_local": r, "corte": 0.0, "fade": 0.0})
	mats.append(dm)
	var cupula_mi: MeshInstance3D = _malla(raiz, _esfera(r, true), dm)
	cupula_mi.position.y = 0.0
	var td := raiz.create_tween()
	td.tween_interval(0.3)
	td.tween_callback(func() -> void: dm.set_shader_parameter("fade", 1.0))
	_param(td, dm, "corte", 0.0, 1.05, 0.55)
	# Brasas dentro, charco de luz y luz parpadeante
	var gp: GPUParticles3D = particulas(raiz, Vector3(0.0, 0.2 * r, 0.0), 16, 1.4, 0.07 * esc, 0.5, false, true, r * 0.8, 0.3, Vector3.UP, 30.0)
	charco(padre, suelo, r * 1.5, 1.4, dura + 0.8)
	_luz(raiz, Vector3(0.0, 0.5 * r, 0.0), 1.6, 3.0 + r * 1.5)
	# Fin: todo se deshace
	var tf := raiz.create_tween()
	tf.tween_interval(maxf(dura - 0.5, 0.8))
	tf.tween_callback(gp.set.bind("emitting", false))
	for m in mats:
		_param(tf, m, "fade", 1.0, 0.0, 0.5)
	tf.tween_callback(raiz.queue_free)
	return raiz


## --- 6. Muro ---

## Pared de llamas de `largo` × `alto` centrada en `centro` (en el suelo) y extendida a lo largo de `lado`: tres capas de quads
## verticales con ruido distinto (da volumen; `n_capas` 1 = una sola superficie, la más barata; hasta 3). `fase` = desfase del ruido, para que casillas vecinas no repitan.
## `crece` = nace baja y sube con la erosión bajando (el muro del hechizo); sin él nace ya hecha (la pared fija de BarreraFuego).
## Devuelve la raíz; con `dura` > 0 se deshace y se borra sola.
static func tira(padre: Node3D, centro: Vector3, lado: Vector3, largo: float, alto: float, fase: float = 0.0, crece: bool = false,
		dura: float = 0.0, retraso: float = 0.0, n_capas: int = 1, lados: float = 0.0) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = centro
	raiz.rotation.y = atan2(-lado.z, lado.x)
	padre.add_child(raiz)
	var mats: Array[ShaderMaterial] = []
	var capas: Array = [[0.0, 0.46, 1.05, 1.0], [0.09, 0.5, 0.85, 0.8], [-0.09, 0.52, 0.8, 1.15]]   # [z, erosión, brillo, velocidad]
	for i in range(mini(n_capas, capas.size())):
		var c: Array = capas[i]
		var mat: ShaderMaterial = material({"erosion": float(c[1]), "brillo": float(c[2]), "calor_max": 0.95, "ondula": 0.06, "ondula_freq": 6.0, "lateral": 0.04, "lado_ruido": lados, "escala_ruido": Vector2(largo / 1.7, alto * 0.1 / float(c[3])),
			"velocidad": Vector2(0.0, 1.6 * float(c[3])), "fase": fase + float(i) * 0.43, "potencia": 1.2, "suave": 0.18,
			"fade": 0.0 if crece else 1.0})
		de().ajustar_tira(mat, largo, alto, c)   # el elemento puede cambiar la tira (el agua la convierte en ola)
		mats.append(mat)
		var mi: MeshInstance3D = _malla(raiz, _quad(Vector2(largo, alto), false, Vector2i(24, 8)), mat)
		mi.position.z = float(c[0])
	if crece:
		raiz.scale = Vector3(1.0, 0.0001, 1.0)
		var tw := raiz.create_tween()
		tw.tween_interval(retraso)
		# 1) llamas bajas a lo largo de la línea · 2) la tira crece en alto con la erosión bajando
		tw.tween_property(raiz, "scale:y", 0.3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(raiz, "scale:y", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		var tf := raiz.create_tween()
		tf.tween_interval(retraso)
		for m in mats:
			_param(tf, m, "fade", 0.0, 1.0, 0.35)
	if dura > 0.0:
		var td := raiz.create_tween()
		td.tween_interval(retraso + maxf(dura - 0.5, 0.6))
		for m in mats:
			_param(td, m, "fade", 1.0, 0.0, 0.5)
		td.tween_callback(raiz.queue_free)
	return raiz


## Muro de fuego del hechizo (`muro`): chispas en arco → llamas bajas a lo largo de la línea → la tira crece en alto con la erosión
## bajando. Mismo reparto que `_pared`: `centro` al suelo, `lado` a lo largo de la línea.
static func muro(padre: Node3D, origen: Vector3, centro: Vector3, lado: Vector3, largo: float, alto: float, dura: float, esc: float) -> Node3D:
	alto = de().alto_muro(alto)
	# Chispas en arco desde la mano hacia la línea
	particulas(padre, origen + Vector3(0.0, 0.8, 0.0), 14, 0.5, 0.08 * esc, 3.0, true, false, 0.1, -3.0,
		(centro - origen).normalized() + Vector3(0.0, 0.7, 0.0), 35.0)
	# 9/10 11:05 (Pablo): un plano sin grosor en Z desaparece visto de canto; 3 capas separadas ±0,09 en Z le dan cuerpo.
	var t: Node3D = tira(padre, centro, lado, largo, alto, randf(), true, dura, 0.25, 3)
	particulas(padre, centro + Vector3(0.0, 0.1, 0.0), 24, 1.4, 0.1 * esc, 1.4, false, true, largo * 0.5, 0.0, Vector3.UP, 20.0).position = centro + Vector3(0.0, 0.1, 0.0)
	_luz(t, Vector3(0.0, alto * 0.45, 0.0), 1.8, 3.0 + largo * 0.4)
	charco(padre, centro, largo * 0.55, 1.4, dura + 0.6)
	return t


## PILAR (prueba de Pablo, 9/10 11:07): el muro con el ancho y el alto cambiados (x ↔ y): una columna de llamas estrecha y alta en
## `suelo`. Dos tiras cruzadas a 90° (cada una con sus 3 capas en Z) para que tenga cuerpo desde cualquier ángulo. `ancho` y `alto` en
## unidades; el Vfx3D pasa los del muro intercambiados.
static func pilar(padre: Node3D, origen: Vector3, suelo: Vector3, ancho: float, alto: float, dura: float, esc: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = suelo
	padre.add_child(raiz)
	particulas(padre, origen + Vector3(0.0, 0.8, 0.0), 10, 0.5, 0.08 * esc, 3.0, true, false, 0.1, -3.0,
		(suelo - origen).normalized() + Vector3(0.0, 0.7, 0.0), 35.0)
	for i in range(2):
		var lado := Vector3.RIGHT if i == 0 else Vector3.BACK
		tira(raiz, Vector3.ZERO, lado, ancho, alto, randf() + float(i) * 0.5, true, dura, 0.2, 3, 1.0)   # 11:19: ruido también en X
	particulas(raiz, Vector3(0.0, 0.1, 0.0), 18, 1.2, 0.09 * esc, 1.8, false, true, ancho * 0.35, 0.0, Vector3.UP, 15.0)
	_luz(raiz, Vector3(0.0, alto * 0.5, 0.0), 1.8, 2.5 + alto * 0.5)
	charco(raiz, Vector3.ZERO, ancho * 1.1, 1.4, dura + 0.6)
	var tf := raiz.create_tween()
	tf.tween_interval(dura + 0.8)
	tf.tween_callback(raiz.queue_free)
	return raiz


## --- WorldEnvironment ---

## Bloom del fuego: el umbral HDR (luminancia) es 1,6: solo lo supera el corazón del fuego (blanco-amarillo a brillo ≈ 2); el cuerpo
## naranja, el agua, los cristales y el suelo (≈ 1,0 con la luz de la maqueta) se quedan por debajo. Con la tecla K del Lab se apaga.
## OJO: en Compatibilidad no hay HDR y el suelo ya llega a 1,0; el bloom se juzga en Forward+. Se llama sobre el Environment.
static func activar_glow(env: Environment, intensidad: float = 0.55) -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return                          # medido en la nube: en Compatibilidad el bloom lava toda la escena (no hay HDR); el proyecto es Forward+
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.6
	env.glow_hdr_scale = 1.5
	env.glow_intensity = intensidad
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.4)
