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
}

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
	quit(0 if bien == PAREDES.TODAS.size() else 1)


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
	mat.albedo_texture = _beige(r[0])
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
	# Colisión: la caja del muro (para los hechizos; a pie ya bloquea la casilla entera).
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
