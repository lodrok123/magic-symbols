# Prueba 2 de VFX en Unreal: muro de fuego toon (1/11/2026)

Proyecto `E:\UnrealProjects\MS_POC_VFX` (UE 5.8.4, el de la prueba 1), carpeta `/Game/POC2`. Referencia que manda:
`../referencia/ref_muro.jpg` (Zelda BotW). Todo se construye por scripts Python que ejecuta el editor desde la cola
`Saved/cola_py` (`scripts/init_unreal.py`); los scripts del proyecto están copiados en `scripts/`.

## 1. Horas (reloj de agente, editor abierto desde las 12:41 y sin reiniciar: 0 reinicios)

| Paso | Horas | Qué |
|---|---|---|
| Técnica 1: textura de ruido propia + `M_FuegoToon`, `M_HumoToon`, `M_ChispaToon` e instancias por `MaterialEditingLibrary` | 0 h 15 | `scripts/poc2_material.py` |
| Técnica 1: `NS_MuroFuegoToon` (malla plana + lenguas + humo + chispas + luz), `BP_MuroFuegoToon`, tecla 5 | 0 h 12 | `poc2_niagara.py`, `poc2_bp.py`, `poc2_personaje.py` |
| Capturas en PIE y prueba de los 12 fps (7 rondas de ajuste) | 0 h 20 | `poc2_capturas.py`, `poc2_gif.py` |
| Comparación con la referencia y medida objetiva | 0 h 20 | `poc2_distancia.py` |
| Técnica 2 (tutorial de CGHOW adaptado), rondas 8-17 | 0 h 35 | `poc2_material_cghow.py`, `poc2_niagara_cghow.py` |
| Script de aserciones, intento sin interfaz, GIF, copia, notas y diario | 0 h 25 | `poc2_prueba.py` |
| **Total** | **≈ 2 h 10** | (de las 16 h de presupuesto; la hora de Pablo no se ha usado) |

## 2. Método entregado (técnica 2: «UE 5.5 Quick and Easy Stylized Fire» de CGHOW, vídeo 2A4AMI-SHIQ, adaptado a la referencia)

**Material `M_FuegoToon`** (Unlit, Masked, dos caras, 271 instrucciones, 89 nodos, sin textura), por pasos del tutorial:
2-3) nodo **Noise** procedimental (Voronoi ALU, 3 niveles, salida 0..1) sobre (x, y, 0); 4) degradado radial exponencial
(hecho a mano: `pow(saturate(1 - distancia(uv, centro) / Radio), Erosion × Densidad)`); 5) **Power** (`Contraste`);
6) coordenadas estiradas en vertical (`EstiradoU` = 1, `EstiradoV` = 0,2); 7) paneo hacia arriba sumando
`(desfase, desfase + tq × Velocidad)` con **tq = floor(Time × Fps) / Fps**; 8) **ParticleColor**: RGB multiplica el
emisivo y A multiplica la máscara (al morir, la lengua se come desde el borde); 9) **DynamicParameter**
(`Densidad` por partícula desde Niagara) y desfases de paneo distintos por partícula (`ParticleRandom`).
Adaptación obligatoria: máscara **dura** (`Step(Umbral, m)`, sin opacidad suave) y **rampa de tres tonos planos**:
crema en la mitad baja de cada lengua con corte ondulado por el ruido (`Banda`), naranja en el cuerpo, rojo solo en
el borde superior fino (`BandaBorde`); nada de degradado a negro. Dos añadidos propios: `InvertirRuido` (el Voronoi
invertido da gotas en vez de una red de anillos, ronda 9→10) y `Resta` (radial − (1 − ruido) × `AmplitudRuido`:
puntas apuntadas en los valles del ruido en vez de bultos redondos, ronda 12→13).
Mandos en castellano en las instancias (los diez de §1 y los del tutorial): `Fps, Umbral, Banda, BandaBorde, AlturaLlama,
Erosion, Desplazamiento, Contorno, Velocidad, EscalaRuido, Brillo, EstiradoU, EstiradoV, Contraste, Radio, InvertirRuido,
Resta, AmplitudRuido` y los colores `ColorNucleo (#FFE060), ColorCuerpo (#F07820), ColorBorde (#C83018), ColorContorno`.
Instancias: `MI_FuegoToon_Lengua` (rampa completa) y `MI_FuegoToon_Cuerpo` (capa base: todo crema, umbral 0,30).

**Niagara `NS_MuroFuegoToon`** (paso fijo `fixed_tick_delta` = 1/12 s en toda la simulación; `User.Longitud`): 10) sin
gravedad, nacen en una caja de 690 × 30 cm; 11) vida corta 0,8-1,3 s; 12) curva de tamaño que crece rápido (0,15 s) y se
mantiene; 13) alfa por vida (1 → 0 en el último tercio) en vez de color a negro; 14) **cambiado**: eje vertical fijo
(`CUSTOM_ALIGNMENT` + `FACE_CAMERA_POSITION`, pivote abajo) en vez de alineación a la velocidad, porque las lenguas de
la referencia son más anchas que altas (sprites de 110-200 × 80-140 cm, «Random Non-Uniform»); 15) `DynamicMaterialParameter`
aleatorio por partícula; 16) dos capas: `Lenguas` (28/s·L) y `Base` (6/s·L, lenguas bajas todo crema). Más `Humo`
(2,5/s·L, bolas grises de dos tonos de 9-15 cm desde la punta, z 100-125), `Chispas` (40/s·L, 2,5-4,5 cm, alineadas a la
velocidad) y `Luz` (una, radio con titileo en escalones de 1/12 s, `RCIM_CONSTANT`). Presupuesto tasa × vida = 81
partículas por muro (≤ 300). `BP_MuroFuegoToon` y la tecla 5 del personaje son de la técnica 1 (sin cambios).

La técnica 1 (`poc2_material.py` + `poc2_niagara.py`: textura de ruido de valor propia, malla plana de 6,9 × 1,5 m con el
material y lenguas en sprites, `f = ruido + (1 − h) × Erosion`) queda en `scripts/` como registro; su mejor ronda (7) daba
distancia 1,075 y, vista junto a la referencia, zonas planas enormes, islas de crema en medio del naranja y bolas de
humo demasiado grandes (lo que Pablo llamó «papel recortado»).

## 3. Rondas, distancia a la referencia y juicio visual

Medida (criterio de Pablo): franja del fuego de `ref_muro.jpg` (filas 270-380 de 668) y rectángulo del muro en mi
`muro_cerca.png` (filas 370-780 de 1080); histograma tono × valor cuantizado 8 × 8 sobre los píxeles con saturación > 0,4,
normalizado; distancia L1 (0 = igual, 2 = nada en común). `py -3 scripts/poc2_distancia.py <ref> <captura> 0 370 1920 780`.
Controles: el muro realista de la prueba 1 da **0,680** (el fuego real tiene naranjas oscuros como la hierba de la
referencia); `ref_muro_b.jpg` contra `ref_muro.jpg` da **1,627** (la medida es muy sensible al recorte y a la exposición:
hay que leerla junto con la vista, no sola).

| Ronda | Cambio | Distancia | Reparto saturado (naranja-rojo / amarillo) | Vista junto a la referencia |
|---|---|---|---|---|
| 7 (técnica 1) | bloom y viñeta fuera | 1,075 | 99 % / 1 % | naranja demasiado claro y amarillento (#F8A000), crema lavada (#F8F088, por debajo de s = 0,4), rojo 24 %; islas de crema, zonas planas |
| 8 | técnica 2, primera | 0,852 | 84 / 16 | **no vale**: solo sobrevive el centro del radial (fichas rojas sueltas) y manchas de crema en el suelo |
| 9 | umbral 0,12, Brillo 0,5, colores medidos | 0,542 | 99 / 1 | **no vale**: red de anillos rojos (el Voronoi vale 1 en los bordes de celda), masa sin lenguas; colores ya bien (#E08018, #C02008, #E0D870) |
| 10 | ruido invertido (gotas), sprites más pequeños y más | 0,845 | 47 / 53 | nubes redondas con contorno rojo, demasiada crema |
| 11 | menos crema, ruido más estirado | 0,716 | 85 / 15 | proporciones bien, pero «coliflores» redondas y alfombra crema en el suelo |
| 12 | crema por peso vertical | 0,668 | 89 / 11 | **mejor distancia**, peor vista: la crema son óvalos en medio; bultos redondos |
| 13 | `Resta` (puntas en los valles del ruido), 3 niveles | 0,763 | 82 / 18 | puntas apuntadas por fin; crema aún en islas |
| 14 | crema = mitad baja con corte ondulado | 1,056 | 37 / 63 | estructura correcta (crema abajo, naranja, rojo arriba) pero crema al 63 % |
| 15 | `Banda` 0,18, capa base pequeña | 0,692 | 76 / 24 | la más parecida hasta aquí; rojo también en los lados |
| 16 | rojo solo arriba | 0,737 | 63 / 37 | rojo bien; la captura pilló el muro bajo y la crema parece franja en el suelo |
| **17 (entregada)** | `Banda` 0,16, corte menos ondulado | **0,712** | 72 / 28 | lenguas apuntadas naranja con punta roja, crema ondulada en la base y mitad baja, solapadas a varias profundidades |

Se entrega la 17 y no la 12 (0,668) ni la 9 (0,542): la regla era «baja la distancia **y** se acerca a la vista», y en
esas dos la vista era peor (óvalos, anillos). Entre la 15 (0,692) y la 17 (0,712) la diferencia está dentro de lo que
cambia la medida de un fotograma a otro con los mismos mandos; la 17 tiene el rojo solo arriba, como la referencia.
Juicio propio sobre la 17: **3,5 sobre 5** del mismo estilo de fuego. Lo que aún le falta frente a `ref_muro.jpg`:
- las lenguas siguen siendo recortes planos apilados (en la referencia se funden unas con otras sin borde entre ellas);
- la crema de la base es demasiado regular (en la referencia es una franja irregular que se mezcla con la hierba) y,
  vista desde arriba a 2 m, a veces se lee como una franja en el suelo;
- no hay halo ni brillo sobre el suelo: el bloom se apaga para que la paleta se quede en ≤ 8 colores (con bloom, la
  rampa plana se convierte en degradados); la luz única ilumina poco a plena luz del día del mapa de prueba;
- la referencia tiene matices de naranja oscuro (hierba quemándose) que un fuego de tres tonos no tiene.
Lo que sí coincide: tres tonos planos y sus valores (#E88818 / #E0D870 / #C82010 medidos), rojo solo en el borde
superior fino, crema abajo, puntas apuntadas, muchas chispas pequeñas, poco humo gris en bolas.

Las capturas de las rondas 7-16 se sobrescribieron (`Saved/Screenshots`): solo queda la 17.

## 4. Rasgos de §0.1 del diseño

| Rasgo | Estado |
|---|---|
| Tres tonos planos en rampa (crema, naranja, rojo) | **sí** (4 colores principales en `muro_cerca.png` a 5 bits: 54 % naranja, 26 % crema, 10 % rojo, 7 % naranja claro) |
| Lenguas como gotas invertidas con erosión dura | **a medias**: puntas apuntadas por el ruido y Masked (borde duro); no son gotas limpias, son crestas |
| Todo a 12 fps cuantizados | **sí**: paso fijo de Niagara 1/12 s y `tq` en el material. Prueba: 6 capturas a 1/24 s de juego (`muro_q0..q5`, a `slomo 0.1` y sin antialiasing): los pares q1-q2 y q3-q4 son idénticos (0,01 % de píxeles) y los demás cambian el 8-12 %; en la secuencia a 1/12 s (`muro_2m_12fps.gif`, 40 cuadros) los 39 pares cambian el 8-16 % |
| Material Unlit + Masked | **sí** (los tres) |
| Una sola luz (LightRenderer) | **sí**, con titileo en escalones |
| Humo en bolas de dos tonos desde la punta | **sí**, pequeño y escaso (nace a 100-125 cm) |
| Contorno opcional | **sí**, mando `Contorno` (`muro_contorno.png` con 1,0) |
| Legible a 10 m | **sí** (`muro_lejos.png`, `juego_muro.png`) |
| Diez mandos en castellano | **sí** (18 escalares + 4 colores) |
| ≤ 300 partículas, ≤ 8 colores | **sí** (81 y 4) |
| Columna y bola | **no** (solo muro, como pedía el diseño si el tiempo no sobraba; sobra tiempo pero el muro no llega a 4/5) |

## 5. Pruebas

`scripts/poc2_prueba.py`: 19 comprobaciones (materiales existen, Unlit, Masked, compilan; los diez mandos; sistema
existe; paso fijo 1/12; ≤ 1 luz contando objetos `NiagaraLightRendererProperties` del sistema con `ObjectIterator`;
presupuesto ≤ 300; paleta ≤ 8 colores con lector PNG propio). En el editor: **19 OK, 0 fallos**
(`poc2_prueba_resultado.txt`).

**Sin interfaz**: `UnrealEditor-Cmd.exe MS_POC_VFX.uproject -run=pythonscript -script=Scripts\poc2_prueba.py -unattended
-nopause -nosplash` con el editor abierto a la vez: **funciona**, 15 s, código de salida 0, 16 OK y 3 omitidas (el
commandlet no compila shaders: `get_statistics` devuelve 0 instrucciones, se marca OMIT y se verifica en el editor);
`poc2_prueba_headless.txt`. Sale con 1 si algo falla (se comprobó en el primer intento, con los 3 «compila» en fallo).

Rendimiento: diez muros a la vez **106-116 fps** (tick de Slate, editor; `diez_muros.png` con `stat fps`/`stat unit`:
105 fps, 9,5 ms de juego, 3,7 ms de GPU). El «Input 1542 ms» de la captura es el editor sin foco, no el efecto.

## 6. Contenido ajeno

Aspecto **0 % de Epic**: ruido procedimental del nodo Noise del motor, degradado radial a mano, materiales e instancias
propios, sin texturas (la `T_RuidoToon` generada en la técnica 1 queda en la carpeta sin uso). Del motor solo la
plantilla Third Person (personaje, nivel) y los módulos estándar de Niagara. Fab: no se ha usado (sin inicio de sesión).

## 7. Huecos de la API de Python (comprobados, por si Pablo lo hace a mano en el editor)

- `MaterialFunctionCall` con `RadialGradientExponential`: desde Python el nodo no expone sus salidas (no se puede conectar
  `Result`), por eso el degradado se construye con `Distance`, `Divide`, `OneMinus`, `Saturate`, `Power`.
- `DynamicParameter`: solo la salida 0 se conecta por nombre; las otras tres no resuelven. Por eso `Densidad` va por
  parámetro dinámico y los desfases de paneo por `ParticleRandom`.
- La entrada `Position` del nodo Noise no resuelve por nombre: hay que conectar a `""` (primera entrada).
- `Vector4f` no admite argumentos en el constructor: `set_editor_properties({"x":…})`.
- `NiagaraSystem.emitter_handles` y `export_text` no están expuestos: la cuenta de luces se hace con `ObjectIterator`.
- `delete_all_material_expressions` no vacía el grafo: hay que borrar nodo a nodo (ya visto en la técnica 1).

## 8. Qué puede hacer Pablo en el editor (sin que nada esté a medias)

Abrir `MI_FuegoToon_Lengua` y mover `Banda` (altura de la crema), `BandaBorde`, `EstiradoV`, `EscalaRuido` y
`AmplitudRuido`; en `NS_MuroFuegoToon`, los tamaños de sprite de `Lenguas`. Para regenerar todo: dejar en `Saved/cola_py`
un `.py` de una línea que ejecute `Scripts/poc2_material_cghow.py`, luego `poc2_niagara_cghow.py`, `poc2_bp.py` y
`poc2_capturas.py` (ver los `.hecho` de la cola).
