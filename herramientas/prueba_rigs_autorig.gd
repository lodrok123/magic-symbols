extends SceneTree
## PRUEBA de los rigs que salen de tools/autorig_fantasma.py: el fantasma elfo y la Santa Compaña.
##   godot --headless --path . --script res://herramientas/prueba_rigs_autorig.gd
## Fija lo que se corrigió el 10/11 (Pablo: «ambos están mal, revísalos»), midiendo los PESOS, que es donde nace cada defecto:
##   A · PIES      nada de lo que hay bajo el tobillo cuelga de la cadera ni de la columna. Con un 1,5-2,4 % de peso de Hips ahí,
##                 al dar una zancada salía un pico del talón hacia donde estaba el pie en reposo.
##   B · MANGAS    lo que rodea a la mano no cuelga de las piernas ni, salvo la capa, de la cadera. La bocamanga de la Santa Compaña
##                 heredaba el peso de la capa del donante y se quedaba en la cadera al subir el brazo.
##   C · ESQUELETO la muñeca está donde estaba. Regenerar el rig tocando cómo se mide el eje del brazo la subió 9 cm sin avisar
##                 (volvían los brazos estirados), y solo se vio comparando los huesos con los del GLB anterior.
##   D · LADOS     ningún vértice de un lado cuelga de huesos del otro.
## Cómo se VEN se mira en docs/capturas/<id>_poses/ (herramientas/captura_rig_fantasma.gd -- modelo=<id>) y la auditoría entera,
## con herramientas/medidas_pesos_rig.gd.

## id -> posición en reposo de la muñeca izquierda (espacio del esqueleto, Y arriba): la del rig bueno.
const RIGS: Dictionary = {
	"fantasma_elfo_rig": Vector3(0.267, 0.390, 0.054),
	"santa_compana_rig": Vector3(0.262, 0.390, 0.054),
}
const TOL_MUNECA: float = 0.004
const PIE_TRONCO_MAX: float = 0.005       ## fracción del peso bajo el tobillo que puede ser de Hips/Spine*
const MANO_PIERNA_MAX: float = 0.005      ## fracción del peso alrededor de la mano que puede ser de las piernas
const R_MANO: float = 0.06                ## (fracción del alto) radio alrededor del hueso de la mano
const CRUZ_PESO: float = 0.25
const CRUZ_MARGEN: float = 0.02
const CRUZ_MAX: int = 12                  ## vértices: la costura central de la falda reparte las dos piernas y deja unos pocos

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	await process_frame
	for id in RIGS:
		var modelo: Node3D = (load("res://arte/modelos/%s.glb" % id) as PackedScene).instantiate()
		root.add_child(modelo)
		await process_frame
		var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
		var pos: Array[Vector3] = []
		var pesos: Array[Dictionary] = []
		for n in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var ar: Array = mi.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
				var bs: PackedInt32Array = ar[Mesh.ARRAY_BONES]
				var ws: PackedFloat32Array = ar[Mesh.ARRAY_WEIGHTS]
				if bs.is_empty() or ws.is_empty():
					continue
				var por_v: int = bs.size() / vs.size()
				for v in vs.size():
					pos.append(mi.global_transform * vs[v])
					var d: Dictionary = {}
					for k in por_v:
						var w: float = ws[v * por_v + k]
						if w <= 0.0001:
							continue
						var b: int = bs[v * por_v + k]      # índice del SKIN, no del esqueleto
						if mi.skin != null:
							var nb: String = mi.skin.get_bind_name(b)
							b = sk.find_bone(nb) if nb != "" else mi.skin.get_bind_bone(b)
						var nombre: String = String(sk.get_bone_name(b)).trim_prefix("mixamorig_")
						d[nombre] = float(d.get(nombre, 0.0)) + w
					pesos.append(d)
		var y0: float = INF
		var y1: float = -INF
		for p in pos:
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		var alto: float = y1 - y0

		# A · pies
		for lado in ["Left", "Right"]:
			var tobillo: Vector3 = sk.global_transform * sk.get_bone_global_rest(sk.find_bone("mixamorig_%sFoot" % lado)).origin
			var total: float = 0.0
			var tronco: float = 0.0
			for v in pos.size():
				if pos[v].y > tobillo.y or absf(pos[v].x - tobillo.x) > absf(tobillo.x) * 0.9 + 0.01:
					continue
				for nb2 in pesos[v]:
					total += float(pesos[v][nb2])
					if String(nb2) == "Hips" or String(nb2).begins_with("Spine"):
						tronco += float(pesos[v][nb2])
			_ok(total > 0.0 and tronco / total <= PIE_TRONCO_MAX,
				"A %s · pie %s: bajo el tobillo, el %.2f %% del peso es de la cadera o la columna (tope %.1f %%)" % [
					id, lado, 100.0 * tronco / maxf(total, 0.001), PIE_TRONCO_MAX * 100.0])

		# B · mangas: alrededor de la mano no manda ninguna pierna
		for lado in ["Left", "Right"]:
			var mano: Vector3 = sk.global_transform * sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHand" % lado)).origin
			var tot: float = 0.0
			var pierna: float = 0.0
			for v in pos.size():
				if pos[v].distance_to(mano) > R_MANO * alto:
					continue
				for nb3 in pesos[v]:
					tot += float(pesos[v][nb3])
					if String(nb3).contains("Leg") or String(nb3).contains("Foot"):
						pierna += float(pesos[v][nb3])
			_ok(tot > 0.0 and pierna / tot <= MANO_PIERNA_MAX,
				"B %s · mano %s: a su alrededor, el %.2f %% del peso es de las piernas (tope %.1f %%)" % [
					id, lado, 100.0 * pierna / maxf(tot, 0.001), MANO_PIERNA_MAX * 100.0])

		# C · esqueleto
		var m: Vector3 = sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHand")).origin
		var esperado: Vector3 = RIGS[id]
		_ok(m.distance_to(esperado) <= TOL_MUNECA,
			"C %s: la muñeca izquierda está en (%.3f, %.3f, %.3f), a %.3f de donde debe (tope %.3f)" % [
				id, m.x, m.y, m.z, m.distance_to(esperado), TOL_MUNECA])

		# D · lados (en estos rigs los huesos Left están en +X)
		var cruz: int = 0
		for v in pos.size():
			if absf(pos[v].x) < CRUZ_MARGEN * alto:
				continue
			var otro: String = "Right" if pos[v].x > 0.0 else "Left"
			var w_otro: float = 0.0
			for nb4 in pesos[v]:
				if String(nb4).begins_with(otro):
					w_otro += float(pesos[v][nb4])
			if w_otro >= CRUZ_PESO:
				cruz += 1
		_ok(cruz <= CRUZ_MAX, "D %s: %d vértices cuelgan de huesos del otro lado (tope %d)" % [id, cruz, CRUZ_MAX])
		modelo.queue_free()
	print("RESULTADO rigs_autorig · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
