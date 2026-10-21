extends SceneTree
## Capturas CON VENTANA (camara del juego) del enganche de logros/reacciones en el Bosque 01 (diario 245). Sin --headless:
##     godot --path . --resolution 1280x720 -s res://herramientas/captura_enganche_logros.gd
## Guarda en res://docs/capturas/enganche_logros/: reaccion_*.png (vapor + hundido) y nivel_completado_*.png (celebracion a 0,3 s / 1,0 s / 2,0 s).
const SALIDA: String = "res://docs/capturas/enganche_logros/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var m: Node3D = (load("res://escenas/PruebaBosque01.tscn") as PackedScene).instantiate()
	m.set("usar_escena", true)
	root.add_child(m)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 or not _puede(m):          # velo de precalentado
		await process_frame
		if Time.get_ticks_msec() - t0 > 40000:
			break
	for _i in 60:
		await process_frame
	var pj: Node3D = m.get("_jugador") as Node3D
	var p: Vector3 = pj.position
	# Reacciones: vapor (apagado por agua) y hundimiento, a los pies del jugador.
	Mundo3D.avisar_reaccion("apagado_agua", p + Vector3(0.0, 0.3, 0.0), null)
	await _real(0.35)
	_guardar("reaccion_vapor_0")
	await _real(0.5)
	Mundo3D.avisar_reaccion("hundido", p + Vector3(1.2, 0.0, 0.0), null)
	await _real(0.4)
	_guardar("reaccion_hundido_0")
	await _real(1.5)
	# Celebracion de nivel completado.
	Mundo3D.avisar_logro("nivel_completado", p + Vector3.UP, pj)
	await _real(0.5)
	_guardar("nivel_completado_0")
	await _real(0.5)
	_guardar("nivel_completado_1")
	await _real(1.5)
	_guardar("nivel_completado_2")
	print("capturas en ", ProjectSettings.globalize_path(SALIDA))
	quit()


func _puede(m: Node) -> bool:
	var j: Variant = m.get("_jugador")
	return j != null and get_first_node_in_group("spellcaster") != null and (get_first_node_in_group("spellcaster") as Lanzador3D).jugador != null \
		and (get_first_node_in_group("spellcaster") as Lanzador3D).jugador.puede_lanzar()


func _real(s: float) -> void:
	var t: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t) / 1000.0 < s:
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(SALIDA + nombre + ".png"))
