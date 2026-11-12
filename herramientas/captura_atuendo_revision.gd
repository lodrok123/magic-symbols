extends SceneTree
## HOJAS DE REVISIÓN DE UN ATUENDO sobre la jugadora (12/11, Pablo: «revisa el último traje generado y arréglalo»).
## NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_atuendo_revision.gd -- <prenda,prenda…> [carpeta] [clip…]
## Desviste a la jugadora, le pone ESAS prendas (ids de arte/modelos/ropa.json) y guarda en res://docs/capturas/<carpeta>/:
##   reposo.png        el reposo desde ocho lados (dos filas de cuatro), de cerca
##   clip_<nombre>.png cada clip en cuatro instantes, visto de tres cuartos por delante (fila de arriba) y por detrás (fila de abajo)
## De cerca y sin suelo ni sombra que distraigan: lo que se busca es piel o ropa de debajo asomando, agujeros y tela rasgada.

const ALTO: float = 1.0
const CELDA: int = 640
const CLIPS: Array[String] = ["Walking", "Running", "RollDodge", "MageSoellCast003", "FacePunchReaction", "Dead", "StandAndDrink", "CollectObject"]


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args: Array = Array(OS.get_cmdline_user_args())
	var prendas: PackedStringArray = (String(args[0]) if args.size() > 0 else "tunica_lobo,piernas_lobo").split(",")
	var carpeta: String = String(args[1]) if args.size() > 1 else "atuendo_revision"
	var clips: Array = args.slice(2) if args.size() > 2 else Array(CLIPS)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.6)
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
	p.cargar("jugadora_base")
	p.set_alto(ALTO)
	await process_frame
	for pr in p.ropa_puesta():
		p.quitar_ropa(String(pr))
	# PRENDA DE PRUEBA sin tocar ropa.json: «<id>=<glb>:<prenda de la que copia ranura y zonas>» la registra solo para esta
	# ejecución (p. ej. tunica_pablo=ropa_tunica_lobo_pablo:tunica_lobo). Así se prueba un .glb nuevo sin meterlo en los datos del juego.
	Ropa3D.prendas()
	for k in prendas.size():
		if prendas[k].contains("="):
			var id_n: String = prendas[k].get_slice("=", 0)
			var resto: String = prendas[k].get_slice("=", 1)
			var como: Dictionary = (Ropa3D.datos_de(resto.get_slice(":", 1)) if resto.contains(":") else {}).duplicate(true)
			como["nombre"] = id_n
			como["glb"] = resto.get_slice(":", 0)
			Ropa3D._datos[id_n] = como
			print("prenda de prueba «%s»: %s" % [id_n, como])
			prendas[k] = id_n
	for pr in prendas:
		if not p.poner_ropa(String(pr)):
			print("NO se pudo poner la prenda: ", pr)
	await process_frame
	print("prendas puestas: ", p.ropa_puesta())
	if p.get("_sombra") != null and p._sombra != null:
		p._sombra.visible = false
	var ap: AnimationPlayer = p._ap
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var dir: String = "res://docs/capturas/%s" % carpeta
	DirAccess.make_dir_recursive_absolute(dir)
	var sk: Skeleton3D = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var i_cad: int = sk.find_bone("mixamorig_Hips")
	var dist: float = ALTO * 1.35 / (2.0 * tan(deg_to_rad(12.0)))

	# reposo: ocho lados
	ap.play(p.clip_de("idle"))
	ap.seek(0.0, true)
	for i in 8:
		await process_frame
	var hoja := Image.create_empty(CELDA * 4, 720 * 2, false, Image.FORMAT_RGB8)
	var foco := Vector3(0, ALTO * 0.5, 0)
	for k in 8:
		var ang: float = TAU * float(k) / 8.0
		cam.look_at_from_position(foco + Vector3(sin(ang), 0.12, cos(ang)).normalized() * dist, foco)
		for i in 3:
			await process_frame
		hoja.blit_rect(root.get_viewport().get_texture().get_image(), Rect2i(320, 0, CELDA, 720), Vector2i(CELDA * (k % 4), 720 * (k / 4)))
	hoja.save_png(dir.path_join("reposo.png"))
	print("hoja reposo")
	# PRIMER PLANO del torso desde los mismos ocho lados (zoom_torso.png): la cintura, las sisas y el pecho, que es donde se ve
	# si una prenda de debajo asoma por otra.
	# Con `zoom=<alto del centro>,<alto que se ve>` entre los clips (fracciones del alto del personaje) se encuadra otra franja:
	# zoom=0.5,0.22 es la cintura muy de cerca.
	var z_centro: float = 0.60
	var z_alto: float = 0.55
	var limpios: Array = []
	for c0 in clips:
		if String(c0).begins_with("zoom="):
			var partes: PackedStringArray = String(c0).trim_prefix("zoom=").split(",")
			z_centro = float(partes[0])
			if partes.size() > 1:
				z_alto = float(partes[1])
		else:
			limpios.append(c0)
	clips = limpios
	var hz := Image.create_empty(CELDA * 4, 720 * 2, false, Image.FORMAT_RGB8)
	var fz := Vector3(0, ALTO * z_centro, 0)
	var dz: float = ALTO * z_alto / (2.0 * tan(deg_to_rad(12.0)))
	for k in 8:
		var ang2: float = TAU * float(k) / 8.0
		cam.look_at_from_position(fz + Vector3(sin(ang2), 0.1, cos(ang2)).normalized() * dz, fz)
		for i in 3:
			await process_frame
		hz.blit_rect(root.get_viewport().get_texture().get_image(), Rect2i(320, 0, CELDA, 720), Vector2i(CELDA * (k % 4), 720 * (k / 4)))
	hz.save_png(dir.path_join("zoom_torso.png"))
	print("hoja zoom_torso")

	for clip in clips:
		if not ap.has_animation(String(clip)):
			continue
		var largo: float = ap.get_animation(String(clip)).length
		var h2 := Image.create_empty(CELDA * 4, 720 * 2, false, Image.FORMAT_RGB8)
		for k in 4:
			ap.play(String(clip))
			ap.seek(largo * (float(k) + 0.5) / 4.0, true)
			for i in 6:
				await process_frame
			var c: Vector3 = sk.global_transform * sk.get_bone_global_pose(i_cad).origin if i_cad >= 0 else p.global_position
			var centro := Vector3(c.x, foco.y, c.z)
			for v in 2:
				var desde: Vector3 = (Vector3(0.55, 0.2, 1.0) if v == 0 else Vector3(-0.55, 0.2, -1.0)).normalized()
				cam.look_at_from_position(centro + desde * dist, centro)
				for i in 3:
					await process_frame
				h2.blit_rect(root.get_viewport().get_texture().get_image(), Rect2i(320, 0, CELDA, 720), Vector2i(CELDA * k, 720 * v))
		h2.save_png(dir.path_join("clip_%s.png" % clip))
		print("hoja ", clip)
	quit(0)
