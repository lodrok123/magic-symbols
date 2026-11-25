extends SceneTree
const LAB = preload("res://laboratorios/lab_estados_blender.gd")
const DIR = "res://output/blender_interacciones_2026-11-25/"
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	root.size=Vector2i(800,500)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var lab=LAB.new(); root.add_child(lab)
	var hoja:=Image.create(1600,2500,false,Image.FORMAT_RGBA8)
	for i in 5:
		lab.mostrar(i)
		for estado in 2:
			if estado==1:
				lab.actuar()
				if i==1: lab.actuar()
				if i==2:
					lab.objeto._process(float(lab.objeto._num_combustible()[0])+0.1)
				await create_timer(3.0 if i==2 else 0.9).timeout
			lab.texto.text = lab.TITULOS[i]+"\n"+("ANTES" if estado==0 else "DESPUÉS")
			for j in 12: await process_frame
			await RenderingServer.frame_post_draw
			var im:=root.get_texture().get_image(); im.convert(Image.FORMAT_RGBA8)
			im.save_png(DIR+"conexion_%d_%d.png"%[i,estado])
			hoja.blit_rect(im,Rect2i(0,0,800,500),Vector2i(estado*800,i*500))
	hoja.save_png(DIR+"lamina_conexion.png")
	lab.free()
	await process_frame
	print("CAPTURAS CONEXION: 10")
	quit()
