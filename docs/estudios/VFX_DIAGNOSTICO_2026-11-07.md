# VFX · lo que ya hay y lo que falta de la direccion de Genshin

Medicion del 7/11/2026 sobre `presentacion/vfx/`, antes de tocar nada.
Continua [GENSHIN_DIRECCION_ARTE_2026-11-07.md](GENSHIN_DIRECCION_ARTE_2026-11-07.md) §6 y §8.

**Conclusion por delante: la prioridad 5 de aquel documento —"colapsar los ~85 shaders de VFX en un
uber shader"— estaba equivocada y hay que retirarla.** Ese trabajo ya esta hecho, por elemento, y un
uber shader seria un retroceso. Lo que si falta es otra cosa, mas pequeña y mas visible.

---

## 1. Lo que ya hay (medido)

| | |
|---|---|
| Shaders `.gdshader` en `presentacion/vfx` | **71** |
| Lineas de codigo (sin vacias ni comentarios) | **2.777** — **39 por shader de media** |
| Ficheros `.gdshaderinc` (codigo compartido) | **9** |
| Funciones auxiliares definidas en 3+ shaders | **2** (`tri`, `hash1`) |

Los 9 includes, uno por familia: `agua_toy`, `barrera_toy`, `fuego_barrera`, `fuego_lelu`, `hielo_toy`,
`lelu_sprite`, `particula_toy`, `rayo_toy`, `rayo_trazo`. Es decir: **el colapso ya se hizo, elemento a
elemento.** `agua_toy.gdshaderinc` lo incluyen 13 shaders.

**La paleta ya esta centralizada.** `vfx_kit_3d.gd` tiene `rampa_de(nombre)`, que construye y cachea un
`GradientTexture1D` por elemento desde un gradiente declarado. Eso es el equivalente de VFX al
`_DeferredToonRampTex` de Genshin, y esta bien resuelto.

**El vocabulario de uniforms es consistente**, cosa rara y que habla de disciplina:

```
brillo 25 · semilla 24 · opacidad 14 · rampa 14 · vida 13 · tono 10 · velocidad 10
ondulacion 9 · erosion 8 · umbral 8 · crece 7 · chisporroteo 7 · grosor 7
```

El 36,8 % de las lineas se repiten, pero mirando **que** se repite son `shader_type spatial;` (71x),
`void fragment() {` (59x), `render_mode ...` (21x) y declaraciones de uniform. Es andamiaje, no logica.

**Por eso el uber shader no procede.** 71 shaders de 39 lineas son legibles y baratos de cambiar; un
unico shader de ~1.000 lineas con 30 ramas seria peor de leer, peor de tocar y, en Godot, o ramifica en
tiempo de ejecucion o explota en variantes. Genshin puede permitirselo porque sus artistas no escriben
shaders: rellenan mascaras en una herramienta. Aqui se escriben shaders.

## 2. El duplicado real (medido, y es poco)

| primitiva | copias | veredicto |
|---|---|---|
| Billboard (`MODELVIEW_MATRIX = VIEW_MATRIX * mat4(...esc...)`) | **9** | a compartir |
| Fundido por profundidad (`agua_prof`, `hielo_prof`) | **2** | a compartir |

`agua_prof` y `hielo_prof` son **identicas hasta el comentario**, solo cambia el prefijo del nombre. La
cabecera de `hielo_toy.gdshaderinc` ya lo dice: «igual que el agua y el fuego».

**Lo que NO hay que juntar:** `agua_tonos` y `hielo_tonos` suenan a lo mismo y no lo son. El agua hace
escalones entre hondo y somero con espuma por encima de un umbral; el hielo hace facetas con `floor` y
remata en escarcha. Son dos lecturas distintas **a proposito**, y son parte de la identidad de cada
elemento. Juntarlas haria el hielo mas acuoso, que es justo lo contrario de lo que se busca.

## 3. Lo que falta de verdad: la erosion

De los 56 shaders que escriben `ALPHA`, **45 se desvanecen bajando el alfa** y solo **11** se comen por
ruido o erosion.

```
agua_cinta  agua_esfera  agua_espuma  agua_franja  agua_gota  agua_haz  agua_lamina  agua_mancha
agua_ola  agua_onda  agua_pilar  aro_barrera  barrera_toy  briznas_toy  cabeza_toy  calor
chispa_impacto  explosion_suelo  fuego_barrera  fuego_lelu_bola  grietas_magma  halo_toy  haz_toy
hielo_cristal  hielo_destello  hielo_escarcha  llama_toy  naturaleza_blob  naturaleza_esfera
nube_veneno_suelo  particula_toy  rayo_bola  rayo_sello  rayo_trazo_cuerpo  tierra_anillo  ... (45)
```

Esta es **la firma visual de Genshin** y es la que falta: `_ErodeNoise` / `_ErodeNoisePow` /
`_ErodeNoiseTill`. Alli **nada se desvanece bajando alfa; todo se come por ruido.** Un alfa que baja
lee como «se apaga el monitor»; un alfa comido por ruido lee como que la cosa se consume. Es una linea
de shader y cambia el caracter de todos los efectos a la vez.

Lo mismo con el **fundido por profundidad**: el que hay (`agua_prof`) es limpio, un degradado recto.
Genshin lo hace con ruido (`_EnableDepthBlendNoise`, `_DepthBlendNoiseTex`), y por eso el humo «entra»
en el suelo en vez de posarse encima con un filo.

El **glow** ya esta centralizado en `vfx_kit_3d.gd` (`glow_enabled`, `glow_intensity`), asi que la
guerra de «mi efecto no se ve, le subo la emision» esta contenida.

## 4. Que hacer

1. **Retirar la prioridad 5 del documento anterior.** No hay uber shader.
2. **`nucleo_toy.gdshaderinc`**: el billboard (9 copias) y el fundido por profundidad (2 copias). Es el
   vehiculo, no el premio; no cambia un pixel.
3. **`erosion_alfa()` en ese nucleo**, y aplicarla donde los efectos mueren. **Este es el premio.**
4. **Ruido en el fundido por profundidad**, una vez el nucleo exista.

**Como se prueba, y esta vez con la leccion aprendida de la rampa del decorado:** NO aplicarlo a los 45
de golpe. Primero a cuatro efectos representativos (uno de agua, uno de fuego, uno de hielo, uno de
rayo), captura, y decidir mirando. Si convence, se extiende; si no, se revierte un archivo en vez de
cuarenta y cinco.

---

## 5. Resultado de la prueba en cuatro efectos (7/11, tres rondas)

**La erosion funciona y se queda.** Sin ella las cuatro bolas se volvian transparentes y se lavaban
contra el fondo; con ella se consumen, y cada elemento se consume A SU MANERA sin perder identidad:

| elemento | como se come | estado |
|---|---|---|
| agua | manchas grandes, conserva una cascara: burbuja que revienta | bien a la primera |
| fuego | se deshace en chispas sueltas | bien a la primera |
| hielo | se desconcha en trozos angulosos | bien a la tercera |
| rayo | el nucleo se rompe en islas y el filo azul se fragmenta alrededor | bien a la tercera |

Lo que costo tres rondas, y conviene recordarlo porque son trampas que se repiten:

1. **Ruido sobre UV en malla no esferica** → el cristal de hielo salio con rayas verticales espejadas
   (UV cilindrico). Se arregla muestreando en espacio de objeto.
2. **Ruido en espacio local con nodo escalado** → el mismo cristal, escalado x1,7 en Y, salio en gotas
   alargadas. Se arregla multiplicando la posicion local por la escala del `MODEL_MATRIX` y
   normalizando por la raiz cubica del volumen, para que el grano sea isotropo EN EL MUNDO y conserve
   el tamaño medio.
3. **Subir el brillo del filo MULTIPLICANDO** (`albedo * (1 + k)`) sobre un color ya saturado → el
   naranja del fuego se fue a lima: el rojo se clava en 1 y el verde sigue subiendo. Se arregla
   **sumando** hacia un color de filo (`albedo + color_filo * k * borde`), que conserva el tono.
4. **Empezar a erosionar desde el primer instante** hace que el efecto nunca parezca entero. Con
   `avance = smoothstep(ero_inicio, 1.0, 1.0 - vida)` aguanta la silueta y se consume despues.

Parametros por shader: `ero_escala`, `ero_dureza`, `ero_ancho`, `ero_brillo`, `ero_inicio`.
Interruptor global `VfxKit3D.usar_erosion`; apagado, la imagen es identica bit a bit a la de antes.

**Garantias que se cumplen:** con `vida = 1` el alfa sale igual que entraba y con `vida = 0` sale 0,
monotona entre medias. La erosion cambia COMO mueren los efectos, nunca CUANDO.

### Lo que falta decidir

Extender a los 41 restantes **no es automatico**: no todos son efectos que mueren. Los de suelo y
estado (`decal_suelo`, `grietas_magma`, `hielo_escarcha`, `nube_veneno_suelo`, `tierra_grietas`) y las
barreras (`barrera_toy`, `aro_barrera`) piden pensarse aparte. El lote natural siguiente son los que
mas se ven morir: la familia del agua (14 shaders) y los impactos (`chispa_impacto`, `halo_impacto`,
`cabeza_impacto`, `halo_toy`).

Y antes de ningun lote conviene **verlo en movimiento**: una rejilla de fotogramas fijos no dice si
el efecto lee a la velocidad real del juego.

---

## 6. En movimiento (8/11): el cuello de botella no son los shaders

Tira a tiempo real, con los milisegundos rotulados (`herramientas/captura_vfx_erosion_tira.gd`).
Duraciones REALES de la muerte de cada bola, medidas, no supuestas:

| camino | dura | erosion visible |
|---|---|---|
| choque (`impactar_en`) | **125 ms** (agua, fuego, hielo) · **37,5 ms** (rayo) | solo ~60 ms, tras el arranque tardio |
| fin sin choque (`terminar_sin_choque`) | **500 ms** (rayo 350) | **ninguna** |

Lo que se ve, juzgado sobre `tira_erosion_aislada_0/1.png`:

- **Hielo: la mejor con diferencia.** A 50 ms ya se rompe en grano y a 63-75 ms es una nube de polvo.
  Lee a cristal que estalla.
- **Agua: gana de verdad.** Desde 50 ms se agujerea y a 63-75 ms queda una cascara de encaje.
- **Fuego: no se nota.** En la rejilla estatica era el mejor; en el juego el toy es un COMPUESTO
  (penacho naranja + destello blanco + chispas) y el quad que se erosiona es una parte pequeña. La
  rejilla juzgaba el shader; la tira juzga el efecto, y el efecto lo tapa el destello.
- **Rayo: cero.** `RayoToy` anima `corte`, no `aparicion`, asi que `vida` se queda en 1 y las dos
  tiras son identicas. Y con 37,5 ms (2 fotogramas a 60 fps) no habria sitio aunque se conectara.

**El hallazgo estructural.** `terminar_sin_choque` solo rampa `_c_escala` (verificado en
`agua_toy.gd` L480 y `rayo_toy.gd` L467): la bola se encoge, y `vida` no se mueve. O sea que **el
camino que tiene tiempo de sobra (500 ms) es el que NO tiene erosion, y el que la tiene vive 125 ms.**
Esta del reves.

### Que hacer, y que NO

**No extender a los 14 shaders del agua todavia.** El limite no es cuantos shaders llevan erosion,
es que los caminos de muerte apenas la usan. Añadir erosion a trece shaders mas que tambien mueren en
125 ms no compra nada.

1. **Conectar `vida` a la rampa de APAGANDO** para que `terminar_sin_choque` se coma la bola en sus
   500 ms. El embudo existe: `efecto_toy.gd` L217 (`_param_mats("vida", v)`).
2. **Quitar la erosion del rayo.** 37,5 ms no va a leerse nunca.
3. **Dejar la del fuego pero no invertir mas ahi:** el compuesto la tapa.
4. Repetir la tira del modo `fin` y volver a juzgar.

### Incidencia aparte
`agua_mallas.gd` crea un `RandomNumberGenerator` sin semilla para las cintas de la bola, asi que
**ninguna captura del agua es reproducible**: dos pasadas identicas difieren solo en esa fila. Afecta
a cualquier comparacion antes/despues que incluya agua.

---

## 7. Resultado del fin sin choque (8/11): ahi si paga

Con `vida` conectada a la rampa de apagado (500 ms), sobre `tira_erosion_fin_1.png`:

- **Agua: muy bien.** Desde ~150 ms se pica, hacia 250-300 ms se rompe en gotas que caen, y de 350 a
  500 ms queda una dispersion de gotas sueltas. La bola se DESHACE en agua, que es exactamente lo que
  tenia que pasar. Es mucho mejor que en el choque.
- **Hielo: muy bien.** Desde 250 ms se fractura y entre 300 y 450 ms estalla en esquirlas que se
  dispersan. Lee a cristal que se rompe.
- **Fuego: modesto.** Algo de erosion en el cuerpo naranja hacia 250-350 ms, pero el resplandor manda.
  Confirmado: no merece mas inversion.
- **Rayo: sin erosion**, retirada a proposito (37,5 ms en el choque, y anima `corte`, no `aparicion`).

**Conclusion: la decision correcta era la rampa de muerte, no el numero de shaders.** Con 125 ms la
erosion era un chasquido; con 500 ms se lee y aporta. El trabajo de shaders ya estaba; lo que faltaba
era darle tiempo.

Implementacion: `EfectoToy._vida_erosion(v)` empuja `vida` SOLO a los materiales que declaran
`ero_inicio`, sin tocar `aparicion`, los halos ni la escala del cuerpo (por eso no hay doble
encogido), y no hace nada con `VfxKit3D.usar_erosion` apagado. Los tres toys la llaman en APAGANDO
con la misma rampa que el encogido.

### Estado de las pruebas (106 pasadas, con el comando de cada cabecera)

75 con 0 fallos. Los fallos se comprobaron contra HEAD en un `git worktree` aparte:

- **Ya fallaban en HEAD**, mismo conteo: `campos_ejecutados`, `catalogo_reacciones`, `contacto_fuego`,
  `destello_elemento`, `en_punto_proyectil`, `hechizo_golden`, `hielo_toy`, `muerte_elemento`,
  `papeles`, `trampas_pared`, `vfx_toon`, `reaccion_enemigos`.
- **Pasan en HEAD y fallan en el arbol de trabajo**, todas de tierra / solidez / muro: `canouro_v2`,
  `ejecucion_combinaciones`, `haz`, `hechizo_vivo`, `materia_v2`, `vfx_en_juego`, `lab_vfx_toys`.

Esas siete **no son de este trabajo**. El arbol lleva WIP sin commitear de otro frente que toca justo
eso: `magia/hechizo_vivo.gd`, `magia/lanzador_3d.gd`, `nucleo/hechizo.gd`, `mundo/pieza_3d.gd`,
`objetos/objetos_3d.gd` y `presentacion/vfx/toy/tierra_toy.gd`, ninguno tocado aqui. Es evidencia
fuerte, no una biseccion: no se ha aislado cual de esos cambios las rompe.

### Pendiente
`agua_mallas.gd` crea un `RandomNumberGenerator` sin semilla, asi que las capturas de agua (y, se vio
despues, tambien las de hielo y rayo) no son reproducibles entre pasadas. Impide comparar por pixel
cualquier antes/despues que las incluya.

---

## 8. Erosion en la familia del agua (8/11): cuatro quedan fuera por razones de fondo, tres llevan erosion

Regla aplicada: la erosion solo se ve si el efecto tarda en morir Y su muerte mueve algo que gobierne el ruido. Para cada shader se siguio el codigo que lo mata.

| shader | como muere | dura | erosion |
|---|---|---|---|
| agua_cinta | bola: `terminar_sin_choque` rampa `vida` (APAGANDO); choque: `morir` x4; carga: `opacidad` | 500 ms fin / 125 ms choque / 120-150 ms carga | SI (vida de la bola). El choque sigue siendo un chasquido, como la esfera. La carga no cambia (`vida` = 1) |
| agua_esfera_atras (no estaba en la lista; comparte bola con la esfera) | igual que la esfera | 500 ms | SI, mismo ruido que la cara delantera. A/B en `agua_fin_1.png` vs `agua_fin_1_sin_atras.png`: sin ella queda una cascara oscura entera bajo los huecos; con ella se rompe todo junto. Quitar `#define AGUA_CON_EROSION` del shader la deja como antes |
| agua_haz, agua_haz_cinta | `morir` anima `corte` (haz suelto que se rompe en islas); `vida` = 1 | 1000 ms | NO. Probado y retirado: el chorro ya se rompe por ruido propio y se va del encuadre antes de la ventana de alfa (700-1000 ms) |
| agua_pilar | `corte` colapsa la altura (~corte^2) y deja el charco | 1200 ms | NO. Probado y retirado: a 570 ms ya no hay columna; la ventana de alfa (600-900 ms) cae sobre nada |
| agua_ola, agua_ola_lamina | `corte` hace caer la ola (altura al 12 %) y deja el charco | 1900 ms | NO. Probado y retirado: a 1000 ms ya es un charco con espuma; el cuerpo no esta cuando entra la ventana |
| agua_lamina | `caida` por lengua (pilar corona; explosion de area) | ~350 ms de ventana | NO. Probado en la explosion de area: on y off no se distinguen (la lengua ya esta al 40 % de altura) |
| agua_espuma, agua_franja | opacidad por instancia puesta desde la CPU; `vida` = 1 | 0,5-0,8 s | NO. No hay `vida` que gobernar y son manchas pequenas y ya difusas. No probado |
| agua_mancha | `u` (edad de la salpicadura); `vida` = 1 | 0,8 s | NO. Mancha de pared al 34 % de opacidad: nada que comer. No probado |
| agua_onda | `u`; ademas `vida` es GANANCIA (0,55 en la carga): erosionar por `vida` romperia la carga | 0,4-0,9 s | NO. Anillos finos y charcos de estado |
| agua_gota | alfa por instancia (`datos.g`); no incluye agua_toy.gdshaderinc ni tiene `vida` | 0,3-1,5 s | NO. Gotas de 5-14 cm |

Codigo: los uniforms `ero_*` y las funciones (`agua_ero_av`, `agua_fade`, `agua_ero_alfa`, `agua_ero_tinte`) viven UNA vez en `agua_toy.gdshaderinc`, activadas con `#define AGUA_CON_EROSION` (y `AGUA_ERO_ESCALA` para el tiling). Cada shader añade ~3 lineas. `agua_esfera` paso a usarlas (antes llevaba su copia). Garantias: avance 0 = alfa intacto, 1 = 0, interruptor global apagado = identico; comprobado pixel a pixel contra HEAD con `herramientas/prueba_agua_erosion_apagada.gd` (esfera, esfera_atras y cinta: md5 igual con la erosion apagada y con ella encendida y `vida` = 1).

Herramienta: `herramientas/captura_vfx_erosion_agua.gd` (modos fin, haz, pilar, ola, choque, area), ms rotulados. Salidas en `docs/capturas/vfx_erosion/agua_*_{0,1}.png`. Los encuadres de haz/pilar/ola/area son mejorables; la decision de retirarlas se apoya tambien en el codigo (la geometria acaba antes que la ventana de alfa).
