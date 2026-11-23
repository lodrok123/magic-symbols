extends "res://herramientas/escenario_base.gd"
## EL DRAGÓN JEFE (21/11; objetos/dragon_jefe_3d.gd, mapas/SalaDragon.txt, escenas/PruebaSalaDragon.tscn). La sala es un CARRIL (filas 3 y 4) al pie del dragón (8,1).
## Comprueba las ideas de Pablo vistas en Mages of Mystralia (docs/MAGES_OF_MYSTRALIA_2026-11-21.md O8 y O9):
##   1. PRESENTACIÓN: duerme bajo el suelo; al acercarse la jugadora se levanta, sale el rótulo (epíteto + nombre) y no ataca hasta que acaba; luego aparece su barra.
##   2. ALIENTO: carga (cabeza atrás, boca encendida) → anillos → barrido de fuego real. Sin protección hiere; con algo sólido delante se corta; con una barrera de verdad, también.
##      El agua mientras carga lo aturde.
##   3. PUNTOS DÉBILES: el cuerpo no recibe daño; flechas de verdad encienden los tres cristales; con el tercero cae (temblor), expone el núcleo; una flecha al núcleo le quita
##      vida (×1,5) con silueta blanca y tirón; pasado el tiempo se levanta (temblor) y los cristales se apagan. Vencido, la regla del mapa pone la flag del cofre.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_dragon_jefe.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaDragon.tscn"
var _z: Puzle3D = null


func _preparar(desde: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	colocar_jugador(desde)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _lanzar(desde: Vector2i, elemento: String, glifos: Array, dir: Vector3) -> bool:
	var d: Dictionary = _preparar(desde, elemento, glifos)
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	return lanzador.lanzar_ahora(d, jugador.position, dir)


## Espera hasta que el dragón esté en `fase` (o `max_s`). Devuelve true si llegó.
func _esperar_fase(dr: DragonJefe3D, fase: int, max_s: float) -> bool:
	var inicio: float = reloj.t
	while dr.fase != fase and reloj.t - inicio < max_s:
		await process_frame
	return dr.fase == fase


## Espera a que el contador `campo` del dragón suba de `antes` (o `max_s`). Devuelve los segundos que tardó (-1 si no subió).
func _esperar_contador(dr: DragonJefe3D, campo: String, antes: int, max_s: float) -> float:
	var inicio: float = reloj.t
	while int(dr.get(campo)) <= antes and reloj.t - inicio < max_s:
		await process_frame
	return (reloj.t - inicio) if int(dr.get(campo)) > antes else -1.0


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 la sala tiene sus puzles", _z != null)
	if _z == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	var dr: DragonJefe3D = _z.nodo("dragon") as DragonJefe3D
	_ok("1 la pieza `dragon_jefe` monta el dragón en (8,1) con sus tres cristales", dr != null and dr.celda == Vector2i(8, 1) and dr.puntos.size() == 3)
	if dr == null:
		return
	var R: float = DragonJefe3D.RECUPERA_S + DragonJefe3D.REPOSO_S + DragonJefe3D.CARGA_S + DragonJefe3D.ANILLOS_S + DragonJefe3D.ALIENTO_S + 1.0   # un ciclo entero

	# --- 1 · PRESENTACIÓN ---
	colocar_jugador(Vector2i(2, 4))
	await avanzar_s(1.0)
	_ok("2 lejos, al principio del carril, sigue dormido y no se ve", dr.fase == DragonJefe3D.Fase.DORMIDO and not dr._raiz.visible)
	var hechos: Dictionary = {"presentado": 0}
	dr.presentado.connect(func() -> void: hechos["presentado"] = int(hechos["presentado"]) + 1)
	colocar_jugador(Vector2i(7, 3))
	await avanzar_s(0.3)
	_ok("2 al acercarse por el carril empieza la presentación", dr.fase == DragonJefe3D.Fase.PRESENTA and dr._raiz.visible)
	_ok("2 crea el rótulo con epíteto y nombre", dr.presentacion != null and dr.presentacion._epiteto.text == "Guardian del foso" and dr.presentacion._nombre.text == "DRAGON")
	colocar_jugador(Vector2i(8, 4))
	await avanzar_s(DragonJefe3D.SUBIDA_S + 0.3)
	_ok("2 tras subir, el rótulo está en pantalla y el dragón ya ha salido del suelo", dr.presentacion.titulo_visible and dr._raiz.position.y > -0.2, "y=%.2f" % dr._raiz.position.y)
	_ok("2 mientras se presenta no ataca ni se ve su barra", dr.soplos == 0 and not dr.presentacion.barra_visible)
	var listo: bool = await _esperar_fase(dr, DragonJefe3D.Fase.REPOSO, PresentacionJefe.duracion_titulo() + 2.0)
	_ok("2 al acabar el rótulo: fase de combate, `presentado` una vez y barra a la vista", listo and int(hechos["presentado"]) == 1 and dr.presentacion.barra_visible)

	# --- 2 · ALIENTO sin protección ---
	j._t_inv = 0.0
	var vida0: float = j.vida
	var cargo: bool = await _esperar_fase(dr, DragonJefe3D.Fase.CARGA, DragonJefe3D.REPOSO_S + 1.0)
	_ok("3 tras el reposo empieza la carga (anticipación)", cargo)
	await avanzar_s(DragonJefe3D.CARGA_S * 0.9)
	_ok("3 en la carga la boca se enciende y la cabeza se echa atrás", dr._brillo_boca > 0.5 and dr._cabeceo > 0.6, "boca %.2f cabeza %.2f" % [dr._brillo_boca, dr._cabeceo])
	# A2 de PLAN_COMBATE (22/11): aviso de AvisoAtaque3D (rectángulo rojo que parpadea) y retroceso exagerado del cuello.
	var av: AvisoAtaque3D = dr.aviso_aliento()
	_ok("3 A2 la carga saca un AvisoAtaque3D rectangular que parpadea y cubre a la jugadora en el carril", av != null and av.forma == "rect" and av.parpadeo > 0.0 and av.contiene(j.global_position),
		"aviso %s" % ("sí" if av != null else "no"))
	if av != null:
		var queda_esperado: float = DragonJefe3D.CARGA_S * 0.1 + DragonJefe3D.ANILLOS_S
		_ok("3 A2 el aviso acaba cuando empieza el aliento (carga + anillos)", absf(av.queda() - queda_esperado) < 0.1, "queda %.2f s, esperado %.2f" % [av.queda(), queda_esperado])
	_ok("3 A2 el cuello se echa atrás de forma exagerada", dr._retroceso > 0.8 and dr._cuello.position.z < DragonJefe3D.CUELLO_BASE.z - 0.5, "retroceso %.2f, z %.2f" % [dr._retroceso, dr._cuello.position.z])
	var anillos: bool = await _esperar_fase(dr, DragonJefe3D.Fase.ANILLOS, 1.0)
	await avanzar_s(DragonJefe3D.ANILLOS_S * 0.4)
	var anillo_visto: bool = false
	for a in dr._anillos:
		anillo_visto = anillo_visto or a.visible
	_ok("3 después salen los anillos en el suelo", anillos and anillo_visto)
	var av2: AvisoAtaque3D = dr.aviso_aliento()
	var en_ventana: bool = av2 != null and av2.queda() <= AvisoAtaque3D.VENTANA_ESQUIVA
	var esquiva: AvisoAtaque3D = AvisoAtaque3D.esquiva_a_tiempo(self, j.global_position) if en_ventana else null
	_ok("3 A2 en los últimos %.1f s del aviso, rodar da la esquiva perfecta (tiempo bruja)" % AvisoAtaque3D.VENTANA_ESQUIVA, esquiva != null and esquiva == av2,
		"queda %.2f" % (av2.queda() if av2 != null else -1.0))
	var soplando: bool = await _esperar_fase(dr, DragonJefe3D.Fase.ALIENTO, 1.0)
	await avanzar_s(0.3)
	_ok("3 A2 al soltar el aliento el cuello vuelve adelante (latigazo)", dr._retroceso < 0.2, "retroceso %.2f" % dr._retroceso)
	var yaw0: float = dr._yaw
	await _esperar_fase(dr, DragonJefe3D.Fase.RECUPERA, DragonJefe3D.ALIENTO_S + 1.0)
	_ok("3 el aliento barre el abanico de lado a lado", soplando and absf(dr._yaw - yaw0) > DragonJefe3D.BARRIDO_GRADOS * 0.8, "de %.0f° a %.0f°" % [yaw0, dr._yaw])
	_ok("3 sopla haces reales de fuego (uno cada %.2f s)" % DragonJefe3D.TICK_S, dr.soplos >= int(DragonJefe3D.ALIENTO_S / DragonJefe3D.TICK_S) - 1, "%d soplos" % dr.soplos)
	_ok("3 sin protección, el chorro hiere a la jugadora en el carril", dr.golpes_jugadora >= 1 and j.vida < vida0, "%d golpes, -%.0f de vida" % [dr.golpes_jugadora, vida0 - j.vida])

	# --- 3 · Algo SÓLIDO delante corta el chorro ---
	var muro: Array = []
	for x in range(1, 16):
		muro.append(Vector2i(x, 3))
	colocar_jugador(Vector2i(8, 4))
	for c in muro:
		Terreno3D.bloquear_celda(c as Vector2i)
	var golpes1: int = dr.golpes_jugadora
	var cortes1: int = dr.cortes_solido
	j._t_inv = 0.0
	await _esperar_fase(dr, DragonJefe3D.Fase.ALIENTO, R)
	await _esperar_fase(dr, DragonJefe3D.Fase.RECUPERA, DragonJefe3D.ALIENTO_S + 1.0)
	_ok("4 con la fila de delante sólida, el chorro se corta y no la hiere", dr.golpes_jugadora == golpes1 and dr.cortes_solido > cortes1,
		"%d golpes nuevos, %d cortes · %s" % [dr.golpes_jugadora - golpes1, dr.cortes_solido - cortes1, dr.ultimo_golpe if dr.golpes_jugadora > golpes1 else ""])
	for c in muro:
		Terreno3D.liberar_celda(c as Vector2i)

	# --- 5 · Agua mientras carga: aturde (da en el cristal del ala izquierda y lo enciende). Se lanza por la izquierda: el agua que deja delante apagaría luego el fuego al núcleo ---
	var hechos2: Dictionary = {"aturdido": 0}
	dr.aturdido.connect(func() -> void: hechos2["aturdido"] = int(hechos2["aturdido"]) + 1)
	await _esperar_fase(dr, DragonJefe3D.Fase.CARGA, R)
	var imp0: int = dr.impactos
	_lanzar(Vector2i(7, 3), "agua", ["flecha"], Vector3(0, 0, -1))
	var tarda: float = await _esperar_contador(dr, "impactos", imp0, 2.5)
	await avanzar_s(0.2)
	_ok("6 una flecha de agua mientras carga lo aturde", int(hechos2["aturdido"]) == 1 and dr.fase == DragonJefe3D.Fase.ATURDIDO,
		"tarda %.2f s, fase %d, vía «%s»" % [tarda, dr.fase, dr.ultima_via])
	_ok("6 y como da en el cristal del ala izquierda, lo enciende (1 de 3)", dr.puntos_encendidos() == 1 and (dr.puntos[0] as DragonJefe3D.PuntoDebil).encendido)

	# --- 6 · El cuerpo no recibe daño ---
	var vida_d: float = dr.vida
	var fuego: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {"flecha": 1})
	dr.on_spell_hit(null, Vector3.ZERO, fuego)
	_ok("7 un fuego en el cuerpo no le quita vida", is_equal_approx(dr.vida, vida_d) and dr.golpes_sin_efecto >= 1, "%.0f" % dr.vida)

	# --- 7 · Encender los otros dos cristales (pecho y ala derecha) con flechas de verdad ---
	var hechos3: Dictionary = {"expuesto": 0}
	dr.expuesto.connect(func() -> void: hechos3["expuesto"] = int(hechos3["expuesto"]) + 1)
	var temblores0: int = dr.temblores
	for par in [[Vector2i(8, 3), 1], [Vector2i(9, 3), 2]]:
		var esperar: float = 0.0
		while not dr.puntos_activos() and esperar < R:
			await process_frame
			esperar += 1.0 / 30.0
		_lanzar(par[0] as Vector2i, "fuego", ["flecha"], Vector3(0, 0, -1))
		var t0: float = reloj.t
		var punto: DragonJefe3D.PuntoDebil = dr.puntos[int(par[1])]
		while not punto.encendido and reloj.t - t0 < 2.0:
			await process_frame
		_ok("8 una flecha de fuego desde %s enciende el cristal %d" % [str(par[0]), int(par[1])], punto.encendido, "%d encendidos" % dr.puntos_encendidos())
	var cayo: bool = await _esperar_fase(dr, DragonJefe3D.Fase.EXPUESTO, DragonJefe3D.CAE_S + 1.0)
	_ok("8 con los tres encendidos cae y expone el núcleo", cayo and int(hechos3["expuesto"]) == 1 and dr._nucleo.activo())
	_ok("8 la caída hace temblar la pantalla", dr.temblores == temblores0 + 1, "%d temblores" % (dr.temblores - temblores0))

	# --- 8 · Flecha al núcleo ---
	vida_d = dr.vida
	var nucleo0: int = dr.golpes_nucleo
	var tirones0: int = dr.tirones
	_lanzar(Vector2i(8, 3), "fuego", ["flecha"], Vector3(0, 0, -1))      # la flecha llega a 2 casillas: desde la fila de delante del carril
	var t_n: float = await _esperar_contador(dr, "golpes_nucleo", nucleo0, 2.0)
	_ok("9 una flecha de fuego al núcleo le quita vida (×%.1f)" % DragonJefe3D.MULT_NUCLEO, t_n >= 0.0 and dr.vida < vida_d, "%.0f → %.0f en %.2f s" % [vida_d, dr.vida, t_n])
	_ok("9 con tirón de cámara", dr.tirones == tirones0 + 1)
	dr.golpe_nucleo(load("res://nucleo/fire_rune.tres") as RuneData, null)
	await process_frame
	var blanca: bool = dr.silueta_blanca()
	await avanzar(6)
	_ok("9 y silueta blanca un instante (se pone y se quita)", blanca and not dr.silueta_blanca())
	_ok("9 la barra sigue a la vida", is_equal_approx(dr.presentacion.vida_fr, dr.vida / dr.vida_max), "%.2f" % dr.presentacion.vida_fr)

	# --- 9 · Se levanta y vuelve a empezar ---
	var levanto: bool = await _esperar_fase(dr, DragonJefe3D.Fase.REPOSO, DragonJefe3D.EXPUESTO_S + DragonJefe3D.LEVANTA_S + 1.0)
	_ok("10 pasada la exposición se levanta (temblor otra vez) y apaga los cristales", levanto and dr.temblores == temblores0 + 2 and dr.puntos_encendidos() == 0 and not dr._nucleo.activo())

	# --- 10 · Con la BARRERA de la jugadora, de verdad: sola y con flecha (muro delante). Al final: el muro de tierra se queda un rato y taparía las flechas de antes ---
	for receta in [["barrera"], ["barrera", "flecha"]]:
		await _esperar_fase(dr, DragonJefe3D.Fase.ANILLOS, R)
		_lanzar(Vector2i(8, 4), "tierra", receta, Vector3(0, 0, -1))
		var golpes2: int = dr.golpes_jugadora
		var cortes2: int = dr.cortes_solido
		var burbuja2: int = dr.en_burbuja
		colocar_jugador(Vector2i(8, 4))
		j._t_inv = 0.0
		var vida2: float = j.vida
		await _esperar_fase(dr, DragonJefe3D.Fase.RECUPERA, DragonJefe3D.ANILLOS_S + DragonJefe3D.ALIENTO_S + 1.0)
		var info: String = "%d cortes, %d en burbuja, %d golpes, -%.0f de vida" % [dr.cortes_solido - cortes2, dr.en_burbuja - burbuja2, dr.golpes_jugadora - golpes2, vida2 - j.vida]
		if receta.size() == 1:
			# La barrera SOLA de tierra no es un escudo delante: se mide y se enseña, no se exige (decisión de diseño pendiente, H2 «hechizos sobre sí misma»).
			_aviso("12 tierra + barrera sola (medido, no se exige)", info)
		else:
			_ok("12 tierra + barrera + flecha (muro delante) para el aliento", dr.cortes_solido > cortes2 and dr.golpes_jugadora == golpes2, info)
		if dr.golpes_jugadora > golpes2:
			_aviso("12 aun con tierra + %s la alcanzan %d soplos" % [" + ".join(receta), dr.golpes_jugadora - golpes2], info + " · " + dr.ultimo_golpe)

	# --- 11 · Vencerlo ---
	var hechos4: Dictionary = {"derrotado": 0}
	dr.derrotado.connect(func() -> void: hechos4["derrotado"] = int(hechos4["derrotado"]) + 1)
	dr.vida = 5.0
	dr.recibir(10.0)
	await avanzar_s(0.5)
	_ok("11 vencido: `derrotado` una vez, fase final y barra oculta", int(hechos4["derrotado"]) == 1 and dr.fase == DragonJefe3D.Fase.MUERTO and not dr.presentacion.barra_visible)
	_ok("11 la regla del mapa pone la flag del cofre", Flags.i().tiene("saladragon.sala.vencido"))
	await avanzar_s(1.0)
