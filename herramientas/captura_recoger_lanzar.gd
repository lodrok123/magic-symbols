extends "res://herramientas/escenario_base.gd"
## COGER Y LANZAR: las fases con la CÁMARA DEL JUEGO (agachada, alzando, cargando, andando cargando, anticipación, remate, vuelo, impacto, soltar). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_recoger_lanzar.gd -- [carpeta]   (por defecto res://docs/capturas/recoger_lanzar)
## El tiempo va a cámara lenta (`Engine.time_scale`) para que cada foto caiga en su instante; los instantes se leen de `CargarObjeto3D` (estado y `_t`).

var _dir: String = "res://docs/capturas/recoger_lanzar"
var j: Jugador3D = null
var c: CargarObjeto3D = null
var claro: Vector2i = Vector2i.ZERO
var _ancho_recorte: int = 640
var _alto_recorte: int = 400
var _pendientes: Array = []
var _zoom: float = 0.0
var _g: Combate3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1:
		_zoom = float(a[1])               # tamaño de la cámara ortogonal (la del juego es ~10): más pequeño = más cerca
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	j = jugador as Jugador3D
	c = j.carga
	lanzador.tinta = null
	j.vida = 100000.0
	_ocultar_ui(root)
	if _zoom > 0.0:
		maqueta.set("_tam_camara", _zoom)
		(maqueta.get("_camara") as Camera3D).size = _zoom
	_buscar_claro()
	await avanzar_s(1.0)
	var g: Combate3D = _goblin(claro + Vector2i(2, 0))
	_g = g
	var jr := Rompible3D.new()
	jr.name = "jarron_foto"
	jr.preparar(claro + Vector2i(-1, 0), "jarron", "oro", 5, false, "", maqueta)
	maqueta.add_child(jr)
	colocar_jugador(claro)
	j.mirar_hacia(Vector3.RIGHT)
	(j.pj as Pj3D).mirar(Vector3.RIGHT, 1.0)
	await avanzar_s(1.0)
	_ocultar_ui(root)
	await _foto("0_antes")
	Engine.time_scale = 0.25
	_pulsar_e()
	await _cuando(func() -> bool: return c.estado == CargarObjeto3D.Estado.COGIENDO and c._t >= c._t_fondo * 0.95)
	await _foto("1_agachada_coge")
	await _cuando(func() -> bool: return c.estado == CargarObjeto3D.Estado.COGIENDO and c._t >= c._t_fondo + (c._t_total - c._t_fondo) * 0.6)
	await _foto("2_alzando")
	await _cuando(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO and c._t >= 0.4)
	await _foto("3_cargando_quieta")
	j.mirar_hacia(Vector3.RIGHT)
	(j.pj as Pj3D).mirar(Vector3.RIGHT, 1.0)
	# andar cargando: W un momento
	_tecla(KEY_W, true)
	await _cuando(func() -> bool: return c._t >= 1.4)
	await _foto("4_andando_cargando")
	_tecla(KEY_W, false)
	await _cuando(func() -> bool: return c._t >= 2.0)
	colocar_jugador(claro)
	j.mirar_hacia(Vector3.RIGHT)
	(j.pj as Pj3D).mirar(Vector3.RIGHT, 1.0)
	await _cuando(func() -> bool: return c._t >= 2.6)
	_pulsar_e()
	await _cuando(func() -> bool: return c.estado == CargarObjeto3D.Estado.ANTICIPANDO and c._t >= CargarObjeto3D.T_ANTICIPAR * 0.9)
	await _foto("5_anticipacion", 2.0)
	await _cuando(func() -> bool: return c.estado == CargarObjeto3D.Estado.LANZANDO and c._t >= 0.07)
	await _foto("6_remate_suelta", 2.5)
	await _cuando(func() -> bool: return not c._vuelos.is_empty() and float((c._vuelos[0] as Dictionary)["t"]) >= 0.3 * float((c._vuelos[0] as Dictionary)["T"]))
	await _foto("7_vuelo", 2.5, 800)
	await _cuando(func() -> bool: return c.ultimo.get("accion", "") == "impacto")
	await _foto_goblin("8_impacto")
	await _cuando(func() -> bool: return c.ultimo.get("accion", "") == "impacto" and jr.roto_ya and c.estado == CargarObjeto3D.Estado.LIBRE)
	await avanzar_s(0.3 / Engine.time_scale)
	await _foto_goblin("9_despues_restos")
	print("goblin: vida %.1f · ultimo: %s" % [g.health, c.ultimo])
	Engine.time_scale = 1.0
	await avanzar_s(0.5)
	_guardar()


func _pulsar_e() -> void:
	_tecla(KEY_E, true)
	await process_frame
	await process_frame
	_tecla(KEY_E, false)


## Espera (en fotogramas, con la cámara lenta) a que se cumpla `cond`; tope de seguridad.
func _cuando(cond: Callable) -> void:
	var n: int = 0
	while n < 3000 and not bool(cond.call()):
		await process_frame
		n += 1


func _buscar_claro() -> void:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var dmejor: float = INF
	claro = Vector2i(-1, -1)
	for y in range(4, alto - 4):
		for x in range(4, ancho - 8):
			var cc := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(cc)
			var bien: bool = true
			for dy in range(-3, 4):
				for dx in range(-3, 7):
					var v := cc + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(cc - desde).length() < dmejor:
				dmejor = Vector2(cc - desde).length()
				claro = cc
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)


func _goblin(cel: Vector2i) -> Combate3D:
	var p: Vector3 = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, j, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(-1, 0, 0)
	modelo.mirar(Vector3(-1, 0, 0), 1.0)
	return g


## Dos fotos por instante: la general (recorte ancho, para ver el vuelo y el entorno) y el primer plano de la jugadora (para leer la pose). `dx` desplaza el centro del recorte general hacia el este.
## Solo se COPIAN los recortes aquí: guardarlos (cambiar el tamaño y escribir el PNG) tarda más que varios fotogramas y, con la cámara lenta, esa pausa se contaría como tiempo de juego
## y saltaría de fase; se guardan todos al final (`_guardar`).
func _foto(nombre: String, dx: float = 1.2, ancho: int = 0) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if _zoom > 0.0:
		_recorte(img, nombre + "_zoom", j.position + Vector3(dx * 0.4, 0.9, 0.0), _ancho_recorte, _alto_recorte, 1)
	else:
		if ancho > 0:
			_recorte(img, nombre, j.position + Vector3(dx, 0.9, 0.0), ancho, ancho * 5 / 8, 1)
		else:
			_recorte(img, nombre, j.position + Vector3(dx, 0.9, 0.0), _ancho_recorte, _alto_recorte, 2)
	print("foto %s · estado %d t=%.2f" % [nombre, c.estado, c._t])


## Primer plano de donde está el goblin (el impacto y lo que deja): recorte pequeño ampliado a la cámara del juego, o ancho a la cámara cercana.
func _foto_goblin(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if _zoom > 0.0:
		_recorte(img, nombre + "_zoom", _g.global_position + Vector3(0, 0.5, 0), _ancho_recorte, _alto_recorte, 1)
	else:
		_recorte(img, nombre, _g.global_position + Vector3(0, 0.5, 0), 320, 200, 3)
	print("foto %s · goblin en %s vida %.1f" % [nombre, _g.global_position, _g.health])


func _recorte(img: Image, nombre: String, punto: Vector3, w: int, h: int, ampliar: int) -> void:
	var centro: Vector2 = lanzador.camara.unproject_position(punto)
	var vista: Vector2 = lanzador.camara.get_viewport().get_visible_rect().size
	centro = centro * Vector2(img.get_width(), img.get_height()) / vista
	var x0: int = clampi(int(centro.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(centro.y) - h / 2, 0, img.get_height() - h)
	_pendientes.append([nombre, img.get_region(Rect2i(x0, y0, w, h)), ampliar])


func _guardar() -> void:
	for p in _pendientes:
		var rec: Image = p[1]
		rec.resize(rec.get_width() * int(p[2]), rec.get_height() * int(p[2]), Image.INTERPOLATE_LANCZOS)
		rec.save_png(ProjectSettings.globalize_path(_dir).path_join(String(p[0]) + ".png"))
	_pendientes.clear()

func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
