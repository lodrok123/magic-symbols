# Fase 14 · Presentación, HUD, escritura de runas, animación y laboratorio de fuego

Contexto Juego, 16/10. Pedido de Pablo (10:54): analizar las referencias (Zelda: Echoes of Wisdom y dos capturas de un juego
de runas en primera persona) y convertirlas en tareas con prompt por responsable, de cara al prototipo jugable del nivel 01.
Fuente de verdad del reparto: `docs/PROPIETARIOS.md`. Este documento propone; el plan es `docs/PLAN_ARREGLOS.md` (Pablo lo integra
como Fase 14 si le vale).

---

## 1. Qué hace Echoes of Wisdom para que funcione (y qué de eso vale aquí)

Lo que se ve en las capturas y en el juego, en orden de impacto por esfuerzo:

| Recurso de EoW | Por qué funciona | Aplicable a Magic Symbols | Coste |
|---|---|---|---|
| **Diorama: profundidad de campo tipo «tilt-shift»** (nítido donde está la protagonista, borroso arriba y abajo) | Vende la escala de juguete y esconde el horizonte y los bordes del mapa | Sí: `CameraAttributes` de Godot con desenfoque lejano suave, atado a la distancia del jugador | Bajo (Pipeline) |
| **Geometría blanda**: taludes redondeados, piedras del borde como canto rodado, nada termina en arista viva aunque la lógica sea de casillas | La rejilla no se ve; se ven colinas | Sí: el suelo ya es por casillas; falta biselar los bordes de altura y los bordes del agua con una malla «falda» y poner el **anillo de piedras** en cada cambio de altura (la foto 2) | Medio (Pipeline) |
| **Transiciones entre materiales con borde orgánico** (hierba→tierra→arena con bordes desflecados, no rectos) | Cohesión; el ojo lee zonas, no baldosas | Sí: el shader del suelo ya lo hace para hierba (diario 85); falta para tierra/arena/piedra entre sí | Bajo (Juego, shader del suelo es del Juego desde la 85) |
| **Paleta uniforme y saturada**: 3–4 verdes, 2 marrones, 1 azul; todo con el mismo tono de luz | Lo que más «calidad» aparenta con menos trabajo | Sí: paleta única en `docs/ARTE.md` y un `ColorCorrection`/LUT en el entorno; las matas de `Hierba3D` al verde del suelo (ya pedido en la 96) | Bajo (Pipeline) |
| **La hierba cortada deja rastrojo** (foto 3: matas verdes → cuadraditos oscuros en el suelo) | El mundo recuerda lo que hiciste | Sí: al quemar/cortar, cambiar la mata por su versión `rastrojo` (decal o malla baja) y marcar la casilla | Bajo (Pipeline + 1 señal del Juego) |
| **Agua translúcida con fondo visible** (foto de la piscina azul del 15/10 y el río) | Se intuye profundidad; se ven cosas en el fondo | Sí: `AguaRender3D` ya tiene opacidad por profundidad; bajar `prof_rio` para que el fondo se vea hasta ~0,6 u y poner **objetos en el fondo** (ítems, piedras) | Bajo (Pipeline) |
| **Telegrafía legible**: el enemigo anuncia (foto 2: los moblins alrededor del hueso), el hechizo deja estela (foto 1: haz verde) | Se entiende sin HUD | Parcial: ya hay chispa en el punto de activación; falta estela continua del hechizo hasta el impacto | Medio (Pipeline) |
| **Adventure Log** (foto 4): lista a la izquierda, ficha a la derecha, icono de tipo, radio «activa», texto de 2–3 frases con quién y dónde | Trazabilidad de misiones sin mapa | Sí: diario de misiones (ver §3.1) | Medio (Juego lógica + Pipeline arte) |
| **Inventario en rejilla con contador y corazón** (foto 6) | Se cuenta de un vistazo | Sí, con la variante de Pablo: silueta de **bolsa** y objetos dentro (§3.2) | Medio |
| **Game Over**: desenfoque del mundo + texto grande y sobrio, sin UI (foto 7) | Pausa emocional | Sí: «Has muerto» en rojo apagado, desenfoque, 2 s, reaparecer (§3.3) | Bajo (Juego) |
| **Sombras de contacto suaves** bajo todo lo que está en el suelo (foto 5) | Las piezas se «apoyan» | Sí: SSAO suave o decal de sombra bajo cada pieza (muchas piezas ya tienen) | Bajo (Pipeline) |

Lo que **no** conviene copiar: el nivel de detalle de los personajes (otro presupuesto), la cámara que gira (la nuestra es fija isométrica
y los puzles de línea de tiro dependen de eso).

---

## 2. Presentación del escenario (las 5 mejoras de Pablo)

| # | Mejora | Qué hacer | Propietario | Archivos |
|---|---|---|---|---|
| P1 | **Evitar lo cuadrado** | (a) **Falda biselada** en cada escalón de altura y en el borde del agua: una tira de malla con normal suavizada que «funde» la pared vertical con el suelo (1 segmento, 0,3 u); (b) **anillo de piedras** generado por procedimiento en los cambios de altura (como EoW: cantos de 0,3–0,6 u con jitter, MultiMesh); (c) esquinas de las zonas de agua/tierra con la máscara orgánica del shader, no con la rejilla. La lógica sigue siendo cúbica. | Pipeline | `prueba_test2.gd` (`_construir_suelo`), `terra_fina_3d.gd` (terrazas, hablar con Juego), nueva `presentacion/borde_piedras_3d.gd` |
| P2 | **Uniformidad de color** | Paleta cerrada en `docs/ARTE.md` (hierba ×3, tierra ×2, piedra ×2, agua ×2, madera, metal); `Hierba3D` toma su color de la textura del suelo; `WorldEnvironment` con `adjustment` (saturación/contraste) único para todos los niveles; comprobar las piezas de Meshy contra la paleta (tinte si se van). | Pipeline | `docs/ARTE.md`, `hierba_3d.gd`, `prueba_test2.gd` (entorno), piezas |
| P3 | **Rastrojo al destruir hierba** | Al quemar o cortar una mata: la pieza pasa a `rastrojo` (malla baja de tallos quemados/cortados + mancha oscura) y la casilla queda marcada «segada» en `EstadosSuelo3D` (nuevo estado `SEGADA`, no vuelve a crecer en la sesión). El Juego emite; el Pipeline dibuja. | Juego (estado + señal) · Pipeline (malla y cambio) | `mundo/estados_suelo_3d.gd`, `presentacion/hierba_3d.gd`, `objetos_3d.gd` (seto/matas) |
| P4 | **Bordes entre materiales** | Extender el borde orgánico del shader del suelo (hoy solo hierba→otro) a **todas las parejas**: tierra↔piedra, arena↔piedra, camino↔hierba, con el ancho y el desflecado por pareja (`borde_ancho` por material). La arena «lame» la piedra (gradiente de 0,4 u), la hierba invade la tierra con matas sueltas. | Juego (shader del suelo es del Juego desde la 85) | `prueba_test2.gd` (`CODIGO_SUELO`) |
| P5 | **Agua translúcida con fondo** | `AguaRender3D`: `prof_rio` de 0,9 → 1,4 (el fondo se ve hasta más hondo), tinte del fondo (caustics suaves opcionales), y **fondo con contenido**: piedras/ítems bajo el agua se dibujan (hoy el lecho es un bloque liso). Ítems recogibles sumergidos: el Juego los marca «bajo el agua» y solo se recogen nadando/buceando (decisión). | Pipeline (dibujo) · Juego (ítem sumergido) | `agua_render_3d.gd`, `prueba_test2.gd` (lecho), `objetos/recogible` |

---

## 3. HUD (inspiración Zelda)

### 3.1 Diario de misiones (Adventure Log)
- **Dato (Juego):** `nucleo/misiones.gd` (`Misiones`, autoload o estático en `Estado`): misión = {id, título, tipo (principal/secundaria), estado (oculta/activa/completa), texto (2–3 frases: quién, qué, dónde), objetivos [{texto, hecho}], origen (NPC/lugar), recompensa}. Señales `misión_cambio(id)`. Las reglas de nivel (`Bosque3D`, `TerraFina3D`) ya tienen «tareas»: pasan a ser misiones de este sistema (una API, no dos). Persistencia con el guardado actual.
- **Pantalla (Juego lógica, Pipeline arte):** tecla `J`/pestaña del grimorio: lista izquierda (icono de tipo, radio «seguida», título), ficha derecha (título, texto, objetivos con casilla, origen abajo a la derecha como en la foto 4). Una misión «seguida» muestra su objetivo actual en una línea discreta del HUD.
- **Arte (Pipeline):** pergamino de la ficha, iconos principal/secundaria, fuente coherente con el libro.

### 3.2 Inventario «bolsa»
- **Idea de Pablo:** contorno de una **bolsa** y los objetos dispuestos dentro (no una rejilla fría).
- **Juego:** `bolsa_ui.gd` ya existe (presentación/ui, del Juego): pasa a una **rejilla irregular** definida por una máscara (puntos de anclaje dentro de la silueta de la bolsa, 4–5 filas que se estrechan hacia el cuello), contador numérico abajo-derecha de cada objeto, corazón rojo en los que curan (como EoW), nombre del seleccionado en una banda bajo la bolsa, y orden fijo por categoría (componentes, pociones, llaves/objetos clave). Navegación con ratón y teclado.
- **Pipeline:** la silueta de la bolsa (PNG 2D a 2 tamaños), iconos 2D de los objetos (12.2 ya lo pedía), banda del nombre.

### 3.3 Pantalla de muerte
- **Juego:** al morir (`Jugador3D.muerto`): el mundo se desenfoca (`CameraAttributes` o un `ColorRect` con shader de desenfoque sobre el viewport), la UI se oculta, aparece **«Has muerto»** en rojo apagado (#8a2a2a), fuente del grimorio, fundido de 0,6 s, se mantiene 1,5 s, y reaparece en el último guardado con fundido a negro. Nada de botones salvo «pulsa cualquier tecla» tras 2 s.
- **Pipeline:** nada, salvo la fuente si no es la del libro.

---

## 4. Escritura de runas

### 4.1 Asistencia al trazo («el dibujo predice lo que escribes»)
Referencia de Pablo: Runeomicon / Runehaven (trazos que se «limpian» solos). Cómo se hace con lo que hay (`nucleo/gesture_recognizer.gd` es un $P por nube de puntos; `spellbook.gd` captura los trazos):
1. **Reconocimiento incremental:** mientras el trazo avanza, cada ~80 ms se pasa el trazo parcial (normalizado) por $P contra las plantillas **de la página activa** (solo las runas que el jugador conoce: `Repertoire`). Se queda con las 1–2 candidatas por encima de un umbral de confianza.
2. **Guía fantasma:** la candidata líder se dibuja bajo el trazo como línea punteada tenue (el «qué estás escribiendo»); cambia si otra candidata la supera. Con dos candidatas empatadas no se enseña nada (no se guía en falso).
3. **Imán:** el punto del trazo se proyecta sobre el segmento más cercano de la plantilla candidata con una fuerza que crece con la confianza (0 = libre, 1 = pegado), tope 0,6 para que el trazo siga siendo del jugador. Lo que se dibuja es el trazo imantado; lo que se reconoce al soltar es el trazo real (así no nos engañamos).
4. **Cierre:** al soltar, si la candidata líder tiene confianza ≥ umbral se acepta aunque falte un 15 % del recorrido (trazos más cortos, sensación de «lo ha entendido»). El trazo aceptado se **redibuja limpio** con la plantilla (animación de 0,2 s: el trazo tembloroso se endereza) antes de encender la runa.
5. **Ajustable y desactivable:** `asistencia` 0–1 en opciones; con 0 vuelve a hoy. Métrica en `PlayLog`: confianza, tiempo de trazo, corrección aplicada.
- **Propietario:** Juego (`nucleo/gesture_recognizer.gd` + `spellbook.gd`/grimorio). Prueba sin ventana con trazos grabados (ya hay `podar_gestos.py` y plantillas): el reconocimiento de los trazos completos no puede empeorar (misma tasa que hoy), y los parciales al 60 % del recorrido deben dar la candidata correcta en ≥ 80 % de los casos del conjunto de prueba.

### 4.2 Página – mano con pluma – trazo que sigue al ratón
- **Pipeline (assets):** la **mano con la pluma** como sprite 2D por capas (mano, pluma, sombra) o modelo bajo visto desde arriba; 3 poses (reposo sobre la página, escribiendo, levantada entre trazos); la **tinta** como trazo con punta (shader de línea con grosor por velocidad) y salpicadura al soltar; la página con su textura ya existente (`presentacion/ui/laminas`).
- **Juego (lógica):** la mano sigue el cursor con un retraso de 60 ms y una curva (sensación de muñeca), se inclina según la dirección del trazo, la pluma «se levanta» cuando no se pulsa, el trazo se dibuja desde la punta de la pluma (no desde el cursor); conecta con 4.1 (la mano sigue el trazo imantado, no el ratón crudo).

---

## 5. Animación

| # | Mejora | Qué hacer | Propietario |
|---|---|---|---|
| A1 | **Nado: cabeza hundida** | La 94 subió el cuerpo (`NADO_CADERA` 0,93 × cadera de idle) y ya se ve la espalda; si la cabeza sigue hundida: subir `NADO_CADERA` a 1,0–1,05 o bajar `HUNDIDO` (Juego, 0,35 → 0,25) hasta que la cabeza quede fuera; medir con el sandbox del Pipeline. **Alternativa de diseño (Pablo):** nadar deshabilitado hasta conseguir un objeto («aletas»/«perla»): el agua honda es pared hasta entonces (el Juego lo hace con un flag en `Repertoire`/`Estado` y `Jugador3D.puede_nadar`). | Pipeline (clip) · Juego (flag) |
| A2 | **Escritura** | = 4.2 | Pipeline + Juego |
| A3 | **Conjuro coherente: del libro a la mano, y dispara** | Secuencia al lanzar: (1) la runa brilla en la página (0,1 s); (2) una **voluta del elemento** sale del libro y recorre el brazo hasta la mano (0,25 s, `HiloLuz3D` ya existe para hilos de luz); (3) en la mano se forma la bola/forma (0,1 s); (4) sale el proyectil. Total ~0,45 s de «anticipación», con el `Jugador3D` en pose de apuntar. Ajustable por elemento (`RETARDO_CONJURO`); registrar en PlayLog para medir si molesta. Pablo lo afinará: dejarlo parametrizado. | Juego (tiempos y disparo en `Lanzador3D`) · Pipeline (voluta, pose, VFX en mano) |

---

## 6. Laboratorio de fuego (`laboratorios/LabPuzlesFuego3D.tscn`)

Mismo armazón que el de agua (salas de 7 × 7, cartel por sala, botón/placa como vías alternativas, `escenario_puzles_fuego.gd`). El
fuego ya tiene en el juego: quemar hierba y setos con propagación, antorchas/braseros que se encienden, fogata, hielo que se derrite,
evaporar, puerta goblin que arde, barril (nuevo), compuerta de hielo (nueva). Diez puzles, de más a menos seguro:

| # | Puzle | Montaje | Solución | Piezas nuevas |
|---|---|---|---|---|
| F1 | **Enciende las cuatro antorchas** | 4 braseros alrededor de una puerta; un detector cuenta encendidos | Fuego a cada uno (o uno y que el viento lo propague) | `ContadorReactivos3D` (cuenta `is_lit` de una lista; señal `todos(si)`) |
| F2 | **Relé de braseros** | Braseros en fila separados 2 casillas; cada uno enciende al siguiente al cabo de 1,5 s y se apaga a los 6 s | Encender el primero y correr: la puerta solo se abre si el último está encendido **a la vez** que el primero (hay que volver a encender) | `Brasero` con `relé` (ya hay `brasero`; añadir temporizador y «contagia a») |
| F3 | **Quema la cuerda** | Una cuerda sostiene una compuerta levantada / un puente plegado (12.5) | Fuego a la cuerda → cae | `Cuerda3D` (12.5): arde en 1 s, señal `rota` |
| F4 | **Contrafuego** | Hierba seca en línea hacia un barril junto a la puerta; un brasero prende la hierba a los 5 s de entrar | Quemar un tramo ANTES (cortafuegos) para que el fuego no llegue al barril; o aprovecharlo para volar la roca de al lado | propagación ya existe; `Barril3D` |
| F5 | **Derrite el bloque** | Compuerta de hielo que corta el paso; el fuego la derrite y el charco resultante **apaga** la antorcha de abajo (orden importa) | Primero antorcha, luego hielo; o hielo y volver a encender | `Compuerta3D` hielo (hecha) + charco al derretir (`ReaccionesAgua3D` ya hace charco) |
| F6 | **La caldera** | Caldera con nivel de **calor** (análogo a `NivelAgua3D`): sube con fuego cerca, baja sola; la puerta abre con calor ≥ objetivo | Mantener fuego 10 s (brasero al lado o varios hechizos) | `Caldera3D` (calor acumulado, decae `ENFRIA`/s; señal `calor_alcanzado`) |
| F7 | **Alimenta la hoguera** | Fogata que se apaga a los 8 s si no se le echa leña; la leña se recoge (12.1) | Recoger 3 leños y echarlos; mientras arde, la puerta está abierta | `Fogata` con `combustible` (recibe «leño» del inventario, +8 s) |
| F8 | **Luz en la cueva** | Sala oscura; solo se ve lo que iluminan antorchas; el camino correcto se ve al encender la del rincón | Encender antorchas para leer el suelo (baldosas falsas que no se pisan) | `Antorcha` con `OmniLight3D` (Pipeline) + `Baldosa falsa` (cae: ya hay placa/hueco) |
| F9 | **Viento + fuego** | Hierba en dos lados de un río; hay que incendiar el lado lejano | Fuego + viento (dirección) o brasa que vuela: el fuego cruza el agua | ya: `viento` lleva `carried_element` |
| F10 | **Escudo del goblin** (12.6) | Goblin guerrero con escudo de madera | Fuego al escudo: arde y el goblin queda expuesto 6 s | `Combate3D` escudo + animación (Pipeline) |

Piezas nuevas del Juego: `ContadorReactivos3D`, `Caldera3D`, `Cuerda3D`, `brasero.relé`, `fogata.combustible`. Pipeline: caldera, cuerda (3 estados), leño, antorcha con luz, escudo del goblin ardiendo. Las 5 primeras no dependen de nada pendiente: F1–F5 pueden estar en el lab en un día.

---

## 7. Tareas con prompt por responsable

Orden sugerido para el prototipo del nivel 01 (fuego): **Pablo 0 → Juego T1 → Pipeline T4 → Juego T2 → Pipeline T5 → Juego T3 → Pipeline T6**. El resto, después.

### Pablo (decisiones, 10 min)
0. Fase 14 al plan (`docs/PLAN_ARREGLOS.md`) con estas tareas; **12.0** (tronco 2/3, piezas de fuego, tinta en nivel 1 o 2); ¿nadar bloqueado hasta un objeto? (A1); ¿asistencia de runas activa por defecto y con qué fuerza inicial (propongo 0,5)?; permiso para `mapas/PuzlesFuego.txt`.

### Juego
**T1 · Laboratorio de fuego (F1–F5 primero).**
```
Laboratorio de fuego (Fase 14.6, Juego). Lee docs/DIARIO.md (88–96), laboratorios/lab_puzles_agua_3d.gd (el armazón: salas
7×7, carteles, botón/placa como vías alternativas, HUD, teclas) y herramientas/escenario_puzles_agua.gd. Crea
laboratorios/LabPuzlesFuego3D.tscn + lab_puzles_fuego_3d.gd + mundo/datos_nivel/mapas/PuzlesFuego.txt (permiso de Pablo) +
herramientas/escenario_puzles_fuego.gd con los puzles F1–F5 de FASE14_PRESENTACION.md §6 (antorchas ×4, relé de braseros,
cuerda, contrafuego, derretir con orden). Piezas nuevas en objetos/: ContadorReactivos3D (cuenta is_lit de una lista, señal
todos(si)), Cuerda3D (arde 1 s, señal rota, sostiene una Compuerta3D o un PuenteReactivo3D), brasero con relé (contagia al
siguiente a 1,5 s, se apaga a 6 s; en objetos_3d.gd, sin tocar lo que ya hace el brasero). Reutiliza Pulsador3D, Compuerta3D
(hielo), Barril3D y la propagación de fuego existente. Cada puzle con su vía natural y botón/placa; cartel por sala; el
escenario juega los cinco por código y queda en FALLOS 0 con tools\prueba_una.cmd. Después F6–F10 (Caldera3D, fogata con
combustible, luz en cueva, viento, escudo) en una segunda tanda. Diario al terminar con lo que necesita el Pipeline.
```
**T2 · Asistencia a la escritura de runas.**
```
Asistencia al trazo (Fase 14.4, Juego). Lee nucleo/gesture_recognizer.gd ($P), spellbook.gd (captura de trazos),
nucleo/gesture_library.tres, tools/podar_gestos.py y FASE14_PRESENTACION.md §4.1. Implementa: reconocimiento incremental
cada ~80 ms contra las plantillas de la página activa (solo runas conocidas: Repertoire); guía fantasma de la candidata líder
(punteada, tenue; nada si hay empate); imán del trazo hacia la plantilla con fuerza = confianza × asistencia (tope 0,6), el
reconocimiento final se hace sobre el trazo REAL; aceptación anticipada con ≥ umbral y ≥ 85 % del recorrido; redibujado
limpio (0,2 s) al aceptar; opción `asistencia` 0–1 (0 = como hoy) en Estado; PlayLog con confianza, tiempo y corrección.
Prueba sin ventana herramientas/prueba_asistencia.gd con trazos grabados: la tasa de acierto de trazos completos no
empeora; los parciales al 60 % dan la candidata correcta ≥ 80 %. Expón la API (trazo_imantado, candidata, confianza) para
que la mano con la pluma (Pipeline) la siga. Diario.
```
**T3 · HUD: diario de misiones, bolsa, muerte; conjuro del libro a la mano.**
```
HUD y conjuro (Fase 14.3 y 14.5, Juego). (1) nucleo/misiones.gd: misión {id, título, tipo, estado, texto, objetivos,
origen, recompensa}, señal mision_cambio; migrar las tareas de Bosque3D/TerraFina3D a este sistema; guardado. Pantalla
(tecla J / pestaña del grimorio) lista+ficha como el Adventure Log de EoW (FASE14 §3.1), misión seguida con su objetivo en
una línea del HUD. (2) bolsa_ui.gd: rejilla irregular dentro de la silueta de la bolsa (anclas), contador, corazón en los
que curan, nombre bajo la bolsa, orden por categoría, ratón y teclado; usa los PNG del Pipeline (placeholder gris
mientras). (3) Muerte: desenfoque del mundo, UI fuera, «Has muerto» rojo apagado, 0,6 s fundido + 1,5 s, reaparecer en el
guardado. (4) Conjuro: en Lanzador3D, secuencia runa brilla (0,1) → voluta del libro a la mano (0,25, HiloLuz3D) → forma en
la mano (0,1) → disparo; RETARDO_CONJURO por elemento, parametrizado para que Pablo lo afine; PlayLog. Pruebas sin
ventana de misiones y de la bolsa (datos), y escenario del conjuro (el disparo sale ~0,45 s después de soltar). Diario.
```
**T7 · Shader del suelo: bordes entre todos los materiales (P4) y estado SEGADA (P3).** (1 día; después de T1–T3.)

### Pipeline
**T4 · Presentación del escenario (P1, P2, P5 + diorama).**
```
Presentación del escenario (Fase 14.2, Pipeline). Referencia: Zelda Echoes of Wisdom (capturas de Pablo 16/10) y
FASE14_PRESENTACION.md §1–§2. (a) Profundidad de campo tipo diorama: CameraAttributes con desenfoque lejano suave atado a
la distancia al jugador (ajustable, apagable). (b) Falda biselada en cada escalón de altura y borde de agua (tira de 0,3 u
con normales suavizadas) y anillo de piedras por procedimiento en los cambios de altura (cantos 0,3–0,6 u con jitter,
MultiMesh; presentacion/borde_piedras_3d.gd). (c) Paleta cerrada en docs/ARTE.md (hierba ×3, tierra ×2, piedra ×2, agua ×2,
madera, metal), Hierba3D al verde del suelo, adjustment único en el WorldEnvironment, piezas de Meshy tintadas a la paleta.
(d) Agua: prof_rio 0,9 → 1,4 para ver el fondo, lecho con piedras/detalle en vez de bloque liso. (e) Sombra de contacto bajo
las piezas. Probar en escenas/PruebaBosque.tscn y en el lab de agua; capturas antes/después (13.14). Diario con lo que
cambia de contrato (nada del Juego debería cambiar).
```
**T5 · Mano con pluma, tinta y assets de la bolsa/misiones.**
```
Assets de escritura y HUD (Fase 14.4/14.3, Pipeline). (a) Mano con pluma vista desde arriba: sprite 2D por capas (mano,
pluma, sombra) o modelo bajo; 3 poses (reposo, escribiendo, levantada); sigue la API del Juego (trazo_imantado) con 60 ms de
retraso y curva de muñeca; la tinta como trazo con grosor por velocidad y salpicadura al soltar; se integra en spellbook.gd
solo en la capa de dibujo. (b) Silueta de la bolsa (PNG, 2 tamaños) e iconos 2D de los objetos (12.2); banda del nombre.
(c) Pergamino y iconos del diario de misiones (principal/secundaria), fuente del libro. (d) Rastrojo: malla baja de mata
quemada/cortada + mancha, y cambio de visual cuando el Juego marque SEGADA. Diario con nombres de nodo/estado para el Juego.
```
**T6 · Animación: nado, conjuro, escudo del goblin, fuego.**
```
Animación (Fase 14.5, Pipeline). (a) Nado: la cabeza queda hundida; subir NADO_CADERA (0,93 → ~1,0) o pedir al Juego bajar
HUNDIDO; medir en el sandbox con la cabeza fuera del agua. (b) Conjuro: pose de apuntar del Jugador3D, voluta del elemento
del libro a la mano (VFX .tres por elemento) y forma en la mano, con los tiempos que exponga Lanzador3D. (c) Escudo del
goblin que arde (12.6): estados entero/ardiendo/quemado. (d) Assets del lab de fuego: cuerda (entera/ardiendo/rota), caldera
con calor (fría/caliente/al rojo), leño, antorcha con OmniLight3D, baldosa falsa. Diario.
```

---

## 8. Lo que queda fuera a propósito
- Cámara que gira (EoW): no, rompe la línea de tiro de los puzles.
- Rehacer personajes al nivel de EoW: no, es otro presupuesto; la paleta y las sombras dan el 80 % del efecto.
- Minimapa: no hasta tener dos niveles.
