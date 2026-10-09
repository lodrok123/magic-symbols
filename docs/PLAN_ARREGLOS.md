# Plan de arreglos — octubre 2026

Problemas detectados en la revisión del 4 de octubre, ordenados para
ejecutarlos sin que los contextos se pisen. Cada tarea tiene **un
responsable** (Pablo, Juego o Pipeline) según `docs/PROPIETARIOS.md`, y las
fases van en orden: cada una deja el proyecto arrancable antes de la
siguiente.

Marca `[x]` al terminar y anota en `docs/DIARIO.md` lo que cruce la frontera.

---

## Fase 0 — Que el proyecto arranque (Pablo, ~20 min, hoy)

- [x] **0.1 `project.godot`: escena principal.** Cambiar
  `run/main_scene="res://tests/walk_8dir_test.tscn"` (no existe) por
  `res://TestJugabilidad.tscn`. Comprobar con F5.
- [x] **0.2 Plugin fantasma.** `editor_plugins/enabled` activa
  `res://addons/ms_sprite_importer/plugin.cfg` y no hay carpeta `addons/`.
  Preguntar al Pipeline si ese plugin existe en otra máquina (tarea 1.3). Si
  no, borrar la línea `enabled=PackedStringArray(...)`.
- [ ] **0.3 Abrir Godot una vez** para que genere los `.uid` que faltan
  (`nivel_base.gd`, `test_1.gd`, `test_2.gd`, `recolectable.gd`,
  `vfx_lab_mundo.gd`) y reimporte. Commitear los `.uid` nuevos.
- [ ] **0.4 Limpieza de raíz.** Borrar `Documents.lnk` y `pipeline.lnk`
  (accesos directos de Windows dentro del repo).
- [ ] **0.5 Commit** de `PROPIETARIOS.md`, `DIARIO.md`, este plan y lo anterior.
- [ ] **0.7 Lista §4 de `docs/QA_ARTE.md`** (10 min en Godot con F6): confirmar o descartar lo
  marcado **[Godot]** (hielo hundido, maga que se levanta, golpe del goblin, hachazo). Lo
  confirmado entra en 1.2 (Juego) o 1.9 (Pipeline).
- [ ] **0.8 Tras el OK de la integración:** borrar `docs/propuesta_arquitectura_*.md` y
  `test_1.gd` (+ `.uid`); comprobar `git ls-files tools` por el `.exe` de 181 MB y los vídeos.
- [ ] **0.6 Conocimiento de los proyectos de Claude.** Subir a los dos:
  `CONTEXTO.md`, `PROPIETARIOS.md`, este plan. A Juego: `ARQUITECTURA.md`,
  `NUEVOS_SISTEMAS.md`, `TEST2_CONCLUSIONES.md`. A Pipeline: `ARTE.md`,
  `ANIMACION.md`, `PERSONAJE.md`, `ASSETS_PENDIENTES.md`, `CONTRATO_GODOT.md`. A los dos, además,
  `DISENO_FUTURO.md`.

---

## Fase 1 — Estabilizar el código (Juego y Pipeline en paralelo; no comparten archivos)

### Juego

- [x] **1.1 Invertir la herencia de niveles.** *(hecha: pasos a-c; (d) se resolvió dejando `test_jugabilidad.gd` como hoja y marcando `test_1.gd` obsoleto; borrar `test_1.gd` + `.uid`)* Hoy
  `test_1/mundo/test_2 → nivel_base.gd → test_jugabilidad.gd` y
  `nivel_base` depende de seis ganchos "NO BORRAR" dentro de un archivo de
  2.472 líneas. Objetivo:
  ```
  nivel_base.gd        (sin padre) mapa por letras, props, guardado, empujables,
     │                 mochila, botín, tiendas, goblins, muerte, placa de peso
     ├─ test_1.gd      el mapa de 23×23 (lo que hoy es test_jugabilidad.gd)
     ├─ mundo.gd
     ├─ test_2.gd
     └─ vfx_lab_mundo.gd
  ```
  Hacerlo **por pasos verificables**, no de golpe: (a) mover a `nivel_base`
  el plano por letras y `_mapa()`; (b) props y `_prop_creado`; (c) guardado y
  empujables; (d) lo que quede de `test_jugabilidad.gd` pasa a ser el cuerpo
  de `test_1.gd`. Tras cada paso, las cuatro escenas arrancan con F6.
  Al final, `test_jugabilidad.gd` desaparece o queda como alias vacío.
- [x] **1.2 Hilos abiertos de `CONTEXTO.md`** *(hecha el 6/10 por el Juego; sin probar en Godot)* (bugs conocidos):
  - el jugador **se salta el muro del mundo** estando elevado (subirse
    desactiva la máscara de capa 1);
  - el **arquero recibe daño desmedido**: el circuito sigue soltando
    descargas después de matarlo (falta un pestillo como `is_electrified`).
- [ ] **1.4 Flag de depuración.** Hay 84 `print()` repartidos. Centralizar en
  `PlayLog` o en una constante `DEPURAR` para que la consola de una partida
  normal esté limpia. Prioridad baja; hacerlo cuando se toque cada archivo.

### Pipeline

- [x] **1.3 Plugin `ms_sprite_importer`.** ¿Existe en alguna máquina? Si sí,
  traerlo a `addons/` y commitearlo; si no, avisar a Pablo (tarea 0.2) para
  quitar la línea de `project.godot`.
  Resultado (2026-10-04): no hay carpeta `addons/` en la raiz ni en el primer nivel de
  `pipeline/`, `tools/`, `export_godot/`, `Render Studio/` y `assets/`, y ningun
  documento del proyecto lo describe; `project.godot` ya no lo activa. No se puede
  comprobar en otras maquinas: si aparece en alguna, traerlo a `addons/`.
- [ ] **1.5 Clip `shot_in_the_back_and_fall` del héroe.** Está en el inbox;
  pasar `PROCESAR_PERSONAJES` + `EXPORTAR_GODOT` y comprobar que el
  `meta.json` lo lista con `en_bucle = false`. El Juego ya lo busca y mientras
  tanto usa `hit_reaction_to_waist`. Anotar en el diario cuando esté.
- [ ] **1.6 Vídeo de SE** (y SO por espejo) de la maga; hoy llevan la fila S.
- [ ] **1.7 Sección 0 y 1 de `ASSETS_PENDIENTES.md`:** `roll_dodge_1`,
  `swim_forward`, y `hit`/`death` de los goblins (hoy se fingen con tinte).
- [x] **1.8 Validar los atlas al cargar.** Que `MsAtlas` compruebe al leer un personaje que
  `meta.json` cuadra con el PNG (filas × `frame_px`, frames, clips sin bucle, `ancla_suelo_px`
  dentro del fotograma) y avise por consola, como hacía `ActorAnimator._check_sheets`. Sale de
  `DISENO_FUTURO.md` §5.
- [ ] **1.9 `QA_ARTE.md`:** aceptar o rechazar los puntos que asigna al Pipeline (1.1 hielo con la
  cara en y=96, 1.3–1.5, 2.1, 2.6) y pasarlos a `ASSETS_PENDIENTES.md` o al diario.

---

## Fase 2 — Documentación al día (secuencial: Juego → Pipeline → Pablo)

`README.md` y `ARQUITECTURA.md` describen el 25 de septiembre: rama
`prueba-isometrico`, `IsoTest.tscn` como escena principal, personaje de
`gen_actor.py`, sellos `pilar`/`tiempo` activos. Son archivos de Pablo, así
que **cada contexto escribe su propuesta en un archivo propio** y Pablo
integra. Así nadie reescribe la fuente de verdad desde una copia.

- [x] **2.1 Juego → `docs/propuesta_arquitectura_juego.md`.** Secciones de
  `ARQUITECTURA.md` que han cambiado: estado (ya no hay dos ramas), cómo se
  juega (mochila, oro, E/I/Q), sellos retirados, niveles y herencia (tras
  1.1), enemigos nuevos, Test 2, y la tabla de "errores que costaron caros"
  con los de este mes (hechizos muriendo en mapas grandes, ganchos perdidos).
- [x] **2.2 Pipeline → `docs/propuesta_arquitectura_arte.md`.** Secciones
  Arte, Animación y Personaje de `ARQUITECTURA.md`: el personaje ya viene del
  pipeline 3D, no de `gen_actor.py`; `MsAtlas`/`MsActor` como punto de
  entrada; losas 128×64; y el reparto real de `tools/`.
- [ ] **2.3 Pablo integra** *(integrado el 4/10 por Claude a petición de Pablo; falta su OK final, borrar las dos propuestas y volver a subir al conocimiento)* las dos propuestas en `ARQUITECTURA.md` y
  `README.md`, borra las propuestas y actualiza `CONTEXTO.md` (estado, hilos
  abiertos, tabla de documentos). Vuelve a subir al conocimiento (0.6).

---

## Fase 3 — Sistemas según `DISENO_FUTURO.md` (manda su atlas de prioridades)

La regla de ese documento: P0 y P1 primero; una P2 solo entra si es poco
código y no rompe nada. Las tareas que dejó el Pipeline en el diario van
delante porque desbloquean arte ya entregado.

### Juego

- [x] **3.0 Lo que pide el diario del Pipeline** *(el código ya estaba hecho; verificado el 6/10 que los `water_frozen_*` existen. Falta que el Pipeline borre `art/hielo_1..3`, ver diario)* (poco código, arte ya entregado):
  `goblin_guerrero._die()` → `anim_orden = "death"`, esperar ~1 s y `queue_free()`;
  `nivel_base._agua()` → rutas nuevas de `water_frozen_{1_nevado,2_escarcha,3_claro}.png` y
  después borrar `art/hielo_1..3` (avisar al Pipeline por el diario para que los borre él);
  `receive_damage()` de guerrero y arquero → `interrupcion = maxf(interrupcion, 0.3)`.
- [x] **3.1 (P0) Regla del libro: un glifo por sector** *(hecha el 6/10 en `spellcaster.gd`; el libro ya dibujaba el hueco ocupado; sin probar en Godot)* (`DISENO_FUTURO` §3). `spellcaster.gd`:
  con `aim_with_mouse`, `_component_at` devuelve siempre el mismo componente; `add_sigil`
  rechaza con aviso el segundo glifo de un sector. `spellbook.gd`: dibujar el hueco ocupado.
  Comprobar en Test2 que `barrera + levitación` en dos sectores sigue dando columna.
- [ ] **3.2 (P0) Sprite bajo las partículas, lado código** (§6): `neutral_block.gd` /
  `grass_block.gd` colocan en `$Visual` el PNG de estado (mojado, ceniza, escarcha) cuando exista;
  sin PNG, el tinte de siempre. Depende de 3.6.
- [ ] **3.3 (P1) Enemigos como base + componentes** (§4): primer componente `Escudo` (hijo con
  `on_spell_hit`, etiqueta `madera`, `blocks`; `quema_madera` lo destruye). Añadir `quema_madera`
  al `.tres` del fuego y `madera` a `combustible.gd`.
- [ ] **3.4 (P1) Sistema de síntesis** (§7): lista de ingredientes y recetas → mejoras (glifos,
  sellos, vida…). Hoy `alquimia.gd` ya cambia oro + ingredientes por mejoras: definir primero en
  `DISENO_FUTURO` §7 qué recetas y qué mejoras, y después extender `alquimia.gd`/`objetos.gd`.
- [ ] **3.5 (P2, solo si es barato)** matriz receta → forma visual (§3); igual + igual = nada (§1).

### Pipeline

- [ ] **3.6 (P0) Sprites de estado de losa** (§6): `wet_ground`, `ash`, `escarcha`, `polvo`, con
  el lienzo de la losa (128×64, cara en y=33). Entregar en `export_godot/terrain/.../blocks/`.
- [ ] **3.7 (P0) Animaciones mínimas por personaje** (§5): definir por personaje la lista mínima
  de clips y el formato, y dejarla escrita en `ASSETS_PENDIENTES.md` §1; iterar sobre ella.
- [ ] **3.8 (P1) Escudo del goblin** (§4): sprite del escudo (sano / ardiendo / roto) con el
  mismo ancla que el goblin.

### Pablo

- [ ] **3.9 Jugar el Test 2 con cronómetro** y responder por escrito las seis preguntas de
  `TEST2_CONCLUSIONES.md`. Necesario antes de decidir nada de §1 y §2 (P2).
- [ ] **3.10 Decisiones abiertas de `DISENO_FUTURO`**: relámpago como base o derivado;
  naturaleza como elemento o como reacción del mundo; qué hace solo la arena.

Dependencias: 3.6 antes de 3.2 · 3.9 antes de cualquier P2 de §1/§2 · 3.1 antes de rediseñar cámaras.

---

## Deuda pequeña (cuando toque, sin prisa)

- [ ] **Juego:** `stride` de la maga hasta que los pies no patinen (depende
  de 1.6); renombrar o retirar del código `pilar` y `tiempo`; sistema de
  diálogo (hoy las frases salen por `print`), decidir dónde aparece el texto.
- [ ] **Pipeline:** `idle`, `cast`, `hurt` y `death` de la maga son de una
  columna; iconos de interfaz 64×64 de `objetos.gd`; VFX de 8 fotogramas;
  tótems de hielo/tierra/viento.
- [ ] **Pablo:** iluminación (`CanvasModulate` + `PointLight2D`) sigue
  siendo lo que más acercaría al referente sin un asset nuevo; decidir
  cuándo.

---

---

## Fase 4 — Test 3: la prueba real de la migración 3D (P0 de `DISENO_FUTURO.md`)

**Qué es.** `poc_25d/PruebaTest2.tscn` pasa de maqueta a **Test 3**: las seis
cámaras del Test 2 más una séptima de **altura**, jugables con el grimorio
real, con un goblin con `Combate`, y medidas. Es la condición de fin de
`DISENO_FUTURO.md` §0 (fecha: 12/10) y, si el 3D gana, la escena sobre la que
se juega `docs/Playtests/PLAYTEST_MIGRACION.md`. Recoge el plan que el Juego
propuso en el diario el 5/10 a las 23:55 y le pone dueño a cada parte.

**Dueños dentro de `poc_25d/`** (hasta ahora era todo del Pipeline; con dos
contextos escribiendo ahí hace falta repartir):

| archivos | dueño |
|---|---|
| `lanzador_3d.gd`, `combate_3d.gd`, `jugador_3d.gd` (nuevos), `playlog_3d.gd` | Juego |
| `pj_3d.gd`, `proporcion_chibi.gd`, `equipo_3d.gd`, `catalogo_assets.gd`, `hierba_3d.gd`, `vfx_3d.gd`, `prueba_test2.gd`, escenas, GLB, texturas, shaders | Pipeline |
| `ESTADOS_SUELO.md` (contrato de reglas) | Juego escribe, Pipeline cumple |

Regla: lo que un contexto necesita cambiar en un archivo del otro va al
diario como petición con el cambio exacto. Godot pisó `prueba_test2.gd`
seis veces el 5/10 por tener el editor de scripts abierto: **cerrar el
editor de scripts de Godot mientras un chat escribe**.

### Decisiones de Pablo (antes de empezar 4.1 y 4.4)

- [x] **4.0a Altura.** Decidida el 6/10 (`DISENO_FUTURO.md` §0b). Propuesta aceptada: la altura son **niveles enteros de
  un bloque**. El jugador sube un nivel con el salto, no dos. Los bloques de
  tierra se apilan hasta dos; barrera + levitación da una columna de dos
  niveles **sólida** (se sube, bloquea proyectiles). Los proyectiles vuelan a
  medio nivel y chocan con lo que esté a nivel ≥ 1: un bloque es cobertura
  contra el arquero. Los goblins no suben. Agua, hielo y charcos solo a
  nivel 0. Caer no hace daño. Si se acepta, la cámara 7 se diseña con esto.
- [x] **4.0b Cast point** = punto que señala el ratón, con alcance máximo de 3
  casillas (playtest 4/10). En 3D es un rayo cámara → plano del suelo. Decidido el
  6/10 con el **modo lanzar** (tiempo al 70 %, `readandwrite`, dirección + posición;
  `DISENO_FUTURO.md` §0b).
- [x] **4.0c Tierra con duración** (25 s, tope 8), **hielo con duración** (20 s) y
  **caída al agua → nadar**; retardo fuera del Test 3. Decidido el 6/10
  (`DISENO_FUTURO.md` §0b).

### Juego

- [x] **4.1 `Lanzador3D`.** `Spellbook` + `GestureRecognizer` en un `CanvasLayer`
  (tal cual, son interfaz); `SpellRecipe.build()` → puntos en casillas →
  `Vfx3D.lanzar(forma, elemento, ...)` + un `Area3D` por manifestación con
  `RuneData` y etiquetas. Sustituye a `spellcaster.gd`; `spell_form` y
  `spell_material` no se portan (su papel visual lo hace `Vfx3D`). Incluye la
  **regla del libro** (un glifo por sector, una receta por página con ratón,
  rechazo con aviso: `DISENO_FUTURO.md` §3) y 4.0b/4.0c. Comprobación:
  `barrera + levitación` en dos sectores da columna; `pilar` no existe.
- [x] **4.1b Modo lanzar** (§0b): al cerrar el libro con hechizo, `Engine.time_scale`
  al 0,7 (constante `RALENTIZADO = 0.7`), el jugador no se mueve, ratón controla
  dirección y origen (rayo cámara → plano del suelo, origen limitado a 3 casillas),
  soltar lanza y el tiempo vuelve a 1. Pide a `Pj3D` el clip de lanzar por nombre
  (`anim_cast` que declare la forma; si no, `readandwrite`) y le avisa de las
  partículas del elemento: solo el nombre, el Juego no sabe cómo se ven.
- [x] **4.1c Tierra e hielo con duración** (§0b): `duracion` en el bloque de tierra
  (25 s, tope 8, FIFO) y en la casilla helada (20 s salvo `permanente`). Actualizar
  `ESTADOS_SUELO.md` (el hielo caduca; es un contrato: avisar en el diario).
- [x] **4.2 Contrato `on_spell_hit(rune_data, direccion)` en 3D.** El Juego lo
  define (firma, etiquetas, orden) y engancha el suelo a `ESTADOS_SUELO.md`
  (la capa de estado por celda ya existe: `_al_impactar`). Lo publica en el
  diario; el Pipeline lo implementa en sus nodos (4.7).
- [x] **4.3 `Combate3D` + IA del guerrero + jugador mínimo.** `CombateComun`
  portado con la misma tabla (debilidad, efectos, botín); tinte de material en
  vez de `modulate`, barra con `Label3D`. IA: detectar a 300 px-equivalente
  (≈ 2,5 casillas), perseguir, golpear, rendirse a 3,5 s. Jugador: vida, daño
  por contacto, muerte con clip y reaparición. Enemigo con `anim_orden` como
  en `MsActor` modo "ia", para que `Pj3D` no conozca la IA.
- [x] **4.4 Altura (según 4.0a).** `CharacterBody3D` sube un nivel con salto;
  bloque de tierra creado = malla + colisión a nivel +1, apilable hasta 2;
  columna de barrera + levitación sólida; proyectiles a medio nivel;
  `MAX_NIVELES_SUBIBLES = 2`. Cámara 7.
- [x] **4.4b Caída al agua** (§0b): cuando la casilla helada bajo el jugador se
  deshace (o pisa agua), estado `nadando`: velocidad ×0,4, no puede lanzar ni
  saltar, clip `swim_forward`, sale al tocar una casilla de suelo. Sin daño.
- [x] **4.5 Mediciones.** `PlayLog` en 3D (volcado a `user://`, errores en
  consola, gestos reconocidos/rechazados/confundidos, manifestaciones) y panel
  `F12` (ms, VRAM, llamadas, casillas vivas). Es P1/P2 de
  `PLAYTEST_MIGRACION.md` §7, hecho directamente en 3D.

### Pipeline

- [ ] **4.6 VFX por forma.** Matriz mínima para el Test 3: 6 elementos ×
  {proyectil, corro, columna, muro que avanza} = 24 celdas; las que no tengan
  dibujo propio usan el del elemento con la forma por defecto. Es la "matriz
  receta → forma" de `DISENO_FUTURO.md` §3 reducida a lo que el Test 3
  necesita.
- [ ] **4.6b Lanzar en 3D** (§0b): clip `readandwrite` del héroe con partículas
  sutiles por elemento (un emisor en la mano, color del elemento, 6 variantes),
  y la tabla `anim_cast` por forma: qué clip de los que existen en el GLB va con
  proyectil, corro, columna y muro. Si un clip coherente no existe, se anota en
  `ASSETS_PENDIENTES.md` §1 y se usa `readandwrite`.
- [ ] **4.7 Objetos del Test 2 en 3D con `on_spell_hit` (4.2):** seto, tronco,
  telaraña (arden, chamuscados, desaparecen; seto y telaraña son muro),
  tótems de rayo/fuego/agua, antorchas, puente plegable, placa de peso
  (empujables ya están). Estados visuales por material, no por PNG.
- [ ] **4.8 Validación de personajes al cargar** (`DISENO_FUTURO.md` §5 en
  3D): al cargar un GLB, comprobar los clips mínimos por tipo (héroe: idle,
  walk, run, cast, hit, death, roll; goblin: idle, walk, attack, hit, death),
  escala del rig y que ningún clip desplace la raíz. Avisa por consola, como
  `_check_sheets`. La lista mínima va en `ASSETS_PENDIENTES.md` §1; para el
  héroe incluye ahora `readandwrite` y `swim_forward` (ambos en el inbox).
- [ ] **4.9 Goblin guerrero jugable** (clips de 4.8 aprobados, `goblin_espadachin`
  como variante) y arquero cuando exista su GLB (`walk_002` → `walk_back`).
- [ ] **4.10 Layout del Test 3.** Las seis cámaras del Test 2 (mismo plano de
  letras: `test_2.gd._mapa()` es la fuente) más la cámara 7 de altura:
  una cornisa de un nivel con el tótem arriba, a la que se llega
  construyendo (tierra apilada o columna), y un arquero abajo contra el que el
  bloque hace de cobertura. Puerta norte con seis runas que se encienden.

### Pablo

- [ ] **4.11 Jugar el Test 3** con la lista §2 de `PLAYTEST_MIGRACION.md`
  (bloques G, M, E y 2.6) y rellenar la tabla de medición de
  `DISENO_FUTURO.md` §0. Capturas de las siete cámaras.
- [ ] **4.12 Decidir el 12/10** y escribirlo en `DISENO_FUTURO.md` §0: 3D (la
  migración entra aquí como fase 5 con pasos) o 2D (`poc_25d` se archiva).

**Orden y dependencias:** 4.0 (hecho) → 4.1, 4.1b, 4.1c y 4.2 (en paralelo con 4.6, 4.8) →
4.7 (necesita 4.2) → 4.3 (necesita 4.9) → 4.4 → 4.10 → 4.5 → 4.11 → 4.12.
Lo que **no** entra hasta el 12/10: mochila, tiendas, encargos, alquimia,
guardados, diálogo. Todo eso es reutilizable tal cual y no responde a la
pregunta de §0.

---

## Fase 5 — Lo decidido en los playtests del 6/10 (`DISENO_FUTURO.md`, "ACTUALIZADO 06/10/2026")

Pablo jugó `PruebaJugabilidad3D` varias veces el 6/10 y cerró decisiones en
`DISENO_FUTURO.md` (§0, §0b, §1, §3, §4). Esta fase las convierte en tareas.
Lo que ya estaba hecho en la fase 4 (modo lanzar, tierra/hielo con duración,
altura, nado, barrera de fuego, IA del arquero, formas corro/muro/columna)
**se queda**; aquí solo entra lo que cambia o se añade.

**Dos números que Pablo tiene que confirmar antes de 5.2** (el texto de §0b
admite dos lecturas): (a) con el **libro abierto** el tiempo ya no se para
sino que va al 30 % ("se ralentiza un 70 %"); (b) en **modo lanzar** también
al 30 % (antes 70 %). Se implementan como constantes `TIEMPO_LIBRO` y
`TIEMPO_LANZAR`, de partida 0,3 las dos.

### Juego

- [x] **5.1 (P0) El origen es siempre el jugador.** Se retira el "origen en el
  punto del ratón" de §0b: el ratón da solo la **dirección**; el alcance de 3
  casillas es distancia de viaje. Nada nace lejos salvo que un glifo lo diga
  (levitación: queda estático donde termina la trayectoria). Motivo: lanzar
  en un punto trivializa el puzle. `Lanzador3D`: `origen = jugador` siempre;
  `alcance` solo limita `travels`.
- [x] **5.2 (P0) Tiempo del libro.** Abrir el libro ya no pausa: `TIEMPO_LIBRO`
  (0,3). Modo lanzar: `TIEMPO_LANZAR` (0,3). Los enemigos siguen moviéndose
  (lento): es el castigo al que abre el libro sin haberse preparado. El HUD
  tiene que enseñar que el tiempo corre (los goblins se mueven, basta).
- [x] **5.3 (P0) Altura: un nivel.** `MAX_NIVELES_SUBIBLES = 1`, la tierra se
  apila hasta 1, la columna de barrera + levitación es de 1 nivel. Los
  números de §0b (dos niveles) quedan para después.
- [ ] **5.4 (P0) Semántica de glifos v2** (tabla de §3). *(Sustituida el 8/10 por la Fase 8, glifos como geometría; lo hecho de `linea` en `Receta3D` se aprovecha.)* Cada glifo aporta un
  parámetro a la receta, como hoy; lo que cambia es la lectura:
  - `flecha`: **desplaza** el hechizo `d` casillas desde el jugador; varias
    flechas alargan la **duración** (no la distancia). Sola: bola del
    elemento (la forma de la bola depende del elemento: `ARTE`/VFX).
  - `barrera`: **redondez** y radio; varias barreras, más radio. Sola:
    escudo del elemento alrededor del jugador.
  - `levitacion`: **estático en un punto**. Sola: acompañante flotante junto
    al jugador (llama, roca). Con flecha: viaja `d` y se queda. Con barrera:
    pilar delante del jugador.
  - `pulso`: **empuja**. Sola: onda que empuja. Con barrera: la barrera se
    extiende `d'` < `d`. Con flecha: trayectoria curva.
  - `linea` (**glifo nuevo**): **muro** delante. Hielo y tierra dejan un
    bloque sólido que bloquea proyectiles; fuego, agua, viento, rayo dejan el
    elemento "fluido" en línea. Con pulso: muro que empuja y se estira. Con
    flecha: muro que avanza. Con barrera: muro sólido. Con levitación:
    **lanzallamas** (chorro que permanece).
  Implementación: `Sigils.FORM` gana `linea` (parámetro `line`) y `pulso`
  pasa de `spread+pulse` a `push`; `SpellRecipe` traduce a forma:
  `bola | corro | pilar | muro | onda | chorro | acompanante`. La tabla de
  acumulación de `ARQUITECTURA.md` se actualiza cuando esté hecho. Gesto de
  `linea`: una raya horizontal; grabar plantilla.
- [ ] **5.5 (P1) Agua que rellena.** No hay fluidos: un hechizo de agua sobre
  un hueco (foso, casilla vacía bajo nivel 0) **rellena** ese hueco y los
  vecinos conectados hasta `N` casillas (de partida 4). Regla en
  `ESTADOS_SUELO.md` (nuevo estado `agua_llena`, se puede helar y cruzar).
- [ ] **5.6 (P1) Escudo del goblin** (§4): componente `Escudo` hijo del
  enemigo; mientras está activo, los **impactos directos** (bola, muro que
  avanza) no le hacen daño; corros y pulsos sí. `quema_madera` lo destruye.
  Etiqueta `quema_madera` en `fire_rune.tres`, `madera` en el escudo.
- [ ] **5.7 (P2) Cinco elementos base** (fuego, agua, viento, tierra, **rayo**).
  Tabla `par → RuneData` con las combinaciones ya decididas: rayo + viento =
  **tormenta** (nubes de tormenta estáticas sobre el área: rayo periódico
  en las casillas de debajo); agua + viento = hielo; fuego + agua = vapor.
  `fuego + viento` y `rayo + tierra` sin definir: no se implementan.
- [x] **5.8 (P0) Contrato VFX v2 para el Pipeline.** Publicar en el diario la
  lista de formas de 5.4 con sus parámetros (`radio`, `largo`, `altura`,
  `duracion`, `direccion`) para que 5.10 pueda empezar. Un día.

### Pipeline

- [ ] **5.9 (P0) Transición del libro.** Al abrir, el grimorio **aparece en
  las manos** de la protagonista (lo barato: escala desde 0 + partículas
  sutiles + 0,3 s; no coger el libro de la cadera). Al cerrar, lo inverso.
  Clip `readandwrite` ya existe para el modo lanzar.
- [ ] **5.10 (P0) Set de VFX con las combinaciones en mente.** Matriz de
  formas v2 × elementos: `bola, corro, pilar, muro, onda, chorro,
  acompanante` × `fuego, agua, viento, tierra, rayo, hielo` = 42 celdas,
  con "forma = malla/emisor, elemento = material" (fase 4, 4.5).
  Prioridad: las 12 que usa `PruebaJugabilidad3D` (bola y muro de los seis).
  Entrega por celda con captura en `docs/qa/vfx/`. Lo ya hecho
  (`stone_ring`, `energy_ring`, corro y muro) cuenta.
  **Referencias (Pablo, 6/10):** ha dejado varias animaciones de
  lanzallamas, muros y barreras como referencia de cómo tienen que verse,
  en `poc_25d/vfx/referencias/` (ver su `LEEME.md`: qué forma enseña cada
  vídeo; llevan marca de agua, no van al juego). Y **el pulso usa la
  animación `fire ring`** como referencia: un aro que nace en el jugador y
  se expande hacia fuera, no un corro quieto. Esto fija dos cosas para la
  matriz: la forma `onda` (pulso) es un anillo que crece, y `muro`/`chorro`
  siguen las referencias de muro y lanzallamas, no se inventan.
- [ ] **5.11 (P1) Nubes de tormenta** estáticas para `tormenta` (5.7) y el
  **chorro** (lanzallamas) por elemento, siguiendo las animaciones de
  referencia de 5.10.
- [ ] **5.12 (P1) Plan de assets "bosque"** para un nivel más ambicioso:
  lista en `ASSETS_PENDIENTES.md` con medida en pantalla, tope de triángulos
  y textura ≤ 1024: árboles (3 variantes), arbustos, rocas (2 tamaños),
  tocones, setos, telaraña, puente, pasarela, cabaña/puesto, tótems ×3,
  antorchas, fogata, nubes de tormenta, agua (orilla, cascada pequeña),
  camino; personajes: héroe, goblin guerrero, goblin arquero, guardabosques,
  librera, alquimista, con los clips mínimos de 4.8. Cada asset con qué
  letra del plano lo coloca.

**Estado del Juego a 7/10 09:30** (diario 21:00–22:00 del 6/10): fase 4
cerrada; **5.1, 5.2, 5.3 y 5.8 hechas**; **5.4 a medias** (`linea` en
`Receta3D`, falta el resto de la semántica v2, que espera a 5.14). Lo que
le falta para `linea` y no es suyo: `Sigils.FORM["linea"]` en `sigils.gd`
(Pablo, propuesta exacta en el diario 22:00), plantilla del gesto (Pablo,
al avisar el Juego) e icono `linea.png` (Pipeline). Sus archivos
retrocedieron otra vez a las 21:11: **cerrar las pestañas de `poc_25d/*.gd`
en el editor de scripts de Godot.**

### Pablo

- [x] **5.13** Confirmado el 6/10: libro abierto al 30 % (castigo al no preparado; se ajustará) y modo lanzar al 30 %.
- [ ] **5.14** Tras 5.1–5.4: jugar la **tabla de glifos** de §3 combinación a
  combinación (16 filas: cada glifo solo y cada par de la tabla) y marcar
  ✔/✘ en `TEST2_CONCLUSIONES.md`. Es el playtest de esta fase.
- [ ] **5.15** Decidir `fuego + viento` y `rayo + tierra` (o dejarlos fuera).

**Orden:** 5.13 → 5.1, 5.2, 5.3 (una tarde del Juego) → 5.8 → 5.4 ∥ 5.9,
5.10 → 5.14 → 5.5, 5.6 ∥ 5.11, 5.12 → 5.7. Las fases 4 (Test 3, altura) y
el playtest de migración siguen vigentes; esta fase va **antes** del Test 3
porque cambia el lenguaje con el que se jugaría.

**Aviso del diario (17:20):** los archivos del Juego en `poc_25d/`
retrocedieron a una versión anterior dos veces hoy. No es un chat: es
Godot guardando desde el editor de scripts o un `BAJAR` con `stash`
sin `drop`. Con un chat escribiendo en `poc_25d`, el editor de scripts
de Godot cerrado, y `git status` antes de `BAJAR`.

## Fase 6 — Lo visto en el playtest largo del 7/10 (`docs/Playtests/Magic_Symbols_Playtest 071026.docx`)

Segundo playtest largo en `PruebaJugabilidad3D`. El documento tiene cinco
bloques (estructura, animaciones, assets, hechizos, glifos); aquí cada punto
es una tarea con dueño. Las imágenes del playtest son la referencia: el que
haga la tarea abre el `.docx` (está en la copia de OneDrive; Pablo lo copia a
`docs/Playtests/` del repo, 6.0). Prioridad: P0 lo que rompe el juego o el
lenguaje de los hechizos; P1 lo que se ve mal; P2 lo que es pulido.

### Pablo

- [x] **6.0** Copiado el `.docx` del 7/10 a `docs/Playtests/` (7/10). Queda
  decidir **6.10** (estructura del mundo) cuando el Pipeline entregue la
  propuesta: es la decisión grande de esta fase.
- [ ] **6.21 (P0) Glifos nuevos y símbolos.** **Validado el 7/10.** Símbolos
  nuevos: **flecha = `<`** (un ángulo; se reconoce a izquierdas y derechas),
  **línea = `|`** (raya vertical), **hielo = `X`**, **pulso = dos
  semicírculos**, **levitación = `^`** (el mismo ángulo que flecha, con la
  punta hacia arriba; fijado el 7/10). Ojo con el $P: flecha vale a
  izquierdas y derechas (`<` y `>`), así que levitación solo puede ser `^`
  (no `v`, que se confundiría con una flecha girada): comprobar el margen
  entre `<`, `>` y `^` con `podar_gestos.py` al grabar. Pablo graba las plantillas en
  `gesture_library.tres` cuando el Juego avise de que `linea` y `pulso`
  entran por el libro (6.1) y añade `Sigils.FORM["linea"]` /
  `GLYPHS["linea"]` en `sigils.gd` (propuesta exacta en el diario del 6/10,
  22:00). Comprobar que `pulso` (dos semicírculos) no se confunde con
  `barrera` (círculo) en el $P: `podar_gestos.py` da el margen.
- [x] **6.22 (P1) Hierba crecida: decidido (a), deja de ser sólida en 3D**
  (7/10). Lo ejecuta el Juego en 6.22a. Contexto: hoy la hierba crecida por el
  agua es **sólida** (regla heredada del 2D) y es lo que el playtest ve como
  "colisión fantasma al crecer la hierba". Opciones: (a) deja de ser sólida en
  3D (lo más simple: una línea en `Jugador3D._puede_estar`); (b) sigue sólida
  pero se ve claramente como seto. Recomendación: (a); en 3D no hace falta
  que la hierba bloquee, ya bloquean setos y tierra.
- [ ] **6.23 (P1) Jugar la cadena de casteo** cuando 6.2 y 6.11 estén:
  T/página → `readandwrite` sostenido mientras se apunta → soltar → `cast` →
  fin, y confirmar que el libro en las manos se ve. **El tiempo al 30 % se
  siente bien (7/10): no se ajusta.** Cadena confirmada como está escrita.
- [x] **6.24 (P2) Validado (7/10):** `rayo + flecha` = bola eléctrica
  pequeña; `rayo + levitación + barrera` = el rayo que cae de hoy, más corto.
  El Juego lo aplica en 6.5; actualizar la tabla de §3 de `DISENO_FUTURO.md`
  al hacerlo.

### Juego

- [x] **6.1 (P0) `linea` y `pulso` entran por el libro.** `pulso` existe en
  `sigils.gd` pero el playtest pide "crear el símbolo y añadirlo al test":
  comprobar que el 3D lo acepta (`Receta3D.apply("pulso")`), que `linea`
  llega desde el libro en cuanto Pablo meta `Sigils.FORM["linea"]`, y avisar
  en el diario para que Pablo grabe plantillas (6.21). Sin esto 5.14 no se
  puede jugar.
- [x] **6.2 (P0) Cadena de casteo correcta.** Hoy: elegir página/dibujar →
  clip de casteo. Debe ser: **T o página → `readandwrite` (y se sostiene
  mientras se apunta) → al soltar, `cast` de la forma → fin**.
  `Lanzador3D`: al entrar en modo lanzar `Pj3D.jugar("readandwrite")` en
  bucle; al lanzar `jugar("cast", true)` y esperar `duracion("cast")` antes
  de volver a idle. El libro en las manos lo pone el Pipeline (5.9/6.11); el
  Juego solo pide el clip por nombre.
- [ ] **6.2b (P0) El clip de atacar no se congela.** Si el jugador se mueve
  durante la animación de lanzar (`cast`), el clip se queda congelado
  (añadido al playtest el 7/10). Arreglo: cuando empieza `cast`, el jugador
  queda **bloqueado hasta que el clip termina** (`duracion("cast")`), igual
  que los goblins con `attack` (6/10 18:55); el movimiento que llegue
  mientras tanto se ignora y al acabar vuelve `walk`/`idle`. **Decidido
  (7/10): el mismo bloqueo lo reutilizan `cast` y `drink`** (un solo "clip
  que bloquea" en `Jugador3D` con su temporizador). La voltereta (`roll`)
  no entra: se desplaza y ya tiene su propio control (6.6).
- [x] **6.3 (P0) Barrera que dura, te sigue y te protege.** Con cualquier
  elemento, la barrera quieta (`cupula`): (1) dura más (propuesta: `vida`
  × 2, mínimo 6 s; número en una constante para ajustar); (2) **sigue al
  jugador** (el `Area3D` y la cúpula son hijos del jugador, no del mundo);
  (3) **para los golpes de los goblins y las flechas** mientras dura
  (`Combate3D`: si hay barrera activa del jugador, el golpe/flecha se
  absorbe; opcional: cada impacto le resta vida). Hoy la barrera es solo
  área de daño/colisión y no protege: es la queja más repetida del playtest.
- [x] **6.4 (P0) `tierra + barrera` = esfera de tierra; `barrera + pulso` =
  anillo de piedra que crece.** Hoy tierra + barrera da el anillo de piedra
  (`stone_ring`), que al playtest le parece perfecto… **para barrera +
  pulso**. Cambio en `Receta3D.forma()`/`_visual_campo`: tierra + barrera →
  `cupula` de tierra (bloques en cúpula, el jugador dentro); barrera + pulso
  → `corro` que se expande del jugador hasta el radio (hoy el corro nace ya
  en su radio). Sólidos (tierra, hielo): al apagarse se **destruyen** (VFX
  de Pipeline 6.17); fluidos se apagan.
- [x] **6.5 (P0) Proyectiles por elemento (`flecha`).** `fuego + flecha` se ve
  como una gota enorme que vuela; "mal, y probablemente en el resto de
  elementos". Juego: la **bola** es una manifestación pequeña (≈ 0,5
  casilla) que viaja a 3 casillas, no el campo entero estirado; pasar al VFX
  el tamaño (`{"radio": 0.25}`) y la dirección real. `rayo + flecha` pasa a
  ser **bola eléctrica** pequeña (deja de ser rayo que cae); el rayo que cae
  queda para `rayo + levitación + barrera` con duración corta (6.24).
- [x] **6.6 (P1) Voltereta.** Tecla (propuesta: Ctrl o botón derecho fuera
  del modo lanzar): `roll_dodge`, desplaza **≤ 1 casilla** en la dirección
  de movimiento, **colisiona** (usa `_puede_estar` paso a paso, no
  teletransporta), reutilización **4 s** (constante `TIEMPO_VOLTERETA`),
  sin daño por contacto mientras dura (i-frames). Evento en `PlayLog`.
- [x] **6.7 (P1) Beber poción.** Tecla (propuesta: Q): si hay poción en la
  mochila, clip `stand_drink` **1,5 s con el jugador bloqueado** (ni moverse
  ni lanzar ni voltereta: es vulnerable), cura al terminar (si le golpean
  antes, se interrumpe y no cura). La poción en la mano la cose el Pipeline
  (6.12); el Juego pide `Pj3D.equipar("pocion")` / `desequipar` por nombre.
- [x] **6.8 (P1) Nadar: flotar, no hundirse.** En agua el jugador queda con
  los pies a `ALTO_AGUA - 0,35` (la superficie, no el fondo del bloque) y el
  clip `swim`; hoy se hunde en el bloque. Un offset en `Jugador3D` según
  `nadando`; comprobar con la cámara del juego, no en headless.
- [ ] **6.9 (P1) Propagación del fuego solo por contacto + retardo del
  reconocimiento.** **Medido el 7/10 (diario 10:05):** (a) vive en
  `prueba_test2.gd` → lo hace el Pipeline en 7.3; (b) el retardo es
  `GESTURE_PAUSE` (0,75 s) de `spellbook.gd` escalado por `time_scale` al
  30 % = 2,5 s reales → **lo arregla Pablo** en `spellbook.gd`:
  `gesture_countdown -= delta / maxf(Engine.time_scale, 0.01)`. Nada
  pendiente del Juego. Texto original: (a) El fuego en hierba se extiende demasiado rápido y
  lejos: `ESTADOS_SUELO` / `lanzador_3d`: el fuego solo pasa a casillas
  **adyacentes** (4 vecinas) y con un retardo por salto (propuesta 0,6 s);
  nada de radio. (b) **Bug:** hay un retardo notable entre dibujar un sello o
  glifo y que el libro lo reconozca. Medir primero (tiempo entre soltar el
  ratón y `_on_gesture`): sospechosos, el remuestreo del $P con todas las
  plantillas en el mismo fotograma, o un `await` del libro. Reportar la
  medida en el diario antes de arreglar.
- [x] **6.22a (P1) Hierba crecida no sólida** (decisión 6.22, opción a):
  en `Jugador3D._puede_estar` la hierba crecida deja de bloquear; los
  goblins igual (`Combate3D`). Setos y tierra siguen bloqueando. Es la
  "colisión fantasma al crecer la hierba" del playtest.

### Pipeline

- [ ] **6.10 (P0) Propuesta de estructura del mundo: de bloques a nivel
  editable.** El playtest: generar todo por bloques da colisiones fantasma
  (hierba, puesto), no deja construir el mundo poco a poco ni girar piezas,
  y hay piezas que no ocupan una casilla entera. Pide ir a **3D puro
  editable en Godot** para que Pablo monte niveles con las piezas ya
  validadas. Pipeline escribe la propuesta (una página en `DISENO_FUTURO.md`
  §0 o en el diario) con dos caminos y su coste: (a) el mapa de letras sigue
  siendo la **fuente** pero `prueba_test2.gd` lo **hornea** una vez a un
  `.tscn` normal (nodos hijos, `MeshInstance3D` + colisión por pieza) que
  Pablo edita en el editor; la lógica del Juego (`_bloqueadas`, huellas,
  estados del suelo) se alimenta de los nodos, no de las letras; (b) nivel
  hecho a mano desde cero con una paleta de escenas (`.tscn` por pieza) y
  un `GridMap` solo para el suelo. En las dos: **colisión por malla real**
  (`create_trimesh`/convex por pieza) en vez de "casilla bloqueada"; eso
  quita de raíz las colisiones fantasma del puesto y la hierba. Pablo decide
  (6.0). **No se empieza a programar hasta la decisión.**
- [x] **6.11 (P0) Libro en las manos + `readandwrite` sostenido** (= 5.9 con
  lo que añade el playtest): el grimorio sale de la pelvis y va a las manos
  al abrir, y el clip `readandwrite` **se aguanta en bucle mientras se
  apunta**; `cast` solo al soltar (ver 6.2). Comprobar que `readandwrite`
  hace bucle limpio.
- [x] **6.12 (P1) Clips nuevos del héroe:** (a) **giro al andar**: integrar
  `walk02` en el bucle de `walk` (1–2 fotogramas clave bastan) para que el
  cambio de dirección no sea seco; (b) **`roll_dodge`** validado como
  "voltereta" (≤ 1 casilla de desplazamiento en el clip, o sin
  desplazamiento y lo mueve el Juego); (c) **`stand_drink`** 1,5 s con el
  modelo de la **poción al 50 %** cosido a la mano (`Equipo3D`, como el arco
  del arquero); exponer `Pj3D.equipar("pocion")`.
- [x] **6.13 (P1) Arquero: fotograma de apuntado.** Bloquear el clip
  `ArcheryShot` en el fotograma con los brazos extendidos (Pablo: el 5 o el
  6) mientras apunta, y soltar desde ahí; dar al Juego `momento_golpe` y el
  fotograma de bloqueo. Arco: **+20 % de largo y más ancho** para que se
  vea.
- [x] **6.14 (P0) Hierba: más masa y quemado sin mancha.** (a) Los matojos
  salen muy separados: más masa visual, sin huecos, para que la propagación
  no parezca irreal (imagen del playtest como objetivo); (b) **quitar el
  suelo ennegrecido** al quemarse: la hierba quemada desaparece o queda un
  rastrojo corto, el suelo no cambia de color; (c) la hierba **no genera
  colisión** (ver 6.22; la solidez la decide el Juego, el Pipeline no pone
  `StaticBody`).
- [x] **6.15 (P1) Fuego sencillo = una lengua.** Antorchas y fogatas hoy
  tienen dos lenguas; que `fuego_fijo` en antorcha/hoguera lleve **una**.
- [x] **6.16 (P1) Agua, orilla y hielo.** (a) El agua no llega al borde del
  cubo (queda por debajo): subirla a ras y darle sensación de fluido (ondas
  en el shader, ya hay base); (b) **transición de orilla** entre bloque de
  agua y hierba (pieza o decal de borde: arena/piedras); (c) hielo sobre
  agua: por dentro vale la textura blanca, falta una **capa de pulido**
  encima (placa de hielo con grietas, como `cristal_hielo`).
- [x] **6.17 (P0) VFX del pulso y de los sólidos que se rompen.** Pulso:
  anillo que **crece poco a poco desde el jugador hasta el radio fijado**,
  se completa y se apaga (los cuatro fotogramas del playtest: puntos →
  anillo bajo → anillo lleno → ceniza). Referencia `anillo_fuego.glb` y
  `vfx/referencias/`. Para tierra y hielo, al acabar el pulso o la barrera
  los bloques **se destruyen** (fragmentos que caen, como el vídeo de rocas
  del playtest); los fluidos se apagan. Mismo `lanzar_forma("corro", …)` con
  una opción `{"crece": true}` y `apagar()` con `{"rompe": true}`.
- [x] **6.18 (P0) Bola por elemento.** La `bola` (flecha) de cada elemento es
  un proyectil pequeño reconocible: fuego = bola de fuego con estela, rayo =
  **bola eléctrica**, agua = gota, viento = remolino, hielo = carámbano,
  tierra = piedra. Hoy fuego sale como gota enorme. Tamaño por `{"radio"}`
  del Juego (6.5).
- [x] **6.19 (P1) `tierra + barrera` = esfera de tierra** alrededor del
  jugador (cúpula de bloques/rocas; `cupula` de tierra). El `stone_ring`
  pasa a `barrera + pulso` (6.4).
- [ ] **6.20 (P1) Assets: arreglos y plan.** (a) **Tocón**: versión
  horizontal y vertical (girarlo); (b) **arbusto**: regenerar, es demasiado
  low-poly; (c) **puesto (stand)**: hoy demasiado low-poly y con colisión
  fantasma a la derecha; o regenerar uno más sencillo donde se vea a la
  librera, o quitar lo que hay sobre la mesa y reducirlo en conjunto (y
  centrarlo entre `c` y `c+1`, pendiente del 6/10); (d) **señal**: más
  pequeña y con posibilidad de un texto corto (dirección) encima; (e)
  **iconos** `linea.png` (`|`), nueva `flecha.png` (`<`), `hielo.png` (`X`),
  `pulso.png` (dos semicírculos) y `levitacion.png` (`^`) en
  `assets/ui/glyphs/` (6.21). Añadir lo nuevo a `ASSETS_PENDIENTES.md`.

**Orden:** 6.0 → 6.1 + 6.21 (sin glifos no hay 5.14) → 6.2, 6.2b ∥ 6.11 → 6.3,
6.4, 6.5 ∥ 6.17, 6.18, 6.19 (los hechizos, que son el lenguaje) → 6.23 →
6.14, 6.9 ∥ 6.22 → 6.6, 6.7, 6.8 ∥ 6.12, 6.13 → 6.15, 6.16, 6.20 → 6.24.
**6.10 se decide en paralelo y no bloquea nada**: lo demás vale igual con
bloques o con nivel editable. Esta fase sustituye en la práctica al "Test 3"
de la fase 4 (4.10/4.11): ya se juega un nivel completo.

## Fase 7 — Nivel editable: camino A de 6.10 (decidido por Pablo el 7/10)

Pablo elige el **camino A** de la propuesta del Pipeline (diario 7/10 10:20):
el mapa de letras se **hornea** una vez a un `.tscn` normal; cada pieza es
un nodo que Pablo mueve y gira con los gizmos del editor de Godot; la
colisión es **la de la propia malla**. Quiere el editor de niveles **ya**.

**Lo que no cambia** (y por eso el Juego no se reescribe): los estados del
suelo siguen siendo **por casilla de 2,3 u** (agua, hielo, fuego, tierra,
hierba: `_helada`, `_al_impactar`, `_img_estado`); los hechizos siguen
calculando en casillas; `Vfx3D`, `Pj3D`, `Reactivo3D`, `Ocluso3D` igual.
Lo que cambia es **de dónde salen las piezas** (nodos del `.tscn`, no
letras) y **qué decide que algo bloquea** (la colisión real, no
`_bloqueadas` escrito a mano desde el mapa).

**Por qué en dos pasos.** Medido en el código del Juego (7/10): todo lo que
pregunta al mundo pasa por **una docena de funciones** de `Lanzador3D`
(`en_mapa`, `letra_de`, `es_agua`, `y_pies`, `celda_solida`, `pisable`,
`linea_libre`, `calcular_huellas`/`choca_huella`, `bloqueada`) y
`Jugador3D._puede_estar`; `letra_de` solo se usa para cuatro letras (`~`
agua, `b` puente, `#` pared, `B` barrera de fuego). Así que el paso 1 deja
jugable el nivel editable **sin tocar la física del jugador**: el cargador
rellena `_bloqueadas` y las huellas **desde las colisiones** de los nodos, y
el Juego solo cambia "letra" por "tipo de suelo". El paso 2 (jugador y
goblins con física de verdad) se hace después, con el nivel ya editable, y
solo si el paso 1 deja colisiones raras.

### Pablo

- [x] **7.0** Decidido: camino A (7/10). Respuestas pendientes a las
  preguntas (2)–(4) del Pipeline; si no dice otra cosa, valen estas:
  **(2)** tras hornear, **el `.tscn` manda** y el mapa de letras se archiva
  (se conserva `_mapa()` solo para regenerar desde cero, con aviso de que
  pisa las ediciones); **(3)** la rejilla lógica de 2,3 u se queda para los
  estados del suelo; las piezas giran a cualquier ángulo y el bloqueo es por
  colisión real; **(4)** la hierba crecida es `Area3D` sin cuerpo (6.22a).
- [ ] **7.10 (P2) Limpieza tras la entrega 1.** Borrar
  `poc_25d/niveles/jugabilidad.tscn`, `test2.tscn` y los dos
  `*_copia_20261007_11*.tscn` (formato de la entrega 1 de las 11:55, ya
  sustituido por `Nivel_*.tscn`); el Pipeline retira después `_modo_escena`
  de `prueba_test2.gd`. Y nombrar la capa 11 en `project.godot`:
  `layer_names/3d_physics/layer_11="MUNDO"` (cosmético, pero se ve en el
  inspector).
- [ ] **7.11 (P1) Barrera de fuego larga.** *(parte Pipeline hecha el 7/10; falta la del Juego)* Decidido el 7/10: una barrera
  es **un solo marcador** `barrera_fuego` estirado (escala en su eje largo o
  campo `largo` en casillas), no un `B` por casilla. **Pipeline:**
  `Marcador3D` admite `largo` + dirección; el cargador escribe `B` en cada
  casilla cubierta (el Juego sigue viendo casillas); el horneador junta las
  `B` contiguas en una; el visual pasa de N `fuego_fijo` (dos lenguas cada
  uno) a **una pared de fuego** continua (`lanzar_forma("muro", "fuego")`
  de la longitud real, una luz y un emisor por cada 2 casillas); API nueva
  `fx.apagar_tramo(muro, casilla)` que parte o acorta la pared. **Juego:**
  `colocar_barreras` sigue con una `BarreraFuego` por casilla (así el agua
  abre un hueco de 1–3 casillas y se pasa por él) y al apagar llama a
  `apagar_tramo` en vez de buscar la llama por posición. Las diagonales se
  escalonan a casillas (la rejilla es de 2,3 u). Media jornada Pipeline,
  una hora Juego.
- [x] **7.12 (P1) Nivel de pruebas.** *(hecho el 7/10 por el Pipeline)* `niveles/Nivel_Pruebas.tscn`: un
  banco de pruebas para assets y mecánicas nuevas, separado de los niveles
  de verdad: suelo llano 16×16 con una franja de agua, un puente, una
  **fila con una pieza de cada** (`piezas/*.tscn`, con rótulo), un marcador
  de cada tipo reactivo, los tres goblins y el jugador. Pipeline lo hornea
  (un `_mapa()` de pruebas + hornear) y Pablo lo edita desde ahí. Es donde
  se prueba una pieza nueva (D) o una mecánica antes de meterla en un nivel.
- [ ] **7.13 (P2) Guía paso a paso en `poc_25d/LEEME.md`** ("Guía paso a
  paso para editar niveles"): hecha el 7/10 (Juego, a petición de Pablo;
  el Pipeline la mantiene junto con la sección 7.4). Añadir ahí cada cosa
  nueva que Pablo pregunte dos veces.
- [x] **7.14 (P1) Reglas separadas del nombre del nivel.** *(hecho el 7/10, 18:40, Pipeline: `PruebaTest2.reglas`; ver diario)* Hoy
  `PruebaTest2._ready` activa `Jugabilidad3D` solo si `nivel ==
  "jugabilidad"`; cualquier nivel nuevo de Pablo (`Nivel_Bosque.tscn` +
  `PruebaBosque.tscn` con `nivel = "bosque"`) cae en la rama del Test 2 y
  se juega sin objetivos. Pipeline: `@export var reglas: String =
  "ninguna"` (`"ninguna" | "jugabilidad"`) independiente de `nivel`, y que
  `Jugabilidad3D` lea sus marcadores (puerta, salida, losas, NPC,
  recogibles) de cualquier nivel, no del 23×23. Una hora. Así Pablo monta un
  nivel nuevo con tareas sin tocar código.
- [ ] **7.9** Cuando 7.1 y 7.5 estén: abrir `Nivel_Jugabilidad.tscn` en el
  editor, mover/girar tres piezas (puesto, un árbol, un tocón) y jugarlo
  (F6). Si lo que se ve es lo que choca, paso 1 cerrado. Luego construir el
  primer nivel propio con las piezas validadas.

### Juego (paso 1: ~1 día; paso 2: ~1–2 días)

- [x] **7.5 (P0) Contrato "qué pregunta el Juego al mundo".** **Resuelto de
  otra forma (Juego, diario 12:00):** en vez de un contrato de funciones, el
  Juego centralizó la solidez en `Lanzador3D.fuente` (`FuenteCasillas` /
  `FuenteNodos`): una casilla bloquea si hay un cuerpo en la capa 11
  (`CAPA_SOLIDO`); el Pipeline lo adoptó (12:40, 13:00) y `PruebaTest2`
  activa `FuenteNodos` tras cargar el `.tscn`. Queda publicado como
  contrato; `limites()` ya existe en `PruebaTest2`. Texto original: Publicar en el
  diario (y en `ESTADOS_SUELO.md` §8) la lista exacta de lo que el nivel
  horneado debe ofrecer, para que el cargador del Pipeline (7.2) lo
  implemente: `limites() -> Rect2i` (sustituye a `_lado`, los niveles ya no
  son cuadrados), `tipo_suelo(c) -> int` (`SUELO | AGUA | PUENTE | FUERA`;
  sustituye a `_letra`), `_bloqueadas` y `huellas` rellenos por el cargador
  desde las colisiones, `_helada`, `_al_impactar`, `_poner_canal`,
  `_img_estado`, `marcar_estado`, `_fx`, `_camara`, `_jugador`, `_goblins`,
  y los **marcadores**: grupo `barrera_fuego` (antes letra `B`), grupo
  `inicio_jugador`, grupo `goblin` con `tipo`, grupo `puerta`, grupo
  `baldosa` (antes letras del mapa de `jugabilidad_3d`). Es medio día y
  desbloquea al Pipeline: **va primero**.
- [x] **7.6 (P0) `letra_de` → `tipo_suelo`; `en_mapa` → `limites`.** **No
  hace falta:** el cargador deriva `_mapa` (letras) del GridMap y los
  marcadores, y pone `#` bajo las piezas de `Borde`, así que `letra_de`
  sigue siendo correcto con piezas movidas. Se revisa solo si 7.9 enseña
  una pared que no está. Texto original: En
  `lanzador_3d.gd` (11 usos), `playlog_3d.gd` (1) y `jugador_3d.gd`:
  `es_agua`, `y_pies`, `celda_solida`, `pisable`, `linea_libre`, hielo
  (`"agua": letra_de(c) == "~"`), `construir_tierra` (no sobre agua) y
  `colocar_barreras` (lee el grupo `barrera_fuego` en vez de buscar `B`).
  Mientras el cargador no exista, un adaptador de una línea
  (`tipo_suelo` a partir de `_letra`) mantiene jugable el mapa de letras.
- [x] **7.7 (P1) Huellas desde colisión.** Hecho por `FuenteNodos`: el
  jugador choca si una esfera de 0,3 m toca la malla de colisión real.
  Texto original: `calcular_huellas` hoy saca el
  círculo de cada pieza de `_lotes`/`_plantilla` (el decorado por lotes).
  Con nodos, el cargador (7.2) entrega por casilla la lista de formas que la
  tocan; `choca_huella` pasa a preguntar a la forma real
  (`PhysicsDirectSpaceState3D.intersect_point` o la caja de la forma) en vez
  del círculo aproximado. Es lo que quita la "casilla y media" del puesto.
- [ ] **7.8 (P1, paso 2) Jugador y goblins con física real.** `Jugador3D`
  pasa de `_puede_estar` a `move_and_slide` contra los `StaticBody3D` del
  nivel (capa `MUNDO`), conservando la altura (`y_pies`, salto de un nivel),
  el nado y los i-frames; `Combate3D` igual para guerrero y arquero
  (`NavigationAgent3D` opcional; con `move_and_slide` y el "rendirse a
  3,5 s" de hoy basta). Los hechizos **siguen en casillas**: `celda_solida`
  y `linea_libre` pasan a un `intersect_ray` contra la capa `MUNDO` más la
  altura de tierra. Los bloques de tierra y la cúpula de tierra ganan un
  `StaticBody3D` propio (hoy son colisión "lógica"). Solo si tras 7.9 hay
  choques raros; si el paso 1 va fino, se pospone.
- [ ] **7.8b (P2) F10 y PlayLog.** El overlay de F10 dibuja también las
  formas de colisión reales (no solo `_bloqueadas`) para ver de un vistazo
  qué choca; evento `nivel_cargado` con el nombre del `.tscn` y el número de
  piezas.

### Pipeline (~2–3 días)

- [x] **7.1 (P0) Piezas como escenas con colisión de malla.** Cada pieza del
  catálogo validada (árbol, arbusto, roca ×2, tocón ×2 orientaciones, seto,
  telaraña, puente, pasarela, puesto, señal, tótems, antorcha, fogata,
  cabaña…) pasa a `poc_25d/piezas/<id>.tscn`: `Node3D` raíz con ancla en la
  base, `MeshInstance3D`, `StaticBody3D` + `CollisionShape3D` **de la
  malla** (`convex` para lo compacto: tronco sin copa, roca, tocón, mesa del
  puesto sin toldo; `trimesh` solo para puente/pasarela), capa `MUNDO`;
  `Area3D` sin cuerpo para lo que no bloquea (hierba, telaraña); metadatos
  (`bloquea`, `reactivo`, `inflamable`, `huella`). `Reactivo3D` sigue
  siendo lo que es, dentro de su pieza.
- [x] **7.2 (P0) Horneador + cargador.** Script `@tool`
  (`poc_25d/hornear_nivel.gd`): recorre `_mapa()` de un nivel y escribe
  `poc_25d/niveles/Nivel_<nombre>.tscn` con una instancia de pieza por
  letra (posición y giro libres en `Transform3D`), el suelo como `GridMap`
  (o un plano por zona) con el tipo (`SUELO | AGUA | PUENTE`), y los
  **marcadores** del contrato 7.5 (jugador, goblins, puerta, baldosas,
  barrera de fuego, NPC, recogibles). Árboles del borde: agrupados en
  `MultiMeshInstance3D` por tipo al hornear, con la colisión aparte, para
  no pagar 600 nodos. El **cargador** (`prueba_test2.gd` o un
  `nivel_3d.gd` nuevo) abre el `.tscn` y rellena lo que el contrato 7.5
  pide a partir de los nodos: `limites`, `tipo_suelo` desde el `GridMap`,
  `_bloqueadas` y `huellas` desde las colisiones (por casilla: qué formas la
  tocan), `_goblins`, `_jugador`, etc. Modo "regenerar desde letras" con
  aviso. Primer nivel horneado: **`Nivel_Jugabilidad.tscn`** (el 23×23 de
  `jugabilidad_3d.gd`); `PruebaTest2` después.
- [x] **7.3 (P1) Reglas de `jugabilidad_3d.gd` sobre marcadores.** Las
  cuatro tareas, la puerta, el botín y los NPC pasan de letras a los nodos
  marcadores del `.tscn` (mismo comportamiento). La propagación del fuego en
  hierba (6.9a: solo 4 vecinas, 0,6 s por salto) se hace aquí de paso.
- [x] **7.4 (P1) Guía de edición.** Media página en `poc_25d/LEEME.md`: cómo
  abrir el nivel, la paleta de piezas (arrastrar `piezas/*.tscn`), girar con
  los gizmos, qué marcadores poner y qué no tocar; cómo regenerar desde
  letras y qué se pierde.

**Orden:** 7.5 (Juego, medio día) → 7.1 ∥ 7.6 → 7.2 → 7.7 ∥ 7.3 → 7.4 →
7.9 (Pablo) → 7.8 solo si hace falta. Mientras, lo de la fase 6 que queda
(6.9b en `spellbook.gd` es de Pablo; 6.20 del Pipeline; 6.2b del Juego)
sigue en paralelo: **nada de la fase 6 depende de la 7**.

---

## Fase 8 — Glifos como geometría (decidido por Pablo el 8/10)

**De dónde sale.** Pablo trajo el documento *Diseño matemático y funcional de
glifos 3D* (v0.3, 8/10). Resumen y decisiones en `DISENO_FUTURO.md` §3b. La
idea: cada glifo hace **una sola operación** sobre una forma (dar volumen,
estirar, mover, envolver) y las formas salen de componerlas. Sustituye a la
tabla v2 de §3, que se había convertido en una tabla de parejas («levitación +
barrera = pilar», «pulso + flecha = curva»…): justo lo que `ARQUITECTURA.md`
dice que no se escribe. Por eso 5.4 se quedó a medias.

**Decidido el 8/10 (Pablo):**
- La **esfera es la forma por defecto** y no tiene glifo: un hechizo sin Línea
  es una esfera de radio r₀. «Flecha sola = bola» sigue igual y el círculo
  queda para **Barrera**.
- El tamaño lo da un glifo nuevo, **Tamaño**: escala la forma que haya (radio
  de la esfera, largo de la línea). No toca la altura.
- Regla para cualquier glifo futuro: **o da forma, o transforma la que hay;
  nunca las dos cosas.**
- **Primera etapa con cinco glifos:** forma = **Línea, Altura**; propiedad =
  **Tamaño, Flecha, Barrera**. El resto (Elevación, Permanencia, Pulso,
  Repetición, Rebote) va a una segunda etapa y solo si el playtest 8.12 lo
  pide.

**Cada glifo (primera etapa), en casillas de 2,3 u:**

| glifo | tipo | operación | repetirlo | tope |
|---|---|---|---|---|
| (esfera) | forma por defecto | volumen de radio r₀ = 0,5 casilla (1 casilla) | — | — |
| Línea | forma | segmento perpendicular a la mirada, largo ℓ₀ = 3 casillas | no se repite: más largo es Tamaño | — |
| Altura | forma (modifica) | estira la forma hacia arriba 1 nivel; no la mueve | +1 nivel | tope Y (abajo) |
| Tamaño | propiedad | escala la forma: radio +0,5 casilla o largo +2 casillas | otra vez | ×3 |
| Flecha | propiedad | traslada la forma `d` = 3 casillas en la dirección del ratón | +1 casilla de alcance | 5 casillas |
| Barrera | propiedad | coloca la forma **alrededor del jugador**, hueca, y bloquea proyectiles | más resistencia (vida del escudo ×1,5) | ×3 |

Con eso salen sin escribir ninguna combinación:

| forma de hoy (`Receta3D.forma()`) | receta nueva |
|---|---|
| `proyectil` (bola) | (esfera) + Flecha |
| `corro` | (esfera) + Barrera |
| `columna` | (esfera) + Altura |
| `muro` quieto | Línea (+ Altura) |
| `muro` que avanza | Línea + Flecha |
| **`arco`** (nueva) | Línea + Barrera: la línea curvada delante del jugador |
| bola grande | (esfera) + Tamaño + Flecha |

**Orden fijo de evaluación** (no depende del orden de dibujo): forma base →
Altura → Tamaño → Barrera → Flecha → colisiones. **Tope Y combinado:** lo
que queda en pie y se puede pisar no pasa de `Jugador3D.MAX_NIVELES_SUBIBLES` (hoy 1) por
encima del suelo donde nace; si una receta lo supera, el libro lo avisa y no
se lanza (no se recorta en silencio). Los proyectiles no cuentan.

**Lo que se queda fuera del 3D** (siguen en el 2D, no se borran): amplificar,
retardo, atracción, espejo y pilar. **Lo que cambia respecto a lo decidido:**
varias flechas dan **alcance**, no duración (v2 decía duración); «pulso +
flecha = curva» desaparece; levitación pasa a ser Elevación en la etapa 2.

### Pablo

- [x] **8.0** Decidido el 8/10: el documento sustituye a la semántica v2 de
  §3; esfera por defecto; glifo Tamaño; primera etapa de cinco glifos.
- [x] **8.1 (P0) Confirmar tres cosas** *(confirmadas por Pablo el 8/10)* antes de 8.4: (a) varias flechas =
  más alcance (no duración); (b) se retira «pulso + flecha = curva»;
  (c) amplificar, retardo, atracción y espejo fuera del 3D.
- [x] **8.2 (P0) `sigils.gd`:** *(hecho el 8/10 22:20 por Claude con permiso de Pablo; además hacía falta `GestureLibrary.SIGILS` en `gesture_library.gd`, que es la lista que leen la paleta F1 y `Repertoire`)* entradas para `linea` (ya pendiente de 5.4),
  `altura` y `tamano` en `Sigils.FORM`, para que el libro y la paleta (F1)
  las reconozcan. Basta con el nombre y la recarga: el significado lo pone
  `Receta3D` en 3D, como ya hace con `linea`. Propuesta:
  `"linea": {"cooldown": 2.0}`, `"altura": {"cooldown": 2.0}`,
  `"tamano": {"cooldown": 1.5}`.
- [ ] **8.3 (P0) Gestos.** Barrera = círculo (ya grabado). Propuesta:
  **Altura = `⊥`**, el gesto que ya tiene plantilla con `pilar`, que sale del
  3D. **Tamaño = una cruz `+`** (en el sector no compite con el hielo `X`, que
  es del núcleo). Línea = la raya ya decidida. Grabar con `G` y pasar
  `tools/podar_gestos.py` para ver que Línea y Altura no se confunden.
- [ ] **8.12 Playtest de la etapa 1:** cada glifo solo y cada pareja de los
  cinco (15 filas), marcando ✔/✘ en `TEST2_CONCLUSIONES.md`. De aquí sale si
  hace falta la etapa 2 y qué glifos entran.

### Juego

- [x] **8.4 (P0) `GeometriaHechizo`: la receta como datos puros.** Clase
  nueva dentro de `poc_25d/lanzador_3d.gd` (junto a `Receta3D`): recibe los
  contadores de glifos y devuelve `{base: esfera|linea, radio, largo, alto,
  alcance, envuelve, bloquea, resistencia, y_tope}` en casillas, siempre en el
  mismo orden de evaluación. Sin nodos: se prueba en headless con la tabla de
  arriba (cada fila da la forma esperada, y los órdenes de dibujo distintos
  dan lo mismo).
- [x] **8.5 (P0) `Receta3D` lee de `GeometriaHechizo`.** `forma()` y
  `manifestaciones()` salen de la geometría y no de los flags de
  `SpellRecipe`. Los nombres de forma de hoy (`proyectil`, `corro`,
  `columna`, `muro`…) se conservan para que `Vfx3D`, `Formas3D` y la
  animación de lanzar no cambien. Levitación, pulso, repetición y rebote
  siguen funcionando como hoy hasta la etapa 2. El 2D (`SpellRecipe`,
  `spellcaster.gd`) no se toca.
- [x] **8.6 (P0) De forma a casillas, y tope Y.** La geometría se rasteriza:
  ocupan las casillas cuyo centro cae dentro de la forma, y ahí van los
  estados del suelo (fuego, hielo…) y los bloques de tierra/hielo. Tope Y
  combinado: si se supera, aviso y no se lanza.
- [x] **8.7 (P1) Forma nueva `arco`** (Línea + Barrera): la línea curvada
  delante del jugador, mismo largo, centrada en él; bloquea proyectiles.
- [x] **8.8 (P1) Previsualización.** En modo lanzar, dibujar en el suelo las
  casillas que va a ocupar el hechizo (las de 8.6) y su altura. Y, en el
  libro, avisar de una receta inválida (supera el tope Y) antes de lanzar.
- [ ] **8.9 (P2) Propuesta para `ARQUITECTURA.md`:** la tabla de glifos y la
  de «lo que emerge» con la versión geométrica, en
  `docs/propuesta_arquitectura_juego.md` (Pablo integra).

### Pipeline

- [ ] **8.10 (P0) Contrato VFX con parámetros.** Las formas del contrato 5.8
  pasan a leer sus medidas de la geometría (`radio`, `largo`, `alto`): una
  bola con Tamaño es la misma bola más grande, no otra celda de la matriz.
  Añadir **`arco`** (anillo parcial delante del jugador, del elemento).
  Muro y corro ya existen.
- [ ] **8.11 (P1) Iconos** de `altura` y `tamano` (y `linea`, pendiente de
  6.20), con el estilo de los demás.

**Orden:** 8.1 → 8.2 ∥ 8.3 ∥ 8.4 → 8.5 → 8.6 → 8.7 ∥ 8.10 → 8.8 ∥ 8.11 →
8.12 → (etapa 2). **La fase 6 y la 7 siguen en paralelo**; 5.4 queda
sustituida por esta fase (lo hecho de `linea` en `Receta3D` se aprovecha).

---

## Reparto resumido

| | Pablo | Juego | Pipeline |
|---|---|---|---|
| Fase 0 | 0.1–0.6 | — | — |
| Fase 1 | 0.7 | 1.1, 1.2, 1.4 | 1.3, 1.5, 1.6, 1.7, 1.8, 1.9 |
| Fase 2 | 2.3 | 2.1 | 2.2 |
| Fase 3 | 3.9, 3.10 | 3.0–3.5 | 3.6–3.8 |
| Fase 4 (Test 3) | 4.0, 4.11, 4.12 | 4.1–4.5 | 4.6–4.10 |
| Fase 5 (glifos v2, VFX, bosque) | 5.13–5.15 | 5.1–5.8 | 5.9–5.12 |
| Fase 6 (playtest 7/10) | 6.0, 6.21–6.24 | 6.1–6.9, 6.2b, 6.22a | 6.10–6.20 |
| Fase 7 (nivel editable, camino A) | 7.0, 7.9, 7.10 | 7.5–7.8b, 7.11 (parte) | 7.1–7.4, 7.11–7.14 |
| Fase 8 (glifos como geometría) | 8.0–8.3, 8.12 | 8.4–8.9 | 8.10, 8.11 |
| Deuda pequeña | iluminación | stride, pilar/tiempo, diálogo | clips, iconos, VFX, tótems |

Dependencias: 1.1 antes de 2.1 · 1.6 antes de `stride` · 3.6 antes de 3.2 · 3.9 antes de las P2 · 0.2 espera a 1.3.
