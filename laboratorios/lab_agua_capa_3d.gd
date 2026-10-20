extends Node3D
## LABORATORIO DE LA CAPA DEL AGUA (Pipeline, 20/10; W1 + W2 del PLAN_TRES_FRENTES). Un entorno SOLO para ver lo nuevo de `AguaCapa3D` (presentacion/agua_capa_3d.gd),
## sin pasar por la maqueta ni por un nivel: un mapa pequeño con las tres situaciones de referencia en la misma escena y teclas para provocar cada efecto.
##
## El mapa (12 × 6 casillas, de izquierda a derecha):
##   · una TERRAZA de 1,2 u con un manantial: el agua baja por un pasillo de 2 casillas y hace la CASCADA (la caída supera UMBRAL_CAIDA);
##   · un RÍO (cauce rebajado) que sigue de la cascada hacia la izquierda, con una SALIDA al final (la corriente no se para);
##   · un POZO aparte (abajo a la izquierda) que se llena con su propio manantial (tecla P) y se puede helar.
## Es la MISMA simulación (`AguaSim3D`) que usa el juego; la capa solo la dibuja. Con T se alterna con `AguaRender3D` (el dibujo de siempre) para comparar.
##
## Teclas:   T capa nueva ↔ dibujo de siempre · M manantial de la cascada · P manantial del pozo · R reiniciar
##           clic izquierdo: ONDA (`impulso`) en el punto del ratón · A echar agua · V quitar agua · H helar (radio 1,5 u) · J derretir
##           I textura del hielo (la del bloque de hielo 3D) ↔ hielo procedural · clic derecho + arrastrar: girar · rueda: acercar · 1/2/3: cámara a la cascada / al río / al pozo · Espacio: pausa · F: velocidad ×0,25
## Abrir: laboratorios/LabAguaCapa3D.tscn y F6. Sin ventana no se ve nada (hace falta un renderizador de verdad).

const ANCHO: int = 12
const ALTO: int = 6
const SUB: int = 3
const S: float = 2.3
const ALTO_TERRAZA: float = 1.2
const FONDO_RIO: float = -0.4
const FONDO_POZO: float = -1.0
const CAUDAL_CASCADA: float = 3.0
const CAUDAL_POZO: float = 2.5

var agua: AguaSim3D = null
var capa: AguaCapa3D = null
var render: AguaRender3D = null
var _cam: Camera3D = null
var _suelo: Node3D = null
var _hud: Label = null
var _yaw: float = 0.35
var _pitch: float = 0.62
var _dist: float = 19.0
var _foco: Vector3 = Vector3(6.0 * S, 0.2, 3.0 * S)
var _manantial: bool = true
var _pozo_abierto: bool = false
var _usa_capa: bool = true
var _tex_hielo: bool = true
var _pausa: bool = false
var _lento: bool = false
var _arrastrando: bool = false
var _t_hud: float = 0.0


func _ready() -> void:
	_montar_escena()
	_reiniciar()
	_colocar_camara()


func _es_terraza(c: Vector2i) -> bool:
	return c.x >= 6


func _es_pasillo(c: Vector2i) -> bool:
	return c.y == 2 or c.y == 3


func _y_suelo(c: Vector2i) -> float:
	if _es_terraza(c):
		return ALTO_TERRAZA if _es_pasillo(c) else ALTO_TERRAZA + 1.0       # fuera del pasillo, el muro de la terraza
	if c.x <= 5 and _es_pasillo(c) and c.x >= 1:
		return FONDO_RIO
	if c.x >= 2 and c.x <= 3 and c.y >= 4:
		return FONDO_POZO
	return 0.0


func _es_pared(c: Vector2i) -> bool:
	return _es_terraza(c) and not _es_pasillo(c)


func _montar_escena() -> void:
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 200.0
	add_child(_cam)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	luz.light_energy = 1.0
	add_child(luz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.70, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 10.0)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.add_theme_font_size_override("font_size", 14)
	cl.add_child(_hud)


## Rehace el suelo, la simulación y las dos capas de dibujo (se llama al empezar y con R).
func _reiniciar() -> void:
	if capa != null:
		capa.enlazar(null)
		capa.queue_free()
	if render != null:
		render.queue_free()
	if _suelo != null:
		_suelo.queue_free()
	_suelo = Node3D.new()
	add_child(_suelo)
	for y in range(ALTO):
		for x in range(ANCHO):
			var c := Vector2i(x, y)
			var h: float = _y_suelo(c)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(S, 4.0, S)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.50, 0.42, 0.33) if _es_terraza(c) else Color(0.40, 0.35, 0.29)
			mi.material_override = m
			mi.position = Vector3((x + 0.5) * S, h - 2.0, (y + 0.5) * S)
			_suelo.add_child(mi)
	agua = AguaSim3D.new()
	agua.configurar(ANCHO, ALTO, SUB, S, _y_suelo, _es_pared)
	agua.fuente_en(Vector2i(9, 2), CAUDAL_CASCADA if _manantial else 0.0)
	agua.fuente_en(Vector2i(9, 3), CAUDAL_CASCADA if _manantial else 0.0)
	agua.fijar_nivel(Vector2i(0, 2), FONDO_RIO + 0.2)                      # la salida del río: la corriente no se estanca
	agua.fijar_nivel(Vector2i(0, 3), FONDO_RIO + 0.2)
	if _pozo_abierto:
		agua.fuente_en(Vector2i(2, 5), CAUDAL_POZO)
	render = AguaRender3D.new()
	add_child(render)
	render.enlazar(agua)
	capa = AguaCapa3D.new()
	add_child(capa)
	capa.enlazar(agua)
	capa.usar_textura_hielo(_tex_hielo)
	_aplicar_modo()


func _aplicar_modo() -> void:
	capa.visible = _usa_capa
	capa.process_mode = Node.PROCESS_MODE_INHERIT if _usa_capa else Node.PROCESS_MODE_DISABLED
	render.visible = not _usa_capa
	render.process_mode = Node.PROCESS_MODE_DISABLED if _usa_capa else Node.PROCESS_MODE_INHERIT


func _physics_process(delta: float) -> void:
	if agua != null and not _pausa:
		agua.paso(delta * (0.25 if _lento else 1.0))


func _process(delta: float) -> void:
	_t_hud += delta
	if _t_hud > 0.25 and agua != null:
		_t_hud = 0.0
		_refrescar_hud()


func _refrescar_hud() -> void:
	var t: String = "LAB CAPA DEL AGUA  ·  dibujo: %s  ·  %d fps\n" % ["CAPA NUEVA (AguaCapa3D)" if _usa_capa else "AguaRender3D (el de siempre)", Engine.get_frames_per_second()]
	t += "agua: %.1f u³  ·  manantial cascada: %s  ·  manantial pozo: %s%s\n" % [agua.volumen_total(), "abierto" if _manantial else "cerrado", "abierto" if _pozo_abierto else "cerrado", "  ·  PAUSA" if _pausa else ("  ·  ×0,25" if _lento else "")]
	if _usa_capa:
		var gpu: String = ("%.2f ms" % capa.milisegundos_gpu()) if capa.milisegundos_gpu() > 0.0 else "n/d"
		t += "capa: GPU %s (solo la pasada de estado; n/d = el motor no la mide) · lectura %.2f ms · cascadas %d · salpicadura %d puntos\n" % [gpu, capa.milisegundos_lectura(), capa.cascadas(), capa.salpicaduras_activas()]
	t += "T cambia de dibujo · M/P manantiales · clic: onda · A/V echar/quitar · H/J helar/derretir · I textura del hielo (%s) · 1/2/3 cámara · R reinicia" % ("con textura" if _tex_hielo else "procedural")
	_hud.text = t


func _punto_del_ratón() -> Vector3:
	var m: Vector2 = get_viewport().get_mouse_position()
	var o: Vector3 = _cam.project_ray_origin(m)
	var d: Vector3 = _cam.project_ray_normal(m)
	if absf(d.y) < 0.001:
		return Vector3.INF
	var t: float = (0.2 - o.y) / d.y
	return o + d * t if t > 0.0 else Vector3.INF


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_arrastrando = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(4.0, _dist * 0.9)
			_colocar_camara()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(60.0, _dist * 1.1)
			_colocar_camara()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector3 = _punto_del_ratón()
			if p != Vector3.INF:
				capa.impulso(p, -0.3, 0.7)
	elif ev is InputEventMouseMotion and _arrastrando:
		var mm := ev as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch + mm.relative.y * 0.005, 0.12, 1.45)
		_colocar_camara()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		_tecla((ev as InputEventKey).keycode)


func _tecla(k: Key) -> void:
	var p: Vector3 = _punto_del_ratón()
	match k:
		KEY_T:
			_usa_capa = not _usa_capa
			_aplicar_modo()
		KEY_M:
			_manantial = not _manantial
			agua.fuente_en(Vector2i(9, 2), CAUDAL_CASCADA if _manantial else 0.0)
			agua.fuente_en(Vector2i(9, 3), CAUDAL_CASCADA if _manantial else 0.0)
		KEY_P:
			_pozo_abierto = not _pozo_abierto
			agua.fuente_en(Vector2i(2, 5), CAUDAL_POZO if _pozo_abierto else 0.0)
		KEY_I:
			_tex_hielo = not _tex_hielo
			capa.usar_textura_hielo(_tex_hielo)
		KEY_R:
			_reiniciar()
		KEY_SPACE:
			_pausa = not _pausa
		KEY_F:
			_lento = not _lento
		KEY_A:
			if p != Vector3.INF:
				agua.anadir(p, 1.5, 0.8)
		KEY_V:
			if p != Vector3.INF:
				agua.quitar(p, 1.5, 0.8)
		KEY_H:
			if p != Vector3.INF:
				agua.helar(p, 1.5)
		KEY_J:
			if p != Vector3.INF:
				agua.derretir(p, 1.5)
		KEY_1:
			_enfocar(Vector3(6.0 * S, 0.6, 3.0 * S), 12.0, 0.45)
		KEY_2:
			_enfocar(Vector3(3.0 * S, -0.2, 3.0 * S), 13.0, 0.9)
		KEY_3:
			_enfocar(Vector3(3.0 * S, -0.4, 5.0 * S), 9.0, 0.85)


func _enfocar(foco: Vector3, dist: float, pitch: float) -> void:
	_foco = foco
	_dist = dist
	_pitch = pitch
	_colocar_camara()


func _colocar_camara() -> void:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.look_at_from_position(_foco + off, _foco)
