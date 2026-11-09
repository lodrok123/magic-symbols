extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL HAZ DE FUEGO CON LAS TRES IDEAS (9/11/2026). NECESITA VENTANA. Antes / después con la cámara DEL JUEGO:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_haz_fuego_ideas.gd -- [carpeta] [casos: aire,muro,goblin,dragon] [elementos: fuego,agua,rayo]
## «antes» = FuegoToy.haz_ideas = false (el haz de antes); «después» = true. Escribe <carpeta>/<elemento>_<caso>_<antes|despues>_<t>.jpg (recorte del juego, 960 × 540).
## Casos: aire (sin obstáculo: la punta acaba en humo), muro (un bloque de tierra a 3 casillas), goblin (un goblin a 3 casillas), dragon (la trampa de la sala F7 del lab de puzles de fuego).

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const LAB: String = "res://laboratorios/LabPuzlesFuego3D.tscn"
const DIR: Vector3 = Vector3(1.0, 0.0, 0.0)
const TIEMPOS: Array = [0.5, 0.85]

var _dir: String = "res://docs/capturas/vfx_en_juego/haz_fuego_ideas"
var _casos: PackedStringArray = ["aire", "muro", "goblin", "dragon"]
var _elementos: PackedStringArray = ["fuego"]


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_casos = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_elementos = a[2].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	if _casos.has("aire") or _casos.has("muro") or _casos.has("goblin"):
		await cargar(RUTA, true)
		if maqueta == null or jugador == null:
			return
		lanzador.tinta = null
		_ocultar_ui(root)
		_cam(1.9)
		for n in get_nodes_in_group("combate3d"):
			(n as Combate3D).quieto = true
		var c: Vector2i = _buscar_claro()
		_ok("0 hay un claro llano", c != Vector2i(-1, -1))
		if c == Vector2i(-1, -1):
			return
		for el in _elementos:
			for caso in ["aire", "goblin", "muro"]:
				if not _casos.has(caso):
					continue
				colocar_jugador(c)
				var gob: Node3D = _un_goblin()
				_limpiar_extras(c, gob)
				if caso == "muro":
					_muro(Vector2i(c.x + 2, c.y))
				elif caso == "goblin" and gob != null:
					var q := Vector2i(c.x + 2, c.y)
					gob.position = Terreno3D.centro_de(q, Terreno3D.y_pies(q))
				await avanzar_s(0.5)
				if caso == "aire":
					_cam(1.45)
				for modo in ["antes", "despues"]:
					FuegoToy.haz_ideas = modo == "despues"
					await _una(el, "%s_%s_%s" % [el, caso, modo], c)
				if caso == "aire":
					_cam(1.0 / 1.45)
	FuegoToy.haz_ideas = true
	if _casos.has("dragon"):
		await _dragon()
	if _casos.has("formas"):
		await _formas()
	print("escrito ", _dir)


## Antes / después de las capas añadidas a MURO, PILAR, BARRERA y al impacto de la BOLA (FuegoToy.formas_extra: todas apagadas = antes, todas encendidas = después).
func _formas() -> void:
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	_cam(1.2)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	var figs: Array = [["muro", ["barrera", "linea_x", "linea_x", "altura"], 2.0, [0.6, 1.2]], ["pilar", ["altura", "altura", "altura"], 1.0, [0.6, 1.2]],
			["barrera", ["barrera", "linea_x", "linea_z", "altura"], 2.0, [0.6, 1.2]], ["bola_impacto", ["flecha"], 2.7, [0.12, 0.35]]]
	for f in figs:
		for modo in ["antes", "despues"]:
			for k in FuegoToy.formas_extra:
				FuegoToy.formas_extra[k] = modo == "despues"
			colocar_jugador(c)
			await avanzar_s(0.5)
			if f[0] == "bola_impacto":
				# la bola de FuegoToy contra el suelo (el impacto lo decide HechizoVivo en el juego; aquí se llama directamente a `impactar_en`, que es lo que añade las capas)
				var bola: FuegoToy = FuegoToy.new()
				bola.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
				maqueta.add_child(bola)
				var q: Vector3 = jugador.position + DIR * Terreno3D.casilla * 2.7
				bola.global_position = q + Vector3(0, 0.4, 0)
				await avanzar(3)
				bola.impactar_en(q, Vector3.UP, 0.5)
			else:
				lanzador.select_page(0)
				lanzador.clear_sequence()
				lanzador.place_element("fuego")
				for g in (f[1] as Array):
					lanzador.place_sigil(String(g))
				lanzador.cooldown_left[0] = 0.0
				var origen: Vector3 = jugador.position
				if (f[1] as Array).has("barrera"):
					origen += DIR * Terreno3D.casilla * 2.0
				lanzador.lanzar_pagina_ya(0, origen, DIR, false)
			await avanzar(2)
			var t_ant: float = 0.0
			for t in (f[3] as Array):
				await avanzar_s(float(t) - t_ant)
				t_ant = float(t)
				_ocultar_ui(root)
				var cz: Vector3 = jugador.position + DIR * Terreno3D.casilla * float(f[2]) + Vector3(0, 0.6, 0)
				var z: Image = _recorte(cz, 520, 292)
				z.resize(960, 540, Image.INTERPOLATE_LANCZOS)
				z.save_jpg(ProjectSettings.globalize_path(_dir.path_join("fuego_%s_%s_%03d.jpg" % [f[0], modo, int(round(float(t) * 100.0))])))
			await avanzar_s(4.0)
	for k in FuegoToy.formas_extra:
		FuegoToy.formas_extra[k] = false


## Aleja la cámara del juego (× k) para ver el haz entero.
func _cam(k: float) -> void:
	var tam: float = float(maqueta.get("_tam_camara")) * k
	maqueta.set("_tam_camara", tam)
	(maqueta.get("_camara") as Camera3D).size = tam


func _un_goblin() -> Node3D:
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n):
			(n as Combate3D).quieto = true
			if "vida" in n:
				n.set("vida", 100000.0)
			return n as Node3D
	return null


func _limpiar_extras(c: Vector2i, gob: Node3D) -> void:
	if gob != null:
		gob.position = Terreno3D.centro_de(Vector2i(c.x + 8, c.y + 8), 0.0)
	for k in [Vector2i(c.x + 2, c.y)]:
		pass


func _muro(q: Vector2i) -> void:
	var opc: Dictionary = {"resta": 60.0, "color": Color(0.5, 0.4, 0.3), "v2": true, "apilar": 2, "elemento": "tierra"}
	lanzador.construir_tierra(q, true, opc)
	print("muro en ", q, " sólida: ", Lanzador3D.celda_solida(q, 0))


func _una(el: String, nombre: String, c: Vector2i) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(el)
	for g in ["linea_x", "linea_x"]:
		lanzador.place_sigil(g)
	lanzador.cooldown_left[0] = 0.0
	colocar_jugador(c)
	var salio: bool = lanzador.lanzar_pagina_ya(0, jugador.position, DIR, false)
	_ok("1 %s: sale el haz" % nombre, salio)
	await avanzar(2)
	var t_ant: float = 0.0
	for t in TIEMPOS:
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		_ocultar_ui(root)
		var centro: Vector3 = jugador.position + DIR * Terreno3D.casilla * 2.6 + Vector3(0, 0.6, 0)
		var img: Image = _recorte(centro)
		img.save_jpg(ProjectSettings.globalize_path(_dir.path_join("%s_%03d.jpg" % [nombre, int(round(float(t) * 100.0))])))
		var cz: Vector3 = jugador.position + DIR * Terreno3D.casilla * (3.3 if nombre.contains("_aire_") else 1.9) + Vector3(0, 0.6, 0)
		var z: Image = _recorte(cz, 400, 225)
		z.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		z.save_jpg(ProjectSettings.globalize_path(_dir.path_join("%s_%03d_zoom.jpg" % [nombre, int(round(float(t) * 100.0))])))
	await avanzar_s(3.5)


func _recorte(centro: Vector3, ancho: int = 1280, alto: int = 720) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var vis: Vector2 = root.get_viewport().get_visible_rect().size
	var k: float = float(img.get_width()) / maxf(vis.x, 1.0)
	var p: Vector2 = lanzador.camara.unproject_position(centro) * k
	var w: int = mini(ancho, img.get_width())
	var h: int = mini(alto, img.get_height())
	var x0: int = clampi(int(p.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(p.y) - h / 2, 0, img.get_height() - h)
	return img.get_region(Rect2i(x0, y0, w, h))


func _dragon() -> void:
	await cargar(LAB)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	var pz: Puzle3D = (maqueta.get_node("Reglas").get("_puzle_nodo")) as Puzle3D
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	(jugador as Jugador3D).vida = 100000.0
	var a: TrampaDragon3D = pz.nodo("t_drg_a") as TrampaDragon3D
	var b: TrampaDragon3D = pz.nodo("t_drg_b") as TrampaDragon3D
	var tam_juego: float = float(maqueta.get("_tam_camara"))
	_despejar(maqueta)
	b.apagar(0.0)
	var cel := Vector2i(27, 10)
	var p: Vector3 = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p
	jugador.position = p
	for modo in ["antes", "despues"]:
		FuegoToy.haz_ideas = modo == "despues"
		a.encender()
		await avanzar_s(3.0)
		_ocultar_ui(root)
		var fotos: int = 0
		var seguro: int = 0
		while fotos < 3 and seguro < 9000:
			seguro += 1
			await process_frame
			if a.fase == TrampaDragon3D.Fase.FUEGO:
				var t_f: float = a._t_ciclo - a.apagada_s
				if t_f >= 0.35 + 0.3 * fotos:
					await RenderingServer.frame_post_draw
					_ocultar_ui(root)
					var img: Image = _recorte(a.global_position + Vector3(0.0, 0.6, 2.2), 900, 506)
					img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
					img.save_jpg(ProjectSettings.globalize_path(_dir.path_join("fuego_dragon_%s_%d.jpg" % [modo, fotos])))
					fotos += 1
		a.apagar(0.0)
		await avanzar_s(2.0)
	FuegoToy.haz_ideas = true


## Esconde los árboles y las piezas altas del decorado (como captura_trampas_pared.gd) para ver las trampas limpias.
func _despejar(n: Node) -> void:
	for h in n.get_children():
		if h is TrampaPared3D or h is FlechaTrampa3D or h is Pj3D or h is Jugador3D or h is Lanzador3D or h is Combate3D or h is Camera3D or h is Light3D:
			continue
		if h is MeshInstance3D and (h as MeshInstance3D).get_aabb().size.y * (h as Node3D).global_transform.basis.get_scale().y > 1.8:
			(h as Node3D).visible = false
		if h is MultiMeshInstance3D and String(h.name).begins_with("lote_pino"):
			(h as Node3D).visible = false
		_despejar(h)

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


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
