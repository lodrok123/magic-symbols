extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

## Cuánto dura un hechizo "quieto" (pilar, barrera, nube de vapor)
## antes de desaparecer solo, ya que a diferencia de una flecha nunca
## sale de la pantalla por sí mismo. Lo pone SpellFactory.cast() ANTES
## de meter el hechizo en la escena, porque _ready() ya lo necesita.
var stationary_lifetime: float = 0.6

# En vez de guardar solo un color y un daño sueltos, el hechizo
# lleva la ficha completa del elemento (RuneData). Así, cuando
# choque con algo, puede pasarle TODAS sus propiedades de golpe,
# no solo el daño.
var rune_data: RuneData = null

## Multiplicador de potencia que le pone la receta (el sello de
## aumento). Escala lo que se ve; el daño ya viene multiplicado en el
## RuneData duplicado, porque tocarlo aquí no serviría: quien lo lee es
## el objeto golpeado, no el hechizo.
## Es una propiedad con setter y no una variable a secas por la misma
## razón que ya nos mordió con `direction`: la receta pone la potencia
## DESPUÉS de crear el hechizo, así que calcular el tamaño en cualquier
## otro sitio llegaría tarde. Aquí, se aplique cuando se aplique, el
## tamaño va detrás. La raíz cuadrada es para que doblar la potencia no
## cuadruplique el área que ocupa en pantalla.
var power: float = 1.0:
	set(value):
		power = value
		scale = Vector2.ONE * sqrt(maxf(power, 0.01))

var is_stationary: bool = false

## Velocidad de reproducción del efecto visual. Las tiras se muestrearon
## desde animaciones de 28 FPS quedándonos con ~18 fotogramas, así que a
## 24 FPS se ven a un ritmo parecido al original.
const VFX_FPS: float = 24.0
var vfx_time: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Se decide UNA vez, al nacer, y se guarda. Antes esto se consultaba
	# leyendo `direction` en cada sitio, lo cual era frágil: bastaba con
	# que alguien asignase la dirección un instante tarde para que el
	# hechizo se creyera quieto siendo una flecha.
	is_stationary = direction == Vector2.ZERO

	if is_stationary:
		# Un Area2D solo avisa con "area_entered" cuando algo ENTRA de
		# nuevo en su zona. Si el pilar/barrera/vapor nace ya solapado
		# con un bloque, ese aviso nunca llegaría, así que lo miramos a
		# mano en cuanto la física haya procesado un ciclo.
		_check_initial_overlaps()
		get_tree().create_timer(stationary_lifetime).timeout.connect(queue_free)


## Movimiento del hechizo (una flecha). Si es quieto, no se mueve, pero
## su efecto visual sigue animándose igualmente.
func _process(delta: float) -> void:
	_animate_vfx(delta)

	if is_stationary:
		return

	position += direction * speed * delta

	# Si se aleja mucho, se destruye para no acumular basura
	if position.length() > 2000:
		queue_free()


## Asigna el elemento de este hechizo y con él su aspecto. Fíjate en que
## este código no sabe qué elemento es: solo pregunta a la ficha si trae
## animación. El día que añadas un elemento nuevo con su tira, se verá
## animado aquí sin tocar esta función.
func set_rune_data(data: RuneData) -> void:
	rune_data = data

	# El elemento se configura a sí mismo en el sprite (ver
	# RuneData.setup_sprite) y nos dice si tenía animación o no.
	if data.setup_sprite($Vfx):
		$Vfx.show()
		$ColorRect.hide()
	else:
		# Elementos sin animación propia (el vapor) siguen usando el
		# cuadrado de color, que al menos transmite de qué elemento son.
		$ColorRect.color = data.color


func _animate_vfx(delta: float) -> void:
	if not $Vfx.visible or rune_data == null or rune_data.vfx_frames <= 0:
		return

	vfx_time += delta
	# El módulo se hace sobre los fotogramas REALES, no sobre las celdas
	# de la rejilla: la última fila puede tener celdas vacías y saltarían
	# como parpadeos si las recorriéramos.
	$Vfx.frame = int(vfx_time * VFX_FPS) % rune_data.vfx_frames


## `await get_tree().physics_frame` espera a que termine el siguiente
## ciclo de física, que es cuando Godot ya sabe qué áreas se solapan
## con esta. Antes de eso, get_overlapping_areas() devolvería vacío.
func _check_initial_overlaps() -> void:
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	for area in get_overlapping_areas():
		_hit(area)


## Cuando el hechizo toca cualquier Area2D del mundo (enemigo, agua,
## una puerta...), le avisamos usando un "contrato" común: si ese
## objeto sabe reaccionar a un hechizo (tiene la función on_spell_hit),
## se lo pasamos junto con la dirección del hechizo (útil para el
## viento, que empuja/propaga cosas en esa dirección) y dejamos que
## decida qué hacer. El hechizo no necesita saber si era un enemigo o
## un bloque de agua.
func _on_area_entered(area: Area2D) -> void:
	var reacted: bool = _hit(area)

	# Una flecha desaparece al golpear algo QUE REACCIONA, no contra
	# cualquier área que se cruce. La diferencia importa: el jugador
	# lleva un Area2D en los pies (para saber sobre qué está subido) y el
	# hechizo nace justo encima de ella. Con la regla ingenua, toda
	# flecha se autodestruía contra los pies de quien la lanzaba antes de
	# recorrer un solo píxel.
	#
	# Un pilar, una barrera o una nube de vapor no desaparecen al primer
	# impacto: se quedan su tiempo y pueden afectar a varias cosas.
	if reacted and not is_stationary:
		queue_free()


## Devuelve si el área golpeada sabía reaccionar a un hechizo.
func _hit(area: Area2D) -> bool:
	if not area.has_method("on_spell_hit"):
		return false

	area.on_spell_hit(rune_data, direction)
	return true
