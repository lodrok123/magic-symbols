# La Gruta de la Permanencia — la barrera ya aprendida (idea guardada)

27/10/2026 · contexto JUEGO · **guardada para una mazmorra posterior**.

Era el primer diseño de la Gruta Batida. Se aparta porque da ᛜ por sabido en un sitio donde la jugadora todavía no lo tiene (Pablo, 27/10: «conserva la idea, no es mala, pero no para esta parte»). Sirve tal cual para una mazmorra **después** de ganar ᛜ: desarrolla los cuatro usos de la barrera y da **ᛉ permanencia**. El nuevo diseño de la Gruta Batida, que enseña ᛜ antes de darlo, está en `docs/GRUTA_BATIDA.md`.

- **Copia del mapa:** `mundo/datos_nivel/mapas/GrutaPermanencia.txt` (idéntica al mapa construido el 27/10).
- Mientras no se construya la Gruta nueva, `escenas/PruebaGrutaBatida.tscn` y `herramientas/escenario_gruta_batida.gd` siguen jugando **esta** versión.
- **Pendiente si se recupera:** las rejas son losas opacas con el rótulo «PUERTA CERRADA» y tapan la placa y el brasero que hay detrás (captura del 27/10). Necesitan un modelo de barrotes que deje ver, sin rótulo de puerta. Quizá también la pista en el rótulo de G2: «Lo que no alcanza la flecha, lo alcanza la barrera».

A partir de aquí, el texto original.

- **Mapa (editable):** `mundo/datos_nivel/mapas/GrutaBatida.txt`
- **Escena:** `escenas/PruebaGrutaBatida.tscn` (nivel `GrutaBatida` en `Niveles.ESCENAS`, kit `barrera`)
- **Autoplay:** `herramientas/escenario_gruta_batida.gd` (84 comprobaciones, 0 fallos, ~3,5 min de juego)

Es una cueva nueva de seis salas (25 × 19) cuyo tema es **ᛜ barrera**. No usa cristales ni nada del pulso. El arte es el kit genérico de cueva: paredes, `placa_presion_cueva`, `brasero_cueva`, puertas de llave, jarrones, estalagmitas, rocas, musgo, helechos y raíces. Al final hay un cofre legendario que da **ᛉ permanencia**, «la barrera que dura», que se usa en la salida.

---

## 1. La idea

El ᛜ hace dos cosas que ningún otro glifo hace:

1. **nace donde apuntas** (hasta 3 casillas), también detrás de una reja que para las flechas;
2. **es sólido**: para proyectiles y pesa.

Lo que hace al llegar lo decide el elemento. Es la misma pregunta que los ecos de EoW, «¿qué pongo y dónde?», pero con una sola herramienta. Así que el nivel no enseña «la barrera» en general: enseña **cuatro usos** y los combina.

Para que cada puzle se lea como «¿dónde levanto la barrera, y de qué?», el kit `barrera` (`Lanzador3D.KITS`) deja solo **fuego, tierra y hielo** y **flecha, barrera y línea**. Sin agua, viento ni rayo no hay soluciones de otra familia que tapen la lección.

## 2. Los átomos (medidos, no supuestos)

Antes de diseñar pasé una sonda por cada combinación, en una sala de prueba que ya he borrado. Esto es lo que hay en el motor hoy:

| átomo | receta | qué hace | medida |
|---|---|---|---|
| **B1 · Escudo** | tierra o hielo + ᛜ (+ ᛁ) | para las flechas de los arqueros (`Lanzador3D.solidez_para`) | 0 de daño en 8 s, frente a 12 sin ella |
| **B2 · Peso a distancia** | tierra + ᛜ | el bloque nace en el punto apuntado (también tras una reja) y **pisa una placa** | aguanta **8,4 s**; con ᛜᛜ 9,3 s, con ᛉ 10,4 s, con ᛉᛉ **12,3 s** |
| **B3 · Fuego a distancia** | fuego + ᛜ | nace tras la reja y **enciende el brasero** al que una flecha no llega | al momento |
| **B4 · Puente** | hielo + ᛜ | hiela el agua donde se apunta: **se pisa** durante 20 s | 1 casilla por barrera |
| **B5 · Puente + escudo** | hielo + ᛜ + ᛁ | las dos cosas a la vez | cruzar G5: 0 de daño |
| **T · Tiempo** | ᛉ | +2 s a lo que dura la barrera | la jugadora anda a ~0,7 casillas/s |

**Lo que no funciona hoy (descartado del diseño):**
- agua + ᛜ no activa un pulsador de agua (`pulsador modo=agua`);
- agua + ᛜ no apaga un muro de fuego `B`;
- el hielo sobre suelo no bloquea (es escarcha);
- con fuego + ᛜ como escudo, la jugadora recibió un flechazo en 6 s (queda sin concluir).

## 3. La curva, sala a sala

`P` presentar · `D` desarrollar · `C` combinar · `o` opcional.

| | G1 Boca | G2 Rejas | G3 Galería | G4 Charca | G5 Paso batido | G6 Santuario |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| placa que se suelta | **P** | D | | | | C (atajo) |
| B2 peso a distancia | **P** | **D** (tras reja) | | | | C (atajo) |
| B3 fuego a distancia | | **P** | | | | **C** ×2 |
| B1 escudo | | | **P** | | **C** | C |
| B4 puente de hielo | | | o (cofre de la cornisa) | **P** | **C** | **C** |
| T ᛉ permanencia | | | | | | **premio → primer uso** |

### G1 · La Boca — *presentar la placa y lo poco que dura*
Pisar la placa abre la puerta del norte, pero al bajarse se cierra antes de llegar. Tierra + ᛜ sobre la placa la mantiene pisada ~8 s: lo justo. **Se aprende:** la barrera pesa y no dura.

### G2 · Las rejas — *desarrollar el peso y presentar el fuego a distancia*
Una placa y un brasero, cada uno tras su reja.
- La flecha de fuego se para en la reja: **fuego + ᛜ** nace al otro lado y enciende el brasero.
- **Tierra + ᛜ** pisa la placa que no se puede pisar.

La puerta pide las dos cosas a la vez y se cierra cuando la placa se suelta.

### G3 · La galería — *presentar el escudo*
Un arquero de puesto, al otro lado del agua y fuera del alcance de las flechas de la jugadora, bate el paso: 12 de daño en 7 s a quien se queda quieta. Tras una tierra + ᛜ + ᛁ, nada. Se puede cruzar aguantando, porque es la presentación. En la cornisa del arquero hay un cofre para quien vuelva sabiendo hacer puentes.

### G4 · La charca — *presentar el puente*
El agua corta la sala y nadie dispara. Hielo + ᛜ donde apuntas hiela la casilla y se pisa; son dos casillas, así que hacen falta dos barreras.

### G5 · El paso batido — *combinar escudo y puente*
Un río de dos filas con dos arqueros de puesto en la otra orilla (12 de daño en 6 s si se espera en la orilla). **Hielo + ᛜ + ᛁ es a la vez puente y escudo**: se cruza sin daño, y en su orilla se les tumba a flechazos.

### G6 · El santuario — *combinar los cuatro*
- Se cruza el agua sobre hielo bajo dos arqueros en las esquinas, que se tumban al llegar o se aguantan tras un escudo.
- Desde la orilla norte, **fuego + ᛜ tras cada reja** enciende los dos braseros, y se abre la puerta del cofre.
- El cofre legendario da **ᛉ** con su secuencia y su pista dorada: «ᛉ junto a la barrera: dura más».

**Primer uso de ᛉ, la salida:** el atajo a G1 solo se abre mientras su placa está pisada.
- **Sin ᛉ**, andando, la barrera se deshace antes de llegar y la puerta se cierra delante. El autoplay lo comprueba: se cierra a los 8,3 s.
- **Con ᛉ ᛉ** da tiempo: se cruza a los 9,7 s de abrirse.

## 4. Claridad

Como en la Cueva Resonante, cada sala comprueba también **lo que no debe pasar** (`[legible]`, 10 comprobaciones):
- G1: bajarse de la placa cierra la puerta.
- G2: la flecha no pasa la reja; con solo el brasero no se abre.
- G3 y G5: sin escudo, las flechas aciertan.
- G4: el agua no se pisa.
- G6: la flecha no pasa la reja; sin ᛉ el atajo se cierra delante.

**Lo que el autoplay no puede juzgar, para el playtest:**
- Si se entiende sin texto que **la barrera atraviesa la reja**. Cada sala tiene su rótulo («Las rejas», «La galería»…), pero ninguno lo dice. Si no se entiende, la pista podría ir en el rótulo de G2: «Lo que no alcanza la flecha, lo alcanza la barrera».
- Si las rejas (`puerta` sin modelo, una losa) dejan ver la placa y el brasero de detrás.
- **Corriendo** (Shift) el atajo probablemente se cruza sin ᛉ. Andando no. Lo dejo así a propósito: es un atajo para quien lo descubra, no una trampa.
- El escudo de G3 no es obligatorio (se aguanta el daño). Hacerlo obligatorio pediría más arqueros o una tarea larga bajo fuego. Es la misma pregunta que tiene abierta el paso batido del Bosque 01 v01.

## 5. Cambios de motor (pequeños y genéricos)

| cambio | dónde | por qué |
|---|---|---|
| `vigia … puesto=si` | `Puzle3D.VigiaPuzle` | los arqueros de la sala son **de puesto** (`Combate3D.fijo`) desde el mapa; antes solo lo hacía el script del Bosque 01 v01 |
| la placa (`pulsador modo=presencia`) nota lo que **pesa** (grupo `peso`) | `Pulsador3D._alguien_encima` | el bloque de tierra ya estaba en el grupo `peso` «para que lo noten las placas», pero `Pulsador3D` solo miraba a la jugadora y a `cuerpos` |
| kit `barrera` | `Lanzador3D.KITS` | §1 |
| pista dorada de ᛉ | `SecuenciaCofreLegendario3D.PISTAS` | el segundo aviso del cofre dice dónde se usa |

## 6. Cómo editar

Es la misma gramática de `escenas/puzle.gd` que la Cueva. Lo propio de este nivel:
- **Una puerta que se abre mientras algo pesa:** `cuando=<placa>.pulsado hace=<puerta>.abrir` + `cuando=<placa>.soltado hace=<puerta>.cerrar`.
- **Una puerta que pide dos cosas a la vez:** una regla por cada orden, con `si=` (las de G2).
- **Distancias:** la barrera nace a **≤ 3 casillas** de la jugadora. Una placa o un brasero tras una reja tiene que poder apuntarse desde una casilla pisable a 3 o menos. Una puerta temporizada tiene que estar a menos de ~5,5 casillas andando (8,4 s) del sitio desde el que se lanza, o a más si se quiere obligar a usar ᛉ (~8,5 casillas con ᛉᛉ).
- **Arqueros:** la letra `A` (la escena lleva `arqueros = true`) y una pieza `vigia de=<sus casillas> puesto=si`. Las flechas de la jugadora llegan a ~2,8 casillas: a más distancia, al otro lado del agua, solo queda el escudo.

```bash
tools/Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path . --script res://herramientas/escenario_gruta_batida.gd
```

## 7. Para el playtest

- Abre `escenas/PruebaGrutaBatida.tscn` (F6).
- **ᛉ no tiene muestras grabadas** (`PENDIENTES.md`, «Gestos de ᛁ y de ᛉ»): tras el cofre, el glifo está en el libro pero no se reconoce dibujándolo. Para el atajo, ponlo con la paleta (F1) o grábalo con `G`.
- La salida al Bosque (3..5,17) apunta a `Bosque_01_v01:boca_cueva`, como la Cueva. El Bosque todavía no lleva a la Gruta.
- El autoplay se salta la recarga de las páginas, igual que el de la Cueva. Jugando hay 3 páginas, y la barrera tarda 3 s en recargar.
