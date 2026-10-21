# Hechizos que se sienten poderosos: cast points + reacción de enemigos (17/10/2026, Juego)

Sustituye la versión de esta mañana. Pablo (20:11): «que los hechizos se sientan poderosos incluso los básicos»,
por dos cauces: **mejor cast point** (desde dónde sale el hechizo, con VFX de anticipación) para tres posiciones con
al menos dos variaciones cada una, y **enemigos que reaccionen al menos el doble**.

## 0. Veredicto: se puede, con una cosa que falta

Se puede hacer todo con lo que hay en disco **salvo una pieza técnica** (§2.3: sujetar el libro con una mano mientras
la otra lanza, porque los clips son a dos manos) que se resuelve en código sin assets nuevos. Lo único que pediría
assets es si se quieren más de dos variaciones por posición o clips a una mano «de verdad» (§5, opcional).

## 1. Lo medido

**Clips de lanzar del héroe** (`arte/modelos/woodland_wanderer.glb`, cinemática directa sobre el esqueleto Mixamo;
alturas en unidades de cadera→cabeza, «frente» = +Z del modelo; instante = fracción del clip):

| clip | dura | manos arriba | manos abajo | manos al frente | cadera | lectura |
|---|---|---|---|---|---|---|
| MageSoellCast003 | 2,29 s | **+2,04 @0,36** | — | **izq +1,24 @0,68** (der +0,43) | quieta | alza y lanza con UNA mano (la izquierda) |
| MageSoellCast001 | 3,33 s | +1,02 @0,19 | — | **+1,44 @0,46** las dos | quieta | empuje al frente a dos manos |
| ChargedSpellCast001 | 4,33 s | +0,90 | — | **+1,57 @0,51** | quieta | empuje cargado (largo) |
| MageSoellCast002 | 2,21 s | +1,37 @0,14 | — | +1,49 @0,27 | quieta | brazos que se abren (muro hoy) |
| ChargedSpellCast002 | 2,71 s | **+1,97 @0,68** | — | +1,30 @0,88 | 0,44–0,80 | brazos al cielo (columna hoy) |
| ChargedGroundSlam | 3,00 s | +1,78 @0,47 | **−0,82 @0,63** | — | **baja a 0,22** | sube y golpea el suelo |
| CollectObject | 6,00 s | — | **−0,33 @0,66** | +0,98 @0,31 | **baja a 0,20** | se agacha y deja algo (trampa) |

Hoy solo se usan cuatro (`Pj3D.ANIM_CAST`: proyectil, corro, columna, muro); el resto de formas cae en `leer`.

**El libro:** se lleva en la **mano izquierda** (`Pj3D.libro_en_manos`, BoneAttachment en `LeftHand`) y al lanzar
**se devuelve al cinto** (`lanzar()` llama a `libro_en_manos(false)`). Es lo contrario de lo que pide Pablo.

**El disparo:** sale por reloj y por elemento (`RETARDO_CONJURO`, fuego 0,45 s), sin relación con el fotograma del
clip, y siempre desde la mano o el origen fijado con el ratón.

**Empuje de enemigos** (`enemigos/combate_3d.gd`): velocidad inicial = `FUERZA_POR_ELEMENTO × 2,3/64 × 0,1` y decae
con `lerp(…, 7·dt)`, así que recorre ≈ v₀/7. Con casilla = 2,3 u:

| elemento | fuerza | recorre hoy | ×2 |
|---|---|---|---|
| rayo | 400 | 0,21 u = **0,09 casilla** | 0,18 casilla |
| hielo | 300 | 0,15 u = 0,07 casilla | 0,13 |
| fuego | 500 | 0,26 u = **0,11 casilla** | 0,22 |
| agua | 600 | 0,31 u = 0,13 casilla | 0,27 |
| tierra | 2200 | 1,13 u = 0,49 casilla | 0,98 |
| viento | 2600 | 1,34 u = 0,58 casilla | 1,16 |

Los básicos empujan **una décima de casilla**: no se ve. Además el clip `hit` se salta si el goblin está aturdido,
el destello dura 0,10 s y no hay pausa de impacto. El elemental recibe ×0,15.

## 2. Cast points

### 2.1 Modelo de datos (por posición y variación, no por elemento)

`magia/cast_points.gd` (`CastPoints`, nuevo, Juego):

```
"x_mano":   {clip, inicio, fin, instante, origen: "mano_libre", sostener, anticipacion: [runa, voluta, forma]}
```

- `inicio`/`fin`: recorte del clip (0–1), para usar trozos (CollectObject entero dura 6 s).
- `instante`: fracción del clip recortado en la que nace el hechizo.
- `origen`: `mano_libre` (la que no lleva el libro), `manos_alto` (punto medio de las dos manos), `suelo_delante`
  (a los pies, una casilla hacia donde se apunta), `destino`.
- `velocidad`: del clip (hoy `VEL_CAST` 1,6 para todos).
- El elemento escala el tiempo total (rayo ×0,6, tierra ×1,3), como ya expresan las diferencias de `RETARDO_CONJURO`.

### 2.2 Las seis variaciones de partida (valores medidos, a afinar en el lab)

| posición | id | clip | recorte | instante | origen | qué formas lo usan |
|---|---|---|---|---|---|---|
| **1. Eje X** | `x_mano` | MageSoellCast003 | 0,40–0,85 | ≈0,62 (pico de la mano izq.) | mano libre | flecha, línea, bola, chorro |
| | `x_empuje` | MageSoellCast001 | 0,25–0,65 | ≈0,52 | manos al frente | flecha cargada, onda |
| **2. Se eleva** | `alto_cielo` | ChargedSpellCast002 | 0,30–0,85 | ≈0,69 | manos alto → nace en el suelo delante | pilar, columna, levitación |
| | `alto_alza` | MageSoellCast003 | 0,10–0,45 | ≈0,74 (pico arriba 0,36) | manos alto → suelo delante | muro, altura |
| **3. Hacia abajo** | `abajo_golpe` | ChargedGroundSlam | 0,35–0,80 | ≈0,62 | suelo (a los pies / delante) | barrera, corro, pulso |
| | `abajo_deja` | CollectObject | 0,45–0,80 (×2,5) | ≈0,60 | suelo delante | trampa, retardo |

Tabla `forma → id` en el mismo archivo; Pablo la cambia en el lab.

### 2.3 Lo que falta: el libro en la otra mano

Todos los clips son a dos manos salvo MageSoellCast003. Para «libro recogido en una mano, la otra lanza» hace falta:

1. **No devolver el libro al cinto al lanzar** (`Pj3D.lanzar` deja de llamar a `libro_en_manos(false)`; lo cierra y lo
   encoge, pero sigue en la mano) y **devolverlo al acabar** (`soltar_lanzar`).
2. **Mano del libro según la variación:** MageSoellCast003 lanza con la izquierda, así que en `x_mano`/`alto_alza` el
   libro pasa a la **derecha**. Campo `mano_libro` en el cast point.
3. **Brazo del libro quieto:** un `SkeletonModifier3D` propio (Godot 4.3+, el proyecto va en 4.7.2) que, después de la
   animación, mezcla los huesos del brazo del libro (hombro, brazo, antebrazo, mano) hacia una pose fija «libro
   recogido al pecho» con peso 0,8–1. La pose se saca de un fotograma de `Readandwrite` (ya en el GLB). Sin esto el
   libro atraviesa el hechizo en los clips a dos manos. Es código del Juego (`jugador/`), no necesita assets.

### 2.4 El laboratorio

`laboratorios/LabCastPoint3D.tscn` + `lab_cast_point_3d.gd` (patrón del lab de agua). Sala 9×9, jugador en el
centro, tres dianas (frente a 4 casillas, un poste a 2 para lo que sube, un círculo en el suelo para lo que baja) y
dos goblins quietos para ver el empuje.

- Cámara lateral fija (tecla para la de juego), cámara lenta 0,25× (`L`), paso a paso (`.`).
- Barra del clip recortado con el fotograma actual, marca del `instante` y franjas de anticipación; nombre real
  del clip.
- **Cast point desplazable:** el punto de origen se ve como un aro y se mueve con las flechas (offset local respecto
  a la mano/suelo, en u); `Q/A` instante, `W/S` sostener, `Z/X` recorte, `E/D` reparto de la anticipación, `M` cambia la
  mano del libro, `Tab` siguiente variación, `1–6` elige variación, `Espacio` lanza, `G` guarda en
  `user://cast_points.json`, `P` imprime la tabla para volcarla al `.gd`.
- Medidas al disparar: desfase instante↔fotograma (objetivo ≤ 1 fotograma) y distancia mano–origen (≤ 0,15 u con
  origen en mano); PlayLog `castpoint`.
- Panel de **reacción de enemigos** (§3) con sus multiplicadores en vivo, para ajustarlos en el mismo sitio.

### 2.5 VFX de anticipación

El nodo ya existe: `ConjuroVfx3D` (Pipeline) dibuja voluta y «forma» en los tiempos de `conjuro_fase`. Lo que cambia:
la «forma» debe crecer **en el cast point** (mano libre, sobre la cabeza o un círculo en el suelo) y durar hasta el
`instante`. El Juego añade el punto: `conjuro_fase(fase, elemento, posicion)` ya lleva posición; se le pasa la del
cast point en vez de la mano. Sin cambio de firma.

## 3. Reacción de enemigos (×2 como mínimo)

En `enemigos/combate_3d.gd` (Juego), todo con constantes para el panel del lab:

- `MULT_EMPUJE` = **2,0** sobre todas las fuerzas (fuego pasa de 0,11 a 0,22 casillas; viento a 1,16). Recomiendo
  además un **suelo** para los básicos: ningún golpe con daño empuja menos de 0,35 casilla (≈ 0,8 u), porque ×2 sobre
  0,09 sigue sin verse. Elemental: de ×0,15 a ×0,3.
- **Pausa de impacto** (hit-stop): 50–70 ms del goblin golpeado (su `_process` se congela; no el mundo), 90 ms si es
  débil al elemento.
- **Destello** de 0,10 a 0,20 s, blanco puro, y **aplastamiento** del modelo (escala 1,25 × 0,8 → 1 en 0,15 s).
- **Clip `hit` siempre** (hoy se salta si está aturdido) y un pequeño **salto** vertical (0,25 u) con viento y tierra.
- **Interrupción** de su ataque con cualquier golpe con daño (hoy 0,3 s), 0,6 s.
- Cámara: el `_temblor` de `Vfx3D` (Pipeline) ya existe; pedir que acepte intensidad por golpe para usarlo en
  débil/crítico.

## 4. Reparto

**Pablo — antes de empezar:**
1. ¿La tabla de seis variaciones de §2.2 vale como punto de partida?
2. ¿Suelo de empuje de 0,35 casilla para los básicos, o solo ×2?
3. Confirmar archivos nuevos: `magia/cast_points.gd`, `laboratorios/LabCastPoint3D.*`, `herramientas/prueba_cast_points.gd`
   (Juego) y el modificador del brazo en `jugador/brazo_libro_3d.gd` (Juego).

**Juego — T-CP1 (cast points + lab):**
> `magia/cast_points.gd` con el modelo de §2.1 y las seis variaciones de §2.2; `Pj3D`: `lanzar(id)` con recorte,
> velocidad y `fraccion_clip()`, libro que se queda en la mano (`mano_libro`) y `jugador/brazo_libro_3d.gd`
> (SkeletonModifier3D, pose sacada de Readandwrite); `Lanzador3D`: dispara en el `instante` del clip (reloj de
> `RETARDO_CONJURO` como respaldo si no hay clip) y emite `conjuro_fase` con la posición del cast point; laboratorio
> de §2.4. Prueba sin ventana `herramientas/prueba_cast_points.gd`: con cada variación, el disparo a ±1 fotograma
> del instante, origen donde se pide, sin clip igual que hoy; regresión `prueba_conjuro_vfx` y `escenario_libro` a 0.

**Juego — T-CP2 (reacción de enemigos):**
> `combate_3d.gd`: `MULT_EMPUJE` 2, suelo de empuje, elemental ×0,3, hit-stop por enemigo, destello 0,2 s,
> aplastamiento, `hit` siempre, salto con viento/tierra, interrupción 0,6 s; todo en constantes leídas por el panel
> del lab. Prueba: distancia recorrida por elemento ≥ 2× la de hoy (tabla de §1) y ≥ suelo.

**Pipeline — T-CP3 (VFX):**
> (a) `ConjuroVfx3D`: la «forma» crece en la posición de `conjuro_fase` (que ahora será el cast point) y se adapta al
> origen: orbe en la mano libre (eje X), columna de luz que sube sobre la cabeza (se eleva), círculo rúnico en el suelo
> que se cierra (hacia abajo). (b) `Vfx3D._temblor(intensidad)` público para golpes fuertes. (c) Destello de impacto en
> el enemigo (chispa/estrella del elemento, 0,1 s) si no basta con el del Juego.

**Pipeline — T-CP4 (opcional, solo si dos variaciones se quedan cortas):**
> Clips a UNA mano con la otra sujetando un libro (Mixamo o Meshy, mismo esqueleto): lanzar al frente, invocar hacia
> arriba, señalar/golpear al suelo. Medir cadera < 0,3 alturas como con los actuales.

**Pablo — después:** afinar en el lab, `G` para guardar, «vale» para volcar la tabla al `.gd`.

**Opción una mano en el lab (añadido 17/10 20:36, Pablo de acuerdo):** cada variación lleva `clip_una_mano` (vacío
por defecto; relleno → se usa ese clip y el modificador del brazo se apaga). Teclas del lab: `B` modificador on/off,
`C` fuente «original + modificador» / «una mano» (gris «sin clip (T-CP4)» si no hay), `V` valoración de Pablo
(bien / rígido / sin fuerza) → PlayLog `castpoint_valoracion`. T-CP4 se lanza solo para las posiciones que Pablo
marque como rígidas, no los tres clips de golpe.

Orden: T-CP2 primero (rápido, se nota al instante), después T-CP1 y T-CP3 a la vez.

— Juego
