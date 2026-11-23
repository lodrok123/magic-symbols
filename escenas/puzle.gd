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
##   molino     umbral=<u/s> (0.3)  vertical (si)  hechizo (si)                       Molino3D: gira a ω ∝ corriente en su plano (tope 3 rad/s), con inercia, y se baja al fondo de su casilla (foso, canal, río). `umbral` = corriente que da `girando`. `hechizo=no`: el golpe de agua solo la empuja un instante y NO cuenta para `girando` (solo lo mueve el agua del cauce)
##   barril     tam=normal|pequeno (normal)                                           Barril3D. `tam=pequeno`: barril de 0,55 u que la jugadora coge y lanza (radio 1,6, mecha 2,4 s)
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
##   decorado   modelo=<pieza> (obligatoria)  giro=<grados> (0)  escala=<x> (1)         24/10: una pieza de ADORNO sin mecánica en su casilla (geoda_resonante, estalagmita_resonante…). No bloquea.
##              27/10: también estalagmitas_a|b, cueva_pared_baja, boca_cueva, llave_pequena, bloque_enlace, roca_musgosa, raices_musgo, rocas_salpicadura, helechos_cueva, musgo_colgante
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
##   vigia      de=<lista de casillas> (obligatoria)  flag=<nombre>  puesto=si (no, 27/10: sus arqueros son DE PUESTO, Combate3D.fijo: baten desde donde nacen sin perseguir)
##                              VigiaPuzle (C3): vigila a los Combate3D cuya casilla de PARTIDA (`casa`) está en `de`
##              (un rectángulo `x0,y0..x1,y1` es "la zona"). Cuando han caído todos (muertos o hundidos) emite `todos_derrotados` y, si hay
##              `flag`, la pone. Mientras no haya encontrado ninguno no se da por cumplido (una lista que no casa con nadie avisa)
##              6/11 (bloque A2): `debil=<elemento>` y `resiste=<elemento>` fijan la debilidad / resistencia de esos enemigos (sin ellas, los de fuera del Bosque no tienen ninguna:
##              `Combate3D.DEBILIDAD_GOBLIN_POR_NIVEL`). Ej.: `; pieza g vigia 0 0 de=12,8 debil=rayo resiste=agua`
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
##   bloque     material=piedra|hielo (piedra)                                      BloqueEmpujable3D (27/10, docs/EMPUJAR_BLOQUES.md): bloque que la jugadora EMPUJA andando contra él (0,35 s apretando) o que el VIENTO se lleva. Bloquea
##              su casilla (jugadora, enemigos, flechas), pesa (pisa las placas) y no se guarda: al recargar vuelve a su casilla. `piedra`: una casilla por empujón (0,45 s); sobre el HUECO de una
##              veta (`enlaces=`) lo TIENDE y el pulso cruza. `hielo`: un empujón y resbala hasta que la siguiente casilla no esté libre (pared, otro bloque, una barrera de tierra, un enemigo).
##              Si queda atascado sin remedio (sin ningún movimiento posible y sin servir de nada) se deshace a los 3 s y vuelve a formarse en su casilla del mapa.
##              Señales `movido` (al acabar cada movimiento completo; la casilla) y `reaparece`; condiciones `quieto`|`en_marcha`. Usa una `placa` (pulsador modo=presencia) para saber si está encima
##   roca_empujable  tam=mediana|pequena (mediana)  variante=musgo|neutra|magma (la del bioma)  forma=<n> (1 mediana, 0 pequeña)     BloqueEmpujable3D con material `roca` (5/11/2026, docs/ROCAS_EMPUJABLES_2026-11-05.md): una
##              roca estilizada que se EMPUJA igual que el `bloque` de piedra (mismo clip, mismo tacto, una casilla por empujón, no tiende vetas) pero pesa lo suyo: mediana 2, pequeña 1 (bloque de
##              piedra 3). Modelo `roca_est[_musgo|_magma]_<forma>` (mediana) o `piedra_est[…]_<forma>` (pequeña); `forma` fuera del tamaño pedido = el de por defecto. Mismas señales y condiciones que `bloque`.
##              Las rocas GRANDES (roca_est_0 y 4) siguen siendo muro: no se piden aquí. Una placa `pulsador modo=presencia peso=<n>` solo se pisa con ≥ n de peso encima (la jugadora no cuenta)
##   cofre      aparece_si=<expresión de si=> (siempre)  abierto=<flag>  modelo=legendario|epico   CofrePuzle (C3): un Cofre3D (arte/piezas/cofre.tscn) en x,y. Con `abierto` ya puesta al
##              montar nace ABIERTO; si no, oculto hasta que `aparece_si` se cumpla (se reevalúa cada 0,2 s y al cambiar cualquier flag) y
##              entonces APARECE cerrado (con efecto; si ya se cumplía al montar, sin efecto). El jugador lo abre con E a ≤ 2,7 u; al acabar
##              de abrirse pone la flag `abierto`. Sin `aparece_si` nace cerrado
##   cristal    cada=<s> (3)  alcance=<casillas> (12)                                CristalPulso3D (el pulso resonante, PLAN_PULSO_RESONANTE §4): EMISOR. Late (suelta un Pulso3D desde su
##              casilla) cada `cada` s (0 = solo al golpearlo) y cuando le da un hechizo (el pulso lleva su elemento). Modelo `cristal_resonante`. Bloquea su casilla
##   guardian   en=<lista> (obligatoria)  cada=<s> (0)  elemento=fuego|… (fuego)  cerca=<casillas> (0)  roto=si (no)   GuardianBarrera3D (28/10, Gruta Batida): un tótem que levanta
##              LA BARRERA (la receta elemento + ᛜ de la jugadora) en cada casilla de `en` (sus marcas, a cualquier distancia: tras una reja, al otro lado del agua). `cada` > 0: late solo
##              (con `cerca` > 0, solo con la jugadora a esas casillas o menos); `cada` = 0: dormido, lo despierta un hechizo (y la barrera lleva su elemento). `roto=si`: caído, no hace nada
##              ni bloquea (el sitio de la barrera de la jugadora). Señal `levanta`; acción `levantar`. Bloquea su casilla
##   puente     celdas=<lista> (la propia x,y)                                       PuenteReactivo3D (28/10): losas rúnicas plegadas bajo el agua de `celdas`; con la acción `tender` (o la `cuerda`
##              que lo sostiene, al quemarse) suben una a una y cada casilla se vuelve un puente que se pisa. Señal `tendido`; condición `tendido`|`plegado`
##              23/11: `estilo=losas|raices|zarcillos` (losas). `raices` = PuenteRaices3D (PUENTE DE RAÍCES, fase 1 con modelos provisionales): cada casilla es un tramo de raíces trenzadas que crece sobre el
##              agua DESDE LA PRIMERA de `celdas` (la pegada al tocón; el orden de la lista importa: «a,b..c,d» va siempre de menor a mayor, para el otro sentido usa «+»: `celdas=5,6+5,5+5,4`) hacia fuera, con el mismo escalonado que las losas y un frente verde que revela el tramo a lo largo del puente; al asentarse el tramo
##              la casilla es andable (misma ruta que las losas) y, al acabar el último, brotan hojas. `dir=n|e|s|o` fija el sentido con UNA sola casilla (con varias sale de `celdas`).
##              `tendido_si=<expresión de si=>`: si se cumple AL MONTAR (p. ej. `flag.<la flag del bancal>`, que sobrevive a recargar) el puente nace ya tendido, sin animación y con las casillas andables
##              (no emite `tendido`: nadie lo oye al montar). Vale con los tres estilos. Una expresión mala descarta la pieza (como `aparece_si`)
##              23/11 `estilo=zarcillos` (PUENTE DE ZARCILLOS, el concepto elegido; mismo PuenteRaices3D con `zarcillos=true`, modelos provisionales por código): el primer tramo es el ARRANQUE en abanico (estrecho junto al
##              nudo, del ancho del puente al otro extremo), los siguientes son TEJIDO de enrejado plano, y en la casilla que sigue al último tramo (en su sentido) se monta el ANCLAJE: dos rocas con anillos verdes que se cierran
##              al acabar el último tramo (solo decorado, no bloquea; si esa casilla es pared, agua o está fuera del mapa no se monta y avisa). `completo` sale al cerrarse los anillos. Pensado para `bancal modelo=surco`.
##   limo       elemento=fuego|agua|hielo|rayo|tierra|viento (sin teñir)  grande=si (no)   Limo3D (E1, 28/10): el limo elemental. Persigue a brincos y salta encima (15; 30 de grande),
##              se tiñe del primer elemento que le llega (hechizo o casilla), con su elemento otra vez crece y, grande, su elemento lo cura. Es un Combate3D: el vigía lo cuenta
##              (su casilla de partida es la de la pieza). No bloquea su casilla
##   golem      quieto=si (no)                                                      Golem3D (E3, 28/10): el gólem de piedra. De pie nada le hace daño; persigue lento y golpea con aviso (30 y empuje); tras el
##              golpe queda de rodillas con el núcleo a la vista (×1,5 de daño). El viento sobre una casilla helada lo hace resbalar (tumbado = núcleo a la vista; al agua honda o la
##              lava, muere). `quieto=si`: no persigue ni ataca (un blanco para probar el hielo). Es un Combate3D: el vigía lo cuenta. No bloquea su casilla
##   goblin_escudo  quieto=si (no)                                                  21/11 (arena de combate): un goblin guerrero con ESCUDO (Escudo3D). De frente para todo; el fuego lo prende y,
##              mientras arde, se quema el brazo y no ataca; consumido, pelea sin escudo. Es un Combate3D: el vigía lo cuenta. No bloquea su casilla
##   chaman     quieto=si (no)                                                      Chaman3D (E2, 28/10): el chamán goblin. Escuda primero (traza un rombo en el suelo con el bastón, lo clava y una onda verde da un escudo de
##              naturaleza a los goblins cercanos; el fuego lo quema) y luego se mantiene lejos tirando bolas de veneno. Si le pegan trazando, la runa se rompe. Es un Combate3D: el vigía lo cuenta
##   mamoa      agrietada=si (no)  tapada=si (no)                                   Mamoa3D (E4): el brocal de pozo del que vuelve el mouro. Se TAPA con un bloque empujable encima, la tierra o el hielo de un hechizo vivo, o la
##              acción `tapar` (la destapa `destapar`); tapada se ve la losa. 21/11: también la tapa CUALQUIER cosa sólida en su casilla (roca, caja, jarrón soltado…) y el AGUA: con su
##              casilla mojada o helada el pozo se inunda y queda tapado para siempre. `agrietada=si` nace en su estado final (el mouro ya no vuelve). Sellada con un mouro dentro suelta las reliquias.
##              Señales `tapada`, `destapada`, `agrietada`. No bloquea su casilla (el bloque tiene que poder llegar)
##   mouro      mamoa=<id de la pieza mámoa> (sin ella, un enemigo normal)  quieto=si (no)   MouroEspectro3D (E4): el espectro de elfo. Se desliza hacia ella y la agarra (12 y raíces 1 s, con aviso);
##              al caer con la mámoa abierta se deshace y vuelve de ella a los 4 s con la vida llena, SIN LÍMITE (21/11); con la mámoa tapada muere de verdad. Lleva un aura de veneno. Es un Combate3D: el vigía lo cuenta
##   compana    animas=<n> (3)  camino=<casillas> (el de por defecto: 4 casillas al este, al sur...)   SantaCompana3D (E5): la procesión de n ánimas en fila por el camino (el x,y de la pieza es su salida; el
##              camino se recorre de ida y vuelta). No persiguen: si se les cruza, 10 y ralentiza; si las atacan, el guía (el que lleva la cruz) maldice. Al caer el guía la cruz pasa a la siguiente; si caen
##              todas en 2,5 s se acaba; si no, se reponen SIN LÍMITE (21/11). La cruz lleva una niebla que roba vida (1/s, +1 cada 5 s dentro; atraviesa muros); un muro de hechizo para
##              la fila. Cada ánima es un Combate3D: la casilla de la pieza es la de partida para el vigía
##   (puerta)   modelo=reja                                                       28/10: una REJA de barrotes que deja ver lo de detrás, sin rótulo (para y se abre igual que la losa)
##   veta       celdas=<lista> (la propia x,y)  enlaces=<lista>  aturde=<s> (0)  mineral=si (no)   VetaPulso3D: CONDUCTOR del pulso. Una losa por casilla con las vetas de `arte/suelo_meshy/veta_mineral.png`
##              (máscara × color del pulso por emisión, casilla a casilla) y un hilo guía entre casillas vecinas. No bloquea; la rejilla de vetas la conoce solo el pulso.
##              Fase 3 (24/10): `enlaces` = HUECOS de la veta (C2), casillas que solo conducen con un bloque de tierra encima (hechizo de tierra: el «bloque de enlace»); `aturde=<s>` deja sin
##              sentido, ese tiempo, a quien pisa la veta cuando pasa el frente (C4); `mineral=si` la hace reactivo de tierra: un hechizo de tierra suelta un `mineral_veta` (una vez)
##   columna    golpes=<n> (2)  cae=n|e|s|o (s)                                      MuroAgrietado3D como COLUMNA (fase 3, C2): modelo `columna_agrietada`; la rompen los PULSOS (cada uno la agrieta, al
##              `golpes`-ésimo CAE hacia `cae`, deja su casilla libre y se deshace); la tierra y los hechizos no le hacen nada. Bloquea su casilla mientras está en pie.
##              26/10: también la tumba una EXPLOSIÓN (`geoda`). `puente=<id de una lava>  largo=<casillas>  flag=<nombre>`: columna-PUENTE (C3): al caer se estira `largo` casillas hacia `cae`, NO se deshace y
##              cubre para siempre las casillas de esa lava que quedan bajo ella (se pisan y conducen el pulso); con `flag` se acuerda de que cayó (nace ya tendida). La lava tiene que estar ANTES en el archivo
##   geoda      flag=<nombre>  escala=<x> (1)  cerca=<casillas> (0)                                       GeodaPulso3D (26/10, Cueva): REACTIVO del pulso. El 1.er pulso que la toca (por su casilla o la de la veta de al lado) la CARGA 0,9 s y EXPLOTA una vez: a
##              2,8 u avisa a todo lo `explosionable` (columnas, jarrones, cajas, barriles…) y daña 30 y aturde 2 s a los Combate3D (a la jugadora no). Después desaparece; con `flag` se acuerda.
##              `cerca=<n>`: solo reacciona si la jugadora está a n casillas o menos (la demostración de C1 espera a que la veas). Señal `explota`; condición `explotada`|`intacta`. No bloquea su casilla
##   estalagmita  cae=n|e|s|o (la opuesta de por donde llegó el pulso)  flag=<nombre>    EstalagmitaPulso3D (24/10, C4): REACTIVO del pulso. El 1.er pulso que la toca (por su casilla o la de la veta de al lado) la hace vibrar;
##              el 2.º la tira hacia `cae`: aturde 3 s y daña 25 a los Combate3D de la casilla donde cae (a la jugadora no) y queda `estalagmita_rota`, un escombro bajo que NO bloquea. Con `flag`
##              se acuerda de que cayó (la pone al caer; si ya está puesta nace caída). Señal `cae`; condición `caida`|`en_pie`. No bloquea su casilla (adorno que se rodea)
##   estatuas   celdas=<lista>  secuencia=<e1,e2,…>  flag=<nombre>                  EstatuasPulso3D (fase 3, secreto de C1): una estatua de piedra por casilla de `celdas`; piden pulsos de ESOS elementos, EN ESE
##              ORDEN (las dos listas, igual de largas: `secuencia=fuego,agua,tierra`); un fallo las apaga todas; al acabar ponen `flag`. Cada una lleva a sus pies el color del elemento que pide
##   prisma     dir=n|e|s|o (n)                                                      PrismaPulso3D (fase 2): MODIFICADOR. Reemite el pulso que le llega por la casilla que mira (`dir`), con su
##              elemento, su dueño y el alcance que le quedaba; se gira 90° (horario) con un golpe de hechizo o con E. Bloquea su casilla
##   pared_hueca  flag=<nombre>  mira=n|e|s|o                                       ParedHuecaPulso3D (fase 2): REACTIVO. Suena hueca (eco) con cualquier pulso y SE ABRE solo con uno del
##              JUGADOR (el glifo ᚱ). Bloquea su casilla mientras está cerrada; `flag` se pone al abrirse. `mira`: hacia qué sala mira (grietas y luz) si tiene sala a los dos lados
##   (cofre)    abre_si=<expr> (siempre)  glifo=<id del libro>                        `abre_si`: hasta que se cumpla el cofre está sellado (E avisa y no abre). `glifo=raido`: abrirlo da ese
##              glifo con la SECUENCIA del cofre legendario (SecuenciaCofreLegendario3D) y lo desbloquea en el libro
##              sello=<elemento> (22/11, PLAN_HECHIZOS §1.5): abrirlo da ese SELLO (elemento: fuego, agua, tierra…), con la flag `global.sello.<id>` que ya rearma cada nivel (como el agua de Marimanta)
##              reto=<flag> reto_en=<x,z> (23/11, PLAN_HECHIZOS §4.5 H6, con `glifo=`): el glifo nuevo se equipa en una página y `PistaGlifo` enseña «Pulsa 2 · …» en el HUD. `reto` = la flag que lo resuelve (la pista se va al ponerse; sin ella, al primer lanzamiento con el glifo);
##              `reto_en` = la casilla (UNA) con un aro suave y la runa en el suelo: desde dónde usarlo, sin decir cómo. No se guarda: recargar la quita
##   receptor   elemento=fuego|agua|hielo|rayo|tierra|viento (cualquiera)  flag=<nombre>  rearme=<s> (0)   ReceptorPulso3D: se ACTIVA al llegarle un pulso (de ese elemento, si lo
##              pide) y se queda activo; pone `flag` con la forma de siempre (nivel.sala.hecho). `rearme` > 0: se apaga solo. Modelo `receptor_runico`. Bloquea su casilla
##   jarron, caja  botin=oro|pocion|nada|zona|<objeto> (oro)  cantidad=<n> (la de la zona)  alto=si (jarron_alto)  pequena=si (caja_pequena)  celdas=<lista>  modelo=caja (en un jarron)   Rompible3D (mapas abiertos, 23/10): un jarrón o una caja
##              que tapa su casilla y se ROMPE con cualquier golpe (un hechizo, un empujón de viento, una explosión; `golpear()` para el cuerpo a cuerpo que aún no hay), deja restos
##              y suelta su BOTÍN según la ZONA donde está (tabla `jarron_<zona>` de `botin_tablas.tsv`, F1: bosque, ruinas, cueva…). `botin=oro` da monedas, `pocion` una poción, `<objeto>` cualquier id de
##              `Objetos.DATOS`, `nada` no da nada, `zona` tira la tabla de la zona (casi siempre nada; a veces oro, poción…); `cantidad` fija cuánto. `celdas` pone uno en cada casilla (<id>, <id>_2, <id>_3…).
##              No reaparece: la flag `<nivel>.rompible.<id>` sobrevive a cambiar de nivel y a guardar
##   salida     a=<Nivel>:<entrada> (o escena=<Nivel o escena> entrada=<nombre>)  celdas=<lista> (la propia x,y)  modo=pisar|usar (pisar)  marca=si|no (si)  modelo=<id> (aún no se dibuja)     SalidaNivel3D (transición entre niveles): al pisar sus casillas (o con E,
##              `modo=usar`) carga <Nivel> (tabla `Niveles.ESCENAS`) y deja a la jugadora en su entrada con ese nombre, con fundido a negro. Nace desarmada y se arma al salir de sus casillas.
##              Si el nivel no existe todavía, avisa en consola y en pantalla y no hace nada
##   entrada    mira=n|e|s|o (hacia dentro)                                          EntradaNivel3D: el punto de llegada de otro nivel; el ID de la pieza es su nombre (`a=Cueva:desde_bosque`).
##              La jugadora aparece en su casilla mirando a `mira` o, sin ella, hacia donde hay más suelo libre seguido. Es también su punto de reaparición. No dibuja ni bloquea
##   colmena    (sin claves)                                                        Colmena3D (F1, 29/10): colgada de un árbol. VIENTO: cae el panal (`panal` 1–2, una vez: flag `<nivel>.colmena.<id>`). FUEGO: arde, nube de
##              veneno 3 s y nada de panal. Primitivas hasta que haya pieza. Señales `cae_panal`, `arde`; condición `colgada`|`vacia`
##   nube_veneno  vida=<s> (6; 0 = permanente)  radio=<casillas> (1)                 NubeVeneno3D (F4, 29/10): una nube de veneno con vida propia. Envenena a quien esté dentro (2 de vida/s y 3 s después; el antídoto, la capucha de musgo y el
##              limo, el chamán y el gólem no se envenenan), el VIENTO la empuja y la dispersa (8 s) y el FUEGO la consume (4 s). Se guarda en la partida. Señal `disipada`
##   respiradero  cada=<s> (8)  vida=<s> (5)  radio=<casillas> (1)  crece=<s> (1.5)  dir=n|e|s|o  desfase=<s> (0)  agua=si|no (si)  quema=<s> (0.5)  arde=<s> (6)   Respiradero3D (18/11; alias `seta_veneno`): una SETA venenosa grande
##              en el suelo (x,y es una casilla de SUELO; no bloquea; antes era una reja) que EXHALA una nube de veneno (`NubeVeneno3D`, con esa `vida` y ese `radio`) cada `cada` s; un segundo antes la seta se hincha y brilla de verde
##              y al exhalar se encoge de golpe (puf). La nube NO nace completa: crece desde el centro de la seta hasta su `radio` en `crece=<s>` (de verdad: lo que envenena es el radio de cada momento; 0 = nace completa) y lleva ondas
##              (anillos que salen de la seta hasta el borde) para que se vea de dónde viene. `dir`: la nube brota media casilla hacia ese lado (sin ella, centrada en la seta).
##              `desfase` = punto del ciclo en el que empieza (0 = acaba de exhalar). El FUEGO (a la seta o a una nube suya) PRENDE EL GAS: la seta arde `arde=<s>` (6) sin exhalar ni avisar, con una llama pequeña rojo-naranja sobre el sombrero y luz cálida; su
##              nube viva se consume en `quema=<s>` (0,5; es su `consume_propio_s`: las demás nubes, 4 s de la tabla `veneno`); al acabar vuelve a su ciclo desde 0. El AGUA y el HIELO la atascan 8 s (`agua=no`: nada la atasca) y,
##              sobre una seta ardiendo, apagan la llama y la dejan atascada. Señales `exhala`, `apagado`, `prende`, `se_apaga_llama`; condición `activo`|`apagado`|`ardiendo`; acciones `apagar(s)` | `encender`
##   balsa      ruta=<lista de casillas>  cofre=<id de un cofre>  calado=<u> (0.2)  vel=<u/s> (1.5)   Balsa3D (18/11): una plataforma de tablones en x,y (una casilla `c` del foso; el REPOSO). Descansa en el fondo y FLOTA cuando el agua
##              de su casilla llega a `calado` (sube con la superficie, de ahí su altura); entonces DERIVA casilla a casilla por la `ruta` (en orden: x,y,… con «+»; la última es el MUELLE) a `vel` u/s, y solo avanza si en la
##              casilla siguiente hay agua de `calado` (si el foso se seca, queda varada y se hunde donde esté). Al llegar queda ATRACADA, aunque luego se hunda. `cofre=<id>`: lleva ese cofre encima (el cofre se mueve con
##              ella y la casilla que bloquea también); para que no se abra desde el fondo del foso vacío, el cofre lleva `abre_si=<id de la balsa>.atracada`. Ej. (Q12 de PuzlesAgua):
##              `; pieza b balsa 26 30 ruta=27,30+28,30 cofre=cf` · `; pieza cf cofre 26 30 abre_si=b.atracada`. Señales `atraca`, `flota`, `se_hunde`; condiciones `atracada`|`en_ruta`, `a_flote`|`hundida`. Sin acciones.
##   nido       (sin claves)                                                        Nido3D (F1): el viento suelta una `pluma`, como mucho cada 45 s. Señal `suelta`
##   bancal     flag=<nivel.sala.hecho> (obligatoria)                                Tierra o arena. Agua (o agua → naturaleza) germina la casilla y guarda la flag. 23/11: basta el agua, decisión de la demo.
##              Señal `germino`; condiciones `germinado` y `pendiente`. La flag restaura la hierba al volver al mapa.
##              23/11: `modelo=tocon` (opcional): pone un TOCÓN en la casilla (provisional `tronco_seco` mientras está pendiente; al germinar cambia a `tronco_musgoso` con un pop de escala y esporas; ya germinado
##              al cargar, sale directamente el musgoso). El tocón NO bloquea la casilla (se le quita el cuerpo de colisión): una casilla bloqueada no recibe el agua (ReaccionesSuelo3D) y el bancal no germinaría.
##              Pensado para enlazar con un `puente estilo=raices`: `; puzle crece cuando=<bancal>.germino hace=<puente>.tender` + `tendido_si=flag.<flag del bancal>` en el puente
##              23/11: `modelo=surco` + `dir=n|e|s|o` (s): el bancal del PUENTE DE ZARCILLOS: una piedra con hueco (~¾ de la casilla, lado −dir; sin colisión) y un nudo de zarcillos dormido (verde oliva) en el borde +dir.
##              Al germinar: el agua sube en el hueco, un hilo baja por el surco, el nudo se abre (verde lima, pop, se desenrolla, esporas). La flag/`germinado` se ponen al instante, pero la SEÑAL `germino` sale cuando
##              el nudo empieza a abrirse (~0,9 s después): así `cuando=<bancal>.germino hace=<puente>.tender` arranca el puente con el nudo ya despierto. `dir` ha de coincidir con el sentido del puente.
##   arbol      modelo=arbol_redondo|arbol_redondo_2|pino|pino_2 (arbol_redondo)    Reactivo3D `arbol` (F1): bloquea su casilla; un golpe cuerpo a cuerpo (F) lo sacude y suelta la tabla `tronco_golpe`, cada 30 s
##   musgo, helecho_cueva, seta_palida   coge_si=<expresión>  rebrota=<s> (0)        Recolectable3D (F1): como `alga`, con la pieza de la columna `modelo` de su objeto (o una esfera si no la hay)
##   cofre (da=)  da=<objeto>:<n>[+<objeto>:<n>…] (`oro` es oro)  o  da=tabla:<id> (una tirada de `botin_tablas.tsv`; se mezcla con «+»). `abre_si=tener.<objeto>`: la condición `tener.<objeto>` vale mientras
##              haya ese objeto en la bolsa (también en `si=`); con `gasta=si` el cofre quita 1 de cada objeto `tener.` de su `abre_si` al abrirse (la llave de la bolsa)
##   cofre (da=)  da=<objeto>:<n>[+<objeto>:<n>…] (`oro` es oro)        Al acabar de abrirse da ESE botín una vez (oro y lo que quepa en la mochila; avisa). Un cofre que nace abierto no da
##   vigía con la sala ya limpia: si su `flag` está puesta al montar, sus enemigos (los de `de=`) NO aparecen: no se repueblan al volver de otro nivel ni al cargar partida
##   puerta (con llave)  llave=<flag>  gasta=si|no (no)  abierto=<flag> (o flag=<flag>)          La puerta pide la llave DE VERDAD: con `llave` solo se abre si esa flag está puesta Y la jugadora está delante (la toca o
##              pulsa E a ≤ PuertaPuzle.ALCANCE_USAR); sin la flag, tocarla o pulsar E avisa «Hace falta una llave». `gasta=si` quita la flag al abrir (la llave se gasta); `abierto=<flag>`
##              recuerda que se abrió (con ella puesta nace abierta). Sin `llave`, la puerta es la de siempre (la abre una regla)
##   trampa_dragon   mira=n|e|s|o (s)  ciclo=<encendida>,<apagada> (2.0,1.5)  desfase=<s> (0)  alcance=3..6 (5)  elemento=fuego|agua|hielo|rayo|tierra|viento (fuego)  agua=si|no (si)  cerca=<casillas> (0)   TrampaDragon3D (5/11, docs/TRAMPAS_PARED_2026-11-05.md):
##              cabeza de dragón de cuello largo metida en el MURO de x,y (una `#`) que da a la casilla de `mira`; ESCUPE un chorro continuo (el haz real de la jugadora, relanzado cada 0,8 s) durante `encendida` s y
##              descansa `apagada` s, avisando con brasas y humo 0,5 s antes. `desfase` = punto del ciclo en el que empieza (0 = en reposo). `agua=no`: el agua y el hielo no la apagan (8 s). `cerca=<n>`: dormida (ciclo parado) mientras la jugadora esté a más de n casillas de la casilla de delante. Hiere a la jugadora 10 por tick
##   trampa_flechas  mira=n|e|s|o (s)  cada=<s> (1.2)  desfase=<s> (0)  alcance=<casillas> (8)  vel=<casillas/s> (3.5)  elemento=fuego|ninguno|agua|… (fuego)  agua=si|no (si)  cerca=<casillas> (0)   TrampaFlechas3D (5/11): mascarón de piedra en el muro
##              que dispara cada `cada` s una FLECHA (fuego + ᛇ: hechizo real que vuela recto, prende lo inflamable y se para en muros y bloques; `elemento=ninguno`: flecha normal, 12 a la jugadora), con la ranura iluminada 0,35 s antes
##              18/11: `exenta=si` = TÓTEM DE RUINAS: x,y es una casilla de SUELO (no una `#`); el mascarón queda de pie en ella con un bloque de piedra detrás, la bloquea y dispara hacia `mira` desde su borde de delante.
##              Todo lo demás (cada, desfase, alcance, cerca, agua, apagar/encender) es igual. Ej.: `; pieza t1 trampa_flechas 17 18 mira=e exenta=si cada=3.0 desfase=0`
##

## SEÑALES (`cuando=<id>.<señal>`; sin señal vale la primera de cada fila):
##   pulsador   pulsado | soltado           compuerta  abierta | cerrada          nivel   alcanzado | perdido
##   molino     girando | parado            nexo       conduce | corta            barril  explota
##   puerta     abierta | cerrada           totem      activado                   tinaja  agua_llega
##   emisor     descarga
##   trampa_dragon  escupe | calla | apagada          trampa_flechas  dispara | apagada          respiradero  exhala | apagado | prende | se_apaga_llama
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
##   trampa_dragon, trampa_flechas   apagar(s) (s segundos; sin argumento, hasta `encender`) | encender         (condiciones: activa | apagada)
##   respiradero         apagar(s) (quita también la llama) | encender         (condiciones: activo | apagado | ardiendo)
##   jarron, caja        romper (como un golpe)                salida   usar (la dispara, como si la jugadora la pisara)      columna  romper (la tumba)
##   zona       poner(<estado>[,<segundos>]) | quitar(<estado>)     (F4, 29/10: los estados DINÁMICOS del mundo de `estados_mundo.tsv`, p. ej. `hace=zona.poner(tormenta,60)` o `zona.poner(vendaval)`; sin segundos, los de la tabla
##              o hasta `zona.quitar`. «zona» es palabra reservada como «flag»; el veneno no se pone así: es de las nubes (`nube_veneno`))
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
	"columna": "cae", "estatuas": "completa", "estalagmita": "cae", "geoda": "explota", "bloque": "movido", "roca_empujable": "movido",
	"guardian": "levanta", "puente": "tendido", "trampa_dragon": "escupe", "trampa_flechas": "dispara",
	"colmena": "cae_panal", "nube_veneno": "disipada", "respiradero": "exhala", "balsa": "atraca", "nido": "suelta", "musgo": "recogida", "helecho_cueva": "recogida", "seta_palida": "recogida",
	"flor": "recogida", "raiz": "recogida", "lavanda": "recogida", "bayas": "recogida", "helecho": "recogida", "flor_silvestre": "recogida",
	"bancal": "germino", "mamoa": "tapada", "dragon_jefe": "derrotado", "verraco": "derrotado",
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
	"totem": {"activado": ["activado", 2, null],
		# R2 (6/11): la naturaleza enreda el tótem y el hielo lo congela (señales de Reactivo3D); un puzle puede esperar a que lo liberen o descongelen.
		"enredado": ["enredado_cambio", 1, true], "liberado": ["enredado_cambio", 1, false], "congelado": ["congelado_cambio", 1, true], "descongelado": ["congelado_cambio", 1, false]},
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
	"geoda": {"explota": ["explota", 2, null]},
	"bloque": {"movido": ["movido", 1, null], "reaparece": ["reaparecio", 0, null]},
	"roca_empujable": {"movido": ["movido", 1, null], "reaparece": ["reaparecio", 0, null]},
	"estatuas": {"completa": ["completa", 0, null], "falla": ["falla", 0, null], "acierta": ["acierta", 2, null]},
	"guardian": {"levanta": ["levanta", 1, null]},
	"puente": {"tendido": ["completo", 0, null]},
	"mamoa": {"tapada": ["tapada", 0, null], "destapada": ["destapada", 0, null], "agrietada": ["agrietada", 0, null]},
	"trampa_dragon": {"escupe": ["escupe", 0, null], "calla": ["calla", 0, null], "apagada": ["apagada", 0, null]},
	"trampa_flechas": {"dispara": ["dispara", 0, null], "apagada": ["apagada", 0, null]},
	"dragon_jefe": {"derrotado": ["derrotado", 0, null], "presentado": ["presentado", 0, null], "aliento": ["aliento_empieza", 0, null], "aturdido": ["aturdido", 0, null], "expuesto": ["expuesto", 0, null]},
	# X2 de PLAN_COMBATE (22/11): el Verraco (enemigos/verraco_3d.gd).
	"verraco": {"derrotado": ["derrotado", 0, null], "embiste": ["embiste", 0, null], "choca": ["choca", 1, null], "frena": ["frena", 0, null], "expuesto": ["expuesto", 0, null]},
	"colmena": {"cae_panal": ["panal_cae", 0, null], "arde": ["arde", 0, null]},
	"nube_veneno": {"disipada": ["disipada", 0, null]},
	"respiradero": {"exhala": ["exhala", 0, null], "apagado": ["apagado", 0, null], "prende": ["prende", 0, null], "se_apaga_llama": ["se_apaga_llama", 0, null]},
	"balsa": {"atraca": ["atraca", 0, null], "flota": ["a_flote", 1, true], "se_hunde": ["a_flote", 1, false]},
	"nido": {"suelta": ["suelta", 0, null]},
	"bancal": {"germino": ["germino", 0, null]},
	"musgo": {"recogida": ["recogido", 1, null]},
	"helecho_cueva": {"recogida": ["recogido", 1, null]},
	"seta_palida": {"recogida": ["recogido", 1, null]},
	"flor": {"recogida": ["recogido", 1, null]}, "raiz": {"recogida": ["recogido", 1, null]}, "lavanda": {"recogida": ["recogido", 1, null]},
	"bayas": {"recogida": ["recogido", 1, null]}, "helecho": {"recogida": ["recogido", 1, null]}, "flor_silvestre": {"recogida": ["recogido", 1, null]},
}
const CONDICIONES: Dictionary = {
	"bancal": {"germinado": ["germinado", true], "pendiente": ["germinado", false]},
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
	"geoda": {"explotada": ["explotada", true], "intacta": ["explotada", false]},
	"bloque": {"quieto": ["moviendo", false], "en_marcha": ["moviendo", true]},
	"roca_empujable": {"quieto": ["moviendo", false], "en_marcha": ["moviendo", true]},
	"estatuas": {"completa": ["hecha", true], "pendiente": ["hecha", false]},
	"puente": {"tendido": ["tendido", true], "plegado": ["tendido", false]},
	"mamoa": {"abierta": ["abierta", true], "tapada": ["abierta", false], "agrietada": ["esta_agrietada", true]},
	"trampa_dragon": {"activa": ["activa", true], "apagada": ["activa", false]},
	"trampa_flechas": {"activa": ["activa", true], "apagada": ["activa", false]},
	"colmena": {"colgada": ["colgada", true], "vacia": ["colgada", false]},
	"respiradero": {"activo": ["activo", true], "apagado": ["activo", false], "ardiendo": ["ardiendo", true]},
	"balsa": {"atracada": ["atracada", true], "en_ruta": ["atracada", false], "a_flote": ["flota", true], "hundida": ["flota", false]},
	"musgo": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"helecho_cueva": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"seta_palida": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"flor": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]}, "raiz": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"lavanda": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]}, "bayas": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
	"helecho": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]}, "flor_silvestre": {"recogida": ["recogido_ya", true], "en_suelo": ["recogido_ya", false]},
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
	"musgo": {"recoger": 0},
	"helecho_cueva": {"recoger": 0},
	"seta_palida": {"recoger": 0},
	"flor": {"recoger": 0}, "raiz": {"recoger": 0}, "lavanda": {"recoger": 0}, "bayas": {"recoger": 0}, "helecho": {"recoger": 0}, "flor_silvestre": {"recoger": 0},
	"cristal": {"latir": 0},
	"receptor": {"activar": 0, "apagar": 0},
	"prisma": {"girar": 0},
	"pared_hueca": {"abrir": 0},
	"emisor": {"pulso": 1},
	"jarron": {"romper": 0},
	"caja": {"romper": 0},
	"salida": {"usar": 0},
	"columna": {"romper": 0},
	"guardian": {"levantar": 0},
	"puente": {"tender": 0},
	"mamoa": {"tapar": 0, "destapar": 0},
	"trampa_dragon": {"apagar": 1, "encender": 0},
	"trampa_flechas": {"apagar": 1, "encender": 0},
	"respiradero": {"apagar": 1, "encender": 0},
}
## Otros nombres de un tipo de pieza (se normalizan al leer la línea: la pieza queda con el tipo de la derecha, así que condiciones, acciones y señales son las suyas). 18/11: `seta_veneno` = `respiradero`.
const ALIAS_TIPO: Dictionary = {"seta_veneno": "respiradero"}
## Claves de cada tipo de pieza y qué valor admiten: «f» número, «b» sí/no, «celdas» lista de casillas, «fijo» número o sí, «s:a|b» una de esas palabras.
const CLAVES: Dictionary = {
	"pulsador": {"modo": "s:magia|agua|presencia", "rearme": "f", "modelo": "s:cueva", "peso": "f"},
	"compuerta": {"abierta": "b", "abre_con": "s:fuego|agua|hielo|rayo|explosion", "cierra_con": "s:fuego|agua|hielo|rayo", "estrecha": "b", "vertical": "b"},
	"nivel": {"objetivo": "f", "banda": "f", "invertido": "b"},
	"molino": {"umbral": "f", "vertical": "b", "hechizo": "b"},
	"barril": {"tam": "s:normal|pequeno"},
	"nexo": {},
	"puerta": {"modelo": "s:llave|reja", "giro": "f", "llave": "flag", "gasta": "b", "abierto": "flag", "flag": "flag"},
	"emisor": {},
	"cuenca": {"celdas": "celdas", "nivel": "f", "fijo": "fijo"},
	"manantial": {"caudal": "f", "volumen": "f", "rampa": "b", "inicia": "b", "celdas": "celdas", "sin_piedra": "b", "bloque": "celdas", "terraza": "f", "pilares": "b", "espuma": "f"},
	"tinaja": {"canal": "celdas"},
	"totem": {},
	"brasero": {"rele": "id", "espera": "f", "dura": "f", "luz": "f", "modelo": "s:cueva", "por_hierba": "b"},
	# 27/10: todo el kit de la Cueva se puede poner de adorno desde el mapa (estalagmitas, pared baja, boca, llave, bloque de enlace, rocas y raíces con musgo)
	"decorado": {"modelo": "decorado:geoda_resonante|estalagmita_resonante|estalagmita_rota|rocas_salpicadura|helechos_cueva|musgo_colgante|estalagmitas_a|estalagmitas_b|cueva_pared_baja|boca_cueva|llave_pequena|bloque_enlace|roca_musgosa|raices_musgo", "giro": "f", "escala": "f"},
	"seto": {"mojable": "b"},
	"contador": {"de": "celdas", "minimo": "f"},
	"cuerda": {"sostiene": "id"},
	"vigia": {"de": "celdas", "flag": "flag", "puesto": "b", "debil": "s:fuego|agua|tierra|viento|rayo|hielo", "resiste": "s:fuego|agua|tierra|viento|rayo|hielo"},
	"cerrojo": {"celdas": "celdas", "sala": "celdas", "hasta": "flag"},
	"cofre": {"aparece_si": "expr", "abierto": "flag", "modelo": "s:legendario|epico", "abre_si": "expr", "glifo": "glifo", "sello": "sello", "da": "da", "gasta": "b", "reto": "flag", "reto_en": "celdas"},
	"muro": {"golpes": "f"},
	"lava": {"celdas": "celdas", "vuelve": "f"},
	"seta": {"variante": "s:roja|azul|marron", "rebrota": "f", "madura": "b"},
	"alga": {"coge_si": "expr", "rebrota": "f"},
	"basalto": {"coge_si": "expr", "rebrota": "f"},
	"musgo": {"coge_si": "expr", "rebrota": "f"},
	"helecho_cueva": {"coge_si": "expr", "rebrota": "f"},
	"seta_palida": {"coge_si": "expr", "rebrota": "f"},
	"flor": {"coge_si": "expr", "rebrota": "f"}, "raiz": {"coge_si": "expr", "rebrota": "f"}, "lavanda": {"coge_si": "expr", "rebrota": "f"},
	"bayas": {"coge_si": "expr", "rebrota": "f"}, "helecho": {"coge_si": "expr", "rebrota": "f"}, "flor_silvestre": {"coge_si": "expr", "rebrota": "f"},
	"colmena": {},
	"bancal": {"flag": "flag", "modelo": "s:tocon|surco", "dir": "s:n|e|s|o"},
	"nube_veneno": {"vida": "f", "radio": "f"},
	"respiradero": {"cada": "f", "vida": "f", "radio": "f", "crece": "f", "dir": "s:n|e|s|o", "desfase": "f", "agua": "b", "quema": "f", "arde": "f"},
	"balsa": {"ruta": "celdas", "cofre": "id", "calado": "f", "vel": "f"},
	"nido": {},
	"arbol": {"modelo": "s:arbol_redondo|arbol_redondo_2|pino|pino_2"},
	"cristal": {"cada": "f", "alcance": "f"},
	"veta": {"celdas": "celdas", "enlaces": "celdas", "aturde": "f", "mineral": "b"},
	"columna": {"golpes": "f", "cae": "s:n|e|s|o", "puente": "id", "largo": "f", "flag": "flag"},
	"estalagmita": {"cae": "s:n|e|s|o", "flag": "flag"},
	"geoda": {"flag": "flag", "escala": "f", "cerca": "f"},
	"bloque": {"material": "s:piedra|hielo"},
	"roca_empujable": {"tam": "s:mediana|pequena", "variante": "s:musgo|neutra|magma", "forma": "f"},
	"estatuas": {"celdas": "celdas", "secuencia": "secuencia", "flag": "flag"},
	"receptor": {"elemento": "s:fuego|agua|hielo|rayo|tierra|viento", "flag": "flag", "rearme": "f"},
	"prisma": {"dir": "s:n|e|s|o"},
	"pared_hueca": {"flag": "flag", "mira": "s:n|e|s|o"},
	"jarron": {"botin": "botin", "cantidad": "f", "alto": "b", "celdas": "celdas", "modelo": "s:caja|jarron|anfora_asas_a|anfora_asas_b"},
	"caja": {"botin": "botin", "cantidad": "f", "pequena": "b", "celdas": "celdas"},
	"salida": {"a": "destino", "escena": "nombre", "entrada": "nombre", "modelo": "nombre", "celdas": "celdas", "modo": "s:pisar|usar", "marca": "b"},
	"entrada": {"mira": "s:n|e|s|o"},
	"guardian": {"en": "celdas", "cada": "f", "elemento": "s:fuego|agua|hielo|tierra|rayo|viento", "cerca": "f", "roto": "b"},
	"puente": {"celdas": "celdas", "estilo": "s:losas|raices|zarcillos", "tendido_si": "expr", "dir": "s:n|e|s|o"},
	"limo": {"elemento": "s:fuego|agua|hielo|rayo|tierra|viento", "grande": "b", "coraza": "s:barro|brasa"},
	"golem": {"quieto": "b"},
	"goblin_escudo": {"quieto": "b"},
	# B1 de PLAN_COMBATE (22/11): guerrero con coraza de elemento (`CorazaElemento3D`); de serie, de barro (la rompe la tierra).
	"goblin_coraza": {"quieto": "b", "coraza": "s:barro|brasa"},
	"chaman": {"quieto": "b"},
	"mamoa": {"agrietada": "b", "tapada": "b"},
	"mouro": {"mamoa": "id", "quieto": "b"},
	"compana": {"animas": "f", "camino": "celdas"},
	"trampa_dragon": {"mira": "s:n|e|s|o", "ciclo": "par", "desfase": "f", "alcance": "f", "elemento": "s:fuego|agua|hielo|rayo|tierra|viento", "agua": "b", "cerca": "f"},
	"trampa_flechas": {"mira": "s:n|e|s|o", "cada": "f", "desfase": "f", "alcance": "f", "vel": "f", "elemento": "s:fuego|ninguno|agua|hielo|rayo|tierra|viento", "agua": "b", "cerca": "f", "exenta": "b"},
	# 21/11 (Pablo): dragón jefe placeholder (objetos/dragon_jefe_3d.gd): presentación con rótulo y aliento que barre, se bloquea con barrera.
	"dragon_jefe": {"mira": "s:n|e|s|o", "alcance": "f", "cerca": "f", "vida": "f", "nombre": "nombre", "epiteto": "nombre"},
	# X2 de PLAN_COMBATE (22/11): el Verraco, élite de granito que embiste (enemigos/verraco_3d.gd).
	"verraco": {"mira": "s:n|e|s|o", "vida": "f"},
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
const ID_ZONA: String = "zona"                   ## F4: `hace=zona.poner(tormenta,60)`: los estados dinámicos del mundo (EstadoZona3D)
const ACCIONES_ZONA: Array = ["poner", "quitar"]
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
## F1: condición `tener.<objeto>` = hay al menos uno en la bolsa (`Estado.cuenta`). Palabra reservada, como `flag`.
const TERMINO_TENER: String = "tener"
const ESTADOS_CASILLA: Array = ["mojada", "helada", "quemada", "electrificada", "segada", "agua", "roca", "escombro", "vapor"]
## Piezas que ya pone la maqueta por letra: la casilla de la pieza tiene que llevar esa letra.
const LETRA_MAQUETA: Dictionary = {"tinaja": "u", "totem": "i", "emisor": "e", "brasero": "T", "seto": "z"}
## Trampas de pared (5/11): van en una casilla de MURO y miran a una casilla de suelo.
const TRAMPAS_PARED: Array = ["trampa_dragon", "trampa_flechas"]
## Piezas que necesitan la simulación de agua (`agua_fisica = true` en la escena).
const NECESITAN_AGUA: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino", "balsa"]
const NECESITAN_CAUCE: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino", "balsa"]


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


## Registra la germinación del suelo de una casilla y la recuerda entre visitas.
## 23/11: con `modelo=tocon` (`con_tocon`) lleva un tocón encima: `tronco_seco` mientras está pendiente y `tronco_musgoso` al germinar (cambio de malla con un pop de escala y esporas).
## El tocón NO bloquea la casilla (ver `_montar_tocon`): el agua tiene que poder llegar a ella.
## 23/11 (PUENTE DE ZARCILLOS): con `modelo=surco` (`con_surco`) la casilla lleva una PIEDRA CON HUECO (ocupa ~¾ de la casilla, del lado −`dir`) y, en el borde de +`dir`, un NUDO de zarcillos dormido.
## `dir` = hacia dónde sale el puente (n|e|s|o, por defecto s): el mismo que el del puente. Piedra y nudo son provisionales (ver las constantes `MODELO_*`). Ninguna lleva colisión (el agua tiene que mojar la casilla).
## SECUENCIA al germinar (el agua la pone el motor, no el modelo): el agua SUBE en el hueco (T_AGUA) → un HILO de agua baja por el surco hasta el nudo (T_HILO) → el NUDO SE ABRE: pasa del verde oliva apagado al
## verde lima con un pop de escala, se desenrolla girando (cada espira con su giro y su escala) y suelta esporas. La flag y `germinado` se ponen AL INSTANTE (sobreviven a recargar); la SEÑAL `germino`, en cambio,
## se emite cuando el nudo EMPIEZA a abrirse (T_AGUA + T_HILO ≈ 0,9 s después): así la regla `cuando=<bancal>.germino hace=<puente>.tender` arranca el puente justo cuando el nudo está despierto, sin
## que el puente tenga que esperar nada. (Con `modelo=tocon` o sin modelo, `germino` sigue saliendo al instante.) Ya germinado al cargar: agua en el hueco, hilo y nudo abierto, sin animación.
class BancalPuzle extends Node3D:
	signal germino

	const ESCENA_TOCON_SECO: String = "res://arte/piezas/tronco_seco.tscn"
	const ESCENA_TOCON_VIVO: String = "res://arte/piezas/tronco_musgoso.tscn"
	const POP_INICIO: float = 0.78             ## escala con la que aparece el musgoso (de ahí sube a 1 con rebote)
	const POP_DURA: float = 0.4
	## --- modelo=surco: MODELOS. Cambiar solo la ruta (si el .glb existe se usa solo; si no, el provisional). Origen en el centro de la base, Y arriba, el surco/nudo mirando a +X (se gira hacia `dir`). ---
	## TODO modelo Meshy: arte/meshy/piezas/piedra_surco.glb
	const MODELO_PIEDRA_SURCO: String = "res://arte/meshy/piezas/piedra_surco.glb"
	## TODO modelo Meshy: arte/meshy/piezas/nudo_zarcillos_dormido.glb
	const MODELO_NUDO_DORMIDO: String = "res://arte/meshy/piezas/nudo_zarcillos_dormido.glb"
	## TODO modelo Meshy: arte/meshy/piezas/nudo_zarcillos_vivo.glb   (misma geometría que el dormido: el cambio es de malla/textura)
	const MODELO_NUDO_VIVO: String = "res://arte/meshy/piezas/nudo_zarcillos_vivo.glb"
	const PIEDRA_PROVISIONAL: String = "pila_piedra"       ## id de `PiezaPuzle3D.malla_modelo` (la pila del cuenco); sin ella, un cilindro
	const PIEDRA_ESCALA: float = 1.5           ## la pila mide 1,1 → 1,65 u: ~¾ de la casilla (2,3)
	const PIEDRA_DESPLAZA: float = -0.42       ## u del centro de la casilla hacia `dir` (negativo = hacia atrás)
	const NUDO_DESPLAZA: float = 0.85          ## u del centro hacia `dir` a la que está el nudo (junto al borde de la casilla que da al agua); lateralmente va a PuenteRaices3D.NUDO_LATERAL del eje, del lado de la cámara
	## Hueco de la piedra PROVISIONAL (medidas de `pila_piedra` × PIEDRA_ESCALA, las del cuenco de Reactivo3D). Con el modelo de Meshy hay que ajustar estas tres al hueco real.
	const HUECO_Y: float = 0.27 * PIEDRA_ESCALA           ## nivel del agua: ~0,15 u por debajo del labio (0,37 × escala), a la vista un trozo de pared seca
	const HUECO_FONDO_Y: float = 0.17 * PIEDRA_ESCALA
	## TODO piedra Meshy: centro del hueco respecto al origen de la piedra (x, z en unidades de mundo, ejes del mundo: la pila provisional no se gira con `dir`). MEDIDO A OJO en captura: la malla de la pila es irregular
	## y su caja no da el centro del hueco (los salientes laterales la sesgan); con el .glb de Meshy medirlo de su hueco y ajustar aquí junto a HUECO_Y, HUECO_FONDO_Y y HUECO_RADIO.
	const HUECO_CENTRO: Vector2 = Vector2(0.07, -0.07)
	const HUECO_RADIO: float = 0.36 * PIEDRA_ESCALA       ## semieje del contorno del agua (u): la boca del hueco a su nivel
	## TODO piedra Meshy (hueco en forma de ocho redondeado): el contorno es UNA elipse con lóbulos (HUECO_FORMA = proporción de sus semiejes x/z respecto a HUECO_RADIO; HUECO_LOBULOS = amplitud de los
	## lóbulos de 5 y de 9 picos; 0 = círculo liso). Con el ocho de Meshy: o se aproxima con una elipse (HUECO_FORMA ≈ (1.5, 0.8), lóbulos a 0), o hay que tocar `CODIGO_AGUA_HUECO` y `CODIGO_FONDO_HUECO`
	## (`borde`) para dar dos centros/radios. Fondo del hueco: color de la piedra mojada clara y escala respecto a la boca (el hueco se estrecha hacia abajo).
	const HUECO_FORMA: Vector2 = Vector2(1.0, 1.15)
	const HUECO_LOBULOS: Vector2 = Vector2(0.035, 0.02)
	const HUECO_FONDO_ESCALA: float = 0.78
	const HUECO_FONDO_DESPLAZA: Vector2 = Vector2(0.0, -0.1)      ## el fondo, más profundo, se vería corrido hacia la cámara y asomaría fuera del contorno del agua: se compensa hacia atrás (cámara al norte desde el sur)
	## Agua del hueco: LIMPIA, casi transparente, estilizada (como el filtro del río, `agua_render_3d.gd`): orilla casi invisible que pasa con un degradado largo a un tinte turquesa claro y poco denso hacia el centro,
	## sin bandas; deja ver el FONDO (`CODIGO_FONDO_HUECO`, un disco de piedra mojada con guijarros pintados y cáusticas tenues). Las ondas solo se notan en el brillo; al llenarse, un anillo suave que se expande (`pulso`
	## 0 → 1). El tinte no usa la profundidad real (no hay lectura de pantalla): crece con el radio (más hondo hacia el centro).
	const CODIGO_AGUA_HUECO: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 tinte : source_color = vec3(0.24, 0.62, 0.64);
uniform vec3 brillo : source_color = vec3(0.88, 0.97, 0.96);
uniform vec2 salida = vec2(0.0, 1.0);          // hacia dónde sale el surco: una ondulación muy tenue dentro de la superficie
uniform vec2 forma = vec2(1.0, 1.0);
uniform vec2 lob = vec2(0.035, 0.02);
uniform float pulso = 2.0;
uniform float radio = 0.54;
varying vec2 pxz;
void vertex() {
	pxz = VERTEX.xz;
}
void fragment() {
	vec2 p = pxz / radio / forma;
	float r = length(p);
	float a = atan(p.y, p.x);
	float b = 0.9 + lob.x * sin(a * 5.0 + 1.0) + lob.y * sin(a * 9.0 + 2.0);
	if (r > b) { discard; }
	float d = pow(1.0 - smoothstep(0.0, b, r), 1.4);               // 1 en el centro (hondo), 0 en la orilla
	float alpha = 0.09 + 0.09 * d;                                 // mínimo de tinte: lo que se ve por la orilla siempre se lee «bajo el agua»
	vec3 c = tinte;
	float w = sin(p.x * 7.0 + TIME * 0.7) * sin(p.y * 6.0 - TIME * 0.6) * 0.5 + 0.5;
	float blob = smoothstep(0.28, 0.0, length(p - vec2(-0.28, -0.25))) * (0.65 + 0.35 * w);
	c = mix(c, brillo, blob * 0.5);
	alpha += blob * 0.2;
	float rr = r - pulso * b;
	float anillo = exp(-rr * rr * 50.0) * step(pulso, 1.2);
	c = mix(c, brillo, anillo * 0.5);
	alpha += anillo * 0.12;
	float rz = fract(TIME * 0.45);
	float dz = length(p - salida * 0.78) - rz * 0.5;
	alpha += exp(-dz * dz * 120.0) * (1.0 - rz) * 0.05;
	ALBEDO = c;
	ALPHA = clamp(alpha, 0.0, 0.75) * (1.0 - smoothstep(b - 0.05, b, r));
}
"""
	## RAICES (el nudo y el puente "beben" de la pila): el fondo del hueco es un lecho de raices finas entrelazadas (venas de un Voronoi, dos escalas) del mismo verde que el puente, sobre un fondo oscuro; de el suben unas
	## pocas raices de CONEXION (tubos finos de `ZarcilloMalla`) por la pared hasta la boca del surco y siguen junto al hilo de agua hasta el nudo. DORMIDAS (oliva apagado, #7A8450) hasta regar; al llenarse el agua una
	## onda de SAVIA (uniform `savia` 0 -> 1, T_HILO s) las despierta desde el fondo hacia el nudo (primero el fondo, luego los tubos) y al llegar se abre el nudo. Constantes: RAICES_DENSIDAD, N_RAICES_CONEXION, RAIZ_RADIO,
	## RAIZ_SUBIDA (que fraccion del radio del hueco sube por la pared). El contorno se desvanece hacia el oscuro de la pila (sin borde) y el disco es menor que el agua.
	const CODIGO_FONDO_HUECO: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 dormido : source_color = vec3(0.478, 0.518, 0.314);
uniform vec3 vivo : source_color = vec3(0.494, 0.62, 0.271);
uniform vec2 salida = vec2(0.0, 1.0);
uniform float radio = 0.46;
uniform float densidad = 5.5;
uniform float savia = 0.0;
varying vec2 pxz;
vec2 h2(vec2 i) {
	return fract(sin(vec2(dot(i, vec2(127.1, 311.7)), dot(i, vec2(269.5, 183.3)))) * 43758.5453);
}
float venas(vec2 x) {
	vec2 w = x + 0.9 * vec2(sin(x.y * 1.7 + 1.3), cos(x.x * 1.9 + 0.4));
	w += 0.5 * vec2(sin(w.y * 3.1 + TIME * 0.1), cos(w.x * 2.7));
	return abs(sin(w.x * 2.0 + sin(w.y * 1.3) * 1.4)) * 0.55;
}
void vertex() {
	pxz = VERTEX.xz;
}
void fragment() {
	vec2 p = pxz / radio;
	float r = length(p);
	float v = 0.5 * max(1.0 - smoothstep(0.0, 0.09, venas(p * densidad * 0.55)), (1.0 - smoothstep(0.0, 0.07, venas(p * densidad * 0.9 + 7.0))) * 0.7);
	float t = 0.5 + 0.5 * dot(p, normalize(salida));
	float frente = savia * 1.25;
	float vivo_k = 1.0 - smoothstep(frente - 0.12, frente, t);
	float banda = exp(-pow((t - frente + 0.06) * 9.0, 2.0)) * step(0.001, savia) * step(savia, 0.999);
	float tono = 0.93 + 0.14 * (sin(p.x * 17.0 + p.y * 11.0) * 0.5 + 0.5);
	vec3 raiz = mix(dormido, vivo, vivo_k) * tono * 0.55;
	vec3 c = mix(vec3(0.025, 0.05, 0.045), raiz, v) + vec3(0.25, 0.35, 0.1) * banda * v;
	c = mix(c, vec3(0.03, 0.07, 0.09), smoothstep(0.5, 0.95, r));
	ALBEDO = c;
	ALPHA = 1.0 - smoothstep(0.45, 0.98, r);
}
"""
	## Raices de conexion: tubos con el UV.x a lo largo (0 en el fondo, 1 en el nudo); despiertan donde `savia` ha pasado.
	const CODIGO_RAIZ_CONEXION: String = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 dormido : source_color = vec3(0.478, 0.518, 0.314);
uniform vec3 vivo : source_color = vec3(0.494, 0.62, 0.271);
uniform float savia = 0.0;
uniform bool invertir = false;
uniform vec3 sumergida = vec3(0.75, 1.05, 0.7);
uniform float rim = 0.4;
uniform float nivel = 1.0;
varying float yy;
void vertex() {
	yy = VERTEX.y;
}
void fragment() {
	float f = invertir ? 1.0 - UV.x : UV.x;
	float k = 1.0 - smoothstep(savia - 0.08, savia, f);
	float banda = exp(-pow((f - savia + 0.04) * 12.0, 2.0)) * step(0.001, savia) * step(savia, 0.999);
	float sub = 1.0 - smoothstep(nivel - 0.03, nivel + 0.01, yy);          // la parte bajo la superficie del agua
	vec3 col = mix(dormido, vivo, k) * COLOR.rgb;
	col = mix(col, col * sumergida, sub);
	float franja = smoothstep(nivel - 0.14, nivel - 0.03, yy) * (1.0 - smoothstep(nivel - 0.03, nivel + 0.01, yy));
	col *= 1.0 - 0.3 * franja;                     // transicion suave justo bajo la superficie (no un corte)
	ALBEDO = col + vec3(0.2, 0.3, 0.08) * banda;
	SPECULAR = 0.1;
	RIM = rim;
	RIM_TINT = 0.3;
	EMISSION += col * 0.22 * rim * (1.0 - sub);      // minima autoiluminacion por encima del agua (se lee contra la pared oscura), nada fuerte
	EMISSION += vec3(0.1, 0.18, 0.04) * banda * 2.0;
	ROUGHNESS = 0.9;
}
"""
	## TODO piedra Meshy: compensacion de color de lo SUMERGIDO. El agua (sin luz propia, translucida) blanquea lo que hay debajo (lo que lo lavaba era el tinte turquesa claro del agua sobre raices mas oscuras, no
	## la luz ni el vertex color: sin agua las raices se ven verde puente). Multiplicador RGB que se aplica a las raices por debajo del nivel del agua: menos rojo y azul, algo mas de verde = mas saturacion y menos valor.
	const RAIZ_SUMERGIDA_TINTE: Vector3 = Vector3(0.75, 1.05, 0.7)
	const RAICES_DENSIDAD: float = 5.5          ## densidad de las venas finas pintadas del fondo (relleno entre los tubos)
	## TODO piedra Meshy: el trazado de las raices del fondo y de la conexion sale de HUECO_* y de estas. Pared del hueco (radio a ras del fondo y arriba, y altura del labio), numero de raices del fondo (N_RAICES_FONDO),
	## ramas por raiz (RAMAS_POR_RAIZ) y su grosor (RAIZ_FONDO_RADIO). Con la piedra Meshy remedirlas del modelo.
	const HUECO_PARED_ABAJO: float = 0.30 * PIEDRA_ESCALA
	const HUECO_PARED_ARRIBA: float = 0.40 * PIEDRA_ESCALA
	const HUECO_LABIO_Y: float = 0.37 * PIEDRA_ESCALA
	const N_RAICES_FONDO: int = 6
	const RAMAS_POR_RAIZ: int = 1
	const RAIZ_FONDO_RADIO: float = 0.045
	## TODO piedra Meshy (raices de conexion = 1 PRINCIPAL + 2 SECUNDARIAS): la principal nace en la marana del fondo (mismo punto de arranque que las raices del fondo), sube pegada a la pared interior, apoya en el labio y baja
	## por fuera hasta la base del nudo; las secundarias, mas finas, se separan de ella a distinta altura y se enroscan alrededor (helice). Remedir con el modelo: HUECO_PARED_*, HUECO_EXTERIOR_*, HUECO_LABIO_Y.
	const RAIZ_PRINCIPAL_RADIO: Vector2 = Vector2(0.05, 0.04)        ## grosor al empezar y al acabar (u)
	const RAIZ_SECUNDARIA_RADIO: Vector2 = Vector2(0.03, 0.018)
	const RAIZ_HELICE_RADIO: float = 0.08                            ## radio de la helice de las secundarias alrededor de la principal
	const RAIZ_HELICE_VUELTAS: Vector2 = Vector2(1.5, 1.0)            ## vueltas de cada secundaria
	const RAIZ_SECUNDARIA_DESDE: Vector2 = Vector2(0.2, 0.35)         ## a que fraccion del recorrido de la principal se separa cada una (una bajo el agua, otra cerca del labio)
	const RAIZ_SUBIDA: float = 0.15                                   ## fraccion de la altura (fondo -> labio) a la que la principal llega a la pared
	const RAIZ_SEPARACION: float = 0.075                               ## separacion lateral (u) de cada secundaria respecto a la principal al cruzar el labio (puntos distintos: sin garra); se juntan de nuevo en el nudo
	const RAIZ_REPTA_Y: float = 0.03                                  ## altura del eje de la raiz sobre el suelo en el tramo exterior (la hierba no la tapa)
	const RAIZ_REPTA_ONDA: float = 0.07                               ## serpenteo lateral de ese tramo (u)
	const RAIZ_BORDE_LUZ: float = 0.4                                 ## borde de luz suave (rim) y autoiluminacion minima de lo que va por encima del agua: se lee contra la pared oscura
	const LABIO_APLASTADO: float = 0.3                                ## cuanto se hunde en el labio (fraccion de su grosor): se lee el contacto
	const HUECO_EXTERIOR_ARRIBA: float = 0.52 * PIEDRA_ESCALA         ## radio de la pared EXTERIOR junto al labio y a ras del suelo
	const HUECO_EXTERIOR_ABAJO: float = 0.57 * PIEDRA_ESCALA
	static var _sombreado_agua: Shader = null
	static var _sombreado_fondo: Shader = null
	static var _sombreado_raiz: Shader = null
	const BOCA_DESPLAZA: float = -0.2          ## dónde rebosa el surco: u hacia `dir` desde el centro de la casilla, a BOCA_LATERAL hacia el lado del nudo, y a BOCA_Y de altura
	const BOCA_LATERAL: float = 0.5
	const BOCA_Y: float = 0.52
	const T_AGUA: float = 0.4                  ## el agua sube en el hueco
	const T_HILO: float = 0.5                  ## el hilo baja por el surco hasta el nudo
	const T_NUDO: float = 0.9                  ## el nudo se desenrolla
	const COLOR_NUDO_DORMIDO: Color = Color("7A8450")      ## verde oliva apagado, mate: NO paja (lo seco arde)
	const COLOR_NUDO_VIVO: Color = PuenteRaices3D.COLOR_ZARCILLO         ## el único verde de todo lo vivo del puente (#8FB548)
	const ARTE_ENTORNO = preload("res://presentacion/arte_entorno_3d.gd")     ## su `sin_brote`: con surco no sale la plantita genérica (el nudo es el brote)
	const N_ESPIRAS: int = 4
	const NUDO_ESCALA: float = 1.25            ## el nudo provisional mide ~0,7 de ancho: a 1,25 no se esconde tras el borde de la piedra desde la cámara

	var celda: Vector2i
	var flag: String
	var germinado: bool = false
	var con_tocon: bool = false                ## `modelo=tocon`: lo pone quien monta la pieza, ANTES de añadirla al árbol
	var con_surco: bool = false                ## `modelo=surco`: idem
	var dir_txt: String = "s"                  ## `dir=` (solo con surco): n|e|s|o
	var fx: Vfx3D = null                       ## para las esporas del brote (opcional)
	var _seco: Node3D = null
	var _vivo: Node3D = null
	# --- surco ---
	var _piedra: Node3D = null
	var _agua_hueco: MeshInstance3D = null
	var _mat_agua: ShaderMaterial = null
	var _fondo_hueco: MeshInstance3D = null
	var _mat_fondo: ShaderMaterial = null
	var _raices_fondo: MeshInstance3D = null    ## los tubos que serpentean por el fondo del hueco
	var _mat_raiz_fondo: ShaderMaterial = null
	var _mats_raiz: Array = []                 ## ShaderMaterial de cada raiz de conexion
	var _raices_conexion: Array = []           ## MeshInstance3D de las raices que suben del fondo al nudo
	var _savia_v: float = 0.0                  ## 0 dormidas ... 1 despiertas
	var _hilo: Node3D = null                   ## pivote del hilo de agua (se alarga con su `scale.z`)
	var _nudo: Node3D = null
	var _espiras: Array = []                   ## MeshInstance3D del nudo provisional
	var _mat_nudo: StandardMaterial3D = null
	var _nudo_glb_dormido: Node3D = null
	var _nudo_glb_vivo: Node3D = null
	var nudo_abierto: bool = false
	var t_nudo_abierto: int = -1               ## ms (Time.get_ticks_msec) en que se abrió el nudo: las pruebas lo comparan con el arranque del puente

	func _exit_tree() -> void:
		if con_surco:
			ARTE_ENTORNO.sin_brote.erase(celda)

	func _ready() -> void:
		germinado = Flags.i().tiene(flag)
		if con_tocon:
			_montar_tocon()
		elif con_surco:
			ARTE_ENTORNO.sin_brote[celda] = true
			_montar_surco()
		if germinado:
			Terreno3D.estados.poner_material(celda, "hierba")
		else:
			Terreno3D.estados.germino.connect(_al_germinar)
			Terreno3D.estados.cambio.connect(_al_cambiar)

	## El tocón: la pieza se coloca en el centro de la casilla (el bancal es un Node3D en el origen del contenedor) y se carga el modelo que toque; al cargar ya germinado
	## solo se crea el musgoso. Se le QUITA el `cuerpo` (StaticBody3D de la escena provisional, capa de bloqueo): una casilla bloqueada no recibe hechizos de suelo y el bancal nunca germinaría.
	func _montar_tocon() -> void:
		var y: float = Terreno3D.y_pies(celda) if Terreno3D.hay_mundo() else 0.0
		position = Terreno3D.centro_de(celda, y)
		if germinado:
			_vivo = _cargar_tocon(ESCENA_TOCON_VIVO)
		else:
			_seco = _cargar_tocon(ESCENA_TOCON_SECO)

	func _cargar_tocon(ruta: String) -> Node3D:
		if not ResourceLoader.exists(ruta):
			return null
		var n: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
		if n == null:
			return null
		for cuerpo in n.find_children("*", "CollisionObject3D", true, false):
			(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
			(cuerpo as Node).free()
		add_child(n)
		return n

	## 23/11 (decisión de la demo): basta el agua. Mojar la casilla la vuelve hierba (la maqueta pinta con `material_cambiado`).
	func _al_cambiar(c: Vector2i, estado: String, si: bool) -> void:
		if c != celda or germinado or not si or estado != EstadosSuelo3D.MOJADA:
			return
		Terreno3D.estados.poner_material(celda, "hierba")
		_cerrar()

	func _al_germinar(c: Vector2i) -> void:
		if c != celda or germinado:
			return
		_cerrar()

	## Cierre común (agua sola o agua → naturaleza): una sola vez, desconecta ambas señales, flag y aviso.
	func _cerrar() -> void:
		var e: EstadosSuelo3D = Terreno3D.estados
		if e.germino.is_connected(_al_germinar):
			e.germino.disconnect(_al_germinar)
		if e.cambio.is_connected(_al_cambiar):
			e.cambio.disconnect(_al_cambiar)
		germinado = true
		Flags.i().poner(flag)
		if con_surco:
			_germinar_surco()          # `germino` sale cuando el nudo empieza a abrirse
			return
		if con_tocon:
			_brotar_tocon()
		germino.emit()

	## Cambia la malla seca por la musgosa con un pop de escala (y unas esporas si hay Vfx3D).
	func _brotar_tocon() -> void:
		if _seco != null:
			_seco.visible = false
		if _vivo == null:
			_vivo = _cargar_tocon(ESCENA_TOCON_VIVO)
		if _vivo == null:
			return
		if is_inside_tree():
			_vivo.scale = Vector3.ONE * POP_INICIO
			var tw: Tween = create_tween()
			tw.tween_property(_vivo, "scale", Vector3.ONE, POP_DURA).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if fx != null and is_instance_valid(fx):
				var efectos: Array = [fx.esporas(global_position + Vector3(0.0, 0.6, 0.0)),
					fx.destellos(global_position + Vector3(0.0, 0.9, 0.0), Vfx3D.COLOR.get("naturaleza", Color(0.45, 0.8, 0.3)))]
				var vfx: Vfx3D = fx
				get_tree().create_timer(1.2).timeout.connect(func() -> void:        # esporas y destellos se quedan emitiendo: los suelta quien los pide
					for ef in efectos:
						if is_instance_valid(vfx) and is_instance_valid(ef):
							vfx.apagar(ef as Node3D))

	# ------------------------------------------------------------------ modelo=surco ------------------------------------------------------------------

	## Hacia dónde mira el surco (eje del mundo).
	func dir_v() -> Vector3:
		match dir_txt:
			"n": return Vector3(0.0, 0.0, -1.0)
			"e": return Vector3(1.0, 0.0, 0.0)
			"o": return Vector3(-1.0, 0.0, 0.0)
		return Vector3(0.0, 0.0, 1.0)

	func _material_agua() -> ShaderMaterial:
		if _sombreado_agua == null:
			_sombreado_agua = Shader.new()
			_sombreado_agua.code = CODIGO_AGUA_HUECO
		var m := ShaderMaterial.new()
		m.shader = _sombreado_agua
		m.set_shader_parameter("radio", HUECO_RADIO)
		m.set_shader_parameter("forma", HUECO_FORMA)
		m.set_shader_parameter("lob", HUECO_LOBULOS)
		m.render_priority = 1            # por encima del fondo
		return m

	func _material_raiz() -> ShaderMaterial:
		if _sombreado_raiz == null:
			_sombreado_raiz = Shader.new()
			_sombreado_raiz.code = CODIGO_RAIZ_CONEXION
		var m := ShaderMaterial.new()
		m.shader = _sombreado_raiz
		m.set_shader_parameter("dormido", COLOR_NUDO_DORMIDO)
		m.set_shader_parameter("vivo", COLOR_NUDO_VIVO)
		m.set_shader_parameter("savia", 0.0)
		m.set_shader_parameter("sumergida", RAIZ_SUMERGIDA_TINTE)
		m.set_shader_parameter("nivel", _piedra.position.y + HUECO_Y)
		m.set_shader_parameter("rim", RAIZ_BORDE_LUZ)
		return m

	## Savia 0 -> 1: el fondo despierta en la primera mitad y las raices de conexion en la segunda.
	func _savia(v: float) -> void:
		_savia_v = v
		_mat_fondo.set_shader_parameter("savia", clampf(v * 2.0, 0.0, 1.0))
		if _mat_raiz_fondo != null:
			_mat_raiz_fondo.set_shader_parameter("savia", clampf(v * 2.0, 0.0, 1.0))
		for m in _mats_raiz:
			(m as ShaderMaterial).set_shader_parameter("savia", clampf(v * 2.0 - 1.0, 0.0, 1.0))

	func _material_fondo() -> ShaderMaterial:
		if _sombreado_fondo == null:
			_sombreado_fondo = Shader.new()
			_sombreado_fondo.code = CODIGO_FONDO_HUECO
		var m := ShaderMaterial.new()
		m.shader = _sombreado_fondo
		m.set_shader_parameter("radio", HUECO_RADIO * HUECO_FONDO_ESCALA)
		m.set_shader_parameter("dormido", COLOR_NUDO_DORMIDO)
		m.set_shader_parameter("vivo", COLOR_NUDO_VIVO)
		m.set_shader_parameter("densidad", RAICES_DENSIDAD)
		m.set_shader_parameter("savia", 0.0)
		return m

	## Un .glb de Meshy ya instanciado y sin colisiones (null si no existe el archivo).
	func _cargar_glb(ruta: String) -> Node3D:
		if not ResourceLoader.exists(ruta):
			return null
		var ps: PackedScene = load(ruta) as PackedScene
		var n: Node3D = ps.instantiate() as Node3D if ps != null else null
		if n == null:
			return null
		for cuerpo in n.find_children("*", "CollisionObject3D", true, false):
			(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
			(cuerpo as Node).free()
		return n

	## Monta todo en su estado inicial (agua, hilo y nudo dormido) o, si ya está germinado, en el final. Los modelos de Meshy, si existen, sustituyen a los provisionales.
	func _montar_surco() -> void:
		var y: float = Terreno3D.y_pies(celda) if Terreno3D.hay_mundo() else 0.0
		position = Terreno3D.centro_de(celda, y)
		var d: Vector3 = dir_v()
		var giro: float = atan2(-d.z, d.x)         # el eje +x del modelo mira hacia `d`
		# La piedra (sin colisión).
		_piedra = Node3D.new()
		_piedra.name = "piedra_surco"
		_piedra.position = d * PIEDRA_DESPLAZA
		add_child(_piedra)
		var glb: Node3D = _cargar_glb(MODELO_PIEDRA_SURCO)
		if glb != null:
			glb.rotation.y = giro
			_piedra.add_child(glb)
		else:
			var mi := MeshInstance3D.new()
			var malla: Mesh = PiezaPuzle3D.malla_modelo(PIEDRA_PROVISIONAL)
			if malla != null:
				mi.mesh = malla
				mi.scale = Vector3.ONE * PIEDRA_ESCALA
			else:
				var cil := CylinderMesh.new()
				cil.top_radius = 0.5 * PIEDRA_ESCALA
				cil.bottom_radius = 0.55 * PIEDRA_ESCALA
				cil.height = 0.37 * PIEDRA_ESCALA
				var piedra_mat := StandardMaterial3D.new()
				piedra_mat.albedo_color = Color(0.58, 0.56, 0.52)
				piedra_mat.roughness = 0.95
				cil.material = piedra_mat
				mi.mesh = cil
				mi.position.y = cil.height * 0.5
			_piedra.add_child(mi)
		# El agua del hueco: shader propio (CODIGO_AGUA_HUECO) sobre un disco un poco más pequeño que la boca. Oculto hasta regar. (La pared mojada se insinúa con el degradado a turquesa oscuro del propio shader; un cilindro aparte sobresalía de la pila.)
		var disco := CylinderMesh.new()
		disco.top_radius = HUECO_RADIO * maxf(HUECO_FORMA.x, HUECO_FORMA.y) * 1.05       # el disco ha de contener el contorno (elipse con lóbulos)
		disco.bottom_radius = disco.top_radius
		disco.height = 0.01
		disco.radial_segments = 32
		disco.rings = 1
		_agua_hueco = MeshInstance3D.new()
		_agua_hueco.name = "agua_hueco"
		_agua_hueco.mesh = disco
		_mat_agua = _material_agua()
		_agua_hueco.material_override = _mat_agua
		_agua_hueco.position = _piedra.position + Vector3(HUECO_CENTRO.x, HUECO_Y, HUECO_CENTRO.y)
		_agua_hueco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_agua_hueco.visible = false
		add_child(_agua_hueco)
		var disco_f := CylinderMesh.new()
		disco_f.top_radius = HUECO_RADIO * HUECO_FONDO_ESCALA
		disco_f.bottom_radius = disco_f.top_radius
		disco_f.height = 0.005
		disco_f.radial_segments = 96
		disco_f.rings = 1
		_mat_fondo = _material_fondo()
		_fondo_hueco = MeshInstance3D.new()
		_fondo_hueco.name = "fondo_hueco"
		_fondo_hueco.mesh = disco_f
		_fondo_hueco.material_override = _mat_fondo
		_fondo_hueco.position = _piedra.position + Vector3(HUECO_CENTRO.x + HUECO_FONDO_DESPLAZA.x, HUECO_FONDO_Y, HUECO_CENTRO.y + HUECO_FONDO_DESPLAZA.y)
		_fondo_hueco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_fondo_hueco)
		# El hilo de agua: del reborde del surco al nudo. Pivote en la boca, mirando al nudo; su `scale.z` lo alarga.
		var lat: Vector3 = Vector3(-d.z, 0.0, d.x) * PuenteRaices3D.lado_nudo(d)        # hacia el lado del nudo (el de la cámara)
		var boca: Vector3 = d * BOCA_DESPLAZA + lat * BOCA_LATERAL + Vector3(0.0, BOCA_Y, 0.0)
		var hacia: Vector3 = boca - _agua_hueco.position
		_mat_agua.set_shader_parameter("salida", Vector2(hacia.x, hacia.z).normalized())
		var fin: Vector3 = d * NUDO_DESPLAZA + lat * PuenteRaices3D.NUDO_LATERAL + Vector3(0.0, 0.28, 0.0)
		_mat_fondo.set_shader_parameter("salida", Vector2(hacia.x, hacia.z).normalized())
		_montar_raices_fondo(boca)
		_montar_raices_conexion(boca, fin)
		_hilo = Node3D.new()
		_hilo.name = "hilo_agua"
		add_child(_hilo)
		_hilo.look_at_from_position(boca, fin, Vector3.UP)
		var largo: float = boca.distance_to(fin)
		var cilh := CylinderMesh.new()
		cilh.top_radius = 0.075
		cilh.bottom_radius = 0.065
		cilh.height = largo
		cilh.radial_segments = 8
		cilh.rings = 1
		cilh.material = Reactivo3D.material_caudal(false, 3.5, 3.0, true)       # opaco: el mismo agua que el cuenco, que se ve
		var hm := MeshInstance3D.new()
		hm.mesh = cilh
		hm.rotation.x = PI * 0.5
		hm.position = Vector3(0.0, 0.0, -largo * 0.5)
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hilo.add_child(hm)
		_hilo.visible = false
		# El nudo (en el borde de +dir).
		_nudo = Node3D.new()
		_nudo.name = "nudo"
		_nudo.position = d * NUDO_DESPLAZA + lat * PuenteRaices3D.NUDO_LATERAL
		_nudo.rotation.y = giro
		_nudo.scale = Vector3.ONE * NUDO_ESCALA
		add_child(_nudo)
		_nudo_glb_dormido = _cargar_glb(MODELO_NUDO_DORMIDO)
		_nudo_glb_vivo = _cargar_glb(MODELO_NUDO_VIVO)
		if _nudo_glb_dormido != null and _nudo_glb_vivo != null:
			_nudo.add_child(_nudo_glb_dormido)
			_nudo.add_child(_nudo_glb_vivo)
			_nudo_glb_vivo.visible = false
		else:
			if _nudo_glb_dormido != null:
				_nudo_glb_dormido.free()
			if _nudo_glb_vivo != null:
				_nudo_glb_vivo.free()
			_nudo_glb_dormido = null
			_nudo_glb_vivo = null
			_montar_nudo_provisional()
		if germinado:
			_poner_estado_final_surco()

	## Nudo provisional: una espiral de zarcillo (2,5 vueltas, de fuera a dentro) partida en N_ESPIRAS arcos, más una cola que apunta a +x (hacia el puente). Un material compartido que cambia de color al abrirse.
	func _montar_nudo_provisional() -> void:
		_mat_nudo = StandardMaterial3D.new()
		_mat_nudo.albedo_color = COLOR_NUDO_DORMIDO
		_mat_nudo.roughness = 0.95
		_mat_nudo.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_nudo.vertex_color_use_as_albedo = true            # tono por espira y falso oscurecimiento de ZarcilloMalla
		_mat_nudo.emission_enabled = true                      # solo el destello del despertar; en reposo, sin emisión
		_mat_nudo.emission = COLOR_NUDO_VIVO
		_mat_nudo.emission_energy_multiplier = 0.0
		var pasos_por: int = 14
		var total: int = N_ESPIRAS * pasos_por
		var vueltas: float = 2.5
		for k in range(N_ESPIRAS):
			var pts: PackedVector3Array = PackedVector3Array()
			if k == 0:
				pts.append(Vector3(0.66, 0.075, 0.0))        # la cola: sale hacia +x y entra en la espiral por fuera
				pts.append(Vector3(0.5, 0.075, 0.0))
			for s in range(pasos_por + 1):
				var f: float = float(k * pasos_por + s) / float(total)
				var a: float = f * vueltas * TAU
				var r: float = 0.34 * (1.0 - 0.72 * f)
				pts.append(Vector3(cos(a) * r, 0.085 + 0.15 * f, -sin(a) * r))
			var zm := ZarcilloMalla.new()
			zm.tubo(pts, 0.075 - 0.01 * float(k), 0.075 - 0.01 * float(k + 1), 7, k == 0 or k == N_ESPIRAS - 1)
			var mi := MeshInstance3D.new()
			mi.name = "espira_%d" % k
			mi.mesh = zm.malla()
			mi.material_override = _mat_nudo
			_nudo.add_child(mi)
			_espiras.append(mi)

	func color_nudo() -> Color:
		return _mat_nudo.albedo_color if _mat_nudo != null else Color(0, 0, 0, 0)

	## RAICES DEL FONDO: N_RAICES_FONDO tubos curvos (ZarcilloMalla, grosor decreciente a la punta) que serpentean desde la zona de la boca del surco hacia el resto del hueco y se ramifican (RAMAS_POR_RAIZ), con alguna
	## punta enroscada. Un solo mesh y un material (CODIGO_RAIZ_CONEXION con `invertir`: la savia va de las puntas hacia la boca). Todo relativo al centro/radio/forma del fondo (HUECO_*).
	func _montar_raices_fondo(boca: Vector3) -> void:
		var f: Vector3 = _fondo_hueco.position
		var h: Vector3 = Vector3(boca.x - f.x, 0.0, boca.z - f.z).normalized()
		var radio: float = HUECO_RADIO * HUECO_FONDO_ESCALA * 0.8
		var escala: Vector3 = Vector3(HUECO_FORMA.x, 1.0, HUECO_FORMA.y)
		var zm := ZarcilloMalla.new()
		var y: float = f.y + 0.02
		var inicio: Vector3 = f + h * radio * 0.7 * escala
		inicio.y = y
		var base_ang: float = atan2(-h.z, -h.x)           # hacia el lado opuesto a la boca
		for k in range(N_RAICES_FONDO):
			var a: float = base_ang + (float(k) - float(N_RAICES_FONDO - 1) * 0.5) * (PI * 1.5 / float(maxi(1, N_RAICES_FONDO - 1)))
			var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var largo: float = radio * (1.15 + 0.35 * sin(float(k) * 2.1))
			var pts := PackedVector3Array()
			var pasos: int = 12
			for i in range(pasos + 1):
				var t: float = float(i) / float(pasos)
				var q: Vector3 = inicio + dir * largo * t
				q += Vector3(-dir.z, 0.0, dir.x) * sin(t * 6.0 + float(k)) * 0.07 * (0.3 + t)      # serpentea
				var rel: Vector3 = (q - f) / escala
				rel.y = 0.0
				if rel.length() > radio:                                                      # no salirse del fondo
					q = f + rel.normalized() * radio * escala
				q.y = y + 0.012 * t
				pts.append(q)
			zm.tubo(pts, RAIZ_FONDO_RADIO, RAIZ_FONDO_RADIO * 0.28, 5, true)
			for r in range(RAMAS_POR_RAIZ):
				var ti: int = 5 + r * 3
				var lado: float = 1.0 if (k + r) % 2 == 0 else -1.0
				var da: float = a + lado * 0.7
				var d2: Vector3 = Vector3(cos(da), 0.0, sin(da))
				var pr := PackedVector3Array()
				for i in range(8):
					var t2: float = float(i) / 7.0
					var q2: Vector3 = (pts[ti] as Vector3) + d2 * largo * 0.4 * t2 + Vector3(-d2.z, 0.0, d2.x) * sin(t2 * 5.0) * 0.04
					var rel2: Vector3 = (q2 - f) / escala
					rel2.y = 0.0
					if rel2.length() > radio:
						q2 = f + rel2.normalized() * radio * escala
					q2.y = y + 0.012
					pr.append(q2)
				zm.tubo(pr, RAIZ_FONDO_RADIO * 0.55, RAIZ_FONDO_RADIO * 0.18, 5, true)
			if k % 2 == 0:                                                                     # algunas puntas, enroscadas
				var punta: Vector3 = pts[pasos]
				var sale: Vector3 = (punta - (pts[pasos - 1] as Vector3)).normalized()
				zm.rizo(punta, sale, Vector3.UP, 0.05, 1.3, RAIZ_FONDO_RADIO * 0.2, 4)
		_raices_fondo = MeshInstance3D.new()
		_raices_fondo.name = "raices_fondo"
		_raices_fondo.mesh = zm.malla()
		_mat_raiz_fondo = _material_raiz()
		_mat_raiz_fondo.set_shader_parameter("invertir", true)
		_raices_fondo.material_override = _mat_raiz_fondo
		_raices_fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_raices_fondo)

	## RAICES DE CONEXION (1 principal + 2 secundarias): ver las constantes RAIZ_*. La principal arranca del mismo punto que las raices del fondo (sin costura), se pega a la pared interior (radio de la pared menos su grosor
	## y 0,015 de holgura, con un leve serpenteo), se APOYA en el labio (hundida LABIO_APLASTADO en el borde) y baja por fuera pegada a la pared exterior hasta meterse en la base del nudo. Las secundarias salen de ella a
	## distinta altura y se enroscan a su alrededor (helice) hasta el mismo final: ninguna punta queda a la vista. Sin colision. El UV.x de cada tubo es su recorrido (la savia lo sigue).
	func _montar_raices_conexion(boca: Vector3, fin: Vector3) -> void:
		var c: Vector3 = _agua_hueco.position
		var base_y: float = _piedra.position.y
		var y0: float = base_y + HUECO_FONDO_Y
		var yl: float = base_y + HUECO_LABIO_Y
		var h: Vector3 = Vector3(boca.x - c.x, 0.0, boca.z - c.z).normalized()
		var escala: Vector3 = Vector3(HUECO_FORMA.x, 1.0, HUECO_FORMA.y)
		var r0: float = RAIZ_PRINCIPAL_RADIO.x
		var inicio: Vector3 = _fondo_hueco.position + h * (HUECO_RADIO * HUECO_FONDO_ESCALA * 0.8) * 0.7 * escala      # = el de las raices del fondo
		inicio.y = _fondo_hueco.position.y + 0.02
		var lado: Vector3 = Vector3(-h.z, 0.0, h.x)
		var claves: Array = [inicio + h * 0.05]
		# pared interior: sube desde el fondo hasta cerca del labio, pegada a ella, serpenteando un poco
		var pasos: int = 6
		for i in range(pasos + 1):
			var t: float = float(i) / float(pasos)
			var yy: float = lerpf(y0 + (yl - y0) * RAIZ_SUBIDA, yl - 0.1, t)
			var tp: float = clampf((yy - y0) / (yl - y0), 0.0, 1.0)
			var rp: float = lerpf(HUECO_PARED_ABAJO, HUECO_PARED_ARRIBA, tp) - lerpf(RAIZ_PRINCIPAL_RADIO.x, RAIZ_PRINCIPAL_RADIO.y, 0.4) - 0.015
			var q: Vector3 = c + (h * rp + lado * sin(t * 7.0) * 0.035 * (1.0 - t)) * escala
			q.y = yy
			claves.append(q)
		# el labio: ABRAZANDO la piedra (arco bajo y asimetrico: entra casi recta y se tumba hacia fuera con una curva mas larga)
		var rr: float = RAIZ_PRINCIPAL_RADIO.y
		var rl: float = HUECO_PARED_ARRIBA + 0.04
		var entra: Vector3 = c + h * (HUECO_PARED_ARRIBA - rr * 0.5) * escala
		entra.y = yl - 0.02
		claves.append(entra)
		var sobre: Vector3 = c + h * (rl + 0.035) * escala
		sobre.y = yl + rr * (1.0 - LABIO_APLASTADO) + 0.005
		claves.append(sobre)
		var tumba: Vector3 = c + h * (rl + 0.16) * escala
		tumba.y = yl - 0.035
		claves.append(tumba)
		# por fuera: en diagonal por la pared exterior hasta el suelo
		var ext2: Vector3 = c + (h * (HUECO_EXTERIOR_ARRIBA + 0.04) + lado * 0.03) * escala
		ext2.y = yl - 0.26
		claves.append(ext2)
		var ext3: Vector3 = c + (h * (HUECO_EXTERIOR_ABAJO + 0.05)) * escala
		ext3.y = base_y + RAIZ_REPTA_Y + 0.02
		claves.append(ext3)
		# repta por el suelo con una curva suave hasta la base del nudo
		var base_nudo: Vector3 = fin + Vector3(0.0, -0.17, 0.0)
		var dir_suelo: Vector3 = Vector3(base_nudo.x - ext3.x, 0.0, base_nudo.z - ext3.z)
		var lado_s: Vector3 = Vector3(-dir_suelo.z, 0.0, dir_suelo.x).normalized()
		for i in range(1, 4):
			var tt: float = float(i) / 4.0
			var q2: Vector3 = ext3.lerp(base_nudo, tt) + lado_s * sin(tt * 5.5) * RAIZ_REPTA_ONDA
			q2.y = base_y + RAIZ_REPTA_Y
			claves.append(q2)
		claves.append(base_nudo)
		# polilinea densa (Catmull-Rom)
		var guia: Array = [(claves[0] as Vector3) + ((claves[0] as Vector3) - (claves[1] as Vector3)).normalized() * 0.05] + claves + [base_nudo + (base_nudo - (claves[claves.size() - 2] as Vector3)).normalized() * 0.1]
		var pp := PackedVector3Array()
		for i in range(1, guia.size() - 2):
			for j in range(5):
				pp.append(PuenteRaices3D._catmull(guia[i - 1], guia[i], guia[i + 1], guia[i + 2], float(j) / 5.0))
		pp.append(base_nudo)
		_conexion_tubo("raiz_principal", pp, RAIZ_PRINCIPAL_RADIO.x, RAIZ_PRINCIPAL_RADIO.y)
		# donde cruza el labio (el punto mas alto)
		var n: int = pp.size()
		var i_lip: int = 0
		for i in range(n):
			if pp[i].y > pp[i_lip].y and (pp[i] - c).length() < rl + 0.5:
				i_lip = i
		# secundarias: helice suelta alrededor de la principal ANTES del labio, cruzan el borde a ambos lados de ella (RAIZ_SEPARACION) y vuelven a juntarse con ella en el nudo
		for k in range(2):
			var u0: float = RAIZ_SECUNDARIA_DESDE[k]
			var vueltas: float = RAIZ_HELICE_VUELTAS[k]
			var fase: float = 1.3 + float(k) * 2.4
			var signo: float = -1.0 if k == 0 else 1.0
			var ps := PackedVector3Array()
			for i in range(int(u0 * float(n - 1)), n):
				var w: float = (float(i) / float(n - 1) - u0) / (1.0 - u0)
				var tg: Vector3 = (pp[mini(i + 1, n - 1)] - pp[maxi(i - 1, 0)]).normalized()
				var nn: Vector3 = tg.cross(Vector3.UP)
				if nn.length() < 0.2:
					nn = tg.cross(Vector3.RIGHT)
				nn = nn.normalized()
				var bb: Vector3 = tg.cross(nn).normalized()
				var ro: float = RAIZ_HELICE_RADIO * smoothstep(0.0, 0.15, w) * (1.0 - smoothstep(float(i_lip) - 6.0, float(i_lip) - 1.0, float(i)))
				var ph: float = fase + vueltas * TAU * w
				var off: Vector3 = (nn * cos(ph) + bb * sin(ph)) * ro
				var lat: Vector3 = Vector3.UP.cross(tg)
				if lat.length() < 0.3:
					lat = lado
				lat = lat.normalized()
				var u_ext: float = clampf(float(i - i_lip) / float(maxi(1, n - 1 - i_lip)), 0.0, 1.0)
				var sep: float = RAIZ_SEPARACION * signo * smoothstep(float(i_lip) - 7.0, float(i_lip) - 2.0, float(i)) * (1.0 - smoothstep(0.7, 1.0, u_ext))
				ps.append(pp[i] + off + lat * sep)
			_conexion_tubo("raiz_secundaria_%d" % k, ps, RAIZ_SECUNDARIA_RADIO.x, RAIZ_SECUNDARIA_RADIO.y)

	func _conexion_tubo(nombre: String, pts: PackedVector3Array, r0: float, r1: float) -> void:
		var zm := ZarcilloMalla.new()
		zm.tubo(pts, r0, r1, 6, true)
		var mi := MeshInstance3D.new()
		mi.name = nombre
		mi.mesh = zm.malla()
		var mat: ShaderMaterial = _material_raiz()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_raices_conexion.append(mi)
		_mats_raiz.append(mat)

	## Estado final sin animación (cargado ya germinado, o sin árbol): agua llena, hilo entero, nudo abierto.
	func _poner_estado_final_surco() -> void:
		if _agua_hueco == null:
			return
		_agua_hueco.visible = true
		_agua_hueco.position.y = _piedra.position.y + HUECO_Y
		_agua_hueco.scale = Vector3.ONE
		_mat_agua.set_shader_parameter("pulso", 2.0)
		_savia(1.0)
		_hilo.visible = true
		_hilo.scale = Vector3.ONE
		_abrir_nudo_ya()

	func _abrir_nudo_ya() -> void:
		nudo_abierto = true
		if _mat_nudo != null:
			_mat_nudo.albedo_color = COLOR_NUDO_VIVO
			_mat_nudo.roughness = 0.85
			_mat_nudo.emission_energy_multiplier = 0.0
		if _nudo_glb_vivo != null:
			_nudo_glb_dormido.visible = false
			_nudo_glb_vivo.visible = true

	## La secuencia: agua sube → hilo → nudo se abre (y entonces `germino`).
	func _germinar_surco() -> void:
		if _agua_hueco == null or not is_inside_tree():
			if _agua_hueco != null:
				_poner_estado_final_surco()
			t_nudo_abierto = Time.get_ticks_msec()
			germino.emit()
			return
		var base_y: float = _piedra.position.y + HUECO_Y
		_agua_hueco.visible = true
		_agua_hueco.position.y = _piedra.position.y + HUECO_FONDO_Y
		_agua_hueco.scale = Vector3(0.35, 1.0, 0.35)
		_mat_agua.set_shader_parameter("pulso", 2.0)
		if fx != null and is_instance_valid(fx):
			fx.salpicadura(global_position + Vector3(_agua_hueco.position.x, base_y, _agua_hueco.position.z), 0.7)
		_hilo.scale = Vector3(1.0, 1.0, 0.001)
		var tw: Tween = create_tween()
		tw.tween_property(_agua_hueco, "position:y", base_y, T_AGUA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_agua_hueco, "scale", Vector3.ONE, T_AGUA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			_hilo.visible = true)
		tw.tween_property(_hilo, "scale:z", 1.0, T_HILO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(v: float) -> void: _mat_agua.set_shader_parameter("pulso", v), 0.0, 1.1, T_HILO)
		tw.parallel().tween_method(_savia, 0.0, 1.0, T_HILO)       # la savia recorre fondo -> raices -> nudo mientras baja el hilo
		tw.tween_callback(_despertar_nudo)

	## El nudo se abre: color lima, pop con rebote, las espiras se desenrollan girando, esporas. Aquí sale `germino`.
	func _despertar_nudo() -> void:
		nudo_abierto = true
		t_nudo_abierto = Time.get_ticks_msec()
		_nudo.scale = Vector3.ONE * NUDO_ESCALA * 0.8
		var tw: Tween = create_tween()
		tw.tween_property(_nudo, "scale", Vector3.ONE * NUDO_ESCALA, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _mat_nudo != null:
			tw.parallel().tween_property(_mat_nudo, "albedo_color", COLOR_NUDO_VIVO, 0.3)
			tw.parallel().tween_property(_mat_nudo, "roughness", 0.85, 0.3)
			tw.parallel().tween_property(_mat_nudo, "emission_energy_multiplier", 0.0, 0.6).from(0.7)
			for k in range(_espiras.size()):
				var e: MeshInstance3D = _espiras[k]
				e.rotation.y = -0.55 * float(k + 1)            # cada arco parte desfasado y se asienta: el nudo «se desenrolla»
				e.scale = Vector3(0.72, 1.0, 0.72)
				var te: Tween = create_tween()
				te.tween_interval(0.07 * float(k))
				te.tween_property(e, "rotation:y", 0.0, T_NUDO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				te.parallel().tween_property(e, "scale", Vector3.ONE, T_NUDO * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_nudo_glb_dormido.visible = false
			_nudo_glb_vivo.visible = true
			var giro_final: float = _nudo.rotation.y
			_nudo.rotation.y = giro_final - 1.0
			tw.parallel().tween_property(_nudo, "rotation:y", giro_final, T_NUDO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if fx != null and is_instance_valid(fx):
			var centro: Vector3 = _nudo.global_position + Vector3(0.0, 0.3, 0.0)
			var efectos: Array = [fx.esporas(centro), fx.destellos(centro + Vector3(0.0, 0.2, 0.0), Vfx3D.COLOR.get("naturaleza", Color(0.45, 0.8, 0.3)))]
			var vfx: Vfx3D = fx
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				for ef in efectos:
					if is_instance_valid(vfx) and is_instance_valid(ef):
						vfx.apagar(ef as Node3D))
		germino.emit()


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
		if not k.pressed or k.echo or not k.is_action("interactuar"):
			return
		if distancia_jugadora() <= ALCANCE_USAR and intentar(true):
			get_viewport().set_input_as_handled()

	## `modelo` "llave" (23/10, la Cueva): marco y hoja de verdad en vez de la losa y sin rótulo. Necesita a la maqueta (`mundo._pieza`) o las
	## escenas horneadas de arte/piezas; si no hay ninguna de las dos, queda la losa.
	func _ready() -> void:
		set_process(llave != "")                  # una puerta sin llave no necesita mirar nada cada fotograma

	func preparar(c: Vector2i, modelo: String = "", mundo: Node = null) -> void:
		celda = c
		add_to_group("e_puerta")               # CargarObjeto3D: E abre la puerta con llave antes que coger un jarrón
		_mundo = mundo
		position = Terreno3D.centro_de(c, Terreno3D.alto_suelo)
		Terreno3D.bloquear_celda(c)
		# La puerta tapa el paso: si la pared sigue de norte a sur (paso de este a oeste), se gira 90°.
		var pared_ns: bool = Terreno3D.letra_de(c + Vector2i(0, -1)) == "#" and Terreno3D.letra_de(c + Vector2i(0, 1)) == "#"
		if pared_ns:
			rotation.y = PI * 0.5
		if modelo == "llave" and _poner_modelo(mundo):
			return
		if modelo == "reja":
			_poner_reja()
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

	## 28/10 (Gruta Batida, `modelo=reja`): REJA de barrotes de hierro que DEJA VER lo que hay detrás (un brasero, una cuerda, la marca de un guardián) y sin rótulo.
	## Tapa la casilla igual que la losa (para a la jugadora y a las flechas, que se paran en ella) y se hunde al abrir.
	func _poner_reja() -> void:
		var reja := Node3D.new()
		reja.name = "reja"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.15, 0.14)
		mat.metallic = 0.7
		mat.roughness = 0.45
		var ancho: float = Terreno3D.casilla * 0.92
		var alto: float = 2.1
		var n_barrotes: int = 7
		for i in range(n_barrotes):
			var b := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.top_radius = 0.035
			cil.bottom_radius = 0.035
			cil.height = alto
			cil.radial_segments = 8
			b.mesh = cil
			b.material_override = mat
			b.position = Vector3(-ancho * 0.5 + ancho * (float(i) + 0.5) / float(n_barrotes), alto * 0.5, 0.0)
			reja.add_child(b)
		for y in [0.25, alto - 0.12]:
			var t := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = Vector3(ancho, 0.09, 0.09)
			t.mesh = caja
			t.material_override = mat
			t.position = Vector3(0.0, y, 0.0)
			reja.add_child(t)
		_losa = reja
		_y0 = 0.0
		add_child(reja)

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
		Sfx.play(self, "puerta_abre" if si else "puerta_cierra")     # 13/11 (inventario SFX): antes no sonaba
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
	var puesto: bool = false                     ## 27/10: sus ARQUEROS son de puesto (`Combate3D.fijo`): no persiguen, baten desde donde nacen
	var debil: String = ""                       ## 6/11 (bloque A2): "" = no toca la debilidad del enemigo (la del nivel); si no, `Combate3D.fijar_debilidad`
	var resiste: String = ""
	var _t: float = 0.0
	var _t_sin: float = 0.0
	var _avisado: bool = false
	## G1 de PLAN_COMBATE (22/11, morir y reintentar): la receta de cada enemigo tal como estaba antes de empezar la pelea, y el nodo del que salió (para cambiar `pz.nodo`).
	var recetas: Array = []
	var originales: Array = []
	var empezado: bool = false                   ## algún enemigo suyo ya está herido, muerto o persiguiendo: el encuentro ha empezado
	var reinicios: int = 0

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

	## G1: la jugadora reapareció. Si el encuentro empezó y no está resuelto, quita a todos sus enemigos (vivos, muertos o nacidos después, como los hijos del limo) y los vuelve
	## a crear sanos en su casilla de partida desde la receta. Devuelve {viejo → nuevo} para que el puzle cambie sus `pz.nodo`. {} si no tocaba.
	func reiniciar(p_mundo: Node3D, p_jugador: Jugador3D, p_lanz: Lanzador3D) -> Dictionary:
		if completo or not empezado or recetas.is_empty():
			return {}
		var cambios: Dictionary = {}
		for e in vistos:
			if is_instance_valid(e) and not originales.has(e):
				(e as Combate3D).retirar()
		var nuevos: Array = []
		for i in range(recetas.size()):
			var viejo: Variant = originales[i]
			if is_instance_valid(viejo):
				(viejo as Combate3D).retirar()
			var nuevo: Combate3D = Combate3D.recrear(recetas[i] as Dictionary, p_mundo, p_jugador, p_lanz)
			if nuevo != null:
				nuevos.append(nuevo)
				cambios[viejo] = nuevo
		vistos.clear()
		recetas.clear()
		originales.clear()
		empezado = false
		reinicios += 1
		_t = 0.0                                     # que el siguiente fotograma los vuelva a ver (y a guardar su receta)
		PlayLog.event("encuentro_reiniciado", {"vigia": String(name), "repuestos": nuevos.size()})
		return cambios

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
		if not empezado:
			for e in vistos:
				if not is_instance_valid(e) or bool((e as Combate3D).muerto) or (e as Combate3D).health < (e as Combate3D).vida_max - 0.01 or (e as Combate3D).objetivo != null:
					empezado = true
					break
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
					if not empezado and not bool((n as Combate3D).muerto):
						var rc: Dictionary = (n as Combate3D).receta()      # G1: los que ya estaban antes de la pelea son los que se reponen al reintentar
						if not rc.is_empty():
							recetas.append(rc)
							originales.append(n)
					if puesto and (n as Combate3D).arquero:
						(n as Combate3D).fijo = true
					if debil != "" or resiste != "":
						(n as Combate3D).fijar_debilidad(debil if debil != "" else (n as Combate3D).debil, resiste if resiste != "" else (n as Combate3D).resiste)


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

	## G1 (22/11): la jugadora reapareció fuera. Si la sala no está vencida y estaba cerrada, se abre (y se volverá a cerrar al entrar). Devuelve si la abrió.
	func reiniciar() -> bool:
		if vencido or not cerrado:
			return false
		cerrado = false                              # sin `_poner`: no es un logro, no debe sonar a «puerta abierta»
		for pu in _puertas:
			(pu as PuertaPuzle).poner(true)
		cambio.emit(false)
		_t = 0.5                                     # margen: el modelo de la jugadora puede seguir un fotograma donde murió (dentro de la sala) y la puerta se volvía a cerrar
		return true

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
	var da: Array = []                           ## da= ([{que, n}] o {tabla}): el botín que da al abrirse
	var gasta: bool = false                      ## gasta=si: al abrirse quita 1 de cada objeto `tener.` de su `abre_si` (la llave de la bolsa)
	var gastado: Array = []                      ## lo que gastó de verdad (las pruebas)
	var _gastado_ya: bool = false
	var _contenido_preparado: Array = []
	var _contenido_listo: bool = false
	var botin_dado: Array = []                   ## lo que dio de verdad al abrirse (las pruebas)
	var glifo: String = ""                       ## glifo= (id del libro): abrirlo da ese glifo con la secuencia del cofre legendario (SecuenciaCofreLegendario3D)
	var secuencia: SecuenciaCofreLegendario3D = null
	var sello: String = ""                       ## sello= (22/11): abrirlo da ese elemento (flag `global.sello.<id>`, la misma que rearma `EncargoMarimanta.rearmar_sellos`)
	var reto: String = ""                        ## reto= (23/11, H6): la flag que resuelve la sala con el glifo que da este cofre; la pista de uso (`PistaGlifo`) se va al ponerse. Sin ella, al primer lanzamiento con el glifo
	var reto_en: Variant = null                  ## reto_en=x,z (23/11, H6): la casilla donde el suelo enseña el marcador suave de la runa (desde dónde usarla)
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
		add_to_group("e_cofre")                # CargarObjeto3D: E abre el cofre antes que coger un jarrón
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
			if sello != "":
				Repertoire.unlock_element(sello)     # y el sello, igual
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

	func _columna_actualizar_ceremonia() -> void:
		if columna != null:
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
		if (glifo != "" or calidad in ["epico", "legendario"]) and ctrl != null:
			# El cofre que da un glifo: lo abre la secuencia (cámara, luz, tapa, glifo, libro). Ella llama a `Cofre3D.abrir` a su hora.
			if StringName(ctrl.call("estado_nombre")) != &"cerrado":
				return false
			_abriendo = true
			secuencia = SecuenciaCofreLegendario3D.new()
			secuencia.name = "Secuencia"
			_preparar_contenido()
			if not _contenido_preparado.is_empty():
				secuencia.objeto_presentado = str(_contenido_preparado[0].get("que", "oro"))
			secuencia.calidad = calidad if calidad != "" else "legendario"
			secuencia.reto = reto
			secuencia.reto_en = reto_en
			secuencia.recompensa_lista.connect(_al_abrirse, CONNECT_ONE_SHOT)
			add_child(secuencia)
			if not secuencia.iniciar(self, ctrl, mundo, glifo):
				_abriendo = false
				secuencia.queue_free()
				secuencia = null
				return false
			_gastar()
			_columna_actualizar_ceremonia()
			return true
		if ctrl == null:
			_gastar()
			_al_abrirse()
			return true
		if not bool(ctrl.call("abrir")):
			return false                          # aún apareciendo: el jugador volverá a pulsar
		_abriendo = true
		ctrl.connect("abierto", _al_abrirse, CONNECT_ONE_SHOT)
		_gastar()
		return true

	## `gasta=si`: quita de la bolsa 1 de cada objeto `tener.<objeto>` del grupo de `abre_si` que se cumple (la llave). Una sola vez.
	func _gastar() -> void:
		if not gasta or _gastado_ya:
			return
		_gastado_ya = true
		for g in expr_abre:
			if puzle != null and not bool(puzle.call("cumple_expr", [g])):
				continue
			for t in (g as Array):
				if String((t as Dictionary)["tipo"]) == "tener" and not bool((t as Dictionary)["neg"]):
					var ob: String = String((t as Dictionary)["objeto"])
					if Estado.i().quitar(ob, 1):
						gastado.append(ob)
			return

	## ¿Se cumple `abre_si`? (vacío = sí).
	func sellado_cumplido() -> bool:
		return expr_abre.is_empty() or puzle == null or bool(puzle.call("cumple_expr", expr_abre))

	## `da=`: el botín del cofre, UNA vez, al acabar de abrirse (un cofre que nace ya abierto no vuelve a dar). Oro y lo que quepa en la mochila (lo que no cabe se queda y se avisa).
	## Devuelve lo que entró: [{que, n}].
	func _preparar_contenido() -> void:
		if _contenido_listo:
			return
		_contenido_listo = true
		for it0 in da:
			if (it0 as Dictionary).has("tabla"):
				_contenido_preparado.append_array(Botin.tirar(String(it0["tabla"])))
			else:
				_contenido_preparado.append(it0)

	func dar_botin() -> Array:
		var dado: Array = []
		var texto: PackedStringArray = []
		var sin_sitio: bool = false
		var color: Color = Color(1.0, 0.9, 0.6)
		var mejor: float = -1.0
		_preparar_contenido()
		var items: Array = _contenido_preparado
		for it in items:
			var que: String = String((it as Dictionary)["que"])
			var n: int = int((it as Dictionary)["n"])
			if que == "oro":
				Estado.i().dar_oro(n)
				Sfx.play_ui("moneda")                        # gamefeel U4
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
				lz.call("avisar", "Cofre abierto: %s%s" % [", ".join(texto) if not texto.is_empty() else "vacío", " (la mochila está llena: lo demás se queda aquí)" if sin_sitio else ""], color)
		return dado

	## `sello=`: apunta el sello como ganado (vale para los demás niveles) y lo desbloquea ya. Avisa solo si era nuevo.
	func _dar_sello() -> void:
		if sello == "":
			return
		Flags.i().poner(EncargoMarimanta.SELLO_GANADO + sello)
		if Repertoire.unlock_element(sello):
			var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
			if lz != null and lz.has_method("avisar"):
				lz.call("avisar", "Sello de %s conseguido: ya puedes dibujarlo." % sello, Color(1.0, 0.9, 0.6))
			LaminaGlifo.mostrar(self, sello, true, true)          # 23/11: la ficha del sello nuevo (pausa y se cierra con E/clic)

	func _al_abrirse() -> void:
		_abriendo = false
		es_cerrado = false
		es_abierto = true                         # antes de poner la flag: su aviso no debe tomarse por una carga de partida
		_columna_actualizar()                     # apaga la columna de luz
		if calidad != "" and Objetos.CALIDADES.has(calidad) and get_parent() is Node3D and is_inside_tree():
			VfxCalidad3D.motas(get_parent() as Node3D, global_position + Vector3(0.0, 1.0, 0.0), Objetos.CALIDADES[calidad]["color"], MOTAS_APERTURA, 1.4, 0.1, 2.0, 0.5)
		botin_dado = dar_botin()
		_dar_sello()
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
		if not k.pressed or k.echo or not k.is_action("interactuar"):
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
	EncargoMarimanta.rearmar_sellos()       # 13/11: los sellos ganados (la runa de agua del cofre de Marimanta) también se conservan entre niveles


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


## =====================================================================================================
##  G1 de PLAN_COMBATE (22/11): MORIR Y REINTENTAR. Regla de Pablo: lo permanente (cofres, misiones, atajos, puzles resueltos: flags) se queda; la vida y la fase de los enemigos
##  del encuentro se restauran; los ataques, avisos y efectos de paso se retiran; una recompensa única no se vuelve a dar.
## =====================================================================================================

static var REINTENTAR: bool = true               ## interruptor
var _jugador_reintentar: Jugador3D = null
var reintentos: int = 0                           ## veces que se ha reiniciado (pruebas)

## Se engancha a `Jugador3D.reaparecio` en cuanto hay jugadora (la maqueta la monta antes o después que este nodo, según el nivel).
func _vigilar_reaparecer() -> void:
	if _jugador_reintentar != null and is_instance_valid(_jugador_reintentar):
		return
	var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	var j: Variant = lz.get("jugador") if lz != null else null
	if j is Jugador3D:
		_jugador_reintentar = j as Jugador3D
		if not _jugador_reintentar.reaparecio.is_connected(al_reaparecer):
			_jugador_reintentar.reaparecio.connect(al_reaparecer)


## Lo que pasa al reaparecer (público: las pruebas lo pueden llamar).
func al_reaparecer() -> void:
	if not REINTENTAR or not is_inside_tree():
		return
	reintentos += 1
	CoordinadorEncuentro.reiniciar()                 # G2: nadie conserva su ficha de ataque
	var lz: Lanzador3D = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D
	var j: Jugador3D = lz.jugador as Jugador3D if lz != null else null
	var m3: Node3D = mundo as Node3D
	# 1) Lo de paso: avisos en el suelo, flechas y bolas de veneno en vuelo.
	for a in get_tree().get_nodes_in_group(AvisoAtaque3D.GRUPO):
		(a as AvisoAtaque3D).cancelar()
	if m3 != null:
		for n in m3.get_children():
			if n.has_meta("flecha_goblin") or n is FlechaTrampa3D or n is BolaVeneno3D:
				n.queue_free()
	# 2) Los encuentros (vigías) empezados y sin resolver: sus enemigos vuelven como al empezar. Y las puertas de sus salas se abren.
	var en_encuentro: Array = []
	for pz in _orden:
		var p: Pieza = pz as Pieza
		if p.tipo == "vigia" and p.nodo is VigiaPuzle:
			var cambios: Dictionary = (p.nodo as VigiaPuzle).reiniciar(m3, j, lz)
			for viejo in cambios:
				_cambiar_nodo(viejo, cambios[viejo])
			en_encuentro.append_array((p.nodo as VigiaPuzle).vistos)
		elif p.tipo == "cerrojo" and p.nodo is CerrojoPuzle:
			(p.nodo as CerrojoPuzle).reiniciar()
		elif (p.tipo == "dragon_jefe" or p.tipo == "verraco") and p.nodo != null and is_instance_valid(p.nodo) and p.nodo.has_method("reiniciar"):
			p.nodo.call("reiniciar")
	# 3) Los enemigos sueltos que siguen vivos: dejan de perseguirla y se curan.
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n is Combate3D and not en_encuentro.has(n):
			(n as Combate3D).olvidar_pelea()
	PlayLog.event("reintentar", {"n": reintentos})


## G1: una pieza cuyo nodo era `viejo` pasa a ser `nuevo` (el enemigo repuesto), para que las reglas y las pruebas sigan encontrándolo por su id.
func _cambiar_nodo(viejo: Variant, nuevo: Node) -> void:
	for pz in _orden:
		if (pz as Pieza).nodo == viejo:
			(pz as Pieza).nodo = nuevo


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


const RUTA_PIEZAS_ARTE: String = "res://arte/piezas/"

## ¿Existe la escena `arte/piezas/<id>.tscn`? (decorado con una pieza que no es de la lista cerrada de CLAVES).
static func _pieza_arte_existe(id: String) -> bool:
	return _id_valido(id) and ResourceLoader.exists(RUTA_PIEZAS_ARTE + id + ".tscn")


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
	var tipo: String = String(ALIAS_TIPO.get(p[2], p[2]))      # 18/11: `seta_veneno` es el `respiradero` (misma clase, mismas claves)
	if not _id_valido(id):
		_aviso_linea(avisos, n, l, "id no válido «%s» (letras, cifras y «_»)" % id)
		return null
	if por_id.has(id):
		_aviso_linea(avisos, n, l, "id repetido «%s» (ya está en la línea %d)" % [id, (por_id[id] as Pieza).n])
		return null
	if id == ID_FLAG or id == ID_ZONA or id == TERMINO_TENER:
		_aviso_linea(avisos, n, l, "«%s» es una palabra reservada (las flags, la zona y la bolsa): ponle otro id a la pieza" % id)
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
	if bien and tipo == "bancal" and not pz.p.has("flag"):
		_aviso_linea(avisos, n, l, "el bancal necesita flag=<nivel.sala.hecho>")
		return null
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
	if tipo == "sello":
		if not GestureLibrary.ELEMENTS.has(t):
			return [false, null, "tiene que ser un sello (elemento) del libro (GestureLibrary.ELEMENTS: fuego, agua, tierra…)"]
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
			if kv.size() == 2 and kv[0] == "tabla":
				# F1: `tabla:<id>` = una tirada de `botin_tablas.tsv` al abrirse (varias se suman con «+»).
				if not Botin.existe(kv[1]):
					return [false, null, "la tabla «%s» no existe en nucleo/datos/botin_tablas.tsv" % kv[1]]
				lista.append({"tabla": kv[1]})
				continue
			if kv.size() != 2 or not kv[1].is_valid_int() or int(kv[1]) <= 0 or not (kv[0] == "oro" or Objetos.existe(kv[0])):
				return [false, null, "«%s» no es <objeto>:<n> (oro u objeto de Objetos.DATOS; n entero > 0) ni tabla:<id>, unidos con «+»" % trozo]
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
	if tipo == "par":
		# «2.0,1.5»: dos números separados por coma (el ciclo de la trampa dragón: encendida, apagada). Devuelve [float, float].
		var dos: PackedStringArray = t.split(",")
		if dos.size() != 2 or not dos[0].is_valid_float() or not dos[1].is_valid_float() or float(dos[0]) < 0.0 or float(dos[1]) < 0.0:
			return [false, null, "tiene que ser «<s>,<s>» (dos números ≥ 0 separados por coma, p. ej. 2.0,1.5)"]
		return [true, [float(dos[0]), float(dos[1])], ""]
	if tipo.begins_with("decorado:"):
		# 7/11: los modelos de siempre (lista cerrada) o el id de CUALQUIER pieza que exista en arte/piezas (p. ej. las prov_* del pack Fantasy Provencal). Un id inventado sigue avisando.
		var vale_d: PackedStringArray = tipo.substr(9).split("|")
		if not (t in vale_d) and not _pieza_arte_existe(t):
			return [false, null, "tiene que ser uno de: %s, o el id de una pieza de arte/piezas (p. ej. prov_barrel)" % ", ".join(vale_d)]
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
	if t.begins_with(TERMINO_TENER + "."):
		var ob: String = t.substr(TERMINO_TENER.length() + 1)
		if not Objetos.existe(ob):
			_aviso_linea(avisos, n, l, "si=%s: «%s» no es un objeto de Objetos.DATOS (se escribe tener.<objeto>, por ejemplo tener.llave)" % [t, ob])
			return {}
		return {"neg": false, "tipo": "tener", "objeto": ob}
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
	# zona.poner(<estado>[,<segundos>]) / zona.quitar(<estado>) (F4): el primer argumento es un nombre de estado, el segundo un número.
	if t.begins_with(ID_ZONA + "."):
		var accz: String = t.substr(ID_ZONA.length() + 1, (ip if ip >= 0 else t.length()) - ID_ZONA.length() - 1)
		if not (accz in ACCIONES_ZONA):
			_aviso_linea(avisos, n, l, "hace=%s: la zona sabe %s" % [t, ", ".join(ACCIONES_ZONA)])
			return {}
		if ip < 0 or not t.ends_with(")"):
			_aviso_linea(avisos, n, l, "hace=%s: se escribe zona.%s(<estado>%s)" % [t, accz, ",<segundos>" if accz == "poner" else ""])
			return {}
		var az: PackedStringArray = t.substr(ip + 1, t.length() - ip - 2).split(",")
		var estz: String = az[0].strip_edges()
		if BD.estado_mundo(estz).is_empty() or estz == "veneno":
			_aviso_linea(avisos, n, l, "hace=%s: «%s» no es un estado del mundo que se pueda poner (estados_mundo.tsv; el veneno es de las nubes)" % [t, estz])
			return {}
		if az.size() > (2 if accz == "poner" else 1) or (az.size() == 2 and not az[1].strip_edges().is_valid_float()):
			_aviso_linea(avisos, n, l, "hace=%s: argumentos no válidos (zona.poner(<estado>,<segundos>) o zona.quitar(<estado>))" % t)
			return {}
		return {"id": ID_ZONA, "accion": accz, "args": [float(az[1])] if az.size() == 2 else [], "estado": estz}
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
	if pz.tipo in TRAMPAS_PARED and not bool(pz.p.get("exenta", false)):
		# 5/11: la trampa de pared va METIDA en un muro (su x,y es una `#`) y da a la casilla de `mira`, que tiene que ser suelo.
		if letra != "#":
			_avisar_pieza(pz, "la casilla %s es «%s»: una trampa de pared va en una casilla de muro «#» (x y = el muro; `mira` = hacia dónde da)" % [c, letra])
			return false
		var d: Vector2i = TrampaPared3D.DIRS_CELDA.get(String(pz.p.get("mira", "s")), Vector2i(0, 1))
		var delante: String = Terreno3D.letra_de(c + d) if Terreno3D.en_mapa(c + d) else "#"
		if delante == "#" or delante == " ":
			_avisar_pieza(pz, "la trampa de %s da a un muro (la casilla %s es «%s»): `mira` tiene que apuntar a suelo" % [c, c + d, delante])
			return false
		return true
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
		"bancal":
			var material: String = Terreno3D.estados.material_de(pz.celda)
			if material not in ["tierra", "arena"]:
				_avisar_pieza(pz, "un bancal necesita tierra o arena, hay «%s»" % material)
				return
			var bancal := BancalPuzle.new()
			bancal.name = pz.id
			bancal.celda = pz.celda
			bancal.flag = String(pz.p["flag"])
			bancal.con_tocon = String(pz.p.get("modelo", "")) == "tocon"
			bancal.con_surco = String(pz.p.get("modelo", "")) == "surco"
			bancal.dir_txt = String(pz.p.get("dir", "s"))
			if bancal.con_tocon or bancal.con_surco:
				var fx_b: Variant = (mundo as Object).get("_fx") if mundo is Object else null
				bancal.fx = fx_b as Vfx3D
			cont.add_child(bancal)
			pz.nodo = bancal
		"pulsador":
			var b := Pulsador3D.new()
			b.name = pz.id
			b.modelo = String(pz.p.get("modelo", ""))
			b.peso_min = maxi(0, int(pz.p.get("peso", 0)))
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
			mo.hechizo = bool(pz.p.get("hechizo", true))
			mo.preparar(pz.celda, float(pz.p.get("umbral", 0.3)), bool(pz.p.get("vertical", true)))
			cont.add_child(mo)
			pz.nodo = mo
		"barril":
			var ba := Barril3D.new()
			ba.name = pz.id
			ba.preparar(pz.celda, String(pz.p.get("tam", "normal")) == "pequeno")
			cont.add_child(ba)
			pz.nodo = ba
		"seta":
			var se := Recolectable3D.new()
			se.name = pz.id
			se.madura = bool(pz.p.get("madura", false))
			se.preparar(pz.celda, String(pz.p.get("variante", "")), float(pz.p.get("rebrota", 0.0)), mundo as Node)
			cont.add_child(se)
			pz.nodo = se
		"alga", "basalto", "musgo", "helecho_cueva", "seta_palida", "flor", "raiz", "lavanda", "bayas", "helecho", "flor_silvestre":
			# Materiales de la Cueva (docs/MATERIALES_CUEVA.md): un Recolectable3D que solo existe mientras se cumple `coge_si`.
			# 11/11: y las plantas del bosque (REVISION_OBJETOS_SINTESIS §4): flor (de luna), raíz, lavanda, bayas, helecho y flor silvestre. Un elemento lanzado
			# antes transforma las que tienen tabla (flor y raíz: Objetos.PLANTAS), como la seta.
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
		"bloque":
			var bq := BloqueEmpujable3D.new()
			bq.name = pz.id
			bq.preparar(pz.celda, String(pz.p.get("material", "piedra")), mundo as Node)
			cont.add_child(bq)
			pz.nodo = bq
		"roca_empujable":
			var rq := BloqueEmpujable3D.new()
			rq.name = pz.id
			rq.preparar(pz.celda, "roca", mundo as Node, String(pz.p.get("tam", "mediana")), String(pz.p.get("variante", "")), int(pz.p.get("forma", -1)))
			cont.add_child(rq)
			pz.nodo = rq
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
			if pz.p.has("giro"):
				pu.rotation.y = deg_to_rad(float(pz.p["giro"]))        # 28/10: girarla a mano (una reja entre dos casillas libres)
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
				if String(pz.p.get("modelo", "")).begins_with("anfora_"):
					ro.modelo_forzado = String(pz.p.get("modelo", ""))       # 8/11: las anforas de la lamina Ancient Artifact (rompibles como el jarron)
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
		"trampa_dragon":
			var td := TrampaDragon3D.new()
			td.name = pz.id
			var ciclo_d: Array = pz.p.get("ciclo", [TrampaDragon3D.ENCENDIDA_DEFECTO, TrampaDragon3D.APAGADA_DEFECTO])
			td.preparar(pz.celda, String(pz.p.get("mira", "s")), String(pz.p.get("elemento", "fuego")), clampi(int(pz.p.get("alcance", TrampaDragon3D.ALCANCE_DEFECTO)), TrampaDragon3D.ALCANCE_MIN, TrampaDragon3D.ALCANCE_MAX), mundo as Node)
			td.preparar_ciclo(float(ciclo_d[0]), float(ciclo_d[1]), float(pz.p.get("desfase", 0.0)))
			td.apaga_con_agua = bool(pz.p.get("agua", true))
			td.cerca = float(pz.p.get("cerca", 0.0))
			cont.add_child(td)
			pz.nodo = td
		"trampa_flechas":
			var tf := TrampaFlechas3D.new()
			tf.name = pz.id
			tf.preparar(pz.celda, String(pz.p.get("mira", "s")), String(pz.p.get("elemento", "fuego")), clampi(int(pz.p.get("alcance", TrampaFlechas3D.ALCANCE_DEFECTO)), 1, 8), mundo as Node)
			tf.preparar_ciclo(float(pz.p.get("cada", TrampaFlechas3D.CADA_DEFECTO)), float(pz.p.get("desfase", 0.0)), float(pz.p.get("vel", TrampaFlechas3D.VEL_DEFECTO)))
			tf.apaga_con_agua = bool(pz.p.get("agua", true))
			tf.cerca = float(pz.p.get("cerca", 0.0))
			if bool(pz.p.get("exenta", false)):
				tf.como_exenta()                  # tótem: de pie en una casilla de suelo, no metido en un muro
			cont.add_child(tf)
			pz.nodo = tf
		"verraco":
			var vr := Verraco3D.new()
			vr.name = pz.id
			cont.add_child(vr)
			vr.preparar(pz.celda, String(pz.p.get("mira", "s")), float(pz.p.get("vida", Verraco3D.VIDA)), mundo as Node)
			pz.nodo = vr
		"dragon_jefe":
			var dj := DragonJefe3D.new()
			dj.name = pz.id
			dj.preparar_jefe(pz.celda, String(pz.p.get("mira", "s")), clampi(int(pz.p.get("alcance", DragonJefe3D.ALCANCE_DEFECTO)), 3, 8), float(pz.p.get("cerca", DragonJefe3D.CERCA_DEFECTO)),
				float(pz.p.get("vida", DragonJefe3D.VIDA)), String(pz.p.get("nombre", "")), String(pz.p.get("epiteto", "")), mundo as Node)
			cont.add_child(dj)
			pz.nodo = dj
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
			br.enciende_por_hierba = bool(pz.p.get("por_hierba", false))
			if br.enciende_por_hierba:
				br.add_to_group(Reactivo3D.GRUPO_ARDE)
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
			vg.puesto = bool(pz.p.get("puesto", false))
			vg.debil = String(pz.p.get("debil", ""))
			vg.resiste = String(pz.p.get("resiste", ""))
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
			cf.sello = String(pz.p.get("sello", ""))
			cf.gasta = bool(pz.p.get("gasta", false))
			cf.reto = String(pz.p.get("reto", ""))
			if pz.p.has("reto_en") and (pz.p["reto_en"] as Array).size() > 0:
				cf.reto_en = (pz.p["reto_en"] as Array)[0]
				if (pz.p["reto_en"] as Array).size() > 1:
					_avisar_pieza(pz, "reto_en=: solo vale UNA casilla (se usa la primera)")
			if cf.gasta and not pz.p.has("abre_si"):
				_avisar_pieza(pz, "«gasta=si» solo vale con «abre_si=tener.<objeto>» (no hay nada que gastar)")
			pz.nodo = cf
		"cristal":
			var cr := CristalPulso3D.new()
			cr.name = pz.id
			cr.nivel = nivel
			cr.preparar(pz.celda, float(pz.p.get("cada", CristalPulso3D.CADA_DEFECTO)), int(pz.p.get("alcance", Pulso3D.ALCANCE_DEFECTO)), mundo as Node)
			cont.add_child(cr)
			pz.nodo = cr
		"guardian":
			if not pz.p.has("en"):
				_avisar_pieza(pz, "el guardián necesita «en=<casillas>» (sus marcas: dónde levanta la barrera)")
				return
			var gu := GuardianBarrera3D.new()
			gu.name = pz.id
			gu.preparar(pz.celda, pz.p["en"], float(pz.p.get("cada", 0.0)), String(pz.p.get("elemento", "fuego")), float(pz.p.get("cerca", 0.0)), bool(pz.p.get("roto", false)), mundo as Node)
			cont.add_child(gu)
			pz.nodo = gu
		"limo":
			# E1 (28/10): el limo se cuelga del MUNDO (como los Combate3D de los goblins), no del decorado: su cuerpo es hermano suyo y se mueve por el nivel.
			var cel_l: Vector2i = pz.celda
			var li: Limo3D = Limo3D.crear(mundo as Node3D, Terreno3D.centro_de(cel_l, Terreno3D.y_pies(cel_l)), String(pz.p.get("elemento", "")), bool(pz.p.get("grande", false)))
			li.name = pz.id
			pz.nodo = li
			if String(pz.p.get("coraza", "")) != "":
				CorazaElemento3D.equipar(li, String(pz.p.get("coraza", "")))      # B1 (22/11): limo de fuego con costra de brasa (`coraza=brasa`)
		"goblin_coraza":
			# B1 de PLAN_COMBATE (22/11): un guerrero (el modelo del goblin con escudo, sin escudo) con una coraza de elemento sobre todo el cuerpo.
			var cel_k: Vector2i = pz.celda
			var lz_k: Lanzador3D = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D if is_inside_tree() else null
			var jug_k: Jugador3D = lz_k.jugador as Jugador3D if lz_k != null else null
			var gk: Combate3D = null
			if (mundo as Node3D).has_method("_personaje"):
				var mod_k: Pj3D = (mundo as Node3D).call("_personaje", ["goblin_warrior_chibi"], Terreno3D.centro_de(cel_k, Terreno3D.y_pies(cel_k)))
				if mod_k != null:
					var lista_k: Variant = (mundo as Node3D).get("_goblins")
					if lista_k is Array:
						(lista_k as Array).append(mod_k)
					gk = Combate3D.equipar(mod_k, mundo as Node3D, jug_k, lz_k)
			if gk == null:
				_avisar_pieza(pz, "el goblin con coraza no tiene modelo (goblin_warrior_chibi.glb)")
				return
			CorazaElemento3D.equipar(gk, String(pz.p.get("coraza", "barro")))
			gk.quieto = bool(pz.p.get("quieto", false))
			gk.name = pz.id
			pz.nodo = gk
		"goblin_escudo":
			# 21/11: guerrero + Escudo3D, colgado del MUNDO como el gólem (Puzle3D crea sus piezas después de que el Jugador3D equipe los goblins de letra).
			var cel_e: Vector2i = pz.celda
			# 22/11 (A1 de PLAN_COMBATE): sin jugador ni lanzador el goblin no veía a nadie (`Combate3D._ve` con jugador null) y nunca atacaba. Se buscan como el gólem (`Golem3D._buscar_jugador`).
			var lz_e: Lanzador3D = get_tree().get_first_node_in_group("spellcaster") as Lanzador3D if is_inside_tree() else null
			var jug_e: Jugador3D = lz_e.jugador as Jugador3D if lz_e != null else null
			var ge: Combate3D = Escudo3D.invocar_goblin_escudo(mundo as Node3D, Terreno3D.centro_de(cel_e, Terreno3D.y_pies(cel_e)), jug_e, lz_e)
			if ge == null:
				_avisar_pieza(pz, "el goblin con escudo no tiene modelo (goblin_warrior_chibi.glb)")
				return
			ge.quieto = bool(pz.p.get("quieto", false))
			ge.name = pz.id
			pz.nodo = ge
		"golem":
			# E3 (28/10): como el limo, el gólem se cuelga del MUNDO (su modelo Pj3D es hermano suyo). Si falta el modelo, avisa y no sale.
			var cel_g: Vector2i = pz.celda
			var go: Golem3D = Golem3D.invocar_golem(mundo as Node3D, Terreno3D.centro_de(cel_g, Terreno3D.y_pies(cel_g)))
			if go == null:
				_avisar_pieza(pz, "el gólem no tiene modelo (golem_piedra_rig.glb)")
				return
			go.quieto = bool(pz.p.get("quieto", false))
			go.name = pz.id
			pz.nodo = go
		"chaman":
			# E2 (28/10): el chamán goblin, colgado del MUNDO como el gólem. Escuda a los goblins que tenga cerca y tira bolas de veneno desde lejos.
			var cel_c: Vector2i = pz.celda
			var ch: Chaman3D = Chaman3D.invocar_chaman(mundo as Node3D, Terreno3D.centro_de(cel_c, Terreno3D.y_pies(cel_c)))
			if ch == null:
				_avisar_pieza(pz, "el chamán no tiene modelo (goblin_chaman_rig.glb)")
				return
			ch.quieto = bool(pz.p.get("quieto", false))
			ch.name = pz.id
			pz.nodo = ch
		"mamoa":
			# E4: el brocal del que vuelve el mouro. Sin su modelo avisa pero funciona igual (la lógica de tapada/abierta no depende del dibujo). Cuelga del decorado, como las demás piezas fijas.
			if not ResourceLoader.exists(Mamoa3D.BROCAL):
				_avisar_pieza(pz, "la mámoa no tiene modelo (brocal_pozo.glb)")
			var mm: Mamoa3D = Mamoa3D.crear(mundo as Node3D, pz.celda, bool(pz.p.get("agrietada", false)), bool(pz.p.get("tapada", false)), cont)
			mm.name = pz.id
			pz.nodo = mm
		"mouro":
			# E4: como el chamán, colgado del MUNDO. La mámoa se le asigna en `_enlazar` (ya están todas las piezas: puede estar declarada después).
			var cel_m: Vector2i = pz.celda
			var mo: MouroEspectro3D = MouroEspectro3D.crear(mundo as Node3D, Terreno3D.centro_de(cel_m, Terreno3D.y_pies(cel_m)))
			if mo == null:
				_avisar_pieza(pz, "el mouro no tiene modelo (fantasma_elfo_rig.glb)")
				return
			mo.quieto = bool(pz.p.get("quieto", false))
			mo.name = pz.id
			pz.nodo = mo
		"compana":
			# E5: la procesión (un nodo del MUNDO) con sus ánimas. Sale de la casilla de la pieza; el camino (si lo hay) se valida casilla a casilla y la pieza se antepone si no es su primera casilla.
			var camino_c: Array = []
			camino_c.append(pz.celda)
			for cc in (pz.p.get("camino", []) as Array):
				if cc != pz.celda:
					if not _casilla_valida(pz, cc as Vector2i):
						return
					camino_c.append(cc)
			var sc: SantaCompana3D = SantaCompana3D.crear(mundo as Node3D, camino_c if camino_c.size() > 1 else [], int(pz.p.get("animas", SantaCompana3D.N_ANIMAS_DEFECTO)), pz.celda)
			if sc == null:
				_avisar_pieza(pz, "la Santa Compaña no tiene modelo (santa_compana_rig.glb)")
				return
			sc.name = pz.id
			pz.nodo = sc
		"puente":
			# 28/10 (Gruta Batida): las losas rúnicas de PuenteReactivo3D sobre el agua de `celdas`, plegadas hasta `tender` (una regla o la cuerda que lo sostiene).
			# Cada losa que sube vuelve su casilla un puente «b» que se pisa.
			var celdas_p: Array = pz.p.get("celdas", [pz.celda])
			var centros_p: Array = []
			for c in celdas_p:
				centros_p.append(Terreno3D.centro_de(c as Vector2i, Terreno3D.alto_agua))
			var fx_p: Variant = (mundo as Object).get("_fx") if mundo is Object else null
			var al_lista: Callable = func(c: Vector2i) -> void:
				Terreno3D.poner_letra(c, "b")
				Terreno3D.liberar_celda(c)
			if String(pz.p.get("estilo", "losas")) in ["raices", "zarcillos"]:
				# 23/11: el puente de raíces / de zarcillos (misma interfaz que las losas). Crece desde la primera casilla de `celdas`.
				var pq := PuenteRaices3D.new()
				pq.name = pz.id
				pq.zarcillos = String(pz.p.get("estilo", "")) == "zarcillos"
				cont.add_child(pq)
				pq.preparar(celdas_p, centros_p, Terreno3D.alto_agua + 0.12, Terreno3D.alto_agua, fx_p as Vfx3D, Vfx3D.COLOR.get("naturaleza", Color(0.45, 0.8, 0.3)), String(pz.p.get("dir", "")))
				pq.losa_lista.connect(al_lista)
				if pq.zarcillos:
					# El ANCLAJE va en la casilla que sigue al último tramo (en su sentido). Solo decorado, y solo si es suelo andable: con pared (o agua, o fuera del mapa) no se pone y se avisa.
					var dd: Vector3 = pq.direccion_final()
					var c_fin: Vector2i = (celdas_p.back() as Vector2i) + Vector2i(int(roundf(dd.x)), int(roundf(dd.z)))
					var letra_fin: String = Terreno3D.letra_de(c_fin)
					if letra_fin in ["#", "~", ""] or Terreno3D.bloqueada(c_fin):
						_avisar_pieza(pz, "zarcillos: la casilla de llegada %s no es suelo libre («%s»): el puente queda sin anclaje" % [str(c_fin), letra_fin])
					else:
						pq.montar_anclaje(Terreno3D.centro_de(c_fin, Terreno3D.y_pies(c_fin)))
				pz.nodo = pq
			else:
				var pr := PuenteReactivo3D.new()
				pr.name = pz.id
				cont.add_child(pr)
				pr.preparar(celdas_p, centros_p, Terreno3D.alto_agua + 0.12, Terreno3D.alto_agua, fx_p as Vfx3D, Vfx3D.COLOR.get("fuego", Color(1.0, 0.6, 0.2)))
				pr.losa_lista.connect(al_lista)
				pz.nodo = pr
		"veta":
			var ve := VetaPulso3D.new()
			ve.name = pz.id
			# 27/10: un hueco que también está en `celdas` es veta normal y conduce sin bloque: el puzle del enlace queda resuelto solo.
			for c in pz.p.get("enlaces", []):
				if (pz.p.get("celdas", [pz.celda]) as Array).has(c):
					_avisar_pieza(pz, "la casilla %s está en «celdas» y en «enlaces»: conduciría sin bloque de tierra" % str(c))
			ve.preparar(pz.p.get("celdas", [pz.celda]), pz.p.get("enlaces", []), float(pz.p.get("aturde", 0.0)), bool(pz.p.get("mineral", false)), nivel)
			cont.add_child(ve)
			pz.nodo = ve
		"columna":
			var co := MuroAgrietado3D.new()
			co.name = pz.id
			co.como_columna(String(pz.p.get("cae", "s")))
			if pz.p.has("puente"):
				var lava_p: Lava3D = nodo(String(pz.p["puente"])) as Lava3D
				if lava_p == null:
					_avisar_pieza(pz, "la columna-puente necesita «puente=<id de una lava>» definida ANTES en el archivo (no hay lava «%s»)" % String(pz.p["puente"]))
					return
				co.como_puente(lava_p, float(pz.p.get("largo", 2.0)), String(pz.p.get("flag", "")))
			elif pz.p.has("flag"):
				co.flag = String(pz.p["flag"])
			co.preparar(pz.celda, int(pz.p.get("golpes", 2)), mundo as Node)
			cont.add_child(co)
			pz.nodo = co
		"estalagmita":
			var eg := EstalagmitaPulso3D.new()
			eg.name = pz.id
			eg.preparar(pz.celda, String(pz.p.get("cae", "")), String(pz.p.get("flag", "")), mundo as Node)
			cont.add_child(eg)
			pz.nodo = eg
		"geoda":
			var ge := GeodaPulso3D.new()
			ge.name = pz.id
			ge.preparar(pz.celda, String(pz.p.get("flag", "")), float(pz.p.get("escala", 1.0)), mundo as Node, float(pz.p.get("cerca", 0.0)))
			cont.add_child(ge)
			pz.nodo = ge
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
			var modelo_dec: String = String(pz.p["modelo"]) if pz.p.has("modelo") else ""
			var clasicos: PackedStringArray = String((CLAVES["decorado"] as Dictionary)["modelo"]).substr(9).split("|")
			var dec: Node3D = null
			if modelo_dec != "" and not (modelo_dec in clasicos) and _pieza_arte_existe(modelo_dec):
				# 7/11: una pieza de arte/piezas fuera de la lista cerrada (las prov_*): la ESCENA tal cual (ya a su medida y con su colision), no la copia normalizada de la maqueta.
				dec = _colocar_pieza_arte(modelo_dec, cont, pz.id, Terreno3D.centro_de(pz.celda, Terreno3D.y_pies(pz.celda) - 0.02),
					float(pz.p.get("giro", 0.0)), Vector3.ONE * float(pz.p.get("escala", 1.0)))
			else:
				dec = _colocar_pieza(modelo_dec, cont, pz.id,
					Terreno3D.centro_de(pz.celda, Terreno3D.y_pies(pz.celda) - 0.02), float(pz.p.get("giro", 0.0)), Vector3.ONE * float(pz.p.get("escala", 1.0)))
			if dec == null:
				_avisar_pieza(pz, "decorado necesita «modelo=<pieza>» y que la pieza exista")
				return
			pz.nodo = dec
		"colmena":
			var cm := Colmena3D.new()
			cm.name = pz.id
			cm.preparar(pz.celda, nivel)
			cont.add_child(cm)
			pz.nodo = cm
		"nube_veneno":
			# F4: una nube de veneno (vida en s, 0 = permanente; radio en casillas). Cuelga del contenedor de piezas y se registra sola en EstadoZona3D.
			var nb: NubeVeneno3D = NubeVeneno3D.crear(cont, Terreno3D.centro_de(pz.celda, Terreno3D.y_pies(pz.celda)), float(pz.p.get("vida", 6.0)), float(pz.p.get("radio", 1.0)))
			nb.name = pz.id
			pz.nodo = nb
		"respiradero":
			# 18/11: la seta venenosa (antes reja; alias `seta_veneno`) que exhala una nube de veneno cada `cada` s y la extiende en `crece` s (objetos/respiradero_3d.gd). Cuelga del contenedor de piezas; las nubes que suelta, también.
			var rp := Respiradero3D.new()
			rp.name = pz.id
			rp.preparar(pz.celda, float(pz.p.get("cada", Respiradero3D.CADA_DEFECTO)), float(pz.p.get("vida", Respiradero3D.VIDA_DEFECTO)), float(pz.p.get("radio", Respiradero3D.RADIO_DEFECTO)),
				String(pz.p.get("dir", "")), float(pz.p.get("desfase", 0.0)), mundo as Node)
			rp.apaga_con_agua = bool(pz.p.get("agua", true))
			rp.crece = maxf(float(pz.p.get("crece", Respiradero3D.CRECE_DEFECTO)), 0.0)
			rp.quema_s = maxf(float(pz.p.get("quema", Respiradero3D.QUEMA_DEFECTO)), 0.0)
			rp.arde_s = maxf(float(pz.p.get("arde", Respiradero3D.ARDE_DEFECTO)), 0.1)
			cont.add_child(rp)
			pz.nodo = rp
		"balsa":
			# 18/11: plataforma que flota cuando el agua de su casilla llega a `calado` y deriva por la `ruta` hasta el muelle (objetos/balsa_3d.gd). El cofre que lleva se le pone en `_enlazar`.
			var ba2 := Balsa3D.new()
			ba2.name = pz.id
			var ruta_b: Array = [pz.celda]
			ruta_b.append_array(pz.p.get("ruta", []))
			ba2.preparar(ruta_b, float(pz.p.get("calado", Balsa3D.CALADO_DEFECTO)), float(pz.p.get("vel", Balsa3D.VEL_DEFECTO)))
			cont.add_child(ba2)
			pz.nodo = ba2
		"nido":
			var nd2 := Nido3D.new()
			nd2.name = pz.id
			nd2.preparar(pz.celda)
			cont.add_child(nd2)
			pz.nodo = nd2
		"arbol":
			# F1: un árbol que se SACUDE con el golpe F (papel `sacudible` de Reactivo3D). Modelo de la maqueta (`_pieza`) o, sin él, un tronco y una copa de primitivas.
			var vis_a: Node3D = null
			var id_a: String = String(pz.p.get("modelo", "arbol_redondo"))
			if mundo is Object and (mundo as Object).has_method("_pieza"):
				vis_a = (mundo as Object).call("_pieza", id_a) as Node3D
			if vis_a == null:
				vis_a = _arbol_primitivo()
			var ar := Reactivo3D.new()
			ar.name = pz.id
			ar.add_child(vis_a)
			var fx_a: Variant = (mundo as Object).get("_fx") if mundo is Object else null
			ar.preparar("arbol", pz.celda, "", fx_a as Vfx3D, vis_a)
			ar.position = Terreno3D.centro_de(pz.celda, Terreno3D.y_pies(pz.celda))
			cont.add_child(ar)
			Terreno3D.bloquear_celda(pz.celda)
			pz.nodo = ar
		"pared_hueca":
			var ph := ParedHuecaPulso3D.new()
			ph.name = pz.id
			ph.preparar(pz.celda, String(pz.p.get("flag", "")), mundo as Node, String(pz.p.get("mira", "")))
			cont.add_child(ph)
			pz.nodo = ph


## Un árbol de primitivas (tronco y copa) para la pieza `arbol` cuando la maqueta no tiene modelo.
static func _arbol_primitivo() -> Node3D:
	var raiz := Node3D.new()
	var tronco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.18
	cil.bottom_radius = 0.26
	cil.height = 1.6
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.4, 0.28, 0.18)
	cil.material = mt
	tronco.mesh = cil
	tronco.position = Vector3(0.0, 0.8, 0.0)
	raiz.add_child(tronco)
	var copa := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.9
	es.height = 1.5
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.36, 0.62, 0.34)
	es.material = mc
	copa.mesh = es
	copa.position = Vector3(0.0, 2.1, 0.0)
	raiz.add_child(copa)
	return raiz


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
		"puente":
			# 23/11: `tendido_si` (p. ej. la flag del bancal) cumplida al montar: el puente nace ya tendido, sin animación. Va aquí porque la expresión puede mirar otras piezas.
			if pz.exprs.has("tendido_si") and cumple_expr(pz.exprs["tendido_si"]):
				pz.nodo.call("tender_ya")
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
		"mouro":
			if not pz.p.has("mamoa"):
				return
			var pm: Pieza = _piezas.get(pz.p["mamoa"], null)
			if pm == null or pm.tipo != "mamoa" or not is_instance_valid(pm.nodo):
				_avisar_pieza(pz, "mamoa=%s: no es una pieza mámoa que se haya montado" % pz.p["mamoa"])
			else:
				(pz.nodo as MouroEspectro3D).asignar_mamoa(pm.nodo as Mamoa3D)
		"balsa":
			if not pz.p.has("cofre"):
				return
			var pc2: Pieza = _piezas.get(pz.p["cofre"], null)
			if pc2 == null or pc2.tipo != "cofre" or not is_instance_valid(pc2.nodo):
				_avisar_pieza(pz, "cofre=%s: no es un cofre que se haya montado" % pz.p["cofre"])
			else:
				(pz.nodo as Balsa3D).llevar(pc2.nodo as Node3D)
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


## 7/11: instancia `arte/piezas/<id>.tscn` tal cual (su escala y su `cuerpo` ya vienen horneados) en `pos`. Si la maqueta tiene el circulo de transparencia (`transparencia_jugador`),
## sus materiales pasan por `Ocluso3D.convertir` como los del decorado en lotes (`PruebaTest2._plantilla`); las copias son propias de esta pieza.
func _colocar_pieza_arte(id: String, cont: Node, nombre: String, pos: Vector3, giro: float, escala: Vector3) -> Node3D:
	var ps: PackedScene = load(RUTA_PIEZAS_ARTE + id + ".tscn") as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = nombre
	n.position = pos
	n.rotation.y = deg_to_rad(giro)
	n.scale = escala
	cont.add_child(n)
	if mundo is Object and String((mundo as Object).get("estilo")) == "pantano":      # 8/11: el tinte de Paleta3D.PIEZAS (la copa del manglar) tambien en los decorados del pantano
		var tinte_p: Color = Paleta3D.tinte_de_pieza(id)
		if tinte_p != Color.WHITE:
			Paleta3D.tintar(n, tinte_p)
	if mundo is Object and bool((mundo as Object).get("transparencia_jugador")):
		for h in n.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = h as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_active_material(s)
				if m != null:
					mi.set_surface_override_material(s, Ocluso3D.convertir(m.duplicate() as Material))
	if bool(n.get_meta("bloquea", false)):
		_bloquear_huella(n)
	return n


## Las casillas que toca la colision de la pieza (la caja XZ de sus cascos convexos, con >= 0,3 u de solape en cada eje) quedan bloqueadas para quien camina: la solidez de los mapas de letras es por casillas
## (FuenteCasillas), no por la colision fisica, que solo ven los hechizos.
func _bloquear_huella(n: Node3D) -> void:
	var ini := Vector2(INF, INF)
	var fin := Vector2(-INF, -INF)
	for h in n.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = h as CollisionShape3D
		if cs.shape is ConvexPolygonShape3D:
			for p in (cs.shape as ConvexPolygonShape3D).points:
				var w: Vector3 = cs.global_transform * p
				ini = Vector2(minf(ini.x, w.x), minf(ini.y, w.z))
				fin = Vector2(maxf(fin.x, w.x), maxf(fin.y, w.z))
	if ini.x == INF:
		return
	var a: Vector2i = Terreno3D.celda_de(Vector3(ini.x, 0.0, ini.y))
	var b: Vector2i = Terreno3D.celda_de(Vector3(fin.x, 0.0, fin.y))
	var cas: float = Terreno3D.casilla
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var solape_x: float = minf(fin.x, float(cx + 1) * cas) - maxf(ini.x, float(cx) * cas)
			var solape_y: float = minf(fin.y, float(cy + 1) * cas) - maxf(ini.y, float(cy) * cas)
			if solape_x >= 0.3 and solape_y >= 0.3:
				Terreno3D.bloquear_celda(Vector2i(cx, cy), n)      # 12/11: la jugadora choca con los cascos de la pieza, no con la casilla entera
	return


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
uniform float vel_caida = 2.4;       // los valores de AguaRender3D (VEL_CAIDA, CAIDA_VETA2…), para que casen con la cortina
uniform float veta2_fuerza = 0.7;
uniform float veta2_vel = 1.5;
uniform float veta3_fuerza = 0.55;
uniform float veta3_vel = 0.8;
uniform float alfa_base = 0.34;
uniform float alfa_veta = 0.50;
uniform float y_labio = 0.0;         // y del mundo del labio y z (hacia el sur) donde empieza la cortina: la lámina sigue el dibujo de la cortina por detrás de ellos
uniform float z_labio = 0.0;
uniform float alto_delantal = 0.10;
uniform float delantal = 0.0;     // 1 = es el delantal vertical: se desvanece de arriba (UV.y 0) a abajo (UV.y 1)

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
	// 7.ª pasada (Pablo: «las vetas se cortan a media altura»): ESTA lámina es la MISMA agua que la cortina del renderizador (CODIGO_CORTINA de AguaRender3D), con su misma fórmula, sus mismos
	// ruidos, velocidades, colores y alfas. La cortina usa el eje horizontal `a` (x del mundo aquí: la cascada corre de norte a sur) y la y del mundo, que baja con el tiempo; aquí la y
	// equivalente es la del labio más lo que falta para llegar a él (z_labio − z): el agua que viene por la cornisa es la que luego cae, y el dibujo sigue sin saltos por el labio.
	float a = v_pos.x;
	float y = delantal > 0.5 ? v_pos.y : y_labio + (z_labio - v_pos.z);
	float v1 = smoothstep(0.58, 0.78, ruido(vec2(a * 7.0, y * 0.40 + TIME * vel_caida)));
	float v2 = smoothstep(0.62, 0.80, ruido(vec2(a * 12.0 + 3.7, y * 0.65 + TIME * vel_caida * veta2_vel))) * veta2_fuerza;
	float v3 = smoothstep(0.56, 0.80, ruido(vec2(a * 3.5 + 11.3, y * 0.28 + TIME * vel_caida * veta3_vel))) * veta3_fuerza;
	float vetas = clamp(max(v1, max(v2, v3)) * 0.75 + (v1 + v2 + v3) * 0.15, 0.0, 1.0);
	ALBEDO = mix(color_hondo, color_claro, clamp(vetas * 0.9 + 0.10, 0.0, 1.0));            // 0,10 = el `t * 0,10` de la cortina en lo más alto (t = 1; sin aclarado del labio en la Cueva)
	float alfa = clamp(alfa_base + vetas * alfa_veta, 0.0, 1.0);
	if (delantal > 0.5) {
		// El delantal se apaga hacia abajo (u de 0 a 1 en `alto_delantal` u bajo el labio) mientras la cortina aparece: a1 = 1 − (1−A)^(1−u); la cortina pone a2 = 1 − (1−A)^u y entre las dos suman A justo.
		float u = clamp((y_labio - v_pos.y) / alto_delantal, 0.0, 1.0);
		alfa = 1.0 - pow(1.0 - min(alfa, 0.98), max(1.0 - u, 0.0001));
	}
	ALPHA = alfa;
}
"""

## Opacidad de la cortina de la Cueva (la del renderizador, `CORTINA_ALFA_BASE` 0,34 y `CORTINA_ALFA_VETA` 0,50 en el Bosque) y de la lámina de la cornisa: bastante más opaca, para que a través
## del agua no se vea la junta entre la roca de la terraza y la pared del pozo. Máx. 1,0 en las vetas.
const ALTO_DELANTAL: float = 0.10        ## alto del delantal de la lámina bajo el labio = tramo en el que la cortina del renderizador aparece (se cruzan)
const ALFA_BASE_CUEVA: float = 0.62
const ALFA_VETA_CUEVA: float = 0.38

func _params_agua_cortina(m: ShaderMaterial, y_labio: float, z_labio: float) -> void:
	m.set_shader_parameter("alfa_base", ALFA_BASE_CUEVA)
	m.set_shader_parameter("alfa_veta", ALFA_VETA_CUEVA)
	m.set_shader_parameter("y_labio", y_labio)
	m.set_shader_parameter("z_labio", z_labio)

const PILAR_SOBRE_TERRAZA: float = 1.5      ## cuánto sobresale un pilar por encima del fondo del canal (u)
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
			n.call("ajustar_cortina", "alfa_base", ALFA_BASE_CUEVA)      # 7.ª: más opaca (se veía la junta entre la roca de la terraza y la pared del pozo a través del agua); la lámina de la cornisa usa la misma
			n.call("ajustar_cortina", "alfa_veta", ALFA_VETA_CUEVA)
			n.call("ajustar_cortina", "fundido_alto", ALTO_DELANTAL)
			n.call("ajustar_cortina", "fundido_y", y_tope + 0.03)   # 6.ª: y sin borde superior: la cortina aparece en el 6 % de arriba (≈ 0,12 u) mientras el delantal de la lámina se apaga: un cruce, no una suma
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
		var largo_film: float = (lip_z + 0.055) - esq.z           # hasta donde cuelga el delantal (lip_z + 0,055): sin hueco ni solape
		pl.size = Vector2(an, largo_film)
		film.mesh = pl
		film.position = Vector3(xc, y_tope + 0.03, esq.z + largo_film * 0.5)
		var m_film := ShaderMaterial.new()
		m_film.shader = sh_film
		for mm in [m_film]:
			_params_agua_cortina(mm as ShaderMaterial, y_tope + 0.03, lip_z + 0.055)
		film.material_override = m_film
		film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cont.add_child(film)
		# Un delantal vertical de la misma agua (0,16 u) que cae por el canto de la roca justo bajo el labio: tapa la grieta oscura del canto, que se veía como un hilo negro en la unión.
		var delantal := MeshInstance3D.new()
		delantal.name = "%s_delantal_%d" % [nombre, i_c]
		var qd := QuadMesh.new()
		qd.size = Vector2(an, ALTO_DELANTAL)
		delantal.mesh = qd
		delantal.position = Vector3(xc, y_tope + 0.03 - ALTO_DELANTAL * 0.5, lip_z + 0.055)
		var m_delantal := ShaderMaterial.new()
		m_delantal.shader = sh_film
		_params_agua_cortina(m_delantal, y_tope + 0.03, lip_z + 0.055)
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
	# 13/11: cerrar el grifo de una tinaja también corta su chorro visible (gotas, arroyo, sonido y charco): antes el agua del canal paraba pero la tinaja seguía vertiendo para siempre.
	if pz.tipo == "tinaja" and pz.nodo is Reactivo3D and is_instance_valid(pz.nodo):
		(pz.nodo as Reactivo3D).dejar_de_verter()


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
		"tener":
			v = Estado.i().cuenta(String(t["objeto"])) > 0
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
	if String(a["id"]) == ID_ZONA:
		var ez: EstadoZona3D = EstadoZona3D.actual
		if ez == null or not is_instance_valid(ez):
			push_warning("Puzle3D: zona.%s(%s) sin EstadoZona3D en el nivel" % [a["accion"], a["estado"]])
			return
		if String(a["accion"]) == "poner":
			ez.poner(String(a["estado"]), float((a["args"] as Array)[0]) if (a["args"] as Array).size() > 0 else 0.0)
		else:
			ez.quitar(String(a["estado"]))
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
		"tender":
			if nd != null:
				nd.call("tender")
		"tapar":
			if nd != null:
				nd.call("tapar_a_mano")
		"destapar":
			if nd != null:
				nd.call("destapar_a_mano")
		"levantar":
			if nd != null:
				nd.call("levantar")
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
				if pz.tipo in TRAMPAS_PARED or pz.tipo == "respiradero":
					nd.call("apagar", float(args[0]) if args.size() > 0 else 0.0)        # `apagar(s)`: s segundos; sin argumento, hasta `encender`
				else:
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
	_vigilar_reaparecer()
	# Hielos puestos por una regla: caducan como los del hechizo (con el reloj de este nodo: va con la simulación y con las pruebas sin ventana).
	for c in _hielos.keys():
		_hielos[c] = float(_hielos[c]) - delta
		if float(_hielos[c]) <= 0.0:
			_hielos.erase(c)
			if Terreno3D.agua_sim != null:
				Terreno3D.agua_sim.helar_casilla(c, false)
			Terreno3D.poner_helada(c, false)
