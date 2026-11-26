extends SceneTree
const P = preload("res://herramientas/propuesta_sustituciones_assets.gd")
const IDS: Array[String] = ["setas_amarillas","caja","barril"]
var cam: Camera3D
var etiqueta: Label
var entorno: Environment
var sol: DirectionalLight3D
var mundo: Node3D
var pj: Pj3D
var suelo: MeshInstance3D
var medidas: Array = []

func _initialize() -> void:
	call_deferred("correr")

func esperar() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw

func correr() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P.DIR+"capturas"))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640,480)
	Pieza3D._cargar_bibliotecas()
	Ocluso3D.preparar()
	mundo = Node3D.new()
	root.add_child(mundo)
	var we := WorldEnvironment.new()
	entorno = Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.13,0.17,0.22)
	we.environment = entorno
	mundo.add_child(we)
	sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	mundo.add_child(sol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 200.0
	mundo.add_child(cam)
	suelo = MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(100,100)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32,0.36,0.24)
	mat.roughness = 1.0
	suelo.material_override = mat
	mundo.add_child(suelo)
	pj = Pj3D.new()
	mundo.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(-1.1,0,0)
	etiqueta = Label.new()
	etiqueta.position = Vector2(16,12)
	etiqueta.add_theme_font_size_override("font_size",24)
	etiqueta.add_theme_constant_override("outline_size",5)
	etiqueta.add_theme_color_override("font_outline_color",Color.BLACK)
	root.add_child(etiqueta)
	if "polvora" in OS.get_cmdline_user_args():
		await polvora()
		quit()
		return
	var hoja := Image.create(1440,2320,false,Image.FORMAT_RGBA8)
	hoja.fill(Color(0.08,0.12,0.17))
	for fila in 6:
		var id: String = IDS[fila/2]
		var escala_juego: bool = fila%2 == 1
		for variante in 3:
			var n: Node3D = P.crear(id,variante)
			mundo.add_child(n)
			var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
			if not escala_juego:
				medidas.append({"id":id,"variante":variante,"fuente":id if variante==0 else P.OPCIONES[id][variante-1],"alto":caja.size.y,"ancho":caja.size.x,"fondo":caja.size.z,"triangulos":P.triangulos(n)})
			for mi in n.find_children("*","MeshInstance3D",true,false):
				for s in mi.mesh.get_surface_count():
					var material: Material = mi.get_active_material(s)
					if material != null: mi.set_surface_override_material(s,Ocluso3D.convertir(material.duplicate()))
			if escala_juego:
				LuzZona3D.aplicar(entorno,sol,"bosque")
			else:
				entorno.sky = null
				entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				entorno.ambient_light_color = Color(0.85,0.9,1.0)
				entorno.ambient_light_energy = 0.65
				sol.light_color = Color.WHITE
				sol.light_energy = 0.95
				sol.rotation_degrees = Vector3(-45,-35,0)
			pj.visible = escala_juego
			suelo.visible = escala_juego
			var foco: Vector3 = Vector3(-0.25,0.5,0) if escala_juego else caja.get_center()
			cam.size = 3.5 if escala_juego else maxf(caja.size.x,maxf(caja.size.y,caja.size.z))*1.6
			cam.position = foco + Vector3(0.4,0.577,1.0).normalized()*40
			cam.look_at(foco)
			var titulo: String = "ACTUAL" if variante==0 else ("A · " if variante==1 else "B · ")+String(P.OPCIONES[id][variante-1])
			etiqueta.text = id+" / "+titulo+"\n"+("Luz bosque · jugadora 1 u" if escala_juego else "Detalle · luz neutra")
			await esperar()
			var im: Image = root.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png(P.DIR+"capturas/"+id+"_"+str(fila%2)+"_"+str(variante)+".png")
			im.resize(480,360,Image.INTERPOLATE_LANCZOS)
			hoja.blit_rect(im,Rect2i(0,0,480,360),Vector2i(variante*480,160+fila*360))
			n.free()
		print("FILA ",fila," ",id)
	mundo.visible = false
	root.size = Vector2i(1440,160)
	etiqueta.add_theme_font_size_override("font_size",26)
	etiqueta.text = "LOTE 3 · PRUEBA DE SUSTITUCIONES · 24/11/2026\nACTUAL / OPCION A / OPCION B · Detalle y escala junto a la jugadora\nSolo propuestas visuales: misma altura objetivo. No se han cambiado las asignaciones del juego."
	await esperar()
	var cabecera: Image = root.get_texture().get_image()
	cabecera.convert(Image.FORMAT_RGBA8)
	hoja.blit_rect(cabecera,Rect2i(0,0,1440,160),Vector2i.ZERO)
	var error: int = hoja.save_png(P.DIR+"lamina_sustituciones.png")
	var f := FileAccess.open(P.DIR+"medidas.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(medidas,"  "))
	print("LAMINA error=",error)
	quit(0 if error==OK else 1)

func polvora() -> void:
	var hoja := Image.create(1440,880,false,Image.FORMAT_RGBA8)
	hoja.fill(Color(0.08,0.12,0.17))
	LuzZona3D.aplicar(entorno,sol,"bosque")
	pj.visible = true
	suelo.visible = true
	for fila in 2:
		for v in 3:
			var b := Barril3D.new()
			mundo.add_child(b)
			if not P.probar_barril(b,v):
				push_error("Material no compatible con barril "+str(v))
				quit(1)
				return
			b.set_process(false)
			if fila == 1: b._poner_color_mecha(0.65)
			var foco := Vector3(-0.25,0.55,0)
			cam.size = 2.7
			cam.position = foco + Vector3(0.4,0.577,1.0).normalized()*40.0
			cam.look_at(foco)
			etiqueta.text = "BARRIL REAL · "+["ACTUAL","OPCION A","OPCION B"][v]+"\n"+("Reposo · altura 0,95 u" if fila==0 else "Vista previa del parpadeo rojo")
			await esperar()
			var im: Image = root.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png(P.DIR+"capturas/polvora_"+str(fila)+"_"+str(v)+".png")
			im.resize(480,360,Image.INTERPOLATE_LANCZOS)
			hoja.blit_rect(im,Rect2i(0,0,480,360),Vector2i(v*480,160+fila*360))
			b.free()
	mundo.visible = false
	root.size = Vector2i(1440,160)
	etiqueta.add_theme_font_size_override("font_size",26)
	etiqueta.text = "BARRIL DE POLVORA · COMPATIBILIDAD VISUAL\nACTUAL / OPCION A / OPCION B · Misma colision, radio de explosion y posicion de mecha\nSegunda fila: tinte simulado con el metodo real. No es una prueba de explosion ni de encendido completo."
	await esperar()
	var cabecera: Image = root.get_texture().get_image()
	cabecera.convert(Image.FORMAT_RGBA8)
	hoja.blit_rect(cabecera,Rect2i(0,0,1440,160),Vector2i.ZERO)
	print("LAMINA POLVORA error=",hoja.save_png(P.DIR+"lamina_barril_polvora.png"))
