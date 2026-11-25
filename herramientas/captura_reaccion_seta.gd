extends SceneTree
const DIR = "res://output/reacciones_setas_2026-11-24/"
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
	seed(12345)
	var hoja := Image.create(1920,960,false,Image.FORMAT_RGBA8)
	var vias := ["viento","hielo","agua","pulso","viento","hielo"]
	for i in 6:
		var r := Recolectable3D.new()
		r.preparar(Vector2i.ZERO,"roja")
		r.madura = true
		mundo.add_child(r)
		r.position = Vector3.ZERO
		if i >= 3:
			var p := Pulso3D.new()
			r.on_pulso(p)
			p.free()
			if i > 3: await create_timer(1.0).timeout
		if i != 3:
			var runa := RuneData.new()
			match vias[i]:
				"viento": runa.estado="gas"; runa.empuje=1.0
				"hielo": runa.modificadores={"temperatura":{"op":"fija","valor":-1.0}}
				"agua": runa.modificadores={"humedad":{"op":"fija","valor":1.0}}
			r.on_spell_hit(runa,Vector3.RIGHT)
		titulo.text = (("SETA / " if i < 3 else "PULSO + ")+vias[i].to_upper() if i != 3 else "SETA / SOLO PULSO")+"\nIngrediente: "+r.objeto
		var caja: AABB = Pieza3D._caja(r._visual,Transform3D.IDENTITY)
		var foco: Vector3 = caja.get_center()
		cam.size = maxf(caja.size.x,maxf(caja.size.y,caja.size.z))*1.65
		cam.position = foco+Vector3(0.4,0.45,1.0).normalized()*12
		cam.look_at(foco)
		await create_timer(0.35).timeout
		await esperar()
		var im: Image = root.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.save_png(DIR+"estado_"+str(i)+".png")
		hoja.blit_rect(im,Rect2i(0,0,640,480),Vector2i((i%3)*640,(i/3)*480))
		r.free()
		for h in mundo.get_children():
			if h not in [we,sol,cam]: h.free()
	print("LAMINA error=",hoja.save_png(DIR+"lamina_reacciones_setas.png"))
	quit()
