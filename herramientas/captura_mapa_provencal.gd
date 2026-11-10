extends "res://herramientas/escenario_base.gd"

## CAPTURAS (7/11) del MAPA DE MUESTREO del pack Fantasy Provencal (escenas/PruebaProvencal.tscn, mapa mundo/datos_nivel/mapas/Provencal.txt) con la escena de verdad y la camara FIJA del juego
## (ortogonal a 60 grados mirando al norte; `CAMARA_GIRA = false`, Z/C no giran): vista general desde arriba, una vista desde arriba por zona (para leer cada pieza), dos capturas por zona desde la
## camara del juego con la jugadora dentro, y la prueba de OCLUSION: la jugadora DETRAS (al norte, mas lejos de la camara) de follaje con recorte alfa, con el circulo de transparencia y sin el.
## Tambien comprueba los avisos de Puzle3D al cargar y la solidez de las piezas. Para MIRARLO. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_mapa_provencal.gd -- docs/capturas/provencal/mapa

const RUTA: String = "res://escenas/PruebaProvencal.tscn"
const MAPA: String = "res://mundo/datos_nivel/mapas/Provencal.txt"
const S: float = 2.3
const TAM_VENTANA: Vector2i = Vector2i(1600, 900)

var _dir: String = "docs/capturas/provencal/mapa"
var _piezas: Dictionary = {}       ## id de pieza -> Vector2i (casilla)
var _rects: Dictionary = {}        ## titulo -> Rect2i
var _cam: Camera3D = null


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM_VENTANA
	_leer_mapa()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	var pz: Puzle3D = maqueta.get_node("Puzles") as Puzle3D
	var n_avisos: int = pz.avisos.size() if pz != null else -1
	_ok("1 Puzle3D carga el mapa sin avisos", n_avisos == 0, "%d avisos %s" % [n_avisos, str(pz.avisos.slice(0, 5)) if pz != null else ""])
	var puestas: int = 0
	for id in _piezas.keys():
		if maqueta.find_child(String(id), true, false) != null:
			puestas += 1
	_ok("2 estan todas las piezas colocadas", puestas == _piezas.size(), "%d de %d" % [puestas, _piezas.size()])
	# Solidez para quien camina: lo solido bloquea su casilla, la hierba, las flores y las enredaderas se pisan, y la casilla libre de alrededor queda libre.
	for id in ["d_prov_crate_01", "d_prov_barrel", "d_prov_house_barn", "d_prov_rock_large_01", "d_prov_shrine"]:
		if _piezas.has(id):
			_ok("3 bloquea su casilla: %s" % id, Terreno3D.bloqueada(_piezas[id]))
	for id in ["d_prov_grassfield_01_b", "d_prov_flower_01_c", "d_prov_vines_group_01", "d_prov_bridge", "d_prov_bush_02"]:
		if _piezas.has(id):
			_ok("3 se pisa: %s" % id, not Terreno3D.bloqueada(_piezas[id]))
	if _piezas.has("d_prov_crate_01"):
		var cc: Vector2i = _piezas["d_prov_crate_01"]
		_ok("3 la casilla de al lado de la caja esta libre", not Terreno3D.bloqueada(cc + Vector2i(1, 0)) and not Terreno3D.bloqueada(cc + Vector2i(0, 1)))
	# Sin relleno de la maqueta (adornos de claros, hierba alta): solo lo que pone el mapa.
	_ok("4 sin relleno decorativo de la maqueta", int(maqueta.get("_adornos_borde")) == 0 or maqueta.get("_adornos_borde") == null)
	_cam = root.get_viewport().get_camera_3d()
	var tam0: float = _cam.size
	for cl in root.find_children("*", "CanvasLayer", true, false):       # sin HUD ni paleta F1 en las capturas
		(cl as CanvasLayer).visible = false

	# --- vista general y una vista por zona desde arriba (camara propia ortogonal a plomo; norte arriba) ---
	var filas: PackedStringArray = _filas_mapa()
	var ancho_c: int = (filas[0] as String).length()
	var alto_c: int = filas.size()
	var arriba := Camera3D.new()
	arriba.projection = Camera3D.PROJECTION_ORTHOGONAL
	arriba.far = 400.0
	maqueta.add_child(arriba)
	await _arriba(arriba, Rect2i(0, 0, ancho_c, alto_c), 2600, "mapa_general.png")
	for titulo in _rects.keys():
		var r: Rect2i = _rects[titulo]
		var mitades: int = 2 if r.size.x > 40 else 1             # la zona ancha (vegetacion) en dos mitades para que se lean las piezas
		for k in range(mitades):
			var rr := Rect2i(r.position.x + k * (r.size.x / 2), r.position.y - 1, r.size.x / mitades, r.size.y + 1)
			await _arriba(arriba, rr, 2400, "arriba_%s%s.png" % [String(titulo).to_lower(), "" if mitades == 1 else "_%d" % (k + 1)])
	arriba.current = false
	_cam.current = true
	root.get_window().size = TAM_VENTANA
	arriba.queue_free()

	# --- dos capturas por zona desde la camara del juego ---
	_cam.size = 26.0
	for titulo in _rects.keys():
		var r: Rect2i = _rects[titulo]
		var vistas: Array = [Vector2i(r.position.x + 12, r.position.y + 3), Vector2i(r.position.x + 22, r.position.y + maxi(r.size.y - 4, 4))]
		for k in range(vistas.size()):
			_poner_jugadora(vistas[k])
			await avanzar(45)
			_guardar("zona_%s_%d.png" % [String(titulo).to_lower(), k + 1])

	# --- oclusion: la jugadora DETRAS (al norte: la camara mira desde el sur) de follaje con recorte alfa, con el circulo y sin el. Los rotulos fuera para ver la pieza. ---
	_rotulos(false)
	_cam.size = 7.0
	# desplazamiento hacia el norte (z negativo, en m) desde el centro de la pieza: lo bastante para que la pieza tape a la jugadora en pantalla (la camara mira a 60 grados)
	var detras: Dictionary = {"d_prov_bush_01": Vector3(0, 0, -1.0), "d_prov_vines_group_01": Vector3(0, 0, -1.6), "d_prov_tree_cypress": Vector3(0, 0, -2.4)}
	for id in detras.keys():
		if not _piezas.has(id):
			continue
		_poner_jugadora(_piezas[id], detras[id])
		for con_circulo in [true, false]:
			maqueta.set("radio_transparencia", 1.9 if con_circulo else 0.0)
			await avanzar(40)
			_guardar("oclusion_%s_%s.png" % [String(id).trim_prefix("d_prov_"), "con_circulo" if con_circulo else "sin_circulo"])
	maqueta.set("radio_transparencia", 1.9)
	_cam.size = tam0


## Foto desde arriba (norte arriba) del rectangulo de casillas `r`, con la ventana a `ancho_px` de ancho y el alto que toque.
func _arriba(cam: Camera3D, r: Rect2i, ancho_px: int, nombre: String) -> void:
	var alto_px: int = int(round(float(ancho_px) * float(r.size.y) / float(r.size.x)))
	alto_px = clampi(alto_px, 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro: Vector3 = Terreno3D.centro_de(r.position, 0.0) + Vector3(float(r.size.x - 1) * 0.5 * S, 0.0, float(r.size.y - 1) * 0.5 * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(25)
	_guardar(nombre)


func _poner_jugadora(c: Vector2i, desp: Vector3 = Vector3.ZERO) -> void:
	jugador.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c)) + desp
	if "velocity" in jugador:
		jugador.set("velocity", Vector3.ZERO)


func _rotulos(visibles: bool) -> void:
	for l in maqueta.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = visibles


func _filas_mapa() -> PackedStringArray:
	var res := PackedStringArray()
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		if l != "" and not l.begins_with(";"):
			res.append(l)
	return res


func _leer_mapa() -> void:
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		var p: PackedStringArray = l.split(" ")
		if l.begins_with("; pieza ") and p.size() >= 6:
			_piezas[p[2]] = Vector2i(int(p[4]), int(p[5]))
		elif l.begins_with("; rect ") and p.size() >= 7:
			_rects[p[2]] = Rect2i(int(p[3]), int(p[4]), int(p[5]), int(p[6]))


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura: ", _dir.path_join(nombre), " ", img.get_size())
