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
*Sensación (21/11, visto en Mystralia, ver `MAGES_OF_MYSTRALIA_2026-11-21.md` O5):* semilla visible que anuncia dónde nace la
plataforma, nacimiento de golpe con una onda de polvo de ~0,6 s, plataformas que encajan entre sí y ritmo de unos 1,6 s por paso.

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

**X8 · Tres braseros y las plataformas** — *llegar a un ángulo de tiro que solo da la plataforma móvil, aguantando un chorro que empuja* · fuego + barrera · **B** · *añadido el 21/11 (Pablo, visto en Mages of Mystralia, O15)*
Una sala con un foso en medio y una puerta que pide **tres braseros encendidos**. Dos se encienden desde el suelo (uno de frente y otro en
diagonal); el **tercero solo queda a tiro desde una plataforma móvil** que cruza el foso. Por encima del recorrido de la plataforma pasa un
**chorro que empuja**: sin protegerse, tira a la jugadora de la plataforma; con la **barrera puesta** lo aguanta. Se resuelve combinando
moverse, protegerse y disparar en el momento en que la plataforma da el ángulo.
*Necesita:*
- La **plataforma móvil** (P6), la misma de X5 y X6.
- Un **chorro que empuje** en vez de dañar. El viento está fuera de la demo: o una trampa de **agua a presión** que empuja, o la losa de viento del escenario de C21.
- Que la barrera **aguante el empuje** del chorro (hoy la barrera para proyectiles y golpes; el empuje habría que comprobarlo).
- Contador de braseros: ya existe (`contador`, como los tres braseros de Bosque 01).
*Ojo:* si caer al foso cuesta mucho, se vuelve frustrante. Que caer devuelva al borde con poco daño.

**X9 · Plataformas en raíl sobre el cañón** — *activar el receptor de cada parada para cruzar en cadena, apuntando desde algo que se mueve* · agua (noria); también fuego (brasero) o tierra (contrapeso) · **B** · *añadido el 22/11 (Pablo, visto en Mages of Mystralia, O19; PROPUESTAS «P10 · X9»)*
Un cañón con pilares y foso. Entre cada dos pilares, un **raíl** visible con una plataforma en un extremo y, junto a su parada, una **noria**. Se sube a la plataforma, se riega la noria con una flecha o un haz de agua y la plataforma recorre su raíl entero (~3–4 s) hasta el pilar siguiente, donde empieza otro raíl, a menudo en otra dirección. Varios tramos. En un pilar hay dos raíles: uno sigue y el otro lleva a un cofre o a un callejón.
*Necesita:*
- La **plataforma móvil** (P6), la misma de X5, X6 y X8, con un modo que hace un viaje entero cuando se le manda `avanzar`, y el raíl dibujado a lo largo de su ruta.
- La regla «receptor → plataforma.avanzar», como la de «botón apaga trampa» (`cuando=noria_1.girando hace=pl_1.avanzar`).
*Qué existe ya:* la noria es el `molino` (gira con agua, condición `girando`); el `receptor` de elemento; el brasero; las placas de peso; caer de una plataforma al foso ya devuelve al borde sin daño.
*Verificar:* que se puede apuntar a la noria desde una plataforma en marcha. Con la cámara fija, raíles de 4–6 casillas para que cada tramo se vea entero.
*Más adelante:* una trampa dragón que barre un tramo y se tapa con la barrera (regla C18) o se esquiva cambiando de plataforma.
Plan: `PLAN_PUZLES_2026-11-22.md` (5b).

**X10 · Reflejar el rayo de luz** — *hacer de espejo y apuntar girando* · agua (protección) · **B/C** · *añadido el 22/11 (Pablo, visto en Mages of Mystralia, O24; PROPUESTAS «P11 · X10»)*
Un haz de luz baja del techo a un pedestal. La jugadora se pone en él con su **protección de agua** y la luz sale reflejada como un rayo horizontal **hacia donde mira**. Girando, lo lleva a un `receptor`.
- **Fácil:** el receptor está a la vista.
- **Media:** el receptor está tras una esquina; el rayo va al `prisma`, que se gira con E, y de ahí al receptor.
- **Difícil:** dos receptores; el primero abre una puerta durante N s (`rearme`, con la cuenta atrás común del temporizador P8) y hay que llevar el rayo al segundo antes de que se cierre.
*Qué existe ya:* el receptor, el prisma, el cristal como base del emisor, y el cálculo del rayo que se corta en lo sólido (el chorro de la trampa dragón), que se dibuja como el haz ᛁ.
*Necesita:* la luz cenital con su pedestal; que la protección de agua refleje y se mantenga mientras se gira; que el receptor y el prisma reciban la luz. **El pulso no vale tal cual:** no viaja por el aire, solo por lo que conduce.
*Verificar:* qué protección se mantiene (barrera o burbuja, C10). La cámara fija tiene que ver a la vez el pedestal y el receptor.
*Variante para después:* el escudo de hielo, como en Mystralia.
Plan: `PLAN_PUZLES_2026-11-22.md` (3b).

**X11 · La luz mueve la vagoneta** — *seguir con el reflejo algo que se mueve* · agua (protección) · **B** (sobre X9 y X10) · *añadido el 22/11 (Pablo, visto en Mages of Mystralia, O25; PROPUESTAS «P12 · X11»)*
Una vagoneta con un cristal **avanza por su vía mientras le da la luz** y se para cuando no. La luz le llega por una cadena: fuente → `prisma`, que se gira con E → reflejo de la jugadora (X10) → vagoneta. La jugadora tiene que ir siguiéndola mientras avanza; si la vía pasa tras un muro, se mueve para no perder la línea. Al final de la vía, la vagoneta hace de puente, de contrapeso o de llave.
*Necesita:*
- La **plataforma móvil** (P6) con un modo `va=luz`: avanza en el sentido de la vía mientras su receptor recibe luz.
- Un **receptor que viaja** encima de la plataforma.
- El **rayo de X10**, recalculado a menudo, porque el blanco se mueve.
*Variantes para después (D1):* la misma vagoneta movida por un chorro de agua o por un brasero encima.
Plan: `PLAN_PUZLES_2026-11-22.md` (5c).

**X12 · Alinear los prismas y poner tú el último reflejo** — *preparar y después ejecutar* · agua (protección) · **A/B** (casi solo mapa, sobre la base de X10) · *añadido el 22/11 (Pablo, visto en Mages of Mystralia, O26; PROPUESTAS «P13 · X12»)*
Una fuente de luz y un `prisma` en el centro de la sala. **Primero** se gira el prisma con E, y se queda donde se deja. **Después**, la jugadora cierra la cadena con su reflejo (X10), que solo dura mientras lo mantiene: fuente → reflejo → prisma → receptor, y el receptor abre la puerta. La sala obliga al orden: desde el sitio del reflejo no se llega al prisma.
*Versión difícil:* dos prismas en cadena.
*Qué existe ya:* el prisma (gira 90° y se queda), el receptor y la regla que abre la puerta.
*Necesita:* solo la base de la luz: luz cenital, reflejo de la protección de agua, y prisma y receptor que acepten la luz.
*Diseño:* sobre la cuadrícula, con fuente, prismas y receptor alineados en filas y columnas.
*Recompensa:* el cofre mágico o una mejora del libro.
Es la tercera variante del rayo de luz, con X10 (reflejar y apuntar) y X11 (la luz mueve la vagoneta).
Plan: `PLAN_PUZLES_2026-11-22.md` (3d y §5.1).

**X7 · El brasero tras el chorro** — *disparar a través de un peligro para apagarlo un momento* · fuego · **A (casi solo mapa)** · *añadido el 21/11 (Pablo, visto en Mages of Mystralia, O13)*
Una `trampa_dragon` corta un pasillo con su chorro sin descanso (`ciclo=` largo de fuego). Al otro lado, o a un costado tras el chorro, hay un
**brasero**. Hay que dispararle **a través del chorro**; al encenderse, la trampa se apaga unos segundos y se cruza corriendo.
*Qué existe ya:* las trampas se apagan con una regla (`hace=<trampa>.apagar(s)`, como el botón de `PuzlesFuego.txt:108`); solo cambia el
disparador: `cuando=<brasero>.encendido hace=<trampa>.apagar(2.5)`.
*Ajustes:*
- **Tiempo corto** (~2,5 s, como Mystralia) y el brasero **se apaga solo** (`dura=` del brasero) para poder repetir.
- **Qué cruza el chorro** (tabla de contacto, C19): la bola de fuego cruza un chorro de fuego sin problema; una flecha de **agua** se apagaría en él (caso ineficaz que enseña a elegir). Con un chorro de **agua**, al revés: el fuego no pasa.
*Verificar:* que la bola de fuego atraviesa el haz de la trampa sin apagarse ni transformarse (cruces de `HechizoVivo._cruzar_zonas`).
*Confirmado por Pablo (21/11):* en Mystralia el brasero es el disparador y el chorro vuelve con un temporizador. Concepto general en `docs/CONCEPTO_TEMPORIZADOR_2026-11-21.md`.

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

**X5 · Plataforma bajo el dragón** — *protegerse de un chorro mientras te llevan* · barrera ᛝ (tierra o agua) · **B** · *añadido el 21/11 (Pablo, visto en Mages of Mystralia)*
Una plataforma se mueve sola a lo largo de un muro con una o varias **trampas dragón** (`TrampaDragon3D`). Los chorros cruzan el
recorrido y no hay hueco para esperar a que se apaguen. La jugadora se sube y se protege con una **barrera alrededor de ella** (ᛝ
sola ya forma el corro que la rodea), que para el haz porque el haz se corta en lo sólido. Variante: ritmo de la trampa con hueco
justo, para quien prefiera cronometrar en vez de protegerse (dos soluciones).
*Verificar / necesita:*
- **No hay plataforma móvil** en el juego: es una pieza nueva.
- Que la barrera **viaje con la plataforma** (hoy lo que se levanta se queda en su casilla del mundo).
- El daño a la jugadora **ya respeta lo sólido**: `jugadora_en_chorro()` usa `largo_chorro_u()`, que corta el chorro en la primera casilla sólida (`trampa_dragon_3d.gd:340-358`). Una barrera entre la boca y la jugadora la protege. Falta comprobar que las casillas del corro cuentan como sólidas para `Lanzador3D.celda_solida`.
- Qué elemento de barrera aguanta el fuego (tierra seguro; agua apagaría el chorro, que también vale).

**X6 · La mecha suspendida** — *dejar un hechizo en el camino de algo que se mueve* · fuego + ᛉ (sin ᛇ) · **B** · *añadido el 21/11 (Pablo, visto en Mages of Mystralia)*
Una balsa con un brasero apagado flota junto a un muelle. Una placa de presión en el muelle la manda lejos mientras alguien la pisa, y
la balsa vuelve al soltarla. La jugadora tiene que estar en la placa para algo (por ejemplo, que la puerta solo se abre si el brasero
llega encendido mientras la placa está libre, o que la placa sujeta una compuerta). Solución: desde la placa, dejar una **bola de
fuego quieta con permanencia** en el sitio por donde pasará el brasero, bajarse y ver cómo se enciende al pasar.
*Verificar / necesita:*
- La misma **plataforma móvil** que X5 (aquí, balsa sobre agua con recorrido fijo y botón que la mueve).
- Que un brasero que **pasa a través** de una zona de fuego viva se encienda (hoy los objetos prenden por contacto con lo que arde, `emite_fuego_por_contacto`; falta comprobarlo con una zona de hechizo y con un objeto en movimiento).
- Que la bola de fuego con ᛉ sin flecha **se quede en el aire** a la altura del brasero y no caiga al agua (el agua la apagaría).
- **Por qué no vale encenderlo directamente** (Pablo, 21/11 — ver también X7, que es el caso contrario: allí SÍ se dispara a través del peligro): se bloquea físicamente el disparo directo con **un muro en medio**. Desde la placa no hay línea libre hasta el brasero (ni flecha de fuego ni haz), así que la única forma es dejar la bola suspendida en el sitio por donde pasará. El muro hace la regla visible sin explicarla.

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

**Ruta de la demo (Pablo, 20/11).**

| Paso | Mapa | Sellos que se tienen | Qué pasa |
|---|---|---|---|
| 1 | Bosque 01 | fuego | |
| 2 | Bosque 02 | fuego | Salida **opcional** a la Cueva: da un glifo opcional (ᚱ, el cofre C6 de `Cueva.txt`). |
| 3 | Monte Sumicio | fuego → **agua** | El encargo de Marimanta da el agua (ya hecho, `encargo_marimanta.gd`). |
| 4 | Bosque 01 → **Ruinas** | fuego, agua → **tierra** | Segunda salida de Bosque 01. Las Ruinas se juegan con **agua** y su cofre final da la **tierra** (Pablo, 20/11). |
| 5 | Monte Sumicio | los tres | Se vuelve de paso; ya no da sello. |
| 6 | Bosque 02 → **Cuevas** | los tres | Segunda salida de Bosque 02. |
| 7 | Cuevas → **Pantano** → **Pantano 01** | los tres | Final de la demo. |

**Lo que esto obliga.** La tabla dice qué elementos tiene cada bioma; la ruta dice **cuándo** se tienen. Donde chocan, manda la ruta:
- **Bosque se juega dos veces.** La primera pasada (pasos 1–2) es **solo fuego**. Sus puzles de agua van en los tramos que se recorren
  al volver: el camino de Bosque 01 a las Ruinas y el de Bosque 02 a las Cuevas. Así el agua abre caminos nuevos en un mapa conocido.
- **La Cueva opcional se juega con fuego.** No tiene tierra todavía. Lo que en `Cueva.txt` pide agua o tierra (el nicho de C2, la lava
  de C3, las estatuas) se queda como **secreto para la vuelta**, que es natural porque en el paso 6 se vuelve a pasar por Bosque 02.
- **Las Ruinas se juegan con agua y terminan dando la tierra.** Así la tierra de la tabla en Ruinas sale sola: se gana en el cofre
  final y **la salida de las Ruinas ya pide tierra**. Se estrena el sello en el mismo sitio donde se consigue, sin volver atrás.
- **Cueva y Cuevas son dos sitios.** La opcional (paso 2) es `Cueva.txt`; las Cuevas del paso 6 son las de tierra y llevan a Pantano.
- El Pantano sigue siendo el único bioma con los tres sellos desde el principio, y es el final.

**Supuesto de lectura.** Leo la tabla como el **tema** de los puzles de cada bioma: sus puzles **giran** en torno a esos elementos.
Un elemento que ya se tiene puede aparecer como apoyo, por ejemplo el fuego en la Cueva opcional (que es lo único que hay en ese
momento). Si la lectura es estricta, la Cueva y las Ruinas pierden los puzles que ya tienen de fuego y agua (ver §5.5).

### 5.1 Bosque · fuego y agua

Ya tiene mucho: braseros, relé, setos, cuerda, molino, tinaja, puente, balanza. Le falta **variedad de verbo**, no cantidad.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| Id | Puzle | Verbo | Elementos | Coste | Pasada | Estado |
|---|---|---|---|---|---|---|
| F13 | Mecha de hierba (§3) | guiar el fuego | fuego (+ agua) | A | 1ª, la versión sin agua; la de proteger con agua en la 2ª | nuevo |
| F14 | Cortina de vapor (§3) | esconderse | fuego sobre suelo mojado | A | 1ª si el suelo ya está mojado (charca) | nuevo |
| Q13 | Brasas en el sendero (§3) | apagar a ritmo | agua | A | 2ª · Bosque 01, camino a Ruinas | nuevo |
| Q14 | El barril que no debe estallar (§3) | apagar antes de usar | agua, luego fuego | A | 2ª · Bosque 02, camino a Cuevas | nuevo |

**La salida a las Ruinas y la segunda salida a las Cuevas se cierran con agua.** Q13 (brasas que cortan el sendero) y Q14 (barril
junto a la boca) hacen de puerta: en la primera pasada se ven y no se pueden pasar.

**Retirar:** tope de 2 puzles de braseros por nivel. Bosque 01 tiene tres seguidos. El escondite de Bosque 02 (muro agrietado) ya
se abre con la explosión de un barril, sin tierra.
*Verificar:* que ningún puzle de agua que ya existe en Bosque 01 y 02 (tinaja, molino, puente) esté en el camino obligatorio de la
primera pasada. Si lo está, se mueve al tramo de vuelta o pasa a ser opcional.

### 5.2 Cueva opcional (fuego) y Cuevas (tierra)

**Cueva opcional, paso 2 (`Cueva.txt`).** Se juega solo con fuego y da ᚱ. Lo que hay ya encaja casi entero: braseros y cristal de C1,
geoda, guardias de C4, fuente de C5 y el cofre C6. Lo que pide otros sellos queda para la vuelta del paso 6:
- C2, el nicho tras la columna: el enlace de la veta es un bloque de tierra.
- C3, la lava: el agua la enfría (el cristal y la geoda son la vía sin agua, si llevan al mismo sitio).
- C1, las estatuas: fuego, agua y tierra. Con ᚱ ya ganado, la pared hueca se abre, y las estatuas esperan a que se tengan los tres.

*Verificar:* que el camino de la entrada al cofre C6 no pida agua ni tierra en ningún punto.

**Cuevas, paso 6 (mapa nuevo o la Cueva Resonante).** Aquí se aprende la tierra, y es lo que conecta con el Pantano.
Ya hay en `Cueva.txt`: veta con hueco para el bloque, columna que tumba el pulso y pared hueca (ᚱ). Faltan los verbos **construir**,
**protegerse** y **pesar**.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| T2 | La cornisa (§3) | subir construyendo | tierra + altura | A | nuevo |
| T4 | Galería de tiro (§3) | protegerse | tierra + ᛁ | A | nuevo |
| T3 | El foso (§3) | cruzar un vacío a ritmo | tierra + ᛒ | A | nuevo, viene de Ruinas: la sima de la cueva es el vacío |
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
*Necesita:* una regla nueva. Hoy la columna cae hacia un lado fijo (`cae=e` en `Cueva.txt`); C8 pide `cae=contra_pulso` (coste B).

### 5.3 Ruinas · agua, y la tierra como premio final (bioma nuevo)

Es un bioma nuevo, así que necesita mapa, escena y arte. Su tema propone **piedra labrada y agua canalizada**: acueductos, cisternas,
suelos rotos y túmulos. Encaja con los puzles de cauces, que aquí se leen como obra humana.

Es la **primera mazmorra con agua** (paso 4): el agua se acaba de ganar en Monte Sumicio y aquí se aprende a fondo. Hay fuego como apoyo.

**Camino principal (agua):**

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| **R2** | **Los caños del acueducto** | elegir adónde va el agua | agua | A | nuevo |
| **R3** | **El reloj de agua** | regar y correr | agua | A | nuevo |
| Q16 | Subir la balsa (§3) | el agua como ascensor | agua | B | nuevo |
| **R4** | **Las lámparas ahogadas** | vaciar para encender | agua + fuego | A/B | nuevo |

**R2 · Los caños del acueducto.** Un manantial alto y tres `pulsador modo=agua` en tres caños, cada uno con su `compuerta`. Solo una
compuerta da a la sala siguiente; las otras dos inundan un foso y lo cierran, o abren un nicho con premio. Se aprende que **el agua
sigue el cauce que se le abre**: antes de regar hay que mirar adónde baja cada caño.

**R3 · El reloj de agua.** Una clepsidra: una cuba que se vacía sola por un agujero. Mientras tiene nivel, un `pulsador modo=agua` tiene
abierta una reja al fondo de la sala. Hay que llenarla regando y llegar a la reja antes de que baje. Con más agua dura más; si la
jugadora riega de más se desborda y no gana tiempo. Es Q13 al revés: aquí el agua es el tiempo.

**R4 · Las lámparas ahogadas.** Dos braseros en una sala hundida, bajo el agua. Hay que vaciarla (regando el `pulsador` del desagüe,
como en R2) para que los braseros asomen, y encenderlos con fuego antes de que la sala se vuelva a llenar desde la fuente. Junta lo que
ya se sabía, el fuego, con lo nuevo.
*Verificar:* que un brasero bajo el agua no se puede encender, y que se enciende cuando el agua baja de `UMBRAL_AGUA`.

**El túmulo y la tierra.** Al fondo de las Ruinas, tras R2–R4 y Q16, un túmulo guarda el cofre legendario con el **sello de tierra**.
Al cogerlo, el camino por el que se vino queda cortado (se hunde un tramo del suelo, o el agua de la cisterna lo cubre), y la única
salida pide la tierra recién ganada. La salida es un tutorial corto, de menos a más:

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| **R5** | **El primer escalón** | levantar para subir | tierra | A | nuevo |
| T1a | Desvío en seco (§3) | cerrar un brazo antes de soltar el agua | tierra, luego agua | A | **hecho en el lab** |
| **R1** | **La cisterna dormida** | vaciar para bajar | tierra + agua | A/B | nuevo, es la salida |
| T5 | Las bocas de la mamoa (§3) | tapar a la vez | tierra | B | opcional, sala lateral (decisión §7) |

**R5 · El primer escalón.** Junto al cofre, un muro de una casilla de alto. Un bloque de tierra delante hace de escalón. Sin enemigos ni
tiempo: solo ver que la tierra levanta suelo. Enseña lo mismo que T2 a pequeña escala; T2 lo amplía en las Cuevas.

**Orden de la salida:** R5 enseña a levantar; T1a, a hacer la presa en seco; R1 lo junta con el agua y con contrarreloj. Después de
R1 se sale al Bosque 01 con los tres sellos.

T1b pasa al Pantano. El foso T3 pasa a las Cuevas.

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

Son dos mapas: **Pantano** (`Pantano.txt`, hoy de muestra) y **Pantano 01**, el final. Propuesta: en Pantano los puzles de uno o dos
sellos (T1b, Q15, P1, X1) y en Pantano 01 los de los tres (X3, P2), con el cierre de la demo.

| Id | Puzle | Verbo | Elementos | Coste | Estado |
|---|---|---|---|---|---|
| T1b | Retener (§3) | sellar la charca antes de que se llene | tierra, luego agua | A | **hecho en el lab**, viene de Ruinas |
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
| Cueva opcional | Braseros de C1 norte | fuego | Se quedan: en el paso 2 el fuego es lo único que hay. | Igual: sin ellos la Cueva opcional no tiene puzle. |
| Cuevas | Reja de fuego de la Cueva Resonante (si es el mapa del paso 6) | fuego | Se queda como apoyo. | Cambiar por veta y receptor de tierra. |
| Cueva opcional | Río de lava de C3 y reja por el basalto | agua | Secreto para la vuelta del paso 6. | El cristal y la geoda lo resuelven sin agua; quitar la vía del agua. |
| Cueva opcional | Estatuas (fuego, agua, tierra) | los tres | Secreto para la vuelta: piden los tres sellos. | Secuencia solo de tierra, lo que no tiene sentido: mejor quitar las estatuas. |
| Bosque 02 | Escondite (muro agrietado) | tierra o explosión | Vale con el barril. | Igual: dejar solo el barril. |
| Bosque 02 | Placa K (bloque) | empuje | Vale. | Vale: no pide tierra. |

---

## 6. Orden de trabajo

En el orden de la ruta, que es también el orden en que hacen falta:

1. **Hecho:** T1a y T1b en el laboratorio y las estatuas sin hielo.
2. **Comprobar la primera pasada** (sin programar): que Bosque 01, Bosque 02 y el camino al cofre C6 de la Cueva se pueden hacer
   **solo con fuego**. Es una prueba de recorrido con el kit recortado; lo que falle dice qué hay que mover.
3. **Bosque, coste A:** F13, F14, Q13 y Q14 en el laboratorio de fuego y agua. Q13 y Q14 son las puertas de la segunda pasada.
4. **Ruinas, agua, coste A:** R2, R3 y R4 en el laboratorio de agua. Después Q16 (coste B).
5. **Laboratorio de tierra nuevo** (`LabPuzlesTierra3D`, con el patrón de los laboratorios de fuego y agua): T2, T3, T4 y C7, coste A.
   Sirve para las Cuevas y la salida de las Ruinas.
6. **Pantano, coste A:** T1b (ya hecho), X1, P1 y Q15.
7. **Reacción «la tierra tapa»** (coste B) para X3 y T5. Después P2, R1 y C8.
8. **Coste C:** T6, si se aprueba.
9. **Mapas:** Ruinas (mapa, escena y arte; antes hace falta decidir su arte, §7), las Cuevas del paso 6 y Pantano 01. Las salidas
   nuevas: Bosque 01 → Ruinas y Bosque 02 → Cuevas, con su puerta de agua.
10. **Progresión:** hoy el kit `demo` da los tres sellos de entrada (`Lanzador3D.PROGRESIONES`). La ruta pide fuego al empezar,
    agua en Sumicio (ya existe, `global.sello.agua`) y tierra en el cofre final de las Ruinas. Los cofres hoy dan glifos (`glifo=`) pero
    no sellos: falta un `sello=tierra` en el cofre que apunte `global.sello.tierra`, como hace `EncargoMarimanta.dar_sello_agua()`.

Cada puzle se monta primero como sala del laboratorio, con botón `!` y placa `@`, y después se pasa al catálogo del generador de mapas
y al nivel.

## 7. Decisiones para Pablo

1. **Lectura de la tabla de biomas:** ¿tema principal, o cada bioma solo con sus elementos? Cambia lo que se hace con §5.5.
2. **Las Cuevas del paso 6:** ¿mapa nuevo, o la Cueva Resonante?
3. **Vuelta a Sumicio (paso 5):** ¿sigue siendo obligatoria, ya sin sello? Si no, de las Ruinas se puede ir directo a Bosque 02.
4. **Ruinas:** ¿qué arte? Por ejemplo piedra labrada con musgo, acueducto, cisterna y túmulo, o el kit de otro bioma reutilizado.
5. ¿La flecha de tierra empuja bloques (T6)?
6. ¿Qué sale de la mamoa (T5): veneno, enemigos o nada?
7. ¿Un tope de 2 puzles de braseros por nivel?
8. ¿Gruta Permanencia y Sala de Empuje entran en la demo? Si entran, con los arreglos de §4.
