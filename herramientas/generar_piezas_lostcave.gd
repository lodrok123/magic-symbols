extends SceneTree

## GENERADOR (24/11/2026) de las piezas del pack «Stylized Lost Cave» (StylArts / Leartes Cosmos). Lo de cambiar a mano está en
## `arte/lostcave/tabla_lostcave.gd`; el flujo entero, en `tools/preparar_lostcave.cmd`. Tres pasos (argumento tras `--`):
##   --texturas  baja a 1K las texturas que usan los materiales (desde arte/lostcave/_fuente/texturas), tapa la marca del autor, mete la
##               opacidad del follaje en el alfa del color y HORNEA la roca en mosaico (losa × máscara) a una textura por material.
##   --ajustes   pone en los .import de arte/lostcave/texturas los ajustes de 3D: VRAM, mipmaps y mapa de normales en las *_N.
##               (después hay que reimportar:  godot --headless --path . --import)
##   --roca-material M_X  regenera solamente la textura horneada de ese material de roca.
##   --follaje   regenera solo las tres piezas de FOLLAJE_PIEZAS, con sus materiales derivados.
##   --piezas    (por defecto) crea materiales/*.tres, mallas_res/<id>.res y piezas/lost_<nombre>.tscn con el formato de arte/piezas
##               (raíz Node3D con metadata, `modelo/malla` y `cuerpo` StaticBody3D en la capa 1024 con la colisión del autor), y las calcas
##               (símbolos y grietas) como piezas con un nodo Decal.
## Reejecutable: sobrescribe. Imprime una línea por pieza y un RESULTADO al final.
##   godot --headless --path . --script res://herramientas/generar_piezas_lostcave.gd -- --piezas

const T = preload("res://arte/lostcave/tabla_lostcave.gd")
const AJUSTE_NATURALES = preload("res://presentacion/ajuste_naturales_3d.gd")
const CAPA_MUNDO: int = 1024
const S: float = 2.3
const ALFA_JSON: String = "res://arte/lostcave/texturas/_alfa.json"   ## texturas de color que llevan alfa (para decidir el recorte)

var _mats: Dictionary = {}          ## receta de Unity por nombre (materiales_unity.json)
var _hechos: Dictionary = {}        ## M_X -> Material ya creado (o null si no se traduce)
var _alfa: Dictionary = {}


func _initialize() -> void:
	var modo: String = "--piezas"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			modo = a
	var txt: String = FileAccess.get_file_as_string(T.CARPETA_FUENTE + "materiales_unity.json")
	if txt == "":
		print("FALLO  no hay %smateriales_unity.json: antes, python tools/preparar_lostcave.py <zip>" % T.CARPETA_FUENTE)
		quit(1)
		return
	_mats = JSON.parse_string(txt)
	match modo:
		"--follaje":
			_piezas(T.FOLLAJE_PIEZAS)
		"--roca-material":
			var argumentos: PackedStringArray = OS.get_cmdline_user_args()
			var material_pedido: String = argumentos[-1]
			if _tipo(material_pedido) != "roca":
				push_error("Se esperaba un material de roca: " + material_pedido)
				quit(1)
				return
			if _hornear_roca(material_pedido) == 0:
				quit(1)
				return
		"--texturas":
			_texturas()
		"--ajustes":
			_ajustes()
		_:
			_piezas()
	quit(0)


# ---------------------------------------------------------------- recetas

func _tipo(m: String) -> String:
	if not _mats.has(m):
		return ""
	return String(T.TIPO_SHADER.get(String(_mats[m]["shader"]), ""))


## Primera textura de verdad de entre esos huecos (salta las de relleno del pack: T_Fill_*, T_StandIn_*).
func _tex(m: String, huecos: Array) -> String:
	var tex: Dictionary = _mats[m]["tex"]
	for h in huecos:
		if tex.has(h):
			var n: String = String(tex[h])
			if not n.begins_with("T_Fill") and not n.begins_with("T_StandIn"):
				return n
	return ""


func _num(m: String, clave: String, defecto: float) -> float:
	return float((_mats[m]["num"] as Dictionary).get(clave, defecto))


func _color(m: String, clave: String, defecto: Color) -> Color:
	var c: Array = (_mats[m]["color"] as Dictionary).get(clave, [])
	return Color(c[0], c[1], c[2]) if c.size() >= 3 else defecto


func _opacidad(m: String) -> String:
	return _tex(m, ["_OpacityMask", "_Opacity"]) if _num(m, "_AlphaCutoffEnable", 0.0) > 0.5 else ""


# ---------------------------------------------------------------- paso 1: texturas

func _texturas() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(T.CARPETA_TEXTURAS))
	var hechas: Dictionary = {}
	var n: int = 0
	for m in _mats:
		var tipo: String = _tipo(m)
		match tipo:
			"pbr":
				var bc: String = _tex(m, ["_BaseMap"])
				if bc != "":
					n += _bajar(bc, hechas, _opacidad(m))
				for t in [_tex(m, ["_NormalMap", "_Normal", "_Normals"]), _tex(m, ["_ORM", "_ORM_Map"]), _tex(m, ["_Emissive"])]:
					if t != "":
						n += _bajar(t, hechas)
			"roca":
				n += _hornear_roca(m)
				var nm: String = _tex(m, ["_Macro_Normal"])
				if nm != "":
					n += _bajar(nm, hechas)
			"calca":
				var cbc: String = _tex(m, ["_BaseMap", "_Base_Map"])
				if cbc != "":
					n += _bajar(cbc, hechas, "", m.begins_with("M_Glowing"))
				var cn: String = _tex(m, ["_NormalMap", "_Normal_Map"])
				if cn != "":
					n += _bajar(cn, hechas)
			"llama":
				n += _bajar("T_FlameAlpha_O", hechas)
	var f := FileAccess.open(ALFA_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify(_alfa, "\t"))
	print("RESULTADO texturas escritas: %d (lado máximo %d) en %s" % [n, T.LADO_MAX, T.CARPETA_TEXTURAS])


func _cargar_fuente(nombre: String) -> Image:
	var ruta: String = ProjectSettings.globalize_path(T.CARPETA_FUENTE + "texturas/" + nombre + ".png")
	var im := Image.load_from_file(ruta)
	if im == null or im.is_empty():
		print("FALLO  falta la textura ", ruta)
		return null
	if im.is_compressed():
		im.decompress()
	return im


## Baja una textura a LADO_MAX, tapa la marca si toca y, si se da `opacidad`, mete esa imagen (gris) en el alfa. Con `alfa_por_croma`
## (calcas sin un alfa útil: la grieta y los puntos brillantes son trazos azules sobre fondo claro) el alfa sale de cuánto color tiene cada
## píxel: el fondo gris o blanco queda transparente. Devuelve 1 si la escribe.
func _bajar(nombre: String, hechas: Dictionary, opacidad: String = "", alfa_por_croma: bool = false) -> int:
	if hechas.has(nombre):
		return 0
	hechas[nombre] = true
	var im: Image = _cargar_fuente(nombre)
	if im == null:
		return 0
	var lado: int = mini(T.LADO_MAX, maxi(im.get_width(), im.get_height()))
	if T.TAPAR_MARCA.has(nombre):
		im.convert(Image.FORMAT_RGBA8)
		_tapar(im, T.TAPAR_MARCA[nombre])
	if opacidad != "":
		var op: Image = _cargar_fuente(opacidad)
		if op != null:
			im.convert(Image.FORMAT_RGBA8)
			op.convert(Image.FORMAT_L8)
			op.resize(im.get_width(), im.get_height(), Image.INTERPOLATE_BILINEAR)
			for y in im.get_height():
				for x in im.get_width():
					var c: Color = im.get_pixel(x, y)
					c.a = op.get_pixel(x, y).r
					im.set_pixel(x, y, c)
	if im.get_width() != lado or im.get_height() != lado:
		im.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
	if alfa_por_croma:                     # su PNG trae canal alfa, pero casi opaco entero: no sirve de recorte
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				var c: Color = im.get_pixel(x, y)
				c.a = clampf((maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) * 4.0, 0.0, 1.0)
				im.set_pixel(x, y, c)
		# el Decal NO recorta la emisión con el alfa: la emisión va aparte, premultiplicada (fondo negro = no brilla)
		var em := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGB8)
		for y in im.get_height():
			for x in im.get_width():
				var c2: Color = im.get_pixel(x, y)
				em.set_pixel(x, y, Color(c2.r * c2.a, c2.g * c2.a, c2.b * c2.a))
		em.save_png(ProjectSettings.globalize_path(T.CARPETA_TEXTURAS + nombre + "_emision.png"))
	if im.detect_alpha() != Image.ALPHA_NONE:
		_alfa[nombre] = true
	im.save_png(ProjectSettings.globalize_path(T.CARPETA_TEXTURAS + nombre + ".png"))
	return 1


## Copia encima de la zona [x0,y0,x1,y1] el trozo desplazado [dx,dy] (fracciones de la imagen).
func _tapar(im: Image, d: Array) -> void:
	var r: Array = d[0]
	var off: Array = d[1]
	var w: int = im.get_width()
	var h: int = im.get_height()
	var zona := Rect2i(int(r[0] * w), int(r[1] * h), int((r[2] - r[0]) * w), int((r[3] - r[1]) * h))
	var trozo: Image = im.get_region(Rect2i(zona.position + Vector2i(int(off[0] * w), int(off[1] * h)), zona.size))
	im.blit_rect(trozo, Rect2i(Vector2i.ZERO, zona.size), zona.position)


## Roca en mosaico horneada: losa de roca repetida ROCA_REPETICION veces sobre la UV; donde el damero (R) de la máscara está alto la losa se
## desplaza media celda (segunda variante); B oscurece las grietas (oclusión) y G por encima de 0,5 aclara los cantos. Sale <M_X>_roca.png.
func _hornear_roca(m: String) -> int:
	var mascara_n: String = _tex(m, ["_RockMask_Map"])
	var losa_n: String = _tex(m, ["_BaseMap", "_RockDiffuse"])
	if losa_n == "":
		losa_n = "T_Rock_Tiles_BC"
	if mascara_n == "":
		print("FALLO  %s: sin máscara de roca" % m)
		return 0
	var losa: Image = _cargar_fuente(losa_n)
	var mascara: Image = _cargar_fuente(mascara_n)
	if losa == null or mascara == null:
		return 0
	var lado: int = T.LADO_MAX
	losa.convert(Image.FORMAT_RGB8)
	losa.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
	mascara.convert(Image.FORMAT_RGB8)
	mascara.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
	var rep: float = float(T.ROCA_REPETICION.get(m, 3.0))
	var tinte: Color = _color(m, "_BC_Tint", Color.WHITE)
	var sal := Image.create(lado, lado, false, Image.FORMAT_RGB8)
	for y in lado:
		for x in lado:
			# La máscara genérica pertenece a otro atlas: en esta pieza pintaba
			# cuñas negras sobre las agujas. Conservar la losa y el normal propios.
			var mk: Color = Color(0.0, 0.5, 1.0) if m in T.ROCA_SIN_MASCARA_ATLAS else mascara.get_pixel(x, y)
			var u: float = float(x) / lado * rep
			var v: float = float(y) / lado * rep
			if mk.r > 0.5:
				u += 0.5
				v += 0.5
			var c: Color = losa.get_pixel(posmod(int(u * lado), lado), posmod(int(v * lado), lado))
			c = c * tinte * T.ROCA_BRILLO
			var ao: float = lerpf(1.0, mk.b, T.ROCA_OCLUSION)
			var canto: float = maxf(mk.g - 0.5, 0.0) * 2.0 * T.ROCA_CURVATURA
			sal.set_pixel(x, y, Color(c.r * ao + canto, c.g * ao + canto, c.b * ao + canto))
	sal.save_png(ProjectSettings.globalize_path(T.CARPETA_TEXTURAS + m + "_roca.png"))
	print("OK     roca horneada %s  (losa %s × máscara %s, repetición %.1f)" % [m, losa_n, mascara_n, rep])
	return 1


# ---------------------------------------------------------------- paso 2: ajustes de importación

func _ajustes() -> void:
	var d := DirAccess.open(T.CARPETA_TEXTURAS)
	var n: int = 0
	for f in d.get_files():
		if not f.ends_with(".png.import"):
			continue
		var ruta: String = T.CARPETA_TEXTURAS + f
		var cfg := ConfigFile.new()
		if cfg.load(ruta) != OK:
			continue
		var nombre: String = f.trim_suffix(".png.import")
		cfg.set_value("params", "compress/mode", 2)                 # VRAM comprimida (como las texturas 3D del juego)
		cfg.set_value("params", "mipmaps/generate", true)           # sin mipmaps titilan de lejos
		cfg.set_value("params", "detect_3d/compress_to", 0)
		cfg.set_value("params", "compress/normal_map", 1 if (nombre.ends_with("_N") or nombre.contains("_N_") or nombre.ends_with("_Norm")) else 2)
		cfg.save(ruta)
		n += 1
	print("RESULTADO .import ajustados: %d. Falta reimportar:  godot --headless --path . --import" % n)


# ---------------------------------------------------------------- paso 3: materiales y piezas

func _piezas(solo: Array = []) -> void:
	for c in [T.CARPETA_MATERIALES, T.CARPETA_MALLAS_RES, T.CARPETA_PIEZAS]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(c))
	# las piezas y mallas son todas de este generador: se borran antes para que no queden huérfanas si cambia un id
	for c in [T.CARPETA_MALLAS_RES, T.CARPETA_PIEZAS]:
		if not solo.is_empty(): continue
		for f in DirAccess.get_files_at(c):
			if f.begins_with(T.PREFIJO):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(c + f))
	var a: String = FileAccess.get_file_as_string(ALFA_JSON)
	_alfa = JSON.parse_string(a) if a != "" else {}
	var hechas: int = 0
	var cuenta: Dictionary = {}
	var d := DirAccess.open(T.CARPETA_MALLAS)
	var nombres: Array = []
	for f in d.get_files():
		if f.ends_with(".gltf"):
			nombres.append(f.trim_suffix(".gltf"))
	nombres.sort()
	for nombre in nombres:
		if not solo.is_empty() and nombre not in solo: continue
		if T.EXCLUIDAS.has(nombre):
			continue
		var cat: String = _generar(String(nombre))
		if cat != "":
			hechas += 1
			cuenta[cat] = int(cuenta.get(cat, 0)) + 1
	for m in _mats:
		if not solo.is_empty(): continue
		if _tipo(m) == "calca" and _calca(String(m)):
			hechas += 1
			cuenta["calca"] = int(cuenta.get("calca", 0)) + 1
	print("RESULTADO piezas generadas: %d  %s" % [hechas, str(cuenta)])


func _textura(nombre: String) -> Texture2D:
	var ruta: String = T.CARPETA_TEXTURAS + nombre + ".png"
	if nombre == "" or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D


## Material de Godot para la receta M_X (se crea una vez y se guarda en materiales/M_X.tres). null = no se traduce (agua...).
func _material(m: String) -> Material:
	if _hechos.has(m):
		return _hechos[m]
	var mat: StandardMaterial3D = null
	match _tipo(m):
		"pbr":
			mat = StandardMaterial3D.new()
			var bc: String = _tex(m, ["_BaseMap"])
			mat.albedo_texture = _textura(bc)
			var b: float = _color(m, "_BaseColor_Value", Color.WHITE).r if T.USAR_BRILLO_UNITY else 1.0
			mat.albedo_color = Color(b, b, b)
			var nm: Texture2D = _textura(_tex(m, ["_NormalMap", "_Normal", "_Normals"]))
			if nm != null:
				mat.normal_enabled = true
				mat.normal_texture = nm
			var orm: Texture2D = _textura(_tex(m, ["_ORM", "_ORM_Map"]))
			if orm != null:
				mat.ao_enabled = true
				mat.ao_texture = orm
				mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				mat.roughness = 1.0
				mat.roughness_texture = orm
				mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				mat.metallic = 1.0
				mat.metallic_texture = orm
				mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			else:
				mat.roughness = 0.9
			var em: Texture2D = _textura(_tex(m, ["_Emissive"]))
			var fuerza: float = _num(m, "_Emission_Strength", 0.0) if String(_mats[m]["shader"]) == "S_Simple_Asset" \
					else _num(m, "_EmissiveIntensity", 0.0) * _color(m, "_EmissiveColor", Color.BLACK).get_luminance()
			if em != null and fuerza > 0.0:
				mat.emission_enabled = true
				mat.emission = Color.WHITE
				mat.emission_texture = em
				mat.emission_energy_multiplier = fuerza * T.EMISION_ESCALA
			if _num(m, "_AlphaCutoffEnable", 0.0) > 0.5 and _alfa.has(bc):
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.5
			if _num(m, "_DoubleSidedEnable", 0.0) > 0.5:
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"roca":
			mat = StandardMaterial3D.new()
			mat.albedo_texture = _textura(m + "_roca")
			mat.roughness = 0.85
			var nm2: Texture2D = _textura(_tex(m, ["_Macro_Normal"]))
			if nm2 != null:
				mat.normal_enabled = true
				mat.normal_texture = nm2
		"llama":
			mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = T.LLAMA_COLOR * T.LLAMA_ENERGIA
			mat.albedo_texture = _textura("T_FlameAlpha_O")
	if mat != null:
		mat.resource_name = m
		ResourceSaver.save(mat, T.CARPETA_MATERIALES + m + ".tres")
		mat = load(T.CARPETA_MATERIALES + m + ".tres") as StandardMaterial3D
	_hechos[m] = mat
	return mat


## Duplicar el material y el albedo: ninguna otra planta que comparta atlas cambia.
func _material_follaje(original: StandardMaterial3D, id: String) -> StandardMaterial3D:
	var clave: String = original.resource_name + "_natural"
	if _hechos.has(clave): return _hechos[clave]
	var mat: StandardMaterial3D = original.duplicate()
	var im: Image = AJUSTE_NATURALES.procesar(original.albedo_texture.get_image(), false, T.FOLLAJE_SATURACION, T.FOLLAJE_BRILLO)
	var ruta_png: String = T.CARPETA_TEXTURAS + clave + ".png"
	im.save_png(ruta_png)
	# Un recurso .res independiente permite guardar la textura sin una importación
	# intermedia; generar mipmaps aquí evita ruido fino al alejar la cámara.
	im.generate_mipmaps()
	var tex := ImageTexture.create_from_image(im)
	var ruta_tex: String = T.CARPETA_TEXTURAS + clave + ".res"
	ResourceSaver.save(tex, ruta_tex)
	mat.albedo_texture = load(ruta_tex) as Texture2D
	mat.resource_name = clave
	mat.alpha_scissor_threshold = T.FOLLAJE_CORTE_ALFA
	var ruta_mat: String = T.CARPETA_MATERIALES + clave + ".tres"
	ResourceSaver.save(mat, ruta_mat)
	_hechos[clave] = load(ruta_mat)
	print("PALETA FOLLAJE ",id," ",clave)
	return _hechos[clave]


## Transformación de un nodo respecto a la raíz de la escena importada (la escena no está en el árbol: se multiplica a mano).
func _xf(n: Node, raiz: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _mallas(n: Node, salida: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		salida.append(n)
	for h in n.get_children():
		_mallas(h, salida)


func _generar(nombre: String) -> String:
	var ps: PackedScene = load(T.CARPETA_MALLAS + nombre + ".gltf") as PackedScene
	if ps == null:
		print("FALLO  no se importó ", nombre)
		return ""
	var esc: Node = ps.instantiate()
	var todas: Array = []
	_mallas(esc, todas)
	var principal: MeshInstance3D = null
	var casco: MeshInstance3D = null
	for mi in todas:
		var nn: String = String(mi.name)
		if nn.contains("ConvexHulls"):
			casco = mi
		elif principal == null or nn.ends_with("_LOD0"):
			principal = mi
	if principal == null:
		print("FALLO  %s sin malla" % nombre)
		esc.free()
		return ""
	var malla: Mesh = principal.mesh
	var xf_malla: Transform3D = _xf(principal, esc)
	var id: String = T.id_de(nombre)
	var cat: String = T.categoria_de(nombre)
	var f: float = float(T.ESCALA_PIEZA.get(nombre, T.FACTOR))
	var giro: float = 0.0
	if T.GIRO.has(nombre):
		giro = float(T.GIRO[nombre])
	else:
		var c0: AABB = xf_malla * malla.get_aabb()
		if c0.size.z > c0.size.x * T.GIRO_AUTO_RAZON:
			giro = 90.0                    # lo largo (Z) pasa a X: horizontal en pantalla
	var base := Basis(Vector3.UP, deg_to_rad(giro)) * Basis.from_scale(Vector3.ONE * f)
	var caja: AABB = Transform3D(base, Vector3.ZERO) * (xf_malla * malla.get_aabb())
	var pos := -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5)
	var t := Transform3D(base, pos)
	var alto: float = caja.size.y
	var solido: bool = alto > T.ALTO_MIN_SOLIDO + 0.0001

	# malla como recurso propio (con los LOD que generó el importador)
	var ruta_malla: String = T.CARPETA_MALLAS_RES + id + ".res"
	ResourceSaver.save(malla, ruta_malla)
	malla = load(ruta_malla) as Mesh

	var raiz := Node3D.new()
	raiz.name = id
	var mi := MeshInstance3D.new()
	mi.name = "malla"
	mi.mesh = malla
	mi.transform = t * xf_malla
	var inflamable: bool = true
	var mats_usados: Array = []
	var tris: int = 0
	for s in range(malla.get_surface_count()):
		var nom_sup: String = malla.surface_get_name(s)
		if nom_sup == "" and malla.surface_get_material(s) != null:
			nom_sup = malla.surface_get_material(s).resource_name
		var m: String = T.material_unity(nom_sup)
		mats_usados.append(m)
		inflamable = inflamable and T.MAT_INFLAMABLE.has(m)
		var mat: Material = _material(m)
		if nombre in T.FOLLAJE_PIEZAS and m.begins_with("M_Atlas_") and mat is StandardMaterial3D:
			mat = _material_follaje(mat, id)
		if mat != null:
			mi.set_surface_override_material(s, mat)
		var arr: Array = malla.surface_get_arrays(s)
		tris += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", solido)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", inflamable)
	raiz.set_meta("origen", T.ORIGEN)
	raiz.set_meta("pieza_original", nombre)
	raiz.set_meta("triangulos", tris)
	raiz.set_meta("categoria", cat)
	raiz.set_meta("giro", giro)
	var modelo := Node3D.new()
	modelo.name = "modelo"
	raiz.add_child(modelo)
	modelo.add_child(mi)
	var luz: Array = T.luz_de(nombre)
	if not luz.is_empty():
		var omni := OmniLight3D.new()
		omni.name = "luz"
		omni.light_color = luz[0]
		omni.light_energy = float(luz[1])
		omni.omni_range = float(luz[2])
		omni.light_specular = 0.0
		omni.shadow_enabled = false
		omni.position = Vector3(0.0, alto * float(luz[3]), 0.0)
		raiz.add_child(omni)

	var n_formas: int = 0
	if solido:
		var formas: Array = []
		if T.colision_exacta(nombre):
			# arcos, túneles, bocamina, escaleras: la envolvente convexa del autor es UNA por malla y taparía el paso; aquí va la malla tal cual
			var caras: PackedVector3Array = malla.get_faces()
			var tx: Transform3D = t * xf_malla
			for i in caras.size():
				caras[i] = tx * caras[i]
			var exacta := ConcavePolygonShape3D.new()
			exacta.set_faces(caras)
			formas.append(exacta)
			if T.con_patas(nombre):
				var patas: Array = _patas(caras)
				formas.append_array(patas)
				raiz.set_meta("huella_por_forma", true)
				raiz.set_meta("patas", patas.size())
		elif casco != null:
			formas = _trozos_convexos(casco.mesh, t * _xf(casco, esc))
		if formas.is_empty() and malla is ArrayMesh:
			var cv: ConvexPolygonShape3D = (malla as ArrayMesh).create_convex_shape(true, true)
			var fuera := PackedVector3Array()
			for p in cv.points:
				fuera.append(t * xf_malla * p)
			cv.points = fuera
			formas.append(cv)
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "cuerpo"
		cuerpo.collision_layer = CAPA_MUNDO
		cuerpo.collision_mask = 0
		raiz.add_child(cuerpo)
		for forma in formas:
			var cs := CollisionShape3D.new()
			cs.name = "forma_%d" % n_formas
			cs.shape = forma
			cuerpo.add_child(cs)
			n_formas += 1
	_propietario(raiz, raiz)
	var empaquetada := PackedScene.new()
	empaquetada.pack(raiz)
	var salida: String = T.CARPETA_PIEZAS + id + ".tscn"
	var err: int = ResourceSaver.save(empaquetada, salida)
	raiz.free()
	esc.free()
	if err != OK:
		print("FALLO  no se pudo guardar ", salida, " error ", err)
		return ""
	print("OK     %-28s %-10s x%.2f giro %3d  %5.2f x %5.2f casillas (%5.2f x %5.2f u)  %6d tris  formas=%d  %s" % [
		id, cat, f, int(giro), maxf(caja.size.x, caja.size.z) / S, alto / S, maxf(caja.size.x, caja.size.z), alto, tris, n_formas, str(mats_usados)])
	return cat


## El nodo «ConvexHulls» del autor junta en una malla varias piezas convexas: se separan por componentes conexas (vértices soldados por
## posición) y cada una es un ConvexPolygonShape3D, ya en el espacio de la pieza.
func _trozos_convexos(casco: Mesh, t: Transform3D) -> Array:
	var formas: Array = []
	for s in range(casco.get_surface_count()):
		var arr: Array = casco.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var soldado: Dictionary = {}       # posición redondeada -> índice representante
		var rep := PackedInt32Array()
		rep.resize(v.size())
		for i in v.size():
			var k: Vector3i = Vector3i((v[i] * 10000.0).round())
			if not soldado.has(k):
				soldado[k] = i
			rep[i] = int(soldado[k])
		var padre: Dictionary = {}
		for i in rep:
			padre[i] = i
		var buscar := func(x: int) -> int:
			while padre[x] != x:
				padre[x] = padre[padre[x]]
				x = padre[x]
			return x
		for tri in range(0, idx.size() - 2, 3):
			var a: int = buscar.call(rep[idx[tri]])
			for j in [1, 2]:
				var b: int = buscar.call(rep[idx[tri + j]])
				if a != b:
					padre[b] = a
		var grupos: Dictionary = {}
		for k in soldado:
			var r: int = buscar.call(int(soldado[k]))
			if not grupos.has(r):
				grupos[r] = []
			(grupos[r] as Array).append(t * v[int(soldado[k])])
		for r in grupos:
			var puntos := PackedVector3Array(grupos[r] as Array)
			if puntos.size() >= 4:
				var forma := ConvexPolygonShape3D.new()
				forma.points = puntos
				formas.append(forma)
	return formas


## Las PATAS de una pieza con hueco: los vértices de sus caras por debajo de ALTO_PATA, agrupados en una rejilla XZ de CELDA_PATA por contacto
## (8 vecinas); cada grupo de al menos PATA_MIN celdas es un ConvexPolygonShape3D (sus puntos y los mismos a ALTO_PATA, para que tenga cuerpo).
func _patas(caras: PackedVector3Array) -> Array:
	var celdas: Dictionary = {}          # Vector2i -> Array de puntos (Array y no PackedVector3Array: el Packed del diccionario se copia al añadir y se quedaba vacío)
	for v in caras:
		if v.y > T.ALTO_PATA:
			continue
		var k := Vector2i(floori(v.x / T.CELDA_PATA), floori(v.z / T.CELDA_PATA))
		if not celdas.has(k):
			celdas[k] = []
		(celdas[k] as Array).append(v)
	var vistas: Dictionary = {}
	var formas: Array = []
	for k0 in celdas:
		if vistas.has(k0):
			continue
		var grupo: Array = [k0]
		vistas[k0] = true
		var i: int = 0
		while i < grupo.size():
			var k: Vector2i = grupo[i]
			i += 1
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var q := Vector2i(k.x + dx, k.y + dz)
					if celdas.has(q) and not vistas.has(q):
						vistas[q] = true
						grupo.append(q)
		if grupo.size() < T.PATA_MIN:
			continue
		var puntos := PackedVector3Array()
		for k in grupo:
			for v in (celdas[k] as Array):
				puntos.append(Vector3(v.x, 0.0, v.z))
				puntos.append(Vector3(v.x, T.ALTO_PATA, v.z))
		var forma := ConvexPolygonShape3D.new()
		forma.points = puntos
		formas.append(forma)
	return formas


## Calca (símbolo rupestre, grieta, puntos brillantes): pieza con un Decal que proyecta hacia -Z (sobre la pared que tenga detrás).
func _calca(m: String) -> bool:
	var bc: Texture2D = _textura(_tex(m, ["_BaseMap", "_Base_Map"]))
	if bc == null:
		print("FALLO  calca %s sin textura" % m)
		return false
	var id: String = T.PREFIJO + "calca_" + m.trim_prefix("M_").to_lower()
	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", false)
	raiz.set_meta("reactivo", false)
	raiz.set_meta("inflamable", false)
	raiz.set_meta("origen", T.ORIGEN)
	raiz.set_meta("pieza_original", m)
	raiz.set_meta("categoria", "calca")
	var dc := Decal.new()
	dc.name = "calca"
	dc.size = Vector3(T.CALCA_LADO, T.CALCA_FONDO, T.CALCA_LADO)
	dc.rotation_degrees = Vector3(90, 0, 0)        # el Decal proyecta por -Y: girado, proyecta por -Z
	dc.position = Vector3(0, T.CALCA_ALTO, 0)
	dc.normal_fade = T.CALCA_FUNDIDO_NORMAL
	dc.texture_albedo = bc
	var nm: Texture2D = _textura(_tex(m, ["_NormalMap", "_Normal_Map"]))
	if nm != null:
		dc.texture_normal = nm
	var em: Texture2D = _textura(_tex(m, ["_BaseMap", "_Base_Map"]) + "_emision")
	if em != null:
		dc.texture_emission = em
		dc.emission_energy = 2.0
	raiz.add_child(dc)
	_propietario(raiz, raiz)
	var ps := PackedScene.new()
	ps.pack(raiz)
	var err: int = ResourceSaver.save(ps, T.CARPETA_PIEZAS + id + ".tscn")
	raiz.free()
	print("OK     %-28s calca      %.2f u de lado  %s" % [id, T.CALCA_LADO, m])
	return err == OK


func _propietario(n: Node, duenio: Node) -> void:
	for h in n.get_children():
		h.owner = duenio
		_propietario(h, duenio)
