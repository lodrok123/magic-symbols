# Animales de cuatro patas: movimiento del CANOURO (hiena) y del LOBERNO (lobo) — 4/11/2026

Encargo de Pablo (4/11): «Quiero que revises personajes de tipo animal. Para el CANOURO usa de referencia el movimiento de una HIENA y para el LOBERNO (el lobo marrón) el movimiento de un LOBO. Primero compara y después ejecuta.»

Este documento recoge la **Fase 1 (comparar)** y el resultado de la **Fase 2 (ejecutar)** (§7). Aviso de método: las medidas de la Fase 1 se tomaron antes de implementar nada, pero el texto se cerró **después** de probar un primer prototipo de la capa (me adelanté a escribirlo antes: no se entregó la Fase 1 por separado). Rama `claude/pt-animales`. Todo lo medido sale de `herramientas/medir_animales.gd` (esqueleto muestreado clip a clip, sin ventana) y de `herramientas/prueba_marcha_animales.gd` (Combate3D real, 30 fps fijos). Las tiras de fotogramas están en `docs/capturas/animales/` (cámara del juego: ortogonal, inclinación 60°, el animal mira a la derecha; las rayas del suelo están cada 0,25 u).

**Qué vale cada número.** «u» = unidad del juego. Las alturas con que se midió: loberno 0,75 (la de `ALTO_PJ`), canouro 0,55 (la que ya cuenta `VfxCanouro3D`; no estaba en `ALTO_PJ`, que le daba 1,0 por defecto). Los valores de las dos referencias reales (hiena, lobo) son **los de la literatura de memoria y los que dio Pablo en el encargo, no medidos por mí**: sirven de dirección, no de tolerancia.

---

## 1. Qué hay

Los dos van sobre el esqueleto «Wolf» de 51 huesos (Meshy; `Body → Back → Torso → Torso2 → Torso3 → Neck1-3 → Head`, `FrontShoulder/UpperLeg/LowerLeg`, `BackShoulder/Leg/UpperLeg/LowerLeg`, `Tail1-8`, más controles IK `FF`, `FFB` y polos que **Godot no resuelve**: la malla va por los huesos FK).

| | LOBERNO (`emberheart.glb`) | CANOURO (`canouro.glb`) |
|---|---|---|
| Altura de juego | 0,75 (escala 0,256; cruz a 0,40 u, cabeza a 0,54) | 0,55 (escala 0,93; cruz a 0,29 u, cabeza a 0,40) |
| Clips (duración s) | 17: Idle 3,33 · Idle_2 3,33 · Idle_2_HeadLow 4,0 · Idle_Alt 41,6 · **Walk 1,07** · Walk_Alt 1,63 · **Creep 1,63** · **Gallop 0,57** · Run_Alt 0,67 · Gallop_Jump 0,93 · Attack 1,33 · Idle_HitReact1/2 0,67 · Jump_ToIdle 1,33 · Eating 2,53 · Sit 5,29 · Death 1,07 | 13: Idle 3,33 · Idle_2 · Idle_2_HeadLow · **Walk 1,07** · **Gallop 0,57** · Gallop_Jump 0,93 · Attack 1,33 · **Zarpazo 0,90** · Idle_HitReact1/2 0,67 · Jump_ToIdle 1,33 · Eating 2,53 · Death 1,07 |
| Lo que el juego usa hoy | `walk`=Walk, `run`=Gallop (`CLIPS_DE`), `idle`, `attack`=Attack, `hit`=Idle_HitReact1, `death`. **No usa** Creep, Run_Alt, Walk_Alt, Eating, Sit. | `walk`=Walk, `attack`=Attack, `hit`, `death`. **`run` no existe**: `CLIPS_DE` no lo mapea a Gallop y `jugar("run")` no hace nada (el modelo se queda en idle mientras avanza). `Zarpazo` solo lo pide el laboratorio. |
| Dónde sale como enemigo | `bosque_02_3d.gd` (`_crear_loberno`), `bosque_01_3d.gd`, `bosque_01_v01_3d.gd` | **En ningún nivel**: solo en `LabGato3D` (tecla M). Su lógica de enemigo es la genérica de `Combate3D`. |
| Lo decidido antes | DIARIO 49-56, 140: emberheart es el bueno; «pelea igual que un goblin» (`PROPUESTA_COMBATE.md`) | DIARIO 142-144: Zarpazo con VFX de garras en t = 0,40 s; `PLAN_RIGGING.md`: **«retarget de la hiena rechazado»** (21/10, «las formas se estiran»); los cuadrúpedos se hacen sobre «Wolf», no se traen clips de otro cuadrúpedo |

Consecuencia que importa: el canouro es un cuerpo «Wolf» con un Walk/Gallop heredados de un retarget de hiena que ya se rechazó; el loberno tiene tres clips que el juego no usa y que sirven (Creep, Run_Alt) .

---

## 2. Lo que hacen HOY (medido)

### 2.1 Velocidad, zancada, patinado

`Combate3D`: `VEL_PATRULLA` = 1,0 u/s (patrulla y `walk`), `VEL_PERSEGUIR` = 2,4 u/s (`run`); `v_base(clip)` solo distingue a los goblins (los que miden su zancada). El clip se reproduce a ×1, **sin relación con el avance**.

Velocidad del suelo que pisa el pie durante el apoyo (lo que haría falta avanzar para no patinar) a reproducción ×1, a la altura de juego:

| Clip | duración | pisadas/s a ×1 | avance sin patinar (u/s) | zancada (u por ciclo) | avance en juego | patinado |
|---|---|---|---|---|---|---|
| LOBERNO Walk | 1,07 s | 3,75 | **0,42-0,47** (delanteras 0,45; las cuatro 0,42) | 0,45-0,50 | **1,0** | pies **×2,2-2,4 más lento que el suelo** (los pies «corren en el sitio») |
| LOBERNO Gallop | 0,57 s | 7,06 | **2,0-2,3** (1,94 por IK; 2,06 en la prueba) | 1,1-1,3 | **2,4** | ×1,15-1,3 (casi bien) |
| LOBERNO Run_Alt (no usado) | 0,67 s | 6,0 | ≈1,4 (media de 4 patas; las delanteras son asimétricas) | 0,9 | — | — |
| LOBERNO Creep (no usado) | 1,63 s | 2,46 | ≈0,15-0,2 | 0,24 | — | — |
| CANOURO Walk | 1,07 s | 3,75 | **no hay apoyo coherente**: pie izq. −0,22…−0,33 u/s y der. +0,38…+0,49 en reposo de altura (una pata delantera avanza mientras está en el suelo) | ≈0,2-0,25 de recorrido | **1,0** | imposible de calibrar: el clip no es simétrico |
| CANOURO Gallop | 0,57 s | 7,06 | 1,5-1,85 (según pata) | 0,7-1,0 | **no corre** (sin mapa de `run`) | — |

Fases de las pisadas (0 = pata delantera izq.): Loberno Walk: delantera izq. 0, trasera der. ≈0,33, delantera der. 0,55, trasera izq. ≈0,83 = **andadura de cuatro tiempos (paso)**, no trote. Gallop: 0 / 0,20 / 0,67 / 0,75 = galope transverso. Canouro Walk: 0 / 0,18 / 0,24 / 0,90 (revuelto).

### 2.2 Postura (de los huesos, media a lo largo del clip)

Pendiente del lomo = ángulo de la línea grupa→cruz (hombros menos caderas) con la horizontal; **+ = delante alto**.

| | LOBERNO Walk | LOBERNO Gallop | CANOURO Walk | CANOURO Gallop |
|---|---|---|---|---|
| Pendiente del lomo | **−7,3°** (grupa más alta que la cruz) | −9,9° (−18° … −1°) | **−9,6°** | −11,6° |
| Cuello→cabeza (°) | +16° sobre la horizontal | +12° | +12° | +8° |
| Cabeza sobre la cruz | **+0,136 u** (34 % de la altura) | +0,122 | **+0,110** (39 %) | +0,100 |
| Cabeceo (p2p de la cabeza) | 0,015 u | 0,099 | 0,010 | 0,066 |
| Vaivén lateral de la cabeza (p2p) | 0,003 u | 0,039 | 0,000 | 0,024 |
| Balanceo de hombros (alt. izq-der p2p) | 0,004 | 0,005 | 0,003 | 0,003 |
| Rebote de grupa | 0,013 | 0,156 | 0,086 | 0,106 |

El loberno es un lobo con la grupa alta y la cabeza erguida; el canouro, igual, con el lomo **al revés que una hiena** (grupa más alta que la cruz) y **sin vaivén de cabeza ni hombros** en ninguno de sus dos clips.

Otros clips del loberno (sin usar): **Creep** (lomo +13°, cabeza a 12°, cruz a 0,372: es un acecho agazapado y despacio, el que falta), **Walk_Alt** (lomo +18°, cruz 0,51: una pose casi estática con la cruz muy alta, sin apoyo coherente), **Run_Alt** (galope recogido con suspensión, lomo −3,5°).

### 2.3 Giro, arranque y parada

* **Giro: instantáneo.** `Combate3D._animar` hace `pj.mirar(mirada, 0.05)`: un `lerp_angle` con factor `0,05·12 = 0,6` por fotograma de física (cierra el 84 % del ángulo en dos pasos, ≈ 1 fotograma a 30 fps). Medido (prueba, la jugadora cambia de lado 180° mientras persigue): ver §7.3 «antes». El animal además avanza **hacia el objetivo en línea recta** (`_dir_hacia`, A* si hay obstáculos), no por donde mira, así que no describe arcos.
* **Patrulla:** va y vuelve a lo largo de X ±2,0 u de su casilla (`DISTANCIA_PATRULLA`); al llegar al extremo `_direccion *= −1`: media vuelta en seco, a velocidad constante.
* **Arranque/parada:** sin aceleración: `moviendo` pasa de 0 a 1 o 2 y la velocidad es la nominal desde el primer fotograma; el clip entra con una mezcla de 0,15 s.

### 2.4 Conducta

Detecta a la jugadora a ≤ 5,75 u con línea de visión (aviso «!»), la **persigue en línea recta a 2,4 u/s**, y al entrar a 1,2 u (`RANGO_ATAQUE`; histéresis ×1,2) carga 0,6 s (`PREPARAR_GOLPE`, con el aviso `AvisoAtaque3D`) y suelta el clip Attack (1,33 s; golpe al 19 %), descansa 1,6 s y repite. Si la pierde 3,5 s o se aleja > 10 u, vuelve a casa andando (`walk` ×1,5). **No hay** acecho, zigzag, tanteo, retroceso, cerco, retirada tras el golpe ni huida: es la IA del goblin con otro modelo.

---

## 3. Referencia real

(De memoria de la literatura y de lo que dio Pablo; aproximado.)

**HIENA manchada.** Espalda **inclinada**: la cruz queda muy por encima de la grupa (≈ +10° a +15° de pendiente); patas delanteras más largas, traseras más cortas y flexionadas. **Cabeza baja y adelantada**, por debajo del nivel de la cruz al andar. Paso de **amblo/«lope»** balanceado y desgarbado: mucho **vaivén lateral de cabeza y hombros** sincronizado con la zancada (una vez por ciclo), tronco que se dobla de lado. **Trote cansino** que puede mantener mucho tiempo; **galope corto** en arrancadas. Conducta **oportunista**: se acerca en zigzag, se para, retrocede unos pasos y vuelve, rodea, ataca a mordiscos rápidos y se retira. Gira más torpe (cuerpo largo delante, pesado).

**LOBO.** Espalda **recta y nivelada** (≈ 0° ± 3°), cabeza **a la altura de la espalda o algo por debajo** cuando trota. **TROTE** eficiente de dos tiempos con **huella directa** (la pata trasera pisa donde pisó la delantera), **poco cabeceo**, cabeza estable. Galope **largo y estirado** para cazar. Conducta: patrulla al trote, **acecho** bajando cabeza y cuerpo antes de atacar, **persigue en arco** para cerrar el paso, **embestida corta**, **la cabeza siempre orientada a la presa**. Gira ágil.

---

## 4. Cuadro «hoy / referencia / qué cambiar»

### 4.1 LOBERNO ← lobo

| Aspecto | Hoy (medido) | Referencia lobo | Qué cambiar |
|---|---|---|---|
| Pendiente del lomo | −7,3° (trote) / −9,9° (galope): grupa alta | ≈ 0° nivelado | Capa procedural: sube el delantero (+7° → **+0,7°** medido) |
| Cabeza sobre la cruz | +0,136 u (34 % de la altura) | a la altura de la espalda o algo por debajo | Morro abajo al trotar (26° repartidos en cuello y cabeza): **+0,076 u** (−44 %) |
| Cabeceo / vaivén lateral | trote 0,015 / galope 0,099 u; lateral 0,003 / 0,039 | poco cabeceo, cabeza estable | Estabilizador: quita el 70 % del cabeceo y el 80 % del desvío lateral del clip |
| Andadura | Walk = paso de 4 tiempos a ×1 con **patinado ×2,3** (1,0 u/s contra 0,45) | trote de 2 tiempos, huella directa | **Clip nuevo** (trote diagonal). Con lo que hay: **Run_Alt a ×0,82** como trote rápido (1,15 u/s, 4,9 pisadas/s) |
| Velocidad patrulla / persecución | 1,0 / 2,4 u/s | trote eficiente y rápido / galope largo | 1,15 / 2,5 u/s; Gallop a ×1,25 sin patinar |
| Giro | instantáneo, recto hacia el objetivo | gira ágil, cierra en arco | ω máx 6,5 rad/s (±372°/s) y avanza por donde apunta (arco), más despacio en giros cerrados |
| Cabeza hacia la presa | no: mira donde mira el cuerpo | siempre a la presa | cuello y cabeza giran hasta ±70° respecto al cuerpo |
| Acecho | no hay (corre y pega) | baja cabeza y cuerpo antes de atacar | A 2,9-1,9 u de la presa: **Creep** a 0,32 u/s, agachado (+16° de cabeza), pausa 0,3 s, embestida ×1,25 0,7 s; enfriamiento de 6 s |
| Retirada / huida | no | (el lobo también se retira herido; no pedido) | sin cambios |

### 4.2 CANOURO ← hiena

| Aspecto | Hoy (medido) | Referencia hiena | Qué cambiar |
|---|---|---|---|
| Pendiente del lomo | −9,6° (grupa MÁS alta: al revés) | ≈ +10° a +15° (cruz muy alta) | Sube el delantero 13° y alarga las patas delanteras ×1,28 máx.: **−0,1°** medido (nivelado; **no llega** a +10° sin estirar más la malla: queda como propuesta de modelo/clip) |
| Cabeza sobre la cruz | +0,110 u | por debajo de la cruz, adelantada | Morro abajo 46° (la base del cuello también): **+0,008 u** (a la altura de la cruz) |
| Vaivén lateral de cabeza / hombros | 0,000 u; 0,003 | mucho, una vez por zancada | Giro lateral de cuello ±22°, del lomo ±6° (contrafase) y balanceo de hombros ±7°: vaivén lateral de la cabeza **0,045 u** andando y **0,062 u** corriendo (antes 0,000 y 0,018) |
| Andadura | Walk asimétrico (no se puede calibrar); **no corre** (`run` sin mapa) | amblo balanceado; trote cansino; galope corto | Mapear Gallop como correr (a ×1,42 para 2,2 u/s); Walk a ×1,33 para 0,6 u/s con el defecto del clip a la vista. **Clip nuevo** de lope/amblo y de andar simétricos (§6) |
| Velocidad patrulla / persecución | 1,0 / (no corre) | cansino / arrancadas cortas | 0,6 u/s cansino / 2,2 u/s con **arrancada** ×1,4 0,9 s |
| Giro | instantáneo | más torpe que el lobo | ω máx 3,6 rad/s (±206°/s), giro cerrado a ×0,5 |
| Conducta | recta y a pegar | zigzag, parada, retroceso, rodea, mordisco y retirada | **Zigzag** ±24° (cambia cada 0,9 s), **un tanteo** (a 4,6-2,6 u: para 0,4 s y retrocede 0,55 s a 0,45 u/s mirando a la presa), **arrancada** a ≤ 3,0 u, y tras morder **retirada** de 0,6 s hacia atrás. **No hace**: «rodear» (§8) |
| Cabeza hacia la presa | no | sí, con la cabeza baja | ±55° |

---

## 5. Qué se puede con los clips que hay

| Palanca | Qué consigue | Qué no |
|---|---|---|
| **Velocidad de reproducción por avance real** (`elegir`: v / zancada medida, ×0,45…×2,2) | quita el patinado del loberno (×2,3 → ×0,8-1,7 según el clip) y hace correr al canouro | no arregla un clip asimétrico (canouro Walk) |
| **Elegir el clip por velocidad** (Run_Alt como trote, Gallop como correr, Creep como acecho, estados `andar_marcha`/`correr_marcha`/`andar_acecho` del grafo reducido) | da al loberno un trote más lobuno y un acecho agazapado sin clip nuevo | Run_Alt es un galope recogido con suspensión, no un trote de dos tiempos |
| **Capa procedural sobre huesos** (`SkeletonModifier3D`: pendiente del lomo, base y cuello, cabeza, vaivén lateral, balanceo, estabilizador, mirada, agachado, longitud de pata delantera) | postura de lobo (nivelado, cabeza baja y quieta) y de hiena (delante alto, cabeza baja y adelantada, vaivén) | el **patrón de apoyo** de las patas (trote vs. amblo) no se cambia; el lomo de hiena (+10°) no se alcanza sin deformar la malla |
| **Mezcla / datos de conducta** (`PERFILES`) | acecho, embestida, zigzag, tanteo, retirada | rodear al jugador, flanquear, robar la espalda: exigen reescribir la IA (§8) |

## 6. Qué necesitaría un clip NUEVO de Meshy (no hecho: propuesta con prompt)

Todos sobre el esqueleto «Wolf» de 51 huesos, en el sitio (sin avance de cadera), en bucle, mismos nombres de hueso que `Walk`/`Gallop`.

1. **Loberno · TROTE de lobo** (el que más cambiaría la sensación): *«Gray wolf trotting, two-beat diagonal gait (left front + right hind together, then the opposite pair), direct registration (hind paw lands where the front paw was), level back, head carried low and steady at back level, very little head bob, tail low and straight, looping in-place cycle, 0.6 s per stride, quadruped Wolf rig.»*
2. **Canouro · AMBLO/«lope» de hiena**: *«Spotted hyena loping, sloped back with high withers and low hindquarters, head low and forward below shoulder height, pronounced side-to-side sway of head and shoulders once per stride, shambling relaxed gait, long front legs, looping in-place cycle, 0.9 s per stride, quadruped Wolf rig.»* (Sustituye al Walk asimétrico heredado del retarget; PLAN_RIGGING exige hacerlo **sobre el «Wolf»**, no traerlo de otro esqueleto.)
3. **Canouro · GALOPE corto de hiena** (para arrancadas): *«Hyena short bounding gallop, head low, rear end rolling, 0.5 s per cycle, quadruped Wolf rig.»* (hoy usa el Gallop del lobo.)
4. **Canouro · ACECHO / «Creep»** (el loberno ya lo tiene; el canouro no): *«Hyena stalking creep, belly low, head down and forward, slow 1.6 s per cycle, quadruped Wolf rig.»*
5. **Los dos · RETROCESO** (`walk_back`): *«Quadruped backing up slowly, facing forward, 1.2 s per cycle.»* Hoy se reproduce `Walk` a velocidad negativa (las patas se mueven hacia atrás con el cuerpo).
6. **Loberno · EMBESTIDA corta** (salto-mordisco de ~0,5 s) y **canouro · MORDISCO rápido** (el `Attack` de 1,33 s es largo para «mordiscos rápidos»).
7. **Canouro · modelo con la grupa baja** (si se quiere +10° de lomo de verdad): malla con los cuartos traseros más bajos, o pesos de hueso que admitan la capa sin estirar.

---

## 7. Resultado (Fase 2, medido)

Todo lo de abajo lo imprime `herramientas/prueba_marcha_animales.gd` (`FALLOS: 0`); «antes» = con `MarchaCuadrupedo3D.MARCHA_ANIMAL = false`.

### 7.1 Postura (esqueleto muestreado fotograma a fotograma, dentro del modificador)

| | lomo (°) | cabeza sobre cruz (u) | cabeceo de la cabeza (u) | vaivén lateral cabeza (u) |
|---|---|---|---|---|
| LOBERNO trote: antes → ahora | −7,3 → **+0,7** | 0,136 → **0,076** | 0,015 → 0,075 (Run_Alt, más movido que Walk; sin estabilizar sería 0,119) | 0,003 → 0,006 |
| LOBERNO galope | −9,2 → −5,4 | 0,125 → 0,099 | 0,099 → 0,063 | 0,039 → **0,004** |
| CANOURO andando | −9,5 → **−0,1** | 0,110 → **0,008** | 0,010 → 0,009 | 0,000 → **0,045** |
| CANOURO corriendo | −8,2 → −2,0 | 0,117 → **0,001** | 0,001 → 0,053 | 0,018 → **0,062** |

### 7.2 Pies y velocidades

| | antes | ahora |
|---|---|---|
| LOBERNO patrulla: clip y avance | Walk ×1,0 a 1,0 u/s (medido 0,98): el pie apoyado hace 0,43 u/s → **patina ×2,35** | **Run_Alt ×0,82** a 1,15 u/s nominales (medido 0,96 con las vueltas de la patrulla); 4,9 pisadas/s. Las patas delanteras del clip son asimétricas (izq. 1,76, der. −0,40 u/s): **AVISO, no contrato**; la media de las cuatro patas (medir_animales) da 1,12 u/s de pie para 1,15 de avance (×0,84-1,0) |
| LOBERNO persecución | Gallop ×1,0 a 2,4 u/s; pie 2,06 → **×1,16** | **Gallop ×1,25** a 2,5 u/s; pie 2,36 → **×1,06** |
| CANOURO patrulla | Walk ×1,0 a 1,0 u/s; pie 0,02: **no hay apoyo coherente** | Walk ×1,33 a 0,6 u/s nominales (medido 0,45): sigue siendo el Walk asimétrico (izq. −0,27, der. +0,52): **AVISO**, solo se arregla con un clip nuevo (§6.2) |
| CANOURO persecución | **no corre** (sin `run`) | **Gallop ×1,42** a 2,2 u/s; pie 1,83 → **×1,20** |

Patrulla medida en juego (jugadora lejos, 1,2 s): loberno **0,96 u/s** y canouro **0,45 u/s** (el lobo ≥ 1,5 × más rápido: la prueba lo exige) frente a **1,0 / 1,0** de antes. Persecución nominal 2,5 y 2,2 u/s; la arrancada del canouro sale a **3,08 u/s** durante 0,9 s. Tramo de patrulla en 14 s: ±1,13 u antes y ±1,15 u ahora (el mismo: lo limita el terreno de la prueba), con 6 vueltas el loberno y 3 el canouro (más lento).

### 7.3 Giro y conducta

| | antes | ahora |
|---|---|---|
| Giro del cuerpo (la jugadora cambia 180° de lado mientras persigue; ω máx del yaw) | **79 rad/s** (un fotograma) los dos | loberno **6,5 rad/s** (límite 6,5), canouro **3,6 rad/s** (límite 3,6): el canouro gira más torpe |
| Cabeza hacia la presa | no | con la presa a 60°: loberno 56°, canouro 51°; a 150° se queda en el límite (loberno 71° de 70°, canouro 61° de 55°) |
| Loberno · acecho | no | estados `acecho → pausa → embestida`; agachado = 1; clip Creep a **0,32 u/s**; primer ataque a los **4,9 s** de verla desde 4,6 u (antes ≈ 2 s, calculado: 3,4 u a 2,4 u/s más 0,6 s de carga; el acecho añade ≈ 2-3 s por primer contacto y se enfría 6 s) |
| Canouro · conducta | recta y a pegar | zigzag (4 cambios de lado), parada, retroceso a **0,42 u/s** de espaldas mirando a la presa (el clip Walk se reproduce con velocidad negativa: funciona), arrancada a 3,08 u/s, muerde a los 10,6 s (desde 6,9 u: no veía a la jugadora hasta acercarse), **retirada** hasta 2,06 u tras morder (estaba a 1,17 u) |
| Con `MARCHA_ANIMAL = false` | — | sin capa; `v_base` = 1,0 / 2,4; patrulla 0,98 u/s; el goblin guerrero sigue en 0,49 u/s (no lleva marcha) |

Fallo propio encontrado y corregido durante la prueba (anótalo quien toque `_patrullar`): con el giro suave, el extremo de la patrulla (`|x − casa.x| ≥ 2,0`) se cumplía mientras el animal aún giraba hacia fuera, así que `_direccion` se invertía cada fotograma y el animal **se escapaba de su tramo** (en `escenario_bosque_01_v01` un loberno acabó a 8 casillas de su sitio) o se quedaba atascado contra un obstáculo. Ahora, solo para animales con capa, la vuelta se da a 0,6 u antes del extremo, solo si va hacia fuera y como mucho cada 0,8 s (`MarchaCuadrupedo3D.permitir_vuelta`). Los goblins conservan la regla de siempre.

### 7.4 Qué se tocó

`presentacion/marcha_cuadrupedo_3d.gd` (nuevo: la capa, los perfiles y la conducta; `MARCHA_ANIMAL`), `enemigos/combate_3d.gd` (enganches: `_marcha`, `v_base`, `_actualizar_marcha`, la rama de persecución/vuelta/patrulla y `_animar`; todo con `_marcha != null`, así que los demás enemigos no cambian), `presentacion/prueba_test2.gd` (una línea: `ALTO_PJ["canouro"] = 0,55`), `herramientas/` (`medir_animales.gd`, `medir_animales_huesos.gd`, `captura_animales.gd`, `prueba_marcha_animales.gd`; `escenario_bosque_01_v01.gd` 5.25: cada loberno a ≤ 1 casilla de su marcador en vez de la casilla exacta, porque patrullan y la casilla dependía de la fase). **No se tocó** `pj_3d.gd`, `jugador_3d.gd` ni el resto de `prueba_test2.gd`.

Cómo ajustar sin tocar código de IA: todos los números (ángulos, velocidades, distancias de acecho, zigzag, tanteo…) están en `MarchaCuadrupedo3D.TIPOS` y `.PERFILES`.
## 8. Lo que queda como propuesta (no hecho)

* **Rodear / flanquear**: «el lobo persigue en arco para cerrar el paso» (adelantarse al movimiento de la jugadora) y «la hiena rodea» necesitan una IA de intercepción (punto de cierre calculado con la velocidad de la jugadora, como `_con_adelanto` del arquero) y una órbita alrededor del jugador. Se ha hecho solo la mitad que es por datos: el **arco** sale de limitar la velocidad angular del cuerpo y avanzar por donde apunta. No se ha reescrito la IA.
* **Mordisco corto** en lugar del Attack de 1,33 s, y **embestida** como salto: necesitan clip nuevo (§6.6) y que `_iniciar_ataque` acepte otra duración.
* **Huida** herido (hiena y lobo): sin pedir.
* **Canouro en un nivel**: no sale en ninguno; la conducta queda lista (`Combate3D` lo equipa solo con `Pj3D` id `canouro`) y `ALTO_PJ["canouro"] = 0,55`.
* **Walk simétrico del canouro** y su **lope** (§6.2): sin eso, andando despacio la hiena sigue patinando de una pata.



