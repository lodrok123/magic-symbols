extends "res://herramientas/escenario_base.gd"
## LOS TRES NIVELES DE BOSQUE DE LA SECCIÓN JUGABLE (26/11/2026). Pablo: «hacer al menos 3 niveles medio grandes de bosque para las siguientes escenas: 01, 02 y
## cabaña del guardabosques, con el objetivo de preparar una sección jugable… el flujo será primero generar una aproximación con el generador y retocar a mano».
## Esta herramienta es esa primera aproximación, REPRODUCIBLE: la tabla NIVELES de abajo lleva, por nivel, los parámetros del generador, la semilla por la que
## empezar a buscar y los puzles del catálogo que tiene que llevar (uno por claro, en orden desde la entrada). Busca la primera semilla en la que cabe todo (sin
## errores ni avisos que no estén permitidos en `avisos_ok`), exporta mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn (con el exportador del generador, como el botón
## «Exportar»), carga cada escena y comprueba lo básico (piezas montadas, Puzle3D sin avisos, cabaña, enlaces). Imprime el inventario de cada nivel para el documento.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/generar_niveles_bosque.gd [-- nivel=BosqueGen02] [-- sin_cargar] [-- buscar]
##   · `nivel=<Nombre>`: solo ese nivel.  · `sin_cargar`: solo genera y exporta (no monta las escenas).  · `buscar`: ignora `semilla` fija y vuelve a buscar desde `semilla_ini`.
## Los niveles se pueden RETOCAR a mano en el generador (herramientas/generador_mapas/GeneradorMapas.tscn → «Abrir mapa generado»): los retoques quedan en el .txt
## (`; retoques`, `; movidos`, `; anadidos`…) y sobreviven a «Exportar». Si se vuelve a ejecutar ESTA herramienta, el .txt se regenera de la tabla (el exportador guarda
## antes una copia `<Nombre>_copia_<fecha>.txt` si el archivo se había retocado).
## Los enlaces entre niveles (Niveles.ESCENAS: BosqueGen01 → BosqueGen02 → BosqueCabana) son filas de nucleo/niveles.gd.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const SEMILLAS_MAX: int = 60            ## cuántas semillas se prueban, a partir de `semilla_ini`, antes de rendirse

## Lo común a los tres (se pisa con los `params` de cada nivel).
const BASE: Dictionary = {
	"algoritmo": "bosque", "estilo": "bosque", "luz": "bosque", "paredes": "kit", "decorado": true, "terreno": true, "acabado": true, "camara_sala": true,
	"rotulo": true, "rotulos_claros": true,
	"ancho_camino": 2, "ancho_rio": 2, "hierba_alta": 15, "solo_aceptados": false, "runas": "",     # solo_aceptados = false: hay puzles «pendientes» a propósito (ver el doc)
	"braseros": 0.0, "jarrones": 1.0, "charcas": 0, "salas_cerradas": 0, "llave": false, "sala_jefe": "no", "puzles": 0, "barreras": 0,
}

## NIVELES. `puzles` = ids del catálogo, EN ORDEN (el primero, en el claro más cercano a la entrada): dificultad creciente. `cofre` = calidad del cofre común que se enlaza
## a los puzles de tipo «salida» (activador sin premio propio): "comun" | "epico". `avisos_ok` = trozos de aviso del generador que se aceptan (con la razón en el doc).
const NIVELES: Array = [
	{
		"nombre": "BosqueGen01", "semilla_ini": 1, "semilla": 1,           # semilla fija (la primera que cumple todo); 0 = buscar desde semilla_ini
		"descripcion": "La entrada del bosque (tutorial): amable, fuego y empujar, un río con vado.",
		# Tamaño 72 × 60: 7 claros de dentro + el de la entrada + el de la salida = 9.
		"params": {"titulo_nivel": "El umbral del bosque", "titulos_claros": "0=El umbral del bosque;1=El camino al bosque profundo;4=El claro de los goblins", "ancho": 72, "alto": 60, "claros": 7, "tamano_claro": 5, "sinuosidad": 45, "bucles_claros": 25, "apertura": 60, "rio": "ns", "paso_tierra": 0,
			"enemigos": 0.5, "arqueros": 0, "jarrones": 3.0, "campamentos": 0, "barreras": 0, "tesoro": true, "kit": "demo_inicio",
			"salida_a": "MonteSumicio:desde_fraga=desde_sumicio,BosqueGen02:desde_01=desde_02", "lados_salida": "s,n"},
		"puzles": ["braseros_premio", "piedra_premio", "barril_muro", "braseros_puerta", "contrafuego"],
		"cofre": "comun", "avisos_ok": [],
	},
	{
		"nombre": "BosqueGen02", "semilla_ini": 1, "semilla": 1,
		"descripcion": "El bosque profundo: más grande y enrevesado, río que parte el mapa, campamento goblin, agua y tierra.",
		"params": {"titulo_nivel": "El bosque profundo", "titulos_claros": "1=La senda de la cabaña;2=El calvero de los goblins;3=El claro de la emboscada", "ancho": 90, "alto": 68, "claros": 10, "tamano_claro": 5, "sinuosidad": 60, "bucles_claros": 60, "apertura": 40, "rio": "ns", "paso_tierra": 2,
			"enemigos": 0.8, "arqueros": 30, "jarrones": 3.0, "campamentos": 1, "barreras": 0, "tesoro": false, "kit": "demo",
			"salida_a": "BosqueGen01:desde_02=desde_01,BosqueCabana:desde_02=desde_cabana", "lados_salida": "s,n"},
		"puzles": ["riega_pulsador", "escudo_flechas", "puente_raices", "placa_isla", "dos_riegos", "setas_veneno", "choque_termico"],
		"cofre": "comun", "avisos_ok": [],
	},
	{
		"nombre": "BosqueCabana", "semilla_ini": 1, "semilla": 1,
		"descripcion": "La cabaña del guardabosques: un claro grande y seguro con la casa; alrededor, puzles de premio y algún encuentro.",
		"params": {"titulo_nivel": "La senda del guardabosques", "titulos_claros": "0=La senda del guardabosques;1=El claro de la emboscada;7=El calvero de los goblins", "ancho": 84, "alto": 68, "claros": 9, "tamano_claro": 6, "sinuosidad": 50, "bucles_claros": 40, "apertura": 50, "rio": "eo", "paso_tierra": 0,
			"enemigos": 0.4, "arqueros": 25, "jarrones": 3.0, "campamentos": 0, "barreras": 0, "tesoro": false, "kit": "demo", "cabana": "prov_house_02",
			"salida_a": "BosqueGen02:desde_cabana=desde_02", "lados_salida": "s"},
		"puzles": ["braseros_orden", "escondite_muro", "dragon_brasero", "cofre_balsa", "estatuas_sellos", "puente_aliviadero"],
		"cofre": "epico", "avisos_ok": [],
	},
]

var _solo: String = ""
var _cargar: bool = true
var _buscar: bool = false
var _inventario: Array = []


func _escenario() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nivel="):
			_solo = a.substr(6)
		elif a == "sin_cargar":
			_cargar = false
		elif a == "buscar":
			_buscar = true
	Catalogo.recargar()
	for cfg in NIVELES:
		if _solo != "" and String(cfg["nombre"]) != _solo:
			continue
		await _nivel(cfg)
	print("---- INVENTARIO ----")
	for l in _inventario:
		print(l)


func _parametros(cfg: Dictionary, semilla: int) -> Dictionary:
	var par: Dictionary = Generador.parametros_defecto()
	par.merge(BASE, true)
	par.merge(cfg["params"] as Dictionary, true)
	par["nombre"] = String(cfg["nombre"])
	par["semilla"] = semilla
	return par


func _nivel(cfg: Dictionary) -> void:
	var nombre: String = String(cfg["nombre"])
	var elegido: Dictionary = {}
	var mapa: Dictionary = {}
	var semillas: Array = []
	if int(cfg["semilla"]) > 0 and not _buscar:
		semillas = [int(cfg["semilla"])]
	else:
		for s in range(int(cfg["semilla_ini"]), int(cfg["semilla_ini"]) + SEMILLAS_MAX):
			semillas.append(s)
	var semilla_ok: int = 0
	var motivos: PackedStringArray = PackedStringArray()
	for s in semillas:
		var par: Dictionary = _parametros(cfg, int(s))
		var r: Array = _colocar(par, cfg, motivos)
		if not r.is_empty():
			elegido = r[0]
			mapa = r[1]
			semilla_ok = int(s)
			break
	_ok("%s: hay una semilla donde cabe todo (%s)" % [nombre, str(semilla_ok)], not mapa.is_empty(), "\n  ".join(motivos.slice(maxi(0, motivos.size() - 12))))
	if mapa.is_empty():
		return
	print("%s: semilla %d" % [nombre, semilla_ok])
	var res: Dictionary = Exportador.exportar(mapa)
	_ok("%s: se exporta" % nombre, bool(res["ok"]), str(res))
	if not bool(res["ok"]):
		return
	_inventariar(cfg, mapa, elegido, semilla_ok)
	if _cargar:
		await _comprobar_escena(cfg, mapa)


## Genera con esos parámetros y pone los puzles de `cfg` en claros libres, en orden de cercanía a la entrada (el primero que cabe). Devuelve [sala → puzle, mapa] o [].
func _colocar(par: Dictionary, cfg: Dictionary, motivos: PackedStringArray) -> Array:
	var lista: Array = cfg["puzles"]
	var base: Dictionary = Generador.new().generar(par)
	var sem: int = int(par["semilla"])
	if not (base["errores"] as Array).is_empty():
		motivos.append("sem %d: errores %s" % [sem, str(base["errores"])])
		return []
	var libres: Array = (base["salas"] as Array).filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))
	# Tiene que quedar al menos un claro libre más que puzles (para los enemigos): si no, el nivel sería todo puzles.
	if libres.size() < lista.size() + 1:
		motivos.append("sem %d: solo %d claros libres para %d puzles" % [sem, libres.size(), lista.size()])
		return []
	if String(par.get("cabana", "")) != "" and (base["cabana"] as Dictionary).is_empty():
		motivos.append("sem %d: sin sitio para la cabaña" % sem)
		return []
	if int(par.get("campamentos", 0)) > 0 and not _hay_rol(base, "campamento"):
		motivos.append("sem %d: sin campamento" % sem)
		return []
	var asign: Dictionary = {}
	for cid in lista:
		var puesto: bool = false
		for s in libres:
			var sid: int = int(s["id"])
			if asign.has(sid):
				continue
			var prueba: Dictionary = asign.duplicate()
			prueba[sid] = cid
			var m: Dictionary = Generador.new().generar(par, {}, {}, prueba)
			var todos: bool = (m["errores"] as Array).is_empty()
			for k in prueba:
				todos = todos and String((m["puzles"] as Dictionary).get(k, "")) == String(prueba[k])
			if todos and _hay_rol(m, "campamento") == (int(par.get("campamentos", 0)) > 0) and (String(par.get("cabana", "")) == "" or not (m["cabana"] as Dictionary).is_empty()):
				asign = prueba
				puesto = true
				break
		if not puesto:
			motivos.append("sem %d: no cabe %s" % [sem, str(cid)])
			return []
	# Un cofre común (o el de `cofre`) enlazado a cada puzle de tipo «salida»: no tiene premio propio y sin cofre se vería muerto.
	var anadidos: Array = []
	var apariciones: Array = []
	var m0: Dictionary = Generador.new().generar(par, {}, {}, asign)
	var salas: Dictionary = {}
	for s in m0["salas"]:
		salas[int(s["id"])] = s
	for sid in asign:
		if String(Catalogo.todos()[asign[sid]]["tipo"]) == "salida":
			var r: Rect2i = salas[sid]["rect"]
			apariciones.append({"cofre": "a%d" % anadidos.size(), "enemigos": ["pz%d" % int(sid)]})
			var tipo: String = String(cfg.get("cofre", "comun"))
			var ped: Dictionary = {"que": "cofre", "tipo": tipo, "premio": "fragmento_savia:1+oro:60" if tipo == "epico" else "", "forzar": true}
			var dentro: Vector2i = _cofre_de_plantilla(m0, salas[sid], String(asign[sid]))
			ped["c"] = dentro if dentro.x >= 0 else _junto_al_activador(m0, salas[sid], String(asign[sid]), r)
			if dentro.x < 0:
				ped.erase("forzar")
			anadidos.append(ped)
	var m2: Dictionary = Generador.new().generar(par, {}, {}, asign, {}, anadidos, apariciones)
	for k in asign:
		if String((m2["puzles"] as Dictionary).get(k, "")) != String(asign[k]):
			motivos.append("sem %d: el puzle de la sala %d cambió al añadir los cofres" % [sem, int(k)])
			return []
	if (m2["anadidos"] as Array).size() != anadidos.size() or (m2["apariciones"] as Array).size() != apariciones.size() or not (m2["errores"] as Array).is_empty():
		motivos.append("sem %d: los cofres enlazados no caben (%s)" % [sem, str(m2["errores"])])
		return []
	var avisos_malos: Array = []
	for av in m2["avisos"]:
		# «El cofre que ponías en (x, y) ha quedado en (x, y−1)»: el cofre enlazado a un puzle «salida» se pide encima de su activador (la casilla de la pieza) y el
		# generador lo deja en la casilla libre más cercana (la misma fila de arriba). Es lo esperado (igual en los niveles Pt).
		var vale: bool = String(av).begins_with("El cofre que ponías en") and String(av).contains("era el sitio válido más cercano")
		for ok in cfg["avisos_ok"]:
			vale = vale or String(av).contains(String(ok))
		if not vale:
			avisos_malos.append(String(av))
	if not avisos_malos.is_empty():
		motivos.append("sem %d: avisos %s" % [sem, str(avisos_malos.slice(0, 2))])
		return []
	# Los puzles puestos a mano van al .txt (`; puzles`): `exportar` los lee de `puzles_mano` del mapa.
	return [asign, m2]


func _hay_rol(m: Dictionary, rol: String) -> bool:
	for s in m["salas"]:
		if String(s["rol"]) == rol:
			return true
	return false


# --- Los dos auxiliares de generar_playtest_puzles.gd (dónde va el cofre de un puzle «salida») ---

func _junto_al_activador(m: Dictionary, sala: Dictionary, cid: String, r: Rect2i) -> Vector2i:
	var res: String = String(Catalogo.todos().get(cid, {}).get("resuelto", ""))
	if sala.has("inst") and res.contains("."):
		var pieza: String = String(sala["inst"]) + "_" + res.split(".")[0]
		for o in m["objetos"]:
			if String(o.get("id", "")) == pieza:
				return o["c"]
	return Vector2i(r.position.x + 1, r.end.y - 2)


func _cofre_de_plantilla(m: Dictionary, sala: Dictionary, cid: String) -> Vector2i:
	var e: Dictionary = Catalogo.todos().get(cid, {})
	var hueco: Vector2i = e.get("cofre_salida", Vector2i(-1, -1))
	var res: String = String(e.get("resuelto", ""))
	if hueco.x < 0 or not sala.has("inst") or not res.contains("."):
		return Vector2i(-1, -1)
	var local_id: String = res.split(".")[0]
	var local: Vector2i = Vector2i(-1, -1)
	for l in e["lineas"]:
		var p: PackedStringArray = String(l).split(" ", false)
		if p.size() >= 5 and p[1] == "pieza" and p[2] == local_id:
			local = Vector2i(p[4].to_int(), p[5].to_int()) if p.size() >= 6 else Vector2i(-1, -1)
	var pieza: String = String(sala["inst"]) + "_" + local_id
	for l in m["lineas"]:
		var q: PackedStringArray = String(l).split(" ", false)
		if q.size() >= 6 and q[1] == "pieza" and q[2] == pieza and local.x >= 0:
			return Vector2i(q[4].to_int(), q[5].to_int()) - local + hueco
	return Vector2i(-1, -1)


# --- Inventario (para docs/NIVELES_BOSQUE_2026-11-26.md) ---

func _inventariar(cfg: Dictionary, m: Dictionary, asign: Dictionary, semilla: int) -> void:
	var cat: Dictionary = Catalogo.todos()
	var par: Dictionary = m["parametros"]
	var st: Dictionary = m["stats"]
	var salas: Dictionary = {}
	for s in m["salas"]:
		salas[int(s["id"])] = s
	var cuenta: Dictionary = {}
	for o in m["objetos"]:
		cuenta[String(o["tipo"])] = int(cuenta.get(String(o["tipo"]), 0)) + 1
	_inventario.append("## %s · %d × %d · semilla %d · %d claros · %d enemigos · %d cofres · %d jarrones" % [String(cfg["nombre"]), int(m["ancho"]), int(m["alto"]), semilla,
		(m["salas"] as Array).size(), int(st["enemigos"]), int(st["cofres"]), int(st["jarrones"])])
	var ids: Array = asign.keys()
	ids.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	for sid in ids:
		var e: Dictionary = cat[String(asign[sid])]
		var nec: String = Catalogo.necesita_dicho(e)
		_inventario.append("  claro %d (%s) · %s (`%s`) · %s · %s" % [int(sid), str(salas[sid]["rect"]), String(e["titulo"]), String(asign[sid]), nec if nec != "" else "empujar", String(e["validacion"])])
	for s in m["salas"]:
		_inventario.append("  sala %d rol=%s rect=%s dist=%s enemigos=%d" % [int(s["id"]), String(s["rol"]), str(s["rect"]), str(s.get("dist", -1)), int(s["enemigos"])])
	_inventario.append("  objetos: " + str(cuenta))
	_inventario.append("  avisos: " + str(m["avisos"]))
	if not (m["cabana"] as Dictionary).is_empty():
		_inventario.append("  cabaña: " + str(m["cabana"]))


# --- Comprobaciones al cargar la escena ---

func _comprobar_escena(cfg: Dictionary, m: Dictionary) -> void:
	var nombre: String = String(cfg["nombre"])
	var ruta: String = Exportador.ruta_escena(nombre)
	await cargar(ruta, false)
	if maqueta == null:
		return
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("%s: Puzle3D sin avisos" % nombre, pz != null and pz.avisos.is_empty(), str(pz.avisos.slice(0, 5)) if pz != null else "sin Puzle3D")
	var avisos_maqueta: Array = maqueta.get("_avisos") if maqueta.get("_avisos") != null else []
	_ok("%s: la maqueta no da avisos de piezas" % nombre, avisos_maqueta.is_empty(), str(avisos_maqueta.slice(0, 6)))
	if not (m["cabana"] as Dictionary).is_empty():
		var gc: Node = maqueta.get_node_or_null("GuardabosquesCabana")
		_ok("%s: el nodo de la guardabosques está" % nombre, gc != null)
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)
