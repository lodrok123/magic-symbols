class_name RuneData
extends Resource

## Un RuneData es una "ficha de propiedades" para un elemento
## (fuego, agua...). En vez de escribir un match{} nuevo cada vez
## que quieras que una runa haga algo distinto, le añades una
## propiedad aquí y la rellenas en el archivo .tres de ese elemento.
##
## Para crear un elemento nuevo en el futuro: duplica un .tres
## existente (por ejemplo fire_rune.tres), cambia sus valores, y
## regístralo en el diccionario rune_database de spellcaster.gd.
## No hace falta tocar ningún match{} ni ninguna otra función.

@export var rune_type: Runes.Type = Runes.Type.NONE
@export var display_name: String = ""
@export var color: Color = Color.WHITE

## Propiedades de combate
@export var damage: float = 0.0

## Etiquetas libres para que objetos del mundo (agua, hielo, plantas...)
## decidan cómo reaccionar sin que el elemento necesite saber que existen.
## Ejemplo de uso en un futuro WaterBlock.gd:
##   if rune_data.tags.has("frio"): _freeze()
@export var tags: Array[String] = []

## --- Efecto visual ---
## La animación del elemento, en un único PNG con los fotogramas
## colocados en REJILLA. Es un dato más del elemento, igual que su color
## o su daño: quien lo dibuja no necesita saber qué elemento es.
##
## En rejilla y no en una tira larga por una razón muy concreta: cada
## tarjeta gráfica tiene un tamaño máximo de textura, y en algunas es de
## solo 2048px. Una tira de 19 fotogramas de 128px medía 2432px de ancho
## y el juego fallaba al arrancar con "Texture dimensions exceed device
## maximum". La misma animación en 6 columnas mide 768px de ancho.
##
## Godot recorta la rejilla con `hframes` y `vframes`, y `frame` recorre
## las celdas de izquierda a derecha y de arriba abajo.
const VFX_COLUMNS: int = 6

@export var vfx_sheet: Texture2D = null
@export var vfx_frames: int = 0


## El elemento sabe cómo presentarse. Así, los dos sitios que animan un
## efecto (el hechizo y la hierba ardiendo) no repiten la configuración
## —ni el riesgo de que una copia se quede desfasada si mañana cambia el
## número de columnas.
##
## Devuelve false si este elemento no tiene animación (el vapor), para
## que quien llame sepa que debe recurrir a pintar su color a secas.
func setup_sprite(sprite: Sprite2D) -> bool:
	if vfx_sheet == null or vfx_frames <= 0:
		return false

	sprite.texture = vfx_sheet
	sprite.hframes = VFX_COLUMNS
	# La última fila puede quedar a medias (19 fotogramas en 6 columnas
	# son 4 filas con 5 celdas vacías). No pasa nada: al avanzar la
	# animación se cuenta hasta vfx_frames, no hasta el total de celdas.
	sprite.vframes = ceili(float(vfx_frames) / float(VFX_COLUMNS))
	sprite.frame = 0
	return true
