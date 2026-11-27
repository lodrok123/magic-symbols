# Goblin asesino, rediseño sin dagas (27 de noviembre de 2026)

Sustituye al del 22 de octubre. Pablo: las dagas no hacen falta y el modelo no encaja con el estilo. El anterior tenía la
piel amarilla del aldeano (`goblin_base`), cuero oscuro realista y dos sables negros; los goblins enemigos
(`goblin_warrior_chibi`, `goblin_archer_chibi`) son de piel verde pálida, trapo y piel raídos, cuerda y pies descalzos.

**Qué cambia:**
- **Ataca con las manos.** Uñas largas y oscuras. Los dos cortes del ataque doble pasan a ser dos zarpazos.
- **Misma familia:** piel, orejas, telas y paleta del guerrero y el arquero.
- **Silueta propia:** gorro de punta larga curvada (se conserva la idea, pero de fieltro remendado), pañuelo que le tapa la
  boca y capa corta de tiras de hierba y hojas, porque nace en la hierba alta.

**Cómo se reparte el trabajo (igual que antes):**
- **A-pose y manos vacías.** No hay armas que colgar.
- **Lo agazapado es una animación**, no la pose del modelo.
- **La punta del gorro, rígida** y por encima de los hombros. **La capa, corta:** hasta media espalda, sin tocar los brazos.

---

## 1. Imagen de concepto

**Referencia de estilo:** una captura de frente de `arte/modelos/goblin_warrior_chibi.glb`.

> Same 3D chibi goblin style, same body proportions, same head, big pointed ears with pink inner ear and same PALE GREEN
> skin as the reference goblin, about 3 heads tall. New character: a goblin STALKER, lean and wiry with slightly longer
> arms, sly narrow eyes. Hands: long thin fingers ending in long dark pointed claws, ragged cloth wraps around the
> forearms. Headwear: a patched brown FELT cap with a rolled brim and a LONG pointed tip that curves backwards in a stiff
> arc and stays above the shoulders; the ears come out under the brim. A ragged cloth scarf covering the mouth and nose.
> A SHORT cape of dry grass strips and leaves, moss green and straw, tied at the neck and ending at mid-back, not touching
> the arms. Torn brown cloth tunic, rope belt, ragged short trousers, cloth wraps on the shins, bare feet. Muted palette:
> warm browns, straw, moss green. EMPTY HANDS: no daggers, no weapons, no sheaths, no props. Standing upright, full body,
> front view, symmetrical A-pose with arms 35 degrees away from the body, palms down, fingers apart, legs slightly apart,
> plain light background, soft even lighting.

**Si sale mal:**
- **Piel amarilla u oliva oscura:** *"pale light green skin exactly like the reference"*.
- **Cuero oscuro, hebillas, aspecto realista:** *"ragged cloth and rope only, no leather armour, no buckles"*.
- **Garras de metal o guanteletes:** *"natural claws, bare hands"*.
- **La capa cae sobre los brazos:** *"cape short and narrow, only on the back"*.
- **Agachado:** *"standing straight, upright posture, A-pose"*.

## 2. Meshy, de imagen a 3D

> chibi goblin stalker, pale green skin, felt cap with long stiff curved tip, grass cape, clawed bare hands, A-pose, empty
> hands, game character, ready for rig, no weapons

Nombre al instalar: `goblin_asesino` (sustituye al actual). Altura en el juego: 0,85, como la familia goblin.
Rig con Mixamo (`mixamorig:*`), para que sigan valiendo los clips que ya tiene.

## 3. Al instalarlo (código)

- Quitar las dos `daga_goblin` que le cuelga `Equipo3D`, y lo que las comprueba en `herramientas/prueba_goblin_asesino.gd`
  y `captura_goblin_asesino.gd`.
- `attack`: los mismos dos cortes cruzados sirven de zarpazos; revisar `Pj3D.MOMENTOS_CORTE["goblin_asesino"]` con el clip.
- El alcance (`ANCHO_CORTE_ASESINO`, `RANGO_ATAQUE + 0.5`) se midió con sables: sin ellos, acortar el frente unos 0,3.

## 4. Animaciones

Las mismas de la versión anterior (`idle`, `walk` y `run` agazapados, `attack` doble, `hit`, `death`, `empujado`,
`levantarse`). En `idle`, las manos abiertas y bajas, con las uñas a la vista.
