# Pack «Stylized Lost Cave» (StylArts / Leartes Cosmos)

- **Origen:** «Stylized Lost Cave» de StylArts (artista Laima Vaitkus), comprado en Cosmos de Leartes el 24/11/2026, versión Godot
  (`StylizedLostCaveForward.zip`: el proyecto de Unity pasado a Godot 4.0 con Unidot).
- **Licencia:** contrato de Cosmos, licencia *Individual*. Permite el uso comercial con menos de 100.000 $ de facturación al año. Prohíbe
  redistribuir los assets sueltos, dejarlos descargables como archivos y usarlos para entrenar IA. **Por eso aquí solo viajan en git esta nota y
  `tabla_lostcave.gd`.** Todo lo demás (`_fuente/`, `mallas/`, `texturas/`, `materiales/`, `mallas_res/`, `piezas/`, `capturas/`) está en
  `.gitignore` y se regenera desde el zip.
- **Contenido generado:** 201 piezas `piezas/lost_<nombre>.tscn` (36 de estructura, 52 de mina, 54 de atrezo, 19 cristales y 40 de vegetación)
  y 6 calcas `piezas/lost_calca_*.tscn` (4 símbolos rupestres, la grieta brillante y los puntos brillantes). Quedan fuera el agua (el agua del
  mundo es mejor y debe verse igual en todo el juego), el terreno, el cielo y las partículas del nivel de muestra.

## Regenerar (otra máquina, o después de tocar la tabla)

```
tools\preparar_lostcave.cmd "C:\Users\pablo\Downloads\StylizedLostCaveForward.zip"
```

Pasos que hace (unos 4 minutos):
1. `tools/preparar_lostcave.py`: saca del zip las texturas originales, las recetas de los 68 materiales de Unity y las mallas glTF limpias.
2. Importa las mallas.
3. Baja las texturas a 1K, tapa la marca del autor, mete la opacidad del follaje en el alfa y hornea la roca en mosaico.
4. Las importa.
5. Les pone los ajustes de 3D (VRAM, mipmaps y mapas de normales).
6. Las reimporta.
7. Crea los materiales y las piezas.

Si solo cambias escalas, giros, colisión o emisión en la tabla, basta con el último paso:
`godot --headless --path . --script res://herramientas/generar_piezas_lostcave.gd -- --piezas`

## Ver las piezas

- Laboratorio: `godot --path . res://laboratorios/LabLostCave.tscn`. Teclas: 1-6 categoría, flechas/WASD, rueda para el zoom,
  L para la luz de cueva y N para los nombres.
- Hojas de contacto: `godot --path . --script res://herramientas/captura_lostcave.gd` → `arte/lostcave/capturas/`.
- Giros de una pieza: `... captura_lostcave.gd -- giros lost_arch lost_cart` → `capturas/lostcave_giros.png`.

## Nivel de prueba

- Escena `escenas/PruebaLostCave.tscn` (nivel «LostCave» en `Niveles.ESCENAS`) con el mapa `mundo/datos_nivel/mapas/LostCave.txt`. Tiene cinco salas:
  - **BOCA** (transición desde el bosque, con luz de bosque).
  - **CRUCE** (arco de roca, columnas y grieta azul).
  - **MINA** (vía, vagonetas, bocamina y faroles).
  - **CRISTALES** (rojos de fuego, azules de agua y hexágonos).
  - **SANTUARIO** (portal de runas, tótems, símbolos y altar).
- Abrir: `godot --path . res://escenas/PruebaLostCave.tscn`.
- Comprobación y capturas: `godot --path . --script res://herramientas/captura_lostcave_nivel.gd`. Comprueba avisos, piezas y solidez, y deja las
  imágenes en `arte/lostcave/capturas/nivel/`.
- Las piezas se ponen como `; pieza d_<x> decorado X Y modelo=lost_<pieza> [giro=] [escala=]`. `Puzle3D` busca las `lost_*` en `arte/lostcave/piezas/`.
- Las que brillan (faroles, velas, cristales, hexágonos y plantas brillantes) llevan su propia luz (`TablaLostCave.LUCES`): en la cueva del juego
  es lo que alumbra.

## Decisiones (24/11/2026)

- **Texturas pintadas del pack**, no colores planos de la paleta como en Provencal. Lo pidió Pablo («texturas a 1K»).
- Materiales `StandardMaterial3D` (color, normal, ORM y emisión), así que Ocluso3D los convierte como los de Meshy. El musgo por arriba de los
  Shader Graph de Unity **no** se ha traducido.
- Escala 0,68 (la del atrezo de Provencal). Lo largo de cada pieza queda en horizontal en pantalla.
- Colisión: la malla exacta en «estructura» (arcos, túneles, bocamina y escaleras dejan pasar). En el resto, la envolvente convexa del autor.
- La marca «StylArts» pintada en el detonador y en la caja de dinamita se tapa al generar.
