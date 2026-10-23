extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LAS PIEZAS DE LOS MAPAS ABIERTOS (23/10). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_mapa_abierto.gd -- [carpeta]   (por defecto res://docs/capturas/mapa_abierto)
## · jarron_1_entero, jarron_2_rompiendose, jarron_3_roto_con_botin: el jarrón de C1 antes de romperse, con los trozos en el aire y con los restos y las monedas en el suelo.
## · rotulo_entrada_zona: el rótulo «La Cueva» la primera vez que se entra en la zona de la boca.
## · transicion_1_fundido_sale, transicion_2_fundido_entra: el fundido a negro al pisar la boca de la Cueva. El Bosque 01 v01 aún no existe: se le da de alta con la escena del
##   Bosque 01 (`Niveles.registrar`), que NO tiene la entrada `boca_cueva`, así que la jugadora aparece donde nace.

const RUTA: String = "res://escenas/PruebaCueva.tscn"

var _dir: String = "res://docs/capturas/mapa_abierto"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(30)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	maqueta.set("_tam_camara", 9.0)
	if cam != null:
		cam.size = 9.0

	# Rótulo: salir de la zona, quitar la flag de «ya visto» y volver a entrar.
	colocar_jugador(Vector2i(4, 4))
	await avanzar_s(0.5)
	Flags.i().quitar("cueva.rotulo.1_11_visto")
	colocar_jugador(Vector2i(4, 15))
	await avanzar_s(1.6)
	_foto("rotulo_entrada_zona")
	await avanzar_s(4.0)

	# Jarrón de C1: entero, rompiéndose, roto con botín.
	var jarron: Rompible3D = z.nodo("jarron_c6a") as Rompible3D        # el de la esquina de C6 (17,11): contra la pared del fondo se ve entero; los de la fila 18 los tapa el muro sur
	colocar_jugador(Vector2i(16, 12))            # pegada al jarrón: la cámara sigue a la jugadora y el jarrón queda a su lado
	await avanzar_s(1.0)
	_foto("jarron_1_entero")
	if jarron != null:
		Rompible3D.tirada_forzada = 0.99
		jarron.golpear(jugador.position)
		await avanzar_s(0.22)
		_foto("jarron_2_rompiendose")
		await avanzar_s(1.0)
		_foto("jarron_3_roto_con_botin")
	Rompible3D.tirada_forzada = Rompible3D.PROB_FORZADA_NINGUNA

	# Transición: pisar la boca. El Bosque 01 v01 todavía no existe: hace de él la escena del Bosque 01.
	Niveles.registrar("Bosque_01_v01", "res://escenas/PruebaBosque01.tscn")
	colocar_jugador(Vector2i(4, 16))
	await avanzar_s(0.5)
	colocar_jugador(Vector2i(4, 18))
	var foto1: bool = false
	var foto2: bool = false
	var alto: bool = false
	var pared: int = Time.get_ticks_msec()
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 3000:
		await process_frame
	pared = Time.get_ticks_msec()
	while Niveles.en_curso and Time.get_ticks_msec() - pared < 120000:
		var al: float = Niveles.alfa_fundido(self)
		if al >= 0.99:
			alto = true
		if not alto and not foto1 and al >= 0.5:
			foto1 = true
			_foto("transicion_1_fundido_sale")
		if alto and not foto2 and al >= 0.0 and al <= 0.6:
			foto2 = true
			_foto("transicion_2_fundido_entra")
		await process_frame
	_refrescar()
	await avanzar_s(0.5)
	_foto("transicion_3_llegada")
	_ok("la transición hizo fundido de salida y de entrada y terminó", foto1 and foto2 and not Niveles.en_curso, "salida=%s entrada=%s" % [foto1, foto2])


func _refrescar() -> void:
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)
