class_name TablaProvencal
extends RefCounted
## TABLAS del pack Fantasy Provencal (Leartes Studios) integrado en arte/piezas/prov_*.tscn. PABLO: lo que se cambia a mano vive AQUI (y solo aqui):
##   · COLORES  — color plano por familia de material (sin texturas del pack: decision del dueño, cohesion con Paleta3D).
##   · FAMILIA_DE() — que familia lleva cada material de Unity (`usemtl` del OBJ).
##   · PIEZAS   — por pieza: categoria/LOD/triangulos del catalogo, escala (`esc`), giro y si lleva colision. Una linea de «por que» por grupo.
## Despues de cambiar algo, regenerar las escenas (las escenas llevan el color y la escala HORNEADOS, como las demas piezas de arte/piezas):
##   godot --headless --path . --script res://herramientas/generar_piezas_provencal.gd
## Los OBJ estan en arte/provencal/obj/<pieza_original>.obj (el LOD elegido del catalogo). Id de la escena: «prov_» + nombre en minusculas sin «SM_».
## `esc`: ["alto", u] alto final · ["ancho", u] lado horizontal mayor · ["largo", u] igual, y gira la pieza para que el largo vaya en X (horizontal en pantalla)
##       · ["factor", f] factor directo sobre las unidades de Unity (metros). `giro`: grados en Y despues. Casilla = 2,3 u; la jugadora mide 1 u.
## `detalle`: ver DETALLE/RECORTE (por material de Unity, no por pieza): el alfa del detalle recorta la forma de la hoja; el color sigue siendo el de COLORES.
##       Esas piezas llevan StandardMaterial3D ALPHA_SCISSOR (0,5) a doble cara y Ocluso3D.convertir las convierte conservando el umbral (uniform `recorte` del shader comun).
## `aspas`: pieza compuesta (molino): {obj, pos (en el espacio del OBJ, antes de escalar), mats}; se monta como nodo hijo `modelo/aspas` con la misma escala. El prefab de Unity no trae posicion (identidad): `pos` es aproximada.
## ORIENTACION (camara fija al norte, 4/11): frente hacia +Z (lo que ve la camara) y lo largo a lo largo de X. `giro` (multiplos de 90) lo decide mirando cada pieza desde esa camara; las que lo llevan tienen su motivo al final de la linea.
## `fam`: (opcional) familia de color para las superficies de follaje de esa pieza (los matorrales: «arbusto» en vez de «hoja»).
## `col`: colision convexa sencilla (si la pieza mide <= 0,45 u de alto se pisa: sin cuerpo y bloquea=false, como ColisionPieza.ALTO_MIN_SOLIDO).
## Piezas con varias superficies en el OBJ (casa, santuario...) llevan un color por `usemtl`; las de UNA sola superficie (todo el atrezo, rocas, arbol, puente)
## llevan el color de su primer material de Unity (`mats`): el OBJ no distingue ahi, p. ej. las hojas y el tronco del cipres salen del mismo color.

const ORIGEN: String = "Fantasy Provencal (Leartes Studios)"
const CARPETA_OBJ: String = "res://arte/provencal/obj/"
const CARPETA_PIEZAS: String = "res://arte/piezas/"

const COLORES: Dictionary = {
	"madera": Paleta3D.MADERA,                 # Wood*, WoodenMeshes, Barrel, Cart, Crates, WaterMill, Atlas (puertas, vallas, puente), TunnelProps
	"piedra": Color(0.445, 0.445, 0.405),      # Rock*, RocksBricks, RocksWall, RockCliffs. Gris piedra calido (R=G, azul algo menor, luminosidad 0,44 como la media de roca_est_0..4 = 0.514/0.421/0.382, que tiraba a rosado); Paleta3D.PIEDRA (B8ADB8) salia lavanda
	"teja": Paleta3D.TIERRA_FLANCO,            # RoofTile* y la maceta (arcilla naranja)
	"yeso": Color("D9CDB4"),                   # HouseWalls / Plaster (el crema de la prueba) y las aspas del molino
	"hoja": Color(0.30, 0.52, 0.24),           # follaje de arbol (Flora2/Flora3): oscuro y saturado; con HIERBA salia pálido contra el suelo (mismo tono)
	"arbusto": Color(0.33, 0.56, 0.27),        # Flora2_doublesided, Flora_o (oscurecido: con HIERBA_SOMBRA se fundia con el suelo)
	"hierba": Color(0.42, 0.65, 0.26),         # Grass*, Test_Grass (mas oscura y saturada que el suelo, para que se lea)
	"enredadera": Color(0.30, 0.50, 0.26),     # M_Flora a secas (enredaderas): verde oscuro (con 78A86A se veian palidas sobre el suelo)
	"flor": Color("F2C84B"),                   # M_FloraFlower*: un unico acento calido (la paleta cerrada no trae color de flor)
	"cristal": Color(0.34, 0.48, 0.60),        # Windows: azul-gris medio (con A8D8E8 el vidrio y los parteluces se perdian en un parche celeste liso)
	"decal": Paleta3D.PIEDRA_OSCURA,           # HouseDecal*: detalles de pared (manchas, grietas)
	"cera": Color("F2E8C9"),                   # ShrineCandle
}
const SIN_CULL: Array = ["hoja", "arbusto", "hierba", "enredadera", "flor"]    ## vegetacion de planos: se ve por las dos caras

const DOBLE_CARA: Array = ["SM_Door", "SM_Wooden_Arch_Tunnel"]    ## piezas de planos finos que se veian solo por una cara (la puerta salia hueca): se dibujan por las dos
const _DOBLE_FOLLAJE: String = "M_Flora2_doublesided"


## Familia de color de un material de Unity (nombre del `usemtl`). Lo que no se reconoce cae en «madera».
static func familia_de(mat: String) -> String:
	if mat.begins_with("M_RoofTile") or mat == "M_Flower_Pot":
		return "teja"
	if mat.begins_with("M_Rock"):
		return "piedra"
	if mat.begins_with("M_HouseWalls") or mat == "M_WindMill_Palms":
		return "yeso"
	if mat.begins_with("M_Windows"):
		return "cristal"
	if mat.begins_with("M_HouseDecal"):
		return "decal"
	if mat.begins_with("M_FloraFlower"):
		return "flor"
	if mat == _DOBLE_FOLLAJE or mat == "M_Flora_o":
		return "arbusto"
	if mat == "M_Flora":
		return "enredadera"
	if mat.begins_with("M_Flora2") or mat.begins_with("M_Flora3"):
		return "hoja"
	if mat.begins_with("M_Grass") or mat == "M_Test_Grass":
		return "hierba"
	if mat == "M_ShrineCandle":
		return "cera"
	return "madera"


const ID_ESPECIAL: Dictionary = {"SM_WindMill_SM_WindMill": "prov_windmill"}    ## nombre propio (el original repite «WindMill»)
const CARPETA_DETALLE: String = "res://arte/provencal/detalle/"
const BRILLO_DETALLE: float = 1.25     ## el detalle se guarda como d/1,25 (cabe en 8 bits); el color de la paleta se multiplica por esto para que el tono medio no cambie

## DETALLE EN GRIS: por material de Unity, su albedo _B pasado a gris y normalizado (media = 1, d = 1 + 0,6·(L − media)/media recortado a [0,4 ; 1,25]) y su normal _N aplanada al 50 %.
## El COLOR sigue siendo el de COLORES; el detalle solo le pone la veta, las losas y las tejas. Los PNG salen de las texturas del pack con la herramienta de un solo uso
## `herramientas/` (ver DIARIO): K = 0,6. Material -> [albedo, normal ("" = sin normales)].
const DETALLE: Dictionary = {
	"M_Atlas": ["T_Atlas_House_B", "T_Atlas_House_N"], "M_BarrelJars": ["T_Barrel_Jar_B", "T_Barrel_Jar_N"], "M_Cart": ["T_Cart_B", "T_Cart_N"], "M_Crates": ["T_Crates_B", "T_Crates_N"],
	"M_Flora": ["T_Flora_Atlas_01_B", ""], "M_Flora_o": ["T_Flora_Atlas_01_B", ""], "M_FloraFlower": ["T_Flora_Atlas_01_B", ""], "M_FloraFlower02": ["T_Flora_Atlas_01_B", ""],
	"M_Grass_a": ["T_Flora_Atlas_01_B", ""], "M_Grass_b": ["T_Flora_Atlas_01_B", ""], "M_Test_Grass": ["T_Flora_Atlas_01_B", ""],
	"M_Flora2": ["T_Flora_Atlas_02_B", ""], "M_Flora2_doublesided": ["T_Flora_Atlas_02_B", ""], "M_Flora3": ["T_Flora_Atlas_02_B", ""], "M_Flora4": ["T_Flora_Atlas_02_B", ""],
	"M_Flower_Pot": ["T_Flower_Pot_B", "T_Flower_Pot_N"], "M_HouseDecal": ["T_Decals_B", "T_Decals_N"], "M_HouseDecalNormal": ["T_Decals_B", "T_Decals_N"],
	"M_HouseWallsVertex": ["T_Plaster_B", "T_Plaster_N"], "M_RockCliffs": ["T_Rocks_Cliff_B", "T_Rocks_Cliff_N"], "M_Rocks": ["T_Rocks_B", "T_Rocks_N"],
	"M_RocksBricks01": ["T_Rocks_Bricks_B", "T_Rocks_Bricks_N"], "M_RocksBricks02": ["T_Rocks_Bricks_B", "T_Rocks_Bricks_N"], "M_RocksBricks2": ["T_Rocks_Bricks_B", "T_Rocks_Bricks_N"],
	"M_RocksWall": ["T_Rock_Walls_B", "T_Rock_Walls_N"],
	"M_RoofTileVertexPaint": ["T_RoofTiles_01_B", "T_RoofTiles_Normal"], "M_RoofTile_Meshes_VertexPaint": ["T_RoofTileMeshes_01_B", "T_RoofTileMeshes_N"],
	"M_ShrineCandle": ["T_Shrine_Candle_B", "T_Shrine_Candle_N"], "M_TunnelProps": ["T_TunnelProps_B", "T_TunnelProps_N"], "M_WaterMill_Wheel": ["T_WaterMill_Wheel_B", "T_WaterMill_Wheel_N"],
	"M_WindMill_Palms": ["T_WindMill_B", "T_WindMill_N"], "M_Windows": ["T_Windows_B", "T_Windows_N"], "M_WoodTrunk": ["T_WoodTrunk_B", "T_WoodTrunk_N"], "M_WoodenMeshes": ["T_WoodenMeshes_B", "T_WoodenMeshes_N"],
}
## Los detalles con canal alfa (hojas, aspas, calcomanias): su alfa recorta (alpha scissor 0,5, doble cara) y no llevan normales.
const RECORTE: Array = ["T_Flora_Atlas_01_B", "T_Flora_Atlas_02_B", "T_Decals_B", "T_WindMill_B"]
## Materiales de piezas cuyo dibujo no corresponde (atlas equivocado): solo color, sin detalle. (se rellena mirando la hoja de contacto)
const SIN_DETALLE: Array = []


static func id_de(pieza: String) -> String:
	if ID_ESPECIAL.has(pieza):
		return ID_ESPECIAL[pieza]
	return "prov_" + pieza.trim_prefix("SM_").to_lower()


const PIEZAS: Dictionary = {	# familia del barril: el factor de SM_Barrel (alto 0,8 u como `barril`)
	"SM_Barrel": {"cat": "atrezo", "lod": 0, "tris": 1382, "mats": "M_BarrelJars", "esc": ["factor", 0.6820], "giro": 0, "col": true},
	"SM_Barrel_Open": {"cat": "atrezo", "lod": 0, "tris": 896, "mats": "M_BarrelJars", "esc": ["factor", 0.6820], "giro": 0, "col": true},
	# jarrones: alto 0,85 u (decision del dueño; `jarron` 0,6 / `jarron_alto` 0,95)
	"SM_Jar_01": {"cat": "atrezo", "lod": 0, "tris": 912, "mats": "M_BarrelJars", "esc": ["alto", 0.8500], "giro": 0, "col": true},
	"SM_Jar_02": {"cat": "atrezo", "lod": 0, "tris": 916, "mats": "M_BarrelJars", "esc": ["alto", 0.8500], "giro": 0, "col": true},
	# familia de la caja: el factor de SM_Crate_01 (alto 0,8 u como `caja`)
	"SM_Crate_01": {"cat": "atrezo", "lod": 0, "tris": 447, "mats": "M_Crates", "esc": ["factor", 0.6130], "giro": 0, "col": true},
	"SM_Crate_02": {"cat": "atrezo", "lod": 0, "tris": 198, "mats": "M_Crates", "esc": ["factor", 0.6130], "giro": 0, "col": true},
	"SM_Crate_03": {"cat": "atrezo", "lod": 0, "tris": 204, "mats": "M_Crates", "esc": ["factor", 0.6130], "giro": 90, "col": true},   # giro 90: caja baja: lado largo hacia la camara
	# atrezo sin equivalente en arte/piezas: el factor del barril y la caja (~0,65), para que viva a su escala
	"SM_Bench": {"cat": "atrezo", "lod": 0, "tris": 196, "mats": "M_Cart", "esc": ["factor", 0.6800], "giro": 90, "col": true},   # giro 90: banco: largo a lo largo de X (cruzando la pantalla)
	"SM_Stool": {"cat": "atrezo", "lod": 0, "tris": 134, "mats": "M_Cart", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	"SM_Cart": {"cat": "atrezo", "lod": 0, "tris": 4578, "mats": "M_Cart", "esc": ["factor", 0.6800], "giro": 90, "col": true},   # giro 90: carro: largo a lo largo de X, de lado a la camara (rueda y caja a la vista)
	"SM_Shrine_Candle": {"cat": "atrezo", "lod": 0, "tris": 3364, "mats": "M_ShrineCandle", "esc": ["factor", 0.5402], "giro": 0, "col": true},
	# puente: LARGO de la malla a 2,5 casillas, girado para que el largo vaya en horizontal en pantalla; sin colision (se pisa)
	"SM_Bridge": {"cat": "madera_y_paso", "lod": 0, "tris": 5520, "mats": "M_Atlas", "esc": ["largo", 5.7500], "giro": 0, "col": false},
	# rueda: diametro 1 casilla; girada 90 grados en Y para que la camara vea la cara
	"SM_WaterMill_Wheel": {"cat": "madera_y_paso", "lod": 0, "tris": 1814, "mats": "M_WaterMill_Wheel", "esc": ["alto", 2.3000], "giro": 90, "col": true},
	# puerta: el factor de los edificios (0,458, el de SM_House_Barn)
	"SM_Door": {"cat": "madera_y_paso", "lod": 0, "tris": 1224, "mats": "M_Atlas", "esc": ["factor", 0.4580], "giro": 180, "col": true},   # giro 180: puerta: la cara con herrajes (la reconocible) a la camara
	# vallas: largo de una casilla
	"SM_Fence_01": {"cat": "madera_y_paso", "lod": 0, "tris": 3556, "mats": "M_Atlas", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	"SM_Fence_02": {"cat": "madera_y_paso", "lod": 0, "tris": 1952, "mats": "M_Atlas", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	# vigas: su eje mas largo (vertical) a una casilla: quedan como postes de 2,3 u
	"SM_WoodenBeam_01": {"cat": "madera_y_paso", "lod": 0, "tris": 44, "mats": "M_WoodenMeshes", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	"SM_WoodenBeam_02": {"cat": "madera_y_paso", "lod": 0, "tris": 28, "mats": "M_WoodenMeshes", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	"SM_WoodenBeam_03": {"cat": "madera_y_paso", "lod": 0, "tris": 12, "mats": "M_WoodenMeshes", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	"SM_WoodenBeam_04": {"cat": "madera_y_paso", "lod": 0, "tris": 12, "mats": "M_WoodenMeshes", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	"SM_WoodenBeam_05": {"cat": "madera_y_paso", "lod": 0, "tris": 52, "mats": "M_WoodenMeshes", "esc": ["largo", 2.3000], "giro": 0, "col": true},
	# tablones: largo 0,6 casillas
	"SM_WoodenPlank_01": {"cat": "madera_y_paso", "lod": 0, "tris": 24, "mats": "M_WoodenMeshes", "esc": ["largo", 1.3800], "giro": 0, "col": true},
	"SM_WoodenPlank_02": {"cat": "madera_y_paso", "lod": 0, "tris": 44, "mats": "M_WoodenMeshes", "esc": ["largo", 1.3800], "giro": 0, "col": true},
	"SM_WoodenPlank_03": {"cat": "madera_y_paso", "lod": 0, "tris": 36, "mats": "M_WoodenMeshes", "esc": ["largo", 1.3800], "giro": 0, "col": true},
	# arbusto grande: alto 1,0 u como `arbusto`
	"SM_Bush_01": {"cat": "vegetacion", "lod": 0, "tris": 1584, "mats": "M_Flora2_doublesided", "esc": ["alto", 1.0000], "fam": "arbusto", "giro": 0, "col": true},
	# matas pequeñas: alto 0,5 u, sin colision
	"SM_Bush_02": {"cat": "vegetacion", "lod": 0, "tris": 48, "mats": "M_Flora2_doublesided", "esc": ["alto", 0.5000], "fam": "arbusto", "giro": 0, "col": false},
	"SM_Bush_03": {"cat": "vegetacion", "lod": 0, "tris": 62, "mats": "M_Flora2_doublesided", "esc": ["alto", 0.5000], "fam": "arbusto", "giro": 0, "col": false},
	# arbusto con flores: alto 0,9 u como `arbusto_bayas`
	"SM_Bush_04": {"cat": "vegetacion", "lod": 0, "tris": 4470, "mats": "M_FloraFlower", "esc": ["alto", 0.9000], "fam": "arbusto", "giro": 0, "col": true},
	# flores: alto 0,4 u (como `flores_amarillas`), sin colision
	"SM_Flower_01_c": {"cat": "vegetacion", "lod": 0, "tris": 266, "mats": "M_FloraFlower", "esc": ["alto", 0.4000], "giro": 0, "col": false},
	"SM_Flower_02_c": {"cat": "vegetacion", "lod": 0, "tris": 38, "mats": "M_FloraFlower", "esc": ["alto", 0.4000], "giro": 0, "col": false},
	"SM_Flower_03_a": {"cat": "vegetacion", "lod": 0, "tris": 122, "mats": "M_FloraFlower", "esc": ["alto", 0.4000], "giro": 0, "col": false},
	# maceta: alto 0,45 u
	"SM_Flower_Pot": {"cat": "vegetacion", "lod": 0, "tris": 244, "mats": "M_Flower_Pot", "esc": ["alto", 0.4500], "giro": 0, "col": true},
	# hierba pequeña: alto 0,25 u, sin colision
	"SM_Grass_Small_01_a": {"cat": "vegetacion", "lod": 0, "tris": 24, "mats": "M_Grass_a", "esc": ["alto", 0.2500], "giro": 0, "col": false},
	"SM_Grass_Small_02_b": {"cat": "vegetacion", "lod": 0, "tris": 24, "mats": "M_Grass_b", "esc": ["alto", 0.2500], "giro": 0, "col": false},
	# campo de hierba: alto 0,45 u (`hierba_alta` 0,53), sin colision
	"SM_GrassField_01_b": {"cat": "vegetacion", "lod": 0, "tris": 162, "mats": "M_Grass_a", "esc": ["alto", 0.4500], "giro": 0, "col": false},
	"SM_GrassField_02_a": {"cat": "vegetacion", "lod": 0, "tris": 202, "mats": "M_Grass_a", "esc": ["alto", 0.4500], "giro": 0, "col": false},
	"SM_GrassField_02_b": {"cat": "vegetacion", "lod": 0, "tris": 202, "mats": "M_Grass_b", "esc": ["alto", 0.4500], "giro": 0, "col": false},
	# enredaderas: tamaño natural a 0,68 (el del atrezo); los grupos 02 y 04 (colgaban 4-6 u) a alto 2,4 u; sin colision
	"SM_Vine_01": {"cat": "vegetacion", "lod": 0, "tris": 252, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vine_01_b": {"cat": "vegetacion", "lod": 0, "tris": 276, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vine_02": {"cat": "vegetacion", "lod": 0, "tris": 30, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vine_03": {"cat": "vegetacion", "lod": 0, "tris": 92, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vine_05": {"cat": "vegetacion", "lod": 0, "tris": 16, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vine_06": {"cat": "vegetacion", "lod": 0, "tris": 24, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vines_Group_01": {"cat": "vegetacion", "lod": 0, "tris": 244, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vines_Group_01_b": {"cat": "vegetacion", "lod": 0, "tris": 256, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vines_Group_02": {"cat": "vegetacion", "lod": 0, "tris": 1120, "mats": "M_Flora", "esc": ["alto", 2.4000], "giro": 0, "col": false},
	"SM_Vines_Group_02_b": {"cat": "vegetacion", "lod": 0, "tris": 1144, "mats": "M_Flora", "esc": ["alto", 2.4000], "giro": 0, "col": false},
	"SM_Vines_Group_03": {"cat": "vegetacion", "lod": 0, "tris": 1412, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vines_Group_03_b": {"cat": "vegetacion", "lod": 0, "tris": 1442, "mats": "M_Flora", "esc": ["factor", 0.6800], "giro": 0, "col": false},
	"SM_Vines_Group_04": {"cat": "vegetacion", "lod": 0, "tris": 786, "mats": "M_Flora", "esc": ["alto", 2.4000], "giro": 0, "col": false},
	"SM_Vines_Group_04_b": {"cat": "vegetacion", "lod": 0, "tris": 804, "mats": "M_Flora", "esc": ["alto", 2.4000], "giro": 0, "col": false},
	# cipres: alto 3,8 u (entre `sauce` 3,8 y `arbol_redondo` 4,2)
	"SM_Tree_Cypress": {"cat": "vegetacion", "lod": 0, "tris": 4210, "mats": "M_Flora2", "esc": ["alto", 3.8000], "giro": 0, "col": true},
	# roca grande: alto 1,4 u como `roca_grande`
	"SM_Rock_Large_01": {"cat": "roca", "lod": 0, "tris": 3052, "mats": "M_Rocks", "esc": ["alto", 1.4000], "giro": 0, "col": true},
	"SM_Rock_Large_02": {"cat": "roca", "lod": 0, "tris": 2026, "mats": "M_Rocks", "esc": ["alto", 1.4000], "giro": 0, "col": true},
	# acantilados: ancho de una casilla
	"SM_Rock_Cliff_01": {"cat": "roca", "lod": 0, "tris": 1526, "mats": "M_RockCliffs", "esc": ["ancho", 2.3000], "giro": 0, "col": true},
	"SM_Rock_Cliff_02": {"cat": "roca", "lod": 0, "tris": 1376, "mats": "M_RockCliffs", "esc": ["ancho", 2.3000], "giro": 0, "col": true},
	"SM_Rock_Cliff_03": {"cat": "roca", "lod": 0, "tris": 1886, "mats": "M_RockCliffs", "esc": ["ancho", 2.3000], "giro": 0, "col": true},
	"SM_Rock_Cliff_04": {"cat": "roca", "lod": 0, "tris": 1428, "mats": "M_RockCliffs", "esc": ["ancho", 2.3000], "giro": 0, "col": true},
	# rocas pequeñas: alto 0,33 u como `rocas_pequenas` (por debajo de 0,45 se pisan: sin cuerpo)
	"SM_Rock_Small_01": {"cat": "roca", "lod": 0, "tris": 208, "mats": "M_Rocks", "esc": ["alto", 0.3300], "giro": 0, "col": true},
	"SM_Rock_Small_02": {"cat": "roca", "lod": 0, "tris": 432, "mats": "M_Rocks", "esc": ["alto", 0.3300], "giro": 0, "col": true},
	"SM_Rock_Small_03": {"cat": "roca", "lod": 0, "tris": 118, "mats": "M_Rocks", "esc": ["alto", 0.3300], "giro": 0, "col": true},
	# muros de roca: ancho de una casilla
	"SM_Rock_Wall_01": {"cat": "roca", "lod": 0, "tris": 994, "mats": "M_RocksWall", "esc": ["ancho", 2.3000], "giro": 90, "col": true},   # giro 90: muro de roca: se veia de canto; el largo pasa a X
	"SM_Rock_Wall_02": {"cat": "roca", "lod": 0, "tris": 986, "mats": "M_RocksWall", "esc": ["ancho", 2.3000], "giro": 90, "col": true},   # giro 90: muro de roca: se veia de canto; el largo pasa a X
	# ladrillos sueltos: factor del atrezo (0,68); bajos, sin cuerpo
	"SM_RockBrick_Medium_01": {"cat": "roca", "lod": 0, "tris": 84, "mats": "M_RocksBricks02", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	"SM_RockBrick_Medium_02": {"cat": "roca", "lod": 0, "tris": 72, "mats": "M_RocksBricks02", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	"SM_RockBrick_Small_01": {"cat": "roca", "lod": 0, "tris": 24, "mats": "M_RocksBricks02", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	"SM_RockBrick_Small_02": {"cat": "roca", "lod": 0, "tris": 42, "mats": "M_RocksBricks01", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	"SM_RockBrick_Small_03": {"cat": "roca", "lod": 0, "tris": 20, "mats": "M_RocksBricks02", "esc": ["factor", 0.6800], "giro": 0, "col": true},
	# casa-granero: ancho 2,4 casillas (factor 0,458, el de la prueba)
	"SM_House_Barn": {"cat": "edificio", "lod": 0, "tris": 5876, "mats": "M_RoofTile_Meshes_VertexPaint", "esc": ["ancho", 5.5200], "giro": 90, "col": true},   # giro 90: granero: el lado largo abierto (los postes) a la camara, largo en X
	# santuario: alto 4,2 u (~1,8 casillas), decision del dueño
	"SM_Shrine": {"cat": "edificio", "lod": 0, "tris": 3800, "mats": "M_WoodenMeshes", "esc": ["alto", 4.2000], "giro": 0, "col": true},
	# edificios: el factor de SM_House_Barn (0,458). Excepciones de tamaño: SM_House_Tower 0,3674 (3 casillas de alto) y el molino 0,3048 (4 casillas de alto con las aspas). Excepcion: SM_Shrine_Candle con el factor del santuario (0,54). El molino lleva las aspas (`aspas`) dentro de prov_windmill: el OBJ SM_WindMill_Palms se monta en `pos` (OBJ, antes de escalar: eje del cubo del tejado) con el mismo factor
	"SM_House_02": {"cat": "edificio", "lod": 0, "tris": 11869, "mats": "M_WoodenMeshes", "esc": ["factor", 0.4580], "giro": 90, "col": true},   # giro 90: casa: fachada con puerta y ventanas a la camara, larga en X
	"SM_House_01": {"cat": "edificio", "lod": 3, "tris": 9595, "mats": "M_HouseWallsVertex", "esc": ["ancho", 8.0500], "giro": 90, "col": true},   # nuevo (7/11): edificio grande, factor de los demas (0,458); giro 90: fachada larga (con el arco / la torre) hacia la camara
	"SM_House_Passage": {"cat": "edificio", "lod": 2, "tris": 7838, "mats": "M_HouseWallsVertex", "esc": ["ancho", 9.2000], "giro": 90, "col": true},   # nuevo (7/11): edificio grande, factor de los demas (0,458); giro 90: fachada larga (con el arco / la torre) hacia la camara
	"SM_House_Tower": {"cat": "edificio", "lod": 1, "tris": 8134, "mats": "M_HouseWallsVertex", "esc": ["alto", 6.9000], "giro": 0, "col": true},
	"SM_WaterMill_House": {"cat": "edificio", "lod": 1, "tris": 11502, "mats": "M_WoodenMeshes", "esc": ["ancho", 8.4400], "giro": 270, "col": true},   # giro 270: casa del molino: fachada larga con puerta y ventanas a la camara
	"SM_WindMill_SM_WindMill": {"cat": "edificio", "lod": 1, "tris": 11803, "mats": "M_HouseDecal", "esc": ["alto", 6.9900], "giro": 0, "col": true, "aspas": {"obj": "SM_WindMill_Palms", "lod": 1, "pos": Vector3(0.0, 16.0, -3.6), "mats": "M_WindMill_Palms"}},
	"SM_Wooden_Arch_Tunnel": {"cat": "edificio", "lod": 0, "tris": 88, "mats": "M_TunnelProps", "esc": ["factor", 0.4580], "giro": 90, "col": true},
}
