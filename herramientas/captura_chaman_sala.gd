extends "res://herramientas/escenario_base.gd"
## Capturas del chamán en SU SALA (PruebaSalaChaman, cámara del juego): el rombo a medio dibujar, completo, la onda con los guerreros escudados y una bola de veneno en vuelo.
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_chaman_sala.gd
## Salida en res://docs/capturas/chaman_rig/sala_*.png

const DIR: String = "res://docs/capturas/chaman_rig"


var _cam: Camera3D = null
var _ch: Chaman3D = null


func _foto(nombre: String) -> void:
	# cámara propia sobre el chamán (la del juego sigue a la jugadora, que está lejos): misma inclinación (60°) y zoom 7
	var foco: Vector3 = _ch.position + Vector3(-1.2, 0.3, 0.0)
	var inc: float = deg_to_rad(60.0)
	_cam.look_at_from_position(foco + Vector3(-sin(0.0) * cos(inc), sin(inc), 0.0) * 7.5 + Vector3(-3.0, 0.0, 0.0), foco)
	_cam.current = true
	for i in 2:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join("sala_" + nombre + ".png"))
	print("foto " + nombre)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaChaman.tscn", true)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var ch: Chaman3D = z.nodo("chaman_a") as Chaman3D
	_ch = ch
	_cam = Camera3D.new()
	_cam.fov = 40.0
	maqueta.add_child(_cam)
	var j: Jugador3D = jugador as Jugador3D
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D):
			(n as Combate3D).quieto = true
	colocar_jugador(Vector2i(12, 4))
	j.vida = 100000.0
	var t: float = 0.0
	while t < 15.0 and ch.ritual == null:
		await avanzar_s(0.1)
		t += 0.1
	var hechas: Dictionary = {}
	while t < 30.0 and ch.ultima_bola == null:
		await avanzar(1)
		t += 1.0 / 30.0
		var r: RunaSuelo3D = ch.ritual.runa if (ch.ritual != null and is_instance_valid(ch.ritual)) else null
		if r != null and is_instance_valid(r):
			if r.estado == "dibujando" and r.u_dibujado > 0.62 and not hechas.has("medias"):
				hechas["medias"] = true
				await _foto("rombo_a_medias")
			elif r.estado == "dibujando" and r.u_dibujado > 0.86 and not hechas.has("completo"):
				hechas["completo"] = true
				await _foto("rombo_completo")
			elif r.estado == "activa" and r.radio_onda > 1.8 and not hechas.has("onda"):
				hechas["onda"] = true
				await _foto("onda")
			elif r.estado == "activa" and r.radio_onda > 4.5 and not hechas.has("onda2"):
				hechas["onda2"] = true
				await _foto("onda_alcanza_guerreros")
		elif hechas.has("onda") and not hechas.has("escudados"):
			hechas["escudados"] = true
			await avanzar_s(0.3)
			await _foto("guerreros_escudados")
	# bola en vuelo
	var b: BolaVeneno3D = ch.ultima_bola
	if b != null:
		await avanzar_s(b.t_vuelo * 0.5)
		await _foto("bola_veneno_vuelo")
	quit(0)
