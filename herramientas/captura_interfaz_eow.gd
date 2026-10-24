extends "res://herramientas/escenario_base.gd"
## INTERFAZ ESTILO ECHOES OF WISDOM, A LA VISTA (24/10; presentacion/ui/tema_interfaz.gd y marco_calidad.gd). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_interfaz_eow.gd -- <etiqueta> [carpeta]
## Etiqueta «antes» o «despues» (va al final del nombre del archivo). Carpeta por defecto: res://docs/capturas/interfaz_eow (lleva .gdignore).
## Fotos (la escena es el bosque): la bolsa con objetos de las tres calidades · el rótulo de zona · el HUD de vida y tinta (recorte) ·
## la pista de interacción «E» y las barras de vida y tinta nuevas (solo «despues»: antes no existían como pieza suelta).
## Los avisos sobre hielo, hierba, arena y cueva los hace captura_avisos_calidad.gd con esta misma carpeta.
## Funciona con el código de antes y de después: lo nuevo se busca por ruta, no por nombre de clase.

const OBJETOS_BOLSA: Array = [["seta", 3], ["pocion", 2], ["nucleo_eco", 1], ["geoda_resonante", 2], ["colmillo_goblin", 4], ["seta_asada", 1]]
const ID_LEGENDARIO: String = "seta_asada"          ## no hay legendarios en DATOS: la bolsa deja forzar la calidad en las pruebas (BolsaUI.calidad_prueba)
const RECORTE_HUD: Rect2i = Rect2i(0, 60, 520, 120)
const RECORTE_BARRAS: Rect2i = Rect2i(700, 280, 280, 90)
const ESPERA_BOLSA_S: float = 0.9
const ESPERA_ROTULO_S: float = 1.2
const RUTA_PISTA: String = "res://presentacion/ui/pista_interaccion.gd"
const RUTA_BARRA: String = "res://presentacion/ui/barra_hud.gd"

var _dir: String = "res://docs/capturas/interfaz_eow"
var _etiqueta: String = "despues"


func _foto(nombre: String, recorte: Rect2i = Rect2i()) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if recorte.size != Vector2i.ZERO:
		img = img.get_region(recorte)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(_dir.path_join("%s_%s.png" % [nombre, _etiqueta]))
	print("foto " + nombre)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_etiqueta = a[0]
	if a.size() > 1 and a[1] != "":
		_dir = a[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	for par in OBJETOS_BOLSA:
		Estado.i().agregar(String(par[0]), int(par[1]))
	Estado.i().oro = 137
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	await avanzar_s(1.5)
	# --- HUD de vida y tinta (la esquina de arriba a la izquierda) ---
	_foto("hud_vida_tinta", RECORTE_HUD)
	# --- Rótulo de zona ---
	RotuloZona3D.mostrar(maqueta, "Bosque de Terra")
	await avanzar_s(ESPERA_ROTULO_S)
	_foto("rotulo_zona")
	await avanzar_s(3.5)
	# --- Pista «E» y barras nuevas, si existen ---
	if ResourceLoader.exists(RUTA_PISTA):
		var pista: Control = (load(RUTA_PISTA) as GDScript).new() as Control
		var capa := CanvasLayer.new()
		capa.layer = 20
		root.add_child(capa)
		capa.add_child(pista)
		pista.call("mostrar", "E", "Hablar")
		await avanzar_s(0.6)
		_foto("pista_e")
		capa.queue_free()
	if ResourceLoader.exists(RUTA_BARRA):
		var capa2 := CanvasLayer.new()
		capa2.layer = 20
		root.add_child(capa2)
		var vida: Control = (load(RUTA_BARRA) as GDScript).new() as Control
		var tinta: Control = (load(RUTA_BARRA) as GDScript).new() as Control
		capa2.add_child(vida)
		capa2.add_child(tinta)
		vida.call("configurar", "Vida", Color(0.35, 0.85, 0.4), 0.8)
		tinta.call("configurar", "Tinta 74/100 · Tinta azul", Color(0.3, 0.55, 1.0), 0.74)
		vida.position = RECORTE_BARRAS.position + Vector2i(10, 8)         # en un hueco de la pantalla: el HUD de verdad ocupa la esquina
		tinta.position = RECORTE_BARRAS.position + Vector2i(10, 46)
		await avanzar_s(0.5)
		_foto("hud_barras_nuevas", RECORTE_BARRAS)
		capa2.queue_free()
	# --- La bolsa con las tres calidades ---
	var bolsa: BolsaUI = lanzador.get("mochila") as BolsaUI
	if bolsa != null:
		if "calidad_prueba" in bolsa:
			bolsa.set("calidad_prueba", {ID_LEGENDARIO: "legendario"})
		reloj.process_mode = Node.PROCESS_MODE_ALWAYS      # la bolsa pausa el árbol: el reloj del armazón tiene que seguir contando
		bolsa.alternar()
		await avanzar_s(ESPERA_BOLSA_S)
		print("bolsa abierta=", bolsa.abierta, " marco visible=", bolsa.get("_marco").visible, " pos=", bolsa.get("_marco").position, " alfa=", bolsa.get("_marco").modulate.a)
		_foto("bolsa")
		bolsa.alternar()
		await avanzar_s(0.5)
	_ok("capturas hechas", true)
