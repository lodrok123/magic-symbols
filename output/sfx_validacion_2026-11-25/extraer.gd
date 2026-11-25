extends SceneTree
func _initialize(): call_deferred("extraer")
func extraer():
	var dir: String = "E:/magic-symbols/output/sfx_validacion_2026-11-25/"
	var lista = JSON.parse_string(FileAccess.get_file_as_string(dir+"extraer.json"))
	for cfg in lista:
		var ruta: String = "E:/magic-symbols/audio/"+cfg.f
		var s: AudioStream
		if ruta.ends_with(".mp3"): s=AudioStreamMP3.load_from_file(ruta)
		elif ruta.ends_with(".wav"): s=AudioStreamWAV.load_from_file(ruta)
		else: s=AudioStreamOggVorbis.load_from_file(ruta)
		if s==null:
			quit(1)
			return
		var p=s.instantiate_playback()
		p.start(cfg.inicio)
		var n: int = roundi(cfg.duracion*44100)
		var pcm:=PackedByteArray()
		pcm.resize(n*2)
		var pos: int=0
		while pos<n:
			var datos: PackedVector2Array=p.mix_audio(1.0,mini(4096,n-pos))
			if datos.is_empty(): break
			for v in datos:
				pcm.encode_s16(pos*2,roundi(clampf((v.x+v.y)*0.5,-1.0,1.0)*32767.0))
				pos+=1
		p.stop()
		var w:=AudioStreamWAV.new()
		w.format=AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate=44100
		w.data=pcm
		w.save_to_wav(dir+cfg.salida+".wav")
		print(cfg.salida, " muestras: ",pos)
	quit()
