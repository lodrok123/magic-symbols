# Presupuesto de triángulos y texturas

23/10/2026 · bloque 4 de la revisión EoW. Medido con `herramientas/medir_rendimiento.gd` (necesita ventana) en un portátil con
**Intel UHD Graphics 620**, Forward+, ventana de 1152 × 648, sin vsync y con el jugador quieto donde empieza. Los informes completos están en
`docs/capturas/bloque4_eow/`. Los FPS de este portátil varían bastante de una tirada a otra (se calienta): para comparar, el dato fiable son
los **triángulos dibujados por fotograma**.

## Lo que pesa

| escena | triángulos en la escena | dibujados por fotograma | FPS |
|---|---|---|---|
| Bosque (antes) | 4,47 M | **4,35 M** | 12,0 |
| Bosque (sombra reducida) | 5,24 M¹ | **1,71 M** | 16,1 |
| Bosque 01 (antes) | 6,65 M | **3,93 M** | 6,1 |
| Bosque 01 (sombra reducida) | 7,89 M¹ | **1,62 M** | 9,8 |

¹ Sube porque se añaden las copias reducidas que solo proyectan sombra; lo que importa es lo dibujado.

**El cuello de botella era la SOMBRA del sol, no la cámara.** Diagnóstico en el Bosque (antes del arreglo):

| caso | triángulos dibujados | FPS |
|---|---|---|
| tal cual | 4,35 M | 12,2 |
| sin sombra del sol | 0,55 M | 19,4 |
| sin árboles ni pinos | 0,76 M | 19,7 |
| árboles sin proyectar sombra | 0,94 M | 16,3 |

La cámara solo dibuja lo que ve (≈ 0,55 M), pero la pasada de sombra dibujaba **todos los árboles del mapa**. Y los árboles son el 61 % de
la escena (Bosque) y el 68 % (Bosque 01): `arbol_redondo` tiene 12 000 triángulos × 227 copias. EoW usa ~850 por árbol.

Bajar la escala de render ayuda poco: con 0,5 el Bosque pasaba de 12 a 18 FPS. Es geometría, no píxeles. Aun así hay un coste de
píxeles (hierba, agua, SSAO) que se queda en ≈ 19 FPS sin sombras en esta GPU.

## Lo que se ha hecho (bloque 4)

- **Sombra reducida** (`MallaReducida3D`, `prueba_test2.gd` → `SOMBRA_REDUCIDA`, export `sombra_reducida`): árboles y pinos se dibujan
  igual pero NO proyectan sombra; la proyecta una copia de ≈ 1/8 de triángulos (árbol 12 000 → 3 000, pino 12 000 → 1 500) que no se ve.
  Se calcula en el juego (≈ 35 ms por pieza, una vez), sin assets nuevos: los mismos vértices soldados por posición y los niveles de
  detalle del simplificador de Godot. **No se nota**: la misma toma con una y otra sombra difiere 0,0125 de media, y parte es el viento
  (`docs/capturas/bloque4_eow/PruebaBosque_sombra_*.png`).
- **Escala de render** (export `escala_render`, 1,0 de serie): por debajo de 1 reescala con FSR; el HUD no se toca. 0,75 da ≈ +20 % de FPS.

## Lo que falta decidir (Pablo)

1. **Árboles**: siguen siendo 12 000 triángulos en la imagen. Con la cámara fija y lejos, un árbol de 1 500–3 000 no se distinguiría.
   La misma `MallaReducida3D` podría hacer la versión que se VE (habría que conservar UV y normales: hoy la reducción las descarta), o
   pedir a Meshy/Blender una versión decimada. Es lo siguiente que más rinde.
2. **Personajes** (EoW: protagonista 9–11 k, enemigo ~1,8 k):

   | id | triángulos | huesos |
   |---|---|---|
   | woodland_wanderer (jugadora) | 116 924 | 32 |
   | goblin_warrior_chibi | 42 039 | 28 |
   | goblin_archer_chibi | 41 249 | 28 |
   | goblin_espadachin | 40 227 | 28 |
   | ranger_human, bookseller_chibi, lince, alchemist_elf | ≈ 31 000 | 28–66 |
   | elemental_bosque | 30 384 | 28 |

   La jugadora sola pesa como 10 árboles. Decimar a 5–10 k (los enemigos a 3–5 k) sin tocar el rig es un trabajo de Blender.
3. **Texturas**: el decorado ya va a 512 casi todo (82 de 512, 38 de 1024, 31 de 2048). Hay 69 importadas sin comprimir
   (`compress/mode=0`), todas pequeñas y de los efectos de elemento (terrones, cascotes, hielo, algas, rocas de río): pasarlas a VRAM
   comprimida ahorraría poco. VRAM de texturas en el Bosque: ≈ 333 MB.
