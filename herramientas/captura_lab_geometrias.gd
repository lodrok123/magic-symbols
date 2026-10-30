extends "res://herramientas/escenario_lab_geometrias.gd"
## FOTOS DEL LABORATORIO DE GEOMETRÍAS (29/10; 30/10 con los quince carriles y sus dianas): lanzados a la vez con cada elemento. NECESITA VENTANA:
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
	for pal in maqueta.find_children("*", "PanelContainer", true, false):
		if pal.get_script() != null and String((pal.get_script() as Script).resource_path).ends_with("rune_palette.gd"):
			(pal as CanvasItem).visible = false          # la paleta de pruebas (F1)
	# 30/10: los quince carriles (base + 1 glifo) con sus dianas, sin panel y con ᛁ ×2 en la base.
	for e in ["fire", "water", "earth"]:
		lab.call("poner_elemento", e)
		_tecla_lab(KEY_SPACE)
		await avanzar_s(0.8)
		await _foto(e)
		_tecla_lab(KEY_BACKSPACE)
		await avanzar_s(0.5)
	lab.call("poner_elemento", "fire")
	lab.call("sumar", "linea_x", 2)
	_tecla_lab(KEY_SPACE)
	await avanzar_s(0.8)
	await _foto("fire_base_x2")
	print("FOTOS en %s" % ProjectSettings.globalize_path(_dir))


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nombre])
