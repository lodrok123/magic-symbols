extends SceneTree
const DIR = "res://output/colmena_cuerda_2026-11-24/"
var mundo: Node3D
var cam: Camera3D
var titulo: Label
func _initialize() -> void: call_deferred("correr")
func esperar() -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
func correr() -> void:
	print("INICIO CAPTURA")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640,480)
	Terreno3D.cargar_datos(PackedStringArray(["....","....","....","...."]),{})
	Terreno3D.alto_suelo = 0.0
	Ocluso3D.preparar()
	mundo = Node3D.new()
	root.add_child(mundo)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.13,0.17,0.20)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.85,0.87,0.92)
	we.environment.ambient_light_energy = 0.75
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40,-25,0)
	sol.light_energy = 0.9
	mundo.add_child(sol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	mundo.add_child(cam)
	titulo = Label.new()
	titulo.position = Vector2(12,12)
	titulo.add_theme_font_size_override("font_size",22)
	titulo.add_theme_constant_override("outline_size",5)
	root.add_child(titulo)
	var hoja := Image.create(2560,960,false,Image.FORMAT_RGBA8)
	for fila in 2:
		for columna in 4:
			print("CREAR ",fila," ",columna)
			var n: Node3D = Colmena3D.new() if fila == 0 else Cuerda3D.new()
			mundo.add_child(n)
			print("CREADA")
			var visual: Node3D = n._visual if fila == 0 else n
			var caja: AABB = Pieza3D._caja(visual,Transform3D.IDENTITY)
			if fila == 0:
				if columna == 1:
					n.caer_panal()
					await create_timer(0.42).timeout
				if columna >= 2:
					n.arder()
					n.set_process(false)
					n._process(0.4 if columna == 2 else 0.95)
				titulo.text = "COLMENA / "+["REPOSO","VIENTO / VACIA","FUEGO / CERA ARDIENDO","CERA CONSUMIDA"][columna]+"\n"+["Panal y soporte separados","Mismo estado al recargar","Veneno activo desde el inicio","Se conserva el soporte"][columna]
			else:
				if columna > 0:
					n.arder()
					n.set_process(false)
					n._process(0.4 if columna < 3 else 1.05)
				if columna == 2: n._apagar()
				titulo.text = "CUERDA / "+["REPOSO","ARDIENDO / 40 %","APAGADA CON AGUA","ROTA"][columna]+"\n"+["Modelo original","Frente de brasa y llamas","Conserva el chamuscado","Cabo caido; soporte intacto"][columna]
			var foco: Vector3 = caja.get_center()
			cam.size = maxf(0.7,maxf(caja.size.x,maxf(caja.size.y,caja.size.z))*1.65)
			cam.position = foco+Vector3(0.4,0.45,1.0).normalized()*12
			cam.look_at(foco)
			await esperar()
			print("DIBUJADA")
			var im: Image = root.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png(DIR+str(fila)+"_"+str(columna)+".png")
			hoja.blit_rect(im,Rect2i(0,0,640,480),Vector2i(columna*640,fila*480))
			n.free()
			for h in mundo.get_children():
				if h not in [we,sol,cam]: h.free()
	print("LAMINA error=",hoja.save_png(DIR+"lamina_colmena_cuerda.png"))
	quit()
