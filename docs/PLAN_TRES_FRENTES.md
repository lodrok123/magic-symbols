# Plan: laboratorio de hechizos + animación, VFX y agua (18/10/2026, Juego)

Pablo (18/10, 00:17): ampliar el laboratorio de recetas a **laboratorio de hechizos**; de acuerdo con atacar en Godot
los tres frentes que motivaban mirar Unreal (animación, VFX, agua). **Arranca cuando el Pipeline termine V2**
(libro: línea rotada y chuleta, `GLIFOS_RECETA.md`). Duración objetivo: dos semanas. Cada frente tiene un criterio de
«resuelto» medible; si alguno no llega, prueba de 3 días en Unreal solo con ese frente y se decide con datos.

## 0. Laboratorio de hechizos (Juego, eje de todo)

Un solo laboratorio que reúne lo que hoy está repartido en encargos distintos, porque los tres frentes se juzgan en
el mismo sitio: con un hechizo lanzado por el personaje, contra enemigos y sobre agua.

`laboratorios/LabHechizos3D.tscn` + `lab_hechizos_3d.gd` (amplía el de recetas que Pablo está montando; si ya existe
`LabRecetas3D`, se renombra o se hereda: se decide al leer lo que haya en disco). Sala abierta con: dianas, dos goblins
quietos y uno que ataca, un pozo y un canal con agua, combustibles (seto, tronco), un poste alto y suelo libre.

Pestañas (tecla `F1`–`F5`), todas sobre el mismo personaje y la misma sala:

| pestaña | qué se ajusta | viene de |
|---|---|---|
| F1 Receta | contadores por glifo de `GLIFOS_V2` + elemento; volumen en alambre, casillas, coste, nombre derivado; modo barrido | R4 de `GLIFOS_RECETA.md` |
| F2 Cast point | variación, instante, sostener, recorte, offset desplazable, libro en la otra mano (B/C/V) | T-CP1 de `LAB_CASTPOINT.md` |
| F3 Impacto | reacción de enemigos (empuje, hitstop, destello, aplastamiento) con sus constantes en vivo | T-CP2 |
| F4 VFX | aprobación visual por estado × volumen × propiedad (§2 de este plan) | frente VFX |
| F5 Estados de animación | grafo del `AnimationTree` en vivo y botones para forzar cada transición (§1) | frente animación |

Comunes:
- cámara lateral fija / de juego;
- cámara lenta 0,25× (`L`) y paso a paso (`.`);
- PlayLog de todo lo que se ajusta;
- `G` guarda en `user://lab_hechizos.json`;
- `P` imprime los valores para volcarlos al código.

Herramienta, no juego: sin progresión ni tinta (tinta infinita por defecto, con un interruptor para medir coste).

## 1. Animación (Juego)

**Diagnóstico (medido en `jugador/pj_3d.gd`).** No hay máquina de estados: el `AnimationPlayer` se reproduce desde
**cinco** sitios del propio `Pj3D`:
- `jugar`;
- `giro_al_andar`;
- `beber`;
- `apuntar_clip`;
- el nado.

A eso se suman **15 llamadas** desde otros archivos (lanzador, jugador, escenas) a `jugar`, `lanzar`,
`soltar_lanzar` y `libro_en_manos`. El libro va con tres tweens independientes, y ya se mataron entre sí una vez
(el libro «cosido» a la mano). Quien llama último gana, y por eso el flujo no es estable.

**Arreglo:** `AnimationTree` con `AnimationNodeStateMachine` como única fuente de verdad.
- **Estados:** idle, andar, correr, nadar, apuntar, lanzar (subestados por variación de cast point), golpeado,
  rodar, beber, muerto.
- **Capa superior** con filtro de huesos para el brazo del libro (sustituye el `SkeletonModifier3D` de T-CP1, o lo
  complementa).
- **Libro:** un solo estado (`cinto`, `en_mano_abierto`, `en_mano_cerrado`, `volando`) con una función que decide la
  transición. Nunca tweens sueltos.
- **API pública igual:** `jugar()`, `lanzar()`, `soltar_lanzar()`, `libro_en_manos()` pasan a pedir **eventos** al
  árbol (`viajar_a(estado)`) en lugar de tocar el `AnimationPlayer`. Así los 15 sitios que llaman no cambian.
- Los enemigos (`combate_3d.gd` usa `Pj3D` con `anim_orden`) entran en una segunda tanda, con su propio grafo
  reducido.

**Criterio de resuelto:**
- prueba sin ventana que recorre **todas las transiciones permitidas y prohibidas** sin estados colgados;
- el libro termina siempre en un estado válido tras 1 000 secuencias al azar de eventos (lanzar, cancelar, rodar,
  ser golpeado, abrir/cerrar libro, nadar);
- PlayLog sin «clip no encontrado».

## 2. VFX (Pipeline, con laboratorio del Juego)

**Diagnóstico.** Casi todo el VFX se escribe en código (`vfx_3d.gd` 112 KB, `vfx_kit_3d.gd`) y se ajusta por capturas
fijas: el ciclo de ver → corregir es lento y a ciegas, sea cual sea el motor. La variedad es contenido, y el contenido
procedural cuesta mucho por pieza.

**Arreglo de método:**
1. **Efectos como escenas** (`presentacion/vfx/escenas/<estado>_<pieza>.tscn`: partículas, mallas y shaders montados
   en el editor), cargadas por nombre desde el código. El código decide **cuándo y dónde**; la escena, **cómo se ve**.
   Siguen siendo texto (`.tscn`), así que el Pipeline puede editarlas.
2. **Flipbooks estilizados** como base para llama, humo, chispa, salpicadura, polvo y destello (pack CC0 o generado).
   Encima, lo procedural que ya funciona (fuego y agua del kit).
3. **Matriz de aprobación** en la pestaña F4: estado (6) × volumen (esfera, X×3, Y×2, Z×3) × propiedad (ninguna,
   viaja, copias, crece, solidez) × impacto (suelo, goblin, agua, objeto). Pablo marca cada celda: aprobado /
   rechazado / nota. La matriz se guarda (`user://vfx_aprobados.json`) y es la lista de trabajo del Pipeline.
4. **Variedad por variantes:** cada pieza con 2–3 variantes y elección al azar con semilla, más tamaño y brillo por
   calidad del trazo.

**Criterio de resuelto:** las 6 × 4 celdas base (estado × volumen) aprobadas por Pablo en la pestaña F4, y cada
impacto (4) aprobado para los 6 estados. Presupuesto: ≤ 2 luces y ≤ 400 partículas por hechizo, medido en el lab.

## 3. Agua (Juego + Pipeline)

**Diagnóstico.** La simulación (`AguaSim3D`, tuberías, trocitos de 0,77 u) es buena para el gameplay (niveles de pozo,
hielo, electricidad, nado) y es la que manda; el dibujo (`AguaRender3D`) la pinta casi directamente, y por eso se ve
«a celdas». Ni Unreal resolvería esto para el gameplay: Niagara Fluids es visual y no se lee desde la CPU.

**Arreglo: dos capas.**
1. **Simulación de juego** (Juego, `mundo/agua_sim_3d.gd`): no cambia de modelo. Exporta lo que el dibujo necesita y
   hoy no tiene:
   - velocidad por trocito (ya está en B/A de `textura()`);
   - «caída» (salto de nivel entre vecinos);
   - una textura de **eventos** (dónde entra agua, dónde se rompe hielo, impacto de hechizo) que el render consume y
     limpia.
2. **Capa visual** (Pipeline, `presentacion/agua_render_3d.gd` + compute shader nuevo):
   - una superficie de **más resolución** (×4) que **sigue** a la simulación, sin decidir nada;
   - advección de la normal y de la espuma con la velocidad (flow map), para que el agua fluya en vez de subir y
     bajar por celdas;
   - suavizado espacial del nivel entre trocitos;
   - partículas de salpicadura y cascada donde hay caída;
   - ondas de impacto desde la textura de eventos;
   - bordes de orilla ya con ruido (125).
   
   El estilo es el de las referencias, estilizado y no realista: Echoes of Wisdom (superficie con brillos en bandas
   y espuma blanca en los bordes) y Link's Awakening.
3. **Comparación con referencia:** Pablo elige un vídeo corto de agua de Echoes of Wisdom (pozo llenándose, río con
   corriente, cascada) y la pestaña F4 tiene una escena del lab que reproduce esas tres situaciones con la simulación.

**Criterio de resuelto:**
- en las tres situaciones no se distinguen celdas a la distancia de cámara del juego (Pablo lo valida con la
  referencia al lado);
- la capa visual no cambia ningún resultado de `escenario_puzles_agua` (FALLOS 0);
- coste del compute ≤ 1 ms en el desktop.

## 4. Reparto, orden y prompts

| semana | Juego | Pipeline | Pablo |
|---|---|---|---|
| 0 (ahora) | R1 (receta v2: datos y volumen) | **V2** (libro: línea rotada, chuleta) | lab de recetas en marcha |
| 1 | L0 laboratorio de hechizos (pestañas F1–F3) · A1 `AnimationTree` del héroe | X1 método VFX (escenas + flipbooks) · W1 capa visual del agua (prototipo) | elegir vídeo de agua de referencia |
| 2 | A2 libro y enemigos en el árbol · L0 pestañas F4–F5 · W0 exportación de la simulación | X2 matriz de VFX (6 estados × 4 volúmenes) · W2 capa visual completa | aprobar en F4; validar agua y estados |

R2–R3 (materia por estado y propiedades) siguen su curso en paralelo; el lab los incorpora a medida que existan.

**L0 · Juego · laboratorio de hechizos**
```
Contexto Juego. Lee docs/PLAN_TRES_FRENTES.md §0 (proyecto), LAB_CASTPOINT.md y GLIFOS_RECETA.md, y las últimas entradas de docs/DIARIO.md. Mira qué hay ya del laboratorio de recetas en laboratorios/ (Pablo lo está montando) y amplíalo, no lo dupliques.
Crea laboratorios/LabHechizos3D.tscn + lab_hechizos_3d.gd:
- sala con dianas, 2 goblins quietos y 1 que ataca, un pozo y un canal con agua, seto y tronco, poste alto;
- pestañas F1 Receta, F2 Cast point, F3 Impacto (§0); F4 VFX y F5 Estados como paneles vacíos que se rellenan en la semana 2;
- comunes: cámara lateral/juego, L (0,25×), . (paso), G guarda en user://lab_hechizos.json, P imprime para el código; tinta infinita con interruptor.
Cada pestaña lee y escribe las constantes de su sistema sin duplicarlas (CastPoints, Combate3D, Sigils.GLIFOS_V2).
Prueba herramientas/prueba_lab_hechizos.gd: el lab carga sin errores y cada pestaña lanza un hechizo.
Diario. Sin commit.
```

**A1 + A2 · Juego · máquina de estados de animación**
```
Contexto Juego. Lee docs/PLAN_TRES_FRENTES.md §1.
Diagnóstico medido: Pj3D reproduce el AnimationPlayer desde 5 funciones propias (jugar, giro_al_andar, beber, apuntar_clip, nado) y hay 15 llamadas externas a jugar/lanzar/soltar_lanzar/libro_en_manos; el libro va con 3 tweens.
A1:
- en jugador/pj_3d.gd, un AnimationTree con AnimationNodeStateMachine para el héroe;
- estados: idle, andar, correr, nadar, apuntar, lanzar (un subestado por variación de CastPoints), golpeado, rodar, beber, muerto;
- transiciones con mezcla;
- capa superior con filtro de huesos para el brazo del libro.
La API pública (jugar, lanzar, soltar_lanzar, apuntar, cancelar_apuntar, rodar, beber) se queda igual por fuera y por dentro pide viajar_a(estado): ningún llamador cambia. Nadie fuera del árbol toca _ap.play.
A2:
- el libro como un estado único (cinto, en_mano_abierto, en_mano_cerrado, volando) con una sola función de transición; fuera los tweens sueltos;
- segunda tanda: los enemigos de combate_3d.gd con un grafo reducido (idle, andar, atacar, golpeado, muerto).
Pruebas:
- herramientas/prueba_estados_anim.gd: todas las transiciones permitidas y prohibidas;
- 1 000 secuencias aleatorias de eventos acaban con el libro en un estado válido;
- ningún «clip no encontrado».
Regresión de escenarios a 0. Pestaña F5 del lab con el grafo en vivo. Diario. Sin commit.
```

**W0 · Juego · lo que la simulación exporta al dibujo**
```
Contexto Juego. Lee docs/PLAN_TRES_FRENTES.md §3.
En mundo/agua_sim_3d.gd, sin cambiar el modelo de simulación:
- documentar en la cabecera que velocidad = B/A de textura();
- añadir textura_caida() (salto de nivel con el vecino más bajo, por trocito);
- añadir textura_eventos() (R = agua que entra, G = hielo roto, B = impacto de hechizo; el render la consume y la sim la limpia cada paso);
- API emitir_evento(c, tipo, fuerza) para que hechizos y reacciones lo usen.
Coste medido < 0,3 ms. escenario_puzles_agua y prueba_agua_sim a 0.
Diario con el contrato (el Pipeline lo usa en W1/W2). Sin commit.
```

**X1 + X2 · Pipeline · método y matriz de VFX**
```
Contexto Pipeline. Lee docs/PLAN_TRES_FRENTES.md §2 (te lo pasa Pablo), GLIFOS_RECETA.md y VFX_RAYO_HIELO.md.
X1 (método):
- Los efectos pasan a ser escenas en presentacion/vfx/escenas/<estado>_<pieza>.tscn (partículas, mallas y shaders montados en el editor) que el código carga por nombre. El código decide cuándo y dónde; la escena, cómo se ve.
- Base de flipbooks estilizados (llama, humo, chispa, salpicadura, polvo, destello) de un pack CC0 o generados; licencia en presentacion/vfx/LICENCIAS.md.
- 2–3 variantes por pieza con elección por semilla.
- Migrar primero lo que ya funciona (fuego y agua del kit) a escenas sin cambiar su aspecto, para validar el método.
X2 (matriz):
- un VFX por estado (solido, liquido, plasma, energia, gas, campo) que se escala al volumen (X, Y, Z) de la señal hechizo_v2 del Juego;
- firmas por propiedad (viaja, copias, crece, solidez);
- impactos sobre suelo, goblin, agua y objeto.
Pablo aprueba cada celda en la pestaña F4 del lab (user://vfx_aprobados.json): esa lista es la de trabajo.
Presupuesto: ≤ 2 luces y ≤ 400 partículas por hechizo.
Si necesitas cambios en archivos del Juego, pídelos por el diario. Sin commit.
```

**W1 + W2 · Pipeline · capa visual del agua**
```
Contexto Pipeline. Lee docs/PLAN_TRES_FRENTES.md §3 y el contrato W0 del Juego en el diario.
El dibujo del agua deja de pintar la simulación casi tal cual y pasa a SEGUIRLA con una capa propia, sin decidir nada del gameplay.
W1 (prototipo):
- superficie de resolución ×4 sobre la de la simulación, con un compute shader (RenderingDevice) que suaviza el nivel entre trocitos y sigue a la simulación con un muelle;
- advección de normal y espuma con la velocidad (flow map).
W2 (completa):
- salpicadura y cascada donde textura_caida() > umbral;
- ondas desde textura_eventos();
- estilo Echoes of Wisdom / Link's Awakening: brillos en bandas, espuma blanca en orillas y caídas;
- mantener la orilla con ruido (125) y el hielo (11.14).
Validación:
- las tres situaciones de referencia (pozo llenándose, río con corriente, cascada) en la escena de agua del lab, con el vídeo de Pablo al lado;
- coste ≤ 1 ms en el desktop;
- escenario_puzles_agua sigue a FALLOS 0 (la capa no toca la simulación).
Si necesitas algo de la simulación, pídelo por el diario. Sin commit.
```

**Pablo**
- Elegir el vídeo de agua de referencia (3 situaciones).
- Aprobar celdas de VFX en F4.
- Validar agua y estados en las pestañas del lab.
- Decidir al final de la semana 2 si algún frente necesita la prueba de 3 días en Unreal.

— Juego
