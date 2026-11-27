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
		"CuevaPrueba":
			_ok("4 %s: estilo cueva con las paredes del kit" % nombre, estilo == "cueva" and String(maqueta.get("paredes_cueva")) != "lostcave", "%s / %s" % [estilo, String(maqueta.get("paredes_cueva"))])
		"CuevaPruebaLostCave":
			_ok("4 %s: estilo cueva con las paredes de Lost Cave" % nombre, estilo == "cueva" and String(maqueta.get("paredes_cueva")) == "lostcave", "%s / %s" % [estilo, String(maqueta.get("paredes_cueva"))])
