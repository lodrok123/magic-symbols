# Goblin asesino (enemigo nuevo, 22 de octubre de 2026)

Pedido de Pablo: un goblin asesino con la idea de los goblins enemigos (`goblin_warrior_chibi`,
`goblin_archer_chibi`), un gorro como el de `goblin_base` (copa de fieltro con el borde vuelto) pero de
**cuero** y con la **punta larga**, ataque con **dos armas** y movimiento **agazapado**.

**Cómo se reparte el trabajo:**
- **El modelo va en A-pose y con las manos vacías.** Las dos armas son piezas aparte que se cuelgan de
  las manos en Godot (`Equipo3D`, como el escudo del goblin). Si las armas vienen pegadas a la malla, no
  se pueden cambiar, el autorig las deforma y las manos no cierran bien.
- **Lo agazapado es una animación, no la pose del modelo.** El modelo de pie y recto; el andar agazapado
  y el ataque doble son clips (Meshy, Mixamo o Tripo).
- **La punta del gorro, rígida.** Larga, pero de cuero endurecido que se curva hacia atrás y queda por
  encima de los hombros. Si cae sobre la espalda, el autorig la pega a la columna y se deforma al andar.

---

## 1. Imagen de concepto

**Referencia de estilo:** una captura de frente de `arte/modelos/goblin_warrior_chibi.glb` (mismo estilo,
misma cabeza, orejas y ojos). Si el generador admite dos referencias, añade la imagen del gorro.

> Same 3D chibi goblin style, same body proportions, same head, big pointed ears and eyes as the reference
> goblin, about 3 heads tall. New character: a goblin ASSASSIN, lean and wiry, olive-green skin, sharp sly
> narrow eyes, a thin confident smirk, a small scar across the nose. Headwear: a fitted dark brown LEATHER
> cap with a thick rolled-up leather brim around the head (like a folded beanie), stitched seams, and a
> LONG pointed tip made of stiff hardened leather that curves backwards in a gentle arc and stays above the
> shoulders (not flopping down onto the back). The ears come out under the brim. Outfit: dark charcoal and
> brown fitted leather jerkin with straps crossing the chest, a hooded short scarf wrapped around the neck
> and lower face pulled down, leather bracers on the forearms, dark cloth wraps on the hands with bare
> fingers, a wide belt with small pouches and two EMPTY dagger sheaths on the hips, tight dark trousers
> wrapped with cloth strips at the shins, soft leather wraps on the feet with bare toes. Muted palette:
> charcoal, dark brown, deep olive, a touch of dull red on the scarf. EMPTY HANDS: no daggers, no weapons,
> no props in the hands. Standing upright, full body, front view, symmetrical A-pose with arms 35 degrees
> away from the body, palms down, fingers apart, legs slightly apart, plain light background, soft even
> lighting.

**Si sale mal:**
- **Agachado o encorvado:** *"standing straight, upright posture, A-pose"*.
- **Con armas en las manos:** *"hands completely empty and open, sheaths are empty"*.
- **La punta del gorro cae por la espalda:** *"the cap tip is stiff and short enough to stay above the
  shoulders, curving backwards"*.
- **Ojos de chibi enormes:** *"small narrow eyes, no sparkles"*.

## 2. Meshy, de imagen a 3D

> chibi goblin assassin, leather cap with long stiff pointed tip, A-pose, empty hands, game character,
> ready for rig, no weapons

Nombre al instalar: `goblin_asesino`. Altura en el juego: 0,85, como la familia goblin.

## 3. Las dos armas (aparte)

Dos dagas curvas de goblin, una para cada mano. Mismo estilo, pocas caras:

> stylized chibi game prop: a short curved goblin dagger, crude dark iron blade with a notch, wrapped
> leather grip, small bone pommel, hand-painted texture, single object, no hand, plain background

- **Una sola malla** sirve para las dos manos; en Godot se refleja para la izquierda.
- **Si quieres que no sean iguales,** pide una segunda: *"a short straight goblin stiletto, thin dark
  iron blade, cloth-wrapped grip"*.
- Nombre al instalar: `daga_goblin` (y `estilete_goblin`).

## 4. Animaciones que hacen falta

| Rol | Qué | Notas |
|---|---|---|
| `idle` | de pie, alerta, balanceo ligero | con las manos donde irían las dagas, un poco abiertas |
| `walk` agazapado | andar bajo, rodillas dobladas, torso adelantado | es su forma normal de moverse |
| `run` agazapado | carrera baja y rápida | |
| `attack` doble | dos cortes cruzados, una mano y luego la otra | el juego engancha el golpe al instante del corte |
| `hit` | golpe recibido | |
| `death` | muerte | que acabe tumbado en el suelo, no flotando |
| `empujado` / `levantarse` | | se pueden reutilizar los de los goblins si el esqueleto es Mixamo |

Si lo riggeas con Mixamo (huesos `mixamorig:*`), comparte nombres con `goblin_base` y los goblins
enemigos: los clips de empujado, levantarse y ahogarse que ya hay le sirven.
