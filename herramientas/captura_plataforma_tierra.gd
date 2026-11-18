extends "res://herramientas/escenario_base.gd"
## PLATAFORMA DE TIERRA EN EL JUEGO (18/11/2026). NECESITA VENTANA. Levanta en un claro del Bosque 01 v01 un escalón de una casilla y un puente de tres
## (`Lanzador3D.levantar_plataforma_tierra`, lo mismo que llama el hechizo) con la cámara del juego y guarda la foto.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_plataforma_tierra.gd -- [ruta_png]

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"

var _png: String = "res://docs/capturas/plataforma_tierra_rockform.png"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_png = a[0]
	Flags.nuevo()
	Misiones.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro llano para la captura (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c + Vector2i(1, 0))
	await avanzar_s(1.5)
	var escalon: Array[Vector2i] = [c + Vector2i(2, -1)]
	var puente: Array[Vector2i] = [c + Vector2i(2, 1), c + Vector2i(3, 1), c + Vector2i(4, 1)]
	lanzador.levantar_plataforma_tierra(escalon, 30.0)
	lanzador.levantar_plataforma_tierra(puente, 30.0)
	await avanzar_s(1.0)
	var piezas: int = 0
	var losas: int = 0
	for n in lanzador.mundo.get_children():
		if str(n.name).contains("PlataformaTierra"):    # la segunda se llama «@PlataformaTierra@N»: Godot renombra el nodo repetido
			piezas += 1
			losas += n.find_children("*", "MeshInstance3D", true, false).size()
	_ok("1 hay dos plataformas con una losa por casilla (piezas %d, losas %d)" % [piezas, losas], piezas == 2 and losas == 4)
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = ProjectSettings.globalize_path(_png) if _png.begins_with("res://") else _png
	_ok("2 foto guardada en %s" % ruta, img.save_png(ruta) == OK)


func _buscar_claro() -> Vector2i:
	for y in range(4, 38):
		for x in range(2, 40):
			var ok: bool = true
			var base: float = Terreno3D.y_pies(Vector2i(x, y))
			for dx in range(-1, 8):
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
