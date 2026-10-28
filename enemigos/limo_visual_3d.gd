class_name LimoVisual3D
extends Node3D
## ASPECTO del limo elemental (E1, prototipo hecho por código, 27/10). Solo se ve y se anima: sin IA ni combate.
##
## Una gota de gelatina blanco lechoso, más ancha que alta, con la base aplastada e irregular; dentro, un NÚCLEO oscuro que
## late; dos ojos ovalados con un brillo y una boquita fruncida en la cara delantera (+Z, la que mira a la cámara del juego);
## burbujitas que suben. `cargar("fuego")` tiñe la gelatina y el núcleo con el color del elemento (`Pulso3D.COLORES`, el mismo
## que las runas); `congelar(true)` la vuelve un cubo de hielo; `dividir()` la parte en dos limos pequeños.
##
## Dibujo: el cuerpo es un shader TRANSLÚCIDO sin escribir profundidad (`depth_draw_never`); el núcleo es opaco y se dibuja antes
## por ser opaco; ojos, boca y burbujas van en el pase transparente con `render_priority` mayor, así que quedan ENCIMA del velo
## de gelatina y se leen. Origen del nodo: el suelo, en el centro de la base.

signal salto_terminado
signal dividido(hijos: Array)
signal crecio(tamano: float)

const TAMANO_PEQUENO: float = 0.6
const TAMANO_NORMAL: float = 1.0
const TAMANO_GRANDE: float = 1.6                 ## un limo que recibe OTRA VEZ su elemento absorbe y crece (pequeño → normal → grande)
const T_CRECER: float = 0.7

const ALTO: float = 0.6                          ## alto total en reposo (u)
const ANCHO: float = 1.0
const PROFUNDO: float = 0.9
const ESCALA_CUERPO: Vector3 = Vector3(ANCHO, 0.72, PROFUNDO)   ## sobre una esfera de radio 0,5: 1,0 × 0,72 × 0,9 con la base recortada (≈0,6 de alto)
const PLANO_BASE: float = -0.34                  ## y local (esfera de radio 0,5) donde se aplasta la base
const CASILLA: float = 2.3
const ALTO_SALTO: float = 0.9
const T_PREPARA: float = 0.18
const T_AIRE: float = 0.5
const T_CAE: float = 0.24
const T_DIVIDE: float = 0.32
## Cara: tamaño de los ojos (multiplica 0,10 × 0,15 u) y altura sobre la esfera (y local, radio 0,5). Pablo la quiere más grande y alta que en el concepto.
const ESCALA_OJOS: float = 1.3
const ALTO_CARA: float = 0.32
const SEPARACION_OJOS: float = 0.165
const ALTO_BOCA: float = 0.25
const N_BURBUJAS: int = 7
const RADIO_NUCLEO: float = 0.1                  ## ≈ 20 % del ancho (diámetro 0,2)
const RADIO_NUCLEO_GRANDE: float = 0.13            ## ≈ 26 % del ancho en el grande
const ALTO_NUCLEO: float = -0.19                ## y local (esfera de radio 0,5): casi en la base (-0,34)
const COLOR_NUCLEO_NEUTRO: Color = Color(0.04, 0.06, 0.11)
const ADELANTE_NUCLEO: float = 0.1                ## z local: adelantado hacia la cámara (+Z), así con la cámara inclinada cae más abajo en pantalla
const CODIGO_NUCLEO: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;
uniform vec4 color : source_color = vec4(0.2, 0.24, 0.32, 1.0);
uniform float emision = 0.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	float f = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = color.rgb * (0.85 + 0.15 * n.y) + color.rgb * emision;   // sin brillo especular: solo un degradado suave
	ALPHA = mix(1.0, 0.0, f);                                           // borde suave: más transparente en el contorno
}
"""

const CODIGO_GELATINA: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform vec4 color_elemento : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float carga = 0.0;        // 0 blanco lechoso ... 1 teñido del elemento
uniform float aplastar = 0.0;     // 0..1: temblor de gelatina (golpe)
uniform float congelado = 0.0;    // 0 gelatina ... 1 cubo de hielo
uniform float intensidad = 0.0;   // 0..1: el limo GRANDE tiñe más fuerte
uniform float plano = -0.34;
varying vec3 pos_c;
varying vec3 pos_l;
void vertex() {
	vec3 v = VERTEX;
	vec3 a = abs(v);
	float m = max(max(a.x, a.y), a.z);
	vec3 cubo = v / max(m, 0.0001) * 0.5;
	vec3 ncubo = vec3(0.0, 0.0, sign(v.z));
	if (a.x >= a.y && a.x >= a.z) { ncubo = vec3(sign(v.x), 0.0, 0.0); }
	else if (a.y >= a.z) { ncubo = vec3(0.0, sign(v.y), 0.0); }
	// gelatina: base aplastada, algo más ancha y con un ruido muy suave para que no sea perfecta
	float f = smoothstep(plano + 0.2, plano, v.y);
	float r = sin(v.x * 9.0 + 1.3) * sin(v.z * 8.0 + 0.4) * 0.03 + sin(v.x * 3.0 - v.z * 4.0) * 0.02;
	vec3 g = v;
	g.xz *= 1.0 + 0.12 * f + r * f * 2.5;
	vec3 ng = NORMAL;
	if (v.y <= plano) { ng = vec3(0.0, -1.0, 0.0); }
	g.y = max(g.y, plano);
	g.xz += aplastar * 0.045 * sin(TIME * 38.0 + v.y * 14.0 + v.x * 6.0) * vec2(1.0, 0.8);
	pos_c = cubo;
	pos_l = v;
	VERTEX = mix(g, cubo, congelado);
	NORMAL = normalize(mix(ng, ncubo, congelado));
}
void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.2);
	float grosor = 1.0 - fres;                                     // más grueso hacia el centro
	vec3 leche_borde = vec3(0.97, 0.98, 1.0);
	vec3 leche_hondo = vec3(0.70, 0.78, 0.90);
	vec3 el = color_elemento.rgb * (1.0 + 0.18 * intensidad);
	vec3 borde = mix(leche_borde, mix(el, vec3(1.0), 0.35 - 0.15 * intensidad), carga * (0.8 + 0.15 * intensidad));
	vec3 hondo = mix(leche_hondo, el, carga * (0.9 + 0.1 * intensidad));                  // dispersión: más color donde hay más gelatina
	vec3 col = mix(borde, hondo, pow(grosor, 1.3));
	float alfa = mix(0.2, 0.88, fres);
	// hielo: azul pálido, más opaco, aristas claras y grietas
	vec3 hielo_h = mix(vec3(0.62, 0.86, 0.98), el, carga * 0.35);
	vec3 hielo_b = vec3(0.90, 0.98, 1.0);
	vec3 chielo = mix(hielo_h, hielo_b, fres);
	float e = smoothstep(0.43, 0.49, abs(pos_c.x)) + smoothstep(0.43, 0.49, abs(pos_c.y)) + smoothstep(0.43, 0.49, abs(pos_c.z));
	float arista = clamp(e - 1.0, 0.0, 1.0);
	float grieta = smoothstep(0.93, 1.0, abs(sin(pos_l.x * 17.0 + pos_l.y * 11.0) * sin(pos_l.z * 14.0 - pos_l.y * 9.0)));
	chielo = mix(chielo, vec3(1.0), arista * 0.8 + grieta * 0.25);
	col = mix(col, chielo, congelado);
	alfa = mix(alfa, mix(0.62, 0.95, max(fres, arista)), congelado);
	ALBEDO = col;
	ALPHA = alfa;
	ROUGHNESS = mix(0.14, 0.05, congelado);
	SPECULAR = 0.9;
	vec3 L = normalize(vec3(-0.35, 0.65, 0.7));                     // brillo pequeño de ventana, en el espacio de la cámara
	float h = pow(max(dot(n, normalize(L + normalize(VIEW))), 0.0), 90.0);
	EMISSION = col * 0.15 + vec3(h) * 0.85 + vec3(arista * 0.25 * congelado);
}
"""

## Elemento con el que está teñido («» = neutro). `tamano`: 1,0 normal, 0,6 pequeño.
var elemento: String = ""
var tamano: float = 1.0:
	set(v):
		tamano = v
		_tam_mostrado = v
		if _escala != null:
			_escala.scale = Vector3.ONE * v
## 0 = gelatina, 1 = bloque de hielo (animado).
var congelado: float = 0.0
var hijos: Array = []                            ## los limos pequeños de la última `dividir()`
var material_cuerpo: ShaderMaterial = null
var en_salto: bool = false

var _escala: Node3D = null                       ## aplica `tamano`
var _squash: Node3D = null                       ## aplasta y estira desde el suelo
var _cuerpo: MeshInstance3D = null
var _nucleo: MeshInstance3D = null
var _mat_nucleo: ShaderMaterial = null
var _cara: Node3D = null
var _ojos: Array[Node3D] = []
var _boca: MeshInstance3D = null
var _burbujas: Array[MeshInstance3D] = []
var _datos_burbuja: Array[Vector4] = []          ## x, z, velocidad, fase
var _t: float = 0.0
var _cong_obj: float = 0.0
var _carga: float = 0.0
var _carga_obj: float = 0.0
var _estado: String = "reposo"
var _te: float = 0.0
var _origen: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.ZERO
var _sq: float = 1.0
var _sx: float = 1.0
var _sz: float = 1.0
var _temblor: float = 0.0
var _lado: Vector3 = Vector3.ZERO
var _desde: Vector3 = Vector3.ZERO
var _tam_mostrado: float = 1.0                  ## tamaño que se ve (anima el crecimiento hacia `tamano`)
var _tam_ini: float = 1.0
var _crec_te: float = -1.0                       ## <0 = no está creciendo
var _pulso_te: float = -1.0                      ## pulso de absorción del grande
var _destello: float = 0.0                       ## el núcleo destella al absorber
var _g: float = 0.0                              ## 0..1: cuánto «grande» se ve (cejas, ojos, núcleo, respiración)
var _cejas: Array[MeshInstance3D] = []
var _sep_hijos: float = 0.9
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2710
	_construir()
	tamano = tamano
	if elemento != "":
		cargar(elemento)
	_aplicar_forma()


# ---------------------------------------------------------------------------------------------------------------------
#  Construcción
# ---------------------------------------------------------------------------------------------------------------------

func _construir() -> void:
	_escala = Node3D.new()
	_escala.name = "Escala"
	add_child(_escala)
	_squash = Node3D.new()
	_squash.name = "Aplaste"
	_escala.add_child(_squash)

	var sh := Shader.new()
	sh.code = CODIGO_GELATINA
	material_cuerpo = ShaderMaterial.new()
	material_cuerpo.shader = sh
	material_cuerpo.set_shader_parameter("color_elemento", Pulso3D.COLOR_BASE)
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 56
	esf.rings = 28
	_cuerpo = MeshInstance3D.new()
	_cuerpo.name = "Cuerpo"
	_cuerpo.mesh = esf
	_cuerpo.material_override = material_cuerpo
	_cuerpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_squash.add_child(_cuerpo)

	# Núcleo: esfera oscura y densa abajo en el centro (opaca: se dibuja antes que el velo de gelatina).
	var en := SphereMesh.new()
	en.radius = 0.5
	en.height = 1.0
	en.radial_segments = 32
	en.rings = 16
	var shn := Shader.new()
	shn.code = CODIGO_NUCLEO
	_mat_nucleo = ShaderMaterial.new()
	_mat_nucleo.shader = shn
	_mat_nucleo.render_priority = -1                              # antes que el velo: el cuerpo lo cubre
	_nucleo = MeshInstance3D.new()
	_nucleo.name = "Nucleo"
	_nucleo.mesh = en
	_nucleo.material_override = _mat_nucleo
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cuerpo.add_child(_nucleo)

	_construir_cara()
	_construir_burbujas()


func _comp() -> Vector3:
	return Vector3(1.0 / ESCALA_CUERPO.x, 1.0 / ESCALA_CUERPO.y, 1.0 / ESCALA_CUERPO.z)


## Pega algo a la superficie de la esfera (radio 0,5) en (x, y) locales, mirando hacia fuera.
func _sobre_superficie(x: float, y: float, fuera: float) -> Transform3D:
	var z: float = sqrt(maxf(0.25 - x * x - y * y, 0.01))
	var n := Vector3(x, y, z).normalized()
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z) + n * fuera)   # sin girar: el cuerpo es anisótropo y un giro sesgaría los ojos


func _construir_cara() -> void:
	_cara = Node3D.new()
	_cara.name = "Cara"
	_cuerpo.add_child(_cara)
	var comp := _comp()
	var mat_ojo := StandardMaterial3D.new()
	mat_ojo.albedo_color = Color(0.03, 0.04, 0.08, 1.0)
	mat_ojo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ojo.roughness = 0.2
	mat_ojo.render_priority = 5
	var mat_brillo := StandardMaterial3D.new()
	mat_brillo.albedo_color = Color(1, 1, 1, 1)
	mat_brillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_brillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_brillo.render_priority = 6
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 20
	esf.rings = 10
	for lado in [-1.0, 1.0]:
		var raiz := Node3D.new()
		raiz.name = "Ojo"
		raiz.transform = _sobre_superficie(lado * SEPARACION_OJOS, ALTO_CARA, -0.012)
		_cara.add_child(raiz)
		var o := MeshInstance3D.new()
		o.mesh = esf
		o.material_override = mat_ojo
		o.scale = Vector3(0.10, 0.15, 0.06) * ESCALA_OJOS * comp
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(o)
		var b := MeshInstance3D.new()
		b.mesh = esf
		b.material_override = mat_brillo
		b.scale = Vector3(0.030, 0.034, 0.02) * ESCALA_OJOS * comp
		b.position = Vector3(-0.02 * ESCALA_OJOS, 0.045 * ESCALA_OJOS, 0.03) * comp
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(b)
		_ojos.append(raiz)
	# Cejas (solo el grande): trazos oscuros inclinados hacia dentro, ceño enfadado.
	var caja := BoxMesh.new()
	for lado in [-1.0, 1.0]:
		var c := MeshInstance3D.new()
		c.name = "Ceja"
		c.mesh = caja
		c.material_override = mat_ojo
		var tf := _sobre_superficie(lado * (SEPARACION_OJOS - 0.005), ALTO_CARA + 0.085, 0.004)
		tf.basis = Basis(Vector3.BACK, lado * 0.42)      # el extremo de dentro más bajo
		c.transform = tf
		c.scale = Vector3(0.0, 0.0, 0.0)
		c.visible = false
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cara.add_child(c)
		_cejas.append(c)
	# Boca: textura pintada en un quad pegado a la superficie.
	var mb := StandardMaterial3D.new()
	mb.albedo_texture = _textura_boca()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.render_priority = 5
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.5)
	_boca = MeshInstance3D.new()
	_boca.name = "Boca"
	_boca.mesh = q
	_boca.material_override = mb
	_boca.transform = _sobre_superficie(0.0, ALTO_BOCA, 0.004)
	_boca.scale = Vector3(0.20, 0.10, 1.0) * ESCALA_OJOS * comp
	_boca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cara.add_child(_boca)


## Boquita fruncida: un óvalo pequeño y oscuro, como una «o» (legible a la distancia de la cámara del juego).
func _textura_boca() -> ImageTexture:
	var w: int = 128
	var h: int = 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for py in range(h):
		for px in range(w):
			var x: float = (float(px) / (w - 1) - 0.5) / 0.17
			var y: float = (float(py) / (h - 1) - 0.5) / 0.36
			var r: float = sqrt(x * x + y * y)                     # óvalo pequeño: boquita fruncida en «o»
			var aro: float = clampf(1.0 - absf(r - 0.85) / 0.35, 0.0, 1.0)
			var dentro: float = clampf((0.85 - r) / 0.1, 0.0, 1.0) * 0.85
			var a: float = maxf(aro, dentro)
			if a > 0.0:
				img.set_pixel(px, py, Color(0.16, 0.06, 0.12, clampf(a * 1.6, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _construir_burbujas() -> void:
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 12
	esf.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.95, 1.0)
	mat.emission_energy_multiplier = 0.12
	mat.render_priority = 2
	var comp := _comp()
	for i in N_BURBUJAS:
		var m := MeshInstance3D.new()
		m.mesh = esf
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r: float = _rng.randf_range(0.028, 0.055)
		m.scale = Vector3.ONE * r * 2.0 * comp
		_cuerpo.add_child(m)
		_burbujas.append(m)
		var d := Vector4(_rng.randf_range(-0.28, 0.28), _rng.randf_range(-0.22, 0.22), _rng.randf_range(0.05, 0.11), _rng.randf() * TAU)
		_datos_burbuja.append(d)
		m.position = Vector3(d.x, _rng.randf_range(-0.18, 0.28), d.y)


# ---------------------------------------------------------------------------------------------------------------------
#  Órdenes
# ---------------------------------------------------------------------------------------------------------------------

## Tiñe hacia el color del elemento («» = neutro, blanco lechoso).
func cargar(p_elemento: String) -> void:
	var nuevo: String = p_elemento if Pulso3D.COLORES.has(p_elemento) else ""
	# El MISMO elemento otra vez: absorbe y crece (el grande solo palpita).
	var repite: bool = nuevo != "" and nuevo == elemento and _carga_obj > 0.5
	elemento = nuevo
	_carga_obj = 1.0 if elemento != "" else 0.0
	if elemento != "" and material_cuerpo != null:
		material_cuerpo.set_shader_parameter("color_elemento", Pulso3D.color_de(elemento))
	if repite and _squash != null:
		if tamano < TAMANO_GRANDE - 0.01:
			crecer()
		else:
			_pulso_te = 0.0
			_destello = 1.0


## Absorbe y crece un escalón (pequeño 0,6 → normal 1,0 → grande 1,6). Se encoge un instante, se infla con rebote elástico y se asienta.
func crecer() -> void:
	if tamano >= TAMANO_GRANDE - 0.01:
		_pulso_te = 0.0
		_destello = 1.0
		return
	_tam_ini = _tam_mostrado
	tamano = TAMANO_NORMAL if tamano < 0.8 else TAMANO_GRANDE   # fija el tamaño final y reinicia lo mostrado
	_tam_mostrado = _tam_ini
	_crec_te = 0.0
	_destello = 1.0
	crecio.emit(tamano)


func esta_grande() -> bool:
	return tamano >= 1.5


## Cuánto color de elemento lleva ahora (0..1).
func carga_actual() -> float:
	return _carga


func congelar(b: bool = true) -> void:
	_cong_obj = 1.0 if b else 0.0


func esta_congelado() -> bool:
	return _cong_obj > 0.5


## Salto de una casilla (2,3 u) hacia `dir` (en el plano horizontal): se aplasta, se estira en el aire y se aplasta al caer.
func saltar(dir: Vector3) -> void:
	if _estado == "salto":
		return
	dir.y = 0.0
	_dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	_origen = position
	_estado = "salto"
	_te = 0.0
	en_salto = true


func golpe() -> void:
	if _estado == "salto" or _estado == "dividir":
		return
	_estado = "golpe"
	_te = 0.0


## Se estira en horizontal y se parte en dos limos un escalón más pequeños (grande → 2 normales, normal → 2 pequeños de 0,6; un pequeño no se divide) que salen a los lados. Los hijos son hermanos (hijos del
## mismo padre); nacen ocultos y aparecen cuando el original acaba de estirarse. Devuelve los hijos.
func dividir() -> Array:
	if _estado == "dividir" or _estado == "dividido":
		return hijos
	if tamano < 0.8:                                 # un pequeño ya no se divide: solo encaja el golpe
		golpe()
		return []
	var tam_hijo: float = TAMANO_NORMAL if esta_grande() else TAMANO_PEQUENO
	_estado = "dividir"
	_te = 0.0
	_lado = global_transform.basis.x.normalized() if is_inside_tree() else Vector3.RIGHT
	hijos = []
	var padre: Node = get_parent()
	for s in [-1.0, 1.0]:
		var h := LimoVisual3D.new()
		h.tamano = tam_hijo
		h.elemento = elemento
		if padre != null:
			padre.add_child(h)
		else:
			add_child(h)
		h.position = position + _lado * s * 0.2 if padre != null else _lado * s * 0.2
		h.visible = false
		h._estado = "oculto"
		h._desde = h.position
		h._lado = _lado * s
		h._sep_hijos = 0.9 * maxf(1.0, tamano)
		h._carga = _carga
		h._carga_obj = _carga_obj
		hijos.append(h)
	return hijos


## Vuelve a la forma normal tras una división (el original reaparece, por si se quiere reutilizar).
func reunir() -> void:
	for h in hijos:
		if is_instance_valid(h):
			(h as Node).queue_free()
	hijos = []
	_squash.visible = true
	_estado = "reposo"


# ---------------------------------------------------------------------------------------------------------------------
#  Animación
# ---------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _squash == null:
		return
	_t += delta
	_te += delta
	_g = move_toward(_g, 1.0 if esta_grande() else 0.0, delta / 0.3)
	_destello = move_toward(_destello, 0.0, delta / 0.5)
	_animar_tamano(delta)
	congelado = move_toward(congelado, _cong_obj, delta / 0.45)
	_carga = move_toward(_carga, _carga_obj, delta / 0.35)
	_temblor = 0.0
	_sx = 1.0
	_sz = 1.0
	var desplaza_x: float = 0.0
	match _estado:
		"reposo":
			_sq = 1.0 + lerpf(0.04, 0.05, _g) * sin(_t * TAU * lerpf(0.8, 0.6, _g)) * (1.0 - congelado)   # el grande respira más lento y más hondo
			_sx = 1.0 / sqrt(_sq)
			_sz = _sx
		"salto":
			_animar_salto()
		"golpe":
			var k: float = _te
			_sq = 1.0 - 0.45 * exp(-5.0 * k) * cos(k * 22.0)
			_sx = 1.0 / sqrt(_sq)
			_sz = _sx
			_temblor = exp(-4.0 * k)
			desplaza_x = sin(k * 70.0) * 0.03 * exp(-5.0 * k)
			if k > 0.7:
				_estado = "reposo"
		"dividir":
			_animar_dividir()
		"sale":
			var k2: float = clampf(_te / 0.42, 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - k2, 3.0)
			position = _desde + _lado * _sep_hijos * e
			_sq = 0.75 + 0.25 * e + 0.12 * sin(k2 * PI * 2.0) * (1.0 - k2)
			_sx = 1.0 / sqrt(_sq)
			_sz = _sx
			if k2 >= 1.0:
				_estado = "reposo"
		_:
			pass
	_squash.scale = Vector3(_sx, _sq, _sz)
	_squash.position.x = desplaza_x
	_aplicar_forma()
	_animar_burbujas(delta)
	_animar_nucleo()
	material_cuerpo.set_shader_parameter("carga", _carga)
	material_cuerpo.set_shader_parameter("congelado", congelado)
	material_cuerpo.set_shader_parameter("aplastar", _temblor)


## Tamaño que se ve: crecimiento elástico (se encoge ~0,1 s, se infla pasándose un ~12 % y se asienta) y pulso de absorción del grande.
func _animar_tamano(delta: float) -> void:
	var factor: float = 1.0
	if _crec_te >= 0.0:
		_crec_te += delta
		var s0: float = _tam_ini * 0.9
		if _crec_te < 0.1:
			_tam_mostrado = lerpf(_tam_ini, s0, _crec_te / 0.1)
		elif _crec_te < T_CRECER:
			var u: float = (_crec_te - 0.1) / (T_CRECER - 0.1)
			var p: float = 1.0 - exp(-3.27 * u) * cos(2.5 * PI * u)      # pico ~+27 % del salto = ~+12 % sobre el tamaño final
			_tam_mostrado = s0 + (tamano - s0) * p
		else:
			_tam_mostrado = tamano
			_crec_te = -1.0
	if _pulso_te >= 0.0:
		_pulso_te += delta
		factor += 0.08 * sin(PI * clampf(_pulso_te / 0.4, 0.0, 1.0))
		if _pulso_te >= 0.4:
			_pulso_te = -1.0
	_escala.scale = Vector3.ONE * _tam_mostrado * factor


func _animar_salto() -> void:
	if _te < T_PREPARA:
		var k: float = _te / T_PREPARA
		_sq = lerpf(1.0, lerpf(0.62, 0.55, _g), k * k)
	elif _te < T_PREPARA + T_AIRE:
		var u: float = (_te - T_PREPARA) / T_AIRE
		var h: float = ALTO_SALTO * lerpf(1.0, 0.6, _g) * 4.0 * u * (1.0 - u)
		position = _origen + _dir * CASILLA * u + Vector3(0.0, h, 0.0)
		_sq = lerpf(0.62, 1.32, u / 0.25) if u < 0.25 else lerpf(1.32, 0.92, (u - 0.25) / 0.75)
	elif _te < T_PREPARA + T_AIRE + T_CAE:
		var k2: float = (_te - T_PREPARA - T_AIRE) / T_CAE
		position = _origen + _dir * CASILLA
		_sq = 1.0 - lerpf(0.4, 0.55, _g) * exp(-4.0 * k2) * cos(k2 * TAU * 0.9)
		_temblor = lerpf(0.25, 0.6, _g) * (1.0 - k2)
	else:
		position = _origen + _dir * CASILLA
		_sq = 1.0
		_estado = "reposo"
		en_salto = false
		salto_terminado.emit()
	_sx = 1.0 / sqrt(_sq)
	_sz = _sx


func _animar_dividir() -> void:
	var k: float = clampf(_te / T_DIVIDE, 0.0, 1.0)
	var e: float = k * k
	_sx = lerpf(1.0, 1.75, e)
	_sq = lerpf(1.0, 0.62, e)
	_sz = lerpf(1.0, 0.8, e)
	_temblor = e * 0.6
	if _te >= T_DIVIDE and not hijos.is_empty() and not (hijos[0] as Node3D).visible:
		for h in hijos:                                      # los hijos aparecen y salen a los lados mientras el original se deshace
			if is_instance_valid(h):
				var hv: LimoVisual3D = h
				hv.visible = true
				hv._estado = "sale"
				hv._te = 0.0
		dividido.emit(hijos)
	if _te >= T_DIVIDE:
		var f: float = clampf((_te - T_DIVIDE) / 0.16, 0.0, 1.0)
		_sx *= lerpf(1.0, 0.3, f)
		_sq *= lerpf(1.0, 0.2, f)
		_sz *= lerpf(1.0, 0.3, f)
		if f >= 1.0:
			_squash.visible = false
			_estado = "dividido"


## Forma del cuerpo y de lo que lleva dentro según `congelado` (el cubo es más alto y se apoya en y = −0,5 local).
func _aplicar_forma() -> void:
	var c: float = congelado
	var s: Vector3 = ESCALA_CUERPO.lerp(Vector3(0.9, 0.95, 0.9), c)
	_cuerpo.scale = s
	var fondo: float = lerpf(PLANO_BASE, -0.5, c)
	_cuerpo.position = Vector3(0.0, -fondo * s.y, 0.0)
	# La cara avanza hasta la cara del cubo y los ojos se abren («sorprendidos»).
	_cara.position = Vector3(0.0, 0.0, 0.06 * c)
	for o in _ojos:
		o.scale = Vector3.ONE * (1.0 + 0.18 * c) * (1.0 - 0.1 * _g)      # el grande, con los ojos algo más pequeños, se ve más masivo
	var comp := Vector3(1.0 / s.x, 1.0 / s.y, 1.0 / s.z)
	for ce in _cejas:
		ce.visible = _g > 0.02
		ce.scale = Vector3(0.15, 0.034, 0.03) * ESCALA_OJOS * comp * _g


func _animar_burbujas(delta: float) -> void:
	var v: float = 1.0 - congelado
	for i in _burbujas.size():
		var d: Vector4 = _datos_burbuja[i]
		var p: Vector3 = _burbujas[i].position
		p.y += d.z * delta * v * (1.0 + (5.0 if _crec_te >= 0.0 else 0.0))      # al crecer suben rápido
		if p.y > 0.3:
			p.y = -0.2
			d.x = _rng.randf_range(-0.28, 0.28)
			d.y = _rng.randf_range(-0.22, 0.22)
			_datos_burbuja[i] = d
		p.x = d.x + sin(_t * 1.3 + d.w) * 0.02
		p.z = d.y
		_burbujas[i].position = p


## El núcleo late a ~1 Hz y toma el color del elemento, más saturado que el cuerpo.
func _animar_nucleo() -> void:
	var late: float = 0.5 + 0.5 * sin(_t * TAU * 1.0)
	var base: Color = COLOR_NUCLEO_NEUTRO
	if elemento != "":
		var ce: Color = Pulso3D.color_de(elemento)
		var vivo := Color.from_hsv(ce.h, minf(ce.s * (0.92 + 0.08 * _g), 1.0), clampf(ce.v * (0.62 + 0.1 * _g), 0.0, 1.0))
		base = COLOR_NUCLEO_NEUTRO.lerp(vivo, _carga)
	elif _carga > 0.01:
		base = COLOR_NUCLEO_NEUTRO
	_mat_nucleo.set_shader_parameter("color", base)
	_mat_nucleo.set_shader_parameter("emision", (0.04 + (0.3 + 0.25 * _g) * late * _carga + 1.4 * _destello) * (1.0 - 0.6 * congelado))
	material_cuerpo.set_shader_parameter("intensidad", _g)
	var comp := Vector3(1.0 / _cuerpo.scale.x, 1.0 / _cuerpo.scale.y, 1.0 / _cuerpo.scale.z)
	var r: float = lerpf(RADIO_NUCLEO, RADIO_NUCLEO_GRANDE, _g) * 2.0 * (1.0 + 0.04 * late * (0.4 + 0.6 * _carga) + 0.35 * _destello)
	_nucleo.scale = Vector3.ONE * r * comp
	_nucleo.position = Vector3(0.0, lerpf(ALTO_NUCLEO, -0.33, congelado), lerpf(ADELANTE_NUCLEO, 0.0, congelado))
