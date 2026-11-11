extends "res://herramientas/escenario_base.gd"
## CAMPO DE VIENTO COMPARTIDO y NUBE DE VENENO COMO GAS PESADO (11/11/2026; presentacion/vfx/toy/campo_viento.gd, viento_toy.gd, viento_corrientes.gd, nube_veneno_vfx.gd).
##   1 · la turbulencia NO tiene divergencia (libre y ceñida a un sólido, con la rampa de Bridson).
##   2 · el flujo no entra en los sólidos (en la piel no hay componente hacia dentro; las partículas arrastradas no acaban dentro y lo rodean) y nada vuelve contra el viento.
##   3 · los interruptores: las tres partes, CampoViento.en_viento_toy (VientoToy: cintas, hojas) y los de la nube (gas_pesado, humo_al_arder).
##   4 · la nube de veneno muestrea el campo: a ras de suelo, dentro de su radio, verde, rodea un bloque, se deshilacha con el viento y al arder suelta humo PARDO.
##   5 · coste (se mide y se enseña).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_campo_viento.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaChaman.tscn"


func _div(c: CampoViento, p: Vector3, h: float = 0.004) -> float:
	var dx: float = (c.velocidad(p + Vector3(h, 0, 0)).x - c.velocidad(p - Vector3(h, 0, 0)).x) / (2.0 * h)
	var dy: float = (c.velocidad(p + Vector3(0, h, 0)).y - c.velocidad(p - Vector3(0, h, 0)).y) / (2.0 * h)
	var dz: float = (c.velocidad(p + Vector3(0, 0, h)).z - c.velocidad(p - Vector3(0, 0, h)).z) / (2.0 * h)
	return dx + dy + dz


## La escala de las derivadas (para comparar la divergencia): |∂vx/∂x| + |∂vx/∂y| medio.
func _grad(c: CampoViento, p: Vector3, h: float = 0.004) -> float:
	return absf((c.velocidad(p + Vector3(h, 0, 0)).x - c.velocidad(p - Vector3(h, 0, 0)).x) / (2.0 * h)) + absf((c.velocidad(p + Vector3(0, h, 0)).x - c.velocidad(p - Vector3(0, h, 0)).x) / (2.0 * h))


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	var gas0: bool = NubeVenenoVfx.gas_pesado
	var humo0: bool = NubeVenenoVfx.humo_al_arder
	var campo0: bool = CampoViento.en_viento_toy
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# ---- 1 · sin divergencia ------------------------------------------------------------------------------------------
	print("--- 1 · turbulencia sin divergencia")
	var c := CampoViento.new(5)
	c.parte_viento = false
	c.t = 1.3
	var peor: float = 0.0
	var escala_g: float = 0.0
	var vmedia: float = 0.0
	for i in 200:
		var p := Vector3(rng.randf_range(-3, 3), rng.randf_range(0, 2), rng.randf_range(-3, 3))
		peor = maxf(peor, absf(_div(c, p)))
		escala_g += _grad(c, p)
		vmedia += c.velocidad(p).length()
	escala_g /= 200.0
	vmedia /= 200.0
	_ok("1.1 libre: |div| máxima %.5f, frente a derivadas de %.3f (< 1 %%)" % [peor, escala_g], peor < escala_g * 0.01 and escala_g > 0.1)
	_ok("1.2 y no es nula: rapidez media %.2f m/s (turbulencia %.2f)" % [vmedia, c.turbulencia], vmedia > c.turbulencia * 0.4 and vmedia < c.turbulencia * 3.0)
	c.poner_caja(Vector3(0, 0.5, 0), Vector3(0.6, 0.5, 0.6))
	c.piel = 0.0                                      # solo la rampa de Bridson (la piel de la parte 3 proyecta, y eso no es de divergencia nula)
	var peor_s: float = 0.0
	var cerca_n: int = 0
	for i in 120:
		var p := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.8), 0.6 + rng.randf_range(0.03, 0.55))     # delante de la cara +z, lejos de aristas
		peor_s = maxf(peor_s, absf(_div(c, p)))
		if c.sdf(p) < c.alcance:
			cerca_n += 1
	_ok("1.3 ceñida a un sólido (rampa de Bridson): |div| máxima %.4f (< 3 %% de %.3f) en %d puntos de la piel" % [peor_s, escala_g, cerca_n], peor_s < escala_g * 0.03 and cerca_n > 60)
	var tang: float = 0.0
	for i in 60:
		var p := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.8), 0.6 + 0.002)
		tang = maxf(tang, absf(c.velocidad(p).dot(Vector3.BACK)))
	_ok("1.4 ...y pegada a la cara solo corre tangente (|v·n| máx %.3f)" % tang, tang < 0.05)

	# ---- 2 · no entra en los sólidos -----------------------------------------------------------------------------------
	print("--- 2 · el flujo rodea los sólidos")
	var s := CampoViento.new(8)
	s.dir = Vector3(0, 0, -1)
	s.fuerza = 3.0
	s.turbulencia = 0.8
	s.poner_caja(Vector3(0, 0.6, -2.0), Vector3(0.7, 0.6, 0.3), Basis(Vector3.UP, 0.4))
	s.poner_capsula(Vector3(1.6, 0.35, -1.2), Vector3(1.6, 0.95, -1.2), 0.35)
	s.poner_barrera(Vector3(-1.8, 0, -1.5), Vector3(0, 0, 1), 1.0, 1.2)
	var entra: float = 0.0
	for i in 600:
		var p := Vector3(rng.randf_range(-2.6, 2.6), rng.randf_range(0.0, 1.6), rng.randf_range(-3.0, -0.6))
		var d: float = s.sdf(p)
		if d > 0.0 or d < -0.1:
			# llevarlo a la piel (de -0,1 a 0 m) por la normal
			p -= s.normal(p) * (d + rng.randf_range(0.0, 0.1))
		if s.sdf(p) <= 0.0 and s.sdf(p) > -0.12:
			entra = minf(entra, s.velocidad(p).dot(s.normal(p)))
	_ok("2.1 en la piel de caja, cápsula y barrera no hay componente hacia dentro (v·n mín %.5f)" % entra, entra > -1.0e-4)
	var dentro: int = 0
	var rodean: int = 0
	var pasan: int = 0
	var vuelven: int = 0
	for i in 160:
		var p := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.0), 0.0)
		var v := Vector3.ZERO
		var x0: float = p.x
		for k in 90:
			s.avanzar(1.0 / 30.0)
			v = s.arrastrar(p, v, 1.0 / 30.0)
			p = s.contener(p + v * (1.0 / 30.0), 0.02)
			if s.sdf(p) < -0.01:
				dentro += 1
				break
			if s.sdf(p) > s.piel and v.dot(s.dir) < -0.01:
				vuelven += 1
		if p.z < -2.6:
			pasan += 1
			if absf(p.x - x0) > 0.25 or p.y > 1.25:
				rodean += 1
	_ok("2.2 160 partículas arrastradas 3 s contra el bloque: ninguna acaba dentro (%d)" % dentro, dentro == 0)
	_ok("2.3 ...lo rodean y siguen: %d de %d pasan al otro lado desviadas" % [rodean, pasan], pasan > 100 and rodean > pasan / 3)
	_ok("2.4 nada vuelve contra el viento fuera de la piel (%d pasos hacia atrás)" % vuelven, vuelven == 0)

	# ---- 3 · interruptores ---------------------------------------------------------------------------------------------
	print("--- 3 · interruptores")
	var q := Vector3(0.3, 0.5, -0.4)
	s.parte_turbulencia = false
	_ok("3.1 sin turbulencia, lejos de sólidos el campo es el viento dirigido exacto", s.velocidad(Vector3(0, 0.5, 4.0)).is_equal_approx(s.viento_base(Vector3(0, 0.5, 4.0))))
	s.parte_turbulencia = true
	s.parte_viento = false
	var media := Vector3.ZERO
	for i in 100:
		media += s.velocidad(Vector3(rng.randf_range(-3, 3), rng.randf_range(0, 2), rng.randf_range(3, 8)))
	_ok("3.2 sin viento dirigido no hay deriva media (%.2f m/s)" % (media / 100.0).length(), (media / 100.0).length() < 0.35)
	s.parte_viento = true
	s.parte_solidos = false
	var pin := Vector3(0, 0.6, -2.0)
	_ok("3.3 sin sólidos, contener no mueve nada y el aire atraviesa el bloque", s.contener(pin).is_equal_approx(pin) and s.velocidad(pin).dot(s.dir) > 1.0)
	s.parte_solidos = true
	_ok("3.4 con sólidos, contener lo saca del bloque", s.sdf(s.contener(pin, 0.05)) >= 0.04)

	Flags.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	var j: Jugador3D = jugador as Jugador3D
	var base: Vector3 = j.position + Vector3(4.0, 0.0, 0.0)

	# VientoToy HAZ con una cápsula en el camino
	var capsula: StaticBody3D = _capsula(maqueta, base + Vector3(0.05, 0, -1.4), 0.32, 1.2)
	CampoViento.en_viento_toy = false
	var vt: VientoToy = VientoToy.new()
	maqueta.add_child(vt)
	vt.global_position = base
	vt.definir(VientoToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	vt.lanzar(-1.0)
	await avanzar(20)
	var cor: Node = vt.get_node_or_null("Cuerpo/CorrientesViento")
	var sond := CampoViento.new()
	sond.poner_capsula(base + Vector3(0.05, 0.32, -1.4), base + Vector3(0.05, 0.88, -1.4), 0.32)
	var dentro_off: int = _puntos_dentro(cor, sond)
	_ok("3.5 apagado (de serie), el VientoToy no tiene campo y sus cintas atraviesan la cápsula (%d puntos dentro)" % dentro_off, vt.campo() == null and cor != null and cor.get("campo") == null and dentro_off > 0)
	CampoViento.en_viento_toy = true
	await avanzar(20)
	var dentro_on: int = _puntos_dentro(cor, sond)
	_ok("3.6 encendido, el VientoToy tiene campo, las cintas lo muestrean (%d puntos) y ninguno queda en la cápsula (%d)" % [int(cor.get("puntos_desviados")), dentro_on],
		vt.campo() != null and cor.get("campo") == vt.campo() and int(cor.get("puntos_desviados")) > 100 and dentro_on == 0)
	_ok("3.7 ...el campo recogió la cápsula (grupo solido_viento) entre sus sólidos (%d)" % vt.campo().solidos(), vt.campo().solidos() >= 1 and vt.campo().muestras > 0)
	var hojas: Node = vt.get_node_or_null("Cuerpo/Hojas")
	var hoja_ok: bool = hojas != null
	if hoja_ok:
		for e in (hojas.get("_s") as Array):
			if bool((e as Dictionary).get("vivo", false)):
				var pw: Vector3 = (hojas as Node3D).global_transform * ((e as Dictionary)["pos"] as Vector3)
				if sond.sdf(pw) < -0.02:
					hoja_ok = false
	_ok("3.8 las hojas del haz tampoco se meten en la cápsula", hoja_ok)
	# 11/11 («no veo diferencia en viento»): las cintas no se aplastan contra la cara, la rodean con holgura (viento_corrientes.gd, _rodeo)
	var hol: Array = _holgura(cor, sond)
	_ok("3.9 las cintas RODEAN la cápsula con holgura: %d puntos a menos de 0,6 m de su piel, a %.3f m de media (> 0,15) y solo %d pegados a menos de 0,12 m (≤ 10 %%; antes se aplastaban a 0,08 m)" % [hol[0], hol[1], hol[2]],
		int(hol[0]) > 20 and float(hol[1]) > 0.15 and int(hol[2]) <= int(hol[0]) / 10)

	# coste: el paso del toy con y sin campo (mismo dibujo de cintas)
	print("--- 5 · coste")
	var t_on: float = 1.0e9
	var t_off: float = 1.0e9
	for rep in 6:                                    # alternando y con el mínimo: la máquina puede estar ocupada
		CampoViento.en_viento_toy = true
		vt._process(1.0 / 30.0)
		t_on = minf(t_on, _medir(vt, 15))
		CampoViento.en_viento_toy = false
		vt._process(1.0 / 30.0)
		t_off = minf(t_off, _medir(vt, 15))
	CampoViento.en_viento_toy = true
	var muestras0: int = vt.campo().muestras if vt.campo() != null else 0
	vt._process(1.0 / 30.0)
	var por_paso: int = (vt.campo().muestras - muestras0) if vt.campo() != null else 0
	var t0: int = Time.get_ticks_usec()
	for i in 2000:
		s.velocidad(Vector3(rng.randf_range(-2, 2), rng.randf_range(0, 1.5), rng.randf_range(-3, 0)))
	var us_muestra: float = float(Time.get_ticks_usec() - t0) / 2000.0
	_aviso("5.1 coste del campo en el HAZ: %.3f ms/paso con campo, %.3f sin él (+%.3f ms; %d muestras por paso; %.1f µs por muestra con 3 sólidos)" % [t_on, t_off, t_on - t_off, por_paso, us_muestra])
	_ok("5.2 el campo cuesta poco en el HAZ (< 3 ms extra por paso con una cápsula dentro del haz, headless y en depuración)", t_on - t_off < 3.0, "(%.3f ms)" % (t_on - t_off))
	vt.queue_free()
	capsula.queue_free()
	CampoViento.en_viento_toy = campo0

	# ---- 4 · la nube de veneno muestrea el campo -------------------------------------------------------------------
	print("--- 4 · nube de veneno como gas pesado")
	NubeVenenoVfx.gas_pesado = false
	NubeVenenoVfx.humo_al_arder = false
	var n0: NubeVeneno3D = NubeVeneno3D.crear(maqueta, base, 8.0, 1.0, j)
	var d0: NubeVenenoVfx = n0.get_node("Dibujo") as NubeVenenoVfx
	for i in 10:
		n0.avanzar(0.1)
	_ok("4.1 apagado (de serie): la nube de siempre, sin campo (muestras %d)" % int(d0.estado()["muestras"]), d0.campo == null and int(d0.estado()["muestras"]) == 0 and not bool(d0.estado()["gas_pesado"]))
	n0.retirar()
	NubeVenenoVfx.gas_pesado = true
	NubeVenenoVfx.humo_al_arder = true
	var bloque: StaticBody3D = _bloque(maqueta, base + Vector3(1.2, 0, 0.2), Vector3(0.8, 0.8, 0.8))
	var n: NubeVeneno3D = NubeVeneno3D.crear(maqueta, base, 0.0, 1.0, j)
	var dv: NubeVenenoVfx = n.get_node("Dibujo") as NubeVenenoVfx
	var r_u: float = n.radio * Terreno3D.casilla
	var alto_max: float = 0.0
	var en_bloque: int = 0
	var fuera_radio: int = 0
	var alfa_max: float = 0.0
	var caja := CampoViento.new()
	caja.poner_caja(base + Vector3(1.2, 0.4, 0.2), Vector3(0.4, 0.4, 0.4))
	for i in 60:
		n.avanzar(0.1)
		var e: Dictionary = dv.estado()
		alfa_max = maxf(alfa_max, float(e["alfa_max"]))
		if i >= 15:
			for p in (e["pos"] as PackedVector3Array):
				alto_max = maxf(alto_max, p.y)
				if caja.sdf(base + p) < 0.0:
					en_bloque += 1
				if Vector2(p.x, p.z).length() > r_u * 1.2:
					fuera_radio += 1
	var est: Dictionary = dv.estado()
	_ok("4.2 encendido: la nube MUESTREA el campo (%d muestras) y ve el bloque y el suelo (%d sólidos)" % [int(est["muestras"]), int(est["solidos"])], dv.campo != null and int(est["muestras"]) > 500 and int(est["solidos"]) >= 2)
	_ok("4.3 gas pesado: a ras de suelo (la bocanada más alta, a %.2f m)" % alto_max, alto_max < 0.85)
	_ok("4.4 las bocanadas rodean el bloque: ninguna dentro (%d)" % en_bloque, en_bloque == 0)
	_ok("4.5 en reposo se queda en su radio (%d fuera de 1,2·R) y sigue translúcida (alfa máx %.3f ≤ %.2f)" % [fuera_radio, alfa_max, NubeVenenoVfx.ALFA_MAX], fuera_radio == 0 and alfa_max <= NubeVenenoVfx.ALFA_MAX + 1.0e-6 and alfa_max > 0.05)
	var verdes: int = 0
	for col in (est["colores"] as Array):
		if (col as Color).g > (col as Color).r * 1.2 and (col as Color).g > (col as Color).b * 1.6:
			verdes += 1
	_ok("4.6 mismos verdes del veneno (%d de %d)" % [verdes, int(est["bocanadas"])], verdes == int(est["bocanadas"]))
	var giran: bool = false
	var p_a: PackedVector3Array = (dv.estado()["pos"] as PackedVector3Array).duplicate()
	n.avanzar(0.5)
	var p_b: PackedVector3Array = dv.estado()["pos"] as PackedVector3Array
	var mov: float = 0.0
	for i in p_a.size():
		mov += Vector2(p_b[i].x - p_a[i].x, p_b[i].z - p_a[i].z).length()
	giran = mov / float(p_a.size()) > 0.02
	_ok("4.7 se arremolina a ras de suelo (desplazamiento horizontal medio %.3f m en 0,5 s)" % (mov / float(p_a.size())), giran)
	# viento: la lógica la empuja, el dibujo se deshilacha
	var disp0: float = _largo_z(dv.estado()["pos"])
	n.soplar(Vector3(0, 0, 1))
	var atras: float = 0.0
	var disp_max: float = 0.0
	var jirones: int = 0
	for i in 10:
		n.avanzar(0.1)
		var ev: Dictionary = dv.estado()
		var sz: float = 0.0
		for p in (ev["pos"] as PackedVector3Array):
			sz += p.z
		atras = minf(atras, sz / float((ev["pos"] as PackedVector3Array).size()))
		disp_max = maxf(disp_max, _largo_z(ev["pos"]))
		var sueltas: int = 0
		for p in (ev["pos"] as PackedVector3Array):
			if Vector2(p.x, p.z).length() > r_u:
				sueltas += 1
		jirones = maxi(jirones, sueltas)
	_ok("4.8 con viento se queda atrás (centro %.2f u detrás) y se DESHILACHA: se estira a lo largo del viento (desviación en z %.2f → %.2f) y %d bocanadas salen del radio" % [atras, disp0, disp_max, jirones], atras < -0.2 and disp_max > disp0 * 1.05 and jirones >= 2)
	# fuego: humo pardo
	n.quemar(4.0)
	var emit: int = 0
	var humo: Variant = null
	for i in 20:
		n.avanzar(0.1)
		await avanzar(3)
		var ef: Dictionary = dv.estado()
		emit = maxi(emit, int(ef["humo_emitidas"]))
		if ef["humo"] != null:
			humo = ef["humo"]
	_ok("4.9 al arder suelta humo de HumoRegla (%d bocanadas)" % emit, humo != null and emit >= 5)
	var pal: Dictionary = HumoRegla.PALETAS[HumoRegla.Materia.HUMO]
	_ok("4.10 ...PARDO (la materia HUMO de HumoRegla, sus colores)", humo != null and (humo as HumoRegla).materia == HumoRegla.Materia.HUMO and (pal["hollin"] as Color).r > (pal["hollin"] as Color).b)
	var t_pared: float = 0.0
	while NubeVeneno3D.vivas.has(n) and t_pared < 6.0:
		n.avanzar(0.1)
		t_pared += 0.1
	await avanzar(5)
	_ok("4.11 al irse la nube el humo deja de emitir (se cierra solo)", not NubeVeneno3D.vivas.has(n) and (humo == null or not is_instance_valid(humo) or (humo as HumoRegla).cerrado))
	NubeVenenoVfx.humo_al_arder = false
	var n2: NubeVeneno3D = NubeVeneno3D.crear(maqueta, base + Vector3(0, 0, 8), 6.0, 1.0, j)
	var d2: NubeVenenoVfx = n2.get_node("Dibujo") as NubeVenenoVfx
	n2.avanzar(0.5)
	n2.quemar(3.0)
	for i in 10:
		n2.avanzar(0.1)
	_ok("4.12 humo_al_arder apagado: arde sin humo", d2.estado()["humo"] == null)
	n2.retirar()
	bloque.queue_free()
	NubeVenenoVfx.gas_pesado = gas0
	NubeVenenoVfx.humo_al_arder = humo0
	await avanzar(2)


## Desviación típica de las bocanadas a lo largo de z (el eje del soplo).
func _largo_z(pos: PackedVector3Array) -> float:
	var m: float = 0.0
	for p in pos:
		m += p.z
	m /= float(maxi(pos.size(), 1))
	var s: float = 0.0
	for p in pos:
		s += (p.z - m) * (p.z - m)
	return sqrt(s / float(maxi(pos.size(), 1)))


func _dispersion(pos: PackedVector3Array) -> float:
	var c := Vector3.ZERO
	for p in pos:
		c += p
	c /= float(maxi(pos.size(), 1))
	var s: float = 0.0
	for p in pos:
		s += Vector2(p.x - c.x, p.z - c.z).length()
	return s / float(maxi(pos.size(), 1))


func _puntos_dentro(cor: Node, sond: CampoViento) -> int:
	if cor == null:
		return -1
	var xf: Transform3D = (cor as Node3D).global_transform
	var k: int = 0
	for tz in (cor.get("_trazos") as Array):
		for p in ((tz as Dictionary)["puntos"] as PackedVector3Array):
			if sond.sdf(xf * p) < -0.01:
				k += 1
	return k


## [puntos de las cintas a menos de 0,6 m de la piel, su distancia media, cuántos van pegados (< 0,12 m)]
func _holgura(cor: Node, sond: CampoViento) -> Array:
	var xf: Transform3D = (cor as Node3D).global_transform
	var n: int = 0
	var suma: float = 0.0
	var rozan: int = 0
	for tz in (cor.get("_trazos") as Array):
		for p in ((tz as Dictionary)["puntos"] as PackedVector3Array):
			var d: float = sond.sdf(xf * p)
			if d < 0.6:
				n += 1
				suma += d
				if d < 0.12:
					rozan += 1
	return [n, suma / float(maxi(n, 1)), rozan]


func _medir(vt: VientoToy, pasos: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in pasos:
		vt._process(1.0 / 30.0)
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(pasos)


func _capsula(padre: Node, pie: Vector3, r: float, alto: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 0
	b.add_to_group("solido_viento")
	var cs := CollisionShape3D.new()
	var f := CapsuleShape3D.new()
	f.radius = r
	f.height = alto
	cs.shape = f
	b.add_child(cs)
	padre.add_child(b)
	b.global_position = pie + Vector3(0, alto * 0.5, 0)
	return b


func _bloque(padre: Node, pie: Vector3, tam: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 0
	b.add_to_group("solido_viento")
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = tam
	cs.shape = f
	b.add_child(cs)
	padre.add_child(b)
	b.global_position = pie + Vector3(0, tam.y * 0.5, 0)
	return b
