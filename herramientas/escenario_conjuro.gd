extends "res://herramientas/escenario_base.gd"
## Escenario 14.5 · conjuro (A3): al soltar, el hechizo sale tras la secuencia runa → voluta → forma → disparo (~0,45 s), no al instante.
## Lo escribe el Juego (16/10). Mide con el reloj del escenario (a --fixed-fps 30: un fotograma = 33 ms) y mira lo que se anota en PlayLog.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_conjuro.gd

const DESDE := Vector2i(6, 24)


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)
	var fases: Array = []
	lanzador.conjuro_fase.connect(func(f: String, e: String, _p: Vector3) -> void: fases.append([f, e, Time.get_ticks_msec()]))
	var lanzados: Array = []
	lanzador.lanzado.connect(func(e: String, f: String, n: int) -> void: lanzados.append([e, f, n, Time.get_ticks_msec()]))

	# --- 1. Sin conjuro (los escenarios de siempre): el disparo es inmediato ---
	_ok("1 por defecto el lanzamiento sigue siendo instantáneo", lanzar_con("fuego", false))
	_ok("1 el hechizo ya salió en el mismo fotograma", lanzados.size() == 1 and fases.size() == 1 and fases[0][0] == "disparo", str(fases))

	# --- 2. Con conjuro: no sale al instante, sale tras ~0,45 s ---
	await avanzar_s(lanzador.cooldown_total[0] + 0.3)
	lanzados.clear()
	fases.clear()
	var casts_antes: int = eventos("cast").size()
	_ok("2 el lanzamiento con conjuro se acepta", lanzar_con("fuego", true))
	_ok("2 NO sale en el mismo fotograma", lanzados.is_empty())
	_ok("2 hay un conjuro en marcha", lanzador.conjurando)
	_ok("2 la recarga y la tinta se cobran ya al soltar", lanzador.cooldown_left[0] > 0.0)
	_ok("2 empieza la fase «runa»", fases.size() == 1 and fases[0][0] == "runa", str(fases))
	await avanzar_s(0.2)
	_ok("2 a los ~0,2 s sigue sin salir y la voluta ya viaja", lanzados.is_empty() and _nombres(fases).has("voluta"), str(_nombres(fases)))
	await avanzar_s(0.5)
	_ok("2 pasados 0,7 s ha salido UN hechizo", lanzados.size() == 1, str(lanzados.size()))
	_ok("2 las fases salieron en orden: runa, voluta, forma, disparo", _nombres(fases) == ["runa", "voluta", "forma", "disparo"], str(_nombres(fases)))
	var previsto: float = lanzador.retardo_total("fuego")
	_ok("2 el retardo previsto del fuego ronda los 0,45 s", absf(previsto - 0.45) < 0.001, "%.3f" % previsto)
	var real: float = float(casts_retardo(eventos("cast")))
	# T-CP1 (18/10): con cast point el disparo sale cuando el CLIP llega a su instante (x_mano: ≈ 0,40 s), no por el reloj de RETARDO_CONJURO (0,45 s).
	_ok("2 y el disparo salió entre 0,35 y 0,55 s (de juego) después de soltar", real > 0.35 and real < 0.55, "%.2f s" % real)
	_ok("2 ya no hay conjuro en marcha", not lanzador.conjurando)
	var casts: Array = eventos("cast")
	_ok("2 PlayLog: un `cast` más, con su retardo", casts.size() == casts_antes + 1 and float(casts.back().get("retardo", 0.0)) > 0.3, str(casts.back()) if not casts.is_empty() else "")
	var conj: Array = eventos("conjuro")
	_ok("2 PlayLog: evento `conjuro` con lo previsto y lo medido", not conj.is_empty() and float(conj.back().get("previsto", 0.0)) > 0.4 and float(conj.back().get("retardo", 0.0)) > 0.3 and not bool(conj.back().get("interrumpido", true)), str(conj.back()) if not conj.is_empty() else "")

	# --- 3. Parametrizable por elemento y con la escala global ---
	_ok("3 el rayo tarda menos que el fuego", lanzador.retardo_total("rayo") < lanzador.retardo_total("fuego"))
	_ok("3 la tierra tarda más que el fuego", lanzador.retardo_total("tierra") > lanzador.retardo_total("fuego"))
	_ok("3 un elemento sin entrada usa el «defecto»", is_equal_approx(lanzador.retardo_total("cosa_rara"), 0.45))
	lanzador.conjuro_escala = 2.0
	_ok("3 la escala 2 duplica el retardo", is_equal_approx(lanzador.retardo_total("fuego"), 0.9))
	lanzador.conjuro_escala = 0.0
	_ok("3 la escala 0 lo quita", is_equal_approx(lanzador.retardo_total("fuego"), 0.0))
	await avanzar_s(lanzador.cooldown_total[0] + 0.3)
	lanzados.clear()
	lanzar_con("fuego", true)
	_ok("3 con escala 0 el disparo es inmediato aunque se pida conjuro", lanzados.size() == 1)
	lanzador.conjuro_escala = 1.0

	# --- 4. Apagar el conjuro: vuelve al disparo instantáneo ---
	await avanzar_s(lanzador.cooldown_total[0] + 0.3)
	lanzados.clear()
	lanzador.conjuro_activo = false
	lanzar_con("fuego", true)
	_ok("4 con `conjuro_activo` en false el disparo es inmediato", lanzados.size() == 1)
	lanzador.conjuro_activo = true

	# --- 5. Si el jugador muere mientras conjura, no sale nada ---
	await avanzar_s(lanzador.cooldown_total[0] + 0.3)
	lanzados.clear()
	lanzar_con("fuego", true)
	jugador.set("_t_muerte", 99.0)             # que no reaparezca solo durante la prueba
	jugador.set("muerto", true)
	await avanzar_s(0.7)
	_ok("5 muerto durante el conjuro: no sale el hechizo", lanzados.is_empty())
	var inter: Array = eventos("conjuro").filter(func(e: Dictionary) -> bool: return bool(e.get("interrumpido", false)))
	_ok("5 y PlayLog anota el conjuro interrumpido", inter.size() >= 1)
	jugador.set("muerto", false)


func lanzar_con(elemento: String, con_conjuro: bool) -> bool:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	lanzador.place_sigil("flecha")
	lanzador.cooldown_left[0] = 0.0
	if jugador.tinta != null:
		jugador.tinta.actual = 100.0
	return lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT, con_conjuro)


func casts_retardo(casts: Array) -> float:
	return float(casts.back().get("retardo", 0.0)) if not casts.is_empty() else -1.0


func _nombres(fases: Array) -> Array:
	var r: Array = []
	for f in fases:
		r.append(f[0])
	return r
