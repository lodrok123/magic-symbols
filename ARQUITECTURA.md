# Magic Symbols — Notas de arquitectura

Prototipo de aprendizaje en Godot 4. Idea central: dibujar símbolos con el
ratón para lanzar hechizos, combinando un **elemento** con **glifos** que
dicen qué forma toma y hacia dónde va. Inspiración: Magicka (combinar
elementos), Witch Hat Atelier (el trazo del símbolo importa), Breath of the
Wild (reacciones físicas entre elementos).

> **La idea que sostiene todo el proyecto: el comportamiento son datos, no
> código.** Un elemento es un `.tres`. Un gesto es una plantilla grabada.
> Una reacción es una etiqueta. Una combinación de glifos no está escrita
> en ninguna parte: emerge de leer juntos unos pocos parámetros.

> **Vocabulario.** **Sello = elemento** (fuego, agua…; se dibuja en el
> núcleo). **Glifo = forma** (flecha, barrera…; se dibuja en un sector).
> Así hablan el HUD, `progresion.gd` y los niveles. En el código antiguo la
> forma se llama `sigil` (`Sigils`, `Repertoire.sigils`): es lo mismo que
> glifo. Las versiones anteriores de este documento llamaban "sello" a la
> forma; aquí ya no.

Este documento cuenta **lo que el código hace hoy**. Lo que se quiere que
haga está en `docs/DISENO_FUTURO.md`. El reparto de quién toca qué archivo,
en `docs/PROPIETARIOS.md`.

---

## Estado

Una sola rama, `main`, en **3D** desde el 4/10/2026: Godot 4.7, física
**Jolt** (`project.godot`), modelos `.glb` de Meshy y niveles hechos de
piezas `.tscn`. La cámara es **ortogonal, fija a 60°**, y gira en pasos de
90°. El cómo está en *Vista 3D*, *Animación* y *Arte*.

| escena | qué es |
|---|---|
| `escenas/PruebaBosque.tscn` | **escena principal** (`project.godot`): el Bosque |
| `escenas/PruebaBosque01.tscn`, `PruebaJugabilidadBosque*.tscn`, `PruebaNivelBosque.tscn` | variantes del Bosque 01 (nivel horneado en `mundo/datos_nivel/Nivel_Bosque_01.tscn`) |
| `escenas/PruebaTest2.tscn`, `PruebaJugabilidad3D.tscn`, `PruebaNivelPruebas3D.tscn` | el laboratorio de elementos, el mapa de jugabilidad y el de una pieza de cada |
| `escenas/PruebaTitan.tscn`, `PruebaTerraFina.tscn` | pruebas de escala y de terreno |
| `laboratorios/*.tscn` | laboratorios: agua, fuego, hechizos, recetas, VFX, humanoides, catálogo de assets… |

Todas las `Prueba*` son la misma maqueta (`presentacion/prueba_test2.gd`,
clase `PruebaTest2`) con otro nivel.

> **Ojo al leer el resto.** Las secciones *Vista 3D*, *Animación* y *Arte*
> están al día (21/10). Las de lógica —*Las piezas del sistema* (salvo
> `runes.gd`, `rune_data.gd`, `sigils.gd`, `spell_recipe.gd` y el
> reconocedor, que siguen), *El mundo*, *Niveles y herencia*, *Test 2*,
> *Partículas*, *Bloqueo físico* e *Interfaz*— todavía cuentan los scripts
> de la era 2D (`spell.gd`, `neutral_block.gd`, `enemy.gd`, `nivel_base.gd`,
> `block_fx.gd`, `Area2D`…), que **ya no están en el repo**. Las ideas
> (reacciones por etiqueta, el contrato `on_spell_hit`, la receta que
> emerge) siguen; los nombres de archivo y las medidas en píxeles, no. Su
> equivalente 3D vive en `magia/` (`lanzador_3d.gd`, `hechizo_vivo.gd`),
> `nucleo/hechizo.gd`, `mundo/` (`terreno_3d.gd`, `mundo_3d.gd`),
> `objetos/` y `enemigos/`. Reescribirlas es tarea aparte.
>
> **Historia: era 2D (hasta el 4/10).** Hasta entonces el juego era
> isométrico 2D en una sola rama: `Mundo.tscn` (40×34) como escena
> principal, `TestJugabilidad.tscn` (23×23), `Test2.tscn` (40×40) y los
> laboratorios `VfxLab*`, con losas de 128×64 y personajes en atlas de 8
> direcciones. La prueba de septiembre había consolidado el isométrico; el
> paso a 3D lo reemplazó (`docs/DECISIONES_CHATS.md` §2).

---

## Cómo se juega ahora mismo

| tecla | acción |
|---|---|
| `WASD` | moverse |
| `Shift` | saltar (impulso corto que ignora colisiones) |
| `Espacio` | voltereta (esquiva rápida con recarga) |
| `T` | abrir / cerrar el grimorio; **el tiempo se detiene** mientras está abierto |
| `1` `2` `3` | con el libro **cerrado**, lanzar la página 1, 2 o 3; con el libro abierto, cambiar de página |
| ratón | en los niveles se apunta con el ratón |
| `E` | hablar con un NPC, recoger un ingrediente o planta, comprar en un puesto |
| `I` | mochila (pausa el juego) |
| `Q` | beber una poción |
| `F1` | ocultar / mostrar la paleta de pruebas (incluye "Añadir todos") |
| `R` | reiniciar el nivel (también con el juego en pausa); en la pantalla de muerte, volver al último punto de guardado |

**Lanzar hechizos.** El grimorio tiene **tres páginas**. En cada una se
dibuja un elemento en el núcleo y uno o varios glifos en los sectores. Al
cerrar el libro con `T` se lanza la página abierta; con el libro cerrado,
`1`/`2`/`3` lanzan cualquiera. **Las páginas no se gastan**: al lanzarse se
quedan **recargando** el tiempo que digan sus glifos (el `cooldown` de
`Sigils.FORM`; con varios manda el mayor, no la suma). Abajo en el centro
se ve de qué elemento es cada página y cuánto le falta a su recarga.

Un mago con un solo hechizo listo no tiene decisiones: tiene el hechizo.
Con tres preparados, entrar en una sala es elegir con qué entras, y eso
convierte el libro en *preparación* y la partida en *ejecución*: dos
ritmos distintos. Las páginas podrían gastarse al usarse, y sería más
"táctico", pero el libro para el tiempo, así que rehacer un hechizo
gastado no costaría riesgo, costaría tedio. Un hechizo preparado es una
herramienta en el cinturón, no una poción.

**Cuántos glifos caben en una página** lo decide
`Repertoire.max_sigils_per_page` (los "huecos de glifo"): el nivel empieza
con 1 y se ganan más jugando o comprándolos a la librera.

### Sectores

La corona entre el núcleo y el borde está repartida en **8 sectores**. El
sector de un gesto se calcula desde el **centro** de sus puntos, no desde
donde empieza: el centro es lo único que no cambia si lo dibujas de ida o
de vuelta.

**Lo que decide el significado es DÓNDE dibujas, no qué forma tiene.**
Núcleo = elemento; sector = glifo. Antes lo decidía la forma (cerrada =
elemento, recta = patrón), y eso dejaba fuera cualquier gesto abierto: un
semicírculo no se cierra, así que jamás habría podido ser un elemento.
Mirar la posición liberó el vocabulario por completo.

**Atajo que sobrevive**: un trazo recto suelto en un sector sigue valiendo
como el glifo equivalente, según su sentido respecto al centro — hacia
fuera flecha, hacia dentro pilar, de lado barrera. El trazo es azúcar; el
glifo es el lenguaje, y solo el glifo se puede combinar.

---

## Vocabulario de runas

La hoja de referencia dibujada está en **`docs/runas.png`**.

### Elementos (sellos) — se dibujan en el NÚCLEO

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

> **`tiempo` está fuera de la progresión**: sigue en
> `GestureLibrary.ELEMENTS` y tiene plantilla grabada, pero ningún nivel lo
> da ni la librera lo vende. Solo aparece con "Añadir todos" (F1) o en los
> laboratorios. Retirado del uso, no del código, a propósito.

> **El agua perdió la etiqueta `frio`.** La llevaba de paso desde el
> principio, y al aparecer el hielo como elemento propio había que
> repartir: el agua moja, el hielo congela. Esto **cambió una solución de
> nivel** — el puente ya no se cruza congelando con agua, hay que usar
> hielo.

### Glifos — se dibujan en un SECTOR

Un glifo da **propiedades** al hechizo: no decide qué es, decide cómo se
comporta.

| Gesto | Glifo | Aporta |
|---|---|---|
| `→` | flecha | `travels`, `reach +1` |
| `⊥` | pilar | `origin = 128` (dos casillas) |
| círculo cerrado | barrera | `spread` (ocupa área), `blocks` |
| `↑` | levitación | `lifetime +2s`, `height +1` |
| dos triángulos | repetición | `copies ×2` |
| `<` | amplificar | `power ×2` |
| `V` que toca el suelo y sube | rebote | `bounces 2`: rebota en barreras y en lo que golpea; con barrera, la barrera **refleja** |
| reloj de arena | retardo | `delay 1,5 s`: sale tarde y deja una marca en el suelo |
| aros que se abren | pulso | `spread` + `pulse`: el área nace en ti y se expande |
| puntas que convergen | atracción | `pull`: tira de lo que toca (gancho con viento, vórtice con barrera) |
| eje con dos puntas hacia fuera | espejo | `mirror`: lo que viaja sale también hacia atrás |

> **Plantillas grabadas (octubre de 2026):** los 7 elementos y 4 glifos
> (`flecha`, `pilar`, `barrera`, `levitacion`). `repeticion`, `amplificar`
> y los 5 nuevos **no tienen plantilla**: no se pueden dibujar hasta que se
> graben (modo de grabación, `G`). Mientras tanto se usan desde la paleta
> de pruebas (F1).
>
> **`pilar` sigue en el código** y tiene plantilla, pero está fuera de la
> progresión de los niveles, igual que `tiempo`.

Los dos lados **nunca compiten al reconocer**: un gesto del núcleo solo se
compara contra elementos, y uno de sector solo contra glifos. Esa
separación es lo que permite que la barrera sea un círculo aunque haya
elementos redondeados, y la razón de que el vocabulario pueda crecer sin
que cada gesto nuevo degrade a todos los anteriores.

---

## El lenguaje de glifos: `sigils.gd` + `spell_recipe.gd`

Esta es la pieza de la que más se aprende del proyecto.

Seis glifos son quince parejas, veinte tríos y quince cuartetos; con once,
las cuentas se disparan. Escribir a mano qué hace cada combinación mata el
sistema: cada glifo nuevo obligaría a decidir qué pasa con todos los
anteriores.

**Por eso no hay ni una combinación escrita.** Cada glifo declara solo lo
suyo en una tabla (`sigils.gd`), lo vuelca en una receta común
(`spell_recipe.gd`), y es la receta terminada la que se interpreta al
final.

### Cómo se acumula cada parámetro

No es arbitrario: dice qué significa apilar ese glifo.

| parámetro | acumula | significado |
|---|---|---|
| `travels`, `spread` | se encienden | o viaja o no |
| `origin` | el mayor manda | el más lejano gana |
| `reach`, `lifetime`, `height` | **se suman** | más flechas, más lejos; más levitaciones, más rato |
| `copies`, `power` | **se multiplican** | dos repeticiones son cuatro |
| `bounces`, `delay`, `pulse`, `pull`, `mirror` | los traen los glifos nuevos | cada glifo nuevo es UN parámetro más; ninguna combinación con ellos está escrita |
| `cooldown` | el mayor manda | recarga de la página |
| `blocks` | se enciende | lo que sale bloquea proyectiles (la barrera) |

### Lo que emerge

Ninguna de estas líneas existe en el código:

| glifos | resultado |
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

`MAX_MANIFESTATIONS = 48` por componente. Los parámetros se multiplican
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
(o retirarlo del código junto con `tiempo`) está pendiente.

---

## Reconocimiento de gestos

### `gesture_recognizer.gd` — el reconocedor **$P**

Algoritmo **$P (Point-Cloud Recognizer)** de Vatavu, Anthony y Wobbrock
(ICMI 2012), portado a GDScript. Licencia **New BSD**.
Original: https://depts.washington.edu/acelab/proj/dollar/

**Por qué $P y no $1.** El $1 es *unistroke*: un gesto, un trazo. En
cuanto un glifo necesita varios —el copo son tres líneas, el viento tres
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
gesto y **`← →` recorren la lista entera** — hacen falta porque hay más
grabables que teclas. `Retroceso` borra la última muestra, `Supr` dos
veces borra todas las de ese gesto. `tools/podar_gestos.py` limpia
muestras dispersas y nombres muertos del `.tres`.

Vive dentro del propio libro a propósito: las plantillas se graban **en
las mismas condiciones** en que luego se dibujan. Una herramienta aparte
grabaría gestos que no se parecen a los de la partida real.

> El panel de grabación va **pegado a la esquina superior izquierda**, y
> es una corrección: colgado bajo el anillo (radio 250, centrado en una
> ventana de 648 de alto) las dos últimas líneas caían en y=650 y y=672,
> **fuera de la pantalla**. Las esquinas no dependen de lo alta que sea la
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
> nombre aunque ya no describa nada. Cualquier elemento nuevo va detrás.

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

**Los hechizos se borran por distancia RECORRIDA, no por distancia al
origen.** Antes se destruían cuando `position.length() > 2000`, que mide
desde la esquina de la escena. En los mapas pequeños daba igual; en
`Mundo` y `Test2` media mitad del mapa queda más allá de 2000 px y los
hechizos morían al nacer. Ahora `spell.gd` suma lo que ha recorrido
(`_recorrido`).

**`SpellFactory.agua_apaga_muros`.** En el Blockout el agua apaga entero
un muro de fuego que avanza (impide cruzar el canal con llamas). Los
niveles lo ponen a `false` mientras duran, para que el muro sí cruce el
agua, y lo devuelven a `true` al salir (`_exit_tree`).

> **Crear nodos de física dentro de `on_spell_hit`** da el aviso "Can't
> change this state while flushing queries": la llamada llega en mitad del
> paso de física. `reagente.gd` ya lo difiere con `call_deferred`;
> `earth_builder.gd` todavía hace `add_child` directo y funciona, pero
> debería diferirse también.

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

**Hielo permanente y que se ve descongelarse.** Con
`hielo_permanente = true` (lo ponen los niveles) el hielo ya no vuelve a
ser agua ni con calor ni con el tiempo: es un camino firme. Con tres
dibujos en `hielo` (nevado → escarcha → claro), al congelarse sale el
primero y se va fundiendo al último, que se queda. Es solo aspecto: la
casilla se puede pisar desde el primer instante. Sin dibujos, se tiñe la
losa como antes.

> **Pendiente de confirmar en Godot** (`docs/QA_ARTE.md` 1.1): los PNG de
> hielo de `art/` tienen la cara en y = 96, no en y = 33 como las losas, y
> `$Visual` hereda el `offset` de la textura del agua. Por aritmética, el
> hielo queda ~22 px hundido respecto a las losas vecinas.

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

### Piezas nuevas de los niveles

| pieza | dónde | qué hace |
|---|---|---|
| bloques empujables | `Empujable` en `nivel_base.gd` | tierra avanza una casilla por empujón; hielo resbala hasta chocar. Pesan (pisan placas) y el calor derrite el de hielo |
| objetos que arden | `combustible.gd` (letras `z l h r`) | seto, tronco, setas y telaraña: arden, se ven chamuscados y desaparecen; el seto y la telaraña son muro hasta quemarlos. Contagian a los vecinos |
| fogatas | `fogata.gd` | la llama es una capa aparte: apagada no queda ningún sprite de fuego |
| tótems | `Interruptor` en `nivel_base.gd` (letras `i j k`) | rayo, fuego o agua; cada uno solo responde a su elemento. El de rayo tiende el puente |
| placa de peso | `PlacaPeso` (letra `K`) | el jugador no la activa; hace falta un bloque de tierra creado con hechizo o un empujable |
| plantas reactivas | `reagente.gd` (letras `s f q`) | seta, flor y raíz: cada elemento las convierte en un ingrediente distinto, que cae al suelo; rebrotan |
| decorado recogible | `recolectable.gd` | lavanda, bayas, helecho, flores y piedras se cogen con `E` y rebrotan. Lo que no tiene sentido recoger (cajas, barriles) no se recoge |

Todas siguen el mismo contrato que los bloques: reaccionan por etiqueta en
`on_spell_hit` y no saben qué elemento les llega.

### Enemigos

**El principio:** usar el elemento adecuado te apoya en derrotar al
enemigo. Hoy eso se concreta en debilidades y resistencias por etiqueta;
lo que falta (escudos que arden, armaduras) está en `DISENO_FUTURO.md`.

#### `enemy.gd` y `archer.gd` — la base

Patrulla entre dos puntos y hace `damage_per_second` por contacto. Tiene
además un **golpe frontal**: si te quedas plantado delante más de 0,5s,
recibes 20 de daño con 1,5s de recarga. La espera es lo que lo hace justo
— convierte "estar delante" en una decisión y no en un accidente.

La zona de golpe se consulta por solapamiento en vez de por señales,
porque **el área se mueve cada fotograma**: con señales habría que confiar
en que entran y salen en el orden correcto al girar.

Para decidir si un hechizo le duele no lista elementos a ignorar, mira el
dato que importa: `rune_data.damage <= 0`.

#### Goblins con IA — `goblin_guerrero.gd`, `goblin_arquero.gd`, `goblin_escarcha.gd`

Heredan de `enemy.gd` y `archer.gd` y solo sustituyen el **movimiento**:

- **Guerrero:** patrulla; te detecta a 300 px, te persigue y ataca cuerpo
  a cuerpo. Si te pierde de vista 3,5 s se rinde y vuelve a su puesto.
- **Arquero:** te ve por distancia y línea de visión, se coloca a su
  distancia ideal (250 px), retrocede si te acercas y dispara. También se
  rinde a los 3,5 s.
- **Dummy** (`goblin_escarcha.gd`): no se mueve, lleva su nombre siempre a
  la vista y reaparece. No cuenta para las tareas.

La vida, la barra, la debilidad, los efectos y el botín no están en cada
goblin: los lleva un nodo hijo **`Combate`** (`combate_comun.gd`). La barra
se ve siempre, con un rombo del color de su debilidad al lado. Es
**comportamiento como componente**: el enemigo solo hace su IA y llama a
`golpe()` desde `on_spell_hit()`; cualquier enemigo nuevo se equipa con
`CombateComun.equipar()`.

| elemento | efecto en un enemigo |
|---|---|
| fuego | daño + quemadura 3 s (si está mojado, la apaga con vapor) |
| agua | daño + mojado 6 s (más lento; el rayo le hace +50 % y salta a otro) |
| rayo | daño alto + aturde; mojado, descarga en cadena |
| hielo | poco daño + congela (más si está mojado) |
| viento | interrumpe y empuja lejos |
| tierra | pedrada con retroceso fuerte y lentitud |

Debilidad ×2, resistencia ×0,5: guerrero débil al agua y resiste el
fuego; arquero débil al fuego y resiste la tierra; dummy débil al fuego y
resiste agua y hielo.

> La comprobación de "¿está libre el paso?" (`CombateComun.libre`) excluye
> los cuerpos de quien pregunta: sin eso, el goblin chocaba contra su propio
> `SolidBody` y se quedaba clavado.

---

## Vista 3D

### La casilla: 2,3 u

El mundo es 3D, pero la lógica sigue pensando en **casillas**, que es como
se piensan los puzles. Una casilla mide **`S = 2,3` u** de lado (la chibi
mide ~1 u): la misma constante está en `presentacion/prueba_test2.gd`,
`mundo/pieza_3d.gd`, `mundo/hornear_nivel.gd` y `mundo/terreno_3d.gd`. Un
bloque de tierra mide **`ALTO = S × 0,45`** (≈ 1,04 u) y el agua queda 4 cm
por debajo (`ALTO_AGUA = ALTO − 0,04`).

**`Terreno3D`** (`mundo/terreno_3d.gd`) responde a «¿qué hay en esta
casilla?»: de qué casilla es un punto, si hay agua o hielo, a qué altura
pisa quien está en ella, si se ven dos puntos. No conoce los hechizos.

> Los hechizos miden sus longitudes en **casillas** («metros-casilla»,
> `nucleo/hechizo.gd`, `docs/ESPEC_HECHIZO.md` §0.1), no en unidades del
> mundo.

### La cámara: ortogonal, fija a 60°, giros de 90°

`PruebaTest2._colocar_camara()`:

- **Proyección ortogonal** (`Camera3D.PROJECTION_ORTHOGONAL`). Sin
  perspectiva, una casilla mide lo mismo en cualquier punto de la
  pantalla.
- **Inclinación bloqueada en 60°** (`INCLINACION`, medida desde la
  vertical: la cámara mira 30° por debajo del horizonte), a 40 u del foco.
  Pablo, 6/10: «de momento lockeamos en 60 grados, siguiendo al
  personaje». Solo el zoom es libre (`size` 6 al empezar, mínimo 2).
- **Sigue al jugador** con suavizado exponencial (`SEGUIMIENTO = 14`).
- **Gira en pasos de 90°** con `Z`/`C` (`_giro_cam`), para ver lo que
  tapa algo desde el otro lado. `jugador_3d.gd` gira la entrada de `WASD`
  con ese mismo ángulo (`_giro_camara()`), así que «arriba» sigue siendo
  arriba en pantalla.

### Profundidad, oclusión y colisión

- **El orden de dibujado lo resuelve el z-buffer.** Las trampas del
  isométrico 2D (`y_sort`, desempates con `z_index`) ya no existen.
- **Lo que tapa al jugador se vuelve translúcido** en un círculo de
  pantalla centrado en él (`presentacion/ocluso_3d.gd`, `Ocluso3D`): es un
  descarte con trama, sin mezcla alfa, así que no ordena nada ni rompe la
  sombra.
- **Física: Jolt** (`3d/physics_engine` en `project.godot`). Las piezas
  que bloquean llevan un `StaticBody3D` en la **capa 11 «MUNDO»**
  (`1 << 10`), con cascos medidos **sobre el contorno del modelo** en la
  franja donde toca un cuerpo (`mundo/colision_pieza.gd`; ver *Arte*). Los
  hechizos, las flechas y la línea de visión siguen por casillas.
- **Aspecto de diorama:** profundidad de campo lejana, banda tilt-shift,
  luz por zona y sonda de reflejos (`docs/ARTE.md` §10; diario 233).

> **Historia: era 2D (hasta el 4/10).** La vista era isométrica 2D y se
> reducía a `iso_grid.gd`, una conversión casilla ↔ pantalla sacada del
> contrato de losa del pipeline (`tile_px = [128, 64]`, cara de arriba en
> y = 33). `nivel_base.gd` encogía cada losa a un rombo de 116×55 (paso
> 58 × 27,5, nivel de 55,5 px) y los personajes con el mismo factor
> (`MsAtlas.ESCALA_MUNDO`). Había tres trampas que costaron caras: sin
> `y_sort` un bloque del fondo tapaba a uno de delante; un bloque apilado
> se dibujaba detrás de su losa salvo que el nodo se quedara a ras de suelo
> y solo subiera el sprite (y el desempate no podía ser `z_index`, que
> manda sobre `y_sort`); y los personajes había que ordenarlos por los
> pies, no por el centro. Las colisiones eran rombos, y los cubos elevados
> no tenían volumen de verdad. Todo eso desapareció con el 3D.

---

## Niveles y herencia

Un **nivel es un plano de letras** y unos pocos datos. Todo lo demás lo
pone un motor común:

```
nivel_base.gd          EL MOTOR (sin padre): construye el plano letra a letra (suelos, agua y su
  │                    hielo, árboles, puente, tótems, fogatas, empujables...), jugador, cámara,
  │                    interfaz, NPC y diálogo, puestos, mochila, botín, alquimista, encargos,
  │                    goblins, guardados, pantalla de muerte, placa de peso y las 4 tareas
  ├─ test_jugabilidad.gd   el mapa de 23×23 (TestJugabilidad.tscn)
  ├─ mundo.gd              el mapa grande
  ├─ test_2.gd             el laboratorio de elementos
  └─ vfx_lab_mundo.gd
```

Un nivel **solo sobrescribe** lo suyo: `_mapa()`, `_lista_props()`,
`_lista_setos()`, `_suelo_objetos()`, `_celdas_guardado()`,
`_lista_empujables()`, `_puestos()`, `_definir_encargos()`,
`_letra_extra()`, `_extras_nivel()`, `_repertorio_inicial()` y, si sus
tareas no son las cuatro de siempre, `_progreso()`, `_refrescar_hud()` y
`_actualizar_tareas()`. Todas tienen un valor por defecto vacío en el
motor. La leyenda completa de letras está en la cabecera de
`nivel_base.gd` y en `docs/NUEVOS_SISTEMAS.md`.

**Por qué al revés que antes.** Hasta octubre el motor vivía dentro del
nivel de 23×23 y los demás niveles colgaban de él a través de seis
funciones marcadas "NO BORRAR". Una sesión reescribió ese archivo desde
una copia vieja, se perdieron los ganchos y `Mundo` y `Test2` dejaron de
arrancar. Con el motor como padre, un nivel se puede editar o rehacer
entero sin romper a los demás. **Lo que cuesta:** el motor es un archivo
largo (~2 500 líneas) y cualquier cambio de mecánica se hace ahí, no en el
nivel.

> **Regla que salió de un bug:** el motor nunca lee constantes de un
> nivel; las pide con una función. Cuando leía `SETOS` del mapa de 23×23,
> quitaba props en esas mismas casillas de **todos** los mapas.

> `test_1.gd` es un resto de la transición: ninguna escena lo usa y está
> marcado obsoleto. Se puede borrar con su `.uid`. Cuando el motor empiece
> a doler por tamaño, la partición natural es por responsabilidad
> (constructor del plano / sistemas de partida / HUD), no por nivel.

**Puestos de venta.** El mostrador (`art/puesto.png`) es el placeholder de
toda tienda y el tendero se coloca **al norte** (casilla `x, y-1`). La
librera vende pociones, huecos de glifo y tomos de elementos; el
alquimista vende **mejoras** (vida máxima, huecos de mochila, cura de las
pociones, velocidad) a cambio de oro e ingredientes (`alquimia.gd`).

---

## Test 2: laboratorio de elementos

`Test2.tscn`, 40×40. Seis cámaras, **una por elemento**, y una puerta al
norte que solo se abre con las seis pruebas superadas. Se empieza con
todos los sellos y glifos: es un laboratorio, no una progresión.

| cámara | qué pide |
|---|---|
| fuego | quemar telaraña y setos; encender el tótem |
| agua | apagar la barrera de fuego; mojar el tótem |
| tierra | cruzar el foso y crear un bloque de tierra sobre la placa de peso |
| viento | que el viento lleve la llama de las fogatas a las antorchas por encima del agua |
| rayo | electrificar el tótem para tender el puente |
| hielo | congelar 4 casillas del río |

Para qué sirve: medir si cada elemento tiene **identidad propia**. La
primera medición está en `docs/TEST2_CONCLUSIONES.md`. El hallazgo
principal es que el hielo hace de comodín (cruza cualquier agua y resuelve
también la cámara del viento) y que a la tierra solo le queda la placa
como función exclusiva. Es la pregunta que hay que responder antes de
añadir más elementos.

---

## Animación

Sin sprites ni atlas: cada personaje es **un modelo 3D vivo** que se anima
con el `AnimationPlayer` de su propio GLB. Lo monta **`Pj3D`**
(`jugador/pj_3d.gd`) para el héroe, los goblins, las bestias y los NPC.

### Cómo se carga un personaje

- `Pj3D.cargar(id)` carga **`res://arte/modelos/<id>.glb`**, lo apoya en
  el suelo, le prepara los materiales, le pone equipo (`Equipo3D`) y
  sombra, y arranca en `idle`. Si falta el GLB avisa y devuelve `false`.
- **`MODELO_DE`**: variantes que comparten modelo. La elfa jugadora es
  `woodland_wanderer` y carga `woodland_wanderer_suave.glb` (pesos de piel
  suavizados en mangas y abrigo); `goblin_espadachin` usa el GLB de
  `goblin_warrior_chibi`; el `loberno` usa `emberheart`.
- **Se gira libremente** hacia donde se mueve (`mirar()`): ya no hay 8
  filas ni 8 direcciones.

### Qué clip toca

- **Los clips se piden por rol, no por nombre.** `SINONIMOS` traduce cada
  rol (`idle`, `walk`, `run`, `cast`, `hit`, `death`, `roll`, `swim`,
  `drink`…) a los nombres que traen los GLB de Meshy/Mixamo, y
  **`CLIPS_DE`** da las excepciones por personaje (el guerrero goblin usa
  `slapreaction` como golpe porque su `HitReaction` le arrastra la
  cadera; el arquero dispara con `archeryshot`).
- **Un clip de lanzar por forma** (`ANIM_CAST`): proyectil, corro,
  columna y muro tienen su gesto, todos elegidos porque se quedan en su
  sitio (cadera < 0,3 alturas). Una forma sin clip usa `leer`.
- **La máquina de estados es `ArbolAnimPj`**: es lo único que reproduce
  clips; el `AnimationPlayer` solo se lee. Los enemigos usan el grafo
  reducido (`GRAFO_REDUCIDO`: idle, andar, correr, atacar, lanzar,
  golpeado, muerto).

### Lo que decide cómo se ve

- **Proporciones y postura sin volver a exportar.** `ProporcionChibi`
  (`jugador/proporcion_chibi.gd`, un `SkeletonModifier3D`) cambia cabeza,
  piernas y torso **después** de la animación, así que vale para todos los
  clips. `POSTURAS` endereza a la elfa (los clips de Meshy la dejan
  cabizbaja): la postura de `chibi_elf` la afinó Pablo el 5/10
  (`docs/DECISIONES_CHATS.md` §4).
- **Movimiento de raíz anulado donde estorba**: la voltereta y, en el
  elemental, ataque, andar y golpe se quedan en su sitio (`_anular_raiz`),
  porque es el Juego quien mueve al personaje; si no, al cambiar de clip
  el modelo salta.
- **La pisada va por distancia**: `jugador_3d.gd` suena un paso cada
  0,85 u andando y 1,1 u corriendo (`DIST_PASO_*`), no por fotogramas.

> **Historia: era 2D (hasta el 4/10).** Los personajes eran sprites. El
> pipeline renderizaba cada GLB en Blender en **8 direcciones** y
> exportaba atlas (`export_godot/characters/<id>/`, celdas de 192×240 y un
> `meta.json` por personaje, con la etiqueta este-oeste invertida). Los
> leían `MsAtlas` y `MsActor` (un `Sprite2D` para goblins y NPC, con modos
> `fijo`, `guerrero`, `arquero` e `ia`); el héroe era un
> `AnimatedSprite2D`, y antes aún la maga de 64×64 de `ActorAnimator`
> (`docs/ANIMACION.md` y `docs/PERSONAJE.md` son de esa época). Había que
> desaplastar la vertical ~2:1 para calcular ángulos, recortar clips a mano
> (el golpe, fotogramas 2–5) y esperar a que el pipeline exportara cada
> clip. Se abandonó porque el acabado de los personajes no se acercaba al
> terreno y mantener las animaciones en sprites era inviable
> (`docs/DECISIONES_CHATS.md` §2). Nada de eso está ya en el repo.

---

## Partículas — `block_fx.gd`

> *Era 2D: `block_fx.gd` ya no está en el repo. Los efectos 3D viven en
> `presentacion/vfx_*.gd` (`docs/ARTE.md` §9.1, §13). La idea de abajo
> —que las cosas ocurran en el sitio correcto— sigue valiendo.*

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
- **Muerte con pantalla.** Si el nivel tiene `PantallaMuerte` (grupo
  `"pantalla_muerte"`), el jugador hace su animación de caída y, **al
  acabar**, sale "HAS MUERTO"; con Enter o R reaparece en el último
  **punto de guardado** pisado (o en el inicio) con la vida llena. Sin
  pantalla, se usa el cartel `gameover_ui` de siempre.
- **`level_controller.gd`**: nodo aparte con `process_mode = ALWAYS` para
  leer `R` estando en pausa. No se puede poner ALWAYS en la raíz porque
  los hijos lo heredan y entonces nada se pausaría.
- El grimorio también es `ALWAYS`: sin eso se congelaría con su propia
  pausa y no podrías ni cerrarlo.
- `receive_damage()` tiene guarda `is_dead`: sin ella los temporizadores
  de daño en marcha seguirían llamando a `_die()` en bucle.
- **Mochila** (`bolsa_ui.gd`): barra de 8 huecos siempre visible abajo a
  la derecha y ventana completa con `I`. Huecos de 8 a 20, pilas de 9. El
  estado (oro, objetos, mejoras) vive en un único `Estado.i()`, que avisa
  con la señal `cambiado`.
- **Diálogo** (`Dialogo`): caja inferior para los NPC. **Tiendas**
  (`Tienda`): ventana de compra que abren los tenderos.
- **Páginas** (`page_hud.gd`): las tres pestañas y la voltereta, siempre a
  la vista con su recarga.

---

## Arte

La dirección de arte y los números están en `docs/ARTE.md` (estilo y
referencias al principio; §1 colores de elemento y §2 paletas de bioma;
§9–§23, piezas, paleta cerrada y láminas de Meshy). Aquí solo se cuenta
**cómo llega el arte al juego** y por qué.

### De dónde sale cada cosa

| qué | cómo se hace | dónde queda | quién lo lee |
|---|---|---|---|
| Personajes, enemigos y bestias | GLB de Meshy con esqueleto y clips (Mixamo/Meshy) | `arte/modelos/<id>.glb` | `Pj3D` (ver *Animación*) |
| Equipo (arco, grimorios, armas) | GLB de Meshy | `arte/equipo/` | `Equipo3D` (cuelga de un hueso) |
| Piezas de escenario | lámina de Meshy → `arte/meshy/recibir_assets.py` (separa, reduce, aprueba Pablo) | `arte/meshy/piezas/<id>.glb` | `Pieza3D` (medida en `Pieza3D.MEDIDA`) |
| Piezas listas para el nivel | `herramientas/generador_piezas.gd` las hornea | `arte/piezas/<id>.tscn` | el editor y el horneado de niveles |
| Niveles | `mundo/hornear_nivel.gd` (F9 en la maqueta) | `mundo/datos_nivel/Nivel_*.tscn` | `PruebaTest2` |
| Suelo | texturas de Meshy pintadas por un shader | `arte/suelo_meshy/` | la maqueta |
| Piezas de puzle, fuego, bosque, escritura | láminas de Meshy separadas por pieza | `arte/meshy/puzle/`, `fuego/`, `bosque/`, `escritura/` | `PiezaPuzle3D`, `PiezaFuego3D`, `PiezaBosque3D`, `PiezaEscritura3D` (`docs/ARTE.md` §9–§19) |
| Efectos | partículas y mallas en código | `presentacion/vfx_*.gd`, `presentacion/vfx/` | hechizos y piezas |
| Interfaz 2D (libro, bolsa, diario) | scripts de Python (Pillow) y láminas | `presentacion/ui/` | grimorio, HUD (`docs/ARTE.md` §11, §16) |

### El camino de una pieza: Meshy → GLB → `.tscn`

1. **Meshy entrega láminas**: un solo mesh con 10–20 objetos y hasta 2,6
   millones de triángulos. `recibir_assets.py` (`ver` → `lote` →
   `instalar`) las parte en trozos, reduce cada pieza (8 000 triángulos por
   defecto, 12 000 árboles y objetos grandes) y deja un lote en
   `aprobacion3d/`: **nada llega a su sitio sin que Pablo lo vea**.
2. **`Pieza3D`** (`mundo/pieza_3d.gd`) da a cada id su medida en la
   casilla de 2,3 u y su origen (**centro de la base**, a ras de suelo).
3. **`GeneradorPiezas`** (`herramientas/generador_piezas.gd`; en el
   editor, `generar_piezas_editor.gd` con Ctrl+Shift+X) escribe
   `arte/piezas/<id>.tscn`: un `Node3D` con el modelo y un `StaticBody3D`
   en la capa «MUNDO», más los metadatos `bloquea`, `reactivo` e
   `inflamable`. Hierba crecida y telaraña llevan un `Area3D` sin cuerpo.
   **Regenera todas**: una pieza retocada a mano hay que renombrarla antes.
4. **Colisión por contorno** (`mundo/colision_pieza.gd`, 20–21/10): no un
   casco de todo el modelo (rellenaba el hueco de un arco o de una puerta)
   ni una caja, sino cascos medidos en la franja de 0,12 a 1,6 u sobre el
   suelo, partidos por trozos que no se tocan. Modos: `contorno` (lo
   normal), `tronco` (árboles: solo el tronco; bajo la copa se pasa) y
   `ninguna` (lo que se pisa).
5. **El nivel se hornea** a un `.tscn` editable a partir del mapa de letras
   (camino A, 6.10) y se retoca en el editor de Godot.

### Presupuesto

Medido el 21/10 en `arte/meshy/PRESUPUESTO.md`: todo está por encima del
orientativo de EoW (enemigos ≈ 31 k triángulos, el tope de Meshy; piezas
de 8–12 k), y el Bosque 01 suma ≈ 4,2 millones, el 63 % solo en
`arbol_redondo` y `pino`. Las variantes `_2` de los árboles ahorran la
mitad sin arte nuevo; decide Pablo. Equipo: 15 k como máximo
(`docs/DECISIONES_CHATS.md` §4).

### Packs en bruto: `.gdignore`

**Godot importa todo lo que haya dentro del proyecto, lo use el juego o
no.** En la era 2D una imagen de un pack sin usar (35 623 × 635 px) tumbó
el arranque con una cascada de `Attempting to use an uninitialized RID`.
La regla sigue: las carpetas de trabajo que Godot no debe importar llevan
`.gdignore` (p. ej. `arte/aprobacion/`).

> **Historia: era 2D (hasta el 4/10).** El arte eran sprites. El
> **pipeline de sprites isométricos** (`pipeline/`, Blender) renderizaba
> cada GLB de Meshy en 8 direcciones y lo exportaba a `export_godot/`
> (personajes en atlas que leían `MsAtlas`/`MsActor`, losas de 128×64 con
> la cara de arriba en y = 33 y luz plana, árboles y props como render con
> el ancla en la base). Convivía con piezas pintadas a 2x en `art/` (hielo,
> empujables, tótems, puesto) que no cumplían el contrato de losa, y con
> efectos en tiras de 128×128 en `art/fx/` (en rejilla de 6 columnas tras
> fallar una tira de 2432 px en tarjetas con tope de 2048). `pipeline/`,
> `export_godot/` y `art/` ya no están en el repo.

---

## Decisiones de diseño

- **3D con cámara fija** (4/10/2026). El isométrico 2D (consolidado a
  principios de octubre, que a su vez había sustituido a la vista cenital)
  se abandonó porque el acabado de los personajes no se acercaba al
  terreno, se notaba el tono plastificado del render y las animaciones en
  sprites eran inviables de mantener. La prueba 2,5D del 4/10 (chibi,
  paleta pastel, Link's Awakening de referencia) se quedó: Jolt, `.glb`,
  piezas `.tscn` y cámara ortogonal a 60°. La vuelta a 2D que se llegó a
  planear no se hizo (`docs/DECISIONES_CHATS.md` §2).
- **Se descartó la vista lateral tipo Noita** por una razón concreta: en
  lateral el agua tiene que acumularse y caer, lo que obliga a rediseñar
  el agua entera y con ella la mitad de las reacciones.
- **Las reacciones viven en el objeto que reacciona**, nunca en el
  elemento. El fuego no sabe que existe la hierba.
- **Las combinaciones no se escriben, emergen.**
- **Solo se añade lo que da opciones nuevas.** Un sistema que no abre
  jugadas nuevas no entra. Si los elementos y glifos están bien elegidos,
  los puzles salen de combinarlos, no de escribir una regla por sala.
- **Los niveles cuelgan de un motor, no unos de otros.** Ver *Niveles y
  herencia*.
- **Modelos de Meshy en vez de arte dibujado.** Un personaje es un GLB
  con sus clips; un clip nuevo no cuesta dibujos ni renders. El coste
  aceptado: las animaciones vienen de una librería (Meshy/Mixamo), no a
  medida, y se corrigen en el juego (postura, proporciones, raíz anulada);
  y los modelos pesan más que el presupuesto (`arte/meshy/PRESUPUESTO.md`).
  *(En la era 2D esto mismo se hacía renderizando el GLB en 8 direcciones
  en Blender; ver Historia en* Animación*.)*
- **Dos contextos de trabajo, un archivo por dueño.** El Juego y el
  Pipeline se encuentran solo a través de datos y APIs (`Pj3D`, `Pieza3D`,
  las piezas `.tscn`, `PiezaPuzle3D`). `docs/PROPIETARIOS.md`.

---

## Errores que costaron caros

Los que volverían a morder. Las filas de sprites, atlas, losas y
`Area2D` son de la era 2D: se guardan por la lección, no porque el código
siga así.

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
| Sombrero recortado, o un clip que se corta | parece una gorra; la pose se "aplana" en un borde | el dibujo se sale del fotograma. El pipeline lo mide (`margins` en la validación de render) y `procesar_inbox.fit_margins()` recentra y, si no cabe, agranda `ortho_scale` un 15 %. Si hay `size_lock.json`, no lo toca y hay que revisarlo a mano |
| Hechizos que mueren al nacer en los mapas grandes | nada sale en media mitad de `Mundo` | se borraban por `position.length() > 2000`, que mide desde el origen de la escena, no lo recorrido |
| `Mundo` y `Test2` dejan de arrancar | "Could not resolve super class" | una sesión reescribió `test_jugabilidad.gd` entero desde una copia vieja y se llevó los ganchos que necesitaban los demás niveles. Arreglo: invertir la herencia y la regla de `PROPIETARIOS.md` (cambios parciales, leer del disco antes) |
| Goblins clavados en el sitio | el guerrero no persigue | la comprobación de "¿está libre el paso?" chocaba con el `SolidBody` del propio goblin. Arreglo: excluir los cuerpos de quien pregunta (`CombateComun.libre`) |
| "Can't change this state while flushing queries" | aviso rojo al soltar un ingrediente | crear un `Area2D` dentro de `on_spell_hit`, que llega en mitad de la física. Arreglo: `call_deferred`. (Queda el mismo aviso en `earth_builder.gd`) |
| Decorado que falta en un mapa | casillas vacías sin motivo | el motor usaba una constante del mapa de 23×23 (`SETOS`) y quitaba props en esas mismas casillas de **todos** los mapas. Regla: el motor nunca lee constantes de un nivel; las pide con una función |
| La maga muerta se levanta | sale "HAS MUERTO" con ella de pie | sin `shot_in_the_back_and_fall` se usa `hit_reaction_to_waist` entero y su última pose es la inicial. Medido: la figura baja de 135 a 97 px en el fotograma 5 y vuelve a 135 |
| Lo estático parece un fallo de dibujo | un bloque "hundido" o "flotando" al lado de otro | el `Visual` toma su `offset` de la textura del bloque base. Una textura con la cara en otra fila (hielo: y = 96, no 33) queda ~22 px más abajo, y ningún `offset` global lo arregla |
| Direcciones invertidas este-oeste | el personaje mira a la izquierda al ir a la derecha | el pipeline etiqueta cada fila al revés en ese eje; la tabla `mapeo_direcciones_godot` del `meta.json` lo corrige y hay que leerla, no suponerla |
| Escalar un raster para que "llene" | el prop se ve borroso al lado de losas nítidas | `PROP_DATOS` amplía ×1,2–1,6 props que el pipeline entrega a 38–51 px de ancho. Ampliar un raster emborrona justo lo que está delante del jugador |

---

## Pendiente / próximos pasos naturales

Hecho desde septiembre: una sola rama (`main`), el paso a 3D (4/10),
niveles horneados a `.tscn`, personajes con sus clips (`Pj3D`) y sonido
(`audio/` + `sfx.gd`, más efectos sintetizados en `sonidos.gd`).

Sigue pendiente (el plan con responsables está en `docs/PLAN_ARREGLOS.md`;
lo que es diseño nuevo, en `docs/DISENO_FUTURO.md`):

- **Identidad de cada elemento** (Test 2): que viento y tierra tengan algo
  que solo ellos hagan.
- **Grabar las plantillas** de `repeticion`, `amplificar`, `rebote`,
  `retardo`, `pulso`, `atraccion` y `espejo`.
- **Reescribir para el 3D las secciones de lógica** de este documento
  (ver el aviso de *Estado*).
- **Renombrar `pilar` a `alcance`**, o retirarlo del código junto con
  `tiempo`.
- **Bugs conocidos**: el jugador se salta el muro estando elevado; el
  arquero recibe daño de más del circuito tras morir (tarea 1.2 del plan).
- **Consola limpia**: centralizar los `print()` en `PlayLog` o tras una
  constante `DEPURAR` (tarea 1.4).
- **Arte pendiente**: `docs/ASSETS_PENDIENTES.md` y `docs/QA_ARTE.md`
  (en parte de la era 2D); el presupuesto de triángulos por decidir, en
  `arte/meshy/PRESUPUESTO.md`.
- **Atribución CC-BY**: `tree_ghibli_01` la exige y no figura en ningún
  sitio; comprobar si el árbol se usa (ver README, créditos).
- **Archivos pesados en `tools/`** (un `.exe` de 181 MB, vídeos y un zip):
  comprobar con `git ls-files tools` si están versionados y, si no,
  excluirlos en `.gitignore`.
