extends SceneTree

## PRUEBA DEL GLIFO QUE SE ESCRIBE EN LA PÁGINA DERECHA (24/10, Pablo: «una vez aparezca la runa, que se dibuje en la parte derecha del libro;
## así la página derecha te recuerda los glifos que has conseguido»). Sin ventana: `tools\pruebas.cmd solo escritura_glifo`.
##   1. `Repertoire.conseguir_sigil` desbloquea y deja el glifo por escribir; `unlock_sigil` a secas (nivel, partida cargada) no;
##   2. el libro abierto lo recoge, lo escribe por tiempos (espera, trazo, nombre, halo) y lo suelta al acabar; dos glifos van uno detrás de otro;
##   3. lo que ya no está activo cuando se abre el libro no se escribe;
##   4. el icono del aviso acepta «glifo:<id>».
## Con ventana y una ruta (`-- <salida.png>`) guarda además tres capturas: a mitad del trazo, con el nombre y terminado.

var fallos: int = 0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else ""
	Estado.nuevo()
	Repertoire.libro = "bosque"
	Repertoire.reset_to_p0()
	Repertoire.max_sigils_per_page = 0
	root.size = Vector2i(1280, 720)

	# 1. Repertoire
	Repertoire.tomar_por_escribir()
	_ok(Repertoire.unlock_sigil("rebote") and Repertoire.tomar_por_escribir().is_empty(), "unlock_sigil a secas no deja nada por escribir")
	_ok(Repertoire.conseguir_sigil("raido") and Repertoire.sigil_active("raido"), "conseguir_sigil desbloquea ᚱ")
	_ok(not Repertoire.conseguir_sigil("raido"), "y la segunda vez dice que no era nuevo")
	_ok(Repertoire.tomar_por_escribir() == PackedStringArray(["raido"]) and Repertoire.tomar_por_escribir().is_empty(), "queda una vez por escribir y tomarlo lo vacía")
	Repertoire.conseguir_sigil("retardo")
	Repertoire.lock_sigil("retardo")
	_ok(Repertoire.tomar_por_escribir().is_empty(), "lo que se bloqueó antes de abrir el libro no se escribe")

	# 2. El libro
	var grimorio: Node = load("res://magia/grimorio.gd").new()
	root.add_child(grimorio)
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	for _i in range(4):
		await process_frame
	Repertoire.lock_sigil("raido")
	Repertoire.conseguir_sigil("raido")
	Repertoire.lock_sigil("repeticion")
	Repertoire.conseguir_sigil("repeticion")
	_ok(libro._escribiendo.is_empty(), "con el libro cerrado no se empieza a escribir")
	libro.is_open = true
	libro.visible = true
	_ok(libro._empezar_escrituras() == 2 and libro._escribiendo.size() == 2, "al abrir recoge los dos glifos")
	var t_raido: float = float(libro._escribiendo["raido"])
	var t_rep: float = float(libro._escribiendo["repeticion"])
	_ok(t_raido < 0.0 and t_rep < t_raido - 0.5, "esperan su turno, uno detrás del otro (%.2f y %.2f s)" % [t_raido, t_rep])
	var dur: float = libro._duracion_escritura()
	libro._avanzar_escrituras(-t_raido + libro.ESCRITURA_TRAZO * 0.5)
	_ok(libro._escribiendo.has("raido") and float(libro._escribiendo["raido"]) > 0.0, "ᚱ está a mitad del trazo")
	if salida != "":
		await _captura(libro, salida.replace(".png", "_trazo.png"))
	libro._avanzar_escrituras(libro.ESCRITURA_TRAZO * 0.5 + libro.ESCRITURA_NOMBRE)
	if salida != "":
		await _captura(libro, salida.replace(".png", "_nombre.png"))
	libro._avanzar_escrituras(dur)
	_ok(not libro._escribiendo.has("raido"), "acabado, ᚱ ya no está en la cola (se pinta como siempre)")
	libro._avanzar_escrituras(dur * 2.0)
	_ok(libro._escribiendo.is_empty(), "y la cola se vacía")
	if salida != "":
		await _captura(libro, salida.replace(".png", "_hecho.png"))

	# 4. El icono del aviso
	var icono := MarcoCalidad.Icono.new()
	icono.configurar_calidad(MarcoCalidad.PREFIJO_GLIFO + "raido", Objetos.CALIDAD_LEGENDARIO)
	root.add_child(icono)
	await process_frame
	_ok(icono.calidad == Objetos.CALIDAD_LEGENDARIO and Sigils.GLYPHS.has("raido"), "el icono del aviso acepta «glifo:raido» con marco legendario")
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


func _captura(libro: Control, ruta: String) -> void:
	for _i in range(3):
		libro.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png(ruta)
	print("guardada ", ruta)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)
