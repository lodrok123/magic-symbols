"""Recortes aprobados por Pablo, tanda SFX 25/11/2026.
Lee WAV fuente decodificados en output/sfx_validacion_2026-11-25/.
Papel: exclusivamente segundos 50–55 de fs_paginas_bucle.mp3.
Escritura: fs_pluma_pergamino.mp3. Piedra: propuesta granular CC0 aprobada e integrada con nivel sutil.
Requiere numpy. Ejecutar después del extractor Godot de esa carpeta.
"""
from pathlib import Path
import json
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'output/sfx_validacion_2026-11-25'
SR=44100
rng=np.random.default_rng(251125)

def leer(nombre):
    with wave.open(str(QA/(nombre+'.wav'))) as w:
        return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768

def fundir(x,ms=8):
    x=x.copy();n=min(round(SR*ms/1000),len(x)//2)
    x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)
    return x

def guardar(ruta,x,rms=-25,limite=-3):
    x=x.copy();x-=np.mean(x)
    ganancia=min(10**(rms/20)/max(np.sqrt(np.mean(x*x)),1e-10),10**(limite/20)/max(np.max(abs(x)),1e-10))
    x*=ganancia
    with wave.open(str(ROOT/ruta),'wb') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed'))
        w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
    return {'archivo':ruta,'segundos':len(x)/SR,'ganancia_db':float(20*np.log10(ganancia)),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x))))}

def clips(x,dur,cantidad):
    n=round(dur*SR);hop=441
    inicios=list(range(0,len(x)-n,hop))
    inicios.sort(key=lambda i:float(np.mean(x[i:i+n]**2)),reverse=True)
    elegidos=[]
    for i in inicios:
        if all(abs(i-j)>n+SR*.12 for j in elegidos): elegidos.append(i)
        if len(elegidos)==cantidad:break
    assert len(elegidos)==cantidad
    return sorted(elegidos)

def main():
    informe=[];papel=leer('paginas_50_55')
    for k,i in enumerate(clips(papel,.38,3)):
        d=guardar(f'audio/fs_pagina_corta_{k}.wav',fundir(papel[i:i+round(.38*SR)]),-24)
        d['origen_s']=[50+i/SR,50+i/SR+.38];informe.append(d)
    # Cruce de 40 ms, sin añadir silencio al borde del tramo aprobado.
    n=round(.04*SR);loop=papel[n:].copy();t=np.linspace(0,1,n)
    loop[-n:]=papel[-n:]*(1-t)+papel[:n]*t
    informe.append(guardar('audio/fs_paginas_50_55_loop.wav',loop,-26))
    pluma=leer('pluma_fuente')
    for k,i in enumerate(clips(pluma,.65,3)):
        d=guardar(f'audio/fs_conjuro_escritura_{k}.wav',fundir(pluma[i:i+round(.65*SR)]),-25)
        d['origen_s']=[i/SR,i/SR+.65];informe.append(d)
    # Piedra aprobada por Pablo: mismo timbre de la propuesta; nivel sutil en catálogo.
    fuentes=[leer('grava_fuente'),leer('piedra_fuente')]
    fuentes=[v/max(np.sqrt(np.mean(v*v)),1e-9) for v in fuentes]
    n=6*SR;sal=np.zeros(n)
    for i in range(0,n,round(.023*SR)):
        fuente=fuentes[int(rng.integers(2))];largo=round(rng.uniform(.055,.12)*SR)
        inicio=int(rng.integers(0,len(fuente)-largo))
        grano=fuente[inicio:inicio+largo]*np.hanning(largo)*rng.uniform(.3,.8)
        posiciones=(i+np.arange(largo))%n;np.add.at(sal,posiciones,grano)
    f=np.fft.rfftfreq(n,1/SR);mascara=(1-np.exp(-(f/65)**4))*np.exp(-(f/4200)**4)
    sal=np.fft.irfft(np.fft.rfft(sal)*mascara,n)
    informe.append(guardar('output/sfx_validacion_2026-11-25/piedra_candidata.wav',sal,-23,-4))
    # Copia exacta de la propuesta validada: atenuar en el catálogo, no regenerar el timbre.
    (ROOT/'audio/arrastre_piedra_loop.wav').write_bytes((QA/'piedra_candidata.wav').read_bytes())
    (QA/'recortes.json').write_text(json.dumps(informe,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(informe,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
