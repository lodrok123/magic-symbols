class_name Tinta
extends RefCounted

## LA TINTA: el "maná" del juego (15/10, Juego). Cada hechizo cuesta tinta según su FORMA; se recupera sola, despacio, y más despacio aún
## si te están pegando. No dibuja nada ni conoce al jugador: quien la use le pasa el tiempo (`actualizar`) y la pinta.
##
## Por qué el coste va por FORMA y no por glifo suelto: es lo que pidió Pablo ("por tipo de hechizo": flecha 10, barrera 25, círculo 35,
## espiral 50) y la forma ya sale resuelta de `Receta3D.forma()`, así el coste no depende de en qué orden se pusieron los glifos.
##
## TOTAL CERRADO (E1, 21/10, decisión de Pablo). Como en Eternal Wizard, la tinta máxima que se puede llegar a tener está CERRADA de antemano:
## se empieza con `MAXIMA_INICIAL` (100) y el tope es `MAXIMA_TOTAL` (300). Los +200 que se pueden ganar se reparten 60 % jefes (+120)
## y 40 % secretos (+80) entre `JEFES` y `SECRETOS` hallazgos, así que cada jefe da +30 y cada secreto +10. Por qué cerrado: el jugador sabe
## qué le falta, no se puede «farmear» más barra y el equilibrio de los costes se calcula contra un máximo conocido. Las COMPRAS NO suben
## el máximo (las compras dan otras cosas). Todo son constantes con nombre para que Pablo las ajuste sin tocar código. La subida vive
## en `Estado.mejoras` ("tinta_jefe" y "tinta_secreto", nivel = cuántos se han conseguido), así viaja con la partida; `maxima` se
## calcula de ahí. El juego llamará a `ganar_jefe()` / `ganar_secreto()` al derrotar un jefe o hallar un secreto (aún no hay ninguno marcado).
##
## PIGMENTOS (E1): un pigmento es un AUMENTO TEMPORAL sobre un SELLO (elemento), no una rebaja permanente por grupo de formas. Cada uno
## potencia UN elemento durante `dura` segundos de una de dos maneras: «rebaja» (los hechizos de ese elemento cuestan `valor` veces su
## coste, p. ej. 0,5 = la mitad) o «dano» (hacen `valor` veces su daño, p. ej. 1,5 = +50 %). Al acabar el tiempo vuelve el azul arcano
## (base, sin efecto). Activar otro sustituye al anterior. Además tiñe la barra, como antes. La asignación de abajo es una PROPUESTA.
##
## REGLA DEL 1/3 (plan EOW): ninguna rebaja baja un coste de menos de `REBAJA_MINIMA` (1/3) de su coste de partida, por mucho que
## valga `valor`: así un pigmento nunca vuelve gratis un hechizo y el coste sigue siendo una decisión.
##
## DÓNDE SE APLICA (un sitio cada uno): la rebaja, en `coste_efectivo` (lo usan `puede_pagar` y `gastar`; el Lanzador solo pasa el elemento);
## el daño, en `Lanzador3D._disparar` (multiplica `Hechizo.dano` con `mult_dano`) y, como todo lo que daña lee ese campo, llega igual al golpe, al
## área y al escudo.

signal cambiada                               ## cualquier cambio de cantidad, de máximo o de pigmento (para repintar)
signal insuficiente(forma: String, coste: float, hay: float)
signal pigmento_acabado(id: String)           ## el pigmento temporal se ha agotado (ya ha vuelto el base)

## --- Tinta máxima: total cerrado (todo ajustable) ---
const MAXIMA_INICIAL: float = 100.0           ## la barra con la que empieza la partida
const MAXIMA_TOTAL: float = 300.0             ## techo absoluto, ganes lo que ganes
const REPARTO_JEFES: float = 0.6              ## fracción de lo ganable (TOTAL - INICIAL) que dan los jefes
const REPARTO_SECRETOS: float = 0.4           ## y la que dan los secretos (los dos repartos suman 1)
const JEFES: int = 4                          ## cuántos jefes dan tinta -> +30 cada uno con los valores de hoy
const SECRETOS: int = 8                       ## cuántos secretos dan tinta -> +10 cada uno
const MEJORA_JEFE: String = "tinta_jefe"      ## ids en Estado.mejoras (nivel = cuántos llevas)
const MEJORA_SECRETO: String = "tinta_secreto"

const MAXIMA: float = MAXIMA_INICIAL          ## alias antiguo = la barra de partida (es el techo de `coste_receta`: los costes se miden contra ella)
const REBAJA_MINIMA: float = 1.0 / 3.0        ## ninguna rebaja baja un coste de este tanto por uno de su coste de partida
const PIGMENTO_DURA: float = 60.0             ## s por defecto que dura un pigmento
const REGEN: float = 3.0                      ## tinta/s fuera de combate: llenar entera tarda ~33 s
const REGEN_COMBATE: float = 1.0              ## con enemigos encima, a un tercio
const ESPERA_TRAS_GASTAR: float = 1.2         ## s sin recuperar justo después de lanzar (si no, el coste real sería menor)
const UMBRAL_BAJA: float = 0.25               ## por debajo se pinta en rojo ("baja tinta")

## Coste por forma de `Receta3D.forma()` (+ las formas de la geometría). Lo que no esté aquí cuesta `COSTE_DEFECTO`.
## Valores de partida de la lámina del concepto; están aquí para equilibrarlos sin tocar código.
const COSTE_DEFECTO: float = 20.0
const COSTES: Dictionary = {
	"proyectil": 10.0,    # flecha
	"punto": 10.0,        # elemento sin forma, en un punto
	"chorro": 15.0,
	"flotante": 20.0,
	"corro": 25.0,        # barrera: anillo / cúpula
	"muro": 25.0,
	"arco": 25.0,
	"columna": 25.0,
	"onda": 35.0,         # círculo que se expande
}

## id -> {nombre, color, zona, elemento, efecto, valor, dura}. "azul_arcano" es la tinta base: sin zona, sin efecto.
## PROPUESTA de asignación (ajustable): carmesí -> fuego, daño ×1,5 · ocre -> tierra, rebaja ×0,5 · musgo -> viento, rebaja ×0,5 · ámbar -> rayo, daño ×1,5.
const PIGMENTOS: Dictionary = {
	"azul_arcano": {"nombre": "Azul Arcano", "color": Color(0.30, 0.55, 1.0), "zona": "", "elemento": "", "efecto": "", "valor": 1.0, "dura": 0.0},
	"resina_carmesi": {"nombre": "Resina Carmesí", "color": Color(0.85, 0.20, 0.22), "zona": "bosque", "elemento": "fuego", "efecto": "dano", "valor": 1.5, "dura": PIGMENTO_DURA},
	"ocre_tumulo": {"nombre": "Ocre del Túmulo", "color": Color(0.80, 0.58, 0.22), "zona": "tumulo", "elemento": "tierra", "efecto": "rebaja", "valor": 0.5, "dura": PIGMENTO_DURA},
	"verde_musgo": {"nombre": "Verde de Musgo", "color": Color(0.38, 0.72, 0.30), "zona": "bosque_humedo", "elemento": "viento", "efecto": "rebaja", "valor": 0.5, "dura": PIGMENTO_DURA},
	"ambar_volcanico": {"nombre": "Ámbar Volcánico", "color": Color(0.95, 0.55, 0.12), "zona": "volcan", "elemento": "rayo", "efecto": "dano", "valor": 1.5, "dura": PIGMENTO_DURA},
}
const PIGMENTO_BASE: String = "azul_arcano"

var actual: float = MAXIMA_INICIAL
var maxima: float = MAXIMA_INICIAL
var pigmento: String = PIGMENTO_BASE
var partida: Estado = null                     ## de dónde salen los jefes/secretos ganados; null = el de la partida (`Estado.i()`). Las pruebas inyectan uno propio
var _espera: float = 0.0
var _t_pigmento: float = 0.0                  ## s que le quedan al pigmento activo (0 con el base)


func _init() -> void:
	maxima = maxima_calculada()
	actual = maxima


func _est() -> Estado:
	return partida if partida != null else Estado.i()


## Lo que sube la barra cada jefe / cada secreto: el reparto de lo ganable (TOTAL - INICIAL) entre cuántos hay.
static func por_jefe() -> float:
	return (MAXIMA_TOTAL - MAXIMA_INICIAL) * REPARTO_JEFES / float(JEFES)


static func por_secreto() -> float:
	return (MAXIMA_TOTAL - MAXIMA_INICIAL) * REPARTO_SECRETOS / float(SECRETOS)


## La tinta máxima según lo ganado, con el techo `MAXIMA_TOTAL` (aunque alguien toque los niveles a mano).
func maxima_calculada() -> float:
	var e: Estado = _est()
	var m: float = MAXIMA_INICIAL + float(mini(e.nivel(MEJORA_JEFE), JEFES)) * por_jefe() + float(mini(e.nivel(MEJORA_SECRETO), SECRETOS)) * por_secreto()
	return minf(m, MAXIMA_TOTAL)


## Un jefe derrotado: +`por_jefe()` al máximo. Devuelve false si ya se llevan todos (no sube más). Lo ganado entra también en la barra
## (si no, subirías el máximo y verías la barra a medias como castigo).
func ganar_jefe() -> bool:
	return _ganar(MEJORA_JEFE, JEFES)


## Un secreto hallado: +`por_secreto()`. Mismo contrato que `ganar_jefe`.
func ganar_secreto() -> bool:
	return _ganar(MEJORA_SECRETO, SECRETOS)


func _ganar(id: String, tope: int) -> bool:
	var e: Estado = _est()
	if e.nivel(id) >= tope:
		return false
	e.mejoras[id] = e.nivel(id) + 1
	var antes: float = maxima
	maxima = maxima_calculada()
	actual = minf(maxima, actual + (maxima - antes))
	e.cambiado.emit()
	cambiada.emit()
	return true


## R3 (17/10): con la receta V2 el coste ya no sale de una forma con nombre sino de las medidas (`Sigils.coste_v2`: la esfera base vale 1,
## crece con el volumen y con el nº de propiedades). Aquí se pasa a tinta: la esfera base cuesta lo que un `punto` (10) y el techo es la barra.
const COSTE_BASE_V2: float = 10.0


static func coste_receta(coste_relativo: float) -> float:
	return clampf(COSTE_BASE_V2 * coste_relativo, COSTE_BASE_V2, MAXIMA)


## Cuánto cuesta una forma de hechizo.
static func coste_de(forma: String) -> float:
	return float(COSTES.get(forma, COSTE_DEFECTO))


## El pigmento que da una zona ("" si la zona no tiene: se queda el base).
static func pigmento_de_zona(zona: String) -> String:
	for id in PIGMENTOS:
		if zona != "" and String(PIGMENTOS[id]["zona"]) == zona:
			return String(id)
	return PIGMENTO_BASE


func fraccion() -> float:
	return clampf(actual / maxf(maxima, 1.0), 0.0, 1.0)


## "normal" · "recuperando" (por debajo del máximo y con la espera ya cumplida) · "baja" · "sin_tinta".
func estado() -> String:
	if actual <= 0.0:
		return "sin_tinta"
	if fraccion() < UMBRAL_BAJA:
		return "baja"
	if actual < maxima - 0.01 and _espera <= 0.0:
		return "recuperando"
	return "normal"


func color() -> Color:
	return PIGMENTOS[pigmento]["color"]


func nombre_pigmento() -> String:
	return String(PIGMENTOS[pigmento]["nombre"])


## Un coste rebajado por `valor` (< 1), sin bajar nunca de `REBAJA_MINIMA` de su coste de partida. Una `valor` >= 1 no rebaja.
static func rebajar(coste: float, valor: float) -> float:
	return coste * clampf(valor, REBAJA_MINIMA, 1.0)


## EL ÚNICO SITIO DE LA REBAJA: lo que cuesta de verdad un hechizo de `elemento` con el pigmento activo. Si el pigmento no es de
## rebaja, o es de otro elemento (o no se dice elemento), el coste es el de partida.
func coste_efectivo(coste: float, elemento: String = "") -> float:
	var p: Dictionary = PIGMENTOS[pigmento]
	if elemento != "" and String(p["efecto"]) == "rebaja" and String(p["elemento"]) == elemento:
		return rebajar(coste, float(p["valor"]))
	return coste


## El factor de daño de un hechizo de `elemento` con el pigmento activo (1 = sin cambio). Lo aplica `Lanzador3D._disparar`.
func mult_dano(elemento: String) -> float:
	var p: Dictionary = PIGMENTOS[pigmento]
	if elemento != "" and String(p["efecto"]) == "dano" and String(p["elemento"]) == elemento:
		return float(p["valor"])
	return 1.0


## Segundos que le quedan al pigmento temporal (0 con el base).
func tiempo_pigmento() -> float:
	return _t_pigmento


## `coste` >= 0 manda sobre la tabla de formas (receta V2: lo calcula `coste_receta`); -1 = el de siempre, por forma.
## `elemento` (opcional) deja que un pigmento de rebaja de ese elemento abarate el coste (ver `coste_efectivo`).
func puede_pagar(forma: String, coste: float = -1.0, elemento: String = "") -> bool:
	return actual + 1e-4 >= coste_efectivo(coste if coste >= 0.0 else coste_de(forma), elemento)


## Descuenta el coste de la forma. Si no alcanza, NO descuenta nada (no hay lanzamientos a medias) y avisa por `insuficiente`.
func gastar(forma: String, coste: float = -1.0, elemento: String = "") -> bool:
	var c: float = coste_efectivo(coste if coste >= 0.0 else coste_de(forma), elemento)
	if actual + 1e-4 < c:
		insuficiente.emit(forma, c, actual)
		return false
	actual = maxf(0.0, actual - c)
	_espera = ESPERA_TRAS_GASTAR
	cambiada.emit()
	return true


func recuperar(cantidad: float) -> void:
	var antes: float = actual
	actual = clampf(actual + cantidad, 0.0, maxima)
	if not is_equal_approx(antes, actual):
		cambiada.emit()


func rellenar() -> void:
	recuperar(maxima)


## Regeneración natural. `en_combate` la frena a un tercio.
func actualizar(delta: float, en_combate: bool) -> void:
	if _t_pigmento > 0.0:                       # el reloj del pigmento corre siempre (también durante la espera de tras gastar)
		_t_pigmento = maxf(0.0, _t_pigmento - delta)
		if _t_pigmento <= 0.0:
			var acabado: String = pigmento
			pigmento = PIGMENTO_BASE
			cambiada.emit()
			pigmento_acabado.emit(acabado)
	if _espera > 0.0:
		_espera = maxf(0.0, _espera - delta)
		return
	if actual < maxima:
		recuperar((REGEN_COMBATE if en_combate else REGEN) * delta)


## Activa un pigmento durante su `dura` (el base no caduca). Sustituye al anterior. Devuelve false si no existe.
func activar_pigmento(id: String) -> bool:
	if not PIGMENTOS.has(id):
		return false
	pigmento = id
	_t_pigmento = float(PIGMENTOS[id]["dura"])
	cambiada.emit()
	return true


## Nombre antiguo (paso 1): ahora es lo mismo que activar.
func poner_pigmento(id: String) -> bool:
	return activar_pigmento(id)


## Pasa al siguiente pigmento de la lista (comando de prueba mientras no haya crafteo). Devuelve el id nuevo.
func siguiente_pigmento() -> String:
	var ids: Array = PIGMENTOS.keys()
	var i: int = ids.find(pigmento)
	poner_pigmento(String(ids[(i + 1) % ids.size()]))
	return pigmento
