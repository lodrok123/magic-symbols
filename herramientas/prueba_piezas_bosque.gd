extends SceneTree
## Prueba sin ventana de PiezaBosque3D: las 7 piezas existen, miden lo previsto y tienen el origen que dice la cabecera.
##   godot --headless --path . --script res://herramientas/prueba_piezas_bosque.gd
var fallos: int = 0

func ok(c: bool, m: String) -> void:
	if c:
		print("  ok  ", m)
	else:
		print("  FALLA ", m)
		fallos += 1

func _initialize() -> void:
	await process_frame
	var esperado: Dictionary = {"tronco_puente_pie": Vector3(1.43, 2.6, 1.58), "tronco_puente_caido": Vector3(2.6, 0.56, 0.5),
		"bloqueo_enredaderas": Vector3(2.2, 1.08, 1.09), "bloqueo_enredaderas_quemado": Vector3(1.83, 0.66, 1.02),
		"enredadera_quemada_a": Vector3(0.6, 0.22, 0.62), "enredadera_quemada_b": Vector3(0.5, 0.3, 0.56), "ceniza_enredadera": Vector3(0.9, 0.1, 1.03)}
	ok(PiezaBosque3D.IDS.size() == 7, "hay 7 piezas")
	ok(PiezaBosque3D.crear("no_existe") == null, "una pieza que no existe da null")
	for id in PiezaBosque3D.IDS:
		var m: MeshInstance3D = PiezaBosque3D.crear(id)
		ok(m != null, "%s existe" % id)
		if m == null:
			continue
		var b: AABB = m.mesh.get_aabb()
		var e: Vector3 = esperado[id]
		ok(absf(b.size.x - e.x) < 0.05 and absf(b.size.y - e.y) < 0.05 and absf(b.size.z - e.z) < 0.05, "%s mide %s ≈ %s" % [id, b.size.snapped(Vector3.ONE * 0.01), e])
		ok(absf(b.position.y) < 0.02, "%s: apoyada en y = 0 (%.3f)" % [id, b.position.y])
		if id == "tronco_puente_caido":
			ok(absf(b.position.x) < 0.02 and b.end.x > 2.5, "tronco caído: el pie en el origen y tumbado hacia +X")
		else:
			ok(absf(b.get_center().x) < 0.02 and absf(b.get_center().z) < 0.02, "%s: centrada en la base" % id)
	var q: float = PiezaBosque3D.malla_modelo("bloqueo_enredaderas_quemado").get_aabb().size.x / PiezaBosque3D.malla_modelo("bloqueo_enredaderas").get_aabb().size.x
	ok(q < 1.0, "el bloqueo quemado no es más ancho que el vivo (%.2f)" % q)
	print("FALLOS ", fallos)
	quit(1 if fallos > 0 else 0)
