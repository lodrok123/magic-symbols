extends SceneTree
## H16 · NOMBRE DE CADA HECHIZO (22/11, PLAN_HECHIZOS junto a B5) sin ventana. Lo escribe la sesión HECHIZOS.
##   godot --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_nombre_hechizo.gd
## Comprueba: el nombre automático de varias recetas (forma + elemento + rasgo, concordado); renombrar, recortar y vaciar; guardar y cargar el nombre propio (Grimorio y
## `Repertoire.a_dic/desde_dic`, con una partida vieja sin la clave); y el tamaño del rótulo del HUD (grande al cambiar de página, luego pequeño).

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _h(elem: String, glifos: Dictionary, orden: Array = []) -> Hechizo:
	var en: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth"}
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % en[elem]) as RuneData, glifos, 1.0, false, orden)


func _grimorio() -> Grimorio:
	var g: Grimorio = (load("res://magia/grimorio.gd") as GDScript).new() as Grimorio
	root.add_child(g)
	return g


func _initialize() -> void:
	await process_frame
	# 1 · Nombres automáticos.
	var casos: Array = [
		["fuego", {"flecha": 1}, [], "Flecha de fuego"],
		["fuego", {"flecha": 2}, [], "Flecha de fuego larga"],
		["fuego", {"flecha": 1, "repeticion": 1}, ["repeticion", "flecha"], "Flecha de fuego doble"],
		["fuego", {"flecha": 1, "retorno": 1}, [], "Flecha de fuego que vuelve"],
		["agua", {"flecha": 1, "raido": 1}, [], "Flecha de agua que pulsa"],
		["agua", {"barrera": 1}, [], "Escudo de agua"],
		["fuego", {"barrera": 1}, [], "Escudo de fuego"],
		["agua", {"barrera": 1, "flecha": 1}, [], "Muro de agua que avanza"],
		["fuego", {"linea_x": 1}, [], "Chorro de fuego"],
		["tierra", {"suelo": 1}, [], "Plataforma de tierra"],
		["fuego", {"suelo": 1}, [], "Trampa de fuego"],
		["fuego", {"retorno": 1, "repeticion": 1}, [], "Orbes de fuego"],
		["tierra", {"barrera": 1}, [], "Muro de tierra"],
		["fuego", {"barrera": 1, "linea_x": 3}, [], "Muro de fuego"],
	]
	for c in casos:
		var n: String = NombreHechizo.automatico(_h(String(c[0]), c[1], c[2]))
		_ok("1 %s %s → «%s»" % [c[0], str(c[1]), c[3]], n == String(c[3]), "«%s»" % n)
	_ok("1 sin hechizo no hay nombre", NombreHechizo.automatico(null) == "")
	var largo_max: int = 0
	for c in casos:
		largo_max = maxi(largo_max, NombreHechizo.automatico(_h(String(c[0]), c[1], c[2])).split(" ").size())
	_ok("1 todos son cortos (como mucho 5 palabras contando «de»)", largo_max <= 5, str(largo_max))

	# 2 · Renombrar y vaciar en el Grimorio, y guardar en Repertoire.paginas.
	var paginas0: Array = Repertoire.paginas.duplicate(true)
	Repertoire.activate_all()
	Repertoire.paginas = [{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": ["barrera"]}, {"elemento": "", "glifos": []}]
	var g: Grimorio = _grimorio()
	await process_frame
	_ok("2 la página 1 se llama sola «Flecha de fuego»", g.nombre_pagina(0) == "Flecha de fuego", "«%s»" % g.nombre_pagina(0))
	_ok("2 la página 2 «Escudo de agua» y la 3, vacía, sin nombre", g.nombre_pagina(1) == "Escudo de agua" and g.nombre_pagina(2) == "", "«%s» / «%s»" % [g.nombre_pagina(1), g.nombre_pagina(2)])
	_ok("2 sin renombrar no se guarda ningún nombre (se rehace de la receta)", not (Repertoire.paginas[0] as Dictionary).has("nombre"))
	g.renombrar_pagina(0, "   El mechero de la abuela   ")
	_ok("2 renombrar recorta a %d caracteres y quita espacios" % NombreHechizo.LARGO_MAX, g.nombre_pagina(0) == "El mechero de la a", "«%s»" % g.nombre_pagina(0))
	_ok("2 y queda marcado como propio y guardado en Repertoire.paginas", g.nombre_es_propio(0) and String((Repertoire.paginas[0] as Dictionary).get("nombre", "")) == "El mechero de la a" and bool((Repertoire.paginas[0] as Dictionary).get("nombre_propio", false)))
	_ok("2 el nombre propio se respeta aunque no diga la verdad de la receta", g.nombre_pagina(0) != NombreHechizo.automatico(_h("fuego", {"flecha": 1})))

	# 3 · Guardar y cargar.
	var guardado: String = JSON.stringify(Repertoire.a_dic())
	g.queue_free()
	await process_frame
	Repertoire.paginas = []
	Repertoire.desde_dic(JSON.parse_string(guardado))
	_ok("3 desde_dic (tras JSON) conserva el nombre propio", String((Repertoire.paginas[0] as Dictionary).get("nombre", "")) == "El mechero de la a" and bool((Repertoire.paginas[0] as Dictionary).get("nombre_propio", false)))
	var g2: Grimorio = _grimorio()
	await process_frame
	_ok("3 un Grimorio nuevo lo lee de la partida", g2.nombre_pagina(0) == "El mechero de la a" and g2.nombre_es_propio(0), "«%s»" % g2.nombre_pagina(0))
	_ok("3 y la página 2 sigue con el automático", g2.nombre_pagina(1) == "Escudo de agua" and not g2.nombre_es_propio(1))
	g2.renombrar_pagina(0, "   ")
	_ok("3 vaciar el nombre vuelve al automático y borra la clave guardada", g2.nombre_pagina(0) == "Flecha de fuego" and not g2.nombre_es_propio(0) and not (Repertoire.paginas[0] as Dictionary).has("nombre"), "«%s»" % g2.nombre_pagina(0))
	g2.queue_free()
	await process_frame
	# Una partida vieja (anterior a H16): sin la clave, recibe el automático.
	Repertoire.desde_dic({"paginas": [{"elemento": "agua", "glifos": ["flecha", "flecha"]}]})
	var g3: Grimorio = _grimorio()
	await process_frame
	_ok("3 una partida vieja sin nombre recibe el automático («Flecha de agua larga»)", g3.nombre_pagina(0) == "Flecha de agua larga", "«%s»" % g3.nombre_pagina(0))
	g3.queue_free()
	await process_frame

	# 4 · El rótulo del HUD.
	var Hud: GDScript = load("res://presentacion/ui/page_hud.gd") as GDScript
	_ok("4 al cambiar de página el nombre sale grande (%d) durante %.1f s" % [Hud.TAM_NOMBRE_GRANDE, Hud.T_NOMBRE_GRANDE], Hud.tam_nombre(0.0) == Hud.TAM_NOMBRE_GRANDE and Hud.tam_nombre(Hud.T_NOMBRE_GRANDE) == Hud.TAM_NOMBRE_GRANDE)
	_ok("4 y luego se queda pequeño (%d)" % Hud.TAM_NOMBRE, Hud.tam_nombre(Hud.T_NOMBRE_GRANDE + Hud.T_NOMBRE_ENCOGE + 0.1) == Hud.TAM_NOMBRE)
	var medio: int = Hud.tam_nombre(Hud.T_NOMBRE_GRANDE + Hud.T_NOMBRE_ENCOGE * 0.5)
	_ok("4 se reduce poco a poco, no de golpe", medio < Hud.TAM_NOMBRE_GRANDE and medio > Hud.TAM_NOMBRE, str(medio))

	Repertoire.paginas = paginas0
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
