# Mejoras propuestas para los hechizos de Magic Symbols

22 de noviembre de 2026 · Propuestas de Pablo, basadas en el estudio del código de Mages of Mystralia y su comparación con Magic Symbols.

**Revisión del 22/11 (contexto dirección):** cada punto lleva debajo un bloque **Revisión** con lo que dice nuestro código (comprobado), lo que se añade y lo que se modifica. El texto original de Pablo no se ha tocado. El orden de trabajo revisado está al final.

> **Regla de uso:** de Mystralia se toman **reglas e ideas** (por ejemplo, el factor 1,2 de Buscar), **no su código ni sus tablas**.

## 0. Antes de empezar: qué entra en la demo

La demo lleva fuego, agua y tierra con el kit **ᛇ flecha, ᛁ línea, ᛜ barrera, ᛏ altura, ᚱ pulso y ᛒ suelo** (`magia/lanzador_3d.gd:137`). **Buscar ᚨ, Repetición ᚠ, Carga ⧖, Crecer ᚷ, Permanencia ᛉ y Rebote ᚢ no están en la demo**, y el primer libro ya está lleno (pregunta P3 del plan de hechizos, aplazada). Por eso el orden revisado empieza por lo que se juega en la demo: Flecha, Barrera, Pulso, Línea y Suelo.

**Nombres:** en el juego, ᚱ se ve como «pulso» (`raido` en el código) y ᚷ como «crecer» (`pulso` en el código). En este documento, «Pulso» es **ᚱ**.

## 1. Buscar: conservar el objetivo

- Mantener el objetivo mientras siga vivo, sea apuntable y esté dentro de los límites de seguimiento.
- Cambiarlo solo cuando otro candidato sea suficientemente preferible. Como punto de partida, probar la regla de Mystralia: `distancia_candidato × 1,2 < distancia_objetivo_actual`.
- Separar la búsqueda de candidatos del giro: buscar a intervalos y orientar el proyectil suavemente en cada actualización.
- Definir y mostrar qué ocurre cuando hay una pared entre el proyectil y el objetivo.
- Conservar el efecto de las repeticiones del glifo sobre el cono y la capacidad de giro.

**Objetivo:** seguimiento estable, sin saltos constantes entre enemigos cercanos.

**Comprobación:** dos enemigos a distancias similares, muerte del objetivo, pérdida de apuntabilidad, salida del alcance y obstáculos.

> **Revisión.** Confirmado. `_buscar` (`magia/hechizo_vivo.gd:2147-2172`) elige en **cada fotograma** el enemigo más cercano del cono (alcance 6 casillas; el cono se abre con cada ᚨ, `BUSCA_COS_POR_NIVEL`). **No guarda el objetivo** y **no mira paredes**. Ya respeta `apuntable()` (canouro con niebla) e ignora a los golpeados en ese tramo.
> - **Añadir:** el orbe que sale disparado con ᚨ en órbita (`_orbe_busca`, `:671`) tiene que usar la misma regla.
> - **Añadir:** con pared en medio, propuesta de partida: no se elige un objetivo que no se ve (rayo contra lo sólido, como el corte del haz).
> - **Fuera de la demo**: va al final del orden.

## 2. Repetición: hacer visible la distribución de copias

- Distinguir tres distribuciones: abanico, proyectiles paralelos y ráfaga por una misma línea.
- Representar la distribución en la página y en la previsión, aprovechando la ráfaga que ya existe.
- Dar a cada distribución una función: cobertura angular, cobertura de carriles o concentración temporal.
- Mantener un presupuesto común de proyectiles y calcular el coste de las instancias producidas.
- Definir expresamente si las copias pueden generar hijos. Empezar las pruebas con esa multiplicación desactivada y habilitarla únicamente con límites y coste propios.

**Objetivo:** que más copias permitan elegir cómo cubrir el espacio.

**Comprobación:** misma receta contra un blanco, varios blancos separados y varios carriles; previsión y ejecución deben coincidir.

> **Revisión.** Hoy hay **dos de las tres** distribuciones:
> - **Abanico + separación lateral, mezclados:** copias a la vez, abiertas `dispersion` (15° en total) y separadas `separacion` (`HechizoVivo.salida_de_copia`, `hechizo_vivo.gd:270`).
> - **Ráfaga:** ᛇ antes de ᚠ, una cada 0,12 s por la misma línea (`nucleo/hechizo.gd:24`).
> - **Paralelo puro** (la captura de Mystralia, O18) = `dispersion` 0.
>
> **Añadir:**
> - **Cómo se elige la distribución al dibujar.** Hoy solo la ráfaga tiene gesto (el orden). Opciones: el orden de dibujo o el hueco de la corona donde se dibuja ᚠ (`Grimorio.dir_corona`). Depende de H4 (vecindad u orden), que está sin decidir.
> - **Repetición en el haz ᛁ y en ᛒ suelo:** hoy no hacen nada con ᚠ y cobran tinta igual (H13).
> - **Copias e hijos:** el cobro del hijo (`Dano.hijos_previstos`, `nucleo/dano.gd:169`) **no se multiplica por las copias**. Si cada copia suelta su hijo, se paga uno y salen varios. Hay que comprobarlo y cobrar hijos × copias.

## 3. Barrera: identificar la protección construida

- Distinguir visualmente protección personal, obstáculo colocado y barrera transportada o creada por un hijo.
- Mostrar en el resumen dónde nace, si acompaña a la jugadora y qué ataques puede detener.
- Mantener la geometría y las diferencias entre materias.
- Estudiar una separación mínima de enemigos al aparecer la protección personal, limitada a resolver solapamientos y sin regalar un empuje ofensivo.
- Señalar qué barrera antigua desaparecerá cuando se alcance el máximo de construcciones.

**Objetivo:** que la silueta y la previsión permitan confiar en la defensa.

**Comprobación:** proyectiles, ataques de suelo, cuerpo a cuerpo, explosiones y aparición junto a un enemigo; cada variante debe comunicar sus límites.

> **Revisión.**
> - **«Qué ataques puede detener» sale de la tabla de contacto C19** (barrera × proyectil, aprobada). La sesión de combate ya la ha metido en las flechas y el aliento (fase B, 22/11). La tabla vive en **`nucleo/contacto.gd`** (`Contacto`); la usan `combate_3d.gd:2421`, `objetos/dragon_jefe_3d.gd:704` y `objetos/flecha_trampa_3d.gd:72`, y la prueba es `herramientas/prueba_contacto.gd` (precisión de la sesión HECHIZOS, 22/11). El resumen y la previsión (`PrevisionReaccion3D`) deben leer **esa misma tabla**, para que no haya dos verdades.
> - **Ejemplo ya hecho:** la barrera sola de tierra es ahora un anillo fino que **solo para proyectiles**: los golpes desde el suelo, el cuerpo a cuerpo y las explosiones lo atraviesan (A4 de combate). Tiene que comunicarlo.
> - **El tope ya existe:** 3 barreras (`lanzador_3d.gd:68`). Falta lo que propones: señalar cuál se irá.
> - **La burbuja** también es protección personal, con la decisión C10: rebota flechas y la de fuego las quema.

## 4. Carga: unificar el compromiso entre espera, potencia y tinta

- Comparar Carga, sobrecarga y la combinación de ambas antes de ajustar cifras.
- Diseñar una relación común: el glifo define qué propiedades pueden potenciarse y mantener pulsado ejecuta la carga.
- Mostrar progreso, umbral de potencia y coste antes de soltar.
- Evitar multiplicaciones de potencia poco visibles entre ambos mecanismos.
- Definir el resultado de soltar antes del umbral, completar la carga o interrumpirla.

**Objetivo:** una operación de carga comprensible y un coste proporcional a su beneficio.

**Comprobación:** daño, tamaño, tiempo de exposición y tinta de las tres variantes, incluyendo interrupciones y falta de recurso.

> **Revisión.** Confirmado: hoy se acumulan sin verse.
> - ⧖ **cuenta doble** para el daño (`cuenta_dano` = 2, `nucleo/sigils.gd:418`).
> - ⧖ además da **×1,5 de potencia y ×1,69 de tamaño** hasta 3 glifos.
> - La **sobrecarga** (mantener 0,8 s) da otro **×1,5 con tinta ×2** (`lanzador_3d.gd:59-61`).
>
> **Modificar:** hoy ⧖ tiene **dos papeles**, carga y disparador (entre dos formas). Si el conector va por la página de dos círculos (H12, punto 6), **⧖ queda solo como carga**, y este punto se simplifica.
>
> **Añadir:** ⧖ **no se puede dibujar a mano** (solo con la paleta F1) y no está en la demo. La sobrecarga sí está en la demo: lo primero es hacer **legible la sobrecarga**.

## 5. Crecer y Permanencia: presupuestar espacio y tiempo

- Calcular separadamente tamaño máximo, tiempo de crecimiento, duración y frecuencia de los efectos repetidos.
- Revisar su beneficio conjunto: una zona grande y duradera controla mucho más espacio y tiempo aunque conserve el daño por impacto.
- Probar un balance donde añadir estas funciones no otorgue además un salto automático de daño por recuento de glifos.
- Mostrar la duración restante y avisar antes de desaparecer con una convención visual común.
- Mantener funciones distintas: Crecer amplía la cobertura; Permanencia prolonga su ocupación.

**Objetivo:** que cobertura y duración sean elecciones con coste propio.

**Comprobación:** comparar zona pequeña, grande, duradera y grande-duradera; medir daño efectivo, objetivos alcanzados, control y tinta.

> **Revisión.** Ampliado a una **regla general** (ver §10): el salto de daño por recuento afecta a **todos** los glifos, no solo a estos dos.
> - **Añadir:** el aviso de «va a desaparecer» con la **misma convención que el temporizador común** (P8, `CONCEPTO_TEMPORIZADOR_2026-11-21.md`), para que todo lo que caduca en el juego avise igual.

## 6. Conectores: construir dos tramos explícitos

- Representar `hechizo A → condición → hechizo B`, con sello y glifos propios en cada tramo.
- Empezar por dos condiciones: al impactar y al acabar. Definir qué colisiones y causas de finalización corresponden a cada una.
- Mantener seis glifos totales inicialmente, repartibles entre ambos tramos.
- Conservar mezcla elemental y secuencia como operaciones distintas. La mezcla produce una manifestación resultante; el conector relaciona dos manifestaciones.
- Sustituir el recargo genérico del hijo por el cálculo de su coste real. Comparar cobro al activarse y reserva inicial antes de escoger la política definitiva.
- Mostrar coste inicial, coste condicionado y máximo previsto.
- Permitir que un segundo tramo afecte al enemigo golpeado por el primero, conservando la protección contra impactos duplicados dentro de cada tramo.
- Controlar los premios de tinta para que una cadena no cobre repetidamente la misma reacción.
- Mantener límites compartidos de profundidad y vivos; añadir un límite de efectos totales generados por lanzamiento.
- Incorporar a la previsión el punto de activación y el primer efecto secundario.

**Objetivo:** cadenas elementales comprensibles y presupuestadas, como mojar y después electrificar al mismo objetivo.

**Comprobación:** impacto en enemigo y pared, expiración, cancelación, retorno, mismo objetivo entre tramos, falta de tinta, copias, límites y guardado/carga.

> **Revisión.** Es **H12, la página de dos círculos, ya aprobada** (2 sellos, uno por círculo; 6 glifos en total). Este punto es su especificación técnica: se unen.
> - **Responde a la pregunta P4** del plan de hechizos: el libro avanzado (mezcla de dos sellos en un hechizo) y los dos círculos (secuencia) **conviven**, porque son operaciones distintas.
> - **Lo que ya existe:**
>   - la lógica del hijo (`Hechizo.DISPARADOR`, `hechizo_vivo.gd:1781-1814`);
>   - los eventos `al_impactar`, `al_detenerse` y `al_expirar`;
>   - profundidad 2 y tope de 32 vivos;
>   - premio de tinta una vez por enemigo y tipo (`nucleo/tinta_reaccion.gd`), que ya evita el cobro repetido de la misma reacción.
> - **Lo que hay que cambiar:**
>   - el hijo va con el elemento del padre;
>   - se cobra un recargo fijo (`K_HIJO` 0,10) que no mira las copias.
> - **Ojo:** el ejemplo «mojar y después electrificar» usa rayo, que no está en la demo. Para la demo: **mojar y después congelar** tampoco vale (hielo). Con fuego, agua y tierra: **flecha de agua → barrera de tierra** (muro donde cae) o **fuego → agua** (vapor).
> - **Guardado y carga:** ~~las páginas guardadas no se recargan en el Grimorio (`nucleo/repertoire.gd:216`, ya anotado en LIBRO_AVANZADO §0). Hay que arreglarlo antes.~~ **Corregido el 22/11 (sesión HECHIZOS, comprobado en el código):** eso ya está arreglado. `Grimorio.cargar_paginas()` (`magia/grimorio.gd:222`) rehace las páginas desde `Repertoire.paginas` al montarse (`:181-185`: «antes… la partida cargada abría las tres páginas en blanco»), al cambiar de libro (`_al_cambiar_libro`) y en `Lanzador3D` tras la progresión (`lanzador_3d.gd:573`). El comentario de `repertoire.gd:219-221` está desfasado. Lo que falta para H12 es solo **guardar el segundo círculo** (`{hijo: {sello, glifos}, condicion}`), no la recarga.

## 7. Rebote: convertirlo en un punto de composición

- Conservar el número explícito de rebotes y su límite.
- Verificar que la previsión reproduce los rebotes de la ejecución real.
- Aprovechar `al_rebotar` para activar un efecto secundario en el punto y dirección de salida.
- Aplicar a esos efectos los mismos costes y presupuestos de los conectores.

**Objetivo:** transportar y activar efectos aprovechando paredes y esquinas.

**Comprobación:** superficies oblicuas, esquinas, varios rebotes y un hijo que nace una sola vez por evento.

> **Revisión.** `al_rebotar` ya existe como evento (`nucleo/hechizo.gd:65`), así que el coste es bajo. En los dos círculos sería una **tercera condición** (después de «al impactar» y «al acabar»). No hay que confundirlo con el **rebote de flechas enemigas** en barrera y burbuja (C9 y C10), que es de combate. **Fuera de la demo.**

## 8. Flecha: ampliar trayectorias sin acumular mejoras implícitas

- Conservar Flecha como transporte y alcance, con significado estable al repetirla.
- Separar alcance, velocidad y curvatura como parámetros distintos.
- Probar una modificación explícita de curvatura cuando exista una situación que la aproveche.
- Mostrar la trayectoria completa en la previsión.
- Presupuestar la utilidad del movimiento sin aumentar automáticamente daño y tamaño.

**Objetivo:** nuevas rutas para alcanzar objetivos, manteniendo legible el efecto de cada propiedad.

**Comprobación:** receptor lateral, obstáculo intermedio y trayectoria con gravedad; contrastar coste y facilidad de acierto.

> **Revisión.** Confirmado: hoy cada ᛇ suma alcance (+1 casilla, tope 6) y un poco de arco, y **además sube el daño por recuento**, que es lo que el punto quiere evitar.
> - **Curvatura:** no tenemos runas de dirección. Una curva hacia un lado podría salir del **hueco de la corona** donde se dibuja la flecha (lo mismo que se plantea para H11 y para la distribución de la repetición). Se decide junto con H4.
> - **En la demo:** es el glifo más usado, así que va pronto en el orden.

## 9. Pulso: delimitar su función respecto a los conectores

- Mantener Pulso como propagación del efecto del hechizo actual.
- Reservar a los conectores la creación de otro hechizo completo.
- Distinguir visualmente crecimiento, propagación, detonación y nacimiento de un hijo.
- Si se incorpora un emisor periódico de hijos, darle intervalo, coste por activación y máximo de emisiones propios.

**Objetivo:** que cada glifo y relación tengan una consecuencia reconocible.

**Comprobación:** que el jugador pueda distinguir un pulso de un hijo sin consultar los datos internos.

> **Revisión.** Es **ᚱ**: pulso de 4 casillas por glifo (tope 12). Salta **al impactar** si el hechizo viaja y es **continuo** si se queda; el continuo cobra recargo (`Dano.es_continuo`). Está en la demo. El nacimiento del hijo hoy no tiene efecto propio: hay que **verlo nacer** (H1b, punto 5).

## 10. Añadido en la revisión: qué glifos suben el daño

Hoy el daño base sale del **recuento de glifos «ofensivos»** (12 / 24 / 40; `nucleo/dano.gd:8`, `base_dano`). **Cuentan todos menos ᛁ, ᛏ y posición** (`cuenta_dano` en `nucleo/sigils.gd:380-427`). Así que Flecha, Crecer, Permanencia, Buscar, Rebote y Repetición suben el daño aunque solo mueven, alargan o multiplican: es el problema de los puntos 5 y 8, pero general.

**Propuesta:** decidir, glifo a glifo, cuáles son de **transporte o forma** (no suben el daño: su beneficio es el alcance, el tamaño o la duración) y cuáles son de **potencia**. Es poner `cuenta_dano: false` en los que toque: **un dato por glifo**, coste bajo. Cambiará las pruebas con «golden» (`prueba_dano_tinta`, `prueba_catalogo_reacciones`): hay que regenerarlas a propósito y anotarlo.

## Orden de trabajo propuesto

1. Mejorar Buscar y comprobar su estabilidad.
2. Clarificar las distribuciones de Repetición y las variantes de Barrera.
3. Revisar Carga, sobrecarga y el balance de Crecer con Permanencia.
4. Definir y construir los conectores, sus costes, impactos y previsión.
5. Extender Rebote y evaluar trayectorias curvas de Flecha en salas concretas.
6. Introducir emisiones periódicas únicamente después de validar los presupuestos de las cadenas.

Cada mejora se considera terminada cuando sus reglas pasan las comprobaciones correspondientes y su comportamiento se verifica dentro del juego.

> **Orden revisado** (primero lo que se juega en la demo):
> 1. **Qué glifos suben el daño** (§10). Es la base del balance de todo lo demás.
> 2. **Barrera con la tabla de contacto C19** (punto 3). Combate ya la usa en flechas y aliento.
> 3. **Flecha** (punto 8): sin daño implícito y con la trayectoria completa en la previsión.
> 4. **Repetición en haz y ᛒ (H13) y sus distribuciones** (punto 2). Pide decidir H4.
> 5. **Sobrecarga legible**, y luego la Carga ⧖ (punto 4) cuando ⧖ sea dibujable.
> 6. **Conectores = H12** (punto 6), con Rebote como tercera condición (punto 7).
> 7. **Crecer y Permanencia** (punto 5), con el aviso del temporizador común.
> 8. **Buscar** (punto 1), cuando entre en el juego.
> 9. Emisiones periódicas, al final.
>
> Para comprobar cada punto: un escenario sin ventana (`herramientas/escenario_base.gd`) y, al final, verlo en el juego.


## 11. Botín de enemigos: fórmula acordada y mejoras respecto a Mystralia

**Acuerdo de Pablo:** 22 de noviembre de 2026. Se aprueba esta dirección de diseño. Este apartado documenta la propuesta; no supone su implementación ni la validación de sus cifras mediante partidas.

### 11.1 Separar las recompensas

El reparto tendrá tres canales independientes:

1. Oro y materiales, según el enemigo y su tabla.
2. Recuperación de tinta, como recompensa predecible por combatir.
3. Recuperación de vida, con una probabilidad limitada que responde a la necesidad.

La necesidad de vida o tinta no modificará el valor económico del enemigo ni la probabilidad de materiales vendibles, llaves o recompensas de progreso.

### 11.2 Oro y materiales

Conservar inicialmente las tablas y los valores base actuales. Las piezas de nivel podrán sobrescribir el oro como ya permite el código.

| Enemigo | Oro base |
|---|---:|
| Limo | 5 |
| Canouro | 8 |
| Goblin | 10 |
| Chamán | 15 |
| Gólem | 40 |
| Elemental | 150 |

Los materiales mantienen sus tiradas particulares. Combatir con poca vida no aumenta las recompensas vendibles.

### 11.3 Tinta

Conservar inicialmente la fórmula ya incorporada al código:

```text
tinta = base + 4 × bonificación

base = 6 para enemigos normales
base = 10 para enemigos grandes

bonificación = 1 si murió por debilidad o tras una reacción premiada
bonificación = 0 en otro caso
```

La bonificación se aplica una sola vez aunque coincidan debilidad y reacción: 6/10 para una muerte ordinaria y 10/14 con bonificación, respectivamente.

No añadir todavía un multiplicador por falta de tinta. Evaluar conjuntamente regeneración, golpe cuerpo a cuerpo, premios por reacción y gotas al matar. Registrar la recuperación real, descontando el exceso que no cabe en la barra.

### 11.4 Vida: curva propuesta

Sustituir el salto actual del 15 % al 25 % al bajar del 34 % de vida por una curva continua:

```text
limitar(x) = mínimo(1, máximo(0, x))

h = limitar((vida_actual + curación_disponible) / vida_máxima)

probabilidad_vida =
    0,15 × limitar((1 − h) / 0,20)
  + 0,10 × limitar((0,50 − h) / 0,30)
```

`curación_disponible` cuenta los recogibles de vida vivos y accesibles del encuentro. No incluye pociones de la mochila, recogibles inaccesibles ni recursos de todo el mapa. Cada recogible pendiente se contabiliza una sola vez y se retira del registro al recogerse o desaparecer.

Sin recogibles pendientes:

| Vida actual | Probabilidad de soltar vida |
|---|---:|
| 100 % | 0 % |
| 90 % | 7,5 % |
| 80 % | 15 % |
| 50 % | 15 % |
| 40 % | 18,3 % |
| 34 % | 20,3 % |
| 30 % | 21,7 % |
| 20 % o menos | 25 % |

Mantener inicialmente la cantidad actual:

```text
curación_del_recogible = 0,12 × vida_máxima
curación_aplicada = mínimo(curación_del_recogible, vida_que_falta_al_recoger)
```

Con 100 de vida máxima, cada recogible cura hasta 12 puntos. El rendimiento esperado es 1,8 puntos por enemigo al 15 % y 3 puntos al 25 %, suponiendo recogida sin desperdicio. Son valores iniciales para probar, no un balance final medido.

### 11.5 Reglas de reparto y recogida

- Un enemigo original concede su recompensa una vez por intento válido.
- Divisiones e invocaciones comparten un presupuesto de recompensa con su origen.
- Reiniciar un encuentro no permite conservar y repetir indefinidamente el mismo botín. La política concreta debe coordinarse con la restauración del encuentro.
- Los recogibles de recuperación no se convierten en oro si sobran.
- Evitar que el imán o la recogida automática consuman un recurso cuando su barra está llena. Mantener la caducidad de los recogibles para impedir almacenarlos indefinidamente.
- Registrar por separado valor generado, recogido, recuperado realmente y desperdiciado.

### 11.6 Qué se mejora respecto al código de Mystralia

**Evitar la competencia entre recuperación y economía.** En `DropConfig`, Mystralia modifica pesos de vida y maná y luego normaliza una única elección que también contiene moneda y ausencia de botín. Necesitar ambos recursos hace que compitan entre sí y altera la probabilidad económica. Aquí los tres canales quedan separados.

En el perfil extraído `DropConfigRegular`, los pesos base son nada 40, moneda 30, vida 5 y maná 5. Los multiplicadores de recuperación interpolan de 5 con la reserva vacía a 0,25 con la reserva llena. Con vida al 20 %, la probabilidad de vida es aproximadamente 22,1 % con maná lleno y 18,3 % con maná al 20 %. El ejemplo corresponde a ese perfil concreto, no a todos los enemigos de Mystralia.

**Contemplar recuperación pendiente.** La función revisada de Mystralia consulta las barras actuales, sin incorporar los recogibles disponibles en el suelo. Aquí se cuentan los recogibles de vida accesibles para evitar ayudas redundantes tras varias muertes seguidas.

**Medir las malas rachas antes de compensarlas.** Las tiradas independientes pueden producir sequías: con una probabilidad constante del 25 %, seis muertes seguidas sin curación tienen una probabilidad aproximada del 17,8 %. Registrar las rachas y estudiar una compensación pequeña y limitada solo si perjudican las partidas. No se aprueba todavía una garantía de curación ni una fórmula adicional de compensación.

**Validar las tablas.** La implementación revisada de Mystralia divide por la suma de pesos sin comprobar explícitamente que sea positiva; una entrada repetida del mismo tipo sobrescribe la anterior. En Magic Symbols, validar pesos no negativos, probabilidades independientes entre 0 y 1, suma positiva para elecciones ponderadas y tratamiento explícito de duplicados. Una tabla inválida debe producir un resultado seguro y un diagnóstico útil.

### 11.7 Primera implementación y evaluación

1. Conservar oro, materiales y la fórmula actual de tinta.
2. Aplicar la curva de probabilidad de vida.
3. Registrar y descontar la curación pendiente accesible.
4. Verificar límites, caducidad, recogida con barras llenas y ausencia de recompensas duplicadas.
5. Medir por encuentro vida perdida, vida recuperada realmente, tinta gastada y recuperada, recogibles desperdiciados y rachas sin curación.

La primera prueba debe aislar esta modificación: no cambiar simultáneamente precios de consumibles, daño enemigo y cantidad de curación.

> **Revisión (22/11, comprobado en el código; Pablo: «déjalo como ahora» sobre el reintento).**
> - **Ya coincide con el código:** los tres canales van separados (Combate3D._soltar_botin tira la tabla y, aparte, _soltar_recogibles), y la fórmula de tinta es la de 11.3, con el +4 sumado una sola vez.
> - **La curva de 11.4 está bien calculada.** Mejora lo de hoy: ahora sale vida un 15 % de las veces aunque la vida esté llena (RECOGIBLE_VIDA_PROB, o _PROB_BAJA por debajo del 34 %).
> - **Reintento (11.5): decidido «como ahora».** Los enemigos repuestos al reintentar vuelven a soltar todo: oro, gota y tirada de vida. Esto **sustituye** a la frase «reiniciar un encuentro no permite conservar y repetir indefinidamente el mismo botín».
> - **Recoger con la barra llena: hoy se gasta.** Botin3D._coger (enemigos/combate_3d.gd:4555) aplica la tinta o la vida sin mirar si cabe, y el número flotante enseña el valor entero («+12 vida» aunque cure 3). Ajuste: **no se imanta ni se recoge con la barra llena** (se queda en el suelo hasta caducar, 8 s) y el número enseña **lo que de verdad entra**.
> - **Divisiones (11.5): pasa hoy.** El limo grande se deshace sin botín (Limo3D._desvanecer) y **cada hijo suelta su gota entera, su oro y su tirada de vida** al morir (hereda _soltar_botin). Ajuste: presupuesto común, en el que el original reparte su recompensa entre los hijos. En cambio, el mouro que rebrota y las ánimas de la Compaña ya están bien: no sueltan nada al reponerse.
> - **«Accesible» (11.4), simplificado:** contar los recogibles de vida que siguen en el suelo a **≤ 8 casillas** de la jugadora. Calcular rutas sería caro y frágil.
> - **Tabla de oro (11.2), completa:** limo 5, loberno 6, canouro 8, goblin 10, mouro 12, chamán 15, procesión de la Santa Compaña 20 (al acabarse, no por ánima), gólem 40 y elemental 150 (
ucleo/datos/botin_tablas.tsv:50-89).
