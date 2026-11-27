extends RefCounted
## SALA MUESTRARIO DE PIEZAS (27/11/2026). Pablo: «el nivel de prueba tiene que enseñar TODAS las piezas del bioma a escala del juego, con su id en un rótulo legible, para decir
## "esta sí / esta no" por id». La pieza de mapa `; pieza <id> muestrario <x> <y> pack=ss|lc|kit grupo=<grupo> ancho=<casillas> alto=<casillas>` (escenas/puzle.gd) reparte las piezas
## del pack en FILAS dentro del rectángulo de casillas que empieza en (x, y): una fila por categoría, cada pieza con su id escrito delante (un `Label3D` que siempre mira a la cámara).
## No es un laboratorio nuevo: es una pieza más del mapa, así que sirve en cualquier nivel generado (las plantillas `muestrario_*` del catálogo la llevan, con `; solo_mano si`).
## Esta clase solo CALCULA la distribución (`plan`); puzle.gd instancia las piezas con su `_colocar_pieza_arte` (el mismo camino que `decorado`, con la transparencia de la jugadora).
##
## PACKS Y GRUPOS (los ids de cada grupo salen de las tablas de abajo; las de `ss` y `lc` las generó una vez un script a partir de `docs/fab_ue/inventario_piezas.tsv` y de la
## `metadata/categoria` de cada pieza lost_*; el `kit` es una lista a mano de las piezas propias de la cueva (Tripo/Meshy) que hay en arte/piezas):
##   ss    Stylescape: Ruins (199 piezas ss_*, sin la franja de sombra). Grupos: «muros» (muros, arcos, puertas, cornisas…) · «resto» (suelos, escaleras, pilares, vigas, barandas, hiedra, escombros)
##   lc    Stylized Lost Cave (207 piezas lost_*). Grupos: «roca» (estructura: arcos, columnas, muros enormes) · «mina» (raíles, vagonetas, entibado, herramientas) · «vida» (vegetación, atrezo, cristales y calcas)
##   kit   el kit propio de la cueva. Grupo: «todo»
## Sin `grupo` (o «todo») salen todas las del pack. Una pieza que no existe en esta máquina (pack sin generar) se salta y se cuenta en `faltan`.

const S: float = 2.3                     ## casilla (u)
const HUECO: float = 0.55                ## u entre piezas de una fila
const FONDO_ROTULO: float = 1.15         ## u que se reservan delante de cada fila para el rótulo
const ALTO_FILA_EXTRA: float = 0.55      ## u de aire extra por cada unidad de alto de la pieza más alta de la fila (la cámara mira desde el sur y lo alto tapa lo de detrás)
const ALTO_FILA_TOPE: float = 2.2        ## … con un tope
const ANCHO_RETULO_CAR: float = 0.105    ## u de ancho por carácter del rótulo (Label3D font_size 24, pixel_size 0.0075: lo medido en pantalla)
const CAJA_DEFECTO: AABB = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 0.6, 1.2))     ## piezas sin malla (las calcas): un cuadro de 1,2 u
const RUTAS: Dictionary = {"ss": "res://arte/stylescape/piezas/", "lc": "res://arte/lostcave/piezas/", "kit": "res://arte/piezas/"}
const GRUPOS_SS: Dictionary = {
	"muros": ["muro", "muro_arco", "muro_grueso", "muro_danado", "muro_bajo", "muro_ventana", "arco", "puerta_ventana", "cornisa"],
	"resto": ["suelo", "techo_suelo", "escalera", "pilar", "viga", "baranda", "escombro", "hiedra", "caja"],
}
const GRUPOS_LC: Dictionary = {
	"roca": ["estructura"],
	"mina": ["mina"],
	"vida": ["calca", "vegetacion", "atrezo", "cristal"],
}

const CATS_SS: Dictionary = {
	"arco": ["ss_arch_01"],
	"caja": ["ss_crate_01"],
	"puerta_ventana": ["ss_doorframe_01", "ss_wall_door_01", "ss_wall_door_thick_01", "ss_windowframe_01", "ss_wooddoor_double", "ss_wooddoor_single"],
	"escombro": ["ss_edge_stones_01", "ss_edge_stones_01_half_01", "ss_edge_stones_01_half_02", "ss_edge_stones_02", "ss_edge_stones_03", "ss_rubble_01", "ss_rubble_02", "ss_stone_01", "ss_stone_02", "ss_stone_03"],
	"suelo": ["ss_floor_2x2_01_topface", "ss_floor_2x2_02_topface", "ss_floor_2x2_03_topface", "ss_floor_3x2_01", "ss_floor_3x2_02", "ss_floor_4x2_01", "ss_floor_4x2_02", "ss_floor_4x2_03", "ss_floor_4x4_01", "ss_floor_4x4_01_alt", "ss_floor_4x4_01_dmg", "ss_floor_4x4_02", "ss_floor_4x4_03", "ss_floor_4x4_03_alt", "ss_floor_4x4_03_dmg", "ss_floor_4x4_topface_01", "ss_floor_4x4_topface_02", "ss_floor_4x4_topface_03", "ss_floor_6x4_01", "ss_floor_6x4_01_alt", "ss_floor_6x4_02", "ss_floor_6x4_03", "ss_floor_6x4_03_alt", "ss_floor_6x4_03_dmg", "ss_floor_6x4_topface_01", "ss_floor_6x4_topface_02", "ss_floor_6x4_topface_03", "ss_wood_floor_2x1", "ss_wood_floor_2x2"],
	"techo_suelo": ["ss_floor_ceiling_01_1x1", "ss_floor_ceiling_01_2x1", "ss_floor_ceiling_01_dmg", "ss_floor_ceiling_01_dmg_alt", "ss_floor_ceiling_02_1x1", "ss_floor_ceiling_02_2x1", "ss_floor_ceiling_02_dmg_01", "ss_floor_ceiling_02_dmg_02", "ss_floor_ceiling_02_dmg_03", "ss_floor_ceiling_02_dmg_04", "ss_floor_ceiling_2x2_01", "ss_floor_ceiling_2x2_01_alt", "ss_floor_ceiling_2x2_02", "ss_floor_ceiling_2x2_02_alt", "ss_floor_ceiling_2x2_03", "ss_floor_ceiling_2x2_03_alt", "ss_floor_ceiling_2x2_03_tilt"],
	"hiedra": ["ss_hangingivy_01", "ss_hangingivy_02", "ss_hangingivy_03", "ss_hangingivy_04", "ss_hangingivy_05", "ss_hangingivy_06"],
	"pilar": ["ss_pillar_01", "ss_pillar_01_dmg", "ss_pillar_02", "ss_pillar_03", "ss_pillar_04", "ss_pillar_05", "ss_railing_pillar_01", "ss_railing_pillar_01_corner"],
	"viga": ["ss_rafter_01", "ss_rafter_02", "ss_rafter_ceiling", "ss_rafter_dmg", "ss_rafter_intersection"],
	"baranda": ["ss_railing_01_01", "ss_railing_01_02", "ss_railing_01_03", "ss_railing_01_04", "ss_railing_02_01", "ss_railing_02_02", "ss_railing_02_03", "ss_railing_02_04", "ss_railing_02_corner"],
	"escalera": ["ss_stairs_half", "ss_stairs_railing", "ss_stairs_railing_01", "ss_stairs_railing_01_alt", "ss_stairs_railing_01_alt_2", "ss_stairs_railing_3", "ss_stairs_railing_3_alt_2", "ss_stairs_railing_5_alt", "ss_stairs_railing_end", "ss_stairs_railing_merged_01", "ss_stairs_railing_merged_02", "ss_stairs_wood_2floor_end", "ss_stairs_wood_2floor_start", "ss_stairs_wood_3floor_end", "ss_stairs_wood_3floor_mid", "ss_stairs_wood_3floor_start", "ss_stairs_wood_full", "ss_stairs_wood_tower_end", "ss_stairs_wood_tower_start", "ss_wood_stair_plank"],
	"muro": ["ss_wall_01", "ss_wall_01_corner", "ss_wall_02", "ss_wall_03", "ss_wall_04", "ss_wall_arch_01"],
	"muro_arco": ["ss_wall_archdetail_01", "ss_wall_archdetail_02", "ss_wall_archdetail_03", "ss_wall_archdetail_04", "ss_wall_archdetail_cornerinside", "ss_wall_archdetail_corneroutside", "ss_wall_thick_archdetail_01", "ss_wall_thick_archdetail_02", "ss_wall_thick_archdetail_03", "ss_wall_thick_archdetail_04", "ss_wall_window_archdetail", "ss_wall_window_archdetail_half"],
	"muro_grueso": ["ss_wall_corner_thick_05", "ss_wall_loopholes_thick_01", "ss_wall_loopholes_thick_half", "ss_wall_thick_01", "ss_wall_thick_02", "ss_wall_thick_03", "ss_wall_thick_04", "ss_wall_thick_dmg_01", "ss_wall_thick_dmg_01_alt", "ss_wall_thick_dmg_01_half_01", "ss_wall_thick_dmg_01_half_02", "ss_wall_thick_dmg_02", "ss_wall_thick_dmg_02_alt", "ss_wall_thick_dmg_02_half_01", "ss_wall_thick_dmg_02_half_02", "ss_wall_thick_dmg_03", "ss_wall_thick_dmg_03_alt", "ss_wall_thick_dmg_03_half_01", "ss_wall_thick_dmg_03_half_02", "ss_wall_thick_dmg_04", "ss_wall_thick_dmg_04_alt", "ss_wall_thick_dmg_04_half_01", "ss_wall_thick_dmg_04_half_02", "ss_wall_thick_half_01", "ss_wall_thick_half_02", "ss_wall_thick_half_03", "ss_wall_thick_half_04", "ss_wall_windows_half_thick", "ss_wall_windows_thick_01"],
	"muro_danado": ["ss_wall_dmg_01", "ss_wall_dmg_01_alt", "ss_wall_dmg_02", "ss_wall_dmg_02_alt", "ss_wall_dmg_03", "ss_wall_dmg_03_alt", "ss_wall_dmg_04", "ss_wall_dmg_04_alt"],
	"muro_bajo": ["ss_wall_dmg_01_half_01", "ss_wall_dmg_01_half_02", "ss_wall_dmg_02_half_01", "ss_wall_dmg_02_half_02", "ss_wall_dmg_03_half_01", "ss_wall_dmg_03_half_02", "ss_wall_dmg_04_half_01", "ss_wall_dmg_04_half_02", "ss_wall_half_01", "ss_wall_half_02", "ss_wall_half_03", "ss_wall_half_04", "ss_wall_half_corner", "ss_wall_loopholes_half", "ss_wall_windows_half"],
	"cornisa": ["ss_wall_ledge_corner", "ss_wall_ledge_thick_01", "ss_wall_ledge_thick_02", "ss_wall_ledge_thick_03", "ss_wall_ledge_thick_04", "ss_wall_ledge_thick_04_bottom", "ss_wall_ledge_thick_corner", "ss_wall_ledge_thick_corner_big", "ss_wall_ledgedetail_01", "ss_wall_ledgedetail_02", "ss_wall_ledgedetail_03", "ss_wall_ledgedetail_04", "ss_wall_ledgedetail_inside", "ss_wall_ledgedetail_outside"],
	"muro_ventana": ["ss_wall_loopholes_01", "ss_wall_windows_01"],
}

const CATS_LC: Dictionary = {
	"estructura": ["lost_arch", "lost_entrance", "lost_flatplatform", "lost_flatstone_a", "lost_flatstone_b", "lost_largearch", "lost_largewall_6x9", "lost_largewall_b", "lost_minearch", "lost_platform_a", "lost_portalblocks", "lost_rockarray_a", "lost_shrinearch", "lost_smallplatform_a", "lost_smallplatform_b", "lost_smallplatform_c", "lost_smallplatform_d", "lost_stair_a", "lost_stair_b", "lost_stair_c", "lost_stair_d", "lost_stair_e", "lost_stalagmite_a", "lost_stalagmite_b", "lost_stonearray_a", "lost_stonearray_b", "lost_stonearray_c", "lost_stonecolumn_a", "lost_stonecolumn_b", "lost_totem_a", "lost_totemrock_a", "lost_totemrock_b", "lost_totemrock_c", "lost_totemstone_b", "lost_tunnel", "lost_tunnel_a"],
	"mina": ["lost_axe", "lost_barrier", "lost_beamsupport_a", "lost_blastingmachine", "lost_bomb", "lost_brokenrail_a", "lost_brokenrail_b", "lost_cart", "lost_dynamite_a", "lost_dynamite_b", "lost_forkedrail_2_a", "lost_forkedrail_2_b", "lost_forkedrail_2_c", "lost_forkedrail_3_a", "lost_forkedrail_4_a", "lost_hammer", "lost_lantern", "lost_ledder", "lost_pickaxe", "lost_rope_a", "lost_rope_b", "lost_rope_c", "lost_rope_d", "lost_roundbeam", "lost_roundrail_a", "lost_roundrail_b", "lost_roundrail_c", "lost_roundrail_d", "lost_shovel", "lost_sidepanel_a", "lost_sidepanel_b", "lost_siderail_a", "lost_siderail_b", "lost_sidesupport_a", "lost_standinglantern", "lost_straightrail_a", "lost_straightrail_b", "lost_supportbeam", "lost_toolbox", "lost_toolshelf", "lost_trolley_a", "lost_trolley_b", "lost_trolley_c", "lost_trolley_d", "lost_trolley_e", "lost_u_rail_a", "lost_u_rail_b", "lost_woodbeam_1", "lost_woodbeam_2", "lost_woodbeam_3", "lost_woodenplank", "lost_woodsupport"],
	"atrezo": ["lost_bag_a", "lost_bag_b", "lost_bag_c", "lost_bag_d", "lost_bag_e", "lost_bag_f", "lost_barrel", "lost_barrel_a", "lost_barrel_b", "lost_barrel_c", "lost_barrel_d", "lost_barrel_e", "lost_barrel_f", "lost_bench", "lost_book_a", "lost_book_b", "lost_book_c", "lost_book_d", "lost_book_e", "lost_book_f", "lost_book_g", "lost_book_h", "lost_book_i", "lost_book_j", "lost_book_l", "lost_bottle_a", "lost_bottle_b", "lost_bottle_c", "lost_bottle_d", "lost_bottle_e", "lost_bottle_f", "lost_bottle_g", "lost_box_a", "lost_box_b", "lost_box_c", "lost_box_cover", "lost_box_d", "lost_box_e", "lost_box_f", "lost_box_g", "lost_box_i", "lost_box_j", "lost_brokenbox_a", "lost_brokenbox_b", "lost_brokenbox_c", "lost_brokenbox_d", "lost_brokenparts", "lost_candle_a", "lost_candle_b", "lost_candle_c", "lost_candle_d", "lost_candle_e", "lost_chair", "lost_table"],
	"vegetacion": ["lost_berries", "lost_bush", "lost_clover_cluster", "lost_deadtree_a", "lost_fern_a", "lost_flower_b", "lost_flowers_a", "lost_glowingplant_a", "lost_glowingplant_b", "lost_glowingplant_c", "lost_greentrees", "lost_groundcover_a", "lost_groundcover_b", "lost_groundmushrooms_a", "lost_groundmushrooms_b", "lost_largegroundplant", "lost_largemushrooms_a", "lost_largemushrooms_b", "lost_largemushrooms_c", "lost_middlemushrooms_a", "lost_middlemushrooms_b", "lost_root_a", "lost_root_b", "lost_root_c", "lost_root_d", "lost_roundleaf_cluster", "lost_smallgroundcover", "lost_smallmushrooms_a", "lost_smallmushrooms_b", "lost_smallmushrooms_c", "lost_smallroot_a", "lost_smallroot_b", "lost_smallroot_c", "lost_smallroot_d", "lost_smallroot_e", "lost_spiral_plant", "lost_violetflowercluster", "lost_wallgrassclump_a", "lost_wallgrassclump_b", "lost_wallgrassclump_c"],
	"calca": ["lost_calca_glowingcrack_a", "lost_calca_glowingdots", "lost_calca_symbol_a", "lost_calca_symbol_b", "lost_calca_symbol_c", "lost_calca_symbol_d"],
	"cristal": ["lost_crystal_blue_a", "lost_crystal_blue_b", "lost_crystal_blue_c", "lost_crystal_red_a", "lost_crystal_red_b", "lost_crystal_red_c", "lost_hex_a", "lost_hex_b", "lost_hex_c", "lost_hex_d", "lost_hex_e", "lost_hex_f", "lost_singlecrystal_blue_a", "lost_singlecrystal_blue_b", "lost_singlecrystal_blue_c", "lost_singlecrystal_blue_d", "lost_singlecrystal_red_a", "lost_singlecrystal_red_b", "lost_smallcrystals"],
}

const KIT_CUEVA: Array = ["cueva_pared", "cueva_esquina_ext", "cueva_esquina_int", "cueva_pared_baja", "estalagmitas_a", "estalagmitas_b", "rocas_pequenas", "piedras", "estalagmita_resonante", "estalagmita_rota", "geoda_resonante", "cristal_resonante", "cristal_elemental", "cristal_sanctuario", "esquirla_cristal", "roca_cristal", "columna_agrietada", "muro_agrietado", "boca_cueva", "rocas_salpicadura", "helechos_cueva", "musgo_colgante", "llave_pequena", "bloque_enlace", "roca_musgosa", "raices_musgo", "raices_secas", "raices_obstaculo", "brasero_cueva", "placa_presion_cueva", "placa_peso", "receptor_runico", "prisma_orientable", "totem_runico", "roca_hueca", "alga_cueva", "basalto_suelto", "laja_piedra", "cuenco_piedra", "estatua_piedra", "tocon_roca", "roca_est_0", "roca_est_1", "roca_est_2", "roca_est_3", "roca_est_4", "roca_est_musgo_0", "roca_est_musgo_1", "roca_est_musgo_2", "roca_est_musgo_3", "roca_est_musgo_4", "piedra_est_0", "piedra_est_1", "piedra_est_2", "piedra_est_3", "piedra_est_4", "piedra_est_musgo_0", "piedra_est_musgo_1", "piedra_est_musgo_2"]


static var _cajas: Dictionary = {}


## Las categorías de un pack (y grupo) EN ORDEN: [[nombre_categoria, [ids…]], …]. Solo ids cuya escena existe (el resto va a `faltan`).
static func categorias(pack: String, grupo: String) -> Dictionary:
	var res: Array = []
	var faltan: Array = []
	var fuente: Array = []
	match pack:
		"ss":
			var orden: Array = (GRUPOS_SS.get(grupo, GRUPOS_SS["muros"] + GRUPOS_SS["resto"]) as Array) if grupo != "" and grupo != "todo" else (GRUPOS_SS["muros"] + GRUPOS_SS["resto"])
			for c in orden:
				if CATS_SS.has(c):
					fuente.append([c, CATS_SS[c]])
		"lc":
			var orden_l: Array = (GRUPOS_LC.get(grupo, GRUPOS_LC["roca"] + GRUPOS_LC["mina"] + GRUPOS_LC["vida"]) as Array) if grupo != "" and grupo != "todo" else (GRUPOS_LC["roca"] + GRUPOS_LC["mina"] + GRUPOS_LC["vida"])
			for c in orden_l:
				if CATS_LC.has(c):
					fuente.append([c, CATS_LC[c]])
		"kit":
			fuente.append(["kit propio de la cueva", KIT_CUEVA])
	for par in fuente:
		var ids: Array = []
		for id in (par[1] as Array):
			if ResourceLoader.exists(String(RUTAS[pack]) + String(id) + ".tscn"):
				ids.append(String(id))
			else:
				faltan.append(String(id))
		if not ids.is_empty():
			res.append([String(par[0]), ids])
	return {"categorias": res, "faltan": faltan}


## La caja de la pieza (en su propio espacio, base en y = 0). Sin malla (calcas) devuelve CAJA_DEFECTO. Guardada por id.
static func caja_de(pack: String, id: String) -> AABB:
	if _cajas.has(id):
		return _cajas[id]
	var ps: PackedScene = load(String(RUTAS[pack]) + id + ".tscn") as PackedScene
	var caja: AABB = CAJA_DEFECTO
	if ps != null:
		var st: SceneState = ps.get_state()
		var hecho: bool = false
		for i in range(st.get_node_property_count(0)):
			if st.get_node_property_name(0, i) == "metadata/caja":
				caja = st.get_node_property_value(0, i)
				hecho = true
		if not hecho:
			var n: Node = ps.instantiate()
			var hay: bool = false
			var acc := AABB()
			for h in n.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = h as MeshInstance3D
				if mi.mesh == null:
					continue
				var xf := Transform3D.IDENTITY
				var q: Node = mi
				while q != null and q != n:
					xf = (q as Node3D).transform * xf
					q = q.get_parent()
				var b: AABB = xf * mi.mesh.get_aabb()
				acc = b if not hay else acc.merge(b)
				hay = true
			n.free()
			if hay and acc.size.x > 0.05 and acc.size.z > 0.05:
				caja = acc
	_cajas[id] = caja
	return caja


## La distribución: ancho_u = ancho del rectángulo en u. Devuelve
##   {"piezas": [{id, categoria, x, z (el ORIGEN de la pieza, relativo a la esquina del rectángulo, u), rx, rz (dónde va el rótulo)}], "cabeceras": [{texto, x, z}], "fondo": u usadas, "faltan": [ids]}.
static func plan(pack: String, grupo: String, ancho_u: float) -> Dictionary:
	var cats: Dictionary = categorias(pack, grupo)
	var piezas: Array = []
	var cabeceras: Array = []
	var z: float = 0.0
	for par in (cats["categorias"] as Array):
		cabeceras.append({"texto": "%s (%d)" % [String(par[0]).to_upper().replace("_", " "), (par[1] as Array).size()], "x": 0.3, "z": z + 0.2})
		z += 1.0
		var fila: Array = []
		var x: float = 0.0
		var fondo: float = 0.0
		var alto: float = 0.0
		for id in (par[1] as Array):
			var caja: AABB = caja_de(pack, String(id))
			var ancho_p: float = maxf(caja.size.x, float(String(id).length()) * ANCHO_RETULO_CAR)
			if x > 0.0 and x + ancho_p > ancho_u:
				z = _cerrar_fila(piezas, fila, z, fondo, alto)
				fila = []
				x = 0.0
				fondo = 0.0
				alto = 0.0
			var cx: float = x + ancho_p * 0.5
			fila.append({"id": String(id), "categoria": String(par[0]), "x": cx - (caja.position.x + caja.size.x * 0.5), "cx": cx, "caja": caja})
			x += ancho_p + HUECO
			fondo = maxf(fondo, caja.size.z)
			alto = maxf(alto, caja.size.y)
		if not fila.is_empty():
			z = _cerrar_fila(piezas, fila, z, fondo, alto)
		z += 0.3
	return {"piezas": piezas, "cabeceras": cabeceras, "fondo": z, "faltan": cats["faltan"]}


static func _cerrar_fila(piezas: Array, fila: Array, z0: float, fondo: float, alto: float) -> float:
	for it in fila:
		var caja: AABB = it["caja"]
		piezas.append({"id": it["id"], "categoria": it["categoria"], "x": it["x"], "z": z0 - caja.position.z,
			"rx": it["cx"], "rz": z0 + fondo + 0.45})
	return z0 + fondo + FONDO_ROTULO + minf(alto * ALTO_FILA_EXTRA, ALTO_FILA_TOPE)


## Casillas de alto que necesita un rectángulo de `ancho` casillas para un pack y grupo (para dimensionar la plantilla).
static func alto_necesario(pack: String, grupo: String, ancho: int) -> int:
	var p: Dictionary = plan(pack, grupo, float(ancho) * S)
	return int(ceil(float(p["fondo"]) / S)) + 1
