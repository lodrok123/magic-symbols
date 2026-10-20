extends Node3D
## LABORATORIO de la lámina de agua y la orilla (Pipeline, 20/10, DIARIO 211). Dibuja con el `AguaRender3D` DEL JUEGO (no con la capa) un pozo, un canal y un
## estanque con las medidas reales del mapa (S = 2,3; bloque ALTO = S·0,45; agua llena a ALTO − 0,04; lecho 0,9 u más abajo), cada casilla seca con su bloque,
## para ver cómo queda el agua contra el borde del bloque y cómo respira la orilla.
## Teclas:
##   B  bajada de la lámina: 0 → 0,04 → 0,08 (la elegida) → 0,12 → 0,16 u      O  vaivén de orilla: 0 → 0,01 → 0,02 (el elegido) → 0,04 u
##   1 / 2 / 3  mirar el pozo / el canal / el estanque       C  cámara: del juego (ortogonal, 60°) → de perfil (casi de canto) → libre (perspectiva)
##   H  alterna entre «antes» (0 / 0) y «después» (valores elegidos)      L  línea roja a la altura de la cara del bloque (para ver el margen)
##   P  pausa el reloj del agua      botón derecho + arrastrar: girar      rueda: zoom      Esc: salir
## Qué mirar: con «antes» el agua llega casi a ras del borde del bloque (0,04 u); con «después» queda hundida y la orilla se mece muy despacio.

const S: float = 2.3
const ALTO: float = S * 0.45
const ALTO_AGUA: float = ALTO - 0.04
const LECHO: float = 0.9
const ANCHO: int = 14
const FONDO: int = 10
const BAJADAS: Array = [0.0, 0.04, 0.08, 0.12, 0.16]
const VAIVENES: Array = [0.0, 0.01, 0.02, 0.04]
const FOCOS: Array = [Vector2(2.5, 2.5), Vector2(6.0, 6.5), Vector2(9.0, 2.5)]

var _agua: Array[Vector2i] = []
var _sim: AguaSim3D = null
var _render: AguaRender3D = null
var _cam: Camera3D = null
var _hud: Label = null
var _linea: MeshInstance3D = null
var _i_bajada: int = 2
var _i_vaiven: int = 2
var _modo_cam: int = 0
var _foco: Vector3 = Vector3(6.0 * S, ALTO, 6.5 * S)
var _giro: float = 0.0
var _incl: float = 60.0
var _dist: float = 14.0
var _tam: float = 6.0
var _arrastrando: bool = false
var _pausa: bool = false


func _ready() -> void:
	_agua.append(Vector2i(2, 2))
	for x in range(1, 12):
		_agua.append(Vector2i(x, 6))
	for x in range(7, 11):
		for y in range(1, 4):
			_agua.append(Vector2i(x, y))
	_montar()
	_colocar_camara()
	_refrescar()


func _es_agua(c: Vector2i) -> bool:
	return _agua.has(c)


func _suelo(c: Vector2i) -> float:
	return ALTO_AGUA - LECHO if _es_agua(c) else ALTO


func _montar() -> void:
	var mat_tierra := StandardMaterial3D.new()
	mat_tierra.albedo_color = Color(0.46, 0.55, 0.30)
	var mat_lecho := StandardMaterial3D.new()
	mat_lecho.albedo_color = Color(0.55, 0.47, 0.34)
	for y in range(FONDO):
		for x in range(ANCHO):
			var c := Vector2i(x, y)
			var top: float = _suelo(c)
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(S, top + 1.0, S)
			b.mesh = bm
			b.material_override = mat_lecho if _es_agua(c) else mat_tierra
			b.position = Vector3((x + 0.5) * S, (top - 1.0) * 0.5, (y + 0.5) * S)
			add_child(b)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.far = 300.0
	add_child(_cam)
	_cam.current = true
	_sim = AguaSim3D.new()
	_sim.configurar(ANCHO, FONDO, 3, S, _suelo, func(_c: Vector2i) -> bool: return false)
	for c in _agua:
		_sim.llenar_casilla(c, ALTO_AGUA)
	_render = AguaRender3D.new()
	add_child(_render)
	_render.enlazar(_sim)
	# Línea de referencia: una lámina roja muy fina a la altura de la cara del bloque, solo sobre las casillas de agua (para ver cuánto falta).
	_linea = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in _agua:
		var x0: float = c.x * S
		var z0: float = c.y * S
		var y: float = ALTO + 0.003
		for par in [[Vector3(x0, y, z0), Vector3(x0 + S, y, z0)], [Vector3(x0, y, z0 + S), Vector3(x0 + S, y, z0 + S)], [Vector3(x0, y, z0), Vector3(x0, y, z0 + S)], [Vector3(x0 + S, y, z0), Vector3(x0 + S, y, z0 + S)]]:
			im.surface_add_vertex(par[0])
			im.surface_add_vertex(par[1])
	im.surface_end()
	_linea.mesh = im
	var ml := StandardMaterial3D.new()
	ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ml.albedo_color = Color(1.0, 0.15, 0.15)
	_linea.material_override = ml
	_linea.visible = false
	add_child(_linea)
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(_hud)


func _process(delta: float) -> void:
	if not _pausa and _sim != null:
		_sim.paso(delta)


func _refrescar() -> void:
	_render.bajada_lamina = BAJADAS[_i_bajada]
	_render.orilla_mov = VAIVENES[_i_vaiven]
	var margen: float = (ALTO - ALTO_AGUA) + BAJADAS[_i_bajada]
	_hud.text = "bajada de la lámina %.2f u  (B) · margen real con el borde del bloque %.2f u\nvaivén de la orilla %.2f u  (O) · cresta a %.2f u del borde\ncámara %s (C) · 1/2/3 pozo/canal/estanque · H antes/después · L línea roja · P pausa" % [
		BAJADAS[_i_bajada], margen, VAIVENES[_i_vaiven], margen - VAIVENES[_i_vaiven],
		["del juego", "de perfil", "libre"][_modo_cam]]


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_B:
				_i_bajada = (_i_bajada + 1) % BAJADAS.size()
			KEY_O:
				_i_vaiven = (_i_vaiven + 1) % VAIVENES.size()
			KEY_H:
				var antes: bool = _i_bajada == 0 and _i_vaiven == 0
				_i_bajada = 2 if antes else 0
				_i_vaiven = 2 if antes else 0
			KEY_L:
				_linea.visible = not _linea.visible
			KEY_P:
				_pausa = not _pausa
			KEY_C:
				_modo_cam = (_modo_cam + 1) % 3
			KEY_1, KEY_2, KEY_3:
				var f: Vector2 = FOCOS[int(ev.keycode - KEY_1)]
				_foco = Vector3(f.x * S, ALTO, f.y * S)
			KEY_ESCAPE:
				get_tree().quit()
		_colocar_camara()
		_refrescar()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_arrastrando = ev.pressed
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tam = maxf(1.5, _tam * 0.9)
			_dist = maxf(3.0, _dist * 0.9)
			_colocar_camara()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tam = minf(30.0, _tam * 1.1)
			_dist = minf(60.0, _dist * 1.1)
			_colocar_camara()
	elif ev is InputEventMouseMotion and _arrastrando:
		_giro -= ev.relative.x * 0.4
		_incl = clampf(_incl + ev.relative.y * 0.3, 8.0, 86.0)
		_modo_cam = 2
		_colocar_camara()
		_refrescar()


func _colocar_camara() -> void:
	if _cam == null:
		return
	var incl: float = _incl
	var giro: float = _giro
	match _modo_cam:
		0:
			incl = 60.0
			giro = 0.0
		1:
			incl = 84.0                       # en el juego `INCLINACION` es el ángulo desde la vertical del rayo: 84 = mirada casi horizontal (6° sobre el plano)
			giro = 0.0
	var e: float = deg_to_rad(90.0 - incl)
	var dir: Vector3 = (-Vector3(0.0, sin(e), cos(e))).rotated(Vector3.UP, deg_to_rad(giro))
	if _modo_cam == 2:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 45.0
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * _dist)
	else:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = _tam if _modo_cam == 0 else minf(_tam, 3.0)
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * 40.0)
