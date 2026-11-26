const fs=require('fs'),path=require('path');
const nombres=['fuego','agua','hielo','rayo','viento','tierra'];
const detalles=[
 ['Fuego','Cuatro variantes de 0,85–1,39 s. Comparar el ataque, la textura de llama y la cola.','¿Identificas fuego? ¿Qué variantes conservarías y cuáles resultan demasiado explosivas o largas?'],
 ['Agua','Tres variantes de 0,87–1,21 s. Comparar si comunican agua o un impacto líquido con el tamaño adecuado.','¿Parece agua conjurada? ¿Cambiarías salpicadura, fuerza, duración o nivel?'],
 ['Hielo','Cuatro variantes de 1,03–1,33 s. Esta señal elemental es distinta de congelar el mundo y de la fractura de puzle ya aprobadas.','¿Encaja con magia de hielo? ¿Qué variantes conservarías y cómo las distinguirías de una rotura?'],
 ['Rayo','Cuatro variantes de 0,35–0,67 s. Revisar ataque y aspereza: una descarga breve debe reconocerse sin resultar molesta al repetir.','¿Se reconoce electricidad? ¿Qué variantes tienen la fuerza y el tono adecuados?'],
 ['Viento','Cuatro variantes de 0,41–1,05 s. Hay bastante diferencia de duración; valorar si todas sirven para el mismo gesto mágico.','¿Se entiende como viento? ¿Sobra golpe, soplido o cola en alguna variante?'],
 ['Tierra','Cuatro variantes de 0,89–1,53 s. Revisar material y duración: debe relacionarse con roca/tierra y con la piedra que ya has aprobado.','¿Suena a tierra o roca manifestándose? ¿Qué variantes conservarías y qué cambiarías de su textura?']
];
const casos=nombres.map((n,i)=>({id:43+i,n,cat:'Sfx',titulo:'Magia elemental: '+detalles[i][0],cuando:'Se utiliza la señal general de '+n+' cuando una fase del hechizo no dispone de un sonido específico; puede reutilizarse en otras acciones del elemento. Las cargas y los impactos específicos se revisan por separado.',motivo:detalles[i][1],propuesta:'Elegir una o varias variantes si encajan con el elemento; después ajustar duración o nivel según tu valoración.',pregunta:detalles[i][2]}));
let s=fs.readFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda7.cjs','utf8');
const ini=s.indexOf('const casos=['),fin=s.indexOf('].map(x=>',ini);
s=s.slice(0,ini)+'const casos='+JSON.stringify(casos,null,2)+s.slice(fin+1);
s=s.replaceAll('tanda7','tanda8').replaceAll('TANDA7_2026-11-25','TANDA8_2026-11-26').replaceAll('Séptima','Octava').replaceAll('25 noviembre 2026','26 noviembre 2026').replaceAll('25 NOVIEMBRE 2026','26 NOVIEMBRE 2026').replaceAll('magic-symbols-sfx-2026-11-25-tanda8','magic-symbols-sfx-2026-11-26-tanda8');
s=s.replace('Octava tanda: seis efectos todavía sin validar.','Octava tanda: las señales generales de seis elementos. Se presentan aisladas para elegir su timbre; la escritura de conjuración ya aprobada y los sonidos específicos de carga/disparo/impacto no se mezclan en esta escucha.');
s=s.replace('Las muestras permiten validar timbre y comparar variantes. Para cerrar el balance final se necesita escucharlas junto al resto de capas del combate.','Las muestras permiten elegir la voz de cada elemento. La escritura aprobada acompaña a la carga; si una fase tiene sonido específico, este tiene prioridad sobre la señal general que se escucha aquí. El balance conjunto con la escritura y el resto del combate requiere una escucha en escena.');
fs.writeFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda8.cjs',s);
require('./generar_escucha_tanda8.cjs');
const h=fs.readFileSync('docs/ESCUCHA_SFX_TANDA8_2026-11-26.html','utf8');let n=0;
for(const m of h.matchAll(/src="([^"]+)"/g)){if(!fs.existsSync(path.resolve('docs',decodeURIComponent(m[1]))))throw Error(m[1]);n++;}
new Function(h.match(/<script>([\s\S]*?)<\/script>/)[1]);
const prev=[1,2,3,4,5,6,7].flatMap(i=>require('./tanda'+i+'.json'));
for(const c of casos)if(prev.some(p=>p.n===c.n&&(p.cat||p.entrada.catalogo)===c.cat))throw Error('Caso repetido');
if(!h.includes('magic-symbols-sfx-2026-11-26-tanda8'))throw Error('Clave incorrecta');
console.log(n+' muestras presentes; seis casos nuevos; fecha y clave propias; JavaScript válido.');
