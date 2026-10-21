extends SceneTree
## A5 de docs/PLAN_EOW.md (21/10, Juego): EL ESCUDO DEL GOBLIN COMO COMPONENTE (`enemigos/escudo_3d.gd`).
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_escudo.gd
## Lo que comprueba (la mirada del goblin es +Z; un disparo «de frente» viaja hacia −Z):
##   1. Sin `equipar`, el goblin no tiene escudo y recibe todo igual que antes. `equipar` lo cuelga, es idempotente y trae los papeles `inflamable` y `bloquea_proyectiles`.
##   2. De frente: el disparo NO llega al goblin (su vida igual, sin estados), el escudo lo recibe y se emite `bloqueado` (una vez, con el nodo del escudo, de tipo «escudo»).
##   3. Por la espalda, por el lado y sin dirección, pasa. El cono (120° en total) es el que declara la constante: 50° de la mirada bloquea, 70° pasa.
##   4. Con fuego el escudo arde (`prendido`), no hay quemadura en el goblin, se consume en T_CONSUMO s (`consumido`) y después el disparo de frente SÍ llega.
##   5. Mojado no prende (vapor); el agua apaga el que arde; la tierra lo desgasta hasta romperlo (`consumido`, «roto»).
##   6. Si el GOBLIN arde (contacto de A2), el escudo arde con él y se consume.
##   7. Papeles retocados: `-bloquea_proyectiles` deja pasar todo; `-inflamable` bloquea pero no prende. Un goblin muerto no tiene escudo que valga.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 10

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fx: Vfx3D = null
var _fallos: int = 0
var _emitidas: Array = []        ## [nombre, punto, nodo] de cada Mundo3D.reaccion


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_equipar()
	_cono()
	_fuego()
	_zona_de_llamas()
	_agua_y_rotura()
	_contacto()
	_papeles()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.reaccion.connect(func(n: String, p: Vector3, nd: Node) -> void: _emitidas.append([n, p, nd]))
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 8.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


func _goblin(cx: int, cz: int) -> Combate3D:
	var p := Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(cx, cz)), (cz + 0.5) * S)
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(0, 0, 1)
	g.health = 100000.0
	g.vida_max = 100000.0
	return g


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


func _r(archivo: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % archivo)


## Un disparo del elemento `archivo` que viaja en `dir` (lo que haría el Lanzador3D por el contrato).
func _tiro(g: Combate3D, archivo: String, dir: Vector3) -> void:
	g.on_spell_hit(_r(archivo), dir, _h(archivo))


func _pasos(e: Node, segundos: float) -> void:
	var n: int = int(ceil(segundos / DT))
	for _i in range(n):
		e._physics_process(DT)


func _n(nombre: String, nodo: Node) -> int:
	var c: int = 0
	for e in _emitidas:
		if e[0] == nombre and e[2] == nodo:
			c += 1
	return c


# ---------------------------------------------------------------------------------------------------------------------

func _equipar() -> void:
	var g := _goblin(2, 2)
	_ok("1 sin equipar, el goblin no tiene escudo", g.escudo == null)
	var antes: float = g.health
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("1 y un disparo de frente le llega entero, como siempre", g.health < antes, str(antes - g.health))
	var e: Escudo3D = Escudo3D.equipar(g)
	_ok("1 equipar cuelga el escudo del Combate3D", e != null and g.escudo == e and e.get_parent() == g)
	_ok("1 equipar dos veces devuelve el mismo", Escudo3D.equipar(g) == e)
	_ok("1 papeles de serie: inflamable y bloquea_proyectiles", e.tiene_papel("inflamable") and e.tiene_papel("bloquea_proyectiles") and not e.tiene_papel("mojable"))
	_ok("1 su tipo es «escudo» para el Pipeline", ReaccionesVfx3D.tipo_de(e) == "escudo")
	_ok("1 tiene su malla entera y su malla quemada", e._entero != null and e._quemado != null and e._entero.visible and not e._quemado.visible)
	_ok("1 y está activo", e.esta_activo())
	# Está delante del cuerpo, hacia donde mira
	_ok("1 va por delante del cuerpo, hacia la mirada (+Z)", e.position.z > 0.2 and absf(e.position.x) < 0.01, str(e.position))
	# Un goblin vecino sin escudo sigue igual
	var otro := _goblin(5, 2)
	var a2: float = otro.health
	_tiro(otro, "earth", Vector3(0, 0, -1))
	_ok("1 un goblin vecino sin escudo no cambia", otro.escudo == null and otro.health < a2)


func _cono() -> void:
	_emitidas.clear()
	var g := _goblin(2, 4)
	var e: Escudo3D = Escudo3D.equipar(g)
	var v0: float = g.health
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("2 de frente: la vida del goblin no se mueve", g.health == v0, str(v0 - g.health))
	_ok("2 el escudo lo recibe: pierde vida y cuenta 1 bloqueo", e.vida < e.vida_max and e.bloqueos == 1, str(e.vida))
	_ok("2 se emite «bloqueado» una vez con el nodo del escudo", _n("bloqueado", e) == 1 and _n("bloqueado", g) == 0, str(_emitidas))
	var p: Vector3 = _emitidas[0][1] if not _emitidas.is_empty() else Vector3.INF
	_ok("2 y el punto del aviso está en el escudo, no lejos del goblin", p.distance_to(g.global_position) < 1.5, str(p))
	_ok("2 sin estado raro en el goblin (ni lento ni empujado)", g.lento <= 0.0 and g._empuje.length() < 0.01)
	_tiro(g, "water", Vector3(0, 0, -1))
	_ok("2 el agua de frente tampoco moja al goblin", g.mojado <= 0.0 and _n("bloqueado", e) == 2)

	_emitidas.clear()
	v0 = g.health
	_tiro(g, "earth", Vector3(0, 0, 1))
	_ok("3 por la espalda pasa: el goblin pierde vida", g.health < v0, str(v0 - g.health))
	_ok("3 y no se emite «bloqueado»", _n("bloqueado", e) == 0)
	v0 = g.health
	_tiro(g, "earth", Vector3(1, 0, 0))
	_tiro(g, "earth", Vector3(-1, 0, 0))
	_ok("3 de lado (90°) pasa por los dos costados", g.health < v0 and _n("bloqueado", e) == 0)
	v0 = g.health
	_tiro(g, "earth", Vector3.ZERO)
	_ok("3 sin dirección (una onda, el suelo) pasa", g.health < v0 and _n("bloqueado", e) == 0)
	v0 = g.health
	_tiro(g, "earth", Vector3(0, -1, 0))
	_ok("3 cenital (sin componente horizontal) pasa", g.health < v0 and _n("bloqueado", e) == 0)
	# El cono: a 50° de la mirada bloquea, a 70° pasa (el límite es ANGULO_CONO_FRONTAL / 2 = 60°)
	v0 = g.health
	var a50: float = deg_to_rad(50.0)
	_tiro(g, "earth", -Vector3(sin(a50), 0, cos(a50)))
	_ok("3 a 50° de la mirada, dentro del cono: bloquea", g.health == v0 and _n("bloqueado", e) == 1, str(_n("bloqueado", e)))
	var a70: float = deg_to_rad(70.0)
	_tiro(g, "earth", -Vector3(sin(a70), 0, cos(a70)))
	_ok("3 a 70°, fuera del cono: pasa", g.health < v0 and _n("bloqueado", e) == 1)
	_ok("3 el cono vale 120° en total", is_equal_approx(Escudo3D.ANGULO_CONO_FRONTAL, 120.0))
	# Si el goblin se gira, el cono se gira con él
	g.mirada = Vector3(1, 0, 0)
	v0 = g.health
	_tiro(g, "earth", Vector3(-1, 0, 0))
	_ok("3 si el goblin mira a +X, el disparo que viaja a −X ahora es de frente", g.health == v0)
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("3 y el que antes era de frente ahora es de lado y pasa", g.health < v0)
	_pasos(e, 0.1)
	_ok("3 el escudo se recoloca hacia la nueva mirada", e.position.x > 0.2 and absf(e.position.z) < 0.01, str(e.position))


func _fuego() -> void:
	_emitidas.clear()
	var g := _goblin(2, 6)
	var e: Escudo3D = Escudo3D.equipar(g)
	var v0: float = g.health
	_tiro(g, "fire", Vector3(0, 0, -1))
	_ok("4 fuego de frente: el goblin no pierde vida ni arde", g.health == v0 and g.quemando <= 0.0)
	_ok("4 el escudo arde y se emite «prendido» una vez", e.estado == "ardiendo" and e.esta_ardiendo() and _n("prendido", e) == 1, str(e.estado))
	_ok("4 «bloqueado» también se emitió", _n("bloqueado", e) == 1)
	_tiro(g, "fire", Vector3(0, 0, -1))
	_ok("4 más fuego sobre el que ya arde no repite «prendido» ni reinicia la cuenta", _n("prendido", e) == 1)
	_pasos(e, 1.5)
	_ok("4 a mitad de camino sigue ardiendo y sigue protegiendo", e.estado == "ardiendo" and e.esta_activo())
	v0 = g.health
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("4 ardiendo todavía para disparos de frente", g.health == v0)
	_pasos(e, Escudo3D.T_CONSUMO)
	_ok("4 pasado T_CONSUMO se consume: «consumido» una vez y estado quemado", e.estado == "quemado" and _n("consumido", e) == 1, str(e.estado))
	_ok("4 ya no está activo; la malla quemada sustituye a la entera", not e.esta_activo() and not e._entero.visible and e._quemado.visible)
	v0 = g.health
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("4 y el disparo de frente SÍ llega al goblin", g.health < v0, str(v0 - g.health))
	_ok("4 no hay más «bloqueado» tras consumirse", _n("bloqueado", e) == 3)
	_pasos(e, 1.0)


## El impacto de fuego que el escudo para deja su CAMPO DE LLAMAS (ZonaV2, plasma), y sus pulsos hieren por `receive_damage` sin pasar por `on_spell_hit`:
## el escudo ardiendo tenía que protegerle también de eso (bug del playtest 21/10: el goblin perdía 10 cada 0,25 s). Después de consumirse, el campo sí le hiere.
func _zona_de_llamas() -> void:
	var g := _goblin(8, 4)
	var e: Escudo3D = Escudo3D.equipar(g)
	var l := Lanzador3D.new()
	l.mundo = _mundo
	l.jugador = _jugador
	root.add_child(l)
	var z := Lanzador3D.ZonaV2.new()
	z.lanz = l
	z.rune = _r("fire")
	z.elemento = "fuego"
	z.dir = Vector3(0, 0, -1)                      # el disparo de frente (la mirada del goblin es +Z)
	z.celdas[Terreno3D.celda_de(g.position)] = true
	z.vida = 20.0
	z.intervalo = 0.25
	z.dano_periodico = 40.0                        # 10 por pulso, como el fuego del juego
	z.metodo_pulso = "pulso_plasma"
	z.tocados[g.get_instance_id()] = true          # el impacto que paró el escudo ya cuenta como «golpeado» (así nace la zona)
	z.set_physics_process(false)
	_tiro(g, "fire", Vector3(0, 0, -1))
	var v0: float = g.health
	_ok("4z el fuego de frente prende el escudo", e.esta_ardiendo())
	var t: float = 0.0
	while e.esta_ardiendo() and t < Escudo3D.T_CONSUMO + 1.0:
		z.avanzar(DT)
		_pasos(e, DT)
		t += DT
	_ok("4z durante los 3 s que arde el escudo, el campo de llamas NO hiere al goblin (ni lo prende)", g.health == v0 and g.quemando <= 0.0 and not g.esta_ardiendo(), "vida %.1f → %.1f en %.1f s" % [v0, g.health, t])
	_ok("4z el escudo se consumió a su hora", e.estado == "quemado" and not e.esta_activo(), str(e.estado))
	for _i in range(int(0.6 / DT)):
		z.avanzar(DT)
	_ok("4z después, con el escudo quemado, el campo SÍ le hiere (expuesto)", g.health < v0, "vida %.1f → %.1f" % [v0, g.health])
	# El mismo campo por la ESPALDA del escudo (el goblin mira al otro lado de lo que viaja el disparo): lo hiere aunque el escudo esté entero.
	var h := _goblin(8, 6)
	Escudo3D.equipar(h)
	z.celdas = {Terreno3D.celda_de(h.position): true}
	z.tocados[h.get_instance_id()] = true
	z.dir = Vector3(0, 0, 1)
	var vh: float = h.health
	z.avanzar(0.3)
	_ok("4z lo que viaja por la espalda del escudo sí hiere (solo cubre de frente)", h.health < vh, "vida %.1f → %.1f" % [vh, h.health])
	z.queue_free()
	l.queue_free()
	_ok("4 consumido solo una vez aunque pasen fotogramas", _n("consumido", e) == 1)


func _agua_y_rotura() -> void:
	_emitidas.clear()
	var g := _goblin(4, 6)
	var e: Escudo3D = Escudo3D.equipar(g)
	_tiro(g, "water", Vector3(0, 0, -1))
	_ok("5 el agua moja el escudo y se avisa «mojado»", e.mojado_t > 0.0 and _n("mojado", e) == 1)
	_tiro(g, "fire", Vector3(0, 0, -1))
	_ok("5 fuego sobre escudo mojado = vapor: no prende (y avisa «secado»)", e.estado == "entero" and _n("prendido", e) == 0 and _n("secado", e) == 1, str(e.estado))
	_tiro(g, "fire", Vector3(0, 0, -1))
	_ok("5 ya seco, el fuego sí lo prende", e.estado == "ardiendo" and _n("prendido", e) == 1)
	_tiro(g, "water", Vector3(0, 0, -1))
	_ok("5 el agua apaga el que arde: vuelve a entero y avisa «apagado_agua»", e.estado == "entero" and _n("apagado_agua", e) == 1, str(e.estado))
	_pasos(e, Escudo3D.T_CONSUMO + 1.0)
	_ok("5 apagado no se consume", e.estado == "entero" and _n("consumido", e) == 0)

	var h := _goblin(6, 6)
	var f: Escudo3D = Escudo3D.equipar(h)
	var v0: float = h.health
	var n: int = 0
	while f.estado == "entero" and n < 500:
		_tiro(h, "earth", Vector3(0, 0, -1))
		n += 1
	_ok("5 a golpes de tierra el escudo se rompe: «roto», «consumido» una vez, y el goblin no perdió nada", f.estado == "roto" and _n("consumido", f) == 1 and h.health == v0, "%d golpes · %s" % [n, f.estado])
	_ok("5 roto desaparece (ni la malla entera ni la quemada)", not f._entero.visible and not f._quemado.visible)
	_tiro(h, "earth", Vector3(0, 0, -1))
	_ok("5 y roto deja pasar", h.health < v0)


func _contacto() -> void:
	_emitidas.clear()
	var g := _goblin(2, 8)
	var e: Escudo3D = Escudo3D.equipar(g)
	_pasos(e, 0.5)
	_ok("6 sin fuego el escudo se queda entero", e.estado == "entero")
	g.prender_por_contacto()
	_ok("6 el goblin arde por contacto (A2)", g.esta_ardiendo())
	_pasos(e, 0.1)
	_ok("6 el escudo que lleva arde con él", e.estado == "ardiendo" and _n("prendido", e) == 1, str(e.estado))
	_pasos(e, Escudo3D.T_CONSUMO + 0.2)
	_ok("6 y se consume", e.estado == "quemado" and _n("consumido", e) == 1)

	# Un goblin mojado que "arde" por contacto no prende (puede_prender lo impide): el escudo tampoco.
	var m := _goblin(4, 8)
	var em: Escudo3D = Escudo3D.equipar(m)
	m.mojado = 5.0
	_ok("6 un goblin mojado no prende por contacto", not m.prender_por_contacto())
	_pasos(em, 0.5)
	_ok("6 y su escudo tampoco", em.estado == "entero")


func _papeles() -> void:
	_emitidas.clear()
	var g := _goblin(6, 8)
	var e: Escudo3D = Escudo3D.equipar(g)
	e.papeles = PackedStringArray(["-bloquea_proyectiles"])
	var v0: float = g.health
	_tiro(g, "earth", Vector3(0, 0, -1))
	_ok("7 con «-bloquea_proyectiles» el disparo de frente pasa", g.health < v0 and _n("bloqueado", e) == 0 and not e.esta_activo())
	e.papeles = PackedStringArray(["-inflamable"])
	v0 = g.health
	_tiro(g, "fire", Vector3(0, 0, -1))
	_ok("7 con «-inflamable» bloquea el fuego pero no arde", g.health == v0 and e.estado == "entero" and _n("bloqueado", e) == 1 and _n("prendido", e) == 0, str(e.estado))
	e.papeles = PackedStringArray(["+mojable", "bloquea_proyectiles"])
	_ok("7 los retoques sin signo y con «+» añaden", e.tiene_papel("mojable") and e.tiene_papel("bloquea_proyectiles"))

	var m := _goblin(8, 8)
	var em: Escudo3D = Escudo3D.equipar(m)
	m.receive_damage(m.health + 1.0)
	_ok("7 un goblin muerto: el escudo ya no está activo", m.muerto and not em.esta_activo())
	_pasos(em, 0.1)
	_ok("7 y se oculta", not em.visible)
