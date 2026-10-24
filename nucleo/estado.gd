class_name Estado
extends RefCounted

## EL ESTADO DE LA PARTIDA que viaja con el jugador: oro, mochila y mejoras.
##
## Es un único objeto compartido (Estado.i()). Quien necesite oro o inventario lo pide
## aquí; quien quiera enterarse de cambios escucha `cambiado`. No dibuja nada.
##
## MOCHILA. Cada hueco guarda una pila de UN solo tipo de objeto, hasta PILA_MAX unidades.
## Empieza con CAPACIDAD_INICIAL huecos y el alquimista la sube hasta CAPACIDAD_MAX.

signal cambiado
signal enemigo_muerto(pos: Vector2, id: String)
signal objeto_conseguido(id: String)

const CAPACIDAD_INICIAL: int = 8
const CAPACIDAD_MAX: int = 20
const PILA_MAX: int = 9
const VIDA_BASE: float = 100.0
const CURA_BASE: float = 35.0
const VEL_BASE: float = 100.0

static var _inst: Estado = null

var oro: int = 0
var capacidad: int = CAPACIDAD_INICIAL
var items: Dictionary = {}        ## id -> cantidad
var mejoras: Dictionary = {}      ## id de mejora -> nivel
var vida_max: float = VIDA_BASE
var cura_pocion: float = CURA_BASE
var vel_extra: float = 0.0
## 24/10 (HUD estilo Echoes of Wisdom): lo que viaja con la partida del menú y los frascos. `frascos_tinta`: frascos de reserva de tinta llenos (los usa
## `Tinta`; empieza con los de `Tinta.FRASCOS_INICIALES`). `consumible_equipado`: el consumible que gasta Q ("" = ninguno; lo gestiona `Consumibles`).
var frascos_tinta: int = 3          ## = Tinta.FRASCOS_INICIALES (literal para no cruzar las dos clases en un inicializador)
var consumible_equipado: String = ""
## ASISTENCIA AL TRAZO (Fase 14.4): 0 = dibujar como siempre (no se calcula nada); 1 = ayuda máxima. La guía fantasma y el imán del
## trazo (tope 0,6 de fuerza) escalan con esto. Empieza en 0,5: ayuda sin quitarle protagonismo a la mano. Es una opción del jugador,
## no una mejora: no se pierde ni se compra.
var asistencia: float = 0.5
## TRAZO RECTO (Fase 14.4, 16/10): lo dibujado se convierte en tramos rectos en las ocho direcciones del compás (GestureRectify), y
## eso es lo que se ve, se reconoce y se graba. Sin rejilla: solo se corrigen las direcciones. `false` = trazo libre, como antes.
var trazo_recto: bool = true


static func i() -> Estado:
	if _inst == null:
		_inst = Estado.new()
	return _inst


## Partida nueva: borra todo (se llama al abrir un nivel).
static func nuevo() -> Estado:
	_inst = Estado.new()
	return _inst


func cuenta(id: String) -> int:
	return int(items.get(id, 0))


func huecos_usados() -> int:
	var n: int = 0
	for id in items:
		n += int(ceil(float(items[id]) / float(PILA_MAX)))
	return n


## Cuántas unidades de `id` caben todavía.
func sitio_para(id: String) -> int:
	var libres: int = capacidad - huecos_usados()
	var actual: int = cuenta(id)
	var resto_pila: int = (PILA_MAX - actual % PILA_MAX) % PILA_MAX
	return libres * PILA_MAX + resto_pila


## Mete `n` unidades; devuelve cuántas entraron de verdad.
func agregar(id: String, n: int = 1) -> int:
	var cabe: int = mini(n, sitio_para(id))
	if cabe <= 0:
		return 0
	items[id] = cuenta(id) + cabe
	objeto_conseguido.emit(id)
	cambiado.emit()
	return cabe


func quitar(id: String, n: int = 1) -> bool:
	if cuenta(id) < n:
		return false
	var resto: int = cuenta(id) - n
	if resto <= 0:
		items.erase(id)
	else:
		items[id] = resto
	cambiado.emit()
	return true


func dar_oro(n: int) -> void:
	oro += n
	cambiado.emit()


func gastar_oro(n: int) -> bool:
	if oro < n:
		return false
	oro -= n
	cambiado.emit()
	return true


func nivel(mejora: String) -> int:
	return int(mejoras.get(mejora, 0))


func subir_capacidad(n: int) -> void:
	capacidad = mini(CAPACIDAD_MAX, capacidad + n)
	cambiado.emit()
