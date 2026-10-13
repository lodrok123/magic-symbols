class_name Glow
extends RefCounted

## LA LUZ.
##
## Mismo patrón que BlockFx y Sfx: funciones estáticas, nada que colocar
## en la escena, nada que configurar. Quien alumbre llama y ya.
##
## Oscurecer el juego entero no es un filtro encima: cambia lo que
## significa el fuego. Con todo iluminado, una antorcha es un adorno
## naranja; a oscuras, es POR DONDE PUEDES VER. Ese es el motivo real de
## hacer esto ahora y no al final — el nivel de la cueva volcánica se
## apoya entero en ello, y un bioma no se puede diseñar sin saber cómo
## se va a ver.

## El color de la noche. Multiplica a todo lo que hay en el mundo (no a
## la interfaz, que vive en su propio CanvasLayer y se queda legible).
##
## Azulado y no gris: la penumbra real tira a azul porque el ojo pierde
## sensibilidad al rojo con poca luz, y eso hace que cualquier llama
## naranja destaque el doble sin subirle ni un punto de energía.
##
## 0.40 y no menos. Bajarlo se ve espectacular en una captura y se juega
## fatal: hay que seguir viendo dónde acaba el suelo y empieza el vacío.
const NOCHE: Color = Color(0.40, 0.43, 0.58)

## Los colores de las luces vivas, en un solo sitio para que el fuego de
## una pira, el de un árbol y el de un hechizo sean EL MISMO fuego.
##
## SON EL NÚCLEO DEL EFECTO, NO SU IDENTIDAD, y esa diferencia es real:
## medidos sobre la guía de arte, el cuerpo del fuego está en 14° y su
## núcleo en 42°. Lo que identifica al elemento es el cuerpo (y por eso
## va en RuneData.color, que es lo que tiñe el hechizo); lo que ilumina
## una sala es el núcleo, que siempre tira a blanco. Una antorcha
## naranja saturada pinta la piedra de naranja y se ve a tinte; una con
## el color del rescoldo la pinta de cálido, que es lo que hace el fuego.
const LUZ_FUEGO: Color = Color(1.00, 0.78, 0.42)
const LUZ_RAYO: Color = Color(0.98, 0.92, 0.55)
const LUZ_MAGIA: Color = Color(0.78, 0.70, 1.00)

## --- EL AMBIENTE DE CADA BIOMA ---
##
## Medido sobre las tiras de paleta de la guía de arte, tomando su color
## más oscuro —que es el que manda en la penumbra— y subiéndolo hasta que
## se sigan viendo los bordes del suelo.
##
## No es decoración: el ambiente decide qué elemento importa. En la cueva
## volcánica casi no se ve, así que el fuego deja de ser un arma y pasa a
## ser la vista; en el desierto apenas oscurece, así que ahí el fuego no
## te da nada que no tuvieras.
const AMBIENTE: Dictionary = {
	"bosque":   Color(0.42, 0.46, 0.40),
	"ciudad":   Color(0.40, 0.42, 0.55),
	"cueva":    Color(0.24, 0.28, 0.42),
	"pantano":  Color(0.32, 0.42, 0.38),
	"volcan":   Color(0.26, 0.20, 0.24),
	"desierto": Color(0.62, 0.56, 0.46),
}

## Cuánto se aplasta el charco de luz.
##
## Una luz redonda en un mundo isométrico se lee como una ESFERA flotando
## delante del suelo, no como luz posada sobre él. Aplastarla a la misma
## proporción que el rombo la pega al suelo. Es el mismo truco que ya
## hacen la pisada del jugador y las partículas.
const APLASTADO: Vector2 = Vector2(1.0, 0.55)

## La luz nace en la CARA DE ARRIBA del bloque, no en el centro del nodo,
## igual que las partículas. Si no, una antorcha parece alumbrar desde
## dentro de la piedra.
const CARA: Vector2 = Vector2(0.0, -IsoGrid.LEVEL * 0.35)

static var _degradado: GradientTexture2D = null


## El degradado radial que usa toda luz del juego. Se construye una vez y
## se comparte: son unos pocos kilobytes, pero una textura por antorcha
## serían cientos de copias idénticas en un nivel con fuego.
##
## La curva NO es lineal. Una caída recta deja un borde visible, un aro
## donde se acaba la luz; elevándola hace que se apague antes por el
## centro y se desvanezca de verdad en los bordes.
static func _textura() -> GradientTexture2D:
	if _degradado != null:
		return _degradado

	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1, 1, 1, 0))
	for i in range(1, 6):
		var x: float = float(i) / 6.0
		g.add_point(x, Color(1, 1, 1, pow(1.0 - x, 2.2)))

	_degradado = GradientTexture2D.new()
	_degradado.gradient = g
	_degradado.width = 256
	_degradado.height = 256
	_degradado.fill = GradientTexture2D.FILL_RADIAL
	_degradado.fill_from = Vector2(0.5, 0.5)
	_degradado.fill_to = Vector2(1.0, 0.5)
	return _degradado


## Cuelga una luz permanente de algo. Devuelve el nodo para poder
## apagarla después (`queue_free()`), que es lo que hacen la pira al
## apagarse y el árbol al consumirse.
##
## `parpadeo` NO es un adorno: una luz fija se lee como una bombilla.
## Lo que dice "esto es fuego" es que la intensidad no para quieta, y se
## consigue con un Tween en bucle — sin script, sin _process y sin que
## nadie tenga que acordarse de actualizarla.
static func attach(padre: Node2D, color: Color, radio: float,
		energia: float = 1.0, parpadeo: bool = false) -> PointLight2D:
	var luz := PointLight2D.new()
	luz.texture = _textura()
	luz.color = color
	luz.energy = energia
	# texture_scale toma como referencia la mitad de la textura (128 px),
	# así que se divide para poder hablar en radio de pantalla.
	luz.texture_scale = radio / 128.0
	luz.scale = APLASTADO
	luz.position = CARA
	luz.shadow_enabled = false

	padre.add_child(luz)

	if parpadeo:
		# El tiempo se detiene al abrir el grimorio y las llamas deben
		# quedarse quietas con él: es la única manera de que el libro se
		# sienta como una pausa y no como una ventana encima del juego.
		var t := luz.create_tween().set_loops()
		t.tween_property(luz, "energy", energia * 1.18, 0.11)
		t.tween_property(luz, "energy", energia * 0.86, 0.09)
		t.tween_property(luz, "energy", energia * 1.05, 0.14)
		t.tween_property(luz, "energy", energia * 0.92, 0.08)

	return luz


## Un fogonazo que se apaga solo. Para lo que pasa y ya no está: el
## impacto de un hechizo, una descarga, una puerta al abrirse.
##
## Cuelga de la ESCENA y no del emisor, por lo mismo que las partículas y
## los sonidos: muchas de estas luces ocurren justo cuando el objeto
## desaparece, y un hijo se va con su padre.
static func flash(origen: Node2D, color: Color, radio: float,
		energia: float = 1.4, duracion: float = 0.35) -> void:
	if origen == null or not origen.is_inside_tree():
		return

	var luz := PointLight2D.new()
	luz.texture = _textura()
	luz.color = color
	luz.energy = energia
	luz.texture_scale = radio / 128.0
	luz.scale = APLASTADO
	luz.shadow_enabled = false

	origen.get_tree().current_scene.add_child(luz)
	luz.global_position = origen.global_position + CARA

	var t := luz.create_tween()
	t.tween_property(luz, "energy", 0.0, duracion)
	t.tween_callback(luz.queue_free)


## Enciende la noche en una escena. Se llama desde el nivel y no se pone
## a mano en el .tscn para que cada bioma pueda traer su propio color sin
## tocar la escena: la cueva casi negra, el pantano verdoso, el desierto
## apenas oscurecido.
static func night(escena: Node, color: Color = NOCHE) -> CanvasModulate:
	var cm := CanvasModulate.new()
	cm.color = color
	escena.add_child(cm)
	return cm
