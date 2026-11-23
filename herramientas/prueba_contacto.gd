extends "res://herramientas/escenario_base.gd"
## B2 de docs/PLAN_COMBATE_2026-11-22.md (C19 + C10 + C20, 22/11): la TABLA DE CONTACTO barrera × proyectil (`nucleo/contacto.gd`) en el juego de verdad.
##   · la tabla dice lo aprobado (fuego quema la flecha, agua la frena, tierra la para; la flecha ardiendo cruza el fuego; el fuego no para el fuego…);
##   · una flecha enemiga contra una barrera de cada elemento hace lo de su celda: se detiene (y no hiere) o la cruza sin gastarla (y sigue);
##   · la burbuja (C10, Pablo): las flechas rebotan en la de agua/tierra/viento y se queman en la de fuego; la burbuja NO revienta;
##   · el aliento del dragón: la barrera de fuego no lo corta, la de agua y la de tierra sí.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_contacto.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaDragon.tscn"


func _flecha(ardiendo: bool = false) -> Node3D:
	var f := Node3D.new()
	f.name = "FlechaPrueba"
	maqueta.add_child(f)
	if ardiendo:
		f.set_meta("ardiendo", true)
	return f


func _quitar_barreras() -> void:
	for s in lanzador._solideces_v2:
		if is_instance_valid(s):
			(s as Node).queue_free()
	lanzador.barreras_vivas.clear()
	await avanzar(2)


## Levanta una barrera de `elemento` en la casilla de la jugadora y tira una flecha contra ella. Devuelve {accion, parada, gastada}.
func _contra_barrera(elemento: String, ardiendo: bool) -> Dictionary:
	await _quitar_barreras()
	colocar_jugador(Vector2i(4, 4))
	await avanzar(2)
	lanzar(elemento, ["barrera"], Vector3(1, 0, 0))
	await avanzar_s(0.4)
	var p: Vector3 = jugador.position + Vector3(0, 0.8, 0)
	var s: Lanzador3D.SolidezV2 = lanzador.solidez_en(p)
	if s == null:
		return {"accion": "SIN BARRERA", "parada": false, "gastada": false}
	var aguante0: float = s.aguante
	var f: Node3D = _flecha(ardiendo)
	f.position = p
	var acc: String = Contacto.flecha_en(lanzador, f, p, p - Vector3(1, 0, 0), Combate3D.DANO_FLECHA, maqueta)
	var r: Dictionary = {"accion": acc, "parada": f.has_meta("parada"), "gastada": is_instance_valid(s) and s.aguante < aguante0, "elemento_barrera": s.elemento}
	if is_instance_valid(f) and not f.has_meta("parada"):
		f.queue_free()
	return r


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	(jugador as Jugador3D).vida = 100000.0
	# --- 1 · la tabla ---
	_ok("1 tabla: el fuego quema la flecha", Contacto.accion("fuego", "flecha") == "quema")
	_ok("1 tabla: la flecha ardiendo cruza el fuego (ineficaz)", Contacto.accion("fuego", "flecha_ardiendo") == "pasa" and not Contacto.protege("pasa"))
	_ok("1 tabla: el fuego no para el fuego (lanzallamas)", Contacto.accion("fuego", "fuego") == "pasa")
	_ok("1 tabla: el agua frena la flecha y apaga el fuego", Contacto.accion("agua", "flecha") == "frena" and Contacto.accion("agua", "fuego") == "apaga")
	_ok("1 tabla: la piedra pasa por el agua (ineficaz)", Contacto.accion("agua", "piedra") == "pasa")
	_ok("1 tabla: la tierra lo para todo", Contacto.accion("tierra", "flecha") == "para" and Contacto.accion("tierra", "fuego") == "para" and Contacto.accion("tierra", "piedra") == "para")
	_ok("1 tabla: lo que pasa no gasta la barrera; el vapor la gasta más", Contacto.gasto("pasa", 12.0) == 0.0 and Contacto.gasto("vapor", 12.0) > 12.0)
	_ok("1 burbuja (C10): la flecha rebota en agua, tierra y viento y se quema en fuego", Contacto.accion("agua", "flecha", true) == "rebota" and Contacto.accion("tierra", "flecha", true) == "rebota"
		and Contacto.accion("viento", "flecha", true) == "rebota" and Contacto.accion("fuego", "flecha", true) == "quema")
	_ok("1 tabla (luz, 22/11, base de la luz de puzles): el agua la refleja, la tierra la para, el fuego la deja pasar; reflejar no gasta",
		Contacto.accion("agua", "luz") == "refleja" and Contacto.accion("agua", "luz", true) == "refleja" and Contacto.accion("tierra", "luz") == "para"
		and Contacto.accion("fuego", "luz") == "pasa" and Contacto.protege("refleja") and Contacto.gasto("refleja", 10.0) == 0.0)
	# --- 2 · flechas contra barreras de verdad ---
	var casos: Array = [["fuego", false, "quema", true], ["fuego", true, "pasa", false], ["agua", false, "frena", true], ["agua", true, "apaga", true], ["tierra", false, "para", true]]
	for c in casos:
		var r: Dictionary = await _contra_barrera(String(c[0]), bool(c[1]))
		var esperado: String = String(c[2])
		var para: bool = bool(c[3])
		_ok("2 flecha%s contra barrera de %s → %s" % [" ardiendo" if bool(c[1]) else "", c[0], esperado], String(r["accion"]) == esperado and bool(r["parada"]) == para
			and (bool(r["gastada"]) == para or esperado == "apaga"), str(r))
	await _quitar_barreras()
	# --- 3 · burbuja ---
	for el in ["agua", "fuego"]:
		colocar_jugador(Vector2i(6, 4))
		await avanzar(2)
		var rune: RuneData = load("res://nucleo/%s_rune.tres" % ("water" if el == "agua" else "fire")) as RuneData
		var b: Lanzador3D.Burbuja = lanzador.levantar_burbuja(rune, el)
		await avanzar(2)
		var pb: Vector3 = b.centro()
		var f: Node3D = _flecha()
		f.position = pb
		var acc: String = Contacto.flecha_en(lanzador, f, pb, pb - Vector3(1, 0, 0), Combate3D.DANO_FLECHA, maqueta)
		var esperado_b: String = "rebota" if el == "agua" else "quema"
		_ok("3 burbuja de %s: la flecha %s y la burbuja NO revienta" % [el, "rebota" if el == "agua" else "se quema"], acc == esperado_b and f.has_meta("parada") and not b.reventada, "acción %s · reventada %s" % [acc, b.reventada])
		if is_instance_valid(b):
			b.queue_free()
		lanzador._barrera_activa = null
		await avanzar_s(1.0)
	# --- 4 · el aliento del dragón contra barreras ---
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var dr: DragonJefe3D = z.nodo("dragon") as DragonJefe3D if z != null else null
	if dr != null:
		var o: Vector3 = dr.global_position + Vector3(0, 1.5, 0)
		var cel_j := Vector2i(8, 4)
		var dj: Vector3 = Terreno3D.centro_de(cel_j, Terreno3D.y_pies(cel_j)) - o
		dj.y = 0.0
		dj = dj.normalized()
		var sin_nada: float = dr.largo_aliento_u(o, dj)
		for el in ["fuego", "agua", "tierra"]:
			await _quitar_barreras()
			colocar_jugador(cel_j)
			await avanzar(2)
			lanzar(el, ["barrera"], Vector3(1, 0, 0))
			await avanzar_s(0.4)
			var largo: float = dr.largo_aliento_u(o, dj)
			var corta: bool = largo < sin_nada - 0.01
			_ok("4 aliento contra barrera de %s: %s" % [el, "NO la corta (el fuego no para el fuego)" if el == "fuego" else "la corta"], corta == (el != "fuego"),
				"largo %.2f de %.2f" % [largo, sin_nada])
