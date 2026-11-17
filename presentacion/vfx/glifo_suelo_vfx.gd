class_name GlifoSueloVfx
extends RefCounted

## ᛒ SUELO · EL DIBUJO (18/11/2026). Solo representa: la lógica (qué se pisa, qué ralentiza, qué explota) es de `GlifoSuelo` y del juego; aquí no se decide nada.
##   · SÍMBOLO de la trampa: un aro y la runa ᛒ tumbados en el suelo, discretos mientras esperan (poco alpha, el color del elemento oscurecido). `iluminar` los enciende con el COLOR DEL ELEMENTO
##     (mezcla aditiva, un destello de luz, crecen y se apagan).
##   · EXPLOSIÓN: la de ÁREA de cada elemento, ya hecha (ExplosionFuegoToy e ImpactoXToy.Variante.AREA); la naturaleza, que aún no tiene, lleva una onda sencilla del color del elemento.
##   · CAPA sutil de escarcha o de tierra (una mancha suave con motas) y PLACA de hielo (HieloToy.Figura.SUELO, la losa ya hecha).
## Los colores son los del juego: `Combate3D.COLORES` (fuego, agua, rayo, hielo, viento, tierra) y el de la runa para magma y naturaleza (`GlifoSuelo.color_de`).

const LADO_SIMBOLO_CAS: float = 0.8            ## lado del símbolo (× casilla)
const ALPHA_ANILLO: float = 0.30               ## lo que se ve el aro mientras espera
const ALPHA_GLIFO: float = 0.38
const OSCURECE_ESPERA: float = 0.25            ## el color de espera es el del elemento algo más oscuro
const T_ILUMINA_S: float = 0.08
const T_APAGA_S: float = 0.45
const COLOR_ESCARCHA: Color = Color(0.86, 0.93, 0.99)       ## la de `HieloPaleta.ESCARCHA`
const COLOR_POLVO: Color = Color(0.55, 0.40, 0.26)          ## tierra del mundo: la de `Combate3D.COLORES["tierra"]` algo más oscura
const ALTO_CAPA_M: float = 0.03                ## cuánto sobre el suelo se tumba lo dibujado (para no pisarse con él)

static var _tex_anillo: ImageTexture = null
static var _tex_capa: Dictionary = {}


# ---------------------------------------------------------------------------------------------------------------- texturas

static func textura_anillo() -> ImageTexture:
	if _tex_anillo != null:
		return _tex_anillo
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var r: float = Vector2(float(x) + 0.5 - float(n) * 0.5, float(y) + 0.5 - float(n) * 0.5).length() / (float(n) * 0.5)
			var anillo: float = clampf(1.0 - absf(r - 0.86) / 0.07, 0.0, 1.0)
			var relleno: float = 0.10 if r < 0.80 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(anillo, relleno)))
	_tex_anillo = ImageTexture.create_from_image(img)
	return _tex_anillo


## Una mancha suave y moteada, blanca con alpha (se tiñe con el material): `hielo` lleva motas más finas y claras, la tierra, grumos.
static func textura_capa(hielo: bool) -> ImageTexture:
	if _tex_capa.has(hielo):
		return _tex_capa[hielo] as ImageTexture
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18112026 if hielo else 7112026
	var motas: PackedFloat32Array = PackedFloat32Array()
	motas.resize(n * n)
	for i in range(n * n):
		motas[i] = rng.randf()
	for y in range(n):
		for x in range(n):
			var r: float = Vector2(float(x) + 0.5 - float(n) * 0.5, float(y) + 0.5 - float(n) * 0.5).length() / (float(n) * 0.5)
			var borde: float = clampf(1.0 - r, 0.0, 1.0)
			var suave: float = smoothstep(0.0, 0.55, borde)
			var mota: float = motas[y * n + x]
			var a: float = suave * (0.55 + 0.45 * mota) if not hielo else suave * (0.35 + 0.65 * (1.0 if mota > 0.72 else mota * 0.5))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_tex_capa[hielo] = t
	return t


static func _material(tex: Texture2D, color: Color, aditivo: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = color
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func _quad(nombre: String, lado: float, mat: Material, y: float = 0.0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(lado, lado)
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------------------------------------------- la trampa

## El color con que espera el símbolo: el del elemento, más oscuro y casi transparente.
static func color_espera(color: Color, alpha: float) -> Color:
	var c: Color = color.darkened(OSCURECE_ESPERA)
	c.a = alpha
	return c


## El símbolo de la trampa tumbado en el suelo: aro + runa ᛒ, discretos. `lado_m` = lado total (m). El nodo guarda sus materiales (meta «mats») para `iluminar` y `apagar`.
static func simbolo(color: Color, lado_m: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Simbolo"
	var m_anillo: StandardMaterial3D = _material(textura_anillo(), color_espera(color, ALPHA_ANILLO))
	var m_glifo: StandardMaterial3D = _material(Sigils.GLYPHS["suelo"] as Texture2D, color_espera(color, ALPHA_GLIFO))
	raiz.add_child(_quad("Anillo", lado_m, m_anillo))
	raiz.add_child(_quad("Glifo", lado_m * 0.62, m_glifo, 0.004))
	raiz.set_meta("mats", [m_anillo, m_glifo])
	return raiz


## El símbolo SE ILUMINA con el color del elemento (mezcla aditiva, crece, un destello de luz) y se apaga; al acabar libera `raiz`.
static func iluminar(raiz: Node3D, color: Color, lado_m: float) -> void:
	if raiz == null or not is_instance_valid(raiz) or not raiz.is_inside_tree():
		return
	var mats: Array = raiz.get_meta("mats", [])
	var vivo: Color = Color(minf(color.r * 1.35, 1.0), minf(color.g * 1.35, 1.0), minf(color.b * 1.35, 1.0), 1.0)
	var tw: Tween = raiz.create_tween().set_parallel(true)
	for m in mats:
		var mat: StandardMaterial3D = m
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(vivo.r, vivo.g, vivo.b, 0.15)
		tw.tween_property(mat, "albedo_color", vivo, T_ILUMINA_S)
	tw.tween_property(raiz, "scale", Vector3(1.35, 1.0, 1.35), T_ILUMINA_S + T_APAGA_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var luz := OmniLight3D.new()
	luz.name = "Destello"
	luz.light_color = color
	luz.light_energy = 3.0
	luz.omni_range = maxf(lado_m * 2.0, 1.5)
	luz.position = Vector3(0.0, 0.5, 0.0)
	raiz.add_child(luz)
	var tl: Tween = luz.create_tween()
	tl.tween_property(luz, "light_energy", 0.0, T_ILUMINA_S + T_APAGA_S)
	var apaga: Tween = raiz.create_tween()
	apaga.tween_interval(T_ILUMINA_S)
	apaga.tween_callback(_desvanecer.bind(raiz, mats, vivo))


static func _desvanecer(raiz: Node3D, mats: Array, vivo: Color) -> void:
	if not is_instance_valid(raiz) or not raiz.is_inside_tree():
		return
	var tw: Tween = raiz.create_tween().set_parallel(true)
	for m in mats:
		var mat: StandardMaterial3D = m
		tw.tween_property(mat, "albedo_color", Color(vivo.r, vivo.g, vivo.b, 0.0), T_APAGA_S)


## Lo que se ve de algo plantado cuando se retira sin explotar (caducó, lo desalojaron): se desvanece.
static func apagar(raiz: Node3D) -> void:
	if raiz == null or not is_instance_valid(raiz) or not raiz.is_inside_tree():
		return
	var tw: Tween = raiz.create_tween().set_parallel(true)
	for m in raiz.get_meta("mats", []):
		var mat: StandardMaterial3D = m
		var c: Color = mat.albedo_color
		tw.tween_property(mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), T_APAGA_S)


# ---------------------------------------------------------------------------------------------------------------- la explosión

## La explosión SIMPLE del elemento en `pos` (sobre el suelo), de `radio_m` de radio, hija de `padre`: la de ÁREA que ya tiene su toy (agua, hielo, rayo, viento, magma, tierra, fuego); la naturaleza
## y lo que no tenga, una onda del color del elemento. Devuelve el nodo (se libera solo).
static func explosion(elemento: String, pos: Vector3, radio_m: float, color: Color, padre: Node) -> Node3D:
	if padre == null or not is_instance_valid(padre):
		return null
	var n: Node3D = null
	match elemento:
		"fuego":
			n = ExplosionFuegoToy.crear(radio_m)
		"agua":
			n = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, radio_m)
		"hielo":
			n = ImpactoHieloToy.crear(ImpactoHieloToy.Variante.AREA, Vector3.UP, radio_m)
		"rayo":
			n = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.AREA, Vector3.UP, radio_m)
		"viento":
			n = ImpactoVientoToy.crear(ImpactoVientoToy.Variante.AREA, Vector3.UP, radio_m)
		"magma":
			n = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.AREA, Vector3.UP, radio_m)
		"tierra":
			n = ImpactoTierraToy.crear(ImpactoTierraToy.Variante.AREA, Vector3.UP, radio_m)
		_:
			n = _onda(color, radio_m)
	padre.add_child(n)
	n.global_position = pos
	if n.name == "OndaSuelo":
		_abrir_onda(n, color)
	return n


## Onda sencilla: un aro del color del elemento (mezcla aditiva) que `_abrir_onda` abre de 0 a `radio_m` y apaga.
static func _onda(color: Color, radio_m: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "OndaSuelo"
	var mat: StandardMaterial3D = _material(textura_anillo(), Color(color.r, color.g, color.b, 0.9), true)
	raiz.add_child(_quad("Onda", radio_m * 2.0, mat, ALTO_CAPA_M))
	raiz.set_meta("mats", [mat])
	raiz.scale = Vector3(0.15, 1.0, 0.15)
	return raiz


static func _abrir_onda(raiz: Node3D, color: Color) -> void:
	var mat: StandardMaterial3D = (raiz.get_meta("mats") as Array)[0]
	var tw: Tween = raiz.create_tween().set_parallel(true)
	tw.tween_property(raiz, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.45)
	tw.chain().tween_callback(raiz.queue_free)


# ---------------------------------------------------------------------------------------------------------------- capas y placa

## La capa sutil: una mancha de `lado_m` m, de escarcha (`hielo`) o de polvo de tierra. Guarda su material en la meta «mats» (`apagar` la desvanece).
static func capa(hielo: bool, lado_m: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "CapaEscarcha" if hielo else "CapaTierra"
	var color: Color = COLOR_ESCARCHA if hielo else COLOR_POLVO
	color.a = 0.55 if hielo else 0.60
	var mat: StandardMaterial3D = _material(textura_capa(hielo), color)
	raiz.add_child(_quad("Mancha", lado_m, mat))
	raiz.set_meta("mats", [mat])
	return raiz


## La placa de hielo ya hecha (HieloToy.Figura.SUELO) del tamaño de una casilla; con su nacer. Se rompe con `morir()`.
static func placa_hielo(lado_m: float) -> HieloToy:
	var p := HieloToy.new()
	p.name = "PlacaHielo"
	p.definir(HieloToy.Figura.SUELO, lado_m * 0.5, 0.14, lado_m * 0.5, false)
	return p
