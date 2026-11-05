extends "res://herramientas/escenario_base.gd"
## Capturas de la NUBE DE VENENO EN EL JUEGO (PruebaSalaChaman, cámara con la inclinación del juego): la bola del chamán que cae y deja la nube con la jugadora y un goblin dentro (y el estallido de
## hojas encima), una nube que dura, el viento soplándola y el fuego consumiéndola.
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_nube_veneno.gd
## Salida en res://docs/capturas/vfx_en_juego/nube_veneno/*.png

const DIR: String = "res://docs/capturas/vfx_en_juego/nube_veneno"

var _cam: Camera3D = null
var _ch: Chaman3D = null


func _foto(nombre: String, foco: Vector3, zoom: float = 5.0) -> void:
	var inc: float = deg_to_rad(52.0)
	_cam.look_at_from_position(foco + Vector3(-cos(inc) * zoom * 0.35, sin(inc) * zoom, cos(inc) * zoom), foco)
	_cam.current = true
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_interfaz(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		else:
			_ocultar_interfaz(h)


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaChaman.tscn", true)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ch = z.nodo("chaman_a") as Chaman3D
	_cam = Camera3D.new()
	_cam.fov = 38.0
	maqueta.add_child(_cam)
	var j: Jugador3D = jugador as Jugador3D
	_ocultar_interfaz(maqueta)
	_ch.quieto = true
	var gob: Combate3D = null
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D):
			(n as Combate3D).quieto = true
			if gob == null:
				gob = n
	colocar_jugador(Vector2i(12, 4))
	j.vida = 100000.0
	await avanzar_s(0.5)
	var suelo: Vector3 = j.position
	# el goblin, junto a la jugadora (dentro del radio de la nube)
	if gob != null:
		gob.position = suelo + Vector3(1.3, 0.0, -0.6)
	var foco: Vector3 = suelo + Vector3(0.5, 0.3, 0.0)

	# 1 · la bola del chamán cae sobre la jugadora y deja la nube (3 s)
	var ori: Vector3 = suelo + Vector3(-4.0, 3.0, -4.0)
	var b: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, ori, suelo, _ch, j, lanzador)
	while not b.llego:
		await avanzar(1)
	var marcas: Array = [0.1, 0.4, 0.9, 1.6, 2.3, 2.8]
	var antes: float = 0.0
	for m in marcas:
		await avanzar_s(float(m) - antes)
		antes = float(m)
		await _foto("01_bola_%03d" % int(float(m) * 100.0), foco)
	await avanzar_s(1.5)

	# 2 · una nube que dura (vida 14 s), con la jugadora y el goblin dentro
	var n2: NubeVeneno3D = NubeVeneno3D.crear(maqueta, suelo, 14.0, 1.0, j)
	await avanzar_s(1.6)
	await _foto("02_nube_vive_a", foco)
	await avanzar_s(0.9)
	await _foto("02_nube_vive_b", foco)
	await _foto("02_nube_vive_lejos", foco, 9.0)

	# 3 · el viento la empuja (hacia la derecha de la pantalla)
	n2.soplar(Vector3(1, 0, 0.3))
	var pasos: Array = [0.25, 0.6, 1.0, 1.6, 2.4]
	antes = 0.0
	for m in pasos:
		await avanzar_s(float(m) - antes)
		antes = float(m)
		await _foto("03_viento_%03d" % int(float(m) * 100.0), n2.global_position + Vector3(0.2, 0.3, 0.0))
	n2.retirar()
	await avanzar_s(0.3)

	# 4 · el fuego la consume
	var n3: NubeVeneno3D = NubeVeneno3D.crear(maqueta, suelo, 14.0, 1.0, j)
	await avanzar_s(2.0)
	n3.quemar(4.0)
	pasos = [0.2, 0.7, 1.4, 2.2, 3.0, 3.7]
	antes = 0.0
	for m in pasos:
		await avanzar_s(float(m) - antes)
		antes = float(m)
		await _foto("04_fuego_%03d" % int(float(m) * 100.0), foco)
	quit(0)