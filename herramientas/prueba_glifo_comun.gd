extends "res://herramientas/prueba_trayectorias.gd"
## EFECTOS COMUNES DE GLIFO (24/11, sesión HECHIZOS; `presentacion/vfx/glifo_comun_vfx.gd`) en la escena real del Bosque, lanzando de verdad:
##   · el juego monta GlifoComunVfx;
##   · flecha sola: ningún efecto de glifo;
##   · ᚠᚠ (abanico): UNO por disparo, en la mano, con un trazo por copia y la runa ᚠ;
##   · ᛇ antes de ᚠ (ráfaga): uno, en fila;
##   · ᚢ contra una pared: uno por rebote real, en el punto del rebote;
##   · con fuego, tierra y agua (no depende del elemento);
##   · `activo = false` lo calla.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_glifo_comun.gd

var _gc: GlifoComunVfx = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(20)
	_gc = root.find_child("GlifoComunVfx", true, false) as GlifoComunVfx
	_ok("0 el juego monta GlifoComunVfx", _gc != null)
	if _gc == null:
		return
	var oeste := Vector3(-1, 0, 0)
	for el in ["fuego", "tierra", "agua"]:
		await _caso_copias(el, oeste)
	await _caso_rebote_real(oeste)
	await _caso_callado(oeste)
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _cuenta(k: String) -> int:
	return int(GlifoComunVfx.cuenta[k])


func _nodos(nombre: String) -> Array:
	return _gc.get_parent().find_children(nombre + "*", "Node3D", true, false)


func _disparar(c: Vector2i, el: String, glifos: Array, dir: Vector3) -> void:
	var d: Dictionary = _preparar(c, el, glifos)
	lanzador.ultimo_disparo = {"dir": dir}
	_lanzar(d, dir)
	await avanzar(2)


func _caso_copias(el: String, dir: Vector3) -> void:
	var c := Vector2i(12, 33)
	var r0: int = _cuenta("repeticion")
	await _disparar(c, el, ["flecha"], dir)
	_ok("%s flecha sola: sin efecto de glifo" % el, _cuenta("repeticion") == r0)
	await avanzar_s(1.5)
	# ᚠᚠ antes de ᛇ: ABANICO (todas a la vez); ᛇ antes de ᚠᚠ: RÁFAGA (en fila, `Hechizo.rafaga`).
	for caso in [["abanico", ["repeticion", "repeticion", "flecha"]], ["ráfaga", ["flecha", "repeticion", "repeticion"]]]:
		r0 = _cuenta("repeticion")
		var n_antes: int = _nodos("GlifoRepeticion").size()
		await _disparar(c, el, caso[1], dir)
		var h: Hechizo = lanzador.get_children().filter(func(x): return x is HechizoVivo).back().h if not lanzador.get_children().filter(func(x): return x is HechizoVivo).is_empty() else null
		var nodos: Array = _nodos("GlifoRepeticion")
		var nombre: String = "%s ᚠᚠ %s" % [el, caso[0]]
		_ok("%s: UN efecto por disparo" % nombre, _cuenta("repeticion") == r0 + 1 and nodos.size() == n_antes + 1, "%d → %d" % [r0, _cuenta("repeticion")])
		if nodos.size() > n_antes:
			var g: Node3D = nodos[nodos.size() - 1]
			var trazos: int = g.get_children().filter(func(x): return String(x.name).begins_with("Trazo")).size()
			var runa: Node = g.get_node_or_null("Runa_repeticion")
			var esperados: int = 3
			_ok("%s: %d trazos y la runa ᚠ visible" % [nombre, trazos], trazos == esperados and runa != null and (runa as Node3D).visible, "rafaga=%s" % [h.rafaga if h != null else "?"])
			_ok("%s: en la mano" % nombre, Vector2(g.global_position.x - jugador.position.x, g.global_position.z - jugador.position.z).length() < Terreno3D.casilla * 0.8)
		await avanzar_s(1.5)
	_limpiar()
	await avanzar(3)


func _caso_rebote_real(dir: Vector3) -> void:
	var c: Vector2i = _sitio_contra_pared(2)
	_ok("R hay una pared a 1,5 casillas", c.x >= 0)
	if c.x < 0:
		return
	var b0: int = _cuenta("rebote")
	var d: Dictionary = _preparar(c, "fuego", ["flecha", "rebote"])
	var antes: Array = lanzador.get_children().filter(func(n): return n is HechizoVivo)
	_lanzar(d, dir)
	var vivo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo and not antes.has(n):
			vivo = n
	var rebotes: int = 0
	var puntos: Array = []
	if vivo != null:
		vivo.rebotado.connect(func(p, _n): puntos.append(p))
	var t: float = 0.0
	while t < 3.0 and vivo != null and is_instance_valid(vivo) and vivo.activo:
		rebotes = vivo.rebotes_usados
		t += await avanzar_s(1.0 / 30.0)
	_ok("R el proyectil real rebota", puntos.size() >= 1, str(puntos.size()))
	_ok("R un ᚢ por rebote (%d rebotes, %d efectos)" % [puntos.size(), _cuenta("rebote") - b0], _cuenta("rebote") - b0 == puntos.size() and puntos.size() >= 1)
	var nodos: Array = _nodos("GlifoRebote")
	if not puntos.is_empty() and not nodos.is_empty():
		var g: Node3D = nodos[0]
		_ok("R el ᚢ está donde rebotó", g.global_position.distance_to(puntos[0] as Vector3) < 0.05)
	_limpiar()
	await avanzar(3)


func _caso_callado(dir: Vector3) -> void:
	GlifoComunVfx.activo = false
	var r0: int = _cuenta("repeticion")
	await _disparar(Vector2i(12, 33), "fuego", ["flecha", "repeticion"], dir)
	_ok("activo = false: no dibuja nada", _cuenta("repeticion") == r0)
	GlifoComunVfx.activo = true
	_limpiar()
	await avanzar(3)
