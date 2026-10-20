extends Node3D
## LABORATORIO DEL CONSUMO POR FUEGO (Pipeline, 20/10). Una fila de piezas reales de `Pieza3D` para ver cómo se destruyen al arder:
## el efecto NUEVO (`ConsumoFuego3D`: frente de brasa, hundimiento, brasas, humo, ceniza) frente al de ahora (`Reactivo3D._consumir`: aplastar en Y en 0,5 s).
## Teclas:  Espacio = quemar todo con el NUEVO     V = quemar todo con el de AHORA     N = quemar solo la pieza marcada (con el nuevo)
##          Tab = marcar la siguiente      P = el frente nace en un punto (como si te alcanzara un hechizo) / sube desde la base      R = reponer
##          D = duración 1,0 / 1,6 / 2,4 s      T = cámara lenta (¼)      botón derecho: girar · rueda: zoom · Esc: salir
const IDS: Array = ["hierba_alta", "helecho", "juncos", "arbusto_otono", "valla", "cartel", "caja", "barril", "tronco", "puesto"]
const DURACIONES: Array = [1.0, 1.6, 2.4]

var _piezas: Array = []           ## [id, Node3D]
var _cam: Camera3D = null
var _hud: Label = null
var _i_dur: int = 1
var _sel: int = 0
var _desde_punto: bool = false
var _lento: bool = false
var _giro: float = 20.0
var _incl: float = 28.0
var _dist: float = 8.0
var _arrastrando: bool = false
var _foco: Vector3 = Vector3(0.0, 0.8, 0.0)


func _ready() -> void:
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 24)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.40, 0.50, 0.28)
	suelo.material_override = ms
	add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.shadow_enabled = true
	add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.far = 200.0
	add_child(_cam)
	_cam.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(_hud)
	_reponer()
	_colocar_camara()


func _reponer() -> void:
	for p in _piezas:
		if is_instance_valid(p[1]):
			(p[1] as Node).queue_free()
	_piezas.clear()
	for k in range(IDS.size()):
		var id: String = IDS[k]
		var v: Node3D = Pieza3D.crear_visual(id)
		if v == null:
			continue
		var cont := Node3D.new()                       # hace de Reactivo: su origen es la base
		cont.position = Vector3((float(k) - (IDS.size() - 1) * 0.5) * 2.3, 0.0, 0.0)
		add_child(cont)
		cont.add_child(v)
		_piezas.append([id, cont])
	_refrescar()


func _refrescar() -> void:
	var nombre: String = String(_piezas[_sel][0]) if not _piezas.is_empty() else "-"
	_hud.text = "Espacio: quemar todo (NUEVO) · V: quemar todo (el de AHORA) · N: solo «%s» (Tab cambia) · R: reponer\nduración %.1f s (D) · frente: %s (P) · cámara lenta: %s (T)" % [
		nombre, DURACIONES[_i_dur], "desde un punto" if _desde_punto else "desde la base", "sí" if _lento else "no"]


func _quemar_nuevo(i: int) -> void:
	var cont: Node3D = _piezas[i][1]
	if not is_instance_valid(cont) or cont.get_child_count() == 0 or cont.has_meta("quemado"):
		return
	cont.set_meta("quemado", true)
	var v: Node3D = cont.get_child(0)
	var origen: Vector3 = Vector3.INF
	if _desde_punto:
		origen = cont.global_position + Vector3(0.35, 0.3, 0.0)
	ConsumoFuego3D.consumir(v, DURACIONES[_i_dur], origen, self)


func _quemar_viejo(i: int) -> void:
	# Réplica de Reactivo3D._consumir: ceniza (no se ve aquí) y el cuerpo se aplasta a Y = 0,05 en 0,5 s.
	var cont: Node3D = _piezas[i][1]
	if not is_instance_valid(cont) or cont.has_meta("quemado"):
		return
	cont.set_meta("quemado", true)
	var tw := create_tween()
	tw.tween_property(cont, "scale", Vector3(1.0, 0.05, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(cont.queue_free)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE:
				for i in range(_piezas.size()):
					_quemar_nuevo(i)
			KEY_V:
				for i in range(_piezas.size()):
					_quemar_viejo(i)
			KEY_N:
				if not _piezas.is_empty():
					_quemar_nuevo(_sel)
			KEY_TAB:
				_sel = (_sel + 1) % maxi(1, _piezas.size())
			KEY_P:
				_desde_punto = not _desde_punto
			KEY_D:
				_i_dur = (_i_dur + 1) % DURACIONES.size()
			KEY_T:
				_lento = not _lento
				Engine.time_scale = 0.25 if _lento else 1.0
			KEY_R:
				_reponer()
			KEY_ESCAPE:
				Engine.time_scale = 1.0
				get_tree().quit()
		_refrescar()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_arrastrando = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(3.0, _dist * 0.9)
			_colocar_camara()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(40.0, _dist * 1.1)
			_colocar_camara()
	elif ev is InputEventMouseMotion and _arrastrando:
		_giro -= ev.relative.x * 0.4
		_incl = clampf(_incl + ev.relative.y * 0.3, 5.0, 85.0)
		_colocar_camara()


func _colocar_camara() -> void:
	var e: float = deg_to_rad(_incl)
	var dir: Vector3 = Vector3(0.0, -sin(e), -cos(e)).rotated(Vector3.UP, deg_to_rad(_giro))
	_cam.fov = 40.0
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * _dist)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
