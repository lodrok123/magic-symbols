# El Inquisidor (20 de noviembre de 2026)

Diseño de Pablo: joven humano chibi de pelo castaño ondulado, ojos dorados que brillan, cicatriz en la frente y gesto serio; coraza de cuero marrón
con hombreras doradas, medallón de pez entre laureles en el pecho y un puñal prendido; capa roja con embozo alrededor del cuello, sujeta con un
broche de estrella; faldellín de tiras (pteruges) sobre la rodilla; brazales; grebas con laurel dorado; botas. Escudo rojo alargado con el pez, los
laureles y estrellas; espada curva en su vaina colgando de la cadera.

**Riesgo bajo en el cuerpo:** coraza ceñida, faldellín corto y brazos libres. **Lo único delicado es la capa**, que cae por detrás hasta las
pantorrillas: si el rig le da peso de las piernas se parte en dos al andar (lo que pasó con la falda de la Moura). Se arregla igual que allí y que
con la coroza de Benvito: la capa pesa en la cadera y la espalda. **El escudo y la espada van aparte** y se le ponen en la mano o en la cadera en el
juego: colgando del cinturón, la espada recibiría peso del muslo y se doblaría al andar.

**Rig:** Meshy + Mixamo, como Pedro Chosco y la Moura. Si la capa se parte, la arreglo editando solo los pesos del GLB, sin tocar sus animaciones.

**Cambios sobre el diseño, solo por el rig:**
- La capa cae por la ESPALDA, por detrás de los brazos, sin tocarlos ni envolverlos; el embozo, ceñido al cuello.
- Sin espada ni vaina en la cadera, sin escudo. El puñal del pecho, plano contra la coraza.
- Las tiras del faldellín, cortas y pegadas, sin colgar sueltas.
- Pose A con los brazos a 40°, cabeza recta, ojos abiertos.

---

## 1. Imagen de concepto limpia

**Referencia de estilo:** el diseño de Pablo y una captura de frente de `arte/modelos/jugadora_base.glb` (proporciones chibi).

> Same 3D stylized chibi style and body proportions as the reference. A single character: the Inquisitor, a stern young human soldier with wavy
> chestnut brown hair, glowing golden eyes, a small scar on the forehead and a serious frown. A brown leather muscle cuirass with gold trim and gold
> shoulder guards, a round red emblem with a golden fish between laurels on the chest and a small golden dagger fixed FLAT against the cuirass. A
> red cloak with a soft scarf collar wrapped SNUGLY around the neck, fastened with a round gold star brooch; the cloak falls straight down the BACK,
> behind the arms, to mid-calf, NOT touching or wrapping the arms. A short pleated brown skirt of leather strips with gold trim above the knee, the
> strips short and close to the body. Brown leather bracers with gold rims, brown greaves with golden laurel decoration and brown boots. NO sword,
> NO scabbard, NO shield, EMPTY HANDS, no props. Full body, front view, symmetrical A-pose with arms 40 degrees away from the body, palms down,
> fingers apart, legs slightly apart, head straight looking forward, plain dark background, soft even lighting.

Si la capa envuelve los brazos: *"the cloak hangs only down the back, behind the arms"*. Si sale con la espada: *"remove the sword and the
scabbard from the belt"*.

## 2. Meshy, de imagen a 3D (él)

> stern young chibi soldier, leather cuirass, red cloak down the back, A-pose, empty hands, no weapons, game character, ready for rig, no props

- Con textura. Rig con Meshy + Mixamo: quieto, andar, hablar y, si su papel lo pide, uno de ataque con espada y escudo.
- Nombre al instalar: `inquisidor`.

## 3. El escudo (aparte)

> A tall curved rectangular Roman shield (scutum) with rounded corners, deep red with a gold rim studded with small gold rivets, a golden fish
> curled inside a laurel wreath in the centre, a golden eight-pointed star above and below, stylized 3D game prop matching the reference style,
> front view, plain background.

- Sin rig. Nombre al instalar: `escudo_inquisidor`.

## 4. La espada (aparte)

> A short slightly curved sword in its scabbard, dark red leather scabbard with gold fittings and two gold rings, gold crossguard and a pale bone
> grip with a gold pommel, stylized 3D game prop matching the reference style, plain background.

- Sin rig. Nombre al instalar: `espada_inquisidor` (si se quiere sacar en combate, mejor generar también la hoja sin vaina).
