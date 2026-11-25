# Inventario para construir niveles: atrezo del pack «SH assets» (25/11/2026)

Son los 64 objetos pequeños del pack «SH assets.blend»: contenedores, adornos, cerámica, piedras y vegetación. Ya están en el juego con sus
**texturas reales** horneadas y se pueden usar en cualquier nivel. Monte Sumicio ya los lleva repartidos por el pueblo
(`escenas/monte_sumicio_atrezo.gd`).

- **Archivos:** `arte/sh_assets/atrezo/sh_<nombre>.glb`, uno por objeto, más `atrezo_sh.json` con sus cifras. **No van en git**, porque
  la licencia del pack sigue sin identificar. En otra máquina se regeneran con `arte/sh_assets/LEEME.md`.
- **Catálogo para verlos:** `laboratorios/LabAtrezoSH.tscn` (teclas 1-5 por categoría, P para esparcir, N para los nombres).
- **Cómo se prepararon:** `tools/exportar_atrezo_sh.py --hornear`.
  - Cada objeto se une en **una malla con un solo material**: 1 llamada de dibujo por copia, y Godot agrupa las copias iguales.
  - Se hornean en Cycles el color real del pack (madera, piedra y cerámica procedurales con su oclusión) y las normales (vetas, herrajes).
  - Las texturas son de 1024 px para lo grande, 512 para lo mediano y 256 para los cántaros.
  - La vegetación conserva sus imágenes. Los arbustos y `hierba_1` llevan un verde fijado a mano, porque en el pack su color salía de un
    truco de iluminación de EEVEE que no viaja a Godot.

## Cómo ponerlos en un nivel

```gdscript
var escena := load("res://arte/sh_assets/atrezo/sh_barril.glb") as PackedScene
var barril := escena.instantiate() as Node3D
barril.scale = Vector3.ONE * 0.42        # escala de la tabla (el pack viene en metros y grande)
nivel.add_child(barril)
# material del juego (rampa de luz y círculo de transparencia): Ocluso3D.convertir(material), uno por material y compartido
```

`escenas/monte_sumicio_atrezo.gd` ya resuelve lo que hace falta y sirve de plantilla:
- materiales convertidos con Ocluso3D y compartidos;
- tinte cálido para la madera;
- choque con caja para lo grande;
- nada encima de caminos, delante de puertas ni dentro de edificios;
- semilla fija, para que el reparto salga siempre igual.

**Escalas usadas** (la jugadora mide 1 u y una casilla 2,3 u):

| Categoría | Escala |
|---|---|
| Contenedores, adornos y cerámica | 0,42 |
| Piedras | 0,45 |
| Vegetación | 0,30 |

**Tinte:** la madera horneada sale rosada y pálida junto a la paja y la empalizada. En Sumicio se multiplica por `(1,0 0,82 0,64)`.

## Contenedores optimizados (25/11, `--hornear --bajo`)
Los 7 contenedores de madera se **diezman** a 4–8 mil triángulos (antes 67–232 mil). El color y las normales se hornean **desde la malla
original** (alta → baja), así que las vetas, los clavos y los biseles siguen en el mapa de normales: a la vista no se distinguen. El
`barril_bajo` usa una jaula de 0,08 (con 0,03 salía oscuro). Las versiones altas quedan en `arte/sh_assets/atrezo_alta/` para comparar.

Medido en la RTX 3070 (`docs/capturas/atrezo_sh/contenedores_antes.txt` y `contenedores_despues.txt`; 100 copias a la vista, en ms por
fotograma, con la escena vacía en 2,5–2,8):

| Objeto | Triángulos | Disco | Carga del .glb | 100 copias con LOD | 100 copias sin LOD |
|---|---|---|---|---|---|
| `barril` | 70.264 → **4.000** | 10,5 → 2,3 MB | 18 → 3 ms | 6,4 → 5,8 | 26,8 → **5,7** |
| `barril_bajo` | 70.264 → **4.000** | 10,5 → 2,3 MB | 15 → 2 ms | 6,4 → 5,9 | 27,0 → **5,9** |
| `arcon` | 114.108 → **6.000** | 16,2 → 2,5 MB | 26 → 2 ms | 6,4 → 5,4 | 39,8 → **6,0** |
| `cajon_abierto` | 107.040 → **6.000** | 14,7 → 2,1 MB | 25 → 2 ms | 5,9 → 3,3 | 36,3 → **5,6** |
| `caja_cerrada` | 232.268 → **8.000** | 28,5 → 2,6 MB | 75 → 2 ms | 8,0 → 6,5 | 74,9 → **8,1** |
| `caja_abierta` | 232.268 → **8.000** | 28,5 → 2,7 MB | 72 → 3 ms | 6,6 → 6,4 | 73,1 → **6,9** |
| `troncos` | 66.848 → **4.000** | 10,6 → 2,3 MB | 17 → 2 ms | 6,1 → 5,8 | 27,4 → **5,4** |

**Monte Sumicio** (94 objetos), con la vista del juego (el pueblo sin atrezo: 5,06 ms y 381 mil triángulos):

| | Antes | Optimizado |
|---|---|---|
| Fotograma | 6,25 ms | **5,44 ms** |
| Triángulos dibujados | 823 mil | **480 mil** |
| Coste del atrezo | +1,19 ms | **+0,38 ms** |
| Montaje al cargar | 1,1 s | 0,9 s (casi todo leer los otros 57 modelos) |

Los FPS varían bastante de una pasada a otra; triángulos, peso y llamadas son exactos.

## Coste del resto
- **Medio:** el farol, la crestería, la cadena y una planta (`planta_c2`, 18 mil).
- **Bajo:** todo lo demás (cerámica, piedras y plantas). Cuesta prácticamente lo mismo que no ponerlo.

## Tabla

Tamaño en **unidades del juego** a la escala de arriba (ancho × fondo × alto). «Choque»: en Sumicio lleva cuerpo sólido (una caja con su
planta). Lo demás se pisa.

| Objeto | Categoría | Tamaño (u) | Triángulos | Textura | Choque | Coste | Para qué |
|---|---|---|---|---|---|---|---|
| `barril` | contenedor | 0.49 × 0.49 × 0.62 | 4.000 | 1024 | sí | bajo | Junto a puertas, almacenes, tabernas, muelles. Se agrupa con cajas. |
| `barril_bajo` | contenedor | 0.49 × 0.49 × 0.52 | 4.000 | 1024 | sí | bajo | Igual que el barril, algo más bajo: alternarlos rompe la repetición. |
| `arcon` | contenedor | 1.10 × 0.59 × 0.54 | 6.000 | 1024 | sí | bajo | Arcón alargado cerrado: mercancía de tienda, almacén, cubierta de barco. |
| `cajon_abierto` | contenedor | 1.19 × 0.36 × 0.28 | 6.000 | 1024 | sí | bajo | Cajón abierto o jardinera: con flores encima o cántaros al lado. |
| `caja_cerrada` | contenedor | 0.61 × 0.58 × 0.64 | 8.000 | 1024 | sí | bajo | Caja de carga con refuerzos en cruz: pilas de mercancía, campamentos. |
| `caja_abierta` | contenedor | 1.00 × 0.93 × 0.60 | 8.000 | 1024 | sí | bajo | La misma caja abierta con la tapa caída: tiendas, saqueos, cofres pobres. |
| `troncos` | contenedor | 2.25 × 0.58 × 0.42 | 4.000 | 1024 | sí | bajo | Pila de leña larga y baja: junto a casas, obradores, aserraderos. |
| `farol_pared` | adorno | 0.49 × 0.22 × 0.58 | 22.046 | 1024 | no | medio | Brazo de forja con farol colgado: muros de piedra, entradas de noche. |
| `tinaja_colgante` | adorno | 0.31 × 0.21 × 0.32 | 7.542 | 512 | no | bajo | Tinaja atada con cuerdas: colgar de aleros o vigas. |
| `veleta` | adorno | 1.98 × 0.40 × 1.13 | 13.458 | 1024 | no | medio | Crestería de forja (el pack la llama «WindVane»): cumbreras, verjas. |
| `cartel` | adorno | 0.68 × 0.04 × 0.44 | 884 | 1024 | no | bajo | Tablero de cartel: tiendas, posadas, cruces de caminos. |
| `cadena` | adorno | 0.03 × 0.03 × 0.24 | 11.520 | 512 | no | medio | Cadena de 10 eslabones: pozos, mazmorras, puentes levadizos. |
| `tinaja_a` … `tinaja_f` | cerámica | 0.28–0.60 de ancho, 0.42–0.69 de alto | 3.072 | 1024 | no | bajo | Tinaja grande: rincones de casa, bodegas, patios. |
| `cuenco_d2`, `cuenco_d3` | cerámica | 0.26–0.31 × 0.20 × 0.25 | 3.072–4.158 | 512 | no | bajo | Cuenco pequeño: mesas, interiores, junto a tinajas. |
| `cantaro_01` … `cantaro_21` | cerámica | 0.03–0.18 de ancho, 0.09–0.21 de alto | 3.072 | 256–512 | no | bajo | Cántaro pequeño: alrededor de tinajas, estantes, mesas. **Muy pequeños** a esta escala: en exteriores apenas se ven. |
| `piedra_rota_1` … `_4` | piedra | 0.23–0.41 × 0.34–0.41 × 0.15 | 1.112–2.962 | 512 | no | bajo | Piedra rota: caminos, ruinas, al pie de muros. |
| `flor_amarilla`, `flor_blanca`, `rosal` | vegetación | 0.27–0.40 de ancho, 0.43–0.52 de alto | 987–1.290 | la suya | no | bajo | Flores: macizos junto a casas, cajones, plazas. |
| `matojo`, `enredadera`, `hierba_1`, `hierba_2` | vegetación | 0.35–0.53 de ancho, 0.11–0.40 de alto | 139–552 | la suya | no | bajo | Matas bajas: bordes y macizos. |
| `planta_1` … `planta_3` | vegetación | 0.18–0.63 de ancho, 0.22–0.68 de alto | 801–4.831 | la suya | no | bajo | Plantas de hoja ancha (BagaPie). |
| `planta_c1` … `planta_c6` | vegetación | 0.26–0.57 de ancho, 0.24–0.42 de alto | 730–18.184 | la suya | no | bajo (`c2`: medio) | Plantas con flor en espiga y lirios. |
| `arbusto_1` … `_3` | vegetación | 0.64–0.84 de ancho, 0.47–0.58 de alto | 256 | la suya | no | bajo | Arbusto de tarjetas con hoja: setos, lindes. Verde fijado a mano. |

## Pendiente o por decidir (Pablo)
- **Los cántaros:** subirles la escala en exteriores, o dejarlos solo para interiores y estantes.
- **Licencia y autor del pack:** sin identificar. Hace falta saberlos antes de que algo del pack entre en el repo público o en una build
  que se distribuya.
