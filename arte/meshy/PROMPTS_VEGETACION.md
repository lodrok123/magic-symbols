# Hierba y vegetación: prompts (5 de octubre de 2026)

## Qué NO pedir a Meshy
La **hierba fina** (las briznas del suelo) se queda hecha por código (`hierba_3d.gd`). Son decenas de miles
de matojos: tienen que ser muy ligeros, y Meshy hace mal las cosas finas (le salen gruesas o con agujeros).
Lo que sí mejora mucho el aspecto es darle a esos matojos una **textura pintada** (parte A) y tener
**vegetación grande** de Meshy para salpicar el escenario (parte B).

---

## A. Textura para los matojos y las flores (generador de imágenes, NO Meshy)
Una imagen 2 × 2 con cuatro matojos distintos. Yo la recorto, le quito el fondo y la pongo en los matojos de
`Hierba3D` como "tarjetas" que miran a la cámara.

```
A 2x2 sprite sheet of four small stylized grass tufts for a cozy chibi game, soft hand-painted pastel style matching the reference image, fresh light green with yellow-green tips and slightly darker teal-green base, each tuft a rounded clump of 6 to 10 soft blades, one with two tiny white flowers, one with a tiny pink flower, one taller and thinner, one short and round. Each tuft centered in its own quarter, seen from the front and slightly above, no ground, no shadow, flat pure magenta background (#FF00FF) for easy cutout, no text, no outline.
```

Flores sueltas, para salpicar entre la hierba:
```
A 3x3 sprite sheet of nine tiny stylized flowers for a cozy chibi game, soft hand-painted pastel style: white daisies, pink five-petal flowers, butter-yellow buttercups, lilac bell flowers and coral wildflowers, each with one or two small leaves, each centered in its own cell, seen from slightly above, no ground, no shadow, flat pure magenta background (#FF00FF), no text, no outline.
```
Sube como referencia una captura de la maqueta o la imagen de la elfa, para que salga en la misma paleta.

---

## B. Vegetación 3D (imagen de concepto y luego Meshy, **una por generación**)
Mismo método que la elfa y los grimorios. Pon al final de cada prompt:

```
stylized chibi game asset, soft pastel colors, hand-painted texture, chunky rounded shapes, matching the reference image, single object, no ground plane, three-quarter front view, full object visible, plain light background, soft even lighting
```

| id | polígonos | prompt (empieza así y pega el final de arriba) |
|---|---|---|
| `mata_alta` | 1.500–2.500 | `a big clump of tall soft grass, long rounded blades in light and teal greens, a few seed heads on top` |
| `arbusto` | 2.000–3.000 | `a round fluffy bush made of soft puffy leaf clumps, fresh green with lighter tips` |
| `arbusto_flores` | 2.000–3.000 | `the same round fluffy bush with small pink and white flowers scattered on it` |
| `helecho` | 1.500–2.500 | `a small fern plant with five or six curled soft fronds, fresh green` |
| `macizo_flores` | 1.500–2.500 | `a small patch of wildflowers with leaves: white daisies, pink and yellow flowers, low and wide` |
| `juncos` | 1.000–2.000 | `a clump of pond reeds and cattails with two round lily pads at the base` |
| `setas` | 800–1.500 | `a small cluster of three cute red mushrooms with white spots and a bit of moss` |
| `piedras_musgo` | 800–1.500 | `a small group of three rounded lavender-grey stones with soft green moss on top` |
| `tronco_caido` | 1.500–2.500 | `a short fallen log with moss patches, a small mushroom and a tiny sprout` |

Los árboles (redondo y pino) y el seto seco ya están en `PROMPTS_EQUIPO.md`, sección 2.

Al bajarlos, déjalos en `meshy\entrada\` con el nombre del id (`arbusto.glb`...). Los meto en una biblioteca
`vegetacion.glb` y en el decorado de la maqueta en lugar de las piezas de lámina.
