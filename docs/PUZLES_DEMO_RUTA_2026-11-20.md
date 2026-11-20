# Puzles de la demo, en el orden de la ruta (20/11/2026)

Lista propuesta de puzles para la demo, con el concepto de cada uno. Sale de `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` (inventario,
diagnóstico y reglas del motor) y de la ruta que fijó Pablo el 20/11.

## La ruta y los sellos

| Paso | Mapa | Sellos | Puzles nuevos |
|---|---|---|---|
| 1 | Bosque 01 | fuego | F13 |
| 2 | Bosque 02 | fuego | F14 |
| 2b | Cueva *(opcional)* | fuego → **ᚱ** | ninguno: ya está hecha |
| 3 | Monte Sumicio | → **agua** | ninguno: el encargo de Marimanta ya existe |
| 4 | Bosque 01, vuelta | fuego, agua | Q13 (puerta a las Ruinas) |
| 4 | **Ruinas** | fuego, agua → **tierra** | R2, R3, R4, Q16 · cofre de la tierra · R5, T1a, R1 · T5 (opcional) |
| 5 | Monte Sumicio | los tres | ninguno |
| 6 | Bosque 02, vuelta | los tres | Q14 (puerta a las Cuevas) |
| 6 | **Cuevas** | los tres | T2, T4, C7, T3, C8 · T6 (opcional) |
| 7 | **Pantano** | los tres | Q15, P1, T1b, X1 |
| 7 | **Pantano 01** | los tres | X3, P2, P3 (final) |

En total son **25 puzles**: 2 ya hechos en el laboratorio (T1a, T1b), 16 de coste A o A/B y 7 de coste B o C.

**Reglas del motor que mandan en los diseños:**
- La tierra no se levanta sobre agua (desde 0.25 u de profundidad). Las presas se preparan **en seco**.
- Un bloque de tierra dura 25 s, pesa 1 en las placas y hace de presa.
- ᛒ tierra: sobre el vacío es una plataforma de 8 s; sobre el suelo, una capa que frena; sobre el agua, nada.
- ᛒ fuego o agua: una trampa que salta al pisarla un enemigo.
- Ningún hechizo de la demo empuja bloques (salvo T6, si se aprueba).
- Tope de dos puzles de braseros por nivel.

**Cómo leer cada ficha:** *Idea* es el verbo nuevo. *Sala* es lo que ve la jugadora al entrar. *Solución* es lo que tiene que hacer.
*Si falla* es cómo se reintenta sin bloquear. *Piezas* son las que ya existen (si falta algo, va en *Necesita*).

---

## 1 · Bosque 01 · primera pasada (fuego)

Se quedan los puzles de fuego que ya tiene: braseros y relé, setos hasta el barril, cuerda con compuerta y tótems. Sobran braseros:
tiene tres puzles de braseros seguidos y hay que dejarlo en dos.

### F13 · Quemar primero
**Dónde:** Bosque 01, un prado antes del muro agrietado · **Sellos:** fuego · **Coste:** A
- **Idea:** el fuego también sirve para **frenar al fuego**. Es la versión con solo fuego de la mecha de hierba.
- **Sala:** un prado de hierba seca. Al fondo hay un barril junto a un muro agrietado, y en un ramal un cofre de madera. Hay una franja
  estrecha de hierba entre el prado y el cofre.
- **Solución:** primero se prende la franja estrecha. Se quema y deja ceniza, que ya no arde. Después se prende el prado: el fuego
  llega al barril, el barril revienta el muro y el cofre se salva, porque la ceniza corta el paso del fuego.
- **Si falla:** si se prende el prado primero, el cofre arde y se pierde lo que tenía (es un premio, no la llave). El muro se abre igual.
- **Enseña:** el orden importa; el fuego deja huella.
- **Piezas:** hierba (`setos`), `barril`, muro agrietado, `cofre`.
- **Verificar:** que la hierba quemada no vuelve a arder. Si vuelve a arder, la franja es de otra cosa que se consume (paja).

---

## 2 · Bosque 02 · primera pasada (fuego)

Se quedan sus puzles de fuego (braseros, cortafuegos, tronco-puente, tótems, torre que arde, santuario) y el escondite que se abre con
el barril. Lo que pide agua en el camino obligatorio se mueve al tramo de vuelta (*verificar* con una partida solo con fuego).

### F14 · Cortina de vapor
**Dónde:** Bosque 02, un paso abierto junto a una charca · **Sellos:** fuego · **Coste:** A
- **Idea:** **esconderse** con los elementos. Es el primer puzle de sigilo.
- **Sala:** un arquero en una atalaya vigila un paso de hierba corta. El paso pasa al lado de una charca natural que moja las casillas
  de la orilla.
- **Solución:** se lanza fuego sobre la orilla mojada; el vapor tapa la vista del arquero mientras dura y se cruza dentro de él.
- **Si falla:** el arquero dispara y la jugadora vuelve al inicio del paso. No hay muerte segura: el daño es bajo.
- **Enseña:** fuego sobre agua es vapor, y el vapor tapa.
- **Piezas:** arquero, charca, vapor (`Combate3D._ve`).
- **Verificar:** que el vapor de fuego sobre suelo mojado dura lo bastante para cruzar 4 casillas.

---

## 2b · Cueva opcional (fuego, da ᚱ)

Se queda como está (`Cueva.txt`): braseros y cristal de C1, geoda, guardias de C4, fuente de C5 y el cofre C6 con ᚱ. Tres cosas
quedan como **secretos para la vuelta** del paso 6, porque se vuelve a pasar por Bosque 02:
- el nicho de C2, que pide un bloque de tierra en la veta;
- la lava de C3, que pide agua (o el cristal y la geoda);
- las estatuas de C1, que piden fuego, agua y tierra.

*Verificar:* que de la entrada al cofre C6 no hace falta agua ni tierra.

---

## 4 · Bosque 01 · vuelta (agua)

### Q13 · Brasas en el sendero
**Dónde:** Bosque 01, la boca del camino a las Ruinas · **Sellos:** agua · **Coste:** A
- **Idea:** el agua **abre camino**. Es la puerta de las Ruinas.
- **Sala:** un sendero cubierto de setos en llamas que no se apagan. En la primera pasada se ve, y el fuego no sirve de nada.
- **Solución:** con una línea ᛁ de agua se apaga un tramo y se avanza. Las brasas se reavivan a los 6 s si no se han mojado del todo,
  así que se avanza a tramos: apagar, cruzar y apagar el siguiente.
- **Si falla:** si la jugadora se queda en un tramo que se reaviva, recibe daño y retrocede.
- **Enseña:** la línea de agua; el ritmo.
- **Piezas:** `setos` ardiendo con reavivado.
- **Necesita:** que un seto se reavive solo (pequeño, coste A).

---

## 4 · Ruinas (agua, y la tierra al final)

Bioma nuevo: piedra labrada y agua canalizada, con acueductos, cisternas y un túmulo. Es la mazmorra del agua; el fuego es apoyo.
El cofre del fondo da la tierra y **la salida ya la pide**.

### R2 · Los caños del acueducto
**Dónde:** Ruinas, primera sala · **Sellos:** agua · **Coste:** A
- **Idea:** el agua **sigue el cauce que se le abre**: antes de regar hay que mirar adónde baja.
- **Sala:** un manantial alto y tres caños que bajan en abanico. Cada caño tiene una `compuerta` que se abre regando su `pulsador`.
  Un caño llena la cisterna que abre la puerta; otro inunda un foso que corta el camino; el tercero llena un nicho con un premio.
- **Solución:** seguir con la vista el recorrido de cada caño y regar el bueno. El del premio es opcional.
- **Si falla:** si se inunda el foso, se vacía solo en 20 s por un desagüe. Se pierde tiempo, no la partida.
- **Enseña:** leer la sala antes de lanzar; el pulsador de agua.
- **Piezas:** `compuerta`, `pulsador modo=agua`, cauces, cisterna (cuenca con nivel).

### R3 · El reloj de agua
**Dónde:** Ruinas, segunda sala · **Sellos:** agua · **Coste:** A
- **Idea:** el agua **es el tiempo**.
- **Sala:** una cuba de piedra con un agujero en el fondo, que se vacía sola. Mientras tiene nivel, un pulsador tiene abierta una reja
  al otro lado de la sala. Entre la cuba y la reja hay un tramo con obstáculos (escombro o un tótem de fuego).
- **Solución:** se llena la cuba regando y se corre a la reja. Con más agua dura más, pero si se riega de más se desborda y no gana
  tiempo: hay que llenarla justo hasta el borde.
- **Si falla:** la reja se cierra y se vuelve a llenar la cuba.
- **Enseña:** dosificar; el agua guarda un estado durante un tiempo.
- **Piezas:** cuenca con desagüe (como T1b), `pulsador modo=agua`, reja.

### R4 · Las lámparas ahogadas
**Dónde:** Ruinas, sala hundida · **Sellos:** agua + fuego · **Coste:** A/B
- **Idea:** **vaciar para encender**. Junta el sello de siempre, el fuego, con el nuevo.
- **Sala:** una sala más baja que el resto, inundada. Dos braseros asoman apenas bajo el agua. Una fuente la vuelve a llenar poco a poco.
- **Solución:** se riega el pulsador del desagüe (lo enseñó R2) y la sala se vacía. Los braseros quedan en seco y se encienden con
  fuego antes de que la fuente vuelva a cubrirlos. Encendidos los dos, se abre la puerta.
- **Si falla:** si el agua cubre un brasero, se apaga. Se vacía otra vez.
- **Enseña:** el orden entre elementos: primero el agua y después el fuego.
- **Piezas:** `brasero`, `compuerta`, `pulsador modo=agua`, fuente.
- **Verificar:** que un brasero bajo el agua no se enciende y que se apaga si el agua lo cubre.

### Q16 · Subir la balsa
**Dónde:** Ruinas, la cisterna grande, antes del túmulo · **Sellos:** agua · **Coste:** B
- **Idea:** el nivel del agua **como ascensor**.
- **Sala:** una cisterna baja con la `balsa` en el fondo. La puerta del túmulo está en una galería alta, sin escalera.
- **Solución:** se riegan las dos tinajas que alimentan la cisterna; el nivel sube y la balsa sube con él hasta la cota de la galería.
- **Si falla:** si solo se riega una tinaja, el nivel se queda a medias. No hay castigo.
- **Enseña:** el nivel del agua mueve cosas.
- **Piezas:** `balsa`, `tinaja`, cuenca.
- **Necesita:** que la `balsa` siga el nivel del agua (coste B si no lo hace).

### El cofre del túmulo · el sello de tierra
**Dónde:** Ruinas, al fondo del túmulo · **Coste:** A (una opción nueva en el cofre)
- **Idea:** el premio de las Ruinas es la tierra, y el mismo momento cierra la vuelta.
- **Sala:** un cofre legendario con ceremonia. Al abrirlo se gana la tierra, y la galería por la que se vino se hunde: la única
  salida es la de abajo.
- **Necesita:** un `sello=tierra` en el cofre que apunte `global.sello.tierra`, como `EncargoMarimanta.dar_sello_agua()`.

### R5 · El primer escalón
**Dónde:** Ruinas, junto al cofre · **Sellos:** tierra · **Coste:** A
- **Idea:** la tierra **levanta suelo**. Es el primer uso, sin presión.
- **Sala:** un muro de una casilla de alto corta el paso. No hay enemigos ni tiempo.
- **Solución:** un bloque de tierra delante del muro hace de escalón.
- **Si falla:** no se puede fallar; si el bloque cae en mal sitio, se lanza otro.
- **Enseña:** lanzar tierra y subirse encima. T2 lo amplía en las Cuevas.
- **Piezas:** ninguna nueva.

### T1a · Desvío en seco · *hecho en el laboratorio*
**Dónde:** Ruinas, la salida · **Sellos:** tierra, luego agua · **Coste:** A
- **Idea:** la presa se prepara **en seco**, antes de soltar el agua.
- **Sala:** un manantial cerrado por una compuerta con botón. Detrás, una bifurcación seca: un brazo va a un molino que abre la puerta
  y el otro se pierde por un desagüe.
- **Solución:** se tapa con tierra el brazo que se pierde y se abre la compuerta. El caudal entero va al molino.
- **Si falla:** si se suelta el agua sin tapar, ya no se puede tapar (la tierra no se levanta sobre agua). Se cierra la compuerta, el
  brazo se vacía y se vuelve a intentar.
- **Enseña:** la regla más importante de la tierra con el agua.
- **Piezas:** las del laboratorio (`PuzlesAgua.txt`, sala T1a).

### R1 · La cisterna dormida
**Dónde:** Ruinas, la salida · **Sellos:** tierra + agua · **Coste:** A/B
- **Idea:** T1 a lo grande, con **contrarreloj**.
- **Sala:** una cisterna llena tapa la escalera que sube a la salida. La alimenta un canal desde un manantial, y tiene un desagüe con
  compuerta y pulsador de agua. El canal tiene un tramo seco, un salto del acueducto.
- **Solución:**
  1. Si solo se riega el pulsador, la cisterna baja, pero el manantial la vuelve a llenar antes de llegar a la escalera.
  2. Se tapa en seco el salto del acueducto, como en T1a, y después se riega el pulsador.
  3. La cisterna se vacía, se cruza el fondo y se sube la escalera antes de que la presa caduque a los 25 s.
- **Si falla:** la cisterna se vuelve a llenar y saca a la jugadora flotando a la orilla.
- **Enseña:** combinar dos sellos y medir el tiempo.
- **Verificar:** los tiempos de vaciado y llenado con la simulación.

### T5 · Las bocas de la mamoa · *opcional*
**Dónde:** Ruinas, sala lateral de la salida · **Sellos:** tierra · **Coste:** B
- **Idea:** **tapar a la vez**.
- **Sala:** una mamoa con tres bocas que sueltan algo dañino. En la cima, un cofre.
- **Solución:** la tierra tapa una boca durante 25 s. Hay que taparlas las tres a la vez: un bloque de piedra empujado a mano para una
  y tierra para las otras dos, de la más lejana a la más cercana.
- **Si falla:** la primera boca se destapa antes de tapar la tercera; se empieza de nuevo.
- **Piezas:** `mamoa`, bloque de piedra.
- **Necesita:** la reacción «la tierra tapa» (coste B) y decidir qué sale de la mamoa.

---

## 6 · Bosque 02 · vuelta (puerta a las Cuevas)

### Q14 · El barril que no debe estallar
**Dónde:** Bosque 02, la boca de la segunda cueva · **Sellos:** agua, luego fuego · **Coste:** A
- **Idea:** **invertir el verbo**: el agua controla el fuego.
- **Sala:** la boca de la cueva está tapada por un muro agrietado. Junto a una urna de cristal (un cofre frágil) hay un barril con la
  mecha encendida, que se reenciende sola cada vez que se pasa (un tótem cercano lo prende).
- **Solución:** se apaga la mecha con agua, se empuja el barril hasta el muro y se enciende allí con fuego.
- **Si falla:** si estalla junto a la urna, la urna se rompe y se pierde su premio. El barril vuelve a aparecer.
- **Enseña:** el agua también sirve para preparar el fuego.
- **Piezas:** `barril` (la mecha se apaga con agua), muro agrietado, cofre frágil.

---

## 6 · Cuevas (tierra)

Aquí se aprende la tierra a fondo: construir, protegerse y pesar. Luego viene ᛒ.

### T2 · La cornisa
**Dónde:** Cuevas, primera sala · **Sellos:** tierra + altura · **Coste:** A
- **Idea:** **construir para subir**. Es R5 con orden.
- **Sala:** un rellano a dos alturas con un cofre, sin escalera.
- **Solución:** un bloque de altura 1 y, al lado, uno de altura 2. Si se levanta primero el alto, no se puede subir a él.
- **Si falla:** los bloques caducan a los 25 s y se vuelve a intentar.
- **Piezas:** ninguna nueva.

### T4 · Galería de tiro
**Dónde:** Cuevas, un pasillo · **Sellos:** tierra + ᛁ · **Coste:** A
- **Idea:** **protegerse construyendo**.
- **Sala:** un pasillo con dos `trampa_flechas` en paredes opuestas y desfasadas.
- **Solución:** un muro de tierra en línea tapa solo un lado. Hay que elegir dónde levantarlo y avanzar en el hueco de la otra trampa.
- **Variante:** una `trampa_dragon` que se apaga con agua o se tapa con tierra.
- **Piezas:** `trampa_flechas`, `trampa_dragon`.

### C7 · La balanza de la mina
**Dónde:** Cuevas, sala de la vagoneta · **Sellos:** tierra · **Coste:** A/B
- **Idea:** **pesar con lo que hay**.
- **Sala:** una reja con dos placas de peso: A pide 3 y B pide 1. Hay una roca mediana (2) y una pequeña (1). No hay ningún bloque de 3.
- **Solución:** la mediana y la pequeña a la placa A (suma 3), y un bloque de tierra en la B (pesa 1) **al final**, ya junto a la reja,
  porque dura 25 s.
- **Si falla:** si se pone la tierra primero, caduca antes de colocar las rocas. Se vuelve a lanzar.
- **Piezas:** placas de peso, rocas.
- **Verificar:** que la tierra se levanta sobre una placa y que dos rocas suman en la misma casilla.

### T3 · El foso
**Dónde:** Cuevas, la sima · **Sellos:** tierra + ᛒ · **Coste:** A
- **Idea:** **cruzar un vacío a ritmo**. Enseña ᛒ.
- **Sala:** una sima de tres casillas.
- **Solución:** cada plataforma ᛒ dura 8 s, así que no se puede tender el puente entero: se lanza una, se sube, se lanza la siguiente.
- **Si falla:** se cae a una galería de abajo que vuelve al principio por una rampa.
- **Piezas:** ninguna nueva.

### C8 · Derrumbe dirigido
**Dónde:** Cuevas, junto a la sima · **Sellos:** tierra + ᚱ · **Coste:** B
- **Idea:** **elegir de dónde sale el pulso**.
- **Sala:** una columna junto a otra sima. Dos vetas llegan a ella, una por cada lado.
- **Solución:** el pulso tumba la columna en sentido contrario al de su llegada. Desde la veta buena cae sobre la sima y hace de puente.
  Desde la otra cae contra la pared.
- **Si falla:** la columna caída contra la pared se levanta al reiniciar la sala.
- **Necesita:** `cae=contra_pulso` (hoy la columna cae a un lado fijo, `cae=e`).
- **Nota:** ᚱ es el glifo opcional de la Cueva. Si no se tiene, C8 tiene que tener otra salida o ser opcional.

### T6 · Pedrada que empuja · *opcional, si se aprueba*
**Dónde:** Cuevas · **Sellos:** flecha de tierra · **Coste:** C
- **Idea:** **empujar desde lejos**.
- **Sala:** un bloque al otro lado de un canal, y una placa en esa orilla.
- **Solución:** la flecha de tierra mueve el bloque una casilla, hasta la placa.
- **Necesita:** la mecánica nueva.

---

## 7 · Pantano (los tres sellos)

La tierra trabaja en las islas y orillas secas. Aquí se combinan los sellos y se usa ᛒ en combate.

### Q15 · El bancal
**Dónde:** Pantano, la entrada · **Sellos:** agua · **Coste:** A/B
- **Idea:** **hacer crecer**.
- **Sala:** tres bancales secos. Uno está detrás de una reja baja.
- **Solución:** se riegan los tres; al del fondo se le llega con una flecha de agua que pasa por encima de la reja. Al germinar los
  tres, se abre el vivero (o crece un puente de raíces).
- **Piezas:** `bancal`.

### P1 · Juncos secos
**Dónde:** Pantano, junto al bancal · **Sellos:** fuego + agua · **Coste:** A
- **Idea:** **guiar el fuego y proteger** lo cultivado. Es F13 con consecuencia.
- **Sala:** una enredadera cierra el paso al otro lado de un brazo de agua. Un cinturón de juncos secos rodea el brazo y llega hasta
  ella, pero pasa junto al bancal de Q15.
- **Solución:** primero se mojan los dos juncos que tocan el bancal, después se prenden los juncos y el fuego llega a la enredadera.
- **Si falla:** el bancal se quema y hay que volver a regarlo para que vuelva a germinar.
- **Piezas:** `setos`, enredadera, `bancal`.

### T1b · Retener · *hecho en el laboratorio*
**Dónde:** Pantano, una charca con desagüe · **Sellos:** tierra, luego agua · **Coste:** A
- **Idea:** recordar la presa en seco, ahora para **guardar** agua.
- **Sala:** una cuenca seca con un desagüe y una puerta de nivel.
- **Solución:** se tapa la boca del desagüe con tierra y después se riega la tinaja. La puerta se abre mientras la presa aguante.
- **Piezas:** las del laboratorio (`PuzlesAgua.txt`, sala T1b).
- **Riesgo:** solo hay unos 9 s de margen. En el nivel conviene una tinaja más rápida.

### X1 · Trampas en el vado
**Dónde:** Pantano, un paso estrecho · **Sellos:** fuego o agua + ᛒ, tierra + ᛒ · **Coste:** A
- **Idea:** **preparar el combate**. Enseña ᛒ como trampa.
- **Sala:** una patrulla de goblins cruza un vado camino de un cofre, y la jugadora llega antes desde una loma.
- **Solución:** se plantan trampas ᛒ de fuego o agua en el paso y una capa de tierra ᛒ los frena encima de ellas. El cofre se abre al
  vaciar el paso.
- **Si falla:** se lucha a la antigua usanza.
- **Piezas:** goblins, `vigia`.

---

## 7 · Pantano 01 (final)

### X3 · Setas tapadas
**Dónde:** Pantano 01, el claro de las setas · **Sellos:** tierra, fuego, agua · **Coste:** B
- **Idea:** **repartir tres elementos** contra un mismo problema.
- **Sala:** tres setas de veneno sueltan gas cada pocos segundos. No da tiempo a quemarlas todas.
- **Solución:** una se quema, otra se atasca con agua y la tercera se sella con un bloque de tierra encima.
- **Piezas:** las setas de F12 (`respiradero`).
- **Necesita:** la reacción «la tierra tapa», la misma de T5.

### P2 · Balsa entre juncos
**Dónde:** Pantano 01, el canal · **Sellos:** agua, fuego, tierra · **Coste:** B
- **Idea:** **llevar flotando**, con los tres sellos en el orden en que se aprendieron.
- **Sala:** la `balsa` en un canal que lleva a una orilla con un cofre.
- **Solución:** se riega la tinaja para que el canal tenga nivel (agua); se quema el junco seco que la frena (fuego); al llegar, la
  orilla está una casilla más alta y un escalón de tierra en la orilla seca permite subir (tierra).
- **Verificar:** que la balsa se mueve con la corriente o con la jugadora encima.

### P3 · El faro del pantano · *cierre de la demo*
**Dónde:** Pantano 01, la isla del faro · **Sellos:** los tres · **Coste:** B
- **Idea:** **el último fuego**: encender el faro cierra la demo.
- **Sala:** un faro de piedra en una isla seca, en medio del agua. Su linterna está apagada y su escalera, derrumbada.
- **Solución:**
  1. Se llega a la isla en la balsa (lo de P2, ahora sin ayuda).
  2. Se sube con escalones de tierra y altura (lo de T2) por la escalera rota.
  3. Arriba hay un brasero bajo una cubierta de musgo empapado: hay que secarlo antes con fuego, y después prender la linterna.
- **Al encenderse:** la luz barre el pantano, la niebla se retira y se ve el camino de vuelta. Fin de la demo.
- **Piezas:** `balsa`, `brasero`, musgo (`setos` húmedos).
- **Necesita:** una pieza «faro» con su luz (arte), y que el brasero se seque con fuego.

---

## Orden de trabajo

1. **Comprobar la primera pasada:** una partida de Bosque 01, Bosque 02 y la Cueva solo con fuego. Lo que se atasque, se mueve.
2. **Laboratorio de fuego y agua:** F13, F14, Q13 y Q14 (Bosque) y R2, R3 y R4 (Ruinas). Todos de coste A.
3. **El cofre con sello:** `sello=tierra`.
4. **Laboratorio de tierra nuevo** (`LabPuzlesTierra3D`): R5, T2, T4, C7 y T3. Todos de coste A.
5. **Pantano, coste A:** Q15, P1, X1 (T1b ya está).
6. **Coste B:** la reacción «la tierra tapa» (T5, X3), la balsa que sigue el nivel (Q16), la columna que cae contra el pulso (C8), P2,
   R1 y P3.
7. **Mapas:** Ruinas, las Cuevas del paso 6 y Pantano 01, con las salidas nuevas y la progresión de sellos.

## Decisiones

1. ¿Dónde se gana ᛒ (suelo)? Lo piden T3 y X1. Propuesta: un cofre en las Cuevas, antes de T3.
2. ¿C8 es obligatorio? Pide ᚱ, que es opcional en la Cueva.
3. ¿Las Cuevas del paso 6 son un mapa nuevo o la Cueva Resonante?
4. ¿Qué sale de la mamoa (T5)?
5. ¿T6 (la flecha de tierra empuja)?
6. ¿El final es un faro (P3) u otra cosa?
