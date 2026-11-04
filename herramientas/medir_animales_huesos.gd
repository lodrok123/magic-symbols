extends SceneTree
## Lista los huesos y clips de los modelos de animal (ayuda de medir_animales.gd). Uso: godot --headless --path . --script res://herramientas/medir_animales_huesos.gd

func _initialize() -> void:
	for id in ["loberno", "canouro"]:
		var pj := Pj3D.new()
		root.add_child(pj)
		var ok: bool = pj.cargar(id)
		print("== %s ok=%s glb=%s" % [id, ok, Pj3D.glb_de(id)])
		if not ok:
			continue
		var sk: Skeleton3D = pj._modelo.find_children("*", "Skeleton3D", true, false)[0]
		var s: String = ""
		for i in sk.get_bone_count():
			var p: int = sk.get_bone_parent(i)
			s += "%d:%s(p%d) " % [i, sk.get_bone_name(i), p]
		print(s)
		for n in pj._ap.get_animation_list():
			var a: Animation = pj._ap.get_animation(n)
			print("clip %s len=%.3f tracks=%d" % [n, a.length, a.get_track_count()])
		print("alto_modelo=", pj.alto_modelo())
		print("clips roles: walk=%s run=%s idle=%s attack=%s hit=%s" % [pj.clip_de("walk"), pj.clip_de("run"), pj.clip_de("idle"), pj.clip_de("attack"), pj.clip_de("hit")])
	quit()
