# La Gruta Batida — la mazmorra que enseña ᛜ antes de darlo

28/10/2026 · contexto JUEGO · **construida, solo con fuego**. El autoplay la recorre de principio a fin con 76 comprobaciones y 0 fallos.

- **Mapa:** `mundo/datos_nivel/mapas/GrutaBatida.txt`.
- **Escena:** `escenas/PruebaGrutaBatida.tscn`, con el kit `gruta`.
- **Autoplay:** `herramientas/escenario_gruta_batida.gd`. Recorre el nivel a pie y con hechizos reales, y después recarga el nivel.
- **Fotos:** `herramientas/captura_gruta_batida.gd`, con ventana. Se guardan en `docs/capturas/gruta_batida/`.
- **De dónde viene:**
  - El primer diseño daba ᛜ desde la entrada. Queda guardado para una mazmorra posterior que dé ᛉ: `docs/GRUTA_PERMANENCIA.md` y `mapas/GrutaPermanencia.txt`, con el kit `barrera`.
  - El rediseño del 27/10 con tótems usaba tierra (peso) y hielo (puente).
  - Pablo pidió el 28/10 **«la barrera como concepto, sin más elementos que el fuego»**. Este documento es esa versión.

## 1. La regla

Es la misma regla que la Cueva Resonante sigue con el pulso: **primero se ve el glifo funcionando sin tenerlo, y al final el cofre lo da.**

- **Lo que lleva la jugadora:** solo **fuego + ᚠ flecha**. Una página con dos huecos, del primer libro. No lleva ningún otro elemento.
- **Quién enseña la barrera:** los **guardianes**, tótems antiguos con ᛜ tallado. Levantan la barrera de fuego en sus **marcas**, unas losas rúnicas del suelo.
- **El premio:** el cofre del santuario da **ᛜ**.
- **La salida:** pide levantarla **una misma**, en una marca cuyo tótem está roto en el suelo.

### Lo que hace la barrera de fuego (medido el 28/10 con una sonda)

| | flecha de fuego | barrera de fuego (de un tótem o de la jugadora) |
|---|---|---|
| alcance | 2 casillas; se para en la pared, la reja o el tótem | nace donde se apunta, hasta 3 casillas de la jugadora (la de un tótem, en su marca, a cualquier distancia) |
| una reja | se para en ella y **no** enciende lo de detrás | **nace al otro lado** y lo enciende |
| lo que toca | lo que golpea en el camino; al pararse deja ~3 s de llama en la casilla de antes | ~3 s de llama en su casilla: enciende braseros, quema cuerdas y prende a quien esté encima (48 de daño más la quemadura) |
| escudo | — | **no sirve**: la solidez del fuego dura 2,4 s y las flechas del arquero pasan igual (12 de daño con ella y sin ella) |

Como el fuego no hace de escudo ni pesa, las salas no usan el escudo ni la placa. Usan las tres cosas que sí hace:

1. **nace donde marca**, también tras una reja;
2. **alcanza lo que la flecha no alcanza**;
3. **arde bajo los pies** de quien está en la marca.

## 2. El átomo nuevo: el guardián

`; pieza <id> guardian <x> <y> en=<casillas> [cada=<s>] [cerca=<casillas>] [elemento=fuego] [roto=si]`. El código está en `objetos/guardian_barrera_3d.gd` (`GuardianBarrera3D`).

| variante | qué hace |
|---|---|
| **que late** (`cada` > 0) | levanta su barrera solo cada `cada` s; con `cerca`, solo si la jugadora está a esa distancia o menos (para que lo vea) |
| **dormido** (`cada` = 0) | lo despierta un hechizo que le da; la barrera lleva el elemento de ese hechizo, que aquí siempre es fuego |
| **roto** (`roto=si`) | tumbado junto a su marca, no hace nada y no bloquea: es el sitio de la barrera de la jugadora |

- **Es la barrera del jugador, la misma.** El tótem llama a `Lanzador3D.lanzar_receta` con la receta `fuego + ᛜ`, en el centro de cada marca. Tiene la misma figura, el mismo sonido y los mismos segundos, así que la jugadora la reconoce cuando la lance ella.
- **Se lee así:** al golpearlo, el tótem se enciende del color del elemento y un **hilo de luz** (`HiloLuz3D`) corre hasta cada marca. La barrera nace cuando el hilo llega, a los 0,45 s. Después el hilo se queda tenue y deja dicho qué tótem manda en qué marca.
- **Enfriamiento:** 1,2 s entre dos barreras.
- **Arte:** `totem_runico` para el tótem y `losa_runas_ovalo` para la marca. Las dos piezas ya existían.

## 3. La curva, sala a sala

`P` presentar · `C` combinar.

| | G1 Boca | G2 Rejas | G3 Galería | G4 Charca | G5 Paso batido | G6 Santuario |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| tótem que late | **P** | | | | | |
| tótem dormido (un golpe lo despierta) | | **P** | ✓ | ✓ | C (dos) | C (dos, uno con dos marcas) |
| nace tras la reja | **P** (se ve) | **P** (se hace) | | | | **C** + primer uso de ᛜ |
| arde bajo los pies (trampa) | | | **P** | | **C** (dos arqueros) | |
| alcanza lo que la flecha no alcanza (cuerda → puente) | | | | **P** | **C** | **C** |
| ᛜ en tu mano | | | | | | **premio → primer uso** |

### G1 · La Boca — *algo levanta fuego lejos, tras una reja*
- Hay un tótem **que late** cada 5 s, en cuanto la jugadora está a 4 casillas. Su marca está tras la reja de un brasero.
- Sin hacer nada, nace la barrera, se enciende el brasero y se abre la puerta del norte.

### G2 · Las rejas — *el tótem dormido; la flecha no pasa la reja*
- Dos braseros, cada uno tras su reja, y dos tótems dormidos con la marca tras cada reja.
- La flecha al brasero se para en la reja. Una flecha a cada tótem enciende su brasero.
- Con un solo brasero encendido, la puerta sigue cerrada.

### G3 · La galería — *el fuego nace bajo los pies*
- Un arquero de puesto, al otro lado del agua y fuera del alcance de la flecha, bate el paso: 12 de daño en 6 s.
- La marca del tótem está en su cornisa. **Dos golpes** al tótem lo tumban, y la puerta del este se abre.

### G4 · La charca — *lo que la flecha no alcanza*
- La cuerda que sostiene el puente plegado está en la otra orilla, a 3 casillas. La flecha, de 2 casillas, cae al agua antes de llegar.
- La marca del tótem está en la cuerda: arde, se rompe y las losas del puente suben una a una.

### G5 · El paso batido — *combinar trampa y puente*
- Dos arqueros en la otra orilla. Un tótem tiene una marca bajo **cada** arquero: dos golpes tumban a los dos.
- Otro tótem quema la cuerda del puente. Se puede cruzar bajo las flechas o quemarlos antes.

### G6 · El santuario — *combinar, el premio y el primer uso*
- El puente de un tótem, con la cuerda en la orilla norte.
- En la orilla norte, **un tótem con dos marcas**, una tras cada reja de los braseros: un golpe enciende los dos y se abre la puerta del cofre.
- **El cofre legendario da ᛜ.**
- **La salida:** el atajo a G1, en (8,13), se abre con el brasero de la esquina, que está tras su reja.
  - A su pie hay una marca **sin tótem**: el tótem está roto en el suelo.
  - La flecha no pasa la reja. Hay que levantar la barrera de fuego **una misma**: fuego + ᛜ apuntando a la marca.

### Lo que comprueba el autoplay que NO pasa (claridad)
- **G2, G6 y el atajo:** la flecha directa al brasero tras la reja no lo enciende.
- **G2:** con un brasero solo, la puerta no se abre.
- **G4, G5 y G6:** la flecha a la cuerda no llega.
- **G4:** el agua no se pisa sin el puente.
- **El tótem roto** no responde ni bloquea.
- **Antes del cofre** no hay ᛜ en el libro, y la jugadora no tiene ningún elemento aparte del fuego.
- **Al recargar:** puertas, puentes y cofre siguen resueltos y los arqueros vencidos no vuelven.

## 4. Cambios de motor (28/10)

| cambio | dónde |
|---|---|
| pieza `guardian` (el tótem, sus marcas y los hilos) | nuevo `objetos/guardian_barrera_3d.gd`; tipo nuevo en `escenas/puzle.gd` (señal `levanta`, acción `levantar`) |
| pieza `puente` (losas que suben del agua y vuelven la casilla «b», pisable), que tiende una `cuerda` o una regla | `escenas/puzle.gd` con `PuenteReactivo3D` (señal `tendido`, condición `tendido` / `plegado`, acción `tender`) |
| reja de barrotes que **deja ver**, sin rótulo (`puerta modelo=reja`), y `giro=` para girar una puerta a mano | `Puzle3D.PuertaPuzle._poner_reja` |
| la llama de una barrera de fuego **prende lo inflamable** de su casilla aunque no sea un `Reactivo3D` (la cuerda, un barril) | `HechizoVivo.pulso_plasma` (el grupo `flammable3d`, sin repetir golpes) |
| kit `gruta`: fuego y flecha | `Lanzador3D.PROGRESIONES` |
| el cofre da ᛜ | `cofre … glifo=barrera` (ya existía) |

## 5. Por decidir (Pablo)

- **¿Se entiende sin texto?** Hay que mirar las fotos y jugarlo: el tótem se enciende, el hilo corre y la llama nace tras la reja. Las marcas que caen bajo un brasero o un arquero quedan tapadas: solo se ven por el hilo.
- **El hilo en reposo:** hoy aparece con el primer golpe y después se queda tenue. Si conviene que se vea **antes** (para saber qué tótem va con qué marca), es una línea.
- **El tótem entero se ilumina** al levantar, no solo la runa. Si se quiere solo la runa, hace falta una máscara de emisión en el modelo.
- **La dificultad de G3 y G5:** dos golpes por arquero. Si sobra o falta, se toca el daño del fuego o la vida del arquero de puesto.
- **El Bosque vende hoy la barrera** (el guardabosques, por 20 de oro). Si la Gruta va antes y da ᛜ, el guardabosques tendrá que vender otra cosa.
- **¿Se ve ᛜ en el libro antes de tenerlo?** Propuesta: el hueco en gris con su silueta, como ᚱ en la Cueva.
- **Un opcional con ᛜ al volver:** no hay ninguno todavía. Propuesta: un tercer brasero tras una reja en G2, sin tótem, que abra un cofre pequeño.
