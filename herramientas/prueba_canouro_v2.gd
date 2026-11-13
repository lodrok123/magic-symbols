extends "res://herramientas/prueba_bosque_02_recorrido.gd"
## 6/11 · CANOURO v2 (CanouroV2; rediseño aprobado por Pablo). Sin ventana, a 30 fps fijos, sobre las escenas reales (Bosque 02 para la colocación, el Bosque para el combate).
##   N  colocación: dos canouros en la zona bosque_denso del Bosque 02, alcanzables a pie, lejos del resto de enemigos
##   S  stats propios (40 de vida, defensa 0, sin resistencia al fuego) y el interruptor CANOURO_V2 = false (50 / defensa 2 / sin CanouroV2)
##   O  acecho en círculo con la jugadora quieta: distancia 4-5 u, tangencial, cambios de sentido, embestida cada 3-4 s, aviso de 0,4 s, mordisco de 12, huida a > 3,5 u
##   D  niebla: ×0,5 con niebla, ×1,5 expuesto; un golpe de fuego la disipa 8 s (fundido visual) y rebrota en 1,5 s
##   A  apuntado: la asistencia de los proyectiles (`busca`) ignora al canouro con niebla y lo persigue expuesto
##   B  barrera: el mordisco parado por la burbuja rebota, aturde 1,5 s y no hiere; la burbuja de fuego lo quema
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_canouro_v2.gd

const FILA_L: int = 21                     ## filas 18..25 del Bosque: un prado de 12 × 8 casillas sin nada
const DT_V: float = 1.0 / 60.0
var _creados: Array = []


func _rune(elem: String) -> RuneData:
	var en: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "hielo": "ice", "rayo": "lightning"}
	return load("res://nucleo/%s_rune.tres" % String(en.get(elem, elem))) as RuneData


func _hz(elem: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(_rune(elem), glifos, 1.0)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _planta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _canouro(c: Vector2i, id: String = "canouro") -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", [id], p)
	if modelo == null:
		return null
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.position = p
	g.casa = p
	_creados.append(g)
	_creados.append(modelo)
	return g


func _limpiar_todo() -> void:
	var lista: Variant = maqueta.get("_goblins")
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			if lista is Array and n is Pj3D:
				(lista as Array).erase(n)
			(n as Node).queue_free()
	_creados.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()


func _jugadora_lista(c: Vector2i) -> void:
	colocar_jugador(c)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	j._t_inv = 0.0
	j._roll_cd = 0.0
	j._t_roll = 0.0
	j._empuje = Vector3.ZERO
	j.muerto = false


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	Niveles.viajes.clear()
	await _caso_nivel()
	if maqueta != null:
		maqueta.queue_free()
		await avanzar(6)
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	lanzador.tinta = null
	await _caso_stats()
	await _caso_orbita()
	await _caso_niebla()
	await _caso_apuntado()
	await _caso_barrera()
	_limpiar_todo()
	await avanzar(3)


# --- N · colocación en el Bosque 02 ------------------------------------------------------------------------------------------

func _caso_nivel() -> void:
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	var cs: Array = []
	var otros: Array = []
	for n in get_nodes_in_group("combate3d"):
		var c: Combate3D = n as Combate3D
		if c == null or not is_instance_valid(c):
			continue
		if c.pj != null and c.pj.id == "canouro":
			cs.append(c)
		else:
			otros.append(c)
	_ok("N1 el Bosque 02 trae 2 canouros (marcadores `canouro` del mapa)", cs.size() == 2, str(cs.size()))
	var zonas: Zonas3D = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	var celdas: Array = []
	for c in cs:
		celdas.append(Terreno3D.celda_de((c as Combate3D).casa))
	celdas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	# 12/11/2026: Pablo movió los dos marcadores en Bosque_02.txt (b87ca18e, 10/11: canouro_01 26,29 → 24,29 y canouro_02 25,34 → 27,34), siguen en bosque_denso.
	_ok("N2 en las casillas (24,29) y (27,34) del mapa", celdas == [Vector2i(24, 29), Vector2i(27, 34)], str(celdas))
	var en_zona: bool = zonas != null
	for ce in celdas:
		if zonas != null:
			en_zona = en_zona and String(zonas.zona_en(ce as Vector2i).get("nombre", "")) == "bosque_denso"
	_ok("N3 los dos están en la zona bosque_denso", en_zona)
	var a_pie: bool = true
	for ce in celdas:
		a_pie = a_pie and _libre(ce as Vector2i) and not _ruta(Vector2i(16, 31), ce as Vector2i).is_empty()
	_ok("N4 son pisables y se llega a pie desde la orilla este del arroyo (16,31)", a_pie)
	var min_otro: float = INF
	for c in cs:
		for o in otros:
			if is_instance_valid(o) and not (o as Combate3D).muerto:
				min_otro = minf(min_otro, _planta((c as Combate3D).position, (o as Combate3D).position))
	_ok("N5 a más de 8 u de cualquier otro enemigo (mín %.1f u)" % min_otro, min_otro > 8.0)
	# ni encima de un puzle: a más de 1 casilla de cualquier reactivo, roca o rompible (la balanza de rocas ocupa (19..22, 30..34))
	var min_pieza: float = INF
	var cerca_de: String = ""
	for grupo in ["reactivo3d", "empujable", "rompible"]:
		for o in get_nodes_in_group(grupo):
			if is_instance_valid(o) and o is Node3D:
				for c in cs:
					var dp: float = _planta((c as Combate3D).position, (o as Node3D).global_position)
					if dp < min_pieza:
						min_pieza = dp
						cerca_de = "%s «%s» en %s" % [grupo, o.name, str(Terreno3D.celda_de((o as Node3D).global_position))]
	_ok("N5b a más de 1 casilla de cualquier pieza de puzle (mín %.1f u: %s)" % [min_pieza, cerca_de], min_pieza > Terreno3D.casilla)
	var raros: bool = true
	for c in cs:
		raros = raros and (c as Combate3D)._cv2 != null and is_equal_approx((c as Combate3D).vida_max, CanouroV2.VIDA) and (c as Combate3D)._niebla != null
	_ok("N6 cada uno es un CanouroV2 con su niebla", raros)


# --- S · stats --------------------------------------------------------------------------------------------------------------

func _caso_stats() -> void:
	_jugadora_lista(Vector2i(2, 24))
	var g: Combate3D = _canouro(Vector2i(11, 18))
	await avanzar(3)
	_ok("S1 vida 40 · defensa 0 · sin resistencia al fuego", g != null and g._cv2 != null and g.vida_max == 40.0 and g.health == 40.0 and g.defensa == 0.0 and g.resiste == "", "%s/%s def %s res «%s»" % [g.health, g.vida_max, g.defensa, g.resiste])
	_ok("S2 mordisco de 12 (CanouroV2.DANO_MORDISCO) y marcha de hiena", CanouroV2.DANO_MORDISCO == 12.0 and g._marcha != null)
	var perfil: Dictionary = MarchaCuadrupedo3D.PERFILES["canouro"]
	_ok("S3 las velocidades de la IA caben en el clip Gallop sin patinar (rodear %.1f, embestir %.1f ≤ %.1f u/s)" % [CanouroV2.V_ORBITA, CanouroV2.V_EMBESTIDA, 1.55 * float(perfil["vel_max"])],
		CanouroV2.V_ORBITA > float(perfil["v_cambio"]) and CanouroV2.V_EMBESTIDA <= 1.55 * float(perfil["vel_max"]) and CanouroV2.V_HUIDA <= 1.55 * float(perfil["vel_max"]))
	_ok("S4 el aviso del mordisco cumple el contrato C3 (≥ AvisoAtaque3D.T_MIN %.2f)" % AvisoAtaque3D.T_MIN, CanouroV2.T_AVISO_MORDISCO >= AvisoAtaque3D.T_MIN)
	var gob: Combate3D = _canouro(Vector2i(11, 20), "goblin_warrior_chibi")
	await avanzar(2)
	_ok("S5 un goblin sigue igual (50 de vida, defensa 2, sin CanouroV2, apuntable)", gob != null and gob._cv2 == null and gob.vida_max == 50.0 and gob.defensa == 2.0 and gob.apuntable())
	CanouroV2.CANOURO_V2 = false
	var viejo: Combate3D = _canouro(Vector2i(11, 22))
	await avanzar(2)
	CanouroV2.CANOURO_V2 = true
	_ok("S6 con CANOURO_V2 = false vuelve el canouro de antes (50 de vida, defensa 2, resiste fuego, sin CanouroV2)", viejo != null and viejo._cv2 == null and viejo.vida_max == 50.0 and viejo.defensa == 2.0 and viejo.resiste == "fuego" and viejo.apuntable())
	_limpiar_todo()
	await avanzar(3)


# --- O · acecho en círculo --------------------------------------------------------------------------------------------------

func _caso_orbita() -> void:
	var c_j: Vector2i = Vector2i(6, FILA_L)
	_jugadora_lista(c_j)
	var p_j: Vector3 = jugador.position
	var g: Combate3D = _canouro(Vector2i(8, FILA_L))
	var cv: CanouroV2 = g._cv2
	var t0: float = reloj.t
	var dur: float = 45.0
	var n: int = 0
	var n_orbita: int = 0
	var n_orbita_banda: int = 0
	var n_banda: int = 0
	var d_min_orbita: float = INF
	var ang_prev: float = NAN
	var ang_total: float = 0.0
	var sentido_prev: float = NAN
	var cambios: int = 0
	var vida0: float = (jugador as Jugador3D).vida
	var mord_prev: int = 0
	var bites: Array = []                   # [t, d_max en los 3,5 s siguientes]
	var v_embestida: Array = []
	var pos_prev: Vector3 = g.position
	var t_pend: float = -1.0
	var avisos: Array = []
	var pend_prev: bool = false
	var fases_vistas: Dictionary = {}
	while reloj.t - t0 < dur:
		await process_frame
		var t: float = reloj.t - t0
		colocar_jugador(c_j)
		(jugador as Jugador3D)._empuje = Vector3.ZERO
		(jugador as Jugador3D)._t_inv = 0.0
		var d: float = _planta(g.position, p_j)
		var fase: int = int(cv.fase)
		fases_vistas[fase] = true
		var v_real: float = _planta(g.position, pos_prev) / maxf(reloj.t - (t0 + t - 1.0 / 30.0), 0.001)
		pos_prev = g.position
		if t > 3.0:
			n += 1
			if d >= 3.5 and d <= 5.5:
				n_banda += 1
		if fase == int(CanouroV2.Fase.ORBITA) and t > 3.0:
			n_orbita += 1
			d_min_orbita = minf(d_min_orbita, d)
			if d >= 3.5 and d <= 5.5:
				n_orbita_banda += 1
			var ang: float = atan2(g.position.z - p_j.z, g.position.x - p_j.x)
			if not is_nan(ang_prev):
				ang_total += absf(wrapf(ang - ang_prev, -PI, PI))
			ang_prev = ang
		else:
			ang_prev = NAN
		if fase == int(CanouroV2.Fase.EMBESTIDA):
			v_embestida.append(v_real)
		if not is_nan(sentido_prev) and cv._sentido != sentido_prev:
			cambios += 1
		sentido_prev = cv._sentido
		if cv.mordiscos > mord_prev:
			mord_prev = cv.mordiscos
			bites.append([t, d])
		for b in bites:
			if t - float((b as Array)[0]) <= 3.5:
				(b as Array)[1] = maxf(float((b as Array)[1]), d)
		if g._golpe_pendiente and not pend_prev:
			t_pend = reloj.t
		if pend_prev and not g._golpe_pendiente and t_pend > 0.0:
			avisos.append(reloj.t - t_pend)
			t_pend = -1.0
		pend_prev = g._golpe_pendiente
	var vida_perdida: float = vida0 - (jugador as Jugador3D).vida
	var frac_orbita: float = float(n_orbita_banda) / maxf(float(n_orbita), 1.0)
	var frac_total: float = float(n_banda) / maxf(float(n), 1.0)
	print("  [orbita] %d muestras · en órbita %d (%.0f %% dentro de 3,5-5,5 u, mín %.2f u) · global %.0f %% · giro %.1f rad · %d cambios de sentido · %d mordiscos · avisos %s · v embestida máx %.2f u/s" % [n, n_orbita,
		frac_orbita * 100.0, d_min_orbita, frac_total * 100.0, ang_total, cambios, cv.mordiscos, str(avisos), (v_embestida.max() if not v_embestida.is_empty() else 0.0)])
	_ok("O1 acechando mantiene 3,5-5,5 u de la jugadora (%.0f %% de las muestras de acecho, mín %.2f u)" % [frac_orbita * 100.0, d_min_orbita], frac_orbita >= 0.9 and d_min_orbita >= 3.3)
	_ok("O2 y en el conjunto (con embestida y huida) pasa dentro de esa banda el %.0f %% del tiempo" % (frac_total * 100.0), frac_total >= 0.5)
	_ok("O3 rodea de verdad: %.1f rad de giro alrededor de la jugadora y %d cambios de sentido" % [ang_total, cambios], ang_total >= 2.5 and cambios >= 2)
	_ok("O4 embiste y muerde: %d mordiscos en %.0f s (uno cada ~%.1f s)" % [cv.mordiscos, dur, dur / maxf(float(cv.mordiscos), 1.0)], cv.mordiscos >= 4 and cv.mordiscos <= 9)
	_ok("O5 cada mordisco quita 12 de vida (perdió %.0f con %d mordiscos)" % [vida_perdida, cv.mordiscos], absf(vida_perdida - 12.0 * float(cv.mordiscos)) < 0.01)
	var huye_ok: bool = not bites.is_empty()
	for b in bites:
		if float((b as Array)[0]) < dur - 3.6 and float((b as Array)[1]) < 3.5:
			huye_ok = false
	_ok("O6 tras cada mordisco huye a más de 3,5 u (%s)" % str(bites.map(func(b: Array) -> String: return "t%.1f→%.1f u" % [b[0], b[1]])), huye_ok)
	var aviso_ok: bool = not avisos.is_empty()
	for a in avisos:
		aviso_ok = aviso_ok and absf(float(a) - CanouroV2.T_AVISO_MORDISCO) < 0.12
	_ok("O7 el mordisco se avisa %.2f s antes de salir (medido %s)" % [CanouroV2.T_AVISO_MORDISCO, str(avisos.map(func(a: float) -> String: return "%.2f" % a))], aviso_ok)
	_ok("O8 la embestida va rápido (máx %.2f u/s ≥ 2,5) y pasa por las cuatro fases" % (v_embestida.max() if not v_embestida.is_empty() else 0.0), not v_embestida.is_empty() and float(v_embestida.max()) >= 2.5 and fases_vistas.size() == 4)
	_limpiar_todo()
	await avanzar(3)


# --- D · niebla con juego ---------------------------------------------------------------------------------------------------

func _caso_niebla() -> void:
	_jugadora_lista(Vector2i(2, 24))
	var g: Combate3D = _canouro(Vector2i(10, 20))
	g.quieto = true
	g.health = 1000.0
	g.vida_max = 1000.0
	await avanzar(3)
	var cv: CanouroV2 = g._cv2
	var niebla: NieblaCanouro3D = g._niebla
	_ok("D1 nace con la niebla puesta: ×0,5 y no apuntable", cv != null and not cv.expuesto() and not g.apuntable() and absf(cv.mult_dano() - 0.5) < 1e-6 and niebla != null and niebla.densidad == 1.0)
	var v0: float = g.health
	g.receive_damage(10.0)
	_ok("D2 con niebla un daño de 10 quita %.1f (×0,5)" % (v0 - g.health), absf((v0 - g.health) - 5.0) < 1e-4)
	# golpe real de rayo (sin fuego): ×0,5 sobre lo que decide el cálculo normal
	var hr: Hechizo = _hz("rayo", {"flecha": 1})
	var dr: float = float(g.decidir_golpe(hr)["dano"])
	v0 = g.health
	g.golpe(hr, Vector3.RIGHT)
	_ok("D3 un golpe de rayo (%.1f) con niebla quita %.1f (×0,5) y no disipa la niebla" % [dr, v0 - g.health], absf((v0 - g.health) - dr * 0.5) < 1e-3 and not cv.expuesto())
	await avanzar_s(0.5)
	# fuego
	var hf: Hechizo = _hz("fuego", {"flecha": 1})
	var df: float = float(g.decidir_golpe(hf)["dano"])
	v0 = g.health
	var t_fuego: float = reloj.t
	g.golpe(hf, Vector3.RIGHT)
	_ok("D4 un golpe de fuego (%.1f) lo encuentra ya expuesto: quita %.1f (×1,5) y quema" % [df, v0 - g.health], absf((v0 - g.health) - df * 1.5) < 1e-3 and cv.expuesto() and g.quemando > 0.0)
	_ok("D5 expuesto es apuntable", g.apuntable() and absf(cv.mult_dano() - 1.5) < 1e-6)
	await avanzar_s(1.0)
	var oculta: bool = true
	for cp in niebla.capas:
		oculta = oculta and not (cp as MeshInstance3D).visible
	_ok("D6 la niebla se desvanece a la vista (densidad %.2f, láminas ocultas)" % niebla.densidad, niebla.densidad <= 0.01 and oculta)
	# D6b · piezas de la 2.ª versión de la niebla (cuerpo negro, humo de los huesos): al disiparse se apagan y se ve el animal
	var humo_apagado: bool = not niebla.emisores.is_empty()
	for e in niebla.emisores:
		humo_apagado = humo_apagado and e.amount_ratio <= 0.01
	var sin_negro: bool = not niebla.cuerpo.is_empty()
	for mi in niebla.cuerpo:
		sin_negro = sin_negro and mi.material_override != niebla._mat_negro
	_ok("D6b disipada: el humo de los %d huesos deja de salir y el cuerpo ya no va negro (%d mallas)" % [niebla.emisores.size(), niebla.cuerpo.size()], humo_apagado and sin_negro)
	var v1: float = g.health
	g.quemando = 0.0
	g.receive_damage(10.0)
	_ok("D7 expuesto, 10 de daño quitan %.1f (×1,5)" % (v1 - g.health), absf((v1 - g.health) - 15.0) < 1e-4)
	var t_fin_expuesto: float = -1.0
	var t_fin_rebrote: float = -1.0
	var dens_media: bool = false
	while reloj.t - t_fuego < 12.0:
		await process_frame
		g.quemando = 0.0
		g.health = 1000.0
		if t_fin_expuesto < 0.0 and not cv.expuesto():
			t_fin_expuesto = reloj.t - t_fuego
		if t_fin_expuesto > 0.0 and niebla.densidad > 0.05 and niebla.densidad < 0.95:
			dens_media = true
		if t_fin_rebrote < 0.0 and cv.niebla_estado == CanouroV2.Niebla.PUESTA:
			t_fin_rebrote = reloj.t - t_fuego
	print("  [niebla] expuesta hasta %.2f s · rebrote completo a los %.2f s" % [t_fin_expuesto, t_fin_rebrote])
	_ok("D8 queda expuesto 8 s (medido %.2f s)" % t_fin_expuesto, t_fin_expuesto >= 7.8 and t_fin_expuesto <= 8.6)
	_ok("D9 la niebla rebrota en ~1,5 s (todo el ciclo a los %.2f s) pasando por densidades intermedias" % t_fin_rebrote, t_fin_rebrote >= 9.3 and t_fin_rebrote <= 10.3 and dens_media and niebla.densidad >= 0.99)
	_ok("D10 de nuevo con niebla: ×0,5 y no apuntable", not cv.expuesto() and not g.apuntable() and absf(cv.mult_dano() - 0.5) < 1e-6)
	var humo_vuelve: bool = not niebla.emisores.is_empty()
	for e in niebla.emisores:
		humo_vuelve = humo_vuelve and e.amount_ratio >= 0.99 and e.emitting
	var negro_vuelve: bool = not niebla.cuerpo.is_empty()
	for mi in niebla.cuerpo:
		negro_vuelve = negro_vuelve and mi.material_override == niebla._mat_negro
	_ok("D11 rebrotada: vuelven el humo entero y el cuerpo negro", humo_vuelve and negro_vuelve)
	_limpiar_todo()
	await avanzar(3)


# --- A · apuntado -----------------------------------------------------------------------------------------------------------

func _golpes_de(v: HechizoVivo, e: Combate3D) -> int:
	var golpes: int = 0
	var vida: float = e.health
	var n: int = 0
	while v.activo and n < 3000:
		v.paso(DT_V)
		n += 1
		if e.health < vida - 0.0001:
			golpes += 1
		vida = e.health
	return golpes


func _caso_apuntado() -> void:
	var c_o: Vector2i = Vector2i(3, 21)
	var origen: Vector3 = Lanzador3D.centro_de(c_o, Terreno3D.y_pies(c_o) + 0.8)
	var res: Array = []
	for expuesto in [false, true]:
		_jugadora_lista(Vector2i(2, 24))
		var e: Combate3D = _canouro(Vector2i(7, 23))        # 4 casillas y 2 de lado: ~27° de la línea de tiro
		e.set_physics_process(false)
		e.health = 100000.0
		e.vida_max = 100000.0
		if expuesto:
			e._cv2.disipar()
		var v: HechizoVivo = HechizoVivo.crear(_hz("rayo", {"flecha": 4, "buscar": 1}), origen, Vector3.RIGHT, lanzador, null, {}, true)
		res.append(_golpes_de(v, e))
		if is_instance_valid(v) and not v.is_queued_for_deletion():
			v.queue_free()
		_limpiar_todo()
		await avanzar(3)
	_ok("A1 el proyectil con `busca` pasa de largo del canouro con niebla (golpes %d) y lo persigue sin ella (golpes %d)" % [res[0], res[1]], res[0] == 0 and res[1] == 1)


# --- B · barrera ------------------------------------------------------------------------------------------------------------

## 13/11 (T9): la burbuja se levanta con `Lanzador3D.levantar_burbuja` (antes por `_una_ola` con una receta montada a mano: el camino «Campo» se retiró).
func _burbuja(elemento: String) -> Lanzador3D.Burbuja:
	var rune := RuneData.new()
	rune.tags.append(elemento)
	return lanzador.levantar_burbuja(rune, elemento)


func _caso_barrera() -> void:
	var c_j: Vector2i = Vector2i(6, FILA_L)
	var j: Jugador3D = jugador as Jugador3D
	# B1 · sin barrera: el mordisco hiere 12 y no aturde
	_jugadora_lista(c_j)
	var g0: Combate3D = _canouro(Vector2i(7, FILA_L))
	g0.quieto = true
	await avanzar(2)
	var v0: float = j.vida
	g0.position = jugador.position + Vector3(1.0, 0.0, 0.0)
	g0._cv2.al_conectar()
	_ok("B1 sin barrera el mordisco quita 12 (quitó %.1f) y no aturde" % (v0 - j.vida), absf((v0 - j.vida) - 12.0) < 0.01 and g0.stun_timer <= 0.0 and g0._cv2.mordiscos_parados == 0)
	_limpiar_todo()
	await avanzar(3)
	# B2 · burbuja de agua
	_jugadora_lista(c_j)
	var g: Combate3D = _canouro(Vector2i(7, FILA_L))
	g.quieto = true
	await avanzar(2)
	var b: Lanzador3D.Burbuja = _burbuja("agua")
	_ok("B2 hay burbuja de agua viva", b != null and not b.reventada)
	if b == null:
		return
	g.position = jugador.position + Vector3(1.0, 0.0, 0.0)
	var d0: float = _planta(g.position, jugador.position)
	v0 = j.vida
	g._cv2.al_conectar()
	var t_stun: float = reloj.t
	_ok("B3 la burbuja para el mordisco: no quita vida (%.1f), la burbuja revienta y cuenta como parado" % (v0 - j.vida), j.vida == v0 and b.reventada and g._cv2.mordiscos_parados == 1)
	_ok("B4 el canouro queda aturdido %.1f s" % g.stun_timer, absf(g.stun_timer - CanouroV2.T_ATURDIDO_BARRERA) < 0.01)
	await avanzar_s(0.6)
	var d1: float = _planta(g.position, jugador.position)
	_ok("B5 rebota hacia fuera (de %.2f a %.2f u) sin salir volando" % [d0, d1], d1 > d0 + 0.3 and g._fase_empuje == Combate3D.FASE_NINGUNA)
	var t_fin: float = -1.0
	while reloj.t - t_stun < 3.0:
		await process_frame
		if t_fin < 0.0 and g.stun_timer <= 0.0:
			t_fin = reloj.t - t_stun
	_ok("B6 el aturdimiento dura ~1,5 s (medido %.2f s)" % t_fin, t_fin >= 1.3 and t_fin <= 1.9)
	_limpiar_todo()
	await avanzar(3)
	# B7 · burbuja de fuego: lo quema (y de paso le quita la niebla)
	_jugadora_lista(c_j)
	var gf: Combate3D = _canouro(Vector2i(7, FILA_L))
	gf.quieto = true
	gf.health = 1000.0
	gf.vida_max = 1000.0
	await avanzar(2)
	var bf: Lanzador3D.Burbuja = _burbuja("fuego")
	if bf == null:
		_ok("B7 hay burbuja de fuego viva", false)
		return
	gf.position = jugador.position + Vector3(1.0, 0.0, 0.0)
	gf._cv2.al_conectar()
	_ok("B7 la burbuja de fuego parada lo quema (quemando %.1f) además de aturdirlo" % gf.quemando, gf._cv2.mordiscos_parados == 1 and gf.quemando > 0.0 and gf.stun_timer > 1.0)
	_limpiar_todo()
	await avanzar(3)
