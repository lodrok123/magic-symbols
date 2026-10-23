# Materiales de la Cueva

Lista del 23/10/2026 para la Cueva (`PLAN_BOSQUE_EOW.md` §6) con las tres calidades de `PLAN_PULSO_RESONANTE.md` §7:

- **común**: materiales que se consiguen;
- **épico**: materiales de mejora;
- **legendario**: glifos.

Parte del catálogo que ya hay (`nucleo/objetos.gd`: `DATOS` y `PLANTAS`). En la columna «estado», **hay** significa que el objeto ya
existe en `DATOS` y **nuevo**, que hay que darlo de alta.

## Regla de la Cueva

Como en el resto del juego, **los ingredientes salen de hacer reaccionar algo del mundo con un elemento**: una seta tal cual es una
seta; electrificada es otro ingrediente. En la Cueva cada sala tiene su elemento, así que la reacción **natural** de cada material
está a mano en su sala. Las demás obligan a volver con otro hechizo.

## Comunes (gris o blanco)

### Plantas y hongos (se recogen con E y reaccionan con hechizos)

| id | nombre | dónde | cómo | estado |
|---|---|---|---|---|
| `seta` | Seta | C1, C2, C6 (las tres variantes de color) | E | hay |
| `seta_asada` | Seta asada | C1 (braseros) | fuego a una seta | hay |
| `seta_electrificada` | Seta electrificada | C5 (la fuente) | rayo a una seta | hay |
| `seta_helada` | Seta helada | C5 | hielo a una seta | hay |
| `seta_humeda` | Seta empapada | C3 | agua a una seta | hay |
| `esporas` | Esporas | cualquiera | viento a una seta | hay |
| `seta_resonante` | Seta resonante | C1 (junto al cristal que late) | la seta madura con el pulso (`PLAN_PULSO_RESONANTE.md` §4) | **nuevo** |
| `alga_cueva` | Alga de cueva | C5, en el lecho de la charca | E con la charca **helada** (se ve atrapada en el hielo) | **nuevo** |
| `alga_seca` | Alga seca | C5 | fuego al alga | **nuevo** |

**Las tres setas de color.** Hoy las tres variantes (roja, azul y marrón) dan la misma `seta`: el color solo cambia el modelo. Hay
dos opciones:

1. **Mantenerlo** (recomendado para la Fase 1): el color es variedad visual y lo que cuenta es la reacción.
2. **Cada color, un ingrediente base distinto** (`seta_roja`, `seta_azul`, `seta`), con la misma tabla de reacciones. Así salen 15
   ingredientes en vez de 5. Es más rico, pero llena la bolsa y la mitad no tendría uso en recetas todavía.

### Minerales (se sacan golpeando o rompiendo)

| id | nombre | dónde | cómo | estado |
|---|---|---|---|---|
| `piedra` | Piedra | todas | E en piedras sueltas | hay |
| `mineral_veta` | Mineral de veta | C2 y C4 (las vetas del pulso) | tierra a una veta: suelta un trozo | **nuevo** |
| `esquirla_cristal` | Esquirla de cristal | C1, C4 (cristales) y jarrones | golpear un cristal resonante dos veces, o romper un jarrón | **nuevo** |
| `basalto` | Basalto | C3 | E en la roca de la lava **enfriada** antes de que vuelva a ser lava (10 s) | **nuevo** |
| `cristal_tierra` | Cristal de tierra | — | tierra a una raíz (no hay raíces en la Cueva) | hay, no se usa aquí |

### Botín

| id | nombre | dónde | cómo | estado |
|---|---|---|---|---|
| `oro` | Oro | jarrones (C1, C6), cofres pequeños | romper o abrir | hay |
| `colmillo_goblin` | Colmillo de goblin | C4 | lo suelta cada goblin | **nuevo** |
| `pocion` | Poción de vida | cofre de C2 (nicho de la columna) | abrir | hay |

## Épicos (morado): materiales de mejora

Uno por secreto. **Decisión de Pablo del 23/10 (`PLAN_PULSO_RESONANTE.md` §10, punto 4):** los épicos son **ingredientes para mejorar
al personaje** (vida, tinta, pigmentos nuevos, quizá ropa), **no** variables de un glifo. La mejora concreta de cada uno (cuánta vida,
qué pigmento) está por diseñar; hoy son objetos de la bolsa con calidad épica.

| id | nombre | dónde | qué mejora | estado |
|---|---|---|---|---|
| `nucleo_eco` | Núcleo de eco | cofre épico tras las **estatuas** de C1 (secuencia de pulsos, hace falta el glifo) | al personaje (por decidir) | **hecho en datos** (el cofre es de la fase 3) |
| `geoda_resonante` | Geoda resonante | tras una **pared hueca** de C3, que se encuentra con el eco del pulso | al personaje (por decidir) | **hecho en datos** (la pared es de la fase 3) |

Los dos piden el glifo, así que son la razón para volver a la Cueva tras el cofre legendario.

## Legendario (dorado): el glifo

| id | nombre | dónde | qué da | estado |
|---|---|---|---|---|
| `glifo_resonancia` | Glifo de resonancia | cofre legendario de C6 | la propiedad `resuena`, escrita en el libro con su animación | **nuevo** (nombre y runa por decidir) |

## Objetos clave (sin calidad)

| id | nombre | dónde | para qué | estado |
|---|---|---|---|---|
| `llave` | Llave | cofre de C4 | abre la puerta de C6 | hay (hoy es el flag `cueva.c4.llave`; falta que entre en la bolsa) |

## Reparto por sala

| sala | comunes | épico | legendario |
|---|---|---|---|
| C1 · Boca | 3 setas, setas asadas, seta resonante, esquirla, oro en jarrones | núcleo de eco (con glifo) | — |
| C2 · Grietas | 2 setas, mineral de veta, poción del nicho | — | — |
| C3 · Lava | seta empapada, basalto | geoda resonante (con glifo) | — |
| C4 · Cerrada | colmillos, esquirla, mineral de veta | — | — |
| C5 · Charca | setas electrificada y helada, alga de cueva y alga seca | — | — |
| C6 · Santuario | 3 setas, oro | — | glifo de resonancia |

En una sola pasada, sin glifo, salen unos **10 comunes distintos**. Al volver con el glifo, **2 épicos**.

## Hecho el 23/10 (datos, recolectables, botín y avisos)

- **Datos** (`nucleo/objetos.gd`): los 9 materiales están en `DATOS` (`seta_resonante`, `alga_cueva`, `alga_seca`, `mineral_veta`,
  `esquirla_cristal`, `basalto`, `colmillo_goblin`, `nucleo_eco`, `geoda_resonante`), con las formas de siempre (seta, hoja, piedra,
  cristal, raíz). Campo `calidad`: `comun` (por defecto), `epico` y `legendario`; `Objetos.CALIDADES` da el color (gris/blanco,
  morado, dorado) y lo que dura el aviso (1,4 · 3 · 4,5 s). `Objetos.calidad(id)`, `color_calidad(id)`, `duracion_aviso(id)`.
  El glifo de resonancia (legendario) **no** es un objeto de `DATOS`: es un glifo del libro y lo da la secuencia del cofre.
- **Iconos:** los 9 PNG de 128 × 128 (`presentacion/ui/laminas/objeto_<id>.png`, hechos con `iconos.py`; los épicos con destellos
  morados, la seta resonante con ondas). Sin PNG, `Objetos.dibujar` pone un aro del color de la calidad en los no comunes.
- **`PLANTAS`:** fila `alga` (base `alga_cueva`; `fuego` → `alga_seca`).
- **Recolectables con condición:** piezas nuevas de mapa `alga` y `basalto` (Recolectable3D con la clave `coge_si=<expresión de si=>`).
  Mientras no se cumple, la planta **no se ve, no se coge y no reacciona**; cuando se cumple aparece, y si la condición se pierde
  (el hielo se funde, la lava vuelve) desaparece. Se mira cada 0,2 s. El alga es la `planta_agua` y el basalto, `rocas_pequenas` (×1,5),
  teñidas con el color del objeto: sin arte nuevo.
  - alga: `coge_si=casilla(x,y).helada`.
  - basalto: `coge_si=casilla(x,y).roca`. **Estado nuevo de casilla `roca`** = lava enfriada que aún no ha vuelto a ser lava
    (`Lava3D.es_roca(c)`); vale en cualquier `si=`.
- **Minerales (gancho, sin cablear):** `Objetos.MINERALES` dice qué da cada reactivo (veta + tierra → `mineral_veta`; cristal
  resonante con 2 golpes y jarrón roto → `esquirla_cristal`) y `Objetos.mineral_de(reactivo, vía)` lo consulta. Nadie lo llama aún:
  los reactivos de pulso son de la fase 3.
- **Botín de goblin** (`enemigos/botin_goblin.gd`): al caer (no ahogado, no elemental) cada goblin hace una tirada con
  `BotinGoblin.PROB_COLMILLO` = 0,6 y, si sale, el `colmillo_goblin` va **directo a la bolsa** con el aviso de su calidad y un texto
  flotante donde cayó. No sale en el suelo para recoger (no hay pieza de botín de objeto; hoy solo las monedas lo son).
- **Aviso al coger** (`nucleo/aviso_objeto.gd`, `AvisoObjeto.mostrar`): común, el `X (+1)` de siempre; épico, texto claro con el
  **borde morado**, 3 s y un **destello** de luz morada sobre la jugadora. El legendario usa el mismo camino con el borde dorado y
  4,5 s, pero hoy no hay ningún objeto legendario: lo hace la secuencia del cofre. `Lanzador3D.avisar` admite `borde` y `duracion`.

### Colocado en la Cueva (`mundo/datos_nivel/mapas/Cueva.txt`)

| sala | puesto |
|---|---|
| C3 | 2 basaltos (13,3) y (14,6) sobre la lava; 2 setas (11,3) y (11,6) para empaparlas |
| C5 | 3 algas (21,14), (23,15), (22,16) con la charca helada; 2 setas (20,17) y (23,17) para electrificar/helar |
| C4 | el colmillo lo sueltan los goblins que ya hay |

C1, C2 y C6 ya tenían sus setas.

### Pendiente (fase 3 del pulso y siguientes)

- `seta_resonante` (la seta madura con el pulso, C1), `mineral_veta` (veta + tierra, C2 y C4), `esquirla_cristal` (cristal resonante a
  golpes, C1 y C4; jarrón roto): faltan los reactivos de pulso y el jarrón roto; llamar a `Objetos.mineral_de`.
- Los dos épicos: el cofre épico tras las estatuas de C1 y la pared hueca de C3 (fase 3), y qué mejora al personaje da cada uno.
- El oro de los jarrones de C1 y C6 y la llave en la bolsa (`cueva.c4.llave` sigue siendo solo una flag).
- Arte 3D propio del alga, el basalto suelto y el cristal resonante (hoy piezas del decorado teñidas).

## Lo que había que hacer (lista original)

- **Datos:** dar de alta en `DATOS` los 9 nuevos y en `PLANTAS` el `alga` (base `alga_cueva`; `fuego` → `alga_seca`). Los épicos y
  el glifo necesitan una **calidad** (campo `calidad` en `DATOS`: común por defecto) para el color del aviso y del icono.
- **Recolectables:** el alga y el basalto son `Recolectable3D` con condición: solo se cogen con la charca helada o con la lava
  enfriada. Los minerales salen de un reactivo (la veta o el cristal), igual que la seta transformada.
- **Botín de goblin:** `colmillo_goblin` al caer (hoy los goblins no sueltan nada).
- **Iconos:** las formas que ya hay sirven: `cristal` (esquirla, geoda, núcleo), `piedra` (basalto, mineral), `hoja` (alga) y `raiz`
  (colmillo). Solo hace falta el color.
- **Arte 3D:**
  - alga en el lecho (los adornos del lecho ya son algas);
  - roca de basalto suelta;
  - cristal resonante (está en la lista del plan del pulso);
  - jarrón roto (ya hay `jarron` y `jarron_alto`; falta la versión rota).


**Decisión de Pablo (24/10):** los épicos y los comunes son **ingredientes de recetas**. Con recetas se fabrican las mejoras de vida, tinta y pigmentos (DISENO_FUTURO.md §7). La ropa no sale de recetas: llega ya hecha en cofres o misiones.
