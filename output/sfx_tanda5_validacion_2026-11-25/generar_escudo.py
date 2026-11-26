from pathlib import Path
import json,wave
import numpy as np
q=Path('output/sfx_tanda5_validacion_2026-11-25');sr=44100

def leer(nombre):
 with wave.open(str(q/(nombre+'_fuente.wav'))) as w:x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
 indices=np.flatnonzero(abs(x)>max(abs(x))*.015)
 return x[max(0,int(indices[0])-88):int(indices[-1])+89] if len(indices) else x

def fade(x,entrada=.003,salida=.03):
 x=x.copy();a=min(round(sr*entrada),len(x)//2);b=min(round(sr*salida),len(x)//2)
 x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b);return x

def guardar(nombre,x,origen,rms=-23):
 x=x-np.mean(x);x=fade(x)
 x*=min(10**(rms/20)/max(np.sqrt(np.mean(x*x)),1e-9),10**(-4/20)/max(abs(x)))
 with wave.open(str(q/(nombre+'.wav')),'wb') as w:
  w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(x*32767).astype('<i2').tobytes())
 return {'archivo':nombre+'.wav','duracion_s':len(x)/sr,'origen':origen,'integrado':False}

media=leer('madera_media');fuerte=leer('madera_fuerte');corte=leer('corte_madera');crujido=leer('crujido')
info=[guardar('escudo_golpe_a',media,'Kenney Impact Sounds / impactWood_medium_000.ogg, CC0'),guardar('escudo_golpe_b',fuerte,'Kenney Impact Sounds / impactWood_heavy_000.ogg, CC0')]
rotura=np.zeros(round(.8*sr))
for fuente,inicio,ganancia in [(corte,0,.9),(crujido,.03,.45),(media,.13,.32),(fuerte,.25,.18)]:
 i=round(inicio*sr);n=min(len(fuente),len(rotura)-i);rotura[i:i+n]+=fuente[:n]*ganancia
info.append(guardar('escudo_rotura_a',rotura,'Composición de impactos/corte/crujido de madera Kenney, CC0'))
t=np.arange(round(.25*sr))/sr;rng=np.random.default_rng(25112526)
ruido=rng.normal(size=len(t));f=np.fft.rfftfreq(len(t),1/sr)
ruido=np.fft.irfft(np.fft.rfft(ruido)*np.exp(-(f/2400)**4)*(1-np.exp(-(f/120)**4)),len(t))
ruido*=(1-np.exp(-t/.003))*np.exp(-t/.045)
info.append(guardar('burbuja_rotura_b',ruido,'Síntesis propia: estallido de aire filtrado, sin resonancia de cristal',-26))
(q/'propuestas_escudo.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(info,ensure_ascii=False,indent=2))
