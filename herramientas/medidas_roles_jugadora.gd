extends SceneTree
## Qué roles de clip resuelve cada versión de la jugadora (para ver qué le falta a la nueva frente a la elfa vieja). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_roles_jugadora.gd

const IDS: Array = ["woodland_wanderer", "jugadora_base"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var roles: Array = Pj3D.SINONIMOS.keys()
	for id in IDS:
		var p := Pj3D.new()
		mundo.add_child(p)
		p.cargar(String(id))
		var faltan: PackedStringArray = []
		for r in roles:
			if p.clip_de(String(r)) == "":
				faltan.append(String(r))
		print("%s: %d clips; roles sin clip: %s" % [id, p._ap.get_animation_list().size(), ", ".join(faltan)])
		p.queue_free()
		await process_frame
	quit(0)
