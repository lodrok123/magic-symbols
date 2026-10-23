# Plan · El Bosque al estilo de Echoes of Wisdom

23/10/2026 · propuesta para que **Pablo la revise** antes de tocar el mapa. No cambia ningún archivo del juego.

Fuentes: el estudio de niveles y tablas de EoW (`docs/estudios/eow/EOW_2_NIVELES.md` §1.4, §6, §7; `EOW_1_TABLAS.md` §3), el plan
visual (`docs/PLAN_EOW_VISUAL.md` §5) y el nivel tal como lo carga el juego hoy (`mundo/datos_nivel/Nivel_Bosque.tscn`, 19 × 49).
Coordenadas en casillas `(columna, fila)`, como las de `; pieza` y `; puzle`. **Regla de siempre: de EoW se toman las ideas, no los mapas.**

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

## 6. Lo que falta construir

| pieza | qué hace | tamaño |
|---|---|---|
| **Rompibles** (`; pieza j jarron x y botin=oro\|pocion\|nada`) | jarrón o caja que se rompe con cualquier golpe (hechizo, empujón, explosión) y suelta su botín. Botín por zona (`bosque`, `ruinas`…) como el `RegionItemDrop` de EoW | pequeño, como el muro |
| **Mezcla por zona** (`; zona … mezcla=5`) | el tiempo de mezcla de la luz por zona: 5 s en el exterior y ≤ 1 s en la mazmorra (hoy, 1,5 s fijo) | muy pequeño, en `Zonas3D` |
| **Preset de luz `santuario`** | verdoso oscuro, para el elemental | una fila de `LuzZona3D.ZONAS` |
| **Temperatura por zona** (opcional) | `temp=0..4`: en una zona fría el agua lanzada se hiela sola; en una caliente se evapora antes. Sin `if` por sala: la lee la reacción del agua | medio; toca reglas de juego |
| **Entrada a zona una vez** (opcional) | un rótulo o diálogo la primera vez que se entra en una zona (`RegionEntryDemo` de EoW), con flag de «ya visto» | pequeño |

## 7. Decisiones para Pablo

1. **¿Se abre la banda este** para la vuelta (sala 8), o el atajo baja por dentro del pasillo, con más paredes y menos espacio?
2. **¿El cuello se cierra en combate** (sala cerrada) o se mantiene la puerta goblin que se quema? Se puede tener las dos: quemarla abre la entrada y los goblins la cierran detrás.
3. **¿Dónde va la llave pequeña:** en el campamento (como aquí) o en el prado, junto a un rompible grande?
4. **¿Temperatura por zona sí o no** en esta fase? Cambia reglas de juego y pide playtest.
5. **Orden de los trabajos propuesto:**
   1. zonas y mezcla por zona (visible enseguida, sin tocar el mapa);
   2. rompibles;
   3. sala cerrada del campamento con cofre y llave;
   4. la vuelta (abrir la banda este, muro y lava);
   5. pasar la lógica de `bosque_3d.gd` a líneas `; puzle`.

   Cada paso con su captura y su escenario de prueba, como los laboratorios.
