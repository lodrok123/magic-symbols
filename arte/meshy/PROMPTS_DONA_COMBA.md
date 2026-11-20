# Doña Comba, la tendera de Monte Sumicio (20 de noviembre de 2026)

Diseño de Pablo: goblin regordeta con vestido azul marino, delantal, cinturón con bolso, llaves y saquito, aros en las orejas.
Se riggea con el esqueleto de `goblin_base` partiendo de `tools/autorig_tendera.py` (las articulaciones se miden de nuevo sobre su malla,
que es más ancha que la de Bramblebraid). Los clips son los de la tendera: idle, andar, hablar y atender en el mostrador.

**Cambios sobre el diseño, solo por el rig:**
- Sin el manojo de llaves ni el saquito: cuelgan delante del muslo, Meshy los funde con la falda y se deforman con la pierna. Si se quieren,
  van después como objetos sueltos en la cadera.
- Se quedan el bolso (pegado y plano a la cadera, por fuera de la pierna), el cinturón y el delantal (plano, sin cintas colgando).
- Aros pequeños y pegados al lóbulo, que no toquen el cuello ni el pelo.
- Pose A con las manos lejos de la falda, cabeza recta mirando al frente.

---

## 1. Imagen de concepto limpia (si no se usa la del diseño tal cual)

**Referencia de estilo:** el diseño de Pablo y una captura de frente de `arte/modelos/tendera_sumicio.glb` (misma familia goblin).

> Same 3D stylized goblin style and proportions as the reference. New character: a plump, cheerful middle-aged goblin shopkeeper woman
> with olive-green skin, big pointed ears, a round orange-pink nose, a mischievous toothy grin and warm brown eyes. Voluminous black
> curly hair that ends at the jaw and neck, NOT touching the shoulders or the arms. Small gold hoop earrings hanging close to the
> earlobes. Navy-blue dress with a square neckline and gold front lacing, short puffy sleeves ending above the elbow with a cream
> scalloped trim and a small gold leaf pattern. A full skirt to mid-calf with a gold leaf border at the hem, the brown ankle boots fully
> visible below it. A brown leather belt with a gold buckle. A tan apron lying flat on the front of the skirt with a navy leaf pattern,
> no ties or ends hanging. A small brown leather satchel attached flat against the left hip. NO KEYS, NO SACK, NO POUCH, nothing hanging
> from the belt. EMPTY HANDS, no props. Full body, front view, symmetrical A-pose with arms 40 degrees away from the body, hands well
> clear of the skirt, palms down, fingers apart, legs slightly apart, head straight looking forward, plain dark background, soft even
> lighting.

Si salen las llaves igualmente: *"remove the bunch of keys and the small sack from the belt"*. Si el pelo cae sobre los hombros:
*"shorter hair, ending above the shoulders"*.

---

## 2. Meshy, de imagen a 3D

> plump goblin shopkeeper woman, navy dress, apron, A-pose, empty hands, nothing hanging from the belt, game character, ready for rig, no props

- **Sin rig** en Meshy: el rig lo pone `tools/autorig_tendera.py` con el esqueleto de `goblin_base`.
- Con textura, y con vistas de lado y espalda si las genera.
- Nombre al instalar: `dona_comba`.
