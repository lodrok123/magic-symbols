extends SceneTree
## Capturas de la implementación real; no modifica progreso ni assets del juego.
func _initialize() -> void:
	await process_frame
	var lab := (load("res://laboratorios/LabCofresCeremonia3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for i in 8:
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/capturas/cofres_ceremonia")
	for calidad: String in ["epico", "legendario"]:
		lab.calidad = calidad
		lab.abrir_prueba()
		for capa in lab.get_children():
			if capa is CanvasLayer:
				capa.visible = false
		var seq: CeremoniaCofre3D = lab.secuencia
		var momentos: Array = [0.25, 1.65, 2.35] if calidad == "epico" else [0.25, 2.15, 2.85, 3.7]
		for cuando: float in momentos:
			while seq.t < cuando:
				if seq.esperando_input:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://docs/capturas/cofres_ceremonia/" + calidad + "_presentacion.png")
					seq.continuar()
				await process_frame
			await RenderingServer.frame_post_draw
			var ruta: String = "res://docs/capturas/cofres_ceremonia/%s_%03d.png" % [calidad, int(cuando * 100)]
			root.get_texture().get_image().save_png(ruta)
			print("CAPTURA ", ruta)
		seq.saltar()
	await process_frame
	quit()
