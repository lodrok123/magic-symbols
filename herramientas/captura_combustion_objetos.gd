extends SceneTree
const LAB = preload("res://laboratorios/lab_combustion_objetos.gd")
const DIR = "res://output/combustion_2026-11-24/"
func _initialize() -> void: call_deferred("correr")
func esperar() -> void:
	for i in 14: await process_frame
	await RenderingServer.frame_post_draw
func correr() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960,640)
	var lab = LAB.new()
	root.add_child(lab)
	var hoja := Image.create(1920,1920,false,Image.FORMAT_RGBA8)
	for fase in 6:
		if fase == 0:
			lab.etiqueta.text = "COMBUSTION / 1. REPOSO\nAssets reales / telaraña y barril de madera"
		elif fase == 1:
			for r in lab.piezas:
				r.ignite(r.global_position+Vector3(-0.15,0.35,0.15))
				r.set_process(false)
				r._process(float(r._num_combustible()[0])*0.18)
			lab.etiqueta.text = "COMBUSTION / 2. PRENDE (18 %)\nFocos adheridos / frente desde el impacto"
		elif fase == 2:
			for r in lab.piezas: r._process(float(r._num_combustible()[0])*0.34)
			lab.etiqueta.text = "COMBUSTION / 3. ARDE (52 %)\nHilos consumidos / madera carbonizada"
		elif fase == 3:
			for r in lab.piezas: r._apagar()
			lab.etiqueta.text = "COMBUSTION / 4. AGUA\nSin llamas ni brasas / daño visible y humedad"
		elif fase == 4:
			for r in lab.piezas:
				r.ignite()
				r.set_process(false)
				r._process(float(r._num_combustible()[0]))
			lab.etiqueta.text = "COMBUSTION / 5. CONSUMIDO\nPaso libre / restos de madera sin colisión"
			await create_timer(0.6).timeout
		else:
			lab.etiqueta.text = "COMBUSTION / 6. RESTOS\nHumo residual / tablas carbonizadas temporales"
			await create_timer(0.9).timeout
		await esperar()
		var im: Image = root.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.save_png(DIR+"fase_"+str(fase)+".png")
		hoja.blit_rect(im,Rect2i(0,0,960,640),Vector2i((fase%2)*960,(fase/2)*640))
	print("LAMINA error=",hoja.save_png(DIR+"lamina_combustion.png"))
	lab.free()
	quit()
