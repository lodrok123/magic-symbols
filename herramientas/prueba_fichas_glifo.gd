extends SceneTree
## FICHAS DE GLIFO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4 H5, H6 y H8) sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_fichas_glifo.gd
## Comprueba: que cada id jugable (los seis elementos y todo glifo de los kits del Lanzador más los de cofre) tiene ficha completa (verbo, UNA frase, bases); que la familia cuadra con
## `cuenta_dano` de Sigils; que el TÍTULO de la lámina es el nombre de la runa del futhark (altura → Tiwaz, viento → Uruz); que la lámina NO lleva diagramas, familia, «Vale con» ni pie de runa; que cada
## frase es una sola y no nombra otras runas ni bases; que `LaminaGlifo.mostrar` funciona con cada id y `cerrar` la libera; que con `cierre_propio` pausa el árbol; y que el libro rojo lee lo mismo.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Todos los ids jugables, sacados de los datos (no de FichasGlifo, para que la prueba pueda cazar uno que falte): elementos, glifos de todos los kits y los que dan los cofres.
func _jugables() -> Array:
	var salida: Array = []
	for e in GestureLibrary.ELEMENTS:
		salida.append(String(e))
	var prog: Dictionary = load("res://magia/lanzador_3d.gd").PROGRESIONES
	for kit in prog:
		for g in (prog[kit]["glifos"] as Array):
			if not salida.has(String(g)):
				salida.append(String(g))
	salida.erase("levitacion")                         # 24/11: comparte la ficha de altura (Sigils.ALIAS_V2), no tiene la suya
	for g in ["permanencia", "raido"]:                  # los dan cofres (Puzle3D `glifo=`)
		if not salida.has(g):
			salida.append(g)
	return salida


func _esperar_liberada(l: Node, max_s: float = 3.0) -> bool:
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(l) and float(Time.get_ticks_msec() - t0) / 1000.0 < max_s:
		await process_frame
	return not is_instance_valid(l)


func _textos(raiz: Node) -> Array:
	var s: Array = []
	for n in raiz.find_children("*", "Label", true, false):
		s.append((n as Label).text)
	return s


## El título que debe llevar la lámina, escrito AQUÍ a mano (no sale de LaminaGlifo: así la prueba caza un cambio): el nombre de la runa del futhark.
const TITULOS: Dictionary = {
	"fuego": "Kenaz", "agua": "Laguz", "tierra": "Mannaz", "viento": "Uruz", "rayo": "Sowilo", "hielo": "Naudiz",
	"flecha": "Eihwaz", "linea": "Isa", "altura": "Tiwaz", "levitacion": "Tiwaz", "pulso": "Gebo", "permanencia": "Algiz", "rebote": "Dagaz",
	"buscar": "Ansuz", "repeticion": "Fehu", "retorno": "Jera", "barrera": "Ingwaz", "raido": "Raido", "perforar": "Thurisaz", "suelo": "Berkana",
	"retardo": "Carga",                 # ⧖ no es del futhark (no está en la biblia): el título es su nombre visible
}
## La frase de tierra la escribió Pablo (24/11) y habla de muros a propósito: es lo que construye, no una combinación.
const EXCEPCIONES_FRASE: Dictionary = {"tierra": ["muro"]}
const FRASES_PROHIBIDAS: PackedStringArray = ["bola", "barrera", "flecha", "haz", "bloque", "muro", "chorro", "ᛇ", "ᛜ", "ᛏ", "ᚱ", "ᛁ", "Con ", "con "]


func _nombre_de(id: String) -> String:
	return String(TITULOS.get(id, ""))


func _initialize() -> void:
	await process_frame
	var jugables: Array = _jugables()
	_ok("0 hay al menos 20 ids jugables", jugables.size() >= 20, str(jugables.size()))
	var ids: Array = FichasGlifo.ids()
	_ok("1 FichasGlifo.ids() cubre los jugables y nada más", ids.size() == FichasGlifo.FICHAS.size() and jugables.all(func(i): return ids.has(i)), "%d ids" % ids.size())
	var orden_ok: bool = true
	var ultimo: int = 0
	var rango: Dictionary = {"sello": 0, "forma": 1, "potencia": 2}
	for i in ids:
		var r: int = int(rango[FichasGlifo.familia(String(i))])
		if r < ultimo:
			orden_ok = false
		ultimo = r
	_ok("1 ids() va ordenado: sellos, forma, potencia", orden_ok)
	for i in jugables:
		var id: String = String(i)
		var f: Dictionary = FichasGlifo.ficha(id)
		_ok("2 %s: verbo, frase y bases no vacíos, y sin campo `demo`" % id, not f.is_empty() and String(f["verbo"]) != "" and String(f["frase"]) != "" and String(f["bases"]) != "" and not f.has("demo"))
		var fr: String = String(f["frase"])
		_ok("2 %s: la frase es UNA sola («%s»)" % [id, fr], fr.ends_with(".") and fr.count(".") == 1 and fr.count("?") == 0 and fr.count(";") == 0 and fr.length() <= 50)
		var mala: String = ""
		for p in FRASES_PROHIBIDAS:
			if fr.contains(p) and not (EXCEPCIONES_FRASE.get(id, []) as Array).has(p):
				mala = p
		_ok("2 %s: la frase no nombra otras runas ni bases%s" % [id, "" if mala == "" else " (lleva «%s»)" % mala], mala == "")
		var fam: String = FichasGlifo.familia(id)
		if GestureLibrary.ELEMENTS.has(id):
			_ok("3 %s es sello" % id, fam == "sello" and FichasGlifo.es_sello(id))
		else:
			var clave: String = "linea_x" if id == "linea" else Sigils.glifo_v2(id)
			_ok("3 %s: familia %s cuadra con cuenta_dano (%s)" % [id, fam, str(Sigils.cuenta_dano(clave))], fam == ("potencia" if Sigils.cuenta_dano(clave) else "forma") and not FichasGlifo.es_sello(id))
	_ok("3 un id sin ficha da ficha vacía", FichasGlifo.ficha("nada").is_empty())

	# La lámina, para cada id.
	var barra: Node = Node.new()
	root.add_child(barra)
	for i in jugables:
		var id: String = String(i)
		var l: LaminaGlifo = LaminaGlifo.mostrar(barra, id, true, false)
		await process_frame
		await process_frame
		var tx: Array = _textos(l)
		_ok("4 %s: la lámina lleva el nombre «%s» y la frase" % [id, _nombre_de(id)], tx.has(_nombre_de(id)) and tx.has(FichasGlifo.frase(id)))
		_ok("4 %s: rótulo %s" % [id, "NUEVO SELLO" if FichasGlifo.es_sello(id) else "NUEVA RUNA"], tx.has("NUEVO SELLO" if FichasGlifo.es_sello(id) else "NUEVA RUNA"))
		var n_diag: int = l.find_children("Diagrama*", "", true, false).size()
		_ok("4 %s: sin diagramas" % id, n_diag == 0 and not ResourceLoader.exists("res://presentacion/ui/diagrama_glifo.gd"))
		var cc: String = "|".join(tx)
		_ok("4 %s: sin etiqueta de familia, «Vale con» ni pie de runa" % id, not cc.contains("FORMA ·") and not cc.contains("POTENCIA ·") and not cc.contains("SELLO ·") and not cc.contains("Vale con") and not cc.contains("·  eihwaz") and l.find_child("PieRuna", true, false) == null and l.find_child("Familia", true, false) == null and l.find_child("ValeCon", true, false) == null)
		_ok("4 %s: el verbo «%s» sale aunque coincida con el título" % [id, FichasGlifo.verbo(id)], tx.has(FichasGlifo.verbo(id)))
		var carta: Control = l.find_child("Carta", true, false) as Control
		_ok("4 %s: tarjeta baja (≈1000×400)" % id, carta != null and carta.size.x <= 1000.0 and carta.size.y <= 420.0)
		l.fijar_tiempo(0.4)
		await process_frame
		l.fijar_tiempo(1.4)
		await process_frame
		l.cerrar()
		_ok("4 %s: cerrar() la libera" % id, await _esperar_liberada(l))
	var l2: LaminaGlifo = LaminaGlifo.mostrar(barra, "flecha", false, false)
	await process_frame
	_ok("4 en consulta el rótulo es «RUNA»", _textos(l2).has("RUNA"))
	l2.cerrar()
	await _esperar_liberada(l2)
	var l3: LaminaGlifo = LaminaGlifo.mostrar(barra, "agua", false, false)
	await process_frame
	_ok("4 en consulta de un sello el rótulo es «SELLO»", _textos(l3).has("SELLO"))
	l3.cerrar()
	await _esperar_liberada(l3)

	# La frase se escribe letra a letra y se completa de golpe.
	var l4: LaminaGlifo = LaminaGlifo.mostrar(barra, "barrera", true, false)
	await process_frame
	_ok("5 la frase empieza a medias", l4.find_child("Frase", true, false) != null and not l4.texto_completo())
	l4.completar_texto()
	_ok("5 completar_texto() la deja entera", l4.texto_completo())
	l4.cerrar()
	await _esperar_liberada(l4)

	# Cierre propio: pausa y al cerrar la quita.
	_ok("6 antes: el árbol no está en pausa", not paused)
	var l5: LaminaGlifo = LaminaGlifo.mostrar(barra, "fuego", true, true)
	await process_frame
	_ok("6 con cierre_propio pausa el árbol", paused)
	_ok("6 y enseña su propio «Continuar»", l5.find_child("Continuar", true, false) != null)
	var cerrada: Array = [false]
	l5.cerrada.connect(func(): cerrada[0] = true)
	await create_timer(0.3, true, false, true).timeout            # pasa la guarda de la pulsación que la abrió
	l5._pulsar()                                                   # 1.ª pulsación: completa el texto
	_ok("6 la 1.ª pulsación completa el texto y no cierra", l5.texto_completo() and not l5._cerrando)
	l5._pulsar()
	_ok("6 la 2.ª pulsación cierra", await _esperar_liberada(l5) and cerrada[0])
	_ok("6 al cerrar quita la pausa", not paused)
	var l6: LaminaGlifo = LaminaGlifo.mostrar(barra, "agua", true, true)
	await process_frame
	var estaba: bool = paused
	l6.queue_free()
	await process_frame
	await process_frame
	_ok("6 si se libera por fuera también quita la pausa", estaba and not paused)
	var l7: LaminaGlifo = LaminaGlifo.mostrar(barra, "flecha", true, false)
	await process_frame
	_ok("6 sin cierre_propio no pausa", not paused)
	l7.cerrar()
	await _esperar_liberada(l7)

	# El libro rojo lee de FichasGlifo.
	for i in jugables:
		var id: String = String(i)
		var fi: Array = LibroRojo.ficha_de(id)
		_ok("7 libro rojo %s: verbo, frase y bases son los de FichasGlifo" % id, LibroRojo.verbo_de(id) == FichasGlifo.verbo(id) and String(fi[0]) == FichasGlifo.frase(id) and String(fi[1]) == FichasGlifo.bases(id))
	_ok("7 FichasGlifo ya no tiene frase_corta ni demo", not (load("res://nucleo/fichas_glifo.gd") as GDScript).get_script_method_list().any(func(m): return m["name"] in ["frase_corta", "demo"]))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
