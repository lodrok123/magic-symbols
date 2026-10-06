# Plan — estética pastel y migración a 2D (octubre 2026)

Sale de las pruebas de `poc_25d\` (5 de octubre). Lo que convenció: **la chibi sobre bloques de color pastel con
luz y sombra suaves y la cámara casi cenital (20° respecto a la vertical, de frente)**. Kenney es demasiado
low poly para ese acabado.

## Qué cambia respecto a los planes anteriores

Esto **cierra los experimentos** de `EXPERIMENTOS_ESTILO.md` y **cambia la dirección** de
`PLAN_HOMOGENEIZAR_ARTE.md`:

- Los dos documentos daban por objetivo **la guía** (`guia_arte.png`: fantasía pintada, oscura, contorno suave).
  La prueba de hoy elige otra cosa: **mundo chibi pastel, luminoso y de volumen suave**, con la chibi de
  `referencia_personaje.png` como protagonista (E1-b ya está hecho: es `chibi_test`).
- Del entorno gana la idea de **E2 / E2'** (entorno en 3D con la misma luz que el personaje), pero con paleta
  pastel y sin contorno.
- Consecuencias que hay que asumir:
  - `ARTE.md` §1–§2 (paleta oscura del bosque, V 0,35–0,65) y §6 se reescriben con la paleta pastel. **Es
    decisión de Pablo** y hay que hacerla antes de que alguien aplique el normalizador de
    `PLAN_HOMOGENEIZAR_ARTE.md` fase 1, que hoy oscurecería todo hacia la guía.
  - Las piezas pintadas de `art/` (tótems, seto, puesto, hielo...) no casan con este estilo: se rehacen con
    Meshy cuando les toque, con los prompts de `poc_25d\meshy\PROMPTS.md`.
  - El héroe de 7 cabezas y hero_v2 quedan fuera del estilo; los goblins habría que pasarlos a chibi también.
  - Fases 2–4 de `PLAN_HOMOGENEIZAR_ARTE.md` **quedan en pausa** hasta cerrar la fase 1 de este plan.

Decisiones tomadas:
- **Decorado: todo con Meshy**, con una plantilla de estilo común para que case con la chibi.
- **Migración a 2D: prerrender.** Todo pasa a sprites y atlas con el pipeline y la cámara nueva.

## Fase 1 — Prueba de concepto 3D: un claro de bosque

| # | Tarea | Quién |
|---|---|---|
| 1.1 | Paleta pastel en los bloques del suelo (`prueba_diorama.gd`, paleta `pastel`, la de arranque). | Hecho |
| 1.2 | Escena que carga el decorado de `poc_25d\meshy\<id>.glb` escalado a su alto, con Kenney de sustituto. | Hecho |
| 1.3 | Generar `arbol_redondo` como prueba de estilo con los prompts de `poc_25d\meshy\PROMPTS.md`. | Pablo |
| 1.4 | Revisar juntos el árbol frente a la chibi y ajustar el bloque de estilo si hace falta. | Pablo + Pipeline |
| 1.5 | Generar las 12 piezas restantes y dejarlas en `poc_25d\meshy\`. | Pablo |
| 1.6 | Ajustar la escena: reparto del decorado, alturas, luz y paleta final. | Pipeline |
| 1.7 | Decidir el suelo definitivo: bloques de color (como ahora) o bloques generados también con Meshy. | Pablo |

**Hecho cuando:** el claro de bosque, con la chibi andando por él, se ve homogéneo (nada parece de otro juego)
y Pablo lo da por bueno como referencia visual.

## Fase 2 — Migración a 2D y mininivel

Se usa lo mismo de la fase 1, renderizado a sprites con la cámara de la prueba.

| # | Tarea | Quién |
|---|---|---|
| 2.1 | **Cámara nueva en el pipeline**: hoy los renders van a 30° de elevación y 35,75° de giro (`render_npc_v2_5.py`, cámara en (0,72, −1, 0,72)). Añadir `render.camara` {elevación, giro} a `character.json` y usar 70°/0° para la estética nueva. | Pipeline |
| 2.2 | Re-renderizar la chibi con esa cámara (8 direcciones, `idle`, `walk`, `run` primero). | Pipeline |
| 2.3 | **Props y árboles** del bosque como sprites (tipos `tree` y `prop` del pipeline, con la cámara nueva). | Pipeline |
| 2.4 | **Suelo como tileset**: renderizar los bloques de la fase 1 desde la cámara nueva (uno por tipo y variante). | Pipeline |
| 2.5 | **Rejilla del juego**: con la cámara de frente la casilla deja de ser un rombo isométrico y pasa a ser un rectángulo (~1 : 0,94 más la banda del costado). Afecta a `IsoGrid`, a las colisiones de rombo y a la colocación de todo. | Juego |
| 2.6 | Mininivel 2D de prueba (un claro de bosque, la chibi, un enemigo, un hechizo) con los sprites nuevos. | Juego |

**Coste a tener en cuenta:** la 2.5 es la grande. Hoy todo el juego (movimiento, colisiones, empujables, mapa por
letras) piensa en rombos isométricos. Conviene hacer el mininivel aparte, sin tocar los niveles actuales, hasta
que se decida migrarlos.

**Hecho cuando:** el mininivel 2D se ve igual que la prueba 3D de la fase 1 y se juega con los sistemas actuales
(hechizos, enemigos, mochila).

## Abierto
- ¿La chibi pasa a ser la protagonista? Si sí, sus 15 clips se re-renderizan con la cámara nueva (2.2 completo).
- ¿Qué pasa con hero_v2? Sus proporciones realistas no casan con este estilo.
- Licencia de lo generado con Meshy: comprobar en sus condiciones si el plan que uses permite uso comercial y si pide atribución.
