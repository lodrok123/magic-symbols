extends "res://herramientas/escenario_base.gd"
## Integración de bucles 54–58: selección, tono estable y parada en las salidas reales del modo de lanzar.
func _escenario() -> void:
	await cargar("res://escenas/PruebaSalaGolem.tscn")
	Sensacion3D.ACTIVA = true
	Sfx.REGISTRAR = true
	for el in ["agua", "hielo", "rayo", "viento", "tierra"]:
		lanzador.modo_lanzar = true
		Sfx.vaciar_registro()
		Sensacion3D.carga(lanzador, el)
		var aro: Sensacion3D.AroCarga = lanzador.get_node_or_null("AroCarga") as Sensacion3D.AroCarga
		_ok(el + ": se crea carga elemental", aro != null and aro._sonido_elemental)
		if aro == null:
			continue
		var p: AudioStreamPlayer3D = aro._zumbido as AudioStreamPlayer3D
		_ok(el + ": usa solo su bucle, sin zumbido genérico", Sfx.veces(el + "_carga_bucle") == 1 and Sfx.veces("carga_bucle") == 0)
		_ok(el + ": audio activo y WAV circular", p != null and p.playing and p.stream is AudioStreamWAV and (p.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
		aro.t = 2.0
		aro._colocar()
		_ok(el + ": conserva tono y nivel aceptados", p != null and is_equal_approx(p.pitch_scale, 1.0) and is_equal_approx(p.volume_db, Sfx.db_de(el + "_carga_bucle")))
		lanzador._salir_modo(true)
		await create_timer(0.25).timeout
		_ok(el + ": al lanzar se libera el reproductor", not is_instance_valid(p))
		lanzador.modo_lanzar = true
		Sensacion3D.carga(lanzador, el)
		aro = lanzador.get_node_or_null("AroCarga") as Sensacion3D.AroCarga
		p = aro._zumbido as AudioStreamPlayer3D
		lanzador._cancelar_modo()
		await create_timer(0.25).timeout
		_ok(el + ": al cancelar se libera el reproductor", not is_instance_valid(p))
	# El sonido vive en la raíz: retirar el aro debe pararlo también.
	lanzador.modo_lanzar = true
	Sensacion3D.carga(lanzador, "agua")
	var ultimo: Sensacion3D.AroCarga = lanzador.get_node("AroCarga") as Sensacion3D.AroCarga
	var sonido: Node = ultimo._zumbido
	ultimo.queue_free()
	await process_frame
	await process_frame
	_ok("retirar la carga no deja audio huérfano", not is_instance_valid(sonido))
	lanzador.modo_lanzar = false
