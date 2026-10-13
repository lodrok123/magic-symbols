extends SceneTree
## Lab del agua con troncos (11.2 + 11.6), sin ventana: el hoyo se llena y el tronco que cae flota a su altura; el de la
## escalera del manantial no atraviesa el suelo. Lo escribe el Juego.
func _initialize() -> void:
	await process_frame
	var lab: Node3D = load("res://laboratorios/LabAgua3D.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var fallos: int = 0
	var S: float = 2.3
	# Hoyo (casillas 6-7, 4-5): se llena echando agua; luego un tronco encima.
	for _i in range(20):
		lab.agua.anadir(Vector3(7.0 * S, 0.0, 5.0 * S), 3.0, 1.5)
	for _i in range(60 * 12):
		await physics_frame
	var c := Vector2i(6, 4)
	var sup: float = lab.agua.superficie_en(Vector3((c.x + 0.5) * S, 0, (c.y + 0.5) * S))
	var t = lab.echar_tronco(Vector3((c.x + 1.0) * S, sup + 1.5, (c.y + 1.0) * S))
	for _i in range(60 * 8):
		await physics_frame
	var ok1: bool = t.flota() and absf(t.global_position.y - (lab.agua.superficie_en(t.global_position) - 0.082)) < 0.08
	print(("OK    " if ok1 else "FALLO ") + "hoyo: superficie %.3f tronco y %.3f hundidas %d" % [sup, t.global_position.y, t.hundidas])
	if not ok1: fallos += 1
	# Tronco sobre la escalera del manantial: no atraviesa el suelo (suelo en 2 niveles = 2.3).
	var t2 = lab.echar_tronco(Vector3(2.5 * S, 5.0, 1.5 * S))
	for _i in range(60 * 10):
		await physics_frame
	var ok2: bool = t2.global_position.y > -0.5 and t2.global_position.y < 6.0
	print(("OK    " if ok2 else "FALLO ") + "escalera: el tronco no atraviesa el suelo, y %.3f" % t2.global_position.y)
	if not ok2: fallos += 1
	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)
