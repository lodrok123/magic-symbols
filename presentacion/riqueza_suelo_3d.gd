extends RefCounted
## RIQUEZA DEL SUELO DE HIERBA (26/11/2026). Pablo: «que el suelo con hierba, cuando se genere, también genere hierba corta, flores pequeñas, etc.
## Es solo para darle riqueza a la escena». Sobre todo suelo de hierba del nivel (letras `.` claro, `,` hierba corta y `v` hierba alta) siembra, por
## LOTES (MultiMesh, los de siempre de la maqueta), y SIN colisión:
##   · matas de hierba corta de varios modelos (papel `hierba_corta` de la tabla: pack Pure Nature, musgo, trébol de Lost Cave…),
##   · flores pequeñas en CORROS: cada mancha de flores lleva sobre todo UN modelo (papel `flor`),
##   · de vez en cuando una roca pequeña, una rama o una raíz caída (papeles `roca` y `tronco`),
##   · y, muy de vez en cuando, un resto de ruina suelto (papel `ruina`): en el BOSQUE enlaza con el bioma de las ruinas; con estilo «ruinas» hay muchos.
## Qué piezas valen y con qué peso: `presentacion/tabla_decorado_bioma.gd`. Qué cantidad: las constantes de aquí (Pablo las afina).
##
## Reglas: nunca sobre caminos `g`, losas `R`, agua, marcadores, piezas de puzle, cofres ni casillas ocupadas (bloqueadas, con runa, con pieza del `.tscn`,
## con algo ya puesto cerca); menos densidad en el CENTRO de los claros (zona de combate) y más en los bordes; manchas por ruido, no confeti
## uniforme; todo determinista: cada casilla y cada mata salen de la semilla del mapa (`semilla_decorado`) y de la posición, igual en cada partida.
## Lo llama `PruebaTest2._sembrar_riqueza_suelo` (interruptor `riqueza_suelo`) antes de construir los lotes. Sin `class_name`: se carga con preload.

const TABLA = preload("res://presentacion/tabla_decorado_bioma.gd")

## --- LA HIERBA CORTA ---
const HIERBA: Dictionary = {
	"tam_mancha": 3.4,        ## casillas: tamaño de las manchas de hierba corta (el ruido de valor; una mancha ≈ 1,5 × esto)
	"umbral": 0.40,           ## por debajo de este valor del ruido no hay matas (claro de tierra pelada); a partir de aquí entran
	"suave": 0.22,            ## de 0 a la densidad plena entre `umbral` y `umbral + suave`
	"por_casilla": 5.0,       ## matas por casilla en el corazón de una mancha, sobre `.` y en el borde del claro
	"zona_modelo": 2.6,       ## casillas: tamaño de la zona donde domina un mismo modelo de mata
	"pureza": 0.65,           ## probabilidad de que una mata sea del modelo que domina su zona (el resto, de cualquiera)
	"escala": Vector2(0.8, 1.3),
	"margen": 0.30,           ## u: distancia mínima al borde con una casilla que no es hierba (camino, agua, piedra…)
	"libre": 0.55,            ## u: distancia mínima a cualquier cosa ya puesta (adornos, piezas, marcadores)
	"modelos": 4,             ## modelos DISTINTOS de mata como mucho en cada trozo de 7×7 casillas (cada uno es un lote, o sea una llamada de dibujo más); 0 = sin límite
	"tope": 1800,             ## matas como mucho en el mapa
}
## --- LAS FLORES ---
const FLOR: Dictionary = {
	"tam_corro": 4.6,         ## casillas: tamaño de los corros de flores
	"umbral": 0.60,           ## solo los corazones de las manchas de ruido llevan flores (más alto = menos corros)
	"suave": 0.14,
	"por_casilla": 4.0,       ## flores por casilla en el corazón de un corro
	"zona_modelo": 5.0,       ## casillas: zona de un mismo modelo de flor (un corro es casi de una sola especie)
	"pureza": 0.85,
	"escala": Vector2(0.85, 1.25),
	"margen": 0.45,
	"libre": 0.35,
	"modelos": 3,             ## ídem para las flores
	"tope": 800,
}
## --- ROCAS PEQUEÑAS Y RAMAS ---
const ROCA: Dictionary = {"prob": 0.035, "tope": 45, "escala": Vector2(0.8, 1.3), "margen": 0.6, "libre": 0.9, "modelos": 2}
const TRONCO: Dictionary = {"prob": 0.030, "tope": 35, "escala": Vector2(0.85, 1.25), "margen": 0.6, "libre": 0.9, "modelos": 2}
## --- RESTOS DE RUINA SUELTOS (Stylescape) ---
## `prob`: probabilidad por casilla de claro de llevar un resto; en el bosque, casi ninguno (enlaza con el bioma ruinas); en el estilo «ruinas», muchos.
const RUINA: Dictionary = {
	"prob_bosque": 0.008, "tope_bosque": 6,
	"prob_ruinas": 0.045, "tope_ruinas": 80,
	"prob_pantano": 0.0, "tope_pantano": 0,
	"escala": Vector2(0.9, 1.1), "margen": 0.7, "libre": 1.1,
	"lejos_de_muro": 1,       ## casillas: en el BOSQUE, ni en las pegadas a un `#` (que no parezcan caídos de la masa de árboles); 0 = en cualquiera. En las ruinas, en cualquiera
}
## --- DÓNDE: más en los bordes de los claros, menos en el centro ---
const DENSIDAD: Dictionary = {
	"borde": 1.0,             ## multiplicador en las casillas pegadas a lo que no es hierba (la masa de árboles, el camino, el agua)
	"centro": 0.35,           ## ídem en el CENTRO del claro (zona de combate: que no se pierda lo que pasa)
	"radio_centro": 3,        ## casillas hasta lo no-hierba a partir de las cuales ya es «centro» (entre 1 y esto, se mezcla)
	# multiplicador por letra: `.` claro · `,` hierba corta (que ya lleva sus briznas) · `v` hierba alta (que la tapa; solo flores sueltas)
	"letra_hierba": {".": 1.0, ",": 0.55, "v": 0.0},
	"letra_flor": {".": 1.0, ",": 0.7, "v": 0.25},
}

var _stats: Dictionary = {}


## Siembra. `m` = la maqueta (PruebaTest2); `S` = lado de la casilla; `y` = altura del suelo (ALTO - HUNDIR); `estilo`; `semilla`; `con_pack`.
## Devuelve las cuentas: {"hierba": n, "flores": n, "rocas": n, "troncos": n, "ruinas": n, "especies": n}.
func sembrar(m: Node, S: float, y: float, estilo: String, semilla: int, con_pack: bool) -> Dictionary:
	_stats = {"hierba": 0, "flores": 0, "rocas": 0, "troncos": 0, "ruinas": 0, "especies": 0}
	if estilo == "cueva":
		return _stats
	var filas_hierba: Array = TABLA.filas(estilo, "hierba_corta", con_pack)
	var filas_flor: Array = TABLA.filas(estilo, "flor", con_pack)
	var filas_roca: Array = TABLA.filas(estilo, "roca", con_pack)
	var filas_tronco: Array = TABLA.filas(estilo, "tronco", con_pack)
	var filas_ruina: Array = TABLA.filas(estilo, "ruina", con_pack)
	var ocupado: Dictionary = m._ocupacion_adornos()
	var puzle: Dictionary = {}
	for q in m._celdas_puzle_del_mapa():
		puzle[q] = true
	var lado: int = m._lado
	var dist: Dictionary = _distancias(m, lado)
	var usadas: Dictionary = {}
	var sal: int = 700 + posmod(semilla, 997)
	var tope_ruina: int = int(RUINA["tope_" + _clave_ruina(estilo)])
	var prob_ruina: float = float(RUINA["prob_" + _clave_ruina(estilo)])
	for cz in range(lado):
		for cx in range(lado):
			var c := Vector2i(cx, cz)
			var l: String = m._letra(c)
			var es_hierba: bool = DENSIDAD["letra_hierba"].has(l)
			# 27/11 (`ruinas_completas`): una casilla con losa entera pintada en el suelo no lleva hierba ni flores, pero sí restos de ruina (escombros, piedras)
			var enlosada: bool = not (m._rc_enlosada as Dictionary).is_empty() and (m._rc_enlosada as Dictionary).has(c)
			if enlosada:
				es_hierba = false
			if not es_hierba and not (estilo == "ruinas" and (l == "R" or enlosada)):
				continue
			if not _apta(m, c, puzle, enlosada):
				continue
			var d: int = int(dist.get(c, 99))
			var centro: float = smoothstep(1.0, float(DENSIDAD["radio_centro"]), float(d))
			var dens_dist: float = lerpf(float(DENSIDAD["borde"]), float(DENSIDAD["centro"]), centro)
			if es_hierba:
				if int(_stats["hierba"]) < int(HIERBA["tope"]) and not filas_hierba.is_empty():
					var k_h: float = float(DENSIDAD["letra_hierba"][l]) * dens_dist * _mancha(m, c, sal + 1, HIERBA)
					_sembrar_celda(m, c, S, y, k_h * float(HIERBA["por_casilla"]), HIERBA, filas_hierba, ocupado, usadas, sal + 11, "hierba")
				if int(_stats["flores"]) < int(FLOR["tope"]) and not filas_flor.is_empty():
					var k_f: float = float(DENSIDAD["letra_flor"][l]) * dens_dist * _mancha(m, c, sal + 2, FLOR)
					_sembrar_celda(m, c, S, y, k_f * float(FLOR["por_casilla"]), FLOR, filas_flor, ocupado, usadas, sal + 12, "flores")
				var r: float = m._hash(cx, cz, sal + 20) % 10000 / 10000.0
				if r < float(ROCA["prob"]) * (1.0 - 0.6 * centro) and int(_stats["rocas"]) < int(ROCA["tope"]) and not filas_roca.is_empty():
					_sembrar_uno(m, c, S, y, filas_roca, ROCA, ocupado, usadas, sal + 21, "rocas")
				elif r > 1.0 - float(TRONCO["prob"]) * (1.0 - 0.6 * centro) and int(_stats["troncos"]) < int(TRONCO["tope"]) and not filas_tronco.is_empty():
					_sembrar_uno(m, c, S, y, filas_tronco, TRONCO, ocupado, usadas, sal + 22, "troncos")
			# restos de ruina (Stylescape): no en el centro del claro; cada uno es un nodo, no un lote
			if prob_ruina > 0.0 and int(_stats["ruinas"]) < tope_ruina and not filas_ruina.is_empty() and d >= (0 if estilo == "ruinas" else int(RUINA["lejos_de_muro"])) + 1:
				if m._hash(cx, cz, sal + 30) % 100000 / 100000.0 < prob_ruina:
					_poner_ruina(m, c, S, y, filas_ruina, ocupado, sal + 31)
	_stats["especies"] = usadas.size()
	for id in usadas:
		m._ids_sin_sombra[id] = true
	return _stats


func _clave_ruina(estilo: String) -> String:
	return "ruinas" if estilo == "ruinas" else ("pantano" if estilo == "pantano" else "bosque")


## Cuánta «mancha» hay en la casilla (0..1): ruido de valor de la maqueta (`_vruido`), con el umbral y la suavidad de `ajustes`.
func _mancha(m: Node, c: Vector2i, sal: int, ajustes: Dictionary) -> float:
	var n: float = m._vruido((Vector2(c) + Vector2(0.5, 0.5)) / float(ajustes.get("tam_mancha", ajustes.get("tam_corro", 4.0))), sal)
	n = n * 0.75 + m._vruido((Vector2(c) + Vector2(0.5, 0.5)) / (float(ajustes.get("tam_mancha", ajustes.get("tam_corro", 4.0))) * 0.4), sal + 5) * 0.25
	var u: float = float(ajustes["umbral"])
	return smoothstep(u, u + float(ajustes["suave"]), n)


## ¿Se puede poner decorado suelto en la casilla? Hierba o tierra pisable, sin nada de juego encima.
func _apta(m: Node, c: Vector2i, puzle: Dictionary, enlosada: bool = false) -> bool:
	if m._bloqueadas.has(c) or m._sin_hierba.has(c) or m._celdas_pieza.has(c) or puzle.has(c):
		return false
	if m._germinadas.has(c) or m._junto_a_agua(c):
		return false
	var t: int = m._tipo_suelo(c)
	return t == 0 or m._letra(c) == "R" or enlosada


## Distancia (en casillas, 1 = pegada) de cada casilla de hierba hasta la casilla más cercana que NO es hierba (`#`, camino, agua, losas, marcadores…).
## Se rellena desde el borde hacia dentro; lo que queda a `radio_centro` o más es el «centro» del claro.
func _distancias(m: Node, lado: int) -> Dictionary:
	var dist: Dictionary = {}
	var cola: Array = []
	var tope: int = int(DENSIDAD["radio_centro"])
	for cz in range(lado):
		for cx in range(lado):
			var c := Vector2i(cx, cz)
			if not DENSIDAD["letra_flor"].has(m._letra(c)):
				dist[c] = 0
				cola.append(c)
	var i: int = 0
	while i < cola.size():
		var c2: Vector2i = cola[i]
		i += 1
		var dc: int = int(dist[c2])
		if dc >= tope:
			continue
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c2 + dv
			if q.x < 0 or q.y < 0 or q.x >= lado or q.y >= lado or dist.has(q):
				continue
			dist[q] = dc + 1
			cola.append(q)
	return dist


## `esperado` piezas (entero + probabilidad del resto) repartidas por la casilla `c`, cada una con su modelo (el de la zona o uno cualquiera).
func _sembrar_celda(m: Node, c: Vector2i, S: float, y: float, esperado: float, aj: Dictionary, filas: Array, ocupado: Dictionary, usadas: Dictionary,
		sal: int, clave: String) -> void:
	if esperado <= 0.02:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = m._hash(c.x, c.y, sal)
	var n: int = int(esperado)
	if rng.randf() < esperado - float(n):
		n += 1
	for i in range(n):
		if int(_stats[clave]) >= int(aj["tope"]):
			return
		var p := Vector3((float(c.x) + rng.randf_range(0.06, 0.94)) * S, y, (float(c.y) + rng.randf_range(0.06, 0.94)) * S)
		if not _lejos(m, p, c, S, float(aj["margen"])) or _cerca(p, ocupado, S, float(aj["libre"])):
			continue
		var lista: Array = _del_trozo(m, filas, c, int(aj.get("modelos", 0)), sal)
		var zk := Vector2i(floori(p.x / (float(aj["zona_modelo"]) * S)), floori(p.z / (float(aj["zona_modelo"]) * S)))
		var domina: String = TABLA.elegir_de(lista, m._hash(zk.x, zk.y, sal + 50))
		var id: String = domina if rng.randf() < float(aj["pureza"]) else TABLA.elegir_de(lista, rng.randi())
		if _poner(m, S, id, p, aj, rng, ocupado, usadas):
			_stats[clave] = int(_stats[clave]) + 1


func _sembrar_uno(m: Node, c: Vector2i, S: float, y: float, filas: Array, aj: Dictionary, ocupado: Dictionary, usadas: Dictionary, sal: int, clave: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = m._hash(c.x, c.y, sal)
	var p := Vector3((float(c.x) + rng.randf_range(0.2, 0.8)) * S, y, (float(c.y) + rng.randf_range(0.2, 0.8)) * S)
	if not _lejos(m, p, c, S, float(aj["margen"])) or _cerca(p, ocupado, S, float(aj["libre"])):
		return
	if _poner(m, S, TABLA.elegir_de(_del_trozo(m, filas, c, int(aj.get("modelos", 0)), sal), rng.randi()), p, aj, rng, ocupado, usadas):
		_stats[clave] = int(_stats[clave]) + 1


## Las filas de `filas` que valen en el trozo de 7×7 casillas de `c`: como mucho `n` modelos distintos (elegidos por peso según el trozo y la semilla); el mismo
## trozo siempre da los mismos. Cada modelo distinto de un trozo es un lote (una llamada de dibujo) más. n = 0: todas.
var _trozos: Dictionary = {}


func _del_trozo(m: Node, filas: Array, c: Vector2i, n: int, sal: int) -> Array:
	if n <= 0 or filas.size() <= n:
		return filas
	var clave := Vector3i(floori(c.x / 7.0), floori(c.y / 7.0), sal)
	if _trozos.has(clave):
		return _trozos[clave]
	var ids: Dictionary = {}
	var sub: Array = []
	var i: int = 0
	while sub.size() < n and i < n * 6:
		var id: String = TABLA.elegir_de(filas, m._hash(clave.x, clave.y, sal + 90 + i * 17))
		if id != "" and not ids.has(id):
			ids[id] = true
			for f in filas:
				if String(f[0]) == id:
					sub.append(f)
					break
		i += 1
	_trozos[clave] = sub if not sub.is_empty() else filas
	return _trozos[clave]


## Mete una pieza en el lote de su id (la maqueta las dibuja con MultiMesh). false si el modelo no existe en esta máquina.
func _poner(m: Node, S: float, id_pedido: String, p: Vector3, aj: Dictionary, rng: RandomNumberGenerator, ocupado: Dictionary, usadas: Dictionary) -> bool:
	if id_pedido == "":
		return false
	var id: String = m._id_real(id_pedido)
	if m._plantilla(id).is_empty():
		return false
	var r: Vector2 = aj["escala"]
	var esc: float = rng.randf_range(r.x, r.y)
	if not m._lotes.has(id):
		m._lotes[id] = []
	(m._lotes[id] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc), p))
	usadas[id] = true
	var k := Vector2i(floori(p.x / S), floori(p.z / S))
	if not ocupado.has(k):
		ocupado[k] = []
	(ocupado[k] as Array).append(Vector2(p.x, p.z))
	return true


func _poner_ruina(m: Node, c: Vector2i, S: float, y: float, filas: Array, ocupado: Dictionary, sal: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = m._hash(c.x, c.y, sal)
	var p := Vector3((float(c.x) + rng.randf_range(0.25, 0.75)) * S, y, (float(c.y) + rng.randf_range(0.25, 0.75)) * S)
	if not _lejos(m, p, c, S, float(RUINA["margen"])) or _cerca(p, ocupado, S, float(RUINA["libre"])):
		return
	var id: String = TABLA.elegir_de(filas, rng.randi())
	if id == "":
		return
	var r: Vector2 = RUINA["escala"]
	var esc: float = rng.randf_range(r.x, r.y)
	var giro: float = rng.randf() * TAU
	var nodo: Node3D = m._poner_escena(id, c, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc), p), false)
	if nodo == null:
		return
	var k := Vector2i(floori(p.x / S), floori(p.z / S))
	if not ocupado.has(k):
		ocupado[k] = []
	(ocupado[k] as Array).append(Vector2(p.x, p.z))
	_stats["ruinas"] = int(_stats["ruinas"]) + 1


## ¿El punto está a `margen` o más de cualquier casilla vecina que no es de hierba/claro (camino, agua, piedra, marcadores…)? Los `#` no cuentan.
func _lejos(m: Node, p: Vector3, c: Vector2i, S: float, margen: float) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var q := c + Vector2i(dx, dz)
			var l: String = m._letra(q)
			if l == "." or l == "," or l == "v" or l == "#":
				continue
			var ex: float = maxf(maxf(float(q.x) * S - p.x, p.x - float(q.x + 1) * S), 0.0)
			var ez: float = maxf(maxf(float(q.y) * S - p.z, p.z - float(q.y + 1) * S), 0.0)
			if sqrt(ex * ex + ez * ez) < margen:
				return false
	return true


func _cerca(p: Vector3, oc: Dictionary, S: float, radio: float) -> bool:
	var k := Vector2i(floori(p.x / S), floori(p.z / S))
	var q := Vector2(p.x, p.z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var lista: Variant = oc.get(k + Vector2i(dx, dz))
			if lista == null:
				continue
			for o in (lista as Array):
				if (o as Vector2).distance_to(q) < radio:
					return true
	return false
