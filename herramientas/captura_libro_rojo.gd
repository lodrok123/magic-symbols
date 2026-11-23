extends "res://herramientas/escenario_base.gd"
## FOTOS DEL LIBRO ROJO (libro de prueba, 22/11, sesión HECHIZOS). Con ventana:
##   godot --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/captura_libro_rojo.gd -- <carpeta>

var _dir: String = ""
var _lr: LibroRojo = null


func foto(nombre: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)


func _trazos(nombre: String, escala: float = 120.0) -> Array:
	var c: Vector2 = _lr.zona_trazado()["centro"]
	var salida: Array = []
	for poli in LibroRojo.polilineas(nombre):
		var pts := PackedVector2Array()
		for q in poli:
			pts.append(c + (q as Vector2) * escala)
		var denso := PackedVector2Array([pts[0]])
		for j in range(1, pts.size()):
			for k in range(1, 9):
				denso.append(pts[j - 1].lerp(pts[j], float(k) / 8.0))
		salida.append(denso)
	return salida


func _escribir(destino: String, nombre: String) -> void:
	_lr.elegir_destino(destino)
	_lr.cerrar_gesto(_trazos(nombre))
	await avanzar(24)


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
		DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://laboratorios/LabLibroRojo.tscn", false)
	for _i in range(60):
		if paused:
			break
		await process_frame
	_lr = root.find_child("LibroRojo", true, false) as LibroRojo
	if _lr == null:
		return
	lanzador.select_page(0)
	lanzador.clear_sequence()
	_lr.elegir_destino("nucleo")
	await avanzar(4)
	await foto("01_vacio_nucleo_elegido")
	await _escribir("nucleo", "fuego")
	_lr.elegir_destino("hueco:0")
	_lr.cerrar_gesto(_trazos("flecha"))
	await avanzar(8)
	await foto("02_tinta_escribiendo_flecha")
	await avanzar(20)
	await foto("03_fuego_y_flecha_escritos")
	_lr.elegir_destino("hueco:1")
	var c0: Vector2 = _lr.zona_trazado()["centro"]
	var espiral := PackedVector2Array()
	for k in range(60):
		var a: float = float(k) * 0.45
		espiral.append(c0 + Vector2(cos(a), sin(a)) * (10.0 + float(k) * 2.0))
	_lr.cerrar_gesto([espiral])
	await avanzar(4)
	await foto("04_trazo_no_reconocido_se_queda")
	_lr._trazos.clear()
	_lr._trazo_rechazado = false
	_lr.aviso = ""
	await _escribir("hueco:3", "repeticion")
	_lr.cambiar_orden(true)
	await avanzar(4)
	await foto("05_orden_por_huecos")
	_lr.cambiar_orden(false)
	_lr.elegir_destino("nucleo2")
	_lr.cerrar_gesto(_trazos("tierra"))
	await avanzar(10)
	await foto("06_combinando_transicion")
	await avanzar(30)
	await foto("07_magma_combinado")
	_lr._pulsar("catalogo")
	await avanzar(3)
	await foto("08_catalogo_con_capacidad")
	_lr._pulsar("catalogo")
	_lr.separar_sellos()
	# 2.ª vuelta: ayuda al dibujo (práctica animada desde el catálogo).
	_lr.elegir_destino("hueco:2")
	_lr._pulsar("catalogo")
	_lr._pulsar("practica:barrera")
	await avanzar(20)
	await foto("10_practica_barrera_animada")
	_lr._pulsar("sin_practica")
	_lr.elegir_destino("hueco:4")
	await avanzar(3)
	await foto("11_guia_de_la_familia")
	# 2.ª vuelta: anidación EDITABLE.
	lanzador.clear_sequence()
	_lr._pulsar("vaciar")
	_lr._pulsar("anidacion")
	await _escribir("nucleo", "fuego")
	await _escribir("hueco:0", "flecha")
	await _escribir("hueco:1", "repeticion")
	await _escribir("hijo_nucleo", "tierra")
	_lr.elegir_destino("hijo_hueco:0")
	await avanzar(3)
	await foto("12_anidacion_hijo_seleccionado")
	await _escribir("hijo_hueco:0", "barrera")
	_lr.elegir_destino("condicion")
	_lr.siguiente_condicion()
	await avanzar(3)
	await foto("13_anidacion_condicion_al_acabar")
	_lr.elegir_destino("hueco:1")
	_lr.mover_glifo_al_otro_circulo()
	await avanzar(3)
	await foto("14_anidacion_glifo_movido_al_hijo")
	_lr._pulsar("vaciar")
	_lr._pulsar("anidacion")
	lanzador.clear_sequence()
	# 5.ª vuelta: las notas del personaje y el cuaderno.
	await _escribir("nucleo", "fuego")
	_lr.elegir_destino("nucleo")
	await avanzar(3)
	await foto("17_notas_sellos_con_el_nucleo")
	_lr.elegir_destino("hueco:1")
	var rombo: Array = _trazos("barrera")
	var medio := PackedVector2Array()
	for j in range(int((rombo[0] as PackedVector2Array).size() * 0.5)):
		medio.append(rombo[0][j])
	_lr._trazos = [medio]
	await avanzar(3)
	await foto("18_notas_glifos_a_medio_dibujar")
	_lr._trazos = rombo
	await avanzar(3)
	await foto("19_notas_la_barrera_va_ganando")
	_lr._trazos.clear()
	var c1: Vector2 = _lr.zona_trazado()["centro"]
	var esp := PackedVector2Array()
	for k in range(60):
		esp.append(c1 + Vector2(cos(float(k) * 0.45), sin(float(k) * 0.45)) * (10.0 + float(k) * 2.0))
	_lr.cerrar_gesto([esp])
	await avanzar(3)
	await foto("20_notas_intento_tachado")
	_lr._trazos.clear()
	_lr._trazo_rechazado = false
	_lr.aviso = ""
	_lr._pulsar("nota:barrera")
	var pc: Vector2 = _lr.caja_practica().get_center()
	var esc_p: float = _lr.caja_practica().size.x * 0.6
	var prac: Array = []
	for poli in LibroRojo.polilineas("barrera"):
		var d := PackedVector2Array()
		for j in range(1, (poli as PackedVector2Array).size()):
			for k in range(8):
				d.append(pc + (poli[j - 1] as Vector2).lerp(poli[j], float(k) / 8.0) * esc_p)
		prac.append(d)
	_lr.evaluar_practica(prac)
	_lr._prac_trazos = prac
	await avanzar(16)
	await foto("21_cuaderno_practica_bien")
	_lr._prac_trazos.clear()
	_lr._pulsar("cerrar_cuaderno")
	lanzador.clear_sequence()
	# 3.ª vuelta: la hoja de catálogo como se vería en la demo (arranque + agua, tierra y ᛁ): candados en lo que falta.
	Lanzador3D.aplicar_progresion("demo_inicio")
	Repertoire.unlock_element("agua")
	Repertoire.unlock_element("tierra")
	Repertoire.unlock_sigil("linea")
	_lr._pulsar("catalogo")
	_lr._pulsar("cat:barrera")
	await avanzar(24)
	await foto("15_catalogo_demo_ficha_barrera")
	_lr._pulsar("cat:permanencia")
	await avanzar(4)
	await foto("16_catalogo_demo_ficha_bloqueada")
	_lr._pulsar("catalogo")
