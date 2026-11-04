# Recoger cosas del suelo y lanzarlas (4/11/2026)

Encargo de Pablo: «Implementa recoger cosas del suelo y lanzarlas. Básate en cómo se hacen las animaciones en Echoes of Wisdom.»
**Actualización 4/11 (clips de Meshy):** la pose ya no es procedural sino de clips reales (§2a); la capa `BrazosCarga3D` queda solo de respaldo. Las tablas de abajo (§1, §2b) son el diseño y el estado de antes; los tiempos vigentes están en §2a.
Código: `jugador/cargar_objeto_3d.gd` (`CargarObjeto3D`), `jugador/brazos_carga_3d.gd` (`BrazosCarga3D`, la pose por capa de respaldo), `objetos/rompible_3d.gd` (`al_coger`, `al_soltar`, `romper_lanzado`).
Prueba: `herramientas/prueba_recoger_lanzar.gd`. Capturas: `herramientas/captura_recoger_lanzar.gd` → `docs/capturas/recoger_lanzar/`.

## 1. Referencia: cómo lo resuelven los Zelda

**Honestidad sobre las cifras.** No he podido medir fotogramas de Echoes of Wisdom (EoW): lo que sigue es lo que se ve jugando y los tiempos que pidió Pablo en el encargo (~0,3 s para agacharse y coger). Los tiempos de abajo
son un punto de partida a afinar a ojo, no medidas del juego de Nintendo.

La mecánica es la misma en A Link to the Past (SNES), Link's Awakening (Game Boy y remake de Switch) y EoW (Zelda, vista de arriba/inclinada):

| Fase | Qué se ve | Duración aprox. | Notas |
|---|---|---|---|
| 1. Acercarse | Se anda hasta pegarse al objeto. La acción aparece en el HUD («Coger» / «Levantar»). | — | Sin lock-on: vale lo que tengas delante, a una casilla. |
| 2. Agacharse y coger | Baja el cuerpo, las dos manos al objeto, lo agarra en el fondo de la agachada. | ~0,3 s hasta agarrarlo | No se cancela a media agachada (recuerdo, no verificado). |
| 3. Alzar | Se levanta y sube el objeto sobre la cabeza con los brazos casi rectos, sujeto con las dos manos. | ~0,3 s | El objeto va de las manos a sobre la cabeza; el cuerpo se echa un poco atrás por el peso. |
| 4. Andar cargando | Andar normal pero más lento, con el objeto arriba; sin correr, sin rodar/esquivar, sin atacar, sin hechizos / ecos (recuerdo: con las manos ocupadas no se invoca). | ×0,5–0,75 de la velocidad normal según peso (estimado) | El clip de andar es propio (brazos en alto), no el normal con el objeto pegado encima. |
| 5. Lanzar | Anticipación corta (el objeto va atrás), suelta hacia delante en la dirección de la mirada y remate con los brazos al frente. | ~0,1 s de anticipación; ~0,3 s hasta poder andar | Arco corto de 3–4 casillas (lo pide Pablo). El vuelo sube y cae, no es una recta. |
| 6. Impacto | Al tocar el suelo o chocar con algo se rompe (jarrones, cajas, hierba: con trozos y a veces botín) o rebota/queda en el suelo (piedras sueltas). Si toca a un enemigo le hace daño y lo empuja. | — | Un jarrón roto suelta su botín de la tabla de la zona (rupias/corazones en los Zelda). |
| 7. Soltar sin lanzar | El mismo botón que coger no (lanza); se deja con el botón de cancelar/otro: baja el objeto y lo deja entero delante. | ~0,3 s | Pablo pide poder soltar sin lanzar (en algunos Zelda no se puede): aquí Q. |
| 8. Recibir un golpe cargando | El golpe tira lo que llevas: se cae al suelo y se rompe (jarrón) y Link/Zelda recibe el daño y el retroceso de siempre. | inmediato | El objeto roto no vuelve. |

### Decisiones para Magic Symbols

- **E coge y lanza** (la tecla de interactuar, `interactuar`), **Q suelta** (`usar_consumible`, que con el objeto en brazos NO bebe nada). El juego ya usaba E para cofres, puertas con llave, salidas, NPC y plantas: manda
  siempre la otra interacción; E coge un cogible solo si no hay nada de eso a mano (`CargarObjeto3D.hay_otra_interaccion`). La pista `[E] Coger` / `[E] Lanzar` sale por el detector de pistas que ya existía (`PistaProximidad`).
- **Qué se coge**: lo ligero y suelto del mundo (jarrones y cajas hoy). Se marca por datos: grupo `cogible` + metadato `cogible` = fila de `CargarObjeto3D.COGIBLES` (velocidad, alcance, daño, empuje, si rompe, altura y escala en brazos).
  Los bloques empujables, los cofres, las puertas y las plantas recolectables NO son cogibles (el bloque es de puzle; las plantas van a la bolsa).
- **Tiempos** (constantes de `CargarObjeto3D`): `T_FONDO` 0,33 s hasta agarrar (el clip `agacharse`, que dura 3,5 s, se reproduce ×5,3 y toda la agachada dura 0,66 s); `T_ANTICIPAR` 0,12 s; `T_REMATE` 0,28 s
  (andar otra vez a los 0,40 s de pulsar E); `T_SOLTAR` 0,28 s. Cargando: ×0,7 de velocidad (1,6 → 1,12 u/s). Vuelo: 12 u/s, arco de 1,1 u; jarrón 3,5 casillas (8,05 u), caja 3,2, piedra 3,0.

## 2a. Clips de Meshy integrados (4/11: ya NO es solo la capa procedural)

Pablo generó en Meshy los clips que pedía el §2b (la misma «Willow Fernstep» pasada a Mixamo que `jugadora_base`, 65 huesos, así que los huesos coinciden). Flujo, igual que con los de la elfa vieja:
`arte/meshy/clips_carga.py` (Python + numpy, como `clips_jugadora.py`) recorta y renombra los clips del GLB de Meshy (20 MB, con malla, **fuera del repo**) y `solo_clips.py` le quita malla, materiales y texturas →
`arte/meshy/jugadora_carga_clips.glb` (0,5 MB: esqueleto y seis clips). `ClipsFamilia.FUENTE_CLIPS_CARGA` los traduce al esqueleto (retarget en código) para `jugadora_base` (`FUENTES`) y los modelos de la elfa vieja (`EXTRAS`:
woodland_wanderer, chibi_elf…; esos últimos no se han mirado con ventana). Walking y Running no se importaron. Los instantes se miden con `arte/meshy/medir_clips_carga.py` (cinemática directa de los huesos; unidades del GLB, la jugadora de pie mide 1,68; en el juego ×0,625).

| Clip del GLB de Meshy | Rol (Pj3D.SINONIMOS) | Tramo usado | Dur. clip | Instante medido (`Pj3D.INSTANTE_CLIP`) | Velocidad en el juego → dura |
|---|---|---|---|---|---|
| `_01a1a760_…` quieta con las manos sobre la cabeza | `cargar_idle` (bucle) | entero | 2,97 s | — | ×1 |
| `_01a1a75f_…` anda con las manos arriba (arranca quieta ~1 s, avanza la cadera 0,75) | `cargar_andar` (bucle, en el sitio) | un ciclo de paso, 1,20–2,13 s | 0,93 s | — | ×0,8–×2,2 según la velocidad del suelo (`vel_clip_andar`) |
| `_01a1a757_…` manos sobre la cabeza, atrás y al frente | `lanzar_objeto` | 0,85–2,0 s | 1,15 s | suelta a **0,41 s** (pico de velocidad de las manos, 5,3 u/s del GLB, a 0,38–0,42 s) | ×2,28 → **0,50 s**; el objeto sale a los `T_SUELTA_CLIP` 0,18 s |
| `_01a1a75d_…` manos arriba, se agacha, deja el objeto y se levanta | `dejar_objeto` | 0,65–2,967 s | 2,32 s | objeto apoyado a **1,30 s** (manos a ≤ 2 cm de su mínimo desde 1,18 s) | ×3,8 → **0,61 s**; apoya a los `T_DEJAR_FONDO` 0,34 s |
| el MISMO clip al revés | `levantar` | 1,0–2,967 s invertido | 1,97 s | manos cerradas abajo a **1,05 s** (llegan a 0,62 s y se quedan hasta ~1,25 s) | ×3,2 → **0,62 s**; el agarre cae en `T_FONDO` 0,33 s |
| `Female_Crouch_Pick_Throw_Forward` | `coger_lanzar` (objetos ligeros) | 0,25–3,5 s | 3,25 s | agarre a **0,72 s** (mano derecha a 0,31) y suelta a **2,13 s** (pico 7,0 u/s) | ×2,7 → **1,2 s**; agarra a los 0,27 s, suelta a los 0,79 s |

- **Cadera de `dejar_objeto`/`levantar` a 1,02 en vez de 0,85:** no es un salto ni puntillas: TODO el cuerpo está 0,17 más alto que en los demás clips (los pies, a 0,30 en vez de 0,13 durante todo el clip: flota). Se corrige con `plantar`
  de `ClipsFamilia` (la suela más baja al suelo en cada fotograma, como `agacharse`). `levantar` empieza a medio levantarse (el clip acaba antes de ponerse del todo de pie) y la mezcla de 0,15 s lo absorbe.
- **`cargar_andar` y la zancada:** el andar de Meshy es de pasos CORTOS (0,41 u del GLB = 0,26 u del juego por ciclo de 0,93 s: 0,28 u/s de suelo a ×1) y el juego va a 1,12 u/s con carga (×0,7 de 1,6). Para no patinar haría falta ×4
  (ciclo de 0,23 s, un borrón de pies): se topa en ×2,2 (`VEL_CARGAR_MAX`), así que a ese tope los pies aún patinan ~×2 sobre el suelo. Arreglo de verdad: un clip de andar con zancada más larga, o menos velocidad con carga. No se ha visto con ventana.
- **Las manos NO llegan por encima de la cabeza** (medido en el juego, `prueba_recoger_lanzar` 3b): en `cargar_idle` las muñecas quedan a 0,92 u sobre los pies, el centro de la cabeza a 0,76 y la coronilla (`HeadTop_End` con los modificadores puestos, la cabeza a 0,80) a 1,00:
  por encima del centro de la cabeza (+0,16) pero 0,08 por debajo de la coronilla, y juntas (0,09 u). La pose de Meshy era para un cuerpo de proporciones normales y la cabeza grande de la chibi se come las manos. Andando, la coronilla baja a ~0,92 (se echa atrás) y las manos quedan a 0,89–0,91.
- **Escala del objeto en brazos: se queda en 0,60 (jarrón) y 0,65 (caja).** El objeto no puede ir literalmente «entre las manos» (el punto medio de las manos cae dentro de la cabeza): se coloca con la base a 0,95 u (0,03 sobre las manos, 0,05 bajo la coronilla: `HUNDE_EN_CABEZA` 0,08 como máximo) y a medio camino
  entre las manos y el eje de la cabeza (`EN_EJE_CABEZA`), como antes. Un jarrón al 100 % mide 0,5 u y taparía la cara; al 60 % (0,30 u) su base está a 0,95 y su tope a 1,25 u, por encima de la coronilla. Con el clip no hace falta más: no hay que bajarlo ni encogerlo más.
- **Cómo sigue el objeto las manos:** al coger va del suelo a la posición sobre la cabeza (la misma que antes: base 0,95); al lanzar baja de la coronilla a las manos según se echan atrás y salen al frente (`_f_cabeza` de 1 a 0) y sale de ahí; al dejar, de la coronilla
  a la casilla de delante; el objeto pequeño va en la mano DERECHA (centro del objeto en el hueso `RightHand`, medido a 0,00 u).
- **Objetos pequeños:** `COGIBLES[tipo].ligero = true` (la piedra) o, sin la clave, `alto ≤ UMBRAL_LIGERO` (0,36 u: una fruta de 0,2 sí; el jarrón, 0,5, y la caja, 0,4, no): E coge y lanza de una vez con `coger_lanzar` (`T_PEQUENO` 1,2 s) hacia donde mira al agacharse
  (la deja mirando al objeto). Hoy no hay piedras ni frutas sueltas en el mundo; la ruta está probada con un nodo suelto.
- **Respaldo:** si el modelo no trae alguno de los cinco clips de cargar (`CargarObjeto3D.tiene_clips()`), todo sigue como antes con `BrazosCarga3D` (probado quitando `levantar`). Un objeto ligero sin `coger_lanzar` se carga normal.

## 2b. Clips: qué había y qué se pidió (antes del 4/11)

Clips que ya tiene la jugadora (`jugadora_base`, que carga los de `chibi_elf.glb` más los de Meshy de `arte/meshy/clips_jugadora.py`; lista real del GLB: Idle, Idle002, Walking, Walk002, Running, RollDodge, MageSoellCast001-003, ChargedSpellCast001/002, ChargedGroundSlam, CastOneHandFront/Up/Ground, Readandwrite, FacePunchReaction (el `hit` y el `attack`), Dead, StandAndDrink, StandTalkingAngry, SwimForward, SwimmingToEdge, OpenDoor, CollectObject, y los de Meshy):
`agacharse` (Meshy, `Agacharse`, 3,5 s: se agacha con las manos juntas y se levanta; instante del fondo a 1,75 s, tabla `Pj3D.INSTANTE_CLIP`), `abrir_cofre`, `ofrecer`, `saludo`, `empujar`, y los tres casts a una mano.
El rol `pick_up` de `Pj3D.SINONIMOS` ("collectobject", "pick_up") **sí tiene clip**: `CollectObject` (Mixamo, 6,0 s, medido al cargar `jugadora_base`). Medido con los huesos de las manos (altura sobre los pies, a intervalos de 0,25 s): `CollectObject` baja hasta casi el suelo (manos a 0,12 u de 0,75 a 1,25 s), se queda abajo hasta ~3,5 s y se levanta a los 4,25 s; `agacharse` solo baja las manos a 0,37 u (agachada media, fondo a 1,75 s). Para un jarrón o una caja (se agarran por el costado, a 0,3–0,4 u) vale `agacharse` y es la que se usa; `CollectObject` quedaría para objetos a ras de suelo (piedras), recortada a ~0,6–3,9 s y acelerada, y no se ha usado.

| Necesito | ¿Hay? | Qué hago ahora |
|---|---|---|
| Agacharse y coger | Sí: `agacharse` (Meshy) y `CollectObject` (Mixamo, más profundo, 6 s). | Se reproduce acelerado (×5,3) para que su fondo caiga en 0,33 s; con él se agarra el objeto. |
| Alzar sobre la cabeza | No. | Capa procedural `BrazosCarga3D` (brazos hacia la pose `alzado`, columna atrás) que sube del 0 al 1 mientras se levanta el cuerpo del clip `agacharse`. |
| Andar cargando | No. | `walk` a ×0,7 + la misma capa (los brazos se quedan en alto aunque el clip los mueva). Quieta: `idle` + capa. |
| Anticipación, lanzar y remate | No. | Capa: pose `atras` (anticipación) → `adelante` (brazos estirados al frente) y vuelta al clip; la jugadora queda quieta ese rato. |
| Dejar en el suelo | No. | Capa: `alzado` → `bajo` mientras el objeto baja delante. |
| Recibir un golpe cargando | Sí: `hit`. | Se corta la capa en 0,18 s y suena `hit`; el objeto cae y se rompe. |

**Límite de la capa (y por qué conviene el clip de Meshy):** la jugadora es chibi. Con los brazos todo lo arriba que llegan, las manos quedan a 0,86 u sobre los pies y la coronilla a 1,00 u: **no puede sujetar el objeto de verdad
encima de la cabeza**. Se pone la base del objeto 0,08 u por debajo de la coronilla y a medio camino (en el plano) entre las manos y el eje de la cabeza; el jarrón se ve al 60 % de su tamaño en brazos (entero es casi tan alto como ella)
y vuelve al 100 % al soltarlo o romperse. Se lee bien como «lo lleva sobre la cabeza», pero las manos no tocan el objeto. Un clip real de Meshy resolvería la pose (brazos más arriba con el hombro y el torso, no solo el brazo).

### Clips nuevos propuestos para Meshy (para Pablo) — HECHO: ver §2a (los generó Pablo y ya están en el juego)

Todos sobre el esqueleto de `jugadora_base`, en el sitio (sin avance de cadera, como `agacharse`), los de bucle con el último fotograma igual al primero.

1. **`cargar_andar`** (bucle, ~1 s). Prompt: *"Chibi fantasy heroine walking slowly while carrying a heavy clay pot held high above her head with both hands, arms straight up and slightly forward, upper body leaning back a little, small careful steps, loopable walk cycle, in place."*
2. **`cargar_idle`** (bucle, 2–3 s). Prompt: *"Chibi fantasy heroine standing still holding a heavy clay pot above her head with both hands, arms extended up, slight weight sway, idle loop."*
3. **`levantar`** (una vez, ~0,7 s). Prompt: *"Chibi fantasy heroine crouches quickly, grabs a pot from the ground with both hands, stands up and lifts it above her head, arms fully extended, snappy cartoon timing, one shot."* (sustituiría el uso acelerado de `agacharse` y la subida procedural).
4. **`lanzar_objeto`** (una vez, ~0,5 s). Prompt: *"Chibi fantasy heroine holding a pot above her head throws it forward with both hands: quick wind-up leaning back, then a strong forward overhead throw with follow-through, arms ending pointing forward, one shot."* (instante de la suelta a ~0,12 s: anotarlo en `Pj3D.INSTANTE_CLIP`).
5. **`dejar_objeto`** (una vez, ~0,4 s, opcional). Prompt: *"Chibi fantasy heroine lowers a pot from above her head and sets it gently on the ground in front of her, bending her knees, one shot."*

Cuando estén, se sustituye la capa por estos clips (solo cambia `CargarObjeto3D.animar` y las llamadas a `_poner_pose`) y se afina el escalado en brazos.

## 3. Lo que no se hizo

- **Reacción con el mundo**: no existe un jarrón con agua ni nada parecido (solo la tinaja de la maqueta, que es un reactivo fijo), así que no se ha inventado ninguna reacción. Un jarrón roto suelta su botín por zona (`Rompible3D._soltar_botin`).
- **Bomba / seta explosiva / piedras sueltas / arbustos arrancables**: no existen como objetos sueltos del mundo (las `piedras` y `rocas_pequenas` son decorado; `piedra` de `fuentes.tsv` se recoge a la bolsa con E; `Geoda` explosiva es de puzle). La tabla `COGIBLES` ya trae la fila `piedra`
  (probada con un nodo suelto) para cuando existan.
- Un jarrón soltado en otra casilla vuelve a su sitio de origen si el nivel se recarga (la flag solo recuerda los rotos).
- La hoguera / brasero encendido (E abre su menú) no se mira como interacción prioritaria: hoy no hay jarrones junto a ellos.
