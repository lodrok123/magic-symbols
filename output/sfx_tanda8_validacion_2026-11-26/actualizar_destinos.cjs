const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'../..');
const gen=path.join(__dirname,'generar_revision.cjs');let s=fs.readFileSync(gen,'utf8');
const rows=[
{id:43,titulo:'Fuego A: carga y fuego ardiendo en bucle',estado:'Aceptado · aplicado',nota:'A es para carga y fuego ardiendo, no para impacto. Carga breve: copia exacta del recorte elegido. Carga sostenida y arde_bucle: grabación completa de origen oga_fuego_crepita_loop.wav, preparada para bucle, sin la envolvente del recorte. El ambiente de fuego 3D ya utiliza esa misma fuente. Se conservan los niveles de cada uso.',nombre:'fuego_carga'},
{id:44,titulo:'Impacto de agua: variante 2',estado:'Mejorable · ajuste aplicado',nota:'Variante 2 a −19 dB, 12 dB más baja que la señal general. Solo impacto; la carga conserva su entrada propia.',nombre:'agua_impacto'},
{id:45,titulo:'Impacto de hielo: variante 3',estado:'Aceptado · aplicado',nota:'Variante 3 asignada a hielo_impacto. La elección no corresponde a carga ni a la señal general.',nombre:'hielo_impacto'},
{id:46,titulo:'Impacto de rayo: variante 1',estado:'Aceptado · aplicado',nota:'Variante 1 asignada a rayo_impacto. La elección no corresponde a carga ni a la señal general.',nombre:'rayo_impacto'},
{id:47,titulo:'Impacto de viento: A',estado:'Aceptado · aplicado',nota:'Copia exacta de la propuesta A, fuente Extreme Winds de 344 Audio/Sonniss. Asignada a viento_impacto, manteniendo −11 dB y variación de tono.',nombre:'viento_impacto'},
{id:48,titulo:'Impacto de tierra: variante 1',estado:'Aceptado · aplicado',nota:'Solo la variante 1 en tierra_impacto, manteniendo −8 dB y variación de tono.',nombre:'tierra_impacto'}
];
const ini=s.indexOf('const casos=['),fin=s.indexOf('];let total=0;',ini);if(ini<0||fin<0)throw Error('Casos no encontrados');
s=s.slice(0,ini)+'const casos='+JSON.stringify(rows,null,2)+s.slice(fin+1);
s=s.replace('Hielo y rayo fijados; agua y tierra destinados a impacto. Fuego y viento pendientes de nueva validación.','Fuego A para carga y bucles. Agua 2 sutil, hielo 3, rayo 1, viento A y tierra 1 para impacto.');
// La página muestra la selección aplicada de cada evento. Los bucles se verifican en la prueba de rutas.
fs.writeFileSync(gen,s);require('./generar_revision.cjs');
for(const [src,dest] of [['fuego_a.wav','fuego_carga_crepitar.wav'],['viento_a.wav','sn_viento_impacto_a.wav']])if(!fs.readFileSync(path.join(__dirname,src)).equals(fs.readFileSync(path.join(root,'audio',dest))))throw Error('Copia distinta');
fs.writeFileSync(path.join(__dirname,'destinos_aprobados.json'),JSON.stringify(rows,null,2));
console.log('Destinos actualizados y copias exactas comprobadas.');
