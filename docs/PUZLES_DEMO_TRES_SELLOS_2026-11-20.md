# Puzles para la demo de tres sellos: inventario y diseño (20/11/2026)

La demo lleva solo **fuego, agua y tierra**, con los glifos flecha, línea ᛁ, barrera ᛜ, altura, pulso ᚱ y suelo ᛒ (kit `demo`, DIARIO 537).
Este documento recoge qué puzles hay, cuáles sobreviven con ese kit y qué falta para que la demo tenga variedad. Después propone
puzles nuevos, cada uno con su coste.

**Fuentes:** los mapas `.txt`, los laboratorios `LabPuzlesFuego3D` y `LabPuzlesAgua3D`, el catálogo del generador de mapas y
`PUZLES_LOGICA_Y_ASSETS.md`. Nada de esto se ha comprobado jugando: es una lectura del código y de los mapas.

**Coste:**
- **A**: solo mapa, con piezas que ya existen.
- **B**: hace falta una pieza o reacción pequeña.
- **C**: hace falta una mecánica nueva.

---

## 1. Inventario

### 1.1 Laboratorios (18 puzles de fuego y agua)

| Puzle | Verbo | Pide | ¿Vale para la demo? |
|---|---|---|---|
| F1 Cuatro antorchas | encender todo | fuego | sí |
| F2 Relé de braseros | encender a tiempo | fuego | sí |
| F3 Quema la cuerda | soltar un mecanismo | fuego | sí |
| F4 Contrafuego | cortar la propagación | agua + fuego | sí |
| F5 Derrite el bloque | orden de pasos | fuego (el hielo es una pieza, no un hechizo) | sí |
| F7–F9 Trampas de pared | esquivar o tapar | agua, tierra | sí |
| F10 Lleva la pólvora | transportar | fuego | sí |
| F11 Tótems que escupen fuego | ritmo, cruzar carriles | agua (opcional) | sí |
| F12 Setas de veneno | despejar gas | fuego, agua | sí |
| Q1 Cuenca | llenar | agua | sí |
| Q2 Trasvase | vasos comunicantes | fuego | sí |
| Q3 Presa de hielo | cortar el caudal | **hielo** | **no** (ver T1) |
| Q4 Desvía el río | elegir un brazo | **hielo** | **no** (ver T1) |
| Q5 Vaciar para pasar | desaguar | fuego | sí |
| Q6 Riega | pulsador de agua | agua | sí |
| Q7 Rayo por el agua | conducir | agua (el rayo lo pone el emisor) | sí |
| Q8 Nivel justo | dosificar | agua, fuego | sí |
| Q9 Molino | caudal | agua | sí |
| Q10 Roca y barril | despejar el cauce | fuego | sí |
| Q11 Dos riegos | a la vez | agua | sí |
| Q12 Foso y balsa | flotar | agua | sí |

### 1.2 Niveles (unos 60 puzles)

| Nivel | Lo que hay | Con el kit demo |
|---|---|---|
| **Bosque 01** | Braseros ×2 (4 braseros y relé), setos hasta el barril, cuerda y compuerta, 3 tótems de fuego, losa que llena el estanque. | Todo vale. **Es casi todo fuego.** |
| **Bosque 02** | Unos 20 puzles: braseros, cortafuegos, muro agrietado, tronco-puente, tinaja, 3 tótems, puente con pulsador o cuerda, bloque a la placa, molino y desvío, balanza de rocas, torre que arde, santuario. | Vale casi todo. Se pierden colmena, nido y alga (ingredientes). El arroyo solo se cruza con fuego. |
| **Cueva / Cueva Resonante** | Braseros, muro (paso obligatorio), veta con hueco para tierra, río de lava, receptores, prismas, combate, pared hueca. | Vale casi todo. **Se pierden las estatuas** (piden hielo): adiós al cofre épico. |
| **Gruta Batida** | Tótems guardianes, cuerdas, puentes, «fuego + ᛜ tras una reja». | Hay riesgo (ver 1.3). |
| **Gruta Permanencia** | Placas sostenidas con tierra + ᛜ, cruces de agua con hielo. | **Se rompe:** de G4 a G6 hace falta hielo para cruzar. |
| **Sala de Empuje** | Bloque a la placa, bloque de hielo frenado con tierra, veta, bloque empujado con viento. | **E4 se rompe:** pide viento o hielo. |
| **Pantano** | **Ningún puzle.** Una nube de veneno y un tramo que «tapa el hielo o la tierra». La tierra no cuaja sobre agua. | Hay que hacerlo entero. |
| **Monte Sumicio** | Ninguno: es el pueblo. | No aplica. |

**Piezas que existen y ningún mapa usa:** `respiradero`, `trampa_dragon`, `trampa_flechas`, `mamoa`, `balsa`, `bancal`.

### 1.3 Riesgos que no tienen que ver con los elementos

- **La barrera ya no nace donde apuntas.** Desde el 30/10 nace alrededor de la jugadora, salvo la de tierra y la de hielo
  (`nucleo/sigils.gd:388`). Los puzles «fuego + ᛜ sobre la marca tras una reja» pueden estar rotos: Gruta Batida `abre_atajo` y
  Gruta Permanencia G2 y G6. Hay que jugarlos para saberlo.
- **Ninguna tierra cruza el agua.** No se construye sobre agua, y tierra + ᛒ sobre agua no hace nada. Sin hielo, en la demo el agua
  solo se cruza con troncos, puentes, balsas o vaciándola.
- **Ningún hechizo de la demo empuja bloques.** Solo lo hace el viento. Los bloques se empujan andando.

---

## 2. Diagnóstico de variedad

Agrupando los puzles por **verbo** (lo que hace la jugadora), no por pieza:

| Verbo | Fuego | Agua | Tierra |
|---|---|---|---|
| Encender o activar | **muchísimos** (braseros en 6 niveles) | tinaja, pulsador | — |
| Ritmo o tiempo | relé, tótems | — | placa sostenida 25 s |
| Llevar un flujo de A a B | setos, hierba | cauces, molino, nivel | veta (enlace) |
| Cortar un flujo | — | contrafuego | **presa: existe en el código y no la usa ningún puzle** |
| Transportar | pólvora | balsa | bloques empujados a mano |
| Construir terreno (subir, cruzar) | — | — | **apenas: P03 está propuesto y sin montar; el ᛒ sobre un foso no se usa** |
| Protegerse | — | apagar trampas | muro contra trampas (solo en el laboratorio) |
| Transformar un estado | derretir, secar | enfriar lava, mojar | escombro (no se usa) |
| Preparar el combate | — | — | **ᛒ trampas y capa lenta: no se usan en ningún puzle** |
| Revelar u observar | — | — | pared hueca (ᚱ) |

**Conclusiones:**
1. **Sobra fuego que enciende cosas.** Propongo no añadir ni un brasero más y limitar los puzles de braseros a dos por nivel.
2. **La tierra es el sello más pobre.** Solo rompe muros, rellena el hueco de una veta y pisa placas. Su verbo propio
   (**construir terreno**) no tiene puzles.
3. **El ᛒ suelo entra en la demo y no lo enseña ningún puzle.** Ni la plataforma sobre un foso, ni la capa lenta, ni las trampas.
4. **Sin hielo desaparece el verbo «cortar o cruzar agua».** La presa de tierra lo sustituye de forma natural.
5. **El Pantano no tiene nada** y es uno de los tres escenarios de la demo.

---

## 3. Puzles nuevos

Cada puzle tiene un verbo distinto o una combinación nueva. **T** = tierra, **Q** = agua, **F** = fuego, **X** = combinados.

### Tierra

**T1 · La presa en seco** — *preparar el cauce antes de soltar el agua* · tierra + ᛜ, luego cualquier hechizo · **A/B** · sustituye a Q3 y Q4
La tierra hace de presa (`lanzador_3d.gd:2879`), pero **no se puede levantar sobre el agua** (`puede_construir_en`: «es agua»). Por eso
la presa se prepara **en seco**, antes de soltar el agua. Esa es la regla que enseña el puzle.
- **T1a · Desvío (sustituye a Q4):** un manantial cerrado por una compuerta que abre y cierra un botón. Detrás hay una bifurcación
  seca: un brazo va al molino y el otro se pierde por un desagüe. Se tapa con tierra el brazo que se pierde y se abre el grifo: el
  caudal llega al molino y se abre la puerta. Si se suelta el agua sin tapar antes, se cierra el grifo, el brazo se vacía y se
  vuelve a intentar.
- **T1b · Retener (sustituye a Q3):** una cuenca con un desagüe seco que la vacía. Se tapa con tierra la boca del desagüe y después
  se riega la tinaja: la cuenca llega al nivel y la puerta se abre mientras la presa aguante (25 s).
*Comprobar:* que un cauce vacío admite la tierra. Si no la admite, hace falta permitirla en casillas de cauce por debajo de un umbral
de profundidad (coste B).

**T2 · La cornisa** — *construir para subir* · tierra + altura · **A**
Un cofre en un rellano a 2 niveles, sin escalera. Hay que levantar un escalón de 1 y otro de 2 al lado, en el orden correcto. Si se
levanta primero el alto, no se puede subir a él.
*Versión difícil:* el único sitio para el segundo peldaño es una casilla con escombro, y hay que esperar a que se despeje.
Es el P03 del documento de puzles, con escalera de dos peldaños.

**T3 · El foso** — *puentear un vacío a ritmo* · tierra + ᛒ · **A**
Una sima de 3 casillas. Cada plataforma de tierra ᛒ dura 8 s, así que no se puede tender el puente entero y cruzar después: se lanza
una plataforma, se sube a ella, se lanza la siguiente desde ahí.
Es el primer puzle que **enseña ᛒ**.
*Pantano:* aquí el vacío tiene que ser una hondonada seca, porque la tierra no cuaja sobre agua.

**T4 · Galería de tiro** — *protegerse construyendo* · tierra + ᛁ · **A**
Un pasillo con dos `trampa_flechas` en paredes opuestas y desfasadas. Un muro de tierra en línea tapa solo un lado. La jugadora tiene
que elegir **dónde** levantarlo y avanzar en el hueco de la otra trampa.
*Variante:* una `trampa_dragon` cuyo chorro se apaga con agua o se tapa con tierra, con las dos vías válidas.

**T5 · Las bocas de la mamoa** — *tapar* · tierra (bloque o ᛜ) · **B**
Tres bocas de `mamoa` que sueltan algo dañino: veneno o pequeños enemigos (la pieza existe pero falta decidir qué hace). Taparlas
todas abre el túmulo y su tesoro.
La tierra tapa durante 25 s, así que el reto es taparlas **a la vez**: un bloque empujado a mano para una, tierra para las otras dos.
*Decidir:* qué sale de la mamoa.

**T6 · Pedrada que empuja** — *empujar a distancia* · flecha de tierra · **C (pequeña)**
**Propuesta de mecánica:** la flecha de tierra mueve una casilla el bloque de piedra empujable, porque tiene el mayor retroceso del
juego. Así vuelve el verbo «empujar desde lejos», que se perdió con el viento.
*Puzle:* un bloque al otro lado de un canal de agua que hay que llevar a la placa sin poder cruzar. Arregla también E4 de la Sala de
Empuje.

### Agua

**Q13 · Brasas en el sendero** — *abrir camino apagando, a ritmo* · agua · **A**
Un sendero de setos en llamas que se reavivan a los 6 s si no se mojan del todo. Con una línea ᛁ de agua se apaga un tramo y se
avanza. Para no gastar tinta hay que apagar justo lo necesario.
Es la inversa de F4: allí el fuego es la herramienta y aquí el obstáculo.

**Q14 · El barril que no debe estallar** — *invertir el verbo* · agua, y luego fuego · **A**
Un barril con la mecha ya encendida rueda o está junto a un cofre frágil, como una urna de cristal. Primero hay que **apagarlo** con
agua (la mecha se apaga, `barril_3d.gd`), después llevarlo al muro agrietado y encenderlo allí.
Enseña que el agua también sirve para controlar el fuego.

**Q15 · El bancal** — *hacer crecer* · agua · **A/B**
Tres `bancal` que germinan con agua (la pieza existe). Uno está tras una reja baja, y hay que regarlo con una flecha de agua que pase
por encima. Al germinar los tres, se abre el vivero.
Es el P07 sin naturaleza. Encaja en el Pantano.

**Q16 · Subir la balsa** — *nivel del agua como ascensor* · agua · **B**
Q12 ampliado: la balsa está en un estanque bajo y el cofre en una orilla alta. Regar dos tinajas sube el nivel hasta que la balsa queda
a la cota de la orilla.
*Verificar:* que la `balsa` sigue el nivel.

### Fuego (sin braseros)

**F13 · La mecha de hierba** — *guiar una propagación* · fuego + agua · **A**
Un prado de hierba con un barril al fondo, junto a un muro agrietado, y un cofre de madera en un ramal. Si se prende sin más, el fuego
también quema el cofre. Hay que mojar casillas para hacer un laberinto que lleve el fuego solo al barril.
F4 es un cortafuegos que bloquea; este es un camino que se diseña.

**F14 · Cortina de vapor** — *esconderse* · fuego sobre suelo mojado · **A**
Un arquero vigía un paso abierto. El vapor en su casilla o en la de la jugadora le impide verla (`Combate3D._ve`). Se moja el suelo
del paso, se le prende fuego, y se cruza dentro del vapor.
Es sigilo con elementos, un verbo que no tiene ningún puzle.

### Combinados

**X1 · Trampas en el vado** — *preparar el combate* · fuego o agua + ᛒ y tierra + ᛒ · **A**
Una patrulla de goblins cruza un paso estrecho antes de llegar a un cofre. Se plantan trampas ᛒ de fuego o agua en su camino, y una
capa de tierra ᛒ los frena encima de ellas. El cofre se abre al vaciar el paso (con `vigia`).
Es el único puzle que **enseña ᛒ en combate**.

**X2 · Lava, presa y arroyo** — *desviar un elemento contra otro* · tierra + agua · **B**
Un río de lava corta el paso y un arroyo corre al lado. Con dos bloques de tierra se desvía el arroyo hacia la lava, que se enfría y
deja un paso de basalto que dura.
*Verificar:* que el agua de la simulación enfría la lava. Hoy solo la enfría un hechizo.

**X3 · Setas tapadas** — *tapar con tierra un respiradero* · tierra + fuego · **B**
Las setas de veneno de F12, en el Pantano. Además de quemar el gas o atascarlas con agua, **un bloque de tierra encima la sella**
mientras dura. Hay tres setas y no da tiempo a quemarlas todas: hay que repartir entre tierra, agua y fuego.
*Necesita:* la reacción «tierra tapa el respiradero», igual que la de la mamoa.

**X4 · La caldera** — *calentar agua* · agua + fuego · **C**
Una cuenca con una caldera debajo. Se llena con agua y se calienta con fuego. El vapor levanta una tapa o mueve una veleta que abre
una puerta.
*Coste alto:* necesita el estado «agua caliente». Lo dejo para después de la demo, como reserva.

---

## 4. Arreglos para que lo que existe funcione con el kit demo

| Dónde | Problema | Propuesta |
|---|---|---|
| Gruta Permanencia G4–G6 | Para cruzar el agua hace falta hielo. | Sacar la gruta de la demo **o** cambiar los cruces por T3 (foso con ᛒ) y T1 (presa). |
| Sala de Empuje E4 | Viento o hielo. | T6 (pedrada que empuja) **o** sacar E4. |
| Cueva y Cueva Resonante: estatuas | La secuencia pide hielo. | Cambiar la secuencia a **fuego, agua, tierra**: un sello por estatua. Es solo mapa. |
| Gruta Batida `abre_atajo`, Permanencia G2 y G6 | La barrera ya no nace en el punto. | Jugar para comprobarlo. Si están rotos, cambiar la marca tras la reja por un brasero alcanzable con flecha. |
| Laboratorio Q3 y Q4 | Hielo. | Montar las variantes con presa de tierra (T1). |
| Pantano (12,14) | «Lo tapa el hielo o la tierra», y la tierra no cuaja. | Quitar la frase y dejar como ruta la enredadera quemada, o usar T3 si se convierte en hondonada seca. |
| Kit demo en Bosque 02 y en las cuevas | Siguen con `kit = "pruebas"`. | Pasarlos a `demo` **después** de estos arreglos y repasar sus escenarios automáticos. |

---

## 5. Reparto por bioma (Pablo, 20/11)

Cada elemento tiene sus biomas:

| | Bosque | Cueva | Ruinas *(nuevo)* | Pantano |
|---|---|---|---|---|
| **Fuego** | ✔ | | | ✔ |
| **Agua** | ✔ | | ✔ | ✔ |
| **Tierra** | | ✔ | ✔ | ✔ |

**Orden de visita que propongo.** Cada bioma usa solo lo que ya se ha aprendido antes:
1. **Bosque** · fuego, y después agua.
2. **Cueva** · tierra sola, para aprenderla sin mezclar.
3. **Ruinas** · tierra + agua.
4. **Pantano** · los tres, y ᛒ suelo. Es el final.

El único bioma con los tres sellos es el Pantano, y por eso encaja como cierre.

**Supuesto de lectura.** Leo la tabla como el **tema** de los puzles de cada bioma: sus puzles **giran** en torno a esos elementos.
Un elemento que ya se tiene puede aparecer como apoyo, por ejemplo una antorcha en la Cueva. Si la lectura es estricta, la Cueva y las
Ruinas pierden los puzles que ya tienen de fuego y agua (ver §5.5).

### 5.1 Bosque · fuego y agua

Ya tiene mucho: braseros, relé, setos, cuerda, molino, tinaja, puente, balanza. Le falta **variedad de verbo**, no cantidad.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| F13 | Mecha de hierba (§3) | guiar el fuego | fuego + agua | A | nuevo |
| F14 | Cortina de vapor (§3) | esconderse | fuego sobre suelo mojado | A | nuevo |
| Q13 | Brasas en el sendero (§3) | apagar a ritmo | agua | A | nuevo |
| Q14 | El barril que no debe estallar (§3) | apagar antes de usar | agua, luego fuego | A | nuevo |

**Retirar:** tope de 2 puzles de braseros por nivel. Bosque 01 tiene tres seguidos. El escondite de Bosque 02 (muro agrietado) ya
se abre con la explosión de un barril, sin tierra.

### 5.2 Cueva · tierra

Ya tiene: muro agrietado (paso obligatorio), veta con hueco para el bloque, columna que tumba el pulso y pared hueca (ᚱ).
Faltan los verbos **construir**, **protegerse** y **pesar**.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| T2 | La cornisa (§3) | subir construyendo | tierra + altura | A | nuevo |
| T4 | Galería de tiro (§3) | protegerse | tierra + ᛁ | A | nuevo |
| T6 | Pedrada que empuja (§3) | empujar a distancia | flecha de tierra | C | nuevo (decisión §7) |
| **C7** | **Balanza de la mina** | pesar con lo que hay | tierra + ᛜ, empuje | A/B | nuevo |
| **C8** | **Derrumbe dirigido** | elegir de dónde sale el pulso | tierra + ᚱ | B | nuevo |

**C7 · Balanza de la mina.** Una reja se abre con dos placas de peso: A pide 3 y B pide 1. Las placas suman `peso_valor`:
- roca pequeña 1 y mediana 2;
- bloque de piedra 3;
- bloque de tierra 1 (`pulsador_3d.gd:241`).

En la sala hay una roca mediana y una pequeña, y ningún bloque de 3. Solución: la mediana y la pequeña a la placa A, que suma 3, y
para la B un bloque de tierra **mientras dure**, 25 s. La reja se cierra en cuanto la tierra caduca, así que hay que preparar A primero
y levantar la tierra en B al final, ya junto a la reja.
*Verificar:* que la tierra se levanta sobre la casilla de una placa y que dos rocas suman en la misma casilla. Si una casilla solo
admite una roca, se reparte en tres placas.

**C8 · Derrumbe dirigido.** Una columna junto a una sima. El pulso de tierra (ᚱ) la tumba (`columna`, como en C2 y C3), y debería
caer **en sentido contrario a la llegada del pulso**: si cae hacia la sima, hace de puente. Hay dos vetas que llegan a la columna, una
de cada lado, y solo una la tumba bien. La otra la tira hacia la pared y deja el paso cerrado hasta reiniciar.
*Necesita:* comprobar si la columna ya cae según de dónde llega el pulso. Si no, la regla es pequeña (coste B).

### 5.3 Ruinas · tierra y agua (bioma nuevo)

Es un bioma nuevo, así que necesita mapa, escena y arte. Su tema propone **piedra labrada y agua canalizada**: acueductos, cisternas,
suelos rotos y túmulos. Encaja con los puzles de cauces, que aquí se leen como obra humana.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| T1a | Desvío en seco (§3) | cerrar un brazo antes de soltar el agua | tierra, luego agua | A | **hecho en el lab** |
| T1b | Retener (§3) | sellar la cisterna | tierra, luego agua | A | **hecho en el lab** |
| T3 | El foso (§3) | cruzar un vacío a ritmo | tierra + ᛒ | A | nuevo |
| T5 | Las bocas de la mamoa (§3) | tapar a la vez | tierra | B | nuevo (decisión §7) |
| Q16 | Subir la balsa (§3) | el agua como ascensor | agua | B | nuevo |
| **R1** | **La cisterna dormida** | vaciar para bajar | tierra + agua | A/B | nuevo |

T1 deja la Cueva y pasa a las Ruinas, porque la Cueva ya no lleva agua. El foso T3 deja el Pantano y pasa aquí: el suelo roto de las
ruinas es un vacío natural, y en el Pantano la tierra no cuaja sobre el agua.

**R1 · La cisterna dormida.** Una cisterna llena tapa una escalera con un cofre al fondo. La alimenta un canal desde un manantial, y
tiene un desagüe con una `compuerta` que abre un `pulsador modo=agua`.
1. Si solo se riega el pulsador, la cisterna baja, pero el manantial la vuelve a llenar antes de bajar la escalera.
2. Hay que cortar antes el aporte. El canal tiene un tramo seco, un salto del acueducto, donde la tierra sí se levanta: se tapa en seco,
   **como enseñó T1**, y después se riega el pulsador.
3. La cisterna se vacía, se baja, se coge el cofre y se sube antes de que la presa caduque a los 25 s.

Es T1 aplicado en una sala grande, con un cofre como premio y una salida a contrarreloj.
*Verificar:* los tiempos de vaciado con la simulación.

### 5.4 Pantano · fuego, agua y tierra (y ᛒ suelo)

Ahora no tiene ningún puzle. Es el bioma de las **combinaciones** y de **ᛒ**. Recordatorio: la tierra no cuaja sobre el agua, así que en
el Pantano trabaja en las islas y orillas secas.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| X1 | Trampas en el vado (§3) | preparar el combate | fuego o agua + ᛒ, tierra + ᛒ | A | nuevo |
| X3 | Setas tapadas (§3) | repartir tres elementos | tierra, fuego, agua | B | nuevo |
| Q15 | El bancal (§3) | hacer crecer | agua | A/B | nuevo |
| **P1** | **Juncos secos** | guiar el fuego y proteger | fuego + agua | A | nuevo |
| **P2** | **Balsa entre juncos** | llevar flotando | agua, tierra | B | nuevo |

**P1 · Juncos secos.** Una enredadera cierra el paso al otro lado de un brazo de agua, sin alcance directo. Un cinturón de juncos secos
(setos) rodea el brazo y llega hasta ella, pero también pasa junto al bancal de Q15, ya germinado.
Hay que prenderlos para que el fuego llegue a la enredadera, y **antes** mojar los dos juncos que tocan el bancal, para que no se
queme lo que se ha cultivado.
Es F13 con una consecuencia: lo que se quema se pierde.

**P2 · Balsa entre juncos.** La `balsa` de Q12, en un canal del Pantano que sale a una orilla con un cofre.
- Para que flote hasta la orilla, el canal tiene que tener nivel: hay que regar la tinaja (agua).
- Un junco seco atraviesa el canal y la frena: hay que quemarlo (fuego).
- Al llegar, la orilla está una casilla más alta: un escalón de tierra en la orilla seca permite subir.
Usa los tres sellos en el orden en que se aprendieron.
*Verificar:* que la balsa se mueve con la corriente o con la jugadora encima.

### 5.5 Puzles que ya existen fuera de su bioma

Con la lectura estricta (cada bioma solo con sus elementos) chocan estos:

| Dónde | Puzle | Elemento | Con la lectura de tema | Con la lectura estricta |
|---|---|---|---|---|
| Cueva | Braseros de C1 norte, reja de la Cueva Resonante | fuego | Se quedan como apoyo. | Cambiar por veta y receptor de tierra. |
| Cueva | Río de lava de C3 y reja por el basalto | agua | Se quedan: es la única agua de la Cueva. | El cristal y la geoda ya lo resuelven sin agua; quitar la vía del agua. |
| Cueva | Estatuas (fuego, agua, tierra) | los tres | Valen: se vuelve con todo. | Secuencia solo de tierra, lo que no tiene sentido: mejor quitar las estatuas. |
| Bosque 02 | Escondite (muro agrietado) | tierra o explosión | Vale con el barril. | Igual: dejar solo el barril. |
| Bosque 02 | Placa K (bloque) | empuje | Vale. | Vale: no pide tierra. |

---

## 6. Orden de trabajo

1. **Hecho:** T1a y T1b en el laboratorio y las estatuas sin hielo.
2. **Laboratorio de tierra nuevo** (`LabPuzlesTierra3D`, con el patrón de los laboratorios de fuego y agua): T2, T3, T4 y C7, todos de coste A.
   Es el sello con menos puzles, y el laboratorio sirve para Cueva y Ruinas.
3. **Bosque, coste A:** F13, F14, Q13 y Q14 en el laboratorio de fuego y agua.
4. **Pantano, coste A:** X1, P1 y Q15.
5. **Reacción «la tierra tapa»** (coste B) para X3 y T5. Después P2, Q16, R1 y C8.
6. **Coste C:** T6, si se aprueba.
7. **Ruinas:** mapa, escena y arte del bioma, con T1a, T1b, T3, T5, Q16 y R1. Antes hace falta decidir su arte (§7).

Cada puzle se monta primero como sala del laboratorio, con botón `!` y placa `@`, y después se pasa al catálogo del generador de mapas
y al nivel.

## 7. Decisiones para Pablo

1. **Lectura de la tabla de biomas:** ¿tema principal, o cada bioma solo con sus elementos? Cambia lo que se hace con §5.5.
2. **Orden de visita:** ¿Bosque → Cueva → Ruinas → Pantano?
3. **Ruinas:** ¿qué arte? Por ejemplo piedra labrada con musgo, acueducto, cisterna y túmulo, o el kit de otro bioma reutilizado.
4. ¿La flecha de tierra empuja bloques (T6)?
5. ¿Qué sale de la mamoa (T5): veneno, enemigos o nada?
6. ¿Un tope de 2 puzles de braseros por nivel?
7. ¿Gruta Permanencia y Sala de Empuje entran en la demo? Si entran, con los arreglos de §4.
