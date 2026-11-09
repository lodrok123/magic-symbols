extends SceneTree

## PRUEBA de las REGLAS de la MASA DE FUEGO del haz (prototipo 9/11/2026, laboratorios/haz_masa/haz_masa_sim.gd; docs/HAZ_FUEGO_VS_DEMO_2026-11-09.md). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_haz_masa.gd
## Contra un MURO (caja de 1 x 2,4 x 0,3 m a 2 m de la mano) y contra una ESFERA (r 0,8):
##   · ninguna bocanada entra jamas en el obstaculo (sdf >= 0 en todos los pasos), ni chispa
##   · ninguna vuelve hacia el lanzador (v·dir >= -eps) tras los primeros pasos
##   · envuelve: tras ~1 s hay bocanadas a los LADOS y por ENCIMA del canto, y alguna ya DETRAS del obstaculo
##   · el hollin crece donde se frena (cerca del obstaculo y detras) y no en el chorro (bocanadas rapidas)
##   · las chispas rebotan en el suelo; topes (<= 90 bocanadas, <= 120 chispas); sin choque no hay chispas ni masa de choque
##   · se apaga: sin alimentar deja de emitir y se vacia
## Imprime FALLOS: n al final.

var _fallos: int = 0
const DT: float = 1.0 / 60.0


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + "  " + detalle)


func _sim(modo: String) -> HazMasaSim:
	var s: HazMasaSim = HazMasaSim.new(11)
	s.configurar(Vector3(0, 0.5, 0), Vector3(0, 0, -1), 3.0)
	if modo == "muro":
		s.poner_caja(Vector3(0, 1.2, -2.15), Vector3(0.5, 1.2, 0.15), Basis.IDENTITY)
	elif modo == "esfera":
		s.poner_esfera(Vector3(0, 0.5, -2.8), 0.8)
	return s


func _correr() -> void:
	for modo in ["muro", "esfera"]:
		print("== %s" % modo)
		var s: HazMasaSim = _sim(modo)
		_ok("%s: el haz tiene su punto de choque (contacto z %.2f, normal %s)" % [modo, s.contacto.z, str(s.normal_c)], s.hay_choque and s.normal_c.dot(Vector3(0, 0, 1)) > 0.9 and absf(s.contacto.z + 2.0) < 0.1)
		var min_sdf: float = 1000.0
		var min_avance: float = 1000.0
		var max_n: int = 0
		var max_c: int = 0
		var lados: int = 0
		var encima: int = 0
		var detras: int = 0
		var lados_05: int = 0
		var encima_08: int = 0
		var hollin_cerca: float = 0.0
		var n_cerca: int = 0
		var hollin_rapido: float = 0.0
		var n_rapido: int = 0
		var chispa_min_sdf: float = 1000.0
		var pasos: int = 0
		for k in 240:
			s.paso(DT, 1.0)
			pasos += 1
			max_n = maxi(max_n, s.n)
			var vivas: int = 0
			for i in HazMasaSim.MAX_CHISPAS:
				if s.c_vida[i] > 0.0:
					vivas += 1
					chispa_min_sdf = minf(chispa_min_sdf, s.sdf(s.c_pos[i]))
			max_c = maxi(max_c, vivas)
			for i in s.n:
				min_sdf = minf(min_sdf, s.sdf(s.pos[i]))
				if k > 20:
					min_avance = minf(min_avance, s.vel[i].dot(s.dir))
				if k == 60 or k == 239:
					var p: Vector3 = s.pos[i]
					var rel: Vector3 = p - s.o_centro
					var semi_x: float = 0.5 if modo == "muro" else 0.8
					var alto: float = 2.4 if modo == "muro" else 1.3
					if absf(rel.x) > semi_x + 0.05 and p.z < s.contacto.z + 1.2 and p.z > s.contacto.z - 1.5:
						lados += 1
					if p.y > alto and absf(rel.x) < semi_x + 0.3 and absf(p.z - s.o_centro.z) < 1.0:
						encima += 1
					if p.z < s.contacto.z - (0.35 if modo == "muro" else 0.9) and absf(rel.x) < 1.6 and p.y < 3.5:
						detras += 1
				if k == 59:
					var sd: float = s.sdf(s.pos[i])
					if sd < 0.9:
						hollin_cerca += s.hollin[i]
						n_cerca += 1
					if (s.vel[i] - s.dir * s.viento).length() > 4.0:
						hollin_rapido += s.hollin[i]
						n_rapido += 1
			if k == 60:
				_ok("%s: envuelve a los 1,0 s: hay bocanadas a los lados (%d) y por encima (%d)" % [modo, lados, encima], lados > 0 and encima > 0)
		_ok("%s: ninguna bocanada entra jamas en el obstaculo (sdf minimo %.3f >= 0)" % [modo, min_sdf], min_sdf >= -0.001)
		_ok("%s: ninguna chispa entra (sdf minimo %.3f)" % [modo, chispa_min_sdf], chispa_min_sdf >= -0.001)
		_ok("%s: ninguna bocanada vuelve hacia el lanzador (v·dir minimo %.3f >= -0,02 tras 0,3 s)" % [modo, min_avance], min_avance >= -0.02)
		_ok("%s: a 1,0 y a 4,0 s hay bocanadas a los lados (%d), por encima del canto (%d) y detras del obstaculo (%d) [suma de ambos instantes]" % [modo, lados, encima, detras], lados > 0 and encima > 0 and detras > 0)
		_ok("%s: topes respetados (bocanadas %d <= %d, chispas %d <= %d)" % [modo, max_n, HazMasaSim.MAX_BOCANADAS, max_c, HazMasaSim.MAX_CHISPAS], max_n <= HazMasaSim.MAX_BOCANADAS and max_c <= HazMasaSim.MAX_CHISPAS and max_c > 20)
		_ok("%s: las chispas rebotan en el suelo (%d rebotes)" % [modo, s.c_rebotes], s.c_rebotes > 0)
		var h_c: float = hollin_cerca / maxf(float(n_cerca), 1.0)
		var h_r: float = hollin_rapido / maxf(float(n_rapido), 1.0)
		_ok("%s: el hollin crece donde se frena (cerca del obstaculo, media %.2f en %d bocanadas)" % [modo, h_c, n_cerca], n_cerca > 5 and h_c > 0.12)
		_ok("%s: el seguro de «nada vuelve» actua pocas veces (%d de %d pasos·bocanada)" % [modo, s.guardas, s.emitidas * 60], s.guardas < s.emitidas * 6)
		# calor: lo recien nacido es fuego, lo viejo humo
		var t_max: float = 0.0
		var hollin_max: float = 0.0
		for i in s.n:
			t_max = maxf(t_max, s.temp[i])
			hollin_max = maxf(hollin_max, s.hollin[i])
		_ok("%s: hay fuego (T max %.2f) y humo (hollin max %.2f) a la vez" % [modo, t_max, hollin_max], t_max > 0.7 and hollin_max > 0.35)
		# apagar: sin alimentar, deja de emitir y se vacia
		var e0: int = s.emitidas
		for k in 400:
			s.paso(DT, 0.0)
		_ok("%s: apagado: no emite y se vacia (n=%d, emitidas +%d)" % [modo, s.n, s.emitidas - e0], s.n == 0 and s.emitidas == e0)
	# sin choque
	print("== sin choque")
	var a: HazMasaSim = _sim("nada")
	var n_max: int = 0
	var chispas_vivas: int = 0
	var lejos: bool = true
	for k in 240:
		a.paso(DT, 1.0)
		n_max = maxi(n_max, a.n)
		for i in HazMasaSim.MAX_CHISPAS:
			if a.c_vida[i] > 0.0:
				chispas_vivas += 1
	var jet_h: float = 0.0
	var jet_n: int = 0
	for i in a.n:
		if a.edad[i] < 0.6:
			jet_h += a.hollin[i]
			jet_n += 1
	_ok("el chorro rapido queda limpio: sin choque, hollin medio %.3f en %d bocanadas de menos de 0,6 s (< 0,08)" % [jet_h / maxf(float(jet_n), 1.0), jet_n], jet_n > 0 and jet_h / float(jet_n) < 0.08)
	_ok("sin choque: no hay punto de choque ni chispas (%d) y la masa es solo la punta (%d bocanadas, <= 20)" % [chispas_vivas, n_max], not a.hay_choque and chispas_vivas == 0 and n_max <= 20)
	# persistencia: relanzar (configurar de nuevo) no vacia la masa
	var b: HazMasaSim = _sim("muro")
	for k in 120:
		b.paso(DT, 1.0)
	var antes: int = b.n
	b.configurar(Vector3(0, 0.5, 0), Vector3(0, 0, -1), 3.0)
	b.poner_caja(Vector3(0, 1.2, -2.15), Vector3(0.5, 1.2, 0.15), Basis.IDENTITY)
	_ok("relanzar el haz (reconfigurar) no vacia la masa (%d -> %d)" % [antes, b.n], b.n == antes and antes > 20)
	# la vista: se borra sola
	var v: HazMasaVista = HazMasaVista.new()
	root.add_child(v)
	await process_frame
	v.sim.configurar(Vector3(0, 0.5, 0), Vector3(0, 0, -1), 3.0)
	v.sim.poner_caja(Vector3(0, 1.2, -2.15), Vector3(0.5, 1.2, 0.15), Basis.IDENTITY)
	for k in 20:
		v.alimentar()
		await process_frame
	_ok("vista: dibuja bocanadas y chispas (MultiMesh con %d + %d instancias)" % [v.get_node("Bocanadas").multimesh.instance_count, v.get_node("Chispas").multimesh.instance_count], v.sim.n > 0)
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
