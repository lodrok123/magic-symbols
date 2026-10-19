extends SceneTree
## Armazón común de los ESCENARIOS (Fase 13.10, 15/10). Lo escribe el Juego.
##
## Qué es un escenario: una prueba que carga la ESCENA de verdad (`escenas/PruebaBosque.tscn`, con la maqueta, el jugador, el
## Lanzador3D, la simulación de agua y los objetos reactivos) en headless, avanza fotogramas, hace cosas por código como las haría
## el jugador (lanzar un hechizo, andar hacia una casilla) y AFIRMA lo que pasó. Las `prueba_*.gd` miran una pieza suelta con un
## mundo falso; los escenarios miran que las piezas siguen cableadas entre sí (eso es lo que se rompió con la tinaja: cada pieza
## funcionaba sola y nadie las había unido).
##
## Cómo se escribe uno:
##     extends "res://herramientas/escenario_base.gd"
##     func _escenario() -> void:
##         await cargar()
##         await lanzar("agua", ["flecha"], Vector3.RIGHT)
##         await avanzar_s(5.0)
##         _ok("1 pasó lo esperado", cosa)
## y se corre con (a 30 fps fijos, como pide el plan; sin el flag también vale, el reloj cuenta los segundos de verdad):
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_agua_tinaja.gd
##
## Reglas del armazón:
##   · El tiempo se cuenta con el DELTA real de los fotogramas (nodo `Reloj`), no con «n fotogramas × 1/30»: así `avanzar_s(5)` son
##     5 s de simulación se corra con --fixed-fps o sin él.
##   · `cargar()` pone `usar_escena = false`: el nivel sale de las LETRAS (mundo/datos_nivel/mapas/Bosque.txt) y no del
##     Nivel_Bosque.tscn horneado, que lleva las ediciones de Pablo y cambia con cada F9. Un escenario no debe depender de eso.
##     (Excepción: `hornear`, que sí toca ese archivo y por eso lo guarda y lo restaura.)
##   · Nada se escribe en el repo salvo el diario de la prueba (user://playtest_logs) y, en `hornear`, lo dicho arriba.
##   · Un fallo es `_ok(nombre, false)`; al final se imprime `FALLOS: n` y se sale con 1 si n > 0, igual que las `prueba_*.gd`.
##     Un AVISO (`_aviso`) NO cuenta: es para lo que se mide y se enseña pero todavía no es contrato.

const RUTA_BOSQUE: String = "res://escenas/PruebaBosque.tscn"

## Cuenta el tiempo que de verdad pasa entre fotogramas (suma de deltas).
class Reloj extends Node:
	var t: float = 0.0
	var fotogramas: int = 0
	func _process(delta: float) -> void:
		t += delta
		fotogramas += 1

var maqueta: Node = null          ## la raíz de la escena (PruebaTest2)
var lanzador: Lanzador3D = null
var jugador: Node3D = null       ## Jugador3D
var reloj: Reloj = null
var _fallos: int = 0
var _avisos: int = 0


func _initialize() -> void:
	await process_frame
	await _escenario()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Lo rellena cada escenario.
func _escenario() -> void:
	pass


# ---------------------------------------------------------------------------------------------------------------------
#  Afirmar
# ---------------------------------------------------------------------------------------------------------------------

func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Algo que se mide y se enseña, pero que todavía no es una exigencia: no suma fallos.
func _aviso(nombre: String, info: String = "") -> void:
	_avisos += 1
	print("AVISO " + nombre + "  " + info)


# ---------------------------------------------------------------------------------------------------------------------
#  Cargar la escena y avanzar el tiempo
# ---------------------------------------------------------------------------------------------------------------------

## Carga la escena, la mete en el árbol y espera a que estén montados el Lanzador3D, el jugador y la simulación de agua.
## Devuelve la raíz de la escena (también queda en `maqueta`).
func cargar(ruta: String = RUTA_BOSQUE, usar_escena: bool = false, fotogramas_max: int = 600) -> Node:
	if reloj == null:                      # una segunda carga en el mismo escenario (hornear: recargar) sigue con el mismo reloj
		reloj = Reloj.new()
		reloj.name = "Reloj"
		root.add_child(reloj)
	var paquete: PackedScene = load(ruta) as PackedScene
	_ok("0 la escena %s carga" % ruta.get_file(), paquete != null)
	if paquete == null:
		return null
	maqueta = paquete.instantiate()
	if "usar_escena" in maqueta:
		maqueta.set("usar_escena", usar_escena)
	root.add_child(maqueta)
	var n: int = 0
	while n < fotogramas_max and (get_first_node_in_group("spellcaster") == null or Terreno3D.agua_sim == null):
		await process_frame
		n += 1
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	_ok("0 la escena monta el Lanzador3D, el jugador y la simulación de agua", lanzador != null and jugador != null and Terreno3D.agua_sim != null,
		"tras %d fotogramas" % n)
	# La maqueta tapa la pantalla con un velo unos segundos de RELOJ DE PARED (PRECALENTAR: compila los efectos); mientras dura,
	# Jugador3D.puede_lanzar() es false. Se espera a que se levante, con tope de 30 s de pared por si algo lo dejara puesto.
	var pared: int = Time.get_ticks_msec()
	while not jugador.puede_lanzar() and Time.get_ticks_msec() - pared < 30000:
		await process_frame
	_ok("0 el jugador puede lanzar (velo de precalentado levantado)", jugador.puede_lanzar(), "%d ms de pared" % (Time.get_ticks_msec() - pared))
	await avanzar(30)           # que se asiente (hierba, cámara, primer paso de la simulación)
	return maqueta


func avanzar(fotogramas: int) -> void:
	for _i in range(fotogramas):
		await process_frame


## Avanza `segundos` de tiempo REAL de simulación (suma de deltas). Devuelve los que pasaron de verdad.
func avanzar_s(segundos: float) -> float:
	var inicio: float = reloj.t
	while reloj.t - inicio < segundos - 1.0e-6:
		await process_frame
	return reloj.t - inicio


## Avanza `segundos` y cada `cada` s llama a `al_segundo(t_relativo)`. Para volcar tablas mientras se espera.
func avanzar_vigilando(segundos: float, cada: float, al_segundo: Callable) -> void:
	var inicio: float = reloj.t
	var siguiente: float = cada
	while reloj.t - inicio < segundos - 1.0e-6:
		await process_frame
		if reloj.t - inicio >= siguiente - 1.0e-6:
			al_segundo.call(snappedf(reloj.t - inicio, 0.01))
			siguiente += cada


# ---------------------------------------------------------------------------------------------------------------------
#  Jugador
# ---------------------------------------------------------------------------------------------------------------------

## Pone al jugador en el centro de una casilla (a la altura de sus pies ahí). Es un TELETRANSPORTE: para andar de verdad,
## `mover_hacia`.
func colocar_jugador(c: Vector2i) -> void:
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var pj: Node3D = jugador.get("pj") as Node3D
	if pj != null:
		pj.position = p            # Jugador3D adopta la posición de `pj` si algo externo la mueve (ir_a)
	jugador.position = p


func celda_jugador() -> Vector2i:
	return Terreno3D.celda_de(jugador.position)


## Anda de verdad hacia una casilla con `Input.parse_input_event` (teclas WASD, que es lo que lee Jugador3D), hasta llegar a menos
## de `tol` casillas o agotar `max_s`. Como el movimiento sigue a la cámara, antes mide hacia dónde empuja W y hacia dónde D
## (0,3 s cada una) y reparte las teclas según eso. Devuelve true si llegó.
func mover_hacia(c: Vector2i, max_s: float = 15.0, tol: float = 0.5) -> bool:
	var w: Vector2 = await _empuje(KEY_W)
	var d: Vector2 = await _empuje(KEY_D)
	if w.length() < 0.1 or d.length() < 0.1:
		_aviso("mover_hacia: el jugador no se mueve con las teclas (bloqueado o sin foco)", "w=%s d=%s" % [w, d])
		return false
	var meta: Vector3 = Terreno3D.centro_de(c, 0.0)
	var inicio: float = reloj.t
	var llego: bool = false
	while reloj.t - inicio < max_s:
		var a: Vector2 = Vector2(meta.x - jugador.position.x, meta.z - jugador.position.z)
		if a.length() <= tol * Terreno3D.casilla:
			llego = true
			break
		var adelante: float = a.dot(w)
		var lado: float = a.dot(d)
		_tecla(KEY_W, adelante > 0.15 * a.length())
		_tecla(KEY_S, adelante < -0.15 * a.length())
		_tecla(KEY_D, lado > 0.15 * a.length())
		_tecla(KEY_A, lado < -0.15 * a.length())
		await process_frame
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	await avanzar(2)
	return llego


## Hacia dónde se desplaza el jugador (plano XZ, normalizado) al mantener una tecla 0,3 s. Vuelve a donde estaba.
func _empuje(tecla: Key) -> Vector2:
	var antes: Vector3 = jugador.position
	_tecla(tecla, true)
	await avanzar_s(0.3)
	_tecla(tecla, false)
	await avanzar(2)
	var v := Vector2(jugador.position.x - antes.x, jugador.position.z - antes.z)
	colocar_jugador(Terreno3D.celda_de(antes))
	await avanzar(2)
	return v.normalized() if v.length() > 0.001 else Vector2.ZERO


func _tecla(tecla: Key, pulsada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = pulsada
	Input.parse_input_event(ev)


# ---------------------------------------------------------------------------------------------------------------------
#  Magia
# ---------------------------------------------------------------------------------------------------------------------

## Compone en la página 1 un hechizo (`elemento` + `glifos`) y lo lanza desde el jugador hacia `dir` (plano XZ) SIN pasar por el
## modo de apuntar (Lanzador3D.lanzar_pagina_ya). Quita la recarga antes. Devuelve true si salió un hechizo.
func lanzar(elemento: String, glifos: Array, dir: Vector3) -> bool:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	# 19/10: los elementos líquidos y sólidos ya CAEN (ESPEC_HECHIZO §2: gravedad base 1 × el estado). Estos escenarios prueban reglas de puzle, no balística:
	# se lanza sin gravedad, como asumían todos antes de la ESPEC. Si Pablo ajusta la gravedad de las flechas, se quita esta línea.
	var previos: Dictionary = lanzador.cambios_hechizo.duplicate()
	if not previos.has("gravedad"):
		lanzador.cambios_hechizo = previos.duplicate()
		lanzador.cambios_hechizo["gravedad"] = 0.0
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var salio: bool = lanzador.lanzar_pagina_ya(0, jugador.position, d)
	lanzador.cambios_hechizo = previos                       # el hechizo ya está construido: lo que toque un laboratorio queda como estaba
	return salio


## Como `lanzar`, pero apunta a una casilla: coloca al jugador `distancia` casillas antes (en línea recta desde `desde_celda`, o
## en la casilla vecina más cercana por el oeste si no se da) y dispara hacia el centro de `objetivo`.
func lanzar_a_celda(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	var a: Vector3 = Terreno3D.centro_de(objetivo, 0.0) - Terreno3D.centro_de(desde, 0.0)
	return lanzar(elemento, glifos, a)


# ---------------------------------------------------------------------------------------------------------------------
#  Agua
# ---------------------------------------------------------------------------------------------------------------------

func profundidades(celdas: Array) -> Array:
	var r: Array = []
	for c in celdas:
		r.append(Terreno3D.agua_sim.profundidad_casilla(c as Vector2i))
	return r


## Escribe una línea en el diario de la prueba (`PlayLog`) Y en la consola.
func volcar(evento: String, datos: Dictionary) -> void:
	PlayLog.event(evento, datos)
	print("      [%s] %s" % [evento, JSON.stringify(datos)])


# ---------------------------------------------------------------------------------------------------------------------
#  Leer el diario
# ---------------------------------------------------------------------------------------------------------------------

## Los eventos del diario de ESTA ejecución (el .jsonl más reciente de user://playtest_logs), filtrados por tipo.
## `PlayLog` no guarda nada en memoria (escribe y vacía en cada línea), así que se lee el archivo; se escribe con `flush`.
func eventos(tipo: String) -> Array:
	var ruta: String = ""
	# La ruta del archivo abierto por ESTA ejecución. `_file` es privado de PlayLog, pero esto es una herramienta de pruebas y no hay otra
	# forma de saber cuál de los .jsonl de la carpeta es el de ahora (get_modified_time solo tiene resolución de segundos).
	if PlayLog._file != null:
		ruta = PlayLog._file.get_path()
	var res: Array = []
	var fa: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if fa == null:
		return res
	while not fa.eof_reached():
		var linea: String = fa.get_line()
		if linea.is_empty():
			continue
		var j: Variant = JSON.parse_string(linea)
		if j is Dictionary and String((j as Dictionary).get("evento", "")) == tipo:
			res.append(j)
	return res
