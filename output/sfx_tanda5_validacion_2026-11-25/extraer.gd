extends SceneTree
func _initialize():call_deferred("extraer")
func extraer():
	var lista={"madera_media":"kenney_impact-sounds/Audio/impactWood_medium_000.ogg","madera_fuerte":"kenney_impact-sounds/Audio/impactWood_heavy_000.ogg","corte_madera":"kenney_rpg-audio/Audio/chop.ogg","crujido":"kenney_rpg-audio/Audio/creak1.ogg"}
	for nombre in lista:
		var s=AudioStreamOggVorbis.load_from_file("E:/magic-symbols/audio/fuentes/"+lista[nombre])
		if s==null:quit(1);return
		var p=s.instantiate_playback();p.start()
		var n: int=ceili(s.get_length()*44100)
		var pcm:=PackedByteArray();pcm.resize(n*2)
		var pos: int=0
		while pos<n:
			var datos: PackedVector2Array=p.mix_audio(1.0,mini(4096,n-pos))
			if datos.is_empty():break
			for v in datos:
				pcm.encode_s16(pos*2,roundi(clampf((v.x+v.y)*0.25,-1.0,1.0)*32767))
				pos+=1
		p.stop()
		var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=44100;w.data=pcm
		w.save_to_wav("E:/magic-symbols/output/sfx_tanda5_validacion_2026-11-25/"+nombre+"_fuente.wav")
		print(nombre, " ",s.get_length()," s")
	quit()
