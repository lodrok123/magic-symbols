class_name Tinta
extends RefCounted

## LA TINTA: el "maná" del juego (15/10, Juego). Cada hechizo cuesta tinta según su FORMA; se recupera sola, despacio, y más despacio aún
## si te están pegando. No dibuja nada ni conoce al jugador: quien la use le pasa el tiempo (`actualizar`) y la pinta.
##
## Por qué el coste va por FORMA y no por glifo suelto: es lo que pidió Pablo ("por tipo de hechizo": flecha 10, barrera 25, círculo 35,
## espiral 50) y la forma ya sale resuelta de `Receta3D.forma()`, así el coste no depende de en qué orden se pusieron los glifos.
##
## PIGMENTOS (paso 1): solo tiñen la barra. Cada zona tiene el suyo. El paso 2 (aún sin hacer) les dará un hechizo que potenciar
## (más daño, menos coste) y teñirá también el trazo; por eso cada pigmento ya guarda su `zona`, y `elemento` queda vacío hasta que
## Pablo decida a qué hechizo potencia cada uno.

signal cambiada                               ## cualquier cambio de cantidad o de pigmento (para repintar)
signal insuficiente(forma: String, coste: float, hay: float)

const MAXIMA: float = 100.0
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

## id -> {nombre, color, zona, elemento}. "azul_arcano" es la tinta base, sin zona.
const PIGMENTOS: Dictionary = {
	"azul_arcano": {"nombre": "Azul Arcano", "color": Color(0.30, 0.55, 1.0), "zona": "", "elemento": ""},
	"resina_carmesi": {"nombre": "Resina Carmesí", "color": Color(0.85, 0.20, 0.22), "zona": "bosque", "elemento": ""},
	"ocre_tumulo": {"nombre": "Ocre del Túmulo", "color": Color(0.80, 0.58, 0.22), "zona": "tumulo", "elemento": ""},
	"verde_musgo": {"nombre": "Verde de Musgo", "color": Color(0.38, 0.72, 0.30), "zona": "bosque_humedo", "elemento": ""},
	"ambar_volcanico": {"nombre": "Ámbar Volcánico", "color": Color(0.95, 0.55, 0.12), "zona": "volcan", "elemento": ""},
}
const PIGMENTO_BASE: String = "azul_arcano"

var actual: float = MAXIMA
var maxima: float = MAXIMA
var pigmento: String = PIGMENTO_BASE
var _espera: float = 0.0


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


func puede_pagar(forma: String) -> bool:
	return actual + 1e-4 >= coste_de(forma)


## Descuenta el coste de la forma. Si no alcanza, NO descuenta nada (no hay lanzamientos a medias) y avisa por `insuficiente`.
func gastar(forma: String) -> bool:
	var c: float = coste_de(forma)
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
	if _espera > 0.0:
		_espera = maxf(0.0, _espera - delta)
		return
	if actual < maxima:
		recuperar((REGEN_COMBATE if en_combate else REGEN) * delta)


func poner_pigmento(id: String) -> bool:
	if not PIGMENTOS.has(id):
		return false
	pigmento = id
	cambiada.emit()
	return true


## Pasa al siguiente pigmento de la lista (comando de prueba mientras no haya crafteo). Devuelve el id nuevo.
func siguiente_pigmento() -> String:
	var ids: Array = PIGMENTOS.keys()
	var i: int = ids.find(pigmento)
	poner_pigmento(String(ids[(i + 1) % ids.size()]))
	return pigmento
