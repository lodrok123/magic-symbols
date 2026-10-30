class_name Botin
extends RefCounted

## BOTÍN: UNA SOLA FORMA DE TIRAR Y UNA SOLA DE CAER (F1 de docs/PLAN_BASE_DATOS.md, 29/10).
##
## Antes había tres: `Rompible3D.BOTIN_ZONA` (cifras en código), `BotinGoblin` (colmillo directo a la bolsa) y `CofrePuzle.da=`. Ahora todo lo que reparte algo (jarrones, hierba
## segada, árboles sacudidos, setos quemados, enemigos al morir, cofres con `da=tabla:<id>`) llama a `Botin.tirar(tabla)` y a `Botin.soltar(mundo, pos, lista)`.
## Las cifras viven en `nucleo/datos/botin_tablas.tsv` (las lee `BD.tabla`), no aquí: añadir un enemigo o un jarrón nuevo es una fila.
##
## LA TABLA. Una fila = `objeto, peso, min, max, independiente`. `nada` es una fila más (en EoW la mayoría de los jarrones salen vacíos).
##   · Filas normales: UNA tirada ponderada por `peso` (`n_tiradas` veces si se pide); sale una fila y de ella `min`..`max` unidades.
##   · Filas con `independiente = si`: cada una hace SU PROPIA tirada con probabilidad `peso` (0..1; 1 = siempre) además de la ponderada. Así el goblin da oro siempre Y el colmillo el 60 %.
## El resultado es una lista de `{que: String, n: int}` (el oro es `que == "oro"`).
##
## LAS PRUEBAS: `tirada_forzada` (>= 0) sustituye al azar en TODAS las tiradas de `tirar` (la ponderada, la independiente y la cantidad dentro de min..max). Es el mismo gancho que tenían
## `Rompible3D.tirada_forzada` y `BotinGoblin.tirada_forzada`.

## Tabla a la que se vuelve cuando la de una zona no existe (el jarrón sin zona conocida da lo del bosque, como antes daba `BOTIN_DEFECTO`).
const ZONA_DEFECTO: String = "bosque"
const NADA: String = "nada"
const ORO: String = "oro"

## Solo para las pruebas: >= 0 sustituye al azar. -1 = al azar.
static var tirada_forzada: float = -1.0


## `<base>_<zona>` si esa tabla existe; si no, `<base>_bosque`. Con `luz` y `botin_zona` (los datos de `Zonas3D`) prueba en el mismo orden que usaba Rompible3D: primero el `botin=`
## de la zona, luego su nombre, luego el de su luz.
static func tabla_de_zona(base: String, zona: String, luz: String = "", botin_zona: String = "") -> String:
	for z in [botin_zona, zona, luz]:
		if String(z) != "" and not BD.tabla("%s_%s" % [base, z]).is_empty():
			return "%s_%s" % [base, z]
	return "%s_%s" % [base, ZONA_DEFECTO]


## ¿Existe la tabla (tiene alguna fila)?
static func existe(tabla: String) -> bool:
	return not BD.tabla(tabla).is_empty()


## Haz la tirada de `tabla`. `n_tiradas` repite la ponderada (las independientes se tiran una vez). Devuelve [{que, n}], sin `nada` ni cantidades 0; las mismas cosas se suman.
static func tirar(tabla: String, n_tiradas: int = 1) -> Array:
	var filas: Array = BD.tabla(tabla)
	if filas.is_empty():
		push_warning("Botin: la tabla «%s» no existe o está vacía" % tabla)
		return []
	var ponderadas: Array = []
	var independientes: Array = []
	var total: float = 0.0
	for f in filas:
		if String((f as Dictionary).get("independiente", "")) == "si":
			independientes.append(f)
		else:
			ponderadas.append(f)
			total += float((f as Dictionary)["peso"])
	var res: Array = []
	if total > 0.0:
		for _i in range(maxi(n_tiradas, 0)):
			var f: Dictionary = _elegir(ponderadas, total, _azar())
			_anotar(res, f, _azar())
	for f in independientes:
		if _azar() < float((f as Dictionary)["peso"]):
			_anotar(res, f as Dictionary, _azar())
	return res


static func _azar() -> float:
	return randf() if tirada_forzada < 0.0 else tirada_forzada


## La fila que cae con la tirada `t` (0..1) sobre el peso total.
static func _elegir(filas: Array, total: float, t: float) -> Dictionary:
	var objetivo: float = clampf(t, 0.0, 0.999999) * total
	var acumulado: float = 0.0
	for f in filas:
		acumulado += float((f as Dictionary)["peso"])
		if objetivo < acumulado:
			return f as Dictionary
	return filas.back() as Dictionary


## Apunta `n` unidades de la fila en `res` (entre `min` y `max` según `t`), sumando si ya había de ese objeto. `nada` y las cantidades 0 no se apuntan.
static func _anotar(res: Array, f: Dictionary, t: float) -> void:
	var que: String = String(f["objeto"])
	if que == NADA:
		return
	var lo: int = int(f["min"])
	var hi: int = maxi(int(f["max"]), lo)
	var n: int = lo + int(floor(clampf(t, 0.0, 0.999999) * float(hi - lo + 1)))
	if n <= 0:
		return
	for e in res:
		if String((e as Dictionary)["que"]) == que:
			(e as Dictionary)["n"] = int((e as Dictionary)["n"]) + n
			return
	res.append({"que": que, "n": n})


## El rango [min, max] de un objeto en una tabla (Vector2i(0, 0) si no está). Para los jarrones con `botin=oro` o `botin=pocion` y para las pruebas.
static func rango(tabla: String, objeto: String) -> Vector2i:
	for f in BD.tabla(tabla):
		if String((f as Dictionary)["objeto"]) == objeto:
			return Vector2i(int((f as Dictionary)["min"]), int((f as Dictionary)["max"]))
	return Vector2i.ZERO


## Un entero entre `r.x` y `r.y` (ambos incluidos) con la misma tirada que el resto (`tirada_forzada` o azar).
static func entre(r: Vector2i) -> int:
	var hi: int = maxi(r.y, r.x)
	return r.x + int(floor(clampf(_azar(), 0.0, 0.999999) * float(hi - r.x + 1)))


## Lo que dice una celda `botin` de `reactivos_mapa.tsv` o el `da=` de un cofre: "tabla:<id>" (tira esa tabla), "<objeto>:<n>" o "<objeto>:<min>-<max>" (esa cantidad, al azar si hay rango),
## o "" / "-" (nada). Devuelve [{que, n}].
static func desde_texto(t: String) -> Array:
	var txt: String = t.strip_edges()
	if txt == "" or txt == "-":
		return []
	var kv: PackedStringArray = txt.split(":", true, 1)
	if kv.size() != 2:
		return []
	if kv[0] == "tabla":
		return tirar(kv[1])
	var cant: String = kv[1]
	var lo: int = 0
	var hi: int = 0
	if cant.contains("-"):
		var r: PackedStringArray = cant.split("-")
		lo = r[0].to_int()
		hi = r[1].to_int()
	else:
		lo = cant.to_int()
		hi = lo
	var n: int = entre(Vector2i(lo, hi))
	return [{"que": kv[0], "n": n}] if n > 0 else []


## La fila de `reactivos_mapa.tsv` de `pieza` cuyo `llega` incluye `via` (las alternativas van con «|»: "viento|golpe"); {} si no hay.
static func fila_reactivo(pieza: String, via: String) -> Dictionary:
	for f in BD.reactivos(pieza):
		if via in String((f as Dictionary).get("llega", "")).split("|"):
			return f as Dictionary
	return {}


## La jugadora del nivel (la del lanzador del grupo «spellcaster»); null si no hay árbol o no hay lanzador.
static func jugador_de(mundo: Node) -> Jugador3D:
	if mundo == null or not mundo.is_inside_tree():
		return null
	var lanz: Node = mundo.get_tree().get_first_node_in_group("spellcaster")
	return (lanz.get("jugador") as Jugador3D) if lanz != null and lanz.get("jugador") is Jugador3D else null


## Crea en `mundo` las piezas de `lista` (ver `tirar`) alrededor de `pos`: el oro es `Combate3D.Botin3D` (la moneda de siempre), todo lo demás `BotinObjeto3D`.
## Devuelve los nodos creados. `mundo` null o sin ser Node3D: no crea nada.
static func soltar(mundo: Node, pos: Vector3, lista: Array, jugador: Jugador3D = null) -> Array:
	var nodos: Array = []
	var m3: Node3D = mundo as Node3D
	if m3 == null:
		return nodos
	var jug: Jugador3D = jugador if jugador != null and is_instance_valid(jugador) else jugador_de(mundo)
	for it in lista:
		var que: String = String((it as Dictionary)["que"])
		var n: int = int((it as Dictionary)["n"])
		if n <= 0:
			continue
		if que == ORO:
			nodos.append(Combate3D.Botin3D.soltar(m3, jug, n, pos))
		else:
			nodos.append(BotinObjeto3D.soltar(m3, jug, que, n, pos))
	return nodos


## Atajo: tira la tabla y suelta lo que salga. Devuelve la lista (no los nodos).
static func tirar_y_soltar(tabla: String, mundo: Node, pos: Vector3, n_tiradas: int = 1) -> Array:
	var lista: Array = tirar(tabla, n_tiradas)
	soltar(mundo, pos, lista)
	return lista


# ---------------------------------------------------------------------------------------------------------------------
#  Hierba segada
# ---------------------------------------------------------------------------------------------------------------------

const T_HIERBA_DEFECTO: float = 60.0           ## s antes de que la misma casilla vuelva a dar algo al segarla (si `reactivos_mapa.tsv` no dice otra cosa)
static var _hierba_t: Dictionary = {}          ## Vector2i -> reloj (s) de la última vez que dio algo


## Lo llama `Mundo3D` cuando una casilla pasa a «segada». Tira la tabla de la hierba (`reactivos_mapa.tsv`: `hierba_segada`, casi siempre nada) y suelta lo que salga en la casilla, como mucho una vez
## por casilla y `cada_s` (60) s. La hierba que se quemó antes de segarse (casilla `quemada`) no da nada: es ceniza, no cosecha. `ahora` = reloj en s (-1 = el del motor; las pruebas lo pasan).
static func al_segar(mundo: Node, c: Vector2i, ahora: float = -1.0) -> Array:
	if not Terreno3D.hay_mundo():
		return []                               # sin terreno no hay suelo donde dejar nada (una prueba que solo mira el estado)
	if Terreno3D.estados != null and Terreno3D.estados.tiene(c, "quemada"):
		return []
	var t: float = ahora if ahora >= 0.0 else Time.get_ticks_msec() / 1000.0
	var fila: Dictionary = fila_reactivo("hierba", "golpe")
	var espera: float = float(fila.get("cada_s", 0)) if float(fila.get("cada_s", 0)) > 0.0 else T_HIERBA_DEFECTO
	if _hierba_t.has(c) and t - float(_hierba_t[c]) < espera:
		return []
	_hierba_t[c] = t
	var texto: String = String(fila.get("botin", ""))
	var lista: Array = desde_texto(texto) if texto != "" else tirar("hierba_segada")
	soltar(mundo, Terreno3D.centro_de(c, Terreno3D.y_pies(c)), lista)
	return lista


## Olvida cuándo se segó cada casilla (cambio de nivel, pruebas).
static func olvidar_hierba() -> void:
	_hierba_t.clear()
