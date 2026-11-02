extends SceneTree

## Compone las hojas de la fase 4 del agua «toy» a partir de las capturas ya hechas (sin ventana): hoja_paleta_antes_despues.png, hoja_lenguas_antes_despues.png y hoja_resumen.png (referencias arriba).
##   godot --headless --path . --script res://herramientas/hoja_agua_fase4.gd

const BASE: String = "res://docs/capturas/comparativa_vfx/godot_agua/"
const REF_A: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_a.png"
const REF_B: String = "res://docs/capturas/comparativa_vfx/referencia_agua/ref_agua_bola_ola_pilar_b.png"
const CW: int = 480
const CH: int = 270


func _initialize() -> void:
	_paleta()
	_lenguas()
	_resumen()
	quit()


func _cargar(ruta: String) -> Image:
	var im: Image = Image.new()
	if im.load(ProjectSettings.globalize_path(ruta)) != OK:
		print("NO ESTÁ: " + ruta)
		return null
	im.convert(Image.FORMAT_RGB8)
	return im


func _celda(h: Image, im: Image, col: int, fila: int, y0: int = 0, cw: int = CW, ch: int = CH) -> void:
	if im == null:
		return
	var c: Image = im.duplicate()
	c.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
	h.blit_rect(c, Rect2i(0, 0, cw, ch), Vector2i(col * cw, y0 + fila * ch))


func _guardar(h: Image, nombre: String) -> void:
	h.save_png(ProjectSettings.globalize_path(BASE + "fase4/" + nombre))
	print("hoja " + nombre)


## Cada fila: antes (fase 1-3) | después (fase 4). La última columna: el agua del mundo.
func _paleta() -> void:
	var filas: Array = [
		["fase1/bola_quieta_juego.png", "fase4/despues_f1/bola_quieta_juego.png"],
		["fase1/bola_quieta_cerca.png", "fase4/despues_f1/bola_quieta_cerca.png"],
		["fase2/haz_juego.png", "fase4/despues_f2/haz_juego.png"],
		["fase3/geiser_juego.png", "fase4/geiser_juego.png"],
		["fase3/area_juego_700.png", "fase4/area_juego_700.png"],
		["fase1/impacto_suelo_juego.png", "fase4/despues_f1/impacto_suelo_juego.png"]]
	var h: Image = Image.create_empty(CW * 3, CH * filas.size() + CH, false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	for i in filas.size():
		_celda(h, _cargar(BASE + filas[i][0]), 0, i)
		_celda(h, _cargar(BASE + filas[i][1]), 1, i)
	var y: int = filas.size()
	_celda(h, _cargar(BASE + "fase4/paleta_junto_al_agua_del_mundo.png"), 0, y)
	_celda(h, _cargar(BASE + "fase4/paleta_junto_al_agua_del_mundo_estandar.png"), 1, y)
	_celda(h, _cargar(BASE + "fase4/paleta_area_350.png"), 2, y)
	_guardar(h, "hoja_paleta_antes_despues.png")


## Lenguas: fila 1 géiser antes (fase 3) y después; filas 2-3 el área en cuatro instantes, antes y después.
func _lenguas() -> void:
	var h: Image = Image.create_empty(CW * 4, CH * 6, false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	var g_antes: Array = ["fase3/geiser_juego.png", "fase3/geiser_cerca.png", "fase3/geiser_horizontal.png"]
	var g_desp: Array = ["fase4/geiser_juego.png", "fase4/geiser_cerca.png", "fase4/geiser_horiz.png"]
	for i in 3:
		_celda(h, _cargar(BASE + g_antes[i]), i, 0)
		_celda(h, _cargar(BASE + g_desp[i]), i, 1)
	var tiempos: Array = [100, 300, 500, 700, 1000, 1400]
	for i in 4:
		var t: int = [100, 300, 500, 700][i]
		_celda(h, _cargar(BASE + "fase3/area_cerca_%d.png" % t), i, 2)
		_celda(h, _cargar(BASE + "fase4/area_cerca_%d.png" % t), i, 3)
	for i in 4:
		var t2: int = [500, 700, 1000, 1400][i]
		_celda(h, _cargar(BASE + "fase3/area_juego_%d.png" % t2), i, 4)
		_celda(h, _cargar(BASE + "fase4/area_juego_%d.png" % t2), i, 5)
	_guardar(h, "hoja_lenguas_antes_despues.png")


## Resumen: referencias de Pablo arriba; después la ola (vistas, nacer, morir) y la tira de 12 fps.
func _resumen() -> void:
	var w: int = CW * 4
	var refs: Array = []
	var alto_refs: int = 0
	for r in [REF_A, REF_B]:
		var im: Image = _cargar(r)
		if im == null:
			continue
		var hh: int = int(round(float(im.get_height()) * float(w) / float(im.get_width())))
		im.resize(w, hh, Image.INTERPOLATE_LANCZOS)
		refs.append(im)
		alto_refs += hh
	var filas: Array = [
		["ola_juego", "ola_cerca", "ola_az0", "ola_az45"],
		["ola_az90", "ola_cerca_nace_120", "ola_cerca_nace_280", "ola_cerca_nace_450"],
		["ola_cerca_nace_700", "ola_cerca_muere_300", "ola_cerca_muere_700", "ola_cerca_muere_1100"],
		["ola_cerca_muere_1700", "ola_az90_nace_450", "ola_az90_muere_700", "ola_juego_muere_1100"]]
	var h: Image = Image.create_empty(w, alto_refs + CH * filas.size(), false, Image.FORMAT_RGB8)
	h.fill(Color(0.08, 0.08, 0.1))
	var y: int = 0
	for im in refs:
		h.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(0, y))
		y += im.get_height()
	for f in filas.size():
		for c in 4:
			_celda(h, _cargar(BASE + "fase4/" + filas[f][c] + ".png"), c, f, alto_refs)
	_guardar(h, "hoja_resumen.png")
