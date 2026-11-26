extends SceneTree
func _initialize(): call_deferred("extraer")
func extraer():
	var ruta: String="E:/magic-symbols/audio/fuentes/kenney_interface-sounds/Audio/back_001.ogg"
	var s=AudioStreamOggVorbis.load_from_file(ruta)
	var p=s.instantiate_playback()
	p.start()
	var n: int=ceili(s.get_length()*44100)
	var pcm:=PackedByteArray();pcm.resize(n*2)
	var pos: int=0
	while pos<n:
		var datos: PackedVector2Array=p.mix_audio(1.0,mini(4096,n-pos))
		if datos.is_empty():break
		for v in datos:
			pcm.encode_s16(pos*2,roundi(clampf((v.x+v.y)*0.5,-1.0,1.0)*32767))
			pos+=1
	var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=44100;w.data=pcm
	w.save_to_wav("E:/magic-symbols/output/sfx_tanda4_validacion_2026-11-25/back_fuente.wav")
	print("Fuente Kenney: ",s.get_length()," s")
	quit()
