extends "res://herramientas/escenario_base.gd"
## LA BALANZA DE PtAGUATIERRA (sala 6, `balanza_rocas`), COMO LA JUEGA PABLO (26/11/2026, vídeo del playtest: «revisa este puzzle»).
## Carga PtAguaTierra y la resuelve ANDANDO (teclas de verdad, `mover_hacia` + W mantenida contra la roca) y lanzando tierra + barrera a la
## tercera placa. Dice en qué casilla queda cada roca tras cada empujón y si cada placa se activa. Con ventana saca fotos:
##   godot --path . --script res://herramientas/captura_balanza.gd          → docs/capturas/balanza/
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/captura_balanza.gd   (solo comprueba)

const RUTA: String = "res://escenas/PruebaPtAguaTierra.tscn"
const DIR: String = "res://docs/capturas/balanza"
const T_TINTA_MAX_S: float = 6.0

var _pz: Puzle3D = null
var _pre: String = ""
var _fotos: bool = true


func _escenario() -> void:
	_fotos = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	root.get_window().size = Vector2i(1600, 900)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	for i in range(1, 20):
		if _pz != null and _pz.pieza("cat%d_rm" % i) != null:
			_pre = "cat%d_" % i
	_ok("hay Puzle3D y sin avisos", _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "")
	if _pz == null:
		return
	var pa = _pz.nodo(_pre + "pa")
	var pb = _pz.nodo(_pre + "pb")
	var pc = _pz.nodo(_pre + "pc")
	var rm = _pz.nodo(_pre + "rm")
	var rp = _pz.nodo(_pre + "rp")
	var cofre = _pz.nodo(_pre + "cofre")
	_ok("están las tres placas, las dos rocas y el cofre", pa != null and pb != null and pc != null and rm != null and rp != null and cofre != null)
	if rm == null or rp == null or pc == null:
		return
	print("rocas al empezar: mediana ", rm.celda, " pequeña ", rp.celda, " · placas ", _pz.pieza(_pre + "pa").celda, _pz.pieza(_pre + "pb").celda, _pz.pieza(_pre + "pc").celda)
	await _foto("1_inicio.png")
	# Lo que ve la jugadora al entrar (cámara del juego, con su luz): ¿se ven las rocas?
	colocar_jugador(rp.celda + Vector2i(0, 2))
	await avanzar_s(1.5)
	await _foto_juego("0_al_entrar_camara_juego.png")
	# La pequeña (peso 1) a su placa: dos empujones hacia el norte, andando.
	for i in 2:
		await _empujar_andando(rp, Vector2i(0, -1))
		print("pequeña tras el empujón %d: %s" % [i + 1, rp.celda])
	_ok("la roca pequeña llega a su placa (peso 1)", rp.celda == _pz.pieza(_pre + "pb").celda and pb.activo, "roca %s placa activa %s" % [rp.celda, pb.activo])
	for i in 2:
		await _empujar_andando(rm, Vector2i(0, -1))
		print("mediana tras el empujón %d: %s" % [i + 1, rm.celda])
	_ok("la roca mediana llega a su placa (peso 2)", rm.celda == _pz.pieza(_pre + "pa").celda and pa.activo, "roca %s placa activa %s" % [rm.celda, pa.activo])
	await _foto("2_rocas_en_placas.png")
	var cc: Vector2i = _pz.pieza(_pre + "pc").celda
	_ok("tierra + barrera a la tercera placa", await _lanzar("tierra", ["barrera"], cc, cc + Vector2i(0, 2), true))
	_ok("el bloque de tierra pisa la tercera placa", await _esperar(func() -> bool: return pc.activo, 3.0))
	_ok("con las tres, aparece el cofre", await _esperar(func() -> bool: return not cofre.es_oculto, 3.0))
	await _foto("3_resuelto.png")


## Se pone detrás de la roca y mantiene la tecla hacia ella, como la jugadora.
func _empujar_andando(r, dir: Vector2i) -> void:
	var detras: Vector2i = r.celda - dir
	colocar_jugador(detras)
	await avanzar_s(0.4)
	var antes: Vector2i = r.celda
	await mover_hacia(r.celda, 4.0, 0.2)
	await _esperar(func() -> bool: return not r.moviendo, 6.0)
	await avanzar_s(0.5)
	if r.celda == antes:
		print("  la roca de %s no se ha movido; jugadora en %s" % [antes, celda_jugador()])


func _esperar(cond: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return bool(cond.call())


func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i, en_punto: bool = false) -> bool:
	colocar_jugador(desde)
	await avanzar_s(0.5)
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		jugador.tinta.actual = jugador.tinta.maxima
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		var origen: Vector3 = yo
		if en_punto:
			var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
			origen = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, origen, hacia.normalized()):
			await avanzar_s(1.2)
			return true
		t += await avanzar_s(0.5)
	return false


func _foto_juego(nombre: String) -> void:
	if not _fotos:
		return
	await avanzar(4)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	print("captura: ", nombre)


func _foto(nombre: String) -> void:
	if not _fotos:
		return
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var centro: Vector3 = Terreno3D.centro_de(_pz.pieza(_pre + "pb").celda + Vector2i(0, 1), Terreno3D.alto_suelo)
	var cam := Camera3D.new()
	cam.fov = 55.0
	maqueta.add_child(cam)
	cam.global_position = centro + Vector3(0.0, 6.5, 6.5)
	cam.look_at(centro + Vector3(0.0, 0.3, 0.0))
	cam.current = true
	await avanzar(6)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	print("captura: ", nombre)
	cam.current = false
	if cam_juego != null and is_instance_valid(cam_juego):
		cam_juego.current = true
	cam.queue_free()
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = true
