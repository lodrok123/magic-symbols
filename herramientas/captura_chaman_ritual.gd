extends SceneTree
## Capturas del chamán (ritual, runa, onda, bola de veneno, andar con bastón) en docs/capturas/chaman_rig/. NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_chaman_ritual.gd
## Usa la escena PruebaChaman (cámara del juego, `_juego`) y una cámara más cercana para los detalles (`_cerca`). Cada momento del ritual se prepara de cero y se espera el tiempo exacto.

const DIR: String = "res://docs/capturas/chaman_rig"
var _esc: Node3D = null
var _cam2: Camera3D = null


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	_esc = (load("res://escenas/PruebaChaman.tscn") as PackedScene).instantiate()
	root.add_child(_esc)
	await process_frame
	_cam2 = Camera3D.new()
	_cam2.fov = 20.0
	_esc.add_child(_cam2)
	DirAccess.make_dir_recursive_absolute(DIR)
	# andar con bastón
	_esc.alternar_andar()
	await _esperar(1.3)
	await _cerca("andar_baston", Vector3(1.2, 0.8, 2.0), true)
	await _esperar(0.9)
	await _cerca("andar_baston_2", Vector3(1.2, 0.8, 2.0), true)
	_esc.alternar_andar()
	await _esperar(0.5)
	# momentos del ritual
	var momentos: Array = [[0.62, "trazo_25"], [1.25, "trazo_50"], [1.9, "trazo_75"], [2.3, "trazo_100"],
		[AnimacionesChaman.DUR_TRAZAR + 0.30, "clavar_alzado"], [AnimacionesChaman.DUR_TRAZAR + AnimacionesChaman.INSTANTE_CLAVAR + 0.15, "clavar_onda"],
		[AnimacionesChaman.DUR_TRAZAR + AnimacionesChaman.INSTANTE_CLAVAR + 0.45, "clavar_onda_2"]]
	for m in momentos:
		_esc.interrumpir()
		await _esperar(1.0)
		_esc.empezar_bucle()
		await _esperar(float(m[0]) - 0.1)
		await _juego(String(m[1]) + "_juego")
		if String(m[1]).begins_with("trazo") or String(m[1]) == "clavar_alzado":
			await _cerca(String(m[1]) + "_cerca", Vector3(1.3, 0.9, 1.4), false)
	# interrumpido
	_esc.interrumpir()
	await _esperar(1.0)
	_esc.empezar_bucle()
	await _esperar(1.6)
	_esc.interrumpir()
	await _esperar(0.25)
	await _juego("interrumpido_juego")
	# bola de veneno en vuelo
	await _esperar(1.0)
	_esc.lanzar_bola()
	await _esperar(AnimacionesChaman.INSTANTE_LANZAR + 0.45)
	await _juego("bola_veneno_vuelo_juego")
	quit(0)


func _esperar(s: float) -> void:
	for i in maxi(int(round(s * 30.0)), 1):
		await process_frame


func _juego(nombre: String) -> void:
	_esc._cam.current = true
	for i in 2:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)


func _cerca(nombre: String, desde: Vector3, sigue: bool) -> void:
	var foco: Vector3 = (_esc.chaman.global_position if sigue else Vector3.ZERO) + Vector3(0.0, 0.4, 0.25)
	_cam2.look_at_from_position(foco + desde, foco)
	_cam2.current = true
	for i in 2:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)
	_esc._cam.current = true
