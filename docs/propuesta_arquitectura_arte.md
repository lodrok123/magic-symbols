# Propuesta de actualización de ARQUITECTURA.md: lado Pipeline (arte)

Tarea 2.2 de `docs/PLAN_ARREGLOS.md`. Se escribe el 4/10/2026 después de leer del disco
`ARQUITECTURA.md` (32 016 bytes), `README.md`, `docs/PROPIETARIOS.md`, `docs/PLAN_ARREGLOS.md`,
`docs/DIARIO.md`, `docs/propuesta_arquitectura_juego.md` y `docs/QA_ARTE.md`, y de comprobar cada
dato contra `ms_atlas.gd`, `ms_actor.gd`, `nivel_base.gd`, los `meta.json` de `export_godot/`, los
atlas, `pipeline/` y `tools/`. **No edita `ARQUITECTURA.md` ni `README.md`**: los integra Pablo (2.3).

Cubre las secciones **Arte**, **Animación** y **Personaje** de `ARQUITECTURA.md`, un retoque de
**Vista isométrica**, otro de **Decisiones de diseño**, las filas de **Errores que costaron caros**
que son de arte, y la **tabla de `tools/` del README**. Todo lo demás es de la propuesta del Juego.

Formato igual que la del Juego: **dónde** va, **qué hacer** (Reemplazar, Añadir, Retocar o Borrar) y
el **texto listo para pegar** entre líneas `---8<---`.

Al integrarla se puede borrar este archivo.

---

## 0. Qué cambió de verdad (para decidir si merece la pena)

`ARQUITECTURA.md` describe el arte de septiembre. Esto ya no es cierto:

| `ARQUITECTURA.md` dice | Lo que hay hoy |
|---|---|
| Terreno de Kenney Sketch Town, losa 256×352 con rombo de 232×110 | Losa de **128×64** del pipeline, cara de arriba en **y = 33** (`terrain/bosque_01/meta.json`: `tile_px [128,64]`). Sketch Town solo vive en `Blockout` e `IsoTest` |
| Personaje de relleno generado por `tools/gen_actor.py`: celdas 64×64, 5 clips, `ActorAnimator` | El **héroe** sale del pipeline 3D: celdas de **192×240**, 15 clips, atlas de 8 filas, leído por `MsAtlas` / `MsActor`. `ActorAnimator` sigue en el repo pero ya no anima a nadie (ver §3) |
| Contrato de hoja en `docs/ANIMACION.md` | Contrato en `export_godot/CONTRATO_GODOT.md` + `meta.json` por personaje |
| Fuego, agua, viento y tierra de un pack de VFX; rayo, hielo y tiempo de `gen_fx.py` | Igual. **Sigue vigente**, incluida la regla de la rejilla de 6 columnas |
| "Ninguna textura pasa de ~1024–1280 px" | **Falso para los atlas del pipeline**: `hero/idle` mide **3072×1920** y el pipeline declara un tope de 4096. La regla vale para los efectos (ver §2) |

Lo que **no hay que tocar**: la sección Partículas (`block_fx.gd`, es del Juego y sigue siendo cierta),
Bloqueo físico vs. detección y todo el bloque de hechizos.

---

## 1. «Vista isométrica» → Retocar el párrafo de la geometría

**Dónde:** en «`iso_grid.gd` — la conversión», el párrafo «La geometría **no es inventada**: viene del
propio pack…» y la cita que lo sigue sobre la hierba que desborda el cubo. (`iso_grid.gd` es del Juego,
pero lo que cuenta ese párrafo es de dónde salen los números, y eso lo decide el arte.)
**Qué hacer:** Reemplazar los dos bloques por el texto de abajo. `STEP = (58, 27.5)` y `LEVEL = 55.5` no
cambian: lo que cambió es de dónde salen.

---8<---
La geometría **no es inventada**: viene del contrato de losa del pipeline (`tile_px = [128, 64]`, cara
de arriba centrada en la fila **y = 33** del sprite). El juego dibuja casillas más pequeñas que la
losa: `nivel_base.gd` encoge cada bloque con `SX = 116/128` y `SY = 55/64`, de ahí el rombo de
**116×55**, el paso **(58, 27.5)** y la altura de nivel **55,5**. Los personajes se encogen con el
mismo `SX` (`MsAtlas.ESCALA_MUNDO`), para que sigan siendo del tamaño correcto respecto al suelo.

> Medir el sprite a ojo sale mal: en una losa el costado también es ancho, así que la fila más ancha
> del dibujo no es el centro de la cara, es la primera de varias. El dato fiable es el contrato
> (`CARA_Y = 33`), no el recorte. Una pieza cuyo centro de cara no esté en y = 33 queda hundida o
> flotando respecto a las losas vecinas sin que ningún `offset` global lo arregle.
---8<---

---

## 2. «Arte» → Reemplazar la sección entera

**Dónde:** desde `## Arte` hasta justo antes de `## Decisiones de diseño`. Incluye «Terreno: Kenney
Sketch Town», «La paleta, medida del propio pack», «Personaje» (su sustituto está en §4), «Efectos
(`art/fx/`)» y «Packs en bruto: `.gdignore`».
**Qué hacer:** Reemplazar por el texto de abajo. Se conservan, porque siguen siendo ciertas, la regla
de la rejilla de efectos y la explicación del `.gdignore`; se reescribe todo lo demás.

---8<---
## Arte

La dirección de arte y los números están en `docs/ARTE.md` (§1 colores de elemento, §2 paletas de
bioma: vigentes) y el contrato con Godot en `export_godot/CONTRATO_GODOT.md`. Aquí solo se cuenta
**cómo llega el arte al juego** y por qué.

### De dónde sale cada cosa

| qué | cómo se hace | dónde queda | quién lo lee |
|---|---|---|---|
| Personajes y enemigos | GLB de Meshy → `pipeline/` (Blender) → 8 direcciones | `export_godot/characters/<id>/` | `MsAtlas` / `MsActor` |
| Losas de terreno | 128×64, cara de arriba en y = 33 | `export_godot/terrain/bosque_01/sprites/blocks/` | `nivel_base._bloque()` |
| Árboles y props | render del pipeline, ancla en el centro de la base | `…/sprites/trees/`, `…/sprites/props/` | `nivel_base` (`PROP_DATOS`) |
| Piezas 2D sueltas | dibujadas a **2x**, se pintan a escala 0.5, ancla apuntada a mano en el código | `art/` (hielo, empujables, puesto, tótems, baldosa, placa, puente) | cada nivel |
| Efectos de hechizo | tiras de 18 fotogramas de 128×128 | `art/fx/` | `RuneData` |
| Interfaz | glifos y paneles | `art/ui/` | grimorio, HUD |

**El pipeline es la única fuente de lo que pisa la rejilla.** Es lo que mantiene una sola luz y un
solo lienzo en pantalla; ver «Las tres familias» más abajo para lo que todavía no cumple.

### El contrato de una losa

- Lienzo **128×64** de rombo (`tile_px`), la **cara de arriba centrada en y = 33**, costados hacia abajo.
  Un bloque suelto mide 128×102.
- **Luz plana.** Una losa se repite sesenta veces; una sombra proyectada marcada hace que se vea la
  repetición antes que el dibujo (`docs/ARTE.md` §6).
- Cualquier pieza que se apile sobre la rejilla (hielo, tierra creada, empujables) debe traer **el mismo
  lienzo**, no uno propio: si cada textura trae su cara en un sitio, cada script necesita una tabla de
  desplazamientos, y el bloque deja de ignorar los píxeles.

### Tamaño de textura: dos reglas, no una

- **Efectos (`art/fx/`)**: ninguna textura pasa de ~1024–1280 px de lado. Los fotogramas van en
  **rejilla de 6 columnas**, no en tira: una tira de 19 fotogramas de 128 px mide 2432 px y falló en
  tarjetas con tope de 2048 (`Texture dimensions exceed device maximum`).
- **Atlas del pipeline**: miden hasta **3072×1920** (16 fotogramas de 192 px por fila) y declaran un
  tope de 4096 (`max_texture_size_px` en su metadata). Funcionan en las tarjetas actuales, pero **no
  pasarían en una con tope de 2048**: es el mismo fallo de la tira, con otro origen. Si algún día hay
  que soportar una, la salida es partir por `max_columns_per_part`, que el pipeline ya sabe hacer
  (`parts` en la metadata; `MsAtlas.animacion()` ya recorre varias partes).

### Piezas que aún no vienen del pipeline

Hay dos «familias» más en pantalla además de la del pipeline, y conviene saberlo para no
sorprenderse:

1. **`art/` nuevo** (hielo, tierra creada, empujables, tótems, puesto, baldosa, placa): pintado con luz
   direccional marcada, a 2x. No cumple el contrato de losa y al lado de un bloque del pipeline se nota
   el cambio de mano.
2. **Duplicados**: fogata (`props/campfire.png` y `art/fogata_*.png`), tierra (`blocks/dirt.png` y
   `art/earth.png`) e hierba (`blocks/grass.png` y `art/grass*.png`).

Se van sustituyendo por lo que más se ve (hielo → tierra creada → empujables → tótems → puesto), y cada
sustitución **borra su duplicado de `art/`**, para que no vuelva a cargarse por error. La lista de lo que
falta, con formato exacto, está en `docs/ASSETS_PENDIENTES.md`; el estado de cada medición, en
`docs/QA_ARTE.md`.

### Efectos (`art/fx/`)

Fuego, agua, viento y tierra vienen de un pack de VFX muestreado a ~18 fotogramas (el fuego, en tres
intensidades: `tools/gen_fire_tiers.py`). Rayo, hielo y tiempo los genera `tools/gen_fx.py`.
**La animación es un dato del elemento**, no del hechizo: `spell.gd` nunca pregunta «¿eres fuego?»,
solo «¿traes tira?».

### Packs en bruto: `.gdignore`

**Godot importa toda imagen que haya dentro del proyecto, la use el juego o no**, y
`Spellbook/fire/strong/strongFire.png` mide **35 623 × 635 px**: ninguna tarjeta la acepta. De ahí la
cascada de `Attempting to use an uninitialized RID`. Por eso los packs en bruto llevan un `.gdignore`, y
también `pipeline/` y `pipeline_output/` (los GLB, renders y reportes intermedios): Godot solo debe ver
`export_godot/`. Efecto secundario bueno: ~3000 archivos menos que importar.
---8<---

> **Una frase que desaparece y por qué.** El texto antiguo decía que Sketch Town «mapea 1:1 con los
> bloques» y que «no es casualidad que encaje». Era cierto y fue la razón de elegirlo, pero ya no
> describe el juego; la razón de diseño que sí sigue en pie está en «Decisiones de diseño» (§6).

---

## 3. «Animación» → Reemplazar la sección entera

**Dónde:** desde `## Animación` hasta justo antes de `## Partículas — block_fx.gd`.
**Qué hacer:** Reemplazar. Las celdas de 64×64, las 8 filas `E SE S SO O NO N NE`, los pies en y = 52, los
cinco clips y «`ActorAnimator` no sabe nada del mago» describen el animador antiguo. **Se conserva la
idea de fondo** (el animador no sabe quién es el personaje: lee datos) y se conserva la decisión de que
andar avanza con la distancia recorrida, solo si se verifica en `player.gd` (ver «Sin verificar» al
final de este archivo).

---8<---
## Animación

El personaje no se anima con código propio: **lee atlas que el pipeline exporta**, y cada atlas se
describe a sí mismo en un `meta.json`. El contrato está en `export_godot/CONTRATO_GODOT.md`.

### Lo esencial del contrato

- Un personaje es `export_godot/characters/<id>/` con `meta.json` y un atlas por animación
  (`atlases/<clip>/<clip>_8dir.png` + `_8dir_metadata.json`).
- **8 filas = 8 direcciones, columnas = fotogramas.** `frame_px` (hoy **192×240**) es el tamaño de cada
  celda; `ancla_suelo_px` dice dónde pisa y `offset_visual_px` cuánto hay que desplazar el sprite para
  que ese punto caiga en el nodo.
- Cada clip declara `frames`, `fps` y `loop`. Un clip con `loop = false` (golpe, muerte, lanzar) se
  reproduce una vez.
- **La etiqueta de la dirección va «al revés» en el eje este-oeste**: el pipeline renderiza cada fila con
  la etiqueta invertida y el `meta.json` trae la tabla que lo corrige (`mapeo_direcciones_godot`:
  `E→W`, `SE→SW`, `SW→SE`, `W→E`, `NW→NE`, `NE→NW`). `player.gd` ya calcula su etiqueta con ese mismo
  volteo, así que para el héroe la etiqueta **es** la fila; para el resto de actores lo hace `MsActor`.

### Las dos piezas que lo leen

- **`MsAtlas`** (sin estado visible): `meta(id)`, `tiene(id, clip)`, `fps()`, `en_bucle()`,
  `escala()`, `animacion(id, clip)` (devuelve `{fila: [AtlasTexture…]}` y cachea, porque un atlas son
  varios megas) y `frames_heroe()`, que monta el `SpriteFrames` que espera `player.gd`.
- **`MsActor`** (un `Sprite2D`): reproduce atlas de 8 direcciones para todo lo que no es el héroe
  (goblins, NPC). Se puede crear nuevo (`MsActor.new().setup("goblin_warrior")`) o ponerlo **sobre un
  `Sprite2D` ya existente** con `set_script()`, de modo que `enemy.gd` y `archer.gd` sigan hablando con
  «su» `$Sprite2D` sin saber que ahora es otro dibujo.

`MsActor` decide qué clip toca según su `modo`: `"fijo"` (el que se le diga con `jugar()`), `"guerrero"`
y `"arquero"` (los enemigos de patrulla, que miran variables de `enemy.gd` / `archer.gd`) y `"ia"`: el
goblin con IA le dice qué hace con tres variables suyas, **`mirada`**, **`moviendo`** (0 quieto, 1 anda,
2 corre) y **`anim_orden`** (un clip puntual: ataque, golpe, tiro). Así la lógica del enemigo no
conoce los nombres de los clips más que en `anim_orden`.

### Lo que decide cómo se ve

- **El tamaño sale del `meta.json`**, no del código: `escala = escala_relativa × (192 / frame_px.x) ×
  ESCALA_MUNDO`. Si un personaje nuevo se exporta con otro `frame_px`, se dibuja bien sin tocar nada.
- **La vertical se ve aplastada ~2:1**, y hay que deshacerlo antes de medir un ángulo
  (`MsActor.DESAPLASTAR = 2.109`), o los personajes miran mal en las diagonales.
- **El golpe del héroe es corto a propósito**: no se usa el clip entero de `hit_reaction` (12
  fotogramas) sino el tramo central, fotogramas 2–5 a 20 fps (0,2 s). El clip entero dura un segundo y
  el personaje parecería moverse a cámara lenta mientras ya le están pegando. `frames_heroe()` tiene una
  tabla `clip → [animación, primer fotograma, último, fps]` justo para estos recortes.
- **La muerte espera a que acabe el clip**: `player.gd` no muestra «HAS MUERTO» hasta que termina la
  caída. Mientras el pipeline no haya procesado `shot_in_the_back_and_fall`, `MsAtlas._clip_muerte()`
  busca `shot_in_the_back_and_fall` → `death` → `hit_reaction_to_waist`, **el primero que exista**. Con
  el último (el actual), el clip entero **se dobla y se vuelve a incorporar**: ver «Errores que costaron
  caros».

### `ActorAnimator` ya no anima a nadie

El animador de la maga de 64×64 (`actor_animator.gd`) sigue en el repo porque `IsoTest` y los enemigos
antiguos lo usan, pero **en los niveles nuevos solo hace de mensajero**: `nivel_base._crear_jugador()`
cuelga un `ActorAnimator` sin hojas (`clips = {"cast": null}`) para que el `Spellcaster` pueda avisarle
de «he empezado a lanzar» y `player.gd` reproduzca el clip del héroe al recibir `cast_requested`.
**No lo borres sin cambiar antes ese aviso**: sin él, la maga lanza hechizos y no hace el gesto.

`docs/ANIMACION.md` y `docs/PERSONAJE.md` describen ese animador antiguo (la maga sacada de vídeo) y
son históricos.
---8<---

---

## 4. «Personaje» (subsección de «Arte») → Reemplazar

**Dónde:** la subsección `### Personaje` («De relleno, generado por `tools/gen_actor.py`, y
**deliberadamente sustituible**…») y las tres frases que la siguen. Ya incluida en el bloque de §2 por
la tabla «De dónde sale cada cosa»; si prefieres mantenerla como subsección propia, usa este texto en
lugar de la tabla:

---8<---
### Personajes

El héroe, los goblins, los NPC (`master_elf`, `ranger_human`, `bookseller_woman`) y todo lo que se
mueva sale del **pipeline de sprites isométricos**: un GLB (de Meshy) entra en `pipeline/inbox/<id>/`
con su `asset.json`, `pipeline/PROCESAR.cmd` lo renderiza con Blender en 8 direcciones, lo valida y deja
un `REPORTE.md`, y `pipeline/EXPORTAR_GODOT.cmd <id>` lo copia a `export_godot/characters/<id>/` si el
reporte empieza por `# APROBADO`. El juego lo lee con `MsAtlas`/`MsActor` sin tocar código.

Lo que esto cambia respecto al personaje de relleno de septiembre:

- **Cambiar de personaje o de clip es exportar de nuevo**, no tocar `player.gd` ni ningún nivel.
- **El juego no puede pedir un clip que el pipeline no haya exportado.** Lo que necesita el Juego se
  apunta en `docs/ASSETS_PENDIENTES.md` (sección 0, «Urgente») y mientras tanto usa un clip que exista.
  Es lo que hace `MsAtlas._clip_muerte()` con la muerte.
- **Los personajes del pipeline no están en la sesión en la nube**: allí salen como cuadrados de color,
  así que su aspecto se revisa en el ordenador.
- Dos nombres de clip arrastran la errata del origen (`mage_soell_cast_001/002`, con «spell» mal
  escrito). Se dejan: cambiarlos rompe `MsAtlas` y obliga a reexportar.
---8<---

---

## 5. «Decisiones de diseño» → Retocar una viñeta

**Dónde:** la viñeta «**El arte generado no es una derrota**: es lo único que da 8 direcciones y 5
animaciones coherentes, y retocarlo es barato mientras aún se está decidiendo.» (La viñeta de la vista
isométrica y su coste la retoca la propuesta del Juego, §12).
**Qué hacer:** Reemplazar.

---8<---
- **El pipeline 3D sustituyó al arte de relleno.** Las 8 direcciones por animación eran el coste que
  hacía casi inviable un personaje propio; con un GLB y un renderizado en Blender, un clip nuevo son
  ~12 fotogramas × 8 filas **sin dibujarlos**. El coste aceptado: las animaciones vienen de una librería
  (Meshy), no a medida; cada clip que falta (voltereta, nadar, muerte del héroe) es una espera, no un
  dibujo; y hay que renderizar en el ordenador de Pablo, no en la nube.
---8<---

---

## 6. «Errores que costaron caros» → Retocar dos filas y añadir cuatro

**Dónde:** la tabla.
**Qué hacer:**

- **Borrar** la fila «Sombra animada en vez del personaje» (es del animador antiguo: ya no existe un
  «primer `Sprite2D`» que animar).
- **Retocar** la fila «Sombrero recortado» (sigue pasando, con otra causa):

---8<---
| Sombrero recortado, o un clip que se corta | parece una gorra; la pose se «aplana» en un borde | el dibujo se sale del fotograma. El pipeline lo mide (`margins` en la validación de render) y `procesar_inbox.fit_margins()` recentra y, si no cabe, agranda `ortho_scale` un 15 %. Si hay `size_lock.json`, no lo toca y hay que revisarlo a mano |
---8<---

- **Añadir:**

---8<---
| La maga muerta se levanta | sale «HAS MUERTO» con ella de pie | sin `shot_in_the_back_and_fall` se usa `hit_reaction_to_waist` entero y su última pose es la inicial. Medido: la figura baja de 135 a 97 px en el fotograma 5 y vuelve a 135 |
| Lo estático parece un fallo de dibujo | un bloque «hundido» o «flotando» al lado de otro | el `Visual` toma su `offset` de la textura del bloque base. Una textura con la cara en otra fila (hielo: y = 96, no 33) queda ~22 px más abajo, y ningún `offset` global lo arregla |
| Direcciones invertidas este-oeste | el personaje mira a la izquierda al ir a la derecha | el pipeline etiqueta cada fila al revés en ese eje; la tabla `mapeo_direcciones_godot` del `meta.json` lo corrige y hay que leerla, no suponerla |
| Escalar un raster para que «llene» | el prop se ve borroso al lado de losas nítidas | `PROP_DATOS` amplía ×1,2–1,6 props que el pipeline entrega a 38–51 px de ancho. Ampliar un raster emborrona justo lo que está delante del jugador |
---8<---

---

## 7. «Pendiente / próximos pasos naturales» → Nada que añadir de arte

La propuesta del Juego (§14) ya reemplaza la lista. Si quieres una línea del lado arte, esta basta:

---8<---
- **Arte pendiente**: la lista, con formato exacto, está en `docs/ASSETS_PENDIENTES.md`; las mediciones
  que la sustentan, en `docs/QA_ARTE.md`. Lo más urgente: el clip de muerte del héroe
  (`shot_in_the_back_and_fall`) y los hielos con el lienzo de las losas.
---8<---

---

## 8. README.md (para la 2.3)

El README mezcla tres cosas de este lado. Cada una con su texto.

### 8.1 «Créditos de recursos» → Reemplazar

Hoy dice que el personaje y los efectos salen de `tools/` y que Sketch Town son «los cubos de terreno».
Ya no es así, y hay una atribución obligatoria que falta.

---8<---
## Créditos de recursos

- **Kenney Sketch Town** (CC0) — los cubos de terreno de `Blockout` e `IsoTest`.
- **Kenney** — packs de interfaz, runas y partículas (CC0).
- **Personajes, enemigos y bloques del juego** — modelos 3D de Meshy procesados por el pipeline de
  `pipeline/` (render isométrico de 8 direcciones); ver `pipeline/catalogo.json` para la licencia de cada
  asset.
- Efectos de rayo, hielo y tiempo: generados por `tools/gen_fx.py`; sonidos: `tools/gen_sfx.py`.
- Reconocedor de gestos **$P** de Vatavu, Anthony y Wobbrock (New BSD).
---8<---

> **Atribución pendiente.** `pipeline/catalogo.json` marca `tree_ghibli_01` como **CC-BY-4.0** (autor
> «Alex Ace», fuente Sketchfab) con `atribucion_requerida: true`, y `CONTRATO_GODOT.md` dice que esa
> licencia «debe acreditarse en el juego». Hoy no figura en ningún sitio. **No lo he podido
> comprobar si el árbol se usa**: `terrain/bosque_01/meta.json` lo lista, pero el juego pinta los 12
> árboles de `sprites/trees/` (`tree_oak_*`, `tree_pine_*`…). Si se usa, hay que añadir esa línea; si no,
> quitar `tree_ghibli_01` del meta.

### 8.2 «Cómo está montado», viñeta de la animación → Reemplazar

La viñeta actual («Una **animación** es una hoja de sprites que cumple un contrato escrito
(`docs/ANIMACION.md`). Cambiar de personaje es cambiar los PNG.») apunta a un documento histórico.

---8<---
- Una **animación** es un atlas de 8 direcciones que el pipeline exporta con su `meta.json`
  (`export_godot/CONTRATO_GODOT.md`). Cambiar de personaje es exportar otro.
---8<---

### 8.3 «Las herramientas de `tools/`» → Reemplazar la tabla

La tabla lista 4 scripts; **`tools/` tiene 14 scripts y 3 `.bat`**, y la carga real de generar arte pasó
a `pipeline/`. Texto para pegar (el estado de cada script está comprobado contra su cabecera):

---8<---
## Las herramientas

Se guardan en el repo para que cada paso sea **repetible**, en vez de acordarse de que un día alguien
recortó unos PNG a mano. Hay dos carpetas:

### `pipeline/`: personajes, enemigos y terreno (lo que usa el juego hoy)

Se manejan con los `.cmd` de `pipeline/` desde Windows (necesitan Python y Blender).

| comando | qué hace |
|---|---|
| `PROCESAR.cmd` | punto de entrada único (`ms_assets.py`): `procesar`, `nuevo <tipo> <id>`, `aprobar`, `rehacer`, `estado`, `escena`, `migrar`, `demo`, `cola`, `arte` |
| `PROCESAR_PERSONAJES.cmd` | renderiza en 8 direcciones todo lo que haya en `pipeline/inbox/` (`procesar_inbox.py`), lo valida y escribe `pipeline_output/<id>/REPORTE.md` |
| `EXPORTAR_GODOT.cmd <id>` | copia un personaje **aprobado** a `export_godot/characters/<id>/` y escribe su `meta.json` (se niega si el reporte no empieza por `# APROBADO`; `--forzar` lo salta) |
| `PROCESAR_ARTE.cmd`, `VARIANTES_ARTE.cmd` | pasada de estilo sobre un personaje ya renderizado, y sus variantes de estilo |
| `NOCHE.cmd`, `NOCHE_RESTO.cmd` | procesan varios personajes seguidos y dejan un log en `pipeline_output/arte_QA/` |
| `ORDENAR_CARPETA.cmd` | crea la estructura y **mueve** (no borra) lo obsoleto a `_obsoleto/`; seguro de repetir |
| `build_npc_v25.cmd`, `render_npc_v25.cmd`, `run_npc_e2e_v24.cmd` | versiones antiguas del flujo de NPC; candidatas a `_obsoleto/` |

### `tools/`: generadores del arte de septiembre y utilidades

| script | qué genera | estado |
|---|---|---|
| `gen_fx.py` | las tiras de efecto de rayo, hielo y tiempo (rejilla de 6 columnas) | **vigente** |
| `gen_fire_tiers.py` | las tres intensidades del fuego (`fire`, `fire_mid`, `fire_high`) | **vigente** |
| `gen_sfx.py` | los efectos de sonido, sintetizados, como `.wav` sueltos | **vigente** |
| `grabar_laboratorio.bat` | graba el laboratorio de VFX con el modo Movie Maker de Godot | **vigente** |
| `subir_a_github.bat` | comprobaciones y subida a GitHub | **vigente** |
| `podar_gestos.py` | quita muestras dispersas y nombres muertos de `gesture_library.tres` | **vigente**, pero es del Juego, no del arte |
| `gen_iso_tiles.py`, `gen_props.py`, `gen_floor.py` | cubos, adornos y fondo de Sketch Town | histórico: solo para `Blockout` e `IsoTest` |
| `gen_tiles_pintadas.py`, `gen_props_bosque.py` | losas pintadas y maleza metidas en la rejilla (`art/floor_b.png`, `grass.png`…) | histórico, sustituidos por el terreno del pipeline |
| `gen_actor.py`, `gen_hero_sheets.py`, `video_a_fila.py` | la maga de relleno de 64×64, y la maga sacada de vídeo (`rita_*`, `maga_*`) | histórico: es el animador antiguo (`ActorAnimator`) |
| `gen_enemies.py` | arquero, guerrero y flecha con la paleta de Sketch Town | histórico |
| `gen_walk.py` | — | **obsoleto**, lo dice su propia cabecera; se puede borrar |
| `empezar_prueba_iso.bat` | prepara la rama `prueba-isometrico` | **obsoleto**: esa rama ya no existe |
---8<---

> **Cosas que pesan o sobran en `tools/` (no editadas):** hay un `Godot_v4.7.2-stable_win64.exe` de
> **181 MB**, un `.mp4` de 34 MB, un `.zip` de 32 MB y otro `.mp4` de 4 MB. `.gitignore` no los excluye.
> GitHub rechaza archivos de más de 100 MB: conviene comprobar con `git ls-files tools` si están
> versionados y, si no, añadirlos al `.gitignore` (o sacarlos de la carpeta); `godot_ruta.txt` ya
> apunta al `.exe`, así que el juego no necesita que viaje.

---

## 9. Fuera de alcance (lo digo para que no se pierda)

- `docs/ARTE.md` §3–§5 (contrato de hoja de 64×64, «La protagonista», «Por dónde seguir») y §6 (losa de
  256×352) describen el arte de septiembre. `CONTEXTO.md` ya dice que el contrato de hojas de §3 es del
  animador antiguo; **§6 (la losa) también está desfasado** (hoy 128×64, cara en y = 33). Son archivos
  del Pipeline, así que los corrijo yo cuando quieras, pero no es parte de esta propuesta.
- `docs/ANIMACION.md` y `docs/PERSONAJE.md` necesitan un aviso de «histórico» arriba.
- **`podar_gestos.py` y `.gitignore`** no encajan en ningún propietario de `PROPIETARIOS.md`
  (`tools/` está asignado al Pipeline pero `podar_gestos.py` es del Juego). Una línea en ese archivo lo
  resuelve.

---

## Sin verificar (no integrar sin mirar)

- **«Andar avanza con la distancia recorrida»**: la decisión del texto antiguo la he **quitado** de §3 a
  propósito. No la he podido comprobar en el código del héroe nuevo (anima con `AnimatedSprite2D` y
  `frames_heroe()`, no con `ActorAnimator`). Si se quiere conservar, hay que mirar `player.gd`.
- **Hielo y tierra creada**: el cálculo de «hundido ~22 px» es aritmético, sobre los PNG medidos y el
  código que los coloca. QA_ARTE lo marca **[Godot]** y sigue sin confirmar con F6.
- Qué scripts de `tools/` siguen usando `IsoTest` o `Blockout`: lo deduzco de sus cabeceras, no de
  haberlos ejecutado.
