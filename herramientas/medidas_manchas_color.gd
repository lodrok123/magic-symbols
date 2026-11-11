extends SceneTree
## CAZADOR DE MANCHAS DE UN COLOR en un personaje vestido, a lo largo de TODOS sus clips (11/11, Pablo: «revisa la última prenda para ver
## por qué aparecen manchas violetas al hacer acciones»).
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/medidas_manchas_color.gd -- <id> [sin=<prenda>,<prenda>] [tono=<grados>] [clip...]
## Reproduce cada clip, lo fotografía en varios instantes desde cuatro lados y cuenta los píxeles cuyo tono cae cerca de `tono` (270 = violeta)
## con saturación y brillo suficientes. Imprime los clips de más a menos mancha y guarda la foto del peor instante de cada uno de los seis
## peores en res://docs/capturas/manchas_<id>/. `sin=` quita prendas de las que lleva por defecto, para saber cuál la provoca.

const ALTO: float = 1.0
const INSTANTES: int = 8
const VISTAS: Array[Vector3] = [Vector3(0, 0.15, 1), Vector3(1, 0.15, 0.2), Vector3(0, 0.15, -1), Vector3(-1, 0.15, 0.2)]
const ANCHO_TONO: float = 28.0      ## grados a cada lado
const SAT_MIN: float = 0.30
const VAL_MIN: float = 0.25
const PEORES: int = 6


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args: Array = Array(OS.get_cmdline_user_args())
	var id: String = String(args[0]) if args.size() > 0 else "jugadora_base"
	var tono: float = 270.0
	var sin: PackedStringArray = []
	var pedidos: Array[String] = []
	var con_muro: bool = false
	for i in range(1, args.size()):
		var a: String = String(args[i])
		if a.begins_with("tono="):
			tono = float(a.trim_prefix("tono="))
		elif a.begins_with("sin="):
			sin = a.trim_prefix("sin=").split(",")
		elif a == "muro":
			# CONTRAPRUEBA: un muro opaco entre la cámara y el personaje, que le tapa de cintura para abajo. Ahí la silueta de
			# «tapada» SÍ tiene que salir. Sin esto, «cero píxeles» también lo daría una silueta que hubiera dejado de pintarse.
			con_muro = true
		else:
			pedidos.append(a)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.5, 0.5)          # gris neutro: sin tono, no cuenta
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	root.add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.05
	root.add_child(cam)
	var p := Pj3D.new()
	root.add_child(p)
	p.cargar(id)
	p.set_alto(ALTO)
	await process_frame
	if not sin.is_empty():
		for pr in sin:
			p.quitar_ropa(String(pr))
		print("prendas puestas: ", p.ropa_puesta(), "  (sin ", sin, ")")
		await process_frame
	var ap: AnimationPlayer = p._ap
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var muro: MeshInstance3D = null
	if con_muro:
		muro = MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(1.6, ALTO * 0.5, 0.2)
		muro.mesh = caja
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.55, 0.55, 0.5)
		muro.material_override = mm
		root.add_child(muro)
	var clips: Array = pedidos if not pedidos.is_empty() else Array(ap.get_animation_list())
	var foco := Vector3(0, ALTO * 0.5, 0)
	var res: Array = []          # [píxeles, clip, instante, vista, Image]
	for clip in clips:
		if not ap.has_animation(String(clip)):
			continue
		var largo: float = ap.get_animation(String(clip)).length
		var peor: int = -1
		var peor_dato: Array = []
		var total: int = 0
		for k in INSTANTES:
			ap.play(String(clip))
			ap.seek(largo * float(k) / float(INSTANTES), true)
			for i in 6:
				await process_frame
			# la cámara sigue al personaje en horizontal (hay clips que avanzan)
			var c: Vector3 = p.global_position
			var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
			if not sks.is_empty():
				var sk: Skeleton3D = sks[0] as Skeleton3D
				var ih: int = sk.find_bone("mixamorig_Hips")
				if ih >= 0:
					c = sk.global_transform * sk.get_bone_global_pose(ih).origin
			var centro := Vector3(c.x, foco.y, c.z)
			for v in VISTAS.size():
				cam.look_at_from_position(centro + VISTAS[v].normalized() * 4.2, centro)
				if muro != null:
					var hacia: Vector3 = VISTAS[v].normalized()
					hacia.y = 0.0
					muro.global_position = Vector3(centro.x, ALTO * 0.25, centro.z) + hacia.normalized() * 1.2
					muro.look_at(Vector3(centro.x, ALTO * 0.25, centro.z), Vector3.UP)
				await process_frame
				await process_frame
				var img: Image = root.get_viewport().get_texture().get_image()
				var n: int = _contar(img, tono)
				total += n
				if n > peor:
					peor = n
					peor_dato = [n, String(clip), largo * float(k) / float(INSTANTES), v, img]
		res.append([total, String(clip), peor_dato])
		print("  %-26s  total %6d   peor instante %5d px (t %.2f, vista %d)" % [clip, total, peor, float(peor_dato[2]), int(peor_dato[3])])
	res.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var dir: String = "res://docs/capturas/manchas_%s" % id
	DirAccess.make_dir_recursive_absolute(dir)
	print("--- los %d peores (tono %.0f°):" % [PEORES, tono])
	for i in mini(PEORES, res.size()):
		var d: Array = res[i][2]
		var sufijo: String = ("_sin_" + "_".join(sin)) if not sin.is_empty() else ""
		(d[4] as Image).save_png(dir.path_join("%s%s.png" % [res[i][1], sufijo]))
		print("  %s: %d px en total; foto del peor instante guardada" % [res[i][1], int(res[i][0])])
	quit(0)


func _contar(img: Image, tono: float) -> int:
	var n: int = 0
	# uno de cada dos píxeles en cada eje: de sobra para contar manchas
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.s < SAT_MIN or c.v < VAL_MIN:
				continue
			var dh: float = absf(fposmod(c.h * 360.0 - tono + 180.0, 360.0) - 180.0)
			if dh <= ANCHO_TONO:
				n += 1
	return n
