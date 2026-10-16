extends SceneTree
## Comprueba el cálculo del diorama (distancia al jugador, zona nítida) sin ventana: el desenfoque en sí solo se ve en Forward+.
func _initialize() -> void:
	var esc: PackedScene = load("res://escenas/PruebaBosque.tscn")
	var m: Node3D = esc.instantiate()
	root.add_child(m)
	for _i in 30:
		await process_frame
	var dof: CameraAttributesPractical = m.get("_camara_dof")
	print("metodo de render: ", RenderingServer.get_current_rendering_method())
	print("far activo: ", dof.dof_blur_far_enabled, "  distancia: %.2f  transicion: %.2f  cantidad: %.3f" % [dof.dof_blur_far_distance, dof.dof_blur_far_transition, dof.dof_blur_amount])
	var cam: Camera3D = m.get("_camara")
	print("tam camara: %.1f  distancia camara→foco: %.2f" % [cam.size, (m.get("_foco") - cam.global_position).length()])
	m.set("diorama", false)
	for _i in 3:
		await process_frame
	print("tras apagar: far activo = ", dof.dof_blur_far_enabled)
	m.set("diorama", true); m.set("_tam_camara", 30.0)
	for _i in 3:
		await process_frame
	print("zoom 30: distancia %.2f transicion %.2f" % [dof.dof_blur_far_distance, dof.dof_blur_far_transition])
	quit()
