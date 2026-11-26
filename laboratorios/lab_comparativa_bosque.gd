extends Node3D

## LABORATORIO: COMPARATIVA UNREAL / GODOT «bosque con ruinas» (26/11/2026).
## La MISMA escena que el mapa de Unreal /Game/MagicSymbols/MS_PruebaBosque (proyecto E:\ue_proyectos\StylescapeRuins): mismas piezas en el
## mismo sitio (docs/capturas/comparativa_ue_godot/escena.json), mismas texturas (a 2K, sin teñir de beige) y las dos mismas cámaras.
## Así lo único que cambia entre las fotos de Unreal y las de aquí es el motor: la luz, el posproceso y los materiales (que aquí son una
## aproximación de los de Unreal, ver presentacion/fab_ue/: MaterialesUE y sus shaders).
##
## Teclas:  1 cámara del juego (30° sobre el suelo) · 2 cámara de detalle · L cambia la luz:
##            · «unreal»: imitando la de la demo de Meadows (sol, cielo azul, luz rebotada SDFGI, oclusión, bloom, saturación)
##            · «juego»:  la luz y el posproceso de NUESTRO bosque (LuzZona3D «bosque», Posproceso3D, Paleta3D), sin luz rebotada
##          G luz rebotada (SDFGI) sí/no
##          3 MUESTRARIO de todas las piezas Pure Nature (pn_*), un bloque por pack; ← → cambian de pack
## Fotos del muestrario:  Godot --path . res://laboratorios/LabComparativaBosque.tscn -- --muestrario   (muestrario_<pack>.png)
## Captura sin tocar nada:  Godot --path . res://laboratorios/LabComparativaBosque.tscn -- --captura
##   deja docs/capturas/comparativa_ue_godot/godot_<luz>_<cámara>.png, junto a las unreal_<cámara>.png, y comparativa_<cámara>.png (las tres juntas).
## Si no hay mallas: tools/ue_montar_prueba_bosque.py, tools/ue_exportar_prueba_bosque.py y tools/preparar_prueba_bosque.py (no viajan en git).

const RAIZ: String = "res://arte/comparativa_bosque/"
const CAPTURAS: String = "res://docs/capturas/comparativa_ue_godot/"
const CM: float = 0.01

## --- Luz «unreal»: los números salen de la demo de Meadows (sol a -70,8° / -71,9°, posproceso con saturación 1,05, bloom 1,59, luz
## indirecta 0,77, temperatura de blanco 7000 K) y se calibraron a ojo contra unreal_Cam_Juego.png. Unreal usa exposición manual con
## un sol de 0,3 lux y +11 de exposición: no se puede copiar el número, se copia el resultado.
## 1.ª prueba (sol 2,2, ambiente 1,0, ACES a 1,0, saturación 1,08): todo lavado y el suelo casi blanco frente a Unreal.
const UE_SOL_ENERGIA: float = 1.5
const UE_SOL_COLOR: Color = Color(1.0, 0.98, 0.95)
## 3.ª (26/11): con (0,18·0,42·0,95), la saturación 1,2 y ACES, las caras en sombra salían AZUL PURO (depurar: sin ajuste o con cielo
## gris desaparecía). Ahora un azul menos saturado y AgX, que no satura los colores intensos.
const UE_CIELO_ARRIBA: Color = Color(0.30, 0.50, 0.88)
const UE_CIELO_HORIZONTE: Color = Color(0.62, 0.78, 0.98)
const UE_AMBIENTE_ENERGIA: float = 0.7
## 4.ª (26/11): con AgX el suelo bajó a 130·176·91 (Unreal 154·211·95): más exposición y saturación para compensar.
const UE_EXPOSICION: float = 1.08
const UE_SATURACION: float = 1.3
const UE_CONTRASTE: float = 1.1
const UE_BLOOM: float = 0.25
const UE_SDFGI_ENERGIA: float = 1.0

var _escena: Dictionary
var _informe: Dictionary
var _camaras: Array = []
var _cam_actual: int = 0
var _luz: String = "unreal"
var _entorno: Environment
var _sol: DirectionalLight3D
var _hud: Label
var _vineta: CanvasLayer
var _mats: Dictionary = {}
var _traductor: MaterialesUE
var _mallas: Dictionary = {}


func _ready() -> void:
	var ruta_escena: String = RAIZ + "escena.json"
	if not FileAccess.file_exists(ruta_escena):
		push_warning("LabComparativaBosque: falta %s (ver la cabecera del script)" % ruta_escena)
		return
	_escena = JSON.parse_string(FileAccess.get_file_as_string(ruta_escena))
	_informe = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "informe.json"))
	_traductor = MaterialesUE.new(_informe, RAIZ + "texturas/")
	_montar_luz()
	var n: int = 0
	for p in _escena["piezas"]:
		if _poner(p):
			n += 1
	print("LabComparativaBosque: %d de %d piezas" % [n, _escena["piezas"].size()])
	for c in _escena["camaras"]:
		var cam := Camera3D.new()
		cam.name = String(c["nombre"])
		var pos := _a_godot(c["pos"])
		var p: float = deg_to_rad(float(c["pitch"]))
		var y: float = deg_to_rad(float(c["yaw"]))
		var dir_ue := Vector3(cos(p) * cos(y), cos(p) * sin(y), sin(p))
		cam.position = pos
		add_child(cam)
		cam.look_at(pos + Vector3(dir_ue.x, dir_ue.z, dir_ue.y), Vector3.UP)
		cam.keep_aspect = Camera3D.KEEP_WIDTH          # en Unreal el FOV es horizontal
		cam.fov = float(c["fov"])
		cam.far = 400.0
		_camaras.append(cam)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	var capa := CanvasLayer.new()
	add_child(capa)
	capa.add_child(_hud)
	_elegir_camara(0)
	_aplicar_luz()
	if OS.get_cmdline_user_args().has("--captura"):
		_capturar()
	elif OS.get_cmdline_user_args().has("--depurar"):
		_depurar()
	elif OS.get_cmdline_user_args().has("--muestrario"):
		_capturar_muestrario()


## Unreal (cm; X delante, Y derecha, Z arriba; mano izquierda) -> Godot (m; Y arriba; mano derecha): (x, z, y) / 100.
func _a_godot(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[2]), float(v[1])) * CM


func _poner(p: Dictionary) -> bool:
	var ruta: String = p["malla"]
	if not _informe["mallas"].has(ruta):
		return false
	var d: Dictionary = _informe["mallas"][ruta]
	var malla := _malla(String(d["fbx"]))
	if malla.is_empty():
		return false
	var esc: Array = p["escala"]
	var base := Basis(Vector3.UP, -deg_to_rad(float(p["giro"]))) * Basis.from_scale(Vector3(float(esc[0]), float(esc[2]), float(esc[1])))
	var t := Transform3D(base, _a_godot(p["pos"]))
	var pack: String = ruta.split("/")[2] if ruta.begins_with("/Game/") else "Engine"
	for parte in malla:
		var mi := MeshInstance3D.new()
		mi.mesh = parte["mesh"]
		mi.transform = t * (parte["xf"] as Transform3D)
		add_child(mi)
		var aabb: AABB = (mi.mesh as Mesh).get_aabb()
		for s in range(mi.mesh.get_surface_count()):
			var orig: Material = mi.mesh.surface_get_material(s)
			var nombre: String = orig.resource_name if orig != null else ""
			if p.get("material") != null and s == 0:
				nombre = "__suelo__"
			var mat := _material(pack + "__" + nombre, aabb)
			if mat != null:
				mi.set_surface_override_material(s, mat)
	return true


func _malla(fbx: String) -> Array:
	if _mallas.has(fbx):
		return _mallas[fbx]
	var ps: PackedScene = load(RAIZ + "mallas/" + fbx) as PackedScene
	var r: Array = []
	if ps == null:
		push_warning("no se importó " + fbx)
	else:
		var esc: Node = ps.instantiate()
		for mi in esc.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != esc:
				if n is Node3D:
					t = (n as Node3D).transform * t
				n = n.get_parent()
			r.append({"mesh": (mi as MeshInstance3D).mesh, "xf": t})
		esc.free()
	_mallas[fbx] = r
	return r


## El material de Godot para una receta de Unreal: el suelo de la prueba aquí; lo demás, MaterialesUE (presentacion/fab_ue/materiales_ue.gd).
func _material(clave: String, aabb: AABB) -> Material:
	if clave.ends_with("__suelo__"):
		if not _mats.has("suelo"):
			var sm := StandardMaterial3D.new()
			var tx: String = "PureNature_Meadows__T_Grass01_"
			sm.albedo_texture = _traductor.tex(tx + "a")
			sm.normal_enabled = true
			sm.normal_texture = _traductor.tex(tx + "n")
			sm.roughness = float(_escena["suelo"]["rugosidad"])
			var rep: float = float(_escena["suelo"]["repeticion"])
			sm.uv1_scale = Vector3(rep, rep, 1.0)
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_mats["suelo"] = sm
		return _mats["suelo"]
	var mat: Material = _traductor.material(clave, aabb.end.y)
	if mat == null:
		push_warning("material no exportado: " + clave)
	return mat


func _montar_luz() -> void:
	var e := WorldEnvironment.new()
	_entorno = Environment.new()
	e.environment = _entorno
	add_child(e)
	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	add_child(_sol)


func _aplicar_luz() -> void:
	var env := _entorno
	if _vineta != null:
		_vineta.queue_free()
		_vineta = null
	if _luz == "unreal":
		var cielo_mat := ProceduralSkyMaterial.new()
		cielo_mat.sky_top_color = UE_CIELO_ARRIBA
		cielo_mat.sky_horizon_color = UE_CIELO_HORIZONTE
		cielo_mat.ground_horizon_color = UE_CIELO_HORIZONTE
		cielo_mat.ground_bottom_color = Color(0.25, 0.3, 0.2)
		cielo_mat.sun_angle_max = 0.0
		var cielo := Sky.new()
		cielo.sky_material = cielo_mat
		env.sky = cielo
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
		env.ambient_light_energy = UE_AMBIENTE_ENERGIA
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = UE_EXPOSICION
		env.tonemap_white = 6.0
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.5
		env.ssil_enabled = true
		env.sdfgi_enabled = true
		env.sdfgi_energy = UE_SDFGI_ENERGIA
		env.sdfgi_use_occlusion = true
		env.glow_enabled = true
		env.glow_intensity = UE_BLOOM
		env.glow_bloom = 0.05
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = UE_CONTRASTE
		env.adjustment_saturation = UE_SATURACION
		env.fog_enabled = false
		var sol: Dictionary = _escena["luz"]["sol"]
		var p: float = deg_to_rad(float(sol["pitch"]))
		var y: float = deg_to_rad(float(sol["yaw"]))
		var dir_ue := Vector3(cos(p) * cos(y), cos(p) * sin(y), sin(p))
		_sol.basis = Basis.looking_at(Vector3(dir_ue.x, dir_ue.z, dir_ue.y), Vector3.UP if absf(dir_ue.z) < 0.99 else Vector3.FORWARD)
		_sol.light_color = UE_SOL_COLOR
		_sol.light_energy = UE_SOL_ENERGIA
		_sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sol.directional_shadow_max_distance = 80.0
		_sol.shadow_blur = 1.0
		_sol.shadow_opacity = 1.0
	else:
		# Lo mismo que monta el juego en el bosque (ver LabStylescape._montar_luz y Posproceso3D).
		env.sdfgi_enabled = false
		env.ssil_enabled = false
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.80, 0.86, 0.90)
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.0
		Paleta3D.aplicar_ajuste(env)
		LuzZona3D.aplicar(env, _sol, "bosque")
		Posproceso3D.aplicar_entorno(env, get_viewport())
		_vineta = Posproceso3D.montar_vineta(self)
	_actualizar_hud()


func _elegir_camara(i: int) -> void:
	_cam_actual = i
	(_camaras[i] as Camera3D).current = true
	_actualizar_hud()


## --- MUESTRARIO (26/11): todas las piezas pn_* de los packs Pure Nature (herramientas/generar_piezas_pure_nature.gd), un bloque por pack,
## detrás de la escena de la comparativa, con la misma luz. Van a la escala del juego (0,575 u/m): un árbol de 15 m mide 8,6 u.
const MUESTRARIO_PIEZAS: String = "res://arte/pure_nature/"
const MUESTRARIO_Z: float = 45.0         ## dónde empieza (m), pasada la escena de la comparativa
const MUESTRARIO_ANCHO: float = 60.0     ## ancho de cada fila
const MUESTRARIO_HUECO: float = 0.8
var _bloques: Array = []                 ## [{pack, centro: Vector3, ancho, fondo}]
var _bloque: int = -1
var _cam_muestrario: Camera3D
var _disposicion: Array = []             ## lo que se guarda en muestrario.json para montar lo mismo en Unreal (tools/ue_montar_muestrario.py)


func _montar_muestrario() -> bool:
	if not _bloques.is_empty():
		return true
	var ruta: String = MUESTRARIO_PIEZAS + "indice.json"
	if not FileAccess.file_exists(ruta):
		push_warning("no hay piezas Pure Nature (ver herramientas/generar_piezas_pure_nature.gd)")
		return false
	var indice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	var por_pack: Dictionary = {}
	for id in indice:
		var p: String = indice[id]["pack"]
		if not por_pack.has(p):
			por_pack[p] = []
		por_pack[p].append(indice[id])
	var orden_cat: Array = ["arbol", "roca", "adorno", "seta", "planta", "suelo"]
	var z: float = MUESTRARIO_Z
	for pack in por_pack.keys().duplicate().map(func(x): return String(x)):
		var lista: Array = por_pack[pack]
		lista.sort_custom(func(a, b):
			var ca: int = orden_cat.find(a["categoria"])
			var cb: int = orden_cat.find(b["categoria"])
			return ca < cb if ca != cb else float(a["caja"][4]) > float(b["caja"][4]))
		var x: float = 0.0
		var z_fila: float = z
		var fondo_fila: float = 0.0
		var z0: float = z
		for e in lista:
			var c: Array = e["caja"]
			var ancho: float = float(c[3])
			var fondo: float = float(c[5])
			if x > 0.0 and x + ancho > MUESTRARIO_ANCHO:
				x = 0.0
				z_fila += fondo_fila + MUESTRARIO_HUECO
				fondo_fila = 0.0
			var ps: PackedScene = load(MUESTRARIO_PIEZAS + "piezas/" + String(e["id"]) + ".tscn") as PackedScene
			if ps != null:
				var n: Node3D = ps.instantiate()
				n.position = Vector3(x - float(c[0]), 0.0, z_fila - float(c[2]))
				add_child(n)
				_disposicion.append({"id": e["id"], "ruta_ue": e.get("ruta_ue", ""), "pos": [n.position.x, n.position.y, n.position.z]})
			x += ancho + MUESTRARIO_HUECO
			fondo_fila = maxf(fondo_fila, fondo)
		var fondo_total: float = z_fila + fondo_fila - z0
		_bloques.append({"pack": pack, "centro": Vector3(MUESTRARIO_ANCHO * 0.5, 0.0, z0 + fondo_total * 0.5), "ancho": MUESTRARIO_ANCHO, "fondo": fondo_total})
		z = z_fila + fondo_fila + 6.0
	# suelo bajo el muestrario
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(MUESTRARIO_ANCHO + 20.0, z - MUESTRARIO_Z + 20.0)
	suelo.mesh = pl
	suelo.position = Vector3(MUESTRARIO_ANCHO * 0.5, -0.01, (MUESTRARIO_Z + z) * 0.5)
	suelo.material_override = _material("x__suelo__", AABB())
	add_child(suelo)
	_cam_muestrario = Camera3D.new()
	_cam_muestrario.name = "Cam_Muestrario"
	_cam_muestrario.far = 500.0
	_cam_muestrario.fov = 50.0
	_cam_muestrario.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(_cam_muestrario)
	print("muestrario: %d packs, %d piezas" % [_bloques.size(), indice.size()])
	return true


## Pone la cámara del muestrario delante del bloque `i` (un pack), mirando desde 35° por encima.
func _ver_bloque(i: int) -> void:
	if not _montar_muestrario() or _bloques.is_empty():
		return
	_bloque = posmod(i, _bloques.size())
	var b: Dictionary = _bloques[_bloque]
	var centro: Vector3 = b["centro"]
	var dist: float = maxf(float(b["ancho"]), float(b["fondo"]) * 1.6) * 0.95
	var ang: float = deg_to_rad(35.0)
	_cam_muestrario.position = centro + Vector3(0.0, sin(ang) * dist, -cos(ang) * dist)
	_cam_muestrario.look_at(centro, Vector3.UP)
	_cam_muestrario.current = true
	_actualizar_hud()


func _capturar_muestrario() -> void:
	_hud.visible = false
	if not _montar_muestrario():
		get_tree().quit()
		return
	_luz = "unreal"
	_aplicar_luz()
	# 26/11: la disposición y las cámaras, para montar el MISMO muestrario en Unreal y comparar foto con foto (en u del juego; Unreal
	# lo pasa a cm con la escala de las piezas).
	var camaras: Array = []
	for i in range(_bloques.size()):
		_ver_bloque(i)
		var fw: Vector3 = -_cam_muestrario.global_transform.basis.z
		camaras.append({"nombre": "Cam_" + String(_bloques[i]["pack"]).trim_prefix("PureNature_"), "pos": [_cam_muestrario.position.x, _cam_muestrario.position.y, _cam_muestrario.position.z],
			"dir": [fw.x, fw.y, fw.z], "fov": _cam_muestrario.fov})
	var arch := FileAccess.open(CAPTURAS + "muestrario.json", FileAccess.WRITE)
	arch.store_string(JSON.stringify({"escala": 0.575, "piezas": _disposicion, "camaras": camaras}, " "))
	arch.close()
	for i in range(_bloques.size()):
		_ver_bloque(i)
		for f in range(120):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var archivo: String = "muestrario_%s.png" % String(_bloques[i]["pack"]).trim_prefix("PureNature_").to_lower()
		get_viewport().get_texture().get_image().save_png(CAPTURAS + archivo)
		print("captura ", archivo)
	get_tree().quit()


func _actualizar_hud() -> void:
	if _hud == null:
		return
	var donde: String = (_camaras[_cam_actual] as Camera3D).name if not _camaras.is_empty() else "-"
	if _cam_muestrario != null and _cam_muestrario.current and _bloque >= 0:
		donde = "muestrario %s (3 / ← →)" % String(_bloques[_bloque]["pack"]).trim_prefix("PureNature_")
	_hud.text = "Comparativa Unreal / Godot · %s · cámaras 1/2 · muestrario 3 · luz «%s» (L) · luz rebotada %s (G)" % [
		donde, _luz, "sí" if _entorno.sdfgi_enabled else "no"]


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match (ev as InputEventKey).keycode:
		KEY_1:
			_elegir_camara(0)
		KEY_2:
			_elegir_camara(min(1, _camaras.size() - 1))
		KEY_3:
			_ver_bloque(max(_bloque, 0))
		KEY_RIGHT:
			if _bloque >= 0:
				_ver_bloque(_bloque + 1)
		KEY_LEFT:
			if _bloque >= 0:
				_ver_bloque(_bloque - 1)
		KEY_L:
			_luz = "juego" if _luz == "unreal" else "unreal"
			_aplicar_luz()
		KEY_G:
			_entorno.sdfgi_enabled = not _entorno.sdfgi_enabled
			_actualizar_hud()


func _capturar() -> void:
	_hud.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURAS))
	for luz in ["unreal", "juego"]:
		_luz = luz
		_aplicar_luz()
		for i in range(_camaras.size()):
			_elegir_camara(i)
			for f in range(90):                     # SDFGI y la exposición se asientan
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(CAPTURAS + "godot_%s_%s.png" % [luz, (_camaras[i] as Camera3D).name])
			print("captura godot_%s_%s.png" % [luz, (_camaras[i] as Camera3D).name])
	_montar_comparativas()
	get_tree().quit()


## Depuración (`-- --depurar`): la cámara de detalle con la luz «unreal», apagando cada vez una cosa, para ver de dónde sale un fallo.
## Deja docs/capturas/comparativa_ue_godot/depurar_<variante>.png
func _depurar() -> void:
	_hud.visible = false
	_luz = "unreal"
	_aplicar_luz()
	_elegir_camara(0)
	# 26/11, 3.ª tanda: manchas azul puro en los costados en sombra de los pilares (vista del juego); se prueba qué lo causa.
	var variantes: Array = ["base", "sin_sdfgi", "sin_ssil", "sin_ssao", "sin_ajuste", "cielo_gris"]
	for v in variantes:
		_aplicar_luz()
		_entorno.sdfgi_enabled = v != "sin_sdfgi"
		_entorno.ssil_enabled = v != "sin_ssil"
		_entorno.ssao_enabled = v != "sin_ssao"
		_entorno.adjustment_enabled = v != "sin_ajuste"
		if v == "cielo_gris":
			var cm := _entorno.sky.sky_material as ProceduralSkyMaterial
			cm.sky_top_color = Color(0.6, 0.6, 0.6)
			cm.sky_horizon_color = Color(0.7, 0.7, 0.7)
		for f in range(90):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(CAPTURAS + "depurar_%s.png" % v)
		print("depurar ", v)
	get_tree().quit()


## Une en una sola imagen, por cámara: Unreal | Godot imitando Unreal | Godot con la luz del juego, con su rótulo.
func _montar_comparativas() -> void:
	for c in _camaras:
		var n: String = (c as Camera3D).name
		var piezas: Array = []
		for archivo in ["unreal_%s.png" % n, "godot_unreal_%s.png" % n, "godot_juego_%s.png" % n]:
			var ruta: String = ProjectSettings.globalize_path(CAPTURAS + archivo)
			if FileAccess.file_exists(ruta):
				var im := Image.load_from_file(ruta)
				im.convert(Image.FORMAT_RGB8)
				im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
				piezas.append(im)
		if piezas.size() < 3:
			continue
		var total := Image.create(960 * 3, 540, false, Image.FORMAT_RGB8)
		for i in range(3):
			total.blit_rect(piezas[i], Rect2i(0, 0, 960, 540), Vector2i(960 * i, 0))
		total.save_png(CAPTURAS + "comparativa_%s.png" % n)
		print("captura comparativa_%s.png" % n)
