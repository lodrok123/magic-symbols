extends SceneTree

## CAPTURA Y MEDIDA de la altura de la lámina de agua y del vaivén de orilla (Pipeline, 20/10, DIARIO 211). No es una prueba: sirve para mirar y medir.
## Monta, con las medidas reales del mapa (prueba_test2.gd: S = 2,3; bloque ALTO = S·0,45; agua llena a ALTO − 0,04; lecho 0,9 u más abajo),
## un POZO (1 casilla), un CANAL (fila de casillas) y un ESTANQUE (4×3), con un bloque de tierra en cada casilla seca, y dibuja el agua con el
## `AguaRender3D` que haya en el proyecto (el original o el retocado: se lanza dos veces, una en cada copia). Cámara del juego: ortogonal, tamaño 6, 60°.
## Imprime: la Y de la cara superior de los bloques, la Y a la que se dibuja el agua llena (sim − bajada), el margen, y el coste por fotograma.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_lamina_agua.gd -- <prefijo> [fotogramas para medir]
## Escribe `<prefijo>_pozo.png`, `_canal.png`, `_estanque.png` (cámara del juego) y `_perfil.png` (casi de canto, para ver el margen contra el bloque).

const S: float = 2.3
const ALTO: float = S * 0.45
const ALTO_AGUA: float = ALTO - 0.04
const LECHO: float = 0.9
const ANCHO: int = 14
const FONDO: int = 10
var _vp: SubViewport = null
var _cam: Camera3D = null
var _sim: AguaSim3D = null
var _agua: Array[Vector2i] = []


func _initialize() -> void:
	_correr()


func _es_agua(c: Vector2i) -> bool:
	return _agua.has(c)


func _suelo(c: Vector2i) -> float:
	return ALTO_AGUA - LECHO if _es_agua(c) else ALTO


func _foto(foco: Vector3, ruta: String, incl: float = 60.0, tam: float = 6.0) -> void:
	var e: float = deg_to_rad(90.0 - incl)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = tam
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)
	await process_frame
	await process_frame
	_vp.get_texture().get_image().save_png(ruta)


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var pref: String = a[0] if a.size() > 0 else "/tmp/lam/x"
	var n_med: int = int(a[1]) if a.size() > 1 else 240
	_agua.append(Vector2i(2, 2))                                   # pozo
	for x in range(1, 12):
		_agua.append(Vector2i(x, 6))                                # canal
	for x in range(7, 11):
		for y in range(1, 4):
			_agua.append(Vector2i(x, y))                             # estanque
	await process_frame
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
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
			b.position = Vector3((x + 0.5) * S, (top - 1.0) * 0.5, (y + 0.5) * S)   # cara superior exactamente en `top`
			mundo.add_child(b)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	mundo.add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	_cam = Camera3D.new()
	_cam.far = 200.0
	mundo.add_child(_cam)
	_cam.current = true
	_sim = AguaSim3D.new()
	_sim.configurar(ANCHO, FONDO, 3, S, _suelo, func(_c: Vector2i) -> bool: return false)
	for c in _agua:
		_sim.llenar_casilla(c, ALTO_AGUA)
	var r := AguaRender3D.new()
	mundo.add_child(r)
	r.enlazar(_sim)
	for i in range(90):
		_sim.paso(1.0 / 30.0)
		await process_frame
	# --- Medida: Y de la sim (lo que el dibujo antiguo pintaba) y Y que se pinta ahora, en el centro de cada casilla llena ---
	var im: Image = _sim.imagen()
	var bajada: float = float(r.get_script().get_script_constant_map().get("BAJADA_LAMINA", 0.0))   # 0 en el original
	for nombre in ["pozo", "canal", "estanque"]:
		var c: Vector2i = {"pozo": Vector2i(2, 2), "canal": Vector2i(5, 6), "estanque": Vector2i(8, 2)}[nombre]
		var px: Color = im.get_pixel(c.x * 3 + 1, c.y * 3 + 1)
		var dibujada: float = px.r - minf(bajada, 0.5 * px.g)
		print("%-8s sim Y %.4f · prof %.3f · dibujada %.4f · cara del bloque vecino %.4f · margen %.4f u" % [nombre, px.r, px.g, dibujada, ALTO, ALTO - dibujada])
	print("bajada usada: %.3f u" % bajada)
	# --- Capturas a la distancia de cámara del juego ---
	var h: float = ALTO
	await _foto(Vector3(2.5 * S, h, 2.5 * S), pref + "_pozo.png")
	await _foto(Vector3(6.0 * S, h, 6.5 * S), pref + "_canal.png")
	await _foto(Vector3(9.0 * S, h, 2.5 * S), pref + "_estanque.png")
	# Perfil: casi de canto (10° sobre el plano), mirando por el eje del canal para ver el agua contra la cara del bloque.
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 3.0
	_cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.12, -1.0), Vector3.UP), Vector3(5.0 * S, ALTO + 0.5, 12.0 * S))
	await process_frame
	await process_frame
	_vp.get_texture().get_image().save_png(pref + "_perfil.png")
	# --- Coste: milisegundos de pared por fotograma (llvmpipe: CPU, no GPU; sirve para comparar las dos versiones entre sí) ---
	await _foto(Vector3(6.0 * S, h, 4.5 * S), pref + "_general.png", 60.0, 14.0)
	var t0: int = Time.get_ticks_usec()
	for i in range(n_med):
		await process_frame
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(n_med)
	print("MS_POR_FOTOGRAMA %.3f (%d fotogramas, vista general, 14×10 casillas)" % [ms, n_med])
	quit()
