"""Compone mundo/datos_nivel/mapas/LostCave.txt, el nivel de prueba del pack Stylized Lost Cave (24/11/2026).

Uso (desde la raíz del repo; solo librería estándar):   python tools/mapa_lostcave.py mundo/datos_nivel/mapas/LostCave.txt
Las salas y las piezas se ponen a mano aquí (SALAS, p(...)). Las PAREDES salen solas: rocas del pack en el borde de cada sala, medio fuera
del suelo y mirando hacia dentro (ver PALETA, PROF, ALTO_MAX). Después: godot --path . --script res://herramientas/captura_lostcave_nivel.gd
comprueba que se llega andando a las cinco salas.
"""
import sys

W, H = 32, 26
g = [[" "] * W for _ in range(H)]


def sala(x0, y0, x1, y1):
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g[y][x] = "."


# salas y pasos (casillas, inclusive). x = este, y = sur (hacia la cámara)
SALAS = {
	"BOCA": (11, 18, 19, 24),
	"CRUCE": (8, 8, 22, 14),
	"MINA": (1, 4, 6, 16),
	"CRISTALES": (24, 4, 30, 16),
	"SANTUARIO": (10, 1, 20, 5),
}
for r in SALAS.values():
	sala(*r)
sala(14, 15, 16, 17)   # boca -> cruce
sala(7, 10, 7, 12)     # cruce -> mina
sala(22, 10, 24, 12)   # cruce -> cristales
sala(14, 6, 16, 7)     # cruce -> santuario
g[20][15] = "S"

P = []   # (id, x, y, extra)


def p(modelo, x, y, **kw):
	extra = "".join(" %s=%s" % (k, v) for k, v in kw.items())
	P.append((modelo, x, y, extra))


# --- BOCA: transición bosque -> cueva (vegetación de fuera que se mete dentro) ---
p("lost_largearch", 15, 17)                 # la boca de la cueva (se pasa por debajo)
p("lost_greentrees", 11, 23); p("lost_greentrees", 19, 22, giro=40)
p("lost_deadtree_a", 12, 19)
p("lost_bush", 13, 24); p("lost_bush", 18, 24, giro=70)
p("lost_fern_a", 11, 21); p("lost_fern_a", 17, 21, giro=120); p("lost_fern_a", 14, 19)
p("lost_largegroundplant", 18, 19); p("lost_roundleaf_cluster", 12, 22); p("lost_clover_cluster", 16, 24)
p("lost_wallgrassclump_a", 19, 19); p("lost_flowers_a", 13, 22); p("lost_violetflowercluster", 17, 23)
p("lost_largemushrooms_b", 19, 20); p("lost_largemushrooms_a", 11, 19); p("lost_smallmushrooms_a", 16, 19)
p("lost_root_b", 18, 18); p("lost_root_d", 12, 18)
p("lost_stair_c", 15, 22); p("lost_standinglantern", 13, 18); p("lost_standinglantern", 17, 18, giro=180)                   # losas de entrada (se pisan)

# --- CRUCE: la sala central ---
p("lost_stonearray_b", 10, 8); p("lost_stonearray_a", 20, 8)
p("lost_stalagmite_a", 9, 13); p("lost_stalagmite_b", 22, 14)
p("lost_stonecolumn_a", 12, 10); p("lost_stonecolumn_a", 18, 10, giro=180)
p("lost_arch", 15, 12)                      # arco de roca en el camino norte-sur (se pasa por debajo)
p("lost_calca_glowingcrack_a", 10, 9)       # grieta azul en la roca del noroeste
p("lost_largemushrooms_c", 9, 14); p("lost_middlemushrooms_a", 20, 14); p("lost_smallmushrooms_b", 10, 14)
p("lost_singlecrystal_blue_a", 22, 9); p("lost_singlecrystal_red_a", 22, 13)   # pistas de la sala de cristales
p("lost_lantern", 8, 9); p("lost_standinglantern", 11, 13); p("lost_standinglantern", 19, 13, giro=180); p("lost_smallroot_b", 13, 8); p("lost_smallroot_d", 17, 8)

# --- MINA (oeste): raíles, vagonetas, entibado ---
p("lost_entrance", 4, 4)                    # bocamina de madera al fondo
for y in (6, 8, 10, 12, 14):
	p("lost_straightrail_b", 3, y, giro=90)  # vía norte-sur
p("lost_roundrail_b", 3, 16, giro=90)
p("lost_trolley_a", 3, 8, giro=90); p("lost_trolley_c", 3, 13, giro=90)
p("lost_cart", 6, 7)
p("lost_standinglantern", 1, 10); p("lost_standinglantern", 4, 11); p("lost_lantern", 2, 4); p("lost_lantern", 4, 15); p("lost_standinglantern", 1, 14)
p("lost_barrel_a", 6, 5); p("lost_barrel_c", 6, 4); p("lost_bag_a", 1, 5); p("lost_bag_c", 1, 6)
p("lost_box_a", 1, 15); p("lost_box_c", 2, 16); p("lost_brokenbox_c", 6, 15)
p("lost_toolbox", 1, 12); p("lost_pickaxe", 5, 9); p("lost_shovel", 5, 13); p("lost_dynamite_b", 6, 13)
p("lost_blastingmachine", 6, 14); p("lost_bomb", 5, 16)
p("lost_minearch", 7, 11, giro=90, escala=1.8)   # 1,8: con su tamaño las patas tapaban la casilla del centro (el único paso); p("lost_lantern", 7, 10)          # paso cruce -> mina
p("lost_smallplatform_a", 5, 5)

# --- CRISTALES (este): rojos = fuego, azules = agua ---
p("lost_hex_a", 25, 5); p("lost_hex_c", 29, 5); p("lost_hex_d", 30, 9); p("lost_hex_e", 25, 14); p("lost_hex_f", 29, 15)
p("lost_crystal_blue_a", 26, 8); p("lost_crystal_blue_b", 28, 7); p("lost_crystal_blue_c", 30, 12)
p("lost_crystal_red_a", 25, 11); p("lost_crystal_red_b", 28, 12); p("lost_crystal_red_c", 27, 15)
p("lost_singlecrystal_blue_b", 27, 10); p("lost_singlecrystal_red_b", 29, 10); p("lost_smallcrystals", 26, 13)
p("lost_glowingplant_a", 24, 7); p("lost_glowingplant_b", 30, 6); p("lost_glowingplant_c", 24, 15)
p("lost_stalagmite_a", 27, 4, giro=200)
p("lost_calca_glowingdots", 26, 5); p("lost_lantern", 23, 10)

# --- SANTUARIO (norte): portal de runas, tótems y símbolos ---
p("lost_portalblocks", 15, 1, escala=0.4)   # el arco portal de runas, al fondo
p("lost_shrinearch", 15, 6)                 # entrada al santuario (se pasa por debajo)
p("lost_totem_a", 11, 3); p("lost_totemstone_b", 19, 3)
p("lost_totemrock_b", 10, 2); p("lost_totemrock_c", 20, 2)
p("lost_calca_symbol_a", 11, 2); p("lost_calca_symbol_c", 19, 2)
p("lost_table", 15, 3); p("lost_standinglantern", 12, 5); p("lost_standinglantern", 18, 5, giro=180); p("lost_candle_a", 13, 3); p("lost_candle_c", 17, 3)
p("lost_candle_d", 14, 4); p("lost_candle_e", 16, 4); p("lost_book_a", 13, 4); p("lost_book_c", 17, 4)

# --- PAREDES (24/11): el anillo de casillas que rodea el suelo es «#». Las viste la maqueta con las rocas del pack (`paredes_cueva = "lostcave"`,
# presentacion/paredes_lostcave.gd), igual que en un mapa del generador: una roca por casilla de muro que da a suelo, así no quedan huecos.
# Más allá del anillo, « » (sin suelo: la oscuridad).
suelo = {(x, y) for y in range(H) for x in range(W) if g[y][x] != " "}
for y in range(H):
	for x in range(W):
		if g[y][x] == " " and any((x + dx, y + dz) in suelo for dx in (-1, 0, 1) for dz in (-1, 0, 1)):
			g[y][x] = "#"
# --- salida ---
cab = """; NIVEL DE PRUEBA del pack «Stylized Lost Cave» (StylArts / Leartes Cosmos), 24/11/2026. 32 x 26. Lo GENERA tools/mapa_lostcave.py (las paredes de roca salen solas): cambiar allí y volver a lanzar.
; Escena: escenas/PruebaLostCave.tscn. Las piezas lost_* NO van en git: si faltan, tools\\preparar_lostcave.cmd (ver arte/lostcave/LEEME.md).
; Recorrido: BOCA (sur: transición del bosque, vegetación) -> arco grande -> CRUCE (sala central, arco de roca, columnas, grieta azul)
;   -> oeste MINA (vía, vagonetas, bocamina, faroles) · este CRISTALES (rojos = fuego, azules = agua, hexágonos) · norte SANTUARIO (portal de runas, tótems, símbolos).
; Letras: «.» suelo de cueva · «#» pared (la viste la maqueta con rocas del pack: paredes_cueva = "lostcave") · « » fuera (sin suelo: la oscuridad) · S jugadora.
; Las piezas sólidas cierran las casillas que tapan; arcos y túneles cierran solo las de sus patas (huella_por_forma); losas y escaleras se pisan.
"""
filas = ["".join(r) for r in g]
# El lector de mapas se salta las filas que solo tienen espacios: se recortan las de arriba y abajo y se corrigen las coordenadas.
dy = next(i for i, f in enumerate(filas) if f.strip())
fin = max(i for i, f in enumerate(filas) if f.strip())
filas = filas[dy:fin + 1]
ZONAS = [(11, 17, 19, 24, "bosque mezcla=0.8 rotulo=Cueva_Perdida"), (7, 6, 23, 16, "cueva mezcla=0.8"), (1, 4, 6, 16, "cueva_goblin mezcla=0.8"),
	(24, 4, 30, 16, "cueva_hielo mezcla=0.8"), (10, 1, 20, 5, "cueva_ruinas mezcla=0.8")]
zonas = ["; --- zonas de luz (LuzZona3D) ---"]
for x0, y0, x1, y1, resto in ZONAS:
	zonas.append("; zona %d,%d..%d,%d %s" % (x0, y0 - dy, x1, y1 - dy, resto))
for nombre, r in SALAS.items():
	zonas.append("; rect %s %d %d %d %d" % (nombre, r[0], r[1] - dy, r[2] - r[0] + 1, r[3] - r[1] + 1))
piezas = ["; --- piezas del pack (decorado: modelo + giro/escala) ---"]
usados = {}
for m, x, y, extra in P:
	if g[y][x] == " ":
		print("AVISO fuera del suelo:", m, x, y)
	base = "d_" + m[5:]
	usados[base] = usados.get(base, 0) + 1
	pid = base if usados[base] == 1 else "%s_%d" % (base, usados[base])
	piezas.append("; pieza %s decorado %d %d modelo=%s%s" % (pid, x, y - dy, m, extra))
cab = cab.replace("32 x 26", "%d x %d" % (W, len(filas)))
open(sys.argv[1], "w", encoding="utf8", newline="\n").write(cab + "\n".join(filas) + "\n" + "\n".join(zonas + piezas) + "\n")
print("\n".join(filas)); print(len(P), "piezas")
