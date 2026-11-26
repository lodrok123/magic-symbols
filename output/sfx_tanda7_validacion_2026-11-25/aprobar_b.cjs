const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'../..'),src=path.join(__dirname,'muerte_b.wav'),dest=path.join(root,'audio/sn_muerte_sobria.wav');
fs.copyFileSync(src,dest);if(!fs.readFileSync(src).equals(fs.readFileSync(dest)))throw Error('Copia distinta');
const gen=path.join(__dirname,'generar_revision.cjs');let s=fs.readFileSync(gen,'utf8');
s=s.replace("estado:c.id===42?'A cambiar':'Aceptado'","estado:'Aceptado'");
s=s.replace('42 rechazado por carácter cómico: alternativas A/B/C pendientes de escuchar y fuera del juego.','42 aceptado: opción B integrada, sustituyendo la señal cómica anterior.');
s=s.replace('el nivel final se decidirá con la opción elegida','se conserva ese nivel con la opción B aprobada');
s=s.replace('42 · Pantalla de muerte: elige A, B o C','42 · Pantalla de muerte: B aceptada e integrada');
s=s.replace('sin modificar todavía el catálogo.','B integrada como sn_muerte_sobria.wav, copia exacta de la muestra elegida. A y C quedan solo como comparativa histórica.');
s=s.replace('42 pendiente.','42 aceptado: B.');
fs.writeFileSync(gen,s);require('./generar_revision.cjs');
const propuestas=JSON.parse(fs.readFileSync(path.join(__dirname,'propuestas_muerte.json'),'utf8'));for(const p of propuestas){p.integrado=p.variante==='B';if(p.integrado)p.destino='audio/sn_muerte_sobria.wav';}
fs.writeFileSync(path.join(__dirname,'propuestas_muerte.json'),JSON.stringify(propuestas,null,2));
fs.writeFileSync(path.join(__dirname,'aprobacion_42.json'),JSON.stringify({estado:'Aceptado',variante:'B',destino:dest,db:-8,tono:0,sha256:crypto.createHash('sha256').update(fs.readFileSync(dest)).digest('hex')},null,2));
console.log('B integrada, copia exacta comprobada.');
