extends "res://herramientas/escenario_base.gd"
## LA CASCADA DE C2 Y EL AGUA SOBRE LA LAVA DE C3 (24/10): las fotos. NECESITA VENTANA.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_cascada.gd -- <etiqueta> [carpeta] [c2|c3|todo]
## `etiqueta` (antes | despues) va en el nombre del archivo. Por defecto res://docs/capturas/cueva_cascada (con .gdignore).
##   c2: C2 con la cámara DEL JUEGO (la de arranque) y un primer plano de la cascada; la cortina desde otro ángulo.
##   c3: la flecha de agua REAL (con su gravedad) lanzada desde la orilla de C3 sobre la lava: antes del impacto, enfriando y con el puente de roca.
## Solo mira; los contratos los comprueba `escenario_cueva_completa.gd`.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const T_CASCADA_S: float = 14.0                  ## lo que tarda la cascada en llenar el pozo y asentarse

var _dir: String = "res://docs/capturas/cueva_cascada"
var _et: String = "despues"
var _cam: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_et = a[0]
	if a.size() > 1 and a[1] != "":
		_dir = a[1]
	var que: String = a[2] if a.size() > 2 else "todo"
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	_cam = maqueta.get("_camara") as Camera3D
	await avanzar(30)
	if que == "c2" or que == "todo":
		await _c2()
	if que == "c3" or que == "todo":
		await _c3()


func _c2() -> void:
	colocar_jugador(Vector2i(4, 6))
	await avanzar_s(T_CASCADA_S)
	print("camara: tam %s · posicion %s · jugador %s" % [str(_cam.size), str(_cam.global_position), str(jugador.position)])
	await _foto("c2_juego_%s" % _et)
	colocar_jugador(Vector2i(4, 5))
	await _zoom(4.6, 1.0)
	await _foto("c2_cascada_cerca_%s" % _et)
	await avanzar_s(0.25)
	await _foto("c2_cascada_cerca_%s_b" % _et)
	await _zoom(3.0, 0.5)
	await _foto("c2_cascada_primer_plano_%s" % _et)
	colocar_jugador(Vector2i(3, 8))
	await _zoom(5.0, 1.0)
	await _foto("c2_cascada_desde_el_pozo_%s" % _et)
	colocar_jugador(Vector2i(2, 5))
	await _zoom(6.0, 1.0)
	await _foto("c2_cascada_terraza_%s" % _et)
	var sim: AguaSim3D = Terreno3D.agua_sim
	var s: String = ""
	for y in range(3, 10):
		for x in range(0, 6):
			var c := Vector2i(x, y)
			s += " %s%.2f" % [Terreno3D.letra_de(c), sim.profundidad_casilla(c)]
		s += "\n"
	print("profundidad C2 (letra+prof):\n", s)
	print("cascada en (2,6): ", sim.hay_cascada_en_casilla(Vector2i(2, 6)))


func _c3() -> void:
	var lava: Lava3D = (maqueta.get_node("Puzles") as Puzle3D).nodo("rio") as Lava3D
	colocar_jugador(Vector2i(12, 5))
	await _zoom(7.0, 1.5)
	await _foto("c3_lava_antes_de_la_flecha_%s" % _et)
	await _lanzar_real("agua", ["flecha"], Vector3(1.0, 0.0, 0.0))
	for i in 4:
		await avanzar_s(0.35)
		await _foto("c3_flecha_agua_%d_%s" % [i, _et])
	await avanzar_s(1.5)
	await _foto("c3_lava_enfriada_%s" % _et)
	print("lava (13,5) roca: ", lava.es_roca(Vector2i(13, 5)) if lava != null else "sin lava")


func _lanzar_real(elemento: String, glifos: Array, dir: Vector3) -> void:
	var t: float = 0.0
	while t < 8.0:
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(dir.x, 0.0, dir.z).normalized()):
			return
		t += await avanzar_s(0.5)


func _zoom(tam: float, s: float) -> void:
	maqueta.set("_tam_camara", tam)
	if _cam != null:
		_cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	print("foto %s" % nombre)
	return img


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
