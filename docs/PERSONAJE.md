# Cambiar el personaje principal

> **HISTÓRICO (4/10/2026).** Describe el animador antiguo (`ActorAnimator`, la maga de 64×64 sacada de vídeo). El personaje de ahora sale del pipeline: contrato en `export_godot/CONTRATO_GODOT.md`, lectura en `MsAtlas`/`MsActor`.

Cómo se consigue que ocho direcciones y cinco animaciones parezcan **la
misma persona**, y cómo se pasa de un vídeo generado a una hoja que el
juego lee.

El contrato de las hojas está en [ANIMACION.md](ANIMACION.md). Esto es lo
otro: de dónde sale el arte.

---

## Lo primero: mira el tamaño real

**La figura mide 75 px de alto en pantalla.** A ese tamaño no sobrevive
la cara, ni el bordado, ni las hebillas del cinturón. Lo único que
distingue a un personaje de otro es:

1. **La silueta** — el ancho de la falda, el sombrero, la capa
2. **La paleta** — dos o tres colores que se reconozcan de un vistazo
3. **Una marca** — la bufanda roja, y poco más

Ahí es donde hay que gastar el esfuerzo. Una cara distinta entre dos
direcciones no se ve; una falda más ancha, sí.

> **Regla para revisar: juzga siempre a 1:1.** A 1440 px vas a rechazar
> cosas que en el juego son idénticas, y a dar por buenas diferencias de
> silueta que allí cantan.

## El problema de verdad es la aritmética

8 direcciones × 5 clips = **40 generaciones**. Aunque cada una salga bien
nueve de cada diez veces, no salen 40 seguidas del mismo personaje. Ése
es el motivo por el que un personaje generado se va desviando, y no la
falta de maña con los prompts.

Todo lo que sigue va dirigido a bajar ese número.

### Espejo: tres direcciones salen gratis

```
E  <-> O        SE <-> SO       NE <-> NO       S y N no tienen pareja
```

Sólo hay que generar **cinco**: E, SE, S, N, NE. Las otras tres se
voltean. Además de ahorrar, **garantiza** que izquierda y derecha sean
idénticas, que es donde más canta una desviación.

De 40 generaciones a 25.

El precio: los detalles asimétricos se cambian de lado (la bufanda pasa
de un hombro al otro). A 75 px no se nota, y es lo que hacían los
clásicos.

> Al voltear hay que voltear **cada celda sobre sí misma**, no la tira
> entera: volteando la tira se invierte además el orden de los
> fotogramas y el personaje anda hacia atrás.

---

## Las tres maneras de conseguir el arte

### 1. Imagen ancla + image-to-video

Es lo que hay montado hoy. La clave es que la identidad viva en **una
imagen**, no en el prompt: cada vídeo se genera *desde* esa imagen, nunca
desde texto. Siguen siendo 25 tiradas, pero todas parten del mismo sitio.

Lo más rápido para seguir avanzando.

### 2. Modelo 3D low-poly y render ortográfico

Consistencia **por construcción**: un modelo, ocho cámaras, y cualquier
animación futura sale gratis y ya encajada. Es lo que ANIMACION.md ya
contempla ("renderizado desde un modelo 3D").

Cuesta aprender Blender y cambia el acabado, pero a 75 px un render
low-poly y una ilustración pintada se parecen más de lo que parece.

Si el personaje es definitivo, es ésta.

### 3. Una pose por dirección, animada por deformación

Ocho dibujos en total, y el movimiento con huesos (`Skeleton2D` +
`Polygon2D`, que Godot ya trae). Cero desviación, porque no hay
generación que se desvíe. A este tamaño el movimiento se lee
perfectamente. Es la que más se subestima.

---

## Los pasos

### 1. Congela UNA imagen canónica

La ilustración de cuerpo entero, de frente, que te guste. Guárdala en
`docs/`. Es la biblia: todo lo demás sale de ahí. **Este paso lo decide
todo**; si la imagen ancla no está fijada, lo demás no sirve.

### 2. Genera una lámina de giro

Las cinco vistas (E, SE, S, N, NE) **en una sola imagen**. Una
generación → las cinco comparten identidad por construcción, que es
justo lo que no se consigue generándolas por separado.

### 3. Recorta cada vista y úsala como primer fotograma

Image-to-video partiendo de ese recorte, una vez por dirección.

### 4. Pasa cada vídeo por la herramienta

```
python tools/video_a_fila.py Hero_walking_E.mp4 \
    --salida fila_E.png --gif E.gif --marca 1130,1340,1440,1430
```

Y voltea las tres que faltan.

### 5. Orden de producción

`idle` de frente (fila 2) primero: es la que más se ve y la referencia de
las demás. Luego `walk`, y al final `cast` / `hurt` / `death`.

---

## Qué pedirle al generador

Tres cosas que muerden si no se fijan desde el principio:

| | |
|---|---|
| **Cámara** | a unos **28° sobre el horizonte** |
| **Luz** | plana y neutra, **sin sombra en el suelo** |
| **Encuadre** | cuerpo entero con margen, fondo liso, sin desenfoque |

**Los 28° no son un gusto.** La losa del juego mide 116 × 55 px, y
`asin(55/116) = 28°`. Si el personaje viene dibujado a la altura de los
ojos, no pisa el suelo del mundo — se ve como si flotara, aunque los
píxeles de los pies estén donde tienen que estar.

**La sombra, la pone el juego.** `CanvasModulate` y los `PointLight2D`
del farol ya iluminan la escena; una sombra quemada en el sprite pelea
con ellos y se nota cuando el personaje pasa al lado de una luz.

**El margen** hace falta porque el recorte necesita que la figura no
toque los bordes: si los toca, el trozo conectado se sale de la imagen y
la silueta sale partida.

---

## Los cuatro problemas de un vídeo generado

Esto es lo que resuelve `tools/video_a_fila.py`, y conviene saberlo
porque son los mismos cuatro siempre:

**1. Fondo.** Viene sobre un color plano, no con alfa. Se quita por
distancia de color, con dos cuidados: quedarse con el **trozo conectado
más grande** (así la firma de la IA se cae sola) y **rellenar los
agujeros** después (las botas y el pelo oscuros se parecen al fondo y si
no se abren como huecos dentro de la figura).

**2. Zoom.** El personaje se aleja de la cámara mientras anda — en los
vídeos medidos, hasta un 16%. Por eso **cada fotograma se escala por su
propio alto**, no todos por el mismo factor. Con una escala común, el
sprite encogería solo al andar.

**3. Deriva.** No anda en el sitio: los pies se mueven hasta 142 px. Se
ancla **por los pies**, no por la caja. En isométrico todo se ordena por
dónde se pisa; anclando por la caja, el personaje da saltitos verticales
cada vez que levanta un brazo.

**4. Bucle.** El clip **no cierra**: el último fotograma no enlaza con el
primero. En vez de repartir 12 fotogramas por todo el clip, la
herramienta prueba cada comienzo con cada duración y se queda con el
tramo que menos salta al volver al principio.

> Al puntuar se resta el movimiento medio del tramo. Sin eso gana siempre
> un trozo en el que el personaje está casi quieto: cierra de maravilla y
> no es un andar.

La herramienta lo dice al ejecutarse:

```
ciclo: fotogramas 85..118 (34 de largo)
  salto al cerrar el bucle 0.0161  /  salto normal entre fotogramas 0.0817
```

**Si el primer número es menor que el segundo, el bucle es invisible**:
el corte cuesta menos que un paso normal. Si es más del doble, se va a
notar el tirón y hay que generar otro vídeo.

---

## Estado de la maga actual

Sacada de cuatro vídeos, montada en `art/maga_*.png` y enganchada en
`ActorAnimator.maga()`.

| fila | dirección | de dónde sale | cierre del bucle |
|---|---|---|---|
| 0 | E | vídeo | 0,0161 vs 0,0817 — invisible |
| 1 | SE | **provisional**: lleva la fila S | — |
| 2 | S | vídeo | 0,0225 vs 0,0228 — invisible |
| 3 | SO | **provisional**: espejo de S | — |
| 4 | O | espejo de E | — |
| 5 | NO | espejo de NE | — |
| 6 | N | vídeo | 0,0277 vs 0,0371 — invisible |
| 7 | NE | vídeo | 0,0541 vs 0,0828 — invisible |

**Lo que falta:**

- Vídeo de **SE** (y con él, SO por espejo). Mientras tanto llevan la
  fila S, que es la vecina; se nota poco al moverse en diagonal hacia
  abajo, pero está ahí.
- **`idle`, `cast`, `hurt` y `death`** son de una columna: el fotograma
  del ciclo con los pies más juntos. No respira ni se cae. Es
  exactamente donde estuvo rita al principio.
- Ajustar **`stride`** mirándola andar, hasta que los pies no patinen.
  Es lo único que hay que tocar a ojo, y describe la anatomía del
  personaje —lo larga que es su zancada—, no su prisa.
