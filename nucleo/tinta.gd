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
## 10/11 (docs/PROPUESTA_CONSUMIBLES.md §6, decisiones de Pablo): los pigmentos pasan a ser de UNA CARGA (`efecto` «carga», `dura` 0): se carga uno y el
## SIGUIENTE hechizo de SU elemento sale con `valor` (1,5) de daño (`mult_dano`) y de geometría (`mult_geometria`). Si se lanza otro elemento la carga se
## queda. Solo uno cargado: cargar otro sustituye al anterior (`Sintesis.aplicar_pigmento` devuelve el frasco anterior a la mochila). Siete: uno por
## elemento y el de eco (que quita el recargo de ᚱ a un hechizo). «rebaja» y «dano» con `dura` siguen funcionando por si se quiere un pigmento temporal.
## CUÁNDO SE GASTA: lo ideal es que el Lanzador llame a `consumir_pigmento(elemento)` después de construir el hechizo (Hechizos). Mientras no lo haga,
## `gastar` lo consume al cobrar el hechizo de ese elemento y deja la carga «en vuelo» T_VUELO_PIGMENTO s: el Lanzador cobra ANTES de construir
## (`Lanzador3D.lanzar_ahora` → `_disparar` → `hechizo_de`, que multiplica el daño), así que sin esa ventana el ×1,5 no llegaría a ese hechizo.
##
## REGLA DEL 1/3 (plan EOW): ninguna rebaja baja un coste de menos de `REBAJA_MINIMA` (1/3) de su coste de partida, por mucho que
## valga `valor`: así un pigmento nunca vuelve gratis un hechizo y el coste sigue siendo una decisión.
##
## DÓNDE SE APLICA (un sitio cada uno): la rebaja, en `coste_efectivo` (lo usan `puede_pagar` y `gastar`; el Lanzador solo pasa el elemento);
## el daño, en `Lanzador3D._disparar` (multiplica `Hechizo.dano` con `mult_dano`) y, como todo lo que daña lee ese campo, llega igual al golpe, al
## área y al escudo.
##
## FRASCOS DE RESERVA (24/10, decisión de Pablo; referencia «Cargas y recarga» de Echoes of Wisdom): la barra es la tinta que gastas al lanzar y
## se regenera despacio, como siempre; ADEMÁS hay `FRASCOS_MAX` (3) frascos de reserva y se empieza con `FRASCOS_INICIALES` (3) llenos. Regla:
##   · si un gasto NO LLEGA con la barra (`actual` < coste) y queda un frasco lleno, se vacía UN frasco, la barra se rellena de golpe hasta `maxima`
##     y entonces se cobra el hechizo (el lanzamiento sale en vez de negarse). `puede_pagar` ya cuenta con el frasco, así que el Lanzador no cambia;
##   · si un gasto que SÍ llegaba deja la barra exactamente en 0 y queda un frasco, el frasco la rellena también (la barra nunca se queda vacía con reserva);
##   · un hechizo que costaría más que la barra entera (`coste` > `maxima`) no se paga ni con frasco: no se gasta ningún frasco en balde.
## Los frascos vacíos NO se recargan solos: se recargan con un consumible (el Tónico de tinta llama a `recargar_frasco`) o con `rellenar()`
## (fuentes, descanso, reaparecer: llena la barra Y los frascos). `rellenar_barra()` llena solo la barra. Los frascos viajan con la partida
## (`Estado.frascos_tinta`), así que cambiar de nivel no los repone gratis.

signal cambiada                               ## cualquier cambio de cantidad, de máximo o de pigmento (para repintar)
signal frasco_gastado                         ## un frasco lleno se ha vaciado para rellenar la barra (el HUD lo anima y avisa)
signal frasco_recargado(indice: int)           ## un frasco vacío se ha llenado (tónico de tinta); `indice` = el último que se llenó (el HUD lo destella)
signal insuficiente(forma: String, coste: float, hay: float)
signal pigmento_acabado(id: String)           ## el pigmento temporal se ha agotado (ya ha vuelto el base)
signal reaccion_premiada(tipo: String, cantidad: float)   ## una reacción de combo ha dado tinta (el HUD pinta el «+20» y el nombre)

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
const PIGMENTO_DURA: float = 60.0             ## s por defecto que dura un pigmento temporal (los de la tabla de hoy son de una carga: `dura` 0)
const PIGMENTO_X: float = 1.5                 ## 10/11: lo que multiplica un pigmento de carga el daño y la geometría del siguiente hechizo de su elemento
const T_VUELO_PIGMENTO: float = 0.8           ## s que el pigmento ya cobrado sigue valiendo para el hechizo en construcción: cubre el conjuro más lento (tierra, 0,56 s) y es menos que la recarga mínima (1 s), así no potencia dos
const REGEN: float = 3.0                      ## tinta/s fuera de combate: llenar entera tarda ~33 s
const REGEN_COMBATE: float = 1.0              ## con enemigos encima, a un tercio
const ESPERA_TRAS_GASTAR: float = 1.2         ## s sin recuperar justo después de lanzar (si no, el coste real sería menor)
const UMBRAL_BAJA: float = 0.25               ## por debajo se pinta en rojo ("baja tinta")
const FRASCOS_MAX: int = 3                    ## huecos de frasco de reserva DE PARTIDA. Con la mejora `frascos_tinta` hay más: usa `frascos_max()` / `maxima_frascos()`
const FRASCOS_INICIALES: int = 3              ## frascos llenos con los que empieza la partida

## TINTA POR REACCIÓN (C2, 28/10, decisión de Pablo): +20 de tinta cada vez que provocas un COMBO contra un enemigo (lo bastante para no ignorarlo, poco para
## farmear). Solo cuentan las reacciones que piden pensar (`REACCIONES_PREMIADAS`: tipo -> rótulo del HUD); el daño simple, el quemado normal o el empujón
## suelto NO. Tope anti-farming: una vez por ENEMIGO y por TIPO (se anota en el propio enemigo, así sobrevive a recrear la tinta). Los muñecos y dianas
## (`premia_tinta` = false o grupo «muneco») no dan nada. Solo sube la BARRA hasta `maxima`; no toca los frascos. Ver `premiar_reaccion`.
const TINTA_POR_REACCION: float = 20.0
const REACCIONES_PREMIADAS: Dictionary = {"hundido": "¡Hundido!", "electrocutado": "¡Electrocutado!", "congelado": "¡Congelado!",
	"mano_quemada": "¡Mano quemada!", "apagado": "¡Apagado!", "roto": "¡Roto!", "llamarada": "¡Llamarada!",
	"enraizado": "¡Enraizado!"}   # 6/11 bloque B: el remate del congelado y el contagio del viento (reacciones de dos pasos) · R3: la naturaleza que lo sujeta

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
	# 10/11: los siete de la tabla son de UNA CARGA (×PIGMENTO_X al daño y a la geometría del siguiente hechizo de su elemento; `dura` 0 = no caducan).
	"resina_carmesi": {"nombre": "Resina Carmesí", "color": Color(0.85, 0.20, 0.22), "zona": "bosque", "elemento": "fuego", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	"azul_rocio": {"nombre": "Azul de Rocío", "color": Color(0.35, 0.71, 0.94), "zona": "bosque", "elemento": "agua", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	"ocre_tumulo": {"nombre": "Ocre del Túmulo", "color": Color(0.80, 0.58, 0.22), "zona": "tumulo", "elemento": "tierra", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	"blanco_escarcha": {"nombre": "Blanco de Escarcha", "color": Color(0.85, 0.94, 1.0), "zona": "cumbre", "elemento": "hielo", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	"ambar_volcanico": {"nombre": "Ámbar Volcánico", "color": Color(0.95, 0.55, 0.12), "zona": "volcan", "elemento": "rayo", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	"verde_musgo": {"nombre": "Verde de Musgo", "color": Color(0.38, 0.72, 0.30), "zona": "bosque_humedo", "elemento": "viento", "efecto": "carga", "valor": PIGMENTO_X, "dura": 0.0},
	# El de eco: una carga que quita el recargo del 25 % de tinta del glifo `glifo` (ᚱ, id `raido`) a UN hechizo. `elemento` va vacío (no es de ningún sello). Quien
	# calcula el coste (`Dano.tinta`, Hechizos) tiene que preguntar `quita_recargo(glifo)` y gastarla con `consumir_pigmento("", glifo)`.
	"azul_eco": {"nombre": "Azul de Eco", "color": Color(0.42, 0.72, 1.0), "zona": "cueva", "elemento": "", "efecto": "sin_recargo", "glifo": "raido", "valor": 1.0, "dura": 0.0},
}
const PIGMENTO_BASE: String = "azul_arcano"

var actual: float = MAXIMA_INICIAL
var maxima: float = MAXIMA_INICIAL
var pigmento: String = PIGMENTO_BASE
var frascos: int = FRASCOS_INICIALES            ## frascos de reserva llenos (0..FRASCOS_MAX); lo cambian `gastar`, `recargar_frasco` y `rellenar`
var partida: Estado = null                    ## de dónde salen los jefes/secretos ganados; null = el de la partida (`Estado.i()`). Las pruebas inyectan uno propio
var _espera: float = 0.0
var _t_pigmento: float = 0.0                  ## s que le quedan al pigmento activo (0 con el base y con los de carga, que no caducan)
var _vuelo: String = ""                       ## el pigmento de carga ya cobrado que aún vale para el hechizo en construcción ("" = ninguno)
var _t_vuelo: float = 0.0


func _init() -> void:
	maxima = maxima_calculada()
	actual = maxima
	frascos = clampi(Estado.i().frascos_tinta, 0, frascos_max())       # los frascos viajan con la partida (otra sala, reaparecer sin descanso)


func _est() -> Estado:
	return partida if partida != null else Estado.i()


## F3: los huecos de frasco que hay ahora = los de partida + el nivel de la mejora `frascos_tinta` (3 → 6). Estático: lee el `Estado` de la partida (o el que se le pase).
static func frascos_max(e: Estado = null) -> int:
	return FRASCOS_MAX + Mejoras.nivel("frascos_tinta", e)


func maxima_frascos() -> int:
	return frascos_max(_est())


## F3: lo que deja un frasco en la barra al gastarse = `maxima × (1 + 0,1 × nivel de tinta_frasco)`. Por encima de `maxima` es un colchón: se gasta primero y no se regenera.
func tinta_por_frasco() -> float:
	return maxima * (1.0 + Mejoras.valor("tinta_frasco", _est()))


## F3: ¿el pigmento activo quita el recargo del glifo `glifo`? (Azul de Eco con ᚱ). Lo pregunta quien calcula el coste de un hechizo (Hechizos).
func quita_recargo(glifo: String) -> bool:
	var p: Dictionary = PIGMENTOS[pigmento]
	return String(p["efecto"]) == "sin_recargo" and String(p.get("glifo", "")) == glifo


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


## 29/10 (DANO_Y_TINTA): el coste de un hechizo YA NO sale del volumen (antes `coste_receta`, 10 × tamaño relativo, con `COSTE_BASE_V2`): sale de su POTENCIA, en `Dano.tinta`
## (ligera 8 · media 18 · alta 34, × (1 + recargos de glifos especiales)). Aquí solo se cobra: `puede_pagar` y `gastar` reciben ese coste y `coste_efectivo` le aplica la rebaja del pigmento.


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


## El factor de daño de un hechizo de `elemento` con el pigmento activo (1 = sin cambio). Lo aplica `Lanzador3D._disparar`. Cuenta el de carga y el que está «en vuelo».
func mult_dano(elemento: String) -> float:
	if elemento == "":
		return 1.0
	var p: Dictionary = PIGMENTOS[pigmento]
	if (String(p["efecto"]) == "dano" or String(p["efecto"]) == "carga") and String(p["elemento"]) == elemento:
		return float(p["valor"])
	if _t_vuelo > 0.0 and String(PIGMENTOS[_vuelo]["elemento"]) == elemento:
		return float(PIGMENTOS[_vuelo]["valor"])
	return 1.0


## 10/11: el factor de GEOMETRÍA (alcance, semiejes, radio) del siguiente hechizo de `elemento` (1 = sin cambio). Solo los pigmentos de carga. Lo tiene que
## aplicar quien construye el hechizo (Hechizos); hasta entonces el ×1,5 solo llega al daño.
func mult_geometria(elemento: String) -> float:
	if elemento == "":
		return 1.0
	var p: Dictionary = PIGMENTOS[pigmento]
	if String(p["efecto"]) == "carga" and String(p["elemento"]) == elemento:
		return float(p["valor"])
	if _t_vuelo > 0.0 and String(PIGMENTOS[_vuelo]["elemento"]) == elemento:
		return float(PIGMENTOS[_vuelo]["valor"])
	return 1.0


## 10/11: ¿hay un pigmento de carga cargado? (el HUD tiñe la barra y el aro del libro mientras lo haya).
func pigmento_cargado() -> bool:
	return pigmento != PIGMENTO_BASE and String(PIGMENTOS[pigmento]["efecto"]) in ["carga", "sin_recargo"] and float(PIGMENTOS[pigmento]["dura"]) <= 0.0


## El elemento del pigmento activo ("" con el base o con el de eco).
func elemento_pigmento() -> String:
	return String(PIGMENTOS[pigmento]["elemento"])


## 10/11: gasta la carga si es de `elemento` (el de eco: `elemento` vacío y `glifo` = ᚱ). Devuelve si gastó algo. La carga queda «en vuelo» T_VUELO_PIGMENTO s
## para el hechizo que se está construyendo. Lo llama `gastar` (puente) y, cuando Hechizos lo conecte, el Lanzador tras construir el hechizo.
func consumir_pigmento(elemento: String, glifo: String = "") -> bool:
	if not pigmento_cargado():
		return false
	var p: Dictionary = PIGMENTOS[pigmento]
	var es_suyo: bool = (elemento != "" and String(p["elemento"]) == elemento) or (String(p["efecto"]) == "sin_recargo" and glifo != "" and String(p.get("glifo", "")) == glifo)
	if not es_suyo:
		return false
	var gastado: String = pigmento
	_vuelo = gastado
	_t_vuelo = T_VUELO_PIGMENTO
	pigmento = PIGMENTO_BASE
	cambiada.emit()
	pigmento_acabado.emit(gastado)
	return true


## Segundos que le quedan al pigmento temporal (0 con el base).
func tiempo_pigmento() -> float:
	return _t_pigmento


## `coste` >= 0 manda sobre la tabla de formas (receta V2: lo calcula `coste_receta`); -1 = el de siempre, por forma.
## `elemento` (opcional) deja que un pigmento de rebaja de ese elemento abarate el coste (ver `coste_efectivo`).
## Cuenta con los frascos: si la barra no llega pero hay un frasco lleno y el coste cabe en una barra entera, SE PUEDE pagar (`gastar` lo hará).
func puede_pagar(forma: String, coste: float = -1.0, elemento: String = "") -> bool:
	var c: float = coste_efectivo(coste if coste >= 0.0 else coste_de(forma), elemento)
	return actual + 1e-4 >= c or (frascos > 0 and c <= maxima + 1e-4)


## Descuenta el coste de la forma. Si no alcanza ni con un frasco, NO descuenta nada (no hay lanzamientos a medias) y avisa por `insuficiente`.
## Con frasco: si la barra no llega, se vacía un frasco y la barra vuelve a `maxima` ANTES de cobrar; si tras cobrar la barra queda en 0 y queda
## otro frasco, ese también la rellena (ver «FRASCOS DE RESERVA» arriba).
func gastar(forma: String, coste: float = -1.0, elemento: String = "") -> bool:
	var c: float = coste_efectivo(coste if coste >= 0.0 else coste_de(forma), elemento)
	if actual + 1e-4 < c:
		if frascos > 0 and c <= maxima + 1e-4:
			_vaciar_frasco()
		else:
			insuficiente.emit(forma, c, actual)
			return false
	actual = maxf(0.0, actual - c)
	if actual <= 1e-4 and frascos > 0:
		_vaciar_frasco()
	_espera = ESPERA_TRAS_GASTAR
	consumir_pigmento(elemento)            # 10/11: el pigmento de carga de ese elemento se gasta con este hechizo (puente: ver «CUÁNDO SE GASTA»)
	cambiada.emit()
	return true


## Un frasco lleno se vacía y la barra se rellena entera (la barra pasa a `maxima`).
func _vaciar_frasco() -> void:
	frascos -= 1
	actual = tinta_por_frasco()
	_guardar_frascos()
	frasco_gastado.emit()
	cambiada.emit()


func _guardar_frascos() -> void:
	_est().frascos_tinta = frascos


func frascos_vacios() -> int:
	return maxima_frascos() - frascos


## Recarga `n` frascos vacíos (lo hace el Tónico de tinta con 1). Devuelve cuántos recargó de verdad (0 si ya estaban todos llenos).
func recargar_frasco(n: int = 1) -> int:
	var antes: int = frascos
	frascos = clampi(frascos + n, 0, maxima_frascos())
	if frascos != antes:
		_guardar_frascos()
		cambiada.emit()
		frasco_recargado.emit(frascos - 1)         # gamefeel U8: el HUD destella el frasco que acaba de llenarse
	return frascos - antes


func recuperar(cantidad: float) -> void:
	var antes: float = actual
	actual = clampf(actual + cantidad, 0.0, maxima)
	if not is_equal_approx(antes, actual):
		cambiada.emit()


## Solo la barra (no toca los frascos).
func rellenar_barra() -> void:
	recuperar(maxima)


## Fuente, descanso o reaparecer: la barra Y los frascos, llenos.
func rellenar() -> void:
	recuperar(maxima)
	recargar_frasco(maxima_frascos())


## Regeneración natural. `en_combate` la frena a un tercio.
func actualizar(delta: float, en_combate: bool) -> void:
	if _t_vuelo > 0.0:
		_t_vuelo = maxf(0.0, _t_vuelo - delta)
		if _t_vuelo <= 0.0:
			_vuelo = ""
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


## C2 (28/10): premia con `TINTA_POR_REACCION` una reacción de combo `tipo` (clave de `REACCIONES_PREMIADAS`) provocada en `enemigo`. Devuelve la tinta que ha
## subido de verdad (0 si no cuenta). Es el ÚNICO sitio por donde entra esta tinta. No cuenta si: el tipo no está en la lista, el enemigo no es válido o es un
## muñeco/diana (`premia_tinta` false, o en el grupo «muneco»), o ya dio ese tipo (marca `tinta_reaccion_<tipo>` en el enemigo). Con la barra ya llena no
## se gasta el premio (no se marca): queda disponible para la próxima vez. Nunca pasa de `maxima`.
func premiar_reaccion(enemigo: Object, tipo: String) -> float:
	if not REACCIONES_PREMIADAS.has(tipo) or enemigo == null or not is_instance_valid(enemigo):
		return 0.0
	if enemigo is Node and (enemigo as Node).is_in_group("muneco"):
		return 0.0
	if enemigo.get("premia_tinta") == false:
		return 0.0
	var marca: String = "tinta_reaccion_" + tipo
	if enemigo.has_meta(marca) or actual >= maxima - 1e-4:
		return 0.0
	var antes: float = actual
	recuperar(TINTA_POR_REACCION)
	var ganada: float = actual - antes
	if ganada <= 0.0:
		return 0.0
	enemigo.set_meta(marca, true)
	reaccion_premiada.emit(tipo, ganada)
	PlayLog.event("tinta_reaccion", {"tipo": tipo, "enemigo": String(enemigo.get("nombre")) if enemigo.get("nombre") != null else str(enemigo.name),
		"tinta": snappedf(ganada, 0.1)})
	return ganada


## --- Guardado (F2 de PLAN_BASE_DATOS, 29/10) ---
## Es la sección `tinta` del archivo de partida. `maxima` NO se guarda: sale de las mejoras (`maxima_calculada`), que `Partida` carga antes.
func a_dic() -> Dictionary:
	return {"actual": actual, "frascos": frascos, "pigmento": pigmento, "pigmento_s": _t_pigmento}


## Sustituye el estado. Claves que falten → barra llena, frascos de partida y pigmento base. Un pigmento que ya no exista vuelve al base.
func desde_dic(d: Dictionary) -> void:
	maxima = maxima_calculada()
	actual = clampf(float(d.get("actual", maxima)), 0.0, maxima)
	frascos = clampi(int(d.get("frascos", FRASCOS_INICIALES)), 0, maxima_frascos())
	_guardar_frascos()
	var p: String = String(d.get("pigmento", PIGMENTO_BASE))
	pigmento = p if PIGMENTOS.has(p) else PIGMENTO_BASE
	_t_pigmento = maxf(0.0, float(d.get("pigmento_s", 0.0))) if pigmento != PIGMENTO_BASE and float(PIGMENTOS[pigmento]["dura"]) > 0.0 else 0.0
	_vuelo = ""
	_t_vuelo = 0.0
	_espera = 0.0
	cambiada.emit()
