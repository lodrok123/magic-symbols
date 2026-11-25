extends "res://herramientas/escenario_base.gd"
## Prueba · T1 «LA PRESA EN SECO» del laboratorio de agua (20/11/2026, rama demo/puzles-tres-sellos; docs/PUZLES_DEMO_TRES_SELLOS_2026-11-20.md): salas T1a (0,4) y T1b (1,4) (filas 33..39 desde el 25/11) de PuzlesAgua.txt.
## La regla que enseña: la tierra NO se levanta sobre agua (`Lanzador3D.puede_construir_en`: «es agua») pero un bloque de tierra hace de presa para la simulación (`refrescar_casilla`) y caduca a los 25 s.
## La tierra se levanta con `Lanzador3D.construir_tierra`, la misma puerta que usa el hechizo (comprueba `puede_construir_en`; no se escribe en la simulación a mano).
##   · T1a: sin presa el grifo abierto reparte el agua entre los dos brazos y el nivel NO llega; se cierra el grifo, los brazos se vacían, se levanta la presa en SECO y se reabre: llega y abre la puerta. La tierra sobre el agua se rechaza.
##   · T1b: sin presa (tinaja regada) la cuenca se vacía por la boca y no llega; con la tierra en la boca puesta antes, sí, y la puerta abre; cuando la presa caduca, se pierde el nivel y la puerta se cierra.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_presa_tierra.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"
const PRESA_A: Vector2i = Vector2i(3, 36)         ## primera casilla del brazo del desagüe de T1a
const BOCA_B: Vector2i = Vector2i(12, 37)         ## boca del desagüe de T1b
const MAX_ABRIR_S: float = 15.0                   ## T1a: con presa, el nivel debe llegar en menos de esto
const MAX_ABRIR_B_S: float = 20.0                 ## T1b: lo mismo (la tinaja tarda en llegar el agua; la presa aguanta 25 s)

var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena y monta las salas T1a y T1b sin avisos", lab != null and (lab.get("_presas") as Array).size() == 2 and (lab.get("_avisos") as Array).is_empty(), str(lab.get("_avisos")) if lab != null else "sin lab")
	if lab == null:
		return
	# Las dos pasadas de T1b van en procesos distintos (la tinaja echa 20 u³ una sola vez): sin argumentos, T1a y T1b CON presa; `-- sin`, T1b sin presa; `-- t1a`, solo T1a.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("sin"):
		await _t1b_sin_presa()
		return
	await _t1a()
	if not args.has("t1a"):
		await _t1b_con_presa()


func _prof(c: Vector2i) -> float:
	return Terreno3D.agua_sim.profundidad_casilla(c)


## Espera a que `cond` sea cierta (tope `max_s`) y devuelve cuántos segundos pasaron (o -1 si no llegó).
func _hasta(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while t < max_s:
		if bool(cond.call()):
			return t
		t += await avanzar_s(0.25)
	return -1.0


func _pulsar(c: Vector2i) -> void:
	(lab.call("pulsador_en", c) as Node).call("pulsar")


# ---------------------------------------------------------------------------------------------------------------------
#  T1a · Desvío en seco
# ---------------------------------------------------------------------------------------------------------------------

func _t1a() -> void:
	var q: Dictionary = lab.call("presa", "T1a")
	var k: Node = q["compuerta"]
	var nv: NivelAgua3D = q["nivel"]
	var puerta: Node = q["puerta"]
	colocar_jugador(Vector2i(4, 33))
	_ok("T1a.1 empieza en seco: grifo cerrado, brazos vacíos, puerta cerrada", not bool(k.get("abierta")) and _prof(Vector2i(3, 36)) == 0.0 and _prof(Vector2i(5, 36)) == 0.0 and not bool(puerta.get("abierta")))
	_ok("T1a.2 con el cauce vacío la tierra se admite en la casilla del brazo del desagüe (puede_construir_en vacío)", lanzador.puede_construir_en(PRESA_A) == "", lanzador.puede_construir_en(PRESA_A))
	# 1 · Sin presa: se abre el grifo y el agua se reparte; el nivel no llega.
	_pulsar(Vector2i(2, 34))
	_ok("T1a.3 el botón abre el grifo", bool(k.get("abierta")))
	var r: Dictionary = {"max": 0.0}
	var t_sin: float = -1.0
	for i in range(12):
		await avanzar_s(2.5)
		r["max"] = maxf(float(r["max"]), nv.profundidad)
		_aviso("T1a sin presa t=%.1f s" % (2.5 * (i + 1)), "oeste %.2f fork %.2f este(5) %.2f nivel(6) %.2f fin(7) %.2f" % [_prof(Vector2i(3, 36)), _prof(Vector2i(4, 36)), _prof(Vector2i(5, 36)), _prof(Vector2i(6, 36)), _prof(Vector2i(7, 36))])
		if bool(puerta.get("abierta")):
			t_sin = 2.5 * (i + 1)
			break
	var maxn: float = float(r["max"])
	_aviso("T1a sin presa tras 30 s", "nivel %.2f (objetivo %.2f) oeste %.2f puerta %s" % [nv.profundidad, nv.objetivo, _prof(Vector2i(3, 36)), "ABIERTA" if bool(puerta.get("abierta")) else "cerrada"])
	_ok("T1a.4 SIN presa el nivel no llega (nivel %.2f < %.2f) y la puerta sigue cerrada" % [maxn, nv.objetivo], t_sin < 0.0 and not bool(puerta.get("abierta")) and nv.profundidad < nv.objetivo)
	# 2 · Con un hilo de agua (< AguaSim3D.UMBRAL_AGUA) la casilla aún no «es agua»: lo que no se admite es la tierra sobre agua de verdad (se prueba más abajo, en el nivel lleno).
	_aviso("T1a hilo de agua en el brazo del desagüe", "%.2f u (es agua desde %.2f): puede_construir_en «%s»" % [_prof(PRESA_A), AguaSim3D.UMBRAL_AGUA, lanzador.puede_construir_en(PRESA_A)])
	# 3 · Reintentar: se cierra el grifo y los brazos se vacían (el botón tiene rearme de 2 s).
	await avanzar_s(2.2)
	_pulsar(Vector2i(2, 34))
	_ok("T1a.6 el botón cierra el grifo", not bool(k.get("abierta")))
	var t_vacia: float = await _hasta(func() -> bool: return _prof(Vector2i(3, 36)) < 0.03 and _prof(Vector2i(5, 36)) < 0.03 and _prof(Vector2i(6, 36)) < 0.03 and _prof(Vector2i(4, 36)) < 0.03, 40.0)
	_ok("T1a.7 cerrado el grifo los brazos se vacían (%.1f s)" % t_vacia, t_vacia >= 0.0)
	_ok("T1a.8 vacío el cauce la puerta está cerrada y la tierra vuelve a admitirse", not bool(puerta.get("abierta")) and lanzador.puede_construir_en(PRESA_A) == "")
	# 4 · Con presa: tierra en seco, después el grifo.
	_ok("T1a.9 la tierra se levanta en la primera casilla del brazo del desagüe", lanzador.construir_tierra(PRESA_A) and Terreno3D.altura_en(PRESA_A) >= 1)
	await avanzar_s(2.2)
	_pulsar(Vector2i(2, 34))
	_ok("T1a.10 el botón abre el grifo", bool(k.get("abierta")))
	var t_con: float = -1.0
	for i in range(10):
		await avanzar_s(2.0)
		_aviso("T1a con presa t=%.1f s" % (2.0 * (i + 1)), "oeste %.2f fork %.2f este(5) %.2f nivel(6) %.2f fin(7) %.2f" % [_prof(Vector2i(3, 36)), _prof(Vector2i(4, 36)), _prof(Vector2i(5, 36)), _prof(Vector2i(6, 36)), _prof(Vector2i(7, 36))])
		if bool(puerta.get("abierta")):
			t_con = 2.0 * (i + 1)
			break
	_ok("T1a.11 CON presa el nivel llega (%.2f ≥ %.2f) y abre la puerta a los %.1f s (< %.0f s)" % [nv.profundidad, nv.objetivo, t_con, MAX_ABRIR_S], t_con >= 0.0 and t_con < MAX_ABRIR_S)
	var c_nivel := Vector2i(6, 36)
	_ok("T1a.11b con el agua en el brazo del nivel (%.2f ≥ %.2f) la tierra se RECHAZA («%s») y construir_tierra no levanta nada" % [_prof(c_nivel), AguaSim3D.UMBRAL_AGUA, lanzador.puede_construir_en(c_nivel)],
		lanzador.puede_construir_en(c_nivel) == "es agua" and not lanzador.construir_tierra(c_nivel) and Terreno3D.altura_en(c_nivel) == 0)
	_ok("T1a.12 el brazo del desagüe se queda a este lado de la presa vacío (oeste %.2f)" % _prof(Vector2i(2, 36)), _prof(Vector2i(2, 36)) < 0.1)
	volcar("t1a", {"sin_presa_nivel": snappedf(maxn, 0.01), "con_presa_t_puerta": snappedf(t_con, 0.1)})
	# Al caducar la presa (25 s) el agua pasa al desagüe y el nivel se pierde.
	var t_caduca: float = await _hasta(func() -> bool: return Terreno3D.altura_en(PRESA_A) == 0, 30.0)
	var t_pierde: float = await _hasta(func() -> bool: return not bool(puerta.get("abierta")), 60.0)
	_ok("T1a.13 la presa caduca (%.1f s después)" % t_caduca, t_caduca >= 0.0)
	_aviso("T1a tras caducar la presa", "la puerta tarda %.1f s en cerrarse; nivel %.2f; puerta %s" % [t_pierde, nv.profundidad, "ABIERTA" if bool(puerta.get("abierta")) else "cerrada"])
	_pulsar(Vector2i(2, 34))                      # (rearme de sobra) deja el grifo cerrado
	await avanzar_s(1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  T1b · Retener
# ---------------------------------------------------------------------------------------------------------------------

func _t1b_sin_presa() -> void:
	var q: Dictionary = lab.call("presa", "T1b")
	var nv: NivelAgua3D = q["nivel"]
	var puerta: Node = q["puerta"]
	colocar_jugador(Vector2i(12, 33))
	_ok("T1b.1 empieza en seco: cuenca y boca vacías, puerta cerrada", _prof(Vector2i(12, 36)) == 0.0 and _prof(BOCA_B) == 0.0 and not bool(puerta.get("abierta")))
	_ok("T1b.2 con la boca seca la tierra se admite", lanzador.puede_construir_en(BOCA_B) == "", lanzador.puede_construir_en(BOCA_B))
	_pulsar(Vector2i(10, 34))                     # el botón moja la tinaja
	var maxn: float = 0.0
	var t_sin: float = -1.0
	for i in range(100):
		await avanzar_s(0.5)
		maxn = maxf(maxn, nv.profundidad)
		if bool(puerta.get("abierta")):
			t_sin = 0.5 * (i + 1)
			break
	_ok("T1b.3 SIN presa, regada la tinaja (20 u³ en 40 s), el nivel no llega (máximo %.2f < %.2f) y la puerta sigue cerrada" % [maxn, nv.objetivo], t_sin < 0.0 and not bool(puerta.get("abierta")) and maxn < nv.objetivo)
	_aviso("T1b sin presa tras 60 s", "nivel %.2f boca %.2f desagüe %.2f" % [nv.profundidad, _prof(BOCA_B), _prof(Vector2i(12, 38))])


func _t1b_con_presa() -> void:
	var q: Dictionary = lab.call("presa", "T1b")
	var nv: NivelAgua3D = q["nivel"]
	var puerta: Node = q["puerta"]
	var tinaja: Node = q["tinaja"]
	colocar_jugador(Vector2i(12, 33))
	_ok("T1b.4 vacía la cuenca, la boca admite la tierra", lanzador.puede_construir_en(BOCA_B) == "", lanzador.puede_construir_en(BOCA_B))
	_ok("T1b.5 la tierra se levanta en la boca del desagüe", lanzador.construir_tierra(BOCA_B) and Terreno3D.altura_en(BOCA_B) >= 1)
	var t0: float = reloj.t
	tinaja.call("on_spell_hit", LabPuzlesAgua3D._runa(["agua", "humedo"]), Vector3.ZERO)       # regar la tinaja con un hechizo de agua (vía natural)
	var t_con: float = await _hasta(func() -> bool: return bool(puerta.get("abierta")), 40.0)
	_ok("T1b.6 CON presa en la boca el nivel llega (%.2f ≥ %.2f) y abre la puerta a los %.1f s (< %.0f s)" % [nv.profundidad, nv.objetivo, t_con, MAX_ABRIR_B_S], t_con >= 0.0 and t_con < MAX_ABRIR_B_S)
	_ok("T1b.7 con agua en la cuenca (%.2f) la tierra no se admite en ella (puede_construir_en: «%s»)" % [_prof(Vector2i(12, 36)), lanzador.puede_construir_en(Vector2i(12, 36))], lanzador.puede_construir_en(Vector2i(12, 36)) == "es agua" and not lanzador.construir_tierra(Vector2i(12, 36)))
	var t_caduca: float = await _hasta(func() -> bool: return Terreno3D.altura_en(BOCA_B) == 0, 40.0)
	var t_pierde: float = await _hasta(func() -> bool: return not bool(puerta.get("abierta")), 40.0)
	_aviso("T1b la presa caduca", "a los %.1f s del riego; puerta %s tras %.1f s más; nivel %.2f" % [reloj.t - t0, "cerrada" if t_pierde >= 0.0 else "sigue abierta", t_pierde, nv.profundidad])
	_ok("T1b.8 al caducar la presa y escaparse el agua, el nivel se pierde y la puerta se cierra", t_caduca >= 0.0 and t_pierde >= 0.0)
	volcar("t1b", {"con_presa_t_puerta": snappedf(t_con, 0.1)})
