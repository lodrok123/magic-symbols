extends SceneTree

## PRUEBA DEL LIBRO «BOSQUE» (lámina grimorio_bosque.png; 16/10, Juego). Sin ventana: `tools\prueba_una.cmd prueba_libro_bosque`.
##
## Comprueba lo que se pidió en el diario 112 sobre `spellbook.gd` con los datos medidos de ARTE §16:
##   1. el sello está DESPLAZADO respecto al círculo exterior (≈ 99 px arriba) y un trazo dentro de él es un elemento;
##   2. los huecos de glifo se abren por orden (abajo → abajo-izq → abajo-der) según los glifos por página;
##   3. un hueco cerrado no admite trazo y un trazo ya no se lleva «al hueco más cercano» si ese está cerrado;
##   4. el aro suelto del hueco se carga y la página derecha trae 6 círculos de sello y 9 óvalos de glifo;
##   5. el bloque de páginas cabe en pantalla.
## No comprueba el aspecto: eso se mira en pantalla (ver la captura aparte si se hizo).

var fallos: int = 0


func _init() -> void:
	Estado.nuevo()
	Repertoire.libro = "bosque"
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	libro.visible = true
	var d: Dictionary = libro._libro()
	_ok(not d.is_empty(), "la lámina «bosque» se carga (existe el PNG)")
	if d.is_empty():
		quit(1)
		return
	_ok(libro._hueco_tex != null and libro._hueco_tex.get_width() == 140, "el aro suelto del hueco (140 × 140) se carga")

	# 1. El sello desplazado
	var desp: Vector2 = libro._core_c() - libro._circ_c()
	_ok(absf(desp.x - 1.8) < 0.01 and absf(desp.y + 99.3) < 0.01, "el sello está %.1f, %.1f px de lámina respecto al círculo exterior (medido: 1,8 y −99,3)" % [desp.x, desp.y])
	_ok(libro._sector_of_point(libro._on_page(Vector2(433.7, 383.1))) == Vector2.ZERO, "un trazo en el centro del sello es un elemento (sector cero)")
	_ok(libro._sector_of_point(libro._on_page(Vector2(433.7, 383.1 + 150.0))) != Vector2.ZERO, "y 150 px por debajo del centro del sello, ya fuera de él, no lo es")
	var radio_sello: float = libro._u(libro._core_u())
	var esperado: float = 119.6 * libro._book_rect().size.x / libro.BOOK_SIZE.x
	_ok(absf(radio_sello - esperado) < 0.5, "el radio del sello en pantalla es el medido (%.1f px, esperado %.1f)" % [radio_sello, esperado])

	# 2 y 3. Huecos por orden
	var centro_hueco: Dictionary = {2: Vector2(431.4, 628.1), 3: Vector2(305.4, 578.7), 1: Vector2(557.3, 578.7)}
	var angulo: Dictionary = {2: PI * 0.5, 3: PI * 0.75, 1: PI * 0.25}
	Repertoire.max_sigils_per_page = 0
	_ok(libro._huecos_abiertos().is_empty(), "con 0 glifos por página no hay ningún hueco abierto")
	for k in centro_hueco:
		_ok(libro._sector_of_point(libro._on_page(centro_hueco[k])) == libro.SIN_HUECO, "0 abiertos: un trazo en el hueco %d no va a ningún sitio (SIN_HUECO, no es un elemento)" % k)
	Repertoire.max_sigils_per_page = 1
	_ok((libro._huecos_abiertos() as Dictionary).keys() == [2], "con 1 glifo por página solo se abre el de abajo (sector 2): %s" % str((libro._huecos_abiertos() as Dictionary).keys()))
	for k in [3, 1]:
		var s: Vector2 = libro._sector_of_point(libro._on_page(centro_hueco[k]))
		_ok(s != libro.SIN_HUECO and s.is_equal_approx(Vector2(cos(PI * 0.5), sin(PI * 0.5))), "1 abierto: un trazo sobre el hueco CERRADO %d se lleva al abierto (abajo), no al cerrado" % k)
	Repertoire.max_sigils_per_page = 2
	_ok((libro._huecos_abiertos() as Dictionary).keys() == [2, 3], "con 2 se abren abajo y abajo-izquierda: %s" % str((libro._huecos_abiertos() as Dictionary).keys()))
	var s1: Vector2 = libro._sector_of_point(libro._on_page(centro_hueco[1]))
	_ok(s1.is_equal_approx(Vector2(cos(PI * 0.5), sin(PI * 0.5))), "2 abiertos: el hueco abajo-derecha, aún cerrado, no atrae (el más cercano abierto es el de abajo)")
	Repertoire.max_sigils_per_page = 3
	_ok((libro._huecos_abiertos() as Dictionary).keys() == [2, 3, 1], "con 3 están los tres")
	for k in centro_hueco:
		var s2: Vector2 = libro._sector_of_point(libro._on_page(centro_hueco[k]))
		_ok(s2.is_equal_approx(Vector2(cos(angulo[k]), sin(angulo[k]))), "3 abiertos: el trazo en el hueco %d da su sector (%.0f°)" % [k, rad_to_deg(angulo[k])])
	Repertoire.max_sigils_per_page = 9
	_ok((libro._huecos_abiertos() as Dictionary).size() == 3, "con más glifos por página que huecos no se inventan huecos (siguen 3)")

	# La paleta de pruebas (F1) respeta los huecos: sectores_abiertos() da los vectores en el orden de apertura
	Repertoire.max_sigils_per_page = 2
	var sa: Array = libro.sectores_abiertos()
	_ok(libro.restringe_huecos() and sa.size() == 2 and (sa[0] as Vector2).is_equal_approx(Vector2(0.0, 1.0)) and (sa[1] as Vector2).is_equal_approx(Vector2(cos(PI * 0.75), sin(PI * 0.75))), "sectores_abiertos con 2 huecos: abajo y abajo-izquierda (%s)" % str(sa))
	Repertoire.max_sigils_per_page = 9
	# 4. Página derecha
	_ok((d["leyenda_sellos"] as Array).size() == 6, "la página derecha tiene 6 círculos de sello")
	_ok((d["leyenda"] as Array).size() == 9, "y 9 óvalos de glifo (rejilla 3 × 3)")
	var y_sellos: bool = true
	for p in d["leyenda_sellos"]:
		y_sellos = y_sellos and absf((p as Vector2).y - 276.8) < 0.01
	_ok(y_sellos, "los 6 sellos están en la misma fila (y = 276,8)")

	# 5. Bloque de páginas
	var rect: Rect2 = libro._book_rect()
	var pb: Rect2 = libro._page_block()
	var a: Vector2 = libro._on_page(pb.position)
	var b: Vector2 = libro._on_page(pb.end)
	_ok(a.x >= -0.5 and a.y >= -0.5 and b.x <= 1280.5 and b.y <= 720.5, "el bloque de páginas cabe en 1280 × 720 (%s a %s)" % [a, b])
	_ok(absf((a.x + b.x) * 0.5 - 640.0) < 1.0 and absf((a.y + b.y) * 0.5 - 360.0) < 1.0, "y queda centrado")

	# Las láminas de siempre no cambian
	Repertoire.libro = ""
	libro._libro_cache = "?"
	_ok(libro._libro().is_empty() and libro._core_c() == libro._circ_c() and libro._page_block() == libro.PAGE_BLOCK, "sin lámina alternativa nada cambia: núcleo en el centro y PAGE_BLOCK de siempre")
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)
