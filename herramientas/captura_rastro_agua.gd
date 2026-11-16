extends "res://herramientas/escenario_base.gd"

## RASTRO DEL AGUA DENTRO DEL JUEGO (16/11/2026): ¿el agua que DIBUJA el toy es la que moja el suelo? Lanza un pilar y un muro de agua REALES (compone el hechizo y lo lanza el Lanzador3D, no se
## instancia el toy a mano) en PruebaBosque, con la cámara casi cenital, y cada instante clave (durante la figura, al morir, +1, +3, +8 s) hace dos cosas:
##   · IMPRIME en números el centro y la extensión del dibujo (el AguaToy: posición y semiejes en el mundo) frente al centro y la extensión de lo MOJADO (casillas de la simulación con
##     `casilla_mojada` o con agua, alrededor del sitio), y los tiempos;
##   · guarda una tira temporal (un PNG por figura).
## Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_rastro_agua.gd -- docs/capturas/columnas_2026-11-16/rastro_juego_antes

const TAM: Vector2i = Vector2i(1000, 720)
const INSTANTES: Array = [["figura", 1.2], ["muere", -1.0], ["+1 s", 1.0], ["+3 s", 3.0], ["+8 s", 8.0], ["+25 s", 25.0], ["+33 s", 33.0]]    # +25 y +33: ¿cuánto dura el mojado? (20 s antes de 16/11, ~30 s ahora)
const FIGURAS: Array = [
	["pilar", ["altura", "altura", "altura"]],
	["muro", ["barrera", "linea_x", "linea_x"]],
]
var DESDE: Vector2i = Vector2i(6, 24)       # se sustituye por un sitio SECO y despejado (en el Bosque el agua del río ya moja medio mapa)

var _base: Dictionary = {}                   # casillas ya mojadas ANTES de lanzar (el río, un charco): no cuentan como rastro del hechizo
var _dir: String = "docs/capturas/columnas_2026-11-16/rastro_juego_antes"


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await cargar()
	maqueta.set("_incl", 4.0)                      # casi cenital: ver la huella en el suelo
	maqueta.set("_tam_camara", 16.0)
	DESDE = _buscar_seco()
	print("sitio seco y despejado: jugador en %s" % str(DESDE))
	for f in FIGURAS:
		await _una(String(f[0]), f[1] as Array)
	print("CAPTURAS en " + _dir)


## Primera casilla desde la que, hacia el este, hay 8 casillas libres de altura 0 y nada mojado a ±9 casillas (si no, lo medido sería el río y no el hechizo).
func _buscar_seco() -> Vector2i:
	for y in range(10, 50):
		for x in range(4, 30):
			var ok: bool = true
			for dx in range(0, 9):
				for dy in range(-3, 4):
					var c: Vector2i = Vector2i(x + dx, y + dy)
					if not Terreno3D.en_mapa(c) or Lanzador3D.bloqueada(c) or Lanzador3D.altura_en(c) != 0:
						ok = false
			if ok and int(_mojado(Vector2i(x + 3, y))["n"]) == 0:
				return Vector2i(x, y)
	return Vector2i(6, 24)


func _toy() -> Node3D:
	for n in maqueta.find_children("*", "AguaToy", true, false):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			return n as Node3D
	return null


## Casillas mojadas (agua o suelo mojado) en un cuadrado de ±9 casillas alrededor de `c0`: [n, centro (x, z), min, max] en metros del mundo.
func _mojado(c0: Vector2i) -> Dictionary:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var n: int = 0
	var sx: float = 0.0
	var sz: float = 0.0
	var mn: Vector2 = Vector2(1.0e9, 1.0e9)
	var mx: Vector2 = Vector2(-1.0e9, -1.0e9)
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var c: Vector2i = c0 + Vector2i(dx, dy)
			if not Terreno3D.en_mapa(c):
				continue
			if (sim.casilla_mojada(c) or sim.profundidad_casilla(c) > 0.02) and not _base.has(c):
				var p: Vector3 = Terreno3D.centro_de(c, 0.0)
				n += 1
				sx += p.x
				sz += p.z
				mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
				mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	if n == 0:
		return {"n": 0}
	return {"n": n, "centro": Vector2(sx / n, sz / n), "min": mn, "max": mx}


func _imprime(etq: String, t: float, c0: Vector2i) -> void:
	var toy: Node3D = _toy()
	var dib: String = "sin toy"
	if toy != null:
		var s: Vector3 = toy.get("semieje_x") as float * Vector3.RIGHT + (toy.get("semieje_y") as float) * Vector3.UP + (toy.get("semieje_z") as float) * Vector3.BACK
		dib = "toy en (%.2f, %.2f) semiejes %s figura %d crece %.2f corte %.2f huella(meta) %s" % [toy.global_position.x, toy.global_position.z, str(s), int(toy.get("figura")), float(toy.get("crece")), float(toy.get("corte")), str(toy.get_meta("huella", "-"))]
	var m: Dictionary = _mojado(c0)
	var moj: String = "nada mojado"
	if int(m["n"]) > 0:
		moj = "%d casillas, centro (%.2f, %.2f), x %.2f..%.2f, z %.2f..%.2f" % [int(m["n"]), (m["centro"] as Vector2).x, (m["centro"] as Vector2).y, (m["min"] as Vector2).x, (m["max"] as Vector2).x, (m["min"] as Vector2).y, (m["max"] as Vector2).y]
	print("RASTRO %s t=%.2f | DIBUJO: %s | MOJADO: %s" % [etq, t, dib, moj])


func _foto(nombre: String) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	return img.get_region(Rect2i(150, 60, 700, 600))


func _una(nombre: String, glifos: Array) -> void:
	colocar_jugador(DESDE)
	await avanzar_s(0.5)
	_base.clear()
	var sim0: AguaSim3D = Terreno3D.agua_sim
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var cb: Vector2i = DESDE + Vector2i(3 + dx, dy)
			if Terreno3D.en_mapa(cb) and (sim0.casilla_mojada(cb) or sim0.profundidad_casilla(cb) > 0.02):
				_base[cb] = true
	print("antes de lanzar: %d casillas ya mojadas alrededor (no cuentan)" % _base.size())
	var c_hit: Vector2i = DESDE + Vector2i(3, 0)
	var salio: bool = lanzar("agua", glifos, Vector3.RIGHT)
	print("== %s: sale %s; el jugador en %s, apunta al este" % [nombre, str(salio), str(DESDE)])
	var t0: float = reloj.t
	var fotos: Array = []
	var rotulos: Array = []
	var t_muere: float = -1.0
	for inst in INSTANTES:
		var etq: String = String(inst[0])
		var dt: float = float(inst[1])
		if etq == "muere":
			# espera a que el toy esté a punto de acabar: su propia expiración (vida del hechizo)
			var guard: float = reloj.t
			while _toy() != null and reloj.t - guard < 40.0:
				if float(_toy().get("corte")) > 0.2:
					break
				await process_frame
			t_muere = reloj.t
			await avanzar_s(0.5)
		elif etq == "figura":
			await avanzar_s(dt)
		else:
			var objetivo: float = t_muere + dt + 0.5
			if reloj.t < objetivo:
				await avanzar_s(objetivo - reloj.t)
		_imprime(etq, reloj.t - t0, DESDE + Vector2i(3, 0))
		fotos.append(_foto(nombre + etq))
		rotulos.append(etq)
	var celda: Vector2i = Vector2i(700, 600)
	var lienzo: Image = Image.create(celda.x * fotos.size(), celda.y, false, Image.FORMAT_RGBA8)
	for i in fotos.size():
		var im: Image = fotos[i]
		im.convert(Image.FORMAT_RGBA8)
		lienzo.blit_rect(im, Rect2i(0, 0, celda.x, celda.y), Vector2i(i * celda.x, 0))
	lienzo.save_png(_dir.path_join("tira_" + nombre + ".png"))
	await avanzar_s(2.0)                     # (con +33 s el suelo ya está seco: la figura siguiente parte de suelo seco)
