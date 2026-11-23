extends "res://herramientas/escenario_base.gd"
## §11 de docs/MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md (fórmula de botín aprobada por Pablo, 22/11) sobre la C1 de PLAN_COMBATE. En la ArenaCombate:
##   1. la CURVA de vida: 100 % → 0 · 90 % → 7,5 % · 80 % → 15 % · 50 % → 15 % · 40 % → 18,3 % · 20 % → 25 %;
##   2. la CURACIÓN PENDIENTE (recogibles de vida en el suelo a ≤ 8 casillas) cuenta como vida;
##   3. con la BARRA LLENA ni se imanta ni se coge; con hueco entra lo que cabe, el número enseña eso y el resto se apunta como desperdiciado;
##   4. un LIMO DIVIDIDO reparte entre sus hijos: su oro suma el del original y sus gotas suman una gota entera;
##   5. las TABLAS de botín: las de hoy son válidas; una con peso negativo, probabilidad fuera de 0..1 o suma 0 no se tira (resultado vacío).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_botin_curva.gd

const RUTA_ARENA: String = "res://escenas/PruebaArenaCombate.tscn"


func _recogibles(tipo: String) -> Array:
	var r: Array = []
	var pila: Array = [maqueta]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Combate3D.Botin3D and (n as Combate3D.Botin3D).tipo == tipo and (n as Combate3D.Botin3D)._vivo:
			r.append(n)
		for h in n.get_children():
			pila.append(h)
	return r


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_ARENA, true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	for id in ["escudo_a", "escudo_b", "coraza_arena", "limo_brasa_arena"]:
		var n: Node = z.nodo(id) if z != null else null
		if n is Combate3D:
			(n as Combate3D).retirar()
	await avanzar(5)
	var j: Jugador3D = jugador as Jugador3D
	var vmax: float = Estado.i().vida_max
	# --- 1 · la curva ---
	var casos: Array = [[1.0, 0.0], [0.9, 0.075], [0.8, 0.15], [0.5, 0.15], [0.4, 0.1833], [0.2, 0.25], [0.0, 0.25]]
	var mal: Array = []
	for c in casos:
		var p: float = Combate3D.prob_vida(float(c[0]))
		if absf(p - float(c[1])) > 0.001:
			mal.append("%.0f %% → %.3f (esperado %.3f)" % [float(c[0]) * 100.0, p, float(c[1])])
	_ok("1 la curva de vida da 0 / 7,5 / 15 / 15 / 18,3 / 25 / 25 % en 100 / 90 / 80 / 50 / 40 / 20 / 0 %", mal.is_empty(), str(mal))
	# --- 2 · la curación pendiente ---
	colocar_jugador(Vector2i(6, 10))
	j.vida = vmax * 0.8
	await avanzar(2)
	_ok("2 sin recogibles en el suelo no hay curación pendiente", is_zero_approx(Combate3D.curacion_pendiente(self, j)))
	var cerca: Combate3D.Botin3D = Combate3D.Botin3D.soltar_recogible(maqueta as Node3D, j, Combate3D.Botin3D.TIPO_VIDA, 12.0, Terreno3D.centro_de(Vector2i(9, 10), 0.0))
	var lejos: Combate3D.Botin3D = Combate3D.Botin3D.soltar_recogible(maqueta as Node3D, j, Combate3D.Botin3D.TIPO_VIDA, 12.0, Terreno3D.centro_de(Vector2i(23, 2), 0.0))
	j.vida = vmax                                          # que no se los coma mientras se mide
	await avanzar(2)
	_ok("2 cuenta el recogible de vida a ≤ 8 casillas y no el lejano", is_equal_approx(Combate3D.curacion_pendiente(self, j), 12.0), "%.1f" % Combate3D.curacion_pendiente(self, j))
	var h: float = (vmax * 0.8 + 12.0) / vmax
	_ok("2 con 80 %% de vida y 12 pendientes la probabilidad baja a la de %.0f %% (%.1f %%)" % [h * 100.0, Combate3D.prob_vida(h) * 100.0], Combate3D.prob_vida(h) < Combate3D.prob_vida(0.8))
	# --- 3 · barra llena ---
	await avanzar_s(0.6)
	var sigue: bool = is_instance_valid(cerca) and cerca._vivo and not cerca.imantada
	colocar_jugador(Terreno3D.celda_de(cerca.global_position))
	await avanzar_s(0.6)
	_ok("3 con la vida llena el recogible de vida ni se imanta ni se coge (aunque pase por encima)", sigue and is_instance_valid(cerca) and cerca._vivo, "vida %.0f/%.0f" % [j.vida, vmax])
	Combate3D.cuentas.clear()
	j.vida = vmax - 3.0
	await avanzar_s(0.8)
	var cv: Dictionary = Combate3D.cuentas.get("vida", {})
	_ok("3 con 3 de hueco se coge y cura 3 (el resto, desperdiciado)", not (is_instance_valid(cerca) and cerca._vivo) and is_equal_approx(j.vida, vmax)
		and is_equal_approx(float(cv.get("recuperado", -1.0)), 3.0) and is_equal_approx(float(cv.get("desperdiciado", -1.0)), 9.0), str(cv))
	lanzador.tinta.actual = lanzador.tinta.maxima
	colocar_jugador(Vector2i(6, 10))
	var gota: Combate3D.Botin3D = Combate3D.Botin3D.soltar_recogible(maqueta as Node3D, j, Combate3D.Botin3D.TIPO_TINTA, 6.0, Terreno3D.centro_de(Vector2i(6, 10), 0.0))
	await avanzar_s(1.0)
	_ok("3 con la tinta llena la gota se queda en el suelo", is_instance_valid(gota) and gota._vivo)
	if is_instance_valid(lejos):
		lejos.queue_free()
	# --- 4 · limo dividido ---
	Combate3D.cuentas.clear()
	Combate3D.tirada_recogible_forzada = 0.99              # sin vida, para mirar solo oro y tinta
	var cl := Vector2i(16, 6)
	var li: Limo3D = Limo3D.crear(maqueta as Node3D, Terreno3D.centro_de(cl, Terreno3D.y_pies(cl)), "", false)
	await avanzar(3)
	li.quieto = true
	var oro_original: int = li.oro
	var dividio: bool = li.dividirse("prueba")
	await avanzar(3)
	var hijos: Array = li.hijos.duplicate()
	var oro_hijos: int = 0
	var cuotas: float = 0.0
	for x in hijos:
		oro_hijos += (x as Combate3D).oro
		cuotas += (x as Combate3D).cuota_botin
	_ok("4 el limo se divide en %d y reparte: su oro suma el del original (%d) y sus cuotas suman 1" % [hijos.size(), oro_original], dividio and hijos.size() == Limo3D.N_HIJOS
		and oro_hijos == oro_original and is_equal_approx(cuotas, 1.0), "oro %d · cuotas %.2f" % [oro_hijos, cuotas])
	lanzador.tinta.actual = 10.0
	for x in hijos:
		(x as Combate3D).quieto = true
		(x as Combate3D).receive_damage(9999.0)
	await avanzar_s(0.8)
	var gen: float = float((Combate3D.cuentas.get("tinta", {}) as Dictionary).get("generado", 0.0))
	_ok("4 las gotas de los dos trozos suman UNA gota (%.0f), no una por trozo" % Combate3D.TINTA_MATAR, is_equal_approx(gen, Combate3D.TINTA_MATAR), "%.2f" % gen)
	Combate3D.tirada_recogible_forzada = -1.0
	# --- 5 · tablas ---
	var invalidas: Array = []
	var f := FileAccess.open("res://nucleo/datos/botin_tablas.tsv", FileAccess.READ)
	var ids: Dictionary = {}
	if f != null:
		f.get_line()
		while not f.eof_reached():
			var l: String = f.get_line()
			if l.strip_edges() != "" and not l.begins_with("#"):
				ids[l.split("\t")[0]] = true
	for id in ids:
		var v: Dictionary = Botin.validar(String(id))
		if not (v["errores"] as Array).is_empty():
			invalidas.append("%s: %s" % [id, str(v["errores"])])
	_ok("5 las %d tablas de botin_tablas.tsv son válidas" % ids.size(), invalidas.is_empty() and ids.size() > 5, str(invalidas))
	var neg: Dictionary = Botin.validar_filas([{"objeto": "oro", "peso": -1, "min": 1, "max": 2, "independiente": "-"}, {"objeto": "nada", "peso": 5, "min": 0, "max": 0, "independiente": "-"}])
	var ind: Dictionary = Botin.validar_filas([{"objeto": "colmillo", "peso": 1.5, "min": 1, "max": 1, "independiente": "si"}])
	var cero: Dictionary = Botin.validar_filas([{"objeto": "oro", "peso": 0, "min": 1, "max": 2, "independiente": "-"}])
	var dup: Dictionary = Botin.validar_filas([{"objeto": "oro", "peso": 1, "min": 1, "max": 2, "independiente": "-"}, {"objeto": "oro", "peso": 2, "min": 3, "max": 4, "independiente": "-"}])
	_ok("5 peso negativo, probabilidad independiente > 1 y suma 0 son errores", not (neg["errores"] as Array).is_empty() and not (ind["errores"] as Array).is_empty() and not (cero["errores"] as Array).is_empty())
	_ok("5 un objeto repetido no es error: es un aviso (las filas cuentan aparte)", (dup["errores"] as Array).is_empty() and not (dup["avisos"] as Array).is_empty())
