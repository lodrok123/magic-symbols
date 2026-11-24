extends "res://herramientas/escenario_base.gd"
## NIVELES DE PLAYTEST DE LOS PUZLES DEL CATÁLOGO (24/11/2026). Pablo: «crea semillas con los puzles a validar; conforme los playtestee te digo si hay
## ajustes o si están aceptados; una vez aceptados ya los usaremos en mapas oficiales».
## Para cada grupo de GRUPOS busca una semilla del algoritmo «página» en la que quepan todos sus puzles, uno por sala y EN ORDEN desde el inicio (sala 1 la
## más cercana). A cada puzle de tipo «salida» (un activador, sin premio propio) le enlaza un cofre común en su sala para que se vea que está resuelto.
## Cada sala lleva una zona con RÓTULO al entrar («3 · Vagoneta por la curva») y nombre `pt_<puzle>` (sale en el diario de partida: PlayLog.zona).
## Sin enemigos, braseros sueltos, jarrones ni barreras: solo los puzles. Exporta mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn, los carga y
## comprueba que Puzle3D no da avisos. Escribe el inventario en docs/PLAYTEST_PUZLES.md.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/generar_playtest_puzles.gd
## Rehacerlo cambia los mapas (y pierde lo que se haya retocado a mano en ellos).

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const DOC: String = "res://docs/PLAYTEST_PUZLES.md"
const SEMILLAS_MAX: int = 400

## nombre, título, kit, puzles en orden (o jefe/campamento), parámetros extra.
const GRUPOS: Array = [
	["PtFuego", "Fuego", "demo", ["braseros_puerta", "braseros_premio", "rele_braseros", "contrafuego", "barril_muro", "cristal_receptor"], {}],
	["PtVagonetas", "Vagonetas", "demo", ["vagoneta_pista", "vagoneta_curva", "vagoneta_boton", "vagoneta_aguja"], {}],
	["PtAguaTierra", "Agua y tierra", "demo", ["riega_pulsador", "puente_cuerda", "rio_lava", "escondite_muro", "hielo_pista", "balanza_rocas"], {}],
	["PtEmpujePulso", "Empuje y pulso", "demo", ["piedra_pista", "piedra_premio", "pared_hueca_nicho", "prisma_rojo_azul", "estatuas_sellos"], {}],
	["PtJefeCueva", "Jefe de la cueva", "demo", [], {"sala_jefe": "jefe_golem", "campamentos": 1, "n_salas": 6}],
	["PtJefeBosque", "Jefe del bosque", "demo", [], {"algoritmo": "bosque", "estilo": "bosque", "luz": "bosque", "sala_jefe": "jefe_elemental", "campamentos": 1, "claros": 5, "ancho": 50, "alto": 44}],
	["PtHielo", "Hielo (fuera de la demo)", "pruebas", ["charca_helada"], {}],
]

var _filas: Array = []          ## para el inventario: [mapa, orden, puzle, sala]
var _jefes: Array = []


func _escenario() -> void:
	Catalogo.recargar()
	for gr in GRUPOS:
		await _grupo(gr)
	_escribir_doc()


func _base(gr: Array) -> Dictionary:
	var par: Dictionary = {"algoritmo": "pagina", "semilla": 1, "nombre": String(gr[0]), "kit": String(gr[2]), "estilo": "cueva", "luz": "cueva", "paredes": "kit",
		"ancho": 56, "alto": 46, "n_salas": (gr[3] as Array).size() + 3, "lado_min": 7, "lado_max": 11, "simetria": false, "pasillos": 20, "bucles": 10,
		"enemigos": 0.0, "arqueros": 0, "jarrones": 0.0, "braseros": 0.0, "charcas": 0, "tesoro": false, "llave": false, "salas_cerradas": 0,
		"puzles": 0, "barreras": 0, "campamentos": 0, "sala_jefe": "no", "rotulo": true}
	par.merge(gr[4] as Dictionary, true)
	return par


func _grupo(gr: Array) -> void:
	var nombre: String = gr[0]
	var lista: Array = gr[3]
	var par: Dictionary = _base(gr)
	var elegido: Dictionary = {}
	var mapa: Dictionary = {}
	for semilla in range(1, SEMILLAS_MAX):
		par["semilla"] = semilla
		var r: Array = _colocar(par, lista)
		if not r.is_empty():
			elegido = r[0]
			mapa = r[1]
			break
	_ok("%s: caben sus %d puzles en orden (semilla %d)" % [nombre, lista.size(), int(par["semilla"])], not mapa.is_empty())
	if mapa.is_empty():
		return
	if (gr[4] as Dictionary).has("sala_jefe"):
		var hay: bool = false
		for v in (mapa["puzles"] as Dictionary).values():
			hay = hay or String(v).begins_with("jefe_")
		_ok("%s: tiene la sala del jefe" % nombre, hay, "\n".join(mapa["avisos"]))
		_jefes.append([nombre, String((gr[4] as Dictionary)["sala_jefe"]), int(par["semilla"])])
	# Rótulos y nombres de zona, en orden.
	var salas: Dictionary = {}
	for s in mapa["salas"]:
		salas[int(s["id"])] = s
	var orden: Array = elegido.keys()
	orden.sort_custom(func(a, b) -> bool: return int(salas[a]["dist"]) < int(salas[b]["dist"]))
	var n: int = 0
	var lineas = mapa["lineas"]                    # un PackedStringArray: se añade y se vuelve a guardar (con `as Array` se añadía a una copia)
	for sid in orden:
		n += 1
		var cid: String = String(elegido[sid])
		var r: Rect2i = salas[sid]["rect"]
		var t: String = "%d._%s" % [n, String(Catalogo.todos()[cid]["titulo"]).replace(":", "").replace("(", "").replace(")", "").replace(",", "").replace(" ", "_")]
		lineas.append("; zona %d,%d..%d,%d %s mezcla=0.5 nombre=pt_%s rotulo=%s" % [r.position.x, r.position.y, r.end.x - 1, r.end.y - 1, String(par["luz"]), cid, t])
		_filas.append([nombre, n, cid, int(sid)])
	mapa["lineas"] = lineas
	var res: Dictionary = Exportador.exportar(mapa)
	_ok("%s: se exporta" % nombre, bool(res["ok"]), str(res))
	_poner_atajos(Exportador.ruta_escena(nombre))
	await cargar(Exportador.ruta_escena(nombre), true)
	if maqueta != null:
		var pz: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
		_ok("%s: Puzle3D sin avisos" % nombre, pz != null and pz.avisos.is_empty(), str(pz.avisos) if pz != null else "sin Puzle3D")
		var at: AtajosPlaytest = maqueta.get_node_or_null("AtajosPlaytest") as AtajosPlaytest
		await avanzar(3)
		if not lista.is_empty():
			_ok("%s: atajos a sus %d salas (Alt + número)" % [nombre, lista.size()], at != null and at.salas.size() == lista.size(), str(at.salas.size()) if at != null else "sin atajos")
			if at != null:
				for s in at.salas:
					var fue: bool = at.ir_a(int(s["n"]))
					await avanzar(2)
					_ok("%s: Alt+%d lleva a la sala «%s»" % [nombre, int(s["n"]), String(s["titulo"])], fue and (s["rect"] as Rect2i).has_point(celda_jugador()), str(celda_jugador()))
		maqueta.get_parent().remove_child(maqueta)
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)


## Añade a la escena exportada el nodo de los atajos de playtest (escenas/atajos_playtest.gd: lista de salas y Alt + número para ir a cada una).
func _poner_atajos(ruta: String) -> void:
	var t: String = FileAccess.get_file_as_string(ruta)
	if t.contains("atajos_playtest.gd"):
		return
	var i: int = t.find("\n[node ")
	t = t.substr(0, i) + "\n[ext_resource type=\"Script\" path=\"res://escenas/atajos_playtest.gd\" id=\"9_atajos\"]" + t.substr(i)
	t = t.rstrip("\n") + "\n\n[node name=\"AtajosPlaytest\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"9_atajos\")\n"
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(t)
	f.close()


## Pone los puzles de `lista` en salas libres, en orden de cercanía al inicio. Devuelve [sala → puzle, mapa final] o [] si no caben todos.
func _colocar(par: Dictionary, lista: Array) -> Array:
	var base: Dictionary = Generador.new().generar(par)
	if not (base["errores"] as Array).is_empty():
		return []
	var libres: Array = (base["salas"] as Array).filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))
	var asign: Dictionary = {}
	for cid in lista:
		var puesto: bool = false
		for s in libres:
			var sid: int = int(s["id"])
			if asign.has(sid):
				continue
			var prueba: Dictionary = asign.duplicate()
			prueba[sid] = cid
			var m: Dictionary = Generador.new().generar(par, {}, {}, prueba)
			var todos: bool = true
			for k in prueba:
				todos = todos and String((m["puzles"] as Dictionary).get(k, "")) == String(prueba[k])
			if todos:
				asign = prueba
				puesto = true
				break
		if not puesto:
			return []
	# Un cofre común enlazado a cada puzle de tipo «salida» (no tiene premio propio).
	var anadidos: Array = []
	var apariciones: Array = []
	var m0: Dictionary = Generador.new().generar(par, {}, {}, asign)
	var salas: Dictionary = {}
	for s in m0["salas"]:
		salas[int(s["id"])] = s
	for sid in asign:
		if String(Catalogo.todos()[asign[sid]]["tipo"]) == "salida":
			var r: Rect2i = salas[sid]["rect"]
			apariciones.append({"cofre": "a%d" % anadidos.size(), "enemigos": ["pz%d" % int(sid)]})
			var dentro: Vector2i = _cofre_de_plantilla(m0, salas[sid], String(asign[sid]))
			if dentro.x >= 0:
				anadidos.append({"que": "cofre", "tipo": "comun", "premio": "", "c": dentro, "forzar": true})
			else:
				anadidos.append({"que": "cofre", "tipo": "comun", "premio": "", "c": _junto_al_activador(m0, salas[sid], String(asign[sid]), r)})
	var m2: Dictionary = Generador.new().generar(par, {}, {}, asign, {}, anadidos, apariciones)
	for k in asign:
		if String((m2["puzles"] as Dictionary).get(k, "")) != String(asign[k]):
			return []
	if (m2["anadidos"] as Array).size() != anadidos.size() or (m2["apariciones"] as Array).size() != apariciones.size() or not (m2["errores"] as Array).is_empty():
		return []
	return [asign, m2]


## Dónde se pide el cofre común de un puzle «salida»: en la casilla de la pieza que da la señal (el receptor, el tótem…); el generador lo deja en
## el suelo libre más cercano que no corte el paso. 24/11, playtest del puzle 6 (cristal y receptor): antes iba a la esquina de abajo a la izquierda
## de la sala, que en las plantillas con muro propio queda FUERA del muro, y no se veía al resolverlo. Sin pieza conocida, la esquina de antes.
func _junto_al_activador(m: Dictionary, sala: Dictionary, cid: String, r: Rect2i) -> Vector2i:
	var res: String = String(Catalogo.todos().get(cid, {}).get("resuelto", ""))
	if sala.has("inst") and res.contains("."):
		var pieza: String = String(sala["inst"]) + "_" + res.split(".")[0]
		for o in m["objetos"]:
			if String(o.get("id", "")) == pieza:
				return o["c"]
	return Vector2i(r.position.x + 1, r.end.y - 2)


## La casilla `; cofre_salida x y` de la plantilla, ya en el mapa: el origen de la plantilla sale de la pieza que da la señal (su casilla en el
## mapa menos la suya en la plantilla). (-1, -1) si la plantilla no la tiene o no se encuentra la pieza.
func _cofre_de_plantilla(m: Dictionary, sala: Dictionary, cid: String) -> Vector2i:
	var e: Dictionary = Catalogo.todos().get(cid, {})
	var hueco: Vector2i = e.get("cofre_salida", Vector2i(-1, -1))
	var res: String = String(e.get("resuelto", ""))
	if hueco.x < 0 or not sala.has("inst") or not res.contains("."):
		return Vector2i(-1, -1)
	var local_id: String = res.split(".")[0]
	var local: Vector2i = Vector2i(-1, -1)
	for l in e["lineas"]:
		var p: PackedStringArray = String(l).split(" ", false)
		if p.size() >= 5 and p[1] == "pieza" and p[2] == local_id:
			local = Vector2i(p[4].to_int(), p[5].to_int()) if p.size() >= 6 else Vector2i(-1, -1)
	var pieza: String = String(sala["inst"]) + "_" + local_id
	for l in m["lineas"]:
		var q: PackedStringArray = String(l).split(" ", false)
		if q.size() >= 6 and q[1] == "pieza" and q[2] == pieza and local.x >= 0:
			return Vector2i(q[4].to_int(), q[5].to_int()) - local + hueco
	return Vector2i(-1, -1)


func _escribir_doc() -> void:
	var cat: Dictionary = Catalogo.todos()
	var t: PackedStringArray = PackedStringArray()
	t.append("# Playtest de los puzles del catálogo (24/11/2026)")
	t.append("")
	t.append("Niveles de prueba hechos con el generador (`herramientas/generar_playtest_puzles.gd`), uno por grupo de puzles. Cada puzle va en su sala, en ORDEN")
	t.append("desde el inicio, con un rótulo al entrar («3 · Vagoneta por la curva»); los que no tienen premio propio llevan un cofre común que aparece")
	t.append("al resolverlos. Sin enemigos ni nada más que los puzles. Se abren con el generador («Abrir mapa generado») o directamente (comandos abajo).")
	t.append("")
	t.append("**Para no buscar las salas:** a la derecha de la pantalla sale la lista de salas del nivel (▶ = en la que estás). **Alt + número** (o el número del")
	t.append("teclado numérico) te lleva a la entrada de esa sala (`escenas/atajos_playtest.gd`). Alt + número también cambia de página del libro: no estorba.")
	t.append("")
	t.append("**Cómo se valida:** Pablo los juega y dice, por puzle, *aceptado* o *ajustes* (y qué). Claude lo apunta en su `.txt` (`; validacion`, `; nota_playtest`)")
	t.append("y en la hoja maestra (pestaña Puzzles, filas `cat_<id>`). En el generador, el estado sale delante de cada puzle (○ pendiente · ✎ ajustes · ✔ aceptado ·")
	t.append("✖ rechazado) y la casilla **«Solo puzles aceptados»** (pestaña Mapa) hace que en los mapas oficiales solo se repartan los aceptados.")
	t.append("")
	for gr in GRUPOS:
		var nombre: String = gr[0]
		t.append("## %s · %s" % [nombre, String(gr[1])])
		t.append("")
		t.append("Kit «%s». Abrir:" % String(gr[2]))
		t.append("```")
		t.append("E:\\magic-symbols\\tools\\Godot_v4.7.2-stable_win64.exe --path E:\\magic-symbols res://escenas/Prueba%s.tscn" % nombre)
		t.append("```")
		t.append("")
		var hay: bool = false
		for f in _filas:
			if String(f[0]) != nombre:
				continue
			if not hay:
				t.append("| Orden | Sala | Puzle | Necesita | Estado |")
				t.append("|---|---|---|---|---|")
				hay = true
			var e: Dictionary = cat[String(f[2])]
			var nec: String = Catalogo.necesita_dicho(e)
			t.append("| %d | %d | **%s** (`%s`) | %s | %s |" % [int(f[1]), int(f[3]), String(e["titulo"]), String(f[2]), nec if nec != "" else "empujar", String(e["validacion"])])
		for j in _jefes:
			if String(j[0]) == nombre:
				t.append("Sala del jefe: **%s** (la sala grande más lejana del inicio), y un campamento goblin. Semilla %d." % [String(Generador.JEFES[String(j[1])]["titulo"]), int(j[2])])
		t.append("")
	t.append("## Inventario completo")
	t.append("")
	t.append("| Puzle | Tipo | Necesita | Nivel de playtest | Estado |")
	t.append("|---|---|---|---|---|")
	var ids: Array = cat.keys()
	ids.sort()
	for cid in ids:
		var e2: Dictionary = cat[cid]
		var donde: String = "—"
		for f in _filas:
			if String(f[2]) == String(cid):
				donde = "%s · %d" % [String(f[0]), int(f[1])]
		var nec2: String = Catalogo.necesita_dicho(e2)
		t.append("| %s (`%s`) | %s | %s | %s | %s |" % [String(e2["titulo"]), String(cid), String(e2["tipo"]), nec2 if nec2 != "" else "empujar", donde, String(e2["validacion"])])
	for jid in Generador.JEFES:
		var donde_j: String = "—"
		for j in _jefes:
			if String(j[1]) == String(jid):
				donde_j = String(j[0])
		t.append("| %s (`%s`) | sala de enemigos | — | %s | pendiente |" % [String(Generador.JEFES[jid]["titulo"]), String(jid), donde_j])
	t.append("| %s (`%s`) | sala de enemigos | — | PtJefeCueva, PtJefeBosque | pendiente |" % [Generador.CAMPAMENTO_TITULO, Generador.CAMPAMENTO])
	var f2: FileAccess = FileAccess.open(DOC, FileAccess.WRITE)
	f2.store_string("\n".join(t) + "\n")
	f2.close()
	print("inventario: ", DOC)
