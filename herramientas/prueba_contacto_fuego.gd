extends SceneTree
## A2 de docs/PLAN_EOW.md (21/10, Juego): EL FUEGO PASA POR CONTACTO. Regla de Pablo: solo pasa de algo que ESTÁ ARDIENDO a algo INFLAMABLE que lo
## TOCA (sin radio de calor). Sin ventana: `--headless --fixed-fps 30` (las flechas vuelan con tweens y necesitan fotogramas).
## Los cuatro casos del plan:
##   1. Un goblin ardiendo que toca un seto lo prende; uno que pasa a 2 casillas, no.
##   2. Una flecha que atraviesa un brasero encendido llega ardiendo (y su impacto quema; ardiendo prende lo inflamable que cruza).
##   3. Un seto mojado no prende.
##   4. Los escenarios de fuego siguen en FALLOS 0 (se ejecutan aparte: escenario_puzles_fuego, prueba_fuego, prueba_papeles).
## Además, lo que la regla implica en el otro sentido: una llama prende al goblin que la toca (salvo mojado) y un goblin ardiendo prende a otro.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_contacto_fuego.gd

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

const DT: float = 1.0 / 60.0
const S: float = 2.3
var _mundo: MundoFalso = null
var _fx: Vfx3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _crear_mundo() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true
	_fx = Vfx3D.new()
	root.add_child(_fx)


## Un objeto reactivo colocado como lo hace la maqueta. `x`,`z` en casillas (se coloca en el centro de la casilla).
func _objeto(tipo: String, cx: float, cz: float, elemento: String = "") -> Reactivo3D:
	var r := Reactivo3D.new()
	r.preparar(tipo, Vector2i(int(cx), int(cz)), elemento, _fx, null)
	r.position = Vector3((cx + 0.5) * S, MundoFalso.ALTO, (cz + 0.5) * S)
	_mundo.add_child(r)
	return r


## Un goblin sin IA (quieto) en la posición del mundo `p`. `arquero` = modelo goblin_archer.
func _goblin(p: Vector3, arquero: bool = false) -> Combate3D:
	var j := Jugador3D.new()
	j.position = Vector3(18 * S, MundoFalso.ALTO, 18 * S)
	j.pj = Pj3D.new()                       # recibir_dano reproduce la animación «hit» en el modelo del jugador
	_mundo.add_child(j.pj)
	var modelo := Pj3D.new()
	modelo.id = "goblin_archer" if arquero else "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	return g


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		g._physics_process(DT)


func _arde(r: Reactivo3D) -> bool:
	return r.estado == Reactivo3D.EstadoObj.ARDIENDO


func _runa(tags: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for g in tags:
		t.append(String(g))
	r.tags = t
	return r


func _initialize() -> void:
	await process_frame
	_crear_mundo()
	_caso_1_goblin_seto()
	_caso_3_mojado()
	_llama_prende_goblin()
	_goblin_prende_goblin()
	await _caso_2_flecha()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------

func _caso_1_goblin_seto() -> void:
	var seto_toca := _objeto("seto", 3, 3)
	var g := _goblin(Vector3(3.5 * S + 0.3, MundoFalso.ALTO, 3.5 * S))         # solapa la caja del seto (medio lado 1,03 + radio 0,32)
	g.quemando = 3.0
	_ok("1 un goblin con quemadura activa está ardiendo y sigue siendo inflamable", g.esta_ardiendo() and g.puede_prender())
	_pasos(g, 20)
	_ok("1 un goblin ardiendo que TOCA un seto lo prende", _arde(seto_toca))
	var seto_lejos := _objeto("seto", 12, 3)
	var g2 := _goblin(Vector3(12.5 * S - 2.0 * S, MundoFalso.ALTO, 3.5 * S))   # el seto está a 2 casillas (4,6 u) de su centro
	g2.quemando = 3.0
	var dist: float = Vector2(g2.position.x - seto_lejos.position.x, g2.position.z - seto_lejos.position.z).length()
	_pasos(g2, 20)
	_ok("1 y uno que pasa a ~2 casillas, no", not _arde(seto_lejos) and dist > 1.9 * S, "distancia %.2f u" % dist)
	# Sin fuego, tocar no prende nada: el contacto necesita que algo ARDA.
	var seto_frio := _objeto("seto", 3, 8)
	var g3 := _goblin(Vector3(3.5 * S + 0.3, MundoFalso.ALTO, 8.5 * S))
	_pasos(g3, 20)
	_ok("1 un goblin que NO arde, aunque toque un seto, no lo prende", not _arde(seto_frio) and not g3.esta_ardiendo())
	# Un seto con -inflamable no prende aunque lo toque un goblin ardiendo (los papeles mandan).
	var seto_roca := _objeto("seto", 3, 12)
	seto_roca.papeles = PackedStringArray(["-inflamable"])
	var g4 := _goblin(Vector3(3.5 * S + 0.3, MundoFalso.ALTO, 12.5 * S))
	g4.quemando = 3.0
	_pasos(g4, 20)
	_ok("1 un seto con -inflamable no prende (el papel decide)", not _arde(seto_roca))


func _caso_3_mojado() -> void:
	var mojado := _objeto("seto", 6, 3)
	mojado.mojable = true
	mojado.on_spell_hit(_runa(["agua"]))
	_ok("3 el seto mojable queda mojado con agua", mojado.esta_mojado())
	var seco := _objeto("seto", 8, 3)        # la caja de cada seto mide ~2,07 u: a 2 casillas entre centros no se solapan
	# Un goblin ardiendo que toca los dos a la vez: uno en cada lado, sin tocar el otro.
	var g_m := _goblin(Vector3(6.5 * S + 0.3, MundoFalso.ALTO, 3.5 * S))
	g_m.quemando = 3.0
	var g_s := _goblin(Vector3(8.5 * S + 0.3, MundoFalso.ALTO, 3.5 * S))
	g_s.quemando = 3.0
	_pasos(g_m, 20)
	_pasos(g_s, 20)
	_ok("3 un seto mojado no prende aunque lo toque un goblin ardiendo", not _arde(mojado) and mojado.estado == Reactivo3D.EstadoObj.SANO)
	_ok("3 el seto seco de al lado, con el mismo goblin ardiendo, sí", _arde(seco))
	# Y un goblin mojado no prende al tocar una llama.
	var brasero := _objeto("brasero", 14, 3)
	brasero.encender_llama()
	var gm := _goblin(Vector3(14.5 * S, MundoFalso.ALTO, 3.5 * S))
	gm.mojado = 6.0
	_pasos(gm, 20)
	_ok("3 un goblin mojado no se prende al tocar un brasero encendido", not gm.esta_ardiendo())


func _llama_prende_goblin() -> void:
	var brasero := _objeto("brasero", 14, 8)
	brasero.encender_llama()
	_ok("2b el brasero encendido pasa la llama por contacto", brasero.emite_fuego_por_contacto() and brasero.esta_ardiendo())
	var apagado := _objeto("fogata", 16, 8)
	_ok("2b y apagado no", not apagado.emite_fuego_por_contacto())
	var toca := _goblin(Vector3(14.5 * S, MundoFalso.ALTO, 8.5 * S))
	var lejos := _goblin(Vector3(14.5 * S + 2.0 * S, MundoFalso.ALTO, 8.5 * S + 2.0 * S))
	_pasos(toca, 20)
	_pasos(lejos, 20)
	_ok("2b un goblin que toca un brasero encendido se prende", toca.esta_ardiendo())
	_ok("2b y el que está a 2 casillas, no", not lejos.esta_ardiendo())


func _goblin_prende_goblin() -> void:
	var a := _goblin(Vector3(4.5 * S, MundoFalso.ALTO, 16.5 * S))
	var b := _goblin(Vector3(4.5 * S + 0.5, MundoFalso.ALTO, 16.5 * S))      # tocándose (0,5 < 0,64)
	var c := _goblin(Vector3(4.5 * S + 2.0 * S, MundoFalso.ALTO, 16.5 * S))   # a 2 casillas
	a.quemando = 3.0
	_pasos(a, 20)
	_pasos(b, 20)
	_pasos(c, 20)
	_ok("2c un goblin ardiendo prende al goblin que toca", b.esta_ardiendo())
	_ok("2c y no al que está a 2 casillas", not c.esta_ardiendo())


func _caso_2_flecha() -> void:
	var pos_arquero := Vector3(2.5 * S, MundoFalso.ALTO, 17.5 * S)
	var hay_jugador_a := Vector3(2.5 * S + 7.0, MundoFalso.ALTO, 17.5 * S)
	# Control: sin ningún fuego en medio la flecha NO sale ardiendo.
	var arq0 := _goblin(pos_arquero, true)
	arq0.jugador.position = hay_jugador_a
	var r0: Dictionary = await _volar(arq0)
	_ok("2 control: sin fuego en el camino la flecha no arde", r0["vio_flecha"] and not r0["ardiendo"])
	arq0.queue_free()
	# Un brasero encendido en el camino: la flecha llega ardiendo.
	var brasero := _objeto("brasero", 2.5 + 7.0 / S / 2.0, 17.5)
	brasero.position = Vector3(2.5 * S + 3.5, MundoFalso.ALTO, 17.5 * S)
	brasero.encender_llama()
	var arq := _goblin(pos_arquero, true)
	arq.jugador.position = hay_jugador_a
	var quemados: Array = []
	arq.flecha_ardiente_impacta.connect(func(o: Node3D) -> void: quemados.append(o))
	var seto_cruzado := _objeto("seto", 2.5, 17.5)       # NO está en el camino: control de que no prende nada que no cruza
	seto_cruzado.position = Vector3(2.5 * S, MundoFalso.ALTO, 14.5 * S)
	var seto_camino := _objeto("seto", 2.5, 17.5)         # SÍ está en el camino, después del brasero
	seto_camino.position = Vector3(2.5 * S + 5.6, MundoFalso.ALTO, 17.5 * S)
	var r: Dictionary = await _volar(arq)
	_ok("2 una flecha que atraviesa un brasero encendido llega ardiendo", r["vio_flecha"] and r["ardiendo"])
	_ok("2 y su impacto aplica quema (señal flecha_ardiente_impacta)", quemados.size() == 1 and quemados[0] == arq.jugador, "impactos %d" % quemados.size())
	_ok("2 la flecha ardiendo prende el seto inflamable que cruza", _arde(seto_camino))
	_ok("2 y no el que no cruza", not _arde(seto_cruzado))
	# Un brasero APAGADO no vale: control de que es la llama, no el objeto.
	brasero.apagar_llama()
	seto_camino.queue_free()              # el seto que acaba de arder TAMBIÉN es fuego en el camino: se quita para aislar el brasero
	seto_cruzado.queue_free()
	await process_frame
	var arq2 := _goblin(pos_arquero, true)
	arq2.jugador.position = hay_jugador_a
	var r2: Dictionary = await _volar(arq2)
	_ok("2 con el brasero apagado la flecha no arde", r2["vio_flecha"] and not r2["ardiendo"])


## Suelta una flecha del arquero y la sigue hasta que llega. Devuelve si la vio y si en algún momento llevaba la marca `ardiendo`.
func _volar(arq: Combate3D) -> Dictionary:
	var antes: Array = _mundo.get_children()
	arq._soltar_flecha()
	var flecha: MeshInstance3D = null
	for n in _mundo.get_children():
		if not antes.has(n) and n is MeshInstance3D:
			flecha = n
	var ardio: bool = false
	var vio: bool = flecha != null
	var i: int = 0
	while flecha != null and is_instance_valid(flecha) and not flecha.is_queued_for_deletion() and i < 120:
		await process_frame
		i += 1
		if is_instance_valid(flecha) and flecha.has_meta("ardiendo"):
			ardio = true
	await process_frame
	return {"vio_flecha": vio, "ardiendo": ardio}
