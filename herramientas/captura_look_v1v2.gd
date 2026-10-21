extends SceneTree
## CAPTURAS ANTES / DESPUÉS de V1+V2 de docs/PLAN_EOW_VISUAL.md (Pipeline, 21/10). NECESITA VENTANA (no sirve con --headless: sin GPU no hay imagen).
## Saca la MISMA vista de la maqueta con todo como antes («antes») y con el look nuevo («despues»), y mide el color medio de la hierba y de la tierra
## (para elegir el tonemap sin fiarse del ojo) y el tiempo de fotograma.
##   godot --path . --script res://herramientas/captura_look_v1v2.gd -- <lab|bosque> <antes|despues> <carpeta> [tonemap=linear|filmic|agx|aces|reinhard] [expo=1.0] [ssao=0|1]
## «antes»  = Posproceso3D.activo=false + zona «clasico» + sin tilt-shift ni sonda: EXACTAMENTE la maqueta de antes de V1/V2.
## «despues» = los valores de serie de ahora. `tonemap=` y `ssao=` sobrescriben UNA cosa del «despues» para compararla.
const S: float = 2.3
const VISTAS: Dictionary = {
	"lab": {
		"escena": "res://laboratorios/LabPlaytestEoW.tscn",
		# nombre: [casilla x, casilla y, tamaño de cámara]. Salas de 7x7: sala 1 (4,4), sala 2 (12,4), sala 5 (4,12).
		"vistas": {"sala1": [4.0, 4.0, 10.0], "sala2": [12.0, 4.0, 10.0], "sala5": [4.0, 12.0, 10.0]},
	},
	"bosque": {
		"escena": "res://escenas/PruebaBosque01.tscn",
		"vistas": {"jugador": [-1.0, -1.0, 16.0]},   # x = -1: se queda con la cámara del jugador (la vista por defecto)
	},
}
const MAPAS_TONEMAP: Dictionary = {
	"linear": Environment.TONE_MAPPER_LINEAR, "reinhard": Environment.TONE_MAPPER_REINHARDT, "filmic": Environment.TONE_MAPPER_FILMIC,
	"aces": Environment.TONE_MAPPER_ACES, "agx": Environment.TONE_MAPPER_AGX,
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <lab|bosque> <antes|despues> <carpeta> [tonemap=..] [ssao=0|1]")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	var tm: String = ""
	var ssao: int = -1
	var expo: float = -1.0
	for i in range(3, a.size()):
		if a[i].begins_with("tonemap="):
			tm = a[i].substr(8)
		elif a[i].begins_with("expo="):
			expo = float(a[i].substr(5))
		elif a[i].begins_with("ssao="):
			ssao = int(a[i].substr(5))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # para medir el tiempo de fotograma sin el tope del monitor
	Engine.max_fps = 0
	Posproceso3D.activo = not antes
	var esc: PackedScene = load(VISTAS[cual]["escena"])
	var m: Node3D = esc.instantiate()
	if antes:
		m.set("zona_luz", "clasico")
		m.set("tilt_shift", false)
		m.set("sonda_reflejos", false)
	root.add_child(m)
	for _i in 120:
		await process_frame
	_ocultar_ui(root)
	var env: Environment = _entorno(m)
	if env != null:
		if tm != "" and MAPAS_TONEMAP.has(tm):
			env.tonemap_mode = MAPAS_TONEMAP[tm] as Environment.ToneMapper
		if expo > 0.0:
			env.tonemap_exposure = expo
		if ssao >= 0:
			env.ssao_enabled = ssao == 1
	var etiqueta: String = ("antes" if antes else "despues") + (("_" + tm) if tm != "" else "") + (("_ssao" + str(ssao)) if ssao >= 0 else "") + (("_e" + str(expo)) if expo > 0.0 else "")
	DirAccess.make_dir_recursive_absolute(carpeta)
	var vistas: Dictionary = VISTAS[cual]["vistas"]
	for k in vistas.keys():
		var v: Array = vistas[k]
		if float(v[0]) >= 0.0:
			m.set("_jugador", null)
			m.set("_foco", Vector3((float(v[0]) + 0.5) * S, 0.5, (float(v[1]) + 0.5) * S))
		m.set("_tam_camara", float(v[2]))
		m.get("_camara").size = float(v[2])
		m.call("_colocar_camara")
		for _i in 40:
			await process_frame
		# Tiempo de fotograma: 120 fotogramas sin vsync (el ciclo incluye el dibujado; si la GPU manda, se nota).
		var t0: int = Time.get_ticks_usec()
		for _i in 120:
			await process_frame
		var ms: float = float(Time.get_ticks_usec() - t0) / 120000.0
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/%s_%s_%s.png" % [carpeta, cual, k, etiqueta]
		img.save_png(ruta)
		print("MEDIDA %s | %s | %s | fotograma %.2f ms (%.0f fps) | %s" % [cual, k, etiqueta, ms, 1000.0 / maxf(ms, 0.001), _colores(img)])
	print("renderer: %s · SSAO %s · tonemap %d · FXAA %d" % [RenderingServer.get_current_rendering_method(),
		str(env.ssao_enabled) if env != null else "?", env.tonemap_mode if env != null else -1, root.screen_space_aa])
	quit()


func _entorno(m: Node) -> Environment:
	for h in m.get_children():
		if h is WorldEnvironment:
			return (h as WorldEnvironment).environment
	return null


## Color medio de los píxeles «hierba» (verdes) y «tierra» (naranja-marrón) y de toda la imagen (saltando de 3 en 3 para ir rápido).
func _colores(img: Image) -> String:
	var g := Vector3.ZERO
	var t := Vector3.ZERO
	var todo := Vector3.ZERO
	var ng := 0
	var nt := 0
	var n := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c: Color = img.get_pixel(x, y)
			todo += Vector3(c.r, c.g, c.b)
			n += 1
			if c.s < 0.15 or c.v < 0.15:
				continue
			var h: float = c.h * 360.0
			if h > 70.0 and h < 150.0:
				g += Vector3(c.r, c.g, c.b)
				ng += 1
			elif h > 15.0 and h < 40.0:
				t += Vector3(c.r, c.g, c.b)
				nt += 1
	return "hierba %s (%d px) · tierra %s (%d px) · media %s" % [_hex(g, ng), ng, _hex(t, nt), nt, _hex(todo, n)]


func _hex(s: Vector3, n: int) -> String:
	if n == 0:
		return "-"
	var c := Color(s.x / n, s.y / n, s.z / n)
	return "#%s (S %.2f V %.2f)" % [c.to_html(false), c.s, c.v]


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
