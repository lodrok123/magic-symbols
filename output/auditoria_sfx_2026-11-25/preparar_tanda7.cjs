const fs=require('fs'),path=require('path');
const casos=[
{id:37,n:'libro_abre',cat:'Sfx',titulo:'Apertura del libro y pantallas',cuando:'Se abre el grimorio, diario u otras pantallas que reutilizan la apertura de libro; también aparece en la ceremonia del cofre.',motivo:'Una toma de 1,01 s para una acción frecuente. El paso de páginas y el cierre ya están aceptados: conviene comprobar la coherencia entre los tres.',propuesta:'Conservarla si comunica apertura y encaja con el papel elegido; recortarla o bajar nivel si la transición se siente demasiado larga.',pregunta:'¿Parece que se abre un libro? ¿La duración y fuerza encajan con el paso de páginas aprobado?'},
{id:38,n:'bolsa',cat:'Sfx',titulo:'Abrir y cerrar el inventario',cuando:'Se abre la bolsa o la pantalla de síntesis. Algunos cierres reutilizan la señal con tono ×0,85.',motivo:'Una toma de 0,51 s que puede repetirse al consultar inventario. Revisar si comunica tela, bolsa o manejo de objetos sin sonar a una compra.',propuesta:'Conservarla si encaja con la bolsa; ajustar textura, nivel o duración según tu valoración.',pregunta:'¿Se reconoce como una bolsa o inventario? ¿Te resulta discreta al abrir y cerrar varias veces?'},
{id:39,n:'pocion',cat:'Sfx',titulo:'Beber una poción',cuando:'Mientras la jugadora bebe se reproduce un bucle, que termina al acabar o interrumpir la acción.',motivo:'El archivo dura 0,35 s y se repite. Escuchar una toma aislada no permite valorar su repetición: prueba también el botón de bucle.',propuesta:'Valorar textura y repetición; ajustar el enlace si cada vuelta se reconoce demasiado.',pregunta:'¿Comunica beber líquido? ¿El bucle resulta natural o se nota un patrón insistente?',bucle:true},
{id:40,n:'cofre_revelado',cat:'Sfx',titulo:'Recompensa al abrir un cofre',cuando:'Se lanza el logro de cofre abierto. Aunque el identificador dice revelado, esta entrada corresponde a la recompensa de apertura.',motivo:'Una señal de 2,00 s. Revisar si la celebración aporta satisfacción y deja espacio a objetos recogidos u otros efectos.',propuesta:'Conservarla si encaja con una recompensa; recortar cola o bajar nivel si domina la apertura.',pregunta:'¿Encaja como recompensa de cofre? ¿Sobra duración, brillo o intensidad?'},
{id:41,n:'puzle_resuelto',cat:'Sfx',titulo:'Confirmación de puzle resuelto',cuando:'Se completa un puzle y aparece su celebración visual.',motivo:'Una señal de 0,78 s. Debe entenderse como éxito y distinguirse de la recompensa del cofre y de los clics cotidianos.',propuesta:'Conservarla si comunica resolución con claridad; ajustar su carácter o intensidad si resulta demasiado pequeña o exagerada.',pregunta:'¿Te transmite que el puzle está resuelto? ¿Encaja con la importancia del logro?'},
{id:42,n:'muerte',cat:'Sfx',titulo:'Señal de la pantalla de muerte',cuando:'Aparece la pantalla de muerte de la jugadora. Es distinta del daño recibido y de las muertes de enemigos.',motivo:'Una señal de 2,19 s. Revisar si acompaña el cierre de la partida sin resultar estridente al repetirse tras varios intentos.',propuesta:'Conservarla si encaja con la pantalla; ajustar duración o nivel si añade demasiada carga a cada derrota.',pregunta:'¿Encaja con la muerte de la jugadora? ¿Cambiarías su fuerza, tono o duración?'}
];
let s=fs.readFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda6.cjs','utf8');
const ini=s.indexOf('const casos=['),fin=s.indexOf('].map(x=>',ini);
s=s.slice(0,ini)+'const casos='+JSON.stringify(casos,null,2)+s.slice(fin+1);
s=s.replaceAll('tanda6','tanda7').replaceAll('TANDA6','TANDA7').replaceAll('Sexta','Séptima');
s=s.replace("'no_puedes_ui','libro_cierra'","'no_puedes_ui','libro_cierra','libro_abre','bolsa','muerte'");
s=s.replace('No reproduce la escena ni la suma de capas,','Para libro y bolsa se toma como referencia el uso en interfaz, con el bus a −6 dB; otros usos pueden sonar a otro nivel. No reproduce la escena ni la suma de capas,');
fs.writeFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda7.cjs',s);
require('./generar_escucha_tanda7.cjs');
const h=fs.readFileSync('docs/ESCUCHA_SFX_TANDA7_2026-11-25.html','utf8');let n=0;
for(const m of h.matchAll(/src="([^"]+)"/g)){if(!fs.existsSync(path.resolve('docs',decodeURIComponent(m[1]))))throw Error(m[1]);n++;}
new Function(h.match(/<script>([\s\S]*?)<\/script>/)[1]);
const prev=[1,2,3,4,5,6].flatMap(i=>require('./tanda'+i+'.json'));
for(const c of casos)if(prev.some(p=>p.n===c.n&&(p.cat||p.entrada.catalogo)===c.cat))throw Error('Caso repetido');
if(!h.includes('tanda7')||!h.includes('Escuchar diez segundos en bucle'))throw Error('Falta clave o bucle');
console.log(n+' muestras presentes; seis casos nuevos; bucle y clave independiente; JavaScript válido.');
