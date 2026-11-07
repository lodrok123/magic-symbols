extends SceneTree

## GENERADOR (7/11) del mapa de muestreo del pack Fantasy Provencal: escribe `mundo/datos_nivel/mapas/Provencal.txt` (el plano de letras y las lineas `; pieza ... decorado`) con las
## 75 piezas prov_* (las de `TablaProvencal.PIEZAS`) y unas pocas EQUIVALENTES del proyecto (barril, caja, jarron, roca_grande, arbusto, arbol_redondo, valla, puente...) al lado de cada una.
## Reejecutable: lee las escenas de arte/piezas para medir cada pieza y deja a cada una su casilla con 1 casilla libre alrededor (los edificios, con toda su huella libre).
##   godot --headless --path . --script res://herramientas/generar_mapa_provencal.gd
## Disposicion: 2 columnas x 3 filas de zonas (atrezo, madera_y_paso / roca, edificio / vegetacion) separadas por caminos `g`; la jugadora (S) nace en el camino central, a media altura.
## Letras: # limite (no se pisa) · , hierba corta · g camino · S jugadora. La hierba se pisa; las piezas que bloquean lo hacen con su `cuerpo` (colision horneada en la escena).
## Las lineas `; rotulo x y texto` las lee `escenas/provencal_rotulos.gd` (titulo de zona); los rotulos de cada pieza salen de su nombre (`d_<id>`).

const SALIDA: String = "res://mundo/datos_nivel/mapas/Provencal.txt"
const S: float = 2.3
const ANCHO_ZONA: int = 28                 ## casillas de ancho de cada zona
const CAMINO: int = 3                      ## ancho de los caminos entre zonas
const MARGEN: int = 3                      ## borde (# + camino) alrededor
const ZONAS: Array = [                      ## [categoria, titulo, columna, fila]
	["atrezo", "ATREZO", 0, 0], ["madera_y_paso", "MADERA_Y_PASO", 1, 0],
	["roca", "ROCA", 0, 1], ["edificio", "EDIFICIO", 1, 1],
	["vegetacion", "VEGETACION", 0, 2],
]
## prov_<x>: equivalente(s) del proyecto que se ponen justo despues, para comparar estilo y escala.
const EQUIVALENTES: Dictionary = {
	"prov_barrel": ["barril"], "prov_crate_01": ["caja"], "prov_jar_01": ["jarron"],
	"prov_fence_01": ["valla"], "prov_bridge": ["puente"],
	"prov_bush_01": ["arbusto"], "prov_tree_cypress": ["arbol_redondo"], "prov_grassfield_01_b": ["hierba_alta"],
	"prov_rock_large_01": ["roca_grande"], "prov_rock_small_01": ["rocas_pequenas"], "prov_rock_cliff_01": ["roca_musgosa"],
	"prov_house_barn": ["puesto"], "prov_shrine": ["arco_ruina"], "prov_house_02": ["estatua_piedra"],
}


func _initialize() -> void:
	var por_cat: Dictionary = {}
	for nombre in TablaProvencal.PIEZAS.keys():
		var d: Dictionary = TablaProvencal.PIEZAS[nombre]
		var cat: String = String(d["cat"])
		if not por_cat.has(cat):
			por_cat[cat] = []
		(por_cat[cat] as Array).append(TablaProvencal.id_de(String(nombre)))
	var zonas: Array = []
	var altos_fila: Array = [0, 0, 0]
	for z in ZONAS:
		var ids: Array = por_cat.get(z[0], [])
		ids.sort()
		var lista: Array = []
		for id in ids:
			lista.append(id)
			for eq in EQUIVALENTES.get(id, []):
				lista.append(eq)
		var anc: int = _ancho_zona(String(z[0]))
		var empaq: Dictionary = _empaquetar(lista, anc)
		zonas.append({"cat": z[0], "titulo": z[1], "col": z[2], "fila": z[3], "ancho": anc, "piezas": empaq["piezas"], "alto": empaq["alto"]})
		altos_fila[z[3]] = maxi(int(altos_fila[z[3]]), int(empaq["alto"]))
	var ancho: int = MARGEN + 2 * ANCHO_ZONA + CAMINO + MARGEN
	var alto: int = MARGEN + int(altos_fila[0]) + CAMINO + int(altos_fila[1]) + CAMINO + int(altos_fila[2]) + MARGEN
	var celdas: Array = []
	for y in range(alto):
		var fila: PackedStringArray = PackedStringArray()
		for x in range(ancho):
			fila.append("#" if (x == 0 or y == 0 or x == ancho - 1 or y == alto - 1) else "g")
		celdas.append(fila)
	var lineas: PackedStringArray = PackedStringArray()
	var zy: Array = [MARGEN, MARGEN + int(altos_fila[0]) + CAMINO, MARGEN + int(altos_fila[0]) + CAMINO + int(altos_fila[1]) + CAMINO]
	for z in zonas:
		var ox: int = MARGEN + int(z["col"]) * (ANCHO_ZONA + CAMINO)
		var oy: int = int(zy[int(z["fila"])])
		for y in range(int(altos_fila[int(z["fila"])])):
			var fila_z: PackedStringArray = celdas[oy + y]
			for x in range(int(z["ancho"])):
				fila_z[ox + x] = ","
			celdas[oy + y] = fila_z
		lineas.append("; rotulo %d %d %s" % [ox + int(z["ancho"]) / 2, oy - 1, z["titulo"]])
		lineas.append("; rect %s %d %d %d %d" % [z["titulo"], ox, oy, int(z["ancho"]), int(z["alto"])])
		for p in z["piezas"]:
			var cx: int = ox + int(p["x"])
			var cy: int = oy + int(p["y"])
			lineas.append("; pieza d_%s decorado %d %d modelo=%s" % [p["id"], cx, cy, p["id"]])
	# La jugadora en el cruce central de caminos.
	var sx: int = ancho / 2
	var sy: int = int(zy[1]) + int(altos_fila[1]) / 2
	var fila_s: PackedStringArray = celdas[sy]
	fila_s[sx] = "S"
	celdas[sy] = fila_s
	var cab: PackedStringArray = PackedStringArray([
		"; MAPA DE MUESTREO del pack Fantasy Provencal (Leartes Studios), 7/11/2026. %d x %d. Lo GENERA herramientas/generar_mapa_provencal.gd (no editar a mano: se pisa al regenerar)." % [ancho, alto],
		"; Para pasear con la jugadora y revisar las piezas en el juego: escena escenas/PruebaProvencal.tscn (F6 en el editor) o el nivel «Provencal» de Niveles.ESCENAS.",
		"; Zonas (2 x 3, separadas por caminos): fila 1 ATREZO · MADERA_Y_PASO; fila 2 ROCA · EDIFICIO; fila 3 VEGETACION. Cada pieza en su casilla con 1 libre alrededor; tras cada prov_* van",
		"; sus equivalentes del proyecto (barril, caja, jarron, valla, puente, arbusto, arbol_redondo, hierba_alta, roca_grande, rocas_pequenas, roca_musgosa, puesto, arco_ruina, estatua_piedra).",
		"; # limite · , hierba corta · g camino · S jugadora (camino central).",
	])
	var salida: PackedStringArray = PackedStringArray()
	salida.append_array(cab)
	for fila in celdas:
		salida.append("".join(fila as PackedStringArray))
	salida.append_array(lineas)
	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	if f == null:
		print("FALLO  no se pudo escribir ", SALIDA)
		quit(1)
		return
	f.store_string("\n".join(salida) + "\n")
	f.close()
	print("OK     %s: %d x %d casillas, %d piezas, zonas: %s" % [SALIDA, ancho, alto, lineas.size() - ZONAS.size(), str(altos_fila)])
	quit()


## La vegetacion (la zona con mas piezas) ocupa las dos columnas de la fila 3.
func _ancho_zona(cat: String) -> int:
	return 2 * ANCHO_ZONA + CAMINO if cat == "vegetacion" else ANCHO_ZONA


## Coloca las piezas en filas dentro de una zona. Devuelve {piezas: [{id, x, y}], alto}. La casilla de cada pieza es el centro de su hueco: huecos impares (con >= 1 casilla libre a cada lado)
## para las que miden mas de una casilla; las pequenas, 2 x 2 (la pieza en la primera casilla y la libre al lado, que comparte con la siguiente).
func _empaquetar(ids: Array, ancho_zona: int) -> Dictionary:
	var res: Array = []
	var x: int = 1
	var y: int = 1
	var alto_fila: int = 0
	for id in ids:
		var m: Vector2 = _medida(String(id))
		var gw: Array = _hueco(m.x)
		var gd: Array = _hueco(m.y)
		var sw: int = int(gw[0])
		var sd: int = int(gd[0])
		if x + sw > ancho_zona - 1:
			x = 1
			y += alto_fila
			alto_fila = 0
		res.append({"id": id, "x": x + int(gw[1]), "y": y + int(gd[1])})
		x += sw
		alto_fila = maxi(alto_fila, sd)
	return {"piezas": res, "alto": y + alto_fila + 1}


## [tamaño del hueco, indice de la casilla de la pieza dentro del hueco] para una pieza de `medida` unidades.
func _hueco(medida: float) -> Array:
	var n: int = int(ceil(medida / S - 0.05))
	if n <= 1:
		return [2, 0]
	var sw: int = n + 2
	if sw % 2 == 0:
		sw += 1
	return [sw, sw / 2]


## Ancho y fondo (u) de la pieza: la union de todas sus mallas, con la escala de su escena.
func _medida(id: String) -> Vector2:
	var ps: PackedScene = load(TablaProvencal.CARPETA_PIEZAS + id + ".tscn") as PackedScene
	if ps == null:
		print("AVISO  sin escena ", id)
		return Vector2(S, S)
	var n: Node3D = ps.instantiate() as Node3D
	var caja: Array = [AABB(), false]
	_unir(n, Transform3D.IDENTITY, caja)
	n.free()
	var a: AABB = caja[0]
	return Vector2(a.size.x, a.size.z)


func _unir(n: Node, acum: Transform3D, caja: Array) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		caja[0] = b if not bool(caja[1]) else (caja[0] as AABB).merge(b)
		caja[1] = true
	for h in n.get_children():
		_unir(h, t, caja)
