# Albedos EoW: medidas antes / después (22/10, Pipeline)

Objetivo (PLAN_EOW_VISUAL §1 punto 2 y pendiente `OSCURECER_SUELO` de ARTE.md §10): igualar contraste y valor de los albedos de la hierba, el suelo y las piezas de Meshy,
en los SHADERS (las imágenes no se tocan). Constantes por familia en `presentacion/albedos_3d.gd`; interruptor `albedos_eow` (export de la maqueta y de `Hierba3D`).

Luminancia = Rec.709 sobre el nivel sRGB final (0-255). «Rango» = percentil 95 − percentil 5 (lo que el plan llama «el valor varía 25–45 niveles»).
Herramientas: `herramientas/medir_albedos.gd` (por textura, headless), `herramientas/medir_captura_albedos.py` (por captura), `herramientas/captura_albedos.gd` (capturas con ventana).
Datos crudos: `antes.tsv`, `despues.tsv`, `frames.md`.

## 1. Por textura (lo que el shader deja en el albedo, ya con `OSCURECER_SUELO` = 0,78 en el suelo, la hierba y los bloques)

| Familia / textura | usos en Bosque 01 | ANTES media | ANTES desv | ANTES rango | DESPUÉS media | DESPUÉS desv | DESPUÉS rango | K | VALOR |
|---|---|---|---|---|---|---|---|---|---|
| suelo · hierba (`hierba_arriba`) | capa del suelo | 155,1 | 7,6 | 24,5 | 147,6 | 9,1 | 29,4 | 1,25 | 0,90 |
| suelo · camino (`path_arriba`) | capa del suelo | 194,6 | 4,4 | 12,9 | 180,8 | 6,8 | 19,5 | 1,60 | 0,85 |
| suelo · tierra (`tierra_arriba`) | capa del suelo | 84,0 | 10,2 | 34,1 | 88,8 | 10,7 | 35,8 | 1,00 | 1,12 |
| suelo · piedra (`losas_piedra`) | capa del suelo | 150,1 | 18,8 | 66,7 | 146,1 | 11,0 | 39,5 | 0,65 | 0,93 |
| hierba · tarjetas (`hierba_matojos`) | Hierba3D | 150,3 | 31,5 | 101,3 | 146,2 | 17,1 | 54,9 | 0,60 | 0,90 |
| bloque triplanar · flanco (`cuerpo`) | 1498 bloques | 140,3 | 14,0 | 42,9 | 147,8 | 14,7 | 45,0 | solo valor | 1,12 |
| bloque triplanar · piedra (`stone_arriba`) | 151 | 150,1 | 18,8 | 66,7 | 146,1 | 11,0 | 39,5 | solo valor | 0,93 (la tabla del tool simula también K; el bloque solo lleva el valor) |
| **piezas de Meshy (media ponderada por usos, 612 instancias)** | 612 | **127,6** | **28,8** | **91,4** | **127,0** | **14,8** | **46,3** | 0,55 | 0,92 (+ saturación 1,08) |

Piezas más repetidas (media / desv / rango, antes → después):

| Textura | usos | antes media | antes desv | antes rango | después media | después desv | después rango |
|---|---|---|---|---|---|---|---|
| meshy/arboles_2 (copas) | 218 | 129,1 | 33,7 | 98,3 | 129,9 | 16,9 | 48,4 |
| piezas/pino | 89 | 120,2 | 23,3 | 79,7 | 118,3 | 12,4 | 42,2 |
| meshy/bosque (flora) | 49 | 132,2 | 36,1 | 121,1 | 134,4 | 17,8 | 60,0 |
| piezas/arbusto_leafy_sphere | 38 | 159,1 | 26,9 | 86,1 | 155,5 | 14,4 | 45,5 |
| piezas/arbusto_otono | 33 | 126,2 | 18,6 | 61,4 | 123,1 | 9,8 | 32,1 |
| piezas/roca_musgosa | 29 | 117,5 | 23,6 | 74,5 | 116,1 | 12,1 | 37,3 |
| piezas/helecho | 28 | 132,0 | 26,8 | 93,9 | 129,7 | 14,2 | 49,1 |
| piezas/tronco_musgoso | 20 | 98,2 | 24,1 | 81,3 | 97,4 | 12,2 | 40,1 |

Lectura: antes, las piezas llevaban cuatro veces el contraste del suelo y la hierba (desv 28,8 contra 4–10; rango 91 contra 13–35) y las losas y las tarjetas de hierba
también se salían (67 y 101). El camino era casi una lámina (rango 13) y la más clara (195). Después: todas las familias entre rango 20 y 55 (piezas 46, losas 40, tarjetas 55, hierba 29,
camino 20, tierra 36), y la media de hierba, losas, flanco y camino entre 147 y 181 (el camino sigue siendo lo más claro a propósito: es el camino).
Los valores de la tabla NO incluyen el tinte de `Paleta3D.PIEZAS` ni el color de vértice (oclusión) de las piezas, que se multiplican después.

## 2. En pantalla (captura con ventana, cámara del juego y de cerca)

Clasificación por tono HSV (heurística: al cambiar el color de una familia algunos píxeles cambian de clase, así que las medias por familia son aproximadas; la fila «todo» es exacta).
Pares antes → después. «todo» excluye el borde azul del vacío.

| Vista | todo: media | todo: rango | hierba: media | copas: media | hierba−copas | arena: media / p95 | tierra: media |
|---|---|---|---|---|---|---|---|
| bosque · cámara del juego | 180,5 → 177,2 | 118 → 105 | 180 → 193 | 203 → 181 | −22 → +11 | 230 / 246 → 226 / 243 | 130 → 140 |
| bosque · claro (zoom 10) | 189,6 → 181,3 | 140 → 129 | 200 → 195 | 211 → 200 | −11 → −6 | 225 / 239 → 219 / 232 | 118 → 123 |
| bosque · árboles (zoom 7) | 201,5 → 190,5 | 91 → 77 | 198 → 192 | 209 → 193 | −10 → −1 | — | 126 → 138 |
| lab sala 4 | 184,5 → 179,1 | 124 → 113 | 182 → 188 | 190 → 175 | −8 → +13 | 229 / 242 → 223 / 236 | 133 → 150 |
| lab sala 4 de cerca | 179,6 → 176,1 | 136 → 122 | 163 → 184 | 189 → 169 | −25 → +15 | 227 / 242 → 221 / 236 | 136 → 147 |

Lo que miden: el rango global del fotograma baja 8–14 niveles, la arena deja de rozar el blanco (p95 246 → 243 y media −5), las copas pasan de más claras que la hierba a casi iguales
(o algo más oscuras: en la cámara del juego y el lab el signo se invierte, de −22 a +11 y de −25 a +15) y la tierra sube 5–15 niveles.

## 3. Constantes (presentacion/albedos_3d.gd)

`HIERBA_K 1,25 · HIERBA_VALOR 0,90 · BRIZNA_K 1,0 · TARJETA_K 0,60 · CAMINO_K 1,60 · CAMINO_VALOR 0,85 · TIERRA_K 1,0 · TIERRA_VALOR 1,12 · PIEDRA_K 0,65 · PIEDRA_VALOR 0,93 ·
PIEZAS_K 0,55 · PIEZAS_VALOR 0,92 · PIEZAS_SAT 1,08 · MIP_MEDIA 12`. Fórmula en cada shader: `c' = (media + (c − media) · K) · VALOR`, con `media` = mip alto de la propia textura
(en las tarjetas, la media lineal del atlas por alfa, calculada al crear el material). `OSCURECER_SUELO` no se ha tocado: 0,78 × 0,90 = 0,70 (hierba) y 0,78 × 0,85 = 0,66 (camino) es el 0,64–0,70 que pedía ARTE.md §10.

Descartado en el camino: `PIEZAS_VALOR 0,88` sin saturación (copas caqui y pinos grises, «sucios») y `PIEZAS_SAT 1,3` con `VALOR 0,95` (copas amarillo ácido).
