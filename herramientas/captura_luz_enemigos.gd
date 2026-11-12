extends SceneTree
## LÁMINA DE ENEMIGOS CON LUZ PLANA Y LUZ SUAVE (12/11, Pablo: «enséñame una lámina de los enemigos con luz plana vs luz suave», tras dejar a la jugadora en
## luz plana, diario 481). Cada enemigo (ENEMIGOS, los que tengan .glb) en reposo, de tres cuartos, dos veces: `Pj3D.set_modo_luz(0)` (plana: sin sombreado ni rim)
## y `set_modo_luz(1)` (suave: sombreado por píxel, como van hoy enemigos y NPC). Una columna por enemigo, dos filas, con sus rótulos. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_luz_enemigos.gd -- docs/capturas/luz_enemigos

const ENEMIGOS: Array = ["goblin_warrior_chibi", "goblin_archer_chibi", "goblin_asesino", "goblin_chaman", "loberno", "canouro", "elemental_bosque", "golem"]
const CELDA: Vector2i = Vector2i(200, 270)
const ALTO: float = 1.0
var _dir: String = "docs/capturas/luz_enemigos"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	var ids: Array = []
	for id in ENEMIGOS:
		if ResourceLoader.exists("res://arte/modelos/%s.glb" % Pj3D.glb_de(String(id))):
			ids.append(String(id))
	var ancho: int = 24 + ids.size() * (CELDA.x + 12)
	var alto: int = 60 + 2 * (CELDA.y + 34)
	root.get_window().size = Vector2i(maxi(ancho, 640), alto)
	var fondo := ColorRect.new()
	fondo.color = Color("5b7a4a")
	fondo.size = Vector2(ancho, alto)
	root.add_child(fondo)
	# El visor 3D con el que se fotografía cada celda
	var sv := SubViewport.new()
	sv.size = CELDA
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6f8f5e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.92)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	sol.light_energy = 1.1
	sv.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.45
	sv.add_child(cam)
	var dir := Vector3(-0.5, -0.32, -1.0).normalized()
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0.0, 0.5, 0.0) - dir * 12.0)
	var f: Font = TemaInterfaz.fuente()
	var titulo := Label.new()
	titulo.text = "Enemigos: luz plana (modo 0, arriba) y luz suave (modo 1, abajo)"
	titulo.position = Vector2(24.0, 14.0)
	titulo.add_theme_font_override("font", f)
	titulo.add_theme_font_size_override("font_size", 20)
	root.add_child(titulo)
	for i in ids.size():
		var id: String = ids[i]
		var pj := Pj3D.new()
		sv.add_child(pj)
		if not pj.cargar(id):
			pj.queue_free()
			continue
		pj.set_alto(ALTO)
		for fila in 2:
			pj.set_modo_luz(fila)
			for _k in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = sv.get_texture().get_image()
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = Vector2(24.0 + i * (CELDA.x + 12), 52.0 + fila * (CELDA.y + 34))
			root.add_child(tr)
			var l := Label.new()
			l.text = "%s · %s" % [id, "plana" if fila == 0 else "suave"]
			l.position = tr.position + Vector2(0.0, CELDA.y + 4.0)
			l.add_theme_font_override("font", f)
			l.add_theme_font_size_override("font_size", 13)
			root.add_child(l)
		pj.queue_free()
		await process_frame
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for _k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var ruta: String = _dir.path_join("lamina_luz_enemigos.png")
	root.get_texture().get_image().save_png(ruta)
	print("captura: ", ruta)
	quit()
