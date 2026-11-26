extends "res://herramientas/prueba_sonidos_grabados_2.gd"
func _escenario() -> void:
	await cargar(RUTA_SALA)
	_impacto_elemento()
	for nombre in ["fuego_carga_bucle", "arde_bucle"]:
		var s: AudioStream = Sfx.flujo_en_bucle(nombre)
		_ok("fuego real en bucle para " + nombre, s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
