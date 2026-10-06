extends "res://nivel_base.gd"

## TEST DE JUGABILIDAD: el nivel de la hoja Test_de_jugabilidad.xlsx (23 x 23).
##
## Este archivo es SOLO EL NIVEL: el plano y sus datos. Todo el motor (cómo se construye cada
## letra, el jugador, la interfaz, los sistemas) está en nivel_base.gd, del que hereda.
##
## SE JUEGA CON F6 (ejecutar escena actual) sobre TestJugabilidad.tscn. No toca
## ni el Blockout ni IsoTest: es un nivel aparte que reutiliza las piezas del
## juego (agua, hierba, braseros, puertas, arqueros, el libro de hechizos...).
##
## EL ARTE SALE DE export_godot/ (lo aprobado en el pipeline), NO del pack viejo de
## art/: bloques, árboles y props de terrain/bosque_01 y los personajes de
## characters/ (hero, goblin_warrior, goblin_archer, bookseller_woman,
## ranger_human). Ver CONTRATO_GODOT.md.
##
## EL MAPA ES UN DATO: cambiar el nivel es cambiar letras de MAPA. La leyenda de TODAS las
## letras está al principio de nivel_base.gd. Lo propio de este mapa:
##   - el hueco del muro de la izquierda lo cierra una TELARAÑA (r);
##   - las fuentes de fuego (F) están ANTES del río (columna K): el viento recoge su llama y la
##     lleva por encima del agua hasta las antorchas (T, columna H), que se quedan encendidas;
##   - la librera atiende en su puesto (PUESTO_CELDA) y el alquimista en otro 3 casillas al sur,
##     cada uno con el tendero al norte del mostrador.
##
## LAS CUATRO TAREAS (la puerta final se abre sola al completarlas, y tiene 4 llamas,
## 1 por tarea, que se enciende al completarla):
##   1. Pisar la baldosa de contacto    3. Hablar con un NPC
##   2. Matar a los goblins             4. Encender las antorchas

const MAPA: PackedStringArray = [
	"#######################",
	"#S....#...~~~~.p.~....#",
	"#.....#......~...~....#",
	"#.vv..#......~...~....#",
	"#.vv..ra.....~i..~....#",
	"#.vv..ra.....~~b~~....#",
	"#.....#......B........#",
	"#.....#......B........#",
	"#.....#......B....#####",
	"#.....#......B....#...#",
	"#.....#......B....#...#",
	"################..X..E#",
	"#gggg~~..m........#...#",
	"#gggg~~..w........#...#",
	"#gggT~~F.w...##########",
	"#gggT~~F.w...#........#",
	"#gggT~~F.w...#.......A#",
	"#gggT~~F.w............#",
	"#gggT~~F.w........W...#",
	"#gggg~~..w............#",
	"#gggg~~..w...........A#",
	"#gggg~~..w............#",
	"#######################",
]

## Decorado del bosque repartido por el mapa: [prop, columna, fila]. Generado con una
## semilla fija y comprobando que no corta ningún camino. Los props con cuerpo (caja,
## barril, peñasco, tocón, tronco, cartel) bloquean el paso; el resto es decorado.
const PROPS: Array = [
	["grass_clump", 8, 1],
	["bush_berry", 9, 1],
	["signpost", 2, 2],
	["lavender", 7, 2],
	["bush_berry", 8, 2],
	["flowers", 10, 2],
	["grass_clump", 18, 2],
	["boulder", 20, 2],
	["mushrooms", 10, 3],
	["bush_berry", 16, 3],
	["flowers", 20, 3],
	["rocks", 21, 3],
	["grass_clump", 9, 4],
	["boulder", 11, 4],
	["barrel", 19, 4],
	["bush", 9, 5],
	["fern", 10, 5],
	["groundcover", 18, 5],
	["flowers", 19, 5],
	["barrel", 21, 5],
	["log", 9, 6],
	["rocks", 21, 6],
	["rocks", 2, 7],
	["stump", 4, 7],
	["flowers", 11, 7],
	["barrel", 15, 7],
	["bush", 18, 7],
	["crate", 20, 7],
	["crate", 1, 8],
	["rocks", 5, 8],
	["mushrooms", 8, 8],
	["boulder", 11, 8],
	["mushrooms", 16, 8],
	["lavender", 17, 8],
	["bush", 2, 9],
	["bush_berry", 3, 9],
	["bush", 4, 9],
	["stump", 7, 9],
	["fern", 10, 9],
	["bush", 11, 9],
	["mushrooms", 15, 9],
	["boulder", 17, 9],
	["fern", 19, 9],
	["bush_berry", 20, 9],
	["stump", 2, 10],
	["mushrooms", 4, 10],
	["lavender", 5, 10],
	["mushrooms", 8, 10],
	["crate", 10, 10],
	["bush_berry", 15, 10],
	["fern", 16, 10],
	["groundcover", 16, 11],
	["flowers", 2, 12],
	["fern", 3, 12],
	["log", 12, 12],
	["groundcover", 15, 12],
	["fern", 13, 13],
	["log", 16, 13],
	["barrel", 20, 13],
	["rocks", 12, 15],
	["fern", 14, 15],
	["mushrooms", 16, 15],
	["rocks", 18, 15],
	["lavender", 11, 16],
	["grass_clump", 14, 16],
	["lavender", 11, 17],
	["flowers", 12, 17],
	["groundcover", 15, 17],
	["lavender", 13, 18],
	["lavender", 14, 18],
	["bush_berry", 15, 18],
	["flowers", 12, 19],
	["flowers", 13, 19],
	["grass_clump", 14, 19],
	["mushrooms", 1, 20],
	["stump", 7, 20],
	["groundcover", 11, 20],
	["barrel", 13, 20],
	["log", 15, 20],
	["mushrooms", 1, 21],
	["groundcover", 7, 21],
	["bush", 13, 21],
	["grass_clump", 14, 21],
	["crate", 17, 21],
]


## Botín del suelo: [objeto, columna, fila]. El oro sale de 5 en 5.
const RECOGIBLES: Array = [
	["pocion", 3, 8], ["pocion", 16, 17], ["pocion", 10, 19],
	["oro", 4, 1], ["oro", 8, 3], ["oro", 19, 3], ["oro", 21, 4],
	["oro", 12, 13], ["oro", 20, 16], ["oro", 11, 18], ["oro", 20, 20],
]


## Las baldosas de punto de guardado.
const GUARDADOS: Array = [Vector2i(3, 10), Vector2i(9, 3), Vector2i(14, 12), Vector2i(16, 19)]


## El puesto de la librera (el del alquimista va 3 casillas al sur).
const PUESTO_CELDA: Vector2i = Vector2i(2, 6)


## Bloques empujables: tierra avanza una casilla; hielo resbala hasta chocar.
const EMPUJABLES: Array = [["tierra", 15, 3], ["tierra", 12, 7], ["hielo", 16, 7]]


## Matorrales secos sueltos en zonas abiertas (arden).
const SETOS: Array = [Vector2i(9, 5), Vector2i(18, 5), Vector2i(13, 21), Vector2i(15, 10),
	Vector2i(19, 9), Vector2i(7, 21), Vector2i(10, 9), Vector2i(14, 16)]


func _mapa() -> PackedStringArray:
	return MAPA


func _lista_props() -> Array:
	return PROPS


func _lista_setos() -> Array:
	return SETOS


func _suelo_objetos() -> Array:
	var l: Array = []
	for r in RECOGIBLES:
		l.append([r[0], r[1], r[2], 5 if String(r[0]) == "oro" else 1])
	return l


func _celdas_guardado() -> Array:
	return GUARDADOS


func _lista_empujables() -> Array:
	return EMPUJABLES


func _puestos() -> Array:
	return [["librera", PUESTO_CELDA], ["alquimista", PUESTO_CELDA + Vector2i(0, 3)]]
