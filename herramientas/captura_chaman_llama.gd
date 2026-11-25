extends "res://herramientas/escenario_base.gd"
## Capturas de la LLAMA DE VENENO del chamán (25/11/2026, enemigos/chaman_3d.gd + presentacion/vfx/bloques/bloques_vfx.gd) en su sala (PruebaSalaChaman): la llama en la punta del bastón
## mientras carga, la flecha de veneno en vuelo con su estela y la estela que se apaga al llegar. Para MIRARLO, no es una prueba.
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_chaman_llama.gd -- [carpeta]
## Salida por defecto en res://output/chaman_llama_2026-11-25/llama_*.png

var _dir: String = "res://output/chaman_llama_2026-11-25"
var _cam: Camera3D = null
var _ch: Chaman3D = null


func _foto(nombre: String) -> void:
	# cámara propia sobre el chamán, con la inclinación del juego (60°), algo más cerca
	var foco: Vector3 = _ch.global_position + Vector3(-0.8, 0.5, 0.0)
	var inc: float = deg_to_rad(60.0)
	_cam.look_at_from_position(foco + Vector3(0.0, sin(inc), cos(inc)) * 4.0, foco)
	_cam.current = true
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("llama_" + nombre + ".png"))
	print("foto " + nombre)


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaChaman.tscn", true)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ch = z.nodo("chaman_a") as Chaman3D
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
	var hechas: Dictionary = {}
	while t < 45.0 and not hechas.has("apagandose"):
		await avanzar(1)
		t += 1.0 / 30.0
		j.position.x += 0.02 * sin(t * 3.0)             # que se mueva un poco: así el chamán tira flechas y no la bola
		if _ch.c_estado == "lanzando" and _ch.llama_baston != null and not hechas.has("carga"):
			hechas["carga"] = true
			for k in 4:
				await avanzar_s(0.1)
				var ll: Node3D = _ch.llama_baston
				print("carga %d: chamán %s · llama %s · dentro del árbol %s" % [k, _ch.global_position, ll.global_position if ll != null and is_instance_valid(ll) else "—",
					ll.is_inside_tree() if ll != null and is_instance_valid(ll) else false])
				await _foto("1_carga_baston_%d" % k)
		var f: Node3D = _ch.ultima_flecha
		if f != null and is_instance_valid(f) and not hechas.has("vuelo"):
			await avanzar_s(0.12)
			hechas["vuelo"] = true
			if is_instance_valid(f):
				await _foto("2_flecha_en_vuelo")
		elif hechas.has("vuelo") and not hechas.has("apagandose") and (f == null or not is_instance_valid(f)):
			await avanzar_s(0.1)
			hechas["apagandose"] = true
			await _foto("3_estela_apagandose")
	print("hechas: ", hechas.keys(), " en ", _dir)
	quit(0)
