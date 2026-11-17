extends SceneTree

## PRUEBA del DUMMY DE ESTADOS del lab (laboratorios/lab_dummy_estados.gd, 18/11/2026). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_lab_dummy_estados.gd
## Comprueba que el dummy queda en el estado que dice `Combate3D.decidir_golpe` (las reglas del juego, no unas propias): cada elemento deja su estado, las combinaciones
## reaccionan (fuego sobre mojado = vapor y lo seca; hielo sobre mojado congela más; rayo sobre congelado lo rompe), los relojes se gastan y el texto del panel lo cuenta.
## 19/11: y que el HAZ de hielo se corta en su tope, avisa una vez al llegar (ahí se congela el dummy) y hace crecer su corona.

var _fallos: int = 0


func _ok(texto: String, bien: bool) -> void:
	print(("  OK   " if bien else "  FALLO ") + texto)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var d: LabDummyEstados = LabDummyEstados.new()
	root.add_child(d)
	await process_frame
	_ok("recién puesto: sin estados y el panel lo dice", d.activos().is_empty() and d.texto().contains("sin estados"))
	for el in LabDummyEstados.RUNAS:
		_ok("hay runa de serie para «%s»" % el, ResourceLoader.exists("res://nucleo/%s_rune.tres" % String(LabDummyEstados.RUNAS[el])))
	# cada elemento, sobre el dummy limpio, lo deja como dice el juego
	var ref: Combate3D = Combate3D.new()
	for el in ["fuego", "agua", "hielo", "rayo", "magma", "naturaleza", "viento", "tierra"]:
		d.limpiar()
		var h: Hechizo = Hechizo.construir(load("res://nucleo/%s_rune.tres" % String(LabDummyEstados.RUNAS[el])), {})
		var esp: Dictionary = ref.decidir_golpe(h)
		d.aplicar(el)
		_ok("%s: quemando %.1f, mojado %.1f, congelado %.1f, enraizado %.1f = los de decidir_golpe" % [el, d.quemando, d.mojado, d.congelado, d.enraizado],
			is_equal_approx(d.quemando, float(esp["quemando"])) and is_equal_approx(d.mojado, float(esp["mojado"])) and is_equal_approx(d.congelado, float(esp["congelado"]))
			and is_equal_approx(d.enraizado, float(esp["enraizado"])))
		_ok("%s: aturdido %.1f y envenenado %.1f = lo que dice la runa cuando toca" % [el, d.aturdido, d.envenenado],
			is_equal_approx(d.aturdido, h.aturde if bool(esp["aturde"]) else 0.0) and is_equal_approx(d.envenenado, h.veneno if bool(esp["veneno"]) else 0.0))
		_ok("%s: el panel nombra el golpe y sus reacciones (%s)" % [el, ", ".join(PackedStringArray(esp["avisos"]))], d.texto().contains(el.to_upper()) and d.ultimo["avisos"] == esp["avisos"])
	ref.free()
	# combinaciones
	d.limpiar()
	d.aplicar("agua")
	var moj: float = d.mojado
	d.aplicar("fuego")
	_ok("agua y luego fuego: vapor, lo seca y no prende (mojado %.1f → %.1f, quemando %.1f)" % [moj, d.mojado, d.quemando], moj > 0.0 and d.mojado <= 0.0 and d.quemando <= 0.0 and bool(d.ultimo["vapor"]))
	d.limpiar()
	d.aplicar("hielo")
	var seco: float = d.congelado
	d.limpiar()
	d.aplicar("agua")
	d.aplicar("hielo")
	_ok("hielo sobre mojado congela más (%.1f s) que sobre seco (%.1f s)" % [d.congelado, seco], d.congelado > seco and seco > 0.0)
	d.aplicar("rayo")
	_ok("rayo sobre congelado: ROTO y se acaba el hielo (congelado %.1f)" % d.congelado, bool(d.ultimo["roto"]) and d.congelado <= 0.0)
	# los relojes se gastan
	d.limpiar()
	d.aplicar("fuego")
	var q0: float = d.quemando
	var t: float = 0.0
	while t < 0.4:
		await process_frame
		t += root.get_process_delta_time()
	_ok("el reloj corre: quemando %.2f → %.2f en %.2f s" % [q0, d.quemando, t], d.quemando < q0 - 0.2 and d.quemando > 0.0)
	_ok("con un estado activo el panel lo lista con sus segundos", d.texto().contains("QUEMANDO"))
	# el congelado pone su efecto (de hermano) y se quita solo
	d.limpiar()
	d.aplicar("hielo")
	await process_frame
	var ct: Variant = d.get_meta(CongeladoToy.META, null)
	_ok("congelado: lleva el CongeladoToy", ct != null and is_instance_valid(ct) and not (ct as CongeladoToy).soltado())
	d.limpiar()
	await process_frame
	await process_frame
	_ok("…y al limpiarlo el efecto se suelta", ct != null and is_instance_valid(ct) and (ct as CongeladoToy).soltado())
	# 19/11: el HAZ de hielo se corta en lo que toca, avisa UNA vez al llegar y su corona crece desde ahí; el aviso es lo que usa el lab para congelar al dummy
	d.limpiar()
	var haz: HieloToy = HieloToy.new()
	haz.definir(HieloToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	haz.haz_tope = 1.2
	haz.haz_tope_radio = LabDummyEstados.RADIO
	var avisos: Array = [0]
	haz.haz_llego.connect(func() -> void:
		avisos[0] = int(avisos[0]) + 1
		d.aplicar("hielo"))
	root.add_child(haz)
	haz.lanzar(-1.0)
	await process_frame
	_ok("haz de hielo: antes de llegar no ha avisado y el dummy no está congelado", int(avisos[0]) == 0 and d.congelado <= 0.0)
	var t2: float = 0.0
	while t2 < HieloToy.T_NACER_HAZ_SELLO + HieloToy.HAZ_CORONA_CRECE_S + 0.3:
		await process_frame
		t2 += root.get_process_delta_time()
	var es: Dictionary = haz.estado_sello()
	_ok("haz de hielo: se corta en el tope (largo %.2f m de 1,20; sin tope serían 3,00)" % float(es["largo"]), float(es["largo"]) <= 1.2 + 0.001 and float(es["largo"]) > 1.0)
	_ok("haz de hielo: avisa UNA vez al llegar (%d) y ahí el dummy queda congelado (%.1f s)" % [int(avisos[0]), d.congelado], int(avisos[0]) == 1 and d.congelado > 0.0)
	_ok("haz de hielo: el sello está abierto y la corona ha crecido desde el impacto (%d cristales, crecida %.2f)" % [int(es["corona"]), float(es["crecida"])],
		float(es["abre"]) > 0.9 and int(es["corona"]) >= 8 and float(es["crecida"]) >= 0.99)
	haz.queue_free()
	d.queue_free()
	await process_frame
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
