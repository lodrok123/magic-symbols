# Los estados de Magic Symbols, revisados con el modelo de *Echoes of Wisdom*

24/10/2026 · contexto JUEGO · análisis de solo lectura (no se ha tocado nada del repo).

**Qué se ha leído.** `docs/ANALISIS_EOW.md`, `EOW_3_ACTORES.md`, `PLAN_EOW.md`, `ESTADOS_SUELO.md` (§2), `PLAN_BOSQUE_EOW.md` (temperatura), y las secciones *El mundo*, *Enemigos* e *Interfaz y estados de partida* de `ARQUITECTURA.md`. Después, el código de cada sistema con estado. Las cifras son recuentos con grep sobre el código del juego, sin contar `herramientas/` ni `laboratorios/` (salvo que se diga). Las líneas son las del worktree `proyecto-analisis-profundo-bf47f8`.

**El patrón de EoW que se usa de vara de medir:**
1. **Una tabla por sistema.**
2. **Papeles pequeños de emisor y receptor** (*emite calor*, *propaga llama*, *inflamable*, *ardiendo*, *apaga*, *conduce*, *electrificado*, *congelable*, *le afecta el viento*) en vez de tipos.
3. **Lógica → señal con nombre → tabla de presentación.** La lógica no pinta.

---

## Resumen en cuatro frases

- **El suelo es el único sistema que ya sigue el modelo EoW**, pero solo a medias. La tabla `TRANSICIONES` existe y tiene un dueño. En cambio, la caducidad (`DURA`) está a cero y su reloj (`avanzar`) no lo llama nadie del juego. El hielo caduca en otros tres sitios.
- **La hierba, la electricidad, la lava y el «preso en hielo» tienen su estado fuera de `EstadosSuelo3D` o de `Combate3D`.** La hierba vive en la maqueta del Pipeline. La electricidad, en el emisor. La lava, en su pieza. El preso en hielo, en la magia.
- **Hay 11 implementaciones distintas de «arder».** De las 29 piezas de `objetos/`, 26 se escriben a mano su propia mini máquina «estado + señal». Solo `Reactivo3D` tiene papeles, y aun así sus papeles no se pueden combinar: `on_spell_hit` sale con `return` tras el primer papel que encuentra. `conduce` y `congelable` siguen **solo declarados**.
- **La presentación por tabla existe (`ReaccionesVfx3D`), pero se salta a menudo.** Hay unas 30 llamadas a VFX puntuales escritas directamente en la lógica, y varios efectos salen dos veces (tabla + llamada directa). Hay dos catálogos de reacciones con nombres distintos (el de `Mundo3D` y el de `Combate3D`). Y el estado del suelo se dispara desde el impacto *visual* (`Vfx3D.impacto`): la presentación manda sobre la lógica.

---

## (A) Tabla de sistemas

| sistema | dónde vive el estado | ¿dueño único? | ¿datos o `if`? | ¿tabla de presentación? | huecos frente a EoW |
|---|---|---|---|---|---|
| **Suelo** (mojada, helada, quemada, electrificada, segada) | `mundo/estados_suelo_3d.gd` (`_celdas`, `_intensidad`, `_queda`, `_avance`, `_escarcha`) | **Sí** para el hecho. **No** para la caducidad (ver Hielo) | **Datos**: `TRANSICIONES` (6 filas, l. 44-51), `DURA` (l. 55), `CANAL` (l. 34) | Sí: textura RGBA de un píxel por casilla (`textura()`), que leen los shaders. No hay tabla de reacción → VFX: el «vapor» de la fila se devuelve, pero lo pinta la maqueta a mano | `DURA` todo a 0 y `avanzar()` sin llamar. Sin filas para rayo, viento ni tierra. `electrificada` no tiene canal en la textura. Las transiciones no distinguen clase de suelo ni temperatura |
| **Hierba** (FINA / CRECIDA / PRENDIENDO / ARDIENDO / CENIZAS) | `presentacion/prueba_test2.gd` `_hf` (Pipeline) + `_mojada` (l. 4755) + `Hierba3D._humedad` (l. 232) + `EstadosSuelo3D` (avance y `quemada`) | **No: cuatro sitios** | **`if`/`match`** en `_impacto_en_hierba` (l. 4691-4707) y `_avanzar_estado` (l. 4801-4869) | Parcial: llamas por `_fx.llamas` directo; mojada y escarcha en una textura propia de `Hierba3D` | No es un receptor del mundo: no prende a enemigos ni a la jugadora. `segada` no la pone nadie en el juego. Hay dos relojes distintos para «mojada» |
| **Agua** (volumen, hielo por trozo, manantiales) | `mundo/agua_sim_3d.gd` (`helado[]`, `hielo_t[]`, fuentes) | Sí para el volumen. El hielo se **copia** en `EstadosSuelo3D` mediante `Lanzador3D.procesar_cambios_hielo` (l. 280-288) | Datos numéricos + `match elemento` en `ReaccionesAgua3D.aplicar` (l. 52-74) | El efecto sale por un `Callable` (`efecto`: «vapor», «hielo_desde»…) y por `Mundo3D.impacto` con nombres que no son elementos | Sin evaporación ambiental ni temperatura. El hielo dura una constante fija (20 s, l. 49) |
| **Hielo** (sobre agua / escarcha) | `AguaSim3D` (trozos) + `EstadosSuelo3D` (`helada` + `_escarcha`) + `Lanzador3D._hielo` (20 s, l. 81, 2244-2258) + `Hierba3D.ESCARCHA_S` (20 s, l. 228) | **No: cuatro relojes** | Constantes repetidas | — | El EoW «es hielo / se derrite» sería un papel. Aquí son cuatro temporizadores con el mismo número escrito cuatro veces |
| **Electricidad** | `EmisorRayo3D.electrificada` (`objetos/emisor_rayo_3d.gd:36`) + `EstadosSuelo3D.electrificada` (lo escribe **solo** `prueba_test2.gd:5318`, el canal del Test 2) + `Terreno3D.conductores` (l. 84) | **No: tres sitios** | Búsqueda en anchura con `Callable` | `Vfx3D.chispazo` directo (`emisor_rayo_3d.gd:181`) y losas propias | `casilla(x,y).electrificada` no se entera de las descargas del emisor. El papel `conduce` del cristal no lo lee nadie |
| **Objetos reactivos** (`Reactivo3D`) | `objetos/objetos_3d.gd`: `estado` (SANO / ARDIENDO / CONSUMIDO), `is_lit`, `activo`, `usado`, `_mojado_s` | Sí, dentro de la pieza | **Papeles** (`PAPELES_POR_TIPO`, l. 121-134, 10 papeles válidos) + `COMBUSTIBLES` / `FUENTES` como números | Sí (9 llamadas a `_reaccionar`), pero además 9 VFX puntuales directos (`fx.vapor`, `fx.ceniza`, `fx.chispazo`…) | Los papeles no se combinan (l. 426-452). `conduce` y `congelable` sin leer. Faltan `emite_calor`, `electrificado`, `le_afecta_viento` y un `apaga` de emisor (aquí `apaga` significa «se deja apagar») |
| **Piezas con script propio** (barril, cuerda, enredadera, lava, muro, tronco_puente, nexo, molino, pulsador, compuerta, surtidor, rompible…) | Una variable propia por pieza (`encendido`, `is_lit`, `roto_ya`, `cayo`, `mojado`, `Fase`…) | Sí por pieza, pero **26 de 29** archivos repiten «estado + señal» a mano | **`if rune_data.tags.has(...)`**: 37 comprobaciones en 10 archivos fuera de `objetos_3d.gd` (20 más dentro) | **No**: ninguna emite `Mundo3D.reaccion`. 21 VFX puntuales directos | Ninguna declara papeles. `is_lit` hace de papel implícito por duck typing (Reactivo3D, Cuerda3D, Lava3D) |
| **Lava** | `objetos/lava_3d.gd` (`_lava`, `_roca`, `is_lit`) | Sí (la roca la consulta `Puzle3D` con `es_roca`) | `if tags` + radio | VFX y sonido directos (l. 311-312). Sin reacción con nombre | No tiene papeles `emite_calor` ni `fuente_fuego`. No daña ni prende a enemigos ni a la jugadora. Comprueba el tipo `Barril3D` (l. 363) |
| **Enemigos: efectos** | `enemigos/combate_3d.gd`: 8 temporizadores sueltos (`quemando`, `envenenado`, `mojado`, `congelado`, `lento`, `stun_timer`, `interrupcion`, `_fase_empuje`) | Casi: el «preso en hielo» lo escribe `Lanzador3D.atrapar` desde fuera (`lanzador_3d.gd:320`) | **`if`/`match`** en `golpe` (l. 479-516) y `_efectos` (l. 712-752). Las duraciones vienen del `Hechizo` (HC3); los multiplicadores están escritos a mano | Sí para los cambios que se avisan (`_reaccionar`), pero `golpe_estrella` y `temblor` son directos (l. 692-693) | El contrato de 7 reacciones tiene **otros nombres** que el catálogo del mundo. Lento, interrupción y veneno no avisan. Sin estado «electrificado» que dure |
| **Enemigos: IA** | `Combate3D.estado: String` (patrulla, persigue, busca, vuelve; Gatopedro añade `huye`) | Sí | `match estado` + asignaciones de cadenas (6 en `combate_3d.gd`) | — | Sin tabla de estados de IA (en EoW, `motionsheets` + EventFlow). Correcto para el tamaño actual |
| **Escudo** | `enemigos/escudo_3d.gd`: `estado: String` (entero, ardiendo, quemado, roto), `vida` | Sí (componente) | Papeles propios (`PAPELES_DE_SERIE`, l. 52), **duplicados** de los de Reactivo3D | Sí (6 avisos, es el mejor ejemplo) | Su vocabulario de papeles es otra copia |
| **Jugadora** | `jugador/jugador_3d.gd`: `muerto`, `nadando`, `en_suelo`, `bloqueado`, `_trepando`, `empujando`, `_lanzando` + 9 temporizadores `_t_*` | Sí | `if` | — | **No tiene ningún estado de elemento**: sin `on_spell_hit`, sin `quemar`. La señal `flecha_ardiente_impacta` (`combate_3d.gd:137`) no tiene oyente. No arde en la hierba ni en la lava, y no resbala sobre la escarcha |
| **Animación** | `jugador/arbol_anim_pj.gd` (máquina de estados con reglas y rechazos) | **Sí (modelo a imitar)** | Datos (`ESTADOS_REDUCIDO`, `ENTRADAS_BLOQUEADAS_AL_NADAR`) + grafo | — | Sin clips de estado elemental (congelado = velocidad 0) |
| **Partida** | `Estado` (oro, mochila, mejoras, frascos), `Flags`, `Misiones`, `Tinta` (copia los frascos a `Estado`) | Sí | Datos | — | `Estado` no se guarda. Flags y Misiones se guardan, pero **el juego nunca las carga**. Los nombres de flag no siguen siempre `nivel.sala.hecho` |
| **Puzles** | `escenas/puzle.gd`: 33 tipos de pieza, 47 condiciones de pieza + `flag.*` + `casilla(x,y).<7 estados>` | Sí | **Datos** (`SENALES`, `CONDICIONES`, `ACCIONES`, `CLAVES`) | `Logros3D` por catálogo cerrado | Sin temporizador, sensor de zona, estado de la jugadora, contador de flags ni comparación de enteros. `si=` se evalúa solo cuando salta el `cuando=` |
| **Presentación de reacciones** | `presentacion/reacciones_vfx_3d.gd` (13 filas en `TABLA` + excepciones para 6 tipos) | — | **Datos** | Sí | Hay excepciones para goblin, flecha, escudo, seto, tronco y telaraña, pero **no** para fogata, brasero, cuerda, barril ni lava. Cualquier enemigo se toma por «goblin» (l. 102) |

---

## (B) Incoherencias y posibles bugs (archivo:línea)

**Dos o más dueños del mismo dato**
1. **El hielo tiene cuatro relojes de 20 s:** `magia/lanzador_3d.gd:81` (`DURACION_HIELO`, aplicado en l. 2244-2258), `mundo/agua_sim_3d.gd:49` (`DURA_HIELO`), `presentacion/hierba_3d.gd:228` (`ESCARCHA_S`) y el `DURA["helada"] = 0` de `estados_suelo_3d.gd:55`, que no se usa. Si se cambia uno, la escarcha de la hierba, la del suelo y el hielo del agua se desincronizan.
2. **La electricidad tiene tres dueños.** `EmisorRayo3D.electrificada` (`objetos/emisor_rayo_3d.gd:36`) no escribe `EstadosSuelo3D`. El único que lo escribe es la maqueta (`presentacion/prueba_test2.gd:5318`, canal del Test 2), y nunca lo quita en el flujo del canal. Además están `Terreno3D.conductores` (`terreno_3d.gd:84`). Consecuencia: la condición `casilla(x,y).electrificada` (`escenas/puzle.gd:348`) no ve las descargas del emisor.
3. **La hierba tiene cuatro sitios:** `_hf` (fase), `_mojada` (reloj de pared, `prueba_test2.gd:4733/4749`), `Hierba3D._humedad` (reloj de juego, `hierba_3d.gd:232`) y `EstadosSuelo3D` (avance y `quemada`). `ReaccionesSuelo3D.sincronizar_hierba` lee el privado `_hf` de la maqueta cada fotograma (`mundo/reacciones_suelo_3d.gd:89`) y copia el enum a mano (`FASE_ARDIENDO = 3`, `FASE_CENIZAS = 4`, l. 25-26).
4. **El «preso en hielo» de los goblins lo lleva la magia.** `Lanzador3D.atrapar` hace `g.set("congelado", …)` y `set_meta("preso_hielo")` (`lanzador_3d.gd:320-321`), sin pasar por `Combate3D`.

**Estados que no caducan o transiciones que faltan**
5. **`EstadosSuelo3D.avanzar()` (l. 158) solo lo llama `herramientas/prueba_estados_suelo.gd`.** Con `DURA` a 0, **la `mojada` del suelo no se seca nunca**. Un agua en el minuto 1 y otra en el minuto 10 sobre la misma casilla la hielan: la regla «dos aguas hielan» acumula sin límite de tiempo.
6. **La hierba con escarcha se ve helada 20 s, pero para el juego solo está «mojada» 8 s** (`hierba_3d.gd:227-228` frente a `prueba_test2.gd:930`). Además, `_mojada` usa `Time.get_ticks_msec()` (reloj de pared) y `Hierba3D` usa el reloj de juego. Con el grimorio abierto (`time_scale` 0,3), la protección contra el fuego se acaba mucho antes de que la hierba deje de verse mojada.
7. **`segada` no la pone nadie en el juego.** Solo la ponen las pruebas, aunque `estados_suelo_3d.gd:22-23` dice que la pone el fuego. El rastrojo (`marcar_segada`, `prueba_test2.gd:4647`) no sale nunca jugando, y `_apagar` (l. 4779) depende de él.
8. **`CENIZAS` no tiene salida temporal.** Una casilla en cenizas lo es para siempre, salvo que le caiga agua o hielo, que la devuelven a FINA (`prueba_test2.gd:4703-4704`). Es coherente con la idea de rastrojo, pero no está escrito como tabla.
9. **La lava escribe `quemada` a mano** (`objetos/lava_3d.gd:167`), sin pasar por `TRANSICIONES`, y no la quita al enfriarse (`_enfriar`, l. 302-313). Tampoco emite reacción: solo la señal `enfriada` y VFX y sonido directos (l. 311-312).
10. **Reglas escritas solo en ramas `if`:** el rayo en la hierba se salta PRENDIENDO (`prueba_test2.gd:4697-4699`), pero en `Reactivo3D` el rayo prende lo inflamable y no enciende las fuentes de fuego (`objetos_3d.gd:427` frente a `:441`). Son tres criterios distintos para la misma pregunta: ¿el rayo prende?

**Papeles**
11. **Los papeles no se combinan.** `Reactivo3D.on_spell_hit` y `spell_reacts` salen con `return` tras el primer papel que tienen: `objetos_3d.gd:426-452` y `462-478`. Una pieza `inflamable + activable` o `fuente_fuego + recibe_agua` no hace la segunda cosa. Es lo contrario de «una variante = sumar o quitar papeles».
12. **`conduce` y `congelable` siguen solo declarados** (`objetos_3d.gd:110-111`, únicos usos en el repo). `apaga` está al revés que en EoW: aquí significa «se deja apagar» (l. 107); en EoW es el emisor que apaga (Freezard, ZolWater).
13. **El vocabulario de papeles está copiado** en `Escudo3D` (`enemigos/escudo_3d.gd:52`, `PAPEL_INFLAMABLE`, `PAPEL_BLOQUEA`).
14. **Hay 11 implementaciones de «arder»:** Reactivo3D, Cuerda3D, Barril3D (mecha), Enredadera3D, TroncoPuente3D, Lava3D, `BarreraFuego` (clase interna de `lanzador_3d.gd:2899`), hierba `_hf`, Escudo3D, `Combate3D.quemando` y la flecha (`combate_3d.gd:1185`). La lava enciende por duck typing `is_lit` y con un caso especial para el tipo `Barril3D` (`lava_3d.gd:361-364`).

**Reacciones y señales**
15. **Hay dos catálogos con nombres distintos.** `Combate3D.REACCIONES` = quemado, mojado, congelado, electrocutado, empujado, aturdido, cae_al_agua (`combate_3d.gd:142`). `Mundo3D.REACCIONES` = prendido, apagado_agua, …, hundido (`mundo_3d.gd:38`). La prueba del contrato y la tabla de VFX no hablan el mismo idioma.
16. **`apagado_viento`** está en el catálogo y en la tabla de VFX, pero **no lo emite nadie**. El viento nunca apaga: lo dice `objetos_3d.gd:576`.
17. **`consumido` mal empleado en enemigos.** Cuando a un goblin se le acaba la quemadura solo, se emite `consumido` (`combate_3d.gd:718`). La excepción del goblin pinta `ceniza` (`reacciones_vfx_3d.gd:54`), así que sale una bocanada de ceniza de un goblin vivo. Falta un nombre del tipo «se apaga solo».
18. **El hielo que apaga a un goblin se avisa como `apagado_agua`** (`combate_3d.gd:510`).
19. **El preso en hielo no es simétrico.** Al entrar no se avisa `congelado` (`lanzador_3d.gd:320`). Si se suelta por `_soltar_preso` (l. 350, `congelado = 0`), no se avisa `derretido`. Solo se avisa si caduca solo (`combate_3d.gd:744-745`).
20. **`Mundo3D.impacto` no es un catálogo cerrado.** Lleva elementos y también `hundido` (`combate_3d.gd:1976`, que **además** emite la reacción `hundido` en la l. 1977: dos avisos para un mismo hecho), `hielo_roto` (`lanzador_3d.gd:297`) y `vapor` (`lanzador_3d.gd:2068`).
21. **Lento, interrupción y veneno cambian el estado sin avisar** (`combate_3d.gd:500-503, 526-530`). Las 10 piezas con script propio que reaccionan a elementos no emiten **ninguna** reacción.
22. **`tipo_de` toma cualquier enemigo por «goblin»** (`reacciones_vfx_3d.gd:102`): el elemental, el gatopedro y el loberno.

**Lógica → presentación (al revés)**
23. **El estado del suelo lo dispara el VFX.** `Vfx3D.impacto` (`presentacion/vfx_3d.gd:2005-2102`) se conecta a `Lanzador3D.al_impactar` (`jugador/jugador_3d.gd:160-162`) y a `PruebaTest2._al_impactar` (`prueba_test2.gd:1145`). De ahí sale `Mundo3D.aplicar_accion`. La cabecera de `lanzador_3d.gd:31-33` lo documenta. Es la dirección contraria a EoW.
24. **Efectos dobles** (tabla + llamada directa en el mismo cambio):
    - `Reactivo3D._apagar`: `apagado_agua` (pinta `apagar_vapor`) + `fx.vapor` (`objetos_3d.gd:576` y `581`).
    - `_apagar_fuente`: reacción + `fx.ceniza` (l. 742 y 747).
    - `_encender`: `prendido` (pinta `llamarada`) + `fx.chispazo` (l. 721 y 730).
25. **VFX puntuales llamados desde la lógica** (sin contar llamas ni chispas de estado continuo, ni las formas del hechizo):

    | carpeta | puntuales | dónde |
    |---|---|---|
    | `objetos/` | 21 | `objetos_3d.gd` 581, 590, 689, 730, 747, 885, 886, 1183, 1374 · `emisor_rayo` 181 · `lava` 311 · `muro_agrietado` 304, 320 · `pared_hueca_pulso` 275 · `puente_reactivo` 108 · `recolectable` 126 · `rompible` 231 · `surtidor` 127, 144, 249 · `tronco_puente` 186 |
    | `magia/` | 3 | `lanzador_3d.gd` 1726, 2295, 2930 |
    | `escenas/` | 4 | `bosque_01_3d` 512 · `bosque_01_v01_3d` 654 · `bosque_3d` 335 · `jugabilidad_3d` 570 |
    | `enemigos/` | 2 | `combate_3d.gd` 692, 693 (sensación de golpe) |
    | `nucleo/`, `mundo/` | 0 | — |

    Total: **30**. Además hay **12** de estado continuo (llamas o chispas que viven mientras dura el estado) en `objetos/`.

**Partida**
26. **Flags y misiones se guardan pero no se cargan.** Se guardan en `escenas/jugabilidad_3d.gd:475-476`, y ningún archivo del juego llama a `Flags.i().cargar()` ni a `Misiones.i().cargar()` (solo `laboratorios/lab_playtest_eow_3d.gd:791`). `Estado` (oro, mochila, mejoras, frascos) no se guarda, y `Estado.nuevo()` no lo llama nadie. Al cambiar de nivel, `Estado`, `Flags` y `Misiones` siguen vivos porque son estáticos. Lo que sí se pierde son los estados de suelo (`terreno_3d.gd:732` `estados.limpiar()`), el agua y lo que haya en las piezas que no ponen flag.
27. **Nombres de flag incoherentes con `nivel.sala.hecho`.** El segundo trozo a veces es una sala (`santuario`, `camara_a`) y a veces una categoría:
    - `totem`, `elfo`, `goblin`, `alquimista` en `escenas/bosque_01_v01_3d.gd:40-60`;
    - `rotulo` en `presentacion/zonas_3d.gd:141`;
    - `rompible` en `objetos/rompible_3d.gd:125`;
    - el nivel `global` en `objetos/secuencia_cofre_legendario_3d.gd:22`.

    El nivel se llama `bosque01v1` en el código y `bosque1` en la documentación. `Flags.nombre_valido` solo comprueba que haya tres trozos.

**Números escritos a mano en `Combate3D`** (HC3 solo sacó las duraciones)
28. Quemadura de 3,0 de daño cada 0,5 s (`combate_3d.gd:722`); mojado ×0,75 y lento ×0,6 de velocidad (l. 456, 458); rayo sobre mojado ×1,5 con un arco de la mitad de daño a 4,5 u (l. 491-492, 564); hielo sobre mojado +15 (l. 496); `QUEMA_CONTACTO` 3,0 y `ELEMENTAL_QUEMA` 5,0 (l. 128, 31). La misma tabla ya está escrita en un documento (`ESTADOS_SUELO.md` §2), pero en el código son `if`.

**Bloqueos para mapas con varias alturas**
29. **`ReaccionesSuelo3D.aplicar` descarta el agua y el frío en cualquier casilla con `altura_en(c) >= 1`** (`reacciones_suelo_3d.gd:63`), y `ReaccionesAgua3D` hace lo mismo (`reacciones_agua_3d.gd:47`). En un mapa de montaña, casi todo el suelo dejaría de reaccionar.

---

## (C) Propuesta ordenada: 8 cambios para llevar los estados al modelo EoW

Ordenada por desbloqueo: cada paso deja preparado el siguiente.

| # | cambio | archivos | coste | jugada nueva que abre |
|---|---|---|---|---|
| **1** | **Un solo reloj de estados.** `Mundo3D._physics_process` llama a `EstadosSuelo3D.avanzar(dt)`. `DURA` pasa a tener valores reales (por ejemplo mojada 30 s; helada-escarcha 20 s, que hoy está en `Lanzador3D._hielo`). La tabla gana una columna `al_caducar` (helada → mojada, para no perder la regla de `ReaccionesSuelo3D.derretir`). Se borra la parte de hielo de `_avanzar_caducidades` y `ESCARCHA_S` lee de aquí | `mundo/estados_suelo_3d.gd`, `mundo/mundo_3d.gd`, `mundo/reacciones_suelo_3d.gd`, `magia/lanzador_3d.gd` (l. 2244-2296) | **S** | Charcos que se secan (se acaba la helada «diferida»), puzles contrarreloj de casilla y, después, el calor de desierto (`DURA` por región) |
| **2** | **Un vocabulario y un catálogo.** Nuevo `mundo/papeles.gd` con las constantes de papel y el catálogo de reacciones. `Reactivo3D`, `Escudo3D` y `Combate3D` lo usan. `Combate3D.REACCIONES` se renombra a los nombres del mundo (quemado → prendido, cae_al_agua → hundido). Se añaden `se_apaga` (natural), `apagado_frio`, `enfriado` (lava), `explota`, `roto`, `ralentizado`, `envenenado`, `interrumpido`, `atrapado`. `Mundo3D.impacto` queda solo para elementos, y vapor, hielo_roto y hundido pasan a ser reacciones | `mundo/mundo_3d.gd`, `objetos/objetos_3d.gd`, `enemigos/combate_3d.gd`, `enemigos/escudo_3d.gd`, `magia/lanzador_3d.gd`, `presentacion/reacciones_vfx_3d.gd` (encargo al Pipeline: filas nuevas) | **M** | El Pipeline recibe un catálogo cerrado y completo. Se arreglan los bugs 15-22 |
| **3** | **Componente `ReceptorElemental`** (nodo hijo, como `Escudo3D`). Una tabla de filas `{papel, si_tag, desde_estado → hasta_estado, señal, reacción}` sustituye a los 57 `tags.has`. `on_spell_hit` recorre **todas** las filas que encajan, sin `return`: así los papeles se combinan. Se migran barril, cuerda, tronco_puente, enredadera, nexo, lava y muro. `conduce` lo lee `EmisorRayo3D` (el nexo deja de escribir `Terreno3D.conductores` a mano) y `congelable` lo lee `ReaccionesAgua3D` (lo que está en el agua helada) | `objetos/*.gd` (26 piezas, por tandas), nuevo `objetos/receptor_elemental_3d.gd` | **L** | Variantes por suma o resta de papeles: cuerda mojable, barril congelable, tronco que conduce mojado, enredadera ignífuga. Una pieza nueva es una fila |
| **4** | **Lógica → tabla → presentación de verdad.** Se quitan los 30 VFX puntuales de la lógica (lista del bug 25) y los 3 efectos dobles. Cada caso emite su reacción. `ReaccionesVfx3D.EXCEPCIONES` gana fogata, brasero, cuerda, barril, lava, muro, rompible y elemental. A medio plazo, el impacto sobre el suelo nace del `HechizoVivo` (la lógica) y no de `Vfx3D.impacto` | `objetos/*.gd`, `magia/lanzador_3d.gd`, `escenas/bosque*_3d.gd`, `presentacion/reacciones_vfx_3d.gd` (Pipeline), `jugador/jugador_3d.gd:160-162` | **M** | Cambiar cómo se ve o suena algo sin tocar la lógica. Se pueden probar los niveles sin ventana con todas las reacciones contadas |
| **5** | **Estados de personaje en una tabla compartida.** `ESTADOS_PERSONAJE`: `{quemado, mojado, congelado, preso_hielo, aturdido, lento, interrumpido, envenenado, electrificado}` × `{vel_mult, bloquea_ia, daño_tick, anula:[…], reaccion_entra, reaccion_sale}`. Las duraciones siguen viniendo del `Hechizo`, y los números del bug 28 entran en la tabla. `aplicar_estado(nombre, s)` es la única puerta: la usa `Lanzador3D.atrapar`. La **jugadora** recibe la misma tabla (`quemar`, `mojar`, `congelar`) y escucha `flecha_ardiente_impacta` | nuevo `nucleo/estados_personaje.gd`, `enemigos/combate_3d.gd`, `jugador/jugador_3d.gd`, `magia/lanzador_3d.gd:309-358` | **M-L** | La jugadora arde en la hierba o la lava y se apaga en el agua. Se congela en la montaña. Mojada, la electricidad le hace ×1,5 |
| **6** | **La hierba entra en `EstadosSuelo3D`.** Estados `crecida`, `prendiendo` y `ardiendo` (con `cenizas` = `quemada` + `segada`). El autómata se mueve a `mundo/hierba_estado_3d.gd` con su `TRANSICIONES_HIERBA` (incluye rayo → ardiendo y viento → abanicar como filas) y su contagio. `mojada` de la hierba = el estado oficial (8 s en `DURA`): desaparecen `_mojada` y la textura de humedad de `Hierba3D`. El Pipeline solo dibuja | nuevo `mundo/hierba_estado_3d.gd`, `mundo/reacciones_suelo_3d.gd`. Encargo al Pipeline: `prueba_test2.gd` (`_hf` y `_avanzar_estado`) y `hierba_3d.gd` | **L** | Enemigos y jugadora se prenden al pisar hierba que arde (contacto con casilla `ardiendo`). Condiciones `casilla(x,y).ardiendo` o `.crecida`. El rastrojo aparece. Se acaba el bug 3 |
| **7** | **Puzle3D gana los actores que le faltan frente a EoW:** <ul><li>`temporizador dura=<s>`: señales `fin` y `tic`; acciones `iniciar`, `parar`, `reiniciar`.</li><li>`sensor celdas=<lista>`: señales `entra` y `sale`; condición `jugadora.nadando` / `.sobre_hielo` / `.ardiendo` / `.en_aire`.</li><li>Condición `flag.<n>>=k` y acción `flag.sumar(<n>,k)`, que convierte en contadores las flags enteras que `Flags` ya admite.</li><li>`cuando=si(<expr>)`, que salta cuando la expresión pasa a verdadera: es el «activador condicional» de EoW, y `CofrePuzle` ya reevalúa cada 0,2 s.</li></ul> | `escenas/puzle.gd` | **M** | Contrarreloj («llega antes de que la lava vuelva»), puzles de «pisa las 5 losas», reaccionar a que la jugadora nade o arda, y «apaga las tres antorchas» sin un `cuando` artificial |
| **8** | **La partida se guarda y se carga entera.** `Niveles` o el menú llaman a `Flags.cargar` / `Misiones.cargar` y a un `Estado.guardar` / `cargar` nuevo (oro, mochila, mejoras, frascos, consumible). Una regla de nombres comprobable: el segundo trozo es una **sala o zona del mapa**, y las categorías van al tercero (`bosque01v1.claro.totem_fuego_1`). `nombre_valido` puede avisar si la sala no existe en las `; zona` del nivel | `nucleo/estado.gd`, `nucleo/flags.gd`, `nucleo/niveles.gd`, `escenas/bosque_01_v01_3d.gd` (renombrar 21 constantes) | **S** | Continuar partida. Las flags de sala sirven de verdad (hoy se pierden al cerrar el juego) |

Si solo se hacen tres, conviene que sean el **1** (S), el **2** (M) y el **8** (S): arreglan los bugs más visibles con poco coste. El **3** y el **6** son los que más acercan el juego a EoW, pero son L y tocan el Pipeline.

---

## (D) Hoja de ruta de biomas

### Lo que se reutiliza tal cual (o casi)

| pieza existente | uso en biomas | qué le falta |
|---|---|---|
| `EstadosSuelo3D` (tabla `TRANSICIONES`, intensidad, avance, textura) | El estado de la casilla en los tres biomas (barro, nieve, arena…) | **Una segunda textura `textura_b()`**, porque los 4 canales están ocupados (R quemada, G mojada, B helada, A segada). Una columna `clase` en `TRANSICIONES` (la fila solo vale sobre una letra o clase de suelo) y una columna `temp` (mín. y máx.). El cambio 1 (reloj) es requisito |
| `AguaSim3D` (volumen, `helar`, `fijar_nivel`, manantiales, `solidificar_casilla`) | Agua estancada, deshielo, oasis | Parámetros por región: `evapora_u3s` (evaporación ambiental) y `dura_hielo` (hoy la constante de la l. 49) |
| `Lava3D` (volumen que bloquea, se transforma con un elemento y vuelve con `vuelve=`) | Molde para cualquier «charco con estado»: arenas movedizas, ciénaga, brea, nieve profunda | Generalizarlo a `CharcoReactivo3D` con una tabla `{elemento → transforma_en, vuelve}`. Que dañe o hunda a quien entra (reutiliza `Combate3D._hundirse`) |
| Papeles de `Reactivo3D` | Cactus, hongos, matorral seco, carámbanos | Que se combinen (cambio 3) |
| `Enredadera3D` (OCULTA → BROTANDO → VIVA → ARDIENDO → …) | Vegetación que crece en el pantano | Que la dispare una fila de casilla (agua sobre `barro` con semilla), no solo el código |
| `EmisorRayo3D` (pulso cada N s por búsqueda en anchura) | Molde de emisor periódico: géiser, hongo de esporas, ráfaga de viento | Extraer el temporizador y el «a quién llega» como componente |
| `MuroAgrietado3D` + `Rompible3D` | Desprendimientos, costras de sal, hielo quebradizo | Una señal `cae` que bloquea la casilla destino |
| `Zonas3D` (`; zona …` con luz, mezcla, nombre, botín) | Regiones de bioma | **Vive en `presentacion/` (Pipeline)**. La temperatura no puede leerla la lógica de ahí: hace falta un `mundo/regiones_3d.gd` que lea las mismas líneas `; zona` con claves `temp=0..4`, `humedad=`, `viento=dir,fuerza`, `vision=` |
| `ReaccionesSuelo3D` / `ReaccionesAgua3D` | Aplican filas con la temperatura de la región | Quitar el corte por altura ≥ 1 (bug 29) para la montaña |
| `Combate3D.lento`, `_hundirse`, `push` | Barro (lento), arenas (hundido), viento fuerte (push) | Que lo dispare el suelo y no solo un hechizo (cambio 5) |

**Tabla nueva común: `TEMPERATURA`** (en `mundo/regiones_3d.gd`). Es la decisión que `PLAN_BOSQUE_EOW.md` §9.4 dejó para más adelante («no por ahora»):

| temp | agua lanzada | `DURA` mojada | hielo (agua) | fuego en hierba |
|---|---|---|---|---|
| 0 (helado) | se hiela al caer (fila `agua → frio` diferida 1 s) | 0 (no se seca, se hiela) | permanente (`dura_hielo` = 0) | no prende en `nevada` |
| 1 (frío) | normal | 60 s | 40 s | normal |
| 2 (templado, bosque actual) | normal | 30 s | 20 s | normal |
| 3 (cálido) | normal | 10 s | 8 s | contagio ×1,5 |
| 4 (ardiente) | se evapora al caer si no cae en agua (vapor) | 4 s | 5 s | prende sola junto a `emite_calor` |

### Pantano

| qué | tipo | dónde iría | concreto |
|---|---|---|---|
| **barro** | estado de suelo nuevo | `EstadosSuelo3D.TODOS` + canal R de `textura_b()` | Filas: `{agua, con: mojada, clase: "blanda", quita: [mojada], pone: [barro]}`, antes de la fila «dos aguas hielan». `{calor, con: barro, quita: [barro], pone: [endurecida]}`. `{frio, con: barro, quita: [barro], pone: [helada]}`. Efecto en quien pisa: estado de personaje `lento` (tabla del cambio 5) |
| **agua estancada** | región + `AguaSim3D` | `regiones_3d.gd` (`humedad=4`) + `cuenca fijo=` (ya existe en Puzle3D) | Sin corriente (no mueve flotadores ni molinos). Conduce la electricidad (reutiliza `EmisorRayo3D` tal cual). `DURA` mojada = 0 |
| **gas o esporas** | pieza nueva `NubeGas3D` (volumen, `Area3D`) + emisor `HongoEsporas3D` (patrón `EmisorRayo3D`: suelta una nube cada N s) | `objetos/` | Papeles: `inflamable`, `explota` (nuevo: con calor o rayo, la nube deflagra en un radio y avisa al grupo `explosionable`, como el barril), `le_afecta_viento` (nuevo: el viento la desplaza en su cono, lo que da al viento un uso exclusivo). Reacción nueva: `deflagra`. Pieza de mapa: `; pieza h hongo x y cada=6 radio=1.5` |
| **niebla** | región, no casilla | `regiones_3d.gd` `vision=0.5` | `Combate3D` multiplica `RADIO_DETECCION` (5,75 u) por `vision`. Un hechizo de viento abre un claro N s (estado de región temporal). La presentación ya tiene la niebla de los fosos |
| **vegetación que crece** | estado de suelo `semilla` (el mapa la pone por letra) + `Enredadera3D` | `EstadosSuelo3D` + fila | `{agua, con: semilla, quita: [semilla], pone: [], efecto: "brota"}`. El efecto `brota` lo atiende `ReaccionesSuelo3D`, que coloca una `Enredadera3D` en la casilla (hace de puente o de muro). Papel `inflamable` (cambio 3): el fuego la quita |
| **sanguijuela o planta carnívora** (opcional) | enemigo con papeles | `Combate3D` + papeles | Sin papel `inflamable`, con `apaga` de emisor (como el ZolWater de EoW): **es la diferencia de papeles, sin código nuevo** |

### Montaña

| qué | tipo | dónde iría | concreto |
|---|---|---|---|
| **nieve** | estado de suelo `nevada` (lo pone el mapa) | `EstadosSuelo3D` + canal G de `textura_b()` | Filas: `{calor, con: nevada, quita: [nevada], pone: [mojada], efecto: "vapor"}`. `{viento, con: nevada, quita: [nevada], pone: []}`: **el viento barre la nieve** (primer uso del viento en el suelo; hoy el rayo, el viento y la tierra no tienen filas). `{agua, con: nevada, pone: [helada]}`. Quien pisa: `lento` suave y huellas (el Pipeline ya tiene `_tex_pisado`) |
| **hielo permanente** | región `temp=0` + `Lanzador3D.hielo_permanente` (ya existe, `lanzador_3d.gd:126`) | `TEMPERATURA` | `dura_hielo = 0`. El fuego lo funde y **vuelve a helarse** a los N s: fila `{calor, con: helada, …, vuelve: 8}`, una columna nueva copiada del `vuelve` de `Lava3D` |
| **frío que congela el agua lanzada** | regla de región | `ReaccionesAgua3D.aplicar` consulta `Regiones3D.temp(c)` | Con temp 0, el agua lanzada al suelo deja `mojada` y en 1 s pasa a `helada` (se programa con el reloj del cambio 1); sobre el agua de la simulación, `helar` inmediato. Jugada: **el agua hace puentes de hielo sin hechizo de hielo** |
| **viento fuerte** | región `viento=dir,fuerza` | `regiones_3d.gd` + papel `le_afecta_viento` | Cada 0,5 s hace `push()` a la jugadora, a los goblins, a los flotadores y al gas. Inclina el contagio del fuego (reutiliza el cono de `_contagiar(viento)` y `_abanicar`). Un muro de tierra hace de abrigo (consulta `Terreno3D` en la dirección del viento) |
| **desprendimientos** | pieza nueva `Desprendimiento3D` | `objetos/` (base `MuroAgrietado3D`) | Lo disparan la tierra, una explosión o un `sensor` (cambio 7). Las rocas caen en `celdas=` y las bloquean (`Terreno3D.bloquear_celda`). Papel nuevo `aplasta` (en EoW, `mFallAttack`): daña a quien esté debajo. Reacción `roto`. Pieza: `; pieza r desprende x y celdas=… golpes=1` |
| **altura de 2 niveles o más** | `Terreno3D` | `alturas` / `permanentes` (enteros, ya sirven) | Hace falta D1 (`cabe` / `ocupado`, que sigue pendiente). Hay que quitar el corte por altura de las reacciones (bug 29) y añadir daño por caída de más de un nivel en `Jugador3D`. `Caminos3D` ya sube o baja ±1 |
| **carámbano** | `Reactivo3D` tipo `caramelo_hielo` | papeles | `[congelable, rompible_calor]`: con calor gotea y cae (puente o arma). Es la diferencia de papeles |

### Desierto

| qué | tipo | dónde iría | concreto |
|---|---|---|---|
| **arena** | estado de suelo `arenosa` (lo pone el mapa) | `EstadosSuelo3D` + canal B de `textura_b()` | `{agua, con: arenosa, pone: [compacta]}` (se puede pisar y cruzar arenas). `{calor, con: compacta, quita: [compacta]}`. `{viento, con: arenosa, efecto: "polvareda"}`: nube que tapa la visión 3 s. `compacta` caduca con `DURA` según la temperatura |
| **arenas movedizas** | pieza nueva `ArenaMovediza3D` | `objetos/` (molde `Lava3D`) | Quien entra se hunde despacio (`Combate3D._hundirse` ya existe; la jugadora necesita el cambio 5). Con agua pasa a `compacta` y se puede pisar unos segundos. Con hielo pasa a `helada`. Reacción `hundido` |
| **calor que evapora** | región `temp=4` | `TEMPERATURA` + `AguaSim3D.evapora_u3s` | El agua lanzada al suelo no deja charco: vapor salvo que caiga en agua. La simulación pierde volumen por casilla expuesta. El hielo dura 5 s. Jugada: **el agua es un recurso** (oasis, tinajas) |
| **tormenta de arena** | región con ciclo | `regiones_3d.gd` + `temporizador` (cambio 7) | Alterna calma y tormenta (en EoW, un ciclo de 30-90 s). En tormenta: `vision=0.3` y `viento=…`, y los hechizos de fuego se apagan al viajar (fila de proyectil). Un muro de tierra protege. Flag de región para los puzles: `si=region.tormenta` |
| **espejismo** | pieza nueva `Espejismo3D` | `objetos/` + papel `ilusorio` | No bloquea ni se puede pisar (un puente falso, un cofre falso). Con agua o viento se deshace y deja ver lo real. Condición `espejismo.visto`. La lógica solo dice `ilusorio`; el brillo es cosa del Pipeline |
| **cactus** | `Reactivo3D` tipo `cactus` | `PAPELES_POR_TIPO` | `[inflamable, pincha]`. `pincha` es un papel nuevo: daño por contacto a quien lo toca, que reutiliza `toca_punto` del contacto de fuego. Arde despacio (fila en `COMBUSTIBLES`). Mojado, crece una vez y da agua (`recibe_agua`): ingrediente o tinaja natural |
| **tierra que se endurece** | fila + bloque de tierra | `TRANSICIONES` + `Lanzador3D._bloques` | `{calor, con: barro, pone: [endurecida]}` en el suelo. Y el **bloque de tierra del jugador**: con calor encima, `resta = INF` (ya no caduca a los 25 s). Hoy el bloque no es receptor: necesita el cambio 3 (un `ReceptorElemental` en el bloque, que ya es un `Area3D` del grupo `peso`). Jugada: **escaleras y puentes permanentes cociendo tierra con fuego** |

### Orden razonable

Cambio 1 (reloj) → `mundo/regiones_3d.gd` con `TEMPERATURA` → `textura_b()` + columnas `clase` / `temp` en `TRANSICIONES` → cambio 3 (papeles combinables) → `CharcoReactivo3D` (de `Lava3D`) → el bioma.

Con eso, **pantano y desierto salen casi todo con filas y papeles**. **La montaña pide además D1 y quitar el corte de altura**, así que es el bioma más caro.
