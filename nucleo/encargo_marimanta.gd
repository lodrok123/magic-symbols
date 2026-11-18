class_name EncargoMarimanta
extends RefCounted
## El primer encargo de la Maestre Marimanta (Monte-Sumicio.pptx, «Hacia el bosque» y Nivel I): trabajo de campo en el
## sendero norte de la Fraga (Bosque 02). Lo da Marimanta tras entregar el uniforme; se hace junto a la salida norte de
## Bosque 02 y se cierra hablando otra vez con ella, que abre el cofre legendario con la runa de agua.
## Todo vive en flags (sobreviven al cambio de nivel y al guardado); la misión del diario se DERIVA de ellas.

const MISION := "sumicio_encargo_campo"
const RECIBIDO := "montesumicio.encargo.recibido"
## 13/11 (Pablo): el hito del sendero se sustituye por cartografiar el 60 % de Bosque 02 (Cartografia).
const MAPA := "montesumicio.encargo.mapa"
const PLANTA := "montesumicio.encargo.planta"
const CRIATURA := "montesumicio.encargo.criatura"
const ENTREGADO := "montesumicio.encargo.entregado"
const COFRE_AGUA := "montesumicio.torre.cofre_agua"
## Como `global.glifo.<id>` de los cofres: un sello ganado se vuelve a desbloquear al montar cualquier nivel (Puzle3D).
const SELLO_GANADO := "global.sello."

const PASOS: Array = [MAPA, PLANTA, CRIATURA]
const TEXTOS_OBJETIVO: Array = [
	"Cartografía el 60 % de Bosque 02 (0 %)",
	"Identifica una planta para el herbario",
	"Registra una criatura en el bestiario",
	"Vuelve a la Torre Verde y habla con Marimanta",
]
## Lo que se lee al anotar cada cosa junto a la salida norte.
const AL_ANOTAR: Array = [
	"El mapa de Bosque 02 ya está cartografiado al 60 %.",
	"Helecho común de la fraga húmeda. Mid lo dibuja y guarda una hoja en el herbario.",
	"Un nido de mirlo entre las raíces. Mid lo registra en el bestiario: canto al alba, huevos azulados.",
]
const SIN_ENCARGO: Array = [
	"Un hito de piedra: «Monte Sumicio, cuesta arriba».",
	"Helechos de la fraga húmeda.",
	"Un nido entre las raíces.",
]


static func recibido() -> bool:
	return Flags.i().tiene(RECIBIDO)


static func pasos_hechos() -> int:
	var n := 0
	for f in PASOS:
		if Flags.i().tiene(String(f)):
			n += 1
	return n


static func listo_para_entregar() -> bool:
	return recibido() and pasos_hechos() == PASOS.size() and not Flags.i().tiene(ENTREGADO)


## Define la misión (si ya se recibió) y la pone al día con las flags. Idempotente: se puede llamar cada sondeo.
static func sincronizar() -> void:
	var mi := Misiones.i()
	if not recibido():
		return
	if not mi.existe(MISION):
		mi.definir({"id": MISION, "titulo": "Trabajo de campo", "tipo": "principal",
			"texto": "Para el Nivel I, Mid debe completar el bestiario y el herbario del grimorio y cartografiar la Fraga de Cailiag. Marimanta le pide empezar por el sendero norte, junto a la subida a Monte Sumicio.",
			"origen": "Maestre Marimanta", "objetivos": TEXTOS_OBJETIVO})
		mi.activar(MISION)
	var pc := Cartografia.porcentaje_de(Cartografia.NIVEL_ENCARGO)
	if pc >= Cartografia.META:
		Flags.i().poner(MAPA)
	mi.objetivo_texto(MISION, 0, "Cartografía el %d %% de Bosque 02 (%d %%)" % [Cartografia.META, mini(pc, 100)])
	for i in range(PASOS.size()):
		if Flags.i().tiene(String(PASOS[i])):
			mi.objetivo_hecho(MISION, i)
	if Flags.i().tiene(ENTREGADO):
		mi.completar(MISION)


## Anota el paso `i` (0 hito, 1 planta, 2 criatura). Devuelve el texto que hay que enseñar.
static func anotar(i: int) -> String:
	if not recibido():
		return String(SIN_ENCARGO[i])
	var f := String(PASOS[i])
	if Flags.i().tiene(f):
		return "Ya está anotado en el grimorio."
	Flags.i().poner(f)
	sincronizar()
	var texto := String(AL_ANOTAR[i])
	if pasos_hechos() == PASOS.size():
		texto += " Encargo listo: vuelve a la Torre Verde."
	return texto


## El sello de agua del cofre legendario: se desbloquea ya y queda apuntado para los demás niveles.
static func dar_sello_agua() -> void:
	Flags.i().poner(SELLO_GANADO + "agua")
	Repertoire.unlock_element("agua")


static func rearmar_sellos() -> void:
	for nombre in Flags.i().nombres(SELLO_GANADO):
		Repertoire.unlock_element(String(nombre).trim_prefix(SELLO_GANADO))
