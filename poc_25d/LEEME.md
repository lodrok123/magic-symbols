# poc_25d — pruebas de concepto 2,5D

## ★ Test 3, objetos del mapa (4.7, 6 de octubre)
`objetos_3d.gd` (`class_name Reactivo3D`, un `Area3D` por objeto) cumple el contrato `on_spell_hit(rune_data, direccion)` del Juego. Se ven en `PruebaTest2.tscn`
(`objetos_reactivos = true` por defecto; en `false` vuelve el dibujo antiguo, y el prerender 2D lo apaga).
- **Seto, tronco, telaraña:** muro (bloquea la celda) hasta que arden (3,5 / 4 / 1,6 s); contagian a ≤1,7 celdas cada 0,8 s (el viento, cono ≤3,6); agua/hielo apagan.
  Al consumirse, la celda se libera y queda ceniza.
- **Fogata y brasero (antorchas):** misma clase; el fuego enciende, agua/hielo apagan; el fuego enciende también lo combustible cercano y la hierba.
- **Tótems:** se activan con su elemento (disco rúnico + luz + motas); el de rayo tiende el puente.
- **Puente:** plegado (80°) y bloqueado hasta `tender()`. **Placa:** solo la acciona el peso: un nodo del grupo `peso` dentro de su Area3D.
- **Mientras no exista el Lanzador:** F1–F6 golpean el objeto de la celda de delante (`_golpear_objetos`, mismo contrato).
- No convertidos (no están en 4.7): barrera de fuego (B) y setas (h).

## ★ Test 3, parte del Pipeline: validación de GLB, VFX por forma y lanzar en 3D (6 de octubre)
Tareas 4.8, 4.6 y 4.6b de `docs/PLAN_ARREGLOS.md`. Se prueba en `LabVfx3D.tscn` (no hay nada nuevo en PruebaTest2).
- **Validar al cargar (4.8):** `Pj3D.validar()` (se llama sola en `cargar`, una vez por id; `Pj3D.validar_al_cargar = false` la apaga)
  avisa por consola de clips mínimos que faltan, clips "en su sitio" que arrastran la cadera (> 0,35 alturas de cadera) y
  escala rara del modelo. La lista mínima está en `docs/ASSETS_PENDIENTES.md` §1. `Pj3D.CLIPS_DE` renombra un rol por personaje.
  Hallazgos: el `cast` genérico de la elfa pasa a `MageSoellCast003` (el anterior arrastraba la cadera 0,36); el `hit` de la elfa
  no resolvía a ningún clip (ahora `FacePunchReaction`); el goblin usa `SlapReaction` como `hit`.
- **VFX por forma (4.6):** `Vfx3D.lanzar_forma(forma, elemento, pie_origen, pie_destino, opciones)` con `Vfx3D.FORMAS` =
  proyectil · corro · columna · muro. 6 elementos × 4 formas = 24 celdas, todas con dibujo propio (cada elemento dibuja su
  "brote": llamas, chorro, púa, torbellino, haz, cristal; la forma decide cuántos y dónde). `opciones`: `radio` (corro:
  radio del anillo; muro: semiancho; 1,2) y `dura` (2,0 / 3,0 / 0,9 s). Una forma desconocida cae al proyectil.
  `lanzar(elemento, ...)` sigue siendo el proyectil de siempre. Es solo la parte visual: la colisión es del Lanzador.
  **En el laboratorio:** tecla **F** cambia de forma (proyectil → corro → columna → muro) y **B** recorre las 24 celdas.
- **Lanzar (4.6b):** `Pj3D.lanzar(forma, elemento)` pone el clip de `Pj3D.ANIM_CAST` (o `readandwrite`) en bucle y unas motas
  sutiles del elemento en la mano derecha (`Vfx3D.chispas_mano`); `Pj3D.soltar_lanzar()` las quita y vuelve a idle.
- **Sin medir:** la nube no tiene Vulkan, así que no hay ms ni FPS. Un muro son 20 manifestaciones con 1–3 emisores cada una
  (~40 `GPUParticles3D` a la vez 1 s); si pesa, bajar `k` en `Vfx3D._brote` o las filas de `_muro`.

## ★ PruebaTest2: estado del suelo, agua, rampa de luz y empujables (5 de octubre, noche) ← para probar
Aplica `docs/IMPLEMENTAR_TECNICAS.md` (pasos 1, 2, 3 y 5; del 4, las sombras). **Abre Godot y deja que reimporte.**
Al arrancar sale un velo "Preparando efectos..." ~2 s: compila los shaders de los seis hechizos (no marca el suelo).
- **Hechizos: F1 fuego · F2 agua · F3 tierra · F4 viento · F5 rayo · F6 hielo**, hacia donde mira la chibi (2,5 casillas).
- **Estado por casilla** (contrato `docs/ESTADOS_SUELO.md`, que manda sobre la guía donde difieren; un impacto toca UNA casilla):
  - *Hierba* (casilla de tipo hierba sin objeto encima): fuego → prende 1 s → arde 5 s → **ceniza** (se queda; la hierba
    se encoge y se oscurece); el fuego se **contagia** a la hierba de al lado (frente de 0,5 casillas/s, hasta 1,7);
    rayo → arde directo; agua o hielo → la que arde se apaga y la ceniza **rebrota**; agua sobre hierba fina → **crece**
    (alta y sólida, no se puede cruzar); viento sobre hierba que arde → prende el cono de delante (3,6 casillas).
  - *Suelo neutro* (camino, tierra, piedra): agua → charco oscuro (tinte 0,62·0,66·0,78 del 2D); dos aguas → hielo;
    hielo → hielo; fuego sobre hielo → charco, fuego sobre charco → se seca con vapor. **No caduca**. El suelo no arde.
  - *Agua*: hielo → casilla helada permanente (la chibi la pisa); fuego → vapor, no la derrite.
  - *Solo aspecto*: la hierba se tumba donde pisa la chibi y **se aparta** a su paso; el viento tumba en radio 2.
- **Agua nueva** (`CODIGO_AGUA`): clara en la orilla y honda en el centro (distancia a tierra), espuma rota junto a
  la orilla, ondas con dos normales (de ruido hasta que exista `suelo_meshy/agua_normal.png`), hielo quieto y pálido.
  La espuma contra piedras y pasaderos con depth buffer (§2.4) **no está hecha**: obliga a pasar el agua a transparente.
- **Rampa de luz** (Paso 3) en suelo y agua: **tecla T** alterna contraste 2,5 → 4 → 1 (1 = como antes) para elegir.
- **Empujables** con tapa y lado distintos y **grietas** (`CODIGO_BLOQUE`): **tecla V** sube el daño del más cercano
  (0 → 0,34 → 0,68 → 1). Texturas opcionales en `suelo_meshy/`: `tierra_lado.png`, `hielo_arriba.png`, `hielo_lado.png`,
  `grietas.png` (R leves, G medias, B rotura) y `agua_normal.png`; sin ellas usa las del suelo y unas grietas de ruido.
- **Presupuesto de texturas (Paso 4):** a 1080p con el zoom inicial (6) un metro ocupa 180 px; la chibi (alto 1) mide 180 px
  y a zoom máximo (2) 540 px, así que 1024 px de textura sobra. Elfa, librera y goblin bajados de 2048 a **1024** (los GLB
  pasan de ~27 MB a ~8 MB y a 1/4 de VRAM; a zoom máximo no se distingue). Las bibliotecas de Meshy (2048, hasta 13 piezas
  por atlas) NO se han tocado: cada pieza ya usa menos de 2048 texels. Al reimportar, Godot rehace las
  `*_Image_N.jpg` junto a cada GLB (ya van subidas a 1024). Si el Pipeline vuelve a copiar un personaje desde su master,
  pasarlo por `reducir_pj.py` o se vuelve a 2048. `chibi_elf_normal.png`, `chibi_elf_texture_0*.png` (4096) son restos del
  modelo viejo y nadie los usa: se pueden borrar.
- **Sin sombra** los lotes pequeños (arbustos, piedras, setas, tocón, cartel, pasadero...): `SIN_SOMBRA` en `prueba_test2.gd`.
- El HUD enseña las casillas vivas y los ms de `_avanzar_estado`. API nueva en `Hierba3D`: `set_estado(tex, celda, lado)`,
  `set_posicion_jugador(p)`, `set_crecida(c, v)`, `subir_crecida()`; en `Vfx3D`: `llamas(suelo, esc, radio)`, `apagar(n)`, `vapor(p)`.
- QA: `impactar_en([["fuego", Vector2i(4, 9)], ...])` e `imprimir_estado()` (llamables desde la captura).
- El **prerender del Test 2D** usa ahora la rampa de luz: si lo vuelves a lanzar, las baldosas salen con otro contraste
  (T = 1 en `_contraste` si quieres el aspecto anterior).

## ★ Carteles con runa y baldosas rúnicas (5 de octubre, noche)
Los seis carteles de elemento de `PruebaTest2` llevan su símbolo en el tablero (`vfx/runas/runa_<elem>.png`, sacadas de
tu lámina) y delante, en el suelo, la baldosa con borde de rombo que late (`runa_suelo_<elem>.png`; ahí no crece hierba).
El cartel va girado `GIRO_CARTEL` = 319° para que el tablero mire a la cámara. `meshy/piezas/seto_seco.glb` (Autumn Bramble)
sustituye al seto de la lámina; `arbusto_otono` queda de reserva.

## ★ Grimorios de Meshy en la cadera de la elfa (5 de octubre, noche)
Los tres que generaste, en `equipo/grimorio_1.glb` (botánico), `grimorio_2.glb` (rúnico) y `grimorio_3.glb`
(legendario), cada uno con su pluma, en el mismo sitio que el de código (cadera izquierda) y a su tamaño
(alto 0,34; textura a 1024, ~1,2 MB cada uno). **Tecla N** cambia de nivel en `PruebaTest2`, `LabVfx3D` (ahí
también cambia el estilo de página del grimorio abierto: botánico / astral / acuarela) y `CatalogoAssets`
(modo personajes). Los GLB originales de `grimorio/` ya no hacen falta: `ORDENAR_POC.cmd` los aparta.

## ★ PruebaTest2: rendimiento, sustituciones y suelo (5 de octubre, noche) ← para medir
Lo que pedía `docs/PLAN_ACCION_TEST2.md` §2.2 para el Pipeline. **Abre Godot y deja que reimporte** (las
texturas de `suelo_meshy` y `vfx` pasan a VRAM comprimida con mipmaps: tarda un poco la primera vez).
- **Rendimiento (A–E):** A ya estaba (los GLB importan sus texturas en VRAM); B hecho en los `.import`; C la hierba
  va en bloques de 4 × 4 casillas que **solo existen alrededor de la chibi** (se siembran al acercarse, uno por
  fotograma, y se liberan al alejarse; el radio crece con el zoom), como pide `docs/HIERBA_OPTIMIZACION.md`;
  D la hierba ya no hacía sombra y la del sol llega a 30 m (antes 60); E el decorado va en **lotes** (un MultiMesh por pieza, malla y trozo del mapa:
  157 lotes en todo el mapa en vez de un nodo por pieza). El HUD enseña llamadas de dibujo, primitivas, memoria de vídeo y lotes: es lo que
  pide la tabla de §1.2 (mide con H / G / K / P como dice el plan).
- **Sustituciones sin Meshy:** árbol y pino de `arboles_2`, `arbusto_otono` en vez de `seto_seco`, `puesto_mercado`,
  `arco_ruina` en la puerta. Fuera `matas`, `flores`, `caja_cristal`.
- **Empujables:** dos cubos de prueba (tierra en la cámara de tierra, hielo en la de hielo), sin mecánica aún.
- **Suelo más oscuro (×0,78) y luz normal** (ambiente 0,6, sol 1,0): los personajes ya no se apagan.
- **Piezas regeneradas:** `meshy/INTEGRAR_PIEZAS.cmd` + `CatalogoAssets` tecla **H** (hoja de contacto con la chibi).
- **Armas del goblin** preparadas en `equipo/` (`garrote`, `escudo`, `daga`): el goblin las coge de ahí.
- El prerender del Test 2D (`PrerenderTest2D`) sigue funcionando: pone el decorado como nodos sueltos.

## ★ Test 2D — `test2d/Test2D.tscn` (5 de octubre, tarde)
El mismo trozo de Test 2 que la maqueta 3D (puerta norte, plaza con goblins y aldea con la librera), en **2D de
verdad**. Todo es imagen **prerenderizada desde el 3D** con la misma cámara (20°) y la misma luz:
- **suelo:** baldosas de 1024 px;
- **decorado:** cada pieza suelta y ordenada en profundidad con los personajes;
- **personajes:** atlas de 8 direcciones; la elfa con su grimorio y el goblin con garrote y escudo.
Sombras, partículas, hechizos y grimorio se hacen en 2D.
Teclas: WASD · Shift · 1-6 hechizo hacia donde mira · T grimorio · +/- zoom · P partículas · O sombras ·
G casillas bloqueadas.
- **Las imágenes** están en `test2d/generado/` y salen de `test2d/PrerenderTest2D.tscn`. Las de ahora se hicieron
  en la nube, sin sombras y con el renderizador de compatibilidad. **Si lo abres y pulsas F6 en tu PC, las rehace
  con Forward+ y sombras proyectadas** (unos minutos; luego vuelve a abrir Test2D).
- **Para cambiar la zona, la resolución, las animaciones o los personajes:** las constantes del principio de
  `prerender_test2d.gd`.

## Assets nuevos (5 de octubre, tarde)
- **`meshy/arboles.glb`:** árbol redondo, pino y seto seco, uno por generación.
- **`meshy/mercado.glb`:** arco, puesto y tótem.
Las dos van primero en la lista de bibliotecas, así que sustituyen a las piezas de lámina. El arco nuevo ya mira a
la cámara: no se gira.
- **`equipo/armas_goblin.glb`:** garrote, escudo y espada del goblin. `equipo_3d.gd` los orienta y los escala
  (`MEDIDA_PIEZA`); el goblin lleva garrote y escudo.

## Novedades del 5 de octubre (mediodía): el grimorio
- **La elfa lleva su grimorio** (libro y pluma provisionales hechos por código, `equipo_3d.gd`) colgado de la
  cadera izquierda. Es su arma principal: ver `meshy/PROMPTS_GRIMORIO.md`.
- **T abre el grimorio en `LabVfx3D`** (`grimorio/grimorio_ui.gd`). El libro sube desde abajo, se oscurece el
  fondo y el mundo va a cámara muy lenta. Dentro: **1** libro de aprendiz (1 sello, 3 glifos), **2** libro
  avanzado (2 sellos, 6 glifos), **Q/E** estilo (botánico, astral, acuarela) con paso de página, **Espacio**
  huecos llenos o vacíos, **T** cerrar. La cámara lenta del laboratorio ha pasado de T a **M**.
- **Páginas provisionales:** `grimorio/generar_paginas.py` dibuja las 6 láminas (3 estilos × 2 libros) y
  `paginas.json`, con las medidas en las que el juego dibuja encima. Una lámina pintada tiene que respetarlas.

- **`LabVfx3D.tscn`: laboratorio de efectos 3D.** La elfa en un claro de hierba frente a una columna de
  objetivos (dummy, seto seco, tótem, tronco y goblin). Los efectos salen de `vfx_3d.gd` (clase
  `Vfx3D`), que lanza un hechizo con carga, proyectil e impacto usando los sprites de `vfx/`.
  - 1–6 elementos (fuego, agua, tierra, viento, rayo, hielo) · Espacio repite · Tab o flechas cambian de objetivo.
  - B bucle con todos los elementos seguidos · T cámara lenta · X tamaño · V velocidad del proyectil.
  - C cámara (juego, baja o lateral) · +/- zoom · G hierba · L luces.
  - Para retocar un efecto: busca su función `_impacto_<elemento>` en `vfx_3d.gd`.
- **`CatalogoAssets.tscn`: revisión de assets.**
  - **1:** todas las piezas de las bibliotecas al mismo tamaño, con su número de triángulos.
  - **2:** los personajes en fila, a la misma altura y con rayas cada 1/6. En este modo, 3/4 cabeza,
    5/6 piernas, 7/8 torso, 0 alterna original y ajustada, y A cambia de animación.
- **Proporciones de la elfa** (`proporcion_chibi.gd`, clase `ProporcionChibi`): corrige en vivo cabeza, piernas
  y torso de un personaje Mixamo después de la animación. Los valores por personaje están en `PROPORCIONES`,
  dentro de `pj_3d.gd`. `chibi_elf` = cabeza 0,76 · piernas 1,4 · torso 1,1, para parecerse a la librera.
  Los ojos no se pueden cambiar así: ver `meshy/PROMPTS_ELFA.md`.
- **Hierba 3D** (`hierba_3d.gd`, clase `Hierba3D`): matojos de briznas que se mecen con el viento y florecitas,
  en MultiMesh, sembrados donde el suelo pinta hierba. En los bordes salen más altos, como un flequillo
  sobre el camino. En `PruebaTest2`, G la enciende o apaga. Densidad, altura y colores: los `@export` del principio.
- **Suelo de `PruebaTest2`:**
  - **Luz:** estaba quemada (ambiente 0,8 + sol 1,0 dejaban el camino blanco). Ahora es ambiente 0,42 + sol 0,78
    y las texturas se ven como están pintadas.
  - **Repetición:** el shader mezcla dos muestras de cada textura, giradas y a otra escala, para que no se
    vean cuadros repetidos, y varía un poco el tono a gran escala.
  - **Bordes:** el ruido que los ondula es ahora una textura calculada por código (`_campo_ruido`), así la
    hierba 3D sabe exactamente dónde está el borde.
- **Arreglos en `PruebaTest2`:**
  - el arco de la puerta norte (X) estaba de canto: gira 90°;
  - la fogata ya no tiene el muñeco de madera del centro (arreglado en `meshy/objetos.glb`);
  - `matas` y `flores` de Meshy ya no se usan, porque salieron mal: las pone `Hierba3D`.

## ★ Prueba F — `PruebaTest2.tscn` (maqueta 3D de Test 2)
Lee el plano de `test_2.gd` (40 × 40) y lo monta en 3D con todo lo generado hasta ahora:
- **Suelo** de bloques con las texturas pintadas y **transiciones onduladas** entre hierba, camino, tierra y
  piedra (shader `CODIGO_SUELO` dentro de `prueba_test2.gd`). Orillas de arena junto al agua. Agua animada.
- **Decorado** de Meshy: `meshy/bosque.glb`, `meshy/objetos.glb`, `meshy/magia.glb`, colocado por letra
  (`#` árboles, `z` setos secos, `l` tronco, `h` setas, `r` telaraña, `j k i` tótems con su círculo rúnico,
  `B` barrera de fuego, `F` fogatas, `T` braseros, `n Q` puestos con la librera, `D` dummy, `s f q` plantas
  mágicas, `X` arco, `E` portal, `K` placa, `b` puente), más guardados, oro, pociones y carteles de cada cámara.
  Cada pieza va algo desplazada, girada y con tamaño variado para que no se note la rejilla.
- **Partículas** de `vfx/`: fuego animado (tira de 8), brasas, humo, esporas, destellos, pétalos y hojas.
- **Personajes**: la chibi nueva (`chibi_elf.glb`), la librera (`bookseller_chibi.glb`) y los goblins
  (`goblin_warrior_chibi.glb` cuando salga del pipeline; mientras, el goblin antiguo). Miran a la chibi al acercarse.
- Solo visual: se pasea; no hay hechizos ni pruebas.
Teclas: WASD · Shift · R/F inclinación · 1/2/3 · +/- zoom · H sombras · P partículas · K decorado · G hierba · L luz · [ ].
Si falta algo, el HUD lo dice en una línea con (!).

Dos pruebas aisladas, sin tocar ningún archivo existente. Los personajes son modelos 3D vivos
(los `*_master.glb` del pipeline) en las dos.

## Prueba E — `PruebaDiorama.tscn` (la buena por ahora)
Bloques gruesos de color liso, con tapa biselada que sobresale sobre un cuerpo de tierra, luz y sombras suaves, matas y
flores de formas simples (referencia: Link's Awakening). Sin texturas. Cámara de frente con 20° de inclinación respecto a la
vertical (R/F, presets 1/2/3). **P** cambia entre la paleta de la chibi (luminosa, tipo Link's Awakening) y la recomendada para
hero_v2 (terrosa y apagada). Colores y luz de cada paleta: `PALETAS` al principio de `prueba_diorama.gd`. Forma del bloque:
`GROSOR_TAPA`, `BISEL`, `VUELO`, `SEPARACION`.

## Prueba D — `PruebaCenital.tscn` (cámara sin inclinación + suelo con la paleta de cada personaje)
Cámara casi vertical (85°, ajustable con R/F), suelo de losetas pintadas por el kit `kit_suelo\generar_suelo.py` con la paleta de la
chibi o de hero_v2 (tecla **P** para cambiar), y los dos personajes en 3D. Antes de abrirla: `python poc_25d\kit_suelo\generar_suelo.py todas`
(ya vienen generadas) y abre Godot para que importe los PNG de `poc_25d\suelo\`. Ver `kit_suelo\LEEME.md`.

## Prueba A — `Prueba3D.tscn` (suelo 3D)  ← la nueva
Suelo de bloques 3D reales que llevan pintado el arte de los bloques del bosque (cara de arriba y costados,
proyectado vértice a vértice), con contorno oscuro por casco invertido y un degradado hacia la base. Cámara
ortográfica con el ángulo del render de Blender, la chibi y hero_v2.
Teclas: WASD mover · Shift correr · Tab personaje · L luz plana/suave · +/- zoom ·
[ ] tamaño del personaje activo · C +5 chibis (coste) · X quitarlos.

## Prueba C — `Prueba2D.tscn` (cámara 2D real)
Escena 2D con `Camera2D`, y-sort y los bloques sprite de siempre; la chibi y hero_v2 son modelos 3D vivos dentro
de un `SubViewport` que se ve como un `Sprite2D` (`MsActor3D`). Es la arquitectura que encaja con el juego actual:
hechizos, enemigos e interfaz siguen en 2D y solo los personajes son 3D. T alterna con el sprite (solo la chibi tiene atlas).
Sin contorno en pantalla en los personajes (en un viewport transparente el posproceso rompe el fondo).

## Prueba B — `Prueba25D.tscn` (suelo de sprites, antiguo)
Los bloques 2D de siempre con chibi, héroe y goblin, alternando 3D en vivo / sprite con la tecla T.

## Cómo probarlas
1. Doble clic en `poc_25d\COPIAR_MODELOS.cmd` (copia los modelos maestros, ~100 MB, a esta carpeta).
2. Abre Godot y espera a que importe los `.glb`.
3. Abre la escena y pulsa F6.

## Ángulo de la cámara (en las dos escenas)
R/F elevación ±5° · Q/E giro ±5° · tecla 1 = ángulo del render de Blender (30,3°/35,75°) · tecla 2 = ángulo del suelo 2D del juego (30°/45°, rombo 2:1 exacto).
En `Prueba3D` el suelo 3D se adapta a cualquier ángulo; en `Prueba2D` el suelo es sprite y solo encaja con la tecla 2.

## Si algo no casa
- Tamaño de bloque vs personaje: `S` en `prueba_3d.gd` (2,3 equivale a la chibi a escala 0,5 del juego).
- Mira al lado equivocado o se mueve al revés: `CAM_OFFSET` y el cálculo de `avance`/`derecha`.
- Rejilla entre casillas: `RECORTE_PX` (recorta el borde del sprite en la cara de arriba; 0 lo quita).
- Contorno en pantalla (tecla O lo activa/desactiva): `GROSOR_LINEA`, `UMBRAL_PROFUNDIDAD` (siluetas y escalones), `UMBRAL_NORMAL` (aristas de los cubos) y `COLOR_LINEA`. Si salen líneas de más, sube los umbrales; si faltan, bájalos. `CONTORNO` es el casco invertido antiguo (0 = apagado). Volumen de los costados: `OSCURO_BASE`.
- Costados que no encajan con la cara de arriba: `PX_TOPE`, `PX_MEDIO_ROMBO` y `PX_COSTADO` (medidas del sprite) o `ALTO`.
- Si falta una textura, ese bloque sale con el color plano de la paleta.
- Muy oscuro o muy claro: tecla L (solo afecta a los personajes; los bloques van sin sombreado).
- Pies flotando o hundidos: `_apoyar_en_el_suelo` de `pj_3d.gd` (apoya el modelo por su caja).

## .gitignore
Ahora el `.gitignore` no excluye los `.glb`, así que los modelos de esta carpeta suben con el commit (unos 150 MB
en total; el mayor, `hero_v2.glb`, pesa 31 MB). Si molesta el peso, usa Git LFS para `*.glb`.
