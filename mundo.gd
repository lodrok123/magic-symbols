extends "res://nivel_base.gd"

## MUNDO: EL NIVEL GRANDE DE PRUEBAS (40 x 34).
##
## Hereda de nivel_base.gd, el motor común: suelos, agua, puente de rayo, barrera de fuego,
## antorchas, baldosas de runas, goblins, puerta final, mochila, botín, puestos, alquimista,
## encargos, pantalla de muerte... Aquí solo están el PLANO y los datos de este nivel.
##
## RECORRIDO (el plano está al final del archivo):
##   ALDEA (suroeste) ..... inicio, librera (n), alquimista (Q), guardabosques (M), dummy (D)
##                           y los glifos de AGUA + BARRERA en las losas (a)
##   PRADO (noroeste) ..... barrera de fuego (B) que se apaga con agua, setos que arden,
##                           baldosa (p) y totem de rayo (i) que tiende el puente (b)
##   BOSQUE (sur) ......... campamento goblin (W, A, A) y ingredientes (s seta, f flor, q raíz)
##   RÍO + ESTE ........... losas de VIENTO (w): el viento atraviesa las fogatas (F) y lleva
##                           el fuego a las antorchas (T) de la plataforma al otro lado del agua
##   FUERTE (sureste) ..... más goblins; al fondo, la puerta final (X) y la salida (E)
##
## LETRAS NUEVAS DEL PLANO (ver nivel_base.gd):  n puesto librera · Q puesto alquimista · M guardabosques · D dummy · s seta · f flor ·
## q raíz · O fogata del encargo de apagar fuego.


const MAPA_MUNDO: PackedStringArray = [
	"########################################",
	"#.............#...........~......#######",
	"#.............#...........~......~~gggg#",
	"#....##....#..#.....p.#...~.s....~~gggg#",
	"#.......z.....#...s.......~...w.F~~Tggg#",
	"#..z..........#........f..~..#w.F~~Tggg#",
	"#.............B...........~.#.w.F~~Tggg#",
	"#.............B...##......~..#w.F~~Tggg#",
	"#.......##....B...........~...w.F~~Tggg#",
	"#..........z..B....q......~.O....~~gggg#",
	"#.............B.........i.b......~~gggg#",
	"#.............#...........~......~~gggg#",
	"#........M....#......s....~..M...~~gggg#",
	"#...z.........#..f..#.....~....s.~~gggg#",
	"#.............#.......q...~......#######",
	"#.........z...#...........~..###########",
	"#.............#...........~............#",
	"#####..###################~.......z....#",
	"#...........#........f....~....h.......#",
	"#....aa.....#.s....s..q...~.........A..#",
	"#.......#...#.............~..l.##......#",
	"#..M.....#..#.q..##..W.f..~............#",
	"#...........#...s.........~......W...s.#",
	"#...........#.........s...~..#.........#",
	"#.#....n..Q.#f....q.......~..........#.#",
	"#...........#....f......A.~........l.#.#",
	"#...............#.........~...A...#....#",
	"#.....................##..~............#",
	"#..S........#..D....s...q.~.....####X###",
	"#...........#.............~.....#......#",
	"#.......##..#...q.A....s..~.....#...E..#",
	"#..#........#..s...f......~.....#......#",
	"#...........#.............~.....#......#",
	"########################################",
]

const CENTRO_BOSQUE: Vector2i = Vector2i(21, 24)

## [celda de la baldosa de guardado]
const GUARDADOS_MUNDO: Array = [Vector2i(5, 26), Vector2i(15, 24), Vector2i(10, 5),
	Vector2i(22, 8), Vector2i(28, 13), Vector2i(28, 19)]
## [objeto, columna, fila, cantidad]
const SUELO_MUNDO: Array = [
	["pocion", 7, 27, 1], ["pocion", 22, 24, 1], ["pocion", 24, 3, 1], ["pocion", 30, 22, 1],
	["oro", 2, 26, 5], ["oro", 11, 13, 5], ["oro", 23, 15, 5], ["oro", 20, 29, 5],
	["oro", 34, 10, 5], ["oro", 36, 24, 5],
]
const EMPUJABLES_MUNDO: Array = [["tierra", 17, 3], ["hielo", 21, 6]]

func _mapa() -> PackedStringArray:
	return MAPA_MUNDO


func _lista_props() -> Array:
	var l: Array = []
	var decor: Array = ["bush", "fern", "flowers", "lavender", "grass_clump", "groundcover",
		"rocks", "bush_berry", "cairn_deco"]
	var m: PackedStringArray = _mapa()
	for y in range(m.size()):
		for x in range(m[y].length()):
			if m[y][x] == "." and _hash(x, y, 3) % 9 == 0:
				l.append([decor[_hash(x, y, 5) % decor.size()], x, y])
	l.append(["signpost", 7, 22])
	l.append(["signpost", 27, 12])
	l.append(["signpost", 13, 27])
	return l


func _celdas_guardado() -> Array:
	return GUARDADOS_MUNDO


func _suelo_objetos() -> Array:
	return SUELO_MUNDO


func _lista_empujables() -> Array:
	return EMPUJABLES_MUNDO


func _definir_encargos() -> void:
	var prado: Npc = _rangers.get(Vector2i(9, 12))
	var este: Npc = _rangers.get(Vector2i(29, 12))
	var aldea: Npc = _rangers.get(Vector2i(3, 21))
	if prado != null:
		misiones.definir(prado, "Quemar 3 matorrales del prado", "quemar", 3,
			["Los matorrales secos están invadiendo el prado.",
			"Préndeles fuego, con tres bastará. Pero cuidado: el fuego se contagia."],
			{"centro": prado.global_position, "radio": 560.0})
	if este != null and _fogata_encargo != null:
		misiones.definir(este, "Apagar la fogata del prado", "apagar", 1,
			["Esa fogata se ha descontrolado y amenaza con quemarlo todo.",
			"Apágala con agua antes de que vaya a más."],
			{"fogata": _fogata_encargo})
	if aldea != null:
		misiones.definir(aldea, "Acabar con 3 goblins del bosque", "matar", 3,
			["Hay un campamento de goblins en el bosque, al este de la aldea.",
			"Acaba con tres de ellos. El guerrero te perseguirá; los arqueros prefieren mantener la distancia.",
			"Usa la debilidad de cada uno: el rombo de color sobre su cabeza te dice qué elemento los castiga."],
			{"centro": _at(CENTRO_BOSQUE), "radio": 560.0})
