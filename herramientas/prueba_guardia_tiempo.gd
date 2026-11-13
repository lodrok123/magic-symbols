extends SceneTree
## Tope de la cámara lenta (GuardiaTiempo, 13/11/2026): una escala lenta que se queda puesta vuelve a 1 a los 2 s reales;
## los efectos cortos (cámara lenta del último enemigo, ~0,7 s) no se tocan.
##   godot --headless --path . --script res://herramientas/prueba_guardia_tiempo.gd

var _fallos := 0
var _paso := 0
var _f := 0
var _t0 := 0


func _initialize() -> void:
	change_scene_to_file("res://escenas/PruebaBosque02.tscn")


func _ok(c: bool, t: String) -> void:
	print(("OK    " if c else "FALLO ") + t)
	if not c:
		_fallos += 1


func _process(_d: float) -> bool:
	_f += 1
	match _paso:
		0:
			if _f < 120:
				return false
			_ok(current_scene.get_node_or_null("GuardiaTiempo") != null, "1 el nivel monta el guardián del tiempo")
			# Un efecto corto como la cámara lenta del último enemigo: 0,7 s a 0,3 y vuelve solo.
			Engine.time_scale = 0.3
			_t0 = Time.get_ticks_msec()
			_paso = 1
		1:
			if Time.get_ticks_msec() - _t0 < 700:
				return false
			_ok(is_equal_approx(Engine.time_scale, 0.3) and GuardiaTiempo.correcciones == 0, "2 un efecto de 0,7 s no se corrige")
			Engine.time_scale = 1.0
			_paso = 2
		2:
			# La situación del playtest: la escala se queda a 0,3 sin nadie que la devuelva.
			Engine.time_scale = 0.3
			_t0 = Time.get_ticks_msec()
			_paso = 3
		3:
			if Time.get_ticks_msec() - _t0 < 2600:
				return false
			_ok(is_equal_approx(Engine.time_scale, 1.0), "3 la escala atascada a 0,3 vuelve a 1 (%.2f)" % Engine.time_scale)
			_ok(GuardiaTiempo.correcciones == 1, "4 el guardián intervino una vez (%d)" % GuardiaTiempo.correcciones)
			print("FALLOS: %d" % _fallos)
			quit(1 if _fallos > 0 else 0)
	return false
