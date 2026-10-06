# Playtest de migración — plan

**Para qué sirve.** Después de cambiar el arte (y, si la prueba 3D sale
adelante, la capa de presentación entera), hay que saber **qué dejó de
funcionar**. Este playtest no mide diseño ni diversión: mide *regresiones*.
Lo que el 4/10 funcionaba tiene que seguir funcionando; lo que no, es un
bug con responsable.

Se juega **dos veces**: una antes de la migración (línea base, sobre el 2D
actual) y otra después. Sin la primera no hay con qué comparar.

Dueño del documento: Pablo. Las tareas de preparación tienen responsable
según `docs/PROPIETARIOS.md`.

---

## 1. Cuándo se puede jugar (condición de entrada)

Ninguna sesión empieza hasta que todo esto esté en verde. Si no, el playtest
mide la preparación, no el juego.

| requisito | responsable | cómo se comprueba |
|---|---|---|
| `Test2.tscn` arranca con F5 sin errores rojos en consola | Juego | consola vacía de `ERROR`; los `WARNING` se cuentan (ver §4) |
| Todos los personajes cargan sin avisos de `MsAtlas` (validación 1.8) o, en 3D, sin materiales rosas ni mallas ausentes | Pipeline | consola al arrancar; captura de la escena entera |
| Plantillas grabadas de los 7 elementos y los 4 glifos base | Juego | `G` en el libro muestra ≥ 4 muestras por gesto |
| PlayLog vuelca a archivo al cerrar (`user://playlog_<fecha>.json`) | Juego | existe el archivo tras salir |
| Teclas de QA activas: `F1` paleta, `F12` panel de mediciones (§4) | Juego | se ven en pantalla |
| Línea base del 4/10 archivada (`playtests/base_2d/`: capturas de las 6 cámaras + `playlog` + tabla de tiempos) | Pablo | carpeta existe |

---

## 2. Qué se prueba: lista de regresión

Cada fila es una prueba de un minuto. Resultado: ✔ igual que la base, ✘
distinto (bug), ~ distinto pero aceptable (anotar). **Quién arregla** sale de
qué falla: si falla el *qué pasa*, Juego; si falla *cómo se ve*, Pipeline;
si falla una *decisión* (un número, una regla), Pablo.

### 2.1 Control y cámara

| # | prueba | esperado | si falla |
|---|---|---|---|
| C1 | WASD en 8 direcciones y diagonales | velocidad igual en todas; sin engancharse en esquinas de casilla | Juego |
| C2 | Shift (salto) sobre un bloque de tierra y bajar | sube, se queda arriba, baja; sin atravesar el muro del mundo | Juego |
| C3 | Espacio (voltereta) con recarga | distancia y recarga iguales a la base; `page_hud` lo muestra | Juego |
| C4 | Cámara en los 4 bordes del mapa | límites respetados, sin ver el vacío | Juego |
| C5 | Orden de dibujado: pasar por detrás y por delante de un árbol, un bloque elevado y un goblin | el personaje queda tapado/visible donde toca | Juego (2D: `y_sort`) / Pipeline (3D: anclas) |

### 2.2 Grimorio y reconocimiento

| # | prueba | esperado | si falla |
|---|---|---|---|
| G1 | `T` abre y cierra; el tiempo se para | goblins y fuego congelados con el libro abierto | Juego |
| G2 | Dibujar los 7 elementos, 3 veces cada uno | ≥ 18/21 reconocidos; los fallos son rechazos, **no** confusiones | Juego (si confunde: regrabar plantillas) |
| G3 | Dibujar los 4 glifos base en 4 sectores distintos | cada uno en su hueco, visible en la página | Juego |
| G4 | Segundo glifo en el mismo sector | rechazado con aviso (regla de un glifo por sector) | Juego |
| G5 | Páginas 1/2/3 y recarga | lanzar la 1 la deja recargando; 2 y 3 siguen disponibles; `1`/`2`/`3` con el libro cerrado lanzan | Juego |
| G6 | Cast point: apuntar con el ratón a 3 casillas y lanzar flecha | el hechizo nace donde dice la decisión vigente (pies / mano / ratón) y va hacia el cursor | Juego (lógica) / Pipeline (si el origen visual no cuadra con el ancla) |

### 2.3 Elementos contra el mundo (una casilla de cada tipo, un impacto)

| # | prueba | esperado | si falla |
|---|---|---|---|
| M1 | fuego → hierba fina | prende 1 s, arde 5 s, ceniza; contagia a la vecina | Juego |
| M2 | agua → hierba ardiendo | se apaga; agua → ceniza rebrota | Juego |
| M3 | rayo → hierba | arde directo, sin fase de prender | Juego |
| M4 | agua → suelo neutro ×2 | mojado, luego hielo; resbala | Juego |
| M5 | hielo → agua; andar encima | casilla helada, se pisa; con `hielo_permanente` no se derrite | Juego |
| M6 | fuego → agua | vapor (hechizo quieto), la casilla no se derrite | Juego |
| M7 | rayo → charca con otra charca a 1 casilla | electrifica las dos; **termina** (sin bucle: el juego no se cuelga) | Juego |
| M8 | tierra (pilar/barrera) → suelo neutro | un bloque por lanzamiento (regla del 4/10); tope FIFO; `disipar` o duración lo deshace | Juego |
| M9 | tierra → agua, luego agua → ese bloque | pasadero; vegetación | Juego |
| M10 | viento sobre hierba ardiendo | lengua de fuego en cono, salta a la vegetación a favor | Juego |
| M11 | viento que cruza fuego y sigue | llega "cargado": prende lo que toca después | Juego |
| M12 | fuego → seto, tronco, telaraña | arden, chamuscados, desaparecen; el seto deja de ser muro | Juego (lógica) / Pipeline (estados visuales) |
| M13 | tótems de rayo, fuego y agua | solo responden a su elemento; el de rayo tiende el puente | Juego |
| M14 | placa de peso con bloque de tierra y con empujable | activa; con el jugador encima, no | Juego |
| M15 | empujable de tierra y de hielo | tierra una casilla, hielo resbala hasta chocar; calor derrite el de hielo | Juego |
| M16 | reagentes (seta, flor, raíz) con dos elementos cada uno | sueltan el ingrediente correcto; rebrotan | Juego |

**Cómo se ve** (misma fila, segunda lectura, Pipeline): ¿la casilla cambia de
aspecto en cada estado (mojado, hielo, ceniza, chamuscado)? ¿el VFX nace en la
cara superior y no flota ni se hunde? Anotar por separado.

### 2.4 Combate

| # | prueba | esperado | si falla |
|---|---|---|---|
| E1 | Guerrero: detección a 300 px, persecución, rendición a 3,5 s | igual que la base | Juego |
| E2 | Arquero: distancia ideal, retroceso, disparo, flecha bloqueada por barrera | igual; `blocks` funciona | Juego |
| E3 | Cada elemento sobre el dummy | efecto y número flotante correctos (tabla de `combate_comun`); rombo de debilidad | Juego |
| E4 | Debilidad ×2 / resistencia ×0,5 | números en pantalla cuadran | Juego |
| E5 | Muerte de guerrero y arquero | clip de muerte completo, cuerpo se queda, botín cae | Juego (`_die`) / Pipeline (clip) |
| E6 | Muerte del jugador | caída completa → "HAS MUERTO" → reaparece en el guardado con vida llena | Juego |
| E7 | Golpe recibido | interrupción ≥ 0,3 s, clip de golpe corto (no un segundo) | Juego / Pipeline |

### 2.5 Sistemas de partida

| # | prueba | esperado | si falla |
|---|---|---|---|
| S1 | Recoger 5 recolectables con `E`; mochila `I` | aparecen, pilas de 9, tope de huecos | Juego (lógica) / Pipeline (iconos) |
| S2 | Comprar en la librera y en el alquimista | oro baja, mejora aplicada, diálogo del tendero | Juego |
| S3 | Encargo del guardabosques (matar 3) | se completa, 100 de oro | Juego |
| S4 | Beber poción con `Q` y con clic | cura; se consume | Juego |
| S5 | Guardar en un punto, morir, volver | posición y vida correctas; mochila conservada | Juego |

### 2.6 Test 2 completo (cronometrado)

Las seis cámaras en el orden del 4/10, con cronómetro. Se apunta el tiempo y
los intentos. La puerta del norte se abre al final.

### 2.7 Animación y arte (Pipeline)

| # | prueba | esperado |
|---|---|---|
| A1 | Andar en las 8 direcciones | mira hacia donde va (este-oeste correctos); pies sin patinar a velocidad normal |
| A2 | Lanzar, golpe, muerte, voltereta | clip correcto, una sola vez, vuelve a idle |
| A3 | Captura de cada cámara del Test 2 | comparada con la base: misma lectura (se entiende qué pide sin rótulo) |
| A4 | Zoom máximo sobre personaje, losa y prop | nada borroso por escalado (regla "textura ≤ 2× píxeles") |
| A5 | Luz: el fuego ilumina (si 3D) / tinte coherente (si 2D) | personaje y suelo con la misma luz |

---

## 3. Sesión libre (15 minutos)

Después de la lista: jugar sin guion, buscando lo que la lista no cubre.
Regla: **cada cosa rara, una línea** en la tabla de bugs, aunque parezca
tontería. No se intenta reproducir en ese momento; se anota y se sigue.

---

## 4. Mediciones

### 4.1 Automáticas (las prepara el Juego, se vuelcan con PlayLog)

| medida | de dónde sale | base 2D (4/10) | tras migración | umbral de alarma |
|---|---|---|---|---|
| ms por fotograma, media y máximo, en la plaza de los goblins | `Performance.TIME_PROCESS` + `PHYSICS_PROCESS` | _rellenar_ | | > 16,6 ms medio o picos > 50 ms |
| memoria de vídeo | `Performance.RENDER_VIDEO_MEM_USED` | | | > 1,5 GB |
| llamadas de dibujado | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | | | > 2× la base |
| tiempo de carga de `Test2` | desde `_ready` hasta el primer fotograma | | | > 2× la base |
| errores y avisos en consola al arrancar | contador en PlayLog | 0 / n | | cualquier `ERROR` |
| gestos reconocidos / rechazados / confundidos | `gesture_recognizer` ya imprime margen; PlayLog lo cuenta | | | confusiones > 0 |
| manifestaciones por hechizo (máximo) | `SpellRecipe.build` | ≤ 48 | | > 48 |
| pruebas del Test 2: segundos e intentos por cámara | PlayLog `"prueba"` (ya existe) | | | > 1,5× la base |

El panel `F12` enseña ms, VRAM y llamadas en pantalla, para mirar sin salir.

### 4.2 Manuales (las rellena Pablo durante la sesión)

| medida | cómo |
|---|---|
| tiempo e intentos por cámara | cronómetro; coincide con PlayLog |
| "¿se entiende qué pide la cámara sin leer el rótulo?" | sí/no por cámara, **antes** de leerlo |
| bugs por severidad | tabla §5 |
| cosas que se ven peor que en la base | lista libre, con captura |

---

## 5. Registro de bugs

Una tabla en `playtests/PLAYTEST_<fecha>.md`, una fila por bug:

| id | dónde (prueba #) | pasos | esperado | real | captura | severidad | responsable | estado |
|---|---|---|---|---|---|---|---|---|

**Severidad:**
- **S1** rompe la partida: cuelgue, no arranca, no se puede avanzar (M7, E6, puerta del Test 2).
- **S2** la mecánica no funciona o funciona distinto a la base (cualquier ✘ de §2).
- **S3** se ve mal pero funciona (anclas, VFX desplazado, clip cortado).

**Responsable** según la columna "si falla" de §2. Si no está claro, Pablo
decide en el triage. Cada bug S1 o S2 entra en `PLAN_ARREGLOS.md` con su
número; los S3 se agrupan en una sola tarea por contexto.

---

## 6. Condición de salida

La migración se da por buena cuando, en una sesión completa:

- **0 S1** abiertos y **≤ 3 S2** abiertos (con tarea asignada);
- todas las filas de §2 en ✔ o ~ (ningún ✘ sin bug registrado);
- ninguna medida automática por encima de su umbral;
- las seis cámaras del Test 2 en ≤ 1,5× el tiempo de la base;
- A3: las seis capturas se leen igual que en la base.

Hasta entonces, cada ronda de arreglos termina con **otra pasada de §2
completa**, no solo de las filas que fallaron: un arreglo en `nivel_base`
rompe cosas que no estaban en la lista de ese día.

---

## 7. Preparación: tareas y responsables

| # | tarea | responsable | antes de |
|---|---|---|---|
| P1 | PlayLog: volcado a `user://playlog_<fecha>.json` al salir; contadores de errores/avisos, gestos (reconocido/rechazado/confundido), manifestaciones máximas, ms/VRAM/llamadas muestreados cada 5 s | Juego | línea base |
| P2 | Panel `F12` con ms, VRAM, llamadas, casillas vivas | Juego | línea base |
| P3 | Script de QA `impactar_en([...])` para reproducir M1–M16 sin jugar (ya existe en la maqueta 3D; portarlo al 2D si no está) | Juego | línea base |
| P4 | Jugar la **línea base** en 2D: §2 completo + §4 + capturas; archivar en `playtests/base_2d/` | Pablo | migración |
| P5 | Capturas de referencia por cámara y por personaje (A3, A1) en la base | Pipeline | migración |
| P6 | Tras la migración: condición de entrada §1 en verde | Juego + Pipeline | sesión |
| P7 | Sesión post-migración: §2, §3, §4.2, tabla §5 | Pablo | triage |
| P8 | Triage: severidad y responsable de cada bug; S1/S2 al plan | Pablo | arreglos |
| P9 | Arreglos por contexto; cada uno cierra su fila con una captura o un `impactar_en` que lo demuestre | Juego / Pipeline | siguiente pasada |

---

## 8. Lo que este playtest no decide

Si una cámara es divertida, si el hielo es un comodín, si relámpago debe ser
fuego + viento: eso es `TEST2_CONCLUSIONES.md` y `DISENO_FUTURO.md`. Aquí
solo se mira si lo que había sigue estando. Mezclar las dos cosas en una
sesión es la forma más rápida de no medir ninguna.
