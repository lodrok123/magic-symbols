extends SceneTree
## 26/11/2026 · Fotos de Monte Sumicio para comparar el suelo ANTES y DESPUÉS de tocar los ajustes de juntas (presentacion/acabado_suelo.gd).
## NECESITA VENTANA. Cámara ortogonal a 60° como la del juego, seis vistas fijas:
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --script res://herramientas/captura_sumicio_juntas.gd -- <carpeta>
## Sin carpeta, deja las fotos en docs/capturas/bosque_generado_2026-11-26/sumicio_despues/. Se comparan pixel a pixel con `herramientas/comparar_capturas.py`.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = "res://docs/capturas/bosque_generado_2026-11-26/sumicio_despues"
	for a in args:
		dir = a
	var abs_dir: String = ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir
	DirAccess.make_dir_recursive_absolute(abs_dir)
	root.size = Vector2i(1280, 720)
	var escena: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	for i in 90:
		await process_frame
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).hide()
	# los ajustes del suelo que lleva el material (los valores de ANTES de unificarlos, 26/11: rugosidad 2,5 · relieve_hierba 0,4 · relieve_junta 0,4 ·
	# borde_extiende 1 · borde_fundido 1 · borde_fuerza 0 · mezcla_hierba 1,2 · borde_tinte (0,82, 0,87, 0,64))
	var mat: ShaderMaterial = escena._mat_suelo
	var linea: String = "SUELO:"
	for p in ["rugosidad", "relieve_hierba", "relieve_junta", "borde_extiende", "borde_fundido", "borde_fuerza", "mezcla_hierba", "borde_tinte"]:
		linea += " %s=%s" % [p, str(mat.get_shader_parameter(p))]
	print(linea)
	var maq := escena.get_node("Maqueta")
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	escena.add_child(cam)
	cam.current = true
	var dir_cam := -Vector3(0.0, sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)))
	var porton: Node3D = maq.porton
	var torre: Node3D = maq.torre
	var casas: Array = maq.casas()
	var vistas := {
		"cancela": [porton.global_position + Vector3(0, 1, 0.8), 10.0],
		"palloza": [(casas[0] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"tienda": [(casas[3] as Node3D).global_position + Vector3(0, 1, 0.5), 9.0],
		"torre": [torre.global_position + Vector3(0, 1, 3.0), 12.0],
		"aldea": [torre.global_position + Vector3(0, 1, 9.0), 26.0],
		"aldea_sur": [torre.global_position + Vector3(0, 1, 22.0), 20.0],
	}
	for nombre in vistas:
		var v: Array = vistas[nombre]
		cam.size = float(v[1])
		cam.global_transform = Transform3D(Basis.looking_at(dir_cam, Vector3.UP), (v[0] as Vector3) - dir_cam * 20.0)
		for k in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var ruta := "%s/%s.png" % [abs_dir, nombre]
		root.get_texture().get_image().save_png(ruta)
		print("guardado ", ruta)
	quit()
