extends "res://herramientas/escenario_base.gd"

## CAPTURAS (8/11) del MAPA DE MUESTRA DEL PANTANO (escenas/PruebaPantano.tscn, mapa mundo/datos_nivel/mapas/Pantano.txt) con la escena de verdad, la luz «pantano» y la camara FIJA del juego
## (ortogonal a 60 grados mirando al norte; `CAMARA_GIRA = false`): una vista general desde arriba (con y sin los postes de los huecos) y tres vistas desde la camara del juego con la jugadora dentro
## (la orilla de salida, el cruce de la pasarela y la cabana del lago). Comprueba tambien los avisos de Puzle3D al cargar, la luz de la zona y la bruma sobre el agua. Para MIRARLO. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_mapa_pantano.gd -- docs/capturas/pantano

const RUTA: String = "res://escenas/PruebaPantano.tscn"
const MAPA: String = "res://mundo/datos_nivel/mapas/Pantano.txt"
const S: float = 2.3
const TAM_VENTANA: Vector2i = Vector2i(1600, 900)

var _dir: String = "docs/capturas/pantano"
var _cam: Camera3D = null


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM_VENTANA
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, false)
	var pz: Puzle3D = maqueta.get_node("Puzles") as Puzle3D
	var n_avisos: int = pz.avisos.size() if pz != null else -1
	_ok("1 Puzle3D carga el mapa sin avisos", n_avisos == 0, "%d avisos %s" % [n_avisos, str(pz.avisos.slice(0, 6)) if pz != null else ""])
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	var esperado: Color = LuzZona3D.ZONAS["pantano"]["sol_color"]
	_ok("2 la luz de la escena es la del pantano", sol != null and sol.light_color.is_equal_approx(esperado), "sol %s" % [str(sol.light_color) if sol != null else "?"])
	_ok("3 hay bruma baja sobre el agua", maqueta.get_node_or_null("NieblaAgua3D") != null)
	_ok("4 hay postes de hueco", maqueta.get_node("Huecos").get_child_count() > 0, "%d" % maqueta.get_node("Huecos").get_child_count())
	_cam = root.get_viewport().get_camera_3d()
	var tam0: float = _cam.size
	for cl in root.find_children("*", "CanvasLayer", true, false):       # sin HUD ni paleta F1 en las capturas
		(cl as CanvasLayer).visible = false

	# --- vista general desde arriba (camara propia ortogonal a plomo; norte arriba) ---
	var filas: PackedStringArray = _filas_mapa()
	var arriba := Camera3D.new()
	arriba.projection = Camera3D.PROJECTION_ORTHOGONAL
	arriba.far = 400.0
	maqueta.add_child(arriba)
	await _arriba(arriba, Rect2i(0, 0, (filas[0] as String).length(), filas.size()), 2200, "mapa_general.png")
	_huecos(false)
	await _arriba(arriba, Rect2i(0, 0, (filas[0] as String).length(), filas.size()), 2200, "mapa_general_sin_huecos.png")
	arriba.current = false
	_cam.current = true
	root.get_window().size = TAM_VENTANA
	arriba.queue_free()

	# --- tres vistas desde la camara del juego ---
	_cam.size = 22.0
	var vistas: Array = [
		["vista_1_orilla_salida.png", Vector2i(5, 24), false],
		["vista_2_cruce_pasarela.png", Vector2i(11, 18), true],
		["vista_3_cabana_lago.png", Vector2i(30, 11), true],
		["vista_4_cabana_muelle_pasarela.png", Vector2i(30, 9), false, 15.0],
		["vista_5_manglar_eneas_lirio_setas.png", Vector2i(5, 16), false, 9.0],
	]
	for v in vistas:
		_huecos(bool(v[2]))
		_cam.size = float(v[3]) if v.size() > 3 else 22.0
		_poner_jugadora(v[1] as Vector2i)
		await avanzar(60)
		_guardar(String(v[0]))
	_cam.size = tam0


func _huecos(visibles: bool) -> void:
	for h in maqueta.get_node("Huecos").get_children():
		(h as Node3D).visible = visibles


## Foto desde arriba (norte arriba) del rectangulo de casillas `r`, con la ventana a `ancho_px` de ancho y el alto que toque.
func _arriba(cam: Camera3D, r: Rect2i, ancho_px: int, nombre: String) -> void:
	var alto_px: int = int(round(float(ancho_px) * float(r.size.y) / float(r.size.x)))
	alto_px = clampi(alto_px, 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro: Vector3 = Terreno3D.centro_de(r.position, 0.0) + Vector3(float(r.size.x - 1) * 0.5 * S, 0.0, float(r.size.y - 1) * 0.5 * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(30)
	_guardar(nombre)


func _poner_jugadora(c: Vector2i) -> void:
	jugador.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if "velocity" in jugador:
		jugador.set("velocity", Vector3.ZERO)


func _filas_mapa() -> PackedStringArray:
	var res := PackedStringArray()
	for l in FileAccess.get_file_as_string(MAPA).split("\n"):
		if l != "" and not l.begins_with(";"):
			res.append(l)
	return res


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura: ", _dir.path_join(nombre), " ", img.get_size())
