extends "res://herramientas/escenario_base.gd"

## PRUEBA DE PUNTA A PUNTA (25/11/2026): un mapa del GENERADOR con estilo «ruinas» (muros finos del pack Stylescape: Ruins en los `#` que tocan
## suelo; presentacion/paredes_stylescape.gd). Genera una mazmorra (algoritmo «salas»), la exporta como el botón «Exportar» de la herramienta
## (escenas/PruebaRuinasGen.tscn + mapas/RuinasGen.txt), la carga con la maqueta y comprueba: que la escena pide `estilo = "ruinas"`, que Puzle3D
## no da avisos, que salen muros del pack (al menos uno por casilla `#` que toca suelo de lado) y que con estilo «bosque» no sale ninguno.
## Foto con la cámara del juego y desde arriba. DEJA lo exportado para pasearlo (con `-- borrar` lo borra al acabar).
## Necesita ventana y el pack generado (arte/stylescape/LEEME.md):
##   godot --path . --script res://herramientas/captura_ruinas_generado.gd [-- borrar]
## Fotos en docs/capturas/stylescape/generado/.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const DIR: String = "res://docs/capturas/stylescape/generado"
const S: float = 2.3
const CASO: Dictionary = {"nombre": "RuinasGen", "algoritmo": "salas", "semilla": 3, "ancho": 40, "alto": 34, "estilo": "ruinas", "luz": "ruinas"}


func _escenario() -> void:
	var borrar: bool = OS.get_cmdline_user_args().has("borrar")
	var dir: String = ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var par: Dictionary = Generador.parametros_defecto()
	par.merge(CASO, true)
	var m: Dictionary = Generador.new().generar(par)
	var nombre: String = String(CASO["nombre"])
	_ok("1 la escena exportada pide el estilo ruinas", Exportador.texto_escena(m).contains("estilo = \"ruinas\""))
	var res: Dictionary = Exportador.exportar(m, true)
	_ok("1 se exporta", bool(res["ok"]), String(res.get("error", "")))
	if not bool(res["ok"]):
		return
	Flags.nuevo()
	Estado.nuevo()
	await cargar(Exportador.ruta_escena(nombre), false)
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var n_av: int = pz.avisos.size() if pz != null else -1
	_ok("2 Puzle3D sin avisos", n_av == 0, "%d %s" % [n_av, str(pz.avisos.slice(0, 4)) if pz != null else ""])
	var filas: PackedStringArray = m["filas"]
	var con_suelo: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if filas[y][x] != "#":
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.y < filas.size() and q.x < filas[q.y].length() and filas[q.y][q.x] != "#" and filas[q.y][q.x] != " ":
					con_suelo += 1
					break
	var muros: int = 0
	for n in maqueta.find_children("*", "Node3D", true, false):
		if String((n as Node).get_meta("id", "")).begins_with("ss_"):
			muros += 1
	_ok("3 hay muros del pack: al menos uno por casilla # que toca suelo", muros >= con_suelo, "%d piezas, %d casillas" % [muros, con_suelo])
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	root.get_window().size = Vector2i(1600, 900)
	await avanzar(40)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_juego.png" % nombre))
	print("captura: ", dir.path_join("%s_juego.png" % nombre))
	# Con la jugadora dentro de una sala, a dos casillas de su pared sur (la baja) y a una (la que pasa por delante de ella).
	for dist in [3, 1]:
		var c: Vector2i = _junto_a_pared_sur(filas, dist)
		if c.x < 0:
			continue
		colocar_jugador(c)
		await avanzar(60)
		var f: String = dir.path_join("%s_sala_%d.png" % [nombre, dist])
		root.get_viewport().get_texture().get_image().save_png(f)
		print("captura: ", f, " jugadora en ", c)
	await _arriba(Rect2i(0, 0, int(m["ancho"]), int(m["alto"])), 2000, dir.path_join("%s_arriba.png" % nombre))
	maqueta.queue_free()
	await avanzar(3)
	if borrar:
		for ruta in [Exportador.ruta_mapa(nombre), Exportador.ruta_escena(nombre)]:
			if FileAccess.file_exists(ruta):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	# Con estilo bosque, la opción no cambia nada: ni un muro del pack.
	var par_b: Dictionary = Generador.parametros_defecto()
	par_b.merge(CASO, true)
	par_b["estilo"] = "bosque"
	_ok("4 con estilo bosque la escena no pide ruinas", not Exportador.texto_escena(Generador.new().generar(par_b)).contains("estilo = \"ruinas\""))


## Una casilla de suelo de una sala (con suelo 4 casillas a cada lado) que tiene la pared sur a `dist` casillas; (-1, -1) si no hay.
func _junto_a_pared_sur(filas: PackedStringArray, dist: int) -> Vector2i:
	var cy: int = filas.size() / 2
	for dy in range(filas.size()):
		for y in [cy + dy, cy - dy]:
			if y < 1 or y + dist >= filas.size():
				continue
			for x in range(4, filas[y].length() - 4):
				var ok: bool = filas[y + dist][x] == "#"
				for k in range(0, dist):
					ok = ok and filas[y + k][x] != "#" and filas[y + k][x] != " " and filas[y + k][x] != "~"
				for dx in range(-4, 5):
					ok = ok and filas[y][x + dx] != "#" and filas[y][x + dx] != "~"
				if ok:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


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
