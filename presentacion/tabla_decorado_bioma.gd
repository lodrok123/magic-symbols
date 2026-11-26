extends RefCounted
## TABLA DE DECORADO POR ESTILO/BIOMA (26/11/2026). Dice, para cada PAPEL del decorado de un nivel (el árbol de la masa `#`, el arbusto de la
## masa, las matas de hierba corta, las flores…), qué piezas valen y con qué PESO. La maqueta (`presentacion/prueba_test2.gd`) ya no lleva esas
## listas escritas en el código: las lee de aquí. Meter o quitar un asset = tocar UNA FILA.
##
## FORMATO DE UNA FILA:  [id, peso]                         una pieza del JUEGO (arte/piezas, biblioteca…) o del pack Stylescape («ss_…»).
##                       [id, peso, "alto", u]              una pieza del pack Pure Nature («pn_…»), escalada para que mida `u` de ALTO.
##                       [id, peso, "planta", u]            ídem, escalada para que su lado mayor en planta mida `u` (piezas planas: flores, musgo).
##   · PESO entero ≥ 0: cuántas veces más sale que una de peso 1. **Peso 0 = vetada** (la fila se queda, pero no sale nunca).
##   · Una pieza «pn_…» necesita su versión del juego (arte/pure_nature/juego/pn_*.tscn, con el MATERIAL DEL JUEGO: se queman, mojan y reaccionan).
##     La crea `herramientas/generar_decorado_bioma.gd` a partir de ESTA tabla (corre una vez; ver arte/pure_nature/LEEME.md). Si la pieza no
##     existe en esta máquina (pack sin generar), su fila se salta sola: el nivel queda como antes de la tabla.
##   · El ORDEN de las filas importa solo en las listas que ya existían con filas repetidas (el reparto `h % n` de antes se conserva).
##   · Escala: el 1,0 del juego es la chibi (~1 u); una casilla son 2,3 u. Los árboles de la masa miden 3,6-5,2 u; las matas del suelo, de 0,25 a
##     0,9 u (con la cámara fija, lo más pequeño no se ve y lo más alto tapa).
##
## PAPELES (clave de cada bioma):
##   arbol_masa    árbol de cada casilla `#` que no toca suelo (el fondo del muro de árboles; bloquea su casilla).
##   arbol_borde   árbol de la `#` que SÍ toca suelo: tronco CENTRADO y estrecho (los de tronco descentrado invaden el paso).
##   masa_menor    arbusto o roca que sustituye a 1 de cada 6 árboles de la masa (da ritmo al muro).
##   decor_claro   decorado suelto en los claros `.` (1 de cada 9 casillas); no bloquea.
##   adorno_borde  flores y matas bajas en el borde de los corros de hierba (tabla ADORNOS de la maqueta); no bloquean.
##   roca          rocas pequeñas sueltas por los claros (capa de riqueza); no bloquean.
##   tronco        troncos, raíces y ramas caídas por los claros (capa de riqueza); no bloquean.
##   hierba_corta  matas de hierba corta sobre el suelo de hierba (capa de riqueza, `riqueza_suelo_3d.gd`); sin colisión.
##   flor          flores pequeñas en corros o manchas (capa de riqueza); sin colisión.
##   ruina         restos de ruina sueltos (pack Stylescape) que salen de vez en cuando en los claros del BOSQUE o por todo el suelo de las RUINAS.
## Un estilo que no define un papel HEREDA el de `HEREDA` (las ruinas son bosque con muros finos). La cueva no usa la tabla (su decorado es de roca).

const PN: String = "res://arte/pure_nature/juego/"
const SS: String = "res://arte/stylescape/piezas/"
const LC: String = "res://arte/lostcave/piezas/"

## Estilo -> estilo del que hereda los papeles que no define.
const HEREDA: Dictionary = {"ruinas": "bosque"}

const TABLA: Dictionary = {
	# ------------------------------------------------------------------------------------------------------------------------------------
	# BOSQUE gallego-atlántico: roble, olmo, abedul, pino, tojo, helechos, brezo, musgo. NADA de palmeras, bambú, sabana ni piezas asiáticas.
	# ------------------------------------------------------------------------------------------------------------------------------------
	"bosque": {
		# Las tres primeras filas son las de siempre (`ARBOLES_MURO`: pino 5 · árbol viejo 4 · sauce 2). Las del pack se suman con el interruptor `decorado_bioma`.
		"arbol_masa": [
			["pino", 5], ["arbol_viejo", 4], ["sauce", 2],
			["pn_meadows_oak2", 1, "alto", 4.0], ["pn_meadows_oak3", 2, "alto", 4.4], ["pn_meadows_oak4", 1, "alto", 4.8], ["pn_meadows_oak5", 1, "alto", 4.8],
			["pn_meadows_elm2", 1, "alto", 4.2], ["pn_meadows_elm3", 1, "alto", 4.4], ["pn_meadows_elm5", 1, "alto", 4.8],
			# los abedules del pack llevan las hojas AMARILLAS (otoño): saltan como manchas naranjas en un bosque verde. Peso 0 = vetados; súbelo a 1 para probarlos.
			["pn_meadows_birch4", 0, "alto", 4.2], ["pn_meadows_birch5", 0, "alto", 4.4], ["pn_meadows_birch3", 0, "alto", 3.8],
			["pn_mountains_pine4", 1, "alto", 4.2], ["pn_mountains_pine5", 2, "alto", 4.6], ["pn_mountains_pine6", 1, "alto", 5.0],
			["pn_mountains_fir5", 1, "alto", 4.8], ["pn_mountains_spruce4", 1, "alto", 4.4],
			["pn_fantasyforest_bigtree1", 1, "alto", 4.6], ["pn_fantasyforest_bigtree4", 1, "alto", 4.6], ["pn_fantasyforest_bigtree2", 0, "alto", 4.6],
		],
		# Solo árboles de tronco centrado y estrecho (el pino de siempre + coníferas y abedules).
		"arbol_borde": [
			["pino", 5],
			["pn_mountains_pine3", 2, "alto", 3.8], ["pn_mountains_pine4", 2, "alto", 4.2], ["pn_mountains_pine5", 2, "alto", 4.4],
			["pn_mountains_fir4", 1, "alto", 4.0], ["pn_meadows_birch3", 0, "alto", 3.8], ["pn_meadows_birch4", 0, "alto", 4.2],
		],
		# La casilla `#` de cada 6 que lleva arbusto o roca en vez de árbol (de siempre: arbusto y roca grande, a partes iguales).
		"masa_menor": [
			# `roca_grande` NO sale en la masa (de siempre salía solo el arbusto: `h % 6 == 0` implica `h % 2 == 0`) y sus variantes de Pablo incluyen la roca naranja de
			# la sabana, que en el bosque salta a la vista: peso 0. Con ese 0, sin `decorado_bioma` sale exactamente lo de antes (siempre «arbusto»).
			["arbusto", 1], ["roca_grande", 0],
			# (los arbustos del pack ya salen por `arbusto`: TablaVariantes los alterna con los de siempre; aquí solo rocas nuevas)
			["pn_fantasyforest_mossyrock_5", 1, "alto", 0.75], ["pn_meadows_stone5", 1, "alto", 0.8], ["pn_mountains_stone5", 1, "alto", 0.8],
		],
		# Los siete de siempre, uno por casilla en el reparto `h % 7` (las filas repetidas son a propósito: son el reparto de antes).
		"decor_claro": [
			["arbusto", 1], ["arbusto_flores", 1], ["piedras", 1], ["setas", 1], ["setas", 1], ["arbusto", 1], ["piedras", 1],
			["pn_fantasyforest_mossyrock_3", 1, "planta", 0.6], ["pn_fantasyforest_mossyrock_4", 1, "planta", 0.7], ["pn_meadows_stone3", 1, "planta", 0.55],
			["pn_mountains_fern2", 1, "alto", 0.5], ["pn_fantasyforest_largefern2", 1, "alto", 0.55],
			# el tojo del pack son palos secos pardo-amarillos sobre el suelo lima: vetado
			["pn_meadows_gorse1", 0, "alto", 0.75], ["pn_meadows_gorse2", 0, "alto", 0.85],
		],
		# Los siete de siempre (`ADORNOS["borde_ids"]`) + flores del pack (las que se leen a la cámara del juego).
		"adorno_borde": [
			["flores_amarillas", 1], ["flores_colores", 1], ["helecho_ancho", 1], ["margarita_amarilla_suelo", 1], ["margarita_blanca_suelo", 1],
			["flor_heliconia", 1], ["musgo_suelo", 1],
			["pn_meadows_lavender", 1, "alto", 0.7], ["pn_meadows_lupin2", 1, "alto", 0.7], ["pn_meadows_commonblue", 1, "planta", 1.3],
			["pn_meadows_sorrel", 0, "planta", 0.7], ["pn_meadows_gorse1", 0, "alto", 0.6], ["pn_fantasyforest_shrub2", 0, "alto", 0.4],
		],
		# Rocas pequeñas sueltas (gris liso; con la cámara del juego miden menos de un paso de la chibi).
		"roca": [
			["pn_fantasyforest_mossyrock_1", 3, "planta", 0.4], ["pn_fantasyforest_mossyrock_2", 3, "planta", 0.4], ["pn_fantasyforest_mossyrock_3", 2, "planta", 0.55],
			["pn_meadows_stone1", 2, "planta", 0.35], ["pn_meadows_stone2", 2, "planta", 0.45], ["pn_mountains_boulder2", 1, "planta", 0.5],
			["pn_mountains_pebble2", 0, "planta", 0.5], ["pn_mountains_stone3", 1, "planta", 0.5],
		],
		# Raíces secas y hojarasca. Las ramas del pack son hilos casi transparentes (no se ven con la cámara del juego): vetadas.
		"tronco": [
			["pn_fantasyforest_smallroot1", 2, "planta", 0.9], ["pn_fantasyforest_smallroot2", 2, "planta", 0.9],
			["pn_fantasyforest_branches", 0, "planta", 0.9], ["pn_mountains_branchs", 0, "planta", 0.9],
			["pn_fantasyforest_deadleaves2", 1, "planta", 0.55], ["pn_fantasyforest_deadleaves3", 1, "planta", 0.55],
		],
		# Hierba corta y matas bajas: el campo del bosque (hierba de prado, de monte y de bosque), musgo y trébol. Alto 0,3-0,5 u: se ve y no tapa.
		"hierba_corta": [
			# (1 y 4 son matas de tallos negro-verdosos que destacan demasiado sobre el suelo lima: vetadas; 2 y 3, lila-grisáceas y con plumeros, sí)
			["pn_meadows_grassmeadows1", 0, "alto", 0.70], ["pn_meadows_grassmeadows2", 3, "alto", 0.70], ["pn_meadows_grassmeadows3", 3, "alto", 0.75],
			["pn_meadows_grassmeadows4", 0, "alto", 0.70], ["pn_mountains_grassmountain1", 0, "alto", 0.70], ["pn_mountains_grassmountain2", 0, "alto", 0.70],
			["pn_mountains_grassmountain3", 0, "alto", 0.70], ["pn_mountains_grassmountain4", 0, "alto", 0.65],
			# helechos pequeños (verde oliva, se leen bien)
			["helecho", 1], ["helecho_ancho", 1], ["pn_mountains_fern1", 1, "alto", 0.5],
			# hierbas finas del pack (briznas negro-azuladas sobre el suelo lima: no casan con los colores del mundo): vetadas; pruébalas con peso 1
			["pn_meadows_grass2", 0, "planta", 0.55], ["pn_meadows_grass3", 0, "planta", 0.6], ["pn_mountains_grass2", 0, "planta", 0.7],
			["pn_fantasyforest_grass2", 0, "planta", 0.7], ["pn_fantasyforest_grass3", 0, "planta", 0.8],
			["pn_fantasyforest_grassmoss", 0, "planta", 0.75],
			["hierba_espesa", 1], ["musgo_suelo", 2],      # (`musgo_suelo` es ya el musgo del pack que eligió Pablo: no se repite aquí)
			["lost_clover_cluster", 2],
		],
		"flor": [
			# mantos de florecillas (puntitos de color sobre el suelo): se miden en planta, grandes para que se lean con la cámara del juego
			["pn_meadows_daisy", 2, "planta", 1.3], ["pn_mountains_daisy", 1, "planta", 1.3], ["pn_mountains_daisyblue", 1, "planta", 1.3],
			["pn_meadows_commonblue", 2, "planta", 1.3], ["pn_meadows_commonpink", 2, "planta", 1.3], ["pn_meadows_commonyellow", 0, "planta", 1.3],      # (esta, tallos negros: vetada)
			["pn_meadows_flowermeadow1", 1, "alto", 0.7], ["pn_meadows_flowermeadow2", 1, "alto", 0.7], ["pn_meadows_flowermeadow3", 1, "alto", 0.7],
			["pn_meadows_flowermeadow4", 1, "alto", 0.7], ["pn_meadows_lavender", 1, "alto", 0.7], ["pn_meadows_sorrel", 0, "planta", 0.7],
			["flores_blancas", 2], ["flores_amarillas", 3], ["flores_colores", 3],
		],
		# Un resto de ruina suelto que enlaza con el bioma «ruinas» (Stylescape; ya están a escala del juego).
		"ruina": [
			["ss_stone_01", 3], ["ss_stone_02", 3], ["ss_stone_03", 3], ["ss_rubble_01", 2], ["ss_rubble_02", 2], ["ss_edge_stones_01", 1],
		],
	},
	# ------------------------------------------------------------------------------------------------------------------------------------
	# PANTANO: manglar, sauce, helechos de humedal, juncos, nenúfares, setas. Lo que encaja de jungle/savanna húmeda.
	# ------------------------------------------------------------------------------------------------------------------------------------
	"pantano": {
		# `arbol_manglar` es el de siempre (la pieza lleva ya sus variantes de TablaVariantes).
		"arbol_masa": [
			["arbol_manglar", 6],
			["pn_jungle_kapokier1", 1, "alto", 3.6], ["pn_jungle_kapokier2", 1, "alto", 3.8], ["pn_islands_pandanace1", 1, "alto", 3.4],
			["pn_islands_pandanace2", 1, "alto", 3.4], ["pn_fantasyforest_bigtree2", 1, "alto", 4.0],
		],
		"arbol_borde": [
			["arbol_manglar", 6],
		],
		"masa_menor": [
			["arbusto", 1], ["roca_grande", 1],
			["pn_jungle_rattle3", 1, "alto", 0.9], ["pn_jungle_elephant4", 1, "alto", 0.9], ["pn_jungle_jungleboulder_3", 1, "alto", 1.0],
		],
		"decor_claro": [
			["arbusto", 1], ["arbusto_flores", 1], ["piedras", 1], ["setas", 1], ["setas", 1], ["arbusto", 1], ["piedras", 1],
			["pn_jungle_thinfern4", 1, "alto", 0.5], ["pn_jungle_bigfern1", 1, "alto", 0.55], ["pn_jungle_asplenium2", 1, "alto", 0.5],
			["pn_jungle_philo2", 1, "alto", 0.55], ["pn_savanna_wetgrass1", 1, "alto", 0.5],
		],
		"adorno_borde": [
			["flores_amarillas", 1], ["flores_colores", 1], ["helecho_ancho", 1], ["margarita_amarilla_suelo", 1], ["margarita_blanca_suelo", 1],
			["flor_heliconia", 1], ["musgo_suelo", 1],
			["pn_jungle_heliconia2", 1, "alto", 0.7], ["pn_jungle_anthurium2", 1, "alto", 0.45], ["pn_savanna_ulmaria1", 1, "alto", 0.5],
		],
		"roca": [
			["pn_jungle_jungleboulder_1", 2, "planta", 0.6], ["pn_jungle_jungleboulder_2", 2, "planta", 0.8], ["pn_fantasyforest_mossyrock_2", 2, "planta", 0.55],
		],
		"tronco": [
			["pn_jungle_branches", 2, "planta", 0.9], ["pn_fantasyforest_smallroot1", 2, "planta", 0.9], ["pn_fantasyforest_smallroot2", 2, "planta", 0.9],
		],
		"hierba_corta": [
			["pn_savanna_wetgrass1", 3, "alto", 0.45], ["pn_savanna_wetgrass2", 3, "alto", 0.5], ["pn_jungle_grass1", 2, "planta", 0.7], ["pn_jungle_grass2", 2, "planta", 0.8],
			["pn_fantasyforest_grassmoss", 3, "planta", 0.75], ["pn_savanna_watermoss", 2, "planta", 1.5],
			["pn_jungle_thinfern2", 1, "alto", 0.4], ["pn_jungle_asplenium1", 1, "alto", 0.4],
		],
		"flor": [
			["pn_savanna_ulmaria2", 2, "alto", 0.45], ["pn_jungle_anthurium1", 1, "alto", 0.35], ["pn_jungle_heliconia1", 1, "alto", 0.5],
			["pn_meadows_daisy", 1, "planta", 0.5],
		],
		"ruina": [],
	},
	# ------------------------------------------------------------------------------------------------------------------------------------
	# RUINAS: bosque con muros finos de Stylescape. Hereda del bosque todo lo de abajo salvo `ruina` (aquí, mucha más variedad del pack).
	# ------------------------------------------------------------------------------------------------------------------------------------
	"ruinas": {
		# Restos sueltos por el suelo (no bloquean; cada pieza ya está a escala del juego). Pilares rotos, escombros, barandillas caídas, bordes de piedra…
		"ruina": [
			["ss_stone_01", 3], ["ss_stone_02", 3], ["ss_stone_03", 3], ["ss_rubble_01", 3], ["ss_rubble_02", 3],
			# pilares: miden 1,8 u de alto y no bloquean (se atraviesan): vetados; súbelos si quieres columnas de adorno
			["ss_pillar_01_dmg", 0], ["ss_pillar_02", 0], ["ss_pillar_03", 0], ["ss_pillar_05", 0],
			["ss_railing_01_02", 1], ["ss_railing_02_03", 1], ["ss_railing_pillar_01", 1],
			["ss_edge_stones_01", 2], ["ss_edge_stones_02", 1], ["ss_edge_stones_03", 1],
			["ss_wall_dmg_03_half_01", 1], ["ss_wall_dmg_04_half_02", 1], ["ss_wall_dmg_01_half_01", 1],
			["ss_crate_01", 1],
		],
		# (La hiedra colgante de los muros no va aquí: la pone `PAREDES_SS._adornos_tramo` con las medidas de cada hiedra; el estilo ya la usa.)
	},
}

## ¿Es una pieza del pack Pure Nature? (se escala con la medida de su fila y su escena está en arte/pure_nature/juego/).
static func es_pack(id: String) -> bool:
	return id.begins_with("pn_")


static func ruta_pack(id: String) -> String:
	return PN + id + ".tscn"


## Piezas de un pack que NO están en las bibliotecas del juego: `pn_…` (Pure Nature, con el material del juego) y `lost_…` (Lost Cave, ya a su medida).
## Las pone `Pieza3D.visual_decorado`. (Las `ss_…` de Stylescape se instancian aparte, con `_poner_escena`.)
static func es_externa(id: String) -> bool:
	return id.begins_with("pn_") or id.begins_with("lost_")


## La escena de una pieza externa o de Stylescape; "" si el id es del propio juego.
static func ruta_de(id: String) -> String:
	if id.begins_with("pn_"):
		return PN + id + ".tscn"
	if id.begins_with("lost_"):
		return LC + id + ".tscn"
	if id.begins_with("ss_"):
		return SS + id + ".tscn"
	return ""


## Los árboles y arbustos del pack traen las raíces y la base del tronco POR DEBAJO de su origen: para igualarlos cuenta lo de encima (ver TablaVariantes).
static func entierra(id: String) -> bool:
	if not es_pack(id):
		return false
	for k in ["_bush", "_oak", "_elm", "_birch", "_pine", "_fir", "_spruce", "_bigtree", "_kapokier", "_pandanace", "_gorse"]:
		if id.contains(k):
			return true
	return false


## Árbol de la tabla cuya copa se tiñe como la de un árbol del juego (`VERDES_COPA` de la maqueta): el verde de siempre del bosque. "" si no es árbol.
static func copa_como(id: String) -> String:
	if not es_pack(id):
		return ""
	if id.contains("_oak") or id.contains("_elm") or id.contains("_birch") or id.contains("_kapokier") or id.contains("_pandanace"):
		return "arbol_redondo"
	if id.contains("_pine") or id.contains("_fir") or id.contains("_spruce"):
		return "pino"
	if id.contains("_bigtree"):
		return "arbol_viejo"
	return ""


## Las filas de un papel de un estilo: las del estilo si las define; si no, las del que hereda. Sin filas de peso 0 y sin las del pack que no estén
## generadas en esta máquina. `con_pack = false` deja SOLO las piezas del juego (las listas de antes de la tabla: los niveles hechos a mano).
static func filas(estilo: String, papel: String, con_pack: bool = true) -> Array:
	var est: String = estilo
	while est != "" and not (TABLA.get(est, {}) as Dictionary).has(papel):
		est = String(HEREDA.get(est, ""))
	if est == "":
		return []
	var res: Array = []
	for f in (TABLA[est][papel] as Array):
		var id: String = String(f[0])
		if int(f[1]) <= 0:
			continue
		var ruta: String = ruta_de(id)
		if ruta != "":
			# piezas de otro pack: solo con `con_pack` y si están generadas en esta máquina (los restos `ss_…` también; sin el pack, la fila se salta)
			if not con_pack or not ResourceLoader.exists(ruta):
				continue
		res.append(f)
	return res


## Elige una fila con el entero `k` (un hash o `rng.randi()`): `k % suma_de_pesos`, recorriendo las filas en orden. "" si no hay filas.
static func elegir(estilo: String, papel: String, k: int, con_pack: bool = true) -> String:
	var lista: Array = filas(estilo, papel, con_pack)
	return elegir_de(lista, k)


static func elegir_de(lista: Array, k: int) -> String:
	var total: int = 0
	for f in lista:
		total += int(f[1])
	if total <= 0:
		return ""
	var n: int = posmod(k, total)
	for f in lista:
		n -= int(f[1])
		if n < 0:
			return String(f[0])
	return String(lista[lista.size() - 1][0])


## Índice id -> medida ({"alto": u} o {"planta": u}) de todas las piezas del pack de la tabla. Se construye una vez.
static var _medidas: Dictionary = {}


static func medida_de(id: String) -> Dictionary:
	if _medidas.is_empty():
		for est in TABLA:
			for papel in (TABLA[est] as Dictionary):
				for f in (TABLA[est][papel] as Array):
					if (f as Array).size() >= 4 and not _medidas.has(String(f[0])):
						_medidas[String(f[0])] = {String(f[2]): float(f[3])}
	return _medidas.get(id, {})


## Todos los ids del pack que aparecen en la tabla, con cualquier peso (también los vetados: así, si Pablo sube un peso, la pieza ya está hecha).
static func ids_pack() -> Array:
	var vistos: Dictionary = {}
	for est in TABLA:
		for papel in (TABLA[est] as Dictionary):
			for f in (TABLA[est][papel] as Array):
				if es_pack(String(f[0])):
					vistos[String(f[0])] = true
	var res: Array = vistos.keys()
	res.sort()
	return res
