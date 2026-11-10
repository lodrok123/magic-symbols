extends SceneTree
## HUECOS DE GLIFO DEL LIBRO AVANZADO (10/11, Juego; revisión pedida por Pablo: «que se puedan quitar y poner los glifos del 3 al 6, con la progresión»).
## Con el laboratorio del libro avanzado (`laboratorios/LabLibroAvanzado.tscn`), para 3, 4, 5 y 6 huecos abiertos (`Repertoire.max_sigils_per_page`):
##   · entran tantos glifos como huecos abiertos, y nunca en un hueco cerrado
##   · el clic derecho SOBRE un hueco quita ese glifo aunque no sea el último; el siguiente glifo vuelve a ese hueco
##   · el clic derecho fuera de la corona sigue deshaciendo el último
##   · `Grimorio.huecos_abiertos` dice cuántos se dibujan abiertos (los demás, tapados)
## Y la progresión: los engarces FIJAN EL TOTAL (diario 458), máx(base del libro, 1 + engarces) con tope 6.
##   godot --headless --path . --script res://herramientas/prueba_huecos_libro.gd

const GLIFOS: Array = ["flecha", "barrera", "rebote", "pulso", "repeticion", "permanencia", "perforar"]

var _fallos: int = 0


func _initialize() -> void:
	call_deferred("_probar")


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _ocupados(libro: Control) -> Array:
	var r: Array = []
	for i in range(6):
		r.append(String(libro.call("_av_glifo_del_hueco", i)))
	return r


func _clic_derecho(libro: Control, punto: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = punto
	libro.call("_manejar_raton", ev)


func _probar() -> void:
	var lab := load("res://laboratorios/LabLibroAvanzado.tscn").instantiate() as Node
	root.add_child(lab)
	await process_frame
	var g: Grimorio = lab.get("_grimorio") as Grimorio
	var libro: Control = lab.get("_libro") as Control
	for n in [3, 4, 5, 6]:
		g.clear_sequence()
		Repertoire.max_sigils_per_page = n
		for nombre in GLIFOS:
			g.place_sigil(String(nombre))
		var o: Array = _ocupados(libro)
		var cerrados_vacios: bool = true
		for i in range(n, 6):
			cerrados_vacios = cerrados_vacios and String(o[i]) == ""
		_ok("%d huecos: entran %d glifos y ninguno en un hueco cerrado" % [n, n], g.sigils_used() == n and cerrados_vacios and Grimorio.huecos_abiertos() == n, str(o))
		# Quitar el del hueco 2 (el segundo), que no es el último puesto.
		var punto: Vector2 = libro.call("_on_page", libro.call("_av_pos_hueco", 1))
		_clic_derecho(libro, punto)
		var q: Array = _ocupados(libro)
		_ok("%d huecos: el clic derecho sobre el hueco 2 quita SU glifo y deja los demás" % n, String(q[1]) == "" and String(q[0]) == "flecha" and String(q[2]) == "rebote" and g.sigils_used() == n - 1, str(q))
		g.place_sigil("perforar")
		_ok("%d huecos: el siguiente glifo vuelve al hueco que se vació" % n, String(_ocupados(libro)[1]) == "perforar" and g.sigils_used() == n)
		# Deshacer ya no recuerda el glifo quitado: quita el último que sigue puesto (el de perforar, que es el más reciente).
		_clic_derecho(libro, Vector2(5.0, 5.0))
		_ok("%d huecos: el clic derecho fuera de la corona deshace el último puesto" % n, String(_ocupados(libro)[1]) == "" and g.sigils_used() == n - 1, str(_ocupados(libro)))
		g.undo_last()
		g.undo_last()
		_ok("%d huecos: deshacer sigue funcionando hacia atrás sin tocar lo quitado" % n, g.sigils_used() == maxi(n - 3, 0), str(_ocupados(libro)))
	# Sin límite (0 = bancos de pruebas): los seis.
	Repertoire.max_sigils_per_page = 0
	_ok("sin límite, los seis huecos abiertos", Grimorio.huecos_abiertos() == 6)
	# La progresión: los engarces fijan el total.
	var casos: Array = []
	for libro_id in ["bosque", "avanzado"]:
		for engarces in range(6):
			Estado.nuevo()
			Estado.i().mejoras = {"huecos_glifo": engarces} if engarces > 0 else {}
			Repertoire.cambiar_libro(libro_id)
			var base: int = int(Repertoire.HUECOS_BASE_LIBRO[libro_id])
			var esperado: int = maxi(base, mini(1 + engarces, 6))
			if Repertoire.max_sigils_per_page != esperado:
				casos.append("%s+%d: %d (esperado %d)" % [libro_id, engarces, Repertoire.max_sigils_per_page, esperado])
	_ok("progresión: huecos = máx(base del libro, 1 + engarces), tope 6, en los dos libros y de 0 a 5 engarces", casos.is_empty(), str(casos))
	Estado.nuevo()
	Repertoire.cambiar_libro("avanzado")
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
