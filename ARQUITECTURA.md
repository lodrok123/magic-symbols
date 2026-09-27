# Magic Symbols — Notas de arquitectura

Prototipo de aprendizaje en Godot 4. Idea central: dibujar símbolos con el
ratón para lanzar hechizos, combinando un **elemento** (siete) con
**sellos** que dicen qué forma toma y hacia dónde va. Inspiración: Magicka
(combinar elementos), Witch Hat Atelier (el trazo del símbolo importa),
Breath of the Wild (reacciones físicas entre elementos).

> **La idea que sostiene todo el proyecto: el comportamiento son datos, no
> código.** Un elemento es un `.tres`. Un gesto es una plantilla grabada.
> Una reacción es una etiqueta. Una combinación de sellos no está escrita
> en ninguna parte: emerge de leer juntos unos pocos parámetros.

---

## Estado: dos ramas

| rama | qué es |
|---|---|
| `main` | el juego en **vista cenital**, el que funcionaba antes de la prueba |
| `prueba-isometrico` | **vista isométrica** con arte de Sketch Town. Todo lo nuevo está aquí |

La rama isométrica se abrió para responder una pregunta —*¿merece la pena
el cambio?*— antes de pagar el coste de migrar. La respuesta fue que sí,
pero `main` sigue intacto hasta que se consolide.

En la rama isométrica, **`node_2d.tscn` (el nivel viejo) se ve mal a
propósito**: sus bloques siguen colocados en la rejilla antigua y ahora
llevan cubos isométricos encima. El nivel bueno es `IsoTest.tscn`, que es
además la escena principal.

---

## Cómo se juega ahora mismo

**Movimiento**: `WASD`. `Shift` salta (impulso corto que ignora
colisiones). `R` reinicia el nivel en cualquier momento, incluso con el
juego pausado por victoria o muerte.

**Lanzar hechizos** — con el grimorio:

1. `T` abre el libro. **El tiempo se detiene** mientras esté abierto.
2. Dibujas en el **núcleo** para elegir el **elemento**.
3. Dibujas en un **sector** (uno de los 8) para añadir un **sello** con su
   propia dirección. Puedes poner varios sellos en el mismo sector: se
   **combinan**.
4. `T` cierra el libro **y lanza** todos los componentes a la vez.

Cuatro flechas en cuatro sectores son cuatro proyectiles en cuatro
direcciones. Pero lo interesante empezó cuando dejó de ser solo eso (ver
*El lenguaje de sellos*).

### Sectores

La corona entre el núcleo y el borde está repartida en **8 sectores**. El
sector de un gesto se calcula desde el **centro** de sus puntos, no desde
donde empieza: el centro es lo único que no cambia si lo dibujas de ida o
de vuelta.

**Lo que decide el significado es DÓNDE dibujas, no qué forma tiene.**
Núcleo = elemento; sector = sello. Antes lo decidía la forma (cerrada =
elemento, recta = patrón), y eso dejaba fuera cualquier gesto abierto: un
semicírculo no se cierra, así que jamás habría podido ser un elemento.
Mirar la posición liberó el vocabulario por completo.

**Atajo que sobrevive**: un trazo recto suelto en un sector sigue valiendo
como el sello equivalente, según su sentido respecto al centro — hacia
fuera flecha, hacia dentro pilar, de lado barrera. El trazo es azúcar; el
sello es el lenguaje, y solo el sello se puede combinar.

---

## Vocabulario

La hoja de referencia dibujada está en **`docs/runas.png`**.

### Elementos — se dibujan en el NÚCLEO

| Gesto | Elemento | Etiquetas | Daño |
|---|---|---|---|
| triángulo abierto abajo `∧` | Fuego | `fuego`, `calor` | 40 |
| onda `~` | Agua | `agua` | 40 |
| rombo `◇` | Tierra | `tierra` | 0 |
| zigzag | Rayo | `rayo`, `electrico` | 55 |
| copo de 3 trazos | Hielo | `hielo`, `frio` | 20 |
| `X` | Tiempo | `tiempo`, `disipar` | 0 |
| 3 líneas horizontales | Viento | `viento` | 0 |

Existe un octavo elemento que el jugador **no puede dibujar**: el
**vapor**. Solo lo genera el mundo al evaporarse el agua. Es el primer
caso de un elemento que existe únicamente como consecuencia.

> **El agua perdió la etiqueta `frio`.** La llevaba de paso desde el
> principio, y al aparecer el hielo como elemento propio había que
> repartir: el agua moja, el hielo congela. Esto **cambió una solución de
> nivel** — el puente ya no se cruza congelando con agua, hay que usar
> hielo.

### Sellos — se dibujan en un SECTOR

| Gesto | Sello | Aporta |
|---|---|---|
| `→` | flecha | `travels`, `reach +1` |
| `⊥` | pilar | `origin = 128` (dos casillas) |
| círculo cerrado | barrera | `spread` (ocupa área) |
| `↑` | levitación | `lifetime +2s`, `height +1` |
| dos triángulos | repetición | `copies ×2` |
| `<` | rombo | `power ×2` |

Los dos lados **nunca compiten al reconocer**: un gesto del núcleo solo se
compara contra elementos, y uno de sector solo contra sellos. Esa
separación es lo que permite que la barrera sea un círculo aunque haya
elementos redondeados, y la razón de que el vocabulario pueda crecer sin
que cada gesto nuevo degrade a todos los anteriores.

---

## El lenguaje de sellos: `sigils.gd` + `spell_recipe.gd`

Esta es la pieza de la que más se aprende del proyecto.

Seis sellos son quince parejas, veinte tríos y quince cuartetos. Escribir
a mano qué hace cada combinación mata el sistema: cada sello nuevo
obligaría a decidir qué pasa con todos los anteriores.

**Por eso no hay ni una combinación escrita.** Cada sello declara solo lo
suyo en una tabla (`sigils.gd`), lo vuelca en una receta común
(`spell_recipe.gd`), y es la receta terminada la que se interpreta al
final.

### Cómo se acumula cada parámetro

No es arbitrario: dice qué significa apilar ese sello.

| parámetro | acumula | significado |
|---|---|---|
| `travels`, `spread` | se encienden | o viaja o no |
| `origin` | el mayor manda | el más lejano gana |
| `reach`, `lifetime`, `height` | **se suman** | más flechas, más lejos; más levitaciones, más rato |
| `copies`, `power` | **se multiplican** | dos repeticiones son cuatro |

### Lo que emerge

Ninguna de estas líneas existe en el código:

| sellos | resultado |
|---|---|
| flecha | proyectil |
| pilar | aparece a dos casillas, quieto |
| barrera | corro que te rodea |
| **pilar + flecha** | muro **a lo largo** del camino |
| **barrera + flecha** | muro **de través** que barre de frente |
| **barrera + levitación** | columna (corro × altura) |
| **levitación** (+ aire) | tornado quieto que permanece |
| **levitación + flecha** | tornado que se desplaza |
| **levitación + flecha ×2** | chorro que ocupa dos casillas y permanece |
| **repetición + cualquiera** | abanico de copias |

Dos reglas que salieron solas y merece la pena señalar:

**Qué área ocupa `barrera` depende de si además viaja.** Quieta, el corro
rodea. Viajando, se pone de través y barre — porque un corro alrededor de
algo que avanza no significaría nada. Una lectura, dos resultados.

**Lo que permanece, atraviesa.** `piercing = lifetime > 0`. Un tornado no
se deshace contra el primer arbusto: lo arrastra y sigue. No hizo falta
una regla nueva, solo leer un parámetro que ya estaba.

### Tope de manifestaciones

`MAX_MANIFESTATIONS = 24` por componente. Los parámetros se multiplican
entre sí: un corro de 6 × 3 alturas × 4 copias son **72 hechizos de un
solo trazo**. Sin tope, la combinación más creativa sería también la que
tira los fotogramas, y eso enseña justo lo contrario de lo que queremos.

El tope se aplica al final, en `build()`, y no dentro de cada paso: así
ninguna regla necesita saber cuántas manifestaciones llevan las demás.

### Nota sobre `pilar`

Ya no hace pilares —los hace `barrera + levitación`—, pero **no sobra**:
dice *dónde* (aparece lejos) mientras que barrera dice *cuánto espacio*.
Son ejes distintos, y por eso `pilar + flecha` y `barrera + flecha` dan
dos armas diferentes. Lo que sobra es el nombre; renombrarlo a `alcance`
está pendiente.

---

## Reconocimiento de gestos

### `gesture_recognizer.gd` — el reconocedor **$P**

Algoritmo **$P (Point-Cloud Recognizer)** de Vatavu, Anthony y Wobbrock
(ICMI 2012), portado a GDScript. Licencia **New BSD**.
Original: https://depts.washington.edu/acelab/proj/dollar/

**Por qué $P y no $1.** El $1 es *unistroke*: un gesto, un trazo. En
cuanto un sello necesita varios —el copo son tres líneas, el viento tres
rayas— deja de servir. El $P trata el gesto como una **nube de puntos sin
orden**: da igual cuántos trazos lo formen, en qué orden los dibujes y en
qué sentido vaya cada uno.

**Parámetros elegidos midiendo, no a ojo:**

- **`NUM_POINTS = 16`**. Con 270 gestos deformados, 16 puntos aciertan el
  95,9% y 32 el 97,0% — pero 32 tarda **seis veces más** (105 ms frente a
  17 ms), y el coste crece con cada plantilla grabada. Un punto de acierto
  no lo compensa.

- **Rechazo por MARGEN, no por parecido.** Lo natural sería descartar por
  debajo de cierto parecido. Con el $P **no funciona, y está medido**: los
  aciertos puntúan 0,91 de media, los fallos 0,87 y un garabato aleatorio
  0,83. Los tres rangos se solapan casi del todo. Lo que sí separa es
  cuánto le saca el primero al segundo: en los aciertos el segundo es un
  103% peor; en fallos y garabatos, un 10–12%. `MIN_MARGIN = 0.30`.

> ⚠️ **Con UN SOLO gesto grabado no se puede reconocer nada.** Antes aquí
> se aceptaba sin más —"es el único candidato posible"— y fue un error
> serio: al renombrar los elementos quedó una única plantilla y el juego
> empezó a leer **cualquier** trazo como esa runa, en silencio. Sin
> segundo candidato no hay margen, y sin margen no hay medida. Ahora
> rechaza y dice por consola qué elementos faltan por grabar.

### `gesture_library.gd` / `.tres` — los gestos como dato

Un gesto es un **dato**, no una heurística. Añadir una forma es dibujarla,
no escribir una función que la detecte.

Cada gesto guarda **varias muestras** (4-5): el mismo trazo sale distinto
rápido que despacio, grande que pequeño.

**Modo de grabación**: dentro del libro, `G` lo activa; `1..9` eligen
gesto y **`← →` recorren la lista entera** — hacen falta porque hay 13
grabables y solo 9 teclas. `Retroceso` borra la última muestra, `Supr` dos
veces borra todas las de ese gesto.

Vive dentro del propio libro a propósito: las plantillas se graban **en
las mismas condiciones** en que luego se dibujan. Una herramienta aparte
grabaría gestos que no se parecen a los de la partida real.

> El panel de grabación va **pegado a la esquina superior izquierda**, y
> es una corrección: colgado bajo el anillo (radio 250, centrado en una
> ventana de 648 de alto) las dos últimas líneas caían en y=650 y y=672,
> **fuera de la pantalla**. Con ellas desaparecían la fila de sellos y el
> aviso de las flechas. Las esquinas no dependen de lo alta que sea la
> ventana.

### Cómo se eligieron las formas

Todo el set está medido con un banco de pruebas que deforma cada gesto
(tamaño, proporción, giro, temblor y densidad de puntos = velocidad):

| | suave | temblor 0,05 · giro 22° |
|---|---|---|
| set inicial (fuego = `P`) | 100% | 69,3% |
| **set actual** (fuego = `∧`) | 100% | **75,0%** |

El cambio clave fue sacar la `P`: `P` ↔ `agua` producía 7 de cada 11
fallos porque son dos trazos con el mismo recorrido general (suben, hacen
panza y vuelven).

**La barrera pasó a círculo** por la misma vía: dos arcos concéntricos
fallaban 38 de 40 con temblor medio; el círculo cerrado falla **1 de 40**.
Y solo es posible porque el agua ya no es un círculo — la regla de separar
las formas conflictivas entre familias es literalmente lo que lo permite.

**Levitación `↑` mide 99,6%** y cero confusiones con `pilar ⊥`, que era la
duda porque ambos son un palo vertical. No se parecen porque el $P **no
normaliza el giro**: uno lleva la barra abajo, el otro la punta arriba.

> **Casi todos los fallos son RECHAZOS, no confusiones.** El sistema dice
> "no te he entendido" en vez de lanzar el hechizo equivocado. En un juego
> de magia eso es exactamente lo que quieres: fallar es gratis,
> equivocarse de elemento no.

---

## Las piezas del sistema

### `runes.gd` — el vocabulario de tipos

Un único `enum Runes.Type`, en su propio script para que cualquiera pueda
usarlo sin depender del nodo del jugador.

> ⚠️ **Los enum no se reordenan.** Los `.tres` y las escenas guardan el
> **número**, no el nombre. Cuando `GrassBlock.State` pasó de 3 a 5
> estados, el `initial_state = 2` del `GrassWall` dejó de significar
> `GROWN` y pasó a `IGNITING`. Por eso `ELEMENT_LIGHTNING`, `ELEMENT_ICE`
> y `ELEMENT_TIME` van **al final**, y los viejos `SHAPE_*` conservan su
> nombre aunque ya no describa nada.

### `rune_data.gd` + `.tres` — las propiedades de cada elemento

Un elemento es un `Resource` con `color`, `damage`, `tags`, `vfx_sheet`.
Añadir una propiedad es un `@export var` y rellenarlo — sin tocar lógica.

Las **`tags`** son la pieza más importante del diseño. Los objetos del
mundo no preguntan "¿eres fuego?", preguntan "¿traes `calor`?". El día que
haya tres runas de fuego, todas derretirán hielo sin tocar el hielo.

### `spell.gd` + `spell_factory.gd` — el contrato `on_spell_hit`

El hechizo lleva su `RuneData` completo. Al tocar cualquier `Area2D` no
sabe qué ha tocado: comprueba si tiene `on_spell_hit()` y se lo pasa.

**Este es el patrón clave del proyecto.** Combate y puzzles usan el mismo
mecanismo, y `Spell` nunca tiene una lista de "cosas que existen".

Tres tipos de hechizo, decididos por sus parámetros:

- **Con dirección** → vuela y muere al primer impacto.
- **Sin dirección** → se queda quieto `stationary_lifetime` y puede
  afectar a varias cosas. Así son el pilar, la barrera y el vapor: **el
  vapor no es una escena nueva, es un hechizo quieto con otra ficha**.
- **Con `piercing`** → vuela y **no** muere al chocar. Lo pone la receta
  cuando hay permanencia.

Un hechizo quieto que nace ya solapado con un bloque no recibiría nunca
`area_entered`, así que al nacer espera un ciclo de física
(`await get_tree().physics_frame`) y mira a mano.

> ⚠️ **`spell_factory.gd` existe porque el ORDEN importa.** `add_child()`
> ejecuta `_ready()` al instante, así que todo lo que `_ready` necesite
> leer (`direction`, `stationary_lifetime`) debe asignarse **antes** de
> meter el nodo en el árbol, y lo que necesite estar en escena
> (`global_position`) **después**. Esto ya causó un bug real: los hechizos
> se creaban invisibles porque la dirección se ponía un instante tarde y
> todos se creían quietos.

**El viento arrastra lo que toca.** Un hechizo de viento que cruza fuego
deja de ser viento y pasa a ser viento *cargado* de fuego: su color, su
daño y sus etiquetas. Sigue volando, pero ahora prende lo que encuentra
más allá.

No es un caso especial viento-contra-fuego. El viento pregunta *"¿llevas
algo que se pueda arrastrar?"* (`carried_element()`) y el bloque responde.
Un bloque futuro que devuelva veneno hará viento venenoso sin que ni el
viento ni el veneno se enteren el uno del otro. **Solo se carga una vez**,
o al cruzar una hoguera larga iría cambiando casilla a casilla.

---

## El mundo: objetos que reaccionan

### `neutral_block.gd` — el suelo de los niveles

Si todos los bloques reaccionan, el jugador no distingue decorado de
puzzle. Este es la base mayoritariamente inerte: nunca bloquea el paso,
sus reacciones son de superficie.

| Estado | agua | frío | calor | rayo | disipar |
|---|---|---|---|---|---|
| DRY | → WET | → ICY | — | — | — |
| WET | → ICY | → ICY | → DRY **+ vapor** | **conduce** | → DRY |
| ICY | — | — | → WET | — | → DRY |

El hielo **hiela de golpe**; el agua pide dos impactos. Uno es la ruta
larga y barata, el otro la corta.

En `ICY` es **resbaladizo**, no sólido: el bloque no empuja al jugador,
solo le avisa (`add_ice_contact()`) y es el jugador quien decide qué
significa. Cuenta contactos en vez de un `bool` porque puede tocar dos
bloques helados a la vez.

> Detalle sutil: avisar de "sales del hielo" se mira en la **transición**
> (`ICY → otro`), no en el estado nuevo. Si no, un bloque que pasa de seco
> a mojado restaría un contacto que nunca sumó.

### `water_block.gd`

`frio` congela (pasable), `calor` derrite, y **agua + fuego = vapor** esté
helada o líquida.

**`rayo` la electrifica**: hiere a quien esté encima y **pasa la corriente
a las charcas vecinas** (grupo `water_blocks`, radio 80). El hielo **no**
conduce: es superficie, no balsa — lo que da la jugada inversa, congelar
para cruzar seguro.

> ⚠️ **El pestillo `is_electrified` no es opcional.** La descarga nace
> encima de la propia charca, así que en cuanto corre un ciclo de física
> se golpea a sí misma y suelta otra, y otra. Es un bucle infinito que
> cuelga el juego al primer rayo. Mismo pestillo en el charco neutro.

`disipar` derrite el hielo y desmorona lo construido encima.

### `earth_block.gd` — lo que el jugador construye

Sólido y **trepable**. Se crea sobre suelo neutro o sobre agua, no en el
aire: da una regla clara y limita el spam de forma natural.

Solo construye con hechizos **quietos**. No hizo falta un dato nuevo: una
flecha llega con dirección y un pilar llega con dirección cero.

Dónde se puede construir lo decide **quien recibe el hechizo**, no la
tierra: `NeutralBlock` y `WaterBlock` llaman a `EarthBuilder.build_on()` y
cada uno guarda su `occupant` para no apilar dos cosas en la misma
casilla.

**Tope: 20 bloques**, política **FIFO** — desaparece el más antiguo, nunca
el recién creado, así el jugador nunca siente que su última acción no hizo
nada. **`disipar` los desmorona**, y eso importa más de lo que parece: con
un tope, disipar es cómo *recuperas presupuesto*. Rectificar pasa a ser
una jugada.

**Tierra + agua = vegetación**: el bloque se sustituye a sí mismo por un
`GrassBlock` en vez de añadirse un estado "con hierba" y duplicar toda la
lógica de incendios.

### `grass_block.gd` — simulación de incendio

```
THIN ──agua──> GROWN          (hierba baja / tupida y sólida)
  │              │
  └──fuego───────┴──> IGNITING ──1s──> BURNING ──5s──> ASHES
                          │               │              │
                          └───agua────────┴──agua────────┘
```

- **IGNITING** (1s): ha prendido pero aún no quema. Ventana de reacción.
- **BURNING** (5s): hace daño y **contagia** en radio 110 cada 1,2s.
- **ASHES**: inerte. Regándolo rebrota.

**`rayo` salta la fase de prender**: cae y arde. Es la vía rápida y cara
frente al fuego, que aún puedes apagar mientras prende.

**`disipar` apaga, pero no riega**: devuelve a THIN sin hacerla crecer ni
resucitarla de la ceniza. El tiempo deshace magia, no obra milagros.

El fuego **se apaga solo**: un incendio no dura para siempre, lo que
convierte el tiempo en un recurso del puzzle.

**Viento sobre llamas** lanza una lengua de fuego hacia delante y **salta
directamente** a la vegetación a favor de viento, hasta 230px y solo en un
cono (producto escalar > 0,3).

### `enemy.gd`

Patrulla entre dos puntos y hace `damage_per_second` por contacto. Tiene
además un **golpe frontal**: si te quedas plantado delante más de 0,5s,
recibes 20 de daño con 1,5s de recarga. La espera es lo que lo hace justo
— convierte "estar delante" en una decisión y no en un accidente.

La zona de golpe se consulta por solapamiento en vez de por señales,
porque **el área se mueve cada fotograma**: con señales habría que confiar
en que entran y salen en el orden correcto al girar.

Para decidir si un hechizo le duele no lista elementos a ignorar, mira el
dato que importa: `rune_data.damage <= 0`.

---

## Vista isométrica

### `iso_grid.gd` — la conversión

Toda la vista isométrica se reduce a una función y su inversa; el resto
del juego sigue pensando en **casillas**, que es como se piensan los
puzles.

La geometría **no es inventada**: viene del propio pack, que declara
`<grid orientation="isometric" width="232" height="110"/>`. A media
escala: rombo **116×55**, paso **(58, 27.5)**, altura de nivel **55,5**.

> Medir el sprite a ojo habría salido mal: en estas piezas la hierba
> **desborda** el borde del cubo, así que la parte verde mide 154 px de
> alto pero el rombo real son 110. Fiarse del recorte habría descuadrado
> el mapa 44 px por casilla.

### Las tres trampas del isométrico

**1. `y_sort` no es opcional.** Sin ordenar por profundidad, el orden de
dibujado es el orden del árbol y un bloque del fondo puede taparle la cara
a uno de delante.

**2. Apilar rompe el `y_sort` ingenuo.** Un bloque subido 55 px tiene
*menos* Y, así que Godot lo dibuja **detrás** de la losa sobre la que se
apoya — invisible. La solución es contraintuitiva: **el nodo se queda a
ras de suelo** y la altura se le da solo al sprite. Así la profundidad que
ve `y_sort` es la de su casilla.

> Y el desempate dentro de la misma casilla **no** se hace con `z_index`:
> `z_index` manda *sobre* `y_sort`, así que el cubo elevado se pintaría
> por encima de todo, incluidos los bloques que tiene delante. Se hace con
> una décima de píxel de empujón, que no mueve nada visible.

**3. Todo se ordena por donde toca el suelo.** Los bloques llevan su
origen en el centro de la cara superior, pero un personaje lo lleva en
mitad del cuerpo. Sin corregirlo, el jugador se ordena como si estuviera
media figura más al fondo de donde pisa.

**Las colisiones son rombos, no rectángulos.** Dos casillas en diagonal
comparten solo una esquina; con rectángulos se solapan y el jugador se
engancha en bordes que visualmente no existen.

> **Pendiente conocido**: las colisiones isométricas siguen siendo poco
> realistas —el rombo es una aproximación y los cubos elevados no tienen
> volumen de colisión de verdad—. Se afinará con niveles reales delante,
> no antes: hacerlo ahora sería ajustar contra un mapa de prueba
> desechable.

---

## Animación

El contrato completo está en **`docs/ANIMACION.md`**. Lo esencial:

- Celdas de **64×64**, **8 filas** en orden `E SE S SO O NO N NE`, pies en
  **y = 52**.
- Cinco clips: `walk` (8), `idle` (4), `cast` (6), `hurt` (3),
  `death` (6).
- **`ActorAnimator` no sabe nada del mago**: sabe leer hojas con esa
  forma. Cambiar de personaje es cambiar los PNG.
- Valida las hojas al arrancar y avisa si alguna no cuadra.

**La decisión que sostiene el resto: andar avanza con la DISTANCIA
recorrida, no con el tiempo.** Si fuera por tiempo, los pies patinarían en
cuanto cambiase la velocidad. Consecuencia práctica: `stride` describe la
anatomía del personaje, no su prisa — para que vaya más lento se toca
`velocidad` en `player.gd` y el ciclo se ajusta solo. Tocar las dos cosas
lo frena dos veces.

Andar y respirar se **observan** (mirando si el padre cambió de posición);
el golpe y la muerte también, escuchando la señal `health_changed` que el
jugador ya emitía para la barra de vida. Solo `cast` hay que avisarlo: "he
empezado a lanzar" no se deduce de una posición.

---

## Partículas — `block_fx.gd`

En isométrico el volumen es un engaño: son dibujos planos colocados en
rombo. **Lo que sostiene el engaño no es el dibujo, es que las cosas
ocurran en el sitio correcto** — que el humo salga de la cara de arriba
del cubo y suba. El cerebro da por buena la profundidad en cuanto ve algo
comportarse con ella.

Por eso los emisores nacen en la **cara superior** y se reparten en un
óvalo ancho y bajo: emitir desde un punto delata que debajo no hay
volumen.

Conectado a: llamas y humo mientras la hierba arde, chispazo al prender,
ceniza al consumirse, escombros al desmoronarse un bloque de tierra,
chispas al electrificarse el agua, destello al disipar.

> Los estallidos **cuelgan de la escena, no del bloque**. La mitad ocurren
> porque el bloque *desaparece*, y un hijo se va con su padre: colgados
> del bloque no se vería ninguno de los que más importan.

Los emisores continuos se crean la primera vez y luego solo se encienden y
apagan — montar un material de partículas en cada cambio de estado daría
tirones.

---

## Bloqueo físico vs. detección de hechizos

Un objeto interactivo necesita **dos colisiones** en el mismo nodo:

- Un `Area2D` (raíz) — detecta el `Spell`. No bloquea.
- Un `StaticBody2D` hijo (`SolidBody`) — este sí bloquea al `Player`. Se
  activa con `set_deferred("disabled", ...)`.

`set_deferred` en vez de asignar directamente: cambiar una forma de
colisión en mitad del paso de física puede ser inestable.

---

## Interfaz y estados de partida

- **`health_bar.gd`**: encuentra al jugador por el grupo `"player"` y se
  suscribe a `health_changed`. El jugador no sabe que existe una barra.
- **Victoria** y **muerte** buscan su cartel por grupo (`"victory_ui"` /
  `"gameover_ui"`), lo hacen visible y pausan el árbol.
- **`level_controller.gd`**: nodo aparte con `process_mode = ALWAYS` para
  leer `R` estando en pausa. No se puede poner ALWAYS en la raíz porque
  los hijos lo heredan y entonces nada se pausaría.
- El grimorio también es `ALWAYS`: sin eso se congelaría con su propia
  pausa y no podrías ni cerrarlo.
- `receive_damage()` tiene guarda `is_dead`: sin ella los temporizadores
  de daño en marcha seguirían llamando a `_die()` en bucle.

---

## Arte

### Terreno: **Kenney Sketch Town** (CC0)

Cubos isométricos de material, que mapean 1:1 con los bloques que el juego
ya tenía. No es casualidad que encaje: el pack son cubos de material y el
juego ya estaba modelado como bloques de material.

| archivo | pieza | bloque |
|---|---|---|
| `art/floor.png` | `dirt_low` | NeutralBlock (losa baja: se pisa) |
| `art/earth.png` | `dirt_center` | EarthBlock (cubo entero: da altura) |
| `art/grass.png` | `grass_center` | GrassBlock fina |
| `art/grass_grown.png` | `grass_center` + `tree_single` | GrassBlock tupida |
| `art/water.png` | `water_center` | WaterBlock |
| `art/goal.png` | `structure_arch` | Meta |

Los compuestos se montan **sobre el mismo lienzo de 256×352**: al no mover
nada, la alineación sale sola y no hay que calcular desplazamientos.

`tools/gen_iso_tiles.py` los extrae del zip. Se guarda en el repo para que
el paso sea **repetible**: si mañana cambia la escala, se toca ahí y se
relanza, en vez de acordarse de que un día alguien recortó unos PNG a
mano.

### La paleta, medida del propio pack

Dos hallazgos que cambiaron el personaje por completo:

1. **No hay contorno negro.** El borde es el mismo color al **57%**.
2. **La cara en sombra solo baja al 89%**, no a la mitad.

Con contorno negro y sombras duras, el mago parecía de otro juego.

### Personaje

De relleno, generado por `tools/gen_actor.py`, y **deliberadamente
sustituible**. Kenney no tiene ni un personaje isométrico: sus 16 packs
isométricos son todos entorno. Un personaje con 8 direcciones y 5
animaciones son 40 dibujos coherentes entre sí, y por eso casi nadie lo
regala.

Las cinco poses salen del **mismo muñeco**: un script por animación
parecía más simple y no lo era — retocar la túnica habría que hacerlo en
cinco sitios y el personaje se desincronizaría consigo mismo.

### Efectos (`art/fx/`)

Fuego, agua, viento y tierra vienen de un pack de VFX muestreado a ~18
fotogramas. Rayo, hielo y tiempo los genera `tools/gen_fx.py`.

> ⚠️ **Los fotogramas van en REJILLA de 6 columnas, no en tira.** Una tira
> de 19 fotogramas de 128px mide 2432px, y muchas tarjetas tienen el tope
> en 2048: el juego arrancaba con un reguero de `Texture dimensions exceed
> device maximum`. **Regla: ninguna textura del proyecto pasa de
> ~1024–1280px de lado.**

**La animación es un dato del elemento**, no del hechizo. `spell.gd` nunca
pregunta "¿eres fuego?", solo "¿traes tira?".

### Packs en bruto: `.gdignore`

`Assets/`, `Spellbook/` y los dos packs de partículas llevan un
`.gdignore`. **Godot importa toda imagen que haya dentro del proyecto, la
use el juego o no**, y `Spellbook/fire/strong/strongFire.png` mide
**35 623 × 635 px** — ninguna tarjeta la acepta. De ahí la cascada de
`Attempting to use an uninitialized RID`.

Efecto secundario bueno: son ~3000 archivos que Godot deja de importar, y
la primera apertura del proyecto se vuelve rápida.

---

## Decisiones de diseño

- **Vista isométrica** (en prueba). Revierte la decisión anterior de
  quedarse en cenital. El motivo no fue estético: el pack son cubos de
  material que mapean 1:1 con los bloques del juego, teselan sin huecos, y
  **la altura por fin se dibuja de verdad** en vez de fingirse. El coste
  aceptado es que el apaño de la elevación sigue ahí.
- **Se descartó la vista lateral tipo Noita** por una razón concreta: en
  lateral el agua tiene que acumularse y caer, lo que obliga a rediseñar
  `water_block.gd` entero y con él la mitad de las reacciones. En
  isométrico el agua sigue siendo una losa.
- **Las reacciones viven en el objeto que reacciona**, nunca en el
  elemento. El fuego no sabe que existe la hierba.
- **Las combinaciones no se escriben, emergen.**
- **El arte generado no es una derrota**: es lo único que da 8 direcciones
  y 5 animaciones coherentes, y retocarlo es barato mientras aún se está
  decidiendo.

---

## Errores que costaron caros

Los que volverían a morder:

| error | señal | causa |
|---|---|---|
| Hechizos invisibles | nada en pantalla | `add_child()` corre `_ready()` al instante; la dirección se ponía después |
| Flechas que se autodestruían | el proyectil no sale | chocaban contra el `Area2D` de los pies del propio lanzador |
| `Texture dimensions exceed device maximum` | cascada de RID nulos | tira de 2432px; y una imagen de 35 623px en un pack sin usar |
| Enum renumerado | un bloque arranca en otro estado | las escenas guardan el número, no el nombre |
| `preload` de un archivo borrado | el juego no arranca | es un error de **compilación**, no de ejecución |
| Todo se reconoce como una runa | sin aviso ninguno | con una sola plantilla no hay margen que medir |
| Texto de interfaz invisible | la ayuda "no existe" | dibujado en y=672 con ventana de 648 |
| Bucle infinito al electrificar | cuelgue | la descarga nace encima de quien la lanza |
| Sombrero recortado | parecía una gorra | el sprite se salía de la celda por arriba |
| Sombra animada en vez del personaje | el mago no anda | "el primer Sprite2D" era la sombra invisible |

---

## Pendiente / próximos pasos naturales

- **Consolidar la rama isométrica** en `main`, o descartarla.
- **Colisiones isométricas de verdad**, con niveles reales delante.
- **Grabar el set completo de gestos** — hoy solo hay `viento` y cuatro
  sellos; el resto están definidos pero sin plantillas.
- **Renombrar `pilar` a `alcance`**, que es lo que hace.
- **Animar al enemigo**: es `_animate(enemigo)` más su propia hoja.
- **Iluminación** (`CanvasModulate` + `PointLight2D`): el fuego que lanzas
  debería iluminar la escena. Sigue siendo lo que más acercaría al
  referente sin un solo asset nuevo.
- **Rueda hidráulica**: primer objeto que reaccione a `vapor`. El gancho
  existe, falta el objeto.
- **Combinaciones sugeridas sin implementar**: `repetición + barrera` →
  corros concéntricos; `rombo + levitación` → que el aumento escale la
  *permanencia* cuando hay algo que permanece.
- Separar el mapa único en escenas de nivel independientes.
- Sonido.
