extends "res://herramientas/escenario_base.gd"
## HUMEDAD: fotos del suelo mojado que se seca y de la orilla mojada (27/10). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_humedad.gd -- [carpeta] [cueva|bosque]
## (por defecto res://docs/capturas/humedad y la cueva). En la escena elegida: la orilla del agua, y agua sobre suelo seco a los 1, 10, 15,
## 18 y 22 s (empapa, entera, secándose, casi seca, seca).

const ESCENAS: Dictionary = {
	"cueva": {"ruta": "res://escenas/PruebaCuevaAgua.tscn", "orilla": Vector2i(4, 5), "suelo": Vector2i(12, 6)},
	"bosque": {"ruta": "res://escenas/PruebaBosque01_v01.tscn", "suelo": Vector2i(11, 29)},     # sin orilla: el río del v01 va entre paredes
}

var _dir: String = "res://docs/capturas/humedad"
var _cam: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	var cual: String = a[1] if a.size() > 1 and ESCENAS.has(a[1]) else "cueva"
	var datos: Dictionary = ESCENAS[cual]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(String(datos["ruta"]), true)
	if maqueta == null:
		return
	for h in root.find_children("*", "CanvasLayer", true, false):
		if not (h is TiltShift3D):
			(h as CanvasLayer).visible = false
	_cam = maqueta.get("_camara") as Camera3D
	if datos.has("orilla"):
		await _mirar(datos["orilla"], 1.5)
		await _foto(cual + "_orilla")
	var suelo: Vector2i = datos["suelo"]
	await _mirar(suelo, 0.5)
	await _foto(cual + "_seco")
	for k in 3:
		Mundo3D.aplicar_accion(AccionElemental.nueva("agua", Terreno3D.centro_de(suelo + Vector2i(k - 1, 0), 0.0)))
	var t0: float = reloj.t
	for t in [1.0, 10.0, 15.0, 18.0, 22.0]:
		await avanzar_s(t - (reloj.t - t0))
		await _foto("%s_agua_%02ds" % [cual, int(t)])
	_ok("fotos hechas", true)


## La jugadora una casilla al sur de `c` y la cámara cerrada sobre `c`.
func _mirar(c: Vector2i, espera: float) -> void:
	colocar_jugador(c + Vector2i(0, 1))
	maqueta.set("_tam_camara", 4.5)
	if _cam != null:
		_cam.size = 4.5
	await avanzar_s(espera)


func _foto(nombre: String) -> void:
	await avanzar(3)
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)
