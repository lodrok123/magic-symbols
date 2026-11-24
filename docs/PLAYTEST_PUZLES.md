# Playtest de los puzles del catálogo (24/11/2026)

Niveles de prueba hechos con el generador (`herramientas/generar_playtest_puzles.gd`), uno por grupo de puzles. Cada puzle va en su sala, en ORDEN
desde el inicio, con un rótulo al entrar («3 · Vagoneta por la curva»); los que no tienen premio propio llevan un cofre común que aparece
al resolverlos. Sin enemigos ni nada más que los puzles. Se abren con el generador («Abrir mapa generado») o directamente (comandos abajo).

**Para no buscar las salas:** a la derecha de la pantalla sale la lista de salas del nivel (▶ = en la que estás). **Alt + número** (o el número del
teclado numérico) te lleva a la entrada de esa sala (`escenas/atajos_playtest.gd`). Alt + número también cambia de página del libro: no estorba.

**Cómo se valida:** Pablo los juega y dice, por puzle, *aceptado* o *ajustes* (y qué). Claude lo apunta en su `.txt` (`; validacion`, `; nota_playtest`)
y en la hoja maestra (pestaña Puzzles, filas `cat_<id>`). En el generador, el estado sale delante de cada puzle (○ pendiente · ✎ ajustes · ✔ aceptado ·
✖ rechazado) y la casilla **«Solo puzles aceptados»** (pestaña Mapa) hace que en los mapas oficiales solo se repartan los aceptados.

## PtFuego · Fuego

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtFuego.tscn
```

| Orden | Sala | Puzle | Necesita | Estado |
|---|---|---|---|---|
| 1 | 2 | **Dos braseros que abren** (`braseros_puerta`) | fuego + flecha | pendiente |
| 2 | 3 | **Tres braseros y un cofre** (`braseros_premio`) | fuego + flecha | pendiente |
| 3 | 4 | **Relé de braseros** (`rele_braseros`) | fuego + flecha | pendiente |
| 4 | 7 | **Contrafuego: setos y barril** (`contrafuego`) | fuego + flecha | pendiente |
| 5 | 6 | **Voladura: barril contra el muro** (`barril_muro`) | fuego + flecha | pendiente |
| 6 | 5 | **Cristal dormido y receptor de fuego** (`cristal_receptor`) | fuego + flecha | pendiente |

## PtVagonetas · Vagonetas

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtVagonetas.tscn
```

| Orden | Sala | Puzle | Necesita | Estado |
|---|---|---|---|---|
| 1 | 1 | **Vagoneta a la placa (a mano)** (`vagoneta_pista`) | empujar | aceptado |
| 2 | 5 | **Vagoneta por la curva (a mano)** (`vagoneta_curva`) | empujar | pendiente |
| 3 | 3 | **Vagoneta lanzada contra el muro (mecanismo)** (`vagoneta_boton`) | fuego + flecha, o agua + flecha, o tierra + flecha | aceptado |
| 4 | 4 | **Vagoneta y aguja: elige el ramal (mecanismo)** (`vagoneta_aguja`) | fuego + flecha, o agua + flecha, o tierra + flecha | pendiente |

## PtAguaTierra · Agua y tierra

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtAguaTierra.tscn
```

| Orden | Sala | Puzle | Necesita | Estado |
|---|---|---|---|---|
| 1 | 1 | **Riega la placa** (`riega_pulsador`) | agua + flecha | pendiente |
| 2 | 2 | **Río de lava** (`rio_lava`) | agua + flecha, o hielo + flecha | pendiente |
| 3 | 3 | **Puente plegado: agua o fuego** (`puente_cuerda`) | agua + flecha, o fuego + flecha | pendiente |
| 4 | 7 | **Escondite tras el muro agrietado** (`escondite_muro`) | tierra + flecha | pendiente |
| 5 | 6 | **Bloque de hielo en la pista** (`hielo_pista`) | tierra + barrera | pendiente |
| 6 | 5 | **Balanza: dos rocas y un bloque de tierra** (`balanza_rocas`) | tierra + barrera | pendiente |

## PtEmpujePulso · Empuje y pulso

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtEmpujePulso.tscn
```

| Orden | Sala | Puzle | Necesita | Estado |
|---|---|---|---|---|
| 1 | 1 | **Bloque de piedra en la pista** (`piedra_pista`) | empujar | pendiente |
| 2 | 5 | **Peso de la piedra (cofre)** (`piedra_premio`) | empujar | pendiente |
| 3 | 4 | **Pared hueca y nicho (ᚱ)** (`pared_hueca_nicho`) | fuego + raido, o agua + raido, o tierra + raido | pendiente |
| 4 | 6 | **Tres estatuas: fuego, agua, tierra (ᚱ)** (`estatuas_sellos`) | fuego + agua + tierra + raido + flecha | pendiente |
| 5 | 3 | **Prisma: rojo y azul** (`prisma_rojo_azul`) | fuego + agua + flecha | pendiente |

## PtJefeCueva · Jefe de la cueva

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtJefeCueva.tscn
```

Sala del jefe: **Sala del jefe: gólem (cueva)** (la sala grande más lejana del inicio), y un campamento goblin. Semilla 1.

## PtJefeBosque · Jefe del bosque

Kit «demo». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtJefeBosque.tscn
```

Sala del jefe: **Sala del jefe: elemental del bosque** (la sala grande más lejana del inicio), y un campamento goblin. Semilla 1.

## PtHielo · Hielo (fuera de la demo)

Kit «pruebas». Abrir:
```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaPtHielo.tscn
```

| Orden | Sala | Puzle | Necesita | Estado |
|---|---|---|---|---|
| 1 | 1 | **Charca que hay que helar** (`charca_helada`) | hielo + flecha | pendiente |

## Inventario completo

| Puzle | Tipo | Necesita | Nivel de playtest | Estado |
|---|---|---|---|---|
| Balanza: dos rocas y un bloque de tierra (`balanza_rocas`) | premio | tierra + barrera | PtAguaTierra · 6 | pendiente |
| Voladura: barril contra el muro (`barril_muro`) | premio | fuego + flecha | PtFuego · 5 | pendiente |
| Tres braseros y un cofre (`braseros_premio`) | premio | fuego + flecha | PtFuego · 2 | pendiente |
| Dos braseros que abren (`braseros_puerta`) | salida | fuego + flecha | PtFuego · 1 | pendiente |
| Charca que hay que helar (`charca_helada`) | paso | hielo + flecha | PtHielo · 1 | pendiente |
| Contrafuego: setos y barril (`contrafuego`) | premio | fuego + flecha | PtFuego · 4 | pendiente |
| Cristal dormido y receptor de fuego (`cristal_receptor`) | salida | fuego + flecha | PtFuego · 6 | pendiente |
| Escondite tras el muro agrietado (`escondite_muro`) | premio | tierra + flecha | PtAguaTierra · 4 | pendiente |
| Tres estatuas: fuego, agua, tierra (ᚱ) (`estatuas_sellos`) | premio | fuego + agua + tierra + raido + flecha | PtEmpujePulso · 4 | pendiente |
| Bloque de hielo en la pista (`hielo_pista`) | salida | tierra + barrera | PtAguaTierra · 5 | pendiente |
| Pared hueca y nicho (ᚱ) (`pared_hueca_nicho`) | premio | fuego + raido, o agua + raido, o tierra + raido | PtEmpujePulso · 3 | pendiente |
| Bloque de piedra en la pista (`piedra_pista`) | salida | empujar | PtEmpujePulso · 1 | pendiente |
| Peso de la piedra (cofre) (`piedra_premio`) | premio | empujar | PtEmpujePulso · 2 | pendiente |
| Prisma: rojo y azul (`prisma_rojo_azul`) | premio | fuego + agua + flecha | PtEmpujePulso · 5 | pendiente |
| Puente plegado: agua o fuego (`puente_cuerda`) | paso | agua + flecha, o fuego + flecha | PtAguaTierra · 3 | pendiente |
| Relé de braseros (`rele_braseros`) | salida | fuego + flecha | PtFuego · 3 | pendiente |
| Riega la placa (`riega_pulsador`) | salida | agua + flecha | PtAguaTierra · 1 | pendiente |
| Río de lava (`rio_lava`) | paso | agua + flecha, o hielo + flecha | PtAguaTierra · 2 | pendiente |
| Vagoneta y aguja: elige el ramal (mecanismo) (`vagoneta_aguja`) | salida | fuego + flecha, o agua + flecha, o tierra + flecha | PtVagonetas · 4 | pendiente |
| Vagoneta lanzada contra el muro (mecanismo) (`vagoneta_boton`) | premio | fuego + flecha, o agua + flecha, o tierra + flecha | PtVagonetas · 3 | aceptado |
| Vagoneta por la curva (a mano) (`vagoneta_curva`) | premio | empujar | PtVagonetas · 2 | pendiente |
| Vagoneta a la placa (a mano) (`vagoneta_pista`) | salida | empujar | PtVagonetas · 1 | aceptado |
| Sala del jefe: gólem (cueva) (`jefe_golem`) | sala de enemigos | — | PtJefeCueva | pendiente |
| Sala del jefe: elemental del bosque (`jefe_elemental`) | sala de enemigos | — | PtJefeBosque | pendiente |
| Campamento goblin (sala de enemigos) (`campamento`) | sala de enemigos | — | PtJefeCueva, PtJefeBosque | pendiente |
