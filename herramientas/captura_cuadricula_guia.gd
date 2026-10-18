extends SceneTree
## Captura y prueba de CuadriculaGuia (17/10, Pipeline): pinta la lámina del bosque con la rejilla encima y guarda un PNG.
## Uso:  godot --rendering-driver opengl3 --path . --script res://herramientas/captura_cuadricula_guia.gd -- /tmp/cuadricula
## Comprueba: (1) los nodos de página coinciden con los 4 × 4 del sello, (2) no dibuja nada con una lámina desconocida,
## (3) activa = false la apaga, (4) la rejilla es tenue (el cambio medio de color respecto a la lámina sola es pequeño).
class Lienzo extends Control:
	var lamina: Texture2D
	var con_rejilla: bool = true
	var libro: String = "bosque"
	var huecos: Dictionary = {2: Vector2(431.4, 628.1), 3: Vector2(305.4, 578.7), 1: Vector2(557.3, 578.7)}
	var radios: Dictionary = {2: 59.8, 3: 58.1, 1: 58.1}
	func _draw() -> void:
		draw_texture_rect(lamina, Rect2(Vector2.ZERO, size), false)
		if con_rejilla:
			var k: float = size.x / 1470.0
			CuadriculaGuia.dibujar(self, libro, huecos, radios, func(p: Vector2) -> Vector2: return p * k, func(m: float) -> float: return m * k)

var _fallos: int = 0
var _sv: SubViewport = null

func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1

func _foto(lienzo: Lienzo) -> Image:
	lienzo.queue_redraw()
	await process_frame
	await process_frame
	return _sv.get_texture().get_image()

func _initialize() -> void:
	var base: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/cuadricula"
	# Un SubViewport del tamaño exacto de la lámina: la ventana del proyecto es más pequeña.
	_sv = SubViewport.new()
	_sv.size = Vector2i(1470, 1070)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sv)
	var l := Lienzo.new()
	l.lamina = load("res://art/ui/grimorio_bosque.png") as Texture2D
	l.size = Vector2(1470, 1070)
	_sv.add_child(l)
	await process_frame
	l.con_rejilla = false
	var sin: Image = await _foto(l)
	l.con_rejilla = true
	var con: Image = await _foto(l)
	con.save_png(base + "_con.png")
	var suma: float = 0.0
	var cambiados: int = 0
	for y in range(0, 1070, 3):
		for x in range(0, 1470, 3):
			var a: Color = sin.get_pixel(x, y)
			var b: Color = con.get_pixel(x, y)
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			suma += d
			if d > 0.004:
				cambiados += 1
	var total: float = float(357 * 490)
	print("píxeles muestreados que cambian: ", cambiados, " de ", int(total), "  cambio medio: ", suma / total)
	_ok(cambiados > 500, "la rejilla se dibuja (hay píxeles distintos de la lámina sola)")
	_ok(suma / total < 0.02, "es tenue (cambio medio por píxel < 0,02)")
	# Un nodo del sello: la esquina arriba-izquierda del cuadrado de nodos = (433,7 − 79 ; 383,1 − 79) debe estar más oscura que su entorno sin rejilla.
	var m: float = 119.6 * 0.66
	var nx: int = int(round(433.7 - m)); var ny: int = int(round(383.1 - m))
	var dn: float = (sin.get_pixel(nx, ny).v - con.get_pixel(nx, ny).v)
	_ok(dn > 0.01, "hay un nodo en la esquina del cuadrado del sello (%d, %d): oscurece %.3f" % [nx, ny, dn])
	# Los nodos de la página caen en la misma retícula: uno dos pasos a la derecha del anterior.
	var paso: float = 2.0 * m / 3.0
	var nx2: int = int(round(433.7 - m + 3.0 * paso))
	var dn2: float = (sin.get_pixel(nx2, ny).v - con.get_pixel(nx2, ny).v)
	_ok(dn2 > 0.01, "y el nodo opuesto del sello (%d, %d): oscurece %.3f" % [nx2, ny, dn2])
	# Lámina desconocida: no pinta.
	l.libro = "nivel1"
	var otra: Image = await _foto(l)
	var igual: bool = true
	for y in range(0, 1070, 7):
		for x in range(0, 1470, 7):
			if otra.get_pixel(x, y) != sin.get_pixel(x, y):
				igual = false
	_ok(igual, "con una lámina que no está en LIBROS no dibuja nada")
	l.libro = "bosque"
	CuadriculaGuia.activa = false
	var apagada: Image = await _foto(l)
	CuadriculaGuia.activa = true
	var igual2: bool = true
	for y in range(0, 1070, 7):
		for x in range(0, 1470, 7):
			if apagada.get_pixel(x, y) != sin.get_pixel(x, y):
				igual2 = false
	_ok(igual2, "activa = false la apaga")
	print("FALLOS: ", _fallos)
	quit(_fallos)
