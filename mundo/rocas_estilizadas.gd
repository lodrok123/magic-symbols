class_name RocasEstilizadas
extends RefCounted

## ROCAS ESTILIZADAS (pack LeLu, 4/11): UN ÚNICO SITIO que decide qué variante de roca se dibuja según el bioma, para el decorado y para los hechizos de tierra.
## Tres variantes, cada una con SU juego de texturas completo (nunca se mezclan):
##   "musgo"  (B, con musgo)                     → bosque (lo normal en exterior)              ids `roca_est_musgo_0..4`, `piedra_est_musgo_0..4`
##   "neutra" (A, parda)                         → cueva (estilo «cueva» de la maqueta o nivel de cueva)   ids `roca_est_0..4`, `piedra_est_0..4`
##   "magma"  (C, volcánica con venas; normal, roughness y emissive propios) → zona o nivel de lava    ids `roca_est_magma_0..4`, `piedra_est_magma_0..4`
## Cómo sabe el juego en qué bioma está: la maqueta (`prueba_test2.gd`) tiene `estilo` («bosque» por defecto, «cueva» en las escenas de cueva) y `nivel` (nombre del nivel).
## MAGMA: hoy NO existe ninguna marca de lava en el juego (ni estilo ni nivel). La tabla queda preparada: se activa con `estilo == "magma"`, con un nivel de `NIVELES_MAGMA`
## o con el metadato `bioma = "magma"` en la maqueta (una zona de lava puede ponérselo). Mientras no exista, ningún nivel saca magma.
## Uso: `RocasEstilizadas.id_de("piedra_est_2")` → el id de la variante del bioma actual; `RocasEstilizadas.id_de("piedra_est_2", "magma")` → de una concreta.

const MUSGO: String = "musgo"
const NEUTRA: String = "neutra"
const MAGMA: String = "magma"
## Niveles de cueva por nombre (las escenas de cueva ya traen `estilo = "cueva"`; esto cubre un nivel cargado sin él).
const NIVELES_CUEVA: Array = ["Cueva", "CuevaAgua", "CuevaResonante", "GrutaBatida", "Grutas", "SalaChaman", "SalaEmpuje", "SalaGolem", "SalaLimo"]
const NIVELES_MAGMA: Array = []
const ESTILOS_MAGMA: Array = ["magma", "lava", "volcan"]

## Fuerza una variante (pruebas y capturas). "" = la del bioma.
static var forzar: String = ""


## La variante para un estilo y un nombre de nivel (puro: es lo que prueba `prueba_rocas_estilizadas`).
static func variante_de(estilo: String, nivel: String, bioma: String = "") -> String:
	if bioma == MAGMA or ESTILOS_MAGMA.has(estilo) or NIVELES_MAGMA.has(nivel):
		return MAGMA
	if estilo == "cueva" or NIVELES_CUEVA.has(nivel):
		return NEUTRA
	return MUSGO


## La variante del bioma donde está el juego ahora (busca la maqueta en el árbol; sin maqueta, bosque).
static func variante_actual() -> String:
	if forzar != "":
		return forzar
	var m: Node = _maqueta()
	if m == null:
		return MUSGO
	return variante_de(str(m.get("estilo")), str(m.get("nivel")), str(m.get_meta("bioma", "")))


## El id con la variante: `roca_est_2` (neutra) → `roca_est_musgo_2` / `roca_est_magma_2`. Si ya trae variante, se respeta.
static func id_de(id_neutro: String, variante: String = "") -> String:
	var v: String = variante if variante != "" else variante_actual()
	if v == NEUTRA or not id_neutro.contains("_est_"):
		return id_neutro
	return id_neutro.replace("_est_", "_est_%s_" % v)


static func _maqueta() -> Node:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root == null:
		return null
	var cola: Array = [arbol.root]
	var prof: int = 0
	while not cola.is_empty() and prof < 4:
		var sig: Array = []
		for n in cola:
			if (n as Node).get("estilo") != null and (n as Node).get("nivel") != null:
				return n
			sig.append_array((n as Node).get_children())
		cola = sig
		prof += 1
	return null
