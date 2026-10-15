extends SceneTree
## Manantial FINITO (15/10, Juego): `AguaSim3D.limitar_fuente` apaga un manantial al echar su volumen, con rampa o sin ella, y
## `apagar_fuente` corta rampa y caudal. Es lo que hace que una tinaja tenga fondo (Surtidor3D.VOL_TINAJA, ReaccionesAgua3D.abrir_cauce).
##   godot --headless --path . --script res://herramientas/prueba_fuente_finita.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _sim() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(1, 1, 3, 2.3, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	return a


func _correr(a: AguaSim3D, seg: float) -> void:
	var t: float = 0.0
	while t < seg:
		a.paso(1.0 / 60.0)
		t += 1.0 / 60.0


func _initialize() -> void:
	await process_frame
	var c := Vector2i(0, 0)                 # la única casilla (la simulación es de 1 × 1: así nada se absorbe ni se va)
	# 1. Manantial fijo de 1 u³/s con tope de 2 u³: a los 3 s está apagado y ha echado 2 u³ (±5 %).
	var a: AguaSim3D = _sim()
	a.fuente_en(c, 1.0)
	a.limitar_fuente(c, 2.0)
	_ok("1a antes de agotarse echa su caudal", absf(a.caudal_en(c) - 1.0) < 1.0e-4)
	_correr(a, 1.0)
	_ok("1b al segundo le queda ~1 u³", absf(a.volumen_restante(c) - 1.0) < 0.06, "%.3f" % a.volumen_restante(c))
	_correr(a, 2.0)
	_ok("1c a los 3 s el manantial está apagado", a.caudal_en(c) == 0.0)
	_ok("1d ha echado el volumen del tope (2 u³)", absf(a.volumen_total() - 2.0) < 0.1, "%.3f u³" % a.volumen_total())
	var ag: Array = a.fuentes_agotadas()
	_ok("1e avisa de que se agotó (una vez)", ag == [c] and a.fuentes_agotadas().is_empty())
	# 2. Con rampa: 1 u³/s en 4 s de arranque y tope 3 u³. La rampa echa 2 u³ en sus 4 s; a los 6 s se ha agotado.
	var b: AguaSim3D = _sim()
	b.sumar_fuente_gradual(c, 1.0, 4.0)
	b.limitar_fuente(c, 3.0)
	_correr(b, 4.0)
	_ok("2a tras la rampa sigue abierto (lleva ~2 de 3 u³)", b.caudal_en(c) > 0.9 and absf(b.volumen_restante(c) - 1.0) < 0.1, "caudal %.2f, queda %.2f" % [b.caudal_en(c), b.volumen_restante(c)])
	_correr(b, 2.0)
	_ok("2b a los 6 s apagado y con 3 u³ echados", b.caudal_en(c) == 0.0 and absf(b.volumen_total() - 3.0) < 0.15, "%.3f u³" % b.volumen_total())
	# 3. apagar_fuente a media rampa: no sigue sumando.
	var d: AguaSim3D = _sim()
	d.sumar_fuente_gradual(c, 1.0, 4.0)
	_correr(d, 1.0)
	d.apagar_fuente(c)
	_correr(d, 2.0)
	_ok("3 apagar_fuente a media rampa deja el caudal a 0 y no vuelve", d.caudal_en(c) == 0.0)
	# 4. Sin tope, infinito como siempre.
	var e: AguaSim3D = _sim()
	e.fuente_en(c, 1.0)
	_correr(e, 3.0)
	# (`fuente` es un PackedFloat32Array: 9 × float32(1/9) no suma exactamente 1,0; por eso la tolerancia.)
	_ok("4 sin limitar_fuente sigue echando", absf(e.caudal_en(c) - 1.0) < 1.0e-4 and e.volumen_restante(c) == INF, "caudal %.6f" % e.caudal_en(c))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
