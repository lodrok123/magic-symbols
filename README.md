# Magic Symbols

Juego 2D isométrico de magia por dibujo de runas, hecho en **Godot 4.7**.

Dibujas un símbolo, el juego lo reconoce, y el elemento que sale
reacciona con el mundo de forma física: el fuego se propaga por la
hierba, el viento lo aviva, el agua conduce el rayo, el hielo deja el
suelo resbaladizo.

Referencias: *Magicka* (combinar elementos), *Witch Hat Atelier* (que
dibujar importe), *Breath of the Wild* (reacciones físicas entre
elementos).

---

## Cómo se juega

| tecla | acción |
|---|---|
| `WASD` | moverse |
| `Shift` | saltar (impulso corto que ignora colisiones) |
| `Espacio` | voltereta (esquiva rápida con recarga) |
| `T` | abrir / cerrar el grimorio; **el tiempo se detiene** mientras está abierto |
| `1` `2` `3` | con el libro **cerrado**, lanzar la página 1, 2 o 3; con el libro abierto, cambiar de página |
| ratón | en los niveles se apunta con el ratón |
| `E` | hablar con un NPC, recoger un ingrediente o planta, comprar en un puesto |
| `I` | mochila (pausa el juego) |
| `Q` | beber una poción |
| `F1` | ocultar / mostrar la paleta de pruebas (incluye "Añadir todos") |
| `R` | reiniciar el nivel (también en pausa); en la pantalla de muerte, volver al último punto de guardado |

Con el grimorio abierto:

- Dibuja en el **núcleo** (el círculo central) → eliges el **elemento**
  o *sello* (fuego, agua, tierra, rayo, hielo, viento).
- Dibuja en un **sector** (uno de los 8 alrededor) → añades un **glifo**
  con su dirección. Varios glifos **se combinan**: barrera + levitación da
  una columna, levitación + flecha un tornado que se mueve. Ninguna de
  esas combinaciones está programada — emergen.
- Al cerrar el libro con `T`, se lanza la página abierta. Hay tres
  páginas; no se gastan, se recargan.

Dibujar en varios sectores lanza varios componentes a la vez: cuatro
flechas en cuatro sectores son cuatro proyectiles en cuatro direcciones.

### Modo de grabación

Dentro del grimorio, `G` entra y sale del modo de grabación, donde
dibujar **no lanza nada**: guarda el trazo como muestra del gesto
seleccionado. `1`–`9` eligen gesto y **`← →` recorren la lista entera**.
`Retroceso` borra la última muestra y `Supr` (dos veces) borra todas las
de ese gesto.

**Los dibujos de cada runa están en `docs/runas.png`.**

Graba **varias muestras por gesto** (cuatro o cinco): el mismo trazo
sale distinto rápido que despacio, grande que pequeño, y con una sola
muestra el reconocedor es frágil.

---

## Cómo está montado

La idea que sostiene todo el proyecto es que **el comportamiento son
datos, no código**:

- Un **elemento** es un archivo `.tres` (`fire_rune.tres`,
  `ice_rune.tres`…) con su color, su daño y sus etiquetas. Inventar un
  elemento es crear un `.tres` y añadir una línea a `spellcaster.gd`.
- Una **animación** es un atlas de 8 direcciones que el pipeline exporta
  con su `meta.json` (`export_godot/CONTRATO_GODOT.md`). Cambiar de
  personaje es exportar otro.
- Un **gesto** es una plantilla grabada en `gesture_library.tres`.
  Cambiar cómo se dibuja el fuego es redibujarlo, no reescribir una
  función que lo detecte.
- Una **reacción** es una etiqueta. El agua no pregunta "¿eres fuego?",
  pregunta "¿traes la etiqueta `calor`?". Por eso un elemento nuevo
  funciona contra el mundo entero sin tocar el mundo.
- Los **glifos** (flecha, barrera, levitación, repetición, amplificar, y
  los nuevos rebote, retardo, pulso, atracción y espejo) no declaran
  combinaciones: cada uno escribe su aportación en una receta común
  (`spell_recipe.gd`) y la receta terminada se interpreta al final.
  `barrera + flecha` da un muro que avanza sin que esa regla esté escrita
  en ninguna parte.
- Un **nivel** es un plano de letras: el motor (`nivel_base.gd`) sabe
  construir cada letra, y cada nivel solo pone su plano y sus datos.

El reconocedor es **$P (Point-Cloud Recognizer)** de Vatavu, Anthony y
Wobbrock (ICMI 2012), portado a GDScript en `gesture_recognizer.gd`.
Licencia New BSD.

**`ARQUITECTURA.md` tiene el detalle completo** de lo que el código hace
hoy, con las decisiones y sus motivos. **`docs/DISENO_FUTURO.md`** tiene
lo que se quiere hacer. **`docs/PROPIETARIOS.md`** dice quién toca qué.

---

## Seguir en otro ordenador

1. Instala **Godot 4.7** y clona este repositorio.
2. Abre la carpeta desde el gestor de proyectos de Godot.
3. La primera apertura tarda: Godot reconstruye `.godot/` reimportando
   todas las texturas. Es normal y solo pasa una vez.
4. Los personajes se renderizan con el pipeline (`pipeline/`, necesita
   Python y Blender) y se exportan a `export_godot/`; el juego solo lee
   esa carpeta.

### Límite de tamaño de textura

Las tiras de efectos (`art/fx/`) no pasan de ~1280 px de lado y van en
**rejilla de 6 columnas**, no en tira larga: una tira de 19 fotogramas de
128 px mide 2432 px y falla en cualquier tarjeta con el tope en 2048. Los
atlas del pipeline miden hasta 3072×1920 y funcionan en las tarjetas
actuales; si hiciera falta soportar un tope de 2048, el pipeline sabe
partirlos (`max_columns_per_part`).

---

## Créditos de recursos

- **Kenney Sketch Town** (CC0) — los cubos de terreno de `Blockout` e
  `IsoTest`.
- **Kenney** — packs de interfaz, runas y partículas (CC0).
- **Personajes, enemigos y bloques del juego** — modelos 3D de Meshy
  procesados por el pipeline de `pipeline/` (render isométrico de 8
  direcciones); ver `pipeline/catalogo.json` para la licencia de cada
  asset.
- Efectos de rayo, hielo y tiempo: generados por `tools/gen_fx.py`;
  sonidos: `tools/gen_sfx.py`.
- Reconocedor de gestos **$P** de Vatavu, Anthony y Wobbrock (New BSD).

> **Atribución pendiente de comprobar.** `pipeline/catalogo.json` marca
> `tree_ghibli_01` como **CC-BY-4.0** (autor "Alex Ace", Sketchfab) con
> atribución obligatoria. Si el árbol se usa en el juego, su crédito tiene
> que figurar aquí y en el juego; si no, hay que quitarlo del
> `meta.json` del terreno.

---

## Las herramientas

Se guardan en el repo para que cada paso sea **repetible**, en vez de
acordarse de que un día alguien recortó unos PNG a mano. Hay dos carpetas:

### `pipeline/`: personajes, enemigos y terreno (lo que usa el juego hoy)

Se manejan con los `.cmd` de `pipeline/` desde Windows (necesitan Python y
Blender).

| comando | qué hace |
|---|---|
| `PROCESAR.cmd` | punto de entrada único (`ms_assets.py`): `procesar`, `nuevo <tipo> <id>`, `aprobar`, `rehacer`, `estado`, `escena`, `migrar`, `demo`, `cola`, `arte` |
| `PROCESAR_PERSONAJES.cmd` | renderiza en 8 direcciones todo lo que haya en `pipeline/inbox/` (`procesar_inbox.py`), lo valida y escribe `pipeline_output/<id>/REPORTE.md` |
| `EXPORTAR_GODOT.cmd <id>` | copia un personaje **aprobado** a `export_godot/characters/<id>/` y escribe su `meta.json` (se niega si el reporte no empieza por `# APROBADO`; `--forzar` lo salta) |
| `PROCESAR_ARTE.cmd`, `VARIANTES_ARTE.cmd` | pasada de estilo sobre un personaje ya renderizado, y sus variantes |
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
| `podar_gestos.py` | quita muestras dispersas y nombres muertos de `gesture_library.tres` | **vigente** (es del Juego) |
| `gen_iso_tiles.py`, `gen_props.py`, `gen_floor.py` | cubos, adornos y fondo de Sketch Town | histórico: solo para `Blockout` e `IsoTest` |
| `gen_tiles_pintadas.py`, `gen_props_bosque.py` | losas pintadas y maleza metidas en la rejilla | histórico, sustituidos por el terreno del pipeline |
| `gen_actor.py`, `gen_hero_sheets.py`, `video_a_fila.py` | la maga de relleno de 64×64, y la maga sacada de vídeo | histórico: animador antiguo (`ActorAnimator`) |
| `gen_enemies.py` | arquero, guerrero y flecha con la paleta de Sketch Town | histórico |
| `gen_walk.py` | — | **obsoleto**, lo dice su propia cabecera |
| `empezar_prueba_iso.bat` | preparaba la rama `prueba-isometrico` | **obsoleto**: esa rama ya no existe |

> `tools/` contiene además un `Godot_v4.7.2-stable_win64.exe` de 181 MB,
> vídeos y un zip que `.gitignore` no excluye. GitHub rechaza archivos de
> más de 100 MB: comprobar con `git ls-files tools` si están versionados.
