extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL TÓTEM CONTADOR (24/11/2026, Pablo: «un tótem que vaya encendiendo 3 símbolos» en vez de «ENCENDIDAS 3/3»).
## Carga PtFuego, va a la sala 2 (Tres braseros y un cofre), enciende los braseros uno a uno y saca el tótem de cerca con 0, 2 y 3 encendidos.
## Comprueba que no hay rótulo de texto, que tiene 3 símbolos y que se encienden con la cuenta. Necesita ventana:
##   godot --path . --script res://herramientas/captura_totem.gd
## Escribe en docs/capturas/totem/.

const RUTA: String = "res://escenas/PruebaPtFuego.tscn"
const DIR: String = "res://docs/capturas/totem"


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	root.get_window().size = Vector2i(1600, 900)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var ct: ContadorReactivos3D = null
	for n in maqueta.find_children("*", "", true, false):
		if n is ContadorReactivos3D and (n as ContadorReactivos3D).minimo == 3:
			ct = n
	_ok("hay un contador de 3 (sala 2)", ct != null)
	if ct == null:
		return
	_ok("es un tótem (sin rótulo de texto)", ct.get("_totem") != null and ct.get("_rotulo") == null)
	_ok("tiene 3 símbolos", (ct.get("_simbolos") as Array).size() == 3)
	var p: Vector3 = ct.global_position
	colocar_jugador(Terreno3D.celda_de(p) + Vector2i(0, 2))
	await avanzar_s(1.0)
	await _foto(p, "totem_0de3.png")
	for i in ct.lista.size():
		ct.lista[i].call("encender_llama")
		await avanzar_s(0.8)
		if i == 1:
			_ok("con 2 encendidos, 2 símbolos encendidos", _encendidos(ct) == 2, str(_encendidos(ct)))
			await _foto(p, "totem_2de3.png")
	await avanzar_s(0.8)
	_ok("con los 3, completo y los 3 símbolos encendidos", ct.completo and _encendidos(ct) == 3)
	await _foto(p, "totem_3de3.png")


func _encendidos(ct: ContadorReactivos3D) -> int:
	var n: int = 0
	for m in ct.get("_simbolos"):
		var c: Color = (m as ShaderMaterial).get_shader_parameter("color")
		n += 1 if c.r > 0.5 else 0
	return n


func _foto(p: Vector3, nombre: String) -> void:
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 45.0
	maqueta.add_child(cam)
	cam.global_position = p + Vector3(1.2, 3.4, 5.2)
	cam.look_at(p + Vector3(0.0, 0.9, -0.6))
	cam.current = true
	await avanzar(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	print("captura: ", nombre)
	cam.current = false
	if cam_juego != null:
		cam_juego.current = true
	cam.queue_free()
