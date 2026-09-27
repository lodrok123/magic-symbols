# Dirección de arte

**Fantasía pintada, isométrica 2.5D.** Sketch Town fue un parche mientras
se buscaba la dirección; se sustituye pieza a pieza, sin parar el juego.

La referencia visual es `docs/guia_arte.png`. Este archivo es su
contraparte en números: lo que hay que cumplir para que una pieza entre
sin tocar código. Los colores de aquí están **medidos sobre la guía**, no
elegidos a ojo.

---

## 1. El color de cada elemento

Dos colores por elemento, y la diferencia importa:

- **cuerpo** — lo que identifica al elemento. Va en `RuneData.color`, y de
  ahí salen el tinte del hechizo y el glifo del grimorio.
- **núcleo** — lo que ilumina. Siempre tira a blanco. Va en `Glow`.

Una antorcha con el color del cuerpo pinta la piedra de naranja y se ve a
tinte; con el del núcleo la pinta de cálido, que es lo que hace el fuego.

| elemento | tono | cuerpo (`RuneData.color`) | hex |
|---|---|---|---|
| Fuego | 14° | `Color(0.95, 0.33, 0.12)` | `#F2551E` |
| Agua | 207° | `Color(0.16, 0.62, 0.98)` | `#2A9DFB` |
| Hielo | 194° | `Color(0.37, 0.81, 0.96)` | `#5ECFF5` |
| Tierra | 24° | `Color(0.78, 0.53, 0.35)` | `#C8875A` |
| Viento | 95° | `Color(0.56, 0.83, 0.42)` | `#8FD46A` |
| Rayo | 44° | `Color(0.95, 0.78, 0.24)` | `#F2C63C` |
| Tiempo | 265° | `Color(0.72, 0.58, 0.98)` | `#B894FA` |

**El viento pasó de casi blanco a verde**, y es el único cambio de fondo.
La guía lo llama "Vital (verde)" y tiene razón por un motivo práctico:
sobre el ambiente oscuro, un blanco grisáceo desaparece y además se
confundía con el hielo y con el agua, que son sus dos vecinos de tono.

Luces (`glow.gd`): `LUZ_FUEGO` `Color(1.00, 0.78, 0.42)` ·
`LUZ_RAYO` `Color(0.98, 0.92, 0.55)` · `LUZ_MAGIA` `Color(0.78, 0.70, 1.00)`.

---

## 2. Las paletas de los biomas

Medidas sobre las tiras de color de la guía, en su orden.

| bioma | paleta |
|---|---|
| Bosque | `#57783F` `#84973C` `#C19053` `#60543E` `#272733` |
| Ciudad | `#4E739E` `#DEB690` `#9F7D7A` `#5C5774` `#2E2E4D` |
| Cueva | `#465E86` `#6583B5` `#5F78AB` `#232A44` |
| Pantano | `#346A60` `#8CAF80` `#887F69` `#55434F` `#2B253C` |
| Cueva volcánica | `#141F2B` `#F9851E` `#90403D` `#55202B` |
| Desierto | `#D29850` `#DBA256` `#D59958` `#AC7748` `#7A5537` |

El ambiente de cada uno está en `Glow.AMBIENTE`. No es decoración:
**decide qué elemento importa**. En la cueva volcánica casi no se ve, así
que el fuego deja de ser un arma y pasa a ser la vista; en el desierto
apenas oscurece, así que allí el fuego no da nada que no tuvieras.

---

## 3. El contrato de una hoja de personaje

Lo lee `actor_animator.gd`. Una hoja que cumpla esto entra sin tocar una
línea de código.

- **64×64 px por celda**, rejilla uniforme, **un PNG por clip**.
- **8 filas = 8 direcciones**, y el orden NO es libre:

  ```
  fila 0  E      fila 4  O
  fila 1  SE     fila 5  NO
  fila 2  S      fila 6  N
  fila 3  SO     fila 7  NE
  ```

  Sale de `_row_for()`: `posmod(round(ángulo / 45°), 8)` sobre el ángulo
  **desaplastado** (`y × 2.109`), con 0° = derecha de pantalla. La guía
  las lista empezando por S; si la hoja llega en ese orden, el mago anda
  mirando hacia donde no es.

- **Columnas por clip.** Cualquier número vale —se declara en
  `ActorAnimator.hero()`— pero hay que decidirlo antes de dibujar:

  | clip | ahora | la guía propone | cómo avanza |
  |---|---|---|---|
  | `walk` | 8 | 8 | por **distancia** recorrida |
  | `idle` | 4 | 4 | por reloj, 4 fps, en bucle |
  | `cast` | 6 | 6 (Lanzamiento) | por reloj, 14 fps, una vez |
  | `hurt` | 3 | 4 (Hit) | por reloj, 12 fps, una vez |
  | `death` | 6 | 6 | por reloj, 8 fps, se queda en el último |

  `walk` va por distancia y no por reloj a propósito: así el ciclo se
  ajusta solo si cambia la velocidad, y **la pisada suena siempre en el
  fotograma en que el pie toca** (columna 0 y columna mitad).

- **Los pies en y=52** de la celda, y nada por encima de y=4. Hay una
  comprobación programática que ya cazó un sombrero saliéndose del sitio.

Clips de la guía que el animador todavía no tiene: `correr`, `sacar
grimorio`, `abrir libro`, `dibujar`. Añadir uno es **una línea** en
`ActorAnimator.hero()`.

---

## 4. La protagonista

**Referencia canónica: `docs/referencia_personaje.png`** — la elfa de
**dos trenzas**, capa azul con ribete dorado y el zurrón al cinto.

Hubo tres tandas antes de fijarla. Se descartó la del **pelo suelto** por
un motivo de producción, no de gusto: el pelo suelto pide su propia
animación —mechones que se mueven con un desfase respecto al cuerpo— y
eso multiplica el trabajo en los cinco clips y en las ocho direcciones.
Las trenzas se mueven como un sólido. Es el tipo de decisión que sale
barata ahora y carísima dentro de doscientos dibujos.

La regla que evita que vuelva a pasar: **pasar la imagen de referencia
como entrada en cada generación**, no solo el texto. Un prompt describe;
una imagen ancla. Si cada tanda trae una chica parecida pero distinta, el
problema no se arregla solo — se acumula, y se descubre tarde, cuando ya
hay cien dibujos hechos.

### Las ocho direcciones: cinco dibujos, no ocho

`E/O`, `SE/SO` y `NE/NO` son parejas simétricas. Con **cinco** vistas
(`S, SE, E, NE, N`) se tienen las ocho, espejando las otras tres.

No es solo ahorrar el 40% del trabajo: **garantiza** que la pareja sea
coherente, y ahí es justo donde falla la generación por IA. Está medido
sobre la primera hoja de direcciones que llegó — el giro `S→SE→E→NE→N`
era correcto (la N era la espalda de verdad), pero las otras tres no
cerraban el círculo:

```
E  vs O    directo 42.9   espejado 53.3   ✗
SE vs SO   directo 37.5   espejado 48.4   ✗
NE vs NO   directo 43.1   espejado 56.3   ✗
```

Espejar las hacía *menos* parecidas, o sea que eran variaciones del mismo
lado. En el juego, andar al este y al oeste se habría visto igual.

Lo que se paga al espejar: los detalles asimétricos —la bolsa del
grimorio, la trenza— cambian de lado al girar. A 78 px se nota poco, y es
lo que hacen casi todos los juegos clásicos.

### Qué falta

- El PNG limpio de la hoja de direcciones (2048×1024) **con
  transparencia**. Lo que llegó era la lámina de documentación
  (1983×793) y sus cuadros traen el fondo pegado: gris moteado con
  manchas rojas y amarillas, el **16% de cada celda**.
- **El andar con trenzas.** Hubo uno de 7 fotogramas × 8 direcciones y
  funcionaba, pero era de la maga de pelo suelto. Está descartado: si se
  dejara puesto, a la maga le cambiaría el peinado al echar a andar, y
  eso se lee como un fallo, mientras que no animar se lee como algo por
  terminar.
- **`cast`, `hurt` y `death`.** Ahora son el fotograma neutro del idle.
  No animan, pero conservan las ocho direcciones, que es lo que de verdad
  se nota — que siga mirando bien mientras lanza.

### Lo que sí está

`idle`: 6 fotogramas × 8 direcciones (5 dibujadas + 3 espejadas), 96 px
de celda, figura de 78, pies en y=86. Medido: respira de verdad (8 px de
recorrido, tres cambios de sentido) y el bucle cierra con 4 px de salto.

---

## 5. Por dónde seguir

Lo más difícil del proyecto entero no es el sistema de runas: son
**8 direcciones × 10 animaciones manteniendo el modelo**. Son más de 500
dibujos que tienen que parecer la misma persona, y es justo donde la
generación por IA se rompe — cada tirada da una chica *parecida*, no la
misma.

Ese paso ya se dio y enseñó justo lo que tenía que enseñar (ver arriba).
El siguiente, en orden:

1. **Las cinco vistas limpias**, con fondo transparente. Las otras tres
   salen espejadas.
2. **`idle` completo**: 4 fotogramas × 5 vistas. Y que se muevan de
   verdad — en la primera tanda la cabeza no subía **ni un píxel** entre
   los ocho cuadros y el área variaba un 2%. Eso no es respiración, es
   ruido de render: en secuencia no se ve respirar, se ve *hervir*.
3. **`walk`**: 8 × 5. Es el que más se mira.
4. **`cast`**. El resto puede esperar a que haya niveles que lo pidan.

---

## 6. El contrato de una losa

Las losas tienen una restricción que el personaje no tiene, y si no se
respeta **no hay nada que ajustar después**: la rejilla isométrica se
apoya en que todas compartan exactamente el mismo rombo. Una losa 4 px
más alta abre una junta visible en todo el mapa.

La plantilla está en `docs/plantilla_losa.png`. Pásala como referencia de
forma al generar, igual que la referencia del personaje.

- Lienzo **256 × 352 px**, fondo transparente.
- **Cara superior**: rombo de **232 × 110**, centrado horizontalmente,
  con su **centro en y = 182**. Esa cruz blanca de la plantilla es el
  punto que el juego coloca en la casilla: todo se alinea respecto a él.
- **Laterales**: **111 px** de alto por debajo del rombo, hasta y ≈ 348.
- A escala 0.5 eso da el rombo de 116 × 55 y el `LEVEL = 55.5` que usa
  `IsoGrid`. Los números no son elegibles: salen del propio pack
  (`<grid orientation="isometric" width="232" height="110"/>`) y están
  metidos en la aritmética del mapa.

Comprobado contra las losas actuales: el cubo real tiene el centro de su
cara superior en (127, 183) y la plantilla lo pone en (128, 182).

### Dos cosas que arruinan una losa aunque cumpla la geometría

- **Luz direccional marcada.** Una losa se repite sesenta veces en
  pantalla. Si trae una sombra proyectada hacia un lado, al enlosar se ve
  la repetición antes que el dibujo. Luz plana y suave; el volumen lo
  dan las tres caras, no las sombras.
- **Detalle que no se pueda repetir.** Una grieta muy característica, una
  flor, una mancha: a la tercera copia el ojo la caza. Eso va en adornos
  sueltos (`prop_*`), que se plantan uno cada varias casillas.

---

## 7. Carpetas

La guía propone una estructura por categoría, y es buena. Se adopta
**según vaya llegando arte**, no de golpe: `art/` sigue en pie con lo de
Sketch Town hasta que cada pieza tenga sustituto. Mover 60 archivos hoy
solo rompería las rutas de todo lo que ya funciona.

```
characters/protagonista/rita_maga/   sprites + atlas
environments/<bioma>/                losas, bloques, props
vfx/<elemento>/                      proyectil, area, impacto
ui/                                  grimorio, iconos, retratos
```

---

## 8. La taxonomía de VFX

La guía separa **Proyectil / Área / Impacto** por elemento, y es mejor
estructura que la de ahora (una hoja por elemento y punto).

Lo bueno es que el código ya distingue los dos primeros sin saberlo:
`SpellRecipe` decide `travels`, y de ahí sale si el hechizo viaja o se
queda. Lo que **no existe** es el impacto — hoy un hechizo desaparece sin
más. Añadirlo daría más sensación que cambiar de estilo.

Encaja en `RuneData` igual que las intensidades del fuego: dos campos más
por elemento, opcionales, y quien no los rellene sigue funcionando.
