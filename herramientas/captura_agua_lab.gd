extends SceneTree
## CAPTURAS del agua del LAB (cascada de la escalera del manantial y río de abajo), 3 fotogramas seguidos de cada una: la legibilidad del MOVIMIENTO (22/10). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_agua_lab.gd -- <carpeta> <etiqueta> [uniform=valor,...]
const S: float = 2.3
const ESPERA_S: float = 10.0          ## segundos reales de simulación antes de la primera foto (el manantial ya ha bajado la escalera)
const FOTOGRAMAS: int = 3
const SEPARACION: float = 0.35
const ALTURA_CAMARA: float = 30.0
const RETRANQUEO_CAMARA: float = 22.0
## nombre, casilla (puede ser fraccionaria), tamaño de la cámara ortogonal
const VISTAS: Array = [["cascada", Vector2(3.0, 2.0), 9.0], ["rio", Vector2(5.5, 8.0), 9.0]]


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		push_error("uso: -- <carpeta> <etiqueta> [uniform=valor,...]")
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab: Node3D = (load("res://laboratorios/LabAgua3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	DirAccess.make_dir_recursive_absolute(a[0])
	for _i in 5:
		await process_frame          # el _ready del lab (que crea el dibujo del agua) corre en el primer fotograma
	if a.size() > 2 and a[2] != "-":
		var mat: ShaderMaterial = (lab.get("_render") as AguaRender3D).material_agua()
		for par in String(a[2]).split(","):
			var kv: PackedStringArray = par.split("=")
			mat.set_shader_parameter(kv[0], float(kv[1]))
	(lab.get("_texto") as Label).visible = false          # el texto de la maqueta tapa la imagen
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < ESPERA_S * 1000.0:
		await process_frame
	var cam: Camera3D = lab.get("_camara")
	for v in VISTAS:
		var c: Vector2 = v[1]
		var foco := Vector3(c.x * S, 0.0, c.y * S)
		cam.size = float(v[2])
		cam.look_at_from_position(foco + Vector3(0.0, ALTURA_CAMARA, RETRANQUEO_CAMARA), foco)
		for _i in 10:
			await process_frame
		for f in FOTOGRAMAS:
			await RenderingServer.frame_post_draw
			var ruta: String = "%s/lab_%s_%s_f%d.png" % [a[0], v[0], a[1], f]
			root.get_viewport().get_texture().get_image().save_png(ruta)
			print("FOTO %s" % ruta.get_file())
			var t1: int = Time.get_ticks_msec()
			while float(Time.get_ticks_msec() - t1) < SEPARACION * 1000.0:
				await process_frame
	quit()
