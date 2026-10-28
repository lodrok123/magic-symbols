extends "res://herramientas/escenario_base.gd"
## 28/10 · Tira de capturas de un guerrero ANDANDO y CORRIENDO a su nuevo ritmo (RITMO_GOBLIN 0,8) para ver a ojo que los pies no patinan: 4 fotogramas a un cuarto de ciclo del clip, con una
## regla de palitos rojos clavados en el suelo cada 0,25 u (el pie apoyado tiene que quedarse junto al mismo palito mientras el cuerpo pasa).
## NECESITA VENTANA:   godot --path . --resolution 1280x720 --fixed-fps 30 --script res://herramientas/captura_ritmo_goblin.gd
## Salida en res://docs/capturas/ritmo_goblin/ (andar.png, correr.png).

const DIR: String = "res://docs/capturas/ritmo_goblin"
const FILA: int = 33
const W: int = 480
const H: int = 360

var _cam: Camera3D = null


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _regla(desde: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 40:
		var m := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.02, 0.12 if k % 4 == 0 else 0.06, 0.02)
		m.mesh = caja
		m.material_override = mat
		maqueta.add_child(m)
		m.position = desde + Vector3(k * 0.25, caja.size.y * 0.5 + 0.01, 0.0)


func _tira(g: Combate3D, nombre: String, clip: String) -> void:
	var imgs: Array = []
	var dur: float = g.pj.duracion(clip)
	var ciclo: float = dur / g.pj.velocidad_animacion()
	print("tira %s: clip %s a x%.2f, ciclo %.3f s, %.2f u/s" % [nombre, g.pj.animacion_actual, g.pj.velocidad_animacion(), ciclo, g._v_avance])
	for i in 4:
		_cam.global_position = g.pj.global_position + Vector3(0.0, 0.9 if nombre == "chaman_andar" else 0.45, 3.2)
		_cam.look_at(g.pj.global_position + Vector3(0.0, 0.32, 0.0), Vector3.UP)
		for f in 2:
			await process_frame
		imgs.append(root.get_viewport().get_texture().get_image())
		await avanzar_s(ciclo / 4.0)
	var primero: Image = imgs[0]
	var tira := Image.create(W * 4, H, false, Image.FORMAT_RGB8)
	for i in 4:
		var im: Image = imgs[i]
		var r := Rect2i(Vector2i((im.get_width() - W) / 2, (im.get_height() - H) / 2), Vector2i(W, H))
		tira.blit_rect(im, r, Vector2i(i * W, 0))
	tira.save_png(DIR.path_join(nombre + ".png"))
	print("foto " + nombre)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	Repertoire.activate_all()
	await avanzar(20)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	maqueta.add_child(_cam)
	_cam.current = true
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var p: Vector3 = _pos(Vector2i(30, FILA))
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	colocar_jugador(Vector2i(10, FILA))
	(jugador as Jugador3D).vida = 100000.0
	_regla(p + Vector3(-1.0, 0.0, -0.45))
	await avanzar_s(0.6)
	await _tira(g, "andar", "walk")
	g.queue_free()
	modelo.queue_free()
	# correr: persigue a la jugadora desde lejos pero sin llegar (ella a 7 u: dentro de RADIO_DETECCION no; así que se pone cerca y la tira se toma al principio)
	var p2: Vector3 = _pos(Vector2i(5, FILA))
	var modelo2: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p2)
	var g2: Combate3D = Combate3D.equipar(modelo2, maqueta, jugador as Jugador3D, lanzador)
	colocar_jugador(Vector2i(7, FILA))
	_regla(p2 + Vector3(-0.5, 0.0, -0.45))
	await avanzar_s(0.3)
	await _tira(g2, "correr", "run")
	# 29/10: el chamán andando con el bastón (su walk es el «Walking» de Marimanta; el de anciana ya no se usa)
	g2.queue_free()
	modelo2.queue_free()
	var p3: Vector3 = _pos(Vector2i(6, FILA))
	var ch: Chaman3D = Chaman3D.invocar_chaman(maqueta, p3, jugador as Jugador3D, lanzador)
	ch._cd_bola = 99.0
	ch._cd_ritual = 99.0
	colocar_jugador(Vector2i(10, FILA))
	_regla(p3 + Vector3(-0.5, 0.0, -0.45))
	await avanzar_s(0.5)
	await _tira(ch, "chaman_andar", "walk")
	quit(0)
