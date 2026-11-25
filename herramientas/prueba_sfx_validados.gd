extends SceneTree
var fallos: int = 0
func ok(b: bool, texto: String) -> void:
	print(("OK " if b else "FALLO ") + texto)
	if not b: fallos += 1
func _initialize() -> void: call_deferred("probar")
func probar() -> void:
	Estado.nuevo()
	Flags.nuevo()
	var ui := TiendaUI.new()
	root.add_child(ui)
	await process_frame
	Estado.i().oro = 50
	Tiendas.abrir("alquimista")
	await process_frame
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	Sfx._ultima.clear()
	ok(ui.comprar(), "compra real realizada")
	ok(Sfx.veces("comprar") == 1 and Sfx.veces("moneda") == 0, "la tienda usa el sonido elegido al comprar")
	ui.cambiar_modo(true)
	await process_frame
	Sfx._ultima.clear()
	ok(ui.vender(), "venta real realizada")
	ok(Sfx.veces("comprar") == 2 and Sfx.veces("moneda") == 0, "la tienda usa el mismo sonido elegido al vender")
	ui.cerrar()
	ui.queue_free()
	ok(Sfx.archivos_de(Sfx.CATALOGO["comprar"]) == ["kenney_comprar_0.ogg"], "compra: solo variante 1")
	ok(Sfx.archivos_de(Sfx.CATALOGO["ui_tick"]) == ["kenney_clic_1.ogg"], "menú: solo clic 2")
	ok(Sfx.archivos_de(Sfx.CATALOGO["recoger"]) == ["kenney_recoger_0.ogg"], "recogida: solo clic 1")
	ok(absf(db_to_linear(float(Sfx.CATALOGO["comprar"]["db"]) + 8.0) - 0.8) < 0.0001, "compra: amplitud anterior multiplicada por 0,8")
	for archivo in Sfx.archivos_de(Sfx.CATALOGO["pagina"]):
		var s: AudioStream = load("res://audio/" + String(archivo))
		ok(s != null and s.get_length() <= 0.4, "recorte de página menor que la animación: " + String(archivo))
	var l := Lanzador3D.new()
	root.add_child(l)
	Sfx._ultima.clear()
	Sfx.vaciar_registro()
	l._sonar_fase_v2("carga", "agua")
	ok(Sfx.veces("agua_carga") == 1 and Sfx.veces("conjuro_arcano") == 1, "la carga combina el elemento con escritura")
	l.queue_free()
	Sfx.REGISTRAR = false
	print("TOTAL DE FALLOS: ", fallos)
	quit(1 if fallos else 0)
