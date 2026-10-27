extends SceneTree

## CAPACIDAD DEL LIBRO (27/10, Pablo): el primer libro de la historia admite 4 ELEMENTOS y 6 GLIFOS en su página derecha; se empieza
## con menos y se ganan jugando. Sin ventana: `tools\prueba_una.cmd prueba_capacidad_libro`.
##   1. Las progresiones de historia (nivel1, bosque, barrera) fijan 4 y 6; los bancos de pruebas (todo, pruebas), sin límite.
##   2. Con el libro lleno, el quinto elemento y el séptimo glifo no entran (tampoco por `conseguir_sigil`, que no lo deja pendiente de escribir).
##   3. La página derecha pinta como mucho la capacidad y deja cerradas las casillas de la lámina que pasan de ella.
##   4. «Añadir todos» de la paleta de pruebas (`activate_all`) quita el tope.

var fallos: int = 0

## Un grimorio de mentira para que la leyenda sepa de qué color es cada elemento (lo único que pide del Spellcaster).
const CASTER_FALSO: String = """extends Node
const G = preload("res://magia/grimorio.gd")
var GESTURE_TO_RUNE: Dictionary = G.GESTURE_TO_RUNE
var feedback_until: float = 0.0
var rune_database: Dictionary = {
	Runes.Type.SHAPE_TRIANGLE: G.FIRE_RUNE, Runes.Type.SHAPE_CIRCLE: G.WATER_RUNE, Runes.Type.SHAPE_LINES: G.WIND_RUNE,
	Runes.Type.SHAPE_ARC: G.EARTH_RUNE, Runes.Type.ELEMENT_LIGHTNING: G.LIGHTNING_RUNE, Runes.Type.ELEMENT_ICE: G.ICE_RUNE,
}
"""

## El libro de verdad, pero apuntando lo que pintaría en vez de pintarlo (así se puede llamar fuera de `_draw`).
const LIBRO_CONTADO: String = """extends "res://presentacion/ui/spellbook.gd"
var pintados: Array = []
var cerradas: Array = []
func _draw_legend_slot(slot: int, glyph: Texture2D, label: String, ink: Color, known: bool, angle: float = 0.0, sello: bool = false) -> void:
	pintados.append([sello, label])
func _draw_legend_cerradas() -> void:
	cerradas = [(_libro().get("leyenda_sellos", []) as Array).size() - casillas_abiertas(true), (_libro().get("leyenda", []) as Array).size() - casillas_abiertas(false)]
"""


func _init() -> void:
	Estado.nuevo()
	# 1 · Qué fija cada progresión
	for p in ["nivel1", "bosque", "barrera"]:
		Lanzador3D.aplicar_progresion(p)
		_ok(Repertoire.max_elementos == 4 and Repertoire.max_glifos == 6, "«%s» fija la capacidad del primer libro: 4 elementos y 6 glifos (%d, %d)" % [p, Repertoire.max_elementos, Repertoire.max_glifos])
	for p in ["todo", "pruebas"]:
		Lanzador3D.aplicar_progresion(p)
		_ok(Repertoire.max_elementos == 0 and Repertoire.max_glifos == 0, "«%s» no tiene límite" % p)
		_ok(Repertoire.active_elements().size() == 6, "«%s» sigue con sus 6 elementos" % p)

	# 2 · El libro lleno no admite más
	Lanzador3D.aplicar_progresion("bosque")
	for e in ["agua", "tierra", "hielo"]:
		_ok(Repertoire.unlock_element(e), "bosque: se gana %s" % e)
	_ok(Repertoire.active_elements().size() == 4 and not Repertoire.cabe_elemento(), "bosque: 4 elementos y el libro está lleno de elementos")
	_ok(not Repertoire.unlock_element("rayo") and not Repertoire.element_active("rayo"), "bosque: el quinto elemento (rayo) no entra")
	for g in ["barrera", "linea", "altura", "levitacion", "repeticion"]:
		_ok(Repertoire.unlock_sigil(g), "bosque: se gana %s" % g)
	_ok(Repertoire.active_sigils().size() == 6 and not Repertoire.cabe_glifo(), "bosque: 6 glifos y el libro está lleno de glifos")
	_ok(not Repertoire.unlock_sigil("rebote") and not Repertoire.sigil_active("rebote"), "bosque: el séptimo glifo (rebote) no entra")
	_ok(not Repertoire.conseguir_sigil("raido") and not Repertoire.tomar_por_escribir().has("raido"), "bosque: un glifo de cofre con el libro lleno no entra ni queda pendiente de escribir")
	_ok(not Repertoire.unlock_sigil("flecha"), "bosque: lo que ya tienes sigue sin contar como nuevo")

	# 3 · La página derecha
	var caster: Node = _nodo(CASTER_FALSO)
	caster.add_to_group("spellcaster")
	root.add_child(caster)
	var libro: Control = _nodo(LIBRO_CONTADO)
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	Repertoire.libro = "bosque"
	libro.call("_draw_legend")
	var p: Array = libro.get("pintados")
	_ok(_cuenta(p, true) == 4 and _cuenta(p, false) == _con_dibujo(), "lleno: la página derecha pinta los 4 elementos y los %d de los 6 glifos que tienen dibujo (%d, %d; «altura» aún no tiene glifo en Sigils.GLYPHS)" % [_con_dibujo(), _cuenta(p, true), _cuenta(p, false)])
	_ok(libro.get("cerradas") == [2, 3], "y deja cerradas 2 casillas de elemento y 3 de glifo de la lámina (6 y 9): %s" % str(libro.get("cerradas")))
	Lanzador3D.aplicar_progresion("bosque")
	libro.set("pintados", [])
	libro.call("_draw_legend")
	p = libro.get("pintados")
	_ok(_cuenta(p, true) == 1 and _cuenta(p, false) == 1 and libro.get("cerradas") == [2, 3], "al empezar el bosque (fuego + flecha): 1 y 1 pintados, y las cerradas son las mismas (lo abierto es la capacidad, no lo ganado)")
	Lanzador3D.aplicar_progresion("pruebas")
	libro.set("pintados", [])
	libro.call("_draw_legend")
	p = libro.get("pintados")
	_ok(_cuenta(p, true) == 6 and _cuenta(p, false) == _con_dibujo() and libro.get("cerradas") == [0, 0], "pruebas: 6 elementos y todos los glifos con dibujo pintados, ninguna casilla cerrada (%d, %d, %s)" % [_cuenta(p, true), _cuenta(p, false), str(libro.get("cerradas"))])

	# 4 · La paleta de pruebas quita el tope
	Lanzador3D.aplicar_progresion("bosque")
	Repertoire.activate_all()
	_ok(Repertoire.max_elementos == 0 and Repertoire.max_glifos == 0 and Repertoire.active_elements().size() == GestureLibrary.ELEMENTS.size(), "«Añadir todos» quita la capacidad y activa todo")

	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)


func _nodo(fuente: String) -> Node:
	var s := GDScript.new()
	s.source_code = fuente
	s.reload()
	return s.new()


func _cuenta(pintados: Array, sellos: bool) -> int:
	var n: int = 0
	for x in pintados:
		if bool(x[0]) == sellos:
			n += 1
	return n


func _ok(bien: bool, texto: String) -> void:
	if bien:
		print("OK    " + texto)
	else:
		fallos += 1
		print("FALLO " + texto)


## Glifos activos que la leyenda puede pintar (los que tienen dibujo), hasta la capacidad.
func _con_dibujo() -> int:
	var n: int = 0
	for g in Repertoire.active_sigils():
		if Sigils.GLYPHS.has(g):
			n += 1
	return n if Repertoire.max_glifos <= 0 else mini(n, Repertoire.max_glifos)
