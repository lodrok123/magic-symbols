class_name TablaLostCave
extends RefCounted
## TABLAS del pack «Stylized Lost Cave» (StylArts, comprado en Cosmos de Leartes el 24/11/2026), integrado en arte/lostcave/piezas/lost_*.tscn.
## PABLO: lo que se cambia a mano vive AQUÍ (y solo aquí). Después de cambiar algo, regenerar con  tools\preparar_lostcave.cmd  (o solo el
## último paso:  godot --headless --path . --script res://herramientas/generar_piezas_lostcave.gd ).
##
## Diferencia con Provencal (arte/provencal/tabla_provencal.gd): aquí se CONSERVAN las texturas pintadas del pack (bajadas a 1K), no se pasan
## a color plano de la paleta. Los materiales salen como StandardMaterial3D, así que Ocluso3D los convierte igual que los de Meshy (rampa toon,
## transparencia alrededor de la jugadora, quemado).
## Licencia: Cosmos, licencia Individual. NADA de lo generado va a git (ver .gitignore y LEEME.md); solo esta tabla.

const ORIGEN: String = "Stylized Lost Cave (StylArts / Leartes Cosmos)"
const PREFIJO: String = "lost_"
const CARPETA: String = "res://arte/lostcave/"
const CARPETA_MALLAS: String = "res://arte/lostcave/mallas/"
const CARPETA_FUENTE: String = "res://arte/lostcave/_fuente/"          ## originales del zip (con .gdignore: Godot no los importa)
const CARPETA_TEXTURAS: String = "res://arte/lostcave/texturas/"
const CARPETA_MATERIALES: String = "res://arte/lostcave/materiales/"
const CARPETA_MALLAS_RES: String = "res://arte/lostcave/mallas_res/"   ## malla LOD0 guardada como recurso (con los LOD que genera Godot)
const CARPETA_PIEZAS: String = "res://arte/lostcave/piezas/"

## ESCALA: el pack está en metros. 0,68 es el factor del atrezo de Provencal (barril, carro, banco), para que las dos colecciones convivan:
## una vagoneta de 1,8 m sale de 1,2 u (la jugadora mide 1 u; casilla = 2,3 u). Por pieza se cambia en ESCALA_PIEZA.
const FACTOR: float = 0.68
## Por pieza: factor propio (sustituye a FACTOR). Vacío de momento.
const ESCALA_PIEZA: Dictionary = {}
## ORIENTACIÓN (cámara fija al norte, como Provencal): lo LARGO de la pieza va en X (horizontal en pantalla). Si la malla es más honda (Z) que
## ancha (X) por más de GIRO_AUTO_RAZON, se gira 90° sola: así los arcos, la bocamina y las paredes enseñan la cara y no el canto.
const GIRO_AUTO_RAZON: float = 1.15
## Giro en Y (grados) por pieza, que SUSTITUYE al automático, para cuando la cara buena no es la larga. Se decide con
##   godot --path . --script res://herramientas/captura_lostcave.gd -- giros lost_<pieza> ...
const GIRO: Dictionary = {}

## TEXTURAS: lado máximo al bajarlas (las del pack llegan a 4096). 1024 = lo pedido el 24/11.
const LADO_MAX: int = 1024
## Las tres piezas de agua del pack quedan FUERA: el agua del mundo (AguaRender3D: simulación, filtro turquesa, hielo, cascada EoW) es mejor
## y la regla es que el agua se vea igual en todo el juego. SM_Plane solo es el suelo del nivel de muestra.
const EXCLUIDAS: Array = ["SM_WaterPlane", "SM_Waterfall_Main", "SM_Waterfall_Top", "SM_WaterFall_Bottom_High", "SM_WaterFall_Bottom_Low",
	"SM_RiverSplineMesh_Splines_0", "SM_RiverSplineMesh_Splines_1", "SM_Plane"]

## CATEGORÍA por el principio del nombre (sin «SM_»). Lo que no encaja en ninguna es «vegetacion».
const CATEGORIAS: Dictionary = {
	"estructura": ["Arch", "LargeArch", "ShrineArch", "MineArch", "Entrance", "Tunnel", "LargeWall", "PortalBlocks", "FlatPlatform", "FlatStone",
		"StoneArray", "RockArray", "Stalagmite", "StoneColumn", "Stair", "TotemRock", "TotemStone", "Totem_", "Platform_a", "SmallPlatform"],
	"mina": ["StraightRail", "RoundRail", "U_Rail", "ForkedRail", "SideRail", "BrokenRail", "Trolley", "Cart", "SupportBeam", "BeamSupport",
		"SideSupport", "SidePanel", "WoodBeam", "WoodSupport", "WoodenPlank", "RoundBeam", "Ledder", "Rope", "Barrier", "StandingLantern", "Lantern",
		"BlastingMachine", "Dynamite", "Bomb", "ToolBox", "Toolshelf", "Axe", "Hammer", "Pickaxe", "Shovel"],
	"atrezo": ["Bag_", "Barrel", "Box", "BrokenBox", "BrokenParts", "Book_", "Bottle_", "Candle_", "Table", "Chair", "Bench"],
	"cristal": ["Crystal_", "Crysral_", "SingleCrystal", "SmallCrystals", "Hex_"],
}
## Materiales de Unity que arden (la pieza es `inflamable` si TODAS sus superficies lo son): madera, sacos, libros y follaje.
const MAT_INFLAMABLE: Array = ["M_SupportBeams", "M_WoodSupport", "M_Boxes", "M_Barrel", "M_Barrels", "M_Bags", "M_Books", "M_Table", "M_Tools",
	"M_Bark", "M_Atlas_1", "M_Atlas_2_TwoSided", "M_Atlas_3", "M_Atlas_4", "M_Trolleys"]
## Colisión: se usan los «ConvexHulls» del autor (varias piezas convexas por malla: un arco deja pasar por debajo). Las piezas más bajas
## que esto (raíles, matas) no llevan cuerpo y se pisan, como ColisionPieza.ALTO_MIN_SOLIDO.
const ALTO_MIN_SOLIDO: float = 0.45
## Piezas (principio del nombre sin «SM_») cuya colisión es la malla exacta (ConcavePolygonShape3D, solo en cuerpos estáticos): las que tienen un
## HUECO por el que se pasa (la envolvente del autor es una sola pieza convexa y lo taparía) y los suelos que se PISAN (losas, escaleras, plataformas).
## Ojo: en los mapas de letras se camina por casillas y `Puzle._bloquear_huella` solo bloquea con envolventes convexas, así que estas piezas NO
## cierran casillas: arcos y túneles se cruzan y sus patas hay que apoyarlas en casillas que ya estén cerradas. El resto (columnas, estalagmitas,
## tótems, paredes, cristales, atrezo...) lleva la envolvente del autor y bloquea sus casillas. (24/11: antes era toda la categoría «estructura»
## y las columnas se atravesaban en el nivel de prueba.)
const COLISION_EXACTA: Array = ["Arch", "LargeArch", "ShrineArch", "MineArch", "Entrance", "Tunnel", "PortalBlocks", "Platform_a", "SmallPlatform",
	"Stair", "FlatStone", "FlatPlatform"]
## De esas, las que tienen PATAS (24/11): además de la malla exacta llevan una forma convexa por pata (lo que la malla tiene por debajo de
## ALTO_PATA, agrupado por contacto) y la marca `huella_por_forma`, así `Puzle._bloquear_huella` cierra las casillas de las patas y deja libre el
## paso de debajo. Antes las patas se atravesaban andando.
const CON_PATAS: Array = ["Arch", "LargeArch", "ShrineArch", "MineArch", "Entrance", "Tunnel", "PortalBlocks"]
const ALTO_PATA: float = 0.9             ## u: lo que está por debajo de esto es «pata»
const CELDA_PATA: float = 0.35           ## u: rejilla con la que se agrupan los trozos de pata (más grande = se unen patas cercanas)
const PATA_MIN: int = 3                  ## celdas mínimas para que un trozo cuente como pata (quita piedrecitas sueltas)

## MATERIALES: cómo se traduce cada shader de Unity (Shader Graph de HDRP) a Godot.
##   pbr   color + normal + ORM (+ emisión) (+ recorte por opacidad, a doble cara)   -> StandardMaterial3D
##   roca  losa de roca en mosaico × máscara (R damero de variante, G curvatura, B oclusión), HORNEADA a una textura por material -> StandardMaterial3D
##   calca símbolos y grietas: se montan como nodo Decal (no como malla)
##   llama la llama de las velas: sin sombreado, aditiva
## Los de agua, nube, cielo y terreno no se traducen.
const TIPO_SHADER: Dictionary = {"S_Simple_Asset": "pbr", "S_Standard": "pbr", "S_Foliage": "pbr", "S_Rock_Tileble": "roca", "S_Decal": "calca", "S_Flame": "llama"}
## Las superficies del glTF se llaman «MI_X»: su receta es el «M_X» de Unity. Excepciones de nombre:
const MAT_ALIAS: Dictionary = {}
## Brillo: el «_BaseColor_Value» de Unity (0,73 en casi todo) multiplica el color. false = color de la textura tal cual.
const USAR_BRILLO_UNITY: bool = true
## Lote de revisión: albedos derivados SOLO en estas piezas, no en los atlas comunes.
const FOLLAJE_PIEZAS: Array[String] = ["SM_Bush", "SM_Fern_a", "SM_GreenTrees"]
const FOLLAJE_SATURACION: float = 0.62
const FOLLAJE_BRILLO: float = 0.90
## Umbral algo menor para conservar hojas finas en mipmaps. No cambia el alfa fuente.
const FOLLAJE_CORTE_ALFA: float = 0.40
## Emisión: multiplicador sobre la fuerza de Unity (cristales 4, faroles 3,9, setas 1). Bajar si deslumbra con el glow del juego.
const EMISION_ESCALA: float = 0.6
## LUZ PROPIA (24/11): las piezas que brillan llevan una OmniLight3D, porque en la cueva del juego (casi a oscuras, LuzZona3D «cueva») la emisión
## del material no alumbra nada alrededor. Por principio del nombre (sin «SM_»): [color, energía, alcance en u, altura como fracción del alto de la pieza].
## Sin sombra y sin brillo especular (como las luces de los braseros). Fuego en rojos y naranjas, nunca amarillo; cristales con el color de su elemento.
const LUCES: Dictionary = {
	"StandingLantern": [Color(1.0, 0.58, 0.28), 2.4, 7.5, 0.8],
	"Lantern": [Color(1.0, 0.58, 0.28), 1.5, 4.5, 0.6],
	"Candle_": [Color(1.0, 0.50, 0.22), 0.9, 2.6, 1.0],
	"Crystal_Blue": [Color(0.35, 0.80, 1.0), 1.8, 5.5, 0.6],
	"Crysral_Red": [Color(1.0, 0.36, 0.14), 1.8, 5.0, 0.6],
	"SingleCrystal_Blue": [Color(0.35, 0.80, 1.0), 0.9, 3.0, 0.6],
	"SingleCrystal_Red": [Color(1.0, 0.36, 0.14), 0.9, 3.0, 0.6],
	"SmallCrystals": [Color(0.40, 0.55, 1.0), 0.7, 2.5, 0.8],
	"Hex_": [Color(0.40, 0.70, 1.0), 1.0, 5.0, 0.9],
	"GlowingPlant": [Color(0.45, 0.85, 1.0), 0.7, 2.8, 0.9],
}
## Llama de las velas: color (rojos y naranjas, nunca amarillo: gusto de Pablo y FuegoToy) y energía.
const LLAMA_COLOR: Color = Color(1.0, 0.42, 0.12)
const LLAMA_ENERGIA: float = 2.0

## ROCA (horneado): veces que se repite la losa sobre la UV de la malla, oscuridad de la oclusión (B) y aclarado de bordes por curvatura (G).
const ROCA_REPETICION: Dictionary = {"M_RockTiles": 4.0, "M_Tunnel": 4.0, "M_Stalagmite_a": 3.0, "M_Stalagmite_b": 3.0, "M_StoneColumn_a": 3.0,
	"M_StoneColumn_b": 3.0, "M_RockArray_a": 3.0}
## Sin máscara genérica de otro atlas: mantener la losa y el normal propio.
const ROCA_SIN_MASCARA_ATLAS: Array[String] = ["M_Stalagmite_b"]
const ROCA_OCLUSION: float = 0.75        ## 0 = la oclusión no oscurece; 1 = las grietas se van a negro
const ROCA_CURVATURA: float = 0.12       ## cuánto aclaran los cantos (G de la máscara por encima de 0,5). Con 0,35 salían blanquecinos (24/11)
const ROCA_BRILLO: float = 0.8           ## multiplica la losa: con 1 la roca salía más clara y rosada que las losas pintadas del pack (24/11)
## Tinte de la roca: el «_BC_Tint» de Unity si existe; si no, blanco.

## CALCAS: tamaño del cuadrado proyectado (u) y profundidad de proyección. El Decal mira a -Z: se apoya en una pared que tenga detrás.
const CALCA_LADO: float = 1.6
const CALCA_FONDO: float = 3.0           ## alcance de la proyección hacia atrás (u): la calca se pone en la casilla de delante de la roca y llega a ella
const CALCA_FUNDIDO_NORMAL: float = 0.6  ## no pinta lo que mira de lado a la proyección (el suelo): 0 = lo pinta todo
## Altura del centro de la calca sobre la base de la pieza (u): así, puesta en el suelo como `decorado`, queda en la pared a la altura de la jugadora.
const CALCA_ALTO: float = 1.2

## MARCA del autor pintada en dos texturas: se tapa copiando encima un trozo vecino de la misma textura.
## [x0, y0, x1, y1] en fracciones de la imagen (0-1) y el desplazamiento [dx, dy] del trozo que se copia encima.
const TAPAR_MARCA: Dictionary = {
	"T_BlastingMachine_BC": [[0.765, 0.640, 0.925, 0.720], [0.0, 0.10]],     ## placa «StylArts» del detonador: se copia el panel de madera de debajo
	"T_Bobm_Dynamite_BC": [[0.600, 0.550, 0.730, 0.880], [-0.125, 0.0]],     ## letras verticales en la banda roja de la caja: se copia la banda de la izquierda
}


## Erratas de los nombres originales que no se arrastran al id.
const ERRATAS: Dictionary = {"crysral": "crystal"}


static func id_de(pieza: String) -> String:
	var id: String = pieza.trim_prefix("SM_").to_lower()
	for e in ERRATAS:
		id = id.replace(String(e), String(ERRATAS[e]))
	return PREFIJO + id


static func categoria_de(pieza: String) -> String:
	var corto: String = pieza.trim_prefix("SM_")
	for cat in CATEGORIAS:
		for pre in CATEGORIAS[cat]:
			if corto.begins_with(String(pre)):
				return String(cat)
	return "vegetacion"


## [color, energía, alcance, fracción de alto] de la luz propia de la pieza, o [] si no lleva.
static func luz_de(pieza: String) -> Array:
	var corto: String = pieza.trim_prefix("SM_")
	for pre in LUCES:
		if corto.begins_with(String(pre)):
			return LUCES[pre]
	return []


static func con_patas(pieza: String) -> bool:
	var corto: String = pieza.trim_prefix("SM_")
	for pre in CON_PATAS:
		if corto.begins_with(String(pre)):
			return true
	return false


static func colision_exacta(pieza: String) -> bool:
	var corto: String = pieza.trim_prefix("SM_")
	for pre in COLISION_EXACTA:
		if corto.begins_with(String(pre)):
			return true
	return false


static func material_unity(superficie: String) -> String:
	if MAT_ALIAS.has(superficie):
		return String(MAT_ALIAS[superficie])
	if superficie.begins_with("MI_"):
		return "M_" + superficie.substr(3)
	return superficie
