extends "res://herramientas/escenario_base.gd"
## SONIDOS GRABADOS, 2.ª ENTREGA (2/11, tarea R de docs/REVISION_GAMEFEEL_30-10.md §10): lo sintetizado que pasa a grabaciones (Kenney, OpenGameArt, Freesound; audio/LICENCIAS.md).
##   1  cada entrada sustituida tiene «f» (grabado) y «f_sint» (lo de antes), todos los archivos cargan y duran < 3 s (los bucles, no);
##   2  los nuevos: paso_goblin, paso_golem (3-4 variantes, tono y dB), gato_ronroneo (bucle), pluma_bucle y paginas_bucle (fs_), no_puedes_ui (y los menús ya no usan el no_puedes del mundo);
##   3  Sfx.GRABADOS = false devuelve «f_sint» en todas las sustituidas (y «f» con true);
##   4  el goblin y el gólem suenan al andar 3 u (y quietos o teletransportados, no); el gato ronronea quieto y cerca, y se calla al moverse o alejarse;
##   5  la pluma suena MIENTRAS se arrastra el trazo (más fuerte con más velocidad) y se corta al soltar; PLUMA_ACTIVA = false la apaga;
##   6  `_sonar_fase_v2` prefiere «<elemento>_impacto» si existe en el catálogo; sin entrada, el derivado de siempre;
##   7  S:GRABADOS está al final del panel F3 y cambia Sfx.GRABADOS sin mover ningún índice.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_sonidos_grabados_2.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"
const SUSTITUIDAS_SFX: Array = ["moneda", "recoger", "ui_equipar", "bolsa", "ui_tick", "no_puedes_ui", "comprar", "cofre_tapa", "clavar"]
const SUSTITUIDAS_3D: Array = ["golpe_piedra", "golpe_carne", "gato_maullido"]
var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _duracion(archivo: String) -> float:
	var s: AudioStream = load(Sfx.CARPETA + archivo) as AudioStream
	return s.get_length() if s != null else -1.0


func _escenario() -> void:
	Sfx.REGISTRAR = true
	_catalogo()
	_nuevos()
	_interruptor()
	await cargar(RUTA_SALA)
	await _pasos()
	await _gato()
	_pluma()
	_impacto_elemento()
	_panel()
	print("COMPROBACIONES: %d" % _comprobaciones)


## 1 · Lo sustituido tiene las dos rutas; todo carga y es corto.
func _catalogo() -> void:
	var todas: Array = []
	for n in SUSTITUIDAS_SFX:
		todas.append([n, Sfx.CATALOGO.get(n, {})])
	for n in SUSTITUIDAS_3D:
		todas.append([n, Sfx3D.CATALOGO.get(n, {})])
	for par in todas:
		var n: String = par[0]
		var cfg: Dictionary = par[1]
		var tiene: bool = cfg.has("f") and cfg.has("f_sint")
		_ok("1 «%s» guarda «f» (grabado) y «f_sint» (el de antes)" % n, tiene)
		if not tiene:
			continue
		var f: Array = cfg["f"]
		var fs: Array = cfg["f_sint"]
		_ok("1 «%s»: lo grabado no es lo sintetizado" % n, f != fs)
		var largo: float = 0.0
		var malos: Array = []
		for a in f + fs:
			var d: float = _duracion(String(a))
			largo = maxf(largo, d)
			if d <= 0.0 or d >= 3.0:
				malos.append("%s=%.2f s" % [a, d])
		_ok("1 «%s»: %d + %d archivos cargan y duran < 3 s" % [n, f.size(), fs.size()], malos.is_empty(), "máx %.2f s %s" % [largo, str(malos)])
		for a in f:
			var pref: bool = String(a).begins_with("kenney_") or String(a).begins_with("oga_") or String(a).begins_with("fs_")
			if not pref:
				_ok("1 «%s»: %s lleva prefijo de procedencia" % [n, a], false)
	# Con GRABADOS = true suenan los grabados (play_ui registra el nombre y elige de «f»).
	_ok("1 los de Sfx3D que no se sustituyen siguen igual (goblin_grito sin f_sint)", not Sfx3D.CATALOGO["goblin_grito"].has("f_sint"))


## 2 · Entradas nuevas.
func _nuevos() -> void:
	for n in ["paso_goblin", "paso_golem"]:
		var cfg: Dictionary = Sfx3D.CATALOGO.get(n, {})
		var nf: int = (cfg.get("f", []) as Array).size()
		_ok("2 «%s» está en Sfx3D con 3-4 variantes" % n, nf >= 3 and nf <= 4, "%d" % nf)
		var todos: bool = nf > 0
		for a in cfg.get("f", []):
			todos = todos and _duracion(String(a)) > 0.0 and _duracion(String(a)) < 3.0
		_ok("2 «%s»: las variantes cargan y duran < 3 s" % n, todos)
	_ok("2 paso_golem: tono ×0,6 y −4 dB", is_equal_approx(float(Sfx3D.CATALOGO["paso_golem"]["base"]), 0.6) and is_equal_approx(float(Sfx3D.CATALOGO["paso_golem"]["db"]), -4.0))
	_ok("2 paso_goblin: tono ×1,2", is_equal_approx(float(Sfx3D.CATALOGO["paso_goblin"]["base"]), 1.2))
	var amb: Dictionary = Sfx3D.AMBIENTES.get("gato_ronroneo", {})
	var bucle: AudioStream = Sfx3D.bucle("gato_ronroneo")
	_ok("2 gato_ronroneo es un ambiente de Sfx3D que sale en bucle", not amb.is_empty() and bucle is AudioStreamWAV and (bucle as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, str(amb.get("f", "")))
	_ok("2 gato_maullido: las 3 grabaciones de OGA", (Sfx3D.CATALOGO["gato_maullido"]["f"] as Array).size() == 3 and String((Sfx3D.CATALOGO["gato_maullido"]["f"] as Array)[0]).begins_with("oga_gato"))
	for n in ["pluma_bucle", "paginas_bucle"]:
		var cfg: Dictionary = Sfx.CATALOGO.get(n, {})
		var f0: String = String((cfg.get("f", [""]) as Array)[0])
		var flujo: AudioStream = Sfx.flujo_en_bucle(n)
		_ok("2 «%s» apunta a un fs_ y sale en bucle" % n, f0.begins_with("fs_") and flujo != null and bool(flujo.get("loop")), "%s %s" % [f0, str(flujo)])
	_ok("2 el mp3 de Freesound se importó como AudioStreamMP3 y carga", load(Sfx.CARPETA + "fs_paginas_bucle.mp3") is AudioStreamMP3 and load(Sfx.CARPETA + "fs_pluma_pergamino.mp3") is AudioStreamMP3)
	_ok("2 no_puedes (del mundo) no cambia", Sfx.CATALOGO["no_puedes"]["f"] == ["no_puedes.wav"] and not Sfx.CATALOGO["no_puedes"].has("f_sint"))
	var restos: Array = []
	for fich in DirAccess.get_files_at("res://presentacion/ui"):
		if String(fich).ends_with(".gd"):
			var t: String = FileAccess.get_file_as_string("res://presentacion/ui/" + String(fich))
			if t.contains("play_ui(\"no_puedes\""):
				restos.append(fich)
	_ok("2 ningún menú de presentacion/ui llama ya a play_ui(\"no_puedes\")", restos.is_empty(), str(restos))
	Sfx.vaciar_registro()
	Sfx._ultima.clear()
	Sfx.play_ui("no_puedes_ui")
	_ok("2 play_ui(\"no_puedes_ui\") suena", Sfx.veces("no_puedes_ui") == 1)


## 3 · El interruptor.
func _interruptor() -> void:
	Sfx.GRABADOS = false
	var mal: Array = []
	for n in SUSTITUIDAS_SFX:
		if Sfx.archivos_de(Sfx.CATALOGO[n]) != Sfx.CATALOGO[n]["f_sint"]:
			mal.append(n)
	for n in SUSTITUIDAS_3D:
		if Sfx.archivos_de(Sfx3D.CATALOGO[n]) != Sfx3D.CATALOGO[n]["f_sint"]:
			mal.append(n)
	_ok("3 GRABADOS = false: todas las sustituidas devuelven «f_sint»", mal.is_empty(), str(mal))
	# Y de verdad al sonar: el reproductor que crea play_ui/Sfx3D usa el sintetizado.
	var c: Dictionary = Sfx.CATALOGO["moneda"]
	_ok("3 GRABADOS = false: «moneda» → moneda.wav", Sfx.archivos_de(c) == ["moneda.wav"])
	_ok("3 GRABADOS = false: lo no sustituido (conjuro_arcano) no cambia", Sfx.archivos_de(Sfx.CATALOGO["conjuro_arcano"]) == Sfx.CATALOGO["conjuro_arcano"]["f"])
	Sfx.GRABADOS = true
	var bien: bool = true
	for n in SUSTITUIDAS_SFX:
		bien = bien and Sfx.archivos_de(Sfx.CATALOGO[n]) == Sfx.CATALOGO[n]["f"]
	_ok("3 GRABADOS = true: «f» (los grabados)", bien)
	_ok("3 por defecto GRABADOS = true y PLUMA_ACTIVA = true", Sfx.GRABADOS and Sfx.PLUMA_ACTIVA)


## 4 · Pasos de goblin y gólem.
func _pasos() -> void:
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100000.0
	var gob: Combate3D = Combate3D.invocar_asesino(maqueta, j, lanzador, _pos(Vector2i(4, 3)))
	_ok("4 hay goblin de pruebas", gob != null)
	if gob == null:
		return
	gob.quieto = true
	gob.set_physics_process(false)
	gob._sonar_pasos()                                    # fija la posición de partida
	Sfx.vaciar_registro()
	for _i in range(5):
		gob._sonar_pasos()
	_ok("4 goblin quieto: ningún paso", Sfx.veces("paso_goblin") == 0)
	var p0: Vector3 = gob.position
	for _i in range(30):                                  # 3,0 u a 0,1 u por fotograma
		Sfx3D._ultima.clear()                             # la veda (70 ms de reloj de pared) no es lo que se prueba aquí
		gob.position += Vector3(0.1, 0.0, 0.0)
		gob._sonar_pasos()
	var n_gob: int = Sfx.veces("paso_goblin")
	_ok("4 goblin: 3 u andadas → 3 pasos (zancada %.1f)" % gob.zancada_sonido, n_gob == 3, "%d · movió %.2f" % [n_gob, gob.position.distance_to(p0)])
	Sfx.vaciar_registro()
	Sfx3D._ultima.clear()
	gob.position += Vector3(3.0, 0.0, 0.0)                # un salto de 3 u en un fotograma no es andar
	gob._sonar_pasos()
	_ok("4 goblin: un teletransporte de 3 u no suena", Sfx.veces("paso_goblin") == 0)
	gob._empuje = Vector3(5.0, 0.0, 0.0)
	for _i in range(20):
		Sfx3D._ultima.clear()
		gob.position += Vector3(0.1, 0.0, 0.0)
		gob._sonar_pasos()
	gob._empuje = Vector3.ZERO
	_ok("4 goblin: empujado (no anda) no suena", Sfx.veces("paso_goblin") == 0)
	gob.snd_paso = ""
	for _i in range(20):
		gob.position += Vector3(0.1, 0.0, 0.0)
		gob._sonar_pasos()
	_ok("4 snd_paso = \"\" lo silencia", Sfx.veces("paso_goblin") == 0)
	# Los que heredan: el chamán y el gólem; el limo y el gato no llevan.
	var lim: Limo3D = Limo3D.new()
	lim.mundo = maqueta
	lim.position = _pos(Vector2i(4, 9))
	maqueta.add_child(lim)
	_ok("4 el limo no lleva pasos (snd_paso vacío)", lim.snd_paso == "")
	lim.queue_free()
	# Gólem: 3 u a mano (1 zancada de 1,8 u) y andando de verdad hacia la jugadora.
	var g: Golem3D = Golem3D.invocar_golem(maqueta, _pos(Vector2i(10, 6)), j, lanzador)
	g.quieto = true
	g.set_physics_process(false)
	_ok("4 el gólem lleva paso_golem y zancada 1,8", g.snd_paso == "paso_golem" and is_equal_approx(g.zancada_sonido, 1.8))
	g._sonar_pasos()
	Sfx.vaciar_registro()
	for _i in range(30):
		Sfx3D._ultima.clear()
		g.position += Vector3(0.1, 0.0, 0.0)
		g._sonar_pasos()
	var n_gol: int = Sfx.veces("paso_golem")
	_ok("4 gólem: 3 u andadas → 1 paso (zancada %.1f)" % g.zancada_sonido, n_gol == 1 and Sfx.veces("paso_goblin") == 0, "%d" % n_gol)
	_ok("4 gólem: el paso suena a −4 dB", is_equal_approx(float((Sfx.ULTIMOS.back() as Dictionary)["db"]), -4.0), str(Sfx.ULTIMOS.back()))
	# Andando por su cuenta con el motor.
	g.set_physics_process(true)
	g.quieto = false
	g.g_estado = "armado"
	colocar_jugador(Vector2i(8, 6))                         # a 4,6 u: dentro de RADIO_DETECCION (5,75) y a 2,7 u de caminata hasta su RANGO
	(jugador as Jugador3D).vida = 100000.0
	g.position = _pos(Vector2i(10, 6))
	g._paso_prev = Vector3(INF, 0.0, 0.0)
	g._paso_acc = 0.0
	Sfx.vaciar_registro()
	var x0: Vector3 = g.position
	var t: float = 0.0
	while t < 5.0 and Vector2(g.position.x - x0.x, g.position.z - x0.z).length() < 2.6:
		Sfx3D._ultima.clear()
		t += await avanzar_s(1.0 / 30.0)
	var mov: float = Vector2(g.position.x - x0.x, g.position.z - x0.z).length()
	var esperados: int = int(mov / g.zancada_sonido)
	_ok("4 gólem andando de verdad (%.1f u en %.1f s) suena un paso cada %.1f u" % [mov, t, g.zancada_sonido], mov > 1.8 and Sfx.veces("paso_golem") == esperados and esperados >= 1, "%d pasos (esperados ≈ %d) · estado %s · moviendo %d · objetivo %s · dist %.1f · quieto %s · fisica %s" % [Sfx.veces("paso_golem"), esperados, g.g_estado, g.moviendo, str(g.objetivo), g.position.distance_to(jugador.position), str(g.quieto), str(g.is_physics_processing())])
	g.quieto = true
	gob.queue_free()
	g.queue_free()
	await avanzar(2)


## 4 · El gato.
func _gato() -> void:
	var j: Jugador3D = jugador as Jugador3D
	colocar_jugador(Vector2i(8, 8))
	var g: Gatopedro3D = Gatopedro3D.invocar(maqueta, j, lanzador, _pos(Vector2i(10, 8)))
	_ok("4 hay gato de pruebas", g != null)
	if g == null:
		return
	g.set_physics_process(false)
	g.quieto = true
	j.position = g.position + Vector3(2.0, 0.0, 0.0)
	var dt: float = 1.0 / 30.0
	for _i in range(24):                                   # 0,8 s quieto: aún no
		g._actualizar_ronroneo(dt)
	_ok("4 gato quieto 0,8 s (< 1 s): aún no ronronea", g._ronroneo == null)
	for _i in range(12):                                   # 1,2 s en total
		g._actualizar_ronroneo(dt)
	_ok("4 gato quieto > 1 s y la jugadora a 2 u: ronronea (bucle gato_ronroneo)", g._ronroneo != null and is_instance_valid(g._ronroneo) and (g._ronroneo.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var p: AudioStreamPlayer3D = g._ronroneo
	for _i in range(30):
		g._actualizar_ronroneo(dt)
	_ok("4 sigue siendo el mismo bucle (no se reinicia cada fotograma)", g._ronroneo == p)
	g.position += Vector3(0.5, 0.0, 0.0)                   # se mueve
	g._actualizar_ronroneo(dt)
	_ok("4 al moverse se para", g._ronroneo == null)
	await avanzar_s(0.7)
	_ok("4 …y el reproductor se libera tras el fundido", not is_instance_valid(p))
	j.position = g.position + Vector3(2.0, 0.0, 0.0)       # la jugadora de la escena tiene física propia y se ha movido durante la espera
	for _i in range(40):
		g._actualizar_ronroneo(dt)
	_ok("4 vuelve a ronronear quieto otra vez", g._ronroneo != null, "quieto %.2f s · dist %.2f · estado %s · muerto %s" % [g._t_quieto, g._dist(j.position), g.estado, str(g.muerto)])
	j.position = g.position + Vector3(6.0, 0.0, 0.0)       # se aleja la jugadora
	g._actualizar_ronroneo(dt)
	_ok("4 jugadora a 6 u (> 4): se calla", g._ronroneo == null)
	j.position = g.position + Vector3(3.5, 0.0, 0.0)
	g._actualizar_ronroneo(dt)
	_ok("4 jugadora a 3,5 u: vuelve", g._ronroneo != null)
	Gatopedro3D.RONRONEO_ACTIVO = false
	g._actualizar_ronroneo(dt)
	_ok("4 RONRONEO_ACTIVO = false lo apaga", g._ronroneo == null)
	Gatopedro3D.RONRONEO_ACTIVO = true
	_ok("4 el gato no lleva pasos", g.snd_paso == "")
	g.queue_free()
	await avanzar(2)


## 5 · La pluma.
func _pluma() -> void:
	Sfx.vaciar_registro()
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	root.add_child(libro)
	libro.size = Vector2(1280.0, 720.0)                    # sin ventana el Control mide 0 y el radio del trazo también
	libro.set_process(false)
	var c: Vector2 = libro.call("_center")
	var dt: float = 1.0 / 60.0
	print("   radio del trazo %.2f · centro %s" % [float(libro.call("_radio_trazo")), str(c)])
	libro.call("_begin_stroke", c)
	_ok("5 el trazo nace dentro del círculo", bool(libro.get("is_drawing")))
	libro.call("_actualizar_pluma", dt)
	var pl: AudioStreamPlayer = libro.get("_pluma")
	_ok("5 al empezar a arrastrar suena el bucle de la pluma (bus Interfaz)", pl != null and pl.playing and String(pl.bus) == Sfx.BUS_INTERFAZ and Sfx.veces("pluma_bucle") == 1)
	# Parado: ~ −30 dB.
	for _i in range(30):
		libro.call("_actualizar_pluma", dt)
	var db_parado: float = pl.volume_db
	_ok("5 parado → %.0f dB" % Sfx.DB_PLUMA_MIN, absf(db_parado - Sfx.DB_PLUMA_MIN) < 0.5, "%.2f dB" % db_parado)
	# Lento (150 px/s) y normal (900 px/s).
	var x: float = 0.0
	for _i in range(60):
		x += 150.0 * dt
		libro.call("_add_point", c + Vector2(fmod(x, 100.0) - 50.0, 0.0))
		libro.call("_actualizar_pluma", dt)
	var db_lento: float = pl.volume_db
	var db_rapido: float = db_lento
	var dir: float = 1.0
	var px: float = -50.0
	for _i in range(60):
		px += dir * Sfx.VELOCIDAD_PLUMA * dt
		if absf(px) > 100.0:
			dir = -dir
			px = clampf(px, -100.0, 100.0)
		libro.call("_add_point", c + Vector2(px, 0.0))
		libro.call("_actualizar_pluma", dt)
		db_rapido = pl.volume_db
	_ok("5 el volumen sube con la velocidad (parado %.1f < lento %.1f < rápido %.1f dB)" % [db_parado, db_lento, db_rapido], db_parado < db_lento and db_lento < db_rapido)
	_ok("5 a velocidad normal llega a DB_PLUMA_MAX (%.0f dB)" % Sfx.DB_PLUMA_MAX, absf(db_rapido - Sfx.DB_PLUMA_MAX) < 1.0 and db_rapido <= Sfx.DB_PLUMA_MAX + 0.01, "%.2f dB" % db_rapido)
	_ok("5 sigue siendo UN solo reproductor", Sfx.veces("pluma_bucle") == 1 and libro.get("_pluma") == pl)
	# Se corta al soltar.
	libro.call("_end_stroke")
	_ok("5 al soltar el trazo se corta (no queda reproductor en el libro)", libro.get("_pluma") == null)
	# PLUMA_ACTIVA = false.
	Sfx.PLUMA_ACTIVA = false
	Sfx.vaciar_registro()
	libro.call("_begin_stroke", c)
	libro.call("_add_point", c + Vector2(30.0, 0.0))
	libro.call("_actualizar_pluma", dt)
	_ok("5 PLUMA_ACTIVA = false: no suena", libro.get("_pluma") == null and Sfx.veces("pluma_bucle") == 0)
	Sfx.PLUMA_ACTIVA = true
	libro.call("_actualizar_pluma", dt)
	_ok("5 …y al reactivarla mientras se arrastra, suena", libro.get("_pluma") != null)
	libro.set("is_drawing", false)                          # el trazo se cancela por otra vía: _process lo calla
	libro.call("_actualizar_pluma", dt)
	_ok("5 un trazo cancelado sin soltar también calla la pluma", libro.get("_pluma") == null)
	libro.queue_free()


## 6 · Impacto por elemento.
func _impacto_elemento() -> void:
	lanzador.sonidos_fase.clear()
	lanzador._sonar_fase_v2("impacto", "fuego", "x_mano", Vector3.ZERO)
	var antes: String = String((lanzador.sonidos_fase.back() as Dictionary)["suena"])
	_ok("6 sin «fuego_impacto» suena el derivado de siempre (x_mano_impacto)", antes == "x_mano_impacto", antes)
	# Una entrada falsa «en caliente». El catálogo es const: si no deja escribir, se prueba con una copia (ver el aviso).
	var cat: Dictionary = Sfx.CATALOGO
	var escribible: bool = true
	if cat.is_read_only():
		escribible = false
	if escribible:
		cat["fuego_impacto"] = {"f": ["kenney_golpe_piedra_0.ogg"], "db": -9.0, "tono": 0.05}
		lanzador._sonar_fase_v2("impacto", "fuego", "x_mano", Vector3.ZERO)
		var despues: String = String((lanzador.sonidos_fase.back() as Dictionary)["suena"])
		_ok("6 con «fuego_impacto» en el catálogo se prefiere al derivado", despues == "fuego_impacto", despues)
		lanzador._sonar_fase_v2("impacto", "agua", "x_mano", Vector3.ZERO)
		_ok("6 otro elemento (agua) sigue con el derivado", String((lanzador.sonidos_fase.back() as Dictionary)["suena"]) == "x_mano_impacto")
		lanzador._sonar_fase_v2("carga", "fuego")
		_ok("6 la fase «carga» no se ve afectada", String((lanzador.sonidos_fase.back() as Dictionary)["suena"]) == "fuego_carga")
		cat.erase("fuego_impacto")
	else:
		_ok("6 el catálogo (const) es de solo lectura: no se puede añadir en caliente", false, "hay que hacerlo static var")


## 7 · Panel F3.
func _panel() -> void:
	var ent: Array = LabHechizos3D.entradas()
	var nombres: Array = []
	for e in ent:
		nombres.append(String(e["n"]))
	var i_gr: int = nombres.find("S:GRABADOS")
	_ok("7 S:GRABADOS está en el panel F3", i_gr >= 0)
	_ok("7 …después de S:DURACION_DIA_S (al final: ningún índice se mueve)", i_gr > nombres.find("S:DURACION_DIA_S") and nombres.find("S:DURACION_DIA_S") > nombres.find("dB:imprimir ajustes"))
	_ok("7 las filas dB nuevas (no_puedes_ui, pluma_bucle, paginas_bucle) van detrás", nombres.find("dB:no_puedes_ui") > i_gr and nombres.find("dB:pluma_bucle") > i_gr and nombres.find("dB:paginas_bucle") > i_gr)
	_ok("7 y no hay filas duplicadas", nombres.size() == _unicos(nombres))
	LabHechizos3D.impacto_poner("S:GRABADOS", 0.0)
	_ok("7 S:GRABADOS = 0 → Sfx.GRABADOS false", not Sfx.GRABADOS and LabHechizos3D.impacto_valor("S:GRABADOS") == 0.0)
	LabHechizos3D.impacto_poner("S:GRABADOS", 1.0)
	_ok("7 S:GRABADOS = 1 → Sfx.GRABADOS true", Sfx.GRABADOS and LabHechizos3D.impacto_valor("S:GRABADOS") == 1.0)


func _unicos(a: Array) -> int:
	var d: Dictionary = {}
	for x in a:
		d[x] = true
	return d.size()
