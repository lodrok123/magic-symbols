extends RefCounted
## RUINAS COMPLETAS (27/11/2026). Pablo: «para las ruinas también pon el suelo; quiero el ejemplo de un nivel completo de bioma ruinas». Hasta hoy el estilo «ruinas» de la
## maqueta (`presentacion/prueba_test2.gd`, muros finos del pack Stylescape: Ruins) tenía el suelo del bosque: desde arriba, un prado con tabiques. Con el interruptor
## `ruinas_completas` de la maqueta (APAGADO por defecto: los niveles ya exportados no cambian; el exportador del generador de mapas lo enciende con el parámetro
## `ruinas_completas`) este script hace DOS cosas:
##
##   1. EL SUELO (`planificar`). Las salas y los pasillos se enlosan con la piedra del propio estilo (el tipo «piedra» del shader del suelo, con las losas teñidas al tono
##      de los muros: `LOSAS_RUINAS`), pero ROTO: sin losa en los bordes y en parches de ruido (con la hierba del bosque asomando por donde falta), con juntas de hierba
##      entre las losas (las de `AcabadoSuelo`, las mismas de siempre: no se duplica nada) y, de vez en cuando, una losa del pack con agujero (`ss_floor_4x4_01_dmg`) por
##      encima de una casilla sin losa pintada, por donde sale la hierba. Es solo aspecto: ni la colisión, ni la rejilla, ni `_tipo_suelo` (lo que arde y lo que crece)
##      cambian. Como el enlosado va PINTADO en el shader (no en piezas), los estados del suelo (mojado, quemado, helado, charcos) se siguen viendo encima; solo las
##      pocas casillas con la losa agujereada del pack tapan el estado de su casilla.
##   2. EL VESTIDO (`vestir`). Con piezas del pack valoradas «encaja» en la revisión (docs/REVISION_ASSETS_CUEVA_RUINAS_2026-11-27.md): pilares pegados a los muros (en la
##      franja de la casilla `#` que el muro fino deja libre y bloqueada: no estorban), un arco sobre cada puerta (`ss_arch_01`, con su hiedra) y escombros sobre
##      la hierba que asoma. Nada de barandas, vigas ni escaleras (valoradas «dudosa»: madera marrón, techos que no hay, y el juego no tiene desniveles).
##
## MEMORIA: todo lo que sale a miles va en MultiMesh por trozos (como `riqueza_suelo_3d.gd`); lo que son decenas (pilares, arcos), nodos con `_poner_escena`.
## Sin `class_name`: se carga con preload. Determinista: todo sale de la semilla del mapa (`semilla_decorado`) y de la casilla.

const PAREDES_SS = preload("res://presentacion/paredes_stylescape.gd")
const RUTA: String = "res://arte/stylescape/piezas/"

## Letras de suelo que se enlosan (el resto —agua, inicio, salidas, cauces— se queda como estaba). `R` ya es piedra: se queda entera.
const LETRAS_ENLOSABLES: String = ".,vgTWAGR"
const LETRAS_SUELO: String = ".,vgTWAGR"

## --- EL SUELO ---
## Cuánta ruina hay en cada trozo del mapa (ruido grueso): de `ruina_min` (casi entero) a `ruina_max` (muy roto).
const RUINA: Dictionary = {"min": 0.10, "max": 0.62, "tam": 9.0}
## Parches sin losa: ruido fino. Falta losa donde el ruido pasa de `umbral - ruina * peso_ruina - borde`.
const PARCHES: Dictionary = {"tam": 3.2, "umbral": 0.80, "peso_ruina": 0.55, "borde1": 0.20, "borde2": 0.08, "pasillo": 0.10, "tesoro": 0.14}
## Losa del pack por encima: `agujero` = probabilidad, en una casilla SIN losa pintada con tres o más vecinas enlosadas (así la losa agujereada queda dentro del enlosado, no suelta sobre la
## hierba), de llevar una losa con agujero (la hierba sale por él). Tapa el estado del suelo de su casilla (mojado, quemado…): por eso son pocas.
const PIEZAS: Dictionary = {"agujero": 0.4}
## Tinte (se multiplica por el color de la losa del pack) para que case con las losas pintadas en el suelo, que son algo más pardas que el beige de los muros.
const TINTE_LOSA: Color = Color(0.93, 0.90, 0.80)
## ids de la losa del pack; «encaja» en la revisión.
const LOSA_AGUJERO: Array = ["ss_floor_4x4_01_dmg"]
const TROZO_LOTE: int = 20             ## casillas de lado de cada trozo del mapa con su propio MultiMesh de losas (pocas losas: trozos grandes, pocos lotes)
const ESCOMBRO: Array = ["ss_rubble_01", "ss_rubble_02", "ss_stone_01", "ss_stone_02", "ss_stone_03", "ss_edge_stones_01_half_01", "ss_edge_stones_01_half_02"]

## --- EL VESTIDO ---
## Pilares pegados a los muros: uno de cada `cada` uniones entre tramos rectos (con desfase por fila para que no formen rejilla).
const PILARES: Dictionary = {"cada": 4, "altos": ["ss_pillar_01", "ss_pillar_02", "ss_pillar_04", "ss_pillar_05", "ss_pillar_01_dmg"], "bajo": "ss_pillar_03", "escala": 0.95}
const ARCO: String = "ss_arch_01"
const ARCO_ESCALA: Vector3 = Vector3(1.27, 1.15, 0.8)      ## a lo largo del muro, alto, fondo: sus pies caen sobre los postes de los muros que flanquean la puerta (4,6 u entre ellos)
const HIEDRA_ARCO: Array = ["ss_hangingivy_02", "ss_hangingivy_01", "ss_hangingivy_03"]
const TOPE_ESCOMBROS: int = 140        ## nodos de escombro sobre la hierba que asoma, como mucho en el mapa

const DIRS4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## --------------------------------------------------------------------------------------------------------------------------------------------------------
## PLAN DEL SUELO. Rellena en la maqueta `_rc_tipo` (casilla -> tipo de suelo que PINTA el shader: 3 piedra, 0 hierba), `_rc_enlosada` (casillas con losa
## entera: ahí no crece hierba) y `_rc_piezas` (lista de [id, casilla, giro en grados, y extra]). Se llama una vez, antes de pintar el mapa de tipos.
## --------------------------------------------------------------------------------------------------------------------------------------------------------
static func planificar(m: Node) -> void:
	m._rc_tipo = {}
	m._rc_enlosada = {}
	m._rc_piezas = []
	var lado: int = int(m._lado)
	var sal: int = 6100 + posmod(int(m.semilla_decorado), 997)
	# casillas de puzle (placas, botones, cofres…): la losa de ahí y la de su alrededor se quedan enteras
	var intacta: Dictionary = {}
	for q in m._celdas_puzle_del_mapa():
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				intacta[q + Vector2i(dx, dz)] = true
	# distancia (en casillas, 1 = pegada) de cada casilla de suelo al muro o a lo que no es suelo
	var dist: Dictionary = _distancias(m, lado)
	var enlosable: Dictionary = {}
	for cz in range(lado):
		for cx in range(lado):
			var c := Vector2i(cx, cz)
			var l: String = m._letra(c)
			if LETRAS_ENLOSABLES.contains(l) and not m._junto_a_agua(c):
				enlosable[c] = true
	# 1) qué casillas llevan losa entera y cuáles no
	var sin_losa: Dictionary = {}
	for c in enlosable:
		var l2: String = m._letra(c)
		var d: int = int(dist.get(c, 9))
		var ruina: float = lerpf(float(RUINA["min"]), float(RUINA["max"]), smoothstep(0.25, 0.75, m._vruido(Vector2(c) / float(RUINA["tam"]), sal + 3)))
		var ruido: float = m._vruido(Vector2(c) / float(PARCHES["tam"]), sal + 7) * 0.8 + m._vruido(Vector2(c) / (float(PARCHES["tam"]) * 0.4), sal + 9) * 0.2
		var umbral: float = float(PARCHES["umbral"]) - ruina * float(PARCHES["peso_ruina"])
		if d <= 1:
			umbral -= float(PARCHES["borde1"])
		elif d == 2:
			umbral -= float(PARCHES["borde2"])
		if l2 == "R":
			umbral += float(PARCHES["tesoro"])        # la sala del tesoro se rompe menos
		if l2 == "g":
			umbral += float(PARCHES["pasillo"])       # los pasillos y las puertas se rompen menos
		if intacta.has(c) or l2 != "." and l2 != "," and l2 != "v" and l2 != "g" and l2 != "R":
			umbral = 2.0                              # marcadores, braseros, enemigos: sobre losa entera
		if _es_puerta(m, c):
			umbral = 2.0
		if ruido > umbral:
			sin_losa[c] = true
	# 2) el tipo que pinta el shader y las piezas sueltas
	for c in enlosable:
		var h: int = m._hash(c.x, c.y, sal + 21)
		var r: float = float(h % 10000) / 10000.0
		if sin_losa.has(c):
			# la hierba asoma (el suelo pintado es hierba aquí, también en la sala del tesoro); si está rodeada de losas, a veces una losa con agujero encima (la hierba sale por el agujero)
			m._rc_tipo[c] = 0
			var vecinas: int = 0
			for dv in DIRS4:
				if enlosable.has(c + dv) and not sin_losa.has(c + dv):
					vecinas += 1
			if vecinas >= 3 and r < float(PIEZAS["agujero"]):
				m._rc_piezas.append([LOSA_AGUJERO[(h >> 5) % LOSA_AGUJERO.size()], c, 90.0 * float((h >> 9) % 4), 0.0])
				m._sin_hierba[c] = true               # sin briznas de hierba atravesando la losa
			continue
		m._rc_tipo[c] = 3
		m._rc_enlosada[c] = true
	# 3) el suelo bajo los muros finos, con el MISMO criterio de `_tipo_suelo` de la maqueta pero mirando el suelo ya enlosado de las casillas vecinas: el tipo más alto de las vecinas que no son
	# piedra; piedra solo si TODAS las vecinas de suelo son piedra. (Sin esto, junto a una puerta —`g`, tierra de siempre— el muro se quedaba sobre una mancha de tierra bajo el enlosado.)
	for cz in range(lado):
		for cx in range(lado):
			var cm := Vector2i(cx, cz)
			if m._letra(cm) != "#":
				continue
			var mejor: int = -1
			var piedra: bool = false
			for dv in DIRS4:
				var q: Vector2i = cm + dv
				if not m._en_mapa(q) or m._letra(q) == "#" or m._es_agua(m._letra(q)):
					continue
				var tq: int = int(m._rc_tipo.get(q, m._tipo_suelo(q)))
				if tq == 3:
					piedra = true
				else:
					mejor = maxi(mejor, tq)
			if mejor >= 0:
				m._rc_tipo[cm] = mejor
			elif piedra:
				m._rc_tipo[cm] = 3


## ¿Es esta casilla una puerta (`g` con muro a los dos lados y suelo en los otros dos)? Devuelve la orientación del MURO: 0 = a lo largo de X (muros a E y O), 1 = a lo largo de Z.
static func orientacion_puerta(m: Node, c: Vector2i) -> int:
	if m._letra(c) != "g":
		return -1
	var e: bool = m._letra(c + Vector2i(1, 0)) == "#"
	var o: bool = m._letra(c + Vector2i(-1, 0)) == "#"
	var n: bool = m._letra(c + Vector2i(0, -1)) == "#"
	var s: bool = m._letra(c + Vector2i(0, 1)) == "#"
	if e and o and not n and not s:
		return 0
	if n and s and not e and not o:
		return 1
	return -1


static func _es_puerta(m: Node, c: Vector2i) -> bool:
	return orientacion_puerta(m, c) >= 0


## Distancia de cada casilla de suelo a lo que no es suelo (1 = pegada), con tope 4.
static func _distancias(m: Node, lado: int) -> Dictionary:
	var dist: Dictionary = {}
	var cola: Array = []
	for cz in range(lado):
		for cx in range(lado):
			var c := Vector2i(cx, cz)
			if not LETRAS_SUELO.contains(m._letra(c)):
				dist[c] = 0
				cola.append(c)
	var i: int = 0
	while i < cola.size():
		var c2: Vector2i = cola[i]
		i += 1
		var dc: int = int(dist[c2])
		if dc >= 4:
			continue
		for dv in DIRS4:
			var q: Vector2i = c2 + dv
			if q.x < 0 or q.y < 0 or q.x >= lado or q.y >= lado or dist.has(q):
				continue
			dist[q] = dc + 1
			cola.append(q)
	return dist


## --------------------------------------------------------------------------------------------------------------------------------------------------------
## EL VESTIDO. `m` = la maqueta; `S` = lado de la casilla; `y` = altura del suelo (ALTO). Devuelve las cuentas para las pruebas y el informe.
## --------------------------------------------------------------------------------------------------------------------------------------------------------
static func vestir(m: Node, S: float, y: float) -> Dictionary:
	var cuentas: Dictionary = {"losas": 0, "lotes": 0, "pilares": 0, "arcos": 0, "hiedras": 0, "escombros": 0, "pilares_en": [], "arcos_en": []}
	var en: bool = m._en_marcador
	m._en_marcador = false
	cuentas["lotes"] = _losas_por_lotes(m, S, y, cuentas)
	_pilares(m, S, y, cuentas)
	_arcos(m, S, y, cuentas)
	_escombros(m, S, y, cuentas)
	m._en_marcador = en
	return cuentas


## Las losas del pack del plan, en MultiMesh por trozos de `TROZO_LOTE` casillas de lado (un nodo por id y trozo, no por losa). Devuelve cuántos lotes ha hecho.
static func _losas_por_lotes(m: Node, S: float, y: float, cuentas: Dictionary) -> int:
	var por_id: Dictionary = {}
	for p in (m._rc_piezas as Array):
		var id: String = String(p[0])
		var c: Vector2i = p[1]
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(p[2]))), Vector3((float(c.x) + 0.5) * S, y + 0.004 + float(p[3]), (float(c.y) + 0.5) * S))
		if not por_id.has(id):
			por_id[id] = []
		(por_id[id] as Array).append(t)
		cuentas["losas"] = int(cuentas["losas"]) + 1
	var lotes: int = 0
	for id in por_id:
		lotes += _lote_de_escena(m, String(id), por_id[id] as Array, S)
	return lotes


## MultiMesh de las mallas de una pieza `ss_*` (con el material del juego, `Ocluso3D`, como las piezas puestas con `_poner_escena`), por trozos del mapa.
static func _lote_de_escena(m: Node, id: String, copias: Array, S: float) -> int:
	var ruta: String = RUTA + id + ".tscn"
	if not ResourceLoader.exists(ruta) or copias.is_empty():
		return 0
	var raiz: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	var partes: Array = []
	m._mallas_de(raiz, Transform3D.IDENTITY, partes)
	raiz.free()
	var trozo: float = S * float(TROZO_LOTE)
	var trozos: Dictionary = {}
	for t in copias:
		var o: Vector3 = (t as Transform3D).origin
		var k := Vector2i(floori(o.x / trozo), floori(o.z / trozo))
		if not trozos.has(k):
			trozos[k] = []
		(trozos[k] as Array).append(t)
	var n_lotes: int = 0
	for parte in partes:
		var malla: Mesh = (parte[0] as Mesh).duplicate() as Mesh      # propia: así los materiales convertidos no tocan los de la pieza original
		var mat_nodo: Material = parte[2] as Material
		if m.transparencia_jugador:
			for i in range(malla.get_surface_count()):
				var sm: Material = malla.surface_get_material(i)
				if sm != null:
					var conv: Material = Ocluso3D.convertir(sm.duplicate() as Material)
					if conv is ShaderMaterial:
						(conv as ShaderMaterial).set_shader_parameter("color", ((conv as ShaderMaterial).get_shader_parameter("color") as Color) * TINTE_LOSA)
					malla.surface_set_material(i, conv)
			if mat_nodo != null:
				mat_nodo = Ocluso3D.convertir(mat_nodo.duplicate() as Material)
		for k in trozos:
			var lista: Array = trozos[k]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = malla
			mm.instance_count = lista.size()
			var local: Transform3D = parte[1]
			for i in range(lista.size()):
				mm.set_instance_transform(i, (lista[i] as Transform3D) * local)
			var mi := MultiMeshInstance3D.new()
			mi.name = "rc_%s_%d_%d" % [id, (k as Vector2i).x, (k as Vector2i).y]
			mi.multimesh = mm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # losas de 6 cm: la sombra no se lee y cada lote con sombra cuesta una pasada más
			if mat_nodo != null:
				mi.material_override = mat_nodo
			m._props.add_child(mi)
			n_lotes += 1
	return n_lotes


## ¿La casilla `q` es muro que el estilo viste con muro fino? (toca suelo en alguna de las 8 direcciones)
static func _vestida(m: Node, q: Vector2i) -> bool:
	return PAREDES_SS.se_viste(q, Callable(m, "_suelo_de_cueva"), Callable(m, "_muro_de_ruina"))


## Pilares pegados a los muros rectos. En cada UNIÓN entre dos tramos rectos seguidos (el muro fino va por el eje de su casilla y mide una casilla por tramo) hay una
## costura: un pilar del pack la tapa. Va por el lado del suelo, en la franja de la casilla `#` que queda entre la cara del muro y la casilla de suelo (esa casilla
## está bloqueada entera: el pilar no estorba el paso). Donde el muro es BAJO (la pared sur de una sala), un pilar bajo, para no tapar lo de dentro.
static func _pilares(m: Node, S: float, y: float, cuentas: Dictionary) -> void:
	var lado: int = int(m._lado)
	var es_suelo := Callable(m, "_suelo_de_cueva")
	var es_muro := Callable(m, "_muro_de_ruina")
	var sal: int = 6100 + posmod(int(m.semilla_decorado), 997)
	var cada: int = int(PILARES["cada"])
	for cz in range(lado):
		for cx in range(lado):
			var w := Vector2i(cx, cz)
			var e: Vector2i = w + Vector2i(1, 0)
			var s_: Vector2i = w + Vector2i(0, 1)
			# unión horizontal (el muro corre por X) entre `w` y la casilla del este, y vertical (por Z) entre `w` y la del sur
			if (cx + cz * 3) % cada == int(m._hash(cz, 1, sal + 40) % cada):
				_pilar_en_union(m, w, e, 0, S, y, es_suelo, es_muro, sal, cuentas)
			if (cz + cx * 3) % cada == int(m._hash(cx, 2, sal + 41) % cada):
				_pilar_en_union(m, w, s_, 1, S, y, es_suelo, es_muro, sal, cuentas)


static func _pilar_en_union(m: Node, a: Vector2i, b: Vector2i, eje: int, S: float, y: float, es_suelo: Callable, es_muro: Callable, sal: int, cuentas: Dictionary) -> void:
	if not (m._letra(a) == "#" and m._letra(b) == "#") or not _vestida(m, a) or not _vestida(m, b):
		return
	if m._contrafuerte_ss(a) != Vector2i.ZERO or m._contrafuerte_ss(b) != Vector2i.ZERO:
		return
	# `d` = el sentido del muro (E o S); los lados del suelo son los perpendiculares
	var d: Vector2i = b - a
	var lados: Array = [Vector2i(d.y, d.x), Vector2i(-d.y, -d.x)]
	var rectos: bool = true
	# los dos tramos han de ser rectos: sin otra rama que doble en `a` o en `b` (si no, ahí hay un poste del pack y no una costura)
	for q in [a, b]:
		for dv in DIRS4:
			if dv == d or dv == -d:
				continue
			if m._letra(q + dv) == "#" and _vestida(m, q + dv) and PAREDES_SS._tramo_con_suelo(q, dv, es_suelo):
				rectos = false
	if not rectos:
		return
	var libres: Array = []
	for lado_v in lados:
		var lv: Vector2i = lado_v
		if es_suelo.call(a + lv) and es_suelo.call(b + lv) and LETRAS_SUELO.contains(m._letra(a + lv)) and LETRAS_SUELO.contains(m._letra(b + lv)):
			libres.append(lv)
	if libres.is_empty():
		return
	var h: int = m._hash(a.x, a.y, sal + 50 + eje)
	var lv2: Vector2i = libres[h % libres.size()]
	# ¿el muro de ese lado es bajo? (la pared sur de una sala)
	var bajo: bool = PAREDES_SS._es_bajo(a, d, es_suelo, es_muro) or PAREDES_SS._es_bajo(b, -d, es_suelo, es_muro)
	var id: String = String(PILARES["bajo"]) if bajo else String((PILARES["altos"] as Array)[(h >> 4) % (PILARES["altos"] as Array).size()])
	var caja: AABB = PAREDES_SS._caja_pieza(id)
	var fondo: float = maxf(caja.size.x, caja.size.z) * float(PILARES["escala"])
	var normal := Vector3(float(lv2.x), 0.0, float(lv2.y))
	# el punto de la costura: en el EJE de las dos casillas (entre sus centros)
	var costura := Vector3((float(a.x) + 0.5 + 0.5 * float(d.x)) * S, y, (float(a.y) + 0.5 + 0.5 * float(d.y)) * S)
	var pos: Vector3 = costura + normal * (PAREDES_SS.MEDIO_GRUESO + fondo * 0.5 + 0.01)
	var giro: float = float((h >> 7) % 4) * 90.0
	var base := Basis(Vector3.UP, deg_to_rad(giro)).scaled(Vector3.ONE * float(PILARES["escala"]))
	m._poner_escena(id, a, Transform3D(base, pos), false)
	cuentas["pilares"] = int(cuentas["pilares"]) + 1
	(cuentas["pilares_en"] as Array).append(Vector2i(floori(pos.x / S), floori(pos.z / S)))


## Un arco sobre cada puerta (`g` con muros a los dos lados): `ss_arch_01`, ancho para que sus pies caigan sobre los postes de los muros que flanquean la puerta, y una hiedra
## colgando de su cara de cámara. El arco no tiene cuerpo: la puerta se cruza igual que antes.
static func _arcos(m: Node, S: float, y: float, cuentas: Dictionary) -> void:
	var lado: int = int(m._lado)
	var sal: int = 6100 + posmod(int(m.semilla_decorado), 997)
	for cz in range(lado):
		for cx in range(lado):
			var c := Vector2i(cx, cz)
			var o: int = orientacion_puerta(m, c)
			if o < 0:
				continue
			# los dos muros que flanquean la puerta tienen que ser muros vestidos (si no, no hay poste donde apoyar los pies)
			var d: Vector2i = Vector2i(1, 0) if o == 0 else Vector2i(0, 1)
			if not (_vestida(m, c + d) and _vestida(m, c - d)):
				continue
			if m._contrafuerte_ss(c + d) != Vector2i.ZERO or m._contrafuerte_ss(c - d) != Vector2i.ZERO:
				continue
			var h: int = m._hash(c.x, c.y, sal + 60)
			var giro: float = 0.0 if o == 0 else 90.0
			var centro := Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
			var base := Basis(Vector3.UP, deg_to_rad(giro)).scaled(ARCO_ESCALA)
			m._poner_escena(ARCO, c, Transform3D(base, centro), false)
			cuentas["arcos"] = int(cuentas["arcos"]) + 1
			(cuentas["arcos_en"] as Array).append(c)
			if h % 3 != 0:
				var ivy: String = String(HIEDRA_ARCO[(h >> 3) % HIEDRA_ARCO.size()])
				var dim: Vector2 = PAREDES_SS.DIM_HIEDRA.get(ivy.replace("ss_", "SM_").replace("hangingivy", "HangingIvy"), Vector2(0.6, 0.2))
				# colgando de la cara que mira a la cámara (el sur, o el este del muro vertical)
				var cara := Vector3(0.0, 0.0, 1.0) if o == 0 else Vector3(1.0, 0.0, 0.0)
				var lado_h: float = float((h >> 6) % 3 - 1) * 0.55
				var a_lo_largo := Vector3(1.0, 0.0, 0.0) if o == 0 else Vector3(0.0, 0.0, 1.0)
				var alto_arco: float = 1.256 * ARCO_ESCALA.y
				var pos: Vector3 = centro + cara * (0.375 * ARCO_ESCALA.z * 0.5 + 0.03) + a_lo_largo * lado_h + Vector3(0.0, alto_arco - dim.x - 0.05, 0.0)
				m._poner_escena(ivy, c, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), pos), false)
				cuentas["hiedras"] = int(cuentas["hiedras"]) + 1


## Escombros y piedras sobre la hierba que asoma entre las losas rotas (donde falta losa y alguna vecina la tiene): pedazos caídos. Un nodo por escombro, con tope.
static func _escombros(m: Node, S: float, y: float, cuentas: Dictionary) -> void:
	var sal: int = 6100 + posmod(int(m.semilla_decorado), 997)
	var puestos: int = 0
	var claves: Array = []
	for cz in range(int(m._lado)):
		for cx in range(int(m._lado)):
			var c := Vector2i(cx, cz)
			if int(m._rc_tipo.get(c, -1)) == 3 or not LETRAS_ENLOSABLES.contains(m._letra(c)) or m._sin_hierba.has(c):
				continue
			claves.append(c)
	for c in claves:
		if puestos >= TOPE_ESCOMBROS:
			break
		var vecina: bool = false
		for dv in DIRS4:
			if m._rc_enlosada.has(c + dv):
				vecina = true
		if not vecina:
			continue
		var h: int = m._hash(c.x, c.y, sal + 70)
		if h % 100 >= 34:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = h
		var id: String = String(ESCOMBRO[(h >> 8) % ESCOMBRO.size()])
		var pos := Vector3((float(c.x) + rng.randf_range(0.2, 0.8)) * S, y, (float(c.y) + rng.randf_range(0.2, 0.8)) * S)
		var esc: float = rng.randf_range(0.85, 1.15)
		m._poner_escena(id, c, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc), pos), false)
		puestos += 1
	cuentas["escombros"] = puestos
