extends SceneTree
func _initialize():
	call_deferred("_medir")
func _medir():
	var nombres = JSON.parse_string(FileAccess.get_file_as_string("E:/magic-symbols/output/auditoria_sfx_2026-11-25/archivos.json"))
	var resultados: Array = []
	var sr: float = AudioServer.get_mix_rate()
	for nombre in nombres:
		var ruta: String = "E:/magic-symbols/audio/" + nombre
		var s: AudioStream
		if ruta.ends_with(".ogg"): s = AudioStreamOggVorbis.load_from_file(ruta)
		elif ruta.ends_with(".wav"): s = AudioStreamWAV.load_from_file(ruta)
		else: s = AudioStreamMP3.load_from_file(ruta)
		if s == null:
			resultados.append({"archivo": nombre, "error": "No decodifica"})
			continue
		var p = s.instantiate_playback()
		p.start()
		var n: int = ceili(s.get_length() * sr)
		var pos: int = 0
		var energia: float = 0.0
		var pico: float = 0.0
		var saturadas: int = 0
		var primero: int = -1
		var ultimo: int = -1
		var borde_a: Vector2 = Vector2.ZERO
		var borde_b: Vector2 = Vector2.ZERO
		var energia_bordes: Array = [0.0, 0.0]
		while pos < n:
			var datos: PackedVector2Array = p.mix_audio(1.0, mini(4096, n - pos))
			if datos.is_empty():
				break
			for v in datos:
				var a: float = maxf(absf(v.x), absf(v.y))
				var en: float = (v.x*v.x + v.y*v.y) / 2.0
				energia += en
				pico = maxf(pico, a)
				if a >= 0.999: saturadas += 1
				if a > 0.001:
					if primero < 0: primero = pos
					ultimo = pos
				if pos == 0: borde_a = v
				borde_b = v
				if pos < sr * 0.02: energia_bordes[0] += en
				if pos >= n - sr * 0.02: energia_bordes[1] += en
				pos += 1
		p.stop()
		if n - pos > 64:
			push_error("Flujo incompleto: " + nombre + " faltan " + str(n - pos) + " muestras")
		if resultados.size() % 25 == 0: print("PROGRESO: ", resultados.size(), " ", nombre)
		resultados.append({"archivo": nombre, "duracion_s": s.get_length(), "pico_dbfs": linear_to_db(maxf(pico, 0.0000001)), "rms_dbfs": linear_to_db(maxf(sqrt(energia / maxf(n, 1)), 0.0000001)), "muestras_casi_0db": saturadas, "entrada_ms": maxf(primero,0)/sr*1000, "cola_bajo_60db_ms": (n-1-ultimo)/sr*1000 if ultimo >= 0 else n/sr*1000, "salto_bucle": maxf(absf(borde_a.x-borde_b.x),absf(borde_a.y-borde_b.y)), "rms_inicio_dbfs": linear_to_db(maxf(sqrt(energia_bordes[0]/(sr*0.02)),0.0000001)), "rms_fin_dbfs": linear_to_db(maxf(sqrt(energia_bordes[1]/(sr*0.02)),0.0000001))})
	FileAccess.open("E:/magic-symbols/output/auditoria_sfx_2026-11-25/metricas.json",FileAccess.WRITE).store_string(JSON.stringify(resultados,"\t"))
	print("ARCHIVOS ANALIZADOS: ", resultados.size(), "; frecuencia de medicion: ", sr)
	quit()
