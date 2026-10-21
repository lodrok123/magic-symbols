# Echoes of Wisdom: análisis de las tablas de diseño (.gsheet) y qué aplicar a Magic Symbols

Fuente: 84 tablas convertidas a JSON en `scratchpad/eow/json/`, más 14 motionsheets que traje después (`scratchpad/eow/ms_json/`).
Los nombres de etiquetas los traduje con un lector MSBT propio (`scratchpad/tools/msbt.py`), pero solo para deducir; aquí no se reproducen textos del juego.
Convención: **[M]** = medido (contado en los datos). **[D]** = deducido (interpretación mía, sobre todo el significado de los enums, que se guardan como enteros sin nombre).

Arquitectura general **[M]**: cada tabla tiene una clave (`flags 0x4`), structs en línea, listas (`0x2`), opcionales (`0x1`) y referencias tipadas a otras tablas (`0x8`, p. ej. `mFlag: GlobalFlags`, `mCondition: Conditions`, `mItemKey: Items`). El conversor resuelve algunas referencias como structs incrustados (`Region.mWeather`, `Region.mSkySphere`). Es decir, el diseño es una **base de datos relacional de hojas**, no ficheros sueltos.

---

## 1. CopyableActor (los ecos) y su economía

### 1a. Lo que hay [M]
128 filas. Campos: `mUi{mNameLabel, mCategory}`, `mPasteCost{mSlot, mReductionGroup}`, `mPasteGridCount{mShape, mWidthOrDiameter, mHeightDouble, mDepth}`, `mPastePlace{mIsIgnoreGridSnap, mRotation}`, `mTriangleOffset{mBase,x,y,z}` y `mHabitat`.

**Categoría** (`mUi.mCategory`): 0 en 93 filas y 1 en 35. **[D]** 0 = monstruo y 1 = objeto (las 35 son cajas, camas, mesas, rocas, cebos, bloques...).

**Coste** (`mPasteCost.mSlot`, en triángulos):

| coste | total | monstruos | objetos |
|---|---|---|---|
| 1 | 33 | 10 | 23 |
| 2 | 35 | 29 | 6 |
| 3 | 33 | 30 | 3 |
| 4 | 18 | 15 | 3 |
| 5 | 8 | 8 | 0 |
| 6 | 1 | 1 (Lynel) | 0 |

La suma de todos los costes es 320. El coste medio de los monstruos es ≈2,8 y el de los objetos ≈1,4.

**Familias y variantes** [M], en formato coste/grupo de reducción:
- MoriblinSword 00/01/02: 2/2 → 4/4 → 5/6.
- Darknut 00/01/02: 3/1 → 4/3 → 5/6.
- Lizalfos: 3 → 4 → 5.
- Keese00 cuesta 1. Sus variantes elementales (fuego, hielo, rayo: 01/02/03) cuestan 4 cada una, con el mismo grupo 6.
- Wizzrobe fuego, hielo y rayo: 5/6 los tres.
- Octorok cuesta 1. Sus variantes de fuego y hielo cuestan 2/4.

Regla observada: **la variante elemental cuesta lo mismo sea cual sea el elemento**, y subir de nivel ("niv. 2/3") suma entre 1 y 2 triángulos.

**Grupo de reducción** (`mReductionGroup`, enum `PasteCostReduction`):
- 0 en 45 filas: los 35 objetos y los 10 monstruos de coste 1.
- Del 1 al 6, 14, 14, 14, 14, 14 y 13 monstruos.

| grupo | n | coste medio | posición media en la tabla | regiones donde predomina (por mHabitat) |
|---|---|---|---|---|
| 0 | 10 | 1,0 | 37 | inicio, mar |
| 1 | 14 | 2,5 | 46 | mar, desierto |
| 2 | 14 | 2,4 | 50 | campo central, desierto |
| 3 | 14 | 2,9 | 72 | mezcla |
| 4 | 14 | 2,9 | 60 | desierto, volcán, nieve |
| 5 | 14 | 3,1 | 93 | volcán, jungla, nieve |
| 6 | 13 | 4,7 | 90 | jungla, nieve, variantes de nivel 3 |

**[D]** Los monstruos están ordenados por "rango de progreso" y repartidos en **6 sextiles del mismo tamaño**. Nunca se reduce un objeto ni un eco de coste 1, porque no se puede bajar de 1. Las cantidades de la reducción **no están en las tablas** (estarán en código o en otro fichero). Hipótesis compatible con los datos: un mecanismo de progreso que abarata los ecos por grupos, del más antiguo al más reciente. La conclusión de diseño se mantiene sea cual sea el mecanismo exacto: **el coste base y el abaratamiento son dos ejes separados**.

**Forma y tamaño en rejilla** [M]:
- `mShape`: 0 en 93 filas, 1 en 6 y 2 en 29.
  - **[D]** 0 = huella circular (el campo se llama `WidthOrDiameter`). Es casi todo monstruos, más cántaros y cebos.
  - **[D]** 2 = rectángulo: cajas, camas, mesas, estatuas.
  - **[D]** 1 = forma alta tipo cápsula. Solo 6 filas: Dekubaba×3, Hidy, SoldierIronBall y Dandarma, todos de 2 o más celdas de alto.
- Ancho: 1 en 118 filas, 2 en 9 y 5 en 1 (`RollingPole`).
- `mDepth`: 1 en 114 filas y 2 en 14.
- `mHeightDouble` va en **medias celdas**: 1 en 8 filas, 2 en 102, 4 en 17 y 5 en 1. Las piezas planas (mesa, piedra, cama elástica, nube) miden media celda.
- **Tamaño de celda [M→D]**: `mTriangleOffset.mY` = 0,75 × `mHeightDouble` en 101 de 128 filas, es decir, 1,5 unidades por celda de alto. `WallCrackedList.mCollisionScale` también usa 1,5. **[D]** Una celda mide 1,5 unidades de mundo, y el icono de coste se coloca a la altura del techo del eco. Las 27 excepciones están ajustadas a mano (cebos más bajos, criaturas voladoras más altas).

**Colocación** [M]:
- `mIsIgnoreGridSnap = false` en **los 35 objetos (100 %)** y en solo 10 de 93 monstruos. Esos 10 son monstruos fijos o enraizados: Skulltula, Dekubaba×3, TrapBladeTimer, Megadon, StoneFragile×2, Armos, Beamos.
- **[D]** Lo que construye el escenario se ajusta a la rejilla. Lo que se mueve se coloca libre.

`mRotation`: 0 en 67 filas, 8 en 38, 1 en 9, 3 en 6, 2 en 4, 7 en 3 y 6 en 1.
- 0 aparece solo en monstruos y 8 sobre todo en objetos.
- El 7 son solo las 3 camas (objetos de 1×2).
- El 1 agrupa objetos y monstruos con dirección (Octorok y sus variantes, WindMaker, FlyingTile, Ghini, SnowBall).
- **[D]** El enum dice qué rotaciones se permiten al pegar: 0 = libre o mirando a la jugadora; 8 = pasos de 90° para piezas simétricas; 7 = alargado de 2 celdas; 1 = direccional. Los nombres exactos no se pueden confirmar.

**mHabitat no es suelo, agua ni aire** [D, con evidencia M]. Valores: 4 en 25 filas, 9 en 26, 11 en 18, 12 en 16, 8 en 14, 10 en 13, 5 en 6, y luego 6, 3, 1, 7, 0 y 2 con 1 a 3 filas cada uno. Al cruzarlo con los identificadores:
- 8 = mar/ríos (Octorok, Taggler, Bombfish, Biri, Gabufin, BlockWater).
- 9 = desierto (Gibdos, Poe, Piranha01, Boarblin, PotGerudo, estatuas L003).
- 10 = volcán (Octorok01 de fuego, Lizalfos, TorchSlug, Keese01, Wizzrobe00, BoardFloatLava).
- 11 = jungla (Hidy, BuzzBlob, Keese03 eléctrico, Wizzrobe02, Dekubaba01).
- 12 = montaña nevada (Octorok02 de hielo, Keese02, Wizzrobe01, Freezard, BlockIce, SnowBall, Wolfos01).
- 5 = castillo (PotHyruleCastle, Darknut, SoldierIronBall, BedZelda).
- 4 = campo inicial y común.
- 0 a 3 = zonas del prólogo y la primera mazmorra.

El orden 8→12 coincide con el de las mazmorras L_Dungeon002→006. **mHabitat es la región de origen o de hallazgo** del eco, probablemente para la enciclopedia o los filtros. El coste medio de los monstruos crece con la región: unos 2,1 en mar y campo, 2,7 en desierto, 3,0 en volcán y unos 3,4 en jungla y nieve.

El medio (tierra, aire, agua) aparece en otra tabla: **TecuumList** guarda tres tipos por hueco de aparición (`mType`, `mTypeAerial`, `mTypeInWater`). 59 de las 139 entradas tienen variantes distintas por medio. El medio es un **sustituto por contexto**, no una propiedad del eco.

**Tablas que se cruzan** [M]:
- `UiActorSelect`: 127 filas, todos los ecos menos `RollingPoleSide`, que es un subeco interno. Cada uno tiene `mPriority` único (0 a 136) y texto de enciclopedia. La prioridad ordena el menú: los ecos recientes salen arriba (Beamos 136, Megadon 135...).
- `GerudoMiniGameRemovableActorData`: 128 filas **en el mismo orden que CopyableActor**. Es una columna paralela de un minijuego: 38 eliminables, de ellos 30 objetos y 8 monstruos.
- `SpikeTileObstacle` y `MogriffonRushDown` son **idénticas**: 40 actores con `mIsDown` (16 true, 24 false). Los true son pesados o macizos (rocas, estatuas, BlockIce, Armos, Megadon, Beamos). **[D]** Dos sistemas reutilizan la misma propiedad de "pesado o anclado".
- `InterestList`: 42 actores, 35 de ellos ecos, con 6 booleanos de atracción (carne, pescado, roca asada, rupia, muñeco, zanahoria). Los combos más comunes: carne+pescado+zanahoria (20) y carne+pescado (11).
- `DeguZolPriorityActor`: puntos de congelación por actor y proyectil (`mFreezePoints` de 0 a 500; el proyectil de Wizzrobe01 da 500). Es el **contenido elemental como número**, que el jefe de hielo consume.
- `JabujabuExhale`: pesos por fase (4 columnas) de qué expulsa el jefe, mezclando enemigos y objetos.

**Energía y límite simultáneo**:
- `PartnerPhotons` [M]: 22 grupos. Hay 15 grietas pequeñas (S###) con 3 a 5 "extraviados" cada una, que dan 3, 5 u 8 unidades (`mNumOfRelease`: 19 veces 3, 31 veces 5, 11 veces 8), y 7 jefes con 100 cada uno.
  - **La suma es exactamente 1000**: 300 de 61 extraviados más 700 de 7 jefes.
  - Cada grupo tiene `mClearFlag`, `mGaugeStartFlag`, niveles donde se ve la barra y destino de teletransporte.
- **[D]** El nivel del compañero ("Niv." en el HUD) depende de un **acumulado sobre un presupuesto cerrado de 1000**. Los umbrales de nivel y el máximo de triángulos por nivel no están en las tablas. La única pista en datos es `BattleChallenge.mPartnerLevel`: 4 de 15 retos fuerzan el nivel 2 para limitar la capacidad de ecos.
- `PieceOfPowers` [M]: 150 piezas. `mCount` vale 0 en 65, 1 en 49, 2 en 21, 3 en 8 y 5 en 7, y su suma es **150**. 141 no tienen condición. 7 usan la estrategia 1 con dos expresiones (categorías 13 y 14: misión preparada o abierta) y van ligadas a misiones. **[D]** Es un coleccionable de mejora con un total cerrado y redondo, igual que los fotones.

### 1b. Patrón
- **Coste como entero pequeño (1-6)** con una distribución en campana centrada en 2-3. Los objetos son baratos y los monstruos crecen con la región y con el nivel de variante. Los 6 niveles caben en la cabeza de cualquiera.
- **Separación de ejes**: coste (`mSlot`), abaratamiento (`mReductionGroup`), huella física (`mPasteGridCount`), reglas de colocación (`mPastePlace`), región de origen (`mHabitat`) y presentación (`mUi`, `mTriangleOffset`). Ningún sistema lee más de lo que necesita.
- **Propiedades para sistemas concretos en tablas laterales** (`SpikeTile`, `Mogriffon`, `Interest`, `DeguZol`, `GerudoRemovable`, `Jabujabu`) en lugar de engordar el actor. Es como un ECS hecho con hojas: el sistema es dueño de su tabla.
- **Presupuestos cerrados y redondos** (1000 de energía, 150 piezas). El diseñador cuadra el total y luego reparte.

### 1c. Para Magic Symbols
1. **Coste del hechizo = entero de 1 a 6 por glifo y sello**, más un "grupo de abaratamiento" aparte. El coste base dice lo que vale el efecto y el grupo dice cuándo se abarata con la progresión. No mezclarlos en una fórmula: dos columnas en el `.tres` del glifo.
2. **La variante elemental cuesta lo mismo en todos los elementos.** Si cambiar el sello no altera el coste, el jugador elige elemento por la situación y no por precio. Encaja con "las combinaciones emergen".
3. **Rejilla de casillas con medias alturas**: guardar la altura en medias celdas (`mHeightDouble`) da escalones de media casilla sin decimales. Los muros o barreras (glifo barrera) se ajustan a la rejilla. Las criaturas o proyectiles invocados se colocan libres.
4. **Las reglas de rotación como enum por glifo** (libre, 90°, alargado, direccional) sirven para el glifo flecha y para la barrera de 1×N.
5. **Propiedades de interacción en tablas por sistema**: "pesado" (lo baja la trampa de pinchos), "atrae a X", "puntos de hielo". Para las runas, una tabla `contenido_elemental` por actor y proyectil (fuego 0-500, hielo...) que lean los estados del suelo y de los enemigos. Así salen combinaciones sin `if`.
6. **Presupuesto cerrado de progresión**: definir el total de "maná máximo" o de páginas de glifos alcanzable (p. ej. 1000) y repartirlo entre jefes (70 %) y secretos (30 %), como hace EoW.
7. **El medio (suelo, aire, agua) es un sustituto en el punto de aparición**, al estilo de `TecuumList`, no un campo del enemigo. Para los encuentros por datos: un hueco con variantes por medio.

---

## 2. Lógica de puzles y progreso: Conditions, GlobalFlags, EventVariables, Quest, TransitCounter

### 2a. Lo que hay [M]

**Conditions**: 479 condiciones con nombre. `mStrategy`: 0 en 440 y 1 en 39. **[D]** 0 = AND y 1 = OR; por ejemplo `AllSwitches01` usa 0 y `AnySwitches01` usa 1, con los mismos operandos.
- Número de expresiones: 0 en 1, 1 en 341, 2 en 99, 3 en 30, 4 en 6, 5 en 1 y 7 en 1. **El 71 % son atómicas.**
- Negación con `!` dentro del parámetro: 165 expresiones. No hay operador NOT aparte.
- 54 condiciones mezclan categorías y 22 **anidan otras condiciones** (categoría 37).

Categorías (`ConditionCategory`), con su significado deducido del uso:

| cat | usos | significado [D] | ejemplo de parámetro |
|---|---|---|---|
| 0 | 1 | siempre verdadero | `true` |
| 1 | 64 | flag global | `!WeatherUnLock` |
| 2 | 30 | tener objeto (inventario) | `$0`, `CopyRod` |
| 3 | 16 | haber tenido objeto (histórico) | `$n` |
| 5 | 16 | eco registrado en la enciclopedia | `$n` |
| 11 | 65 | **interruptor local de la sala** | `0`…`7` |
| 13/14/15/16 | 18/55/65/125 | misión preparada, abierta, completada y en paso X | `Quest=Paso` |
| 18 | 29 | variable de evento (enum) | `HorseRaceDifficulty=Easy` |
| 19 | 1 | contador (TransitCounter) | `VolcanoSubQuests=0` |
| 20 | 22 | flag de mensaje ya leído | `$n` |
| 21 | 45 | mazmorra superada | `L_Dungeon001` |
| 26 | 20 | símbolo de actor | `$n` |
| 28 | 9 | estado de la jugadora | `Ground`, `Aerial`, `OnWall`, `Underwater`, `Burrow`, `Riding` |
| 29/30 | 12/17 | atuendo o habilidad equipados | `$n` |
| 31/33 | 7/1 | montura | `RentalHorse:!Rented` |
| 34 | 8 | sello de colección | `$n` |
| 35 | 3 | temporizador | `t>=120` |
| 36 | 2 | vista superior o lateral | `!` |
| 37 | 32 | **otra condición** (composición) | `HorseRacing` |

- **Plantillas con argumento**: 132 condiciones usan `$0`…`$7`. Cada familia (`Inventory`, `NotInventory`, `QuestCleared`, `MessageFlag`, `Stamp`...) tiene 8 variantes. **[D]** El actor colocado en el nivel tiene 8 ranuras de parámetro. La condición `Inventory3` significa "tengo el objeto que diga mi parámetro 3". No hace falta una condición por objeto, solo una por ranura.
- **Interruptores locales**: los índices van de 0 a 7, así que hay 8 por sala. Existen combinadores ya hechos: `AllSwitches012`, `AnySwitches12`, etc. (16 combos).

**GlobalFlags**: 1624 flags, solo booleanos con nombre.
- Unos 189 son de prueba: `Test*` 121, `Testl` 20 y `TestPartnerStrayGet_#` 48.
- Patrones más frecuentes: `PartnerStrayGet_#` 71, `L#R#TreasureBoxGet` 36, `MapIcon_#` 36, `EvAreaA#` 30, `L#R#DoorOpen` 24, `S#_TreasureBoxOpen` 24, `PartnerSkillUpdate_#` 22, `EvPrologue#` 21, `Warp_L#R#` 21, `L#R#EnemyDead` 12, `L#R#SwitchFoot` 7, `L#R#DodgeRock` 6, `L#BossDead` 7.
- **Por mazmorra grande** (prefijo L00x): 32 a 49 flags (L006 49, L003 44, L004 41, L002 35, L001 34, L008 33, L005 32). **Por mazmorra pequeña** (S###): de 1 a 7.
- **Convención de nombres**: `L<mazmorra>R<sala><Cosa>`, por ejemplo `L001R014SwitchFoot`.
- **[D]** Solo es flag global lo que debe **persistir** fuera de la sala (puerta abierta para siempre, cofre cogido, roca rota). El resto de la lógica de la sala va con los 8 interruptores locales, que no ocupan el guardado global.
- Tablas que referencian flags: UiWarpSet 104, PartnerPhotons 99, Items 38, Conditions 37, UiMapArea 27, CrackRegion 22, UiTutorialModal 18, BattleChallenge 15.

**EventVariables**: 26 variables enumeradas con 261 estados en total. Las de misión más largas: `HyruleCastle_LuberiHouse` 29 estados, `Desert` y `Coast_River` 25, `Volcano` 23, `Midpoint` 22, `LastDungeon` 19. Los estados se guardan como hash.

**Quest**: 107 misiones. `mKind` vale 1 en 50, 2 en 37 y 0 en 20. `mProgress` tiene de 3 a 39 pasos (38 misiones tienen 3). 15 misiones se llaman igual que una EventVariable, y sus pasos son **un subconjunto ordenado de los estados de la variable** (p. ej. HyruleCastle_LuberiHouse muestra 10 de 29 estados). **[D]** La misión es una **máquina de estados**. El diario solo muestra algunos estados; el primero de cada misión no tiene texto (1 vacío en cada caso). Para `mReadyCondition` se usa la categoría 37 en 56 casos y la 15 en 39 ("aparece cuando otra misión acaba").

**TransitCounter**: 10 contadores con un tipo de disparador (`mTrigger` de 0 a 4), como `VolcanoSubQuests` o `StampmanCleared`. **[D]** Son contadores de progreso que una condición compara (cat 19).

Otros usos de Conditions como **interruptor de sistemas**:
- `Region.mTimeStopConditions` (59 regiones con `TimeUnlock`).
- `Weather.OverwriteConditions` (11).
- `ShopItem.mCondition`: 30 `true`, 6 `L001Clear`, `NotHaveOrnament*`.
- `ActorLayoutFilter`: durante `HorseRacing` excluye la categoría `enemy` y los actores Bird y Butterfly.
- `Quake.Conditions`, `RegionEntryDemo` y `BattleChallenge.ReleaseConditions`.

### 2b. Patrón
- **Tres niveles de estado**:
  1. Interruptor local de sala (8 bits, efímero o por sala).
  2. Flag global (booleano persistente con nombre por convención).
  3. Variable de evento enumerada (máquina de estados de misión).
  Además hay contadores y estado derivado: inventario, enciclopedia, mazmorra superada.
- **Condición = lista de (categoría, parámetro) + AND/OR**, con nombre y reutilizable. La composición se hace por referencia (cat 37), no con árboles en línea. No existe NOT: la negación va en el parámetro (`!`).
- **Plantillas parametrizadas por las ranuras del actor** (`$0..$7`). Un número fijo de condiciones genéricas sirve para miles de colocaciones.
- **Todo sistema que "se activa a veces" pide una referencia a Conditions** en vez de programar el caso.

### 2c. Para Magic Symbols
1. **Tabla `condiciones.tres`**: cada condición tiene nombre, estrategia AND/OR y una lista de (tipo, parámetro), con `!` para negar. Tipos mínimos: `siempre`, `flag`, `interruptor_local`, `tiene_glifo`, `estado_casilla` (mojado/quemado/helado en la casilla X), `variable=valor`, `condición`. El estado de casilla es propio de Magic Symbols y encaja como una categoría más.
2. **8 interruptores locales por nivel** en el plano de letras. Una placa o antorcha escribe el bit N y una puerta lee `AllSwitches012`. Solo se guardan como flag global las cosas persistentes, con el nombre `N<nivel>R<sala><Cosa>`.
3. **Parámetros de actor `$0..$7`** en el plano de letras: la puerta lleva "condición = Interruptor + arg 2". Así no se crea una condición por puerta.
4. **Misiones y tutoriales como enum de estados** más una tabla de qué estados se muestran. El diario no tiene lógica propia.
5. Sustituir `if nivel == 3 and tiene_glifo_flecha:` por **referencias con nombre**. Es la regla de "datos antes que condicionales" aplicada tal cual.

---

## 3. Mundo dividido en regiones: Region, Weather, SkySphere, sombras, CrackRegion, RegionEntryDemo

### 3a. Lo que hay [M]
**Region**: 334 filas, 17 campos. Cada región es un **paquete de ambiente** con referencias a otras tablas:

| campo | valores distintos | dato |
|---|---|---|
| `mBlendTime` | 8 | 0,1 s en 239 regiones, 5,0 s en 58 (exteriores) y 1,0/2,0 s en 13 cada una |
| `mCameraType` | 41 | Dungeon 127, Field 69, **Side 57** (secciones en vista lateral), Indoor 8 y cámaras específicas de casas y jefes |
| `mWeather` (→Weather) | 170 | opcional |
| `mSkySphere` (→SkySphere) | 10 | |
| `mGlobalCubeMap` | 76 | vacío en 60 |
| `mAudioSetting` (→AudioLocation) | 128 | BGM y ambiente por franja horaria |
| `mKodamaEnvironmentEffectName` | 44 | |
| `mEnvironmentEffectChannelName` | 10 | |
| `mTimeStopConditions` | 2 | 59 regiones paran el tiempo hasta `TimeUnlock` |
| `mItemDrop` (→RegionItemDrop) | 5 | vacío en 204, Sea 42, Desert 33, Hebra 29 |
| `mEnableCharacterLight` | 2 | true en 8 |
| `mIsLightProbeZNeg` | 2 | |

Las más repetidas por prefijo: SDungeon 20, HyruleHouse 9, ZoraRiverHouse 5.

**Weather**: 182 filas.
- `WeatherRate` (lluvia, tormenta, arena, nieve, ventisca, en %) solo es distinto de cero en 4: nieve al 100 % en 2, ventisca al 100 % en 1 y arena al 100 % en 1. `Timespan` va de 30 a 90 s en los ciclos de nieve.
- **La meteorología se trata como estado fijo de la zona**, no como clima aleatorio.
- **`mTemperatureLevel` por franja horaria (mañana, tarde, atardecer, noche) de 0 a 4**: el 2 aparece en 157 filas. [D] Escala:
  - 0 = frío extremo: `FieldHebraMountains`, `FieldSnowyMountains`, `FieldHeavySnow`.
  - 1 = frío: `SDungeonIce_*`, `BossDeguZol`.
  - 2 = neutro.
  - 3 = suelo caliente: `*_HotFloor`.
  - 4 = calor extremo: `FieldDesert`, `FieldVolcanoHigh`, `*_Lava`.
  - Solo 2 filas cambian la temperatura según la hora.
- `OverwriteConditions` en 11 climas: la condición fuerza un tipo de tiempo (`WeatherUnlock`, `WeatherUnlock_SnowyMountain`, `LanmolaSandStorm*`).
- `mRainSingDuration`: 0 en 144, 2 en 22, 1 en 9 y 3 en 7.

**SkySphere**: 10 cielos. **ShadowMapSettings**: 11 presets de caja y distancia de sombra. `ShadowMapSettingsForLevel` (12) y `ShadowMapSettingsForRegion` (2, jefes con techo alto) los **asignan por nivel o región**, de modo que los ajustes se definen una vez y se reutilizan.

**RegionEntryDemo**: 18 entradas con la clave `Nivel:Región:Enter|Leave`. Cada una lanza un evento si se cumple una condición y no está puesto su flag de "ya visto" (p. ej. `Field:Desert:Enter`, que solo se ve una vez).

**RegionItemDrop**: 6 perfiles de botín por región para cántaros y cajas: NoEffect, Forest, Sea, Desert, Early y Hebra.

**HorseRegion**: 33 hashes de región donde se permite el caballo. Es una lista blanca.

**CrackRegion**: 29 grietas. Cada una tiene `mVertices` (desplazamiento y número dentro de un búfer de vértices; el polígono está en otro bloque) y un **intervalo de vida**: `mActivateFlag` → `mDeactivateFlag`. Por ejemplo, `HyruleClear`→`EvF_WorldGlobeActivate` se repite 6 veces.

**Otros [M]**:
- `TraverseLevelList` (28 niveles por los que se puede viajar).
- `MajorDungeonDefinition` (27: 8 grandes y 19 pequeñas).
- `ReferenceDungeonDataList` (8: cada "Vacío" de campo apunta a la mazmorra que reutiliza sus datos).
- `InstancedModelList` (28 modelos de vegetación instanciada; `ShapeVisibilityFlag` 1 en 18 y 3 en 10).
- `ShaderList` (81).

### 3b. Patrón
- **Región = volumen que aplica un perfil compuesto por referencias** (cámara, clima, cielo, audio, partículas, botín, temperatura, reglas de tiempo). Cambiar de región es mezclar perfiles en `mBlendTime` (0,1 s en interiores y 5 s en exteriores).
- **Presets nombrados y reutilizados** (sombras, cielos, climas) y tablas de asignación aparte.
- **El ambiente es jugable**: la temperatura de 0 a 4 condiciona la supervivencia (hay accesorios y batidos de resistencia al frío y al calor; ver §4), y la arena o ventisca se activan por condición.
- **Contenido con intervalo de flags** (CrackRegion): existe entre la flag A y la flag B. Es un patrón muy barato para el mundo cambiante.

### 3c. Para Magic Symbols
1. **`Region` como recurso** (`region.tres`): cámara (iso/lateral), luz, niebla, música, **temperatura base (0-4) y humedad**, botín de objetos rompibles y "condición de parada de tiempo". El nivel de letras marca qué región cubre cada zona. La temperatura alimenta el estado del suelo: en una región de temperatura 0 el agua lanzada se hiela sola, y en una de 4 se evapora o el suelo se seca. **Emergente sin `if`.**
2. Mezcla al cambiar de región: 0,1 s en interiores y 5 s en exteriores.
3. **Presets nombrados** para sombras y cámara, asignados por nivel en una tabla aparte.
4. **Intervalo de flags (activar/desactivar)** para cualquier elemento del mapa que aparezca o desaparezca con la historia.
5. **Demo de entrada a región** con condición y flag de "ya visto": un tutorial la primera vez que entras en la zona de hielo.

---

## 4. Economía, botín, progresión y retos

### 4a. Lo que hay [M]

**Items**: 240 filas.
- Familias: Smoothie 70, **Reserved 56** (IDs reservados de antemano), Ornament 30, SmoothieIngredient 16, ZeldaClothes 11, ItemQuest 6, ItemMachineUnlock 4, y Sword, Bomb y Arrow con `Lv`.
- `reobtainable`: true en 129 y false en 111.
- `jingle`: 217 pequeño, 20 grande y 1 de contenedor de corazón.
- `ability` (multiplicadores de botín mientras lo llevas): dropMoreRupee 6, Heart 1, Fairy 1, MorphEnergy 1 y **dropMoreCoupon 30** (batidos).
- 4 flags de "¿puede aparecer?": tras desbloquear la copia, en la última mazmorra, en modo difícil y durante eventos.
- `physical` (masa, arrastre, bloqueos de eje): 13 perfiles y 219 objetos con el perfil por defecto.

**ItemDrop**: 118 tablas de lotería.
- `mLotTable` es una lista de (tipo, cantidad o índice, peso). 61 tablas tienen una sola entrada.
- La suma de pesos es 100 en 88 tablas (porcentaje directo), 200/400 en 14 y 1 en 11.
- **Tipo vacío = "nada"**: P(nada) es 0,94 en hierba y en `OBJ_Early`, 0,74 en `OBJ_Sea` y `OBJ_Desert`, 0,65 en `OBJ_Hebra` y 0,50 en árboles.
- **Cambio "en apuros"** (`mPinchKey`) en 21 tablas. Con poca vida se usa `Pinch` (corazón al 15 %) en lugar de la tabla normal (`NormalLow`: corazón al 3 % y rupia verde al 97 %).
- `mAllowBuffReplace` (18) y `mAllowRupeeReplace` (33) permiten que los batidos de botín cambien el resultado.
- `mCookie`: es la cantidad en las tablas normales (1 en 203 entradas, hasta 5). En las 24 tablas `WorldGlobe*` es el **índice único** del coleccionable.
- Escalado por región de cántaros y cajas: cada región añade **sus ingredientes locales** (Sea: ingredientes 00/02/03; Desert: 02/03/04; Hebra: 02/03 y 11 con doble peso).

**EnemyLottery**: 39 tablas de qué enemigo sale. Tamaños: 26 de 1, 10 de 2 y una de 12 (`LastBoundary`, 12 enemigos con peso 9 cada uno). `EnemyZeldaPastePhase1-3List` define las fases del jefe copia: `mMax` de 2 a 6 y pesos con `mIsSelect`.

**BottleContent** (73 batidos y medicinas):
- `mEffect1` y `mEffect2` son (tipo, cantidad).
- Tipo 1 = curar, con cantidades 2…80. Tipo 2 = energía, con 10…40. Tipos 3-12 = **buffs de 300 s**.
- [D] Por el orden de iconos en `UiBuffIconBottleContent` y de las etiquetas de buff: 3 = reducir daño, 4 = buceo, 5 = dar cuerda, 6 = nadar, 7 = trepar, 8 = frío, 9 = fuego, 10 = rayo, 11 = hielo, 12 = luz.
- 20 batidos tienen un solo efecto y 53 tienen dos.
- `mSoldPrice` entre 5 y 75, con escalones de 25, 30, 35, 45, 50 y 75.

**UiItemMenuList**: 16 ingredientes. Cada uno tiene `mBottleContentEffectKind` (0 o 1) y `mAmount` (1, 2, 4 u 8), y precio de 5 a 150. **[D]** Cada ingrediente aporta una cantidad de curación y el batido resultante suma o deriva de sus ingredientes. La tabla de recetas (16 ingredientes → 70 batidos) **no está** entre estas tablas.

**ShopItem**: 37 tiendas y 42 artículos (32 tiendas tienen 1 artículo).
- Precios: 30 en 20 artículos, 50 en 8, y 10-80 y 350-500 en los especiales. Solo 1 tiene descuento distinto del precio.
- Cada artículo tiene `mCondition` (30 `true`, 6 `L001Clear`, `NotHaveOrnamentNN`). Es **inventario condicionado por datos**: aparece cuando se cumple la condición y se agota cuando ya lo tienes.

**CrowlyList**: 16 entradas que convierten "rupias robadas" en monedas a devolver. [D] Con valores 5/20/50, lo devuelto ≈ lo robado − 5 (10→5, 30→30, 100→95). Es una pérdida pequeña y fija.

**Stamp/StampCard**: 25 sellos en 5 tarjetas de 5. Las recompensas van por condiciones de tipo 34.

**BattleChallenge**: 15 retos.
- Cada reto tiene una condición de desbloqueo (mazmorras superadas: `DungeonCleared_Volcano_Jungle_SnowMountain`...), un objetivo (`mDefeat` con límite de 600 s; los jefes 3600 s) y **3 rangos de tiempo con premio**. Ejemplo: 60 s → 5 ingredientes 03; 40 s → 5 ingredientes 05; segunda vez 40 s → 3.
- Hay **reglas de prohibición**: sin bomba, flecha ni espada de Link en 4 retos. Esos 4 son los mismos que tienen `mConditionNumber=4`, `mStartRule=0` y **`mPartnerLevel=2`** (capacidad reducida). También pueden **fijar los contenedores de corazón** (2 o 5).
- `BattleChallengeGrade`: premios por número de retos superados (2, 4, 6, 8, 11 y 14).

**Minijuegos**: `PickUpAcornsStageData` tiene 5 fases con 2 umbrales de tiempo cada una (A/B) y bonus. `GerudoMiniGameStageData` tiene 3 fases con objetivos 50/40, 60/50 y 70/60.

**UiMachineSelect**: 6 autómatas con precio de reparación de 50 a 100; el descuento es siempre el 50 %.

**Otros**:
- **TecuumList**: 68 formaciones de aparición. Tienen de 1 a 3 enemigos; los ángulos más usados son 90 y 270 y la distancia, 3 o 4,5. Cada enemigo tiene variante de tierra, aire y agua.
- **WallCrackedList**: 13 muros rompibles con escala de colisión (1,5 × 1,5 × 0,75…4,5) y material.

### 4b. Patrón
- **Lotería con pesos y "nada" explícito**. Escalado por región **añadiendo ingredientes locales**, no subiendo números.
- **Red de seguridad por estado** (`mPinchKey`): el juego cambia de tabla cuando vas mal. Es el *rubber banding* declarado en datos.
- **Efectos como (tipo, cantidad, duración)**. Un consumible es una lista de como mucho 2 efectos. Hay 13 tipos de efecto y los buffs duran siempre 300 s.
- **Inventario y tiendas condicionados por referencias a Conditions.**
- **Retos = (desbloqueo, objetivo, 3 umbrales, restricciones del jugador)**. Las restricciones incluyen **bajar la capacidad de copia** (`mPartnerLevel`) y prohibir herramientas, lo que obliga a jugar con un subconjunto del sistema.
- **IDs reservados** (56 `Reserved`) para añadir objetos sin reordenar IDs ni romper partidas guardadas.

### 4c. Para Magic Symbols
1. **Ingredientes con (tipo, cantidad)** y síntesis de mejoras como suma o derivación de efectos. Encaja con la "síntesis" prevista. Conviene mantener la tabla de recetas aparte, como hace EoW, o mejor **no tenerla** y calcular el resultado sumando efectos: que emerja.
2. **Consumibles y mejoras como lista de efectos [(tipo, cantidad)]** con un enum corto de tipos, que incluya **resistencias por elemento** (fuego, hielo, rayo, frío): enlaza con la temperatura de región (§3).
3. **Botín**: `ItemDrop` con peso para "nada", perfil por región que añade el ingrediente local y tabla `apuros` cuando la vida baja. Muy barato de implementar.
4. **Retos de práctica** que limiten glifos o páginas (`glifos_prohibidos`, `paginas_max`), con 3 umbrales de tiempo. Enseñan combinaciones a la fuerza.
5. **Reservar IDs** en las tablas de glifos y objetos desde el principio.

---

## 5. Interfaz definida por datos (ui/*)

### 5a. Lo que hay [M]
- **UiMap** (32 niveles): `mUiMapLevelType` 0 = campo (1), 1 = Vacío/Boundary (8), 2 = mazmorra grande (8) y 3 = pequeña (15). Cada nivel guarda número de pisos (1 en 25, y luego 2-5), zooms (`[1,2]` en 23, `[0,7;1;2]` en 8 y `[0,95;3;9]` en el campo), si tiene minimapa (24/32), si muestra la hora, la última sala y el nivel "padre" (`mOtherLevelKey`).
- **UiMapArea** (192 salas del mapa de mazmorra): posición y prioridad. En 32 salas hay 34 reglas `mChangeTexutreInfo` (flag → textura), por ejemplo `L001R002DodgeRock` → `L_Dungeon001_002_c_00`. **El mapa refleja el estado del mundo cambiando textura según flags.**
- **UiMapLine** (9): líneas entre salas con esquinas, para conexiones entre pisos.
- **UiMapIcon** (15 tipos): layout, escala por zoom (3 valores) y por tipo de mapa, si es seleccionable y cómo se comporta en la tormenta de arena.
- **UiMapIconSensorLevelOpen** (106) y **…Pair** (96): iconos que se descubren con un sensor (66 de mazmorra pequeña, 15 de ciudad, 6 de tienda) y pares de entrada y salida entre niveles.
- **UiWarpSet**: 2 conjuntos de destinos de teletransporte (51 y 53), cada uno con su flag de desbloqueo.
- **UiLocationInfo** (117): cartel al entrar en un lugar. Guarda tipo de campo (0 en 84, 2 en 24, 1 en 9), si muestra HUD (100) o rupias (6) y una condición de visibilidad (7).
- **UiOperation** (64 contextos): por cada estado de la jugadora (Carry, Swim, Sync, ActorSelect, menús…) lista de 0 a 5 pares (botón, etiqueta). Los botones más usados son el 1 (44 veces) y el 0 (38). **La ayuda de controles es una tabla por contexto, no código en cada estado.**
- **UiTutorialModal** (18): título, flag de completado y 1 o 2 páginas (con imagen en 2). `mSaveIndex` va de 0 a 17 sin huecos (un bit de guardado por tutorial). **UiTutorialInsert** (10): mensaje en línea con el botón a mostrar y los botones que lo cierran (p. ej. cámara: [9, 26]).
- **UiCollectMenu** (34) y **UiItemMenuGrid** (26): la navegación del menú es **un grafo explícito** (índice arriba, abajo, izquierda, derecha y si repite al mantener).
- **UiActorSelect** (127): orden del selector de ecos (`mPriority`) y texto de enciclopedia.
- **UiBuffIcon\*** (13 + 22): icono por tipo de efecto y nivel.
- **UiAccessory** (28) y **UiDressUp** (11): nombre y descripción por símbolo.

### 5b. Patrón
- La UI **no conoce el juego**: lee tablas que dicen qué icono, qué texto, qué botón y cuándo (condición o flag).
- El mapa es **una vista del estado de flags** (`mChangeTexutreInfo`).
- La navegación de menús por grafo explícito elimina la lógica de foco.
- Los tutoriales son registros con índice de guardado fijo.

### 5c. Para Magic Symbols
1. **`ayuda_controles.tres`** por estado (dibujando, apuntando, en menú…), con la lista de (acción, texto). El HUD solo pinta.
2. **Tutoriales**: tabla con flag de "visto" e índice estable. **Inserts** con el botón a mostrar y el que lo cierra.
3. **Mapa por salas** (posición y textura) con reglas flag → textura para reflejar puertas abiertas o hielo derretido.
4. **Libro de glifos**: orden por prioridad (los recientes arriba) y texto de enciclopedia por glifo, en tabla.
5. Iconos de buffs y estados de suelo: una tabla tipo → icono, sin `match` en el HUD.

---

## 6. Motionsheets (hojas de movimiento por actor)

### 6a. Lo que hay [M]
En el ordenador hay unas 300 hojas. He analizado Player, Zelda, Partner, Octorok y Pot, más Darknut00/02, MoriblinSword00/02, Zol/ZolFire/ZolBoundary/ZolMachine, SwitchFoot, DoorClose, Geyser, Trampoline, Player_abs y _RetargetingHylian.

**Esquema común (8 campos)**: `mMotionName` (clave lógica), `mDataName` (clip real), `mAnimPolicy`, `mInterpolateSeconds`, `mNextMotionName`, `mRootMotionOffset`, `mBoneInfo[]` y `mFacialName`. **No contienen parámetros de juego** (vida, daño). Son la **capa lógica de animación**: nombre lógico → clip, mezcla, encadenado y expresión facial.

| hoja | filas | policy 0/1/2 | con siguiente | alias (`mDataName≠mMotionName`) | root motion | caras distintas |
|---|---|---|---|---|---|---|
| Player | 383 | 130/90/163 | 60 | 29 | 4 | 12 |
| Zelda | 634 | 215/128/291 | 168 | 57 | 15 | 10 |
| Partner | 95 | 4/0/91 | 25 | 3 | 7 | 2 |
| Octorok | 45 | 18/25/2 | 5 | 17 | 0 | 1 |
| Pot | 5 | 2/3/0 | 1 | 0 | 0 | 1 |

- `mAnimPolicy` [D]: 0 = una vez, 1 = bucle y 2 = lo que diga el clip. **Las animaciones encadenadas (`mNextMotionName`) nunca tienen política 1** (40 + 20 en Player y 98 + 70 en Zelda solo con políticas 0 y 2): un bucle no se encadena.
- Sufijos de convención: `_st` (inicio), `_lp` (bucle), `_ed` (final), `_pre`; en Zelda hay 100, 113, 79 y 57. Cadenas típicas: `damage_press_st` → `damage_press_lp`, `damage_blowaway_ed` → `down_lp`.
- Mezcla: 0 s (176 en Player), 0,1 s (101), 0,05 s y 0,2 s.
- `mBoneInfo` siempre está a "NONE" en la muestra (0 casos).
- **Alias**: por ejemplo `move_barehands_f` → `move_f`, para reutilizar clips con otro nombre lógico.

**Vocabulario común de reacciones** [M]. De 18 movimientos estándar (`damage_burn`, `damage_electric`, `damage_freeze`, `damage_inhaled`, `dead_burn`, `dead_electric`, `fall_lava_lp`, `fall_water_lp`, `fall_abyss_lp`, `fall_quicksand_lp`, `interest`, `fear_lp`, `thrown_lp`, `pose_copyobject`, `sync_burst`, `stun`, `damage_blowaway_lp`, `damage_press_lp`):
- Darknut00, Darknut02, Octorok, Zol, ZolFire, ZolBoundary y ZolMachine tienen **los 18**.
- MoriblinSword00 y 02 tienen 17 (les falta `fear_lp`).
- **[D]** Todo enemigo cumple un **contrato de reacciones a elementos y entorno**. Por eso cualquier eco o elemento funciona contra cualquier enemigo: las combinaciones emergen porque el contrato es uniforme.

**Variantes = base + diferencias** [M]:
- ZolBoundary tiene 42 de 43 filas idénticas a Zol.
- ZolFire comparte 40 y solo pierde `pop`, `wait_under` y `depop`.
- ZolMachine añade 13 (montaje, cuerda, ataque de nota…).
- Darknut02 = Darknut00 menos 6 movimientos de un evento.
- **MoriblinSword02 añade 19 movimientos de escudo y estocada** (`guard_*`, `sync_shield_break`, `sync_shield_catch_lp`) sobre la base de 44. **El escudo es un componente que trae su propio paquete de animaciones y su reacción al compañero.**

**Hojas especiales**:
- `Player_abs` (tabla interna `Zelda_abs`, 37 filas): **selector de animación por expresiones**. Cada clave (`wait`, `move`, `wand_copy_st`… y las variables `TYPE`, `DIR`, `COLD`, `BAREHAND`, `IS_LADDER`, `LOOKBACKTYPE`) tiene de 1 a 9 ramas (condición → resultado) más un valor por defecto.
  - Los operandos van en un formato con etiquetas de cadena. Se leen variables como `actionDir` o `locomotion` y resultados de texto: sufijos `_f`, `_b`, `_u`, `_d`, `_r`, `_l` según `actionDir` 0-5, y prefijos `swim_`, `ride_horse_` o `ladder_` según `locomotion`.
  - **[D]** El nombre final de la animación **se compone**: prefijo (modo de locomoción) + base + sufijo (dirección). No hace falta escribir cada combinación a mano.
- `_RetargetingHylian` (124 filas): misma estructura, compartida por todos los NPC de esa especie mediante retargeting.
- Interruptores y puertas: `SwitchFoot` tiene 3 movimientos (`wait_on`, `wait_off`, `on`), `DoorClose` 12 (variantes delante, detrás y agua), `Geyser` 38 (alturas de agua por pasos 0→1→2), `Trampoline` 3.

**Facial** (36 juegos de expresiones; Link 27 y Zelda 40) y **Zelda_vb** (5 huesos virtuales: Sight, OverHead, Ahead, SyncPoint, CenterRT, con desplazamiento relativo al hueso o al actor). Son puntos de anclaje por datos para cámara, efectos y apuntado.

### 6b. Patrón
- **Separar el nombre lógico del clip** permite reutilizar clips, encadenar fases st/lp/ed por datos y mezclar por transición.
- **Contrato de reacciones uniforme** para todos los enemigos. Es la base técnica de la emergencia.
- **Variante = base + delta** (escudo, máquina, versión elemental).
- **Composición de nombres de animación** por variables (dirección y modo) con un pequeño evaluador.

### 6c. Para Magic Symbols
1. **Tabla de movimientos por actor** (`movimientos.tres`): nombre lógico → nombre del clip o de la tira de sprites, política (una vez, bucle o la del recurso), siguiente movimiento y mezcla. En isométrico 2D sirve igual con AnimatedSprite: `quemado_st` → `quemado_lp`.
2. **Componer el nombre**: `prefijo_estado + base + sufijo_dirección` (8 direcciones iso: `_n`, `_ne`…). Un único resolutor sustituye cientos de entradas. Útil para el PIPELINE de sprites, y no es tarea de este contexto: aviso al otro contexto.
3. **Contrato obligatorio de reacciones para todo enemigo**: `daño_fuego`, `daño_rayo`, `congelado`, `empujado_viento`, `caer_agua`, `caer_vacío`, `aplastado`, `atraído`, `aturdido`. Si un enemigo no tiene la animación, se usa una genérica, pero **el estado lógico debe existir siempre**. Así cualquier sello afecta a cualquier enemigo.
4. **Componentes con su paquete de animaciones**: el escudo añade `guardia_*` y `escudo_roto`, y el componente "escudo que arde" añade `escudo_quemado`. Encaja con "base + componentes".
5. **Puntos de anclaje virtuales** (cabeza, frente, centro) por datos para que glifos y VFX apunten sin código.

---

## 7. Resumen de cifras clave

| dato | valor |
|---|---|
| ecos | 128 (93 monstruos y 35 objetos) |
| distribución de coste (1-6) | 33/35/33/18/8/1, suma 320 |
| grupos de reducción | 0: 45; del 1 al 6: 14/14/14/14/14/13 |
| objetos ajustados a la rejilla | 35/35; monstruos 10/93 |
| tamaño de celda deducido | 1,5 unidades (101/128 filas cumplen Y = 0,75·mHeightDouble) |
| energía total del compañero | 1000 (61 extraviados → 300; 7 jefes → 700) |
| piezas de poder | 150 puntos repartidos en 150 ubicaciones |
| condiciones | 479 (440 AND, 39 OR, 71 % atómicas, 132 plantillas `$n`, 22 anidadas) |
| interruptores locales | 8 por sala (índices 0-7) |
| flags globales | 1624 (unos 189 de prueba; 32-49 por mazmorra grande) |
| variables de evento | 26 con 261 estados; 107 misiones |
| regiones | 334 (41 tipos de cámara, 170 climas, 59 con parada de tiempo) |
| temperatura | 0-4, con el neutro 2 en 157/182 climas |
| tablas de botín | 118 (P(nada) de 0,5 a 0,94 en objetos rompibles) |
| batidos | 73; 13 tipos de efecto; los buffs duran 300 s |
| retos | 15; 4 con capacidad del compañero limitada a nivel 2 |
| hojas de movimiento | ~300; 7 de 9 enemigos muestreados cumplen los 18 movimientos de reacción y los otros 2, 17 |

## 8. Qué no está en las tablas (límites del análisis)
- Las cantidades de reducción de coste por grupo y los umbrales de nivel del compañero (energía → triángulos máximos).
- Las recetas de batido (ingredientes → resultado).
- La geometría de las grietas (`mVertices` apunta a un búfer externo).
- Los nombres de los enums. Todos los significados de enums de este informe son **deducciones** a partir de nombres de filas y de orden.
