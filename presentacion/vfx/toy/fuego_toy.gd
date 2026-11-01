class_name FuegoToy
extends EfectoToy

## FUEGO «TOY» PARAMÉTRICO (1/11/2026, rama fuego-toy-parametrico). Un solo efecto que se construye por código a partir de los tres semiejes del hechizo (x ancho, y alto,
## z fondo, en METROS) y de su figura, con los mismos shaders, texturas, rampas y mandos que las cuatro escenas validadas de la prueba 3 (BolaFuegoToy, MuroFuegoToy,
## PilarFuegoToy, BarreraFuegoToy, que no se tocan). «La lógica decide, el VFX representa»: `desde_hechizo(h)` lee `Hechizo` y rellena figura y tamaños; después da igual
## cómo cambien los ejes, la geometría sale sola (setters + `reconstruir()`).
##   BOLA     billboard de radio máx(x, z) y alto y (elipsoide: el quad y su gradiente se estiran en Y), cabeza; con `viaja`: cola, jirones y estelas (proyectil).
##   MURO     banda de 2·x de largo, y de alto y 2·z de grueso. La textura de lenguas se repite UNA vez cada ~2,9 m de contorno (lo medido en el muro validado): alargar no la estira.
##   PILAR    cilindro abierto de radio x (y z si es distinto: sección elíptica) y altura y.
##   BARRERA  elipsoide de semiejes x, y, z con el shader de la barrera (dos pasadas), la mitad de abajo hundida en el suelo como la validada.
## Origen: la bola, en su CENTRO; muro, pilar y barrera, en el suelo y centrados. Un muro se alarga por su X local (gira el nodo para ponerlo de lado).
## Los números de referencia (r 0,4 la bola; 3,45 × 1,5 × 0,3 el muro; 0,5 × 4 el pilar; 1,5 la barrera) son las medidas de las escenas validadas: con ellas, FuegoToy
## produce lo mismo que esas escenas (ver docs/capturas/comparativa_vfx/godot_toy/parametrico/NOTAS.md).

## HAZ (familia LINEAL): tubo abierto de 2·x de largo y radio z que sale del origen (la mano) hacia -Z; el eje va a altura máx(y, 0,4). Lenguas que corren a lo largo y punta que se disipa.
enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }

const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_LELU: String = "res://presentacion/vfx/toy/fuego_lelu.gdshader"
const SH_ATRAS: String = "res://presentacion/vfx/toy/fuego_lelu_atras.gdshader"
const SH_DELANTE: String = "res://presentacion/vfx/toy/fuego_lelu_delante.gdshader"
const SH_BOLA: String = "res://presentacion/vfx/toy/fuego_lelu_bola.gdshader"
const SH_CABEZA: String = "res://presentacion/vfx/toy/cabeza_toy.gdshader"
const SH_HALO: String = "res://presentacion/vfx/toy/halo_toy.gdshader"
const SH_JIRON: String = "res://presentacion/vfx/toy/jiron_toy.gdshader"
const SH_CHISPA: String = "res://presentacion/vfx/toy/chispa_toy.gdshader"

## Tamaños (semiejes en m) con los que se validó cada figura en la prueba 3.
const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)          # no validado en la prueba 3: primera versión
## Una repetición de la textura de lenguas cada tantos metros de contorno (media de lo medido en las tres escenas validadas: 2,90 · 3,14 · 3,14).
const METROS_POR_REPETICION: float = 2.9

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
## Solo BOLA: proyectil en vuelo (cola, jirones y estelas de chispas). Es el mismo `proyectil` de EfectoToy.
@export var viaja: bool = false: set = _set_viaja

static var _rampa_fuego: GradientTexture1D = null
static var _rampa_bola: GradientTexture1D = null
static var _rampa_azul: GradientTexture1D = null
static var _blob: GradientTexture2D = null

var _construido: bool = false
var _pendiente: bool = false
var _figura_anim: int = -1


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_x(v: float) -> void:
	semieje_x = maxf(v, 0.05)
	_pedir()


func _set_y(v: float) -> void:
	semieje_y = maxf(v, 0.05)
	_pedir()


func _set_z(v: float) -> void:
	semieje_z = maxf(v, 0.05)
	_pedir()


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


## Pone figura, ejes y vuelo de una vez y reconstruye una sola vez.
func definir(fig: Figura, x: float, y: float, z: float, vuela: bool = false) -> void:
	figura = fig
	semieje_x = maxf(x, 0.05)
	semieje_y = maxf(y, 0.05)
	semieje_z = maxf(z, 0.05)
	viaja = vuela
	if _construido:
		reconstruir()


func _pedir() -> void:
	if _construido and is_inside_tree() and not _pendiente:
		_pendiente = true
		call_deferred("reconstruir")


## Vuelve a hacer la geometría con los ejes actuales (los mandos y la animación se conservan).
func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


## Escala el efecto a un volumen de hechizo ({x, y, z} en casillas) sin escalar el nodo: la geometría se rehace con los semiejes en metros. `dir` orienta el eje X
## del muro de lado al tiro (como EfectoVfx3D.preparar).
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "fuego") -> void:
	semieje_x = maxf(float(volumen.get("x", 0.5)) * casilla, 0.05)
	semieje_y = maxf(float(volumen.get("y", 0.5)) * casilla, 0.05)
	semieje_z = maxf(float(volumen.get("z", 0.5)) * casilla, 0.05)
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01 and is_inside_tree():
		look_at(global_position + plano, Vector3.UP)
	if _construido:
		reconstruir()


## Elige figura, tamaño y vuelo desde un `Hechizo` (ver `describir`).
func desde_hechizo(h: Hechizo) -> void:
	var d: Dictionary = describir(h, casilla)
	definir(d["figura"], d["x"], d["y"], d["z"], d["viaja"])
	rotation.y = float(d["giro_y"])


## Figura y tamaño de un hechizo, SIN crear nada: {figura, x, y, z (m), viaja, giro_y (rad), nombre (derivado), nota}.
## Regla (plan procedural: figura explícita → superficie/columna → volumen; el proyectil es un comportamiento, no una figura):
##   · haz (ᛁ línea, `h.haz`): HAZ, largo = alcance del haz, radio = HAZ_ANCHO / 2, eje a la altura de la mano.
##   · viaja (o velocidad > 0): BOLA con cola, con los semiejes EN VUELO (× Hechizo.ESCALA_PROYECTIL).
##   · solidez > 0 (barrera): MURO si es alargada en planta (largo ≥ 2 × fondo), si no BARRERA (cúpula).
##   · sin solidez: nombre_derivado «alto» → PILAR; alargado en planta → MURO; lo demás (esfera, elipsoide, zona plana redonda) → BOLA (nota si es plana).
## Los semiejes de Hechizo están en casillas y se pasan a metros con `casilla` (2,3, como VfxElemento3D).
static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	var vuela: bool = h.viaja or h.velocidad > 0.0
	var s: Vector3 = (h.semiejes_vuelo if vuela else h.semiejes) * casilla_m
	var nombre: String = Hechizo.nombre_derivado(h.semieje_x, h.semieje_y, h.semieje_z, vuela)
	var largo: float = maxf(s.x, s.z)
	var corto: float = minf(s.x, s.z)
	var alargado: bool = largo >= 2.0 * corto - 0.0001
	var fig: Figura = Figura.BOLA
	var nota: String = ""
	var y_haz: float = 0.0
	var z_haz: float = 0.0
	if h.haz:
		# haz (ᛁ línea): `nombre_derivado` no distingue el haz (da «x_mano»), lo decide `h.haz`. Largo = alcance del haz (m-casilla) × casilla; radio = la mitad del grosor de dibujo.
		fig = Figura.HAZ
		y_haz = Hechizo.ALTURA_MANO_U
		z_haz = Hechizo.HAZ_ANCHO * casilla_m * 0.5
	elif vuela:
		fig = Figura.BOLA
	elif h.solidez > 0.0:
		fig = Figura.MURO if alargado else Figura.BARRERA
	elif nombre == "alto":
		fig = Figura.PILAR
	elif alargado:
		fig = Figura.MURO
	else:
		fig = Figura.BOLA
		if nombre == "abajo":
			nota = "zona plana redonda: sin figura propia, se dibuja como BOLA aplanada"
	var x: float = s.x
	var z: float = s.z
	var giro: float = 0.0
	if fig == Figura.MURO and s.z > s.x:
		x = s.z                      # el muro se alarga por su X: se gira 90° si lo largo es el fondo
		z = s.x
		giro = PI * 0.5
	if fig == Figura.HAZ:
		return {"figura": fig, "x": h.alcance_haz * casilla_m * 0.5, "y": y_haz, "z": z_haz, "viaja": false, "giro_y": 0.0, "nombre": nombre, "nota": ""}
	return {"figura": fig, "x": x, "y": s.y, "z": z, "viaja": vuela and not h.haz, "giro_y": giro, "nombre": nombre, "nota": nota}


## Radio «grande» del efecto, en metros: lo usan la luz y la cámara del lab.
func extension() -> float:
	return _extension(figura, semieje_x, semieje_y, semieje_z)


static func _extension(fig: Figura, x: float, y: float, z: float) -> float:
	match fig:
		Figura.BOLA:
			return maxf(x, z)
		Figura.MURO, Figura.HAZ:
			return x
		Figura.PILAR:
			return sqrt(pow(maxf(x, z), 2.0) + pow(y * 0.5, 2.0))
	return maxf(maxf(x, y), z)


static func _extension_ref(fig: Figura) -> float:
	match fig:
		Figura.BOLA:
			return _extension(fig, REF_BOLA.x, REF_BOLA.y, REF_BOLA.z)
		Figura.MURO:
			return _extension(fig, REF_MURO.x, REF_MURO.y, REF_MURO.z)
		Figura.PILAR:
			return _extension(fig, REF_PILAR.x, REF_PILAR.y, REF_PILAR.z)
		Figura.HAZ:
			return REF_HAZ.x
	return _extension(fig, REF_BARRERA.x, REF_BARRERA.y, REF_BARRERA.z)


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var cuerpo: Node3D = get_node_or_null("Cuerpo") as Node3D
	if cuerpo == null:
		cuerpo = Node3D.new()
		cuerpo.name = "Cuerpo"
		add_child(cuerpo)
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.free()
	var luz: OmniLight3D = get_node_or_null("Luz") as OmniLight3D
	if luz == null:
		luz = OmniLight3D.new()
		luz.name = "Luz"
		luz.light_color = Color(1.0, 0.5, 0.22)
		luz.omni_attenuation = 1.4
		luz.shadow_enabled = false
		add_child(luz)
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = -0.12
	match figura:
		Figura.BOLA:
			_bola(cuerpo, luz)
		Figura.MURO:
			_muro(cuerpo, luz)
		Figura.PILAR:
			_pilar(cuerpo, luz)
		Figura.BARRERA:
			_barrera(cuerpo, luz)
		Figura.HAZ:
			_haz(cuerpo, luz)
	_anim_si_hace_falta()


func _ajustar_luz(luz: OmniLight3D, pos: Vector3, energia: float, rango: float) -> void:
	var f: float = extension() / _extension_ref(figura)
	luz.position = pos
	luz.light_energy = energia * clampf(f, 0.4, 1.6)
	luz.omni_range = rango * clampf(f, 0.4, 2.0)


## Ruido numérico: cuántas partículas (mínimo 1) al tamaño dado respecto al validado.
static func _cant(base: float, factor: float, minimo: int, maximo: int) -> int:
	return clampi(int(round(base * factor)), minimo, maximo)


# ---- BOLA ----

func _bola(c: Node3D, luz: OmniLight3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var k: float = r / REF_BOLA.x
	var ky: float = 1.0 if viaja else clampf(semieje_y / r, 0.25, 4.0)
	_halo(c, "Halo", Vector2(2.0 * k, 2.0 * k * ky), Vector3(0, 0.05 * k, 0), 0.3, 3.0, 2, Color(1.0, 0.28, 0.06))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.4 * k, 2.4 * k)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Llama"
	mi.mesh = q
	mi.material_override = _mat_fuego(SH_BOLA, {"semilla": 0.3, "tam": 2.4 * k, "radio": 0.52 * k, "desplaza": 0.1 * k,
		"repeticion": Vector2(0.8, 0.65) / k, "rep_ruido": Vector2(0.7, 0.5) / k}, 0, _rampa_de_bola())
	mi.scale = Vector3(1.0, ky, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	# frente: cabeza, halo brillante y destello de 4 puntas (solo en vuelo)
	var fr: Node3D = Node3D.new()
	fr.name = "Frente"
	c.add_child(fr)
	_halo(fr, "Destello", Vector2(0.8 * k, 0.8 * k), Vector3.ZERO, 0.4, 2.8, 2, Color(1.0, 0.4, 0.1), {"latido": 0.12})
	var cab: MeshInstance3D = MeshInstance3D.new()
	cab.name = "Cabeza"
	var cq: QuadMesh = QuadMesh.new()
	cq.size = Vector2(k, k)
	cab.mesh = cq
	var cm: ShaderMaterial = ShaderMaterial.new()
	cm.shader = load(SH_CABEZA)
	cm.render_priority = 2
	cm.set_shader_parameter("ruido", load(TEX + "T_PerlinNoise_Tiled.png"))
	cm.set_shader_parameter("radio", 0.22 * k)
	cm.set_shader_parameter("tam", k)
	cab.material_override = cm
	cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(cab)
	var flare: MeshInstance3D = MeshInstance3D.new()
	flare.name = "Estrella"
	var fq: QuadMesh = QuadMesh.new()
	fq.size = Vector2(1.05 * k, 1.05 * k)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	fm.albedo_color = Color(1.0, 0.92, 0.75, 0.85)
	fm.render_priority = 3
	fq.material = fm
	flare.mesh = fq
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(flare)
	_avance_cabeza = -0.12 * k
	_vuelo(c, k)
	_trocitos(c, _cant(2.0, k, 1, 6), Vector3(0.1, 0.05, 0.1) * k, Vector3(0, 0.55 * k * ky, 0), k)
	_particulas(c, "Chispas", _cant(8.0, k, 4, 24), 1.3, 0.07 * k, Vector3(0.2, 0.15 * ky, 0.2) * k, Vector2(0.3, 0.8) * k, Vector3(0, 1, 0), 40.0, Vector3(0, 0.35 * k, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.62, 0.22, 1.0), Color(1.0, 0.55, 0.15, 0.0)], "chispas", Vector3.ZERO, r * 2.0 + 4.0)
	_ajustar_luz(luz, Vector3.ZERO, 1.1, 4.5)


## Jirones de llama y chispas con estela larga y fina: solo emiten con `proyectil` (grupo «vuelo»); quedan en el mundo.
func _vuelo(c: Node3D, k: float) -> void:
	_particulas_vuelo(c, "Jirones", 5, 0.45, Vector3(0.12, 0.12, 0.05) * k, Vector2(1.0, 2.0) * k, 30.0, Vector2(0.28, 0.55),
		[Color(1.0, 0.55, 0.12, 0.95), Color(0.95, 0.28, 0.06, 0.7), Color(0.8, 0.12, 0.03, 0.0)], SH_JIRON, Vector2(k, k))
	var ch: GPUParticles3D = _particulas_vuelo(c, "ChispasEstela", 6, 0.7, Vector3(0.28, 0.28, 0.05) * k, Vector2(0.5, 1.4) * k, 38.0, Vector2(0.5, 1.2),
		[Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(1.0, 0.35, 0.08, 0.0)], SH_CHISPA, Vector2(0.05 * k, 1.0 * k))
	var cab: QuadMesh = QuadMesh.new()
	cab.size = Vector2(0.26, 0.26) * k
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	cab.material = sm
	ch.draw_passes = 2
	ch.draw_pass_2 = cab


func _particulas_vuelo(c: Node3D, nombre: String, cantidad: int, vida_s: float, caja: Vector3, vel: Vector2, abierto: float, escala: Vector2, colores: Array,
		shader: String, tam: Vector2) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.local_coords = false
	gp.emitting = false
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3(0, 0, 1)
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3.ZERO
	pm.scale_min = escala.x
	pm.scale_max = escala.y
	pm.color_ramp = _gradiente(colores)
	gp.process_material = pm
	var malla: QuadMesh = QuadMesh.new()
	malla.size = tam
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	malla.material = m
	gp.draw_pass_1 = malla
	gp.add_to_group("vuelo", true)
	c.add_child(gp)
	return gp


# ---- MURO ----

func _muro(c: Node3D, luz: OmniLight3D) -> void:
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	var fl: float = a / REF_MURO.x
	var fa: float = alto / REF_MURO.y
	var fb: float = clampf(b / REF_MURO.z, 0.5, 3.0)
	_halo(c, "Charco", Vector2(7.6 * fl, 2.4 * fb), Vector3(0, 0.04, 0), 0.5, 1.6, 0, Color(1.0, 0.28, 0.06), {"latido": 0.05})
	_halo(c, "Resplandor", Vector2(7.2 * fl, 2.2 * fa), Vector3(0, 0.55 * fa, 0), 0.22, 2.6, 2, Color(1.0, 0.28, 0.06))
	# banda exterior: el contorno es una superelipse de 2a × 2b; las repeticiones de la textura se cuentan por METROS de contorno (no se estira al alargar)
	var seg: int = FuegoToyMallas.segmentos(FuegoToyMallas.largo_contorno(a, b, 6.0))
	var banda: ArrayMesh = FuegoToyMallas.banda(a, b, 6.0, FuegoToyMallas.perfil_muro(alto, 0.78), seg)
	var m: Array = FuegoToyMallas.M_MURO
	var largo: float = FuegoToyMallas.largo_contorno(a, b, 6.0)
	_fuego(c, "Banda", banda, Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(largo, m[0]), alto / float(m[1])),
		"rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(largo, m[2]), alto / float(m[3])), "semilla": 0.05, "velocidad": 1.0, "umbral": 0.27, "desfase": 0.45,
		"fuerza_grad": 1.05, "amplitud_vert": 0.16 * clampf(b / REF_MURO.z, 0.5, 2.0)}, 0)
	var ai: float = a * 0.957
	var bi: float = b * 0.4
	var hi: float = alto * 0.7
	var largo_i: float = FuegoToyMallas.largo_contorno(ai, bi, 6.0)
	var mi_: Array = FuegoToyMallas.M_MURO_IN
	var banda_in: ArrayMesh = FuegoToyMallas.banda(ai, bi, 6.0, FuegoToyMallas.perfil_muro(hi, 0.7), FuegoToyMallas.segmentos(largo_i))
	_fuego(c, "Interior", banda_in, Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(largo_i, mi_[0]), hi / float(mi_[1])),
		"rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(largo_i, mi_[2]), hi / float(mi_[3])), "semilla": 0.4, "velocidad": 1.5, "umbral": 0.27, "desfase": 0.45,
		"fuerza_grad": 1.0, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.16 * clampf(b / REF_MURO.z, 0.5, 2.0)}, 1)
	var vv: float = clampf(fa, 0.5, 2.5)
	_trocitos(c, _cant(3.0, fl, 1, 10), Vector3(a * 0.87, 0.05, b * 0.5), Vector3(0, 0.667 * alto, 0), vv)
	_particulas(c, "Chispas", _cant(14.0, fl, 5, 60), 1.4, 0.07, Vector3(a * 0.93, 0.1, b * 0.67), Vector2(0.3, 0.9) * vv, Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.333 * alto, 0), a * 2.0 + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.467 * alto, 0), 1.6, 6.5)


# ---- PILAR ----

func _pilar(c: Node3D, luz: OmniLight3D) -> void:
	var rx: float = semieje_x
	var rz: float = semieje_z
	var alto: float = semieje_y
	var rm: float = (rx + rz) * 0.5
	var fa: float = alto / REF_PILAR.y
	var fr: float = rm / REF_PILAR.x
	_halo(c, "Charco", Vector2(5.2 * rx, 5.2 * rz), Vector3(0, 0.04, 0), 0.45, 1.8, 0, Color(1.0, 0.28, 0.06), {"anillo": 0.5})
	_halo(c, "Resplandor", Vector2(6.8 * rm, 1.05 * alto), Vector3(0, 0.35 * alto, 0), 0.2, 2.8, 2, Color(1.0, 0.28, 0.06))
	var amp: float = clampf(fr, 0.5, 2.0)
	var l1: float = FuegoToyMallas.perimetro_elipse(rx, rz)
	var m: Array = FuegoToyMallas.M_PILAR
	_fuego(c, "Exterior", FuegoToyMallas.banda(rx, rz, 2.0, FuegoToyMallas.perfil_cilindro(0.72, alto), FuegoToyMallas.segmentos(l1)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l1, m[0]), alto / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l1, m[2]), alto / float(m[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.2, "velocidad": 0.9, "amplitud_vert": 0.2 * amp}, 0)
	var rxi: float = rx * 0.6
	var rzi: float = rz * 0.6
	var hi: float = alto * 0.775
	var l2: float = FuegoToyMallas.perimetro_elipse(rxi, rzi)
	var mn: Array = FuegoToyMallas.M_PILAR_IN
	_fuego(c, "Nucleo", FuegoToyMallas.banda(rxi, rzi, 2.0, FuegoToyMallas.perfil_cilindro(0.5333, hi), FuegoToyMallas.segmentos(l2)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l2, mn[0]), hi / float(mn[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l2, mn[2]), hi / float(mn[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.6, "velocidad": 1.5, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.12 * amp}, 1)
	# Pilares más gordos que el validado (r 0,5): un cilindro de lenguas con solo dos capas se ve hueco (un aro a rayas). Se añaden capas intermedias, una cada ~0,4 m de
	# radio por encima de 0,55 (máx. 3), entre el exterior y el núcleo, cada una con su semilla y su velocidad, para que el pilar se vea tan lleno como el validado.
	var n_extra: int = clampi(int(round((rm - 0.55) / 0.4)) + (1 if rm > 0.55 else 0), 0, 3)
	for i in n_extra:
		var f: float = lerpf(1.0, 0.6, float(i + 1) / float(n_extra + 1))      # fracción del radio del exterior
		var rxc: float = rx * f
		var rzc: float = rz * f
		var hc: float = alto * lerpf(1.0, 0.775, float(i + 1) / float(n_extra + 1))
		var lc: float = FuegoToyMallas.perimetro_elipse(rxc, rzc)
		_fuego(c, "Capa%d" % i, FuegoToyMallas.banda(rxc, rzc, 2.0, FuegoToyMallas.perfil_cilindro(lerpf(0.72, 0.5333, float(i + 1) / float(n_extra + 1)), hc), FuegoToyMallas.segmentos(lc)),
			Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(lc, m[0]), hc / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(lc, m[2]), hc / float(m[3])),
			"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.33 + 0.21 * float(i), "velocidad": 1.1 + 0.2 * float(i), "calor_extra": 0.15,
			"amplitud_vert": 0.16 * amp}, 1)
	var area: float = sqrt(clampf(fr * fa, 0.05, 6.0))
	var vv: float = clampf(fa, 0.5, 2.5)
	_trocitos(c, _cant(3.0, area, 1, 10), Vector3(rx * 0.6, 0.1, rz * 0.6), Vector3(0, 0.75 * alto, 0), vv)
	_particulas(c, "Chispas", _cant(16.0, area, 6, 60), 1.8, 0.07, Vector3(rx * 0.6, 0.1, rz * 0.6), Vector2(0.6, 1.5) * vv, Vector3(0, 1, 0), 20.0, Vector3(0, 0.5, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.075 * alto, 0), rm * 2.0 + alto + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.325 * alto, 0), 2.0, 7.0)


# ---- BARRERA ----

func _barrera(c: Node3D, luz: OmniLight3D) -> void:
	var rx: float = semieje_x
	var ry: float = semieje_y
	var rz: float = semieje_z
	var rh: float = maxf(rx, rz)
	var fr: float = rh / REF_BARRERA.x
	_halo(c, "Anillo", Vector2(2.6 * rx, 2.6 * rz), Vector3(0, 0.03, 0), 0.8, 1.0, 0, Color(1.0, 0.28, 0.06), {"anillo": 1.0, "latido": 0.04})
	var m: Array = FuegoToyMallas.M_BARRERA
	var ecuador: float = FuegoToyMallas.perimetro_elipse(rx, rz)
	var meridiano: float = FuegoToyMallas.perimetro_elipse(rh, ry) * 0.5
	var malla: ArrayMesh = FuegoToyMallas.elipsoide(rx, ry, rz, 25, clampi(int(round(ecuador / 0.2)), 48, 160))
	# mínimos de repeticiones (una barrera pequeña con 1-2 repeticiones casi no tiene lenguas): 3 por vuelta y 1 en vertical; no cambian la de 1,5 (3; 1,4) ni la de 3
	var p: Dictionary = {"repeticion": Vector2(maxf(3.0, FuegoToyMallas.repeticiones_u(ecuador, m[0])), maxf(1.0, meridiano / float(m[1]))),
		"rep_ruido": Vector2(maxf(3.0, FuegoToyMallas.repeticiones_u(ecuador, m[2])), maxf(1.5, meridiano / float(m[3]))), "v_base": 0.3, "umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.15,
		"pot_grad": 1.1, "giro": 0.25, "resplandor_borde": 0.45, "escala_rampa": 1.3, "calor_extra": 0.05, "amplitud_vert": 0.1 * clampf(fr, 0.5, 2.0), "velocidad": 1.0,
		"transparencia": 0.92}
	var mi: MeshInstance3D = _fuego(c, "Cascara", malla, Vector3(0, 0.4 * ry, 0), p, 0, SH_ATRAS)
	(mi.material_override as ShaderMaterial).next_pass = _mat_fuego(SH_DELANTE, p, 1)
	var area: float = clampf(fr, 0.3, 3.0)
	var vv: float = clampf(ry / REF_BARRERA.y, 0.5, 2.5)
	_trocitos(c, _cant(3.0, area, 1, 10), Vector3(rx * 0.67, 0.1, rz * 0.67), Vector3(0, 1.2 * ry, 0), vv)
	_particulas(c, "Chispas", _cant(14.0, area * area, 5, 60), 1.6, 0.07, Vector3(rx * 0.8, 0.1, rz * 0.8), Vector2(0.3, 0.9) * vv, Vector3(0, 1, 0), 25.0, Vector3(0, 0.5, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.133 * ry, 0), rh * 2.0 + ry + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.467 * ry, 0), 1.5, 5.5)


# ---- HAZ ----

## Tubo abierto de radio z y largo 2·x, de la mano (origen) hacia -Z a la altura máx(y, 0,4). Es el cilindro del pilar tumbado (el eje de la malla, Y, pasa a -Z): U da la vuelta
## y V va de la mano a la punta, así que las lenguas corren por el tubo hacia la punta y el gradiente restado la disipa. Núcleo interior más estrecho y caliente.
func _haz(c: Node3D, luz: OmniLight3D) -> void:
	var largo: float = semieje_x * 2.0
	var r: float = semieje_z
	var h: float = maxf(semieje_y, 0.4)
	var eje: Node3D = Node3D.new()
	eje.name = "Eje"
	eje.position = Vector3(0, h, 0)
	eje.rotation = Vector3(-PI * 0.5, 0, 0)         # +Y de la malla → -Z
	c.add_child(eje)
	var m: Array = FuegoToyMallas.M_PILAR
	var amp: float = clampf(r / 0.5, 0.3, 1.0)
	var l1: float = FuegoToyMallas.perimetro_elipse(r, r)
	_fuego(eje, "Exterior", FuegoToyMallas.banda(r, r, 2.0, FuegoToyMallas.perfil_cilindro(0.55, largo), FuegoToyMallas.segmentos(l1)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l1, m[0]), largo / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l1, m[2]), largo / float(m[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.2, "velocidad": 1.6, "amplitud_vert": 0.2 * amp}, 0)
	var ri: float = r * 0.55
	var l2: float = FuegoToyMallas.perimetro_elipse(ri, ri)
	_fuego(eje, "Nucleo", FuegoToyMallas.banda(ri, ri, 2.0, FuegoToyMallas.perfil_cilindro(0.5, largo * 0.85), FuegoToyMallas.segmentos(l2)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l2, m[0]), largo * 0.85 / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l2, m[2]), largo * 0.85 / float(m[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.6, "velocidad": 2.2, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.12 * amp}, 1)
	_halo(c, "Base", Vector2(4.0 * r + 0.5, 4.0 * r + 0.5), Vector3(0, h, 0), 0.5, 2.4, 2, Color(1.0, 0.28, 0.06))
	var f: float = clampf(largo / (2.0 * REF_HAZ.x), 0.4, 3.0)
	_trocitos(c, _cant(3.0, f, 1, 10), Vector3(r, r, largo * 0.15), Vector3(0, h, -largo * 0.8), 1.0)
	_particulas(c, "Chispas", _cant(10.0, f, 4, 40), 1.0, 0.07, Vector3(r, r, largo * 0.45), Vector2(0.3, 0.9), Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, h, -largo * 0.5), largo + 6.0)
	_ajustar_luz(luz, Vector3(0, h, -largo * 0.4), 1.4, 5.0)


# ------------------------------------------------------------------ ladrillos ------------------------------------------------------------------

static func _gradiente(colores: Array, offs: Array = []) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	var o: PackedFloat32Array = PackedFloat32Array()
	var cs: PackedColorArray = PackedColorArray()
	for i in colores.size():
		o.append(float(offs[i]) if offs.size() == colores.size() else float(i) / float(maxi(colores.size() - 1, 1)))
		cs.append(colores[i])
	g.offsets = o
	g.colors = cs
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t


static func _rampas() -> void:
	if _rampa_fuego != null:
		return
	var offs: Array = [0.0, 0.22, 0.62, 0.9, 1.0]
	_rampa_fuego = _gradiente([Color(0.85, 0.12, 0.03), Color(1.0, 0.32, 0.03), Color(1.0, 0.52, 0.08), Color(1.0, 0.74, 0.2), Color(1.0, 0.93, 0.62)], offs)
	_rampa_fuego.width = 128
	_rampa_bola = _gradiente([Color(0.85, 0.12, 0.03), Color(1.0, 0.32, 0.03), Color(1.0, 0.52, 0.08), Color(1.0, 0.64, 0.14), Color(1.0, 0.8, 0.42)], offs)
	_rampa_bola.width = 128
	_rampa_azul = _gradiente([Color(0.05, 0.2, 0.85), Color(0.15, 0.4, 1.0), Color(0.3, 0.65, 1.0), Color(0.55, 0.85, 1.0), Color(0.9, 0.98, 1.0)], offs)
	_rampa_azul.width = 128


static func _rampa_de_bola() -> GradientTexture1D:
	_rampas()
	return _rampa_bola


func _mat_fuego(shader: String, p: Dictionary, prio: int = 0, rampa: GradientTexture1D = null) -> ShaderMaterial:
	_rampas()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prio
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	m.set_shader_parameter("ruido_a", load(TEX + "T_PerlinNoise_Tiled.png"))
	m.set_shader_parameter("ruido_v", load(TEX + "T_CloudNoise_Tiled.png"))
	m.set_shader_parameter("ruido_fino", load(TEX + "T_Noise1_tiled.png"))
	m.set_shader_parameter("rampa", rampa if rampa != null else _rampa_fuego)
	m.set_shader_parameter("rampa_azul", _rampa_azul)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


func _fuego(padre: Node, nombre: String, malla: Mesh, pos: Vector3, p: Dictionary, prio: int = 0, shader: String = SH_LELU) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.material_override = _mat_fuego(shader, p, prio)
	mi.position = pos
	mi.extra_cull_margin = 0.6 + semieje_y * 2.0          # las mallas se estiran con el mando `altura` (hasta 3) y se desplazan con el ruido
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


func _halo(padre: Node, nombre: String, tam: Vector2, pos: Vector3, brillo: float, caida: float, billboard: int, color: Color, extra: Dictionary = {}) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = tam
	if billboard == 0:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HALO)
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("caida", caida)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("semilla", randf())
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	m.render_priority = -1
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


static func _textura_blanda() -> GradientTexture2D:
	if _blob != null:
		return _blob
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_blob = GradientTexture2D.new()
	_blob.gradient = g
	_blob.fill = GradientTexture2D.FILL_RADIAL
	_blob.fill_from = Vector2(0.5, 0.5)
	_blob.fill_to = Vector2(1.0, 0.5)
	_blob.width = 64
	_blob.height = 64
	return _blob


## Partículas blandas y pequeñas (la rampa de colores va de nacer a morir). `visto`: radio en planta que cubre su caja de visibilidad.
func _particulas(padre: Node, nombre: String, cantidad: int, vida_s: float, tam: float, caja: Vector3, vel: Vector2, dir: Vector3, abierto: float, gravedad: Vector3,
		colores: Array, grupo: String, pos: Vector3, visto: float) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.position = pos
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.local_coords = true
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var e: float = maxf(6.0, visto)
	gp.visibility_aabb = AABB(Vector3(-e, -3, -e), Vector3(2.0 * e, 12.0 + semieje_y * 2.0, 2.0 * e))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = dir
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravedad
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color_ramp = _gradiente(colores)
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.0))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1, 0.15))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _textura_blanda()
	sm.disable_receive_shadows = true
	q.material = sm
	gp.draw_pass_1 = q
	gp.add_to_group(grupo, true)
	padre.add_child(gp)
	return gp


## Trocitos de llama que se desprenden de las puntas (rampa amarillo → naranja → rojo). `v`: factor de velocidad.
func _trocitos(c: Node, cantidad: int, caja: Vector3, pos: Vector3, v: float) -> void:
	_particulas(c, "Trocitos", cantidad, 0.5, 0.2, caja, Vector2(0.7, 1.4) * v, Vector3(0, 1, 0), 15.0, Vector3(0, 0.4, 0) * v,
		[Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.38, 0.08, 0.8), Color(0.85, 0.15, 0.04, 0.0)], "trocitos", pos, maxf(caja.x, caja.z) * 2.0 + 4.0)


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var nacer: float = 0.3
	var morir_s: float = 0.5
	match figura:
		Figura.PILAR:
			nacer = 0.4
			morir_s = 0.6
		Figura.BARRERA:
			nacer = 0.5
			morir_s = 0.6
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:aparicion"))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, nacer, 1.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 1.0)
				an.track_insert_key(pista, morir_s, 0.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s
