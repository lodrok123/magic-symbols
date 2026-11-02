extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, TAREA O (1/11; nucleo/sfx_3d.gd, default_bus_layout.tres, laboratorios/lab_hechizos_3d.gd): oclusión del sonido.
## Un sonido 3D con línea de vista con el oyente va al bus «Mundo»; con un sólido (capa Terreno3D.CAPA_SOLIDO) en medio, a «Ocluido» (−6 dB, paso bajo a CORTE_OCLUSION);
## los bucles se reevalúan solos y cambian de bus en caliente sin cortarse; OCLUSION_ACTIVA = false → siempre «Mundo»; los dB de `Sfx.AJUSTES` siguen mandando.
## Escena mínima propia (oyente, emisor y un muro), sin cargar el Bosque.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_oclusion_sfx.gd

var _mundo: Node3D = null
var _emisor: Node3D = null


func _jugadores() -> Array:
	var r: Array = []
	for h in root.get_children():
		if h is AudioStreamPlayer3D:
			r.append(h)
	return r


func _borrar_sueltos() -> void:
	for p in _jugadores():
		(p as Node).queue_free()


func _ultimo_suelto() -> AudioStreamPlayer3D:
	var l: Array = _jugadores()
	return l.back() as AudioStreamPlayer3D if not l.is_empty() else null


func _muro() -> StaticBody3D:
	var m := StaticBody3D.new()
	m.name = "Muro"
	m.collision_layer = Terreno3D.CAPA_SOLIDO
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(6.0, 4.0, 0.6)
	cs.shape = caja
	m.add_child(cs)
	m.position = Vector3(0.0, 1.0, 5.0)
	return m


func _pausa() -> void:
	OS.delay_msec(Sfx3D.VEDA_MS + 40)
	await avanzar(1)


func _escenario() -> void:
	# --- Los buses del layout ---
	var im: int = AudioServer.get_bus_index(Sfx3D.BUS_MUNDO)
	var io: int = AudioServer.get_bus_index(Sfx3D.BUS_OCLUIDO)
	_ok("1 el bus «Mundo» existe (default_bus_layout.tres)", im >= 0, "índice %d" % im)
	_ok("1 «Mundo» a 0 dB y envía a Master", im >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(im), 0.0) and String(AudioServer.get_bus_send(im)) == "Master")
	_ok("1 el bus «Ocluido» existe", io >= 0, "índice %d" % io)
	_ok("1 «Ocluido» a −6 dB y envía a Master", io >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(io), -6.0) and String(AudioServer.get_bus_send(io)) == "Master")
	var f: AudioEffectLowPassFilter = AudioServer.get_bus_effect(io, 0) as AudioEffectLowPassFilter if io >= 0 and AudioServer.get_bus_effect_count(io) > 0 else null
	_ok("1 «Ocluido» lleva un paso bajo activo a CORTE_OCLUSION (900 Hz)", f != null and AudioServer.is_bus_effect_enabled(io, 0) and is_equal_approx(f.cutoff_hz, Sfx3D.CORTE_OCLUSION), "%s" % (str(f.cutoff_hz) if f != null else "sin filtro"))
	var fm: AudioEffectLowPassFilter = AudioServer.get_bus_effect(im, 0) as AudioEffectLowPassFilter if im >= 0 and AudioServer.get_bus_effect_count(im) > 0 else null
	_ok("1 «Mundo» lleva su paso bajo DESACTIVADO", fm != null and not AudioServer.is_bus_effect_enabled(im, 0))
	_ok("1 CORTE_OCLUSION = 900 y T_REEVALUAR_OCLUSION = 0,25", is_equal_approx(Sfx3D.CORTE_OCLUSION, 900.0) and is_equal_approx(Sfx3D.T_REEVALUAR_OCLUSION, 0.25))

	# --- Escena mínima ---
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var oyente := AudioListener3D.new()
	_mundo.add_child(oyente)
	oyente.make_current()
	_emisor = Node3D.new()
	_emisor.position = Vector3(0.0, 0.0, 10.0)
	_mundo.add_child(_emisor)
	await avanzar(3)

	# --- 2 · línea de vista → Mundo ---
	Sfx3D.OCLUSION_ACTIVA = true
	Sfx3D.play(_emisor, "goblin_grito")
	var p: AudioStreamPlayer3D = _ultimo_suelto()
	_ok("2 el sonido suelto crea su reproductor", p != null)
	if p == null:
		return
	_ok("2 sin nada en medio va a «Mundo»", String(p.bus) == "Mundo", String(p.bus))

	# --- 3 · con muro → Ocluido ---
	var muro: StaticBody3D = _muro()
	_mundo.add_child(muro)
	await avanzar(3)
	await physics_frame
	await physics_frame
	await _pausa()
	_borrar_sueltos()
	Sfx3D.play(_emisor, "goblin_grito")
	p = _ultimo_suelto()
	_ok("3 con un StaticBody3D de BoxShape3D entre medias va a «Ocluido»", p != null and String(p.bus) == "Ocluido", String(p.bus) if p != null else "sin reproductor")

	# --- 4 · un muro en otra capa NO ocluye ---
	muro.collision_layer = 1 << 3
	await physics_frame
	await physics_frame
	await _pausa()
	Sfx3D.play(_emisor, "goblin_grito")
	p = _ultimo_suelto()
	_ok("4 un cuerpo fuera de la capa de sólidos no ocluye (va a «Mundo»)", p != null and String(p.bus) == "Mundo", String(p.bus) if p != null else "sin reproductor")
	muro.collision_layer = Terreno3D.CAPA_SOLIDO
	await physics_frame
	await physics_frame

	# --- 5 · OCLUSION_ACTIVA = false ---
	Sfx3D.OCLUSION_ACTIVA = false
	await _pausa()
	Sfx3D.play(_emisor, "goblin_grito")
	p = _ultimo_suelto()
	_ok("5 OCLUSION_ACTIVA = false: con muro sigue en «Mundo»", p != null and String(p.bus) == "Mundo", String(p.bus) if p != null else "sin reproductor")
	Sfx3D.OCLUSION_ACTIVA = true

	# --- 6 · los dB de AJUSTES siguen mandando ---
	Sfx.AJUSTES["goblin_grito"] = -21.0
	await _pausa()
	Sfx3D.play(_emisor, "goblin_grito")
	p = _ultimo_suelto()
	_ok("6 con el sonido ocluido, el volumen del reproductor es el de AJUSTES (−21)", p != null and String(p.bus) == "Ocluido" and is_equal_approx(p.volume_db, -21.0), "bus %s, %.1f dB" % [String(p.bus), p.volume_db] if p != null else "")
	Sfx.AJUSTES.erase("goblin_grito")
	_borrar_sueltos()
	await avanzar(2)

	# --- 7 · ambiente: cambia de bus en caliente ---
	_mundo.remove_child(muro)
	await physics_frame
	await physics_frame
	var amb: AudioStreamPlayer3D = Sfx3D.ambiente(_emisor, "fuego")
	_ok("7 el ambiente se crea", amb != null)
	if amb == null:
		return
	await avanzar(10)
	# `Sfx3D.ambiente` arranca en un punto al azar; con el audio ficticio de headless, un bucle que arranca pasada la mitad de este archivo (>~1,4 s de 2,87) se para
	# (medido igual con un AudioStreamPlayer3D pelado, sin nada de la oclusión). Para que la prueba no dependa del azar se reinicia desde 0.
	amb.play(0.0)
	await avanzar(2)
	_ok("7 sin muro el bucle suena por «Mundo»", String(amb.bus) == "Mundo", String(amb.bus))
	_ok("7 suena", amb.playing)
	var t0: float = amb.get_playback_position()
	await avanzar_reloj(amb.stream.get_length() + 0.4)
	_ok("7 (control) sin tocar nada el bucle sigue sonando tras dar más de una vuelta", amb.playing, "pos %.3f de %.3f" % [amb.get_playback_position(), amb.stream.get_length()])
	t0 = amb.get_playback_position()
	_mundo.add_child(muro)
	await physics_frame
	await physics_frame
	await avanzar_reloj(Sfx3D.T_REEVALUAR_OCLUSION + 0.3)
	_ok("7 al interponer el muro, el bucle pasa a «Ocluido» solo", String(amb.bus) == "Ocluido", String(amb.bus))
	_ok("7 y sigue sonando (playing true)", amb.playing)
	var t1: float = amb.get_playback_position()
	_ok("7 sin reiniciarse (la posición no vuelve a 0)", t1 > 0.0 or t0 == 0.0, "antes %.3f, después %.3f" % [t0, t1])
	_mundo.remove_child(muro)
	await physics_frame
	await physics_frame
	await avanzar_reloj(Sfx3D.T_REEVALUAR_OCLUSION + 0.3)
	_ok("7 al quitar el muro vuelve a «Mundo»", String(amb.bus) == "Mundo", String(amb.bus))
	_ok("7 y sigue sonando", amb.playing)
	Sfx3D.OCLUSION_ACTIVA = false
	_mundo.add_child(muro)
	await physics_frame
	await physics_frame
	await avanzar_reloj(Sfx3D.T_REEVALUAR_OCLUSION + 0.3)
	_ok("7 con OCLUSION_ACTIVA = false el bucle ignora el muro (siempre «Mundo»)", String(amb.bus) == "Mundo", String(amb.bus))
	Sfx3D.OCLUSION_ACTIVA = true

	# --- 8 · panel F3 ---
	var ent: Array = LabHechizos3D.entradas()
	var nombres: Array = []
	for e in ent:
		nombres.append(String(e["n"]))
	var ii: int = nombres.find(LabHechizos3D.DB_BUS)
	_ok("8 el panel F3 tiene «dB:Interfaz (bus)», «dB:Mundo (bus)» y «dB:Ocluido (bus)»", ii >= 0 and nombres.has("dB:Mundo (bus)") and nombres.has("dB:Ocluido (bus)"))
	_ok("8 las filas nuevas van al FINAL (no mueven índices) y SQUASH_XZ sigue siendo la 7", nombres.find("dB:Mundo (bus)") > ii and nombres[nombres.size() - 3] == "dB:Ocluido (bus)" and nombres[nombres.size() - 2] == "S:HORA" and nombres.back() == "S:DURACION_DIA_S" and nombres[7] == "SQUASH_XZ")
	LabHechizos3D.impacto_poner("dB:Mundo (bus)", -3.0)
	LabHechizos3D.impacto_poner("dB:Ocluido (bus)", -9.0)
	_ok("8 mover las filas cambia los buses", is_equal_approx(AudioServer.get_bus_volume_db(im), -3.0) and is_equal_approx(AudioServer.get_bus_volume_db(io), -9.0)
		and is_equal_approx(LabHechizos3D.impacto_valor("dB:Mundo (bus)"), -3.0))
	LabHechizos3D.impacto_poner("dB:Mundo (bus)", 0.0)
	LabHechizos3D.impacto_poner("dB:Ocluido (bus)", -6.0)

	Sfx3D.parar(amb)
	_borrar_sueltos()


## Avanza `s` segundos de reloj de pared (los Timer del árbol corren con el tiempo del motor).
func avanzar_reloj(s: float) -> void:
	var fin: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame
