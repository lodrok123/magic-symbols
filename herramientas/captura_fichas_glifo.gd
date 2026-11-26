extends SceneTree
## FOTOS DE LA FICHA DE GLIFO (23/11, sesión HECHIZOS). Con ventana (el render hace falta):
##   godot --path . --script res://herramientas/captura_fichas_glifo.gd -- <carpeta>
## Dibuja `LaminaGlifo` (la ficha corta, con la frase ya escrita entera) en un SubViewport de 1920×1080 (el tamaño no depende de la ventana) y guarda un PNG por runa.

const IDS: Array = ["flecha", "barrera", "raido", "fuego", "agua", "altura", "viento", "linea", "permanencia", "retardo"]
const MOMENTOS: Array = [0.0]


func _initialize() -> void:
	var dir: String = ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
		DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var fondo := ColorRect.new()
	fondo.color = Color(0.30, 0.33, 0.37)
	fondo.size = Vector2(1920, 1080)
	vp.add_child(fondo)
	for id in IDS:
		for t in MOMENTOS:
			var l: LaminaGlifo = LaminaGlifo.mostrar(vp, String(id), true, false)
			await process_frame
			l.fijar_tiempo(float(t))
			for _i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var nombre: String = String(id)
			if dir != "":
				vp.get_texture().get_image().save_png(dir.path_join(nombre + ".png"))
			print("CAPTURA ", nombre)
			l.free()
	quit(0)
