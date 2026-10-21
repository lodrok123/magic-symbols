# Mejoras: sonido, VFX, suelo, assets, reactividad y glifos (17/10/2026, Juego)

Pedido de Pablo (20:47): música suave y sonido por elemento al lanzar; VFX con más variedad (fuego y agua solo
variedad) y partículas de impacto según el hechizo; suelo menos cuadrado; lista de assets mal generados; casi todo
reactivo o recolectable; más glifos para evitar la monotonía. Complementa `LAB_CASTPOINT.md` (cast points y reacción
de enemigos) y `VFX_RAYO_HIELO.md` (rayo e hielo), que siguen vigentes y no se repiten aquí.

## 1. Sonido

**Lo que hay (medido):** `audio/` tiene un sonido por elemento (`elem_fuego.wav` … `elem_tiempo.wav`, sintetizados) y
`Sfx.CATALOGO` los tiene dados de alta, pero **nada los toca en 3D**: la única función que los usa, `Sfx.for_element`,
recibe un `Node2D` (es del juego 2D). Al lanzar solo suena `sello_no` cuando falla. **No hay música.**

**Propuesta:**
- **Tres capas por hechizo, enganchadas a las fases que ya existen** (`Lanzador3D.conjuro_fase`): *carga* (crece durante
  la anticipación, sube de tono hasta el disparo), *disparo* (golpe seco del elemento) e *impacto* (distinto por forma:
  estallido para la bola, rugido grave para el pilar, barrido para el muro). Siete elementos × 3 = 21 sonidos; los
  `elem_*` actuales sirven de *disparo* desde hoy.
- **Variación** para que no canse: 2–3 tomas por sonido y tono ±8 % (el catálogo ya admite listas y `tono`).
- **Calidad del trazo audible:** `quality` (0–1) ya sale del reconocedor; un trazo perfecto añade una capa brillante
  («crítico») al disparo.
- **Música:** un bucle de exploración suave (acústico, 70–90 bpm, 2–3 min) y una capa de tensión que entra con
  enemigos cerca (fundido 2 s). Con el libro abierto (tiempo al 30 %) un filtro paso-bajo en el bus de música: el mundo
  se «aleja» mientras escribes. Bus propio con volumen en opciones. Fuentes CC0/CC-BY con `LICENCIAS.md` al día.

## 2. VFX

Fuego y agua: la paleta y el aspecto valen; ganan variedad con lo que sigue. Rayo e hielo: `VFX_RAYO_HIELO.md`.
Tierra, viento y tiempo aún usan la primera pasada (piezas Formas3D del 6/10): entran en el kit (`vfx_elementos/`)
con su rampa y su perfil, como fuego y agua.

**Variedad sin elementos nuevos: firma visual por sello.** Hoy los sellos cambian la receta pero el hechizo se ve
igual. Cada operador debe dejar una marca que se lea:

| sello | firma visual |
|---|---|
| repetición | ecos: cada copia nace con un destello y la anterior deja una estela que se desvanece |
| amplificar | halo exterior y 1,3× de tamaño; partículas más gruesas y una luz más fuerte |
| rebote | chispa y anillo en cada rebote; la estela cambia de ángulo con un «quiebro» |
| retardo | runa en el suelo con un arco que se cierra (cuenta atrás) y estalla |
| pulso | anillos concéntricos del color del elemento |
| atracción | espiral de partículas hacia dentro |
| espejo | gemelo translúcido que sale hacia atrás |

**Tamaño y brillo por calidad del trazo:** 0,85× a 1,15× según `quality`; un trazo perfecto, destello extra. El
jugador ve que escribir bien rinde.

**Partículas de impacto según el hechizo recibido** (forma × elemento × lo golpeado):
- *Por forma:* bola → estallido en cono **hacia atrás** respecto a la dirección del golpe (ahora es radial); pilar →
  erupción vertical y anillo de polvo; muro → chispas a lo largo de la línea; corro/barrera → onda en el suelo.
- *Sobre un enemigo* (además del destello/aplastamiento de T-CP2): chispa de impacto del elemento y **estado visible
  mientras dure**: quemado (humo y brasas), mojado (gotas que caen), helado (`CostraHielo3D`, ya existe), aturdido
  (arcos alrededor de la cabeza), lento por tierra (polvo en los pies), empujado por viento (hojas).
- *Sobre objetos:* según su material (§5): astillas de madera, esquirlas de piedra, pétalos/hojas, chispas en metal.

## 3. Suelo menos cuadrado

**Lo que ya hay:** bordes con ruido entre materiales del suelo (diario 105, shader del suelo, Juego), ruido en el
contorno agua-orilla (125, Pipeline), `borde_piedras_3d`. Aun así la casilla de 2,3 u se lee en: esquinas del agua y
de los cambios de material, repetición de textura por casilla, alturas planas y bordes rectos de los niveles.

**Propuesta, de más impacto a menos:**
1. **Esquinas redondeadas** en el shader del suelo y en el del agua: en vez de decidir el material por casilla,
   decidir por un campo de distancia suavizado (se mezclan las 4 casillas vecinas con `smoothstep` sobre la distancia
   a la esquina + ruido). Una L de agua deja de tener el pico interior en ángulo recto.
2. **Macro-variación de color en coordenadas de mundo** (ruido de 6–10 casillas de periodo, ±8 % de luminosidad y
   tono): rompe la repetición por casilla sin texturas nuevas.
3. **Relieve suave**: desplazar los vértices de las mallas del suelo con ruido de baja amplitud (≤ 0,05 u) **solo en
   el dibujo**; la colisión y la simulación de agua no cambian.
4. **Dispersión que cruce las costuras**: piedrecitas, hojas, matojos y charcos colocados con jitter y giro
   aleatorios a caballo entre casillas (semilla por nivel para que sea estable).
5. **Bordes del nivel irregulares**: el borde exterior con `borde_piedras_3d`/acantilado con ruido, no recto.

## 4. Assets: lista medida

Medí los 83 `.glb` de `arte/` (578 MB) con un analizador de mallas propio (soldando vértices por posición, porque
Meshy los parte en las costuras de UV): triángulos, aristas no-manifold, caras con orientación contraria a sus
vecinas, triángulos degenerados y astilla, fragmentos sueltos (< 0,2 % de la malla), aristas abiertas, texturas,
escala y origen. La lista completa con acción por archivo va en `auditoria_assets.csv`. Resumen:

**Regenerar (topología rota, se ve como sombras raras y caras que desaparecen):**
- `meshy/piezas/puesto.glb`: 195 aristas no-manifold y 261 caras giradas en solo 3 500 triángulos.
- `meshy/piezas/arbusto.glb`: 79 / 101 y un 9 % de triángulos astilla.

**Limpiar fragmentos sueltos o regenerar** (basura flotante de la generación; se limpia sin regenerar quitando
componentes diminutos):
- en juego: `bosque/bosque_sendero` (847 fragmentos), `equipo/grimorio_1` (414; grimorio_2 y _3 tienen 24 y 15),
  `piezas/campamento_goblin` (400), `piezas/campamento` (329), `piezas/cristal_sanctuario` (314),
  `modelos/elemental_bosque` (277), `enredadera_espinosa` (224), `enredadera` (125), `piezas/ruinas_agua` (125),
  `modelos/emberheart` (115, es el loberno desde la 140), `puente/pilar_runico` (107 + 25 % aristas abiertas),
  `modelos/loberno` (102).
- **Héroe:** `woodland_wanderer.glb` tiene **102 635 triángulos** (3× el resto de personajes, ~31 000) y 127 aristas
  no-manifold; `woodland_wanderer_v1` tiene 31 000 pero también 76. Merece una retopología (o reducción) del héroe.

**Revisar:** escala (`lince` 5,7 u y `emberheart`/`emberstride` 5,5 u frente a 1,7 de los personajes; si el juego los
normaliza, solo es peso), origen (`fuego_rustic` tiene la base 1,3 u por debajo del origen, `puzle_terrain` 0,54) y
telarañas (finas por naturaleza: probablemente bien).

**Duplicados (145 MB):** `woodland_wanderer_suave` = `woodland_wanderer` (misma geometría y tamaño), los 7
`Ivory_Ember_Archmage_*` = `grandmaster`, `gatipedro_*` = `gato_guardabosques`, `Shadowfang_Wolf` = `canouro`,
`campamento` ×3, `cofre_anim` = `cofre`, y cada `_procesados/*` con su versión en `meshy/`. El borrado lo hace Pablo.

**Límites:** mide geometría, no aspecto. Texturas estiradas, colores raros o formas feas no salen aquí; para eso, una
hoja de contacto (todas las piezas renderizadas girando) que el Pipeline puede generar en una tarde. Los archivos
«lámina» (varias piezas en un GLB que se recortan después) tienen muchos fragmentos por diseño: ahí la cifra solo
avisa.

## 5. Casi todo reactivo o recolectable

**Lo que hay:** `Reactivo3D` (seto, tronco, telaraña, tótem, fogata, brasero, puente, placa, emisor, puerta y torre
goblin, surtidor) y las plantas de `Objetos.PLANTAS` (seta, flor, raíz) que **cambian según el elemento y dan un
ingrediente distinto** (seta + rayo = seta electrificada). Ese segundo modelo es el bueno: escala.

**Propuesta: reacción por material, no por objeto.** Cada pieza del catálogo lleva una etiqueta `material` y un
componente genérico decide qué le pasa con cada elemento y qué suelta:

| material | fuego | agua | hielo | rayo | viento | tierra | suelta |
|---|---|---|---|---|---|---|---|
| madera | arde → ceniza | mojada (no arde 20 s) | escarcha | chamusca | — | astilla | carbón, leña |
| vegetal | arde | crece/florece | se congela y quiebra | — | se agita, suelta semillas | — | flor/hoja/semilla |
| piedra | se calienta (brilla) | mojada | se agrieta si estaba mojada | — | — | se desprende | piedra, cristal_tierra |
| metal | se calienta | se oxida | — | **conduce** | — | — | chatarra |
| cristal | se funde (agua) | brilla | crece | **se carga** (luz) | — | se rompe | fragmento |
| tela/cuerda | arde | pesa | se pone rígida | — | ondea | — | hilo |

Así, poner una pieza nueva en el nivel ya la hace reactiva sin código. Los estados visuales reutilizan lo que ya
existe (quemado, mojado, `CostraHielo3D`, electrificado) y las misiones se escriben sobre «consigue X con el elemento
Y» o «enciende/riega/congela N cosas».

## 6. Glifos nuevos

Los sellos actuales cambian **un parámetro** de la receta cada uno (`Sigils.FORM`). Los nuevos siguen esa regla y
aprovechan las cinco runas libres de la biblia (y tres de «asset»), con el significado tradicional de la runa:

| runa | nombre propuesto | qué hace (un parámetro) | por qué rompe la monotonía |
|---|---|---|---|
| ᚦ thurisaz (espina) | **perforar** | el hechizo atraviesa enemigos y objetos (hasta 3) | apuntar a filas, no a uno |
| ᚱ raido (viaje) | **senda** | deja el elemento en el camino recorrido (fuego arde, hielo resbala, agua moja) | convierte un proyectil en terreno |
| ᚨ ansuz (palabra) | **marca** | el primer impacto marca al objetivo; el siguiente hechizo lo busca solo | combos de dos páginas |
| ᛃ jera (ciclo) | **retorno** | el hechizo vuelve al lanzador (búmeran) y golpea de nuevo | ida y vuelta, rodear obstáculos |
| ᛒ berkana (crecer) | **crecer** | el efecto aumenta mientras dura (bola que engorda, muro que sube) | recompensa la distancia |
| ᛉ algiz (protección) | **guarda** | en vez de salir, envuelve al jugador y absorbe un golpe del elemento | defensa activa |
| ᛞ dagaz (día) | **revelar** | destello que aturde 0,5 s y descubre lo oculto (paredes falsas, trampas) | exploración |
| ᛈ perthro (sombra) | **oculto** | el hechizo es invisible hasta que estalla (trampas) | sigilo |

Propuesta de orden: **perforar, senda y marca** primero (las tres cambian cómo se juega el combate y se combinan con
todo lo que hay); retorno y crecer después; guarda/revelar/oculto cuando haya contenido que las necesite. Cada una pide:
la regla (Juego), su firma visual (§2, Pipeline), su glifo en el libro (Pipeline) y que Pablo grabe las muestras.

## 7. Reparto y prompts

**Pablo:** elegir glifos (§6) y su orden; aprobar la tabla de materiales (§5); decidir qué duplicados borrar (§4);
dar el visto bueno a la música (estilo y fuentes).

**Juego (J1 · sonido y datos para VFX):**
> En `magia/lanzador_3d.gd`: llamar a `Sfx.play` en cada fase del conjuro con el nombre del elemento y la fase
> (`"<elemento>_carga"`, `"<elemento>_disparo"`, `"<forma>_impacto"`; si no existen, caer en los `elem_*` actuales) y
> pasar `quality` como tono/capa. Exponer en la señal `impacto` (o una nueva `golpe_hechizo(elemento, forma, sellos,
> calidad, punto, dir, objetivo)`) lo que el Pipeline necesita para las partículas de §2. Prueba sin ventana: cada fase
> pide su sonido una vez. Entrada en el diario con los nombres pedidos.

**Juego (J2 · reactividad por material):**
> Componente genérico `objetos/reaccion_material_3d.gd` con la tabla de §5 (estados, duración, contagio y lo que
> suelta), que se añade solo a cualquier pieza con etiqueta `material`. Reutiliza los estados visuales que ya existen
> y las tablas de `Objetos`. Prueba: una pieza por material × elemento da el estado y el objeto esperados.

**Juego (J3 · glifos):**
> Perforar, senda y marca en `nucleo/sigils.gd` (un parámetro cada uno) y su efecto en `Lanzador3D`/`Receta3D`;
> alta en `GestureLibrary.SIGILS` y `Repertoire`. Prueba por glifo. Pedir al Pipeline glifo PNG y firma visual.

**Juego (J4 · suelo):**
> En el shader del suelo (`CODIGO_SUELO`, del Juego desde la 85): esquinas redondeadas por campo de distancia (§3.1) y
> macro-variación de color en mundo (§3.2). Relieve de vértices solo visual (§3.3). Capturas antes/después.

**Pipeline (P1 · audio):**
> 21 sonidos (7 elementos × carga/disparo/impacto por forma) con 2–3 tomas cada uno, dados de alta en
> `Sfx.CATALOGO`; música de exploración + capa de tensión con fundido, bus «Música» con paso-bajo cuando el libro está
> abierto (`Engine.time_scale` < 1) y volumen en opciones. `LICENCIAS.md` al día.

**Pipeline (P2 · VFX):**
> Tierra, viento y tiempo al kit (`vfx_elementos/`); firma visual por sello (§2, tabla); tamaño y brillo por
> `quality`; impacto por forma (cono hacia atrás según `dir`, erupción, línea, onda); estados visibles sobre enemigos
> mientras duren; astillas/esquirlas/hojas según el material del objeto golpeado. Lee la señal de J1.

**Pipeline (P3 · suelo y agua):**
> Esquinas redondeadas también en `agua_render_3d.gd` (mismo criterio que J4), dispersión de detalles a caballo entre
> casillas con semilla por nivel, y bordes exteriores irregulares.

**Pipeline (P4 · assets):**
> Con `auditoria_assets.csv`: regenerar `puesto` y `arbusto`; quitar fragmentos sueltos (componentes < 0,2 %) del
> resto de la lista «LIMPIAR» con un script de importación o en Blender y volver a medir; reducir el héroe a ~30–40 k
> triángulos conservando el esqueleto y los clips; corregir origen de `fuego_rustic` y `puzle_terrain`. Hoja de
> contacto con todas las piezas para la revisión visual. Etiquetar `material` en el catálogo de piezas (§5).
> Proponer a Pablo la lista de duplicados para borrar.

**Orden:** J1 + P1 (sonido: lo que más se nota por esfuerzo), J4 + P3 (suelo), J2 (reactividad), J3 + P2 (glifos y VFX),
P4 en paralelo cuando el Pipeline tenga hueco.

— Juego
