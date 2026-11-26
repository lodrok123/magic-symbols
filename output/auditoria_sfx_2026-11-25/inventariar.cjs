const fs=require('fs'),path=require('path');
const root=process.cwd(), out=path.join(root,'output/auditoria_sfx_2026-11-25');
let entries=[];
for(const [file,section] of [['nucleo/sfx.gd','Sfx'],['nucleo/sfx_3d.gd','Sfx3D']]){
 const text=fs.readFileSync(file,'utf8');
 const cat=text.slice(text.indexOf('CATALOGO: Dictionary = {'),text.indexOf('\n}',text.indexOf('CATALOGO: Dictionary = {'))+2);
 for(const m of cat.matchAll(/"([\w]+)"\s*:\s*\{([^}]+)\}/g)){
  const cfg=JSON.parse('{'+m[2]+'}');let selected='f';
  if(cfg.f_lc && fs.existsSync('audio/'+cfg.f_lc[0]) && fs.existsSync('audio/'+cfg.f_lc[0]+'.import'))selected='f_lc';
  else if(cfg.f_sn && fs.existsSync('audio/'+cfg.f_sn[0]) && fs.existsSync('audio/'+cfg.f_sn[0]+'.import'))selected='f_sn';
  entries.push({catalogo:section,nombre:m[1],linea:text.slice(0,text.indexOf(m[0])).split('\n').length,cfg,selected,files:cfg[selected]});
 }
 if(section==='Sfx3D'){
  const amb=text.slice(text.indexOf('const AMBIENTES'),text.indexOf('\n}',text.indexOf('const AMBIENTES'))+2);
  for(const m of amb.matchAll(/"([\w]+)"\s*:\s*\{([^}]+)\}/g)){const cfg=JSON.parse('{'+m[2]+'}');entries.push({catalogo:'Ambiente3D',nombre:m[1],cfg,selected:'f',files:[cfg.f]});}
 }
}
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(d=>d.isDirectory()?(['.git','.godot','audio','output','arte','art'].includes(d.name)?[]:walk(path.join(dir,d.name))):d.name.endsWith('.gd')?[path.join(dir,d.name)]:[])}
const sources=['nucleo','magia','mundo','objetos','enemigos','jugador','presentacion','escenas'].flatMap(d=>walk(path.join(root,d))).filter(f=>!/[\\/](herramientas|laboratorios)[\\/]/.test(f)&& !/[\\/]nucleo[\\/](sfx|sfx_3d)\.gd$/.test(f)).map(f=>({file:path.relative(root,f).replaceAll('\\','/'),lines:fs.readFileSync(f,'utf8').split('\n')}));
for(const e of entries){e.references=[];for(const s of sources)s.lines.forEach((line,i)=>{if(line.trimStart().startsWith('#'))return;if(line.includes('"'+e.nombre+'"')||line.includes("'"+e.nombre+"'"))e.references.push(s.file+':'+(i+1)+': '+line.trim());});}
const files=fs.readdirSync('audio').filter(f=>/\.(wav|ogg|mp3)$/i.test(f));
fs.writeFileSync(out+'/catalogo.json',JSON.stringify(entries,null,2));fs.writeFileSync(out+'/archivos.json',JSON.stringify(files));
console.log(JSON.stringify({entries:entries.length,files:files.length,selected:entries.reduce((a,e)=>(a[e.selected]=(a[e.selected]||0)+1,a),{}),missing:entries.flatMap(e=>e.files.filter(f=>!fs.existsSync('audio/'+f)).map(f=>e.nombre+':'+f))},null,2));
