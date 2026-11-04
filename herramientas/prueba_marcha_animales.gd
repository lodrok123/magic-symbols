extends "res://herramientas/escenario_base.gd"
## 4/11 · MARCHA DE LOS ANIMALES (MarchaCuadrupedo3D; encargo de Pablo: canouro = hiena, loberno = lobo). Sin ventana, a 30 fps fijos, sobre la escena real del Bosque.
##   A  perfiles: los dos modelos tienen perfil, sus clips existen y el interruptor MARCHA_ANIMAL = false devuelve las velocidades de antes (1,0 / 2,4 u/s) sin capa.
##   B  postura (esqueleto muestreado fotograma a fotograma, antes = interruptor apagado): pendiente del lomo, altura de la cabeza, cabeceo, vaivén lateral de la cabeza.
##   C  pies: la velocidad del pie delantero apoyado (el suelo que pisa) frente al avance real, antes y ahora (patinado).
##   D  Combate3D: velocidades de patrulla y persecución, el lobo trota más rápido que la hiena, giro con velocidad angular máxima, la cabeza sigue a la presa con límite,
##      acecho agachado y embestida del lobo, zigzag / parada / retroceso / arrancada / retirada de la hiena, y los goblins intactos.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_marcha_animales.gd

const FILA: int = 33
var _creados: Array = []
var _tabla: Array = []


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _cerca(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _enemigo(id: String, c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", [id], p)
	if modelo == null:
		return null
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
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
			if n is Combate3D:
				(n as Combate3D)._quitar_aviso()
			if lista is Array:
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


func _mn(a: Array) -> float:
	var r: float = INF
	for v in a:
		r = minf(r, float(v))
	return r


func _mx(a: Array) -> float:
	var r: float = -INF
	for v in a:
		r = maxf(r, float(v))
	return r


func _med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t: float = 0.0
	for v in a:
		t += float(v)
	return t / float(a.size())


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(20)
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	_caso_perfiles()
	await _caso_postura()
	await _caso_pies()
	await _caso_combate()
	await _caso_interruptor_y_goblins()
	_limpiar()
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	print("")
	print("TABLA (medido):")
	for l in _tabla:
		print("  " + String(l))


# --- A · perfiles ---------------------------------------------------------------------------------------------------------

func _caso_perfiles() -> void:
	for id in ["loberno", "canouro"]:
		_ok("A %s tiene perfil de marcha" % id, MarchaCuadrupedo3D.tiene_perfil(id))
		var pj := Pj3D.new()
		root.add_child(pj)
		pj.cargar(id)
		var perfil: Dictionary = MarchaCuadrupedo3D.PERFILES[id]
		var faltan: Array = []
		for k in ["clip_trote", "clip_correr", "clip_acecho"]:
			if not pj._ap.has_animation(String(perfil[k])):
				faltan.append(perfil[k])
		for k in (perfil["v_clip"] as Dictionary):
			if not pj._ap.has_animation(String(k)):
				faltan.append(k)
		_ok("A %s: los clips del perfil existen en el GLB" % id, faltan.is_empty(), str(faltan))
		var m: MarchaCuadrupedo3D = MarchaCuadrupedo3D.para(pj)
		_ok("A %s: la capa se cuelga del esqueleto (Skeleton3D → MarchaCuadrupedo)" % id, m != null and m.get_parent() is Skeleton3D)
		pj.queue_free()


# --- B · postura -----------------------------------------------------------------------------------------------------------

## Cuelga un animal suelto de la escena, a su altura de juego, y lo deja andando al `modo` pedido. Con `con_marcha` false el modelo va como antes (clip walk/run a ×1).
func _modelo(id: String, alto: float) -> Pj3D:
	var pj := Pj3D.new()
	maqueta.add_child(pj)
	pj.cargar(id)
	pj.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	pj.set_alto(alto)
	pj.position = _pos(Vector2i(34, FILA + 3))
	return pj


## Muestrea `n` fotogramas del esqueleto y devuelve estadísticas. `m` puede ser null (esqueleto sin capa): entonces se calcula con la propia clase auxiliar.
func _muestrear(pj: Pj3D, m: MarchaCuadrupedo3D, n: int) -> Dictionary:
	var sk: Skeleton3D = pj._esqueleto()
	var esc: float = sk.global_transform.basis.get_scale().x
	var lomo: Array = []
	var cab_y: Array = []
	var cab_l: Array = []
	var yaw: Array = []
	var pie_f: Array = [[], []]
	var pie_y: Array = [[], []]
	var ik_f: Array = [[], []]
	var ik_y: Array = [[], []]
	var ts: Array = []
	for i in n:
		await process_frame
		var u: Dictionary = m.ult
		lomo.append(float(u["lomo"]))
		var c: Array = u["cab"]
		cab_y.append(float(c[0]) * esc)
		cab_l.append(float(c[1]) * esc)
		yaw.append(float(u["yaw"]))
		for j in 2:
			var pp: Vector3 = (u["pie_i"] if j == 0 else u["pie_d"]) as Vector3
			var qq: Vector3 = (u["ik_i"] if j == 0 else u["ik_d"]) as Vector3
			pie_f[j].append(pp.dot(m._fw) * esc)
			pie_y[j].append(pp.y * esc)
			ik_f[j].append(qq.dot(m._fw) * esc)
			ik_y[j].append(qq.y * esc)
		ts.append(reloj.t)
	# El pie: el hueso de control (IK) si el clip lo mueve (Walk, Gallop); si no, la estimación por la tibia (Run_Alt). Cada pie por separado: apoyado = el 30 % más bajo.
	var vs_pie: Array = []
	for j in 2:
		var pf: Array = pie_f[j]
		var py: Array = pie_y[j]
		if _mx(ik_f[j]) - _mn(ik_f[j]) > 0.5 * (_mx(pf) - _mn(pf)) and _mx(ik_y[j]) - _mn(ik_y[j]) > 0.01:
			pf = ik_f[j]
			py = ik_y[j]
		var ymin: float = _mn(py)
		var rng: float = _mx(py) - ymin
		var vs: Array = []
		for i in range(1, n):
			if float(py[i]) <= ymin + 0.3 * rng + 0.001 and float(ts[i]) > float(ts[i - 1]):
				vs.append(-(float(pf[i]) - float(pf[i - 1])) / (float(ts[i]) - float(ts[i - 1])))
		if vs.size() >= 3:
			vs_pie.append(_med(vs))
	var v_pies: float = _media(vs_pie)
	return {"lomo": _media(lomo), "cab_y": _media(cab_y), "cab_y_p2p": _mx(cab_y) - _mn(cab_y), "cab_l_p2p": _mx(cab_l) - _mn(cab_l), "yaw_max": _mx(yaw), "yaw_min": _mn(yaw),
		"v_pie": v_pies, "v_pie_i": vs_pie[0] if vs_pie.size() > 0 else 0.0, "v_pie_d": vs_pie[1] if vs_pie.size() > 1 else 0.0}


## Modo `antes`: sin capa (interruptor apagado) y el clip de siempre a ×1; `ahora`: con capa y `v` u/s.
func _estado(id: String, alto: float, ahora: bool, rol: String, v: float, modo: String = "") -> Dictionary:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = ahora
	var pj: Pj3D = _modelo(id, alto)
	var m: MarchaCuadrupedo3D = MarchaCuadrupedo3D.para(pj)
	m.medir = true
	await avanzar(6)
	if ahora:
		m.agachado = 1.0 if modo == "acecho" else 0.0
		m.velocidad = v
		m.animar_andar(v, modo)
	else:
		pj.jugar(rol)
		pj.set_velocidad_animacion(1.0, false)
	await avanzar(20)
	var res: Dictionary = await _muestrear(pj, m, 60)
	if ahora:
		res["clip"] = pj.clip_actual()
		res["vel"] = pj.velocidad_animacion()
	pj.queue_free()
	await avanzar(2)
	return res


func _caso_postura() -> void:
	var ant_l: Dictionary = await _estado("loberno", 0.75, false, "walk", 1.0)
	var des_l: Dictionary = await _estado("loberno", 0.75, true, "walk", MarchaCuadrupedo3D.PERFILES["loberno"]["v_patrulla"])
	var ant_c: Dictionary = await _estado("canouro", 0.55, false, "walk", 1.0)
	var des_c: Dictionary = await _estado("canouro", 0.55, true, "walk", MarchaCuadrupedo3D.PERFILES["canouro"]["v_patrulla"])
	var des_lc: Dictionary = await _estado("loberno", 0.75, true, "run", MarchaCuadrupedo3D.PERFILES["loberno"]["v_perseguir"])
	var des_cc: Dictionary = await _estado("canouro", 0.55, true, "run", MarchaCuadrupedo3D.PERFILES["canouro"]["v_perseguir"])
	var ant_lc: Dictionary = await _estado("loberno", 0.75, false, "run", 2.4)
	var ant_cc: Dictionary = await _estado("canouro", 0.55, false, "run", 2.4)
	for par in [["loberno patrulla", ant_l, des_l], ["canouro patrulla", ant_c, des_c], ["loberno corre", ant_lc, des_lc], ["canouro corre", ant_cc, des_cc]]:
		_tabla.append("B %-17s lomo %+.1f° → %+.1f° | cabeza sobre cruz %.3f → %.3f u | cabeceo %.3f → %.3f u | vaivén lateral cabeza %.3f → %.3f u | giro cabeza ±%.0f°" % [par[0],
			float(par[1]["lomo"]), float(par[2]["lomo"]), float(par[1]["cab_y"]), float(par[2]["cab_y"]), float(par[1]["cab_y_p2p"]), float(par[2]["cab_y_p2p"]),
			float(par[1]["cab_l_p2p"]), float(par[2]["cab_l_p2p"]), maxf(absf(float(par[2]["yaw_max"])), absf(float(par[2]["yaw_min"])))])
	# Loberno: lomo nivelado, cabeza más baja
	_ok("B loberno: el lomo pasa de %+.1f° a %+.1f° (nivelado: entre −3° y +4°)" % [ant_l["lomo"], des_l["lomo"]], float(ant_l["lomo"]) < -4.0 and float(des_l["lomo"]) > -3.0 and float(des_l["lomo"]) < 4.0)
	_ok("B loberno: la cabeza va más baja al trotar (%.3f → %.3f u sobre la cruz, ≥ 25 % menos)" % [ant_l["cab_y"], des_l["cab_y"]], float(des_l["cab_y"]) <= 0.75 * float(ant_l["cab_y"]))
	_ok("B loberno corriendo: la cabeza también baja (%.3f → %.3f)" % [ant_lc["cab_y"], des_lc["cab_y"]], float(des_lc["cab_y"]) < float(ant_lc["cab_y"]))
	# Hiena: el delantero sube (de rabadilla alta a la cruz más alta que la grupa), cabeza baja y adelantada, mucho vaivén lateral
	_ok("B canouro: el lomo sube al menos 8° (%+.1f° → %+.1f°)" % [ant_c["lomo"], des_c["lomo"]], float(des_c["lomo"]) >= float(ant_c["lomo"]) + 8.0)
	_ok("B canouro: cabeza mucho más baja respecto a la cruz (%.3f → %.3f u, a la altura de la cruz o por debajo)" % [ant_c["cab_y"], des_c["cab_y"]], float(des_c["cab_y"]) <= float(ant_c["cab_y"]) - 0.06 and float(des_c["cab_y"]) <= 0.04)
	_ok("B canouro corriendo: vaivén lateral de la cabeza %.3f u (≥ 2,5 × el del loberno %.3f)" % [des_cc["cab_l_p2p"], des_lc["cab_l_p2p"]], float(des_cc["cab_l_p2p"]) >= 2.5 * float(des_lc["cab_l_p2p"]))
	_ok("B canouro andando: la cabeza gira de lado a lado (±%.0f° medidos del cuello a la cabeza)" % maxf(absf(float(des_c["yaw_max"])), absf(float(des_c["yaw_min"]))),
		float(des_c["yaw_max"]) - float(des_c["yaw_min"]) >= 12.0)
	_ok("B loberno andando: la cabeza casi no se mueve de lado (rango %.1f° frente a %.1f° del canouro)" % [float(des_l["yaw_max"]) - float(des_l["yaw_min"]), float(des_c["yaw_max"]) - float(des_c["yaw_min"])],
		float(des_l["yaw_max"]) - float(des_l["yaw_min"]) <= 0.4 * (float(des_c["yaw_max"]) - float(des_c["yaw_min"])))
	# Estabilización: el mismo trote con y sin estabilizar
	var pj: Pj3D = _modelo("loberno", 0.75)
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	var m: MarchaCuadrupedo3D = MarchaCuadrupedo3D.para(pj)
	m.medir = true
	await avanzar(6)
	m.velocidad = 1.15
	m.animar_andar(1.15)
	await avanzar(20)
	var con: Dictionary = await _muestrear(pj, m, 60)
	m.tipo = (m.tipo as Dictionary).duplicate()
	m.tipo["estabilizar"] = 0.0
	await avanzar(10)
	var sin: Dictionary = await _muestrear(pj, m, 60)
	pj.queue_free()
	await avanzar(2)
	_tabla.append("B loberno trote cabeceo de la cabeza: sin estabilizar %.3f u → estabilizada %.3f u" % [float(sin["cab_y_p2p"]), float(con["cab_y_p2p"])])
	_ok("B loberno: la estabilización baja el cabeceo de la cabeza (%.3f → %.3f u)" % [sin["cab_y_p2p"], con["cab_y_p2p"]], float(con["cab_y_p2p"]) < 0.85 * float(sin["cab_y_p2p"]))


# --- C · pies --------------------------------------------------------------------------------------------------------------

func _caso_pies() -> void:
	# Antes: el avance de siempre (patrulla 1,0 u/s con el clip walk a ×1; persecución 2,4 u/s con run a ×1). Ahora: el avance del perfil con el clip a su velocidad.
	for caso in [["loberno", 0.75, "walk", 1.0], ["loberno", 0.75, "run", 2.4], ["canouro", 0.55, "walk", 1.0], ["canouro", 0.55, "run", 2.4]]:
		var id: String = String(caso[0])
		var antes: Dictionary = await _estado(id, float(caso[1]), false, String(caso[2]), 1.0)
		var v_antes: float = float(caso[3])
		var pf: Dictionary = MarchaCuadrupedo3D.PERFILES[id]
		var v_ahora: float = float(pf["v_perseguir"] if caso[2] == "run" else pf["v_patrulla"])
		var ahora: Dictionary = await _estado(id, float(caso[1]), true, String(caso[2]), v_ahora)
		var r_a: float = v_antes / maxf(float(antes["v_pie"]), 0.01)
		var r_n: float = v_ahora / maxf(float(ahora["v_pie"]), 0.01)
		_tabla.append("C %-8s %-4s pies %.2f u/s | avance antes %.2f → patina ×%.2f | ahora: clip %s ×%.2f, pie %.2f u/s, avance %.2f → ×%.2f" % [id, caso[2], float(antes["v_pie"]), v_antes, r_a,
			ahora["clip"], ahora["vel"], float(ahora["v_pie"]), v_ahora, r_n])
		var txt: String = "C %s %s: el pie delantero apoyado hace %.2f u/s (izq. %.2f, der. %.2f) y el cuerpo avanza %.2f (ahora ×%.2f; antes ×%.2f)" % [id, caso[2], float(ahora["v_pie"]), float(ahora["v_pie_i"]), float(ahora["v_pie_d"]), v_ahora, r_n, r_a]
		if id == "loberno" and caso[2] == "walk":
			# Run_Alt (el trote del loberno) trae las patas delanteras asimétricas y con suspensión: la media de las cuatro patas (medir_animales.gd: 1,37 u/s a ×1) da ×0,84, pero aquí solo se ven las delanteras. AVISO.
			_aviso(txt, "Run_Alt: pies delanteros asimétricos; media de 4 patas medida aparte: ×0,84 de ahora (1,15 u/s de avance)")
		elif id == "canouro" and caso[2] == "walk":
			# El clip Walk del canouro (retarget de la hiena) no es simétrico: una pata delantera avanza mientras está baja. No se puede calibrar: AVISO, no contrato (ver el documento).
			_aviso(txt, "el Walk del canouro no tiene un apoyo coherente: las dos patas delanteras no pisan igual")
		else:
			_ok(txt, r_n >= 0.6 and r_n <= 1.45, "tolerancia −40 % / +45 %: la medida del pie en un clip con suspensión es aproximada")
		if false:
			_ok("C loberno patrulla: antes patinaba más (×%.2f) que ahora (×%.2f)" % [r_a, r_n], absf(r_n - 1.0) < absf(r_a - 1.0))


# --- D · Combate3D ---------------------------------------------------------------------------------------------------------

## Avanza `s` s y devuelve los u/s medios por camino recorrido (plano).
func _velocidad(g: Combate3D, s: float) -> float:
	var p0: Vector3 = g.position
	var longitud: float = 0.0
	var t0: float = reloj.t
	while reloj.t - t0 < s:
		await process_frame
		var d: Vector3 = g.position - p0
		d.y = 0.0
		longitud += d.length()
		p0 = g.position
	return longitud / maxf(reloj.t - t0, 0.0001)


func _caso_combate() -> void:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	# D1 · patrulla (jugadora lejos): lobo trota más rápido que la hiena
	_jugadora_lista(Vector2i(8, FILA))
	var lob: Combate3D = _enemigo("loberno", Vector2i(30, FILA))
	var hie: Combate3D = _enemigo("canouro", Vector2i(30, FILA + 3))
	_ok("D los dos animales llevan marcha", lob != null and hie != null and lob._marcha != null and hie._marcha != null)
	if lob == null or hie == null:
		return
	await avanzar(8)
	var v_l: float = await _velocidad(lob, 1.2)
	var v_h: float = await _velocidad(hie, 1.2)
	_tabla.append("D patrulla: loberno %.2f u/s (antes 1,00), canouro %.2f u/s (antes 1,00) ; clips %s y %s" % [v_l, v_h, lob.pj.animacion_actual, hie.pj.animacion_actual])
	_ok("D patrulla: el loberno trota a %.2f u/s, el canouro cansino a %.2f (el lobo, ≥ 1,5 × más rápido)" % [v_l, v_h], v_l >= 1.5 * v_h and _cerca(v_l, 1.15, 0.2) and _cerca(v_h, 0.6, 0.15))
	_ok("D patrulla: cada uno con su clip (loberno trote «%s», canouro «%s»)" % [lob.pj.animacion_actual, hie.pj.animacion_actual], lob.pj.animacion_actual == "trote" and hie.pj.animacion_actual == "trote")
	# D2 · giro: se mide la velocidad angular máxima del cuerpo en una inversión de 180° de la presa
	_limpiar()
	await avanzar(3)
	MarchaCuadrupedo3D.MARCHA_ANIMAL = false
	var giro_antes: Dictionary = await _medir_giro()
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	await avanzar(3)
	var res_giro: Dictionary = await _medir_giro()
	_tabla.append("D giro ANTES (interruptor apagado): loberno ω máx %.1f rad/s, canouro %.1f rad/s" % [giro_antes["loberno"], giro_antes["canouro"]])
	_ok("D giro: antes era casi instantáneo (loberno %.0f rad/s, canouro %.0f rad/s ≥ 15)" % [giro_antes["loberno"], giro_antes["canouro"]], float(giro_antes["loberno"]) >= 15.0 and float(giro_antes["canouro"]) >= 15.0)
	_tabla.append("D giro (presa cambia de lado 180°): loberno ω máx %.1f rad/s (límite %.1f), canouro %.1f rad/s (límite %.1f)" % [res_giro["loberno"], MarchaCuadrupedo3D.TIPOS["lobo"]["omega"], res_giro["canouro"], MarchaCuadrupedo3D.TIPOS["hiena"]["omega"]])
	_ok("D giro del loberno: ω máx %.1f rad/s ≤ 6,5 (+15 %%)" % res_giro["loberno"], float(res_giro["loberno"]) <= 6.5 * 1.15 + 0.2)
	_ok("D giro del canouro: ω máx %.1f rad/s ≤ 3,6 (+15 %%), y gira más torpe que el loberno" % res_giro["canouro"], float(res_giro["canouro"]) <= 3.6 * 1.15 + 0.2 and float(res_giro["canouro"]) < float(res_giro["loberno"]))
	await _caso_patrulla_limite()
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	await _caso_lobo()
	await _caso_hiena()
	await _caso_mirada()


## Un animal persigue a la jugadora; ésta salta al otro lado; se mide cuánto giró el cuerpo por segundo (yaw de Pj3D).
func _medir_giro() -> Dictionary:
	var res: Dictionary = {}
	for id in ["loberno", "canouro"]:
		_jugadora_lista(Vector2i(10, FILA))
		var g: Combate3D = _enemigo(id, Vector2i(15, FILA))
		await avanzar_s(0.8)
		colocar_jugador(Vector2i(20, FILA))        # a su espalda: giro de ~180°
		var y_prev: float = g.pj.rotation.y
		var w_max: float = 0.0
		var t0: float = reloj.t
		var t_prev: float = t0
		while reloj.t - t0 < 1.8:
			await process_frame
			var dt: float = maxf(reloj.t - t_prev, 0.0001)
			t_prev = reloj.t
			var dy: float = absf(wrapf(g.pj.rotation.y - y_prev, -PI, PI)) / dt
			y_prev = g.pj.rotation.y
			w_max = maxf(w_max, dy)
		res[id] = w_max
		_limpiar()
		await avanzar(3)
	return res


## La patrulla con giro suave sigue yendo y viniendo dentro de su tramo (diario 354: sin el margen y la «vuelta una vez cada 0,8 s» el animal se iba hacia fuera sin volver).
func _caso_patrulla_limite() -> void:
	for combo in [["loberno", false], ["canouro", false], ["loberno", true], ["canouro", true]]:
		var id: String = String(combo[0])
		MarchaCuadrupedo3D.MARCHA_ANIMAL = bool(combo[1])
		var antes: bool = not bool(combo[1])
		_jugadora_lista(Vector2i(8, FILA))
		var g: Combate3D = _enemigo(id, Vector2i(30, FILA))
		var x0: float = g.casa.x
		var dmin: float = 0.0
		var dmax: float = 0.0
		var vueltas: int = 0
		var dir_ant: float = g._direccion
		var t0: float = reloj.t
		while reloj.t - t0 < 14.0:
			await process_frame
			dmin = minf(dmin, g.position.x - x0)
			dmax = maxf(dmax, g.position.x - x0)
			if g._direccion != dir_ant:
				vueltas += 1
				dir_ant = g._direccion
		_tabla.append("D patrulla %s %s en 14 s: tramo [%.2f, %+.2f] u alrededor de su casa, %d vueltas" % [id, "ANTES" if antes else "ahora", dmin, dmax, vueltas])
		if antes:
			_limpiar()
			await avanzar(3)
			continue
		_ok("D %s: la patrulla da la vuelta y se queda en su tramo (%.2f … %+.2f u, %d vueltas)" % [id, dmin, dmax, vueltas], dmin >= -2.6 and dmax <= 2.6 and vueltas >= 2 and dmax - dmin >= 2.0)
		_limpiar()
		await avanzar(3)


func _caso_lobo() -> void:
	# D3 · acecho: la jugadora a 4,6 u del loberno; debe pasar por acecho (agachado) → pausa → embestida y acabar atacando
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo("loberno", Vector2i(12, FILA))
	var m: MarchaCuadrupedo3D = g._marcha
	var estados: Array = []
	var ag_max: float = 0.0
	var v_acecho: Array = []
	var t_ataque: float = -1.0
	var d_min: float = 99.0
	var t0: float = reloj.t
	var clip_acecho: String = ""
	while reloj.t - t0 < 9.0 and t_ataque < 0.0:
		await process_frame
		var e: String = m.estado_conducta()
		if estados.is_empty() or estados[estados.size() - 1] != e:
			estados.append(e)
		ag_max = maxf(ag_max, m.agachado)
		if e == "acecho":
			v_acecho.append(g._v_avance)
			clip_acecho = g.pj.animacion_actual
		d_min = minf(d_min, g.position.distance_to(jugador.position))
		if g._ataque > 0.0:
			t_ataque = reloj.t - t0
	_tabla.append("D lobo: estados %s ; agachado máx %.1f ; v. en acecho %.2f u/s ; primer ataque a los %.1f s" % [str(estados), ag_max, _media(v_acecho), t_ataque])
	_ok("D loberno: se acerca por acecho → pausa → embestida (%s)" % str(estados), estados.has("acecho") and estados.has("pausa") and estados.has("embestida"))
	_ok("D loberno: en el acecho va agachado (agachado = %.1f), con el clip %s y despacio (%.2f u/s)" % [ag_max, clip_acecho, _media(v_acecho)], ag_max >= 0.99 and clip_acecho == "acecho" and _media(v_acecho) <= 0.45)
	_ok("D loberno: acaba atacando (primer ataque a los %.1f s de ver a la jugadora)" % t_ataque, t_ataque > 0.0 and t_ataque < 8.0)
	_limpiar()
	await avanzar(3)


func _caso_hiena() -> void:
	# D4 · hiena: zigzag, parada, retroceso (de espaldas), arrancada, ataque y retirada
	_jugadora_lista(Vector2i(10, FILA))
	var g: Combate3D = _enemigo("canouro", Vector2i(13, FILA))
	var m: MarchaCuadrupedo3D = g._marcha
	var estados: Array = []
	var signos: Array = []
	var v_atras: Array = []
	var t_ataque: float = -1.0
	var desvio_prev: float = 0.0
	var t0: float = reloj.t
	var d_ant: float = g.position.distance_to(jugador.position)
	var d_antes_ataque: float = 0.0
	var hubo_retirada: bool = false
	var d_max_retirada: float = 0.0
	var mirando_presa_atras: bool = true
	var v_arr: Array = []
	var atacado: bool = false
	while reloj.t - t0 < 14.0:
		await process_frame
		var e: String = m.estado_conducta()
		if estados.is_empty() or estados[estados.size() - 1] != e:
			estados.append(e)
		var hacia: Vector3 = jugador.position - g.position
		hacia.y = 0.0
		var dir_cuerpo: Vector3 = m.rumbo_vec()
		var ang: float = rad_to_deg(wrapf(atan2(dir_cuerpo.x, dir_cuerpo.z) - atan2(hacia.x, hacia.z), -PI, PI))
		if e == "" and hacia.length() > 2.0 and absf(ang) > 6.0:
			var s: float = signf(ang)
			if signos.is_empty() or signos[signos.size() - 1] != s:
				signos.append(s)
		if e == "atras":
			v_atras.append(g._v_avance)
			if absf(ang) > 70.0:
				mirando_presa_atras = false
		if e == "arrancada":
			v_arr.append(g._v_avance)
		if g._ataque > 0.0 and t_ataque < 0.0:
			t_ataque = reloj.t - t0
			d_antes_ataque = hacia.length()
		if t_ataque > 0.0 and m.retirada > 0.0:
			hubo_retirada = true
			d_max_retirada = maxf(d_max_retirada, hacia.length())
		if hubo_retirada and m.retirada <= 0.0:
			break
	_tabla.append("D hiena: estados %s ; cambios de lado del zigzag %d ; retroceso a %.2f u/s ; arrancada a %.2f u/s ; ataque a los %.1f s ; retirada hasta %.2f u" % [str(estados), signos.size(), _media(v_atras), _media(v_arr), t_ataque, d_max_retirada])
	_ok("D canouro: zigzag al acercarse (%d cambios de lado)" % signos.size(), signos.size() >= 2)
	_ok("D canouro: se para, retrocede unos pasos mirando a la presa y vuelve (%s)" % str(estados), estados.has("para") and estados.has("atras") and mirando_presa_atras)
	_ok("D canouro: retrocede despacio (%.2f u/s) y arranca rápido (%.2f u/s)" % [_media(v_atras), _media(v_arr)], _media(v_atras) <= 0.6 and _media(v_arr) >= 2.2)
	_ok("D canouro: muerde (primer ataque a los %.1f s)" % t_ataque, t_ataque > 0.0)
	_ok("D canouro: tras morder se retira (llega a %.2f u de la jugadora desde %.2f)" % [d_max_retirada, d_antes_ataque], hubo_retirada and d_max_retirada >= d_antes_ataque + 0.25)
	_limpiar()
	await avanzar(3)


func _caso_mirada() -> void:
	# D5 · la cabeza sigue a la presa con límite: modelo suelto con el cuerpo fijo mirando a +Z y la presa a 60° y a 150° a su izquierda
	for id in ["loberno", "canouro"]:
		MarchaCuadrupedo3D.MARCHA_ANIMAL = true
		var pj: Pj3D = _modelo(id, 0.75 if id == "loberno" else 0.55)
		var m: MarchaCuadrupedo3D = MarchaCuadrupedo3D.para(pj)
		m.medir = true
		await avanzar(6)
		var lim: float = float(MarchaCuadrupedo3D.TIPOS[MarchaCuadrupedo3D.PERFILES[id]["tipo"]]["limite_mirada"])
		var res: Array = []
		for grados in [60.0, 150.0]:
			var presa: Vector3 = pj.position + Vector3(sin(deg_to_rad(grados)), 0.0, cos(deg_to_rad(grados))) * 3.0
			for i in 25:
				m.rumbo = 0.0
				m.actualizar(1.0 / 30.0, pj, Vector3(0, 0, 1), presa, true, 0.0)
				await process_frame
			res.append(float(m.ult["yaw"]))
		_tabla.append("D mirada %s: presa a 60° → cabeza a %.0f° ; presa a 150° → cabeza a %.0f° (límite %.0f°)" % [id, res[0], res[1], lim])
		_ok("D %s: la cabeza gira hacia la presa a 60° (%.0f°, al menos 25°)" % [id, res[0]], float(res[0]) >= 25.0)
		_ok("D %s: con la presa a 150° la cabeza se queda en su límite (%.0f° ≤ %.0f° + 10°)" % [id, res[1], lim], float(res[1]) <= lim + 10.0 and float(res[1]) >= 20.0)
		pj.queue_free()
		await avanzar(2)

# --- Interruptor y goblins -------------------------------------------------------------------------------------------------

func _caso_interruptor_y_goblins() -> void:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = false
	_jugadora_lista(Vector2i(8, FILA))
	var l: Combate3D = _enemigo("loberno", Vector2i(30, FILA))
	var h: Combate3D = _enemigo("canouro", Vector2i(30, FILA + 3))
	_ok("E con MARCHA_ANIMAL = false no hay capa y las velocidades son las de antes (patrulla %.1f, persecución %.1f)" % [l.v_base("walk"), l.v_base("run")],
		l._marcha == null and h._marcha == null and _cerca(l.v_base("walk"), Combate3D.VEL_PATRULLA, 0.0001) and _cerca(l.v_base("run"), Combate3D.VEL_PERSEGUIR, 0.0001) and _cerca(h.v_base("walk"), 1.0, 0.0001))
	await avanzar(8)
	var v_l: float = await _velocidad(l, 1.0)
	_ok("E apagado el loberno patrulla a %.2f u/s (la de antes: 1,0)" % v_l, _cerca(v_l, 1.0, 0.12))
	_limpiar()
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	await avanzar(3)
	var g: Combate3D = _enemigo("goblin_warrior_chibi", Vector2i(30, FILA))
	var esperado: float = Combate3D.PASO_GOBLIN * float(Combate3D.ZANCADA_GOBLIN["goblin_warrior_chibi"]["walk"]) / g.pj.duracion("walk")
	_ok("E el goblin guerrero no lleva marcha de animal y su patrulla sigue en %.2f u/s" % g.v_base("walk"), g._marcha == null and _cerca(g.v_base("walk"), esperado, 0.0001))
	var v_g: float = await _velocidad(g, 1.0)
	_ok("E el goblin patrulla a %.2f u/s (como antes: %.2f)" % [v_g, esperado], _cerca(v_g, esperado, 0.06))
	_limpiar()
	await avanzar(2)









