extends SceneTree
var fallos: int=0
func ok(b: bool,t: String):
	print(("OK " if b else "FALLO ")+t)
	if not b: fallos+=1
func _initialize(): call_deferred("probar")
func probar():
	Terreno3D.cargar_datos(PackedStringArray([".....",".....",".....",".....","....."]),{})
	var escena:=Node3D.new()
	root.add_child(escena)
	var bloque:=BloqueEmpujable3D.new()
	bloque.preparar(Vector2i(1,1),"piedra")
	escena.add_child(bloque)
	ok(bloque.empujar(Vector2i.RIGHT),"el bloque inicia empuje real")
	await process_frame
	await process_frame
	var p: AudioStreamPlayer3D=bloque.get("_sonido")
	ok(p!=null and p.stream!=null and p.stream.get_length()>5.9,"el bloque usa el nuevo arrastre de seis segundos")
	if p!=null:
		ok(is_equal_approx(p.volume_db,-23.0),"el nivel integrado es sutil: -23 dB")
		ok(p.stream is AudioStreamWAV and p.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"la rodadura queda en bucle")
	for i in 300:
		if not bloque.moviendo:break
		await process_frame
	ok(not bloque.moviendo and bloque.get("_sonido")==null,"al terminar el empuje se retira el sonido")
	await create_timer(.6).timeout
	ok(not is_instance_valid(p),"el reproductor desaparece tras el fundido")
	escena.queue_free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
