extends "res://herramientas/prueba_niveles_bosque.gd"
## LOS NIVELES DE REVISIÓN DE ASSETS (27/11/2026) SE JUEGAN: RuinasPrueba, CuevaPrueba y CuevaPruebaLostCave, exportados por `generar_niveles_cueva_ruinas.gd`. Sin ventana (headless), con la escena de verdad.
## Hereda el armazón de `prueba_niveles_bosque.gd` (mismos pasos y mismas comprobaciones) y añade lo propio de estos niveles:
##   1. el .txt de cada nivel es exactamente lo que el generador saca de sus propios parámetros (los muestrarios y los puzles van en `; puzles`: sobreviven a «Exportar»);
##   2. carga sin avisos de Puzle3D / Zonas3D, cada `; pieza` existe como nodo, suelo es suelo, paredes bloquean, agua es agua (lo de la prueba de bosque);
##   3. cada plantilla pedida está puesta, y cada sala MUESTRARIO monta una pieza por cada id que dice su plan (`objetos/muestrario_piezas_3d.gd`) con su rótulo;
##   4. el estilo de la escena es el pedido (muros finos del pack Stylescape en las ruinas; paredes del kit o de Lost Cave en la cueva);
##   5. desde la entrada se llega ANDANDO a cada sala (contando lo que abre un puzle).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_niveles_cueva_ruinas.gd [-- solo=CuevaPrueba] [-- rapido]
## Acaba con «FALLOS: n».

const MU = preload("res://objetos/muestrario_piezas_3d.gd")
const NIVELES_REVISION: Array = ["RuinasPrueba", "RuinasPruebaMuestrario", "CuevaPrueba", "CuevaPruebaLostCave"]


func _escenario() -> void:
	Partida.carpeta = CARPETA
	kit_de_pruebas = false
	Flags.nuevo()
	Estado.nuevo()
	var solo: String = ""
	var rapido: bool = false
	avisos_permitidos = ["la cámara tendrá que acercarse al máximo"]          # los pasillos de 1 × n de «pagina» (ver AVISOS_CAMARA de generar_niveles_cueva_ruinas.gd)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo="):
			solo = a.substr(5)
		elif a == "rapido":
			rapido = true
	for nombre in NIVELES_REVISION:
		if solo != "" and nombre != solo:
			continue
		_ok("0 %s: existen el mapa y la escena" % nombre, FileAccess.file_exists(Exportador.ruta_mapa(nombre)) and FileAccess.file_exists(Exportador.ruta_escena(nombre)))
		if not (FileAccess.file_exists(Exportador.ruta_mapa(nombre)) and FileAccess.file_exists(Exportador.ruta_escena(nombre))):
			continue
		await _cargar_nivel(nombre)
		await _comprobar_estatico()
		_comprobar_revision(nombre)
		await _comparar_colision(nombre)
		await _apagar_trampas()
		await _recorrer(not rapido)
		await _descargar()
	_borrar_carpeta()


## Apaga las trampas de pared (dragones y mascarones) para el recorrido a pie: el recorrido prueba el mapa, no las trampas, y con un dragón de chorro continuo encendido (`ciclo=90,1`) la jugadora se
## VA a la deriva hacia el oeste (~0,7 u/s, también quieta; ocurre igual en PtFuego2: efecto previo a estas plantillas, ver el informe) y las teclas del recorrido ya no apuntan donde deben.
func _apagar_trampas() -> void:
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	if pz == null:
		return
	var n: int = 0
	for linea in _m["lineas"]:
		var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and (t[2] == "trampa_dragon" or t[2] == "trampa_flechas"):
			var nodo: Node = pz.nodo(t[1])
			if nodo != null:
				nodo.call("apagar")
				n += 1
	print("      %s: %d trampas de pared apagadas para el recorrido" % [_nivel_actual, n])
	await avanzar(30)


## Quita la escena del nivel (si no, la siguiente carga convive con ella: sus enemigos y su jugadora siguen en los grupos y la prueba mira a la equivocada).
func _descargar() -> void:
	if maqueta != null:
		maqueta.get_parent().remove_child(maqueta)
		maqueta.queue_free()
		maqueta = null
	lanzador = null
	jugador = null
	await avanzar(5)


## Las casillas de las salas muestrario cuentan como ocupadas por piezas: sus piezas (las de los packs) bloquean con su propia colisión, no por el plano.
func _celdas_de_lineas(m: Dictionary, tipo: String) -> Array:
	var res: Array = super(m, tipo)
	if tipo != "":
		return res
	for linea in m["lineas"]:
		var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if t.size() < 5 or t[0] != "pieza" or t[2] != "muestrario":
			continue
		var ancho: int = 12
		var alto: int = 8
		for k in range(5, t.size()):
			if t[k].begins_with("ancho="):
				ancho = t[k].substr(6).to_int()
			elif t[k].begins_with("alto="):
				alto = t[k].substr(5).to_int()
		for y in range(t[4].to_int() - 2, t[4].to_int() + alto + 2):          # (con los dos de margen de la plantilla: una pieza grande asoma por un lado)
			for x in range(t[3].to_int() - 2, t[3].to_int() + ancho + 2):
				res.append(Vector2i(x, y))
	return res


## La colisión y la rejilla de RuinasPrueba son EXACTAMENTE las mismas con y sin `ruinas_completas`: se carga la escena tal cual, se anota para cada casilla si está bloqueada y si se pisa, se vuelve a cargar la
## misma escena SIN la línea `ruinas_completas = true` (copia en user://, no toca el repositorio) y se comparan las dos listas. Luego se deja cargado el nivel de verdad para el resto de la prueba.
func _foto_colision(filas: PackedStringArray) -> PackedInt32Array:
	var res := PackedInt32Array()
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			var c := Vector2i(x, y)
			res.append((1 if Terreno3D.bloqueada(c) else 0) | (2 if Terreno3D.pisable(c, 0, true, 1, false) else 0))
	return res


func _comparar_colision(nombre: String) -> void:
	if nombre != "RuinasPrueba":
		return
	var filas: PackedStringArray = _m["filas"]
	var con: PackedInt32Array = _foto_colision(filas)
	var lineas: PackedStringArray = PackedStringArray()
	for l in FileAccess.get_file_as_string(Exportador.ruta_escena(nombre)).split("\n"):
		if String(l).strip_edges() != "ruinas_completas = true":
			lineas.append(l)
	var ruta_tmp: String = "user://zz_rc_sin_suelo.tscn"
	var f: FileAccess = FileAccess.open(ruta_tmp, FileAccess.WRITE)
	f.store_string("\n".join(lineas))
	f.close()
	await _descargar()
	await cargar(ruta_tmp, false)
	await _preparar_nivel(nombre)
	_ok("6 %s: la escena de comparación NO lleva ruinas_completas ni plan de suelo" % nombre, not bool(maqueta.get("ruinas_completas")) and (maqueta.get("_rc_tipo") as Dictionary).is_empty())
	var sin: PackedInt32Array = _foto_colision(filas)
	var distintas: int = 0
	for i in range(mini(con.size(), sin.size())):
		if con[i] != sin[i]:
			distintas += 1
	_ok("6 %s: la colisión y la rejilla son las mismas con y sin el suelo de ruinas (%d casillas, %d distintas)" % [nombre, con.size(), distintas], con.size() == sin.size() and distintas == 0 and con.size() > 1000)
	await _descargar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_tmp))
	await _cargar_nivel(nombre)


## 27/11 (Pablo: «el ejemplo de un nivel completo de bioma ruinas»): `ruinas_completas` (suelo de losas rotas y vestido de piedra, presentacion/ruinas_completas_3d.gd) está en RuinasPrueba y
## NO en el nivel hermano RuinasPruebaMuestrario (que se exportó sin el parámetro: sin suelo ni vestido nuevos, como los demás niveles de ruinas que ya existían).
func _comprobar_ruinas_completas(nombre: String, texto: String) -> void:
	var escena: String = FileAccess.get_file_as_string(Exportador.ruta_escena(nombre))
	var quiere: bool = nombre == "RuinasPrueba"
	_ok("6 %s: la escena %s `ruinas_completas = true`" % [nombre, "pide" if quiere else "NO pide"], escena.contains("ruinas_completas = true") == quiere)
	_ok("6 %s: la maqueta %s ruinas_completas" % [nombre, "lleva" if quiere else "NO lleva"], bool(maqueta.get("ruinas_completas")) == quiere)
	var rc_tipo: Dictionary = maqueta.get("_rc_tipo")
	var rc_piezas: Array = maqueta.get("_rc_piezas")
	var cuentas: Dictionary = maqueta.get("ruinas_cuentas")
	if not quiere:
		_ok("6 %s: sin el export no hay suelo de ruinas (plan vacío, ninguna casilla repintada, sin losas del pack, sin vestido)" % nombre,
			rc_tipo.is_empty() and rc_piezas.is_empty() and cuentas.is_empty(), "%d casillas, %d losas, %s" % [rc_tipo.size(), rc_piezas.size(), str(cuentas)])
		var lotes_rc: int = 0
		for h in maqueta.find_children("rc_*", "MultiMeshInstance3D", true, false):
			lotes_rc += 1
		_ok("6 %s: sin el export no hay lotes de losas (rc_*)" % nombre, lotes_rc == 0)
		return
	# el suelo: casillas pintadas de piedra y casillas sin losa (hierba) entre ellas; las losas del pack van en lotes (MultiMesh), no en un nodo por losa
	var piedra: int = 0
	var n_floor: int = 0
	var filas: PackedStringArray = _m["filas"]
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			if ".,vg".contains(filas[y][x]):
				n_floor += 1
				if int(rc_tipo.get(Vector2i(x, y), -1)) == 3:
					piedra += 1
	var frac: float = float(piedra) / maxf(1.0, float(n_floor))
	_ok("6 %s: el suelo está enlosado pero ROTO (%d de %d casillas de suelo con losa: entre el 40 y el 92 %%)" % [nombre, piedra, n_floor], frac > 0.40 and frac < 0.92, "%.0f %%" % (frac * 100.0))
	var lotes: int = 0
	var instancias: int = 0
	for h in maqueta.find_children("rc_*", "MultiMeshInstance3D", true, false):
		lotes += 1
		instancias += ((h as MultiMeshInstance3D).multimesh as MultiMesh).instance_count
	_ok("6 %s: las losas del pack van en lotes MultiMesh (%d lotes, %d losas) y no hay un nodo por losa" % [nombre, lotes, instancias], lotes >= 1 and lotes <= 16 and lotes <= instancias and instancias == rc_piezas.size() and instancias >= 5)
	# la colisión no cambia: el suelo es visual. Cada casilla de suelo de las que el plano da por pisables sigue pisable, y los muros siguen bloqueando
	var mal: int = 0
	for y in range(filas.size()):
		for x in range(filas[y].length()):
			var c := Vector2i(x, y)
			if filas[y][x] == "#" and not Terreno3D.bloqueada(c):
				mal += 1
	_ok("6 %s: los muros siguen bloqueando con el suelo nuevo (%d muros que no)" % [nombre, mal], mal == 0)
	# nada del suelo nuevo tapa una placa, un botón ni un cofre: ni losa suelta ni losa levantada en una casilla de puzle
	var puzle: Dictionary = {}
	for q in maqueta.call("_celdas_puzle_del_mapa"):
		puzle[q] = true
	var tapadas: int = 0
	for p in rc_piezas:
		if puzle.has(p[1]):
			tapadas += 1
	_ok("6 %s: ninguna losa del pack cae sobre una casilla de puzle (%d casillas de puzle, %d tapadas)" % [nombre, puzle.size(), tapadas], tapadas == 0 and puzle.size() > 5)
	# el vestido: pilares pegados a los muros (en la franja bloqueada: el centro del pilar está dentro de una casilla `#`), arcos sobre puertas (`g` con muro a los dos lados), escombros
	_ok("6 %s: el vestido: pilares (%d), arcos (%d), hiedras (%d), escombros (%d)" % [nombre, int(cuentas.get("pilares", 0)), int(cuentas.get("arcos", 0)), int(cuentas.get("hiedras", 0)), int(cuentas.get("escombros", 0))],
		int(cuentas.get("pilares", 0)) >= 10 and int(cuentas.get("arcos", 0)) >= 3 and int(cuentas.get("escombros", 0)) >= 10)
	var pilares_fuera: int = 0
	var arcos_fuera: int = 0
	var n_pil: int = (cuentas["pilares_en"] as Array).size()
	var n_arc: int = (cuentas["arcos_en"] as Array).size()
	for cel in (cuentas["pilares_en"] as Array):
		if filas[(cel as Vector2i).y][(cel as Vector2i).x] != "#":
			pilares_fuera += 1
	for cel in (cuentas["arcos_en"] as Array):
		if filas[(cel as Vector2i).y][(cel as Vector2i).x] != "g":
			arcos_fuera += 1
	_ok("6 %s: ningún pilar está sobre una casilla que se pise (%d pilares, %d fuera de un muro)" % [nombre, n_pil, pilares_fuera], pilares_fuera == 0 and n_pil >= 10)
	_ok("6 %s: cada arco está sobre una puerta (%d arcos, %d fuera de una casilla `g`)" % [nombre, n_arc, arcos_fuera], arcos_fuera == 0 and n_arc >= 3)


## Lo propio de estos niveles: las plantillas pedidas, los muestrarios montados y el estilo de la escena.
func _comprobar_revision(nombre: String) -> void:
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var puestos: Array = []
	for l in texto.split("\n"):
		if String(l).begins_with("; puzles "):
			for par in String(l).substr(9).split(" ", false):
				puestos.append(par.split(">")[1])
	var estilo: String = String(maqueta.get("estilo"))
	var n_mu_pedidos: int = puestos.filter(func(c) -> bool: return String(c).begins_with("muestrario_")).size()
	var n_puzles: int = puestos.size() - n_mu_pedidos
	var espera_mu: bool = nombre != "RuinasPrueba"            # RuinasPrueba lleva solo los puzles: sus salas muestrario están en RuinasPruebaMuestrario (la memoria de los niveles de ruinas grandes)
	var espera_pz: bool = nombre == "RuinasPrueba" or nombre == "CuevaPrueba"
	_ok("3 %s: lleva puzles (%d) y salas muestrario (%d) puestos a mano" % [nombre, n_puzles, n_mu_pedidos], (not espera_pz or n_puzles >= 3) and (not espera_mu or n_mu_pedidos >= 1), str(puestos))
	var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var n_mu: int = 0
	for linea in _m["lineas"]:
		var t: PackedStringArray = String(linea).substr(1).strip_edges().split(" ", false)
		if t.size() < 5 or t[0] != "pieza" or t[2] != "muestrario":
			continue
		n_mu += 1
		var pack: String = ""
		var grupo: String = ""
		var ancho: float = 12.0
		var alto: float = 8.0
		for k in range(5, t.size()):
			if t[k].begins_with("pack="):
				pack = t[k].substr(5)
			elif t[k].begins_with("grupo="):
				grupo = t[k].substr(6)
			elif t[k].begins_with("ancho="):
				ancho = t[k].substr(6).to_float()
			elif t[k].begins_with("alto="):
				alto = t[k].substr(5).to_float()
		var plan: Dictionary = MU.plan(pack, grupo, ancho * 2.3)
		var raiz: Node = pz.nodo(t[1]) if pz != null else null
		var montadas: int = 0
		var rotulos: int = 0
		if raiz != null:
			for h in raiz.get_children():
				if h is Label3D:
					rotulos += 1
				elif String(h.name).begins_with("m_"):
					montadas += 1
		var esperadas: int = (plan["piezas"] as Array).size()
		_ok("3 %s: el muestrario %s (%s/%s) monta sus %d piezas con rótulo (%d rótulos)" % [nombre, t[1], pack, grupo, esperadas, rotulos], raiz != null and montadas == esperadas and rotulos >= esperadas, "%d montadas" % montadas)
		_ok("3 %s: el muestrario %s cabe en su rectángulo (%.1f de %.0f u de fondo) y no le falta ninguna pieza" % [nombre, t[1], float(plan["fondo"]), alto * 2.3], float(plan["fondo"]) <= alto * 2.3 and (plan["faltan"] as Array).is_empty(), str(plan["faltan"]))
	_ok("3 %s: las salas muestrario montadas son las pedidas (%d)" % [nombre, n_mu], n_mu == n_mu_pedidos)
	match nombre:
		"RuinasPrueba", "RuinasPruebaMuestrario":
			_ok("4 %s: estilo ruinas" % nombre, estilo == "ruinas", estilo)
			var muros: int = 0
			for n in maqueta.find_children("*", "Node3D", true, false):
				if String((n as Node).get_meta("id", "")).begins_with("ss_"):
					muros += 1
			_ok("4 %s: salen piezas del pack Stylescape (%d)" % [nombre, muros], muros > 50)
			_comprobar_ruinas_completas(nombre, texto)
		"CuevaPrueba":
			_ok("4 %s: estilo cueva con las paredes del kit" % nombre, estilo == "cueva" and String(maqueta.get("paredes_cueva")) != "lostcave", "%s / %s" % [estilo, String(maqueta.get("paredes_cueva"))])
		"CuevaPruebaLostCave":
			_ok("4 %s: estilo cueva con las paredes de Lost Cave" % nombre, estilo == "cueva" and String(maqueta.get("paredes_cueva")) == "lostcave", "%s / %s" % [estilo, String(maqueta.get("paredes_cueva"))])
