# Pedro Chosco (20 de noviembre de 2026)

Diseño de Pablo: elfo anciano de barba y melena blancas, hábito verde oliva bordado de hojas y flores con la orla dorada, mangas de campana con puño
crema, capucha bajada sobre los hombros, broche del árbol, saya crema hasta los pies con trenzado dorado, cinturón de cuero con un libro y un frasco,
botas marrones.

**Una sola malla, no hace falta separarla.** Con el hábito pasa lo mismo que con la falda de Doña Comba: es ancho de abajo (forma de A) y él anda
despacio, así que basta con que la tela pese en la cadera (regla de falda) y no en los muslos. Se riggea con el esqueleto de `elfo_base` (familia del
elfo, como el fantasma: `tools/autorig_fantasma.py`) y anda con el andar de anciano de Mixamo. Las reglas de pesos que harán falta:
- **Hábito y saya:** lo que no es piel por debajo del cinturón pesa en la cadera (con un poco de pierna junto al bajo para que se meza).
- **Mangas de campana:** solo brazo y antebrazo, nada de torso; la boca de la manga, solo antebrazo.
- **Barba:** cabeza arriba y pecho abajo, en degradado: entera a la cabeza, su punta barrería el pecho al asentir.
- **Melena:** a la cabeza y al cuello.
- **Capucha bajada y capelina:** al pecho y a las clavículas.

**Cambios sobre el diseño, solo por el rig** (lo que Meshy debe sacar distinto):
- Brazos más separados del cuerpo (40°) para que las mangas de campana cuelguen libres y no se fundan con el hábito.
- La melena cae por la espalda, no por encima de las mangas.
- La barba descansa sobre el pecho; que no toque los brazos ni las mangas.
- El bajo del hábito acaba justo por encima de los tobillos y se abre en A, separado de las piernas; las botas se ven enteras.
- El libro va plano y pegado a la cadera en su funda. El frasco, atado corto contra el cinturón, sin colgar.
- Manos vacías, sin bastón.

---

## 1. Imagen de concepto limpia

**Referencia de estilo:** el diseño de Pablo y una captura de frente de `arte/modelos/elfo_base.glb` (mismas proporciones de elfo chibi, unas 3 cabezas).

> Same 3D stylized chibi elf style and body proportions as the reference (about 3 heads tall). New character: a kind but stern elderly elf sage with
> long pointed ears, big bushy white eyebrows, warm brown eyes, a long wavy white beard and moustache resting on the chest, NOT touching the arms or
> the sleeves, and long wavy white hair falling BEHIND the shoulders, down the back. An olive-green robe embroidered with golden leaves and small cream
> flowers, with a gold trim, open at the front over a cream under-robe with a golden braided band down the middle. Wide bell sleeves with cream cuffs
> and a golden braided pattern, hanging free from the body. A green hood lowered and resting on the shoulders like a small capelet, fastened with a round
> gold brooch with a tree emblem. A brown leather belt with a round gold tree buckle; a small brown leather book in a holder attached FLAT against the
> left hip; a small glass flask tied SHORT and tight against the belt, not dangling. The robe flares into an A-shape away from the legs and ends just
> above the ankles, the brown leather boots fully visible. EMPTY HANDS, no staff, no props. Full body, front view, symmetrical A-pose with arms
> 40 degrees away from the body, the bell sleeves hanging clear of the robe, palms down, fingers apart, legs slightly apart, head straight looking
> forward, plain dark background, soft even lighting.

Si las mangas se funden con el hábito: *"arms further from the body, the sleeves must not touch the robe"*. Si la barba o el pelo caen sobre los brazos:
*"beard shorter, hair behind the shoulders"*. Si el frasco cuelga: *"the flask tied tight against the belt"*.

---

## 2. Meshy, de imagen a 3D

> elderly elf sage, long olive-green robe, bell sleeves, white beard, A-pose, empty hands, nothing dangling, game character, ready for rig, no props

- **Sin rig** en Meshy: el rig lo ponemos nosotros con el esqueleto de `elfo_base`.
- Con textura, y con vistas de lado y espalda si las genera.
- Nombre al instalar: `pedro_chosco`.
