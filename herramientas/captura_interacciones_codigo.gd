extends SceneTree
const LAB = preload("res://laboratorios/lab_interacciones_codigo.gd")
const DIR = "res://output/interacciones_codigo_2026-11-25/"
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640,480)
	var lab = LAB.new()
	root.add_child(lab)
	var hoja := Image.create(1920,2880,false,Image.FORMAT_RGBA8)
	for i in 18:
		lab.mostrar(i)
		await create_timer(0.25).timeout
		for j in 8: await process_frame
		await RenderingServer.frame_post_draw
		var im: Image = root.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.save_png(DIR+"muestra_%02d.png"%i)
		hoja.blit_rect(im,Rect2i(0,0,640,480),Vector2i((i%3)*640,(i/3)*480))
		print("CAPTURA ",i)
	print("LAMINA error=",hoja.save_png(DIR+"lamina_interacciones.png"))
	lab.free()
	quit()
