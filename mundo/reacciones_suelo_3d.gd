## ReaccionesSuelo3D · qué le hace cada elemento al ESTADO del suelo (mojada, helada, quemada) cuando impacta (21/10, Juego). Sin nodos, sin hechizos.
##
## Por qué existe: los impactos de agua, hielo y fuego sobre una casilla de SUELO solo pintaban la imagen de estado de la maqueta
## (`_img_estado`, `_impacto_en_suelo`); `Terreno3D.estados` no se enteraba, así que las condiciones de puzle
## `casilla(x,y).mojada|helada|quemada` no se cumplían nunca jugando (diario 240). Aquí el Juego escribe el estado, con
## la tabla `EstadosSuelo3D.TRANSICIONES` (que es la regla de `_impacto_en_suelo` hecha datos). B2 (21/10): la imagen de la maqueta se retiró;
## el suelo, la hierba y el agua se dibujan leyendo ESTE estado (`Mundo3D.textura_estados()`), así que ya no hay dos fuentes que pudieran contradecirse.
##
## UN SOLO PUNTO DE ENTRADA: `Mundo3D.aplicar_accion` reparte cada acción al agua (`ReaccionesAgua3D`) y a esto. Lo llama `Lanzador3D.al_impactar`,
## por donde pasa todo impacto de un hechizo (su casilla, un muro o un corro). Ningún hechizo escribe estados por su cuenta.
##
## QUÉ CASILLAS. Las mismas tres ramas que `PruebaTest2._al_impactar` (la maqueta, del Pipeline, no se toca):
##   agua    no hace nada aquí: el hielo sobre agua lo pone `Terreno3D.poner_helada` y el agua de la simulación se lleva su propia lógica;
##   hierba  no hace nada AQUÍ al impactar: lo suyo (prender, brotar, apagar) es un autómata de la maqueta (`_hf`); su resultado «quemada» se
##           copia después con `sincronizar_hierba`, que sigue a la maqueta fotograma a fotograma (así, si el agua apaga la hierba, el estado no
##           se queda con un «quemada» que ya no se ve);
##   suelo   `EstadosSuelo3D.aplicar`. Una casilla bloqueada (algo encima) no recibe nada, como en la maqueta.
## La clasificación la contesta quien conoce la maqueta (`Lanzador3D.configurar` pone `clasificar`); sin ella, un respaldo por letras.
class_name ReaccionesSuelo3D
extends RefCounted

## Qué acción del estado es cada elemento. El rayo, la tierra y el viento no cambian canales del suelo (`_impacto_en_suelo`).
const ACCION_DE: Dictionary = {"agua": "agua", "hielo": "frio", "fuego": "calor"}
## Fases de la hierba de la maqueta (`PruebaTest2.Fase`; no tiene class_name, como en bosque_01_3d.gd).
const FASE_ARDIENDO: int = 3
const FASE_CENIZAS: int = 4
## El shader del suelo pinta «quemado» cuando el canal R pasa de 0,5 (`smoothstep(0.5 - dureza, 0.5 + dureza, e.r)`): la hierba cuenta como
## quemada exactamente desde que se VE quemada, ni antes ni después.
const UMBRAL_QUEMADA: float = 0.5
## 27/10: s que una casilla de HIERBA queda «mojada» tras el agua (= `Hierba3D.MOJADA_S` y `PruebaTest2.T_MOJADA_MS`: lo que la hierba se ve mojada y tarda en poder prender).
const HIERBA_MOJADA_S: float = 8.0

## Callable(c: Vector2i) -> String: «agua» | «hierba» | «suelo» | «» (no recibe nada). Lo pone Lanzador3D.configurar.
static var clasificar: Callable = Callable()

## 28/10 · A2: Callable(elemento: String, c: Vector2i) -> String con lo que ese elemento le haría a la HIERBA de la casilla (la regla de la maqueta, `prever_hierba`). Lo pone Lanzador3D.configurar.
static var prever_hierba: Callable = Callable()

## Casillas cuyo «quemada» puso `sincronizar_hierba` (solo esas puede quitar: lo que ponga otro no lo toca).
static var _hierba_mia: Dictionary = {}


## De qué clase es la casilla para los estados del suelo.
static func clase_de(c: Vector2i) -> String:
	if clasificar.is_valid():
		return String(clasificar.call(c))
	# Respaldo sin maqueta (pruebas con un terreno suelto): por letras, sin saber de hierba.
	if not Terreno3D.hay_mundo():
		return ""
	var l: String = Terreno3D.letra_de(c)
	if l == "~" or l == "b":
		return "agua"
	if Terreno3D.bloqueada(c):
		return ""
	return "suelo"


## Aplica un impacto al estado del suelo. Devuelve lo que devolvió `EstadosSuelo3D.aplicar` ({cambio, efecto}) o {} si no tocaba nada.
## Un chorro que dura (`duracion` > 0) no es un impacto por casilla y no hace nada.
static func aplicar(a: AccionElemental) -> Dictionary:
	var accion: String = String(ACCION_DE.get(a.elemento, ""))
	if accion == "" or a.duracion > 0.0:
		return {}
	var c: Vector2i = Terreno3D.celda_de(a.punto)
	if not Terreno3D.en_mapa(c):
		return {}
	# H4 (DISENO_FUTURO §0b): agua y hielo solo existen a nivel 0; en altura el hechizo golpea el bloque, no el suelo de debajo. El fuego sí llega.
	if accion != "calor" and Terreno3D.altura_en(c) >= 1:
		return {}
	var clase: String = clase_de(c)
	if clase == "hierba" and accion == "agua":
		# 27/10: el agua sobre HIERBA también deja la casilla «mojada» para las reglas (`casilla(x,y).mojada`). Solo eso: la hierba no entra en
		# la tabla de transiciones (el fuego de la hierba es del autómata de la maqueta y su escarcha de Hierba3D), y dura lo mismo que la
		# hierba se ve mojada y no prende (HIERBA_MOJADA_S), no los 20 s del suelo desnudo.
		var cambio: bool = Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, true, 1.0, HIERBA_MOJADA_S)
		return {"cambio": cambio, "efecto": ""}
	if clase != "suelo":
		return {}
	return Terreno3D.estados.aplicar(c, accion)


## 28/10 · A2 (previsión): qué le haría un impacto de `elemento` a la casilla `c`, SIN aplicar nada. Devuelve {} si no pasaría nada, o {reaccion, extra}:
##   hierba  prende · arde · brota · apaga · abanica (`prever_hierba` de la maqueta)    suelo  hiela · moja · seca · derrite (la fila de `EstadosSuelo3D.TRANSICIONES` que `aplicar` usaría)
##   agua    hiela (el hielo sobre agua con fondo) · derrite (el fuego sobre agua helada) · evapora (el fuego sobre agua)
## Son las mismas reglas que `aplicar` y la simulación del agua (`ReaccionesAgua3D`); lo que no cambia el suelo (rayo, tierra, viento) no devuelve nada.
## `solo_hierba`: el impacto del VFX de un proyectil que se para (el agua no marca casillas) solo alcanza a la hierba de la maqueta (`_al_impactar`), no escribe estados del suelo.
static func prever(elemento: String, c: Vector2i, solo_hierba: bool = false) -> Dictionary:
	if not Terreno3D.en_mapa(c):
		return {}
	var accion: String = String(ACCION_DE.get(elemento, ""))
	var clase: String = clase_de(c)
	if solo_hierba and clase != "hierba":
		return {}                                           # el impacto que dibuja el VFX (un proyectil que se para) solo llega a la hierba de la maqueta; los estados los escribe `marcar_celda`
	if clase == "hierba":
		if prever_hierba.is_valid():
			var r: String = String(prever_hierba.call(elemento, c))
			if r != "":
				return {"reaccion": r, "extra": {"clase": "hierba"}}
		if accion == "agua" and not Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA):
			return {"reaccion": "moja", "extra": {"clase": "hierba"}}
		return {}
	if accion == "":
		return {}
	if accion != "calor" and Terreno3D.altura_en(c) >= 1:
		return {}                                           # H4: agua y hielo solo a nivel 0
	if clase == "agua":
		var sim: AguaSim3D = Terreno3D.agua_sim
		var honda: bool = sim != null and sim.profundidad_casilla(c) > 0.05
		match elemento:
			"hielo":
				if honda and not Terreno3D.helada(c):
					return {"reaccion": "hiela", "extra": {"clase": "agua"}}
			"fuego":
				if Terreno3D.helada(c):
					return {"reaccion": "derrite", "extra": {"clase": "agua"}}
				if honda:
					return {"reaccion": "evapora", "extra": {"clase": "agua"}}
		return {}
	if clase != "suelo":
		return {}
	var fila: Dictionary = Terreno3D.estados.fila_para(c, accion)
	if fila.is_empty():
		return {}
	var pone: Array = fila["pone"]
	var quita: Array = fila["quita"]
	var nombre: String = ""
	if pone.has(EstadosSuelo3D.HELADA) and not Terreno3D.estados.tiene(c, EstadosSuelo3D.HELADA):
		nombre = "hiela"
	elif pone.has(EstadosSuelo3D.MOJADA) and not quita.has(EstadosSuelo3D.HELADA):
		nombre = "moja" if not Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA) else ""
	elif quita.has(EstadosSuelo3D.HELADA) and pone.has(EstadosSuelo3D.MOJADA):
		nombre = "derrite"
	elif quita.has(EstadosSuelo3D.MOJADA) and pone.is_empty():
		nombre = "seca"
	if nombre == "":
		return {}
	return {"reaccion": nombre, "extra": {"clase": "suelo", "efecto": String(fila["efecto"])}}


## El hielo de una casilla de SUELO caduca (20 s, `Lanzador3D._derretir`): la maqueta quita el canal «helado» y deja la casilla mojada, y el
## estado hace lo mismo. Solo quita la escarcha (el hielo que congeló la simulación se deshiela por su cuenta).
static func derretir(c: Vector2i) -> void:
	if clase_de(c) != "suelo":
		return
	var e: EstadosSuelo3D = Terreno3D.estados
	if e.es_escarcha(c):
		e.poner(c, EstadosSuelo3D.HELADA, false)
	e.poner(c, EstadosSuelo3D.MOJADA, true)


## «quemada» de la hierba: sigue al autómata de la maqueta (`_hf`: fase por casilla) y a su AVANCE visual (`EstadosSuelo3D.avance`, que la
## maqueta sube mientras arde: el círculo quemado que crece). Una casilla es `quemada` mientras su hierba está ARDIENDO o hecha CENIZAS y el
## círculo quemado ya se ve (avance ≥ UMBRAL_QUEMADA). Si el agua la apaga (la maqueta la deja FINA otra vez y borra el avance), el estado
## se quita en el mismo fotograma. Barato: solo recorre las casillas de hierba que no son finas, y nada si no hay ninguna. Lo llama
## `Lanzador3D._process`.
static func sincronizar_hierba(m: Object) -> void:
	if m == null:
		return
	var hf: Variant = m.get("_hf")
	if not (hf is Dictionary):
		return
	var fases: Dictionary = hf
	if fases.is_empty() and _hierba_mia.is_empty():
		return
	var e: EstadosSuelo3D = Terreno3D.estados
	var vistas: Dictionary = {}
	for k in fases:
		var c: Vector2i = k
		var f: int = int((fases[k] as Dictionary).get("fase", 0))
		if f != FASE_ARDIENDO and f != FASE_CENIZAS:
			continue
		if e.avance(c, EstadosSuelo3D.QUEMADA) < UMBRAL_QUEMADA:
			continue
		vistas[c] = true
		if not _hierba_mia.has(c) and e.poner(c, EstadosSuelo3D.QUEMADA, true):
			_hierba_mia[c] = true
	for k in _hierba_mia.keys():
		if not vistas.has(k):
			e.poner(k as Vector2i, EstadosSuelo3D.QUEMADA, false)
			_hierba_mia.erase(k)


## Cambio de nivel: olvida lo que había puesto (los estados se vacían con `Terreno3D.estados.limpiar`).
static func reiniciar() -> void:
	_hierba_mia.clear()
