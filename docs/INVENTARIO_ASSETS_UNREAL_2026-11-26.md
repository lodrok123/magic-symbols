# Inventario de assets traídos de Unreal — 26/11/2026

Generado por `python tools/inventario_assets_unreal.py` (se puede repetir: lee el índice, las piezas y las tablas del juego). Una fila por pieza en [`docs/fab_ue/inventario_piezas.tsv`](fab_ue/inventario_piezas.tsv). Las reglas de bioma y uso son de Claude (por nombre, categoría y tamaño) y están **sin ver pieza a pieza en pantalla**: Pablo decide.

Tamaños en **u de juego** (la caja ya lleva la escala 0,575; 1 casilla = 2,3 u = 4 m). «Visible» = a tamaño nativo desde la cámara cenital inclinada: **no** < 0,25 u, **poco** < 0,6 u, **sí** el resto (el juego reescala algunas con `MEDIDAS`, p. ej. las margaritas a 2,3 u de manto).

## Resumen

| Pack | Piezas | Usadas por el juego | Con versión del juego | Encajan en bosque (principal) | Bosque (principal o secundario) |
|---|---:|---:|---:|---:|---:|
| Asian Valley | 118 | 3 | 3 | 47 | 47 |
| Fantasy Forest | 102 | 12 | 12 | 100 | 100 |
| Islands | 98 | 2 | 2 | 15 | 15 |
| Jungle | 62 | 11 | 11 | 0 | 32 |
| Meadows | 68 | 19 | 19 | 60 | 61 |
| Mountains | 63 | 10 | 10 | 52 | 53 |
| Savanna | 68 | 3 | 3 | 9 | 9 |
| Stylescape: Ruins | 199 | 39 | n/a | 0 | 16 |
| **Total** | **778** | **99** | 60 | 283 | 333 |

### Por uso sugerido

| Pack | muro_arboles | decor_claro | adorno_borde | hierba_corta | flor_pequena | roca | tronco | ruina | no_usar |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Asian Valley | 19 | 23 | 13 | 34 | 8 | 15 | 0 | 0 | 6 |
| Fantasy Forest | 4 | 21 | 61 | 4 | 0 | 5 | 5 | 0 | 2 |
| Islands | 9 | 11 | 57 | 4 | 0 | 8 | 1 | 0 | 8 |
| Jungle | 10 | 15 | 15 | 3 | 6 | 12 | 1 | 0 | 0 |
| Meadows | 21 | 6 | 8 | 13 | 13 | 7 | 0 | 0 | 0 |
| Mountains | 18 | 3 | 4 | 11 | 6 | 12 | 1 | 0 | 8 |
| Savanna | 16 | 3 | 13 | 5 | 2 | 12 | 0 | 0 | 17 |
| Stylescape: Ruins | 0 | 0 | 6 | 0 | 0 | 0 | 0 | 192 | 1 |
| **Total** | **97** | **82** | **177** | **74** | **35** | **71** | **8** | **192** | **42** |

`uso_sugerido` es lo que la pieza *es*; `bioma_sugerido` dice dónde encaja. Una acacia es `muro_arboles` con bioma `ninguno`. `no_usar` = telón lejano, acantilado de más de 7 u, escala rota, conchas o pieza auxiliar.

### Sin usar que encajan en bosque

De 638 piezas aprovechables sin usar, **240** encajan en bosque como bioma principal (**272** contando secundario). Por uso:

| muro_arboles | decor_claro | adorno_borde | hierba_corta | flor_pequena | roca | tronco | ruina |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 42 | 30 | 68 | 27 | 18 | 49 | 6 | 0 |

Las que más aportarían al bosque y hoy no se usan: 

- **Muro de árboles** (los `#`): 42 piezas en bosque sin usar (abedules, olmos, robles, pinos, píceas, abetos, cipreses).
- **Rocas, setas, helechos, ramas, raíces y hojarasca** para el suelo y los bordes.
- **Muy pequeñas para verse** (`visible = no`/`poco`): los mantos de florecitas y hierbas finas se ven solo en grupo o reescaladas.

## Asian Valley (118 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| cultivo | 29 | 0.3 × 0.3 u (alto 0.1–0.4) | 0 | si 6/poco 19/no 4 | ninguno (29) |
| vara_bambu | 12 | 0.1 × 1.5 u (alto 0.7–1.7) | 0 | si 12 | ninguno (12); sec.: pantano |
| bambu | 11 | 2.3 × 5.4 u (alto 2.6–6.4) | 0 | si 11 | ninguno (11); sec.: pantano |
| flor | 8 | 0.5 × 0.4 u (alto 0.2–0.5) | 1 | si 3/poco 3/no 2 | bosque (8) |
| arbol | 8 | 2.9 × 3.5 u (alto 2.8–4.7) | 1 | si 8 | bosque (8) |
| agua | 7 | 0.5 × 0.2 u (alto 0.2–1.7) | 1 | si 3/poco 3/no 1 | pantano (6), ninguno (1) |
| fondo | 6 | 46.7 × 46.2 u (alto 29.2–48.3) | 0 | si 6 | ninguno (6) |
| estructura_bambu | 6 | 1.4 × 0.3 u (alto 0.1–1.4) | 0 | si 6 | ninguno (6); sec.: pantano |
| helecho | 6 | 0.4 × 0.2 u (alto 0.2–0.3) | 0 | poco 6 | bosque (6); sec.: cueva |
| roca | 6 | 0.8 × 0.4 u (alto 0.4–0.5) | 0 | si 6 | bosque (6); sec.: cueva |
| escombro | 6 | 3.9 × 0.4 u (alto 0.3–0.4) | 0 | si 6 | bosque (6); sec.: cueva |
| arbusto | 5 | 2.4 × 1.5 u (alto 1.0–3.9) | 0 | si 5 | bosque (5) |
| hierba | 5 | 0.6 × 0.2 u (alto 0.0–0.2) | 0 | si 2/poco 3 | bosque (5) |
| acantilado | 3 | 3.1 × 5.2 u (alto 4.2–6.3) | 0 | si 3 | bosque (3); sec.: cueva |

Usadas por el juego (3): `astilb_2`→flores_colores, `lotus_4`→nenufar_flor, `osmanthus5`→arbol_redondo

`no_usar` (6): `asianhill_0`, `asianhill_1`, `asianhill_2`, `asianhill_3`, `asianhill_4`, `asianhill_5`

## Fantasy Forest (102 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| seta | 53 | 0.4 × 0.4 u (alto 0.1–7.1) | 3 | si 21/poco 29/no 3 | bosque (53); sec.: cueva, pantano |
| hiedra | 10 | 0.6 × 1.2 u (alto 0.3–1.4) | 0 | si 10 | bosque (10); sec.: ruinas |
| arbusto | 9 | 0.8 × 0.5 u (alto 0.1–1.5) | 3 | si 6/poco 3 | bosque (9) |
| roca | 5 | 1.5 × 0.6 u (alto 0.5–1.2) | 0 | si 5 | bosque (5); sec.: cueva, pantano |
| raiz | 4 | 4.9 × 3.5 u (alto 0.1–8.4) | 1 | si 2/poco 2 | bosque (4); sec.: pantano |
| arbol | 4 | 13.9 × 15.2 u (alto 14.8–17.5) | 2 | si 4 | bosque (4) |
| hojarasca | 4 | 0.7 × 0.1 u (alto 0.0–0.1) | 0 | si 3/poco 1 | bosque (4); sec.: pantano |
| hierba | 4 | 1.2 × 0.2 u (alto 0.1–0.6) | 1 | si 3/poco 1 | bosque (4) |
| helecho | 3 | 0.5 × 0.3 u (alto 0.2–0.4) | 2 | si 1/poco 2 | bosque (3); sec.: cueva |
| planta_baja | 3 | 0.4 × 0.3 u (alto 0.3–0.4) | 0 | poco 3 | bosque (3); sec.: cueva |
| acantilado | 2 | 8.2 × 3.6 u (alto 3.4–3.8) | 0 | si 2 | ninguno (2) |
| rama | 1 | 0.8 × 0.1 u (alto 0.1–0.1) | 0 | si 1 | bosque (1); sec.: pantano |

Usadas por el juego (12): `bigmushroom_2_1`→seta_reactiva, `bigroots_1`→raices_obstaculo, `bigtree1`→arbol_redondo_2, `bigtree3`→arbol_viejo, `bush1`→arbusto, `bush2`→arbusto_bayas, `grass2`→hierba_crecida, `largefern2`→helecho_ancho, `largefern3`→helechos_cueva, `mushroomsstack_7`→setas_pantano, `shrubleaf2`→planta_hojas, `smallmushroom_3`→seta_amarilla_fina

`no_usar` (2): `cliff1`, `cliff2`

## Islands (98 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| planta_isla | 49 | 0.5 × 0.3 u (alto 0.1–1.3) | 0 | si 18/poco 28/no 3 | ninguno (49); sec.: pantano |
| palmera | 9 | 4.3 × 6.5 u (alto 2.6–10.2) | 1 | si 9 | ninguno (6), pantano (3) |
| roca | 8 | 1.0 × 0.7 u (alto 0.6–0.8) | 0 | si 8 | bosque (8); sec.: cueva |
| agua | 6 | 1.6 × 3.5 u (alto 0.4–5.0) | 0 | si 5/poco 1 | ninguno (6) |
| planta_hoja | 6 | 0.6 × 0.7 u (alto 0.5–0.8) | 0 | si 5/poco 1 | ninguno (6) |
| marino | 6 | 0.1 × 0.0 u (alto 0.0–0.1) | 0 | no 6 | ninguno (6) |
| hierba | 4 | 1.2 × 0.2 u (alto 0.1–0.6) | 0 | si 4 | bosque (3), ninguno (1) |
| arbusto | 3 | 1.7 × 1.4 u (alto 1.0–1.5) | 0 | si 3 | bosque (3) |
| hojarasca | 2 | 2.1 × 0.1 u (alto 0.1–0.1) | 0 | si 2 | ninguno (2) |
| helecho | 2 | 1.1 × 0.4 u (alto 0.4–0.5) | 1 | si 2 | ninguno (2); sec.: pantano |
| acantilado | 2 | 20.8 × 9.2 u (alto 8.7–9.6) | 0 | si 2 | ninguno (2) |
| rama | 1 | 2.1 × 0.2 u (alto 0.2–0.2) | 0 | si 1 | bosque (1) |

Usadas por el juego (2): `ferneil1`→helechos_cueva, `pandanace1`→arbol_manglar

`no_usar` (8): `islandcliff1`, `islandcliff2`, `pearl`, `shell1_down`, `shell1_up`, `shell2`, `starfish1`, `starfish2`

## Jungle (62 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| arbusto | 12 | 0.7 × 0.5 u (alto 0.2–1.8) | 0 | si 10/poco 2 | pantano (9), ninguno (3); sec.: bosque |
| helecho | 11 | 1.0 × 0.4 u (alto 0.2–1.1) | 3 | si 10/poco 1 | pantano (11); sec.: bosque, cueva |
| roca | 7 | 0.6 × 0.5 u (alto 0.5–1.7) | 1 | si 3/poco 4 | pantano (4), ninguno (3); sec.: bosque |
| planta_hoja | 7 | 1.0 × 0.8 u (alto 0.2–1.8) | 2 | si 7 | pantano (7) |
| flor | 6 | 0.3 × 0.3 u (alto 0.2–0.6) | 2 | si 1/poco 4/no 1 | pantano (6) |
| palmera | 6 | 4.2 × 8.6 u (alto 3.6–11.5) | 0 | si 6 | ninguno (6) |
| acantilado | 5 | 2.8 × 1.9 u (alto 1.7–2.6) | 0 | si 5 | pantano (5) |
| arbol | 4 | 8.0 × 12.9 u (alto 9.8–19.5) | 2 | si 4 | pantano (4); sec.: bosque |
| hierba | 3 | 1.6 × 0.2 u (alto 0.2–0.6) | 1 | si 3 | pantano (3); sec.: bosque |
| rama | 1 | 0.8 × 0.1 u (alto 0.1–0.1) | 0 | si 1 | pantano (1); sec.: bosque |

Usadas por el juego (11): `anthurium2`→flor_reactiva, `asplenium2`→helechos_cueva, `bigfern1`→helecho_ancho, `elephant2`→planta_hojas, `grass1`→hierba_crecida, `heliconia2`→flor_heliconia, `jungleboulder_3`→roca_grande, `kapokier1`→arbol_manglar, `kapokier2`→arbol_viejo, `philo2`→planta_hojas, `thinfern1`→planta_agua

## Meadows (68 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| arbol | 18 | 7.0 × 9.0 u (alto 3.9–14.8) | 4 | si 18 | bosque (18) |
| flor | 13 | 0.6 × 0.6 u (alto 0.0–0.7) | 6 | si 7/poco 6 | bosque (13) |
| hierba | 9 | 0.6 × 0.3 u (alto 0.1–0.7) | 1 | si 7/poco 2 | bosque (9) |
| seta | 6 | 0.3 × 0.4 u (alto 0.3–0.6) | 2 | si 2/poco 4 | bosque (6); sec.: pantano |
| roca | 6 | 1.6 × 1.0 u (alto 0.6–1.7) | 1 | si 6 | bosque (6); sec.: cueva |
| cultivo | 4 | 0.7 × 0.7 u (alto 0.6–0.7) | 0 | si 4 | ninguno (4) |
| valla | 3 | 1.6 × 0.7 u (alto 0.7–0.7) | 0 | si 3 | ninguno (3) |
| arbusto | 3 | 1.5 × 1.3 u (alto 1.0–1.7) | 3 | si 3 | bosque (3) |
| conifera | 3 | 1.5 × 5.9 u (alto 2.8–8.4) | 1 | si 3 | bosque (3); sec.: ruinas |
| planta_baja | 1 | 0.5 × 0.1 u (alto 0.1–0.1) | 0 | poco 1 | bosque (1) |
| acantilado | 1 | 6.0 × 6.8 u (alto 6.8–6.8) | 0 | si 1 | bosque (1); sec.: cueva |
| orilla | 1 | 0.4 × 0.7 u (alto 0.7–0.7) | 1 | si 1 | pantano (1); sec.: bosque |

Usadas por el juego (19): `birch3`→arbol_sumicio, `bush1`→arbusto, `bush2`→arbusto_bayas, `bush3`→arbusto_flores, `cypres2`→arbol_sumicio, `daisy`→flores_blancas;margarita_blanca_suelo, `elm1`→arbol_redondo, `flowermeadow3`→flores_colores, `flowermeadow4`→flores_blancas, `grassmeadows3`→hierba_crecida, `lavender`→planta_violeta, `lupin1`→planta_violeta, `lupin2`→flor_reactiva, `mushroom1`→seta_amarilla_alta, `mushroom3`→seta_pradera, `oak1`→arbol_redondo, `oak2`→arbol_redondo_2, `reeds`→planta_agua, `stone4`→roca_musgosa

## Mountains (63 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| conifera | 18 | 2.4 × 7.5 u (alto 3.5–15.7) | 1 | si 18 | bosque (18) |
| roca | 12 | 1.1 × 0.6 u (alto 0.1–1.7) | 2 | si 11/poco 1 | bosque (12); sec.: cueva |
| hierba | 9 | 0.9 × 0.6 u (alto 0.1–0.7) | 1 | si 9 | bosque (9) |
| acantilado | 8 | 15.7 × 17.3 u (alto 8.6–17.3) | 0 | si 8 | ninguno (8) |
| flor | 6 | 0.5 × 0.6 u (alto 0.1–0.6) | 2 | si 2/poco 4 | bosque (6) |
| arbusto | 3 | 1.5 × 1.3 u (alto 1.0–1.7) | 2 | si 3 | bosque (3) |
| cultivo | 2 | 0.6 × 0.7 u (alto 0.6–0.7) | 0 | si 2 | ninguno (2) |
| helecho | 2 | 0.7 × 0.4 u (alto 0.3–0.5) | 2 | si 2 | bosque (2) |
| planta_baja | 1 | 0.5 × 0.1 u (alto 0.1–0.1) | 0 | poco 1 | bosque (1) |
| rama | 1 | 0.8 × 0.1 u (alto 0.1–0.1) | 0 | si 1 | bosque (1) |
| orilla | 1 | 0.4 × 0.7 u (alto 0.7–0.7) | 0 | si 1 | pantano (1); sec.: bosque |

Usadas por el juego (10): `boulder2`→rocas_pequenas, `bush2`→arbusto, `bush3`→arbusto_otono, `daisy`→margarita_amarilla_suelo, `fern1`→helecho, `fern2`→helecho_ancho, `grass3`→hierba_espesa, `lupin2`→planta_violeta, `pine4`→arbol_sumicio, `stone4`→roca_musgosa

`no_usar` (8): `cliff1`, `cliff2`, `cliff3`, `cliff4`, `cliff5`, `cliff6`, `cliff7`, `cliff8`

## Savanna (68 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| escombro | 22 | 0.0 × 0.0 u (alto 0.0–1.3) | 0 | si 6/no 16 | ninguno (16), cueva (6); sec.: ruinas |
| arbol | 16 | 5.3 × 6.4 u (alto 4.1–7.9) | 0 | si 16 | ninguno (16) |
| orilla | 8 | 4.6 × 1.7 u (alto 0.8–2.6) | 0 | si 8 | pantano (8) |
| roca | 6 | 3.5 × 2.1 u (alto 1.9–2.3) | 1 | si 6 | bosque (6) |
| hierba | 5 | 0.4 × 0.2 u (alto 0.1–0.4) | 0 | poco 3/no 2 | ninguno (5) |
| agua | 5 | 0.3 × 0.0 u (alto 0.0–1.7) | 2 | si 2/poco 1/no 2 | pantano (5) |
| arbusto | 3 | 1.7 × 1.4 u (alto 1.0–1.5) | 0 | si 3 | bosque (3) |
| flor | 2 | 0.4 × 0.4 u (alto 0.4–0.4) | 0 | poco 2 | pantano (2) |
| fondo | 1 | 104.0 × 16.7 u (alto 16.7–16.7) | 0 | si 1 | ninguno (1) |

Usadas por el juego (3): `bigboulders_0`→roca_grande, `lillypads1`→nenufar_flor, `watermoss`→musgo_suelo;planta_agua

`no_usar` (17): `bouldersavanna_1`, `bouldersavanna_2`, `bouldersavanna_3`, `bouldersavanna_4`, `bouldersavanna_5`, `bouldersavanna_6`, `kilimanjaro`, `rocksavanna_1`, `rocksavanna_10`, `rocksavanna_2`, `rocksavanna_3`, `rocksavanna_4`, `rocksavanna_5`, `rocksavanna_6`, `rocksavanna_7`, `rocksavanna_8`, `rocksavanna_9`

## Stylescape: Ruins (199 piezas)

| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |
|---|---:|---|---:|---|---|
| suelo | 29 | 2.3 × 0.1 u (alto 0.0–0.1) | 3 | si 29 | ruinas (29) |
| muro_grueso | 29 | 1.2 × 1.7 u (alto 0.9–1.7) | 2 | si 29 | ruinas (29) |
| escalera | 20 | 1.8 × 1.0 u (alto 0.0–2.1) | 0 | si 17/poco 3 | ruinas (20) |
| techo_suelo | 17 | 1.2 × 0.1 u (alto 0.1–0.1) | 0 | si 15/poco 2 | ruinas (17) |
| muro_bajo | 15 | 1.1 × 0.9 u (alto 0.9–1.7) | 8 | si 15 | ruinas (15) |
| cornisa | 14 | 1.1 × 0.2 u (alto 0.2–0.3) | 2 | si 12/poco 2 | ruinas (14) |
| muro_arco | 12 | 1.2 × 0.7 u (alto 0.7–0.7) | 0 | si 12 | ruinas (12) |
| escombro | 10 | 0.4 × 0.7 u (alto 0.2–1.7) | 5 | si 6/poco 4 | ruinas (10); sec.: bosque, cueva |
| baranda | 9 | 1.1 × 0.3 u (alto 0.1–0.3) | 0 | si 7/poco 2 | ruinas (9) |
| pilar | 8 | 0.7 × 1.7 u (alto 0.3–1.8) | 2 | si 7/poco 1 | ruinas (8) |
| muro_danado | 8 | 1.5 × 1.7 u (alto 1.7–1.7) | 5 | si 8 | ruinas (8) |
| puerta_ventana | 6 | 1.4 × 1.6 u (alto 1.0–1.7) | 0 | si 6 | ruinas (6) |
| hiedra | 6 | 0.8 × 0.6 u (alto 0.0–1.2) | 5 | si 5/poco 1 | ruinas (6); sec.: bosque, pantano |
| muro | 6 | 1.4 × 1.7 u (alto 1.7–1.7) | 3 | si 6 | ruinas (6) |
| viga | 5 | 1.1 × 0.1 u (alto 0.1–1.7) | 0 | si 5 | ruinas (5) |
| muro_ventana | 2 | 2.3 × 1.7 u (alto 1.7–1.7) | 2 | si 2 | ruinas (2) |
| arco | 1 | 3.6 × 1.3 u (alto 1.3–1.3) | 0 | si 1 | ruinas (1) |
| caja | 1 | 0.5 × 0.5 u (alto 0.5–0.5) | 1 | poco 1 | ruinas (1); sec.: cueva |
| sombra | 1 | 0.0 × 0.0 u (alto 0.0–0.0) | 1 | no 1 | ruinas (1) |

Usadas por el juego (39): `ss_crate_01`→paredes_stylescape, `ss_floor_4x4_topface_01`→paredes_stylescape, `ss_floor_4x4_topface_02`→paredes_stylescape, `ss_floor_4x4_topface_03`→paredes_stylescape, `ss_hangingivy_01`→paredes_stylescape, `ss_hangingivy_02`→paredes_stylescape, `ss_hangingivy_03`→paredes_stylescape, `ss_hangingivy_05`→paredes_stylescape, `ss_hangingivy_06`→paredes_stylescape, `ss_pillar_03`→paredes_stylescape, `ss_pillar_04`→paredes_stylescape, `ss_rubble_01`→paredes_stylescape, `ss_rubble_02`→paredes_stylescape, `ss_sombra_base`→paredes_stylescape, `ss_stone_01`→paredes_stylescape, `ss_stone_02`→paredes_stylescape, `ss_stone_03`→paredes_stylescape, `ss_wall_01_corner`→paredes_stylescape, `ss_wall_02`→paredes_stylescape, `ss_wall_04`→paredes_stylescape, `ss_wall_dmg_02`→paredes_stylescape, `ss_wall_dmg_02_half_01`→paredes_stylescape, `ss_wall_dmg_03`→paredes_stylescape, `ss_wall_dmg_03_alt`→paredes_stylescape, `ss_wall_dmg_03_half_01`→paredes_stylescape, `ss_wall_dmg_04`→paredes_stylescape, `ss_wall_dmg_04_alt`→paredes_stylescape, `ss_wall_dmg_04_half_02`→paredes_stylescape, `ss_wall_half_02`→paredes_stylescape, `ss_wall_half_04`→paredes_stylescape, `ss_wall_half_corner`→paredes_stylescape, `ss_wall_ledge_thick_04`→paredes_stylescape, `ss_wall_ledgedetail_04`→paredes_stylescape, `ss_wall_loopholes_01`→paredes_stylescape, `ss_wall_loopholes_half`→paredes_stylescape, `ss_wall_thick_04`→paredes_stylescape, `ss_wall_thick_half_04`→paredes_stylescape, `ss_wall_windows_01`→paredes_stylescape, `ss_wall_windows_half`→paredes_stylescape

`no_usar` (1): `ss_sombra_base`

## Qué encaja en cada bioma (criterio)

- **Bosque**: Fantasy Forest, Meadows y Mountains casi enteros (árboles, arbustos, helechos, setas, rocas musgosas, flores de claro). Las coníferas de Mountains valen para el pinar; el ciprés y el olmo, para el borde.
- **Pantano**: Jungle (kapokier, helechos, filodendros, rocas de jungla), y de Savanna solo lo húmedo (hierba mojada, nenúfares, musgo de agua, orillas); lotos de Asian Valley, juncos de Meadows/Mountains, pandanáceas de Islands.
- **Cueva**: ninguna pieza es de cueva; valen como secundarias helechos, setas, rocas musgosas y escombro.
- **Ruinas**: Stylescape entero; hiedras como adorno también para bosque y pantano.
- **Ninguno**: Asian Valley casi entero (huerto, arroz, bambú, colinas), Islands (coco, algas, conchas, plantas de playa), sabana seca (acacia, baobab, hierba seca), cultivos y vallas de Meadows/Mountains, plataneros.

## Lo que hay en Unreal y no ha llegado a `arte/`

Comprobado leyendo los nombres de los `.uasset` de `Content` (sin abrir Unreal) contra las carpetas `*_export` y las piezas de `arte/`.

- Mallas estáticas (`SM_*`) en Content: AsianValley 118, FantasyForest 102, Islands 98, Jungle 62, Meadows 71, Mountains 65, Savanna 68; Stylescape 200 (+ 9 `FoliageTypes`, que son ajustes de follaje y no mallas).
- Exportadas: Pure Nature 579, Stylescape 200. Piezas en `arte/`: 579 `pn_*`, 199 `ss_*`.
- **Mallas de Content sin exportar: 5** → PureNature_Meadows SM_Mountain1, PureNature_Meadows SM_Mountain2, PureNature_Meadows SM_Mountain3, PureNature_Mountains SM_Mountain1, PureNature_Mountains SM_Mountain2. Son los montes de fondo `Models/Mountains` de Meadows y Mountains; el exportador (`tools/ue_exportar_pure_nature.py`, constante `FUERA`) los deja fuera a propósito, junto con nubes, efectos y niebla. No son decorado de sala.
- Stylescape: mallas sin exportar: ninguna.
- Exportadas sin pieza `.tscn`: Pure Nature ninguna; Stylescape SM_Circle_01, SM_Slope (`SM_Slope` y `SM_Circle_01` son a propósito: `EXCLUIDAS` en `paredes_stylescape.gd`, el plano inclinado y el círculo de muestrario de Unreal).
- `Content/MagicSymbols` tiene solo materiales propios (21 `MI_SinTerreno_*`, variantes sin terreno de materiales de Pure Nature): no son mallas. `Collections` y `Developers` están vacías.
- No comprobado: texturas y materiales uno a uno (solo mallas), ni que cada FBX importe bien en Godot más allá de que existe su pieza.

## Piezas con tamaño sospechoso

- **Escala rota (16)**: `bouldersavanna_1`, `bouldersavanna_2`, `bouldersavanna_3`, `bouldersavanna_4`, `bouldersavanna_5`, `bouldersavanna_6`, `rocksavanna_1`, `rocksavanna_10`, `rocksavanna_2`, `rocksavanna_3`, `rocksavanna_4`, `rocksavanna_5`, `rocksavanna_6`, `rocksavanna_7`, `rocksavanna_8`, `rocksavanna_9`. Miden menos de 0,2 u (el resto de rocas de la sabana miden 2–5 u): el FBX se importó en otra escala.
- **Telones enormes (9)**: `pn_asianvalley_asianhill_0` (48 u), `pn_asianvalley_asianhill_1` (52 u), `pn_asianvalley_asianhill_2` (46 u), `pn_asianvalley_asianhill_3` (48 u), `pn_asianvalley_asianhill_4` (40 u), `pn_asianvalley_asianhill_5` (38 u), `pn_mountains_cliff1` (37 u), `pn_mountains_cliff2` (31 u), `pn_savanna_kilimanjaro` (104 u).

