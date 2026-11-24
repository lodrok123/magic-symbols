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
sala(14, 6, 16, 7)     # cruce -> santuario (24/11, puzles: es el PRECIPICIO de LC3, se vacía después de poner las paredes)
# 24/11 · puzles (docs/PUZLES_LOSTCAVE_2026-11-24.md): rincones nuevos
sala(2, 18, 5, 20)     # MINA · galería hundida (LC1): tras el muro de (3,17)
g[17][3] = "."         # la boca de la galería (la tapa el muro agrietado)
sala(2, 1, 2, 3)       # MINA · nicho de la reja (LC2): reja en (2,3), cofre en (2,1)
g[15][12] = "."        # CRUCE · la pared hueca (LC5)
sala(11, 16, 12, 16)   # CRUCE · el nicho de detrás de la pared hueca
PRECIPICIO = [(x, y) for x in range(14, 17) for y in range(6, 8)]   # LC3: 2 de hondo entre el cruce y el santuario
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
# 24/11 (puzle LC4): los ROJOS al norte, junto al receptor de fuego (29,8); los AZULES al sur, junto al de agua (29,14). Ninguno sobre la veta.
p("lost_hex_a", 25, 5); p("lost_hex_c", 29, 5); p("lost_hex_d", 30, 9); p("lost_hex_e", 25, 14); p("lost_hex_f", 29, 15)
p("lost_crystal_red_a", 26, 8); p("lost_crystal_red_b", 28, 7); p("lost_crystal_red_c", 30, 7)
p("lost_crystal_blue_a", 27, 15); p("lost_crystal_blue_b", 28, 12); p("lost_crystal_blue_c", 30, 12)
p("lost_singlecrystal_red_b", 28, 9); p("lost_singlecrystal_blue_b", 28, 14); p("lost_smallcrystals", 26, 13)
p("lost_glowingplant_a", 24, 7); p("lost_glowingplant_b", 30, 6); p("lost_glowingplant_c", 24, 15)
p("lost_stalagmite_a", 27, 4, giro=200)
p("lost_calca_glowingdots", 26, 5); p("lost_lantern", 23, 10)

# --- SANTUARIO (norte): portal de runas, tótems y símbolos ---
p("lost_portalblocks", 15, 1, escala=0.4)   # el arco portal de runas, al fondo
p("lost_shrinearch", 15, 5)                 # entrada al santuario (se pasa por debajo). 24/11: de (15,6) a (15,5): en la 6 está el precipicio
p("lost_totem_a", 11, 3); p("lost_totemstone_b", 19, 3)
p("lost_totemrock_b", 10, 2); p("lost_totemrock_c", 20, 2)
p("lost_calca_symbol_a", 11, 2); p("lost_calca_symbol_c", 19, 2)
# 24/11 (LC6): las estatuas van en (13,3) (15,3) (17,3) y el cofre legendario en (15,2): la mesa y dos velas se apartan
p("lost_table", 17, 1); p("lost_standinglantern", 12, 5); p("lost_standinglantern", 18, 5, giro=180); p("lost_candle_a", 12, 3); p("lost_candle_c", 18, 3)
p("lost_candle_d", 14, 4); p("lost_candle_e", 16, 4); p("lost_book_a", 13, 4); p("lost_book_c", 17, 4)

# --- 24/11 · decorado de los puzles ---
p("lost_brokenrail_b", 15, 8, giro=90, dz=-0.7)   # LC3: la vía rota asomando al precipicio (el puente de la mina que se cayó)
p("lost_rope_c", 13, 5); p("lost_woodenplank", 17, 5, giro=30)
p("lost_woodsupport", 5, 18); p("lost_brokenbox_a", 5, 20); p("lost_dynamite_a", 2, 19)   # LC1: la galería hundida

# --- PUZLES (24/11, docs/PUZLES_LOSTCAVE_2026-11-24.md). Coordenadas de este archivo (se corrigen con dy al escribir). ---
# Flags: lostcave.<sala>.<cosa>. Recompensas: un fragmento de savia en cada épico de LC1, LC4 y LC5 (3 = una savia entera).
PZ = """
; --- LC1 · MINA · La voladura: fuego al barril de pólvora de la vía -> la explosión rompe el muro de la galería hundida (radio 2,6 u: pegado al muro, no en diagonal) ---
; pieza lc1_barril barril 3 16
; pieza lc1_muro muro 3 17 golpes=3
; pieza lc1_cofre cofre 3 20 modelo=epico abierto=lostcave.mina.voladura da=oro:15+fragmento_savia:1
; --- LC2 · MINA · La balanza: roca mediana a la placa de 2, pequeña a la de 1 y un bloque de TIERRA (25 s) en la tercera -> reja del nicho ---
; pieza lc2_placa_a pulsador 4 7 modo=presencia peso=2 modelo=cueva
; pieza lc2_placa_b pulsador 2 7 modo=presencia peso=1 modelo=cueva
; pieza lc2_placa_c pulsador 6 6 modo=presencia peso=1 modelo=cueva
; pieza lc2_roca_m roca_empujable 4 9 tam=mediana
; pieza lc2_roca_p roca_empujable 2 9 tam=pequena
; pieza lc2_reja puerta 2 3 modelo=reja
; pieza lc2_cofre cofre 2 1 modelo=epico abierto=lostcave.mina.balanza da=oro:25+pocion:1
; puzle lc2_a cuando=lc2_placa_a.pulsado si=lc2_placa_b.activo+lc2_placa_c.activo hace=lc2_reja.abrir
; puzle lc2_b cuando=lc2_placa_b.pulsado si=lc2_placa_a.activo+lc2_placa_c.activo hace=lc2_reja.abrir
; puzle lc2_c cuando=lc2_placa_c.pulsado si=lc2_placa_a.activo+lc2_placa_b.activo hace=lc2_reja.abrir
; --- LC3 · CRUCE -> SANTUARIO · El puente caído: precipicio de 2 (14..16, 6..7); se cruza con el puente de tierra (barrera + líneas) desde (15,8) ---
; PRECIPICIO «lc3_precipicio»
; --- LC4 · CRISTALES · Rojo y azul: golpear el cristal dormido con fuego / agua y girar el prisma (E) hacia el receptor de ese color ---
; El prisma nace mirando al OESTE, a la veta de entrada (no reemite nada). Un giro: norte (fuego). Tres giros: sur (agua).
; pieza lc4_cristal cristal 27 11 cada=0
; pieza lc4_veta_entra veta 28 11
; pieza lc4_prisma prisma 29 11 dir=o
; pieza lc4_veta_n veta 29 9 celdas=29,9..29,10
; pieza lc4_veta_s veta 29 12 celdas=29,12..29,13
; pieza lc4_rec_fuego receptor 29 8 elemento=fuego flag=lostcave.cristales.fuego
; pieza lc4_rec_agua receptor 29 14 elemento=agua flag=lostcave.cristales.agua
; pieza lc4_cofre cofre 30 4 modelo=epico aparece_si=flag.lostcave.cristales.fuego+flag.lostcave.cristales.agua abierto=lostcave.cristales.cofre da=oro:15+fragmento_savia:1
; --- LC5 · CRUCE · La grieta que suena: pared hueca (eco con cualquier pulso; se abre con el ᚱ de la jugadora) y nicho ---
; El pulso de la jugadora corre por lo que conduce: una veta de dos casillas lleva desde el cruce hasta el pie de la pared.
; pieza lc5_veta veta 12 13 celdas=12,13..12,14
; pieza lc5_hueca pared_hueca 12 15 flag=lostcave.cruce.grieta mira=n
; pieza lc5_cofre cofre 11 16 modelo=epico abierto=lostcave.cruce.nicho da=pocion:1+fragmento_savia:1
; --- LC6 · SANTUARIO · Los tres sellos: pulsos de fuego, agua y tierra, en ese orden (oeste -> este) -> cofre legendario delante del portal ---
; pieza lc6_estatuas estatuas 13 3 celdas=13,3+15,3+17,3 secuencia=fuego,agua,tierra flag=lostcave.santuario.estatuas
; pieza lc6_cofre cofre 15 2 modelo=legendario aparece_si=flag.lostcave.santuario.estatuas abierto=lostcave.santuario.cofre da=oro:60+nucleo_eco:1
; --- LC7 · CRUCE · Sala del gólem: al entrar se cierran las bocas (boca, mina, cristales) hasta que caen el gólem y los dos limos ---
; pieza lc7_cerrojo cerrojo 15 16 celdas=15,16+7,11+23,10..23,12 sala=8,8..22,14 hasta=lostcave.cruce.limpio
; pieza lc7_guardia vigia 0 0 de=8,8..22,14 flag=lostcave.cruce.limpio
; pieza lc7_golem golem 15 9
; pieza lc7_limo limo 11 11
; pieza lc7_limo_2 limo 19 11
; puzle lc7_abre cuando=lc7_guardia.todos_derrotados hace=lc7_cerrojo.abrir
"""

# --- PAREDES (24/11): el anillo de casillas que rodea el suelo es «#». Las viste la maqueta con las rocas del pack (`paredes_cueva = "lostcave"`,
# presentacion/paredes_lostcave.gd), igual que en un mapa del generador: una roca por casilla de muro que da a suelo, así no quedan huecos.
# Más allá del anillo, « » (sin suelo: la oscuridad).
suelo = {(x, y) for y in range(H) for x in range(W) if g[y][x] != " "}
for y in range(H):
	for x in range(W):
		if g[y][x] == " " and any((x + dx, y + dz) in suelo for dx in (-1, 0, 1) for dz in (-1, 0, 1)):
			g[y][x] = "#"
# 24/11 (LC3): el precipicio, sin suelo DENTRO del mapa (rodeado de suelo y paredes: Precipicio3D le pone las paredes de roca y el fondo negro)
for x, y in PRECIPICIO:
	g[y][x] = " "
# --- salida ---
cab = """; NIVEL DE PRUEBA del pack «Stylized Lost Cave» (StylArts / Leartes Cosmos), 24/11/2026. 32 x 26. Lo GENERA tools/mapa_lostcave.py (las paredes de roca salen solas): cambiar allí y volver a lanzar.
; Escena: escenas/PruebaLostCave.tscn. Las piezas lost_* NO van en git: si faltan, tools\\preparar_lostcave.cmd (ver arte/lostcave/LEEME.md).
; Recorrido: BOCA (sur: transición del bosque, vegetación) -> arco grande -> CRUCE (sala central, arco de roca, columnas, grieta azul)
;   -> oeste MINA (vía, vagonetas, bocamina, faroles) · este CRISTALES (rojos = fuego, azules = agua, hexágonos) · norte SANTUARIO (portal de runas, tótems, símbolos).
; Letras: «.» suelo de cueva · «#» pared (la viste la maqueta con rocas del pack: paredes_cueva = "lostcave") · « » fuera (sin suelo: la oscuridad) · S jugadora.
; Las piezas sólidas cierran las casillas que tapan; arcos y túneles cierran solo las de sus patas (huella_por_forma); losas y escaleras se pisan.
; PUZLES (24/11, docs/PUZLES_LOSTCAVE_2026-11-24.md): LC7 gólem en el CRUCE · LC5 pared hueca (12,15) · LC1 voladura y LC2 balanza en la MINA · LC4 rojo y azul en CRISTALES
;   · LC3 el precipicio (14..16, 6..7: « » dentro del mapa) que se cruza con el puente de tierra · LC6 las tres estatuas del SANTUARIO.
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
# Los puzles van con las coordenadas de este archivo: solo valen si no se recortan filas por arriba (hoy la fila 0 es pared).
assert dy == 0, "las líneas de PZ suponen dy = 0: corrige sus coordenadas"
puzles = ["; --- PUZLES (24/11, docs/PUZLES_LOSTCAVE_2026-11-24.md) ---"] + [l for l in PZ.strip().split("\n")]
open(sys.argv[1], "w", encoding="utf8", newline="\n").write(cab + "\n".join(filas) + "\n" + "\n".join(zonas + piezas + puzles) + "\n")
print("\n".join(filas)); print(len(P), "piezas")
