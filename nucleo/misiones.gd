class_name Misiones
extends RefCounted

## EL DIARIO DE MISIONES (Fase 14.3, 16/10, Juego): UNA sola API para las tareas de un nivel, en lugar de la lista de casillas que cada
## nivel llevaba por su cuenta (Jugabilidad3D, Bosque3D, TerraFina3D). Un nivel DEFINE sus misiones, las ACTIVA y va marcando
## objetivos; el diario (J) y la línea del HUD solo LEEN de aquí.
##
## Una misión es un Dictionary (se guarda tal cual, por eso no es una clase):
##   id          String        único (se usa en las señales y en el guardado)
##   titulo      String
##   tipo        "principal" | "secundaria"
##   estado      "oculta" | "activa" | "completa"      (oculta: el diario no la enseña hasta que se activa)
##   texto       String        2–3 frases: quién, qué, dónde
##   objetivos   Array de {texto: String, hecho: bool}
##   origen      String        quién la da o dónde nace («Guardabosques», «Claro del Bosque»)
##   recompensa  {oro: int, items: {id: n}}            (se paga UNA vez, al completarse)
##   orden       int           desempate al listar (la definición más antigua primero)
##
## Se completa sola cuando todos sus objetivos están hechos (`auto_completa`, true por defecto en `definir`); se puede completar a mano
## con `completar(id)` (misiones sin objetivos, o que se cierran por una conversación).
##
## SEÑALES. `mision_cambio(id)` en CUALQUIER cambio (definir, activar, objetivo, completar). `seguida_cambio(id)` al cambiar la misión
## seguida (la que el HUD enseña en una línea). El diario y el HUD se redibujan con ellas; nadie sondea.
##
## GUARDADO. `guardar()` / `cargar()` leen y escriben `ruta_guardado` (JSON en user://). Las misiones se guardan con su estado, sus
## objetivos y cuál se sigue. NO se guarda solo al cambiar (un test que se reinicia no debe heredar lo del anterior): lo llaman los puntos
## de guardado del nivel (`Jugabilidad3D`: «Punto de guardado») y quien quiera continuar una partida llama a `cargar()` ANTES de que el
## nivel defina sus misiones; las que vinieron del guardado conservan su progreso al `definir` (ver `definir`).
##
## Qué NO hace: no sabe nada de niveles, enemigos ni objetos. Quien los vigila (el nivel) marca el objetivo.

signal mision_cambio(id: String)
signal seguida_cambio(id: String)

const TIPOS: PackedStringArray = ["principal", "secundaria"]
const ESTADOS: PackedStringArray = ["oculta", "activa", "completa"]
const RUTA_DEFECTO: String = "user://misiones.json"

static var _inst: Misiones = null

var ruta_guardado: String = RUTA_DEFECTO
var _misiones: Dictionary = {}           ## id -> misión
var _orden: Array = []                   ## ids en el orden de definición
var _seguida: String = ""
var _del_guardado: Dictionary = {}       ## ids que vinieron de `cargar()`: al definirlos de nuevo se conserva el progreso


static func i() -> Misiones:
	if _inst == null:
		_inst = Misiones.new()
	return _inst


## Empezar de cero (los escenarios y las pruebas lo usan para no heredar nada).
static func nuevo() -> Misiones:
	_inst = Misiones.new()
	return _inst


## Define (o redefine) una misión. Campos que falten: tipo «secundaria», estado «oculta», textos vacíos. Si `id` vino del guardado y
## sigue estando, se conserva su estado y los objetivos que ya estaban hechos (se casan por posición) y solo se refrescan los textos.
## Si no, se sustituye por la nueva (un nivel que se reinicia empieza limpio). Devuelve el id.
func definir(datos: Dictionary) -> String:
	var id: String = String(datos.get("id", ""))
	if id == "":
		push_warning("Misiones.definir: falta el id")
		return ""
	var m: Dictionary = {
		"id": id,
		"titulo": String(datos.get("titulo", id)),
		"tipo": String(datos.get("tipo", "secundaria")),
		"estado": String(datos.get("estado", "oculta")),
		"texto": String(datos.get("texto", "")),
		"objetivos": [],
		"origen": String(datos.get("origen", "")),
		"recompensa": _recompensa(datos.get("recompensa", {})),
		"orden": _orden.size(),
		"auto_completa": bool(datos.get("auto_completa", true)),
		"pagada": false,
	}
	if not TIPOS.has(m["tipo"]):
		push_warning("Misiones.definir: tipo desconocido «%s» en %s; se usa «secundaria»" % [m["tipo"], id])
		m["tipo"] = "secundaria"
	if not ESTADOS.has(m["estado"]):
		m["estado"] = "oculta"
	for o in datos.get("objetivos", []):
		if o is Dictionary:
			(m["objetivos"] as Array).append({"texto": String((o as Dictionary).get("texto", "")), "hecho": bool((o as Dictionary).get("hecho", false))})
		else:
			(m["objetivos"] as Array).append({"texto": String(o), "hecho": false})
	if _del_guardado.has(id) and _misiones.has(id):
		var vieja: Dictionary = _misiones[id]
		m["estado"] = vieja["estado"]
		m["pagada"] = vieja.get("pagada", false)
		m["orden"] = vieja["orden"]
		var ov: Array = vieja["objetivos"]
		for k in range(mini(ov.size(), (m["objetivos"] as Array).size())):
			m["objetivos"][k]["hecho"] = bool(ov[k]["hecho"])
		_del_guardado.erase(id)
	elif _misiones.has(id):
		m["orden"] = (_misiones[id] as Dictionary)["orden"]
	if not _misiones.has(id):
		_orden.append(id)
	_misiones[id] = m
	mision_cambio.emit(id)
	return id


func existe(id: String) -> bool:
	return _misiones.has(id)


## Una COPIA de la misión (para que quien lee no la modifique sin pasar por aquí). {} si no existe.
func get_mision(id: String) -> Dictionary:
	return (_misiones[id] as Dictionary).duplicate(true) if _misiones.has(id) else {}


func estado(id: String) -> String:
	return String((_misiones[id] as Dictionary)["estado"]) if _misiones.has(id) else ""


## Ids en orden de definición, filtrando por estado si se pide (p. ej. «activa»). Las ocultas solo salen si se piden.
func ids(solo_estado: String = "") -> Array:
	var r: Array = []
	for id in _orden:
		var e: String = estado(id)
		if solo_estado == "" and e == "oculta":
			continue
		if solo_estado == "" or e == solo_estado:
			r.append(id)
	return r


## Para el diario: primero las principales, luego las secundarias; dentro de cada una, las activas antes que las completas.
func lista_para_diario() -> Array:
	var r: Array = ids()
	r.sort_custom(func(a: String, b: String) -> bool:
		var ma: Dictionary = _misiones[a]
		var mb: Dictionary = _misiones[b]
		var ta: int = TIPOS.find(ma["tipo"])
		var tb: int = TIPOS.find(mb["tipo"])
		if ta != tb:
			return ta < tb
		var ea: int = 1 if ma["estado"] == "completa" else 0
		var eb: int = 1 if mb["estado"] == "completa" else 0
		if ea != eb:
			return ea < eb
		return int(ma["orden"]) < int(mb["orden"]))
	return r


func activar(id: String) -> void:
	if not _misiones.has(id) or estado(id) != "oculta":
		return
	(_misiones[id] as Dictionary)["estado"] = "activa"
	mision_cambio.emit(id)
	# La primera misión que se activa pasa a ser la seguida (si no hay ninguna): el jugador siempre ve algo en el HUD.
	if _seguida == "" or estado(_seguida) != "activa":
		seguir(id)


## Marca (o desmarca) un objetivo. Si con eso están todos hechos y la misión se autocompleta, la completa. Devuelve true si cambió algo.
func objetivo_hecho(id: String, indice: int, hecho: bool = true) -> bool:
	if not _misiones.has(id):
		return false
	var m: Dictionary = _misiones[id]
	var objs: Array = m["objetivos"]
	if indice < 0 or indice >= objs.size() or bool(objs[indice]["hecho"]) == hecho:
		return false
	if m["estado"] == "completa":
		return false                              # una misión cerrada no se reabre por un objetivo suelto
	objs[indice]["hecho"] = hecho
	mision_cambio.emit(id)
	if hecho and bool(m["auto_completa"]) and m["estado"] == "activa" and objetivos_pendientes(id) == 0:
		completar(id)
	return true


## Cambia el texto de un objetivo (los que llevan una cuenta: «Derrotar gatopedros (2/3)»).
func objetivo_texto(id: String, indice: int, texto: String) -> void:
	if not _misiones.has(id):
		return
	var objs: Array = (_misiones[id] as Dictionary)["objetivos"]
	if indice < 0 or indice >= objs.size() or String(objs[indice]["texto"]) == texto:
		return
	objs[indice]["texto"] = texto
	mision_cambio.emit(id)


func objetivos_pendientes(id: String) -> int:
	var n: int = 0
	if _misiones.has(id):
		for o in (_misiones[id] as Dictionary)["objetivos"]:
			if not bool(o["hecho"]):
				n += 1
	return n


## (hechos, total) de una misión.
func progreso(id: String) -> Vector2i:
	if not _misiones.has(id):
		return Vector2i.ZERO
	var objs: Array = (_misiones[id] as Dictionary)["objetivos"]
	return Vector2i(objs.size() - objetivos_pendientes(id), objs.size())


## Cierra la misión y paga la recompensa (solo la primera vez). Una oculta se completa igualmente (pasa por activa sin avisar).
func completar(id: String) -> void:
	if not _misiones.has(id) or estado(id) == "completa":
		return
	var m: Dictionary = _misiones[id]
	m["estado"] = "completa"
	for o in m["objetivos"]:
		o["hecho"] = true
	if not bool(m["pagada"]):
		m["pagada"] = true
		var rec: Dictionary = m["recompensa"]
		if int(rec.get("oro", 0)) > 0:
			Estado.i().dar_oro(int(rec["oro"]))
		for item in (rec.get("items", {}) as Dictionary):
			Estado.i().agregar(String(item), int((rec["items"] as Dictionary)[item]))
	PlayLog.event("mision", {"id": id, "estado": "completa"})
	mision_cambio.emit(id)
	if _seguida == id:
		# La siguiente misión activa pasa a seguirse sola.
		var siguiente: String = ""
		for otra in lista_para_diario():
			if otra != id and estado(otra) == "activa":
				siguiente = otra
				break
		seguir(siguiente)


## --- La misión seguida y la línea del HUD ---

func seguida_id() -> String:
	return _seguida


## Sigue una misión activa ("" = no seguir ninguna). Una que no está activa no se puede seguir.
func seguir(id: String) -> void:
	if id != "" and estado(id) != "activa":
		return
	if id == _seguida:
		return
	_seguida = id
	seguida_cambio.emit(_seguida)
	if id != "":
		mision_cambio.emit(id)


## El texto del primer objetivo pendiente de una misión ("" si no queda ninguno).
func objetivo_actual(id: String) -> String:
	if not _misiones.has(id):
		return ""
	for o in (_misiones[id] as Dictionary)["objetivos"]:
		if not bool(o["hecho"]):
			return String(o["texto"])
	return ""


## La línea discreta del HUD: «Título · objetivo actual». Vacía si no se sigue nada.
func linea_hud() -> String:
	if _seguida == "" or estado(_seguida) != "activa":
		return ""
	var m: Dictionary = _misiones[_seguida]
	var o: String = objetivo_actual(_seguida)
	return "%s · %s" % [m["titulo"], o] if o != "" else String(m["titulo"])


## --- Guardado ---

func a_dic() -> Dictionary:
	return {"version": 1, "seguida": _seguida, "orden": _orden.duplicate(), "misiones": _misiones.duplicate(true)}


## Sustituye lo que hay por lo guardado. Los ids cargados conservan su progreso en el siguiente `definir`.
func desde_dic(d: Dictionary) -> void:
	_misiones.clear()
	_orden.clear()
	_del_guardado.clear()
	var ms: Dictionary = d.get("misiones", {})
	for id in d.get("orden", []):
		if ms.has(id):
			_orden.append(String(id))
			var m: Dictionary = (ms[id] as Dictionary).duplicate(true)
			# JSON devuelve los números como float: se devuelven a su tipo.
			m["orden"] = int(m.get("orden", 0))
			m["recompensa"] = _recompensa(m.get("recompensa", {}))
			_misiones[String(id)] = m
			_del_guardado[String(id)] = true
	_seguida = String(d.get("seguida", ""))
	if _seguida != "" and estado(_seguida) != "activa":
		_seguida = ""
	for id in _orden:
		mision_cambio.emit(id)
	seguida_cambio.emit(_seguida)


func guardar(ruta: String = "") -> bool:
	var r: String = ruta if ruta != "" else ruta_guardado
	if r == "":
		return false
	var f := FileAccess.open(r, FileAccess.WRITE)
	if f == null:
		push_warning("Misiones.guardar: no se pudo abrir %s" % r)
		return false
	f.store_string(JSON.stringify(a_dic()))
	f.close()
	return true


## Carga el guardado si existe. Devuelve true si cargó algo.
func cargar(ruta: String = "") -> bool:
	var r: String = ruta if ruta != "" else ruta_guardado
	if r == "" or not FileAccess.file_exists(r):
		return false
	var f := FileAccess.open(r, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (d is Dictionary):
		push_warning("Misiones.cargar: %s no es un guardado válido" % r)
		return false
	desde_dic(d)
	return true


static func _recompensa(r: Variant) -> Dictionary:
	var d: Dictionary = r if r is Dictionary else {}
	var items: Dictionary = {}
	for k in (d.get("items", {}) as Dictionary):
		items[String(k)] = int((d["items"] as Dictionary)[k])
	return {"oro": int(d.get("oro", 0)), "items": items}
