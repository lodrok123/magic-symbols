# Asesoramiento de dirección (2/11/2026): dónde está el proyecto y por dónde seguir

Encargo de Pablo: «asesórame en la dirección: lee todo lo que está ya implementado y dime direcciones donde podría implementar». Hecho sobre `E:\magic-symbols` en `main` (`8cc1a83e`) más `origin/main`, los documentos de `docs/` (auditoría del 24/10, `PLAN_VFX_ELEMENTOS`, `DISENO_FUTURO`, `PENDIENTES`, `DECISIONES_CHATS`, diario hasta la 318) y cuatro lecturas del código en paralelo (núcleo, contenido y presentación, ramas). Solo lectura; nada se ha cambiado en el juego.

## 1. Dónde está el proyecto, en una página

**Lo maduro** (se puede construir encima sin miedo):

| qué | dónde | estado |
|---|---|---|
| Modelo de hechizo | `nucleo/hechizo.gd`, `nucleo/sigils.gd` (14 glifos), `nucleo/dano.gd` | 48 048 combinaciones construyen; semiejes X/Y/Z, `viaja`, `haz`, materia; una sola entrada de daño y tinta |
| Ejecución por materia | `magia/hechizo_vivo.gd` (`MATERIA_V2`) | sólido → bloque, líquido → `AguaSim3D`, plasma → zona que daña, energía → descarga, gas → empuje |
| Mundo con estado | `mundo/estados_suelo_3d.gd`, `reacciones_*_3d.gd`, `agua_sim_3d.gd`, `Mundo3D.reaccion` (13 reacciones) | tablas como datos; pruebas sin ventana |
| Enemigos | `enemigos/combate_3d.gd` + limo, gólem, chamán, gatopedro, escudo | IA, debilidades, estados, avisos de ataque, jefe |
| Puzles por datos | `escenas/puzle.gd` + mapas `.txt` + `objetos/` (≈ 30 piezas reactivas) | niveles encadenados Bosque → Cueva → Cueva Resonante, Gruta, salas |
| Gestos | `nucleo/gesture_*` | reconocedor $P con asistencia |
| Fuego y agua oficiales | `presentacion/vfx/toy/` (`FuegoToy`, `AguaToy`) | paramétricos desde semiejes y figura; aprobados el 1 y 2/11; `desde_hechizo(h)` existe |
| Pruebas | ≈ 175 `herramientas/prueba_*.gd` | cubren hechizo, agua, estados, enemigos, VFX, UI |
| Gamefeel y sonido | rama `claude/gamefeel-review-ef17c5`, ya en `origin/main` | hitstop, empuje, cámara, buses «Mundo/Ocluido», menú principal, remapeo, caminar (polvo, huellas, hierba con muelle), grabaciones |

**Lo verde** (existe a medias o no existe):

- **Los glifos no hacen todo lo que prometen** (auditoría 24/10, A5): repetición con flecha lanza un solo proyectil; flechas de tierra y hielo caen a 0,7 casillas; `crecer` nunca cambia una casilla; los proyectiles atraviesan muros con solidez; hielo y rayo «aparcados» en el daño; los eventos (`crear_hijo`, `al_impactar`) no los usa ningún glifo; tinta por glifo a 0.
- **El fuego y el agua oficiales no están en el juego**: ningún script fuera del laboratorio instancia `FuegoToy` ni `AguaToy`; el juego sigue dibujando con `vfx_elemento_3d.gd` y `vfx_elementos/`. Hay **seis familias de VFX** conviviendo.
- **Hielo, rayo, tierra y viento** no tienen versión «toy»; rayo y hielo están señalados como «mejorable» y «no» en el playtest.
- **El mundo responde sin reloj**: `DURA` a 0 y `avanzar()` solo en pruebas (una casilla mojada no se seca); la hierba vive en la maqueta `prueba_test2.gd` (5 343 líneas) y no en `mundo/`; rayo, viento y tierra no cambian el suelo; la jugadora no tiene estados de elemento.
- **Progresión sin cerrar**: el nivel de arranque usa `kit = "pruebas"` (todo desbloqueado); permanencia, perforar y buscar no tienen gesto grabado; la Cueva no se puede terminar con el repertorio real; la barrera del Bosque no es obligatoria; sello de la Torre del Agua sin decidir.
- **Partida**: se guarda en baldosas, pero el «continuar» no tiene menú que lo llame (el menú principal nuevo de gamefeel puede resolverlo).
- **Build**: HUD de depuración y paleta F1 visibles, puzles con primitivas, cuatro familias de árbol, 144 GLB cargados por nivel, texturas sin comprimir, sin música de exploración, fuente del sistema, solo castellano en código.
- **Documentos desfasados**: `README.md` y `CONTEXTO.md` describen un juego 2D; `DISENO_FUTURO.md` (6/10) sigue con la «prueba 3D» como P0; `PROPIETARIOS.md` no conoce a «Dirección» ni «Godot»; no hay GDD; el diario tiene números repetidos (295–301 dos veces; 307–309 también en la rama de gamefeel; 302 y 305 faltan).

**Estado del repositorio** (importa para empezar cualquier cosa):

- `origin/main` va **21 commits por delante** de tu `main` local: alguien fusionó y empujó la rama de gamefeel el 2/11 a las 17:56 (menú principal, buses, caminar, grabaciones, arreglo de la cámara lenta). Tu copia de E no lo tiene. Trae `presentacion/caminar_3d.gd`, que aquí no existe, y reescribe `project.godot`.
- Sin commit en `E:\magic-symbols`: trabajo del agua toy (`agua_toy.gdshaderinc`, `agua_gota.gdshader`, `agua_paleta.gd`, `prueba_agua_toy.gd`), `docs/qa/` y `respaldos/`.
- Ramas con trabajo no fusionado: `claude/game-spell-system-86c11b` (17 ficheros modificados sin commit, 41 commits por detrás: hay que decidir si vale algo) y `claude/prueba2-unreal-toon` (archivo histórico).
- Worktrees viejos en C (`gamefeel-review`, `game-spell-system`, `weight-paint`) y en `E:\tmp\wt_*`.

## 2. Direcciones posibles

Cada una termina en algo que se puede jugar o enseñar, dice qué abre, cuánto cuesta (jornadas de agente, 8 h, con lo medido estas semanas: una ronda de VFX ≈ 15–40 min, un lote de lógica con pruebas ≈ 1–2 jornadas) y qué tienes que decidir tú.

### A. El fuego y el agua oficiales entran en el juego (y el Sello se ejecuta)

**Qué.** Selector ACTUAL/PROCEDURAL en `VfxElemento3D`; `FuegoToy`/`AguaToy` creados desde `HechizoVivo` con `desde_hechizo(h)`, carga en la mano, impacto y muerte por eventos; retirar las familias de VFX que sobran. En paralelo, el lote 1 de la auditoría: repetición con flecha, impulso de tierra y hielo, proyectil contra solidez, `crecer` en m/s.
**Por qué ahora.** Todo el trabajo de VFX de noviembre está en un laboratorio. Hasta que no se vea en el Bosque con la cámara del juego, no sabes si el método aguanta la escala real, y «que no haya que hacer nada por hechizo» solo se cumple cuando `HechizoVivo` manda.
**Abre.** Un recorrido Gruta → Bosque → Cueva con el fuego y el agua aprobados; la matriz figura × elemento como regla del juego; y los glifos que prometen algo lo cumplen.
**Coste.** 3–4 jornadas (enganche 1,5; lote 1 con pruebas 1,5; limpieza de familias 1).
**Riesgo.** Rendimiento en la UHD 620 con muchos efectos a la vez (el muro de hierba ardiendo usa el kit barato; hay que mantenerlo así).
**Decides.** Si el fuego de la hierba (hasta 60 casillas) también pasa a `FuegoToy` o sigue con lenguas baratas.

### B. Los cuatro elementos que faltan, con el mismo generador

**Qué.** Hielo, rayo, tierra y viento como clases hermanas de `FuegoToy`/`AguaToy` (misma figura, mismos ejes, misma API), y entonces una base común `ElementoToy`. Paleta de cada uno sacada de lo que ya existe en el mundo (tu regla del 2/11). Rayo y hielo primero (son los peor valorados en el playtest).
**Abre.** Cambiar de elemento sin cambiar de tamaño ni de figura; un banco de comparación con 6 × 5 celdas; los puzles de hielo y rayo de la Torre y la Montaña con su aspecto.
**Coste.** 1–1,5 jornadas por elemento (el fuego costó ≈ 3 h de agente en 8 rondas más 1 h de carga/impacto; el agua, 4 fases en un día). Total 5–6 jornadas.
**Riesgo.** Hacerlo antes de A: cuatro elementos más en un laboratorio sin saber cómo se enganchan. Mejor tras A, o al menos tras el selector.
**Decides.** El carácter de cada uno (el plan del 31/10 ya lo fija: hielo crece por etapas y se rompe; rayo dura muy poco; tierra pesa y tiembla; el viento se ve por lo que mueve) y el orden.

### C. El mundo responde: reloj, catálogo, propagación, jugadora

**Qué.** Lote 3 de la auditoría (un solo reloj de estados, catálogo de reacciones con un nombre por reacción, guardar y cargar la partida entera) más la regla general del plan de VFX: cada transición emite orden y hora por casilla, para que la placa de hielo crezca y la descarga viaje; hierba seca y viento que propaga (decididos el 31/10); estados de elemento en la jugadora (arde, se moja, se congela). Sacar el autómata de la hierba de la maqueta a `mundo/`.
**Por qué.** Es el pilar «Noita» de tu lámina: el elemento cambia el mundo y ese cambio se ve y se propaga. Hoy la infraestructura está y el reloj no corre.
**Abre.** Charcos que se secan, contrarreloj por casilla, calor de bioma, propagación legible, y la primera consecuencia no letal (caer al agua) tal como la decidiste el 6/10.
**Coste.** 4–5 jornadas (reloj y catálogo 1; partida 0,5; propagación con orden 1; hierba a `mundo/` 1,5; jugadora 1).
**Riesgo.** Toca `prueba_test2.gd` y `combate_3d.gd`, los dos ficheros gigantes: hay que ir con pruebas de igualdad (HC1–HC3), como se hizo con `Hechizo`.
**Decides.** Nada nuevo: las decisiones de octubre ya están tomadas.

### D. Progresión cerrada y niveles que se pueden demostrar

**Qué.** Kit real de arranque (decidido el 27/10: 4 elementos y 6 glifos en el primer libro, 3 huecos del círculo), gestos de ᛉ ᚱ ᚦ ᛃ ᚨ grabados (tú, con G), barrera obligatoria en la tala, cofre de la Cueva que no se desella solo, Cueva terminable con el repertorio real; autotest de resolubilidad capa 1 (`prueba_resolubilidad.gd`, 3–16 ms por nivel, gramática `; prueba` en el mapa). Y una decisión pendiente desde el 24/10: sello de la Torre del Agua (la auditoría propone hielo).
**Abre.** Un nivel nuevo entra con líneas `; prueba` y se sabe sin jugarlo si se puede terminar; la Torre del Agua se puede diseñar con un sello decidido.
**Coste.** 3 jornadas de agente más 1 hora tuya grabando gestos.
**Riesgo.** Ninguno técnico; el riesgo es seguir diseñando niveles sin esto y descubrir en playtest lo que la capa 1 detecta en milisegundos.
**Decides.** Sello de la Torre; si la Gruta Batida (solo fuego, 28/10) es el tutorial real.

### E. Build presentable para un playtest externo

**Qué.** Las mejoras S de la auditoría (quitar depuración de serie, hierba a la paleta, jugadora siempre visible, fuente propia), `PiezaPuzle3D` en los objetos, una familia de árbol y una de pino, Cueva en paleta y boca con modelo, cargar solo las piezas del nivel y comprimir texturas, música de exploración con los buses nuevos, menú principal (ya en `origin/main`) con «continuar».
**Abre.** Que alguien que no eres tú juegue media hora sin que la build parezca de desarrollo. Es la única forma de validar el bucle.
**Coste.** 4–6 jornadas de agente más tu trabajo en Meshy (árboles) y una decisión de presupuesto de triángulos.
**Riesgo.** Es trabajo que no abre jugadas nuevas (tu criterio de `DISENO_FUTURO`); solo tiene sentido justo antes de enseñar el juego.

### F. Orden en el repositorio y en los documentos

**Qué.** Traer `origin/main` a tu copia (decisión tuya: es tu `main`); commitear o descartar el agua toy sin commit; decidir la rama `game-spell-system` (17 ficheros modificados, 41 commits atrás) y archivar `prueba2-unreal-toon`; borrar worktrees viejos de C y `E:\tmp\wt_*`; commitear los `.import`/`.uid` desde la copia principal; renumerar el diario; retirar `spellcaster.gd`, `Campo`, `GLIFOS_V2`, `SpellRecipe`; reducir seis familias de VFX a dos; reescribir `README.md`, `CONTEXTO.md` y `PROPIETARIOS.md` para el juego 3D real con los contextos reales, y un GDD de dos páginas con los pilares y el bucle (hoy no existe y cada chat lo reconstruye).
**Coste.** 1 jornada para lo del repositorio; 1 para los documentos; la limpieza de código, 2 (tras tus decisiones 4–6 de la auditoría).
**Por qué primero.** Cada sesión nueva pierde una hora recomponiendo el estado; y con tres copias de `main` distintas (C, E, origin) la siguiente fusión va a doler.

## 3. Mi recomendación

El proyecto ya tiene la arquitectura que quiere («datos, no código», combinaciones que emergen) y ha ganado en noviembre el lenguaje visual que le faltaba (fuego y agua). Lo que hoy frena no es falta de sistemas: es que **lo construido no se encuentra en el juego**: el fuego oficial vive en un laboratorio, los glifos no ejecutan lo que construyen y el mundo no tiene reloj. Por eso:

1. **F mínimo (1 jornada)**: `main` sincronizado con `origin`, agua toy commiteada, ramas cerradas, diario renumerado. Sin esto, lo demás se construye sobre tres versiones.
2. **A (3–4 jornadas)**: el fuego y el agua oficiales en el juego, con el selector, y el lote 1 del Sello. Al terminar: recorrido Gruta → Bosque → Cueva con los VFX aprobados y los glifos cumpliendo. Es la dirección que convierte en juego todo lo de noviembre.
3. **C (4–5 jornadas)**: el mundo responde con reloj y propagación; la jugadora con estados. Es el siguiente pilar de tu lámina y no depende de arte nuevo.
4. **B (5–6 jornadas)**, intercalada con C: hielo y rayo primero, cuando el selector de A ya enseña cómo entran al juego; tierra y viento después.
5. **D** va en paralelo porque la mitad es tuya (decisiones y gestos) y la otra mitad (resolubilidad) es un agente solo.
6. **E** justo antes del primer playtest con alguien externo. Ponle fecha y que esa fecha ordene el resto.

En total, unas 20 jornadas de agente hasta un juego que otra persona puede jugar con los seis elementos, con una Torre del Agua diseñable encima. Lo que no haría ahora: biomas nuevos (pantano, montaña) ni elementos combinables (`DISENO_FUTURO` §1) hasta que A y C estén; las dos cosas se apoyan en el reloj y la temperatura por región, que es el lote 11 de la auditoría.

## 4. Lo que te toca decidir

| # | decisión | para qué dirección |
|---|---|---|
| 1 | Traer `origin/main` (gamefeel) a tu `main` de E | F |
| 2 | Qué hacer con `claude/game-spell-system-86c11b` (17 ficheros sin commit) | F |
| 3 | Borrar `spellcaster.gd`, la barrera-burbuja `Campo` y las tres escenas sin referencia (decisiones 4–5 de la auditoría, pendientes desde el 24/10) | F |
| 4 | Si la hierba ardiendo (hasta 60 casillas) pasa a `FuegoToy` o sigue con el kit barato | A |
| 5 | Sello de la Torre del Agua: hielo (propuesta) o agua | D |
| 6 | Orden de los cuatro elementos que faltan (propuesta: rayo, hielo, tierra, viento) | B |
| 7 | Fecha del primer playtest externo | E |
| 8 | Presupuesto de triángulos real (hoy son los valores por defecto de Meshy) | E |

## 5. Si empezamos mañana: tres encargos concretos

1. **Sincronizar y cerrar** (Dirección, 1 jornada): fusión de `origin/main`, commit del agua toy, archivo de ramas, diario renumerado, `README`/`CONTEXTO`/`PROPIETARIOS` al día, GDD de dos páginas.
2. **FuegoToy y AguaToy en el juego** (Godot, Sonnet, 1,5 jornadas): selector, `desde_hechizo` desde `HechizoVivo`, carga e impacto por eventos, lámina lado a lado con la cámara del juego, pruebas. Ya hay una tarjeta preparada para esto.
3. **El Sello se ejecuta** (Juego, Sonnet programa y Opus verifica, 1,5 jornadas): los cuatro incumplimientos bloqueantes de A5 con las seis pruebas nuevas que propone la auditoría.

Los dos últimos pueden ir a la vez: tocan ficheros distintos (`presentacion/` frente a `magia/` y `nucleo/`).
