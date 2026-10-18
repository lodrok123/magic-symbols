extends SceneTree
## Prueba sin ventana de PiezaEscritura3D: pluma, mano y manga existen, miden lo previsto y tienen el origen que dice la cabecera.
##   godot --headless --path . --script res://herramientas/prueba_pieza_escritura.gd
var fallos: int = 0

func ok(c: bool, m: String) -> void:
	if c:
		print("  ok  ", m)
	else:
		print("  FALLA ", m)
		fallos += 1

func _initialize() -> void:
	await process_frame
	var esperado: Dictionary = {"pluma": Vector3(0.214, 0.7, 0.045), "mano_apuntando": Vector3(0.386, 0.5, 0.544), "manga_mano": Vector3(0.485, 0.533, 0.582),
		"mano_agarre": Vector3(0.269, 0.228, 0.5), "manga_agarre": Vector3(0.287, 0.292, 0.255)}
	ok(PiezaEscritura3D.crear("no_existe") == null, "una pieza que no existe da null")
	for id in esperado:
		var m: MeshInstance3D = PiezaEscritura3D.crear(id)
		ok(m != null, "%s existe" % id)
		if m == null:
			continue
		var b: AABB = m.mesh.get_aabb()
		var e: Vector3 = esperado[id]
		ok(absf(b.size.x - e.x) < 0.02 and absf(b.size.y - e.y) < 0.02 and absf(b.size.z - e.z) < 0.02, "%s mide %s ≈ %s" % [id, b.size.snapped(Vector3.ONE * 0.001), e])
	var p: AABB = PiezaEscritura3D.malla_modelo("pluma").get_aabb()
	ok(absf(p.position.y) < 0.01 and p.position.x < 0.0 and p.end.x > 0.0, "pluma: la punta del plumín en el origen (y mínima = 0) y de pie")
	var h: AABB = PiezaEscritura3D.malla_modelo("mano_apuntando").get_aabb()
	ok(absf(h.position.y) < 0.01 and h.position.x < 0.0 and h.end.x > 0.0 and h.position.z < 0.0 and h.end.z > 0.0, "mano: la punta del índice en el origen (y mínima = 0)")
	var g: AABB = PiezaEscritura3D.malla_modelo("manga_mano").get_aabb()
	ok(g.position.y > 0.0 and g.end.y > h.end.y, "manga: empieza por encima de la punta y termina más arriba que la mano (mismo origen)")
	var ma: AABB = PiezaEscritura3D.malla_modelo("mano_agarre").get_aabb()
	ok(ma.position.x < 0.0 and ma.end.x > 0.0 and ma.position.z < 0.0 and ma.end.z > 0.0, "mano_agarre: el origen (centro del pellizco) queda dentro de la mano, entre los dedos y la muñeca")
	var tp: Transform3D = PiezaEscritura3D.pluma_en_agarre()
	ok(absf(tp.basis.determinant() - 1.0) < 0.001, "pluma_en_agarre: la base es una rotación limpia (det = 1)")
	ok(tp.origin.z > 0.0 and tp.origin.y < 0.0, "pluma_en_agarre: el plumín asoma por delante (+Z) y por debajo (−Y) del pellizco")
	ok(tp.basis.y.y > 0.0, "pluma_en_agarre: la pluma sube hacia el dorso de la mano")
	print("FALLOS ", fallos)
	quit(1 if fallos > 0 else 0)
