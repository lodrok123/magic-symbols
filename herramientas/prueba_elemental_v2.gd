extends SceneTree
## 6/11 (Juego, Pablo: «El elemental»): EL ELEMENTAL DE BOSQUE V2. Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_elemental_v2.gd
## Una sección por regla (los números son los de las constantes ELEM_* de Combate3D):
##   1. Raíces bajo la jugadora: salen con ella a más de 8 u y no a menos; aviso de 1 s; si sigue dentro la sujetan 1,5 s y le hacen daño; si se aparta, no; recarga 7 s; él sigue avanzando;
##      la jugadora enraizada no anda (con el `_process` real de Jugador3D) pero sí podría lanzar.
##   2. Enfurecido mientras arde: ×1,3 de velocidad, descanso ×0,7, su puñetazo prende casillas; se acaba con la quemadura.
##   3. Agua + hielo: hielo tras el agua (< 5 s) congela 4 s; sin agua o pasados 5 s, solo lo que dice la runa (1,5 s); congelado no actúa.
##   4. Corteza delantera: de frente DEF 6; por la espalda DEF 0 y ×1,5; ᚦ perforar ignora la DEF desde cualquier lado; sin dirección = de frente; el golpe F también.
##   5. Tirantes: uno por enredadera VIVA, que se va al arder.
##   6. La barrera aturde: su puñetazo parado por la barrera lo aturde 1,5 s; el rayo sigue sin aturdirlo.
##   7. Destello de su debilidad: el fuego lo tiñe de rojo anaranjado.
##   8. Con ELEMENTAL_V2 = false todo vuelve a ser el elemental del 8/10.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 24

## Un lanzador que siempre para el golpe (como una barrera cúpula viva): para probar `Jugador3D.golpe_absorbido_por_barrera` sin montar el Lanzador entero.
class LanzadorBarrera extends Lanzador3D:
	func absorber_golpe(_cantidad: float, _desde: Vector3) -> bool:
		return true

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Sensacion3D.ACTIVA = true
	_montar()
	await _raices()
	_enraizada()
	_furia()
	_regado()
	_corteza()
	_tirantes()
	_barrera()
	_destello()
	await _interruptor()
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
	_jugador = Jugador3D.new()
	_jugador.pj = Pj3D.new()
	_jugador.mundo = _mundo
	_mundo.add_child(_jugador.pj)
	_mundo.add_child(_jugador)
	_poner_jugadora(_suelo(15, 12))


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


func _poner_jugadora(p: Vector3) -> void:
	_jugador.position = p
	_jugador.pj.position = p
	_jugador._ultima = p
	_jugador.vida = 100.0
	_jugador._t_inv = 0.0
	_jugador._t_golpe = 0.0               # un golpe anterior la frena y la congela un instante (hitstop): se limpia para que cada sección parta de cero
	_jugador._t_hitstop = 0.0
	_jugador.vel_suelo = Vector3.ZERO
	_jugador.liberar_raices()


## Un elemental en `p`. `quieto` = sin IA (para probar daño y estados); con IA (`false`) persigue a `_jugador`. Se avanza a mano con `_pasos`.
func _nuevo(p: Vector3, quieto: bool = true) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "elemental_bosque"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 1.7
	g.quieto = quieto
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0)
	g._cd_conjuro = 9999.0                    # sin enredaderas: aquí se prueban las demás reglas
	return g


func _quitar(g: Combate3D) -> void:
	if is_instance_valid(g):
		g._cancelar_raices()
		for id in g._tirantes.keys():
			if is_instance_valid(g._tirantes[id]):
				g._tirantes[id].free()
		g._tirantes.clear()
		if is_instance_valid(g.pj):
			g.pj.free()
		g.free()


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		if is_instance_valid(g):
			g._physics_process(DT)


func _h(archivo: String, glifos: Dictionary = {}) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), glifos)


## Pone a la jugadora a `dist` u al este del elemental y lo hace perseguirla.
func _persigue(g: Combate3D, dist: float) -> void:
	_poner_jugadora(g.position + Vector3(dist, 0.0, 0.0))
	g.objetivo = _jugador
	g.estado = "persigue"
	g.vista_perdida = 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  1. Raíces bajo la jugadora
# ---------------------------------------------------------------------------------------------------------------------

func _raices() -> void:
	Combate3D.ELEMENTAL_V2 = true
	# a) lejos (9,5 u): las marca, con aviso de 1 s y el círculo bajo SUS pies
	var g := _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 9.5)
	var pos_j: Vector3 = _jugador.position
	var x0: float = g.position.x
	_pasos(g, 5)
	_ok("1 a 9,5 u saca raíces (una vez)", g.raices_lanzadas == 1, "lanzadas %d" % g.raices_lanzadas)
	var av: AvisoAtaque3D = g._aviso_raices
	_ok("1 el aviso es un círculo de radio %.1f bajo los pies de la jugadora, de %.1f s" % [Combate3D.ELEM_RAICES_RADIO, Combate3D.ELEM_RAICES_AVISO],
		av != null and is_instance_valid(av) and av.forma == "circulo" and is_equal_approx(av.radio, Combate3D.ELEM_RAICES_RADIO) and is_equal_approx(av.t_impacto, Combate3D.ELEM_RAICES_AVISO)
		and Vector2(av.centro.x - pos_j.x, av.centro.z - pos_j.z).length() < 0.01)
	_ok("1 y lleva las raíces que asoman (RaicesElemental3D)", g._raices_vis != null and is_instance_valid(g._raices_vis))
	_ok("1 la recarga de las raíces es %.0f s y NO toca la de las enredaderas" % Combate3D.ELEM_RAICES_CD, g._cd_raices > Combate3D.ELEM_RAICES_CD - 0.2 and g._cd_conjuro > 9000.0, "cd %.2f" % g._cd_raices)
	_pasos(g, 20)
	_ok("1 mientras avisa sigue avanzando (no se para a conjurar)", g.position.x > x0 + 0.2 and g._ataque <= 0.0, "avanza %.2f u" % (g.position.x - x0))
	var vida0: float = _jugador.vida
	_pasos(g, 50)       # ~1,2 s desde el aviso: brotan
	_ok("1 si sigue dentro, la sujeta %.1f s" % Combate3D.ELEM_RAICES_ENRAIZA, _jugador.esta_enraizada() and g.raices_acertadas == 1 and _jugador._t_enraizada > 0.5)
	_ok("1 y le hace daño (≤ %.0f, tras su defensa)" % Combate3D.ELEM_RAICES_DANO, _jugador.vida < vida0 and _jugador.vida >= vida0 - Combate3D.ELEM_RAICES_DANO, "vida %.1f → %.1f" % [vida0, _jugador.vida])
	_ok("1 y no vuelve a lanzar mientras dura la recarga", g.raices_lanzadas == 1)
	_quitar(g)
	# b) se aparta durante el aviso: no pasa nada
	g = _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 9.5)
	_pasos(g, 5)
	_jugador.position += Vector3(Combate3D.ELEM_RAICES_RADIO + 1.0, 0.0, 0.0)
	var vida1: float = _jugador.vida
	_pasos(g, 70)
	_ok("1 si se aparta del círculo a tiempo, ni daño ni raíces", g.raices_lanzadas == 1 and g.raices_acertadas == 0 and not _jugador.esta_enraizada() and _jugador.vida >= vida1, "acertadas %d" % g.raices_acertadas)
	_quitar(g)
	# c) cerca (6 u): no las lanza nunca
	g = _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 6.0)
	_pasos(g, 150)
	_ok("1 a 6 u (menos de %.0f) no saca raíces" % Combate3D.ELEM_RAICES_DIST_MIN, g.raices_lanzadas == 0, "lanzadas %d" % g.raices_lanzadas)
	_quitar(g)
	# d) no la ve (lejos de RADIO_SOLTAR): tampoco
	g = _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 13.0)
	_pasos(g, 20)
	_ok("1 si no la ve (13 u) no las saca", g.raices_lanzadas == 0)
	_quitar(g)
	# e) congelarlo durante el aviso lo corta
	g = _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 9.5)
	_pasos(g, 5)
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	g.congelado = 2.0
	_pasos(g, 12)
	_ok("1 si lo congelan a media cuenta, las raíces se cortan", g._t_raices <= 0.0 and g.raices_acertadas == 0 and g._aviso_raices == null)
	_quitar(g)
	_poner_jugadora(_suelo(15, 12))


## La jugadora enraizada, con el `_process` REAL de Jugador3D: pulsa avanzar y no se mueve; libre sí.
func _enraizada() -> void:
	_poner_jugadora(_suelo(15, 12))
	Input.action_press("mover_adelante")
	var p0: Vector3 = _jugador.position
	for _i in range(20):
		_jugador._process(DT)
	var libre_mov: float = _jugador.position.distance_to(p0)
	_poner_jugadora(_suelo(15, 12))
	p0 = _jugador.position
	_jugador.enraizar(1.5)
	for _i in range(20):
		_jugador._process(DT)
	var preso_mov: float = _jugador.position.distance_to(p0)
	Input.action_release("mover_adelante")
	_ok("1 enraizada no anda aunque pulse avanzar (libre sí: %.2f u; enraizada: %.3f u)" % [libre_mov, preso_mov], libre_mov > 0.1 and preso_mov < 0.001)
	for _i in range(100):
		_jugador._process(DT)         # 1,5 s
	_ok("1 y a los %.1f s se suelta" % Combate3D.ELEM_RAICES_ENRAIZA, not _jugador.esta_enraizada())
	_jugador.enraizar(1.0)
	_jugador.enraizar(0.3)
	_ok("1 enraizar no acorta una sujeción más larga", _jugador._t_enraizada > 0.9)
	_poner_jugadora(_suelo(15, 12))


# ---------------------------------------------------------------------------------------------------------------------
#  2. Enfurecido mientras arde
# ---------------------------------------------------------------------------------------------------------------------

func _avance(arde: bool) -> float:
	var g := _nuevo(_suelo(3, 12), false)
	g._cd_raices = 9999.0
	_persigue(g, 7.0)
	if arde:
		g.quemando = 30.0
	var x0: float = g.position.x
	_pasos(g, 60)
	var d: float = g.position.x - x0
	_quitar(g)
	return d


func _furia() -> void:
	var normal: float = _avance(false)
	var furioso: float = _avance(true)
	_ok("2 ardiendo anda ×%.1f más deprisa (%.2f u/s → %.2f u/s)" % [Combate3D.ELEM_FURIA_VEL, normal, furioso], normal > 0.5 and furioso / normal > 1.2 and furioso / normal < 1.4)
	var g := _nuevo(_suelo(3, 12), true)
	_ok("2 enfurecido() solo mientras arde", not g.enfurecido())
	g.quemando = 3.0
	_ok("2 ... y arde → sí", g.enfurecido())
	# descanso entre puñetazos
	g._descanso = 0.0
	g._carga = Combate3D.PREPARAR_GOLPE
	g._atacar(0.0)
	var d_furia: float = g._descanso
	g._cancelar_ataque()
	g.quemando = 0.0
	g._descanso = 0.0
	g._carga = Combate3D.PREPARAR_GOLPE
	g._atacar(0.0)
	var d_normal: float = g._descanso
	_ok("2 descanso: %.2f s normal, %.2f s enfurecido (×%.1f)" % [d_normal, d_furia, Combate3D.ELEM_FURIA_DESCANSO],
		is_equal_approx(d_normal, Combate3D.ELEM_DESCANSO) and is_equal_approx(d_furia, Combate3D.ELEM_DESCANSO * Combate3D.ELEM_FURIA_DESCANSO))
	# el puñetazo prende casillas solo enfurecido
	g._cancelar_ataque()
	g.mirada = Vector3(1, 0, 0)
	g.quemando = 0.0
	g._golpe_elemental()
	var sin_fuego: int = g.hierba_prendida.size()
	g.quemando = 3.0
	g._golpe_elemental()
	var con_fuego: Array = g.hierba_prendida.duplicate()
	var delante := Terreno3D.celda_de(g.position + Vector3(2.0, 0.0, 0.0))
	_ok("2 su puñetazo prende %d casillas de su área solo enfurecido (sin arder: %d)" % [con_fuego.size(), sin_fuego], sin_fuego == 0 and con_fuego.size() >= 2 and con_fuego.has(delante), str(con_fuego))
	g.quemando = 0.0
	_ok("2 al acabar la quemadura se acaba la furia", not g.enfurecido())
	_quitar(g)
	_poner_jugadora(_suelo(15, 12))


# ---------------------------------------------------------------------------------------------------------------------
#  3. Agua + hielo
# ---------------------------------------------------------------------------------------------------------------------

func _regado() -> void:
	var g := _nuevo(_suelo(3, 12), true)
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	_ok("3 hielo SIN agua: lo que dice la runa (1,5 s)", is_equal_approx(g.congelado, 1.5), "%.2f s" % g.congelado)
	_quitar(g)
	g = _nuevo(_suelo(3, 12), true)
	g.health = 200.0
	g.golpe(_h("water"), Vector3(-1, 0, 0))
	_ok("3 el agua lo sigue curando (+%.0f) y lo deja regado %.0f s" % [Combate3D.ELEM_CURA_AGUA, Combate3D.ELEM_REGADO_VENTANA], is_equal_approx(g.health, 200.0 + Combate3D.ELEM_CURA_AGUA) and is_equal_approx(g._t_regado, Combate3D.ELEM_REGADO_VENTANA))
	_pasos(g, 120)          # 2 s
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	_ok("3 hielo a los 2 s del agua: congelado %.0f s" % Combate3D.ELEM_REGADO_CONGELA, is_equal_approx(g.congelado, Combate3D.ELEM_REGADO_CONGELA), "%.2f s" % g.congelado)
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	_ok("3 la ventana se gasta al congelarlo (otro hielo seguido: 1,5 s)", is_equal_approx(g.congelado, 1.5), "%.2f s" % g.congelado)
	_quitar(g)
	g = _nuevo(_suelo(3, 12), true)
	g.golpe(_h("water"), Vector3(-1, 0, 0))
	_pasos(g, 330)          # 5,5 s
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	_ok("3 hielo pasados 5 s del agua: otra vez 1,5 s", is_equal_approx(g.congelado, 1.5), "%.2f s" % g.congelado)
	_quitar(g)
	# congelado no actúa
	g = _nuevo(_suelo(3, 12), false)
	g._cd_raices = 9999.0
	_persigue(g, 7.0)
	g.golpe(_h("water"), Vector3.ZERO)
	_pasos(g, 130)          # el hitstop pasa; el agua lo agranda
	g.golpe(_h("ice"), Vector3.ZERO)        # sin dirección: sin empuje, para medir solo si anda
	var p_helado: Vector3 = g.position
	_pasos(g, 120)
	_ok("3 congelado no actúa: ni avanza ni ataca (%.4f u)" % g.position.distance_to(p_helado), g.position.distance_to(p_helado) < 0.01 and g.moviendo == 0 and g._ataque <= 0.0)
	_quitar(g)
	_poner_jugadora(_suelo(15, 12))


# ---------------------------------------------------------------------------------------------------------------------
#  4. Corteza delantera
# ---------------------------------------------------------------------------------------------------------------------

func _dano(g: Combate3D, h: Hechizo, dir: Vector3) -> Dictionary:
	return g.prever_golpe(h, dir)


func _corteza() -> void:
	var g := _nuevo(_suelo(3, 12), true)
	g.mirada = Vector3(1, 0, 0)                      # mira al este
	var h: Hechizo = _h("fire")
	var delante: Dictionary = _dano(g, h, Vector3(-1, 0, 0))     # el golpe viaja al oeste: viene del este = de frente
	var detras: Dictionary = _dano(g, h, Vector3(1, 0, 0))
	var sin_dir: Dictionary = _dano(g, h, Vector3.ZERO)
	var bruto: float = float(delante["bruto"])
	_ok("4 de frente: DEF %.0f (daño %.1f = bruto %.1f − 6)" % [Dano.DEF_ELEMENTAL, float(delante["dano"]), bruto], is_equal_approx(float(delante["defensa"]), Dano.DEF_ELEMENTAL) and is_equal_approx(float(delante["dano"]), maxf(bruto - 6.0, 0.2 * bruto)))
	_ok("4 por la espalda: DEF 0 y ×1,5 (%.1f = %.1f × 1,5)" % [float(detras["dano"]), bruto], is_equal_approx(float(detras["defensa"]), 0.0) and is_equal_approx(float(detras["dano"]), bruto * Combate3D.ELEM_ESPALDA_MULT) and bool(detras["espalda"]))
	_ok("4 por la espalda hace más que de frente", float(detras["dano"]) > float(delante["dano"]))
	_ok("4 sin dirección fiable cuenta como de frente", is_equal_approx(float(sin_dir["dano"]), float(delante["dano"])) and not bool(sin_dir["espalda"]))
	# ángulos: a 80° de su frente es frente; a 100°, espalda
	var a80 := Vector3(cos(deg_to_rad(80.0)), 0, sin(deg_to_rad(80.0)))       # hacia dónde está quien golpea
	var a100 := Vector3(cos(deg_to_rad(100.0)), 0, sin(deg_to_rad(100.0)))
	_ok("4 a 80° de su frente aún es de frente; a 100° es la espalda", not bool(_dano(g, h, -a80)["espalda"]) and bool(_dano(g, h, -a100)["espalda"]))
	# ᚦ perforar
	var hp: Hechizo = _h("fire", {"perforar": 1})
	var p_frente: Dictionary = _dano(g, hp, Vector3(-1, 0, 0))
	var p_atras: Dictionary = _dano(g, hp, Vector3(1, 0, 0))
	_ok("4 ᚦ perforar de frente ignora la DEF (daño = bruto %.1f)" % float(p_frente["bruto"]), hp.perfora > 0 and is_equal_approx(float(p_frente["defensa"]), 0.0) and is_equal_approx(float(p_frente["dano"]), float(p_frente["bruto"])))
	_ok("4 ᚦ perforar por la espalda: DEF 0 (y el ×1,5 de la espalda)", is_equal_approx(float(p_atras["defensa"]), 0.0) and is_equal_approx(float(p_atras["dano"]), float(p_atras["bruto"]) * Combate3D.ELEM_ESPALDA_MULT))
	# el daño real baja la vida lo que dice la previsión
	var v0: float = g.health
	g.golpe(h, Vector3(1, 0, 0))
	_ok("4 el golpe real por la espalda quita lo previsto (%.1f)" % (v0 - g.health), is_equal_approx(v0 - g.health, float(detras["dano"])), "%.2f vs %.2f" % [v0 - g.health, float(detras["dano"])])
	# el golpe cuerpo a cuerpo (F)
	g.health = g.vida_max
	var rf: Dictionary = g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 20.0, 0.0)
	g.health = g.vida_max
	var rb: Dictionary = g.recibir_golpe_cuerpo(Vector3(1, 0, 0), 20.0, 0.0)
	_ok("4 el golpe F también: de frente %.1f, por la espalda %.1f" % [float(rf["dano"]), float(rb["dano"])], is_equal_approx(float(rf["dano"]), 14.0) and is_equal_approx(float(rb["dano"]), 30.0))
	# no afecta a otros enemigos
	var gob := Pj3D.new()
	gob.id = "goblin_warrior"
	gob.position = _suelo(5, 5)
	_mundo.add_child(gob)
	var cg: Combate3D = Combate3D.equipar(gob, _mundo, _jugador, null)
	cg.set_physics_process(false)
	cg.mirada = Vector3(1, 0, 0)
	_ok("4 un goblin no tiene corteza: da igual de dónde venga", is_equal_approx(float(_dano(cg, h, Vector3(1, 0, 0))["dano"]), float(_dano(cg, h, Vector3(-1, 0, 0))["dano"])))
	gob.free()
	cg.free()
	_quitar(g)


# ---------------------------------------------------------------------------------------------------------------------
#  5. Tirantes
# ---------------------------------------------------------------------------------------------------------------------

func _vid(p: Vector3) -> Enredadera3D:
	var e := Enredadera3D.new()
	_mundo.add_child(e)
	e.position = p
	e.fase = Enredadera3D.Fase.VIVA
	return e


func _tirantes() -> void:
	var g := _nuevo(_suelo(3, 12), true)
	var e1: Enredadera3D = _vid(_suelo(6, 12))
	var e2: Enredadera3D = _vid(_suelo(6, 14))
	g._vides = [e1, e2]
	g.health = g.vida_max * 0.5
	g._efectos_elemental(DT)
	_ok("5 dos enredaderas vivas → dos tirantes", g.n_tirantes() == 2, "tirantes %d" % g.n_tirantes())
	g._efectos_elemental(DT)
	_ok("5 y no se duplican en el fotograma siguiente", g.n_tirantes() == 2)
	var t1: TiranteEnredadera3D = g._tirantes[e1.get_instance_id()]
	t1.actualizar(0.3)
	var ext: Array = t1.extremos()
	_ok("5 el tirante va del pie de la enredadera al pecho del elemental", ext.size() == 2 and (ext[0] as Vector3).distance_to(e1.global_position + Vector3(0, TiranteEnredadera3D.ALTO_ORIGEN, 0)) < 0.01
		and absf((ext[1] as Vector3).y - (g.global_position.y + g.altura * TiranteEnredadera3D.ALTO_DESTINO)) < 0.01)
	_ok("5 herido, la chispa corre hacia él (cura)", t1.cura and t1._chispa.visible)
	g.health = g.vida_max
	t1.actualizar(0.3)
	_ok("5 con la vida llena solo queda el hilo", not t1.cura and not t1._chispa.visible)
	e1.fase = Enredadera3D.Fase.ARDIENDO
	g._efectos_elemental(DT)
	_ok("5 la enredadera que arde pierde su tirante (queda 1)", g.n_tirantes() == 1, "tirantes %d" % g.n_tirantes())
	e2.fase = Enredadera3D.Fase.DESHACIENDO
	g._efectos_elemental(DT)
	_ok("5 la que se deshace también (queda 0)", g.n_tirantes() == 0, "tirantes %d" % g.n_tirantes())
	e1.free()
	e2.free()
	_quitar(g)


# ---------------------------------------------------------------------------------------------------------------------
#  6. La barrera lo aturde
# ---------------------------------------------------------------------------------------------------------------------

func _barrera() -> void:
	var g := _nuevo(_suelo(3, 12), false)
	g._cd_raices = 9999.0
	g.mirada = Vector3(1, 0, 0)
	_poner_jugadora(g.position + Vector3(1.5, 0.0, 0.0))
	# sin barrera: el puñetazo entra, no lo aturde
	g._golpe_elemental()
	_pasos(g, 2)
	_ok("6 sin barrera su puñetazo entra (%.0f de vida perdida) y no queda aturdido" % (100.0 - _jugador.vida), _jugador.vida < 100.0 and g.stun_timer <= 0.0 and not _jugador.golpe_absorbido_por_barrera)
	# con barrera
	var lb := LanzadorBarrera.new()
	_jugador.lanz = lb
	_poner_jugadora(g.position + Vector3(1.5, 0.0, 0.0))
	g._golpe_elemental()
	_ok("6 la barrera para el puñetazo (la jugadora no pierde vida)", _jugador.golpe_absorbido_por_barrera and _jugador.vida >= 100.0)
	_ok("6 y él queda aturdido %.1f s" % Combate3D.ELEM_BARRERA_ATURDE, is_equal_approx(g.stun_timer, Combate3D.ELEM_BARRERA_ATURDE) and g._aturdido_v2)
	_pasos(g, 30)
	var x_ant: float = g.position.x
	_pasos(g, 30)
	_ok("6 aturdido no actúa (no avanza ni ataca)", absf(g.position.x - x_ant) < 0.01 and g.moviendo == 0 and g.stun_timer > 0.0 and g.stun_timer < Combate3D.ELEM_BARRERA_ATURDE)
	_pasos(g, 45)           # 1,25 s más: ya pasó
	_ok("6 pasado el tiempo se le quita el aturdimiento y vuelve a actuar", g.stun_timer <= 0.0 and not g._aturdido_v2)
	_jugador.lanz = null
	_quitar(g)
	lb.free()
	# el rayo sigue sin aturdirlo
	g = _nuevo(_suelo(3, 12), true)
	g.golpe(_h("lightning"), Vector3(-1, 0, 0))
	_pasos(g, 2)
	_ok("6 el rayo sigue sin aturdir al elemental", g.stun_timer <= 0.0 and not g._aturdido_v2)
	_quitar(g)
	_poner_jugadora(_suelo(15, 12))


# ---------------------------------------------------------------------------------------------------------------------
#  7. Destello de su debilidad
# ---------------------------------------------------------------------------------------------------------------------

func _destello() -> void:
	var g := _nuevo(_suelo(3, 12), true)
	g.golpe(_h("fire"), Vector3(-1, 0, 0))
	var fase: Array = g._destello_fase()
	var c: Color = fase[0]
	_ok("7 el fuego lo deja destellando (%.2f s) rojo anaranjado (%.2f, %.2f, %.2f), energía %.1f" % [g._destello, c.r, c.g, c.b, float(fase[1])],
		g._destello > 0.0 and c.r > 0.9 and c.g < 0.4 and c.b < 0.15 and float(fase[1]) > 0.5 and g._destello_el == "fuego")
	_ok("7 y nunca amarillo (verde < rojo / 2)", c.g < c.r * 0.5)
	_quitar(g)
	var gob := Pj3D.new()
	gob.id = "goblin_warrior"
	gob.position = _suelo(5, 5)
	_mundo.add_child(gob)
	var cg: Combate3D = Combate3D.equipar(gob, _mundo, _jugador, null)
	cg.set_physics_process(false)
	_ok("7 el destello de fuego de un goblin no cambia", cg._color_destello("fuego") != Combate3D.COLOR_FLASH_FUEGO_ELEM)
	gob.free()
	cg.free()


# ---------------------------------------------------------------------------------------------------------------------
#  8. Interruptor
# ---------------------------------------------------------------------------------------------------------------------

func _interruptor() -> void:
	Combate3D.ELEMENTAL_V2 = false
	var g := _nuevo(_suelo(3, 12), false)
	g._cd_raices = 0.0
	_persigue(g, 9.5)
	_pasos(g, 90)
	_ok("8 con ELEMENTAL_V2 = false no saca raíces", g.raices_lanzadas == 0)
	g.quemando = 5.0
	_ok("8 ... ni se enfurece", not g.enfurecido())
	_quitar(g)
	g = _nuevo(_suelo(3, 12), true)
	g.golpe(_h("water"), Vector3(-1, 0, 0))
	g.golpe(_h("ice"), Vector3(-1, 0, 0))
	_ok("8 ... ni el hielo tras el agua lo congela más (1,5 s)", is_equal_approx(g.congelado, 1.5))
	g.mirada = Vector3(1, 0, 0)
	var h: Hechizo = _h("fire")
	_ok("8 ... ni tiene corteza (da igual por dónde)", is_equal_approx(float(_dano(g, h, Vector3(1, 0, 0))["dano"]), float(_dano(g, h, Vector3(-1, 0, 0))["dano"])))
	var e1: Enredadera3D = _vid(_suelo(6, 12))
	g._vides = [e1]
	g._efectos_elemental(DT)
	_ok("8 ... ni tirantes", g.n_tirantes() == 0)
	e1.free()
	_quitar(g)
	Combate3D.ELEMENTAL_V2 = true
	await process_frame
