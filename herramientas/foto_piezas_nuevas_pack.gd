extends SceneTree

## FOTO (26/11/2026) de las piezas NUEVAS del pack Pure Nature que eligió Pablo (TablaVariantes.MEDIDAS), en fila, con la luz del juego
## y una figura de 1 u (la jugadora) para ver el tamaño. NECESITA VENTANA:
##   godot --path . --resolution 1600x900 --script res://herramientas/foto_piezas_nuevas_pack.gd
## Deja docs/capturas/vegetacion_pack/piezas_nuevas.png

const SALIDA: String = "res://docs/capturas/vegetacion_pack/piezas_nuevas.png"


func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80, 0.86, 0.90)
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.shadow_enabled = true
	raiz.add_child(sol)
	LuzZona3D.aplicar(env, sol, "bosque")
	Posproceso3D.aplicar_entorno(env, root)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(60, 30)
	suelo.mesh = pl
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Paleta3D.HIERBA
	suelo.material_override = ms
	raiz.add_child(suelo)
	var x: float = 0.0
	var ids: Array = TablaVariantes.MEDIDAS.keys()
	ids.sort()
	for id in ids:
		var ps: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		if ps == null:
			continue
		var n: Node3D = ps.instantiate() as Node3D
		var c: AABB = TablaVariantes.caja(n)
		var ancho: float = maxf(maxf(c.size.x, c.size.z), 0.8)
		x += ancho * 0.5 + 0.6
		n.position = Vector3(x, 0.0, 0.0)
		raiz.add_child(n)
		var l := Label3D.new()
		l.text = String(id)
		l.font_size = 48
		l.outline_size = 12
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(x, maxf(c.size.y, 0.5) + 0.4, 0.0)
		raiz.add_child(l)
		x += ancho * 0.5 + 0.6
	var fig := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height = 1.0
	cap.radius = 0.18
	fig.mesh = cap
	fig.position = Vector3(-0.4, 0.5, 0.0)
	raiz.add_child(fig)
	var cam := Camera3D.new()
	cam.fov = 45.0
	raiz.add_child(cam)
	var centro := Vector3(x * 0.5 - 0.4, 0.5, 0.0)
	cam.current = true
	# (en _initialize el árbol aún no está listo: look_at_from_position en vez de look_at)
	cam.look_at_from_position(centro + Vector3(0.0, x * 0.22, x * 0.62), centro, Vector3.UP)
	for f in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(SALIDA)
	print("foto ", SALIDA)
	quit(0)
