# Informe: actores, reacciones, kodama, eventos y tailor en *Echoes of Wisdom* (estudio)

Objetivo: entender **cómo** se resolvieron problemas técnicos (composición de actores, reacciones
elementales, eventos por datos, salas que se cierran, interruptores) para sacar **conclusiones
propias** para Magic Symbols. No se copia ningún dato ni asset al juego. Este informe no reproduce
textos del juego.

Marcas: **MEDIDO** = sale de contar o decodificar los archivos. **DEDUCIDO** = interpretación mía
(razonable, pero sin confirmar). **DESCONOCIDO** = no se ha podido descifrar.

Scripts (todos en `scratchpad/eow/actores/`, se ejecutan con `python3 -I`):
- `cbor.py`: decodificador CBOR mínimo. `crack.py` + `hashes.py`: resolución de hashes CRC32.
- `analiza.py`: estadística de componentes (salida en `salida_analiza.txt`, `tipos_detalle.txt`,
  `tipos_refs.txt`, `subtipos.txt`, `componentes_por_actor.json`).
- `apd.py`: lectura exploratoria de `ActorProfile.apd` (salida en `apd_categorias.json`).
- `bfevfl.py`: lector de EventFlow v3. Los flujos legibles están en `eventos/*.txt` (29 archivos).

Datos traídos: los **450 .bfactr** (todos los de la carpeta), 30 .bfevfl + `common.evhb` +
`defhash.bin`, 17 .drsb (de 659), 2 .kobin (los únicos que hay).

---

## 1. `.bfactr`: definición de actor = lista de componentes

### 1.1 Formato (MEDIDO)
- Es **CBOR** estándar (RFC 8949), un único objeto por archivo. Los 450 archivos se decodifican sin
  errores.
- Las **claves de los mapas son CRC32 (zlib) del nombre del campo**. Confirmado con 70 nombres:
  `name`=0x5e237e06, `components`=0xee48f5fd, `mComponentName`=0xa3d86fb1, `mAttribute`,
  `mWindPower`, `mReactionSchema`, `mLifeSchema`, `mStackSchema`, `mFrozenSchema`, etc.
- **El tipo de componente también es el CRC32 del nombre de la clase**: por ejemplo,
  `SkeletalModelComponent`=0xf743bab1 y `BurnAttackCollisionComponent`=0x7f87bf50.
- Estructura:
  ```
  { name: "Zol",
    components: [
      { tipo: crc32(Clase), 0x2326f98a: 0 (a veces 1/2/4), 0x7c82bee7: "",
        params: { mComponentName: "BurnComp", ...referencias... },
        0x70bea1aa: null | [ {tipo: crc32(SubClase), params:{...}} , ... ] },   <- submódulos
      ... ] }
  ```
- Los parámetros **casi nunca son números**. Son **referencias**:
  - a otros componentes del mismo actor, por su nombre de instancia (`"CharaCtrlComp"`,
    `"LifeComp"`, `"DefenseColComp"`, `"TailorPlayerCom"`). Es inyección de dependencias por nombre;
  - a datos de *kodama* como **cadenas de ruta**, por ejemplo
    `kodama::GetZol().mZolSchema.mReaction` o `kodama::GetGrass().mGardenerOutputInfo.mHotSphere`.
  Se cuentan **5.592 referencias kodama**. Solo 20 actores no tienen ninguna.
- Campos repetidos en los componentes "con presencia física": `0xa864849b` (7 en 2.228 casos,
  3/1/5 en el resto; DEDUCIDO: máscara de capas o mundos) y `0xe1c39492`/`0x37d7064b` (componente
  de esqueleto + nombre de hueso, p. ej. `"SkeletalModelCom"`/`"eye"` en los sensores de Ghoma,
  es decir, colgar la colisión de un hueso).

### 1.2 Estadística global (MEDIDO)
- **450 actores**, **122 tipos de componente** distintos y **11.940 instancias** de componente.
- Componentes por actor: media 26,7, mediana 17, mínimo 1 (balas mínimas), máximo 74 (Dandarma).
- Por familia (clasificación mía por nombre): enemigo 151 (media 38,9 componentes), Boundary 21
  (51,6), proyectil 67 (**4,2**), jefe o parte 51 (20,4), objeto 53 (34,4), plataforma 16 (26,3),
  vegetación 25 (18,8), recogible 48 (16,1), interruptor 14 (**9,7**), NPC o patrulla 4.
- **Submódulos**: 102 tipos y 4.881 instancias anidadas dentro de componentes. Ejemplos: la
  colisión de quemado tiene una variante por forma (esfera 0xc906f917, caja 0x78b32e4f, cápsula
  0x32fbcd58) y el componente de líquido aloja hasta 4 manejadores (flotar, sumergirse, sobresalir
  de la superficie).
- Nombres resueltos: 48 de los 122 tipos (39 %) y 38 de las 289 claves. Los demás se nombran abajo
  con `?hash` y una etiqueta **DEDUCIDA** a partir de qué datos referencian.

### 1.3 Componentes más usados (MEDIDO: nº de actores que lo usan, sobre 450)
| n | componente | qué es |
|---|---|---|
| 441 | ActorTailorPlayerComponent | reproductor de "tailor" (efectos y sonido, ver §5) |
| 384 | SkeletalModelComponent | modelo |
| 355 | ?af021674 | DESCONOCIDO (un único booleano a true) |
| 284 | ActorMaterialAnim (instancia) | animación de material |
| 242 | ?a01dbf08 | DEDUCIDO: interacción con superficies líquidas (submódulos LiquidSphere y ProtrudeWaterSurface) |
| 241 | MessageDelivererComponent | buzón de mensajes entre actores |
| 228 | BattleUnitComponent | unidad de combate (bando, objetivo) |
| 228 | AttackCol (instancia) | colisión de ataque |
| 211 | LockedOnByPlayerComponent | se puede fijar como blanco |
| 211 | CharaCtrlComp (instancia) | controlador de personaje (cuerpo físico) |
| 201 | RBfresBoundaryComponent (inst. DefenseColComp) | colisión de defensa (recibe golpes) |
| 189 | ?6964a3a1 | **Reacción** (`mReactionSchema` + LifeComp) |
| 188 | LifeComponent | vida (`mLife`) |
| 173 | GrossWeight (instancia) | peso y apilado (`mStack`) |
| 159 / 154 | ?b75f7569 / ?1799f145 | **receptores de viento** (`mWindParam`) |
| 148 | HotSphereComponent | **esfera de calor**: emite o detecta fuego |
| 141 / 138 | CommonCounterInteractor / ContactAttackInteractor | interactores de contraataque y daño por contacto |
| 136 | BurnComp (instancia) | **estado de quemarse** |
| 136 | EventCharacterComponent | se puede manejar desde EventFlow |
| 119 | ?1dc47e03 | buscar objetivo (`mFindTarget`) |
| 118 | DoActionComponent | interacción con el botón de acción |
| 114 | ?8e2b22ce | **ser presa** (`mPreyedReaction`, `mEnablePreyed`) |
| 107 | ?58c4eb14 (+?0f2ca740) | **llevar y lanzar** (`mCarryParameter`, `mThrowAttack`, `mCarryableOffset`) |
| 96 | ?144b6699 | **empujable y agarrable** (`mPush`, `mCanGrab`) |
| 91 | ?0b0df5b1 | **descarga eléctrica recibida** (`mElectricShock`) |
| 87 | ?f6a051ea | **congelación** (`mFrozen`) |
| 72 | ?018d3763 | robable por Crowly (`mCrowlyStolen`) |
| 71 | ?bf0dedcb | sumergirse o ahogarse (`mSubmerged`) |
| 69 | GridOwnerComp | ocupa celdas de la rejilla (`mAttribute`, `mMedium`, `mPivot`) |
| 58 / 19 | BurnAttackCollision / BurnDefenseCollision | **propaga fuego** / **se puede prender** |
| 52 | ?183b05a6 | atrapado en telaraña (`mInSpiderWebObserver`) |
| 142 | ?452a8811 | muerte por entorno (`mDeadLava`; referencia a Life y Burn) |
| 13 | EnergizationComponent | **está electrificado** (Biri, BuzzBlob, Spark, Keese03…) |
| 4 | ExtinguishComponent | **apaga fuego** (Freezard, Toppyu, ZolWater) |

### 1.4 Combinaciones típicas por familia (MEDIDO, % de actores de la familia)
- **Enemigo**: Tailor 98 %, modelo 95 %, BattleUnit 72 %, LockedOn 70 %, AttackCol 68 %,
  CharaCtrl 67 %, viento ~70 %, Reacción/Life ~57-60 %, CommonCounter 58 %. A eso se suman los
  módulos de entorno (Burn, Frozen, Electric, Submerged, Preyed, Carry…).
- **Objeto empujable o llevable** (Pot, BoxWooden, Bed, BigRock…): Life 71 %, GrossWeight 75 %,
  CharaCtrl 77 %, viento 71 %, GridOwner + ?fddd8ec7 + ?5b0a46b6 (rejilla), **?4d318799 =
  `mFallAttack` (hace daño al caer encima)**, Push/Grab y Carry. Pot tiene 53 componentes y
  BoxWooden 51; **BoxWooden = Pot + Burn + HotSphere + BurnAttackCol − FallAttack − …**
- **Interruptor** (SwitchFoot, 8 componentes): CollisionComp (forma calculada por el Gardener),
  GridOwnerComp (con `mAttribute`=0), modelo, animación, Tailor, EventCharacter, ?4d9f00f6
  (DEDUCIDO: sensor de carga o pisado; lo comparten 34 actores: interruptores, ascensores,
  balanzas, pedestales) y ?af021674.
- **Recogible** (Item*): CollisionComp 89 %, ?4d963f09 / ?e1c47ab2 (arenas movedizas) 100 % / 95 %,
  **viento propio de ítem** ?e077c3a8 (25 de 26 lo tienen ítems), RBfresBoundary. **Sin Life ni
  BattleUnit.**
- **Proyectil** (Bullet, Arrow…): de media 4 componentes (AttackCol 89 %, Tailor 98 %, modelo
  35 %). Los proyectiles de fuego llevan HotSphere (26 %), Burn (20 %) y BurnAttack (19 %). **Las
  flechas llevan BurnDefenseCollision**: se prenden al cruzar fuego.
- **Vegetación** (Grass, Lawn…): Burn 76 %, HotSphere 76 %, BurnAttack 76 %, Life 84 %, Reacción
  84 %. Es un objeto mínimo "que arde y propaga".
- **Boundary** (variante del mundo distorsionado): **son el mismo actor con un cambio pequeño**.
  `Zol → ZolBoundary`: −?018d3763 (robable por Crowly) +?8b9f0919. Pasa lo mismo en Keese, Lynel y
  el resto: ?8b9f0919 es exclusivo de 16 de los 21 Boundary. Sus datos kodama son paralelos
  (`kodama::GetZolBoundary()…`).

### 1.5 Variantes elementales = quitar o poner componentes (MEDIDO)
- `Zol → ZolFire`: −?e734edfc, +2 AttackCol (ataque de fuego). La base Burn/HotSphere ya estaba.
- `Zol → ZolWater`: **−BurnComp −HotSphere −Submerged −?e734edfc, +ExtinguishComponent**.
- `Octorok → Octorok01` (acuático): −Burn −HotSphere −DeadLava, +Submerged +líquido.
- `BoxWooden → BlockIce`: −Burn −HotSphere −BurnAttackCol −Carry −DoAction, +?5f91c349
  (DEDUCIDO: "es de hielo / se derrite"; está en BlockIce, Freezard, SnowBall, QuestSnowBall,
  SnowBallInduce y DandarmaBullet) +?9ba92a1d (detección de líquido y `mWarmSphere`).
- `Freezard → Bonfire`: −Extinguish(×2) … +Burn +BurnAttack +BurnDefense +HotSphere.

**Conclusión DEDUCIDA:** no existe un campo "elemento = fuego". **La identidad elemental de un actor
es qué componentes de emisión y recepción tiene.** Fuego se divide en: *emite calor* (HotSphere),
*propaga llama* (BurnAttackCollision), *se puede prender* (BurnDefenseCollision, o el DefenseCol
genérico como receptor de Burn), *está ardiendo* (BurnComp, con estado `mIsActivate`) y *apaga*
(Extinguish). Electricidad: *está electrificado* (Energization) y *recibe descarga* (ElectricShock).
Hielo: *se congela* (Frozen) y *es hielo* (?5f91c349). Agua: LiquidSphere, Submerged y
ProtrudeWaterSurface. Viento: WindParam (dos variantes, más una propia de ítems). Todos los números
(radio, daño, tiempos) viven en kodama, no en el .bfactr.

### 1.6 Material y atributo (MEDIDO)
- `GridOwnerComp.mAttribute` toma 3 valores en 69 actores: 0 = interruptores y PuzzlePanel (6),
  1 = objetos sólidos (Bed, Box, Rock, BlockIce, Cloud… 51), 5 = **objetos inflamables o de
  "superficie"** (Bonfire, Cactus, Charm*, Lamp*, Sandpile, Signboard; 12). `mMedium` vale 0 en
  todos. DEDUCIDO: es un atributo de la celda que ocupa el objeto en la rejilla (para colocar ecos
  y apilar), no un material de daño.
- No hay campos llamados Material, Element ni Attribute de daño en los .bfactr. El "material" se
  expresa con componentes y, para el sonido y los efectos, con el suelo que pisa (ver tailor).

### 1.7 ¿Qué hace "copiable" (eco) a un actor? (MEDIDO)
- **No es un componente: es una tabla de datos aparte**, `datasheets/CopyableActor.gsheet`, con
  **128 filas**. Cada fila tiene `mSymbol`, la categoría de UI (0 = criatura 93, 1 = objeto 35),
  `mPasteCost.mSlot` (coste 1-6; por ejemplo Lynel cuesta 6), `mPasteGridCount` (forma y huella en
  la rejilla), `mPastePlace` (ajuste a la rejilla y rotación), `mTriangleOffset` y `mHabitat`
  (13 valores).
- 109 de los 128 tienen .bfactr en region_common (los otros 19 viven en otro sitio).
- Componentes que distinguen a los copiables (copiables / no copiables): **?ed395428 100 % / 4 %**
  (los no copiables que lo tienen son variantes Boundary y alguna bala; DEDUCIDO: el aspecto de
  "eco pegado", porque referencia Tailor y ActorMaterialAnim), Life 100 % / 23 %, Reacción
  100 % / 23 %, GrossWeight (apilado) 98 % / 19 %, ContactAttack 91 % / 11 %. Es decir: un eco es
  "un actor normal con vida, reacción y peso" **más** una fila en la tabla de costes.
- `event/Copy.bfevfl` (12 entradas: Copied, Absorbed, FirstPaste, EnemyCopySuccess…) usa la
  consulta `FlowControl.CompareCopyableActor` y la acción `Hud.RegisterPasteSlot`.

---

## 2. `ActorProfile.apd`: el manifiesto de actores

- MEDIDO: cabecera `Bj 06 08`, una tabla de 252 buckets, **1.218 registros de 16 bytes**
  (desplazamiento del nombre, enlace, desplazamiento de datos y tipo), un *pool* de 3.417 cadenas
  (0x5030-0x18b58) y una zona binaria de nodos. Es un árbol clave/valor con cadenas deduplicadas.
- Claves que aparecen: `category`, `packages`, `properties` → `AudioGroup` (por ejemplo, un grupo
  de sonido por enemigo).
- `packages` = lista de recursos que hay que cargar: `actor/X.bfres`, `bfactr/X.bfactr` (y los de
  sus balas), `motionsheets/X.gsheet`, `tailor/X.drsb`, `virtualbonesheets/X_vb.gsheet` y
  `event/X.bfevfl`. Referencias contadas: bfactr 1.275, vb 757, tailor 752, bfres 732,
  motionsheets 322, event 163.
- `category` (extraída con heurística, DEDUCIDO ±): npc 356, obj_map 160, enemy 125, obj_basic 112,
  proj 100, obj_ev 71, boss 57, item 49, sensor 45, tag 42, map 38, obj 21, prop 15, test 12,
  obj_prop 10… Pot, BoxWooden, Grass y Bonfire caen en obj_basic; SwitchFoot en obj_map; balas
  en proj.
- **Conclusión:** el perfil **no contiene comportamiento**. Es categoría + qué archivos cargar +
  audio. El comportamiento está en el .bfactr y los números en kodama.
- Muy relevante: hay **42 "Tag*" y 45 "Sensor*"**, actores invisibles de lógica: TagRoomLocker,
  TagCheckerWipeout, TagSwitchChecker, TagConditionalActivator, TagSwitchOn, TagSyncObserver,
  TagEventSwitch, TagSnowBallSpawner, SensorFlagEnterBox, SensorEventBox, SensorRockfall…

---

## 3. kodama y "Gardener"

- MEDIDO: `.kobin` empieza por `Kobin\0`, seguido de un u16 de versión (0x2e o 0x29), un hash de
  esquema y un tamaño. Después vienen **registros binarios de tamaño fijo sin nombres de campo**
  (floats sobre todo) y al final la tabla de nombres de fila (`DungeonCommon`, `FieldCommon`,
  `BossGolem`…). Solo existen 2: `EnvironmentalEffect` (18.947 B) y `PlayRegionCamera`
  (5.105 B, perfiles de cámara por tipo de zona).
- MEDIDO: los .bfactr acceden a kodama con expresiones de "código"
  (`kodama::GetZol().mZolSchema.mReaction`). Hay 2.833 referencias a `mGardenerOutputInfo.*` y
  2.759 a esquemas de autor (`mZolSchema`, `mKeeseSchema`, `mPot`, `mGrassParam`,
  `mItemCommon`…). **287 referencias apuntan a los datos de OTRO actor**: las flechas Lv02/03 usan
  los de Lv01, 12 ítems usan `GetItemCoupon().mItemCommon`, los Piranha usan `PiranhaCommon` y
  QuestSnowBall usa SnowBall. Es herencia de datos sin herencia de clases.
- DEDUCIDO:
  - **kodama** es una base de datos tipada y compilada (el esquema vive en el código, por eso el
    .kobin no tiene nombres). Expone un *getter* por actor (`GetZol()`) y los componentes guardan la
    ruta al sub-registro que necesitan.
  - **Gardener** ("jardinero") es una **etapa de build que genera datos derivados**. Lo que produce
    es, sobre todo, geometría (`mCollisionPhysicalBox`, `mLiquidSphere` ×372, `mHotSphere`,
    `mBurnObjBox`, `mDefenseCollisoinSphere`…) y bloques estándar de reacción
    (`mWindParam` ×162, `mContactAttack` ×133, `mStack`, `mReaction`, `mBurnEnemy`, `mBurnObj`,
    `mPush`, `mFrozen`, `mElectricShock`, `mDeadLava`, `mCrowlyStolen`, `mInQuickSandObserver`…).
    Los actores sencillos usan solo la salida del Gardener; los complejos tienen su propio esquema.
  - No es un "ecosistema" de IA: es **un sistema de datos con generación automática**.
- DESCONOCIDO: los valores numéricos por actor (no están en region_common; posiblemente dentro
  del ejecutable). No se puede saber ni el radio de un HotSphere ni el daño de una quemadura.

---

## 4. `.bfevfl` (EventFlow v3)

### 4.1 Estructura (MEDIDO; lector propio `bfevfl.py`, verificado sobre 29 archivos)
- `BFEVFL` → 1 *flowchart* `EVFL` con: **actores** (nombre + subnombre, lista de acciones y lista
  de consultas que usa ese flujo), **eventos** de 5 tipos (acción, switch/consulta, fork, join,
  subflujo), **entradas** (puntos de entrada con nombre) y **contenedores de parámetros** tipados
  (int, bool, float, string, arrays, referencia a actor y **argumento** `$arg` = parámetro que se
  rellena al llamar al subflujo).
- Muestra de 29 flujos: 2.554 eventos (acción 1.830, fork 245, join 245, subflujo 137, switch 97) y
  205 entradas. Actores-servicio más usados: Timer 24, Partner 20, Audio 17, Player 16,
  GameControl 16, EventFlags 15, Camera 15, Fade 12, Enemy 11, Dialog 9. Consultas más frecuentes:
  `EventFlags.CheckFlag` (25), `Player.CheckMorph`, `Dialog.GetLastResult`, `CountFlags`,
  `CheckPlayerHit`.
- `common.evhb` = **jerarquía de clases de actores de evento** (Actor → Character → Enemy →
  Keese/Octorok…, Object → BigRock/Door/TreasureBox…, más servicios como Audio, Camera, Timer o
  QuestSystem). DEDUCIDO: las acciones se heredan por clase.

### 4.2 Casos de la muestra
- **SwitchFootTogether** (5 eventos): esperar → `Door.GenericGimmickSequence` (la cámara mira la
  puerta) → `Door.DoorOpen` → esperar → jingle de "puzle resuelto". **La lógica del interruptor
  no está aquí**: el flujo es solo la presentación.
- **SwitchFootLD002**: 5 colores (entradas SwitchRed…SwitchPurple). Cada una pone su flag y llama
  al subflujo `_FlagCheck`, que hace `EventFlags.CountFlags(5 flags)` y elige una animación de
  cámara distinta según cuántos van pisados (0-4). Con el 5.º pasa a `Final=true`. El "contador
  de interruptores" es **una consulta de datos sobre flags con nombre**.
- **TreasureBox** (236 eventos, 12 entradas): `TreasureBoxAppear` = cámara → destruir lo que
  estorbe (`DestroyCollisionHitActors`) → `CheckPlayerHit` → animación "appear" → jingle.
  `TreasureBoxOpen` = `SetActorSwitch(index 1, true)` (marca el cofre como abierto en su ranura de
  switch) → en paralelo (fork) el jugador mira, el cofre se abre y suenan los efectos →
  `GenericItemGetSequence(itemKey=$arg, count=$arg)` → `AddItem` → autoguardado. El contenido
  llega como **argumento**, así que el mismo flujo sirve para cualquier cofre.
- **TagRoomLocker** (91 eventos, 12 entradas): `RoomClose` = `CloseAllDoors` (más una variante
  con compañero) y `RoomCleared` = `OpenAllDoors`. Las variantes *Battle* encadenan subflujos de
  música (`RegionBGMStop` → `RoomClose` → `BattleBGMStart`, y al terminar `BattleBGMStop`
  → `RoomCleared` → `RegionBGMStart`). El retardo llega como `$arg delay`.
- **Copy**: lógica de eco (primera copia, absorber, pegar enemigo), con consultas
  `CompareCopyableActor` y `IsCopiedActorEnemy`.
- **AreaStartCommon** (284 eventos, 31 entradas): una entrada por forma de entrar en una sala
  (WalkIn, LadderUp, FallIn, WaterFallIn, WarpIn…).
- **EvResetCommon**: un subflujo de "limpieza" estándar que se llama antes de las escenas
  (StopBurning, ResetCarriedActor, DestroyAllProjectiles, AbsorbAllPastedActors,
  ResetFloorAbyss…).
- S_Dungeon001 y L_Dungeon001/002: diálogos y escenas de sala (Talk, AimActor, Fade, SetFlag,
  QuestSystem.SetProgress).

### 4.3 Cómo se cierra una sala hasta matar a los enemigos (MEDIDO, cruzando con los .elo de niveles)
La lógica **está en el nivel, con actores Tag enlazados y flags con nombre**:
1. `TagCheckerWipeout` tiene **enlaces** a los enemigos concretos (p. ej. Keese02, Keese02, Zol).
   Cuando todos han muerto escribe el **switch** de su ranura (p. ej. `…EnemyDead`).
2. `TagRoomLocker` lleva como parámetros las entradas del flujo (`"TagRoomLocker:RoomCloseBattle"`,
   `"TagRoomLocker:RoomClearedBattle"`) y en la ranura 0 el mismo flag `…EnemyDead`. Está enlazado
   a las puertas (vía `TagConditionalActivator → DoorClose`).
3. `TreasureBox` en esa sala usa la **ranura 0 = flag de aparición** (`…EnemyDead`) y la **ranura
   1 = flag de abierto** (`…TreasureBoxOpen`). El cofre aparece solo cuando la sala queda limpia.
4. `SwitchFoot` lleva en la ranura 0 el flag que pone (`…CloseDoorOpen`). La puerta escucha el
   mismo flag.
Recuento en los niveles ya extraídos: 111 TreasureBox, 95 TagConditionalActivator,
44 TagRoomLocker, 17 TagCheckerWipeout, 16 TagSwitchChecker y 10+5 SwitchFoot.

---

## 5. `tailor/*.drsb`: la capa de presentación (no es tela)
- MEDIDO: magic `bsrd`. Las cadenas son nombres de efecto (`OnFire_Spark_00`, `Ice_Melt_00`),
  sonidos (`SE_OBJ_POT_BREAK`) y canales. Hay dos canales: **"Motion"** (por animación, p. ej.
  `open` → efecto y sonido del cofre) y **"Other"** (por **señal de acción** `ac_*`).
- MEDIDO: los 17 .drsb comparten **las mismas 62 señales `ac_*`**: ac_Ignition, ac_OnFire,
  ac_BurnBreak, ac_Extinguishing_water, ac_Extinguishing_wind, ac_Electric, ac_Frozen,
  ac_FrozenInHotWater, ac_IceMelt, ac_IceBreak, ac_EnterWater, ac_LeaveWater, ac_WaterSurface,
  ac_EnterLava, ac_EnterQuicksand, ac_EnterHotSpring, ac_Abyssfall, ac_Piyori (aturdido),
  ac_ThrowLand_1..3, ac_Paste/ac_PastedBreak/ac_CopyPossible (ecos), ac_WandSync* (vara de
  sincronía), ac_Bullet* … En total hay 76 distintas. Los enemigos añaden ac_Found, ac_Vigilance,
  ac_PressBreak, ac_LavaBreak, ac_OnHotFloor y ac_DarkMiasma; ZolFire y Bonfire añaden
  ac_GetCopyActor.
- MEDIDO: hay variantes por suelo (`Land_M_Grass/Sand/Snow…`, `SE_OBJ_POT_MOVE_SAND/ICE…`). Son
  1.289 cadenas SE en 17 archivos.
- Conclusión: tailor = **tabla "señal o animación → efecto + sonido"**, con una plantilla común de
  reacciones que hereda cada actor. El componente `ActorTailorPlayerComponent` (en 441 de 450
  actores) la reproduce. **La lógica (Burn, Frozen…) emite la señal y tailor decide cómo se ve.**
  MEDIDO: 718 instancias de 9 tipos de componente de lógica referencian `TailorPlayerCom`
  (líquido 240, BurnComp 136, eco ?ed395428 124, ElectricShock 91, Frozen 84, Energization 15,
  hielo ?5f91c349 7…): justamente los estados elementales.
- DESCONOCIDO: el formato binario fino (tiempos y offsets de emisores).

---

## 6. Conclusiones aplicables a Magic Symbols

1. **Actor = nombre + lista de componentes, como datos.** Confirma el plan de "base + lista de
   componentes". Las dependencias entre componentes se resuelven **por nombre de instancia**
   (`"LifeComp"`). En Godot equivale a nodos hijos con nombre o a `@export var vida: NodePath`.
   Es mejor que buscar por clase, porque permite tener dos colisiones distintas.
2. **Separar tres capas**:
   (a) *qué componentes tiene* (escena o recurso del actor),
   (b) *números* (un Resource de parámetros compartible: los niveles 2 y 3 de un hechizo reusan los
   del 1),
   (c) *presentación* (tabla `señal → partículas + sonido`, con plantilla común y excepciones).
   La lógica emite `ac_burn_start` y la presentación decide.
3. **Elementos por emisor/receptor, no por enums.** Para fuego, por ejemplo: `EmiteCalor`
   (radio), `PropagaLlama`, `Inflamable` (receptor), `Ardiendo` (estado con tiempo) y `Apaga`.
   Una caja de madera es *Inflamable + PropagaLlama*. La hierba es lo mismo con menos vida. Un
   enemigo de agua **no tiene** Inflamable y **sí tiene** Apaga. Las combinaciones emergen al
   cruzarse áreas: una flecha con `Inflamable` que pasa por una hoguera queda ardiendo, y no
   hace falta un caso especial "flecha de fuego". Encaja con las etiquetas `quema_madera`,
   `conduce` y `apaga`, que pueden ser componentes o etiquetas en un `Area3D`.
4. **Variantes = diff de componentes.** ZolWater = Zol − fuego + Apaga. Las variantes del "mundo
   distorsionado" quitan uno y ponen otro. En Godot, escenas heredadas o recursos con
   `+añadir/−quitar`.
5. **Submódulos de forma** (esfera, caja o cápsula) dentro del componente de colisión elemental:
   una sola lógica de "quemar" y la forma como dato.
6. **"Copiable" o invocable = tabla aparte** (coste, huella en la rejilla, rotación, hábitat), no
   un flag en el actor. Sirve para runas o objetos invocables: un `Dictionary`/CSV
   `invocables.tres` con coste y tamaño, y el actor solo necesita Vida + Reacción + Peso.
7. **Lógica de nivel con actores invisibles + flags con nombre.** El patrón TagCheckerWipeout →
   flag → TagRoomLocker/cofre/puerta da salas que se cierran **sin código específico de sala**:
   - `Comprobador` (enlazado a N enemigos) pone `sala3_limpia`;
   - `Cerrojo` escucha `sala3_limpia` y llama a "cerrar" / "abrir";
   - `Cofre` tiene `flag_aparece` y `flag_abierto`;
   - `Interruptor` tiene `flag_que_pone`; la `Puerta` tiene `flag_que_escucha`.
   Todo son `@export var flag: StringName` sobre un autoload de flags con señal `flag_cambiado`.
8. **Eventos = grafo de datos con servicios.** Acciones sobre actores-servicio (Timer, Audio,
   Camera, Fade, Flags), consultas que ramifican, fork/join para paralelismo, subflujos con
   argumentos (`itemKey`) y entradas con nombre. Para Magic Symbols basta con un Resource
   `Evento` con una lista de pasos y tipos `accion|consulta|paralelo|subflujo`. El primer paso
   práctico es un "reset" común antes de cada escena (EvResetCommon).
9. **Contadores sobre flags** (CountFlags de 5 interruptores → rama según cuántos) en lugar de
   código por puzle.
10. **Generar datos derivados en build** (el "Gardener"): formas de colisión, radios de calor o
    flotación calculados a partir del modelo. En Godot puede ser un `@tool` que precalcula
    `AABB → radio` y lo guarda en el recurso.

## 7. Límites y honestidad
- 74 de 122 tipos de componente y 251 de 289 claves siguen sin nombre (hashes CRC32 sin
  diccionario). Las etiquetas de §1.3 marcadas con `?` son deducciones por los datos que
  referencian y por qué actores las usan.
- No hay números de juego (radios, daños, tiempos): viven en kodama compilado, que no está en
  region_common.
- La categoría de ActorProfile se extrajo con heurística (patrón `FFFFFFFF + offset`). Puede
  haber errores puntuales.
- Del drsb solo se han leído las cadenas, no el formato binario.
- Solo se han leído 29 de unos 400 .bfevfl y 17 de 659 .drsb.
