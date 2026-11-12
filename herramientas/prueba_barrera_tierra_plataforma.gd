extends "res://herramientas/escenario_base.gd"
## godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_barrera_tierra_plataforma.gd
## 12/11/2026: una BARRERA de tierra (sello tierra + ᛝ sola = muro) apuntada a una casilla con un ESCALÓN (tierra sola) o un PUENTE (ᛝ + ᛁ) no
## se puede levantar ahí (`construir_tierra` no construye encima de una plataforma). Antes `rechazo_de_construccion` dejaba pasar toda barrera:
## `lanzar_pagina_ya` decía que se había lanzado, se cobraba tinta y recarga y no aparecía nada. Ahora se rechaza ANTES del cobro, con su aviso.
## Control: la misma barrera en suelo libre sí se lanza y levanta su tierra.

var _pagina: int = 0


func _escenario() -> void:
	await cargar()
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 0
	Repertoire.aim_with_mouse = true
	var ancla: Vector2i = _buscar_sitio()
	_ok("0 hay cinco casillas libres y llanas seguidas", ancla != Vector2i(-1, -1))
	if ancla == Vector2i(-1, -1):
		return
	var dir := Vector3.RIGHT
	colocar_jugador(ancla - Vector2i(2, 0))
	await avanzar(2)

	# 1. el escalón (tierra sola) en `ancla`
	_preparar([])
	_ok("1 se lanza el escalón", lanzador.lanzar_pagina_ya(_pagina, _centro(ancla), dir) and Terreno3D.plataformas_tierra.has(ancla))
	await avanzar(2)
	_barrera_rechazada("escalón", ancla, dir)

	# 2. el puente (ᛝ + ᛁ) en ancla+2 .. ancla+3
	var puente: Vector2i = ancla + Vector2i(2, 0)
	colocar_jugador(puente - Vector2i(2, 0) + Vector2i(0, 1))
	await avanzar(2)
	_preparar(["barrera", "linea_x"])
	_ok("2 se lanza el puente", lanzador.lanzar_pagina_ya(_pagina, _centro(puente), dir) and Terreno3D.plataformas_tierra.has(puente), "%s · %s" % [str(Terreno3D.plataformas_tierra.keys()), lanzador.feedback_text])
	await avanzar(2)
	_barrera_rechazada("puente", puente, dir)

	# 3. control: la misma barrera en suelo libre (lejos de las plataformas) sí se lanza y levanta tierra
	var libre: Vector2i = ancla + Vector2i(0, 3)
	colocar_jugador(libre - Vector2i(2, 0))
	await avanzar(2)
	var h: Hechizo = _preparar(["barrera"])
	var libres: bool = true
	for c in Lanzador3D.GeometriaV2.celdas(h.geo(), Vector2(_centro(libre).x, _centro(libre).z), Vector2(dir.x, dir.z), Terreno3D.casilla):
		libres = libres and lanzador.puede_construir_en(c) == "" and not Terreno3D.plataformas_tierra.has(c)
	if libres:
		var antes: int = lanzador._bloques.size()
		_ok("3 la barrera en suelo libre se lanza", lanzador.lanzar_pagina_ya(_pagina, _centro(libre), dir))
		await avanzar(3)
		_ok("3 y levanta su tierra", lanzador._bloques.size() > antes, "bloques %d -> %d" % [antes, lanzador._bloques.size()])
	else:
		_aviso("3 no hay suelo libre para el control de la barrera", str(libre))


## La barrera (tierra + ᛝ) apuntada a la plataforma `c`: no se lanza, no cobra y avisa.
func _barrera_rechazada(que: String, c: Vector2i, dir: Vector3) -> void:
	var h: Hechizo = _preparar(["barrera"])
	_ok("%s: la receta es una barrera de tierra (no una plataforma)" % que, h != null and h.solidez > 0.0 and not h.es_plataforma_tierra())
	var tinta: float = jugador.tinta.actual
	var bloques: int = lanzador._bloques.size()
	lanzador.feedback_text = ""
	var lanzo: bool = lanzador.lanzar_pagina_ya(_pagina, _centro(c), dir)
	_ok("%s: la barrera NO se lanza sobre la plataforma" % que, not lanzo)
	_ok("%s: no cobra tinta ni recarga" % que, is_equal_approx(jugador.tinta.actual, tinta) and float(lanzador.cooldown_left[_pagina]) <= 0.0, "tinta %.2f -> %.2f, recarga %.2f" % [tinta, jugador.tinta.actual, float(lanzador.cooldown_left[_pagina])])
	_ok("%s: avisa del motivo («%s»)" % [que, lanzador.feedback_text], lanzador.feedback_text.contains("plataforma"))
	_ok("%s: no levanta tierra ni deja la plataforma sin su sitio" % que, lanzador._bloques.size() == bloques and Terreno3D.plataformas_tierra.has(c))


## Página 0 con el sello de tierra y los glifos pedidos; devuelve el Hechizo preparado (y deja el modo de lanzar cerrado).
func _preparar(glifos: Array) -> Hechizo:
	if lanzador.modo_lanzar:
		lanzador._cancelar_modo()
	lanzador.cooldown_left[_pagina] = 0.0
	jugador.tinta.actual = jugador.tinta.maxima
	lanzador.select_page(_pagina)
	lanzador.clear_sequence()
	lanzador.place_element("tierra")
	var sectores: Array = [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT]
	for i in glifos.size():
		lanzador.add_sigil(sectores[i], String(glifos[i]))
	if not lanzador._preparar_pagina(_pagina):
		return null
	var h: Hechizo = lanzador._preparado.get("hechizo") as Hechizo
	lanzador._preparado = {}
	return h


func _centro(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


## Casilla con cinco libres, llanas y a la misma altura a +X y, tres más abajo (+Z), otra fila igual (el control); con sitio a -X para la jugadora.
func _buscar_sitio() -> Vector2i:
	var lado: int = Terreno3D.lado_del_mapa()
	for z in range(2, lado - 6):
		for x in range(3, lado - 7):
			var c := Vector2i(x, z)
			var bien: bool = true
			for dz in [0, 1, 2, 3, 4]:
				for dx in range(-2, 5):
					var cc: Vector2i = c + Vector2i(dx, dz)
					if lanzador.puede_construir_en(cc) != "" or Terreno3D.altura_en(cc) != 0 or Terreno3D.es_agua(cc) or not is_equal_approx(Terreno3D.y_pies(cc), Terreno3D.y_pies(c)):
						bien = false
						break
				if not bien:
					break
			if bien:
				return c
	return Vector2i(-1, -1)
