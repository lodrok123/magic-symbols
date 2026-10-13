class_name NivelPruebas
extends RefCounted

## 7.12 · NIVEL DE PRUEBAS: el banco de pruebas de piezas y mecánicas nuevas, separado de los niveles de verdad.
## Se juega con F6 sobre `PruebaNivelPruebas3D.tscn` y se edita en `niveles/Nivel_Pruebas.tscn` (generado desde esto con F9;
## a partir de ahí manda el .tscn). Es lo que se usa para probar una pieza nueva o una mecánica ANTES de meterla en un nivel.
##
## Qué hay (16 × 16, suelo llano):
##   y=6:                    el jugador (S), justo antes del puente
##   y=3 y y=5:              una pieza de cada con su rótulo (el id de la pieza), de izquierda a derecha
##   y=7:                    una franja de agua con un puente (b) en el centro: para probar hielo, agua y cruzar
##   y=9:                    un marcador de cada objeto reactivo (seto, tronco, tótems, fogata, brasero, plantas, telaraña,
##                           placa, muñeco, baldosa)
##   y=12:                   los tres goblins (arquero y dos guerreros)
## Para probar una pieza nueva: añadirla al nivel con Pieza3D (ver LEEME) o, si ya está en `piezas/`, arrastrarla a `Piezas`.

const MAPA: PackedStringArray = [
	"################",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#..............#",
	"#......S.......#",
	"#~~~~~~b~~~~~~~#",
	"#..............#",
	"#zljkiFTsfqrKDp#",
	"#..............#",
	"#..............#",
	"#...A.....W..W.#",
	"#..............#",
	"#..............#",
	"################",
]

## Una pieza de cada: [id, columna, fila]. Cada fila tiene 14 (columnas 1 a 14).
const PIEZAS: Array = [
	["arbol_redondo", 1, 3], ["pino", 2, 3], ["arbusto", 3, 3], ["arbusto_flores", 4, 3], ["roca_grande", 5, 3],
	["roca_cristal", 6, 3], ["tocon", 7, 3], ["tronco", 8, 3], ["piedras", 9, 3], ["setas", 10, 3], ["valla", 11, 3],
	["cartel", 12, 3], ["barril", 13, 3], ["caja", 14, 3],
	["cofre", 1, 5], ["caja_pequena", 2, 5], ["puesto", 3, 5], ["totem_runico", 4, 5], ["brasero", 5, 5], ["fogata", 6, 5],
	["pilar", 7, 5], ["arco_ruina", 8, 5], ["matas", 9, 5], ["juncos", 10, 5], ["seto_seco", 11, 5], ["placa_peso", 12, 5],
	["baldosa_guardado", 13, 5], ["pocion", 14, 5],
]


## [id, Vector2i casilla, bloquea] de cada pieza de la fila (bloquea según el valor normal de la pieza).
static func piezas() -> Array:
	var res: Array = []
	for p in PIEZAS:
		var id: String = String(p[0])
		res.append([id, Vector2i(int(p[1]), int(p[2])), GeneradorPiezas.BLOQUEA.has(id)])
	return res
