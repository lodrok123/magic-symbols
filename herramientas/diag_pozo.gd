extends SceneTree
## Prueba del pozo de la cuenca con la simulación y el dibujo del agua reales.
const S := 2.3
const ALTO := S * 0.45
const ALTO_AGUA := ALTO - 0.04
const LECHO := 0.9
func _initialize() -> void:
	var W := 9; var H := 7
	var pozo: Array[Vector2i] = [Vector2i(3,2), Vector2i(4,2), Vector2i(5,2), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3)]
	var mq := Node3D.new(); root.add_child(mq)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 9.0
	mq.add_child(cam); cam.rotation_degrees = Vector3(-35, 25, 0); cam.position = Vector3(S*4.5 + 7, 9, S*3.5 + 10); cam.current = true
	var luz := DirectionalLight3D.new(); mq.add_child(luz); luz.rotation_degrees = Vector3(-55, 30, 0); luz.shadow_enabled = false
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.65, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.7); env.environment = e; mq.add_child(env)
	var mat_t := StandardMaterial3D.new(); mat_t.albedo_color = Color(0.45, 0.62, 0.3)
	var mat_piedra := StandardMaterial3D.new(); mat_piedra.albedo_color = Color(0.6, 0.58, 0.55); mat_piedra.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_fondo := StandardMaterial3D.new(); mat_fondo.albedo_color = Color(0.36, 0.32, 0.27)
	var y_f: float = ALTO_AGUA - LECHO
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if pozo.has(c): continue
			var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(S, ALTO, S); b.mesh = bm; b.material_override = mat_t
			b.position = Vector3((x+0.5)*S, ALTO*0.5, (y+0.5)*S); mq.add_child(b)
	for c in pozo:
		var p := PozoCauce3D.new(); mq.add_child(p)
		p.position = Vector3((c.x+0.5)*S, 0, (c.y+0.5)*S)
		p.construir(S, y_f, ALTO, mat_piedra, mat_fondo)
		for i in PozoCauce3D.LADOS.size():
			var n: Vector2i = c + PozoCauce3D.LADOS[i]
			p.mostrar_lado(i, not pozo.has(n))
	# Simulación
	var sim := AguaSim3D.new()
	var suelo := func(c: Vector2i) -> float: return y_f if pozo.has(c) else ALTO
	var pared := func(c: Vector2i) -> bool: return not pozo.has(c)
	sim.configurar(W, H, 3, S, suelo, pared)
	var r := AguaRender3D.new(); mq.add_child(r); r.enlazar(sim)
	sim.fuente_en(Vector2i(3,2), 0.8)
	var capsula := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.height = 1.0; cm.radius = 0.25; capsula.mesh = cm; mq.add_child(capsula)
	var tiempos := [0.0, 4.0, 12.0, 30.0]
	var t := 0.0
	for k in tiempos.size():
		while t < tiempos[k]:
			sim.paso(1.0/30.0); t += 1.0/30.0
			r._process(1.0/30.0)
		capsula.position = Vector3(4.5*S, maxf(sim.superficie_en(Vector3(4.5*S, 0, 3*S)), y_f) + 0.0, 3*S)
		for _i in 3: r._process(0.1)
		await process_frame; await process_frame
		print("t=", tiempos[k], " prof(4,3)=", sim.profundidad_casilla(Vector2i(4,3)))
		root.get_viewport().get_texture().get_image().save_png("/tmp/pozo_%d.png" % k)
	quit()
