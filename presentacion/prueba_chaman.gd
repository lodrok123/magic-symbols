extends Node3D

## ESCENA DE PRUEBA DEL CHAMÁN (28/10; escenas/PruebaChaman.tscn): el chamán goblin de pie con su bastón en una sala, con la cámara del juego (inclinación 60°, zoom 6).
## Teclas:  1 andar / quieto  ·  2 ritual completo en bucle (trazar el rombo -> clavar -> onda verde)  ·  3 interrumpir (la runa se rompe)  ·  4 lanzar una bola de veneno
##          Q / E girar la cámara a los lados.
## Sirve para ver el rig, el bastón agarrado/plantado, el orbe y la runa; no hay IA: la IA vive en Chaman3D (SalaChaman).

const ALTO_CHAMAN: float = 0.85
const LADO_SALA: float = 5.0                    ## casillas de lado de la sala
const INCLINACION: float = 60.0
const ZOOM: float = 6.0
const VEL_ANDAR: float = 1.2
const PAUSA_BUCLE: float = 1.2

var chaman: Pj3D = null
var ritual: ChamanRitual = null
var en_bucle: bool = false
var andando: bool = false
var _cam: Camera3D = null
var _giro_cam: float = 0.0
var _pausa: float = 0.0
var _info: Label = null
var _t_andar: float = 0.0


func _ready() -> void:
	_construir_sala()
	chaman = Pj3D.new()
	chaman.position = Vector3(0, 0, 0)
	add_child(chaman)
	chaman.cargar("goblin_chaman")
	chaman.set_alto(ALTO_CHAMAN)
	chaman.rotation.y = 0.0
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	add_child(_cam)
	var cl := CanvasLayer.new()
	add_child(cl)
	_info = Label.new()
	_info.position = Vector2(14, 10)
	_info.add_theme_font_size_override("font_size", 18)
	cl.add_child(_info)
	_poner_camara()


func _construir_sala() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sol.shadow_enabled = true
	add_child(sol)
	var lado: float = LADO_SALA * Terreno3D.casilla
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(lado, lado)
	suelo.mesh = pl
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.36, 0.38, 0.4)
	mt.roughness = 0.95
	suelo.material_override = mt
	add_child(suelo)
	for i in range(int(LADO_SALA) + 1):             # las líneas de las casillas
		for eje in 2:
			var l := MeshInstance3D.new()
			var q := BoxMesh.new()
			q.size = Vector3(lado, 0.01, 0.03) if eje == 0 else Vector3(0.03, 0.01, lado)
			l.mesh = q
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = Color(0.28, 0.3, 0.33)
			l.material_override = m2
			var d: float = -lado * 0.5 + float(i) * Terreno3D.casilla
			l.position = Vector3(0, 0.005, d) if eje == 0 else Vector3(d, 0.005, 0)
			add_child(l)
	for k in 4:                                       # cuatro paredes bajas
		var w := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(lado + 0.4, 1.4, 0.4)
		w.mesh = b
		var m3 := StandardMaterial3D.new()
		m3.albedo_color = Color(0.3, 0.32, 0.36)
		w.material_override = m3
		var ang: float = float(k) * PI * 0.5
		w.position = Vector3(sin(ang), 0.7, cos(ang)) * (lado * 0.5 + 0.2)
		w.rotation.y = ang
		add_child(w)


func _poner_camara() -> void:
	var inc: float = deg_to_rad(INCLINACION)
	var dir := Vector3(sin(_giro_cam) * cos(inc), sin(inc), cos(_giro_cam) * cos(inc))
	var foco := Vector3(0, 0.35, 0.8)
	_cam.look_at_from_position(foco + dir * ZOOM, foco)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match (ev as InputEventKey).keycode:
		KEY_1:
			alternar_andar()
		KEY_2:
			empezar_bucle()
		KEY_3:
			interrumpir()
		KEY_4:
			lanzar_bola()


func alternar_andar() -> void:
	if ritual != null and ritual.en_curso():
		return
	andando = not andando
	if not andando:
		chaman.position = Vector3.ZERO
		chaman.rotation.y = 0.0
		_t_andar = 0.0
	chaman.animacion_actual = ""
	chaman.jugar("walk" if andando else "idle")


## Un ritual completo en bucle: al acabar espera PAUSA_BUCLE s y vuelve a empezar.
func empezar_bucle() -> void:
	en_bucle = true
	_lanzar_ritual()


func _lanzar_ritual() -> void:
	if ritual != null and ritual.en_curso():
		return
	andando = false
	ritual = ChamanRitual.iniciar(chaman, self)
	_pausa = 0.0
	if ritual != null:
		ritual.terminado.connect(func() -> void: _pausa = PAUSA_BUCLE)
		ritual.interrumpido.connect(func() -> void: _pausa = PAUSA_BUCLE)


func interrumpir() -> void:
	en_bucle = false
	if ritual != null and ritual.en_curso():
		ritual.interrumpir()


## Una bola de veneno hacia delante del chamán (a 5 u), para ver el gesto de lanzar y el aviso.
func lanzar_bola() -> void:
	if ritual != null and ritual.en_curso():
		return
	chaman.agarrar_baston(true, 0.15)
	chaman.teñir_baston(Chaman3D.COLOR_VENENO, Chaman3D.ENERGIA_VENENO)
	chaman.animacion_actual = ""
	chaman.jugar("lanzar", true)
	await get_tree().create_timer(AnimacionesChaman.INSTANTE_LANZAR).timeout
	var fwd := Vector3(sin(chaman.rotation.y), 0.0, cos(chaman.rotation.y))
	var b: BastonChaman3D = chaman.baston()
	var origen: Vector3 = b.cima_global() if b != null else Vector3(0, 0.7, 0.2)
	BolaVeneno3D.lanzar(self, origen, chaman.global_position + fwd * 3.2, null, null, null)
	await get_tree().create_timer(AnimacionesChaman.DUR_LANZAR - AnimacionesChaman.INSTANTE_LANZAR).timeout
	chaman.agarrar_baston(false, 0.25)
	chaman.teñir_baston(Color.WHITE, 0.0)
	chaman.animacion_actual = ""
	chaman.jugar("walk" if andando else "idle")


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		_giro_cam -= delta * 1.2
	if Input.is_key_pressed(KEY_E):
		_giro_cam += delta * 1.2
	_poner_camara()
	if andando and chaman != null:
		_t_andar += delta
		# anda en círculo por la sala
		var ang: float = _t_andar * VEL_ANDAR / 1.6
		var pos := Vector3(sin(ang), 0.0, cos(ang)) * 1.6
		var sig := Vector3(sin(ang + 0.05), 0.0, cos(ang + 0.05)) * 1.6
		chaman.position = pos
		chaman.mirar((sig - pos).normalized(), 0.2)
	if _pausa > 0.0:
		_pausa -= delta
		if _pausa <= 0.0:
			if ritual == null or not ritual.en_curso():
				chaman.animacion_actual = ""
				chaman.jugar("idle")
				if en_bucle:
					_lanzar_ritual()
	var fase: String = ritual.fase if ritual != null and is_instance_valid(ritual) else "-"
	_info.text = "1 andar/quieto · 2 ritual en bucle · 3 interrumpir · 4 bola de veneno · Q/E cámara\nclip: %s   ritual: %s%s" % [chaman.animacion_actual, fase, " (bucle)" if en_bucle else ""]
