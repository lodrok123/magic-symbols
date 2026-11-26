extends "res://herramientas/escenario_base.gd"
## LA PRESA EN PtAGUATIERRA (sala 7, `presa_barril`, 26/11/2026, Pablo: «una pared que bloquea una masa de agua; al destruir un barril
## explosivo la pared se destruye dejando pasar el agua»). Carga el nivel, lanza una flecha de fuego DE VERDAD al barril y fotografía la sala
## antes, en la explosión y con el agua ya en el vaso. Comprueba el muro, el nivel y el cofre. Con ventana:
##   godot --path . --script res://herramientas/captura_presa.gd          → docs/capturas/presa/

const RUTA: String = "res://escenas/PruebaPtAguaTierra.tscn"
const DIR: String = "res://docs/capturas/presa"
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
		if _pz != null and _pz.pieza("cat%d_dique" % i) != null:
			_pre = "cat%d_" % i
	_ok("la presa está en el nivel", _pre != "")
	if _pre == "":
		return
	var dique = _pz.nodo(_pre + "dique")
	var alto = _pz.nodo(_pre + "dique_alto")
	var nivel = _pz.nodo(_pre + "nivel")
	var cofre = _pz.nodo(_pre + "cofre")
	var sim: AguaSim3D = Terreno3D.agua_sim
	var ce: Vector2i = _pz.pieza(_pre + "embalse").celda
	var cv: Vector2i = _pz.pieza(_pre + "vaso").celda
	var bc: Vector2i = _pz.pieza(_pre + "barril").celda
	colocar_jugador(bc + Vector2i(0, 2))
	await avanzar_s(2.0)
	_ok("antes: embalse lleno, vaso seco, muro en pie", sim.profundidad_casilla(ce) > 0.6 and sim.profundidad_casilla(cv) < 0.05 and not dique.abierta,
		"embalse %.2f vaso %.2f" % [sim.profundidad_casilla(ce), sim.profundidad_casilla(cv)])
	await _foto("1_antes.png", bc)
	_ok("flecha de fuego al barril", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(0, 2)))
	await _esperar(func() -> bool: return dique.abierta, 5.0)
	await avanzar_s(0.3)
	await _foto("2_explota.png", bc)
	_ok("el muro cae entero", dique.abierta and alto.abierta)
	_ok("el agua pasa, sube el nivel y aparece el cofre", await _esperar(func() -> bool: return nivel.alcanzado and not cofre.es_oculto, 20.0),
		"embalse %.2f vaso %.2f" % [sim.profundidad_casilla(ce), sim.profundidad_casilla(cv)])
	await avanzar_s(2.0)
	await _foto("3_agua_pasada.png", bc)


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
			await avanzar_s(0.4)
			return true
		t += await avanzar_s(0.5)
	return false


## Desde arriba y al sur de la sala, mirando al muro.
func _foto(nombre: String, bc: Vector2i) -> void:
	if not _fotos:
		return
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var cam_juego: Camera3D = root.get_viewport().get_camera_3d()
	var centro: Vector3 = Terreno3D.centro_de(bc + Vector2i(0, -1), Terreno3D.alto_suelo)
	var cam := Camera3D.new()
	cam.fov = 55.0
	maqueta.add_child(cam)
	cam.global_position = centro + Vector3(0.0, 6.0, 6.5)
	cam.look_at(centro + Vector3(0.0, 0.3, 0.0))
	cam.current = true
	await avanzar(4)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(DIR + "/" + nombre))
	print("captura: ", nombre)
	cam.current = false
	if cam_juego != null and is_instance_valid(cam_juego):
		cam_juego.current = true
	cam.queue_free()
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = true
