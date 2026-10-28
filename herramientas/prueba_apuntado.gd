extends "res://herramientas/prueba_prevision_reaccion.gd"
## EL ASPECTO DEL APUNTADO (28/10; presentacion/apuntado_3d.gd). Sobre la escena real (PruebaBosque) y con el modo de apuntar de verdad (`cast_page`):
##   · un proyectil dibuja su RECORRIDO real (el vuelo en seco de A2), que acaba donde la previsión dice que se para, con una retícula ahí, y sin la caja de su cuerpo bajo la jugadora;
##   · un arco (tierra) dibuja su sombra en el suelo; una flecha a la altura de la mano también (vuela por encima de 0,35 u); la repetición, un recorrido y tres retículas;
##   · la barrera (nace donde apuntas) enseña sus casillas, un hilo de la jugadora al origen, el anillo de alcance y ninguna retícula; fuera de alcance, el origen se queda en el borde;
##   · el haz (rayo + línea) dibuja la recta de la mano a la punta, sin cajas;
##   · un «no se puede» pinta la retícula en rojo con X y escribe el motivo;
##   · nada de esto se queda al salir del modo, y pintar cada fotograma no crea nodos.
## Segunda tanda (cursor y fantasma):
##   · lo que nace y se queda (barreras de fuego, tierra, hielo, agua) enseña un FANTASMA por casilla que ocupará, con la textura de su elemento; un proyectil o un haz, ninguno;
##   · mientras se apunta, el cursor es la retícula del elemento (`cursor_puesto`), y al salir vuelve el del sistema; la imagen del cursor tiene la retícula y, con X, otra forma.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_apuntado.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(30)
	await _caso_flecha()
	await _caso_arco_y_copias()
	await _caso_barrera()
	await _caso_haz()
	await _caso_no_se_puede()
	await _caso_fantasmas()
	await _caso_cursor()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _caso_fantasmas() -> void:
	var oeste := Vector3(-1, 0, 0)
	for el in ["fuego", "tierra", "hielo", "agua"]:
		await _apuntar(Vector2i(12, 34), el, ["barrera"], oeste, 2.0)
		var ap: Apuntado3D = _ap()
		var vols: Array = PrevisionHechizo.ultimo_recorrido.get("volumenes", [])
		var celdas: Array = []
		for v in vols:
			celdas.append_array((v["volumen"] as Dictionary).get("celdas", []))
		var bien: bool = ap.fantasmas_dibujados.size() == celdas.size() and celdas.size() >= 1
		for k in range(mini(ap.fantasmas_dibujados.size(), celdas.size())):
			var f: Dictionary = ap.fantasmas_dibujados[k]
			var c: Vector2i = celdas[k]
			bien = bien and Terreno3D.celda_de(f["pie"]) == c and absf((f["pie"] as Vector3).y - Terreno3D.y_pies(c)) < 0.01 and String(f["elemento"]) == el
			bien = bien and float(f["radio"]) >= 0.4 * Terreno3D.casilla and float(f["alto"]) >= 0.5 * Terreno3D.casilla
		_ok("8 barrera de %s: un fantasma por casilla que ocupará (%d), en su suelo, del tamaño de la casilla" % [el, celdas.size()], bien, str(ap.fantasmas_dibujados))
		var tipo: int = int(((ap._fantasmas[0].material_override as ShaderMaterial).get_shader_parameter("tipo"))) if not ap._fantasmas.is_empty() else -1
		_ok("8 barrera de %s: con la textura de su elemento (tipo %d)" % [el, tipo], tipo == int(Apuntado3D.TIPO_FANTASMA[el]))
		await _soltar_sin_lanzar()
	await _apuntar(Vector2i(12, 31), "fuego", ["flecha"], oeste, 3.0)
	_ok("8 un proyectil no deja fantasma (se ve su recorrido y su retícula)", _ap().fantasmas_dibujados.is_empty())
	await _soltar_sin_lanzar()
	await _apuntar(Vector2i(12, 32), "rayo", ["linea_z"], oeste, 3.0)
	_ok("8 un haz no deja fantasma", _ap().fantasmas_dibujados.is_empty())
	await _soltar_sin_lanzar()


func _caso_cursor() -> void:
	_ok("9 sin apuntar, el cursor es el del sistema", lanzador.cursor_puesto == "")
	await _apuntar(Vector2i(12, 31), "hielo", ["flecha"], Vector3(-1, 0, 0), 3.0)
	_ok("9 apuntando, el cursor es la retícula del color del hielo", lanzador.cursor_puesto == "%s|false" % Apuntado3D.color_de("hielo").to_html(), lanzador.cursor_puesto)
	await _soltar_sin_lanzar()
	_ok("9 al salir, vuelve el del sistema", lanzador.cursor_puesto == "")
	var a: Image = Apuntado3D.imagen_cursor(Apuntado3D.color_de("fuego"))
	var x: Image = Apuntado3D.imagen_cursor(Apuntado3D.COLOR_NO, true)
	var c: int = Apuntado3D.TAM_CURSOR / 2
	_ok("9 la imagen del cursor mide %d px, el anillo es del color y las esquinas transparentes" % Apuntado3D.TAM_CURSOR,
		a.get_width() == Apuntado3D.TAM_CURSOR and Vector4(a.get_pixel(c + 15, c).r, a.get_pixel(c + 15, c).g, a.get_pixel(c + 15, c).b, a.get_pixel(c + 15, c).a).distance_to(
		Vector4(Apuntado3D.color_de("fuego").r, Apuntado3D.color_de("fuego").g, Apuntado3D.color_de("fuego").b, 1.0)) < 0.01 and a.get_pixel(0, 0).a == 0.0, str(a.get_pixel(c + 15, c)))
	_ok("9 con X: hay X donde la retícula tiene hueco", x.get_pixel(c + 5, c + 5).a > 0.5 and a.get_pixel(c + 5, c + 5).a == 0.0)


func _ap() -> Apuntado3D:
	return lanzador._apuntado


func _cajas_visibles() -> int:
	return lanzador._prev_casillas.filter(func(m): return (m as MeshInstance3D).visible).size()


func _caso_flecha() -> void:
	var oeste := Vector3(-1, 0, 0)
	await _apuntar(Vector2i(12, 31), "fuego", ["flecha"], oeste, 3.0)
	var ap: Apuntado3D = _ap()
	_ok("1 al apuntar existe el dibujo del apuntado", ap != null and is_instance_valid(ap) and ap.is_inside_tree())
	var rec: Dictionary = PrevisionHechizo.ultimo_recorrido
	_ok("1 flecha: un recorrido dibujado, el de la previsión", ap.caminos_dibujados.size() == 1 and (rec["caminos"] as Array).size() == 1 and ap.caminos_dibujados[0] == rec["caminos"][0],
		"%d dibujados" % ap.caminos_dibujados.size())
	var c: PackedVector3Array = ap.caminos_dibujados[0]
	var fin: Vector3 = (rec["fines"] as Array)[0]
	_ok("1 el recorrido acaba donde la flecha se para (%s)" % str(fin), c[c.size() - 1].is_equal_approx(fin))
	_ok("1 empieza en la jugadora (a < 1 u en planta)", Vector2(c[0].x - jugador.position.x, c[0].z - jugador.position.z).length() < 1.0, str(c[0]))
	_ok("1 una retícula, en el suelo bajo donde se para", ap.reticulas.size() == 1 and Vector2(ap.reticulas[0].x - fin.x, ap.reticulas[0].z - fin.z).length() < 0.01
		and absf(ap.reticulas[0].y - (Terreno3D.y_pies(Terreno3D.celda_de(fin)) + 0.1)) < 0.01, str(ap.reticulas))
	_ok("1 sin la caja de su cuerpo bajo la jugadora", _cajas_visibles() == 0, "%d cajas" % _cajas_visibles())
	_ok("1 sin anillo de alcance (no nace donde apuntas)", not lanzador._marca_alcance.visible)
	_ok("1 el color es el del fuego en el indicador, no el de la runa", lanzador._prev_color.is_equal_approx(Apuntado3D.color_de("fuego")))
	var hijos: int = ap.get_child_count()
	for _i in range(30):
		lanzador._pintar_marcadores()
	_ok("1 pintar 30 veces no crea nodos (%d)" % hijos, ap.get_child_count() == hijos)
	await _soltar_sin_lanzar()
	_ok("1 al salir del modo el dibujo se va", lanzador._apuntado == null and not is_instance_valid(ap))


func _caso_arco_y_copias() -> void:
	var oeste := Vector3(-1, 0, 0)
	await _apuntar(Vector2i(12, 34), "tierra", ["flecha"], oeste, 3.0)
	var ap: Apuntado3D = _ap()
	var c: PackedVector3Array = ap.caminos_dibujados[0]
	var y_max: float = -INF
	for q in c:
		y_max = maxf(y_max, q.y - Terreno3D.y_pies(Terreno3D.celda_de(q)))
	_ok("2 la flecha de tierra sube en arco (%.2f u sobre el suelo)" % y_max, y_max > 1.0)
	_ok("2 y dibuja su sombra en el suelo", ap._sombras.visible)
	await _soltar_sin_lanzar()
	await _apuntar(Vector2i(12, 34), "hielo", ["flecha", "repeticion", "repeticion"], oeste, 3.0)
	ap = _ap()
	var n: int = (PrevisionHechizo.ultimo_recorrido["caminos"] as Array).size()
	_ok("3 flecha con dos repeticiones: tres recorridos y tres retículas (copias previstas: %d)" % n, n == 3 and ap.caminos_dibujados.size() == 3 and ap.reticulas.size() == 3)
	await _soltar_sin_lanzar()


func _caso_barrera() -> void:
	var oeste := Vector3(-1, 0, 0)
	await _apuntar(Vector2i(12, 34), "tierra", ["barrera"], oeste, 2.0)
	var ap: Apuntado3D = _ap()
	var o: Vector3 = lanzador._origen_vivo
	_ok("4 barrera: nace a 2 casillas, donde se apunta", absf(Vector2(o.x - jugador.position.x, o.z - jugador.position.z).length() - 2.0 * Terreno3D.casilla) < 0.05)
	_ok("4 enseña sus casillas (fantasma)", _cajas_visibles() >= 1)
	_ok("4 con anillo de alcance, centrado en ella", lanzador._marca_alcance.visible and Vector2(lanzador._marca_alcance.position.x - jugador.position.x, lanzador._marca_alcance.position.z - jugador.position.z).length() < 0.05)
	_ok("4 un hilo de la jugadora al origen y ninguna retícula", ap.caminos_dibujados.size() == 1 and ap.reticulas.is_empty()
		and Vector2(ap.caminos_dibujados[0][1].x - o.x, ap.caminos_dibujados[0][1].z - o.z).length() < 0.05
		and Vector2(ap.caminos_dibujados[0][0].x - jugador.position.x, ap.caminos_dibujados[0][0].z - jugador.position.z).length() < 0.05)
	_ok("4 el origen marcado está en el origen", Vector2(lanzador._marca_origen.position.x - o.x, lanzador._marca_origen.position.z - o.z).length() < 0.05)
	_mover_puntero(oeste, 6.0)
	await avanzar(4)
	o = lanzador._origen_vivo
	var lejos: float = Vector2(o.x - jugador.position.x, o.z - jugador.position.z).length()
	_ok("5 apuntando a 6 casillas, el origen se queda en el borde del alcance (%.2f u)" % lejos, absf(lejos - Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla) < 0.05)
	_ok("5 y las casillas, con él", _cajas_visibles() >= 1 and Terreno3D.celda_de(lanzador._prev_casillas[0].position) == Terreno3D.celda_de(o))
	await _soltar_sin_lanzar()


func _caso_haz() -> void:
	_goblin(Vector2i(9, 32))
	await avanzar(3)
	await _apuntar(Vector2i(12, 32), "rayo", ["linea_z"], Vector3(-1, 0, 0), 3.0)
	var ap: Apuntado3D = _ap()
	_ok("6 haz: un recorrido (de la mano a la punta) y sin cajas", ap.caminos_dibujados.size() == 1 and ap.caminos_dibujados[0].size() == 2 and _cajas_visibles() == 0,
		"%d recorridos · %d cajas" % [ap.caminos_dibujados.size(), _cajas_visibles()])
	if ap.caminos_dibujados.size() == 1:
		var c: PackedVector3Array = ap.caminos_dibujados[0]
		_ok("6 sale a la altura de la mano y acaba a ras del suelo", c[0].y > c[1].y + 0.3, str(c))
		_ok("6 llega al goblin (la punta pasa de su casilla hacia el oeste)", c[1].x <= (9.5) * Terreno3D.casilla + 0.1, str(c[1]))
	await _soltar_sin_lanzar()
	_limpiar()
	await avanzar(3)


func _caso_no_se_puede() -> void:
	# Ningún hechizo del kit se rechaza en el Bosque sin montar un caso raro: se pide el dibujo de «no se puede» directamente, como lo pide `_pintar_previsualizacion`.
	var ap := Apuntado3D.new()
	maqueta.add_child(ap)
	await avanzar(1)
	var o: Vector3 = Terreno3D.centro_de(Vector2i(10, 34), Terreno3D.y_pies(Vector2i(10, 34)))
	ap.mostrar({}, o, Vector3(-1, 0, 0), 0.0, Apuntado3D.color_de("tierra"), "queda fuera de tu alcance")
	_ok("7 no se puede: una retícula roja con X en el origen", ap.reticulas.size() == 1 and Vector2(ap.reticulas[0].x - o.x, ap.reticulas[0].z - o.z).length() < 0.01
		and bool(((ap._discos[0].mesh as PlaneMesh).material as ShaderMaterial).get_shader_parameter("cruz"))
		and (((ap._discos[0].mesh as PlaneMesh).material as ShaderMaterial).get_shader_parameter("color") as Color).is_equal_approx(Apuntado3D.COLOR_NO))
	_ok("7 y el motivo escrito encima", ap._rotulo.visible and ap._rotulo.text == "queda fuera de tu alcance" and ap.motivo_visible == "queda fuera de tu alcance")
	ap.mostrar({}, o, Vector3(-1, 0, 0), 0.0, Apuntado3D.color_de("tierra"))
	_ok("7 cuando vuelve a poderse, se quitan la X y el motivo", not ap._rotulo.visible and ap.reticulas.is_empty())
	ap.queue_free()
	await avanzar(1)
