extends SceneTree
## ManoPluma3D (Pipeline, 16/10): misma interfaz que ManoPluma2D, la pluma se ve siempre (`pluma_siempre`) y el plumín cae en la punta del trazo.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/prueba_mano_pluma_3d.gd
## NECESITA un renderizador (no vale --headless): mide la punta en la IMAGEN renderizada, no en la cuenta. Tarda ~1 min con llvmpipe.
## Las posiciones son las de `LIBROS["bosque"]` (spellbook.gd) y el encuadre es el de `spellbook._book_rect()` con su `bloque`.

var _fallos: int = 0
const BLOQUE: Rect2 = Rect2(107, 86, 1240, 760)       ## = LIBROS["bosque"]["bloque"]
const LAMINA: Vector2 = Vector2(1470.0, 1070.0)       ## = spellbook.BOOK_SIZE
## Sitios donde cae la punta: los 3 huecos de glifo, el sello (centro del círculo exterior + nucleo_desp) y dos círculos de sello de la página derecha.
const SITIOS: Dictionary = {
	"hueco 2 (abajo)": Vector2(431.4, 628.1), "hueco 3 (abajo-izq)": Vector2(305.4, 578.7), "hueco 1 (abajo-der)": Vector2(557.3, 578.7),
	"sello (núcleo)": Vector2(433.7, 383.1), "sello 1 (derecha)": Vector2(838.3, 276.8), "sello 6 (derecha)": Vector2(1216.9, 276.8),
}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_basicas()
	await _escribir_y_ocultar()
	await _recorte()
	for tam in [Vector2i(1280, 720), Vector2i(960, 540)]:
		await _punta(tam)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _basicas() -> void:
	_ok("A1 hay GLB de mano, manga y pluma", ManoPluma3D.disponible())
	var m := ManoPluma3D.new()
	_ok("A2 es una ManoPluma2D (una variable tipada así la admite)", m is ManoPluma2D)
	_ok("A3 capa_z por encima de los trazos (z_index > 0)", m.capa_z > 0)
	_ok("A4 la punta del modelo es el origen: proyectar(0) = 0", ManoPluma3D.proyectar(Vector3.ZERO) == Vector2.ZERO)
	# El eje X del modelo va a la derecha de la pantalla y la altura (+Y) hacia arriba (y de pantalla negativa).
	_ok("A5 +X del mundo = derecha de pantalla; +Y = arriba", ManoPluma3D.proyectar(Vector3(1, 0, 0)).x > 0.0 and ManoPluma3D.proyectar(Vector3(0, 1, 0)).y < 0.0)
	m.free()


## Mismo recorrido de entrada a una 2D y a una 3D: `punta()` debe salir igual (el Juego no nota la diferencia) y la pluma solo se ve escribiendo.
func _escribir_y_ocultar() -> void:
	var vp := _lienzo(Vector2i(640, 480))
	var a := ManoPluma2D.new()
	var b := ManoPluma3D.new()
	vp.add_child(a)
	vp.add_child(b)
	var recorrido: Array = [Vector2(100, 100), Vector2(160, 120), Vector2(220, 150), Vector2(300, 150), Vector2(300, 150)]
	var dif: float = 0.0
	for p in recorrido:
		for _i in 3:
			a.apuntar(p, true)
			b.apuntar(p, true)
			await process_frame
			dif = maxf(dif, a.punta().distance_to(b.punta()))
	_ok("B1 con las mismas entradas, punta() de la 3D = la de la 2D", dif < 0.001, "dif máx %.5f px" % dif)
	_ok("B2 pulsando: pose ESCRIBIENDO y la pluma se ve", b.pose == ManoPluma2D.Pose.ESCRIBIENDO and b._pluma.visible)
	for _i in 4:
		b.apuntar(Vector2(300, 150), false)
		await process_frame
	_ok("B3 sin pulsar la pluma SIGUE VISIBLE (pluma_siempre, pedido de Pablo 16/10)", b._pluma.visible, "pose=%s" % ManoPluma2D.nombre_pose(b.pose))
	b.pluma_siempre = false
	b.apuntar(Vector2(300, 150), false)
	await process_frame
	_ok("B3b con pluma_siempre = false se oculta al no escribir (el comportamiento del primer encargo)", not b._pluma.visible)
	b.pluma_siempre = true
	_ok("B4 sin pulsar la mano se levanta (altura del ancla > 0)", b._ancla.position.y > 0.0, "alto=%.3f m" % b._ancla.position.y)
	for _i in 40:
		b.apuntar(Vector2(300, 150), true)
		await process_frame
	_ok("B5 al volver a pulsar baja al papel (altura ~ 0) y la pluma vuelve", b._ancla.position.y < 0.002 and b._pluma.visible, "alto=%.4f m" % b._ancla.position.y)
	b.ocultar()
	_ok("B6 ocultar() / mostrar()", not b.visible)
	b.mostrar()
	_ok("B6b mostrar() la devuelve", b.visible)
	vp.queue_free()


## La mano no se corta por arriba ni por la izquierda del viewport (por la esquina de abajo a la derecha sale la manga, que se desvanece a propósito).
func _recorte() -> void:
	var vp := _lienzo(Vector2i(640, 480))
	var b := ManoPluma3D.new()
	vp.add_child(b)
	for estado in ["escribiendo", "levantada"]:
		for _i in 40:
			b.apuntar(Vector2(300, 250), estado == "escribiendo")
			await process_frame
		for _i in 4:
			await process_frame
		var im: Image = b._vp.get_texture().get_image()
		var w: int = im.get_width()
		var h: int = im.get_height()
		var corte: int = 0
		for i in w:
			if im.get_pixel(i, 0).a > 0.05:
				corte += 1
		for j in h:
			if im.get_pixel(0, j).a > 0.05:
				corte += 1
		_ok("C1 (%s) nada toca el borde de arriba ni el de la izquierda del viewport" % estado, corte == 0, "píxeles tocando: %d" % corte)
		# Y la mano llena el viewport razonablemente (no está vacío ni es diminuta).
		var n: int = 0
		for j in range(0, h, 2):
			for i in range(0, w, 2):
				if im.get_pixel(i, j).a > 0.5:
					n += 1
		_ok("C2 (%s) la mano ocupa entre el 5 y el 40 %% del viewport" % estado, n * 4 > w * h * 0.05 and n * 4 < w * h * 0.40, "%.1f %%" % (100.0 * float(n * 4) / float(w * h)))
	vp.queue_free()


## Mide dónde cae la punta del plumín en la imagen: solo la pluma (sin mano, manga ni sombra); la punta es el extremo del trazo contrario a la parte alta de la pluma.
func _punta(tam: Vector2i) -> void:
	var fit: float = minf(float(tam.x) / BLOQUE.size.x, float(tam.y) / BLOQUE.size.y)
	var origen: Vector2 = Vector2(tam) * 0.5 - (BLOQUE.position + BLOQUE.size * 0.5) * fit
	var vp := _lienzo(tam)
	var m := ManoPluma3D.new()
	m.escala = fit
	vp.add_child(m)
	await process_frame
	m._mano_3d.visible = false
	m._manga_3d.visible = false
	m._s_sombra.visible = false
	var peor: float = 0.0
	for nombre in SITIOS.keys():
		var p: Vector2 = origen + (SITIOS[nombre] as Vector2) * fit
		for _i in 20:
			m.apuntar(p, true)
			await process_frame
		for _i in 2:
			await process_frame
		var im: Image = vp.get_texture().get_image()
		# Eje de la pluma en pantalla: de la punta hacia arriba.
		var enganche: Transform3D = PiezaEscritura3D.pluma_en_agarre()
		var eje: Vector2 = ManoPluma3D.proyectar(Basis(Vector3.UP, deg_to_rad(ManoPluma3D.YAW_BASE)) * enganche.basis * Vector3.UP).normalized()
		var punta_img: Vector2 = Vector2.INF
		var mejor: float = INF
		# Solo se busca cerca de la punta esperada (200 px): no se confunde con nada más.
		for j in range(maxi(0, int(p.y) - 60), mini(tam.y, int(p.y) + 60)):
			for i in range(maxi(0, int(p.x) - 60), mini(tam.x, int(p.x) + 60)):
				if im.get_pixel(i, j).a > 0.5:
					var v: float = (Vector2(i, j) - p).dot(eje)
					if v < mejor:
						mejor = v
						punta_img = Vector2(i, j)
		var err: float = punta_img.distance_to(p) / fit        # en px de lámina
		peor = maxf(peor, err)
		_ok("D (%dx%d) %s: el plumín cae en el punto del trazo" % [tam.x, tam.y, nombre], err < 3.0, "error %.1f px de lámina (%.1f px de pantalla); punta medida %s, punto %s" % [err, err * fit, punta_img, p])
	print("      peor error a %dx%d: %.1f px de lámina" % [tam.x, tam.y, peor])
	vp.queue_free()


func _lienzo(tam: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = tam
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp
