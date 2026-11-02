class_name Partida
extends RefCounted

## UNA PARTIDA, UN ARCHIVO (F2 de docs/PLAN_BASE_DATOS.md, 29/10, Juego). Antes cada sistema guardaba lo suyo en su archivo suelto
## (`user://flags.json`, `user://misiones.json`) y el oro, la bolsa, la tinta o el sitio donde estabas no se guardaban. Ahora los
## puntos de guardado llaman a `Partida.guardar(ranura, extra)`, que pide a cada sistema su `a_dic()` y escribe `user://partidas/ranura_<n>.json`
## con las secciones del prototipo `nucleo/datos/partida_ejemplo.json` (meta, jugadora, tinta, bolsa, mejoras, grimorio, recetas_conocidas,
## estados, flags, mundo, misiones). `Partida.cargar(ranura)` hace lo contrario con `desde_dic()` y devuelve el diccionario para que el nivel
## coloque a la jugadora.
##
## QUIÉN APORTA QUÉ. Lo que vive en un singleton (Estado, Flags, Misiones, Repertoire) se pide solo. La Tinta y la jugadora viven en el nivel: la
## `Tinta` viva se registra en `Partida.tinta` (si no hay, se guarda una de partida nueva) y lo demás (mapa, entrada, posición, vida, ropa, punto)
## llega en `extra` desde `Jugabilidad3D`: `mapa_actual`, `entrada`, `posicion` (Vector3 o [x,y,z]), `vida`, `aguante`, `ropa_puesta`, `punto`,
## y, si el libro las da, `paginas`. F4: `extra["mundo"]` = {nivel: EstadoZona3D.a_dic()} se mezcla en la sección `mundo` (lo de otros niveles se conserva) y `aguante` se guarda de verdad.
## La `Tinta` registrada y las claves ausentes de `extra` usan valores por defecto.
##
## CUÁNDO SE GUARDA. Solo en los puntos de guardado (nunca al cambiar algo): una prueba que reinicia no hereda nada.
##
## CONTINUAR. `Partida.continuar = true` (lo pondrá el menú, que es del Pipeline) avisa al nivel de que cargue `ranura_actual` al arrancar. Es de UN
## SOLO USO: el nivel que carga la baja a false, para que viajar a otro nivel (que arranca otra escena) no vuelva a pisar el progreso con el archivo.
##
## ARCHIVO ROTO. Un JSON ilegible, que no sea un diccionario o de una versión que no se conoce: `push_warning`, devuelve `{}` y NO toca ningún
## singleton (la partida en curso sigue como estaba).
##
## MIGRACIÓN. Si la ranura no existe pero sí `flags.json` y/o `misiones.json` (el guardado de la versión 1), `cargar` los lee con `Flags.cargar` /
## `Misiones.cargar`, escribe la ranura en versión 2 y renombra los viejos a `.v1.bak` (no se borran). Pasa una sola vez.

##
## TERCERA TANDA GAMEFEEL (2/11, A1–A3). VERSIÓN 3: añade la sección `estadisticas` (`Estadisticas`) y `meta.guardado_unix` (para saber cuál de dos ranuras es más reciente). Un archivo v2 sigue
## cargando (sin sección = estadísticas a cero). AUTOGUARDADO: la ranura 0 («auto») la escribe `autoguardar` al cambiar de nivel (`Niveles`), al completar una misión (`vigilar_misiones`)
## y al salir al menú (`MenuPausa`); con el árbol en pausa se difiere (`diferido`) y lo hace `IconoGuardado` al despausar. Los puntos de guardado siguen escribiendo en la ranura 1.
## «Continuar» del menú principal carga la ranura más reciente (`ranura_mas_reciente`); `ranura_a_cargar` es de un solo uso como `continuar` y deja `ranura_actual` (donde escriben los puntos de guardado) intacta.

const VERSION: int = 3
const VERSIONES_LEIBLES: Array = [2, 3]
const RANURA_AUTO: int = 0
const PUNTO_VIAJE: String = "viaje"               ## `meta.punto` del autoguardado al cambiar de nivel
const RANURAS_MAX: int = 9                        ## las ranuras 0…9 se buscan para «Cargar»
const RUTA: String = "user://partidas/ranura_%d.json"       ## la ruta de siempre (con `carpeta` por defecto); ver `ruta()`
const CARPETA_DEFECTO: String = "user://partidas/"
const RUTA_FLAGS_V1: String = "user://flags.json"
const RUTA_MISIONES_V1: String = "user://misiones.json"
const SUFIJO_BAK: String = ".v1.bak"

static var ranura_actual: int = 1
static var continuar: bool = false
## Qué ranura lee el próximo «continuar» (-1 = `ranura_actual`). De un solo uso: lo baja a -1 quien carga.
static var ranura_a_cargar: int = -1
## A2: ¿se autoguarda en la ranura 0? Las pruebas lo apagan o lo encienden.
static var AUTOGUARDADO: bool = true
## En headless (pruebas y escenarios) NO se autoguarda salvo que esto sea true: así correr una prueba no pisa la ranura «auto» de nadie.
static var AUTOGUARDADO_EN_HEADLESS: bool = false
## Un autoguardado que se pidió con el árbol en pausa y espera a que se despause.
static var diferido: bool = false
static var ultimo_motivo_auto: String = ""         ## «nivel», «mision», «menu»: lo último que autoguardó (las pruebas)
static var autoguardados: int = 0                  ## cuántos se han hecho en esta sesión (las pruebas)
## Dónde se guardan las ranuras y dónde están los archivos de la versión 1. Las pruebas los apuntan a una carpeta suya.
static var carpeta: String = CARPETA_DEFECTO
static var ruta_flags_v1: String = RUTA_FLAGS_V1
static var ruta_misiones_v1: String = RUTA_MISIONES_V1
## La tinta viva de la jugadora (la registra el nivel). Null = se guarda/carga solo lo que hay en `Estado` (los frascos).
static var tinta: Tinta = null
## Lo que dijo la sección `tinta` del último `cargar` si aún no había una `Tinta` viva: el nivel la aplica cuando tenga la suya (`tinta.desde_dic`).
static var tinta_pendiente: Dictionary = {}
## Las recetas descubiertas (ids). Las rellenará la Síntesis (F3); de momento se guarda lo que haya.
static var recetas_conocidas: Array = []
## Estados de zona por mapa: {nivel: EstadoZona3D.a_dic()} (tormenta, vendaval y nubes de veneno vivas). Lo rellena el nivel con `extra["mundo"]` al guardar; al cargar queda aquí para que el nivel lo aplique.
static var mundo: Dictionary = {}

static var _segundos_base: float = 0.0           ## lo jugado según el último archivo cargado/guardado
static var _t0_ms: int = 0                       ## ticks (ms) en los que empezó a contar `_segundos_base`


static func ruta(ranura: int) -> String:
	return carpeta.path_join("ranura_%d.json" % ranura)


static func existe(ranura: int) -> bool:
	return FileAccess.file_exists(ruta(ranura))


static func borrar(ranura: int) -> bool:
	if not existe(ranura):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta(ranura))) == OK


## Los segundos jugados hasta ahora (los del archivo cargado más lo que va desde entonces).
static func segundos_jugados() -> float:
	return _segundos_base + float(Time.get_ticks_msec() - _t0_ms) / 1000.0


## Reúne todo y escribe la ranura. Devuelve true si quedó escrita. Se escribe a un archivo temporal y se renombra: un corte a medias no deja la
## ranura rota.
static func guardar(ranura: int = -1, extra: Dictionary = {}) -> bool:
	var r: int = ranura if ranura >= 0 else ranura_actual
	var dic: Dictionary = reunir(r, extra)
	var dir_abs: String = ProjectSettings.globalize_path(carpeta)
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)
	var destino: String = ruta(r)
	var tmp: String = destino + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		push_warning("Partida.guardar: no se pudo abrir %s" % tmp)
		return false
	fa.store_string(JSON.stringify(dic, "  "))
	fa.close()
	var destino_abs: String = ProjectSettings.globalize_path(destino)
	if FileAccess.file_exists(destino):
		DirAccess.remove_absolute(destino_abs)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), destino_abs) != OK:
		push_warning("Partida.guardar: no se pudo renombrar %s" % tmp)
		return false
	_segundos_base = float(dic["meta"]["segundos_jugados"])
	_t0_ms = Time.get_ticks_msec()
	mundo = (dic["mundo"] as Dictionary).duplicate(true)       # lo guardado ya es lo vigente (el siguiente guardado de otro nivel no lo pierde)
	return true


## El diccionario completo de la partida (lo que `guardar` escribe), sin tocar el disco. Lo usan las pruebas.
static func reunir(ranura: int, extra: Dictionary = {}) -> Dictionary:
	var est: Dictionary = Estado.i().a_dic()
	if extra.has("paginas"):
		Repertoire.paginas = (extra["paginas"] as Array).duplicate(true)
	var t: Tinta = tinta if tinta != null else Tinta.new()
	var fl: Dictionary = Flags.i().a_dic()
	var mis: Dictionary = Misiones.i().a_dic()
	mis.erase("version")                           # la versión es la de la raíz del archivo
	return {
		"version": VERSION,
		"meta": {
			"ranura": ranura,
			"guardado_en": Time.get_datetime_string_from_system(),
			"guardado_unix": Time.get_unix_time_from_system(),
			"segundos_jugados": int(segundos_jugados()),
			"punto": String(extra.get("punto", "")),
			"hora_dia": float(extra.get("hora_dia", CicloDia3D.HORA)),      # C1 (2/11): la hora del ciclo de día (0-24) viaja con la partida
		},
		"jugadora": {
			"mapa_actual": String(extra.get("mapa_actual", "")),
			"entrada": String(extra.get("entrada", "")),
			"posicion": _posicion(extra.get("posicion", [0.0, 0.0, 0.0])),
			"vida": float(extra.get("vida", Estado.VIDA_BASE)),
			"aguante": float(extra.get("aguante", 100.0)),       # F4: el aguante de Jugador3D (0–100)
			"ropa_puesta": _cadenas(extra.get("ropa_puesta", [])),
			"consumible_equipado": est["consumible_equipado"],
			"opciones": est["opciones"],
		},
		"tinta": t.a_dic(),
		"bolsa": est["bolsa"],
		"mejoras": est["mejoras"],
		"grimorio": Repertoire.a_dic(),
		"recetas_conocidas": _cadenas(recetas_conocidas),
		"estados": fl["estados"],
		"flags": fl["flags"],
		"mundo": _mundo_a_guardar(extra),
		"misiones": mis,
		"estadisticas": Estadisticas.a_dic(),
	}


## F4: la sección `mundo` = lo que ya había (otros niveles) con lo que aporta el nivel de ahora en `extra["mundo"]` ({nivel: dic}) encima.
static func _mundo_a_guardar(extra: Dictionary) -> Dictionary:
	var m: Dictionary = mundo.duplicate(true)
	var nuevo: Variant = extra.get("mundo", {})
	if nuevo is Dictionary:
		for k in (nuevo as Dictionary).keys():
			m[String(k)] = (nuevo as Dictionary)[k]
	return m


## Lee la ranura y reparte cada sección en su sistema (Estado → Tinta → Repertoire → Flags → Misiones). Devuelve el diccionario leído (de ahí
## salen mapa, entrada, posición, vida y ropa para colocar a la jugadora) o `{}` si no hay partida o está rota (los singletons quedan intactos).
## Hay que llamarlo ANTES de que el nivel defina sus misiones (`Misiones.definir` conserva el progreso de las que vinieron del guardado).
static func cargar(ranura: int = -1) -> Dictionary:
	var r: int = ranura if ranura >= 0 else ranura_actual
	if not existe(r) and not _migrar(r):
		return {}
	var d: Dictionary = leer(r)
	if d.is_empty():
		return {}
	var est: Dictionary = {
		"bolsa": d.get("bolsa", {}), "mejoras": d.get("mejoras", {}),
		"consumible_equipado": (d.get("jugadora", {}) as Dictionary).get("consumible_equipado", "") if d.get("jugadora", {}) is Dictionary else "",
		"opciones": (d.get("jugadora", {}) as Dictionary).get("opciones", {}) if d.get("jugadora", {}) is Dictionary else {},
	}
	Estado.i().desde_dic(est)                      # primero: la barra de tinta máxima sale de las mejoras
	var td: Dictionary = _dic(d.get("tinta", {}))
	tinta_pendiente = td
	if tinta != null:
		tinta.desde_dic(td)
		tinta_pendiente = {}
	else:
		Estado.i().frascos_tinta = clampi(int(td.get("frascos", Tinta.FRASCOS_INICIALES)), 0, Tinta.frascos_max())
	Repertoire.desde_dic(_dic(d.get("grimorio", {})))
	recetas_conocidas = _cadenas(d.get("recetas_conocidas", []))
	Flags.i().desde_dic({"estados": _dic(d.get("estados", {})), "flags": _dic(d.get("flags", {}))})
	Misiones.i().desde_dic(_dic(d.get("misiones", {})))
	Estadisticas.desde_dic(d.get("estadisticas", {}))      # A3: un archivo v2 no la trae = ceros
	mundo = _dic(d.get("mundo", {})).duplicate(true)
	var hora: Variant = _dic(d.get("meta", {})).get("hora_dia")           # un archivo de antes de C1 no la trae: la hora se queda como esté
	if hora != null:
		CicloDia3D.HORA = fposmod(float(hora), 24.0)
	_segundos_base = float(_dic(d.get("meta", {})).get("segundos_jugados", 0.0))
	_t0_ms = Time.get_ticks_msec()
	return d


## Lee y valida el archivo SIN repartir nada. `{}` si falta, está roto o es de una versión desconocida (avisa).
static func leer(ranura: int) -> Dictionary:
	var p: String = ruta(ranura)
	if not FileAccess.file_exists(p):
		return {}
	var fa := FileAccess.open(p, FileAccess.READ)
	if fa == null:
		push_warning("Partida.leer: no se pudo abrir %s" % p)
		return {}
	var txt: String = fa.get_as_text()
	fa.close()
	var json := JSON.new()                          # parse() no escribe errores en consola (parse_string sí): el aviso lo damos nosotros
	var d: Variant = json.data if json.parse(txt) == OK else null
	if not (d is Dictionary):
		push_warning("Partida.leer: %s no es una partida válida (JSON roto)" % p)
		return {}
	if not VERSIONES_LEIBLES.has(int((d as Dictionary).get("version", -1))):
		push_warning("Partida.leer: %s es de la versión %s y solo se conoce la %d (y la 2)" % [p, str((d as Dictionary).get("version", "?")), VERSION])
		return {}
	return d


## Versión 1 → 2: dos archivos sueltos (flags y misiones) pasan a la ranura. Devuelve true si escribió la ranura.
static func _migrar(ranura: int) -> bool:
	var f1: bool = FileAccess.file_exists(ruta_flags_v1)
	var m1: bool = FileAccess.file_exists(ruta_misiones_v1)
	if not f1 and not m1:
		return false
	var leidos: Array = []
	if f1 and Flags.i().cargar(ruta_flags_v1):
		leidos.append(ruta_flags_v1)
	if m1 and Misiones.i().cargar(ruta_misiones_v1):
		leidos.append(ruta_misiones_v1)
	if leidos.is_empty():
		return false
	if not guardar(ranura, {"punto": ""}):
		return false
	for v in leidos:
		var bak: String = String(v) + SUFIJO_BAK
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(v), ProjectSettings.globalize_path(bak))
	return true


static func _dic(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _cadenas(v: Variant) -> Array:
	var r: Array = []
	if v is Array or v is PackedStringArray:
		for x in v:
			r.append(String(x))
	return r


static func _posicion(v: Variant) -> Array:
	if v is Vector3:
		return [(v as Vector3).x, (v as Vector3).y, (v as Vector3).z]
	if v is Array and (v as Array).size() >= 3:
		return [float(v[0]), float(v[1]), float(v[2])]
	return [0.0, 0.0, 0.0]


# ---------------------------------------------------------------------------------------------------------------------
#  Tercera tanda (2/11): menú principal, autoguardado y continuar para todos los niveles
# ---------------------------------------------------------------------------------------------------------------------

## Qué hay guardado: [{ranura, mapa, segundos, guardado_en, punto}] de las ranuras 0…RANURAS_MAX que existen y se leen, la «auto» (0) la primera.
static func resumen_ranuras() -> Array:
	var r: Array = []
	for n in range(RANURAS_MAX + 1):
		if not existe(n):
			continue
		var d: Dictionary = leer(n)
		if d.is_empty():
			continue
		var meta: Dictionary = _dic(d.get("meta", {}))
		r.append({"ranura": n, "mapa": String(_dic(d.get("jugadora", {})).get("mapa_actual", "")), "segundos": int(meta.get("segundos_jugados", 0)),
			"guardado_en": String(meta.get("guardado_en", "")), "punto": String(meta.get("punto", ""))})
	return r


## ¿Cuándo se guardó? (segundos unix; los archivos sin `guardado_unix` caen a 0).
static func _cuando(d: Dictionary) -> float:
	return float(_dic(d.get("meta", {})).get("guardado_unix", 0.0))


## La ranura legible más reciente de la 1 (manual) y la 0 (auto) por `meta.guardado_unix`; empate = la 1. -1 si no hay ninguna.
static func ranura_mas_reciente() -> int:
	var d1: Dictionary = leer(1) if existe(1) else {}
	var d0: Dictionary = leer(RANURA_AUTO) if existe(RANURA_AUTO) else {}
	if d1.is_empty() and d0.is_empty():
		return -1
	if d0.is_empty():
		return 1
	if d1.is_empty():
		return RANURA_AUTO
	return RANURA_AUTO if _cuando(d0) > _cuando(d1) else 1


## Pone a cero los sistemas que viven en singletons (oro, mochila, flags, misiones, glifos, estadísticas): una partida nueva empieza limpia aunque se llegue desde otra (Salir al menú).
static func nueva() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Repertoire.reset_to_p0()
	Repertoire.paginas = []
	mundo = {}
	recetas_conocidas = []
	tinta = null
	tinta_pendiente = {}
	_segundos_base = 0.0
	_t0_ms = Time.get_ticks_msec()
	Estadisticas.reiniciar()
	continuar = false
	ranura_a_cargar = -1
	diferido = false


## Prepara «Continuar»/«Cargar»: el próximo nivel que arranque carga la ranura `n` (los puntos de guardado siguen escribiendo en `ranura_actual`).
static func preparar_carga(n: int) -> void:
	continuar = true
	ranura_a_cargar = n


## El `extra` de `guardar` para un nivel en marcha: dónde está la jugadora, su vida, su ropa y los estados de zona. `c` = la casilla del punto de guardado.
static func extra_de(mundo_nivel: Node, jug: Node, c: Vector2i) -> Dictionary:
	var pj_mundo: Node3D = mundo_nivel.get("_jugador") as Node3D
	var pos: Vector3 = pj_mundo.position if pj_mundo != null else Vector3.ZERO
	var cercana: String = ""
	var mejor: float = INF
	for e in mundo_nivel.get_tree().get_nodes_in_group("entrada_nivel"):
		if is_instance_valid(e):
			var dd: float = (e as Node3D).position.distance_squared_to(pos)
			if dd < mejor:
				mejor = dd
				cercana = String(e.get("nombre"))
	var nivel: String = String(mundo_nivel.get("nivel"))
	var extra: Dictionary = {"mapa_actual": nivel, "entrada": cercana, "posicion": pos, "punto": "%s.%d_%d" % [nivel, c.x, c.y]}
	if jug != null:
		extra["vida"] = jug.get("vida")
		extra["aguante"] = jug.get("aguante")
		var pj: Variant = jug.get("pj")
		if pj != null:
			extra["ropa_puesta"] = (pj as Object).call("ropa_puesta")
	var ez: EstadoZona3D = EstadoZona3D.actual
	var del_nivel: Dictionary = {}
	if ez != null and is_instance_valid(ez):
		del_nivel = ez.a_dic()
	del_nivel["suelo"] = Terreno3D.estados.a_dic()            # C1 (2/11): mojado, escarcha, quemado, segado y electrificado del suelo, con lo que les queda
	extra["mundo"] = {nivel: del_nivel}
	return extra


## Si `continuar` está puesto, carga la ranura (`ranura_a_cargar` o `ranura_actual`) y coloca a la jugadora: misma vida, aguante, ropa y estados de zona; en su sitio si es el mismo nivel
## o en la entrada que diga el archivo. Es de un solo uso. Devuelve true si cargó algo. ANTES de que el nivel defina sus misiones (`Misiones.definir` conserva el progreso cargado).
static func aplicar_continuar(mundo_nivel: Node, jug: Node) -> bool:
	if not continuar:
		return false
	continuar = false
	var r: int = ranura_a_cargar if ranura_a_cargar >= 0 else ranura_actual
	ranura_a_cargar = -1
	var d: Dictionary = cargar(r)
	if d.is_empty() or jug == null:
		return false
	var j: Dictionary = _dic(d.get("jugadora", {}))
	var vmax: float = Estado.i().vida_max
	jug.set("vida", clampf(float(j.get("vida", vmax)), 1.0, vmax))
	jug.emit_signal("vida_cambiada", float(jug.get("vida")), vmax)
	jug.set("aguante", clampf(float(j.get("aguante", 100.0)), 0.0, 100.0))
	var nivel: String = String(mundo_nivel.get("nivel"))
	var mundo_n: Variant = _dic(d.get("mundo", {})).get(nivel, {})
	if mundo_n is Dictionary and EstadoZona3D.actual != null and is_instance_valid(EstadoZona3D.actual):
		EstadoZona3D.actual.desde_dic(mundo_n as Dictionary)
	if mundo_n is Dictionary and (mundo_n as Dictionary).has("suelo"):
		Terreno3D.estados.desde_dic(_dic((mundo_n as Dictionary)["suelo"]))      # C1 (2/11): el suelo vuelve como se guardó (un archivo anterior no trae la clave = el suelo del nivel recién montado)
	var pj: Variant = jug.get("pj")
	if pj != null:
		for id in j.get("ropa_puesta", []):
			(pj as Object).call("poner_ropa", String(id))
	var pos: Array = j.get("posicion", []) as Array
	var por_entrada: bool = String(_dic(d.get("meta", {})).get("punto", "")) == PUNTO_VIAJE        # el autoguardado de un viaje apunta a la ENTRADA del nivel nuevo, no a la salida del viejo
	if String(j.get("mapa_actual", "")) == nivel and pos.size() >= 3 and not por_entrada:
		var p := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		mundo_nivel.call("ir_a", mundo_nivel.call("_celda_de", p))
		(mundo_nivel.get("_jugador") as Node3D).position = p
		(jug as Node3D).position = p
		jug.set("puntos_inicio", p)
	else:
		for e in mundo_nivel.get_tree().get_nodes_in_group("entrada_nivel"):
			if is_instance_valid(e) and String(e.get("nombre")) == String(j.get("entrada", "")):
				Niveles.colocar(mundo_nivel, e)
				break
	return true


## Guarda en la ranura 0 («auto») lo del nivel que está en el árbol. false si no se hizo: apagado, headless sin permiso, sin nivel ni jugadora, jugadora caída o árbol en pausa (entonces
## queda `diferido` y lo repite `IconoGuardado` al despausar). Si guarda, el icono del HUD aparece.
static func autoguardar(arbol: SceneTree, motivo: String = "", sobrescribir: Dictionary = {}) -> bool:
	if not AUTOGUARDADO or arbol == null:
		return false
	if DisplayServer.get_name() == "headless" and not AUTOGUARDADO_EN_HEADLESS:
		return false
	if arbol.paused:
		diferido = true
		ultimo_motivo_auto = motivo
		return false
	var lanz: Node = arbol.get_first_node_in_group("spellcaster")
	if lanz == null:
		return false
	var jug: Node = lanz.get("jugador") as Node
	var nivel: Node = lanz.get("mundo") as Node
	if jug == null or nivel == null or not is_instance_valid(jug) or not is_instance_valid(nivel) or bool(jug.get("muerto")):
		return false
	var pj_mundo: Node3D = nivel.get("_jugador") as Node3D
	var c: Vector2i = nivel.call("_celda_de", pj_mundo.position) if pj_mundo != null else Vector2i.ZERO
	var extra: Dictionary = extra_de(nivel, jug, c)
	extra["punto"] = "auto"
	extra.merge(sobrescribir, true)
	diferido = false
	if not guardar(RANURA_AUTO, extra):
		return false
	autoguardados += 1
	ultimo_motivo_auto = motivo
	arbol.call_group("icono_guardado", "mostrar")
	return true


## Autoguardar al completar una misión. Se engancha a la instancia de `Misiones` de ahora (por eso se llama en cada `Jugador3D.montar`).
static func vigilar_misiones() -> void:
	var m: Misiones = Misiones.i()
	if not m.mision_completada.is_connected(_al_completar_mision):
		m.mision_completada.connect(_al_completar_mision)


static func _al_completar_mision(_id: String) -> void:
	autoguardar(Engine.get_main_loop() as SceneTree, "mision")
