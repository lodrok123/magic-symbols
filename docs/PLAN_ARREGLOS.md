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

- [ ] **5.1 (P0) El origen es siempre el jugador.** Se retira el "origen en el
  punto del ratón" de §0b: el ratón da solo la **dirección**; el alcance de 3
  casillas es distancia de viaje. Nada nace lejos salvo que un glifo lo diga
  (levitación: queda estático donde termina la trayectoria). Motivo: lanzar
  en un punto trivializa el puzle. `Lanzador3D`: `origen = jugador` siempre;
  `alcance` solo limita `travels`.
- [ ] **5.2 (P0) Tiempo del libro.** Abrir el libro ya no pausa: `TIEMPO_LIBRO`
  (0,3). Modo lanzar: `TIEMPO_LANZAR` (0,3). Los enemigos siguen moviéndose
  (lento): es el castigo al que abre el libro sin haberse preparado. El HUD
  tiene que enseñar que el tiempo corre (los goblins se mueven, basta).
- [ ] **5.3 (P0) Altura: un nivel.** `MAX_NIVELES_SUBIBLES = 1`, la tierra se
  apila hasta 1, la columna de barrera + levitación es de 1 nivel. Los
  números de §0b (dos niveles) quedan para después.
- [ ] **5.4 (P0) Semántica de glifos v2** (tabla de §3). Cada glifo aporta un
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
- [ ] **5.8 (P0) Contrato VFX v2 para el Pipeline.** Publicar en el diario la
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

**Estado del Juego a 6/10 21:10** (revisado contra `lanzador_3d.gd` y
`jugador_3d.gd` en disco y el diario): fase 4 cerrada por su parte (4.1–4.5,
diario 03:00; marcadas arriba). De la fase 5: **5.1 a medias** (flecha y
barrera ya nacen en el jugador, 19:15; falta quitar el origen por ratón y el
aro `ALCANCE_ORIGEN`, y que el alcance solo limite el viaje); **5.2 sin
hacer** (sigue `RALENTIZADO = 0.7` y el libro con `PROCESS_MODE_ALWAYS`
sobre la pausa; faltan `TIEMPO_LIBRO`/`TIEMPO_LANZAR` = 0,3); **5.3 sin
hacer** (`MAX_NIVELES_SUBIBLES = 2`, tierra hasta 8 bloques); **5.4 y 5.8
sin empezar**. Nada le bloquea para 5.1–5.3 y 5.8. Para **5.4** necesita
tres cosas que no son suyas: (a) **plantilla del gesto `linea`** en
`gesture_library.tres` (Pablo la graba en el entrenador; es un archivo de
Pablo); (b) **icono `assets/ui/glyphs/linea.png`** (Pipeline, mismo estilo
que `pulso.png`); (c) que `Vfx3D.lanzar_forma` acepte `chorro`, `onda` y
`acompanante` sin romper aunque el VFX aún no exista (Pipeline, 5.10: con
un sustituto vale). Hasta (a) puede programar `linea` y probarla con el
atajo de teclado del libro.

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
| Deuda pequeña | iluminación | stride, pilar/tiempo, diálogo | clips, iconos, VFX, tótems |

Dependencias: 1.1 antes de 2.1 · 1.6 antes de `stride` · 3.6 antes de 3.2 · 3.9 antes de las P2 · 0.2 espera a 1.3.
