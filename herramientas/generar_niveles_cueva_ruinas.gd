extends "res://herramientas/escenario_base.gd"
## LOS NIVELES DE REVISIÓN DE ASSETS DE LAS RUINAS Y LA CUEVA (27/11/2026). Pablo: «quiero que montes niveles de prueba para la cueva y las ruinas; la idea es revisar que todos los assets se
## corresponden con el proyecto. Diseña puzles para ellos: ruinas con assets tipo pulsadores / trampas, y cueva con puzles para agua y tierra».
## Es el hermano de `generar_niveles_bosque.gd` (la misma idea: una tabla de parámetros y semillas fijos, reproducible), con tres diferencias:
##   · el algoritmo es «pagina» (ruinas, y el nivel de Lost Cave) o «salas» (CuevaPrueba), con estilo «ruinas» (muros finos del pack Stylescape: Ruins) o «cueva» (paredes del kit propio, o del pack Stylized Lost Cave).
##     Ojo con el TAMAÑO: los mapas «ruinas» grandes consumen muchísima memoria al cargar (8-9 GB de pico a 76 × 66, más de 20 GB a 118 × 109), por eso las ruinas son dos niveles pequeños;
##   · hay SALAS MUESTRARIO: plantillas `muestrario_*` del catálogo (con `; solo_mano si`) que reparten TODAS las piezas del pack en filas por categoría, con su id en un rótulo legible
##     (objetos/muestrario_piezas_3d.gd), en salas que talla el generador aparte (parámetro `salas_grandes`). Sirven para decir «esta sí / esta no» por id (docs/REVISION_ASSETS_CUEVA_RUINAS_2026-11-27.md);
##   · hay enemigos del bioma: goblins en las ruinas; limos y un gólem (pieza `; pieza … limo|golem`) en la cueva.
## Busca la primera semilla en la que cabe todo (sin errores ni avisos que no estén permitidos en `avisos_ok`), exporta mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn (con el exportador del botón
## «Exportar»), carga cada escena y comprueba lo básico. Imprime el inventario de cada nivel para el documento.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/generar_niveles_cueva_ruinas.gd [-- nivel=CuevaPrueba] [-- sin_cargar] [-- buscar]
##   · `nivel=<Nombre>`: solo ese nivel.  · `sin_cargar`: solo genera y exporta (no monta las escenas).  · `buscar`: ignora `semilla` fija y vuelve a buscar desde `semilla_ini`.
## Regenerar pisa los retoques a mano del .txt (el exportador guarda antes una copia `<Nombre>_copia_<fecha>.txt`). Lo comprueba `prueba_niveles_cueva_ruinas.gd`.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const SEMILLAS_MAX: int = 80            ## cuántas semillas se prueban, a partir de `semilla_ini`, antes de rendirse
const SALAS_MUESTRARIO: int = 10        ## un muestrario solo se prueba en las N salas libres más grandes (cada intento regenera el mapa entero: unos segundos)

## Avisos del generador que se aceptan en estos niveles: con el algoritmo «pagina» salen pasillos de 1 × 5 que cuentan como «sala» y la cámara de salas dice que no los encuadra del todo (se ve un poco de fuera en un pasillo).
const AVISOS_CAMARA: Array = ["la cámara tendrá que acercarse al máximo"]

## Lo común a los tres (se pisa con los `params` de cada nivel).
const BASE: Dictionary = {
	"algoritmo": "salas", "luz": "cueva", "paredes": "kit", "decorado": true, "terreno": true, "acabado": true, "camara_sala": true,
	"rotulo": true, "rotulos_claros": true, "ancho_pasillo": 2, "solo_aceptados": false, "runas": "", "kit": "demo",
	"braseros": 1.0, "jarrones": 1.0, "charcas": 0, "salas_cerradas": 0, "llave": false, "sala_jefe": "no", "puzles": 0, "barreras": 0, "tesoro": true,
}

## NIVELES. `muestrarios` y `puzles` = ids del catálogo (los muestrarios se colocan primero, en las salas libres más grandes; los puzles, en orden de cercanía a la entrada).
## `enemigos_extra` = [tipo, …] de `Generador.ENEMIGOS`: se añaden uno por sala libre que sobre, lo más lejos de la entrada primero.
const NIVELES: Array = [
	{
		"nombre": "RuinasPrueba", "semilla_ini": 1, "semilla": 5,           # semilla fija (la primera que cumple todo); 0 = buscar desde semilla_ini
		"descripcion": "Ruinas COMPLETAS: entrada, recorrido, 6 puzles nuevos de pulsadores y trampas + 2 de los que ya había (dragon_brasero, escudo_flechas), goblins, cofre y sala final del tesoro, con el suelo de losas rotas y el vestido de piedra (`ruinas_completas`). Las salas muestrario están en RuinasPruebaMuestrario.",
		# 27/11 (Pablo: «para las ruinas también pon el suelo; quiero el ejemplo de un nivel completo de bioma ruinas»): `ruinas_completas` = el suelo de losas rotas y el vestido de piedra
		# (pilares, arcos en las puertas, escombros: presentacion/ruinas_completas_3d.gd). Mismo tamaño y semilla que antes: el plano no cambia, solo la escena exportada.
		"params": {"estilo": "ruinas", "luz": "ruinas", "titulo_nivel": "Ruinas de prueba (puzles)", "algoritmo": "pagina", "ancho": 76, "alto": 66, "n_salas": 13, "lado_min": 11, "lado_max": 14,
			"simetria": false, "pasillos": 30, "bucles": 25, "enemigos": 0.0, "arqueros": 0, "ruinas_completas": true},
		"muestrarios": [],
		"puzles": ["mascarones_relevo", "dragon_brasero", "placa_y_boton", "totem_a_favor", "dos_placas_cofre", "dragon_muro_brasero", "dragon_agua_reja", "escudo_flechas"],
		"enemigos_extra": ["guerrero", "arquero"], "avisos_ok": AVISOS_CAMARA,
	},
	{
		"nombre": "RuinasPruebaMuestrario", "semilla_ini": 1, "semilla": 2,
		"descripcion": "Las dos salas muestrario con TODAS las piezas del pack Stylescape: Ruins (198), en filas por categoría y con su id en un rótulo, más una sala de entrada.",
		"params": {"estilo": "ruinas", "luz": "ruinas", "titulo_nivel": "Ruinas de prueba (muestrario de piezas)", "algoritmo": "pagina", "ancho": 80, "alto": 44, "n_salas": 2, "lado_min": 9, "lado_max": 10,
			"simetria": false, "pasillos": 20, "bucles": 10, "enemigos": 0.0, "arqueros": 0, "tesoro": false, "salas_grandes": "32x23;32x22"},
		"muestrarios": ["muestrario_ruinas_resto", "muestrario_ruinas_muros"],       # de la más grande a la más pequeña (cada una cabe justa en una de las `salas_grandes`)
		"puzles": [],
		"enemigos_extra": [], "avisos_ok": AVISOS_CAMARA,
	},
	{
		"nombre": "CuevaPrueba", "semilla_ini": 1, "semilla": 2,
		"descripcion": "Cueva con las paredes del KIT PROPIO: 5 puzles nuevos de agua y tierra + 2 de los que ya había + una sala muestrario con el kit propio + limos y un gólem.",
		"params": {"estilo": "cueva", "luz": "cueva", "paredes": "kit", "titulo_nivel": "Cueva de prueba (revisión de assets)", "ancho": 120, "alto": 100, "sala_min": 3, "sala_max": 5, "densidad_salas": 0.3, "salas_grandes": "28x13",
			"enemigos": 0.0, "arqueros": 0},
		"muestrarios": ["muestrario_cueva_kit"],
		"puzles": ["desvia_arroyo", "muro_cauce_balsa", "retener_cuenca", "fuga_reja_reloj", "dique_pozo_placa", "columna_puente_lava", "lava_roca_peso"],
		"enemigos_extra": ["limo", "limo_agua", "golem"], "avisos_ok": AVISOS_CAMARA,
	},
	{
		"nombre": "CuevaPruebaLostCave", "semilla_ini": 1, "semilla": 37,
		"descripcion": "El hermano de CuevaPrueba con las paredes del pack Stylized Lost Cave (`paredes_cueva = lostcave`) y tres salas muestrario con las 207 piezas lost_* (sin puzles: las paredes y las piezas de Lost Cave son lo que se revisa; los puzles de la cueva están en CuevaPrueba y en LostCave).",
		"params": {"estilo": "cueva", "luz": "cueva", "paredes": "lostcave", "titulo_nivel": "Cueva de prueba con Lost Cave (revisión de assets)", "algoritmo": "pagina", "ancho": 100, "alto": 62, "n_salas": 3, "lado_min": 10, "lado_max": 12, "simetria": false, "pasillos": 20, "bucles": 10, "salas_grandes": "44x25;36x17;36x15", "tesoro": false,
			"enemigos": 0.0, "arqueros": 0},
		"muestrarios": ["muestrario_lc_estructura", "muestrario_lc_vida", "muestrario_lc_mina"],
		"puzles": [],
		"enemigos_extra": [], "avisos_ok": AVISOS_CAMARA,
	},
]

var _solo: String = ""
var _cargar: bool = true
var _buscar: bool = false
var _inventario: Array = []


## Progreso por la salida de errores (la estándar no se vacía hasta el final al redirigirla a un archivo: la búsqueda de semilla tarda minutos).
func _prog(texto: String) -> void:
	printerr(texto)


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
		_prog("%s: probando la semilla %d" % [nombre, int(s)])
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


## Genera con esos parámetros y pone los muestrarios y los puzles de `cfg` en salas libres. Devuelve [sala → puzle, mapa] o [].
func _colocar(par: Dictionary, cfg: Dictionary, motivos: PackedStringArray) -> Array:
	var sem: int = int(par["semilla"])
	var base: Dictionary = Generador.new().generar(par)
	if not (base["errores"] as Array).is_empty():
		motivos.append("sem %d: errores %s" % [sem, str(base["errores"])])
		return []
	var libres: Array = (base["salas"] as Array).filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
	var n_pedidos: int = (cfg["puzles"] as Array).size()          # los muestrarios van a salas grandes aparte
	if libres.size() < n_pedidos + (cfg["enemigos_extra"] as Array).size() + 1:
		motivos.append("sem %d: solo %d salas libres para %d plantillas y %d enemigos" % [sem, libres.size(), n_pedidos, (cfg["enemigos_extra"] as Array).size()])
		return []
	var asign: Dictionary = {}
	# 1 · Los muestrarios, en las salas grandes que talla el generador aparte (`salas_grandes`), de más grande a más pequeña.
	var grandes: Array = (base["salas"] as Array).filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "grande")
	if grandes.size() < (cfg["muestrarios"] as Array).size():
		motivos.append("sem %d: solo se talló %d sala grande de %d (avisos %s)" % [sem, grandes.size(), (cfg["muestrarios"] as Array).size(), str(base["avisos"])])
		return []
	grandes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["rect"] as Rect2i).get_area() > (b["rect"] as Rect2i).get_area())
	for cid in cfg["muestrarios"]:
		if not _poner(par, grandes.slice(0, SALAS_MUESTRARIO), asign, String(cid), sem, motivos):
			return []
	# 2 · Los puzles, de la entrada hacia fuera.
	var cerca: Array = libres.duplicate()
	cerca.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))
	for cid in cfg["puzles"]:
		if not _poner(par, cerca, asign, String(cid), sem, motivos):
			return []
	# 3 · Enemigos del bioma que no son goblins (limos, gólem…): uno por sala libre que sobre, la más lejana primero.
	var anadidos: Array = []
	var m0: Dictionary = Generador.new().generar(par, {}, {}, asign)
	var salas: Dictionary = {}
	for s in m0["salas"]:
		salas[int(s["id"])] = s
	var sobran: Array = cerca.filter(func(s: Dictionary) -> bool: return not asign.has(int(s["id"])))
	sobran.reverse()
	var k: int = 0
	for tipo in cfg["enemigos_extra"]:
		if k >= sobran.size():
			motivos.append("sem %d: no sobra sala para el enemigo %s" % [sem, str(tipo)])
			return []
		var r: Rect2i = salas[int(sobran[k]["id"])]["rect"]
		anadidos.append({"que": "enemigo", "tipo": String(tipo), "c": r.position + r.size / 2})
		k += 1
	var m2: Dictionary = Generador.new().generar(par, {}, {}, asign, {}, anadidos, [])
	for sid in asign:
		if String((m2["puzles"] as Dictionary).get(sid, "")) != String(asign[sid]):
			motivos.append("sem %d: el puzle de la sala %d cambió al añadir los enemigos" % [sem, int(sid)])
			return []
	if (m2["anadidos"] as Array).size() != anadidos.size() or not (m2["errores"] as Array).is_empty():
		motivos.append("sem %d: los enemigos añadidos no caben (%s)" % [sem, str(m2["errores"])])
		return []
	var avisos_malos: Array = []
	for av in m2["avisos"]:
		var vale: bool = false
		for ok in cfg["avisos_ok"]:
			vale = vale or String(av).contains(String(ok))
		if not vale:
			avisos_malos.append(String(av))
	if not avisos_malos.is_empty():
		motivos.append("sem %d: avisos %s" % [sem, str(avisos_malos.slice(0, 2))])
		return []
	return [asign, m2]


## Pone `cid` en la primera sala de `orden` (que no tenga ya algo) donde el generador lo acepta. false si en ninguna.
func _poner(par: Dictionary, orden: Array, asign: Dictionary, cid: String, sem: int, motivos: PackedStringArray) -> bool:
	for s in orden:
		var sid: int = int(s["id"])
		if asign.has(sid):
			continue
		var prueba: Dictionary = asign.duplicate()
		prueba[sid] = cid
		var m: Dictionary = Generador.new().generar(par, {}, {}, prueba)
		var todos: bool = (m["errores"] as Array).is_empty()
		for kk in prueba:
			todos = todos and String((m["puzles"] as Dictionary).get(kk, "")) == String(prueba[kk])
		if todos:
			asign[sid] = cid
			_prog("  sem %d: %s en la sala %d" % [sem, cid, sid])
			return true
	motivos.append("sem %d: no cabe %s" % [sem, cid])
	_prog("  sem %d: NO cabe %s" % [sem, cid])
	return false


# --- Inventario (para los documentos) ---

func _inventariar(cfg: Dictionary, m: Dictionary, asign: Dictionary, semilla: int) -> void:
	var cat: Dictionary = Catalogo.todos()
	var st: Dictionary = m["stats"]
	var salas: Dictionary = {}
	for s in m["salas"]:
		salas[int(s["id"])] = s
	var cuenta: Dictionary = {}
	for o in m["objetos"]:
		cuenta[String(o["tipo"])] = int(cuenta.get(String(o["tipo"]), 0)) + 1
	_inventario.append("## %s · %d × %d · semilla %d · %d salas · %d enemigos · %d cofres · %d jarrones" % [String(cfg["nombre"]), int(m["ancho"]), int(m["alto"]), semilla,
		(m["salas"] as Array).size(), int(st["enemigos"]), int(st["cofres"]), int(st["jarrones"])])
	var ids: Array = asign.keys()
	ids.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	for sid in ids:
		var e: Dictionary = cat[String(asign[sid])]
		var nec: String = Catalogo.necesita_dicho(e)
		_inventario.append("  sala %d (%s) · %s (`%s`) · %s · %s" % [int(sid), str(salas[sid]["rect"]), String(e["titulo"]), String(asign[sid]), nec if nec != "" else "empujar/andar", String(e["validacion"])])
	for s in m["salas"]:
		_inventario.append("  sala %d rol=%s rect=%s dist=%s enemigos=%d" % [int(s["id"]), String(s["rol"]), str(s["rect"]), str(s.get("dist", -1)), int(s["enemigos"])])
	_inventario.append("  objetos: " + str(cuenta))
	_inventario.append("  avisos: " + str(m["avisos"]))


# --- Comprobaciones al cargar la escena ---

func _comprobar_escena(cfg: Dictionary, m: Dictionary) -> void:
	var nombre: String = String(cfg["nombre"])
	var ruta: String = Exportador.ruta_escena(nombre)
	await cargar(ruta, false)
	if maqueta == null:
		return
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("%s: Puzle3D sin avisos" % nombre, pz != null and pz.avisos.is_empty(), str(pz.avisos.slice(0, 5)) if pz != null else "sin Puzle3D")
	maqueta.get_parent().remove_child(maqueta)
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)
