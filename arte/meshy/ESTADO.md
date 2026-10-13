# Decorado Meshy — estado (5 de octubre, mañana)

## Bibliotecas (un GLB con un objeto por pieza, cada uno con el nombre de su id)
| archivo | de dónde sale | piezas |
|---|---|---|
| `bosque.glb` | lámina 1 (`separar_lamina.py`) | arbol_redondo, pino, arbusto, arbusto_flores, matas (*), flores (*), roca_grande, piedras, tocon, tronco, setas, valla, cartel |
| `objetos.glb` | lámina 2 (`agrupar_3d.py`, identificadas con `entrada/POC forest 1.png`) | arco_puerta, totem_runico, brasero, fogata, puesto, caja_pequena, placa_peso, juncos, barril, cofre, caja, caja_cristal, baldosa_guardado |
| `magia.glb` | lámina 4 (`agrupar_3d.py`, con `entrada/POC forest 2.png`) | seto_seco, dummy, seta_reactiva, flor_reactiva, raiz_reactiva, portal_salida, puente, pocion, pilar, pasadero |

(*) Mal: Meshy las hizo como rocas de cristal (`matas`) y bolas (`flores`). La maqueta ya no las usa (la hierba
y las flores las pone `Hierba3D`). Candidatas a rehacer en la lámina 3 de `PROMPTS_2.md`.

## Revisión del 5 de octubre (catálogo `CatalogoAssets.tscn` y las láminas originales renderizadas)
El corte de las láminas está bien. Lo que falla viene de Meshy:
| pieza | problema | qué se ha hecho |
|---|---|---|
| `matas`, `flores` | no son lo pedido | ya no se usan; las sustituye la hierba 3D |
| `arco_puerta` | estaba bien, pero la abertura mira a ±X | la maqueta lo gira 90° |
| `fogata` | un muñeco de madera en el centro | quitado del GLB (2 trozos, 86 triángulos); quedan las piedras y los troncos |
| `seto_seco` | plano y alargado, en fila parece un ciempiés | sin tocar; candidato a rehacer |
| todas | 100–2000 triángulos y una sola textura de 2048 para 13 piezas, así que de cerca se ven facetadas y borrosas | límite de hacer láminas: para las piezas que se ven grandes (árbol, pino, arco, portal, puesto, tótem) conviene pedirlas sueltas a Meshy, una por modelo |

## Lo que falta
- **Bloques empujables de tierra y hielo**: Meshy los hizo cajas de madera con cristal (`caja_cristal`). Se harán con
  cubos y las texturas de tierra / hielo.
- **Oro**: no salió en la lámina 4. La maqueta usa monedas sencillas hechas por código.

## Herramientas
- `separar_lamina.py`: separa una lámina usando la IMAGEN de la lámina (piezas en filas, sin solaparse de frente).
- `agrupar_3d.py`: separa sin imagen, agrupando en 3D los trozos que se tocan (`--ver` para ver los grupos,
  `--partir G:N` si dos piezas se tocan, `--nombres 0=id,...` para escribir la biblioteca).

## Bibliotecas nuevas (5 de octubre, tarde) — de `entrada/Tree_Trio`, `Market_Ruin`, `Armas_Goblin`
Partidas con `agrupar_3d.py` (sin lámina: los tres GLB vienen como un único mesh). Cada pieza conserva
el atlas 2048 original, así que cada biblioteca pesa 5–6 MB.

| archivo | piezas | notas |
|---|---|---|
| `arboles_2.glb` | arbol_redondo_2 (3.7 k tris), pino_2 (1.8 k), arbusto_otono (9.6 k) | segundo juego de árboles, mismo estilo chibi que `chibi_elf`. Dos trozos sueltos (66 tris, raíces/ramas) descartados. `arbusto_otono` es un seto de hojas naranjas: candidato a sustituir a `seto_seco` |
| `mercado.glb` | puesto_mercado (6.4 k), arco_ruina (4.0 k), roca_cristal (3.5 k), piedras_2, piedras_3, piedras_4 (~200) | el puesto lleva toldo azul/blanco (paleta "ciudad": aldea sí, bosque no). `roca_cristal` tiene un cristal celeste incrustado: vale como roca mágica o como cristal de tierra. De las 7 piedras se han guardado 3 |
| `armas_goblin.glb` | garrote (5.3 k), escudo (5.8 k), daga (3.4 k) | **Sustituido** por `equipo/garrote.glb`, `escudo.glb`, `daga.glb` (ver abajo). Este puede ir a `_descartado` (`ORDENAR_POC.cmd`) |

Todas las piezas siguen **centradas en el origen del GLB de origen** (como las demás bibliotecas): la
maqueta las apoya por su caja. Tamaños relativos dentro de cada biblioteca son los de Meshy (el trío de
árboles mide 1 unidad de ancho total: cada árbol ~0,3).

## Actualización (5 de octubre, noche) — Pipeline
- `mercado.glb` vuelve a tener los ids de esta tabla (`puesto_mercado`, `arco_ruina`, `roca_cristal`): una subida
  intermedia lo había dejado con `puesto`, `arco_puerta`, `totem_runico`, que tapaban a los de `objetos.glb`.
  Las tres piedras sueltas (`piedras_2..4`) no están en esta versión (no las usa nadie).
- `arboles.glb` (seto_seco / arbol_redondo / pino) es **el mismo corte** que `arboles_2.glb` con otros nombres:
  ya no lo usa nadie; `ORDENAR_POC.cmd` lo mueve a `_descartado`.
- La maqueta usa las nuevas por **sustitución** (`SUSTITUTAS` en `prueba_test2.gd`): árbol y pino → `_2`,
  `seto_seco` → `arbusto_otono`, `puesto` → `puesto_mercado`, `arco_puerta` → `arco_ruina`. Retiradas `matas`,
  `flores` y `caja_cristal` (los empujables son cubos con la textura de tierra / hielo).
- **Armas preparadas** en `equipo/`: `garrote.glb`, `escudo.glb`, `daga.glb` (antes `espada_goblin`), sacadas de
  `equipo/armas_goblin.glb` (la versión sin las puntas de correa), con el agarre en el origen, +Y y textura a 1024.
- **Piezas regeneradas**: una por GLB en `meshy/piezas/<id>.glb`, con `INTEGRAR_PIEZAS.cmd` (ver `REGENERAR.md`).
  Ganan a la de la lámina y a la sustituta. Revisión: `CatalogoAssets.tscn`, tecla **H** (hoja de contacto con la chibi).
- **`piezas/lamina_1.glb`** (5/10, 17:30): Meshy generó `cartel`, `baldosa_guardado` y `pasadero` en un solo GLB
  ("Ancient Waypoint Sign", de la imagen de las cuatro piezas). Partido por trozos conectados: cartel 8,2 k tris,
  baldosa 5,0 k, pasadero 2,4 k. Sustituyen a los de la lámina. La próxima vez: una imagen por pieza
  (`referencias/<id>_meshy.png`).
