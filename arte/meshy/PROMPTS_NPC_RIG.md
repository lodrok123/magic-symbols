# Dos NPC para el rig común: elfo y goblin (22 de octubre de 2026)

Pedidos por Pablo para el rigging común (`docs/PLAN_RIGGING.md`). Las referencias son dos ilustraciones
realistas: un goblin con saco saliendo por una puerta y un elfo joven con pluma, tintero y libro.
De ellas se toma **solo el personaje** (ropa, colores, carácter). Se pasan al estilo chibi del juego y
**sin accesorios**: ni saco, ni pluma, ni tintero, ni libro.

**Reglas para que se puedan riggear con el esqueleto de su familia** (PLAN_RIGGING §3, paso 1):
- **Pose:** A-pose, simétrica, brazos separados del cuerpo unos 30–40°, palmas hacia abajo y dedos abiertos.
  Piernas algo separadas. Mirando al frente.
- **Manos vacías.** Nada en las manos ni colgando de ellas.
- **Ropa:** sin piezas sueltas que cuelguen (flecos largos, colas de cinturón, borlas). Si las hay, cortas y
  pegadas al cuerpo. Las mangas no pueden tapar ni fundirse con las manos.
- **Tamaño:** el elfo es de la familia chibi (≈ 1 u, unas 3 cabezas de alto). El goblin es de la familia
  goblin (0,85), con las proporciones de `goblin_warrior_chibi`.
- **Cara:** ojos pequeños y amables, como la librera y la elfa v2. Nada de ojos enormes de chibi.

---

## 1. Elfo (NPC escribano)

**Referencia de estilo para el generador de imágenes:** una captura de frente de `arte/modelos/chibi_elf.glb`
o de `bookseller_chibi.glb` (mismo estilo, mismas proporciones, mismos ojos pequeños).

**Imagen de concepto:**

> Same 3D chibi character style, same body proportions, same head size and SAME SMALL GENTLE EYES as the
> reference character (about 3 heads tall). New character: a young male elf scribe with long pointed ears,
> shoulder-length dark brown curly hair, calm thoughtful expression. Cream linen shirt with puffy sleeves
> gathered at the wrists, open collar with lacing, a brown leather vest. A wide burgundy and rust cloth
> sash at the waist, tied flat and short (no long hanging ends). Dark brown knee-length breeches,
> cream knitted knee socks with a woven pattern, brown leather shoes. EMPTY HANDS: no book, no quill,
> no inkwell, no bag, no weapons, no props. Full body, front view, symmetrical A-pose with arms 35 degrees
> away from the body, palms down, fingers apart, legs slightly apart, plain light background, soft even
> lighting.

Si salen ojos grandes: *"eyes 25% smaller, no sparkles in the eyes"*. Si sale con algo en las manos:
*"hands completely empty and open"*.

**Meshy, de imagen a 3D** (con vistas de lado y espalda si las genera):

> chibi male elf scribe, A-pose, empty hands, game character, ready for rig, no props

Nombre al instalar: `npc_elfo_escribano`.

---

## 2. Goblin (NPC ratero)

**Referencia de estilo para el generador de imágenes:** una captura de frente de
`arte/modelos/goblin_warrior_chibi.glb` (mismo estilo, misma cabeza y orejas, mismas proporciones).

**Imagen de concepto:**

> Same 3D chibi goblin style, same body proportions, same head, ears and eyes as the reference goblin.
> New character: a sneaky old goblin townsfolk with olive-green wrinkled skin, a long hooked nose, big
> pointed ears, small sly eyes and a slight frown. A soft olive-brown felt cap with a short pointed tip that
> stays upright (not flopping down, not covering the ears). A worn olive-brown tunic to mid-thigh with
> rolled-up sleeves above the wrists, a thin rope belt tied flat (no hanging ends), brown cloth trousers
> and wrapped leather foot bindings with bare toes. EMPTY HANDS: no sack, no bag, no weapons, no props.
> Standing upright (not crouching), full body, front view, symmetrical A-pose with arms 35 degrees away
> from the body, palms down, fingers apart, legs slightly apart, plain light background, soft even lighting.

Si sale encorvado o agachado: *"standing straight, upright posture"*. Si sale con el saco: *"no sack, no
bag, hands completely empty and open"*.

**Meshy, de imagen a 3D:**

> chibi goblin townsfolk, A-pose, empty hands, game character, ready for rig, no props

Nombre al instalar: `npc_goblin_ratero`.

---

## Después

- **Sin rig en Meshy:** se riggean con el esqueleto maestro de su familia cuando estén las 4 decisiones de
  PLAN_RIGGING §7. Hasta entonces se instalan con `recibir_assets.py` como modelos sin animar.
- **Comprobar al recibirlos:** que las manos salen separadas de las mangas y del cuerpo, que la gorra del
  goblin no tapa las orejas y que no quedan flecos colgando.
