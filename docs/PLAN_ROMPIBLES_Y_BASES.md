# Plan · Romper con plantillas y fundir la base de las piezas

Propuesta del 27/10/2026. Sale de revisar los documentos de técnicas de Nintendo (Donkey Kong Bananza y Zelda) y cruzarlos con el juego. Son
dos trabajos independientes; cada uno acaba con sus pruebas a 0 y sus capturas.

---

## 1. Romper con pocas plantillas

### 1.1 De dónde viene la idea

En Bananza hay más de 800 materiales y todos se rompen bien porque cada uno es **una plantilla de comportamiento × su textura**. Son solo
9 plantillas (crujiente, granular, húmedo…) y 8 de cómo vuelan los trozos (ligero, pesado, fino…). Las grietas son una capa común que crece
con el daño, y el «último golpe» se avisa siempre igual.

### 1.2 Qué hay hoy

Cada pieza que se rompe lo hace a su manera, con su propio código de polvo, trozos y sonido:

| pieza | clase | cómo se rompe | grietas | aviso de último golpe |
|---|---|---|---|---|
| jarrón, caja | `Rompible3D` | un golpe cualquiera: polvo, sonido, trozos que quedan como restos, botín por zona, flag | no | no |
| muro agrietado | `MuroAgrietado3D` | `golpes` de tierra; se deshace por celdas | sí (capa Voronoi propia) | no |
| columna | `MuroAgrietado3D` (modelo `columna_agrietada`) | pulsos o una explosión; puede caer como puente | sí | no |
| estalagmita | `EstalagmitaPulso3D` | dos pulsos: vibra y cae; queda rota | no | la vibración del primero |
| geoda | `GeodaPulso3D` | un pulso: carga 0,9 s y explota | no | la carga |

### 1.3 La propuesta

**Una tabla de plantillas** (`objetos/plantillas_rotura.gd`, solo datos). Cada fila dice:
- el color y el tamaño del polvo;
- qué trozos saltan (`cascote_*`, cuántos y con qué peso: ligero, pesado o fino);
- el sonido;
- si quedan restos o desaparece;
- la sacudida de cámara.

Cinco plantillas bastan para lo que hay y para lo que viene:

| plantilla | piezas | se nota en |
|---|---|---|
| cerámica (crujiente) | jarrones | trozos curvos ligeros, sonido agudo y corto |
| madera (astillas) | cajas, barriles | astillas largas, sonido seco |
| piedra (pesado) | muro, columna, estalagmita | cascotes que caen enseguida, polvo gris, golpe grave |
| cristal | geoda, cristales resonantes | esquirlas que brillan, nota del pulso |
| húmedo | barro, setas grandes (futuro) | sin trozos, salpica, oscurece el suelo (humedad) |

**Cada pieza dice su material** en el mapa (`material=piedra`), con un valor por defecto por clase. El código de cada clase deja de pintar
el polvo y los trozos: pide `PlantillasRotura.romper(pieza, punto)`.

**Las grietas pasan a ser una capa común.** La capa de `MuroAgrietado3D` (Voronoi que crece con cada golpe) sale a un sombreado propio que
puede llevar cualquier pieza con `golpes` > 1: jarrón reforzado, caja de hierro, columna, estalagmita.

**El último golpe se avisa siempre igual.** Cuando a la pieza le queda un golpe:
- las grietas brillan un poco y laten;
- la pieza da una sacudida corta;
- suena un «crac».

En Bananza es la calcomanía de «a punto de romperse»; aquí sale de la misma capa de grietas, sin arte nuevo.

### 1.4 Ruta

1. **Tabla y llamada única.** Se crea `PlantillasRotura` y `Rompible3D` y `MuroAgrietado3D` la usan. **Sin cambiar cómo se ven**: el primer
   paso solo junta el código. Prueba: los escenarios de la Cueva y de los mapas abiertos siguen a 0.
2. **Capa de grietas común y último golpe.** Se saca la capa de `MuroAgrietado3D` a `presentacion/grietas_3d.gd` y se añade el aviso.
   Prueba nueva `prueba_rompibles.gd`:
   - cada material suelta lo suyo;
   - el número de golpes se cumple;
   - el aviso sale con el último golpe y no antes;
   - la flag hace que no vuelva.
3. **Estalagmita y geoda.** Pasan a la tabla (piedra y cristal). Su comportamiento propio se queda (caer, explotar); solo cambia lo que se ve
   y se oye al romperse.
4. **Las cinco plantillas afinadas** con capturas de cada una (`docs/capturas/rompibles/`) y el sonido por plantilla
   (`audio/gen_sfx_rotura.py`, sintetizado como los demás).

### 1.5 Decisiones

- ¿El jarrón sigue rompiéndose con **cualquier** golpe, o los grandes (`alto=si`) aguantan dos?
- ¿Una caja de madera **arde** con fuego (se quema y deja ceniza) o solo se rompe?
- ¿Cinco plantillas, o alguna más desde el principio (hielo, metal)?

---

## 2. Fundir la base de las piezas con el suelo

### 2.1 De dónde viene la idea

En Zelda (BotW) las rocas, raíces y edificios no parecen pegados encima del terreno: el terreno se dibuja después y se funde con lo que ya
está, por profundidad. Aquí no hace falta llegar tan lejos: basta con que el pie de cada pieza tome el color y la sombra del suelo en sus
últimos centímetros.

### 2.2 Qué hay hoy

Las piezas del decorado (paredes, rocas, pilares, árboles, cofres, braseros) comparten el material común `Ocluso3D`. Donde tocan el suelo
hay un corte limpio: la roca gris sobre la hierba verde, con la misma luz arriba y abajo. Se nota sobre todo en las paredes de la Cueva y
en las rocas del Bosque.

### 2.3 Tareas

1. **Captura de antes** (`herramientas/captura_bases.gd`, con ventana): cuatro encuadres fijos con rocas, paredes, pilares y árboles en el
   Bosque 01 v01 y en la Cueva Resonante.
2. **El fundido en `Ocluso3D`.** En el sombreado común, a menos de `FUNDIR_ALTO` (unos 0,25 u) de la base de la pieza:
   - el color se mezcla hacia el del suelo;
   - se oscurece un poco, como sombra de contacto.
   
   La altura se mide desde el **origen de la propia pieza** (`MODEL_MATRIX`), así vale igual en el suelo, en una terraza o en el fondo de
   un pozo, sin saber nada del terreno.
3. **El color del suelo.**
   - Primera versión: un color por nivel y estilo, que pone la maqueta (hierba en el Bosque, roca en la Cueva).
   - Segunda versión, si la primera se queda corta: el suelo de verdad bajo la pieza, leyendo las mismas texturas y el mapa de tipos del
     suelo por la posición x/z.
4. **Borde irregular.** El límite del fundido lleva ruido para que no sea una raya recta a la misma altura en todas las piezas.
5. **Qué no lo lleva.** Lo que se mueve o se separa del suelo:
   - personajes y enemigos;
   - la tapa de los cofres;
   - el agua;
   - lo que cae (la columna-puente, la estalagmita al caer).
   
   Cada pieza puede quitárselo con un parámetro (`fundir = 0`).
6. **Captura de después y prueba.** Las mismas cuatro fotos, y una prueba que comprueba tres cosas:
   - el material compila;
   - la franja no pasa de `FUNDIR_ALTO`;
   - una pieza levantada del suelo (en una terraza) no se oscurece por arriba.
7. **Coste.** Una mezcla y una resta por píxel en las piezas: se mide con `herramientas/medir_rendimiento` antes y después.

### 2.4 Decisiones

- ¿Fuerza del fundido? Proponemos que se note de cerca sin verse como una mancha: se ajusta con las fotos.
- ¿Los árboles también, o solo roca y piedra? (en EoW los troncos tampoco tienen corte limpio).
