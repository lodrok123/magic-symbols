extends "res://herramientas/escenario_base.gd"
## ESCENARIO BOSQUE 01 (Juego, 16/10): carga escenas/PruebaBosque01.tscn DE VERDAD, con el Nivel_Bosque_01.tscn horneado (usar_escena = true:
## esta es la única excepción a la regla del armazón, porque lo que se prueba ES el nivel editable y sus marcadores), y comprueba que las reglas
## de escenas/bosque_01_3d.gd están cableadas: los tres criterios de tótem, la puerta, los dos cofres, el alquimista y la losa del estanque.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_bosque_01.gd
##
## Qué NO prueba (se declara para que nadie lo dé por cubierto): el recorrido a pie de punta a punta, el aspecto de los troncos (son cilindros provisionales) ni el arte de los cofres.

const RUTA: String = "res://escenas/PruebaBosque01.tscn"

var reglas: Node = null


func _escenario() -> void:
	await cargar(RUTA, true)
	reglas = maqueta.get_node_or_null("Reglas")
	_ok("1 la escena trae su nodo Reglas", reglas != null)
	if reglas == null:
		return
	await avanzar(10)
	_mapa()
	await _totem_antorchas()
	await _totem_secuencia()
	await _totem_propagacion()
	await _puerta()
	await _cofres()
	await _alquimista()
	await _estanque()
	await _lobernos()
	await _tronco_estanque()
	await _tronco_puente()


func _letras() -> Dictionary:
	var cuenta: Dictionary = {}
	var mapa: PackedStringArray = maqueta.get("_mapa")
	for fila in mapa:
		for ch in fila:
			cuenta[ch] = int(cuenta.get(ch, 0)) + 1
	return cuenta


func _mapa() -> void:
	var l: Dictionary = _letras()
	_ok("2.1 el nivel horneado es de 28 × 28", int(maqueta.get("_lado")) == 28, "lado %s" % str(maqueta.get("_lado")))
	_ok("2.2 un jugador, un elemental, una puerta, un alquimista", int(l.get("S", 0)) == 1 and int(l.get("G", 0)) == 1 and int(l.get("X", 0)) == 1 and int(l.get("Q", 0)) == 1, str(l))
	_ok("2.3 dos guerreros goblin (los lobernos ya no son letra W) y dos cofres", int(l.get("W", 0)) == 2 and int(l.get("Z", 0)) == 2)
	_ok("2.4 tres tótems de fuego y las siete antorchas", int(l.get("j", 0)) == 3 and int(l.get("T", 0)) == 7, "j=%s T=%s" % [l.get("j"), l.get("T")])
	_ok("2.5 telaraña, raíz y dos setas (sin letras `l` ni `P`); el estanque conserva sus 15 casillas c", int(l.get("r", 0)) == 1 and int(l.get("l", 0)) == 0 and int(l.get("P", 0)) == 0 and int(l.get("q", 0)) == 1 and int(l.get("s", 0)) == 2 and int(l.get("c", 0)) == 15, "c=%s" % l.get("c"))
	_ok("2.6 los tres tótems y las cuatro antorchas de la secuencia los encontró la regla", (reglas.get("_totems") as Dictionary).size() == 3 and (reglas.get("_sec") as Array).size() == 4)
	_ok("2.7 la regla ve los dos goblins del cofre 1", (reglas.get("_goblins") as Array).size() == 2, "goblins %d" % (reglas.get("_goblins") as Array).size())
	if (reglas.get("_elementales") as Array).size() == 1:
		_ok("2.7b y el elemental", true)
	else:
		_aviso("2.7b sin elemental en este entorno", "falta el modelo elemental_bosque (arte/ incompleto); la prueba 7.5 fuerza el cofre 2 a mano")
	var grupos: Dictionary = {}
	for mc in (maqueta.get("_marcas") as Array):
		var g: String = String((mc as Dictionary)["grupo"])
		grupos[g] = int(grupos.get(g, 0)) + 1
	_ok("2.8 marcadores de datos: un tronco-puente, un tronco del estanque, dos lobernos; sin puente reactivo", int(grupos.get("tronco_puente", 0)) == 1 and int(grupos.get("tronco_estanque", 0)) == 1 and int(grupos.get("loberno", 0)) == 2 and (maqueta.get("_puentes_def") as Array).is_empty(), str(grupos))


func _totem(c: Vector2i) -> Variant:
	return (reglas.get("_totems") as Dictionary).get(c)


func _totem_antorchas() -> void:
	var t: Variant = _totem(Vector2i(19, 8))
	_ok("3.1 TF_2 empieza apagado y los hechizos no lo encienden (capa 0)", not bool(t.activo) and (t as CollisionObject3D).collision_layer == 0)
	var a: Array = reglas.get("_antorchas2")
	a[0].encender_llama()
	await avanzar_s(0.5)
	_ok("3.2 con UNA antorcha, TF_2 sigue apagado", not bool(t.activo))
	a[1].encender_llama()
	await avanzar_s(0.5)
	_ok("3.3 con las DOS antorchas, TF_2 se activa", bool(t.activo))


func _totem_secuencia() -> void:
	var t: Variant = _totem(Vector2i(17, 19))
	var s: Array = reglas.get("_sec")
	s[1].encender_llama()                               # fuera de orden: debe apagarlas todas
	await avanzar_s(0.4)
	var algo: bool = false
	for r in s:
		algo = algo or bool(r.is_lit)
	_ok("4.1 una antorcha fuera de orden apaga todas", not algo and not bool(t.activo))
	_ok("4.2 y la cuenta vuelve a cero", int(reglas.get("_sec_sig")) == 0)
	for i in [0, 1, 2]:
		s[i].encender_llama()
		await avanzar_s(0.4)
	_ok("4.3 tres bien puestas: aún no hay tótem", not bool(t.activo) and int(reglas.get("_sec_sig")) == 3)
	s[3].encender_llama()
	await avanzar_s(0.5)
	_ok("4.4 la cuarta en orden activa TF_3", bool(t.activo))


func _totem_propagacion() -> void:
	var t: Variant = _totem(Vector2i(18, 25))
	_ok("5.1 TF_1 empieza apagado", not bool(t.activo))
	maqueta.call("_poner_fase", Vector2i(18, 24), 3)       # una casilla vecina ARDIENDO (Fase.ARDIENDO)
	await avanzar_s(0.5)
	_ok("5.2 con una casilla vecina ardiendo, TF_1 se activa", bool(t.activo))


func _puerta() -> void:
	var c: Vector2i = reglas.get("_celda_puerta")
	await avanzar_s(0.5)
	_ok("6.1 con los tres tótems la puerta se abre", bool(reglas.get("_puerta_abierta")) and not (maqueta.get("_bloqueadas") as Dictionary).has(c), "puerta %s" % str(c))
	var p: Vector2i = Misiones.i().progreso("bosque_01")
	_ok("6.2 la misión lleva 2 objetivos hechos (tótems y puerta)", p.x >= 2, "progreso %s" % str(p))


func _cofres() -> void:
	_ok("7.1 los cofres no están antes de tiempo", (reglas.get("_cofres") as Array)[0] == null and (reglas.get("_cofres") as Array)[1] == null)
	for g in (reglas.get("_goblins") as Array):
		g.muerto = true
	await avanzar_s(0.5)
	_ok("7.2 al caer los dos goblins aparece el cofre 1", (reglas.get("_cofres") as Array)[0] != null and (reglas.get("_cofres") as Array)[1] == null)
	var cof: Node3D = (reglas.get("_cofres") as Array)[0]
	if cof != null:
		_ok("7.3 el cofre 1 bloquea su casilla", (maqueta.get("_bloqueadas") as Dictionary).has((reglas.get("_celdas_cofre") as Array)[0]))
		var tenia: bool = Repertoire.sigil_active("barrera")
		if tenia:
			_aviso("7.4 la barrera ya estaba desbloqueada al empezar", "la comprobación del glifo no distingue; se mira la misión")
		colocar_jugador((reglas.get("_celdas_cofre") as Array)[0] + Vector2i(-1, 0))
		await avanzar(3)
		_tecla(KEY_E, true)
		await avanzar(2)
		_tecla(KEY_E, false)
		await avanzar_s(3.0)
		_ok("7.4 abrir el cofre 1 da el glifo de barrera y marca su objetivo", Repertoire.sigil_active("barrera") and bool((reglas.get("_entregado") as Array)[0]))
	for e in (reglas.get("_elementales") as Array):
		e.muerto = true
	await avanzar_s(0.5)
	if (reglas.get("_elementales") as Array).is_empty():
		reglas.call("_aparecer_cofre", 1)            # sin modelo del elemental (entorno sin arte completo): se fuerza la aparición
	_ok("7.5 al caer el elemental aparece el cofre 2", (reglas.get("_cofres") as Array)[1] != null)
	var cc: Array = reglas.get("_celdas_cofre")
	if cc.size() == 2:
		colocar_jugador(cc[1] + Vector2i(-1, 0))
		await avanzar(3)
		_tecla(KEY_E, true)
		await avanzar(2)
		_tecla(KEY_E, false)
		await avanzar_s(3.0)
		_ok("7.6 abrir el cofre 2 termina la demo", bool(reglas.get("_terminado")))


func _alquimista() -> void:
	var npc: Variant = reglas.get("_npc")
	if npc == null:
		_aviso("8 sin alquimista en este entorno", "falta el modelo del alquimista (arte/ incompleto): la conversación y la muestra no se prueban aquí")
		return
	_ok("8.1 la regla encontró al alquimista", true)
	var antes: int = Estado.i().cuenta("pocion")
	colocar_jugador(Terreno3D.celda_de((npc as Node3D).position) + Vector2i(0, 1))
	await avanzar(3)
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar_s(0.3)
	_ok("8.2 la primera conversación da UNA poción (muestra gratis)", Estado.i().cuenta("pocion") == antes + 1, "%d → %d" % [antes, Estado.i().cuenta("pocion")])
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar_s(0.3)
	_ok("8.3 la segunda no da otra", Estado.i().cuenta("pocion") == antes + 1)


func _estanque() -> void:
	var sim: Variant = Terreno3D.agua_sim
	var c: Vector2i = Vector2i(16, 14)
	_ok("9.1 el estanque empieza vacío", sim.profundidad_casilla(c) == 0.0)
	colocar_jugador(Vector2i(16, 9))                       # la losa T_C
	await avanzar_s(20.0)
	var d: float = sim.profundidad_casilla(c)
	var d_cola: float = sim.profundidad_casilla(Vector2i(16, 20))
	_ok("9.2 pisar la losa sube el agua del estanque", d > 0.05, "profundidad en el tronco %.2f, en el extremo sur %.2f" % [d, d_cola])
	await avanzar_s(40.0)
	var perfil: Array = []
	for y in range(10, 21):
		perfil.append("%.2f" % sim.profundidad_casilla(Vector2i(16, y)))
	_aviso("9.3 perfil del estanque a los 60 s (columna 16, filas 10..20)", " ".join(perfil))


func _fuego() -> RuneData:
	var r := RuneData.new()
	var tags: Array[String] = ["fuego", "calor"]
	r.tags = tags
	return r


func _lobernos() -> void:
	var lista: Array = reglas.get("_lobernos")
	if not ResourceLoader.exists("res://arte/modelos/loberno.glb"):
		_aviso("11 lobernos", "falta arte/modelos/loberno.glb en este entorno (el del proyecto sí lo tiene)")
		return
	_ok("11.1 salen los dos lobernos del nivel", lista.size() == 2, "lobernos %d" % lista.size())
	var buenos: int = 0
	for g in lista:
		if is_instance_valid(g) and (g as Pj3D).id == "loberno" and Pj3D.glb_de("loberno") == "loberno":
			buenos += 1
	_ok("11.2 usan el modelo loberno.glb (no emberheart) y la regla no los cuenta como goblins del cofre 1", buenos == 2 and (reglas.get("_goblins") as Array).size() == 2)
	var n: int = 0
	for nodo in maqueta.get_tree().get_nodes_in_group("combate3d"):
		if (nodo as Combate3D).pj != null and (nodo as Combate3D).pj.id == "loberno":
			n += 1
	_ok("11.3 cada loberno lleva su Combate3D", n == 2, "combates %d" % n)


func _tronco_puente() -> void:
	var t: TroncoPuente3D = reglas.get("_tronco_puente") as TroncoPuente3D
	_ok("12.1 hay un tronco-puente en la orilla este (K10) que cae hacia el oeste sobre J10 (6,5)", t != null and t.celda_puente == Vector2i(6, 5) and t.direccion.x < -0.99, "celda %s dir %s" % [str(t.celda_puente) if t != null else "-", str(t.direccion) if t != null else "-"])
	if t == null:
		return
	var c: Vector2i = Vector2i(6, 5)
	_ok("12.2 el río empieza como agua", String(maqueta.call("_letra", c)) == "~")
	_ok("12.3 el tronco está en pie y reacciona al fuego", t.spell_reacts(_fuego()) and not t.cayo)
	var agua := RuneData.new()
	var tg: Array[String] = ["agua"]
	agua.tags = tg
	_ok("12.4 el agua no lo tumba", not t.spell_reacts(agua))
	_ok("12.5 está en la capa de hechizos", (t.collision_layer & Lanzador3D.CAPA_REACTIVO) != 0)
	t.on_spell_hit(_fuego(), Vector3.ZERO)
	await avanzar_s(2.0)
	_ok("12.6 golpeado con fuego, cae y la casilla del río pasa a puente", t.cayo and String(maqueta.call("_letra", c)) == "b", "letra «%s»" % String(maqueta.call("_letra", c)))
	_ok("12.7 el tronco quedó tumbado (su eje largo, horizontal)", absf((t.get("_pivote") as Node3D).basis.y.y) < 0.05)
	_ok("12.8 el puente se pisa", Terreno3D.pisable(c, 0, false, 0, false))


func _tronco_estanque() -> void:
	var tr: TroncoEstanque3D = reglas.get("_tronco_estanque") as TroncoEstanque3D
	var c: Vector2i = Vector2i(16, 14)
	_ok("13.1 hay un tronco del estanque en T19 (16,14)", tr != null and tr.celda == c)
	if tr == null:
		return
	# El estanque ya se llenó en la prueba 9 (60 s con la losa pisada): el tronco tiene que haber subido y abierto el paso.
	_ok("13.2 con el agua llena, el tronco ha subido a ras del suelo", tr.abierto and absf(tr.position.y - (Terreno3D.alto_suelo - TroncoEstanque3D.RADIO + 0.04)) < 0.06, "y %.2f abierto %s" % [tr.position.y, str(tr.abierto)])
	_ok("13.3 su casilla pasó a puente", String(maqueta.call("_letra", c)) == "b", "letra «%s»" % String(maqueta.call("_letra", c)))
	_ok("13.4 la regla cortó el resto de la columna del cauce", bool(reglas.get("_columna_cortada")))
	var col: Array = reglas.get("COLUMNA_ESTANQUE")
	var cortadas: int = 0
	var libres: int = 0
	for q in col:
		if (maqueta.get("_bloqueadas") as Dictionary).has(q):
			cortadas += 1
		if Terreno3D.pisable(q, 0, false, 0, true):
			libres += 1
	_ok("13.5 las casillas de la columna están bloqueadas y la del tronco no", cortadas == col.size() and not (maqueta.get("_bloqueadas") as Dictionary).has(c), "bloqueadas %d de %d" % [cortadas, col.size()])
	_ok("13.6 y no se pisan ni a nado (si falla, el agua no es un muro y el bloqueo no basta)", libres == 0, "se pisan %d de %d" % [libres, col.size()])
