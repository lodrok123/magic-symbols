extends SceneTree
## SONIDOS GRABADOS (27/10; OpenGameArt, CC0, ver audio/LICENCIAS.md): todo lo que piden `Sfx.CATALOGO`, `Sfx3D.CATALOGO` y `Sfx3D.AMBIENTES`
## existe y se carga (un nombre mal escrito no falla en el juego: simplemente no suena), y los ambientes de fuego (.wav) y agua (.ogg) salen en
## bucle de `Sfx3D.bucle`.
##   godot --headless --path . --script res://herramientas/prueba_sonidos_grabados.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print("%s %s  %s" % ["OK   " if bien else "FALLO", nombre, info])
	if not bien:
		_fallos += 1


func _initialize() -> void:
	var faltan: Array = []
	var n: int = 0
	for cat in [Sfx.CATALOGO, Sfx3D.CATALOGO]:
		for clave in cat:
			for f in (cat[clave] as Dictionary)["f"]:
				n += 1
				if not ResourceLoader.exists(Sfx.CARPETA + String(f)) or load(Sfx.CARPETA + String(f)) == null:
					faltan.append("%s/%s" % [clave, f])
	for clave in Sfx3D.AMBIENTES:
		n += 1
		var f: String = String((Sfx3D.AMBIENTES[clave] as Dictionary)["f"])
		if not ResourceLoader.exists(Sfx3D.CARPETA + f):
			faltan.append("%s/%s" % [clave, f])
	_ok("1 todos los sonidos del catálogo existen y se cargan", faltan.is_empty(), "%d archivos · faltan %s" % [n, str(faltan)])
	for clave in ["conjuro_arcano", "descarga_electrica", "chasquidos_electricos", "congelar", "rayo", "hielo", "arde_bucle"]:
		_ok("2 Sfx tiene «%s» con un archivo grabado (oga_)" % clave, Sfx.CATALOGO.has(clave) and String((Sfx.CATALOGO[clave]["f"] as Array)[0]).begins_with("oga_"))
	for clave in ["paso_hierba", "paso_tierra", "paso_roca", "paso_madera"]:
		_ok("2 Sfx3D tiene «%s» con pisadas grabadas" % clave, Sfx3D.CATALOGO.has(clave) and String((Sfx3D.CATALOGO[clave]["f"] as Array)[0]).begins_with("oga_"))
	var fuego: AudioStream = Sfx3D.bucle("fuego")
	_ok("3 el crepitar del fuego (.wav) sale en bucle", fuego is AudioStreamWAV and (fuego as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD and (fuego as AudioStreamWAV).loop_end > 0)
	var agua: AudioStream = Sfx3D.bucle("agua")
	_ok("3 el agua corriendo (.ogg) sale en bucle", agua != null and bool(agua.get("loop")))
	var original: AudioStream = load(Sfx3D.CARPETA + String(Sfx3D.AMBIENTES["fuego"]["f"]))
	_ok("3 el recurso importado no se toca (el bucle va en una copia)", original is AudioStreamWAV and (original as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD)
	# 10/11: foley de Sonniss («f_sn»). Los archivos sn_* no viajan en el repositorio: o están TODOS los de una entrada (y entonces suenan) o ninguno (y suena «f»).
	var n_sn: int = 0
	var a_medias: Array = []
	var mal_elegido: Array = []
	for cat in [Sfx.CATALOGO, Sfx3D.CATALOGO]:
		for clave in cat:
			var cfg: Dictionary = cat[clave]
			if not cfg.has("f_sn"):
				continue
			var hay: int = 0
			for f in cfg["f_sn"]:
				if ResourceLoader.exists(Sfx.CARPETA + String(f)) and load(Sfx.CARPETA + String(f)) != null:
					hay += 1
			if hay != 0 and hay != (cfg["f_sn"] as Array).size():
				a_medias.append(clave)
			n_sn += hay
			Sfx.SONNISS = true
			var con: Array = Sfx.archivos_de(cfg)
			Sfx.SONNISS = false
			var sin: Array = Sfx.archivos_de(cfg)
			Sfx.SONNISS = true
			if con != (cfg["f_sn"] if hay > 0 else cfg["f"]) or sin != cfg["f"]:
				mal_elegido.append(clave)
	_ok("4 las entradas con «f_sn» tienen todos sus archivos o ninguno", a_medias.is_empty(), "%d archivos sn_ aquí · a medias %s" % [n_sn, str(a_medias)])
	_ok("4 archivos_de: «f_sn» si están y SONNISS encendido; «f» si no", mal_elegido.is_empty(), str(mal_elegido))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
