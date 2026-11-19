extends SceneTree
## Reduce una imagen a un tamaño cuadrado y la guarda (png o jpg según la extensión del destino).
##   godot --headless --path . --script res://herramientas/reducir_textura.gd -- <origen> <destino> <lado>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var lado := int(a[2])
	img.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
	var err := img.save_jpg(a[1], 0.9) if a[1].ends_with(".jpg") else img.save_png(a[1])
	print("guardado %s (%d)" % [a[1], err])
	quit()
