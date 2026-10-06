class_name Prop
extends Area2D

## LOS ADORNOS DEL MUNDO — y por qué ninguno es solo un adorno.
##
## Un árbol que solo se ve es un sprite. Un árbol que arde es una
## herramienta: te tapa el paso, y la forma de quitarlo es la misma magia
## con la que resuelves lo demás. Por eso aquí no hay un "decorado" y
## aparte unos "objetos interactivos": todo lo que se planta en el mundo
## habla los mismos tres contratos que ya hablaban los bloques, y el que
## no reacciona a nada es simplemente el que dejó la casilla en blanco.
##
##   on_spell_hit(rune, dir)   qué le hace un hechizo
##   carried_element()         qué se puede llevar el viento de aquí
##   push(dir, fuerza)         qué pasa si lo empujan
##
## UNA SOLA ESCENA PARA TODOS, y de hecho ninguna: el nodo se monta en
## _ready() a partir de la ficha del catálogo. Con seis adornos serían
## seis .tscn que mantener alineados a mano, y el séptimo sería el que se
## quedara descuadrado. Aquí añadir un adorno es una línea en CATALOGO.

const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")
const EARTH_RUNE: RuneData = preload("res://earth_rune.tres")

## La ficha de cada adorno. Todo lo que lo distingue de los demás está
## aquí; el código de abajo no menciona ni un solo nombre de adorno.
##
##   art       el png, en art/
##   estorbo   qué fracción de la casilla ocupa de verdad (0 = se pisa).
##             1.0 es la casilla ENTERA: el rombo de IsoGrid.diamond(),
##             que encaja borde con borde con el de al lado y no deja ni
##             una rendija. Los valores pequeños dejan pasar en diagonal.
##   arde      el calor lo prende; mientras arde, el viento se lleva fuego
##   rompe     la tierra y el rayo lo revientan
##   empuja    el viento lo mueve de casilla entera
##   bosque    no se le puede hacer nada, y lo dice cuando lo intentas
const CATALOGO: Dictionary = {
	# LOS ÁRBOLES SON MURO, NO HERRAMIENTA.
	#
	# Antes ardían y al arder abrían paso, y sobre el papel eso era
	# elegante: el obstáculo y su solución eran la misma magia. En la
	# mesa resultó ser lo contrario de elegante — cualquier problema de
	# terreno se resolvía con la misma respuesta (prende el árbol), así
	# que el bosque no planteaba una pregunta, solo cobraba un peaje de
	# un hechizo. Y un mapa donde TODO se puede borrar no tiene forma.
	#
	# De muro, el bosque hace el trabajo que ningún otro elemento hacía:
	# decidir por dónde se va. El nivel se dibuja con él, no a pesar de
	# él. Lo comprobé antes de cambiarlo — con el canal congelado se
	# sigue llegando a las 66 casillas del nivel 1, incluidas la pira, la
	# puerta y la plataforma del arquero.
	"arbol":    {"art": "prop_tree.png",  "estorbo": 1.0, "bosque": true},
	"arboleda": {"art": "prop_grove.png", "estorbo": 1.0, "bosque": true},
	"pino":     {"art": "prop_pine.png",  "estorbo": 1.0, "bosque": true},

	"rocas":    {"art": "prop_rocks.png",   "estorbo": 0.70, "rompe": true},
	"canto":    {"art": "prop_boulder.png", "estorbo": 0.50, "empuja": true},
	"tocon":    {"art": "prop_stump.png",   "estorbo": 0.00},

	# La cabaña ocupa la casilla entera y NO reacciona a nada. Hace falta
	# precisamente por eso — sin nada inerte, todo el mapa se siente
	# como un tablero de puzle y ninguna esquina como un sitio.
	"cabana":  {"art": "prop_cabin.png", "estorbo": 0.95},
}

## --- LA MALEZA ---
##
## Setenta y tres piezas de sotobosque, y ni una en CATALOGO. Escribir
## una ficha por helecho serían setenta y tres líneas que dicen lo mismo
## y una que se quedaría mal copiada; aquí la ficha es de la FAMILIA y el
## nombre del adorno la elige. Añadir una seta nueva es soltar el png en
## art/forest/ y no tocar código.
##
## Van en su carpeta porque son otra cosa que los adornos de arriba: un
## árbol es terreno y se coloca a mano; esto se esparce, y lo único que
## tiene que hacer es que el suelo deje de parecer un tablero. Viven en
## art/forest/ y ficha_de() les pone la ruta sola.

## CASI TODO ESTORBO CERO, y es una decisión, no pereza.
##
## Ahora que el árbol es muro, el mapa ya dice por dónde se va. Si además
## estorbaran los helechos, cada paso sería una negociación con el
## decorado y el jugador dejaría de fiarse de lo que ve. La maleza se
## pisa; lo que para es lo que se ve claramente que para.
const FAMILIAS: Dictionary = {
	"arbusto":    {"estorbo": 0.0},
	"mata":       {"estorbo": 0.0},
	"setas":      {"estorbo": 0.0},
	"cepa":       {"estorbo": 0.0},
	"enredadera": {"estorbo": 0.0},
	"cartel":     {"estorbo": 0.0},
	"arbolillo":  {"estorbo": 0.0},

	# Un tronco caído SÍ se nota al andar, y encima se puede reventar con
	# tierra o con rayo: es el obstáculo pequeño que faltaba entre "se
	# pisa" y "es un muro".
	"tronco":     {"estorbo": 0.45, "rompe": true},
	"roca":       {"estorbo": 0.55, "rompe": true},
	"valla":      {"estorbo": 0.90, "rompe": true},

	# EL FAROL ES LA PIEZA QUE MÁS CAMBIA UNA PARTIDA, y es un adorno.
	# Con el juego a oscuras, un farol no decora: reparte el mapa en
	# sitios donde ves y sitios donde no. Cuesta una línea porque Glow ya
	# existía y no sabe nada de faroles.
	"farol":      {"estorbo": 0.0, "luz": true},
}


## La ficha de un adorno, venga de donde venga. CATALOGO manda —así una
## pieza suelta puede salirse de su familia sin tocar la familia— y si no
## está, la decide el prefijo del nombre.
static func ficha_de(tipo: String) -> Dictionary:
	if CATALOGO.has(tipo):
		return CATALOGO[tipo]
	var familia: String = tipo.get_slice("_", 0)
	if FAMILIAS.has(familia):
		var f: Dictionary = FAMILIAS[familia].duplicate()
		f["art"] = "forest/" + tipo + ".png"
		return f
	return {}


## Lo que dice la maga cuando alguien le prende fuego al bosque.
##
## No es un chiste por hacer un chiste: es la manera barata de que un
## "no puedes" no se lea como un fallo. Un árbol que se traga una bola
## de fuego sin inmutarse y sin decir nada parece un bug; el mismo árbol
## con una frase encima es una decisión del personaje.
const EXCUSAS: Array = [
	"Ni hablar. Un incendio forestal no entraba en el plan.",
	"...mejor no. Esto arde entero y yo estoy en medio.",
	"No pienso ser la maga que quemó el bosque.",
	"El árbol no tiene la culpa de nada.",
]

## Lo que tarda un árbol en consumirse. Cuatro segundos es bastante rato
## en pantalla: da tiempo a ver que arde, a que el viento pase por encima
## y se lleve el fuego, y a apagarlo si te has equivocado de árbol.
const BURN_TIME: float = 4.0

## Un canto no se desliza: o se mueve de casilla o no se mueve. El tiempo
## de reposo evita que un corro de viento de seis puntos lo mande seis
## casillas de un solo hechizo.
const MOVE_TIME: float = 0.45

enum Estado { SANO, ARDIENDO, QUEMADO }

@export var kind: String = "arbol"

var estado: int = Estado.SANO
var burn_timer: float = 0.0
var move_cooldown: float = 0.0

var visual: Sprite2D = null
var solido: StaticBody2D = null
var llamas: GPUParticles2D = null
var luz: PointLight2D = null


func _ready() -> void:
	if ficha_de(kind).is_empty():
		push_warning("Adorno desconocido: " + kind)
		queue_free()
		return

	_montar()


## --- Montaje ---

func _montar() -> void:
	var ficha: Dictionary = ficha_de(kind)

	visual = Sprite2D.new()
	visual.texture = load("res://art/" + String(ficha["art"]))
	add_child(visual)

	# El área de detección es la casilla ENTERA aunque el estorbo sea
	# menor: si un hechizo cae en tu casilla te ha dado, aunque físicamente
	# se pueda pasar rozándote. Separar "dónde me dan" de "por dónde no se
	# pasa" es lo que permite árboles estrechos que aun así se prenden.
	var deteccion := CollisionShape2D.new()
	deteccion.shape = IsoGrid.diamond()
	add_child(deteccion)

	_set_estorbo(float(ficha.get("estorbo", 0.0)))

	# El farol se enciende solo. Parpadea como el fuego porque es fuego:
	# una luz fija se lee como una bombilla, y aquí dentro de un farol
	# hay una llama.
	if ficha.get("luz", false):
		luz = Glow.attach(self, Glow.LUZ_FUEGO, 130.0, 0.9, true)


## El cuerpo sólido se crea y se destruye entero en vez de deshabilitar
## su forma. Un árbol quemado no es "un árbol con la colisión apagada":
## es otra cosa, y tenerlo apagado por ahí invita a olvidarse de él.
func _set_estorbo(fraccion: float) -> void:
	if solido:
		solido.queue_free()
		solido = null

	if fraccion <= 0.0:
		return

	solido = StaticBody2D.new()
	var forma := CollisionShape2D.new()
	forma.shape = IsoGrid.footprint(fraccion)
	solido.add_child(forma)
	add_child(solido)


## --- Reacciones ---

func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return

	var ficha: Dictionary = ficha_de(kind)

	# EL BOSQUE NO REACCIONA, PERO CONTESTA. El silencio y el "no pasa
	# nada" se parecen demasiado, y el jugador no tiene forma de
	# distinguir "esto es inmune" de "esto está roto" si no se lo dicen.
	if ficha.get("bosque", false):
		if rune_data.tags.has("calor"):
			print(EXCUSAS[randi() % EXCUSAS.size()])
		return

	if ficha.get("arde", false):
		# EL RAYO TAMBIÉN PRENDE. No es un caso especial del rayo contra
		# los árboles: es que un árbol arde con calor Y con una descarga,
		# igual que la hierba. Le da al rayo un segundo uso sin inventar
		# ninguna regla, y de paso una cadena entera — descarga, árbol
		# ardiendo, viento que se lleva el fuego.
		if (rune_data.tags.has("calor") or rune_data.tags.has("electrico")) \
				and estado == Estado.SANO:
			_prender()
			return
		if (rune_data.tags.has("agua") or rune_data.tags.has("frio")) \
				and estado == Estado.ARDIENDO:
			_apagar()
			return

	if ficha.get("rompe", false) and \
			(rune_data.tags.has("tierra") or rune_data.tags.has("electrico")):
		_desmoronar()
		return

	# `disipar` revierte, aquí igual que en todas partes: devuelve el
	# árbol quemado a árbol. No es un poder nuevo del tiempo, es el mismo
	# de siempre aplicado a una cosa más.
	# `direction` no se usa: un adorno no reacciona distinto según de dónde
	# venga el golpe. Se acepta igualmente porque el contrato es el mismo
	# para todo el mundo, y recortarlo obligaría a quien lanza el hechizo
	# a saber a quién está golpeando.
	if rune_data.tags.has("disipar") and estado != Estado.SANO:
		_revertir()


## Mientras arde, ES una hoguera. Y como el viento pregunta a todo lo que
## cruza "¿llevas algo?", un árbol ardiendo sirve de mechero sin que ni
## el viento ni el árbol sepan el uno del otro. La misma regla que hace
## que una pira encendida encienda la siguiente.
func carried_element() -> RuneData:
	return FIRE_RUNE if estado == Estado.ARDIENDO else null


func _prender() -> void:
	estado = Estado.ARDIENDO
	burn_timer = BURN_TIME
	llamas = BlockFx.flames(self)
	luz = Glow.attach(self, Glow.LUZ_FUEGO, 170.0, 1.1, true)
	visual.modulate = Color(1.4, 1.05, 0.8)
	Sfx.play(self, "prender")
	print("¡El ", kind, " arde!")


func _apagar() -> void:
	estado = Estado.SANO
	burn_timer = 0.0
	_quitar_llamas()
	visual.modulate = Color(1, 1, 1)
	# Un reventón de ceniza y no humo continuo: `smoke()` deja un emisor
	# colgado para siempre, que es lo correcto para algo que humea de
	# fondo y lo incorrecto para un fuego que acaba de apagarse.
	BlockFx.burst(self, "ceniza")
	print("El ", kind, " se apaga.")


## Consumido. Deja de estorbar, y ahí está lo que hace que esto sea una
## mecánica y no un efecto: QUEMAR UN ÁRBOL ABRE UN PASO.
func _consumir() -> void:
	estado = Estado.QUEMADO
	_quitar_llamas()
	visual.texture = load("res://art/" + String(CATALOGO["tocon"]["art"]))
	visual.modulate = Color(1, 1, 1)
	_set_estorbo(0.0)
	BlockFx.burst(self, "ceniza")
	print("El ", kind, " se ha consumido. El paso queda libre.")


func _revertir() -> void:
	estado = Estado.SANO
	burn_timer = 0.0
	_quitar_llamas()
	visual.texture = load("res://art/" + String(ficha_de(kind)["art"]))
	visual.modulate = Color(1, 1, 1)
	_set_estorbo(float(ficha_de(kind).get("estorbo", 0.0)))
	BlockFx.burst(self, "magia")


func _desmoronar() -> void:
	BlockFx.burst(self, "tierra")
	Sfx.play(self, "derrumbe")
	print("Las rocas se desmoronan.")
	queue_free()


func _quitar_llamas() -> void:
	if llamas:
		llamas.queue_free()
		llamas = null
	if luz:
		luz.queue_free()
		luz = null


## --- El canto rodado ---

## LAS OCHO VECINAS, en coordenadas de rejilla.
##
## El empuje llega en dirección de PANTALLA y hay que traducirlo a una
## casilla, que no es lo mismo: en isométrico la vertical de pantalla no
## es ninguna dirección de la rejilla. Se elige la vecina cuya dirección
## en pantalla más se parece al empuje, que es exacto y son ocho cuentas.
const VECINAS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
]


func push(direction: Vector2, _force: float) -> void:
	if not ficha_de(kind).get("empuja", false):
		return
	if move_cooldown > 0.0 or direction == Vector2.ZERO:
		return

	var mejor := Vector2i.ZERO
	var mejor_parecido := 0.0
	for vecina in VECINAS:
		var en_pantalla: Vector2 = IsoGrid.to_screen(vecina).normalized()
		var parecido: float = en_pantalla.dot(direction.normalized())
		if parecido > mejor_parecido:
			mejor_parecido = parecido
			mejor = vecina

	if mejor == Vector2i.ZERO:
		return

	move_cooldown = MOVE_TIME
	position += IsoGrid.to_screen(mejor)
	BlockFx.burst(self, "tierra")
	Sfx.play(self, "rodar")
	print("El canto rueda una casilla.")

	_mirar_donde_he_caido()


## AL AGUA, EL CANTO HACE PASADERO.
##
## No hay una regla "canto + agua" escrita en ninguna parte: el canto le
## dice al agua "ha caído tierra encima" con el mismo contrato que usa el
## hechizo de tierra, y el agua ya sabía qué hacer con eso desde antes de
## que existieran los cantos. Empujar una piedra al canal es por tanto
## una tercera forma de cruzar, y ha salido gratis.
func _mirar_donde_he_caido() -> void:
	# Hay que esperar un fotograma de física: el área acaba de moverse y
	# Godot todavía no ha recalculado con quién se solapa. Es la misma
	# trampa que nos costó el "el jugador se cae al empezar".
	await get_tree().physics_frame
	if not is_inside_tree():
		return

	for area in get_overlapping_areas():
		if area.is_in_group("water_blocks") and area.has_method("on_spell_hit"):
			area.on_spell_hit(EARTH_RUNE, Vector2.ZERO)
			queue_free()
			return


func _process(delta: float) -> void:
	if move_cooldown > 0.0:
		move_cooldown -= delta

	if estado != Estado.ARDIENDO:
		return

	burn_timer -= delta
	if burn_timer <= 0.0:
		_consumir()


## --- Creación ---

## Se planta desde código y no desde una escena. `make` devuelve el nodo
## sin añadirlo al árbol a propósito: quien lo planta tiene que colocarlo
## primero, porque add_child() ejecuta _ready() al instante y ahí ya se
## lee `kind`. Es la misma trampa que ya nos mordió con los hechizos y
## con las flechas del arquero.
static func make(tipo: String) -> Prop:
	var p := Prop.new()
	p.kind = tipo
	p.y_sort_enabled = true
	return p
