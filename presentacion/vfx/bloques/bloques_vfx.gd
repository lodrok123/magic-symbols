extends Node3D

## EFECTOS «BLOQUES» (25/11/2026). Pablo pasó capturas de la demo de EffectBlocks (pack de pago de PolyBlocks) y pidió hacer NOSOTROS lo que le interesa, porque del pack
## solo se usaría un 40 %. Nada sale de la demo: son efectos nuevos, hechos con piezas del juego, con la PALETA DE CADA ELEMENTO que ya hay en el mundo (regla de Pablo).
## Lo que hay (cada uno con su `crear_*`; se ven todos en LabVfxComparativa3D con Ctrl+9, laboratorios/lab_bloques_vfx.gd):
##   · llama de veneno del chamán goblin (la «magic flame» de la demo, en verde veneno), quieta en el bastón o en vuelo (deja estela)
##   · humo tóxico (ambiente del pantano), en verde veneno o en morado
##   · explosión por elemento: fuego, agua, tierra (humo hexagonal + trozos + destello) y la ELÉCTRICA (con arcos de rayo)
##   · rayo: ondas eléctricas, chispas eléctricas, bola de rayo (trazos de rayo_trazos.gd: la misma línea quebrada y paleta que el rayo del juego)
##   · destellos (botín) y portal (fuego o agua)
##   · decals en el suelo (decal_suelo.gdshader vía TierraToy.crear_decal_suelo, se pegan al relieve): grietas (tierra, magma, rayo, veneno), pisadas y salpicadura de limo
## Las máscaras de las grietas, pisadas y manchas se GENERAN por código (con semilla): cada grieta sale distinta y no hace falta ninguna textura nueva.
## Sin class_name (como sprite_toy.gd): `const BloquesVfx = preload("res://presentacion/vfx/bloques/bloques_vfx.gd")`.
## Uso:  var e := BloquesVfx.crear_explosion("fuego"); padre.add_child(e); e.global_position = punto      (las de un disparo se liberan solas)

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")
const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const RUTA: String = "res://presentacion/vfx/bloques/bloques_vfx.gd"
const SH_PORTAL: String = "res://presentacion/vfx/bloques/bloque_portal.gdshader"

# ------------------------------------------------------------------ MANDOS (para ajustar a mano) ------------------------------------------------------------------

## Llama de veneno del chamán
const VENENO_ALTO_LLAMA: float = 0.75          ## m que sube la llama
const VENENO_TAM_BOCANADA: float = 0.40        ## m de cada hexágono de la llama
const VENENO_BOCANADAS: int = 34
const VENENO_MOTAS: int = 22                   ## puntitos verdes que flotan alrededor
const VENENO_LUZ: float = 1.2                  ## energía de la luz verde (0 = sin luz)
const VENENO_K_BASTON: float = 0.75           ## escala de la llama en la punta del bastón del chamán del juego (mide 0,85 u)
const VENENO_K_FLECHA: float = 0.35            ## escala de la llama que lleva la flecha de veneno
const VENENO_VIDA_FLECHA: float = 0.28         ## s de cada bocanada de la estela de la flecha (largo de la estela ≈ esto × 9 u/s)
## Humo tóxico
const HUMO_BOCANADAS: int = 18
const HUMO_VIDA: float = 3.6                   ## s que tarda cada bocanada en deshacerse
const HUMO_TAM: float = 0.75
const HUMO_MORADO: Array = [Color(0.66, 0.48, 0.88), Color(0.47, 0.31, 0.72), Color(0.30, 0.20, 0.46)]   ## el de la demo, por si Pablo lo prefiere al verde
## Explosiones
const EXPLOSION_TROZOS: int = 18
const EXPLOSION_HUMO: int = 16
const EXPLOSION_TAM_HUMO: float = 0.55
const EXPLOSION_VEL_TROZOS: Vector2 = Vector2(2.4, 4.4)
const EXPLOSION_DURACION: float = 1.6          ## s hasta liberarse
## Rayo
const ONDAS_LARGO: float = 2.4                 ## m de la banda de ondas eléctricas
const ONDAS_HEBRAS: int = 3
const ONDAS_AMPLITUD: float = 0.15
const BOLA_RADIO: float = 0.42
const BOLA_ARCOS: int = 6
const CHISPAS_RADIO: float = 0.45              ## m de la zona donde saltan
const REFRESCO_ARCOS: float = 0.05             ## s entre un dibujo de los arcos y el siguiente (el rayo «salta», no se desliza)
## Decals
const GRIETA_TAM: float = 1.6                  ## m de lado de la caja de la grieta
const PISADA_PASO: float = 0.26                ## m entre pisada y pisada
const PISADA_CADENCIA: float = 0.32            ## s entre pisada y pisada
const PISADA_VIDA: float = 3.2                 ## s que se ve cada pisada (las últimas 0,8 se borra)
const PISADA_COLOR: Color = Color(0.17, 0.11, 0.07)   ## barro oscuro (pardo de TierraToy, más hondo)
const DECAL_ALTO: float = 0.6                  ## m de alto de la caja de los decals (lo que abarca de relieve)

## Grietas: color de la grieta, color y fuerza del brillo, y forma de la máscara. Los colores salen de cada elemento del juego.
static func estilos_grieta() -> Dictionary:
	return {
		"tierra": {"color": Color(0.07, 0.045, 0.03), "emision_color": Color.BLACK, "emision": 0.0, "forma": "impacto"},
		"magma": {"color": Color(0.5, 0.09, 0.03), "emision_color": Color(1.0, 0.28, 0.06), "emision": 2.6, "forma": "seca"},
		"rayo": {"color": RayoPaleta.HALO_BORDE, "emision_color": RayoPaleta.HALO, "emision": 3.0, "forma": "impacto"},
		"veneno": {"color": NubeVenenoVfx.VERDE_OSCURO, "emision_color": NubeVenenoVfx.VERDE, "emision": 1.4, "forma": "rama"},
	}


## Colores de cada elemento, de lo que ya hay en el juego: fuego = FuegoToy (rojos y naranjas, nunca amarillo), agua = AguaPaleta, tierra = TierraToy / ImpactoTierraToy,
## rayo = RayoPaleta, veneno = NubeVenenoVfx.
static func colores(el: String) -> Dictionary:
	var d: Dictionary = _colores_base(el)
	d["chispa"] = {"fuego": Color(1.0, 0.4, 0.1), "agua": AguaPaleta.CAUSTICAS, "tierra": TierraToy.COLOR_PUA, "rayo": Color(0.85, 0.93, 1.0),
		"veneno": NubeVenenoVfx.VERDE_CLARO}.get(el, Color(1.0, 0.4, 0.1))          ## los trozos que salen despedidos (el fuego, naranja: nunca amarillo)
	return d


static func _colores_base(el: String) -> Dictionary:
	match el:
		"agua":
			return {"caliente": AguaPaleta.ESPUMA, "brillo": AguaPaleta.CAUSTICAS, "humo": AguaPaleta.SOMERO, "humo_viejo": AguaPaleta.HONDO, "luz": AguaPaleta.SOMERO,
				"aditivo": false, "luz_fuerza": 0.8, "destello": 0.9}
		"tierra":
			return {"caliente": ImpactoTierraToy.CENTRO_CLARO, "brillo": TierraToy.COLOR_PUA, "humo": TierraToy.POLVO_SOMBRA, "humo_viejo": TierraToy.POLVO_VIEJO, "luz": Color.BLACK,
				"aditivo": false, "luz_fuerza": 0.0, "destello": 0.0}
		"rayo":
			return {"caliente": RayoPaleta.NUCLEO, "brillo": RayoPaleta.HALO_BORDE, "humo": Color(0.10, 0.11, 0.14), "humo_viejo": Color(0.22, 0.24, 0.3), "luz": RayoPaleta.LUZ,
				"aditivo": true, "luz_fuerza": 3.0, "destello": 1.1}
		"veneno":
			return {"caliente": NubeVenenoVfx.VERDE_NUCLEO, "brillo": NubeVenenoVfx.VERDE_CLARO, "humo": NubeVenenoVfx.VERDE_OSCURO, "humo_viejo": NubeVenenoVfx.CENIZA, "luz": NubeVenenoVfx.VERDE,
				"aditivo": true, "luz_fuerza": 1.2, "destello": 1.0}
	return {"caliente": Color(1.0, 0.5, 0.15), "brillo": Color(1.0, 0.28, 0.06), "humo": FuegoToy.PILAR_HUMO_SOMBRA, "humo_viejo": FuegoToy.PILAR_HUMO_VIEJO, "luz": Color(1.0, 0.5, 0.22),
		"aditivo": true, "luz_fuerza": 3.0, "destello": 1.6}


# ------------------------------------------------------------------ estado de cada efecto ------------------------------------------------------------------

var tipo: String = ""
var elemento: String = "fuego"
var p: Dictionary = {}                         ## lo que cada tipo necesita
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _luz: OmniLight3D = null
var _luz_base: float = 0.0
var _trazos: MultiMeshInstance3D = null
var _destellos: MultiMeshInstance3D = null
var _reloj_arcos: float = 0.0
var _chispas: Array = []                       ## chispas eléctricas vivas: {pts, t, vida, fase}
var _proxima_chispa: float = 0.0
var _pisadas: Array = []                       ## {nodo, t0}
var _decal: MeshInstance3D = null


static func _nuevo(tipo_: String, nombre: String) -> Node3D:
	var e: Node3D = (load(RUTA) as GDScript).new()
	e.name = nombre
	e.set("tipo", tipo_)
	return e


func _ready() -> void:
	_rng.randomize()


## Lo que dura (las de un disparo); -1 = sigue hasta que la quiten.
func duracion() -> float:
	return float(p.get("duracion", -1.0))


func _process(delta: float) -> void:
	_t += delta
	match tipo:
		"veneno":
			if _luz != null:
				_luz.light_energy = _luz_base * (0.82 + 0.18 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0))
		"explosion":
			_paso_explosion()
		"ondas":
			_paso_ondas(delta)
		"chispas":
			_paso_chispas(delta)
		"bola":
			_paso_bola(delta)
		"grieta":
			_paso_grieta()
		"pisadas":
			_paso_pisadas()
		"limo":
			_paso_limo()
	var d: float = duracion()
	if d > 0.0 and _t >= d:
		queue_free()


# ------------------------------------------------------------------ piezas comunes ------------------------------------------------------------------

static var _texturas: Dictionary = {}


## Textura de partícula blanca con alfa: "hex" (bocanada hexagonal, el sello de la demo), "circulo" o "estrella" (cuatro puntas, para los destellos).
static func textura(forma: String) -> Texture2D:
	if _texturas.has(forma):
		return _texturas[forma]
	var n: int = 64
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c: float = (n - 1) * 0.5
	for y in n:
		for x in n:
			var px: float = absf((x - c) / c)
			var py: float = absf((y - c) / c)
			var a: float = 0.0
			match forma:
				"hex":
					var d: float = maxf(px * 0.866025 + py * 0.5, py)
					a = (1.0 - smoothstep(0.80, 0.86, d)) * (0.78 + 0.22 * (1.0 - d))
				"estrella":
					var d2: float = pow(sqrt(px) + sqrt(py), 2.0)
					var r: float = sqrt(px * px + py * py)
					a = clampf(pow(clampf(1.0 - d2, 0.0, 1.0), 1.3) + 0.6 * exp(-r * r * 30.0), 0.0, 1.0)
				_:
					var r2: float = sqrt(px * px + py * py)
					a = 1.0 - smoothstep(0.7, 0.95, r2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_texturas[forma] = t
	return t


static func _rampa(cols: Array, pos: Array = []) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	var off: PackedFloat32Array = PackedFloat32Array()
	for i in cols.size():
		off.append(float(pos[i]) if pos.size() == cols.size() else float(i) / float(maxi(cols.size() - 1, 1)))
	g.offsets = off
	g.colors = PackedColorArray(cols)
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	t.width = 64
	return t


static func _curva(puntos: Array) -> CurveTexture:
	var cu: Curve = Curve.new()
	cu.max_value = 3.0
	for q in puntos:
		cu.add_point(q)
	var t: CurveTexture = CurveTexture.new()
	t.curve = cu
	return t


static func _mat_part(tex: Texture2D, aditivo: bool, prioridad: int) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true                  # los colores de las rampas están en sRGB, como los de la paleta: sin esto salen lavados
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.render_priority = prioridad
	return m


## Un GPUParticles3D listo. `c`: radio / caja / anillo (forma de salida), dir, abanico (grados), vel (min, max), radial (min, max), gravedad, frenado (min, max),
## escala (min, max), curva (puntos de tamaño a lo largo de la vida), colores (de nacer a morir; admite HDR), pos (dónde cae cada color, 0..1; si no, repartidos), aditivo, un_disparo, explosion (0..1), local, azar_vida, giro_vel, prioridad.
static func particulas(nombre: String, cantidad: int, vida: float, tex: Texture2D, tam: float, c: Dictionary) -> GPUParticles3D:
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	if c.has("anillo"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_radius = float(c["anillo"])
		pm.emission_ring_inner_radius = float(c["anillo"]) * 0.9
		pm.emission_ring_height = 0.0
		pm.emission_ring_axis = c.get("eje_anillo", Vector3(0, 0, 1))
	elif c.has("caja"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = c["caja"]
	elif float(c.get("radio", 0.0)) > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(c["radio"])
	pm.direction = c.get("dir", Vector3.UP)
	pm.spread = float(c.get("abanico", 180.0))
	var v: Vector2 = c.get("vel", Vector2.ZERO)
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	var rv: Vector2 = c.get("radial", Vector2.ZERO)
	pm.radial_velocity_min = rv.x
	pm.radial_velocity_max = rv.y
	pm.gravity = c.get("gravedad", Vector3.ZERO)
	var fr: Vector2 = c.get("frenado", Vector2.ZERO)
	pm.damping_min = fr.x
	pm.damping_max = fr.y
	var es: Vector2 = c.get("escala", Vector2.ONE)
	pm.scale_min = es.x
	pm.scale_max = es.y
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var gv: float = float(c.get("giro_vel", 0.0))
	pm.angular_velocity_min = -gv
	pm.angular_velocity_max = gv
	pm.lifetime_randomness = float(c.get("azar_vida", 0.3))
	pm.scale_curve = _curva(c.get("curva", [Vector2(0.0, 0.6), Vector2(0.2, 1.0), Vector2(1.0, 0.2)]))
	pm.color_ramp = _rampa(c["colores"], c.get("pos", []))
	var g: GPUParticles3D = GPUParticles3D.new()
	g.name = nombre
	g.amount = maxi(cantidad, 1)
	g.lifetime = vida
	g.one_shot = bool(c.get("un_disparo", false))
	g.explosiveness = float(c.get("explosion", 0.0))
	g.local_coords = bool(c.get("local", true))
	g.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = _mat_part(tex, bool(c.get("aditivo", false)), int(c.get("prioridad", 0)))
	g.draw_pass_1 = q
	g.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.emitting = true
	return g


static func _con_alfa(c: Color, a: float, brillo: float = 1.0) -> Color:
	return Color(c.r * brillo, c.g * brillo, c.b * brillo, a)


func _poner_luz(color: Color, energia: float, alcance: float, alto: float) -> void:
	if energia <= 0.0:
		return
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = color
	_luz.light_energy = energia
	_luz.omni_range = alcance
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, alto, 0)
	_luz_base = energia
	add_child(_luz)


# ------------------------------------------------------------------ LLAMA DE VENENO (chamán goblin) ------------------------------------------------------------------

## La llama de veneno: bocanadas hexagonales verdes que suben, un núcleo claro y motas que flotan. `en_vuelo` = true: las bocanadas se quedan en el mundo (estela) al moverse,
## para el proyectil. Se sostiene hasta que la quiten.
## `k`: escala de todo (1 = la de la galería; el chamán del juego mide 0,85 u y usa VENENO_K_BASTON / VENENO_K_FLECHA). `vida_llama`: s de cada bocanada (en vuelo, corta: si no,
## la estela de una flecha a 9 u/s mediría metros).
static func crear_veneno_chaman(en_vuelo: bool = false, k: float = 1.0, vida_llama: float = 0.9) -> Node3D:
	var e: Node3D = _nuevo("veneno", "VenenoChaman")
	var col: Dictionary = colores("veneno")
	var sube: float = VENENO_ALTO_LLAMA * k / 0.9
	e.add_child(particulas("Llama", VENENO_BOCANADAS, vida_llama, textura("hex"), VENENO_TAM_BOCANADA * k, {
		"radio": 0.07 * k, "dir": Vector3.UP, "abanico": 14.0, "vel": Vector2(0.45, 0.8) * sube, "gravedad": Vector3(0, 0.5 * k, 0), "frenado": Vector2(0.4, 0.8),
		"escala": Vector2(0.7, 1.1), "curva": [Vector2(0.0, 0.45), Vector2(0.22, 1.0), Vector2(1.0, 0.12)], "local": not en_vuelo,
		"colores": [_con_alfa(col["caliente"], 0.9, 1.15), _con_alfa(col["brillo"], 0.8, 1.1), _con_alfa(NubeVenenoVfx.VERDE, 0.65, 1.0), _con_alfa(col["humo"], 0.0)]}))
	e.add_child(particulas("Nucleo", 10, minf(0.45, vida_llama), textura("hex"), VENENO_TAM_BOCANADA * 0.6 * k, {
		"radio": 0.04 * k, "dir": Vector3.UP, "abanico": 10.0, "vel": Vector2(0.3, 0.5) * k, "escala": Vector2(0.8, 1.0), "local": not en_vuelo, "aditivo": true, "prioridad": 1,
		"curva": [Vector2(0.0, 0.7), Vector2(0.3, 1.0), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(col["brillo"], 0.8, 1.3), _con_alfa(NubeVenenoVfx.VERDE, 0.5, 1.2), _con_alfa(NubeVenenoVfx.VERDE, 0.0)]}))
	e.add_child(particulas("Motas", VENENO_MOTAS, 1.8 * minf(1.0, vida_llama / 0.9 + 0.3), textura("circulo"), 0.045 * maxf(k, 0.6), {
		"radio": 0.45 * k, "dir": Vector3.UP, "abanico": 60.0, "vel": Vector2(0.08, 0.3) * k, "gravedad": Vector3(0, 0.12 * k, 0), "aditivo": true, "local": not en_vuelo, "azar_vida": 0.5,
		"curva": [Vector2(0.0, 0.0), Vector2(0.2, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(col["brillo"], 0.0, 2.2), _con_alfa(col["brillo"], 1.0, 2.2), _con_alfa(NubeVenenoVfx.VERDE, 0.0, 1.5)]}))
	e.call("_poner_luz", col["luz"], VENENO_LUZ * k, 2.2 * maxf(k, 0.5), 0.25 * k)
	return e


## Deja de soltar partículas y se libera cuando se acaba la última (las que ya están en el aire terminan su vida: no corta en seco). La luz se apaga en 0,2 s.
func apagar() -> void:
	var vida_max: float = 0.0
	for h in get_children():
		if h is GPUParticles3D:
			(h as GPUParticles3D).emitting = false
			vida_max = maxf(vida_max, (h as GPUParticles3D).lifetime)
	if _luz != null:
		create_tween().tween_property(_luz, "light_energy", 0.0, 0.2)
		_luz = null                                  # que el parpadeo de _process no la vuelva a encender
	p["duracion"] = _t + vida_max + 0.1


# ------------------------------------------------------------------ HUMO TÓXICO (ambiente) ------------------------------------------------------------------

## Humo tóxico que sale del suelo y se deshace al subir. `morado` = true: los tonos de la demo; si no, el verde del veneno del juego. Se sostiene hasta que lo quiten.
static func crear_humo_toxico(morado: bool = false) -> Node3D:
	var e: Node3D = _nuevo("humo", "HumoToxico")
	var c0: Color = HUMO_MORADO[0] if morado else NubeVenenoVfx.VERDE_CLARO
	var c1: Color = HUMO_MORADO[1] if morado else NubeVenenoVfx.VERDE
	var c2: Color = HUMO_MORADO[2] if morado else NubeVenenoVfx.VERDE_OSCURO
	e.add_child(particulas("Humo", HUMO_BOCANADAS, HUMO_VIDA, textura("hex"), HUMO_TAM, {
		"caja": Vector3(0.35, 0.05, 0.35), "dir": Vector3.UP, "abanico": 25.0, "vel": Vector2(0.12, 0.3), "gravedad": Vector3(0, 0.06, 0), "frenado": Vector2(0.05, 0.1),
		"escala": Vector2(0.7, 1.1), "giro_vel": 20.0, "azar_vida": 0.35, "curva": [Vector2(0.0, 0.35), Vector2(0.3, 1.0), Vector2(1.0, 1.35)],
		"colores": [_con_alfa(c0, 0.0), _con_alfa(c0, 0.55), _con_alfa(c1, 0.45), _con_alfa(c2, 0.0)]}))
	e.add_child(particulas("Burbujas", 8, 2.2, textura("circulo"), 0.06, {
		"caja": Vector3(0.3, 0.02, 0.3), "dir": Vector3.UP, "abanico": 15.0, "vel": Vector2(0.2, 0.45), "aditivo": true, "azar_vida": 0.5,
		"curva": [Vector2(0.0, 0.0), Vector2(0.15, 1.0), Vector2(1.0, 0.6)],
		"colores": [_con_alfa(c0, 0.0, 1.6), _con_alfa(c0, 0.8, 1.6), _con_alfa(c1, 0.0)]}))
	return e


# ------------------------------------------------------------------ EXPLOSIONES ------------------------------------------------------------------

## Explosión de un disparo: destello, núcleo de humo hexagonal que se abre y trozos que salen despedidos y caen. `elemento`: "fuego", "agua", "tierra" o "rayo" (la eléctrica, con arcos).
## Se libera sola a los EXPLOSION_DURACION s.
static func crear_explosion(el: String = "fuego") -> Node3D:
	var e: Node3D = _nuevo("explosion", "Explosion_" + el)
	e.set("elemento", el)
	e.set("p", {"duracion": EXPLOSION_DURACION})
	var col: Dictionary = colores(el)
	var aditivo: bool = bool(col["aditivo"])
	if float(col["destello"]) > 0.0:
		e.add_child(particulas("Destello", 3, 0.2, textura("hex"), 0.75, {
			"radio": 0.05, "vel": Vector2.ZERO, "un_disparo": true, "explosion": 1.0, "aditivo": true, "prioridad": 2, "azar_vida": 0.2,
			"curva": [Vector2(0.0, 0.6), Vector2(0.3, 1.0), Vector2(1.0, 1.1)],
			"colores": [_con_alfa(col["chispa"], 1.0, float(col["destello"])), _con_alfa(col["brillo"], 0.0)]}))
	var humo: Color = col["humo"]
	e.add_child(particulas("Humo", EXPLOSION_HUMO, 1.15, textura("hex"), EXPLOSION_TAM_HUMO, {
		"radio": 0.2, "vel": Vector2(0.6, 1.5), "frenado": Vector2(1.8, 2.6), "gravedad": Vector3(0, 0.5, 0), "un_disparo": true, "explosion": 0.95,
		"escala": Vector2(0.75, 1.2), "giro_vel": 40.0, "curva": [Vector2(0.0, 0.4), Vector2(0.15, 1.0), Vector2(1.0, 1.25)],
		"pos": [0.0, 0.14, 0.6, 1.0],               # el color caliente dura poco: enseguida es humo (núcleo oscuro, como en la demo)
		"colores": [_con_alfa(col["chispa"], 0.95, 1.3 if aditivo else 1.0), _con_alfa(humo, 0.92), _con_alfa(humo, 0.75), _con_alfa(col["humo_viejo"], 0.0)]}))
	e.add_child(particulas("Trozos", EXPLOSION_TROZOS, 0.85, textura("hex"), 0.13, {
		"radio": 0.12, "dir": Vector3.UP, "abanico": 75.0, "vel": EXPLOSION_VEL_TROZOS, "gravedad": Vector3(0, -9.8, 0), "un_disparo": true, "explosion": 1.0,
		"escala": Vector2(0.6, 1.3), "aditivo": aditivo, "prioridad": 1, "local": false, "curva": [Vector2(0.0, 1.0), Vector2(0.7, 0.8), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(col["chispa"], 1.0, 1.7 if aditivo else 1.0), _con_alfa(col["chispa"], 1.0, 1.4 if aditivo else 0.85), _con_alfa(col["brillo"], 0.0)]}))
	if el == "agua":                               # el agua no humea: espuma clara que se abre en corona
		e.add_child(particulas("Espuma", 12, 0.7, textura("hex"), 0.22, {
			"anillo": 0.25, "eje_anillo": Vector3.UP, "radial": Vector2(1.2, 2.0), "dir": Vector3.UP, "abanico": 20.0, "vel": Vector2(0.6, 1.2), "gravedad": Vector3(0, -3.0, 0),
			"un_disparo": true, "explosion": 1.0, "curva": [Vector2(0.0, 0.5), Vector2(0.3, 1.0), Vector2(1.0, 0.3)],
			"colores": [_con_alfa(AguaPaleta.ESPUMA, 0.95), _con_alfa(AguaPaleta.CAUSTICAS, 0.7), _con_alfa(AguaPaleta.SOMERO, 0.0)]}))
	if el == "tierra":                             # la tierra deja la grieta en el suelo
		var g: Node3D = crear_grieta("tierra", 1.3)
		g.set("p", {"duracion": EXPLOSION_DURACION, "borrar_desde": EXPLOSION_DURACION - 0.5})
		e.add_child(g)
	if el == "rayo":
		e.set("_trazos", RayoTrazos.crear_trazos("Arcos", 64))
		e.add_child(e.get("_trazos"))
	e.call("_poner_luz", col["luz"], float(col["luz_fuerza"]), 4.0, 0.4)
	return e


func _paso_explosion() -> void:
	if _luz != null:
		_luz.light_energy = _luz_base * clampf(1.0 - _t / 0.45, 0.0, 1.0)
	if _trazos == null:
		return
	# eléctrica: arcos del centro hacia fuera durante 0,35 s, redibujados a saltos
	const VIDA_ARCOS: float = 0.35
	_reloj_arcos -= get_process_delta_time()
	if _reloj_arcos > 0.0 and _t < VIDA_ARCOS:
		return
	_reloj_arcos = REFRESCO_ARCOS * 0.7
	var lista: Array = []
	if _t < VIDA_ARCOS:
		var alfa: float = 1.0 - _t / VIDA_ARCOS
		for i in 6:
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1, 1)).normalized()
			var fin: Vector3 = d * _rng.randf_range(0.5, 1.1) * (0.6 + 0.6 * _t / VIDA_ARCOS)
			var pts: PackedVector3Array = RayoTrazos.camino(Vector3(0, 0.1, 0), fin + Vector3(0, 0.1, 0), 6, 0.12, _rng)
			RayoTrazos.trazar(lista, pts, 0.035, alfa, 1.0, 1.0, 0.5, float(i))
			RayoTrazos.ramas(lista, pts, 1, 0.18, 0.02, alfa * 0.8, 1.0, _rng)
	RayoTrazos.volcar(_trazos.multimesh, lista)


# ------------------------------------------------------------------ RAYO: ondas, chispas y bola ------------------------------------------------------------------

## Banda de ondas eléctricas a lo largo del eje X local (ONDAS_LARGO m), con el trazo del rayo del juego. Se sostiene.
static func crear_ondas_electricas(largo: float = ONDAS_LARGO) -> Node3D:
	var e: Node3D = _nuevo("ondas", "OndasElectricas")
	e.set("p", {"largo": largo})
	e.set("_trazos", RayoTrazos.crear_trazos("Ondas", ONDAS_HEBRAS * 48))
	e.add_child(e.get("_trazos"))
	return e


func _paso_ondas(delta: float) -> void:
	_reloj_arcos -= delta
	if _reloj_arcos > 0.0:
		return
	_reloj_arcos = REFRESCO_ARCOS * 0.8
	var largo: float = float(p.get("largo", ONDAS_LARGO))
	var lista: Array = []
	var n: int = 40
	for h in ONDAS_HEBRAS:
		var k: float = 5.0 + 2.3 * float(h)
		var w: float = 7.0 + 3.0 * float(h)
		var amp: float = ONDAS_AMPLITUD * (1.0 - 0.22 * float(h))
		var pts: PackedVector3Array = PackedVector3Array()
		for i in n + 1:
			var u: float = float(i) / float(n)
			var x: float = (u - 0.5) * largo
			var env: float = pow(sin(PI * u), 0.5)
			var y: float = amp * env * sin(k * x - w * _t + float(h) * 2.1) + _rng.randf_range(-0.018, 0.018)
			var z: float = amp * 0.5 * env * cos(k * 0.7 * x + w * 0.6 * _t + float(h))
			pts.append(Vector3(x, y, z))
		RayoTrazos.trazar(lista, pts, 0.04 if h == 0 else 0.028, 0.95 if h == 0 else 0.75, 1.0, 0.8, 0.5, float(h) * 1.3)
	RayoTrazos.volcar(_trazos.multimesh, lista)


## Chispas eléctricas: saltitos cortos de rayo que aparecen al azar en una esfera de CHISPAS_RADIO m. Se sostiene.
static func crear_chispas_electricas(radio: float = CHISPAS_RADIO) -> Node3D:
	var e: Node3D = _nuevo("chispas", "ChispasElectricas")
	e.set("p", {"radio": radio})
	e.set("_trazos", RayoTrazos.crear_trazos("Chispas", 64))
	e.add_child(e.get("_trazos"))
	e.set("_destellos", RayoTrazos.crear_destellos("Destellos", 12))
	e.add_child(e.get("_destellos"))
	return e


func _paso_chispas(delta: float) -> void:
	var radio: float = float(p.get("radio", CHISPAS_RADIO))
	_proxima_chispa -= delta
	while _proxima_chispa <= 0.0:
		_proxima_chispa += _rng.randf_range(0.02, 0.07)
		var c: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).limit_length(1.0) * radio
		var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var pts: PackedVector3Array = RayoTrazos.camino(c, c + d * _rng.randf_range(0.15, 0.35), 4, 0.06, _rng)
		_chispas.append({"pts": pts, "t": 0.0, "vida": _rng.randf_range(0.08, 0.18), "fase": _rng.randf() * 6.0})
	var lista: Array = []
	var vivas: Array = []
	var di: int = 0
	for ch in _chispas:
		ch["t"] = float(ch["t"]) + delta
		if float(ch["t"]) >= float(ch["vida"]):
			continue
		vivas.append(ch)
		var alfa: float = 1.0 - float(ch["t"]) / float(ch["vida"])
		RayoTrazos.trazar(lista, ch["pts"], 0.03, alfa, 1.0, 0.8, 0.6, float(ch["fase"]))
		if di < _destellos.multimesh.instance_count:
			RayoTrazos.poner_destello(_destellos.multimesh, di, (ch["pts"] as PackedVector3Array)[0], 0.16, alfa, 0.9, float(ch["fase"]))
			di += 1
	_chispas = vivas
	for i in range(di, _destellos.multimesh.instance_count):
		RayoTrazos.ocultar(_destellos.multimesh, i)
	RayoTrazos.volcar(_trazos.multimesh, lista)


## Bola de rayo: núcleo (la esfera del rayo del juego, pequeña) y arcos que saltan del centro a la superficie y por la superficie. Se sostiene.
static func crear_bola_rayo(radio: float = BOLA_RADIO) -> Node3D:
	var e: Node3D = _nuevo("bola", "BolaRayo")
	e.set("p", {"radio": radio})
	var nucleo: MeshInstance3D = RayoTrazos.crear_esfera("Nucleo")
	nucleo.scale = Vector3.ONE * radio * 0.24
	e.add_child(nucleo)
	e.set("_trazos", RayoTrazos.crear_trazos("Arcos", 96))
	e.add_child(e.get("_trazos"))
	e.set("_destellos", RayoTrazos.crear_destellos("Destellos", BOLA_ARCOS))
	e.add_child(e.get("_destellos"))
	e.call("_poner_luz", RayoPaleta.LUZ, 1.6, 2.5, 0.0)
	return e


func _paso_bola(delta: float) -> void:
	if _luz != null:
		_luz.light_energy = _luz_base * _rng.randf_range(0.6, 1.0)
	_reloj_arcos -= delta
	if _reloj_arcos > 0.0:
		return
	_reloj_arcos = REFRESCO_ARCOS
	var r: float = float(p.get("radio", BOLA_RADIO))
	var lista: Array = []
	for i in BOLA_ARCOS:
		var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var fin: Vector3 = d * r * _rng.randf_range(0.85, 1.05)
		RayoTrazos.trazar(lista, RayoTrazos.camino(d * r * 0.12, fin, 5, r * 0.18, _rng), 0.045, 0.95, 1.0, 1.0, 0.5, float(i))
		RayoTrazos.poner_destello(_destellos.multimesh, i, fin, 0.14, 0.9, 0.9, _rng.randf() * TAU)
	for j in 4:                                     # arcos por la piel de la bola
		var a: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var b: Vector3 = (a + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * 0.9).normalized()
		var pts: PackedVector3Array = RayoTrazos.camino(a * r, b * r, 6, r * 0.1, _rng)
		for k in pts.size():
			pts[k] = pts[k].normalized() * r * _rng.randf_range(0.95, 1.08)
		RayoTrazos.trazar(lista, pts, 0.03, 0.8, 1.0, 0.6, 0.6, float(j) * 2.0)
	RayoTrazos.volcar(_trazos.multimesh, lista)


# ------------------------------------------------------------------ DESTELLOS Y PORTAL ------------------------------------------------------------------

## Destellos de estrella que parpadean (botín, cofre, recogida). `el`: el color del elemento ("fuego" por defecto: rojos y naranjas). Se sostiene.
static func crear_destellos(el: String = "fuego", radio: float = 0.5) -> Node3D:
	var e: Node3D = _nuevo("destellos", "Destellos_" + el)
	var col: Dictionary = colores(el)
	e.add_child(particulas("Estrellas", 16, 0.9, textura("estrella"), 0.24, {
		"radio": radio, "dir": Vector3.UP, "abanico": 40.0, "vel": Vector2(0.05, 0.2), "aditivo": true, "azar_vida": 0.5, "escala": Vector2(0.6, 1.3), "giro_vel": 90.0,
		"curva": [Vector2(0.0, 0.0), Vector2(0.35, 1.0), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(col["chispa"], 1.0, 2.0), _con_alfa(col["brillo"], 1.0, 1.8), _con_alfa(col["brillo"], 0.0)]}))
	e.add_child(particulas("Puntos", 10, 1.2, textura("circulo"), 0.04, {
		"radio": radio, "dir": Vector3.UP, "abanico": 30.0, "vel": Vector2(0.05, 0.15), "aditivo": true, "azar_vida": 0.5,
		"curva": [Vector2(0.0, 0.0), Vector2(0.3, 1.0), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(col["brillo"], 1.0, 2.0), _con_alfa(col["brillo"], 0.0)]}))
	return e


## Portal vertical (mira hacia +Z local) de `radio` m: disco de espirales (bloque_portal.gdshader) y motas que caen hacia el centro. `el`: "fuego" o "agua". Se sostiene.
static func crear_portal(el: String = "fuego", radio: float = 0.75) -> Node3D:
	var e: Node3D = _nuevo("portal", "Portal_" + el)
	var col: Dictionary = colores(el)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(radio * 2.0, radio * 2.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Disco"
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_PORTAL)
	m.set_shader_parameter("color_borde", col["caliente"] if el != "fuego" else Color(1.0, 0.4, 0.1))      # fuego: naranja, no amarillo
	m.set_shader_parameter("color_dentro", col["brillo"] if el != "agua" else AguaPaleta.SOMERO)
	m.set_shader_parameter("fuerza", 1.2 if el == "fuego" else 1.1)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, radio + 0.05, 0)
	e.add_child(mi)
	var motas: GPUParticles3D = particulas("Motas", 22, 1.1, textura("hex"), 0.07, {
		"anillo": radio * 0.95, "eje_anillo": Vector3(0, 0, 1), "radial": Vector2(-0.9, -0.5), "vel": Vector2.ZERO, "aditivo": bool(col["aditivo"]), "prioridad": 1,
		"curva": [Vector2(0.0, 0.0), Vector2(0.2, 1.0), Vector2(1.0, 0.2)],
		"colores": [_con_alfa(col["chispa"], 1.0, 1.5), _con_alfa(col["brillo"], 0.0)]})
	motas.position = mi.position
	e.add_child(motas)
	e.call("_poner_luz", col["luz"], float(col["luz_fuerza"]) * 0.4, 2.5, radio)
	return e


# ------------------------------------------------------------------ DECALS: grietas, pisadas y limo ------------------------------------------------------------------

## Grieta en el suelo (se pega al relieve). `estilo`: "tierra", "magma", "rayo" o "veneno" (estilos_grieta()). Nace en 0,15 s y se queda; con p["duracion"] se borra al final.
static func crear_grieta(estilo: String = "tierra", tam: float = GRIETA_TAM, semilla: int = -1) -> Node3D:
	var e: Node3D = _nuevo("grieta", "Grieta_" + estilo)
	var s: Dictionary = estilos_grieta().get(estilo, estilos_grieta()["tierra"])
	var sem: int = semilla if semilla >= 0 else randi() % 8
	var d: MeshInstance3D = TierraToy.crear_decal_suelo("Decal", tam, tam, DECAL_ALTO, {"mascara": mascara(String(s["forma"]), sem), "color": s["color"],
		"color_emision": s["emision_color"], "emision": float(s["emision"]), "vida": 1.0, "fuerza": 1.0}, Vector3.ZERO, -3)
	d.rotation.y = randf() * TAU
	e.add_child(d)
	e.set("_decal", d)
	return e


func _paso_grieta() -> void:
	if _decal == null:
		return
	var m: ShaderMaterial = _decal.material_override as ShaderMaterial
	var nace: float = clampf(_t / 0.15, 0.0, 1.0)
	var vida: float = nace
	var desde: float = float(p.get("borrar_desde", -1.0))
	var dur: float = duracion()
	if desde >= 0.0 and dur > desde:
		vida *= 1.0 - clampf((_t - desde) / (dur - desde), 0.0, 1.0)
	m.set_shader_parameter("vida", vida)
	m.set_shader_parameter("fuerza", 0.6 + 0.4 * nace)


## Pisadas de barro que van apareciendo (alternando pie) a lo largo de +Z local y se borran solas. `bucle`: vuelve a empezar cuando se borra la última.
static func crear_pisadas(n: int = 10, bucle: bool = true) -> Node3D:
	var e: Node3D = _nuevo("pisadas", "Pisadas")
	e.set("p", {"n": n, "bucle": bucle})
	return e


func _paso_pisadas() -> void:
	var n: int = int(p.get("n", 10))
	var hechas: int = _pisadas.size()
	var t_ciclo: float = _t
	if hechas < n and t_ciclo >= float(hechas) * PISADA_CADENCIA:
		var lado: float = -1.0 if hechas % 2 == 0 else 1.0
		var z: float = (float(hechas) - float(n) * 0.5) * PISADA_PASO
		var d: MeshInstance3D = TierraToy.crear_decal_suelo("Pisada%d" % hechas, 0.15, 0.3, DECAL_ALTO * 0.5, {"mascara": mascara("pisada", 0), "color": PISADA_COLOR,
			"color_emision": Color.BLACK, "emision": 0.0, "vida": 1.0, "fuerza": 1.0}, Vector3(lado * 0.075, 0, z), -3)
		d.rotation.y = lado * 0.08
		add_child(d)
		_pisadas.append({"nodo": d, "t0": _t})
	for ps in _pisadas:
		var nd: MeshInstance3D = ps["nodo"]
		if not is_instance_valid(nd):
			continue
		var edad: float = _t - float(ps["t0"])
		var v: float = clampf(edad / 0.08, 0.0, 1.0) * (1.0 - clampf((edad - (PISADA_VIDA - 0.8)) / 0.8, 0.0, 1.0))
		(nd.material_override as ShaderMaterial).set_shader_parameter("vida", v)
	if bool(p.get("bucle", true)) and hechas >= n and _t >= float(n - 1) * PISADA_CADENCIA + PISADA_VIDA:
		for ps2 in _pisadas:
			(ps2["nodo"] as Node).queue_free()
		_pisadas.clear()
		_t = 0.0


## Salpicadura de limo: gotas que saltan y caen, y la mancha en el suelo que se abre y, con p["duracion"], se borra. `el`: color del limo ("veneno", "agua", "fuego", "tierra").
static func crear_salpicadura_limo(el: String = "veneno", tam: float = 1.1) -> Node3D:
	var e: Node3D = _nuevo("limo", "Limo_" + el)
	e.set("elemento", el)
	var col: Dictionary = colores(el)
	var base: Color = col["humo"] if el != "agua" else AguaPaleta.HONDO
	var claro: Color = col["brillo"]
	var d: MeshInstance3D = TierraToy.crear_decal_suelo("Mancha", tam, tam, DECAL_ALTO, {"mascara": mascara("limo", randi() % 8), "color": base,
		"color_emision": claro, "emision": 0.35, "vida": 1.0, "fuerza": 1.0}, Vector3.ZERO, -3)
	d.rotation.y = randf() * TAU
	d.scale = Vector3(0.01, d.scale.y, 0.01)
	e.add_child(d)
	e.set("_decal", d)
	e.set("p", {"tam": tam, "duracion": 3.0, "borrar_desde": 2.2})
	e.add_child(particulas("Gotas", 16, 0.75, textura("circulo"), 0.13, {
		"radio": 0.08, "dir": Vector3.UP, "abanico": 65.0, "vel": Vector2(1.4, 3.0), "gravedad": Vector3(0, -9.8, 0), "un_disparo": true, "explosion": 1.0, "local": false,
		"escala": Vector2(0.6, 1.4), "curva": [Vector2(0.0, 1.0), Vector2(0.8, 0.9), Vector2(1.0, 0.0)],
		"colores": [_con_alfa(claro, 1.0), _con_alfa(base.lerp(claro, 0.5), 1.0), _con_alfa(base, 0.9)]}))
	return e


func _paso_limo() -> void:
	if _decal == null:
		return
	var tam: float = float(p.get("tam", 1.0))
	var k: float = 1.0 - pow(1.0 - clampf(_t / 0.18, 0.0, 1.0), 3.0)
	_decal.scale = Vector3(tam * maxf(k, 0.01), _decal.scale.y, tam * maxf(k, 0.01))
	var desde: float = float(p.get("borrar_desde", 2.2))
	var v: float = 1.0 - clampf((_t - desde) / maxf(duracion() - desde, 0.01), 0.0, 1.0)
	(_decal.material_override as ShaderMaterial).set_shader_parameter("vida", v)


# ------------------------------------------------------------------ máscaras generadas (negro opaco = marca; decal_suelo lee alfa × (1 − rojo)) ------------------------------------------------------------------

static var _mascaras: Dictionary = {}


## Máscara de decal: "impacto" (rayos desde el centro y anillo roto), "seca" (tierra cuarteada, celdas), "rama" (grieta larga con ramas), "pisada" o "limo". `semilla` cambia la forma.
static func mascara(forma: String, semilla: int) -> Texture2D:
	var clave: String = "%s_%d" % [forma, semilla]
	if _mascaras.has(clave):
		return _mascaras[clave]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(clave)
	var img: Image
	match forma:
		"seca":
			img = _mascara_seca(rng)
		"rama":
			img = _mascara_rama(rng)
		"pisada":
			img = _mascara_pisada()
		"limo":
			img = _mascara_limo(rng)
		_:
			img = _mascara_impacto(rng)
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_mascaras[clave] = t
	return t


static func _lienzo(w: int, h: int) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Pinta un disco negro de radio `r` px (borde suave); no baja el alfa de lo ya pintado.
static func _disco(img: Image, cx: float, cy: float, r: float) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(maxi(int(cy - r - 1.0), 0), mini(int(cy + r + 2.0), h)):
		for x in range(maxi(int(cx - r - 1.0), 0), mini(int(cx + r + 2.0), w)):
			var a: float = clampf(r + 0.5 - Vector2(x - cx, y - cy).length(), 0.0, 1.0)
			if a > img.get_pixel(x, y).a:
				img.set_pixel(x, y, Color(0, 0, 0, a))


static func _trazo(img: Image, a: Vector2, b: Vector2, r0: float, r1: float) -> void:
	var n: int = maxi(int(ceil(a.distance_to(b))), 1)
	for i in n + 1:
		var u: float = float(i) / float(n)
		var q: Vector2 = a.lerp(b, u)
		_disco(img, q.x, q.y, lerpf(r0, r1, u))


## Camino quebrado desde `desde` con rumbo `ang`: `n` tramos de `largo` px, grosor de `r0` a `r1`. Devuelve los puntos.
static func _grieta_camino(img: Image, desde: Vector2, ang: float, n: int, largo: float, r0: float, r1: float, rng: RandomNumberGenerator, quiebro: float = 0.38) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([desde])
	var q: Vector2 = desde
	var a: float = ang
	for i in n:
		a += rng.randf_range(-quiebro, quiebro)
		var sig: Vector2 = q + Vector2(cos(a), sin(a)) * largo * rng.randf_range(0.7, 1.2)
		_trazo(img, q, sig, lerpf(r0, r1, float(i) / float(n)), lerpf(r0, r1, float(i + 1) / float(n)))
		pts.append(sig)
		q = sig
	return pts


static func _mascara_impacto(rng: RandomNumberGenerator) -> Image:
	var s: int = 256
	var img: Image = _lienzo(s, s)
	var c: Vector2 = Vector2(s, s) * 0.5
	var k: int = rng.randi_range(6, 8)
	var anillo1: Array = []
	var anillo2: Array = []
	for i in k:
		var ang: float = TAU * float(i) / float(k) + rng.randf_range(-0.25, 0.25)
		var pts: PackedVector2Array = _grieta_camino(img, c + Vector2(cos(ang), sin(ang)) * 6.0, ang, 6, s * 0.075, 5.0, 1.3, rng)
		anillo1.append(pts[2])
		anillo2.append(pts[4])
		for j in [2, 3, 4]:                              # ramas
			if rng.randf() < 0.55:
				var lado: float = rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				_grieta_camino(img, pts[j], ang + lado, rng.randi_range(2, 3), s * 0.05, 2.6, 0.9, rng, 0.5)
	for i in k:                                         # el anillo roto
		if rng.randf() < 0.85:
			_trazo(img, anillo1[i], anillo1[(i + 1) % k], 2.4, 2.4)
		if rng.randf() < 0.4:
			_trazo(img, anillo2[i], anillo2[(i + 1) % k], 1.6, 1.6)
	return img


static func _mascara_seca(rng: RandomNumberGenerator) -> Image:
	var s: int = 160
	var img: Image = _lienzo(s, s)
	var semillas: Array = []
	for i in 18:
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * 0.5
		semillas.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r)
	for y in s:
		for x in s:
			var u: Vector2 = Vector2((x + 0.5) / s, (y + 0.5) / s)
			var rr: float = u.distance_to(Vector2(0.5, 0.5)) * 2.0
			if rr > 1.0:
				continue
			var f1: float = 9.0
			var f2: float = 9.0
			for q in semillas:
				var d: float = u.distance_to(q)
				if d < f1:
					f2 = f1
					f1 = d
				elif d < f2:
					f2 = d
			var ancho: float = (0.03 - 0.014 * rr)
			var a: float = (1.0 - smoothstep(ancho * 0.5, ancho, f2 - f1)) * (1.0 - smoothstep(0.7, 1.0, rr))
			if a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, a))
	return img


static func _mascara_rama(rng: RandomNumberGenerator) -> Image:
	var s: int = 256
	var img: Image = _lienzo(s, s)
	var ang: float = rng.randf_range(-0.3, 0.3)
	var ini: Vector2 = Vector2(s * 0.5, s * 0.5) - Vector2(cos(ang), sin(ang)) * s * 0.42
	var pts: PackedVector2Array = PackedVector2Array([ini])
	var q: Vector2 = ini
	var a: float = ang
	var n: int = 9
	for i in n:                                         # el tronco: grueso en el centro, fino en las puntas
		a += rng.randf_range(-0.45, 0.45)
		a = lerpf(a, ang, 0.35)
		var sig: Vector2 = q + Vector2(cos(a), sin(a)) * s * 0.095
		_trazo(img, q, sig, 2.5 + 5.0 * sin(PI * float(i) / n), 2.5 + 5.0 * sin(PI * float(i + 1) / n))
		pts.append(sig)
		q = sig
	for j in range(1, n):
		if rng.randf() < 0.7:
			var lado: float = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.6, 1.2)
			var b: PackedVector2Array = _grieta_camino(img, pts[j], ang + lado, rng.randi_range(2, 3), s * 0.06, 3.6, 1.2, rng, 0.5)
			if rng.randf() < 0.4:
				_grieta_camino(img, b[1], ang + lado * 1.6, 2, s * 0.04, 2.0, 0.9, rng, 0.5)
	return img


static func _mascara_pisada() -> Image:
	var w: int = 64
	var h: int = 128
	var img: Image = _lienzo(w, h)
	for y in h:
		for x in w:
			var planta: float = Vector2((x - 31.5) / 19.0, (y - 40.0) / 33.0).length()
			var talon: float = Vector2((x - 33.0) / 15.0, (y - 102.0) / 20.0).length()
			var d: float = minf(planta, talon)
			var a: float = 1.0 - smoothstep(0.85, 1.0, d)
			if a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, a * 0.92))
	return img


static func _mascara_limo(rng: RandomNumberGenerator) -> Image:
	var s: int = 256
	var img: Image = _lienzo(s, s)
	var c: Vector2 = Vector2(s, s) * 0.5
	var f1: float = rng.randf() * TAU
	var f2: float = rng.randf() * TAU
	for y in s:
		for x in s:
			var v: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var ang: float = atan2(v.y, v.x)
			var borde: float = s * 0.26 * (1.0 + 0.16 * sin(5.0 * ang + f1) + 0.08 * sin(9.0 * ang + f2))
			var a: float = clampf(borde + 0.5 - v.length(), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, a))
	for i in 11:                                        # gotas y regueros
		var ang2: float = rng.randf() * TAU
		var dir: Vector2 = Vector2(cos(ang2), sin(ang2))
		var dist: float = s * rng.randf_range(0.31, 0.46)
		var r: float = rng.randf_range(4.0, 11.0)
		if rng.randf() < 0.45:
			_trazo(img, c + dir * s * 0.24, c + dir * dist, r * 0.9, r * 0.55)
		_disco(img, c.x + dir.x * dist, c.y + dir.y * dist, r)
	return img
