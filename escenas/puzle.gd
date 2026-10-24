class_name Puzle3D
extends Node

## PUZLES DECLARADOS EN EL MAPA (Fase 12.3, 16/10, Juego). Un nivel describe sus puzles en las líneas «;» de su `mapas/<Nivel>.txt`,
## sin código: `HorneadorNivel.leer_mapa` ya las ignora (solo lee `azar_suelo` y `giro`), igual que `TerraFina3D.leer_alturas` relee las suyas.
##
## CÓMO SE ENGANCHA: como nodo hijo de la escena del nivel (nombre «Reglas», como TerraFina3D) o, si el nivel ya tiene sus reglas,
## como segundo hijo («Puzles»). `_ready` espera un fotograma (la maqueta ya está montada: simulación de agua, tinaja, jugador) y
## llama a `iniciar(get_parent())`. Un nodo de reglas propio (el laboratorio) puede crearlo con `Puzle3D.new()` y llamar él a `iniciar`.
## Lee el nivel de `mundo.nivel`; si no lo tiene, `iniciar(mundo, "NombreDelMapa")`.
##
## ---------------------------------------------------------------------------------------------------------------------
##  GRAMÁTICA  (una instrucción por línea; las que no empiezan por «pieza» ni «puzle» son comentarios)
## ---------------------------------------------------------------------------------------------------------------------
##   ; pieza <id> <tipo> <x> <y> [clave=valor …]
##   ; puzle <nombre> cuando=<id>[.<señal>] [si=<expresión: ver CONDICIONES>] hace=<id>.<acción>[(args)] [y=<id>.<acción>[(args)] …]
##
## <id> y <nombre>: letras, cifras y «_» (sin espacios ni puntos), únicos en el archivo. <x> <y>: casilla del mapa (columna, fila).
## Los valores no llevan espacios. Lista de casillas: `x,y` o un rectángulo `x0,y0..x1,y1`, y varios unidos con `+`
## (`celdas=4,10..4,12+1,12..2,12`). Booleanos: si | no (también true/false, 1/0).
##
## PIEZAS (tipo → claves, entre paréntesis el valor por defecto) y qué clase de `objetos/` es:
##   pulsador   modo=magia|agua|presencia (magia)  rearme=<s> (0)  modelo=cueva          Pulsador3D: botón, pulsador de agua o placa (modelo=cueva: la placa de piedra de la Cueva)
##   compuerta  abierta (no)  abre_con=fuego|agua|hielo|rayo|explosion  cierra_con=…  estrecha (si)  vertical (si)   Compuerta3D
##   nivel      objetivo=<u> (0.45)  banda=<u> (0)  invertido (no)                    NivelAgua3D: lee la profundidad de su casilla
##   molino     umbral=<u/s> (0.3)  vertical (si)                                     Molino3D
##   barril                                                                          Barril3D
##   nexo                                                                            NexoRayo3D (pila que conduce mojada)
##   puerta     modelo=llave (losa)                                                  losa que bloquea su casilla hasta abrirse (PuertaPuzle). `modelo=llave`: el marco
##                                                                                   de piedra y la hoja con herrajes (arte/piezas/puerta_llave_*), girados con la pared
##   emisor                                                                          EmisorRayo3D: la fuente eléctrica (letra «e»)
##   cuenca     celdas=<lista> (la propia x,y)  nivel=<u> (no llena)  fijo=<u>|si     abre casillas c o canal al agua; `nivel` las llena a esa
##                                                                                   profundidad; `fijo=<u>` mantiene ese nivel (un desagüe);
##                                                                                   `fijo=si` lo mantiene en `nivel`
##   manantial  caudal=<u³/s> (0.5)  volumen=<u³> (0 = infinito)  rampa (si)  inicia (si)  celdas=<lista>
##              En x,y echa agua. `rampa=si`: arranque suave de ReaccionesAgua3D.ARRANQUE_CAUCE (abre también las `celdas`; x,y va la primera);
##              `rampa=no`: echa el caudal de golpe. `inicia=no`: espera a la acción `abrir_cauce`. `sin_piedra=si` (24/10): no dibuja la pieza de canal de ruinas de
##              sus `celdas` (el agua corre igual por el canal, a ras de suelo: la cascada de la Cueva, sin «puente»)
##   tinaja     canal=<lista>                                                         la tinaja de la MAQUETA (letra «u»), solo se enlaza por casilla;
##                                                                                   `canal` es el cauce que llena (la primera casilla recibe el agua)
##   totem                                                                           el tótem de la MAQUETA (letra «i»), enlazado por casilla
##   decorado   modelo=<pieza> (obligatoria)  giro=<grados> (0)  escala=<x> (1)         24/10: una pieza de ADORNO sin mecánica en su casilla (geoda_resonante, estalagmita_resonante…). No bloquea
##   brasero    modelo=cueva (24/10): el modelo `brasero_cueva` en vez del del Bosque (mismo reactivo; `Reactivo3D.cambiar_visual`)
##   brasero    rele=<id> espera=<s> (1.5) dura=<s> (6)  luz=<x> (1)               el brasero de la MAQUETA (letra «T»), enlazado por casilla. Sin claves es
##                                                                                   el de siempre. Con `rele` (el id de OTRO brasero), al encenderse enciende a ése
##                                                                                   `espera` s después y él se apaga a los `dura` s; `dura` sin `rele` = se apaga solo.
##                                                                                   `luz=<x>` (24/10): la llama alumbra x veces más (en la Cueva, `luz=2.2`). Un pulso de FUEGO lo enciende
##   seto       mojable (no)                                                         el seto de la MAQUETA (letra «z»), enlazado por casilla. `mojable=si`: el agua lo
##                                                                                   moja y no prende en Reactivo3D.T_MOJADO s (el cortafuegos)
##   contador   de=<lista de casillas>  minimo=<n> (todos)                           ContadorReactivos3D: cuenta lo que arde (`is_lit`) en esas casillas (braseros,
##                                                                                   fogatas, setos…); rótulo «ENCENDIDAS n/m» sobre su casilla
##   cuerda     sostiene=<id>                                                        Cuerda3D: arde 1 s y se rompe; lo que sostiene (una compuerta o un puente) cae
##   vigia      de=<lista de casillas> (obligatoria)  flag=<nombre>                  VigiaPuzle (C3): vigila a los Combate3D cuya casilla de PARTIDA (`casa`) está en `de`
##              (un rectángulo `x0,y0..x1,y1` es "la zona"). Cuando han caído todos (muertos o hundidos) emite `todos_derrotados` y, si hay
##              `flag`, la pone. Mientras no haya encontrado ninguno no se da por cumplido (una lista que no casa con nadie avisa)
##   cerrojo    celdas=<lista> (obligatoria)  sala=<lista>  hasta=<flag>             CerrojoPuzle (C3): puertas de sala (PuertaPuzle, una por casilla de `celdas`). Nacen
##              ABIERTAS; se cierran cuando el jugador pisa una casilla de `sala` (y no está en la puerta). Se abren con la acción `abrir`
##              y ya no vuelven a cerrarse. `hasta=<flag>`: con esa flag puesta (al montar o después) ni se cierra ni se queda cerrado.
##              Sin `sala` solo cierra la acción `cerrar`. El rectángulo de `sala` NO debe incluir las `celdas` de las puertas
##   lava       celdas=<lista> (la propia x,y)  vuelve=<s> (0)                       Lava3D (bloque 3 EoW): charco de lava que no se pisa y prende lo de al
##              lado; agua o hielo lo ENFRÍAN en roca (la casilla y sus 4 vecinas). `vuelve` > 0: la roca vuelve a ser lava a los `vuelve` s. El agua cuenta aunque sea la
##              flecha de agua REAL (la que se para en el borde de la lava y deja agua en la orilla de la simulación): `Lava3D.CADA_AGUA`
##   seta       variante=roja|azul|marron (la que toque por casilla)  rebrota=<s> (0)  madura=si (no)   Recolectable3D (la Cueva): setas que se cogen con E y dan
##              un ingrediente; un elemento lanzado antes las transforma (Objetos.PLANTAS). Sin variante se intercalan por casilla.
##              `madura=si` (24/10): un PULSO que la toca la hace brillar y la MADURA a `seta_resonante` (si aún no la había transformado un elemento)
##   alga, basalto   coge_si=<expresión de si=>  rebrota=<s> (0)                         Recolectable3D con CONDICIÓN (docs/MATERIALES_CUEVA.md): solo se ve y se coge mientras se cumple
##              `coge_si` (alga: casilla(x,y).helada · basalto: casilla(x,y).roca). Si la condición se pierde, desaparece; si vuelve, reaparece (salvo si ya se cogió)
##   muro       golpes=<n> (2)                                                       MuroAgrietado3D (bloque 2 EoW): bloque de piedra que tapa su casilla;
##              lo rompen `golpes` impactos de tierra o una explosión (barril). Se deshace por celdas y libera la casilla
##   cofre      aparece_si=<expresión de si=> (siempre)  abierto=<flag>  modelo=legendario|epico   CofrePuzle (C3): un Cofre3D (arte/piezas/cofre.tscn) en x,y. Con `abierto` ya puesta al
##              montar nace ABIERTO; si no, oculto hasta que `aparece_si` se cumpla (se reevalúa cada 0,2 s y al cambiar cualquier flag) y
##              entonces APARECE cerrado (con efecto; si ya se cumplía al montar, sin efecto). El jugador lo abre con E a ≤ 2,7 u; al acabar
##              de abrirse pone la flag `abierto`. Sin `aparece_si` nace cerrado
##   cristal    cada=<s> (3)  alcance=<casillas> (12)                                CristalPulso3D (el pulso resonante, PLAN_PULSO_RESONANTE §4): EMISOR. Late (suelta un Pulso3D desde su
##              casilla) cada `cada` s (0 = solo al golpearlo) y cuando le da un hechizo (el pulso lleva su elemento). Modelo `cristal_resonante`. Bloquea su casilla
##   veta       celdas=<lista> (la propia x,y)  enlaces=<lista>  aturde=<s> (0)  mineral=si (no)   VetaPulso3D: CONDUCTOR del pulso. Una losa por casilla con las vetas de `arte/suelo_meshy/veta_mineral.png`
##              (máscara × color del pulso por emisión, casilla a casilla) y un hilo guía entre casillas vecinas. No bloquea; la rejilla de vetas la conoce solo el pulso.
##              Fase 3 (24/10): `enlaces` = HUECOS de la veta (C2), casillas que solo conducen con un bloque de tierra encima (hechizo de tierra: el «bloque de enlace»); `aturde=<s>` deja sin
##              sentido, ese tiempo, a quien pisa la veta cuando pasa el frente (C4); `mineral=si` la hace reactivo de tierra: un hechizo de tierra suelta un `mineral_veta` (una vez)
##   columna    golpes=<n> (2)  cae=n|e|s|o (s)                                      MuroAgrietado3D como COLUMNA (fase 3, C2): modelo `columna_agrietada`; la rompen los PULSOS (cada uno la agrieta, al
##              `golpes`-ésimo CAE hacia `cae`, deja su casilla libre y se deshace); la tierra y los hechizos no le hacen nada. Bloquea su casilla mientras está en pie
##   estalagmita  cae=n|e|s|o (la opuesta de por donde llegó el pulso)  flag=<nombre>    EstalagmitaPulso3D (24/10, C4): REACTIVO del pulso. El 1.er pulso que la toca (por su casilla o la de la veta de al lado) la hace vibrar;
##              el 2.º la tira hacia `cae`: aturde 3 s y daña 25 a los Combate3D de la casilla donde cae (a la jugadora no) y queda `estalagmita_rota`, un escombro bajo que NO bloquea. Con `flag`
##              se acuerda de que cayó (la pone al caer; si ya está puesta nace caída). Señal `cae`; condición `caida`|`en_pie`. No bloquea su casilla (adorno que se rodea)
##   estatuas   celdas=<lista>  secuencia=<e1,e2,…>  flag=<nombre>                  EstatuasPulso3D (fase 3, secreto de C1): una estatua de piedra por casilla de `celdas`; piden pulsos de ESOS elementos, EN ESE
##              ORDEN (las dos listas, igual de largas: `secuencia=fuego,hielo,fuego`); un fallo las apaga todas; al acabar ponen `flag`. Cada una lleva a sus pies el color del elemento que pide
##   prisma     dir=n|e|s|o (n)                                                      PrismaPulso3D (fase 2): MODIFICADOR. Reemite el pulso que le llega por la casilla que mira (`dir`), con su
##              elemento, su dueño y el alcance que le quedaba; se gira 90° (horario) con un golpe de hechizo o con E. Bloquea su casilla
##   pared_hueca  flag=<nombre>  mira=n|e|s|o                                       ParedHuecaPulso3D (fase 2): REACTIVO. Suena hueca (eco) con cualquier pulso y SE ABRE solo con uno del
##              JUGADOR (el glifo ᚱ). Bloquea su casilla mientras está cerrada; `flag` se pone al abrirse. `mira`: hacia qué sala mira (grietas y luz) si tiene sala a los dos lados
##   (cofre)    abre_si=<expr> (siempre)  glifo=<id del libro>                        `abre_si`: hasta que se cumpla el cofre está sellado (E avisa y no abre). `glifo=raido`: abrirlo da ese
##              glifo con la SECUENCIA del cofre legendario (SecuenciaCofreLegendario3D) y lo desbloquea en el libro
##   receptor   elemento=fuego|agua|hielo|rayo|tierra|viento (cualquiera)  flag=<nombre>  rearme=<s> (0)   ReceptorPulso3D: se ACTIVA al llegarle un pulso (de ese elemento, si lo
##              pide) y se queda activo; pone `flag` con la forma de siempre (nivel.sala.hecho). `rearme` > 0: se apaga solo. Modelo `receptor_runico`. Bloquea su casilla
##   jarron, caja  botin=oro|pocion|nada|zona|<objeto> (oro)  cantidad=<n> (la de la zona)  alto=si (jarron_alto)  pequena=si (caja_pequena)  celdas=<lista>  modelo=caja (en un jarron)   Rompible3D (mapas abiertos, 23/10): un jarrón o una caja
##              que tapa su casilla y se ROMPE con cualquier golpe (un hechizo, un empujón de viento, una explosión; `golpear()` para el cuerpo a cuerpo que aún no hay), deja restos
##              y suelta su BOTÍN según la ZONA donde está (`Rompible3D.BOTIN_ZONA`: bosque, ruinas, cueva…). `botin=oro` da monedas, `pocion` una poción, `<objeto>` cualquier id de
##              `Objetos.DATOS`, `nada` no da nada, `zona` tira el perfil de la zona (nada/oro/poción); `cantidad` fija cuánto. `celdas` pone uno en cada casilla (<id>, <id>_2, <id>_3…).
##              No reaparece: la flag `<nivel>.rompible.<id>` sobrevive a cambiar de nivel y a guardar
##   salida     a=<Nivel>:<entrada> (o escena=<Nivel o escena> entrada=<nombre>)  celdas=<lista> (la propia x,y)  modo=pisar|usar (pisar)  marca=si|no (si)  modelo=<id> (aún no se dibuja)     SalidaNivel3D (transición entre niveles): al pisar sus casillas (o con E,
##              `modo=usar`) carga <Nivel> (tabla `Niveles.ESCENAS`) y deja a la jugadora en su entrada con ese nombre, con fundido a negro. Nace desarmada y se arma al salir de sus casillas.
##              Si el nivel no existe todavía, avisa en consola y en pantalla y no hace nada
##   entrada    mira=n|e|s|o (hacia dentro)                                          EntradaNivel3D: el punto de llegada de otro nivel; el ID de la pieza es su nombre (`a=Cueva:desde_bosque`).
##              La jugadora aparece en su casilla mirando a `mira` o, sin ella, hacia donde hay más suelo libre seguido. Es también su punto de reaparición. No dibuja ni bloquea
##   cofre (da=)  da=<objeto>:<n>[+<objeto>:<n>…] (`oro` es oro)        Al acabar de abrirse da ESE botín una vez (oro y lo que quepa en la mochila; avisa). Un cofre que nace abierto no da
##   vigía con la sala ya limpia: si su `flag` está puesta al montar, sus enemigos (los de `de=`) NO aparecen: no se repueblan al volver de otro nivel ni al cargar partida
##   puerta (con llave)  llave=<flag>  gasta=si|no (no)  abierto=<flag> (o flag=<flag>)          La puerta pide la llave DE VERDAD: con `llave` solo se abre si esa flag está puesta Y la jugadora está delante (la toca o
##              pulsa E a ≤ PuertaPuzle.ALCANCE_USAR); sin la flag, tocarla o pulsar E avisa «Hace falta una llave». `gasta=si` quita la flag al abrir (la llave se gasta); `abierto=<flag>`
##              recuerda que se abrió (con ella puesta nace abierta). Sin `llave`, la puerta es la de siempre (la abre una regla)
##

## SEÑALES (`cuando=<id>.<señal>`; sin señal vale la primera de cada fila):
##   pulsador   pulsado | soltado           compuerta  abierta | cerrada          nivel   alcanzado | perdido
##   molino     girando | parado            nexo       conduce | corta            barril  explota
##   puerta     abierta | cerrada           totem      activado                   tinaja  agua_llega
##   emisor     descarga
##   brasero    encendido | apagado          contador   todos | no_todos            cuerda  rota
##   seto       consumido
##   vigia      todos_derrotados             cerrojo  cerrado | abierto            cofre   aparecido | abierto
##   muro       roto                         lava     enfriada | apagada        seta     recogida
##   cristal    late                         receptor activado | apagado   prisma gira | emite   pared_hueca abierta | eco
##   jarron, caja  roto                      salida   usada             columna cae    estatuas completa | falla | acierta
## CONDICIONES (`si=<id>.<cond>`: la regla solo actúa si en ese momento se cumple):
##   compuerta/puerta  abierta | cerrada    nivel  alcanzado | perdido     nexo    conduce | corta    molino  girando | parado
##   barril  explotado | encendido | entero    pulsador  activo | libre
##   brasero apagado | encendido   contador  todos | no_todos   cuerda  rota | entera   seto  ardiendo
##   vigia  todos | quedan     cerrojo  cerrado | abierto     cofre  oculto | cerrado | abierto     muro  roto | entero     lava  activa | apagada     seta  recogida | en_suelo
##   receptor  activo | libre     pared_hueca  abierta | cerrada     jarron, caja  roto | entero     columna  caida | en_pie     estatuas  completa | pendiente
##
## CONDICIONES COMPUESTAS (C2, 21/10). `si=` es una EXPRESIÓN de términos:
##   término    <id>.<cond> (de arriba) | flag.<nombre> | casilla(x,y).<estado>
##   «!»        delante de UN término lo niega:   si=!k.abierta     si=!casilla(3,4).mojada     si=!flag.bosque1.s3.placa
##   «+»        Y:   si=a.abierta+b.encendido            (las dos a la vez)
##   «|»        O:   si=a.abierta|b.encendido            (basta una)
##   Precedencia: Y antes que O, SIN paréntesis. `a+b|c` = (a Y b) O c;   `a|b+c` = a O (b Y c);   `!a+b` = (NO a) Y b.
##   Todo junto:  si=casilla(2,5).mojada+casilla(3,5).mojada+casilla(4,5).mojada+!br.encendido
##                ("abre si las tres casillas están mojadas y el brasero está apagado" — o `br.apagado`, que da igual)
##   casilla(x,y).<estado>   estado = mojada | helada | quemada | electrificada | segada (EstadosSuelo3D, B1) | agua (Terreno3D.es_agua) | roca (lava enfriada que aún
##        no ha vuelto a ser lava: Lava3D.es_roca).
##        La coma de «casilla(3,4)» es de la casilla: SOLO «+» y «|» separan términos. Sin espacios. No hace falta que haya una pieza
##        en esa casilla. Se lee en el momento del disparo (si la casilla se moja DESPUÉS, la regla no se vuelve a evaluar sola: la
##        dispara su `cuando=`; para «cuando se moje la última» usa un pulsador/contador que dispare, o un `cuando` que ocurra después).
##   Con una sola condición de pieza sin «!» la regla sigue guardando `si_id`/`si_cond` (las pruebas viejas); la expresión entera
##   está siempre en `si_expr` (lista de grupos O, cada uno una lista de términos Y).
##   AVISOS (la línea se ignora y sale en `avisos`; NUNCA se abre "a medias"): `si=a+` o `si=+a` o `si=a||b` (separador sin condición),
##   `si=!` o `si=!!a.abierta` (el «!» va delante de UNA condición), `casilla(3.mojada` / `casilla(a,4).mojada` / `casilla(3,4)mojada`
##   (casilla mal escrita), `casilla(3,4).mojadaa` (estado desconocido: salen los que valen), id de pieza o condición que no existen.
##
## PLANTILLA `$` (C2): para no escribir una regla por puerta. En `si=` y en `hace=`/`y=`, `$…` se sustituye, al leer, por datos de la
## pieza que DISPARA la regla (`cuando=<id>`; con `cuando=flag.…` no hay pieza y `$` da aviso):
##   $id        el id del disparador            $x  $y     su casilla
##   $1 $2 …    los valores de sus claves, en el orden en que las escribiste en su línea `pieza` (sí/no para los booleanos; en una
##              lista de casillas, su primera casilla «x,y»). Una clave de tipo id (rele=, sostiene=) es, pues, el id de OTRA pieza.
## Ejemplo: «; pieza br brasero 5 5 rele=pu» y «; puzle abre cuando=br.encendido si=!casilla($x,$y).mojada hace=$1.abrir» equivale a
## «… si=!casilla(5,5).mojada hace=pu.abrir»: copiando la pareja pieza+regla y cambiando la clave, cada brasero abre SU puerta sin tocar
## la regla (la regla se queda con la misma forma, sólo cambias `rele=`). `$` desconocido ($7 sin 7 claves, $z) = aviso y regla ignorada.
## Forma mínima: la regla sigue siendo UNA por disparador (no hay `cuando=` con comodín); lo que se ahorra es reescribir sus ids y casillas.
## ACCIONES (`hace=<id>.<acción>`, con argumentos entre paréntesis separados por comas si los admite):
##   compuerta, puerta   abrir | cerrar | alternar          pulsador   pulsar
##   barril              encender | apagar                    nexo       mojar | secar
##   tinaja              mojar | abrir_cauce(caudal,volumen) | apagar_fuente
##   manantial           abrir_cauce(caudal,volumen) | apagar_fuente | helar(s)
##   cuenca              helar(s)        (hiela sus casillas `s` segundos; sin argumento, AguaSim3D.DURA_HIELO)
##   brasero             encender | apagar        seto    encender (lo prende)        cuerda  quemar
##   cerrojo             abrir (definitivo) | cerrar                              cofre   abrir (como si el jugador pulsara E) | aparecer (lo fuerza)
##   cristal             latir (suelta un pulso ahora)                            receptor  activar | apagar     prisma  girar     pared_hueca  abrir
##   emisor              pulso(alcance) (la fuente suelta un Pulso3D de rayo por el agua y las vetas; alcance en casillas, 12 por defecto)
##   jarron, caja        romper (como un golpe)                salida   usar (la dispara, como si la jugadora la pisara)      columna  romper (la tumba)
## `abrir_cauce` sin argumentos usa los de la pieza (manantial) o Surtidor3D.CAUDAL_TINAJA / VOL_TINAJA (tinaja).
##
## FLAGS (C1, 21/10): lo que el juego RECUERDA entre partidas (`nucleo/flags.gd`). «flag» es una palabra reservada: ninguna pieza se
## puede llamar así. El nombre de la flag es `<nivel>.<sala>.<hecho>` (minúsculas, cifras y «_»; ej. `bosque1.s3.placa_norte`).
##   señal      cuando=flag.<nombre>           salta cuando la flag se PONE (pasa a verdadera; también al cargar una partida que la trae) y UNA vez al montar el nivel si ya estaba puesta
##                                             (volver de otra escena: lo resuelto se recuerda con la pareja `cuando=<pieza>.<señal> hace=flag.poner(x)` + `cuando=flag.x hace=<pieza>.<acción>`)
##   condición  si=flag.<nombre>               se cumple si la flag está puesta
##   acciones   hace=flag.poner(<nombre>) | flag.quitar(<nombre>)
## Ejemplo (dos piezas enlazadas solo por una flag): «; puzle marca cuando=b.pulsado hace=flag.poner(bosque1.s3.placa)» y
## «; puzle abre cuando=flag.bosque1.s3.placa hace=p.abrir». Lo de dentro de una sala sigue en las piezas, no en flags.
##
## EJEMPLO DE SALA CERRADA (C3): se entra, la sala se cierra, se derrota a los tres goblins, se abre, aparece el cofre y recuerda que se abrió:
##   ; pieza v  vigia   0 0 de=3,2..6,5 flag=bosque1.s3.limpia
##   ; pieza cj cerrojo 2 3 celdas=2,3..2,4 sala=3,2..6,5 hasta=bosque1.s3.limpia
##   ; pieza cf cofre   5 4 aparece_si=v.todos abierto=bosque1.s3.cofre
##   ; puzle sala_abre cuando=v.todos_derrotados hace=cj.abrir
## (`aparece_si=flag.bosque1.s3.limpia` sirve igual y sobrevive a recargar la partida; `v.todos` solo vale mientras la sala está viva.)
## Al recargar con `bosque1.s3.cofre` puesta el cofre nace abierto; con solo `bosque1.s3.limpia`, la sala nace abierta y el cofre cerrado y visible.
##
## EJEMPLO (una sala: cada pulsador abre la compuerta y, cuando el agua llega a 0,35, se abre la puerta):
##   ; pieza k    compuerta 4 3 abre_con=fuego
##   ; pieza n    nivel     6 3 objetivo=0.35
##   ; pieza p    puerta    1 6
##   ; pieza b    pulsador  2 6 modo=magia
##   ; puzle boton cuando=b.pulsado hace=k.abrir
##   ; puzle abre  cuando=n.alcanzado hace=p.abrir
##   ; puzle cierra cuando=n.perdido hace=p.cerrar
##
## ERRORES: una línea mal escrita, un id repetido o una referencia a algo que no existe NO tumban el nivel: esa línea se ignora,
## sale `push_warning("Puzle3D: línea N: …")` con el texto de la línea, queda en `avisos` y se pinta un rótulo AVISO en el HUD.
## Para las pruebas: `pieza(id)` (la ficha, con `.nodo`), `nodo(id)`, `puzle(nombre)` (la regla, con `veces`), `parsear(texto)` sin mundo.
##
## DEPENDENCIA CON LA MAQUETA: las piezas se cuelgan de `mundo._props` (el contenedor del decorado; si no existe, del propio mundo) y el
## emisor eléctrico recibe el mundo. La tinaja y el tótem se buscan en el grupo `reactivo3d`. Nada más.

signal aviso_nuevo(texto: String)

const SENAL_DEFECTO: Dictionary = {
	"pulsador": "pulsado", "compuerta": "abierta", "nivel": "alcanzado", "molino": "girando", "nexo": "conduce", "barril": "explota",
	"puerta": "abierta", "totem": "activado", "tinaja": "agua_llega", "emisor": "descarga",
	"brasero": "encendido", "contador": "todos", "cuerda": "rota", "seto": "consumido",
	"vigia": "todos_derrotados", "cerrojo": "cerrado", "cofre": "abierto", "muro": "roto", "lava": "apagada", "seta": "recogida",
	"alga": "recogida", "basalto": "recogida",
	"cristal": "late", "receptor": "activado", "prisma": "gira", "pared_hueca": "abierta",
	"jarron": "roto", "caja": "roto", "salida": "usada",
	"columna": "cae", "estatuas": "completa", "estalagmita": "cae",
}
## Señal de usuario → [señal de Godot, cuántos argumentos trae, filtro]: un filtro `true`/`false` deja pasar solo ese valor del primer argumento.
const SENALES: Dictionary = {
	"pulsador": {"pulsado": ["pulsado", 1, null], "soltado": ["soltado", 0, null]},
	"compuerta": {"abierta": ["cambio", 1, true], "cerrada": ["cambio", 1, false]},
	"nivel": {"alcanzado": ["nivel_alcanzado", 1, true], "perdido": ["nivel_alcanzado", 1, false]},
	"molino": {"girando": ["girando", 1, true], "parado": ["girando", 1, false]},
	"nexo": {"conduce": ["cambio", 1, true], "corta": ["cambio", 1, false]},
	"barril": {"explota": ["explota", 2, null]},
	"puerta": {"abierta": ["cambio", 1, true], "cerrada": ["cambio", 1, false]},
	"totem": {"activado": ["activado", 2, null]},
	"tinaja": {"agua_llega": ["agua_llega", 0, null]},
	"emisor": {"descarga": ["descarga", 1, null]},
	"brasero": {"encendido": ["llama", 1, true], "apagado": ["llama", 1, false]},
	"contador": {"todos": ["todos", 1, true], "no_todos": ["todos", 1, false]},
	"cuerda": {"rota": ["rota", 0, null]},
	"seto": {"consumido": ["consumido", 1, null]},
	"vigia": {"todos_derrotados": ["todos_derrotados", 0, null]},
	"cerrojo": {"cerrado": ["cambio", 1, true], "abierto": ["cambio", 1, false]},
	"cofre": {"aparecido": ["aparecido", 0, null], "abierto": ["abierto", 0, null]},
	"muro": {"roto": ["roto", 0, null]},
	"lava": {"enfriada": ["enfriada", 1, null], "apagada": ["apagada", 0, null]},
	"seta": {"recogida": ["recogido", 1, null]},
	"alga": {"recogida": ["recogido", 1, null]},
	"basalto": {"recogida": ["recogido", 1, null]},
	"cristal": {"late": ["late", 1, null]},
	"receptor": {"activado": ["activado", 0, null], "apagado": ["apagado", 0, null]},
	"prisma": {"gira": ["gira", 1, null], "emite": ["emite", 1, null]},
	"pared_hueca": {"abierta": ["abierto", 0, null], "eco": ["eco", 1, null]},
	"jarron": {"roto": ["roto", 0, null]},
	"caja": {"roto": ["roto", 0, null]},
	"salida": {"usada": ["usada", 1, null]},
	"columna": {"cae": ["roto", 0, null]},
	"estalagmita": {"cae": ["cae", 0, null]},
	"estatuas": {"completa": ["completa", 0, null], "falla": ["falla", 0, null], "acierta": ["acierta", 2, null]},
}
const CONDICIONES: Dictionary = {
	"compuerta": {"abierta": ["abierta", true], "cerrada": ["abierta", false]},
	"puerta": {"abierta": ["abierta", true], "cerrada": ["abierta", false]},
	"nivel": {"alcanzado": ["alcanzado", true], "perdido": ["alcanzado", false]},
	"nexo": {"conduce": ["conduce", true], "corta": ["conduce", false]},
	"molino": {"girando": ["activo", true], "parado": ["activo", false]},
	"barril": {"explotado": ["explotado", true], "encendido": ["encendido", true], "entero": ["explotado", false]},
	"pulsador": {"activo": ["activo", true], "libre": ["activo", false]},
	"brasero": {"encendido": ["is_lit", true], "apagado": ["is_lit", false]},
	"contador": {"todos": ["completo", true], "no_todos": ["completo", false]},
	"cuerda": {"rota": ["rota_ya", true], "entera": ["rota_ya", false]},
	"seto": {"ardiendo": ["is_lit", true]},
	"vigia": {"todos": ["completo", true], "quedan": ["completo", false]},
	"cerrojo": {"cerrado": ["cerrado", true], "abierto": ["cerrado", false]},
	"cofre": {"oculto": ["es_oculto", true], "cerrado": ["es_cerrado", true], "abierto": ["es_abierto", true]},
	"muro": {"roto": ["roto_ya", true], "entero": ["roto_ya", false]},
	"lava": {"activa": ["is_lit", true], "apagada": ["is_lit", false]},
	"seta": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"alga": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"basalto": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"receptor": {"activo": ["activo", true], "libre": ["activo", false]},
	"pared_hueca": {"abierta": ["abierta", true], "cerrada": ["abierta", false]},
	"jarron": {"roto": ["roto_ya", true], "entero": ["roto_ya", false]},
	"caja": {"roto": ["roto_ya", true], "entero": ["roto_ya", false]},
	"columna": {"caida": ["roto_ya", true], "en_pie": ["roto_ya", false]},
	"estalagmita": {"caida": ["caida_ya", true], "en_pie": ["caida_ya", false]},
	"estatuas": {"completa": ["hecha", true], "pendiente": ["hecha", false]},
}
## Acción → cuántos argumentos admite como máximo.
const ACCIONES: Dictionary = {
	"pulsador": {"pulsar": 0},
	"compuerta": {"abrir": 0, "cerrar": 0, "alternar": 0},
	"puerta": {"abrir": 0, "cerrar": 0, "alternar": 0},
	"barril": {"encender": 0, "apagar": 0},
	"nexo": {"mojar": 0, "secar": 0},
	"tinaja": {"mojar": 0, "abrir_cauce": 2, "apagar_fuente": 0},
	"manantial": {"abrir_cauce": 2, "apagar_fuente": 0, "helar": 1},
	"cuenca": {"helar": 1},
	"brasero": {"encender": 0, "apagar": 0},
	"seto": {"encender": 0},
	"cuerda": {"quemar": 0},
	"cerrojo": {"abrir": 0, "cerrar": 0},
	"cofre": {"abrir": 0, "aparecer": 0},
	"muro": {"romper": 0},
	"lava": {"enfriar": 0},
	"seta": {"recoger": 0},
	"alga": {"recoger": 0},
	"basalto": {"recoger": 0},
	"cristal": {"latir": 0},
	"receptor": {"activar": 0, "apagar": 0},
	"prisma": {"girar": 0},
	"pared_hueca": {"abrir": 0},
	"emisor": {"pulso": 1},
	"jarron": {"romper": 0},
	"caja": {"romper": 0},
	"salida": {"usar": 0},
	"columna": {"romper": 0},
}
## Claves de cada tipo de pieza y qué valor admiten: «f» número, «b» sí/no, «celdas» lista de casillas, «fijo» número o sí, «s:a|b» una de esas palabras.
const CLAVES: Dictionary = {
	"pulsador": {"modo": "s:magia|agua|presencia", "rearme": "f", "modelo": "s:cueva"},
	"compuerta": {"abierta": "b", "abre_con": "s:fuego|agua|hielo|rayo|explosion", "cierra_con": "s:fuego|agua|hielo|rayo", "estrecha": "b", "vertical": "b"},
	"nivel": {"objetivo": "f", "banda": "f", "invertido": "b"},
	"molino": {"umbral": "f", "vertical": "b"},
	"barril": {},
	"nexo": {},
	"puerta": {"modelo": "s:llave", "llave": "flag", "gasta": "b", "abierto": "flag", "flag": "flag"},
	"emisor": {},
	"cuenca": {"celdas": "celdas", "nivel": "f", "fijo": "fijo"},
	"manantial": {"caudal": "f", "volumen": "f", "rampa": "b", "inicia": "b", "celdas": "celdas", "sin_piedra": "b", "bloque": "celdas", "terraza": "f", "pilares": "b", "espuma": "f"},
	"tinaja": {"canal": "celdas"},
	"totem": {},
	"brasero": {"rele": "id", "espera": "f", "dura": "f", "luz": "f", "modelo": "s:cueva"},
	"decorado": {"modelo": "s:geoda_resonante|estalagmita_resonante|estalagmita_rota|rocas_salpicadura|helechos_cueva|musgo_colgante", "giro": "f", "escala": "f"},
	"seto": {"mojable": "b"},
	"contador": {"de": "celdas", "minimo": "f"},
	"cuerda": {"sostiene": "id"},
	"vigia": {"de": "celdas", "flag": "flag"},
	"cerrojo": {"celdas": "celdas", "sala": "celdas", "hasta": "flag"},
	"cofre": {"aparece_si": "expr", "abierto": "flag", "modelo": "s:legendario|epico", "abre_si": "expr", "glifo": "glifo", "da": "da"},
	"muro": {"golpes": "f"},
	"lava": {"celdas": "celdas", "vuelve": "f"},
	"seta": {"variante": "s:roja|azul|marron", "rebrota": "f", "madura": "b"},
	"alga": {"coge_si": "expr", "rebrota": "f"},
	"basalto": {"coge_si": "expr", "rebrota": "f"},
	"cristal": {"cada": "f", "alcance": "f"},
	"veta": {"celdas": "celdas", "enlaces": "celdas", "aturde": "f", "mineral": "b"},
	"columna": {"golpes": "f", "cae": "s:n|e|s|o"},
	"estalagmita": {"cae": "s:n|e|s|o", "flag": "flag"},
	"estatuas": {"celdas": "celdas", "secuencia": "secuencia", "flag": "flag"},
	"receptor": {"elemento": "s:fuego|agua|hielo|rayo|tierra|viento", "flag": "flag", "rearme": "f"},
	"prisma": {"dir": "s:n|e|s|o"},
	"pared_hueca": {"flag": "flag", "mira": "s:n|e|s|o"},
	"jarron": {"botin": "botin", "cantidad": "f", "alto": "b", "celdas": "celdas", "modelo": "s:caja|jarron"},
	"caja": {"botin": "botin", "cantidad": "f", "pequena": "b", "celdas": "celdas"},
	"salida": {"a": "destino", "escena": "nombre", "entrada": "nombre", "modelo": "nombre", "celdas": "celdas", "modo": "s:pisar|usar", "marca": "b"},
	"entrada": {"mira": "s:n|e|s|o"},
}
## C3: pieza del cofre, cuánto de cerca hay que estar para abrirlo con E (la casilla mide 2,3; igual que el Bosque), cada cuánto miran su estado
## las piezas lógicas (vigía, cerrojo, cofre) y los avisos de un vigía que no encuentra enemigos.
const ESCENA_COFRE: String = "res://arte/piezas/cofre.tscn"
## 23/10: cofres de la Cueva (hoja D2). `modelo=legendario|epico` en un cofre usa su escena (misma API: cuerpo + tapa con la bisagra en el origen de la tapa).
const ESCENAS_COFRE_CUEVA: Dictionary = {"legendario": "res://arte/piezas/cofre_legendario.tscn", "epico": "res://arte/piezas/cofre_epico.tscn"}
const ALCANCE_COFRE: float = 2.7
## 24/10: un glifo ganado en un cofre (`glifo=`) se apunta en la flag `global.glifo.<id>`; al montarse OTRO nivel, `Lanzador3D.aplicar_progresion` vuelve a fijar el repertorio de su kit y el glifo se perdía
## (ᚱ de la Cueva no llegaba al Bosque): Puzle3D lo vuelve a desbloquear al montar (`_restaurar_glifos`), venga el glifo del nivel que venga.
const FLAG_GLIFO_GANADO: String = "global.glifo."
const MOTAS_APERTURA: int = 34                   ## motas del color de la calidad al abrirse un cofre épico o legendario
const TXT_COFRE_SELLADO: String = "El cofre está sellado: sus vetas están apagadas"
const CADA_LOGICA: float = 0.1
const CADA_COFRE: float = 0.2
const T_VIGIA_SIN_ENEMIGOS: float = 3.0
## C1: el «id» con el que se nombran las flags en las reglas (cuando=flag.x, si=flag.x, hace=flag.poner(x)).
const ID_FLAG: String = "flag"
const ACCIONES_FLAG: Array = ["poner", "quitar"]
## RESPUESTA POSITIVA (PLAN_EOW_VISUAL §4): las piezas lógicas avisan de un LOGRO con un nombre del catálogo cerrado `Mundo3D.LOGROS`; qué se ve y suena lo decide
## `Logros3D`. Quién emite qué (cada uno UNA vez por suceso real, nunca al montar ni al recargar algo que ya estaba hecho):
##   paso_puzle     un contador SUBE sin llegar a su mínimo (2 de 3 braseros)      puzle_resuelto  un contador COMPLETA, o una regla ABRE una compuerta/puerta que estaba cerrada
##   sala_limpia    el vigía ve caer al último enemigo                              puerta_abierta  un cerrojo pasa de cerrado a abierto
##   cofre_aparece  el cofre pasa de oculto a cerrado CON efecto                    cofre_abierto   el cofre acaba de abrirse (animación terminada)
## `nivel_completado` no lo emite Puzle3D: lo emite cada nivel al terminarlo (salida o cofre final, `Mundo3D.avisar_logro`). Una cascada del mismo fotograma (un contador completa y su regla
## abre la puerta) cuenta como UN suceso: el mismo nombre no se repite en VENTANA_LOGRO fotogramas.
const VENTANA_LOGRO: int = 2
## Mientras sea true no se avisa de ningún logro: lo pone quien CARGA una partida con el nivel ya montado (las flags que llegan reabren puertas sin que el jugador haya hecho nada).
static var silencio_logros: bool = false
static var _logro_en: Dictionary = {}                    ## nombre -> fotograma del último aviso
## C2: condición de casilla `casilla(x,y).<estado>`: los estados de EstadosSuelo3D (B1) y «agua» (Terreno3D.es_agua).
const TERMINO_CASILLA: String = "casilla"
const ESTADOS_CASILLA: Array = ["mojada", "helada", "quemada", "electrificada", "segada", "agua", "roca"]
## Piezas que ya pone la maqueta por letra: la casilla de la pieza tiene que llevar esa letra.
const LETRA_MAQUETA: Dictionary = {"tinaja": "u", "totem": "i", "emisor": "e", "brasero": "T", "seto": "z"}
## Piezas que necesitan la simulación de agua (`agua_fisica = true` en la escena).
const NECESITAN_AGUA: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino"]
const NECESITAN_CAUCE: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino"]


## Una pieza declarada: su ficha (y su nodo, si es de las que lo tienen; `cuenca` y `manantial` son solo datos).
class Pieza extends RefCounted:
	var id: String = ""
	var tipo: String = ""
	var celda: Vector2i = Vector2i.ZERO
	var p: Dictionary = {}                       ## las claves que escribió Pablo (ya convertidas)
	var exprs: Dictionary = {}                   ## C3: las claves de tipo «expr» (aparece_si=) ya leídas como expresión (misma forma que `si_expr`); `p` guarda su texto
	var nodo: Node = null
	var nodos: Array = []                        ## las piezas que crea una línea con `celdas=` (jarrones, cajas): `nodo` es la primera
	var n: int = 0                               ## línea del .txt
	var activa: bool = false                     ## manantial: ya está echando agua


## Losa que bloquea su casilla hasta que el puzle se cumple (y vuelve a cerrarse si deja de cumplirse). Antes vivía en el laboratorio.
class PuertaPuzle extends Node3D:
	signal cambio(abierta: bool)
	var celda: Vector2i = Vector2i.ZERO
	var abierta: bool = false
	const ANCHO_MARCO: float = 0.78           ## dónde van las jambas, en medias casillas desde el centro (ajustado a ojo en la Cueva)
	## PUERTA CON LLAVE DE VERDAD (23/10, EoW): con `llave` puesta la puerta no la abre una regla, sino la jugadora: hace falta la flag Y estar delante (tocarla o pulsar E).
	const ALCANCE_TOQUE: float = 1.9           ## u del centro de la casilla: ya la toca (media casilla + el cuerpo de la jugadora)
	const ALCANCE_USAR: float = 3.2            ## u: a cuánto vale E (una casilla de margen)
	const CADA_PUERTA: float = 0.1
	const T_AVISO_LLAVE: float = 2.5           ## s entre dos avisos de «hace falta una llave»
	const TXT_SIN_LLAVE: String = "Hace falta una llave"
	var llave: String = ""                     ## flag que hace de llave ("" = puerta normal)
	var gasta: bool = false                    ## quitar la flag al abrir
	var flag_abierto: String = ""              ## flag que recuerda que se abrió
	var intentos_sin_llave: int = 0            ## cuántas veces se ha intentado sin la llave (las pruebas)
	var _mundo: Node = null
	var _t_puerta: float = 0.0
	var _t_aviso: float = 0.0
	var _losa: Node3D = null
	var _rotulo: Label3D = null
	var _y0: float = 0.0

	## Convierte la puerta en una puerta con llave. Con `abierto` ya puesta nace abierta.
	func configurar_llave(p_llave: String, p_gasta: bool, p_abierto: String) -> void:
		llave = p_llave
		gasta = p_gasta
		flag_abierto = p_abierto
		set_process(llave != "")
		if flag_abierto != "":
			Flags.i().flag_cambio.connect(_al_cambiar_flag)
			if Flags.i().tiene(flag_abierto):
				_abrir_ya()

	func _al_cambiar_flag(nombre: String, valor: Variant) -> void:
		if nombre == flag_abierto and valor != null and not (valor is bool and valor == false) and not abierta:
			_abrir_ya()

	## Abierta sin animación (partida cargada).
	func _abrir_ya() -> void:
		poner(true)
		if _losa != null:
			_losa.position.y = _y0 - 2.1

	## Distancia horizontal de la jugadora al centro de la puerta (INF si no hay jugadora).
	func distancia_jugadora() -> float:
		var j: Node3D = Puzle3D.jugador_nodo(get_tree(), _mundo)
		if j == null:
			return INF
		var d: Vector3 = j.global_position - global_position
		d.y = 0.0
		return d.length()

	## Lo que hace la jugadora al llegar a la puerta (tocarla: `explicito` false; pulsar E: true). Con la llave, se abre; sin ella, avisa.
	## Devuelve true si se abre ahora (o ya estaba abierta).
	func intentar(explicito: bool) -> bool:
		if abierta:
			return true
		if llave == "":
			return false
		if Flags.i().tiene(llave):
			if distancia_jugadora() > (ALCANCE_USAR if explicito else ALCANCE_TOQUE):
				return false
			abrir_con_llave()
			return true
		intentos_sin_llave += 1
		if _t_aviso <= 0.0:
			_t_aviso = T_AVISO_LLAVE
			var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", TXT_SIN_LLAVE, Color(1.0, 0.75, 0.5))
		return false

	## Abre y, si la puerta lo pide, gasta la llave.
	func abrir_con_llave() -> void:
		Sfx.play(self, "puerta_abre")
		poner(true)
		if gasta and llave != "":
			Flags.i().quitar(llave)
		if flag_abierto != "":
			Flags.i().poner(flag_abierto)
		Puzle3D._logro("puerta_abierta", self)

	func _process(delta: float) -> void:
		_t_aviso -= delta
		_t_puerta -= delta
		if _t_puerta > 0.0 or abierta or llave == "":
			return
		_t_puerta = CADA_PUERTA
		if distancia_jugadora() <= ALCANCE_TOQUE:
			intentar(false)

	func _unhandled_input(ev: InputEvent) -> void:
		if llave == "" or abierta or not (ev is InputEventKey):
			return
		var k: InputEventKey = ev as InputEventKey
		if not k.pressed or k.echo or k.keycode != KEY_E:
			return
		if distancia_jugadora() <= ALCANCE_USAR and intentar(true):
			get_viewport().set_input_as_handled()

	## `modelo` "llave" (23/10, la Cueva): marco y hoja de verdad en vez de la losa y sin rótulo. Necesita a la maqueta (`mundo._pieza`) o las
	## escenas horneadas de arte/piezas; si no hay ninguna de las dos, queda la losa.
	func _ready() -> void:
		set_process(llave != "")                  # una puerta sin llave no necesita mirar nada cada fotograma

	func preparar(c: Vector2i, modelo: String = "", mundo: Node = null) -> void:
		celda = c
		_mundo = mundo
		position = Terreno3D.centro_de(c, Terreno3D.alto_suelo)
		Terreno3D.bloquear_celda(c)
		# La puerta tapa el paso: si la pared sigue de norte a sur (paso de este a oeste), se gira 90°.
		var pared_ns: bool = Terreno3D.letra_de(c + Vector2i(0, -1)) == "#" and Terreno3D.letra_de(c + Vector2i(0, 1)) == "#"
		if pared_ns:
			rotation.y = PI * 0.5
		if modelo == "llave" and _poner_modelo(mundo):
			return
		var losa := MeshInstance3D.new()
		_losa = losa
		var b := BoxMesh.new()
		b.size = Vector3(Terreno3D.casilla * 0.9, 2.2, 0.3)
		losa.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.36, 0.22)
		losa.material_override = mat
		_y0 = 1.1
		_losa.position = Vector3(0.0, _y0, 0.0)
		add_child(_losa)
		_rotulo = Label3D.new()
		_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rotulo.font_size = 30
		_rotulo.outline_size = 8
		_rotulo.pixel_size = 0.005
		_rotulo.position = Vector3(0.0, 2.9, 0.0)
		add_child(_rotulo)
		_pintar_rotulo()

	## Marco (dos jambas: el modelo es media, la otra va en espejo) y hoja, que se hunde al abrir como la losa. Devuelve false si no hay modelos.
	func _poner_modelo(mundo: Node) -> bool:
		var jamba_a: Node3D = _cargar_pieza("puerta_llave_marco", mundo)
		var jamba_b: Node3D = _cargar_pieza("puerta_llave_marco", mundo)
		var hoja: Node3D = _cargar_pieza("puerta_llave_hoja", mundo)
		if jamba_a == null or jamba_b == null or hoja == null:
			return false
		var media: float = Terreno3D.casilla * 0.5
		jamba_a.position.x = -media * ANCHO_MARCO
		jamba_b.position.x = media * ANCHO_MARCO
		jamba_b.scale.x = -1.0
		add_child(jamba_a)
		add_child(jamba_b)
		_losa = hoja
		_y0 = 0.0
		add_child(hoja)
		return true

	func _cargar_pieza(id: String, mundo: Node) -> Node3D:
		if mundo != null and mundo.has_method("_pieza"):
			var n: Node3D = mundo.call("_pieza", id) as Node3D
			if n != null:
				return n
		var ruta: String = "res://arte/piezas/%s.tscn" % id
		if ResourceLoader.exists(ruta):
			return (load(ruta) as PackedScene).instantiate() as Node3D
		return null

	func _pintar_rotulo() -> void:
		if _rotulo == null:
			return
		_rotulo.text = "PUERTA ABIERTA" if abierta else "PUERTA CERRADA"
		_rotulo.modulate = Color(0.5, 1.0, 0.55) if abierta else Color(1.0, 0.6, 0.5)

	func poner(si: bool) -> void:
		if si == abierta:
			return
		abierta = si
		_pintar_rotulo()
		if si:
			Terreno3D.liberar_celda(celda)
		else:
			Terreno3D.bloquear_celda(celda)
		var tw: Tween = create_tween()
		tw.tween_property(_losa, "position:y", _y0 - 2.1 if si else _y0, 0.8).set_trans(Tween.TRANS_SINE)
		cambio.emit(si)

	func abrir() -> void:
		poner(true)

	func cerrar() -> void:
		poner(false)

	func alternar() -> void:
		poner(not abierta)


## C3 · VIGÍA: vigila a los enemigos cuya casilla de partida está en `de` y avisa cuando han caído todos. «Caído» = `muerto` (por daño o hundido: A3 los
## marca igual) o ya liberado. Se fija en `Combate3D.muerto` y no en la señal de muerte porque es lo único que no se pierde: el vigía puede montarse
## después de que alguien muera, y `Estado.enemigo_muerto` solo dice dónde, no cuál. Los enemigos se buscan en los grupos «combate3d» (vivos) y «goblins»
## (siguen ahí ~1,4 s tras morir), cada CADA_LOGICA s, hasta el momento de cumplirse: así también entran los que nazcan algo más tarde.
class VigiaPuzle extends Node:
	signal todos_derrotados
	signal aviso(texto: String)
	var de: Array = []
	var flag: String = ""
	var completo: bool = false
	var vistos: Array = []                       ## los Combate3D que vigila
	var _t: float = 0.0
	var _t_sin: float = 0.0
	var _avisado: bool = false

	func preparar(p_de: Array, p_flag: String) -> void:
		de = p_de
		flag = p_flag
		# Partida cargada con la sala ya limpia: nace cumplido (sin emitir: la sala no se vuelve a cerrar ni a abrir).
		if flag != "" and Flags.i().tiene(flag):
			completo = true

	## Sala ya limpia al montar (la flag del vigía está puesta: se volvió de otro nivel o se cargó una partida): sus enemigos NO aparecen. Quita de la escena a los Combate3D cuya
	## casilla de partida está en `de`, con su modelo. Los de fuera de la sala (los sueltos del exterior) vuelven como siempre. Devuelve cuántos quitó.
	func retirar_enemigos() -> int:
		var quitados: int = 0
		var mundo_v: Variant = null
		for grupo in ["combate3d", "goblins"]:
			for n in get_tree().get_nodes_in_group(grupo):
				if not (n is Combate3D) or not is_instance_valid(n) or not de.has(Terreno3D.celda_de((n as Combate3D).casa)):
					continue
				var c: Combate3D = n as Combate3D
				if c.mundo != null:
					mundo_v = c.mundo.get("_goblins")
					if mundo_v is Array:
						(mundo_v as Array).erase(c.pj)
				c.remove_from_group("combate3d")
				c.remove_from_group("goblins")
				if c.pj != null and is_instance_valid(c.pj):
					c.pj.queue_free()
				c.queue_free()
				quitados += 1
		return quitados

	func restantes() -> int:
		var n: int = 0
		for e in vistos:
			if is_instance_valid(e) and not bool((e as Object).get("muerto")):
				n += 1
		return n

	func _process(delta: float) -> void:
		if completo:
			return
		_t_sin += delta
		_t -= delta
		if _t > 0.0:
			return
		_t = CADA_LOGICA
		_escanear()
		if vistos.is_empty():
			# Sin enemigos que casen no se da por limpio (una sala vacía por error abriría todo): se avisa una vez.
			if not _avisado and _t_sin >= T_VIGIA_SIN_ENEMIGOS:
				_avisado = true
				aviso.emit("vigía «%s»: ningún enemigo nace en las %d casillas de de= (usa la casilla de PARTIDA del enemigo)" % [name, de.size()])
			return
		if restantes() == 0:
			completo = true
			# El logro va ANTES de poner la flag: la flag abre el cerrojo (`hasta=`) y hace aparecer el cofre, y la respuesta debe llegar en su orden
			# (sala despejada → puerta → cofre), no al revés.
			Puzle3D._logro("sala_limpia", (vistos.back() as Node) if is_instance_valid(vistos.back()) else self)   # el punto: el último enemigo caído
			if flag != "":
				Flags.i().poner(flag)
			todos_derrotados.emit()

	func _escanear() -> void:
		for grupo in ["combate3d", "goblins"]:
			for n in get_tree().get_nodes_in_group(grupo):
				if n is Combate3D and not vistos.has(n) and de.has(Terreno3D.celda_de((n as Combate3D).casa)):
					vistos.append(n)


## C3 · CERROJO: las puertas de una sala. Nacen abiertas; se cierran cuando el jugador entra en `sala` y se abren con `abrir` (definitivo: no
## vuelven a cerrarse) o cuando se pone la flag `hasta`. Cada puerta es una PuertaPuzle (bloquea su casilla con Terreno3D.bloquear_celda).
class CerrojoPuzle extends Node3D:
	signal cambio(cerrado: bool)
	var celdas: Array = []
	var sala: Array = []
	var hasta: String = ""
	var mundo: Variant = null
	var cerrado: bool = false
	var vencido: bool = false                    ## ya se abrió "para siempre": entrar en la sala no lo cierra
	var _puertas: Array = []
	var _t: float = 0.0

	func preparar(p_celdas: Array, p_sala: Array, p_hasta: String, p_mundo: Variant) -> void:
		celdas = p_celdas
		sala = p_sala
		hasta = p_hasta
		mundo = p_mundo
		for c in celdas:
			var pu := PuertaPuzle.new()
			pu.name = "puerta_%d_%d" % [(c as Vector2i).x, (c as Vector2i).y]
			add_child(pu)
			pu.preparar(c as Vector2i)
			pu.poner(true)                       # nace abierta (preparar la deja cerrada y bloqueada)
			pu._losa.position.y = pu._y0 - 2.1   # y ya hundida, sin esperar al tween
			pu._rotulo.visible = false           # una puerta de sala no lleva el rótulo de la puerta de puzle
			_puertas.append(pu)
		if hasta != "":
			vencido = Flags.i().tiene(hasta)
			Flags.i().flag_cambio.connect(_al_cambiar_flag)

	func _al_cambiar_flag(nombre: String, valor: Variant) -> void:
		if nombre == hasta and valor != null and not (valor is bool and valor == false):
			abrir()

	## Abre para siempre (la regla `cuando=vigia.todos_derrotados hace=cerrojo.abrir`). Si nunca llegó a cerrarse, queda "ya vencido" y no cierra.
	func abrir() -> void:
		vencido = true
		_poner(true)

	## Cierra a mano (la acción `cerrar`: una sala sin `sala=`, o volver a cerrar). Con la flag `hasta` puesta no cierra.
	func cerrar() -> void:
		if hasta != "" and Flags.i().tiene(hasta):
			return
		vencido = false
		_poner(false)

	func _poner(abiertas: bool) -> void:
		if cerrado == (not abiertas):
			return
		cerrado = not abiertas
		for pu in _puertas:
			(pu as PuertaPuzle).poner(abiertas)
		if abiertas:
			Puzle3D._logro("puerta_abierta", _puertas[0] as Node if not _puertas.is_empty() else self)
		cambio.emit(cerrado)

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = CADA_LOGICA
		if vencido or cerrado or sala.is_empty():
			return
		var j: Node3D = Puzle3D.jugador_nodo(get_tree(), mundo)
		if j == null:
			return
		var c: Vector2i = Terreno3D.celda_de(j.global_position)
		# Pisar la propia puerta no cuenta como entrar (cerrarla encima del jugador lo dejaría atrapado dentro de la losa).
		if sala.has(c) and not celdas.has(c):
			_poner(false)


## C3 · COFRE: la LÓGICA del cofre (cuándo existe, cuándo se abre, qué se recuerda); el dibujo y la animación son de Cofre3D (Pipeline), al que solo se le
## PIDEN estados (ocultar / aparecer / abrir / poner_estado). Estados: oculto → cerrado → abierto. `ctrl` es un objeto con esa API (el Cofre3D real, o uno
## falso en una prueba). Sin modelo o sin tapa que animar (arte sin importar) el cofre funciona igual, solo que sin dibujo.
class CofrePuzle extends Node3D:
	signal aparecido
	signal abierto
	var celda: Vector2i = Vector2i.ZERO
	var expr: Array = []                         ## aparece_si= (vacío = siempre)
	var expr_abre: Array = []                    ## abre_si= (vacío = siempre): mientras no se cumpla el cofre está SELLADO (se ve, pero E avisa y no lo abre). PLAN_PULSO_RESONANTE §8
	var da: Array = []                           ## da= ([{que, n}]): el botín que da al abrirse
	var botin_dado: Array = []                   ## lo que dio de verdad al abrirse (las pruebas)
	var glifo: String = ""                       ## glifo= (id del libro): abrirlo da ese glifo con la secuencia del cofre legendario (SecuenciaCofreLegendario3D)
	var secuencia: SecuenciaCofreLegendario3D = null
	var calidad: String = ""                     ## `modelo=epico|legendario` (24/10, PLAN_PULSO_RESONANTE §7): el cofre sin abrir echa una COLUMNA DE LUZ de ese color y al abrirse suelta motas de él (VfxCalidad3D)
	var columna: Node3D = null                   ## la columna de luz mientras el cofre está cerrado
	var flag_abierto: String = ""
	var puzle: Variant = null                    ## el Puzle3D que sabe evaluar la expresión
	var mundo: Variant = null
	var modelo: Node3D = null
	var ctrl: Object = null
	var es_oculto: bool = true
	var es_cerrado: bool = false
	var es_abierto: bool = false
	var iniciado: bool = false
	var _abriendo: bool = false
	var _cuerpo: CollisionObject3D = null
	var _capa0: int = 0
	var _bloqueada: bool = false
	var _t: float = 0.0

	func preparar(p_celda: Vector2i, p_expr: Array, p_flag: String, p_puzle: Variant, p_mundo: Variant, escena: String, p_abre_si: Array = [], p_glifo: String = "") -> void:
		celda = p_celda
		expr = p_expr
		expr_abre = p_abre_si
		glifo = p_glifo
		flag_abierto = p_flag
		puzle = p_puzle
		mundo = p_mundo
		position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
		if escena != "" and ResourceLoader.exists(escena):
			modelo = (load(escena) as PackedScene).instantiate() as Node3D
			add_child(modelo)
			ctrl = Cofre3D.en(modelo)            # null si el modelo no trae tapa: funciona sin dibujo
			_cuerpo = modelo.get_node_or_null("cuerpo") as CollisionObject3D
			if _cuerpo != null:
				_capa0 = _cuerpo.collision_layer
		_poner_estado("oculto")                  # sin parpadeo: hasta `arrancar` (con todas las piezas montadas) no se sabe cuál toca

	## Segunda pasada: ya están todas las piezas, así que `aparece_si` se puede evaluar. Una partida cargada manda: `abierto` puesta = nace abierto.
	func arrancar() -> void:
		iniciado = true
		if flag_abierto != "" and Flags.i().tiene(flag_abierto):
			_poner_estado("abierto")
			if glifo != "":
				Repertoire.unlock_sigil(glifo)       # partida cargada: el glifo que dio este cofre ya es tuyo
		elif expr.is_empty() or bool(puzle.call("cumple_expr", expr)):
			_poner_estado("cerrado")             # ya se cumplía al montar: sin efecto de aparición
		Flags.i().flag_cambio.connect(_al_cambiar_flag)

	func _al_cambiar_flag(nombre: String, valor: Variant) -> void:
		var puesta: bool = valor != null and not (valor is bool and valor == false)
		if nombre == flag_abierto and puesta and not es_abierto:
			_poner_estado("abierto")             # la partida se cargó DESPUÉS de montar el nivel
		else:
			_revisar()

	## De golpe y sin efecto (montar, cargar partida). `e`: oculto | cerrado | abierto.
	func _poner_estado(e: String) -> void:
		es_oculto = e == "oculto"
		es_cerrado = e == "cerrado"
		es_abierto = e == "abierto"
		_abriendo = false
		if ctrl != null:
			ctrl.call("poner_estado", StringName(e))
		if modelo != null:
			modelo.visible = not es_oculto       # Cofre3D.ocultar() no hace nada sin tapa: se asegura aquí
		_colision(not es_oculto)
		_columna_actualizar()

	## Colisión del jugador (la casilla) y del cuerpo del modelo: solo existen mientras el cofre existe.
	func _colision(activa: bool) -> void:
		if activa and not _bloqueada:
			Terreno3D.bloquear_celda(celda)
			_bloqueada = true
		elif not activa and _bloqueada:
			Terreno3D.liberar_celda(celda)
			_bloqueada = false
		if _cuerpo != null:
			_cuerpo.collision_layer = _capa0 if activa else 0

	## La columna de luz de la calidad (solo épico y legendario): encendida mientras el cofre está cerrado y se ve; se apaga al abrirse.
	func _columna_actualizar() -> void:
		if calidad == "" or not Objetos.CALIDADES.has(calidad):
			return
		var debe: bool = es_cerrado and modelo != null and is_inside_tree()
		if debe and columna == null:
			columna = VfxCalidad3D.columna_luz(self, Objetos.CALIDADES[calidad]["color"])
		elif not debe and columna != null:
			VfxCalidad3D.apagar(columna)
			columna = null

	func _revisar() -> void:
		if iniciado and es_oculto and puzle != null and bool(puzle.call("cumple_expr", expr)):
			aparecer()

	## oculto → cerrado, con el efecto de Cofre3D. false si no estaba oculto.
	func aparecer() -> bool:
		if not es_oculto:
			return false
		es_oculto = false
		es_cerrado = true
		_colision(true)
		if modelo != null:
			modelo.visible = true
		if ctrl != null:
			ctrl.call("aparecer")
		_columna_actualizar()
		Puzle3D._logro("cofre_aparece", self)
		aparecido.emit()
		return true

	## Abre el cofre (E del jugador o la acción `abrir`). La flag se pone cuando TERMINA de abrirse (la señal `abierto` de Cofre3D).
	func abrir() -> bool:
		if not es_cerrado or _abriendo:
			return false
		if not sellado_cumplido():
			return false
		if glifo != "" and ctrl != null:
			# El cofre que da un glifo: lo abre la secuencia (cámara, luz, tapa, glifo, libro). Ella llama a `Cofre3D.abrir` a su hora.
			if StringName(ctrl.call("estado_nombre")) != &"cerrado":
				return false
			_abriendo = true
			ctrl.connect("abierto", _al_abrirse, CONNECT_ONE_SHOT)
			secuencia = SecuenciaCofreLegendario3D.new()
			secuencia.name = "Secuencia"
			add_child(secuencia)
			secuencia.iniciar(self, ctrl, mundo, glifo)
			return true
		if ctrl == null:
			_al_abrirse()
			return true
		if not bool(ctrl.call("abrir")):
			return false                          # aún apareciendo: el jugador volverá a pulsar
		_abriendo = true
		ctrl.connect("abierto", _al_abrirse, CONNECT_ONE_SHOT)
		return true

	## ¿Se cumple `abre_si`? (vacío = sí).
	func sellado_cumplido() -> bool:
		return expr_abre.is_empty() or puzle == null or bool(puzle.call("cumple_expr", expr_abre))

	## `da=`: el botín del cofre, UNA vez, al acabar de abrirse (un cofre que nace ya abierto no vuelve a dar). Oro y lo que quepa en la mochila (lo que no cabe se queda y se avisa).
	## Devuelve lo que entró: [{que, n}].
	func dar_botin() -> Array:
		var dado: Array = []
		var texto: PackedStringArray = []
		var sin_sitio: bool = false
		var color: Color = Color(1.0, 0.9, 0.6)
		var mejor: float = -1.0
		for it in da:
			var que: String = String((it as Dictionary)["que"])
			var n: int = int((it as Dictionary)["n"])
			if que == "oro":
				Estado.i().dar_oro(n)
				dado.append({"que": que, "n": n})
				texto.append("%d de oro" % n)
				continue
			var entra: int = Estado.i().agregar(que, n)
			if entra > 0:
				dado.append({"que": que, "n": entra})
				texto.append("%d × %s" % [entra, Objetos.nombre(que)])
				var rareza: float = float(Objetos.CALIDADES.keys().find(Objetos.calidad(que)))
				if rareza > mejor:
					mejor = rareza
					color = Objetos.color_calidad(que).lightened(0.6)
			if entra < n:
				sin_sitio = true
		if not da.is_empty():
			var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", "Cofre abierto: %s%s" % [", ".join(texto), " (la mochila está llena: lo demás se queda aquí)" if sin_sitio else ""], color)
		return dado

	func _al_abrirse() -> void:
		_abriendo = false
		es_cerrado = false
		es_abierto = true                         # antes de poner la flag: su aviso no debe tomarse por una carga de partida
		_columna_actualizar()                     # apaga la columna de luz
		if calidad != "" and Objetos.CALIDADES.has(calidad) and get_parent() is Node3D and is_inside_tree():
			VfxCalidad3D.motas(get_parent() as Node3D, global_position + Vector3(0.0, 1.0, 0.0), Objetos.CALIDADES[calidad]["color"], MOTAS_APERTURA, 1.4, 0.1, 2.0, 0.5)
		botin_dado = dar_botin()
		if flag_abierto != "":
			Flags.i().poner(flag_abierto)
		if glifo == "":
			Puzle3D._logro("cofre_abierto", self)     # el cofre que da un glifo lleva su propio aviso dorado (la secuencia): el rótulo de siempre taparía el primer plano
		abierto.emit()

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = CADA_COFRE
		_revisar()

	func _unhandled_input(ev: InputEvent) -> void:
		if not (ev is InputEventKey) or not es_cerrado or _abriendo:
			return
		var k: InputEventKey = ev as InputEventKey
		if not k.pressed or k.echo or k.keycode != KEY_E:
			return
		var j: Node3D = Puzle3D.jugador_nodo(get_tree(), mundo)
		if j == null:
			return
		var d: Vector3 = j.global_position - global_position
		d.y = 0.0
		if d.length() > ALCANCE_COFRE:
			return
		if not sellado_cumplido():
			# Sellado: se ve pero no se abre. El aviso dice que algo tiene que despertarlo (el receptor y el pulso, PLAN §8).
			var lz: Node = get_tree().get_first_node_in_group("spellcaster")
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", TXT_COFRE_SELLADO, Color(0.7, 0.85, 1.0))
			get_viewport().set_input_as_handled()
			return
		if abrir():
			get_viewport().set_input_as_handled()


var mundo: Variant = null                       ## la maqueta ya montada
var nivel: String = ""
var avisos: Array = []                           ## String: lo que no se pudo leer o montar, con su línea
var _piezas: Dictionary = {}                     ## id -> Pieza
var _orden: Array = []                           ## las piezas en el orden del .txt
var _reglas: Array = []                          ## Dictionary: {nombre, cuando_id, senal, si_id, si_cond, acciones, n, veces, ignoradas}
var _hielos: Dictionary = {}                     ## Vector2i -> s que le quedan a un hielo puesto por una regla
var _flags_al_montar: Array = []                 ## reglas `cuando=flag.…` cuya flag ya estaba puesta al montar: saltan una vez al acabar `iniciar`
var _iniciado: bool = false
var listo: bool = false                         ## `iniciar` terminó: todas las piezas montadas y las reglas conectadas (Niveles espera a esto antes de colocar a la jugadora en una entrada)
var _hud: Label = null


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if not _iniciado and get_parent() != null:
		iniciar(get_parent())


## Entrada pública. `p_nivel`: nombre del mapa («PuzlesAgua»); vacío = `mundo.nivel`. `p_texto`: el contenido del .txt (para las pruebas;
## vacío = se lee `mapas/<nivel>.txt`).
func iniciar(p_mundo: Variant, p_nivel: String = "", p_texto: String = "") -> void:
	if _iniciado:
		return
	_iniciado = true
	mundo = p_mundo
	nivel = p_nivel
	if nivel == "" and mundo is Object:
		var nv: Variant = (mundo as Object).get("nivel")          # null si el mundo no tiene «nivel» (un mundo falso de prueba)
		if nv != null:
			nivel = String(nv)
	var texto: String = p_texto
	if texto == "":
		texto = _leer_archivo(nivel)
	var r: Dictionary = parsear(texto)
	for a in (r["avisos"] as Array):
		_avisar(String(a))
	for pz in (r["piezas"] as Array):
		_orden.append(pz)
		_piezas[(pz as Pieza).id] = pz
	_reglas = r["reglas"]
	for pz in _orden:
		_crear(pz as Pieza)
	for pz in _orden:
		_enlazar(pz as Pieza)             # lo que apunta a otra pieza (`rele=`, `sostiene=`) se enlaza cuando ya están todas
	_conectar()
	_restaurar_glifos()
	set_process(true)
	listo = true
	for rf in _flags_al_montar:
		_disparar(rf as Dictionary)
	_flags_al_montar.clear()


## Vuelve a desbloquear los glifos que el jugador ganó en cofres de otros niveles (flags `global.glifo.<id>`): el repertorio lo reinicia cada nivel al montarse.
func _restaurar_glifos() -> void:
	for nombre in Flags.i().nombres(FLAG_GLIFO_GANADO):
		var id: String = String(nombre).trim_prefix(FLAG_GLIFO_GANADO)
		if GestureLibrary.SIGILS.has(id):
			Repertoire.unlock_sigil(id)


func _leer_archivo(p_nivel: String) -> String:
	var ruta: String = HorneadorNivel.ruta_mapa(p_nivel)
	if ruta == "":
		_avisar("no hay mapa «%s» (mundo/datos_nivel/mapas/%s.txt)" % [p_nivel, p_nivel])
		return ""
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		_avisar("no se puede leer %s" % ruta)
		return ""
	return f.get_as_text()


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que se puede preguntar (las pruebas, el HUD del laboratorio)
# ---------------------------------------------------------------------------------------------------------------------

func pieza(id: String) -> Pieza:
	return _piezas.get(id, null)


func nodo(id: String) -> Node:
	var pz: Pieza = pieza(id)
	return pz.nodo if pz != null and is_instance_valid(pz.nodo) else null


func piezas() -> Array:
	return _orden.duplicate()


## La pieza de un tipo en una casilla (el primer pulsador de (10,2), …). `tipo` vacío = cualquiera.
func pieza_en(c: Vector2i, tipo: String = "") -> Pieza:
	for pz in _orden:
		if (pz as Pieza).celda == c and (tipo == "" or (pz as Pieza).tipo == tipo):
			return pz
	return null


func puzle(nombre: String) -> Dictionary:
	for r in _reglas:
		if String((r as Dictionary)["nombre"]) == nombre:
			return r
	return {}


func reglas() -> Array:
	return _reglas.duplicate()


## El nodo que anda del jugador, como lo busca Pulsador3D en modo presencia: el Lanzador3D (grupos «spellcaster» / «player») sabe su `jugador`, y el
## muñeco `pj` es el que se mueve de verdad. Sin lanzador, el `_jugador` de la maqueta. null si no hay jugador.
static func jugador_nodo(arbol: SceneTree, p_mundo: Variant) -> Node3D:
	for grupo in ["spellcaster", "player"]:
		var lanz: Node = arbol.get_first_node_in_group(grupo)
		if lanz != null and lanz.get("jugador") != null:
			var j: Node3D = lanz.get("jugador") as Node3D
			return (j.get("pj") as Node3D) if j.get("pj") != null else j
	if p_mundo is Object:
		var mj: Variant = (p_mundo as Object).get("_jugador")
		if mj is Node3D:
			return mj as Node3D
	return null


static func runa(etiquetas: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for e in etiquetas:
		t.append(String(e))
	r.tags = t
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  Leer la gramática (sin mundo: se prueba con texto)
# ---------------------------------------------------------------------------------------------------------------------

## Devuelve {"piezas": Array[Pieza], "reglas": Array[Dictionary], "avisos": Array[String]}. Solo valen las líneas correctas.
static func parsear(texto: String) -> Dictionary:
	var piezas: Array = []
	var crudas: Array = []
	var avisos: Array = []
	var por_id: Dictionary = {}
	var n: int = 0
	for linea in texto.split("\n"):
		n += 1
		var l: String = String(linea).replace("\r", "").replace("\t", " ")
		if not l.begins_with(";"):
			continue
		var p: PackedStringArray = l.substr(1).strip_edges().split(" ", false)
		if p.is_empty():
			continue
		if p[0] == "pieza":
			var pz: Pieza = _leer_pieza(p, n, l, por_id, avisos)
			if pz != null:
				piezas.append(pz)
				por_id[pz.id] = pz
		elif p[0] == "puzle":
			var r: Dictionary = _leer_regla(p, n, l, avisos)
			if not r.is_empty():
				crudas.append(r)
	# Las claves «id» (rele=, sostiene=) apuntan a otra pieza: ya están todas leídas, se comprueba aquí. Si no existe, se quita la clave
	# (la pieza sigue, sin esa relación) y sale el aviso.
	for pz in piezas:
		var claves_pz: Dictionary = CLAVES[(pz as Pieza).tipo]
		for k in claves_pz:
			if String(claves_pz[k]) == "id" and (pz as Pieza).p.has(k) and not por_id.has((pz as Pieza).p[k]):
				_aviso_linea(avisos, (pz as Pieza).n, "pieza %s %s" % [(pz as Pieza).id, (pz as Pieza).tipo], "%s=%s: no hay ninguna pieza «%s»" % [k, (pz as Pieza).p[k], (pz as Pieza).p[k]])
				(pz as Pieza).p.erase(k)
	# C3: las claves «expr» (aparece_si=) son condiciones como las de si=: se leen aquí, con todas las piezas ya conocidas. Una pieza con una condición
	# MALA se descarta entera (un cofre que apareciera cuando no toca, o nunca, sería peor que un aviso; igual que una regla con `si=` roto).
	var descartadas: Array = []
	for pz in piezas:
		var claves_e: Dictionary = CLAVES[(pz as Pieza).tipo]
		for k in claves_e:
			if String(claves_e[k]) == "expr" and (pz as Pieza).p.has(k):
				var ex: Array = _leer_si(String((pz as Pieza).p[k]), por_id, (pz as Pieza).n, "pieza %s %s" % [(pz as Pieza).id, (pz as Pieza).tipo], avisos)
				if ex.is_empty():
					descartadas.append(pz)
				else:
					(pz as Pieza).exprs[k] = ex
	for pz in descartadas:
		piezas.erase(pz)
		por_id.erase((pz as Pieza).id)
	var reglas: Array = []
	var nombres: Dictionary = {}
	for r in crudas:
		var rr: Dictionary = r
		if nombres.has(rr["nombre"]):
			_aviso_linea(avisos, int(rr["n"]), String(rr["linea"]), "nombre de puzle repetido «%s» (ya está en la línea %d)" % [rr["nombre"], nombres[rr["nombre"]]])
			continue
		if _resolver(rr, por_id, avisos):
			nombres[rr["nombre"]] = int(rr["n"])
			reglas.append(rr)
	return {"piezas": piezas, "reglas": reglas, "avisos": avisos}


static func _aviso_linea(avisos: Array, n: int, linea: String, msg: String) -> void:
	avisos.append("línea %d: %s  [%s]" % [n, msg, linea.strip_edges()])


static func _id_valido(s: String) -> bool:
	if s == "":
		return false
	for i in range(s.length()):
		var ch: String = s[i]
		var ok: bool = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"
		if not ok:
			return false
	return true


static func _leer_pieza(p: PackedStringArray, n: int, l: String, por_id: Dictionary, avisos: Array) -> Pieza:
	if p.size() < 5:
		_aviso_linea(avisos, n, l, "pieza incompleta: se escribe «pieza <id> <tipo> <x> <y> [clave=valor …]»")
		return null
	var id: String = p[1]
	var tipo: String = p[2]
	if not _id_valido(id):
		_aviso_linea(avisos, n, l, "id no válido «%s» (letras, cifras y «_»)" % id)
		return null
	if por_id.has(id):
		_aviso_linea(avisos, n, l, "id repetido «%s» (ya está en la línea %d)" % [id, (por_id[id] as Pieza).n])
		return null
	if id == ID_FLAG:
		_aviso_linea(avisos, n, l, "«%s» es una palabra reservada (las flags): ponle otro id a la pieza" % ID_FLAG)
		return null
	if not CLAVES.has(tipo):
		_aviso_linea(avisos, n, l, "tipo desconocido «%s» (valen: %s)" % [tipo, ", ".join(CLAVES.keys())])
		return null
	if not p[3].is_valid_int() or not p[4].is_valid_int():
		_aviso_linea(avisos, n, l, "la casilla tiene que ser dos enteros (x y): «%s %s»" % [p[3], p[4]])
		return null
	var pz := Pieza.new()
	pz.id = id
	pz.tipo = tipo
	pz.celda = Vector2i(int(p[3]), int(p[4]))
	pz.n = n
	var claves: Dictionary = CLAVES[tipo]
	var bien: bool = true
	for i in range(5, p.size()):
		var kv: PackedStringArray = p[i].split("=", true, 1)
		if kv.size() != 2 or kv[0] == "":
			_aviso_linea(avisos, n, l, "«%s» no es clave=valor" % p[i])
			bien = false
			continue
		if not claves.has(kv[0]):
			_aviso_linea(avisos, n, l, "la pieza «%s» no tiene la clave «%s» (valen: %s)" % [tipo, kv[0], ", ".join(claves.keys()) if not claves.is_empty() else "ninguna"])
			bien = false
			continue
		var v: Array = _valor(String(claves[kv[0]]), kv[1])
		if not bool(v[0]):
			_aviso_linea(avisos, n, l, "%s=%s: %s" % [kv[0], kv[1], v[2]])
			bien = false
			continue
		pz.p[kv[0]] = v[1]
	return pz if bien else null


## Convierte el texto de una clave según su tipo. Devuelve [ok, valor, error].
static func _valor(tipo: String, t: String) -> Array:
	if tipo == "f":
		if not t.is_valid_float():
			return [false, null, "tiene que ser un número"]
		return [true, float(t), ""]
	if tipo == "b":
		var m: String = t.to_lower()
		if m in ["si", "sí", "true", "1"]:
			return [true, true, ""]
		if m in ["no", "false", "0"]:
			return [true, false, ""]
		return [false, null, "tiene que ser si o no"]
	if tipo == "fijo":
		var m2: String = t.to_lower()
		if m2 in ["si", "sí", "true"]:
			return [true, true, ""]
		if not t.is_valid_float():
			return [false, null, "tiene que ser un número o si"]
		return [true, float(t), ""]
	if tipo == "celdas":
		return _lista_celdas(t)
	if tipo == "flag":
		if not Flags.nombre_valido(t):
			return [false, null, "tiene que ser un nombre de flag (nivel.sala.hecho)"]
		return [true, t, ""]
	if tipo == "expr":
		return [true, t, ""]                    # el texto; se lee como expresión cuando ya están todas las piezas (ver parsear)
	if tipo == "glifo":
		if not GestureLibrary.SIGILS.has(t):
			return [false, null, "tiene que ser un glifo del libro (GestureLibrary.SIGILS: flecha, barrera, raido…)"]
		return [true, t, ""]
	if tipo == "botin":
		if not Rompible3D.botin_valido(t):
			return [false, null, "tiene que ser oro, pocion, nada o un objeto de Objetos.DATOS"]
		return [true, t, ""]
	if tipo == "da":
		# «<objeto>:<n>[+<objeto>:<n>…]»; `oro` es oro. Devuelve [{que, n}].
		var lista: Array = []
		for trozo in t.split("+", false):
			var kv: PackedStringArray = String(trozo).split(":")
			if kv.size() != 2 or not kv[1].is_valid_int() or int(kv[1]) <= 0 or not (kv[0] == "oro" or Objetos.existe(kv[0])):
				return [false, null, "«%s» no es <objeto>:<n> (oro u objeto de Objetos.DATOS; n entero > 0), unidos con «+»" % trozo]
			lista.append({"que": kv[0], "n": int(kv[1])})
		if lista.is_empty():
			return [false, null, "lista vacía"]
		return [true, lista, ""]
	if tipo == "secuencia":
		# «fuego,hielo,fuego»: una lista de elementos separados por comas (las estatuas del secreto). Devuelve [String].
		var elementos: Array = []
		for e in t.split(",", false):
			if not EstatuasPulso3D.ELEMENTOS_VALIDOS.has(String(e)):
				return [false, null, "«%s» no es un elemento (valen: %s)" % [e, ", ".join(EstatuasPulso3D.ELEMENTOS_VALIDOS)]]
			elementos.append(String(e))
		if elementos.is_empty():
			return [false, null, "lista vacía"]
		return [true, elementos, ""]
	if tipo == "nombre":
		if not _id_valido(t):
			return [false, null, "tiene que ser un nombre (letras, cifras y «_»)"]
		return [true, t, ""]
	if tipo == "destino":
		var pd: PackedStringArray = Niveles.partir(t)
		if pd.is_empty() or not _id_valido(pd[0]) or not _id_valido(pd[1]):
			return [false, null, "tiene que ser <Nivel>:<entrada> (letras, cifras y «_» a cada lado de los dos puntos)"]
		return [true, t, ""]
	if tipo == "id":
		if not _id_valido(t):
			return [false, null, "tiene que ser el id de otra pieza (letras, cifras y «_»)"]
		return [true, t, ""]
	if tipo.begins_with("s:"):
		var vale: PackedStringArray = tipo.substr(2).split("|")
		if not (t in vale):
			return [false, null, "tiene que ser uno de: %s" % ", ".join(vale)]
		return [true, t, ""]
	return [false, null, "tipo de valor desconocido"]


## «x,y» o «x0,y0..x1,y1», unidos con «+». Devuelve [ok, Array[Vector2i], error].
static func _lista_celdas(t: String) -> Array:
	var res: Array = []
	for trozo in t.split("+", false):
		var ext: PackedStringArray = String(trozo).split("..")
		if ext.size() > 2:
			return [false, null, "«%s» no es x,y ni x0,y0..x1,y1" % trozo]
		var a: Variant = _punto(ext[0])
		var b: Variant = a if ext.size() == 1 else _punto(ext[1])
		if a == null or b == null:
			return [false, null, "«%s» no es x,y ni x0,y0..x1,y1" % trozo]
		var pa: Vector2i = a
		var pb: Vector2i = b
		for y in range(mini(pa.y, pb.y), maxi(pa.y, pb.y) + 1):
			for x in range(mini(pa.x, pb.x), maxi(pa.x, pb.x) + 1):
				res.append(Vector2i(x, y))
	if res.is_empty():
		return [false, null, "lista vacía"]
	return [true, res, ""]


static func _punto(t: String) -> Variant:
	var xy: PackedStringArray = t.split(",")
	if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():
		return null
	return Vector2i(int(xy[0]), int(xy[1]))


static func _leer_regla(p: PackedStringArray, n: int, l: String, avisos: Array) -> Dictionary:
	var nombre: String = ""
	var cuando: String = ""
	var si: String = ""
	var hace: Array = []
	var bien: bool = true
	for i in range(1, p.size()):
		var t: String = p[i]
		var kv: PackedStringArray = t.split("=", true, 1)
		if kv.size() == 1:
			if nombre == "":
				nombre = t
			else:
				_aviso_linea(avisos, n, l, "sobra «%s»" % t)
				bien = false
			continue
		match kv[0]:
			"cuando":
				if cuando != "":
					_aviso_linea(avisos, n, l, "dos «cuando=»: un puzle tiene un solo disparador")
					bien = false
				cuando = kv[1]
			"si":
				if si != "":
					_aviso_linea(avisos, n, l, "dos «si=»")
					bien = false
				si = kv[1]
			"hace", "y":
				hace.append(kv[1])
			_:
				_aviso_linea(avisos, n, l, "clave desconocida «%s» (valen: cuando, si, hace, y)" % kv[0])
				bien = false
	if nombre == "" or not _id_valido(nombre):
		_aviso_linea(avisos, n, l, "falta el nombre del puzle (o no es válido): «puzle <nombre> cuando=… hace=…»")
		bien = false
	if cuando == "":
		_aviso_linea(avisos, n, l, "falta «cuando=<id>[.<señal>]»")
		bien = false
	if hace.is_empty():
		_aviso_linea(avisos, n, l, "falta «hace=<id>.<acción>»")
		bien = false
	if not bien:
		return {}
	return {"nombre": nombre, "cuando": cuando, "si": si, "hace": hace, "n": n, "linea": l, "veces": 0, "ignoradas": 0}


## Comprueba que cada referencia de la regla existe y es válida; si sí, la deja lista (ids, señal, acciones con argumentos).
static func _resolver(r: Dictionary, por_id: Dictionary, avisos: Array) -> bool:
	var n: int = int(r["n"])
	var l: String = String(r["linea"])
	# cuando=flag.<nombre> (C1): salta cuando la flag se pone.
	r["cuando_flag"] = ""
	if String(r["cuando"]).begins_with(ID_FLAG + "."):
		var nf: String = String(r["cuando"]).substr(ID_FLAG.length() + 1)
		if not Flags.nombre_valido(nf):
			_aviso_linea(avisos, n, l, "cuando=%s: «%s» no es un nombre de flag (nivel.sala.hecho)" % [r["cuando"], nf])
			return false
		r["cuando_id"] = ID_FLAG
		r["senal"] = "puesta"
		r["cuando_flag"] = nf
	else:
		if not _resolver_cuando(r, por_id, avisos):
			return false
	# C2: plantilla `$n` / `$id` / `$x` / `$y` en si= y hace=/y=, con los datos de la pieza que dispara (ya resuelta arriba).
	if not _aplicar_plantilla(r, por_id, avisos):
		return false
	# si
	r["si_id"] = ""
	r["si_cond"] = ""
	r["si_expr"] = []
	if String(r["si"]) != "":
		var expr: Array = _leer_si(String(r["si"]), por_id, n, l, avisos)
		if expr.is_empty():
			return false
		r["si_expr"] = expr
		# Compatibilidad: una sola condición de pieza sigue quedando en si_id / si_cond, como antes.
		if expr.size() == 1 and (expr[0] as Array).size() == 1:
			var t0: Dictionary = expr[0][0]
			if String(t0["tipo"]) == "pieza" and not bool(t0["neg"]):
				r["si_id"] = t0["id"]
				r["si_cond"] = t0["cond"]
	# hace / y
	var acciones: Array = []
	for txt in (r["hace"] as Array):
		var a: Dictionary = _leer_accion(String(txt), por_id, n, l, avisos)
		if a.is_empty():
			return false
		acciones.append(a)
	r["acciones"] = acciones
	return true


## C2: sustituye `$…` en el `si` y en cada `hace`/`y` por datos de la pieza que dispara (`cuando=`). Se hace al LEER (texto → texto),
## antes de resolver ids y condiciones, así que `$1` puede ser un id: `hace=$1.abrir`. Sin `$` no toca nada (compatibilidad total).
## Fichas: `$id` (id del disparador) · `$x` `$y` (su casilla) · `$1`, `$2`… (los valores de sus claves en el orden en que se escribieron
## en su línea `pieza`; un sí/no sale «si»/«no»; una lista de casillas, su primera casilla «x,y»).
static func _aplicar_plantilla(r: Dictionary, por_id: Dictionary, avisos: Array) -> bool:
	var n: int = int(r["n"])
	var l: String = String(r["linea"])
	var textos: Array = [String(r["si"])] + (r["hace"] as Array)
	var hay: bool = false
	for tx in textos:
		if String(tx).contains("$"):
			hay = true
	if not hay:
		return true
	var fuente: Pieza = por_id.get(String(r["cuando_id"]), null)
	if fuente == null:
		_aviso_linea(avisos, n, l, "«$» en la regla: solo vale si `cuando=` es una pieza (con flag.<nombre> no hay claves que leer)")
		return false
	var valores: Array = []
	for k in fuente.p:
		valores.append(_texto_valor(fuente.p[k]))
	var nuevo: Array = []
	for tx in textos:
		var res: Variant = _sustituir(String(tx), fuente, valores, n, l, avisos)
		if res == null:
			return false
		nuevo.append(String(res))
	r["si"] = String(nuevo[0])
	r["hace"] = nuevo.slice(1)
	return true


static func _texto_valor(v: Variant) -> String:
	if v is bool:
		return "si" if v else "no"
	if v is Array:
		var c: Vector2i = (v as Array)[0]
		return "%d,%d" % [c.x, c.y]
	if v is float:
		return String.num(v)
	return str(v)


static func _sustituir(t: String, fuente: Pieza, valores: Array, n: int, l: String, avisos: Array) -> Variant:
	var res: String = ""
	var i: int = 0
	while i < t.length():
		var ch: String = t[i]
		if ch != "$":
			res += ch
			i += 1
			continue
		# El nombre es todo-cifras ($12) o todo-letras ($id); lo siguiente ya es texto normal ($1.abrir, $x,$y).
		var j: int = i + 1
		var cifras: bool = j < t.length() and t[j] >= "0" and t[j] <= "9"
		while j < t.length() and ((t[j] >= "0" and t[j] <= "9") if cifras else ((t[j] >= "a" and t[j] <= "z") or (t[j] >= "A" and t[j] <= "Z") or t[j] == "_")):
			j += 1
		var nom: String = t.substr(i + 1, j - i - 1)
		if nom == "id":
			res += fuente.id
		elif nom == "x":
			res += str(fuente.celda.x)
		elif nom == "y":
			res += str(fuente.celda.y)
		elif nom.is_valid_int() and int(nom) >= 1 and int(nom) <= valores.size():
			res += String(valores[int(nom) - 1])
		else:
			_aviso_linea(avisos, n, l, "«$%s»: no existe (vale $id, $x, $y y $1…$%d: las claves de la pieza «%s», en el orden en que las escribiste)" % [nom, valores.size(), fuente.id])
			return null
		i = j
	return res


## `cuando=<id>[.<señal>]` de una pieza. Deja cuando_id y senal.
static func _resolver_cuando(r: Dictionary, por_id: Dictionary, avisos: Array) -> bool:
	var n: int = int(r["n"])
	var l: String = String(r["linea"])
	var cw: PackedStringArray = String(r["cuando"]).split(".")
	if cw.size() > 2 or not por_id.has(cw[0]):
		_aviso_linea(avisos, n, l, "cuando=%s: no hay ninguna pieza «%s»" % [r["cuando"], cw[0]])
		return false
	var fuente: Pieza = por_id[cw[0]]
	if not SENALES.has(fuente.tipo):
		_aviso_linea(avisos, n, l, "cuando=%s: una pieza «%s» no emite señales" % [r["cuando"], fuente.tipo])
		return false
	var senal: String = cw[1] if cw.size() == 2 else String(SENAL_DEFECTO[fuente.tipo])
	if not (SENALES[fuente.tipo] as Dictionary).has(senal):
		_aviso_linea(avisos, n, l, "cuando=%s: «%s» no emite «%s» (emite: %s)" % [r["cuando"], fuente.tipo, senal, ", ".join((SENALES[fuente.tipo] as Dictionary).keys())])
		return false
	r["cuando_id"] = fuente.id
	r["senal"] = senal
	return true


## `si=`: devuelve la expresión como lista de grupos O, cada uno una lista de términos Y (vacía = error, ya avisado).
## Un término: {"neg": bool, "tipo": "pieza"|"flag", …} (pieza: id, cond · flag: nombre).
## C2: «|» separa los grupos O y «+» los términos Y de cada grupo (Y antes que O, sin paréntesis). Si CUALQUIER trozo está mal, toda la
## condición se descarta (devuelve vacío) y la regla se ignora con su aviso: una condición a medias abriría puertas que no toca.
static func _leer_si(t: String, por_id: Dictionary, n: int, l: String, avisos: Array) -> Array:
	var expr: Array = []
	for g in t.split("|", true):
		var grupo: Array = []
		for trozo in String(g).split("+", true):
			if String(trozo) == "":
				_aviso_linea(avisos, n, l, "si=%s: hay un «+» o «|» sin condición al lado (a+b, a|b; no «a+», «+b» ni «a||b»)" % t)
				return []
			var termino: Dictionary = _leer_termino(String(trozo), por_id, n, l, avisos)
			if termino.is_empty():
				return []
			grupo.append(termino)
		expr.append(grupo)
	return expr


## Un término de condición: `<id>.<cond>`, `flag.<nombre>` o `casilla(x,y).<estado>`, con un «!» delante para negarlo.
static func _leer_termino(t: String, por_id: Dictionary, n: int, l: String, avisos: Array) -> Dictionary:
	if t.begins_with("!"):
		var resto: String = t.substr(1)
		if resto == "" or resto.begins_with("!"):
			_aviso_linea(avisos, n, l, "si=…%s…: el «!» va delante de UNA condición (!a.abierta); no vale solo ni doble" % t)
			return {}
		var interno: Dictionary = _leer_termino(resto, por_id, n, l, avisos)
		if not interno.is_empty():
			interno["neg"] = true
		return interno
	if t.begins_with(TERMINO_CASILLA + "("):
		return _leer_casilla(t, n, l, avisos)
	if t.begins_with(ID_FLAG + "."):
		var nf: String = t.substr(ID_FLAG.length() + 1)
		if not Flags.nombre_valido(nf):
			_aviso_linea(avisos, n, l, "si=%s: «%s» no es un nombre de flag (nivel.sala.hecho)" % [t, nf])
			return {}
		return {"neg": false, "tipo": "flag", "nombre": nf}
	var sw: PackedStringArray = t.split(".")
	if sw.size() != 2 or not por_id.has(sw[0]):
		_aviso_linea(avisos, n, l, "si=%s: tiene que ser <id>.<condición> de una pieza que existe" % t)
		return {}
	var pc: Pieza = por_id[sw[0]]
	if not CONDICIONES.has(pc.tipo) or not (CONDICIONES[pc.tipo] as Dictionary).has(sw[1]):
		_aviso_linea(avisos, n, l, "si=%s: una pieza «%s» no tiene la condición «%s»%s" % [t, pc.tipo, sw[1], (" (tiene: %s)" % ", ".join((CONDICIONES[pc.tipo] as Dictionary).keys())) if CONDICIONES.has(pc.tipo) else ""])
		return {}
	return {"neg": false, "tipo": "pieza", "id": pc.id, "cond": sw[1]}


## `casilla(x,y).<estado>`: la coma de dentro del paréntesis no separa nada (los separadores de términos son «+» y «|»).
static func _leer_casilla(t: String, n: int, l: String, avisos: Array) -> Dictionary:
	var ip: int = t.find(")")
	if ip < 0 or t.substr(ip + 1, 1) != ".":
		_aviso_linea(avisos, n, l, "si=%s: se escribe casilla(x,y).<estado>, por ejemplo casilla(3,4).mojada" % t)
		return {}
	var xy: PackedStringArray = t.substr(TERMINO_CASILLA.length() + 1, ip - TERMINO_CASILLA.length() - 1).split(",")
	if xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int():
		_aviso_linea(avisos, n, l, "si=%s: la casilla tiene que ser dos enteros, casilla(x,y)" % t)
		return {}
	var estado: String = t.substr(ip + 2)
	if not (estado in ESTADOS_CASILLA):
		_aviso_linea(avisos, n, l, "si=%s: estado de casilla desconocido «%s» (valen: %s)" % [t, estado, ", ".join(ESTADOS_CASILLA)])
		return {}
	return {"neg": false, "tipo": "casilla", "celda": Vector2i(int(xy[0]), int(xy[1])), "estado": estado}


static func _leer_accion(t: String, por_id: Dictionary, n: int, l: String, avisos: Array) -> Dictionary:
	var ref: String = t
	var args: Array = []
	var ip: int = t.find("(")
	# flag.poner(<nombre>) / flag.quitar(<nombre>) (C1): el argumento es un nombre, no un número.
	if t.begins_with(ID_FLAG + "."):
		var acc: String = t.substr(ID_FLAG.length() + 1, (ip if ip >= 0 else t.length()) - ID_FLAG.length() - 1)
		if not (acc in ACCIONES_FLAG):
			_aviso_linea(avisos, n, l, "hace=%s: las flags saben %s" % [t, ", ".join(ACCIONES_FLAG)])
			return {}
		if ip < 0 or not t.ends_with(")"):
			_aviso_linea(avisos, n, l, "hace=%s: se escribe flag.%s(<nivel.sala.hecho>)" % [t, acc])
			return {}
		var nf: String = t.substr(ip + 1, t.length() - ip - 2).strip_edges()
		if not Flags.nombre_valido(nf):
			_aviso_linea(avisos, n, l, "hace=%s: «%s» no es un nombre de flag (nivel.sala.hecho)" % [t, nf])
			return {}
		return {"id": ID_FLAG, "accion": acc, "args": [], "nombre": nf}
	if ip >= 0:
		if not t.ends_with(")"):
			_aviso_linea(avisos, n, l, "hace=%s: falta el «)»" % t)
			return {}
		ref = t.substr(0, ip)
		var dentro: String = t.substr(ip + 1, t.length() - ip - 2)
		for a in dentro.split(",", false):
			var s: String = String(a).strip_edges()
			if not s.is_valid_float():
				_aviso_linea(avisos, n, l, "hace=%s: el argumento «%s» no es un número" % [t, s])
				return {}
			args.append(float(s))
	var w: PackedStringArray = ref.split(".")
	if w.size() != 2 or not por_id.has(w[0]):
		_aviso_linea(avisos, n, l, "hace=%s: no hay ninguna pieza «%s» (se escribe <id>.<acción>)" % [t, w[0]])
		return {}
	var pz: Pieza = por_id[w[0]]
	if not ACCIONES.has(pz.tipo) or not (ACCIONES[pz.tipo] as Dictionary).has(w[1]):
		_aviso_linea(avisos, n, l, "hace=%s: una pieza «%s» no sabe «%s»%s" % [t, pz.tipo, w[1], (" (sabe: %s)" % ", ".join((ACCIONES[pz.tipo] as Dictionary).keys())) if ACCIONES.has(pz.tipo) else " (no tiene acciones)"])
		return {}
	var maximo: int = int((ACCIONES[pz.tipo] as Dictionary)[w[1]])
	if args.size() > maximo:
		_aviso_linea(avisos, n, l, "hace=%s: «%s» admite como mucho %d argumento(s)" % [t, w[1], maximo])
		return {}
	return {"id": pz.id, "accion": w[1], "args": args}


# ---------------------------------------------------------------------------------------------------------------------
#  Montar las piezas
# ---------------------------------------------------------------------------------------------------------------------

func _avisar(texto: String) -> void:
	avisos.append(texto)
	push_warning("Puzle3D: " + texto)
	aviso_nuevo.emit(texto)
	_pintar_avisos()


func _avisar_pieza(pz: Pieza, msg: String) -> void:
	_avisar("línea %d: pieza «%s» (%s): %s" % [pz.n, pz.id, pz.tipo, msg])


func _pintar_avisos() -> void:
	if not is_inside_tree():
		return
	if _hud == null:
		var capa := CanvasLayer.new()
		capa.layer = 7
		add_child(capa)
		_hud = Label.new()
		capa.add_child(_hud)
		_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_hud.offset_left = 12.0
		_hud.offset_bottom = -12.0
		_hud.add_theme_font_size_override("font_size", 14)
		_hud.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		_hud.add_theme_color_override("font_outline_color", Color.BLACK)
		_hud.add_theme_constant_override("outline_size", 6)
	var t: String = ""
	for a in avisos:
		t += "AVISO Puzle3D · %s\n" % String(a)
	_hud.text = t


func _contenedor() -> Node:
	if mundo is Object:
		var pr: Variant = (mundo as Object).get("_props")
		if pr is Node:
			return pr
	return mundo as Node


func _hay_agua() -> bool:
	return Terreno3D.agua_sim != null


## ¿La casilla de la pieza es válida? (dentro del mapa, no un muro, con la letra que la maqueta espera, y una casilla de agua si es una
## pieza de agua). Sin mapa montado no se puede mirar y se da por buena.
func _casilla_valida(pz: Pieza, c: Vector2i) -> bool:
	if not Terreno3D.hay_mundo():
		return true
	if not Terreno3D.en_mapa(c):
		_avisar_pieza(pz, "la casilla %s está fuera del mapa" % c)
		return false
	var letra: String = Terreno3D.letra_de(c)
	if letra == "#" or letra == " ":
		_avisar_pieza(pz, "la casilla %s es un muro" % c)
		return false
	var esperada: String = String(LETRA_MAQUETA.get(pz.tipo, ""))
	if esperada != "" and letra != esperada:
		_avisar_pieza(pz, "en %s esperaba la letra «%s» (la maqueta pone ahí la pieza) y hay «%s»" % [c, esperada, letra])
		return false
	if pz.tipo in NECESITAN_CAUCE and not (letra == "c" or letra == "~" or Terreno3D.es_canal(c)):
		_avisar_pieza(pz, "la casilla %s es «%s»: una pieza de agua va sobre un cauce «c», un canal «-»/«L» o un río «~»" % [c, letra])
		return false
	return true


func _crear(pz: Pieza) -> void:
	if pz.tipo in NECESITAN_AGUA and not _hay_agua():
		_avisar_pieza(pz, "no hay simulación de agua: la escena necesita agua_fisica = true")
		return
	var cont: Node = _contenedor()
	if cont == null:
		_avisar_pieza(pz, "no hay dónde colgar la pieza (el mundo no tiene `_props`)")
		return
	var celdas: Array = []
	if pz.p.has("celdas"):
		celdas = pz.p["celdas"]
	elif pz.tipo == "cuenca" or pz.tipo == "manantial":
		celdas = [pz.celda]
	var a_mirar: Array = [] if pz.tipo == "vigia" else [pz.celda]       # el vigía no ocupa sitio: su x,y es solo una referencia
	a_mirar.append_array(celdas)
	for c in a_mirar:
		if not _casilla_valida(pz, c as Vector2i):
			return
	match pz.tipo:
		"pulsador":
			var b := Pulsador3D.new()
			b.name = pz.id
			b.modelo = String(pz.p.get("modelo", ""))
			b.preparar(pz.celda, String(pz.p.get("modo", "magia")), float(pz.p.get("rearme", 0.0)))
			cont.add_child(b)
			pz.nodo = b
		"compuerta":
			var k := Compuerta3D.new()
			k.name = pz.id
			k.estrecha = bool(pz.p.get("estrecha", true))
			k.preparar(pz.celda, bool(pz.p.get("abierta", false)), String(pz.p.get("abre_con", "")), String(pz.p.get("cierra_con", "")), bool(pz.p.get("vertical", true)))
			cont.add_child(k)
			pz.nodo = k
		"nivel":
			var d := NivelAgua3D.new()
			d.name = pz.id
			d.preparar(pz.celda, float(pz.p.get("objetivo", 0.45)), float(pz.p.get("banda", 0.0)), bool(pz.p.get("invertido", false)))
			cont.add_child(d)
			pz.nodo = d
		"molino":
			var mo := Molino3D.new()
			mo.name = pz.id
			mo.preparar(pz.celda, float(pz.p.get("umbral", 0.3)), bool(pz.p.get("vertical", true)))
			cont.add_child(mo)
			pz.nodo = mo
		"barril":
			var ba := Barril3D.new()
			ba.name = pz.id
			ba.preparar(pz.celda)
			cont.add_child(ba)
			pz.nodo = ba
		"seta":
			var se := Recolectable3D.new()
			se.name = pz.id
			se.madura = bool(pz.p.get("madura", false))
			se.preparar(pz.celda, String(pz.p.get("variante", "")), float(pz.p.get("rebrota", 0.0)), mundo as Node)
			cont.add_child(se)
			pz.nodo = se
		"alga", "basalto":
			# Materiales de la Cueva (docs/MATERIALES_CUEVA.md): un Recolectable3D que solo existe mientras se cumple `coge_si`.
			var ma := Recolectable3D.new()
			ma.name = pz.id
			ma.coge_si = pz.exprs.get("coge_si", [])
			ma.puzle = self
			ma.preparar(pz.celda, "", float(pz.p.get("rebrota", 0.0)), mundo as Node, pz.tipo)
			cont.add_child(ma)
			pz.nodo = ma
		"lava":
			var lv := Lava3D.new()
			lv.name = pz.id
			lv.preparar(pz.p.get("celdas", [pz.celda]), float(pz.p.get("vuelve", 0.0)))
			cont.add_child(lv)
			pz.nodo = lv
		"muro":
			var mu := MuroAgrietado3D.new()
			mu.name = pz.id
			mu.preparar(pz.celda, int(pz.p.get("golpes", 2)), mundo as Node)
			cont.add_child(mu)
			pz.nodo = mu
		"nexo":
			var nx := NexoRayo3D.new()
			nx.name = pz.id
			nx.preparar(pz.celda)
			cont.add_child(nx)
			pz.nodo = nx
		"puerta":
			var pu := PuertaPuzle.new()
			pu.name = pz.id
			pu.preparar(pz.celda, String(pz.p.get("modelo", "")), mundo as Node)
			cont.add_child(pu)
			var abierto_flag: String = String(pz.p.get("abierto", pz.p.get("flag", "")))        # `flag=` es otro nombre de `abierto=`
			if pz.p.has("llave"):
				pu.configurar_llave(String(pz.p["llave"]), bool(pz.p.get("gasta", false)), abierto_flag)
			elif abierto_flag != "" or pz.p.has("gasta"):
				_avisar_pieza(pz, "«abierto=» (o «flag=») y «gasta=» solo valen con «llave=<flag>»")
			pz.nodo = pu
		"jarron", "caja":
			# `celdas=` pone uno en cada casilla (el primero es la pieza; los demás se llaman <id>_2, <id>_3…). `modelo=caja` en un jarrón lo vuelve caja.
			var tipo_r: String = "caja" if pz.tipo == "jarron" and String(pz.p.get("modelo", "")) == "caja" else pz.tipo
			var otro: bool = bool(pz.p.get("alto" if pz.tipo == "jarron" else "pequena", false))
			var cs: Array = pz.p.get("celdas", [pz.celda])
			for i in range(cs.size()):
				var ro := Rompible3D.new()
				ro.name = pz.id if i == 0 else "%s_%d" % [pz.id, i + 1]
				ro.preparar(cs[i] as Vector2i, tipo_r, String(pz.p.get("botin", Rompible3D.BOTIN_ORO)), int(pz.p.get("cantidad", 0.0)), otro, nivel, mundo as Node)
				cont.add_child(ro)
				if i == 0:
					pz.nodo = ro
				pz.nodos.append(ro)
		"salida":
			var destino: String = String(pz.p.get("a", ""))
			if destino == "" and pz.p.has("escena") and pz.p.has("entrada"):
				destino = "%s:%s" % [Niveles.nivel_de(String(pz.p["escena"])), String(pz.p["entrada"])]      # la otra forma: escena=<Nivel o escena> entrada=<nombre>
			if destino == "":
				_avisar_pieza(pz, "la salida necesita «a=<Nivel>:<entrada>» (o «escena=<Nivel>» y «entrada=<nombre>»)")
				return
			var sa := SalidaNivel3D.new()
			sa.name = pz.id
			sa.preparar(pz.p.get("celdas", [pz.celda]), destino, String(pz.p.get("modo", SalidaNivel3D.MODO_PISAR)), bool(pz.p.get("marca", true)), mundo as Node)
			cont.add_child(sa)
			pz.nodo = sa
		"entrada":
			var en := SalidaNivel3D.EntradaNivel3D.new()
			en.name = pz.id
			en.preparar(pz.celda, pz.id, String(pz.p.get("mira", "")))
			cont.add_child(en)
			pz.nodo = en
		"emisor":
			var em := EmisorRayo3D.new()
			em.name = pz.id
			cont.add_child(em)
			em.preparar(mundo, pz.celda)
			pz.nodo = em
		"cuenca":
			_abrir_celdas(celdas)
			var nivel_llenado: float = float(pz.p.get("nivel", -1.0))
			if nivel_llenado >= 0.0:
				for c in celdas:
					Terreno3D.agua_sim.llenar_casilla(c as Vector2i, _fondo(c as Vector2i) + nivel_llenado)
			if pz.p.has("fijo"):
				var f: Variant = pz.p["fijo"]
				var prof: float = nivel_llenado if f is bool else float(f)
				if prof < 0.0:
					_avisar_pieza(pz, "«fijo=si» necesita «nivel=<u>»")
				else:
					for c in celdas:
						Terreno3D.agua_sim.fijar_nivel(c as Vector2i, _fondo(c as Vector2i) + prof)
		"manantial":
			if bool(pz.p.get("sin_piedra", false)):
				_ocultar_piedra_canal(celdas, cont)
			if pz.p.has("bloque"):
				if float(pz.p.get("terraza", 0.0)) > 0.0:
					_levantar_terraza(pz.p["bloque"] as Array, float(pz.p["terraza"]), cont, bool(pz.p.get("pilares", false)), float(pz.p.get("espuma", 0.0)))
				if bool(pz.p.get("pilares", false)):
					_forma_cortinas(pz.p["bloque"] as Array)
				else:
					_forma_ancha(pz.p["bloque"] as Array)
			if bool(pz.p.get("inicia", true)):
				_abrir_cauce(pz, [])
		"tinaja":
			var t: Reactivo3D = _reactivo("surtidor", pz.celda)
			if t == null:
				_avisar_pieza(pz, "no hay tinaja de la maqueta en %s (letra «u»)" % pz.celda)
				return
			t.sin_arroyo()           # la maqueta no le da su arroyo propio: el cauce lo abre una regla (`abrir_cauce`)
			pz.nodo = t
		"totem":
			var to: Reactivo3D = _reactivo("totem", pz.celda)
			if to == null:
				_avisar_pieza(pz, "no hay tótem de la maqueta en %s (letra «i»)" % pz.celda)
				return
			pz.nodo = to
		"brasero":
			var br: Reactivo3D = _reactivo("brasero", pz.celda)
			if br == null:
				_avisar_pieza(pz, "no hay brasero de la maqueta en %s (letra «T»)" % pz.celda)
				return
			br.mult_luz = maxf(float(pz.p.get("luz", 1.0)), 0.1)
			if String(pz.p.get("modelo", "")) == "cueva":
				# 24/10 (tercera tanda): el brasero de la Cueva (`brasero_cueva`, 0,9 de alto) en vez del del Bosque (1,4). Solo cambia el modelo: sigue siendo el mismo Reactivo3D, con su luz, su
				# pulso de fuego y su caja de acierto; la llama y la luz bajan a la altura del cuenco nuevo.
				var raiz_b: Node3D = (mundo as Object).call("_pieza", "brasero_cueva") as Node3D if mundo is Object and (mundo as Object).has_method("_pieza") else null
				if raiz_b != null and raiz_b.get_child_count() > 0:
					var modelo_b: Node3D = raiz_b.get_child(0) as Node3D
					raiz_b.remove_child(modelo_b)
					raiz_b.free()
					br.cambiar_visual(modelo_b, [0.80, 0.55, 0.12, 0.95])
			pz.nodo = br
		"seto":
			var se: Reactivo3D = _reactivo("seto", pz.celda)
			if se == null:
				_avisar_pieza(pz, "no hay seto de la maqueta en %s (letra «z»)" % pz.celda)
				return
			se.mojable = bool(pz.p.get("mojable", false))
			pz.nodo = se
		"contador":
			if not pz.p.has("de"):
				_avisar_pieza(pz, "el contador necesita «de=<casillas>» (lo que cuenta)")
				return
			var lista: Array = []
			for c in (pz.p["de"] as Array):
				var o: Node = _encendible_en(c as Vector2i)
				if o == null:
					_avisar_pieza(pz, "no hay nada que arda en %s (brasero, fogata, seto…)" % (c as Vector2i))
				else:
					lista.append(o)
			if lista.is_empty():
				return
			var ct := ContadorReactivos3D.new()
			ct.name = pz.id
			ct.preparar(lista, int(pz.p.get("minimo", 0)), pz.celda)
			cont.add_child(ct)
			pz.nodo = ct
			# Respuesta positiva: subir sin completar = «vas bien»; completar = puzle resuelto. `previos` guarda la cuenta anterior (la señal solo trae la nueva).
			var previos: Array = [ct.encendidos]
			ct.cambio.connect(func(enc: int, _total: int) -> void:
				if enc > int(previos[0]) and enc < ct.minimo:
					Puzle3D._logro("paso_puzle", ct)
				previos[0] = enc)
			ct.todos.connect(func(si: bool) -> void:
				if si:
					Puzle3D._logro("puzle_resuelto", ct))
		"cuerda":
			var cu := Cuerda3D.new()
			cu.name = pz.id
			cu.preparar(pz.celda, null)
			cont.add_child(cu)
			pz.nodo = cu
		"vigia":
			if not pz.p.has("de"):
				_avisar_pieza(pz, "el vigía necesita «de=<casillas>» (la casilla de partida de los enemigos que vigila)")
				return
			var vg := VigiaPuzle.new()
			vg.name = pz.id
			vg.preparar(pz.p["de"], String(pz.p.get("flag", "")))
			vg.aviso.connect(_avisar)
			cont.add_child(vg)
			if vg.completo:
				vg.retirar_enemigos()              # sala ya limpia: no se repuebla al volver (de otro nivel o de una partida guardada)
			pz.nodo = vg
		"cerrojo":
			if not pz.p.has("celdas"):
				_avisar_pieza(pz, "el cerrojo necesita «celdas=<casillas>» (las puertas de la sala)")
				return
			var cj := CerrojoPuzle.new()
			cj.name = pz.id
			cont.add_child(cj)
			cj.preparar(pz.p["celdas"], pz.p.get("sala", []), String(pz.p.get("hasta", "")), mundo)
			pz.nodo = cj
		"cofre":
			var cf := CofrePuzle.new()
			cf.name = pz.id
			cont.add_child(cf)
			cf.calidad = String(pz.p.get("modelo", ""))      # `modelo=epico|legendario` es también su calidad (columna de luz y motas de su color)
			cf.preparar(pz.celda, pz.exprs.get("aparece_si", []), String(pz.p.get("abierto", "")), self, mundo,
				String(ESCENAS_COFRE_CUEVA.get(String(pz.p.get("modelo", "")), ESCENA_COFRE)), pz.exprs.get("abre_si", []), String(pz.p.get("glifo", "")))
			cf.da = pz.p.get("da", [])
			pz.nodo = cf
		"cristal":
			var cr := CristalPulso3D.new()
			cr.name = pz.id
			cr.nivel = nivel
			cr.preparar(pz.celda, float(pz.p.get("cada", CristalPulso3D.CADA_DEFECTO)), int(pz.p.get("alcance", Pulso3D.ALCANCE_DEFECTO)), mundo as Node)
			cont.add_child(cr)
			pz.nodo = cr
		"veta":
			var ve := VetaPulso3D.new()
			ve.name = pz.id
			ve.preparar(pz.p.get("celdas", [pz.celda]), pz.p.get("enlaces", []), float(pz.p.get("aturde", 0.0)), bool(pz.p.get("mineral", false)), nivel)
			cont.add_child(ve)
			pz.nodo = ve
		"columna":
			var co := MuroAgrietado3D.new()
			co.name = pz.id
			co.como_columna(String(pz.p.get("cae", "s")))
			co.preparar(pz.celda, int(pz.p.get("golpes", 2)), mundo as Node)
			cont.add_child(co)
			pz.nodo = co
		"estalagmita":
			var eg := EstalagmitaPulso3D.new()
			eg.name = pz.id
			eg.preparar(pz.celda, String(pz.p.get("cae", "")), String(pz.p.get("flag", "")), mundo as Node)
			cont.add_child(eg)
			pz.nodo = eg
		"estatuas":
			if not pz.p.has("celdas") or not pz.p.has("secuencia") or (pz.p["celdas"] as Array).size() != (pz.p["secuencia"] as Array).size():
				_avisar_pieza(pz, "las estatuas necesitan «celdas=<casillas>» y «secuencia=<elementos>» con el mismo número de cada (una estatua por casilla)")
				return
			var es := EstatuasPulso3D.new()
			es.name = pz.id
			es.preparar(pz.p["celdas"], pz.p["secuencia"], String(pz.p.get("flag", "")), mundo as Node)
			cont.add_child(es)
			pz.nodo = es
		"receptor":
			var rc := ReceptorPulso3D.new()
			rc.name = pz.id
			rc.preparar(pz.celda, String(pz.p.get("elemento", "")), String(pz.p.get("flag", "")), float(pz.p.get("rearme", 0.0)), mundo as Node)
			cont.add_child(rc)
			pz.nodo = rc
		"prisma":
			var pr := PrismaPulso3D.new()
			pr.name = pz.id
			pr.preparar(pz.celda, String(pz.p.get("dir", PrismaPulso3D.DIR_DEFECTO)), mundo as Node)
			cont.add_child(pr)
			pz.nodo = pr
		"decorado":
			# 24/10 (tercera tanda): una pieza de adorno sin mecánica (la geoda de C3, las estalagmitas de C4…): solo el modelo, en su casilla, a ras de suelo. No bloquea.
			var dec: Node3D = _colocar_pieza(String(pz.p["modelo"]) if pz.p.has("modelo") else "", cont, pz.id,
				Terreno3D.centro_de(pz.celda, Terreno3D.y_pies(pz.celda) - 0.02), float(pz.p.get("giro", 0.0)), Vector3.ONE * float(pz.p.get("escala", 1.0)))
			if dec == null:
				_avisar_pieza(pz, "decorado necesita «modelo=<pieza>» y que la pieza exista")
				return
			pz.nodo = dec
		"pared_hueca":
			var ph := ParedHuecaPulso3D.new()
			ph.name = pz.id
			ph.preparar(pz.celda, String(pz.p.get("flag", "")), mundo as Node, String(pz.p.get("mira", "")))
			cont.add_child(ph)
			pz.nodo = ph


## Avisa de un logro (ver arriba). `nodo` = la pieza que lo origina: de ella sale el punto (1 u por encima de su base) para destello y sonido.
static func _logro(nombre: String, nodo: Node = null) -> void:
	if silencio_logros:
		return
	var f: int = Engine.get_process_frames()
	if _logro_en.has(nombre) and f - int(_logro_en[nombre]) <= VENTANA_LOGRO:
		return
	_logro_en[nombre] = f
	var punto: Vector3 = Vector3.ZERO
	if nodo is Node3D:
		var n3: Node3D = nodo as Node3D
		punto = (n3.global_position if n3.is_inside_tree() else n3.position) + Vector3(0.0, 1.0, 0.0)
	Mundo3D.avisar_logro(nombre, punto, nodo)


## Lo que arde (o puede arder) en una casilla y tiene `is_lit`: un brasero, una fogata, un seto, una cuerda… `null` si no hay nada.
func _encendible_en(c: Vector2i) -> Node:
	for grupo in [Reactivo3D.GRUPO_REACTIVO, Reactivo3D.GRUPO_ARDE]:
		for n in get_tree().get_nodes_in_group(String(grupo)):
			if is_instance_valid(n) and n.get("celda") == c and n.get("is_lit") != null:
				return n
	return null


## Segunda pasada: enlaza lo que apunta a otra pieza. Un enlace que no se puede hacer es un aviso, no un fallo.
func _enlazar(pz: Pieza) -> void:
	if not is_instance_valid(pz.nodo):
		return
	match pz.tipo:
		"cofre":
			(pz.nodo as CofrePuzle).arrancar()      # ya están todas las piezas: aparece_si puede mirarlas
		"brasero":
			if not (pz.p.has("rele") or pz.p.has("dura") or pz.p.has("espera")):
				return
			var siguiente: Reactivo3D = null
			if pz.p.has("rele"):
				var ps: Pieza = _piezas.get(pz.p["rele"], null)
				if ps == null or ps.tipo != "brasero" or not is_instance_valid(ps.nodo):
					_avisar_pieza(pz, "rele=%s: no es un brasero que se haya montado" % pz.p["rele"])
				else:
					siguiente = ps.nodo as Reactivo3D
			(pz.nodo as Reactivo3D).configurar_rele(siguiente, float(pz.p.get("espera", Reactivo3D.T_RELE_ESPERA)), float(pz.p.get("dura", Reactivo3D.T_RELE_DURA)))
		"cuerda":
			if not pz.p.has("sostiene"):
				return
			var po: Pieza = _piezas.get(pz.p["sostiene"], null)
			if po == null or not is_instance_valid(po.nodo) or not (po.nodo.has_method("tender") or po.nodo.has_method("cerrar")):
				_avisar_pieza(pz, "sostiene=%s: tiene que ser una compuerta o un puente que se haya montado" % pz.p["sostiene"])
			else:
				(pz.nodo as Cuerda3D).sostiene = po.nodo


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	for r in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(r) and String(r.get("tipo")) == tipo and r.get("celda") == c:
			return r
	return null


## Profundidad 0 de una casilla de agua: el fondo del cajón de un canal de ruinas, o el lecho de un cauce «c».
func _fondo(c: Vector2i) -> float:
	if Terreno3D.es_canal_ruinas(c):
		return Terreno3D.fondo_canal_en(c)
	return Terreno3D.alto_agua - Terreno3D.LECHO_AGUA


## 24/10 (Pablo: «la cascada de C2 sin el puente de ruinas»): el canal `-` de la Cueva sigue siendo canal para la simulación (el agua corre por su cajón y cae al
## pozo), pero su PIEZA de ruinas (la losa con barandillas de musgo, que en la cueva se leía como un puente) no se dibuja en `celdas`: el agua corre a ras de suelo,
## saliendo de la pared. Las piezas van por lotes (un MultiMesh por trozo del mapa): se anula la copia de esa casilla (escala 0) sin tocar las demás.
## Se apunta en `piedras_ocultas` (casilla -> true) para que las pruebas lo vean sin leer el MultiMesh (sin GPU no se puede).
static var piedras_ocultas: Dictionary = {}

func _ocultar_piedra_canal(celdas: Array, cont: Node) -> void:
	var lotes: Variant = (mundo as Object).get("_lotes") if mundo is Object else null
	var lado_bloque: float = float((mundo as Object).get("BLOQUE_LOTE")) if mundo is Object and (mundo as Object).get("BLOQUE_LOTE") != null else Terreno3D.casilla * 7.0
	if not (lotes is Dictionary):
		return
	for c in celdas:
		piedras_ocultas[c] = true
	for id in ["canal_recto", "canal_codo"]:
		if not (lotes as Dictionary).has(id):
			continue
		for n in cont.get_children():
			var nombre: String = String(n.name)
			if not (n is MultiMeshInstance3D) or not nombre.begins_with("lote_%s_" % id):
				continue
			var k: PackedStringArray = nombre.trim_prefix("lote_%s_" % id).trim_suffix("_sombra").split("_")
			if k.size() != 2:
				continue
			# Las copias del trozo, en el orden en que `_construir_lotes` las puso (el mismo que el de las instancias del MultiMesh).
			var copias: Array = []
			for t in ((lotes as Dictionary)[id] as Array):
				var o: Vector3 = (t as Transform3D).origin
				if floori(o.x / lado_bloque) == int(k[0]) and floori(o.z / lado_bloque) == int(k[1]):
					copias.append(t)
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			for i in range(mini(copias.size(), mm.instance_count)):
				var o2: Vector3 = (copias[i] as Transform3D).origin
				if celdas.has(Terreno3D.celda_de(o2)):
					mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), o2))


## 24/10 (tercera tanda): pone una pieza del decorado (la que da `PruebaTest2._pieza`: ya a su MEDIDA, con la base en y = 0 y centrada en x/z) en `pos`, girada `giro` grados y con la escala
## `escala` (por eje: se ajusta a un alto, un ancho o un fondo). null si no hay maqueta o falta la pieza.
func _colocar_pieza(id: String, cont: Node, nombre: String, pos: Vector3, giro: float, escala: Vector3) -> Node3D:
	if not (mundo is Object) or not (mundo as Object).has_method("_pieza"):
		return null
	var n: Node3D = (mundo as Object).call("_pieza", id) as Node3D
	if n == null:
		return null
	n.name = nombre
	n.position = pos
	n.rotation.y = deg_to_rad(giro)
	n.scale = escala
	cont.add_child(n)
	if id in ["pilar_cascada", "pilar_cascada_ancho", "musgo_colgante"]:
		_apagar_verde(n)
	return n


## El musgo de estas piezas sale verde brillante, fuera de la paleta azul de la Cueva: se multiplica el albedo de sus materiales por un tinte azulado (rojo y verde abajo, azul casi igual), así el
## verde pasa a verde-azulado oscuro y la piedra azul apenas cambia. Por material (copia propia de cada superficie), como el apagado del cristal (`BrilloPulso3D`), no con una luz.
const TINTE_MUSGO: Color = Color(0.48, 0.70, 0.95)

func _apagar_verde(n: Node3D) -> void:
	for h in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(s)
			if m is StandardMaterial3D:
				var copia: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				copia.albedo_color = copia.albedo_color * TINTE_MUSGO
				mi.set_surface_override_material(s, copia)


## La lámina de agua de la tapa de una terraza (`_levantar_terraza`). Sin luz (unshaded) como la cortina: la Cueva está casi a oscuras y el agua tiene que leerse. El flujo va hacia +Z (el sur, el labio).
const CODIGO_TAPA_TERRAZA: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec3 color_hondo : source_color = vec3(0.12, 0.50, 0.85);     // los de la cortina de AguaRender3D (CODIGO_CORTINA): sin cambio de tono en la unión
uniform vec3 color_claro : source_color = vec3(0.78, 0.95, 1.0);
uniform float velocidad = 0.9;
uniform float delantal = 0.0;       // 1 = es el delantal vertical: se desvanece de arriba (UV.y 0) a abajo (UV.y 1)

varying vec3 v_pos;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// El mismo hash entero que la cortina de AguaRender3D: el de `sin` pierde precisión en la GPU y sale a cuadros.
const float HASH_CUANTO = 256.0;
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p * HASH_CUANTO + 0.5)));
	uint h = q.x * 1597334673u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h >> 8u) * (1.0 / 16777216.0);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Vetas alargadas a lo largo del flujo: poco frecuentes en Z (estiradas), más en X.
	float f1 = smoothstep(0.58, 0.80, ruido(vec2(v_pos.x * 4.2, v_pos.z * 0.30 - TIME * velocidad)));
	float f2 = smoothstep(0.62, 0.82, ruido(vec2(v_pos.x * 8.0 + 4.1, v_pos.z * 0.55 - TIME * velocidad * 1.6)));
	float veta = clamp(max(f1, f2 * 0.8), 0.0, 1.0);
	// Rizos finos que cruzan la corriente.
	float rizo = smoothstep(0.64, 0.9, ruido(vec2(v_pos.x * 1.4 + TIME * 0.2, v_pos.z * 1.6 - TIME * velocidad * 0.5)));
	vec3 col = mix(color_hondo, color_claro, clamp(veta * 0.75 + rizo * 0.25, 0.0, 1.0));
	ALBEDO = col;
	// 2.ª pasada: una lámina FINA, no un bloque azul: donde no hay veta se ve la roca del canal; las vetas (y los rizos) son agua. Se aclara hacia el labio (v_pos.z lo da la malla: UV.y 1 = sur).
	// 5.ª pasada: hacia el final la lámina se funde (alfa → alfa de la cortina de debajo, que es ~0,34 + vetas) en vez de sumarse a ella: sin franja clara en la unión.
	// Primero se probó fundirla, pero entonces arriba quedaba más transparente que la cortina y el cambio de tono se veía igual: ahora tiene el MISMO alfa que la cortina (0,34 + 0,5 × veta), sin fundido.
	ALPHA = clamp(0.34 + veta * 0.50 + rizo * 0.08, 0.0, 0.9) * mix(1.0, 1.0 - UV.y, delantal);     // el delantal se desvanece hacia abajo mientras la cortina aparece (cruce, no suma)
}
"""

const PILAR_SOBRE_TERRAZA: float = 1.5       ## cuánto sobresale un pilar por encima del fondo del canal (u)
const PILAR_LARGO: float = 1.5               ## cuánto se mete un pilar hacia el norte desde el labio de la cornisa (u)
const ESPUMA_ATRAS: float = 0.45             ## cuánto se mete la espuma bajo el labio (hacia la roca), para tapar el borde claro de la superficie del pozo (la «pastilla»)
const ESPUMA_SOBRE: float = 0.12            ## y cuánto sube sobre la superficie del pozo
const ESPUMA_LARGO: float = 1.3            ## hasta dónde llega la franja de espuma por el pozo, desde la cortina (u)

## La espuma al pie de una cortina (`_levantar_terraza`): una franja blanca OPACA pegada a la caída, hecha de burbujas que respiran, y aros que se abren por el pozo. UV.x a lo ancho, UV.y = 0 en la cortina y 1 al fondo.
const CODIGO_ESPUMA_PIE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

varying vec3 v_pos;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

const float HASH_CUANTO = 256.0;
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p * HASH_CUANTO + 0.5)));
	uint h = q.x * 1597334673u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h = h ^ (h >> 16u);
	return float(h >> 8u) * (1.0 / 16777216.0);
}

// x = distancia al borde de la burbuja más cercana, y = su id.
vec2 voronoi(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(ip + g), hash(ip + g + 7.7));
			o = 0.5 + 0.45 * sin(TIME * (0.8 + o * 1.4) + 6.2831 * o);
			float d = length(g + o - fp);
			if (d < d1) {
				d1 = d;
				id = hash(ip + g + 3.1);
			}
		}
	}
	return vec2(d1, id);
}

void fragment() {
	float d = UV.y;
	float lateral = smoothstep(0.0, 0.10, UV.x) * smoothstep(1.0, 0.90, UV.x);
	// Franja sólida junto a la caída y burbujas que se ralean hacia fuera.
	vec2 v = voronoi(v_pos.xz * 4.2);
	float burbuja = 1.0 - smoothstep(0.20, 0.34, v.x);
	float solida = 1.0 - smoothstep(0.10, 0.34, d + (v.y - 0.5) * 0.18);
	float ralo = (1.0 - smoothstep(0.25, 1.0, d)) * (0.35 + 0.65 * v.y);
	float espuma = clamp(solida + burbuja * ralo * 1.4, 0.0, 1.0);
	// Aros que salen de la caída y se abren por el pozo.
	float r = fract(d * 2.2 - TIME * 0.45);
	float aro = smoothstep(0.0, 0.05, r) * (1.0 - smoothstep(0.05, 0.14, r)) * (1.0 - smoothstep(0.1, 0.9, d));
	float a = clamp(espuma + aro * 0.55, 0.0, 1.0) * lateral;
	ALBEDO = mix(vec3(0.78, 0.92, 1.0), vec3(1.0), espuma);
	ALPHA = a * (1.0 - smoothstep(0.82, 1.0, d));
}
"""


## 24/10: sube el fondo del canal de las casillas del `bloque` `alto` u sobre el suelo y pone debajo un bloque de roca de cueva (la pared del foso, la misma piedra mojada que los costados de
## las charcas): una TERRAZA con el agua encima. Así la cascada cae `alto` u más al pozo y se ve desde la cámara (con un solo escalón de suelo a pozo, 1 u, la cortina medía una franja).
## Las casillas se bloquean (no se pisan: el fondo del canal queda a la altura de un nivel) y la simulación relee su suelo. Se hace UNA vez por bloque (hay un manantial por carril).
func _levantar_terraza(bloque: Array, alto: float, cont: Node, pilares: bool = false, nivel_pozo: float = 0.0) -> void:
	var nombre: String = "terraza_%d_%d" % [(bloque[0] as Vector2i).x, (bloque[0] as Vector2i).y]
	if cont.has_node(nombre):
		return
	var x0: int = 9999
	var y0: int = 9999
	var x1: int = -9999
	var y1: int = -9999
	for c in bloque:
		x0 = mini(x0, (c as Vector2i).x)
		y0 = mini(y0, (c as Vector2i).y)
		x1 = maxi(x1, (c as Vector2i).x)
		y1 = maxi(y1, (c as Vector2i).y)
		Terreno3D.elevacion_canal[c] = alto
		Terreno3D.bloquear_celda(c as Vector2i)
		if Terreno3D.agua_sim != null:
			Terreno3D.agua_sim.refrescar_casilla(c as Vector2i)
	var s: float = Terreno3D.casilla
	var esq: Vector3 = Terreno3D.centro_de(Vector2i(x0, y0), 0.0) - Vector3(s * 0.5, 0.0, s * 0.5)
	var ancho: float = float(x1 - x0 + 1) * s
	var fondo: float = float(y1 - y0 + 1) * s - 0.03          # 3 cm menos al sur: la cortina cae por delante de la cara de roca, no dentro
	var y_base: float = Terreno3D.alto_suelo - 0.1
	var y_tope: float = Terreno3D.alto_suelo + alto + Terreno3D.FONDO_CANAL - 0.02     # un pelo bajo el fondo del canal: la lámina de agua se apoya en la roca
	var caja := BoxMesh.new()
	caja.size = Vector3(ancho, y_tope - y_base, fondo)
	var bloque_roca := MeshInstance3D.new()
	bloque_roca.name = nombre
	bloque_roca.mesh = caja
	bloque_roca.position = esq + Vector3(ancho * 0.5, (y_base + y_tope) * 0.5, fondo * 0.5)
	var mat: StandardMaterial3D = null
	if mundo is Object and (mundo as Object).has_method("_mat_triplanar"):
		mat = (mundo as Object).call("_mat_triplanar", "res://arte/suelo_meshy/pared_foso_cueva.png", Color(0.3, 0.33, 0.4)) as StandardMaterial3D
	if mat != null:
		mat.uv1_scale = Vector3(1.0, 2.0, 1.0) / (s * 2.0)          # la textura es 2:1: se estira en vertical para que las piedras no salgan alargadas (como el costado de las charcas)
		mat.albedo_color = mat.albedo_color * 2.6                    # y se aclara: con la luz de la cueva se perdía en negro
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.33, 0.4)
	bloque_roca.material_override = mat
	cont.add_child(bloque_roca)
	# Segunda pasada (24/10, Pablo: «varias cortinas entre pilares de roca, espuma blanca fuerte al pie, sin el bloque azul plano de arriba»). Con `pilares`, cada tercio de casilla cuyo número de
	# columna es múltiplo de 4 es un PILAR (ver `_forma_cortinas`: la simulación lo cierra) y las columnas entre dos pilares son una CORTINA de una casilla. Arriba ya no hay una tapa azul opaca: cada
	# cortina trae una lámina fina de agua (casi transparente donde no hay veta, así se ve la roca del canal) con vetas que corren hacia el labio.
	# La «pastilla» clara sobre la espuma (3.ª pasada): es el borde de la superficie inclinada de la caída que el renderizador de agua deja pasar (descarta solo lo que cae ≥ 0,45) cuando la
	# cortina es tan alta; en esta terraza se descarta todo lo que tenga algo de caída (> 0: la «pastilla» es una superficie casi plana, apenas inclinada, que `caida` valora poco), y solo en esta instancia del renderizador (los ríos y cascadas del Bosque conservan el 0,45).
	for n in (mundo as Node).find_children("*", "MeshInstance3D", true, false):
		if n.get_script() != null and String((n.get_script() as Script).resource_path).ends_with("agua_render_3d.gd"):
			n.call("ajustar", "caida_descarte", 0.0)
			n.call("ajustar_cortina", "labio_fuerza", 0.0)      # 5.ª pasada: sin el aclarado del labio, la cortina sigue a la lámina de la cornisa sin franja clara
			n.call("ajustar_cortina", "fundido_arriba", 0.06)   # 6.ª: y sin borde superior: la cortina aparece en el 6 % de arriba (≈ 0,12 u) mientras el delantal de la lámina se apaga: un cruce, no una suma
	var tercio: float = s / 3.0
	var n_col: int = (x1 - x0 + 1) * 3
	var lip_z: float = esq.z + fondo + 0.03
	var y_agua_pozo: float = Terreno3D.fondo_cauce() + nivel_pozo + 0.02
	var sh_film := Shader.new()
	sh_film.code = CODIGO_TAPA_TERRAZA
	var sh_espuma := Shader.new()
	sh_espuma.code = CODIGO_ESPUMA_PIE
	var mat_roca: Material = mat
	var cortinas: Array = []                        # [x_ini, ancho] de cada cortina, en x de mundo
	if pilares:
		var k: int = 0
		while k < n_col:
			if k % 4 == 0:
				# Pilares: las piezas de la tercera tanda (hoja F1; antes eran cajas). `pilar_cascada` en el centro (se escala a una columna de agua, 0,77 u) y `pilar_cascada_ancho` en los flancos
				# (1,15 u: la mitad pegada a la cortina, el resto asoma hacia la pared del canal o hacia la sala). Cada una con un giro y una escala algo distintos para que no se repitan.
				var flanco_o: bool = k == 0
				var flanco_e: bool = k == n_col - 1
				var id_p: String = "pilar_cascada_ancho" if (flanco_o or flanco_e) else "pilar_cascada"
				var ancho_p: float = 1.15 if (flanco_o or flanco_e) else tercio * 1.08
				var nat_x: float = 1.749 if (flanco_o or flanco_e) else 1.049        # medidas del modelo ya a su MEDIDA (diag de 24/10)
				var nat_z: float = 2.051 if (flanco_o or flanco_e) else 1.343
				var largo_p: float = 1.65
				var cx: float = esq.x + (float(k) + 0.5) * tercio
				if flanco_o:
					cx = esq.x + tercio - ancho_p * 0.5
				elif flanco_e:
					cx = esq.x + ancho - tercio + ancho_p * 0.5
				var vari: float = float((k * 37) % 7 - 3) * 0.012
				var pilar: Node3D = _colocar_pieza(id_p, cont, "%s_pilar_%d" % [nombre, k / 4],
					Vector3(cx, y_base, lip_z + 0.09 - largo_p * 0.5), float((k * 53) % 9 - 4), Vector3(ancho_p / nat_x, 1.0 + vari, largo_p / nat_z))
				if pilar == null:
					# Sin la pieza (otra biblioteca, pruebas sin maqueta): la caja de siempre.
					var cajap := MeshInstance3D.new()
					cajap.name = "%s_pilar_%d" % [nombre, k / 4]
					var cp := BoxMesh.new()
					var alto_pilar: float = (y_tope - y_base) + PILAR_SOBRE_TERRAZA
					cp.size = Vector3(tercio, alto_pilar, largo_p)
					cajap.mesh = cp
					cajap.material_override = mat_roca
					cajap.position = Vector3(esq.x + (float(k) + 0.5) * tercio, y_base + alto_pilar * 0.5, lip_z + 0.09 - largo_p * 0.5)
					cont.add_child(cajap)
				else:
					# El musgo que cuelga por delante de la cabeza del pilar (`musgo_colgante`), sin tapar el agua: queda en la cara frontal del pilar, por encima de la cortina.
					_colocar_pieza("musgo_colgante", cont, "%s_musgo_%d" % [nombre, k / 4], Vector3(cx, y_base + 3.1 - 0.80, lip_z + 0.10), float((k * 29) % 11 - 5),
						Vector3(minf(ancho_p, 0.95) / 0.7526, 1.0, 0.45))
					# Las rocas que asoman del agua al pie de cada pilar (`rocas_salpicadura`): en el pozo, a ~1 u de la caída, fuera del grueso de la espuma.
					_colocar_pieza("rocas_salpicadura", cont, "%s_rocas_%d" % [nombre, k / 4], Vector3(cx + float((k * 13) % 5 - 2) * 0.08, y_agua_pozo - 0.30, lip_z + 1.0 + float(k % 3) * 0.12),
						float((k * 71) % 360), Vector3.ONE * (0.9 + float((k * 17) % 5) * 0.06))
				k += 1
			else:
				var k0: int = k
				while k < n_col and k % 4 != 0:
					k += 1
				cortinas.append([esq.x + float(k0) * tercio, float(k - k0) * tercio])
	else:
		cortinas.append([esq.x, ancho])
	var i_c: int = 0
	for ct in cortinas:
		var x_ini: float = ct[0]
		var an: float = ct[1]
		var xc: float = x_ini + an * 0.5
		var film := MeshInstance3D.new()
		film.name = "%s_agua_%d" % [nombre, i_c]
		var pl := PlaneMesh.new()
		# 4.ª pasada (Pablo: «¿qué es la línea negra entre la cascada?»): la lámina acababa en el borde de la roca (lip_z − 0,06) y la cortina vertical empieza en lip_z: entre las dos asomaba la
		# roca oscura del canto de la cornisa. La lámina llega ahora hasta pasado el plano de la cortina (+0,04) y las dos se solapan.
		var largo_film: float = (lip_z + 0.06) - esq.z
		pl.size = Vector2(an, largo_film)
		film.mesh = pl
		film.position = Vector3(xc, y_tope + 0.03, esq.z + largo_film * 0.5)
		var m_film := ShaderMaterial.new()
		m_film.shader = sh_film
		film.material_override = m_film
		film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cont.add_child(film)
		# Un delantal vertical de la misma agua (0,16 u) que cae por el canto de la roca justo bajo el labio: tapa la grieta oscura del canto, que se veía como un hilo negro en la unión.
		var delantal := MeshInstance3D.new()
		delantal.name = "%s_delantal_%d" % [nombre, i_c]
		var qd := QuadMesh.new()
		qd.size = Vector2(an, 0.12)
		delantal.mesh = qd
		delantal.position = Vector3(xc, y_tope + 0.03 - 0.06, lip_z + 0.055)
		var m_delantal := ShaderMaterial.new()
		m_delantal.shader = sh_film
		m_delantal.set_shader_parameter("delantal", 1.0)
		delantal.material_override = m_delantal
		delantal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cont.add_child(delantal)
		# La ESPUMA al pie: una franja blanca opaca y burbujeante pegada a la cortina, con aros que se abren por el pozo, y un surtidor de salpicaduras.
		var esp := MeshInstance3D.new()
		esp.name = "%s_espuma_%d" % [nombre, i_c]
		var pe := PlaneMesh.new()
		pe.size = Vector2(an + 0.5, ESPUMA_LARGO + ESPUMA_ATRAS)
		esp.mesh = pe
		esp.position = Vector3(xc, y_agua_pozo + ESPUMA_SOBRE, lip_z + ESPUMA_LARGO * 0.5 - ESPUMA_ATRAS * 0.5)
		var m_esp := ShaderMaterial.new()
		m_esp.shader = sh_espuma
		m_esp.render_priority = 2
		esp.material_override = m_esp
		esp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cont.add_child(esp)
		var chorro := CPUParticles3D.new()
		chorro.name = "%s_salpicaduras_%d" % [nombre, i_c]
		chorro.position = Vector3(xc, y_agua_pozo + 0.05, lip_z + 0.15)
		chorro.amount = 36
		chorro.lifetime = 0.9
		chorro.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		chorro.emission_box_extents = Vector3(an * 0.45, 0.04, 0.12)
		chorro.direction = Vector3(0.0, 1.0, 0.7)
		chorro.spread = 32.0
		chorro.initial_velocity_min = 1.8
		chorro.initial_velocity_max = 3.4
		chorro.gravity = Vector3(0.0, -9.0, 0.0)
		chorro.scale_amount_min = 0.5
		chorro.scale_amount_max = 1.5
		var esf := SphereMesh.new()
		esf.radius = 0.07
		esf.height = 0.14
		esf.radial_segments = 8
		esf.rings = 4
		var m_gota := StandardMaterial3D.new()
		m_gota.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_gota.albedo_color = Color(0.92, 0.98, 1.0)
		esf.material = m_gota
		chorro.mesh = esf
		chorro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cont.add_child(chorro)
		# El borde de la cornisa por donde rebosa el agua (`labio_cascada`, una casilla de largo): una losa baja pegada al canto, con su cara de arriba justo por debajo de la lámina de agua
		# (que pasa por encima) y su frente a ras del plano de la cortina: no tapa el agua, solo le da una piedra gastada debajo.
		_colocar_pieza("labio_cascada", cont, "%s_labio_%d" % [nombre, i_c], Vector3(xc, y_tope + 0.012 - 0.34, lip_z - 0.02 - 0.28), float(i_c) * 180.0,
			Vector3(an / 2.3, 0.34, 0.56 / 2.194))
		i_c += 1
	# Los helechos (`helechos_cueva`) en los bordes del pozo: uno en el borde este (junto al suelo de la sala) y otro en el sur, sobre el suelo, y nunca dentro del agua.
	var y_suelo: float = Terreno3D.alto_suelo - 0.02
	_colocar_pieza("helechos_cueva", cont, "%s_helecho_0" % nombre, Vector3(esq.x + ancho + 0.28, y_suelo, lip_z + 0.9), 20.0, Vector3.ONE * 1.1)
	_colocar_pieza("helechos_cueva", cont, "%s_helecho_1" % nombre, Vector3(esq.x + ancho * 0.3, y_suelo, lip_z + 2.0 * s + 0.35), 200.0, Vector3.ONE * 0.9)


## Segunda pasada (24/10): como `_forma_ancha` pero con PILARES. En el ancho del `bloque` (3 trocitos por casilla) quedan cerrados los trocitos cuya columna es múltiplo de 4 (columna 0 = el
## primer tercio de la primera casilla): con 3 casillas son 9 columnas, pilares en 0, 4 y 8 y dos cortinas de una casilla (columnas 1-3 y 5-7). La profundidad (norte-sur) queda toda abierta.
func _forma_cortinas(bloque: Array) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null or bloque.is_empty():
		return
	var x0: int = 9999
	for c in bloque:
		x0 = mini(x0, (c as Vector2i).x)
	for c in bloque:
		var abiertos: Array = []
		for sx in range(3):
			if (((c as Vector2i).x - x0) * 3 + sx) % 4 != 0:
				for sy in range(3):
					abiertos.append(Vector2i(sx, sy))
		sim.abrir_trocitos(c as Vector2i, abiertos, false)


## 24/10: un canal de ruinas es ESTRECHO para la simulación (un carril central de un tercio de casilla: el cajón de la pieza), y una cortina de un tercio de casilla no se ve
## desde la cámara. Aquí las casillas del `bloque` forman UNA lámina ancha: cada una abre sus 9 trocitos salvo por el lado donde linda con suelo pisable (ahí queda cerrado el tercio del
## borde: el agua no se sale a la sala). Se abre a su vecina del bloque, al muro de detrás (norte: ahí nace) y a una cuenca `c` (sur: la caída).
func _forma_ancha(bloque: Array) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	for c in bloque:
		var abre: Dictionary = {}
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = (c as Vector2i) + (d as Vector2i)
			var letra: String = Terreno3D.letra_de(n)
			abre[d] = bloque.has(n) or (d == Vector2i(0, -1) and letra == "#") or (d == Vector2i(0, 1) and letra == "c")
		var lados: Array = []
		for d in abre:
			if abre[d]:
				lados.append(d)
		for dx in [-1, 1]:
			for dy in [-1, 1]:
				if abre[Vector2i(dx, 0)] and abre[Vector2i(0, dy)]:
					lados.append(Vector2i(dx, dy))
		sim.abrir_solo(c as Vector2i, lados, false)


func _abrir_celdas(celdas: Array) -> void:
	for c in celdas:
		Terreno3D.cauces_abiertos[c] = true
		Terreno3D.agua_sim.solidificar_casilla(c as Vector2i, false)


## Pone a echar agua un manantial o una tinaja. `args` = [caudal, volumen] (lo que falte sale de la pieza o de Surtidor3D).
func _abrir_cauce(pz: Pieza, args: Array) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var caudal: float
	var volumen: float
	var cauce: Array
	var rampa: bool = true
	if pz.tipo == "tinaja":
		caudal = float(args[0]) if args.size() > 0 else Surtidor3D.CAUDAL_TINAJA
		volumen = float(args[1]) if args.size() > 1 else Surtidor3D.VOL_TINAJA
		cauce = pz.p.get("canal", [])
		if cauce.is_empty():
			_avisar_pieza(pz, "abrir_cauce necesita «canal=<lista>»")
			return
	else:
		caudal = float(args[0]) if args.size() > 0 else float(pz.p.get("caudal", 0.5))
		volumen = float(args[1]) if args.size() > 1 else float(pz.p.get("volumen", 0.0))
		rampa = bool(pz.p.get("rampa", true))
		cauce = [pz.celda]
		for c in (pz.p.get("celdas", []) as Array):
			if c != pz.celda:
				cauce.append(c)                         # la primera casilla es la del manantial
	if rampa:
		Mundo3D.abrir_cauce(cauce, caudal, volumen)
	else:
		_abrir_celdas(cauce)
		sim.fuente_en(pz.celda, caudal)
		if volumen > 0.0:
			sim.limitar_fuente(pz.celda, volumen)
	pz.activa = true


func _apagar_fuente(pz: Pieza) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var c: Vector2i = pz.celda
	if pz.tipo == "tinaja":
		var canal: Array = pz.p.get("canal", [])
		if canal.is_empty():
			_avisar_pieza(pz, "apagar_fuente necesita «canal=<lista>»")
			return
		c = canal[0]
	sim.apagar_fuente(c)
	pz.activa = false


func _helar(pz: Pieza, segundos: float) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var celdas: Array = pz.p.get("celdas", [pz.celda])
	for c in celdas:
		sim.helar_casilla(c as Vector2i, true)
		Terreno3D.poner_helada(c as Vector2i, true)
		_hielos[c] = segundos


# ---------------------------------------------------------------------------------------------------------------------
#  Conectar las reglas
# ---------------------------------------------------------------------------------------------------------------------

func _conectar() -> void:
	for r in _reglas:
		var rr: Dictionary = r
		if String(rr["cuando_id"]) == ID_FLAG:
			# Se engancha a la instancia de Flags de ESTE momento (un Flags.nuevo() posterior es otra partida).
			var nombre: String = String(rr["cuando_flag"])
			var regla_f: Dictionary = rr
			Flags.i().flag_cambio.connect(func(nf: String, v: Variant) -> void:
				if nf == nombre and v != null and not (v is bool and v == false):
					_disparar(regla_f))
			# 24/10 (volver de otro nivel): con la flag YA puesta al montar la regla salta una vez (la «recordada»: la puerta que se abrió sigue abierta). Se dispara al final de `iniciar`.
			if Flags.i().tiene(nombre):
				_flags_al_montar.append(regla_f)
			continue
		var fuente: Pieza = _piezas.get(rr["cuando_id"], null)
		if fuente == null or not is_instance_valid(fuente.nodo):
			_avisar("línea %d: puzle «%s»: la pieza «%s» no se pudo montar, la regla no actúa" % [rr["n"], rr["nombre"], rr["cuando_id"]])
			continue
		var info: Array = (SENALES[fuente.tipo] as Dictionary)[rr["senal"]]
		fuente.nodo.connect(String(info[0]), _callable_de(rr, int(info[1]), info[2]))


## El Callable de una regla: una lambda PROPIA por regla. No vale `Callable(self, "_disparar").bind(regla)`: Godot compara las conexiones por el
## Callable BASE y se queda con la primera (medido 16/10: «alcanzado→abrir» y «perdido→cerrar» de un mismo nivel, la segunda no se conectaba y la
## puerta no se cerraba nunca). Una lambda es única, y su aridad es la de la señal (`nargs`); `filtro` (true/false) deja pasar solo ese valor
## del primer argumento (`cambio(abierta)`, `nivel_alcanzado(si)`, `girando(si)`); null = pasa todo.
func _callable_de(regla: Dictionary, nargs: int, filtro: Variant) -> Callable:
	if filtro != null:
		var esperado: bool = bool(filtro)
		return func(valor: bool) -> void:
			if valor == esperado:
				_disparar(regla)
	match nargs:
		0:
			return func() -> void: _disparar(regla)
		1:
			return func(_a: Variant) -> void: _disparar(regla)
		_:
			return func(_a: Variant, _b: Variant) -> void: _disparar(regla)


func _disparar(regla: Dictionary) -> void:
	if not cumple_expr(regla.get("si_expr", []) as Array):
		regla["ignoradas"] = int(regla["ignoradas"]) + 1
		return
	regla["veces"] = int(regla["veces"]) + 1
	for a in (regla["acciones"] as Array):
		_ejecutar(a as Dictionary)


## ¿Se cumple una expresión de `si=`? Vacía = sí. Es O entre grupos e Y dentro de cada grupo.
func cumple_expr(expr: Array) -> bool:
	if expr.is_empty():
		return true
	for g in expr:
		var todos: bool = true
		for t in (g as Array):
			if not _cumple_termino(t as Dictionary):
				todos = false
				break
		if todos:
			return true
	return false


func _cumple_termino(t: Dictionary) -> bool:
	var v: bool = false
	match String(t["tipo"]):
		"pieza":
			v = _cumple(String(t["id"]), String(t["cond"]))
		"flag":
			v = Flags.i().tiene(String(t["nombre"]))
		"casilla":
			# «agua» no es un estado del suelo: la dice el terreno (Terreno3D.es_agua). El resto, EstadosSuelo3D (B1).
			var c: Vector2i = t["celda"]
			if String(t["estado"]) == "agua":
				v = Terreno3D.es_agua(c)
			elif String(t["estado"]) == "roca":
				v = _roca_enfriada_en(c)       # lava enfriada que aún no ha vuelto a ser lava (Lava3D)
			else:
				v = Terreno3D.estados.tiene(c, String(t["estado"]))
	return v != bool(t["neg"])


## ¿Hay roca de lava enfriada en esa casilla? (`casilla(x,y).roca`). Mira las lavas montadas; false si ninguna la tiene.
func _roca_enfriada_en(c: Vector2i) -> bool:
	for pz in _piezas.values():
		if (pz as Pieza).tipo == "lava" and is_instance_valid((pz as Pieza).nodo) and bool(((pz as Pieza).nodo as Lava3D).es_roca(c)):
			return true
	return false


func _cumple(id: String, cond: String) -> bool:
	var pz: Pieza = _piezas.get(id, null)
	if pz == null or not is_instance_valid(pz.nodo):
		return false
	var c: Array = (CONDICIONES[pz.tipo] as Dictionary)[cond]
	return bool(pz.nodo.get(String(c[0]))) == bool(c[1])


func _ejecutar(a: Dictionary) -> void:
	if String(a["id"]) == ID_FLAG:
		if String(a["accion"]) == "poner":
			Flags.i().poner(String(a["nombre"]))
		else:
			Flags.i().quitar(String(a["nombre"]))
		return
	var pz: Pieza = _piezas.get(a["id"], null)
	if pz == null:
		return
	var args: Array = a["args"]
	var nd: Node = pz.nodo if is_instance_valid(pz.nodo) else null
	match String(a["accion"]):
		"pulsar":
			if nd != null:
				nd.call("pulsar")
		"abrir":
			if nd != null:
				var estaba_cerrada: bool = (pz.tipo == "compuerta" or pz.tipo == "puerta") and not bool(nd.get("abierta"))
				nd.call("abrir")
				# Respuesta positiva: una regla que ABRE una compuerta/puerta que estaba cerrada = puzle resuelto (abrir una ya abierta no cuenta).
				if estaba_cerrada and bool(nd.get("abierta")):
					_logro("puzle_resuelto", nd)
		"cerrar":
			if nd != null:
				nd.call("cerrar")
		"aparecer":
			if nd != null:
				nd.call("aparecer")
		"latir":
			if nd != null:
				nd.call("latir")
		"girar":
			if nd != null:
				nd.call("girar")
		"activar":
			if nd != null:
				nd.call("activar")
		"pulso":
			# La fuente eléctrica suelta un pulso de rayo por el agua (y las vetas que la toquen). Alcance = el argumento o el de siempre.
			if nd != null:
				Pulso3D.emitir(_contenedor(), [pz.celda], "rayo", int(args[0]) if args.size() > 0 else Pulso3D.ALCANCE_DEFECTO, nd)
		"alternar":
			if nd != null:
				var estaba_cerrada_a: bool = (pz.tipo == "compuerta" or pz.tipo == "puerta") and not bool(nd.get("abierta"))
				nd.call("alternar")
				if estaba_cerrada_a and bool(nd.get("abierta")):
					_logro("puzle_resuelto", nd)
		"encender":
			if nd != null:
				if pz.tipo == "brasero":
					nd.call("encender_llama")
				elif pz.tipo == "seto":
					nd.call("ignite")
				else:
					nd.call("encender")
		"apagar":
			if nd != null:
				nd.call("apagar_llama" if pz.tipo == "brasero" else "apagar")
		"quemar":
			if nd != null:
				nd.call("quemar")
		"romper":
			if nd != null:
				nd.call("romper")
		"usar":
			if nd != null:
				nd.call("usar")
		"enfriar":
			if nd != null:
				nd.call("enfriar_en", pz.celda)
		"recoger":
			if nd != null:
				nd.call("recoger")
		"mojar":
			if nd == null:
				return
			if pz.tipo == "tinaja":
				nd.call("on_spell_hit", runa(["agua", "humedo"]), Vector3.ZERO)
			else:
				nd.call("mojar")
		"secar":
			if nd != null:
				nd.call("secar")
		"abrir_cauce":
			_abrir_cauce(pz, args)
		"apagar_fuente":
			_apagar_fuente(pz)
		"helar":
			_helar(pz, float(args[0]) if args.size() > 0 else AguaSim3D.DURA_HIELO)


func _process(delta: float) -> void:
	# Hielos puestos por una regla: caducan como los del hechizo (con el reloj de este nodo: va con la simulación y con las pruebas sin ventana).
	for c in _hielos.keys():
		_hielos[c] = float(_hielos[c]) - delta
		if float(_hielos[c]) <= 0.0:
			_hielos.erase(c)
			if Terreno3D.agua_sim != null:
				Terreno3D.agua_sim.helar_casilla(c, false)
			Terreno3D.poner_helada(c, false)
