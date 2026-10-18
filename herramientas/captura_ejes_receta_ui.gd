extends SceneTree

## SOLO CAPTURA (Pipeline, 18/10): la página del libro del bosque con la chuleta de ejes y el cubo en el núcleo, para MIRAR cómo quedan
## (la prueba sin ventana es `prueba_ejes_receta_ui.gd`). Con ventana (GPU o xvfb):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_ejes_receta_ui.gd -- <prefijo_salida>
## Dibuja sobre `grimorio_bosque.png` con las mismas coordenadas que `Spellbook.LIBROS["bosque"]` (núcleo y óvalos de la página derecha).
## Escribe `<prefijo>_pagina.png` (esfera base) y `<prefijo>_pagina_larga.png` (ᛁ ᛁ ᛏ + flecha + repetición: muro 3 de ancho, 2 niveles).
class Pagina:
	extends Control
	var g: Dictionary = {"x": 0.5, "y": 0.5, "z": 0.5}
	var usos: Dictionary = {}
	var fondo: Texture2D = load("res://art/ui/grimorio_bosque.png")
	## Los glifos se cargan UNA vez, fuera de `_draw`, como hace el juego (`Sigils.GLYPHS` son preload): cargarlos dentro del dibujo daba cuadrados blancos.
	var glifos: Dictionary = {}
	func _init() -> void:
		for n in ["fuego", "linea", "levitacion", "flecha", "barrera", "repeticion", "rebote", "pulso", "raido", "ansuz"]:
			glifos[n] = load("res://art/ui/glyphs/%s.png" % n)
	func _draw() -> void:
		draw_texture_rect(fondo, Rect2(Vector2.ZERO, size), false)
		var k: float = size.x / 1470.0
		# núcleo: círculo de 119,6 px de lámina centrado en (433,7 · 383,1) con el glifo del elemento (aquí el fuego) como en `_draw_core`
		var c := Vector2(433.7, 383.1) * k
		var radio: float = 119.6 * k
		var fuego: Texture2D = glifos["fuego"]
		draw_texture_rect(fuego, Rect2(c - Vector2.ONE * radio * 0.72, Vector2.ONE * radio * 1.44), false, Color(0.95, 0.33, 0.12).darkened(0.30))
		_texto(c + Vector2(0.0, radio - 28.0 * k), "Fuego", Color(0.95, 0.33, 0.12).darkened(0.55), int(20.0 * k))
		EjesRecetaUi.dibujar_indicador(self, EjesRecetaUi.sitio_en_nucleo(c, radio), radio * 1.0, g)
		# chuleta: los glifos en la rejilla 3 × 3 (centros de `leyenda`)
		var cen: Array = [Vector2(871.4, 415.6), Vector2(1028.8, 415.6), Vector2(1184.9, 415.6), Vector2(871.4, 551.4), Vector2(1028.8, 551.4),
				Vector2(1184.9, 551.4), Vector2(871.4, 683.8), Vector2(1028.8, 683.8), Vector2(1184.9, 683.8)]
		var nombres: Array = ["linea", "levitacion", "flecha", "barrera", "repeticion", "rebote", "pulso", "raido", "ansuz"]
		var tinta := Color(0.24, 0.19, 0.16)
		for i in nombres.size():
			var tex: Texture2D = glifos[nombres[i]]
			var conocida: bool = i < 7
			if not EjesRecetaUi.dibujar_casilla(self, nombres[i], tex, (cen[i] as Vector2) * k, 54.0 * k, tinta, conocida, usos):
				draw_texture_rect(tex, Rect2((cen[i] as Vector2) * k - Vector2.ONE * 27.0 * k, Vector2.ONE * 54.0 * k), false, tinta if conocida else EjesRecetaUi.TINTA_APAGADA)
	func _texto(pos: Vector2, t: String, col: Color, cuerpo: int) -> void:
		var f: Font = ThemeDB.fallback_font
		var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
		draw_string(f, pos - Vector2(w * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo, col)

func _initialize() -> void:
	_correr()

func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.is_empty():
		print("uso: -- <prefijo_salida>")
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(1470, 1070)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var p := Pagina.new()
	p.size = Vector2(1470, 1070)
	vp.add_child(p)
	await _frames(8)   # una textura pequeña tarda unos cuadros en subirse a la GPU: con 2 sale un cuadrado blanco
	vp.get_texture().get_image().save_png("%s_pagina.png" % a[0])
	p.g = {"x": 1.5, "y": 1.0, "z": 1.25}
	p.usos = {"linea_x": 2, "altura": 2, "flecha": 1, "repeticion": 1}
	p.queue_redraw()
	await _frames(8)
	vp.get_texture().get_image().save_png("%s_pagina_larga.png" % a[0])
	print("capturado ", a[0])
	quit()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame
