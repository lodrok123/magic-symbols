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
| 6 | **Cuevas** | los tres | T2, T4, C7, T3, C8, T6 |
| 7 | **Pantano** | los tres | Q15, P1, T1b, X1 |
| 7 | **Pantano 01** | los tres | X3, P2 · la posición final |

En total son **24 puzles**: 2 ya hechos en el laboratorio (T1a, T1b), 18 de coste A o A/B y 4 de coste B o C (Q16, C8, T6, P2), más la posición final por definir.

**Reglas del motor que mandan en los diseños:**
- La tierra no se levanta sobre agua (desde 0.25 u de profundidad). Las presas se preparan **en seco**.
- Un bloque de tierra dura 25 s, pesa 1 en las placas y hace de presa.
- ᛒ tierra: sobre el vacío es una plataforma de 8 s; sobre el suelo, una capa que frena; sobre el agua, nada.
- ᛒ fuego o agua: una trampa que salta al pisarla un enemigo.
- La flecha de tierra empuja bloques y rompe paredes destruibles (Pablo, 20/11; ver T6). Ningún otro hechizo de la demo empuja.
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

### T5 · Las mámoas · *opcional*
**Dónde:** Ruinas, sala lateral de la salida · **Sellos:** tierra · **Coste:** A
- **Qué es una mámoa** (ya existe, `objetos/mamoa_3d.gd`): una tumba antigua, con forma de brocal de pozo, de la que vuelve un
  **mouro espectro** (`enemigos/mouro_espectro_3d.gd`). Mientras está abierta, el mouro se rehace de ella cada vez que lo derriban,
  hasta 3 veces, echando humo por el brocal. Si se tapa (bloque de piedra, tierra construida, plataforma o muro de tierra), deja de
  volver. Si se tapa **con el mouro dentro**, esperando a volver, se sella con él y suelta reliquias.
- **Idea:** **tapar en el momento justo**.
- **Sala:** un cementerio de las ruinas con tres mámoas y un mouro en cada una.
- **Solución:** se derriba un mouro y, mientras su mámoa echa humo, se levanta tierra encima: queda sellado y suelta sus reliquias. Con
  tres a la vez no da tiempo, así que hay que separarlos o usar el bloque de piedra para uno.
- **Si falla:** si se tapa tarde, el mouro ya ha vuelto. Se le vuelve a derribar; al tercer rebrote la mámoa se agrieta y ya no da reliquias.
- **Piezas:** `mamoa`, mouro espectro, bloque de piedra. No hace falta nada nuevo.
- **Verificar:** qué pasa cuando la tierra caduca a los 25 s sobre una mámoa ya sellada.

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

### T6 · La pedrada · *aprobado (Pablo, 20/11)*
**Dónde:** Cuevas · **Sellos:** flecha de tierra · **Coste:** C
- **Regla nueva:** la flecha de tierra **empuja bloques** una casilla y **rompe paredes destruibles**.
- **Idea:** **actuar desde lejos** sobre lo que no se alcanza.
- **Sala:** un canal de agua sin puente. Al otro lado hay un bloque de piedra, una placa y una pared agrietada que tapa un nicho.
- **Solución:** con la flecha de tierra se empuja el bloque hasta la placa, que abre la reja de la salida. La pared agrietada se rompe
  con otra flecha y deja ver un cofre (opcional).
- **Si falla:** si el bloque se empuja contra una esquina, se reinicia con un botón (como en la Sala de Empuje).
- **Necesita:** la mecánica nueva en el lanzador. También arregla E4 de la Sala de Empuje.
- **Verificar:** si la tierra ya rompe los muros agrietados (hoy se abren con tierra o con explosión); si es así, solo falta el empuje.

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
- **Necesita:** que la tierra tape la seta. Se copia la detección de la mámoa (`Mamoa3D._hechizo_encima`), así que es poca cosa (A/B).

### P2 · Balsa entre juncos
**Dónde:** Pantano 01, el canal · **Sellos:** agua, fuego, tierra · **Coste:** B
- **Idea:** **llevar flotando**, con los tres sellos en el orden en que se aprendieron.
- **Sala:** la `balsa` en un canal que lleva a una orilla con un cofre.
- **Solución:** se riega la tinaja para que el canal tenga nivel (agua); se quema el junco seco que la frena (fuego); al llegar, la
  orilla está una casilla más alta y un escalón de tierra en la orilla seca permite subir (tierra).
- **Verificar:** que la balsa se mueve con la corriente o con la jugadora encima.

### La posición final · *por definir*
**Dónde:** Pantano 01 · **Sellos:** los tres
- La demo termina al llegar a **una posición final concreta** de Pantano 01 (Pablo, 20/11). El sitio, lo que se ve allí y el puzle
  que la precede se definen más adelante.
- **Necesita:** una pieza de meta (por ejemplo `fin_demo`) que, al pisarla, cierre la demo.

---

## Glifos por puzle (replanteo, 20/11)

Pablo: «primero busquemos usos y después metemos el glifo». Aquí, para cada puzle, los glifos con los que se puede resolver. Si hay
varias soluciones, mejor. Al final, qué pide cada glifo y cuándo conviene darlo.

**Cómo se comporta cada glifo con cada sello** (lo que dice el código hoy; lo marcado *verificar* no lo he probado):

| Glifo | Fuego | Agua | Tierra |
|---|---|---|---|
| sin glifo | bola en la mano, enciende lo que toca | salpica lo que toca | — (*verificar* si construye delante) |
| Flecha | enciende a distancia (brasero, seto, barril) | riega a distancia (pulsador, tinaja, bancal), apaga una mecha | golpe y empuje; **no construye**. Con T6: empuja bloques y rompe paredes |
| ᛁ Línea | rayo: quema una franja recta | chorro: apaga o moja una franja | con ᛜ, muro más ancho (3 casillas con 3 ᛁ) |
| ᛜ Barrera | aro alrededor de la jugadora: prende lo que la rodea | burbuja que para el primer golpe | **muro o bloque donde se apunta**: es la forma de construir |
| ᛏ Altura | el hechizo sube: llega a lo que está alto | igual | con ᛜ, bloque más alto (1, 2 o 3 niveles) |
| ᚱ Pulso | pulso de fuego al final o a intervalos: enciende en un radio, recorre vetas | pulso de agua en un radio (*verificar* que riega pulsadores) | pulso por las vetas: tumba columnas |
| ᛒ Suelo | trampa que estalla al pisarla un enemigo | trampa | plataforma 8 s sobre el vacío; capa que frena en el suelo; nada sobre el agua |

### Puzle a puzle

| Puzle | Solución principal | Otras soluciones | Glifo que **hace falta** |
|---|---|---|---|
| **F13** Quemar primero | ᛁ fuego: quema la franja en línea recta | flecha casilla a casilla; ᚱ fuego al final de una flecha prende la franja de golpe | ninguno (flecha basta); ᛁ lo hace limpio |
| **F14** Cortina de vapor | flecha de fuego sobre la orilla mojada | ᛁ fuego: una franja de vapor más larga | flecha |
| **Q13** Brasas | ᛁ agua: apaga un tramo entero | flecha de agua, tramo a tramo (más lento, pide ritmo) | ninguno; ᛁ lo hace fácil |
| **R2** Los caños | flecha de agua al pulsador bueno | ᛏ si un pulsador está alto | flecha |
| **R3** Reloj de agua | flecha de agua a la cuba | ᛁ agua: llena más deprisa | flecha |
| **R4** Lámparas ahogadas | flecha de agua al desagüe y flecha de fuego a cada brasero | ᚱ fuego: enciende los dos braseros de un pulso si están a menos de 4 casillas | flecha; ᚱ como atajo |
| **Q16** Balsa ascensor | flecha de agua a las dos tinajas | — | flecha |
| **R5** Primer escalón | tierra + ᛜ delante del muro | — | ᛜ |
| **T1a** Desvío en seco | tierra + ᛜ en el brazo seco, después agua al pulsador | tierra + ᛜ + ᛁ: un muro que tapa un brazo ancho | ᛜ |
| **R1** Cisterna dormida | tierra + ᛜ en el salto del acueducto; flecha de agua al pulsador | — | ᛜ |
| **T5** Las mámoas | flecha de fuego o agua al mouro; tierra + ᛜ encima de la mámoa | tierra + ᛒ (plataforma: cuenta como tapa); bloque empujado; flecha de tierra para empujar el bloque (T6) | ᛜ (o ᛒ) |
| **Q14** El barril | flecha de agua a la mecha; empujar a mano; flecha de fuego | flecha de tierra empuja el barril (T6) | flecha |
| **T2** La cornisa | tierra + ᛜ (nivel 1) y tierra + ᛜ + ᛏ (nivel 2) | ᛏ×3 en un solo bloque alto + otro bajo | ᛏ |
| **T4** Galería de tiro | tierra + ᛜ + ᛁ: muro largo en un lado | tierra + ᛜ casilla a casilla; agua a la `trampa_dragon` | ᛁ |
| **C7** Balanza | tierra + ᛜ sobre la placa B | flecha de tierra para acercar una roca (T6) | ᛜ |
| **T3** El foso | tierra + ᛒ: plataformas sobre el vacío | tierra + ᛜ al fondo si la sima no es honda (*verificar*) | ᛒ |
| **C8** Derrumbe | tierra + ᚱ desde la veta buena | flecha de tierra tumba la columna hacia la sima (T6, si rompe columnas) | ᚱ (o T6) |
| **T6** La pedrada | flecha de tierra al bloque y a la pared | — | flecha (de tierra) |
| **Q15** El bancal | flecha de agua a los bancales; ᛏ o flecha alta por encima de la reja | ᚱ agua: riega varios a la vez (*verificar*) | flecha (+ ᛏ) |
| **P1** Juncos secos | ᛁ agua sobre los juncos del bancal; flecha de fuego a la punta | ᛜ fuego en mitad de los juncos; ᚱ fuego | flecha |
| **T1b** Retener | tierra + ᛜ en la boca del desagüe; flecha de agua a la tinaja | — | ᛜ |
| **X1** Trampas en el vado | ᛒ fuego o agua (trampas) + tierra + ᛒ (capa que frena) | flecha y ᛁ en combate normal; tierra + ᛜ + ᛁ para estrechar el paso | ᛒ |
| **X3** Setas tapadas | flecha de fuego, flecha de agua y tierra + ᛜ encima | tierra + ᛒ como tapa; ᚱ fuego quema dos de un pulso | ᛜ |
| **P2** Balsa entre juncos | flecha de agua a la tinaja; flecha de fuego al junco; tierra + ᛜ en la orilla | ᛁ fuego; flecha de tierra empuja la balsa (T6, *verificar*) | ᛜ |

### Qué pide cada glifo

| Glifo | Lo pide (sin él no sale) | Lo mejora o abre otra solución | Lectura |
|---|---|---|---|
| Flecha | casi todos | — | es el glifo base; se tiene desde el principio |
| ᛜ Barrera | todo lo que construye tierra: R5, T1a, R1, T5, C7, T1b, X3, P2 | P1 | con tierra es **el** glifo de construir; tiene que estar cuando llega la tierra |
| ᛁ Línea | T4 | F13, Q13, P1, T1a | glifo de franjas; útil en Bosque desde el principio |
| ᛏ Altura | T2 | R2, Q15 | uso propio solo en T2: o se le buscan más puzles, o se da justo antes de las Cuevas |
| ᚱ Pulso | C8 | R4, F13, X3, Q15 | encaja como opcional: casi siempre es un **atajo** |
| ᛒ Suelo | T3, X1 | T5, X3 | dos usos propios, los dos tarde (Cuevas y Pantano) |

### Glifos que ya existen y no están en el kit demo

Encajan con estos puzles y dan soluciones nuevas. Los apunto por si se prefiere cambiar alguno del kit:

| Glifo | Qué hace | Dónde daría juego |
|---|---|---|
| ᛉ Permanencia | lo que sale se queda donde nace, +2 s cada uno | R3 (agua que dura en la cuba), R1 (presa que aguanta más), T5 (sellar dos mámoas seguidas) |
| Repetición | el hechizo sale varias veces (hasta 4) | R4 (los dos braseros a la vez), X3 (dos setas), Q15 (los tres bancales) |
| Rebote | el proyectil rebota al acabar | R2 o Q15 (regar un pulsador escondido tras una esquina) |
| Posición | el hechizo nace en el punto señalado | toda la tierra: construir donde se apunta sin ᛜ, lo que dejaría ᛜ solo para muros |
| ᚦ Perforar | atraviesa enemigos o sólidos | T6 (romper dos paredes en fila), X1 |

### Lo que sale de esto

1. **ᛜ con tierra es imprescindible** desde el cofre de las Ruinas. Si la tierra llega en las Ruinas, ᛜ tiene que estar ya o llegar a la
   vez. Hoy la jugadora la gana en el santuario de Bosque 02 (`glifo=barrera`), así que encaja.
2. **ᛏ y ᛒ tienen pocos usos propios** (1 y 2). Hay dos caminos: añadir puzles que los pidan, o darlos justo antes de esos puzles
   (ᛏ antes de T2, ᛒ antes de T3) para que se aprendan en el sitio.
3. **ᚱ funciona como glifo opcional**: abre atajos, y solo C8 lo pide. Si C8 tiene la otra solución (T6), ᚱ puede seguir siendo opcional.
4. **ᛁ merece llegar pronto**: mejora tres puzles del Bosque y de las Ruinas.
5. Si se quiere menos glifos en la demo, **Posición** podría sustituir a ᛜ como «construir donde apunto». Si se quiere más variedad,
   **Repetición** y **ᛉ Permanencia** son los que más soluciones nuevas abren.

---

## Orden de trabajo

1. **Comprobar la primera pasada:** una partida de Bosque 01, Bosque 02 y la Cueva solo con fuego. Lo que se atasque, se mueve.
2. **Laboratorio de fuego y agua:** F13, F14, Q13 y Q14 (Bosque) y R2, R3 y R4 (Ruinas). Todos de coste A.
3. **El cofre con sello:** `sello=tierra`.
4. **Laboratorio de tierra nuevo** (`LabPuzlesTierra3D`): R5, T2, T4, C7 y T3. Todos de coste A.
5. **Pantano, coste A:** Q15, P1, X1 (T1b ya está).
6. **Coste A/B:** T5 (la mámoa ya funciona), X3 (la tierra tapa la seta), R1.
7. **Coste B y C:** la balsa que sigue el nivel (Q16), la columna que cae contra el pulso (C8), P2, y la flecha de tierra que empuja y
   rompe (T6).
8. **Mapas:** Ruinas, las Cuevas del paso 6 y Pantano 01, con las salidas nuevas, la progresión de sellos y la posición final. Las
   Cuevas son un **mapa nuevo**, hecho con el generador de mapas y pulido a mano (Pablo, 20/11).

## Decisiones

**Tomadas (Pablo, 20/11):**
- Las Cuevas del paso 6 son un mapa nuevo: generador de mapas y pulido a mano.
- La flecha de tierra empuja bloques y rompe paredes destruibles (T6).
- La demo acaba en una posición final concreta de Pantano 01, por definir.

**Pendientes:**
1. ¿Dónde se gana ᛒ (suelo)? Lo piden T3 y X1. Propuesta: un cofre en las Cuevas, antes de T3.
2. ¿C8 es obligatorio? Pide ᚱ (pulso), que es el glifo opcional de la Cueva.

**Los glifos de la demo** (kit `demo`):

| Símbolo | Nombre | Id en el código | Qué hace |
|---|---|---|---|
| (flecha) | Flecha | `flecha` | El hechizo viaja en línea recta. |
| ᛁ | Línea | `linea` | Estira el hechizo; sola con un elemento, es un rayo. |
| ᛜ | Barrera | `barrera` | El hechizo rodea a la jugadora y bloquea proyectiles. Con tierra, muro. |
| ᛏ | Altura | `altura` | Eleva el hechizo: 1 = 1 nivel, 3 = 2, 6 = 3. |
| ᚱ | Pulso | `raido` | Suelta un pulso del elemento al final del proyectil o a intervalos. Tumba columnas por las vetas. |
| ᛒ | Suelo | `suelo` | El hechizo se planta en la casilla señalada. Tierra: plataforma sobre el vacío o capa que frena; fuego o agua: trampa. |
