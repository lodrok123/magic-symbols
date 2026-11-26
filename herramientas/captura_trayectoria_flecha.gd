extends "res://herramientas/captura_apuntado.gd"
## FOTOS DE B9c · LA TRAYECTORIA DE LA FLECHA (23/11, sesión HECHIZOS). Antes / después de bajar a ras de suelo la cinta de un vuelo recto. NECESITA VENTANA:
##   godot --resolution 1280x720 --path E:\magic-symbols --script res://herramientas/captura_trayectoria_flecha.gd -- <carpeta>


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	_dir = a[0] if a.size() > 0 and a[0] != "" else "res://docs/capturas/trayectoria_flecha_2026-11-23"
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	maqueta.set("_tam_camara", 8.0)
	(maqueta.get("_camara") as Camera3D).size = 8.0
	await avanzar_s(1.0)
	var oeste := Vector3(-1, 0, 0)
	for antes in [true, false]:
		Apuntado3D.bajar_vuelo_recto = not antes
		var pre: String = "antes_" if antes else "despues_"
		await _caso(pre + "1_flecha_fuego_libre", Vector2i(12, 34), "fuego", ["flecha"], oeste, 3.0)
		await _caso(pre + "2_flecha_tierra_libre", Vector2i(12, 34), "tierra", ["flecha"], oeste, 3.0)
		await _caso(pre + "3_flecha_agua_doble", Vector2i(12, 34), "agua", ["flecha", "flecha"], oeste, 4.0)
		_goblin(Vector2i(10, 31))
		await _caso(pre + "4_flecha_fuego_a_goblin", Vector2i(12, 31), "fuego", ["flecha"], oeste, 3.0)
	Apuntado3D.bajar_vuelo_recto = true
