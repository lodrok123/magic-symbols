class_name Estado
extends RefCounted

## EL ESTADO DE LA PARTIDA que viaja con el jugador: oro, mochila y mejoras.
##
## Es un único objeto compartido (Estado.i()). Quien necesite oro o inventario lo pide
## aquí; quien quiera enterarse de cambios escucha `cambiado`. No dibuja nada.
##
## MOCHILA. Cada hueco guarda una pila de UN solo tipo de objeto, hasta `Objetos.pila(id)` unidades (columna `pila` de objetos.tsv: 20 los ingredientes, 9 los frascos,
## 1 la ropa y las llaves, 999 el oro; 9 si el objeto no está en la tabla). `PILA_MAX` (9) queda solo como el valor de siempre para quien aún la lea (bolsa_ui.gd).
## Empieza con CAPACIDAD_INICIAL huecos y el alquimista la sube hasta CAPACIDAD_MAX.

signal cambiado
signal enemigo_muerto(pos: Vector2, id: String)
signal objeto_conseguido(id: String)

const CAPACIDAD_INICIAL: int = 8
const CAPACIDAD_MAX: int = 20
const PILA_MAX: int = 9
const VIDA_BASE: float = 100.0
const CURA_BASE: float = 40.0          ## = la cura de `pocion` en objetos.tsv (antes 35, sin nadie que la leyera)
const VEL_BASE: float = 100.0

static var _inst: Estado = null

var oro: int = 0
var capacidad: int = CAPACIDAD_INICIAL
var items: Dictionary = {}        ## id -> cantidad
var mejoras: Dictionary = {}      ## id de mejora -> nivel
var vida_max: float = VIDA_BASE
var cura_pocion: float = CURA_BASE
var vel_extra: float = 0.0
## F3 (29/10): DEF plana de la jugadora que dan las mejoras (`Mejoras`, campo `defensa`). La de la ropa puesta se suma aparte (`Ropa3D.defensa_ids`) en `Jugador3D.defensa_total`.
var defensa: float = 0.0
## Huecos de partida: la bolsa vale `capacidad_base` + lo que dé la mejora `capacidad`. Se guarda el TOTAL (`bolsa.capacidad`) y al cargar se deduce la base,
## de modo que `Mejoras.aplicar_todas()` es idempotente (calcula desde la base, no acumula).
var capacidad_base: int = CAPACIDAD_INICIAL
## 24/10 (HUD estilo Echoes of Wisdom): lo que viaja con la partida del menú y los frascos. `frascos_tinta`: frascos de reserva de tinta llenos (los usa
## `Tinta`; empieza con los de `Tinta.FRASCOS_INICIALES`). `consumible_equipado`: el consumible que gasta Q ("" = ninguno; lo gestiona `Consumibles`).
var frascos_tinta: int = 3          ## = Tinta.FRASCOS_INICIALES (literal para no cruzar las dos clases en un inicializador)
var consumible_equipado: String = ""
## 10/11 (docs/PROPUESTA_CONSUMIBLES.md §2): la RUEDA DE LANZABLES, acceso rápido de HUECOS_RUEDA huecos (uno por dirección; "" = vacío). Lo que va en cada hueco se
## elige en la mochila (`poner_en_rueda`); el hueco recuerda el objeto aunque se acabe. `rueda_elegido` = el hueco que lanza la G. `rueda_vistos`: los lanzables
## que ya se han cogido alguna vez (el primero de cada uno entra solo en un hueco libre; luego, la jugadora manda).
const HUECOS_RUEDA: int = 6
var rueda: Array = ["", "", "", "", "", ""]
var rueda_elegido: int = 0
var rueda_vistos: Array = []
var bosque_retorno_cueva: String = "" ## Bosque desde el que se entró en Cueva.
## ASISTENCIA AL TRAZO (Fase 14.4): 0 = dibujar como siempre (no se calcula nada); 1 = ayuda máxima. La guía fantasma y el imán del
## trazo (tope 0,6 de fuerza) escalan con esto. Empieza en 0,5: ayuda sin quitarle protagonismo a la mano. Es una opción del jugador,
## no una mejora: no se pierde ni se compra.
var asistencia: float = 0.5
## TRAZO RECTO (Fase 14.4, 16/10): lo dibujado se convierte en tramos rectos en las ocho direcciones del compás (GestureRectify), y
## eso es lo que se ve, se reconoce y se graba. Sin rejilla: solo se corrigen las direcciones. `false` = trazo libre, como antes.
var trazo_recto: bool = true
## LANZAMIENTO INTELIGENTE (27/10, A1): `true` = pulsar 1/2/3 lanza al instante hacia el ratón, sin indicador. `false` = mantener la tecla enseña el indicador y soltar lanza. Opción del jugador; la lee `Lanzador3D`.
var lanzamiento_inteligente: bool = false


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
		n += int(ceil(float(items[id]) / float(Objetos.pila(String(id)))))
	return n


## Cuántas unidades de `id` caben todavía: los huecos libres a la pila de ESE objeto, más lo que le falta a su última pila para llenarse.
func sitio_para(id: String) -> int:
	var pila: int = Objetos.pila(id)
	var libres: int = capacidad - huecos_usados()
	var actual: int = cuenta(id)
	var resto_pila: int = (pila - actual % pila) % pila
	return libres * pila + resto_pila


## Mete `n` unidades; devuelve cuántas entraron de verdad.
func agregar(id: String, n: int = 1) -> int:
	var cabe: int = mini(n, sitio_para(id))
	if cabe <= 0:
		return 0
	items[id] = cuenta(id) + cabe
	_rueda_al_coger(id)
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


## Compatibilidad: sube la bolsa `n` huecos. Pasa por `Mejoras.subir("capacidad", self)` (cada nivel da `por_nivel` = 4 huecos; se suben los niveles que hagan falta para
## cubrir `n`). Si la mejora ya está en su tope, no hace nada.
func subir_capacidad(n: int) -> void:
	var por: int = maxi(1, int(BD.mejora("capacidad").get("por_nivel", 4)))
	for _i in range(maxi(1, int(ceil(float(n) / float(por))))):
		Mejoras.subir("capacidad", self)


## --- Guardado (F2 de PLAN_BASE_DATOS, 29/10) ---
## `Partida` pide `a_dic()` y reparte cada trozo en su sección del archivo: `bolsa` (oro, capacidad, items), `mejoras`, y, dentro de `jugadora`,
## `consumible_equipado`, `bosque_retorno_cueva` y `opciones`. Lo derivado de las mejoras (`vida_max`, `cura_pocion`, `defensa`, `vel_extra`) NO se guarda: `Mejoras.aplicar_todas()` lo recalcula
## desde `mejoras` al cargar (F3). Los frascos de tinta viajan en la sección `tinta` (`Tinta.a_dic`), que a su vez los deja en `frascos_tinta`.
func a_dic() -> Dictionary:
	return {
		"bolsa": {"oro": oro, "capacidad": capacidad, "items": items.duplicate()},
		"mejoras": mejoras.duplicate(),
		"consumible_equipado": consumible_equipado,
		"rueda": {"huecos": rueda.duplicate(), "elegido": rueda_elegido, "vistos": rueda_vistos.duplicate()},
		"bosque_retorno_cueva": bosque_retorno_cueva,
		"opciones": {"asistencia": asistencia, "trazo_recto": trazo_recto, "lanzamiento_inteligente": lanzamiento_inteligente},
	}


## Sustituye lo guardado. Una clave que falte vuelve a su valor de partida nueva. JSON da los números como float: aquí vuelven a entero.
func desde_dic(d: Dictionary) -> void:
	var b: Dictionary = d.get("bolsa", {}) if d.get("bolsa", {}) is Dictionary else {}
	oro = maxi(0, int(b.get("oro", 0)))
	capacidad = clampi(int(b.get("capacidad", CAPACIDAD_INICIAL)), 1, CAPACIDAD_MAX)
	capacidad_base = capacidad          # se corrige abajo, cuando ya se conocen las mejoras
	items = {}
	var it: Dictionary = b.get("items", {}) if b.get("items", {}) is Dictionary else {}
	for id in it:
		var n: int = int(it[id])
		if n > 0:
			items[String(id)] = n
	mejoras = {}
	var mj: Dictionary = d.get("mejoras", {}) if d.get("mejoras", {}) is Dictionary else {}
	for id in mj:
		mejoras[String(id)] = int(mj[id])
	consumible_equipado = String(d.get("consumible_equipado", ""))
	var r: Dictionary = d.get("rueda", {}) if d.get("rueda", {}) is Dictionary else {}
	rueda = []
	var huecos: Array = r.get("huecos", []) if r.get("huecos", []) is Array else []
	for k in range(HUECOS_RUEDA):
		rueda.append(String(huecos[k]) if k < huecos.size() else "")
	rueda_elegido = clampi(int(r.get("elegido", 0)), 0, HUECOS_RUEDA - 1)
	rueda_vistos = []
	for v in (r.get("vistos", []) if r.get("vistos", []) is Array else []):
		rueda_vistos.append(String(v))
	bosque_retorno_cueva = String(d.get("bosque_retorno_cueva", ""))
	var o: Dictionary = d.get("opciones", {}) if d.get("opciones", {}) is Dictionary else {}
	asistencia = clampf(float(o.get("asistencia", 0.5)), 0.0, 1.0)
	trazo_recto = bool(o.get("trazo_recto", true))
	lanzamiento_inteligente = bool(o.get("lanzamiento_inteligente", false))
	capacidad_base = clampi(capacidad - int(Mejoras.valor("capacidad", self)), 1, CAPACIDAD_MAX)
	Mejoras.aplicar_todas(self, false)           # vida máxima, cura, defensa, velocidad, bolsa, frascos y libro salen de las mejoras
	cambiado.emit()


## --- Rueda de lanzables (10/11) ---

## Pone `id` en el hueco `hueco` (0..HUECOS_RUEDA-1). Un objeto solo está en un hueco: si ya estaba en otro, sale de él; si el hueco estaba ocupado, los dos
## cambian de sitio. false si `id` no es un lanzable o el hueco no existe.
func poner_en_rueda(id: String, hueco: int) -> bool:
	if not Objetos.es_lanzable(id) or hueco < 0 or hueco >= HUECOS_RUEDA:
		return false
	var antes: int = rueda.find(id)
	var habia: String = String(rueda[hueco])
	rueda[hueco] = id
	if antes >= 0 and antes != hueco:
		rueda[antes] = habia
	if not rueda_vistos.has(id):
		rueda_vistos.append(id)
	cambiado.emit()
	return true


## Quita `id` de la rueda (su hueco queda vacío). false si no estaba.
func quitar_de_rueda(id: String) -> bool:
	var k: int = rueda.find(id)
	if k < 0:
		return false
	rueda[k] = ""
	cambiado.emit()
	return true


## El lanzable del hueco elegido ("" si está vacío).
func lanzable_elegido() -> String:
	return String(rueda[clampi(rueda_elegido, 0, HUECOS_RUEDA - 1)])


func elegir_hueco(hueco: int) -> void:
	rueda_elegido = clampi(hueco, 0, HUECOS_RUEDA - 1)
	cambiado.emit()


## La primera vez que se coge un lanzable entra solo en el primer hueco libre (y, si el elegido estaba vacío, pasa a ser el elegido).
func _rueda_al_coger(id: String) -> void:
	if not Objetos.es_lanzable(id) or rueda_vistos.has(id):
		return
	rueda_vistos.append(id)
	if rueda.has(id):
		return
	var libre: int = rueda.find("")
	if libre < 0:
		return
	rueda[libre] = id
	if lanzable_elegido() == "":
		rueda_elegido = libre
