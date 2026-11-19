extends Node3D
## Laboratorio sin progreso: todos los directores se crean con modo_prueba=true.
var _camara: Camera3D
var _env: Environment
var _sol: DirectionalLight3D
var _tam_camara := 5.4
var pj: Pj3D
var cofre: Node3D
var ctrl: Cofre3D
var secuencia: SecuenciaCofreLegendario3D
var calidad := "legendario"
var mixamo := false
var reducido := false
var nivel := 1
var estado: Label
var contacto: SpinBox
var listo := false

func _ready() -> void:
	var entorno := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.07, 0.10, 0.09)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.74, 0.83, 0.80)
	_env.ambient_light_energy = 0.65
	entorno.environment = _env
	add_child(entorno)
	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-55, -35, 0)
	_sol.light_energy = 1.4
	_sol.shadow_enabled = true
	add_child(_sol)
	var suelo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(12, 0.15, 10)
	suelo.mesh = caja
	suelo.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.25, 0.19)
	suelo.material_override = mat
	add_child(suelo)
	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = _tam_camara
	add_child(_camara)
	_camara.position = Vector3(3.8, 3.3, 6)
	_camara.look_at(Vector3(0, 0.95, 0.4))
	_camara.current = true
	pj = Pj3D.new()
	add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(0, 0, 1.0)
	pj.mirar(Vector3.FORWARD, 1.0)
	pj.jugar("idle")
	_ui()
	_reponer()
	listo = true

func _ui() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	capa.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var titulo := Label.new()
	titulo.text = "COFRES · prueba sin guardar progreso"
	v.add_child(titulo)
	var fila := HBoxContainer.new()
	v.add_child(fila)
	for c: String in ["comun", "epico", "legendario"]:
		var b := Button.new()
		b.text = c.capitalize()
		b.pressed.connect(func() -> void: calidad = c; _reponer())
		fila.add_child(b)
	var abrir := Button.new()
	abrir.text = "Abrir / repetir [Espacio]"
	abrir.pressed.connect(abrir_prueba)
	v.add_child(abrir)
	var m := CheckButton.new()
	m.text = "Mixamo completo (8,93 s) para comparar"
	m.toggled.connect(func(b: bool) -> void: mixamo = b)
	v.add_child(m)
	var r := CheckButton.new()
	r.text = "Efectos reducidos / cámara fija"
	r.toggled.connect(func(b: bool) -> void: reducido = b)
	v.add_child(r)
	contacto = SpinBox.new()
	contacto.min_value = 0.5
	contacto.max_value = 8.0
	contacto.step = 0.05
	contacto.value = 1.77
	contacto.prefix = "Contacto Mixamo (s): "
	v.add_child(contacto)
	var libros := HBoxContainer.new()
	v.add_child(libros)
	for n in [1, 2, 3]:
		var b := Button.new()
		b.text = "Libro %d" % n
		b.pressed.connect(func() -> void: nivel = n)
		libros.add_child(b)
	var saltar_b := Button.new()
	saltar_b.text = "Saltar apertura / continuar presentación"
	saltar_b.pressed.connect(func() -> void:
		if is_instance_valid(secuencia):
			secuencia.saltar())
	v.add_child(saltar_b)
	var cancelar_b := Button.new()
	cancelar_b.text = "Reiniciar [R]"
	cancelar_b.pressed.connect(_reponer)
	v.add_child(cancelar_b)
	var velocidad := HSlider.new()
	velocidad.min_value = 0.15
	velocidad.max_value = 1.5
	velocidad.step = 0.05
	velocidad.value = 1.0
	velocidad.value_changed.connect(func(vv: float) -> void: Engine.time_scale = vv)
	v.add_child(velocidad)
	var vistas := OptionButton.new()
	vistas.add_item("Cámara: tres cuartos")
	vistas.add_item("Cámara: frontal / estrellas")
	vistas.add_item("Cámara: elevada / página")
	vistas.item_selected.connect(func(i: int) -> void:
		_camara.position = [Vector3(3.8, 3.3, 6), Vector3(0, 1.9, 6), Vector3(2.8, 5.5, 4)][i]
		_camara.look_at(Vector3(0, 0.95, 0.4)))
	v.add_child(vistas)
	var ver_pj := CheckButton.new()
	ver_pj.text = "Ocultar personaje para revisar estrellas"
	ver_pj.toggled.connect(func(b: bool) -> void: pj.visible = not b)
	v.add_child(ver_pj)
	estado = Label.new()
	v.add_child(estado)

func _reponer() -> void:
	if is_instance_valid(secuencia):
		secuencia.cancelar()
		secuencia.queue_free()
	secuencia = null
	if is_instance_valid(cofre):
		remove_child(cofre)
		cofre.queue_free()
	var ruta := "res://arte/piezas/cofre%s.tscn" % ("" if calidad == "comun" else "_" + calidad)
	cofre = (load(ruta) as PackedScene).instantiate() as Node3D
	add_child(cofre)
	ctrl = Cofre3D.en(cofre)
	pj.mirar(cofre.global_position - pj.global_position, 1.0)

func abrir_prueba() -> void:
	if is_instance_valid(secuencia) and secuencia.activa:
		return
	_reponer()
	if calidad == "comun":
		ctrl.abrir()
		return
	secuencia = SecuenciaCofreLegendario3D.new()
	secuencia.modo_prueba = true
	secuencia.calidad = calidad
	secuencia.pj_explicito = pj
	secuencia.camara_explicita = _camara
	secuencia.efectos_reducidos = reducido
	secuencia.usar_mixamo = mixamo
	secuencia.contacto_mixamo = contacto.value
	add_child(secuencia)
	secuencia.nivel_libro = nivel
	secuencia.iniciar(cofre, ctrl, self, "raido" if calidad == "legendario" else "")

func _process(_delta: float) -> void:
	if estado == null:
		return
	estado.text = "%s · %s" % [calidad, ctrl.estado_nombre() if ctrl != null else "sin tapa"]
	if is_instance_valid(secuencia):
		estado.text += "\n%.2f s · %s" % [secuencia.t, secuencia.fase]

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE: abrir_prueba()
			KEY_R: _reponer()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
