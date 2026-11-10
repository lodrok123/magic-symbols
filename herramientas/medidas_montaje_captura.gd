extends SceneTree
## ¿La hoja de capturas enseña la misma altura que el juego? La captura monta el GLB a mano (ClipsFamilia.clips_para sobre la
## escena del GLB) y el juego lo monta con Pj3D, que además apoya el modelo en el suelo y le pone sus modificadores. Si las dos
## no dan lo mismo, la hoja miente sobre si el personaje pisa o se hunde, y no sirve para juzgar el tope de hundimiento.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_montaje_captura.gd -- <id> [clip]
## Imprime, para cada instante, la suela más baja de los dos montajes en fracción del alto.

const MUESTRAS: int = 8
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "santa_compana_vela"
	var clip: String = args[1] if args.size() > 1 else "Dead"
	var glb: String = String(Pj3D.MODELO_DE.get(id, id))

	# A) como la CAPTURA: la escena del GLB tal cual, con los clips de ClipsFamilia.
	var modelo: Node3D = (load("res://arte/modelos/%s.glb" % glb) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk_a: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame
	var clave: String = id if ClipsFamilia.tiene_fuente(id) else glb
	var todos: Dictionary = ClipsFamilia.clips_para(clave, modelo, sk_a)
	if not todos.has(clip):
		print("no hay clip ", clip, " en ", todos.keys())
		quit(1)
		return
	var ap_a := AnimationPlayer.new()
	modelo.add_child(ap_a)
	var lib := AnimationLibrary.new()
	lib.add_animation(clip, todos[clip] as Animation)
	ap_a.add_animation_library("", lib)
	var alto_a: float = _alto_malla(modelo)

	# B) como el JUEGO: Pj3D.
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar(id)
	pj.set_alto(1.0)
	await process_frame
	var sk_b: Skeleton3D = (pj.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var ap_b: AnimationPlayer = pj._ap
	if pj._arbol != null:
		pj._arbol.active = false
	ap_b.active = true
	var alto_b: float = pj.alto_modelo() * pj.scale.y

	var largo: float = (todos[clip] as Animation).length
	print("%s · %s · alto captura %.3f, alto juego %.3f" % [id, clip, alto_a, alto_b])
	print("    t       captura    juego     diferencia")
	for k in range(MUESTRAS):
		var t: float = largo * float(k) / float(MUESTRAS)
		ap_a.play(clip)
		ap_a.seek(t, true)
		ap_b.play(clip)
		ap_b.seek(t, true)
		await process_frame
		sk_a.force_update_all_bone_transforms()
		sk_b.force_update_all_bone_transforms()
		var a: float = _suela(sk_a, Vector3.ZERO) / alto_a
		var b: float = _suela(sk_b, pj.global_position) / alto_b
		print("    %.2f   %+.3f     %+.3f    %+.3f" % [t, a, b, a - b])
	quit(0)


func _alto_malla(n: Node3D) -> float:
	var caja := AABB()
	var primero: bool = true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var c: AABB = mi.global_transform * mi.get_aabb()
		caja = c if primero else caja.merge(c)
		primero = false
	return caja.size.y if not primero else 1.0


func _suela(sk: Skeleton3D, origen: Vector3) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, (sk.global_transform * sk.get_bone_global_pose(i).origin).y - origen.y)
				break
	return m if m != INF else 0.0
