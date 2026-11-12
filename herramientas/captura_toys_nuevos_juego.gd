extends "res://herramientas/captura_vfx_en_juego.gd"
## CAPTURAS DE MAGMA, VIENTO Y TIERRA EN EL JUEGO (6/11/2026). NECESITA VENTANA. Igual que captura_vfx_en_juego.gd (Bosque 01 v01, cámara del juego) pero lanza hechizos de magma, viento y tierra
## directamente con `HechizoVivo.crear` (el magma es un derivado de ᚠ + ᛏ del libro avanzado: no hay forma de ponerlo con la paleta de una sola página) y los saca con el toy (ajuste = true, lista de serie)
## y, para comparar, con lo de antes (ajuste = false).
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_toys_nuevos_juego.gd -- [carpeta] [solo_caso|*] [modos: actual,procedural | procedural]
## Escribe docs/capturas/vfx_en_juego/toys_nuevos/<caso>_<actual|procedural>_<t>.png. Se miran a ojo (no hay `_ok` que valga).

const CASOS: Array = [
	# id, elemento, glifos, dirección (con y < 0 el proyectil baja y revienta contra el suelo), desplazamiento en casillas hacia +X, tiempos de foto
	["magma_vuelo", "magma", {"flecha": 1}, Vector3(1.0, 0.0, 0.0), 0.0, [0.25, 0.5]],
	["magma_crater", "magma", {"flecha": 1}, Vector3(1.0, -0.55, 0.0), 0.0, [0.5, 0.9, 1.8, 3.2]],
	["tierra_muro", "tierra", {"barrera": 1, "linea_x": 2, "altura": 1}, Vector3(1.0, 0.0, 0.0), 1.0, [0.15, 0.4, 1.2]],      # 6/11 tarde: a 1 casilla (a 2 el muro del toy caía fuera del encuadre, tapado por el bloque sólido del Lanzador)
	["viento_rafaga", "viento", {"flecha": 1}, Vector3(1.0, 0.0, 0.0), 0.0, [0.2, 0.45]],
	["viento_haz", "viento", {"linea_x": 2}, Vector3(1.0, 0.0, 0.0), 0.0, [0.3, 1.0]],
	["magma_haz", "magma", {"linea_x": 2}, Vector3(1.0, 0.0, 0.0), 0.0, [0.3, 0.6, 1.2]],                                         # 7/11 (Pablo): las mismas púas que tierra pero de roca de magma, con el fuego rojo encima

	["tierra_linea", "tierra", {"linea_x": 2}, Vector3(1.0, 0.0, 0.0), 0.0, [0.3, 0.6, 1.2]],                                      # 7/11 (Pablo, «sí, haz de púas»): la tierra con ᛁ YA es un haz en el juego (`Hechizo.SOLIDOS_CON_HAZ`): salen las púas en secuencia que golpean y empujan, no el muro sobre casillas
	["tierra_golpe", "tierra", {"flecha": 1}, Vector3(1.0, -0.9, 0.0), 0.0, [0.5, 0.7, 0.9, 1.3]],                                # la bola (lenta: tierra ×0,8) revienta contra el suelo: anillo + púas que asoman
]


func _escenario() -> void:
	_dir = "res://docs/capturas/vfx_en_juego/toys_nuevos"
	_modos = ["actual", "procedural"]
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "*":
		_solo = a[1]
	if a.size() > 2 and a[2] != "":
		_modos = Array(a[2].split(","))
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro llano para las capturas (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	await avanzar_s(2.0)
	var runas: Dictionary = {"magma": "magma", "viento": "wind", "tierra": "earth"}
	for caso in CASOS:
		if _solo != "" and _solo != String(caso[0]):
			continue
		for modo in _modos:
			ProjectSettings.set_setting(VfxToyJuego.AJUSTE, modo == "procedural")
			ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
			colocar_jugador(c)
			await avanzar_s(0.3)
			var rd: RuneData = load("res://nucleo/%s_rune.tres" % runas[String(caso[1])]) as RuneData
			var h: Hechizo = Hechizo.construir(rd, caso[2] as Dictionary)
			# 12/11: solo a la BOLA de magma (con flecha). Antes se hacía con todos los casos de magma, y al haz (ᛁ ᛁ) le ponía `distancia_max` > 0: dejaba de ser un
			# haz (`Hechizo.haz` pide distancia_max 0) y salía un volumen que viaja fuera del encuadre. De ahí el «el haz de magma no se ve en el juego» (DIARIO 442).
			if String(caso[1]) == "magma" and (caso[2] as Dictionary).has("flecha"):
				h = h.con({"gravedad": 1.0 if (caso[3] as Vector3).y < 0.0 else 0.0, "distancia_max": 9.0})
			var origen: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0) + Vector3.RIGHT * Terreno3D.casilla * float(caso[4])
			HechizoVivo.crear(h, origen, (caso[3] as Vector3).normalized(), lanzador)
			var t_ant: float = 0.0
			for t in (caso[5] as Array):
				await avanzar_s(float(t) - t_ant)
				t_ant = float(t)
				_ocultar_ui(root)
				var nombre: String = "%s_%s_%03d" % [caso[0], modo, int(round(float(t) * 100.0))]
				root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
				print("FOTO ", nombre, " toys: ", _contar_toys())
			await avanzar_s(4.0)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	print("escrito ", _dir)


func _contar_toys() -> String:
	var r: Dictionary = {}
	for n in maqueta.get_children():
		var nom: String = String(n.get_script().get_global_name()) if n.get_script() != null else ""
		if nom.ends_with("Toy"):
			r[nom] = int(r.get(nom, 0)) + 1
	return str(r)
