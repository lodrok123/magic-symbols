@tool
class_name HorneadorNivel
extends RefCounted

## 7.2 · HORNEADOR: convierte un nivel de letras en `poc_25d/niveles/Nivel_<Nombre>.tscn`, un nivel EDITABLE en Godot.
##
## Lo que escribe (todo con nombres claros para el árbol de escena del editor):
##   Nivel_<Nombre>   (Node3D; metadatos: lado, nombre, origen, horneado)
##     Suelo          GridMap: el suelo casilla a casilla (SUELO, AGUA, PUENTE, TIERRA, ZONA_V). Pintar con la paleta del GridMap.
##     Piezas         el decorado: una instancia de `piezas/<id>.tscn` por pieza, con su Transform3D libre.
##     Borde          los árboles y rocas de las paredes (#): también instancias, aparte para no estorbar al editar.
##     Marcadores     Marcador3D: jugador, goblins, barrera de fuego, puerta, NPC, baldosas, reactivos, botín…
##
## Lo llama la maqueta (PruebaTest2.hornear, tecla F9) con los datos de lo que acaba de colocar; así el .tscn sale EXACTAMENTE
## de lo que se ve, sin repetir aquí las reglas de colocación (giros, escalas, qué letra pone qué).
##
## Qué pasa con una edición previa: si ya hay un Nivel_<Nombre>.tscn, NO se pisa: se aparta como `..._copia_<hora>.tscn`.

const NIVELES: String = "res://poc_25d/niveles/"
const PIEZAS: String = "res://poc_25d/piezas/"
const BIBLIOTECA: String = "res://poc_25d/niveles/suelo_tipos.tres"
const S: float = 2.3
const ALTO: float = 2.3 * 0.45
## Casillas del GridMap: nombre del ítem → letra del mapa que reconstruye el cargador.
const TIPOS: Array = [["SUELO", ".", Color(0.36, 0.58, 0.30), 1.0], ["AGUA", "~", Color(0.25, 0.5, 0.85), 0.6],
	["PUENTE", "b", Color(0.55, 0.4, 0.25), 0.7], ["TIERRA", "g", Color(0.45, 0.33, 0.22), 1.0], ["ZONA_V", "v", Color(0.55, 0.75, 0.3), 1.0],
	# 9.6 (10/10): hierba corta decorativa (no arde) y cauce seco (lecho de piedras que el Juego convierte en agua).
	["CORTA", ",", Color(0.47, 0.68, 0.36), 1.0], ["CAUCE", "c", Color(0.6, 0.58, 0.52), 0.8]]
## Letras que son suelo (no marcadores).
const LETRAS_SUELO: String = ".~bgv#,c"
## Letras que son decorado puesto por la maqueta (van al .tscn como pieza, no como marcador): U = arco de piedra (arco_ruina), t = tienda goblin, x = empalizada goblin, V = estandarte goblin.
## Los canales de ruinas (`-` recto, `L` codo) ya NO son decorado: son marcadores (Marcador3D, con `lleno` = agua o vacío), que es lo
## que el cargador necesita para montar el agua. El suelo bajo ellos es suelo normal; el cargador los pinta como piedra.
const LETRAS_DECOR: String = "UtxV"
## 9.5: mapas de letras en archivo (propuesta D2 del 8/10): `mapas/<nivel>.txt`.
const MAPAS: String = NIVELES + "mapas/"


## 9.5 · ¿Hay mapa en archivo para este nivel? Se busca `mapas/<nivel>.txt` y, si no, en minúsculas.
static func ruta_mapa(nivel: String) -> String:
	for n in [nivel, nivel.to_lower()]:
		var r: String = MAPAS + String(n) + ".txt"
		if FileAccess.file_exists(r):
			return r
	return ""


## 9.5 · Lee las letras de `mapas/<nivel>.txt`: una fila del mapa por línea, tal cual. Las líneas vacías y las que empiezan
## por `;` son comentarios, salvo las instrucciones:
##   ; azar_suelo <fila_desde> <fila_hasta> [semilla]   el `.` de esas filas (contadas desde 0, la primera del mapa) se reparte
##                                                     al azar entre suelo `.`, hierba corta `,` y manchas de tierra `g`
##   ; giro <x> <y> <grados>                            giro de la pieza de esa casilla (p. ej. un arco que se cruza de
##                                                     oeste a este); va a `giros` (casilla -> grados), como GIROS_CELDA
## Devuelve las filas rellenas con " " (sin suelo, bloqueado) hasta un cuadrado: el mapa no tiene por qué serlo (el bosque es
## 19 × 49) y la maqueta trabaja en un cuadrado de `lado`. `tam` (si se pasa) recibe el ancho y el alto reales.
static func leer_mapa(nivel: String, tam: Array = [], giros: Dictionary = {}) -> PackedStringArray:
	var r: String = ruta_mapa(nivel)
	var filas: PackedStringArray = PackedStringArray()
	if r == "":
		return filas
	var f := FileAccess.open(r, FileAccess.READ)
	if f == null:
		return filas
	var azar: Array = []
	for linea in f.get_as_text().split("\n"):
		var l: String = String(linea).replace("\r", "")
		if l.strip_edges() == "":
			continue
		if l.begins_with(";"):
			var p: PackedStringArray = l.substr(1).strip_edges().split(" ", false)
			if p.size() >= 3 and p[0] == "azar_suelo":
				azar.append([int(p[1]), int(p[2]), int(p[3]) if p.size() >= 4 else 10])
			elif p.size() >= 4 and p[0] == "giro":
				giros[Vector2i(int(p[1]), int(p[2]))] = float(p[3])
			continue
		filas.append(l)
	for a in azar:
		filas = _azar_suelo(filas, int(a[0]), int(a[1]), int(a[2]))
	var ancho: int = 0
	for fila in filas:
		ancho = maxi(ancho, fila.length())
	tam.clear()
	tam.append_array([ancho, filas.size()])
	var lado: int = maxi(ancho, filas.size())
	for y in range(filas.size()):
		filas[y] = filas[y] + " ".repeat(lado - filas[y].length())
	while filas.size() < lado:
		filas.append(" ".repeat(lado))
	return filas


## 9.6 · Reparte al azar el suelo `.` de las filas `desde`..`hasta`: manchas de tierra (`g`) y de hierba corta (`,`) con forma
## de mancha (ruido de valor, no casillas sueltas), y el resto suelo. NUNCA hierba alta (`v`): arde y cambiaría los puzles del
## fuego. Siempre sale igual para la misma semilla (hornear dos veces da el mismo nivel).
static func _azar_suelo(filas: PackedStringArray, desde: int, hasta: int, semilla: int) -> PackedStringArray:
	for y in range(maxi(desde, 0), mini(hasta + 1, filas.size())):
		var fila: String = filas[y]
		for x in range(fila.length()):
			if fila[x] != ".":
				continue
			var p := Vector2(float(x), float(y))
			var tierra: float = _vruido(p * 0.45, semilla) * 0.7 + _vruido(p * 1.1, semilla + 1) * 0.3
			var hierba: float = _vruido(p * 0.35, semilla + 2) * 0.7 + _vruido(p * 0.9, semilla + 3) * 0.3
			var l: String = "."
			if tierra > 0.66:
				l = "g"
			elif hierba > 0.5:
				l = ","
			fila = fila.substr(0, x) + l + fila.substr(x + 1)
		filas[y] = fila
	return filas


static func _vruido(p: Vector2, sal: int) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f: Vector2 = p - Vector2(i)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a: float = _azar(i, sal)
	var b: float = _azar(i + Vector2i(1, 0), sal)
	var c: float = _azar(i + Vector2i(0, 1), sal)
	var d: float = _azar(i + Vector2i(1, 1), sal)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _azar(i: Vector2i, sal: int) -> float:
	return float(absi((i.x * 73856093) ^ (i.y * 19349663) ^ (sal * 83492791)) % 10007) / 10006.0


## 7.11: agrupa casillas `B` (barrera de fuego) en tramos rectos. Un tramo es vertical si sus casillas tienen otra `B` arriba o
## abajo (igual que hacía la maqueta casilla a casilla); el resto, horizontales. Devuelve [{celdas: [Vector2i] en orden, vertical: bool}].
static func tramos_barrera(celdas: Array) -> Array:
	var hay: Dictionary = {}
	for c in celdas:
		hay[c] = true
	var visto: Dictionary = {}
	var res: Array = []
	var orden: Array = celdas.duplicate()
	orden.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in orden:
		var cc: Vector2i = c
		if visto.has(cc):
			continue
		var vert: bool = hay.has(cc + Vector2i(0, 1)) or hay.has(cc + Vector2i(0, -1))
		var paso: Vector2i = Vector2i(0, 1) if vert else Vector2i(1, 0)
		var tramo: Array = []
		var q: Vector2i = cc
		# en orden fila a fila, `cc` es la casilla más arriba / más a la izquierda que queda de su tramo
		while hay.has(q) and not visto.has(q):
			var q_vert: bool = hay.has(q + Vector2i(0, 1)) or hay.has(q + Vector2i(0, -1))
			if q_vert != vert:
				break
			tramo.append(q)
			visto[q] = true
			q += paso
		res.append({"celdas": tramo, "vertical": vert})
	return res


static func nombre_archivo(nivel: String) -> String:
	return "Nivel_" + nivel.substr(0, 1).to_upper() + nivel.substr(1)


static func ruta(nivel: String) -> String:
	return NIVELES + nombre_archivo(nivel) + ".tscn"


## ¿Existe el .tscn de este nivel CON ESE NOMBRE EXACTO? En Windows `ResourceLoader.exists` (y `FileAccess.file_exists`) no distinguen
## mayúsculas: con un `nivel_Bosque.tscn` viejo en la carpeta, `Nivel_Bosque.tscn` «existía» y la maqueta cargaba aquel (un 23 × 23
## de jugabilidad) en vez de leer `mapas/Bosque.txt`. Aquí se compara con la lista de nombres tal como están escritos en disco.
static func existe_nivel(nivel: String) -> bool:
	var dir: DirAccess = DirAccess.open(NIVELES)
	if dir == null:
		return false
	var buscado: String = nombre_archivo(nivel) + ".tscn"
	for f in dir.get_files():
		if f == buscado or f == buscado + ".remap":
			return true
	return false


## La paleta del GridMap (se crea una vez y se reutiliza; Pablo puede añadirle ítems).
static func biblioteca() -> MeshLibrary:
	if ResourceLoader.exists(BIBLIOTECA):
		var b: MeshLibrary = load(BIBLIOTECA) as MeshLibrary
		if b != null:
			# 9.6: si la paleta guardada es anterior a algún tipo (CORTA, CAUCE…), se le añade al final y se guarda: los ítems
			# que ya tenía (y lo que Pablo le haya añadido) no se tocan.
			var hay: Dictionary = {}
			for it in b.get_item_list():
				hay[b.get_item_name(it)] = true
			var nuevos: int = 0
			for t in TIPOS:
				if not hay.has(String((t as Array)[0])):
					var lista: PackedInt32Array = b.get_item_list()
					var id: int = (lista[lista.size() - 1] + 1) if lista.size() > 0 else 0
					_crear_item(b, id, t)
					nuevos += 1
			if nuevos > 0:
				ResourceSaver.save(b, BIBLIOTECA)
			return b
	var lib := MeshLibrary.new()
	for i in range(TIPOS.size()):
		_crear_item(lib, i, TIPOS[i])
	DirAccess.make_dir_recursive_absolute(NIVELES)
	ResourceSaver.save(lib, BIBLIOTECA)
	return lib


## Un ítem de la paleta del GridMap: caja del color y alto del tipo, con colisión solo para el editor.
static func _crear_item(lib: MeshLibrary, i: int, tipo: Array) -> void:
	var t: Array = tipo
	var h: float = ALTO * float(t[3])
	var bm := BoxMesh.new()
	bm.size = Vector3(S * 0.98, h, S * 0.98)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(t[2] as Color, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = mat
	lib.create_item(i)
	lib.set_item_name(i, String(t[0]))
	lib.set_item_mesh(i, bm)
	lib.set_item_mesh_transform(i, Transform3D(Basis(), Vector3(0.0, h * 0.5, 0.0)))
	# Colisión solo para el EDITOR: al soltar una pieza arrastrando (o con «Ajustar al suelo», RePág) Godot la apoya en lo
	# que tenga colisión; sin ella caía a y = 0, dentro del bloque. En el juego el GridMap no entra en el árbol.
	var forma := BoxShape3D.new()
	forma.size = Vector3(S, h, S)
	lib.set_item_shapes(i, [forma, Transform3D(Basis(), Vector3(0.0, h * 0.5, 0.0))])


## Letra de suelo de un ítem del GridMap (por su nombre).
static func letra_de_item(lib: MeshLibrary, item: int) -> String:
	var nombre: String = lib.get_item_name(item)
	for t in TIPOS:
		if String((t as Array)[0]) == nombre:
			return String((t as Array)[1])
	return "."


## Hornea. `datos`:
##   nivel: String            nombre corto del nivel («jugabilidad», «test2»)
##   mapa: PackedStringArray  las letras
##   registro: Array          [id, casilla Vector2i, Transform3D, bloquea: bool, origen: "decor" | "marcador"]
##   extras: Array            marcadores de datos / letras fuera del mapa: {letra, grupo, tipo, c: Vector2i, giro: float}
## Devuelve la ruta escrita ("" si falló).
static func hornear(datos: Dictionary) -> String:
	var nivel: String = String(datos["nivel"])
	var mapa: PackedStringArray = datos["mapa"]
	var lado: int = mapa.size()
	DirAccess.make_dir_recursive_absolute(NIVELES)
	var destino: String = ruta(nivel)
	if FileAccess.file_exists(destino):
		var sello: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
		var copia: String = NIVELES + nombre_archivo(nivel) + "_copia_" + sello + ".tscn"
		DirAccess.rename_absolute(destino, copia)
		push_warning("Hornear: ya existía %s con sus ediciones. Lo he apartado como %s; el nuevo sale de las LETRAS y no las tiene." % [destino, copia])
	var raiz := Node3D.new()
	raiz.name = nombre_archivo(nivel)
	raiz.set_meta("lado", lado)
	raiz.set_meta("nombre", nivel)
	raiz.set_meta("origen", "letras")
	raiz.set_meta("horneado", Time.get_datetime_string_from_system())

	# --- Suelo ---
	var suelo := GridMap.new()
	suelo.name = "Suelo"
	var lib: MeshLibrary = biblioteca()
	suelo.mesh_library = lib
	suelo.cell_size = Vector3(S, ALTO, S)
	suelo.cell_center_y = false
	raiz.add_child(suelo)
	suelo.owner = raiz
	var item_de: Dictionary = {}
	for i in lib.get_item_list():
		item_de[letra_de_item(lib, i)] = i
	for y in range(lado):
		for x in range(mapa[y].length()):
			var l: String = mapa[y][x]
			if l == " ":
				continue                    # 9.5: fuera del mapa (relleno hasta el cuadrado): sin suelo
			if l == "#" or not item_de.has(l):
				l = "."                     # bajo una pared, un marcador o un decorado el suelo es suelo
			if l == "." or item_de.has(l):
				var it: int = int(item_de.get(l, item_de["."]))
				suelo.set_cell_item(Vector3i(x, 0, y), it)

	# --- Piezas y borde ---
	var piezas := Node3D.new()
	piezas.name = "Piezas"
	raiz.add_child(piezas)
	piezas.owner = raiz
	var borde := Node3D.new()
	borde.name = "Borde"
	raiz.add_child(borde)
	borde.owner = raiz
	var cache: Dictionary = {}
	var nombres: Dictionary = {}
	var giro_marcador: Dictionary = {}     # casilla → giro (rad) de la pieza que puso un marcador (puerta, puesto…)
	var sin_escena: Dictionary = {}
	var n_piezas: int = 0
	for r in (datos["registro"] as Array):
		var d: Array = r
		var id: String = String(d[0])
		var c: Vector2i = d[1]
		var t: Transform3D = d[2]
		if String(d[4]) == "marcador":
			if not giro_marcador.has(c):
				giro_marcador[c] = t.basis.orthonormalized().get_euler().y
			continue
		if not cache.has(id):
			cache[id] = load(PIEZAS + id + ".tscn") as PackedScene if ResourceLoader.exists(PIEZAS + id + ".tscn") else null
		var ps: PackedScene = cache[id]
		if ps == null:
			sin_escena[id] = int(sin_escena.get(id, 0)) + 1
			continue
		var nodo: Node3D = ps.instantiate() as Node3D
		var base: String = "%s_%d_%d" % [id, c.x, c.y]
		var k: int = int(nombres.get(base, 0))
		nombres[base] = k + 1
		nodo.name = base if k == 0 else "%s_%d" % [base, k]
		nodo.transform = t
		var bq: bool = bool(d[3])
		if bool(nodo.get_meta("bloquea", false)) != bq:
			nodo.set_meta("bloquea", bq)         # esta instancia se aparta de lo normal de la pieza
		var destino_nodo: Node3D = borde if mapa[c.y][c.x] == "#" else piezas
		destino_nodo.add_child(nodo)
		nodo.owner = raiz
		n_piezas += 1
	for id in sin_escena:
		push_warning("Hornear: no hay piezas/%s.tscn (¿falta ejecutar el generador de piezas?): %d sin colocar." % [id, int(sin_escena[id])])

	# --- Marcadores ---
	var marc := Node3D.new()
	marc.name = "Marcadores"
	raiz.add_child(marc)
	marc.owner = raiz
	var n_marc: int = 0
	var cuenta: Dictionary = {}
	var lista: Array = []
	var cel_b: Array = []
	for y in range(lado):
		for x in range(mapa[y].length()):
			var l: String = mapa[y][x]
			if LETRAS_SUELO.contains(l) or LETRAS_DECOR.contains(l) or l == " ":
				continue
			if l == "B":
				cel_b.append(Vector2i(x, y))       # las barreras se fusionan en UN marcador por tramo (abajo)
				continue
			lista.append({"letra": l, "grupo": "", "tipo": "", "c": Vector2i(x, y), "giro": float(giro_marcador.get(Vector2i(x, y), 0.0))})
	for tr in tramos_barrera(cel_b):
		var td: Dictionary = tr
		var tc: Array = td["celdas"]
		var c0: Vector2i = tc[0]
		var c1: Vector2i = tc[tc.size() - 1]
		var medio: Vector2 = (Vector2(c0) + Vector2(c1)) * 0.5
		lista.append({"letra": "B", "grupo": "", "tipo": "", "c": c0, "largo": tc.size(), "centro": medio,
			"giro": -PI * 0.5 if bool(td["vertical"]) else 0.0})
	var rotulos: Array = []
	for e in (datos["extras"] as Array):
		var ed: Dictionary = e
		var cc: Vector2i = ed["c"]
		if ed.has("rotulo"):
			rotulos.append(ed)
			continue
		lista.append({"letra": String(ed.get("letra", "")), "grupo": String(ed.get("grupo", "")), "tipo": String(ed.get("tipo", "")),
			"c": cc, "giro": float(giro_marcador.get(cc, float(ed.get("giro", 0.0))))})
	for m in lista:
		var md: Dictionary = m
		var cm: Vector2i = md["c"]
		var mk := Marcador3D.new()
		var etiqueta: String = String(md["letra"]) if String(md["letra"]) != "" else String(md["grupo"])
		var kk: int = int(cuenta.get(etiqueta, 0))
		cuenta[etiqueta] = kk + 1
		mk.name = "%s_%d_%d" % [etiqueta, cm.x, cm.y]
		mk.letra = String(md["letra"])
		mk.grupo = String(md["grupo"])
		mk.tipo = String(md["tipo"])
		mk.position = Vector3((float(cm.x) + 0.5) * S, ALTO, (float(cm.y) + 0.5) * S)
		if md.has("centro"):
			var ct: Vector2 = md["centro"]
			mk.position = Vector3((ct.x + 0.5) * S, ALTO, (ct.y + 0.5) * S)
			mk.largo = int(md["largo"])
		mk.rotation.y = float(md["giro"])
		marc.add_child(mk)
		mk.owner = raiz
		# grupo persistente: se guarda en el .tscn y el contrato (grupo «goblin», «puerta»…) vale sin ejecutar el script
		if mk.letra != "" and Marcador3D.LETRAS.has(mk.letra):
			var g: String = String((Marcador3D.LETRAS[mk.letra] as Dictionary).get("grupo", ""))
			if g != "":
				mk.add_to_group(g, true)
			if mk.tipo == "":
				mk.tipo = String((Marcador3D.LETRAS[mk.letra] as Dictionary).get("tipo", ""))
		elif mk.grupo != "":
			mk.add_to_group(mk.grupo, true)
		mk.add_to_group("marcador", true)
		n_marc += 1

	# --- Rótulos (texto en el suelo, delante de la casilla): el banco de pruebas los usa para nombrar cada pieza ---
	if not rotulos.is_empty():
		var rot := Node3D.new()
		rot.name = "Rotulos"
		raiz.add_child(rot)
		rot.owner = raiz
		for r in rotulos:
			var rd: Dictionary = r
			var rc: Vector2i = rd["c"]
			var et := Label3D.new()
			et.name = "rotulo_%s" % String(rd["rotulo"])
			et.text = String(rd["rotulo"]).replace("_", "\n")
			et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			et.no_depth_test = true
			et.pixel_size = 0.004
			et.font_size = 48
			et.outline_size = 10
			et.position = Vector3((float(rc.x) + 0.5) * S, ALTO + 0.15, (float(rc.y) + 0.97) * S)
			rot.add_child(et)
			et.owner = raiz

	var ps_nivel := PackedScene.new()
	var e: int = ps_nivel.pack(raiz)
	raiz.free()
	if e != OK:
		push_error("Hornear: no se pudo empaquetar el nivel (error %d)" % e)
		return ""
	e = ResourceSaver.save(ps_nivel, destino)
	if e != OK:
		push_error("Hornear: no se pudo guardar %s (error %d)" % [destino, e])
		return ""
	print("Horneado: ", destino, " (", n_piezas, " piezas, ", n_marc, " marcadores, suelo ", lado, "×", lado, " como mucho)")
	return destino
