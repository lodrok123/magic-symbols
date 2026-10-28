class_name PrevisionHechizo
extends RefCounted

## PREVISIÓN «EN SECO» DE UN HECHIZO (A2 de docs/PROPUESTA_COMBATE.md §1.2 y §7; 28/10). Dueño: Juego.
##
## Responde a «¿qué pasaría si ESTE hechizo (receta, elemento, forma, origen, dirección) se lanzara AHORA?» con las MISMAS reglas que el impacto real y SIN aplicar nada: no cambia estado,
## no emite señales, no suena, no gasta tinta ni recarga, no crea nodos de juego. NO dibuja nada: es la base de datos de A3 (pintar la reacción en el indicador) y de A4 (trayectorias).
##
## UNA SOLA FUENTE DE VERDAD. Aquí no hay reglas de reacción: cada una vive donde se ejecuta y se extrajo a una función de decisión que el camino real también llama:
##   · el recorrido (vuelo con gravedad, choques, alcance, camino de lo que viaja, casillas de un volumen, haz) lo corre el propio `HechizoVivo` en modo `seco` (`HechizoVivo.prever`);
##   · enemigos  `Combate3D.prever_golpe` ← `decidir_golpe` (que `golpe` aplica), `prever_empuje` ← `_puede_estar_desde` (que `_mover_paso` usa), `Escudo3D.cubre` / `reaccion_a`;
##     el empuje del viento/atracción: `Lanzador3D.empuje_de_golpe` (que `_golpear` ejecuta);
##   · suelo     `ReaccionesSuelo3D.prever` ← `EstadosSuelo3D.fila_para` (que `aplicar` usa), `PruebaTest2.prever_hierba` (que `_impacto_en_hierba` usa);
##   · piezas    `spell_reacts` (lo que decide `_golpear` si el golpe llega) y, para NOMBRAR la reacción, `Reactivo3D.reaccion_a`, `BloqueEmpujable3D.reaccion_a`, `MuroAgrietado3D.reaccion_a`,
##               `Lava3D.celdas_enfriables` / `celda_de_impacto` (cada una la llama su `on_spell_hit`). `Rompible3D` y las piezas sin tabla propia se nombran «rompe» / «activa».
##
## CADA ENTRADA:  {que: «enemigo»|«suelo»|«pieza», nodo: Node o null, celda: Vector2i, reaccion: String, mult: float, extra: Dictionary}
##   reaccion  la principal. Enemigo: bloquea · crece · cura · tine (el limo, E1) · piedra · nucleo · resbala · lava · inmune (el gólem, E3) · hunde · electrocuta · congela · prende · moja · seca (vapor) · apaga · aturde · empuja · ralentiza · golpe.
##             Suelo: hiela · moja · seca · derrite · evapora · prende · arde · brota · apaga · abanica.   Pieza: enciende · apaga · prende · moja · aviva · activa · brota · mueve · agrieta · rompe · enfria.
##   mult      2,0 debilidad · 0,5 resistencia · 1,0 (en piezas y suelo, siempre 1,0)
##   extra     enemigo: {reacciones: [String] (todas, en orden de importancia), dano, cubierto, escudo (la reacción del escudo si lo para), hundira, destino: Vector3 (adónde llegaría empujado),
##                       empuje_u (recorrido en u), golpes (cuántas veces le llega: copias del proyectil)}
##             pieza: {destino: Vector2i (bloque), celdas: Array (lava), golpes}        suelo: {clase: «suelo»|«hierba»|«agua», efecto}
## Un hechizo que no reacciona con nada devuelve una lista vacía.
##
## QUÉ NO CUBRE (a propósito; está en el informe de A2): los eventos del hechizo (hijos, explosión en área `radio_explosion`, `al_golpear`), los pulsos periódicos de las zonas, el empuje del gas a los
## enemigos, el pulso de ᚱ, el electrificado del suelo mojado por el rayo, combos en cadena (lo que una reacción provoca después: el fuego que contagia, el vapor), el agua que un hechizo líquido
## suelta en la simulación (y lo que moja), los enemigos que se muevan mientras vuela el proyectil, y los rebotes complejos (se simulan, pero con el vuelo de `HechizoVivo`, no con ninguna ruta aparte).
## Un proyectil con `retorna` se prevé solo en la ida.

## Prioridad de las reacciones de un enemigo para elegir la principal (la primera que aparece).
const PRIORIDAD_ENEMIGO: PackedStringArray = ["bloquea", "crece", "cura", "tine", "hunde", "lava", "resbala", "nucleo", "electrocuta", "congela", "prende", "moja", "seca", "apaga", "aturde", "empuja", "ralentiza", "golpe", "piedra", "inmune"]
## Qué aviso de `Combate3D.decidir_golpe` (catálogo de Mundo3D.REACCIONES) es qué reacción del indicador.
const DE_AVISO: Dictionary = {"electrocutado": "electrocuta", "prendido": "prende", "apagado_agua": "apaga", "secado": "seca", "mojado": "moja", "congelado": "congela"}
## Un empujón menor que esto (casillas) no cuenta como «empuja» para el indicador (todo golpe con daño empuja un poco: EMPUJE_MIN_CASILLAS).
const EMPUJE_VISIBLE_CASILLAS: float = 0.5

## Edad máxima (ms) de lo que devuelve `prever_rapido`: lo que se ve en el indicador no necesita ser más fresco (un enemigo se mueve poco en 0,1 s).
const EDAD_RAPIDA_MS: int = 100

## Caché de una sola entrada del `Hechizo` de la última página preparada (construirlo cada fotograma sería caro y no cambia mientras se apunta).
static var _cache_clave: Array = []
static var _cache_hechizo: Hechizo = null
static var _rapida_clave: Array = []
static var _rapida_ms: int = -1000000
static var _rapida_res: Array[Dictionary] = []
## 28/10 (apuntado): el recorrido de la última previsión, para DIBUJARLO (no es una reacción): {caminos: [PackedVector3Array] (uno por copia de proyectil; vacío si no vuela),
## fines: [Vector3] (dónde se para cada uno o dónde nace lo que no vuela), causas: [String], volumenes: [{estado, elemento, volumen, origen, dir, props}] (lo que se anunciaría
## al dibujo con `hechizo_v2`: el fantasma del indicador)}. Lo lee el indicador (`TrayectoApuntado3D`) justo después de `prever_rapido`.
static var ultimo_recorrido: Dictionary = {}
static var _rapida_recorrido: Dictionary = {}


## La previsión. `datos` es lo que prepara el lanzador (`Lanzador3D._preparado`: receta, rune, indice…). `origen` y `dir` son los que se pasarían a `lanzar_ahora`.
static func prever(lanzador: Lanzador3D, datos: Dictionary, origen: Vector3, dir: Vector3) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	if lanzador == null or datos.is_empty() or not datos.has("receta") or not datos.has("rune") or not lanzador.is_inside_tree():
		return res
	var h: Hechizo = _hechizo(lanzador, datos)
	ultimo_recorrido = {}
	if h == null:
		return res
	if h.solido_quieto and lanzador.rechazo_de_construccion(datos, origen) != "":
		return res                                           # el lanzamiento se negaría: no pasa nada
	var rune: RuneData = datos["rune"]
	var cas: float = Terreno3D.casilla
	var vivo: Dictionary = HechizoVivo.prever(h, lanzador, origen, dir)
	ultimo_recorrido = {"caminos": vivo.get("caminos", []), "fines": vivo["fines"], "causas": vivo["causas"], "volumenes": vivo.get("volumenes", [])}

	# 1 · A quién llega el golpe (una entrada por objeto; si le llega varias veces, `golpes` lo cuenta).
	var vistos: Dictionary = {}
	for gp in vivo["golpes"]:
		var obj: Node = gp["obj"]
		if obj == null or not is_instance_valid(obj):
			continue
		var id: int = obj.get_instance_id()
		if vistos.has(id):
			var previa: Dictionary = vistos[id]
			(previa["extra"] as Dictionary)["golpes"] = int((previa["extra"] as Dictionary).get("golpes", 1)) + 1
			continue
		var e: Dictionary = _de_golpe(lanzador, obj, h, rune, gp)
		if e.is_empty():
			continue
		vistos[id] = e
		res.append(e)

	# 2 · Qué le pasa al suelo: cada casilla marcada y el sitio donde se detiene cada proyectil (una vez por casilla y reacción).
	var marcas: Array = []                                   # [{elemento, celda, solo_hierba}]
	for m in vivo["suelo"]:
		marcas.append({"elemento": m["elemento"], "celda": m["celda"], "solo_hierba": false})
	for f in vivo["fines"]:
		var cf: Vector2i = Terreno3D.celda_de(f as Vector3)
		if Terreno3D.en_mapa(cf):
			marcas.append({"elemento": h.elemento, "celda": cf, "solo_hierba": true})        # el impacto del VFX donde se para: solo la hierba de la maqueta (el agua, p. ej., no marca casillas)
	var hechas: Dictionary = {}
	for m in marcas:
		var c: Vector2i = m["celda"]
		var clave: String = "%s|%d|%d" % [String(m["elemento"]), c.x, c.y]
		if hechas.has(clave):
			continue
		hechas[clave] = true
		var r: Dictionary = ReaccionesSuelo3D.prever(String(m["elemento"]), c, bool(m["solo_hierba"]))
		if r.is_empty():
			continue
		if _hay_suelo(res, c, String(r["reaccion"])):
			continue
		res.append({"que": "suelo", "nodo": null, "celda": c, "reaccion": String(r["reaccion"]), "mult": 1.0, "extra": r["extra"]})

	# 3 · La lava se enfría por el AVISO de impacto del agua y del hielo (`Lava3D._al_impacto`), no solo por el golpe: se pregunta en el sitio donde cae y en cada casilla marcada.
	if h.elemento == "agua" or h.elemento == "hielo":
		var puntos: Array = []
		for f in vivo["fines"]:
			puntos.append(f)
		for m in vivo["suelo"]:
			var cm: Vector2i = m["celda"]
			puntos.append(Terreno3D.centro_de(cm, Terreno3D.y_pies(cm)))
		for lava in lanzador.get_tree().get_nodes_in_group("lava3d"):
			if not is_instance_valid(lava):
				continue
			for p in puntos:
				var c2: Vector2i = (lava as Lava3D).celda_de_impacto(p as Vector3, h.elemento, cas * ReaccionesAgua3D.RADIO_HIELO)
				if c2 != Vector2i(-9999, -9999):
					_sumar_lava(res, lava as Lava3D, (lava as Lava3D).celdas_enfriables(c2))
	return res


## Como `prever`, pero para llamarla CADA FOTOGRAMA al apuntar: si se pregunta lo mismo (misma receta, origen a 2 cm y dirección a ~1°) en menos de `edad_max_ms`, devuelve lo de la última vez
## sin recalcular. Las entradas llevan nodos: quien las lea debe mirar `is_instance_valid`.
static func prever_rapido(lanzador: Lanzador3D, datos: Dictionary, origen: Vector3, dir: Vector3, edad_max_ms: int = EDAD_RAPIDA_MS) -> Array[Dictionary]:
	var receta: Variant = datos.get("receta")
	var clave: Array = [receta.get_instance_id() if receta != null else 0, snappedf(origen.x, 0.02), snappedf(origen.y, 0.02), snappedf(origen.z, 0.02),
		snappedf(dir.x, 0.02), snappedf(dir.z, 0.02), lanzador.cambios_hechizo.hash()]
	var ahora: int = Time.get_ticks_msec()
	if clave == _rapida_clave and ahora - _rapida_ms < edad_max_ms:
		ultimo_recorrido = _rapida_recorrido
		return _rapida_res
	_rapida_res = prever(lanzador, datos, origen, dir)
	_rapida_recorrido = ultimo_recorrido
	_rapida_clave = clave
	_rapida_ms = ahora
	return _rapida_res


## El `Hechizo` de la página preparada, el mismo que `_disparar` lanzaría (pigmento y cambios del laboratorio incluidos). Se guarda el último; no se muta.
static func _hechizo(lanzador: Lanzador3D, datos: Dictionary) -> Hechizo:
	var receta: Lanzador3D.Receta3D = datos["receta"]
	var rune: RuneData = datos["rune"]
	var mult: float = lanzador.tinta.mult_dano(Objetos.elemento_de(rune)) if lanzador.tinta != null else 1.0
	var clave: Array = [receta.get_instance_id(), rune.get_instance_id(), mult, lanzador.cambios_hechizo.hash()]
	if _cache_hechizo != null and clave == _cache_clave:
		return _cache_hechizo
	var h: Hechizo = lanzador.hechizo_de(datos)
	if h != null and not lanzador.cambios_hechizo.is_empty():
		h = h.con(lanzador.cambios_hechizo)               # lo que añade `Lanzador3D._con_cambios` al lanzar
	_cache_clave = clave
	_cache_hechizo = h
	return h


## Olvida la caché (para las pruebas, o si se cambia algo del hechizo por detrás).
static func olvidar() -> void:
	_cache_clave = []
	_cache_hechizo = null
	_rapida_clave = []
	_rapida_ms = -1000000
	_rapida_res = []
	_rapida_recorrido = {}
	ultimo_recorrido = {}


static func _hay_suelo(res: Array[Dictionary], c: Vector2i, reaccion: String) -> bool:
	for e in res:
		if String(e["que"]) == "suelo" and (e["celda"] as Vector2i) == c and String(e["reaccion"]) == reaccion:
			return true
	return false


## Suma casillas a la entrada de una lava (o la crea).
static func _sumar_lava(res: Array[Dictionary], lava: Lava3D, celdas: Array) -> void:
	if celdas.is_empty():
		return
	for e in res:
		if e["nodo"] == lava and String(e["reaccion"]) == "enfria":
			var ya: Array = (e["extra"] as Dictionary)["celdas"]
			for c in celdas:
				if not ya.has(c):
					ya.append(c)
			return
	res.append({"que": "pieza", "nodo": lava, "celda": celdas[0], "reaccion": "enfria", "mult": 1.0, "extra": {"celdas": celdas.duplicate(), "golpes": 1}})


## Una entrada para un objeto al que llega el golpe `gp` ({dir, punto, desde}), o {} si no reaccionaría.
static func _de_golpe(lanzador: Lanzador3D, obj: Node, h: Hechizo, rune: RuneData, gp: Dictionary) -> Dictionary:
	var dir: Vector3 = gp["dir"]
	var punto: Vector3 = gp["punto"]
	if obj is Combate3D:
		return _enemigo(obj as Combate3D, h, rune, dir, punto, gp["desde"])
	if not obj.has_method("on_spell_hit"):
		return {}
	var reacciona: bool = true
	if obj.has_method("spell_reacts"):
		reacciona = bool(obj.call("spell_reacts", rune, dir))      # la misma consulta que `Lanzador3D._golpear`
	if not reacciona:
		return {}
	return _pieza(obj, rune, dir, punto)


static func _enemigo(g: Combate3D, h: Hechizo, rune: RuneData, dir: Vector3, punto: Vector3, desde: Vector3) -> Dictionary:
	if g.muerto:
		return {}
	var previo: Dictionary = Lanzador3D.empuje_de_golpe(g, rune, dir, punto, false, desde)
	var pg: Dictionary = g.prever_golpe(h, dir, previo)
	var cas: float = Terreno3D.casilla
	var lista: Array = []
	var empuje: Dictionary = pg["empuje"] as Dictionary
	var hunde: bool = bool(pg["cae_al_agua"])
	var empuja: bool = not empuje.is_empty() and float(empuje["recorrido"]) >= EMPUJE_VISIBLE_CASILLAS * cas
	var propias: Array = pg.get("reacciones_propias", [])    # E3: el gólem las decide él (piedra, núcleo, resbala, lava, inmune)
	if bool(pg["cubierto"]):
		lista.append("bloquea")
	elif not propias.is_empty():
		for p in propias:
			lista.append(String(p))
	elif String(pg.get("absorbe", "")) != "":
		lista.append(String(pg["absorbe"]))              # E1: el limo absorbe el elemento (tiñe · crece · cura): nada más le pasa
	else:
		for aviso in pg["avisos"]:
			var n: String = String(DE_AVISO.get(String(aviso), ""))
			if n != "" and not lista.has(n):
				lista.append(n)
		if bool(pg["aturde"]):
			lista.append("aturde")
		if float(pg["lento"]) > 0.0:
			lista.append("ralentiza")
	if not propias.is_empty():
		pass                                             # lo que empuja o hunde ya va en sus reacciones propias
	elif hunde:
		lista.append("hunde")
	elif empuja:
		lista.append("empuja")
	if float(pg["dano"]) > 0.0 and not bool(pg["cubierto"]) and propias.is_empty():
		lista.append("golpe")                            # el daño suelto (sin ningún estado) también es lo que le pasa
	if lista.is_empty():
		return {}                                        # nada que enseñar (un viento que no lo mueve, un golpe sin daño ni estado)
	lista.sort_custom(func(a: String, b: String) -> bool: return PRIORIDAD_ENEMIGO.find(a) < PRIORIDAD_ENEMIGO.find(b))
	var extra: Dictionary = {"reacciones": lista, "dano": float(pg["dano"]), "cubierto": bool(pg["cubierto"]), "escudo": String(pg["escudo"]),
		"hundira": hunde, "lava": bool(pg.get("cae_en_lava", false)), "golpes": 1, "empuje_u": float(empuje.get("recorrido", 0.0)), "destino": (empuje["destino"] as Vector3) if not empuje.is_empty() else g.position}
	return {"que": "enemigo", "nodo": g, "celda": Terreno3D.celda_de(g.position), "reaccion": String(lista[0]),
		"mult": 1.0 if bool(pg["cubierto"]) else float(pg["mult"]), "extra": extra}


static func _pieza(obj: Node, rune: RuneData, dir: Vector3, punto: Vector3) -> Dictionary:
	var celda: Vector2i = Terreno3D.celda_de((obj as Node3D).global_position) if obj is Node3D else Vector2i.ZERO
	var extra: Dictionary = {"golpes": 1}
	var reaccion: String = ""
	if obj is Lava3D:
		var celdas: Array = (obj as Lava3D).celdas_enfriables(Terreno3D.celda_de(punto))
		if celdas.is_empty():
			return {}
		reaccion = "enfria"
		celda = celdas[0]
		extra["celdas"] = celdas
	elif obj is BloqueEmpujable3D:
		var r: Dictionary = (obj as BloqueEmpujable3D).reaccion_a(rune, dir)
		if r.is_empty():
			return {}
		reaccion = String(r["reaccion"])
		extra["destino"] = r["destino"]
		extra["dir"] = r["dir"]
	elif obj is MuroAgrietado3D:
		reaccion = (obj as MuroAgrietado3D).reaccion_a(rune)
	elif obj is Rompible3D:
		reaccion = "rompe"
	elif obj is Reactivo3D:
		reaccion = (obj as Reactivo3D).reaccion_a(rune)
	else:
		reaccion = "activa"                              # una pieza con `spell_reacts` y sin tabla de nombres propia (pulsador, compuerta, cristal…): reacciona y se activa
	if reaccion == "":
		return {}
	return {"que": "pieza", "nodo": obj, "celda": celda, "reaccion": reaccion, "mult": 1.0, "extra": extra}
