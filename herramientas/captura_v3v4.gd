extends SceneTree
## CAPTURAS ANTES / DESPUÉS de V3 (bisel del labio) y V4 (estado del suelo) de docs/PLAN_EOW_VISUAL.md (Pipeline, 21/10). NECESITA VENTANA
## (sin GPU no hay imagen). Mismo patrón que `captura_look_v1v2.gd`.
##   godot --path . --script res://herramientas/captura_v3v4.gd -- <lab|bosque> <antes|despues> <carpeta>
## «antes»   = `bisel_suelo = false` y `estado_suelo_eow = false` en la maqueta: el suelo y los bordes de antes de V3/V4.
## «despues» = los valores de serie de ahora.
## B2 (21/10): la maqueta ya NO tiene imagen de estado propia; el suelo, la hierba y el agua leen `Terreno3D.estados`. Los estados se ponen ahí
## (como antes de B2 se escribían las dos fuentes con el mismo resultado, las capturas V4 «despues» de `docs/capturas/v3_v4/` valen de «antes de B2»).
## Las vistas «*_pisado» marcan la hierba PISADA (textura propia de la maqueta, `marcar_pisado`) y se capturan al instante, antes de que se levante sola.
## Imprime también: triángulos y llamadas de dibujado del fotograma, y el tiempo de fotograma sin vsync.
const S: float = 2.3
const VISTAS: Dictionary = {
	"lab": {
		"escena": "res://laboratorios/LabPlaytestEoW.tscn",
		# nombre: [casilla x, casilla y, tamaño de cámara, estados?, ocultar la hierba 3D?]. Sala 4 (terrazas) en el centro (28,4); sala 5 (estados) en (4,12).
		"vistas": {"sala4_terrazas": [28.0, 4.0, 9.0, false, false], "sala5_estados": [4.0, 10.0, 8.5, true, true], "sala5_hierba": [4.0, 10.0, 8.5, true, false], "terraza_cerca": [0.0, 0.0, 4.5, false, false], "sala5_pisado": [4.0, 12.0, 6.0, false, false]},
	},
	"bosque": {
		"escena": "res://escenas/PruebaBosque01.tscn",
		"vistas": {"jugador": [-1.0, -1.0, 14.0, false, false], "estados": [-2.0, -2.0, 7.0, true, true], "estados_hierba": [-2.0, -2.0, 7.0, true, false], "borde_cerca": [-2.0, -2.0, 4.5, false, false], "estados_pisado": [-2.0, -2.0, 6.0, false, false]},   # x = -1: cámara del jugador · x = -2: junto al jugador, con estados
	},
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <lab|bosque> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var esc: PackedScene = load(VISTAS[cual]["escena"])
	var m: Node3D = esc.instantiate()
	if antes:
		m.set("bisel_suelo", false)
		m.set("estado_suelo_eow", false)
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	print("alturas: %d casillas · lado %d" % [Terreno3D.alturas.size(), Terreno3D.lado_del_mapa()])
	var jc: Vector2i = Vector2i(-1, -1)
	var j: Variant = m.get("_jugador")
	if j != null:
		jc = Vector2i(int(floorf((j as Node3D).position.x / S)), int(floorf((j as Node3D).position.z / S)))
		print("jugador en casilla ", jc)
	var vistas: Dictionary = VISTAS[cual]["vistas"]
	var puestos: bool = false
	for k in vistas.keys():
		var v: Array = vistas[k]
		var centro: Vector2i = Vector2i(int(v[0]), int(v[1]))
		if float(v[0]) <= -2.0:
			centro = jc
		if k.begins_with("estados"):
			centro = jc + Vector2i(0, -1)
		if k == "borde_cerca":
			centro = jc + Vector2i(1, 2)       # el borde sur del Bosque 01, junto a donde empieza el jugador
		if k == "terraza_cerca" and not Terreno3D.alturas.is_empty():
			centro = Terreno3D.alturas.keys()[0]
		var pisado: bool = k.ends_with("_pisado")
		if float(v[0]) != -1.0:
			m.set("_jugador", null)
			m.set("_foco", Vector3((float(centro.x) + 0.5) * S, 0.5, (float(centro.y) + 0.5) * S))
		m.set("_tam_camara", float(v[2]))
		m.get("_camara").size = float(v[2])
		m.call("_colocar_camara")
		if bool(v[3]) and not puestos:
			_poner_estados(m, jc if cual == "bosque" else centro, cual)
			puestos = true
		if m.get("_hierba") != null:
			(m.get("_hierba") as Node3D).visible = not bool(v[4])
		var t0: int = Time.get_ticks_usec()
		var ms: float = 0.0
		if pisado:
			# La hierba pisada se levanta sola en 2 s: se marca (radio 2 alrededor del centro) y se captura enseguida.
			for _i in 20:
				await process_frame
			m.call("marcar_pisado", centro, 1.0, 2)
			for _i in 6:
				await process_frame
		else:
			for _i in 40:
				await process_frame
			t0 = Time.get_ticks_usec()
			for _i in 120:
				await process_frame
			ms = float(Time.get_ticks_usec() - t0) / 120000.0
		var tri: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/%s_%s_%s.png" % [carpeta, cual, k, "antes" if antes else "despues"]
		img.save_png(ruta)
		print("MEDIDA %s | %s | %s | fotograma %.2f ms (%.0f fps) | triangulos %d | llamadas %d" % [cual, k, "antes" if antes else "despues", ms, 1000.0 / maxf(ms, 0.001), tri, dc])
	quit()


## Tres manchas irregulares (mojada, helada, quemada) alrededor de `c`, en el estado del juego (`Terreno3D.estados`).
func _poner_estados(m: Node, c: Vector2i, cual: String) -> void:
	var manchas: Array = []
	if cual == "lab":
		# Sala 5 (rect 1..7 × 9..15): una mancha en cada tercio.
		manchas = [[0, Vector2i(1, 10), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]],
			[1, Vector2i(3, 11), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 1)]],
			[2, Vector2i(5, 10), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 1)]]]
	else:
		manchas = [[1, c + Vector2i(1, 0), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]],
			[2, c + Vector2i(1, -2), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2)]],
			[0, c + Vector2i(-2, 0), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]]]
	var nombres: Array = ["quemada", "mojada", "helada"]
	for mancha in manchas:
		var canal: int = int(mancha[0])
		for o in mancha[2]:
			var q: Vector2i = (mancha[1] as Vector2i) + (o as Vector2i)
			if o == Vector2i.ZERO:
				print("mancha %s en %s -> pantalla %s" % [nombres[canal], q, (m.get("_camara") as Camera3D).unproject_position(Vector3((q.x + 0.5) * S, 0.5, (q.y + 0.5) * S))])
			Terreno3D.estados.poner(q, String(nombres[canal]), true)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
