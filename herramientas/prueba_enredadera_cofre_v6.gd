extends SceneTree
## V6 (restos, docs/PLAN_EOW_VISUAL.md): la ENREDADERA arde y se deshace con el material común de Ocluso3D (quemado + disolver por celdas, brote con `corte_y`)
## y el COFRE aparece materializándose con el disolver al revés (1 → 0).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_enredadera_cofre_v6.gd
## En headless no hay GPU: el shader no se compila ni se dibuja; esto comprueba el CABLEADO (qué uniform se mueve y cuándo, los tiempos y que la lógica no cambia).
## Que se vea bien lo comprueba herramientas/captura_v6_restos.gd CON VENTANA.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Ocluso3D.preparar()
	await _enredadera("", 1.3)
	await _enredadera("bloqueo", 2.2)
	await _enredadera_interruptor_apagado()
	await _cofre()
	await _cofre_interruptores()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _t() -> float:
	return float(Engine.get_process_frames()) / 30.0      # con --fixed-fps 30 el reloj de pared no sirve (no hay sincronía en tiempo real)


func _enredadera(variante: String, ancho: float) -> void:
	var et: String = "ENR[%s] " % (variante if variante != "" else "normal")
	Ocluso3D.usar_quemado_disolver = true
	var e := Enredadera3D.new()
	root.add_child(e)
	e.preparar(null, ancho, variante)
	await process_frame
	_ok(et + "1. usa el material común de Ocluso3D", Ocluso3D.es_comun(e._mat), str(e._mat))
	var cod: String = e._mat.shader.code
	_ok(et + "1. el shader común trae corte_y, quemado y disolver", cod.contains("uniform float corte_y") and cod.contains("uniform float quemado") and cod.contains("uniform float disolver"))
	_ok(et + "1. viva, quemada y restos comparten ese material", e._viva.material_override == e._mat and e._quemada.material_override == e._mat)
	_ok(et + "1. parte con quemado 0, disolver 0 y sin recorte", Ocluso3D.quemado_de(e._mat) == 0.0 and Ocluso3D.disolver_de(e._mat) == 0.0 and float(e._mat.get_shader_parameter("corte_y")) < -999.0)
	# --- brote intacto ---
	e.brotar()
	await process_frame
	await process_frame            # el rebote (TRANS_BACK) sube casi todo en el primer 15 %: se mira al principio
	var corte: float = float(e._mat.get_shader_parameter("corte_y"))
	var rama: Node3D = e._viva.get_parent() as Node3D
	_ok(et + "2. brotando: recorte del suelo activo y hundida", e.fase == Enredadera3D.Fase.BROTANDO and corte > -1.0 and rama.position.y < -0.05, "corte_y %.3f y %.3f" % [corte, rama.position.y])
	await create_timer(Enredadera3D.DURA_BROTE + 0.1).timeout
	_ok(et + "2. brotada: viva, a ras de suelo y recorte quitado", e.fase == Enredadera3D.Fase.VIVA and absf(rama.position.y) < 0.001 and float(e._mat.get_shader_parameter("corte_y")) < -999.0, "y %.3f" % rama.position.y)
	# --- arde, se quema, se deshace: se muestrea cada cuadro ---
	var t0: float = _t()
	e.quemar()
	var m: Array = []     # [t, fase, quemado, disolver]
	var y0: float = e.position.y
	while is_instance_valid(e) and (_t() - t0) < 9.0:
		await process_frame
		if is_instance_valid(e):
			m.append([_t() - t0, e.fase, Ocluso3D.quemado_de(e._mat), Ocluso3D.disolver_de(e._mat), e.position.y])
	_ok(et + "3. se borra sola al acabar", not is_instance_valid(e))
	var q_fin_arder: float = -1.0
	var q_antes_deshacer: float = 0.0
	var crece: bool = true
	var disolver_antes: bool = false
	var t_des_ini: float = -1.0
	var t_des_fin: float = 0.0
	var d_max: float = 0.0
	var q_prev: float = 0.0
	var d_prev: float = 0.0
	var d_crece: bool = true
	var cuando_quemada: float = -1.0
	var mitad_q: float = -1.0
	for s in m:
		var fase: int = int(s[1])
		if fase == Enredadera3D.Fase.ARDIENDO and mitad_q < 0.0 and float(s[0]) >= Enredadera3D.DURA_ARDER * 0.5:
			mitad_q = float(s[2])
		if fase == Enredadera3D.Fase.QUEMADA and q_fin_arder < 0.0:
			q_fin_arder = float(s[2])
			cuando_quemada = float(s[0])
		if fase != Enredadera3D.Fase.DESHACIENDO:
			if float(s[3]) > 0.0:
				disolver_antes = true
			q_antes_deshacer = float(s[2])
		if fase == Enredadera3D.Fase.DESHACIENDO:
			if t_des_ini < 0.0:
				t_des_ini = float(s[0])
			t_des_fin = float(s[0])
			if float(s[3]) < d_prev - 0.0001:
				d_crece = false
			d_prev = float(s[3])
			d_max = maxf(d_max, float(s[3]))
		if float(s[2]) < q_prev - 0.0001 and fase != Enredadera3D.Fase.DESHACIENDO:
			crece = false
		q_prev = float(s[2])
	print("      quemado a la mitad de ARDIENDO %.2f · al pasar a QUEMADA %.2f (a los %.2f s) · antes de deshacer %.2f · disolver max %.2f · deshaciendo %.2f s" % [mitad_q, q_fin_arder, cuando_quemada, q_antes_deshacer, d_max, t_des_fin - t_des_ini])
	_ok(et + "3. ARDIENDO: el quemado común sube (carbón con brasas), a la mitad ~%.2f" % (Enredadera3D.QUEMADO_AL_ARDER * 0.5), absf(mitad_q - Enredadera3D.QUEMADO_AL_ARDER * 0.5) < 0.1 and crece, "%.2f" % mitad_q)
	_ok(et + "3. al pasar a QUEMADA lleva ~QUEMADO_AL_ARDER", absf(q_fin_arder - Enredadera3D.QUEMADO_AL_ARDER) < 0.08, "%.2f" % q_fin_arder)
	_ok(et + "3. QUEMADA: sigue hasta ceniza (quemado ~1)", q_antes_deshacer > 0.95, "%.2f" % q_antes_deshacer)
	_ok(et + "3. el tiempo hasta QUEMADA es el de antes (DURA_ARDER)", absf(cuando_quemada - Enredadera3D.DURA_ARDER) < 0.2, "%.2f s" % cuando_quemada)
	_ok(et + "3. el disolver no se mueve hasta DESHACIENDO", not disolver_antes)
	_ok(et + "3. DESHACIENDO: disolver común sube de 0 a ~1 sin saltos atrás", d_crece and d_max > 0.9, "max %.2f" % d_max)
	_ok(et + "3. DESHACIENDO dura DURA_DESHACER", absf((t_des_fin - t_des_ini) - Enredadera3D.DURA_DESHACER) < 0.2, "%.2f s" % (t_des_fin - t_des_ini))
	_ok(et + "3. se hunde un poco al deshacerse (como antes)", m.size() > 0 and float(m[m.size() - 1][4]) < y0 - 0.04, "y %.3f -> %.3f" % [y0, float(m[m.size() - 1][4])])
	if variante == "bloqueo":
		_ok(et + "3. (el material de los restos es el mismo común)", true)


func _enredadera_interruptor_apagado() -> void:
	var et: String = "ENR[interruptor apagado] "
	Ocluso3D.usar_quemado_disolver = false
	var e := Enredadera3D.new()
	root.add_child(e)
	e.preparar(null, 1.3, "")
	e.brotar()
	await create_timer(Enredadera3D.DURA_BROTE + 0.2).timeout
	var rama: Node3D = e._viva.get_parent() as Node3D
	var esc0: float = rama.scale.y
	var t0: float = _t()
	e.quemar()
	var q_max: float = 0.0
	var d_max: float = 0.0
	var esc_min: float = esc0
	while is_instance_valid(e) and (_t() - t0) < 9.0:
		await process_frame
		if is_instance_valid(e):
			q_max = maxf(q_max, Ocluso3D.quemado_de(e._mat))
			d_max = maxf(d_max, Ocluso3D.disolver_de(e._mat))
			esc_min = minf(esc_min, rama.scale.y)
	_ok(et + "no toca quemado ni disolver", q_max == 0.0 and d_max == 0.0, "q %.2f d %.2f" % [q_max, d_max])
	_ok(et + "se aplasta al deshacerse y se borra (misma lógica y tiempos)", esc_min < esc0 * 0.5 and not is_instance_valid(e) and (_t() - t0) < 6.5, "escala.y min %.2f de %.2f · %.2f s" % [esc_min, esc0, _t() - t0])
	Ocluso3D.usar_quemado_disolver = true


func _cofre() -> void:
	var et: String = "COFRE "
	Ocluso3D.usar_quemado_disolver = true
	Cofre3D.aparecer_disolviendo = true
	var ps: PackedScene = load("res://arte/piezas/cofre.tscn") as PackedScene
	var pieza: Node3D = ps.instantiate() as Node3D
	root.add_child(pieza)
	await process_frame
	await process_frame
	var c: Cofre3D = Cofre3D.en(pieza)
	var asa: Node3D = c._asa
	var esc0: Vector3 = asa.scale
	var apar: Array = [0]
	c.aparecido.connect(func() -> void: apar[0] += 1)
	c.ocultar()
	_ok(et + "1. oculto: invisible, sin disolver en curso", c.esta_oculto() and not pieza.visible)
	var t0: float = _t()
	_ok(et + "2. aparecer() arranca", c.aparecer())
	var m: Array = []       # [t, disolver_v, disolver del material, escala.x, estado, abrir()]
	var abrio_apareciendo: bool = false
	var primera: bool = true
	while apar[0] == 0 and (_t() - t0) < 3.0:
		if primera:
			primera = false
			abrio_apareciendo = c.abrir()
		await process_frame
		m.append([_t() - t0, c.disolver_v, Ocluso3D.disolver_de(c._mats_disolver[0]) if not c._mats_disolver.is_empty() else -1.0, asa.scale.x, c.estado_nombre()])
	var dur: float = _t() - t0
	_ok(et + "2. usa el material común en el cofre (varios materiales)", not c._mats_disolver.is_empty() and Ocluso3D.es_comun(c._mats_disolver[0]), "%d materiales" % c._mats_disolver.size())
	_ok(et + "2. apareciendo no se puede abrir", not abrio_apareciendo and m.size() > 0 and m[0][4] == &"apareciendo")
	var ini: float = float(m[0][1])
	var baja: bool = true
	for i in range(1, m.size()):
		if float(m[i][1]) > float(m[i - 1][1]) + 0.0001:
			baja = false
	var igual: bool = true
	for s in m:
		if absf(float(s[1]) - float(s[2])) > 0.0001:
			igual = false
	print("      disolver al primer cuadro %.2f · al acabar %.2f · duró %.2f s (%d cuadros)" % [ini, c.disolver_v, dur, m.size()])
	_ok(et + "3. disolver parte de ~1 (invisible) y baja sin saltos atrás", ini > 0.8 and baja, "ini %.2f" % ini)
	_ok(et + "3. el material recibe el mismo valor", igual)
	_ok(et + "3. dura T_APARECE_DISOLVER", absf(dur - Cofre3D.T_APARECE_DISOLVER) < 0.15, "%.2f s" % dur)
	_ok(et + "3. termina en 0 (entero), cerrado y con UNA señal `aparecido`", c.disolver_v == 0.0 and Ocluso3D.disolver_de(c._mats_disolver[0]) == 0.0 and c.estado_nombre() == &"cerrado" and apar[0] == 1)
	var sin_pop: bool = true
	for s in m:
		if absf(float(s[3]) - esc0.x) > 0.0001:
			sin_pop = false
	_ok(et + "3. sin pop de escala (el tamaño no cambia al aparecer)", sin_pop)
	_ok(et + "4. ahora sí se abre y llega a abierto", c.abrir())
	await create_timer(1.3).timeout
	_ok(et + "4. abierto", c.esta_abierto())
	# Ocultar y volver a aparecer: parte otra vez de 1.
	c.ocultar()
	_ok(et + "5. ocultar() deja el disolver en 0 (la pose no queda a medias)", c.disolver_v == 0.0)
	c.aparecer()
	await process_frame
	_ok(et + "5. reaparece desde ~1", c.disolver_v > 0.8)
	c.ocultar()
	await create_timer(Cofre3D.T_APARECE_DISOLVER + 0.2).timeout
	_ok(et + "5. ocultar() durante la aparición cancela el final", c.esta_oculto() and apar[0] == 1 and c.disolver_v == 0.0, "señales=%d" % apar[0])
	pieza.queue_free()


func _cofre_interruptores() -> void:
	var et: String = "COFRE[interruptores] "
	var ps: PackedScene = load("res://arte/piezas/cofre.tscn") as PackedScene
	for caso in ["Cofre3D.aparecer_disolviendo = false", "Ocluso3D.usar_quemado_disolver = false"]:
		Cofre3D.aparecer_disolviendo = caso != "Cofre3D.aparecer_disolviendo = false"
		Ocluso3D.usar_quemado_disolver = caso != "Ocluso3D.usar_quemado_disolver = false"
		var pieza: Node3D = ps.instantiate() as Node3D
		root.add_child(pieza)
		await process_frame
		await process_frame
		var c: Cofre3D = Cofre3D.en(pieza)
		var esc0: Vector3 = c._asa.scale
		c.ocultar()
		c.aparecer()
		await process_frame
		_ok(et + caso + ": vuelve al pop con escala y no toca el disolver", c._asa.scale.x < esc0.x * 0.9 and c.disolver_v == 0.0, "escala %.2f" % c._asa.scale.x)
		await create_timer(Cofre3D.T_APARECE + 0.25).timeout
		_ok(et + caso + ": acaba cerrado a su escala", c.estado_nombre() == &"cerrado" and c._asa.scale.is_equal_approx(esc0))
		pieza.queue_free()
	Cofre3D.aparecer_disolviendo = true
	Ocluso3D.usar_quemado_disolver = true
	# aparecer_ya no anima.
	var p2: Node3D = ps.instantiate() as Node3D
	root.add_child(p2)
	await process_frame
	var c2: Cofre3D = Cofre3D.en(p2)
	c2.ocultar()
	c2.aparecer_ya()
	_ok(et + "aparecer_ya(): cerrado de golpe, sin disolver", c2.estado_nombre() == &"cerrado" and c2.disolver_v == 0.0 and p2.visible)
