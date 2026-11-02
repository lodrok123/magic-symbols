extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL FUEGO Y EL AGUA EN EL JUEGO (A1, 2/11/2026). NECESITA VENTANA. Carga el Bosque 01 v01 con la cámara DEL JUEGO (la de la maqueta, ortogonal a 60°, sin tocar su zoom) y lanza los mismos
## hechizos (bola quieta, proyectil, muro, pilar, barrera, haz, y la carga en la mano) de fuego y de agua dos veces desde el mismo sitio y la misma luz: con `magic_symbols/vfx_procedural` = false
## («actual»: VfxElemento3D y el kit) y = true («procedural»: FuegoToy / AguaToy). Se cambia el ajuste en marcha (VfxToyJuego lo lee en cada evento).
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_vfx_en_juego.gd -- [carpeta] [solo_elemento] [solo_hechizo]
## Por defecto escribe en res://docs/capturas/vfx_en_juego/: <elemento>_<hechizo>_<actual|procedural>_<t>.png (fotograma completo del juego) y celdas.json, que monta
##   python herramientas/lamina_vfx.py --en-juego docs/capturas/vfx_en_juego docs/capturas/vfx_en_juego/lamina_vfx_en_juego.png
## Se miran a ojo (no hay `_ok`).

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const HECHIZOS: Array = [
	["bola_quieta", "bola quieta", ["pulso"]],      # sin glifos la página no se lanza; ᛟ `pulso` da una bola quieta que crece (radio 0,3)
	["proyectil", "proyectil", ["flecha"]],
	["muro", "muro", ["barrera", "linea_x", "linea_x"]],
	["pilar", "pilar", ["altura", "altura", "altura"]],
	["barrera", "barrera", ["barrera", "linea_x", "linea_x", "linea_z", "linea_z"]],
	["haz", "haz", ["linea_x", "linea_x"]],
	["carga", "carga en la mano", ["flecha"]],
]
const TIEMPOS: Array = [0.45, 1.1]            ## s tras lanzar de cada fotograma (el segundo, ya asentado o en pleno vuelo)
const DIR: Vector3 = Vector3(1.0, 0.0, 0.0)

var _dir: String = "res://docs/capturas/vfx_en_juego"
var _solo: String = ""
var _solo_h: String = ""
var _json: Array = []


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1:
		_solo = a[1]
	if a.size() > 2:
		_solo_h = a[2]
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
	_ok("0 hay un claro de 9 × 5 casillas llano para las capturas (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	await avanzar_s(2.0)
	for el in ["fuego", "agua"]:
		if _solo != "" and _solo != el:
			continue
		for hz in HECHIZOS:
			if _solo_h != "" and _solo_h != String(hz[0]):
				continue
			for modo in ["actual", "procedural"]:
				ProjectSettings.set_setting(VfxToyJuego.AJUSTE, modo == "procedural")
				colocar_jugador(c)
				await avanzar_s(0.3)
				await _una(el, hz, modo)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	var f: FileAccess = FileAccess.open(_dir.path_join("celdas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_json, "  "))
	f.close()
	print("escrito ", _dir)


func _una(el: String, hz: Array, modo: String) -> void:
	var id: String = String(hz[0])
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(el)
	for g in (hz[2] as Array):
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	var con_conjuro: bool = id == "carga"
	var origen: Vector3 = jugador.position
	if (hz[2] as Array).has("barrera"):
		origen += DIR * Terreno3D.casilla * 2.0      # ᚦ nace donde se apunta (`en_punto`, hasta ALCANCE_ORIGEN casillas): dos casillas por delante; lo demás nace en la jugadora
	var salio: bool = lanzador.lanzar_pagina_ya(0, origen, DIR, con_conjuro)
	_ok("1 %s · %s · %s: sale el hechizo" % [el, id, modo], salio)
	var t_ant: float = 0.0
	var tiempos: Array = TIEMPOS
	for t in tiempos:
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		var nombre: String = "%s_%s_%s_%03d" % [el, id, modo, int(round(float(t) * 100.0))]
		root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
		_json.append({"id": nombre, "elemento": el, "hechizo": id, "titulo": String(hz[1]), "modo": modo, "t": float(t)})
	# esperar a que se apague todo (el haz dura 2,6 s, la bola quieta 3 s)
	await avanzar_s(4.5)
	if id == "carga":
		await avanzar_s(1.0)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


## Una casilla desde la que haya 9 casillas libres y llanas hacia +X y 2 a cada lado (la bola, el muro, el pilar y el haz caben a la vista y no chocan).
func _buscar_claro() -> Vector2i:
	for y in range(4, 38):
		for x in range(2, 40):
			var ok: bool = true
			var base: float = Terreno3D.y_pies(Vector2i(x, y))
			for dx in range(-1, 10):
				for dz in range(-2, 3):
					var q := Vector2i(x + dx, y + dz)
					if not Terreno3D.en_mapa(q) or Terreno3D.celda_solida(q, 0) or Terreno3D.bloqueada(q) or Lanzador3D.es_agua(q) or absf(Terreno3D.y_pies(q) - base) > 0.01:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
