# Plan de acción · lo aprendido de *Echoes of Wisdom*

21/10/2026 · contexto JUEGO (chat de análisis). **Integrado en `docs/PLAN_ARREGLOS.md` como Fase 15** (21/10), con el estado de cada tarea; este documento queda como el detalle (qué, por qué, archivos, comprobación y prompt). **E1 cambió por decisión de Pablo** (21/10): tope de tinta 300 con reparto 60/40 jefes/secretos, y el pigmento es un aumento temporal sobre un sello (abarata su tinta o sube su daño), no una rebaja permanente por grupo de formas.
Lo ejecuta **otro chat del contexto Juego**, tarea a tarea. Las tareas del Pipeline las pide el Juego por el diario; no las hace el Juego.

Fuentes: `docs/ANALISIS_EOW.md` (síntesis) y sus anexos `EOW_1…4`. Diagnóstico del código leído del disco el 21/10 (rutas abajo).

**Regla que no cambia:** de EoW no entra nada en el repo (ni datos, ni textos, ni assets, ni shaders). Solo las ideas, con nuestras palabras y nuestros números.

---

## 0. Decisiones de Pablo ya tomadas (21/10)

- **Fuego desde enemigos y objetos:** solo se propaga entre algo **inflamable** y algo que **está ardiendo y le toca** (contacto, no radio de calor).
- **Caer al agua:** entra. De momento el enemigo **se hunde** y desaparece. Se busca una animación de «ahogarse» (encargo al Pipeline) para sustituirlo.
- **Responsable:** el Juego. Los pasos que tocan archivos del Pipeline salen como encargo por el diario.

## 1. Lo que ya hay (no rehacer)

| Lección de EoW | Ya existe en el proyecto | Archivo |
|---|---|---|
| El mundo recibe acciones, no hechizos | `AccionElemental` + `Mundo3D.aplicar` (M3, parcial: solo agua) | `mundo/accion_elemental.gd`, `mundo/mundo_3d.gd` |
| Los números del golpe en datos | HC3: daño, quema, congela, aturde… salen del `.tres` de cada runa | `nucleo/hechizo.gd`, `nucleo/*_rune.tres`, `enemigos/combate_3d.gd` |
| Estado por casilla como dato | `EstadosSuelo3D` (helada, electrificada, quemada, mojada, segada) + señal | `mundo/estados_suelo_3d.gd` |
| Estado por casilla en el shader | `_img_estado` 40×40 RGBA8 (R quemado · G mojado · B helado · A pisado) **en la maqueta** | `presentacion/prueba_test2.gd` (Pipeline) |
| Puzles sin código por sala | `Puzle3D`: piezas, `cuando`/`si`/`hace`, contador de encendidas | `escenas/puzle.gd` |
| Misiones como datos | `Misiones` con guardado JSON | `nucleo/misiones.gd` |
| Coste que no depende del elemento | `Tinta`: coste por FORMA | `nucleo/tinta.gd` |
| Fundido de lo que tapa | `Ocluso3D`: descarte con trama | `presentacion/ocluso_3d.gd` (Pipeline) |
| Hierba instanciada | `Hierba3D`: MultiMesh por bloques, se aparta de la chibi | `presentacion/hierba_3d.gd` (Pipeline) |

**Lo que falta, por bloques:**
- A · Reacciones.
  - El receptor decide por `tipo` (`COMBUSTIBLES.has(tipo)`, `match tipo`), no por propiedades.
  - Solo emiten los hechizos y los combustibles entre sí.
  - Los enemigos no caen al agua.
  - No hay catálogo de señales de reacción.
- B · Estado del suelo. El dato (`EstadosSuelo3D`) y su imagen (`_img_estado`) viven en dos sitios, con caducidades distintas.
- C · Puzles.
  - No hay flags con nombre persistentes.
  - `si=` admite una sola condición.
  - No se puede preguntar por el estado de una casilla.
  - No hay «todos muertos» ni cerrojo de sala.
- D · Rejilla. No hay una consulta única de ocupación por casilla y altura. Los enemigos no buscan camino sobre casillas.
- E · Coste. Falta la rebaja por progresión y un total de mejoras cerrado.
- F · Look. Luz por zona, tilt-shift, probes y presupuestos de Meshy (Pipeline).

---

## 2. Secuencia

Cuatro rondas. Dentro de una ronda las tareas no comparten archivos, así que se pueden hacer en cualquier orden. Cada tarea acaba con una prueba sin ventana en **FALLOS 0** (`tools\prueba_una.cmd`) y con una entrada en `docs/DIARIO.md` si toca un contrato.

| Ronda | Tareas | Depende de |
|---|---|---|
| 1 | **A1** papeles · **B1** estado del suelo con dueño · **C1** flags · **D1** medir ocupación | — |
| 2 | **A2** fuego por contacto · **A3** contrato de enemigo + hundirse · **C2** condiciones compuestas · **C3** piezas lógicas · *(Pipeline: B2, PL1)* | A1 · C1 · B1 |
| 3 | **A4** señales de reacción · **A5** escudo como componente · **D2** caminos sobre casillas | A1–A3 · D1 |
| 4 | **E1** rebaja y total de tinta (tras decisión) · *(Pipeline: F1–F4)* | Pablo |

---

## 3. Tareas

Formato de cada una: qué, por qué (de EoW), archivos (todos del Juego según `PROPIETARIOS.md` salvo que se diga), cómo se comprueba y prompt para el chat que la ejecuta.

### A1 · Papeles explícitos en los objetos reactivos (P0)

- **Qué.** `Reactivo3D` deja de decidir por `tipo` y decide por **papeles**: `inflamable`, `propaga_llama`, `apaga`, `conduce`, `congelable`, `mojable`, `pesado`.
  - Una tabla `PAPELES_POR_TIPO` da los de cada tipo y `@export var papeles` permite añadir o quitar por pieza (las variantes como diferencia de papeles).
  - `on_spell_hit`, `spell_reacts`, `can_burn` y `_contagiar` preguntan por papeles. `COMBUSTIBLES` queda solo para los números (segundos ardiendo, escala).
  - Corregir la cabecera «Dueño: Pipeline», que está desfasada: `objetos/` es del Juego (`PROPIETARIOS.md` §1).
- **Por qué.** En EoW ningún objeto «es de fuego»: tiene papeles sueltos (148 actores emiten calor, 136 pueden arder, 58 propagan…), y las variantes son sumar o quitar papeles. Es lo pendiente de M3 en `ARQUITECTURA_MODULAR.md` (`Reactivo3D.propiedades`).
- **Archivos.** `objetos/objetos_3d.gd`.
- **Comprobación.**
  - **Sin cambio de comportamiento.** `escenario_puzles_fuego` y `escenario_puzles_agua` dan exactamente lo mismo que antes; se guarda la salida de antes y se compara.
  - Prueba nueva `herramientas/prueba_papeles.gd`: cada tipo tiene sus papeles; un seto con `-inflamable` no prende; una telaraña con `+mojable` se moja.
- **Prompt.**
```
Tarea A1 de docs/PLAN_EOW.md (Juego). Lee PROPIETARIOS.md, las últimas entradas del DIARIO y objetos/objetos_3d.gd entero.
Sustituye las decisiones por `tipo` (COMBUSTIBLES.has(tipo), match tipo en on_spell_hit/spell_reacts/can_burn/_contagiar) por
PAPELES: tabla PAPELES_POR_TIPO (inflamable, propaga_llama, apaga, conduce, congelable, mojable, pesado) + @export var papeles con
+añadir/-quitar por pieza. COMBUSTIBLES solo guarda números. El comportamiento NO cambia: ejecuta antes y después los escenarios de
puzles de fuego y agua y compara la salida. Prueba nueva herramientas/prueba_papeles.gd. Corrige la cabecera «Dueño: Pipeline»
(objetos/ es del Juego). Cambios parciales, comentarios en español con el porqué. Diario: nombres de los papeles (contrato).
```

### B1 · El estado del suelo tiene un solo dueño (P0)

- **Qué.** `EstadosSuelo3D` guarda también **intensidad y caducidad** (cuánto dura el quemado y el mojado; hoy las lleva la imagen de la maqueta) y ofrece `textura() -> ImageTexture`, con un píxel por casilla y los mismos canales que `_img_estado` (R quemado · G mojado · B helado · A pisado/segada). Se actualiza solo cuando algo cambia.
  - Las reglas de paso entre estados (mojado + frío → helado; calor sobre helado → mojado) se escriben como **tabla**, no como `if`.
- **Por qué.** EoW resuelve el estado en el shader. Nosotros ya lo hacemos, pero el hecho y la imagen viven en dos sitios. Con un solo dueño, la hierba, los VFX y las condiciones de puzle (C2) leen lo mismo. Es el criterio 6 de §0 de `DISENO_FUTURO.md`.
- **Archivos.** `mundo/estados_suelo_3d.gd`, `mundo/mundo_3d.gd` (exponer la textura).
- **Comprobación.** `herramientas/prueba_estados_suelo.gd`:
  - poner, caducar y combinar estados;
  - la textura tiene el píxel correcto en la casilla correcta;
  - sin señales repetidas.
- **Prompt.**
```
Tarea B1 de docs/PLAN_EOW.md (Juego). Lee mundo/estados_suelo_3d.gd, mundo/mundo_3d.gd y, solo para leer, la parte de
presentacion/prueba_test2.gd que usa _img_estado y marcar_estado (es del Pipeline: no la toques). Haz que EstadosSuelo3D sea
dueño de intensidad y caducidad por casilla y exponga textura() (1 píxel por casilla, mismos canales que _img_estado) que solo
se actualiza al cambiar algo. Las transiciones entre estados en una TABLA. Prueba herramientas/prueba_estados_suelo.gd.
Diario: encargo B2 al Pipeline (que el shader del suelo lea Mundo3D.estados.textura() y retire _img_estado) con la firma exacta.
```

### C1 · Flags con nombre (P0)

- **Qué.** `nucleo/flags.gd` (`Flags`, RefCounted como `Misiones`):
  - `poner(nombre, valor=true)`, `tiene(nombre)` y la señal `flag_cambio(nombre, valor)`;
  - guardar y cargar en JSON junto a las misiones;
  - nombres `<nivel>.<sala>.<hecho>` (por ejemplo `bosque1.s3.placa_norte`).

  Solo es persistente lo que el juego debe recordar (cofre abierto, sala resuelta, puerta abierta para siempre). Lo de dentro de una sala sigue en las piezas de `Puzle3D`.
  - En `Puzle3D`: la acción `flag.poner(<nombre>)`, la señal `cuando=flag.<nombre>` y la condición `si=flag.<nombre>`.
- **Por qué.** EoW tiene 1.624 flags globales con el nombre de la sala y del hecho (una mazmorra grande usa ~40). Un interruptor escribe la flag y la leen dos puertas, una valla y un cerrojo, sin enlaces directos entre ellos.
- **Archivos.** `nucleo/flags.gd` (nuevo), `escenas/puzle.gd`.
- **Comprobación.** `herramientas/prueba_flags.gd`: poner, leer, señal, guardar y cargar, y un puzle de dos piezas enlazadas solo por una flag.
- **Prompt.**
```
Tarea C1 de docs/PLAN_EOW.md (Juego). Lee nucleo/misiones.gd (modelo de API y guardado) y la cabecera de escenas/puzle.gd
(gramática). Crea nucleo/flags.gd (Flags: poner/tiene/flag_cambio, JSON junto a las misiones, nombres nivel.sala.hecho) y añade
a Puzle3D: acción flag.poner(nombre), señal cuando=flag.<nombre>, condición si=flag.<nombre>. Documenta la gramática en la
cabecera. Prueba herramientas/prueba_flags.gd. Diario: el contrato de nombres de flag.
```

### D1 · Medir la ocupación por casilla (P1)

- **Qué.** Antes de escribir nada, **medir** qué ofrece ya `Terreno3D`: bloqueos, alturas y sólidos horneados (`FuenteNodos`, diario 230). Hay que ver qué falta para responder «¿cabe una forma de N casillas y M alturas aquí?», que preguntan el rasterizado de glifos (Fase 8), el bloque de tierra y el camino de los enemigos.
  - Si falta, una sola función `Terreno3D.cabe(celdas, nivel_desde, alto) -> bool` y `ocupado(c, nivel)`.
- **Por qué.** EoW guarda por sala un mapa 3D de ocupación aparte del dibujo, para no lanzar rayos en cada consulta.
- **Archivos.** `mundo/terreno_3d.gd`.
- **Comprobación.** Informe en el diario con lo medido. Si se añade la función, `herramientas/prueba_ocupacion.gd`.
- **Prompt.**
```
Tarea D1 de docs/PLAN_EOW.md (Juego). Lee mundo/terreno_3d.gd y el diario 227–230. MIDE primero (no supongas): qué consultas
de bloqueo/altura/sólido existen y quién las usa (lanzador_3d, combate_3d, earth builder). Si no hay una consulta única
«¿cabe esta forma aquí?», añade Terreno3D.cabe(celdas, nivel_desde, alto) y ocupado(c, nivel) reutilizando lo que hay.
Prueba herramientas/prueba_ocupacion.gd. Diario con lo medido.
```

### A2 · El fuego pasa por contacto, también desde y hacia enemigos (P1)

- **Qué.** **Regla de Pablo: solo se prende lo `inflamable` que toca algo que está ardiendo.**
  - Algo que arde (objeto con papel `ardiendo`, enemigo con quemadura activa, flecha ardiendo) prende lo `inflamable` que **toca**: cuerpos solapados, o casilla vecina para las piezas de rejilla.
  - El contagio actual de 1,7 casillas entre combustibles se queda como «vecino»; se documenta como contacto en la rejilla.
  - Los goblins son `inflamable`, y su quemadura enciende papeles que tocan (un goblin ardiendo que choca con un seto lo prende).
  - Las **flechas del arquero** son `inflamable`: al cruzar un brasero o una fogata encendidos salen ardiendo y su impacto aplica quema.
  - Mojado bloquea, como ahora (`mojable`, `T_MOJADO`).
- **Por qué.** En EoW «emite calor», «propaga llama» y «se puede prender» son papeles independientes, y por eso la flecha + hoguera sale sola, sin regla escrita.
- **Archivos.** `objetos/objetos_3d.gd`, `enemigos/combate_3d.gd` (flecha y quemadura).
- **Comprobación.** `herramientas/prueba_contacto_fuego.gd`:
  1. Un goblin ardiendo que toca un seto lo prende; uno que pasa a 2 casillas, no.
  2. Una flecha que atraviesa un brasero encendido llega ardiendo.
  3. Un seto mojado no prende.
  4. Los escenarios de fuego siguen en FALLOS 0.
- **Prompt.**
```
Tarea A2 de docs/PLAN_EOW.md (Juego). Requiere A1. Regla de Pablo (21/10): el fuego solo pasa de algo ARDIENDO a algo
INFLAMABLE que lo TOCA (sin radio de calor). Implementa: goblin con quemadura activa = ardiendo; goblin = inflamable; la flecha del
arquero (Combate3D._soltar_flecha) es inflamable y sale ardiendo si cruza un brasero/fogata encendidos o algo ardiendo; el contagio
actual entre combustibles queda como «vecino de rejilla». Mojado sigue bloqueando. Prueba herramientas/prueba_contacto_fuego.gd
con los cuatro casos del plan. Mide antes cuántas veces arde la escena del Bosque en 60 s para detectar incendios en cadena.
```

### A3 · Contrato mínimo de reacciones de enemigo + hundirse (P1)

- **Qué.** Todo enemigo (`Combate3D`) responde a: quemado, mojado, congelado, electrocutado, empujado, aturdido y **cae al agua**.
  - Cae al agua: si después de un empuje o al moverse su casilla es agua profunda (`Terreno3D` o `AguaSim3D`) y no está helada, **se hunde** (baja, burbujas por `Mundo3D.impacto`), muere sin botín de golpe y avisa.
  - El hielo de la casilla sigue sosteniendo a quien está encima.
  - Una función `reacciones_soportadas()` que la prueba recorre por cada tipo de enemigo.
- **Por qué.** En EoW los nueve enemigos medidos tienen el mismo paquete de reacciones. Empujar al agua pasa a ser una jugada (el viento y la tierra ganan un uso exclusivo: «solapes de elementos» en `CONTEXTO.md`).
- **Archivos.** `enemigos/combate_3d.gd`.
- **Encargo PL1 (Pipeline, por el diario).** Buscar o generar una animación de «ahogarse» para el goblin. Mientras no la haya, el Juego usa el hundimiento.
- **Comprobación.** `herramientas/prueba_contrato_enemigo.gd`:
  - cada tipo responde a las siete reacciones;
  - un goblin empujado por viento a una charca honda se hunde;
  - sobre hielo, no.
- **Prompt.**
```
Tarea A3 de docs/PLAN_EOW.md (Juego). Lee enemigos/combate_3d.gd (golpe, push, _efectos, _ia, _mover_paso) y las consultas de
agua de Terreno3D/AguaSim3D. Añade «cae al agua»: si su casilla es agua honda y no helada (tras empuje o paso), se hunde (baja,
avisa Mundo3D.impacto para burbujas), muere sin botín de golpe. Añade reacciones_soportadas() y comprueba que todos los tipos
cumplen las siete del plan. Prueba herramientas/prueba_contrato_enemigo.gd. Diario: encargo PL1 (animación de ahogarse del
goblin) y el nombre del aviso de hundimiento para su VFX.
```

### C2 · Condiciones compuestas y estado de casilla en `Puzle3D` (P1)

- **Qué.** `si=` admite varias condiciones: `si=a.abierta+b.encendido` (Y), `si=a.abierta|b.encendido` (O) y `!` delante para negar. Condiciones nuevas:
  - `casilla(x,y).mojada|helada|quemada|electrificada|agua`, que lee `EstadosSuelo3D` (B1) y el agua;
  - `flag.<nombre>` (C1).

  Plantilla opcional: `$1` en una regla toma el valor de una clave de la pieza que emite la señal, para no escribir una regla por puerta.
- **Por qué.** EoW tiene 479 condiciones con nombre, combinadas con Y/O/negación, y 132 son plantillas que leen los parámetros del objeto colocado.
- **Archivos.** `escenas/puzle.gd`.
- **Comprobación.** `herramientas/prueba_puzle_condiciones.gd`, con una sala «abre si las tres casillas están mojadas y el brasero apagado». Los escenarios de agua y fuego siguen en FALLOS 0.
- **Prompt.**
```
Tarea C2 de docs/PLAN_EOW.md (Juego). Requiere B1 y C1. Amplía la gramática de escenas/puzle.gd: si= con «+» (y), «|» (o) y
«!» (no); condición casilla(x,y).<estado> (EstadosSuelo3D y agua); condición flag.<nombre>; plantilla $n opcional. Mantén
compatible todo lo que ya se escribe. Documenta en la cabecera. Prueba herramientas/prueba_puzle_condiciones.gd + escenarios.
```

### C3 · Piezas lógicas: «todos derrotados», cerrojo de sala y cofre por flag (P1)

- **Qué.** Piezas nuevas de `Puzle3D`:
  - `vigia de=<lista de enemigos o zona>`: señal `todos_derrotados`, que también puede poner una flag;
  - `cerrojo celdas=<lista>`: cierra las puertas de la sala al entrar y las abre con una condición;
  - `cofre aparece_si=<cond> abierto=<flag>`: la lógica es del Juego; la presentación (`presentacion/cofre_3d.gd`) es del Pipeline y solo se le pide el estado.
- **Por qué.** EoW monta casi todos sus puzles con un puñado de objetos lógicos invisibles. L_Dungeon001 tiene 92 frente a 14 enemigos. «Sala que se cierra hasta derrotar a todos» = vigía → flag → cerrojo, sin código de sala.
- **Archivos.** `escenas/puzle.gd`, y `objetos/` si hace falta un nodo.
- **Comprobación.** `herramientas/prueba_sala_cerrada.gd`: se entra, se cierra, se derrota a 3 goblins, se abre y aparece el cofre; al recargar, el cofre sigue abierto (flag).
- **Prompt.**
```
Tarea C3 de docs/PLAN_EOW.md (Juego). Requiere C1 (C2 recomendable). Añade a Puzle3D las piezas vigia (todos_derrotados),
cerrojo (cierra al entrar, abre con condición) y cofre (aparece_si, abierto=flag); para el cofre usa la API de estados de
presentacion/cofre_3d.gd sin tocarlo (es del Pipeline; si falta algo, pídelo por el diario). Prueba
herramientas/prueba_sala_cerrada.gd con recarga de partida.
```

### A4 · Señales de reacción con nombre (P2)

- **Qué.**
  - La lógica avisa de lo que pasa con un nombre de un catálogo cerrado: `prendido`, `apagado_agua`, `apagado_viento`, `consumido`, `mojado`, `secado`, `congelado`, `derretido`, `electrocutado`, `hundido`, `aturdido`, `empujado`. Usa `Mundo3D.reaccion(nombre, punto, nodo)`, una señal nueva junto a `impacto`.
  - El Juego **no** decide qué partículas ni qué sonido salen.
  - El Pipeline mantiene la tabla `reacción → efecto + sonido`, con una plantilla común y excepciones por pieza, reutilizando `VfxPuzle3D` y `Sfx`.
- **Por qué.** En EoW la lógica emite una señal y una tabla aparte (presente en 441 de 450 actores) decide cómo se ve y suena, con 62 señales comunes. Al Pipeline le da un catálogo cerrado que producir.
- **Archivos.** `mundo/mundo_3d.gd`, `objetos/objetos_3d.gd`, `enemigos/combate_3d.gd`. **Encargo PL2 (Pipeline):** la tabla.
- **Comprobación.** `herramientas/prueba_reacciones.gd`: cada reacción de A1–A3 emite su nombre una vez.
- **Prompt.**
```
Tarea A4 de docs/PLAN_EOW.md (Juego). Requiere A1–A3. Añade Mundo3D.reaccion(nombre, punto, nodo) con el catálogo cerrado del
plan (constante con los nombres) y emítela desde Reactivo3D y Combate3D en cada cambio. No dibujes ni suenes nada nuevo. Prueba
herramientas/prueba_reacciones.gd. Diario: el catálogo como contrato y el encargo PL2 (tabla reacción → VFX + sonido).
```

### A5 · El escudo del goblin como componente (P2)

- **Qué.** `Escudo` como nodo hijo de `Combate3D`, con su propio `on_spell_hit`, los papeles `inflamable` y `bloquea_proyectiles`, y su vida.
  - Mientras está, los disparos directos de frente no llegan al goblin.
  - Si arde (A2), se consume y el goblin queda expuesto.
  - Ni el goblin ni el fuego saben del escudo. Es §4 de `DISENO_FUTURO.md` y F10 de la Fase 14.
- **Por qué.** En EoW el escudo de una variante añade su propio paquete de reacciones (guardia, escudo roto) sobre el enemigo base.
- **Archivos.** `enemigos/` (nuevo `escudo_3d.gd`), `enemigos/combate_3d.gd` (solo para colgarlo).
- **Comprobación.** `herramientas/prueba_escudo.gd`: la flecha de frente se bloquea; por la espalda, pasa; con fuego, el escudo arde y después la flecha pasa.

### D2 · Caminos de enemigo sobre casillas (P2)

- **Qué.** `AStarGrid2D` sobre casillas, con altura (sube o baja ±1 nivel, como el jugador), agua no transitable salvo helada y bloqueos de `Terreno3D`. Se invalida con `Mundo3D.casilla_cambio("bloqueo"|"altura"|"agua"|"hielo")`.
  - La IA del goblin lo usa para perseguir y patrullar cuando no hay línea recta.
- **Por qué.** La navegación de EoW es una rejilla de columnas por sala, no una malla de polígonos. Con altura entera, A\* sobre casillas basta y se recalcula barato cuando la magia cambia el terreno (muro de tierra, hielo).
- **Archivos.** `mundo/terreno_3d.gd` o un `mundo/caminos_3d.gd` nuevo, `enemigos/combate_3d.gd`.
- **Comprobación.** `herramientas/prueba_caminos.gd`:
  - el goblin rodea un muro de tierra recién creado;
  - cruza un puente de hielo y no cruza el agua;
  - el coste por recálculo es menor de 1 ms en 40×40 (medido).

### E1 · Rebaja de tinta por progresión y total cerrado (P2, tras decisión)

- **Decisión de Pablo antes de empezar:**
  1. ¿Cuánta tinta máxima en total se puede llegar a tener y cómo se reparte entre jefes, secretos y compras? En EoW los totales están cerrados (1000 = 70 % jefes + 30 % secretos).
  2. ¿El paso 2 de los pigmentos es una **rebaja por grupo de formas** (por ejemplo, el pigmento del bosque abarata `muro` y `columna`)? Así la mejora no depende del elemento, igual que en EoW.
- **Qué (después).** En `Tinta`, `GRUPO_REBAJA` por forma y la rebaja según `Estado.mejoras`, con los totales escritos como constantes.
- **Archivos.** `nucleo/tinta.gd`, `nucleo/estado.gd`.
- **Comprobación.** `herramientas/prueba_tinta.gd`: el coste con y sin pigmento, y que ninguna forma baje de 1/3 de su coste de partida.

---

## 4. Encargos al Pipeline (los escribe el Juego en el diario; no los hace)

| id | qué | nace de |
|---|---|---|
| **B2** | El shader del suelo lee `Mundo3D.estados.textura()` y se retira `_img_estado` y su caducidad de `prueba_test2.gd` | B1 |
| **PL1** | Animación de «ahogarse» para el goblin (buscar en Mixamo, Meshy o similar); hasta entonces el Juego lo hunde | A3 |
| **PL2** | Tabla `reacción → efecto + sonido` (plantilla común + excepciones) con `VfxPuzle3D` y `Sfx` | A4 |
| **F1** | Una luz direccional casi cenital (15–20°) cuyo **color dé el tono de cada zona** + ambiente de dos colores | ANALISIS_EOW §5 |
| **F2** | Banda de tilt-shift (centro, ancho, gamma) además del DOF ya pedido en la Fase 14 | ANALISIS_EOW §5 |
| **F3** | Un `ReflectionProbe` por sala (actualización `Once`, baja resolución) para agua y hielo | ANALISIS_EOW §5 |
| **F4** | Presupuesto orientativo para Meshy: protagonista 5–10k tris, enemigos 1,5–4k, piezas 300–1.500, texturas 256–1024², sin LODs | ANEXO 4 |

**Nota:** antes de pedir F1–F3, mirar si ya están hechos. Esta revisión no ha leído la iluminación ni la cámara de la maqueta.

---

## 5. Fuera de este plan (anotado para más adelante)

- Temperatura por región de 0 a 4 (en zona fría el agua se hiela sola). Cuando haya más de un bioma.
- Escenas al entrar en una zona con flag de «ya vista»; mapa que cambia de dibujo según flags; ayuda de controles por estado del jugador como tabla.
- Hoja de animación lógica por actor (nombre lógico → clip, bucle, siguiente, mezcla) y nombre compuesto `estado_base_dirección`: es del Pipeline; se le propone por el diario cuando toque animación.
- Botín con «nada» explícito, ingrediente local por zona y tabla «de apuros» con poca vida (§7 síntesis).
