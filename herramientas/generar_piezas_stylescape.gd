extends SceneTree

## GENERADOR (25/11/2026) de las piezas de MURO FINO del pack «Stylescape: Ruins» (Fab) para el estilo «ruinas» de la maqueta
## (presentacion/paredes_stylescape.gd). Antes: exportar desde Unreal (tools/ue_exportar_stylescape.py), preparar (tools/preparar_stylescape.py)
## e importar en Godot. Crea, sin tocar nada del juego:
##   arte/stylescape/texturas/<textura>_beige.res   el color del pack HORNEADO al beige de nuestros muros (el «modo 3» de LabStylescape)
##   arte/stylescape/materiales/<material>.tres     StandardMaterial3D: beige + normal + oclusión (R) y rugosidad (G) del AORM del pack
##   arte/stylescape/mallas_res/<id>.res             la malla
##   arte/stylescape/piezas/ss_<nombre>.tscn         con el formato de arte/piezas: raíz con metadata, `modelo/malla` y `cuerpo` (capa 1024)
## Las piezas salen con lo LARGO a lo largo de X, centradas en planta y con la base en y = 0, a 0,575 u por metro (4 m = una casilla).
## Reejecutable: sobrescribe.   godot --headless --path . --script res://herramientas/generar_piezas_stylescape.gd

const PAREDES = preload("res://presentacion/paredes_stylescape.gd")
const MALLAS: String = "res://arte/stylescape/mallas/"
const TEX: String = "res://arte/stylescape/texturas/"
const MATERIALES: String = "res://arte/stylescape/materiales/"
const MALLAS_RES: String = "res://arte/stylescape/mallas_res/"
const ESCALA: float = 0.575
const CAPA_MUNDO: int = 1024
const ORIGEN: String = "Stylescape: Ruins (Stylescape, Fab)"

## El beige de nuestros muros (muro_ruina y muro_agrietado), calibrado en pantalla en LabStylescape (ver PIEDRA_MUROS allí), y cuánto
## claroscuro de la textura del pack sobrevive (el `detalle` del modo 3). El cálculo es el del shader del lab, en lineal.
const BEIGE: Color = Color(0.715, 0.62, 0.555)
const DETALLE: float = 0.75
## Material de Unreal -> [color, normal, AORM]
const RECETAS: Dictionary = {
	"MI_Walls": ["T_WallTrim_NoMoss_D", "T_WallTrim_NoMoss_N", "T_WallTrim_NoMoss_AORS"],
	"MI_Stones": ["T_StoneRuins_D", "T_StoneRuins_N", "T_StoneRuins_AORM"],
	"MI_Walls_Dmg": ["T_WallTrim_Dmg_D", "T_WallTrim_Dmg_N", "T_WallTrim_Dmg_AORM"],
	# 25/11 (los adornos: losas, caja, hiedra). Las losas, con la piedra de los muros (beige); la madera y la hiedra, con su color (cuarto dato = sin hornear).
	"MI_Floors": ["T_WallTrim_NoMoss_D", "T_WallTrim_NoMoss_N", "T_WallTrim_NoMoss_AORS", "losa"],
	"MI_Wall_Wood": ["T_Wood_D", "T_Wood_N", "T_Wood_AORM", "natural"],
	"MI_Ivy_Leaf": ["T_IvyLeaves_D", "", "", "hiedra"],
	"MI_Ivy_Vine_01": ["T_IvyBranch_01_D", "", "", "hiedra"],
	"MI_Ivy_Vine_02": ["T_IvyBranch_02_D", "", "", "hiedra"],
}
## Las losas del pack (MI_Floors, la misma textura que los muros): reciben la luz de arriba y salen más claras que el frente del muro; esto las iguala.
## 25/11, 2.º (Pablo: «diferencia ligeramente el color del suelo»): un poco más oscuro y más gris que el ladrillo, para que muro y suelo no se fundan.
## (Antes Color(0,9·0,86·0,8) lo igualaba al muro: 43°·0,247·0,631 contra 44°·0,224·0,627.)
const COLOR_LOSAS: Color = Color(0.84, 0.81, 0.78)
## 3.º (Pablo: «marca las juntas»): oclusión entera con luz directa y más relieve (antes 0,6 y 1,6). Con la luz de arriba eso apenas se notaba
## (las juntas de esta textura casi no tienen AO), así que además las juntas se OSCURECEN en el color (`_losa_juntas`).
const AO_LOSAS: float = 1.0
const RELIEVE_LOSAS: float = 2.4
## Cuánto oscurece el color según lo inclinada que está la normal (juntas y bordes de losa) y hasta dónde como mucho.
const JUNTAS_GANANCIA: float = 2.2
const JUNTAS_MIN: float = 0.5
## La hiedra del pack es un verde muy claro (en Unreal la oscurecía su `Ivy Tint`): se multiplica por esto para que no brille más que la hierba.
const TINTE_HIEDRA: Color = Color(0.62, 0.68, 0.55)

var _mats: Dictionary = {}


func _initialize() -> void:
	for d in [MATERIALES, MALLAS_RES, PAREDES.RUTA]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	if not ResourceLoader.exists(MALLAS + "SM_Wall_04.fbx"):
		print("FALLO  no hay mallas en %s: antes, tools/preparar_stylescape.py e importar" % MALLAS)
		quit(1)
		return
	var bien: int = 0
	for nombre in PAREDES.TODAS:
		if _pieza(String(nombre)):
			bien += 1
	print("RESULTADO piezas=%d de %d" % [bien, PAREDES.TODAS.size()])
	var losas: bool = _losas_ruinas()
	var sombra: bool = _sombra_base()
	quit(0 if bien == PAREDES.TODAS.size() and losas and sombra else 1)


## 25/11 (Pablo: «una sombra estrecha y suave pegada a la base»): la franja de sombra de contacto (presentacion/sombra_base_ruinas.gdshader), de MEDIA
## casilla de largo (un brazo de muro) y con Z local de la cara del muro (0) hacia fuera. Sin cuerpo ni sombra propia.
func _sombra_base() -> bool:
	var raiz := Node3D.new()
	var id: String = PAREDES.SOMBRA_BASE
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", false)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", false)
	raiz.set_meta("origen", "Magic Symbols")
	raiz.set_meta("categoria", "sombra")
	var plano := PlaneMesh.new()
	plano.size = Vector2(PAREDES.S * 0.5, 0.5)
	plano.center_offset = Vector3(0.0, 0.0, 0.25)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://presentacion/sombra_base_ruinas.gdshader")
	plano.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "malla"
	mi.mesh = plano
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	mi.owner = raiz
	var emp := PackedScene.new()
	emp.pack(raiz)
	var err: int = ResourceSaver.save(emp, PAREDES.RUTA + id + ".tscn")
	raiz.free()
	print("%s    %s (sombra de contacto)" % ["OK " if err == OK else "FALLO", id])
	return err == OK


## Calibrado en pantalla (25/11, docs/capturas/stylescape/trampas/2_patio_dragon.png, sin los píxeles de musgo): con el color medio tal cual el suelo
## salía 0,583·0,566·0,492 y el frente del muro 0,624·0,593·0,471 (al muro le da otra luz); se corrige con la razón de los dos, en lineal.
## 2.º ajuste (25/11, Pablo: «los colores no casan»), con el musgo del muro a 0,15: el suelo seguía más amarillo (tono 50°) que el ladrillo (42°): más rojo, menos verde.
const AJUSTE_LOSAS: Vector3 = Vector3(1.22, 1.06, 0.93)
## 25/11 (Pablo: «integra el suelo exterior con el muro, los colores de las texturas son distintos»): las losas del suelo del juego (arte/suelo_meshy/
## losas_piedra.png, gris lila) TEÑIDAS con el color medio de los muros del pack: mismo dibujo, el tono de la piedra de los muros. Cada canal se
## multiplica por (color del muro / color medio de las losas), en lineal. La usa la maqueta en el suelo de piedra con estilo «ruinas».
func _losas_ruinas() -> bool:
	var origen: String = "res://arte/suelo_meshy/losas_piedra.png"
	var im := Image.load_from_file(ProjectSettings.globalize_path(origen))
	if im == null or im.is_empty():
		print("FALLO  no está %s" % origen)
		return false
	im.convert(Image.FORMAT_RGB8)
	var media := Color(0, 0, 0)
	var chica: Image = im.duplicate()
	chica.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	for yy in range(64):
		for xx in range(64):
			media += chica.get_pixel(xx, yy).srgb_to_linear()
	media = Color(media.r / 4096.0, media.g / 4096.0, media.b / 4096.0)
	var muro: Color = PAREDES.color_piedra().srgb_to_linear()
	var k := Vector3(muro.r / maxf(media.r, 0.001), muro.g / maxf(media.g, 0.001), muro.b / maxf(media.b, 0.001)) * AJUSTE_LOSAS
	for yy in range(im.get_height()):
		for xx in range(im.get_width()):
			var p: Color = im.get_pixel(xx, yy).srgb_to_linear()
			im.set_pixel(xx, yy, Color(minf(p.r * k.x, 1.0), minf(p.g * k.y, 1.0), minf(p.b * k.z, 1.0)).linear_to_srgb())
	im.generate_mipmaps()
	var ruta: String = TEX + "losas_piedra_ruinas.res"
	ResourceSaver.save(ImageTexture.create_from_image(im), ruta)
	print("OK     losas del suelo teñidas: %s (media de las losas %s -> muro %s)" % [ruta, media.linear_to_srgb(), muro.linear_to_srgb()])
	return true


## 25/11 (Pablo: «marca las juntas»): el beige de las losas con las juntas oscurecidas. Se sacan de la normal del pack: donde la superficie se
## inclina (los bordes biselados de cada losa) el color baja, f = 1 − (1 − n.z) × JUNTAS_GANANCIA, sin bajar de JUNTAS_MIN. Solo las losas: el muro no cambia.
func _losa_juntas(nombre: String, normal: String) -> Texture2D:
	var ruta_res: String = TEX + nombre + "_losa.res"
	var base: Image = _beige(nombre).get_image().duplicate()
	if base.is_compressed():
		base.decompress()
	base.clear_mipmaps()
	base.convert(Image.FORMAT_RGB8)
	var nm := Image.load_from_file(ProjectSettings.globalize_path(TEX + normal + ".png"))
	if nm == null or nm.is_empty():
		return _beige(nombre)
	nm.convert(Image.FORMAT_RGB8)
	if nm.get_size() != base.get_size():
		nm.resize(base.get_width(), base.get_height(), Image.INTERPOLATE_BILINEAR)
	for yy in range(base.get_height()):
		for xx in range(base.get_width()):
			var n: Color = nm.get_pixel(xx, yy)
			var nx: float = n.r * 2.0 - 1.0
			var ny: float = n.g * 2.0 - 1.0
			var nz: float = sqrt(maxf(1.0 - nx * nx - ny * ny, 0.0))
			var f: float = clampf(1.0 - (1.0 - nz) * JUNTAS_GANANCIA, JUNTAS_MIN, 1.0)
			var p: Color = base.get_pixel(xx, yy).srgb_to_linear()
			base.set_pixel(xx, yy, Color(p.r * f, p.g * f, p.b * f).linear_to_srgb())
	base.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(base), ruta_res)
	return load(ruta_res) as Texture2D


## El color del pack teñido de beige: beige × (1 + (lum − 0,4) × 2, entre 0,2 y 1,6) mezclado al DETALLE, todo en lineal.
func _beige(nombre: String) -> Texture2D:
	var ruta_res: String = TEX + nombre + "_beige.res"
	var im := Image.load_from_file(ProjectSettings.globalize_path(TEX + nombre + ".png"))
	if im == null or im.is_empty():
		return null
	im.convert(Image.FORMAT_RGB8)
	var b: Color = BEIGE.srgb_to_linear()
	for yy in range(im.get_height()):
		for xx in range(im.get_width()):
			var p: Color = im.get_pixel(xx, yy).srgb_to_linear()
			var lum: float = p.r * 0.299 + p.g * 0.587 + p.b * 0.114
			var f: float = lerpf(1.0, clampf(1.0 + (lum - 0.4) * 2.0, 0.2, 1.6), DETALLE)
			im.set_pixel(xx, yy, Color(b.r * f, b.g * f, b.b * f).linear_to_srgb())
	im.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(im), ruta_res)
	return load(ruta_res) as Texture2D


func _material(m: String) -> Material:
	if _mats.has(m):
		return _mats[m]
	var r: Array = RECETAS.get(m, [])
	if r.is_empty():
		_mats[m] = null
		return null
	var mat := StandardMaterial3D.new()
	mat.resource_name = m
	var modo: String = String(r[3]) if r.size() > 3 else "beige"
	if modo == "hiedra":
		# hojas en tarjetas: recorte por alfa, las dos caras, sin normal ni AORM
		mat.albedo_texture = load(TEX + r[0] + ".png")
		mat.albedo_color = TINTE_HIEDRA
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		ResourceSaver.save(mat, MATERIALES + m + ".tres")
		_mats[m] = load(MATERIALES + m + ".tres")
		return _mats[m]
	mat.albedo_texture = _beige(r[0]) if modo == "beige" else (_losa_juntas(r[0], r[1]) if modo == "losa" else load(TEX + r[0] + ".png"))
	mat.normal_enabled = true
	mat.normal_texture = load(TEX + r[1] + ".png")
	var orm: Texture2D = load(TEX + r[2] + ".png")
	mat.ao_enabled = true
	mat.ao_texture = orm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	mat.roughness_texture = orm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic = 0.0
	if modo == "losa":
		# 25/11: con la rugosidad del AORM el suelo brillaba como mojado (reflejos del cielo en una superficie grande y plana): mate.
		mat.roughness_texture = null
		mat.roughness = 1.0
		mat.albedo_color = COLOR_LOSAS       # 25/11: calibrado en pantalla contra el ladrillo del muro
		# 2.º (Pablo: «el suelo parece lavado, las juntas muy tenues»): la oclusión del AORM también con luz directa y más relieve: las juntas se leen.
		mat.ao_light_affect = AO_LOSAS
		mat.normal_scale = RELIEVE_LOSAS
	ResourceSaver.save(mat, MATERIALES + m + ".tres")
	_mats[m] = load(MATERIALES + m + ".tres")
	return _mats[m]


func _xf(n: Node, raiz: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _pieza(nombre: String) -> bool:
	var ps: PackedScene = load(MALLAS + nombre + ".fbx") as PackedScene
	if ps == null:
		print("FALLO  no se importó ", nombre)
		return false
	var esc: Node = ps.instantiate()
	var mi_orig: MeshInstance3D = null
	for h in esc.find_children("*", "MeshInstance3D", true, false):
		mi_orig = h
		break
	if mi_orig == null:
		esc.free()
		print("FALLO  %s sin malla" % nombre)
		return false
	var malla: Mesh = mi_orig.mesh
	var xf: Transform3D = _xf(mi_orig, esc)
	var c0: AABB = xf * malla.get_aabb()
	var giro: float = 90.0 if c0.size.z > c0.size.x else 0.0
	var base := Basis(Vector3.UP, deg_to_rad(giro)) * Basis.from_scale(Vector3.ONE * ESCALA)
	var caja: AABB = Transform3D(base, Vector3.ZERO) * c0
	var t := Transform3D(base, -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5))
	var id: String = PAREDES.id_de(nombre)
	var ruta_malla: String = MALLAS_RES + id + ".res"
	ResourceSaver.save(malla, ruta_malla)
	malla = load(ruta_malla) as Mesh

	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", true)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", false)
	raiz.set_meta("origen", ORIGEN)
	raiz.set_meta("pieza_original", nombre)
	raiz.set_meta("categoria", "muro")
	var modelo := Node3D.new()
	modelo.name = "modelo"
	raiz.add_child(modelo)
	var mi := MeshInstance3D.new()
	mi.name = "malla"
	mi.mesh = malla
	mi.transform = t * xf
	modelo.add_child(mi)
	var mats: Array = []
	for s in range(malla.get_surface_count()):
		var orig: Material = malla.surface_get_material(s)
		var nm: String = orig.resource_name if orig != null else ""
		mats.append(nm)
		var mat: Material = _material(nm)
		if mat != null:
			mi.set_surface_override_material(s, mat)
	# Colisión: la caja del muro (para los hechizos; a pie ya bloquea la casilla entera). Los adornos (hiedra, escombros, losas…) no llevan cuerpo.
	if nombre in PAREDES.ADORNOS:
		raiz.set_meta("bloquea", false)
		raiz.set_meta("categoria", "adorno")
		for n2 in [modelo, mi]:
			(n2 as Node).owner = raiz
		var emp := PackedScene.new()
		emp.pack(raiz)
		var sal: String = PAREDES.RUTA + id + ".tscn"
		var e2: int = ResourceSaver.save(emp, sal)
		raiz.free()
		esc.free()
		print("OK     %-28s %5.2f x %5.2f x %5.2f u  giro %3d  %s  (adorno)" % [id, caja.size.x, caja.size.y, caja.size.z, int(giro), str(mats)])
		return e2 == OK
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "cuerpo"
	cuerpo.collision_layer = CAPA_MUNDO
	cuerpo.collision_mask = 0
	raiz.add_child(cuerpo)
	var cs := CollisionShape3D.new()
	cs.name = "forma_0"
	var bx := BoxShape3D.new()
	bx.size = caja.size
	cs.shape = bx
	cs.position = Vector3(0.0, caja.size.y * 0.5, 0.0)
	cuerpo.add_child(cs)
	for n in [modelo, mi, cuerpo, cs]:
		(n as Node).owner = raiz
	var empaquetada := PackedScene.new()
	empaquetada.pack(raiz)
	var salida: String = PAREDES.RUTA + id + ".tscn"
	var err: int = ResourceSaver.save(empaquetada, salida)
	raiz.free()
	esc.free()
	if err != OK:
		print("FALLO  no se pudo guardar ", salida)
		return false
	print("OK     %-28s %5.2f x %5.2f x %5.2f u  giro %3d  %s" % [id, caja.size.x, caja.size.y, caja.size.z, int(giro), str(mats)])
	return true
