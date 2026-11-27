extends "res://herramientas/escenario_base.gd"
## LA COCA (enemigos/coca_3d.gd; arte/meshy/PROMPTS_COCA.md §0) en la Sala de la Coca (mundo/datos_nivel/mapas/SalaCoca.txt, escenas/PruebaSalaCoca.tscn): prototipo de primitivas.
##   0. la pieza `coca` la monta (3 pozas de agua, bajío, 150 de vida) y empieza sumergida;
##   1. emerge por una poza libre y no repite si hay otra; el ciclo entero pasa por SUMERGIDA → EMERGE → ACECHA → POSE → CHORRO → HUNDE → SUMERGIDA;
##   2. en ACECHA gira hacia la jugadora (a lo sumo GIRO_RAD_S); en POSE crea el aviso y se queda quieta;
##   3. el chorro hiere a la jugadora en la línea y NO si hay un sólido en medio (la tapa hace que el chorro y su aviso se recorten);
##   4. fuera de VARADA fuego, agua y tierra no le quitan vida (golpe sordo); sumergida no reacciona;
##   5. con las 3 pozas tapadas emerge por el bajío y queda VARADA con la runa encendida: los tres elementos le quitan vida (×1);
##   6. pasados VARADA_S se hunde y vuelve al ciclo;
##   7. `reiniciar` (y la muerte de la jugadora) la devuelven al principio;
##   7b. la TIERRA DE VERDAD (tierra + barrera, `lanzar_pagina_ya`) se levanta sobre una poza (`Lanzador3D.pozas_tapables`, las registra la Coca; el bajío NO) y la deja no libre; sobre agua que no es
##       poza se sigue rechazando («es agua»); la losa no sube a una poza; sobre ella emergida («está la Coca») no se construye; al caducar, la poza vuelve a ser agua y queda libre; y tres
##       hechizos reales (uno por poza) la mandan al bajío, VARADA;
##   8. a vida 0 NO muere: se CALMA (runa girada 180° y encendida), emite `calmada`, no ataca ni reacciona más, y `reiniciar` no la despierta.
##   + el chorro SALE DE LA BOCA (su caja arranca a < 0,4 u de la punta de la cabeza y sigue la dirección horizontal del aviso) y NO queda ningún aviso rojo vivo en VARADA, CALMA ni SUMERGIDA.
## Los apartados 3b, 4 y 5 TAPAN las pozas a mano (una `Lanzador3D.SolidezV2`, la misma clase que levanta la barrera, y `Terreno3D.alturas`) para no depender del tiempo de lanzar; el 7b es el camino real.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_coca.gd

const RUTA: String = "res://escenas/PruebaSalaCoca.tscn"
const POZAS: Array = [Vector2i(5, 4), Vector2i(7, 5), Vector2i(9, 4)]
const BAJIO: Vector2i = Vector2i(3, 6)
var co: Coca3D = null
var j: Jugador3D = null
var _tapas: Array = []
var _emergidas: Array = []
var _varadas: int = 0
var _calmadas: int = 0
var _chorros: int = 0


func _poner_jugadora(c: Vector2i, vida: float = 1.0e6) -> void:
	colocar_jugador(c)
	j.vida = vida
	j._t_inv = 0.0


func _esperar_fase(f: int, max_s: float) -> bool:
	var t: float = 0.0
	while co.fase != f and t < max_s:
		t += await avanzar_s(1.0 / 30.0)
	return co.fase == f


## Un sólido de la jugadora sobre la casilla `c` (una SolidezV2 viva, como la barrera de tierra).
func _tapar(c: Vector2i) -> Lanzador3D.SolidezV2:
	var s := Lanzador3D.SolidezV2.new()
	s.celdas = {c: true}
	s.niveles = 1
	s.vida = 600.0
	s.aguante = 1.0e6
	s.elemento = "tierra"
	lanzador.mundo.add_child(s)
	lanzador._solideces_v2.append(s)
	_tapas.append(s)
	return s


func _destapar() -> void:
	for s in _tapas:
		if is_instance_valid(s):
			lanzador._solideces_v2.erase(s)
			(s as Node).queue_free()
	_tapas.clear()
	for c in POZAS:
		Terreno3D.alturas.erase(c)
	await avanzar(2)


## Los avisos de ataque (el rectángulo rojo del chorro) que siguen vivos: hijos de su padre, sin cancelar ni a punto de borrarse.
func _avisos_vivos() -> int:
	var n: int = 0
	for h in co.get_parent().get_children():
		var a: AvisoAtaque3D = h as AvisoAtaque3D
		if a != null and not a.cancelado and not a.is_queued_for_deletion():
			n += 1
	return n


## Lanza de verdad (como el libro) un hechizo de `elemento` + `glifos` con el origen en el centro de `origen` (los sólidos quietos nacen donde se apunta, a <= 3 casillas) desde `desde`.
func _lanzar_en(elemento: String, glifos: Array, origen: Vector2i, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	var dir: Vector3 = Terreno3D.centro_de(origen, 0.0) - Terreno3D.centro_de(desde, 0.0)
	dir.y = 0.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, Terreno3D.centro_de(origen, Terreno3D.y_pies(origen)), dir.normalized())


## Cada poza lleva 6 piedras y 3 burbujas.
func _marcas_bien() -> bool:
	for anillo in co._marcas_raiz.get_children():
		var piedras: int = 0
		for h in anillo.get_children():
			if String(h.name).begins_with("Piedra"):
				piedras += 1
		if piedras != Coca3D.PIEDRAS_POR_POZA or anillo.get_node("Burbujas").get_child_count() != Coca3D.BURBUJAS_POR_POZA:
			return false
	return true


## Deshace los bloques de tierra y las barreras vivas que dejaron los hechizos (no las `_tapas` de a mano).
func _limpiar_hechizos() -> void:
	for b in lanzador._bloques.duplicate():
		lanzador._deshacer_bloque(b)
	for sv in lanzador._solideces_v2.duplicate():
		if is_instance_valid(sv) and not _tapas.has(sv):
			lanzador._solideces_v2.erase(sv)
			(sv as Node).queue_free()


## Agua total del lago (suma de profundidades de sus casillas, u): lo que la tierra aparta no se pierde y vuelve al caducar.
func _agua_lago() -> float:
	var t: float = 0.0
	for y in range(3, 7):
		for x in range(3, 11):
			t += Terreno3D.agua_sim.profundidad_casilla(Vector2i(x, y))
	return t


func _bloque_en(c: Vector2i) -> Dictionary:
	for b in lanzador._bloques:
		if (b["celda"] as Vector2i) == c:
			return b
	return {}


func _sumergir() -> void:
	co._quitar_aviso()
	co._cambiar(Coca3D.Fase.SUMERGIDA)
	co._t = 0.0


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	co = z.nodo("coca") as Coca3D if z != null else null
	j = jugador as Jugador3D
	_ok("0 la pieza `coca` la monta en una de sus pozas, con 3 pozas, el bajío (3,6) y 150 de vida",
		co != null and POZAS.has(Terreno3D.celda_de(co.global_position)) and co.pozas.size() == 3 and co.pozas[0] == Vector2i(5, 4) and co.bajio == BAJIO and is_equal_approx(co.vida, 150.0),
		str(z.avisos) if z != null else "")
	if co == null:
		return
	var todas_agua: bool = true
	for c in POZAS:
		todas_agua = todas_agua and Lanzador3D.es_agua(c)
	_ok("0 las 3 pozas son agua (Lanzador3D.es_agua) y todas están libres", todas_agua and co.pozas_libres().size() == 3)
	var registradas: bool = lanzador.pozas_tapables.size() == 3 and not lanzador.pozas_tapables.has(BAJIO)
	for c in POZAS:
		registradas = registradas and lanzador.pozas_tapables.has(c)
	_ok("0 la Coca registra sus 3 pozas en el Lanzador como tapables, y no el bajío", registradas, str(lanzador.pozas_tapables.keys()))
	_ok("0 el anillo de piedras y las burbujas están montados en las 3 pozas (6 piedras y 3 burbujas cada una) y en el bajío no hay marca",
		co._burbujas.size() == 3 and not co._burbujas.has(BAJIO) and co._marcas_raiz != null and co._marcas_raiz.get_child_count() == 3 and _marcas_bien())
	co.emerge.connect(func(c: Vector2i) -> void: _emergidas.append(c))
	co.varada.connect(func() -> void: _varadas += 1)
	co.calmada.connect(func() -> void: _calmadas += 1)
	co.chorro.connect(func() -> void: _chorros += 1)
	Repertoire.activate_all()
	var elementos: Array = ["fire", "water", "earth"]

	# --- 1 · emerge por una poza libre y no repite; el ciclo entero ---
	_poner_jugadora(Vector2i(5, 8))
	co.reiniciar()                                              # la carga de la escena ya la ha puesto a andar: se vuelve a empezar de cero
	_ok("1 reiniciada, empieza sumergida y entera", co.fase == Coca3D.Fase.SUMERGIDA and is_equal_approx(co.vida, 150.0))
	var fases: Array = [co.fase]
	var seguidas: bool = true
	var t_ciclo: float = 0.0
	var aviso_de_mas: int = 0                                   # fotogramas en que hay un aviso rojo vivo sin estar en POSE ni CHORRO (su destello)
	while t_ciclo < 7.0:
		t_ciclo += await avanzar_s(1.0 / 30.0)
		if co.fase != fases.back():
			fases.append(co.fase)
		if co.fase != Coca3D.Fase.POSE and co.fase != Coca3D.Fase.CHORRO and _avisos_vivos() > 0:
			aviso_de_mas += 1
	_ok("1 en el ciclo normal no queda ningún aviso rojo vivo fuera de POSE y CHORRO (SUMERGIDA, EMERGE, ACECHA, HUNDE)", aviso_de_mas == 0, "%d fotogramas con aviso de más" % aviso_de_mas)
	_ok("1 el ciclo entero: SUMERGIDA → EMERGE → ACECHA → POSE → CHORRO → HUNDE → SUMERGIDA",
		fases.slice(0, 7) == [Coca3D.Fase.SUMERGIDA, Coca3D.Fase.EMERGE, Coca3D.Fase.ACECHA, Coca3D.Fase.POSE, Coca3D.Fase.CHORRO, Coca3D.Fase.HUNDE, Coca3D.Fase.SUMERGIDA], str(fases))
	_ok("1 la primera vez emerge por una de las 3 pozas libres (señal `emerge`)", _emergidas.size() >= 1 and POZAS.has(_emergidas[0]) and _chorros >= 1, str(_emergidas))
	_emergidas.clear()
	var previa: Vector2i = Vector2i(-9, -9)
	var repite: bool = false
	var todas_pozas: bool = true
	for _i in range(8):
		_sumergir()
		co._t = 99.0
		await avanzar(2)
		if co.celda == previa:
			repite = true
		todas_pozas = todas_pozas and POZAS.has(co.celda) and co.fase == Coca3D.Fase.EMERGE
		previa = co.celda
	var distintas: Dictionary = {}
	for c in _emergidas:
		distintas[c] = true
	_ok("1 en 8 salidas seguidas no repite poza y siempre es una de las 3 (salieron por %d distintas)" % distintas.size(), not repite and todas_pozas and _emergidas.size() == 8 and distintas.size() >= 2, str(_emergidas))

	# --- 2 · acecha (gira) y pose (quieta, con el aviso) ---
	_poner_jugadora(Vector2i(5, 8))
	await _destapar()
	_sumergir()
	co.set_physics_process(true)
	co.reiniciar()
	co._salir_por(Vector2i(5, 4), false)
	_ok("2 emerge por (5,4) mirando a la jugadora", Terreno3D.celda_de(co.global_position) == Vector2i(5, 4) and absf(angle_difference(co.rotation.y, 0.0)) < 0.05)
	await _esperar_fase(Coca3D.Fase.ACECHA, 2.0)
	_poner_jugadora(Vector2i(13, 4))
	var yaw0: float = co.rotation.y
	await avanzar_s(0.3)
	var giro: float = absf(angle_difference(co.rotation.y, yaw0))
	_ok("2 en ACECHA gira hacia la jugadora a lo sumo GIRO_RAD_S (%.2f rad en 0,3 s; techo %.2f)" % [giro, Coca3D.GIRO_RAD_S * 0.3 + 0.1], co.fase == Coca3D.Fase.ACECHA and giro > 0.3 and giro < Coca3D.GIRO_RAD_S * 0.3 + 0.1)
	_poner_jugadora(Vector2i(5, 8), 100.0)
	var en_pose: bool = await _esperar_fase(Coca3D.Fase.POSE, 3.0)
	var av: AvisoAtaque3D = co._aviso
	_ok("2 la POSE crea el aviso `rectangulo` del chorro, de media anchura ANCHO_CHORRO",
		en_pose and av != null and av.forma == "rect" and is_equal_approx(av.ancho, Coca3D.ANCHO_CHORRO) and is_equal_approx(av.largo, co._largo_u),
		"largo aviso %.2f · chorro %.2f" % [av.largo if av != null else -1.0, co._largo_u])
	var p_pose: Vector3 = co.global_position
	var yaw_pose: float = co.rotation.y
	await avanzar_s(Coca3D.POSE_S * 0.5)
	_ok("2 en la pose se queda quieta (ni se mueve ni gira)", co.fase == Coca3D.Fase.POSE and co.global_position.distance_to(p_pose) < 0.01 and absf(angle_difference(co.rotation.y, yaw_pose)) < 0.001)
	_ok("2 el chorro llega a ALCANCE_CHORRO_CASILLAS o hasta la pared (largo %.1f)" % co._largo_u, co._largo_u > 3.0 * Terreno3D.casilla and co._largo_u <= Coca3D.ALCANCE_CHORRO_CASILLAS * Terreno3D.casilla + 0.01)

	# --- 3 · el chorro hiere a la jugadora en la línea ---
	var v0: float = j.vida
	var golpes0: int = co.golpes_jugadora
	await _esperar_fase(Coca3D.Fase.CHORRO, 2.0)
	var vj: float = j.vida
	_ok("3 el chorro hiere a la jugadora en la línea (DANO_CHORRO %.0f) y la aparta" % Coca3D.DANO_CHORRO, co.fase == Coca3D.Fase.CHORRO and co.golpes_jugadora == golpes0 + 1 and vj < v0, "vida %.1f → %.1f" % [v0, vj])
	_ok("3 en CHORRO hay una caja de chorro desde la boca y desaparece al acabar", co._chorro_mesh != null and is_instance_valid(co._chorro_mesh))
	await avanzar_s(0.3)                                        # la cabeza ya está en su sitio (T_CHORRO_A_LANZADA = 0,15 s)
	var cm: MeshInstance3D = co._chorro_mesh
	if cm != null and is_instance_valid(cm) and co.fase == Coca3D.Fase.CHORRO:
		var gt: Transform3D = cm.global_transform
		var largo_c: float = (cm.mesh as BoxMesh).size.z
		var origen_c: Vector3 = gt.origin + gt.basis.z * (largo_c * 0.5)          # looking_at apunta -Z hacia el final: +Z es la boca
		var fin_c: Vector3 = gt.origin - gt.basis.z * (largo_c * 0.5)
		var punta: Vector3 = co._cabeza.global_transform * Vector3(0.0, 0.0, 0.9)    # el morro del cráneo (centrado en z 0,4 y de largo 1,0)
		var horiz: Vector3 = Vector3(fin_c.x - origen_c.x, 0.0, fin_c.z - origen_c.z).normalized()
		var a_fin: float = Vector3(fin_c.x - co.global_position.x, 0.0, fin_c.z - co.global_position.z).length()
		_ok("3 el origen del chorro está a menos de 0,4 u de la punta de la cabeza (%.2f u)" % origen_c.distance_to(punta), origen_c.distance_to(punta) < 0.4)
		_ok("3 el chorro sigue la dirección horizontal del aviso (dot %.3f), acaba donde el rectángulo (%.2f u de %.2f) y cae poco desde la boca (%.2f u)" % [horiz.dot(co.dir), a_fin, co._largo_u, origen_c.y - fin_c.y],
			horiz.dot(co.dir) > 0.99 and absf(a_fin - co._largo_u) < 0.1 and origen_c.y - fin_c.y >= 0.0 and origen_c.y - fin_c.y < 1.6)
	else:
		_ok("3 el chorro sigue en pie 0,3 s después de empezar (para medir su origen)", false)
	await _esperar_fase(Coca3D.Fase.HUNDE, 2.0)
	await avanzar(3)
	_ok("3 el chorro desaparece al acabar", co._chorro_mesh == null or co._chorro_mesh.is_queued_for_deletion())
	_ok("3 y no queda ningún aviso rojo vivo al hundirse", _avisos_vivos() == 0)

	# --- 3b · con un sólido en medio, no ---
	_sumergir()
	_poner_jugadora(Vector2i(5, 8), 100.0)
	_tapar(Vector2i(5, 7))                                      # una barrera entre ella y la jugadora
	co._salir_por(Vector2i(5, 4), false)
	await _esperar_fase(Coca3D.Fase.POSE, 3.0)
	var largo_tapado: float = co._largo_u
	var largo_aviso: float = co._aviso.largo if co._aviso != null else -1.0
	var v1: float = j.vida
	var golpes1: int = co.golpes_jugadora
	await _esperar_fase(Coca3D.Fase.CHORRO, 2.0)
	await avanzar(2)
	_ok("3 con una barrera en medio el chorro NO hiere a la jugadora", co.golpes_jugadora == golpes1 and is_equal_approx(j.vida, v1), "vida %.1f → %.1f" % [v1, j.vida])
	_ok("3 y el aviso y el chorro se recortan en el primer sólido (largo %.1f < la distancia a la jugadora %.1f)" % [largo_tapado, 3.5 * Terreno3D.casilla],
		largo_tapado < 3.5 * Terreno3D.casilla and is_equal_approx(largo_aviso, largo_tapado))
	await _destapar()

	# --- 4 · fuera de VARADA es invulnerable; sumergida no reacciona ---
	co.set_physics_process(false)                               # que las llamadas de abajo no cambien de fase solas
	var sin_dano: bool = true
	var contados: bool = true
	var reactiva: bool = true
	for f in [Coca3D.Fase.EMERGE, Coca3D.Fase.ACECHA, Coca3D.Fase.POSE, Coca3D.Fase.CHORRO, Coca3D.Fase.HUNDE]:
		co._cambiar(f)
		var vf: float = co.vida
		var g0: int = co.golpes_sin_efecto
		for e in elementos:
			var rd: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
			co.on_spell_hit(rd, Vector3.LEFT, Hechizo.construir(rd, {"flecha": 1}))
		sin_dano = sin_dano and is_equal_approx(co.vida, vf)
		contados = contados and co.golpes_sin_efecto == g0 + 3
		reactiva = reactiva and co._cuerpo.collision_layer == Lanzador3D.CAPA_REACTIVO and co._cuerpo.spell_reacts(null)
	_ok("4 fuera de VARADA (emerge, acecha, pose, chorro, hunde) fuego, agua y tierra no le quitan vida: golpe sordo", sin_dano and contados and reactiva)
	co._cambiar(Coca3D.Fase.SUMERGIDA)
	var g1: int = co.golpes_sin_efecto
	var vs: float = co.vida
	var rdf: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	co.on_spell_hit(rdf, Vector3.LEFT, Hechizo.construir(rdf, {"flecha": 1}))
	_ok("4 sumergida no reacciona a hechizos (sin capa reactiva, ni golpe sordo ni daño)", co._cuerpo.collision_layer == 0 and not co._cuerpo.spell_reacts(null) and co.golpes_sin_efecto == g1 and is_equal_approx(co.vida, vs))
	# Un hechizo de verdad contra el cuello erguido: el Area3D de la capa reactiva lo recibe (si no, el prototipo no sirve).
	co.set_physics_process(true)
	_poner_jugadora(Vector2i(3, 8))
	_sumergir()
	co._salir_por(BAJIO, false)                                 # por el bajío, pegado a la orilla: el fuego no cruza casillas de agua (se apagaría) antes de llegar
	await _esperar_fase(Coca3D.Fase.ACECHA, 2.0)
	var g2: int = co.golpes_sin_efecto
	var v2: float = co.vida
	await lanzar("fuego", ["flecha"], Vector3(0, 0, -1))
	await avanzar_s(1.2)
	_ok("4 un hechizo de fuego de verdad contra el cuello erguido llega al cuerpo: «Escamas», sin daño", co.golpes_sin_efecto > g2 and is_equal_approx(co.vida, v2), "golpes %d → %d" % [g2, co.golpes_sin_efecto])

	# --- 5 · tapadas las pozas: sale por el bajío y queda varada ---
	_sumergir()
	_tapar(Vector2i(5, 4))
	_tapar(Vector2i(7, 5))
	Terreno3D.alturas[Vector2i(9, 4)] = 1                       # la tercera, con la tierra apilada (lo que levantaría un bloque)
	await avanzar(2)
	var libres: int = co.pozas_libres().size()
	_poner_jugadora(Vector2i(3, 8))
	_emergidas.clear()
	var varadas0: int = _varadas
	co._t = 99.0
	await avanzar(2)
	_ok("5 con las 3 pozas tapadas (2 barreras y 1 con tierra) ninguna está libre y emerge por el bajío", libres == 0 and co.fase == Coca3D.Fase.EMERGE and co.celda == BAJIO and _emergidas == [BAJIO], "libres %d · celda %s" % [libres, co.celda])
	await _esperar_fase(Coca3D.Fase.VARADA, 2.0)
	var t_ini: float = reloj.t
	await avanzar_s(0.6)
	_ok("5 queda VARADA (señal `varada`), con la runa encendida y el cuerpo alargado hacia delante", co.fase == Coca3D.Fase.VARADA and _varadas == varadas0 + 1 and co._runa_luz > 0.99
		and co._mat_runa.emission_energy_multiplier > 2.5 and (co._forma.shape as BoxShape3D).size.z > 3.5 and co._cuerpo.collision_layer == Lanzador3D.CAPA_REACTIVO)
	_ok("5 varada no hay ningún aviso rojo vivo", _avisos_vivos() == 0)
	var v3: float = co.vida
	var ok_el: bool = true
	var detalle: String = ""
	for e in elementos:
		var rd2: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
		var hz: Hechizo = Hechizo.construir(rd2, {"flecha": 1})
		var antes: float = co.vida
		co.on_spell_hit(rd2, Vector3.LEFT, hz)
		ok_el = ok_el and absf((antes - co.vida) - hz.dano) < 0.01 and hz.dano > 0.0
		detalle += " %s %.1f/%.1f" % [e, antes - co.vida, hz.dano]
	_ok("5 varada, fuego, agua y tierra le quitan vida (×1)", ok_el and co.vida < v3 and co.fase == Coca3D.Fase.VARADA, detalle)
	var g3: float = co.vida
	await lanzar("fuego", ["flecha"], Vector3(0, 0, -1))
	await avanzar_s(1.2)
	_ok("5 y un hechizo de fuego de verdad contra su cuello tendido le hace daño", co.vida < g3, "vida %.1f → %.1f" % [g3, co.vida])
	var chorros_varada: int = co.chorros

	# --- 6 · pasados VARADA_S vuelve al ciclo ---
	while co.fase == Coca3D.Fase.VARADA and reloj.t - t_ini < Coca3D.VARADA_S + 1.5:
		await avanzar_s(1.0 / 30.0)
	var t_v: float = reloj.t - t_ini
	_ok("6 pasados VARADA_S (%.2f s de %.1f) se hunde, y varada no echó chorros" % [t_v, Coca3D.VARADA_S], co.fase == Coca3D.Fase.HUNDE and absf(t_v - Coca3D.VARADA_S) < 0.2 and co.chorros == chorros_varada)
	await _esperar_fase(Coca3D.Fase.SUMERGIDA, 2.0)
	_ok("6 hundida, la runa se apaga", await _runa_apagada())
	await _destapar()
	_poner_jugadora(Vector2i(5, 8))
	co._t = 99.0
	await avanzar(2)
	_ok("6 destapadas las pozas, sigue el ciclo: emerge por una poza (no el bajío) y acecha", co.fase == Coca3D.Fase.EMERGE and POZAS.has(co.celda) and not co._por_bajio)
	await _esperar_fase(Coca3D.Fase.ACECHA, 2.0)
	_ok("6 …y no queda varada", co.fase == Coca3D.Fase.ACECHA)

	# --- 7 · reiniciar ---
	co.vida = 40.0
	var rein0: int = co.reinicios
	co.reiniciar()
	_ok("7 `reiniciar` la devuelve al principio: sumergida, entera, en su sitio y con la runa apagada", co.fase == Coca3D.Fase.SUMERGIDA and is_equal_approx(co.vida, co.vida_max) and Terreno3D.celda_de(co.global_position) == Vector2i(5, 4)
		and co.reinicios == rein0 + 1 and not co._runa_enciende and co._aviso == null)
	await avanzar_s(0.2)
	co.vida = 77.0
	j.vida = 0.0
	j._morir()
	await avanzar(3)
	j.reaparecer()
	await avanzar(3)
	_ok("7 al reaparecer la jugadora (G1) vuelve a empezar", co.reinicios == rein0 + 2 and is_equal_approx(co.vida, co.vida_max) and co.fase == Coca3D.Fase.SUMERGIDA)
	_poner_jugadora(Vector2i(3, 8), 100.0)

	# --- 7b · la TIERRA DE VERDAD sobre las pozas (tierra + barrera lanzada con `lanzar_pagina_ya`, como el libro) ---
	co.set_physics_process(false)                               # quieta y sumergida mientras se mide (se reanuda al final)
	await _destapar()
	_limpiar_hechizos()
	_sumergir()
	var mot_poza: String = lanzador.puede_construir_en(POZAS[1])
	var mot_agua: String = lanzador.puede_construir_en(Vector2i(6, 5))
	var mot_bajio: String = lanzador.puede_construir_en(BAJIO)
	_ok("7b `puede_construir_en`: la poza (7,5) admite tierra («%s»); el agua del lago que no es poza (6,5) («%s») y el bajío («%s») se siguen rechazando" % [mot_poza, mot_agua, mot_bajio],
		mot_poza == "" and mot_agua == "es agua" and mot_bajio == "es agua")
	# Tierra real sobre la poza (7,5), desde 3 casillas.
	var lago0: float = _agua_lago()
	var t_lanz: float = reloj.t
	var salio: bool = _lanzar_en("tierra", ["barrera"], POZAS[1], Vector2i(7, 8))
	await avanzar_s(0.8)
	var bl: Dictionary = _bloque_en(POZAS[1])
	var duracion: float = float(bl["resta"]) + (reloj.t - t_lanz) if not bl.is_empty() else 0.0
	var visible_bloque: bool = false
	if not bl.is_empty():
		for nodo in (bl["nodos"] as Array):
			var n3: Node3D = nodo as Node3D
			visible_bloque = visible_bloque or (is_instance_valid(n3) and n3.is_inside_tree() and n3.visible and n3.global_position.y > Terreno3D.alto_agua)
	_ok("7b tierra + barrera real sobre la poza (7,5) SALE y levanta un bloque (%d bloque, altura %d, dura ~%.1f s)" % [lanzador._bloques.size(), Terreno3D.altura_en(POZAS[1]), duracion],
		salio and not bl.is_empty() and Terreno3D.altura_en(POZAS[1]) >= 1 and visible_bloque)
	_ok("7b … y la deja NO libre: ya no es agua, la Coca no saldrá por ella, y las otras dos siguen libres", not co.poza_libre(POZAS[1]) and not Lanzador3D.es_agua(POZAS[1]) and co.poza_libre(POZAS[0]) and co.poza_libre(POZAS[2]))
	var lago1: float = _agua_lago()
	_ok("7b el agua que aparta no se pierde (lago %.3f → %.3f)" % [lago0, lago1], absf(lago1 - lago0) < 0.02 * maxf(lago0, 0.001))
	_limpiar_hechizos()
	await avanzar_s(0.5)
	_ok("7b al deshacerse el bloque, la poza vuelve a admitir tierra", lanzador.puede_construir_en(POZAS[1]) == "")
	# La Coca emergida en una poza: ahí no se construye.
	co._salir_por(POZAS[2], false)                              # emerge por (9,4): ahí está la Coca
	var mot_coca: String = lanzador.puede_construir_en(POZAS[2])
	var salio_coca: bool = _lanzar_en("tierra", ["barrera"], POZAS[2], Vector2i(9, 7))
	await avanzar_s(0.8)
	_ok("7b con la Coca emergida en la poza (9,4) no se construye («%s»): el hechizo se rechaza antes de cobrar, sin bloque ni barrera, y la poza sigue libre" % mot_coca,
		mot_coca == "está la Coca" and not salio_coca and _bloque_en(POZAS[2]).is_empty() and Terreno3D.altura_en(POZAS[2]) == 0 and co.poza_libre(POZAS[2]), "el hechizo salió: %s" % str(salio_coca))
	_limpiar_hechizos()
	_sumergir()
	await avanzar_s(0.5)
	# Agua que NO es poza: se rechaza con el hechizo real.
	var salio_agua: bool = _lanzar_en("tierra", ["barrera"], Vector2i(6, 5), Vector2i(6, 8))
	await avanzar_s(0.8)
	_ok("7b tierra + barrera real sobre agua que NO es poza (6,5): no levanta bloque ni altura y sigue siendo agua", _bloque_en(Vector2i(6, 5)).is_empty() and Terreno3D.altura_en(Vector2i(6, 5)) == 0 and Lanzador3D.es_agua(Vector2i(6, 5)), "el hechizo salió: %s" % str(salio_agua))
	_limpiar_hechizos()
	await avanzar_s(0.5)
	# La losa (tierra sola) no sube a una poza.
	var salio_losa: bool = _lanzar_en("tierra", [], POZAS[1], Vector2i(7, 8))
	await avanzar_s(0.5)
	_ok("7b tierra sola (la losa) sobre la poza no levanta ninguna losa ni bloque, y la poza sigue siendo agua libre", Terreno3D.plataformas_tierra.is_empty() and _bloque_en(POZAS[1]).is_empty() and co.poza_libre(POZAS[1]), "el hechizo salió: %s" % str(salio_losa))
	# Caduca: la poza vuelve a ser agua y queda libre.
	await avanzar_s(0.5)
	_lanzar_en("tierra", ["barrera"], POZAS[1], Vector2i(7, 8))
	await avanzar_s(0.6)
	var hubo: bool = not _bloque_en(POZAS[1]).is_empty() and not co.poza_libre(POZAS[1])
	var t_cad: float = reloj.t
	while not _bloque_en(POZAS[1]).is_empty() and reloj.t - t_cad < 40.0:
		await avanzar_s(1.0 / 30.0)
	var caducado: float = reloj.t - t_cad
	_ok("7b el bloque caduca solo (%.1f s más tarde) y se va: altura 0" % caducado, hubo and _bloque_en(POZAS[1]).is_empty() and Terreno3D.altura_en(POZAS[1]) == 0)
	var t_agua: float = reloj.t
	while not (Lanzador3D.es_agua(POZAS[1]) and co.poza_libre(POZAS[1])) and reloj.t - t_agua < 30.0:
		await avanzar_s(1.0 / 30.0)
	var vuelta: float = reloj.t - t_agua
	var lago2: float = _agua_lago()
	_ok("7b al caducar, la poza vuelve a ser agua y queda libre (%.1f s después; profundidad %.2f u; lago %.3f → %.3f)" % [vuelta, Terreno3D.agua_sim.profundidad_casilla(POZAS[1]), lago0, lago2],
		Lanzador3D.es_agua(POZAS[1]) and co.poza_libre(POZAS[1]) and absf(lago2 - lago0) < 0.05 * maxf(lago0, 0.001))
	await avanzar_s(3.0)
	_aviso("7b el agua tras 3 s más de asentarse", "poza (7,5) %.3f u · vecinas (6,5) %.3f (8,5) %.3f (7,4) %.3f (7,6) %.3f · lago %.3f" % [Terreno3D.agua_sim.profundidad_casilla(POZAS[1]), Terreno3D.agua_sim.profundidad_casilla(Vector2i(6, 5)),
		Terreno3D.agua_sim.profundidad_casilla(Vector2i(8, 5)), Terreno3D.agua_sim.profundidad_casilla(Vector2i(7, 4)), Terreno3D.agua_sim.profundidad_casilla(Vector2i(7, 6)), _agua_lago()])
	# Las tres pozas tapadas con hechizos reales: sale por el bajío y queda varada (¿da tiempo dentro de lo que dura la tierra?).
	_limpiar_hechizos()
	await avanzar_s(0.5)
	var t_tres: float = reloj.t
	var tiempos: Array = []
	var lanzados: int = 0
	var lanza: Array = [[Vector2i(5, 4), Vector2i(5, 7)], [Vector2i(7, 5), Vector2i(7, 8)], [Vector2i(9, 4), Vector2i(9, 7)]]
	for par in lanza:
		var intentos: float = 0.0
		var hecho: bool = false
		while not hecho and intentos < 8.0:
			hecho = _lanzar_en("tierra", ["barrera"], par[0], par[1])
			if not hecho:
				intentos += await avanzar_s(0.2)
		if hecho:
			lanzados += 1
			tiempos.append(snappedf(reloj.t - t_tres, 0.01))
			await avanzar_s(0.3)
			while not jugador.puede_lanzar() and reloj.t - t_tres < 12.0:
				await avanzar_s(0.1)
	var t_lanzar: float = reloj.t - t_tres
	var tapadas: int = 3 - co.pozas_libres().size()
	var restan: Array = []
	for c in POZAS:
		var bq: Dictionary = _bloque_en(c)
		restan.append(snappedf(float(bq["resta"]), 0.1) if not bq.is_empty() else -1.0)
	_ok("7b las tres pozas se tapan con hechizos reales (lanzados %d de 3 en %.1f s, instantes %s; dura la tierra %.1f s; les quedaba %s s)" % [lanzados, t_lanzar, str(tiempos), duracion, str(restan)], lanzados == 3 and tapadas == 3)
	if tapadas == 3:
		_poner_jugadora(Vector2i(3, 8), 1.0e6)
		_emergidas.clear()
		var var0: int = _varadas
		co.set_physics_process(true)
		co._t = 99.0
		await avanzar(3)
		_ok("7b con las 3 pozas tapadas por hechizos reales emerge por el bajío", co.celda == BAJIO and _emergidas == [BAJIO] and co._por_bajio, str(_emergidas))
		await _esperar_fase(Coca3D.Fase.VARADA, 2.0)
		await avanzar_s(0.3)
		_ok("7b … y queda VARADA con la runa encendida (y sin aviso rojo)", co.fase == Coca3D.Fase.VARADA and _varadas == var0 + 1 and co._runa_luz > 0.5 and _avisos_vivos() == 0)
	else:
		_aviso("7b no se pudieron tapar las tres a tiempo: sin esa comprobación", "tapadas %d · lanzados %d · %.1f s" % [tapadas, lanzados, t_lanzar])
	_limpiar_hechizos()
	co.set_physics_process(true)
	co.reiniciar()
	await avanzar(3)
	_poner_jugadora(Vector2i(3, 8), 100.0)
	_sumergir()
	var t_lib: float = reloj.t
	while co.pozas_libres().size() < 3 and reloj.t - t_lib < 30.0:
		await avanzar_s(1.0 / 30.0)
	_ok("7b tras limpiar, las tres pozas vuelven a estar libres (agua otra vez en %.1f s)" % (reloj.t - t_lib), co.pozas_libres().size() == 3, "libres %s" % str(co.pozas_libres()))

	# --- 7c · el aviso rojo solo vive en POSE (y su destello en CHORRO): en cualquier otra fase se quita ---
	co.set_physics_process(false)
	_poner_jugadora(Vector2i(5, 8), 100.0)
	co._cambiar(Coca3D.Fase.SUMERGIDA)
	co._salir_por(Vector2i(5, 4), false)
	co._empezar_pose()
	var con_aviso: int = _avisos_vivos()
	co._cambiar(Coca3D.Fase.SUMERGIDA)
	await avanzar(2)
	_ok("7c de POSE a SUMERGIDA no queda aviso rojo (había %d)" % con_aviso, con_aviso == 1 and _avisos_vivos() == 0)
	co._salir_por(Vector2i(5, 4), false)
	co._empezar_pose()
	con_aviso = _avisos_vivos()
	co._cambiar(Coca3D.Fase.VARADA)
	await avanzar(2)
	_ok("7c de POSE a VARADA no queda aviso rojo (había %d)" % con_aviso, con_aviso == 1 and _avisos_vivos() == 0)
	co._cambiar(Coca3D.Fase.HUNDE)
	co._salir_por(Vector2i(5, 4), false)
	co._empezar_pose()
	co._empezar_chorro()                                        # el aviso sigue vivo un instante (su destello) mientras dura el chorro
	co._cambiar(Coca3D.Fase.HUNDE)
	await avanzar(2)
	_ok("7c de CHORRO a HUNDE tampoco queda aviso rojo", _avisos_vivos() == 0)
	co.set_physics_process(true)
	_sumergir()
	_poner_jugadora(Vector2i(3, 8), 100.0)

	# --- 8 · a vida 0 se calma ---
	_sumergir()
	co._por_bajio = true
	co._cambiar(Coca3D.Fase.VARADA)
	co.vida = 4.0
	var rd3: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	co.on_spell_hit(rd3, Vector3.LEFT, Hechizo.construir(rd3, {"flecha": 1}))
	_ok("8 a vida 0 NO muere: pasa a CALMA, emite `calmada` y sigue en el árbol", co.fase == Coca3D.Fase.CALMA and is_equal_approx(co.vida, 0.0) and _calmadas == 1 and co.calmada_ya
		and co.is_inside_tree() and not co.is_queued_for_deletion() and co._cuerpo.collision_layer == 0)
	await avanzar_s(Coca3D.T_CALMA + 0.2)
	_ok("8 la runa gira 180° en 1 s y se queda encendida", absf(co._runa_giro.rotation.z - PI) < 0.01 and co._runa_luz > 0.99 and co._mat_runa.emission_energy_multiplier > 2.5)
	var ch0: int = co.chorros
	var cs0: int = _chorros
	var em0: int = co.emergencias
	var vj2: float = j.vida
	var dano0: int = co.golpes_dano
	var sord0: int = co.golpes_sin_efecto
	for e in elementos:
		var rd4: RuneData = load("res://nucleo/%s_rune.tres" % e) as RuneData
		co.on_spell_hit(rd4, Vector3.LEFT, Hechizo.construir(rd4, {"flecha": 1}))
	await avanzar_s(12.0)
	_ok("8 calmada no ataca (12 s sin chorro ni salidas), no reacciona a hechizos y la jugadora no pierde vida", co.fase == Coca3D.Fase.CALMA and co.chorros == ch0 and co.emergencias == em0 and _chorros == cs0
		and co.golpes_dano == dano0 and co.golpes_sin_efecto == sord0 and is_equal_approx(co.vida, 0.0) and is_equal_approx(j.vida, vj2) and not co._cuerpo.spell_reacts(null),
		"fase %d · chorros %d/%d/%d · salidas %d/%d · golpes %d/%d %d/%d · vida %.1f · jugadora %.1f/%.1f" % [co.fase, co.chorros, ch0, _chorros, co.emergencias, em0, co.golpes_dano, dano0, co.golpes_sin_efecto, sord0, co.vida, j.vida, vj2])
	var rein1: int = co.reinicios
	co.reiniciar()
	j.vida = 0.0
	j._morir()
	await avanzar(3)
	j.reaparecer()
	await avanzar(3)
	_ok("8 `reiniciar` (también al reaparecer la jugadora) no la despierta: sigue calmada", co.fase == Coca3D.Fase.CALMA and co.reinicios == rein1 and _calmadas == 1)
	# Un aviso rojo que se hubiera quedado vivo no sobrevive a CALMA (se fuerza uno a mano y se vuelve a entrar en CALMA).
	co._aviso = AvisoAtaque3D.rectangulo(co.get_parent(), co.global_position, co.dir, 5.0, Coca3D.ANCHO_CHORRO, 30.0, co, 0.0)
	var con_aviso2: int = _avisos_vivos()
	co._cambiar(Coca3D.Fase.CALMA)
	await avanzar(2)
	_ok("8 calmada no hay ningún aviso rojo vivo (se forzó uno: había %d)" % con_aviso2, con_aviso2 == 1 and _avisos_vivos() == 0 and co.fase == Coca3D.Fase.CALMA)


func _runa_apagada() -> bool:
	await avanzar_s(0.6)
	return co._runa_luz < 0.01 and co._mat_runa.emission_energy_multiplier < 0.05
