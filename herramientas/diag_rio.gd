extends SceneTree
## Prueba de la corriente del río y la cascada con la simulación y el dibujo reales (DIARIO 95).
const S := 2.3
const ALTO := 1.035
func _initialize() -> void:
	var W := 10; var H := 5
	var mq := Node3D.new(); root.add_child(mq)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 14.0
	mq.add_child(cam); cam.rotation_degrees = Vector3(-35, 25, 0); cam.position = Vector3(S*5 + 8, 9, S*2.5 + 12); cam.current = true
	var luz := DirectionalLight3D.new(); mq.add_child(luz); luz.rotation_degrees = Vector3(-55, 30, 0)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.65, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.7); env.environment = e; mq.add_child(env)
	var mat_t := StandardMaterial3D.new(); mat_t.albedo_color = Color(0.45, 0.62, 0.3)
	var alto_de := func(c: Vector2i) -> float:
		if c.y == 2: return 0.2 if c.x < 5 else -0.8
		return ALTO
	var sup_de := func(c: Vector2i) -> float: return 0.9 if c.x < 5 else -0.1
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if c.y == 2: continue
			var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(S, ALTO, S); b.mesh = bm; b.material_override = mat_t
			b.position = Vector3((x+0.5)*S, ALTO*0.5, (y+0.5)*S); mq.add_child(b)
	var sim := AguaSim3D.new()
	var pared := func(c: Vector2i) -> bool: return c.y != 2
	sim.configurar(W, H, 3, S, alto_de, pared)
	for x in W:
		sim.fijar_nivel(Vector2i(x, 2), sup_de.call(Vector2i(x, 2)))
	var r := AguaRender3D.new()
	r.proveedor_flujo = func() -> Dictionary: return AguaRender3D.flujo_hacia_salidas(W, func(c: Vector2i) -> bool: return c.y == 2, func(c: Vector2i) -> bool: return c.x == 9)
	mq.add_child(r); r.enlazar(sim)
	var caidas := [0]
	r.caida_detectada.connect(func(p: Vector3, s: float) -> void:
		caidas[0] += 1
		if caidas[0] <= 3: print("caida en ", p, " salto ", s))


	var t := 0.0
	for k in 3:
		while t < 3.0 + k * 0.25:
			sim.paso(1.0/30.0); t += 1.0/30.0
			r._process(1.0/30.0)
		for _i in 3: r._process(0.1)
		await process_frame; await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/rio_%d.png" % k)
	print("caidas emitidas=", caidas[0])
	quit()
