# Propuesta · assets de los biomas prototipo y sus packs GLB

7/11/2026 · para que Pablo la valide. Sale de leer el arte que ya hay (`arte/piezas/` con 269 piezas, láminas de `arte/meshy/`, rocas LeLu, pack
Provencal), la guía (`docs/ARTE.md` §1, §2 y §10) y las tablas de `nucleo/datos/`. La lista completa, una fila por asset, está en
`docs/assets_biomas.tsv` y en la hoja **Assets_biomas** de `docs/BD_INTERACTUABLES.xlsx`; el inventario de lo que existe, en la hoja **Assets**.

## Reglas que salen de la guía y de lo que se ha decidido

- **Estilo**: diorama chibi pastel, formas redondeadas y gruesas, pintado a mano, sin contorno ni biseles a 45°. Se pega el bloque
  `[ESTILO]` de `arte/meshy/PROMPTS_CUEVA.md` al final de cada prompt de la tabla.
- **Color**: cada pieza nueva se pide con los colores de la paleta del bioma (`ARTE.md` §2); al integrarla se ajusta a `Paleta3D` como se
  hizo con Provencal (color de la paleta × detalle en gris del albedo), para que todo viva bajo la misma luz.
- **Rejilla**: casilla de 2,3 u, un nivel de altura = 1,04 u, la jugadora mide ~1 u. Origen en el centro de la base, **frente hacia +Z**
  (la cámara está fija al norte desde el 4/11). Lo modular (paredes, pasarelas, raíles) ocupa una casilla exacta.
- **Nada de brillo pintado**: cristales, setas luminosas, runas y lava se piden apagados; la emisión la pone el motor con una máscara, y la luz,
  `OmniLight3D` + `LuzTitila3D`. Es la clave de la cueva.
- **Triángulos**: el detalle manda. Piezas únicas y edificios con malla completa (hasta ~12 000 los hitos); lo que se repite cientos de veces
  (árboles, hierba, rocas de relleno) con detalle alto pero con la sombra reducida que ya tiene el motor (`MallaReducida3D`), porque lo que
  medimos que pesa es su sombra.

## Por bioma

| bioma | identidad (paleta · luz · estado del mundo) | reutiliza | consigue | qué lo hace distinto |
|---|---|---|---|---|
| **Desértico** | `#D29850`… arena · luz nueva `desierto` (sol alto, sombra corta) · `calor` | 19 (rocas Provencal teñidas de arenisca, jarrones, ánforas, carro, arco y columna de ruina, brasero) | 19 | cactus (3), palmeras (2), dunas, esqueleto de bestia como hito, arco y pilares de arenisca, pozo y orilla de oasis, tienda nómada |
| **Pantano** · *siguiente mapa jugable* | `#346A60` `#8CAF80` `#887F69` · luz nueva `pantano` con bruma baja · `humedad`, `veneno` | 20 (sauce, nenúfares, juncos, troncos, raíces, musgo, telaraña, enredadera, lámina de orilla, nube de veneno) | 24 | árboles propios (manglar, ciprés calvo, árbol muerto), **pasarelas modulares** (recta, codo, rota, pilote), cabaña-palafito, muelle, plantas reactivas (planta carnívora), setas luminosas, caldero, farolillos guía, puente de cuerda que arde |
| **Rocoso** | grises fríos con liquen ocre · luz nueva `rocoso` · `vendaval` | 15 (rocas LeLu y Provencal, muro agrietado, pino, gólem) | 17 | **kit de risco modular** (pared, esquinas, escalón de un nivel), cornisa, roca en equilibrio y desprendimiento (puzle), puente colgante, pino achaparrado por el viento, cairn, banderas que enseñan el viento, vagoneta y raíles |
| **Ruinas** · *mazmorras de glifos* | piedra beige-gris, musgo · luz `ruinas` / `cueva_ruinas` (existen) | 26 (todo el kit rúnico y de pulso, puertas, cofres, láminas de puzle, antorchas, trampas) | 26 | **kit de mazmorra modular** (muro, esquinas, roto, hornacina, portón con hoja que baja, escalinata), pedestal del glifo, mosaico, puente roto, y **un tema por glifo** (ᛇ dianas y arquero · ○ guardián con escudo y cúpula · ᚢ espejo inclinado · ᚠ estatuas gemelas · ᚷ gong · ᛉ reloj de arena · ⊥ bloques escalonados · ᛁ pasillo de runa larga) |
| **Cueva** · *la luz* | `#465E86` `#6583B5` `#232A44` · luces `cueva*` (existen 5) · `oscuridad`, `resonancia` | 18 (kit de paredes, estalagmitas, cristales y geoda, braseros, farolillo, musgo, helechos, vetas, cascada) | 15 | **fuentes de luz con masa**: racimos de cristal S/L y de pared, hongo gigante y de pared, lámpara de minero, velas, **tragaluz** (haz de luz desde el techo), charca con algas luminosas, raíces con bulbos; y las 3 piezas pendientes desde la Cueva (`mineral_veta`, `setas_cueva`, `cristal_cargado`) |
| **Común** | — | — | 4 texturas de suelo + 3 presets de luz | `arena_arriba`, `barro_arriba`, `roca_montana_arriba`, `losas_mazmorra_arriba`; filas `desierto`, `pantano`, `rocoso` en `LuzZona3D.ZONAS` |

**Prioridad 1** (lo mínimo para montar un prototipo jugable del bioma): desértico 6 · pantano 12 · rocoso 9 · ruinas 12 · cueva 8, más las 4
texturas comunes.

## Los packs GLB

Un GLB por bioma, `arte/meshy/packs/pack_<bioma>.glb`, con **un nodo por pieza llamado como su id** (la convención de las láminas que ya lee
`Pieza3D.BIBLIOTECAS`): `pack_desertico`, `pack_pantano`, `pack_rocoso`, `pack_ruinas`, `pack_cueva` y `pack_comun` (texturas y luz, no GLB).

1. Cada pieza «conseguir» se genera **sola** en Meshy (una pieza por generación; nunca en lámina) con su prompt + `[ESTILO]` y su
   `tris_objetivo`, y se deja en `meshy\entrada\<id>.glb`.
2. Un script junta las piezas del bioma en su pack (base en el origen, frente a +Z, a la medida de la columna `medida`), y registra la
   biblioteca en `Pieza3D` y las medidas en `MEDIDA` / `MEDIDA_ANCHO`.
3. Las «reutilizar» no se copian al pack: el pack las **referencia** (el nivel prototipo las coloca por id como ya hace la maqueta). Las
   «adaptar» son las mismas piezas con otro color en `tabla_provencal.gd` o un retinte en `Paleta3D.PIEZAS`.
4. Un nivel de muestra por bioma, como `PruebaProvencal`, con su luz y su suelo, para revisar el pack en el juego antes de diseñar el nivel.

## Lo que necesito que decidas

- **Pantano primero**: es el siguiente mapa jugable. Propongo empezar por sus 12 piezas de prioridad 1 y su luz.
- **Temas de las mazmorras**: he propuesto un tema por glifo de los que aún no se ganan en cofre. Si el orden de glifos por mazmorra ya está
  decidido, lo ajusto a ese orden.
- **Desierto y rocoso** tienen menos piezas nuevas porque reutilizan mucha roca: si quieres que se distingan más del bosque, añado una tanda 2.
