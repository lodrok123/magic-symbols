extends SceneTree
## PRUEBA de la galería de animaciones UAL (laboratorios/LabGaleriaUAL3D.tscn, 25/11): carga; están todos los clips de UAL 1 y UAL 2 menos A_TPose; cada jugadora reproduce
## SU clip en bucle y el tiempo avanza; no hay dos en el mismo sitio; los maniquíes (M) salen con su clip original; Tab lleva la cámara al clip. Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_galeria_ual.gd

const CLIPS_ESPERADOS: int = 84               ## 43 + 43 de las dos librerías, menos las dos A_TPose

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	print("OK    " if c else "FALLO ", m)
	if not c:
		_fallos += 1


func _initialize() -> void:
	_correr()


func _correr() -> void:
	Estado.nuevo()
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var lab: Node = (load("res://laboratorios/LabGaleriaUAL3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	print("montada en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for _i in 5:
		await process_frame
	var clips: Array = lab.call("clips")
	_ok(clips.size() == CLIPS_ESPERADOS, "%d clips en la galería (esperados %d)" % [clips.size(), CLIPS_ESPERADOS])
	var tpose: bool = false
	var mal: Array = []
	var sitios: Dictionary = {}
	for c in clips:
		if String(c["origen"]) == "A_TPose":
			tpose = true
		var ap: AnimationPlayer = c["ap"]
		if ap == null or not ap.is_playing() or String(ap.current_animation) != String(c["nombre"]) or ap.get_animation(String(c["nombre"])).loop_mode != Animation.LOOP_LINEAR:
			mal.append(String(c["nombre"]))
		sitios[str(c["pos"])] = true
	_ok(not tpose, "A_TPose fuera")
	_ok(mal.is_empty(), "cada jugadora reproduce su clip en bucle (mal: %s)" % [mal])
	_ok(sitios.size() == clips.size(), "cada una en su sitio (%d sitios)" % sitios.size())
	var ap0: AnimationPlayer = (clips[0] as Dictionary)["ap"]
	var antes: float = ap0.current_animation_position
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 300:
		await process_frame
	_ok(not is_equal_approx(ap0.current_animation_position, antes), "el tiempo avanza (%.2f → %.2f s)" % [antes, ap0.current_animation_position])
	lab.call("poner_maniquies", true)
	await process_frame
	var sin_m: int = 0
	for c in clips:
		var apm: AnimationPlayer = c.get("ap_m") as AnimationPlayer
		if c["maniqui"] == null or apm == null or String(apm.current_animation) != String(c["origen"]):
			sin_m += 1
	_ok(sin_m == 0, "maniquíes con su clip original (%d sin él)" % sin_m)
	lab.call("ir_a", 10)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var p10: Vector3 = (clips[10] as Dictionary)["pos"]
	_ok(cam != null and cam.global_position.distance_to(p10) < 3.5, "Tab lleva la cámara al clip 10 (%.1f u)" % (cam.global_position.distance_to(p10) if cam != null else -1.0))
	print("\n%s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	quit(1 if _fallos > 0 else 0)
