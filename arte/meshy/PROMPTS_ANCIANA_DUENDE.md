# Anciana duende (NPC, 23 de octubre de 2026)

Fuente: la ficha de personaje de Pablo («Anciana duende»: gorro rojo larguísimo con borla dorada,
trenzas canosas, túnica roja con bordados dorados, bastón retorcido, piel verde clara, colmillos).

**Lo que cambia respecto a la ficha para que se pueda riggear** (como con el elfo y el goblin base):
- **A-pose y manos vacías.** El bastón es una pieza aparte que se cuelga de la mano en Godot. La postura
  encorvada apoyada en el bastón va en las animaciones, no en el modelo.
- **El gorro.** En la ficha la punta llega al suelo: el autorig la pegaría a la espalda y a las piernas y se
  estiraría al andar. Se pide **más corta, hasta media espalda**, cayendo pegada a la espalda, con la borla
  ahí. Si se quiere larga de verdad, después se le añade una cadena de huesos con muelle (se puede hacer en
  Godot), pero el modelo tiene que llegar así.
- **La túnica, hasta media espinilla** y abierta por los lados. Hasta el suelo, las piernas la deforman en
  cada paso. Los pies tienen que verse.
- **Mangas anchas pero por encima de las muñecas.** Las manos libres, sin tela encima.
- **Trenzas cortas** (hasta el pecho), pegadas al cuerpo.
- **Altura en el juego:** familia goblin. Ella más bajita que el goblin guerrero, unos 0,80 (la ficha dice
  1,60 m, que en nuestra escala es «adulta pequeña»).

---

## 1. Imagen de concepto (A-pose)

**Referencia:** la ficha de Pablo (vista frontal) como imagen de estilo y personaje. Si el generador admite
dos referencias, añade una captura de frente de `goblin_warrior_chibi.glb` para la proporción.

> Same character as the reference sheet: an old goblin grandmother («anciana duende»), 3D chibi game style,
> about 3 heads tall, pale lime-green skin, long pointed ears, wrinkled stern face with thick grey eyebrows,
> big brown eyes, a long hooked nose, two small white lower tusks. Long grey-silver hair in two braids that
> reach only the chest, each braid with small gold rings and a tiny gold tassel. A deep crimson velvet
> stocking cap with a wide gold-embroidered flower band around the head; the long cap tip falls straight
> down against her back and ends at MID-BACK with a gold bead and gold tassel (the tip does not reach the
> legs or the floor). A crimson velvet robe with gold floral embroidery on the hems and the front, wide
> sleeves that end ABOVE THE WRISTS (hands fully visible and free), a braided cord belt with a small leather
> pouch, the robe ends at MID-SHIN with side slits, simple brown cloth shoes visible. EMPTY HANDS: no staff,
> no cane, no props. Standing upright (not hunched), full body, front view, symmetrical A-pose with arms 35
> degrees away from the body, palms down, fingers apart, legs slightly apart, plain light background, soft
> even lighting.

**Si sale mal:**
- **Encorvada o con el bastón:** *"standing straight, upright posture, hands completely empty"*.
- **La punta del gorro baja a las piernas:** *"the cap tip ends at the middle of her back"*.
- **Túnica hasta el suelo:** *"robe ends at mid-shin, feet clearly visible"*.
- **Mangas tapando las manos:** *"sleeves end above the wrists, bare hands"*.

## 2. Meshy, de imagen a 3D

> chibi old goblin grandmother, crimson embroidered robe and long stocking cap, A-pose, empty hands, game
> character, ready for rig, no props

Nombre al instalar: `anciana_duende`.

## 3. El bastón (aparte)

> stylized chibi game prop: a gnarled twisted wooden walking staff, dark brown wood with knots, a curled
> twisting top, a small gold bell and a tiny gold tassel hanging from the top, hand-painted texture,
> single object, no hand, plain background

Nombre al instalar: `baston_anciana`. Alto en el juego: más o menos el de ella (0,8).

## 4. Animaciones que le harían falta

| Rol | Qué |
|---|---|
| `idle` | encorvada, apoyada en el bastón con la mano derecha |
| `walk` | paso corto y lento con el bastón |
| `talk` | gestos con la mano libre (seria / irritada) |
| `pensar` | mano libre en la barbilla (la expresión «pensativa» de la ficha) |

Si lleva esqueleto Mixamo, comparte nombres con `goblin_base` y el asesino: se le pueden pasar clips de
ellos (hablar, por ejemplo) con `ClipsFamilia`.
