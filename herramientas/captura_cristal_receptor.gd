extends "res://herramientas/escenario_base.gd"
## EL PUZLE 6 DE PtFUEGO (cristal dormido y receptor de fuego), COMO LO JUEGA PABLO (24/11/2026, vídeo del playtest: «mira 6»).
## Carga PtFuego, se pone delante del cristal (cat4), lanza una flecha de fuego DE VERDAD y mira: si el pulso activa el receptor, si aparece
## el cofre que lo premia (cofre_m3) y qué se ve con la cámara del juego. Necesita ventana para las fotos (sin ventana, solo comprueba):
##   godot --path . --script res://herramientas/captura_cristal_receptor.gd      → docs/capturas/cristal_receptor/

const RUTA: String = "res://escenas/PruebaPtFuego.tscn"
const DIR: String = "res://docs/capturas/cristal_receptor"
const T_TINTA_MAX_S: float = 6.0

var _pz: Puzle3D = null
var _fotos: bool = true


func _escenario() -> void:
	_fotos = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	root.get_window().size = Vector2i(1600, 900)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("hay Puzle3D", _pz != null)
	if _pz == null:
		return
	var rec = _pz.nodo("cat4_receptor")
	var cristal = _pz.nodo("cat4_cristal")
	var cofre = _pz.nodo("cofre_m3")
	_ok("están el cristal, el receptor y el cofre de la sala", rec != null and cristal != null and cofre != null)
	if rec == null or cristal == null or cofre == null:
		return
	var cc: Vector2i = _pz.pieza("cat4_cristal").celda
	print("cristal ", cc, " receptor ", _pz.pieza("cat4_receptor").celda, " cofre ", _pz.pieza("cofre_m3").celda)
	_ok("antes: el cofre está oculto", cofre.es_oculto)
	await _foto("1_antes.png")
	var esq0: int = Estado.i().cuenta("esquirla_cristal")
	_ok("flecha de fuego al cristal", await _lanzar("fuego", ["flecha"], cc, cc + Vector2i(0, 2)))
	await _foto("2_tras_flecha.png")
	_ok("el receptor se activa", await _esperar(func() -> bool: return rec.activo, 4.0))
	_ok("aparece el cofre", await _esperar(func() -> bool: return not cofre.es_oculto, 3.0))
	_ok("el cofre está DENTRO de la sala del puzle, junto al receptor (a la vista al resolverlo)",
		_pz.pieza("cofre_m3").celda.distance_to(_pz.pieza("cat4_receptor").celda) <= 2.5, str(_pz.pieza("cofre_m3").celda))
	print("esquirlas tras un flechazo: ", Estado.i().cuenta("esquirla_cristal") - esq0)
	await avanzar_s(1.0)
	await _foto("3_receptor_activo.png")
	_ok("flecha de fuego otra vez", await _lanzar("fuego", ["flecha"], cc, cc + Vector2i(0, 2)))
	await avanzar_s(1.5)
	print("esquirlas tras dos flechazos: ", Estado.i().cuenta("esquirla_cristal") - esq0, " · receptor activo ", rec.activo)
	await _foto("4_segunda_flecha.png")


func _esperar(cond: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return bool(cond.call())


func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	await avanzar_s(0.5)
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		jugador.tinta.actual = jugador.tinta.maxima
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, yo, hacia.normalized()):
			await avanzar_s(0.6)
			return true
		t += await avanzar_s(0.5)
	return false


## Foto de la sala desde arriba y algo al sur (la cámara del juego, con la jugadora detrás del muro del puzle, sale tapada).
func _foto(nombre: String) -> void:
	if not _fotos:
		return
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var centro: Vector3 = Terreno3D.centro_de(_pz.pieza("cat4_cristal").celda + Vector2i(2, 1), Terreno3D.alto_suelo)
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

