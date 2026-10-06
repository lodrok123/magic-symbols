class_name Formas3D
extends RefCounted

## FORMAS 3D DE BAJA POLIGONIZACIÓN para los efectos (6/10, Pipeline; pedido de Pablo: «partículas directamente en 3D, como
## Link's Awakening»). Sustituye a los sprites planos de vfx/ en Vfx3D: cada partícula es una pieza con volumen.
##
## Estilo: facetas planas con TRES tonos (luz, media, sombra) cocidos en el color de vértice según hacia dónde mira cada cara, y
## un contorno grueso oscuro (casco invertido: la misma malla inflada y con las caras vueltas). El material no lleva iluminación
## (el tono ya está en la malla), así que se ve igual con cualquier luz y con la cámara a 60°, y una pieza cuesta 2 llamadas
## de dibujo en cualquier cantidad (todas las copias comparten malla y material).
##
##   var m: ArrayMesh = Formas3D.malla("llama")                      # para GPUParticles3D.draw_pass_1 (el color lo pone el color_ramp)
##   var mi: MeshInstance3D = Formas3D.instancia("cristal", Color(0.7, 0.92, 1.0))   # una pieza suelta, teñida
##
## Todas miden ~1 unidad. Las «de pie» (llama, cristal, pua, corona, rayo) tienen la base en y = 0; las demás están centradas.
## Las planas (anillo, runa, grieta, disco) son decales tumbados en y = 0, de doble cara y sin contorno.

const NOMBRES: Array = ["llama", "ascua", "nube", "burbuja", "gota", "chispa", "estrella", "copo", "hoja", "piedra",
	"cristal", "pua", "corona", "rayo", "remolino", "anillo", "runa", "grieta", "disco", "telarana"]
const PLANAS: Array = ["anillo", "runa", "grieta", "disco"]
const DOBLE_CARA: Array = ["remolino", "anillo", "runa", "grieta", "disco", "telarana"]
## Sin contorno inflado: hilos finos (la telaraña de pie, en el plano XY, radio 1).
const SIN_CONTORNO: Array = ["telarana"]
## PIEZAS DE EFECTO (12:49, Pablo: «las llamas parecen un dibujo, no un efecto; contornos muy definidos y colores de sprite»).
## Fuego, brasas, chispas, destellos y rayos NO llevan contorno ni tonos planos de dibujo: son facetas translúcidas con degradado
## de la base a la punta (blanco amarillento → naranja → rojo que se desvanece), sin iluminación y con mezcla ADITIVA, que brilla
## y se funde con lo de detrás como el fuego de Breath of the Wild. El humo (nube) es gris translúcido, mezcla normal, sin contorno.
## La llama va en mezcla NORMAL translúcida (no aditiva): sobre el suelo claro de pastel la aditiva se quema a blanco.
const EFECTO_ADITIVO: Array = ["ascua", "chispa", "estrella", "rayo"]
const EFECTO_SUAVE: Array = ["nube"]
## La llama es una lengua lisa con su propio shader (CODIGO_FUEGO).
const FUEGO: Array = ["llama"]

## SHADER DEL FUEGO (13:06, Pablo, con capturas de Link's Awakening: «lengua de fuego prominente hacia una dirección» y «muro de fuego»).
## El fuego del LA no es un dibujo facetado: es una lengua LISA y translúcida, con el corazón amarillo claro, los bordes naranjas que se
## deshacen y la punta que se apaga, que ondula sin parar y se inclina hacia un lado. Eso se hace aquí con una malla lisa y este shader:
##   - núcleo/borde por FRESNEL (donde la malla mira a la cámara es el corazón; en la silueta se vuelve naranja y transparente);
##   - ondulación por vértice con TIME (más cuanto más arriba) y una inclinación `lean` hacia `dir_lean`; la fase sale de la posición de
##     cada instancia, así que ninguna lengua ondula igual que otra (sirve igual para mallas sueltas y para partículas);
##   - `COLOR` (el de la partícula o del vértice) tiñe y desvanece, como en el resto de efectos.
const CODIGO_FUEGO: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 col_nucleo : source_color = vec4(1.0, 0.96, 0.62, 1.0);
uniform vec4 col_medio : source_color = vec4(1.0, 0.64, 0.16, 1.0);
uniform vec4 col_borde : source_color = vec4(0.93, 0.30, 0.07, 1.0);
uniform vec4 tinte : source_color = vec4(1.0);
uniform float lean = 0.22;
uniform vec2 dir_lean = vec2(1.0, 0.25);
uniform float onda = 0.11;
uniform float vel = 4.0;
uniform float ruido = 0.55;       // cuánto rompe el ruido la lengua (0 = lisa)
uniform float ruido_esc = 3.2;    // tamaño del ruido
uniform float ruido_vel = 2.4;    // lo rápido que sube
const float ALTURA = 1.6;
varying float hh;
varying float fase;
varying vec3 vp;
float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
varying vec4 tint_v;
void vertex() {
	hh = clamp(VERTEX.y / ALTURA, 0.0, 1.0);
	vp = VERTEX;
	tint_v = COLOR;
	vec2 pos = MODEL_MATRIX[3].xz;
	float ph = fract(sin(dot(pos, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	fase = ph;
	float k = hh * hh;
	vec2 d = normalize(dir_lean);
	float giro = (ph - 3.1415) * 0.18;
	d = vec2(d.x * cos(giro) - d.y * sin(giro), d.x * sin(giro) + d.y * cos(giro));
	VERTEX.xz += d * lean * ALTURA * k;
	VERTEX.x += sin(TIME * vel + ph + VERTEX.y * 3.4) * onda * ALTURA * k;
	VERTEX.z += cos(TIME * vel * 0.83 + ph * 1.7 + VERTEX.y * 2.9) * onda * ALTURA * k;
	VERTEX.y *= 1.0 + 0.07 * sin(TIME * vel * 1.7 + ph);
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.8);
	// rizos de calor que suben por la lengua (las franjas claras del fuego del LA)
	float rizo = 0.5 + 0.5 * sin(hh * 11.0 - TIME * 5.5 + fase);
	// FILTRO DE RUIDO: dos octavas de ruido de valor que suben por la lengua; rompen el borde en jirones y mueven el calor
	vec3 q = vec3(vp.x, vp.y * 0.8 - TIME * ruido_vel, vp.z) * ruido_esc + fase;
	float nz = vnoise(q) * 0.65 + vnoise(q * 2.1 + 7.3) * 0.35;
	float calor = clamp(1.0 - fres * 0.95 - hh * 0.38 + (rizo - 0.5) * 0.18 + (nz - 0.5) * 0.35 * ruido, 0.0, 1.0);
	vec3 c = mix(col_borde.rgb, col_medio.rgb, smoothstep(0.0, 0.40, calor));
	c = mix(c, col_nucleo.rgb, smoothstep(0.34, 0.78, calor));
	ALBEDO = c * tint_v.rgb * tinte.rgb;
	float a = (1.0 - smoothstep(0.35, 1.0, fres)) * (1.0 - smoothstep(0.55, 1.0, hh));
	// el ruido muerde más arriba y en el borde: la punta se deshace en jirones, la base queda entera
	a *= smoothstep(0.0, 1.0, (nz + (1.0 - hh) * 0.55 + (1.0 - fres) * 0.25 - 0.45 * ruido) / (1.0 - 0.45 * ruido + 0.001) * 1.15);
	ALPHA = clamp(a, 0.0, 1.0) * tint_v.a * tinte.a * 0.9;
}
"""

const LUZ: Vector3 = Vector3(-0.35, 0.82, 0.45)
## Tonos como multiplicadores del color: luz · media · sombra (la sombra vira a violeta, como la paleta pastel del juego).
const TONO_LUZ: Color = Color(1.0, 1.0, 1.0)
const TONO_MEDIO: Color = Color(0.80, 0.78, 0.90)
const TONO_SOMBRA: Color = Color(0.58, 0.55, 0.76)
const COLOR_CONTORNO: Color = Color(0.13, 0.09, 0.17)
const GROSOR_CONTORNO: float = 0.055

static var _mallas: Dictionary = {}
static var _mat_cuerpo: StandardMaterial3D = null
static var _mat_doble: StandardMaterial3D = null
static var _mat_contorno: StandardMaterial3D = null
static var _mat_fx_add: StandardMaterial3D = null
static var _mat_fx_mix: StandardMaterial3D = null
static var _mat_fx_fuego: ShaderMaterial = null
static var _tintes: Dictionary = {}


## La malla (ya con sus materiales blancos: sirve tal cual para partículas, que la tiñen con su color).
static func malla(nombre: String) -> ArrayMesh:
	if _mallas.has(nombre):
		return _mallas[nombre]
	var tris: Array = _tris_de(nombre)
	var m: ArrayMesh
	if FUEGO.has(nombre):
		m = _construir_fuego(tris)
	elif EFECTO_ADITIVO.has(nombre) or EFECTO_SUAVE.has(nombre):
		m = _construir_efecto(tris, nombre)
	else:
		m = _construir(tris, not PLANAS.has(nombre) and not SIN_CONTORNO.has(nombre), DOBLE_CARA.has(nombre))
	_mallas[nombre] = m
	return m


## Una pieza suelta teñida con `color` (el contorno no se tiñe). `escala` es uniforme.
static func instancia(nombre: String, color: Color = Color.WHITE, escala: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla(nombre)
	mi.set_surface_override_material(0, material_tinte(color, DOBLE_CARA.has(nombre), nombre))
	mi.scale = Vector3.ONE * escala
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Material de cuerpo teñido (se reutiliza por color).
static func material_tinte(color: Color, doble: bool = false, nombre: String = "") -> Material:
	var clave: String = "%s|%s|%s" % [color.to_html(), doble, nombre]
	if _tintes.has(clave):
		return _tintes[clave]
	if FUEGO.has(nombre):
		var mfu: ShaderMaterial = _mat_fuego().duplicate() as ShaderMaterial
		mfu.set_shader_parameter("tinte", color)
		_tintes[clave] = mfu
		return mfu
	if EFECTO_ADITIVO.has(nombre) or EFECTO_SUAVE.has(nombre):
		var mf: StandardMaterial3D = _mat_efecto(EFECTO_ADITIVO.has(nombre)).duplicate() as StandardMaterial3D
		var k: float = 1.2 if EFECTO_ADITIVO.has(nombre) else 1.0
		mf.albedo_color = Color(color.r * k, color.g * k, color.b * k, color.a)
		_tintes[clave] = mf
		return mf
	var m: StandardMaterial3D = (_cuerpo_doble() if doble else _cuerpo()).duplicate() as StandardMaterial3D
	m.albedo_color = Color(color, 1.0)
	_tintes[clave] = m
	return m


static func _cuerpo() -> StandardMaterial3D:
	if _mat_cuerpo == null:
		_mat_cuerpo = StandardMaterial3D.new()
		_mat_cuerpo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_cuerpo.vertex_color_use_as_albedo = true
	return _mat_cuerpo


static func _cuerpo_doble() -> StandardMaterial3D:
	if _mat_doble == null:
		_mat_doble = _cuerpo().duplicate() as StandardMaterial3D
		_mat_doble.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_doble


## El material del fuego (compartido; material_tinte saca copias teñidas).
static func _mat_fuego() -> ShaderMaterial:
	if _mat_fx_fuego == null:
		var sh := Shader.new()
		sh.code = CODIGO_FUEGO
		_mat_fx_fuego = ShaderMaterial.new()
		_mat_fx_fuego.shader = sh
	return _mat_fx_fuego


## Malla de la lengua de fuego: normales LISAS (promedio por vértice) para que el fresnel del shader degrade sin facetas.
static func _construir_fuego(tris: Array) -> ArrayMesh:
	var suma: Dictionary = {}
	var caras: Array = []
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n: Vector3 = -(b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			continue
		n = n.normalized()
		caras.append([a, b, c])
		for v in [a, b, c]:
			var k: Vector3i = _clave(v)
			suma[k] = ((suma[k] as Vector3) + n) if suma.has(k) else n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in caras:
		for v in f:
			st.set_normal((suma[_clave(v)] as Vector3).normalized())
			st.add_vertex(v)
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, _mat_fuego())
	return m


## Material de los efectos: sin luz, translúcido, de dos caras, sin escribir profundidad (no se tapan entre sí). Aditivo = brilla.
static func _mat_efecto(aditivo: bool) -> StandardMaterial3D:
	if aditivo and _mat_fx_add != null:
		return _mat_fx_add
	if not aditivo and _mat_fx_mix != null:
		return _mat_fx_mix
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(1.25, 1.15, 1.05, 1.0) if aditivo else Color.WHITE
	if aditivo:
		_mat_fx_add = m
	else:
		_mat_fx_mix = m
	return m


## Color del degradado de una pieza de efecto a la altura relativa t (0 base · 1 punta). Alfa incluido.
static func _color_efecto(nombre: String, t: float) -> Color:
	if nombre == "llama":
		var paradas: Array = [Color(1.0, 0.93, 0.50, 0.95), Color(1.0, 0.62, 0.18, 0.88), Color(0.96, 0.33, 0.10, 0.62),
			Color(0.85, 0.2, 0.08, 0.0)]
		var x: float = clampf(t, 0.0, 1.0) * float(paradas.size() - 1)
		var i: int = mini(int(x), paradas.size() - 2)
		return (paradas[i] as Color).lerp(paradas[i + 1], x - float(i))
	if nombre == "nube":
		return Color(0.72, 0.70, 0.76, 0.38).lerp(Color(0.52, 0.51, 0.57, 0.1), clampf(t, 0.0, 1.0))
	# brasas, chispas, destellos, rayos: núcleo blanco que se tiñe con el color de la partícula
	return Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.85, 0.85, 0.85, 0.7), clampf(t, 0.0, 1.0))


## Malla de efecto: las mismas facetas, pero con color de vértice en degradado y alfa (sin contorno ni tonos planos).
## Cada cara se atenúa un poco según lo inclinada que esté, para que se lea el facetado sin parecer un dibujo.
static func _construir_efecto(tris: Array, nombre: String) -> ArrayMesh:
	var ymin: float = 1.0e9
	var ymax: float = -1.0e9
	for t in tris:
		for v in t:
			ymin = minf(ymin, (v as Vector3).y)
			ymax = maxf(ymax, (v as Vector3).y)
	var rango: float = maxf(ymax - ymin, 0.0001)
	var luz: Vector3 = LUZ.normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n: Vector3 = -(b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			continue
		n = n.normalized()
		var f: float = 0.82 + 0.18 * absf(n.dot(luz))
		for v in [a, b, c]:
			var col: Color = _color_efecto(nombre, ((v as Vector3).y - ymin) / rango)
			st.set_color(Color(col.r * f, col.g * f, col.b * f, col.a))
			st.set_normal(n)
			st.add_vertex(v)
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, _mat_efecto(EFECTO_ADITIVO.has(nombre)))
	return m


static func _contorno() -> StandardMaterial3D:
	if _mat_contorno == null:
		_mat_contorno = StandardMaterial3D.new()
		_mat_contorno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_contorno.vertex_color_use_as_albedo = true
		_mat_contorno.cull_mode = BaseMaterial3D.CULL_FRONT
	return _mat_contorno


## --- Construcción: triángulos -> malla de facetas con tres tonos + casco de contorno ---

## `tris`: lista de [a, b, c] con las caras en sentido horario visto desde fuera (lo que Godot toma como frente).
static func _construir(tris: Array, con_contorno: bool, doble: bool) -> ArrayMesh:
	var luz: Vector3 = LUZ.normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var suma: Dictionary = {}          # posición redondeada -> suma de normales salientes (para inflar el contorno)
	var caras: Array = []
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n: Vector3 = -(b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			continue
		n = n.normalized()
		caras.append([a, b, c, n])
		for v in [a, b, c]:
			var k: Vector3i = _clave(v)
			suma[k] = ((suma[k] as Vector3) + n) if suma.has(k) else n
		if doble:
			# lámina de una sola cara geométrica que el material dibuja por los dos lados (cull desactivado): un solo triángulo,
			# con el tono según lo inclinada que esté, nunca dos caras coplanares peleándose (z-fighting)
			_cara(st, a, b, c, n, _tono(absf(n.dot(luz))))
		else:
			_cara(st, a, b, c, n, _tono(n.dot(luz)))
	var malla_: ArrayMesh = st.commit()
	malla_.surface_set_material(0, _cuerpo_doble() if doble else _cuerpo())
	if con_contorno:
		var so := SurfaceTool.new()
		so.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in caras:
			var vs: Array = []
			for i in range(3):
				var v: Vector3 = f[i]
				var dir: Vector3 = (suma[_clave(v)] as Vector3).normalized()
				vs.append(v + dir * GROSOR_CONTORNO)
			# caras vueltas: el contorno se ve solo por detrás de la pieza (cull_front)
			_cara(so, vs[0], vs[1], vs[2], f[3], COLOR_CONTORNO)
		so.commit(malla_)
		malla_.surface_set_material(1, _contorno())
	return malla_


static func _cara(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)


static func _tono(d: float) -> Color:
	if d > 0.35:
		return TONO_LUZ
	if d > -0.25:
		return TONO_MEDIO
	return TONO_SOMBRA


static func _clave(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 500.0), roundi(v.y * 500.0), roundi(v.z * 500.0))


## Pone cada triángulo en sentido horario visto desde fuera, tomando `centro` como el interior de la pieza.
static func _orientar(tris: Array, centro: Vector3) -> Array:
	var res: Array = []
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n: Vector3 = (b - a).cross(c - a)
		var cen: Vector3 = (a + b + c) / 3.0
		# (b-a)x(c-a) apunta hacia dentro = ya es horario visto desde fuera
		if n.dot(cen - centro) < 0.0:
			res.append([a, b, c])
		else:
			res.append([a, c, b])
	return res


## --- Generadores ---

static func _tris_de(nombre: String) -> Array:
	match nombre:
		"llama":
			# Lengua lisa de 1,6 de alto (10 lados, 10 anillos): el shader la ondula e inclina. Gorda abajo, fina en la punta.
			var perfil: Array = []
			for i in range(11):
				var t: float = float(i) / 10.0
				var r: float = 0.37 * pow(maxf(sin(PI * pow(t, 0.62)), 0.0), 0.85) * (1.0 - 0.45 * t)
				perfil.append(Vector2(r, 1.6 * t))
			return _revolucion(perfil, 10, false, false)
		"ascua":
			return _octaedro(0.5, 0.7, 0.5)
		"nube":
			return _icosaedro(0.5, 0.14, 0.85, 3)
		"burbuja":
			return _icosaedro(0.5, 0.02, 1.0, 5)
		"gota":
			return _revolucion([Vector2(0.0, -0.5), Vector2(0.30, -0.32), Vector2(0.38, -0.08), Vector2(0.22, 0.26),
				Vector2(0.0, 0.62)], 6, true, false)
		"chispa":
			return _octaedro(0.13, 0.5, 0.13)
		"estrella":
			return _octaedro(0.5, 0.11, 0.11) + _octaedro(0.11, 0.5, 0.11) + _octaedro(0.11, 0.11, 0.5)
		"copo":
			return _estrella_plana(6, 0.5, 0.2, 0.09)
		"hoja":
			return _octaedro(0.3, 0.05, 0.55)
		"piedra":
			return _icosaedro(0.5, 0.2, 0.8, 7)
		"cristal":
			return _revolucion([Vector2(0.0, 0.0), Vector2(0.32, 0.05), Vector2(0.34, 0.56), Vector2(0.0, 1.0)], 6, true, false)
		"pua":
			return _doblar(_revolucion([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.44, 0.14), Vector2(0.0, 1.0)], 5, true, false), 0.0, 0.18)
		"corona":
			return _revolucion([Vector2(0.0, 0.0), Vector2(0.30, 0.02), Vector2(0.36, 0.22), Vector2(0.24, 0.42),
				Vector2(0.40, 0.64), Vector2(0.22, 0.86), Vector2(0.0, 1.0)], 7, true, false)
		"rayo":
			return _rayo()
		"remolino":
			return _remolino()
		"anillo":
			return _anillo_plano(0.5, 0.44, 12)
		"runa":
			return _runa()
		"grieta":
			return _grieta()
		"disco":
			return _anillo_plano(0.5, 0.0, 8)
		"telarana":
			return _telarana()
	push_warning("Formas3D: forma desconocida '%s'" % nombre)
	return _octaedro(0.5, 0.5, 0.5)


## Telaraña de pie (plano XY, mira a +Z, radio 1): 8 radios y 3 anillos de hilo.
static func _telarana() -> Array:
	var t: Array = []
	var lados: int = 8
	for i in range(lados):
		var a: float = float(i) / float(lados) * TAU
		var b: float = float(i + 1) / float(lados) * TAU
		var pa := Vector3(cos(a), sin(a), 0.0)
		var pb := Vector3(cos(b), sin(b), 0.0)
		t += _tira(Vector3.ZERO, pa, 0.035)
		for r in [0.33, 0.66, 1.0]:
			t += _tira(pa * float(r), pb * float(r), 0.035)
	return t


## Un hilo plano (dos triángulos) de a a b, de semiancho `w`, en el plano XY.
static func _tira(a: Vector3, b: Vector3, w: float) -> Array:
	var d: Vector3 = (b - a).normalized()
	var p := Vector3(-d.y, d.x, 0.0) * w
	return [[a - p, a + p, b + p], [a - p, b + p, b - p]]


## Bipirámide de cuatro lados (un «diamante»), centrada.
static func _octaedro(rx: float, ry: float, rz: float) -> Array:
	var px := Vector3(rx, 0.0, 0.0)
	var nx := Vector3(-rx, 0.0, 0.0)
	var py := Vector3(0.0, ry, 0.0)
	var ny := Vector3(0.0, -ry, 0.0)
	var pz := Vector3(0.0, 0.0, rz)
	var nz := Vector3(0.0, 0.0, -rz)
	var t: Array = [[py, px, pz], [py, pz, nx], [py, nx, nz], [py, nz, px],
		[ny, pz, px], [ny, nx, pz], [ny, nz, nx], [ny, px, nz]]
	return _orientar(t, Vector3.ZERO)


## Icosaedro irregular (`ruido` = cuánto se descoloca cada vértice, `sal` cambia el reparto; `sy` lo aplasta).
static func _icosaedro(radio: float, ruido: float, sy: float, sal: int) -> Array:
	var f: float = (1.0 + sqrt(5.0)) * 0.5
	var base: Array = [Vector3(-1, f, 0), Vector3(1, f, 0), Vector3(-1, -f, 0), Vector3(1, -f, 0),
		Vector3(0, -1, f), Vector3(0, 1, f), Vector3(0, -1, -f), Vector3(0, 1, -f),
		Vector3(f, 0, -1), Vector3(f, 0, 1), Vector3(-f, 0, -1), Vector3(-f, 0, 1)]
	var vs: Array = []
	for i in range(base.size()):
		var v: Vector3 = (base[i] as Vector3).normalized()
		var r: float = radio * (1.0 + (_azar(i, sal) - 0.5) * 2.0 * ruido)
		vs.append(Vector3(v.x * r, v.y * r * sy, v.z * r))
	var caras: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
		[8, 6, 7], [9, 8, 1]]
	var t: Array = []
	for c in caras:
		t.append([vs[c[0]], vs[c[1]], vs[c[2]]])
	return _orientar(t, Vector3.ZERO)


static func _azar(i: int, sal: int) -> float:
	return float(((i + 1) * 7919 + sal * 104729) % 1000) / 999.0


## Sólido de revolución sobre Y. `perfil` = (radio, altura) de abajo arriba. `tapas`: cierra con abanicos las puntas que
## no acaban en radio 0. `doble`: una lámina abierta que se dibuja por las dos caras (el remolino).
static func _revolucion(perfil: Array, lados: int, tapas: bool, doble: bool = false) -> Array:
	var anillos: Array = []
	for p in perfil:
		var pv: Vector2 = p
		var anillo: Array = []
		for i in range(lados):
			var ang: float = float(i) / float(lados) * TAU
			anillo.append(Vector3(cos(ang) * pv.x, pv.y, sin(ang) * pv.x))
		anillos.append(anillo)
	var t: Array = []
	for k in range(anillos.size() - 1):
		var a: Array = anillos[k]
		var b: Array = anillos[k + 1]
		var r0: float = (perfil[k] as Vector2).x
		var r1: float = (perfil[k + 1] as Vector2).x
		for i in range(lados):
			var j: int = (i + 1) % lados
			if r0 < 0.0001:
				t.append([a[0], b[j], b[i]])
			elif r1 < 0.0001:
				t.append([a[i], a[j], b[0]])
			else:
				t.append([a[i], a[j], b[j]])
				t.append([a[i], b[j], b[i]])
	if tapas:
		var ult: int = perfil.size() - 1
		if (perfil[0] as Vector2).x > 0.0001:
			for i in range(lados):
				t.append([Vector3(0.0, (perfil[0] as Vector2).y, 0.0), anillos[0][(i + 1) % lados], anillos[0][i]])
		if (perfil[ult] as Vector2).x > 0.0001:
			for i in range(lados):
				t.append([Vector3(0.0, (perfil[ult] as Vector2).y, 0.0), anillos[ult][i], anillos[ult][(i + 1) % lados]])
	if doble:
		return t         # lámina abierta: sin orientar (se dibuja por las dos caras)
	var ymax: float = (perfil[perfil.size() - 1] as Vector2).y
	var ymin: float = (perfil[0] as Vector2).y
	return _orientar(t, Vector3(0.0, (ymin + ymax) * 0.5, 0.0))


## Dobla una pieza vertical: lo de arriba se va hacia +X (la punta de la llama) y se tuerce un poco hacia +Z.
static func _doblar(tris: Array, k: float, kz: float) -> Array:
	var res: Array = []
	for t in tris:
		var n: Array = []
		for v in t:
			var p: Vector3 = v
			var h: float = maxf(p.y - 0.25, 0.0)
			n.append(Vector3(p.x + k * h * h, p.y, p.z + kz * h * h * 0.5))
		res.append(n)
	return res


## Estrella plana extruida (el copo): `puntas` brazos de radio `r_ext`, huecos de radio `r_int`, grosor `g`.
static func _estrella_plana(puntas: int, r_ext: float, r_int: float, g: float) -> Array:
	var pts: Array = []
	for i in range(puntas * 2):
		var ang: float = float(i) / float(puntas * 2) * TAU
		var r: float = r_ext if i % 2 == 0 else r_int
		pts.append(Vector2(cos(ang) * r, sin(ang) * r))
	var t: Array = []
	var n: int = pts.size()
	var arriba := Vector3(0.0, g * 0.5, 0.0)
	var abajo := Vector3(0.0, -g * 0.5, 0.0)
	for i in range(n):
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % n]
		var pa := Vector3(p.x, g * 0.5, p.y)
		var qa := Vector3(q.x, g * 0.5, q.y)
		var pb := Vector3(p.x, -g * 0.5, p.y)
		var qb := Vector3(q.x, -g * 0.5, q.y)
		t.append([arriba, pa, qa])
		t.append([abajo, qb, pb])
		t.append([pa, pb, qb])
		t.append([pa, qb, qa])
	return _orientar(t, Vector3.ZERO)


## Remolino: cuatro bandas de viento, cada una más ancha y más alta que la anterior, con huecos y giradas entre sí.
static func _remolino() -> Array:
	var t: Array = []
	var lados: int = 8
	for k in range(4):
		var r0: float = 0.16 + 0.11 * float(k)
		var r1: float = r0 + 0.07
		var y0: float = 0.28 * float(k)
		var y1: float = y0 + 0.2
		var fase: float = float(k) * 1.1
		for i in range(5):                                  # 5 de 8 tramos: la banda no cierra el círculo
			var a0: float = fase + float(i) / float(lados) * TAU
			var a1: float = fase + float(i + 1) / float(lados) * TAU
			var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var q0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var q1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			t.append([p0, p1, q1])
			t.append([p0, q1, q0])
	return t


## Rayo: cuatro diamantes alargados y torcidos uno sobre otro (zigzag), base en y = 0, punta en y ≈ 1.
static func _rayo() -> Array:
	var tramos: Array = [[Vector2(0.02, 0.88), 0.45], [Vector2(0.15, 0.64), -0.5], [Vector2(-0.08, 0.40), 0.5], [Vector2(0.10, 0.14), -0.45]]
	var t: Array = []
	for tr in tramos:
		var c: Vector2 = (tr as Array)[0]
		var giro: float = (tr as Array)[1]
		var b := Basis(Vector3(0.0, 0.0, 1.0), giro)
		var piezas: Array = _octaedro(0.11, 0.26, 0.11)
		for p in piezas:
			var n: Array = []
			for v in p:
				var w: Vector3 = b * (v as Vector3)
				n.append(Vector3(w.x + c.x, w.y + c.y, w.z))
			t.append(n)
	return t


## Anillo plano en y = 0 (con `r_int` = 0 es un disco). Doble cara.
static func _anillo_plano(r_ext: float, r_int: float, lados: int) -> Array:
	var t: Array = []
	for i in range(lados):
		var a0: float = float(i) / float(lados) * TAU
		var a1: float = float(i + 1) / float(lados) * TAU
		var e0 := Vector3(cos(a0) * r_ext, 0.0, sin(a0) * r_ext)
		var e1 := Vector3(cos(a1) * r_ext, 0.0, sin(a1) * r_ext)
		if r_int <= 0.0001:
			t.append([Vector3.ZERO, e1, e0])
		else:
			var i0 := Vector3(cos(a0) * r_int, 0.0, sin(a0) * r_int)
			var i1 := Vector3(cos(a1) * r_int, 0.0, sin(a1) * r_int)
			t.append([i0, e0, e1])
			t.append([i0, e1, i1])
	return t


## Círculo rúnico plano: aro exterior, aro medio y ocho dientes que los unen.
static func _runa() -> Array:
	var t: Array = _anillo_plano(0.5, 0.43, 16) + _anillo_plano(0.31, 0.26, 12)
	for i in range(8):
		var ang: float = (float(i) + 0.5) / 8.0 * TAU
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var l := Vector3(-d.z, 0.0, d.x)
		t.append([d * 0.43 + l * 0.05, d * 0.43 - l * 0.05, d * 0.27])
	return t


## Grieta plana: seis brazos quebrados que salen del centro y se afinan.
static func _grieta() -> Array:
	var t: Array = []
	for i in range(6):
		var ang: float = float(i) / 6.0 * TAU + (_azar(i, 3) - 0.5) * 0.5
		var largo: float = 0.34 + _azar(i, 5) * 0.16
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var l := Vector3(-d.z, 0.0, d.x)
		var codo: Vector3 = d * (largo * 0.5) + l * ((_azar(i, 9) - 0.5) * 0.14)
		var punta: Vector3 = d * largo + l * ((_azar(i, 11) - 0.5) * 0.18)
		t.append([l * 0.05, -l * 0.05, codo + l * 0.03])
		t.append([-l * 0.05, codo - l * 0.03, codo + l * 0.03])
		t.append([codo + l * 0.03, codo - l * 0.03, punta])
	return t
