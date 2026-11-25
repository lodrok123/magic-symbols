extends SceneTree
const DIR = "res://output/blender_interacciones_2026-11-25/"
var fallos := 0
func _initialize() -> void: call_deferred("correr")
func comprobar(ok: bool, detalle: String) -> void:
	print("OK " if ok else "FALLO ",detalle)
	if not ok: fallos += 1
func correr() -> void:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string(DIR+"inventario_blender.json"))
	var fuentes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"fuentes.json"))
	var mundo := Node3D.new()
	root.add_child(mundo)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color("23303b")
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.85,0.9,1)
	we.environment.ambient_light_energy = 0.7
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	mundo.add_child(sol)
	sol.rotation_degrees = Vector3(-48,-35,0)
	sol.light_energy = 1.3
	var titulo := Label.new()
	titulo.position = Vector2(20,12)
	titulo.add_theme_font_size_override("font_size",24)
	titulo.add_theme_constant_override("outline_size",4)
	root.add_child(titulo)
	root.size = Vector2i(960,480)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var hoja := Image.create(1920,2880,false,Image.FORMAT_RGBA8)
	for i in lista.size():
		var dato: Dictionary = lista[i]
		var n: Node3D = (load("res://"+String(dato.glb)) as PackedScene).instantiate()
		mundo.add_child(n)
		var mallas: Array[Node] = n.find_children("*","MeshInstance3D",true,false)
		comprobar(mallas.size()==int(dato.mallas),String(dato.id)+" mallas")
		comprobar(n.find_children("*","CollisionObject3D",true,false).is_empty(),String(dato.id)+" sin colisiones")
		comprobar(FileAccess.file_exists("res://"+String(dato.blend)),String(dato.id)+" editable")
		var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
		comprobar(caja.size.length()>0.05,String(dato.id)+" volumen")
		if String(dato.id).ends_with("fragmentos"):
			comprobar(mallas.size()==8,String(dato.id)+" ocho fragmentos")
			for m: MeshInstance3D in mallas:
				m.position += (m.position-caja.get_center())*0.55
		if dato.id == "barril_articulado":
			var bisagra: Node3D = n.find_child("bisagra_tapa",true,false)
			comprobar(bisagra != null,"bisagra de tapa")
			var ap := n.find_children("*","AnimationPlayer",true,false)
			comprobar(not ap.is_empty(),"animación importada")
			if not ap.is_empty():
				var anim: AnimationPlayer = ap[0]
				comprobar(anim.get_animation_list().size()>0,"clip de apertura")
				anim.play(anim.get_animation_list()[0]); anim.seek(1.0,true); anim.pause()
				comprobar(absf(bisagra.rotation.x)>1.0,"La animación mueve la bisagra")
		var original: Node3D
		if fuentes.has(dato.fuente) and DisplayServer.get_name() != "headless":
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(fuentes[dato.fuente],state)==OK: original=doc.generate_scene(state)
		if original != null:
			mundo.add_child(original)
		var dimension: float = maxf(caja.size.x,maxf(caja.size.y,caja.size.z))
		var factor: float = 1.5/maxf(dimension,0.1)
		n.scale *= factor
		n.position = Vector3(1.05,0,0)-Vector3(caja.get_center().x,caja.position.y,caja.get_center().z)*factor
		if original != null:
			original.scale *= factor
			original.position = Vector3(-1.05,0,0)-Vector3(caja.get_center().x,caja.position.y,caja.get_center().z)*factor
		cam.size = 5.5
		cam.position = Vector3(3,3.3,7)+Vector3(0,0.65,0)
		cam.look_at(Vector3(0,0.65,0))
		titulo.text = String(dato.id).replace("_"," ").to_upper()+"\nOriginal (izq.) / Blender (der.)"
		if dato.fuente == "procedural": titulo.text = "CENIZA Y CARBONES · GEOMETRÍA NUEVA"
		if dato.id == "bayas_separadas": titulo.text += " · Frutos separados"
		if DisplayServer.get_name() != "headless":
			for j in 10: await process_frame
			await RenderingServer.frame_post_draw
			var im := root.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png(DIR+String(dato.id)+".png")
			hoja.blit_rect(im,Rect2i(0,0,960,480),Vector2i((i%2)*960,(i/2)*480))
		n.free()
		if original != null: original.free()
	if DisplayServer.get_name() != "headless": hoja.save_png(DIR+"lamina_blender.png")
	await probar_integracion(mundo)
	print("TOTAL DE FALLOS: ",fallos)
	quit(0 if fallos==0 else 1)

func probar_integracion(mundo: Node3D) -> void:
	Terreno3D.cargar_datos(PackedStringArray(["..........","..........","..........",".........."]),{})
	Terreno3D.alto_suelo=0.0
	Flags.nuevo(); Estado.nuevo()
	for tipo in ["caja","jarron"]:
		for alternativo in [false,true]:
			var r := Rompible3D.new()
			r.name="prueba_blender"
			r.preparar(Vector2i(2,2),tipo,"nada",0,alternativo,"")
			mundo.add_child(r)
			var original: AABB = Pieza3D._caja(r._modelo,Transform3D.IDENTITY)
			r._trozos(true)
			comprobar(r.n_restos()==8,tipo+" ocho piezas reales en partida")
			var recompuesto: AABB = Pieza3D._caja(r._restos,Transform3D.IDENTITY)
			comprobar(original.size.distance_to(recompuesto.size)<0.02 and original.get_center().distance_to(recompuesto.get_center())<0.02,tipo+" fragmentos parten de la geometría original")
			await create_timer(0.6).timeout
			var poses: Array[Transform3D]=[]
			for p: Node3D in r._restos.get_children():
				poses.append(p.transform)
				var suelo: AABB = Pieza3D._caja(p,Transform3D.IDENTITY)
				comprobar(absf(suelo.position.y-0.008)<0.005,tipo+" fragmento asentado en suelo")
			var nombre: String = String(r.name)
			r.free()
			var recarga := Rompible3D.new()
			recarga.name=nombre
			recarga.preparar(Vector2i(2,2),tipo,"nada",0,alternativo,"qa_blender")
			Flags.i().poner(recarga.flag())
			mundo.add_child(recarga)
			comprobar(recarga.roto_ya and recarga._modelo==null and recarga.n_restos()==8,tipo+" nace roto por flag")
			var coincide := true
			for j in poses.size(): coincide = coincide and poses[j].is_equal_approx(recarga._restos.get_child(j).transform)
			comprobar(coincide,tipo+" rotura y recarga dejan la misma pose")
			recarga.free()
			Flags.nuevo()
	var planta := Recolectable3D.new()
	planta.preparar(Vector2i(3,3),"",0.2,null,"bayas")
	mundo.add_child(planta)
	comprobar(planta._visual.find_child("frutos",true,false)!=null,"Arbusto usa frutos separados")
	comprobar(planta.recoger(),"Recolección con nuevo modelo")
	var frutos: Node3D = planta._residuo.find_child("frutos",true,false)
	comprobar(frutos!=null and not frutos.visible,"Agotamiento oculta frutos geométricos")
	comprobar(planta._residuo.find_children("*","CollisionObject3D",true,false).is_empty(),"Arbusto agotado sin colisiones")
	planta._process(0.3)
	comprobar(planta._residuo==null and not planta.recogido_ya,"Rebrote recupera frutos")
	planta.free()
