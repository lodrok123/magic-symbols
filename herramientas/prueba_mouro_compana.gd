extends SceneTree
## E4 y E5 (Juego): el MOURO ESPECTRO con su MÁMOA (enemigos/mouro_espectro_3d.gd, objetos/mamoa_3d.gd) y la SANTA COMPAÑA (enemigos/santa_compana_3d.gd + anima_compana_3d.gd). Sin ventana, con un
## mundo falso (como prueba_contrato_enemigo) y el tiempo avanzado a mano a 1/60 s por paso: nada depende del reloj de la máquina. La jugadora es una subclase de `Jugador3D` que apunta lo que le
## hacen (daño, raíces, estados): lo que se comprueba es que los enemigos le piden lo que dice su diseño.
##   godot --headless --path . --script res://herramientas/prueba_mouro_compana.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_mouro_compana
## Lo que fija:
##   mouro   1 muere con la mámoa abierta: no muere, vuelve a los 4 s en la casilla de la mámoa con la vida llena · 2 con la mámoa tapada: muerte definitiva y botín · 3 lo tapan mientras está
##           latente: no vuelve y muere a los 1,5 s (la mámoa suelta las reliquias) · 4 gastados los 3 rebrotes la mámoa se agrieta y el siguiente golpe mortal es definitivo · 8 su agarre pide
##           daño 12 y raíces 1 s · 9 la mámoa se tapa con un volumen de hechizo o un bloque empujable y se destapa al quitarlos
##   compaña 5 al morir el guía la cruz pasa a la siguiente a 1 s (con su pieza cambiada) · 6 las tres en menos de 2,5 s: se acaba · 7 una a una: repone, y gastadas las 3 reposiciones se acaba ·
##           10 el toque (10 y ralentizada 1,5 s) y la maldición del guía cuando atacan a otra ánima
##   12/11   animaciones: 1 SURGIR el cuerpo no se ve hasta 1,3 s, luego sale en la casilla de la mámoa con el clip Getting_Up (`lanzar_surgir`) sin ser blanco, y se esconde si tapan a mitad ·
##           5 RELEVO la cruz queda en el suelo (la del guía se esconde), la fila para, la siguiente llega y se agacha a 1,2 s con CollectObject (`lanzar_recoger`), la cruz se le engancha
##           a los T_ENGANCHE s (no antes), se endereza y la fila sigue; si la matan a medias la cruz sigue en el suelo y la recoge la tercera

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14

## La jugadora de mentira: apunta lo que le piden los enemigos y no toca nada del resto de `Jugador3D`.
class JugadoraFalsa extends Jugador3D:
	var danos: Array = []
	var raices: Array = []
	var estados: Array = []

	func recibir_dano(cantidad: float, _desde: Vector3 = Vector3.ZERO) -> void:
		danos.append(cantidad)
		vida -= cantidad

	func enraizar(segundos: float) -> void:
		raices.append(segundos)

	func aplicar_estado(elemento: String, segundos: float) -> String:
		estados.append([elemento, segundos])
		return "ralentizada"

var _mundo: Mundo3D = null
var _jug: JugadoraFalsa = null
var _fallos: int = 0
var _mouros: Array = []
var _procs: Array = []
var _creados: Array = []
var _muertos: int = 0                    ## veces que se emitió `Estado.enemigo_muerto`


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	Estado.nuevo()
	var sensacion_antes: bool = Sensacion3D.ACTIVA
	Sensacion3D.ACTIVA = false                    # la cámara lenta de la última baja pide la posición de la jugadora, que aquí no está en el árbol; no es lo que se prueba
	await process_frame
	_montar()
	await _mouro_rebrota()
	await _mouro_tapada()
	await _mouro_tapan_latente()
	await _mouro_gasta_rebrotes()
	await _mouro_agarra()
	await _mamoa_se_tapa()
	await _compana_relevo()
	await _compana_ventana()
	await _compana_reposicion()
	await _compana_surge_repuesta()
	await _compana_toque_y_maldicion()
	_piezas_de_mapa()
	Sensacion3D.ACTIVA = sensacion_antes
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jug = JugadoraFalsa.new()
	_jug.position = _pos(Vector2i(12, 12))
	_jug.pj = Pj3D.new()
	_mundo.add_child(_jug.pj)
	_jug.vida = 1000.0
	Estado.i().enemigo_muerto.connect(func(_p: Vector2, _n: String) -> void: _muertos += 1)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, Terreno3D.y_pies(c), (float(c.y) + 0.5) * S)


## Un mouro quieto (sin IA propia: se avanza con `_paso`) en la casilla `c`, con la mámoa dada.
func _mouro(c: Vector2i, m: Mamoa3D, quieto: bool = true) -> MouroEspectro3D:
	var mo: MouroEspectro3D = MouroEspectro3D.crear(_mundo, _pos(c), m, _jug)
	mo.set_physics_process(false)
	mo.quieto = quieto
	_mouros.append(mo)
	_creados.append(mo)
	return mo


func _mamoa(c: Vector2i) -> Mamoa3D:
	var m: Mamoa3D = Mamoa3D.crear(_mundo, c)
	m.set_physics_process(false)
	_creados.append(m)
	return m


func _procesion(camino: Array, n: int = 3) -> SantaCompana3D:
	var sc: SantaCompana3D = SantaCompana3D.crear(_mundo, camino, n, camino[0], _jug)
	sc.set_physics_process(false)
	sc.quieto = true                              # la fila no se mueve: lo que se prueba son las bajas
	_procs.append(sc)
	_creados.append(sc)
	_apagar_fisica(sc)
	return sc


func _apagar_fisica(sc: SantaCompana3D) -> void:
	for a in sc.animas:
		if is_instance_valid(a):
			(a as Node).set_physics_process(false)


## Avanza `segundos` de juego: la procesión, sus ánimas y los mouros, a 1/60 s por paso.
func _paso(segundos: float) -> void:
	var n: int = int(round(segundos / DT))
	for _i in range(n):
		for p in _procs:
			if is_instance_valid(p):
				(p as SantaCompana3D).avanzar(DT)
				for a in (p as SantaCompana3D).animas.duplicate():
					if is_instance_valid(a):
						(a as AnimaCompana3D)._physics_process(DT)
		for m in _mouros:
			if is_instance_valid(m):
				(m as MouroEspectro3D)._physics_process(DT)
	for p in _procs:
		if is_instance_valid(p):
			_apagar_fisica(p as SantaCompana3D)


func _limpiar() -> void:
	for n in _creados:
		if is_instance_valid(n):
			if n is Combate3D and is_instance_valid((n as Combate3D).pj):
				(n as Combate3D).pj.queue_free()
			if n is SantaCompana3D:
				for a in (n as SantaCompana3D).animas:
					if is_instance_valid(a):
						if is_instance_valid((a as Combate3D).pj):
							(a as Combate3D).pj.queue_free()
						(a as Node).queue_free()
			(n as Node).queue_free()
	_creados.clear()
	_mouros.clear()
	_procs.clear()
	for a in get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()
	_jug.danos.clear()
	_jug.raices.clear()
	_jug.estados.clear()
	_jug.vida = 1000.0
	await process_frame
	await process_frame


func _mata(e: Combate3D) -> void:
	e.receive_damage(100000.0)


func _celda(n: Node3D) -> Vector2i:
	return Terreno3D.celda_de(n.position)


func _tiene_oro(botin: Array) -> int:
	for it in botin:
		if String((it as Dictionary)["que"]) == "oro":
			return int((it as Dictionary)["n"])
	return 0


# ---------------------------------------------------------------------------------------------------------------------
#  Mouro
# ---------------------------------------------------------------------------------------------------------------------

func _mouro_rebrota() -> void:
	var cm := Vector2i(10, 6)
	var m: Mamoa3D = _mamoa(cm)
	var mo: MouroEspectro3D = _mouro(Vector2i(4, 6), m)
	var rebrotes: Array = []
	var deshechos: Array = [0]
	mo.rebroto.connect(func(v: int) -> void: rebrotes.append(v))
	mo.deshecho.connect(func() -> void: deshechos[0] += 1)
	var muertos0: int = _muertos
	_ok("0 el mouro nace con 45 de vida, sin debilidad, con su tabla y la mámoa abierta", is_equal_approx(mo.health, 45.0) and mo.debil == "" and mo.resiste == "" and mo.tabla_botin == "mouro" and mo.oro == 12 and mo.defensa == 1.0 and m.abierta and mo.inmune_estados.has("veneno") and mo.snd_paso == "", "vida %.1f" % mo.health)
	_mata(mo)
	_ok("1 muere con la mámoa abierta: NO muere, se deshace (latente, sin botín, sin contar como enemigo muerto)", not mo.muerto and mo.latente and mo.botin_soltado.is_empty() and _muertos == muertos0 and deshechos[0] == 1, "muerto %s · latente %s · caídos %d" % [mo.muerto, mo.latente, _muertos - muertos0])
	_ok("1 sigue contando como vivo (el vigía no da la sala por limpia) y no es un blanco: sin colisión ni grupo de combate", not mo.muerto and mo.collision_layer == 0 and not mo.is_in_group("combate3d") and not mo.pj.visible)
	_ok("1 la mámoa echa humo para avisar de dónde vuelve", m.humo_activo)
	_paso(1.2)
	_ok("1 SURGIR: a 1,2 s el cuerpo todavía no se ve (solo el humo)", mo.latente and not mo.surgiendo and not mo.pj.visible)
	_paso(0.2)
	_ok("1 SURGIR: a 1,4 s ya se ve en la casilla de la mámoa, levantándose (clip Getting_Up de Mixamo, estado `lanzar_surgir`)", mo.surgiendo and mo.pj.visible and _celda(mo) == cm and mo.pj.estado_anim() == "lanzar_surgir" and mo.pj.clip_actual() == "Mixamo_Incorporarse", "estado %s · clip %s · %s" % [mo.pj.estado_anim(), mo.pj.clip_actual(), _celda(mo)])
	_ok("1 SURGIR: y aún no es un blanco (latente, sin colisión, fuera del grupo de combate)", mo.latente and mo.collision_layer == 0 and not mo.is_in_group("combate3d") and rebrotes.is_empty())
	_ok("1 SURGIR: el clip entra en el rebrote: dura %.2f s y T_REBROTE son %.1f" % [mo.dur_surgir(), MouroEspectro3D.T_REBROTE], mo.dur_surgir() > 1.0 and mo.dur_surgir() <= MouroEspectro3D.T_REBROTE - 0.5)
	_ok("1 SURGIR: al empezar el cuerpo está ENCIMA del suelo de la casilla (por encima del brocal: ≥ 0,9 de la altura inicial, %.2f u)" % mo.altura_surgir(), mo.pj.position.y - mo.position.y >= 0.9 * mo.altura_surgir() and mo.altura_surgir() > 0.3, "sube %.3f" % (mo.pj.position.y - mo.position.y))
	_paso(0.8)
	_ok("1 SURGIR: a mitad del clip (2,2 s) sigue alto (el gateo se ve; la curva baja al final), sin haber tocado la posición del nodo ni la colisión", mo.pj.position.y - mo.position.y > 0.5 * mo.altura_surgir() and mo.collision_layer == 0 and Vector2(mo.pj.position.x - mo.position.x, mo.pj.position.z - mo.position.z).length() < 0.15, "sube %.3f" % (mo.pj.position.y - mo.position.y))
	_paso(1.4)
	_ok("1 SURGIR: a 3,6 s, al incorporarse, ya ha bajado más de la mitad (< 0,5 de la altura)", mo.surgiendo and mo.pj.position.y - mo.position.y < 0.5 * mo.altura_surgir(), "sube %.3f" % (mo.pj.position.y - mo.position.y))
	_paso(0.2)
	_ok("1 a los 3,8 s sigue latente", mo.latente and rebrotes.is_empty())
	_paso(0.4)
	_ok("1 a los 4 s ha vuelto: emite rebroto(1)", not mo.latente and rebrotes == [1], str(rebrotes))
	var paso: Vector2i = _celda(mo) - cm
	_ok("1 SURGIR: reaparece UN PASO FUERA del brocal, en una vecina RECTA de la mámoa (no en ella ni en diagonal), la más cercana a la jugadora (12,12)", _celda(mo) != cm and absi(paso.x) + absi(paso.y) == 1 and _celda(mo) == mo.celda_salida and paso == Vector2i(0, 1), str(_celda(mo)))
	_ok("1 SURGIR: el NODO está en el centro de la casilla de salida, a su altura de suelo, y `casa` coincide", mo.position.is_equal_approx(Terreno3D.centro_de(mo.celda_salida, Terreno3D.y_pies(mo.celda_salida))) and mo.casa.is_equal_approx(mo.position), str(mo.position))
	_ok("1 SURGIR: completado el rebrote el desplazamiento vertical es EXACTAMENTE 0", mo.pj.position.y == mo.position.y, "dif %.6f" % (mo.pj.position.y - mo.position.y))
	_ok("1 con la vida llena, visible, golpeable y sin humo", is_equal_approx(mo.health, mo.vida_max) and mo.pj.visible and mo.is_in_group("combate3d") and mo.collision_layer != 0 and not m.humo_activo)
	_ok("1 un rebrote gastado y la mámoa sin agrietar", mo.rebrotes_gastados == 1 and not m.esta_agrietada and not mo.surgiendo)
	await _limpiar()
	# Si tapan la mámoa a mitad de surgir, el cuerpo se esconde y no vuelve.
	var cm2 := Vector2i(10, 6)
	var m2: Mamoa3D = _mamoa(cm2)
	var mo2: MouroEspectro3D = _mouro(Vector2i(4, 6), m2)
	_mata(mo2)
	_paso(2.0)
	_ok("1 SURGIR: (otra vez) a 2 s se está levantando", mo2.surgiendo and mo2.pj.visible)
	m2.tapar_a_mano()
	_ok("1 SURGIR: la tapan a mitad: se esconde y deja de surgir", not mo2.surgiendo and not mo2.pj.visible)
	_paso(4.0)
	_ok("1 SURGIR: no vuelve (muere sellado)", mo2.muerto)
	await _limpiar()
	# Con las vecinas rectas bloqueadas (aunque las diagonales estén libres) se queda en la casilla de la mámoa, como antes.
	var cm3 := Vector2i(10, 6)
	var m3: Mamoa3D = _mamoa(cm3)
	var cerradas: Array = []
	for d3 in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		cerradas.append(cm3 + (d3 as Vector2i))
		Terreno3D.bloquear_celda(cm3 + (d3 as Vector2i))
	var mo3: MouroEspectro3D = _mouro(Vector2i(4, 6), m3)
	_mata(mo3)
	_paso(MouroEspectro3D.T_REBROTE + 0.2)
	_ok("1 SURGIR: con todas las vecinas bloqueadas vuelve en la casilla de la mámoa, con el desplazamiento vertical en 0", not mo3.latente and _celda(mo3) == cm3 and mo3.pj.position.is_equal_approx(mo3.position), "%s · %s" % [_celda(mo3), mo3.pj.position - mo3.position])
	for c in cerradas:
		Terreno3D.liberar_celda(c)
	await _limpiar()


func _mouro_tapada() -> void:
	var m: Mamoa3D = _mamoa(Vector2i(10, 6))
	m.tapar_a_mano()
	var mo: MouroEspectro3D = _mouro(Vector2i(4, 6), m)
	var muertos0: int = _muertos
	_ok("2 la mámoa tapada se ve tapada (señal y estado)", not m.abierta)
	_mata(mo)
	_ok("2 con la mámoa tapada muere de verdad", mo.muerto and not mo.latente and mo.rebrotes_gastados == 0 and _muertos == muertos0 + 1)
	_ok("2 y suelta botín (el oro de la tabla `mouro`: 12)", _tiene_oro(mo.botin_soltado) == 12, str(mo.botin_soltado))
	_paso(5.0)
	_ok("2 y no vuelve", mo.muerto and not mo.latente)
	await _limpiar()
	# Sin mámoa es un enemigo normal: muere una vez.
	var suelto: MouroEspectro3D = _mouro(Vector2i(4, 6), null)
	_mata(suelto)
	_ok("2 suelto, sin mámoa, muere una vez y con botín", suelto.muerto and _tiene_oro(suelto.botin_soltado) == 12)
	await _limpiar()


func _mouro_tapan_latente() -> void:
	var cm := Vector2i(10, 6)
	var m: Mamoa3D = _mamoa(cm)
	var mo: MouroEspectro3D = _mouro(Vector2i(4, 6), m)
	var selladas: Array = [0]
	var rebrotes: Array = []
	mo.sellado.connect(func() -> void: selladas[0] += 1)
	mo.rebroto.connect(func(v: int) -> void: rebrotes.append(v))
	_mata(mo)
	_paso(1.0)
	_ok("3 latente, sin tapar: sigue esperando", mo.latente and not m.reliquias_soltadas)
	m.tapar_a_mano()
	_ok("3 al taparla estando él dentro emite sellado() y la mámoa suelta las reliquias", selladas[0] == 1 and m.reliquias_soltadas and _tiene_oro(m.botin_soltado) > 0, str(m.botin_soltado))
	_ok("3 se sella con él dentro: lo cuenta la mámoa", m.mouros_dentro() == 1)
	_paso(1.4)
	_ok("3 a los 1,4 s de tapada aún no ha muerto", not mo.muerto and mo.latente)
	_paso(0.2)
	_ok("3 a los 1,5 s muere definitivamente", mo.muerto and not mo.latente, "muerto %s" % mo.muerto)
	_ok("3 su botín cae en la mámoa", _celda(mo) == cm and _tiene_oro(mo.botin_soltado) == 12, "%s · %s" % [_celda(mo), mo.botin_soltado])
	_paso(5.0)
	_ok("3 no vuelve nunca", rebrotes.is_empty() and mo.muerto)
	m.destapar_a_mano()
	_ok("3 y la mámoa ya no lo tiene dentro", m.mouros_dentro() == 0)
	await _limpiar()


func _mouro_gasta_rebrotes() -> void:
	var cm := Vector2i(10, 6)
	var m: Mamoa3D = _mamoa(cm)
	var mo: MouroEspectro3D = _mouro(Vector2i(4, 6), m)
	var rebrotes: Array = []
	var agrietadas: Array = [0]
	mo.rebroto.connect(func(v: int) -> void: rebrotes.append(v))
	m.agrietada.connect(func() -> void: agrietadas[0] += 1)
	for i in range(MouroEspectro3D.REBROTES_MAX):
		_mata(mo)
		_ok("4 muerte %d: se deshace" % (i + 1), mo.latente and not mo.muerto)
		_paso(MouroEspectro3D.T_REBROTE + 0.2)
		_ok("4 vuelve (rebroto %d) con la vida llena" % (i + 1), not mo.latente and is_equal_approx(mo.health, mo.vida_max) and rebrotes.size() == i + 1, str(rebrotes))
	_ok("4 los rebrotes salen numerados 1, 2, 3", rebrotes == [1, 2, 3], str(rebrotes))
	_ok("4 gastado el último, la mámoa se agrieta (una vez) aunque siga abierta", m.esta_agrietada and m.abierta and agrietadas[0] == 1)
	_mata(mo)
	_ok("4 el siguiente golpe mortal es DEFINITIVO", mo.muerto and not mo.latente and _tiene_oro(mo.botin_soltado) == 12)
	_paso(5.0)
	_ok("4 y no vuelve", mo.muerto and not mo.latente)
	await _limpiar()
	# Una mámoa que NACE agrietada: el primer golpe mortal ya es definitivo.
	var m2: Mamoa3D = Mamoa3D.crear(_mundo, Vector2i(10, 6), true)
	m2.set_physics_process(false)
	_creados.append(m2)
	var mo2: MouroEspectro3D = _mouro(Vector2i(4, 6), m2)
	_mata(mo2)
	_ok("4 con la mámoa nacida agrietada muere a la primera", m2.esta_agrietada and mo2.muerto)
	await _limpiar()


func _mouro_agarra() -> void:
	var mo: MouroEspectro3D = _mouro(Vector2i(5, 6), null, false)
	_jug.position = _pos(Vector2i(6, 6))
	var antes: int = get_nodes_in_group(AvisoAtaque3D.GRUPO).size()
	_paso(0.3)
	_ok("8 a 1 casilla de ella marca el aviso en el suelo antes de pegar", mo.avisos_dados == 1 and get_nodes_in_group(AvisoAtaque3D.GRUPO).size() == antes + 1 and _jug.danos.is_empty(), "avisos %d" % mo.avisos_dados)
	_paso(0.6)
	_ok("8 a los 0,9 s ya agarró: 12 de daño y raíces 1 s", _jug.danos == [12.0] and _jug.raices == [1.0], "daño %s · raíces %s" % [_jug.danos, _jug.raices])
	_ok("8 y lo cuenta", mo.golpes_dados == 1 and mo.toques == 1)
	_jug.position = _pos(Vector2i(12, 12))
	await _limpiar()
	# Si ella se sale del círculo antes de que acabe el aviso, no la agarra.
	var mo2: MouroEspectro3D = _mouro(Vector2i(5, 6), null, false)
	_jug.position = _pos(Vector2i(6, 6))
	_paso(0.3)
	_jug.position = _pos(Vector2i(12, 12))
	_paso(0.8)
	_ok("8 se ve venir: si sale del círculo del aviso no pasa nada", _jug.danos.is_empty() and _jug.raices.is_empty() and mo2.golpes_dados == 0, "daño %s" % [_jug.danos])
	await _limpiar()


func _mamoa_se_tapa() -> void:
	var cm := Vector2i(10, 6)
	var m: Mamoa3D = _mamoa(cm)
	var avisos: Array = []
	m.tapada.connect(func() -> void: avisos.append("tapada"))
	m.destapada.connect(func() -> void: avisos.append("destapada"))
	_ok("9 nace abierta", m.abierta and not m.esta_agrietada)
	var lz := Lanzador3D.new()
	m.lanz = lz
	lz._bloques.append({"celda": cm, "niveles": 1})
	m.revisar()
	_ok("9 la tierra de un hechizo encima la tapa", not m.abierta and avisos == ["tapada"], str(avisos))
	lz._bloques.clear()
	m.revisar()
	_ok("9 al deshacerse la tierra se destapa", m.abierta and avisos == ["tapada", "destapada"], str(avisos))
	lz._plataformas_tierra.append({"celdas": [cm], "nodo": null, "resta": 5.0})
	m.revisar()
	_ok("9 una plataforma de tierra también", not m.abierta)
	lz._plataformas_tierra.clear()
	m.revisar()
	var b := BloqueEmpujable3D.new()
	b.preparar(cm, "piedra", null)
	_mundo.add_child(b)
	m.revisar()
	_ok("9 un bloque empujable encima la tapa", not m.abierta)
	b.free()                                      # `_exit_tree` lo borra del registro de bloques
	Terreno3D.liberar_celda(cm)
	m.revisar()
	_ok("9 y al quitarlo se destapa", m.abierta)
	m.tapar_a_mano()
	_ok("9 a mano, la tapa un puzle", not m.abierta)
	m.destapar_a_mano()
	_ok("9 y a mano se destapa", m.abierta)
	lz.free()
	await _limpiar()


# ---------------------------------------------------------------------------------------------------------------------
#  Santa Compaña
# ---------------------------------------------------------------------------------------------------------------------

## Las tres piezas de mapa se leen bien (sin montar nada: el parseo de Puzle3D) y una clave `mamoa=` que no apunta a ninguna pieza avisa.
func _piezas_de_mapa() -> void:
	var texto: String = "; pieza m mamoa 3 3 agrietada=si tapada=no\n; pieza o mouro 5 5 mamoa=m quieto=si\n; pieza c compana 2 2 animas=4 camino=2,2+8,2\n; pieza x mouro 6 6 mamoa=no_existe\n"
	var r: Dictionary = Puzle3D.parsear(texto)
	var piezas: Array = r["piezas"]
	var por_id: Dictionary = {}
	for p in piezas:
		por_id[(p as Puzle3D.Pieza).id] = p
	_ok("11 las tres piezas nuevas se leen sin avisos de más (solo el de `mamoa=no_existe`)", piezas.size() == 4 and (r["avisos"] as Array).size() == 1, str(r["avisos"]))
	_ok("11 mamoa: agrietada y tapada", por_id["m"].p["agrietada"] == true and por_id["m"].p["tapada"] == false and por_id["m"].tipo == "mamoa")
	_ok("11 mouro: la mámoa es el id de otra pieza, y quieto", por_id["o"].p["mamoa"] == "m" and por_id["o"].p["quieto"] == true)
	_ok("11 compaña: número de ánimas y camino", por_id["c"].p["animas"] == 4.0 and por_id["c"].p["camino"] == [Vector2i(2, 2), Vector2i(8, 2)], str(por_id["c"].p))
	_ok("11 un `mamoa=` sin pieza se quita (la pieza sigue, sin enlace)", not por_id["x"].p.has("mamoa"))


## Los ids de las piezas de equipo que lleva una ánima en las manos.
func _piezas(a: AnimaCompana3D) -> Array:
	var r: Array = []
	for n in a.pj.find_children("*", "Node3D", true, false):
		if n.has_meta("equipo_id") and not n.is_queued_for_deletion():
			r.append(String(n.get_meta("equipo_id")))
	return r


func _compana_relevo() -> void:
	var sc: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var pasos: Array = []
	sc.cruz_pasada.connect(func(i: int) -> void: pasos.append(i))
	var viva: Array = sc.vivas()
	_ok("5 la procesión sale con 3 ánimas en fila", viva.size() == 3 and sc.animas.size() == 3)
	var guia: AnimaCompana3D = viva[0]
	_ok("5 el primero es el guía y lleva la cruz; los otros la palmatoria", guia.es_guia and _piezas(guia) == ["cruz_santa"] and _piezas(viva[1]) == ["vela_santa"] and _piezas(viva[2]) == ["vela_santa"] and not (viva[1] as AnimaCompana3D).es_guia, str(_piezas(guia)))
	var separacion: float = (viva[0] as Node3D).position.distance_to((viva[1] as Node3D).position)
	_ok("5 van a una casilla una de otra", absf(separacion - S) < 0.05, "%.2f u" % separacion)
	var siguiente: AnimaCompana3D = viva[1]
	var pos_guia: Vector3 = guia.position
	_mata(guia)
	_ok("5 cae el guía: la cruz NO pasa en el acto, se queda en el suelo donde cayó y la fila se para", pasos.is_empty() and not siguiente.es_guia and guia.muerto and sc.cruz_suelo != null and sc.fila_parada(), str(sc.cruz_suelo))
	_ok("5 la cruz del suelo está junto a donde cayó (a ≤ 0,3 u) y no es la de su mano (esa se esconde)", sc.cruz_suelo != null and sc.cruz_suelo.position.distance_to(pos_guia) <= 0.3 and _piezas_visibles(guia).is_empty(), "%.2f u" % sc.cruz_suelo.position.distance_to(pos_guia))
	_paso(0.9)
	_ok("5 a los 0,9 s todavía no se ha agachado ni ha pasado la cruz (viene andando a ella)", pasos.is_empty() and not siguiente.es_guia and not siguiente.recogiendo)
	_paso(0.3)
	_ok("5 RECOGER: a 1,2 s llega a la cruz y se agacha con CollectObject (estado `lanzar_recoger`)", siguiente.recogiendo and siguiente.pj.estado_anim() == "lanzar_recoger" and siguiente.pj.clip_actual() == "CollectObject", "estado %s · clip %s" % [siguiente.pj.estado_anim(), siguiente.pj.clip_actual()])
	_ok("5 RECOGER: y todavía no tiene la cruz (la mano no ha llegado abajo)", pasos.is_empty() and not siguiente.es_guia and _piezas(siguiente) == ["vela_santa"] and sc.cruz_suelo != null)
	_paso(AnimaCompana3D.T_ENGANCHE - 0.4)
	_ok("5 RECOGER: justo antes del enganche sigue sin ella", pasos.is_empty() and not siguiente.es_guia and sc.cruz_suelo != null)
	_paso(0.7)
	await process_frame
	await process_frame
	_ok("5 RECOGER: a los T_ENGANCHE s la cruz se le engancha (señal con su número) y la del suelo desaparece", pasos == [siguiente.numero] and siguiente.es_guia and sc.vivas()[0] == siguiente and sc.cruz_suelo == null, str(pasos))
	_ok("5 y se le cambia la pieza: ahora lleva la cruz y ya no la vela", _piezas(siguiente) == ["cruz_santa"], str(_piezas(siguiente)))
	_ok("5 se está agachando aún: la fila sigue parada hasta que se endereza", siguiente.recogiendo and sc.fila_parada())
	_paso(AnimaCompana3D.T_RECOGER)
	_ok("5 se endereza y la fila vuelve a andar (en marcha si no estuviera `quieto`)", not siguiente.recogiendo and not sc.fila_parada() and sc.recogidas == 1 and siguiente.cruces_recogidas == 1)
	_ok("5 la otra sigue con su vela y sin ser guía", _piezas(viva[2]) == ["vela_santa"] and not (viva[2] as AnimaCompana3D).es_guia)
	await _limpiar()
	# Si la matan a medio agacharse, la cruz sigue en el suelo y la recoge la siguiente.
	var sc2: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var pasos2: Array = []
	sc2.cruz_pasada.connect(func(i: int) -> void: pasos2.append(i))
	var v2: Array = sc2.vivas()
	var tercera: AnimaCompana3D = v2[2]
	_mata(v2[0])
	_paso(1.3)
	_ok("5 interrupción: la segunda se está agachando a por la cruz", (v2[1] as AnimaCompana3D).recogiendo and sc2.cruz_suelo != null)
	_mata(v2[1])
	_ok("5 interrupción: la matan a medias: la cruz sigue en el suelo, sin dueña, y nadie la tiene", pasos2.is_empty() and sc2.cruz_suelo != null and sc2.vivas() == [tercera] and not tercera.es_guia)
	_paso(3.2)
	await process_frame
	await process_frame
	_ok("5 interrupción: la tercera acaba recogiéndola", pasos2 == [tercera.numero] and tercera.es_guia and sc2.cruz_suelo == null and _piezas(tercera) == ["cruz_santa"], str(pasos2))
	await _limpiar()


## Los ids de las piezas de equipo VISIBLES que lleva `a` (la cruz del guía caído se esconde).
func _piezas_visibles(a: AnimaCompana3D) -> Array:
	var r: Array = []
	for n in a.pj.find_children("*", "Node3D", true, false):
		if n.has_meta("equipo_id") and not n.is_queued_for_deletion() and (n as Node3D).visible:
			r.append(String(n.get_meta("equipo_id")))
	return r


func _compana_ventana() -> void:
	var sc: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var rotas: Array = [0]
	sc.procesion_rota.connect(func() -> void: rotas[0] += 1)
	_mata(sc.vivas()[0])
	_paso(0.8)
	_mata(sc.vivas()[0])
	_paso(0.8)
	_ok("6 con dos caídas en 1,6 s la procesión sigue", rotas[0] == 0 and not sc.rota)
	_mata(sc.vivas()[0])
	_ok("6 las tres dentro de 2,5 s: la procesión se acaba de verdad (señal procesion_rota)", sc.rota and rotas[0] == 1 and sc.motivo_fin == "ventana", sc.motivo_fin)
	_ok("6 con botín (el oro de la tabla `anima`: 20)", _tiene_oro(sc.botin_soltado) == 20, str(sc.botin_soltado))
	_paso(8.0)
	_ok("6 y no entra nadie a reponer", sc.vivas().is_empty() and sc.reposiciones == 0)
	await _limpiar()


func _compana_reposicion() -> void:
	var sc: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var repuestas: Array = []
	var rotas: Array = [0]
	sc.repuesta.connect(func(n: int) -> void: repuestas.append(n))
	sc.procesion_rota.connect(func() -> void: rotas[0] += 1)
	for i in range(SantaCompana3D.REPOSICIONES_MAX):
		_mata(sc.vivas()[0])
		_paso(SantaCompana3D.T_REPONER - 0.5)
		_ok("7 reposición %d: a los 5,5 s aún no ha entrado" % (i + 1), repuestas.size() == i and sc.vivas().size() == 2, str(repuestas))
		_paso(0.7)
		await process_frame
		_ok("7 reposición %d: entra una ánima nueva por el extremo (señal repuesta(%d))" % [i + 1, i + 1], repuestas.size() == i + 1 and repuestas[i] == i + 1 and sc.vivas().size() == 3 and rotas[0] == 0, str(repuestas))
		_ok("7 reposición %d: siempre hay guía con la cruz" % (i + 1), (sc.vivas()[0] as AnimaCompana3D).es_guia and _piezas(sc.vivas()[0]) == ["cruz_santa"], str(_piezas(sc.vivas()[0])))
	_ok("7 tres reposiciones hechas: 1, 2, 3", repuestas == [1, 2, 3] and sc.reposiciones == 3)
	for k in range(3):
		_mata(sc.vivas()[0])
		_paso(3.0)
	_ok("7 agotadas las reposiciones, las bajas ya no se reponen y la procesión se acaba", sc.rota and rotas[0] == 1 and sc.motivo_fin == "agotada" and sc.reposiciones == 3, "%s · %s" % [sc.motivo_fin, rotas[0]])
	_ok("7 y suelta su botín", _tiene_oro(sc.botin_soltado) == 20)
	await _limpiar()


func _compana_surge_repuesta() -> void:
	var sc: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var guia: AnimaCompana3D = sc.vivas()[0]
	var pos_guia: Vector3 = guia.position
	_mata(guia)
	var nueva: AnimaCompana3D = sc.animas.back()
	_ok("12 REPONER: la repuesta se crea al caer el guía, latente, invisible, sin colisión y todavía en el grupo de combate (para el vigía)", nueva.latente and not nueva.pj.visible and nueva.collision_layer == 0 and nueva.is_in_group("combate3d"))
	_paso(1.0)
	_ok("12 REPONER: pasada la gracia del vigía (0,5 s) sale de los grupos de combate: nada la elige de objetivo", nueva.latente and not nueva.is_in_group("combate3d") and not nueva.is_in_group("goblins"))
	_paso(2.1)
	var t_ini: float = SantaCompana3D.T_REPONER - nueva.dur_surgir()
	_ok("12 REPONER: el clip va al FINAL de la espera: arranca a los %.1f s (T_REPONER %.0f − clip %.1f) y a 3,1 s aún no se ve" % [t_ini, SantaCompana3D.T_REPONER, nueva.dur_surgir()], absf(t_ini - 3.3) < 0.01 and nueva.dur_surgir() > 2.0 and not nueva.surgiendo and not nueva.pj.visible)
	_paso(0.3)
	var esperada: Vector3 = sc.punto_en(sc.s_cabeza - 2.0 * sc.separacion())["pos"]
	var ultima: AnimaCompana3D = sc.vivas().back()
	_ok("12 REPONER: a 3,4 s sale: ya se ve, surgiendo (estado `lanzar_surgir`, clip Getting_Up), latente", nueva.surgiendo and nueva.latente and nueva.pj.visible and nueva.pj.estado_anim() == "lanzar_surgir" and nueva.pj.clip_actual() == "Mixamo_Incorporarse", "estado %s · clip %s" % [nueva.pj.estado_anim(), nueva.pj.clip_actual()])
	_ok("12 REPONER: sale DETRÁS de la última viva (una separación más atrás sobre el recorrido), no en la cabeza ni donde cayó el guía", Vector2(nueva.position.x - esperada.x, nueva.position.z - esperada.z).length() < 0.05 and Vector2(nueva.position.x - pos_guia.x, nueva.position.z - pos_guia.z).length() > 1.0 and ultima != nueva, "dist a la esperada %.3f" % Vector2(nueva.position.x - esperada.x, nueva.position.z - esperada.z).length())
	_ok("12 REPONER: empieza HUNDIDA bajo el suelo (el nodo está a ras y el modelo %.2f u por debajo)" % (nueva.position.y - nueva.pj.position.y), nueva.position.y - nueva.pj.position.y > 0.5 * AnimaCompana3D.HUNDIDA_SURGIR, "%.3f" % (nueva.position.y - nueva.pj.position.y))
	_paso(0.3)
	_ok("12 REPONER: a 3,7 s sigue subiendo (aún bajo el suelo) y no es un blanco: sin colisión ni grupos", nueva.pj.position.y < nueva.position.y - 0.2 and nueva.collision_layer == 0 and not nueva.monitorable and not nueva.is_in_group("combate3d") and nueva.latente)
	_paso(1.4)
	_ok("12 REPONER: a 5,1 s ya está a ras (desplazamiento 0 exacto) pero sigue latente hasta que acabe el clip", nueva.pj.position == nueva.position and nueva.latente and nueva.surgiendo and nueva.collision_layer == 0)
	_paso(1.0)
	await process_frame
	_ok("12 REPONER: al acabar el clip (6 s) es un ENEMIGO de verdad: no latente, colisión, grupos de combate, a ras de suelo", not nueva.latente and not nueva.surgiendo and nueva.collision_layer == Lanzador3D.CAPA_REACTIVO and nueva.is_in_group("combate3d") and nueva.pj.position == nueva.position and sc.vivas().size() == 3)
	await _limpiar()
	# Si la casilla de detrás no está libre, sale en la siguiente hacia atrás del camino.
	var sc2: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	_mata(sc2.vivas()[0])
	var nueva2: AnimaCompana3D = sc2.animas.back()
	_paso(3.0)
	var celda_ocupada: Vector2i = Terreno3D.celda_de(sc2.punto_en(sc2.s_cabeza - 2.0 * sc2.separacion())["pos"] as Vector3)
	Terreno3D.bloquear_celda(celda_ocupada)
	_paso(0.4)
	var siguiente_atras: Vector3 = sc2.punto_en(sc2.s_cabeza - 3.0 * sc2.separacion())["pos"]
	_ok("12 REPONER: con la casilla de detrás bloqueada sale en la siguiente hacia atrás", nueva2.surgiendo and Terreno3D.celda_de(nueva2.position) != celda_ocupada and Vector2(nueva2.position.x - siguiente_atras.x, nueva2.position.z - siguiente_atras.z).length() < 0.05, str(Terreno3D.celda_de(nueva2.position)))
	Terreno3D.liberar_celda(celda_ocupada)
	await _limpiar()


func _compana_toque_y_maldicion() -> void:
	# Toque: se le cruza (a ≤ 1 casilla de una ánima): 10 y ralentizada 1,5 s.
	var sc: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var viva: Array = sc.vivas()
	_jug.position = (viva[1] as Node3D).position
	_paso(0.2)
	_ok("10 se les cruza: 10 de daño y ralentizada 1,5 s", _jug.danos.size() >= 1 and _jug.danos[0] == 10.0 and _jug.estados.size() >= 1 and _jug.estados[0] == ["hielo", 1.5], "daño %s · estados %s" % [_jug.danos, _jug.estados])
	await _limpiar()
	# Maldición: atacan a una ánima que NO es el guía; solo el guía se gira y lanza una maldición con aviso.
	var sc2: SantaCompana3D = _procesion([Vector2i(2, 3), Vector2i(11, 3)])
	var v2: Array = sc2.vivas()
	var guia: AnimaCompana3D = v2[0]
	_jug.position = guia.position + Vector3(0.0, 0.0, 3.0 * S)
	_paso(0.3)
	_ok("10 sin que la ataquen nadie maldice", guia.malditos == 0 and (v2[1] as AnimaCompana3D).malditos == 0 and _jug.danos.is_empty())
	(v2[2] as Combate3D).receive_damage(1.0)
	_paso(0.3)
	_ok("10 la atacan: solo el guía se gira y marca la maldición (aviso en el suelo)", guia.malditos == 1 and guia.maldiciendo and (v2[1] as AnimaCompana3D).malditos == 0 and (v2[2] as AnimaCompana3D).malditos == 0 and guia.avisos_dados == 1, "malditos %d" % guia.malditos)
	_ok("10 sin salirse de la fila: sigue a una casilla del siguiente", absf(guia.position.distance_to((v2[1] as Node3D).position) - S) < 0.05)
	_ok("10 y todavía no ha caído", _jug.danos.is_empty())
	_paso(1.0)
	_ok("10 a 1 s del aviso cae: 8 de daño y ralentizada", _jug.danos == [8.0] and _jug.estados == [["hielo", 2.0]], "daño %s · estados %s" % [_jug.danos, _jug.estados])
	await _limpiar()
