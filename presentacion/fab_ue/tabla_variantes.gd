class_name TablaVariantes
extends RefCounted
## TABLA DE VARIANTES DE VEGETACIÓN (26/11/2026). Para cada pieza del juego que Pablo eligió sustituir por el pack Pure Nature, sus
## variantes: rutas de arte/pure_nature/juego/pn_*.tscn (modelo del pack con material del juego) o "" (= la pieza original).
## Con varias, cada pieza que se coloca coge una al azar (alternan). Las elecciones: docs/fab_ue/candidatos_vegetacion.json.
## La usan VarianteVegetal (piezas de arte/piezas, puzles) y Pieza3D.crear_visual (maqueta).
## REGENERADA por herramientas/aplicar_candidatos_vegetacion.gd: no editar VARIANTES a mano (se cambia la elección y se vuelve a aplicar).

const VARIANTES: Dictionary = {
	"arbol_manglar": ["res://arte/pure_nature/juego/pn_jungle_kapokier1.tscn","res://arte/pure_nature/juego/pn_islands_pandanace1.tscn",""],
	"arbol_redondo": ["res://arte/pure_nature/juego/pn_meadows_oak1.tscn","res://arte/pure_nature/juego/pn_meadows_elm1.tscn","res://arte/pure_nature/juego/pn_asianvalley_osmanthus5.tscn",""],
	"arbol_redondo_2": ["res://arte/pure_nature/juego/pn_meadows_oak2.tscn","res://arte/pure_nature/juego/pn_fantasyforest_bigtree1.tscn"],
	"arbol_sumicio": ["res://arte/pure_nature/juego/pn_meadows_birch3.tscn","res://arte/pure_nature/juego/pn_mountains_pine4.tscn","res://arte/pure_nature/juego/pn_meadows_cypres2.tscn"],
	"arbol_viejo": ["res://arte/pure_nature/juego/pn_fantasyforest_bigtree3.tscn","res://arte/pure_nature/juego/pn_jungle_kapokier2.tscn",""],
	"arbusto": ["res://arte/pure_nature/juego/pn_meadows_bush1.tscn","res://arte/pure_nature/juego/pn_mountains_bush2.tscn","res://arte/pure_nature/juego/pn_fantasyforest_bush1.tscn"],
	"arbusto_bayas": ["res://arte/pure_nature/juego/pn_meadows_bush2.tscn","res://arte/pure_nature/juego/pn_fantasyforest_bush2.tscn"],
	"arbusto_flores": ["res://arte/pure_nature/juego/pn_meadows_bush3.tscn"],
	"arbusto_otono": ["res://arte/pure_nature/juego/pn_mountains_bush3.tscn"],
	"flor_heliconia": ["res://arte/pure_nature/juego/pn_jungle_heliconia2.tscn"],
	"flor_reactiva": ["res://arte/pure_nature/juego/pn_meadows_lupin2.tscn","res://arte/pure_nature/juego/pn_jungle_anthurium2.tscn",""],
	"flores_blancas": ["res://arte/pure_nature/juego/pn_meadows_daisy.tscn","res://arte/pure_nature/juego/pn_meadows_flowermeadow4.tscn",""],
	"flores_colores": ["res://arte/pure_nature/juego/pn_meadows_flowermeadow3.tscn","res://arte/pure_nature/juego/pn_asianvalley_astilb_2.tscn"],
	"helecho": ["res://arte/pure_nature/juego/pn_mountains_fern1.tscn",""],
	"helecho_ancho": ["res://arte/pure_nature/juego/pn_fantasyforest_largefern2.tscn","res://arte/pure_nature/juego/pn_jungle_bigfern1.tscn","res://arte/pure_nature/juego/pn_mountains_fern2.tscn",""],
	"helechos_cueva": ["res://arte/pure_nature/juego/pn_fantasyforest_largefern3.tscn","res://arte/pure_nature/juego/pn_jungle_asplenium2.tscn","res://arte/pure_nature/juego/pn_islands_ferneil1.tscn",""],
	"hierba_crecida": ["res://arte/pure_nature/juego/pn_meadows_grassmeadows3.tscn","res://arte/pure_nature/juego/pn_fantasyforest_grass2.tscn","res://arte/pure_nature/juego/pn_jungle_grass1.tscn"],
	"hierba_espesa": ["res://arte/pure_nature/juego/pn_mountains_grass3.tscn",""],
	"margarita_amarilla_suelo": ["res://arte/pure_nature/juego/pn_mountains_daisy.tscn"],
	"margarita_blanca_suelo": ["res://arte/pure_nature/juego/pn_meadows_daisy.tscn"],
	"musgo_suelo": ["res://arte/pure_nature/juego/pn_savanna_watermoss.tscn"],
	"nenufar_flor": ["res://arte/pure_nature/juego/pn_asianvalley_lotus_4.tscn","res://arte/pure_nature/juego/pn_savanna_lillypads1.tscn"],
	"planta_agua": ["res://arte/pure_nature/juego/pn_meadows_reeds.tscn","res://arte/pure_nature/juego/pn_savanna_watermoss.tscn","res://arte/pure_nature/juego/pn_jungle_thinfern1.tscn"],
	"planta_hojas": ["res://arte/pure_nature/juego/pn_jungle_elephant2.tscn","res://arte/pure_nature/juego/pn_jungle_philo2.tscn","res://arte/pure_nature/juego/pn_fantasyforest_shrubleaf2.tscn",""],
	"planta_violeta": ["res://arte/pure_nature/juego/pn_meadows_lavender.tscn","res://arte/pure_nature/juego/pn_meadows_lupin1.tscn","res://arte/pure_nature/juego/pn_mountains_lupin2.tscn"],
	"raices_obstaculo": ["res://arte/pure_nature/juego/pn_fantasyforest_bigroots_1.tscn"],
	"roca_grande": ["res://arte/pure_nature/juego/pn_savanna_bigboulders_0.tscn","res://arte/pure_nature/juego/pn_jungle_jungleboulder_3.tscn",""],
	"roca_musgosa": ["res://arte/pure_nature/juego/pn_meadows_stone4.tscn","res://arte/pure_nature/juego/pn_mountains_stone4.tscn",""],
	"rocas_pequenas": ["res://arte/pure_nature/juego/pn_mountains_boulder2.tscn",""],
	"seta_amarilla_alta": ["res://arte/pure_nature/juego/pn_meadows_mushroom1.tscn"],
	"seta_amarilla_fina": ["res://arte/pure_nature/juego/pn_fantasyforest_smallmushroom_3.tscn"],
	"seta_pradera": ["res://arte/pure_nature/juego/pn_meadows_mushroom3.tscn"],
	"seta_reactiva": ["res://arte/pure_nature/juego/pn_fantasyforest_bigmushroom_2_1.tscn",""],
	"setas_pantano": ["res://arte/pure_nature/juego/pn_fantasyforest_mushroomsstack_7.tscn",""],
}


## Tamaño de las PIEZAS NUEVAS (las que no existían en el juego y no están en Pieza3D.MEDIDA): {"alto": u} o {"planta": u}, medido de la
## pieza actual que Pablo dio como referencia («al tamaño de la actual»). REGENERADO por la misma herramienta.
const MEDIDAS: Dictionary = {
	"flor_heliconia": {"alto":0.9},
	"margarita_amarilla_suelo": {"planta":2.3},
	"margarita_blanca_suelo": {"planta":2.3},
	"musgo_suelo": {"planta":2.3},
	"raices_obstaculo": {"planta":4.6},
	"seta_amarilla_alta": {"alto":0.35},
	"seta_amarilla_fina": {"alto":0.35},
	"seta_pradera": {"alto":0.35},
}


## Una variante de `id` al azar; "" si no tiene, si toca la original o si el archivo no está en esta máquina (pack sin regenerar).
static func elegir(id: String) -> String:
	# para comparar antes/después en las capturas: con la variable de entorno MS_SIN_VARIANTES, todo con los modelos originales
	if OS.has_environment("MS_SIN_VARIANTES"):
		return ""
	var lista: Array = VARIANTES.get(id, [])
	if lista.is_empty():
		return ""
	var ruta: String = String(lista[randi() % lista.size()])
	if ruta == "" or not ResourceLoader.exists(ruta):
		return ""
	return ruta


## Las variantes de `id` tal cual se pueden usar en esta máquina ("" = la original; las que faltan cuentan como la original). [] si no tiene.
static func lista(id: String) -> Array:
	if OS.has_environment("MS_SIN_VARIANTES"):
		return []
	var res: Array = []
	for r in VARIANTES.get(id, []):
		res.append(String(r) if String(r) != "" and ResourceLoader.exists(String(r)) else "")
	return res


## La variante de `id` para una pieza en `pos`: siempre la misma para el mismo sitio (el mapa no cambia de una partida a otra).
static func elegir_en(id: String, pos: Vector3) -> String:
	var l: Array = lista(id)
	if l.is_empty():
		return ""
	return String(l[posmod(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0))), l.size())])


## 26/11 (Pablo: «algunos árboles tienen raíces, entiérralas»): los árboles y arbustos del pack traen las raíces y la base del tronco
## POR DEBAJO de su origen (en Unreal el origen es el suelo y eso queda enterrado: un 4-20 % del alto en los árboles, 13-31 % en los
## arbustos). Para las piezas que empiezan por uno de estos prefijos, la caja que cuenta es la de por encima del origen: se igualan por
## lo que se ve y lo de debajo queda bajo tierra. Las rocas NO (su origen está en el centro) ni raices_obstaculo (casi todo bajo el origen).
const ENTERRAR_BAJO_ORIGEN: Array = ["arbol", "arbusto"]


static func entierra(id: String) -> bool:
	for p in ENTERRAR_BAJO_ORIGEN:
		if id.begins_with(String(p)):
			return true
	return false


## La caja de la variante `n` de `id` que se iguala a la pieza original: la de todas sus mallas, o solo lo de encima del origen si `entierra(id)`.
static func caja_visible(id: String, n: Node3D) -> AABB:
	var c: AABB = caja(n)
	if entierra(id) and c.position.y < 0.0 and c.end.y > 0.0:
		c.size.y = c.end.y
		c.position.y = 0.0
	return c


## Caja de todas las mallas de `n` en el espacio de `n` (sin la transformación del propio `n`).
static func caja(n: Node3D) -> AABB:
	var res := AABB()
	var primera := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var x: Node = mi
		while x != null and x != n:
			if x is Node3D:
				t = (x as Node3D).transform * t
			x = x.get_parent()
		if (mi as MeshInstance3D).mesh == null:
			continue
		var c: AABB = t * (mi as MeshInstance3D).mesh.get_aabb()
		res = c if primera else res.merge(c)
		primera = false
	return res
