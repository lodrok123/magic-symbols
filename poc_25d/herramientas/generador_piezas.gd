@tool
class_name GeneradorPiezas
extends RefCounted

## 7.1 · GENERADOR DE PIEZAS-ESCENA. Crea `poc_25d/piezas/<id>.tscn` para cada pieza de la maqueta (las de Pieza3D.MEDIDA con
## modelo): una escena que se arrastra al nivel desde el editor y que ya lleva su colisión.
##
## Estructura de cada pieza (todas iguales, para que el cargador y Pablo sepan qué esperar):
##   <id>  (Node3D, origen = centro de la BASE, y = 0)        metadatos: id, bloquea, reactivo, inflamable
##     modelo  (Node3D)     el modelo del .glb ya a su medida (el mismo que dibuja la maqueta)
##     cuerpo  (StaticBody3D, capa MUNDO) con una CollisionShape3D por trozo: sale del modelo (ver COLISION)
##   o, para hierba y telaraña, un Area3D «zona» sin cuerpo.
##
## Cómo se usa: en el editor, abrir `poc_25d/herramientas/generar_piezas_editor.gd` y pulsar Archivo → Ejecutar (Ctrl+Shift+X);
## o desde consola: godot --headless --path . --script res://poc_25d/herramientas/generar_piezas_cli.gd
## Regenera TODAS las piezas: si Pablo ha retocado una pieza a mano, que la renombre antes (esto sobrescribe).

const CARPETA: String = "res://poc_25d/piezas/"
const CAPA_MUNDO: int = 1 << 10          ## capa 11 «MUNDO» (= Lanzador3D.CAPA_SOLIDO)

## Cómo se hace la colisión de cada pieza:
##   "tronco"  → convexa solo con la parte baja y estrecha del modelo (el tronco, no la copa: se pasa por debajo)
##   "mesa"    → convexa solo con la parte baja (la mesa del puesto, sin el toldo)
##   "convexa" → casco convexo de todo el modelo (roca, tocón, caja…)
##   "trimesh" → la malla tal cual (puente, pasarela: se camina sobre ellos)
##   "ninguna" → sin cuerpo
const COLISION: Dictionary = {
	"arbol_redondo": "tronco", "arbol_redondo_2": "tronco", "pino": "tronco", "pino_2": "tronco",
	"arbusto": "convexa", "arbusto_flores": "convexa", "arbusto_otono": "convexa", "seto_seco": "convexa",
	"roca_cristal": "convexa", "roca_grande": "convexa", "piedras": "convexa", "tocon": "convexa", "tronco": "convexa",
	"valla": "convexa", "cartel": "convexa", "totem_runico": "convexa", "brasero": "convexa", "fogata": "convexa",
	"puesto": "mesa", "puesto_mercado": "mesa", "dummy": "convexa", "caja_pequena": "convexa", "caja": "convexa",
	"barril": "convexa", "cofre": "convexa", "pilar": "convexa",
	"seta_reactiva": "convexa", "flor_reactiva": "convexa", "raiz_reactiva": "convexa",
	"puente": "trimesh", "pasadero": "trimesh",
}
## Bloquea por defecto (cada instancia del nivel puede cambiarlo con el metadato `bloquea`). Lo que no sale aquí no bloquea.
const BLOQUEA: Array = ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2", "arbusto", "arbusto_flores", "arbusto_otono",
	"seto_seco", "roca_cristal", "roca_grande", "tocon", "tronco", "valla", "cartel", "totem_runico", "brasero", "fogata",
	"puesto", "puesto_mercado", "dummy", "caja_pequena", "caja", "barril", "cofre", "pilar", "seta_reactiva", "flor_reactiva",
	"raiz_reactiva"]
## Las que tienen comportamiento propio (las crea `Reactivo3D` / el Juego; la pieza solo da modelo y colisión).
const REACTIVO: Array = ["seto_seco", "tronco", "totem_runico", "fogata", "brasero", "placa_peso", "seta_reactiva",
	"flor_reactiva", "raiz_reactiva", "puente", "dummy"]
## Las que arden.
const INFLAMABLE: Array = ["arbol_redondo", "arbol_redondo_2", "pino", "pino_2", "arbusto", "arbusto_flores", "arbusto_otono",
	"seto_seco", "tronco", "tocon", "valla", "matas", "juncos", "cartel", "puesto", "puesto_mercado", "caja", "caja_pequena", "barril"]
## Parte baja que cuenta como «tronco» y como «mesa»: fracción de la altura del modelo, y radio máximo del tronco.
const TRONCO_ALTO_MAX: float = 1.9
const TRONCO_RADIO_MAX: float = 0.45
const MESA_FRACCION: float = 0.45

## Zonas sin cuerpo (hierba crecida y telaraña): id → tamaño de la zona (la casilla entera).
const ZONAS: Dictionary = {"hierba_crecida": Vector3(2.3, 1.2, 2.3), "telarana": Vector3(2.3, 1.2, 2.3)}


## Genera todas. Devuelve cuántas escribió.
static func generar_todas() -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var n: int = 0
	var ids: Array = Pieza3D.MEDIDA.keys()
	ids.sort()
	for id in ids:
		if generar(String(id)):
			n += 1
	for z in ZONAS.keys():
		if _generar_zona(String(z)):
			n += 1
	return n


## Una pieza. false si no hay modelo para ese id (no se escribe nada: se avisa).
static func generar(id: String) -> bool:
	var vis: Node3D = Pieza3D.crear_visual(id)
	if vis == null:
		push_warning("GeneradorPiezas: sin modelo para '%s' (falta la biblioteca .glb); no se genera." % id)
		return false
	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", BLOQUEA.has(id))
	raiz.set_meta("reactivo", REACTIVO.has(id))
	raiz.set_meta("inflamable", INFLAMABLE.has(id))
	vis.name = "modelo"
	raiz.add_child(vis)
	vis.owner = raiz
	_dueno(vis, raiz)
	var tipo: String = String(COLISION.get(id, "ninguna"))
	if tipo != "ninguna":
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "cuerpo"
		cuerpo.collision_layer = CAPA_MUNDO
		cuerpo.collision_mask = 0
		raiz.add_child(cuerpo)
		cuerpo.owner = raiz
		var formas: Array = _formas(vis, tipo, id)
		var i: int = 0
		for f in formas:
			var cs := CollisionShape3D.new()
			cs.name = "forma_%d" % i
			cs.shape = f as Shape3D
			cuerpo.add_child(cs)
			cs.owner = raiz
			i += 1
		if formas.is_empty():
			push_warning("GeneradorPiezas: '%s' no ha producido colisión (%s)." % [id, tipo])
	return _guardar(raiz, id)


static func _generar_zona(id: String) -> bool:
	var raiz := Node3D.new()
	raiz.name = id
	raiz.set_meta("id", id)
	raiz.set_meta("bloquea", false)
	raiz.set_meta("reactivo", id == "telarana")
	raiz.set_meta("inflamable", true)
	var area := Area3D.new()
	area.name = "zona"
	area.collision_layer = CAPA_MUNDO
	area.collision_mask = 0
	area.add_to_group(id)
	raiz.add_child(area)
	area.owner = raiz
	var cs := CollisionShape3D.new()
	cs.name = "forma"
	var caja := BoxShape3D.new()
	caja.size = ZONAS[id]
	cs.shape = caja
	cs.position.y = caja.size.y * 0.5
	area.add_child(cs)
	cs.owner = raiz
	return _guardar(raiz, id)


static func _guardar(raiz: Node3D, id: String) -> bool:
	var ps := PackedScene.new()
	var e: int = ps.pack(raiz)
	raiz.free()
	if e != OK:
		push_warning("GeneradorPiezas: no se pudo empaquetar '%s' (%d)." % [id, e])
		return false
	e = ResourceSaver.save(ps, CARPETA + id + ".tscn")
	if e != OK:
		push_warning("GeneradorPiezas: no se pudo guardar '%s' (%d)." % [id, e])
		return false
	return true


static func _dueno(n: Node, raiz: Node) -> void:
	for h in n.get_children():
		h.owner = raiz
		_dueno(h, raiz)


## --- Colisión a partir del modelo ---

## Todos los (MeshInstance3D, transform respecto a la raíz de la pieza) del modelo.
static func _mallas(n: Node, acum: Transform3D, fuera: Array) -> void:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		fuera.append([n, t])
	for h in n.get_children():
		_mallas(h, t, fuera)


static func _formas(vis: Node3D, tipo: String, id: String) -> Array:
	var mallas: Array = []
	_mallas(vis, Transform3D.IDENTITY, mallas)     # vis es hijo de la raíz con transform identidad
	var res: Array = []
	if tipo == "trimesh":
		for par in mallas:
			var m: Mesh = (par[0] as MeshInstance3D).mesh
			var sh: ConcavePolygonShape3D = m.create_trimesh_shape()
			if sh == null:
				continue
			# la malla vive en el espacio del MeshInstance: lleva su transform dentro de los puntos
			var tf: Transform3D = par[1]
			var caras: PackedVector3Array = sh.get_faces()
			for k in range(caras.size()):
				caras[k] = tf * caras[k]
			sh.set_faces(caras)
			res.append(sh)
		return res
	# convexas: nube de puntos en el espacio de la pieza
	var pts := PackedVector3Array()
	for par in mallas:
		var tf2: Transform3D = par[1]
		for v in (par[0] as MeshInstance3D).mesh.get_faces():
			pts.append(tf2 * v)
	if pts.is_empty():
		return res
	var ymax: float = -INF
	for p in pts:
		ymax = maxf(ymax, p.y)
	var filtrados := PackedVector3Array()
	if tipo == "tronco":
		# la columna central: lo bajo y cerca del eje (los modelos están centrados en el origen). Medido en las bandas de
		# altura: el radio mínimo del tronco es ~0,4 hasta los 3 m, y la copa se ensancha desde los 0,6 m.
		for p in pts:
			if p.y <= TRONCO_ALTO_MAX and Vector2(p.x, p.z).length() <= TRONCO_RADIO_MAX:
				filtrados.append(p)
	elif tipo == "mesa":
		for p in pts:
			if p.y <= ymax * MESA_FRACCION:
				filtrados.append(p)
	else:
		filtrados = pts
	if filtrados.size() < 4:
		return res
	res.append(_casco(filtrados))
	return res


## Casco convexo COMPACTO de una nube de puntos: se le da a un ConvexPolygonShape3D y se leen los vértices de su malla
## de depuración (que es el casco ya calculado), para no guardar miles de puntos en el .tscn.
static func _casco(pts: PackedVector3Array) -> ConvexPolygonShape3D:
	var tmp := ConvexPolygonShape3D.new()
	tmp.points = pts
	var dbg: ArrayMesh = tmp.get_debug_mesh()
	var unicos: Dictionary = {}
	for s in range(dbg.get_surface_count()):
		var arr: Array = dbg.surface_get_arrays(s)
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			unicos[Vector3(snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001))] = true
	var res := ConvexPolygonShape3D.new()
	var lista := PackedVector3Array()
	for k in unicos.keys():
		lista.append(k)
	res.points = lista if lista.size() >= 4 else pts
	return res
