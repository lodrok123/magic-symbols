# Bloque de ambiente global · lo que ya hay contra lo que ganariamos

Medicion del 7/11/2026 sobre el proyecto, antes de tocar nada.
Continua [GENSHIN_DIRECCION_ARTE_2026-11-07.md](GENSHIN_DIRECCION_ARTE_2026-11-07.md).

**Conclusion por delante: la direccion mejora los resultados, pero no por donde yo dije.** El bloque
global en si no cambia ni un pixel. Lo que cambia los resultados son dos cosas que el bloque hace
posibles, y que he podido medir. Los numeros estan abajo.

---

## 1. Lo que YA hay (y es mas de lo que parece)

Hay que reconocerlo antes de proponer nada:

| Ya resuelto | Donde |
|---|---|
| Infraestructura de uniforms globales, funcionando | `albedos_3d.gd`, `ocluso_3d.gd` (`global uniform vec4` + `global_shader_parameter_add`) |
| Parcheo de shaders en caliente, idempotente | `Albedos3D.parchear_ocluso()` |
| Normalizacion de contraste y valor por familia | `Albedos3D` (K, VALOR, SAT por familia, medido en `docs/capturas/albedos/MEDIDAS.md`) |
| Rampa toon con sombra tintada | `prueba_test2.gd`, `agua_render_3d.gd`, `lecho_rio_3d.gd`, `material_personaje_3d.gd` |
| Un material comun para las 195 piezas de Meshy | `Ocluso3D.convertir()`, 3 variantes de culling |

**Esto importa**: la mitad del trabajo de "prioridad 1" del documento anterior ya esta hecho. El patron
existe, funciona y tiene precedente. Lo que falta no es la tuberia, es **que la usen los que no la
usan**.

Y `Albedos3D` merece una nota: hace lo correcto por el camino largo. Comprime el contraste de las
texturas de Meshy hacia su media para que no canten. Eso es *corregir la textura a posteriori*.
Genshin hace que la textura no tenga nada que corregir. Las dos cosas son compatibles: `Albedos3D`
neutraliza, el bloque unifica la luz. No hay que tirar nada.

---

## 2. Lo que esta realmente roto (medido, no opinado)

### 2.1 El mundo tiene DOS modelos de luz y no casan

Busqueda de `void light()` en todo el proyecto (sin worktrees ni respaldos):

| Familia | Modelo de luz | Sombra |
|---|---|---|
| Suelo (`prueba_test2.gd` L585, L707) | rampa toon propia | `vec3(0.34, 0.36, 0.46)` fria |
| Agua (`agua_render_3d.gd` L1007, L1070) | rampa toon propia | `vec3(0.34, 0.36, 0.46)` |
| Lecho (`lecho_rio_3d.gd` L158, L220) | rampa toon propia | `vec3(0.34, 0.36, 0.46)` |
| Personaje (`material_personaje_3d.gd` L129) | rampa toon propia | `vec3(0.62, 0.62, 0.85)` **distinta** |
| **Las 195 piezas de Meshy** (`Ocluso3D`) | **PBR estandar de Godot** | la que salga del ambiente |
| **La hierba** (`Hierba3D`) | **PBR estandar de Godot** | la que salga del ambiente |

El decorado y la hierba **no estan en el mismo sistema de luz que el suelo que pisan**. El suelo tiene
una rampa de dos escalones con sombra azul pastel; el arbol que hay encima tiene un degradado Lambert
continuo con sombra gris. No es impureza arquitectonica: es que, literalmente, no se iluminan igual.

Esto es lo que mas pesa de todo el analisis, y no estaba en el documento de ayer.

### 2.2 El arte se aprueba con 24 luces distintas, y ninguna es la del juego

`ambient_light_color` puesto a mano: **72 sitios, 24 valores distintos**. `ambient_light_energy`:
**52 sitios, 6 valores**.

```
 11x  Color(0.75, 0.82, 0.9)    <- herramientas/captura_*: personajes, jugadora, goblins, elfo...
  7x  Color(1, 1, 1)            <- captura_golem*, captura_chaman, captura_rig_*, mixamo
  6x  Color(0.95, 0.94, 1.0)    <- prueba_test2.gd (EL JUEGO), catalogo_assets, captura_haz
  6x  Color(0.7, 0.72, 0.8)     <- captura_vfx_*, captura_recetas_vfx, captura_conjuro_vfx
  5x  Color(0.8, 0.8, 0.85)     <- capturas de agua
  5x  Color(0.7, 0.7, 0.7)      <- diag_*, captura_viento, captura_vfx_tierra_viento
  ... y 18 valores mas, de Color(1,1,1) a Color(0.35, 0.36, 0.42)
```

Lee la tercera linea: **el juego corre a `Color(0.95, 0.94, 1.0)`**. Y:

- Los **personajes** se aprueban a `(0.75, 0.82, 0.9)`. Frente al juego: 79 % del rojo, 87 % del verde,
  90 % del azul. Es decir, se aprueban bajo una luz **mas apagada y mas fria**, y luego se juegan bajo
  una **mas brillante y mas calida**. Un personaje ajustado hasta que se ve bien en la captura sale en
  el juego mas claro y mas calido de lo que se decidio.
- Los **VFX** se aprueban a `(0.7, 0.72, 0.8)`: 74 % del rojo del juego. Aun mas lejos.
- Los **golems, el chaman y los rigs** se aprueban a `Color(1, 1, 1)`: luz plana, blanca, sin direccion.
  Cualquier cosa aprobada ahi llega al juego con una sombra que no se vio al aprobarla.

Esto explica, por el lado de la causa, el sintoma que `Albedos3D` corrige por el lado del efecto:
*"en pantalla las copas salian mas claras que la hierba (208 contra 198)"*. Claro: se aprobaron con
otra luz.

### 2.3 Seis copias del mismo valor

`sombra_tinte : source_color = vec3(0.34, 0.36, 0.46)` esta escrito **seis veces** (suelo ×2, agua ×2,
lecho ×2), con el mismo valor. `contraste` esta escrito seis veces con **cuatro valores** (2.5, 1.5,
1.2, 1.2). `contraste_faceta = 0.2` esta dos veces.

Hoy esto **no se nota**, porque los valores coinciden por disciplina de copiar y pegar. Es deuda, no
sintoma.

---

## 3. Ganancia contra coste, parte por parte

Honestamente, y con el veredicto delante.

| # | Cambio | Ganancia visual HOY | Coste | Riesgo | Veredicto |
|---|---|---|---|---|---|
| **A** | Unificar `sombra_tinte` + `contraste` en `amb_sombra` global | **Ninguna** | Bajo (7 shaders) | Bajo | Hacerlo, pero no es la razon |
| **B** | Dar la rampa toon a las 195 piezas y a la hierba | **Alta** | Medio | **Medio** | **Esta es la que mejora resultados** |
| **C** | Una sola luz de aprobacion = la del juego | **Alta, indirecta** | Medio (72 sitios) | **Alto** (invalida capturas) | Hacerlo, pero acotado |
| **D** | Ambiente hemisferico (cielo arriba / suelo abajo) | Media | Medio | Bajo | Despues de B |
| **E** | Niebla tintada por el cielo | Baja | Medio | Bajo | No ahora |
| **F** | Presets por zona (bosque / cueva) | **Ninguna** (hay una zona) | Bajo | Bajo | Inversion, no mejora |

### Por que **B** es la buena

Es el unico cambio que arregla algo que se ve mal **hoy, en la pantalla, sin imaginar nada**. El
decorado y la hierba son la mayor parte de los pixeles de una escena de bosque, y estan en otro
sistema de luz que el suelo. Darles la misma rampa hace que las 195 piezas de Meshy —que vienen de
24 generaciones distintas y es lo que mas cuesta cohesionar— se lean juntas de golpe, sin tocar ni
una textura.

Y tiene un punto de inyeccion unico: `Ocluso3D.CODIGO`, tres variantes de culling, con el precedente
exacto de `Albedos3D.parchear_ocluso()`. Es un cambio de un archivo.

**El riesgo es real**: cambia el aspecto de todo el decorado a la vez. Hay que verlo en capturas antes
de quedarselo, y puede que la rampa del suelo (contraste 2.5) sea demasiado dura para un tronco. Por
eso `amb_sombra` global + un offset por familia (como `_TreeDiffuseRampScale/Offset` de Genshin) en
vez de una rampa unica rigida.

### Por que **A** sola no vale la pena como objetivo

Seis copias con el mismo valor. Unificarlas no mueve un pixel. Es la **tuberia** que hace posible B,
D y F, y por eso se hace — pero presentarla como "prioridad 1" era un error mio: ordena el codigo, no
mejora el juego.

### Por que **C** hay que acotarlo

El fondo es correcto: aprobar arte bajo una luz que no es la del juego garantiza que el arte no case.
Pero tocar los 72 sitios **invalida todas las capturas de referencia** de `docs/capturas/`, incluidas
las medidas de `MEDIDAS.md` sobre las que esta calibrado `Albedos3D`. Seria rehacer la calibracion
entera.

Acotado: cambiar **solo** las herramientas que aprueban arte que va al juego (los `captura_*` de
personajes, piezas y VFX, ~25 archivos) y dejar en paz las de diagnostico y las de comparacion
historica. Y hacerlo **despues** de B, no antes, porque B ya cambia como se ve todo.

### Por que **F** no es una mejora todavia

Presets por zona solo pagan cuando hay zonas. Hoy hay una. Segun el objetivo del proyecto —una zona
de prueba pequeña y funcional con enemigos— la segunda zona no es inminente. Dejarlo preparado cuesta
nada (el bloque ya es global), pero no cuenta como ganancia.

---

## 4. Recomendacion

**Si, la direccion mejora los resultados, con el orden invertido respecto a lo que propuse ayer:**

1. **A como medio, no como fin** — `amb_sombra` (vec4: rgb tinte, a contraste) y `amb_sombra_pers`
   global. Refactor puro: los 7 `light()` leen el global en vez de su uniform. **Cero cambio visual**,
   y eso es la prueba de que esta bien hecho: captura antes y despues identicas.
2. **B, que es el premio** — inyectar la rampa en `Ocluso3D.CODIGO` (3 variantes) y en `Hierba3D`, con
   offset y escala por familia sobre la rampa comun. Captura de la misma escena antes/despues para
   decidir el offset de cada familia.
3. **D** — ambiente hemisferico, una vez B este aceptado.
4. **C acotado** — igualar la luz de aprobacion de los ~25 `captura_*` que alimentan el juego.
5. **F** queda preparado gratis. **E** se deja.

**Lo que no haria:** tocar `Albedos3D` ni recalibrar `MEDIDAS.md` en este paso. Son compatibles y
estan medidos; moverlos ahora mezcla dos cambios y no se sabria cual rompio que.

**Como se mide el exito:** una captura de la escena de bosque antes y despues del paso 2. Si el
decorado y el suelo se leen como una sola cosa, la direccion vale. Si no, se revierte un archivo.

---

## 5. Resultado medido del paso B (7/11, despues de implementarlo)

La rampa del decorado se implemento y **no funciona**. Barrido del contraste base `amb_sombra.a`,
midiendo sobre `viento_sin_a.png` la separacion entre la copa iluminada (x 150-520, y 200-560) y la rama
en sombra (x 230-430, y 430-600) del mismo pino. La separacion dentro de la misma imagen es la medida de
si hay rampa, y no la contamina el ruido entre ejecuciones.

| contraste base | separacion copa-rama (R / G / B) | hierba (control) |
|---|---|---|
| sin rampa (antes) | +0,9 / +1,9 / +8,0 | 158,6 / 207,1 / 78,9 |
| 1,2 | +0,0 / +1,3 / +7,4 | 158,7 / 207,3 / 78,9 |
| 2,2 | +1,1 / +2,3 / +7,9 | 158,9 / 207,4 / 78,9 |
| 3,2 | +0,9 / +2,3 / +7,8 | 158,9 / 207,4 / 78,9 |
| 4,5 | +1,6 / +2,6 / +8,2 | 158,8 / 207,2 / 79,2 |

**Lectura.** Cuadruplicar el contraste apenas devuelve la separacion al punto en que estaba SIN rampa.
El azul es plano (~8 en todo el barrido) y ya estaba ahi antes: viene del albedo del pino, no de la rampa.
Lo unico que crece con el contraste es el brillo general (copa 125 -> 131). A 4,5 empeora a ojo: los pinos
se aplanan y se van a amarillo, porque casi toda la superficie se satura al lado iluminado. La hierba sale
identica en las cinco, como debia.

**Conclusion.** El contraste no es el limite. El limite es el ambiente: `LUZ_SOL = 1.0` contra
`LUZ_AMBIENTE = 0.6` con `Color(0.95, 0.94, 1.0)` casi blanco en `prueba_test2.gd`. En sombra el ambiente
es el 100 % de la luz que recibe una superficie, asi que el termino tintado del `light()` queda en un
15-18 % y no puede verse. **El ambiente hemisferico (D) no es la secuela de B: es su precondicion.**

Queda en el codigo el contraste base en 1,2 (sin cambiar) y la rampa puesta pero sin efecto visible,
a la espera de atacar el ambiente. Lo que si se arreglo: `amb_sombra` y `amb_sombra_pers` ahora guardan
los dos en sRGB y convierten al subir, asi que los dos setters piden el color en el mismo espacio.
