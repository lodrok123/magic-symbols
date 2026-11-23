extends "res://herramientas/escenario_base.gd"
## C17 (22/11, Mystralia O9): FEEDBACK DE CUERPO GRANDE. El temblor largo es para lo que hace el cuerpo grande (caer, golpear el suelo, levantarse).
## Comprueba en la Sala del Gólem que el gólem pide `Sensacion3D.temblor_cuerpo_grande` al caer tumbado y otra vez al levantarse, y que la cámara se mueve de verdad.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cuerpo_grande.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var a: Golem3D = z.nodo("golem_a") as Golem3D if z != null else null
	_ok("0 hay gólem en la sala", a != null)
	if a == null:
		return
	a.quieto = true
	(jugador as Jugador3D).vida = 100000.0
	await avanzar(10)
	var cam: Camera3D = get_root().get_viewport().get_camera_3d()
	var n0: int = int(Sensacion3D.cuenta.get("cuerpo_grande", 0))

	# --- Cae tumbado ---
	a._parar_resbalon()
	_ok("1 al caer tumbado pide el temblor de cuerpo grande", int(Sensacion3D.cuenta.get("cuerpo_grande", 0)) == n0 + 1)
	_ok("1 la cámara está temblando", cam != null and cam.has_meta("temblor_base"))
	var max_desp: float = 0.0
	var base: Vector2 = cam.get_meta("temblor_base", Vector2.ZERO) if cam != null else Vector2.ZERO
	var t: float = 0.0
	while t < 0.5:
		t += await avanzar_s(1.0 / 30.0)
		if cam != null:
			max_desp = maxf(max_desp, Vector2(cam.h_offset, cam.v_offset).distance_to(base))
	var tope: float = Sensacion3D.TEMBLOR_CUERPO_GRANDE * Vfx3D.FUERZA_TEMBLOR_MAX
	_ok("1 el desplazamiento máximo no pasa del tope (%.3f u; %.3f por eje, %.3f en diagonal)" % [max_desp, tope, tope * sqrt(2.0)], max_desp > 0.0 and max_desp <= tope * 1.01 * sqrt(2.0))
	_ok("1 la cámara vuelve al centro", cam != null and not cam.has_meta("temblor_base") and Vector2(cam.h_offset, cam.v_offset).distance_to(base) < 0.001)

	# --- Se levanta ---
	await avanzar_s(Golem3D.T_TUMBADO + 0.3)
	_ok("2 se levanta tras T_TUMBADO y pide otro temblor", int(Sensacion3D.cuenta.get("cuerpo_grande", 0)) == n0 + 2, a.g_estado)

	# --- El puñetazo del elemental contra el suelo ---
	var pos_e: Vector3 = jugador.position + Vector3(4.0, 0.0, 0.0)
	var e: Combate3D = Combate3D.invocar_elemental(maqueta.get("mundo") if maqueta.get("mundo") is Node3D else jugador.get("mundo"), jugador as Jugador3D, lanzador, pos_e)
	_ok("4 se invoca un elemental", e != null)
	if e != null:
		await avanzar(5)
		var n1: int = int(Sensacion3D.cuenta.get("cuerpo_grande", 0))
		e._golpe_elemental()
		_ok("4 su puñetazo contra el suelo pide el temblor de cuerpo grande", int(Sensacion3D.cuenta.get("cuerpo_grande", 0)) == n1 + 1)

	# --- Apagado ---
	Sensacion3D.ACTIVA = false
	_ok("3 con Sensacion3D apagada no hace nada", not Sensacion3D.temblor_cuerpo_grande(a))
	Sensacion3D.ACTIVA = true
