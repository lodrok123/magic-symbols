# Plan de puzles (22/11/2026)

22/11/2026 · contexto **PUZLES** (sesión nueva, nacida del reparto L1–L8) · **plan para que Pablo decida; nada implementado, sin commit.**

Parte de `CONCEPTO_TEMPORIZADOR_2026-11-21.md`, de «Puzles y mundo» y de L6–L7 en `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`, de `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` y de los planes de combate, hechizos y gamefeel del mismo día. Todo lo que se cita del código se ha vuelto a mirar hoy.

**Coste:** B = pequeño (una tarde), M = medio (una pieza nueva o varios enganches), C = grande (mecánica nueva o toca la simulación).

---

## 0. Resumen y orden propuesto

| # | Punto | Coste | Depende de | Para qué |
|---|---|---|---|---|
| 1 | **L6a · Cuenta atrás visible común** (`CuentaAtras3D`): el aro de tramos que se apagan, el aviso final, el «clac» y el hilo de causa | M | Decisiones 1–5 | Todo lo que dura se lee igual |
| 2 | **L6b · Enganchar las piezas** que ya tienen reloj (brasero con `dura`, pulsador y receptor con `rearme`, trampa y respiradero apagados, lava que vuelve, bloque de tierra) | M | 1 | Que la pieza enseñe su reloj |
| 3 | **X7 · El brasero tras el chorro** (P7), con la opción A del temporizador | B | 1–2 | El primer puzle que lo estrena |
| 3b | **Base de la luz** (§5.1): luz cenital con pedestal, reflejo de la protección de agua, prisma y receptor que aceptan la luz | M | La protección de agua que se mantiene (pregunta 15; toca hechizos y C10) | Una sola base para X10, X11 y X12 |
| 3c | **X10 · Reflejar el rayo de luz** (P11) | B (sobre 3b) | 3b. La difícil, L6b | Apuntar girando. No necesita la plataforma, así que puede ir pronto |
| 3d | **X12 · Alinear los prismas y poner tú el último reflejo** (P13) | B (sobre 3b), casi solo mapa | 3b | Preparar y después ejecutar |
| 4 | **L7a · Reiniciar un puzle**: pieza `reinicio` por sala y `reiniciar()` en las piezas sencillas | M | Decisiones 6–9 | No hay que morir para volver a probar |
| 5 | **P6 · Plataforma móvil** (con el raíl dibujado y la acción `avanzar`) | M (C si la barrera viaja) | Decisión 10 | X5, X6, X8 y X9 |
| 5b | **X9 · Plataformas en raíl sobre el cañón** (P10), primero con la noria de agua | B | 5 | El mismo verbo en cadena, apuntando desde algo que se mueve. Es el puzle que mejor estrena P6: no pide barrera que viaje ni chorro que empuje |
| 5c | **X11 · La luz mueve la vagoneta** (P12) | B (+ P6 y la base de la luz) | 5, 3b | Es X9 + X10: la plataforma con `va=luz` y el receptor encima |
| 6 | **X5 · Plataforma bajo el dragón** (P1) | B | 5, B2 de combate | Protegerse mientras te llevan |
| 7 | **X8 · Tres braseros y las plataformas** (P9) | M | 5; el chorro que empuja es la trampa dragón con `elemento=agua` (decidido, pregunta 12) | Moverse, protegerse y disparar |
| 8 | **X6 · La mecha suspendida** (P4) | B–M | 5, **decisión 11 (ᛉ no está en la demo)** | Dejar un hechizo en el camino |
| 9 | L7b · Reinicio de lo que se gasta (barril, cuerda, puente) | B–M | 4 | Salas con consumibles |
| 10 | L6c · Pieza `temporizador` (opción B) | M | Un segundo puzle que la pida | Puertas, puentes y plataformas con tiempo |
| — | P2 (una sala por glifo) y P3 (sala de prácticas) | M | El diseño de la mazmorra de los glifos (Pablo) | Ver §6 |

Va primero lo común (1–2), luego el puzle que lo estrena (3), y la plataforma móvil (5) antes que los cinco puzles que la piden (X5, X6, X8, X9 y X11). **X9 (añadido el 22/11) es otro motivo para subir P6**: es el más barato de los cuatro una vez hecha la plataforma, así que va justo detrás (5b) y sirve de banco de pruebas de P6 antes de X5 y X8, que además dependen de combate.

---

## 1. Inventario de los relojes que ya hay

Hoy cada pieza lleva su propio reloj y casi ninguna lo enseña.

| Pieza | Qué cuenta | Dónde | Se ve | Al volver a disparar | Observaciones |
|---|---|---|---|---|---|
| **Brasero con relé / `dura`** | Enciende al siguiente a los `espera` s (1,5) y se apaga a los `dura` s (6) | `objetos/objetos_3d.gd:228-235`, `:1286` (`configurar_rele`), `:1297` (`_avanzar_rele`); se monta en `escenas/puzle.gd:2855-2864` | No | **No reinicia.** Un brasero que ya arde ignora el fuego: `_encender` solo pone `_t_rele = 0` al encenderse (`:1263-1266`) | Choca con la regla 4 del concepto («volver a disparar reinicia»). Va en `_process`, no en `_physics_process` |
| **Pulsador con `rearme`** | Vuelve a estar libre a los `rearme` s | `objetos/pulsador_3d.gd:32-49`, `:163`, `:235-237`; `escenas/puzle.gd:2243` | No | Mientras está activo no se vuelve a pulsar | Lo usan `PuzlesFuego.txt`, `PuzlesAgua.txt` y las cuevas |
| **Receptor con `rearme`** | Se apaga solo a los `rearme` s y quita su flag | `objetos/receptor_pulso_3d.gd:28-32`, `:117-148`; `escenas/puzle.gd:2708` | No | Un pulso nuevo pone `_t_rearme = rearme` (`:125`): sí reinicia | Ya quita la flag al apagarse (13/11) |
| **Trampa de pared / dragón / flechas apagada** | `apagar(s)`: `s` segundos sin disparar (agua o hielo: 8 s) | `objetos/trampa_pared_3d.gd:24`, `:241-262`; la regla en `escenas/puzle.gd:3672` | No | `maxf(_apagada_t, s)`: **alarga hasta el mayor**, no suma | La trampa dragón **ya avisa antes de escupir** (`AVISO_S` = 0,5 s: retrocede, abre la boca, brasas; `trampa_dragon_3d.gd:5`, `:21`). **Se duerme lejos de la jugadora** (`cerca`, `trampa_pared_3d.gd:275`) y entonces vuelve al reposo |
| **Respiradero (setas) apagado** | `apagar(s)`; agua o hielo, 8 s | `objetos/respiradero_3d.gd:42`, `:402-416` | No | Igual que la trampa | |
| **Lava que vuelve** | La roca vuelve a ser lava a los `vuelve` s | `escenas/puzle.gd:64-65`, `:2292`; `objetos/lava_3d.gd` | La roca deja de brillar a los 4 s (`T_ENFRIAR`), pero no avisa de que vuelve | — | |
| **Bloque de tierra (y columnas, hielo de hechizo)** | Tierra 25 s; columnas e hielo 20 s | `magia/lanzador_3d.gd:99` (`AVISO_CADUCA` = **3,0 s**), `:2730`, `:2917-2925` | **Sí: parpadea los últimos 3 s** a 6 Hz | Hay tope de bloques; uno nuevo no alarga el viejo | La única convención de aviso que existe. **Ojo: el concepto propone 0,8 s y la tierra usa 3 s** (decisión 3) |
| **Barril (mecha)** | `T_MECHA` 1,2 s (pequeño 2,4 s) | `objetos/barril_3d.gd:22`, `:46`, `:207-218` | **Sí: la mecha se encoge** (`mecha_restante`) | El agua la apaga | Otra cuenta visible que ya existe: la llama que se encoge del concepto (§4) |
| **Hielo de cuenca por regla** | `helar(s)` | `escenas/puzle.gd:240`, `:3710` | No | — | Va con el reloj del nodo Puzle3D |
| Estados del suelo | Helada 20, electrificada 6, quemada 8, mojada 20, escombro 6, vapor 4, pegajosa 6 s | `mundo/estados_suelo_3d.gd:149` (`DURA`) | El propio suelo | — | **Propongo no ponerles aro**: son decenas de casillas y ya se leen por su aspecto (memorias de suelo legible) |
| Otros relojes de ambiente | Molino 6 s (`molino_3d.gd:14`), cristal cargado 20 s (`cristal_pulso_3d.gd:34`), nexo y objetos mojados 30 s y 12 s | — | No | — | Fuera del alcance de L6 salvo que un puzle los pida |

**Tiempo del juego (regla 6 del concepto).** Todos estos relojes cuentan con el `delta` del motor, así que ya van más despacio cuando algo baja `Engine.time_scale` (`nucleo/guardia_tiempo.gd`). Falta comprobar que el libro abierto ralentiza con `time_scale` y no con otro mecanismo: se mira en la prueba de L6a.

---

## 2. L6 · Temporizador común legible (es P8)

Lo que tiene que comunicar: **activación, tiempo restante, aviso de final, reinicio o prolongación, y fin**, y que se vea **qué lo activó y qué cambió**, aunque esté lejos.

### L6a · `CuentaAtras3D`: la presentación común (va primero)

- **Qué:** un nodo que cualquier pieza con duración cuelga de sí misma. API: `empezar(dura, aviso)`, `prolongar(dura)` (vuelve a llenar el aro), `parar()`, `fraccion()`, y las señales `aviso` y `acaba`.
- **Cómo se ve:**
  - **Activación:** el aro nace con una onda corta y, a la vez, sale un **hilo de luz** del disparador a lo que cambia, con un destello en el destino. El hilo ya existe: es el del tótem guardián (`objetos/guardian_barrera_3d.gd:17`, `T_HILO` 0,45 s).
  - **Tiempo restante:** un aro de runas en el suelo, alrededor del disparador, dividido en tramos que se apagan uno a uno (decisión 5: cuántos tramos).
  - **Aviso:** el último tramo parpadea al ritmo de la tierra (`lanzador_3d.gd:2730`) y suena un tic que se acelera.
  - **Reinicio o prolongación:** el aro se vuelve a llenar de golpe, con un destello corto.
  - **Fin:** un «clac» y un destello en lo que vuelve (la trampa que se enciende), y el hilo una última vez, para que se entienda la causa.
- **Reaprovecha:**
  - El aro y el parpadeo del aviso de ataque (`enemigos/aviso_ataque_3d.gd`, `ajustar()`), que ya se dibuja en el suelo.
  - El hilo del tótem guardián.
  - El ritmo de parpadeo de la tierra.
  - Un sonido del catálogo de Sfx para el tic y el clac (hay que elegirlo; si no hay ninguno que valga, se pide).
- **Riesgo conocido** (nota de la sesión de gamefeel): los avisos se pintan con `render_priority` 2, por debajo de FuegoToy (3). Un aro junto a un brasero encendido podría quedar tapado por la llama. Se mira en las fotos y, si pasa, se sube la prioridad solo del aro.
- **Archivos:** `presentacion/cuenta_atras_3d.gd` (nuevo, `class_name CuentaAtras3D`). Tras crearlo, un `--import` sin ventana para la caché de clases (como hizo combate con sus clases nuevas).
- **Coste:** M.
- **Prueba:** `herramientas/prueba_cuenta_atras.gd`, sin ventana:
  - Con `dura` 2,5: a los 1,25 s queda la mitad de los tramos.
  - `aviso` salta cuando quedan los segundos del aviso (decisión 3), y `acaba` a los 2,5 s, una sola vez.
  - `prolongar` vuelve a llenar el aro; `parar` lo quita sin emitir `acaba`.
  - Con `Engine.time_scale` 0,3 dura 2,5 s del juego (≈ 8,3 s reales).
  - Con el libro abierto, igual.
- **Fotos:** con la herramienta de capturas de siempre, el aro lleno, a medias y en el aviso, con un brasero encendido al lado (para el riesgo de la prioridad).

### L6b · Enganchar las piezas que ya tienen reloj

- **Qué:** cada pieza, al empezar su cuenta, llama a `CuentaAtras3D` y le dice qué cambia (para el hilo). Son unas pocas líneas en cada una; la lógica de cada reloj no se toca.
- **Piezas:** brasero con `dura`, pulsador y receptor con `rearme`, trampa y respiradero con `apagar(s)`, lava con `vuelve`, y el bloque de tierra (el parpadeo actual pasa a ser el aviso común, con el mismo ritmo).
- **Dos arreglos de reglas** (los dos los pide el concepto):
  - **El brasero que ya arde reinicia su cuenta** si le vuelve a llegar fuego (regla 4). Hoy lo ignora (`objetos_3d.gd:1263`).
  - La trampa apagada que se vuelve a apagar **vuelve a la duración completa** (hoy coge el mayor de los dos, que en la práctica es lo mismo; solo hay que avisar con el aro).
- **Archivos:** `objetos/objetos_3d.gd`, `objetos/pulsador_3d.gd`, `objetos/receptor_pulso_3d.gd`, `objetos/trampa_pared_3d.gd`, `objetos/respiradero_3d.gd`, `objetos/lava_3d.gd` y `magia/lanzador_3d.gd` (solo el parpadeo, `:2730` y `:2925`). **Ojo:** combate ha tocado hoy `lanzador_3d.gd` (`solidez_en`) y `escenas/puzle.gd`. Se edita cuando no lo estén tocando y se avisa en el DIARIO.
- **Coste:** M.
- **Prueba:** `herramientas/prueba_cuenta_atras.gd`, bloque 2. Un mapa de texto con un pulsador `rearme=4`, un brasero `dura=3`, una trampa `apagar(2.5)` y una lava `vuelve=5`. Cada una saca su aro al empezar, el aro acaba cuando la pieza vuelve, y el brasero que recibe fuego otra vez reinicia la cuenta. Se repasan los escenarios que ya existen de esas piezas (`escenario_puzles_fuego_nuevos`, `escenario_puzles_agua_nuevos`) para ver que siguen dando 0 fallos.
- **Dónde verlo:** con ventana, en `LabPuzlesFuego3D`, en las salas que ya tienen pulsador con rearme y relé (F2).

### L6c · La lógica común (opción B), solo si hace falta

- **Opción A (recomendada para empezar):** la duración va en la acción que ya admite segundos (`hace=tr_x7.apagar(2.5)`) y el brasero lleva `dura=2.5`. X7 sale con L6a y L6b.
  - **El problema de A:** son dos relojes que hay que poner iguales a mano. Si el brasero se reenciende, la trampa no se entera.
- **Opción B:** la pieza lógica `temporizador` con `empieza`, `aviso`, `acaba`, `empezar`, `parar` y `muestra=<pieza>`, como en el concepto. Un solo reloj manda en todo lo que cambia.
- **Recomendación:** A para X7. **B en cuanto un segundo puzle tenga dos o más cosas que cambian con el mismo tiempo**, o cuando una puerta o un puente tengan que durar N segundos. Con L6a hecho, B es poca cosa: el reloj ya existe y solo falta la pieza en `escenas/puzle.gd`.
- **Coste:** B (A) o M (B).

---

## 3. L7 · Reiniciar un puzle sin morir

### Lo que ya existe

- **El bloque y la roca empujables** se rehacen solos en su casilla si se quedan atascados sin remedio (3 s, `objetos/bloque_empujable_3d.gd:51`, `_reaparecer` `:563`, señal `reaparecio`; en el mapa, `reaparece`, `escenas/puzle.gd:337-338`). La función es privada.
- **Morir y reintentar (G1 de combate, ya hecho hoy):** `Puzle3D.al_reaparecer` (`escenas/puzle.gd:1474`) retira avisos y proyectiles, rehace los encuentros (vigías) con su receta, abre los cerrojos y duerme al dragón. **Los puzles no se tocan.** L7 se apoya en esto: misma regla (lo permanente se queda, lo de paso vuelve) y mismo sitio del código.
- **Volver a un sitio seguro:** `Jugador3D._volver_a_suelo_seguro` (`jugador/jugador_3d.gd:1636`) ya busca la casilla pisable más cercana cuando se cae de una plataforma ᛒ.
- **Los laboratorios** recargan la escena entera con R (`lab_puzles_fuego_3d.gd:335`). Sirve para probar, no dentro del juego.

### La propuesta

- **Una pieza `reinicio` por sala**, solo en las salas donde un error obliga a dar la vuelta:
  `; pieza r_f2 reinicio 3 9 zona=2,2..12,9 entrada=3,10`
  Es visible: una losa o runa en la entrada (decisión 6: cómo se activa).
- **Al activarse:** un destello que recorre la zona (con el mismo lenguaje del aro), y entonces:

  | Qué hay en la zona | Qué pasa |
  |---|---|
  | Bloques y rocas empujables | Vuelven a su casilla (la `_reaparecer` que ya existe, hecha pública) |
  | Braseros, setos, fogatas | Vuelven a como nacieron (encendidos o apagados) y paran el relé |
  | Pulsadores y receptores | Libres; el receptor quita su flag, como ya hace al apagarse |
  | Trampas y respiraderos | Encendidos y con su ciclo desde el principio |
  | Lava | Vuelve a ser lava |
  | Compuertas y puertas de puzle | A su estado del mapa, salvo que su flag diga que están resueltas |
  | Estatuas y secuencias | A cero (las estatuas ya lo hacen al fallar) |
  | Temporizadores (L6) | Se paran sin emitir `acaba` |
  | Estados del suelo de la zona | Se quitan (`EstadosSuelo3D.poner(c, e, false)`) |
  | Hechizos que la jugadora ha dejado en la zona (tierra, barreras, plataformas ᛒ, hielo, suelos ᛒ) | Se retiran |
  | **Flags, cofres abiertos, rompibles rotos con flag, puzles resueltos** | **Se quedan** |
  | La jugadora | A la casilla `entrada` |

- **Cómo:** cada tipo de pieza guarda su estado al montarse y aprende `reiniciar()`. `Puzle3D.reiniciar_zona(zona)` recorre `_orden` y llama a `reiniciar()` en lo que está dentro y no es permanente.
- **Morir dentro (decisión 7):** si se muere en una sala con `reinicio`, `al_reaparecer` llama también a `reiniciar_zona`. Es **una línea en el código de combate**: se le pide a esa sesión o se pone con su permiso.
- **Lo que se queda fuera de L7a:**
  - **Lo que se gasta** (barril explotado, cuerda quemada, puente caído): necesita rehacer la pieza desde una receta, como hace el vigía con sus enemigos. Es L7b.
  - **El agua de la simulación** (cauces, cuencas, niveles): devolverla a como estaba no es trivial. Propongo dejar los puzles de agua sin reinicio por ahora (decisión 8). En la mayoría el agua se puede volver a soltar o vaciar.
- **Archivos:** `escenas/puzle.gd` (pieza `reinicio`, `reiniciar_zona`, la línea en `al_reaparecer`), un `reiniciar()` en cada pieza de la tabla (`objetos/bloque_empujable_3d.gd`, `objetos_3d.gd`, `pulsador_3d.gd`, `receptor_pulso_3d.gd`, `trampa_pared_3d.gd`, `respiradero_3d.gd`, `lava_3d.gd`, `compuerta_3d.gd`, `estatuas_pulso_3d.gd`), `magia/lanzador_3d.gd` (retirar lo plantado en una zona) y el dibujo de la losa (primitivas primero).
- **Coste:** L7a M; L7b B–M; el agua, C (aparcado).
- **Prueba:** `herramientas/prueba_reiniciar_puzle.gd`, sin ventana. Un mapa de texto con todo lo de la tabla:
  - Mover el bloque, encender el brasero, pulsar el pulsador, apagar la trampa, dejar un bloque de tierra y poner una flag de «resuelto».
  - Reiniciar.
  - Comprobar que todo vuelve a su estado del mapa, que la flag sigue puesta, que no queda ningún temporizador en marcha, que la jugadora está en `entrada` y que el puzle se puede volver a resolver entero.
  - Y lo mismo muriendo dentro (con el `escenario_reintentar.gd` de combate al lado, que tiene que seguir dando 0 fallos).
- **Dónde verlo:** con ventana, en `LabPuzlesFuego3D`, con una losa de reinicio en la sala F2 (relé) y en la de la pólvora (F10).

### Salas candidatas (Pablo decide, decisión 9)

| Sala | Por qué hace falta | ¿L7a basta? |
|---|---|---|
| F2 Relé de braseros (laboratorio, Bosque 01) | Si la llama corre mal, hay que esperar a que se apaguen todos | Sí |
| C8 Derrumbe dirigido (Cuevas, propuesto) | La columna caída al lado malo «deja el paso cerrado hasta reiniciar» | No: la columna caída es de las que se gastan (L7b) |
| F10 Lleva la pólvora | El barril explota donde no era | No: L7b |
| C7 Balanza de la mina | Rocas mal colocadas en una esquina | Sí (rocas empujables) |
| X6, X8, X9, X11 (con plataforma) | La plataforma se va sin la jugadora o con el brasero apagado | Sí, si la plataforma aprende `reiniciar()` |
| Puzles de agua (Q2, R1–R4…) | Agua soltada antes de tiempo | No (decisión 8) |

---

## 4. P6 · Plataforma móvil

Ninguna pieza lleva a la jugadora, pero casi todo lo necesario ya existe:

- **La plataforma ᛒ de tierra sobre el vacío.** La jugadora ya sabe estar encima de una casilla de foso si está en `Terreno3D.plataformas_tierra` (`jugador/jugador_3d.gd:1549`). Si la plataforma desaparece, cae (`caer_de_plataforma`, `:1627`) y vuelve sola al borde seguro más cercano sin daño (`_volver_a_suelo_seguro`, `:1636`). Es justo lo que pide X8: «que caer devuelva al borde con poco daño».
- **La balsa** (`objetos/balsa_3d.gd`) ya recorre una `ruta` de casillas a `vel` u/s y **lleva un objeto encima** (`llevar(nodo)`, hoy un cofre), moviendo también la casilla que bloquea. No lleva a la jugadora y solo se mueve con agua de la simulación.

**La propuesta:** una pieza `plataforma` que junta las dos cosas.

`; pieza pl_x5 plataforma 3 4 ruta=3,4+4,4+5,4+6,4 vel=1.5 va=sola|placa|orden espera=1 lleva=<id> rail=si`

- Avanza por la `ruta` como la balsa, pero con su propio motor, sin depender del agua. `va=placa`: se mueve mientras se pisa una placa y vuelve al soltarla (X6). `va=sola`: va y viene, esperando `espera` s en cada punta (X5, X8). `va=orden` (X9): está quieta en una punta y hace **un viaje entero** a la otra cuando una regla le manda `avanzar`; otro `avanzar` la devuelve. `va=luz` (X11): lleva un receptor encima y **avanza por la `ruta` mientras ese receptor recibe luz**, a velocidad constante y en el sentido de la vía; se para al perderla y se queda en la punta al llegar. Las variantes de otro elemento (chorro de agua, brasero) son el mismo modo con otro receptor (§8).
- **El raíl** (X9) lo dibuja la propia plataforma con `rail=si`: vigas a lo largo de su `ruta` y topes en las puntas, de modo que el recorrido se ve antes de moverla. Sale de la `ruta` que ya tiene, así que no hace falta una pieza `rail` aparte (si Pablo la prefiere separada, para poner raíles sin plataforma, es poca cosa más).
- **La acción `avanzar`** se dispara con las reglas de siempre, como «botón apaga trampa»: `; puzle x9a cuando=noria_1.girando hace=pl_1.avanzar`. La condición `girando` del molino y `activado` del receptor ya existen.
- En cada paso, su casilla entra en la lista de plataformas y la anterior sale. Si la jugadora está encima, se mueve con ella. Si se baja al foso, cae y vuelve al borde, como hoy.
- `lleva=<id>` usa la `llevar` de la balsa para un brasero (X6) o un cofre.
- **Lo difícil, aparte:** que **una barrera viaje con la plataforma** (X5). Hoy lo que se levanta se queda en su casilla del mundo (`lanzador_3d.gd`, barreras por casilla). Hay dos caminos:
  - (a) Que la barrera alrededor de la jugadora se mueva con ella mientras dure. Es lo natural en X5, pero toca el lanzador y la sesión de hechizos (C).
  - (b) Que la plataforma tenga un parapeto propio en un lado y la barrera solo haga falta en el otro (B).
- **Archivos:** `objetos/plataforma_movil_3d.gd` (nuevo), `escenas/puzle.gd` (pieza), `jugador/jugador_3d.gd` (seguir a la plataforma: pocas líneas junto a `_vertical`) y quizá `mundo/terreno_3d.gd` (una lista propia de plataformas móviles para no pisarse con las ᛒ del lanzador).
- **Coste:** M; C si la barrera viaja (camino a).
- **Prueba:** `herramientas/prueba_plataforma_movil.gd`, sin ventana:
  - Recorre la ruta en el tiempo esperado y espera en las puntas.
  - La jugadora encima llega al otro lado sin caerse.
  - Bajarse sobre el foso hace caer y volver al borde, sin daño.
  - El brasero que lleva sigue encendido y se mueve con ella.
  - Con `va=placa`, se para al soltar la placa.
  - Con `va=orden`, un `avanzar` hace un viaje entero y para en la otra punta; un `avanzar` en marcha no hace nada.
  - Con `va=luz`, avanza solo mientras su receptor recibe luz (en la prueba, encendiendo y apagando la luz a mano) y se para en cuanto la pierde.
  - `reiniciar()` la devuelve al principio.
- **Dónde verlo:** sala nueva en `LabPuzlesFuego3D` (no se hace un laboratorio nuevo).

---

## 5. Los puzles propuestos

| Id | Puzle | Necesita | Ya existe | Falta | Coste | Kit en ese punto de la ruta | Prueba |
|---|---|---|---|---|---|---|---|
| **P7 · X7** | El brasero tras el chorro | L6a+b, trampa dragón, brasero `dura` | La regla `cuando=<brasero>.encendido hace=<trampa>.apagar(2.5)`; la trampa dragón (ninguna sala la usa) | **Comprobar** que la bola de fuego cruza el chorro sin apagarse (`HechizoVivo._cruzar_zonas`); que la trampa no se duerma (`cerca`) mientras la jugadora corre hacia ella | B | Fuego basta: vale para la primera pasada del Bosque | `escenario_x7.gd`: disparar al brasero a través del chorro, se apaga 2,5 s, cruzar a 3 u/s llega con margen, al acabar vuelve. Versión con flecha de agua: no pasa (caso ineficaz) |
| **P1 · X5** | Plataforma bajo el dragón | P6, barrera que para el chorro | `jugadora_en_chorro()` ya corta el chorro en lo sólido (`trampa_dragon_3d.gd:340-358`) | Que las casillas de la barrera cuenten como sólidas para el chorro; que la barrera viaje (§4); B2 de combate (qué barrera para qué chorro: la de fuego no para fuego) | B (+ P6) | Barrera de tierra o de agua: **Cuevas o Pantano**, no el Bosque | `escenario_x5.gd`: en la plataforma sin barrera recibe daño; con barrera de tierra, 0; la variante del ritmo justo también se puede pasar |
| **P9 · X8** | Tres braseros y las plataformas | P6, contador de braseros, chorro que empuja, barrera que aguanta el empuje | `contador`; el empuje de la jugadora (`Jugador3D.push`, D1 de combate) | El chorro que empuja: la trampa dragón **ya admite `elemento=`** en el mapa (`escenas/puzle.gd:511`); falta que con agua **empuje** en vez de herir (un parámetro, no una pieza nueva). Y que la barrera aguante el empuje | M (+ P6) | Fuego + barrera de tierra o agua | `escenario_x8.gd`: sin barrera el chorro la tira de la plataforma y vuelve al borde; con barrera aguanta; el tercer brasero solo se enciende desde la plataforma |
| **P4 · X6** | La mecha suspendida | P6 con `va=placa` y `lleva`, bola de fuego quieta con permanencia, muro en medio | `llevar` de la balsa | **ᛉ permanencia no está en el kit de la demo y no cabe en el primer libro** (nota de la sesión de hechizos; memoria «glifos sin progresión»). Comprobar que un brasero que pasa por una zona de fuego viva se enciende | B–M (+ P6) | Depende de la decisión 11 | `escenario_x6.gd`: desde la placa no hay línea de tiro; la bola quieta enciende el brasero al pasar; sin bola, la puerta no se abre |
| **P10 · X9** | Plataformas en raíl sobre el cañón (MAGES O19; PROPUESTAS «P10 · X9») | P6 con `va=orden` y `rail=si`; un receptor por parada | **La noria** es el molino que ya existe (`objetos/molino_3d.gd`: gira 6 s con agua, condición `girando`); el `receptor` de elemento; el brasero (`encendido`); las placas de peso para el contrapeso de tierra; caer al foso ya devuelve al borde sin daño | La plataforma (P6) y la acción `avanzar`. Comprobar que se puede apuntar a la noria **desde una plataforma en marcha** (la puntería y el lanzamiento con la jugadora moviéndose sin andar) | B (+ P6) | **Agua (noria), decidido para la primera versión.** Ruinas o Pantano (pregunta 14, abierta). El brasero, el contrapeso y el molinete de viento quedan para después (§8) | `escenario_x9.gd`: cuatro tramos encadenados; regar la noria mueve su plataforma con la jugadora encima hasta el pilar siguiente en ~3–4 s; desde allí se alcanza la noria siguiente; un pilar con dos raíles, y uno lleva al cofre; caer al foso devuelve al pilar |
| **P11 · X10** | Reflejar el rayo de luz (MAGES O24; PROPUESTAS «P11 · X10») | Un pedestal con luz cenital; la protección de agua de la jugadora como espejo; el rayo sale hacia donde mira y se corta en lo sólido; receptor (y prisma en la media) | El `receptor` (activarse y poner flag); el `prisma` (gira 90° con un golpe o E); el `cristal` como base del emisor; **el rayo que se corta en lo sólido** ya lo calcula la trampa dragón (`largo_chorro_u`, `trampa_dragon_3d.gd:340-358`) y se dibuja como el haz ᛁ, relanzado cada pocas décimas como hace el chorro | **El pulso no sirve tal cual**: avanza solo por lo que conduce (agua, vetas, nexos) y por el aire solo toca la casilla de al lado (`objetos/pulso_3d.gd:9-17`). Así que la luz es un rayo propio y el receptor y el prisma tienen que aprender a recibirlo (o recibir un pulso que se les entrega por el rayo). Falta también la luz cenital con su pedestal, y que la protección de agua dure lo que se mantiene. La versión difícil sale casi gratis con L6b: el receptor con `rearme` ya enseña su aro | M | **Agua**: Ruinas (agua) o Pantano. La variante de hielo, la de Mystralia, queda para después (§8) | `escenario_x10.gd`: sin protección, la luz no sale; con la de agua en el pedestal, el rayo sale hacia donde mira; girando se acierta el receptor y se pone su flag; un muro corta el rayo; en la media, el rayo al prisma lo reemite al receptor y girar el prisma cambia el destino; en la difícil, el primer receptor (`rearme`) se apaga con su aro si no se llega al segundo a tiempo |
| **P12 · X11** | La luz mueve la vagoneta (MAGES O25; PROPUESTAS «P12 · X11») | P6 con `va=luz`; el rayo de X10; un receptor encima de la plataforma; prisma | Prisma y receptor; lo que haga X10 (rayo, reflejo de la jugadora) | El modo `va=luz` y un receptor que **viaja** con la plataforma (hoy el receptor bloquea y vive en su casilla). **El rayo tiene que recalcularse muy a menudo** (cada fotograma o cada ~0,1 s), no cada 0,8 s como el chorro de la trampa dragón, porque el blanco se mueve y la jugadora lo va siguiendo | B (+ P6 y X10) | Agua (el reflejo de X10). Mismo bioma que X10 | `escenario_x11.gd`: con luz en el receptor de la vagoneta avanza a su velocidad; al cortarla (un muro, o la jugadora que deja de mirar) se para; la cadena fuente → prisma → reflejo de la jugadora → vagoneta la lleva al final, donde hace de puente o de llave |
| **P13 · X12** | Alinear los prismas y poner tú el último reflejo (MAGES O26; PROPUESTAS «P13 · X12») | La base de la luz (§5.1); uno o dos prismas; un receptor con regla que abre una puerta | El prisma (gira 90° con E o con un golpe y **se queda donde se deja**, `escenas/puzle.gd:132`); el receptor y la regla de puerta | Nada propio: todo está en la base de la luz. El diseño de la sala tiene que obligar al orden (la jugadora no alcanza el prisma desde donde refleja) | B, casi solo mapa | Agua (el reflejo). Mismo bioma que X10 | `escenario_x12.gd`: con el prisma mal girado, el reflejo no llega al receptor; girado bien, sí, y la puerta se abre; desde el sitio del reflejo no se llega al prisma con E; versión difícil con dos prismas en cadena |
| P8 | Temporizador común | — | — | Es L6 (§2) | — | — | — |
| P6 | Plataforma móvil | — | — | §4 | — | — | — |
| P2 | Una sala por glifo, con pista de pago | El diseño de la mazmorra de los glifos (Pablo) | Las pistas de pago | — | M | — | Después del diseño |
| P3 | Sala de prácticas en el mundo (probar páginas sin gastar tinta) | Un interruptor de «sin tinta» por zona | El laboratorio de hechizos tiene algo parecido | — | M | — | Después de P2; puede ir en el tutorial (TU1) |
| P5 | Puente sobre agua | — | — | Solo referencia: la sensación va en T3 | — | — | — |

### 5.1 La familia de la luz: una base y tres puzles

X10, X11 y X12 son **tres variantes de la misma base**. Se construye la base una vez y cada puzle es, sobre todo, mapa.

**La base (paso 3b, coste M):**
1. **Luz cenital con pedestal:** un haz que baja del techo a la casilla del pedestal. Pieza nueva; el emisor puede salir del `cristal`.
2. **Reflejo de la jugadora:** con la protección de agua en el pedestal, sale un rayo hacia donde mira. Se corta en lo sólido con el cálculo del chorro de la trampa dragón (`largo_chorro_u`) y se dibuja como el haz ᛁ. Se recalcula a menudo (cada ~0,1 s), porque X11 lo pide.
3. **Prisma y receptor que aceptan la luz:** el prisma reemite el rayo hacia donde mira y el receptor se activa mientras lo recibe. El pulso no sirve tal cual, porque no viaja por el aire (`objetos/pulso_3d.gd:9-17`).
4. **Receptor que puede ir encima de una plataforma** (solo para X11).
5. **Una función común para trazar el rayo**, que usan la luz cenital y también los enemigos (petición de combate, 22/11: la mirada del **Basilisco**, X3 de `PLAN_COMBATE_2026-11-22.md`, se refleja en la protección de agua con la misma regla y, si le vuelve, lo petrifica). Así no se duplican reglas:
   - `nucleo/rayo_luz.gd`, `class_name RayoLuz`, sin estado (como `Contacto`):
     `static func trazar(desde: Vector3, dir: Vector2i, alcance: int, lanz: Lanzador3D, emisor: Node = null) -> Dictionary`
   - Devuelve `{"tramos": [[a, b], …], "acaba": "receptor" | "nodo" | "muro" | "alcance", "nodo": <lo golpeado o null>, "reflejos": n}`. Los `tramos` sirven para dibujarlo; `acaba` y `nodo`, para la lógica.
   - **Avanza por casillas** en las 4 direcciones (pregunta 15). En cada casilla mira, en este orden: lo sólido del terreno (corta: `muro`); las barreras y la burbuja con la tabla de contacto (abajo); un prisma (cambia la dirección a la suya); la jugadora con su protección de agua (cambia la dirección a la de su mirada); y lo que sepa recibir la luz (`on_luz(resultado)`: receptor, Basilisco…), que la para (`receptor` o `nodo`).
   - **Sin bucles:** como mucho 8 reflejos, y no se repite una pareja casilla + dirección. `emisor` no se golpea a sí mismo en su primera casilla.
   - **Qué hace cada barrera con la luz:** lo decide `Contacto`, con un tipo de proyectil nuevo, `luz`, para que esté en la misma tabla que el aliento del dragón y las flechas. Propuesta (pregunta 16):

     | Barrera | Luz |
     |---|---|
     | Tierra | `para` (corta) |
     | Agua (barrera o burbuja) | `refleja` (acción nueva: sale hacia donde mira quien la lleva; si no la lleva nadie, hacia atrás) |
     | Fuego | `pasa` (la luz atraviesa la llama) |
     | Viento (fuera de la demo) | `pasa` |
     | Hielo (después de la demo) | `refleja`, como en Mystralia |

     **Ya está en `nucleo/contacto.gd`** (lo puso combate el 22/11; comprobado: filas `luz` en `TABLA` y la acción `refleja` en el catálogo; la burbuja usa la misma fila). Reflejar **no gasta** la barrera (`gasto` = 0) y sí protege. Se llama con `Contacto.accion(elemento, "luz", es_burbuja)`; la dirección de salida la resuelve `RayoLuz.trazar`. Su prueba, `prueba_contacto.gd`, tiene un caso de la fila luz (0 fallos, según combate). Si Pablo cambia la tabla (pregunta 16), se cambia la fila, que es solo datos, y se avisa a combate. La solidez de los hechizos se mira con `Lanzador3D.solidez_en(p)`, como hace ya el aliento del dragón.
   - **No usa `largo_chorro_u`** de la trampa dragón: ese cálculo solo corta, no refleja. Se toma de él la idea (recorrer casillas hasta lo sólido).

**La prueba de la base:** `herramientas/prueba_luz.gd`, sin ventana:
- `RayoLuz.trazar` a solas, con un mapa de texto: un muro corta; un prisma gira el rayo; dos prismas enfrentados no hacen un bucle infinito; una barrera de tierra corta, una de fuego deja pasar y una de agua refleja; un nodo con `on_luz` acaba el rayo como `nodo`.
- Sin protección, no sale rayo.
- Con ella, el rayo sale hacia donde mira y un muro lo corta.
- El prisma lo reemite hacia su lado y, al girarlo, cambia el destino.
- El receptor se activa con la luz y se apaga al perderla, o a los `rearme` s si lo lleva.

**Los tres puzles:**

| Puzle | Verbo | Lo que añade a la base | Paso |
|---|---|---|---|
| X10 | Reflejar y apuntar girando | Nada; la versión difícil usa el aro del receptor con `rearme` (L6b) | 3c |
| X12 | Preparar (girar prismas) y después ejecutar (el reflejo) | Nada; es diseño de sala sobre la cuadrícula | 3d |
| X11 | Seguir con el reflejo algo que se mueve | El modo `va=luz` de la plataforma (P6) | 5c |

**Sobre la cuadrícula:** los prismas giran a saltos de 90° (n, e, s, o), así que las salas de luz se diseñan con fuente, prismas y receptor alineados en filas y columnas. Por eso cambio la recomendación de la pregunta 15: el reflejo de la jugadora, **en las 4 direcciones**, como el prisma (ver §7).

**Antes de construir cada puzle**, sus «comprobar» se hacen como prueba sin ventana. Así, si algo no funciona como dice el documento (la bola que cruza el chorro, el brasero que se enciende al pasar), se sabe antes de montar la sala.

---

## 6. Coordinación con las otras sesiones

- **Combate:** G1 está hecho en `escenas/puzle.gd:1452-1505`. L7 añade **una línea** en `al_reaparecer` (llamar a `reiniciar_zona` si se muere en una sala con `reinicio`). X5 y X8 dependen de su **B2** (la tabla de contacto: qué barrera para qué chorro) y del empuje (D1). Combate también ha tocado `lanzador_3d.gd` y `puzle.gd` hoy: antes de editarlos, se mira el DIARIO.
- **Combate, la luz:** el Basilisco (su X3) usará `RayoLuz.trazar` de la base de la luz (§5.1). La luz ya está en `Contacto` como proyectil `luz`, con la acción `refleja` (la puso combate el 22/11). Si cambia la tabla, se toca la fila y se avisa a combate.
- **Hechizos:** su B9g (Crecer y Permanencia) y el aviso de «va a desaparecer» (`PLAN_HECHIZOS_2026-11-22.md:35`, `:388`) **dependen de L6a**. Que usen `CuentaAtras3D` y no hagan otro aviso. La barrera que viaja con la plataforma (§4, camino a) toca su terreno.
- **Gamefeel:** el riesgo de `render_priority` de los avisos (§2) es el mismo para el aro.

---

## 7. Preguntas para Pablo

**Temporizador (L6)**
1. ¿**A** (reutilizar: la duración en la acción y en el brasero) o **B** (pieza `temporizador`) para empezar? Recomiendo **A con el aro común** y B cuando la pida un segundo puzle.
2. ¿Dónde se ve la cuenta: en el **disparador** (el brasero, como en Mystralia), en **lo que cambia** (la trampa) o en los dos? Recomiendo el aro en el disparador, y el hilo y el destello en lo que cambia al empezar y al acabar.
3. ¿Cuánto dura el **aviso final**? Hay un choque: el concepto propone 0,8 s y la tierra ya parpadea 3 s. Propongo una sola regla: **el 25 % de la duración, entre 0,6 s y 3 s**. X7 (2,5 s) avisa 0,6 s; la tierra (25 s) sigue con sus 3 s.
4. ¿Cómo se ve **qué lo activó y qué cambió si está lejos**? La cámara es fija, así que no se va a mirar allí. Opciones: (a) el hilo de luz y un sonido situado, y las salas diseñadas para que disparador y efecto quepan en pantalla (recomendado); (b) además, una flecha pequeña en el borde de la pantalla cuando el efecto está fuera.
5. ¿El aro tiene **tramos fijos** (por ejemplo 8, siempre igual) o **uno por segundo** (se cuentan los segundos, pero con 25 s salen muchos)? Recomiendo tramos fijos.

**Reiniciar (L7)**
6. ¿**Cómo se reinicia** una sala? (a) Una losa o runa en la entrada que se golpea o se pisa (recomendado: se ve y se aprende sola); (b) solo con salir de la sala con el puzle a medias; (c) una opción «Reiniciar sala» en el menú de pausa cuando se está en una.
7. ¿**Morir** dentro de una sala con reinicio también reinicia el puzle? Recomiendo que sí.
8. ¿Los **puzles de agua** se quedan sin reinicio por ahora?
9. ¿En qué salas va? La lista de §3 es la propuesta.

**Puzles**
10. Plataforma móvil: ¿solo **sobre el foso**, o también **sobre agua** (X6 es una balsa)? Recomiendo una sola pieza que valga para los dos. Y para X5, ¿**la barrera viaja** con la plataforma (más caro, toca hechizos) o la plataforma lleva un **parapeto** en un lado?
11. **X6 pide ᛉ permanencia, que no está en la demo.** ¿X6 se queda para después de la demo, o se busca otra solución con el kit (por ejemplo, una trampa ᛒ de fuego en la casilla por la que pasa el brasero)?
12. ~~**X8, el chorro que empuja:** ¿trampa dragón de agua a presión o losa de viento?~~ **Respondida (Pablo, 22/11, principio D1 de PROPUESTAS):** las variantes de otro elemento son lo mejor y lo más barato. Es la trampa dragón con `elemento=agua` y un parámetro de empuje.
13. ¿Los **estados del suelo** se quedan sin aro? Recomiendo que sí: ya se leen por su aspecto.
14. **X9:** ~~¿qué mueve las plataformas?~~ **Respondido (Pablo, 22/11, D1):** la noria de agua en la primera versión; el brasero, el contrapeso y el molinete de viento son variantes para después (§8). **Sigue abierto:** ¿dónde va, Ruinas (agua, acueducto) o Pantano (agua honda bajo los raíles)? Por la cámara fija, propongo raíles de 4–6 casillas para que cada tramo se vea entero sin cambiar el encuadre.

15. **X10:** ¿qué protección de agua hace de espejo, la **barrera** alrededor de la jugadora o la **burbuja** (C10, aún sin decidir)? Para apuntar girando, la protección tiene que **mantenerse** mientras la jugadora gira. Recomiendo esperar a C10 y usar la que se mantenga; si ninguna se mantiene lo bastante, el pedestal puede guardar el reflejo unos segundos con el aro común (L6). ¿Y el rayo reflejado **sigue la mirada suave** o va **por las 4 u 8 direcciones** de la cuadrícula? Recomiendo **4 direcciones** (n, e, s, o), como el prisma: con X12 las salas de luz van sobre la cuadrícula y una diagonal no encaja con ningún prisma. Se lee mejor con la cámara fija. Las 8 direcciones solo si Pablo quiere diagonales.
16. **La luz y las barreras:** ¿tierra corta, agua refleja y fuego deja pasar? Es la tabla que propongo en §5.1. La misma regla vale para la mirada del Basilisco de combate.

---

## 8. Después de la demo: variantes de otro elemento (principio D1, Pablo 22/11)

**Regla:** una pieza que ya existe con otro elemento es mejor y más barata que una pieza nueva. **El elemento va como parámetro de mapa** (`elemento=agua`), no como otra pieza. Cuando se construya algo de este plan, se deja preparado para recibir `elemento=`, aunque la demo solo use uno.

| Pieza | Elemento en la demo | Variantes para después | Hoy |
|---|---|---|---|
| Trampa dragón | Fuego (quema) y agua (empuja, X8) | Hielo (deja suelo helado), tierra (escombro) | Ya lee `elemento=` (`escenas/puzle.gd:511`); falta el comportamiento de cada uno |
| Receptor de parada de X9 | Agua (noria = molino) | Fuego (brasero), tierra (contrapeso en placa de peso), viento (molinete) | Las tres primeras piezas existen; la plataforma solo tiene que escuchar `avanzar` |
| Receptor de pulso | Cualquiera | — | Ya lee `elemento=` |
| Espejo de X10 | Protección de agua | Escudo de hielo (Mystralia) | La protección existe; falta que refleje |
| Vagoneta de X11 (`va=luz`) | Luz | Chorro de agua que la empuja mientras le da; brasero encima que la mueve mientras arde | Mismo modo de la plataforma, con otro receptor |
| Plataforma móvil | — | Sobre agua o sobre foso, con el mismo motor (pregunta 10) | Nueva |
