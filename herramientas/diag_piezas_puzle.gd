extends SceneTree
## Prueba de las piezas de puzle (PiezaPuzle3D): las construye todas, recorre sus estados y saca capturas. Sin comprobaciones de juego: es
## para VER el modelo y los efectos, y para comprobar que ningún estado da error. Uso: godot --path . --script res://herramientas/diag_piezas_puzle.gd
const FILAS: Array = [
	["pulsador", {"tinte": "magia"}], ["pulsador", {"tinte": "agua"}], ["placa", {}], ["compuerta", {"material": "madera"}],
	["compuerta", {"material": "hierro"}], ["compuerta_hielo", {}], ["roca", {}], ["barril", {}], ["molino", {}], ["pila", {}],
	["poste_nivel", {"marca": 0.9}], ["reja", {}], ["tapon_hielo", {}],
]
var _fallos: int = 0

func _initialize() -> void:
	var mq := Node3D.new(); root.add_child(mq)
	current_scene = mq
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 17.0
	mq.add_child(cam); var b := Basis.from_euler(Vector3(deg_to_rad(-35), deg_to_rad(25), 0.0)); cam.basis = b; cam.position = Vector3(0, 0, 0.5) + b * Vector3(0, 0, 30); cam.current = true
	var luz := DirectionalLight3D.new(); mq.add_child(luz); luz.rotation_degrees = Vector3(-50, 30, 0)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.62, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.75, 0.75, 0.75); env.environment = e; mq.add_child(env)
	var suelo := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 40); suelo.mesh = pm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color(0.42, 0.58, 0.3); suelo.material_override = ms; mq.add_child(suelo)
	var piezas: Array = []
	for i in FILAS.size():
		var p: PiezaPuzle3D = PiezaPuzle3D.crear(FILAS[i][0], FILAS[i][1])
		if p == null:
			_fallos += 1
			continue
		p.position = Vector3((i % 5) * 4.6 - 9.0, 0, (i / 5) * 5.0 - 4.5)
		mq.add_child(p)
		piezas.append(p)
	await _captura("inicial")
	# cada pieza recorre sus estados; una captura por «ronda» de estados (la i-ésima de cada familia)
	for ronda in range(1, 3):
		for p in piezas:
			var est: Array = PiezaPuzle3D.ESTADOS[p.familia]
			if ronda < est.size():
				if not p.poner_estado(est[ronda]):
					_fallos += 1
		await create_timer(0.55).timeout
		await _captura("estado_%d" % ronda)
		await create_timer(0.9).timeout
		await _captura("estado_%d_b" % ronda)
	# un id inventado se ignora
	if piezas[0].poner_estado("nunca"):
		_fallos += 1
	# tinaja: cualquier nodo con mallas dentro; «vacia» pone el velo y «llena» lo quita
	var tin := Node3D.new(); mq.add_child(tin)
	var mi := MeshInstance3D.new(); mi.mesh = SphereMesh.new(); tin.add_child(mi)
	if not PiezaPuzle3D.poner_estado_tinaja(tin, "vacia", false) or mi.material_overlay == null:
		_fallos += 1
	if not PiezaPuzle3D.poner_estado_tinaja(tin, "llena", false) or mi.material_overlay != null:
		_fallos += 1
	if PiezaPuzle3D.poner_estado_tinaja(tin, "rota", false):
		_fallos += 1
	print("FALLOS: ", _fallos)
	quit()

func _captura(nombre: String) -> void:
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/pz_%s.png" % nombre)
