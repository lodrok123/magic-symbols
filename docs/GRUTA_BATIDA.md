# La Gruta Batida — la mazmorra que enseña ᛜ antes de darlo

27/10/2026 · contexto JUEGO · **rediseño propuesto, sin construir**.

- **Por qué se rehace:** el primer diseño daba ᛜ desde la entrada, y en esta parte de la historia la jugadora todavía no lo tiene (Pablo, 27/10). Ese diseño no se tira. Queda guardado para una mazmorra posterior que da ᛉ: `docs/GRUTA_PERMANENCIA.md`, con la copia de su mapa en `mapas/GrutaPermanencia.txt`.
- **Hasta que se construya esto,** `PruebaGrutaBatida.tscn` y su autoplay siguen jugando la versión antigua.

---

## 1. La regla: como la Cueva Resonante con el pulso

En la Cueva Resonante el pulso se ve desde la primera sala sin que la jugadora pueda lanzarlo:
- los cristales laten solos;
- golpeados, llevan el elemento del golpe por las vetas.

Cuando el cofre da ᚱ, la jugadora ya sabe qué hace y lo usa enseguida en la pared hueca.

**Aquí, lo mismo con ᛜ.** La gruta está llena de **guardianes**: tótems antiguos con ᛜ tallado que levantan barreras en una marca del suelo. Durante cinco salas la jugadora:
- ve barreras nacer lejos, pesar, parar flechas y helar el agua;
- descubre que el elemento lo pone su golpe;
- comprueba que duran poco.

Todo eso sin poder hacerlo ella. El cofre del santuario da **ᛜ**, y la salida pide levantar una barrera **donde no hay ningún guardián**.

**Lo que la jugadora lleva:** fuego, tierra y hielo con ᚠ flecha, sin ᛜ. Es la misma página de la Gruta antigua, quitando la barrera. La línea (ᛁ) queda pendiente de decidir (§6).

## 2. El átomo nuevo: el guardián

| átomo | pieza del mapa | qué hace | equivale en la Cueva a |
|---|---|---|---|
| **G1 · guardián que late** | `guardian cada=6 elemento=tierra en=x,y` | levanta su barrera sola cada n s, en su marca | E1 cristal que late |
| **G2 · guardián dormido** | `guardian cada=0 en=x,y` | levanta la barrera **del elemento de la flecha que lo golpea** | E2 cristal teñido |
| **M · la marca** | parte del guardián (`en=`, una o varias casillas) | una losa rúnica en el suelo, a ≤ 3 casillas del guardián. Puede estar **tras una reja** o **sobre el agua** | la veta: dice adónde va |

**Lo que lo hace legible:**
- **Es la barrera del jugador, la misma.** El guardián no tiene una barrera propia: llama al Lanzador con la receta `elemento + ᛜ`, con la misma figura, el mismo sonido y los mismos 8,4 s. Así, cuando la jugadora lance la suya, la reconoce al instante.
- **La runa ᛜ del tótem se ilumina** del color del elemento al disparar. Un trazo dorado corre del tótem a la marca y deja ver que la barrera nace donde se apunta, no donde está quien la lanza.
- **Arte:** `totem_runico` para el guardián y `losa_runas_ovalo` para la marca. Las dos piezas ya existen.

## 3. Los usos de la barrera, y quién los enseña

Son los mismos cuatro usos que medía la Gruta antigua (sus números, en `GRUTA_PERMANENCIA.md` §2). La diferencia es quién los hace.

| uso | antes (con ᛜ) | ahora (sin ᛜ) |
|---|---|---|
| **peso a distancia** (tierra) | la jugadora sobre una placa | un guardián sobre la placa |
| **fuego a distancia** | la jugadora tras una reja | un guardián golpeado con fuego, con la marca tras la reja |
| **escudo** (tierra o hielo) | la jugadora frente a los arqueros | un guardián que levanta un muro **a ritmo**, y se cruza a su sombra |
| **puente** (hielo) | la jugadora sobre el agua | un guardián golpeado con hielo, con sus marcas sobre el agua |
| **dura poco** | la placa que se suelta | igual: lo que levanta un guardián se deshace a los 8,4 s |

## 4. La curva, sala a sala

Se usa **la misma geometría** de la Gruta antigua (25 × 19, seis salas, las mismas paredes y aguas). Solo cambian las piezas.

`P` presentar · `D` desarrollar · `C` combinar · `o` opcional.

| | G1 Boca | G2 Rejas | G3 Galería | G4 Charca | G5 Paso batido | G6 Santuario |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| guardián que late | **P** | | **P** (escudo) | | C | |
| guardián dormido (el elemento del golpe) | | **P** ×2 | | **D** (hielo) | **C** | **C** |
| peso a distancia | **P** | **D** | | | | primer uso de ᛜ |
| fuego a distancia | | **P** | | | | **C** |
| escudo | | | **P** | | **C** | |
| puente | | | o (al volver con ᛜ) | **P** | **C** | **C** |
| ᛜ en tu mano | | | | | | **premio → primer uso** |

### G1 · La Boca — *presentar: algo levanta piedra lejos, y pesa*
- **Se ve sin hacer nada:** un guardián de tierra late cada 6 s. Su runa se enciende, el trazo corre hasta la marca y nace un bloque **sobre la placa** del norte. La puerta se abre y, a los 8,4 s, el bloque se deshace y la puerta se cierra.
- **Paso obligado:** cruzar mientras dura. La puerta está a ≤ 5 casillas andando de donde se ve nacer el bloque: da tiempo si se sale enseguida.
- **Se aprende:** la barrera nace lejos de quien la lanza, pesa y no dura.

### G2 · Las rejas — *presentar: el elemento lo pone el golpe*
Es la sala de la captura. **La idea de las rejas se queda,** pero ahora las rejas tapan la **marca**, no la mano de la jugadora:
- Dos guardianes **dormidos** en la sala, a la vista. La marca de uno está tras la reja del **brasero** y la del otro tras la reja de la **placa**.
- Una flecha de fuego directa al brasero se para en la reja.
- **Flecha de fuego al guardián:** la barrera de fuego nace tras la reja y enciende el brasero.
- **Flecha de tierra al otro guardián:** el bloque pisa la placa.
- La puerta del este pide las dos cosas a la vez, como antes, así que hay que encender primero el brasero y dejar la placa para el final. Es la lección «el pulso lleva el elemento del golpe» de C1, ahora con la barrera.
- **Las rejas tienen que dejar ver** el brasero y la placa: modelo de barrotes y sin el rótulo «PUERTA CERRADA». Es el fallo de la captura del 27/10 y aquí es obligatorio arreglarlo, porque la marca tras la reja es justo lo que hay que ver.

### G3 · La galería — *presentar el escudo*
- Un arquero de puesto bate el paso desde el otro lado del agua.
- Un guardián **que late** levanta un muro de tierra cada 6 s entre el arquero y el camino. Las flechas se clavan en él.
- **Paso obligado:** avanzar a su sombra, de muro en muro. Hay dos marcas en fila, de modo que el camino se cruza en dos tramos.
- **Opcional, al volver:** el cofre de la cornisa del arquero, al otro lado del agua, sin ningún guardián que haga el puente. Se alcanza con hielo + ᛜ propio, igual que las estatuas de C1 piden ᚱ.

### G4 · La charca — *desarrollar: el mismo guardián, otro elemento*
- El agua corta la sala y nadie dispara.
- Un guardián dormido tiene **dos marcas sobre el agua**, una por casilla. **Flecha de hielo:** hiela las dos y se cruza durante 20 s.
- Una flecha de tierra levanta dos bloques que se hunden en el agua (si el motor lo hace hoy; se mide con la sonda, §6). La de fuego se apaga sin más. Lo que se aprende: no todo elemento sirve en cada sitio.

### G5 · El paso batido — *combinar escudo y puente*
- El río de dos filas, con dos arqueros en la otra orilla.
- Un guardián dormido pone el **puente** cuando se le golpea con hielo.
- Un guardián que late levanta un **muro** cada 6 s, entre los arqueros y el puente.
- Hay que golpear el hielo **justo después** de un muro y cruzar a su sombra. Si se hace al revés, se cruza bajo las flechas: se puede, con daño.

### G6 · El santuario — *combinar los cuatro, y el premio*
- Se cruza el agua con el puente de un guardián dormido, bajo los dos arqueros de las esquinas.
- En la orilla norte, **un solo guardián dormido con dos marcas**, cada una tras una de las rejas de los braseros. Una flecha de fuego enciende los dos a la vez y se abre la puerta del cofre. Es la versión «combinada» de G2.
- **El cofre legendario da ᛜ** con su secuencia y su pista dorada: «ᛜ: levanta tú la barrera, donde apuntes».

**Primer uso de ᛜ, la salida:** el atajo a G1 se abre mientras su placa está pisada. Junto a la placa hay una marca **sin guardián**: la losa rúnica sola, con el tótem roto en el suelo. La única forma de pisarla desde donde se llega es **tierra + ᛜ**, lanzado por la jugadora. La puerta del atajo queda a ≤ 5 casillas andando, porque aquí no hay ᛉ.

## 5. Claridad: lo que el autoplay comprobará que no pasa

- G1: sin el latido, la puerta no se abre; al deshacerse el bloque, se cierra.
- G2: la flecha de fuego directa no pasa la reja; con el brasero solo, la puerta no se abre; una flecha de tierra al guardián del brasero **no** lo enciende.
- G3 y G5: sin el muro, las flechas aciertan.
- G4: el agua no se pisa sin el puente; la flecha de fuego al guardián no hace puente.
- G6: el atajo no se abre sin ᛜ (con flecha de tierra a la marca vacía tampoco).
- **En ninguna sala antes del cofre hay ᛜ en el libro** (kit sin barrera).

## 6. Por decidir y por medir

**Decisiones:**
- **La línea (ᛁ)** en la página. Sin ᛜ no tiene un uso claro aquí. Propuesta: fuera del kit, y que un guardián de G5 la **muestre** (su marca es una fila de tres casillas, «barrera ancha»), pero que no la dé.
- **El Bosque** vende hoy la barrera (guardabosques, 20 de oro, progresión `bosque`). Si la Gruta va antes y da ᛜ, el guardabosques tiene que vender otra cosa.
- **¿Ves ᛜ en el libro antes de tenerlo?** Como la Cueva con ᚱ: el hueco del glifo sale vacío hasta el cofre. Propuesta: sí, en gris, con la silueta del ᛜ.

**Por medir con una sonda antes de construir** (como en el primer diseño, que lo midió todo):
- si una **flecha de hielo directa** al agua ya hiela una casilla. Si lo hace, G4 y G5 se resuelven sin el guardián, y habría que ensanchar el agua o hacer que corra;
- si una **flecha de tierra** sobre la placa la pisa por sí sola. Si es así, la placa de G2 tiene que quedar fuera del alcance de la flecha, tras la reja, y no solo lejos;
- cuánto tarda en cruzarse andando cada tramo de G3 y G5 con muros de 8,4 s.

## 7. Cambios de motor

| cambio | dónde | por qué |
|---|---|---|
| pieza `guardian` (`cada=`, `elemento=`, `en=`) | nuevo `objetos/guardian_barrera_3d.gd` y su entrada en `escenas/puzle.gd` | el átomo nuevo. Al golpearlo, o al latir, pide al Lanzador la barrera `elemento + ᛜ` en cada casilla de `en=` |
| barrera **lanzada desde fuera** del jugador | `Lanzador3D`: una función pública para levantar un campo con una receta en un punto | hoy la barrera solo nace de un hechizo de la jugadora |
| reja **que deja ver** | modelo de barrotes para `puerta` sin `modelo=llave`, sin rótulo | G2 y G6 dependen de ver la marca tras la reja |
| kit `gruta` | `Lanzador3D.PROGRESIONES`: fuego, tierra, hielo y solo flecha | sin ᛜ hasta el cofre |
| cofre que da ᛜ | `SecuenciaCofreLegendario3D` + su pista | el premio |

El mapa, la escena y el autoplay se rehacen sobre los de la versión antigua, que ya está guardada aparte.
