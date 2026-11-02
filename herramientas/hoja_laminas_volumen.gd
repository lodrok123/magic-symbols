extends SceneTree

## Hojas resumen ANTES | DESPUÉS de las capturas de captura_laminas_volumen.gd (una por figura y una general). Sin ventana:
##   godot --headless --path . --script res://herramientas/hoja_laminas_volumen.gd -- docs/capturas/comparativa_vfx/godot_toy/laminas_volumen

const W: int = 560
const H: int = 315
const CAMARAS: Array = ["juego", "az0", "az45", "az90", "cerca"]
const FIGURAS: Array = ["muro", "muro_eje", "pilar", "barrera", "bola", "vuelo"]


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "docs/capturas/comparativa_vfx/godot_toy/laminas_volumen"
	if not dir.is_absolute_path():
		dir = ProjectSettings.globalize_path("res://" + dir)
	for f in FIGURAS:
		var filas: Array = []
		for c in CAMARAS:
			if f == "muro_eje" and c != "juego" and c != "cerca":
				continue
			filas.append("%s_%s" % [f, c])
		_hoja(dir, filas, "hoja_" + f)
	_hoja(dir, ["muro_az90", "muro_az0", "pilar_az90", "pilar_az45", "barrera_az90", "bola_az45", "vuelo_az0", "muro_eje_juego", "muro_juego", "pilar_juego"], "hoja_resumen")
	quit()


func _hoja(dir: String, filas: Array, nombre: String) -> void:
	var hoja: Image = Image.create(W * 2 + 30, (H + 10) * filas.size() + 10, false, Image.FORMAT_RGB8)
	hoja.fill(Color(0.12, 0.12, 0.14))
	for i in filas.size():
		for k in 2:
			var ruta: String = dir.path_join("%s%s.png" % [filas[i], ["_antes", "_despues"][k]])
			if not FileAccess.file_exists(ruta):
				continue
			var im: Image = Image.load_from_file(ruta)
			im.convert(Image.FORMAT_RGB8)
			im.resize(W, H, Image.INTERPOLATE_LANCZOS)
			hoja.blit_rect(im, Rect2i(0, 0, W, H), Vector2i(10 + k * (W + 10), 10 + i * (H + 10)))
	hoja.save_png(dir.path_join(nombre + ".png"))
	print("hoja " + nombre)
