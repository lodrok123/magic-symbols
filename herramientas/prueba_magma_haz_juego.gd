extends "res://herramientas/captura_vfx_en_juego.gd"
## PRUEBA DEL HAZ DE MAGMA EN EL JUEGO (12/11/2026). NECESITA VENTANA (sin ella no hay imagen que comparar: AVISO y solo se mira el árbol).
##   godot --path . --resolution 1280x720 --script res://herramientas/prueba_magma_haz_juego.gd -- [carpeta]
## Bosque 01 v01 con la cámara del juego y lo de serie (`vfx_procedural` + la lista por defecto). Lanza el haz de magma (sello magma + ᛁ ᛁ, sin tocar el Hechizo)
## como lo lanza el juego (`HechizoVivo.crear` → `hechizo_v2` con `haz` → `VfxToyJuego._haz`) y comprueba que SE DIBUJA: un MagmaToy HAZ con mallas visibles
## de verdad (visibles en el árbol, con malla y sin escala cero) y que la imagen del juego cambia a lo largo del recorrido del haz respecto al fotograma de antes
## (píxeles rojos/naranjas nuevos, la paleta del magma). Escribe <carpeta>/magma_haz_antes.png y magma_haz_<t>.png.

const T_FOTOS: Array = [0.3, 0.6]
const UMBRAL_PIXELES: int = 400           ## píxeles que cambian y tiran al rojo/naranja en el recorrido del haz (un haz de 2 ᛁ ocupa miles)

var _hz: Dictionary = {}


func _escenario() -> void:
	_dir = "res://docs/capturas/vfx_en_juego/magma_haz"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		_ok("carga el Bosque 01", false)
		return
	lanzador.tinta = null
	lanzador.hechizo_v2.connect(func(_e: String, el: String, g: Dictionary, _o: Vector3, _d: Vector3, _p: Dictionary) -> void:
		if el == "magma" and g.has("haz"):
			_hz = g["haz"])
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro llano", c != Vector2i(-1, -1), str(c))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	await avanzar_s(2.0)
	var con_imagen: bool = RenderingServer.get_rendering_device() != null and DisplayServer.get_name() != "headless"
	if not con_imagen:
		_aviso("sin ventana: no se compara la imagen (correla con --resolution 1280x720, sin --headless)")
	_ocultar_ui(root)
	var antes: Image = root.get_viewport().get_texture().get_image() if con_imagen else null
	if antes != null:
		antes.save_png(ProjectSettings.globalize_path(_dir.path_join("magma_haz_antes.png")))
	var vfx: VfxToyJuego = root.find_child("VfxToyJuego", true, false) as VfxToyJuego
	_ok("0 hay VfxToyJuego y el magma lo dibuja el toy", vfx != null and VfxToyJuego.usa_toy("magma"))
	await _caso("hechizo", vfx, antes)
	await avanzar_s(3.0)
	colocar_jugador(c)
	await avanzar_s(1.0)
	await _caso("libro", vfx, antes)
	print("capturas en ", _dir)


## `como`: «hechizo» = HechizoVivo.crear con el Hechizo de magma (lo que hace la captura); «libro» = como en el juego: libro avanzado, página fuego + tierra + ᛁ ᛁ,
## lanzada con el conjuro (`lanzar_pagina_ya` con conjuro: runa, voluta, carga en la mano y disparo).
func _caso(como: String, vfx: VfxToyJuego, antes: Image) -> void:
	_hz = {}
	var creados0: int = int(vfx.creados["magma"]) if vfx != null else 0
	if como == "hechizo":
		var h: Hechizo = Hechizo.construir(load("res://nucleo/magma_rune.tres") as RuneData, {"linea_x": 2})
		_ok("1 %s: el Hechizo de magma con ᛁ ᛁ es un haz" % como, h.haz, "estado %s" % h.estado_materia)
		HechizoVivo.crear(h, jugador.position + Vector3(0.0, 0.8, 0.0), Vector3.RIGHT, lanzador)
		await avanzar(2)
	else:
		Repertoire.activate_all()
		Repertoire.max_sigils_per_page = 0
		Repertoire.libro = "avanzado"
		lanzador.cooldown_left[0] = 0.0
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element("fuego")
		lanzador.place_element("tierra")
		lanzador.add_sigil(Vector2.RIGHT, "linea_x")
		lanzador.add_sigil(Vector2.LEFT, "linea_x")
		var lanzo: bool = lanzador.lanzar_pagina_ya(0, jugador.position, Vector3.RIGHT, true)
		_ok("1 %s: la página fuego + tierra + ᛁ ᛁ se lanza (%s)" % [como, lanzador.feedback_text], lanzo)
		var t0: int = Time.get_ticks_msec()
		while _hz.is_empty() and Time.get_ticks_msec() - t0 < 4000:
			await avanzar(1)
		await avanzar(2)
	_ok("1 %s: la lógica emite el haz de magma (hechizo_v2 con «haz»)" % como, not _hz.is_empty(), str(_hz.get("largo", -1.0)))
	var toy: MagmaToy = vfx.ultimo as MagmaToy if vfx != null and int(vfx.creados["magma"]) > creados0 else null
	_ok("1 %s: VfxToyJuego crea un MagmaToy con la figura HAZ" % como, toy != null and toy.figura == MagmaToy.Figura.HAZ, "ultimo %s" % (str(vfx.ultimo) if vfx != null else "-"))
	var t_ant: float = 0.0
	for t in T_FOTOS:
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		if toy == null or not is_instance_valid(toy):
			_ok("2 %s (%.1f s) el MagmaToy sigue vivo" % [como, t], false)
			break
		var vis: Dictionary = _visibles(toy)
		_ok("2 %s (%.1f s) el MagmaToy tiene mallas que se ven (%d visibles con malla, %d ocultas; visible en el árbol: %s)" % [como, t, int(vis["si"]), int(vis["no"]), str(toy.is_visible_in_tree())],
			toy.is_visible_in_tree() and int(vis["si"]) > 0, str(vis["nombres"]))
		if antes == null:
			continue
		_ocultar_ui(root)
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(_dir.path_join("magma_haz_%s_%03d.png" % [como, int(round(float(t) * 100.0))])))
		var n: int = _pixeles_magma(antes, img, toy)
		_ok("3 %s (%.1f s) la imagen del juego cambia a lo largo del haz con tonos de magma (%d píxeles ≥ %d)" % [como, t, n, UMBRAL_PIXELES], n >= UMBRAL_PIXELES)


## Mallas del toy (GeometryInstance3D): cuántas se ven de verdad (visibles en el árbol, con malla o MultiMesh con instancias) y cuántas no.
func _visibles(t: Node3D) -> Dictionary:
	var si: int = 0
	var no: int = 0
	var nombres: Array = []
	for n in t.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		var tiene: bool = false
		if gi is MeshInstance3D:
			tiene = (gi as MeshInstance3D).mesh != null
		elif gi is MultiMeshInstance3D:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			tiene = mm != null and (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count) > 0
		elif gi is GPUParticles3D:
			tiene = (gi as GPUParticles3D).emitting
		else:
			tiene = true
		var escala: float = gi.global_transform.basis.get_scale().length()
		if gi.is_visible_in_tree() and tiene and escala > 0.01:
			si += 1
			if nombres.size() < 8:
				nombres.append(String(gi.name))
		else:
			no += 1
	return {"si": si, "no": no, "nombres": nombres}


## Píxeles que cambian respecto a `antes` y tiran al rojo/naranja (R claramente sobre G y B), dentro del rectángulo de pantalla que cubre el recorrido del haz.
func _pixeles_magma(antes: Image, img: Image, toy: Node3D) -> int:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	if cam == null:
		return 0
	var desde: Vector3 = _hz.get("desde", toy.global_position) as Vector3
	var hasta: Vector3 = _hz.get("hasta", toy.global_position + Vector3.RIGHT * 4.0) as Vector3
	var r := Rect2(cam.unproject_position(desde), Vector2.ZERO)
	for p in [desde, hasta, desde + Vector3.UP * 1.5, hasta + Vector3.UP * 1.5, toy.global_position]:
		r = r.expand(cam.unproject_position(p as Vector3))
	r = r.grow(40.0).intersection(Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height())))
	var n: int = 0
	for y in range(int(r.position.y), int(r.end.y), 2):
		for x in range(int(r.position.x), int(r.end.x), 2):
			var c1: Color = img.get_pixel(x, y)
			var c0: Color = antes.get_pixel(x, y)
			var cambio: float = absf(c1.r - c0.r) + absf(c1.g - c0.g) + absf(c1.b - c0.b)
			if cambio > 0.15 and c1.r > c1.g + 0.12 and c1.r > c1.b + 0.12:
				n += 1
	return n * 4
