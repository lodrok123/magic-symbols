extends SceneTree

## HOJA COMPARATIVA de impactos (25/11/2026): junta en una imagen por par las fotos de la vista «cerca» a los mismos instantes, en tres filas:
##   EFFEKSEER ORIGINAL (E:\pruebas_effekseer\demo\captura_original.gd) · AHORA (izquierda de la comparativa del lab) · TRADUCIDO A NUESTRAS PIEZAS (derecha).
## Necesita ventana (pinta los rótulos con Labels). Antes: captura_impactos_effekseer.gd y la captura de los originales.
##   godot --path . --script res://herramientas/hoja_impactos_effekseer.gd -- output/effekseer_impactos_2026-11-25
## Escribe <carpeta>/hoja_<id>.png.

const INSTANTES_MS: Array = [50, 100, 200, 350, 600, 1000]
const IDS: Array = [["hit01", true], ["toonhit", true], ["fire02", false], ["toonwater", false], ["tierra", false]]    ## [id, pared]
const CELDA: Vector2i = Vector2i(560, 440)
const ESC: float = 0.6
const IZQ: int = 210
const ARRIBA: int = 40

var _dir: String = "output/effekseer_impactos_2026-11-25"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	var cw: int = int(CELDA.x * ESC)
	var ch: int = int(CELDA.y * ESC)
	var tam: Vector2i = Vector2i(IZQ + cw * INSTANTES_MS.size(), ARRIBA + ch * 3)
	root.get_window().size = tam
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for e in IDS:
		var id: String = String(e[0])
		var pared: bool = bool(e[1])
		var y0: int = 170 if pared else 330
		var lienzo: Control = Control.new()
		lienzo.size = tam
		root.add_child(lienzo)
		var fondo: ColorRect = ColorRect.new()
		fondo.color = Color(0.1, 0.1, 0.11)
		fondo.size = tam
		lienzo.add_child(fondo)
		var filas: Array = [["EFFEKSEER\nORIGINAL", "originales/%s_original_%04d.png", 800 - CELDA.x / 2],
			["AHORA", "capturas/%s_cerca_%04d.png", 480 - CELDA.x / 2], ["TRADUCIDO\nA NUESTRAS\nPIEZAS", "capturas/%s_cerca_%04d.png", 1120 - CELDA.x / 2]]
		for c in INSTANTES_MS.size():
			_rotulo(lienzo, "%d ms" % int(INSTANTES_MS[c]), Vector2(IZQ + c * cw + 8, 8), 20)
		for f in filas.size():
			_rotulo(lienzo, "%s\n(%s)" % [String(filas[f][0]), id] if f == 0 else String(filas[f][0]), Vector2(10, ARRIBA + f * ch + 10), 20)
			for c in INSTANTES_MS.size():
				var ruta: String = _dir.path_join(String(filas[f][1]) % [id, int(INSTANTES_MS[c])])
				var img: Image = Image.load_from_file(ruta) if FileAccess.file_exists(ruta) else null
				if img == null:
					continue
				var rec: Image = img.get_region(Rect2i(int(filas[f][2]), y0, CELDA.x, CELDA.y))
				rec.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
				var tr: TextureRect = TextureRect.new()
				tr.texture = ImageTexture.create_from_image(rec)
				tr.position = Vector2(IZQ + c * cw, ARRIBA + f * ch)
				lienzo.add_child(tr)
		for k in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(_dir.path_join("hoja_%s.png" % id))
		print("hoja " + id)
		lienzo.queue_free()
		await process_frame
	quit()


func _rotulo(padre: Control, texto: String, pos: Vector2, tam: int) -> void:
	var l: Label = Label.new()
	l.text = texto
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	padre.add_child(l)
