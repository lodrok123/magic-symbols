extends SceneTree

## CAPTURA Y MEDIDA de la capa visual del agua (Pipeline, 20/10, W1): monta la MISMA simulación (un pozo que se llena, una escalera de agua y un río) y la
## dibuja con el dibujo de siempre (`AguaRender3D`) o con la capa nueva (`AguaCapa3D`), y escribe una imagen y cifras. No es una prueba (la prueba es
## `prueba_agua_capa.gd`): sirve para mirar. Hace falta ventana (xvfb en el sandbox):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_agua_capa.gd -- <prefijo> <viejo|nuevo> [segundos] [casillas por lado]
## Escribe `<prefijo>_<modo>_0.png` (vista general) y `_1.png` (cerca de la escalera) y por la salida estándar la altura y la espuma medidas.

const S: float = 2.3
var LADO: int = 12
var _sim: AguaSim3D = null
var _vp: SubViewport = null
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _suelo(c: Vector2i) -> float:
	if c.x >= 1 and c.x <= 3 and c.y >= 1 and c.y <= 3:
		return -1.0                                   # el pozo
	if c.y >= 6 and c.y <= 9:
		return -0.4 if c.x <= 5 else -1.45            # el río, con un escalón de 1,05 u en x = 6
	return 0.0


func _pared(c: Vector2i) -> bool:
	return false


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var pref: String = a[0] if a.size() > 0 else "/tmp/cap/agua"
	var modo: String = a[1] if a.size() > 1 else "nuevo"
	var seg: float = float(a[2]) if a.size() > 2 else 14.0
	LADO = int(a[3]) if a.size() > 3 else 12          # casillas por lado del mapa: con 40 se mide el coste a escala de un nivel (el GPU solo se mide con Vulkan)
	await process_frame
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	_sim = AguaSim3D.new()
	_sim.configurar(LADO, LADO, 3, S, _suelo, _pared)
	_sim.fuente_en(Vector2i(2, 2), 2.0)
	_sim.fuente_en(Vector2i(0, 7), 3.0)
	_sim.fuente_en(Vector2i(0, 8), 3.0)
	# Suelo (un plano oscuro a Y = -1,6, por debajo de todo) y luz
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LADO * S + 6.0, LADO * S + 6.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.45, 0.38, 0.28)
	suelo.material_override = ms
	suelo.position = Vector3(LADO * S * 0.5, -1.6, LADO * S * 0.5)
	mundo.add_child(suelo)
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
	_cam.fov = 45.0
	mundo.add_child(_cam)
	_cam.look_at_from_position(Vector3(LADO * S * 0.5, 17.0, LADO * S * 1.25), Vector3(LADO * S * 0.5, -0.5, LADO * S * 0.55), Vector3.UP)
	_cam.current = true
	var dibujo: Node = null
	if modo == "viejo":
		var r := AguaRender3D.new()
		mundo.add_child(r)
		r.enlazar(_sim)
		dibujo = r
	else:
		var c := AguaCapa3D.new()
		mundo.add_child(c)
		c.enlazar(_sim)
		dibujo = c
	var t: float = 0.0
	var dt: float = 1.0 / 30.0
	var t0: int = Time.get_ticks_msec()
	while t < seg:
		_sim.paso(dt)
		await process_frame
		t += dt
	_vp.get_texture().get_image().save_png("%s_%s_0.png" % [pref, modo])
	_cam.look_at_from_position(Vector3(S * 7.0, 6.0, S * 11.0), Vector3(S * 6.5, -1.0, S * 7.5), Vector3.UP)
	await process_frame
	await process_frame
	await process_frame
	_vp.get_texture().get_image().save_png("%s_%s_1.png" % [pref, modo])
	print("modo %s · %.0f s simulados en %d ms de pared · agua %.1f u³" % [modo, seg, Time.get_ticks_msec() - t0, _sim.volumen_total()])
	if dibujo is AguaCapa3D:
		var c2: AguaCapa3D = dibujo
		var im: Image = c2.imagen_estado()
		if im != null:
			var mx_e: float = 0.0
			var espuma: float = 0.0
			var n_esp: int = 0
			for y in range(im.get_height()):
				for x in range(im.get_width()):
					var px: Color = im.get_pixel(x, y)
					mx_e = maxf(mx_e, absf(px.r))
					espuma += px.b
					if px.b > 0.3:
						n_esp += 1
			print("capa %s · pasos %d · |error de altura| máx %.4f u · espuma suma %.1f, texels > 0,3: %d · GPU %.3f ms · lectura %.3f ms" % [str(c2.dimension_fina()), c2.pasos(), mx_e, espuma, n_esp, c2.milisegundos_gpu(), c2.milisegundos_lectura()])
		else:
			print("sin imagen de estado")
	quit()
