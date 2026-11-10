extends SceneTree
## La Santa Compaña en procesión: varios encapuchados iguales en fila, alternando el que porta la CRUZ y el que porta la VELA,
## andando desfasados para que no vayan como autómatas. NECESITA VENTANA:
##   Godot --path . --resolution 1600x900 --script res://herramientas/captura_procesion_santa.gd
## Salida: res://docs/capturas/santa_compana_cruz/procesion.png (tres cuartos y lado).
##
## Cada uno es el MISMO GLB con distinta entrada de Equipo3D (Pj3D.MODELO_DE), que es como está pensada la procesión.

const DIR: String = "res://docs/capturas/santa_compana_cruz"
const FUENTE: String = "res://arte/modelos/chibi_elf.glb"
const CLIP: String = "Walking"
## Quién lleva qué, de delante hacia atrás. La cruz encabeza, como en la procesión del cuento.
const FILA: Array[String] = ["santa_compana_cruz", "santa_compana_vela", "santa_compana_cruz",
	"santa_compana_vela", "santa_compana_vela"]
const SEPARACION: float = 0.78      ## distancia entre uno y el siguiente, en unidades de juego (menos y se tapan entre ellos)
const DESFASE: float = 0.37         ## fracción del ciclo de paso que se retrasa cada uno

var _cam: Camera3D = null


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	_entorno()
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 200.0
	_cam.fov = 30.0
	root.add_child(_cam)

	var alto_total: float = 0.0
	for i in FILA.size():
		var id: String = FILA[i]
		var glb: String = String(Pj3D.MODELO_DE.get(id, id))
		var modelo: Node3D = (load("res://arte/modelos/%s.glb" % glb) as PackedScene).instantiate()
		root.add_child(modelo)
		# en fila hacia el fondo, mirando a la cámara (+Z del modelo es su frente)
		modelo.position = Vector3(0.0, 0.0, -SEPARACION * i)
		var sk: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
		Equipo3D.equipar(id, modelo)
		var an: Animation = ClipsFamilia.traducir_clip(glb, FUENTE, CLIP, modelo, sk)
		if an == null:
			push_error("no se pudo traducir " + CLIP)
			quit(1)
			return
		var ap := AnimationPlayer.new()
		modelo.add_child(ap)
		var lib := AnimationLibrary.new()
		lib.add_animation(CLIP, an)
		ap.add_animation_library("", lib)
		ap.play(CLIP)
		ap.seek(an.length * fposmod(DESFASE * i, 1.0), true)
		ap.pause()
		await process_frame
		# Los clips sueltos no plantan los pies (eso lo hace Pj3D en el juego): aquí se sube cada uno hasta pisar el suelo.
		var bajo: float = _mas_bajo(modelo)
		modelo.position.y -= bajo
		alto_total = maxf(alto_total, _alto(modelo))
		print("%d  %-20s  z %.2f" % [i, id, modelo.position.z])

	await process_frame
	var centro := Vector3(0.0, alto_total * 0.45, -SEPARACION * (FILA.size() - 1) * 0.5)
	# Las piezas van en la mano DERECHA del personaje (su −X, porque mira a +Z), así que la cámara se pone de ese lado:
	# desde +X el propio cuerpo tapa la cruz y la vela.
	await _foto("procesion", centro, Vector3(-0.85, 0.26, 0.55), 4.3)
	await _foto("procesion_lado", centro, Vector3(-1.0, 0.14, 0.0), 3.9)
	quit(0)


func _mas_bajo(n: Node3D) -> float:
	var y: float = INF
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var caja: AABB = mi.global_transform * mi.get_aabb()
		y = minf(y, caja.position.y)
	return 0.0 if y == INF else y


func _alto(n: Node3D) -> float:
	var y: float = -INF
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		var caja: AABB = mi.global_transform * mi.get_aabb()
		y = maxf(y, caja.position.y + caja.size.y)
	return 0.0 if y == -INF else y


func _foto(nombre: String, foco: Vector3, dir: Vector3, dist: float) -> void:
	_cam.look_at_from_position(foco + dir.normalized() * dist, foco)
	for i in 5:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(DIR.path_join("%s.png" % nombre))
	print("foto ", nombre)


func _entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.34, 0.40)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 1.0)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.85
	sol.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	root.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(40, 40)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.26, 0.28, 0.32)
	suelo.material_override = mt
	root.add_child(suelo)
