extends "res://herramientas/escenario_base.gd"
## Escenario · EL GIRO DEL MOLINO (23/11/2026, Juego; encargo de Pablo: «revisa el movimiento del molino para que sea realista en el giro»). Carga el
## laboratorio de puzles de agua (Q9 «molino»: arroyo de canal (28,1..7), compuerta-grifo en (28,2), molino en (28,5)) y mide, con la rueda de verdad:
##   · parada sin agua y la rueda BAJADA al fondo de su casilla (la punta de las palas por debajo de la superficie con el arroyo corriendo);
##   · el golpe de un hechizo de agua: gira, en el sentido de la dirección del chorro, emite `girando` y se frena sin saltos;
##   · con el grifo abierto: sentido (palas de abajo CON el agua, medido con la transformada real de la rueda), velocidad estable ∝ corriente y `girando`;
##   · al cerrar el grifo: ω monótona hasta pararse, sin saltos, y `girando` se suelta;
##   · con `hechizo=no`: el golpe la mueve (ω > 0) pero `girando` nunca salta.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_molino_giro.gd

const RUTA_LAB: String = "res://laboratorios/LabPuzlesAgua3D.tscn"

var lab: Node = null
var mol: Molino3D = null
var _senales: Array = []                       ## cada `girando(si)` que emite el molino, con el instante


func _escenario() -> void:
	await cargar(RUTA_LAB, false, 3000)
	lab = maqueta.get_node_or_null("Reglas")
	if lab == null:
		_ok("0 el laboratorio carga", false, "sin lab")
		return
	var q: Dictionary = lab.call("puzle", "Q9")
	var puerta: Node = q["puerta"]
	var k: Node = q["compuerta"]
	mol = q["molino"]
	mol.girando.connect(func(si: bool) -> void: _senales.append([snappedf(reloj.t, 0.01), si]))
	var sim: AguaSim3D = Terreno3D.agua_sim

	# --- 1 · parada sin agua y la rueda al fondo de su casilla ---
	await avanzar_s(1.0)
	_ok("1.1 sin agua la rueda está parada", mol.velocidad == 0.0 and not mol.activo and mol.corriente() < 0.05, "ω %.3f corriente %.3f" % [mol.velocidad, mol.corriente()])
	var punta: float = mol.punta_y()
	_ok("1.2 la punta de las palas queda %.1f u sobre el fondo de su casilla (fondo %.3f, punta %.3f)" % [Molino3D.PUNTA_SOBRE_FONDO, mol.fondo, punta],
		absf(punta - (mol.fondo + Molino3D.PUNTA_SOBRE_FONDO)) < 0.02)

	# --- 2 · golpe de agua (el mismo disparo que Q9: de oeste a este, de lado a la rueda) ---
	_senales.clear()
	_ok("2.1 agua + flecha a la rueda desde el oeste (de lado: sin componente en el plano, gira en el sentido por defecto)", lanzar_a_celda("agua", ["flecha"], Vector2i(28, 5), Vector2i(26, 5)))
	await avanzar_s(0.3)
	var w_prev: float = mol.velocidad
	var saltos: float = 0.0
	var pico: float = 0.0
	var t0: float = reloj.t
	while reloj.t - t0 < 6.0:
		await process_frame
		saltos = maxf(saltos, absf(mol.velocidad - w_prev))
		pico = maxf(pico, mol.velocidad)
		w_prev = mol.velocidad
	_ok("2.2 el golpe la hace girar en el sentido del chorro (ω > 0) y emite girando(true)", pico > 1.5 and not _senales.is_empty() and bool(_senales[0][1]), "pico %.2f rad/s, señales %s" % [pico, str(_senales)])
	_ok("2.3 sin saltos: el mayor cambio de ω entre fotogramas es pequeño", saltos < 0.1, "%.4f rad/s por fotograma" % saltos)
	var esperar: float = 0.0
	while mol.velocidad != 0.0 and esperar < 40.0:
		await avanzar_s(0.5)
		esperar += 0.5
	_ok("2.4 pasado el impulso (y el charco) la rueda se para", mol.velocidad == 0.0 and not mol.activo, "tras %.1f s más" % esperar)
	_ok("2.5 la puerta se vuelve a cerrar al parar", not bool(puerta.get("abierta")))

	# --- 3 · el grifo abierto: sentido, velocidad estable, girando ---
	await avanzar_s(8.0)                                      # que el charco del golpe acabe de irse
	_senales.clear()
	(lab.call("pulsador_en", Vector2i(26, 6)) as Node).call("pulsar")
	_ok("3.1 el botón abre la compuerta", bool(k.get("abierta")))
	var r: Dictionary = {"t_gira": -1.0}
	var t_abre: float = reloj.t
	var tabla: Array = []
	var w_prev3: float = mol.velocidad
	var salto3: float = 0.0
	while reloj.t - t_abre < 90.0:
		await process_frame
		salto3 = maxf(salto3, absf(mol.velocidad - w_prev3))
		w_prev3 = mol.velocidad
		if float(r["t_gira"]) < 0.0 and mol.activo:
			r["t_gira"] = reloj.t - t_abre
		if tabla.size() < int((reloj.t - t_abre) / 2.0):
			tabla.append("%.0fs: corriente %.2f (plano %.2f) ω %.2f obj %.2f" % [reloj.t - t_abre, mol.corriente(), mol.flujo().dot(mol.dir_abajo()), mol.velocidad,
				Molino3D.omega_de(mol.flujo().dot(mol.dir_abajo()))])
		if float(r["t_gira"]) > 0.0 and reloj.t - t_abre > float(r["t_gira"]) + 25.0:
			break
	for linea in tabla:
		print("      ", linea)
	_ok("3.2 con el arroyo corriendo girando(true) salta", float(r["t_gira"]) > 0.0 and mol.activo, "a los %.1f s" % float(r["t_gira"]))
	_ok("3.3 la puerta (mecanismo) se abre", bool(puerta.get("abierta")))
	var v_plano: float = mol.flujo().dot(mol.dir_abajo())
	var w_obj: float = Molino3D.omega_de(v_plano)
	var w_est: float = mol.velocidad
	print("      estable: corriente %.3f u/s (en el plano %.3f), ω_obj %.3f, ω %.3f rad/s, ω_umbral %.3f" % [mol.corriente(), v_plano, w_obj, w_est, mol.omega_umbral()])
	_ok("3.4 la velocidad estable es la que da la corriente (ω = v/R × EFICIENCIA, con tope VEL_MAX), con el sentido de la corriente", absf(w_est) > 0.0 and absf(w_est - w_obj) < 0.05 * maxf(absf(w_obj), 0.1) and signf(w_est) == signf(v_plano),
		"ω %.3f, objetivo %.3f" % [w_est, w_obj])
	_ok("3.7 proporcional por debajo del tope: ω(1 u/s)×2 = ω(2 u/s) y 0 bajo el rozamiento estático", absf(Molino3D.omega_de(1.0) * 2.0 - Molino3D.omega_de(2.0)) < 0.001 and Molino3D.omega_de(0.04) == 0.0 and Molino3D.omega_de(0.5) > 0.0 and Molino3D.omega_de(50.0) == Molino3D.VEL_MAX,
		"ω(0,5)=%.3f ω(1)=%.3f ω(2)=%.3f ω(3,75)=%.3f" % [Molino3D.omega_de(0.5), Molino3D.omega_de(1.0), Molino3D.omega_de(2.0), Molino3D.omega_de(3.75)])
	# Medio caudal: lo que daría una corriente la mitad de la medida.
	print("      con medio caudal (%.3f u/s) el objetivo sería ω = %.3f rad/s; con todo (%.3f u/s), %.3f rad/s" % [v_plano * 0.5, Molino3D.omega_de(v_plano * 0.5), v_plano, w_obj])
	# El sentido, con la transformada real: la pala que está abajo se mueve en el sentido de la corriente.
	var rueda: Node3D = mol.rueda()
	var p0: Vector3 = rueda.global_position + Vector3(0.0, -Molino3D.RADIO, 0.0)
	var m_local: Vector3 = rueda.global_transform.affine_inverse() * p0
	var f0: Vector2 = mol.flujo()
	await avanzar(2)
	var p1: Vector3 = rueda.global_transform * m_local
	var desp := Vector2(p1.x - p0.x, p1.z - p0.z)
	_ok("3.5 la pala de abajo va CON el agua (desplazamiento %s, corriente %s)" % [str(desp.snapped(Vector2(0.001, 0.001))), str(f0.snapped(Vector2(0.001, 0.001)))], desp.length() > 0.001 and desp.dot(f0) > 0.0)
	# La punta toca el agua con el arroyo corriendo.
	var superficie: float = mol.fondo + sim.profundidad_casilla(mol.celda)
	_ok("3.6 con el arroyo corriendo la punta de las palas está bajo la superficie del agua de su casilla", mol.punta_y() < superficie - 0.02, "punta %.3f, superficie %.3f (fondo %.3f + prof %.3f)" % [mol.punta_y(), superficie, mol.fondo, sim.profundidad_casilla(mol.celda)])

	# --- 4 · cerrar el grifo: frena sin saltos y se para ---
	_senales.clear()
	k.call("cerrar")
	var serie: Array = []
	var t_cierra: float = reloj.t
	var mayor_salto: float = 0.0
	var w_prev4: float = mol.velocidad
	while reloj.t - t_cierra < 90.0:
		await process_frame
		serie.append(mol.velocidad)
		mayor_salto = maxf(mayor_salto, absf(mol.velocidad - w_prev4))
		w_prev4 = mol.velocidad
		if mol.velocidad == 0.0 and not mol.activo and reloj.t - t_cierra > 3.0:
			break
	var monotona: bool = true
	var peor: float = 0.0
	for i in range(1, serie.size()):
		var subida: float = absf(float(serie[i])) - absf(float(serie[i - 1]))
		peor = maxf(peor, subida)
		if subida > 0.02:
			monotona = false
	_ok("4.1 al cerrar el grifo la rueda se para", mol.velocidad == 0.0 and not mol.activo, "tras %.1f s" % (reloj.t - t_cierra))
	_ok("4.2 frena sin saltos: |ω| solo baja (el agua que se va chapotea: se tolera 0,02) y nunca cambia más de VEL_MAX·dt/TAU por fotograma", peor < 0.02 and mayor_salto < 0.09, "mayor subida %.4f, mayor cambio por fotograma %.4f rad/s" % [peor, mayor_salto])
	var cayo: bool = false
	for s in _senales:
		if not bool(s[1]):
			cayo = true
	_ok("4.3 girando(false) se emite al parar (y la puerta se cierra)", cayo and not bool(puerta.get("abierta")), str(_senales))

	# --- 5 · hechizo=no: el golpe la mueve pero no cuenta para girando ---
	await avanzar_s(10.0)
	mol.hechizo = false
	_senales.clear()
	var agua: RuneData = load("res://nucleo/water_rune.tres")
	mol.on_spell_hit(agua, Vector3(0.0, 0.0, -1.0))
	var pico5: float = 0.0
	var activo5: bool = false
	var t5: float = reloj.t
	var t_para: float = -1.0
	while reloj.t - t5 < 12.0:
		await process_frame
		pico5 = maxf(pico5, mol.velocidad)
		activo5 = activo5 or mol.activo
		if t_para < 0.0 and pico5 > 0.5 and mol.velocidad == 0.0:
			t_para = reloj.t - t5
	_ok("5.1 con hechizo=no el golpe la mueve (ω > 0)", pico5 > 0.5, "pico %.2f rad/s" % pico5)
	_ok("5.2 con hechizo=no `girando` NO salta (ni activo ni señal)", not activo5 and _senales.is_empty(), str(_senales))
	_ok("5.3 el empujón es corto: se para solo", t_para > 0.0, "parada a los %.1f s" % t_para)
	mol.on_spell_hit(agua, Vector3(0.0, 0.0, 1.0))
	await avanzar(6)
	_ok("5.4 el golpe hacia +Z (con el agua) da ω < 0: las palas de abajo van hacia +Z (ω %.2f)" % mol.velocidad, mol.velocidad < -0.3 and not mol.activo)
	mol.hechizo = true

	# --- 6 · el sentido de una rueda NO vertical (eje N-S, giro 90° en Y): el chorro hacia −X las lleva hacia −X ---
	var mo2 := Molino3D.new()
	mo2.hechizo = true
	mo2.preparar(Vector2i(26, 3), 0.3, false)
	maqueta.add_child(mo2)
	await avanzar(2)
	mo2.on_spell_hit(agua, Vector3(-1.0, 0.0, 0.0))
	await avanzar(10)
	var r2: Node3D = mo2.rueda()
	var q0: Vector3 = r2.global_position + Vector3(0.0, -Molino3D.RADIO, 0.0)
	var ml: Vector3 = r2.global_transform.affine_inverse() * q0
	await avanzar(2)
	var q1: Vector3 = r2.global_transform * ml
	_ok("6.1 rueda no vertical: el chorro hacia −X lleva la pala de abajo hacia −X (ω > 0, desplazamiento x %.4f)" % (q1.x - q0.x), mo2.velocidad > 0.0 and (q1.x - q0.x) < -0.001)
	mo2.queue_free()
