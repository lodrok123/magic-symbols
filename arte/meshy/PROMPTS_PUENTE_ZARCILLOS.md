# Prompts del puente de zarcillos (23 de noviembre de 2026)

Fase 2 del puente que crece con agua. Sustituye a los modelos provisionales del prototipo, que usaba un tocón y raíces: `tronco_seco`, `tronco_musgoso` y `raices_musgo`.
Referencia principal: `referencias/puzles/puente_zarcillos_piedra_surco.png`. Otras referencias: `puente_enredaderas_arranques.png` para la piedra con surco y `puente_enredaderas_concepto.png` para el tejido.

**Qué tiene que contar la pieza.** La secuencia es «riega el surco → el nudo se abre → se teje el paso». El agua cae en el hueco de la piedra, baja por el surco y despierta un nudo de zarcillos dormido. Del nudo sale un abanico de zarcillos que se teje hasta la otra orilla y se agarra a dos postes de roca.

Se usa el mismo método que en `PROMPTS_AGUA.md`. Pega el bloque [ESTILO] **al final** de cada prompt.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, low contrast albedo,
no harsh baked shadows, no baked lighting, single object, centered, no base, no ground plane,
no background, no outline, no black lines.
```

## Reglas que NO son de estilo

1. **Sin agua en ningún modelo.** El hueco de la piedra se pide **seco**. El motor llena el hueco y pinta el chorro que cae al nudo, como hace con el cuenco de agua. Si el agua viene pintada, la piedra parecerá llena antes de regarla.
2. **El nudo dormido no puede parecer paja.** En este juego lo seco y pajizo arde (hierba, setos, juncos) y el fuego es el primer sello. Si el nudo parece seco, la jugadora lo quemará. Tiene que verse **verde oliva apagado, carnoso y enrollado apretado**, como un helecho que espera. Nada de amarillo paja ni marrón quebradizo.
3. **Un único verde para todo lo vivo.** El nudo despierto, el arranque, el tramo y los anillos del anclaje usan el mismo verde lima suave de la referencia (≈ `#9CC94A` de base, con sombras hacia `#5E8F2E` y luces hacia `#D4EC8A`). Si cada pieza sale con su propio verde, el puente parece hecho de trozos.
4. **Las piezas del puente se encadenan.** El arranque y el tramo terminan en un **corte limpio a la misma altura y el mismo ancho**, sin zarcillos que sobresalgan por delante o por detrás. Los rizos solo van en los lados. El shader del juego hace crecer cada tramo de un extremo al otro a lo largo de X, así que la textura no debe tener brillos ni detalles que dependan de esa dirección.
5. **Se ve desde arriba.** La cámara es fija y cenital inclinada, así que el tejido tiene que leerse en la cara superior. La cara de abajo también se ve sobre el agua y debe llevar textura, sin agujeros negros.
6. **Lo que se pisa es plano.** La parte superior del arranque y del tramo es casi plana: la jugadora camina por encima y el juego la pone a una altura fija. En el modelo no puede haber arco ni comba.
7. **Medidas.** Una casilla mide 2,3 u y la jugadora ~1 u.

   | Pieza | Medida | Triángulos | Textura |
   |---|---|---|---|
   | Piedra con surco | ~1,7 × 1,2 u de planta, ~0,6 u de alto | 1.500–2.500 | 1024² |
   | Nudo | ~0,7 u de diámetro, ~0,35 u de alto | 600–1.200 | 512² |
   | Arranque | 2,3 u de largo (X); estrecho junto al nudo (~0,5 u) y ~1,6 u en el extremo; ~0,35 u de grueso | 1.000–2.000 | 512² |
   | Tramo tejido | 2,3 × 1,6 u, ~0,3 u de grueso | 800–1.500 | 512² |
   | Anclaje | ~1,8 u de ancho; postes de ~1,2 u de alto | 1.500–2.500 | 1024² |

8. **Origen y orientación.** El origen va en el centro de la base, con Y hacia arriba. **Todo lo que apunta hacia el puente mira a +X**: el surco de la piedra, el nudo, el arranque y el tramo crecen hacia +X. En el anclaje, el tejido llega desde −X.
9. **Ids** en `arte/meshy/piezas/`:
   - `piedra_surco.glb`
   - `nudo_zarcillos_dormido.glb` y `nudo_zarcillos_vivo.glb`
   - `zarcillos_arranque.glb`
   - `zarcillos_tramo.glb`
   - `zarcillos_anclaje.glb`
   - De la fase 3, si se hace: `zarcillos_tramo_quemado.glb`

   Al recibirlos hay que cambiar en el código las rutas provisionales y sustituir el tocón por piedra + nudo. Es un encargo pequeño.

## Cómo se monta en el juego

Esto explica para qué sirve cada pieza.

| Momento | Qué se ve | Piezas |
|---|---|---|
| Antes | La piedra con el hueco seco y, en la boca del surco, el nudo dormido (verde oliva y apretado) | `piedra_surco` + `nudo_zarcillos_dormido`, en la misma casilla: la piedra ocupa ~¾ y el nudo el borde que da al agua |
| Riega el surco | El motor sube el agua en el hueco y deja caer un hilo por el surco hasta el nudo | `piedra_surco` (el agua es del motor) |
| El nudo se abre | El nudo cambia a la malla viva con un pequeño salto, gira un poco al desenrollarse y suelta esporas verdes | `nudo_zarcillos_vivo` (giro y escala por código, sin esqueleto) |
| Se teje el paso | De la casilla del nudo hacia fuera: primero el abanico y luego un tramo tejido por casilla. Cada uno se revela de −X a +X con un frente verde brillante | `zarcillos_arranque` (1.ª casilla), `zarcillos_tramo` (las demás) |
| Se agarra | En la otra orilla, los anillos se cierran sobre los postes | `zarcillos_anclaje` |

---

## 1. Piedra con surco — `piedra_surco`

**Para qué:** recibe el agua y la lleva al nudo. Es lo primero que ve la jugadora, y tiene que pedir agua sin explicación.

> A low chunky natural stone basin, rounded weathered grey-beige rock with soft moss patches on the sides, carved by time with a smooth shallow hollow on top shaped like a rounded figure-eight. The hollow is completely DRY and empty, its bottom a little darker with a thin crust of dry earth. From the hollow, a narrow worn groove runs across the top and spills over one edge (+X) like a small natural spout, clearly showing where water would flow out. Smooth rounded edges, readable from above. No water, no puddle, no plants inside the hollow.

## 2. Nudo de zarcillos — `nudo_zarcillos_dormido` y `nudo_zarcillos_vivo`

**Para qué:** el origen de las enredaderas. Las dos versiones tienen **la misma geometría**. Genera primero la dormida y saca la viva con *Retexture* sobre ese mismo modelo. Si la forma cambia, el cambio se lee como «otro objeto» y no como «despierta».

**Dormido:**
> A tight coiled knot of thick plant tendrils resting on the ground, like a sleeping curled fern fiddlehead or a coiled spring: four or five fleshy tendrils wound tightly in a low spiral, their tips tucked inside, one tendril end pointing outward to one side (+X). Muted dull olive green with soft grey-green tones, slightly wilted and matte, looking dormant and thirsty, but still alive and supple. NOT dry straw, NOT yellow, NOT brown, NOT brittle, no leaves, no flowers.

**Vivo** (Retexture):
> The same coiled tendril knot, awake and full of life: fresh soft lime green, juicy and slightly glossy, lighter green tips, a few tiny new leaves budding from the coil. Same shape.

## 3. Arranque — `zarcillos_arranque`

**Para qué:** la primera casilla del puente. Es el abanico de zarcillos que sale del nudo y se cierra hasta formar el tejido.

> A fan of long flexible plant tendrils emerging from a narrow point at one end (−X) and spreading out along the length (+X), where they start crossing and weaving together into a flat wicker-like mesh, so that the far end (+X) becomes a flat woven strip with a clean straight edge. A few loose tendrils curl into spiral tips on the left and right sides, with small ivy leaves here and there. Soft lime green, rounded thick tendrils. Mostly flat and low; the top surface is walkable. Long horizontal piece.

## 4. Tramo tejido — `zarcillos_tramo`

**Para qué:** las casillas del centro. Se repite tantas veces como haga falta.

> A straight flat section of a woven natural bridge made of thick lime green plant tendrils interlaced like wicker basket weave, a regular over-and-under pattern clearly visible from above, two thicker tendrils running along the left and right edges as borders, a few small curling tendril spirals and tiny ivy leaves on the sides only. Both ends are cut straight and clean with exactly the same width and height so the piece tiles seamlessly end to end. Flat walkable top, low and horizontal, textured underside.

Pide dos generaciones y elige la más regular. Si salen dos buenas, el juego puede alternarlas.

## 5. Anclaje — `zarcillos_anclaje`

**Para qué:** la otra orilla. Muestra que el puente queda sujeto y no flota.

> Two short rounded standing stones side by side on a small mossy rock ledge, weathered grey-beige like the stone basin, each wrapped by two or three thick lime green tendril rings coiled tightly around it. From the rings, the tendrils run down and back (−X) and join into the end of a flat woven wicker strip with a clean straight edge, the same width as the bridge. Small ivy leaves on the rings. Readable from above.

**Plan B** si Meshy no la saca entera: pide solo los **anillos de zarcillo**, un aro grueso enroscado de ~0,6 u de diámetro, y ponlos sobre rocas que ya existan. El final del tejido se hace con un `zarcillos_tramo`.

---

## Fase 3 (opcional): el puente que arde

Si se hace la reactividad al fuego (el puente arde y vuelve a crecer al regar), hace falta la versión quemada del tramo. Saca `zarcillos_tramo_quemado` con *Retexture* sobre el tramo elegido:
> The same woven tendril bridge section, burnt: charred dark brown and black tendrils, cracked, with a few glowing orange ember spots and grey ash on top. Same shape.

El nudo y la piedra no se queman: el nudo vuelve a quedar dormido y se puede regar otra vez. Así nunca hay bloqueo.
