extends SceneTree

## HOJAS RESUMEN de la ronda de Pablo (2/11): monta, a partir de las capturas de captura_ronda_pablo_0211.gd, una hoja por figura con «antes», «después» y la REFERENCIA debajo, y las hojas
## de secuencia (12 fps) del haz y de la barrera. No necesita ventana:
##   godot --headless --path . --script res://herramientas/hojas_ronda_pablo_0211.gd -- docs/capturas/comparativa_vfx/godot_toy/ronda_pablo_0211

const ANCHO: int = 1920
const REF: String = "res://docs/capturas/comparativa_vfx/referencia_toy/"
var _dir: String = "docs/capturas/comparativa_vfx/godot_toy/ronda_pablo_0211"


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	_hoja("hoja_bola", [["bola_juego_antes", "bola_cerca_antes", "bola_lado_antes"], ["bola_juego_despues", "bola_cerca_despues", "bola_lado_despues"]], ["ref_haz_bola_video_b"])
	_hoja("hoja_barrera", [["barrera_juego_antes", "barrera_cerca_antes", "barrera_frente_antes"], ["barrera_juego_despues", "barrera_cerca_despues", "barrera_frente_despues"]],
		["ref_barrera_video_a", "ref_barrera_video_b"])
	_hoja("hoja_haz", [["haz_lado_antes", "haz_juego_antes", "haz_cerca_antes"], ["haz_lado_despues", "haz_juego_despues", "haz_cerca_despues"],
		["haz_corte_000_antes", "haz_corte_150_antes", "haz_corte_300_antes", "haz_corte_500_antes"], ["haz_corte_000_despues", "haz_corte_150_despues", "haz_corte_300_despues", "haz_corte_500_despues"]], ["ref_haz_video_a"])
	_hoja("hoja_pilar", [["pilar_juego_antes", "pilar_base_cerca_antes", "pilar_base_alta_antes"], ["pilar_juego_despues", "pilar_base_cerca_despues", "pilar_base_alta_despues"]], [])
	_secuencia("secuencia_barrera", "seq_barrera", ["antes", "despues"], 30, 6)
	_secuencia("secuencia_haz", "seq_haz", ["despues"], 30, 6)
	print("HOJAS en " + _dir)
	quit()


func _img(ruta: String) -> Image:
	var im: Image = Image.load_from_file(ruta)
	if im == null:
		push_warning("falta " + ruta)
		im = Image.create_empty(16, 9, false, Image.FORMAT_RGB8)
	im.convert(Image.FORMAT_RGB8)
	return im


func _a_ancho(im: Image, w: int) -> Image:
	var r: Image = im.duplicate()
	r.resize(w, maxi(1, int(round(float(im.get_height()) * float(w) / float(im.get_width())))), Image.INTERPOLATE_LANCZOS)
	return r


## Filas de capturas (cada fila ocupa el ancho de la hoja, celdas de igual ancho en 16:9) y, debajo, las referencias a todo el ancho.
func _hoja(nombre: String, filas: Array, refs: Array) -> void:
	var celdas: Array = []
	var alto: int = 0
	for f in filas:
		var w: int = ANCHO / (f as Array).size()
		var fila: Array = []
		var h: int = int(round(float(w) * 9.0 / 16.0))
		for n in f:
			fila.append(_a_ancho(_img(_dir.path_join(String(n) + ".png")), w))
		celdas.append(fila)
		alto += h + 4
	var imgs_ref: Array = []
	for r in refs:
		var im: Image = _a_ancho(_img(ProjectSettings.globalize_path(REF + String(r) + ".png")), ANCHO)
		imgs_ref.append(im)
		alto += im.get_height() + 4
	var hoja: Image = Image.create_empty(ANCHO, alto, false, Image.FORMAT_RGB8)
	hoja.fill(Color(0.08, 0.08, 0.1))
	var y: int = 0
	for fila in celdas:
		var w2: int = ANCHO / (fila as Array).size()
		for i in (fila as Array).size():
			var im2: Image = fila[i]
			hoja.blit_rect(im2, Rect2i(0, 0, im2.get_width(), im2.get_height()), Vector2i(i * w2, y))
		y += (fila[0] as Image).get_height() + 4
	for im3 in imgs_ref:
		hoja.blit_rect(im3, Rect2i(0, 0, im3.get_width(), im3.get_height()), Vector2i(0, y))
		y += (im3 as Image).get_height() + 4
	hoja.save_png(_dir.path_join(nombre + ".png"))
	print("hoja " + nombre)


## Secuencia a 12 fps: `n` fotogramas de cada etiqueta en `cols` columnas (celdas de 320 × 180).
func _secuencia(nombre: String, sub: String, tags: Array, n: int, cols: int) -> void:
	var w: int = ANCHO / cols
	var h: int = int(round(float(w) * 9.0 / 16.0))
	var filas_tag: int = (n + cols - 1) / cols
	var hoja: Image = Image.create_empty(ANCHO, h * filas_tag * tags.size() + 4 * tags.size(), false, Image.FORMAT_RGB8)
	hoja.fill(Color(0.08, 0.08, 0.1))
	for t in tags.size():
		for i in n:
			var ruta: String = _dir.path_join(sub).path_join("%s_%02d.png" % [tags[t], i])
			if not FileAccess.file_exists(ruta):
				continue
			var im: Image = _a_ancho(_img(ruta), w)
			hoja.blit_rect(im, Rect2i(0, 0, w, im.get_height()), Vector2i((i % cols) * w, t * (h * filas_tag + 4) + (i / cols) * h))
	hoja.save_png(_dir.path_join(nombre + ".png"))
	print("hoja " + nombre)
