# Plan · El Bosque y la Cueva al estilo de Echoes of Wisdom

23/10/2026 · propuesta para que **Pablo la revise** antes de tocar el mapa. No cambia ningún archivo del juego.

Fuentes: el estudio de niveles y tablas de EoW (`docs/estudios/eow/EOW_2_NIVELES.md` §1.4, §6, §7; `EOW_1_TABLAS.md` §3), el plan
visual (`docs/PLAN_EOW_VISUAL.md` §5) y el nivel tal como lo carga el juego hoy (`mundo/datos_nivel/Nivel_Bosque.tscn`, 19 × 49).
Coordenadas en casillas `(columna, fila)`, como las de `; pieza` y `; puzle`. **Regla de siempre: de EoW se toman las ideas, no los mapas.**

**Dos enfoques, dos sitios.** EoW alterna un campo ABIERTO (regiones, libertad, recompensa por explorar) con mazmorras CERRADAS (salas,
cierres, llaves, bucles). Para probar los dos sin mezclarlos:

- **El Bosque, enfoque abierto** (§1–§5): se reordena como un exterior por regiones con algunas salas de puzle dentro.
- **La Cueva, enfoque cerrado** (§6): una mazmorra pequeña nueva, de seis salas, con todo lo de una mazmorra de EoW (sala que se cierra,
  cofre con llave, puerta con llave, atajo desde dentro).

Con los dos se compara jugando qué funciona mejor con el sistema de hechizos (§7).

---

## 1. Qué tiene hoy el Bosque

Un **pasillo vertical** de 12 columnas jugables (x 1–12) y 47 filas, más el santuario del elemental a la derecha (x 14–17, filas 35–47).
La banda de x 13–18, filas 0–34, es roca maciza y no se usa.

```
fila  1– 9  ALTAR DE ARRIBA   tótem de agua k (1,1) tras la barrera de fuego B (columna 2, filas 1–6); tótem de fuego j (11,1);
                              4 antorchas T (10,4) (12,4) (10,8) (12,8) que encienden el tótem de fuego; hierba v en la columna 9
fila 10–16  CAMPAMENTO        arquero A (2,10), torre o (6,11), guerreros W (10,12) (2,14) (3,14)
fila 17     CUELLO            puerta goblin y (3,17) que se quema; pared de (7,17) a (12,17)
fila 18–28  PRADO             vacío salvo, abajo, la fuente eléctrica e (1,26), el codo L (2,26), la tinaja u (3,26) y el canal (2,27) (2,28)
fila 29–30  RÍO               de (1,29) a (7,30); se cruza por x 8–12
fila 31–47  RUINAS Y PRADERA  río vertical en x 7 con puente b (7,39); tótem de rayo i (8,36); guardabosques m (9,41); puerta X (13,39)
            FRANJA OESTE      x 1–3: inicio S (1,46), librera M (1,44), braseros de práctica T (1,42) (3,42) (1,43) (3,43), goblin W (2,34);
                              la telaraña r (4,33)–(4,35) la separa del cauce y detrás quedan las losas de agua a (5,33)–(5,35) (sello de agua)
            SANTUARIO         x 14–17, filas 35–47: elemental G (17,39), salida E (18,39)
```

La misión (`bosque_1`, `escenas/bosque_3d.gd`): iluminar las tres runas (fuego, agua y rayo) en sus tótems, abrir la puerta X, derrotar al
elemental y cruzar la salida.

**Lo que no encaja con EoW:**

- **Ida y vuelta de 40 filas.** Se empieza abajo (fila 46), las runas de fuego y agua están arriba (fila 1) y la puerta X en la fila 39.
  Tras el altar no hay atajo: se vuelve a bajar todo el pasillo.
- **Espacio sin propósito.** El prado (filas 18–25) son 8 filas vacías, y la banda este (x 13–18) está sin usar.
- **Todo es una sola «sala».** No hay umbrales que separen las partes ni respuesta al resolver cada una. La luz es la misma en todo el nivel.
- **La lógica está en código** (`bosque_3d.gd`) y no en líneas `; puzle` del mapa, así que cada cambio de diseño es tocar código.

## 2. Qué se toma de EoW

| idea de EoW | medida en EoW | aquí |
|---|---|---|
| **Salas de una pantalla** encadenadas | 12–18 × 9–16 casillas, ≈ 1 puzle por sala | 7 salas de 12 × 8–11 |
| **Pocos enemigos** | 0,6 por sala; el combate se concentra en una sala que se cierra (`TagRoomLocker` + `TagCheckerWipeout`) | 6 enemigos, 4 de ellos en una sala cerrada |
| **Centro con alas y atajos** | contigüidades y escaleras; atajos que se abren desde dentro | un centro, tres alas por elemento y un camino de vuelta |
| **La puerta grande quiere algo de cada ala** | llave del jefe en el cofre grande | la puerta X sigue pidiendo tres runas |
| **Llave pequeña en un cofre** | mapa, llave pequeña y llave del jefe en cofres distintos | cofre del campamento → llave del atajo |
| **El área elige luz y cámara** | `Region`: mezcla en 0,1 s dentro y 5 s fuera | `; zona` por sala (`Zonas3D`) |
| **El ambiente es jugable** | temperatura 0–4 por región | temperatura por zona (pieza nueva, §6) |
| **Mucho rompible pequeño** | 47 rompibles y empujables por mazmorra; botín según la región | jarrones y cajas con oro o poción (pieza nueva, §6) |

**Lo que NO cambia:** las tres runas, la puerta X con sus tres lámparas, el elemental, la tienda del guardabosques, el sello de agua tras
la telaraña ni el tamaño del mapa (19 × 49). Se reordena, no se rehace.

## 3. Las salas

```
        x: 1 ........ 12  13  14 .. 17
fila  1 ┌─ 6 ALTAR ──────┐   ┌──────────┐
        │  (fuego+agua)  │══▶│ 8 VUELTA │  ← atajo nuevo: muro agrietado en (13,5), se rompe desde el altar
fila  9 ├─ 5 CAMPAMENTO ─┤   │ (banda   │
        │  sala cerrada  │   │  este,   │
fila 17 ├── cuello (y) ──┤   │  hoy     │
        │  4 PRADO       │   │  roca)   │
        │  exterior      │   │          │
fila 28 ├── río ─────────┤   │          │
        │ 3 AGUA │ 2 CENTRO (ruinas)    │
fila 34 │ (oeste)│                ├─────┘  ← la vuelta baja hasta la antesala del santuario (15,34)
        │ 1 CLARO│      X (13,39) ┤ 7 SANTUARIO
fila 47 └────────┴────────────────┴──────────
```

| sala | dónde (x, filas) | qué se resuelve | elemento | luz (`; zona`) |
|---|---|---|---|---|
| **1 · Claro de la librera** | x 1–3, filas 40–47 | encender los dos pares de braseros de práctica (1,42)–(3,43) abre el paso al norte de la franja (hoy no cierran nada) | fuego (enseñar) | `bosque` |
| **2 · Ruinas del río (centro)** | x 5–12, filas 29–47 | punto de guardado, guardabosques con su tienda (glifo barrera), tótem de rayo (8,36) y puerta X (13,39). Desde aquí salen el ala del agua, el prado y, al final, la vuelta | — | `ruinas` |
| **3 · Ala del agua** | x 1–6, filas 31–39 | quemar la telaraña (4,33)–(4,35) para llegar a las losas a (5,33)–(5,35): sello de agua. El goblin W (2,34) se queda aquí, solo (el primer combate, sin cierre) | fuego → agua | `agua` |
| **4 · Prado (exterior)** | x 1–12, filas 18–28 | el puzle del rayo que ya hay: la tinaja u (3,26) vierte al canal (2,26)–(2,28) y el agua lleva la corriente de la fuente e (1,26) por el río hasta el tótem de rayo (8,36). En las filas 18–25, hoy vacías: rompibles y un claro con la segunda línea de antorchas (ver sala 6) | agua + rayo | `bosque`, mezcla lenta |
| **5 · Campamento (sala cerrada)** | x 1–12, filas 10–17 | al entrar se cierra el cuello (cerrojo en (1,17)–(6,17), que sustituye a la puerta goblin y); vigía con los 4 goblins A (2,10), W (10,12), W (2,14), W (3,14). Al caer el último se abre y aparece un **cofre** con la **llave pequeña**. La torre o (6,11) sigue ardiendo con fuego (quema el arquero de su lado) | combate | `atardecer` |
| **6 · Altar** | x 1–12, filas 1–9 | lo de hoy: las 4 antorchas → tótem de fuego (11,1); agua a la barrera de fuego B → tótem de agua (1,1). **Nuevo:** la llave del campamento abre el muro agrietado de (13,5) (o lo rompe la tierra) y da la **vuelta** | fuego + agua (combinar) | `fuego` |
| **7 · Santuario** | x 14–17, filas 35–47 | el elemental G (17,39) y la salida E (18,39), como hoy | combate final | preset nuevo `santuario` (verdoso oscuro) |
| **8 · La vuelta** (nueva) | x 14–17, filas 1–34 (hoy roca) | un pasillo de bajada por la banda este: de (14,5) a la antesala (15,34), que da al santuario por el norte y a la puerta X por detrás. Un sentido: se entra desde el altar. Puede llevar una lava pequeña (agua para cruzar) como recordatorio del ala de fuego | agua (lava) | `hielo` (cueva fría) |

**Con esto el recorrido queda así:**
- inicio → claro (fuego) → ala del agua (sello de agua) → centro;
- → prado (rayo) → campamento (combate, llave) → altar (fuego + agua);
- → **la vuelta** (atajo, lava) → antesala → puerta X → santuario → salida.

De 80 filas andadas para un solo objetivo se pasa a un **bucle sin volver sobre los pasos**.

**Densidad:**
- **Enemigos:** 6 en 8 salas (0,75 por sala, cerca de los 0,6 de EoW), y 4 de ellos en la sala cerrada.
- **Puzles:** 1 por sala.
- **Rompibles:** el prado y la vuelta llevan los que más botín dan.

## 4. Mazmorra y exterior

EoW trata distinto el campo y las mazmorras (`EOW_1_TABLAS.md` §3). Aquí:

- **Exterior: el prado (sala 4) y la pradera del centro (sala 2).**
  - La luz cambia despacio al entrar (5 s, como los exteriores de EoW).
  - Más rompibles y botín según la región.
  - Enemigos sueltos que no cierran nada.
  - Sin cofres «de puzle».
- **Mazmorra: el claro, el ala del agua, el campamento, el altar, la vuelta y el santuario.**
  - La luz cambia rápido (≤ 1 s): se nota que se ha cruzado un umbral.
  - Un puzle con su respuesta (`Logros3D`).
  - Cierres y cofres.

## 5. Cómo se escribe en el mapa

Todo con piezas que ya existen (`docs/ARQUITECTURA.md`, *Niveles* y *Las piezas de `objetos/`*), en `mundo/datos_nivel/mapas/Bosque.txt`.

```
; --- zonas (Zonas3D) ---
; zona 1,40..3,47 bosque
; zona 1,31..6,39 agua
; zona 5,29..12,47 ruinas
; zona 1,18..12,28 bosque
; zona 1,10..12,17 atardecer
; zona 1,1..12,9 fuego
; zona 14,1..17,34 hielo
; zona 14,35..18,47 ruinas          (hasta tener el preset «santuario»)
; --- sala 5: campamento cerrado ---
; pieza cuello cerrojo 1 17 celdas=1,17..6,17 sala=1,10..12,16
; pieza campamento vigia 1 10 de=1,10..12,16 flag=bosque.campamento.limpio
; pieza cofre_llave cofre 6 13 aparece_si=flag.bosque.campamento.limpio abierto=bosque.campamento.llave
; puzle abre_cuello cuando=campamento.todos_derrotados hace=cuello.abrir
; --- sala 6: el atajo ---
; pieza atajo muro 13 5 golpes=2
; puzle llave cuando=flag.bosque.campamento.llave hace=atajo.romper
; --- sala 8: la vuelta, una lava pequeña ---
; pieza lava_vuelta lava 15 20 celdas=14,20..17,21
```

**Lo que hay que cambiar en el `.tscn`** (lo manda sobre el `.txt`): abrir la banda este entre (14,1) y (17,34) y la antesala (15,34).
Mejor en el editor sobre `Nivel_Bosque.tscn`, porque hornear con F9 lo aparta y lo sustituye.

**La lógica que hoy está en `bosque_3d.gd`** (tótems, puerta X, elemental, salida, tienda) puede quedarse donde está en una primera fase.
Lo nuevo va en líneas `; puzle`. Pasar lo viejo a líneas es una segunda fase, cuando el diseño esté cerrado.

## 6. La Cueva: una mazmorra pequeña (enfoque cerrado)

**Por qué una cueva.** Es el entorno cerrado por excelencia: paredes por todas partes, poca luz, salas que se leen solas. Tiene el tamaño
de las mazmorras pequeñas de EoW (S_Dungeon022: 6 salas; `EOW_2_NIVELES.md` §6) y **una mecánica por elemento**, así que también sirve
para medir la identidad de cada uno (la pregunta del Test 2, ver `ARQUITECTURA.md`).

**Mapa nuevo** `mundo/datos_nivel/mapas/Cueva.txt`, 27 × 21 casillas, con su escena `escenas/PruebaCueva.tscn` (la maqueta con
`nivel = "Cueva"` y un nodo hijo *Puzles*, como el Bosque 01). Seis salas de 8 × 8 en dos filas, con paredes de una casilla y pasos de una:

```
     x: 1 ...... 8   9   10 ..... 17   18   19 ..... 25
y  1  ┌── C2 ─────┐      ┌── C3 ─────┐       ┌── C4 ─────┐
      │ GRIETAS   │ ▓▓▶  │ RÍO DE    │  ══▶  │ SALA      │
      │ (tierra)  │(9,4) │ LAVA      │ (18,4)│ CERRADA   │
y  8  └─────┬─────┘      │ (agua)    │       │ (combate, │
            │ (4,9)      └───────────┘       │  llave)   │
y 11  ┌── C1 ─────┐      ┌── C6 ─────┐       └─────┬─────┘
      │ BOCA      │  ◀═  │ TESORO    │  ◀╬═        │ (22,9)
      │ (fuego,   │(9,16)│ (cofre    │(18,16) ┌── C5 ─────┐
      │  inicio)  │atajo │  grande)  │ puerta │ CHARCA    │
y 18  └───────────┘      └───────────┘ c/llave│ ELÉCTRICA │
                                              │ (hielo +  │
                                              │  rayo)    │
                                              └───────────┘
```

| sala | casillas | qué se resuelve | elemento | luz |
|---|---|---|---|---|
| **C1 · Boca** | x 1–8, y 11–18 | se entra a oscuras. Dos braseros apagados (2,12) y (7,12): con fuego dan luz y abren el paso al norte (4,9)–(4,10). Jarrones con oro (cuando existan los rompibles) | fuego (enseñar) | `cueva` (oscura) |
| **C2 · Las grietas** | x 1–8, y 1–8 | el paso al este (9,4) es un **muro agrietado**: dos golpes de tierra. Es la sala que enseña la tierra | tierra | `cueva` |
| **C3 · Río de lava** | x 10–17, y 1–8 | un río de lava en x 13–14 corta la sala de arriba abajo. Agua para enfriarlo y cruzar; la roca **vuelve a ser lava** a los 10 s (contrarreloj) | agua | `fuego` |
| **C4 · Sala cerrada** | x 19–25, y 1–8 | al entrar se cierra (18,4). Dos goblins, uno con escudo (se rodea o se quema). Al caer el último se abre y aparece un **cofre con la llave** | combate | `atardecer` |
| **C5 · Charca eléctrica** | x 19–25, y 11–18 | la fuente eléctrica (25,12) electrifica una charca que corta la sala (x 20–24, y 13–16). El agua no se cruza y electrocuta; **el hielo la vuelve suelo y corta la corriente** | hielo + rayo | `hielo` |
| **C6 · Tesoro** | x 10–17, y 11–18 | la **puerta con llave** (18,16) se abre con la llave de C4. Cofre grande (13,13) con la recompensa (un glifo o un sello). Un pulsador de presencia (10,16) abre el **atajo** (9,16) de vuelta a la boca: se abre desde dentro | — | `ruinas` |

**El recorrido** es un bucle: C1 → C2 (tierra) → C3 (agua) → C4 (combate, llave) → C5 (hielo) → C6 (tesoro) → atajo → C1.

- Seis salas, un puzle cada una.
- Dos enemigos, los dos en la sala cerrada.
- Cada elemento tiene un sitio donde es la respuesta: fuego da luz, tierra rompe, agua enfría, hielo hace suelo y corta la corriente, y el
  rayo es el peligro.

**Las líneas del mapa** (validadas con `Puzle3D` y `Zonas3D`):

```
; zona 1,11..8,18 cueva
; zona 1,1..8,8 cueva
; zona 10,1..17,8 fuego
; zona 19,1..25,8 atardecer
; zona 19,11..25,18 hielo
; zona 10,11..17,18 ruinas
; pieza grieta muro 9 4 golpes=2
; pieza rio lava 13 1 celdas=13,1..14,8 vuelve=10
; pieza entrada_c4 cerrojo 18 4 celdas=18,4 sala=19,1..25,8
; pieza guardia vigia 19 1 de=19,1..25,8 flag=cueva.c4.limpia
; pieza cofre_llave cofre 22 5 aparece_si=flag.cueva.c4.limpia abierto=cueva.c4.llave
; puzle abre_c4 cuando=guardia.todos_derrotados hace=entrada_c4.abrir
; pieza puerta_llave puerta 18 16
; puzle con_llave cuando=flag.cueva.c4.llave hace=puerta_llave.abrir
; pieza tesoro cofre 13 13
; pieza boton pulsador 10 16 modo=presencia
; pieza atajo puerta 9 16
; puzle abre_atajo cuando=boton.pulsado hace=atajo.abrir
```

Las letras del plano:
- `T` en los braseros (2,12) y (7,12);
- `e` en la fuente (25,12) y `~` en la charca (con `agua_fisica = true` en la escena, por la charca);
- `W` en los goblins de C4 (el del escudo, con `Escudo3D`);
- `S` en la entrada (4,17).

**El arte** está en `arte/meshy/PROMPTS_CUEVA.md`, separado en lo que se usa tal cual, lo que se adapta sin generar (rocas escaladas
como paredes provisionales, suelo oscurecido, cofre grande, cristales que alumbran) y lo que hay que pedir a Meshy:
- paredes modulares de cueva;
- el muro agrietado;
- la boca de la cueva;
- jarrones rompibles;
- la puerta con cerradura y la llave;
- decorado de cueva y dos texturas de suelo.

Ninguna de esas piezas bloquea la Fase 1: la Cueva se monta ya con lo que hay y se cambia el arte cuando llegue.

**Estado (23/10).** La Fase 1 está montada en `escenas/PruebaCueva.tscn` y la recorre `herramientas/captura_cueva.gd` (0 fallos, fotos en
`docs/capturas/cueva`):
- **Paredes:** el kit de cueva elige pared, esquina o rincón según las vecinas.
- **Suelos:** las dos texturas, roca de cueva y basalto.
- **Setas:** recolectables (`Recolectable3D`, tres variantes intercaladas) que reaccionan a los hechizos.
- **Muro agrietado:** con su modelo y grietas que crecen con cada golpe.
- **Puertas:** con el marco y la hoja de piedra (`modelo=llave`).

La charca de C5 es agua quieta: `agua_corre = false` en la escena, porque sin eso el agua corría como un río y sus franjas se veían
como goteras blancas.

**Lo que falta revisar del agua** tiene su banco de pruebas: `escenas/PruebaCuevaAgua.tscn` con `herramientas/escenario_cueva_agua.gd`
(fotos en `docs/capturas/cueva_agua`), con charca quieta, eléctrica, helada y nexo. Quedan tres cosas por arreglar:
- los cuadros amarillos opacos del agua electrificada;
- las costuras rectas de las cáusticas;
- la franja marrón del borde del mapa.

**Los materiales** que se consiguen en la Cueva están en `MATERIALES_CUEVA.md`.

**El tema de la Cueva** es el **pulso resonante** (`PLAN_PULSO_RESONANTE.md`). Cada sala gana un uso del pulso sobre lo que ya
resuelve, y el cofre de C6 es el **legendario**: da el glifo, con su animación, y la salida pide usarlo. Allí se fijan también las
tres calidades de recompensa: común, épica y legendaria.

**Cómo se une al Bosque.**
- **Fase 1:** escena propia, como un laboratorio, para probar el enfoque cerrado sin depender de nada.
- **Fase 2:** la boca de la cueva en el Bosque, con transición de nivel (pieza nueva, §8).
- **Opción para Pablo:** que la cueva SEA «la vuelta» del Bosque (sala 8). Se entraría por el altar y se saldría junto a la puerta X, como
  los «vacíos» del campo de EoW, que apuntan a una mazmorra. Así la mazmorra es a la vez el atajo.

## 7. Abierto + cerrado: qué se prueba y cómo se compara

| | Bosque (abierto) | Cueva (cerrado) |
|---|---|---|
| **qué manda** | el sitio: regiones con su luz, su botín y sus enemigos | la sala: un puzle, un cierre, una recompensa |
| **orientación** | se ve lejos; se elige adónde ir | una salida visible por sala; el bucle guía |
| **recompensa** | explorar: rompibles, rincones | resolver: cofre, llave, atajo |
| **combate** | enemigos sueltos que se pueden evitar | una sala que se cierra hasta acabar |
| **luz** | mezcla lenta (5 s) al cambiar de región | cambio rápido (≤ 1 s) al cruzar cada umbral |
| **riesgo** | perderse o aburrirse en zonas vacías | sentirse en un pasillo de pruebas |

**Qué medir en el playtest.** El `PlayLog` ya apunta los lanzamientos y los golpes; faltaría la sala o región en cada evento:

- tiempo por sala o región, y cuántas veces se vuelve a una ya resuelta;
- hechizos por elemento en cada sala: ¿el que se esperaba es el que se usa?;
- intentos fallidos antes de resolver (hechizos que no hacen nada);
- muertes y dónde;
- lo que dice Pablo: dónde se aburre, dónde se pierde, qué recuerda al acabar.

Con eso se decide cuánto de cada enfoque lleva el juego: si el Bosque necesita más cierres o si la Cueva necesita más libertad.

## 8. Lo que falta construir

| pieza | qué hace | tamaño |
|---|---|---|
| **Rompibles** (`; pieza j jarron x y botin=oro\|pocion\|nada`) | jarrón o caja que se rompe con cualquier golpe (hechizo, empujón, explosión) y suelta su botín. Botín por zona (`bosque`, `ruinas`…) como el `RegionItemDrop` de EoW | pequeño, como el muro |
| **Mezcla por zona** (`; zona … mezcla=5`) | el tiempo de mezcla de la luz por zona: 5 s en el exterior y ≤ 1 s en la mazmorra (hoy, 1,5 s fijo) | muy pequeño, en `Zonas3D` |
| **Preset de luz `santuario`** | verdoso oscuro, para el elemental | una fila de `LuzZona3D.ZONAS` |
| **Temperatura por zona** (opcional) | `temp=0..4`: en una zona fría el agua lanzada se hiela sola; en una caliente se evapora antes. Sin `if` por sala: la lee la reacción del agua | medio; toca reglas de juego |
| **Entrada a zona una vez** (opcional) | un rótulo o diálogo la primera vez que se entra en una zona (`RegionEntryDemo` de EoW), con flag de «ya visto» | pequeño |
| **Preset de luz `cueva`** | oscuro: sol casi apagado y ambiente bajo, para que los braseros iluminen de verdad | una fila de `LuzZona3D.ZONAS` |
| **Puerta con llave** | hoy la regla abre la puerta en cuanto se abre el cofre. EoW pide llegar a la puerta con la llave: abrir solo si la flag está puesta y el jugador está delante | pequeño, en `Puzle3D` |
| **Transición entre niveles** | una salida con nombre que carga otro nivel y aparece en una entrada con nombre (`SensorLevelOpen` + `TagAreaStart` de EoW). Hoy cada escena es independiente | medio |
| **La sala en el `PlayLog`** | apuntar en cada evento la zona en la que está el jugador (`Zonas3D` ya lo sabe), para comparar los dos enfoques | pequeño |

## 9. Decisiones para Pablo

1. **¿Se abre la banda este** para la vuelta (sala 8), o el atajo baja por dentro del pasillo, con más paredes y menos espacio?
2. **¿El cuello se cierra en combate** (sala cerrada) o se mantiene la puerta goblin que se quema? Se puede tener las dos: quemarla abre la entrada y los goblins la cierran detrás.
3. **¿Dónde va la llave pequeña:** en el campamento (como aquí) o en el prado, junto a un rompible grande?
4. **¿Temperatura por zona sí o no** en esta fase? Cambia reglas de juego y pide playtest.
5. **¿La Cueva es «la vuelta» del Bosque**, o un nivel aparte con su propia entrada (en el prado, por ejemplo)?
6. **Orden de los trabajos propuesto:**
   1. **la Cueva como escena propia** (§6): preset `cueva`, mapa y líneas; todas sus piezas existen salvo la puerta con llave;
   2. zonas y mezcla por zona en el Bosque (visible enseguida, sin tocar el mapa);
   3. rompibles (los usan los dos);
   4. la sala en el `PlayLog` y **un playtest de los dos enfoques** (§7);
   5. sala cerrada del campamento con cofre y llave;
   6. la vuelta, o la transición a la Cueva si es la vuelta;
   7. pasar la lógica de `bosque_3d.gd` a líneas `; puzle`.

   Cada paso con su captura y su escenario de prueba, como los laboratorios.
