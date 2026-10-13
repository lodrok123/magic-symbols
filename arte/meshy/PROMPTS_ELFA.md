# Elfa nueva con la base de la librera (5 de octubre de 2026)

**Por qué hay que rehacerla:** los ojos de `chibi_elf` no se pueden reducir desde Godot. No tienen hueso
propio y están pintados en la textura, troceados en muchas islas del atlas de Meshy. Las proporciones
del cuerpo sí se corrigen en vivo (`proporcion_chibi.gd`), pero la cara no.

**Referencia:** `referencias/bookseller_referencia.png` (la librera de frente, de 3/4 y de lado, sacada
del modelo de `poc_25d`).

---

## Camino A, recomendado: imagen de concepto y Meshy desde imagen

**1. Imagen de concepto.** Usa cualquier generador de imágenes que admita imagen de referencia. Sube
`bookseller_referencia.png` como referencia de estilo:

> Same 3D chibi character style, same body proportions, same head size and SAME SMALL GENTLE EYES as the
> reference girl (about 3 heads tall). New character: a young elf girl with long pointed ears, light blonde
> hair in two long braids over the shoulders, a deep teal-blue tunic dress with gold trim and green leaf
> embroidery, white puffy sleeves, brown leather belt with two small pouches, brown boots. No glasses,
> no weapons. Friendly calm expression, small eyes (smaller than typical chibi). Full body, front view,
> A-pose with arms slightly away from the body, plain light background, soft even lighting.

Si salen ojos grandes, añade: *"eyes 25% smaller, no sparkles in the eyes"*.

**2. Meshy, de imagen a 3D.** Usa esa imagen (y vistas de lado y espalda si las genera). El texto solo
repite lo que ya se ve: *"chibi elf girl, A-pose, game character, ready for rig"*.

**3. Rig y pipeline.** Igual que la librera: rig en Meshy o Mixamo, las animaciones en
`pipeline\inbox\chibi_elf_v2\` y `PROCESAR.cmd` con `rapido chibi_elf_v2 Idle,Walking,Running`.
Después se copia `chibi_elf_v2_master.glb` a `poc_25d\chibi_elf_v2.glb` y se pone primero en
`PJ_JUGADOR` (en `prueba_test2.gd`).

Con este camino las proporciones ya salen bien, así que en `pj_3d.gd` (PROPORCIONES) la v2 no
necesita corrección.

## Camino B, rápido: retexturizar la librera en Meshy

Meshy, "Retexture", sobre `bookseller_chibi.glb`:

> elf girl: light blonde hair, teal-blue tunic dress with gold trim and leaf embroidery, white sleeves,
> brown belt and boots, small gentle eyes, no glasses

- **A favor:** el cuerpo, la cara y el rig son los de la librera, y las orejas ya son de elfa. Se
  pueden reutilizar sus animaciones.
- **En contra:** el pelo (ondulado con una coleta baja), el delantal, el bolso y la falda siguen
  siendo los de la librera; solo cambia el color. Las trenzas no saldrán como trenzas.
