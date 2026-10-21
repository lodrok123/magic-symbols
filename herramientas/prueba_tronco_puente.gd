extends "res://herramientas/escenario_base.gd"
## TRONCO-PUENTE DE ORILLA A ORILLA (Juego, 21/10, tras el playtest de Pablo: «el tronco no llega al otro lado»). Carga el Bosque 01 de verdad y MIDE:
##   1. el río en el sitio del tronco (casillas de agua, borde a borde) y el tronco tal como se dibuja ya caído (vértices del modelo en coordenadas del
##      mundo): la punta de arriba pasa el borde lejano y el pie queda dentro de su orilla, con margen; el grosor no se estira; la cara de arriba
##      queda a la altura que se pisa;
##   2. las casillas que cubre: `b`, pisables, a la altura de la cara de arriba (`Terreno3D.y_pies`);
##   3. el jugador cruza ANDANDO de verdad (teclas) de una orilla a otra sin nadar ni hundirse; una ruta de `Caminos3D` y un goblin con IA lo cruzan;
##   4. el largo sale del ancho del río: un río de 3 casillas (mundo sintético) da un tronco de 3 y cubre las tres.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_tronco_puente.gd
## Qué NO prueba: el aspecto (hace falta ventana: herramientas/captura_tronco_puente.gd).

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const TOLERANCIA_PASO: float = 0.55        ## Jugador3D.TOLERANCIA_SUELO: lo que se sube sin saltar

var _muestras: Array = []                  ## [celda, y, nadando] del jugador, un registro por fotograma mientras cruza


func _escenario() -> void:
	await cargar(RUTA, true)
	var reglas: Node = maqueta.get_node_or_null("Reglas")
	_ok("1 la escena trae su nodo Reglas", reglas != null)
	if reglas == null:
		return
	await avanzar(10)
	var t: TroncoPuente3D = reglas.get("_tronco_puente") as TroncoPuente3D
	_ok("2 hay un tronco-puente", t != null)
	if t == null:
		return
	await _rio_y_tronco(t)
	await _cruce_andando(t)
	await _ruta_y_goblin(t)
	await _rio_ancho()


# ---------------------------------------------------------------------------------------------------------------------
#  1-2. Medir el río y el tronco caído
# ---------------------------------------------------------------------------------------------------------------------
func _rio_y_tronco(t: TroncoPuente3D) -> void:
	var cas: float = Terreno3D.casilla
	var d: Vector3 = t.direccion
	var base: Vector3 = t.position
	var celdas: Array[Vector2i] = t.celdas_rio
	# El río por fuera, sin fiarse de lo que calculó el tronco: se cuentan las casillas `~` desde la primera en la dirección de caída.
	var paso := Vector2i(roundi(d.x), roundi(d.z))
	var n_real: int = 0
	var c: Vector2i = t.celda_puente
	while Terreno3D.letra_de(c) == "~":
		n_real += 1
		c += paso
	var banco_lejano: Vector2i = c
	var banco_cercano: Vector2i = t.celda_puente - paso
	var s_cerca: float = (Terreno3D.centro_de(t.celda_puente) - base).dot(d) - cas * 0.5
	var s_lejos: float = s_cerca + float(n_real) * cas
	print("      [medida] río de %d casilla(s) de agua: borde cercano a %.2f u del pie, lejano a %.2f u (ancho %.2f u). Orillas %s y %s." % [n_real, s_cerca, s_lejos, s_lejos - s_cerca, str(banco_cercano), str(banco_lejano)])
	_ok("3.1 el tronco cuenta las mismas casillas de agua que hay (%d)" % n_real, celdas.size() == n_real and n_real >= 1, "cuenta %d" % celdas.size())
	_ok("3.2 las dos orillas son suelo andable antes de caer", Terreno3D.pisable(banco_cercano, 0, false, 0, false) and Terreno3D.pisable(banco_lejano, 0, false, 0, false, true))
	_ok("3.3 antes de caer el agua NO se pisa (sin nadar)", not Terreno3D.pisable(t.celda_puente, 0, false, 0, false))
	var ruta_antes: Array[Vector2i] = Caminos3D.camino(banco_cercano, banco_lejano)
	_ok("3.4 antes de caer no hay ruta de una orilla a otra", ruta_antes.is_empty(), "ruta de %d casillas" % ruta_antes.size())

	t.on_spell_hit(_fuego_(), Vector3.ZERO)
	await avanzar_s(TroncoPuente3D.T_ARDE + TroncoPuente3D.T_CAIDA + 0.8)
	_ok("4.1 cayó", t.cayo)
	var modelo: bool = t.get("_caido_modelo") != null
	var piv: Node3D = t.get("_pivote") as Node3D
	var pie: MeshInstance3D = null
	for h in piv.get_children():
		if h is MeshInstance3D and (h as MeshInstance3D).mesh != null and h.name == "tronco_puente_pie":
			pie = h as MeshInstance3D
	if modelo and pie != null:
		var perp := Vector3(-d.z, 0.0, d.x)
		var gt: Transform3D = pie.global_transform
		var s_min: float = INF
		var s_max: float = -INF
		var lat_min: float = INF
		var lat_max: float = -INF
		var lat_mod_min: float = INF
		var lat_mod_max: float = -INF
		var tops: Dictionary = {}           # tajada de 0,2 del modelo -> y máxima en el mundo
		var cima_centro: float = -INF       # la y más alta bajo el centro de la casilla del río
		var s_centro: float = (s_cerca + s_lejos) * 0.5
		var mesh: Mesh = pie.mesh
		for sidx in range(mesh.get_surface_count()):
			var vs: PackedVector3Array = mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]
			for v in vs:
				var w: Vector3 = gt * v
				var s: float = (w - base).dot(d)
				s_min = minf(s_min, s)
				s_max = maxf(s_max, s)
				if v.y >= 0.4 and v.y <= 2.5:                 # el tronco sin la base de piedras ni la punta rota
					var lat: float = (w - base).dot(perp)
					lat_min = minf(lat_min, lat)
					lat_max = maxf(lat_max, lat)
					lat_mod_min = minf(lat_mod_min, v.z)
					lat_mod_max = maxf(lat_mod_max, v.z)
					var k: int = int(floor(v.y / 0.2))
					tops[k] = maxf(float(tops.get(k, -INF)), w.y)
				if absf(s - s_centro) < 0.3:
					cima_centro = maxf(cima_centro, w.y)
		var maximos: Array = tops.values()
		maximos.sort()
		var mediana: float = float(maximos[maximos.size() / 2])
		var largo_real: float = s_max - s_min
		print("      [medida] tronco caído: del pie (s=%.2f) a la punta (s=%.2f) = %.2f u; estirado %.3f solo a lo largo; ancho del tronco %.2f (modelo %.2f); lomo a y=%.3f (cara %.3f); orilla %.3f" % [s_min, s_max, largo_real, t.escala_largo, lat_max - lat_min, lat_mod_max - lat_mod_min, mediana, t.y_cara, base.y])
		_ok("4.2 la punta pasa el borde lejano del río con apoyo (≥ 0,4 u dentro de la orilla; la punta mide %.2f, el borde %.2f)" % [s_max, s_lejos], s_max >= s_lejos + 0.4, "apoya %.2f u" % (s_max - s_lejos))
		_ok("4.3 el pie queda dentro de su orilla con apoyo (≥ 0,3 u antes del borde cercano; pie %.2f, borde %.2f)" % [s_min, s_cerca], s_min <= s_cerca - 0.3, "apoya %.2f u" % (s_cerca - s_min))
		_ok("4.4 no hay hueco: el tronco cubre del borde cercano al lejano de corrido", s_min <= s_cerca and s_max >= s_lejos)
		_ok("4.5 solo se estira el eje largo: el grosor del tronco es el del modelo (±3 %)", absf((lat_max - lat_min) - (lat_mod_max - lat_mod_min)) <= 0.03 * (lat_mod_max - lat_mod_min), "%.3f frente a %.3f" % [lat_max - lat_min, lat_mod_max - lat_mod_min])
		_ok("4.6 el estirado es el justo para el río (largo %.2f / 2,6) y razonable (≤ 1,6)" % t.largo, absf(t.escala_largo - t.largo / TroncoPuente3D.LARGO_MODELO) < 1.0e-4 and t.escala_largo <= 1.6, "×%.3f" % t.escala_largo)
		_ok("4.7 el lomo del tronco (mediana de la malla) está a la altura que se pisa (±0,1)", absf(mediana - t.y_cara) <= 0.1, "lomo %.3f, cara %.3f" % [mediana, t.y_cara])
		_ok("4.8 bajo el centro del río el punto más alto del tronco está a la altura que se pisa (±0,15)", absf(cima_centro - t.y_cara) <= 0.15, "cima %.3f, cara %.3f" % [cima_centro, t.y_cara])
		_ok("4.9 el modelo de la mesa (CARA_MODELO %.2f) coincide con la malla medida (±0,06)" % TroncoPuente3D.CARA_MODELO, absf((mediana - piv.global_position.y) - TroncoPuente3D.CARA_MODELO) <= 0.06, "malla %.3f" % (mediana - piv.global_position.y))
	else:
		_aviso("4.2-4.9 medidas del modelo", "sin la lámina bosque_ruinas.glb: se usó el cilindro; solo se miden las casillas")
		var cil: Node3D = piv.get_node_or_null("tronco") as Node3D
		_ok("4.2c el cilindro mide lo que el río pide (%.2f)" % t.largo, cil != null and absf((cil.get("mesh") as CylinderMesh).height - t.largo) < 1.0e-3)
	for cc in celdas:
		_ok("5.1 la casilla %s es puente (b) y se pisa" % str(cc), Terreno3D.letra_de(cc) == "b" and Terreno3D.pisable(cc, 0, false, 0, false))
		_ok("5.2 …y los pies van a la altura de la cara del tronco (%.3f)" % t.y_cara, absf(Terreno3D.y_pies(cc) - t.y_cara) < 1.0e-4, "y_pies %.3f" % Terreno3D.y_pies(cc))
	for cc in celdas:
		_ok("5.2b %s: sobre el tronco no es agua (ni se nada) pero la corriente de debajo sigue conduciendo" % str(cc), not Terreno3D.es_agua(cc) and not Terreno3D.se_nada(cc) and Terreno3D.conduce(cc))
	_ok("5.3 las casillas de las orillas siguen a su altura de siempre", absf(Terreno3D.y_pies(banco_cercano) - base.y) < 1.0e-4 and absf(Terreno3D.y_pies(banco_lejano) - base.y) < 1.0e-4)
	_ok("5.4 el escalón de la orilla al tronco se anda sin saltar (%.2f ≤ %.2f)" % [t.y_cara - base.y, TOLERANCIA_PASO], t.y_cara - base.y <= TOLERANCIA_PASO)
	_ok("5.5 la regla de pisable deja pasar de una orilla a la otra casilla a casilla", _cruzable(banco_cercano, banco_lejano, celdas, paso))


## Casilla a casilla, con la misma regla de Jugador3D._puede_estar (pisable subiendo un nivel y el escalón de y).
func _cruzable(a: Vector2i, b: Vector2i, celdas: Array[Vector2i], paso: Vector2i) -> bool:
	var ruta: Array[Vector2i] = []
	ruta.append_array(celdas)
	ruta.append(b)
	var actual: Vector2i = a
	var y: float = Terreno3D.y_pies(a)
	for c in ruta:
		if not Terreno3D.pisable(c, Terreno3D.altura_en(actual), true, 1, false, Terreno3D.es_parcial(c)):
			return false
		if Terreno3D.y_pies(c) > y + TOLERANCIA_PASO:
			return false
		y = Terreno3D.y_pies(c)
		actual = c
	return actual == b


# ---------------------------------------------------------------------------------------------------------------------
#  3. Cruzar andando de verdad
# ---------------------------------------------------------------------------------------------------------------------
func _cruce_andando(t: TroncoPuente3D) -> void:
	var paso := Vector2i(roundi(t.direccion.x), roundi(t.direccion.z))
	var origen: Vector2i = t.celda_puente - paso * 2          # una casilla ANTES de la orilla del tronco, ya en tierra
	var destino: Vector2i = t.celda_puente + paso * (t.celdas_rio.size() + 1)     # la casilla de la otra orilla
	colocar_jugador(origen)
	await avanzar(10)
	_muestras.clear()
	var grabar := func() -> void:
		_muestras.append([celda_jugador(), jugador.position.y, bool(jugador.get("nadando")), jugador.position])
	process_frame.connect(grabar)
	var llego: bool = await mover_hacia(destino, 20.0, 0.6)
	process_frame.disconnect(grabar)
	var en_puente: Array = []
	var nado: bool = false
	for m in _muestras:
		# Solo cuenta el tramo de la casilla donde YA ha subido (a más de 0,6 u del borde de la casilla): el escalón de entrada se sube a 9 u/s y las
		# primeras muestras van de camino (1,035 → 1,385), eso es subir, no hundirse.
		var pos: Vector3 = m[3]
		var cen: Vector3 = Terreno3D.centro_de(m[0] as Vector2i)
		if t.celdas_rio.has(m[0] as Vector2i) and absf((pos - cen).dot(t.direccion)) < Terreno3D.casilla * 0.5 - 0.6:
			en_puente.append(float(m[1]))
		nado = nado or bool(m[2])
	var y_min: float = INF
	var y_max: float = -INF
	for y in en_puente:
		y_min = minf(y_min, float(y))
		y_max = maxf(y_max, float(y))
	print("      [medida] el jugador pasó %d fotogramas sobre el tronco: y entre %.3f y %.3f (cara %.3f); %d muestras en total" % [en_puente.size(), y_min if not en_puente.is_empty() else 0.0, y_max if not en_puente.is_empty() else 0.0, t.y_cara, _muestras.size()])
	_ok("6.1 el jugador cruza andando de %s a %s (llega a %s)" % [str(origen), str(destino), str(celda_jugador())], llego and celda_jugador().x * paso.x + celda_jugador().y * paso.y >= (t.celdas_rio[0].x * paso.x + t.celdas_rio[0].y * paso.y), "llegó=%s" % str(llego))
	_ok("6.2 pasó por encima del tronco (hay fotogramas en las casillas del río)", not en_puente.is_empty())
	_ok("6.3 nunca nadó ni cayó al agua", not nado)
	if not en_puente.is_empty():
		_ok("6.4 no se hunde: sobre el tronco sus pies nunca bajan de la cara (−0,05)", y_min >= t.y_cara - 0.05, "mín %.3f" % y_min)
		_ok("6.5 …ni flota por encima de ella (+0,1)", y_max <= t.y_cara + 0.1, "máx %.3f" % y_max)
	# Y la vuelta, por el mismo sitio (el escalón de bajada).
	var vuelta: bool = await mover_hacia(origen, 20.0, 0.6)
	_ok("6.6 y vuelve de la otra orilla a la primera", vuelta, "en %s" % str(celda_jugador()))
	# Un salto sobre el tronco: la simulación sigue viendo agua debajo (la letra cambió, la profundidad no), y al aterrizar el jugador NO debe ponerse a
	# nadar (se hundiría a través del tronco). Es lo que arregla `Terreno3D.se_nada` («b» nunca se nada).
	if not bool(jugador.get("salto_activo")):
		_aviso("6.7 salto sobre el tronco", "el salto está desactivado en este nivel: no se prueba")
		return
	colocar_jugador(t.celdas_rio[0])
	await avanzar_s(0.5)
	_tecla(KEY_SPACE, true)
	await avanzar_s(0.15)
	_tecla(KEY_SPACE, false)
	var nado_salto: bool = false
	var y_aire: float = -INF
	var inicio: float = reloj.t
	while reloj.t - inicio < 1.6:
		await process_frame
		nado_salto = nado_salto or bool(jugador.get("nadando"))
		y_aire = maxf(y_aire, jugador.position.y)
	_ok("6.7 salta sobre el tronco (llega a %.2f por encima de la cara) y aterriza sin ponerse a nadar" % (y_aire - t.y_cara), y_aire > t.y_cara + 0.3 and not nado_salto, "nadó=%s" % str(nado_salto))
	_ok("6.8 …y vuelve a quedar sobre la cara del tronco (%.3f)" % t.y_cara, absf(jugador.position.y - t.y_cara) < 0.05, "y %.3f" % jugador.position.y)


# ---------------------------------------------------------------------------------------------------------------------
#  3b. Rutas y goblins
# ---------------------------------------------------------------------------------------------------------------------
func _ruta_y_goblin(t: TroncoPuente3D) -> void:
	var paso := Vector2i(roundi(t.direccion.x), roundi(t.direccion.z))
	var a: Vector2i = t.celda_puente - paso * 2
	var b: Vector2i = t.celda_puente + paso * (t.celdas_rio.size() + 1)
	var ruta: Array[Vector2i] = Caminos3D.camino(a, b)
	var pasa: bool = not ruta.is_empty()
	for c in t.celdas_rio:
		pasa = pasa and ruta.has(c)
	_ok("7.1 tras caer, una ruta de Caminos3D de %s a %s atraviesa las casillas del tronco (%d casillas)" % [str(a), str(b), ruta.size()], pasa, str(ruta))
	# Un goblin con IA, como en prueba_caminos: va «a la última posición vista», que está al otro lado del río.
	var p: Vector3 = Terreno3D.centro_de(a, Terreno3D.y_pies(a))
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	maqueta.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador, lanzador)
	g.set_physics_process(false)
	g.position = p
	g.casa = p
	var objetivo: Vector3 = Terreno3D.centro_de(b)
	colocar_jugador(b)                          # el jugador (que seguía encima del tronco tras el salto) se va a la otra orilla: no estorba el paso
	g.objetivo = jugador
	g.ultima_pos = objetivo
	var llego: bool = false
	var y_max: float = -INF
	var y_min_puente: float = INF
	for i in range(1500):
		g.vista_perdida = 0.0
		g.estado = "busca"
		g._physics_process(1.0 / 60.0)
		g._ajustar_al_suelo(1.0 / 60.0)
		# Solo cuenta con el goblin ya hacia el centro de la casilla: el escalón de entrada lo sube a 6 u/s y las primeras muestras van de camino.
		if t.celdas_rio.has(Terreno3D.celda_de(g.position)) and absf((g.position - Terreno3D.centro_de(Terreno3D.celda_de(g.position))).dot(t.direccion)) < 0.5:
			y_min_puente = minf(y_min_puente, g.position.y)
			y_max = maxf(y_max, g.position.y)
		if Vector2(g.position.x - objetivo.x, g.position.z - objetivo.z).length() < 1.2:
			llego = true
			break
	print("      [medida] goblin: llegó=%s, en el tronco y entre %.3f y %.3f" % [str(llego), y_min_puente if y_min_puente < INF else 0.0, y_max if y_max > -INF else 0.0])
	_ok("7.2 un goblin cruza el tronco hasta la otra orilla", llego, "en %s" % str(Terreno3D.celda_de(g.position)))
	_ok("7.3 …a la altura del tronco (sin hundirse)", y_min_puente < INF and y_min_puente >= t.y_cara - 0.1, "mín %.3f" % y_min_puente)
	g.pj.free()
	g.free()


# ---------------------------------------------------------------------------------------------------------------------
#  4. El largo sale del río: río de 3 casillas (mundo sintético)
# ---------------------------------------------------------------------------------------------------------------------
func _rio_ancho() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(9):
		var f: String = ""
		for x in range(14):
			if x == 0 or y == 0 or x == 13 or y == 8:
				f += "#"
				bloq[Vector2i(x, y)] = true
			elif y == 4 and x >= 4 and x <= 6:
				f += "~"
			else:
				f += "."
		filas.append(f)
	Terreno3D.agua_sim = null              # la simulación del Bosque 01 no es de este mapa de mentira
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	Terreno3D.y_puentes.clear()
	var raiz := Node3D.new()
	maqueta.add_child(raiz)
	var t := TroncoPuente3D.new()
	raiz.add_child(t)
	var base: Vector3 = Terreno3D.centro_de(Vector2i(7, 4), Terreno3D.alto_suelo)
	t.preparar(null, base, Vector3.LEFT, Vector2i(6, 4))
	_ok("8.1 río de 3 casillas: el tronco cubre las 3 (%d)" % t.celdas_rio.size(), t.celdas_rio.size() == 3)
	var esperado: float = 3.0 * Terreno3D.casilla + 2.0 * TroncoPuente3D.MARGEN_ORILLA
	_ok("8.2 y su largo sale del ancho: 3 × casilla + 2 márgenes = %.2f" % esperado, absf(t.largo - esperado) < 1.0e-3, "largo %.3f" % t.largo)
	t.caer()
	await avanzar_s(TroncoPuente3D.T_CAIDA + 0.6)
	var todas: bool = true
	for c in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]:
		todas = todas and Terreno3D.letra_de(c) == "b" and Terreno3D.pisable(c, 0, false, 0, false) and absf(Terreno3D.y_pies(c) - t.y_cara) < 1.0e-4
	_ok("8.3 al caer, las tres casillas son puente pisable a la altura de la cara", todas)
	var ruta: Array[Vector2i] = Caminos3D.camino(Vector2i(8, 4), Vector2i(3, 4))
	_ok("8.4 y hay ruta de una orilla a la otra", ruta.size() == 6, str(ruta.size()))
	var un_rio: bool = true
	for c in t.celdas_rio:
		un_rio = un_rio and ruta.has(c)
	_ok("8.5 …que pasa por las tres", un_rio)
	raiz.queue_free()


func _fuego_() -> RuneData:
	var r := RuneData.new()
	var tg: Array[String] = ["calor"]
	r.tags = tg
	return r
