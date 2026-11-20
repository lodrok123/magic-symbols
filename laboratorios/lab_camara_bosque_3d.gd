extends Node3D
## Maqueta de encuadre independiente: no modifica mapas ni la cámara de producción.
const Bordes = preload("res://laboratorios/camara_bordes_bosque.gd")
const ZONAS: Array[Rect2] = [Rect2(-18, -14, 36, 28), Rect2(-10, -8, 20, 16)]
var zona: int = 0
var bloqueo: bool = true
var depuracion: bool = false
var zoom_pedido: float = 6.0
var limites: Rect2
var zona_transitable: Rect2
var foco := Vector3.ZERO
var camara: Camera3D
var jugador: CharacterBody3D
var escenario: Node3D
var guia: MeshInstance3D
var texto: Label
var direccion := Vector3(0, -0.5, -0.8660254) # 60° desde la vertical, igual que el bosque real.

func _ready() -> void:
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("171e24")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("b9d6d2")
	ambiente.environment.ambient_light_energy = 0.65
	add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -30, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	add_child(sol)
	camara = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.near = 0.1
	camara.far = 150
	add_child(camara)
	camara.make_current()
	jugador = CharacterBody3D.new()
	jugador.collision_layer = 1
	jugador.collision_mask = 1
	add_child(jugador)
	var cuerpo := CapsuleMesh.new()
	cuerpo.radius = 0.28
	cuerpo.height = 1.15
	_malla(jugador, cuerpo, Vector3(0, 0.65, 0), Color("578b83"))
	var sombrero := CylinderMesh.new()
	sombrero.top_radius = 0
	sombrero.bottom_radius = 0.45
	sombrero.height = 0.65
	_malla(jugador, sombrero, Vector3(0, 1.48, 0), Color("d6c291"))
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.2
	col.shape = capsula
	col.position.y = 0.65
	jugador.add_child(col)
	guia = MeshInstance3D.new()
	add_child(guia)
	var capa := CanvasLayer.new()
	add_child(capa)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(panel)
	texto = Label.new()
	texto.add_theme_font_size_override("font_size", 17)
	panel.add_child(texto)
	cambiar_zona(0)

func _malla(padre: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = mesh
	nodo.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	nodo.material_override = mat
	padre.add_child(nodo)
	return nodo

func _caja(pos: Vector3, tam: Vector3, color: Color, solida: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = tam
	_malla(escenario, mesh, pos, color)
	if solida:
		var cuerpo := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = tam
		forma.shape = caja
		cuerpo.position = pos
		cuerpo.add_child(forma)
		escenario.add_child(cuerpo)

func _pieza(ruta: String, pos: Vector3, escala: float) -> void:
	var pieza := (load(ruta) as PackedScene).instantiate() as Node3D
	pieza.position = pos
	pieza.scale = Vector3.ONE * escala
	escenario.add_child(pieza)

func cambiar_zona(indice: int) -> void:
	zona = indice
	if is_instance_valid(escenario):
		remove_child(escenario)
		escenario.queue_free()
	escenario = Node3D.new()
	add_child(escenario)
	limites = ZONAS[zona]
	# Banda de suelo escénico: deja al personaje completo en pantalla al tocar el límite físico.
	zona_transitable = limites.grow(-4.0)
	var centro := limites.get_center()
	_caja(Vector3(centro.x, -0.2, centro.y), Vector3(limites.size.x, 0.4, limites.size.y), Color("566e42") if zona == 0 else Color("777066"), true)
	# Colisiones al borde de la superficie: visibles como canto del suelo, sin cortina de árboles ni muros altos.
	for x: float in [zona_transitable.position.x, zona_transitable.end.x]:
		_barrera(Vector3(x, 1, centro.y), Vector3(0.15, 2, zona_transitable.size.y))
	for z: float in [zona_transitable.position.y, zona_transitable.end.y]:
		_barrera(Vector3(centro.x, 1, z), Vector3(zona_transitable.size.x, 2, 0.15))
	if zona == 0:
		for pos: Vector2 in [Vector2(-16,0), Vector2(-9,12), Vector2(10,12)]:
			_pieza("res://arte/piezas/arbol_redondo.tscn", Vector3(pos.x, 0, pos.y), 0.9)
		_pieza("res://arte/piezas/boca_cueva.tscn", Vector3(0, 0, -11), 1.1)
		_caja(Vector3(-3.5, 0.03, 1), Vector3(2.8, 0.04, 17), Color("a28e60"))
	else:
		# Dos tramos al fondo y tres rocas: el encuadre debe cerrar el resto.
		_caja(Vector3(-6, 0.9, -7), Vector3(5, 1.8, 1), Color("514c49"), true)
		_caja(Vector3(6, 0.9, -7), Vector3(5, 1.8, 1), Color("514c49"), true)
		for pos: Vector2 in [Vector2(-8,2), Vector2(8,-3), Vector2(6,5)]:
			_pieza("res://arte/piezas/roca_musgosa.tscn", Vector3(pos.x, 0, pos.y), 1.5)
		_caja(Vector3(0, 0.025, -6.8), Vector3(3, 0.05, 2), Color("a18d5d"))
	jugador.position = Vector3.ZERO
	jugador.velocity = Vector3.ZERO
	foco = Vector3.ZERO
	_actualizar_camara(0.0, true)

func _barrera(pos: Vector3, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.position = pos
	cuerpo.add_child(col)
	escenario.add_child(cuerpo)

func _physics_process(delta: float) -> void:
	var movimiento := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if movimiento.length() > 1:
		movimiento = movimiento.normalized()
	var velocidad := 7.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0
	jugador.velocity = Vector3(movimiento.x * velocidad, jugador.velocity.y - 20 * delta, movimiento.y * velocidad)
	jugador.move_and_slide()

func _process(delta: float) -> void:
	_actualizar_camara(delta)
	var deseado := Vector3(jugador.position.x, 0, jugador.position.z)
	var limitado := Bordes.limitar(deseado, limites.grow(-0.2), Bordes.huella(camara))
	texto.text = "  BORDES · %s · BLOQUEO %s  \n  WASD mover · Shift correr · Tab bosque/cueva · L comparar  \n  1–9 centro/bordes/esquinas · R reiniciar · +/- zoom · F2 guías  \n  Eje X: %s   Eje Z: %s   Zoom: %.1f (pedido %.1f)  " % ["BOSQUE / BOCA DE CUEVA" if zona == 0 else "INTERIOR DE CUEVA", "SÍ" if bloqueo else "NO", "BLOQUEADO" if absf(limitado.x - deseado.x) > 0.01 and bloqueo else "sigue", "BLOQUEADO" if absf(limitado.z - deseado.z) > 0.01 and bloqueo else "sigue", camara.size, zoom_pedido]
	_dibujar_guia()

func _actualizar_camara(delta: float, inmediato: bool = false) -> void:
	camara.transform = Transform3D(Basis.looking_at(direccion, Vector3.UP), foco - direccion * 40)
	camara.size = zoom_pedido
	if bloqueo:
		camara.size = minf(zoom_pedido, Bordes.tamanio_maximo(camara, limites.grow(-0.2)))
	var deseado := Vector3(jugador.position.x, 0, jugador.position.z)
	var vista := Bordes.huella(camara)
	if bloqueo:
		foco = Bordes.limitar(deseado, limites.grow(-0.2), vista) if inmediato else Bordes.seguir(foco, deseado, limites.grow(-0.2), vista, delta)
	else:
		foco = deseado if inmediato else foco.lerp(deseado, 1.0 - exp(-9.0 * delta))
	camara.position = foco - direccion * 40

func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.is_pressed() or ev.is_echo():
		return
	match ev.physical_keycode:
		KEY_TAB: cambiar_zona(1 - zona)
		KEY_L: bloqueo = not bloqueo
		KEY_F2: depuracion = not depuracion
		KEY_R: cambiar_zona(zona)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: zoom_pedido = maxf(5, zoom_pedido - 1)
		KEY_MINUS, KEY_KP_SUBTRACT: zoom_pedido = minf(30, zoom_pedido + 1)
		KEY_ESCAPE: get_tree().quit()
		_:
			if ev.physical_keycode >= KEY_1 and ev.physical_keycode <= KEY_9:
				ir_a_punto(ev.physical_keycode - KEY_1)

func ir_a_punto(indice: int) -> void:
	var puntos: Array[Vector2] = [Vector2(0.5,0.5), Vector2(0.05,0.5), Vector2(0.95,0.5), Vector2(0.5,0.05), Vector2(0.5,0.95), Vector2(0.05,0.05), Vector2(0.95,0.05), Vector2(0.05,0.95), Vector2(0.95,0.95)]
	var p := zona_transitable.position + zona_transitable.size * puntos[indice]
	jugador.position = Vector3(p.x, 0.1, p.y)
	jugador.velocity = Vector3.ZERO
	_actualizar_camara(0, true)

func _dibujar_guia() -> void:
	guia.visible = depuracion
	if not depuracion:
		return
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var vista := Bordes.huella(camara)
	for rect: Rect2 in [limites.grow(-0.2), zona_transitable, Rect2(Vector2(foco.x, foco.z) + vista.position, vista.size)]:
		var puntos: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			mesh.surface_set_color(Color.CYAN if rect.size == vista.size else (Color.GREEN if rect == zona_transitable else Color.ORANGE))
			mesh.surface_add_vertex(Vector3(puntos[i].x, 0.08, puntos[i].y))
			mesh.surface_add_vertex(Vector3(puntos[(i+1)%4].x, 0.08, puntos[(i+1)%4].y))
	mesh.surface_end()
	guia.mesh = mesh
