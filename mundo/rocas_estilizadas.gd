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

## TAMAÑOS (5/11/2026, docs/ROCAS_EMPUJABLES_2026-11-05.md). Se miden sobre el modelo ya a escala (alto = `Pieza3D.MEDIDA`; huella = el lado mayor de su planta, medido una vez y guardado):
##   "grande"  : alto ≥ ALTO_GRANDE (1,4) o huella ≥ HUELLA_GRANDE (1,4)   → muro fijo (roca_est_0 1,40 × 1,43 · roca_est_4 1,50 × 0,84)
##   "mediana" : alto de ALTO_MEDIANA (0,75) a menos de 1,4                  → se EMPUJA, pesa 2 (roca_est_1 1,30 × 1,16 · roca_est_2 1,30 × 1,14 · roca_est_3 0,90 × 1,38)
##   "pequena" : alto > ColisionPieza.ALTO_MIN_SOLIDO (0,45) y < 0,75        → se EMPUJA, pesa 1 (piedra_est_0 0,50 × 0,51)
##   "pisable" : alto ≤ 0,45                                                  → sin cuerpo, se pisa (piedra_est_1..4: 0,40 … 0,26); no se empuja
const ALTO_GRANDE: float = 1.4
const HUELLA_GRANDE: float = 1.4
const ALTO_MEDIANA: float = 0.75
const GRANDE: String = "grande"
const MEDIANA: String = "mediana"
const PEQUENA: String = "pequena"
const PISABLE: String = "pisable"
const PESO_TAM: Dictionary = {"mediana": 2, "pequena": 1}
## Qué modelo (índice neutro) se usa por defecto para cada tamaño de roca empujable (`roca_est_<n>` / `piedra_est_<n>`): la 1 es la mediana más «de bloque»; la 0 de las piedras es la única pequeña sólida.
const FORMA_DEFECTO: Dictionary = {"mediana": "roca_est_1", "pequena": "piedra_est_0"}
static var _huellas: Dictionary = {}

## Fuerza una variante (pruebas y capturas). "" = la del bioma.
static var forzar: String = ""


## El id neutro (sin variante) de cualquier id de roca: `roca_est_musgo_2` → `roca_est_2`.
static func id_neutro(id: String) -> String:
	return id.replace("_est_musgo_", "_est_").replace("_est_magma_", "_est_")


## Lado mayor de la planta del modelo (u, ya a escala de `Pieza3D.MEDIDA`). 0 si no hay modelo. Se mide una sola vez por id.
static func huella_de(id: String) -> float:
	var n: String = id_neutro(id)
	if _huellas.has(n):
		return float(_huellas[n])
	var v: Node3D = Pieza3D.crear_visual(n)
	var h: float = 0.0
	if v != null:
		var ab: AABB = Pieza3D._caja(v, Transform3D.IDENTITY)
		h = maxf(ab.size.x, ab.size.z)
		v.free()
	_huellas[n] = h
	return h


## Tamaño de una roca (`grande`, `mediana`, `pequena` o `pisable`) a partir de su alto y su huella; "" si no es una roca estilizada.
static func tamano_de(id: String) -> String:
	var n: String = id_neutro(id)
	if not (n.begins_with("roca_est_") or n.begins_with("piedra_est_")):
		return ""
	var alto: float = float(Pieza3D.MEDIDA.get(n, 0.0))
	if alto >= ALTO_GRANDE - 0.005 or huella_de(n) >= HUELLA_GRANDE - 0.005:
		return GRANDE
	if alto >= ALTO_MEDIANA:
		return MEDIANA
	if alto > ColisionPieza.ALTO_MIN_SOLIDO + ColisionPieza.ALTO_TOLERANCIA:
		return PEQUENA
	return PISABLE


## ¿Se puede empujar? Solo la mediana y la pequeña (la grande es muro; la pisable no tiene cuerpo).
static func empujable(id: String) -> bool:
	var t: String = tamano_de(id)
	return t == MEDIANA or t == PEQUENA


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
