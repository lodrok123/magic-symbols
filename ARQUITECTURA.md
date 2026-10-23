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

> **Todo el documento describe el juego 3D** (*Vista 3D*, *Animación* y
> *Arte*, al 21/10; la lógica, al 23/10). Lo que queda de la era 2D va en
> párrafos «Historia», que explican de dónde viene cada idea: esos
> archivos ya no están en el repo. El código vive en `nucleo/` (datos:
> runas, glifos, `Hechizo`, estado de partida), `magia/` (grimorio,
> `Lanzador3D`, `HechizoVivo`), `mundo/` (terreno, agua, estados del
> suelo, niveles), `objetos/`, `enemigos/`, `jugador/` y `presentacion/`
> (la maqueta, VFX e interfaz).
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
| `Shift` | correr |
| `Ctrl` | voltereta (esquiva rápida con recarga) |
| `Z` / `C` | girar la cámara 90° |
| `T` | abrir / cerrar el grimorio; **el tiempo va a 0,3** mientras está abierto |
| `1` `2` `3` | con el libro **cerrado**, preparar la página 1, 2 o 3; con el libro abierto, cambiar de página |
| ratón | en el modo lanzar, apuntar; al **soltar** el clic sale el hechizo |
| `E` | hablar con un NPC; comprar en la tienda del guardabosques (Bosque) |
| `I` | mochila (pausa el juego) |
| `J` | diario de misiones (pausa el juego) |
| `Q` | beber una poción |
| `F1` | ocultar / mostrar la paleta de pruebas (incluye "Añadir todos") |

**Lanzar hechizos.** El grimorio tiene **tres páginas**. En cada una se
dibuja un elemento en el núcleo y uno o varios glifos en los sectores. Al
cerrar el libro con `T` se prepara la página abierta; con el libro
cerrado, `1`/`2`/`3` preparan cualquiera. Preparar entra en el **modo
lanzar**: el tiempo va a cámara lenta, se apunta con el ratón y el
hechizo sale al soltar el clic (ver *`Lanzador3D`*). **Las páginas no se
gastan**: al lanzarse se quedan **recargando** el tiempo que digan sus
glifos (el `cooldown` de `Sigils.GLIFOS`; con varios manda el mayor, no la
suma), y cada lanzamiento cuesta **tinta**. Abajo en el centro se ve de
qué elemento es cada página y cuánto le falta a su recarga.

Un mago con un solo hechizo listo no tiene decisiones: tiene el hechizo.
Con tres preparados, entrar en una sala es elegir con qué entras, y eso
convierte el libro en *preparación* y la partida en *ejecución*: dos
ritmos distintos. Las páginas podrían gastarse al usarse, y sería más
"táctico", pero el libro casi para el tiempo, así que rehacer un hechizo
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
como el glifo equivalente, según su sentido respecto al centro: flecha o
barrera (`Sigils.PATTERN_AS_SIGIL`; el sentido que daba `pilar` ya no
vale nada). El trazo es azúcar; el glifo es el lenguaje, y solo el glifo
se puede combinar.

---

## Vocabulario de runas

La hoja de referencia dibujada está en **`docs/runas.png`**.

### Elementos (sellos) — se dibujan en el NÚCLEO

| Gesto | Elemento | Etiquetas | Daño |
|---|---|---|---|
| triángulo abierto abajo `∧` | Fuego | `fuego`, `calor` | 50 |
| onda `~` | Agua | `agua` | 40 |
| rombo `◇` | Tierra | `tierra` | 0 |
| zigzag | Rayo | `rayo`, `electrico` | 55 |
| copo de 3 trazos | Hielo | `hielo`, `frio` | 20 |
| 3 líneas horizontales | Viento | `viento` | 0 |

El daño es solo el de partida: el resto de lo que hace cada elemento (cuánto
quema, cuánto moja, cuánto empuja) va en sus `modificadores` (ver
`rune_data.gd`).

> **`tiempo` es una runa cinemática** desde el 20/10: salió de
> `GestureLibrary.ELEMENTS`, ya no se graba ni se reconoce y el jugador no
> la traza. Su `.tres` sigue (`tiempo`, `disipar`, `cinematico`) para
> eventos de nivel o de guion.
>
> El **vapor** ya no es un elemento: es un efecto que sale cuando el calor
> seca algo mojado o evapora agua.

> **El agua perdió la etiqueta `frio`.** La llevaba de paso desde el
> principio, y al aparecer el hielo como elemento propio había que
> repartir: el agua moja, el hielo congela. Esto **cambió una solución de
> nivel** — el puente ya no se cruza congelando con agua, hay que usar
> hielo.

### Glifos — se dibujan en un SECTOR

Un glifo **nunca decide qué es el hechizo**: eso lo pone el elemento. Desde
la receta V2 (17/10, `docs/GLIFOS_RECETA.md`) hay dos familias:

- **Glifos de geometría: dibujan la forma.** Sin ninguno, un hechizo es
  una esfera de 0,25 m de semieje (`Sigils.RADIO_BASE_V2`; en los
  hechizos 1 m = 1 casilla). Cada glifo de eje estira un semieje del
  elipsoide 0,15 m (`PASO_EJE_V2`), con tope de 3 m en horizontal y 1 m en
  altura.
- **Glifos de propiedad: dan una propiedad o mejoran una variable** de la
  clase `Hechizo` (velocidad, solidez, copias, rebotes…), siempre con
  tope.

| runa | glifo | familia | qué toca en `Hechizo` |
|---|---|---|---|
| ᛁ isa | `linea` | geometría | `semiejes.x` o `semiejes.z` +0,15 (tope 3), según se trace en horizontal o en vertical en la página (`linea_x` / `linea_z`). Sin barrera ni flecha, el hechizo es un **haz** |
| `⊥` | `altura` (`levitacion`, ᛏ, es su alias) | geometría | `semiejes.y` +0,15 (tope 1) |
| ᛇ eihwaz | `flecha` | propiedad | `velocidad` = 4 u/s (≈ 1,74 m/s); `distancia_max` 2 m y +1 por cada flecha más (tope 6) |
| círculo cerrado | `barrera` | propiedad | `solidez` 1 × 1,5ⁿ (tope 3); `en_punto` (nace donde apuntas, a 3 casillas como mucho); +1 s de `permanencia` por cada barrera **sucesiva** |
| ᚠ fehu | `repeticion` | propiedad | `copias` +1 (tope 4) |
| ᚢ uruz | `rebote` | propiedad | `rebotes` +1 (tope 3) |
| ᚷ gebo | `pulso` | propiedad | `crece` +0,5 m/s (tope 1,5) |
| ᛉ algiz | `permanencia` | propiedad | `permanencia` +2 s (tope 25) |

> **Glifos aparcados:** `retardo`, `atraccion`, `espejo` y `amplificar`
> se reconocen y se dibujan, pero la receta los anota en `ignorados` y el
> lanzador avisa «Aún sin uso» (`Receta3D.APARCADOS`). `Hechizo` ya tiene
> los campos que usarán (`retardo`, `potencia`).
>
> **`pilar` ya no es un glifo:** salió de `GestureLibrary.SIGILS`. La
> columna la da `barrera + altura`.
>
> **Plantillas:** `permanencia` todavía no tiene muestras grabadas en
> `gesture_library.tres`, así que no se reconoce (se graban con `G`).
> Mientras tanto se usa desde la paleta de pruebas (F1).

Los dos lados **nunca compiten al reconocer**: un gesto del núcleo solo se
compara contra elementos, y uno de sector solo contra glifos. Esa
separación es lo que permite que la barrera sea un círculo aunque haya
elementos redondeados, y la razón de que el vocabulario pueda crecer sin
que cada gesto nuevo degrade a todos los anteriores.

---

## El lenguaje de glifos: `Hechizo.construir`

Esta es la pieza de la que más se aprende del proyecto.

Seis glifos son quince parejas, veinte tríos y quince cuartetos; con once,
las cuentas se disparan. Escribir a mano qué hace cada combinación mata el
sistema: cada glifo nuevo obligaría a decidir qué pasa con todos los
anteriores.

**Por eso no hay ni una combinación escrita.** Elemento y glifos hablan el
mismo idioma, el de los **modificadores** sobre los campos de `Hechizo`
(`nucleo/hechizo.gd`, HC1 del 18/10, `docs/HECHIZO_CLASE.md`):

```
{campo, op, valor, tope, desde, salta}
  op: suma (v + valor·n) · multiplica (v · valorⁿ) · fija · minimo
```

- **Cada glifo** es una lista de modificadores en `Sigils.GLIFOS`.
  Añadir un glifo es añadir una línea a esa tabla.
- **Cada elemento** trae los suyos en su `.tres`: `damage`, `persiste`,
  `empuje`, `pisable`, `deja` y `estado` se traducen a modificadores
  «fija», y `RuneData.modificadores` añade el resto (el fuego, por
  ejemplo, `quema` 3 s, `dano_periodico` 40 y `temperatura` 1).

### El orden en que se construye

`Hechizo.construir(elemento, contadores, calidad)` es el **único sitio**
donde nace un hechizo, y siempre sigue el mismo orden:

1. valores por defecto (los `var` de `Hechizo`);
2. modificadores del elemento;
3. modificadores de los glifos: primero los que fijan y suman, después
   las multiplicaciones;
4. topes, y después los mínimos;
5. la calidad del trazo multiplica solo `persiste` y `permanencia`;
6. límites globales (`_limitar`);
7. derivados, que no se tocan a mano: forma, niveles, punto de
   lanzamiento, coste en tinta y recarga.

Los glifos de una página llegan como un **multiconjunto**
(`contadores`: nombre → veces): el orden en que se dibujaron no existe.

### Lo que emerge

Ninguna de estas líneas existe en el código: salen de leer los campos.

| página | resultado |
|---|---|
| solo el elemento | esfera pequeña y quieta |
| ᛁ (`linea`) | **haz**: instantáneo y perforante; golpea todo su recorrido (3 m, +1 m por cada ᛁ más, tope 6) |
| ᛁ + `barrera` | **muro** |
| ᛁ + `flecha` | proyectil largo |
| `flecha` | proyectil |
| `barrera` | volumen sólido que para proyectiles, nacido donde apuntas |
| `barrera` + `altura` | columna |
| `repeticion` + cualquiera | copias repartidas en X |

**Qué es por dentro lo decide el elemento, no el glifo.** El mismo muro
es un bloque pisable si es de tierra, una pared de llamas si es de fuego
o agua que corre si es de agua: lo decide el estado de la materia del
`.tres` (ver *Qué hace al llegar*).

### Lo que cuesta

- **Tinta:** crece con el volumen y con el número de propiedades
  distintas, ∝ volumen × (1 + 0,25 × propiedades) (`Sigils.coste_v2`).
- **Recarga de la página:** la del glifo más lento, más 0,5 s por cada
  glifo repetido (`cooldown_v2`). Con varios glifos manda el mayor, no la
  suma.

### Topes

Los parámetros se multiplican entre sí, así que sin topes la combinación
más creativa sería también la que tira los fotogramas. Hay tres capas:

- **Por glifo**, en su propia línea de la tabla.
- **Límites globales** al final de `construir()`, que ni los glifos ni el
  laboratorio pueden saltarse: semieje 3 m en horizontal y 1 m en alto,
  distancia 8 m, vida 25 s (`persiste` + `permanencia`), 8 copias, 6
  glifos por página.
- **Por lanzamiento**: 32 hechizos vivos (`MAX_VIVOS`) y 2 niveles de
  hijos (`MAX_PROFUNDIDAD`). Los hechizos hijos salen de los **eventos**
  (`al_nacer`, `al_golpear`, `al_matar`, `al_expirar`, `al_rebotar`,
  `al_viajar`), que solo pueden usar un catálogo cerrado de acciones:
  `danar_area`, `crear_hijo`, `estado_suelo`, `sonido` y `vfx`.

> `Sigils.GLIFOS_V2` es la misma tabla escrita a la antigua. Se conserva
> mientras la lean el laboratorio, la interfaz de ejes y las pruebas;
> `prueba_hechizo` comprueba que las dos dicen lo mismo.

> **Historia: era 2D (hasta el 4/10).** La receta era `SpellRecipe` con
> dos tablas, `Sigils.FORM` (dónde: `origin`, `travels`, `reach`,
> `spread`, `lifetime`, `height`, `blocks`) y `Sigils.OPERATOR` (cuánto:
> `copies`, `power`), cada parámetro con su propia regla de acumulación,
> y un tope de 48 manifestaciones por componente. `pilar` hacía nacer el
> hechizo a dos casillas, y `pilar + flecha` frente a `barrera + flecha`
> daban un muro a lo largo o de través. La idea —cada glifo declara solo
> lo suyo y la combinación sale sola— es la que ha sobrevivido; la tabla
> se rehízo en ejes y propiedades.

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
usarlo sin depender del nodo del jugador. Al lado vive
`enum Runes.Pattern { ARROW, PILLAR, BARRIER }`, que usan el grimorio y
`sigils.gd` para los trazos rectos.

> ⚠️ **Los enum no se reordenan.** Los `.tres` y las escenas guardan el
> **número**, no el nombre. En la era 2D, cuando `GrassBlock.State` pasó
> de 3 a 5 estados, el `initial_state = 2` del `GrassWall` dejó de
> significar `GROWN` y pasó a `IGNITING`. Por eso `ELEMENT_LIGHTNING`,
> `ELEMENT_ICE` y `ELEMENT_TIME` van **al final**, y los `DIRECTION_*` y
> `SHAPE_*` se quedan aunque ya no se usen. Cualquier elemento nuevo va
> detrás.

### `rune_data.gd` + `.tres` — las propiedades de cada elemento

Un elemento es un `Resource`: nombre, color, `glyph` (una silueta blanca
que se tiñe), `damage`, `tags` y su **materia**: `estado` (sólido,
líquido, plasma, energía, gas o campo), `persiste`, `empuje`, `pisable` y
`deja`. Lo demás va en `modificadores`, en el idioma de `Hechizo`. Añadir
una propiedad es rellenar un dato, sin tocar lógica. Un elemento nuevo se
registra en `rune_database` de `grimorio.gd`.

Las **`tags`** siguen siendo la pieza más importante del diseño **para el
mundo**: los objetos no preguntan «¿eres fuego?», preguntan «¿traes
`calor`?». El día que haya tres runas de fuego, todas derretirán hielo sin
tocar el hielo.

| elemento | tags | estado |
|---|---|---|
| fuego | `fuego`, `calor` | plasma |
| agua | `agua` | líquido |
| viento | `viento` | gas |
| tierra | `tierra` | sólido |
| rayo | `rayo`, `electrico` | energía |
| hielo | `hielo`, `frio` | sólido |
| tiempo | `tiempo`, `disipar`, `cinematico` | campo |

> `tiempo` es una runa **cinemática** (`RuneData.cinematico`): el
> jugador no la traza y `Hechizo.construir` devuelve `null` si no se le
> pide expresamente. Solo la usan eventos de nivel o de guion.
>
> Los campos de sprites (`vfx_sheet`, `beam`, `setup_sprite`…) son de la
> era 2D: los `.tres` aún los rellenan, pero nada del 3D los lee.

### `Hechizo` y `HechizoVivo` — datos y ejecución

Desde HC2 (18/10) un hechizo son dos piezas:

- **`Hechizo`** (`nucleo/hechizo.gd`, `RefCounted`): **datos puros**, sin
  nodos. Unos sesenta campos agrupados en forma, movimiento, combate,
  estados, materia, choque, aspecto y eventos, todos con su valor por
  defecto. Lo construye siempre `Hechizo.construir` (ver *El lenguaje de
  glifos*). Las longitudes van en metros-casilla y las velocidades en m/s.
- **`HechizoVivo`** (`magia/hechizo_vivo.gd`, `Node3D`): **lo ejecuta**
  en el mundo. Es el único sitio donde los metros pasan a unidades del
  motor (× 2,3). No tiene escena ni `Area2D`/`Area3D` propia; lo crea
  `HechizoVivo.crear(...)` y cuelga del `Lanzador3D`.

`HechizoVivo.crear` asigna todos los datos (`preparar`) **antes** de
`add_child`, y la posición y el movimiento **después**. El problema de
orden de la era 2D no ha desaparecido, ha cambiado de sitio:
`child_entered_tree` salta **dentro** de `add_child`, cuando el hechizo
aún no tiene posición. Por eso los VFX que lo escuchan dibujan con
`call_deferred`, y `h` tiene que estar asignado antes de meterlo en el
árbol.

Lo que el hechizo deja en el mundo (una zona de llamas, un volumen sólido,
tierra, agua) **no cuelga de él**: vive aparte en el mundo y dura lo suyo.
El `HechizoVivo` se borra solo cuando ya nació, no tiene esperas
pendientes y no está activo (`_revisar_fin`).

### `Lanzador3D` — del libro al disparo

`Lanzador3D` (`magia/lanzador_3d.gd`) hereda de `Grimorio`
(`magia/grimorio.gd`: páginas, glifos, deshacer, plantillas $P, recarga).
Hereda en vez de componer porque `spellbook.gd`, `page_hud.gd` y
`rune_palette.gd` buscan al lanzador por el grupo `"spellcaster"` y leen
sus miembros. Desde HC2, **el Lanzador solo conjura**: la ejecución es de
`HechizoVivo`.

La cadena completa:

1. **Trazo → página.** `spellbook.gd` entrega el trazo y
   `Grimorio.add_gesture` lo reconoce con $P y lo guarda en su sector (un
   glifo por sector).
2. **Página → modo lanzar.** Al cerrar el libro, `cast_page` junta los
   glifos de la página en una receta (`Receta3D`), toma como calidad la
   del **peor** trazo, comprueba la materia (un sólido más alto de lo que
   el jugador puede subir no se lanza: se avisa en vez de recortar en
   silencio) y la tinta, y entra en el **modo lanzar** con el tiempo a
   0,3.
3. **Apuntar.** El ratón solo da la **dirección**: todo nace en el
   jugador, porque lanzar lejos trivializaba el puzle. La excepción es
   `en_punto` (la barrera), que nace en el punto apuntado dentro de un
   anillo de 3 casillas.
4. **Soltar.** Al soltar el clic se cobran la tinta y la recarga. Se
   cobran **al soltar y no al disparar**: si no, se podía lanzar dos veces
   en la ventana del conjuro.
5. **Conjurar.** El clip de lanzar **manda**: el disparo sale cuando el
   clip llega al instante de su punto de lanzamiento (`CastPoints`;
   `x_mano`, `alto`, `abajo`). Mientras, se emite
   `conjuro_fase("runa" | "voluta" | "forma" | "disparo")` para los VFX.
6. **Disparar.** `receta.hechizo(rune)` → `Hechizo.construir` →
   `lanzar_hechizo` → `HechizoVivo.crear`.

### El contrato `on_spell_hit`

**Este sigue siendo el patrón clave del proyecto.** Combate y puzles usan
el mismo mecanismo, y el hechizo nunca tiene una lista de «cosas que
existen». El contrato está escrito en la cabecera de `lanzador_3d.gd`:

- **Obligatorio:** `on_spell_hit(rune_data: RuneData, direccion: Vector3)`
  en un `Area3D` de la capa `CAPA_REACTIVO` (capa 9). `direccion` es
  horizontal y unitaria, o cero si el hechizo está quieto. **Se decide por
  `rune_data.tags`, nunca por el tipo de runa.**
- **Opcionales:** `spell_reacts` (si devuelve falso, el hechizo lo
  atraviesa), `spell_passes_through`, `spell_flies_over`,
  `carried_element`, `bloquea_proyectiles` / `refleja_a` (zonas en
  `CAPA_BLOQUEO`, capa 10), `push(dir, fuerza)`, `nivel_altura()` (0 = a
  ras: reacciona pero no detiene) y `punto_activacion()`.

Todo golpe pasa por **un único punto**, `Lanzador3D._golpear`: lleva el
golpe al `punto_activacion` si lo hay, aplica el empuje del viento, mira
`spell_reacts`, deja la posición en `Lanzador3D.ultimo_impacto` (la firma
no la lleva; quien la necesite la lee de ahí), lo apunta en el `PlayLog`
y llama a `on_spell_hit`.

Los **enemigos** amplían la firma con un tercer argumento, el `Hechizo`
entero, porque sus efectos (cuánto quema, cuánto moja) salen de sus
campos. Ver *Enemigos*.

### Cómo encuentra un hechizo lo que toca

Ya no hay un área que espere a `area_entered`: el hechizo **pregunta**.

- **Proyectil** (`velocidad` > 0). Avanza en `_physics_process` y en cada
  paso consulta tres cosas:
  - **paredes y suelo por casilla** (`Lanzador3D.celda_solida`,
    `Terreno3D.y_pies`). Si le quedan rebotes, rebota. Si no, golpea lo
    que hay **dentro** de la casilla sólida (un pulsador, una antorcha:
    nunca llegaría a su radio) y termina;
  - **objetos con un rayo** del tramo recorrido (`_rayo_areas`: hasta 24
    `intersect_ray` contra áreas de `CAPA_REACTIVO | CAPA_BLOQUEO`,
    ordenados por distancia). `bloquea_proyectiles` lo para;
  - **enemigos y reactivos por distancia** (grupos `combate3d` y
    `reactivo3d`), con el radio del proyectil más 0,6 u en planta y 1 u
    en vertical.

  Golpea cada cosa una vez; al pasar de `perfora`, termina. Donde se para
  aplica su materia **una vez** en las casillas de su volumen; si lo paró
  un golpe, en la casilla de lo golpeado («un goblin en el agua se hiela
  con su casilla»). El alcance se mide **en planta**, por lo recorrido
  (`recorrido`), porque un arco recorre más en 3D.
- **Volumen quieto** (`velocidad` = 0). El elipsoide se rasteriza a
  casillas (cuenta la casilla cuyo centro cae dentro; la del origen
  siempre) y se golpea lo que esté en ellas (`nodos_en`). Si tiene
  `distancia_max`, viaja por tandas a 8 m/s siguiendo `Lanzador3D.trazar`,
  que avanza a pasos de 0,1 casilla hasta una casilla sólida o una
  barrera.
- **Haz.** Instantáneo y perforante: golpea una vez todo su recorrido al
  nacer y se queda dibujado 0,9 s (+ `permanencia`).

> El proyectil se ve y choca a **la mitad de su tamaño**
> (`Hechizo.ESCALA_PROYECTIL = 0,5`, decisión del 21/10 tras el playtest:
> medía más que la chibi). Solo cambia lo que se ve volar y el radio de
> acierto, no el coste ni la zona.

### Qué hace al llegar: el estado de la materia

Lo decide el `estado` del `.tres` (`HechizoVivo.MATERIA_V2`), no el
elemento por su nombre:

| estado | elementos | qué hace |
|---|---|---|
| sólido | tierra, hielo | construye tierra si es `pisable`; si no, bloquea la casilla |
| líquido | agua | añade agua a `AguaSim3D` |
| plasma | fuego | zona que hace daño a pulsos |
| energía | rayo | descarga que recorre el agua conectada |
| gas | viento | zona de empuje |
| campo | tiempo | ralentiza |

Las zonas (`Lanzador3D.ZonaV2`) golpean a pulsos cada 0,25 s. Sólido,
líquido y campo dan además un golpe de contacto al nacer.

Encima van los modificadores de forma: `solidez` añade un volumen que
bloquea proyectiles y aguanta 30 × solidez de daño (`SolidezV2`; con
rebote y sin viajar, refleja), y `copias`, `crece` y `retardo`.

**Cuánto dura:** lo que viaja se queda `permanencia` segundos donde llega
o choca (ahí `persiste` no cuenta); lo que nace quieto dura `persiste +
permanencia`. Tope: 25 s.

### Lecciones de Godot que salieron aquí

- **Callbacks diferidos y nodos muertos.** Una lambda que captura `self`
  da error en el motor si el nodo muere antes, **aunque compruebe
  `is_instance_valid`**: el error salta al llamarla. Se usan
  `bind(weakref(...))` y métodos estáticos (`HechizoVivo._tras_espera`,
  `Lanzador3D._borrar_si_vive`).
- **Temporizadores que respetan la pausa:** `create_timer(t, false)`.
- **Los pulsos de zona no pasan por `on_spell_hit`**, van directos a
  `receive_damage`, así que tienen que consultar el escudo
  (`escudo_cubre`). Sin eso, el goblin con escudo perdía 10 de vida cada
  0,25 s.
- La zona que nace donde se para un proyectil no vuelve a cobrar en el
  mismo instante a quien ya recibió el golpe.

> **Historia: era 2D (hasta el 4/10).** El hechizo era `spell.gd`, un
> `Area2D` que llevaba su `RuneData` y llamaba a `on_spell_hit` al tocar
> otra área. Había tres tipos (con dirección, quieto, perforante), un
> `spell_factory.gd` que existía solo porque el orden de asignación antes
> de `add_child` importaba, y un `await physics_frame` al nacer para ver lo
> que ya estaba solapado. Dos ideas de entonces **no han pasado al 3D**:
> - **El viento que arrastra un elemento** («viento cargado de fuego que
>   prende lo de más allá»). `trazar` todavía consulta `carried_element()`
>   y varios objetos lo implementan, pero `HechizoVivo` golpea con su
>   propio dato y no usa la carga: hoy un viento que cruza fuego **no**
>   prende lo de más allá.
> - **`SpellFactory.agua_apaga_muros`** ya no existe. Lo más parecido es
>   `BarreraFuego`: las casillas `B` del plano se apagan con
>   `agua`/`frio` y salpican a sus cuatro vecinas.

---

## El mundo: objetos que reaccionan

El hechizo habla con el mundo por **dos puertas**, según quién recibe:

- **Los objetos** (`Area3D` con `on_spell_hit`) reciben el `RuneData` y
  reaccionan por etiqueta (ver *El contrato `on_spell_hit`*).
- **El suelo y el agua** no son nodos: son datos por casilla. Reciben una
  **acción elemental** (`AccionElemental`: elemento, punto, radio,
  cantidad, duración, dirección…) por `Mundo3D.aplicar_accion`, que la
  reparte a `ReaccionesAgua3D` y, si toca suelo, a `ReaccionesSuelo3D`.
  El mundo recibe acciones, no hechizos. La única entrada es
  `Lanzador3D.al_impactar`.

**El mundo no depende de la magia.** Lo «mágico» entra por `Callable`
(`Terreno3D.al_solidificar`, `ReaccionesAgua3D.efecto`,
`ReaccionesSuelo3D.clasificar`), y lo que el mundo quiere contar sale por
las señales de `Mundo3D`:

- `casilla_cambio(c, que)`: agua, hielo, rayo, fuego, mojado, siega,
  bloqueo, altura o letra. La escucha `Caminos3D` para rehacer el A* solo
  de esa casilla.
- `impacto(punto, elemento, radio)`: para VFX y sonido.
- `reaccion(nombre, punto, nodo)`: con un **catálogo cerrado** de 13
  nombres (prendido, apagado_agua, congelado, electrocutado, hundido…).
  Un nombre que no esté en el catálogo da un aviso y no se emite.
- `logro(...)`.

### El suelo: estados por casilla

Ya no hay un nodo por bloque. **`EstadosSuelo3D`**
(`mundo/estados_suelo_3d.gd`) es el **único dueño** del estado de cada
casilla. Hay cinco estados que pueden coincidir: `helada`,
`electrificada`, `quemada`, `mojada` y `segada`. De cada uno guarda el
hecho, una intensidad 0–1 y un avance solo visual. Lo publica como una
textura de un píxel por casilla (R quemada, G mojada, B helada, A segada)
que leen los shaders de suelo, agua y hierba, y avisa con
`cambio(c, estado, si)` solo cuando algo cambia de verdad.

La tabla está escrita como datos (`EstadosSuelo3D.TRANSICIONES`; gana la
primera fila que encaje):

| casilla | agua | frío | calor |
|---|---|---|---|
| seca | → mojada | → helada (escarcha) | — |
| mojada | → helada | → helada | → seca **+ vapor** |
| helada | — | — | → mojada |

- El agua pide **dos** impactos para helar; el hielo, uno. Por eso un
  impacto se aplica **una sola vez** (`marcar_celda`): si se marcara dos
  veces, el agua sola helaría el suelo.
- **Escarcha no es hielo.** «Helada» sobre suelo es escarcha: no cambia
  cómo se anda ni la altura de los pies. Solo el hielo **sobre agua** se
  pisa (`Terreno3D.hielo_fisico`). Sin esa distinción, helar el suelo lo
  hundía a la altura del agua.
- La escarcha pasa a mojada a los 20 s.
- Agua y frío no actúan sobre casillas elevadas; el fuego sí.
- Rayo, viento y tierra no cambian el estado del suelo.

> **Un dato, un dueño** salió de un bug: el hielo se leía con
> `mundo.get("_helada")` en ocho sitios, y la maqueta tenía su propia
> imagen de estados que contradecía al juego. Las condiciones de puzle
> del tipo «esta casilla mojada» no se cumplían nunca jugando.

### El agua: `AguaSim3D`

`mundo/agua_sim_3d.gd` es una **simulación de volumen** real («tuberías
virtuales», O'Brien-Hodgins). Divide cada casilla en 3×3 trocitos de
0,77 u, con profundidad, caudal hacia cuatro vecinos, hielo, manantiales y
ríos de nivel fijo. Corre a 30 Hz, solo dentro de una caja de trabajo, y
**conserva el volumen**. Una casilla es agua desde 0,25 u de profundidad.

- **agua** añade volumen; si dura (un chorro), es un manantial.
- **fuego** funde el hielo del círculo y, si no había, evapora (avisa
  «vapor»).
- **hielo** hiela durante 20 s el agua del círculo (sin renovar el tiempo
  si ya estaba helada). El hielo atrapa flotadores y goblins, se pisa a su
  altura, y con 0,5 u de espesor para también proyectiles y vista. Corta
  la corriente.
- La **tierra** y las **compuertas** apartan el agua sin perderla
  (`solidificar_casilla`): la tierra hace de presa.
- El **vapor** ya no es un elemento: es solo un efecto visual.

> Lecciones del agua: sin una lámina mínima retenida, un manantial se
> extendía en una película de milímetros y el suelo se la bebía; un cauce
> que no toca el borde es una balsa cerrada que desborda (se arregla
> fijando el nivel en el río de desagüe); una tinaja con manantial
> infinito inundaba la sala.

### Electricidad: `EmisorRayo3D`

La corriente no la pone el rayo del jugador: la ponen los **emisores**
(`objetos/emisor_rayo_3d.gd`, letra `e`). Sueltan una descarga cada 4 s
que dura 1,6 s y recorre el agua **conectada**: una búsqueda en anchura a
cuatro vecinas, sin diagonales y con un tope de 4096 casillas. El hielo
corta la corriente; el agua bajo un puente sí conduce, y también un nexo
mojado (`Terreno3D.conductores`). Hace 8 de daño cada 0,4 s a quien esté
dentro y activa los tótems de rayo.

El rayo del jugador, en cambio, es una **descarga** que recorre el agua
conectada desde donde cae (estado «energía»).

> En 2D la descarga se golpeaba a sí misma y hacía falta un pestillo
> (`is_electrified`) para no colgar el juego. En 3D no hay recursión
> física: la búsqueda tiene su tope.

### La tierra del jugador

`Lanzador3D.construir_tierra` decide dónde se puede: no fuera del mapa,
ni sobre agua o puente, ni sobre algo bloqueado o una cornisa
permanente, ni encima del jugador o de un goblin. Sube un nivel como
mucho, dura 25 s y parpadea los últimos 3.

**Tope FIFO de 8 niveles**: desaparece el más antiguo, nunca el recién
creado, así el jugador nunca siente que su última acción no hizo nada.
La solidez de verdad está en `Terreno3D.alturas`. El bloque es además un
`Area3D` del grupo `peso` para que lo noten las placas.

> Ya no decide quien recibe el hechizo (el `occupant` de la era 2D): lo
> decide el Lanzador preguntando a `Terreno3D`. **Disipar no existe** en
> 3D, ni la regla «tierra + agua = vegetación».

### Hierba e incendio

La hierba es un **autómata por casilla dentro de la maqueta**
(`PruebaTest2._hf`), no en `mundo/`:

```
FINA ──agua──> CRECIDA
  │              │
  └──fuego───────┴──> PRENDIENDO ──1s──> ARDIENDO ──5s──> CENIZAS
                          │                 │                │
                          └───agua/hielo────┴────────────────┴──> FINA
```

- **El rayo se salta la fase de prender:** cae y arde. Es la vía rápida
  frente al fuego, que aún puedes apagar mientras prende.
- **Contagio por frente** a las cuatro vecinas, a 0,5 casillas/s y hasta
  1,7 casillas. Si el frente toca antes un objeto inflamable, lo prende.
- **Viento sobre llamas** (`_abanicar`): salta en un cono de 3,6 casillas
  (producto escalar ≥ 0,3).
- **Agua o hielo** apagan un cuadrado de 5×5 y dejan la hierba mojada 8 s
  para que no vuelva a prender.
- **Tope: 60 casillas ardiendo** y 24 efectos de hierba. El 6/10 medio
  mapa en llamas congeló una GPU integrada.
- La hierba crecida **ya no bloquea**. Lo quemado se copia al estado
  `quemada` del suelo (`ReaccionesSuelo3D.sincronizar_hierba`).

### `Reactivo3D` y las piezas de `objetos/`

**`Reactivo3D`** (`objetos/objetos_3d.gd`, un `Area3D`) es un solo nodo
con varios `tipo` para las piezas del plano: seto, tronco, telaraña,
puerta y torre goblin (arden), tótems de fuego, agua y rayo, fogata y
brasero, puente plegado, placa de peso, cristal de rayo y surtidor/tinaja.
Avisa con `consumido`, `activado`, `agua_llega` y `llama`, y está en los
grupos `reactivo3d`, `flammable3d` y `peso`.

**Papeles** (A1, 21/10): en vez de preguntar por el tipo, cada pieza
declara lo que es: `inflamable`, `propaga_llama`, `apaga`, `mojable`,
`pesado`, `fuente_fuego`, `activable`, `recibe_agua`… Hay una tabla por
tipo (`PAPELES_POR_TIPO`) y cada pieza puede añadir o quitar papeles con
`+x` / `-x`.

> **Cortafuegos:** el contagio (cada 0,8 s, a 1,7 casillas) es más rápido
> que la combustión (3,5 s un seto), así que la única forma de frenar un
> incendio es quitarle combustible. La leña mojada no prende durante
> 12 s: con 8 s el seto mojado se secaba a mitad del incendio.

Las demás piezas tienen su propio script:

| pieza | qué hace |
|---|---|
| `Barril3D` | calor o rayo encienden la mecha (1,2 s), el agua la apaga; explota en 2,6 u y avisa al grupo `explosionable` |
| `Compuerta3D` | pared en un cauce: abierta deja pasar el agua de la simulación, cerrada la aparta. Se abre por código o con el elemento que se le diga |
| `Cuerda3D` | arde 1 s con calor o rayo; al romperse tiende o cierra lo que sostiene |
| `Enredadera3D` | brota, arde por focos y se deshace; solo el fuego la quema y bloquea mientras vive |
| `Flotador3D` | cuerpo rígido que flota y deriva con la corriente de `AguaSim3D`; el hielo lo atrapa |
| `Molino3D` | gira con corriente (> 0,3 u/s) o 6 s tras un hechizo de agua |
| `NexoRayo3D` | pila: el agua la moja 30 s y entonces conduce; el calor la seca |
| `NivelAgua3D` | detector de profundidad con histéresis; no reacciona a hechizos |
| `PuenteReactivo3D` | fila de losas que emergen al tenderlo |
| `Pulsador3D` | botón (magia, agua o presencia); si el golpe no vale, lo dice («SOLO AGUA»), porque «pulsando este botón no pasa nada» |
| `Surtidor3D` | con agua abre su cauce y echa agua |
| `TroncoEstanque3D` | sube con el agua; a 0,45 u de profundidad se vuelve puente |
| `TroncoPuente3D` | con calor arde y cae cruzando el río |
| `ContadorReactivos3D` | cuenta cuántos de una lista están encendidos |

> Del 2D no han pasado los **empujables** (se dibujan, sin mecánica), las
> **plantas reactivas** que daban ingredientes (en 3D son decorado) ni el
> **decorado recogible con `E`**.

### Enemigos

**El principio:** usar el elemento adecuado te ayuda a derrotar al
enemigo. Hoy eso se concreta en debilidades, resistencias y efectos por
elemento; lo que falta está en `docs/DISENO_FUTURO.md`.

#### `Combate3D` — un nodo para todos

`enemigos/combate_3d.gd` es un `Area3D` que lleva **en un solo archivo**
la IA, la vida, la tabla de debilidades, los efectos y el botín. Se cuelga
**junto a** un modelo `Pj3D`, que no sabe nada de IA, con
`Combate3D.equipar(modelo, mundo, jugador, lanz)`. Es hermano del modelo,
no hijo: así su posición es la del mundo, y cada fotograma se la copia al
modelo. Lo monta `Jugador3D.montar` para cada goblin que la maqueta haya
puesto en el plano.

El tipo sale del `id` del modelo:

| tipo | cómo es |
|---|---|
| goblin guerrero | el de serie: vida 100, débil al agua, resiste el fuego |
| goblin arquero | `goblin_archer*`: mismas debilidades que el guerrero; se coloca a 6,5 u, retrocede si te acercas a menos de 2,4 y dispara flechas que van a donde estás **ahora** (si te mueves, fallan) |
| goblin asesino | `goblin_asesino*`: dos cortes (`AtaqueDoble`). Hoy solo aparece con Alt+F11 |
| elemental del bosque | `elemental_bosque`: vida 1000, débil al fuego; puñetazos de área y enredaderas; el agua lo cura y lo agranda una vez. Barra de jefe |
| gatopedro (lince) | `Gatopedro3D`, la única subclase: **no ataca, huye**; sirve para practicar las páginas (Terra Fina) |

> El **loberno** del Bosque 01 usa `Combate3D` sin rama propia, así que
> hereda los valores del guerrero (nombre incluido). El **dummy** ya no es
> un enemigo: la letra `D` pone un muñeco decorativo. Para una diana se
> usa `Combate3D.quieto = true`.

**IA** (`patrulla` → `persigue` → `busca` → `vuelve`): te ve a 5,75 u con
línea de visión, saca un «!», te persigue a 2,4 u/s y, si pasa 3,5 s sin
verte o te alejas más de 10 u, vuelve a su puesto. Si la recta no está
libre usa el A* de `Caminos3D`, recalculado cada 0,5 s. Cuerpo a cuerpo:
carga 0,6 s y pega 20 de daño a 1,2 u. El golpe sale en un momento
concreto del clip, y se cancela si te alejas antes. Un goblin no entra al
agua andando; solo un empujón lo mete.

**Efectos por elemento.** Desde HC3 las duraciones y fuerzas salen de los
campos del `Hechizo` (los `modificadores` de cada `.tres`). En
`Combate3D` solo queda lo que depende del estado del enemigo:

| elemento | efecto |
|---|---|
| fuego | daño + quemadura (3 s); si está mojado, sale vapor y no prende |
| agua | daño + mojado (6 s, −25 % de velocidad); apaga la quemadura |
| rayo | daño + aturde 1,2 s; mojado, ×1,5 y salta a otro enemigo a menos de 4,5 u |
| hielo | congela 1,5 s, o 2,5 s y +15 de daño si está mojado |
| viento | interrumpe 0,7 s; el empujón lo da el Lanzador con `push()` |
| tierra | lentitud 3 s y empujón fuerte |

Debilidad ×2, resistencia ×0,5; quien resiste el agua también resiste el
hielo. Hay siete **reacciones nombradas** fijas, y cada cambio de estado
se avisa con `Mundo3D.avisar_reaccion` para que la presentación decida
cómo se ve.

Además:

- **Fuego por contacto:** un enemigo que arde prende lo inflamable que
  toca, y al revés.
- **Cae al agua honda** de un empujón: se hunde y muere **sin botín**.
- **Barra de vida** 3D con un rombo del color de la debilidad. Con la
  vida llena solo se ve el rombo; la barra aparece con el primer daño.
- **Botín:** monedas de oro (`Botin3D`), que se recogen al pasar cerca.
- **Al morir** avisa con `Estado.i().enemigo_muerto`.

> Las constantes de «sensación de golpe» (hitstop, destello, temblor) son
> `static var` y no `const` **a propósito**: el laboratorio las afina en
> vivo.

#### Escudo: comportamiento como componente

`Escudo3D` (`enemigos/escudo_3d.gd`) es un nodo hijo que se equipa con
`Escudo3D.equipar(combate)`. `Combate3D` lo consulta en un solo punto
(`escudo.para(direccion, hechizo)`): bloquea los disparos de frente en un
cono de 120° y tiene 60 de vida propia. Tiene papeles como un reactivo
(`inflamable`, `bloquea_proyectiles`). El fuego lo consume en 3 s, y
entonces al goblin «se le quema la mano» y queda aturdido. Hoy solo lo
llevan los laboratorios.

Es el patrón para lo que venga (armaduras, monturas): **nodo hijo + una
consulta**. La base no lo sigue: IA y combate están juntos en
`Combate3D`, y el elemental va en el mismo archivo, porque separarlo
habría duplicado la lógica o habría obligado a abrir `Combate3D` a la
herencia.

> **Historia: era 2D (hasta el 4/10).** Los enemigos eran `enemy.gd` y
> `archer.gd`, y los goblins con IA heredaban de ellos y solo cambiaban
> el movimiento. La vida, las debilidades y el botín los llevaba un hijo
> `Combate` (`combate_comun.gd`). Había un golpe frontal tras 0,5 s
> plantado delante, daño por contacto, un arquero débil al fuego y un
> dummy que reaparecía. En el mundo, cada casilla era un nodo
> (`neutral_block.gd`, `water_block.gd`, `earth_block.gd`,
> `grass_block.gd`) con su tabla de estados, más `combustible.gd`,
> `fogata.gd`, `reagente.gd`, `recolectable.gd` y las clases `Empujable`,
> `Interruptor` y `PlacaPeso` de `nivel_base.gd`. Las ideas —reaccionar
> por etiqueta, el tope FIFO de la tierra, el rayo que se salta la fase de
> prender— han sobrevivido; los archivos, no.

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

## Niveles: una maqueta y sus reglas

Ya no hay un motor padre del que hereden los niveles. Hay **una sola
maqueta**, `PruebaTest2` (`presentacion/prueba_test2.gd`), y cada escena
`Prueba*.tscn` la **configura** con unos pocos `@export` y le cuelga sus
reglas:

| export | qué elige |
|---|---|
| `nivel` | qué plano carga (por defecto `test2`) |
| `reglas` | reglas por nombre: `""`, `"jugabilidad"` o `"bosque"` |
| `kit` | `"pruebas"` da todo el repertorio |
| `fuego_nuevo`, `vitrina_vfx`, `usar_escena` | variantes de presentación |

Por ejemplo, `PruebaBosque.tscn` (la escena principal) pone el nivel
`Bosque` con las reglas `bosque`. `PruebaBosque01.tscn` pone `Bosque_01`
y le cuelga dos nodos hijos, *Reglas* (`bosque_01_3d.gd`) y *Puzles*
(`puzle.gd`).

### De dónde sale el plano

Por dentro, un nivel **sigue siendo un plano de letras**. La maqueta lo
toma del primero de estos tres sitios que exista:

1. **Un nivel editable** `mundo/datos_nivel/Nivel_<Nombre>.tscn`, que es
   lo que se toca en el editor. Lleva un `GridMap` *Suelo* (letras de
   suelo), *Piezas* y *Borde* (instancias de `arte/piezas/<id>.tscn`) y
   *Marcadores* (`Marcador3D`, cada uno con su letra). La maqueta
   reconstruye las filas de letras a partir de ellos.
2. **Un mapa en texto** `mundo/datos_nivel/mapas/<nivel>.txt`
   (`HorneadorNivel.leer_mapa`), con comentarios `; azar_suelo`,
   `; giro x y grados` y las líneas `; pieza` / `; puzle` que lee
   `Puzle3D`. Así van Terra Fina y los laboratorios.
3. **Una constante en código:** `Jugabilidad3D.MAPA` (23×23),
   `NivelPruebas.MAPA` (16×16) y `DatosTest2.MAPA_TEST2` (40×40).
   `datos_test2.gd` es solo datos: sustituye al `preload` de `test_2.gd`,
   que arrastraba 41 archivos de la era 2D.

**La leyenda** está en `mundo/marcador_3d.gd` (`LETRAS`, con grupo, tipo y
pieza). Qué hace cada letra al montarse lo decide `_colocar_letras` de la
maqueta. Un nivel puede usar letras propias que la maqueta ignora.

**Hornear** (F9, `mundo/hornear_nivel.gd`) pasa el plano a un
`Nivel_<Nombre>.tscn` editable: lo que se ve es exactamente lo que sale,
sin repetir reglas de colocación. Si el archivo ya existe lo aparta como
`_copia_<hora>`, y no hornea un nivel que ya se cargó de `.tscn`.

> En Windows `ResourceLoader.exists` no distingue mayúsculas, así que la
> comprobación de que existe el nivel se hace a mano: un
> `nivel_Bosque.tscn` viejo se cargaba en lugar del bueno.

### Qué monta la maqueta

`PruebaTest2._ready`, en este orden:

1. `Mundo3D` y el plano; `Terreno3D.cargar_datos`.
2. Entorno, sol, luz por zona y posproceso.
3. Los nodos *Decorado* y *Efectos*, `Vfx3D`, y las tablas
   `ReaccionesVfx3D` y `Logros3D` enganchadas a las señales del mundo.
4. Suelo, letras, canal, agua simulada, extras, el `.tscn` del nivel, lotes
   `MultiMesh`, hierba y ambiente.
5. Cámara, precalentado de VFX tras un velo y
   **`Jugador3D.montar(self)`**: el jugador, el `Lanzador3D` con su
   interfaz, un `Combate3D` por goblin, el HUD y la pantalla de muerte.
6. Los VFX de conjuro y de proyectil, y la solidez por colisión real.
7. `reglas.iniciar(self)`.

Las **reglas** se enganchan de dos maneras:

- **Por nombre** (`reglas`), con un contrato sin tipo que la maqueta va
  llamando: `registrar_losa` y `registrar_npc` mientras coloca letras,
  `colocar(mundo)` antes de agrupar los lotes e `iniciar(mundo)` al
  final. Así van `Jugabilidad3D` y `Bosque3D`.
- **Como nodo hijo** que en su `_ready` difiere un `iniciar(get_parent())`:
  Terra Fina, Bosque 01, `Puzle3D` y los laboratorios. Existe porque la
  maqueta solo conoce por nombre las reglas de la lista fija.

> **Las constantes de la maqueta son contrato.** `Jugador3D.montar` y
> `Terreno3D.configurar` leen `S`, `ALTO`, `ALTO_AGUA`, `VEL_ANDAR`… de
> la maqueta con `get_script_constant_map`.

### Lo que cuesta

La maqueta tiene **5 600 líneas** (293 KB) y mezcla cargador, dibujo,
shaders en cadenas, la simulación de la hierba y una API para el juego
(`llenar_cauce`, `electrificar_agua`…). La partición que propone
`docs/ARQUITECTURA_MODULAR.md` (M5: cargador de nivel / maqueta) está sin
hacer, y la maqueta incumple sus reglas en dos sitios:

- **Lee constantes de los niveles** (`Jugabilidad3D.MAPA`,
  `NivelPruebas.MAPA`…) y tiene casos por nombre (`nivel == "Bosque"`).
  En la era 2D, eso mismo quitaba props en las casillas equivocadas de
  todos los mapas.
- **Las reglas tocan privados de la maqueta** (`_bloqueadas`, `_props`,
  `_goblins`…). Además conviven dos estados de bloqueo: `_bloqueadas` y
  la fuente de solidez del Lanzador. Siempre hay que pasar por
  `_bloquear` / `_liberar`.

Lecciones que costaron algo:

- **Los estáticos sobreviven a la escena.** `Terreno3D`, el tope de
  niveles del jugador y las señales de `Estado` se limpian a mano al
  salir. Una prueba lo cazó con un cierre corrupto.
- **El `.tscn` del nivel leído fuera del árbol se filtraba** hasta cerrar
  el juego: se libera al terminar de leerlo.
- **Un nivel nuevo heredaba el botín, los rótulos y los colores de
  Test 2** si no se vaciaban.
- **El motor de física no ve los cuerpos nuevos** hasta uno o dos
  fotogramas de física. Se esperan y, si no aparecen, se vuelve a la
  solidez por casillas.
- **F9 era síncrono y parecía una pausa:** se pulsaba otra vez y salían
  copias.
- Dos veces una sesión reescribió un archivo desde una copia vieja
  (`test_jugabilidad.gd` el 5/10, `prueba_test2.gd` el 13/10, 17 KB
  menos). La regla es verificar en disco (`docs/PROPIETARIOS.md`).

**Personajes, NPC y puestos** salen también de letras: `S` jugador,
`W`/`A` goblins, `G` elemental, `n`/`Q` librera y alquimista con su
puesto, `M` librera suelta, `m` guardabosques. El puesto ocupa dos
casillas y el tendero queda a 0,8 u al norte. **Diálogo y tienda no son
clases:** cada nivel tiene su tabla `DIALOGOS` y su manejador de `E` (a
2,7 u). La única tienda es la mínima de `Bosque3D`: el guardabosques vende
el glifo barrera por 20 de oro. Los encargos los sustituye `Misiones`
(ver *Interfaz*).

> **Historia: era 2D (hasta el 4/10).** El motor era `nivel_base.gd`
> (~2 500 líneas, sin padre), y cada nivel heredaba de él y solo
> sobrescribía funciones con valor por defecto vacío (`_mapa()`,
> `_lista_props()`, `_puestos()`, `_definir_encargos()`…):
> `test_jugabilidad.gd`, `mundo.gd`, `test_2.gd` y `vfx_lab_mundo.gd`.
> Se le dio la vuelta (antes el motor vivía dentro del nivel de 23×23)
> después de que una sesión perdiera los ganchos y `Mundo` y `Test2`
> dejaran de arrancar. Había tiendas de verdad (`Tienda`), diálogo
> (`Dialogo`), encargos y las mejoras del alquimista (`alquimia.gd`).

---

## Test 2: el mapa de los elementos

`PruebaTest2.tscn` sin reglas carga el mapa de 40×40 (`DatosTest2`, o
`Nivel_Test2.tscn` si existe), con sus seis cámaras, una por elemento.
**Hoy es solo el mapa:** cada cámara tiene su rótulo, su cartel y sus
mecanismos (telaraña, setos, tótems, barrera de fuego, placa de peso,
fogatas y braseros, porque son letras con `Reactivo3D`), pero **no hay
lógica de prueba superada ni puerta que se abra**: la `X` es solo un
arco. Se empieza con todo el repertorio.

Varias cámaras han cambiado por debajo: el puente `b` es fijo desde el
11/10 (la cámara del rayo ya no pide nada), el tótem de rayo solo para
las tinajas, el agua es pared porque nadar está desactivado y el hielo
dura 20 s.

**Para qué servía, y sigue pendiente:** medir si cada elemento tiene
**identidad propia**. La medición de `docs/TEST2_CONCLUSIONES.md` es de
la era 2D: el hielo hacía de comodín y a la tierra solo le quedaba la
placa. No hay medición en 3D.

El papel de laboratorio lo cubren hoy `laboratorios/`: recetas y
hechizos (`LabRecetas3D`, `LabHechizos3D`), puzles de fuego y de agua
(salas de 7×7 con una mecánica cada una) y el playtest de siete salas
(`LabPlaytestEoW3D`).

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

## Efectos visuales

**El juego no decide partículas.** La lógica avisa de lo que pasa (una
señal de `Mundo3D`, una fase del conjuro, un hechizo que nace) y una tabla
de presentación decide cómo se ve. Es la separación lógica → tabla →
efecto del análisis de *Echoes of Wisdom*.

| pieza | qué dibuja | quién la dispara |
|---|---|---|
| `Vfx3D` (`presentacion/vfx_3d.gd`) | llamas, fuego fijo y de pared, vapor, ceniza, chispazo, salpicadura, temblor, estrella de golpe | `Reactivo3D`, la maqueta y el Lanzador |
| `VfxKit3D` | piezas comunes estáticas (bola, impacto, haz, onda, cúpula, muro, pilar), shader de llama, bloom | los demás |
| `vfx_elementos/*.gd` | el aspecto de cada elemento (rampa, perfil, ganchos); tierra y hielo usan GLB de Meshy | `VfxKit3D` |
| `VfxElemento3D` | el proyectil en vuelo | `child_entered_tree` y `hechizo_v2` del Lanzador |
| `VfxEstado3D` | el volumen según el estado de la materia | apagado de serie; F8 |
| `ConjuroVfx3D` | la voluta y la forma en la mano | `conjuro_fase` |
| `ReaccionesVfx3D` + `VfxReaccion3D` | una reacción con nombre → efecto y sonido, con excepciones por tipo (goblin, flecha, escudo…) | `Mundo3D.reaccion` |
| `Logros3D` | la respuesta a un logro: sonido, motas, aro, rótulo, hitstop, zoom | `Mundo3D.logro` |

**Los estallidos cuelgan de `Vfx3D`, no del objeto.** La idea es la de
la era 2D: muchos ocurren porque el objeto *desaparece*, y un hijo se va
con su padre. El objeto que arde solo guarda una referencia a su llama, y
la ceniza se pide al `Vfx3D` antes del `queue_free`. Excepciones
deliberadas:

- **Las llamas de un cuerpo o de una flecha** cuelgan de él para seguirlo,
  con las brasas en `local_coords = false`.
- **El efecto del proyectil** cuelga del `HechizoVivo`. Cuando este se va,
  pasa al mundo con un `reparent` **inmediato** (uno diferido llegaría a
  un nodo ya muerto) y se apaga en 0,5 s.

**Los emisores no se reutilizan:** se crean en cada encendido y se liberan
al apagarse. El tirón de la primera vez se evita **precalentando**: al
cargar, un velo («Preparando efectos…») tapa el lanzamiento de los seis
elementos.

Reglas que salieron de fallos:

- **Presupuesto:** 10 llamas completas y 3 luces de llama a la vez, 40
  restos en el suelo; por volumen de `VfxEstado3D`, 2 luces y 400
  partículas.
- **Los giros van en `_process`, no en un tween en bucle**, para que
  mueran con su padre.
- **Un efecto nunca falla porque falte un PNG:** usa un punto suave.
- `VfxElemento3D` da por hecho que el hechizo que acaba de anunciarse es
  **el último `HechizoVivo` que entró**, porque la señal no trae el nodo.
- En GLSL, `smoothstep` con `edge0 > edge1` es indefinido y en Vulkan
  rompía. La llama pasó de aditiva a mezcla porque el naranja viraba a
  amarillo. El bloom se juzga en Forward+.

> **Historia: era 2D (hasta el 4/10).** Las partículas eran
> `block_fx.gd`. En isométrico el volumen era un engaño, y lo que lo
> sostenía era que las cosas ocurrieran en el sitio correcto: los
> emisores nacían en la cara de arriba del cubo, repartidos en un óvalo
> ancho y bajo. Los emisores continuos se creaban una vez y luego solo se
> encendían y apagaban.

---

## Bloqueo físico vs. detección de hechizos

Siguen siendo dos cosas distintas, y en 3D van por capas
(`Lanzador3D`):

| capa | constante | qué hay |
|---|---|---|
| 8 | `CAPA_HECHIZO` | — |
| 9 | `CAPA_REACTIVO` | `Area3D` con `on_spell_hit`: lo que detecta un hechizo |
| 10 | `CAPA_BLOQUEO` | zonas que paran proyectiles |
| 11 | `CAPA_SOLIDO` | `StaticBody3D` del grupo `bloquea`: lo que choca |

- **El hechizo detecta** con consultas sobre áreas
  (`collide_with_areas`, sin cuerpos). Un objeto deja de reaccionar
  poniendo `collision_layer = 0` (un barril que explotó, un reactivo
  consumido).
- **El jugador no es un cuerpo físico:** es un `Node3D` que se mueve por
  casillas preguntando a `Terreno3D` (`pisable`, `choca_huella`). La
  solidez sale de una **fuente intercambiable**: por casillas
  (`FuenteCasillas`) o por la colisión real de las piezas
  (`FuenteNodos`, «lo que se ve es lo que choca»). Esta última da una
  casilla por bloqueada cuando la forma cubre su 50 % central, y el
  jugador roza con una esfera de 0,3 u.
- Lo que se crea jugando se bloquea con `Terreno3D.bloquear_celda` /
  `liberar_celda`, que avisan con `casilla_cambio("bloqueo")`.
- Los cascos de las piezas los mide `ColisionPieza` sobre el contorno del
  modelo (ver *Arte*). No tocan hechizos, flechas ni línea de visión, que
  siguen por casillas.

> Con el 90 % de la casilla, `FuenteNodos` cerraba pasillos (90 casillas
> por pino); con el casco convexo del modelo entero salían muros
> invisibles. Y aunque la pieza sea fina, una caja que envuelve dos
> pilares sigue tapando el paso.
>
> **Los `Reactivo3D` nacen con capa 0** hasta que existe el Lanzador, que
> les añade `CAPA_REACTIVO`.

> **Historia: era 2D (hasta el 4/10).** Cada objeto interactivo llevaba
> un `Area2D` (detectaba el hechizo) y un `StaticBody2D` hijo,
> `SolidBody`, que bloqueaba al jugador y se encendía con
> `set_deferred("disabled", ...)` para no tocar la física a mitad de paso.

---

## Interfaz y estados de partida

Casi toda la interfaz la monta `Lanzador3D.construir_interfaz()` en un
`CanvasLayer` («InterfazLanzador», capa 10):

| pieza | archivo | cómo se entera |
|---|---|---|
| vida y tinta | `Jugador3D._construir_hud` (capa 9) | sondea cada fotograma |
| páginas | `ui/page_hud.gd` | grupo `"spellcaster"` |
| grimorio (`T`) | `ui/spellbook.gd` | grupo `"spellcaster"` |
| paleta de runas (F1, pruebas) | `ui/rune_palette.gd` | grupo `"spellcaster"`; se rehace al cambiar el repertorio |
| mochila (`I`) | `ui/bolsa_ui.gd` (capa 30) | `Estado.i().cambiado` |
| diario de misiones (`J`) | `ui/diario_misiones.gd` (capa 31) | `Misiones.i().mision_cambio` / `seguida_cambio` |
| línea de misión en el HUD | `ui/mision_hud.gd` | las mismas señales |
| pantalla de muerte | `ui/pantalla_muerte.gd` (capa 40) | la llama `Jugador3D._morir` |
| barra de jefe | dentro de `Combate3D` | — |

**El estado de la partida** vive en dos `RefCounted` con instancia
estática (no son autoload):

- `Estado.i()`: oro, mochila (8 huecos al empezar, hasta 20; pilas de 9),
  mejoras y vida máxima. Avisa con `cambiado`, `enemigo_muerto` y
  `objeto_conseguido`. **No se guarda en disco.**
- `Misiones.i()`: las misiones como diccionarios, con `mision_cambio` y
  `seguida_cambio`. La recompensa la paga `Estado`, una sola vez. Se
  guarda en `user://misiones.json` (y las banderas en
  `user://flags.json`), pero solo cuando se pisa una baldosa de guardado
  de `Jugabilidad3D`.

**Morir.** `Jugador3D.recibir_dano` tiene su guarda (`muerto`, 0,7 s de
invulnerabilidad). Al llegar a 0, `_morir` reproduce `death` y llama a
`PantallaMuerte`, que esconde las demás capas, desenfoca el mundo, muestra
«Has muerto», funde a negro y **reaparece sola** en `puntos_inicio` con la
vida y la tinta llenas. **No pausa el árbol:** usa tweens que ignoran la
escala de tiempo. Solo `Jugabilidad3D` mueve `puntos_inicio` al pisar un
guardado. **No hay pantalla de victoria:** el fin de un nivel es un logro
(`nivel_completado`) y un aviso.

**Pausa.** Pausan de verdad la mochila y el diario, y los dos despausan
en `_exit_tree` (cambiar de escena con la mochila abierta no puede dejar
el mundo congelado). **El grimorio ya no detiene el tiempo:** lo pone a
0,3 (`Engine.time_scale`), y el Lanzador deshace en cada fotograma la
pausa que pide `spellbook.gd`. Llevan `PROCESS_MODE_ALWAYS` el Lanzador,
el libro, la mochila, el diario, la línea de misión y la pantalla de
muerte. Ninguna pantalla se abre encima de otra que ya pausa: abrirla
la descongelaría.

> **Historia: era 2D (hasta el 4/10).** `health_bar.gd` escuchaba
> `health_changed`; victoria y muerte buscaban su cartel por grupo y
> pausaban el árbol; `level_controller.gd` (en `ALWAYS`) leía `R` en
> pausa, y no se podía poner `ALWAYS` en la raíz porque lo heredaban los
> hijos. La mochila tenía una correa de 8 huecos siempre visible (Pablo la
> quitó el 10/10), y había `Dialogo` y `Tienda` como clases.

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
- **Los niveles configuran una maqueta, no heredan unos de otros.** Un
  nivel es un plano y unas reglas que se enganchan a `PruebaTest2`. Ver
  *Niveles*.
- **El hechizo son datos; ejecutarlo es otra pieza.** `Hechizo` no tiene
  nodos y se construye en un solo sitio; `HechizoVivo` lo ejecuta. Un
  glifo o un elemento nuevo es una línea de modificadores.
- **Un dato, un dueño.** El estado del suelo es de `EstadosSuelo3D`, el
  agua de `AguaSim3D` y la solidez de `Terreno3D`; los demás preguntan o
  mandan acciones, nunca leen privados con `get("_x")`
  (`docs/ARQUITECTURA_MODULAR.md`).
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
| "Can't change this state while flushing queries" | aviso rojo al soltar un ingrediente | crear un `Area2D` dentro de `on_spell_hit`, que llega en mitad de la física. Arreglo: `call_deferred`. (Era 2D: en 3D los hechizos preguntan con consultas y no crean nodos de física dentro de `on_spell_hit`) |
| Decorado que falta en un mapa | casillas vacías sin motivo | el motor usaba una constante del mapa de 23×23 (`SETOS`) y quitaba props en esas mismas casillas de **todos** los mapas. Regla: el motor nunca lee constantes de un nivel; las pide con una función |
| La maga muerta se levanta | sale "HAS MUERTO" con ella de pie | sin `shot_in_the_back_and_fall` se usa `hit_reaction_to_waist` entero y su última pose es la inicial. Medido: la figura baja de 135 a 97 px en el fotograma 5 y vuelve a 135 |
| Lo estático parece un fallo de dibujo | un bloque "hundido" o "flotando" al lado de otro | el `Visual` toma su `offset` de la textura del bloque base. Una textura con la cara en otra fila (hielo: y = 96, no 33) queda ~22 px más abajo, y ningún `offset` global lo arregla |
| Direcciones invertidas este-oeste | el personaje mira a la izquierda al ir a la derecha | el pipeline etiqueta cada fila al revés en ese eje; la tabla `mapeo_direcciones_godot` del `meta.json` lo corrige y hay que leerla, no suponerla |
| Error al llamar a un callback diferido | error del motor aunque se compruebe `is_instance_valid` | la lambda capturaba un nodo que ya había muerto. Arreglo: `bind(weakref(...))` y métodos estáticos |
| Puzles que no se resuelven jugando | la condición «casilla mojada» no se cumple nunca | el estado del suelo tenía dos dueños (la maqueta y el juego) que se contradecían. Arreglo: `EstadosSuelo3D` como único dueño |
| Goblin con escudo que se derrite | pierde 10 de vida cada 0,25 s | los pulsos de una zona van directos a `receive_damage` y no pasan por el escudo. Arreglo: consultar `escudo_cubre` |
| Media GPU congelada | el juego se para con un incendio grande | medio mapa de hierba en llamas, cada casilla con sus efectos. Arreglo: tope de 60 casillas ardiendo y 24 efectos |
| Pasillos cerrados sin motivo | el jugador no pasa junto a un pino | la colisión real rozaba el 90 % de la casilla y la daba por bloqueada. Arreglo: contar solo el 50 % central |
| Escalar un raster para que "llene" | el prop se ve borroso al lado de losas nítidas | `PROP_DATOS` amplía ×1,2–1,6 props que el pipeline entrega a 38–51 px de ancho. Ampliar un raster emborrona justo lo que está delante del jugador |

---

## Pendiente / próximos pasos naturales

Hecho desde septiembre: una sola rama (`main`), el paso a 3D (4/10),
niveles horneados a `.tscn`, personajes con sus clips (`Pj3D`) y sonido
(`audio/` + `sfx.gd`, más efectos sintetizados en `sonidos.gd`). Después,
la receta V2 y la clase `Hechizo` (17–21/10), la retirada de `pilar` y
de `tiempo` como runas que traza el jugador, la atribución CC-BY del
árbol en el README y los archivos pesados de `tools/` fuera de git.

Sigue pendiente (el plan con responsables está en `docs/PLAN_ARREGLOS.md`;
lo que es diseño nuevo, en `docs/DISENO_FUTURO.md`):

- **Identidad de cada elemento** (Test 2): que viento y tierra tengan algo
  que solo ellos hagan.
  Hoy no hay medición en 3D, y el mapa de Test 2 no tiene lógica de
  prueba superada (ver *Test 2*).
- **Grabar las plantillas** que falten, al menos la de `permanencia`.
- **El viento ya no arrastra elementos**: `trazar` calcula la carga, pero
  `HechizoVivo` no la usa (ver la Historia de *Las piezas del sistema*).
  Decidir si se recupera o se retira `carried_element`.
- **Partir la maqueta** (`prueba_test2.gd`, 5 600 líneas) según la M5 de
  `docs/ARQUITECTURA_MODULAR.md`, y quitarle las lecturas de constantes
  de nivel y de privados (ver *Niveles*).
- **Bugs conocidos**: el jugador se salta el muro estando elevado; el
  arquero recibe daño de más del circuito tras morir (tarea 1.2 del plan).
- **Atajos F1–F6 de la maqueta**: en `PruebaTest2._unhandled_input` la
  rama `KEY_F1, … KEY_F6:` se quedó sin cuerpo al añadir RePág/AvPág/Inicio
  (21/10), y el `_lanzar` de F1–F6 acabó dentro de `KEY_HOME`. Comprobar
  en Godot si el script carga.
- **Restos que confunden**: el indicador de voltereta de `page_hud.gd`
  busca un método que ya no existe (y rotula «Espacio» en vez de `Ctrl`);
  el loberno hereda nombre y debilidades del guerrero; `Estado` no se
  guarda y `Estado.nuevo()` no lo llama nadie; `spellcaster.gd`, los
  campos de sprites de `RuneData` y `Lanzador3D._barrido` / `_una_ola`
  son código muerto. Hay comentarios desfasados en `hechizo.gd` («aún no
  lo lee nadie»), en la cabecera de `lanzador_3d.gd` y en la de
  `prueba_test2.gd` («es solo visual»).
- **Consola limpia**: centralizar los `print()` en `PlayLog` o tras una
  constante `DEPURAR` (tarea 1.4).
- **Arte pendiente**: `docs/ASSETS_PENDIENTES.md` y `docs/QA_ARTE.md`
  (en parte de la era 2D); el presupuesto de triángulos por decidir, en
  `arte/meshy/PRESUPUESTO.md`.
