extends SceneTree

## CAPTURA DEL LIBRO AVANZADO (6/11, Juego). CON ventana (hace falta renderizar):
##   tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --script res://herramientas/captura_libro_avanzado.gd
## Carga el laboratorio LabLibroAvanzado, espera a que el libro esté abierto y guarda
## docs/capturas/libro_avanzado/lab.png. Para mirar la distribución sin abrir el editor.

const RUTA: String = "res://docs/capturas/libro_avanzado/lab.png"


func _init() -> void:
	var escena: PackedScene = load("res://laboratorios/LabLibroAvanzado.tscn")
	root.add_child(escena.instantiate())
	# Varios fotogramas: el libro abre con animación y la lámina tarda en cargar.
	for i in range(60):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/capturas/libro_avanzado"))
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: int = img.save_png(RUTA)
	print("captura %s -> %s (%dx%d)" % [("guardada" if err == OK else "ERROR %d" % err), RUTA, img.get_width(), img.get_height()])
	quit(0)
