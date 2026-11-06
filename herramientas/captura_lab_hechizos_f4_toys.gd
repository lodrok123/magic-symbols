extends SceneTree
## Captura de la pestaña F4 del laboratorio de hechizos con el HUD de los toys (6/11): abre LabHechizos3D, pasa a F4, elige la fila de un derivado, lanza su celda base por el
## camino real y guarda una foto a los 0,6 s. Necesita ventana (no vale --headless):
##   & "E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe" --path E:\magic-symbols --script res://herramientas/captura_lab_hechizos_f4_toys.gd -- docs/capturas/lab_hechizos_f4_toys [fila=magma]

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"


func _init() -> void:
	_correr()


func _tecla(lab: Node, k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	lab._unhandled_input(ev)


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "docs/capturas/lab_hechizos_f4_toys"
	var fila: String = a[1] if a.size() > 1 else "magma"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + carpeta))
	root.size = Vector2i(1600, 900)
	LabHechizos3D.cargar_al_abrir = false
	var maqueta: Node = (load(RUTA_LAB) as PackedScene).instantiate()
	root.add_child(maqueta)
	var n: int = 0
	while n < 600 and get_first_node_in_group("spellcaster") == null:
		await process_frame
		n += 1
	var jugador: Object = get_first_node_in_group("spellcaster").get("jugador")
	var pared: int = Time.get_ticks_msec()
	while jugador != null and not bool(jugador.call("puede_lanzar")) and Time.get_ticks_msec() - pared < 30000:
		await process_frame
	for _i in range(30):
		await process_frame
	var lab: Node = maqueta.get_node_or_null("Reglas")
	if lab == null:
		print("FALLO: no hay lab")
		quit(1)
		return
	_tecla(lab, KEY_F4)
	var vfx: LabVfx3D = lab.get("f4") as LabVfx3D
	for i in range(LabVfx3D.ESTADOS.size()):
		if String(LabVfx3D.ESTADOS[i][0]) == fila:
			vfx.poner(i, 0, 0, 0)       # la celda base: esfera, ninguna, suelo
	_tecla(lab, KEY_SPACE)
	await create_timer(0.3).timeout
	var img: Image = root.get_texture().get_image()
	var ruta: String = ProjectSettings.globalize_path("res://%s/f4_%s.png" % [carpeta, fila])
	img.save_png(ruta)
	print("guardada ", ruta, " ", img.get_size())
	print(lab.call("texto_hud"))
	quit(0)
