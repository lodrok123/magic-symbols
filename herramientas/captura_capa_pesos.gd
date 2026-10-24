extends SceneTree
## CAPTURAS DE LA CAPA PARA REVISAR SUS PESOS (25/10, Pablo: «Revisa la capa. Los pesos están mal. No funciona en ninguna animación, ni idle ni walking»; su
## vídeo es la vista de lado del laboratorio). `jugadora_base` vestida como en el juego (Pj3D + Ropa3D, muelles de la capa en marcha, clips REPRODUCIÉNDOSE), en
## tres vistas: `lado` (perspectiva, como el vídeo: mira a la izquierda), `tres_cuartos` (perspectiva, 40° desde delante) y `juego` (la cámara del juego:
## ortogonal, 30° bajo la horizontal, tamaño 6, recorte ×3). Por rol y vista, una TIRA de FOTOS fotogramas repartidos por el clip. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_capa_pesos.gd -- <prefijo> [<carpeta>] [<roles separados por comas>]
## Escribe <carpeta>/<prefijo>_<rol>_<vista>.png (por omisión docs/capturas/capa_pesos). <prefijo>: «antes» / «despues».

const ALTO_JUEGO: float = 1.0
const RESOLUCION: Vector2i = Vector2i(1280, 720)
const ROLES: Array = ["idle", "walk", "run", "cast_proyectil", "abrir_cofre"]
## Fracciones del clip de cada foto de la tira (el idle se deja asentar antes ASENTAR_S).
const FOTOS: Array = [0.12, 0.37, 0.62, 0.87]
const ASENTAR_S: float = 1.0
## Vistas: [ángulo de la cámara alrededor del eje vertical desde delante (+Z), perspectiva?]. «lado» = desde +X: la jugadora mira a la izquierda de la imagen.
const VISTAS: Dictionary = {"lado": [90.0, true], "tres_cuartos": [40.0, true], "juego": [180.0, false]}
const CAM_DIST: float = 3.2
const CAM_FOV: float = 26.0
const CAM_ALTO: float = 0.8
const CAMARA_PICADO: float = 30.0
const CAMARA_TAM: float = 6.0
## Recorte de cada foto (píxeles) y aumento del de la cámara del juego.
const RECORTE_PERSP: Vector2i = Vector2i(360, 560)
const RECORTE_JUEGO: Vector2i = Vector2i(120, 170)
const AMPLIA_JUEGO: int = 3

var _carpeta: String = ""
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var prefijo: String = a[0] if a.size() > 0 else "captura"
	_carpeta = a[1] if a.size() > 1 else "res://docs/capturas/capa_pesos"
	var roles: Array = ROLES
	if a.size() > 2:
		roles = Array(a[2].split(","))
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
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(ALTO_JUEGO)
	for i in 10:
		await process_frame
	if pj._arbol != null:
		pj._arbol.active = false
	for rol in roles:
		for v in VISTAS:
			_poner_camara(String(v))
			var tira: Image = null
			var clip: String = pj.clip_de(String(rol))
			if clip == "":
				print("sin clip para ", rol)
				continue
			await _arrancar(pj, String(rol))
			var largo: float = pj._ap.get_animation(clip).length
			for k in FOTOS.size():
				while pj._ap.current_animation_position < largo * float(FOTOS[k]) and pj._ap.is_playing():
					await process_frame
				var trozo: Image = await _recorte(bool(VISTAS[v][1]))
				if tira == null:
					tira = Image.create(trozo.get_width() * FOTOS.size(), trozo.get_height(), false, trozo.get_format())
				tira.blit_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), Vector2i(trozo.get_width() * k, 0))
			var nombre: String = "%s_%s_%s.png" % [prefijo, rol, v]
			tira.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre))
			print("captura ", nombre)
	quit(0)


func _poner_camara(v: String) -> void:
	var ang: float = deg_to_rad(float(VISTAS[v][0]))
	if bool(VISTAS[v][1]):
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = CAM_FOV
		var pos := Vector3(sin(ang) * CAM_DIST, CAM_ALTO, cos(ang) * CAM_DIST)
		_cam.transform = Transform3D(Basis.looking_at(Vector3(0, ALTO_JUEGO * 0.6, 0) - pos, Vector3.UP), pos)
	else:
		# la del juego: mira hacia −Z con 30° de picado (la jugadora, de espaldas a la cámara si mira a −Z; aquí mira a +Z: la vemos de frente)
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = CAMARA_TAM
		var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PICADO)), -cos(deg_to_rad(CAMARA_PICADO))).rotated(Vector3.UP, ang + PI)
		var foco := Vector3(0, ALTO_JUEGO * 0.85, 0)
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


## Reproduce el clip del rol desde el principio con los muelles en marcha; idle se deja asentar antes.
func _arrancar(pj: Pj3D, rol: String) -> void:
	var clip: String = pj.clip_de(rol)
	pj._ap.active = true
	pj._ap.play(clip)
	for i in int(ASENTAR_S * 30.0):
		await process_frame
	pj._ap.play(clip)
	pj._ap.seek(0.0, true)


func _recorte(persp: bool) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var c := Vector2i(_cam.unproject_position(Vector3(0, ALTO_JUEGO * 0.55, 0)))
	var r: Vector2i = RECORTE_PERSP if persp else RECORTE_JUEGO
	var rec: Image = img.get_region(Rect2i(c - r / 2, r))
	if not persp:
		rec.resize(r.x * AMPLIA_JUEGO, r.y * AMPLIA_JUEGO, Image.INTERPOLATE_LANCZOS)
	return rec
