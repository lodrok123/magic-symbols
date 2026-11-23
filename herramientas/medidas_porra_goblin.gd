extends SceneTree
## 21/11 (Pablo: «acércala a que la sujete desde la mano»): dónde poner la porra del goblin guerrero para que el mango quede en el PUÑO.
## El rig chibi no tiene huesos de dedos (28 huesos) y su hueso de la mano no apunta hacia los dedos, así que el puño se mide en la MALLA: el centro de los vértices
## que pesan sobre todo en RightHand, llevados al espacio de ese hueso con su pose de enlace (bind). Ese punto es el que va en GARROTE_POS de Equipo3D.
##   godot --headless --path . --script res://herramientas/medidas_porra_goblin.gd

const HUESO: String = "mixamorig_RightHand"
const PESO_MIN: float = 0.6                     ## un vértice cuenta como «de la mano» si al menos este peso es de RightHand


func _initialize() -> void:
	var n: Node = (load("res://arte/modelos/goblin_warrior_chibi.glb") as PackedScene).instantiate()
	root.add_child(n)
	await process_frame
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	var hb: int = sk.find_bone(HUESO)
	var suma := Vector3.ZERO
	var cuenta: int = 0
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or m.skin == null:
			continue
		var skin: Skin = m.skin
		# Qué índice de bind corresponde a la mano
		var bind_mano: int = -1
		for b in skin.get_bind_count():
			var nombre: String = String(skin.get_bind_name(b))
			if nombre == HUESO or (nombre == "" and skin.get_bind_bone(b) == hb):
				bind_mano = b
		if bind_mano < 0:
			continue
		var bind_pose: Transform3D = skin.get_bind_pose(bind_mano)     # malla → espacio del hueso
		for s in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				continue
			var k: int = bones.size() / vs.size()
			for i in vs.size():
				var w: float = 0.0
				for j in k:
					if bones[i * k + j] == bind_mano:
						w += pesos[i * k + j]
				if w >= PESO_MIN:
					var p: Vector3 = bind_pose * vs[i]
					suma += p
					cuenta += 1
					minimo = minimo.min(p)
					maximo = maximo.max(p)
	if cuenta == 0:
		print("no hay vértices de la mano")
		quit(1)
		return
	var centro: Vector3 = suma / float(cuenta)
	# Equipo3D divide la posición de EQUIPO por la escala del esqueleto respecto al modelo: la posición a poner es la del hueso × esa escala.
	var escala: float = 1.0
	var x: Node = sk
	while x != null and x != n:
		if x is Node3D:
			escala *= (x as Node3D).scale.y
		x = x.get_parent()
	print("escala del esqueleto respecto al modelo: %.4f → GARROTE_POS = Vector3(%.3f, %.3f, %.3f)" % [escala, centro.x * escala, centro.y * escala, centro.z * escala])
	print("vértices de la mano: %d" % cuenta)
	print("caja de la mano en el espacio del hueso: ", minimo, " .. ", maximo)
	print("centro del puño en el espacio del hueso (sin escala del modelo): Vector3(%.3f, %.3f, %.3f)" % [centro.x, centro.y, centro.z])
	quit(0)
