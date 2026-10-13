# Texturas del suelo — prompts (versión 2, 5 de octubre)

La versión de Meshy salió mal en todas: saturada, con piedras y flores pintadas encima, bordes redondeados y
poca resolución. Lección: **el suelo se genera como imagen plana** (el mismo generador que hizo la lámina) y
**casi sin detalle**. El detalle (matas, flores, piedras) lo ponen los modelos 3D sueltos.

## Cómo generarlas
- Una imagen por tipo, **cuadrada, 1024 px o más**. Si el generador tiene opción "tileable / seamless", actívala.
- Imagen de referencia de estilo: `poc_25d\meshy\referencias\_lamina.png` (o una captura de la chibi en el bosque).
- Genera 3–4 y quédate con la **más tranquila**: a la que menos se le noten manchas sueltas.
- Déjalas en `poc_25d\suelo_meshy\entrada\` con el nombre del tipo (`hierba_arriba.png`, …). Claude comprueba
  que repiten bien en 2×2, corrige las costuras y las instala.

## Bloque común (va delante de cada prompt)
```
Seamless tileable square texture seen from directly above, orthographic, no perspective. Hand-painted stylized
like a cozy anime / Ghibli game, soft pastel palette matching the reference image. Very low contrast, soft large
brush shapes, no hard outlines, no objects, no shadows, flat even lighting, no border, no vignette. The pattern
continues across all four edges and fills the entire square.
```

## Negativo (si el generador lo admite)
```
photorealistic, high contrast, noise, grain, outlines, border, frame, vignette, rocks, pebbles, flowers, leaves,
objects, perspective, 3D, text, logo
```

## Prompts por tipo

**hierba_arriba**
```
Short soft grass, pastel mint green (#a8d9a0) with gentle lighter (#c2e6b6) and slightly darker (#8cc68a)
patches, tiny soft brush strokes suggesting grass blades, calm and even, nothing else.
```

**path_arriba**
```
Packed sandy path, pale cream (#ffe8aa) with soft warm peach (#f9d09a) patches, very fine faint grain,
calm and even, nothing else.
```

**dirt_arriba**
```
Soft garden soil, warm peach-brown (#e6b98f) with gentle darker (#d9a077) patches and a few tiny faint specks,
calm and even, nothing else.
```

**stone_arriba**
```
Large irregular rounded flagstones, pale lavender-grey (#dde0ea), four to six stones filling the square,
soft seams in slightly darker grey (#b9bed0), very subtle tint variation, no moss, no cracks.
```

**water_arriba**
```
Calm shallow water, light turquoise (#a3dbe0) with soft lighter (#d4f1f2) painted ripple shapes and gentle
deeper (#7fb9c6) patches, nothing else.
```

**cuerpo** (los costados de los bloques)
```
Side view of soil, warm peach-brown (#e6b98f) with soft horizontal layers in slightly darker tones (#d9a077,
#c99470), a few very faint thin roots, calm and even. Seamless both horizontally and vertically.
```

## Orden
Primero `hierba_arriba` (es la mayor parte del suelo) y `cuerpo`. Con esas dos ya se juzga el aspecto.
