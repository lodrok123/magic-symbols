extends Node2D

## NIVEL 1 — LA PIRA AL OTRO LADO.
##
## El primer nivel que no se pasa andando. El planteamiento:
##
##   La pira que hay que encender está al otro lado de un canal de agua
##   de tres casillas. El fuego no llega tan lejos, y el agua corta el
##   paso. Pero **el viento que cruza fuego se lleva el fuego consigo**.
##
## Esa regla ya existía antes de este nivel y no se escribió pensando en
## él. El nivel no añade una mecánica: DESCUBRE una. Eso es exactamente
## lo que se quería comprobar del sistema emergente.
##
## Hay al menos dos soluciones más, y están bien: congelar el canal y
## cruzar andando (cuesta tres hechizos de hielo), o echar tierra al agua
## para hacer pasadero. Que el puzle tenga una solución elegante y dos
## brutas es la textura que buscamos.
##
## Los enemigos plantean dos problemas distintos a propósito:
##   - El **guerrero** te obliga a no acercarte.
##   - El **arquero** te obliga a no quedarte quieto — que con el tiempo
##     detenido dentro del grimorio es un problema mucho más interesante.


##   .  vacío (te caes)      N  suelo        G  hierba
##   W  agua                 T  hierba tupida
##   X  suelo + cubo de tierra encima (plataforma)
## EL CANAL CRUZA LA ISLA DE LADO A LADO, y eso no es decorativo.
##
## En la primera versión el agua solo ocupaba las filas de en medio: se
## podía rodear andando, y —lo que de verdad rompía el puzle— también
## se podía rodear con una flecha de fuego. La prueba lo enseñó a la
## primera: dos partidas encendieron la pira lanzando fuego en las ocho
## direcciones, sin viento y sin cruzar. Justo lo que queríamos evitar.
##
## Un puzle no está terminado cuando tiene solución: está terminado
## cuando NO tiene la solución tonta.
const MAPA: PackedStringArray = [
	"NNNNNNNNNNNNNNN",
	"NNNNNNNNNNNNNNN",
	"NNNNNNWWWNNNNNN",
	"NNNNNNWWWNNNNNN",
	"NNNNGNWWWNNNNNN",
	"NNNNGNWWWNNNNNN",
	"NNNNNNWWWNNNNNN",
	"NNNNNNWWWNNNXNN",
	"NNNNNNWWWNNNNNN",
	"NNNNNNWWWNNNNNN",
	"NNNNNNNNNNNNNNN",
	"NNNNNNNNNNNNNNN",
]

## LA CAPA DE ADORNOS, encima del mapa y con las mismas dimensiones.
##
## Va aparte del MAPA y no como letras nuevas ahí porque un adorno NO es
## un tipo de suelo: es algo que hay ENCIMA del suelo que haya. Mezclarlos
## obligaría a inventar una letra por cada pareja (hierba-con-árbol,
## tierra-con-árbol, hierba-con-rocas...) y eso crece al cuadrado.
##
## Y no son decorado: cada uno reacciona a algo (ver prop.gd).
##   A  árbol      arde, y al arder deja el paso libre
##   B  arboleda   igual, pero tapa la casilla entera
##   R  rocas      las revientan la tierra y el rayo
##   C  canto      el viento lo mueve de casilla; al agua hace pasadero
##
## DÓNDE SE PUEDEN PONER NO ES A OJO. La solución del nivel es una línea
## de tiro que ya se verificó a mano, y un árbol plantado encima la
## rompería sin que se notara hasta jugarlo. Las casillas de aquí son las
## que quedan fuera de la franja de 32 px alrededor de CUALQUIERA de las
## 18 rectas válidas hasta la pira, comprobado en una pasada aparte. Por
## eso los adornos están en los bordes y no por el medio.
##
## EL CANTO DE (4,1) ES EL QUE TIENE GRACIA: está pegado al agua de
## (5,1), y el agua queda hacia abajo-derecha en pantalla. Un soplo de
## viento en esa diagonal lo tira al canal y deja un pasadero — la
## tercera forma de cruzar, y no hubo que programarla.
const ADORNOS: PackedStringArray = [
	"AAIBBIAAABBABIA",
	"AIIAIBAIABBIIAI",
	"AABA......RIAII",
	"IA.R.C.......AA",
	"II.........R.II",
	"BB...........AB",
	"IA........R..BA",
	"BA...........AB",
	"IA..........FBI",
	"AIBI.......IAII",
	"AIIABAAIIIBAIAI",
	"IAIIIAAAAABBBAA",
]

## LA CAPA DEL CIRCUITO, encima de todo lo demás.
##
##   -  placa conductora   pasa la corriente a sus vecinas
##   P  puerta             se abre con corriente y se cierra sola
##
## QUÉ HACE AQUÍ, exactamente: el agua del canal llega hasta (7,6), la
## placa de (8,6) está pegada a ella, y de placa en placa la corriente
## alcanza la puerta de (10,6). Un rayo en cualquier punto del canal la
## abre, porque el agua ya conducía desde antes de que existieran las
## placas.
##
## Y NO ES UN ADORNO: con la puerta cerrada, para pasar de (9,6) a (11,6)
## hay que rodear por (10,5) y bajar del montículo del arquero, o sea
## meterse justo donde te dispara. Abierta, se cruza de frente. La
## electricidad no regala terreno nuevo: convierte un rodeo peligroso en
## un atajo, que es un premio mejor porque se puede elegir no cogerlo.
##
## Lo honesto es decir lo que NO es: no sella nada. El nivel 1 se dibujó
## sin cuellos de botella, así que aquí no hay ninguna puerta que pueda
## cerrar el paso de verdad. Forzarlo sería redibujar el mapa, y eso vale
## más hacerlo a propósito en el nivel 2 que a martillazos en este.
##
## OJO A LA JUGADA INVERSA, que nadie ha programado: congelar el canal es
## la forma de cruzarlo andando, y el hielo NO conduce. Cruzar por hielo
## y abrir la puerta son dos usos del mismo canal que se excluyen.
const CIRCUITO: PackedStringArray = [
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	".........--P...",
	"...............",
	"...............",
	"...............",
]

## Qué adorno es cada letra. Los nombres son los del catálogo de prop.gd;
## esta tabla es lo único que sabe de letras.
const ADORNO_POR_LETRA: Dictionary = {
	"A": "arbol",
	"B": "arboleda",
	"I": "pino",
	"R": "rocas",
	"C": "canto",
	"H": "cabana",

	# Piezas de la lámina de maleza que NO se esparcen solas, porque o
	# estorban o necesitan apoyarse en algo.
	"F": "farol_1",       # alumbra: con el juego a oscuras, reparte el mapa
	"V": "valla_1",       # estorba y se revienta
	"S": "cartel_1",
	"O": "tronco_1",      # tronco caído: estorba a medias
	"Y": "enredadera_1",  # cuelga, va en bordes
}

const PIEZAS: Dictionary = {
	"N": preload("res://NeutralBlock.tscn"),
	"G": preload("res://GrassBlock.tscn"),
	"T": preload("res://GrassBlock.tscn"),
	"W": preload("res://WaterBlock.tscn"),
	"E": preload("res://EarthBlock.tscn"),
}

## DÓNDE SE PLANTA CADA UNO. Estaban escritas a pelo dentro de
## _place_actors(), y ahora hacen falta en dos sitios: la maleza tiene
## que saber qué casillas dejar libres. Un número mágico en dos funciones
## es un número mágico que un día dejará de coincidir.
const CELDA_JUGADOR: Vector2i = Vector2i(3, 7)
const CELDA_GUERRERO: Vector2i = Vector2i(4, 3)
const CELDA_ARQUERO: Vector2i = Vector2i(12, 7)
const CELDA_PIRA: Vector2i = Vector2i(10, 4)

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const ARCHER_SCENE: PackedScene = preload("res://Archer.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://Brazier.tscn")

## Dónde se planta el mapa. El rombo crece hacia abajo y hacia AMBOS
## lados desde la casilla (0,0), así que hay que desplazarlo o media
## mitad se sale por el borde.
const ORIGEN: Vector2 = Vector2(700.0, 60.0)

## --- LA CÁMARA ---
##
## Hasta ahora no había ninguna: la vista era fija y el nivel entero
## cabía en la ventana. Eso servía para probar el sistema y no sirve para
## jugarlo — a tamaño 1:1 la maga mide 78 px en una pantalla de 648 y el
## arte pintado no se aprecia.
##
## 1.45 y no 2: acercar es perder terreno, y este nivel se resuelve
## VIENDO la pira desde tu lado del canal. Con 1.45 la ventana enseña
## unas 795x447 unidades de mundo, que son casi catorce casillas de
## ancho — el canal entero y las dos orillas siguen entrando.
const ZOOM: float = 1.45

## Lo que se deja ver más allá de la última casilla transitable. No es
## cero a propósito: pegar el límite al último bloque deja al jugador
## clavado contra el borde de la pantalla cuando anda por la orilla, y
## eso se siente como un muro invisible aunque no lo haya.
##
## Bajó de 96 a 40 al plantar el cinturón de bosque. Ese margen ya no
## enseña vacío sino árboles, así que no hace falta tanto; y medido con
## la cámara pegada a los topes, 40 es donde deja de asomar la cuña negra
## de la esquina del rombo. Con 72 todavía se veía.
const MARGEN: float = 40.0

## Cuánto tarda la cámara en alcanzarte. Sin suavizado, cada paso mueve
## el mundo entero un píxel y el fondo vibra; con demasiado, la cámara
## va por detrás y el personaje se sale del centro al correr.
const SEGUIMIENTO: float = 6.0

@onready var player: Node2D = $Player


func _ready() -> void:
	# SIN ESTO EL ISOMÉTRICO SE VE ROTO: sin ordenar por profundidad, el
	# orden de dibujado es el del árbol y un bloque del fondo puede
	# taparle la cara a uno de delante.
	y_sort_enabled = true

	# LA NOCHE, LO PRIMERO. Va antes de construir para que ningún bloque
	# aparezca un fotograma a plena luz, y desde código —no como nodo en
	# la escena— para que cada bioma pueda traer su propio color sin
	# duplicar el .tscn.
	Glow.night(self)

	_build_level()
	# El muro, justo despues del suelo: necesita saber que casillas
	# existen, y tiene que estar antes de que aparezca nadie que pueda
	# empujar a alguien contra el.
	_place_walls()
	_place_props()
	# La maleza DESPUÉS de los adornos: necesita saber qué casillas ya
	# están ocupadas para no plantar un helecho dentro de un árbol.
	_scatter_undergrowth()
	_place_circuit()
	_place_actors()

	# LA CÁMARA, LA ÚLTIMA. Necesita saber dónde acabó el mapa y a quién
	# sigue, así que no puede montarse antes de que existan los dos.
	_place_camera()


func _build_level() -> void:
	for fila in range(MAPA.size()):
		var linea: String = MAPA[fila]
		for columna in range(linea.length()):
			var simbolo: String = linea[columna]
			var cell := Vector2i(columna, fila)

			# La X es suelo Y cubo encima. Se resuelve aquí y no con una
			# pieza nueva: apilar es poner dos bloques en la misma casilla
			# a distinta altura, que es justo lo que hace el jugador al
			# construir con la runa de tierra.
			if simbolo == "X":
				_spawn("N", cell)
				_spawn("E", cell, 1)
				continue

			if not PIEZAS.has(simbolo):
				continue
			_spawn(simbolo, cell)


## VARIANTES DE TEXTURA. Una variante es SOLO una piel: mismo bloque,
## mismo comportamiento, mismas colisiones. Por eso no son escenas
## distintas — serían tres NeutralBlock idénticos que habría que mantener
## a la vez.
##
## Hacen falta porque el suelo se repite sesenta veces en pantalla. Con
## una sola textura, el mismo guijarro sale en la misma esquina de las
## sesenta casillas y el ojo caza la rejilla antes que el dibujo.
##
## SOLO PARA BLOQUES QUE NO SE CAMBIAN LA TEXTURA A SÍ MISMOS. La hierba
## queda fuera a propósito: GrassBlock intercambia su textura al crecer y
## al quemarse, y se llevaría la variante por delante en cuanto cambie de
## estado.
const VARIANTES: Dictionary = {
	"N": ["res://art/floor.png", "res://art/floor_b.png"],
	"W": ["res://art/water.png", "res://art/water_b.png"],
}


## Qué variante le toca a cada casilla.
##
## DETERMINISTA, no al azar. Con random(), el mapa cambiaría de aspecto en
## cada partida y un jugador que se está aprendiendo un puzle vería el
## suelo moverse bajo los pies. La misma casilla tiene que dar siempre la
## misma piedra.
##
## LOS DOS DESPLAZAMIENTOS NO SON ADORNO. La primera versión era solo
## `x * primo + y * primo`, y al medirla salió un DAMERO perfecto: 52 y
## 52, alternando una sí y una no. Los dos primos son impares, así que al
## dividir entre 2 solo sobrevive la paridad de (x + y) — justo la rejilla
## que las variantes venían a romper.
##
## Los `h ^ (h >> k)` reparten los bits altos (donde sí hay mezcla) sobre
## los bajos (que son los que sobreviven al módulo). Medido en el mapa de
## 13x8: 53/51 con dos variantes, y los vecinos en diagonal coinciden 52
## veces de 84 en vez de las 84 del damero.
func _variante(simbolo: String, cell: Vector2i) -> String:
	var lista: Array = VARIANTES[simbolo]
	var h: int = absi(cell.x * 374761393 + cell.y * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	h = absi(h ^ (h >> 16))
	return lista[h % lista.size()]


func _spawn(simbolo: String, cell: Vector2i, altura: int = 0) -> Node2D:
	var bloque: Node2D = PIEZAS[simbolo].instantiate()

	# La hierba tupida es el mismo bloque en otro estado (1 = GROWN). No
	# hay una escena por estado y no debe haberla.
	if simbolo == "T":
		bloque.initial_state = 1

	add_child(bloque)

	# EL NODO SE QUEDA A RAS DE SUELO, aunque el bloque esté elevado.
	# y_sort ordena por la Y de pantalla, y un bloque subido 55 px tiene
	# MENOS Y: Godot lo dibujaría detrás de la losa sobre la que se apoya,
	# es decir, invisible. Dejando el nodo abajo, la profundidad que ve
	# y_sort es la de su CASILLA, que es la correcta.
	bloque.position = ORIGEN + IsoGrid.to_screen(cell)

	if altura > 0:
		var visual: Node2D = bloque.get_node_or_null("Visual")
		if visual:
			visual.position.y -= altura * IsoGrid.LEVEL
		# Un empujoncito para desempatar DENTRO de la misma casilla. Con
		# z_index no valdría: manda sobre y_sort, así que el cubo se
		# pintaría por encima de todo, incluidos los bloques de delante.
		bloque.position.y += 0.1 * altura

	if VARIANTES.has(simbolo):
		var visual: Sprite2D = bloque.get_node_or_null("Visual") as Sprite2D
		if visual:
			visual.texture = load(_variante(simbolo, cell))

	_fit_to_diamond(bloque)
	return bloque


## Los adornos van DESPUÉS de los bloques y como nodos hermanos, no como
## hijos del bloque que pisan. Dos razones: y_sort los ordena solo si son
## hermanos, y un árbol no debe desaparecer porque el suelo de debajo se
## disipe — se quedaría un hueco con un árbol flotando, que es peor que
## un árbol sobre el vacío.
func _place_props() -> void:
	for fila in range(ADORNOS.size()):
		var linea: String = ADORNOS[fila]
		for columna in range(linea.length()):
			var letra: String = linea[columna]
			if not ADORNO_POR_LETRA.has(letra):
				continue

			var adorno: Prop = Prop.make(ADORNO_POR_LETRA[letra])
			add_child(adorno)
			adorno.position = _at(Vector2i(columna, fila))


## --- LA MALEZA ---
##
## Setenta y tres piezas de sotobosque y NI UNA COLOCADA A MANO.
##
## Podrían ir en otra capa de letras como ADORNOS, y sería un error: los
## adornos son terreno —deciden por dónde se va y hay que pensarlos uno a
## uno—, mientras que la maleza solo tiene que quitarle al suelo la cara
## de tablero. Dibujarla a mano serían ochenta letras que revisar cada
## vez que el mapa cambie, para un resultado que nadie va a mirar de
## cerca.
##
## Se reparte con el MISMO hash que las variantes de losa, y por el mismo
## motivo: tiene que ser el mismo helecho en la misma casilla en cada
## partida. Un decorado que baila entre intentos hace que el jugador
## dude de lo que recuerda del nivel.
## SOLO LO QUE NO ESTORBA. Los troncos caídos, las rocas y las vallas
## están cortados y disponibles, pero NO se esparcen: tienen colisión, y
## una colisión colocada por un hash es una colisión que nadie ha mirado.
## La solución de este nivel es una línea de tiro comprobada a mano; un
## tronco que caiga encima la rompe sin que se note hasta jugarlo. Lo que
## estorba se pone en ADORNOS, a mano y a sabiendas.
##
## Las enredaderas tampoco: cuelgan, y colgando de nada en medio de un
## claro parecen una cortina flotando. Van a mano, en los bordes.
const MALEZA: Array = [
	"arbusto", "mata", "setas", "cepa", "arbolillo",
]

## Cuántas piezas hay de cada familia en art/forest/. Se escribe aquí y
## no se cuenta en disco porque contar archivos en tiempo de ejecución
## obliga a abrir el directorio en cada arranque, y esto cambia una vez
## cada muchas semanas.
const MALEZA_CUANTAS: Dictionary = {
	"arbusto": 9, "mata": 11, "setas": 11, "cepa": 7, "arbolillo": 10,
}

## La mitad de las casillas libres. Subió de un tercio a la mitad al
## reescalar las piezas: con setas que llegan a la rodilla en vez de al
## pecho, un tercio de casillas se quedaba en un suelo pelado con cuatro
## cosas sueltas. Más de la mitad y vuelve a ser una alfombra.
const DENSIDAD: float = 0.5


func _scatter_undergrowth() -> void:
	# Las casillas que ya tienen algo encima. Un helecho dentro de un
	# árbol no se ve, pero un tronco caído dentro de una placa conductora
	# sí — y encima estorbaría donde no debe.
	var ocupadas: Dictionary = {}

	# Las casillas donde se planta alguien. Un arbusto encima de la maga
	# la tapa entera: ella mide 78 px y el arbusto 50, y al compartir
	# casilla el orden de dibujo es un empate que gana quien se añadió
	# después. No es un problema de profundidad, es que ahí no va nada.
	for quien in [CELDA_JUGADOR, CELDA_GUERRERO, CELDA_ARQUERO, CELDA_PIRA]:
		ocupadas[quien] = true

	for capa in [ADORNOS, CIRCUITO]:
		for fila in range(capa.size()):
			var linea: String = capa[fila]
			for columna in range(linea.length()):
				if linea[columna] != ".":
					ocupadas[Vector2i(columna, fila)] = true

	var puestas: int = 0
	for fila in range(MAPA.size()):
		var linea: String = MAPA[fila]
		for columna in range(linea.length()):
			var cell := Vector2i(columna, fila)
			# Sobre agua no: es la superficie que el jugador tiene que
			# leer para saber dónde puede congelar.
			if linea[columna] == "." or linea[columna] == "W":
				continue
			if ocupadas.has(cell):
				continue

			# Tres tiradas del mismo hash con semillas distintas: si hay
			# maleza, de qué familia y cuál. Con una sola tirada la
			# familia quedaría atada a la densidad y saldrían rachas.
			if _azar(cell, 1) >= DENSIDAD:
				continue
			var familia: String = MALEZA[int(_azar(cell, 2) * MALEZA.size())]
			var cual: int = int(_azar(cell, 3) * MALEZA_CUANTAS[familia]) + 1

			var pieza: Prop = Prop.make("%s_%d" % [familia, cual])
			add_child(pieza)
			pieza.position = _at(cell)
			puestas += 1

	print("Maleza: ", puestas, " piezas repartidas.")


## Un número entre 0 y 1 para una casilla, estable entre partidas.
## `semilla` permite sacar varios de la misma casilla sin que salgan
## correlacionados — que es lo que pasaría reusando el mismo hash.
func _azar(cell: Vector2i, semilla: int) -> float:
	var h: int = absi(cell.x * 374761393 + cell.y * 668265263 + semilla * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = absi(h ^ (h >> 16))
	return float(h % 100000) / 100000.0


## Las placas y la puerta se plantan igual que los adornos —encima de la
## losa que ya hay, no en su lugar— y por la misma razón: una placa
## conductora no cambia por dónde se anda, solo por dónde pasa la
## corriente. El suelo de debajo sigue siendo el suelo.
func _place_circuit() -> void:
	for fila in range(CIRCUITO.size()):
		var linea: String = CIRCUITO[fila]
		for columna in range(linea.length()):
			var pieza: Node2D = null
			match linea[columna]:
				"-": pieza = Conductor.make()
				"P": pieza = Door.make()
				_: continue

			add_child(pieza)
			pieza.position = _at(Vector2i(columna, fila))


## Las formas de colisión venían dimensionadas para losas de 52x32. El
## rombo isométrico mide 116x55, así que hay que reemplazarlas o el
## jugador atraviesa medio bloque antes de chocar.
func _fit_to_diamond(bloque: Node) -> void:
	for nodo in [bloque.get_node_or_null("CollisionShape2D"),
			bloque.get_node_or_null("SolidBody/CollisionShape2D")]:
		if nodo:
			nodo.shape = IsoGrid.diamond()
			nodo.position = Vector2.ZERO


## --- Actores ---

## LA PISADA DE UN ACTOR TAMBIÉN ES UN ROMBO.
##
## El jugador llevaba un círculo de radio 24, y en un mundo aplastado 2:1
## un círculo miente: ocupa el doble de casillas a lo alto de las que
## aparenta, así que se queda enganchado en bordes que no se ven y se
## cuela por huecos que parecen cerrados. La pisada tiene que estar
## aplastada igual que el suelo.
##
## Pequeña a propósito (media casilla): un personaje que ocupa la casilla
## entera no puede pasar entre dos bloques en diagonal, y eso en
## isométrico se siente fatal porque visualmente hay sitio de sobra.
func _fit_actor_collision(actor: Node) -> void:
	for nodo in actor.get_children():
		if nodo is CollisionShape2D:
			nodo.shape = IsoGrid.footprint(0.42)
		elif nodo is Area2D:
			var forma: Node = nodo.get_node_or_null("CollisionShape2D")
			if forma:
				# Los pies miran qué hay debajo, así que su rombo es aún
				# más pequeño: decide en qué casilla estás, y con uno
				# grande estarías "en" cuatro casillas a la vez.
				forma.shape = IsoGrid.footprint(0.30)


## Le engancha el animador. Es un nodo suelto que se cuelga y ya: no hay
## que tocar player.gd ni enemy.gd, porque deduce el movimiento mirando
## cómo cambia la posición de su padre.
func _animate(actor: Node2D) -> void:
	# Cambiar de arte es cambiar esta línea: hero() es el mago generado,
	# rita() la maga pintada de la guía. Volver atrás cuesta lo mismo.
	actor.add_child(ActorAnimator.rita())


func _anchor_feet(actor: Node) -> void:
	for hijo in actor.get_children():
		if hijo is Sprite2D and hijo.texture and hijo.centered:
			hijo.offset.y -= hijo.texture.get_height() * 0.5


## EL BORDE DEL MUNDO.
##
## Los límites de cámara del paso anterior son SOLO VISUALES: dejan de
## enseñar el vacío, pero no impiden andar hacia él. El resultado es lo
## peor de los dos mundos — te sales del encuadre y te quedas andando a
## ciegas por la nada, o te enganchas en el borde sin entender por qué.
##
## La caída sigue existiendo y sigue estando bien donde tiene sentido:
## que te empujen de una plataforma, que el suelo se disipe bajo tus
## pies. Lo que no puede pasar es SALIRSE DEL NIVEL ANDANDO, porque eso
## no es un riesgo que hayas corrido, es un sitio al que no había que
## poder ir.
##
## SE PONE EN EL VACÍO, NO EN LA ORILLA. Un muro por casilla de suelo
## haría falta saber qué lado de cada casilla mira afuera; poniéndolo en
## las casillas vacías que TOCAN suelo sale el mismo anillo sin pensar en
## direcciones, y funciona igual si el nivel 2 tiene un agujero en medio.
func _place_walls() -> void:
	var muro := StaticBody2D.new()
	muro.name = "BordeDelMundo"
	add_child(muro)

	# SE RECORRE UNA CASILLA MÁS DE LA CUENTA POR CADA LADO. Sin ese
	# margen, las casillas del borde superior del mapa —la fila 0— no
	# tienen ninguna casilla vacía por encima, así que no se sellaría
	# nada y se saldría del nivel andando hacia arriba. Es justo el lado
	# por el que se salía.
	var ancho: int = 0
	for linea in MAPA:
		ancho = maxi(ancho, linea.length())

	var puestos: int = 0
	for fila in range(-1, MAPA.size() + 1):
		for columna in range(-1, ancho + 1):
			var cell := Vector2i(columna, fila)
			if _es_suelo(cell):
				continue
			if not _toca_suelo(cell):
				continue

			var forma := CollisionShape2D.new()
			forma.shape = IsoGrid.diamond()
			forma.position = _at(cell)
			muro.add_child(forma)
			puestos += 1

	print("Borde del mundo: ", puestos, " casillas selladas.")


## Una casilla del mapa por la que se puede andar. El vacío es el punto,
## y todo lo demás —incluida el agua— es suelo a estos efectos: el agua
## ya se bloquea sola, y sellarla aquí impediría cruzarla al congelarla.
func _es_suelo(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAPA.size():
		return false
	var linea: String = MAPA[cell.y]
	if cell.x < 0 or cell.x >= linea.length():
		return false
	return linea[cell.x] != "."


## Una casilla por la que se puede ANDAR: suelo, y sin nada encima que
## ocupe la casilla entera. El umbral en 0.9 y no en 1.0 para que la
## cabaña (0.95) cuente como muro igual que los árboles; por debajo de
## ahí se pasa rozando y sigue siendo sitio del jugador.
func _es_transitable(cell: Vector2i) -> bool:
	if not _es_suelo(cell):
		return false
	var letra: String = ADORNOS[cell.y][cell.x]
	if not ADORNO_POR_LETRA.has(letra):
		return true
	var ficha: Dictionary = Prop.ficha_de(ADORNO_POR_LETRA[letra])
	return float(ficha.get("estorbo", 0.0)) < 0.9


## Sólo los cuatro vecinos en cruz. En diagonal no hace falta: dos
## casillas que sólo comparten una esquina no dejan pasar a nadie, y
## sellar las diagonales pondría muros en esquinas que ya están tapadas.
func _toca_suelo(cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _es_suelo(cell + d):
			return true
	return false


## --- LA CÁMARA ---
##
## Se monta desde código y no en el .tscn por lo mismo que la noche: los
## límites SALEN DEL MAPA. Puestos a mano en la escena habría que volver
## a medirlos cada vez que el nivel cambie de forma, y nadie se acuerda
## de hacerlo hasta que un día la cámara enseña el vacío.
##
## Cuelga del jugador para que le siga sin una línea de _process. Los
## límites son del mundo, no suyos, así que los calculamos aquí.
func _place_camera() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = SEGUIMIENTO

	# El grimorio para el tiempo, y la cámara tiene que pararse con él o
	# seguiría deslizándose sobre un mundo congelado.
	cam.process_mode = Node.PROCESS_MODE_INHERIT

	var caja: Rect2 = _map_bounds()
	cam.limit_left = int(caja.position.x)
	cam.limit_top = int(caja.position.y)
	cam.limit_right = int(caja.end.x)
	cam.limit_bottom = int(caja.end.y)

	player.add_child(cam)
	cam.make_current()
	# Sin esto la cámara arranca en el centro del mundo y se desliza hasta
	# el jugador durante el primer segundo de partida.
	cam.reset_smoothing()


## Hasta dónde llega el nivel, en píxeles de pantalla.
##
## ENCUADRA LO TRANSITABLE, NO EL SUELO. Con el cinturón de bosque
## alrededor de la isla, "hasta dónde hay suelo" y "hasta dónde se puede
## ir" dejaron de ser lo mismo: el bosque son noventa y dos casillas de
## suelo por las que no se pasa. Si la cámara las encuadrara, se pasaría
## media pantalla enseñando copas de árboles.
##
## Encuadrando lo transitable, el bosque queda justo en el filo del
## encuadre: tapa el vacío, que es para lo que está, sin comerse la
## vista. Y el margen de abajo hace que siempre se vea un poco de él.
##
## SE RECORRE EL MAPA EN VEZ DE USAR SUS DIMENSIONES, porque un rombo de
## 15x12 no ocupa un rectángulo de 15x12 y el nivel 2 no va a ser
## rectangular.
func _map_bounds() -> Rect2:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)

	for fila in range(MAPA.size()):
		var linea: String = MAPA[fila]
		for columna in range(linea.length()):
			if not _es_transitable(Vector2i(columna, fila)):
				continue
			var p: Vector2 = _at(Vector2i(columna, fila))
			minimo = minimo.min(p)
			maximo = maximo.max(p)

	if minimo.x == INF:
		return Rect2(ORIGEN, Vector2.ZERO)

	# Media casilla a cada lado, porque _at() da el CENTRO del rombo y el
	# bloque sigue existiendo medio rombo más allá. El margen va encima.
	var borde := Vector2(IsoGrid.STEP.x + MARGEN, IsoGrid.STEP.y + MARGEN)
	return Rect2(minimo - borde, (maximo - minimo) + borde * 2.0)


func _at(cell: Vector2i, altura: int = 0) -> Vector2:
	return ORIGEN + IsoGrid.to_screen(cell, altura)


func _place_actors() -> void:
	# Sales a la izquierda, con la hierba a mano y el agua por delante.
	player.position = _at(CELDA_JUGADOR)
	_fit_actor_collision(player)
	_animate(player)

	# El guerrero patrulla TU lado del canal: es el que te mete prisa
	# mientras resuelves, no el que te remata.
	var guerrero: Node2D = ENEMY_SCENE.instantiate()
	add_child(guerrero)
	guerrero.position = _at(CELDA_GUERRERO)
	_fit_actor_collision(guerrero)
	# Ya NO hace falta _anchor_feet: el animador planta la figura en la
	# celda con los pies donde toca, que es justo lo que aquel apaño
	# intentaba arreglar a mano.
	guerrero.add_child(ActorAnimator.guerrero())

	# El arquero está AL OTRO LADO y subido a la plataforma. Los dos
	# detalles importan: al otro lado no puedes ir a por él con la
	# espada, y subido te alcanza aunque tú también te subas a algo.
	var arquero: Node2D = ARCHER_SCENE.instantiate()
	add_child(arquero)
	# Fuera de la línea del viento a propósito: la hierba y la pira
	# comparten fila de rejilla para que el trayecto del hechizo sea
	# evidente, y plantar al arquero encima solo confundiría la lectura.
	arquero.position = _at(CELDA_ARQUERO)
	# Mismo adelanto en la cola de dibujo que se hace el jugador al
	# subirse: el cubo de su casilla va 0,1 por delante, y sin esto el
	# arquero se pinta DENTRO de la plataforma en la que está plantado.
	arquero.position.y += 0.15
	arquero.get_node("Sprite2D").position.y -= IsoGrid.LEVEL
	arquero.elevation = 1
	arquero.add_child(ActorAnimator.arquero())

	# La pira, al otro lado del canal.
	var pira: Node2D = BRAZIER_SCENE.instantiate()
	add_child(pira)
	pira.position = _at(CELDA_PIRA)
