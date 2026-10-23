# Plan · «Bosque 01 v01»: el Bosque 01 con la forma abierta de Echoes of Wisdom

24/10/2026 · propuesta de diseño para que **Pablo la revise** antes de tocar nada. No cambia ningún archivo del juego.

Parte de las decisiones de Pablo del 23/10 (`PLAN_BOSQUE_EOW.md` §9):
1. mapa nuevo con la forma abierta;
2. el cuello del campamento se quema y se cierra detrás;
3. la llave pequeña sale del cofre del campamento;
4. sin temperatura;
5. la Cueva es una sección secundaria con su boca en este mapa.

Fuentes:
- **El nivel de partida.** `mundo/datos_nivel/mapas/Bosque_01.txt` (52 × 44), `Nivel_Bosque_01.tscn` (marcadores por nombre), `escenas/bosque_01_3d.gd` y `escenas/PruebaBosque01.tscn`.
- **La gramática de las piezas.** `escenas/puzle.gd` y `presentacion/zonas_3d.gd`.
- **Las medidas de EoW.** `docs/estudios/eow/EOW_2_NIVELES.md` §1.4 y §6, y `EOW_1_TABLAS.md` §3 y §4.
- **Las calidades de cofre.** `PLAN_PULSO_RESONANTE.md` §7.

Coordenadas en casillas `(columna, fila)`, como en `; pieza`. **De EoW se toman las ideas, no los mapas.**

---

## 1. Qué tiene hoy el Bosque 01

Un mapa de **52 × 44** casillas pintadas. El núcleo de 28 × 28 del 16/10 tiene alrededor las ramas de `tools/ampliar_bosque_01.py`.
Las reglas son de `bosque_01_3d.gd` y los puzles de agua y de las cámaras son líneas `; pieza`/`; puzle`. No hay líneas `; zona`.

```
fila  1– 21  LINDE (oeste)    x 1–3: inicio S (2,21); telaraña r (2,12), que corta la franja; goblin W (2,5)
             ARROYO           x 6, filas 1–13 (agua ~); el tronco-puente (7,5) cae al oeste sobre (6,5)
fila  1– 10  CAMPAMENTO PEQ.  x 7–10: tienda goblin t (10,1)(10,2), cofre_01 (10,4) con el glifo barrera, telaraña (9,3)
fila  1–  5  CLARO DEL NE     x 13–26: patrulla W (19,3) + A (23,2) + A (23,4) → cofre_03 (25,1). El sendero de la fila 3 sigue al este
fila  7–  9  NICHO TF_2       tótem de fuego j (19,8) con los braseros T (18,9)(19,9); losa del estanque (16,9)
fila 10– 21  PRADO            x 9–20: cauce c en la columna 16 (estanque, tronco (16,14)), TF_3 (17,19) con las antorchas
                              (19,13)(17,16)(17,11)(19,17) en orden, alquimista Q (13,19), setas s (10,14)(10,18), lobernos (9,14)(9,18)
fila 11– 20  SANTUARIO        x 22–26 tras la puerta X (21,15): elemental G (25,15), cofre_02 (26,15) = fin de la demo
fila 21– 26  NICHO TF_1       x 18–19: hierba alta v y el tótem (18,25) que despierta con el fuego que se contagia
fila  3– 28  SENDERO ESTE     x 30–31, con las telarañas (30,8)(31,8); hierba alta v (29–32, 16–18); lobernos (30,15)(31,19)
fila 29– 31  EXPLANADA        x 4–46, guerrero W (22,30)
fila 33– 42  CÁMARAS A–D      cuatro salas de fuego con trastienda y cofre (cofre_04…07)
```

**El recorrido hoy:**
- **Inicio:** linde (telaraña, el goblin), tronco-puente y campamento pequeño, donde está el cofre de la barrera.
- **Centro:** el prado, con los tres tótems, y de ahí la puerta X y el elemental.
- **Opcional:** el claro del NE, el sendero del este y las cámaras del sur.

**Lo que no encaja con la forma abierta:**
- **No hay regiones.** Toda la luz es la de la escena, y el claro, el prado y las cámaras se leen igual. EoW mezcla la luz por región:
  0,1 s en 239 regiones y 5 s en las 58 exteriores (`EOW_1_TABLAS` §3a).
- **No hay ningún cierre ni llave.** EoW concentra el combate en una sala que se cierra (`TagRoomLocker` + `TagCheckerWipeout`) y
  guarda la llave pequeña en un cofre (L_Dungeon001, sala 016; `EOW_2_NIVELES` §6).
- **No hay rompibles.** Una mazmorra L de EoW lleva 47 entre rompibles y empujables, ~2 por sala, y el botín sale según la región
  (`RegionItemDrop`).
- **La banda x 33–51, filas 0–27, está sin pintar:** son 17 × 28 casillas vacías.
- **El sendero del este es un tubo** de 2 casillas y 26 filas sin nada que decidir.
- **No hay un sitio para la Cueva.**

**Cosas del `.tscn` que no casan con el `.txt`** (el `.tscn` manda; hay que comprobarlas en el editor):
- falta `guerrero_02`: en el campamento de la linde solo queda `guerrero_01` (2,5);
- `puerta_01` tiene el centro en z = 37,97, que cae en la casilla (21,16), y el `.txt` la tiene en (21,15);
- `telarana_02` cae en (1,12), y el `.txt` la tiene en (2,12);
- **no hay tinaja (`u`) en el Bosque 01:** la tinaja es del `Nivel_Bosque` (el pasillo). Este plan no la usa.

---

## 2. Qué conserva y qué cambia

**Se conserva**, en las mismas casillas y con los mismos nombres de marcador, porque son el contrato con `bosque_01_3d.gd`:
- el arroyo y el tronco-puente;
- el prado con el estanque, la losa y el tronco;
- **los tres tótems de fuego**, cada uno con su criterio;
- la puerta X con sus tres lámparas, el elemental y el cofre final;
- el alquimista;
- el claro del NE;
- el sendero del este con las telarañas y la hierba alta;
- las cuatro cámaras de fuego;
- la explanada.

Todas las líneas `; pieza`/`; puzle` de hoy (estanque y cámaras A–D) pasan tal cual al mapa nuevo.

**Cambia:**

| qué | cómo | por qué (EoW) |
|---|---|---|
| **Regiones con luz** | 18 líneas `; zona` con 9 regiones exteriores (mezcla 5 s) y 9 salas (≤ 1 s) | `Region.mBlendTime`: 5 s fuera, 0,1 s dentro (`EOW_1` §3a) |
| **Campamento cerrado** | sala nueva de 12 × 10 en la banda vacía del este: se quema la puerta goblin del cuello y al entrar se cierra detrás, con 4 goblins | `TagRoomLocker` + `TagCheckerWipeout` (`EOW_2` §1.5) |
| **Llave pequeña** | el cofre que aparece al limpiar el campamento; abre el nicho del tercer tótem (TF_1) | llave pequeña en cofre y puerta con llave (`EOW_2` §6); «la puerta grande quiere algo de cada ala» |
| **Atajo desde dentro** | dentro del nicho de TF_1, un pulsador abre una puerta al pasillo nuevo (fila 24) que va al sendero del este | contigüidades y atajos que se abren desde dentro (`EOW_2` §1.4, §6) |
| **Boca de la Cueva** | hondonada nueva de 12 × 9 en la banda del este, con la boca, Marimanta y una pared que suena | `SensorLevelOpen` + `TagAreaStart`; los «Vacíos» del campo apuntan a una mazmorra (`EOW_1` §3a) |
| **Dos paredes que suenan** | `pared_hueca` con un cristal que late al lado: se ven y se oyen antes de tener el pulso | contenido condicionado por flag (`CrackRegion`, `EOW_1` §3a) |
| **30 rompibles** | jarrones y cajas por región, con botín por región | 47 rompibles por mazmorra; `RegionItemDrop`, con P(nada) de 0,5 a 0,94 (`EOW_1` §4a) |
| **Menos enemigos sueltos** | de 10 a 12, pero 4 en la sala cerrada; fuera quedan 1–2 por región, todos evitables | 0,6 enemigos por sala, el combate concentrado (`EOW_2` §6) |
| **NPC nuevos** | goblin leñador (`goblin_base`), elfo (`elfo_base`), Marimanta (`marimanta`); goblin asesino en la hierba alta | — |

**Medidas de sala.** EoW tiene salas de 12–18 × 9–16 casillas (mediana ~15 × 13).
- **Cumplen:** el campamento (12 × 10), la hondonada (12 × 9) y el prado (12 × 12).
- **Se quedan pequeños:** los nichos de los tótems (2 × 5, 6 × 3) y el santuario (5 × 10); ver §9.

---

## 3. El plano por regiones

**Tamaño:** 52 × 44, el mismo marco que el Bosque 01. Las casillas nuevas están en la banda vacía:
- el campamento, el nicho del eco y la hondonada, en x 33–47, filas 0–24;
- el pasillo del atajo, en la fila 24, x 20–29;
- el escondite, en x 13–16, filas 22–27.

```
 x:  1     6 7  10 12              26 28  31 32 34 35            46 47
y 1  ┌──────┬─────┬───────────────────┬──────┐  ┌──────────────────┐
     │      │ S1  │ R3 CLARO NORTE    │      │  │ S5 CAMPAMENTO    │
     │  R1  │TALA │ W (19,3) A (23,2) │      │  │ (sala cerrada)   │
y 5  │LINDE ▒◀tronco═ sendero fila 3 ═╪══╗   │y▶▌ 3 W + 1 A, torre │
     │      │goblin   ┌TF_2┐          │  ║R4 │  │ cofre: LLAVE     │
y10  │arroyo├──┬──────┴────┴─────┬────┤  ║HIER│  └────────┬─────────┘
     │ x 6  │  │ R2 PRADO        │ S4 │  ║BA  │    ┌─ nicho eco ─┐ épico
y15  │      │  │ estanque, TF_3, X SAN│  ║ALTA│    └──── H1 ─────┘
     │ telar│  │ alquimista, elfo│TUA-│ asesino ├▶ R5 HONDONADA
y21  │  S   │  │   ▼ llave(18,21)│RIO │  ║    │    Marimanta · BOCA ▶ CUEVA
     └──────┘  └──┬─┬S3 TF_1┬────┴────┘  ║    │  └──────────────────┘
y24            │  │ │ hierba ◀═ atajo (20,24) ═╣
y27            │  │ escondite (H2)           ║
y29  ═════════ R6 EXPLANADA ═══ cristal (13,29) · eco (14,28) ══╝
y33–42         cámaras A · B · C · D (fuego)
```

`▒` es el tronco-puente, `y▶` la puerta goblin del cuello, `▌` el cerrojo, `X` la puerta de los tótems y `▼` la puerta con llave.

### Las regiones y las salas

**Exteriores** (mezcla 5 s, rompibles, enemigos sueltos, sin cofres de puzle salvo los de hoy):

| región | dónde (casillas) | qué se resuelve | elemento | enemigos | botín y rompibles | NPC | luz |
|---|---|---|---|---|---|---|---|
| **R1 · La linde del arroyo** | x 1–11, filas 1–21 | quemar la telaraña (2,12); derrotar al goblin (2,5), que da el cofre_01 (barrera, como hoy); quemar el tronco-puente (7,5) para cruzar el arroyo | fuego | 1 W (`guerrero_01`) | 4 jarrones; cofre_01 | — | `bosque` 5 s |
| **S1 · La tala** (dentro de R1) | x 7–10, filas 1–6 | rincón tranquilo tras el arroyo: el goblin leñador y el cofre de la barrera | — | — | 2 cajas | **goblin leñador** | (la de R1) |
| **R2 · El prado del estanque** | x 9–20, filas 10–21 | la losa sube el estanque y el tronco; TF_3 (secuencia); la puerta con llave (18,21) a la vista | fuego, agua | 1 loberno (`loberno_01`) | 5 jarrones | alquimista Q (13,19), **elfo** (20,14) | `agua` 5 s |
| **R3 · El claro del norte** | x 12–31, filas 1–5 | combate opcional y evitable (se puede ir por el sur); el cofre_03 sale al caer la patrulla, como hoy | — | 1 W + 1 A (`guerrero_03`, `arquero_01`) | 3 jarrones; cofre_03 | — | `bosque` 5 s |
| **R4 · La hierba alta** | x 28–33, filas 6–28, y el pasillo de la fila 24 | el sendero del este, sin la segunda telaraña ni el segundo loberno; la emboscada del asesino; las dos salidas al este (cuello y hondonada) | fuego | 1 loberno (`loberno_03`) + **goblin asesino** | 3 jarrones | — | `atardecer` 5 s |
| **R5 · La hondonada** | x 35–46, filas 15–23 (entrada (34,18)) | la boca de la Cueva (46,18); la pared que suena H1 (41,14) | (pulso) | — | 4 jarrones | **Marimanta** (44,20) | `ruinas` 5 s |
| **R6 · La explanada** | x 4–46, filas 28–32, y la bajada x 9–12, filas 22–27 | el pasillo hacia las cámaras; la segunda pared que suena H2 (14,28) | (pulso) | 1 W (`guerrero_04`) | 3 jarrones | — | `bosque` 5 s |

**Salas** (mezcla ≤ 1 s, un puzle o un cierre cada una):

| sala | dónde (casillas) | qué se resuelve | elemento | enemigos | botín | luz |
|---|---|---|---|---|---|---|
| **S2 · Nicho de las antorchas (TF_2)** | x 15–20, filas 7–9 | las dos antorchas a la vez, como hoy | fuego | — | — | `fuego` 1 s |
| **S3 · Nicho de la hierba (TF_1)** | x 18–19, filas 22–26 | **puerta con llave** (18,21); prender la hierba para que el fuego llegue al tótem (18,25); el pulsador (19,23) abre el **atajo** (20,24) | fuego | — | — | `fuego` 1 s |
| **S4 · El santuario** | x 22–26, filas 11–20 | la puerta X (tres tótems), el elemental y el cofre final, como hoy | combate final | 1 G | cofre_02 (épico) | `santuario` 1 s (pieza nueva; mientras tanto `ruinas`) |
| **S5 · El campamento goblin** | x 35–46, filas 1–10; cuello (32,5)–(34,5) | quemar la puerta goblin (33,5); al entrar se cierra el cerrojo (34,5) hasta que cae el último. Luego aparece el **cofre de la llave** (41,5) | fuego + combate | **A (43,3), W (38,3), W (40,8), W (44,8)** | cofre común (llave); 3 jarrones de campamento | `fuego` 1 s |
| **S6 · Nicho del eco (H1)** | x 40–42, filas 12–13 | la pared hueca (41,14) solo se abre con el pulso del jugador (ᚱ) | pulso | — | **cofre épico** (41,12) | `cueva` 1 s |
| **S7 · El escondite (H2)** | x 13–16, filas 22–27 | la pared hueca (14,28) de la explanada, que también pide el pulso | pulso | — | cofre común (14,24); 3 jarrones | `ruinas` 1 s |
| **Cámaras A–D** | filas 33–42, como hoy | los cuatro puzles de la flecha de fuego (F1, F4, F2, F3) | fuego | — | cofre_04…07 | `fuego` 1 s (la D, la del arroyo: `agua`) |

**El campamento por dentro** (x 35–46, filas 1–10):
- **Torre goblin** `o` en (44,3), con el arquero pegado al oeste (43,3). La torre arde y prende al arquero por contacto.
- **Fogata** `F` en (40,5), en el centro: da luz y prende lo que se acerca.
- **Decorado:** tres tiendas `t` (36,9) (37,9) (45,1); empalizada `x` por el borde oeste (x 35, filas 1–4 y 6–10), que deja libre la
  (35,5), delante del cerrojo; un estandarte `V` (41,2).
- **El cofre de la llave** aparece en (41,5), al lado de la fogata.

**El cuello** tiene 3 casillas de largo: (32,5) se abre en la pared del sendero, en (33,5) va la **puerta goblin** `y` (arde) y en
(34,5) el **cerrojo**.
- **Van en casillas distintas a propósito.** El cerrojo nace abierto y, al montarse, **libera** su casilla. En la casilla de la
  puerta goblin desharía su bloqueo: conviven dos estados de bloqueo (`ARQUITECTURA.md`, *Lo que cuesta*).

---

## 4. El recorrido y la misión

**Orden esperado** (el camino corto, sin opcionales):
1. **Inicio** S (2,21) → norte por la linde → quemar la telaraña (2,12).
2. **El goblin (2,5)** → aparece el cofre_01 con la barrera.
3. **El tronco-puente (7,5)** → la tala: el goblin leñador habla del campamento del este y de la llave.
4. **El prado** (bajando por x 8, filas 6–10):
   - el estanque;
   - **TF_2** (nicho de las antorchas);
   - **TF_3** (secuencia, con la pista del alquimista);
   - el elfo, junto a la puerta X, saluda y señala la **puerta con cerradura** (18,21).
5. **Al campamento**, por uno de los **dos caminos**: el bucle.
   - **Norte:** la tala → sendero de la fila 3 → claro del norte (patrulla evitable) → bajada por el sendero del este → cuello (32,5).
   - **Sur:** prado (11,21) → explanada (pasa por delante de la **pared que suena H2**) → sube por el sendero del este → la hierba
     alta con el **asesino** → se ve la hondonada y la **boca de la Cueva** por la abertura (34,18) → cuello (32,5).
6. **El campamento:** quemar la puerta goblin → entrar → se cierra → 4 goblins → se abre → **cofre con la llave**.
7. **Vuelta al prado.** El atajo de la fila 24 está cerrado y se ve desde el lado del sendero (20,24); hay que rodear.
   - Con la llave, la puerta (18,21) → el nicho de la hierba → **TF_1**;
   - el pulsador (19,23) abre el **atajo** (20,24) para siempre: el bucle este–prado queda corto.
8. **Puerta X** (tres tótems) → **elemental** → **cofre final** (fin del nivel).

**Bucles y atajos:**
- **El bucle grande:** prado → norte → campamento → sur → prado. Se hace en los dos sentidos.
- **El atajo de la fila 24** se abre **desde dentro** del nicho de TF_1 y une el sendero del este con el prado en ~12 casillas, en vez
  de las ~45 que hay rodeando por la explanada.

**Opcionales:**
- **La Cueva** (en cualquier momento después de llegar a la hondonada) → glifo **ᚱ** → la **pared H1**, a 5 casillas de la salida de
  la Cueva, da el cofre épico → la **pared H2** de la explanada da el escondite.
- El claro del norte (cofre_03), las cuatro cámaras de fuego (cofre_04…07) y los 30 rompibles.

**Cómo se ve la misión** (`Misiones`, misión `bosque_01_v01`; hace falta la copia del script, §7):

| # | objetivo | cuándo se marca |
|---|---|---|
| 0 | Cruzar el arroyo | el jugador pisa la tala (zona `linde`, x ≥ 7) |
| 1 | Abrir el cofre de la linde (glifo barrera) | cofre_01 abierto |
| 2 | Despertar los tres tótems de fuego (n/3) | como hoy |
| 3 | Conseguir la llave del campamento | flag `bosque01v1.campamento.llave` |
| 4 | Abrir la puerta de los tótems | como hoy |
| 5 | Derrotar al elemental · 6 Abrir el cofre final | como hoy |
| op. | El claro del norte · Las cuatro cámaras de fuego (n/4) | como hoy |
| op. | **La Cueva: el glifo del pulso** | flag `cueva.c6.glifo` |
| op. | **Las dos paredes que suenan (n/2)** | flags `bosque01v1.hondonada.eco` y `bosque01v1.explanada.eco` |

### La boca de la Cueva: dónde y por qué ahí

**La boca está en (46,18), al fondo de la hondonada (R5).** Se entra por la abertura (34,18) desde la hierba alta.

- **Se ve antes de poder usar lo que da.** Justo encima de la boca está la **pared H1** (41,14). El cristal (39,16) late cada 4 s y su
  pulso recorre la veta hasta la pared, que suena (`eco`) pero no se abre: la pared hueca solo se abre con el pulso del **jugador**.
  - **Antes de entrar:** el jugador ve y oye la pared que no puede abrir, y Marimanta se la señala.
  - **Al salir con ᚱ:** la tiene a 5 casillas. Es el primer uso en el Bosque, como la salida de C6 lo es dentro de la Cueva.
- **También se ve en el camino principal.** La **pared H2** (14,28), en la explanada, late igual (cristal (13,29)).
  - Quien va al campamento por el sur la ve **antes** de llegar a la boca.
  - Quien la ve después, al volver, recuerda «la otra pared que sonaba».
  - Es la misma lectura que la Cueva enseña en C6: vetas que llevan a una pared que suena.
- **Fuera de la ruta obligatoria, pero junto a ella.** La hondonada está a 2 casillas del sendero que lleva al campamento.
  - **Por el sur:** se pasa por delante.
  - **Por el norte:** no se ve hasta la vuelta.
  - Es opcional, como pide la decisión 5. Tampoco aparece en una ruta que se pueda saltar sin enterarse: en el sur se cruza siempre.
- **El ambiente cambia.** La luz `ruinas` (fría y verdosa) frente al `atardecer` de la hierba alta y al `fuego` del campamento: se
  nota el umbral sin rótulo. Con la pieza «entrada a zona una vez», el rótulo «La boca de la cueva» sale la primera vez.

---

## 5. Los NPC nuevos y el goblin asesino

Ninguno tiene letra de mapa todavía (`prueba_test2.gd`: el asesino «se crea con `_personaje(PJ_ASESINO, pos)`»; `goblin_base` y
`marimanta` no se colocan desde ningún mapa).
- **Cómo se colocan:** como **marcadores de datos** con nombre, igual que `loberno` o `tronco_estanque`. Las reglas del nivel los
  leen **por nombre** (como `_leer_marcas_por_nombre`).
- **Qué hace falta:** añadir los grupos `npc` y `asesino` a `Marcador3D.DATOS` y a la copia del script (§7).

Los diálogos van en la tabla del nivel, como `DIALOGO_ALQUIMISTA`.

| marcador | modelo | casilla | rutina | qué dice / qué hace |
|---|---|---|---|---|
| `npc_goblin_01` | `goblin_base` | (9,1), en la tala | **talar** mirando a un tocón (8,1) durante 6 s, `idle` 2 s, y vuelta a empezar. Si te acercas (≤ 2,7 u), para y te mira; E → `talk`. Con la flag `bosque01v1.campamento.limpio`, pasa a **cavar** junto a la tienda | Antes: «Mis primos del este cierran el campamento cuando entra alguien. La llave del viejo nicho la guardan ellos». Después: «¿Los has echado? Pues ahora busco lo que enterraron…» (una poción la primera vez). Es el aviso de que no todos los goblins son enemigos |
| `npc_elfo_01` | `elfo_base` | (20,14), junto a la puerta X | `idle`; la primera vez que el jugador entra a ≤ 4 casillas, **saludo** (una vez). E → `talk`. Al abrirse la puerta X, **celebrar** y andar (`walk`) 2 casillas hacia ella. Al caer el elemental, **celebrar** otra vez | Las pistas de los tótems: «El del sur duerme tras esa cerradura: la llave está en el campamento del este», «Las dos antorchas del norte, a la vez». Es el que hace legible la «puerta que quiere algo de cada ala» |
| `npc_marimanta_01` | `marimanta` | (44,20), en la hondonada, junto a la boca | `walk` lento (su andar de anciana) entre (43,20) y (44,21), y **pensar** 4 s en cada extremo. E → `talk` | Antes de la Cueva: «Esta piedra canta cuando el cristal late. Lo que la abre está ahí abajo, al fondo». Con `cueva.c6.glifo`: «¿Lo oyes ahora? Haz tú que suene». Con la H1 abierta: «Queda otra, junto a la explanada» |

El alquimista (Q, 13,19) se queda como está.

**El goblin asesino** (marcador `asesino_01`, casilla (31,17), en la hierba alta x 29–32, filas 16–18):
- **El encuentro.** Nace **dentro de la hierba alta**, entre el loberno (30,15) y la abertura de la hondonada (34,18).
  - Su andar agazapado lo esconde entre las matas.
  - Al ver al jugador (5,75 u) sale a por él con el ataque doble.
- **La lectura:** la hierba alta es peligrosa. Quemarla antes (fuego que se contagia, lo mismo que pide TF_1) lo deja al descubierto.
  Si está dentro cuando prende, sale ardiendo.
  - Ojo: el asesino pelea como el guerrero, así que **resiste el fuego**. Quemar sirve para verlo, no para matarlo.
- **Lo que no hace:** no tiene IA de sigilo. El «esconderse» es solo la hierba que lo tapa y su clip agazapado. Si se quiere que
  acose (una ruta de patrulla por la hierba), es una clave nueva del marcador (`ruta=`), fuera de este plan.

---

## 6. Densidades

| | EoW (`EOW_2` §6) | Bosque 01 hoy | **Bosque 01 v01** |
|---|---|---|---|
| **zonas** | 22 salas (L_Dungeon001) | 1 (sin `; zona`) | **18 zonas** (9 regiones exteriores, 9 salas) |
| **enemigos** | 14 (0,6 por sala), concentrados | 10 (`.tscn`), repartidos | **12**: 4 en la sala cerrada, 1 jefe, 7 sueltos (≤ 2 por región exterior; 0 en las salas de puzle) |
| **puzles** | ~1 por sala | 8 (3 tótems, estanque, 4 cámaras) | **12**: los 8 + campamento + llave/atajo + 2 paredes que suenan |
| **rompibles** | 47 (~2 por sala) | 0 | **30** (~1,7 por zona; casi todos en exteriores) |
| **cofres** | 8 (mapa, llave, llave del jefe, resto) | 7 | **10** |

**Rompibles por región** (pieza nueva `jarron`, §8):

| región | casillas | perfil de botín |
|---|---|---|
| linde | (3,14) (1,9) (3,2) (1,18) | `bosque` |
| tala | cajas: (7,6) (9,5) | `bosque` |
| prado | (9,12) (15,17) (12,20) (20,11) (20,20) | `bosque` |
| claro del norte | (14,1) (14,5) (26,5) | `bosque` |
| hierba alta | (28,13) (33,13) (33,20) | `bosque` |
| hondonada | (36,15) (46,15) (36,23) (46,23) | `ruinas` |
| campamento | (36,2) (36,3) (46,9) | `campamento` |
| explanada | (4,29) (27,29) (46,31) | `bosque` |
| escondite | (13,23) (16,23) (16,26) | `ruinas` |

**Perfiles de botín**, al estilo de `ItemDrop` (con «nada» explícito y el ingrediente local por región):

| perfil | nada | oro | poción | ingrediente local |
|---|---|---|---|---|
| `bosque` | 60 % | 30 % (3) | 5 % | 5 % `flor_ardiente` |
| `ruinas` | 50 % | 35 % (5) | 5 % | 10 % `raiz_cenizas` |
| `campamento` | 30 % | 50 % (8) | 20 % | — |

Con poca vida, poción al 15 %, como el `mPinchKey` de EoW. Es opcional.

**Cofres por calidad** (`PLAN_PULSO_RESONANTE` §7):

| calidad | cofres | qué dan |
|---|---|---|
| **común** (madera) | cofre_01 (10,4)*, cofre_03 (25,1), cofre_04…07 (cámaras), `cofre_llave` (41,5), `cofre_escondite` (14,24) | la barrera*, oro, pociones, ingredientes, la llave pequeña |
| **épico** (piedra con vetas moradas) | `cofre_eco` (41,12), tras H1; cofre_02 (26,15), el final del elemental | un ingrediente de mejora del personaje (§10.4 del pulso; p. ej. la geoda) |
| **legendario** | ninguno en el Bosque: es el de C6 de la Cueva (glifo ᚱ) | — |

\* El cofre_01 da un **glifo** (la barrera) y, según §7, los glifos son legendarios. Es una de las preguntas (§10).

---

## 7. Las líneas del mapa

Van en `mundo/datos_nivel/mapas/Bosque_01_v01.txt`, después de copiar **tal cual** las líneas `; azar_suelo`, `; giro` y todas las
`; pieza`/`; puzle` de `Bosque_01.txt`: el estanque y las cámaras A–D.

**Ojo con `Puzle3D`:** una línea con una clave que la pieza no tiene se **ignora entera** con un AVISO («la pieza X no tiene la clave Y»).
Por eso cada pieza nueva va en dos versiones:
- **la de hoy**, que funciona ya;
- **la de la pieza nueva**, comentada con `;;` hasta que exista.

`Zonas3D`, en cambio, ya **acepta y descarta** las claves que no conoce (`mezcla=`, `id=`, `titulo=`, `botin=`). Lo único que
rechaza es una luz que no existe (`santuario`).

```
; Bosque_01_v01 (24/10): el Bosque 01 con la forma abierta de EoW. docs/PLAN_BOSQUE_01_V01.md. 52 × 44, mismas casillas que Bosque_01.
; --- ZONAS (Zonas3D). Exteriores mezcla=5; salas mezcla=1. Si se pisan, manda la última: las grandes primero ---
; zona 1,1..11,21 bosque mezcla=5 id=linde titulo=La_linde_del_arroyo botin=bosque
; zona 12,1..31,5 bosque mezcla=5 id=claro_norte titulo=El_claro_del_norte botin=bosque
; zona 28,6..33,28 atardecer mezcla=5 id=hierba_alta titulo=La_hierba_alta botin=bosque
; zona 20,24..28,24 atardecer mezcla=5 id=hierba_alta
; zona 9,10..20,21 agua mezcla=5 id=prado titulo=El_prado_del_estanque botin=bosque
; zona 3,28..47,32 bosque mezcla=5 id=explanada titulo=La_explanada botin=bosque
; zona 9,22..12,27 bosque mezcla=5 id=explanada
; zona 34,15..46,23 ruinas mezcla=5 id=hondonada titulo=La_boca_de_la_cueva botin=ruinas
; zona 15,7..20,9 fuego mezcla=1 id=nicho_antorchas
; zona 18,22..19,26 fuego mezcla=1 id=nicho_hierba
; zona 22,11..26,20 ruinas mezcla=1 id=santuario titulo=El_santuario
;; zona 22,11..26,20 santuario mezcla=1 id=santuario titulo=El_santuario      (pieza nueva: preset «santuario»; sustituye a la de arriba)
; zona 32,1..46,10 fuego mezcla=1 id=campamento titulo=El_campamento_goblin botin=campamento
; zona 40,12..42,13 cueva mezcla=1 id=nicho_eco
; zona 13,22..16,27 ruinas mezcla=1 id=escondite
; zona 4,33..12,42 fuego mezcla=1 id=camara_a
; zona 14,33..28,42 fuego mezcla=1 id=camara_b
; zona 31,33..39,42 fuego mezcla=1 id=camara_c
; zona 42,33..50,42 agua mezcla=1 id=camara_d
; --- S5 · CAMPAMENTO (sala cerrada). La puerta goblin «y» (33,5) es una letra del plano (arde); el cerrojo va en la casilla de DENTRO ---
; pieza cuello cerrojo 34 5 celdas=34,5 sala=35,1..46,10 hasta=bosque01v1.campamento.limpio
; pieza guardia vigia 35 1 de=35,1..46,10 flag=bosque01v1.campamento.limpio
; puzle abre_cuello cuando=guardia.todos_derrotados hace=cuello.abrir
; pieza cofre_llave cofre 41 5 aparece_si=flag.bosque01v1.campamento.limpio abierto=bosque01v1.campamento.llave
;; pieza cofre_llave cofre 41 5 aparece_si=flag.bosque01v1.campamento.limpio abierto=bosque01v1.campamento.llave da=llave_pequena:1   (pieza nueva: da=)
; --- S3 · NICHO DE LA HIERBA (TF_1): puerta con llave y atajo que se abre desde dentro ---
; pieza puerta_tf1 puerta 18 21 modelo=llave
; puzle con_llave cuando=flag.bosque01v1.campamento.llave hace=puerta_tf1.abrir
;; pieza puerta_tf1 puerta 18 21 modelo=llave llave=bosque01v1.campamento.llave flag=bosque01v1.tf1.puerta   (pieza nueva: llave= y flag=; sustituye a las dos de arriba)
; pieza boton_atajo pulsador 19 23 modo=presencia
; pieza atajo_tf1 puerta 20 24
; puzle abre_atajo cuando=boton_atajo.pulsado hace=atajo_tf1.abrir y=flag.poner(bosque01v1.tf1.atajo)
; puzle atajo_recordado cuando=flag.bosque01v1.tf1.atajo hace=atajo_tf1.abrir
; --- R5 · HONDONADA: la boca de la Cueva y la pared que suena (H1) ---
; pieza latido_h1 cristal 39 16 cada=4
; pieza veta_h1 veta 40 16 celdas=40,16..41,16+41,15
; pieza eco_h1 pared_hueca 41 14 flag=bosque01v1.hondonada.eco
; pieza cofre_eco cofre 41 12 modelo=epico abierto=bosque01v1.hondonada.cofre
;; pieza cofre_eco cofre 41 12 modelo=epico abierto=bosque01v1.hondonada.cofre da=geoda:1                      (pieza nueva: da=)
;; pieza boca_cueva salida 46 18 escena=PruebaCueva entrada=boca modelo=boca_cueva                              (pieza nueva)
;; pieza desde_cueva entrada 45 18 mira=o                                                                         (pieza nueva)
; --- R6 · EXPLANADA: la segunda pared que suena (H2) y el escondite ---
; pieza latido_h2 cristal 13 29 cada=4
; pieza veta_h2 veta 14 29
; pieza eco_h2 pared_hueca 14 28 flag=bosque01v1.explanada.eco
; pieza cofre_escondite cofre 14 24 abierto=bosque01v1.escondite.cofre
;; pieza cofre_escondite cofre 14 24 abierto=bosque01v1.escondite.cofre da=oro:30+seta_asada:2                  (pieza nueva: da=)
; --- ROMPIBLES (pieza nueva «jarron»; botin=zona toma el perfil de la zona en la que está cada casilla) ---
;; pieza jarrones_linde jarron 3 14 celdas=3,14+1,9+3,2+1,18 botin=zona
;; pieza cajas_tala jarron 7 6 celdas=7,6+9,5 modelo=caja botin=zona
;; pieza jarrones_prado jarron 9 12 celdas=9,12+15,17+12,20+20,11+20,20 botin=zona
;; pieza jarrones_claro jarron 14 1 celdas=14,1+14,5+26,5 botin=zona
;; pieza jarrones_hierba jarron 28 13 celdas=28,13+33,13+33,20 botin=zona
;; pieza jarrones_hondonada jarron 36 15 celdas=36,15+46,15+36,23+46,23 botin=zona
;; pieza jarrones_campamento jarron 36 2 celdas=36,2+36,3+46,9 botin=zona
;; pieza jarrones_explanada jarron 4 29 celdas=4,29+27,29+46,31 botin=zona
;; pieza jarrones_escondite jarron 13 23 celdas=13,23+16,23+16,26 botin=zona
```

**Notas sobre las líneas que ya funcionan:**
- **El cerrojo.**
  - `sala=` no incluye la casilla del cerrojo (34,5), como pide `CerrojoPuzle`.
  - La celda de la puerta goblin (33,5) queda fuera de la sala: pisarla no cierra nada.
  - Con `hasta=`, una partida cargada con la sala limpia nace abierta.
- **El vigía.** Su rectángulo `de=` es la sala entera: cuenta a los 4 goblins por su casilla de partida (`casa`).
- **El cofre de la llave.** Con `aparece_si=flag.…` sobrevive a recargar, como dice el ejemplo C3 de `puzle.gd`.
- **La puerta con llave, hoy.** Es la regla de la Cueva (`con_llave`): se abre sola en cuanto se abre el cofre, aunque el jugador esté
  en el campamento. Funciona, pero no se lee como llave (§8).
- **El atajo.**
  - **Orientación:** `atajo_tf1` (20,24) tiene paredes al norte y al sur, así que `PuertaPuzle` la gira sola (paso este–oeste);
    `puerta_tf1` (18,21) tiene paredes al este y al oeste y queda sin girar.
  - **Al recargar:** con `y=flag.poner(…)`, `atajo_recordado` lo vuelve a abrir. `cuando=flag.…` también salta al cargar una
    partida que trae la flag.
- **Las paredes que suenan.** Copian el montaje de C6 de la Cueva: la veta acaba junto a la pared y el cristal, que es el dueño del
  pulso y no el jugador, solo saca el `eco`.
- **Los nombres de las flags** siguen `nivel.sala.hecho`. `bosque01v1.*` es este mapa; `cueva.*` es la Cueva, y se leen las dos.

**En la Cueva** (`Cueva.txt`), cuando exista la transición, hacen falta dos líneas. Este plan no toca ese archivo (pregunta 4):

```
;; pieza boca entrada 4 17 mira=n                                                       (donde aparece al entrar desde el Bosque: la S de hoy)
;; pieza a_bosque salida 4 18 escena=PruebaBosque01_v01 entrada=desde_cueva             (la salida de C1, una casilla al sur)
```

Con esto la Cueva queda como un bucle que empieza y acaba en C1: C6 → pared hueca (9,16) → C1 → salida (4,18) → Bosque (45,18).

---

## 8. Lo que el mapa espera de cada pieza nueva

Otro agente está construyendo estas piezas. Esto es lo que el mapa de arriba da por hecho, para que encajen sin tocar las líneas.

| pieza | claves (en el mapa) | comportamiento que espera el mapa |
|---|---|---|
| **Rompibles** `jarron` | `; pieza <id> jarron x y [celdas=<lista>] [botin=zona\|nada\|oro\|pocion\|<objeto>] [modelo=jarron\|caja]` | Un jarrón por casilla de `celdas` (sin `celdas`, solo en x,y). Bloquea su casilla mientras está entero. Se rompe con **cualquier** impacto de hechizo, explosión o empujón (como `Mundo3D.impacto`) y libera la casilla. `botin=zona` (por defecto) sortea con el perfil `botin=` de la zona donde está esa casilla, y fuera de zonas usa `bosque`. Señal `roto` (una por jarrón), condición `roto\|entero` (todos), acción `romper`. No se recuerda entre partidas (como en EoW, vuelven al recargar) |
| **Mezcla por zona** | `; zona … mezcla=<s>` | Los segundos que tarda la luz al **entrar** en esa zona (la región manda su `mBlendTime`). Sin clave, 1,5 s (`T_CAMBIO`, lo de hoy). Al salir de todas, la de la escena con 1,5 s. El zoom no cambia |
| **Preset `santuario`** | luz `santuario` en `; zona` | Una fila de `LuzZona3D.ZONAS` y de `ORDEN`: verdoso oscuro, con el sol verde pálido y débil (~0,6), el ambiente de arriba verde azulado oscuro y el de abajo musgo. Mientras no exista, la línea usa `ruinas` |
| **Entrada a zona una vez** | `; zona … id=<nombre> titulo=<Texto_con_guiones>` | La primera vez que el jugador entra en una zona con `titulo`, un rótulo de lugar (como `UiLocationInfo` y `RegionEntryDemo`) con los `_` cambiados por espacios. Pone la flag `<nivel>.<id>.visto` (`bosque01v1.campamento.visto`) y no vuelve a salir. Varias líneas con el mismo `id` son **una** región: el rótulo sale una vez y la región cuenta como una en el PlayLog. `Zonas3D.zona_cambio` debería llevar también el `id` |
| **Transición entre niveles** | `; pieza <id> salida x y escena=<Escena> entrada=<id en el otro nivel> [modelo=<pieza>]` · `; pieza <id> entrada x y [mira=n\|e\|s\|o]` | Al **pisar** la casilla de `salida` (no al aparecer en ella), fundido a negro y se carga `res://escenas/<Escena>.tscn`. Tiene que ser la escena y no solo el `nivel`, porque la Cueva necesita `estilo = "cueva"`, `agua_corre = false` y su `zona_luz`. El jugador aparece en la `entrada` con ese id, mirando a `mira`. Sin entrada (se abre la escena a mano, como un laboratorio), en la `S`. **Lo que debe sobrevivir al viaje:** flags, glifos (`Repertoire`), oro y objetos (`Estado`), vida y tinta. **Al volver, lo resuelto sigue resuelto** (ver Riesgos, §10) |
| **Puerta con llave** | `; pieza <id> puerta x y modelo=llave llave=<flag> [flag=<flag al abrirse>]` | Nace cerrada. Con E a ≤ 2,7 u: con la flag `llave` puesta se abre (logro `puerta_abierta`) y pone `flag`; sin ella avisa «Cerrada con llave» y no hace nada. Con `flag` ya puesta al montar, nace abierta. La llave no se gasta (hay una llave y una puerta). Con esta clave sobra la regla `con_llave` (aquí y en C6 de la Cueva). Si es fácil, que la llave se vea en el HUD mientras la flag está puesta y la puerta cerrada |
| **La zona en el PlayLog** | — | Cada evento de `PlayLog.event` lleva `zona` (el `id` de la zona, o su luz si no tiene `id`, o `""` fuera de todas) y `nivel`. Dos eventos nuevos: `zona_entra {zona}` y `zona_sale {zona, segundos}`. Con eso salen el tiempo por región, las vueltas a una ya resuelta y los hechizos por región (`PLAN_BOSQUE_EOW` §7) |

**Fuera de la lista del otro agente**, pero las pide el mapa. Son pequeñas:

| pieza | claves | comportamiento |
|---|---|---|
| **Botín del cofre** `da=` | `; pieza … cofre … da=<objeto>:<n>[+<objeto>:<n>…]` (`oro` es oro) | Al acabar de abrirse, da eso con `Estado.dar_oro`/`agregar` y el aviso del color de su calidad. Lo hacen hoy por código los cofres de `bosque_01_3d.gd` (`_dar_botin`) |
| **Vigía con la sala ya limpia** | — | Si la `flag` del vigía está puesta al montar, sus enemigos **no aparecen**. Si no, al volver de la Cueva habría 4 goblins vivos en un campamento abierto con el cofre ya cogido |
| **Marcadores `npc` y `asesino`** | marcador de datos, `grupo = npc` (`tipo = goblin_base\|elfo_base\|marimanta`) o `grupo = asesino` | En `Marcador3D.DATOS`. Los crea la copia del script del nivel: `_personaje(...)` y, para el asesino, `Combate3D.equipar`, como hace hoy `_crear_loberno` |

---

## 9. Qué hay que tocar en el `.tscn` y la escena nueva

**`mundo/datos_nivel/Nivel_Bosque_01_v01.tscn`** sale de copiar `Nivel_Bosque_01.tscn` (que conserva los retoques de Pablo). Lo que
cambia el **plano** se toca en el `.tscn`, porque manda sobre el `.txt`. Las líneas `;` se leen del `.txt` aunque el plano salga del
`.tscn` (`ARQUITECTURA.md`, *De dónde sale el plano*).

1. **Suelo (GridMap), las casillas nuevas:**

   | sitio | casillas | qué se pinta |
   |---|---|---|
   | cuello | (32,5) | `#` → `g` |
   | | (33,5) | suelo, con el marcador `y` |
   | | (34,5) | suelo (el cerrojo) |
   | | x 33 y x 34, filas 0–11 (salvo la fila 5) | `#` |
   | campamento | x 35–46, filas 1–10 | suelo `.` con un sendero `g` de (35,5) a (41,5) |
   | | x 47, filas 0–11; fila 0 y fila 11 | `#` |
   | nicho del eco | x 40–42, filas 12–13 | suelo |
   | | (41,14) | suelo (la pared hueca) |
   | | el resto de x 34–47, filas 11–14 | `#` |
   | hondonada | (34,18) | `#` → `.` |
   | | x 35–46, filas 15–23 | suelo (`.` y alguna `R` de piedra) |
   | | x 47, filas 14–24; x 33–34 y fila 24, de x 33 a 47 | `#` |
   | atajo | (29,24) | `#` → `g` |
   | | x 21–28, fila 24 | suelo |
   | | (20,24) | suelo (la puerta) |
   | | x 20–28, filas 23 y 25 | `#` |
   | escondite | x 13–16, filas 23–27 | suelo (`,` hierba corta) |
   | | x 13–16, fila 22 | `#` |
   | | (14,28) | `#` → suelo (la pared hueca) |

2. **Decorado (Piezas/Borde):**
   - **Quitar** los árboles y rocas de las casillas que pasan de `#` a suelo: (32,5), (34,18), (29,24), (20,24) y (14,28).
   - **Poner** decorado en las paredes nuevas: unas 90 casillas `#`, que en el editor no se rellenan solas (el relleno lo hace el
     horneado). Ver la pregunta 1.
   - **Campamento:** `tienda_goblin` (36,9) (37,9) (45,1), `empalizada_goblin` en x 35 (filas 1–4 y 6–10) y un estandarte (41,2).
   - **Hondonada:** el modelo de la boca de la cueva contra la pared este (47,18), de `PROMPTS_CUEVA.md` (mientras tanto, rocas
     grandes y un `arco_ruina`).
   - **La tala:** un tocón en (8,1).

3. **Marcadores** (por nombre: son el contrato con las reglas):
   - **Se añaden:**
     - `puerta_goblin_01` (`y`, 33,5), `torre_01` (`o`, 44,3), `fogata_01` (`F`, 40,5);
     - `arquero_03` (`A`, 43,3), `guerrero_05` (`W`, 38,3), `guerrero_06` (`W`, 40,8), `guerrero_07` (`W`, 44,8);
     - los marcadores de datos `asesino_01` (31,17), `npc_goblin_01` (9,1), `npc_elfo_01` (20,14) y `npc_marimanta_01` (44,20).
   - **Se quitan:** `loberno_02` (9,18), `loberno_04` (31,19), `arquero_02` (23,4) y `telarana_04` (31,8). Queda una sola telaraña
     en el sendero del este; quita una casilla de tubo y una espera.
   - **No se tocan:** los demás nombres (`cofre_01..07`, `totem_fuego_01..03`, `antorcha_01..04`, `brasero_01/02`, `guerrero_01/03/04`,
     `arquero_01`, `tronco_puente_01`, `tronco_estanque_01`, `loberno_01/03`, `elemental_01`, `puerta_01`, `alquimista_01`, `inicio_01`).
     Los goblins nuevos no están en `GOBLINS_COFRE_1` ni en `PATRULLA`, así que `bosque_01_3d.gd` no los cuenta para nada: solo el
     vigía.
   - **Comprobar** de paso `puerta_01` y `telarana_02` (§1).

4. **El `.txt`** (`mapas/Bosque_01_v01.txt`):
   - las filas de letras con estos cambios, para que coincidan con el `.tscn` y para poder hornear;
   - las líneas `;` de §7 debajo.

**`escenas/PruebaBosque01_v01.tscn`** es una copia de `PruebaBosque01.tscn` con `nivel = "Bosque_01_v01"` y los mismos `fuego_nuevo`,
`agua_fisica = true`, `kit = "pruebas"` y `zona_luz = "bosque"`. Lleva dos nodos hijos:
- **Reglas** (`bosque_01_3d.gd`), en dos fases:
  - **Fase 1:** el de hoy, sin cambios. Lee los marcadores por nombre del `.tscn` de su `nivel`, así que ya sirve: tótems, puerta X,
    elemental y cofres 01–07. El cofre_03 sale con la patrulla de dos.
  - **Fase 2:** una copia, `bosque_01_v01_3d.gd`, con la misión de §4, los tres NPC y el asesino (§5), los diálogos nuevos y lo que
    tenga que sobrevivir a la Cueva en flags (§10).
- **Puzles** (`puzle.gd`).

**Qué se puede montar ya y qué espera:**
- **Ya, con lo que hay:** las zonas (sin mezcla ni rótulo; el santuario con `ruinas`), el campamento entero, la puerta del nicho (con
  la regla provisional), el atajo, las dos paredes que suenan y los cofres sin `da=`.
- **Espera a las piezas nuevas:** los jarrones, la mezcla, el preset `santuario`, los rótulos, la boca de la Cueva, la puerta que pide
  llegar con la llave, el PlayLog con zona, el botín de los cofres y los NPC y el asesino.

---

## 10. Riesgos y preguntas para Pablo

**Riesgos:**
- **Volver de la Cueva.** Es el más grande. Cargar la Cueva y volver recarga el Bosque.
  - **Lo que sobrevive:** lo de `Puzle3D` va en flags (vigía, cerrojo, cofres, atajo, paredes huecas).
  - **Lo que no:** lo de `bosque_01_3d.gd` vive en variables (tótems encendidos, puerta X, cofres 01–07 entregados, elemental) y se
    perdería: los tótems apagados y los cofres otra vez llenos.
  - **Hay dos salidas:**
    1. la transición guarda el Bosque fuera del árbol y lo devuelve; los estáticos (`Terreno3D`) hay que volver a cargarlos, como ya se
       limpian al salir;
    2. la fase 2 pasa esos estados a flags (o a líneas `; puzle`, el paso 7 de `PLAN_BOSQUE_EOW` §9).

    La 2 es más robusta. Hasta tenerla, la Cueva se prueba sola en `PruebaCueva.tscn`.
- **El campamento puede «salirse».** Los goblins ven a 5,75 u: si el jugador quema la puerta desde fuera, el arquero o un guerrero
  pueden salir a por él antes de que entre, y la sala no se cierra con ellos fuera.
  - Lo cuenta el vigía igual, porque mira su casilla de partida, y vuelven a su puesto a más de 10 u.
  - Se pierde un poco de «sala cerrada», no se rompe nada.
- **Las paredes nuevas sin decorado.** Pintar `#` en el GridMap no pone árboles. Son ~90 casillas a mano en el editor, o hornear
  (pregunta 1).
- **El santuario sigue pequeño** (5 × 10, frente a las salas de 9–16 de fondo de EoW) y los nichos de los tótems son de 2 × 5 y 6 × 3.
  Se dejan así: el santuario está entre el prado (x 21) y la hierba alta (x 28) y crecer pide mover la puerta X.
- **La forma abierta es parcial.** Los senderos siguen siendo de 1–2 casillas (la linde, el sendero del este). Las regiones nuevas son
  anchas, pero el Bosque 01 se sigue leyendo como red de caminos. Es lo que hay que medir en el playtest (`PLAN_BOSQUE_EOW` §7).
- **La Cueva pide más que fuego:** tierra (C2), agua (C3) y hielo (C5). Con `kit = "pruebas"` se tiene todo, pero en una progresión
  real la boca tendría que llegar después de esos glifos.
- **El asesino no se esconde de verdad** (§5): sin IA de sigilo, la emboscada depende de que la hierba alta lo tape a la cámara a 60°.

**Preguntas para Pablo:**
1. **El `.tscn`:**
   - **(a)** Copiar `Nivel_Bosque_01.tscn` y abrir lo nuevo a mano en el editor. Se conservan tus retoques, pero hay que decorar unas
     90 casillas de pared.
   - **(b)** Hornear un `.tscn` nuevo desde `Bosque_01_v01.txt`, que pone el decorado solo, y copiar tus retoques de las zonas que no
     cambian. Es fácil porque son las mismas casillas.

   ¿Cuál prefieres?
2. **El cofre de la barrera** (cofre_01) da un glifo, y según `PLAN_PULSO_RESONANTE` §7 los glifos son **legendarios**. ¿Se queda
   como cofre común (es el tutorial) o pasa a `modelo=legendario` (sin la secuencia larga)?
3. **Al volver de la Cueva**, ¿vale que los enemigos **sueltos** del exterior vuelvan a estar, como en EoW, mientras lo resuelto
   (tótems, campamento, cofres) se queda resuelto?
4. **La entrada y la salida de la Cueva:** ¿se añaden las dos líneas al `Cueva.txt` de siempre (la `PruebaCueva` seguiría funcionando
   sola, porque sin entrada se aparece en la `S`) o se hace una `Cueva_v01`?
