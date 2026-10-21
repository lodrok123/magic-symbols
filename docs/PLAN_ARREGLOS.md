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

## Fase 9 — Nivel Bosque 1 (concepto de Pablo del 10/10: `Nivel_Bosque_1_Concept.xlsx`)

**Qué es.** Primer nivel «de verdad» en 3D. Pasillo de bosque de 12 casillas de
ancho y ~47 de largo, más una sala a la derecha (4 × 13) con el elemental.
Se empieza **abajo a la izquierda, junto a la librera**, y se sube. Para
pasar la **puerta final** (V44 en la hoja) hay que activar los **tres tótems**
(fuego, agua y rayo); cada tótem activado **ilumina su runa en la puerta**, y
con las tres se abre. Detrás está el **elemental**; la **salida** se abre al
matarlo.

**Decidido por Pablo (10/10):**
- **Casillas moradas (detrás de la telaraña) = se recoge el sello de agua.**
- **Tótem de rayo = conducir la electricidad por el agua.** La fuente de
  electricidad es permanente; el surtidor echa agua cuando le das con agua y
  llena el cauce seco, que baja al río; la corriente viaja por el agua hasta
  el tótem de rayo, que está en la orilla. El jugador **no** tiene rayo.
- **Las 4 antorchas de arriba activan el tótem de fuego** (las cuatro
  encendidas = tótem activo). Las 4 de abajo, junto a la librera, son de
  práctica: enseñan a encender.
- **Inicio abajo, junto a la librera.** La puerta V44 es la de las tres
  runas; la salida (AA44) se abre al matar al elemental.

**Recorrido que sale del mapa** (para comprobar en el playtest):
1. Inicio en la zona de la librera (cerrada). La librera da consejos; las 4
   antorchas de práctica enseñan a encender con **fuego + flecha**.
2. **Quemar la telaraña** → zona morada → **sello de agua**.
3. Cruzar el **puente** del río → camino de tierra → **guardabosques**: vende
   el glifo **barrera**, dice que la puerta necesita las tres runas y avisa
   de no echarle agua al elemental (lo cura y lo agranda).
4. Subir por el camino. Arriba: goblins (1 arquero, 4 guerreros), **tótem de
   agua** encerrado por una **barrera de fuego** (apagarla con agua), **tótem
   de fuego** rodeado de **hierba alta** (quemarla) y con 4 **antorchas**.
5. **Surtidor + cauce + fuente eléctrica** → tótem de rayo.
6. Tres runas → puerta → **elemental** (débil al fuego) → salida.

**Kit del nivel** (sustituye a `nivel1` para este nivel): empieza con
**fuego + flecha**, **una página con 1 hueco de sello y 2 de glifo** (Pablo,
10/10); **barrera** se compra por **20 oro**; **agua** se recoge. El goblin
guerrero de la zona de inicio suelta 20 oro fijos para poder comprarla (es
para probar la tienda).

**Supuestos sobre la hoja** (confirmados por Pablo el 10/10):
- Rojo sin nombre alrededor del tótem de agua (K6–K11, J11) = **barrera de
  fuego** (`B`). Rojo con nombre = enemigo.
- Gris claro sin leyenda (toda la mitad de arriba) = **suelo variado al
  azar** (Pablo: «randomízalo y ponlo como sea»). El mapa de abajo lo deja en
  `.`; el horneado (9.6) lo reparte entre suelo, hierba corta y manchas de
  tierra, **sin hierba alta** (arde y cambiaría el puzle del fuego).
- Negro = **borde de árboles** (`#`), también las paredes interiores (fila
  22, fila 36, columna M).
- «Elemental de tierra» = el **elemental de bosque** que ya existe (`G`). La
  pista del guardabosques dice «elemental de agua»: se entiende «no le eches
  agua al elemental» (el agua lo cura).
- Fuente eléctrica en J31, surtidor en L31 e inicio en J51: puestos así en
  el mapa; Pablo los mueve en el editor si hace falta.
- Arcos de piedra (R44, J46) = pieza `arco_ruina`, decorado por el que se
  pasa. Puente (O44–Q44) = una casilla de puente sobre el río (P44).
- «Suelo de piedra» está en la leyenda pero no aparece en el mapa.

**Mapa en letras** (sacado de la hoja; columna I = x 0, fila 5 = y 0).
Letras de `marcador_3d.gd` y del GridMap salvo las nuevas, marcadas con ★:

```
###################
#kB......v.j.######
#.B......v...######
#.B......v...######
#.B......vT.T######
#.B......v...######
#BB......v...######
#........v...######
#........vT.T######
#........vvvv######
#.A..........######
#............######
#.........W..######
#............######
#.WW.........######
#............######
#............######
#......############
#............######
#............######
#............######
#............######
#............######
#............######
#............######
#............######
#ecu.........######
#.c..........######
#.c..........######
#~~~~~~~ggggg######
#~~~~~~~vvggg######
#####,v~vvggg######
#,v,#,v~ggggg######
#,ggra,~ggggg######
#vWgra,~ggggg######
#vggra,~ggggg#,,,,#
#,gv#,,~igggg#,,,,#
#,gv#,,~ggggg#,,,,#
#vgv#,,~ggggg#,,,,#
#,g,#,,bgUgggX,,,GE
#vgv#,,~ggggg#,,,,#
#Ugg#,,~gmggg#,,,,#
#T,T#,,~ggggg#,,,,#
#T,T#,,~ggggg#,,,,#
#M,,#,,~ggggg#,,,,#
#.,,#,,~ggggg#,,,,#
#S,,#,,~ggggg#,,,,#
#.,,#,,~ggggg#,,,,#
###################
```

| letra | qué | | letra | qué |
|---|---|---|---|---|
| `#` | borde de árboles | | `k` `j` `i` | tótem de agua / fuego / rayo |
| `.` | suelo | | `B` | barrera de fuego |
| `,` ★ | hierba corta, no arde (decorado) | | `T` | antorcha (brasero) |
| `v` | hierba alta (arde) | | `r` | telaraña |
| `g` | camino de tierra | | `a` | zona del sello de agua (losa de agua) |
| `~` | agua (río) | | `A` `W` `G` | goblin arquero / guerrero / elemental |
| `b` | puente | | `M` `m` | librera / guardabosques (NPC) |
| `c` ★ | cauce seco (se llena de agua) | | `X` | puerta final (3 runas) |
| `e` ★ | fuente de electricidad permanente | | `E` | salida (bloqueada) |
| `u` ★ | surtidor: echa agua si le das con agua | | `S` | inicio del jugador |
| `U` ★ | arco de piedra (pieza `arco_ruina`, no marcador) | | | |

### Pablo

- [x] **9.0** Decidido el 10/10: sello de agua tras la telaraña; rayo por
  conducción; antorchas de arriba = tótem de fuego; inicio junto a la
  librera; salida tras el elemental.
- [x] **9.1 (P0) Revisar los supuestos y el mapa en letras** de arriba
  *(10/10: supuestos confirmados; gris de arriba al azar; página con 1 sello
  y 2 glifos; barrera a 20 oro; el goblin de la zona de inicio suelta 20 oro)*.
- [ ] **9.2 (P1) Textos de los NPC.** El Juego los redacta con la voz de
  `CONTEXTO.md` a partir de la hoja; Pablo los aprueba.
- [ ] **9.3** Tras el horneado (9.6): ajuste fino en el editor (giros,
  decorado, arcos) y **playtest** del nivel entero.
- [ ] **9.4 Limpieza:** `poc_25d/niveles/nivel_Bosque.tscn` (con «n»
  minúscula) es una copia del 23 × 23 de jugabilidad, no el bosque. El
  horneado escribirá `Nivel_Bosque.tscn`; borra o renombra la vieja para que
  no haya dos que solo se distinguen por la mayúscula (Windows no las
  distingue, Godot sí).

### Pipeline

- [x] **9.5 (P0) Mapa desde archivo (D2 del 8/10).** `PruebaTest2` lee las
  letras de `poc_25d/niveles/mapas/<nivel>.txt` (el mapa de arriba, tal
  cual) y F9 hornea `Nivel_Bosque.tscn`. El mapa no es cuadrado (19 × 49):
  `limites()` ya sale del GridMap.
  *(10/10: hecho, ver diario.)*
- [x] **9.6 (P0) Letras y suelos nuevos** (`marcador_3d.gd`, GridMap
  `suelo_tipos.tres`, horneador): `,` hierba corta decorativa (no arde),
  `c` cauce seco (tipo de suelo propio: lecho de piedras; se vuelve agua),
  `e` fuente eléctrica (marcador, grupo `reactivo`, tipo `emisor_rayo`),
  `u` surtidor (marcador, grupo `reactivo`, tipo `surtidor`), `U` pieza
  `arco_ruina`. **El suelo `.` de la mitad de arriba (filas 1–28 del mapa) se
  reparte al azar** entre suelo, hierba corta y manchas de tierra, sin hierba
  alta. Hornear `Nivel_Bosque.tscn` y la escena `PruebaBosque.tscn`
  (`nivel = "Bosque"`, `reglas = "bosque"`), y la línea en `prueba_test2.gd`
  que crea las reglas `Bosque3D` cuando `reglas == "bosque"`.
  *(10/10: hecho; falta que Pablo borre `nivel_Bosque.tscn` (9.4) y pulse F9 en `PruebaBosque`.)*
- [x] **9.7 (P1) Arte nuevo:** puerta final con **tres runas** (fuego, agua,
  rayo) que se iluminan por separado (`arco_puerta` + 3 símbolos con
  emisión); **fuente eléctrica** (cristal/piedra con chispas permanentes);
  **surtidor** (fuente de piedra; chorro al activarse); **lecho del cauce**
  seco y su paso a agua; **agua electrificada** (chispas que recorren el
  agua). Vfx: lo que pida el Juego en 9.10–9.11.
  *(10/10: hecho como primera versión; falta verla con Forward+ y el glow.)*

### Juego

- [x] **9.8 (P0) Reglas del bosque** (`poc_25d/bosque_3d.gd`, nuevo,
  `class_name Bosque3D`, como `Jugabilidad3D`): puerta `X` con tres runas
  (cada tótem activado ilumina la suya; con las tres se abre); tótem de fuego
  activo cuando las **4 antorchas de arriba** están encendidas (las de abajo
  no cuentan); salida `E` bloqueada hasta que muere el elemental; HUD de
  objetivos (las tres runas).
  *(10/10, Juego: hecho y probado en headless con una maqueta falsa y el mapa
  de arriba; falta probarlo en el nivel real cuando el Pipeline entregue 9.5/9.6
  y enganche `Bosque3D`: ver el diario del 10/10 03:00.)*
- [x] **9.9 (P0) Kit del nivel:** progresión `bosque` en `PROGRESIONES`
  (fuego + flecha; una página con 1 hueco de sello y 2 de glifo); la zona `a` desbloquea el **agua**
  (`Repertoire.unlock_element`, con aviso); el **guardabosques vende la
  barrera** por 20 oro (tienda mínima en 3D: oro → `unlock_sigil`). **El
  goblin guerrero de la zona de inicio (K39 en la hoja; fila 34 del mapa)
  suelta 20 oro fijos** (Pablo, 10/10: es para probar la tienda), así la
  barrera se puede comprar en cuanto se llega al guardabosques.
  *(10/10, Juego: hecho. Tienda = E para hablar y E otra vez para comprar. La
  progresión se elige por el nombre del nivel: `nivel = "Bosque"`.)*
- [x] **9.10 (P0) Rayo que conduce por el agua en 3D** (hoy solo salta entre
  enemigos mojados): `emisor_rayo_3d.gd` (D4, ya asignado al Juego) mete
  corriente en las casillas de agua **conectadas** a la suya, cada X s; un
  tótem de rayo en la orilla de esa agua se activa; quien esté en el agua
  electrificada recibe daño. Medir que la cadena J31 → cauce → río → Q41
  llega.
  *(10/10, Juego: `emisor_rayo_3d.gd`. Medido sobre el mapa en letras: la
  corriente llega a la casilla pegada al tótem de rayo (25 casillas de agua
  conectadas una vez lleno el cauce; 0 antes).)*
- [x] **9.11 (P0) Surtidor y cauce:** el surtidor `u` recibe agua → las
  casillas `c` pasan a agua de verdad (`tipo_suelo` AGUA) y se unen al río.
  Es la regla «agua que rellena» de 5.5, en pequeño.
  *(10/10, Juego: `surtidor_3d.gd`. Cambia la letra de la casilla a `~`; el dibujo
  del agua nueva lo hará el Pipeline con `poner_agua(celdas)`, mientras tanto
  sale una losa azul.)*
- [x] **9.12 (P1) NPC:** diálogos de librera y guardabosques a partir de la
  hoja (borrador para 9.2), con la pista del elemental.
  *(10/10, Juego: borrador en `Bosque3D.DIALOGOS`; Pablo lo aprueba en 9.2.)*
- [x] **9.13 (P1) Elemental en sala estrecha:** la sala mide 4 casillas de
  ancho; comprobar que el elemental de 2,5 u, sus enredaderas y su puñetazo
  caben y no atraviesan la pared.
  *(10/10, Juego: medido, cabía pero atravesaba la pared (el centro llegaba a
  0,05 u del borde, con un cuerpo de ~1 u de radio). Arreglado en
  `Combate3D._cabe_con_cuerpo`: ahora se para a 1,05 u.)*

**Orden:** 9.1 → 9.5 ∥ 9.8 ∥ 9.9 → 9.6 → 9.10 ∥ 9.11 → 9.7 ∥ 9.12 ∥ 9.13 →
9.3. Mientras no exista 9.5, el Pipeline puede hornear pegando el mapa en una
constante, como `Jugabilidad3D.MAPA`.

---

## Fase 10 — Lo visto en el playtest del Bosque (Pablo, 10/10 04:00)

Pablo jugó `PruebaBosque`. Cuatro puntos:

1. **Falta esquivar y tomar distancia.** La voltereta **ya existe** (tecla
   **Ctrl**, `Jugador3D._iniciar_voltereta`), pero no se descubre: no sale en
   ningún sitio. Además, si no te mueves no tiene a dónde ir.
2. **La barrera (cúpula) se queda pequeña:** debe **englobar al personaje**,
   al menos el doble. Hoy se dibuja al 20 % del radio del aro
   (`ESCALA_CUPULA = 0.2` en `lanzador_3d.gd`, pedido del 6/10): ≈ 0,7 u de
   radio para un personaje de 1,0 u de alto.
3. **Pablo edita él mismo el mapa** del bosque: `poc_25d/niveles/mapas/Bosque.txt`.
4. **Cámara que gira 90°.** Con la cámara fija hay cosas que se ven peor (p.
   ej. la puerta `X` queda detrás de la columna de árboles, lo avisó el
   Pipeline). Propuesta: mantener la vista inclinada y ortográfica de hoy y
   **girarla en pasos de 90°** con dos teclas, con un giro suave. Cambia poco
   código porque el mundo ya es 3D: lo que hay que adaptar es el movimiento
   (WASD es fijo al mundo: W = −Z) y lo que depende de la dirección de la
   cámara (oclusión, rótulos).

### Pablo

- [ ] **10.0** Decidir las teclas de girar la cámara (propuesta: **Z / C**;
  Q es poción, E es hablar) y si «2,5D» significa algo más que el giro
  (p. ej. perspectiva en vez de ortográfica).
- [ ] **10.1** Editar `mapas/Bosque.txt` (formato en su cabecera: una fila
  por línea, `;` = comentario, `; azar_suelo` y `; giro`). Mientras no exista
  `Nivel_Bosque.tscn`, F6 en `PruebaBosque.tscn` lee el `.txt` directamente;
  cuando hornees (F9), manda el `.tscn` y el `.txt` deja de leerse (desmarca
  `usar_escena` para volver a él). Recuerda borrar `niveles/nivel_Bosque.tscn`
  (9.4).
- [ ] **10.7** Playtest del giro de cámara y de la voltereta.

### Juego

- [ ] **10.2 (P0) Voltereta descubrible y para tomar distancia.** Comprobar
  que **Ctrl** rueda en `PruebaBosque`; enseñar la tecla en el HUD (junto a
  Q/E); **sin dirección de movimiento, rodar hacia atrás**, alejándose de
  donde apunta el ratón (es lo que pide «tomar distancia»). Si Pablo prefiere
  otra tecla, es una línea.
- [ ] **10.3 (P0) Cúpula de la barrera al menos el doble:** `ESCALA_CUPULA`
  de 0,2 a **0,4** como mínimo (≈ 1,4 u de radio) y comprobar que tapa al
  personaje entero (1,0 u de alto). Solo cambia
  el dibujo; el escudo que absorbe (`VIDA_ESCUDO`) sigue igual.
- [ ] **10.4 (P0, tras 10.0) Movimiento relativo a la cámara:** WASD se
  calcula con los ejes de la cámara girada, no con los del mundo. El apuntado
  con ratón ya usa el rayo de la cámara y no cambia.

### Pipeline

- [ ] **10.5 (P0, tras 10.0) Giro de cámara en pasos de 90°** en
  `prueba_test2.gd` (`_colocar_camara` con un ángulo de giro; tween de
  ~0,3 s; el foco sigue al jugador). Exponer el ángulo para que el Juego
  oriente el movimiento (10.4). Adaptar lo que depende de la dirección de la
  cámara: `Ocluso3D` (qué se transparenta), rótulos, runas de la puerta y
  cualquier imagen plana que solo se vea bien de frente.
- [ ] **10.6 (P1)** Revisar el nivel girado: piezas o VFX que solo se
  vieron de un lado (caras sin textura, sombras, la hierba).

**Orden:** 10.2 ∥ 10.3 (ya) · 10.0 → 10.5 → 10.4 → 10.6 → 10.7. 10.1 cuando
Pablo quiera; no bloquea nada.

---

## Fase 11 — Agua con física (Pablo, 12/10)

**Qué pide Pablo.** El agua de hoy no le gusta: **llenarse es falso** (el canal
se llena con una tira animada), **no reacciona** (pisarla o darle con un
hechizo no hace nada) y **no se siente como un fluido ni ocupa su sitio**. La
física tiene que cambiar **cómo se juega**, no solo cómo se ve, y los objetos
tienen que **flotar para los puzles**. Repositorios que trajo, leídos el
12/10:

| repositorio | qué es | qué tomamos |
|---|---|---|
| AstroStucky/EasyFluidSim (Godot 4.2, dominio público) | 2D: gotas como cuerpos rígidos dibujadas con *metaballs* (se pintan borrosas en una capa y se corta por umbral) | la técnica de **metaballs** para el dibujo de chorros, caídas y el hechizo de agua; nada de su física (no da un nivel de agua que el juego pueda preguntar) |
| sjb8100/godot-WaterPack (Godot 3.0, MIT, 2018) | sombreadores de agua (olas Gerstner, espuma por profundidad, refracción), suelo mojado por mapa, flotación por puntos, ondas 2D con muelles | ideas de **suelo mojado por mapa**, **espuma**, **flotación por puntos**; el código es de Godot 3 y no carga en 4.7: se rehace |
| itzMeerkat/Godot-RealisticEnvironments (Godot 4.8, MIT) | océano realista por FFT y cómputo en GPU, ondas interactivas iWave alrededor de los barcos | solo la **idea** de ondas que se propagan desde lo que toca el agua (decidido por Pablo: nada de su código, el proyecto sigue en 4.7 y es cartoon) |
| CaptainProton42/DynamicWaterDemo (Godot 3.2, MIT, 2020; leído el 12/10) | ondas por la **ecuación de ondas en la GPU**: un `ColorRect` con un sombreado en un `Viewport` que se recalcula cada paso (5 puntos, estable si `a = (c·dt·N)² < 0,5`); una **cámara ortográfica bajo el agua** que mira hacia arriba y pinta solo los objetos de una capa con `cull_front`: así sabe **qué atraviesa la superficie** y a qué velocidad, y crea la onda sola; una **máscara de tierra** donde las ondas valen 0; **flotación por sondas** (fuerza lineal con la profundidad y amortiguación, en cada esquina) | es casi exactamente 11.8 y 11.6: tomamos el **método** de las ondas (ping-pong de dos `SubViewport` en Godot 4, sin su copia por CPU `get_data/set_data` en cada paso, que es lenta), la **cámara de colisiones** (las ondas salen solas de todo lo que toca el agua, sin llamar a nada) y las **sondas** para flotar. No sirve su agua (un plano de nivel fijo, sin volumen ni corriente) |

**Decisión técnica (Juego, 12/10): el agua es una cantidad por trocito de
suelo** (`poc_25d/agua_sim_3d.gd`, `AguaSim3D`). Modelo de «tuberías
virtuales» (O'Brien y Hodgins 1995; Mei et al. 2007): cada trocito empuja agua
a sus 4 vecinos según la diferencia de altura de la superficie, con inercia.
Rejilla de 3 × 3 trocitos por casilla (0,77 u). Baja por las pendientes,
llena los huecos hasta el borde, se nivela, la tierra hace de presa, el hielo
la para, el suelo retiene una lámina de 0,03 u que no corre (sin eso un
manantial se volvía una película que el suelo se bebía entera y el agua no
llegaba a ningún sitio) y se bebe los restos, y la casilla queda **mojada**
(se seca en 20 s). El juego sigue preguntando por **casillas**
(`es_agua_casilla`, `se_nada_en`, `profundidad_casilla`); el dibujo lee una
**textura** con la superficie, la profundidad y la corriente de cada trocito.
Probado con un gemelo en Python (conserva el volumen exacto, estable, se
calma); **sin probar todavía en Godot**: lo hace la prueba 11.1.

### Pablo

- [ ] **11.0** Aprobar el enfoque (agua por trocitos que el juego pregunta
  por casilla; el dibujo, del Pipeline) y los números de partida:
  `UMBRAL_AGUA` 0,25 u (desde ahí una casilla es agua), `UMBRAL_NADO`
  0,55 u, se seca en 20 s, 30 pasos por segundo.
- [ ] **11.1 (P0)** Ejecutar la prueba sin ventana, desde la carpeta del
  proyecto: `godot --headless --path . --script
  res://poc_25d/herramientas/prueba_agua_sim.gd`. Debe acabar en
  «FALLOS: 0» y da los milisegundos por paso en el río del Bosque (si pasa de
  4 ms, se baja a 2 × 2 trocitos por casilla).
- [ ] **11.11** Playtest en el laboratorio (11.2) y luego en el Bosque.

### Juego

- [x] **11.1b** `poc_25d/agua_sim_3d.gd` (`AguaSim3D`) y su prueba
  `poc_25d/herramientas/prueba_agua_sim.gd` (12/10).
- [x] **11.2 (P0) Laboratorio `LabAgua3D.tscn`** *(hecho el 12/10, `poc_25d/lab_agua_3d.gd`; sin abrir en Godot: F6 y mirar la consola)* con dibujo de depuración
  (una caja por trocito, más alta y más azul cuanta más agua): un hoyo que se
  llena, una presa de tierra que se levanta y se quita, un manantial que baja
  por una escalera de dos niveles y un río con salida. Para que Pablo juzgue
  la física antes de que exista el dibujo bueno. Controles: clic izquierdo
  echa agua, clic derecho levanta o quita tierra, H hiela, F abre o cierra el
  manantial, R empieza de nuevo. Medido con el gemelo en Python: en 60 s el
  manantial baja la escalera, el hoyo se llena hasta el borde (1,1 u) y el
  río lleva el agua a la salida a ~0,5 u/s.
- [ ] **11.3 (P0) Enchufarlo al Lanzador.** `Lanzador3D` crea un `AguaSim3D`
  al cargar el nivel (suelo de `y_pies`, paredes de lo que bloquea), llena
  las casillas `~` hasta su superficie y fija el nivel donde el río entra o
  sale del mapa. `es_agua(c)` pasa a preguntar a la simulación (con la letra
  como respaldo si no hay simulación); `cambios()` mantiene al día el bloqueo
  a pie, el nado y lo que hoy depende de «~». Nado con `se_nada_en`; en agua
  baja se anda más despacio.
- [x] **11.4 (P0) Hechizos y estados sobre el agua:** *(hecho el 12/10 en `lanzador_3d.gd`, `hechizo_sobre_agua`; medido en `herramientas/prueba_agua_hechizos.gd`; el chorro de agua es un manantial mientras dura)* el hechizo de agua
  **echa volumen** donde cae (bola: un charco; chorro: un caudal mientras
  dura) y moja lo que toca; el fuego **evapora** (`quitar`, con vapor); el
  hielo **hiela las casillas** (`helar_casilla`: el agua se queda quieta y se
  pisa); la tierra **hace de presa** (`solidificar_casilla`); el rayo conduce
  por las casillas que son agua según la simulación (`EmisorRayo3D` ya usa
  `es_agua`).
- [x] **11.5 (P0) Surtidor y canal de verdad:** *(hecho el 12/10 en `surtidor_3d.gd`: abre el cauce y echa un manantial; el canal de ruinas `-`/`L` cuenta como cauce desde el 12/10 tarde; sin abrir el Bosque con ventana)* el surtidor es una
  `fuente_en` y el canal se llena porque el agua corre por él (sustituye al
  llenado por tiempo de `Surtidor3D`; el dibujo de `Canal3D` lo sustituye
  11.7).
- [ ] **11.6 (P1) Flotación para puzles** (`poc_25d/flotador_3d.gd`, nuevo; método de las sondas de DynamicWaterDemo: fuerza lineal con lo sumergido y amortiguación, en 4 puntos, leyendo `superficie_en` de `AguaSim3D`, no de la textura de ondas):
  troncos, cajas y empujables que caen al agua flotan en la superficie
  (`superficie_en`), la corriente los arrastra (`corriente_en`) y se paran
  contra la orilla; un tronco atascado entre dos orillas **se puede pisar**
  (puente). Flotación por varios puntos, como el *buoyancy* de WaterPack.

### Pipeline

- [x] **11.7 (P0) Dibujo del agua desde la simulación.** *(Pipeline, 12/10: `poc_25d/agua_render_3d.gd`, `AguaRender3D`; dibujo por defecto en `LabAgua3D` (Y = cajas); en `PruebaTest2` tras `agua_fisica`, apagado hasta que Pablo lo apruebe. Capturado en Godot 4.7; falta verlo en el PC de Pablo. Falta el hielo: ver diario (32).)* Una malla de
  rejilla (un vértice por trocito) que lee `AguaSim3D.textura()` (R =
  altura de la superficie, G = profundidad, B/A = corriente): los vértices
  suben con el agua (se ve llenarse, rebosar y nivelarse), transparencia y
  orilla por la profundidad, **espuma donde corre o rompe**, franjas
  orientadas con la corriente. Mantener el aspecto estilizado de facetas que
  aprobó Pablo (13/10 (8)). Sustituye al plano de `CODIGO_AGUA` y a las tiras
  de `Canal3D`.
- [x] **11.8 (P1) Ondas que reaccionan** (método de DynamicWaterDemo) *(Pipeline, 12/10: `poc_25d/agua_ondas_3d.gd`, `AguaOndas3D.impulso(pos, fuerza, radio)` + máscara de agua; **sin** la cámara bajo el agua: las ondas no nacen solas, el Juego llama a `impulso()`; ver diario (32))*:
  ecuación de ondas en dos `SubViewport` en ping-pong (sin pasar por la CPU)
  sobre la zona de la cámara; una **cámara ortográfica bajo el agua** pinta
  la capa `agua_contacto` (cápsulas simples colgadas del jugador, goblins,
  troncos y proyectiles, con `cull_front` y su velocidad como color): las
  ondas nacen solas donde algo atraviesa la superficie; donde la simulación
  dice que no hay agua (G = 0) las ondas valen 0. Se suma al dibujo de 11.7
  (normal y algo de altura).
- [x] **11.9 (P1) Chorros, caídas y salpicaduras con *metaballs*** *(Pipeline, 12/10: `poc_25d/agua_metaballs_3d.gd`, `chorro()`/`salpicadura()`/`detener()`; se pinta encima de la escena, sin profundidad)* (la
  técnica de EasyFluidSim en 3D): gotas que se dibujan borrosas y se cortan
  por umbral, para que el chorro del surtidor, la caída al canal y el hechizo
  de agua parezcan un líquido continuo y no partículas sueltas.
- [x] **11.10 (P1) Suelo mojado** *(Pipeline, 12/10: el shader del suelo ya lee `mojado_fisico`; se enciende solo cuando `AguaSim3D.textura_mojado()` exista, 11.4 del Juego)*: el suelo se oscurece y brilla donde
  `casilla_mojada` (o el canal G de la textura) lo dice, y se seca poco a
  poco (idea del `wet_dirt` de WaterPack).

### Hielo de verdad (Pablo, 12/10 14:50)

El agua helada tiene que **ser hielo**: decidido por Pablo:
- **Se hiela la zona del impacto** (el radio del hechizo), siguiendo la forma
  real del agua, no casillas enteras.
- **Se pisa a la altura del agua**, sea cual sea su nivel.
- **Resbala**: cuesta frenar y girar.
- **Bloquea proyectiles** si es grueso (agua honda).
- **Atrapa lo que hay dentro** (troncos, enemigos) hasta que se derrite.
- **Se deshace con el tiempo (20 s) o con fuego**, y vuelve a ser **la misma
  agua** (ni se pierde ni se gana).

- [x] **11.12 (P0, Juego) Hielo en la simulación** *(hecho el 12/10; `prueba_agua_sim.gd` pruebas 8–11)* (`agua_sim_3d.gd`):
  `helado` pasa a ser por **trocito** y con tiempo: `helar(pos, radio,
  segundos)` hiela los trocitos con agua (prof > RETIENE) del círculo y
  guarda el tiempo que les queda; `derretir(pos, radio)` los suelta (fuego);
  al acabar el tiempo se sueltan solos. Un trocito helado conserva su agua y
  no deja pasar caudal. Consultas: `hielo_en(pos) -> float` (Y de la cara
  de arriba del hielo, o −INF), `casilla_helada(c)` (≥ 5 de 9 trocitos),
  `espesor_hielo(c)`. Textura para el dibujo: `textura_hielo()` (RG8: R = 1
  helado, G = lo que le queda, 0-1). Pruebas: helar la mitad de un estanque
  → la otra mitad sigue corriendo; derretir → el volumen total es el mismo.
- [x] **11.13 (P0, Juego) Propiedades del hielo en el juego** *(hecho el 12/10; medido en `herramientas/prueba_hielo.gd`; sin abrir en Godot con ventana)*
  (`lanzador_3d.gd`, `jugador_3d.gd`, `combate_3d.gd`, `flotador_3d.gd`):
  el hechizo de hielo sobre agua llama a `helar` (radio del impacto,
  `DURA_HIELO` = 20 s); el fuego a `derretir`. `_helada` de la maqueta se
  rellena desde `casilla_helada` para que todo lo que ya pregunta por
  `_helada` siga valiendo. **Pisar:** `y_pies` de una casilla helada = cara
  de arriba del hielo. **Resbalar:** sobre hielo el jugador conserva su
  velocidad (aceleración `HIELO_ACEL` ≈ 3 u/s² en vez de inmediata,
  rozamiento `HIELO_FRENO` bajo, giro más lento). **Cobertura:** una casilla
  helada con `espesor_hielo` ≥ `HIELO_COBERTURA` (0,5 u) cuenta como sólida
  para los proyectiles (no para andar). **Atrapar:** al helarse, lo que esté
  dentro del agua helada queda preso: `Flotador3D` se congela (`freeze`),
  los goblins entran en su estado «congelado» mientras dure; al derretirse,
  se sueltan. El jugador **no** queda preso: se le sube a la cara del hielo.
- [x] **11.14 (P1, Pipeline) Dibujo del hielo** *(hecho el 12/10; probado en LabAgua3D con `AguaSim3D.helar`; Bosque sin probar en la nube; costra en `costra_hielo_3d.gd`)* (`agua_render_3d.gd`): lee
  `textura_hielo()`; los trocitos helados se pintan como hielo (blanco
  azulado, opaco, facetas con grietas, sin franjas ni espuma ni ondas, un
  poco más alto que el agua); al helarse, el hielo crece desde el punto del
  impacto en ~0,3 s; con G < 0,15 (le queda poco) aparecen grietas y se
  oscurece, avisando de que se va a romper. Los goblins atrapados llevan una
  costra de hielo (la del estado congelado, si ya existe).

### El Bosque como laboratorio (Pablo, 12/10 15:45)

`PruebaBosque` es **nuestro laboratorio para iterar**: lleva el **kit de
pruebas** (todos los sellos, hielo incluido, y todos los glifos) y el agua
física encendida. El kit del nivel de verdad (`bosque`: fuego + flecha, la
barrera se compra, el agua se recoge) se queda para cuando el nivel se juegue
como nivel.

- [x] **11.15 (P0, Juego) Kit de pruebas elegible por escena**
  (`lanzador_3d.gd`): `PROGRESIONES["pruebas"]` = lo mismo que `todo`
  (fuego, agua, viento, tierra, rayo, **hielo**; todos los glifos; 3
  páginas). `_ready` elige la progresión así: `PROGRESION_FORZADA` si no está
  vacía; si no, la propiedad `kit` del mundo (`mundo.get("kit")`) si existe y
  no está vacía; si no, el nombre del nivel. En el kit de pruebas, `Bosque3D`
  no quita ni bloquea nada del repertorio (el desbloqueo del agua y la
  tienda siguen funcionando, pero ya está todo abierto). Enchufar también la
  costra (`CostraHielo3D` en los goblins presos y en `Flotador3D.congelar()`)
  y `render.hielo_desde(punto)` antes de `helar`.
  *Hecho 12/10 (Juego): `progresion_de(mundo)`, `PROGRESIONES["pruebas"]`, costra en goblins y troncos, `hielo_desde`. Prueba sin ventana: `herramientas/prueba_kit.gd` (36 OK). Nada abierto con ventana.*
- [x] **11.16 (P0, Pipeline) PruebaBosque como laboratorio** *(hecho el 12/10; probado en Godot con ventana virtual en la nube, no en el PC de Pablo; falta la costra en otros casos y el resbalar a mano)*
  (`prueba_test2.gd`, `PruebaBosque.tscn`): `@export var kit: String = ""`
  en la maqueta (lo lee el Lanzador, 11.15); en `PruebaBosque.tscn`,
  `kit = "pruebas"` y `agua_fisica = true`. **Placa de hielo:** con
  `agua_fisica`, `_impacto_en_agua` no pone placa (dibuja `AguaRender3D`);
  sin `agua_fisica`, la placa se quita cuando la casilla deja de estar helada
  (el Juego llama a `_poner_canal(c, 2, 0.0)` al soltarse). Probar en Godot
  con ventana: río, tinaja → canal → tótem de rayo, hielo con el libro que
  crece, avisa y se deshace, y el jugador resbalando.
### Un solo chorro, con caudal calculado (Pablo, 12/10 16:25)

Hoy hay tres chorros que no se hablan: la V del laboratorio (gotas del
Pipeline, **no echa agua**), el hechizo de chorro (echa agua en las casillas
del haz, pero se dibuja con el efecto viejo) y el surtidor (echa 6 u³/s, su
chorro tampoco usa las gotas). Pablo: un solo chorro cuyo **caudal se
calcula**, y en el hechizo **las variables son su X y su Y**.

**El cálculo** (chorro que sale horizontal de la mano o de la boca y cae):
- **X** = distancia horizontal hasta donde cae (en el hechizo: el `largo`
  de su geometría, en u; Tamaño y Flecha lo alargan, como ya hacen).
- **Y** = altura de la salida sobre el suelo donde cae (en el hechizo: la
  mano, ~1 u, más o menos el desnivel del suelo).
- Tiempo de caída `t = √(2·Y / G)`; velocidad de salida `v = X / t`;
  **caudal `Q = π·r²·v`** (u³/s), con `r` = radio del chorro
  (`R_CHORRO`, de partida 0,25 u). Con X = 3 casillas (6,9 u) e Y = 1 u:
  v ≈ 15 u/s y Q ≈ 3 u³/s, lo mismo que echa hoy el haz entre todas sus
  casillas. Un chorro más largo sale más rápido y echa más agua.
- El agua entra en la simulación **donde cae** (`sumar_fuente` en la casilla
  de caída durante lo que dura) y el dibujo usa la misma `v` y la misma
  gravedad, así que **las gotas caen justo donde aparece el agua**.

- [ ] **11.17 (P0, Juego)** `AguaSim3D.calcular_chorro(x, y, r) ->
  {velocidad, tiempo, caudal}` (estática) y la inversa
  `velocidad_para_caudal(q, r)` (para el surtidor, que tiene caudal fijo).
  **Hechizo de chorro de agua:** el agua deja de entrar por las casillas del
  haz y entra en la de caída con el caudal calculado durante `vida`; el daño
  y el mojado del haz no cambian. El dibujo pasa a las gotas del Pipeline
  (`mundo.chorro_agua(...)`, 11.18) cuando existe. **Surtidor:** su agua
  entra por el punto de caída del chorro de la tinaja
  (`Reactivo3D.punto_caida_global`) si cae en el cauce. **Laboratorio:** V
  abre o cierra un chorro de verdad en el ratón (sale a Y sobre el suelo y
  cae a X), con X y Y ajustables (`[` `]` para X de 2 a 10 u, `,` `.` para Y
  de 0,5 a 3 u) y el caudal en pantalla; G sigue siendo solo salpicadura.
  Pruebas headless: Q con X = 6,9 e Y = 1 ≈ 3 u³/s; el volumen que entra en
  la simulación = Q × duración; el agua aparece en la casilla de caída.
- [x] **11.18 (P0, Pipeline)** `AguaMetaballs3D.chorro_fisico(origen,
  dir_horizontal, x, y, r, duracion)`: velocidad de salida de
  `AguaSim3D.calcular_chorro`, gravedad de las gotas = `AguaSim3D.G`, gotas
  por segundo ∝ caudal (`GOTAS_POR_U3`), tamaño de gota ∝ `r`; salpicadura
  al caer. En la maqueta (con `agua_fisica`): crear el `AguaMetaballs3D` del
  nivel y exponer `chorro_agua(origen, dir, x, y, r, dura)` y
  `salpicadura_agua(pos)` para el Juego. **Tinaja:** su chorro con
  `chorro_fisico` (X, Y de la boca al punto de caída) en vez del dibujo de
  ahora.


**Orden:** 11.0 → 11.1 → 11.2 ∥ 11.7 → 11.3 → 11.4 ∥ 11.5 → 11.6 ∥ 11.8 ∥
11.9 ∥ 11.10 → 11.12 → 11.13 ∥ 11.14 → 11.15 ∥ 11.16 → 11.17 ∥ 11.18 →
11.11. Si 11.1 da más de 4 ms por paso, antes de seguir se
mide con 2 × 2 trocitos por casilla.

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
| Fase 9 (nivel Bosque 1) | 9.0–9.4 | 9.8–9.13 | 9.5–9.7 |
| Fase 10 (playtest Bosque: voltereta, cúpula, cámara) | 10.0, 10.1, 10.7 | 10.2–10.4 | 10.5, 10.6 |
| Fase 11 (agua con física) | 11.0, 11.1, 11.11 | 11.1b, 11.2–11.6 | 11.7–11.10 |
| Deuda pequeña | iluminación | stride, pilar/tiempo, diálogo | clips, iconos, VFX, tótems |

Dependencias: 1.1 antes de 2.1 · 1.6 antes de `stride` · 3.6 antes de 3.2 · 3.9 antes de las P2 · 0.2 espera a 1.3.


---

## Fase 12 — Nivel oficial 1: lo que tiene que funcionar antes (Pablo, 13/10 20:50)

**Decisiones de Pablo:** el primer nivel va solo con **Fuego**; glifos **Flecha** desde el principio y **Barrera** poco
después; **Línea** quizá por exploración. **El agua se pospone** hasta después de la primera misión principal (toda la Fase
11 queda como está, sin más tareas hasta entonces). Hace falta: inventario, recolección de componentes con icono 2D,
piezas auxiliares para puzles de fuego, la animación del escudo del goblin ardiendo, un enemigo nuevo (cuadrúpedo, lobo)
y pensar una limitación tipo «tinta».

**Lo que ya hay (medido en el código, 13/10):**
- Inventario: `nucleo/estado.gd` (`Estado.i()`: oro, mochila de 8 huecos ampliable a 20, pilas de 9, `agregar/quitar/cuenta`)
  y `presentacion/ui/bolsa_ui.gd` (tecla I, barra fija abajo, láminas en `presentacion/ui/laminas/`). Se usa en 3D (pociones Q, oro).
- Catálogo de ingredientes: `nucleo/objetos.gd` `DATOS` (lavanda, baya, helecho, piedra, setas, flores, raíces) y `PLANTAS`
  (seta/flor/raíz × elemento → ingrediente: seta + fuego = seta asada, raíz + fuego = raíz carbonizada…). Los iconos hoy se
  **dibujan con primitivas** (`Objetos.dibujar`), no son imágenes 2D.
- Plantas reactivas en el Bosque: piezas `seta_reactiva`, `flor_reactiva`, `raiz_reactiva` (letras `s f q` de la maqueta), como `Reactivo3D`.
- Lo que falta para «recoger»: en el 2D lo hacía `recolectable.gd` (tecla E), que no se portó al 3D. Hoy en 3D una planta
  reacciona al hechizo pero **no entra en la mochila**.

### Juego

- [ ] **12.1 (P0) Recolección en 3D.** `objetos/recolectable_3d.gd`: un `Reactivo3D` que con **E** cerca entra en la mochila
  (`Estado.agregar(id)`), y que si antes recibió un elemento da el ingrediente transformado de `Objetos.PLANTAS` (seta + fuego → seta
  asada). Mensaje flotante «+1 Seta asada» y la pieza desaparece (o se queda «cosechada» si Pablo quiere que rebrote). Letras:
  las `s f q` existentes pasan a ser recolectables; lavanda/baya/helecho/piedra/flor_silvestre necesitan letra y pieza (Pipeline 12.9).
  Prueba headless: recoger sin elemento da la base; con fuego da la asada; mochila llena → aviso y la planta se queda.
- [ ] **12.2 (P0) Iconos 2D en la mochila.** `Objetos.DATOS[id]["icono"]` = ruta a `presentacion/ui/iconos/<id>.png`; `bolsa_ui.gd`
  dibuja la imagen si existe y si no cae a `Objetos.dibujar` (así no se rompe nada mientras el Pipeline entrega iconos).
- [ ] **12.3 (P0) Puzles de fuego como datos: `escenas/puzle.gd`.** Trigger → Condición → Acción (documento de estructura §8):
  un `Puzle` escucha señales de reactivos (`activado`, `quemado`) y aplica acciones (`tender_puente`, `abrir_puerta`,
  `soltar_trampa`, `encender_runa`). Lo que hoy hace `Bosque3D` a mano pasa a ser datos del nivel. Prueba headless con dos
  reactivos falsos.
- [ ] **12.4 (P0) Tronco enraizado → puente.** `objetos/tronco_puente_3d.gd`: `Reactivo3D` con raíces; `on_spell_hit(fuego)` →
  las raíces arden (`enredadera_3d` / `raiz_reactiva`, Pipeline) → a los N s el tronco cae (giro sobre su base) y un
  `PuenteReactivo3D` tiende la losa sobre las casillas que cubre (`largo` del marcador: 2 o 3 casillas, giro = dirección de caída).
- [ ] **12.5 (P1) Cuerdas que arden.** `objetos/cuerda_3d.gd`: `Reactivo3D` que con fuego se quema en `t` s y emite `cortada`.
  Lo que cuelga de ella lo decide el puzle (12.3): una **trampa** (`trampa_3d.gd`: un tronco o roca que cae sobre N casillas y
  daña a quien esté; sirve contra enemigos) o una **compuerta** que se abre. Otras piezas de fuego que propongo, para
  elegir: (a) **antorcha apagada** que hay que encender para abrir una puerta (ya existe como brasero/tótem: solo falta el puzle);
  (b) **seto seco** que arde y deja paso (hoy la telaraña ya lo hace; el seto es lo mismo con otra pieza y propagación
  casilla a casilla, que `Lanzador3D` ya tiene para la hierba); (c) **colmena/avispero** que al quemarse ahuyenta a los goblins
  de una zona (huyen 10 s): es un puzle de combate sin tocar la IA, solo un estado «asustado» en `Combate3D`;
  (d) **barril de resina** que explota y empuja empujables.
- [ ] **12.6 (P0) Escudo del goblin que arde.** `enemigos/combate_3d.gd`: el goblin guerrero lleva `escudo` (pieza de
  `arte/equipo/armas_goblin.glb`); con fuego el escudo pasa a `ardiendo` (bloquea igual 2 s, luego cae) y el goblin pierde la
  reducción de daño frontal. Es la regla «el escudo de madera arde» del documento de estructura §7. Pipeline hace el VFX/animación (12.10).
- [ ] **12.7 (P0) Lobo: lógica.** `enemigos/lobo_3d.gd` reutiliza `Combate3D` (vida, daño, botín, estados) con otra IA:
  rodea al jugador a 3 casillas, embiste en línea recta (1 casilla/0,2 s), retrocede y repite; en manada (2–3) se reparten
  los ángulos. Débil al fuego (huye 3 s si arde). Animaciones que pide: `idle`, `walk`, `run`, `attack`, `hit`, `death`
  (las mismas seis que el goblin). Prueba headless de la IA con un jugador falso.
- [ ] **12.8 (P1) Tinta (limitación de lanzar).** Propuesta para que Pablo decida (ver «Tinta» abajo): `Estado.tinta` (0–100),
  cada **glifo** dibujado cuesta tinta (el sello no), regeneración pasiva lenta, **poción de tinta** crafteable con 2
  ingredientes (seta asada + flor de luna, p. ej.) que da +50. HUD: una barra junto al libro. Sin tinta el libro deja dibujar
  pero no lanzar (aviso). Todo en datos (`nucleo/`) para poder quitarlo si en playtest estorba.

### Pipeline

- [ ] **12.9 (P0) Piezas recolectables** con el estilo del Bosque: lavanda, baya, helecho, piedra, flor silvestre (hay setas, flores y
  raíces). Marcadores/letras en `marcador_3d.gd`.
- [ ] **12.10 (P0) Iconos 2D de inventario** (`presentacion/ui/iconos/<id>.png`, 64×64, fondo transparente) para los ~25 ids
  de `Objetos.DATOS`; primero los 8 que use el nivel 1.
- [ ] **12.11 (P0) Tronco enraizado**: pieza (tronco + raíces, `arte/piezas/tronco_enraizado.tscn`), raíces que arden (VFX) y
  animación de caída (90° sobre la base, 0,8 s, con polvo al caer).
- [ ] **12.12 (P1) Cuerda y trampa**: pieza de cuerda tensa (1 casilla, en vertical u horizontal), que arde de un extremo al
  otro, y la trampa (tronco colgado / roca) que cae.
- [ ] **12.13 (P0) Escudo del goblin ardiendo**: el escudo es un nodo aparte en el modelo (si no, separarlo en `armas_goblin.glb`);
  animación: llamas sobre el escudo 2 s → el goblin lo suelta (clip `drop` o simplemente desprender el nodo con un tween) → el
  escudo cae y se consume (`CostraHielo3D` al revés: una costra de ceniza).
- [ ] **12.14 (P0) Lobo: modelo y animaciones.** Plan de acción, de menos a más riesgo:
  1. **Comprar o descargar un lobo ya animado** y adaptarlo al estilo: el pack *Animated Animals* de **Quaternius** (CC0, low-poly,
     incluye lobo con idle/walk/run/attack/hit/death; `.glb` listo para Godot) es la vía más corta: un día de trabajo (escala,
     paleta pastel, `Pj3D.cargar` y los seis clips). Alternativas de pago en Sketchfab/Synty («Polygon Fantasy Kingdom» trae lobo).
  2. **Meshy con rig animal**: Meshy genera el modelo con el estilo del proyecto, pero su autorrigging está pensado para bípedos;
     para cuadrúpedos sale irregular. Solo si (1) no encaja con el arte: generar en Meshy y **retargetear** las animaciones del
     lobo de Quaternius en Blender (mismo esqueleto de cuadrúpedo: 4 patas, columna, cola, cabeza), que es el trabajo caro.
  3. **Animación procedimental** en Godot (patas por IK, cuerpo que sigue la velocidad): solo como último recurso; tres días y resultado peor.
  Recomendación: (1) ahora para que el Juego tenga algo que mover en 12.7, y decidir después del playtest si merece (2).
  Contrato con el Juego: los mismos nombres de clip que el goblin (`idle, walk, run, attack, hit, death`) y `Pj3D.jugar`.
- [ ] **12.15 (P1) HUD de tinta** (si 12.8 se aprueba): barra junto al libro con la lámina del grimorio.

### Pablo

- [ ] **12.0** Decidir: tronco de 2 o 3 casillas; qué piezas de fuego de 12.5 entran (propongo cuerda+trampa y seto seco); si la
  tinta entra en el nivel 1 o se deja para el 2; y aprobar la vía (1) para el lobo.
- [ ] **12.16** Diseño del nivel 1 en letras (`mundo/datos_nivel/mapas/Nivel1.txt`) con `Bosque.txt` como plantilla, cuando 12.1–12.4 estén.

### Tinta: lo que hay que pensar antes de hacerla

Qué aporta: da valor a los ingredientes (12.1) y a la exploración, y evita que el jugador resuelva todo lanzando sin parar.
Qué arriesga: en un juego de **puzles** una limitación de recursos convierte un fallo de puntería en «no puedo seguir»; si
la regeneración es lenta, el jugador espera; si es rápida, la tinta no significa nada. Propuesta para probar en el laboratorio
antes de decidir: coste solo por **glifo** (el sello gratis: siempre puedes lanzar fuego a secas), regeneración que
rellena de 0 a 100 en 40 s, poción +50, y que **los puzles del nivel 1 se puedan resolver con tinta a cero** (solo con fuego
sin glifos). Así la tinta limita el combate y la comodidad, nunca el avance. Se mide en playtest: cuántas veces el jugador se
queda a cero y qué hace entonces.

**Orden:** 12.0 → 12.1 ∥ 12.9 ∥ 12.10 → 12.2 → 12.3 → 12.4 ∥ 12.11 → 12.6 ∥ 12.13 → 12.7 ∥ 12.14 → 12.5 ∥ 12.12 → 12.8 ∥ 12.15 → 12.16.
Antes de todo: P1–P4 del playtest del 13/10 cerrados.


---

## Fase 13 — Flujo de trabajo: animación, VFX, agua con volumen y pruebas automáticas (Pablo, 15/10)

**Qué pide Pablo:** (1) animar sin depender de que el autorig salga bien; (2) VFX más fáciles de iterar; (3) **agua con
volumen, y resolver la sensación de que «funciona a medias»**: hoy flecha + agua sobre la tinaja activa la animación y el
chorro de gotas, pero en el canal **no se ve un volumen de agua fluyendo** (captura 15/10 08:44: gotas sí, canal seco a la
vista); (4) automatizar pruebas porque el playtest es lento. Los escenarios de juego (13.10) van **antes** del nivel 1 (Fase 12):
son los que ahorran playtests durante todo el nivel.

### Animación (Pipeline)

- [ ] **13.1 (P0) Dos esqueletos estándar y dos bibliotecas de clips.** Bípedo = el rig de Mixamo (el que ya llevan elfa,
  goblins y NPC); cuadrúpedo = el del lobo de Quaternius. `arte/animaciones/bipedo.glb` y `cuadrupedo.glb` con `idle, walk,
  run, attack, hit, death, talk` (lo que haya). Un modelo nuevo sale de Meshy **sin rig** y se pesa en Blender sobre el
  esqueleto de su familia (`Parent → Automatic Weights` + retoque): una hora, determinista. Las animaciones no se repiten
  por personaje: se heredan. Fuentes de clips: Mixamo (bípedos, gratis), Quaternius (lobo), Cascadeur para los que falten.
- [ ] **13.2 (P0) `Pj3D` carga los clips de la biblioteca de su familia** (`AnimationLibrary` compartida) cuando el modelo
  no los trae; el modelo propio manda si los trae. Contrato con el Juego: los mismos nombres de clip de hoy.
- [ ] **13.3 (P1) `herramientas/prueba_animaciones.gd`** (Juego escribe, Pipeline mantiene la lista): recorre `arte/modelos/*.glb`
  y comprueba esqueleto estándar, los seis clips (propios o de biblioteca), sin deriva de cadera, escala ≈ 1,7. Falla antes de verlo en pantalla.
- [ ] **13.4 (P1) Migrar los personajes actuales** a 13.1 (elfa, goblins, librera, alquimista, guardabosques, gato, grandmaster, elemental).

### VFX (Pipeline)

- [ ] **13.5 (P1) Hojas de sprites horneadas** para fuego, humo y vapor (Blender → 8×8 fotogramas, como `llama_tira8`), dibujadas como
  billboard animado en vez de partículas sueltas: más baratas (el Bosque va a 8 fps en un equipo) y más fieles al estilo pintado.
- [ ] **13.6 (P1) Un VFX = un recurso `.tres`** (textura, color, tamaño, duración, sonido) en `presentacion/vfx_elementos/`, que
  `Vfx3D` instancia; el Pipeline lo ajusta en el inspector sin código. Es la partición de `vfx_3d.gd` (111 KB) por elemento, ya apuntada.
- [ ] **13.7 (P1) `LabVfx3D` con escenarios fijos y captura**: lista de escenarios (bola, barrera, chorro, hielo, vapor…) con cámara
  fija que se reproducen en orden y guardan una captura cada uno (`capturas/vfx_<n>.png`). Antes/después en dos imágenes.

### Agua con volumen (Juego la simulación y la medida; Pipeline el dibujo) — **importante para Pablo**

Diagnóstico de la captura del 15/10: la simulación **sí** mete agua en el canal (1,5 u³/s de la tinaja; medido 0,48 / 0,35 /
0,18 u de hondo a los 35 s), pero el dibujo no lo muestra como volumen: `AguaRender3D` pinta solo la **superficie**, las
paredes de piedra de la pieza del canal quedan por encima, y una lámina de 0,2–0,5 u vista a 60° es una línea. El chorro de
gotas (11.18) llega, pero no hay continuidad visual entre las gotas y el agua del canal. Y lo que Pablo llama «bugs»: hay que
**medirlos uno a uno con escenarios (13.10)** antes de tocar nada, porque hoy no se distingue si el agua no está o no se ve.

- [ ] **13.8 (P0, Juego) Escenario `escenario_agua_tinaja.gd`** (headless, Bosque real): flecha de agua sobre la tinaja → a los 5 s el
  canal tiene ≥ 0,25 u en las tres casillas, el río sube, y **se vuelca al diario la profundidad por casilla cada segundo**: es la
  verdad contra la que se compara el dibujo. Idem `escenario_agua_estanque.gd` (hechizo de agua en hierba: charco, mojado, se seca).
- [ ] **13.9 (P0, Pipeline) El agua ocupa espacio.** `AguaRender3D`: (a) **paredes laterales** de la malla donde el agua toca
  tierra o pared (hoy solo superficie): se ve el grosor; (b) **opacidad y color por profundidad** (0,1 u casi transparente, 0,9 u
  azul del río) para que la lámina del canal se lea como agua y el río como masa; (c) en el canal, la malla **dentro** del hueco
  de la pieza (la superficie a `fondo + lámina`, nunca tapada por la piedra: ajustar la pieza o un `render_priority`); (d) **menisco /
  espuma** en el borde (el flow map ya está); (e) las gotas del chorro al caer hacen **ondas** (`AguaOndas3D.impulso`) y una
  salpicadura en el punto de caída. Medida: capturas de 13.7 en el canal y el estanque con los valores de 13.8 al lado.
- [ ] **13.11 (P1, Juego) Rendimiento**: `sub` 3 → 2 en niveles grandes (4× menos trabajo por paso; invisible a 60°), y que
  `textura()` solo recorra la caja de trabajo. Medido con `prueba_agua_sim` (< 4 ms por paso en 19×49).
- [ ] **13.12 (P1, Juego+Pipeline)** Tras 13.8/13.9: lista de «bugs» del agua de Pablo, uno por escenario, cerrados con su prueba.

### Pruebas automáticas (Juego)

- [ ] **13.10 (P0) Escenarios de juego sin ventana.** `herramientas/escenario_*.gd`: cargan `escenas/PruebaBosque.tscn` en
  headless, avanzan N fotogramas, lanzan hechizos por código (`Lanzador3D.lanzar_ahora`) y mueven al jugador con entradas
  sintéticas (`Input.parse_input_event`), y afirman estado del mundo. Primeros cinco = la lista de playtest del 13/10: libro
  (dibujar y lanzar), hielo que atrapa y suelta, fuego en la telaraña abre paso, tinaja llena el canal, hornear y recargar.
  Entran en `tools\pruebas.cmd`.
- [ ] **13.13 (P1) Grabar y repetir playtests.** `playlog_3d.gd` registra también las **entradas** (tecla, fotograma); un playtest
  de Pablo se vuelve a ejecutar solo y se comprueba que los eventos salen iguales. Lo que ya juega bien queda protegido.
- [ ] **13.14 (P1) Capturas de referencia** con ventana en el PC de Pablo (`tools\pruebas.cmd` sin `--headless`): una captura por
  escenario comparada con la anterior con tolerancia (`tools/comparar_capturas.py`). Avisa cuando el agua, el hielo o un VFX cambian de aspecto.
- [ ] **13.15 (P1, Pablo + Juego) CI**: GitHub Actions con Godot headless ejecutando las pruebas y los escenarios en cada push.

**Orden:** 13.8 ∥ 13.10 (primero: son la medida de todo lo demás) → 13.9 → 13.1 ∥ 13.6 → 13.2 → 13.3 ∥ 13.7 → 13.4 ∥ 13.5 →
13.11 ∥ 13.13 → 13.12 → 13.14 → 13.15. **Respecto a la Fase 12:** 13.8 y 13.10 van antes de 12.1; 13.1–13.2 antes de 12.14 (el lobo
nace ya sobre el esqueleto estándar); el resto en paralelo con el nivel 1. El agua sigue sin entrar en el nivel 1 como mecánica;
13.8–13.9 son para que lo que ya existe se vea bien y deje de dar sensación de «a medias».

---

## Fase 14 — Presentación, HUD, escritura de runas, animación y laboratorio de fuego (16/10)

Vive en su propio documento: `docs/FASE14_PRESENTACION.md` (tareas con prompt por responsable). Se apunta aquí para que la numeración de fases no salte.

---

## Fase 15 — Lo aprendido de *Echoes of Wisdom* (21/10)

Detalle de cada tarea (qué, por qué, archivos, comprobación y prompt): `docs/PLAN_EOW.md`; síntesis del estudio: `docs/ANALISIS_EOW.md`. Regla: de EoW no entra nada en el repo (ni datos, ni textos, ni assets), solo las ideas. Lo hizo el Juego el 21/10 (diario 236, 238 y 240–242); todo probado sin ventana y jugado por Pablo en `laboratorios/LabPlaytestEoW.tscn`.

### Juego

- [x] **A1** papeles en `Reactivo3D` (inflamable, propaga_llama, apaga, mojable…) en vez de `match tipo` (diario 236).
- [x] **B1** el estado del suelo tiene un solo dueño: `EstadosSuelo3D` con intensidad, caducidad, transiciones en tabla y `textura()` (diario 238). Desde el 21/10 el juego lo escribe de verdad al impactar (`ReaccionesSuelo3D`, escarcha frente a hielo físico; diario 242).
- [x] **C1** flags con nombre `nivel.sala.hecho` (`nucleo/flags.gd`) y en `Puzle3D` (diario 238).
- [x] **D1** `Terreno3D.ocupado` / `cabe` (diario 238).
- [x] **A2** el fuego pasa solo por contacto; flecha ardiendo (diario 238). Decisión de Pablo tras el playtest: sin contagio entre enemigos (diario 239).
- [x] **A3** siete reacciones por enemigo y hundirse al ser empujado al agua honda, con el clip «Drowning» (diario 238, 240).
- [x] **C2** `si=` con `+` `|` `!`, `casilla(x,y).estado` y plantilla `$` (diario 238).
- [x] **C3** piezas `vigia`, `cerrojo` y `cofre` (diario 238).
- [x] **A4** `Mundo3D.reaccion` con el catálogo de `ReaccionesVfx3D` (diario 238).
- [x] **A5** `Escudo3D` (cono frontal de 120°); al consumirse le quema la mano al goblin (diario 238, 239).
- [x] **D2** `Caminos3D`, rutas por casillas con altura (diario 238).
- [x] **E1** tinta: máximo cerrado y pigmentos (decisión de Pablo del 21/10: tope 300, reparto 60/40 jefes/secretos; el pigmento es un aumento temporal sobre un sello: abarata su tinta o sube su daño) (diario 243).

### Pipeline (encargos del Juego por el diario)

- [ ] **B2** el shader del suelo lee `Mundo3D.textura_estados()` y se retira `_img_estado`.
- [x] **PL1** clip «Drowning» de los goblins (diario 231).
- [x] **PL2** tabla reacción → efecto + sonido (`ReaccionesVfx3D`, diario 234). Falta engancharla en la maqueta para todos los niveles (el laboratorio lo hace por su cuenta).
- [x] **F1–F3** luz por zona, tilt-shift y sonda de reflejos (diario 233). · [x] **F4** presupuesto medido (`arte/meshy/PRESUPUESTO.md`, diario 232; decimar lo decide Pablo).

### Pablo

- [ ] Decidir qué ayudas del laboratorio pasan al juego (lista en `docs/PENDIENTES.md` y diario 240).
- [ ] Ajustar los números de la tinta y de los pigmentos tras jugarlos.