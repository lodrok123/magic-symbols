extends "res://herramientas/escenario_base.gd"
## LEGIBILIDAD DE LOS AVISOS POR CALIDAD (24/10; AvisoObjeto). NECESITA VENTANA. Una pasada por escena:
##   godot --path . --script res://herramientas/captura_avisos_calidad.gd -- <cueva|bosque> <etiqueta> [carpeta]
## Hace el aviso común, el épico y el legendario sobre cada fondo de la escena: cueva = hielo y roca oscura; bosque = hierba y arena
## (el camino). Guarda <fondo>_<calidad>_<etiqueta>.png (la etiqueta es «antes» o «despues»). La carpeta por defecto lleva .gdignore.

const RUTA_CUEVA: String = "res://escenas/PruebaCueva.tscn"
const CHARCA: Rect2i = Rect2i(20, 13, 5, 4)
const ZOOM_CAMARA: float = 7.0
const ESPERA_FONDO_S: float = 2.0       ## que se asiente la cámara y la luz tras mover a la jugadora
const ESPERA_AVISO_S: float = 0.35      ## el aviso ya está a opacidad plena
const ESPERA_ENTRE_S: float = 4.0       ## que se apague el aviso (el legendario dura 4,5 s) antes del siguiente
## Fondos: nombre, celda de la jugadora y si hay que helar la charca (solo cueva).
const FONDOS_CUEVA: Array = [["hielo", Vector2i(22, 17), true], ["cueva", Vector2i(8, 12), false]]
const FONDOS_BOSQUE: Array = [["hierba", Vector2i(4, 6), false], ["arena", Vector2i(2, 7), false]]

var _dir: String = "res://docs/capturas/avisos_calidad"


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _zoom() -> void:
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	maqueta.set("_tam_camara", ZOOM_CAMARA)
	if cam != null:
		cam.size = ZOOM_CAMARA


func _helar_charca(si: bool) -> void:
	for y in range(CHARCA.position.y, CHARCA.end.y):
		for x in range(CHARCA.position.x, CHARCA.end.x):
			Terreno3D.agua_sim.helar_casilla(Vector2i(x, y), si)
			Terreno3D.poner_helada(Vector2i(x, y), si)


## Los tres avisos. El legendario no tiene objeto en DATOS: se avisa con el texto de la calidad (AvisoObjeto.mostrar_texto).
## (Las capturas «antes» se hicieron con el código anterior, que avisaba con lanzador.avisar(texto, color claro, borde de calidad, duración).)
func _aviso_de(calidad: String) -> void:
	match calidad:
		"comun":
			AvisoObjeto.mostrar(lanzador, "seta", 1)
		"epico":
			AvisoObjeto.mostrar(lanzador, "nucleo_eco", 1)
		_:
			AvisoObjeto.mostrar_texto(lanzador, "Glifo de resonancia (+1)", Objetos.CALIDAD_LEGENDARIO)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0] if a.size() > 0 else "cueva"
	var etiqueta: String = a[1] if a.size() > 1 else "despues"
	if a.size() > 2 and a[2] != "":
		_dir = a[2]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_CUEVA if modo == "cueva" else RUTA_BOSQUE, modo == "cueva")
	if maqueta == null or jugador == null:
		return
	await avanzar(30)
	_zoom()
	for f in (FONDOS_CUEVA if modo == "cueva" else FONDOS_BOSQUE):
		colocar_jugador(f[1] as Vector2i)
		if modo == "cueva":
			_helar_charca(bool(f[2]))
		await avanzar_s(ESPERA_FONDO_S)
		for cal in ["comun", "epico", "legendario"]:
			_aviso_de(cal)
			await avanzar_s(ESPERA_AVISO_S)
			_foto("%s_%s_%s" % [f[0], cal, etiqueta])
			await avanzar_s(ESPERA_ENTRE_S)
	_ok("capturas hechas", true)
