extends SceneTree
## CAPTURAS de la capa de `jugadora_base` con la CÁMARA DEL JUEGO (ortogonal, inclinación 60° desde la vertical, tamaño 6, como la de los niveles y
## herramientas/captura_jugadora_integrada.gd), con los muelles de la capa (CapaMuelles3D) en marcha: los clips se REPRODUCEN (no se congelan) para que la
## capa caiga y se meza. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_capa_juego.gd -- [<carpeta>]
## Escribe en <carpeta> (por omisión docs/capturas/jugadora_base) con prefijo `juego_` (cada una con su recorte ampliado ×3, `_cerca`): idle y andar a mitad de paso de frente, de lado y de espaldas; correr al
## 20, 50 y 80 %, lanzar (cast_proyectil) y rodar (roll) de tres cuartos; y `juego_run_tira.png`, 6 fotogramas de correr en una sola imagen.

const ALTO_JUEGO: float = 1.0
## La del juego (PruebaTest2._colocar_camara): INCLINACION 60° desde la vertical = 30° bajo la horizontal; foco a 0,85 del alto.
const CAMARA_PICADO: float = 30.0
const FOCO_ALTO: float = 0.85
const CAMARA_TAM: float = 6.0
const RESOLUCION: Vector2i = Vector2i(1280, 720)
## Recorte alrededor del personaje para la tira de correr (píxeles) y cuántos fotogramas lleva.
const RECORTE: Vector2i = Vector2i(220, 240)
const TIRA_FOTOS: int = 6
const TIRA_RECORTE: Vector2i = Vector2i(120, 150)
## Aumento de los recortes `_cerca`.
const AMPLIA: int = 3
const VISTAS: Dictionary = {"frente": 0.0, "lado": 90.0, "espalda": 180.0, "tres_cuartos": 40.0}
const ASENTAR_S: float = 1.0

var _carpeta: String = ""
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/jugadora_base"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	root.size = RESOLUCION
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.68, 0.45)
	suelo.material_override = sm
	raiz.add_child(suelo)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAMARA_TAM
	raiz.add_child(_cam)
	_cam.current = true
	var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PICADO)), -cos(deg_to_rad(CAMARA_PICADO)))
	var foco := Vector3(0, ALTO_JUEGO * FOCO_ALTO, 0)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(ALTO_JUEGO)
	for i in 10:
		await process_frame
	if pj._arbol != null:
		pj._arbol.active = false
	for rol in ["idle", "walk"]:
		for v in VISTAS:
			if v == "tres_cuartos":
				continue
			pj.rotation_degrees.y = float(VISTAS[v])
			await _clip_hasta(pj, rol, 0.5)
			await _foto("juego_%s_%s.png" % [rol, v])
	pj.rotation_degrees.y = float(VISTAS["tres_cuartos"])
	for f in [0.2, 0.5, 0.8]:
		await _clip_hasta(pj, "run", f)
		await _foto("juego_run_%d.png" % int(f * 100.0))
	for rol in ["cast_proyectil", "roll"]:
		await _clip_hasta(pj, rol, 0.5)
		await _foto("juego_%s.png" % rol)
	# tira de correr: 6 fotogramas seguidos de una misma carrera
	pj.rotation_degrees.y = float(VISTAS["lado"])
	var tira: Image = null
	await _clip_hasta(pj, "run", 0.0)
	var largo: float = pj._ap.get_animation(pj.clip_de("run")).length
	for k in TIRA_FOTOS:
		while pj._ap.current_animation_position < largo * float(k) / TIRA_FOTOS:
			await process_frame
		var img: Image = await _imagen()
		var trozo: Image = img.get_region(Rect2i(_a_pantalla(Vector3(0, ALTO_JUEGO * 0.5, 0)) - TIRA_RECORTE / 2, TIRA_RECORTE))
		trozo.resize(TIRA_RECORTE.x * AMPLIA, TIRA_RECORTE.y * AMPLIA, Image.INTERPOLATE_LANCZOS)
		if tira == null:
			tira = Image.create(TIRA_RECORTE.x * AMPLIA * TIRA_FOTOS, TIRA_RECORTE.y * AMPLIA, false, trozo.get_format())
		tira.blit_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), Vector2i(TIRA_RECORTE.x * AMPLIA * k, 0))
	tira.save_png(ProjectSettings.globalize_path(_carpeta + "/juego_run_tira.png"))
	print("captura juego_run_tira.png")
	quit(0)


## Reproduce el clip del rol desde el principio (con los muelles en marcha) hasta `fraccion` de su duración; para idle deja antes ASENTAR_S de idle.
func _clip_hasta(pj: Pj3D, rol: String, fraccion: float) -> void:
	var clip: String = pj.clip_de(rol)
	pj._ap.active = true
	if rol == "idle":
		pj._ap.play(clip)
		for i in int(ASENTAR_S * 30.0):
			await process_frame
	pj._ap.play(clip)
	pj._ap.seek(0.0, true)
	var m: CapaMuelles3D = Ropa3D.muelles(pj, "capa")
	if m != null and rol != "idle":
		m.reset()
	var hasta: float = pj._ap.get_animation(clip).length * fraccion
	while pj._ap.current_animation_position < hasta and pj._ap.is_playing():
		await process_frame


func _a_pantalla(p: Vector3) -> Vector2i:
	return Vector2i(_cam.unproject_position(p))


func _imagen() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _foto(nombre: String) -> void:
	var img: Image = await _imagen()
	img.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre))
	# y un recorte ampliado (la cámara del juego deja a la jugadora en ~120 píxeles de alto): `_cerca`
	var c: Vector2i = _a_pantalla(Vector3(0, ALTO_JUEGO * 0.5, 0))
	var rec: Image = img.get_region(Rect2i(c - RECORTE / 2, RECORTE))
	rec.resize(RECORTE.x * AMPLIA, RECORTE.y * AMPLIA, Image.INTERPOLATE_LANCZOS)
	rec.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre.replace(".png", "_cerca.png")))
	print("captura ", nombre)
