# Assets faltantes o malos — con presupuesto de polígonos (5 de octubre de 2026)

Para Pablo al generar en Meshy. Los presupuestos salen de **cómo se ve cada pieza en pantalla**, no del gusto:
con la cámara de `PruebaTest2` (`size = 6`, ~8 casillas de ancho a 1080p) una casilla mide ~135 px y una
unidad ~59 px; nada por debajo de 2 px se ve, así que un objeto de 0,5 u (30 px) no necesita más de 300
triángulos y un árbol de 4 u (240 px) rinde a 2 000–3 000. Referencia de lo que ya funciona en la maqueta:
`pino` 1 038, `arbol_redondo` 2 006, `roca_grande` 814, `barril` 278, `puesto` 413 (se veía pobre por
la **textura compartida**, no por los polígonos). Meshy exporta por defecto 10–30 k por pieza: hay que
fijar el **target poly count** al refinar (o remallar al exportar), si no cada prop pesa como un personaje.

Columna *tris*: objetivo (mín–máx). Columna *textura*: tamaño del atlas propio de la pieza.

## 1. Decorado (bloquea la prueba)

| id | problema | qué generar | alto en pantalla | tris | textura |
|---|---|---|---|---|---|
| `cartel` | poste sin tablón | poste + tabla rectangular, sin texto | 1,3 u ≈ 75 px | 300–600 | 512 |
| `baldosa_guardado` | losa gris ilegible | losa cuadrada de piedra, runa grabada que brilla (celeste), borde biselado | 1 casilla plana | 150–300 | 512 (la runa necesita nitidez: 1024 si sale borrosa) |
| `pasadero` | placa plana beige | piedra pasadera redondeada, gris, musgo en el borde | 1 casilla, 0,15 u alto | 200–400 | 512 |
| `seto_seco` | plano, "ciempiés" en fila | seto compacto redondeado, ramas secas; hoy lo sustituye `arbusto_otono` (9 587 tris: **demasiado**, se repite 20 veces) | 1,0 u ≈ 60 px | 800–1 500 | 1024 |
| `remolino_viento` (vfx) | azul; el viento es verde | mismo diseño en verde `#8FD46A` | sprite 256² | — | 256 |

## 2. Decorado (mejora)

| id | problema | qué generar | alto | tris | textura |
|---|---|---|---|---|---|
| `arbusto` | manchas salmón | arbusto solo verde, dos tonos | 1,0 u | 500–900 | 512 |
| `arbusto_flores` | flores = parches rosas | 5–7 flores pequeñas blancas/amarillas | 1,0 u | 600–1 000 | 1024 |
| `tocon` | corte rosado | anillos marrón claro | 0,6 u | 200–400 | 512 |
| `matas` | rocas de cristal | retirar (las pone `Hierba3D`) o mata verde de 3–4 manojos | 0,45 u | 150–300 | 512 |
| `arbol_redondo_2` / `pino_2` (ya en `arboles_2`) | bien | nada; referencia de presupuesto: 3 701 / 1 780 | 4,2 / 4,6 u | 2 000–3 500 | 1024 |
| `oro` | no existe (monedas por código) | pila de 3–4 monedas gordas | 0,3 u | 100–200 | 256 |
| empujables `tierra` / `hielo` | `caja_cristal` no vale | nada: cubos con `cuerpo.png` / hielo (Pipeline) | 1 casilla | 12 | — |
| `puerta_pruebas` (norte del Test 2) | hoy `arco_ruina` | arco con 6 huecos para runas que se encienden (estados por material) | 3,4 u | 2 000–3 000 | 1024 |
| `cartel_camara_<elemento>` ×6 | rótulos de texto | el `cartel` nuevo + 6 texturas de tabla con el símbolo del elemento (mismo modelo, 6 materiales) | 1,3 u | 0 extra | 6 × 512 |
| `plate_trial_<elemento>` ×6 / `placa_peso` | óvalo de código; `placa_peso` bien | la `baldosa_guardado` nueva con otra runa por material | 1 casilla | 0 extra | 7 × 512 |

## 3. VFX (mejora)

| id | problema | qué generar | tris | textura |
|---|---|---|---|---|
| `burbuja`, `gota`, `hoja`, `brasa`, `petalo` | satélites (dobles al emitir) | `single object, no extra pieces` | — | 256 |
| `llama` | tocaba el borde | usar `llama_tira8` (bien) o regenerar con margen | — | 256 / 2048×256 |
| copos de congelación, chispa en agua, polvo de tierra, humo de vela, hojas al recolectar (`ASSETS_PENDIENTES` §5) | ya cubiertos por `copo`, `chispa_electrica`, `polvo`, `humo`, `hoja` | nada | — | — |

## 4. Personajes

| id | problema | qué generar | alto | tris | textura |
|---|---|---|---|---|---|
| `goblin_archer_chibi` | no existe; el arquero es el realista | según el prompt del 5/10 (capucha marrón oscuro, manos vacías; arco aparte). Clips: `idle`, `walk`, `walk_back`, `run`, `archery_shot`, `aim`, `alert`, `hit_reaction`, `electrocution_reaction`, `dead` (+ `dodge`) | 0,85 u ≈ 50 px (75 px en el 2D) | 8 000–12 000 | 2048 (1024 vale a este tamaño) |
| `alchemist_chibi` | hoy guardabosques teñido | elfo, abrigo rojo a media pierna, camiseta negra, guantes blancos; pelo distinto de la elfa. Clips: `idle`, `talk_with_left_hand_raised`, `walk` | 1,0 u | 8 000–12 000 | 2048 |
| `goblin_warrior_chibi` | pelo tapa la cara, piel pálida | regenerar solo si molesta a 50–75 px: pelo corto/recogido, piel verde saturada | 0,85 u | 8 000–12 000 | 2048 |
| `chibi_elf` | dos looks (master dorado/verde vs. pastel blanco/azul) | **decidido: el master**; actualizar `referencia_personaje.png` | 1,0 u | — (ya hecho) | — |
| `bookseller_chibi` | bien | nada | 0,95 u | — | — |
| arco del arquero (`arco` en `equipo\`) | no existe | arco corto de madera con cuerda, mango en el origen, hacia +Y, ~0,5 u | 0,5 u | 300–600 | 512 |

## 5. Suelo y bloques

| id | problema | qué hacer | tris | textura |
|---|---|---|---|---|
| `suelo_meshy\*` | claras | **no regenerar**; ya oscurecidas ×0,78 en la maqueta | — | 1024 (bien) |
| `hierba_matojos` | bien | nada | — | 512 |
| hielo (3 estados) para el agua congelada | solo en 2D (`water_frozen_*`) | en 3D: material de hielo sobre el bloque de agua (Pipeline, sin Meshy); si se quiere textura: `hielo_arriba.png` 1024 sin costuras, mismo estilo que `water_arriba` | — | 1024 |

## 6. Reglas para que salgan bien (resumen para Meshy)

1. **Una pieza por generación**, con su `referencias/<id>.png` como imagen y el [ESTILO] de `PROMPTS.md`.
2. **Target poly count** al refinar: props 300–1 500, árboles/arcos 2 000–3 500, personajes 8–12 k.
   Nunca aceptar los 20–30 k por defecto: con 157 lotes de decorado el presupuesto se va en seguida.
3. **Textura propia** (no lámina): 512 para lo pequeño, 1024 para lo que se ve grande, 2048 solo personajes.
4. Al bajar: `poc_25d\meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` → hoja de contacto con la chibi
   (`CatalogoAssets`, tecla H) antes de darlo por bueno. QA mira esa hoja, no el visor de Meshy.
5. Pedir siempre `no outline, no black lines, no base, no ground plane, single object`.
