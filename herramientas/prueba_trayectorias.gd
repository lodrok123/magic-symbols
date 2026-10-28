extends "res://herramientas/escenario_base.gd"
## A4 · TRAYECTORIAS DEL APUNTADO (28/10; docs/PROPUESTA_COMBATE.md §1.3 y §7). Sobre la escena real del Bosque:
##   · REBOTE: el recorrido previsto de una flecha con ᚢ contra una pared se quiebra donde rebota (Apuntado3D pinta un rombo ahí) y el punto final previsto cae a ±0,5 casilla del
##     sitio donde se para el proyectil de verdad (lanzado por `Lanzador3D.lanzar_ahora`);
##   · VIENTO: la previsión pinta la FLECHA FANTASMA hasta donde acaba el enemigo empujado (con su silueta) y, junto al agua honda, «Se hunde»; el destino coincide con el real ±0,5 casilla;
##   · REPETICIÓN: con ᚠ las copias se dibujan tenues y el proyectil del centro entero.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_trayectorias.gd

var _comprobaciones: int = 0
var _creados: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _preparar(c: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	colocar_jugador(c)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _lanzar(datos: Dictionary, dir: Vector3) -> bool:
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(datos, jugador.position, dir)


func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if lista is Array:
				(lista as Array).erase(n)
			(n as Node).queue_free()
	_creados.clear()
	for z in lanzador._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(20)
	await _caso_rebote()
	await _caso_viento()
	await _caso_repeticion()
	_limpiar()
	print("COMPROBACIONES: %d" % _comprobaciones)


## Una casilla pisable con una pared justo al oeste a `n` casillas (y el camino libre), cerca de la zona de pruebas del Bosque.
func _sitio_contra_pared(n: int) -> Vector2i:
	for y in range(20, 60):
		for x in range(1, 40):
			var c := Vector2i(x, y)
			var muro := Vector2i(x - n, y)
			if not Terreno3D.en_mapa(muro) or not Lanzador3D.celda_solida(muro, 0):        # lo sólido para un proyectil (lo que usa `HechizoVivo._avanzar`)
				continue
			var libre: bool = true
			for k in range(0, n):
				var cc := Vector2i(x - k, y)
				if not Terreno3D.en_mapa(cc) or Lanzador3D.celda_solida(cc, 0) or Terreno3D.bloqueada(cc) or Terreno3D.es_agua(cc) or Terreno3D.altura_en(cc) != 0 						or Lanzador3D.celda_solida(cc + Vector2i(0, 1), 0) or Lanzador3D.celda_solida(cc + Vector2i(0, -1), 0):
					libre = false
					break
			if libre:
				return c
	return Vector2i(-1, -1)


func _caso_rebote() -> void:
	var c: Vector2i = _sitio_contra_pared(2)
	_ok("1 hay una pared a 1,5 casillas al oeste de una casilla libre", c.x >= 0, str(c))
	if c.x < 0:
		return
	var oeste := Vector3(-1, 0, 0)
	var d: Dictionary = _preparar(c, "fuego", ["flecha", "rebote"])
	PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
	var rec: Dictionary = PrevisionHechizo.ultimo_recorrido.duplicate(true)
	var caminos: Array = rec.get("caminos", [])
	_ok("1 la previsión trae el recorrido de la flecha", caminos.size() == 1 and (caminos[0] as PackedVector3Array).size() >= 2, str(caminos.size()))
	if caminos.is_empty():
		return
	var q: Array[Vector3] = Apuntado3D.quiebres(caminos[0])
	_ok("1 el recorrido se QUIEBRA en la pared (%d quiebre)" % q.size(), q.size() >= 1)
	var ap := Apuntado3D.new()
	maqueta.add_child(ap)
	_creados.append(ap)
	ap.mostrar(rec, jugador.position, oeste, 0.0, Apuntado3D.color_de("fuego"))
	_ok("1 el apuntado pinta un rombo en cada rebote", ap.rebotes_dibujados.size() == q.size() and q.size() >= 1, str(ap.rebotes_dibujados))
	if not q.is_empty():
		var muro_x: float = float(c.x - 1) * Terreno3D.casilla        # el borde este de la casilla de la pared
		_ok("1 el rombo está junto a la pared (%.2f u)" % absf(q[0].x - muro_x), absf(q[0].x - muro_x) < 0.6 * Terreno3D.casilla)
	var fin_prev: Vector3 = (rec["fines"] as Array)[0] if not (rec["fines"] as Array).is_empty() else Vector3.INF
	_ok("1 la previsión dice dónde se para", fin_prev != Vector3.INF)
	# Lanzar de verdad y seguir el proyectil hasta que se pare.
	var antes: Array = lanzador.get_children().filter(func(n): return n is HechizoVivo)
	_lanzar(d, oeste)
	var vivo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo and not antes.has(n):
			vivo = n
	_ok("1 sale un proyectil de verdad", vivo != null)
	if vivo == null:
		return
	var ultimo: Vector3 = vivo.p
	var rebotes: int = 0
	var t: float = 0.0
	while t < 3.0 and is_instance_valid(vivo) and (vivo.activo or t < 0.05):
		ultimo = vivo.p
		rebotes = vivo.rebotes_usados
		t += await avanzar_s(1.0 / 30.0)
	if is_instance_valid(vivo):
		ultimo = vivo.p
		rebotes = vivo.rebotes_usados
	_ok("1 el proyectil real rebota", rebotes >= 1, str(rebotes))
	var err: float = Vector2(ultimo.x - fin_prev.x, ultimo.z - fin_prev.z).length()
	_ok("1 el punto final previsto cae a ±0,5 casilla del real (%.2f u)" % err, err <= 0.5 * Terreno3D.casilla, "previsto %s · real %s" % [fin_prev, ultimo])
	_limpiar()
	await avanzar(3)


func _caso_viento() -> void:
	var oeste := Vector3(-1, 0, 0)
	var vista := PrevisionReaccion3D.new()
	maqueta.add_child(vista)
	_creados.append(vista)
	# Lejos del agua: empuja.
	var g: Combate3D = _goblin(Vector2i(10, 33))
	var d: Dictionary = _preparar(Vector2i(12, 33), "viento", ["flecha"])
	var prev: Array[Dictionary] = PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
	vista.mostrar(prev)
	var p: Dictionary = {}
	for x in vista.pintado:
		if x["nodo"] == g:
			p = x
	_ok("2 viento: el enemigo lleva la flecha fantasma", not p.is_empty() and bool(p.get("flecha", false)), str(p))
	var fantasmas: Array = vista._fantasmas.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	var puntas: Array = vista._puntas.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	_ok("2 viento: hay una punta de flecha y una silueta", fantasmas.size() == 1 and puntas.size() == 1, "%d · %d" % [fantasmas.size(), puntas.size()])
	if p.is_empty() or fantasmas.is_empty():
		_limpiar()
		return
	var dest: Vector3 = p["destino"]
	var f: Vector3 = (fantasmas[0] as MeshInstance3D).global_position
	_ok("2 viento: la silueta está en el destino previsto", Vector2(f.x - dest.x, f.z - dest.z).length() < 0.05)
	_lanzar(d, oeste)
	await avanzar_s(3.0)
	var err: float = Vector2(g.position.x - dest.x, g.position.z - dest.z).length()
	_ok("2 viento: el enemigo acaba a ±0,5 casilla de la silueta (%.2f u)" % err, err <= 0.5 * Terreno3D.casilla)
	_limpiar()
	await avanzar(3)
	# Junto al agua honda: se hunde.
	vista = PrevisionReaccion3D.new()
	maqueta.add_child(vista)
	_creados.append(vista)
	var g2: Combate3D = _goblin(Vector2i(8, 31))
	d = _preparar(Vector2i(10, 31), "viento", ["flecha"])
	prev = PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
	vista.mostrar(prev)
	var rot: Array = vista._rotulos.filter(func(l: Label3D) -> bool: return l.visible and l.text == "Se hunde")
	_ok("3 viento junto al agua: la flecha fantasma dice «Se hunde»", rot.size() == 1)
	_lanzar(d, oeste)
	await avanzar_s(3.0)
	_ok("3 viento junto al agua: de verdad se hunde", not is_instance_valid(g2) or g2.se_hundio)
	_limpiar()
	await avanzar(3)


func _caso_repeticion() -> void:
	var oeste := Vector3(-1, 0, 0)
	var d: Dictionary = _preparar(Vector2i(12, 33), "fuego", ["flecha", "repeticion", "repeticion"])
	PrevisionHechizo.prever(lanzador, d, jugador.position, oeste)
	var rec: Dictionary = PrevisionHechizo.ultimo_recorrido
	var n: int = (rec.get("caminos", []) as Array).size()
	_ok("4 ᚠᚠ: la previsión trae un recorrido por copia (%d)" % n, n >= 3)
	var ap := Apuntado3D.new()
	maqueta.add_child(ap)
	_creados.append(ap)
	ap.mostrar(rec, jugador.position, oeste, 0.0, Apuntado3D.color_de("fuego"))
	_ok("4 ᚠᚠ: el del centro del abanico va entero y el resto tenue", ap.principal_dibujado == (ap.caminos_dibujados.size() - 1) / 2 and ap.caminos_dibujados.size() == n)
	var tenues: ImmediateMesh = ap._cintas_tenues.mesh as ImmediateMesh
	var enteras: ImmediateMesh = ap._cintas.mesh as ImmediateMesh
	_ok("4 ᚠᚠ: %d cintas tenues y 1 entera" % tenues.get_surface_count(), tenues.get_surface_count() == n - 1 and enteras.get_surface_count() == 1)
	_ok("4 ᚠᚠ: las tenues van a %.0f %% de alfa" % (Apuntado3D.TENUE_COPIAS * 100.0), is_equal_approx(float(ap._mat_tenue.get_shader_parameter("tenue")), Apuntado3D.TENUE_COPIAS))
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	_limpiar()
	await avanzar(3)
