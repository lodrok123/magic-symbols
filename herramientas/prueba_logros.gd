extends SceneTree
## RESPUESTA POSITIVA AL JUGADOR (PLAN_EOW_VISUAL §4, 21/10, Juego). Sin ventana, con un Puzle3D y un mundo falso (el de prueba_sala_cerrada):
##   godot --headless [--fixed-fps 30] --path . --script res://herramientas/prueba_logros.gd
##   1. Contrato: `Mundo3D.LOGROS` y `Logros3D.TABLA` tienen los mismos nombres (UNA fila por logro), cada fila usa campos y sonidos que existen, «paso_puzle» es suave
##      (sin texto ni hitstop) y «sala_limpia» lleva hitstop de 60–100 ms. `avisar_logro` sin Mundo3D no hace nada y un nombre inventado no se emite.
##   2. Cada suceso emite su logro UNA vez, en su orden: contador (2 pasos y puzle_resuelto, aunque su regla abra la puerta: sin duplicar), pulsador → puerta (puzle_resuelto),
##      sala cerrada (sala_limpia → puerta_abierta → cofre_aparece) y cofre_abierto. Abrir de nuevo lo que ya estaba abierto, o apagar un brasero, no emite.
##   3. Recargar con la flag ya puesta NO emite nada (montar con los tres braseros encendidos, sala limpia, cofre abierto) y `Puzle3D.silencio_logros` calla una carga con el nivel montado.
##   4. La tabla enganchada (`Logros3D.conectar`) responde: cuenta, rótulo del HUD. El hitstop baja `Engine.time_scale` y lo RESTAURA (también si se alarga o se restaura a mano).
##   5. El zoom de la cámara sube y vuelve al valor de antes.

class FalsoLanzador extends Node:
	var jugador: Node3D = null


## Un brasero falso: lo mínimo que mira el contador (`celda`, `is_lit`) y que busca `Puzle3D._encendible_en` (el grupo de los reactivos).
class FalsoFuego extends Node3D:
	var celda: Vector2i = Vector2i.ZERO
	var is_lit: bool = false

const S: float = 2.3
const LADO: int = 14
const RUTA: String = "user://prueba_logros.json"
const TEXTO: String = """
; pieza v  vigia    1 1 de=5,3..11,8 flag=prueba.l.limpia
; pieza cj cerrojo  4 5 celdas=4,5..4,6 sala=5,3..11,8 hasta=prueba.l.limpia
; pieza cf cofre    10 7 aparece_si=v.todos abierto=prueba.l.cofre
; puzle sala_abre cuando=v.todos_derrotados hace=cj.abrir
; pieza ct contador 2 11 de=9,11+10,11+11,11
; pieza k  puerta   2 8
; puzle abre_k cuando=ct.todos hace=k.abrir
; pieza b  pulsador 8 10 modo=magia
; pieza k2 puerta   2 10
; puzle abre_k2 cuando=b.pulsado hace=k2.abrir
"""
const CELDAS_PUERTAS: Array = [Vector2i(4, 5), Vector2i(4, 6), Vector2i(10, 7), Vector2i(2, 8), Vector2i(2, 10)]
const CELDAS_FUEGO: Array = [Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11)]

var _fallos: int = 0
var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _lanz: FalsoLanzador = null
var _cuerpo_jugador: Node3D = null
var _fuegos: Array = []
var _vistos: Array = []              ## los nombres de logro que han llegado a `Mundo3D.logro`, en orden


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_contrato()
	_montar_terreno()
	await _flujo()
	await _recarga()
	await _hitstop()
	await _zoom()
	Logros3D.restaurar_tiempo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
#  1. Contrato
# ---------------------------------------------------------------------------------------------------------------------

func _contrato() -> void:
	var cat: Array = Array(Mundo3D.LOGROS)
	var tabla: Array = Logros3D.TABLA.keys()
	var sin_fila: Array = cat.filter(func(n): return not tabla.has(n))
	var sin_catalogo: Array = tabla.filter(func(n): return not cat.has(n))
	_ok("1 el catálogo tiene 7 logros y la tabla una fila por cada uno (ni más ni menos)", cat.size() == 7 and sin_fila.is_empty() and sin_catalogo.is_empty(), "sin fila %s · sobran %s" % [str(sin_fila), str(sin_catalogo)])
	var mal: Array = []
	for n in tabla:
		var fila: Dictionary = Logros3D.TABLA[n]
		for k in fila:
			if not Logros3D.CAMPOS.has(k):
				mal.append("%s: campo desconocido %s" % [n, k])
		for k in ["sfx", "sfx2"]:
			var s: String = String(fila.get(k, ""))
			if s != "" and not Sfx.CATALOGO.has(s):
				mal.append("%s: %s «%s» no está en Sfx.CATALOGO" % [n, k, s])
			elif s != "":
				for f in (Sfx.CATALOGO[s]["f"] as Array):
					if not ResourceLoader.exists(Sfx.CARPETA + String(f)):
						mal.append("%s: falta el archivo %s" % [n, f])
		if String(fila.get("sfx", "")) == "":
			mal.append("%s: sin sonido principal" % n)
		if float(fila.get("hitstop", 0.0)) > 0.1:
			mal.append("%s: hitstop > 100 ms" % n)
	_ok("1 cada fila usa solo campos de la plantilla y sonidos que existen (con su archivo)", mal.is_empty(), str(mal))
	var paso: Dictionary = Logros3D.resolver("paso_puzle")
	_ok("1 «paso_puzle» es suave: un tono de pista, sin texto, sin hitstop ni zoom", paso["sfx"] == "logro_pista" and paso["texto"] == "" and paso["hitstop"] == 0.0 and paso["zoom"] == 0.0, str(paso))
	var sala: Dictionary = Logros3D.resolver("sala_limpia")
	_ok("1 «sala_limpia» lleva hitstop de 60–100 ms, algo de zoom y texto", float(sala["hitstop"]) >= 0.06 and float(sala["hitstop"]) <= 0.1 and float(sala["zoom"]) > 0.0 and String(sala["texto"]) != "", str(sala))
	_ok("1 «puzle_resuelto» y «cofre_abierto» llevan texto en el HUD", String(Logros3D.resolver("puzle_resuelto")["texto"]) == "¡Puzle resuelto!" and String(Logros3D.resolver("cofre_abierto")["texto"]) != "")
	_ok("1 un logro que no está en la tabla no resuelve nada", Logros3D.resolver("inventado").is_empty() and Logros3D.reproducir("inventado", Vector3.ZERO).is_empty())
	Mundo3D.actual = null
	Mundo3D.avisar_logro("puzle_resuelto", Vector3.ZERO, null)           # sin Mundo3D no hace nada (ni falla)
	_ok("1 avisar_logro sin Mundo3D no hace nada", true)
	_ok("1 conectar sin Mundo3D devuelve false", not Logros3D.conectar(null, null))


# ---------------------------------------------------------------------------------------------------------------------
#  Montaje (igual que prueba_sala_cerrada)
# ---------------------------------------------------------------------------------------------------------------------

func _montar_terreno() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			f += "#" if borde else "."
			if borde:
				bloq[Vector2i(x, y)] = true
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.logro.connect(func(n: String, _p: Vector3, _nodo: Node) -> void: _vistos.append(n))
	_jugador = Jugador3D.new()
	_jugador.position = _centro(2, 5)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)
	_cuerpo_jugador = Node3D.new()
	_mundo.add_child(_cuerpo_jugador)
	_lanz = FalsoLanzador.new()
	_lanz.jugador = _cuerpo_jugador
	_lanz.add_to_group("player")
	root.add_child(_lanz)
	_mover(2, 5)
	for c in CELDAS_FUEGO:
		var ff := FalsoFuego.new()
		ff.celda = c
		ff.position = _centro(c.x, c.y)
		ff.add_to_group(Reactivo3D.GRUPO_REACTIVO)
		_mundo.add_child(ff)
		_fuegos.append(ff)


func _centro(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(cx, cy)), (cy + 0.5) * S)


func _mover(cx: int, cy: int) -> void:
	_cuerpo_jugador.position = _centro(cx, cy)


func _goblin(cx: int, cy: int) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = _centro(cx, cy)
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = _centro(cx, cy)
	g.casa = g.position
	return g


## Espera en tiempo de JUEGO (el del temporizador normal).
func _espera(s: float) -> void:
	await create_timer(s).timeout


## Espera en tiempo REAL: ignora `Engine.time_scale` (para esperar a que un hitstop acabe).
func _espera_real(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _n(nombre: String) -> int:
	return _vistos.count(nombre)


func _levantar() -> Puzle3D:
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(_mundo, "", TEXTO)
	return z


func _desmontar(z: Puzle3D) -> void:
	for pz in z.piezas():
		var nd: Node = (pz as Puzle3D.Pieza).nodo
		if is_instance_valid(nd):
			nd.free()
	z.free()
	for c in CELDAS_PUERTAS:
		Terreno3D.liberar_celda(c)


func _encender(i: int, si: bool) -> void:
	(_fuegos[i] as FalsoFuego).is_lit = si


# ---------------------------------------------------------------------------------------------------------------------
#  2. Cada suceso emite su logro, una vez
# ---------------------------------------------------------------------------------------------------------------------

func _flujo() -> void:
	Flags.nuevo()
	_ok("2 la tabla se engancha al mundo (Logros3D.conectar)", Logros3D.conectar(_mundo, _mundo))
	var g1: Combate3D = _goblin(7, 4)
	var g2: Combate3D = _goblin(8, 6)
	var g3: Combate3D = _goblin(9, 5)
	var z: Puzle3D = _levantar()
	await _espera(0.4)
	_ok("2 montado sin avisos", z.avisos.is_empty(), str(z.avisos))
	_ok("2 montar la sala NO da ningún logro (nada ha ocurrido todavía)", _vistos.is_empty(), str(_vistos))
	var ct: ContadorReactivos3D = z.nodo("ct") as ContadorReactivos3D
	var k: Puzle3D.PuertaPuzle = z.nodo("k") as Puzle3D.PuertaPuzle
	var k2: Puzle3D.PuertaPuzle = z.nodo("k2") as Puzle3D.PuertaPuzle
	var b: Pulsador3D = z.nodo("b") as Pulsador3D
	var cj: Puzle3D.CerrojoPuzle = z.nodo("cj") as Puzle3D.CerrojoPuzle
	var cf: Puzle3D.CofrePuzle = z.nodo("cf") as Puzle3D.CofrePuzle
	if ct == null or k == null or k2 == null or b == null or cj == null or cf == null:
		_ok("2 están contador, puertas, pulsador, cerrojo y cofre", false, "ct %s k %s k2 %s b %s cj %s cf %s" % [str(ct), str(k), str(k2), str(b), str(cj), str(cf)])
		return

	# Contador: dos pasos y la resolución.
	_encender(0, true)
	await _espera(0.3)
	_ok("2 un brasero de tres: «paso_puzle» (UNO)", _vistos == ["paso_puzle"] and ct.encendidos == 1, str(_vistos))
	_encender(1, true)
	await _espera(0.3)
	_ok("2 dos de tres: otro «paso_puzle»", _vistos == ["paso_puzle", "paso_puzle"], str(_vistos))
	_ok("2 la puerta sigue cerrada", not k.abierta)
	_encender(2, true)
	await _espera(0.4)
	_ok("2 el tercero completa: UN «puzle_resuelto» (el contador y la regla que abre la puerta cuentan como un solo suceso) y la puerta se abre", _vistos == ["paso_puzle", "paso_puzle", "puzle_resuelto"] and k.abierta, str(_vistos))
	_ok("2 el HUD enseña «¡Puzle resuelto!» (la tabla enganchada responde)", Logros3D.texto_visible() == "¡Puzle resuelto!", "«%s»" % Logros3D.texto_visible())
	_ok("2 la tabla contó la respuesta (3 logros ejecutados)", int(Logros3D.total.get("paso_puzle", 0)) >= 2 and int(Logros3D.total.get("puzle_resuelto", 0)) >= 1, str(Logros3D.total))
	var antes: int = _vistos.size()
	_encender(1, false)
	await _espera(0.3)
	_ok("2 apagar un brasero (3 → 2) no emite nada", _vistos.size() == antes, str(_vistos))
	_encender(1, true)
	await _espera(0.3)

	# Pulsador → regla → puerta.
	var antes_p: int = _n("puzle_resuelto")
	b.pulsar()
	await _espera(0.3)
	_ok("2 pulsar abre la puerta por una regla: «puzle_resuelto» (UNO más)", k2.abierta and _n("puzle_resuelto") == antes_p + 1, str(_vistos))
	var antes_q: int = _vistos.size()
	z.call("_ejecutar", {"id": "k2", "accion": "abrir", "args": []})       # abrir lo que ya está abierto
	_ok("2 abrir una puerta que YA estaba abierta no emite", _vistos.size() == antes_q, str(_vistos))

	# Sala cerrada.
	_vistos.clear()
	_mover(5, 5)
	await _espera(0.5)
	_ok("2 entrar en la sala la cierra y eso NO es un logro", cj.cerrado and _vistos.is_empty(), str(_vistos))
	g1.receive_damage(10000.0)
	g2.receive_damage(10000.0)
	await _espera(0.5)
	_ok("2 con dos de tres caídos, ningún logro", _vistos.is_empty(), str(_vistos))
	g3.receive_damage(10000.0)
	await _espera(0.7)
	_ok("2 cae el último: «sala_limpia», luego «puerta_abierta» (el cerrojo) y luego «cofre_aparece», cada uno UNA vez y en ese orden", _vistos == ["sala_limpia", "puerta_abierta", "cofre_aparece"], str(_vistos))
	_ok("2 «sala_limpia» no se confunde con puzle_resuelto (la regla del cerrojo no abre una puerta de puzle)", _n("puzle_resuelto") == 0)
	await _espera_real(0.3)
	_ok("2 pasada la pausa de impacto, el tiempo vuelve a 1,0", is_equal_approx(Engine.time_scale, 1.0) and not Logros3D.hitstop_activo(), "time_scale %.3f" % Engine.time_scale)
	await _espera(0.8)
	_vistos.clear()
	_ok("2 el cofre abre", cf.abrir())
	await _espera(1.8)
	_ok("2 acabada la animación: «cofre_abierto» (UNO)", _vistos == ["cofre_abierto"] and cf.es_abierto, str(_vistos))
	_ok("2 el HUD enseña «¡Cofre abierto!»", Logros3D.texto_visible() == "¡Cofre abierto!", "«%s»" % Logros3D.texto_visible())
	_vistos.clear()
	_mover(2, 5)
	await _espera(0.3)
	_mover(6, 4)
	await _espera(0.5)
	_ok("2 reentrar a la sala ya vencida no emite nada", _vistos.is_empty(), str(_vistos))
	_ok("2 guardar escribe el archivo", Flags.i().guardar(RUTA))
	_desmontar(z)


# ---------------------------------------------------------------------------------------------------------------------
#  3. Recargar la partida: nada de fanfarria por lo que ya estaba hecho
# ---------------------------------------------------------------------------------------------------------------------

func _recarga() -> void:
	Flags.nuevo()
	_ok("3 cargar devuelve true", Flags.i().cargar(RUTA))
	_vistos.clear()
	var g4: Combate3D = _goblin(7, 4)                    # al recargar los enemigos vuelven
	_mover(6, 4)                                         # y el jugador aparece dentro de la sala
	# Los tres braseros siguen encendidos de la partida anterior: el contador nace completo SIN avisar.
	var z2: Puzle3D = _levantar()
	await _espera(0.8)
	var cf2: Puzle3D.CofrePuzle = z2.nodo("cf") as Puzle3D.CofrePuzle
	var ct2: ContadorReactivos3D = z2.nodo("ct") as ContadorReactivos3D
	_ok("3 recargada: cofre ABIERTO, contador ya completo (3 braseros encendidos al montar)", cf2 != null and cf2.es_abierto and ct2 != null and ct2.completo, "")
	_ok("3 recargar con todo ya hecho (sala limpia, cofre abierto, braseros encendidos) NO emite ningún logro", _vistos.is_empty(), str(_vistos))
	if is_instance_valid(g4) and not g4.is_queued_for_deletion():       # el vigía retira a los enemigos de una sala ya limpia al montar (mapas abiertos, 23/10)
		g4.free()
	_desmontar(z2)
	# Partida a medias: solo la sala limpia. El cofre nace cerrado y visible SIN «cofre_aparece».
	Flags.nuevo()
	Flags.i().poner("prueba.l.limpia")
	_vistos.clear()
	var z3: Puzle3D = _levantar()
	await _espera(0.6)
	var cf3: Puzle3D.CofrePuzle = z3.nodo("cf") as Puzle3D.CofrePuzle
	_ok("3 partida con la sala limpia: el cofre nace cerrado y no se avisa de que «aparece»", cf3 != null and cf3.es_cerrado and _vistos.is_empty(), str(_vistos))
	_desmontar(z3)
	# Cargar con el nivel ya montado, con el jugador dentro y la sala cerrada: la flag que llega abre el cerrojo.
	Flags.nuevo()
	_vistos.clear()
	_mover(2, 5)
	var g5: Combate3D = _goblin(7, 4)
	var z4: Puzle3D = _levantar()
	await _espera(0.4)
	var cj4: Puzle3D.CerrojoPuzle = z4.nodo("cj") as Puzle3D.CerrojoPuzle
	_mover(5, 5)
	await _espera(0.5)
	_ok("3 (control) el jugador entra y el cerrojo se cierra", cj4 != null and cj4.cerrado)
	Puzle3D.silencio_logros = true
	Flags.i().poner("prueba.l.limpia")                   # lo que haría Flags.cargar con el nivel montado
	Puzle3D.silencio_logros = false
	_ok("3 con `silencio_logros` la flag que llega abre el cerrojo SIN logro", cj4 != null and not cj4.cerrado and _vistos.is_empty(), str(_vistos))
	if is_instance_valid(g5) and not g5.is_queued_for_deletion():
		g5.free()
	_desmontar(z4)
	Flags.nuevo()
	_vistos.clear()
	_mover(2, 5)
	var g6: Combate3D = _goblin(7, 4)
	var z5: Puzle3D = _levantar()
	await _espera(0.3)
	var cj5: Puzle3D.CerrojoPuzle = z5.nodo("cj") as Puzle3D.CerrojoPuzle
	_mover(5, 5)
	await _espera(0.5)
	Flags.i().poner("prueba.l.limpia")                   # lo mismo SIN silencio: el cerrojo se abre de verdad y avisa
	_ok("3 (control) sin `silencio_logros` esa misma apertura sí es «puerta_abierta»", cj5 != null and not cj5.cerrado and _vistos == ["puerta_abierta"], str(_vistos))
	if is_instance_valid(g6) and not g6.is_queued_for_deletion():
		g6.free()
	_desmontar(z5)


# ---------------------------------------------------------------------------------------------------------------------
#  4. Hitstop
# ---------------------------------------------------------------------------------------------------------------------

func _hitstop() -> void:
	Logros3D.restaurar_tiempo()
	_ok("4 (control) el tiempo parte de 1,0", is_equal_approx(Engine.time_scale, 1.0))
	Logros3D.hitstop(self, 0.08)
	_ok("4 el hitstop baja time_scale", is_equal_approx(Engine.time_scale, Logros3D.ESCALA_HITSTOP) and Logros3D.hitstop_activo(), "time_scale %.3f" % Engine.time_scale)
	await _espera_real(0.35)
	_ok("4 pasados los 80 ms REALES el tiempo está restaurado a 1,0", is_equal_approx(Engine.time_scale, 1.0) and not Logros3D.hitstop_activo(), "time_scale %.3f" % Engine.time_scale)
	# Dos seguidos: se alarga, y se restaura al valor ORIGINAL (no al ya frenado).
	Logros3D.hitstop(self, 0.08)
	await _espera_real(0.04)
	Logros3D.hitstop(self, 0.08)
	_ok("4 un segundo hitstop dentro del primero sigue frenado", is_equal_approx(Engine.time_scale, Logros3D.ESCALA_HITSTOP))
	await _espera_real(0.4)
	_ok("4 y al acabar el último vuelve a 1,0 (no se queda en el valor frenado)", is_equal_approx(Engine.time_scale, 1.0), "time_scale %.3f" % Engine.time_scale)
	# Si otro sistema ya había cambiado la escala, se devuelve esa.
	Engine.time_scale = 0.5
	Logros3D.hitstop(self, 0.05)
	await _espera_real(0.3)
	_ok("4 con time_scale = 0,5 de antes, se restaura 0,5", is_equal_approx(Engine.time_scale, 0.5), "time_scale %.3f" % Engine.time_scale)
	Engine.time_scale = 1.0
	# Restauración a mano e idempotente.
	Logros3D.hitstop(self, 5.0)
	Logros3D.restaurar_tiempo()
	Logros3D.restaurar_tiempo()
	_ok("4 restaurar_tiempo() lo deja en 1,0 (dos veces seguidas, igual) y anula el temporizador pendiente", is_equal_approx(Engine.time_scale, 1.0) and not Logros3D.hitstop_activo())
	# La respuesta completa de «sala_limpia» (con padre en el árbol) pide el hitstop y no deja el tiempo frenado.
	var r: Dictionary = Logros3D.reproducir("sala_limpia", Vector3(5, 1, 5), null, _mundo)
	_ok("4 reproducir(sala_limpia): hace sonido, destello, texto, hitstop (y zoom si hay cámara)", bool(r.get("hizo_sfx")) and bool(r.get("hizo_vfx")) and bool(r.get("hizo_texto")) and bool(r.get("hizo_hitstop")), str(r))
	await _espera_real(0.35)
	_ok("4 el texto «Sala despejada» está en el HUD (el fundido ignora el hitstop)", Logros3D.texto_visible() == "Sala despejada", "«%s»" % Logros3D.texto_visible())
	_ok("4 y el tiempo vuelve a 1,0", is_equal_approx(Engine.time_scale, 1.0), "time_scale %.3f" % Engine.time_scale)
	var p: Dictionary = Logros3D.reproducir("paso_puzle", Vector3(5, 1, 5), null, _mundo)
	_ok("4 reproducir(paso_puzle): sonido y destello, sin texto ni hitstop", bool(p.get("hizo_sfx")) and bool(p.get("hizo_vfx")) and not bool(p.get("hizo_texto")) and not bool(p.get("hizo_hitstop")) and is_equal_approx(Engine.time_scale, 1.0), str(p))


# ---------------------------------------------------------------------------------------------------------------------
#  5. Zoom
# ---------------------------------------------------------------------------------------------------------------------

func _zoom() -> void:
	var sin_cam: bool = Logros3D.zoom(self, 0.1)
	_ok("5 sin cámara en el árbol, el zoom no hace nada (false)", not sin_cam)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	root.add_child(cam)
	cam.make_current()
	_ok("5 con cámara: el zoom arranca", Logros3D.zoom(self, 0.1))
	await _espera_real(Logros3D.ZOOM_ENTRA + Logros3D.ZOOM_MANTIENE * 0.5 + 0.05)
	_ok("5 la cámara se acerca (size < 10)", cam.size < 9.5, "size %.2f" % cam.size)
	# Otro zoom encima: no pierde el valor original.
	Logros3D.zoom(self, 0.1)
	await _espera_real(Logros3D.ZOOM_ENTRA + Logros3D.ZOOM_MANTIENE + Logros3D.ZOOM_SALE + 0.4)
	_ok("5 al acabar vuelve a su tamaño de antes (10)", is_equal_approx(cam.size, 10.0), "size %.3f" % cam.size)
	cam.queue_free()
