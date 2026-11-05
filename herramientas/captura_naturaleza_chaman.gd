extends "res://herramientas/escenario_base.gd"
## Capturas del VFX de NATURALEZA del chamán goblin EN EL JUEGO (PruebaSalaChaman, cámara con la inclinación del juego): el brote del escudo cuando llega la onda, el escudo activo, un golpe,
## el escudo roto por golpes, el escudo quemado por fuego y la bola de veneno en vuelo y al caer.
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_naturaleza_chaman.gd
## Salida en res://docs/capturas/vfx_en_juego/naturaleza_chaman/*.png

const DIR: String = "res://docs/capturas/vfx_en_juego/naturaleza_chaman"

var _cam: Camera3D = null
var _ch: Chaman3D = null


func _foto(nombre: String, foco: Vector3, zoom: float = 4.0) -> void:
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
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and not (n is Chaman3D):
			(n as Combate3D).quieto = true
	colocar_jugador(Vector2i(12, 4))
	j.vida = 100000.0
	var t: float = 0.0
	while t < 15.0 and _ch.ritual == null:
		await avanzar_s(0.1)
		t += 0.1
	# 1 · el brote: en cuanto la onda deja el primer escudo, fotos a 0,15 / 0,45 / 1,0 s sobre ese goblin
	while t < 40.0 and _ch.escudos_dados < 1:
		await avanzar(1)
		t += 1.0 / 30.0
	var g: Combate3D = null
	for a in _ch.aliados(1000.0):
		if (a as Combate3D).escudo_natural != null:
			g = a
			break
	if g == null:
		print("no hay goblin escudado")
		quit(1)
		return
	var foco: Vector3 = g.position + Vector3(0, 0.35, 0)
	await _foto("01_brote_015", foco)
	await avanzar_s(0.3)
	await _foto("01_brote_045", foco)
	await avanzar_s(0.55)
	await _foto("01_brote_100", foco)
	await avanzar_s(1.0)
	await _foto("02_activo_a", foco)
	await avanzar_s(0.7)
	await _foto("02_activo_b", foco)
	# los escudos de todos
	await avanzar_s(2.0)
	await _foto("03_escudados_grupo", g.position + Vector3(1.0, 0.3, 0), 7.0)
	# 2 · un golpe que no lo rompe
	var e: EscudoNaturaleza3D = g.escudo_natural
	e.absorber(7.0, "")
	await _foto("04_golpe_00", foco)
	await avanzar_s(0.1)
	await _foto("04_golpe_10", foco)
	await avanzar_s(0.5)
	e.absorber(8.0, "")
	await avanzar_s(0.4)
	await _foto("05_menos_escudo", foco)
	# 3 · roto por golpes
	e.absorber(100.0, "")
	await _foto("06_roto_00", foco)
	await avanzar_s(0.25)
	await _foto("06_roto_25", foco)
	await avanzar_s(0.45)
	await _foto("06_roto_70", foco)
	await avanzar_s(0.8)
	await _foto("06_roto_150", foco)
	# 4 · quemado por fuego (otro escudo)
	var e2: EscudoNaturaleza3D = EscudoNaturaleza3D.poner(g)
	await avanzar_s(1.6)
	e2.absorber(5.0, "")
	await avanzar_s(0.3)
	e2.absorber(1.0, "fuego")
	await _foto("07_quemado_00", foco)
	await avanzar_s(0.25)
	await _foto("07_quemado_25", foco)
	await avanzar_s(0.45)
	await _foto("07_quemado_70", foco)
	await avanzar_s(0.8)
	await _foto("07_quemado_150", foco)
	# 5 · la bola de veneno
	var ori: Vector3 = _ch.position + Vector3(0, 1.0, 0)
	var dest: Vector3 = j.position + Vector3(3.0, 0.0, 1.5)
	var b: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, ori, dest, _ch, j, lanzador)
	var mitad: Vector3 = (ori + dest) * 0.5
	var k: int = 0
	var marcas: Array = [0.30, 0.55, 0.80]
	while not b.llego and k < marcas.size():
		await avanzar(1)
		if b.t / b.t_vuelo >= float(marcas[k]):
			await _foto("08_bola_vuelo_%d" % int(float(marcas[k]) * 100.0), b.global_position + Vector3(0, -0.3, 0), 3.4)
			k += 1
	while not b.llego:
		await avanzar(1)
	await _foto("09_bola_caida_00", dest, 5.0)
	await avanzar_s(0.2)
	await _foto("09_bola_caida_20", dest, 5.0)
	await avanzar_s(0.3)
	await _foto("09_bola_caida_50", dest, 5.0)
	await avanzar_s(0.5)
	await _foto("09_bola_caida_100", dest, 5.0)
	quit(0)
