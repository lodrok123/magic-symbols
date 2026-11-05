extends "res://herramientas/escenario_base.gd"
## DIBUJO DE LA NUBE DE VENENO (5/11/2026; presentacion/vfx/toy/nube_veneno_vfx.gd): translúcida, con sus estados, sin tocar la lógica. Sobre la sala real del chamán:
##   1 · tiene su dibujo (bocanadas, mancha del suelo, burbujas, motas) y es TRANSLÚCIDA: ninguna bocanada pasa de ALFA_MAX y, muestreando el disco, la opacidad acumulada se queda lejos de tapar.
##   2 · estados: NACER (brota desde el centro) · VIVIR · VIENTO (se estira hacia atrás y se deshilacha) · FUEGO (se amarillea, se consume, chispas) · DISIPARSE (se apaga al acabar la vida).
##   3 · la permanente no parpadea ni se apaga; una nube que cambia de sitio con la lógica (soplar) sigue en vivas y la lógica de siempre no cambia (radio, vida, envenenar, a_dic/desde_dic).
##   4 · rendimiento: instancias acotadas y, pasadas MAX_COMPLETOS nubes, las siguientes salen LIGERAS.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_nube_veneno_vfx.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"


## Opacidad acumulada en el punto `p` (plano XZ local) por las bocanadas: 1 - Π(1 - alfa·forma), con la forma blanda del shader (borde suave desde r = tam/2).
func _opacidad_en(est: Dictionary, p: Vector2) -> float:
	var pos: PackedVector3Array = est["pos"]
	var alfas: PackedFloat32Array = est["alfas"]
	var tams: PackedFloat32Array = est["tams"]
	var libre: float = 1.0
	for i in pos.size():
		var tam: float = tams[i]
		var d: float = Vector2(pos[i].x, pos[i].z).distance_to(p) / (tam * 0.5)
		var forma: float = 1.0 - smoothstep(0.45, 1.0, d)
		libre *= 1.0 - alfas[i] * forma
	return 1.0 - libre


func _opacidad_max(est: Dictionary) -> float:
	var radio_u: float = float(est["radio_u"])
	var mx: float = 0.0
	for ix in range(-6, 7):
		for iz in range(-6, 7):
			var p := Vector2(float(ix), float(iz)) * (radio_u / 6.0)
			if p.length() <= radio_u:
				mx = maxf(mx, _opacidad_en(est, p))
	return mx


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	var j: Jugador3D = jugador as Jugador3D
	var base: Vector3 = j.position + Vector3(4.0, 0.0, 0.0)

	# ---- 1 · dibujo y translucidez -----------------------------------------------------------------------------------
	print("--- 1 · el dibujo y su translucidez")
	var n: NubeVeneno3D = NubeVeneno3D.crear(maqueta, base, 8.0, 1.0, j)
	var d: NubeVenenoVfx = n.get_node_or_null("Dibujo") as NubeVenenoVfx
	_ok("1.1 la nube tiene su dibujo (NubeVenenoVfx) con bocanadas, burbujas y motas", d != null and d.get_node_or_null("Bocanadas") != null and d.get_node_or_null("Burbujas") != null and d.get_node_or_null("Motas") != null and d.get_node_or_null("Suelo") != null)
	_ok("1.2 ya no es una esfera opaca: no hay MeshInstance3D con esfera colgando de la nube", n.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D).is_empty())
	var peor: float = 0.0
	var r_u: float = n.radio * Terreno3D.casilla
	for i in 40:
		n.avanzar(0.1)
		var e: Dictionary = d.estado()
		peor = maxf(peor, _opacidad_max(e))
		if i % 13 == 0:
			_ok("1.3 (paso %d) ninguna bocanada pasa del tope de opacidad" % i, float(e["alfa_max"]) <= NubeVenenoVfx.ALFA_MAX + 1.0e-6)
	_ok("1.4 muestreando el disco, la opacidad ACUMULADA nunca pasa de 0,55 (se ve a través)", peor <= 0.55, "(%.2f)" % peor)
	_ok("1.5 pero se LEE: en algún punto pasa de 0,15", peor >= 0.15, "(%.2f)" % peor)
	var e1: Dictionary = d.estado()
	var dentro: int = 0
	for p in (e1["pos"] as PackedVector3Array):
		if Vector2(p.x, p.z).length() <= r_u * 1.01:
			dentro += 1
	_ok("1.6 en reposo las bocanadas se quedan dentro del radio (el radio se lee)", dentro == int(e1["bocanadas"]), "(%d de %d)" % [dentro, int(e1["bocanadas"])])
	var verdes: int = 0
	for c in (e1["colores"] as Array):
		var col: Color = c
		if col.g > col.r * 1.2 and col.g > col.b * 1.6:
			verdes += 1
	_ok("1.7 todas son verdes (el verde del veneno del juego)", verdes == int(e1["bocanadas"]), "(%d)" % verdes)
	n.retirar()

	# ---- 2 · estados ---------------------------------------------------------------------------------------------------
	print("--- 2 · sus estados")
	n = NubeVeneno3D.crear(maqueta, base, 12.0, 1.0, j)
	d = n.get_node_or_null("Dibujo") as NubeVenenoVfx
	n.avanzar(0.05)
	var nace0: Dictionary = d.estado()
	var radio_nace0: float = 0.0
	for p in (nace0["pos"] as PackedVector3Array):
		radio_nace0 = maxf(radio_nace0, Vector2(p.x, p.z).length())
	for i in 20:
		n.avanzar(0.05)
	var nace1: Dictionary = d.estado()
	var radio_nace1: float = 0.0
	for p in (nace1["pos"] as PackedVector3Array):
		radio_nace1 = maxf(radio_nace1, Vector2(p.x, p.z).length())
	_ok("2.1 NACER: brota desde el centro (la nube crece de %.2f a %.2f u) y gana opacidad" % [radio_nace0, radio_nace1], radio_nace0 < radio_nace1 * 0.5 and float(nace0["nacer"]) < 0.2 and float(nace1["alfa_max"]) > float(nace0["alfa_max"]))
	for i in 20:
		n.avanzar(0.1)
	var vive: Dictionary = d.estado()
	_ok("2.2 VIVIR: nacida del todo, sin viento ni fuego", float(vive["nacer"]) > 0.99 and float(vive["viento"]) < 0.05 and float(vive["quema"]) < 0.01 and float(vive["consumo"]) < 0.01)
	var cols_v: Array = vive["colores"]
	var g_ini: float = 0.0
	for c in cols_v:
		g_ini += (c as Color).r / maxf((c as Color).g, 0.01)
	g_ini /= cols_v.size()
	var p_ini: Vector3 = n.global_position
	# viento: la lógica de siempre mueve la nube; el dibujo se estira solo
	n.soplar(Vector3(1, 0, 0))
	var vmax: float = 0.0
	var atras: float = 0.0
	for i in 8:
		n.avanzar(0.1)
		var ev: Dictionary = d.estado()
		vmax = maxf(vmax, float(ev["viento"]))
		var sx: float = 0.0
		for p in (ev["pos"] as PackedVector3Array):
			sx += p.x
		atras = minf(atras, sx / float((ev["pos"] as PackedVector3Array).size()))
	_ok("2.3 VIENTO: la nube deriva en su dirección (lógica) %.2f u" % (n.global_position.x - p_ini.x), n.global_position.x - p_ini.x > 0.8)
	_ok("2.4 ...y el dibujo se ESTIRA hacia atrás (viento %.2f, centro de las bocanadas %.2f u detrás)" % [vmax, atras], vmax > 0.5 and atras < -0.2)
	var disp: Dictionary = d.estado()
	var alfa_viento: float = float(disp["alfa_max"])
	for i in 30:
		n.avanzar(0.1)
	var tras: Dictionary = d.estado()
	_ok("2.5 pasado el soplo se recoge (el viento vuelve a ~0)", float(tras["viento"]) < 0.1 and float(tras["nacer"]) > 0.99)
	n.retirar()
	# fuego
	n = NubeVeneno3D.crear(maqueta, base, 12.0, 1.0, j)
	d = n.get_node_or_null("Dibujo") as NubeVenenoVfx
	for i in 30:
		n.avanzar(0.1)
	n.quemar(4.0)
	var chispas_max: int = 0
	var quema_max: float = 0.0
	var amarillea: bool = false
	var t_f: float = 0.0
	while t_f < 3.0 and NubeVeneno3D.vivas.has(n):
		n.avanzar(0.1)
		t_f += 0.1
		var ef: Dictionary = d.estado()
		chispas_max = maxi(chispas_max, int(ef["motas"]))
		quema_max = maxf(quema_max, float(ef["quema"]))
		if float(ef["quema"]) > 0.9:
			var gsum: float = 0.0
			for c in (ef["colores"] as Array):
				gsum += (c as Color).r / maxf((c as Color).g, 0.01)
			if gsum / float((ef["colores"] as Array).size()) > g_ini + 0.08:
				amarillea = true
	_ok("2.6 FUEGO: la nube se amarillea (rojo/verde sube) y suelta chispas (%d motas)" % chispas_max, quema_max > 0.9 and amarillea and chispas_max >= 6)
	_ok("2.7 ...y se consume: mientras arde, el consumo sube y la opacidad baja", float(d.estado()["consumo"]) > 0.4 and float(d.estado()["alfa_max"]) < NubeVenenoVfx.ALFA_BOCANADA * 0.9)
	# disiparse sin fuego
	n.retirar()
	n = NubeVeneno3D.crear(maqueta, base, 4.0, 1.0, j)
	d = n.get_node_or_null("Dibujo") as NubeVenenoVfx
	for i in 15:
		n.avanzar(0.1)
	var a_plena: float = float(d.estado()["alfa_max"])
	for i in 18:
		n.avanzar(0.1)                                   # 3,3 s: le quedan 0,7 s
	var a_fin: float = float(d.estado()["alfa_max"])
	_ok("2.8 DISIPARSE: en sus últimos segundos se apaga (%.3f → %.3f)" % [a_plena, a_fin], a_fin < a_plena * 0.6 and NubeVeneno3D.vivas.has(n))
	for i in 10:
		n.avanzar(0.1)
	_ok("2.9 ...y al acabarse la vida, la lógica la retira a su hora", not NubeVeneno3D.vivas.has(n))

	# ---- 3 · permanente y lógica -------------------------------------------------------------------------------------
	print("--- 3 · la permanente y la lógica")
	var np: NubeVeneno3D = NubeVeneno3D.crear(maqueta, base, 0.0, 1.0, j)
	var dp: NubeVenenoVfx = np.get_node_or_null("Dibujo") as NubeVenenoVfx
	for i in 20:
		np.avanzar(0.1)
	var amin: float = 1.0
	var amaxp: float = 0.0
	for i in 200:
		np.avanzar(0.1)
		var ep: Dictionary = dp.estado()
		amin = minf(amin, float(ep["alfa_max"]))
		amaxp = maxf(amaxp, float(ep["alfa_max"]))
	_ok("3.1 la PERMANENTE no se apaga ni parpadea en 20 s (alfa %.3f–%.3f) y sigue viva" % [amin, amaxp], amin > 0.08 and amaxp - amin < 0.04 and NubeVeneno3D.vivas.has(np) and np.permanente)
	_ok("3.2 la lógica no cambió: radio en casillas, collision de esfera, envenena, se registra", is_equal_approx(np.radio, 1.0) and np.dentro(base + Vector3(r_u * 0.9, 0, 0)) and not np.dentro(base + Vector3(r_u * 1.1, 0, 0)) and NubeVeneno3D.cubre(Terreno3D.celda_de(base)))
	var dic: Dictionary = np.a_dic()
	np.retirar()
	var nr: NubeVeneno3D = NubeVeneno3D.desde_dic(maqueta, dic)
	_ok("3.3 a_dic/desde_dic la recrean con su dibujo", nr != null and nr.permanente and nr.get_node_or_null("Dibujo") != null and NubeVeneno3D.vivas.has(nr))
	var hp0: float = j.vida
	j.position = base
	nr.avanzar(0.5)
	_ok("3.4 sigue envenenando a la jugadora dentro (envenenadas > 0)", nr.envenenadas > 0 and j.tiene_estado("veneno"))
	j.position = base + Vector3(20, 0, 0)
	nr.retirar()

	# ---- 4 · rendimiento ---------------------------------------------------------------------------------------------
	print("--- 4 · rendimiento")
	var todas: Array = []
	for k in 10:
		todas.append(NubeVeneno3D.crear(maqueta, base + Vector3(float(k) * 6.0, 0, 30.0), 0.0, 1.0, j))
	var completas: int = 0
	var ligeras: int = 0
	var inst: int = 0
	for nn in todas:
		var dd: NubeVenenoVfx = (nn as NubeVeneno3D).get_node("Dibujo") as NubeVenenoVfx
		(nn as NubeVeneno3D).avanzar(0.1)
		var ee: Dictionary = dd.estado()
		inst += int(ee["instancias"]) + 1
		if bool(ee["ligero"]):
			ligeras += 1
		else:
			completas += 1
	_ok("4.1 con 10 nubes, solo %d se dibujan completas y %d en versión ligera" % [completas, ligeras], completas == NubeVenenoVfx.MAX_COMPLETOS and ligeras == 4)
	var tope: int = NubeVenenoVfx.MAX_COMPLETOS * (NubeVenenoVfx.N_BOCANADAS + NubeVenenoVfx.N_BURBUJAS + NubeVenenoVfx.N_MOTAS + 1) + 4 * (NubeVenenoVfx.N_BOCANADAS_LIGERO + 1)
	_ok("4.2 las instancias totales (%d) no pasan del tope (%d)" % [inst, tope], inst <= tope)
	for nn in todas:
		(nn as NubeVeneno3D).retirar()
	await avanzar(2)
	_ok("4.3 al retirarlas todas se libera el cupo (completos = 0)", NubeVenenoVfx.completos == 0, "(%d)" % NubeVenenoVfx.completos)
