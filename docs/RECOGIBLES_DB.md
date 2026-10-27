# Base de datos de recogibles (propuesta para la síntesis)

27/10/2026 · contexto JUEGO · **propuesta para que Pablo la valide**. No está cableada: hoy los objetos viven en `nucleo/objetos.gd` (`DATOS`, `PLANTAS`, `MINERALES`). Las mismas filas, en tabla para importar, están en `docs/recogibles_propuesta.tsv`.

## 1. Por qué una base de datos y no más columnas en `DATOS`

Ahora mismo un objeto es un nombre, un color y una forma de icono. Cómo se consigue está repartido en tres sitios:
- `PLANTAS`: la reacción con un elemento;
- `MINERALES`: los golpes o el pulso;
- el mapa: la condición `coge_si=`.

Para qué sirve en la síntesis no está escrito en ningún sitio. Es lo que el estudio de EoW llama «tablas que se referencian entre sí» (`ANALISIS_EOW.md`, idea 1). La propuesta es **una fila por recogible** con tres grupos de columnas:

1. **qué es**;
2. **cómo se consigue** (la fuente y la condición);
3. **qué aporta a una receta**: etiquetas de síntesis y potencia.

La síntesis no pregunta «¿es una seta asada?», sino «¿trae `calor` con potencia 2?». Funciona como las etiquetas de los elementos: el día que haya tres objetos de calor, todas las recetas de calor los aceptan sin tocar nada.

## 2. Campos

| campo | tipo | ejemplo | para qué |
|---|---|---|---|
| `id` | texto | `seta_asada` | la clave de siempre (`Estado.agregar`) |
| `nombre`, `desc` | texto | «Seta asada» | inventario |
| `categoria` | `hongo` · `planta` · `mineral` · `animal` · `botin` · `consumible` · `clave` | `hongo` | filtros de la bolsa y del libro de síntesis |
| `calidad` | `comun` · `epico` · `legendario` | `comun` | color, aviso y lo que vale (`Objetos.CALIDADES`) |
| `zona` | `bosque` · `cueva` · `todas` | `cueva` | dónde buscarlo (y, después, el diario) |
| `fuente` | `recoger` · `reaccion` · `golpe` · `pulso` · `enemigo` · `cofre` · `romper` · `comprar` | `reaccion` | cómo se consigue |
| `de` | id | `seta` | el objeto del que sale (si sale de una reacción o de un golpe) |
| `via` | elemento, `pulso`, `golpes:n` o `-` | `fuego` | lo que hay que hacerle a `de` |
| `condicion` | expresión `si=` | `casilla(x,y).helada` | cuándo se puede coger (hoy es `coge_si=` del mapa) |
| `etiquetas` | lista | `calor,vital` | lo que aporta a una receta (§3) |
| `potencia` | 1–5 | 2 | cuánto aporta cada etiqueta |
| `rebrota_s` | número | 0 | si vuelve a salir (0 = no) |
| `pila` | número | 20 | cuántos caben en un hueco de la bolsa |
| `icono`, `modelo` | ruta | `objeto_seta_asada.png`, `seta_roja` | arte de la bolsa y del mundo |
| `estado` | `hay` · `nuevo` | `hay` | si ya existe en `Objetos.DATOS` |

## 3. Etiquetas de síntesis

Hay un vocabulario cerrado. Son las mismas palabras que las runas donde coinciden, para que se lea igual en el libro:

| etiqueta | sale de | lo usan las recetas de (DISENO_FUTURO §7) |
|---|---|---|
| `calor` | fuego | bálsamos, pigmento rojo |
| `frio` | hielo | conservas, pigmento blanco |
| `agua` | agua | infusiones, tónicos |
| `electrico` | rayo | pigmento amarillo, tónicos de tinta |
| `tierra` | tierra, minerales | bálsamo protector, mejoras de vida |
| `viento` | viento | pigmento verde, polvos |
| `resonante` | el pulso (Cueva) | mejoras de tinta y del glifo ᚱ |
| `vital` | plantas frescas | curas, mejoras de vida |
| `tinta` | lo que tiñe (pigmentos) | tinta y pigmentos nuevos |
| `raro` | épicos | mejoras del personaje (una por épico) |

Regla de los números: **común = potencia 1–2**, **transformado por un elemento = +1** y **épico = 4–5**. Así, transformar algo siempre vale la pena, sin que un común supere a un épico.

## 4. La lista

**Leyenda:** **hay** = ya está en `Objetos.DATOS`; **nuevo** = propuesto.

### Hongos

| id | nombre | zona | fuente | de / vía | condición | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|---|
| `seta` | Seta | todas | recoger | – | – | vital | 1 | hay |
| `seta_asada` | Seta asada | todas | reacción | seta / fuego | – | vital, calor | 2 | hay |
| `seta_humeda` | Seta empapada | todas | reacción | seta / agua | – | vital, agua | 2 | hay |
| `seta_helada` | Seta helada | todas | reacción | seta / hielo | – | vital, frio | 2 | hay |
| `seta_electrificada` | Seta electrificada | todas | reacción | seta / rayo | – | vital, electrico | 2 | hay |
| `esporas` | Esporas | todas | reacción | seta / viento | – | viento | 2 | hay |
| `seta_resonante` | Seta resonante | cueva | pulso | seta / pulso | `madura=si` | vital, resonante | 2 | hay |
| `esporas_luminosas` | Esporas luminosas | cueva | reacción | seta_resonante / viento | – | resonante, viento, tinta | 3 | **nuevo** |
| `seta_cristalizada` | Seta cristalizada | cueva | reacción | seta_resonante / hielo | – | resonante, frio | 3 | **nuevo** |

### Plantas

| id | nombre | zona | fuente | de / vía | condición | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|---|
| `flor_luna` | Flor de luna | bosque | recoger | – | – | vital, tinta | 1 | hay |
| `flor_ardiente` · `flor_rocio` · `flor_chispa` · `flor_escarcha` · `petalos` | (las 5 de la flor) | bosque | reacción | flor_luna / fuego · agua · rayo · hielo · viento | – | tinta + la del elemento | 2 | hay |
| `lavanda` | Lavanda | bosque | recoger | – | – | vital, viento | 1 | hay |
| `baya` | Bayas | bosque | recoger | – | – | vital | 1 | hay |
| `helecho` | Helecho | bosque | recoger | – | – | vital | 1 | hay |
| `flor_silvestre` | Flor silvestre | bosque | recoger | – | – | tinta | 1 | hay |
| `alga_cueva` | Alga de cueva | cueva | recoger | – | `casilla(x,y).helada` | agua, vital | 2 | hay |
| `alga_seca` | Alga seca | cueva | reacción | alga_cueva / fuego | – | calor, tierra | 2 | hay |
| `alga_cargada` | Alga cargada | cueva | reacción | alga_cueva / rayo | con la charca electrificada | electrico, agua | 3 | **nuevo** |
| `musgo_cueva` | Musgo de cueva | cueva | recoger | – | junto a la cascada (el `musgo_colgante` del decorado) | agua, vital, tinta | 1 | **nuevo** (modelo: `musgo_colgante`) |
| `helecho_cueva` | Helecho de cueva | cueva | recoger | – | – | vital | 1 | **nuevo** (modelo: `helechos_cueva`) |

### Raíces

| id | nombre | zona | fuente | de / vía | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|
| `raiz` | Raíz | bosque | recoger | – | tierra, vital | 1 | hay |
| `raiz_cenizas` · `raiz_hinchada` · `raiz_magnetica` | (las 3 de la raíz) | bosque | reacción | raiz / fuego · agua · rayo | tierra + la del elemento | 2 | hay |
| `cristal_tierra` | Cristal de tierra | bosque | reacción | raiz / tierra | tierra | 3 | hay |

### Minerales

| id | nombre | zona | fuente | de / vía | condición | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|---|
| `piedra` | Piedra | todas | recoger | – | – | tierra | 1 | hay |
| `mineral_veta` | Mineral de veta | cueva | golpe | veta / tierra | `mineral=si` | tierra, resonante | 2 | hay |
| `esquirla_cristal` | Esquirla de cristal | cueva | golpe | cristal / golpes:2 | – | resonante | 2 | hay |
| `basalto` | Basalto | cueva | recoger | – | `casilla(x,y).roca` (10 s) | tierra, calor | 2 | hay |
| `obsidiana` | Obsidiana | cueva | reacción | lava / **hielo** | la lava enfriada con hielo y no con agua | tierra, frio, calor | 3 | **nuevo**: separa hielo y agua en la lava, que hoy dan lo mismo |
| `polvo_cristal` | Polvo de cristal | cueva | golpe | esquirla_cristal / tierra (en la bolsa no: sobre una esquirla tirada) | – | resonante, tinta | 3 | **nuevo**: pigmento azul del pulso |
| `cristal_cargado` | Cristal cargado | cueva | reacción | esquirla / rayo (un cristal golpeado con rayo) | – | resonante, electrico | 3 | **nuevo** |
| `ceniza_geoda` | Polvo de geoda | cueva | romper | geoda (al explotar deja polvo) | – | resonante, tierra | 2 | **nuevo** |

### Animal y botín

| id | nombre | zona | fuente | de / vía | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|
| `colmillo_goblin` | Colmillo de goblin | todas | enemigo | goblin (60 %) | tierra | 2 | hay |
| `jiron_escudo` | Jirón de escudo | todas | enemigo | goblin con escudo, cuando el escudo arde | calor, tierra | 2 | **nuevo** (premia la reacción escudo + fuego) |
| `oro` | Oro | todas | romper, cofre | – | – | – | hay (no es ingrediente) |

### Épicos (morado) y clave

| id | nombre | zona | fuente | dónde | etiquetas | pot. | estado |
|---|---|---|---|---|---|---|---|
| `nucleo_eco` | Núcleo de eco | cueva | cofre | estatuas de C1 (con ᚱ) | resonante, raro | 5 | hay |
| `geoda_resonante` | Geoda resonante | cueva | cofre | tras una pared hueca de C3 (con ᚱ), aún sin poner | resonante, tierra, raro | 4 | hay (sin sitio en el mapa) |
| `llave` | Llave de la Cueva | cueva | cofre | C4 | – | – | **nuevo** como objeto: hoy es solo la flag `…c4.llave`. Iría en la categoría `clave` (`Objetos.CLAVE`), con el icono `llave_pequena` |

**Total: 42 filas** (las variantes de flor y raíz, una por fila en el TSV): 31 ya están en `DATOS` y 11 son nuevas (la llave como objeto incluida; el oro no cuenta: no es ingrediente). Todos los nuevos salen de piezas que ya están en el mundo, así que no piden mecánica nueva. Las dos excepciones piden una reacción más: `obsidiana` (hielo sobre lava) y `jiron_escudo`.

## 5. Cómo se integraría (cuando se apruebe)

1. **Un Resource por fila** (`RecogibleData.tres`, como `RuneData`) o **una tabla** `nucleo/recogibles.gd` que lea el TSV. Se recomienda la tabla: Pablo la edita en una hoja de cálculo y los cambios se ven en git.
2. `Objetos.DATOS`, `PLANTAS` y `MINERALES` **se generan** desde ella, para no romper a quien los lee hoy: `Objetos.nombre`, `Recolectable3D`, `MineralPulso`, la bolsa, `AvisoObjeto`.
3. La **síntesis** solo lee `etiquetas` y `potencia`. Una receta pide, por ejemplo, «`vital` ≥ 4 y `calor` ≥ 2». La prueba de una receta es entonces una prueba de datos, sin escena.
4. Una prueba sin escena comprueba la tabla:
   - cada `de` existe;
   - cada `via` es un elemento, `pulso` o `golpes:n`;
   - cada etiqueta está en el vocabulario de §3;
   - los épicos tienen potencia ≥ 4.

## 6. Decisiones para Pablo

1. ¿Las etiquetas de §3 te sirven, o la síntesis será por **ingrediente concreto** (receta = lista de ids)? Lo primero escala mejor; lo segundo se lee más fácil en el libro.
2. ¿Las tres setas de color dan objetos distintos? `MATERIALES_CUEVA.md` recomendaba que no.
3. ¿Cuáles de los 11 nuevos entran? Por orden de lo que aportan: `obsidiana`, `polvo_cristal`, `llave` (objeto), `esporas_luminosas`, `musgo_cueva`.
