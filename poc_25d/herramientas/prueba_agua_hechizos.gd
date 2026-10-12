extends SceneTree
## Hechizos sobre el agua (11.4) y surtidor con física (11.5), sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://poc_25d/herramientas/prueba_agua_hechizos.gd
## Termina con «FALLOS: n». Usa una maqueta falsa con lo mínimo que lee Lanzador3D.

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _mundo(mapa: PackedStringArray) -> MundoFalso:
	var m := MundoFalso.new()
	m._mapa = mapa
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if mapa[y][x] == "#" or mapa[y][x] == "u":
				m._bloqueadas[Vector2i(x, y)] = true
	return m


func _correr(sim: AguaSim3D, seg: float) -> void:
	for _i in range(int(seg * 60.0)):
		sim.paso(1.0 / 60.0)


func _initialize() -> void:
	await process_frame
	await _hechizos()
	await _surtidor(false)
	await _surtidor(true)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _hechizos() -> void:
	var m := _mundo(["######", "#....#", "#....#", "#....#", "#....#", "######"])
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	var p: Vector3 = Lanzador3D.centro_de(Vector2i(2, 2))
	Lanzador3D.hechizo_sobre_agua("agua", p)
	_ok("1 el agua echa 1,2 u³", absf(sim.volumen_total() - Lanzador3D.VOL_AGUA_IMPACTO) < 0.01, "%.3f" % sim.volumen_total())
	_correr(sim, 0.5)
	var v0: float = sim.volumen_total()
	Lanzador3D.hechizo_sobre_agua("fuego", p)
	_ok("1 el fuego evapora", sim.volumen_total() < v0 - 0.2, "%.3f -> %.3f" % [v0, sim.volumen_total()])
	var v1: float = sim.volumen_total()
	Lanzador3D.hechizo_sobre_agua("viento", p)
	Lanzador3D.hechizo_sobre_agua("tierra", p)
	_ok("1 viento y tierra no tocan el agua", absf(sim.volumen_total() - v1) < 1.0e-6)
	# Hielo (11.12/11.13): hiela los trocitos con agua del círculo; el detalle está en prueba_hielo.gd.
	sim.anadir(p, 6.0, 1.4)
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_ok("2 el hielo para el agua de la casilla", sim.casilla_helada(Vector2i(2, 2)) and m._helada.has(Vector2i(2, 2)))
	# Una casilla con tierra encima no recibe nada (H4).
	Lanzador3D.fijar_altura(Vector2i(3, 3), 1)
	var v2: float = sim.volumen_total()
	Lanzador3D.hechizo_sobre_agua("agua", Lanzador3D.centro_de(Vector2i(3, 3)))
	_ok("2 con tierra encima no echa agua", absf(sim.volumen_total() - v2) < 1.0e-6)
	# La tierra hace de presa: refrescar_casilla la cierra, y al quitarla se abre.
	sim.refrescar_casilla(Vector2i(3, 3))
	_ok("3 la tierra cierra la casilla (presa)", sim.cerrado[sim._trozos(Vector2i(3, 3))[0]] == 1)
	Lanzador3D.fijar_altura(Vector2i(3, 3), 0)
	sim.refrescar_casilla(Vector2i(3, 3))
	_ok("3 al caducar se abre", sim.cerrado[sim._trozos(Vector2i(3, 3))[0]] == 0)
	# Chorro: manantial mientras dura, y se retira.
	var sim2: AguaSim3D = Lanzador3D.montar_agua_sim()
	var c := Vector2i(1, 2)
	Lanzador3D.abrir_caudal(c, 1.0, 2.0)
	_correr(sim2, 1.5)
	var v_durante: float = sim2.volumen_total()
	await create_timer(2.2).timeout            # el temporizador es de tiempo real
	var f: float = 0.0
	for i in sim2._trozos(c):
		f += sim2.fuente[i]
	_ok("4 el chorro echa caudal mientras dura", v_durante > 1.0, "%.2f u³ tras 1,5 s" % v_durante)
	_ok("4 y lo retira al acabar", absf(f) < 1.0e-6, "fuente %.6f" % f)
	# Suma a un río: la fuente de la casilla no se pisa.
	sim2.fuente_en(Vector2i(2, 2), 2.0)
	Lanzador3D.abrir_caudal(Vector2i(2, 2), 1.0, 0.2)
	var f2: float = 0.0
	for i in sim2._trozos(Vector2i(2, 2)):
		f2 += sim2.fuente[i]
	_ok("4 se suma a un manantial que ya corría", absf(f2 - 3.0) < 1.0e-4, "%.3f" % f2)
	await create_timer(0.4).timeout
	f2 = 0.0
	for i in sim2._trozos(Vector2i(2, 2)):
		f2 += sim2.fuente[i]
	_ok("4 y al acabar queda el suyo", absf(f2 - 2.0) < 1.0e-4, "%.3f" % f2)
	m.queue_free()


## Un cauce «c» sellado con un surtidor «u»; con o sin río «~» en el borde.
func _surtidor(con_rio: bool) -> void:
	var mapa: PackedStringArray = ["######", "#uccc~" if con_rio else "#uccc#", "######", "######", "######", "######"]
	var m := _mundo(mapa)
	var sim: AguaSim3D = Lanzador3D.montar_agua_sim()
	var rot: String = "con río" if con_rio else "sin río"
	_correr(sim, 3.0)
	var cerrados: bool = true
	for x in range(2, 5):
		cerrados = cerrados and not sim.es_agua_casilla(Vector2i(x, 1)) and sim.profundidad_casilla(Vector2i(x, 1)) == 0.0
	_ok("5 (%s) el cauce seco está sellado: el río no se mete solo" % rot, cerrados)
	var s := Surtidor3D.new()
	s.preparar(m, Vector2i(1, 1))
	root.add_child(s)
	await process_frame
	_ok("5 (%s) encuentra 3 casillas de cauce" % rot, s.cauce.size() == 3)
	var rune := RuneData.new()
	rune.tags.append("agua")
	s.on_spell_hit(rune)
	var t: float = 0.0
	var t_primera: float = -1.0
	var t_ultima: float = -1.0
	while t < 30.0 and not (s._sim == null and s.esta_lleno):
		await physics_frame
		sim.paso(1.0 / 60.0)
		t += 1.0 / 60.0
		if t_primera < 0.0 and s._convertidas.size() >= 1:
			t_primera = t
		if t_ultima < 0.0 and s._convertidas.size() >= 3:
			t_ultima = t
	var letras: bool = true
	for x in range(2, 5):
		letras = letras and m._letra(Vector2i(x, 1)) == "~"
	_ok("6 (%s) las 3 casillas pasan a «~» corriendo el agua" % rot, letras, "primera %.1f s, última %.1f s" % [t_primera, t_ultima])
	_ok("6 (%s) no se llena de golpe: la última llega después de la primera" % rot, t_ultima > t_primera + 0.2 or con_rio, "")
	_correr(sim, 8.0)                       # el agua se reparte sola tras cerrar el grifo
	var prof: float = sim.profundidad_casilla(Vector2i(4, 1))
	_ok("6 (%s) tras repartirse, es agua y se nada en todo el cauce" % rot,
		Lanzador3D.es_agua(Vector2i(4, 1)) and sim.se_nada_en(Vector2i(2, 1)) and sim.se_nada_en(Vector2i(3, 1)) and sim.se_nada_en(Vector2i(4, 1)),
		"prof %.2f / %.2f / %.2f" % [sim.profundidad_casilla(Vector2i(2, 1)), sim.profundidad_casilla(Vector2i(3, 1)), prof])
	var f: float = 0.0
	for i in sim._trozos(Vector2i(2, 1)):
		f += sim.fuente[i]
	_ok("6 (%s) el grifo se cierra al llenarse" % rot, absf(f) < 1.0e-6, "fuente %.4f" % f)
	var maxp: float = 0.0
	for x in range(2, 5):
		maxp = maxf(maxp, sim.profundidad_casilla(Vector2i(x, 1)))
	_ok("6 (%s) no se desborda" % rot, maxp < Lanzador3D.LECHO_AGUA + 0.35, "máx %.2f" % maxp)
	s.queue_free()
	m.queue_free()
