extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, TAREA H (31/10; enemigos/combate_3d.gd `iniciar_destello` / `_destello_pintar`, limo_visual_3d.gd, golem_3d.gd): el hit flash lleva el COLOR DEL ELEMENTO.
## Sobre la escena real del Bosque, con un guerrero quieto y --fixed-fps 30 (un fotograma = 1/30 s):
##   1 primer fotograma tras el hechizo: emisión BLANCA (T_FLASH_BLANCO); a los 0,1 s: el color del elemento aclarado un 35 % a energía ENERGIA_FLASH;
##   2 cada elemento (fuego, agua, rayo, hielo, tierra) su color, y todos distintos entre sí;
##   3 debilidad: ENERGIA_FLASH_DEBIL y dura ≥ 0,25 s; la resistencia (fuego) ya se apagó a los 0,22 s;
##   4 golpe F (sin elemento): blanco todo el rato y ≤ 0,2 s;
##   5 daño continuo (quemadura): sin fase blanca, tinte del elemento a ENERGIA_FLASH_CONTINUO;
##   6 al apagarse se restauran emission_enabled / emission / energía de cada material; el fundido final baja la energía;
##   7 con Sensacion3D.ACTIVA = false, o DESTELLO_GOLPE = 0: blanco de siempre / sin destello;
##   8 el limo: `flash_color` / `flash_fuerza` de su shader al golpe, y vuelta a 0;
##   9 el gólem: «Piedra» gris corto; con el núcleo expuesto, color del elemento.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_destello_elemento.gd

const ELEMENTOS: Array = ["fuego", "agua", "rayo", "hielo", "tierra"]
const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "rayo": "lightning", "hielo": "ice", "tierra": "earth", "viento": "wind"}
const RUTA_SALA_GOLEM: String = "res://escenas/PruebaSalaGolem.tscn"


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	await _caso_primer_color()
	await _caso_elementos()
	await _caso_debilidad()
	await _caso_golpe_f()
	await _caso_continuo()
	await _caso_restaura()
	await _caso_apagada()
	await _caso_limo()
	_limpiar()
	await _caso_golem()
	print("COMPROBACIONES: %d" % _comprobaciones)


func _runa(el: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % RUNAS[el]) as RuneData


func _guerrero(debil: String = "", resiste: String = "") -> Combate3D:
	var g: Combate3D = _goblin(Vector2i(9, 33))
	g.debil = debil
	g.resiste = resiste
	return g


func _mat(g: Combate3D) -> StandardMaterial3D:
	return g._materiales[0] as StandardMaterial3D


func _esperado(el: String) -> Color:
	return (Combate3D.COLORES[el] as Color).lerp(Color.WHITE, 0.35)


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _golpear(g: Combate3D, el: String) -> void:
	g.on_spell_hit(_runa(el), Vector3(-1, 0, 0))


# --- 1 · primer fotograma blanco, luego el color ----------------------------------------------------------------------
func _caso_primer_color() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_ok("1 los valores: T_FLASH_BLANCO 0,05 · ENERGIA_FLASH 1,4 · DESTELLO_DEBIL 0,28 · ENERGIA_FLASH_DEBIL 1,8", is_equal_approx(Combate3D.T_FLASH_BLANCO, 0.05)
		and is_equal_approx(Combate3D.ENERGIA_FLASH, 1.4) and is_equal_approx(Combate3D.DESTELLO_DEBIL, 0.28) and is_equal_approx(Combate3D.ENERGIA_FLASH_DEBIL, 1.8))
	_ok("1 el guerrero tiene materiales", g._materiales.size() >= 1 and _mat(g) != null)
	_golpear(g, "fuego")
	await avanzar(1)
	var m: StandardMaterial3D = _mat(g)
	_ok("1 primer fotograma: emisión BLANCA y activa", m.emission_enabled and _dist(m.emission, Color.WHITE) < 0.1, str(m.emission))
	await avanzar(2)
	_ok("1 a los 0,1 s: el color del fuego aclarado 35 %", m.emission_enabled and _dist(m.emission, _esperado("fuego")) < 0.1, "%s vs %s" % [str(m.emission), str(_esperado("fuego"))])
	_ok("1 ... a energía 1,4", absf(m.emission_energy_multiplier - 1.4) < 0.01, str(m.emission_energy_multiplier))
	_ok("1 ... y el albedo sigue negro (la textura no asoma)", m.albedo_color.r < 0.01 and m.albedo_color.g < 0.01 and m.albedo_color.b < 0.01, str(m.albedo_color))
	_limpiar()
	await avanzar(3)


# --- 2 · cada elemento su color -----------------------------------------------------------------------------------------
func _caso_elementos() -> void:
	_jugadora(Vector2i(11, 33))
	var vistos: Dictionary = {}
	for el in ELEMENTOS:
		var g: Combate3D = _guerrero()
		await avanzar(3)
		_golpear(g, el)
		await avanzar(3)
		var m: StandardMaterial3D = _mat(g)
		vistos[el] = m.emission
		_ok("2 %s: emisión de su color a los 0,1 s" % el, m.emission_enabled and _dist(m.emission, _esperado(el)) < 0.1 and absf(m.emission_energy_multiplier - 1.4) < 0.01, "%s vs %s" % [str(m.emission), str(_esperado(el))])
		_limpiar()
		await avanzar(3)
	var distintos: bool = true
	for a in ELEMENTOS:
		for b in ELEMENTOS:
			if a < b and _dist(vistos[a], vistos[b]) < 0.05:
				distintos = false
	_ok("2 cada elemento, un color distinto (fuego ≠ agua incluido)", distintos and _dist(vistos["fuego"], vistos["agua"]) > 0.2)


# --- 3 · debilidad y resistencia -----------------------------------------------------------------------------------------
func _caso_debilidad() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _guerrero("agua", "fuego")
	await avanzar(3)
	_golpear(g, "agua")
	await avanzar(3)
	var m: StandardMaterial3D = _mat(g)
	_ok("3 agua sobre débil: energía 1,8 y color del agua", absf(m.emission_energy_multiplier - 1.8) < 0.01 and _dist(m.emission, _esperado("agua")) < 0.1, "%.2f %s" % [m.emission_energy_multiplier, str(m.emission)])
	await avanzar(4)                                          # 0,23 s
	_ok("3 y a los 0,22 s sigue activo (dura 0,28 s)", g._destello > 0.0 and m.emission_enabled, "queda %.3f" % g._destello)
	await avanzar(4)
	_ok("3 y acaba", g._destello <= 0.0 and not g._flash_blanco)
	_limpiar()
	await avanzar(3)
	var r: Combate3D = _guerrero("agua", "fuego")
	await avanzar(3)
	_golpear(r, "fuego")
	await avanzar(7)                                          # 0,23 s
	_ok("3 fuego sobre resistente: a los 0,22 s ya se apagó", r._destello <= 0.0 and not r._flash_blanco and not _mat(r).emission_enabled)
	_limpiar()
	await avanzar(3)


# --- 4 · golpe F ---------------------------------------------------------------------------------------------------------
func _caso_golpe_f() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _guerrero()
	await avanzar(3)
	g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 0.0)
	var m: StandardMaterial3D = _mat(g)
	var siempre_blanco: bool = true
	var visto: bool = false
	var n: int = 0
	while g._destello > 0.0 or n == 0:
		await avanzar(1)
		n += 1
		if g._flash_blanco:
			visto = true
			if _dist(m.emission, Color.WHITE) > 0.1 or absf(m.emission_energy_multiplier - 1.0) > 0.01:
				siempre_blanco = false
		if n > 20:
			break
	_ok("4 golpe F: blanco puro todo el destello", visto and siempre_blanco)
	_ok("4 y dura ≤ 0,2 s (%d fotogramas)" % n, n <= 7 and g._destello <= 0.0, str(n))
	_limpiar()
	await avanzar(3)


# --- 5 · daño continuo ---------------------------------------------------------------------------------------------------
func _caso_continuo() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g, "fuego")
	await avanzar(10)                                         # acaba el destello del golpe
	_ok("5 ardiendo y sin destello antes del tick", g.quemando > 0.0 and g._destello <= 0.0)
	g._tick_fuego = 0.0
	await avanzar(1)                                          # el primer tick de `quemando`
	var m: StandardMaterial3D = _mat(g)
	_ok("5 quemadura: destello continuo, sin fase blanca", g._destello_continuo and g._flash_blanco and _dist(m.emission, Color.WHITE) > 0.1, str(m.emission))
	_ok("5 ... del tinte del fuego a energía 0,8", _dist(m.emission, _esperado("fuego")) < 0.1 and absf(m.emission_energy_multiplier - 0.8) < 0.01, "%s %.2f" % [str(m.emission), m.emission_energy_multiplier])
	_limpiar()
	await avanzar(3)


# --- 6 · restaurar -------------------------------------------------------------------------------------------------------
func _caso_restaura() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _guerrero("agua")
	await avanzar(3)
	var previo: Array = []
	for mm in g._materiales:
		var s: StandardMaterial3D = mm as StandardMaterial3D
		previo.append([s.emission_enabled, s.emission, s.emission_energy_multiplier] if s != null else null)
	_golpear(g, "agua")
	await avanzar(2)
	_ok("6 durante el destello hay emisión", _mat(g).emission_enabled)
	var energia_mitad: float = _mat(g).emission_energy_multiplier
	# el fundido: justo antes de acabar la energía va por debajo de la plena
	var baja: bool = false
	var n: int = 0
	while g._destello > 0.0 and n < 20:
		await avanzar(1)
		n += 1
		if g._destello > 0.0 and g._destello < Combate3D.T_FLASH_FUNDIDO and _mat(g).emission_energy_multiplier < Combate3D.ENERGIA_FLASH_DEBIL - 0.05:
			baja = true
	_ok("6 en los últimos 0,06 s la energía baja (%.2f antes)" % energia_mitad, baja)
	await avanzar(2)
	var igual: bool = true
	for i in range(g._materiales.size()):
		var s2: StandardMaterial3D = g._materiales[i] as StandardMaterial3D
		if s2 == null or previo[i] == null:
			continue
		var p: Array = previo[i]
		if s2.emission_enabled != bool(p[0]) or _dist(s2.emission, p[1]) > 0.001 or absf(s2.emission_energy_multiplier - float(p[2])) > 0.001:
			igual = false
	_ok("6 al apagarse se restauran emission_enabled, emission y energía de cada material", igual and not g._flash_blanco)
	_limpiar()
	await avanzar(3)


# --- 7 · apagada ---------------------------------------------------------------------------------------------------------
func _caso_apagada() -> void:
	_jugadora(Vector2i(11, 33))
	Sensacion3D.ACTIVA = false
	var g: Combate3D = _guerrero("agua")
	await avanzar(3)
	_golpear(g, "agua")
	var m: StandardMaterial3D = _mat(g)
	var blanco: bool = true
	var n: int = 0
	while g._destello > 0.0 and n < 20:
		await avanzar(1)
		n += 1
		if g._flash_blanco and (_dist(m.emission, Color.WHITE) > 0.1 or absf(m.emission_energy_multiplier - 1.0) > 0.01):
			blanco = false
	_ok("7 ACTIVA = false: blanco todo el destello", blanco and n >= 2, str(n))
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar(3)
	_jugadora(Vector2i(11, 33))
	var guardado: float = Combate3D.DESTELLO_GOLPE
	Combate3D.DESTELLO_GOLPE = 0.0
	var g2: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g2, "fuego")
	await avanzar(2)
	_ok("7 DESTELLO_GOLPE = 0: sin destello ni emisión", g2._destello <= 0.0 and not g2._flash_blanco and not _mat(g2).emission_enabled)
	Combate3D.DESTELLO_GOLPE = guardado
	_limpiar()
	await avanzar(3)


# --- 8 · limo ------------------------------------------------------------------------------------------------------------
func _caso_limo() -> void:
	_jugadora(Vector2i(11, 33))
	var l: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(13, 33)), "agua", false)
	l.quieto = true
	l.health = 100000.0
	l.vida_max = 100000.0
	_creados.append(l)
	await avanzar(3)
	var mat: ShaderMaterial = l.cuerpo.material_cuerpo
	_ok("8 el shader del limo tiene flash_color y flash_fuerza (en reposo, a 0)", mat.shader.code.contains("flash_color") and mat.shader.code.contains("flash_fuerza") and float(mat.get_shader_parameter("flash_fuerza")) <= 0.0)
	l.on_spell_hit(_runa("fuego"), Vector3(1, 0, 0))
	await avanzar(1)
	var c: Color = mat.get_shader_parameter("flash_color")
	_ok("8 golpeado con fuego: flash_color es el del fuego y flash_fuerza > 0", _dist(c, _esperado("fuego")) < 0.1 and float(mat.get_shader_parameter("flash_fuerza")) > 0.0, "%s %s" % [str(c), str(mat.get_shader_parameter("flash_fuerza"))])
	await avanzar_s(0.4)
	_ok("8 a los 0,4 s, flash_fuerza = 0", float(mat.get_shader_parameter("flash_fuerza")) <= 0.0, str(mat.get_shader_parameter("flash_fuerza")))
	l.cuerpo.golpe()
	await avanzar(1)
	_ok("8 `golpe()` sin argumentos sigue funcionando (blanco)", _dist(mat.get_shader_parameter("flash_color"), Color.WHITE) < 0.1 and float(mat.get_shader_parameter("flash_fuerza")) > 0.0)
	_limpiar()
	await avanzar(3)


# --- 9 · gólem -----------------------------------------------------------------------------------------------------------
func _caso_golem() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA_GOLEM, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	await avanzar(10)
	colocar_jugador(Vector2i(8, 6))
	var g: Golem3D = Golem3D.invocar_golem(maqueta, _pos(Vector2i(6, 6)), jugador as Jugador3D, lanzador)
	g.quieto = true
	_creados.append(g)
	await avanzar(3)
	_ok("9 el gólem tiene materiales", g._materiales.size() >= 1 and g._materiales[0] != null)
	g.recibir_golpe_cuerpo(Vector3(1, 0, 0), 5.0, 5000.0)                   # de pie: «Piedra»
	await avanzar(1)
	var m: StandardMaterial3D = g._materiales[0] as StandardMaterial3D
	_ok("9 «Piedra»: emisión gris", m.emission_enabled and _dist(m.emission, Combate3D.COLOR_FLASH_PIEDRA) < 0.1, str(m.emission))
	await avanzar(8)
	_ok("9 y se apaga (corto)", g._destello <= 0.0 and not g._flash_blanco)
	g.health = 5000.0
	g.vida_max = 5000.0
	g._exponer()
	while g._t_estado < AnimacionesGolem.T_EXPUESTO_ABAJO + 0.3:
		await process_frame
	_ok("9 núcleo expuesto: vulnerable", g.vulnerable())
	g.on_spell_hit(_runa("fuego"), Vector3(1, 0, 0))
	await avanzar(3)
	_ok("9 con el núcleo expuesto: color del elemento a energía 1,8 (siempre débil)", m.emission_enabled and _dist(m.emission, _esperado("fuego")) < 0.1 and absf(m.emission_energy_multiplier - 1.8) < 0.01,
		"%s %.2f" % [str(m.emission), m.emission_energy_multiplier])
	_limpiar()
