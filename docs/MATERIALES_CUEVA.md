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

Uno por secreto. Cada uno sube **una variable** de un glifo, como las propiedades de la receta v2 (`GLIFOS_RECETA.md` §2.2).

| id | nombre | dónde | qué mejora | estado |
|---|---|---|---|---|
| `nucleo_eco` | Núcleo de eco | cofre épico tras las **estatuas** de C1 (secuencia de pulsos, hace falta el glifo) | resonancia: `resuena` +2 casillas | **nuevo** |
| `geoda_resonante` | Geoda resonante | tras una **pared hueca** de C3, que se encuentra con el eco del pulso | resonancia: +1 salto por cristal resonante | **nuevo** |

Los dos piden el glifo, así que son la razón para volver a la Cueva tras el cofre legendario. Si Pablo decide que las mejoras son un
recurso común en vez de ir atadas a un glifo (`PLAN_PULSO_RESONANTE.md` §10.4), se juntan en uno solo: «esencia de eco».

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

## Lo que hay que hacer

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
