extends "res://herramientas/escenario_base.gd"
## VFX de NATURALEZA del chamán goblin (5/11/2026; presentacion/vfx/toy/naturaleza_*.gd): la bola de veneno (BolaVeneno3D) y el escudo de naturaleza (EscudoNaturaleza3D) con su aspecto nuevo.
## Sobre la sala real del chamán (PruebaSalaChaman), con el chamán quieto y los guerreros goblin como cuerpos de prueba:
##   1 · las hojas por CPU: caen despacio y se quedan en el suelo, se apagan de verde a verde pardo, las atadas siguen a su punto hasta que se sueltan.
##   2 · la bola: deja ESTELA (manchas que siguen el arco) y suelta HOJAS que caen, el estallido saca más hojas y oculta el cuerpo, y NO cambia su lógica (aviso, daño, tiempos, se libera).
##   3 · el escudo pasa por sus estados con su vfx: ACTIVO (hierba verde crecida, hojas que giran, cúpula) · GOLPE (la hierba se encoge, se pierde una hoja por trozo de escudo) · ROTO (hojas que caen, hierba que se
##       marchita a pardo y se echa) · QUEMADO (naranja → negro, brasas) y se libera cuando acaba.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_naturaleza_chaman.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"
var _ch: Chaman3D = null


func _guerreros() -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D) and not (n as Combate3D).muerto:
			res.append(n)
	return res


## Cuánto se parece `c` a un verde (el verde manda sobre rojo y azul).
func _es_verde(c: Color) -> bool:
	return c.g > c.r * 1.25 and c.g > c.b * 1.4


func _es_naranja(c: Color) -> bool:
	return c.r > c.g * 1.3 and c.r > c.b * 2.0 and c.r > 0.5


func _es_oscuro(c: Color) -> bool:
	return maxf(c.r, maxf(c.g, c.b)) < 0.3


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ch = z.nodo("chaman_a") as Chaman3D
	_ok("0 hay chamán", _ch != null)
	if _ch == null:
		return
	_ch.quieto = true
	var gs: Array = _guerreros()
	_ok("0 hay guerreros con combate", gs.size() >= 2, "(%d)" % gs.size())
	for g in gs:
		(g as Combate3D).quieto = true
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0

	# ---- 1 · hojas ---------------------------------------------------------------------------------------------------
	print("--- 1 · las hojas por CPU")
	var hs := NaturalezaHojas.new()
	root.add_child(hs)
	hs.montar(12)
	hs.suelo_y = 0.0
	_ok("1.1 el nodo de hojas vive en el mundo (top_level) y en el origen, aunque se cuelgue de algo lejos", hs.top_level and hs.global_position.is_zero_approx() and hs.capacidad() == 12)
	var h0: int = hs.emitir(Vector3(3, 2.0, 3), Vector3(0.5, 0, 0), 9.0, 0.12, Color(0.3, 0.7, 0.3), NaturalezaHojas.FINAL_VERDE)
	var y0: float = 2.0
	hs.avanzar(0.5)
	var e: Array = hs.estados()
	_ok("1.2 una hoja cae (y baja) y no pasa de la velocidad límite", e.size() == 1 and (e[0]["pos"] as Vector3).y < y0 and (e[0]["vel"] as Vector3).y >= -hs.v_limite - 0.001,
		"(y=%.2f, vy=%.2f)" % [(e[0]["pos"] as Vector3).y, (e[0]["vel"] as Vector3).y])
	for i in 80:
		hs.avanzar(0.05)                              # 4 s más: 2 m a ≤ 1,15 m/s ya han llegado
	e = hs.estados()
	_ok("1.3 al llegar al suelo se queda quieta, no lo atraviesa", e.size() == 1 and bool(e[0]["quieta"]) and (e[0]["pos"] as Vector3).y >= -0.001, "(%s)" % str(e))
	for i in 120:
		hs.avanzar(0.05)
	_ok("1.4 al acabar su vida se apaga y desaparece", hs.vivas() == 0)
	var c_ini: Color = Color(0.3, 0.7, 0.3)
	var h1: int = hs.emitir(Vector3(0, 5, 0), Vector3.ZERO, 2.0, 0.12, c_ini, NaturalezaHojas.NARANJA_FUEGO)
	hs.avanzar(1.7)
	e = hs.estados()
	_ok("1.5 la hoja se va de su color al final (verde → naranja de lo que tenga de `col_fin`)", e.size() == 1 and (e[0]["col_fin"] as Color).is_equal_approx(NaturalezaHojas.NARANJA_FUEGO))
	hs.vaciar()
	var pt: Array = [Vector3(1, 1, 1)]               # (una lambda captura por valor: se mueve el contenido de un Array)
	var h2: int = hs.emitir_atada(func() -> Vector3: return pt[0], 0.12, Color(0.3, 0.7, 0.3))
	pt[0] = Vector3(2, 1.5, 0)
	hs.avanzar(0.1)
	e = hs.estados()
	_ok("1.6 una hoja atada sigue a su punto y no cae", e.size() == 1 and bool(e[0]["atada"]) and (e[0]["pos"] as Vector3).is_equal_approx(Vector3(2, 1.5, 0)))
	hs.soltar(h2, Vector3.ZERO)
	hs.avanzar(0.4)
	e = hs.estados()
	_ok("1.7 al soltarla cae", e.size() == 1 and not bool(e[0]["atada"]) and (e[0]["pos"] as Vector3).y < 1.5)
	hs.queue_free()
	var mn := NaturalezaManchas.new()
	root.add_child(mn)
	mn.montar(6)
	mn.emitir(Vector3(1, 1, 1), Vector3(0, 1, 0), 0.5, 0.2, 0.02, Color.WHITE, Color.GREEN)
	mn.avanzar(0.2)
	e = mn.estados()
	_ok("1.8 una mancha sube con su velocidad, y se acaba a su tiempo", e.size() == 1 and (e[0]["pos"] as Vector3).y > 1.1 and mn.top_level and mn.global_position.is_zero_approx())
	mn.avanzar(0.4)
	_ok("1.9 ...y a su tiempo desaparece", mn.vivas() == 0)
	mn.queue_free()

	# ---- 2 · la bola ---------------------------------------------------------------------------------------------------
	print("--- 2 · la bola de veneno")
	var ori: Vector3 = _ch.position + Vector3(0, 1.0, 0)
	var dest: Vector3 = j.position + Vector3(3.0, 0.0, 1.5)
	var b: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, ori, dest, _ch, j, lanzador)
	_ok("2.1 la bola monta su vfx de naturaleza con el cuerpo (núcleo, cuerpo, halo)", b.vfx != null and b.vfx.cuerpo != null and b.vfx.cuerpo.visible and b.vfx.cuerpo.get_child_count() >= 3)
	_ok("2.2 sigue avisando dónde cae (aviso circular con el mismo radio)", b.aviso != null and is_equal_approx(b.aviso.radio, BolaVeneno3D.RADIO))
	_ok("2.3 las constantes de su lógica no han cambiado", is_equal_approx(BolaVeneno3D.DANO, 6.0) and is_equal_approx(BolaVeneno3D.RADIO, 0.9) and is_equal_approx(BolaVeneno3D.VEL, 5.0) and is_equal_approx(BolaVeneno3D.VENENO_S, 3.0))
	var t_vuelo: float = b.t_vuelo
	while not b.llego and b.t < t_vuelo * 0.6:
		await avanzar(1)
	var estela: Array = b.vfx.manchas.estados()
	_ok("2.4 en vuelo deja ESTELA: muchas manchas", estela.size() >= 8, "(%d)" % estela.size())
	# cada mancha está sobre el arco (a menos de 0,2 u de algún punto del arco) y las más viejas, más atrás
	var sobre_arco: int = 0
	var mas_vieja_atras: bool = true
	var cab: Vector3 = b.global_position
	for m in estela:
		var pm: Vector3 = m["pos"]
		var dmin: float = 1.0e9
		for q in 101:
			dmin = minf(dmin, pm.distance_to(b.punto_en(float(q) / 100.0)))
		if dmin <= 0.2:
			sobre_arco += 1
	_ok("2.5 la estela SIGUE EL ARCO (≥ 90 % de las manchas sobre la curva)", float(sobre_arco) >= 0.9 * float(estela.size()), "(%d de %d)" % [sobre_arco, estela.size()])
	var d_prom_vieja: float = 0.0
	var d_prom_nueva: float = 0.0
	var n_v: int = 0
	var n_n: int = 0
	for m in estela:
		if float(m["edad"]) > float(m["vida"]) * 0.5:
			d_prom_vieja += (m["pos"] as Vector3).distance_to(cab)
			n_v += 1
		else:
			d_prom_nueva += (m["pos"] as Vector3).distance_to(cab)
			n_n += 1
	_ok("2.6 las manchas viejas quedan más atrás que las nuevas", n_v > 0 and n_n > 0 and d_prom_vieja / float(n_v) > d_prom_nueva / float(n_n), "(%.2f vs %.2f)" % [d_prom_vieja / maxf(n_v, 1), d_prom_nueva / maxf(n_n, 1)])
	var sueltas: Array = []
	for h in b.vfx.hojas.estados():
		if not bool(h["atada"]):
			sueltas.append(h)
	_ok("2.7 suelta HOJAS que quedan atrás y CAEN (no atadas, cerca de la bola, bajando)", sueltas.size() >= 4, "(%d)" % sueltas.size())
	var cerca: bool = true
	var bajando: int = 0
	for h in sueltas:
		var dmin_h: float = 1.0e9
		for q in 101:
			dmin_h = minf(dmin_h, (h["pos"] as Vector3).distance_to(b.punto_en(float(q) / 100.0)))
		if dmin_h > 1.6:
			cerca = false
		if (h["vel"] as Vector3).y < 0.0:
			bajando += 1
	_ok("2.8 las hojas están donde pasó la bola (a ≤ 1,6 u del arco: coordenadas de mundo bien) y la mayoría baja", cerca and bajando >= sueltas.size() / 2, "(bajando %d de %d)" % [bajando, sueltas.size()])
	_ok("2.9 tres hojitas giran alrededor de la cabeza", b.vfx.hojas.estados().size() - sueltas.size() == NaturalezaProyectilToy.N_HOJAS_ORBITA)
	while not b.llego:
		await avanzar(1)
	_ok("2.10 al caer estalla (una vez), el cuerpo se oculta y las hojas siguen", b.vfx.estallos() == 1 and not b.vfx.cuerpo.visible and b.vfx.hojas.vivas() >= 15, "(hojas %d)" % b.vfx.hojas.vivas())
	_ok("2.11 el impacto de la lógica sigue: no acierta a quien no estaba allí", not b.acerto)
	await avanzar_s(0.3)
	_ok("2.12 el estallido no deja hojas atadas (todas caen)", b.vfx.hojas.estados().filter(func(h): return bool(h["atada"])).is_empty())
	_ok("2.13 la bola espera a que acaben las hojas antes de liberarse (sigue viva a los 0,9 s)", is_instance_valid(b))
	await avanzar_s(3.0)
	_ok("2.14 y luego se libera", not is_instance_valid(b))
	# la burbuja del lanzador la para: se dispersa sin charco
	var b2: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, ori, dest, _ch, j, lanzador)
	await avanzar(5)
	b2.parada = true
	b2._terminar(false)
	_ok("2.15 si la para una burbuja, se dispersa (una vez) sin estallido de charco", b2.vfx.estallos() == 1 and not b2.vfx.cuerpo.visible and b2.vfx.hojas.vivas() >= 5)
	await avanzar_s(3.0)
	_ok("2.16 ...y se libera", not is_instance_valid(b2))
	# acertar sigue haciendo daño y veneno
	var vida_j: float = j.vida
	var b3: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, j.position + Vector3(0, 1, 3), j.position, _ch, j, lanzador)
	while not b3.llego:
		await avanzar(1)
	_ok("2.17 una bola que cae sobre la jugadora la hiere y la envenena, como antes", b3.acerto and j.vida <= vida_j - BolaVeneno3D.DANO + 0.01 and j.tiene_estado("veneno"))   # 6/11: v2 envenena con una pila (antes `_veneno_t`)
	await avanzar_s(3.0)

	# ---- 3 · el escudo ---------------------------------------------------------------------------------------------------
	print("--- 3 · el escudo de naturaleza")
	for g in _guerreros():
		var cc: Combate3D = g
		if cc.escudo_natural != null and is_instance_valid(cc.escudo_natural):
			cc.escudo_natural.queue_free()
		cc.escudo_natural = null
	var g0: Combate3D = _guerreros()[0]
	var e1: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	var br: NaturalezaBarreraToy = e1.barrera
	_ok("3.1 el escudo monta su barrera (hierba, hojas, cúpula, aro) y sigue siendo `activo`", br != null and br.get_node_or_null("Hierba") != null and br.get_node_or_null("Cupula") != null and br.get_node_or_null("Aro") != null and e1.estado == "activo")
	_ok("3.2 su API no ha cambiado: VIDA 25, activo(), señal roto", is_equal_approx(EscudoNaturaleza3D.VIDA, 25.0) and e1.activo() and e1.has_signal("roto"))
	await avanzar_s(1.3)
	var h_ref: float = float(br.estados_hierba()["alto_medio"])
	var c_ref: Color = br.estados_hierba()["color_medio"]
	_ok("3.3 ACTIVO: la hierba ha brotado (altura media > 0,15 del cuerpo) y es VERDE", h_ref > 0.15 * br.alto and _es_verde(c_ref), "(h %.2f de %.2f, color %s)" % [h_ref, br.alto, str(c_ref)])
	_ok("3.4 ...con todas sus hojas girando alrededor", br.n_orbitando() == NaturalezaBarreraToy.N_ORBITA and br.hojas.estados().filter(func(h): return bool(h["atada"])).size() == NaturalezaBarreraToy.N_ORBITA)
	_ok("3.5 ...y una cúpula tenue (se ve el canto, no tapa al goblin)", br.color_cupula_alfa() > 0.2 and br.color_cupula_alfa() < 0.45)
	var orb: Array = br.hojas.estados()
	var radios_ok: bool = true
	for h in orb:
		var dxz := Vector2((h["pos"] as Vector3).x - g0.global_position.x, (h["pos"] as Vector3).z - g0.global_position.z).length()
		if dxz > br.radio * 1.4:
			radios_ok = false
	_ok("3.6 las hojas que giran están alrededor del goblin (a ≤ 1,4 radios)", radios_ok)
	# golpe que no rompe: 7 de 25
	g0.escudo_natural.absorber(7.0, "")
	await avanzar(2)
	var h_golpe: float = float(br.estados_hierba()["alto_medio"])
	_ok("3.7 GOLPE: el escudo se resiente (la hierba se encoge un momento)", br.golpes_recibidos() == 1 and h_golpe < h_ref * 0.9, "(%.2f → %.2f)" % [h_ref, h_golpe])
	_ok("3.8 ...y suelta hojas: pierde las que le tocan por vida (7 de 25 → 2 menos)", br.n_orbitando() == 8, "(%d)" % br.n_orbitando())
	await avanzar_s(0.7)
	var h_despues: float = float(br.estados_hierba()["alto_medio"])
	_ok("3.9 ...y se recupera (la hierba vuelve a su altura)", h_despues > h_ref * 0.9, "(%.2f)" % h_despues)
	_ok("3.10 el escudo sigue activo con la vida que le queda", e1.estado == "activo" and is_equal_approx(e1.vida, 18.0))
	# roto por golpes
	var sobrante: float = e1.absorber(100.0, "")
	_ok("3.11 ROTO: lo que sobra pasa (como antes) y pasa a `roto`", is_equal_approx(sobrante, 82.0) and e1.estado == "roto" and br.estado == "roto" and g0.escudo_natural == null, "(sobra %.1f)" % sobrante)
	await avanzar_s(0.2)
	var sueltas_roto: Array = br.hojas.estados().filter(func(h): return not bool(h["atada"]))
	_ok("3.12 ...se deshoja: todas las hojas caen y no queda ninguna girando", sueltas_roto.size() >= 15 and br.hojas.estados().filter(func(h): return bool(h["atada"])).is_empty() and br.n_orbitando() == 0, "(caen %d)" % sueltas_roto.size())
	await avanzar_s(0.7)
	var c_roto: Color = br.estados_hierba()["color_medio"]
	var h_roto: float = float(br.estados_hierba()["alto_medio"])
	_ok("3.13 ...la hierba se marchita (pierde altura) y pasa de verde a pardo", h_roto < h_ref * 0.7 and c_roto.g < c_ref.g * 0.95 and c_roto.r > c_ref.r, "(h %.2f, color %s)" % [h_roto, str(c_roto)])
	await avanzar_s(3.2)
	_ok("3.14 y cuando acaba de deshojarse el nodo se libera", not is_instance_valid(e1))
	# quemado por fuego
	var e2: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	var br2: NaturalezaBarreraToy = e2.barrera
	await avanzar_s(1.3)
	var c_v2: Color = br2.estados_hierba()["color_medio"]
	var pasa: float = e2.absorber(5.0, "fuego")
	_ok("3.15 QUEMADO: el fuego lo quema de un golpe y ese daño no pasa (como antes)", is_equal_approx(pasa, 0.0) and e2.estado == "quemado" and br2.estado == "quemado")
	await avanzar_s(0.3)
	var c_q1: Color = br2.estados_hierba()["color_medio"]
	var hojas_q: Array = br2.hojas.estados().filter(func(h): return not bool(h["atada"]))
	var naranjas: int = hojas_q.filter(func(h): return _es_naranja(h["col"] as Color)).size()
	_ok("3.16 ...la hierba se pone NARANJA y las hojas que caen son naranjas", _es_naranja(c_q1) and naranjas >= 10 and _es_verde(c_v2), "(hierba %s, hojas naranjas %d de %d)" % [str(c_q1), naranjas, hojas_q.size()])
	_ok("3.17 ...y suben brasas", br2.brasas.vivas() >= 3, "(%d)" % br2.brasas.vivas())
	var fin_negro: bool = hojas_q.all(func(h): return (h["col_fin"] as Color).is_equal_approx(NaturalezaHojas.NEGRO_CENIZA))
	_ok("3.18 ...las hojas acaban NEGRAS (ceniza)", fin_negro)
	await avanzar_s(0.9)
	var c_q2: Color = br2.estados_hierba()["color_medio"]
	_ok("3.19 ...y la hierba acaba negra y encogida", _es_oscuro(c_q2) and float(br2.estados_hierba()["alto_medio"]) < h_ref * 0.55, "(color %s, h %.2f)" % [str(c_q2), float(br2.estados_hierba()["alto_medio"])])
	await avanzar_s(3.0)
	_ok("3.20 ...y se libera cuando acaba", not is_instance_valid(e2))
	# rellenar un escudo activo no monta otro
	var e3: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	var e3b: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g0)
	_ok("3.21 poner sobre un escudo activo lo rellena (sigue habiendo una sola barrera)", e3 == e3b and g0.find_children("Barrera", "", true, false).size() == 1)
	# presupuesto
	var inst: int = e3.barrera.hojas.capacidad() + int(NaturalezaBarreraToy.N_TUFOS * NaturalezaBarreraToy.BRIZNAS_POR_TUFO)
	_ok("3.22 presupuesto: una barrera cuesta < 200 instancias de MultiMesh y ninguna GPUParticles3D", inst < 200 and e3.find_children("*", "GPUParticles3D", true, false).is_empty(), "(%d)" % (e3.barrera.hojas.capacidad() + NaturalezaBarreraToy.N_TUFOS * NaturalezaBarreraToy.BRIZNAS_POR_TUFO + e3.barrera.brasas.capacidad()))
	e3.queue_free()
	g0.escudo_natural = null
