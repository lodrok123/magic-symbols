extends SceneTree

## Hojas de contraste del haz y la barrera (antes / después / referencia). godot --headless --path . --script res://herramientas/hoja_haz_barrera.gd

const D: String = "res://docs/capturas/comparativa_vfx/godot_toy/haz_barrera/"
const R: String = "res://docs/capturas/comparativa_vfx/referencia_toy/"


func _initialize() -> void:
	_hoja("hoja_haz", [["haz_lado_antes", "haz_juego_antes", "haz_cerca_antes"], ["haz_lado_despues", "haz_juego_despues", "haz_cerca_despues"]], [R + "ref_haz_video_a.png"],
		[D + "seq_haz/antes_%02d.png", D + "seq_haz/despues_%02d.png"])
	_hoja("hoja_barrera", [["barrera_juego_antes", "barrera_cerca_antes", "barrera_frente_antes"], ["barrera_juego_despues", "barrera_cerca_despues", "barrera_frente_despues"]],
		[R + "ref_barrera_video_a.png", R + "ref_barrera_video_b.png"], [D + "seq_barrera/antes_%02d.png", D + "seq_barrera/despues_%02d.png"])
	quit()


func _cargar(ruta: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(ruta))


func _hoja(nombre: String, filas: Array, refs: Array, seqs: Array) -> void:
	var w: int = 960
	var celdas: Array = []
	var cabecera: int = 0
	var out: Image = null
	var imgs: Array = []                      # cada fila: array de imagenes
	for f in filas:
		var fila: Array = []
		for n in f:
			fila.append(_cargar(D + n + ".png"))
		imgs.append(fila)
	for s in seqs:                            # secuencia: 4 fotogramas (0, 8, 16, 24)
		var fila2: Array = []
		for i in [0, 8, 16, 24]:
			var im: Image = _cargar(s % i)
			if im != null:
				fila2.append(im)
		imgs.append(fila2)
	var fila3: Array = []
	for r in refs:
		var im3: Image = _cargar(r)
		if im3 != null:
			fila3.append(im3)
	imgs.append(fila3)
	var cw: int = 480
	var ancho_total: int = cw * 4
	var alto_total: int = 0
	var escalados: Array = []
	for fila in imgs:
		var fe: Array = []
		var h_max: int = 0
		for im in fila:
			var s2: Image = im.duplicate()
			var k: float = float(cw) / float(s2.get_width())
			s2.resize(cw, int(s2.get_height() * k), Image.INTERPOLATE_BILINEAR)
			fe.append(s2)
			h_max = maxi(h_max, s2.get_height())
		escalados.append([fe, h_max])
		alto_total += h_max
	out = Image.create(ancho_total, alto_total, false, Image.FORMAT_RGB8)
	out.fill(Color(0.1, 0.1, 0.1))
	var y: int = 0
	for e in escalados:
		var x: int = 0
		for s3 in e[0]:
			out.blit_rect(s3, Rect2i(0, 0, s3.get_width(), s3.get_height()), Vector2i(x, y))
			x += cw
		y += int(e[1])
	out.save_png(ProjectSettings.globalize_path(D + nombre + ".png"))
	print("hoja " + nombre)
