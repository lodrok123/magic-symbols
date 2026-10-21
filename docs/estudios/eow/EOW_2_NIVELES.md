# Echoes of Wisdom: formatos de nivel, rejilla, colisión, navegación y cámara

Estudio de ingeniería inversa para sacar conclusiones propias aplicables a Magic Symbols.
No se copia ningún dato ni asset al juego. Lo que pongo aquí son identificadores internos
(nombres de clase, nombres de campo), cifras y estructura; no hay textos del juego.

Convención: **MEDIDO** es lo que se comprueba en los bytes con cifras; **DEDUCIDO** es una
interpretación razonable que no he verificado al 100 %.

Lectores (Python, ejecutar con `python3 -I`), en `scratchpad/eow/niveles/`:

| archivo | qué hace |
|---|---|
| `diccionario.py` | Construye `dic_crc32.json` (CRC32 → cadena) con todas las cadenas legibles de lo extraído y los nombres de archivo del dispositivo. Resuelve el 100 % de los tipos de actor. |
| `elo.py` | Lector de `.elo`. Vuelca a `json/<nivel>.json`: secciones, salas, áreas, actores (tipo, id, pos, rotación/escala por índice, 8 parámetros tipados, 4 ranuras de switch, enlaces, sala). |
| `estadisticas.py` | Recuentos por nivel y categoría (`estadisticas.txt`). |
| `grafo_salas.py` | Adyacencia por AABB y saltos por nombre (escaleras/salidas → TagAreaStart). |
| `analisis_mazmorra.py` | Resumen por sala: vista, tamaño en casillas, enemigos, interruptores, puertas, cofres con contenido (`analisis_mazmorras.txt`). |
| `bfgrid.py` | Lector de `.bfgrid` (octree → volumen numpy) y mapa de alturas en ASCII. |
| `cide.py` | Lector de `.cide`: tabla de atributos y malla PhysX (vértices, triángulos, material por triángulo). |

---

## 0. Unidades (clave para todo lo demás)

- **MEDIDO**: las posiciones de los actores caen en múltiplos de **0,75**. Las AABB de sala y las
  escalas de volumen (escaleras de 3; 4,5; 9; 12 y 19,5 de alto; abismos de 4,5×1,5,
  6×6 y 6×10,5) caen en múltiplos de **1,5**.
- **MEDIDO**: `.bfgrid` y `.bfnvms` usan celdas de **0,75** (campo float en la cabecera, igual en
  todos los archivos).
- **DEDUCIDO**: la casilla de diseño es de **1,5 unidades** (un bloque). La rejilla técnica es de
  media casilla (0,75), así los objetos pueden centrarse en una casilla o caer en su borde.
- Salas de L_Dungeon001: entre 8×9 y 35×50 casillas; la mediana ronda las 15×13. Las salas
  laterales (side-scroll) miden **3 casillas de fondo** (4,5 unidades) y entre 19 y 41 de largo.

---

## 1. `.elo` (nivel) y `.eclo` (índice común)

### 1.1 Cabecera (MEDIDO en los 25 `.elo`)

```
0x00  'elo '            magic
0x04  u8 1,0,1,1        versión
0x08  u32               tamaño del archivo (coincide siempre)
0x0C  32 × (u32 cuenta, u32 offset)    tabla de secciones
0x10C 'LVLE' u32 0x0B + relleno hasta 0x120
```

No es autodescriptivo como el `.gsheet`: no hay nombres de campo. Los nombres de **clase de actor**
y de **enlace** van como **CRC32** (zlib estándar) del nombre ASCII. Con el diccionario
(83 673 entradas) resuelvo **765/765 tipos y 31 027/31 027 instancias**.

### 1.2 Secciones (tamaño de elemento MEDIDO y significado)

| sec | tam | contenido | estado |
|---|---|---|---|
| 0 | 0x7C | **actores** | descifrado (ver 1.3) |
| 2 | 4 | nombre del enlace (CRC32) | descifrado |
| 3 | 2 | lista de índices de actor agrupada por sala (permutación de 0..n-1, MEDIDO en los 25) | descifrado |
| 4 | 24 | grupos/capas de actores (u16 tipo, u16, u16 índice, hash); el actor apunta con `+0x64` | parcial |
| 5,6 | 16 / 2 | tablas auxiliares por sala | sin descifrar |
| 7 | 48 | **salas**: AABB (min xyz, pad, max xyz, pad) + u16[8]; u16[2] = inicio y u16[3] = cuenta en la sec. 3 | descifrado |
| 10 | 8 | destino del enlace: u16 ?, u16 ?, **u16 índice del actor destino**, u16 (byte alto = grupo destino, DEDUCIDO) | descifrado |
| 12 | 48 | **áreas/regiones**: AABB + 2 floats + u16 (cadena de nombre, inicio, cuenta) de un polígono XZ en la sec. 22 | descifrado |
| 13 | 12 | referencias de área a valores/eventos | parcial |
| 14 | 48 | parámetros de luces (intensidad, color RGBA8, radio) | DEDUCIDO |
| 15 | 32 | posición + cuaternión (sondas/cámaras locales) | DEDUCIDO |
| 19 | 32 | puntos de raíl (LiftRailMove) | DEDUCIDO |
| 22 | 8 | vértices XZ (float, float) de los polígonos de área | descifrado |
| 24 | 16 | **rotaciones** (cuaternión xyzw), deduplicadas | descifrado |
| 25 | 16 | **escalas/tamaños** (xyz, 0), deduplicadas | descifrado |
| 26 | 8 | **pool de valores tipados** (u32 tipo, u32 valor) | descifrado |
| 30/31 | 4 / — | offsets de cadena + blob de cadenas UTF-8 | descifrado |
| 8,9,11,16,18,20,21 | — | índices/listas sin interpretar | sin descifrar |

### 1.3 Registro de actor (0x7C bytes, MEDIDO)

```
+0x00 f32[3]  posición (x, y=altura, z)
+0x0C u16     índice de rotación en la sec. 24 (cuaternión)
+0x0E u16     índice de escala/tamaño en la sec. 25
+0x10 f32[3]  centro de la caja local     +0x1C f32[6] caja local (min, max)
+0x34 u16[8]  4 RANURAS DE SWITCH: (índice al pool de valores, clase); (2,4) = vacía
+0x44 u16[8]  8 PARÁMETROS: índices al pool de valores (sec. 26)
+0x54 u32     id de instancia (hash, único)
+0x58 u32     índice del actor
+0x5C u32     CRC32 del nombre de clase
+0x60 u32     ?
+0x64 u16[10] [0]=grupo (sec. 4), [1]=?, [2..3]=inicio/nº de ENLACES, [4..9]=otras listas (raíles, referencias entrantes; parcial)
+0x78 u32     flags (0x103 normal, 0x303 volúmenes de mapa como agua o escalera, 0x503 PartnerPhoton)
```

**Pool de valores** (sec. 26). Cada actor tiene 8 parámetros **posicionales** y cada uno es un
índice a este pool deduplicado de pares (tipo, valor):
tipo 0 = vacío, 1 = bool, 2 = entero o hash, 3 = float, 4 = índice de cadena. Es el mismo
juego de códigos que usa el `.gsheet`. El significado de cada posición depende de la clase.
Por ejemplo:

- `MapStatic`: [modelo de sala, …]
- `SensorFloorChange`: [TagAreaStart destino, flujo de transición, sube/baja, condición, …]
- `DoorClose`: [modo, …, 'Switch0', …]. Es la puerta que se abre según su propia ranura de switch 0.
- `TreasureBox`: ['Switch0', **itemID**, …]. El itemID se cruza con `Items.gsheet`.

### 1.4 Salas, cómo se encadenan y regiones

- **MEDIDO**: sec. 7 = salas. En L_Dungeon001 hay 22 salas, que coinciden con 22 modelos
  `L_Dungeon001_0NN` (faltan el 006 y el 011). **31 000 de 31 027** actores caen dentro de la
  AABB de su sala (100 % en todas las mazmorras; las únicas 27 excepciones son del Field).
- **Encadenamiento** (MEDIDO en L_Dungeon001), de dos formas:
  1. **Contigüidad**: 17 pares de salas con AABB que se tocan. Se pasa caminando y la cámara hace scroll.
  2. **Salto por nombre**: una salida (`SensorFloorChange`, `SensorLevelOpen`) nombra en su
     parámetro 0 un `TagAreaStart` (entrada con nombre, p. ej. `L001_R004_LadderW`) y en el 1
     el flujo de transición (`FloorChangeCommon:LadderUp/TopLadderDown/WalkIn`). En L_Dungeon001
     hay 17 saltos de este tipo, casi todos escaleras que unen salas cenitales con salas laterales.
     La salida al mundo es un `SensorLevelOpen` con [nivel, entrada, `AreaExitCommon:WalkOut`, …].
- **Áreas** (sec. 12): polígono XZ con un nombre de región (`LDungeon001_Top`, `_Side`,
  `BossGolem`; en L_Dungeon002 también `_TopWater`, `_SideDark`…). Hay 8 en L_Dungeon001,
  17 en L_Dungeon002 y 88 en L_DungeonLast. `BossGolem` coincide con un preset de
  `PlayRegionCamera.kobin` (sección 4). **DEDUCIDO**: el área elige el preset de cámara, luz y
  ambiente, con independencia de la sala.

### 1.5 Interruptores → puertas: flags con nombre + enlaces directos

**MEDIDO**: son dos mecanismos.

**A) Ranuras de switch (4 por actor)**: pares (valor, clase). Recuento en todos los niveles:

| clase | uso | n.º |
|---|---|---|
| 1 | flag con nombre | 2 096 |
| 0 | entero (DEDUCIDO: flag global numérica) | 339 |
| 2 | entero, casi siempre 1 (DEDUCIDO: flag local o temporal de sala) | 252 |
| 3 | 0/1 (DEDUCIDO: valor inicial o invertido) | 155 |

El emisor y los receptores **comparten el nombre de la flag**. En L_Dungeon001:

- `L001R017SwitchFoot` lo escribe una `SwitchFoot` y lo leen 2 `DoorClose`, un `Fence`, una
  `StatueLD001` y un `TagRoomLocker`.
- `L001R006DoorOpen` lo escribe un `TagCheckerActivate` y lo leen `DoorClose`, 2 `LampDungeon`
  y `TagRoomLocker`.
- `L001R0xxTreasureBoxGet` va en la ranura 1 de cada cofre: es su flag de "ya abierto".

Patrón: **las flags se nombran por sala y por hecho** (`L001R017…`), no por actor.

**B) Enlaces directos** (sec. 2 + sec. 10, referenciados desde `+0x64[2..3]`): la lista de
destinos de un actor, cada uno con un nombre de enlace. Hay 47 en L_Dungeon001 y 3 078 en total.
Se usan para relaciones 1→N que no son una flag. Ejemplos medidos:

- `TagCheckerActivate` → 2 `LampDungeon`: comprueba que los dos estén encendidos.
- 3 `Dekubaba00` → `TagCheckerWipeout`: "todos muertos".
- `GolemMain` → 13 destinos (puerta del jefe, contenedor de corazón, entradas, partículas).
- `TagRoomLocker` → `Fence`.

Los enlaces más frecuentes en todo el juego: `TagAreaStart` 528, `TagConditionalActivator` 339,
`SensorEventBox` 324.

**DEDUCIDO**: la lógica de puzle no va en código por sala. Se arma con **actores lógicos sin
geometría**: `Tag*` (Checker, RoomLocker, ConditionalActivator), `Sensor*` (cajas de entrada,
salida o descubrimiento) y flags con nombre. En L_Dungeon001 hay 42 `Tag*` lógicos y 50
`Sensor*` frente a 14 enemigos.

### 1.6 Cifras de actores (MEDIDO, `estadisticas.txt`)

- Actores por nivel: S_Dungeon001 tiene 19, L_Dungeon001 507, L_Dungeon006 1 101,
  L_DungeonLast 2 421 y el Field 18 442.
- Salas: las L_ tienen de media **24,4** (rango 19–30) y las S_ **7,6** (rango 1–30).
  Salas laterales por L_: entre 2 y 6.
- Actores por sala: 18,7–38,7 en las L_ normales (L_Dungeon001 tiene 23,0).
- Tipos más usados en todo el juego: MapFixture 10 175, Lawn 5 371, TagLightActor 1 561,
  TagTailorPlayer 834, LawnWater 671, TagAreaStart 662, … BoxWooden 262, SensorEventBox 236,
  WallCracked 202, Pot 179, TreasureBox 111, DoorClose 84.
- **Agua, lava y abismo son actores-volumen** con caja escalada: `MapPond` 262, `FloorLava` 101,
  `MapAbyss` 88, `MapWaterfall` 79, `MapRiver` 59, `MapLadder` 141. No son material de colisión.
- Parámetros usados por actor: 0 → 6 939, 1 → 8 826, 2 → 10 992, más de 2 → ~4 300.
  La mayoría usa como mucho 2 de los 8.

### 1.7 `Common.eclo` (MEDIDO, parcial)

`'eclo'` v3, 15 pares (cuenta, offset) y un diccionario `dlce` de **193** pares (CRC32 del
nombre de nivel → índice), resueltos al 100 %. Contiene 193 registros de nivel de 288 bytes,
**511** registros de sala de 96 bytes (AABB + hash del nombre del modelo) y **1 214** actores de
64 bytes de las clases que importan fuera del nivel: SensorLevelOpen 351, SensorFloorChange 239,
TreasureBox 191, DoorClose 148, WarpOpener 97, CrackHuge 96, DoorLock 14…
**DEDUCIDO**: es el índice global que usan el mapa del mundo, el mapa de mazmorra (cofres y
puertas) y la navegación entre niveles sin tener que cargarlos.

---

## 2. `.bfgrid`: rejilla de ocupación voxelizada

### Formato (MEDIDO en 25 archivos)

```
0x00 'Grid'  0x04 u32 2
0x08 i16  profundidad del octree   0x0A i16[3] origen en celdas   0x10 i16[3] tamaño en celdas
0x18 f32  tamaño de celda = 0.75 (todos)    0x1C u32 tamaño de datos = archivo − 0x20
datos: octree. Raíz = últimos 32 bytes. Nodo = 8 × u32: offset absoluto al hijo, o
       0x80000000|v = subárbol uniforme de valor v. Hoja = 4×4×4 bytes en orden Morton.
       Bits del índice de hijo: bit0 = x, bit1 = y, bit2 = z.
```

- Comprobación: con ese orden, la caja de celdas a 1 coincide **exactamente** con el tamaño de
  la cabecera en 3 salas (44×16×30, 60×22×8 y 59×30×134). `4·2^prof ≥ dimensión máxima` se cumple
  en los 25 archivos (prof 2 a 6).
- Valores: **solo 0 y 1** (208 306 ceros y 72 014 unos en hojas). Los únicos nodos uniformes son
  de valor 0 (4 318).
- **Qué codifica** (MEDIDO por cortes): una **cáscara voxelizada de la colisión estática**. Cada
  capa horizontal muestra el contorno de las paredes, el suelo aparece lleno en su altura (525
  celdas en y=4 en S_Dungeon001_001), el estanque aparece como suelo hundido 4 celdas (3 unidades)
  más abajo y hay una tapa arriba. Una celda vale 1 si la toca la geometría de colisión.
- **No** codifica tipo de suelo, agua, transitabilidad ni "colocable para ecos": es un bit.
- **Tamaño frente a sala** (MEDIDO, 24 salas): origen·0,75 + posición del `MapStatic` coincide
  con la AABB de la sala con un margen de ±1 celda. Ejemplo: sala 001 = 28×19×29 celdas
  = 14×9,5×14,5 casillas de 1,5. Las salas laterales tienen siempre 8 celdas de fondo.
- **DEDUCIDO (uso)**: consulta rápida de "¿hay algo sólido aquí?" sin lanzar rayos contra la
  malla: comprobar si cabe un eco (bloque, cama, mesa…), apoyo de objetos, oclusión de cámara.
  Que sea una cáscara y no un volumen macizo sugiere que se usa para detectar contacto y superficie.

---

## 3. `.cide`: colisión

- **MEDIDO**: `'CIDE'` + cabecera propia + una o dos **mallas PhysX cocinadas** (`NXS\x01`
  `MESH`, versión 14, midphase con árbol `RTRE`).
- Malla: `u32 flags, nVert, nTri`, vértices float3, índices u8 o u16 según los flags, y si
  `flags & 1`, **un material u16 por triángulo**.
- El material es un índice a la **tabla de atributos del CIDE** (n registros de 16 bytes con un
  u32 de código). El lector reconstruye el reparto de forma coherente en las 25 mallas.
- Códigos y área total (24 salas medidas):

| código | área | dónde aparece |
|---|---|---|
| `0x0e` | 38 745 | general: paredes y suelos |
| `0x02` | 1 156 | casi siempre 100 % suelo plano |
| `0x0a` | 971 | piezas pequeñas de pared (soportes, lámparas) y paredes de salas laterales; DEDUCIDO: otro material, ¿madera/escalera? |
| `0x2000e` | 745 | |
| `0x16` | 692 | solo paredes |
| `0x03` | 244 | suelo de S_Dungeon001 (cueva de playa) |
| `0x06` | 231 | taludes alrededor del estanque |
| `0x05` | 34 | |

- **DEDUCIDO**: el byte bajo es el **tipo de superficie** (afecta a sonido, efectos y quizá
  agarre) y los bits altos (`0x20000`) son flags que se combinan con él. Ejemplos: `0x2000e` y
  `0x20002` = el mismo material con una propiedad extra, que por su posición parece "no
  escalable" o "pared invisible".
- **No consigo nombres**: no hay tabla de nombres de material en lo extraído, así que no sé qué
  número es hierba y cuál hielo.
- **MEDIDO**: **agua, lava y abismo no están en la colisión estática**. Son actores-volumen
  (`MapPond`, `FloorLava`, `MapAbyss`, `MapRiver`) con caja escalada en múltiplos de 1,5. Los
  efectos de entrar y salir (agua, lava, bloque de agua) aparecen como acciones en los perfiles
  de actor (`tailor/*.drsb`).

---

## 4. Navegación, cámara y himap

### `.bfnvms` (MEDIDO, parcial)

- **Uno por sala**: `navMesh/L_Dungeon001/Area0000..0021` = **22 áreas = 22 salas**. Las salas
  grandes se trocean en chunks: Area0006 (sala 007, 35×50 casillas) tiene 12 y Area0009 tiene 10.
- Cabecera:
  ```
  'NvMs' u32 1, i16 3, i16 origen_x, i16 origen_z (en celdas), i16 32, i16 32, i16 0, f32 0.75
  ```
  Ejemplo: Area0000 tiene origen (-225, 250)·0,75 = (-168,75; 187,5), que es la esquina de la
  sala 001.
- Datos: rejilla **32×32 columnas de 0,75** (24×24 unidades = 16×16 casillas por chunk) en orden
  **Morton**, con (cuenta, offset) por columna y registros de 6 bytes.
- Es decir: **no es una malla de polígonos, es un heightfield de columnas** (al estilo de
  Recast). Cada celda transitable tiene unos 2 registros: el primero casi siempre es
  (1, 0x17FF, 40) y el segundo (1, 0, -32768) o (4, -9, -17).
- **DEDUCIDO**: el primero es la altura y la máscara de conexiones y el segundo, vecinos y coste.
- Bloque final fijo de 1 344 bytes (48×28) a cero en todos los archivos vistos (¿enlaces entre
  chunks?).
- **No he descifrado el significado exacto de los 6 bytes**. La planta reconstruida sí cuadra
  con la sala.

### `PlayRegionCamera.kobin` (MEDIDO)

**41 presets con nombre**: Side, Field, Dungeon, Village, Indoor, BossGolem…, cada uno de 0x70
bytes de floats.

| preset | FOV | cabeceo | distancia |
|---|---|---|---|
| Dungeon | 0,489 rad (**28°**) | -0,785 rad (**-45°**) | 24–28 según el nivel de zoom |
| Indoor / casas | 28° | -45° | 22–23 |
| **Side** | 0,175 rad (**10°**) | 0 | **69** |

Algunos interiores añaden un pequeño giro de guiñada (de -1,2 a 0,75 rad) para encuadrar.
**DEDUCIDO**: la vista lateral es una perspectiva muy cerrada y lejana que simula una
ortográfica. La cenital es una perspectiva de 28° a 45°: no es isométrica pura. El área de la
sec. 12 del `.elo` elige el preset por su nombre.

### `Field.himap` (MEDIDO)

```
u32 28, u32 19, f32 origen_x = -83,75, f32 origen_z = -27,5, f32 1/tamaño_x, f32 1/tamaño_z (≈ 29 u)
```

Después vienen 28×19 floats de altura (-138,75 = sin dato). Es un **mapa de alturas grueso** del
campo. **DEDUCIDO**: sirve para cosas globales como cámara, pájaros, culling o límites.

---

## 5. `RoomFlagList.mflg` (MEDIDO)

```
'MFLG' u32 1, u32 803, 803 × u32 CRC32, u32 final (¿checksum?)
```

Los hashes son **nombres de modelo de sala** (`L_Dungeon004_010`, `S_Dungeon022_004`…). Resuelvo
576/803. El número por mazmorra coincide con las salas del `.elo`: L_Dungeon001 22,
L_Dungeon002 21, L_Dungeon003 27, L_Dungeon006 30, L_DungeonCastle 30, S_Dungeon102 10…

**DEDUCIDO**: es la lista de bits de "sala visitada" (niebla del mapa) en la partida guardada:
**una flag por sala**, con índice estable gracias al hash del nombre.

Las flags de puzle (`L001R017SwitchFoot`…) **no** están aquí: 0 de 654 coinciden.

---

## 6. Mazmorras analizadas (`analisis_mazmorras.txt`)

### L_Dungeon001: 22 salas, 507 actores

- 17 salas cenitales y 5 laterales (29×3, 20×3, 23×3, 19×3 y 20×3 casillas).
- Cenitales de 8×9 a 35×50 casillas; la mayoría entre 12 y 18 de ancho y entre 9 y 16 de fondo.
- **Encadenamiento**: 17 contigüidades y 17 escaleras. Patrón repetido: sala cenital → escalera
  → sala lateral → escalera → otra zona cenital. Las laterales hacen de "pasillos" entre zonas.
- **Densidad**:
  - 14 enemigos en total, concentrados en 6 salas. La sala más cargada (010, 31×67) tiene 2
    Darknut, 2 Keese y un mini-jefe.
  - 4 interruptores (3 `SwitchFoot` y 1 `SwitchFootClear`).
  - 17 "puertas": 7 `DoorClose`, 3 `Fence`, 1 `DoorLock`, 1 `DoorBoss`, barricadas…
  - 8 cofres: mapa en la sala 004, **llave pequeña** en la 016, **llave de jefe** en el cofre
    grande de la 017, y el resto rupias u objetos.
  - 47 rompibles y empujables (BoxWooden, Pot, BigRock).
  - 50 sensores y 42 tags lógicos.
- **Flujo típico de puzle**: placa (`SwitchFoot`) → flag con nombre → puerta, valla, estatua y
  `TagRoomLocker` (la sala se cierra hasta que lo resuelves).
- **Combate**: los enemigos se enlazan a un `TagCheckerWipeout`, que escribe una flag al morir
  todos, y esa flag abre la sala.
- **Proporción**: 21 interruptores y puertas para 22 salas (unos 1 por sala), 14 enemigos
  (0,6 por sala) y 92 actores con ranuras de switch. La mazmorra se basa en exploración y
  puzles, no en combate.

### S_Dungeon022 (pequeña): 6 salas, 229 actores

1 lateral (41×3); sala principal de 21×36 con 4 Keese y 9 rocas; sala de mini-jefe con
`DoorClose`; 1 cofre.

### S_Dungeon001 (mínima): 1 sala de 23×15 casillas, 19 actores

2 entradas, 1 salida al Field, agua y cascada como volúmenes, 2 cajas, 2 rocas y luces.
Es una cueva de una sola pantalla.

---

## 7. Conclusiones prácticas para Magic Symbols

1. **Separar casilla de diseño y rejilla técnica.** Grezzo diseña en bloques de 1,5 y guarda la
   ocupación a 0,75 (media casilla). Para Magic Symbols:
   - mantener la casilla entera para el plano de letras, la altura y el agua;
   - si los glifos necesitan más finura al rasterizarse, usar una subrejilla 2×2 por casilla;
   - no mezclar la rejilla de colisión con la de diseño.
2. **Agua, lava, abismo y escaleras como volúmenes, no como material del suelo.** Un volumen
   (caja escalada en casillas) con su propio actor y estado. Encaja con el agua que rellena
   huecos: el agua es una capa de estado por casilla y columna, separada del tipo de suelo.
3. **Atributo de superficie por cara o casilla en la colisión.** Código pequeño (byte bajo =
   material) más flags (bits altos). Para Magic Symbols: `tipo_suelo` (u8) + `flags` (bits:
   no_escalable, resbala, quema…) por casilla. Es barato y extensible.
4. **Ocupación aparte y consultable.** El `.bfgrid` es un bitmap 3D en octree para preguntar
   "¿hay sólido?". En Godot, un `PackedByteArray` de bits por casilla y nivel (o un diccionario
   disperso) que se recalcula al empujar bloques sirve para:
   - validar dónde cae un hechizo rasterizado;
   - comprobar si cabe un objeto invocado;
   - que la navegación lo lea.
5. **Formato de nivel: tabla de actores + parámetros posicionales tipados + pool deduplicado.**
   Para el plano de letras: la letra crea la geometría y un bloque de "actores" aparte (JSON o
   recurso) lleva tipo, casilla, rotación (4 orientaciones) y hasta N parámetros tipados.
   Pocos parámetros por actor bastan (en EoW el 85 % usa 2 o menos).
6. **Enlaces interruptor→puerta por datos, con flags con nombre.** Convención
   `sala.hecho` (p. ej. `R03.placa_norte`):
   - el emisor tiene una ranura de salida y los receptores una de entrada con el mismo nombre;
   - se añaden enlaces directos solo para relaciones "todos estos" (enemigos → contador, lámparas
     → comprobador);
   - las puertas no conocen a los interruptores, solo la flag;
   - las flags de "cofre abierto" o "sala resuelta" viven en la partida guardada.
7. **Actores lógicos invisibles.** Sensor de caja (entrar, salir, ver), comprobador "todos
   activos" o "todos muertos", bloqueador de sala, activador condicional. Con 5 o 6 de estos se
   arman casi todos los puzles sin código por sala.
8. **Conexiones entre salas por nombre de entrada.** Cada sala tiene entradas con nombre
   (`TagAreaStart`) y cada salida dice "nivel + entrada + tipo de transición".
   - Las salas contiguas no necesitan puerta lógica: se tocan y la cámara hace scroll.
   - Una lista global aparte (como `Common.eclo` y `RoomFlagList`) sirve para el mapa, las flags
     de "visitada" y los cofres pendientes.
9. **Navegación por columnas en la rejilla, no por polígonos.** EoW usa un heightfield de
   columnas de 0,75 por sala, troceado en chunks de 32×32. En Magic Symbols, con altura entera
   por casilla, un A* sobre casillas sirve directamente: cada casilla guarda su altura y una
   máscara de vecinos transitables, se puede saltar ±1 y se invalida al mover bloques o cambiar
   el agua. No hace falta `NavigationServer` con mallas.
10. **Cámara por región.** Presets con nombre (FOV, cabeceo, distancia por zoom) elegidos por un
    polígono o área en el nivel. Las salas laterales usan FOV 10° y distancia 69 (casi
    ortográfica) y las cenitales 28° a -45°. Para la prueba 3D: `Camera3D` ortográfica con
    presets por zona (tamaño, ángulo) y transiciones suaves al cruzar el área.

### Lo que no he descifrado

- Significado exacto de las secciones 5, 6, 8, 9, 11, 13, 16, 18, 20 y 21 del `.elo`.
- Campos `+0x60` y `+0x64[1,4..9]` del actor.
- Clases de switch 0, 2 y 3 (solo por deducción).
- Nombres de los códigos de material del `.cide`.
- Los 6 bytes de las columnas de `.bfnvms` y su bloque final.
- La mitad de los campos de cada preset de cámara.
