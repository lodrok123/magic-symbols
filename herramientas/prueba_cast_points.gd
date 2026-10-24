extends "res://herramientas/escenario_base.gd"
## PRUEBA T-CP1 · CAST POINTS (18/10, Juego; docs/LAB_CASTPOINT.md §2), sin ventana:
##   A  los datos de CastPoints (seis variaciones, tabla nombre derivado → variación, reparto de la anticipación, recortes, una mano, guardado)
##   B  los clips existen en el GLB de la jugadora (los originales y los tres a una mano, con los SINONIMOS pedidos al Pipeline)
##   C  Pj3D.lanzar(id): duración, fraccion_clip() crece de 0 a 1, el libro SE QUEDA en la mano (y en la derecha en x_mano) y vuelve al acabar
##   D  el brazo del libro (BrazoLibro3D): con el modificador la mano del libro queda quieta; sin él se mueve; el lado derecho es el espejo del izquierdo
##   E  Lanzador3D con cada una de las SEIS variaciones: el disparo sale en el instante del clip (≤ 1 fotograma), fases en orden, origen_conjuro,
##      conjuro_fase «forma» en el cast point, distancia mano–origen ≤ 0,15 u con el origen en la mano
##   F  sin clip (variación inexistente / sin cast point) el conjuro es el de siempre (RETARDO_CONJURO)
##   G  clip a UNA mano (fuente `usar_una_mano`): se usa CastOneHand* y el modificador se apaga
##   H  el camino real (cast_page + soltar): el libro se queda en la mano mientras se lanza y vuelve al cinto al acabar; escala del elemento
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_cast_points.gd

const DESDE := Vector2i(6, 24)
const POSICIONES: Dictionary = {"x_mano": ["linea_z"], "alto": ["altura"], "abajo": ["barrera", "linea_x", "linea_x", "linea_x"]}       # 21/10: ᛁ sola es un rayo (x_mano): el volumen plano y quieto que va al suelo es el muro (barrera + ᛁ)

var pj: Pj3D = null


func _escenario() -> void:
	await cargar()
	colocar_jugador(DESDE)
	await avanzar(5)
	pj = jugador.get("pj") as Pj3D
	_ok("0 la jugadora tiene modelo con AnimationPlayer", pj != null and pj._ap != null)
	if pj == null or pj._ap == null:
		return
	var guardado: Dictionary = CastPoints.a_diccionario()

	# --- A · los datos ---
	_ok("A hay seis variaciones", CastPoints.VARIACIONES.size() == 6 and CastPoints.ORDEN.size() == 6)
	_ok("A cada posición (x_mano, alto, abajo) tiene al menos dos", _por_posicion("x_mano") >= 2 and _por_posicion("alto") >= 2 and _por_posicion("abajo") >= 2)
	_ok("A el nombre derivado elige la variación (x_mano → x_mano, alto → alto_cielo, abajo → abajo_golpe)", CastPoints.variacion_de("x_mano") == "x_mano" and CastPoints.variacion_de("alto") == "alto_cielo" and CastPoints.variacion_de("abajo") == "abajo_golpe")
	_ok("A un nombre desconocido no tiene variación (sin cast point: se lanza como siempre)", CastPoints.variacion_de("cosa") == "")
	for id in CastPoints.ORDEN:
		var d: Dictionary = CastPoints.datos(String(id))
		var suma: float = 0.0
		for v in d["anticipacion"]:
			suma += float(v)
		var rec: Vector2 = CastPoints.recorte(String(id))
		_ok("A %s: la anticipación suma 1, el recorte es válido y el instante está dentro" % id, is_equal_approx(suma, 1.0) and rec.x >= 0.0 and rec.y <= 1.0 and rec.x < rec.y and float(d["instante"]) > 0.0 and float(d["instante"]) < 1.0 and CastPoints.ORIGENES.has(String(d["origen"])) and CastPoints.MANOS.has(String(d["mano_libro"])), str(d))
		_ok("A %s: tiene clip a una mano coherente con su origen" % id, String(d["clip_una_mano"]) == String(CastPoints.UNA_MANO_DE_ORIGEN[d["origen"]]), "%s ← %s" % [d["clip_una_mano"], d["origen"]])
	_ok("A el reparto raro se normaliza", CastPoints.normalizar_anticipacion([2.0, 2.0, 4.0]) == [0.25, 0.25, 0.5] and CastPoints.normalizar_anticipacion([0, 0, 0]).size() == 3 and CastPoints.normalizar_anticipacion("x").size() == 3)
	_ok("A el elemento escala el tiempo (rayo ×0,6, tierra ×1,3, fuego ×1)", is_equal_approx(CastPoints.escala_tiempo("lightning"), 0.6) and is_equal_approx(CastPoints.escala_tiempo("earth"), 1.3) and is_equal_approx(CastPoints.escala_tiempo("fire"), 1.0))
	_ok("A x_mano: el libro en la derecha (MageSoellCast003 lanza con la izquierda); alto_cielo en la izquierda", CastPoints.mano_libro("x_mano") == "derecha" and CastPoints.mano_libro("alto_cielo") == "izquierda" and CastPoints.mano_libre("x_mano") == "izquierda")
	_ok("A por defecto la fuente es la original y el modificador está activo", not CastPoints.usar_una_mano and CastPoints.brazo_activo and CastPoints.peso_brazo >= 0.8 and CastPoints.peso_brazo <= 1.0)
	CastPoints.VARIACIONES["x_mano"]["instante"] = 0.5
	var dic: Dictionary = CastPoints.a_diccionario()
	CastPoints.VARIACIONES["x_mano"]["instante"] = 0.9
	CastPoints.desde_diccionario(dic)
	_ok("A guardar y cargar (a_diccionario / desde_diccionario) devuelve lo guardado", is_equal_approx(float(CastPoints.VARIACIONES["x_mano"]["instante"]), 0.5))
	CastPoints.desde_diccionario(guardado)
	_ok("A la tabla para volcar al código nombra las seis", CastPoints.tabla_texto().contains("abajo_deja") and CastPoints.tabla_texto().contains("x_empuje"))

	# --- B · los clips ---
	for rol in ["cast_proyectil", "cast_empuje", "cast_columna", "cast_corro", "pick_up", "cast_mano_frente", "cast_mano_alto", "cast_mano_suelo"]:
		_ok("B el GLB trae el clip del rol %s" % rol, pj._buscar_clip(String(rol)) != "", "«%s»" % pj._buscar_clip(String(rol)))
	_ok("B los SINONIMOS pedidos resuelven a CastOneHandFront / Up / Ground", pj._buscar_clip("cast_mano_frente") == "CastOneHandFront" and pj._buscar_clip("cast_mano_alto") == "CastOneHandUp" and pj._buscar_clip("cast_mano_suelo") == "CastOneHandGround")
	for id in CastPoints.ORDEN:
		_ok("B %s: sus dos clips (original y a una mano) existen" % id, pj._buscar_clip(String(CastPoints.datos(String(id))["clip"])) != "" and pj._buscar_clip(String(CastPoints.datos(String(id))["clip_una_mano"])) != "")

	# --- C · Pj3D.lanzar(id) ---
	pj.soltar_lanzar()
	await avanzar_s(0.8)
	_mantener_lanzando(true)
	var dur: float = pj.lanzar("proyectil", "fire", "x_mano")
	var esperada: float = (0.85 - 0.40) * pj._ap.get_animation(pj._buscar_clip("cast_proyectil")).length / (1.6 / CastPoints.escala_tiempo("fire"))
	_ok("C lanzar(id) devuelve lo que dura el recorte a su velocidad (%.2f s)" % esperada, absf(dur - esperada) < 0.01, "%.3f" % dur)
	_ok("C hay un lanzamiento por cast point en curso y es x_mano", pj.cast_activo() and pj.punto_activo() == "x_mano")
	await avanzar(1)
	_ok("C fraccion_clip() arranca cerca de 0", pj.fraccion_clip() >= 0.0 and pj.fraccion_clip() < 0.25, "%.3f" % pj.fraccion_clip())
	_ok("C el libro está en la mano DERECHA (no vuelve al cinto)", pj._libro != null and is_instance_valid(pj._libro) and pj._libro_lado == "derecha")
	var t_ini: float = reloj.t
	var f_prev: float = pj.fraccion_clip()
	var creciente: bool = true
	var t_instante_real: float = -1.0
	while reloj.t - t_ini < dur + 0.5 and pj.fraccion_clip() < 1.0:
		await process_frame
		var f: float = pj.fraccion_clip()
		creciente = creciente and f >= f_prev - 0.0001
		f_prev = f
		if t_instante_real < 0.0 and f >= CastPoints.datos("x_mano")["instante"]:
			t_instante_real = reloj.t - t_ini
	_ok("C fraccion_clip() solo crece", creciente)
	_ok("C llega al instante en lo previsto (± 1 fotograma)", absf(t_instante_real - pj.tiempo_instante()) <= 1.0 / 30.0 + 0.01, "real %.3f · previsto %.3f" % [t_instante_real, pj.tiempo_instante()])
	await avanzar(3)
	_ok("C al llegar a `fin` el clip se queda ahí (fracción 1)", is_equal_approx(pj.fraccion_clip(), 1.0), "%.3f" % pj.fraccion_clip())
	_ok("C el libro SIGUE en la mano al acabar el clip", pj._libro != null and is_instance_valid(pj._libro))
	pj.soltar_lanzar()
	await avanzar_s(0.7)
	_ok("C al acabar (soltar_lanzar) el libro vuelve al cinto y el lanzamiento termina", not pj.cast_activo() and pj._libro == null and pj.fraccion_clip() < 0.0)
	_ok("C la velocidad de la animación se restaura", is_equal_approx(pj.velocidad_animacion(), 1.0))

	# `sostener`: el clip se congela en el instante.
	CastPoints.VARIACIONES["x_mano"]["sostener"] = 0.5
	_mantener_lanzando(true)
	var dur_s: float = pj.lanzar("proyectil", "fire", "x_mano")
	_ok("C con sostener 0,5 el lanzamiento dura 0,5 s más", absf(dur_s - dur - 0.5) < 0.01, "%.3f vs %.3f" % [dur_s, dur])
	var tt: float = reloj.t
	while reloj.t - tt < pj.tiempo_instante() + 0.25 and not pj.paso_instante():
		await process_frame
	await avanzar(2)
	var f_a: float = pj.fraccion_clip()
	await avanzar_s(0.2)
	_ok("C sostener congela el clip en el instante (no avanza en 0,2 s)", pj.paso_instante() and absf(pj.fraccion_clip() - f_a) < 0.005 and absf(f_a - 0.62) < 0.03, "%.3f → %.3f" % [f_a, pj.fraccion_clip()])
	await avanzar_s(0.6)
	_ok("C pasado el sostener el clip sigue", pj.fraccion_clip() > f_a + 0.05, "%.3f" % pj.fraccion_clip())
	CastPoints.VARIACIONES["x_mano"]["sostener"] = 0.0
	pj.soltar_lanzar()
	_mantener_lanzando(false)
	await avanzar_s(0.7)

	# --- D · el brazo del libro ---
	# Dos variaciones con el libro en la izquierda: x_empuje (la mano del libro casi no se mueve: la de la jugadora nueva solo recorre 0,100 u) y alto_cielo (brazos arriba: se movería muchísimo).
	# Con el modificador, la mano se queda quieta: < 0,03 u, o lo que deja pasar el peso (la parte 1 − peso del movimiento del clip, que con peso 0,9 es el 10 %) con un margen del 3 %.
	var hay_movimiento: bool = false
	var detalle: String = ""
	for id_d in ["x_empuje", "alto_cielo"]:
		var sin_mod: float = await _rango_mano_libro(String(id_d), 0.0)
		var con_mod: float = await _rango_mano_libro(String(id_d), CastPoints.peso_brazo)
		_ok("D %s: con el modificador el libro apenas se mueve respecto al torso (< 0,03 u o ≤ %.0f %% de lo que se movería)" % [id_d, (1.0 - CastPoints.peso_brazo + 0.03) * 100.0],
			con_mod < 0.03 or con_mod <= sin_mod * (1.0 - CastPoints.peso_brazo + 0.03), "sin %.3f · con %.3f u" % [sin_mod, con_mod])
		hay_movimiento = hay_movimiento or (sin_mod > con_mod * 3.0 and sin_mod > 0.1)
		detalle += "%s: sin %.3f · con %.3f  " % [id_d, sin_mod, con_mod]
	_ok("D sin el modificador el libro se mueve de verdad en alguna variación (> 3× más y > 0,1 u)", hay_movimiento, detalle)
	var b: BrazoLibro3D = pj._brazo
	_ok("D el modificador existe, está preparado y cuelga del esqueleto", b != null and b.preparado and b.get_parent() is Skeleton3D)
	var sk: Skeleton3D = pj._esqueleto()
	var hi: BoneAttachment3D = _atar(sk, "mixamorig_LeftHand")
	var hd: BoneAttachment3D = _atar(sk, "mixamorig_RightHand")
	var torso: BoneAttachment3D = _atar(sk, "mixamorig_Spine2")
	var dif_espejo: float = 0.0
	for lado in ["izquierda", "derecha"]:
		b.lado = lado
		b.influence = 1.0
		_mantener_lanzando(true)
		pj.pose_fija("cast_corro", 1.2)               # (A1: el árbol es lo único que reproduce; la pose conocida se pide con pose_fija)
		await avanzar(3)
		if lado == "izquierda":
			dif_espejo = _en_torso(torso, hi.global_position).x
			_ok("D el brazo izquierdo queda en la pose del libro (hacia el lado izquierdo del torso, x > 0)", dif_espejo > 0.02, "%.3f" % dif_espejo)
		else:
			var xd: float = _en_torso(torso, hd.global_position).x
			_ok("D el derecho queda en el ESPEJO del izquierdo (|x| igual, signo contrario: error < 0,03 u)", absf(xd + dif_espejo) < 0.03, "izq %.3f · der %.3f" % [dif_espejo, xd])
	b.influence = 0.0
	_mantener_lanzando(false)
	hi.queue_free()
	hd.queue_free()
	torso.queue_free()
	pj.soltar_lanzar()
	await avanzar_s(0.7)

	# --- E · Lanzador3D con cada variación ---
	var fases: Array = []
	var pos_fases: Dictionary = {}
	lanzador.conjuro_fase.connect(func(f: String, _e: String, p: Vector3) -> void:
		fases.append([f, reloj.t])
		pos_fases[f] = p)
	for id in CastPoints.ORDEN:
		await _lanzar_variacion(String(id), fases, pos_fases)

	# --- F · sin cast point: como siempre ---
	CastPoints.POR_NOMBRE = {}
	fases.clear()
	var ficha: Dictionary = _datos_de("x_mano", "fire")
	await _esperar_cooldown()
	var tiempo0: float = reloj.t
	lanzador.lanzar_ahora(ficha, jugador.position, Vector3.RIGHT, true)
	_ok("F sin cast point no hay punto activo (clip de siempre)", pj.punto_activo() == "" and not pj.cast_activo())
	var tf: float = 0.0
	while lanzador.conjurando and tf < 3.0:
		tf += await avanzar_s(0.05)
	var disparo_t: float = float(fases.back()[1]) - tiempo0 if not fases.is_empty() else -1.0
	_ok("F el disparo sale por reloj (RETARDO_CONJURO fuego ≈ 0,45 s, ± 3 fotogramas)", absf(disparo_t - lanzador.retardo_total("fuego")) < 0.12, "%.3f s (tres temporizadores: hasta 3 fotogramas de redondeo)" % disparo_t)
	_ok("F con las fases de siempre: runa, voluta, forma, disparo", _nombres(fases) == ["runa", "voluta", "forma", "disparo"], str(_nombres(fases)))
	CastPoints.desde_diccionario(guardado)
	CastPoints.POR_NOMBRE = (guardado["por_nombre"] as Dictionary).duplicate()
	await avanzar_s(1.0)
	pj.soltar_lanzar()

	# --- G · clip a una mano ---
	CastPoints.usar_una_mano = true
	CastPoints.POR_NOMBRE["x_mano"] = "x_mano"
	await _esperar_cooldown()
	var f1: Dictionary = _datos_de("x_mano", "fire")
	fases.clear()
	lanzador.lanzar_ahora(f1, jugador.position, Vector3.RIGHT, true)
	_ok("G con la fuente «una mano» se usa CastOneHandFront", pj.cast_activo() and String(pj._cp["clip"]) == "CastOneHandFront", str(pj._cp.get("clip", "")))
	# Con un esqueleto de pose a mano (la jugadora nueva) el clip a una mano viene traducido de otro reposo y el brazo del libro SIGUE puesto; con el resto (clips propios) se apaga.
	var con_pose_a_mano: bool = Pj3D.POSE_LIBRO_BRAZO.has(pj.id)
	_ok("G el libro va a la izquierda (la derecha lanza) y el modificador del brazo %s" % ("sigue puesto (pose a mano de %s)" % pj.id if con_pose_a_mano else "se apaga"),
		pj._libro_lado == "izquierda" and ((pj._brazo != null and pj._brazo.influence > 0.0) if con_pose_a_mano else (pj._brazo == null or pj._brazo.influence == 0.0)))
	tf = 0.0
	while lanzador.conjurando and tf < 3.0:
		tf += await avanzar_s(0.05)
	_ok("G el disparo también sale en el instante (≤ 1 fotograma)", absf(float(lanzador.ultimo_castpoint.get("desfase_fotogramas", 99.0))) <= 1.0, str(lanzador.ultimo_castpoint))
	CastPoints.usar_una_mano = false
	await avanzar_s(1.5)
	pj.soltar_lanzar()
	await avanzar_s(0.7)

	# --- I · el libro descansa en la palma ---
	_ok("I CastPoints.de(nombre, elemento) da la variación y el origen (la forma que esperaba el Pipeline)", String(CastPoints.de("alto", "fire")["origen"]) == "manos_alto" and is_equal_approx(float(CastPoints.de("x_mano", "lightning")["escala_tiempo"]), 0.6) and CastPoints.de("nada").is_empty())
	for una in [false, true]:
		CastPoints.usar_una_mano = una
		for id in ["x_mano", "x_empuje", "alto_cielo"]:
			pj.soltar_lanzar()
			_mantener_lanzando(true)
			await avanzar_s(0.7)
			var dd: float = pj.lanzar("proyectil", "fire", id)
			await avanzar_s(dd * 0.6)
			var ang: float = rad_to_deg((pj._libro as Node3D).global_transform.basis.orthonormalized().z.angle_to(Vector3.UP))
			_ok("I %s con %s: el libro está sobre la palma (normal a menos de 50° de la vertical; antes ≥ 100°)" % [id, "el clip a una mano" if una else "el original + modificador"], ang < 50.0, "%.0f°" % ang)
	CastPoints.usar_una_mano = false
	pj.soltar_lanzar()
	_mantener_lanzando(false)
	await avanzar_s(0.7)

	# --- H · el camino real: el libro se queda en la mano al soltar y vuelve al acabar ---
	await _esperar_cooldown()
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	jugador.tinta.actual = 100.0
	lanzador.cooldown_left[0] = 0.0
	lanzador.cast_page(0)
	await avanzar(2)
	_ok("H al apuntar el libro está en la mano", pj._libro != null and is_instance_valid(pj._libro))
	var datos_h: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	lanzador.lanzar_ahora(datos_h, jugador.position, Vector3.RIGHT, true)
	await avanzar(2)
	_ok("H al SOLTAR para lanzar el libro NO vuelve al cinto (sigue en la mano)", pj._libro != null and is_instance_valid(pj._libro) and pj.libro_estado() != "volando", "libro %s" % str(pj._libro))
	tf = 0.0
	while lanzador.conjurando and tf < 3.0:
		tf += await avanzar_s(0.05)
	await avanzar(2)
	_ok("H el hechizo salió con el libro aún en la mano", pj._libro != null and is_instance_valid(pj._libro))
	await avanzar_s(2.5)
	_ok("H al acabar el lanzamiento el libro vuelve al cinto", pj._libro == null and not pj.cast_activo(), "cast %s libro %s" % [str(pj.cast_activo()), str(pj._libro)])
	# Cancelar el apuntado sí lo guarda en el acto.
	lanzador.cooldown_left[0] = 0.0
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	lanzador.place_sigil("flecha")
	lanzador.cast_page(0)
	await avanzar(2)
	lanzador._cancelar_modo()
	await avanzar_s(0.7)
	_ok("H cancelar el apuntado guarda el libro (como siempre)", pj._libro == null)
	# El elemento escala el tiempo.
	var t_fuego: float = await _tiempo_hasta_instante("fire")
	var t_rayo: float = await _tiempo_hasta_instante("lightning")
	var t_tierra: float = await _tiempo_hasta_instante("earth")
	_ok("H rayo ×0,6 y tierra ×1,3 del tiempo del fuego", absf(t_rayo / t_fuego - 0.6) < 0.01 and absf(t_tierra / t_fuego - 1.3) < 0.01, "fuego %.3f · rayo %.3f · tierra %.3f" % [t_fuego, t_rayo, t_tierra])
	CastPoints.desde_diccionario(guardado)


## Jugador3D vuelve a poner idle/walk cada fotograma si no cree que está lanzando; las pruebas que llaman a Pj3D directamente se lo hacen creer.
func _mantener_lanzando(si: bool) -> void:
	jugador.set("_lanzando", si)
	jugador.set("_t_lanzar", 30.0 if si else 0.0)


func _por_posicion(pos: String) -> int:
	var n: int = 0
	for id in CastPoints.VARIACIONES:
		if String(CastPoints.VARIACIONES[id]["posicion"]) == pos:
			n += 1
	return n


func _nombres(fases: Array) -> Array:
	var r: Array = []
	for f in fases:
		r.append(f[0])
	return r


## Un punto del mundo en el espacio del torso, en unidades del MODELO (la elfa vieja trae el esqueleto a escala 1 y la jugadora nueva a 100: el ancla del torso lleva esa escala, así
## que solo se usa su posición y su giro, y se divide por la escala del personaje).
func _en_torso(torso: Node3D, p_mundo: Vector3) -> Vector3:
	var t := Transform3D(torso.global_transform.basis.orthonormalized(), torso.global_transform.origin)
	return (t.affine_inverse() * p_mundo) / maxf(pj.scale.y, 0.0001)


func _atar(sk: Skeleton3D, hueso: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = hueso
	sk.add_child(a)
	return a


func _esperar_cooldown() -> void:
	lanzador.cooldown_left[0] = 0.0
	lanzador.cooldown_left[1] = 0.0
	if jugador.tinta != null:
		jugador.tinta.actual = 100.0
	var t: float = 0.0
	while lanzador.conjurando and t < 4.0:
		t += await avanzar_s(0.1)
	await avanzar(2)


## Los datos de un lanzamiento (lo que `cast_page` prepara) para la posición `nombre` (x_mano · alto · abajo) y un elemento.
func _datos_de(nombre: String, elem: String) -> Dictionary:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in (POSICIONES[nombre] as Array):
		r.apply(String(g))
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % elem) as RuneData
	return {"indice": 0, "receta": r, "rune": rune, "calidad": 1.0, "glifos": POSICIONES[nombre], "elemento_nombre": elem}


## Rango (u) que recorre el libro de la mano que lo lleva durante un lanzamiento de la variación `id` con el modificador a `peso`.
func _rango_mano_libro(id: String, peso: float) -> float:
	var antes: float = CastPoints.peso_brazo
	var act: bool = CastPoints.brazo_activo
	CastPoints.peso_brazo = peso
	CastPoints.brazo_activo = peso > 0.0
	pj.soltar_lanzar()
	await avanzar_s(0.7)
	_mantener_lanzando(true)
	var dur: float = pj.lanzar("proyectil", "fire", id)
	await avanzar(2)
	var mx: Vector3 = Vector3(-1e9, -1e9, -1e9)
	var mn: Vector3 = Vector3(1e9, 1e9, 1e9)
	var torso: BoneAttachment3D = _atar(pj._esqueleto(), "mixamorig_Spine2")
	await avanzar(1)
	var t0: float = reloj.t
	while reloj.t - t0 < dur - 0.1:
		await process_frame
		if pj._libro != null and is_instance_valid(pj._libro):
			# En el espacio del TORSO: el libro sigue al tronco cuando se inclina (natural); lo que importa es que el brazo no lo mueva por su cuenta.
			var p: Vector3 = _en_torso(torso, (pj._libro as Node3D).global_position)
			mx = mx.max(p)
			mn = mn.min(p)
	torso.queue_free()
	pj.soltar_lanzar()
	_mantener_lanzando(false)
	await avanzar_s(0.7)
	CastPoints.peso_brazo = antes
	CastPoints.brazo_activo = act
	return (mx - mn).length()


## El tiempo (s) que tarda el clip en llegar a su instante con un elemento (lo da Pj3D, sin lanzar nada más).
func _tiempo_hasta_instante(elem: String) -> float:
	pj.soltar_lanzar()
	await avanzar_s(0.7)
	pj.lanzar("proyectil", elem, "x_mano")
	var t: float = pj.tiempo_instante()
	pj.soltar_lanzar()
	await avanzar_s(0.7)
	return t


## E: lanza con la variación `id` (forzando que el nombre derivado de su posición la elija) y comprueba el instante, las fases y el origen.
func _lanzar_variacion(id: String, fases: Array, pos_fases: Dictionary) -> void:
	var d: Dictionary = CastPoints.datos(id)
	var nombre: String = String(d["posicion"])
	var antes: String = String(CastPoints.POR_NOMBRE.get(nombre, ""))
	CastPoints.POR_NOMBRE[nombre] = id
	await _esperar_cooldown()
	pj.soltar_lanzar()
	await avanzar_s(0.7)
	var datos: Dictionary = _datos_de(nombre, "fire")
	_ok("E %s: la receta de prueba se deriva como «%s»" % [id, nombre], String((datos["receta"] as Lanzador3D.Receta3D).geo()["nombre"]) == nombre, String((datos["receta"] as Lanzador3D.Receta3D).geo()["nombre"]))
	fases.clear()
	pos_fases.clear()
	var celdas: Array = []
	var cap := func(_e: String, _el: String, g: Dictionary, _o: Vector3, _dd: Vector3, _p: Dictionary) -> void: celdas.assign(g["celdas"])
	lanzador.hechizo_v2.connect(cap)
	var t0: float = reloj.t
	lanzador.lanzar_ahora(datos, jugador.position, Vector3.RIGHT, true)
	_ok("E %s: arranca el clip de su cast point" % id, pj.cast_activo() and pj.punto_activo() == id and lanzador.conjurando)
	var oc: Dictionary = lanzador.origen_conjuro("fire")
	_ok("E %s: origen_conjuro() dice «%s» y da un destino en el suelo" % [id, d["origen"]], String(oc["origen"]) == String(d["origen"]) and (oc["destino"] as Vector3) != Vector3.ZERO, str(oc))
	_ok("E %s: la mano del libro es %s" % [id, CastPoints.mano_libro(id)], pj._libro_lado == CastPoints.mano_libro(id), pj._libro_lado)
	var previsto: float = pj.tiempo_instante()
	var espera: float = 0.0
	while lanzador.conjurando and espera < 4.0:
		espera += await avanzar_s(0.03)
	await avanzar(2)
	lanzador.hechizo_v2.disconnect(cap)
	_ok("E %s: las fases salen en orden (runa, voluta, forma, disparo)" % id, _nombres(fases) == ["runa", "voluta", "forma", "disparo"], str(_nombres(fases)))
	var t_disparo: float = float(fases.back()[1]) - t0 if not fases.is_empty() else -1.0
	_ok("E %s: el disparo sale en el instante del clip (previsto %.3f s, ± 1 fotograma)" % [id, previsto], absf(t_disparo - previsto) <= 1.0 / 30.0 + 0.02, "real %.3f" % t_disparo)
	var m: Dictionary = lanzador.ultimo_castpoint
	_ok("E %s: desfase instante ↔ fotograma ≤ 1 fotograma" % id, absf(float(m.get("desfase_fotogramas", 99.0))) <= 1.0, str(m))
	_ok("E %s: PlayLog anota `castpoint`" % id, not eventos("castpoint").is_empty() and String(eventos("castpoint").back().get("id", "")) == id)
	_ok("E %s: el hechizo salió (casillas)" % id, not celdas.is_empty(), "%d" % celdas.size())
	if String(d["origen"]) == "mano_libre":
		_ok("E %s: con el origen en la mano libre, distancia mano–origen ≤ 0,15 u" % id, float(m.get("dist_mano", 9.0)) <= 0.15, "%.3f u" % float(m.get("dist_mano", 9.0)))
	_ok("E %s: «forma» sale en el cast point (la posición de conjuro_fase es la del punto, ± 0,6 u)" % id, pos_fases.has("forma") and (pos_fases["forma"] as Vector3).distance_to(pj.posicion_punto(String(d["origen"]), Vector3.RIGHT, CastPoints.mano_libro(id))) < 0.6, str(pos_fases.get("forma", "")))
	if String(d["origen"]) == "manos_alto":
		_ok("E %s: el punto «manos_alto» está sobre la cabeza (más alto que el pecho)" % id, (pos_fases["forma"] as Vector3).y > pj.global_position.y + 0.8, "%.2f" % (pos_fases["forma"] as Vector3).y)
	if String(d["origen"]) == "suelo_delante":
		_ok("E %s: el punto «suelo_delante» está a los pies, una casilla hacia delante" % id, absf((pos_fases["forma"] as Vector3).y - pj.global_position.y) < 0.3 and absf((pos_fases["forma"] as Vector3).x - (pj.global_position.x + Terreno3D.casilla)) < 0.6, str(pos_fases["forma"]))
	if antes == "":
		CastPoints.POR_NOMBRE.erase(nombre)
	else:
		CastPoints.POR_NOMBRE[nombre] = antes
	await avanzar_s(0.3)
