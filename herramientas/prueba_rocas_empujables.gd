extends "res://herramientas/escenario_sala_empuje.gd"
## ROCAS EMPUJABLES (5/11/2026, docs/ROCAS_EMPUJABLES_2026-11-05.md). Pablo, tras el playtest del Bosque 02: «las rocas de tamaño medio y pequeño deberían ser empujables, podemos hacer pequeños puzles de peso».
##   0 · TAMAÑOS: `RocasEstilizadas.tamano_de` clasifica las 10 rocas por alto y huella (grande = muro fijo; mediana y pequeña se empujan; pisable = sin cuerpo) y coincide con la colisión real.
##   1 · MUNDO PEQUEÑO (sin escena, mundo falso de prueba_puzle.gd): mediana y pequeña se empujan UNA casilla en las 4 direcciones; no atraviesan muros, agua honda ni otras rocas; tienen el modelo de su
##       variante; el parser admite `roca_empujable` y rechaza lo que no cabe (tam=grande); las placas de PESO (`peso=n`) se pisan con la suma justa y se sueltan al quitar la roca.
##   2 · LA SALA DEL EMPUJE (el laboratorio de empuje, escena real): la jugadora empuja con las teclas, de verdad, una piedra, una roca mediana y una pequeña: mismo arranque (~0,35 s), mismo clip
##       «empujar», misma velocidad (~1 u/s) y una casilla si suelta a mitad.
##   3 · EL BOSQUE 02 (escena real, mapa de esta rama): la balanza del claro (sección 14) se resuelve a pie, empujando, y da su cofre común.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_rocas_empujables.gd

const MundoFalso = preload("res://herramientas/prueba_puzle.gd").MundoFalso
const RUTA_BOSQUE_02: String = "res://escenas/PruebaBosque02.tscn"
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]


func _escenario() -> void:
	reloj = Reloj.new()                       # el reloj de los escenarios, también para el mundo pequeño (cargar lo reutiliza)
	reloj.name = "Reloj"
	root.add_child(reloj)
	_t_sec_0()
	await _t_sec_1()
	await _t_sec_2()
	await _t_sec_3()
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
#  0 · Tamaños
# ---------------------------------------------------------------------------------------------------------------------

func _t_sec_0() -> void:
	print("--- 0. tamaños")
	var esperado: Dictionary = {"roca_est_0": "grande", "roca_est_1": "mediana", "roca_est_2": "mediana", "roca_est_3": "mediana", "roca_est_4": "grande",
		"piedra_est_0": "pequena", "piedra_est_1": "pisable", "piedra_est_2": "pisable", "piedra_est_3": "pisable", "piedra_est_4": "pisable"}
	for v in ["", "musgo", "magma"]:
		for id in esperado:
			var con_v: String = RocasEstilizadas.id_de(String(id), v) if v != "" else String(id)
			var t: String = RocasEstilizadas.tamano_de(con_v)
			_ok("0 %s → %s" % [con_v, esperado[id]], t == esperado[id], "dio %s" % t)
	for id in ["roca_est_0", "roca_est_1", "roca_est_2", "roca_est_3", "roca_est_4", "piedra_est_0", "piedra_est_1", "piedra_est_4"]:
		var alto: float = float(Pieza3D.MEDIDA.get(id, 0.0))
		print("MEDIDA 0: %s alto %.2f · huella %.2f · %s · cuerpo de colisión: %s" % [id, alto, RocasEstilizadas.huella_de(id), RocasEstilizadas.tamano_de(id), str(not Pieza3D.cascos_colision(id).is_empty())])
	for id in esperado:
		var t2: String = RocasEstilizadas.tamano_de(String(id))
		var tiene_cuerpo: bool = not Pieza3D.cascos_colision(String(id)).is_empty()
		_ok("0 %s: tiene cuerpo de colisión ⇔ no es pisable" % id, tiene_cuerpo == (t2 != "pisable"))
		_ok("0 %s: empujable ⇔ mediana o pequeña" % id, RocasEstilizadas.empujable(String(id)) == (t2 == "mediana" or t2 == "pequena"))
	_ok("0 no es roca: tamano_de('arbol_redondo') vacío y no empujable", RocasEstilizadas.tamano_de("arbol_redondo") == "" and not RocasEstilizadas.empujable("arbol_redondo"))
	_ok("0 pesos: mediana 2, pequeña 1", int(RocasEstilizadas.PESO_TAM["mediana"]) == 2 and int(RocasEstilizadas.PESO_TAM["pequena"]) == 1)
	_ok("0 los modelos por defecto son del tamaño que dicen", RocasEstilizadas.tamano_de(String(RocasEstilizadas.FORMA_DEFECTO["mediana"])) == "mediana" and RocasEstilizadas.tamano_de(String(RocasEstilizadas.FORMA_DEFECTO["pequena"])) == "pequena")


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Mundo pequeño
# ---------------------------------------------------------------------------------------------------------------------

func _quieto(b: BloqueEmpujable3D, max_fotogramas: int = 900) -> void:
	var n: int = 0
	while b.moviendo and n < max_fotogramas:
		await process_frame
		n += 1
	await process_frame


func _t_sec_1() -> void:
	print("--- 1. mundo pequeño")
	var m := MundoFalso.new()
	m._lado = 12
	m._mapa = PackedStringArray(["############", "#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "#......~...#", "#..........#", "#..........#", "#..........#", "############"])
	m._props = Node3D.new()
	m.add_child(m._props)
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(12):
		for x in range(12):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	await process_frame
	RocasEstilizadas.forzar = ""
	# --- 1.1 cuatro direcciones, una casilla por empujón ---
	for tam in ["mediana", "pequena"]:
		var r := BloqueEmpujable3D.new()
		r.preparar(Vector2i(4, 5), "roca", m, tam, "musgo")
		m._props.add_child(r)
		await process_frame
		_ok("1.1 %s: nace en su casilla, la bloquea y es «peso» y «empujable»" % tam, r.celda == Vector2i(4, 5) and Terreno3D.bloqueada(Vector2i(4, 5)) and r.is_in_group("peso") and r.is_in_group("empujable"))
		_ok("1.1 %s: peso_valor %d y modelo %s" % [tam, r.peso_valor, r.id_modelo], r.peso_valor == (2 if tam == "mediana" else 1) and r.id_modelo == ("roca_est_musgo_1" if tam == "mediana" else "piedra_est_musgo_0"))
		var malla: Array = r.find_children("*", "MeshInstance3D", true, false)
		var caja: AABB = Pieza3D._caja(r.get_node("bloque"), Transform3D.IDENTITY)
		_ok("1.1 %s: lleva el modelo de la roca (alto %.2f, MEDIDA %.2f)" % [tam, caja.size.y, float(Pieza3D.MEDIDA[r.id_modelo])], not malla.is_empty() and absf(caja.size.y - float(Pieza3D.MEDIDA[r.id_modelo])) < 0.05)
		var t0: float = Time.get_ticks_msec()
		for d in DIRS4:
			var antes: Vector2i = r.celda
			var pasos0: int = r.pasos
			_ok("1.1 %s: `puede_moverse` hacia %s" % [tam, str(d)], r.puede_moverse(d))
			var cedio: bool = r.empujar(d)
			await _quieto(r)
			_ok("1.1 %s: empujada hacia %s avanza EXACTAMENTE una casilla (%s → %s)" % [tam, str(d), str(antes), str(r.celda)], cedio and r.celda == antes + d and r.pasos == pasos0 + 1 and not r.moviendo)
			_ok("1.1 %s: la casilla nueva queda bloqueada y la vieja libre" % tam, Terreno3D.bloqueada(r.celda) and not Terreno3D.bloqueada(antes))
		_ok("1.1 %s: tras los 4 empujones (E, N, O, S) vuelve a (4,5)" % tam, r.celda == Vector2i(4, 5))
		r.queue_free()
		await process_frame
	# --- 1.2 los límites ---
	var contra_muro := BloqueEmpujable3D.new()
	contra_muro.preparar(Vector2i(1, 2), "roca", m, "mediana", "musgo")
	m._props.add_child(contra_muro)
	var junto_agua := BloqueEmpujable3D.new()
	junto_agua.preparar(Vector2i(6, 7), "roca", m, "pequena", "musgo")
	m._props.add_child(junto_agua)
	var ra := BloqueEmpujable3D.new()
	ra.preparar(Vector2i(3, 9), "roca", m, "mediana", "musgo")
	m._props.add_child(ra)
	var rb := BloqueEmpujable3D.new()
	rb.preparar(Vector2i(4, 9), "roca", m, "pequena", "musgo")
	m._props.add_child(rb)
	await process_frame
	_ok("1.2 contra un muro (#) la mediana no se mueve", not contra_muro.puede_moverse(Vector2i(-1, 0)) and not contra_muro.empujar(Vector2i(-1, 0)) and contra_muro.celda == Vector2i(1, 2) and not contra_muro.moviendo)
	_ok("1.2 hacia el agua honda (7,7) la pequeña no se mueve", not junto_agua.puede_moverse(Vector2i(1, 0)) and not junto_agua.empujar(Vector2i(1, 0)) and junto_agua.celda == Vector2i(6, 7))
	_ok("1.2 contra otra roca la mediana no se mueve (ni la pequeña hacia atrás)", not ra.empujar(Vector2i(1, 0)) and not rb.empujar(Vector2i(-1, 0)) and ra.celda == Vector2i(3, 9) and rb.celda == Vector2i(4, 9))
	_ok("1.2 y no cede a una diagonal ni a un vector nulo", not ra.puede_moverse(Vector2i(1, 1)) and not ra.puede_moverse(Vector2i.ZERO))
	_ok("1.2 la pequeña (4,9) sí puede ir al este, y entonces la mediana ya puede seguirla", rb.empujar(Vector2i(1, 0)))
	await _quieto(rb)
	_ok("1.2 …y la mediana, ahora que la casilla (4,9) está libre, también se mueve", rb.celda == Vector2i(5, 9) and ra.puede_moverse(Vector2i(1, 0)))
	# el destino queda reservado desde que empieza el empujón: nadie más puede ir allí
	_ok("1.2 una roca que se mueve reserva su casilla destino al empezar (la bloquea antes de llegar)", ra.empujar(Vector2i(1, 0)) and Terreno3D.bloqueada(Vector2i(4, 9)) and ra.moviendo)
	await _quieto(ra)
	for q in [contra_muro, junto_agua, ra, rb]:
		(q as BloqueEmpujable3D).queue_free()
	await process_frame
	# --- 1.3 el viento también las mueve (misma mecánica que el bloque) y la roca NO tiende vetas ---
	var rv := BloqueEmpujable3D.new()
	rv.preparar(Vector2i(5, 3), "roca", m, "mediana", "musgo")
	m._props.add_child(rv)
	await process_frame
	var viento := RuneData.new()                          # solo propiedades (gas que empuja), como en prueba_materia_reactivos_2.gd
	viento.estado = "gas"
	viento.empuje = 1.0
	_ok("1.3 un hechizo de viento empuja la mediana una casilla (mismo contrato que el bloque)", rv.spell_reacts(viento, Vector3.ZERO, Hechizo.construir(viento, {})) and not rv.reaccion_a(viento, Vector3(1, 0, 0), Hechizo.construir(viento, {})).is_empty())
	rv.on_spell_hit(viento, Vector3(1, 0, 0), Hechizo.construir(viento, {}))
	await _quieto(rv)
	_ok("1.3 …y queda en (6,3)", rv.celda == Vector2i(6, 3))
	_ok("1.3 la roca NO cuenta como piedra de enlace (no tiende los huecos de las vetas)", not BloqueEmpujable3D.piedra_en(Vector2i(6, 3)))
	rv.queue_free()
	await process_frame
	# --- 1.4 el parser y el montaje ---
	var malo: Dictionary = Puzle3D.parsear("\n".join(["; pieza g roca_empujable 3 3 tam=grande", "; pieza h roca_empujable 4 3 variante=lava", "; pieza k roca_empujable 5 3 tam=mediana variante=musgo forma=2", "; pieza q roca_empujable 6 3"]))
	_ok("1.4 `tam=grande` y `variante=lava` se rechazan con aviso (2 avisos, 2 piezas buenas)", (malo["avisos"] as Array).size() == 2 and (malo["piezas"] as Array).size() == 2, str(malo["avisos"]))
	# --- 1.5 las placas de peso ---
	var texto: String = "\n".join([
		"; pieza pl3b pulsador 8 1 modo=presencia peso=3",
		"; pieza pl2b pulsador 8 2 modo=presencia peso=2",
		"; pieza pl2 pulsador 8 3 modo=presencia peso=2",
		"; pieza pl1 pulsador 8 5 modo=presencia peso=1",
		"; pieza pl0 pulsador 8 8 modo=presencia",
		"; pieza pl3 pulsador 8 9 modo=presencia peso=3",
		"; pieza m2 roca_empujable 6 1 tam=mediana variante=musgo",
		"; pieza p3 roca_empujable 6 2 tam=pequena variante=musgo",
		"; pieza m1 roca_empujable 6 3 tam=mediana variante=musgo forma=2",
		"; pieza p1 roca_empujable 6 5 tam=pequena variante=musgo",
		"; pieza p2 roca_empujable 6 8 tam=pequena variante=musgo",
		"; pieza bq bloque 6 9 material=piedra",
	])
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "", texto)
	await process_frame
	_ok("1.5 el mapa de las placas se monta sin avisos", z.avisos.is_empty(), str(z.avisos))
	var pl: Dictionary = {}
	for id in ["pl3b", "pl2b", "pl2", "pl1", "pl0", "pl3"]:
		pl[id] = z.nodo(id) as Pulsador3D
	var ro: Dictionary = {}
	for id in ["m2", "p3", "m1", "p1", "p2", "bq"]:
		ro[id] = z.nodo(id) as BloqueEmpujable3D
	_ok("1.5 `peso=` llega a la placa (3, 2, 2, 1, 0, 3)", (pl["pl3b"] as Pulsador3D).peso_min == 3 and (pl["pl2b"] as Pulsador3D).peso_min == 2 and (pl["pl2"] as Pulsador3D).peso_min == 2 and (pl["pl1"] as Pulsador3D).peso_min == 1
		and (pl["pl0"] as Pulsador3D).peso_min == 0 and (pl["pl3"] as Pulsador3D).peso_min == 3)
	_ok("1.5 la roca m1 usa la forma 2 (roca_est_musgo_2); el bloque de piedra pesa 3", (ro["m1"] as BloqueEmpujable3D).id_modelo == "roca_est_musgo_2" and (ro["bq"] as BloqueEmpujable3D).peso_valor == 3)
	var sueltas: int = 0
	for id in pl:
		sueltas += 0 if (pl[id] as Pulsador3D).activo else 1
	_ok("1.5 las seis placas empiezan libres", sueltas == 6)
	for vuelta in range(2):
		for id in ro:
			(ro[id] as BloqueEmpujable3D).empujar(Vector2i(1, 0))
		for id in ro:
			await _quieto(ro[id] as BloqueEmpujable3D)
	await avanzar_s(0.5)
	var celdas: String = ""
	for id in ro:
		celdas += " %s=%s" % [id, str((ro[id] as BloqueEmpujable3D).celda)]
	_ok("1.5 las seis llegan a su placa:" + celdas, (ro["m2"] as BloqueEmpujable3D).celda == Vector2i(8, 1) and (ro["p3"] as BloqueEmpujable3D).celda == Vector2i(8, 2) and (ro["m1"] as BloqueEmpujable3D).celda == Vector2i(8, 3)
		and (ro["p1"] as BloqueEmpujable3D).celda == Vector2i(8, 5) and (ro["p2"] as BloqueEmpujable3D).celda == Vector2i(8, 8) and (ro["bq"] as BloqueEmpujable3D).celda == Vector2i(8, 9))
	_ok("1.5 PESO: la mediana (2) NO pisa una placa de peso 3 (pesa %d)" % (pl["pl3b"] as Pulsador3D).peso_en_casilla(), (pl["pl3b"] as Pulsador3D).peso_en_casilla() == 2 and not (pl["pl3b"] as Pulsador3D).activo)
	_ok("1.5 PESO: la pequeña (1) NO pisa una placa de peso 2 (pesa %d)" % (pl["pl2b"] as Pulsador3D).peso_en_casilla(), (pl["pl2b"] as Pulsador3D).peso_en_casilla() == 1 and not (pl["pl2b"] as Pulsador3D).activo)
	_ok("1.5 PESO: la mediana (2) SÍ pisa una placa de peso 2", (pl["pl2"] as Pulsador3D).activo)
	_ok("1.5 PESO: la pequeña (1) SÍ pisa una placa de peso 1", (pl["pl1"] as Pulsador3D).activo)
	_ok("1.5 PESO: una placa de presencia normal (sin peso) la pisa cualquier roca, como el bloque", (pl["pl0"] as Pulsador3D).activo)
	_ok("1.5 PESO: el bloque de piedra (3) SÍ pisa una placa de peso 3", (pl["pl3"] as Pulsador3D).activo)
	# soltar: quitar la mediana de la placa de peso 2
	var soltada: Array = [false]
	(pl["pl2"] as Pulsador3D).soltado.connect(func() -> void: soltada[0] = true)
	(ro["m1"] as BloqueEmpujable3D).empujar(Vector2i(1, 0))
	await _quieto(ro["m1"] as BloqueEmpujable3D)
	await avanzar_s(0.4)
	_ok("1.5 al quitar la mediana (8,3) → (9,3) la placa de peso 2 se SUELTA", (ro["m1"] as BloqueEmpujable3D).celda == Vector2i(9, 3) and not (pl["pl2"] as Pulsador3D).activo and soltada[0])
	# las dos pequeñas (1 + 1) en celdas distintas no suman: una placa mira SOLO su casilla
	_ok("1.5 la placa solo suma lo que hay en SU casilla (la pequeña de al lado no cuenta)", (pl["pl2b"] as Pulsador3D).peso_en_casilla() == 1)
	# el bloque de tierra de un hechizo (Area3D del grupo «peso» sin `peso_valor`) vale 1
	var tierra := Area3D.new()
	tierra.add_to_group("peso")
	m._props.add_child(tierra)
	tierra.global_position = Terreno3D.centro_de(Vector2i(8, 2), 0.0)
	await process_frame
	_ok("1.5 un «peso» sin peso_valor (el bloque de tierra del hechizo) vale 1: con la pequeña ya suma 2 y pisa la placa de peso 2", (pl["pl2b"] as Pulsador3D).peso_en_casilla() == 2)
	await avanzar_s(0.4)
	_ok("1.5 …y se activa", (pl["pl2b"] as Pulsador3D).activo)
	tierra.queue_free()
	z.queue_free()
	m._props.queue_free()
	await process_frame
	m.queue_free()
	for _i in range(3):
		await process_frame


# ---------------------------------------------------------------------------------------------------------------------
#  2 · La Sala del Empuje: empujar de verdad, con teclas
# ---------------------------------------------------------------------------------------------------------------------

## Pone una roca (o una piedra) en `c`, la empuja apretando la tecla y soltando a mitad de la primera casilla. Devuelve lo medido.
func _empuje_real(que: String, c: Vector2i) -> Dictionary:
	var r := BloqueEmpujable3D.new()
	if que == "piedra":
		r.preparar(c, "piedra", maqueta)
	else:
		r.preparar(c, "roca", maqueta, que, "neutra")
	maqueta.add_child(r)
	await avanzar(3)
	colocar_jugador(c + OESTE)
	await avanzar(6)
	var res: Dictionary = {"ok": false}
	if not await _pegarse(ESTE, r):
		_ok("2 %s: la jugadora llega a quedarse pegada «empujando»" % que, false)
		r.queue_free()
		return res
	var cap: Dictionary = await _apretar(ESTE, r, func() -> bool: return r.moviendo and float(r.get("_s")) > 1.0, 8.0)
	await _esperar(func() -> bool: return not r.moviendo, 8.0)
	await avanzar_s(0.3)
	res = {"ok": true, "t_arranque": float(cap["t_mueve"]) - float(cap["t_pegada"]), "clip": String(cap["clip"]), "empujando": bool(cap["empujando"]), "celda": r.celda, "empujones": r.empujones, "pasos": r.pasos,
		"acoplada": bool(cap["empujando_deslizando"])}
	Terreno3D.liberar_celda(r.celda)          # quitarla del árbol no libera la casilla (en el juego no se quita)
	r.queue_free()
	await avanzar(3)
	return res


func _t_sec_2() -> void:
	print("--- 2. la Sala del Empuje (teclas de verdad)")
	if maqueta != null:
		maqueta.get_parent().remove_child(maqueta)
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("2 la Sala del Empuje se monta sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "")
	var control: Dictionary = await _empuje_real("piedra", Vector2i(3, 7))
	var med: Dictionary = await _empuje_real("mediana", Vector2i(3, 6))
	var peq: Dictionary = await _empuje_real("pequena", Vector2i(3, 6))
	for par in [["piedra (control)", control, Vector2i(4, 7)], ["mediana", med, Vector2i(4, 6)], ["pequeña", peq, Vector2i(4, 6)]]:
		var d: Dictionary = par[1]
		if not bool(d["ok"]):
			continue
		print("MEDIDA 2: %s · empieza a moverse a los %.2f s de quedarse pegada · clip %s · celda %s" % [par[0], float(d["t_arranque"]), d["clip"], str(d["celda"])])
		_ok("2 %s: el empuje empieza a los ~0,35 s de quedarse pegada (%.2f s)" % [par[0], float(d["t_arranque"])], absf(float(d["t_arranque"]) - 0.35) < 0.15)
		_ok("2 %s: mientras empuja es true `empujando`, suena el clip «empujar» y va acoplada" % par[0], bool(d["empujando"]) and String(d["clip"]) == "empujar" and bool(d["acoplada"]))
		_ok("2 %s: soltando a mitad de la primera casilla avanza UNA casilla y se queda en %s" % [par[0], str(par[2])], d["celda"] == par[2] and int(d["pasos"]) == 1)
	if bool(control["ok"]) and bool(med["ok"]) and bool(peq["ok"]):
		_ok("2 mismo tacto: el arranque de la mediana y de la pequeña difiere de la piedra menos de 0,1 s (%.2f / %.2f frente a %.2f)" % [float(med["t_arranque"]), float(peq["t_arranque"]), float(control["t_arranque"])],
			absf(float(med["t_arranque"]) - float(control["t_arranque"])) < 0.1 and absf(float(peq["t_arranque"]) - float(control["t_arranque"])) < 0.1)
	# una roca empujada cuyo siguiente paso es un hueco de veta no la tiende (solo la piedra de enlace)
	var tiende := BloqueEmpujable3D.new()
	tiende.preparar(Vector2i(6, 6), "roca", maqueta, "mediana", "neutra")
	_ok("2 la roca no se confunde con una piedra de enlace (`piedra_en` solo mira el bloque de piedra)", not BloqueEmpujable3D.piedra_en(Vector2i(6, 6)))
	tiende.free()


# ---------------------------------------------------------------------------------------------------------------------
#  3 · El Bosque 02: la balanza del claro
# ---------------------------------------------------------------------------------------------------------------------

func _libre(c: Vector2i) -> bool:
	return Terreno3D.pisable(c, 0, false, 0, false)


## ¿Hay camino a pie de `a` a `b` por lo pisable ahora (con las rocas como obstáculo)?
func _camino(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	if not _libre(b):
		return false
	var vis: Dictionary = {a: true}
	var cola: Array = [a]
	var i: int = 0
	while i < cola.size():
		var c: Vector2i = cola[i]
		i += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if vis.has(n) or not Terreno3D.en_mapa(n) or not _libre(n):
				continue
			if n == b:
				return true
			vis[n] = true
			cola.append(n)
	return false


## La jugadora (teletransportada al punto de partida del empujón, y solo si hay camino a pie hasta él) empuja `r` una casilla hacia `dir`.
func _empujar_a_pie(r: BloqueEmpujable3D, dir: Vector2i, que: String) -> bool:
	var detras: Vector2i = r.celda - dir
	var hay: bool = _camino(celda_jugador(), detras)
	_ok("%s: hay camino a pie hasta %s para empujar %s" % [que, str(detras), str(dir)], hay)
	if not hay:
		return false
	colocar_jugador(detras)
	await avanzar(3)
	var cedio: bool = r.empujar(dir, true)
	await _esperar(func() -> bool: return not r.moviendo, 12.0)
	await avanzar(2)
	return cedio


func _t_sec_3() -> void:
	print("--- 3. el Bosque 02: la balanza del claro")
	if maqueta != null:
		maqueta.get_parent().remove_child(maqueta)
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	Niveles.viajes.clear()
	await cargar(RUTA_BOSQUE_02, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	var reglas: Node = maqueta.get_node_or_null("Reglas")
	if reglas != null:
		reglas.set("volver_al_menu", false)
	lanzador.tinta = null
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("3 Puzle3D monta el Bosque 02 sin avisos (con la sección 14)", z != null and z.avisos.is_empty(), str(z.avisos) if z != null else "")
	if z == null:
		return
	var pesada: Pulsador3D = z.nodo("placa_pesada") as Pulsador3D
	var ligera: Pulsador3D = z.nodo("placa_ligera") as Pulsador3D
	var mediana: BloqueEmpujable3D = z.nodo("roca_balanza") as BloqueEmpujable3D
	var pie_a: BloqueEmpujable3D = z.nodo("piedra_balanza_a") as BloqueEmpujable3D
	var pie_b: BloqueEmpujable3D = z.nodo("piedra_balanza_b") as BloqueEmpujable3D
	var cofre: Puzle3D.CofrePuzle = z.nodo("cofre_balanza") as Puzle3D.CofrePuzle
	_ok("3 están las 2 placas, las 3 rocas y el cofre (oculto)", pesada != null and ligera != null and mediana != null and pie_a != null and pie_b != null and cofre != null and cofre.es_oculto)
	if cofre == null or pie_b == null:
		return
	_ok("3 las rocas llevan el modelo del bosque (musgo)", mediana.id_modelo == "roca_est_musgo_1" and pie_a.id_modelo == "piedra_est_musgo_0" and pie_b.id_modelo == "piedra_est_musgo_0")
	var casillas: Array = [Vector2i(19, 30), Vector2i(21, 30), Vector2i(19, 32), Vector2i(22, 30), Vector2i(22, 32), Vector2i(22, 34), Vector2i(23, 30), Vector2i(18, 30), Vector2i(18, 32), Vector2i(22, 33)]
	var mal: Array = []
	for c in casillas:
		var es_roca: bool = c == mediana.celda or c == pie_a.celda or c == pie_b.celda
		if not es_roca and not _libre(c):
			mal.append(c)
	_ok("3 las casillas del puzle (placas, pista, apoyos, cofre) son pisables fuera de las rocas", mal.is_empty(), str(mal))
	colocar_jugador(Vector2i(16, 31))                # la orilla este, donde se llega cruzando el arroyo
	await avanzar(10)
	_ok("3 desde la orilla este (16,31) hay camino a pie hasta la salida del claro (24,31): las rocas no cortan el camino principal", _camino(Vector2i(16, 31), Vector2i(24, 31)))
	_ok("3 y hasta los apoyos de las dos pistas", _camino(Vector2i(16, 31), Vector2i(18, 30)) and _camino(Vector2i(16, 31), Vector2i(18, 32)) and _camino(Vector2i(16, 31), Vector2i(20, 30)))
	var E: Vector2i = Vector2i(1, 0)
	# resolver: la piedrecita de delante se aparta (pasando sobre la placa pesada sin pisarla), la mediana va a la placa pesada, la pequeña a la ligera
	await _empujar_a_pie(pie_a, E, "3 piedra A")
	await avanzar_s(0.5)
	_ok("3 la piedrecita sobre la placa de peso 2 NO la pisa (pesa %d de 2)" % pesada.peso_en_casilla(), pie_a.celda == Vector2i(22, 30) and pesada.peso_en_casilla() == 1 and not pesada.activo)
	await _empujar_a_pie(pie_a, E, "3 piedra A")
	_ok("3 …sigue hasta (23,30) y deja la placa libre", pie_a.celda == Vector2i(23, 30) and pesada.peso_en_casilla() == 0)
	for _i in range(3):
		await _empujar_a_pie(mediana, E, "3 mediana")
	await avanzar_s(0.5)
	_ok("3 la roca mediana en la placa pesada: se pisa", mediana.celda == Vector2i(22, 30) and pesada.activo and Flags.i().tiene("bosque02.balanza.pesada"))
	_ok("3 con una sola placa el cofre sigue oculto", cofre.es_oculto)
	for _i in range(3):
		await _empujar_a_pie(pie_b, E, "3 piedra B")
	await avanzar_s(0.8)
	_ok("3 la piedra pequeña en la placa ligera: se pisa", pie_b.celda == Vector2i(22, 32) and ligera.activo and Flags.i().tiene("bosque02.balanza.ligera"))
	_ok("3 con las dos placas APARECE el cofre", cofre.es_cerrado)
	_ok("3 el camino principal sigue libre con las tres rocas colocadas", _camino(celda_jugador(), Vector2i(24, 31)) or _camino(Vector2i(16, 31), Vector2i(24, 31)))
	colocar_jugador(Vector2i(22, 33))
	await avanzar(10)
	var oro0: int = Estado.i().oro
	var items0: int = Estado.i().huecos_usados()
	var abrio: bool = false
	var t0: float = reloj.t
	while reloj.t - t0 < 8.0 and not abrio:
		abrio = cofre.abrir()
		if not abrio:
			await avanzar_s(0.2)
	await _esperar(func() -> bool: return cofre.es_abierto, 8.0)
	_ok("3 el cofre se abre, pone su flag y da su botín (%s)" % str(cofre.botin_dado), abrio and cofre.es_abierto and Flags.i().tiene("bosque02.balanza.cofre") and (not cofre.botin_dado.is_empty() or Estado.i().oro > oro0 or Estado.i().huecos_usados() > items0))
