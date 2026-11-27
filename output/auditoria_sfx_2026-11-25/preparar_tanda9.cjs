const fs=require('fs'),path=require('path');
const elementos=['agua','hielo','rayo','viento','tierra'];
const preguntas=[
'¿Se entiende que estás reuniendo agua antes de soltarla? ¿Cambiarías textura, intensidad o duración?',
'¿Comunica formación de frío o hielo sin confundirse con la fractura del impacto?',
'¿Parece una acumulación eléctrica antes de descargar? ¿Resulta demasiado agresiva para mantener la preparación?',
'¿Comunica aire reuniéndose antes de salir? ¿La diferenciarías del golpe de viento A aprobado?',
'¿Parece que se reúne tierra o roca? ¿La distinguirías del impacto de tierra 1 aprobado?'
];
const casos=elementos.map((el,i)=>({id:49+i,n:el+'_carga',cat:'Sfx',titulo:'Carga del hechizo de '+el,cuando:'Comienza la fase de carga de un hechizo de '+el+'. Esta señal se acompaña de la escritura ya aprobada. Se presenta aislada para valorar el elemento.',motivo:'Revisamos la anticipación: debe preparar la salida y distinguirse del impacto. La entrada actual es de inicio de carga; esta escucha no demuestra que exista un bucle sostenido para este elemento.',propuesta:'Valorar si la muestra actual sirve para iniciar la carga; después preparar su continuidad en bucle si se mantiene el hechizo listo.',pregunta:preguntas[i]}));
let s=fs.readFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda8.cjs','utf8');
const ini=s.indexOf('const casos=['),fin=s.indexOf('].map(x=>',ini);
s=s.slice(0,ini)+'const casos='+JSON.stringify(casos,null,2)+s.slice(fin+1);
s=s.replaceAll('tanda8','tanda9').replaceAll('TANDA8','TANDA9').replaceAll('Octava','Novena');
s=s.replace('Novena tanda: las señales generales de seis elementos. Se presentan aisladas para elegir su timbre; la escritura de conjuración ya aprobada y los sonidos específicos de carga/disparo/impacto no se mezclan en esta escucha.','Novena tanda: cinco cargas elementales pendientes. Fuego ya tiene aprobados su carga de crepitar A y el bucle sostenido, así que no se vuelve a votar. Aquí se escucha el inicio de carga de agua, hielo, rayo, viento y tierra; la escritura no se mezcla en estas muestras.');
s=s.replace('Las muestras permiten elegir la voz de cada elemento. La escritura aprobada acompaña a la carga; si una fase tiene sonido específico, este tiene prioridad sobre la señal general que se escucha aquí. El balance conjunto con la escritura y el resto del combate requiere una escucha en escena.','Orden de trabajo: carga e inicio sostenido → salida → vuelo si procede → impacto → persistencia y final cuando correspondan. Las elecciones de impacto de la tanda anterior no validan estas cargas. Aprobar un inicio tampoco valida por sí solo su repetición: se preparará y probará el bucle sostenido de cada elemento por separado. La mezcla final con escritura requiere escucharlo en escena.');
s=s.replace('seis casos y barrido completo','cinco casos y barrido completo');
fs.writeFileSync('output/auditoria_sfx_2026-11-25/generar_escucha_tanda9.cjs',s);
require('./generar_escucha_tanda9.cjs');
const h=fs.readFileSync('docs/ESCUCHA_SFX_TANDA9_2026-11-26.html','utf8');let n=0;
for(const m of h.matchAll(/src="([^"]+)"/g)){if(!fs.existsSync(path.resolve('docs',decodeURIComponent(m[1]))))throw Error(m[1]);n++;}
new Function(h.match(/<script>([\s\S]*?)<\/script>/)[1]);
const prev=[1,2,3,4,5,6,7,8].flatMap(i=>require('./tanda'+i+'.json'));
for(const c of casos)if(prev.some(p=>p.n===c.n&&(p.cat||p.entrada.catalogo)===c.cat))throw Error('Caso repetido');
if(!h.includes('magic-symbols-sfx-2026-11-26-tanda9'))throw Error('Clave incorrecta');
console.log(n+' muestras presentes; cinco cargas nuevas; JavaScript válido.');
