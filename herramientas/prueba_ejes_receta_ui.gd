extends SceneTree

## PRUEBA (Pipeline, 18/10): `EjesRecetaUi`, la chuleta de ejes y el cubo X·Y·Z del libro (docs/GLIFOS_RECETA.md §2.1).
##   godot --headless --path . --script res://herramientas/prueba_ejes_receta_ui.gd              (lógica)
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/prueba_ejes_receta_ui.gd   (además, PÍXELES)
## Comprueba: 1. que `linea.png` es vertical (de eso depende QUÉ eje se gira); 2. los números (dimensiones, giro, texto); 3. qué glifos
## trata `dibujar_casilla` y cuáles deja al Spellbook; 4. con ventana, midiendo píxeles: ᛁ «ancho» sale más ancha que alta y ᛁ «fondo» más alta
## que ancha, y el cubo crece con cada eje y cabe en su caja.
class Lienzo:
	extends Control
	var accion: Callable
	var resultado: Variant
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		resultado = accion.call(self)

var _fallos: int = 0
var _glifos: Dictionary = {}

func _initialize() -> void:
	_correr()

func _correr() -> void:
	for n in ["linea", "levitacion", "flecha", "barrera", "repeticion", "rebote", "pulso", "raido"]:
		_glifos[n] = load("res://art/ui/glyphs/%s.png" % n)
	# 1. la raya del arte es vertical
	var im: Image = (_glifos["linea"] as Texture2D).get_image()
	var caja: Rect2i = _caja_oscura(im, 0.5, true)
	_ok(caja.size.y > caja.size.x * 3, "linea.png es una raya vertical (%d × %d px de alfa)" % [caja.size.x, caja.size.y])
	# 2. números
	_ok(EjesRecetaUi.giro_linea("linea_x") == PI * 0.5, "linea_x se pinta girada 90°")
	_ok(EjesRecetaUi.giro_linea("linea_z") == 0.0, "linea_z se pinta como viene (la raya ya es vertical)")
	_ok(EjesRecetaUi.giro_linea("flecha") == 0.0 and EjesRecetaUi.giro_linea("") == 0.0, "cualquier otro nombre no gira")
	_ok(EjesRecetaUi.exenta_del_giro("linea_x") and EjesRecetaUi.exenta_del_giro("linea_z") and not EjesRecetaUi.exenta_del_giro("flecha"), "solo ᛁ está exenta del giro hacia el centro")
	var d: Vector3 = EjesRecetaUi.dimensiones({"x": 0.5, "y": 0.5, "z": 0.5})
	_ok(d == Vector3.ONE, "la esfera base mide 1·1·1 casillas (%s)" % str(d))
	d = EjesRecetaUi.dimensiones({"x": 1.5, "y": 1.0, "z": 1.25})
	_ok(d == Vector3(3.0, 2.0, 2.5), "ᛁᛁ + ᛏ + ᛁ vertical = 3·2·2,5 (%s)" % str(d))
	_ok(EjesRecetaUi.texto_casillas(1.0) == "1" and EjesRecetaUi.texto_casillas(2.5) == "2,5" and EjesRecetaUi.texto_casillas(4.0) == "4" and EjesRecetaUi.texto_casillas(5.49) == "5,5", "texto_casillas: coma decimal y sin ceros de más")
	var tope: Vector3 = EjesRecetaUi.dimensiones({"x": 3.0, "y": 2.0, "z": 3.0})
	_ok(tope == EjesRecetaUi.MAX_CASILLAS, "MAX_CASILLAS = el tope de Sigils.GLIFOS_V2 (3, 2, 3 de semieje) = %s" % str(tope))
	# 3. qué trata dibujar_casilla (con un lienzo, aunque sea sin ventana)
	var lienzo := Lienzo.new()
	lienzo.size = Vector2(200, 120)
	root.add_child(lienzo)
	for n in ["linea", "levitacion", "altura", "flecha", "barrera", "repeticion", "rebote", "pulso", "raido"]:      # 23/10: ᚱ «pulso» (id raido) ya es una propiedad de la receta
		var g: Texture2D = _glifos.get(n, _glifos["levitacion"])
		lienzo.accion = func(c: Control) -> bool: return EjesRecetaUi.dibujar_casilla(c, n, g, Vector2(100, 60), 54.0, EjesRecetaUi.TINTA, true, {})
		lienzo.queue_redraw()
		await process_frame
		await process_frame
		_ok(bool(lienzo.resultado), "dibujar_casilla trata «%s»" % n)
	for n in ["ansuz", "amplificar", "retardo", "espejo", "pilar", "fuego"]:
		lienzo.accion = func(c: Control) -> bool: return EjesRecetaUi.dibujar_casilla(c, n, _glifos["levitacion"], Vector2(100, 60), 54.0, EjesRecetaUi.TINTA, true, {})
		lienzo.queue_redraw()
		await process_frame
		await process_frame
		_ok(not bool(lienzo.resultado), "dibujar_casilla deja «%s» al Spellbook (devuelve false)" % n)
	lienzo.accion = func(c: Control) -> bool: return EjesRecetaUi.dibujar_casilla(c, "linea", null, Vector2(100, 60), 54.0, EjesRecetaUi.TINTA, true, {})
	lienzo.queue_redraw()
	await process_frame
	await process_frame
	_ok(not bool(lienzo.resultado), "sin textura devuelve false y no revienta")
	lienzo.accion = func(c: Control) -> Vector3: return EjesRecetaUi.dibujar_indicador(c, Vector2(100, 60), 60.0, {"x": 1.5, "y": 1.0, "z": 1.25})
	lienzo.queue_redraw()
	await process_frame
	await process_frame
	_ok(lienzo.resultado == Vector3(3.0, 2.0, 2.5), "dibujar_indicador devuelve el tamaño en casillas")
	# 4. píxeles (solo con ventana)
	if DisplayServer.get_name() == "headless":
		print("(sin ventana: se salta la comprobación de píxeles; usa xvfb)")
	else:
		await _pixeles()
	print("%s: %d fallos" % ["FALLO" if _fallos > 0 else "OK", _fallos])
	quit(1 if _fallos > 0 else 0)

func _pixeles() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 140)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var l := Lienzo.new()
	l.size = Vector2(400, 140)
	vp.add_child(l)
	# ᛁ doble: izquierda = ancho (horizontal), derecha = fondo (vertical). Se mide cada mitad por separado, sin rótulos (conocida = true pinta rótulos
	# de color: se mide solo la tinta oscura, y los rótulos están en rojo/azul, que no pasan el umbral).
	l.accion = func(c: Control) -> bool: return EjesRecetaUi.dibujar_casilla(c, "linea", _glifos["linea"], Vector2(200, 60), 90.0, Color.BLACK, true, {})
	l.queue_redraw()
	for _i in 8:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	var izq: Rect2i = _caja_oscura(img.get_region(Rect2i(0, 0, 200, 110)), 0.25, false)
	var der: Rect2i = _caja_oscura(img.get_region(Rect2i(200, 0, 200, 110)), 0.25, false)
	_ok(izq.size.x > izq.size.y * 3, "ᛁ «ancho» sale horizontal en pantalla (%d × %d px)" % [izq.size.x, izq.size.y])
	_ok(der.size.y > der.size.x * 3, "ᛁ «fondo» sale vertical en pantalla (%d × %d px)" % [der.size.x, der.size.y])
	# cubo: la esfera base (1·1·1) y el más grande (6·4·6) caben en su caja de `tam` y el grande es mayor en alto y en ancho
	var cajas: Array = []
	for g in [{"x": 0.5, "y": 0.5, "z": 0.5}, {"x": 3.0, "y": 2.0, "z": 3.0}, {"x": 3.0, "y": 0.5, "z": 0.5}, {"x": 0.5, "y": 2.0, "z": 0.5}]:
		l.accion = func(c: Control) -> Vector3: return EjesRecetaUi.dibujar_indicador(c, Vector2(200, 60), 80.0, g, Color.BLACK, false)
		l.queue_redraw()
		for _i in 3:
			await process_frame
		cajas.append(_caja_oscura(vp.get_texture().get_image(), 0.25, false, true))
	print("medido: ᛁ ancho %s · ᛁ fondo %s · cubos %s" % [str(izq.size), str(der.size), str(cajas.map(func(r: Rect2i) -> Vector2i: return r.size))])
	var peq: Rect2i = cajas[0]
	var gra: Rect2i = cajas[1]
	_ok(peq.size.x > 4 and peq.size.y > 4, "el cubo 1·1·1 se ve (%d × %d px)" % [peq.size.x, peq.size.y])
	_ok(gra.size.x <= 80 and gra.size.y <= 84, "el cubo 6·4·6 cabe en su tam (+ el grosor de las aristas) (%d × %d de 80)" % [gra.size.x, gra.size.y])
	_ok(gra.size.x > peq.size.x and gra.size.y > peq.size.y, "el cubo crece con las dimensiones")
	_ok((cajas[3] as Rect2i).size.y > (cajas[2] as Rect2i).size.y, "más altura = cubo más alto (Y×4 mide %d frente a X×6 %d)" % [(cajas[3] as Rect2i).size.y, (cajas[2] as Rect2i).size.y])
	_ok((cajas[2] as Rect2i).size.x > (cajas[3] as Rect2i).size.x, "más ancho = cubo más ancho (X×6 mide %d frente a Y×4 %d)" % [(cajas[2] as Rect2i).size.x, (cajas[3] as Rect2i).size.x])

## Caja que envuelve los píxeles «de tinta». `alfa` = true mira el canal alfa (para el PNG del arte); si no, la luminosidad (oscuro sobre blanco);
## `color` = también cuenta los píxeles de color (los ejes) además de los negros.
func _caja_oscura(img: Image, umbral: float, alfa: bool, color: bool = false) -> Rect2i:
	var x0: int = 1 << 20
	var y0: int = 1 << 20
	var x1: int = -1
	var y1: int = -1
	for y in img.get_height():
		for x in img.get_width():
			var p: Color = img.get_pixel(x, y)
			var tinta: bool
			if alfa:
				tinta = p.a > umbral
			elif color:
				tinta = (1.0 - minf(minf(p.r, p.g), p.b)) > umbral
			else:
				tinta = maxf(maxf(p.r, p.g), p.b) < umbral and p.a > 0.5 and absf(p.r - p.b) < 0.1
			if tinta:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1) if x1 >= 0 else Rect2i()

func _ok(cond: bool, texto: String) -> void:
	if not cond:
		_fallos += 1
		print("FALLO: ", texto)
