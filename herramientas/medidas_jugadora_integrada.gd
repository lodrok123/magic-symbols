extends SceneTree
## MEDIDAS para integrar la jugadora nueva (jugadora_base) donde estaba la elfa (woodland_wanderer): altura de las manos en idle y en los clips de lanzar, y el punto de
## la espalda donde cuelga el grimorio (Hips). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_jugadora_integrada.gd

const IDS: Array = ["woodland_wanderer", "jugadora_base"]
const ROLES: Array = ["idle", "cast_proyectil", "cast_columna", "cast_corro", "cast_mano_frente", "cast_mano_alto", "cast_mano_suelo", "walk"]
const HUESOS: Array = ["Hips", "Spine2", "LeftHand", "RightHand", "Head"]
const MUESTRAS: int = 8


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	for id in IDS:
		var p := Pj3D.new()
		mundo.add_child(p)
		p.cargar(String(id))
		p.set_alto(1.0)
		await process_frame
		var sk: Skeleton3D = p._esqueleto()
		var esc: float = p.alto_modelo()
		print("== %s: alto %.3f escala %.3f huesos %d" % [id, esc, p.scale.y, sk.get_bone_count()])
		for h in HUESOS:
			var i: int = Equipo3D._hueso(sk, String(h))
			var g: Transform3D = sk.global_transform * sk.get_bone_global_rest(i)
			print("   reposo %-9s mundo %s  ejes X %s Y %s Z %s" % [h, _v(p.to_local(g.origin)), _v(g.basis.x.normalized()), _v(g.basis.y.normalized()), _v(g.basis.z.normalized())])
		# Espalda: la z mínima (hacia atrás, el personaje mira a +Z) de los vértices de la malla a la altura de la cadera.
		var cad: Vector3 = p.to_local(sk.global_transform * sk.get_bone_global_rest(Equipo3D._hueso(sk, "Hips")).origin)
		print("   cadera mundo local %s" % _v(cad))
		for rol in ROLES:
			var clip: String = p.clip_de(String(rol))
			if clip == "":
				print("   %-17s sin clip" % rol)
				continue
			var ap: AnimationPlayer = p._ap
			if p._arbol != null:
				p._arbol.active = false
			ap.active = true
			ap.play(clip)
			var largo: float = ap.get_animation(clip).length
			var altura_max_i: float = -INF
			var altura_max_d: float = -INF
			var al_i: Array = []
			var al_d: Array = []
			for k in MUESTRAS + 1:
				ap.seek(largo * float(k) / float(MUESTRAS), true)
				sk.force_update_all_bone_transforms()
				var li: Vector3 = p.to_local(p.posicion_mano("izquierda"))
				var ld: Vector3 = p.to_local(p.posicion_mano("derecha"))
				altura_max_i = maxf(altura_max_i, li.y)
				altura_max_d = maxf(altura_max_d, ld.y)
				al_i.append(snappedf(li.y, 0.01))
				al_d.append(snappedf(ld.y, 0.01))
			print("   %-17s (%s %.2fs) mano izq máx %.2f  der máx %.2f   izq %s  der %s" % [rol, clip, largo, altura_max_i, altura_max_d, al_i, al_d])
		p.queue_free()
		await process_frame
	quit(0)


func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
