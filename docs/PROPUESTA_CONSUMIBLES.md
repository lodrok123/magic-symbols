# Propuesta de consumibles (10/11)

Desarrollo del apartado 7 de `docs/REVISION_OBJETOS_SINTESIS.md` con las seis familias que pidió Pablo: pociones en tres calidades, antídotos de estado, pigmentos, elixires mixtos, oro y objetos lanzables. Escrito por Juego. No hay nada implementado.

Inspiración: Breath of the Wild y Tears of the Kingdom (elixires, cocina y frutos lanzables), Genshin (aceites y pociones elementales) y Elden Ring (vasijas lanzables con recipiente). Las fuentes están al final.

## 1. Tres reglas para que todo encaje

1. **Un consumible no hace lo que hace un hechizo.** O hace algo que la magia no hace (curar, proteger, iluminar, distraer), o hace poco y barato lo que haría un hechizo, sin gastar tinta.
2. **Cada calidad es su propia receta** (decidido el 10/11, Pablo). La poción menor, la normal y la mayor son tres recetas que piden más etiquetas cuanto mejor es la poción. No hay cálculo de potencia: lo que se ve en la lista de recetas es lo que sale.
3. **Todo cabe en las tablas de hoy.** Cada consumible es una fila de `objetos.tsv` con su `uso` y su `efecto` en pares clave=valor, que es lo que ya lee `Consumibles`. Las recetas siguen pidiendo etiquetas en `recetas.tsv`.

## 2. Tres maneras de usar un consumible

| Uso | Tecla | Qué hace | Hoy |
|---|---|---|---|
| **Beber** | Q usa, R cambia | se gasta y hace efecto en la jugadora | existe (`uso=equipar`) |
| **Lanzar** | G lanza el elegido; Alt abre la rueda para elegir | cae y hace efecto donde aterriza | nuevo |
| **Cargar** (pigmentos) | desde la mochila, o con un hueco propio | tiñe la tinta y potencia el siguiente hechizo | existe, con otro efecto |

Con tres usos, el HUD necesita tres huecos: lo que se bebe, lo que se lanza y el pigmento cargado.

### Rueda de lanzables (decidido el 10/11, Pablo)

- **Seis huecos, uno por dirección**, en una rueda hexagonal: arriba, arriba-derecha, abajo-derecha, abajo, abajo-izquierda y arriba-izquierda.
- **Alt mantenido abre la rueda.** Se elige con la dirección del ratón desde el centro de la pantalla, en sectores de 60°, y al soltar Alt queda elegido. Mientras está abierta, el tiempo va a un cuarto de velocidad, como la rueda de BotW. Así elegir en combate no castiga.
- **La tecla de lanzar es la G.** Mantenerla enseña el arco hacia el ratón y la casilla donde caerá; soltarla lanza el que esté elegido.
- **La rueda es un acceso rápido: lo que va en cada hueco se elige en la mochila** (decidido el 10/11, Pablo). Ver abajo.

### Cómo se rellena la rueda

Así lo hacen juegos parecidos:

| Juego | Cómo se asigna |
|---|---|
| Elden Ring | en el menú de equipo se ponen objetos en huecos rápidos y en una bolsa con direcciones; el hueco recuerda el objeto aunque se acabe |
| Monster Hunter World | menú radial que se configura en la bolsa, con varios juegos de rueda guardados |
| Tears of the Kingdom | rueda con todo lo que llevas, ordenable por uso o por tipo; sin asignar a mano |

Propuesta, tomando lo mejor de cada uno:

1. **En la mochila, cada lanzable tiene la acción «Poner en la rueda».** Al pulsarla sale la rueda pequeña sobre la mochila y se elige el hueco con el ratón o las flechas. También se puede arrastrar el icono a un hueco.
2. **Un objeto solo puede estar en un hueco.** Ponerlo en otro lo quita del anterior. Ponerlo en un hueco ocupado cambia los dos de sitio.
3. **El hueco recuerda el objeto aunque se acabe**, como en Elden Ring. Sale apagado con un 0 y vuelve a funcionar en cuanto coges otro. Así la posición no se pierde y la mano se la aprende.
4. **Lanzable nuevo, hueco libre.** La primera vez que coges un lanzable, si hay un hueco vacío, entra solo. Si no hay, se queda en la mochila y el aviso dice que se puede poner en la rueda.
5. **Quitar de la rueda** desde la mochila o desde la propia rueda con clic derecho.
6. **El lanzable elegido** sale en el HUD junto al icono de la G, con su número.

**Con esto sobra la duda de los siete lanzables:** hay siete para elegir y seis huecos, y cada jugadora lleva los suyos.

**Más adelante**, si hace falta: dos ruedas que se cambian con la rueda del ratón, como los juegos de rueda de Monster Hunter. Y dejar que en la rueda entren también los bebibles, como la bolsa de Elden Ring. Hoy no lo propongo: Q y R ya cubren lo que se bebe.

**Datos.** `Estado.rueda`: una lista de seis ids de objeto, con "" para el hueco vacío, más `Estado.rueda_elegido` con el hueco elegido. Viaja en la partida por `Estado.a_dic` y `desde_dic`, igual que `consumible_equipado`. La rueda en sí y la acción de la mochila son de Pipeline; la lógica de asignar y lanzar, de Juego.

**Teclas que hay que mirar antes:**

| Tecla | Hoy |
|---|---|
| G | libre en el mapa de controles; la usan la maqueta de pruebas para enseñar u ocultar la hierba y el libro para grabar gestos, las dos de depuración |
| Alt | libre en el mapa de controles; solo la usa Alt+F11 para invocar un goblin de prueba |

Las dos se pueden usar. La G de la maqueta hay que moverla a otra tecla, o dejarla solo con el modo depuración. Las dos acciones nuevas, «lanzar» y «rueda», entran en `nucleo/controles.gd` y se pueden reasignar como las demás.

## 3. Pociones de vida: tres calidades

Tres recetas aparte (decidido el 10/11). Cada una pide más que la anterior, y la mayor pide algo de tinta para que haga falta ir a por flores o panal:

| Receta | Pide | Dónde | Cura | Extra | Ingredientes típicos |
|---|---|---|---|---|---|
| Poción menor (`pocion`) | vital ≥ 3 | hoguera y alquimista | 40 | - | bayas, seta, helecho |
| Poción normal (`pocion_grande`) | vital ≥ 6, agua ≥ 2 | solo alquimista | 80 | - | seta asada, alga, seta empapada |
| Poción mayor (`pocion_mayor`) | vital ≥ 10, agua ≥ 3, tinta ≥ 2 | solo alquimista | 120 | regenera 2/s durante 10 s | panal, flor de luna, musgo, alga |

Al implementarlo (10/11) se mantuvieron las curas de hoy, 40 y 80, para no cambiar la poción que ya existe; la mayor sube a 120.

Las recetas de hoy encajan: `pocion` (vital ≥ 3) pasa a ser la menor, y `pocion_grande` (vital ≥ 6, agua ≥ 2) pasa a ser la normal.

- Las tres son objetos distintos (`pocion_menor`, `pocion`, `pocion_mayor`) para que cada una tenga su pila y su icono. La `pocion_grande` de hoy pasa a ser la mayor.
- **El tiempo de beber es el mismo en las tres.** Lo que cambia es cuánto vale el hueco de la mochila.
- La mejora «Poción más dulce» sigue sumando +10 a las tres.
- La infusión de brezo se queda como curación lenta: regenera 3/s durante 12 s y no corta el combate.

## 4. Antídotos de estado

Uno por cada estado que sufre la jugadora. Cada antídoto **quita el estado y da inmunidad 90 s**. Los estados ya existen en `Jugador3D` y en `estados_mundo.tsv`.

| Antídoto | Quita | Inmunidad 90 s a | Receta | Hoy |
|---|---|---|---|---|
| Antídoto | veneno | veneno, nubes y flechas del chamán | tóxico ≥ 2, vital ≥ 2 | existe |
| Brasa embotellada | frío: ralentizada y aguante del frío | frío | calor ≥ 3, vital ≥ 1 | existe (`abrigo`) |
| Frasco de frescor | quemada y aguante del calor | calor y fuego del suelo | frío ≥ 3, agua ≥ 1 | existe (`frescor`) |
| **Savia aislante** | aturdida y suelo electrificado | rayo y tormenta | protección ≥ 2, tierra ≥ 2 (resina, corteza) | nueva |

Los antídotos tienen una sola calidad: tres recetas por cada uno serían doce recetas para lo mismo.

## 5. Elixires mixtos

La receta sigue una regla fija: contra el frío, ingredientes de calor; contra el calor, de frío; contra el veneno, tóxicos; contra el rayo, de protección.

Protegen de dos estados a la vez, durante menos tiempo que los antídotos. **No quitan el estado**: solo previenen. Así el antídoto sigue siendo lo que se bebe cuando ya te ha pillado.

| Elixir | Protege de | Receta (las dos etiquetas) | Para qué zona |
|---|---|---|---|
| Elixir del pantano | veneno y frío | tóxico ≥ 2, calor ≥ 2 | pantano de noche |
| Elixir de la ceniza | veneno y calor | tóxico ≥ 2, frío ≥ 2 | volcán con gases |
| Elixir de la ventisca | frío y rayo | calor ≥ 2, protección ≥ 2 | cumbre con tormenta |
| Elixir del horno | calor y rayo | frío ≥ 2, protección ≥ 2 | forja, minas |
| Elixir templado | frío y calor | calor ≥ 2, frío ≥ 2 | zonas que alternan |
| Elixir del filtro | veneno y rayo | tóxico ≥ 2, protección ≥ 2 | pantano con tormenta |
| **Panacea** (épica) | los cuatro | raro ≥ 4 y las cuatro etiquetas | jefes |

- Duración: 60 s, una sola calidad. La panacea dura 45 s.
- **Los seis mixtos no tienen que existir a la vez.** Propongo empezar con dos, los que pidan las zonas que se hagan primero.

## 6. Pigmentos: el siguiente hechizo, ×1,5

**Qué cambia respecto a hoy.** Hoy el pigmento dura 60 s y da +50 % de daño o la mitad de coste a un elemento (`Tinta.PIGMENTOS`). La propuesta:

- **Se carga uno y se gasta en el siguiente hechizo** de su elemento.
- Ese hechizo sale con **daño ×1,5 y geometría ×1,5**: alcance, semiejes y radio. Es como un glifo de potenciación gratis.
- **Si lanzas otro elemento, el pigmento no se pierde.** Sigue cargado hasta que lances el suyo. Así nunca se tira por error.
- **Solo uno cargado.** Cargar otro devuelve el anterior a la mochila.
- El ×1,5 va después de los glifos y respeta los topes físicos. Por ejemplo, la altura no pasa de 4 niveles.

**Un pigmento por elemento** (decidido el 10/11: cada pigmento solo potencia hechizos de su elemento):

| Pigmento | Elemento | Color | Ingredientes |
|---|---|---|---|
| Resina carmesí | fuego | rojo | resina, flor ardiente |
| Azul de rocío | agua | azul claro | flor de rocío, alga |
| Ocre del túmulo | tierra | ocre | raíz, cristal de tierra |
| Blanco de escarcha | hielo | blanco azulado | flor de escarcha, seda |
| Ámbar volcánico | rayo | ámbar | flor cargada, cristal cargado |
| Verde de musgo | viento | verde | pétalos, pluma |
| Azul de eco | pulso | azul intenso | polvo de cristal, esporas luminosas |

Azul de rocío y blanco de escarcha son nuevos. Los cinco de hoy cambian de efecto pero mantienen nombre y color.

**Cómo se ve:**

- En el HUD, junto a los frascos de tinta, hay **una fila de frascos pequeños, uno por pigmento que llevas**, con su color y su número.
- Al cargar uno, la **barra de tinta y el aro del libro se tiñen de su color** hasta que el hechizo sale.
- El hechizo potenciado deja la estela teñida. Así se entiende de dónde vino el ×1,5.

**Quién toca qué:**

| Contexto | Parte |
|---|---|
| Juego | `Tinta.PIGMENTOS` pasa de «dura 60 s» a «una carga»; recetas y objetos |
| Hechizos | aplicar el ×1,5 al lanzar (`Lanzador3D`, `Hechizo`) y gastar la carga |
| Pipeline | la fila de frascos y el tinte del HUD |

## 7. ¿Hace falta el oro?

**Sí, pero solo si tiene en qué gastarse.** Hoy entra mucho y no sale: Bosque_02 da unos 360 en cofres, y casi no hay en qué gastarlo: la barrera de la guardabosques y la velocidad del alquimista, las dos en el Bosque_01. Sin tienda, el oro es un número que sube.

**Decidido (10/11, Pablo): se mantiene el oro, para comprar en tiendas materiales y objetos como pociones y antídotos.**

Hoy no hay tiendas: solo la compra suelta de la barrera en `bosque_3d.gd`. Propuesta para hacerlas como el resto, con datos: una tabla `nucleo/datos/tiendas.tsv` con `tienda`, `objeto`, `precio`, `existencias` (o «sin fin») y `se_desbloquea` (una flag o una mejora), y una sola pantalla de compra que lea cualquier tienda. El alquimista y la librera serían las dos primeras.

**Implementado el 11/11 (diario 472):** `nucleo/datos/tiendas.tsv` y `nucleo/tiendas.gd` (oferta, compra, existencias guardadas, desbloqueo por flag). El alquimista vende pociones, antídotos, el tónico e ingredientes comunes; la librera de Bosque_02, flores, polvo de cristal, el bulbo de luz, pociones y antídotos un poco más caros y pigmentos. Hablar con ellos emite `Tiendas.tienda_abierta`: falta la pantalla de compra (Pipeline).

Las salidas que propongo para el oro, de más a menos importante:

1. Comprar consumibles básicos al alquimista: poción menor y antídoto.
2. Comprar **recetas**. Una receta comprada se conoce para siempre; las demás se descubren al tener sus ingredientes.
3. La tasa del alquimista al terminar una mejora.
4. Tarros para los lanzables (ver el apartado 8).

Si no se quiere tienda, la alternativa es quitar el oro y que todo sea trueque de ingredientes. Pero entonces los jarrones y los enemigos pierden la mitad de su premio. Lo recomiendo mantener: es lo que hacen EoW, BotW y Genshin.

## 8. Objetos lanzables

**Idea.** Se lanzan en arco, como un hechizo sin glifos. Al caer hacen su efecto en 1 casilla y usan el mismo contrato que los hechizos para hablar con el mundo (`on_spell_hit`, `Materia`). Un seto prende con una bomba de resina igual que con fuego.

**Regla de diseño.** Los lanzables hacen sobre todo lo que la magia **no** hace: luz, humo, frenar y atraer. Los elementales son débiles y baratos: sirven para no gastar tinta o antes de tener ese elemento.

**Lista de Pablo (10/11).** Siete lanzables, cada uno con su límite. Quedan fuera la piedra y el capullo confuso del primer borrador.

| Lanzable | Qué hace | Límite | Ingredientes | Sistema que usa | Falta |
|---|---|---|---|---|---|
| Bulbo de luz | ilumina un punto | dura poco: 60 s | esporas luminosas, resina | estado `oscuridad`, `Mundo3D.iluminar` | nada |
| Bomba de humo | corta la visión | no borra la alerta: los enemigos van a investigar | esporas ×2 | `NubeVeneno3D` sin daño | estado «investigar» en `Combate3D` |
| Tarro de baba | ralentiza una zona pequeña | no inmoviliza para siempre: 6 s | baba de limo ×2 | `EstadosSuelo3D` | estado de suelo «pegajoso» |
| Cebo de miel | atrae fauna compatible | no funciona con cualquier enemigo: solo animales | panal, bayas | IA de lobernos y canouros | ir hacia un punto que no es la jugadora |
| Bomba de resina | prende lo inflamable | poco daño y área pequeña: 1 casilla, 10 de daño | resina, carbón | `Materia`, fuego | nada |
| Bola helada | congela una superficie pequeña | plataforma breve: 1 casilla, 6 s | seta helada, seda | `EstadosSuelo3D`, hielo | nada |
| Fruto chispa | activa o electrifica un punto | también daña a la jugadora | flor cargada, alga cargada | rayo sobre agua, fuego amigo suave | nada |

**Cómo limitarlos.** Hay dos maneras:

- **Pila de 5 por tipo.** Es lo más sencillo y ya existe (`pila` en `objetos.tsv`).
- **Tarros**, como las vasijas de Elden Ring. Cada lanzable necesita un tarro vacío para fabricarse, y el tarro vuelve a la mochila al lanzarlo. El número de tarros se sube encontrándolos y comprándolos. Es más elegante, porque el límite es tuyo y no del objeto.

Recomiendo empezar con la pila y pasar a tarros si se quiere un gasto más para el oro.

## 9. Cómo queda en los datos

**`objetos.tsv`, columna `uso`:** `equipar` pasa a ser `beber`; nuevos `lanzar` y `pigmento`.

**Columna `efecto`.** Las claves que ya lee `Consumibles`: `cura`, `dura`, `tasa`, `cura_estado`, `inmune`, `resiste`, `frascos`. Claves nuevas:

| Clave | Ejemplo | Para |
|---|---|---|
| `regen` | `regen=2;dura=10` | la poción mayor |
| `previene` | `previene=veneno,frio;dura=60` | elixires mixtos: protege sin quitar |
| `carga` | `carga=1;mult=1.5` | pigmentos de una carga |
| `lanza` | `lanza=luz;radio=3;dura=60` | lanzables |

**`recetas.tsv`:** sin columnas nuevas. Cada calidad de poción es una fila más con sus etiquetas y su `da`, como las de hoy.

## 10. Cuántos consumibles salen

| Familia | Cuántos |
|---|---|
| Pociones de vida | 3, más la infusión |
| Antídotos | 4 |
| Elixires mixtos | 6 y la panacea; empezar con 2 |
| Pigmentos | 7 |
| Lanzables | 7 (lista de Pablo); empezar con 4 |
| Otros de hoy | tónico de tinta y bálsamo protector |

Con todo son unos 33, frente a los 13 de hoy.

**Primera tanda: 16 (aprobada el 10/11, Pablo).**

| Familia | Cuáles |
|---|---|
| Pociones | menor, normal y mayor |
| Antídotos | antídoto, brasa embotellada, frasco de frescor y savia aislante |
| Elixires mixtos | elixir del filtro (veneno y rayo: el chamán y la tormenta del Bosque) y elixir templado (frío y calor: la cueva volcánica y la helada) |
| Pigmentos | los siete |
| Lanzables | bulbo de luz, bomba de resina, bola helada y fruto chispa |

**Segunda tanda hecha el 11/11** (diario 474): bomba de humo, tarro de baba y cebo de miel, con el estado «investigar» de los enemigos, el suelo pegajoso y el estado «cebo» de los animales.

Los cuatro lanzables son los que no necesitan código nuevo de enemigos ni de suelo. La piedra del primer borrador ya no está en la lista de Pablo, y la bomba de humo, el tarro de baba y el cebo de miel van en la segunda tanda, junto con el estado «investigar», el suelo pegajoso y la IA de ir a un punto que necesitan.

## 11. Lo que necesito que decidas

1. ~~**Pigmentos:** ¿atados a su elemento, o sirven para cualquier hechizo?~~ **Decidido (10/11, Pablo): atados a su elemento.**
2. ~~**Calidad por potencia de los ingredientes:** ¿sí, o tres recetas separadas?~~ **Decidido (10/11, Pablo): tres recetas aparte.**
3. ~~**Oro:** ¿se mantiene, con tienda en el alquimista?~~ **Decidido (10/11, Pablo): se mantiene para tiendas de materiales y objetos.**
4. **Lanzables:** ¿pila de 5 o tarros?
5. ~~**Primera tanda:** ¿te vale la de 16 del apartado 10?~~ **Decidido (10/11, Pablo): sí.**

## Fuentes

- [Elixir, Zelda Wiki (fandom)](https://zelda.fandom.com/wiki/Elixir) y [Elixir, zeldawiki.wiki](https://zeldawiki.wiki/wiki/Elixir): duración por ingredientes y cocina crítica.
- [Muddle Bud, zeldawiki.wiki](https://zeldawiki.wiki/wiki/Muddle_Bud) y [Tears of the Kingdom Materials, Zelda Dungeon](https://www.zeldadungeon.net/wiki/Tears_of_the_Kingdom_Materials): capullo confuso, semilla luminosa y champiñón de humo.
- [How to use Brightbloom Seeds, Prima Games](https://primagames.com/gaming/how-to-use-brightbloom-seeds-in-tears-of-the-kingdom).
- [Cracked Pot](https://eldenring.wiki.fextralife.com/Cracked+Pot), [Fire Pot](https://eldenring.wiki.fextralife.com/Fire+Pot) y [Ritual Pot](https://eldenring.wiki.fextralife.com/Ritual+pot), Elden Ring Wiki (Fextralife): vasijas lanzables y recipientes.

## 12. Implementado (10/11, primera tanda)

Hecho por Juego, probado con `herramientas/escenario_consumibles_tanda.gd`.

| Parte | Dónde | Estado |
|---|---|---|
| Los 16 objetos y sus recetas | `nucleo/datos/objetos.tsv`, `recetas.tsv`, `fuentes.tsv`, `nucleo/textos_objetos.gd` | hecho |
| Pociones: todo lo que lleva `cura` se bebe; la mayor regenera | `nucleo/consumibles.gd`, `jugador/jugador_3d.gd` | hecho |
| Antídotos: quitan frío, calor y rayo además del veneno; la inmunidad para esos estados | `Jugador3D.curar_estado`, `aplicar_estado`, `dano_ambiental` | hecho |
| Elixires mixtos: `inmune` admite una lista | `nucleo/consumibles.gd` | hecho |
| Pigmentos de una carga; el anterior vuelve a la mochila | `nucleo/tinta.gd`, `nucleo/sintesis.gd` | hecho el daño ×1,5; la geometría espera a Hechizos |
| Rueda de 6 huecos, con guardado | `Estado.rueda`, `poner_en_rueda`, `quitar_de_rueda`, `elegir_hueco` | hecho la lógica; la rueda en pantalla espera a Pipeline |
| Lanzar con G | acción `lanzar_objeto` en `nucleo/controles.gd` y `project.godot`; `Jugador3D.lanzar_objeto` | hecho |
| Los cuatro lanzables | `nucleo/lanzables.gd`, `objetos/lanzable_3d.gd` | hecho |

**Decisión que tomé al implementarlo:** los lanzables se limitan con la pila de 5. «Pila o tarros» sigue abierta.

**Lo que queda en otros contextos:**

- **Hechizos.** Hoy el pigmento se gasta al cobrar la tinta del hechizo de su elemento y vale 0,8 s más para ese hechizo, porque el lanzador cobra antes de construirlo. Lo limpio es que el lanzador llame a `Tinta.consumir_pigmento(elemento)` tras construir el hechizo y aplique `Tinta.mult_geometria(elemento)` a alcance y semiejes. El de eco necesita que quien calcula el recargo de ᚱ pregunte `quita_recargo` y lo gaste con `consumir_pigmento("", "raido")`.
- **Pipeline.**
  - La rueda en pantalla con Alt y la acción «Poner en la rueda» de la mochila.
  - La fila de frascos de pigmento y el tinte de la barra mientras hay uno cargado (`Tinta.pigmento_cargado`, `color`).
  - Los iconos de los 10 objetos nuevos.
  - La G de la maqueta sigue enseñando la hierba si nadie la atiende antes. La jugadora la marca como atendida, pero conviene moverla a otra tecla.
