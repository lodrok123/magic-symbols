extends "res://herramientas/escenario_base.gd"
## CHAMÁN V2 (6/11; enemigos/chaman_3d.gd con `Chaman3D.CHAMAN_V2`, jugador/jugador_3d.gd: pilas de veneno, nucleo/datos/botin_tablas.tsv: antídoto). Sobre la sala real del chamán (como prueba_chaman_combate):
##   1 · PRIORIDADES: con un aliado por debajo del 60 % de vida elige CURAR antes que escudar; sin heridos, ESCUDAR; con todo en orden, ATACAR; el enfriamiento (8 s) lo comparten los dos rituales.
##   2 · el ritual de CURAR de verdad: va, traza, la onda cura CURA_RITUAL al herido (sin pasar de su máximo) y no da escudos; si el VIENTO (interrumpe) o un golpe lo cortan trazando, no cura.
##   3 · ATAQUE: flecha si ella se mueve y la ve; bola solo si lleva ≥ 2 s casi quieta (< 1 u) o no la ve; una flecha real tarda ≈ d / 9 s, hace 4 de daño y deja una pila de veneno.
##   4 · VENENO QUE SE ACUMULA: tope 3 pilas, dps = 2 × pilas, cada pila dura 4 s por su cuenta; el veneno NUNCA baja la vida de 1 (pilas ni veneno de ambiente); el antídoto quita las pilas.
##   5 · ANTÍDOTO: la tabla `chaman` lo suelta con probabilidad ≈ 50 % (semilla fija) y al morir cae al suelo de verdad.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_chaman_v2.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"
var _ch: Chaman3D = null
var _j: Jugador3D = null


func _guerreros() -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D) and not (n as Combate3D).muerto:
			res.append(n)
	return res


func _escudar(g: Combate3D) -> void:
	EscudoNaturaleza3D.poner(g)


func _desescudar(g: Combate3D) -> void:
	if g.escudo_natural != null and is_instance_valid(g.escudo_natural):
		g.escudo_natural.queue_free()
	g.escudo_natural = null


func _jugadora(c: Vector2i) -> void:
	colocar_jugador(c)
	_j.vida = 100.0
	_j._t_inv = 0.0
	_j._empuje = Vector3.ZERO
	_j.curar_estado("veneno")


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la sala tiene sus puzles", z != null)
	if z == null:
		return
	Repertoire.activate_all()
	await avanzar(10)
	_j = jugador as Jugador3D
	_ch = z.nodo("chaman_a") as Chaman3D
	_ok("0 hay chamán con CHAMAN_V2 encendido por defecto", _ch != null and Chaman3D.CHAMAN_V2)
	if _ch == null:
		return
	var gs: Array = _guerreros()
	_ok("0 hay dos guerreros goblin", gs.size() == 2, "(%d)" % gs.size())
	for g in gs:
		(g as Combate3D).quieto = true
	var g0: Combate3D = gs[0]
	var g1: Combate3D = gs[1]

	# ---- 1 · prioridades --------------------------------------------------------------------------------------------
	print("--- 1 · prioridades")
	_ch.quieto = true
	_jugadora(Vector2i(12, 4))
	_desescudar(g0)
	_desescudar(g1)
	g0.health = g0.vida_max
	g1.health = g1.vida_max
	_ch._cd_ritual = 0.0
	_ok("1.1 nadie herido y sin escudos: escudar", _ch.decidir_accion() == "escudo")
	g0.health = g0.vida_max * 0.5
	_ok("1.2 un aliado al 50 %% y otro sin escudo: CURAR antes que escudar (aliados_heridos=%d)" % _ch.aliados_heridos().size(), _ch.decidir_accion() == "curar" and _ch.aliados_heridos().size() == 1)
	g0.health = g0.vida_max * 0.6
	_ok("1.3 justo al 60 % no cuenta como herido (se escuda)", _ch.aliados_heridos().is_empty() and _ch.decidir_accion() == "escudo")
	_escudar(g0)
	_escudar(g1)
	_ok("1.4 todos sanos y escudados: atacar", _ch.decidir_accion() == "atacar")
	g1.health = g1.vida_max * 0.2
	_ok("1.5 herido aunque tenga escudo: curar", _ch.decidir_accion() == "curar")
	_ch._cd_ritual = 3.0
	_ok("1.6 el enfriamiento (compartido) manda: atacar aunque haya herido", _ch.decidir_accion() == "atacar")
	_ch._cd_ritual = 0.0
	Chaman3D.CHAMAN_V2 = false
	_ok("1.7 con CHAMAN_V2 apagado ya no cura (todos escudados: atacar)", _ch.decidir_accion() == "atacar")
	_desescudar(g0)
	_ok("1.8 …y escuda como antes", _ch.decidir_accion() == "escudo")
	Chaman3D.CHAMAN_V2 = true
	_escudar(g0)

	# ---- 2 · el ritual de curar ------------------------------------------------------------------------------------------
	print("--- 2 · el ritual de curar")
	_ch.quieto = false
	g0.health = g0.vida_max * 0.25
	g1.health = g1.vida_max
	var h0: float = g0.health
	_ch._cd_ritual = 0.0
	_ch.c_estado = "vigila"
	var t: float = 0.0
	while t < 15.0 and _ch.rituales_curar == 0:
		await avanzar_s(0.2)
		t += 0.2
	_ok("2.1 empieza un ritual de CURAR antes de atacar", _ch.rituales_curar == 1 and _ch.c_estado == "ritual" and _ch.flechas == 0 and _ch.bolas == 0, "(t=%.1f)" % t)
	t = 0.0
	while t < 12.0 and _ch.rituales_completos == 0:
		await avanzar_s(0.2)
		t += 0.2
	var esperado: float = minf(g0.vida_max, h0 + Chaman3D.CURA_RITUAL)
	_ok("2.2 la onda cura %.0f al herido sin pasar de su máximo (%.1f → %.1f, esperado %.1f)" % [Chaman3D.CURA_RITUAL, h0, g0.health, esperado], _ch.rituales_completos == 1 and absf(g0.health - esperado) < 0.01 and g0.health > h0)
	_ok("2.3 curó solo a quien lo necesitaba y no dio escudos", _ch.curas_dadas == 1 and _ch.escudos_dados == 0 and is_equal_approx(g1.health, g1.vida_max))
	_ok("2.4 el enfriamiento corre desde que acaba (≈ 8 s)", _ch._cd_ritual > 5.0, "(%.1f s)" % _ch._cd_ritual)
	# interrumpido por el VIENTO: golpe real de viento sin daño (solo `interrumpe`)
	g0.health = g0.vida_max * 0.25
	h0 = g0.health
	_ch._cd_ritual = 0.0
	_ch.c_estado = "vigila"
	var curas0: int = _ch.curas_dadas
	var rotos0: int = _ch.rituales_rotos
	t = 0.0
	while t < 12.0 and _ch.c_estado != "ritual":
		await avanzar_s(0.2)
		t += 0.2
	_ok("2.5 empieza otro ritual de curar", _ch.c_estado == "ritual" and _ch.rituales_curar == 2)
	await avanzar_s(0.8)
	var viento: Hechizo = Hechizo.construir(load("res://nucleo/wind_rune.tres") as RuneData, {}).con({"dano": 0.0})
	_ok("2.6 el hechizo de viento lleva `interrumpe` > 0 (%.2f)" % viento.interrumpe, viento.interrumpe > 0.0)
	var vida_ch: float = _ch.health
	_ch.golpe(viento, Vector3.RIGHT)
	await avanzar(4)
	_ok("2.7 el VIENTO (sin daño) corta el ritual de curar trazando: roto, sin cura", _ch.rituales_rotos == rotos0 + 1 and _ch.curas_dadas == curas0 and is_equal_approx(g0.health, h0) and is_equal_approx(_ch.health, vida_ch),
		"(rotos %d, curas %d)" % [_ch.rituales_rotos, _ch.curas_dadas])
	await avanzar_s(0.5)
	_ok("2.8 …y espera el enfriamiento compartido", _ch._cd_ritual > 5.0 and _ch.c_estado == "vigila")
	# interrumpido por un golpe
	_ch._cd_ritual = 0.0
	rotos0 = _ch.rituales_rotos
	t = 0.0
	while t < 12.0 and _ch.c_estado != "ritual":
		await avanzar_s(0.2)
		t += 0.2
	await avanzar_s(0.8)
	_ch.receive_damage(1.0)
	await avanzar(4)
	_ok("2.9 un golpe también lo corta", _ch.rituales_rotos == rotos0 + 1 and is_equal_approx(g0.health, h0))

	# ---- 3 · ataque ---------------------------------------------------------------------------------------------------
	print("--- 3 · flecha o bola")
	_ch.quieto = true
	_ch._cd_flecha = 0.0
	_ch._cd_bola = 0.0
	_ch._t_quieta = 0.0
	_ok("3.1 ella se mueve y la ve: FLECHA", _ch.decidir_ataque(8.0, true) == "flecha")
	_ch._t_quieta = 1.9
	_ok("3.2 casi dos segundos quieta aún no vale la bola", _ch.decidir_ataque(8.0, true) == "flecha")
	_ch._t_quieta = 2.1
	_ok("3.3 más de 2 s quieta: BOLA", _ch.decidir_ataque(8.0, true) == "bola")
	_ch._t_quieta = 0.0
	_ok("3.4 sin línea de vista (cobertura): BOLA", _ch.decidir_ataque(8.0, false) == "bola")
	_ch._cd_bola = 4.0
	_ch._t_quieta = 3.0
	_ok("3.5 con la bola en enfriamiento y ella quieta: flecha", _ch.decidir_ataque(8.0, true) == "flecha")
	_ok("3.6 sin verla y con la bola en enfriamiento: nada (la flecha pide verla)", _ch.decidir_ataque(8.0, false) == "")
	_ch._cd_bola = 0.0
	_ok("3.7 fuera de alcance (%.0f u): nada" % Chaman3D.ALCANCE_FLECHA, _ch.decidir_ataque(Chaman3D.ALCANCE_FLECHA + 1.0, true) == "")
	_ok("3.8 constantes: flecha 4 de daño, 9 u/s, CD 2,2, bola CD 6, alcance 10", is_equal_approx(Chaman3D.DANO_FLECHA_VENENO, 4.0) and is_equal_approx(Chaman3D.VEL_FLECHA_VENENO, 9.0)
		and is_equal_approx(Chaman3D.CD_FLECHA, 2.2) and is_equal_approx(Chaman3D.CD_BOLA_V2, 6.0) and is_equal_approx(Chaman3D.ALCANCE_FLECHA, 10.0))
	# la quietud real: dejarla quieta la acumula y moverla a más de 1 u la reinicia
	_ch.quieto = false
	_ch.objetivo = null
	_ch.c_estado = "vigila"
	_ch._cd_ritual = 99.0
	_ch._cd_flecha = 99.0
	_ch._cd_bola = 99.0
	_jugadora(Vector2i(13, 5))
	_ch._ref_jug = _j.position
	_ch._t_quieta = 0.0
	await avanzar_s(2.3)
	_ok("3.9 quieta 2,3 s: el chamán lo cuenta (%.1f s)" % _ch._t_quieta, _ch._t_quieta >= 2.0)
	_mover_jugadora(Vector3(Terreno3D.casilla * 0.8, 0, 0))      # 1,8 u: más que RADIO_QUIETA
	await avanzar(3)
	_ok("3.10 se mueve más de 1 u: la cuenta se reinicia (%.1f s)" % _ch._t_quieta, _ch._t_quieta < 0.5)
	# una flecha de verdad
	_ch._cd_flecha = 0.0
	_ch._cd_bola = 99.0
	_ch._cd_ritual = 99.0
	_ch.position = Vector3(_j.position.x + 7.0, _j.position.y, _j.position.z)
	_ch._empuje = Vector3.ZERO
	var dist: float = Vector2(_ch.position.x - _j.position.x, _ch.position.z - _j.position.z).length()
	_j.vida = 100.0
	_j._t_inv = 0.0
	_j.curar_estado("veneno")
	var v0: float = _j.vida
	var f0: int = _ch.flechas
	_ch._empezar_lanzar("flecha")
	t = 0.0
	while t < 4.0 and _ch.flechas == f0:
		await avanzar(1)
		t += 1.0 / 30.0
	_ok("3.11 suelta una flecha de veneno (verde, recta)", _ch.flechas == f0 + 1 and _ch.ultima_flecha != null and is_instance_valid(_ch.ultima_flecha))
	var t_sale: float = reloj.t
	t = 0.0
	while t < 4.0 and _j.pilas_veneno() == 0:
		await avanzar(1)
		t += 1.0 / 30.0
	var vuelo: float = reloj.t - t_sale
	var esperado_vuelo: float = dist / Chaman3D.VEL_FLECHA_VENENO
	_ok("3.12 la flecha la alcanza (jugadora quieta) en ≈ d/9 s (%.2f s, esperado ≈ %.2f)" % [vuelo, esperado_vuelo], _j.pilas_veneno() == 1 and absf(vuelo - esperado_vuelo) < 0.5)
	_ok("3.13 hace 4 de daño (vida %.1f → %.1f) y deja UNA pila" % [v0, _j.vida], v0 - _j.vida >= 3.99 and v0 - _j.vida <= 5.1 and _j.pilas_veneno() == 1)
	# se mueve y falla
	_ch._cd_flecha = 0.0
	_j.curar_estado("veneno")
	_j.vida = 100.0
	_ch._empezar_lanzar("flecha")
	f0 = _ch.flechas
	t = 0.0
	while t < 4.0 and _ch.flechas == f0:
		await avanzar(1)
		t += 1.0 / 30.0
	_mover_jugadora(Vector3(0, 0, Terreno3D.casilla * 2.0))      # se aparta del punto de impacto (de lado, 4,6 u)
	await avanzar_s(dist / Chaman3D.VEL_FLECHA_VENENO + 0.6)
	_ok("3.14 si ella se aparta, la flecha falla (sin daño ni pila)", _j.pilas_veneno() == 0 and is_equal_approx(_j.vida, 100.0))
	await avanzar_s(1.0)
	_ch.c_estado = "vigila"
	_ch.quieto = true

	# ---- 4 · veneno que se acumula ------------------------------------------------------------------------------------------
	print("--- 4 · pilas de veneno")
	_jugadora(Vector2i(12, 4))
	Consumibles.limpiar_protecciones()
	_j.vida = 60.0
	_j._t_inv = 0.0
	_ok("4.1 constantes: máx 3 pilas, 2 dps, 4 s, no mata", Jugador3D.PILA_VENENO_MAX == 3 and is_equal_approx(Jugador3D.PILA_VENENO_DPS, 2.0) and is_equal_approx(Jugador3D.PILA_VENENO_S, 4.0) and not Jugador3D.VENENO_PUEDE_MATAR)
	_ok("4.2 cada golpe suma una pila", _j.envenenar_pila() == 1 and _j.envenenar_pila() == 2 and _j.envenenar_pila() == 3)
	_ok("4.3 la cuarta no pasa de 3 (renueva la más vieja)", _j.envenenar_pila() == 3 and _j.pilas_veneno() == 3 and _j.tiene_estado("veneno"))
	_j.curar_estado("veneno")
	_j.vida = 60.0
	_j.envenenar_pila()
	await avanzar_s(2.0)
	var perdido1: float = 60.0 - _j.vida
	_ok("4.4 UNA pila durante 2 s ≈ 4 de daño (2 dps): perdió %.1f" % perdido1, perdido1 >= 2.5 and perdido1 <= 5.5)
	_j.curar_estado("veneno")
	_j.vida = 60.0
	_j.envenenar_pila()
	_j.envenenar_pila()
	_j.envenenar_pila()
	await avanzar_s(2.0)
	var perdido3: float = 60.0 - _j.vida
	_ok("4.5 TRES pilas durante 2 s ≈ 12 (6 dps): perdió %.1f, ×%.1f la de una" % [perdido3, perdido3 / maxf(perdido1, 0.01)], perdido3 >= 8.0 and perdido3 <= 15.5 and perdido3 > perdido1 * 2.0)
	await avanzar_s(2.6)
	_ok("4.6 a los 4,6 s ya no queda ninguna (cada pila dura 4 s)", _j.pilas_veneno() == 0 and not _j.tiene_estado("veneno"))
	# relojes independientes
	_j.vida = 60.0
	_j.envenenar_pila()
	await avanzar_s(2.5)
	_j.envenenar_pila()
	_ok("4.7 una pila nueva a los 2,5 s: hay 2", _j.pilas_veneno() == 2)
	await avanzar_s(1.8)
	_ok("4.8 …a los 4,3 s la primera ya caducó y la segunda sigue (1)", _j.pilas_veneno() == 1)
	_j.curar_estado("veneno")
	# no mata
	_j.vida = 3.0
	_j.envenenar_pila()
	_j.envenenar_pila()
	_j.envenenar_pila()
	await avanzar_s(4.5)
	_ok("4.9 el veneno NO MATA: con 3 de vida y 3 pilas, tras 4,5 s queda %.2f (≥ 1) y sigue viva" % _j.vida, _j.vida >= 1.0 and _j.vida <= 1.01 and not _j.muerto)
	_j.vida = 4.0
	_j.envenenar(30.0, 4.0)
	await avanzar_s(4.5)
	_ok("4.10 …tampoco el veneno de ambiente (nubes, pantano): queda %.2f" % _j.vida, _j.vida >= 1.0 and not _j.muerto)
	_j.vida = 0.5
	_j.envenenar_pila()
	await avanzar_s(1.2)
	_ok("4.11 con menos de 1 de vida no la toca (%.2f)" % _j.vida, is_equal_approx(_j.vida, 0.5) and not _j.muerto)
	_j.curar_estado("veneno")
	# nubes / pantano siguen valiendo y no apilan
	_j.vida = 60.0
	_j.envenenar(2.0, 3.0)
	_j.envenenar(2.0, 3.0)
	_ok("4.12 `envenenar` (ambiente) sigue igual: no apila, se queda con el mayor", _j.pilas_veneno() == 0 and _j.tiene_estado("veneno") and is_equal_approx(_j._veneno_dps, 2.0))
	_j.envenenar_pila()
	await avanzar_s(1.0)
	_ok("4.13 ambiente y pilas se suman (perdió %.1f en 1 s: 2 + 2 dps)" % (60.0 - _j.vida), (60.0 - _j.vida) >= 2.5 and (60.0 - _j.vida) <= 5.5)
	# antídoto
	Estado.i().agregar("antidoto", 1)
	var cons := Consumibles.new()
	cons.jugador = _j
	cons.equipar("antidoto")
	_j.envenenar_pila()
	_j.envenenar_pila()
	_ok("4.14 antes de beberlo: %d pilas" % _j.pilas_veneno(), _j.pilas_veneno() >= 2)
	var uso: bool = cons.usar_equipado()
	_ok("4.15 el ANTÍDOTO quita todas las pilas (y el veneno de ambiente) y protege", uso and _j.pilas_veneno() == 0 and not _j.tiene_estado("veneno") and Consumibles.protegido("veneno"))
	_ok("4.16 protegida, una flecha ya no deja pila", _j.envenenar_pila() == 0 and _j.pilas_veneno() == 0)
	Consumibles.limpiar_protecciones()

	# ---- 5 · el antídoto del chamán -------------------------------------------------------------------------------------------
	print("--- 5 · antídoto")
	Botin.tirada_forzada = 0.3
	var con_a: bool = _lista_tiene(Botin.tirar("chaman"), "antidoto")
	Botin.tirada_forzada = 0.7
	var sin_a: bool = not _lista_tiene(Botin.tirar("chaman"), "antidoto")
	Botin.tirada_forzada = -1.0
	_ok("5.1 la tabla `chaman`: con tirada 0,3 suelta antídoto y con 0,7 no", con_a and sin_a)
	seed(20261106)
	var n_ant: int = 0
	var n_pluma: int = 0
	var n: int = 4000
	for _i in range(n):
		var lista: Array = Botin.tirar("chaman")
		if _lista_tiene(lista, "antidoto"):
			n_ant += 1
		if _lista_tiene(lista, "pluma_chaman"):
			n_pluma += 1
	var frac: float = float(n_ant) / float(n)
	_ok("5.2 en %d muertes (semilla fija) cae en el %.1f %% (esperado 50 ± 3)" % [n, frac * 100.0], frac > 0.47 and frac < 0.53)
	_ok("5.3 la pluma sigue en su 50 %% (%.1f %%)" % (100.0 * float(n_pluma) / float(n)), float(n_pluma) / float(n) > 0.47 and float(n_pluma) / float(n) < 0.53)
	_ok("5.4 el objeto existe y la BD lo ve como fuente del chamán", Objetos.CONSUMIBLES.has("antidoto") and BD.fuentes_de("antidoto").any(func(f: Variant) -> bool: return String((f as Dictionary)["fuente"]) == "enemigo" and String((f as Dictionary)["de"]) == "chaman"))
	# muerte de verdad
	Botin.tirada_forzada = 0.1
	_ch.quieto = false
	_ch.receive_damage(1000.0)
	await avanzar(5)
	Botin.tirada_forzada = -1.0
	_ok("5.5 el chamán muere y deja un antídoto en el suelo", _ch.muerto and maqueta.find_child("Botin_antidoto*", true, false) != null)


## Teletransporta a la jugadora `d` u (como `colocar_jugador`, pero relativo).
func _mover_jugadora(d: Vector3) -> void:
	var pj: Node3D = _j.get("pj") as Node3D
	if pj != null:
		pj.position += d
	_j.position += d


func _lista_tiene(lista: Array, que: String) -> bool:
	for it in lista:
		if String((it as Dictionary)["que"]) == que:
			return true
	return false
