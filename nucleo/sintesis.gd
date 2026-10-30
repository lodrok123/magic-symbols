class_name Sintesis
extends RefCounted

## LA SÍNTESIS (F3 de PLAN_BASE_DATOS §4, 29/10, Juego): hacer cosas con lo que llevas en la bolsa. Todo sale de `nucleo/datos/recetas.tsv`; aquí no hay una receta escrita.
##
## UNA RECETA pide `requiere` (una lista `etiqueta>=n`) y, a veces, un `ancla` (un ingrediente obligatorio). La bolsa cumple si, SUMANDO la `potencia` de los objetos que el jugador
## pone sobre la mesa (cada objeto cuenta a CADA una de sus etiquetas), cada etiqueta llega a `n`. El jugador ELIGE qué gastar (`eleccion` = objeto -> unidades); lo que sobra NO se devuelve.
## `oro` lo cobra el alquimista (0 en la hoguera). `da` es `objeto:n` o `mejora:<id>` (sube un nivel con `Mejoras.subir`). `donde` ∈ alquimista, hoguera.
##
## SIN INTERFAZ: la pestaña «Síntesis» es del Pipeline. Este archivo es la API que pinta: `conocidas(donde)` -> qué recetas enseñar; `puede(id, eleccion)` -> la barra de cada
## etiqueta (`falta`) y por qué no; `sugerir(id)` -> el botón «Sugerir»; `hacer(id, eleccion)` -> el botón «Hacer». Las señales viven en la instancia única (`Sintesis.i()`):
## `descubierta(id)`, `hecha(id)`, `aviso(texto)` y `sintesis_abierta(donde)` (la hoguera y el alquimista la emiten, ver `abrir`).
##
## `se_conoce` (qué recetas aparecen en el libro), seis formas: `siempre` · `al tener los ingredientes` · `flag:<nombre>` · `mejora:<id>>=<n>` · `tener:<objeto>` · `al entrar en una
## zona con <estado>`. Una receta que se descubre se apunta en `Partida.recetas_conocidas` y ya no se olvida (viaja con la partida). La última lee `estados_zona`, la lista de
## estados del mundo de la zona donde está la jugadora; el nivel la rellena (F4 la conecta a los estados del mundo).

signal descubierta(id: String)
signal hecha(id: String)
signal aviso(texto: String)
signal sintesis_abierta(donde: String)

static var _inst: Sintesis = null
## Estados del mundo de la zona actual («calor», «frio»...), que rellena el nivel. De momento una variable: F4 la conecta.
static var estados_zona: Array = []


static func i() -> Sintesis:
	if _inst == null:
		_inst = Sintesis.new()
	return _inst


## Abre la síntesis en `donde` ("hoguera" o "alquimista"): avisa a quien la pinte. Sin interfaz, no pasa nada más.
static func abrir(donde: String) -> void:
	i().sintesis_abierta.emit(donde)


## --- Lectura de la receta ---

## `requiere` de la receta como etiqueta -> n (`["vital>=3", "agua>=2"]` -> {vital: 3, agua: 2}).
static func requisitos(id: String) -> Dictionary:
	var r: Dictionary = {}
	for t in (BD.receta(id).get("requiere", []) as Array):
		var par: PackedStringArray = String(t).split(">=")
		if par.size() == 2:
			r[par[0].strip_edges()] = par[1].strip_edges().to_int()
	return r


static func ancla(id: String) -> String:
	return String(BD.receta(id).get("ancla", ""))


## Lo que suman las unidades elegidas a cada etiqueta: potencia × unidades, para CADA etiqueta del objeto.
static func totales(eleccion: Dictionary) -> Dictionary:
	var t: Dictionary = {}
	for obj in eleccion:
		var n: int = int(eleccion[obj])
		if n <= 0:
			continue
		for et in Objetos.etiquetas(String(obj)):
			t[String(et)] = int(t.get(String(et), 0)) + Objetos.potencia(String(obj)) * n
	return t


## --- Qué recetas se enseñan ---

## Las recetas conocidas (en el orden de la tabla), opcionalmente solo las de `donde`. Descubrir una (su `se_conoce` se cumple por primera vez) la apunta para siempre.
static func conocidas(donde: String = "") -> Array[String]:
	var res: Array[String] = []
	for id in BD.recetas():
		var r: Dictionary = BD.recetas()[id]
		if donde != "" and not (r.get("donde", []) as Array).has(donde):
			continue
		if es_conocida(String(id)):
			res.append(String(id))
	return res


## ¿Se conoce `id`? Mira primero lo ya descubierto y, si no, evalúa su `se_conoce` (y, si se cumple, lo descubre: apunta y avisa).
static func es_conocida(id: String) -> bool:
	var r: Dictionary = BD.receta(id)
	if r.is_empty():
		return false
	var cond: String = String(r.get("se_conoce", "siempre"))
	if cond == "siempre":
		return true
	if Partida.recetas_conocidas.has(id):
		return true
	if not cumple_se_conoce(id, cond):
		return false
	Partida.recetas_conocidas.append(id)
	i().descubierta.emit(id)
	return true


## Evalúa una condición de `se_conoce` SIN apuntar nada. Una condición que no se entiende no se cumple (y avisa por consola: sería una errata de la tabla).
static func cumple_se_conoce(id: String, cond: String) -> bool:
	if cond == "siempre":
		return true
	if cond == "al tener los ingredientes":
		var sug: Dictionary = sugerir(id)
		var p: Dictionary = puede(id, sug)
		return (p["falta"] as Dictionary).is_empty() and String(p["ancla_falta"]) == ""
	if cond.begins_with("flag:"):
		return Flags.i().tiene(cond.substr(5).strip_edges())
	if cond.begins_with("mejora:"):
		var par: PackedStringArray = cond.substr(7).split(">=")
		return par.size() == 2 and Mejoras.nivel(par[0].strip_edges()) >= par[1].strip_edges().to_int()
	if cond.begins_with("tener:"):
		return Estado.i().cuenta(cond.substr(6).strip_edges()) > 0
	if cond.begins_with("al entrar en una zona con "):
		return estados_zona.has(cond.substr(26).strip_edges())
	push_warning("Sintesis: no entiendo se_conoce «%s» de la receta %s" % [cond, id])
	return false


## --- ¿Se puede? ---

## ¿Se puede hacer `id` con `eleccion` (objeto -> unidades) en `donde` ("" = no se mira el sitio)? Devuelve
## `{ok, falta: etiqueta -> lo que le falta, oro_falta, ancla_falta (id o ""), no_hay: objeto -> lo que sobra de la elección sobre lo que llevas, motivo}`.
## `motivo` ("" si ok) es lo primero que se le diría al jugador: «receta», «lugar», «tope», «ancla», «falta», «bolsa», «oro».
static func puede(id: String, eleccion: Dictionary, donde: String = "") -> Dictionary:
	var res: Dictionary = {"ok": false, "falta": {}, "oro_falta": 0, "ancla_falta": "", "no_hay": {}, "motivo": ""}
	var r: Dictionary = BD.receta(id)
	if r.is_empty():
		res["motivo"] = "receta"
		return res
	var e: Estado = Estado.i()
	var tot: Dictionary = totales(eleccion)
	var req: Dictionary = requisitos(id)
	for et in req:
		var f: int = int(req[et]) - int(tot.get(et, 0))
		if f > 0:
			(res["falta"] as Dictionary)[et] = f
	var anc: String = ancla(id)
	if anc != "" and (int(eleccion.get(anc, 0)) <= 0 or e.cuenta(anc) <= 0):
		res["ancla_falta"] = anc
	res["oro_falta"] = maxi(0, int(r.get("oro", 0)) - e.oro)
	for obj in eleccion:
		var sobra: int = int(eleccion[obj]) - e.cuenta(String(obj))
		if sobra > 0:
			(res["no_hay"] as Dictionary)[String(obj)] = sobra
	var motivo: String = ""
	if donde != "" and not (r.get("donde", []) as Array).has(donde):
		motivo = "lugar"
	elif _al_tope(r):
		motivo = "tope"
	elif String(res["ancla_falta"]) != "":
		motivo = "ancla"
	elif not (res["falta"] as Dictionary).is_empty():
		motivo = "falta"
	elif not (res["no_hay"] as Dictionary).is_empty():
		motivo = "bolsa"
	elif int(res["oro_falta"]) > 0:
		motivo = "oro"
	res["motivo"] = motivo
	res["ok"] = motivo == ""
	return res


## La receta sube una mejora que ya está en su tope.
static func _al_tope(r: Dictionary) -> bool:
	var da: String = String(r.get("da", ""))
	return da.begins_with("mejora:") and Mejoras.al_tope(da.substr(7))


## --- Sugerir ---

## Rellena la elección sola con lo MÁS BARATO de la bolsa: primero el ancla (una unidad), luego los objetos que suben alguna etiqueta pendiente, de menos a más potencia, y de
## uno en uno mientras sigan sirviendo. NUNCA gasta un épico o legendario salvo que sea el ancla. Devuelve una elección que `puede` acepta, o, si la bolsa no da, la mejor parcial.
static func sugerir(id: String) -> Dictionary:
	var eleccion: Dictionary = {}
	var r: Dictionary = BD.receta(id)
	if r.is_empty():
		return eleccion
	var e: Estado = Estado.i()
	var req: Dictionary = requisitos(id)
	var anc: String = ancla(id)
	if anc != "" and e.cuenta(anc) > 0:
		eleccion[anc] = 1
	var cand: Array = []
	for obj in e.items:
		var o: String = String(obj)
		if Objetos.calidad(o) != Objetos.CALIDAD_COMUN and o != anc:
			continue                                              # los épicos y legendarios se gastan a propósito, no por sugerencia
		var sirve: bool = false
		for et in Objetos.etiquetas(o):
			if req.has(String(et)):
				sirve = true
		if sirve and Objetos.potencia(o) > 0:
			cand.append(o)
	cand.sort_custom(func(a: String, b: String) -> bool:
		var pa: int = Objetos.potencia(a)
		var pb: int = Objetos.potencia(b)
		return pa < pb or (pa == pb and a < b))
	for o in cand:
		while e.cuenta(o) > int(eleccion.get(o, 0)) and _sirve_aun(o, req, eleccion):
			eleccion[o] = int(eleccion.get(o, 0)) + 1
	return eleccion


## ¿Una unidad más de `o` sube alguna etiqueta que todavía no llega a lo que pide la receta?
static func _sirve_aun(o: String, req: Dictionary, eleccion: Dictionary) -> bool:
	var tot: Dictionary = totales(eleccion)
	for et in Objetos.etiquetas(o):
		if req.has(String(et)) and int(tot.get(String(et), 0)) < int(req[String(et)]):
			return true
	return false


## --- Hacer ---

## Hace la receta si `puede`: quita de la bolsa EXACTAMENTE lo elegido (lo que sobra de potencia no se devuelve), cobra el oro y da lo que diga `da`. Si lo que da no cabe en la
## bolsa NO se hace nada (no se destruyen ingredientes sin dar algo): se avisa y todo queda como estaba.
static func hacer(id: String, eleccion: Dictionary, donde: String = "") -> bool:
	var p: Dictionary = puede(id, eleccion, donde)
	if not bool(p["ok"]):
		i().aviso.emit(_texto_motivo(String(p["motivo"])))
		return false
	var r: Dictionary = BD.receta(id)
	var e: Estado = Estado.i()
	var antes: Dictionary = e.items.duplicate()
	for obj in eleccion:
		if int(eleccion[obj]) > 0:
			e.quitar(String(obj), int(eleccion[obj]))
	var da: String = String(r.get("da", ""))
	var dado: bool = false
	if da.begins_with("mejora:"):
		dado = Mejoras.subir(da.substr(7))
	else:
		var par: PackedStringArray = da.split(":")
		var obj: String = par[0]
		var n: int = par[1].to_int() if par.size() > 1 else 1
		dado = obj != "" and e.sitio_para(obj) >= n and e.agregar(obj, n) >= n
		if not dado:
			i().aviso.emit("No te cabe en la mochila")
	if not dado:
		e.items = antes                                          # nada se pierde
		e.cambiado.emit()
		return false
	if int(r.get("oro", 0)) > 0:
		e.gastar_oro(int(r["oro"]))
	i().hecha.emit(id)
	return true


static func _texto_motivo(motivo: String) -> String:
	match motivo:
		"lugar":
			return "Aquí no se hace eso"
		"tope":
			return "Ya no puede mejorar más"
		"ancla":
			return "Falta el ingrediente base"
		"falta":
			return "Faltan ingredientes"
		"bolsa":
			return "No llevas eso"
		"oro":
			return "No te llega el oro"
	return "No se puede"


## --- Pigmentos como objetos ---

## Un objeto de uso «pigmento» (`efecto.pigmento = <id de Tinta.PIGMENTOS>`) se aplica a la tinta: gasta UNA unidad y activa el pigmento (60 s, sustituye al anterior).
## `tinta` = la de la jugadora (por defecto `Partida.tinta`). false si no es un pigmento, el id no existe en `Tinta.PIGMENTOS`, no hay tinta o no lo llevas.
static func aplicar_pigmento(objeto: String, tinta: Tinta = null, e: Estado = null) -> bool:
	var est: Estado = e if e != null else Estado.i()
	var t: Tinta = tinta if tinta != null else Partida.tinta
	if t == null or String(BD.objeto(objeto).get("uso", "")) != "pigmento" or est.cuenta(objeto) <= 0:
		return false
	var pig: String = String(Objetos.efecto(objeto).get("pigmento", ""))
	if not Tinta.PIGMENTOS.has(pig):
		push_warning("Sintesis: el objeto %s pide el pigmento «%s», que no existe en Tinta.PIGMENTOS" % [objeto, pig])
		return false
	if not t.activar_pigmento(pig):
		return false
	est.quitar(objeto)
	return true
