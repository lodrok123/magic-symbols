extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LA TIERRA EN EL JUEGO (rocas estilizadas, 4/11). NECESITA VENTANA. Carga el Bosque 01 v01 con la cámara DEL JUEGO y lanza tierra (proyectil, muro, pilar, barrera)
## desde el mismo sitio; fotografía el fotograma completo. El aspecto lo decide `VfxTierra.ROCAS_ESTILIZADAS` (const): para sacar el «antes» se pone a false, se repite y se vuelve a true.
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_tierra_en_juego.gd -- [carpeta] [sufijo] [solo_hechizo|*]
## Escribe <carpeta>/tierra_<hechizo>_<sufijo>_<t>.png (por defecto docs/capturas/rocas_estilizadas, sufijo «rocas»). Se mira a ojo (no hay `_ok` de aspecto).

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const HECHIZOS: Array = [
	["proyectil", ["flecha"]],
	["muro", ["barrera", "linea_x", "linea_x", "altura"]],
	["barrera", ["barrera", "linea_x", "linea_z", "altura"]],
]
const TIEMPOS: Array = [0.5, 1.2]
const DIR: Vector3 = Vector3(1.0, 0.0, 0.0)

var _dir: String = "res://docs/capturas/rocas_estilizadas"
var _suf: String = "rocas"
var _solo_h: String = ""


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "":
		_suf = a[1]
	if a.size() > 2 and a[2] != "*":
		_solo_h = a[2]
	DirAccess.make_dir_recursive_absolute(_dir if not _dir.begins_with("res://") else ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro de 9 × 5 casillas llano (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	await avanzar_s(2.0)
	print("ROCAS_ESTILIZADAS = ", VfxTierra.ROCAS_ESTILIZADAS, " · hay_modelo(bloque_tierra_0) = ", VfxTierra.hay_modelo("bloque_tierra_0"), " · terron_0 = ", VfxTierra.hay_modelo("terron_0"))
	for hz in HECHIZOS:
		if _solo_h != "" and _solo_h != String(hz[0]):
			continue
		colocar_jugador(c)
		await avanzar_s(0.3)
		await _una(hz)
	print("escrito ", _dir)


func _una(hz: Array) -> void:
	var id: String = String(hz[0])
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("tierra")
	for g in (hz[1] as Array):
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	var origen: Vector3 = jugador.position
	if (hz[1] as Array).has("barrera"):
		origen += DIR * Terreno3D.casilla * 2.0
	var salio: bool = lanzador.lanzar_pagina_ya(0, origen, DIR, false)
	_ok("1 tierra · %s: sale el hechizo" % id, salio)
	await avanzar(2)
	if id == "muro" or id == "barrera":
		colocar_jugador(celda_jugador() + Vector2i(2, 0))      # la cámara sigue a la jugadora: se acerca para que el muro quede en el centro de la foto
	var t_ant: float = 0.0
	for t in TIEMPOS:
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		_ocultar_ui(root)
		var ruta: String = _dir.path_join("tierra_%s_%s_%03d.png" % [id, _suf, int(round(float(t) * 100.0))])
		root.get_viewport().get_texture().get_image().save_png(ruta)
		print("CAPTURA ", ruta)
	await avanzar_s(4.0)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _buscar_claro() -> Vector2i:
	for y in range(4, 38):
		for x in range(2, 40):
			var ok: bool = true
			var base: float = Terreno3D.y_pies(Vector2i(x, y))
			for dx in range(-1, 10):
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
