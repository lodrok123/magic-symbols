# Bosque 01 mejorado: puzles y campamento goblin (21/11/2026)

Encargo de Pablo: «voy a diseñar un nivel Bosque 01 pero mejorado; necesitaré unos 5/6 puzles. Revisa también cómo se podría generar un campamento goblin con el generador».
Punto de partida acordado antes: el nivel **enseña ᚦ perforar** y acaba con el **Elemental** de jefe, que pone **dos raíces delante como muros**: la flecha normal no le hace daño; con **ᚦᚦ** o **ᛁᛁ** atraviesa y le daña. El fuego sigue siendo su debilidad.

Estados sacados de la hoja `docs/BD_INTERACTUABLES.xlsx` (pestaña Puzzles). «En juego» = ya funciona en un nivel; «Prototipo» = montado en un laboratorio; «Idea» = solo escrito.

## 1. Seis puzles, en orden

Kit del nivel: fuego, agua y tierra; glifos de la demo (flecha, línea, barrera, altura, suelo) y **perforar**, que se gana antes del jefe. Cada puzle enseña una cosa que luego sirve contra el Elemental.

| # | Puzle (id en la hoja) | Qué enseña | Estado | Por qué aquí |
|---|---|---|---|---|
| 1 | **Quemar la cuerda** (`fuego_quema_cuerda` o `b02_tronco_puente`) | El fuego actúa sobre objetos, no solo sobre enemigos | En juego | Entrada suave: un disparo y se abre el camino |
| 2 | **Cortafuegos** (`mixto_cortafuegos`) | El agua apaga y protege | En juego | Primer uso del agua como herramienta, no como daño |
| 3 | **Desvío en seco** (`lab_t1a_desvio_en_seco`) | La tierra cambia el terreno (tapar un cauce antes de abrir el agua) | Prototipo | Orden de acciones: primero tierra, luego agua |
| 4 | **Dos riegos** (`lab_q11_dos_riegos`) | **ᛁ línea**: un hechizo ancho alcanza dos cosas a la vez | Prototipo | Es una de las dos llaves del jefe (ᛁᛁ) |
| 5 | **Campamento goblin** (`b02_campamento_puerta_goblin` + `torre_arde`) | Combate con escenario: quemar la puerta y la torre, limpiar el campamento | En juego (en Bosque 02) | El combate grande antes del jefe; ver §2 para generarlo |
| 6 | **Dos dianas en fila** (nuevo) | **ᚦ perforar**: una flecha atraviesa la primera diana y da en la segunda | Nuevo | Justo después del cofre legendario que da ᚦ: es el ensayo exacto de las raíces del jefe |

**Jefe · el Elemental en el santuario.** Dos raíces-muro delante. Flecha normal: se para en la primera raíz. **ᚦᚦ**: atraviesa las dos. **ᛁᛁ**: la flecha es tan larga que llega a través. Fuego = su debilidad.

### El puzle nuevo (6): dos dianas en fila
- Tras el cofre legendario de ᚦ, una sala con **dos dianas (pulsadores de fuego) alineadas**, una detrás de otra, en un pasillo estrecho.
- Una flecha normal enciende solo la primera; hay que encender las dos a la vez (en la misma ventana, como los dos riegos).
- Con ᚦ la flecha atraviesa la primera y llega a la segunda: se abre la puerta al santuario.
- Coste: poco código. Las dianas ya existen (pulsador de elemento); falta comprobar que una flecha con perforar sigue tras activar un pulsador (hoy perforar atraviesa **enemigos**; habría que dejar que atraviese también dianas). Variante sin código: dos goblins en fila en un pasillo estrecho.

### Lo que no he metido y por qué
- Braseros, gotera, reloj de agua, choque térmico: buenos, pero repiten lo de los puzles 1–3; quedan de reserva si sobra espacio.
- Puzles con hielo, rayo o viento: fuera del kit de la demo.

## 2. Campamento goblin con el generador

### Lo que ya existe (hecho a mano en Bosque 02)
Letras del mapa que pinta `presentacion/prueba_test2.gd`:

| Letra | Pieza | Comportamiento |
|---|---|---|
| `x` | empalizada goblin | Muro; se orienta solo según el tramo |
| `y` | puerta goblin | **Arde**: al quemarse deja paso |
| `o` | torre goblin | **Arde** (en Bosque 02 da un cofre) |
| `t` | tienda goblin | Decorado que bloquea |
| `V` | estandarte goblin | Decorado que bloquea |
| `T` | brasero / fogata | Se enciende |
| `W` / `A` | goblin guerrero / arquero | Enemigos |

Más, por líneas del mapa: `; pieza … chaman`, un **vigía** que cuenta a los goblins y pone una flag al limpiar, el **cofre** que aparece con esa flag, y `; zona … fuego id=campamento` (luz del campamento y botín propio).

### Lo que hace hoy el generador
`herramientas/generador_mapas/generador_mazmorra.gd` genera **mazmorras y cuevas** (salas y pasillos, cueva orgánica o mazmorra de una página): pone inicio, goblins `W`/`A`, chamán, braseros, cofres, salas que se cierran hasta limpiarlas y puzles de su **catálogo** (`herramientas/generador_mapas/catalogo/*.txt`). **No sabe nada de campamentos** ni de exteriores.

### Tres formas de hacerlo, de menos a más trabajo

1. **Una plantilla de catálogo `campamento_goblin.txt`** (recomendada para empezar).
   - Es solo un archivo: el catálogo ya copia cualquier letra del juego (`x y o t V T W A`) y las líneas `; pieza` / `; puzle`.
   - Dentro: empalizada con una puerta `y`, dos o tres tiendas `t`, una torre `o`, la fogata `T`, guardias `W`/`A`, el chamán, el vigía y el cofre que aparece al limpiarlo.
   - Límites: tamaño fijo (o estirado solo a lo ancho); el catálogo **no** copia `; zona` (luz de campamento) ni `; decorado` (el cazo, las rocas); el generador puede poner además sus propios goblins en esa sala.
2. **Un papel de sala «campamento»** en el generador.
   - Elige una sala grande y la puebla: rodea con empalizada dejando una puerta que arde, reparte tiendas, torre, fogata, guardias y chamán según el tamaño, y añade vigía, cofre y la zona de luz.
   - Se adapta a cualquier tamaño y no duplica goblins. Es código nuevo en `_poblar`, de tamaño medio.
3. **Un algoritmo de exteriores** (claros de bosque unidos por senderos en vez de salas y pasillos), con el campamento como uno de sus claros. Es lo que haría falta para generar un Bosque entero; trabajo grande.

### Hecho (22/11): la opción 2, «sala campamento»
- Parámetro **«Campamentos goblin»** (0–4) en la herramienta `herramientas/generador_mapas/GeneradorMapas.tscn` (`campamentos` en el generador; 0 de serie: los mapas de antes no cambian).
- Elige las salas de **7 × 6 o más**, sin otro papel y no pegadas al inicio (la más grande primero). En la sala: empalizada `x` por el borde de dentro, una puerta goblin `y` (arde) delante de cada entrada, fogata `T` en el centro, torre `o` en un rincón del fondo, tiendas `t` contra el fondo, estandarte `V` junto a la entrada, guardias `W`/`A` (2–5 según tamaño y el parámetro «Enemigos»), chamán si el patio tiene 30 casillas o más, vigía, cofre épico que aparece al limpiarlo y zona con luz de fuego y botín de campamento. Sin cerrojo.
- Si la empalizada partiera el mapa o lo dejara sin solución, se deshace y se prueba otra sala; si no cabe ninguno, lo avisa. En las cuevas casi nunca cabe (sus claros no llegan a 7 × 6).
- Pruebas: `prueba_generador_mapas` (bloque 16) y `escenario_campamento_generado` (lo exporta, lo carga en el juego, comprueba las piezas y borra los temporales).

## 3. Qué decides tú
- Si los seis puzles te valen o cambias alguno.
- Si el puzle 6 va con dianas (poco código) o con goblins en fila (sin código).
- Qué opción del campamento: plantilla (1) para tenerlo ya, o papel de sala (2).
