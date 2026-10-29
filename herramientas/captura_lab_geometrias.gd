extends "res://herramientas/escenario_lab_geometrias.gd"
## FOTOS DEL LABORATORIO DE GEOMETRÍAS (29/10): los ocho carriles lanzados a la vez con cada elemento. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_lab_geometrias.gd -- [carpeta]   (por defecto res://docs/capturas/lab_geometrias)

var _dir: String = "res://docs/capturas/lab_geometrias"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	await avanzar(5)
	if lab == null:
		return
	for e in ["fire", "water", "earth"]:
		lab.call("poner_elemento", e)
		_tecla_lab(KEY_SPACE)
		await avanzar_s(0.6)
		await _foto(e)
		_tecla_lab(KEY_BACKSPACE)
		await avanzar_s(0.5)
	# De cerca: la tierra ancha y el muro, para ver el perfil de los bloques (29/10).
	lab.call("poner_elemento", "earth")
	colocar_jugador(Vector2i(6, 10))
	for pal in maqueta.find_children("*", "RunePalette", true, false):
		(pal as CanvasItem).visible = false
	maqueta.set("_tam_camara", 12.0)
	(maqueta.get("_camara") as Camera3D).size = 12.0
	await avanzar_s(0.5)
	_tecla_lab(KEY_SPACE)
	await avanzar_s(1.5)
	await _foto("earth_cerca")
	print("FOTOS en %s" % ProjectSettings.globalize_path(_dir))


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nombre])
