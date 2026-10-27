# Análisis profundo del proyecto para la dirección general (24/10/2026)

Encargo de Pablo: programación (funciones inservibles, estados frente a EoW y hoja de ruta de biomas, el patrón de `Hechizo` en otros sitios, autotests de resolubilidad, auditoría de `Hechizo` y que todas las combinaciones se construyan **y se ejecuten en el juego**), capa de presentación y balance de recompensas con la Torre del Agua como siguiente zona.

Todo lo que sigue está **medido sobre el código del commit `7a91ea36`** (worktree de esta sesión), sin tocar nada del repo. Seis análisis en paralelo escribieron los anexos `01`–`06` de esta carpeta; este documento los resume, cruza y ordena. Cuando una cifra sale de un anexo, se cita (`A3 §B`). Lo que no se ha podido verificar en pantalla (GPU, FPS, aspecto real) se dice.

| anexo | tema | lo esencial |
|---|---|---|
| `01_codigo_muerto_y_duplicado.md` | funciones inservibles y recogibles | 45 funciones sin referencia, ~490 líneas de barrera-burbuja antigua, 181 herramientas sin base común, 230 lecturas de privados ajenos |
| `02_estados_vs_eow.md` | lógica de estados | 16 sistemas en tabla, 29 incoherencias, 8 cambios, biomas con estados nuevos |
| `03_patron_hechizo_en_otros_sitios.md` | estructura por clases | 9 candidatos con veredicto y pruebas de igualdad |
| `04_autotest_resolubilidad.md` | autotests de niveles | diseño de dos capas listo, prototipo de 3–16 ms, problemas ya detectados en Bosque 01 v01 y Cueva |
| `05_auditoria_hechizo.md` | `Hechizo` frente a ESPEC y ejecución real | 48 048 combinaciones construyen; 10 incumplimientos en ejecución; campos que nadie lee |
| `06_presentacion.md` | assets, texturas, shaders, VFX, UI, audio | problemas por gravedad, top 10 de mejoras, necesidades por bioma |

---

## 0. Resumen ejecutivo

1. **La arquitectura es la correcta y está a medio aplicar.** «Datos, no código» se cumple en `Hechizo`, en `EstadosSuelo3D` y en las tablas de reacciones; se incumple en objetos (11 formas de «arder», 57 `tags.has`), enemigos (8 temporizadores con `if`), hierba (cuatro dueños) y niveles (reglas en código). EoW no pide una arquitectura nueva: pide **terminar la nuestra**.
2. **`Hechizo` construye todo** (48 048 combinaciones de 0–6 glifos × 6 sellos, cero `null`, cero límites rotos, libro y lab dan los mismos números). **Pero el juego no ejecuta todo lo que construye**: `repetición` con flecha lanza un solo proyectil; las flechas de tierra y hielo caen a 0,7 casillas de las 2 prometidas; `crecer` nunca llega a cambiar una casilla; los proyectiles atraviesan muros con solidez; y el libro del Bosque solo admite 3 glifos, así que solo 990 de las 48 048 son lanzables jugando (A5).
3. **Los sellos cumplen sus datos**: los seis `.tres` coinciden con ESPEC §2 y cada elemento corre en haz, proyectil y volumen quieto (1 716 casos ejecutados con `HechizoVivo`). Lo que no cumple es el **consumo** de esos datos: `temperatura`, `humedad`, `conductividad`, `densidad`, `potencia`, `intensidad_estado` y `elasticidad` no los lee nadie, y `empuje`, `deja`, `pisable` y `color` se leen del `RuneData`, no del `Hechizo` (A5 §A).
4. **El nivel de arranque parece una build de desarrollo**: HUD de depuración y paleta F1 siempre visibles, rótulos «PÍSAME», puzles dibujados con cajas y cilindros aunque existan las láminas de Meshy, 4 familias de árbol mezcladas (y el nivel vuelve a cargar el árbol de 12 k triángulos, deshaciendo V8), boca de la Cueva que es una losa (A6).
5. **No hay ninguna prueba de resolubilidad**: las 127 pruebas son guiones. El prototipo de análisis estático ya detecta que la barrera del Bosque 01 v01 no es obligatoria (confirmado también jugando: 0 de daño al cruzar), que el arroyo se cruza con hielo sin el tronco, que el cofre legendario de la Cueva se abre solo y que la Cueva no se puede terminar con el repertorio real `bosque` (A4).
6. **Hay más código muerto del conocido** (A1): `spellcaster.gd` (986 líneas, copia de `grimorio.gd`), la barrera-burbuja antigua de `Lanzador3D` (~490 líneas), `lab_grandmaster_3d.gd` huérfano (477), `presentacion/grimorio/` (42 MB), copias de nivel y JPEG sueltos (14 MB), 45 funciones sin referencia. Y la duplicación más cara no está en el juego sino en `herramientas/`: 181 scripts sin base común.
7. **El patrón de `Hechizo` encaja ya en dos sitios** (A3): atributos del jugador (andar/correr copiados en 3 archivos) y mejoras/consumibles/pigmentos (la síntesis decidida el 24/10 debería nacer con ese lenguaje). Enemigos y glifos, cuando entre el siguiente de cada uno. VFX y niveles son la M5, más adelante.
8. **El estado de partida no se carga nunca** (flags y misiones se guardan y nadie las lee; `Estado` no se guarda) y el **reloj de estados del suelo no corre** (`DURA` a 0, `avanzar()` solo en pruebas): una casilla mojada no se seca jamás (A2).
9. **Biomas**: pantano y desierto salen casi solo con filas de tabla y papeles nuevos; la montaña es el más caro (altura ≥ 2 niveles, quitar el corte de altura de las reacciones). Requisito común: una tabla `TEMPERATURA` por región (la que PLAN_BOSQUE_EOW aparcó) y una segunda textura de estado, porque los cuatro canales ya están ocupados (A2 §D, A6 §C).
10. **Recompensas**: los números de la tinta (4 jefes × 30, 8 secretos × 10) ya dibujan **cuatro zonas**. Propuesta: 3 sellos iniciales (fuego, agua, tierra) y 3 por historia (hielo en la Torre del Agua, rayo en la montaña, viento en el desierto); los 7 glifos que quedan, uno por mazmorra menor (§7).

---

## 1. Programación · funciones inservibles y recogibles (A1)

### 1.1 Lo que se puede quitar

| qué | dónde | tamaño | estado |
|---|---|---|---|
| `Spellcaster` | `magia/spellcaster.gd` | 986 líneas | muerto en el juego (2 herramientas lo cargan); 331 de 384 líneas útiles son copia de `grimorio.gd` |
| Barrera-burbuja antigua (`Lanzador3D.Campo`, `absorber_golpe`, `burbuja_*`) | `magia/lanzador_3d.gd` | ~490 líneas | solo la crea `prueba_barrera.gd`; en el juego devuelve siempre `false`. **Pablo confirma antes de borrar** |
| `lab_grandmaster_3d.gd` | `laboratorios/` | 477 líneas | huérfano: su `.tscn` carga `lab_humanoide_3d.gd` |
| `_barrido` / `_una_ola` y su cadena | `magia/lanzador_3d.gd` | 67 líneas | muerto (ya en ARQUITECTURA) |
| Voltereta de `page_hud.gd:78-87` | `presentacion/ui/` | 10 líneas | busca un método que no existe y rotula «Espacio» en vez de `Ctrl` |
| Campos de sprites de `RuneData` | `nucleo/rune_data.gd` y los 7 `.tres` | — | era 2D; nada los lee |
| `presentacion/grimorio/` | prototipo | 42 MB en git | sin uso |
| `mundo/datos_nivel/*_copia_2026*` y JPEG Meshy Wolfwood | datos | 545 KB + 14 MB | sobrantes; Godot los importa |
| `vista_suelo_editor.gd` | `mundo/` | 129 líneas | ya no está en ninguna escena |
| 45 funciones sin ninguna referencia | lista en A1 | 387 líneas | revisar una a una |
| 10 reenvíos de `Lanzador3D` a `Terreno3D` | `magia/lanzador_3d.gd` | — | nadie los llama |
| 11 capturas «antes/después» ya cerradas | `herramientas/captura_*` | 1 582 líneas | archivar fuera de la batería |

Lo que **no** es muerto aunque lo parezca: `spell_recipe.gd` (lo hereda `Receta3D`; sobran ~170 de 290 líneas), `GLIFOS_V2` (lo leen libro, labs y recarga: hay que **derivarla de `GLIFOS`**, no borrarla), `Estado.nuevo()` (reinicio de 29 pruebas) y las 100 funciones que solo usan las pruebas (678 líneas, ganchos de prueba: se quedan).

Escenas sin referencia: `PruebaJugabilidadBosque.tscn`, `PruebaJugabilidadBosque_1.tscn`, `PruebaNivelBosque.tscn`. **Pablo dice si las abre a mano con F6.**

### 1.2 Lo que se puede recoger en funciones genéricas (por impacto)

| # | duplicación | medida | propuesta |
|---|---|---|---|
| 1 | Herramientas sin armazón | 181 scripts no usan `escenario_base.gd`; 95 copias de `_ok` en 15 variantes; espera de fotogramas y foto repetidas | dos bases: `herramientas/base_prueba.gd` y `base_captura.gd`. Quita ~1 000 líneas |
| 2 | Reglas de nivel | `bosque_01_3d` y `bosque_01_v01_3d` comparten 280 líneas; diálogo y tecla E repetidos en 5 niveles | `ReglasNivel3D` (base) + `ConversacionesNpc` (tabla + manejador de E) |
| 3 | Privados ajenos | 230 `get/call("_x")` en el juego (587 más en herramientas), casi todas a la maqueta; 70 ya tienen función en `Terreno3D` | sustituir esas 70 primero; el resto pide fachada (M5) |
| 4 | Celda ↔ mundo | 17 definiciones de 2,3 y 64 literales; 17 + 15 conversiones en línea | todo a `Terreno3D` (`casilla`, `a_mundo`, `a_celda`) |
| 5 | VFX | ~580 líneas en 12 constructores de partículas, 6 copias de la textura suave | a `VfxKit3D` |
| 6 | Temporizadores | 3 ayudantes «borrar si vive» idénticos, 17 `queue_free` diferidos sin referencia débil | un `Tiempo.borrar_si_vive(nodo, s)` |
| 7 | Letras del mapa | 3 tablas y 114 comparaciones sueltas | una sola leyenda (`Marcador3D.LETRAS`) y consultas por grupo |

**Aviso antes de unificar**: `PruebaTest2._pisable` trata la hierba crecida como sólida y `Terreno3D.pisable` no. Unificarlas cambia cómo se mueve el jugador en la maqueta. Decisión de Pablo.

---

## 2. Programación · la lógica de estados con lo aprendido de EoW (A2)

### 2.1 Diagnóstico

EoW sostiene sus combinaciones con tres reglas: una tabla por sistema, papeles pequeños emisor/receptor, y lógica → tabla → presentación. Medido sistema a sistema:

| sistema | dueño único | datos o `if` | tabla de presentación | lo que falla |
|---|---|---|---|---|
| Suelo (`EstadosSuelo3D`) | sí | tabla | sí | `DURA` a 0 y `avanzar()` solo en pruebas; el hielo lleva **cuatro** relojes de 20 s (Lanzador, AguaSim, Hierba3D, `DURA`) |
| Hierba | **no: cuatro** (`_hf` de la maqueta, `_mojada`, textura de `Hierba3D`, `EstadosSuelo3D`) | autómata en la maqueta | parcial | `segada` no la pone nadie; agua sobre hierba no deja `mojada` |
| Electricidad | **no: tres** | `if` | — | el emisor no escribe `electrificada`: `casilla(x,y).electrificada` no ve sus descargas |
| Objetos (`Reactivo3D` + 28 piezas) | por pieza | 11 formas de «arder», 57 `tags.has`; 26 de 29 piezas escriben a mano «estado + señal» | parcial | los papeles **no se combinan** (`on_spell_hit` sale con `return` tras el primero, `objetos_3d.gd:426-452`); `conduce` y `congelable` siguen solo declarados |
| Enemigos (`Combate3D`) | sí | 8 temporizadores con `if`, ~9 multiplicadores a mano | sí | dos catálogos de reacciones con nombres distintos (Combate3D / Mundo3D); al acabar la quemadura emite `consumido` y sale ceniza de un goblin vivo; `apagado_viento` no lo emite nadie |
| Jugadora | — | — | — | **ningún estado de elemento** (no arde, no se moja, no se congela); `flecha_ardiente_impacta` sin oyente |
| Presentación | — | — | tabla + **30 llamadas directas** | 3 efectos salen dos veces; el estado del suelo se dispara desde `Vfx3D.impacto` (la presentación manda sobre la lógica) |
| Partida (`Estado`, `Flags`, `Misiones`) | sí | — | — | se guardan flags y misiones pero **nadie las carga**; `Estado` no se guarda; nombres de flag no uniformes |
| Puzles (`Puzle3D`) | sí | datos | sí | faltan temporizador, sensor de zona, estado de la jugadora y contadores sobre flags |

Las 29 incoherencias con archivo:línea están en A2 §B.

### 2.2 Los ocho cambios (ordenados por desbloqueo)

| # | cambio | coste | abre |
|---|---|---|---|
| 1 | **Un solo reloj de estados**: `Mundo3D` llama a `EstadosSuelo3D.avanzar(dt)`, `DURA` con valores reales, columna `al_caducar` | S | charcos que se secan, contrarreloj por casilla, calor del desierto |
| 2 | **Un vocabulario de papeles y un catálogo de reacciones** (`mundo/papeles.gd`), un solo nombre por reacción en Combate3D y Mundo3D | M | el Pipeline recibe un catálogo cerrado; arregla los bugs 15–22 |
| 3 | **Componente `ReceptorElemental`** con tabla `{papel, si_tag, desde → hasta, señal, reacción}`; `on_spell_hit` recorre todas las filas | L | variantes por suma/resta de papeles; una pieza nueva es una fila |
| 4 | **Sacar los 30 VFX de la lógica**: cada caso emite su reacción | M | cambiar aspecto sin tocar lógica; niveles probables sin ventana |
| 5 | **Tabla de estados de personaje** compartida con la jugadora (`quemar`, `mojar`, `congelar`) | M–L | la jugadora arde en la hierba y se apaga en el agua; se congela en la montaña |
| 6 | **La hierba entra en `EstadosSuelo3D`** (`mundo/hierba_estado_3d.gd`) | L | enemigos y jugadora se prenden al pisar; condiciones `casilla.ardiendo` |
| 7 | **Puzle3D gana temporizador, sensor, contadores y `cuando=si(expr)`** | M | contrarreloj, «pisa las 5 losas», reaccionar a que la jugadora nade |
| 8 | **Guardar y cargar la partida entera** y regla de nombres `nivel.sala.hecho` comprobable | S | continuar partida |

Si solo se hacen tres: **1, 2 y 8**. Los que más acercan a EoW son 3 y 6, pero tocan al Pipeline.

### 2.3 Hoja de ruta de biomas (pantano, montaña, desierto)

**Cómo diseñar un bioma a partir de ahora** (así el cuarto bioma cuesta la mitad que el segundo): un bioma es **datos en cinco tablas**, no una escena nueva.

| tabla | dueño | qué declara | hoy |
|---|---|---|---|
| `; zona` del mapa + `mundo/regiones_3d.gd` (nuevo) | Juego | `temp=0..4`, `humedad`, `viento=dir,fuerza`, `vision` | `Zonas3D` vive en `presentacion/`: la lógica no puede leer la temperatura |
| `EstadosSuelo3D.TRANSICIONES` (+ columnas `clase` y `temp`, segunda textura) | Juego | los estados de casilla del bioma | 4 canales ocupados |
| `Reactivo3D` papeles + `ReceptorElemental` | Juego | cactus, hongos, carámbanos, matorral seco | papeles no se combinan |
| `LuzZona3D.ZONAS` + paleta ARTE §2 + texturas de suelo | Pipeline | luz, niebla, suelo | pantano y desierto tienen paleta; **montaña no** |
| lámina de Meshy por bioma + `Pieza3D.MEDIDA` | Pablo + Pipeline | piezas | varias ya existen sin usar (nenúfares, raíces, sauce, laja, ruinas, columna, estatua) |

**La tabla `TEMPERATURA` común** (A2 §D) es el primer ladrillo: 0 helado (el agua lanzada se hiela al caer, el hielo no caduca), 2 templado (el bosque de hoy), 4 ardiente (el agua se evapora al caer, la hierba prende sola junto a lo que emite calor). Con ella, **el mismo hechizo hace cosas distintas por bioma sin un `if` por nivel**, que es exactamente la regla de ARTE §2: «el ambiente decide qué elemento importa».

| bioma | identidad del elemento | estados nuevos (fila de `TRANSICIONES`) | papeles nuevos | piezas nuevas | reutiliza | coste |
|---|---|---|---|---|---|---|
| **Pantano** (zona 2, alrededores de la Torre) | **viento** (disipa el gas, empuja balsas) y **fuego** (seca el barro, quema el gas) | `barro` (lento; agua → más barro; calor → `endurecida` pisable 25 s), `semilla` (agua sobre barro → brota `Enredadera3D`) | `explota` (gas), `le_afecta_viento` | `NubeGas3D` (viento la mueve, fuego la enciende: reutiliza la explosión del barril), `HongoEsporas3D` (molde de `EmisorRayo3D`), pasarela de tablones (ya pedida en ASSETS_PENDIENTES) | `AguaSim3D` con `agua_corre=false` y `evapora`, `NieblaFoso3D`, `Lava3D` generalizado a `CharcoReactivo3D` (ciénaga) | **M**: casi todo son filas y papeles |
| **Montaña** (frontera de la zona 2; zona 3) | **hielo** permanente y **rayo** (tormenta, metal) | `nevada` (no prende; calor → mojada), `compacta` (nieve pisada) | `aplasta` (desprendimiento), `pincha` (carámbano) | `Desprendimiento3D` (`MuroAgrietado3D` + señal `cae` que bloquea la casilla destino), ráfaga de viento periódica (empuje por región) | `Terreno3D.alturas`, `Caminos3D` con ±1 | **L**: pide altura ≥ 2 niveles (`MAX_NIVELES_SUBIBLES`), quitar el corte de altura ≥ 1 de `reacciones_suelo_3d.gd:63` y la D1 de ocupación |
| **Desierto** (zona 4) | **tierra** y **viento**; el fuego no da nada (ARTE §2) | `arenosa` (lenta; agua → `compacta` pisable; viento la mueve), `endurecida` | `ilusorio` (espejismo) | `ArenaMovediza3D` (`CharcoReactivo3D` que hunde: reutiliza `_hundirse`), `Espejismo3D` (calor alto: se disuelve al acercarse), tormenta de arena por región (visión) | `DURA` corto por `temp=4`, `VfxViento` cintas como arena, `PulsoPantalla3D` como calima | **M** |

Orden recomendado: **Pantano → Montaña → Desierto**, porque el pantano comparte el agua con la Torre, la montaña prueba la altura (que la Torre también querrá: una torre son niveles) y el desierto solo necesita lo que los dos anteriores ya dejaron.

**Antes de cualquier bioma** (A6): cargar solo las piezas del nivel (hoy la maqueta carga los 144 GLB de `arte/meshy/piezas` en cada nivel, ~240 MB de VRAM estimados) y comprimir texturas; si no, cada lámina nueva se suma a la VRAM de todos los niveles.

---

## 3. Programación · el patrón de `Hechizo` en otros puntos (A3)

El patrón son nueve piezas: datos puros con defecto, un único `construir()` con orden fijo, modificadores `{campo, op, valor, tope}` desde tablas y `.tres`, `origen` por campo, límites globales, ejecutor aparte, `copiar()/con()/tabla()/a_diccionario()`, la capa `CapaBases` del lab y **pruebas de igualdad** (HC1–HC3: refactor sin cambio de comportamiento).

Dos fugas en su propio terreno: `Lanzador3D` modifica el hechizo después de construirlo (pigmento en `lanzador_3d.gd:1179`, altura de salida en `:1213`; el pigmento no deja `origen` y el lab no lo ve), y conviven `GLIFOS` y `GLIFOS_V2`.

| candidato | veredicto | coste | lo medido |
|---|---|---|---|
| **Mejora / Receta / Consumible / Pigmento** | **aplicar ya** | S–M | la cura de la poción está dos veces (`objetos.gd:17` no lo lee nadie; la real es `jugador_3d.gd:47`); `Consumibles.usar` es un `match` de 4 ramas; `recetas_lab.gd` no es síntesis |
| **Atributos del jugador** | **aplicar ya** | S–M | andar/correr 1,6/3,0 copiados en `prueba_test2.gd:27-28`, `jugador_3d.gd:83-84` y `:138-139` |
| Enemigo + `Combate3D` ejecutor | con el próximo enemigo | M | 2 041 líneas; `elemental` aparece 54 veces; el loberno sale como «Goblin guerrero», débil al agua |
| Glifo como `.tres` | con el próximo glifo | M | añadir ᚱ costó 9 líneas en 4 archivos más un PNG |
| Pieza reactiva | más adelante (= cambio 3 de §2) | S + M | `on_spell_hit` y `spell_reacts` deciden lo mismo dos veces (`objetos_3d.gd:420/456`); ninguna pieza lee temperatura ni humedad del Hechizo |
| Bioma | con el primer bioma nuevo | M | 6 `if estilo == "cueva"`; los nombres de zona de los pigmentos no casan con los de la luz |
| VFX | más adelante, Pipeline | M–L | 13 `match` y 55 `if` por elemento en `presentacion/` |
| DatosNivel | más adelante, es la M5 | L | `prueba_test2.gd` 5 798 líneas y 46 `@export`; las reglas entran en la maqueta por dentro 128 veces |
| Misiones / diálogos | no aplicar | — | es una máquina de estados guardable; solo ordenar los diálogos en un formato común |

**Orden**: (1) `Atributos` + `Mejora`, para que la síntesis del 24/10 nazca con el mismo lenguaje; (2) el pigmento como fuente dentro de `Hechizo.construir` y retirar `GLIFOS_V2`; (3) `Enemigo` (y entonces una base común `DatosConModificadores`); (4) `Glifo` como `.tres`. Riesgos: una errata en un nombre de campo pasa en silencio (cada clase valida sus campos al cargar la tabla) y mezclar reglas nuevas con la mudanza (las variantes de enemigo van en un paso aparte; única excepción declarada: el nombre del loberno).

---

## 4. Programación · autotests de resolubilidad de niveles (A4)

**Hoy**: 127 pruebas, todas guiones. `escenario_bosque_01_v01` tiene 170 `_ok`, 44 teletransportes, 0 `mover_hacia`, y fuerza los pasos (`encender_llama`, `muerto = true`, `Flags.poner`). Corrido entero: 119,6 s, 173 OK, 0 FALLO, 5 AVISO; dos avisos dicen que la pasarela se cruza sin barrera con **0 de daño** (andando 5,1 s, corriendo 2,7 s).

**Diseño (dos capas, hacen falta las dos):**

- **Capa 1 · estática** (`herramientas/prueba_resolubilidad.gd`, segundos): lee el mapa, calcula regiones a pie con la regla de la jugadora (`Terreno3D.pisable`, no `Caminos3D.transitable`: en la losa discrepan), deriva las **capacidades** del repertorio llamando a `Hechizo.construir` con todas sus combinaciones (18 018 con el kit `pruebas`), trata las piezas de `Puzle3D` como puertas con condición, y busca en el grafo de estados (región × flags × llaves × glifos). Seis invariantes: meta alcanzable; opcionales alcanzables o declarados secretos; sin estados sin salida (llave gastada, cerrojo que no reabre); cada puzle con solución **y, si se declara, sin solución sin el glifo que enseña**; ids y letras existentes; flags sin lector o sin escritor. Gramática nueva en el propio mapa: `; prueba meta=flag.x inicio=S opcionales=… obliga=barrera@tramo` (cambio exacto a `HorneadorNivel.leer_extras` en A4). Prototipo: **3–16 ms por nivel**.
- **Capa 2 · dinámica** (`escenario_recorrido_niveles.gd` + `automata.gd`, minutos): ejecuta el plan JSON que sale de la capa 1 con teclas reales, sin teletransportes, con recarga y tinta reales; si falla vuelca el PlayLog y un mapa ASCII (los PNG solo con ventana). Modo fuzz fuera de la batería: hechizos aleatorios del repertorio por sala para cazar estados rotos.
- **Por qué las dos, medido**: la capa 1 marcó la losa (16,9) como trampa; andando de verdad el agua llega a los 19 s y la jugadora sale.
- **Integración**: `tools\pruebas.cmd` y `resumen_prueba.ps1` los recogen por el prefijo; un nivel nuevo entra con líneas `; prueba`, sin código.

**Problemas que ya detecta**:

| nivel | problema |
|---|---|
| Bosque 01 v01 | la barrera **no es obligatoria** (estático y dinámico); además `kit = "pruebas"` la da desde el principio, así que `cofre_01` (legendario) no enseña nada |
| Bosque 01 v01 | el arroyo se cruza con hielo sin el tronco |
| Bosque 01 v01 | tótems y puerta X viven en `bosque_01_v01_3d.gd:569-682`: un análisis del mapa no los ve. Declararlos con `; prueba regla` o pasarlos a `Puzle3D` |
| Cueva | el cofre legendario **se desella solo**: la fuente (24,12) late cada 4 s y su pulso llega al receptor (14,13) sin la jugadora |
| Cueva | con la progresión real `bosque` (fuego + flecha) **no se puede terminar**: la grieta pide tierra y la lava agua o hielo (razonado, no corrido) |

Orden de implementación: **S** regiones + referencias + flags (prototipo al 70 %); **M** capacidades + buscador + invariantes + plan; **L** autómata + fuzz. Límites honestos: no detecta diseño aburrido ni puzles triviales (salvo «se resuelve solo» o «sin el glifo que enseña») ni timing fuera de la ruta del plan.

---

## 5. Programación · `Hechizo`: especificación, el Sello y la ejecución real (A5)

**Sobre «Sello».** ARQUITECTURA y CONTEXTO dicen Sello = elemento, y así se ha auditado. Pero el código viejo sigue llamando «sello» al glifo: `sigils.gd:4`, `GestureLibrary.BIBLIA` (uso «sello»), avisos de `grimorio.gd` y el contador del libro «sellos 2/6», que cuenta glifos. No hay un documento «Sello» aparte. **Propuesta**: renombrar esos textos visibles (el contador del libro el primero) para que el jugador y los documentos hablen igual.

**Lo que cumple**: los seis `.tres` coinciden con ESPEC §2; barrido de **8 008 multiconjuntos × 6 elementos = 48 048** construcciones sin `null`, sin límite de §1.9 superado, `copiar()` y `con({})` idénticos, y el camino del libro (`Receta3D`) da la misma tinta, recarga y forma que `Hechizo` en todos los casos; 1 716 casos ejecutados con `HechizoVivo.crear`: cada elemento corre en haz, proyectil y volumen quieto (solo se rechazan tierra y hielo con ᛏᛏᛏ, por altura, a propósito). Diez pruebas corridas, FALLOS 0; los 4 fallos de `prueba_hechizo` de la entrada 249 ya no salen.

**Incumplimientos, de más a menos grave**:

| # | qué | dónde | gravedad |
|---|---|---|---|
| 1 | **ᚠ repetición**: flecha + ᚠ lanza **un** proyectil; en volúmenes, con copias pares se solapan (ᚠ×1 da 1 casilla en vez de 2). El «abanico de 3 bolas» de GLIFOS_RECETA solo sale en `prueba_receta_v2` porque fuerza `velocidad = 0` | `hechizo_vivo.gd:123` | bloqueante: un glifo del repertorio no hace lo que dice |
| 2 | **Flechas de tierra y de hielo** caen a 0,70 casillas de las 2 prometidas (0,43 desde la mano real): gravedad 1 sin `impulso_salida` (al agua se le puso en la entrada 239) | `.tres` de tierra y hielo | bloqueante para el Sello: dos de seis elementos no cumplen su alcance |
| 3 | **Límite de glifos**: la lámina «bosque» tiene 3 huecos; `MAX_GLIFOS = 6` solo rige en el lab. Solo **990** de las 48 048 combinaciones son lanzables desde el libro | `spellbook.gd` / `Repertoire.libro` | decisión de diseño: ¿3 huecos al empezar y crecen, o 6? |
| 4 | **ᛉ permanencia y ᚱ pulso no se pueden dibujar** (sin muestras en `gesture_library.tres`); ᛉ no está en ningún kit; ᚱ se gana en la Cueva pero solo entra por la paleta F1 | `gesture_library.tres`, kits | bloqueante para la Cueva: la recompensa no se usa jugando |
| 5 | ESPEC §0.3 contradice al código: la flecha deja su materia durante `persiste` al pararse (regla de la entrada 191; la ESPEC no se actualizó) | `hechizo_vivo.gd:1208` | documental |
| 6 | Barrera + flecha con esqueleto parece nacer en la mano y no en el punto apuntado desde `desplaza_mano` (`7a91ea36`); sin prueba | `hechizo_vivo.gd` | comprobar en pantalla |
| 7 | **El proyectil atraviesa muros con solidez**: no consulta `SolidezV2`; solo `trazar` lo hace | `lanzador_3d.gd:1573` | rompe «la barrera para proyectiles» en el juego |
| 8 | **ᚷ crecer** se aplica como escala/s y no en m/s; con ≤ 3 glifos **nunca cambia una casilla** (390 de 390) | `hechizo_vivo.gd` | el glifo no hace nada medible |
| 9 | `resistencia` 30 × solidez frente a 10 en ESPEC; falta el límite de altura total de §1.9 | `hechizo.gd:73` | decisión |
| 10 | `figura()` dice «barrera» para barrera + flecha, que corre como proyectil; nadie la usa en el juego | `hechizo.gd:549` | pulido |

**Campos que nadie lee** (construidos pero no ejecutados): `potencia`, `intensidad_estado`, `elasticidad`, `ralentiza_fuerza`, `densidad`, `temperatura`, `humedad`, `conductividad`. **Se leen del `RuneData` y no del `Hechizo`**: `empuje`, `deja`, `pisable`, `color` (tocarlos en el lab no hace nada). **Solo llegan desde el lab**: `aceleracion`, `elevacion`, `retardo`, `retorna`, `busca`, `perfora`, `radio_explosion`, `golpea_lanzador`, `veneno`, `choca_con`, `estela`, `efecto_impacto` y todos los `eventos` (código preparado sin glifo ni `.tres` que lo produzca).

**Pruebas nuevas propuestas** (hoy fallarían por 1, 2, 4 y 8): `prueba_barrido_hechizos` (las 48 048 construyen y respetan límites; el script `barrido_hechizos.gd.txt` de esta carpeta es la semilla), `prueba_ejecucion_combinaciones` (cada glifo cambia algo medible al ejecutarse: copias → n proyectiles, crecer → casillas, flecha → alcance por elemento), `escenario_libro_combinaciones` (lanzar por el libro real, no por `lanzar_receta`), `prueba_glifos_dibujables` (todo glifo del repertorio tiene muestras), `prueba_campos_ejecutados` (todo campo de `Hechizo.CAMPOS` lo lee alguien o está marcado «aparcado»), `prueba_en_punto_proyectil`.

---

## 6. Capa de presentación (A6)

### 6.1 Lo que rompe la calidad

| problema | evidencia | arreglo | coste | dueño |
|---|---|---|---|---|
| El nivel de arranque parece una build de desarrollo | HUD de depuración (teclas, FPS, triángulos) y paleta F1 siempre visibles y pisándose (`prueba_test2.gd:1195`, `:5191`); rótulos «PÍSAME», «SOLO AGUA» (`pulsador_3d.gd:68`) | ocultos de serie; F1/F3 los enseñan | S | Pipeline |
| Los puzles del juego se dibujan con primitivas | pulsador, barril, compuerta y molino son cajas y cilindros; `PiezaPuzle3D` con sus 3 láminas de Meshy no la llama ningún objeto del juego | enganchar `PiezaPuzle3D` a los objetos | M | Pipeline |
| Cuatro familias de árbol mezcladas y V8 deshecho | 151 `arbol_redondo` (12 k), 135 `_2` (bolas), 111 `pino`, 34 `pino_2` turquesa; `_id_real` prefiere el GLB de 12 k: ~3,7 M de triángulos en árboles (cálculo) | una familia de árbol y una de pino, decimadas | M | Pablo (Meshy) + Pipeline |
| La jugadora desaparece bajo las copas | capturas `region_tala`, `region_prado` | silueta/oclusión siempre | S | Pipeline |
| La boca de la Cueva es una losa | `boca_cueva.glb` existe y no está colocado | colocarlo | S | Pablo (editor) |

### 6.2 Lo que se nota

- La maqueta carga los **144 GLB** de `arte/meshy/piezas` en cada nivel (`_cargar_bibliotecas`, l. 2531), ~20 sin uso; ~240 MB de VRAM estimados. Unos **235 MB de texturas sin comprimir** (88 piezas pequeñas y todo lo posterior a V8: jugadora, ropa, marimanta, elfo, goblins nuevos; `goblin_behit_flyup`/`stand_up` cargan 6 texturas de 2048² para 2 clips).
- Presupuesto frente a EoW: jugadora 31 k + ropa 29 k = **60 k** (EoW 9–11 k); goblins 31 k (EoW 1,8 k); grimorio 15 k; 83 de 144 piezas pasan de 3 k, y 50 tienen justo 8 000 y 17 justo 12 000: **son los valores por defecto de la herramienta, no un presupuesto**.
- Hierba muy saturada (0,51 frente a 0,39 de `Paleta3D.HIERBA`): se ve neón.
- Rayo y hielo con colores distintos en el libro y en el VFX (el rayo sale azul; en `RuneData` y ARTE §1 es amarillo).
- Acabado desigual por elemento: viento > bola de fuego > tierra > agua > haz de fuego (pálido) > rayo > haz de hielo (prisma liso) > tiempo. Pablo solo ha validado fuego y agua.
- La Cueva se sale de su paleta (muro amarillo, paredes verde lima repetidas, tapa del cofre flotando).
- Dos fuentes y ninguna en el proyecto (`SystemFont` Trebuchet en el tema; la de Godot en libro y diario).
- 17 escenas de `arte/piezas` con la malla duplicada (1,0–1,6 MB cada una): se arregla re-horneando (generador ya corregido en `3a178de5`).

### 6.3 Pulido

5 `smoothstep` con bordes invertidos; 67 shaders en cadenas dentro de `.gd` (3 757 líneas, ningún `.gdshader`), 3 versiones del agua y 3 de las llamas; peso muerto importado (`art/forest`, `presentacion/grimorio`, texturas de 4096², `docs/` sin `.gdignore`); `auditoria_texturas.tsv`, `QA_ARTE.md`, `PLAN_HOMOGENEIZAR_ARTE.md` y `EXPERIMENTOS_ESTILO.md` caducados (era 2D); audio con foley grabado y pisadas por material, pero **sin música, sin ambiente por bioma, sin buses**.

**Lo que está bien**: `Ocluso3D` es un material común de verdad (tramado, quemado, disolución, viento), `LuzZona3D` hace el ambiente de dos colores, el posproceso y las tablas de reacciones y logros están montados, y el menú EoW y su tema están bien resueltos.

### 6.4 Las diez mejoras con más calidad por coste

1. Quitar lo de desarrollo (S). 2. Una familia de árbol y de pino, decimadas (M). 3. `PiezaPuzle3D` en los objetos del juego (M). 4. Saturación de hierba a la paleta (S). 5. Jugadora siempre visible (S). 6. Fuente propia y tema único (S). 7. Colores de elemento unificados y los tres haces flojos (S–M). 8. Cueva en paleta y boca con modelo (M). 9. Música y ambiente con buses (M). 10. Comprimir texturas y cargar solo las piezas del nivel (S–M).

**No comprobado** (sin GPU en el análisis): aspecto real en Forward+, FPS en la UHD 620, VRAM real, tirones de compilación, audio, la esfera rosa alrededor de la jugadora en `lanzar_x_mano_instante`.

---

## 7. Balance de recompensas y la Torre del Agua

### 7.1 Lo decidido que condiciona el resto

- Sellos por historia; glifos, uno por mazmorra temática; todo glifo sale de un cofre legendario con desafío propio (Pablo, 24/10).
- Tres calidades: común (ingredientes), épico (ingredientes de mejora por recetas: vida, tinta, pigmentos), legendario (glifos). La ropa llega hecha.
- Tinta: 100 inicial + 120 de jefes (`JEFES = 4` × 30) + 80 de secretos (`SECRETOS = 8` × 10), tope 300. **Esos números ya son cuatro zonas con un jefe y dos secretos cada una.**
- Paletas medidas (ARTE §2): Bosque, Ciudad, Cueva, Pantano, Cueva volcánica, Desierto. Faltan Montaña y Playa.
- Repertorio de serie (`Repertoire.P0`): fuego, agua, viento, rayo + flecha, barrera. El Bosque 01 v01 arranca con `kit = "pruebas"` (todo). **Hay que fijar el kit real**: es la raíz de que la barrera no enseñe nada y de que la Cueva no sea terminable con `bosque`.

### 7.2 Propuesta de progresión de sellos

| cuándo | sello | por qué ahí |
|---|---|---|
| inicio | **fuego, agua, tierra** | el Bosque 01 v01 y la Cueva ya los piden (telaraña, estanque, muro agrietado). Tres sellos × pocos glifos ya dan decisiones sin abrumar |
| **Zona 2 · Torre del Agua** | **hielo** | la torre enseña el agua en sus tres estados (líquido, vapor, hielo) **antes** de darlo, como la Cueva con el pulso. El hielo convierte el agua del pantano y de la playa en camino, corta la corriente y abre la montaña |
| Zona 3 · Montaña | **rayo** | tormenta en la cima, metal y conductores; el agua de la zona 2 ya enseñó a conducir |
| Zona 4 · Desierto | **viento** | arena, tormentas, molinos: donde el viento gana identidad propia |

Alternativa si Pablo prefiere empezar solo con fuego: la Torre da **agua**, la montaña hielo, el desierto tierra y viento. Cuesta más porque la Cueva ya pide tierra y hielo (C2, C5) y habría que reordenarla.

**Por qué hielo y no agua en la Torre del Agua**: el nombre invita a dar agua, pero el agua ya es necesaria en el Bosque (estanque, lava de la Cueva, apagar). Dar hielo convierte la torre en una lección sobre el agua que ya tienes («tu agua puede ser suelo, puede ser pared, puede cortar la corriente»), y encaja con el patrón que funciona: **se ve antes de tenerse** (charcas heladas por el frío de la torre, pasos que solo se cruzan helando) y **se usa justo después** (la salida pide helar). Además es el sello que más terreno abre en los alrededores: pantano (agua estancada), playa (orilla) y montaña (hielo permanente).

### 7.3 Cómo se arma la Torre del Agua con lo que hay

| capa | qué | piezas existentes |
|---|---|---|
| **Historia (sello hielo)** | jefe del agua en lo alto; la torre son niveles (altura ≥ 2 es requisito; ver montaña) | `AguaSim3D` (llenado de salas, `fijar_nivel`, compuertas), `Compuerta3D`, `NivelAgua3D`, `TroncoEstanque3D`, `Molino3D`, `Surtidor3D` |
| **Mazmorras menores con glifo** (alrededores) | **Pantano → ᛉ permanencia** (barreras que duran como pasarelas sobre el barro); **Gruta de la playa → ᚢ rebote** (proyectiles que rebotan en rocas para alcanzar receptores tras la niebla); **Montaña baja → ᛏ altura** (columnas para escalar) | `SecuenciaCofreLegendario3D`, `Puzle3D`, `MuroAgrietado3D`, `Pulso3D` (receptores) |
| **Secretos (2 épicos = +20 tinta)** | pared hueca y estatuas (ya existen en la Cueva) con ingredientes de mejora | `pared_hueca_pulso_3d.gd`, estatuas de C1 |
| **Comunes** | ingredientes por reacción del bioma (alga, junco, sal, barro cocido) | `Objetos.PLANTAS`, `Recolectable3D` con `coge_si=` |
| **Jefe (+30 tinta)** | `Tinta.ganar_jefe()` existe y nadie lo llama | — |

Reparto de los glifos restantes (10 ids; flecha de inicio, barrera en el Bosque, ᚱ en la Cueva): zona 2 → permanencia, rebote, altura; zona 3 → repetición, línea; zona 4 → crecer. Así cada zona tiene **un sello de historia + 2–3 mazmorras menores**, y los totales quedan cerrados como en EoW (6 sellos, 10 glifos, 300 de tinta, 4 jefes, 8 secretos).

### 7.4 Otras recompensas de la misión principal (además del sello)

Para que la misión principal de cada zona dé algo más que el sello sin romper la regla «glifos solo en mazmorras»: **una página más del libro** (`Repertoire.max_pages`, ya existe: 1 → 2 → 3 por zona), **un hueco de glifo** (`max_sigils_per_page`: 3 → 4 → 5 → 6, lo que a la vez resuelve el punto 3 de §5 y convierte las 48 048 combinaciones en progresión), **la ropa** (prenda por zona, `Ropa3D`), y los **+30 de tinta** del jefe. Las recetas (vida, tinta, pigmentos) quedan para los secretos y los comunes, como está decidido.

---

## 8. Decisiones que necesita Pablo

1. **Kit real de arranque** (§7.1): ¿fuego + agua + tierra con flecha, o solo fuego + flecha? Condiciona la Cueva y el desafío de la barrera. — **27/10, Pablo:** el primer libro tiene sitio para 4 elementos y 6 glifos (capacidad que se llena jugando); la mazmorra de la barrera (Gruta Batida) es obligatoria por historia antes del Bosque. Ver PENDIENTES, «Libro y progresión».
2. **Huecos de glifo**: ¿3 al empezar y uno más por zona (propuesta), o 6 desde el principio? — **27/10, Pablo:** los 3 huecos del círculo se quedan; lo que crece es la página derecha (4 elementos y 6 glifos en el primer libro, más en un libro posterior).
3. **Sello de la Torre del Agua**: hielo (propuesta) o agua.
4. **Borrar la barrera-burbuja antigua** (~490 líneas de `Lanzador3D`) y `spellcaster.gd`.
5. **Las tres escenas sin referencia** (`PruebaJugabilidadBosque*`, `PruebaNivelBosque`): ¿se abren a mano?
6. **`_pisable` de la maqueta frente a `Terreno3D.pisable`** (hierba crecida sólida o no).
7. **`resistencia` 30 frente a 10** y el límite de altura total de §1.9.
8. **Renombrar «sello» → «glifo»** en los textos del libro y los avisos.
9. **Presupuesto de triángulos real** (hoy son los valores por defecto de la herramienta): propuesta en A6 §7.3.
10. **Paleta de Montaña** (propuesta en A6 §C) y el preset de luz de los tres biomas.
11. **Los 103 archivos `.import`/`.uid`** que el análisis generó en el worktree al importar (ver §10): decidir si se commitean desde la copia principal, que es la que tiene la caché buena.

---

## 9. Plan de trabajo propuesto (por lotes y contexto)

Cada lote termina con sus pruebas a 0, su captura y su entrada en el DIARIO. Los lotes 1–3 son los que más valor dan por coste y no dependen de decisiones abiertas salvo donde se indica.

| lote | contexto | qué | depende de |
|---|---|---|---|
| **1 · El Sello se ejecuta** | Juego (Sonnet programa, Opus verifica) | A5 puntos 1, 2, 7, 8 (repetición con flecha, impulso de tierra y hielo, proyectil contra solidez, crecer en m/s) + las 6 pruebas nuevas de §5 + ESPEC §0.3 al día | — |
| **2 · Progresión cerrada** | Juego + Pablo | kit real de arranque, huecos por zona, muestras de ᛉ y ᚱ (Pablo graba con G), barrera obligatoria en la tala, cofre de la Cueva que no se desella solo | decisiones 1–3 |
| **3 · Estados: reloj, catálogo y partida** | Juego | cambios 1, 2 y 8 de §2.2 | — |
| **4 · Autotest de niveles, capa 1** | Juego | `prueba_resolubilidad.gd` + gramática `; prueba` en Bosque 01 v01 y Cueva | lote 2 (para que la prueba afirme lo correcto) |
| **5 · Build limpia** | Pipeline | mejoras 1, 4, 5, 6, 10 de §6.4 (todas S) | — |
| **6 · Atributos y Mejora** | Juego | A3 orden 1 y 2: `Atributos`, `Mejora`, pigmento dentro de `construir`, retirar `GLIFOS_V2` | — |
| **7 · Limpieza** | Juego / Pipeline | §1.1 (tras decisiones 4–5), bases de herramientas, celda↔mundo a `Terreno3D` | decisiones 4–6 |
| **8 · Arte del nivel real** | Pablo (Meshy) + Pipeline | árboles, `PiezaPuzle3D`, Cueva en paleta, colores de elemento, haces flojos | presupuesto (decisión 9) |
| **9 · Estados: receptor, VFX fuera de la lógica, jugadora** | Juego + Pipeline | cambios 3, 4, 5 de §2.2 | lote 3 |
| **10 · Autotest capa 2 y fuzz** | Juego | autómata + fuzz | lote 4 |
| **11 · Regiones y temperatura** | Juego + Pipeline | `mundo/regiones_3d.gd`, `TEMPERATURA`, segunda textura, presets de luz de los tres biomas, paleta de montaña | lotes 3 y 9 |
| **12 · Pantano (primer bioma nuevo)** | todos | §2.3, con la Torre del Agua como ancla | lote 11, carga por nivel y texturas comprimidas (A6) |

---

## 10. Cómo se midió y qué queda en el aire

- Seis análisis independientes sobre el worktree en `7a91ea36`, en solo lectura; scripts de medición y salidas en el scratchpad de la sesión (resumidos en los anexos). El barrido de `Hechizo` y los prototipos de resolubilidad se corrieron con Godot 4.7.2 sin ventana.
- **Efecto secundario a resolver**: el worktree no tenía `.godot/`, y al importar aparecieron **103 archivos sin seguimiento** (`.import` de las piezas de la Cueva y 28 `.gd.uid`). Ningún archivo versionado cambió. No se han commiteado: si la copia principal los tiene con otros uid, commitearlos desde aquí rompería referencias. Lista en `import_creados.txt` del scratchpad; conviene commitearlos **desde la copia principal**, que es la que lleva la caché de Pablo.
- Nada de lo visual se ha juzgado en pantalla con GPU; las capturas de `docs/capturas/` del 24/10 son la base de §6.
- Los números de triángulos y VRAM de §6 son cálculos por bytes y recuentos de malla, no mediciones en ventana.
