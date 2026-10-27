extends "res://herramientas/escenario_base.gd"
## HUMEDAD QUE SE SECA Y ORILLA MOJADA (27/10; lote 3, cambio 1, y la idea de DK Bananza de ANALISIS de los .md de Nintendo).
##   1 · EstadosSuelo3D solo (sin mundo): «mojada» empapa en SUBE s, dura DURA s, se aclara en los últimos SECADO s y caduca avisando.
##       Dos aguas siguen helando mientras la casilla está mojada.
##   2 · Con la escena de agua de la Cueva (Mundo3D en el árbol): el reloj corre solo; un hechizo de agua en el suelo deja la casilla
##       mojada y a los DURA s está seca. `AguaSim3D.textura_mojado`: la orilla de la charca sale húmeda, el suelo lejos del agua seco,
##       y cuánto tarda en hacerse (la pide el suelo 8 veces por segundo).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_humedad.gd

const RUTA: String = "res://escenas/PruebaCuevaAgua.tscn"
const SUELO := Vector2i(12, 6)          ## pasillo bajo la charca B, lejos de cualquier agua (dos casillas)
const ORILLA := Vector2i(4, 5)          ## la fila de suelo justo al sur de la charca A (y 2–4)
const LEJOS := Vector2i(20, 7)          ## suelo a tres casillas de la charca C


func _escenario() -> void:
	_estados_solos()
	await cargar(RUTA, true)
	if maqueta == null:
		return
	await _con_mundo()


func _estados_solos() -> void:
	var e := EstadosSuelo3D.new()
	var c := Vector2i(3, 3)
	var avisos: Array = []
	e.cambio.connect(func(p: Vector2i, est: String, si: bool) -> void: avisos.append([p, est, si]))
	e.aplicar(c, "agua")
	_ok("1 el agua deja la casilla mojada", e.tiene(c, "mojada"))
	_ok("1 recién mojada aún no se ve oscura (empapa)", e.intensidad_vista(c, "mojada") < 0.05, "%.2f" % e.intensidad_vista(c, "mojada"))
	e.avanzar(float(EstadosSuelo3D.SUBE["mojada"]) + 0.05)
	_ok("1 tras SUBE s se ve mojada del todo", e.intensidad_vista(c, "mojada") > 0.99, "%.2f" % e.intensidad_vista(c, "mojada"))
	var dura: float = float(EstadosSuelo3D.DURA["mojada"])
	var secado: float = float(EstadosSuelo3D.SECADO["mojada"])
	e.avanzar(dura - secado - 1.0)
	_ok("1 antes del secado sigue entera", e.tiene(c, "mojada") and e.intensidad_vista(c, "mojada") > 0.99)
	e.avanzar(secado * 0.5 + 1.0)
	var v: float = e.intensidad_vista(c, "mojada")
	_ok("1 a mitad del secado se ve a medias y sigue mojada para las reglas", e.tiene(c, "mojada") and v > 0.2 and v < 0.8, "%.2f" % v)
	var c2 := Vector2i(5, 5)
	e.aplicar(c2, "agua")
	e.avanzar(5.0)
	e.aplicar(c2, "agua")
	_ok("1 dos aguas antes de secarse hielan", e.tiene(c2, "helada") and not e.tiene(c2, "mojada"))
	e.avanzar(secado)
	_ok("1 pasados DURA s se seca", not e.tiene(c, "mojada") and e.intensidad_vista(c, "mojada") == 0.0)
	_ok("1 y avisa de que se secó", avisos.has([c, "mojada", false]))
	_ok("1 la imagen ya no la pinta", e.imagen().get_pixelv(c).g < 0.01)


func _con_mundo() -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var e: EstadosSuelo3D = Terreno3D.estados
	_ok("2 hay Mundo3D en el árbol (el reloj)", Mundo3D.actual != null and Mundo3D.actual.is_inside_tree())
	_ok("2 el suelo de prueba está seco y lejos del agua", not e.tiene(SUELO, "mojada") and not Terreno3D.es_agua(SUELO))
	# El agua que aterriza en el suelo, como la deja el mundo (`Mundo3D.aplicar_accion`). No se lanza: en las pruebas `lanzar` quita la
	# gravedad y la flecha de agua se pierde en el aire sin tocar el suelo; jugando cae.
	Mundo3D.aplicar_accion(AccionElemental.nueva("agua", Terreno3D.centro_de(SUELO, 0.0)))
	var t0: float = reloj.t
	await avanzar(2)
	_ok("2 la casilla queda mojada", e.tiene(SUELO, "mojada"))
	await avanzar_s(float(EstadosSuelo3D.DURA["mojada"]) - 3.0 - (reloj.t - t0))
	_ok("2 a falta de 3 s sigue mojada", e.tiene(SUELO, "mojada"), "t = %.1f s" % (reloj.t - t0))
	await avanzar_s(4.0)
	_ok("2 el reloj del mundo la seca sola", not e.tiene(SUELO, "mojada"), "t = %.1f s" % (reloj.t - t0))

	# Orilla: la textura de la simulación.
	var t_us: int = Time.get_ticks_usec()
	var tex: ImageTexture = sim.textura_mojado()
	var coste_ms: float = float(Time.get_ticks_usec() - t_us) / 1000.0
	_ok("3 la simulación da la textura de suelo mojado", tex != null and tex.get_width() == sim.w)
	var img: Image = tex.get_image()
	var borde: float = 0.0
	for i in sim.call("_trozos", ORILLA):
		var k: int = int(i)
		borde = maxf(borde, img.get_pixel(k % sim.w, k / sim.w).r)
	var lejos: float = 0.0
	for i in sim.call("_trozos", LEJOS):
		var k2: int = int(i)
		lejos = maxf(lejos, img.get_pixel(k2 % sim.w, k2 / sim.w).r)
	_ok("3 la orilla de la charca sale húmeda", borde > 0.6, "%.2f" % borde)
	_ok("3 el suelo lejos del agua sale seco", lejos < 0.01, "%.2f" % lejos)
	_aviso("3 coste de textura_mojado (%d × %d trocitos)" % [sim.w, sim.h], "%.2f ms" % coste_ms)
	_ok("3 cuesta menos de 4 ms", coste_ms < 4.0, "%.2f ms" % coste_ms)
	await _hierba()


## 4 · HIERBA (27/10): el agua sobre hierba deja «mojada» oficial, HIERBA_MOJADA_S s, sin la tabla de transiciones (dos aguas no hielan).
## La escena de la Cueva no tiene hierba: se clasifica una casilla como hierba por un momento (`ReaccionesSuelo3D.clasificar`).
func _hierba() -> void:
	var e: EstadosSuelo3D = Terreno3D.estados
	var c := Vector2i(20, 6)
	var antes: Callable = ReaccionesSuelo3D.clasificar
	ReaccionesSuelo3D.clasificar = func(p: Vector2i) -> String: return "hierba" if p == c else String(antes.call(p)) if antes.is_valid() else "suelo"
	Mundo3D.aplicar_accion(AccionElemental.nueva("agua", Terreno3D.centro_de(c, 0.0)))
	_ok("4 el agua sobre hierba la deja «mojada»", e.tiene(c, "mojada"))
	_ok("4 con la duración de la hierba", absf(e.queda(c, "mojada") - ReaccionesSuelo3D.HIERBA_MOJADA_S) < 0.2, "%.1f s" % e.queda(c, "mojada"))
	Mundo3D.aplicar_accion(AccionElemental.nueva("agua", Terreno3D.centro_de(c, 0.0)))
	_ok("4 dos aguas sobre hierba no la hielan (la hierba no usa la tabla)", e.tiene(c, "mojada") and not e.tiene(c, "helada"))
	await avanzar_s(ReaccionesSuelo3D.HIERBA_MOJADA_S + 0.5)
	_ok("4 y se seca a su tiempo", not e.tiene(c, "mojada"))
	ReaccionesSuelo3D.clasificar = antes
