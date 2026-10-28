extends SceneTree
## LimoVisual3D (E1, 27/10): instancia, carga de elementos, salto, división y congelación, sin ventana. Lo escribe el Juego.
##   Godot --headless --path . --script res://herramientas/prueba_limo_visual.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	var base := Node3D.new()
	root.add_child(base)
	var l := LimoVisual3D.new()
	base.add_child(l)
	await _s(0.2)
	_ok("1 se instancia con cuerpo, núcleo y cara", l.material_cuerpo != null and l.get_node_or_null("Escala/Aplaste/Cuerpo/Nucleo") != null and l.get_node_or_null("Escala/Aplaste/Cuerpo/Cara") != null)
	_ok("1 tamaño normal 1,0", is_equal_approx(l.tamano, 1.0))

	# Elementos: el uniform cambia al color del elemento de las runas.
	var vistos: Array = []
	for e in ["fuego", "agua", "rayo", "hielo", "tierra", "viento", "tiempo"]:
		l.cargar(e)
		var c: Color = l.material_cuerpo.get_shader_parameter("color_elemento")
		_ok("2 cargar(%s) tiñe con el color de Pulso3D" % e, c.is_equal_approx(Pulso3D.color_de(e)) and not vistos.has(c))
		vistos.append(c)
	await _s(0.6)
	_ok("2 la carga sube a 1", is_equal_approx(l.carga_actual(), 1.0) and is_equal_approx(l.material_cuerpo.get_shader_parameter("carga"), 1.0))
	l.cargar("")
	await _s(0.6)
	_ok("2 cargar(\"\") vuelve a neutro", l.carga_actual() < 0.01 and l.elemento == "")
	l.cargar("nada")
	_ok("2 un elemento desconocido = neutro", l.elemento == "")

	# Salto: vuelve a la altura del suelo y avanza una casilla.
	l.position = Vector3(1.0, 0.0, 2.0)
	l.saltar(Vector3.RIGHT)
	var alto: float = 0.0
	var t0: int = Time.get_ticks_msec()
	while l.en_salto and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		alto = maxf(alto, l.position.y)
	await _s(0.1)
	_ok("3 el salto sube", alto > 0.5, "alto máx %.2f" % alto)
	_ok("3 aterriza a la altura del suelo", absf(l.position.y) < 0.001, "y=%.4f" % l.position.y)
	_ok("3 avanza ~1 casilla", absf(l.position.x - (1.0 + LimoVisual3D.CASILLA)) < 0.05 and absf(l.position.z - 2.0) < 0.05, "pos %s" % str(l.position))

	# Golpe: no rompe y vuelve a reposo.
	l.golpe()
	await _s(1.0)
	_ok("4 el golpe termina en reposo", l._estado == "reposo")

	# Congelar y descongelar.
	l.congelar(true)
	await _s(0.8)
	_ok("5 congelado llega a 1", is_equal_approx(l.congelado, 1.0) and l.esta_congelado() and is_equal_approx(l.material_cuerpo.get_shader_parameter("congelado"), 1.0))
	l.congelar(false)
	await _s(0.8)
	_ok("5 descongelado vuelve a 0", is_equal_approx(l.congelado, 0.0) and not l.esta_congelado())

	# Dividir: dos hermanos LimoVisual3D de tamaño 0,6 que salen a los lados.
	l.cargar("fuego")
	var h: Array = l.dividir()
	_ok("6 dividir devuelve 2 hijos", h.size() == 2)
	var hermanos: int = 0
	for n in base.get_children():
		if n is LimoVisual3D and n != l:
			hermanos += 1
	_ok("6 hay 2 limos hermanos nuevos", hermanos == 2)
	_ok("6 de tamaño 0,6", h.size() == 2 and is_equal_approx((h[0] as LimoVisual3D).tamano, 0.6) and is_equal_approx((h[1] as LimoVisual3D).tamano, 0.6))
	await _s(1.2)
	var a: LimoVisual3D = h[0]
	var b: LimoVisual3D = h[1]
	_ok("6 salen a lados opuestos", a.visible and b.visible and absf(a.position.x - b.position.x) > 1.2, "separación %.2f" % absf(a.position.x - b.position.x))
	_ok("6 los hijos heredan el elemento", a.elemento == "fuego" and b.elemento == "fuego")
	_ok("6 el original se deshace", not l.get_node("Escala/Aplaste").visible)
	l.reunir()
	await process_frame
	_ok("6 reunir limpia los hijos", l.hijos.is_empty() and l.get_node("Escala/Aplaste").visible)

	# Crecer: el mismo elemento otra vez absorbe y crece (pequeño 0,6 → normal 1,0 → grande 1,6).
	var c := LimoVisual3D.new()
	base.add_child(c)
	var avisos: Array = []
	c.crecio.connect(func(t: float) -> void: avisos.append(t))
	c.cargar("fuego")
	await _s(0.6)
	_ok("7 cargar por primera vez no crece", is_equal_approx(c.tamano, 1.0) and avisos.is_empty())
	c.cargar("agua")
	await _s(0.1)
	_ok("7 otro elemento no crece y cambia el color", is_equal_approx(c.tamano, 1.0) and avisos.is_empty() and c.material_cuerpo.get_shader_parameter("color_elemento").is_equal_approx(Pulso3D.color_de("agua")))
	c.cargar("agua")
	_ok("7 mismo elemento: crece a 1,6 y emite crecio", is_equal_approx(c.tamano, LimoVisual3D.TAMANO_GRANDE) and avisos == [LimoVisual3D.TAMANO_GRANDE])
	await _s(1.2)
	_ok("7 el tamaño visible llega a 1,6", is_equal_approx(c._escala.scale.x, 1.6), "escala %.3f" % c._escala.scale.x)
	c.cargar("agua")
	await _s(0.7)
	_ok("7 grande + mismo sigue en 1,6 y no emite", is_equal_approx(c.tamano, 1.6) and avisos.size() == 1 and is_equal_approx(c._escala.scale.x, 1.6))
	var hg: Array = c.dividir()
	_ok("7 el grande se divide en dos de 1,0", hg.size() == 2 and is_equal_approx((hg[0] as LimoVisual3D).tamano, 1.0) and is_equal_approx((hg[1] as LimoVisual3D).tamano, 1.0))
	await _s(1.0)
	var pq := LimoVisual3D.new()
	pq.tamano = 0.6
	base.add_child(pq)
	pq.cargar("rayo")
	await _s(0.5)
	pq.cargar("rayo")
	_ok("7 pequeño + mismo pasa a 1,0", is_equal_approx(pq.tamano, 1.0))
	pq.tamano = 0.6
	_ok("7 un pequeño no se divide", pq.dividir().is_empty())

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _s(seg: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seg * 1000.0:
		await process_frame
