extends "res://herramientas/escenario_base.gd"
## EL TÓTEM CONTADOR EN TODOS LOS NIVELES (24/11/2026, Pablo: «sí, en todos»). Carga cada nivel con contadores de braseros, comprueba que todos salen
## como tótem (no la placa) y que Puzle3D no da avisos, y saca una foto de cerca de cada tótem para ver cómo encaja donde ya estaba la placa.
## Necesita ventana:   godot --path . --script res://herramientas/captura_totems_niveles.gd     → docs/capturas/totem/niveles/

const ESCENAS: Array[String] = ["res://escenas/PruebaBosque01.tscn", "res://escenas/PruebaBosque01_v01.tscn", "res://escenas/PruebaBosque02.tscn",
	"res://escenas/PruebaCueva.tscn", "res://escenas/PruebaCuevaResonante.tscn", "res://escenas/PruebaGrutaBatida.tscn", "res://laboratorios/LabPuzlesFuego3D.tscn"]
const DIR: String = "res://docs/capturas/totem/niveles"


func _escenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	root.get_window().size = Vector2i(1280, 720)
	# `-- desde=<n>` empieza por la escena n (0 = la primera): para repetir solo las que faltan.
	# `-- hasta=<n>` para antes de la escena n. Sin ventana (--headless) cuenta los tótems pero no hace fotos.
	var desde: int = 0
	var hasta: int = ESCENAS.size()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("desde="):
			desde = String(a).substr(6).to_int()
		if String(a).begins_with("hasta="):
			hasta = String(a).substr(6).to_int()
	var fotos: bool = DisplayServer.get_name() != "headless"
	for ruta in ESCENAS.slice(desde, hasta):
		if maqueta != null and is_instance_valid(maqueta):
			maqueta.get_parent().remove_child(maqueta)
			maqueta.queue_free()
			maqueta = null
			await avanzar(5)
		Flags.nuevo()
		Estado.nuevo()
		await cargar(ruta, false)
		if maqueta == null:
			continue
		var reglas: Node = maqueta.get_node_or_null("Reglas")
		if reglas != null and reglas.get("volver_al_menu") != null:
			reglas.set("volver_al_menu", false)      # como en prueba_rocas_empujables: el Bosque 02 volvía al menú y la prueba se quedaba colgada
		await avanzar_s(1.0)
		for cl in root.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
		var nombre: String = ruta.get_file().get_basename()
		var cts: Array = []
		for n in root.find_children("*", "", true, false):
			if n is ContadorReactivos3D and (n as ContadorReactivos3D).celda.x >= 0:
				cts.append(n)
		var totems: int = cts.filter(func(c) -> bool: return c.get("_totem") != null).size()
		_ok("%s: sus %d contadores son tótems" % [nombre, cts.size()], cts.size() > 0 and totems == cts.size(), "%d de %d" % [totems, cts.size()])
		var k: int = 0
		for ct in (cts if fotos else []):
			k += 1
			await _foto((ct as Node3D).global_position, "%s_%d.png" % [nombre, k])


func _foto(p: Vector3, nombre: String) -> void:
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 50.0
	maqueta.add_child(cam)
	cam.global_position = p + Vector3(0.0, 5.5, 7.5)
	cam.look_at(p + Vector3(0.0, 0.6, -0.6))
	cam.current = true
	await avanzar(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	cam.current = false
	if cam_juego != null and is_instance_valid(cam_juego):
		cam_juego.current = true
	cam.queue_free()
