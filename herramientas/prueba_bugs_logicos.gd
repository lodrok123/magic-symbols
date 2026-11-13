extends SceneTree
## CUATRO BUGS LÓGICOS PEQUEÑOS (13/11, tarea 34 de docs/PENDIENTES.md), sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bugs_logicos.gd
## Las comprobaciones del tono de llegada del pulso viven en `prueba_pulso.gd` (grupo 10) y la de la tinaja que deja de verter al cerrar el grifo, en `escenario_puzles_agua.gd` (Q8.4b).
## Aquí:
##   · RECEPTOR con `rearme` + `flag`: al apagarse (solo por el rearme, o a mano) quita la flag que puso al encenderse; recargar la partida lo deja coherente (apagado y sin flag).
##   · BARRERA DE AGUA (agua + ᛜ): al levantarse sobre un `pulsador modo=agua` lo pulsa y sobre un muro de fuego `B` lo apaga, con la regla de la flecha de agua (Materia.riega / moja);
##     una barrera de fuego o de tierra no hace ninguna de las dos, y el agua levantada en otra casilla tampoco.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)

const LADO: int = 20
const CELDA_PULSADOR: Vector2i = Vector2i(6, 6)
const CELDA_B: Vector2i = Vector2i(12, 12)
const CELDA_LEJOS: Vector2i = Vector2i(15, 4)

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_receptor_rearme_flag()
	await _barrera_de_agua()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
#  Receptor con rearme + flag
# ---------------------------------------------------------------------------------------------------------------------

func _receptor_rearme_flag() -> void:
	var f: Flags = Flags.nuevo()
	var nombre: String = "prueba.sala.receptor_rearme"
	var r := ReceptorPulso3D.new()
	r.preparar(Vector2i(1, 1), "", nombre, 0.5)
	root.add_child(r)
	r.activar()
	_ok("R1 al encenderse pone su flag", r.activo and f.tiene(nombre))
	r._process(0.3)
	_ok("R1 antes de que acabe el rearme sigue activo y con la flag", r.activo and f.tiene(nombre))
	var apagados: Array = [0]
	r.apagado.connect(func() -> void: apagados[0] += 1)
	r._process(0.3)
	_ok("R2 el rearme lo apaga solo", not r.activo and apagados[0] == 1)
	_ok("R2 …y le quita la flag (una puerta que la mire ya no se queda abierta)", not f.tiene(nombre))
	r.activar()
	_ok("R3 se puede volver a encender: pone la flag otra vez", r.activo and f.tiene(nombre))
	r.apagar()
	_ok("R3 apagarlo a mano también quita la flag", not r.activo and not f.tiene(nombre))
	# Recargar la partida: la flag decide cómo nace. Sin flag (ya rearmado) nace apagado; con flag, activado.
	var r2 := ReceptorPulso3D.new()
	r2.preparar(Vector2i(2, 2), "", nombre, 0.5)
	root.add_child(r2)
	_ok("R4 al recargar tras el rearme: nace apagado y sin flag", not r2.activo and not f.tiene(nombre))
	f.poner(nombre)
	var r3 := ReceptorPulso3D.new()
	r3.preparar(Vector2i(3, 3), "", nombre, 0.0)
	root.add_child(r3)
	_ok("R4 control: sin rearme y con la flag puesta, nace activado (como el cofre)", r3.activo and f.tiene(nombre))
	r3.apagar()
	_ok("R5 un receptor sin rearme apagado a mano también deja la flag coherente", not f.tiene(nombre))
	# Sin flag nada cambia: el rearme apaga y no toca ninguna.
	var r4 := ReceptorPulso3D.new()
	r4.preparar(Vector2i(4, 4), "", "", 0.2)
	root.add_child(r4)
	r4.activar()
	r4._process(0.5)
	_ok("R6 sin `flag=` el rearme sigue apagándolo y no toca ninguna flag", not r4.activo and f.nombres().is_empty())
	for n in [r, r2, r3, r4]:
		n.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
#  Barrera de agua (agua + ᛜ)
# ---------------------------------------------------------------------------------------------------------------------

func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var fila: String = ""
		for x in range(LADO):
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				fila += "#"
			elif c == CELDA_B:
				fila += "B"
			else:
				fila += "."
		filas.append(fila)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()


## Levanta una barrera (ᛜ) del elemento dado en la casilla `c`, como lo hace la jugadora.
func _barrera(elemento: String, c: Vector2i) -> void:
	var rd: RuneData = load("res://nucleo/%s_rune.tres" % elemento) as RuneData
	var h: Hechizo = Hechizo.construir(rd, {"barrera": 1}, 1.0)
	HechizoVivo.crear(h, Lanzador3D.centro_de(c, 0.0), Vector3.RIGHT, _l, null, {}, true)


func _pulsador() -> Pulsador3D:
	var p := Pulsador3D.new()
	p.preparar(CELDA_PULSADOR, "agua")
	root.add_child(p)
	return p


func _barrera_de_agua() -> void:
	# Control: la flecha de agua pulsa el pulsador de agua y apaga la B (es la regla que la barrera debe copiar).
	_montar()
	var agua: RuneData = load("res://nucleo/water_rune.tres") as RuneData
	var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	var p0: Pulsador3D = _pulsador()
	_ok("B0 control: el pulsador de agua reacciona a la runa de agua y no a la de fuego", p0.spell_reacts(agua) and not p0.spell_reacts(fuego))
	_ok("B0 hay una B en el mapa y se coloca como barrera de fuego", Lanzador3D.colocar_barreras(_m) == 1)

	# 1. agua + ᛜ sobre el pulsador de agua: lo pulsa.
	_montar()
	var p1: Pulsador3D = _pulsador()
	Lanzador3D.colocar_barreras(_m)
	_barrera("water", CELDA_PULSADOR)
	_ok("B1 una barrera de agua levantada sobre un `pulsador modo=agua` lo pulsa", p1.activo and p1.veces == 1, "veces %d" % p1.veces)

	# 2. agua + ᛜ sobre el muro de fuego B: lo apaga.
	var b: Lanzador3D.BarreraFuego = null
	for n in _m.get_children():
		if n is Lanzador3D.BarreraFuego:
			b = n
	_ok("B2 (control) la B nace encendida", b != null and not b.apagada)
	_barrera("water", CELDA_B)
	_ok("B2 una barrera de agua levantada sobre un muro de fuego `B` lo apaga", b != null and b.apagada)

	# 3. no hace nada más: agua en otra casilla, fuego o tierra sobre las piezas.
	_montar()
	var p2: Pulsador3D = _pulsador()
	Lanzador3D.colocar_barreras(_m)
	for n in _m.get_children():
		if n is Lanzador3D.BarreraFuego:
			b = n
	_barrera("water", CELDA_LEJOS)
	_ok("B3 el agua levantada lejos no pulsa el pulsador ni apaga la B", not p2.activo and not b.apagada)
	_barrera("fire", CELDA_PULSADOR)
	_ok("B3 una barrera de fuego sobre el pulsador de agua no lo pulsa (no es agua)", not p2.activo)
	_barrera("earth", CELDA_PULSADOR)
	_barrera("earth", CELDA_B)
	_ok("B3 una barrera de tierra no pulsa el pulsador de agua ni apaga la B", not p2.activo and not b.apagada)
	_barrera("fire", CELDA_B)
	_ok("B3 una barrera de fuego sobre la B no la apaga", not b.apagada)
	# Un pulsador de magia (cualquier hechizo) NO entra en el contacto por agua: no se pulsa por una barrera, como antes.
	var pm := Pulsador3D.new()
	pm.preparar(Vector2i(8, 8), "magia")
	root.add_child(pm)
	_barrera("water", Vector2i(8, 8))
	_ok("B3 el pulsador de modo magia no entra en esta regla (solo `modo=agua`)", not pm.activo)
	for n in [pm]:
		n.queue_free()
