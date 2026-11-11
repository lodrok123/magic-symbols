# Revisión del sistema de objetos y síntesis (10/11)

Revisión de los objetos, el botín, las recetas y las mejoras tal como están hoy en `nucleo/datos/`, cruzada con lo que hay colocado de verdad en los mapas. Termina con propuestas y con las decisiones que hacen falta de Pablo. Escrito por Juego; nada de esto está implementado todavía.

Niveles mirados: Bosque_02 (el de «Nueva partida»), Bosque_01_v01, CuevaResonante, GrutaBatida, GrutaPermanencia, SalaEmpuje, SalaLimo y SalaGolem.

## 1. Lo que hay hoy, en una página

| | Cuántos | Se consiguen hoy en algún nivel |
|---|---|---|
| Objetos en `objetos.tsv` | 78 | 58 |
| Ingredientes | 52 | 36 |
| Consumibles | 8 | 2 (poción y poción grande, en cofres); el resto solo por receta |
| Pigmentos | 5 | 0 (solo por receta) |
| Prendas | 6 | 3 (las épicas, en cofres de Bosque_02) |
| Recetas en `recetas.tsv` | 28 | 0: la pestaña de Síntesis no existe todavía |
| Mejoras en `mejoras.tsv` | 11 líneas | solo por receta, así que 0 |

**Lo más importante que sale de cruzar datos y mapas:**

1. **La síntesis no se puede usar.** `Sintesis` funciona y tiene pruebas, pero no hay pantalla (la pestaña es del Pipeline). Además Bosque_02 no tiene alquimista; solo la fogata abriría la síntesis de campo. Hoy ninguna receta ni mejora llega a la jugadora.
2. **Casi no hay plantas colocadas.** De 18 plantas solo se coloca el alga. Seta sí (3 en Bosque_02, 12 en la Cueva). Flores, lavanda, helecho, raíces y musgos existen en la tabla y tienen icono, pero ningún mapa los pone. Las bayas y la flor silvestre solo salen al segar hierba (15 %).
3. **Las páginas no pueden pasar de 3.** La mejora `paginas` sube `Repertoire.max_pages`, pero el libro y el lanzador tienen `PAGES = 3` fijo y solo hay teclas 1–3. La mejora «Página cosida» hoy no haría nada.
4. **Lobernos y canouros sueltan colmillo de goblin.** No tienen tabla propia y heredan la de `goblin`.
5. **Lo raro no llega.** Hay 4 recetas que piden `raro` (vida III, frascos II, frasco hondo II, página) y en todo el juego hay 3 raros: un núcleo de eco, una geoda y la savia del jefe. Cada receta se los come.
6. **Las prendas base no existen.** Los bordados piden capa, capucha o túnica, pero ningún cofre las da. Y Bosque_02 regala directamente las tres épicas, así que los bordados sobran.
7. **El cofre legendario del Bosque_02 da 150 de oro y 2 pociones grandes.** Es el final de la demo y no da nada que cambie cómo se juega.
8. **28 objetos sin icono:** los 7 consumibles nuevos, los 5 pigmentos, las 4 claves, las 6 prendas y 6 ingredientes.

## 2. Lista de objetos actualizada

Generada desde `nucleo/datos/objetos.tsv`, `fuentes.tsv` y `botin_tablas.tsv`, y cruzada con los mapas. «Se consigue hoy» dice dónde hay de verdad una fuente colocada. Las fuentes que la tabla promete pero ningún mapa pone salen como **no**.

### Botin (1)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `oro` | Oro | comun | - | 0 | (moneda) | enemigos, cofres, jarrones |

### Hongo (10)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `seta` | Seta | comun | vital | 1 | sí | recoger seta: Bosque_02 (3), CuevaResonante (12) |
| `seta_asada` | Seta asada | comun | vital, calor | 2 | sí | cofre Bosque_01_v01; cofre Bosque_02; reaccion seta: Bosque_02 (3), CuevaResonante (12) |
| `seta_humeda` | Seta empapada | comun | vital, agua | 2 | sí | reaccion seta: Bosque_02 (3), CuevaResonante (12) |
| `seta_helada` | Seta helada | comun | vital, frio | 2 | sí | reaccion seta: Bosque_02 (3), CuevaResonante (12) |
| `seta_electrificada` | Seta electrificada | comun | vital, electrico | 2 | sí | reaccion seta: Bosque_02 (3), CuevaResonante (12) |
| `esporas` | Esporas | comun | viento | 2 | sí | reaccion seta: Bosque_02 (3), CuevaResonante (12) |
| `seta_resonante` | Seta resonante | comun | vital, resonante | 2 | sí | pulso sobre seta madura: CuevaResonante (3) |
| `esporas_luminosas` | Esporas luminosas | comun | resonante, viento, tinta | 3 | **no** | reaccion seta_resonante: CuevaResonante (3 con madura=si) |
| `seta_cristalizada` | Seta cristalizada | comun | resonante, frio | 3 | **no** | reaccion seta_resonante: CuevaResonante (3 con madura=si) |
| `seta_palida` | Seta pálida | comun | toxico, vital | 2 | sí | **no** (sin fuente colocada) |

### Planta (18)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `flor_luna` | Flor de luna | comun | vital, tinta | 1 | sí | **no** (sin fuente colocada) |
| `flor_ardiente` | Flor ardiente | comun | tinta, calor | 2 | sí | cofre Bosque_01_v01 |
| `flor_rocio` | Flor de rocío | comun | tinta, agua | 2 | sí | **no** (sin fuente colocada) |
| `flor_chispa` | Flor cargada | comun | tinta, electrico | 2 | sí | **no** (sin fuente colocada) |
| `flor_escarcha` | Flor de escarcha | comun | tinta, frio | 2 | sí | **no** (sin fuente colocada) |
| `petalos` | Pétalos al viento | comun | tinta, viento | 2 | sí | **no** (sin fuente colocada) |
| `lavanda` | Lavanda | comun | vital, viento | 1 | sí | **no** (sin fuente colocada) |
| `baya` | Bayas | comun | vital | 1 | sí | segar hierba |
| `helecho` | Helecho | comun | vital | 1 | sí | **no** (sin fuente colocada) |
| `flor_silvestre` | Flor silvestre | comun | tinta | 1 | sí | segar hierba |
| `alga_cueva` | Alga de cueva | comun | agua, vital | 2 | sí | recoger alga: Bosque_02 (1), CuevaResonante (3) |
| `alga_seca` | Alga seca | comun | calor, tierra | 2 | sí | reaccion alga: Bosque_02 (1), CuevaResonante (3) |
| `alga_cargada` | Alga cargada | comun | electrico, agua | 3 | **no** | reaccion alga: Bosque_02 (1), CuevaResonante (3) |
| `musgo_cueva` | Musgo de cueva | comun | agua, vital, tinta | 1 | **no** | **no** (sin fuente colocada) |
| `helecho_cueva` | Helecho de cueva | comun | vital | 1 | **no** | **no** (sin fuente colocada) |
| `resina` | Resina | comun | calor, tinta | 2 | sí | golpe a árbol (sin confirmar en mapas) |
| `corteza` | Corteza | comun | proteccion, tierra | 2 | sí | golpe a árbol (sin confirmar en mapas) |
| `savia_elemental` | Savia del elemental | epico | vital, raro | 5 | sí | enemigo elemental: Bosque_02 (jefe del santuario) |

### Raiz (4)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `raiz` | Raíz | comun | tierra, vital | 1 | sí | **no** (sin fuente colocada) |
| `raiz_cenizas` | Raíz carbonizada | comun | tierra, calor | 2 | sí | cofre Bosque_01_v01 |
| `raiz_hinchada` | Raíz hinchada | comun | tierra, agua | 2 | sí | **no** (sin fuente colocada) |
| `raiz_magnetica` | Raíz magnética | comun | tierra, electrico | 2 | sí | **no** (sin fuente colocada) |

### Animal (8)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `panal` | Panal | comun | vital, tinta | 2 | sí | reactivo colmena: Bosque_02 (1) |
| `pluma` | Pluma | comun | viento, vital | 1 | sí | reactivo nido: Bosque_02 (1) |
| `seda` | Seda de araña | comun | frio, proteccion | 2 | sí | reaccion telarana: Bosque_02 (4), Bosque_01_v01 (2) |
| `colmillo_goblin` | Colmillo de goblin | comun | tierra, proteccion | 2 | sí | enemigo goblin: Bosque_02, Bosque_01_v01 (y lobernos y canouros usan su tabla) |
| `jiron_escudo` | Jirón de escudo | comun | calor, proteccion | 2 | sí | enemigo goblin_escudo: GrutaPermanencia, CuevaResonante |
| `baba_limo` | Baba de limo | comun | agua, toxico | 2 | sí | enemigo limo: SalaLimo |
| `gota_veneno` | Gota de veneno | comun | toxico | 3 | **no** | **no** (sin fuente colocada) |
| `pluma_chaman` | Pluma de chamán | comun | viento, toxico | 3 | sí | enemigo chaman: Bosque_02 (1) |

### Mineral (13)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `cristal_tierra` | Cristal de tierra | comun | tierra | 3 | sí | **no** (sin fuente colocada) |
| `carbon` | Carbón | comun | calor, tierra | 2 | sí | seto quemado: Bosque_02 (3 setos) |
| `piedra` | Piedra | comun | tierra | 1 | sí | **no** (sin fuente colocada) |
| `mineral_veta` | Mineral de veta | comun | tierra, resonante | 2 | sí | cofre CuevaResonante; golpe veta: CuevaResonante (16) |
| `esquirla_cristal` | Esquirla de cristal | comun | resonante | 2 | sí | golpe cristal_resonante: CuevaResonante (7); jarrones |
| `basalto` | Basalto | comun | tierra, calor | 2 | sí | recoger basalto: CuevaResonante (2) |
| `obsidiana` | Obsidiana | comun | tierra, frio, calor | 3 | sí | reaccion lava: CuevaResonante (1) |
| `polvo_cristal` | Polvo de cristal | comun | resonante, tinta | 3 | sí | golpe esquirla_cristal: CuevaResonante (tras romper cristal) |
| `cristal_cargado` | Cristal cargado | comun | resonante, electrico | 3 | sí | reaccion cristal_resonante: CuevaResonante (7) |
| `ceniza_geoda` | Polvo de geoda | comun | resonante, tierra | 2 | sí | romper geoda: CuevaResonante (2) |
| `polvo_golem` | Polvo de gólem | comun | tierra, proteccion | 3 | sí | enemigo golem: SalaGolem |
| `nucleo_eco` | Núcleo de eco | epico | resonante, raro | 5 | sí | cofre Bosque_01_v01; cofre CuevaResonante |
| `geoda_resonante` | Geoda resonante | epico | resonante, tierra, raro | 4 | sí | cofre Bosque_01_v01 |

### Glifo (1)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `glifo_resonancia` | Glifo de resonancia | legendario | - | 0 | sí | **no** (sin fuente colocada) |

### Consumible (8)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `pocion` | Poción de vida | comun | - | 0 | sí | cofre Bosque_01_v01; cofre Bosque_02; cofre CuevaResonante; cofre GrutaPermanencia; jarrones; receta (sin interfaz todavía) |
| `pocion_grande` | Poción grande | comun | - | 0 | **no** | cofre Bosque_02; receta (sin interfaz todavía) |
| `tonico_tinta` | Tónico de tinta | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `balsamo_protector` | Bálsamo protector | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `infusion_brezo` | Infusión de brezo | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `antidoto` | Antídoto | comun | - | 0 | **no** | enemigo chaman: Bosque_02 (1); receta (sin interfaz todavía) |
| `frescor` | Frasco de frescor | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `abrigo` | Brasa embotellada | comun | - | 0 | **no** | receta (sin interfaz todavía) |

### Pigmento (5)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `pigmento_carmesi` | Pigmento Resina Carmesí | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `pigmento_ocre` | Pigmento Ocre del Túmulo | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `pigmento_musgo` | Pigmento Verde de Musgo | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `pigmento_ambar` | Pigmento Ámbar Volcánico | comun | - | 0 | **no** | receta (sin interfaz todavía) |
| `pigmento_eco` | Pigmento Azul de Eco | comun | - | 0 | **no** | receta (sin interfaz todavía) |

### Clave (4)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `llave` | Llave de la Cueva | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `llave_goblin` | Llave goblin | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `perla` | Perla | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `aletas` | Aletas | comun | - | 0 | **no** | **no** (sin fuente colocada) |

### Ropa (6)

| id | Nombre | Calidad | Etiquetas | Pot. | Icono | Se consigue hoy |
|---|---|---|---|---|---|---|
| `capa` | Capa corta | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `capucha` | Capucha | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `tunica` | Túnica sin mangas | comun | - | 0 | **no** | **no** (sin fuente colocada) |
| `capa_escarcha` | Capa de escarcha | epico | - | 0 | **no** | cofre Bosque_02 |
| `tunica_salamandra` | Túnica de salamandra | epico | - | 0 | **no** | cofre Bosque_02 |
| `capucha_musgo` | Capucha de musgo | epico | - | 0 | **no** | cofre Bosque_02 |

## 3. Formas de obtención

Las cuatro que propones, más dos que ya existen. La idea de fondo es que cada forma tenga un papel distinto, para que no compitan entre sí.

| Forma | Qué da | Papel | Hoy |
|---|---|---|---|
| **Cofres** | lo que cambia cómo juegas: mejoras, prendas, raros, glifos | progresión: un cofre siempre vale la pena | dan sobre todo oro y pociones |
| **Enemigos** | oro y un material de su especie | recompensa por pelear, y el único sitio de ciertos materiales | correcto, salvo lobernos y canouros |
| **Objetos del escenario** (plantas, jarrones, rocas) | lo común de la zona | el día a día: ir cogiendo mientras se explora | solo setas y algas colocadas |
| **Reactivos del escenario** (elemento sobre pieza) | las variantes y lo poco común | saber magia es la llave: el hechizo correcto da el objeto mejor | colmena, nido, telaraña, lava, cristal, seta: bien encaminado |
| Comercio (librera, alquimista) | consumibles básicos y recetas | gastar oro | existe en Bosque_01; en Bosque_02 la librera solo da pistas |
| Misiones | prendas base, claves | historia | capucha prevista, sin colocar |

**Regla que propongo para que encaje:**

- **Lo común se recoge.** Cada zona tiene su paleta de 4 a 6 plantas o minerales colocados a mano y que rebrotan.
- **Lo poco común se gana con magia.** La variante buena de un ingrediente solo sale por reacción. Ejemplo: la seta da la asada con fuego y la helada con hielo.
- **Lo raro está en un sitio concreto.** Cofres épicos, jefes y secretos, siempre en un lugar fijo. Nunca por azar.
- **Lo que mejora a la jugadora no se compra.** Se encuentra un trozo y el alquimista lo termina con ingredientes. Ver el apartado 5.

## 4. Distribución del loot

**Paleta por zona.** Cada zona aporta dos o tres etiquetas dominantes. Así las recetas piden ir a sitios concretos sin escribirlo en ninguna parte.

| Zona | Etiquetas que abundan | Comunes que propongo colocar | Reactivos |
|---|---|---|---|
| Bosque | vital, tinta, viento | bayas, helecho, lavanda, flor silvestre, flor de luna, raíz | colmena, nido, telaraña, seta, árbol |
| Cueva | resonante, tierra, agua | musgo, helecho de cueva, alga, seta, basalto | veta, cristal, geoda, lava, seta madura |
| Pantano (futuro) | tóxico, agua | seta pálida, alga, raíz hinchada | charca con rayo: alga cargada |
| Volcán (futuro) | calor, tierra | carbón, basalto, flor ardiente | lava: obsidiana |
| Cumbre (futuro) | frío, viento | flor de escarcha, pétalos | agua con hielo |

**Jarrones.** Que sigan saliendo casi siempre vacíos, como en EoW, pero que el 10 % de poción pase a ser 10 % de ingrediente común de la zona. La poción ya sale en cofres y por receta.

**Enemigos.** Cada especie con su tabla: oro fijo más un material propio con su probabilidad.

| Especie | Material propuesto | Etiquetas |
|---|---|---|
| goblin | colmillo de goblin (hoy, 60 %) | tierra, protección |
| loberno | pelaje de loberno (nuevo, 50 %) | frío, protección |
| canouro | garra de canouro (nuevo, 50 %) | viento, tierra |
| limo | baba de limo (hoy, 70 %) | agua, tóxico |
| chamán | pluma de chamán (50 %) y gota de veneno (nueva fuente, 30 %) | viento, tóxico |
| gólem | polvo de gólem (hoy) | tierra, protección |
| jefe | un raro siempre y una mejora | raro |

**Cofres, en tres tamaños:**

- **Común:** algo de oro y uno o dos ingredientes de la zona. La tabla `cofre_pequeno` pasa a dar ingredientes, no solo oro y poción.
- **Épico:** una pieza de mejora, una prenda o un raro. Uno o dos por nivel.
- **Legendario:** un glifo, un libro o una mejora grande. Uno por zona.

**Oro.** Bosque_02 da unos 360 de oro en cofres, más 10 por goblin. Las recetas de mejora piden 680 en total. Está bien que no llegue para todo en el primer nivel, pero hace falta decidir cuánto se espera gastar por nivel.

## 5. Recetas y mejoras

**El sistema de recetas por etiquetas funciona y lo mantendría.** Una receta pide «vital ≥ 3», y cualquier mezcla de ingredientes con esa etiqueta vale. Tres ajustes:

1. **Separar dos tipos de receta.**
   - **Consumibles y pigmentos:** solo ingredientes, en la hoguera o en el alquimista. Se repiten tanto como quieras.
   - **Mejoras:** pieza encontrada más ingredientes más oro, solo en el alquimista y una sola vez. Hoy las mejoras salen solo de ingredientes y oro, así que se compran. Con la pieza, explorar pasa a importar.
2. **Resolver lo raro.** Que lo raro solo lo pidan las mejoras de nivel alto, y que haya al menos uno por cada receta que lo pide. O, mejor, que la pieza encontrada sustituya al raro.
3. **Quitar los bordados o cambiarlos de papel.** Si las épicas salen de cofres, los bordados sobran. Propuesta: el bordado no crea la prenda, la mejora a un segundo nivel. Ver el apartado 6.

**Piezas de mejora (objetos nuevos, categoría `mejora`):**

| Pieza | Dónde | Con qué la termina el alquimista | Da |
|---|---|---|---|
| Trozo de corazón | cofres épicos y secretos; 4 trozos por corazón | vital ≥ 4 y 20 oro | +20 vida máx. |
| Frasco vacío | cofre épico de cada zona | tinta ≥ 4, resonante ≥ 2 | +1 frasco de reserva |
| Engarce de glifo | jefes y cofres legendarios | resonante ≥ 4, tinta ≥ 3 | +1 hueco de glifo por página |
| Hoja de grimorio | cofres legendarios y misiones | tinta ≥ 6, protección ≥ 2 | +1 página |

## 6. Propuestas de mejoras

**Tabla de Pablo (10/11).** Sustituye a la propuesta de abajo, que queda como referencia de los valores de hoy.

| Mejora | Progresión | Obtención |
|---|---|---|
| Huecos de glifo | hasta 6 por página | engarces en hitos principales |
| Páginas | 3 iniciales → 8 como máximo de campaña | hojas en secretos, misiones y finales de zona |
| Frascos de reserva | 3 → 6 | frascos vacíos especiales |
| Capacidad por frasco | tres mejoras de +10 % sobre la capacidad base | ingredientes, con acceso por etapas |
| Vida | 100 → 200 en cinco mejoras de +20 | cuatro fragmentos por mejora |
| Mochila | 8 → 20 como referencia inicial | materiales comunes y coste moderado |

**Regla de los huecos (decidido el 10/11, Pablo): los engarces fijan el total.** Huecos por página = el mayor entre la base del libro y 1 + engarces, con tope 6. Hay 5 engarces en la campaña. Con el libro del bosque (base 1), cada engarce suma un hueco. Con el libro avanzado (base 4), los engarces solo se notan a partir del cuarto. Ningún engarce se pierde al cambiar de libro: cuenta para el total. Implementado el 10/11 (diario 463): `Mejoras._fijar_huecos` calcula el total desde la base que apunta `Repertoire.base_sigils_per_page`.

**Valores de hoy y el primer borrador:**

| Mejora | Hoy | Propuesta | Cómo se consigue | Bloqueo |
|---|---|---|---|---|
| Huecos de glifo por página | 1 → 6 (tope 5 niveles); el libro avanzado ya empieza en 4 | hasta 6 en cualquier libro | 5 engarces en total: jefes y legendarios | ninguno: ya funciona encima del libro |
| Páginas | 3 → 5 en la tabla, pero el libro fija 3 | 3 → 8 | 5 hojas de grimorio | **Hechizos:** `PAGES` = 3 en el libro y el lanzador, teclas 4–8 y la lámina del libro |
| Frascos de reserva | 3 → 6 | 3 → 6, uno por zona | frascos vacíos en cofres épicos | ninguno |
| Tinta por frasco | +10 % por nivel, 3 niveles | igual, pero con ingredientes eléctricos | receta normal del alquimista | ninguno |
| Vida | 100 → 200, 5 niveles | igual, con 20 trozos de corazón | 4 trozos por corazón | ninguno |
| Mochila | 8 → 20 | igual | receta barata con oro | ninguno |
| Defensa | DEF 0 → 2 | quitarla de recetas y dejarla en prendas | prendas | ninguno |

Sobre las páginas: con 8 páginas y teclas 1–8, el libro necesita otra lámina y otra forma de elegir. Una opción es una rueda o dos libros de 4 páginas. Es trabajo de Hechizos y de Pipeline. Hasta entonces propongo dejar el tope en 5 y avisarles.

### Prendas por zona: ventajas funcionales, no de defensa

Hoy las tres épicas dan inmunidad a un estado y DEF 1. Eso pisa a los consumibles: si la capa te hace inmune al frío, el abrigo deja de servir.

**Regla que propongo:** cada estado de zona (`estados_mundo.tsv`) tiene una prenda que lo convierte en ventaja y un consumible que lo aguanta.

- El **consumible** da inmunidad total, poco rato.
- La **prenda** da una habilidad nueva y solo media resistencia: el aguante baja a la mitad.

Tres huecos de ropa: cabeza, medio (túnica) y exterior (capa). Una prenda por hueco y zona:

| Zona / estado | Prenda | Ventaja funcional | Resistencia |
|---|---|---|---|
| Bosque | Capucha de musgo (cabeza) | los recolectables se ven a través de la hierba alta; segar tira dos veces | veneno a la mitad |
| Cueva, oscuridad | Diadema de eco (cabeza) | cada pulso enseña paredes huecas y vetas 5 s | ve 2 casillas más a oscuras |
| Volcán, calor | Túnica de salamandra (medio) | pisar lava enfriada no quema; tu fuego enciende braseros a 2 casillas | calor a la mitad |
| Cumbre, frío | Capa de escarcha (exterior) | el agua que pisas se hiela: andar sobre charcas y ríos | frío a la mitad |
| Pantano, veneno | Botas de limo (medio) | el barro no frena; salir del veneno da 5 de tinta | veneno a la mitad |
| Tormenta | Capa de cobre (exterior) | un rayo que te cae recarga un frasco en vez de dañar | rayo a la mitad |
| Vendaval | Capa lastrada (exterior) | el viento no te empuja; tu viento a favor llega el doble | - |

**El bordado** pasaría a mejorar la prenda: «Capa de escarcha bordada» lleva la ventaja de 3 a 5 casillas, o la resistencia de la mitad a entera.

**Apariencia:** cada prenda es una pieza de ropa nueva para Pipeline (modelo, ajuste a la jugadora, prueba de capa). Es el coste más alto de todo el documento.

## 7. Consumibles

> Desarrollado en `docs/PROPUESTA_CONSUMIBLES.md` (pociones en tres calidades, antídotos, elixires mixtos, pigmentos de una carga, oro y lanzables). Lo de abajo es el primer borrador.

**Los ocho de hoy** se equipan y se usan con Q:

| id | Efecto |
|---|---|
| pocion | cura 40 |
| pocion_grande | cura 80 |
| infusion_brezo | regenera 3 de vida por segundo durante 12 s |
| balsamo_protector | absorbe el próximo golpe durante 20 s |
| tonico_tinta | recarga un frasco de tinta |
| antidoto | quita el veneno y protege 60 s |
| frescor | aguanta el calor 90 s |
| abrigo | aguanta el frío 90 s |

**Faltan consumibles para tres estados de zona:** oscuridad, tormenta y vendaval. Y no hay ninguno de exploración. Propuestas, todas por receta y sin glifos nuevos:

| Propuesta | Receta | Efecto | Para qué |
|---|---|---|---|
| Farol de esporas | esporas luminosas + resina | luz de 3 casillas alrededor durante 120 s | oscuridad |
| Pararrayos de cobre | raíz magnética + mineral | los rayos de tormenta no te buscan 90 s | tormenta |
| Lastre de piedra | piedra ×2 + seda | el vendaval no te empuja 90 s | vendaval |
| Tinta espesa | tónico + panal | recarga dos frascos | tinta, versión grande |
| Polvo de eco | polvo de cristal + esporas | señala el cofre sin abrir más cercano 20 s | exploración |
| Bayas | sin receta: se comen directas | cura 10 al instante | curar poco sin gastar poción |

**Una pregunta de fondo:** hoy se equipa un consumible y se pasa al siguiente con R. Con 14 la vuelta se hace larga y hará falta una rueda o dos huecos rápidos. Eso es de Pipeline.

## 8. Lo que necesito que decidas

1. **Mejoras: ¿pieza encontrada más alquimista, o compra con ingredientes como hoy?** Recomiendo la pieza. Es lo que hace que explorar dé progresión.
2. **Páginas: ¿tope de 8?** Necesita a Hechizos y a Pipeline. Propongo 5 mientras tanto.
3. **Prendas: ¿la regla de ventaja funcional más media resistencia?** Si sí, las tres épicas de hoy cambian de efecto.
4. **¿Las tres épicas siguen en cofres de Bosque_02?** Con la regla de zona, la de escarcha y la de salamandra deberían estar en la cumbre y en el volcán.
5. **¿Cuánta planta por zona?** Propongo una paleta de 4 a 6 objetos por zona, colocados a mano y que rebroten.

## 9. Orden propuesto para implementarlo

1. **Juego, rápido:** tablas para loberno y canouro, `cofre_pequeno` con ingredientes, jarrones con ingrediente de zona, plantas de la paleta colocadas en Bosque_02 y en la Cueva. **Hecho el 11/11** (diario 470): pelaje de loberno y garra de canouro, gota de veneno del chamán, cofre pequeño con oro e ingrediente siempre, jarrones sin poción, y 12 plantas en Bosque_02 y 5 en la Cueva Resonante.
2. **Pipeline:** la pestaña de Síntesis (bloquea todo lo demás) y los 28 iconos que faltan.
3. **Juego:** piezas de mejora (objetos, recetas, cofres épicos que las dan).
4. **Juego y Pipeline:** prendas funcionales, una por zona, empezando por la del Bosque.
5. **Hechizos:** páginas por encima de 3.
6. **Juego:** consumibles nuevos.
