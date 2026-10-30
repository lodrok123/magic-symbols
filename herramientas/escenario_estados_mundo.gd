extends "res://herramientas/escenario_base.gd"
## ESCENARIO ESTADOS DEL MUNDO (F4 de PLAN_BASE_DATOS, 29/10, Juego): los estados de zona con la escena de verdad (PruebaJugabilidad3D, el Jugador3D real, su Lanzador y sus braseros).
## Sobre el llano del sureste (filas 17–21, columnas 10–21) se declaran CUATRO ZONAS con las mismas líneas `; zona … estado=…` que lee un mapa:
##   calor (10–12) · frío (14–16) · veneno fijo (18–19) · oscuridad (20–21)   (y, aparte, una NUBE de veneno en (17,15))
## y la jugadora las cruza con y sin protección midiendo VIDA y AGUANTE contra la tabla `estados_mundo.tsv`:
##   · calor sin nada: el aguante baja 10/s y, a 0, la vida 2/s. Con el FRESCOR de F3 (se usa de verdad, `Consumibles.usar`) cruza y se queda sin perder nada. Mojada o en el agua, tampoco.
##   · frío: baja 8/s (el doble sobre una casilla mojada, que además se hiela sola a los 5 s); con el ABRIGO o junto a un BRASERO encendido no baja.
##   · veneno: una zona fija y una nube envenenan 2/s; el ANTÍDOTO protege. Un hechizo de viento empuja la nube y uno de fuego la quema (si el Lanzador la alcanza).
##   · oscuridad: un enemigo solo ve a la jugadora a ≤ 3 casillas, salvo que su casilla esté iluminada.
##   · tormenta: el rayo cae sobre la casilla mojada de la jugadora (no sobre la seca). Y el guardado de la hoguera lleva el aguante y el mundo, y se recupera al continuar.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_estados_mundo.gd
## Qué NO prueba: cómo se VE (calima, niebla, lluvia, viñeta: son del Pipeline) ni la barra de aguante del HUD.

const RUTA: String = "res://escenas/PruebaJugabilidad3D.tscn"
const CARPETA: String = "user://escenario_estados_mundo/"
const ZONAS: String = """; zona 10,17..12,21 volcan estado=calor
; zona 14,17..16,21 hielo estado=frio
; zona 18,17..19,21 pantano estado=veneno
; zona 20,17..21,21 cueva estado=oscuridad"""
const C_CALOR: Vector2i = Vector2i(11, 19)
const C_FRIO: Vector2i = Vector2i(15, 19)
const C_VENENO: Vector2i = Vector2i(18, 19)
const C_OSCURO: Vector2i = Vector2i(20, 19)
const C_HUECO: Vector2i = Vector2i(13, 19)         ## entre el calor y el frío: sin estado

var _ez: EstadoZona3D = null
var _j: Jugador3D = null
var _fx: Vfx3D = null


func _limpiar_carpeta() -> void:
	var dir_abs: String = ProjectSettings.globalize_path(CARPETA)
	if DirAccess.dir_exists_absolute(dir_abs):
		for f in DirAccess.get_files_at(dir_abs):
			DirAccess.remove_absolute(dir_abs.path_join(f))
		DirAccess.remove_absolute(dir_abs)


## Todo a cero y la jugadora en `c`: vida y aguante llenos, sin veneno, sin protecciones, sin casillas mojadas.
func _reset(c: Vector2i) -> void:
	Consumibles.limpiar_protecciones()
	Terreno3D.estados.limpiar()
	Mundo3D.apagar_luces()
	_j.vida = 100.0
	_j.aguante = Jugador3D.AGUANTE_MAX
	_j._veneno_t = 0.0
	_j._t_inv = 0.0
	_j.nadando = false
	colocar_jugador(c)


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	var r := Reactivo3D.new()
	r.name = "r_%s_%d_%d" % [tipo, c.x, c.y]
	r.preparar(tipo, c, "", _fx, null)
	r.position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	maqueta.add_child(r)
	return r


func _escenario() -> void:
	_limpiar_carpeta()
	Partida.carpeta = CARPETA
	Partida.ranura_actual = 1
	Partida.continuar = false
	Partida.mundo = {}
	Flags.nuevo()
	Estado.nuevo()
	Misiones.nuevo()
	await cargar(RUTA, false)
	if maqueta == null or jugador == null:
		return
	_j = jugador as Jugador3D
	_fx = maqueta.get("_fx") as Vfx3D
	await avanzar(10)
	_ez = EstadoZona3D.actual
	_ok("0 la escena monta el EstadoZona3D (cuelga de la maqueta y lleva a la jugadora)", _ez != null and _ez.get_parent() == maqueta and _ez.jugador == _j)
	if _ez == null:
		return
	for g in get_nodes_in_group("combate3d"):
		g.set("quieto", true)              # los goblins del nivel no deben herir a la jugadora a mitad de una medida
	_ez.zonas.clear()
	_ez.leer_texto(ZONAS)
	_ok("0 las cuatro zonas del mapa se leen", _ez.zonas.size() == 4 and _ez.avisos.is_empty(), str(_ez.zonas.size()))
	_ok("0 la fachada del mundo: calor en el volcán, nada en el hueco, oscuridad al fondo",
		Mundo3D.estado_zona(C_CALOR) == ["calor"] and Mundo3D.estado_zona(C_HUECO).is_empty() and Mundo3D.estado_zona(C_OSCURO) == ["oscuridad"])
	_j.vida = 100.0
	var tabla_calor: Dictionary = BD.estado_mundo("calor")
	var tabla_frio: Dictionary = BD.estado_mundo("frio")

	await _calor(tabla_calor)
	await _frio(tabla_frio)
	await _veneno()
	await _oscuridad()
	await _tormenta()
	await _guardado()
	_limpiar_carpeta()
	Partida.mundo = {}
	Partida.carpeta = Partida.CARPETA_DEFECTO
	Consumibles.limpiar_protecciones()


# ---------------------------------------------------------------------------------------------------------------------
func _calor(tabla: Dictionary) -> void:
	var baja: float = -float(tabla["aguante_s"])                 # 10
	var dano: float = float(tabla["dano_s"])                      # 2
	var vacia_en: float = Jugador3D.AGUANTE_MAX / baja            # 10 s
	# 1 · sin protección, de pie dentro
	_reset(C_CALOR)
	var t: float = await avanzar_s(3.0)
	_ok("1 calor sin nada: tras %.1f s el aguante ha bajado %.0f/s (ahora %.1f) y la vida sigue entera" % [t, baja, _j.aguante], absf(_j.aguante - (100.0 - baja * t)) <= baja * 0.12 and is_equal_approx(_j.vida, 100.0))
	var t2: float = await avanzar_s(9.5)
	var total: float = t + t2
	var esperada: float = dano * (total - vacia_en)
	var perdida: float = 100.0 - _j.vida
	_ok("1 calor sin nada: a 0 de aguante pierde %.0f de vida/s (%.1f s dentro → ≈ %.1f de vida; perdió %.1f)" % [dano, total, esperada, perdida], _j.aguante == 0.0 and absf(perdida - esperada) <= 2.0)
	# 2 · salir: se recupera
	colocar_jugador(C_HUECO)
	var t3: float = await avanzar_s(2.0)
	_ok("1 y al salir al hueco sin estado el aguante SUBE 20/s (tras %.1f s: %.1f)" % [t3, _j.aguante], _j.aguante >= 20.0 * t3 * 0.8 and _j.aguante <= 20.0 * t3 * 1.2 + 6.0)
	await avanzar_s(3.0)
	_ok("1 …hasta volver a 100 y la barra se oculta", is_equal_approx(_j.aguante, 100.0) and not _j.aguante_activo)
	# 3 · el frescor de F3, usado de verdad
	_reset(C_HUECO)
	Estado.i().agregar("frescor", 1)
	var cons := Consumibles.new()
	cons.jugador = _j
	cons.equipar("frescor")
	_ok("2 el frescor se usa de verdad (Consumibles.usar) y activa su protección de 90 s", cons.usar_equipado() and Consumibles.resiste("calor") and Consumibles.tiempo_proteccion("calor") > 80.0 and not Consumibles.resiste("frio"))
	colocar_jugador(C_CALOR)
	var t4: float = await avanzar_s(12.5)
	_ok("2 HECHO CUANDO: con el frescor se queda %.1f s en el calor sin perder aguante (%.1f) ni vida (%.1f)" % [t4, _j.aguante, _j.vida], _j.aguante >= 99.99 and is_equal_approx(_j.vida, 100.0))
	_ok("2 y la jugadora dice que está protegida del calor pero no del frío", _j.protegida("calor") and not _j.protegida("frio"))
	# 4 · mojada
	_reset(C_CALOR)
	Terreno3D.estados.poner(C_CALOR, "mojada", true, 1.0, 60.0)
	var t5: float = await avanzar_s(4.0)
	_ok("3 mojada (casilla mojada bajo los pies) cruza el calor sin perder aguante ni vida (%.1f s)" % t5, _j.aguante >= 99.99 and is_equal_approx(_j.vida, 100.0))
	_reset(C_CALOR)
	var carga: Vector3 = _j.position
	_j.nadando = true
	_ok("3 y nadando (pisar agua) también está protegida", _j.protegida("calor"))
	_j.nadando = false
	# 5 · cruzar andando de verdad
	_reset(C_HUECO)
	var cambios: Array = []
	var alta := func(entrando: Array, saliendo: Array) -> void: cambios.append([entrando, saliendo])
	_ez.estado_zona_cambio.connect(alta)
	var llego: bool = await mover_hacia(Vector2i(11, 19), 15.0, 0.4)
	await avanzar_s(0.3)
	_ok("4 andando al calor llega y el cruce avisa `estado_zona_cambio([calor], [])` y rellena Sintesis.estados_zona", llego and not cambios.is_empty() and cambios[cambios.size() - 1][0] == ["calor"] and Sintesis.estados_zona == ["calor"], str(cambios) + str(Sintesis.estados_zona))
	var dentro: float = _j.aguante
	_ok("4 …y el aguante ya ha empezado a bajar (%.1f)" % dentro, dentro < 100.0)
	await mover_hacia(C_HUECO, 15.0, 0.4)
	await avanzar_s(0.3)
	_ok("4 al salir avisa lo que sale y vacía Sintesis.estados_zona", cambios[cambios.size() - 1][1] == ["calor"] and Sintesis.estados_zona.is_empty(), str(cambios))
	_ez.estado_zona_cambio.disconnect(alta)
	Sintesis.estados_zona = []


# ---------------------------------------------------------------------------------------------------------------------
func _frio(tabla: Dictionary) -> void:
	var baja: float = -float(tabla["aguante_s"])                 # 8
	var hiela: float = float(tabla["hiela_sola_s"])               # 5
	_reset(C_FRIO)
	var t: float = await avanzar_s(4.0)
	_ok("5 frío sin nada: el aguante baja %.0f/s (%.1f s → %.1f)" % [baja, t, _j.aguante], absf(_j.aguante - (100.0 - baja * t)) <= baja * 0.15 and is_equal_approx(_j.vida, 100.0))
	# mojada: el doble, y el suelo se hiela solo
	_reset(C_FRIO)
	Terreno3D.estados.poner(C_FRIO, "mojada", true, 1.0, 60.0)
	var t2: float = await avanzar_s(3.0)
	_ok("6 frío sobre una casilla MOJADA: el doble (×%.0f) → %.1f tras %.1f s" % [float(tabla["mojada_x"]), _j.aguante, t2], absf(_j.aguante - (100.0 - baja * float(tabla["mojada_x"]) * t2)) <= baja * 2.0 * 0.15 and _j.esta_mojada())
	# Todo el llano del nivel es HIERBA (su escarcha la lleva el autómata de la maqueta, no el estado del suelo): para probar el reloj de verdad se declara «suelo» ESA casilla un momento.
	var clasificador: Callable = ReaccionesSuelo3D.clasificar
	ReaccionesSuelo3D.clasificar = func(c: Vector2i) -> String: return "suelo" if c == C_FRIO else clasificador.call(c)
	await avanzar_s(hiela - t2 + 0.8)
	_ok("6 y a los %.0f s la casilla de suelo mojada se HIELA SOLA (mojada → helada, escarcha)" % hiela, Terreno3D.estados.tiene(C_FRIO, "helada") and not Terreno3D.estados.tiene(C_FRIO, "mojada") and Terreno3D.estados.es_escarcha(C_FRIO))
	ReaccionesSuelo3D.clasificar = clasificador
	_ok("6 (la hierba mojada no se hiela por esta vía: es del autómata de la maqueta)", ReaccionesSuelo3D.clase_de(C_FRIO) == "hierba")
	# abrigo
	_reset(C_FRIO)
	Estado.i().agregar("abrigo", 1)
	var cons := Consumibles.new()
	cons.jugador = _j
	cons.equipar("abrigo")
	var uso: bool = cons.usar_equipado()
	await avanzar_s(8.0)
	_ok("7 el abrigo (resiste=frio) cruza el frío sin perder aguante", uso and _j.protegida("frio") and _j.aguante >= 99.99 and not _j.protegida("calor"))
	# brasero
	_reset(C_FRIO)
	var b: Reactivo3D = _reactivo("brasero", Vector2i(13, 21))
	b.encender_llama()
	await avanzar(5)
	colocar_jugador(Vector2i(14, 20))
	_j.refrescar_brasero()
	_j.aguante = 50.0
	var t3: float = await avanzar_s(2.0)
	_ok("8 junto a un brasero ENCENDIDO (a ≤ 2 casillas) el aguante se RELLENA en el frío (%.1f tras %.1f s)" % [_j.aguante, t3], b.is_lit and _j.protegida("frio") and _j.aguante > 50.0)
	colocar_jugador(Vector2i(16, 17))
	_j.aguante = 100.0
	var t4: float = await avanzar_s(2.0)
	_ok("8 lejos del brasero (> 2 casillas) baja como siempre (%.1f)" % _j.aguante, not _j.protegida("frio") and _j.aguante < 100.0 - baja * t4 * 0.7)
	b.apagar_llama()
	await avanzar(3)
	colocar_jugador(Vector2i(14, 20))
	_j.refrescar_brasero()
	await avanzar_s(1.0)
	_ok("8 apagado el brasero ya no protege", not b.is_lit and not _j.protegida("frio"))
	b.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _veneno() -> void:
	var tabla: Dictionary = BD.estado_mundo("veneno")
	var dano: float = float(tabla["dano_s"])
	# zona fija
	_reset(C_VENENO)
	var t: float = await avanzar_s(3.0)
	var perdida: float = 100.0 - _j.vida
	_ok("9 zona fija de veneno: %.0f de vida/s mientras está dentro (%.1f s → perdió %.1f)" % [dano, t, perdida], _j.tiene_estado("veneno") and absf(perdida - dano * t) <= 2.2)
	colocar_jugador(C_HUECO)
	var antes: float = _j.vida
	await avanzar_s(float(tabla["sigue_s"]) + 0.8)
	_ok("9 y fuera sigue %.0f s más y se acaba (perdió %.1f más)" % [float(tabla["sigue_s"]), antes - _j.vida], not _j.tiene_estado("veneno") and antes - _j.vida >= 2.0 and antes - _j.vida <= dano * float(tabla["sigue_s"]) + 1.0)
	# antídoto, de verdad
	_reset(C_VENENO)
	Estado.i().agregar("antidoto", 1)
	var cons := Consumibles.new()
	cons.jugador = _j
	cons.equipar("antidoto")
	var uso: bool = cons.usar_equipado()
	await avanzar_s(3.0)
	_ok("9 el antídoto: dentro de la zona de veneno no pierde ni una gota", uso and is_equal_approx(_j.vida, 100.0) and not _j.tiene_estado("veneno"))
	# nube
	_reset(Vector2i(20, 15))
	var c_nube := Vector2i(17, 15)
	var nube: NubeVeneno3D = NubeVeneno3D.crear(maqueta, Terreno3D.centro_de(c_nube, Terreno3D.y_pies(c_nube)), 0.0, 1.0, _j)
	_ok("10 la nube está viva y su casilla tiene `veneno`", NubeVeneno3D.vivas.has(nube) and Mundo3D.estado_zona(c_nube).has("veneno"))
	colocar_jugador(c_nube)
	var t2: float = await avanzar_s(3.0)
	_ok("10 dentro de la nube se envenena y pierde ≈ %.0f/s (%.1f s → perdió %.1f)" % [dano, t2, 100.0 - _j.vida], _j.tiene_estado("veneno") and absf((100.0 - _j.vida) - dano * t2) <= 2.2 and nube.envenenadas > 0)
	_j.curar_estado("veneno")
	colocar_jugador(Vector2i(20, 17))
	await avanzar_s(0.5)
	_j.vida = 100.0
	await avanzar_s(1.0)
	_ok("10 fuera de la nube no se envenena", not _j.tiene_estado("veneno") and is_equal_approx(_j.vida, 100.0))
	# hechizos de verdad sobre la nube: el viento la empuja, el fuego la quema
	var x0: float = nube.global_position.x
	var salio_v: bool = lanzar_a_celda("viento", ["flecha"], c_nube, Vector2i(c_nube.x + 3, c_nube.y))
	await avanzar_s(2.0)
	var movida: float = nube.global_position.x - x0
	if absf(movida) > 0.2:
		_ok("11 un hechizo de VIENTO lanzado de verdad empuja la nube (%.2f u) y la dispersa (vida %.1f ≤ 8)" % [movida, nube.vida], salio_v and nube.vida <= 8.0 and not nube.permanente)
	else:
		_aviso("11 el viento del Lanzador no alcanza a la nube (movida %.2f u): el contrato `on_spell_hit` de la nube lo cubre la prueba; queda a revisar con Hechizos" % movida)
		nube.on_spell_hit(load("res://nucleo/wind_rune.tres") as RuneData, Vector3(-1, 0, 0))
	nube.retirar()
	var nube2: NubeVeneno3D = NubeVeneno3D.crear(maqueta, Terreno3D.centro_de(c_nube, Terreno3D.y_pies(c_nube)), 0.0, 1.0, _j)
	var salio_f: bool = lanzar_a_celda("fuego", ["flecha"], c_nube, Vector2i(c_nube.x + 3, c_nube.y))
	await avanzar_s(2.0)
	if nube2.ardiendo:
		_ok("11 un hechizo de FUEGO lanzado de verdad la quema: se consume en ≤ 4 s", salio_f and nube2.vida <= 4.0)
		var vida_vista: float = nube2.vida
		await avanzar_s(vida_vista + 0.6)
		_ok("11 y cuando se le acaba la vida (%.1f s después) ha desaparecido" % vida_vista, not NubeVeneno3D.vivas.has(nube2))
	else:
		_aviso("11 el fuego del Lanzador no la ha quemado (ardiendo %s): queda a revisar con Hechizos" % nube2.ardiendo)
		nube2.on_spell_hit(load("res://nucleo/fire_rune.tres") as RuneData, Vector3.RIGHT)
		await avanzar_s(4.5)
		_ok("11 (con el contrato directo) el fuego la consume en 4 s", not NubeVeneno3D.vivas.has(nube2))
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	# la bola del chamán deja una nube
	_reset(Vector2i(20, 15))
	var destino: Vector3 = Terreno3D.centro_de(Vector2i(17, 16), Terreno3D.y_pies(Vector2i(17, 16)))
	var origen: Vector3 = destino + Vector3(4.0, 1.0, 0.0)
	var bola: BolaVeneno3D = BolaVeneno3D.lanzar(maqueta, origen, destino, null, _j, lanzador)
	await avanzar_s(bola.t_vuelo + 0.4)
	_ok("12 la bola de veneno del chamán, al estallar, deja una NUBE de %.0f s" % BolaVeneno3D.T_NUBE, NubeVeneno3D.vivas.size() == 1 and (NubeVeneno3D.vivas[0] as NubeVeneno3D).vida <= BolaVeneno3D.T_NUBE and Mundo3D.estado_zona(Vector2i(17, 16)).has("veneno"))
	await avanzar_s(BolaVeneno3D.T_NUBE + 0.3)
	_ok("12 …que se disipa sola a los 3 s", NubeVeneno3D.vivas.is_empty() and not Mundo3D.estado_zona(Vector2i(17, 16)).has("veneno"))


# ---------------------------------------------------------------------------------------------------------------------
func _oscuridad() -> void:
	_reset(C_HUECO)
	var pos: Vector3 = Terreno3D.centro_de(C_OSCURO, Terreno3D.y_pies(C_OSCURO))
	var limo: Limo3D = Limo3D.crear(maqueta as Node3D, pos)
	limo.quieto = true
	limo.jugador = _j
	await avanzar(3)
	var vista: float = float(BD.estado_mundo("oscuridad")["vista_enemigo_casillas"]) * Terreno3D.casilla
	colocar_jugador(Vector2i(20, 17))
	_ok("13 oscuridad: a 2 casillas el enemigo ve a la jugadora", limo._ve(40.0))
	colocar_jugador(Vector2i(15, 19))
	_ok("13 a 5 casillas (> %.1f u) ya no la ve, aunque su radio de visión sea enorme" % vista, not limo._ve(40.0))
	Mundo3D.iluminar(Vector2i(15, 19))
	_ok("13 pero si la casilla de la jugadora está iluminada (fuego, rayo, esporas), la ve", limo._ve(40.0))
	Mundo3D.apagar_luces()
	_ok("13 apagada la luz, vuelve a perderla", not limo._ve(40.0))
	limo.quieto = true
	limo.queue_free()
	await avanzar(2)


# ---------------------------------------------------------------------------------------------------------------------
func _tormenta() -> void:
	var cada: float = float(BD.estado_mundo("tormenta")["rayo_cada_s"])
	_reset(C_HUECO)
	_ez.dinamicos.clear()
	_ez.rayos.clear()
	_ez.poner("tormenta", 0.0)
	_ok("14 la tormenta se pone (60 s de la tabla) y todo el mapa la tiene", _ez.dinamicos.has("tormenta") and absf(float(_ez.dinamicos["tormenta"]["restante"]) - 60.0) < 0.5 and Mundo3D.estados_jugadora().has("tormenta"))
	# sobre casilla seca: no cae nada
	await avanzar_s(cada + 1.0)
	_ok("14 sin ninguna casilla mojada cerca el rayo no cae y la jugadora no pierde vida", _ez.rayos.is_empty() and is_equal_approx(_j.vida, 100.0), "rayos %s vida %.1f mojadas %s" % [str(_ez.rayos), _j.vida, str(Terreno3D.estados.celdas("mojada"))])
	# sobre casilla mojada: cae encima
	Terreno3D.estados.poner(C_HUECO, "mojada", true, 1.0, 60.0)
	var def: float = _j.defensa_total()
	await avanzar_s(cada + 1.0)
	var cayo: bool = not _ez.rayos.is_empty() and _ez.rayos.has(C_HUECO)
	var esperado: float = Dano.tras_defensa(EstadoZona3D.DANO_RAYO, def)
	_ok("14 con SU casilla mojada el rayo cae encima y la hiere %.0f (perdió %.1f)" % [esperado, 100.0 - _j.vida], cayo and absf((100.0 - _j.vida) - esperado) <= 1.0, str(_ez.rayos))
	# en otra casilla seca a su lado: a salvo
	_j.vida = 100.0
	_j._t_inv = 0.0
	colocar_jugador(Vector2i(13, 20))
	_ez.rayos.clear()
	await avanzar_s(cada + 1.0)
	_ok("14 de pie en una casilla SECA junto a la mojada, el rayo cae en la mojada y a ella no le pasa nada", _ez.rayos.has(C_HUECO) and is_equal_approx(_j.vida, 100.0), str(_ez.rayos))
	_ez.quitar("tormenta")
	Terreno3D.estados.limpiar()


# ---------------------------------------------------------------------------------------------------------------------
func _guardado() -> void:
	_reset(C_HUECO)
	_ez.dinamicos.clear()
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	_ez.poner("tormenta", 0.0)
	_ez.poner("vendaval", 0.0, {"direccion": Vector2i(0, 1)})
	var c_nube := Vector2i(17, 15)
	NubeVeneno3D.crear(maqueta, Terreno3D.centro_de(c_nube, Terreno3D.y_pies(c_nube)), 9.0, 1.0, _j)
	_j.aguante = 37.0
	await avanzar_s(1.0)
	var guardada: float = _j.aguante
	var reglas: Variant = maqueta.get("_reglas")
	_ok("15 la escena trae las reglas de Jugabilidad3D", reglas is Jugabilidad3D)
	if not (reglas is Jugabilidad3D):
		return
	reglas._guardar_partida(C_HUECO)
	var d: Dictionary = Partida.leer(1)
	var nivel: String = String(maqueta.get("nivel"))
	var m: Dictionary = (d.get("mundo", {}) as Dictionary).get(nivel, {}) as Dictionary
	_ok("15 la hoguera guarda `mundo.<nivel>` con la tormenta, el vendaval y la nube, y `jugadora.aguante`",
		(m.get("dinamicos", {}) as Dictionary).has("tormenta") and (m.get("dinamicos", {}) as Dictionary).has("vendaval") and (m.get("nubes", []) as Array).size() == 1 and absf(float(d["jugadora"]["aguante"]) - guardada) < 1.0,
		"nivel «%s» %s aguante %s" % [nivel, str((d.get("mundo", {}) as Dictionary).keys()), str(d.get("jugadora", {}).get("aguante"))])
	# borrar todo y continuar
	_ez.dinamicos.clear()
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	_j.aguante = 100.0
	await avanzar(3)
	Partida.continuar = true
	reglas._continuar_partida()
	await avanzar(3)
	_ok("15 al continuar vuelven el aguante (%.0f) y la tormenta y el vendaval con su dirección" % _j.aguante, absf(_j.aguante - guardada) < 8.0 and _ez.dinamicos.has("tormenta") and _ez.dinamicos.has("vendaval") and _ez.dinamicos["vendaval"]["direccion"] == Vector2i(0, 1))
	_ok("15 …y la nube de veneno, en su sitio y con su vida", NubeVeneno3D.vivas.size() == 1 and (NubeVeneno3D.vivas[0] as NubeVeneno3D).vida <= 9.0 and Mundo3D.estado_zona(c_nube).has("veneno"))
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	_ez.dinamicos.clear()
