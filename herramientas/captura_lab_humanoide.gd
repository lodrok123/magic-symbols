extends SceneTree
## CAPTURAS del laboratorio de humanoides (laboratorios/LabHumanoide3D.tscn) con jugadora_base «como el juego»: idle y run, con la cámara del juego (5) y de lado (1),
## con el panel a la vista. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_lab_humanoide.gd -- [<carpeta>]
## Escribe en <carpeta> (por omisión docs/capturas/jugadora_base) lab_humanoide_<rol>_<cámara>.png.

const RESOLUCION: Vector2i = Vector2i(1280, 720)
const ASENTAR_S: float = 1.2         ## tiempo de reproducción real antes de cada foto (los muelles de la capa tienen que caer)
const TOMAS: Array = [["idle", "juego", 4], ["idle", "lado", 0], ["run", "juego", 4], ["run", "lado", 0]]   ## [rol, nombre de la toma, índice de cámara del lab]

var _carpeta: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/jugadora_base"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	root.size = RESOLUCION
	Estado.nuevo()
	await process_frame
	var lab: Node = (load("res://laboratorios/LabHumanoide3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _i in 10:
		await process_frame
	for t in TOMAS:
		var clip: String = lab._pj.clip_de(String(t[0]))
		lab._elegir_clip(clip)
		lab._camara_preset(int(t[2]))
		var t0: int = Time.get_ticks_msec()
		while float(Time.get_ticks_msec() - t0) < ASENTAR_S * 1000.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		var nombre: String = "lab_humanoide_%s_%s.png" % [t[0], t[1]]
		img.save_png(ProjectSettings.globalize_path(_carpeta + "/" + nombre))
		print("captura ", nombre)
	quit(0)
