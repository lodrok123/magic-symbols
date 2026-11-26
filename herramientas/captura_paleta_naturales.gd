extends SceneTree
## Láminas reproducibles del lote 2: seis assets antes/después, con luz neutra y
## perfil real de agua/cueva. Además, comparativas dentro de los dos niveles.
const DIR: String = "res://output/paleta_naturales_2026-11-24/"
const IDS: Array[String] = ["roca_rio_0", "roca_rio_1", "roca_rio_2", "lost_bush", "lost_fern_a", "lost_greentrees"]
var cam: Camera3D
var etiqueta: Label
var entorno: WorldEnvironment
var sol: DirectionalLight3D
var mundo: Node3D
var pj: Pj3D
var fondo: MeshInstance3D

func _initialize() -> void:
	call_deferred("correr")

func esperar(n: int = 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func foto() -> Image:
	await esperar()
	var im: Image = root.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im

func rotulo(texto: String, tam: int = 24) -> void:
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size",tam)

func pieza(id: String, despues: bool) -> Node3D:
	if id.begins_with("lost_"):
		var ruta: String = "res://arte/lostcave/piezas/"+id+".tscn" if despues else DIR+"antes/"+id+".tscn"
		var n: Node3D = (load(ruta) as PackedScene).instantiate()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(s)
				if mat != null: mi.set_surface_override_material(s,Ocluso3D.convertir(mat.duplicate()))
		return n
	var modelo: Dictionary = LechoRio3D._modelo(id,LechoRio3D.ROCA_DIAM,false,false,0.78)
	var n := Node3D.new()
	n.scale = Vector3.ONE * float(modelo.escala)
	for p in modelo.partes:
		var mi := MeshInstance3D.new()
		mi.mesh = p.malla
		mi.transform = p.tf
		mi.material_override = LechoRio3D._material_adorno(p.malla,false,0.78,id if despues else "")
		n.add_child(mi)
	return n

func perfil(zona: String) -> void:
	if zona != "neutra":
		LuzZona3D.aplicar(entorno.environment,sol,zona)
		return
	entorno.environment.sky = null
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.85,0.9,1.0)
	entorno.environment.ambient_light_energy = 0.65
	sol.light_color = Color.WHITE
	sol.light_energy = 0.95
	sol.rotation_degrees = Vector3(-45,-35,0)

func correr() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR+"capturas"))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640,480)
	Ocluso3D.preparar()
	mundo = Node3D.new()
	root.add_child(mundo)
	entorno = WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.13,0.17,0.22)
	mundo.add_child(entorno)
	sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	mundo.add_child(sol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 300.0
	mundo.add_child(cam)
	fondo = MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200,200)
	fondo.mesh = plano
	var mat_suelo := StandardMaterial3D.new()
	mat_suelo.albedo_color = Color(0.36,0.33,0.28)
	mat_suelo.roughness = 1.0
	fondo.material_override = mat_suelo
	mundo.add_child(fondo)
	pj = Pj3D.new()
	mundo.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(-1.6,0,0)
	etiqueta = Label.new()
	etiqueta.position = Vector2(14,10)
	etiqueta.add_theme_constant_override("outline_size",6)
	etiqueta.add_theme_color_override("font_outline_color",Color.BLACK)
	root.add_child(etiqueta)
	var hoja: Image = Image.create(1600,1960,false,Image.FORMAT_RGBA8)
	hoja.fill(Color(0.08,0.12,0.17))
	for fila in IDS.size():
		var id: String = IDS[fila]
		for col in 4:
			var despues: bool = col%2 == 1
			var contextual: bool = col >= 2
			var n: Node3D = pieza(id,despues)
			mundo.add_child(n)
			var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
			perfil(("cueva" if id.begins_with("lost_") else "agua") if contextual else "neutra")
			pj.visible = contextual
			fondo.visible = contextual
			var foco: Vector3 = Vector3(-0.4,0.7,0) if contextual else caja.get_center()
			cam.size = 6.0 if contextual else maxf(caja.size.x,maxf(caja.size.y,caja.size.z))*1.6
			cam.position = foco + Vector3(0.3,0.577,1.0).normalized()*40.0
			cam.look_at(foco)
			var estado: String = "DESPUES" if despues else "ANTES"
			rotulo(id+" · "+estado+"\n"+("Luz "+("cueva" if id.begins_with("lost_") else "agua")+" · camara 6 u" if contextual else "Detalle · luz neutra"))
			var im: Image = await foto()
			im.save_png(DIR+"capturas/"+id+"_"+str(col)+".png")
			im.resize(400,300,Image.INTERPOLATE_LANCZOS)
			hoja.blit_rect(im,Rect2i(0,0,400,300),Vector2i(col*400,160+fila*300))
			n.free()
		print("CAPTURADO ",id)
	mundo.visible = false
	root.size = Vector2i(1600,160)
	rotulo("PALETA NATURAL · LOTE 2 · REVISION 24/11/2026\nDETALLE: ANTES / DESPUES     |     A ESCALA: ANTES / DESPUES\nMisma geometria y camara. Rocas: menos blanco y musgo mas suave. Follaje: verde moderado y corte alfa 0,40.",26)
	var cabecera: Image = await foto()
	hoja.blit_rect(cabecera,Rect2i(0,0,1600,160),Vector2i.ZERO)
	hoja.save_png(DIR+"lamina_revision.png")
	mundo.free()
	if "solo_lamina" not in OS.get_cmdline_user_args(): await niveles()
	quit()

func ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer: h.visible = false
		ocultar_ui(h)

func niveles() -> void:
	root.size = Vector2i(1000,600)
	var hoja: Image = Image.create(1600,1080,false,Image.FORMAT_RGBA8)
	hoja.fill(Color(0.08,0.12,0.17))
	for fila in 2:
		var cueva: bool = fila == 1
		var ruta: String = "res://escenas/PruebaLostCave.tscn" if cueva else "res://escenas/PruebaBosque01.tscn"
		var m: Node3D = (load(ruta) as PackedScene).instantiate()
		root.add_child(m)
		await esperar(100)
		ocultar_ui(root)
		m.set("_jugador",null)
		var foco: Vector3 = Vector3(14.5*2.3,0.7,22.0*2.3)
		var cambios: Array = []
		if not cueva:
			var adornos: Node3D = m.get("_adornos_lecho")
			if adornos != null:
				for p in adornos.get_meta("piezas",[]):
					if String(p.id).begins_with("roca_rio_"):
						foco = p.base + Vector3(0,0.6,0)
						break
				for mi in adornos.get_children():
					if mi is MultiMeshInstance3D and String(mi.name).begins_with("roca_rio_"):
						var actual: ShaderMaterial = mi.material_override
						var viejo: ShaderMaterial = actual.duplicate()
						var fuente: BaseMaterial3D = mi.multimesh.mesh.surface_get_material(0)
						viejo.set_shader_parameter("t_albedo",fuente.albedo_texture)
						cambios.append([mi,-1,viejo,actual])
		else:
			var posiciones: Array[Vector3] = []
			for n in m.find_children("*","Node3D",true,false):
				var id: String = String(n.get_meta("id",""))
				if id not in IDS: continue
				posiciones.append(n.global_position)
				var original: Node3D = (load(DIR+"antes/"+id+".tscn") as PackedScene).instantiate()
				var om: MeshInstance3D = original.get_node("modelo/malla")
				var nm: MeshInstance3D = n.get_node_or_null("modelo/malla")
				if nm != null:
					for s in nm.mesh.get_surface_count():
						var viejo: Material = Ocluso3D.convertir(om.get_active_material(s).duplicate())
						cambios.append([nm,s,viejo,nm.get_active_material(s)])
				original.free()
			if not posiciones.is_empty():
				foco = Vector3.ZERO
				for p in posiciones: foco += p
				foco = foco / posiciones.size() + Vector3(0,0.8,0)
		m.set("_foco",foco)
		m.set("_tam_camara",20.0 if cueva else 7.0)
		m.call("_colocar_camara")
		(m.get("_camara") as Camera3D).size = 12.0 if cueva else 7.0
		m.process_mode = Node.PROCESS_MODE_DISABLED
		for col in 2:
			for c in cambios:
				if int(c[1]) < 0: c[0].material_override = c[2+col]
				else: c[0].set_surface_override_material(c[1],c[2+col])
			rotulo(("LOST CAVE" if cueva else "BOSQUE · ROCAS DEL RIO")+" · "+("ANTES" if col == 0 else "DESPUES")+"\nNivel real · misma camara e iluminacion",24)
			var im: Image = await foto()
			im.save_png(DIR+"capturas/nivel_"+str(fila)+"_"+str(col)+".png")
			im.resize(800,480,Image.INTERPOLATE_LANCZOS)
			hoja.blit_rect(im,Rect2i(0,0,800,480),Vector2i(col*800,120+fila*480))
		print("NIVEL CAPTURADO ",ruta," cambios=",cambios.size())
		m.free()
		await esperar(4)
	root.size = Vector2i(1600,120)
	rotulo("REVISION EN NIVEL · ANTES / DESPUES\nSolo se alternan los materiales del lote. No se modifica el mapa ni la distribucion de las piezas.",28)
	var cabecera: Image = await foto()
	hoja.blit_rect(cabecera,Rect2i(0,0,1600,120),Vector2i.ZERO)
	hoja.save_png(DIR+"lamina_en_nivel.png")
