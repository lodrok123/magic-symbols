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

## --- El glifo ---
## El dibujo con el que este elemento se firma en el núcleo del grimorio.
## Es un dato más del elemento, igual que su color o su daño: el libro no
## sabe qué elementos existen, solo pinta esta textura teñida con `color`.
##
## La textura es una SILUETA BLANCA sobre transparente, no un dibujo con
## sus colores. Eso es lo que permite teñirla: un glifo ya coloreado se
## ensuciaría al multiplicarlo por el color del elemento, y haría falta
## un PNG por elemento en cada tono que se quisiera probar.
##
## Un elemento sin glifo (ahora mismo tiempo, que está fuera del reparto)
## no rompe nada: el núcleo se queda con su nombre y ya está.
@export var glyph: Texture2D = null

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

## --- INTENSIDADES ---
##
## Un hechizo amplificado ya se veía más grande: spell.gd escala el nodo
## con la raíz de la potencia. Pero más grande no es más FUERTE — una
## llama pequeña ampliada sigue siendo la misma llama pequeña, y el
## aumento se lee como un fallo de escala antes que como poder.
##
## Con estas dos hojas de más, el fuego amplificado CAMBIA DE DIBUJO:
## lenguas sueltas -> columna de llama -> remolino. El tamaño lo sigue
## poniendo la potencia y estas hojas ponen la forma; cada cosa hace una
## sola cosa, y por eso no se estorban.
##
## Son opcionales. Los seis elementos que no las rellenen se quedan con
## su hoja de siempre y funcionan exactamente igual que antes: esto no
## es una obligación nueva, es una posibilidad.
##
## Tres huecos explícitos y no un array porque el número de fotogramas
## va emparejado a su hoja, y dos arrays en paralelo son justo la clase
## de cosa que acaba descuadrada el día que se añade media intensidad.
@export var vfx_sheet_mid: Texture2D = null
@export var vfx_frames_mid: int = 0

@export var vfx_sheet_high: Texture2D = null
@export var vfx_frames_high: int = 0

## A partir de qué potencia se sube de intensidad. Coinciden con lo que
## aporta el sello: 'amplificar' multiplica por 2, así que uno da 2 y dos
## dan 4. No es casualidad, pero tampoco está atado: si mañana el sello
## multiplicara por 1.5, aquí solo habría que mover el corte.
const POWER_MID: float = 2.0
const POWER_HIGH: float = 4.0


## El elemento sabe cómo presentarse. Así, los dos sitios que animan un
## efecto (el hechizo y la hierba ardiendo) no repiten la configuración
## —ni el riesgo de que una copia se quede desfasada si mañana cambia el
## número de columnas.
##
## Devuelve false si este elemento no tiene animación (el vapor), para
## que quien llame sepa que debe recurrir a pintar su color a secas.
## `power` es opcional: quien no sepa de potencias —la hierba ardiendo,
## por ejemplo— llama como siempre y recibe la hoja normal.
func setup_sprite(sprite: Sprite2D, power: float = 1.0) -> bool:
	var hoja: Texture2D = vfx_sheet
	var cuantos: int = vfx_frames

	if power >= POWER_HIGH and vfx_sheet_high != null and vfx_frames_high > 0:
		hoja = vfx_sheet_high
		cuantos = vfx_frames_high
	elif power >= POWER_MID and vfx_sheet_mid != null and vfx_frames_mid > 0:
		hoja = vfx_sheet_mid
		cuantos = vfx_frames_mid

	if hoja == null or cuantos <= 0:
		return false

	sprite.texture = hoja
	sprite.hframes = VFX_COLUMNS
	# La última fila puede quedar a medias (19 fotogramas en 6 columnas
	# son 4 filas con 5 celdas vacías). No pasa nada: al avanzar la
	# animación se cuenta hasta vfx_frames, no hasta el total de celdas.
	sprite.vframes = ceili(float(cuantos) / float(VFX_COLUMNS))
	sprite.frame = 0
	return true


## Cuántos fotogramas tiene la hoja que le tocaría a esta potencia.
## Quien anima necesita saberlo, y no debería tener que repetir la
## decisión de arriba para averiguarlo.
func frames_for(power: float = 1.0) -> int:
	if power >= POWER_HIGH and vfx_sheet_high != null and vfx_frames_high > 0:
		return vfx_frames_high
	if power >= POWER_MID and vfx_sheet_mid != null and vfx_frames_mid > 0:
		return vfx_frames_mid
	return vfx_frames
