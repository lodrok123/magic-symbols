extends SceneTree
## El fantasma elfo (fantasma_elfo_rig.glb) ANIMADO con los clips de la elfa (chibi_elf.glb) traducidos por ClipsFamilia.
## Es la prueba que de verdad importa: el rig no se juzga con poses inventadas, sino con el andar y los conjuros que va a usar en el juego.
## NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_clips_fantasma.gd
## Salida en res://docs/capturas/fantasma_rig/: clip_<nombre>.png, una hoja de cuatro instantes del ciclo (frente) por clip.

## Sin argumentos usa el fantasma; con `-- <id>` usa res://arte/modelos/<id>.glb y guarda en res://docs/capturas/<id>/.
## Con `-- <id> <clip> [clip...]` fotografía ESOS clips en vez de los de CLIPS (para mirar uno concreto: una muerte, una voltereta).
## Opciones, en cualquier orden entre los clips:
##   inst=<n>     cuántos instantes del clip se fotografían (4 por defecto). Se reparten en filas de CUATRO: inst=8 da una hoja de dos filas.
##                Un ciclo de paso se lee en cuartos, pero una voltereta o una caída necesitan más.
##   vista=lado   de perfil en vez de frente (`vista=ambas` saca las dos hojas: clip_<nombre>.png y clip_<nombre>_lado.png).
##                Una voltereta o una muerte NO se leen de frente: hay que verlas de lado para saber qué hace el cuerpo.
## CÓMO SE LEE EL SUELO EN ESTAS FOTOS (9/11, apuntado porque me engañó): la cámara mira horizontal, así que el suelo ocupa desde el borde
## de abajo hasta el horizonte, que queda a media foto. Un personaje de pie se ve con el cuerpo RECORTADO CONTRA esa banda y con más banda
## por debajo de él: eso es el suelo que sigue hacia la cámara, no el personaje medio enterrado. Leyéndolo mal se ve hundimiento donde no lo
## hay. Para saber de verdad si un cuerpo pisa o se hunde, la respuesta es la MEDIDA (herramientas/medidas_hundimiento.gd), no la foto; y
## herramientas/medidas_montaje_captura.gd comprueba que el montaje de esta herramienta da la misma altura que Pj3D en el juego.
##   margen=<f>   cuánto encuadre se deja alrededor del personaje (1,4 por defecto = el alto del modelo ocupa 1/1,4 de la altura de la foto).
##                Una pose tumbada ocupa a lo ancho casi un alto entero: con margen=1.8 cabe entera.
const ID_POR_DEFECTO: String = "fantasma_elfo_rig"
const FUENTE: String = "res://arte/modelos/chibi_elf.glb"
var _id: String = ID_POR_DEFECTO
var _glb: String = ID_POR_DEFECTO
var DIR: String = ""
var GLB: String = ""
const CLIPS: Array[String] = ["Walking", "Running", "Idle", "MageSoellCast001", "Dead"]
## Roles que solo existen cuando el modelo (o su variante) está en ClipsFamilia.FUENTES: el andar propio de cada portador.
const EXTRA: Array[String] = ["walk", "run"]
## Cuántos instantes del clip se fotografían por defecto (un ciclo de paso se lee bien en cuartos) y cuántos caben en una fila de la hoja.
const INSTANTES_POR_DEFECTO: int = 4
const POR_FILA: int = 4
const ANCHO: int = 640         ## recorte de cada instante dentro de la ventana de 1280x720
const ALTO_FOTO: int = 720
## Encuadre: el alto del modelo ocupa 1/MARGEN de la altura de la foto, y la cámara se aleja lo que haga falta para eso. Antes estaba fijo
## a la medida del fantasma (foco 0,48 y distancia 3) y a la jugadora, que es más alta, la cortaba por la cintura.
const MARGEN_POR_DEFECTO: float = 1.4
const FOV: float = 24.0
var _cam: Camera3D = null
var _instantes: int = INSTANTES_POR_DEFECTO
var _margen: float = MARGEN_POR_DEFECTO
var _vista: String = "frente"


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_id = args[0] if args.size() > 0 and args[0] != "" else ID_POR_DEFECTO
	var pedidos: Array[String] = []
	for i in range(1, args.size()):
		var a: String = String(args[i])
		if a.begins_with("inst="):
			_instantes = maxi(1, int(a.trim_prefix("inst=")))
		elif a.begins_with("vista="):
			_vista = a.trim_prefix("vista=")
		elif a.begins_with("margen="):
			_margen = maxf(1.0, float(a.trim_prefix("margen=")))
		else:
			pedidos.append(a)
	# El id puede ser una VARIANTE que comparte GLB (Pj3D.MODELO_DE): el cuerpo sale del modelo y el equipo, del id.
	_glb = String(Pj3D.MODELO_DE.get(_id, _id))
	GLB = "res://arte/modelos/%s.glb" % _glb
	DIR = "res://docs/capturas/%s" % _id
	if _glb != _id:
		print("variante: %s -> modelo %s" % [_id, _glb])
	if not ResourceLoader.exists(GLB):
		push_error("no existe " + GLB)
		quit(1)
		return
	print("modelo: ", GLB)
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.fov = FOV
	root.add_child(_cam)
	var modelo: Node3D = (load(GLB) as PackedScene).instantiate()
	root.add_child(modelo)
	var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame          # el AABB en el mundo necesita que el modelo esté ya en el árbol
	_medir_encuadre(modelo)
	# Si el modelo tiene equipo (cruz, vela, bastón…), se monta igual que en el juego para verlo en la mano con los clips.
	var equipo: Array[Node3D] = Equipo3D.equipar(_id, modelo)
	if not equipo.is_empty():
		print("equipo puesto: ", equipo.map(func(n): return String(n.get_meta("equipo_id", n.name))))
	var ap := AnimationPlayer.new()
	modelo.add_child(ap)
	var lib := AnimationLibrary.new()
	var puestos: Array[String] = []
	# Igual que Pj3D: si la VARIANTE tiene fuentes propias se usan las suyas (así se ve qué andar le toca a cada portador);
	# si no, se traducen los de la elfa uno a uno.
	if ClipsFamilia.tiene_fuente(_id):
		var todos: Dictionary = ClipsFamilia.clips_para(_id, modelo, sk)
		print("clips de la variante: ", todos.keys().size())
		for c in (pedidos if not pedidos.is_empty() else CLIPS + EXTRA):
			if todos.has(c):
				lib.add_animation(String(c), todos[c] as Animation)
				puestos.append(String(c))
	else:
		for c in (pedidos if not pedidos.is_empty() else CLIPS):
			var an: Animation = ClipsFamilia.traducir_clip(_glb, FUENTE, c, modelo, sk)
			if an == null:
				print("NO se pudo traducir: ", c)
				continue
			lib.add_animation(c, an)
			puestos.append(c)
	_corregir_postura(lib)
	ap.add_animation_library("", lib)
	print("clips traducidos: ", puestos)
	if puestos.is_empty():
		quit(1)
		return
	await process_frame
	for c in puestos:
		await _hoja(ap, sk, c)
	quit(0)


## Mismo giro fijo por hueso que aplica Pj3D (CORRECCION_POSTURA), para que la foto enseñe la postura del juego y no la del GLB.
func _corregir_postura(lib: AnimationLibrary) -> void:
	if not Pj3D.CORRECCION_POSTURA.has(_id):
		return
	var giros: Dictionary = Pj3D.CORRECCION_POSTURA[_id]
	print("corrección de postura: ", giros.keys())
	for nombre in lib.get_animation_list():
		var an: Animation = lib.get_animation(nombre)
		for t in range(an.get_track_count()):
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var hueso: String = str(an.track_get_path(t)).get_slice(":", 1)
			if not giros.has(hueso):
				continue
			var g: Vector3 = giros[hueso]
			var extra: Quaternion = Quaternion.from_euler(Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)))
			for i in range(an.track_get_key_count(t)):
				an.track_set_key_value(t, i, extra * (an.track_get_key_value(t, i) as Quaternion))


## Alto del modelo y punto al que mira la cámara, medidos del esqueleto en reposo. Sin esto el encuadre era el del fantasma y nada más.
var _alto: float = 0.9
var _foco: Vector3 = Vector3(0, 0.48, 0)


## Se mide la MALLA, no los huesos: el esqueleto puede traer su propia escala (el de la jugadora la trae, y medido por huesos el
## alto salía 0,02) y además el pelo y la capucha sobresalen de la coronilla, que es el hueso más alto.
func _medir_encuadre(modelo: Node3D) -> void:
	var caja := AABB()
	var primero: bool = true
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var c: AABB = mi.global_transform * mi.get_aabb()
		caja = c if primero else caja.merge(c)
		primero = false
	if primero or caja.size.y <= 0.0:
		return
	# APOYAR EN EL SUELO, igual que Pj3D._apoyar_en_el_suelo al cargar: el GLB no tiene por qué traer los pies en y = 0 ni el
	# cuerpo centrado sobre la vertical. Sin esto la foto enseña al personaje a una altura que NO es la del juego, y a ras de
	# suelo parecía que se hundía medio cuerpo cuando en el juego no se hunde nada.
	modelo.position -= Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5)
	_alto = caja.size.y
	_foco = Vector3(0, _alto * 0.5, 0)
	print("encuadre: alto %.2f, foco y %.2f (el modelo se baja %.3f para apoyarlo)" % [_alto, _foco.y, caja.position.y])


func _hoja(ap: AnimationPlayer, sk: Skeleton3D, clip: String) -> void:
	for v in (["frente", "lado"] if _vista == "ambas" else [_vista]):
		await _hoja_vista(ap, sk, clip, String(v))


func _hoja_vista(ap: AnimationPlayer, sk: Skeleton3D, clip: String, vista: String) -> void:
	var an: Animation = ap.get_animation(clip)
	var largo: float = an.length
	var filas: int = int(ceil(float(_instantes) / float(POR_FILA)))
	var columnas: int = mini(_instantes, POR_FILA)
	var hoja := Image.create_empty(ANCHO * columnas, ALTO_FOTO * filas, false, Image.FORMAT_RGB8)
	# A qué distancia cabe el personaje: con un fov vertical de FOV grados, a distancia d se ve 2·d·tan(FOV/2) de alto.
	var dist: float = (_alto * _margen) / (2.0 * tan(deg_to_rad(FOV) * 0.5))
	# Cámara a la ALTURA del foco, sin mirar hacia abajo: así una pieza vertical se ve vertical. Con la cámara inclinada, las
	# verticales del mundo convergen y un bastón en el borde del encuadre parece torcido aunque esté recto.
	var desde: Vector3 = (Vector3(1.0, 0.0, 0.0) if vista == "lado" else Vector3(0.35, 0.0, 1.0)).normalized()
	var i_cad: int = sk.find_bone("mixamorig_Hips")
	for k in _instantes:
		# El último instante NO es el final del clip: en un bucle coincide con el primero y se desperdicia una foto.
		var t: float = largo * float(k) / float(_instantes)
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
		for i in 3:
			await process_frame
		# La cámara SIGUE al personaje en horizontal, pero no en vertical: una voltereta o un empujón avanzan y se salían del
		# encuadre, y si además siguiera la altura el suelo bailaría en la foto y no se podría ver si el cuerpo lo atraviesa.
		var centro: Vector3 = _foco
		if i_cad >= 0:
			var c: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_cad).origin
			centro = Vector3(c.x, _foco.y, c.z)
		_cam.look_at_from_position(centro + desde * dist, centro)
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		hoja.blit_rect(img, Rect2i((1280 - ANCHO) / 2, 0, ANCHO, ALTO_FOTO),
			Vector2i(ANCHO * (k % POR_FILA), ALTO_FOTO * (k / POR_FILA)))
	var sufijo: String = "" if vista == "frente" else "_" + vista
	hoja.save_png(DIR.path_join("clip_%s%s.png" % [clip, sufijo]))
	print("hoja ", clip, sufijo, "  (", String.num(largo, 2), " s, ", _instantes, " instantes)")


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(20, 20)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.3, 0.32, 0.36)
	suelo.material_override = mt
	root.add_child(suelo)
