extends SceneTree
## PRUEBA DE LA TABLA DE DECORADO POR BIOMA (26/11/2026, presentacion/tabla_decorado_bioma.gd):
##   1. SIN el pack (`con_pack = false`) la tabla da EXACTAMENTE las listas y repartos de antes (así los niveles hechos a mano no cambian): árboles de la masa,
##      árbol de borde, arbusto de la masa, decorado de los claros y flores de borde.
##   2. Una fila de peso 0 no sale nunca (voto de Pablo) y una sola fila sale siempre.
##   3. Toda pieza `pn_…` de la tabla existe en el índice del pack, tiene su versión del juego (material del juego, no el del pack) y mide lo que pide su fila
##      (alto o planta, ±3 %), con la base en y = 0.
##   4. Los árboles de la masa y del borde miden entre 3,4 y 5,4 u (los de siempre, 3,8-4,6): ni gigantes ni enanos; nada de palmeras, bambú, sabana ni piezas asiáticas
##      en el bosque (ids `asianvalley`, `savanna`, `islands`, `jungle` fuera de los papeles del bosque).
##   godot --headless --path . --script res://herramientas/prueba_tabla_decorado.gd

const TABLA = preload("res://presentacion/tabla_decorado_bioma.gd")
const PN: String = "res://arte/pure_nature/"
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	# 1. equivalencia con lo de antes (sin pack)
	var viejo_arboles: Array = [["pino", 5], ["arbol_viejo", 4], ["sauce", 2]]
	var igual: bool = true
	for k in range(0, 400):
		var total: int = 11
		var n: int = k % total
		var esperado: String = "pino"
		for a in viejo_arboles:
			n -= int(a[1])
			if n < 0:
				esperado = String(a[0])
				break
		if TABLA.elegir("bosque", "arbol_masa", k, false) != esperado:
			igual = false
	_ok("1 árboles de la masa sin pack = ARBOLES_MURO de antes", igual)
	var viejo_decor: Array = ["arbusto", "arbusto_flores", "piedras", "setas", "setas", "arbusto", "piedras"]
	igual = true
	for k in range(0, 400):
		if TABLA.elegir("bosque", "decor_claro", k, false) != String(viejo_decor[k % 7]):
			igual = false
	_ok("1 decorado de claro sin pack = la lista `decor` de antes (7 en el mismo orden)", igual)
	var viejo_borde: Array = ["flores_amarillas", "flores_colores", "helecho_ancho", "margarita_amarilla_suelo", "margarita_blanca_suelo", "flor_heliconia", "musgo_suelo"]
	igual = true
	for k in range(0, 400):
		if TABLA.elegir("bosque", "adorno_borde", k, false) != String(viejo_borde[k % 7]):
			igual = false
	_ok("1 flores de borde sin pack = `ADORNOS.borde_ids` de antes", igual)
	var solo_arbusto: bool = true
	for k in range(0, 400):
		if TABLA.elegir("bosque", "masa_menor", k * 6, false) != "arbusto":
			solo_arbusto = false
	_ok("1 arbusto de la masa sin pack = siempre «arbusto» (como antes: `h % 6 == 0` implica par)", solo_arbusto)
	_ok("1 árbol de borde sin pack = siempre «pino»", TABLA.elegir("bosque", "arbol_borde", 12345, false) == "pino" and TABLA.elegir("bosque", "arbol_borde", 7, false) == "pino")
	_ok("1 las ruinas heredan del bosque lo que no definen", TABLA.filas("ruinas", "arbol_masa", false).size() == 3 and TABLA.filas("ruinas", "ruina", true).size() > TABLA.filas("bosque", "ruina", true).size())
	var sin_pack_limpio: bool = true
	for est in TABLA.TABLA:
		for papel in (TABLA.TABLA[est] as Dictionary):
			for f in TABLA.filas(String(est), String(papel), false):
				if TABLA.ruta_de(String(f[0])) != "":
					sin_pack_limpio = false
	_ok("1 con `con_pack = false` no sale ninguna pieza de otro pack", sin_pack_limpio)
	# 2. peso 0
	var vetada_sale: bool = false
	for k in range(0, 3000):
		var id: String = TABLA.elegir("bosque", "arbol_masa", k, true)
		if id.contains("birch"):
			vetada_sale = true
	_ok("2 una fila de peso 0 (los abedules amarillos) no sale nunca", not vetada_sale)
	_ok("2 una sola fila sale siempre", TABLA.elegir_de([["x", 3]], 17) == "x" and TABLA.elegir_de([], 3) == "")
	# 3. las piezas del pack
	var indice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PN + "indice.json"))
	var ids: Array = TABLA.ids_pack()
	var sin_indice: Array = []
	var sin_juego: Array = []
	var mal_medida: Array = []
	var material_pack: Array = []
	for id in ids:
		if not indice.has(id):
			sin_indice.append(id)
		var ruta: String = TABLA.ruta_pack(String(id))
		if not ResourceLoader.exists(ruta):
			sin_juego.append(id)
			continue
		var v: Node3D = Pieza3D.visual_decorado(String(id))
		if v == null:
			sin_juego.append(id)
			continue
		var caja: AABB = Pieza3D._caja(v, Transform3D.IDENTITY)
		var medida: Dictionary = TABLA.medida_de(String(id))
		var real: float = caja.size.y if medida.has("alto") else maxf(caja.size.x, caja.size.z)
		var pedido: float = float(medida.get("alto", medida.get("planta", 1.0)))
		# los árboles y arbustos entierran lo de debajo del origen: miden lo pedido por encima del suelo
		var sobre_suelo: float = caja.end.y if TABLA.entierra(String(id)) else caja.size.y
		if medida.has("alto"):
			real = sobre_suelo if TABLA.entierra(String(id)) else real
		if absf(real - pedido) > pedido * 0.03 or caja.position.y < -0.001 and not TABLA.entierra(String(id)):
			mal_medida.append("%s pide %.2f mide %.2f" % [id, pedido, real])
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			for s in range((mi as MeshInstance3D).mesh.get_surface_count()):
				var m: Material = (mi as MeshInstance3D).get_active_material(s)
				if m is ShaderMaterial and not (m as ShaderMaterial).resource_path.begins_with("res://arte/pure_nature/juego"):
					if (m as ShaderMaterial).shader != null and String((m as ShaderMaterial).shader.resource_path).contains("pure_nature"):
						material_pack.append(id)
		v.free()
	_ok("3 las %d piezas del pack de la tabla existen en el índice" % ids.size(), sin_indice.is_empty(), str(sin_indice.slice(0, 6)))
	_ok("3 y tienen su versión del juego (herramientas/generar_decorado_bioma.gd)", sin_juego.is_empty(), str(sin_juego.slice(0, 6)))
	_ok("3 y miden lo que pide su fila (±3 %)", mal_medida.is_empty(), str(mal_medida.slice(0, 6)))
	_ok("3 y ninguna lleva el shader del pack (material del juego)", material_pack.is_empty(), str(material_pack.slice(0, 4)))
	# 4. tamaños de árbol y nada exótico
	var fuera: Array = []
	for est in ["bosque", "pantano"]:
		for papel in ["arbol_masa", "arbol_borde"]:
			for f in (TABLA.TABLA[est][papel] as Array):
				if (f as Array).size() >= 4 and (float(f[3]) < 3.4 or float(f[3]) > 5.4):
					fuera.append("%s/%s %s %.1f" % [est, papel, f[0], float(f[3])])
	_ok("4 los árboles de las masas miden entre 3,4 y 5,4 u", fuera.is_empty(), str(fuera))
	var exoticas: Array = []
	for papel in (TABLA.TABLA["bosque"] as Dictionary):
		for f in (TABLA.TABLA["bosque"][papel] as Array):
			var id: String = String(f[0])
			if int(f[1]) > 0 and (id.contains("asianvalley") or id.contains("savanna") or id.contains("islands") or id.contains("jungle") or id.contains("palm") or id.contains("bamboo")):
				exoticas.append(id)
	_ok("4 el bosque no lleva piezas de sabana, selva, islas ni asiáticas (con peso > 0)", exoticas.is_empty(), str(exoticas))
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
