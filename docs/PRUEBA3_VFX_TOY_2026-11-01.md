# Prueba 3 de VFX: cinco efectos de fuego estilo Link's Awakening / Echoes of Wisdom, por tres caminos (1/11/2026)

Tercera ronda de la comparativa (`COMPARATIVA_VFX_GODOT_UNREAL_2026-11-01.md`, `PRUEBA2_VFX_TOON_2026-11-01.md`). Encargo de Pablo: cinco efectos, estilo lo más parecido a anime/toon con **Link's Awakening (2019) y Echoes of Wisdom** como referencia, y **tres caminos** para comparar: Godot, Unreal desde código, y Unreal buscando packs en Fab y ajustándolos.

## 0. Referencia

Cuatro capturas en `docs/capturas/comparativa_vfx/referencia_toy/` (ver `LEEME.md`): `eow_hierba.jpg` es la principal (la llama), `la_pilar.jpg` para el pilar, `la_antorchas.jpg` para la bola estática, `eow_ignizol.jpg` para la forma de una llama suelta.

El estilo es el contrario de la prueba 2: **llama blanda**, degradado suave de blanco-amarillo a naranja, borde con resplandor, formas redondas y gordas como de juguete, animación fluida, sin rojo oscuro, sin contorno, sin humo negro. Luz cálida con titileo suave, pocas chispas.

## 1. Los cinco efectos (tamaños del juego)

| Efecto | Tamaño | Qué hace |
|---|---|---|
| Bola estática | r 0,4 m, a 1 m del suelo | Una bola de fuego quieta, como una antorcha flotante; luz en el suelo |
| Bola en movimiento | r 0,4 m, 12 m/s | La misma bola como proyectil con estela corta; impacto al chocar (resplandor y chispas, sin humo negro) |
| Muro | 6,9 × 1,5 m | Línea de fuego en el suelo |
| Pilar | r 0,5 × 4 m | Columna de fuego que sube, como la trampa de Link's Awakening |
| Barrera | esfera r 1,5 m alrededor del jugador | Cáscara de fuego translúcida con lenguas que giran, se ve el jugador dentro |

Mandos: los diez que más cambian el aspecto, en castellano, sin abrir código (inspector en Godot, User Parameters y Material Instance en Unreal, parámetros del pack en Fab).

## 2. Los tres caminos

| Camino | Dónde | Rama | Qué se permite |
|---|---|---|---|
| A. Godot | `E:\tmp\wt_prueba3_godot`, `presentacion/vfx/toy/` | `claude/prueba3-godot-toy` | Todo propio o CC0; se parte de lo de la prueba 2 si sirve |
| B. Unreal desde código | `E:\UnrealProjects\MS_POC_VFX`, `/Game/POC3/`; docs en `E:\tmp\wt_prueba3_unreal` | `claude/prueba3-unreal-toy` | Materiales, Niagara y Blueprints por script; contenido del motor; nada de Fab |
| C. Unreal con Fab | Mismo proyecto, `/Game/POC3_Fab/` (o copia del proyecto si hay que trabajar a la vez) | misma rama, carpeta `unreal_fab/` | Packs gratuitos de Fab (licencia estándar de Fab o CC); se ajustan parámetros, materiales e instancias; se apunta qué es ajeno. Paso 1: búsqueda y lista para que Pablo instale los packs con su cuenta (el agente no inicia sesión). Paso 2: montar los cinco efectos con lo instalado y ajustar. |

## 3. Reglas comunes

| | |
|---|---|
| Presupuesto | 2 jornadas de agente por camino, cronometradas por paso en `NOTAS.md`; 1 hora de Pablo por camino al final |
| Orden | Bola estática → muro → pilar → bola en movimiento → barrera. Cada efecto se captura y se compara con la referencia antes de pasar al siguiente |
| Juez | La referencia: `eow_hierba.jpg` para la llama. Nota propia 1–5 por efecto en `NOTAS.md`, con lo que falta. Si un efecto no pasa de 3 en dos rondas, se sigue con el siguiente y se apunta |
| Render | ≤ 1 luz y ≤ 300 partículas por efecto; diez muros ≥ 60 fps a 1080p |
| Capturas | `bola_cerca`, `bola_juego`, `bola_vuelo`, `bola_impacto`, `muro_cerca`, `muro_juego`, `pilar_cerca`, `pilar_juego`, `barrera_cerca`, `barrera_juego`, `diez_muros` (con fps), y un GIF de 3 s de cada efecto, en `docs/capturas/comparativa_vfx/godot_toy/`, `unreal_toy/`, `unreal_fab/` |
| Pruebas | Godot: script sin ventana con presupuesto, escenas cargan, paleta. Unreal: script de aserciones en editor y con `-run=pythonscript` |
| Cinco modificaciones de Pablo | (1) fuego azul; (2) llama el doble de alta; (3) la mitad de chispas; (4) barrera el doble de grande; (5) pilar que dura 1 s y se apaga. Solo, cronometrado |
| Disco | Todo en E; nada en C |

## 4. Tabla de resultados

| Criterio | Peso | A. Godot | B. Unreal código | C. Unreal Fab | Notas |
|---|---|---|---|---|---|
| Aspecto por efecto frente a la referencia (Pablo, 1–5, media de cinco) | 3 | | | | |
| Efectos entregados de cinco | 2 | | | | |
| Horas de agente | 2 | | | | de las 16 |
| Cinco modificaciones: cuántas solo, tiempo | 3 | | | | |
| Fps diez muros 1080p | 1 | | | | |
| Flujo que sobrevive (sin ventana, pruebas, texto, capturas) | 3 | | | | 0–5 |
| Contenido ajeno en lo que se ve | 1 | | | | % |
| Coste de llegar al juego entero | 3 | 0 | 50–80 jornadas | 50–80 jornadas + licencias | |

## 5. Calendario

| Paso | Quién |
|---|---|
| Referencias y este diseño | Dirección (hecho 1/11) |
| A y B en paralelo; C paso 1 (búsqueda) en paralelo | Agentes |
| Instalar los packs elegidos de C con su cuenta | Pablo |
| C paso 2 | Agente |
| Hora de Pablo por camino, notas, modificaciones; tabla, diario, decisión | Pablo y dirección |
