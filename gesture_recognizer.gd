class_name GestureRecognizer
extends RefCounted

## Reconocedor de gestos $P (Point-Cloud Recognizer), portado a GDScript.
##
## Radu-Daniel Vatavu, Lisa Anthony y Jacob O. Wobbrock (ICMI 2012), de
## la misma familia que el $1. Licencia New BSD: uso libre incluso
## comercial, conservando este aviso.
## Original: https://depts.washington.edu/acelab/proj/dollar/
##
## --- POR QUÉ $P Y NO $1 ---
## El $1 es *unistroke*: un gesto, un trazo. En cuanto un sello necesita
## varios —un palo y una base para el pilar, dos arcos para la barrera,
## tres líneas para el viento— deja de servir.
##
## El $P trata el gesto como una NUBE DE PUNTOS SIN ORDEN: da igual
## cuántos trazos lo formen, en qué orden los dibujes y en qué sentido
## vaya cada uno. Importa más de lo que parece, porque nadie dibuja un ⊥
## empezando siempre por el mismo sitio.

## Cuántos puntos representan un gesto. Medido con 270 gestos
## deformados: 16 puntos aciertan el 95.9% y 32 el 97.0%, pero 32 tarda
## SEIS VECES más (105 ms frente a 17 ms). Como el coste crece además
## con cada plantilla que se grabe, un punto de acierto no compensa.
const NUM_POINTS: int = 16

## Distancia máxima posible entre dos puntos ya normalizados. Sirve para
## convertir distancias en parecidos de 0 a 1.
const HALF_DIAGONAL: float = 0.70710678

## --- POR QUÉ SE RECHAZA POR MARGEN Y NO POR PARECIDO ---
## Lo natural sería descartar por debajo de cierto parecido. Con el $P
## eso NO funciona, y está medido: los aciertos puntúan 0.91 de media,
## los fallos 0.87 y un garabato aleatorio 0.83. Los tres rangos se
## solapan casi del todo — no hay corte posible. El emparejamiento por
## nubes aplana los valores.
##
## Lo que sí separa es cuánto le saca el primer candidato al segundo:
## en los aciertos el segundo es un 103% peor de media, y en los fallos
## y garabatos solo un 10-12%. Con el corte en el 30% se conserva en
## torno al 90% de los aciertos y se rechaza el 85% de los errores.
##
## El parecido se sigue calculando, pero solo para mirarlo por consola
## al calibrar. Quien decide es `accepted`.
const MIN_MARGIN: float = 0.30

## Margen a partir del cual un trazo cuenta como limpio (calidad 1.0).
const QUALITY_FULL_MARGIN: float = 0.90

## Margen propio de los gestos que lo necesitan. Un gesto que se dibuja de forma
## muy variable (o que solo se parece a otro por accidente) puede exigir menos
## que el resto sin abrir la puerta a los demás: el corte de cada gesto es solo
## suyo. Medido con las muestras grabadas y trazos deformados, el viento pasa
## del 43% al 78% de aciertos con 0.15, y la flecha del 94% al 97% con 0.20.
## Los que no aparecen aquí usan MIN_MARGIN.
const MIN_MARGIN_BY_GESTURE: Dictionary = {
	"viento": 0.15,
	"flecha": 0.20,
}


## --- Interfaz pública ---

## Deja un gesto (lista de trazos) en su nube canónica de puntos. Es la
## MISMA función para reconocer y para grabar plantillas a propósito:
## una plantilla no es más que un gesto ya normalizado.
static func normalize(strokes: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var stroke_ids := PackedInt32Array()

	for stroke_index in range(strokes.size()):
		for p in strokes[stroke_index]:
			points.append(p)
			stroke_ids.append(stroke_index)

	if points.size() < 2:
		return PackedVector2Array()

	var resampled := _resample(points, stroke_ids, NUM_POINTS)
	if resampled.is_empty():
		return PackedVector2Array()

	return _translate_to_origin(_scale_to_unit(resampled))


## Devuelve {"name", "second_name", "score", "margin", "accepted"}.
## Lo que hay que mirar es `accepted`, no `score` (ver MIN_MARGIN).
##
## `second_name` existe SOLO para depurar, y se gana el sitio: el margen
## dice cuánto ha faltado, pero no contra QUIÉN, y sin eso un rechazo no
## se puede arreglar. Con el rival delante, "barrera rechazado al 4%" deja
## de ser mala suerte y pasa a ser "barrera y rombo se parecen demasiado",
## que ya es una frase sobre la que se puede actuar.
static func recognize(strokes: Array, templates: Dictionary,
		active: PackedStringArray = PackedStringArray()) -> Dictionary:
	var candidate := normalize(strokes)
	var unknown := {
		"name": "", "second_name": "", "score": 0.0, "margin": 0.0,
		"accepted": false, "needs_more_samples": true,
	}

	if candidate.is_empty():
		return unknown

	# Distancia al MEJOR ejemplar de cada gesto, no a cada plantilla
	# suelta: así tener cinco muestras de un gesto no le da ventaja
	# sobre otro que solo tenga dos.
	var best_per_gesture: Dictionary = {}
	for name in templates:
		var best := INF
		for template in templates[name]:
			if template.size() == candidate.size():
				best = minf(best, _cloud_distance(candidate, template))
		if best < INF:
			best_per_gesture[name] = best

	if best_per_gesture.is_empty():
		return unknown

	var first_name := ""
	var second_name := ""
	var first := INF
	var second := INF

	for name in best_per_gesture:
		var d: float = best_per_gesture[name]
		if d < first:
			second = first
			second_name = first_name
			first = d
			first_name = name
		elif d < second:
			second = d
			second_name = name

	# CON UN SOLO GESTO GRABADO NO SE PUEDE RECONOCER NADA.
	#
	# Antes aquí se aceptaba sin más —"es el único candidato posible"— y
	# fue un error serio. Al renombrar los elementos quedó una única
	# plantilla de elemento en la biblioteca, y el juego empezó a leer
	# CUALQUIER trazo como esa runa: círculos, triángulos y garabatos,
	# todo era viento. Y sin avisar, que es lo peor.
	#
	# El $P no mide "cuánto se parece" —eso está medido y no sirve para
	# decidir—, mide CUÁNTO LE SACA EL PRIMERO AL SEGUNDO. Sin segundo
	# no hay medida, y sin medida no hay reconocimiento. Lo honesto es
	# rechazar y que quien llame lo diga en voz alta.
	if second == INF:
		return {
			"name": first_name,
			"second_name": "",
			"score": 1.0 - first / HALF_DIAGONAL,
			"margin": 0.0,
			"accepted": false,
			"needs_more_samples": true,
		}

	var margin := (second - first) / maxf(first, 0.0001)

	# LOS GESTOS BLOQUEADOS SIGUEN AHÍ COMO SEÑUELOS, pero no como rivales.
	# Hacen falta en la biblioteca: si lo dibujado se parece más a uno de ellos
	# que a cualquier gesto activo, gana él y quien llama lo rechaza. Lo que no
	# debe pasar es que un señuelo parecido le quite el margen a un trazo bueno
	# de un gesto activo (un trazo de flecha que se parece un poco a levitación
	# no es un trazo dudoso: levitación no existe para el jugador). Por eso, si
	# el ganador está activo y hay otro activo, el margen se mide contra ESE.
	# Con un solo gesto activo no hay contra quién medir y se queda el margen de
	# siempre, contra todos.
	if active.size() >= 2 and active.has(first_name):
		var second_active := INF
		var second_active_name := ""
		for name in best_per_gesture:
			if name == first_name or not active.has(name):
				continue
			var d: float = best_per_gesture[name]
			if d < second_active:
				second_active = d
				second_active_name = name
		if second_active < INF:
			margin = (second_active - first) / maxf(first, 0.0001)
			second_name = second_active_name

	# LA CALIDAD DEL TRAZO: de 0 (justo en el límite de ser aceptado) a 1 (el
	# margen llega a QUALITY_FULL_MARGIN o más). Sale del mismo margen que decide
	# si se acepta, así que un trazo dudoso es también un trazo flojo.
	var umbral: float = MIN_MARGIN_BY_GESTURE.get(first_name, MIN_MARGIN)
	var calidad: float = clampf((margin - umbral) / maxf(QUALITY_FULL_MARGIN - umbral, 0.01), 0.0, 1.0)

	return {
		"name": first_name,
		"second_name": second_name,
		"score": 1.0 - first / HALF_DIAGONAL,
		"margin": margin,
		"quality": calidad,
		"accepted": margin >= umbral,
		"needs_more_samples": false,
	}


## --- Pasos del algoritmo ---

## Reparte `n` puntos a intervalos iguales por el recorrido.
##
## Los saltos ENTRE trazos no cuentan como recorrido: levantar el ratón
## no es dibujar. Si contaran, separar más los trazos cambiaría el
## gesto, y dos personas dibujando el mismo símbolo con los trazos más
## juntos o más sueltos obtendrían nubes distintas.
static func _resample(points: PackedVector2Array, ids: PackedInt32Array, n: int) -> PackedVector2Array:
	var total := _path_length(points, ids)
	if total <= 0.0:
		return PackedVector2Array()

	var interval := total / float(n - 1)
	var accumulated := 0.0

	var source := PackedVector2Array(points)
	var source_ids := PackedInt32Array(ids)
	var result := PackedVector2Array([source[0]])

	var i := 1
	while i < source.size():
		if source_ids[i] != source_ids[i - 1]:
			# Empieza un trazo nuevo: su primer punto entra tal cual.
			result.append(source[i])
			i += 1
			continue

		var segment := source[i - 1].distance_to(source[i])
		if segment <= 0.0:
			i += 1
			continue

		if accumulated + segment >= interval:
			var t := (interval - accumulated) / segment
			var new_point := source[i - 1].lerp(source[i], t)
			result.append(new_point)
			source.insert(i, new_point)
			source_ids.insert(i, source_ids[i])
			accumulated = 0.0
		else:
			accumulated += segment

		i += 1

	while result.size() < n:
		result.append(source[source.size() - 1])

	return result.slice(0, n)


## Escalado UNIFORME, a diferencia del $1 que deformaba la proporción.
## Aquí la proporción importa: fue justo estirar el rombo en vertical lo
## que dejó de confundirlo con el círculo.
static func _scale_to_unit(points: PackedVector2Array) -> PackedVector2Array:
	var box := _bounding_box(points)
	var size: float = maxf(maxf(box.size.x, box.size.y), 0.0001)

	var result := PackedVector2Array()
	for p in points:
		result.append((p - box.position) / size)
	return result


static func _translate_to_origin(points: PackedVector2Array) -> PackedVector2Array:
	var center := _centroid(points)
	var result := PackedVector2Array()
	for p in points:
		result.append(p - center)
	return result


## Distancia entre dos nubes. Se prueban varios puntos de partida y en
## ambos sentidos, quedándose con el mejor resultado.
static func _cloud_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	# Probar los n puntos de partida sería n veces más caro para casi
	# nada: con la raíz de n se da con el mínimo casi siempre. Es la
	# recomendación del propio artículo del $P.
	var step: int = maxi(1, int(round(sqrt(float(a.size())))))

	var best := INF
	var i := 0
	while i < a.size():
		best = minf(best, _greedy_match(a, b, i))
		best = minf(best, _greedy_match(b, a, i))
		i += step
	return best


## Empareja cada punto de una nube con el más cercano de la otra que
## siga libre.
##
## Los primeros emparejamientos pesan MÁS que los últimos: se hacen con
## toda la nube disponible, así que son los de fiar. Los últimos se
## conforman con los puntos que han sobrado y no deberían contar igual.
static func _greedy_match(a: PackedVector2Array, b: PackedVector2Array, start: int) -> float:
	var n := a.size()
	var matched := []
	matched.resize(n)
	matched.fill(false)

	var total := 0.0
	var weight_sum := 0.0
	var index := start

	for step in range(n):
		var closest := INF
		var closest_index := -1

		for j in range(n):
			if matched[j]:
				continue
			var d := a[index].distance_to(b[j])
			if d < closest:
				closest = d
				closest_index = j

		if closest_index < 0:
			break

		matched[closest_index] = true

		var weight := float(n - step) / float(n)
		total += weight * closest
		weight_sum += weight

		index = (index + 1) % n

	if weight_sum <= 0.0:
		return INF
	return total / weight_sum


## --- Utilidades ---

static func _path_length(points: PackedVector2Array, ids: PackedInt32Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		if ids[i] == ids[i - 1]:
			total += points[i - 1].distance_to(points[i])
	return total


static func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


static func _bounding_box(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box
