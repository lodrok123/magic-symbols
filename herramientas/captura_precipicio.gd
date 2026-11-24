extends "res://herramientas/escenario_base.gd"
## PRECIPICIO DEL PASO DE TIERRA EN EL JUEGO (24/11/2026). NECESITA VENTANA. Genera el Bosque 01 de Pablo con el generador (paso de tierra en la
## salida 2), lo exporta con un nombre de prueba, lo carga, pone a la jugadora junto al precipicio y guarda dos fotos con la cámara del juego:
## sin puente y con el puente de tierra tendido desde el borde. Al acabar borra el mapa y la escena de prueba.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_precipicio.gd -- [prefijo_png] [semilla]

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "ZzCapPrecipicio"

var _png: String = "res://docs/capturas/precipicio"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_png = a[0]
	var semilla: int = a[1].to_int() if a.size() > 1 else 3
	Flags.nuevo()
	Estado.nuevo()
	var m: Dictionary = Generador.new().generar({"algoritmo": "bosque", "semilla": semilla, "ancho": 48, "alto": 42, "nombre": NOMBRE,
		"salida_a": "CuevaTerrafina:a_bosque=desde_cueva, Precipicio:inicio, Ruinas:inicio, Bosque_02:desde_bosque01",
		"lados_salida": "s, o, s, e", "paso_tierra": 2, "estilo": "bosque", "luz": "bosque", "salas_cerradas": 0, "enemigos": 0.0})
	var hueco: Array = m["precipicio"]
	_ok("0 el mapa tiene precipicio (%d casillas)" % hueco.size(), not hueco.is_empty())
	if hueco.is_empty():
		return
	var res: Dictionary = Exportador.exportar(m)
	_ok("0 se exporta", bool(res["ok"]), String(res["error"]))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null or jugador == null:
		_borrar()
		return
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	# El sitio del puente: una casilla de suelo junto al hueco desde la que se cruza recto (2 de vacío y suelo al otro lado).
	var tramo: Array = _tramo_puente(hueco)
	_ok("1 hay un sitio desde el que tender el puente", not tramo.is_empty())
	if tramo.is_empty():
		_borrar()
		return
	var borde: Vector2i = tramo[0]
	var d: Vector2i = tramo[1]
	colocar_jugador(borde)
	await avanzar_s(4.5)            # que se vaya el cartel con el nombre del nivel
	var pr: Node = maqueta.get_node_or_null("Precipicio")
	_ok("1 la maqueta monta las paredes del precipicio", pr != null and int(pr.get("n_caras")) > 0, str(pr.get("n_caras")) if pr != null else "sin nodo")
	_foto(_png + "_sin_puente.png")
	var celdas: Array[Vector2i] = [borde, borde + d, borde + d * 2]
	lanzador.levantar_plataforma_tierra(celdas, 60.0)
	await avanzar_s(1.0)
	_foto(_png + "_con_puente.png")
	_borrar()


func _tramo_puente(hueco: Array) -> Array:
	var es: Dictionary = {}
	for c in hueco:
		es[c] = true
	# Primero hacia el norte (la jugadora al sur, mirando el hueco como mira la cámara); si no, cualquiera.
	for dirs in [[Vector2i(0, -1)], [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]]:
		for c in hueco:
			for d in dirs:
				var borde: Vector2i = (c as Vector2i) - d
				if es.has(borde) or Terreno3D.es_vacio(borde) or Terreno3D.celda_solida(borde, 0) or Lanzador3D.es_agua(borde):
					continue
				var fin: Vector2i = (c as Vector2i) + d * 2
				if es.has((c as Vector2i) + d) and not es.has(fin) and not Terreno3D.celda_solida(fin, 0) and not Lanzador3D.es_agua(fin):
					return [borde, d]
	return []


func _foto(ruta_res: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = ProjectSettings.globalize_path(ruta_res) if ruta_res.begins_with("res://") else ruta_res
	_ok("2 foto guardada en %s" % ruta, img.save_png(ruta) == OK)


func _borrar() -> void:
	for r in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
