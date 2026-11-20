# Benvito Brisaboa, el nuevo guardabosques (20 de noviembre de 2026)

Diseño de Pablo («Benito»): goblin joven de piel verde, pelo negro despeinado, nariz chata rosada, pecas y sonrisa pícara; coroza de paja (capa
gallega de paja) en capas que cubre hombros y espalda y baja hasta las rodillas, con capucha de paja en punta; túnica verde con costuras, cinturón de
cuero con bolsa, pantalón marrón abombado, botas atadas con cuerda; bastón de madera con el remate en gancho atado con cuerda.

En `docs/PLAN_MONTE_SUMICIO.md` e `INVENTARIO_MONTE_SUMICIO.md` (BE-01) es Benvito Brisaboa: llega al Puesto del Guardabosques tras la derrota del
Canouro y abre descanso, cura, obrador y baúl. El inventario dice «coroza y gorro rojo»; el diseño trae capucha de paja. Este prompt sigue el diseño.

**Rig:** Meshy + Mixamo, como Pedro Chosco y la Moura. Un modelo para él y otro para el bastón (se le pone en la mano en el juego).

**Lo que más riesgo tiene:** la coroza cuelga a los lados JUNTO a los brazos. Si la paja toca el brazo en la pose A, el rig le da peso de brazo y la
capa se estira al moverlos. Si queda por fuera y el brazo pasa dentro, el brazo la atraviesa al balancearse.

**Cambios sobre el diseño, solo por el rig:**
- La coroza cubre hombros, pecho y espalda; por los lados queda ABIERTA bajo los hombros, de modo que los brazos salen libres por la abertura y la
  paja no los toca. Por detrás baja hasta las rodillas; por delante, hasta la cintura (la túnica y el cinturón se ven).
- La capucha de paja en punta va rígida sobre la cabeza; las orejas salen por debajo, sin atravesarla.
- La bolsa, plana contra la cadera.
- Manos vacías, sin bastón.

---

## 1. Imagen de concepto limpia

**Referencia de estilo:** el diseño de Pablo y una captura de frente de `arte/modelos/goblin_base.glb` (familia goblin).

> Same 3D stylized goblin style and body proportions as the reference. A single character: Benvito, a cheerful young goblin forest ranger with green
> skin, big pointed ears, a small round pink nose, freckles, messy short black hair and a mischievous grin, eyes open. A traditional layered straw
> rain cape (coroza) made of thick overlapping straw tufts, covering the shoulders, the chest and the back, reaching the knees at the back and the
> waist at the front, and OPEN at both sides below the shoulders so the arms come out freely and the straw does NOT touch the arms. A pointed straw
> hood resting on the head, the ears coming out below it. A green stitched tunic, a brown leather belt with a small pouch lying FLAT against the
> left hip, loose brown trousers and brown boots wrapped with rope. EMPTY HANDS, no staff, no props. Full body, front view, symmetrical A-pose with
> arms 40 degrees away from the body, palms down, fingers apart, legs slightly apart, head straight looking forward, plain dark background, soft
> even lighting.

Si la paja toca los brazos: *"the straw cape open at the sides, arms completely free of the straw"*. Si la coroza sale hasta los pies por delante:
*"straw cape reaching only the waist at the front"*.

## 2. Meshy, de imagen a 3D (él)

> young goblin forest ranger, layered straw rain cape open at the sides, pointed straw hood, A-pose, empty hands, nothing dangling, game character,
> ready for rig, no props

- Con textura. Rig con Meshy + Mixamo: quieto, andar y hablar como mínimo (si hay uno de reír o saludar, también le va).
- Nombre al instalar: `benvito`.

## 3. El bastón (aparte)

> A rustic wooden walking staff, dark brown knotted wood, the top bent into an open hook, the bend wrapped with a few turns of tan rope, stylized 3D
> game prop matching the reference style, standing upright, plain background.

- Sin rig. Nombre al instalar: `baston_benvito`.
