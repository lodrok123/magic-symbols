extends SceneTree
## HORNEAR UN NIVEL GENERADO sin entrar al juego (17/11/2026). Es lo mismo que abrir el nivel y pulsar F9, pero sin ventana:
##   godot --headless --path . --script res://herramientas/generador_mapas/hornear_generado.gd -- <Nombre>
## Abre `escenas/Prueba<Nombre>.tscn` (la que exporta el generador de mapas), espera a que la maqueta coloque el nivel desde las letras
## y llama a su `hornear()`: escribe `mundo/datos_nivel/Nivel_<Nombre>.tscn`, el nivel EDITABLE en Godot (HorneadorNivel).
## Solo hornea niveles que exportó la herramienta y que aún no están horneados: no pisa nada hecho a mano.
## La última línea que escribe es `HORNEAR_RESULTADO <ruta>` (o `HORNEAR_RESULTADO ERROR <por qué>`); el botón «Hornear» la busca.

const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fin("ERROR falta el nombre del nivel")
		return
	var nombre: String = args[0]
	var est: Dictionary = Exportador.estado_destino(nombre)
	if String(est["escena"]) == "" or not bool(est["escena_nuestra"]) or String(est["mapa"]) == "" or not bool(est["mapa_nuestro"]):
		_fin("ERROR «%s» no es un nivel exportado por el generador de mapas" % nombre)
		return
	if String(est["horneado"]) != "":
		_fin("ERROR ya existe %s: no se vuelve a hornear encima" % String(est["horneado"]).get_file())
		return
	var ps: PackedScene = load(String(est["escena"])) as PackedScene
	if ps == null:
		_fin("ERROR no se pudo cargar %s" % String(est["escena"]))
		return
	var esc: Node = ps.instantiate()
	root.add_child(esc)
	# La maqueta coloca el nivel en su _ready; se le dejan unos fotogramas para que acabe lo que hace en diferido.
	for _i in range(90):
		await process_frame
	if not esc.has_method("hornear"):
		_fin("ERROR la escena no es una maqueta que sepa hornear")
		return
	var ruta: String = String(esc.call("hornear"))
	_fin(ruta if ruta != "" else "ERROR la maqueta no horneó nada (mira lo que escribió arriba)")


func _fin(resultado: String) -> void:
	print("HORNEAR_RESULTADO ", resultado)
	quit(1 if resultado.begins_with("ERROR") else 0)
