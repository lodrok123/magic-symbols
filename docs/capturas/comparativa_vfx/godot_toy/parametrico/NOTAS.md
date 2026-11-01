# Fuego «toy» paramétrico (`FuegoToy`), 1/11/2026

Rama `claude/fuego-toy-parametrico` (worktree `E:\tmp\wt_fuego_param`, sin push). Idea de Pablo: «una vez modifiquemos los ejes X, Y y Z los hechizos geométricamente salgan solos». Un solo efecto: `presentacion/vfx/toy/FuegoToy.tscn` (solo la raíz con el script, para tocar ejes y figura en el inspector) y `fuego_toy.gd` (`class_name FuegoToy`, extiende `EfectoToy`); también se crea con `FuegoToy.new()`. Toda la geometría sale por código. Mallas en `fuego_toy_mallas.gd`. Las cinco escenas validadas no se tocan; de `efecto_toy.gd` solo se sacó `_recoger()` (la parte de `_ready` que recoge materiales, partículas y luz, para repetirla al reconstruir) y `_avance_cabeza` (el −0,12 m de la cabeza en vuelo, que ahora se escala con la bola). Con eso la prueba antigua sigue a 0 fallos.

**Lámina:** `LAMINA_ejes_propiedades.png` (3934 × 3170) y `LAMINA_ejes_propiedades_reducida.png` (2400 px). Se rehace con `captura_fuego_parametrico.gd -- <carpeta> celdas` y `lamina_vfx.py`.

## 1. Qué depende del tamaño en cada escena validada (medido en los `.tscn` y en `montar_efectos_lelu.gd`)

Ojo: `BolaFuegoToy.tscn` se retocó a mano después de `montar_efectos_lelu.gd` (rampa menos amarilla, destello naranja, cabeza…); la fuente de verdad son los `.tscn`, no el montador.

| Efecto | Qué fija el tamaño | Cómo se construye |
|---|---|---|
| Bola | `radio` 0,52 y `tam` 2,4 del shader `fuego_lelu_bola` (quad 2,4 m), `repeticion` (0,8; 0,65) y `rep_ruido` (0,7; 0,5) **por metro**, `desplaza` 0,1, cabeza quad 1 con `radio` 0,22, destello 0,8, estrella 1,05, halo 2,0, partículas (cajas, tamaños, velocidades), cabeza en vuelo −0,12 m | Quads billboard; se queda en el `.tscn`. `tam_referencia` 0,8 |
| Muro | Malla `Banda`: superelipse de a 3,45 × b 0,3 (exponente 6), 1,5 m de alto, escala arriba 0,78, 120 segmentos, 14 anillos; `Interior` (3,3 × 0,12, 1,05 m, 0,7). `repeticion` (5; 0,9) y `rep_ruido` (6; 1,6) (interior 6; 0,9 y 7; 1,6). Charco 7,6 × 2,4, resplandor 7,2 × 2,2, cajas de partículas, luz 1,6 / 6,5 | Mallas **embebidas** en el `.tscn` (generadas por `_malla_lazo`) |
| Pilar | `Exterior` cilindro 0,5 → 0,36 × 4 m, `Nucleo` 0,3 → 0,16 × 3,1 m, 32 segmentos; `repeticion` (1; 1,6) / (1; 1,4), `rep_ruido` (2; 2); `amplitud_vert` 0,2 / 0,12; charco 2,6, resplandor 3,4 × 4,2 | Mallas embebidas (`_cilindro`) |
| Barrera | Esfera r 1,5 (25 anillos × 48), a +0,6 m del suelo (0,4 R), `v_base` 0,3, `repeticion` (3; 1,4), `rep_ruido` (5; 2), `amplitud_vert` 0,1, anillo de suelo 3,9 | Malla embebida (`_malla` con `esfera=true`), dos pasadas (`fuego_lelu_atras` + `fuego_lelu_delante`) |

**Medida clave** (la estimación de la tarea, 0,5–0,7 m por repetición, no sale): el muro validado usa **5 repeticiones sobre 14,5 m de contorno = 2,90 m por repetición** de la textura de lenguas (una cada 2,9 m, ~2,4 por cada lado largo); pilar 3,14 m, barrera 3,14 m. En vertical: 1,67 m (muro), 2,5 m (pilar), 3,37 m (barrera). Con 12 repeticiones por contorno, probadas en la ronda 4, salía «hierba fina». `FuegoToyMallas.M_*` guarda los metros por repetición de cada textura y capa; `repeticiones_u` los pasa a un entero ≥ 1 (la costura de U tiene que cerrar).

## 2. Cómo se construye `FuegoToy`

- Exports: `figura` (BOLA, MURO, PILAR, BARRERA), `semieje_x/y/z` (m), `viaja`, más los diez mandos heredados. Los setters piden `reconstruir()` (diferido, una sola vez); `definir(fig, x, y, z, viaja)` lo pone todo de golpe. Al reconstruir se conservan los mandos, la luz y el AnimationPlayer (solo cambia si cambia de figura, para los tiempos de nacer/morir de cada una).
- **BOLA**: radio = máx(x, z), `k = r / 0,4`. Quad `2,4k`, `radio 0,52k`, `repeticion` y `rep_ruido` ÷ k (la bola es la validada ampliada o reducida entera); `y` ≠ radio: escala Y del nodo `Llama` = y/r (el quad, el gradiente y la textura se estiran en Y, como pedía la tarea). `viaja`: cola, jirones, estelas de chispas y destello de 4 puntas con las medidas × k (el eje de la llama sigue a la velocidad; no se aplica la escala Y en vuelo).
- **MURO**: banda superelipse a = x, b = z, alto y; U medida por la longitud del contorno, repeticiones enteras = contorno / 2,90 m (`rep_ruido`: / 2,42 m); interior a·0,957, b·0,4, 0,7 y. V = alto / 1,667 m.
- **PILAR**: cilindro abierto, sección elíptica (x, z) con U por la longitud real de la elipse (Ramanujan), ahusado 0,72 como el validado; núcleo ×0,6 y 0,775 de alto.
- **BARRERA**: elipsoide x, y, z (normales del elipsoide), centro a 0,4·y, dos pasadas; repeticiones por el perímetro del ecuador y la longitud del meridiano.
- Luz: energía × clamp(E / E_ref, 0,4–1,6), alcance × clamp(…, 0,4–2); partículas: cantidad con raíz del área (muro con el largo) entre topes; cajas de emisión con la figura. **Presupuesto**: 1 luz y de 6 a 69 partículas en los extremos probados (bola 3 m en vuelo 41, barrera 6,9 × 4,6 × 6,9 69, muro 8 × 4,6 × 3 39).
- `describir(h)` / `desde_hechizo(h)`: semiejes de `Hechizo` en casillas × `casilla` (2,3; como `VfxElemento3D`); si el hechizo viaja o tiene velocidad se usan los semiejes en vuelo (× `ESCALA_PROYECTIL`). Regla: haz → BOLA (nota); viaja → BOLA en vuelo; `solidez` > 0 → MURO si el largo en planta ≥ 2 × el fondo, si no BARRERA (cúpula); si no, `nombre_derivado` «alto» → PILAR, alargado en planta → MURO (girado 90° si lo largo es z), lo demás → BOLA. `preparar(volumen, dir)` rehace la geometría con el volumen (no escala el nodo).

## 3. Lo que NO encaja o no sale igual (sin adornar)

- **Haz** (ᛁ `linea`): no hay figura lineal; sale como BOLA y `describir` lo anota («haz: sin figura propia»). La familia LINEAL del plan sigue sin hacerse.
- **Zona plana redonda** (nombre derivado «abajo», sin barrera, no alargada): se dibuja como bola aplanada; no hay figura de «zona en el suelo».
- **Bola con x ≠ z**: es un billboard; solo cuenta máx(x, z). El alto sí se estira (y).
- **Bola en vuelo**: ignora y (la llama sigue la velocidad); en la lámina la cola se ve corta y la celda es pequeña (la bola avanza 6 m en 0,8 s y la cámara abre mucho).
- **Barrera pequeña** (0,5) casi no tiene lenguas (una repetición mínima sobre 3 m de contorno) y se lee como una cúpula translúcida con un anillo; la **barrera grande** (3 m) enseña mejor la cara de atrás y es más hueca. **Pilar grande** (1,2·4,6·1,2): las lenguas se acaban a la mitad de la altura (el gradiente vertical es relativo a V, y con 1,8 repeticiones verticales el pilar se ve a rayas).
- Muros largos (6 m): las lenguas **no se estiran** (3,1 m de contorno por repetición frente a 2,9 en el validado), pero con la cámara que cabe el muro entero salen pequeñas en la lámina.
- En la lámina el cubo de 1 m y la cámara se encuadran por celda (misma dirección y FOV, distinta distancia); no es la misma distancia en todas porque un muro de 12 m y una bola de 0,3 m no caben a la vez.
- La prueba de aspecto (cómo se ve en el juego, con su entorno) no se hizo; solo en el lab.

## 4. Tonos (rojo-naranja / naranja / amarillo; objetivo 15–30 / 50–65 / ≤ 20)

Cámara «cerca» del lab, mismo montaje, **media de 6 fotos separadas 0,41 s** (una sola foto engaña: el fuego depende del tiempo; con una foto la bola salió 14/51/35 frente a 20/62/19 por pura fase). `herramientas/medir_tonos_promedio.py`:

| Figura | `FuegoToy` (prueba 3) | Escena validada, misma sesión | Validado en NOTAS de la ronda (1 foto) |
|---|---|---|---|
| Muro | 23 / 60 / 17 | 23 / 61 / 16 | 17 / 60 / 23 |
| Pilar | 28 / 58 / 14 | 27 / 59 / 14 | 26 / 57 / 17 |
| Bola | 20 / 51 / 30 | 20 / 53 / 28 | 16 / 69 / 14 |
| Barrera | 40 / 52 / 8 | 40 / 50 / 10 | 38 / 48 / 14 |

`FuegoToy` y la escena validada coinciden dentro de ±2 puntos en las cuatro. Frente a los números de las rondas (que eran una sola foto, y el panel de texto del lab cuenta distinto ahora) los pasa en la misma banda salvo la bola (amarillo 28–30 en los dos: sale del halo de la cabeza y del panel, no de `FuegoToy`).

## 5. Geometría comprobada con la prueba sin ventana

Mallas = semiejes (AABB ≈ 2x, y, 2z) en 10 tamaños; con el tamaño de la prueba 3 las mallas son las validadas (≤ 2 %) y las repeticiones de textura son idénticas (5; 0,9 … 3; 1,4); muro de 3 m: 2 repeticiones (3,4 m/rep), de 12 m: 8 (3,1 m/rep).

## 6. Laboratorio (`LabVfxComparativa3D`)

F7 crea el `FuegoToy` con la figura y el tamaño de la prueba 3 (otra pulsación: siguiente figura bola → muro → pilar → barrera) · U/J x ± · I/K y ± · O/L z ± (×1,2) · V bola en vuelo (bucle) · F8 vuelve al tamaño de la prueba 3 · F9 prueba `desde_hechizo` con seis hechizos de ejemplo (bola, muro, pilar, barrera, flecha, barrera alargada) · los diez mandos (RePág, AvPág, +, −) valen también. El panel enseña figura y ejes.

## 7. Horas (reloj del PC, 1/11)

| Paso | Tiempo |
|---|---|
| Leer `efecto_toy`, escenas, shaders, montadores, `Hechizo`, el plan | hasta 21:26 |
| `FuegoToyMallas` + `FuegoToy` + humo | 21:26 – 21:40 |
| Lab (F7–F9, U/J…) y 37 aserciones nuevas | 21:40 – 21:46 |
| Captura, lámina, medida de tonos (incl. la repetición con 6 fotos) | 21:46 – 21:54 |
