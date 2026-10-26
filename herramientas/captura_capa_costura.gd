extends SceneTree
## CAPTURAS DE CERCA DE LA CABEZA: la costura capucha–capa y la cara (26/10, Pablo: «hay una textura rota ahí» · «también una textura rota en la cara»).
## `jugadora_base` vestida como en el juego (Pj3D + Ropa3D, muelles en marcha, clips REPRODUCIÉNDOSE), con la cámara cerca de la cabeza. Por rol y vista, una
## TIRA de FOTOS fotogramas repartidos por el clip. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_capa_costura.gd -- <prefijo> [<carpeta>] [<roles,>] [<modo>] [<vistas,>]
## <modo>: «vestida» (por omisión), «sin_capa» / «sin_capucha_malla» (la malla oculta, las zonas del cuerpo como con ella puesta: se ve lo que hay detrás de la
## costura) o «sin_capucha» (la capucha quitada de verdad: el pelo y las orejas vuelven). Escribe <carpeta>/<prefijo>_<modo>_<rol>_<vista>.png
## (por omisión docs/capturas/capa_costura).

const ALTO_JUEGO: float = 1.0
const RESOLUCION: Vector2i = Vector2i(1280, 720)
const ROLES: Array = ["walk", "run"]
const FOTOS: Array = [0.12, 0.37, 0.62, 0.87]
const ASENTAR_S: float = 1.0
## Vistas: [ángulo alrededor del eje vertical desde delante (+Z), perspectiva?]. «lado» = desde +X; «detras» = 3/4 trasero (la nuca y detrás de la oreja).
const VISTAS: Dictionary = {"frente": [0.0, true], "tres_cuartos": [40.0, true], "lado": [90.0, true], "detras": [140.0, true], "juego": [180.0, false]}
## Cámara de cerca: a CAM_DIST de la cabeza con un FOV estrecho.
const CAM_DIST: float = 1.4
const CAM_FOV: float = 22.0
const CAMARA_PICADO: float = 30.0
const CAMARA_TAM: float = 6.0
## Recorte (píxeles) alrededor de la cabeza y aumento del de la cámara del juego (allí la cabeza mide ~40 px).
const RECORTE_CERCA: Vector2i = Vector2i(420, 420)
const RECORTE_JUEGO: Vector2i = Vector2i(70, 70)
const AMPLIA_JUEGO: int = 6

var _carpeta: String = ""
var _cam: Camera3D = null
var _pj: Pj3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var prefijo: String = a[0] if a.size() > 0 else "captura"
	_carpeta = a[1] if a.size() > 1 else "res://docs/capturas/capa_costura"
	var roles: Array = ROLES
	if a.size() > 2 and a[2] != "":
		roles = Array(a[2].split(","))
	var modo: String = a[3] if a.size() > 3 else "vestida"
	var vistas: Array = VISTAS.keys()
	if a.size() > 4 and a[4] != "":
		vistas = Array(a[4].split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	root.size = RESOLUCION
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.2, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 60, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.45, 0.47, 0.52)
	suelo.material_override = sm
	raiz.add_child(suelo)
	_cam = Camera3D.new()
	raiz.add_child(_cam)
	_cam.current = true
	_pj = Pj3D.new()
	raiz.add_child(_pj)
	_pj.cargar("jugadora_base")
	_pj.set_alto(ALTO_JUEGO)
	for i in 10:
		await process_frame
	if _pj._arbol != null:
		_pj._arbol.active = false
	match modo:
		"sin_capa":
			_ocultar_malla("capa")
		"sin_capucha_malla":
			_ocultar_malla("capucha")
		"sin_capucha":
			_pj.quitar_ropa("capucha")
	for rol in roles:
		var clip: String = _pj.clip_de(String(rol))
		if clip == "":
			print("sin clip para ", rol)
			continue
		for v in vistas:
			if not VISTAS.has(v):
				continue
			await _arrancar(String(rol))
			var tira: Image = null
			var largo: float = _pj._ap.get_animation(clip).length
			for k in FOTOS.size():
				while _pj._ap.current_animation_position < largo * float(FOTOS[k]) and _pj._ap.is_playing():
					await process_frame
				var foco: Vector3 = _cabeza()
				_poner_camara(String(v), foco)
				# un fotograma con la cámara ya puesta (la pose no cambia: se mira el mismo instante)
				var trozo: Image = await _recorte(bool(VISTAS[v][1]), foco)
				if tira == null:
					tira = Image.create(trozo.get_width() * FOTOS.size(), trozo.get_height(), false, trozo.get_format())
				tira.blit_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), Vector2i(trozo.get_width() * k, 0))
			var nombre: String = "%s_%s_%s_%s.png" % [prefijo, modo, rol, v]
			tira.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre))
			print("captura ", nombre)
	quit(0)


func _ocultar_malla(id: String) -> void:
	var mi: MeshInstance3D = Ropa3D.puesta(_pj._modelo, id)
	if mi != null:
		mi.visible = false


## Posición global del hueso Head (el centro de la cara queda algo por encima).
func _cabeza() -> Vector3:
	var sk: Skeleton3D = _pj._modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var b: int = sk.find_bone("mixamorig_Head")
	return (sk.global_transform * sk.get_bone_global_pose(b)).origin + Vector3(0, 0.07, 0)


func _poner_camara(v: String, foco: Vector3) -> void:
	var ang: float = deg_to_rad(float(VISTAS[v][0]))
	if bool(VISTAS[v][1]):
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = CAM_FOV
		var pos := foco + Vector3(sin(ang) * CAM_DIST, 0.12, cos(ang) * CAM_DIST)
		_cam.transform = Transform3D(Basis.looking_at(foco - pos, Vector3.UP), pos)
	else:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = CAMARA_TAM
		var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PICADO)), -cos(deg_to_rad(CAMARA_PICADO))).rotated(Vector3.UP, ang + PI)
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


func _arrancar(rol: String) -> void:
	var clip: String = _pj.clip_de(rol)
	_pj._ap.active = true
	_pj._ap.play(clip)
	for i in int(ASENTAR_S * 30.0):
		await process_frame
	_pj._ap.play(clip)
	_pj._ap.seek(0.0, true)


func _recorte(persp: bool, foco: Vector3) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var c := Vector2i(_cam.unproject_position(foco))
	var r: Vector2i = RECORTE_CERCA if persp else RECORTE_JUEGO
	var rect := Rect2i(c - r / 2, r).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var rec: Image = img.get_region(rect)
	if not persp:
		rec.resize(r.x * AMPLIA_JUEGO, r.y * AMPLIA_JUEGO, Image.INTERPOLATE_NEAREST)
	elif rec.get_size() != r:
		rec.resize(r.x, r.y)
	return rec
