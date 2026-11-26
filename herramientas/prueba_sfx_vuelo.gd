extends "res://herramientas/escenario_base.gd"
## Vuelo 65–70: proyectiles reales, posición, fin, espera, rebote y previsión silenciosa.
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "viento": "wind", "tierra": "earth"}

func ficha(el: String, espera_s: float = 0.0) -> Hechizo:
	var r: RuneData = load("res://nucleo/%s_rune.tres" % ELEMENTOS[el]) as RuneData
	var h: Hechizo = Hechizo.construir(r, {"flecha": 1}, 1.0)
	h.velocidad = 1.0
	h.gravedad = 0.0
	h.retardo = espera_s
	h.distancia_max = 20.0
	h.permanencia = 0.2
	return h

func crear_vuelo(el: String, espera_s: float = 0.0) -> HechizoVivo:
	return HechizoVivo.crear(ficha(el, espera_s), jugador.global_position, Vector3.RIGHT, lanzador, null, {}, true)

func _escenario() -> void:
	await cargar("res://escenas/PruebaSalaGolem.tscn")
	Sfx.REGISTRAR = true
	# Antes de los impactos: la tierra de esos casos modifica el suelo de salida.
	var retardado: HechizoVivo = crear_vuelo("fuego", 0.2)
	_ok("no suena mientras espera", retardado._sonido_vuelo == null)
	retardado.paso(0.1)
	_ok("sigue silencioso antes de moverse", retardado._sonido_vuelo == null)
	retardado.paso(0.11)
	_ok("arranca al terminar la espera", retardado._sonido_vuelo != null, "espera=%.3f activo=%s fin=%s" % [retardado.espera, str(retardado.activo), retardado.motivo_fin])
	var audio_retardo: Node = retardado._sonido_vuelo
	retardado.queue_free()
	await process_frame
	await process_frame
	_ok("retirar el proyectil no deja audio huérfano", not is_instance_valid(audio_retardo))
	for el in ELEMENTOS:
		Sfx.vaciar_registro()
		var vivo: HechizoVivo = crear_vuelo(el)
		var audio: AudioStreamPlayer3D = vivo._sonido_vuelo
		_ok(el + ": inicia un solo bucle", Sfx.veces(el + "_vuelo") == 1 and audio != null and audio.playing)
		if audio != null:
			_ok(el + ": hijo espacial con nivel y tono aprobados", audio.get_parent() == vivo and is_equal_approx(audio.volume_db, Sfx.db_de(el + "_vuelo")) and is_equal_approx(audio.pitch_scale, 1.0))
			_ok(el + ": WAV en bucle", audio.stream is AudioStreamWAV and (audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
			vivo.global_position += Vector3(0.1, 0.0, 0.0)
			_ok(el + ": sigue la posición sin offset", audio.global_position.is_equal_approx(vivo.global_position))
			vivo._actualizar_sonido_vuelo()
			vivo._rebotar()
			vivo._actualizar_sonido_vuelo()
			_ok(el + ": rebote no duplica ni reinicia", vivo._sonido_vuelo == audio and Sfx.veces(el + "_vuelo") == 1)
		vivo._terminar("golpe")
		_ok(el + ": impacto corta audio inmediatamente", vivo._sonido_vuelo == null and (not is_instance_valid(audio) or not audio.playing))
		await process_frame
		await process_frame
		_ok(el + ": reproductor liberado aunque el efecto persista", not is_instance_valid(audio))
	var seco: HechizoVivo = HechizoVivo.preparar(ficha("agua"), lanzador)
	seco.seco = true
	lanzador.add_child(seco)
	seco._iniciar_proyectil(jugador.global_position, Vector3.RIGHT)
	seco._actualizar_sonido_vuelo()
	_ok("previsión en seco sin audio", seco._sonido_vuelo == null)
	seco.queue_free()
	var quieto: HechizoVivo = HechizoVivo.preparar(ficha("agua"), lanzador)
	lanzador.add_child(quieto)
	quieto.activo = true
	quieto.v = Vector3.RIGHT
	quieto._actualizar_sonido_vuelo()
	_ok("un volumen no proyectil no genera bucle de vuelo", quieto._sonido_vuelo == null)
	quieto.queue_free()
