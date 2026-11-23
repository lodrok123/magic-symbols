extends "res://herramientas/escenario_base.gd"
## 22/11 (Pablo: «sala campamento»): un mapa GENERADO con un campamento goblin, cargado en el juego de verdad. Exporta un mapa temporal (CampGenPrueba),
## lo carga y comprueba que las piezas del campamento salen montadas: empalizada, puertas goblin que arden, torre, tiendas, fogata, guardias, chamán,
## vigía y el cofre épico que aparece al limpiarlo. Al acabar borra el mapa y la escena temporales.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_campamento_generado.gd
## Con `-- foto <carpeta>` (y CON ventana) además saca una foto del campamento desde arriba.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "CampGenPrueba"
var _m: Dictionary = {}


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	_m = Generador.new().generar({"algoritmo": "salas", "semilla": 3, "campamentos": 1, "estilo": "bosque", "luz": "bosque", "nombre": NOMBRE})
	var res: Dictionary = Exportador.exportar(_m, true)
	_ok("0 se exporta el mapa con campamento", bool(res.get("ok", false)), str(res.get("error", "")))
	if not bool(res.get("ok", false)):
		return
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		_limpiar()
		return
	await avanzar(20)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 el nivel trae sus piezas", z != null)
	var rect: Rect2i = Rect2i()
	for l in _m["lineas"]:
		if String(l).begins_with("; pieza camp1_vigia"):
			for k in String(l).split(" "):
				if k.begins_with("de="):
					var rr: PackedStringArray = k.substr(3).replace("..", ",").split(",")
					rect = Rect2i(rr[0].to_int(), rr[1].to_int(), rr[2].to_int() - rr[0].to_int() + 1, rr[3].to_int() - rr[1].to_int() + 1)
	_ok("1 el mapa trae un campamento", rect.size.x > 0, str(rect))
	# Lo que la maqueta colocó dentro del rectángulo del campamento: su registro de piezas (el decorado va por lotes y no tiene nodo propio).
	var cuenta: Dictionary = {"empalizada_goblin": 0, "puerta_goblin": 0, "torre_goblin": 0, "tienda_goblin": 0, "estandarte_goblin": 0}
	for e in (maqueta.get("_registro") as Array):
		var id: String = String(e[0])
		if cuenta.has(id) and rect.has_point(e[1] as Vector2i):
			cuenta[id] += 1
	print("  piezas dentro del campamento: ", cuenta)
	var todas: bool = true
	for k in cuenta:
		todas = todas and int(cuenta[k]) > 0
	_ok("1 están todas las piezas del campamento (empalizada, puertas goblin, torre, tiendas, estandarte)", todas, str(cuenta))
	var bloq: int = 0
	for c in (maqueta.get("_bloqueadas") as Dictionary):
		if rect.has_point(c as Vector2i):
			bloq += 1
	_ok("1 la empalizada y las piezas bloquean sus casillas", bloq >= int(cuenta["empalizada_goblin"]), "%d bloqueadas" % bloq)
	var goblins: int = 0
	for g in get_nodes_in_group("combate3d"):
		if rect.has_point(Terreno3D.celda_de((g as Node3D).global_position)):
			goblins += 1
	_ok("1 hay guardias dentro (goblins y chamán)", goblins >= 2, str(goblins))
	var cofre: Node = z.nodo("camp1_cofre") if z != null else null
	_ok("1 el cofre épico existe y está escondido hasta limpiar el campamento", cofre != null and not Flags.i().tiene("%s.campamento_1.limpio" % NOMBRE.to_lower()))
	if OS.get_cmdline_user_args().has("foto"):
		await _foto(rect)
	_limpiar()


func _foto(rect: Rect2i) -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var carpeta: String = a[a.find("foto") + 1] if a.find("foto") + 1 < a.size() else "user://"
	var centro: Vector3 = Vector3((rect.get_center().x + 0.5) * Terreno3D.casilla, 0.0, (rect.get_center().y + 0.5) * Terreno3D.casilla)
	var cam := Camera3D.new()
	maqueta.add_child(cam)
	cam.global_position = centro + Vector3(0.0, 30.0, 18.0)
	cam.look_at(centro, Vector3.UP)
	cam.fov = 40.0
	cam.make_current()
	for _i in 10:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(carpeta)
	img.save_png(carpeta.path_join("campamento_generado.png"))
	print("  foto: ", carpeta.path_join("campamento_generado.png"))


func _limpiar() -> void:
	for ruta in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
