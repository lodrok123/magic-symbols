extends "res://herramientas/escenario_base.gd"

## PRUEBA DE PUNTA A PUNTA (24/11/2026): un mapa del GENERADOR vestido con el pack Stylized Lost Cave. Genera una cueva (algoritmo «cueva») y una
## mazmorra (algoritmo «salas») con `paredes = "lostcave"`, las exporta como el botón «Exportar» de la herramienta (escenas/PruebaLostCaveGen*.tscn
## + mapas/LostCaveGen*.txt), las carga con la maqueta y comprueba: que la escena lleva `paredes_cueva = "lostcave"`, que Puzle3D no da avisos, que
## salen rocas del pack en las paredes (una por cada lado de muro que da a suelo como mínimo) y que ninguna sale del pack si se pide el kit.
## Hace una foto desde arriba de cada una y, al acabar, BORRA lo exportado (con `-- dejar` lo deja, para abrirlo y pasearlo).
## Necesita ventana y el pack generado (tools\preparar_lostcave.cmd):
##   godot --path . --script res://herramientas/captura_lostcave_generado.gd [-- dejar]
## Fotos en arte/lostcave/capturas/generado/ (fuera de git, como el pack).

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const DIR: String = "res://arte/lostcave/capturas/generado"
const S: float = 2.3
const CASOS: Array = [
	{"nombre": "LostCaveGenCueva", "algoritmo": "cueva", "semilla": 7, "ancho": 40, "alto": 34},
	{"nombre": "LostCaveGenSalas", "algoritmo": "salas", "semilla": 3, "ancho": 40, "alto": 34},
]

var _dejar: bool = false


func _escenario() -> void:
	_dejar = OS.get_cmdline_user_args().has("dejar")
	var dir: String = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for caso in CASOS:
		var par: Dictionary = Generador.parametros_defecto()
		par.merge(caso, true)
		par["estilo"] = "cueva"
		par["luz"] = "cueva"
		par["paredes"] = "lostcave"
		var gen = Generador.new()
		var m: Dictionary = gen.generar(par)
		var nombre: String = String(caso["nombre"])
		var esc_txt: String = Exportador.texto_escena(m)
		_ok("1 %s: la escena exportada pide las paredes del pack" % nombre, esc_txt.contains("paredes_cueva = \"lostcave\""))
		var res: Dictionary = Exportador.exportar(m, true)
		_ok("1 %s: se exporta" % nombre, bool(res["ok"]), String(res["error"]))
		if not bool(res["ok"]):
			continue
		Flags.nuevo()
		Estado.nuevo()
		await cargar(Exportador.ruta_escena(nombre), false)
		var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
		var n_av: int = pz.avisos.size() if pz != null else -1
		_ok("2 %s: Puzle3D sin avisos" % nombre, n_av == 0, "%d %s" % [n_av, str(pz.avisos.slice(0, 4)) if pz != null else ""])
		# rocas del pack y lados de muro que dan a suelo
		var filas: PackedStringArray = m["filas"]
		var lados: int = 0
		for y in range(filas.size()):
			for x in range(filas[y].length()):
				if filas[y][x] != "#":
					continue
				for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.y < filas.size() and q.x < filas[q.y].length() and filas[q.y][q.x] != "#":
						lados += 1
		var rocas: int = 0
		for n in maqueta.find_children("*", "Node3D", true, false):
			if String((n as Node).get_meta("id", "")).begins_with("lost_"):      # por el metadato: las copias repetidas cambian de nombre
				rocas += 1
		_ok("3 %s: hay una roca del pack por cada lado de muro que da a suelo" % nombre, rocas >= lados, "%d rocas y adornos, %d lados" % [rocas, lados])
		for cl in root.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
		root.get_window().size = Vector2i(1600, 900)
		await avanzar(40)
		var img0: Image = root.get_viewport().get_texture().get_image()
		img0.save_png(dir.path_join("%s_juego.png" % nombre))           # la cámara del juego en el inicio
		print("captura: ", dir.path_join("%s_juego.png" % nombre))
		await _arriba(Rect2i(0, 0, int(m["ancho"]), int(m["alto"])), 2000, dir.path_join("%s_arriba.png" % nombre))
		maqueta.queue_free()
		await avanzar(3)
		if not _dejar:
			for ruta in [Exportador.ruta_mapa(nombre), Exportador.ruta_escena(nombre)]:
				if FileAccess.file_exists(ruta):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	# Con el kit no sale ninguna pieza del pack (la opción no cambia nada si no se pide).
	var par_k: Dictionary = Generador.parametros_defecto()
	par_k.merge({"algoritmo": "cueva", "semilla": 7, "estilo": "cueva", "luz": "cueva", "paredes": "kit", "nombre": "LostCaveGenKit"}, true)
	_ok("4 con «kit» la escena no pide las paredes del pack", not Exportador.texto_escena(Generador.new().generar(par_k)).contains("paredes_cueva"))


func _arriba(r: Rect2i, ancho_px: int, ruta: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 400.0
	maqueta.add_child(cam)
	var alto_px: int = clampi(int(round(float(ancho_px) * float(r.size.y) / float(r.size.x))), 500, 1800)
	root.get_window().size = Vector2i(ancho_px, alto_px)
	cam.size = float(r.size.y) * S * maxf(1.0, (float(ancho_px) / float(alto_px)) / (float(r.size.x) / float(r.size.y)))
	var centro := Vector3(float(r.size.x) * 0.5 * S, 0.0, float(r.size.y) * 0.5 * S)
	cam.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0, 0, -1)), centro + Vector3(0, 120, 0))
	cam.current = true
	await avanzar(25)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura: ", ruta, " ", img.get_size())
