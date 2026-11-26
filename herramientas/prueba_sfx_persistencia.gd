extends "res://herramientas/escenario_base.gd"
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "viento": "wind", "tierra": "earth"}

func _escenario() -> void:
	await cargar("res://escenas/PruebaSalaGolem.tscn")
	Sfx.REGISTRAR = true
	for el in ELEMENTOS:
		var r: RuneData = load("res://nucleo/%s_rune.tres" % ELEMENTOS[el]) as RuneData
		var h: Hechizo = Hechizo.construir(r, {"barrera": 1}, 1.0)
		var vivo: HechizoVivo = HechizoVivo.preparar(h, lanzador)
		vivo.linaje = HechizoVivo.Linaje.new()
		var ctx: Dictionary = {"data": r, "elemento": el, "celdas": [Vector2i(2, 2)], "niveles": 1, "vida": 2.0, "dir": Vector3.RIGHT, "origen": Terreno3D.centro_de(Vector2i(2, 2)), "estado": "campo", "tocados": {}}
		Sfx.vaciar_registro()
		var s: Lanzador3D.SolidezV2 = vivo._solidez(ctx, 1.0, false)
		var voz: SonidoPersistencia3D = SonidoPersistencia3D.registrar(s, el, vivo.linaje)
		_ok(el + ": solidez inicia carga sostenida, una sola vez", voz != null and Sfx.veces(el + "_carga_bucle") == 1)
		if voz == null:
			vivo.free()
			continue
		var audio: AudioStreamPlayer3D = voz._audio
		var original: AudioStreamWAV = load(Sfx.CARPETA + String(Sfx.archivos_de(Sfx.CATALOGO[el + "_carga_bucle"])[0])) as AudioStreamWAV
		_ok(el + ": conserva muestra, tono y nivel de carga", audio != null and audio.playing and audio.stream is AudioStreamWAV and (audio.stream as AudioStreamWAV).data == original.data and is_equal_approx(audio.pitch_scale, 1.0) and is_equal_approx(audio.volume_db, Sfx.db_de(el + "_carga_bucle")))
		s.celdas = {Vector2i(3, 2): true}
		voz._actualizar()
		_ok(el + ": sigue posición del efecto", voz.global_position.is_equal_approx(Terreno3D.centro_de(Vector2i(3, 2))))
		vivo._abrir_zona(ctx)
		var z: Lanzador3D.ZonaV2 = lanzador._zonas_v2.back() as Lanzador3D.ZonaV2
		_ok(el + ": campo y solidez comparten una voz", SonidoPersistencia3D.registrar(z, el, vivo.linaje) == voz and Sfx.veces(el + "_carga_bucle") == 1)
		z.avanzar(100.0)
		await process_frame
		_ok(el + ": sigue sonando si queda solidez", is_instance_valid(audio) and audio.playing)
		s.golpe(100000.0)
		await process_frame
		await process_frame
		_ok(el + ": rotura final libera audio", not is_instance_valid(audio))
		vivo.free()
	var temporal := Node3D.new()
	lanzador.mundo.add_child(temporal)
	Sfx.vaciar_registro()
	SonidoPersistencia3D.registrar_despues(temporal, "agua", null, 0.03)
	_ok("el agua no suena antes de caer", Sfx.veces("agua_carga_bucle") == 0)
	await create_timer(0.06).timeout
	_ok("el agua inicia persistencia tras caer", Sfx.veces("agua_carga_bucle") == 1)
	var voz_agua: SonidoPersistencia3D = SonidoPersistencia3D.registrar(temporal, "agua")
	var audio_agua: Node = voz_agua._audio
	temporal.queue_free()
	await process_frame
	await process_frame
	_ok("eliminar dueño no deja audio huérfano", not is_instance_valid(audio_agua))
	var b := Lanzador3D.Burbuja.new()
	lanzador.mundo.add_child(b)
	var voz_b: SonidoPersistencia3D = SonidoPersistencia3D.registrar(b, "hielo", null, Callable(b, "centro"))
	var audio_b: AudioStreamPlayer3D = voz_b._audio
	b.reventada = true
	voz_b._actualizar()
	_ok("reventar burbuja corta sonido aunque quede el nodo", not audio_b.playing)
	b.queue_free()
	await process_frame
	var vaciada := Lanzador3D.ZonaV2.new()
	vaciada.celdas = {Vector2i(2, 2): true}
	lanzador.mundo.add_child(vaciada)
	var voz_v: SonidoPersistencia3D = SonidoPersistencia3D.registrar(vaciada, "viento")
	var audio_v: AudioStreamPlayer3D = voz_v._audio
	vaciada.celdas.clear()
	voz_v._actualizar()
	_ok("vaciar las celdas apaga persistencia sin esperar a la caducidad", not audio_v.playing)
	vaciada.queue_free()
	await process_frame
