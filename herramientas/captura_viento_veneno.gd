extends "res://herramientas/escenario_base.gd"
## Capturas del CAMPO DE VIENTO (VientoToy HAZ contra un goblin, sin y con campo) y de la NUBE DE VENENO como GAS PESADO (reposo con un goblin dentro, soplo, fuego con humo pardo),
## en PruebaSalaChaman con la inclinación de cámara del juego.
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_viento_veneno.gd
## Salida en res://docs/capturas/vfx_en_juego/viento_veneno/*.png

const DIR: String = "res://docs/capturas/vfx_en_juego/viento_veneno"

var _cam: Camera3D = null


func _foto(nombre: String, foco: Vector3, zoom: float = 5.5) -> void:
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
	_cam = Camera3D.new()
	_cam.fov = 38.0
	maqueta.add_child(_cam)
	var j: Jugador3D = jugador as Jugador3D
	_ocultar_interfaz(maqueta)
	var gob: Combate3D = null
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D:
			(n as Combate3D).quieto = true
			if gob == null and not (n is Chaman3D):
				gob = n
	colocar_jugador(Vector2i(12, 4))
	j.vida = 100000.0
	await avanzar_s(0.5)
	var suelo: Vector3 = j.position

	# 1 · haz de viento hacia un goblin: sin campo (atraviesa) y con campo (rodea y tiembla)
	if gob != null:
		gob.position = suelo + Vector3(0.0, 0.0, -2.0)
	var vt: VientoToy = VientoToy.new()
	maqueta.add_child(vt)
	vt.global_position = suelo + Vector3(0, 0, -0.4)
	vt.definir(VientoToy.Figura.HAZ, 1.5, 0.6, 0.18, false)
	vt.lanzar(-1.0)
	var foco: Vector3 = suelo + Vector3(0, 0.5, -1.6)
	CampoViento.en_viento_toy = false
	await avanzar_s(0.8)
	await _foto("01_haz_sin_campo", foco)
	CampoViento.en_viento_toy = true
	await avanzar_s(0.8)
	await _foto("02_haz_con_campo", foco)
	vt.queue_free()
	CampoViento.en_viento_toy = false

	# 2 · nube de veneno como gas pesado con el goblin dentro
	NubeVenenoVfx.gas_pesado = true
	NubeVenenoVfx.humo_al_arder = true
	j.position = suelo + Vector3(-4.0, 0, 3.0)
	var c: Vector3 = suelo + Vector3(0, 0, -1.0)
	if gob != null:
		gob.position = c + Vector3(1.0, 0.0, 0.3)
	var n: NubeVeneno3D = NubeVeneno3D.crear(maqueta, c, 0.0, 1.0, j)
	await avanzar_s(2.5)
	await _foto("03_veneno_pesado_reposo", c + Vector3(0, 0.3, 0))
	n.soplar(Vector3(1, 0, 0))
	await avanzar_s(0.9)
	await _foto("04_veneno_pesado_viento", n.global_position + Vector3(-0.5, 0.3, 0))
	await avanzar_s(1.5)
	n.quemar(4.0)
	await avanzar_s(1.6)
	await _foto("05_veneno_arde_humo", n.global_position + Vector3(0, 0.6, 0), 6.5)
	NubeVenenoVfx.gas_pesado = false
	NubeVenenoVfx.humo_al_arder = false
