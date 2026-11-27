# Catálogo de puzles del generador: ruinas (pulsadores y trampas) y cueva (agua y tierra) (27/11/2026)

Encargo de Pablo: «quiero que montes niveles de prueba para la cueva y las ruinas; la idea es revisar que todos los assets se corresponden con el proyecto. Diseña puzles para ellos: ruinas con assets tipo pulsadores / trampas, y cueva con puzles para agua y tierra».
Esta nota amplía `docs/CATALOGO_PUZLES_2026-11-26.md` (41 plantillas) con **11 plantillas de puzle nuevas** (6 de ruinas, 5 de cueva) y **6 plantillas «muestrario»** (salas de revisión de piezas, que no son puzles). El catálogo pasa a **58 archivos**.
Los niveles que las usan y la revisión de assets están en `docs/REVISION_ASSETS_CUEVA_RUINAS_2026-11-27.md`. Demo = solo fuego, agua y tierra; glifos flecha, línea, barrera, altura, ᚱ y suelo.

Resultado del comprobador (todas las plantillas con pruebas, 30 fps fijos): **115 pruebas, 0 con FALLO** (antes 68, 0) en 1.444 s.

## 1. Lo nuevo del formato

* **`; bioma ruinas [cueva …]`**: el reparto AUTOMÁTICO (`puzles` > 0 en el generador) solo pone la plantilla en mapas de ese `estilo` (cueva · bosque · pantano · ruinas). Sin la línea, vale en todos (las 41 de antes no cambian). A mano (pestaña «Puzles» o `; puzles` del mapa) se puede poner donde se quiera.
  Así el reparto al azar de los mapas ya hechos no se altera: un bosque nunca recibe un puzle de ruinas, ni su orden barajado cambia (el filtro quita las nuevas ANTES de barajar).
* **`; solo_mano si`**: el reparto automático no la elige nunca (las salas muestrario).
* **Pieza `muestrario`** (`escenas/puzle.gd`, `objetos/muestrario_piezas_3d.gd`): reparte las piezas de un pack en filas por categoría, a escala del juego, cada una con su id en un rótulo. Ver el otro documento.
* **Parámetro `salas_grandes`** del generador (`generador_mazmorra.gd`, «32x22;32x23»): talla salas vacías del tamaño que se pida donde no pisen otras salas, con `rol = "grande"` (no son el inicio, no llevan enemigos ni jarrones). Solo se llenan con una plantilla a mano. No está en `parametros_defecto()` a propósito (si estuviera, cambiaría el `; generador` de todos los mapas ya exportados, entre ellos los tres de bosque).
* **`decorado modelo=ss_…`**: las piezas del pack de ruinas valen en `decorado` como ya valían las `lost_*` (`puzle.gd`, `_ruta_pieza_arte`).

## 2. Las 11 plantillas de puzle

Todas: `; validacion pendiente`, `; necesita` exacto, comentario de diseño (qué ve la jugadora, idea, solución), una **solución jugada con hechizos reales** y pruebas «nada» que demuestran que no se resuelve sola ni con el hechizo equivocado (`herramientas/comprobar_puzles_agua.gd`). Tiempos medidos en el comprobador (30 fps fijos).

### Ruinas · pulsadores y trampas (`; bioma ruinas`)

| Id | Título | Sellos | Mecánica | Origen | Pruebas (resultado) |
|---|---|---|---|---|---|
| `mascarones_relevo` | Los mascarones y las dos placas | ninguno | cuatro mascarones de flechas en un pasillo de una casilla; dos placas de presencia en medio, cada una apaga 6 s la pareja que viene detrás: **relevo** (placa → `trampa.apagar(6)`) | idea propia (relevo de F7/F8) | A `cruza … sin_dano` + abre cofre OK; nada ×3: sin pisar la placa, las flechas hieren (4,2 s) y el cofre no se abre solo |
| `placa_y_boton` | La placa de peso y el botón de magia | cualquiera (+ flecha) | **placa de peso (1) con la roca pequeña** (se queda) **+ botón de magia con `rearme=9`** (dura): la verja solo abre con los dos activos a la vez (`si=boton.activo`), en cualquier orden | peso de `lava_roca_peso` + botones de F10/F11 | A (roca y luego hechizo) 1,1 s; B (hechizo y luego roca) 8,6 s; nada: solo hechizo / solo roca no abren |
| `dos_placas_cofre` | El cofre que pide dos placas a la vez | ninguno | cofre **sellado** (`abre_si=pa.activo+pb.activo`): una placa de peso (1) que solo baja la **roca** empujada 2 casillas, y otra de presencia **pegada al cofre** que hay que PISAR mientras se pulsa E: «la roca y la jugadora» | idea del encargo (dos pulsadores a la vez: roca + jugadora); antes «la sala que se cierra» (ver §4) | A (empujar, pisar, abrir desde la placa) OK; nada: sin tocar / solo pisando la placa no se abre |
| `totem_a_favor` | El tótem que enciende el brasero | ninguno | un **tótem** (`exenta=si`, flecha de fuego cada 3 s) apunta a un brasero tapado por una **roca pequeña** atravesada en la línea de tiro (la roca para las flechas); empujarla FUERA de la fila deja que la propia trampa encienda el brasero y abra la verja | «trampas a favor» del encargo | A (empujar al norte) 3,9 s OK; nada: sin empujar / empujando a lo largo de la fila el brasero no se enciende en 10 s |
| `dragon_agua_reja` | El dragón que se apaga con agua y la reja del botón | agua | **dragón continuo** (`ciclo=90,1`) cortando la sala; agua a la cabeza lo apaga 8 s (plazo); un botón de magia abre la verja del nicho | idea del encargo (dragón + agua + reja) | A (agua al dragón + agua al botón + cruzar `sin_dano` + abrir) 1,0 s OK; nada: sin apagar la cruza hiere; sin botón la verja no abre |
| `dragon_muro_brasero` | El chorro que espera tras el muro | tierra | un dragón escupe contra un **muro agrietado** que tapa el nicho de un brasero; dos golpes de tierra lo rompen y el chorro enciende el brasero → aparece el cofre (el fuego de la jugadora no rompe el muro) | «dragón que enciende un brasero» del encargo | A 2,8 s OK; nada: sin tocar / con fuego / con un solo golpe de tierra no arde en 8-10 s |

### Cueva · agua y tierra (`; bioma cueva`)

| Id | Título | Sellos | Mecánica | Origen | Pruebas (resultado) |
|---|---|---|---|---|---|
| `muro_cauce_balsa` | El muro que tapa el cauce y la balsa | tierra + flecha | dos golpes de tierra rompen un **muro agrietado** que tapa un cauce (`muro.roto → manantial.abrir_cauce`): el foso sube a 0,5 u, la **balsa** flota y lleva el cofre al muelle | `cofre_balsa` con otro disparador (romper en vez de regar) | A: balsa atracada a los 21,0 s OK; nada: sin tocar / con agua / con un golpe no atraca en 15-20 s |
| `dique_pozo_placa` | El pozo con la placa bajo el agua | tierra + flecha | romper un muro de tierra suelta el **dique** (compuerta `modelo=muro`, **`tarda=12`**) y el pozo (0,45 u) se vacía por un cauce al desagüe en **12,0 s**; seco, se llega a la **placa sumergida** y aparece el cofre | idea del encargo (vaciar un pozo) | A (2 golpes, esperar el vaciado, cruzar, abrir) OK; nada: sin golpes / un golpe / agua no vacían |
| `fuga_reja_reloj` | La fuga y la reja con plazo | agua + flecha | un pulsador de agua abre el manantial (12 u³) **y** una compuerta-fuga con **`caudal=0.35`**; un detector de nivel abre la verja mientras hay agua suficiente y la cierra al perderla: **ventana de ~13 s** para cruzar la sala y abrir el cofre del nicho | idea del encargo («reloj de agua», T1a/Q14) | A: verja abierta a los 9,9 s, cruza `sin_dano` y abre OK; ventana: se cierra a los 23,2 s (≈13 s abierta) |
| `columna_puente_lava` | La columna que se tumba de puente | fuego, agua o tierra | **cristal dormido → veta → geoda → columna agrietada** que cae sobre un **río de lava** (`puente=… largo=2`) y queda de puente para siempre | Cueva Resonante C3 (lab) pasado a plantilla | A (fuego) y B (tierra) 2,0 s OK; nada: sin hechizo la columna no cae |
| `desvia_arroyo` | El arroyo y la presa de tierra | tierra + barrera | una presa de tierra DESPUÉS del brazo hace remontar el agua por el brazo hasta el detector (0,3): aparece el cofre; una presa ANTES lo deja seco | T3 del lab de tierra (probado en `escenario_puzles_tierra.gd`) pasado a plantilla | A 7,7 s OK; nada: sin presa / presa aguas arriba no sube en 12 s |

### Muestrarios (`; solo_mano si`, no son puzles)

`muestrario_ruinas_muros` (32 × 22), `muestrario_ruinas_resto` (32 × 23), `muestrario_cueva_kit` (28 × 13), `muestrario_lc_estructura` (44 × 25), `muestrario_lc_mina` (36 × 15), `muestrario_lc_vida` (36 × 17). Sin pruebas del comprobador: los comprueba `prueba_niveles_cueva_ruinas.gd` (se montan todas las piezas con su rótulo).

## 3. Coherencia con lo que ya había

* Mecánicas **repetidas a propósito** con otro verbo: `muro_cauce_balsa` (balsa de `cofre_balsa`, pero se rompe en vez de regar), `desvia_arroyo` y `columna_puente_lava` (laboratorios probados, ahora plantilla), `placa_y_boton` (peso de `piedra_pista`).
* **Nuevas del todo**: relevo de placas (`mascarones_relevo`), cofre sellado por dos placas (roca + jugadora), tótem a favor, dragón + plazo, dragón contra un muro de tierra, pozo con `tarda`, reloj con `caudal` (la fuga).
* Trampa (`trampa_dragon`, `trampa_flechas` con y sin `exenta`), pulsadores de presencia, de peso, de magia con `rearme`, verja, muro agrietado, compuerta con `tarda` y con `caudal`, manantial con `inicia=no`, balsa, lava + columna-puente, cristal + veta + geoda: todas son piezas que ya existían; solo se ha añadido la pieza `muestrario`.

## 4. Cambios de código (todos pequeños)

* `catalogo_puzles.gd`: líneas `; bioma` y `; solo_mano`, y `vale_en_estilo()`; `generador_mazmorra.gd`: `_vale_plantilla` lo usa (una línea) y `salas_grandes` (`_tallar_salas_grandes`, rol «grande»; el inicio y la colocación a mano lo respetan).
* **Reglas de las pruebas del generador que me obligaron a rehacer dos diseños** (`prueba_generador_mapas.gd` §10, que pone cada plantilla a mano en mapas pequeños): todo `bloque` tiene que vivir en una pista vertical de una casilla cerrada por paredes (la Sala del Empuje) → los puzles con un objeto que se empuja en una sala abierta usan **`roca_empujable`** (que el engine ya recoloca si se atasca) y no `bloque`; y todo `cerrojo` tiene que llamarse `cerrojo_<n>` con su `vigia_<n>` → la primera idea de `dos_placas_cofre` («la sala que se cierra con el cofre»: al coger el cofre el cerrojo de la salida se cerraba y para salir había que sostener bloque + jugadora en dos placas; pasaba el comprobador) se quedó fuera por eso.
* `escenas/puzle.gd`: tipo `muestrario` (+ `_rotulo_muestrario`) y rutas `ss_*` en `decorado`; documentado en la cabecera. `objetos/muestrario_piezas_3d.gd`: la distribución.
* Pruebas: `prueba_generador_mapas.gd` salta la colocación en mapas pequeños de las plantillas `solo_mano` y, para las plantillas con `; prueba mapa` (piden un mapa grande), pide 2 de 16 mapas en vez de 8 (igual que las de 14 o más de ancho; las de 9 a 12 de ancho caben en 4-7) (no caben en 40 × 34; las comprueba `prueba_niveles_cueva_ruinas.gd`); `escenario_generador_mapas.gd` ya no cuenta `cuenca` y `manantial` como piezas con nodo (son datos; fallaba con `-- cueva` cuando el azar repartía `placa_isla`); `prueba_niveles_bosque.gd` cuenta también los enemigos que van por `; pieza` (limo, gólem…).
