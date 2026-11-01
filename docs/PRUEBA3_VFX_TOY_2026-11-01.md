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

Rellenada el 1/11 por la noche. **Pablo decidió a media tarde quedarse en Godot** («dado el tipo de juego, estilizado/toon/anime, no requiere demasiado polígono; Unreal no me está acelerando el proceso»), así que el camino B se paró (el editor se había caído; lo hecho queda en `/Game/POC3/` sin terminar) y el C se quedó en la búsqueda (`docs/capturas/comparativa_vfx/CANDIDATOS_FAB_2026-11-01.md`: 8 packs gratuitos y 4 de pago; ninguno cubre los cinco efectos con el estilo).

| Criterio | Peso | A. Godot | B. Unreal código | C. Unreal Fab | Notas |
|---|---|---|---|---|---|
| Aspecto por efecto frente a la referencia (Pablo, 1–5, media de cinco) | 3 | pendiente de Pablo (agente: bola 4,5, muro 4,5, pilar 4,5, vuelo 3,5, barrera 4) | — | — | Pablo sobre la ronda 3: «por fin esta sí es una dirección» |
| Efectos entregados de cinco | 2 | 5 (el impacto de la bola, de la ronda 2) | parado | — | |
| Horas de agente | 2 | ≈ 2 h en siete rondas (40 + 13 + 9 + 10 + 11 + 12 + 15 min) | — | 12 min de búsqueda | de las 16 |
| Cinco modificaciones: cuántas solo, tiempo | 3 | pendiente; las cinco salen por mando o parámetro y la prueba sin ventana lo comprueba | — | — | |
| Fps diez muros 1080p | 1 | 638 sin vsync | — | — | |
| Flujo que sobrevive (sin ventana, pruebas, texto, capturas) | 3 | 5 | — | — | 0–5 |
| Contenido ajeno en lo que se ve | 1 | 4 texturas del pack gratuito de Le Lu (`assets/vfx/lelu_noise/`, permiso en su readme): la silueta de las lenguas | — | — | % |
| Coste de llegar al juego entero | 3 | 0 | 50–80 jornadas | 50–80 jornadas + licencias | |

### 4.1 Las siete rondas de Godot (rama `claude/prueba3-godot-toy`)

| Ronda | Commit | Qué | Veredicto |
|---|---|---|---|
| 1 | `fd617bf2` | Llama blanda procedimental, cinco efectos en 40 min | Pablo: «la mejor prueba de hoy», pero demasiado amarillo; pide rojos, naranjas, contraste y ruido en las puntas |
| 2 | `1c1d9a56` | Rampa rojo-naranja, mando `chisporroteo` (ruido fino arriba, trocitos, titileo) | Amarillo < 4 %; muro pasado de rojo |
| 3 | `9df78b2b` | Método de Le Lu (vídeo McRzhPV-xmc): mallas de revolución con UV vertical, textura de lenguas del pack, gradiente restado, rampa, vértices desplazados | Pablo: «por fin esta sí es una dirección»; pide pulir: bola con dos contornos, muro circular |
| 4 | `eab5262a` | Muro como una malla de sección rectangular redondeada de 6,9 × 0,6 m; bola con cara trasera descartada | Muro resuelto; la bola gana una estrella de meridianos en la base |
| 5 | `da21c6a0` | Bola con base fundida y disco | No resuelto: disco con rayos y tapa en vuelo |
| 6 | `ba232777` | Bola como billboard con el método en 2D y gradiente radial; en vuelo alineada a la velocidad y estirada | Una sola silueta, sin polos; se pierde el perfil a ras de suelo |
| 7 | `a9004af8` | Bola deformada por dos ruidos lentos (no es esfera); cabeza (head) propia: quad blanco-amarillo con destello de 4 puntas y halo corto; cola que nace detrás de la cabeza con 5 jirones y 6 estelas de chispas con punta de estrella | Apuntes de Pablo: «se deforma libremente» y «si modificas la cresta (head) ya estaría». Amarillo 28–30 %, por encima del 20 % (anillo de la cabeza y halo); queda un `ERROR: Index p_pass = 1` inofensivo |

Tonos finales (rojo-naranja / naranja / amarillo; objetivo 15–30 / 50–65 / ≤ 20): muro 17 / 60 / 23, pilar 26 / 57 / 17, bola 18 / 55 / 28 (ronda 7; en vuelo 14 / 57 / 30), barrera 38 / 48 / 14.

## 5. Calendario

| Paso | Quién |
|---|---|
| Referencias y este diseño | Dirección (hecho 1/11) |
| A y B en paralelo; C paso 1 (búsqueda) en paralelo | Agentes |
| Instalar los packs elegidos de C con su cuenta | Pablo |
| C paso 2 | Agente |
| Hora de Pablo por camino, notas, modificaciones; tabla, diario, decisión | Pablo y dirección |
