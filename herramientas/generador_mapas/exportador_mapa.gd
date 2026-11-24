extends RefCounted
## EXPORTADOR DEL GENERADOR DE MAPAS (17/11/2026). Pasa un mapa de `generador_mazmorra.gd` a los dos archivos que el juego ya sabe leer:
##   · `mundo/datos_nivel/mapas/<Nombre>.txt`   el plano de letras con sus líneas `; zona`, `; pieza` y `; puzle` (HorneadorNivel, Zonas3D, Puzle3D);
##   · `escenas/Prueba<Nombre>.tscn`            la maqueta (`prueba_test2.gd`) configurada con ese nivel y el nodo «Puzles».
## Regla de seguridad: SOLO pisa archivos que haya escrito él (los reconoce por `MARCA` en el .txt y por `metadata/generador_mapas` en la escena).
## Un mapa hecho a mano con el mismo nombre no se toca: se devuelve un error. Si el .txt generado se había retocado a mano, se guarda antes una copia.

const MARCA: String = "GENERADO por herramientas/generador_mapas"
const MARCA_ESCENA: String = "metadata/generador_mapas"
const DIR_MAPAS: String = "res://mundo/datos_nivel/mapas/"
const DIR_ESCENAS: String = "res://escenas/"
const DIR_NIVELES: String = "res://mundo/datos_nivel/"
const ESTILOS: Array[String] = ["cueva", "bosque", "pantano"]
const LUCES: Array[String] = ["cueva", "cueva_lava", "cueva_goblin", "cueva_hielo", "cueva_ruinas", "santuario", "ruinas", "bosque", "atardecer", "pantano", "hielo", "fuego", "agua", "clasico"]
## Letras que el generador puede poner en el plano.
const LETRAS_VALIDAS: String = "#.~SWAT"


static func ruta_mapa(nombre: String) -> String:
	return DIR_MAPAS + nombre + ".txt"


## La escena del nivel. Si el juego ya conoce ese nombre (`Niveles.ESCENAS`), es la escena que tiene apuntada, se llame como se llame
## (Bosque_02 → escenas/PruebaBosque02.tscn, sin el guion bajo): así, al sustituir un nivel, los viajes desde otros niveles llegan al nuevo.
static func ruta_escena(nombre: String) -> String:
	var conocidos: Dictionary = load("res://nucleo/niveles.gd").ESCENAS
	if conocidos.has(nombre):
		return String(conocidos[nombre])
	return DIR_ESCENAS + "Prueba" + nombre + ".tscn"


## "" si el nombre vale; si no, por qué no.
static func nombre_valido(nombre: String) -> String:
	if nombre == "":
		return "Falta el nombre del nivel."
	if nombre.length() > 40:
		return "El nombre es demasiado largo (40 como mucho)."
	for i in range(nombre.length()):
		var ch: String = nombre[i]
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return "El nombre solo puede llevar letras sin acento, cifras y «_» (sin espacios)."
	if nombre[0] >= "0" and nombre[0] <= "9":
		return "El nombre no puede empezar por una cifra."
	return ""


## El archivo de esa carpeta que se llama igual sin mirar mayúsculas ("" si no hay). En Windows `Cueva.txt` y `cueva.txt` son el mismo archivo.
static func _existente(carpeta: String, archivo: String) -> String:
	var d: DirAccess = DirAccess.open(carpeta)
	if d == null:
		return ""
	for f in d.get_files():
		if f.to_lower() == archivo.to_lower():
			return carpeta + f
	return ""


## Qué hay ya en el proyecto con ese nombre: {mapa, mapa_nuestro, escena, escena_nuestra, horneado}.
static func estado_destino(nombre: String) -> Dictionary:
	var res: Dictionary = {"mapa": "", "mapa_nuestro": false, "escena": "", "escena_nuestra": false, "horneado": ""}
	res["mapa"] = _existente(DIR_MAPAS, nombre + ".txt")
	if String(res["mapa"]) != "":
		res["mapa_nuestro"] = FileAccess.get_file_as_string(String(res["mapa"])).contains(MARCA)
	var re: String = ruta_escena(nombre)
	res["escena"] = _existente(re.get_base_dir() + "/", re.get_file())
	if String(res["escena"]) != "":
		res["escena_nuestra"] = FileAccess.get_file_as_string(String(res["escena"])).contains(MARCA_ESCENA)
	res["horneado"] = _existente(DIR_NIVELES, "Nivel_" + nombre + ".tscn")
	return res


static func texto_mapa(m: Dictionary) -> String:
	var p: Dictionary = m["parametros"]
	var nombre: String = String(p["nombre"])
	var st: Dictionary = m["stats"]
	var l: PackedStringArray = PackedStringArray()
	l.append_array(m["filas"])
	l.append("; " + "=".repeat(118))
	l.append(";  %s. %s. Nivel «%s», %d × %d, algoritmo «%s», semilla %d." % [MARCA, Time.get_date_string_from_system(), nombre, int(m["ancho"]), int(m["alto"]), String(p["algoritmo"]), int(p["semilla"])])
	l.append(";  %d salas, %d puertas, %d enemigos, %d cofres, %d jarrones. Escena: escenas/Prueba%s.tscn. Mientras esta cabecera siga aquí, la herramienta puede volver a escribir" % [int(st["salas"]), int(st["puertas"]), int(st["enemigos"]), int(st["cofres"]), int(st["jarrones"]), nombre])
	l.append(";  este archivo (guarda copia si lo has retocado). Para adoptarlo como nivel hecho a mano, borra la palabra GENERADO de la línea de arriba.")
	l.append("; " + "=".repeat(118))
	l.append("; # pared · . suelo · ~ agua honda · S inicio · W goblin guerrero · A goblin arquero · T brasero · g tierra pisada (pasillos) · R losas (o basalto bajo la lava) · G elemental del bosque")
	if String(p["algoritmo"]) == "bosque":
		l.append("; bosque: g camino de tierra · . claro · , hierba corta · v hierba alta (arde) · R vado de piedras · ~ río")
		if not (m.get("precipicio", []) as Array).is_empty():
			var f0: Vector2i = (m["precipicio"] as Array)[0]
			l.append("; PASO DE TIERRA: precipicio de %d casillas (letra espacio, sin suelo) desde (%d, %d), %d de hondo en el camino: se cruza con el puente de tierra (barrera + líneas) lanzado desde el borde." % [(m["precipicio"] as Array).size(), f0.x, f0.y, int(p.get("ancho_precipicio", 2))])
	var limpio: Dictionary = {}
	for k in p:
		if not String(k).begins_with("_"):
			limpio[k] = p[k]
	l.append("; generador " + JSON.stringify(limpio))
	var ret: Dictionary = m.get("retoques", {})
	if not ret.is_empty():
		var claves: Array = ret.keys()
		claves.sort()
		var t: PackedStringArray = PackedStringArray()
		for c in claves:
			t.append("%d,%d%s" % [int(c.x), int(c.y), String(ret[c])])
		l.append("; retoques " + " ".join(t))
	var enl: Dictionary = m.get("enlaces_mano", {})
	if not enl.is_empty():
		var ids_enl: Array = enl.keys()
		ids_enl.sort()
		var te: PackedStringArray = PackedStringArray()
		for id in ids_enl:
			te.append("%s>%s" % [String(id), String(enl[id])])
		l.append("; enlaces " + " ".join(te))
	var pzm: Dictionary = m.get("puzles_mano", {})
	if not pzm.is_empty():
		var salas_pz: Array = pzm.keys()
		salas_pz.sort()
		var tp: PackedStringArray = PackedStringArray()
		for sid in salas_pz:
			tp.append("%d>%s" % [int(sid), String(pzm[sid])])
		l.append("; puzles " + " ".join(tp))
	var mov: Dictionary = m.get("movidos", {})
	if not mov.is_empty():
		var origenes: Array = mov.keys()
		origenes.sort()
		var tm: PackedStringArray = PackedStringArray()
		for de in origenes:
			tm.append("%d,%d>%d,%d" % [int(de.x), int(de.y), int(mov[de].x), int(mov[de].y)])
		l.append("; movidos " + " ".join(tm))
	var an: Array = m.get("anadidos", [])
	if not an.is_empty():
		var ta: PackedStringArray = PackedStringArray()
		for a in an:
			ta.append("%s|%s|%s|%d,%d" % [String(a["que"]), String(a["tipo"]), String(a.get("premio", "")), int(a["c"].x), int(a["c"].y)])
		l.append("; anadidos " + " ".join(ta))
	var apa: Array = m.get("apariciones", [])
	if not apa.is_empty():
		var tap: PackedStringArray = PackedStringArray()
		for ap in apa:
			tap.append("%s<%s" % [String(ap["cofre"]), "+".join(PackedStringArray(ap["enemigos"]))])
		l.append("; apariciones " + " ".join(tap))
	l.append(";")
	if bool(p["rotulo"]):
		l.append("; zona 1,1..%d,%d %s mezcla=0.8 rotulo=%s" % [int(m["ancho"]) - 2, int(m["alto"]) - 2, String(p["luz"]), nombre])
		l.append(";")
	# 20/11: las salas de cámara (CamaraSalas): la cámara se frena en su borde y se acerca en las pequeñas.
	var cam: Array = m.get("salas_camara", [])
	for r in cam:
		var rc: Rect2i = r
		l.append("; camara %d,%d..%d,%d" % [rc.position.x, rc.position.y, rc.end.x - 1, rc.end.y - 1])
	if not cam.is_empty():
		l.append(";")
	l.append_array(m["lineas"])
	return "\n".join(l) + "\n"


static func texto_escena(m: Dictionary) -> String:
	var p: Dictionary = m["parametros"]
	var nombre: String = String(p["nombre"])
	var cueva: bool = String(p["estilo"]) == "cueva"
	var l: PackedStringArray = PackedStringArray()
	l.append("[gd_scene format=3]")
	l.append("")
	l.append("[ext_resource type=\"Script\" path=\"res://presentacion/prueba_test2.gd\" id=\"1_poc\"]")
	l.append("[ext_resource type=\"Script\" path=\"res://escenas/puzle.gd\" id=\"2_pz\"]")
	if cueva:
		l.append("[ext_resource type=\"Script\" path=\"res://presentacion/luz_portatil_cueva.gd\" id=\"3_luz\"]")
	l.append("")
	l.append("[node name=\"Prueba%s\" type=\"Node3D\"]" % nombre)
	l.append("script = ExtResource(\"1_poc\")")
	l.append("fuego_nuevo = true")
	l.append("nivel = \"%s\"" % nombre)
	l.append("estilo = \"%s\"" % String(p["estilo"]))
	l.append("zona_luz = \"%s\"" % String(p["luz"]))
	l.append("agua_fisica = true")
	l.append("agua_corre = false")
	if bool(m.get("arqueros", false)):
		l.append("arqueros = true")
	l.append("kit = \"pruebas\"")
	if not bool(p.get("acabado", true)):
		# El acabado del terreno (orillas y juntas) es de serie en la maqueta desde el 17/11; sin la casilla, se apaga en esta escena.
		l.append("orilla_integrada = false")
		l.append("juntas_entremezcladas = false")
	if bool(p.get("camara_sala", true)):
		# 20/11: cámara confinada a la sala; en los mapas sin líneas `; camara` (algoritmo cueva), solo al mapa.
		l.append("camara_por_sala = true")
	l.append("%s = true" % MARCA_ESCENA)
	if cueva:
		l.append("")
		l.append("[node name=\"LuzPortatilCueva\" type=\"OmniLight3D\" parent=\".\"]")
		l.append("light_color = Color(1, 0.91, 0.72, 1)")
		l.append("light_energy = 1.0")
		l.append("light_specular = 0.0")
		l.append("shadow_enabled = true")
		l.append("omni_attenuation = 0.48")
		l.append("script = ExtResource(\"3_luz\")")
	l.append("")
	l.append("[node name=\"Puzles\" type=\"Node\" parent=\".\"]")
	l.append("script = ExtResource(\"2_pz\")")
	return "\n".join(l) + "\n"


## Comprueba que el mapa se puede jugar. Devuelve los errores (vacío = bien).
static func validar(m: Dictionary) -> PackedStringArray:
	var err: PackedStringArray = PackedStringArray()
	var filas: PackedStringArray = m["filas"]
	var w: int = int(m["ancho"])
	var h: int = int(m["alto"])
	if filas.size() != h or h < 3 or w < 3:
		err.append("El plano no mide lo que dice (%d filas, alto %d)." % [filas.size(), h])
		return err
	var n_s: int = 0
	var ini: Vector2i = Vector2i(-1, -1)
	for y in range(h):
		if filas[y].length() != w:
			err.append("La fila %d mide %d y no %d." % [y, filas[y].length(), w])
			return err
		for x in range(w):
			var ch: String = filas[y][x]
			if not LETRAS_VALIDAS.contains(ch) and not String(m.get("letras_extra", "")).contains(ch):
				err.append("Letra desconocida «%s» en (%d, %d)." % [ch, x, y])
			if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and ch != "#":
				err.append("El borde no es pared en (%d, %d)." % [x, y])
			if ch == "S":
				n_s += 1
				ini = Vector2i(x, y)
	if n_s != 1:
		err.append("Tiene que haber un inicio (S) y hay %d." % n_s)
		return err
	if ini != (m["inicio"] as Vector2i):
		err.append("La S no está donde dice el mapa.")
	# Todo lo que se pisa se alcanza desde el inicio (el agua se nada).
	var visto: Dictionary = {ini: true}
	var cola: Array = [ini]
	var k: int = 0
	while k < cola.size():
		var c: Vector2i = cola[k]
		k += 1
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var v: Vector2i = c + d
			if v.x < 0 or v.y < 0 or v.x >= w or v.y >= h or visto.has(v) or filas[v.y][v.x] == "#":
				continue
			visto[v] = true
			cola.append(v)
	var pisables: int = 0
	for y in range(h):
		for x in range(w):
			if filas[y][x] != "#":
				pisables += 1
	if visto.size() != pisables:
		err.append("%d casillas no se alcanzan desde el inicio." % (pisables - visto.size()))
	# Lo que el propio generador da por imposible (una barrera sin enlazar, un enlace que deja el mapa sin solución).
	err.append_array(m.get("errores", PackedStringArray()))
	# Toda puerta, puente y cerrojo tiene que tener algo que lo abra: una llave o una regla `hace=<id>.abrir|tender|alternar`.
	var abre: Dictionary = {}
	for linea in m["lineas"]:
		for trozo in String(linea).split(" ", false):
			if trozo.begins_with("hace=") or trozo.begins_with("y="):
				var accion: PackedStringArray = trozo.substr(trozo.find("=") + 1).split(".")
				if accion.size() >= 2 and (accion[1].begins_with("abrir") or accion[1].begins_with("tender") or accion[1].begins_with("alternar")):
					abre[accion[0]] = true
	for linea in m["lineas"]:
		var tp: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if tp.size() >= 5 and tp[0] == "pieza" and (tp[2] == "puerta" or tp[2] == "puente" or tp[2] == "cerrojo"):
			if not abre.has(tp[1]) and not String(linea).contains(" llave="):
				var aviso: String = "%s «%s» de (%s, %s) no tiene nada que la abra: enlázala con un activador." % [tp[2].capitalize(), tp[1], tp[3], tp[4]]
				if not err.has(aviso) and not "\n".join(err).contains("«%s»" % tp[1]):
					err.append(aviso)
	# Las piezas: sobre algo que se pisa, con id único.
	var ids: Dictionary = {}
	for linea in m["lineas"]:
		var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if t.size() < 2:
			err.append("Línea vacía: «%s»." % linea)
			continue
		if ids.has(t[0] + " " + t[1]):
			err.append("Id repetido: %s." % t[1])
		ids[t[0] + " " + t[1]] = true
		if t[0] != "pieza":
			continue
		if t.size() < 5 or not t[3].is_valid_int() or not t[4].is_valid_int():
			err.append("Pieza mal escrita: «%s»." % linea)
			continue
		var cx: int = t[3].to_int()
		var cy: int = t[4].to_int()
		if cx < 1 or cy < 1 or cx > w - 2 or cy > h - 2 or filas[cy][cx] == "#":
			err.append("La pieza %s cae en pared o fuera del mapa (%d, %d)." % [t[1], cx, cy])
		elif filas[cy][cx] == "~" and t[2] != "puente" and not t[1].begins_with("cat"):
			err.append("La pieza %s cae en el agua (%d, %d)." % [t[1], cx, cy])
	return err


## Escribe el mapa y la escena. Devuelve {ok, error, escritos: [rutas], copia: ruta de la copia del .txt anterior o ""}.
## `sustituir` (18/11, Pablo: «Sustituir los viejos», por Bosque_01 y Bosque_02): permite ocupar el nombre de un nivel HECHO A MANO. Nada se
## borra: el .txt y la escena viejos se COPIAN al lado como `<nombre>_copia_<fecha>_a_mano.*` y el nivel horneado (`Nivel_<Nombre>.tscn`) se
## RENOMBRA a `..._copia_<fecha>.tscn` (si se quedara, la maqueta lo cargaría en vez del mapa nuevo). `apartados` lleva esas rutas.
static func exportar(m: Dictionary, sustituir: bool = false) -> Dictionary:
	var res: Dictionary = {"ok": false, "error": "", "escritos": [], "copia": "", "apartados": []}
	var nombre: String = String((m["parametros"] as Dictionary)["nombre"])
	var mal: String = nombre_valido(nombre)
	if mal != "":
		res["error"] = mal
		return res
	var errores: PackedStringArray = validar(m)
	if not errores.is_empty():
		res["error"] = "El mapa no pasa la validación: " + errores[0]
		return res
	var est: Dictionary = estado_destino(nombre)
	var ajeno: bool = (String(est["mapa"]) != "" and not bool(est["mapa_nuestro"])) or (String(est["escena"]) != "" and not bool(est["escena_nuestra"]))
	if not (sustituir and ajeno):
		if String(est["mapa"]) != "" and not bool(est["mapa_nuestro"]):
			res["error"] = "Ya existe %s y no lo generó esta herramienta: no se pisa. Elige otro nombre." % String(est["mapa"]).get_file()
			return res
		if String(est["escena"]) != "" and not bool(est["escena_nuestra"]):
			res["error"] = "Ya existe %s y no la generó esta herramienta: no se pisa. Elige otro nombre." % String(est["escena"]).get_file()
			return res
		if String(est["horneado"]) != "":
			res["error"] = "Existe %s (nivel horneado): la maqueta cargaría ese y no el mapa nuevo. Elige otro nombre." % String(est["horneado"]).get_file()
			return res
	else:
		# Sustituir un nivel hecho a mano: primero se aparta TODO lo viejo; si algo no se puede apartar, no se escribe nada.
		var sello: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
		for clave in ["mapa", "escena"]:
			var viejo_r: String = String(est[clave])
			if viejo_r == "" or bool(est[clave + ("_nuestro" if clave == "mapa" else "_nuestra")]):
				continue
			var copia_r: String = "%s_copia_%s_a_mano.%s" % [viejo_r.get_basename(), sello, viejo_r.get_extension()]
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(viejo_r), ProjectSettings.globalize_path(copia_r)) != OK:
				res["error"] = "No se pudo guardar la copia de %s: no se sustituye nada." % viejo_r.get_file()
				return res
			(res["apartados"] as Array).append(copia_r)
		if String(est["horneado"]) != "":
			var horno: String = String(est["horneado"])
			var copia_h: String = "%s_copia_%s.tscn" % [horno.get_basename(), sello]
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(horno), ProjectSettings.globalize_path(copia_h)) != OK:
				res["error"] = "No se pudo apartar %s (¿lo tiene abierto Godot?): no se sustituye nada." % horno.get_file()
				return res
			(res["apartados"] as Array).append(copia_h)
	var texto: String = texto_mapa(m)
	var destino: String = String(est["mapa"]) if String(est["mapa"]) != "" else ruta_mapa(nombre)
	if String(est["mapa"]) != "" and bool(est["mapa_nuestro"]):
		var viejo: String = FileAccess.get_file_as_string(destino)
		var previsto: int = viejo.find("; generador ")
		var hash_viejo: String = _sin_fecha(viejo)
		if previsto < 0 or hash_viejo != _sin_fecha(_regenerado(viejo)):
			# El archivo no es exactamente lo que sale de sus propios parámetros: alguien lo retocó. Copia antes de pisar.
			var copia: String = DIR_MAPAS + "%s_copia_%s.txt" % [nombre, Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")]
			var fc: FileAccess = FileAccess.open(copia, FileAccess.WRITE)
			if fc == null:
				res["error"] = "No se pudo guardar la copia de seguridad %s." % copia
				return res
			fc.store_string(viejo)
			fc.close()
			res["copia"] = copia
	var f: FileAccess = FileAccess.open(destino, FileAccess.WRITE)
	if f == null:
		res["error"] = "No se pudo escribir %s." % destino
		return res
	f.store_string(texto)
	f.close()
	(res["escritos"] as Array).append(destino)
	var destino_e: String = String(est["escena"]) if String(est["escena"]) != "" else ruta_escena(nombre)
	var fe: FileAccess = FileAccess.open(destino_e, FileAccess.WRITE)
	if fe == null:
		res["error"] = "No se pudo escribir %s." % destino_e
		return res
	fe.store_string(texto_escena(m))
	fe.close()
	(res["escritos"] as Array).append(destino_e)
	res["ok"] = true
	return res


## Los parámetros guardados en un mapa generado (la línea `; generador {…}`); vacío si no los tiene.
static func parametros_de(texto: String) -> Dictionary:
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if l.begins_with("; generador "):
			var j: Variant = JSON.parse_string(l.substr(12))
			if j is Dictionary:
				return j
	return {}


## Lo que saldría hoy de los parámetros guardados en `texto` (para saber si el archivo se ha retocado a mano).
static func _regenerado(texto: String) -> String:
	var par: Dictionary = parametros_de(texto)
	if par.is_empty():
		return ""
	var gen: RefCounted = load("res://herramientas/generador_mapas/generador_mazmorra.gd").new()
	return texto_mapa(gen.generar(_tipar(par), retoques_de(texto), enlaces_de(texto), puzles_de(texto), movidos_de(texto), anadidos_de(texto), apariciones_de(texto)))


## Los cofres que aparecen al caer enemigos (la línea `; apariciones cofre<enemigo+enemigo …`; cada extremo es `a<n>`, un añadido a
## mano, o `x,y`, la casilla donde el generador puso el elemento).
static func apariciones_de(texto: String) -> Array:
	var res: Array = []
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; apariciones "):
			continue
		for t in l.substr(14).split(" ", false):
			var ab: PackedStringArray = t.split("<")
			if ab.size() == 2 and ab[0] != "" and ab[1] != "":
				res.append({"cofre": ab[0], "enemigos": Array(ab[1].split("+", false))})
	return res


## Los enemigos y cofres añadidos a mano (la línea `; anadidos que|tipo|premio|x,y …`), en el orden en que se pusieron.
static func anadidos_de(texto: String) -> Array:
	var res: Array = []
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; anadidos "):
			continue
		for t in l.substr(11).split(" ", false):
			var trozos: PackedStringArray = t.split("|")
			if trozos.size() != 4:
				continue
			var xy: PackedStringArray = trozos[3].split(",")
			if xy.size() == 2 and xy[0].is_valid_int() and xy[1].is_valid_int():
				var a: Dictionary = {"que": trozos[0], "tipo": trozos[1], "c": Vector2i(xy[0].to_int(), xy[1].to_int())}
				if trozos[0] == "cofre" and trozos[1] != "comun":
					a["premio"] = trozos[2]
				elif trozos[0] == "salida":
					# El tercer campo de una salida es `modo;ancho;marca;llegada`.
					var ajustes: PackedStringArray = trozos[2].split(";")
					if ajustes.size() >= 4:
						a["modo"] = ajustes[0]
						a["ancho"] = ajustes[1].to_int()
						a["marca"] = ajustes[2] != "no"
						a["llegada"] = ajustes[3]
						a["acceso"] = ajustes[4] if ajustes.size() >= 5 else ""
				res.append(a)
	return res


## Los elementos movidos a mano (la línea `; movidos x,y>x,y …`): casilla donde lo puso el generador → casilla donde quedó.
static func movidos_de(texto: String) -> Dictionary:
	var res: Dictionary = {}
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; movidos "):
			continue
		for t in l.substr(10).split(" ", false):
			var ab: PackedStringArray = t.split(">")
			if ab.size() != 2:
				continue
			var de: PackedStringArray = ab[0].split(",")
			var a: PackedStringArray = ab[1].split(",")
			if de.size() == 2 and a.size() == 2 and de[0].is_valid_int() and de[1].is_valid_int() and a[0].is_valid_int() and a[1].is_valid_int():
				res[Vector2i(de[0].to_int(), de[1].to_int())] = Vector2i(a[0].to_int(), a[1].to_int())
	return res


## Los puzles del catalogo puestos a mano (la linea `; puzles sala>puzle`): sala -> id del puzle.
static func puzles_de(texto: String) -> Dictionary:
	var res: Dictionary = {}
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; puzles "):
			continue
		for t in l.substr(9).split(" ", false):
			var ab: PackedStringArray = t.split(">")
			if ab.size() == 2 and ab[0].is_valid_int():
				res[ab[0].to_int()] = ab[1]
	return res


## Los enlaces cambiados a mano guardados en un mapa generado (la línea `; enlaces barrera>activador …`): id de barrera → id de activador ("" = suelta).
static func enlaces_de(texto: String) -> Dictionary:
	var res: Dictionary = {}
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; enlaces "):
			continue
		for t in l.substr(10).split(" ", false):
			var ab: PackedStringArray = t.split(">")
			if ab.size() == 2:
				res[ab[0]] = ab[1]
	return res


## Los retoques a mano guardados en un mapa generado (la línea `; retoques x,y<letra> …`): casilla → letra.
static func retoques_de(texto: String) -> Dictionary:
	var res: Dictionary = {}
	for linea in texto.split("\n"):
		var l: String = String(linea).strip_edges()
		if not l.begins_with("; retoques "):
			continue
		for t in l.substr(11).split(" ", false):
			var xy: PackedStringArray = t.substr(0, t.length() - 1).split(",")
			if xy.size() == 2 and xy[0].is_valid_int() and xy[1].is_valid_int():
				res[Vector2i(xy[0].to_int(), xy[1].to_int())] = t.substr(t.length() - 1)
	return res


## JSON devuelve todos los números como float: se devuelven a su tipo según los valores por defecto.
static func _tipar(par: Dictionary) -> Dictionary:
	var defecto: Dictionary = load("res://herramientas/generador_mapas/generador_mazmorra.gd").parametros_defecto()
	var res: Dictionary = {}
	for k in par:
		if defecto.has(k) and defecto[k] is int:
			res[k] = int(par[k])
		elif defecto.has(k) and defecto[k] is bool:
			res[k] = bool(par[k])
		else:
			res[k] = par[k]
	return res


## El texto sin la línea de la cabecera que lleva la fecha (dos exportaciones del mismo mapa en días distintos son el mismo mapa).
static func _sin_fecha(texto: String) -> String:
	var l: PackedStringArray = PackedStringArray()
	for linea in texto.split("\n"):
		if not String(linea).contains(MARCA):
			l.append(String(linea).replace("\r", ""))
	return "\n".join(l)
