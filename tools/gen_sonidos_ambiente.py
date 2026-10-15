#!/usr/bin/env python3
"""Sonidos genéricos de ambiente y criaturas, sintetizados (sin muestras, sin licencias).

Genera en ./out/ (se puede cambiar con el primer argumento) los .wav y los .ogg de:
  fuego_loop, agua_loop, goblin_grito_0..2, gato_maullido_0..1,
  conversacion_murmullo_loop, conversacion_voz_0..2, paso_hierba_0..3, paso_roca_0..3
Requiere numpy, scipy y ffmpeg (con libvorbis). La semilla es fija: relanzar da lo mismo.
Los "_loop" tienen la costura ya cruzada (crossfade) para sonar en bucle sin clic.
Por qué sintetizados: no hay grabación de "goblin" libre de derechos en los packs de
Kenney, y así un cambio de carácter es tocar un número y relanzar (igual que gen_sfx.py).
"""
# Generador procedural de sonidos genéricos (sin muestras externas: sin problemas de licencia).
import numpy as np, subprocess, os, sys
from scipy.signal import butter, sosfilt, lfilter
SR=44100
rng=np.random.default_rng(20261014)
def bp(x,lo,hi,o=2): return sosfilt(butter(o,[lo,hi],'band',fs=SR,output='sos'),x)
def lp(x,f,o=2): return sosfilt(butter(o,f,'low',fs=SR,output='sos'),x)
def hp(x,f,o=2): return sosfilt(butter(o,f,'high',fs=SR,output='sos'),x)
def noise(n): return rng.standard_normal(n)
def brown(n):
    x=np.cumsum(noise(n)); x-=np.linspace(x[0],x[-1],n); return x/np.max(np.abs(x))
def norm(x,peak=0.8): return x/np.max(np.abs(x))*peak
def loop(x,fade):
    # bucle sin costura: mezcla el final con el principio (crossfade igual-potencia)
    n=len(x)-fade; t=np.linspace(0,1,fade)
    a=np.cos(t*np.pi/2); b=np.sin(t*np.pi/2)
    y=x[:n].copy(); y[:fade]=x[:fade]*b+x[n:]*a
    return y
def pops(n,rate,fmin,fmax,decay,amp):
    # chasquidos: ráfagas de ruido filtrado con caída exponencial
    out=np.zeros(n)
    for _ in range(int(rate*n/SR)):
        p=rng.integers(0,n-2000); L=int(decay*SR*rng.uniform(.5,1.6))
        t=np.arange(L)/SR; env=np.exp(-t/(decay*rng.uniform(.3,.7)))
        f=rng.uniform(fmin,fmax); c=bp(noise(L),f*.7,min(f*1.6,SR/2-100),2)
        out[p:p+L]+=c*env*amp*rng.uniform(.2,1)**2
    return out
def formant(src,fs,bws,gains):
    y=0
    for f,bw,g in zip(fs,bws,gains): y=y+g*bp(src,max(f-bw/2,50),min(f+bw/2,SR/2-200),2)
    return y
def morph(src,anclas,bws,gains):
    n=len(src); K=len(anclas); u=np.linspace(0,1,n); out=np.zeros(n)
    for k,fs in enumerate(anclas):
        w=np.clip(1-np.abs(u*(K-1)-k),0,1)
        out+=w*formant(src,fs,bws,gains)
    return out
def glottal(f0,jit=0.0,rough=0.0):
    # fuente glotal: diente de sierra por acumulación de fase (f0 es una curva por muestra)
    f0=f0*(1+jit*lp(noise(len(f0)),30,1)*3)
    ph=np.cumsum(f0)/SR
    s=2*(ph%1)-1
    s=s+rough*noise(len(f0))*0.6
    return s
def wav(name,x):
    x=np.clip(x,-1,1); i=(x*32767).astype(np.int16)
    import wave
    with wave.open(name+'.wav','wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(i.tobytes())

# ---------- FUEGO (bucle 6 s) ----------
def fuego():
    n=int((6+0.5)*SR)
    base=lp(brown(n),180,2)*1.0                         # rugido grave de la llama
    sopl=bp(noise(n),300,1800,2)*(0.25+0.2*lp(noise(n),3,1)*8)  # soplo medio que respira
    crep=pops(n,34,800,4500,0.012,1.2)                  # crepitar
    chis=pops(n,5,2500,7000,0.006,0.9)                  # chispas agudas
    flick=1+0.35*lp(noise(n),4,1)*6
    x=(norm(base)*0.7+norm(sopl)*0.35)*np.clip(flick,.3,1.7)+norm(crep)*0.8+norm(chis)*0.35
    return norm(loop(x,int(.5*SR)),0.7)

# ---------- AGUA (bucle 6 s) ----------
def agua():
    n=int(6.5*SR)
    corr=bp(noise(n),200,3500,2)*(0.7+0.3*lp(noise(n),2.5,1)*5)   # cuerpo de corriente
    brillo=hp(noise(n),3500,2)*0.15*(0.7+0.3*lp(noise(n),6,1)*5)
    burb=np.zeros(n)                                      # burbujas: senos con barrido ascendente
    for _ in range(int(55*6.5)):
        p=rng.integers(0,n-4000); L=int(rng.uniform(.015,.05)*SR); t=np.arange(L)/SR
        f0=rng.uniform(350,1400); f=f0*(1+rng.uniform(1.5,3)*t/ (L/SR))
        ph=2*np.pi*np.cumsum(f)/SR
        burb[p:p+L]+=np.sin(ph)*np.exp(-t/(L/SR*0.35))*rng.uniform(.1,.5)
    x=norm(corr)*0.8+norm(brillo)*0.25+norm(burb)*0.28
    return norm(loop(x,int(.5*SR)),0.65)

# ---------- GRITO DE GOBLIN ----------
def goblin(var):
    d=[0.55,0.7,0.45][var]; n=int(d*SR); t=np.arange(n)/SR; u=t/d
    base=[330,280,400][var]
    # contorno: ataque rápido hacia arriba, mantenido con temblor, caída chillona
    f0=base*(0.8+0.7*np.clip(u/0.15,0,1)**.7)*(1-0.35*np.clip((u-0.6)/0.4,0,1)**1.5)
    f0=f0*(1+0.04*np.sin(2*np.pi*(9+var)*t))             # vibrato nervioso
    src=glottal(f0,jit=0.7,rough=0.5)
    # vocal que va de "i" a "a" a "e": formantes móviles (estrangulado/nasal = goblin)
    F=[(300,2300,3000),(700,1250,2600),(520,1900,2800)][var]
    anclas=[np.array([350,2400,3100])*(1-k/7)+np.array(F)*(k/7) for k in range(8)]
    out=morph(src,anclas,[120,200,300],[1.0,.7,.35])
    out=out+0.25*hp(noise(n),2500,2)*np.clip(1-u*1.3,0,1)  # aire áspero al principio
    env=np.clip(u/0.04,0,1)*np.clip((1-u)/0.35,0,1)**1.2
    out=np.tanh(out*2.2)*env                              # saturación = gruñido sucio
    return norm(out,0.8)

# ---------- MAULLIDO DE GATO ----------
def maullido(var):
    d=[0.95,0.75][var]; n=int(d*SR); t=np.arange(n)/SR; u=t/d
    # "mi-a-ou": tono sube de ~450 a ~850 Hz y baja a ~520 Hz
    f0=(450+420*np.sin(np.pi*np.clip(u*1.1,0,1))**1.2*(1 if var==0 else 1.2)) * (1-0.18*np.clip((u-.7)/.3,0,1))
    f0=f0*(1+0.012*np.sin(2*np.pi*6*t))
    src=glottal(f0,jit=0.15,rough=0.04)
    anclas=[[330+400*np.sin(np.pi*k/9),2400-1500*(k/9)**1.2,3300] for k in range(10)]
    out=morph(src,anclas,[150,260,400],[1.0,.6,.2])
    env=np.clip(u/0.12,0,1)**1.2*np.clip((1-u)/0.3,0,1)
    out=out*env
    return norm(out,0.7)

# ---------- CONVERSACIÓN ----------
def voz_silabas(dur,f0b,ritmo,vocales):
    n=int(dur*SR); t=np.arange(n)/SR
    f0=f0b*(1+0.12*lp(noise(n),3,1)*6)
    src=glottal(f0,jit=0.2,rough=0.1)
    out=np.zeros(n); pos=0
    while pos<n:
        L=int(rng.uniform(.10,.22)*SR/ritmo)
        if rng.random()<0.12: pos+=int(rng.uniform(.15,.4)*SR); continue   # pausas entre frases
        F=vocales[rng.integers(len(vocales))]; e=min(pos+L,n); seg=src[pos:e]
        y=formant(seg,F,[110,150,250],[1,.55,.25])
        m=len(seg); env=np.sin(np.pi*np.arange(m)/m)**1.5
        out[pos:e]+=y*env
        pos=e
    return out
VOC=[(700,1200,2600),(300,2300,3000),(450,1100,2500),(500,1800,2600),(350,800,2500)]
def murmullo():
    n=int(8.5*SR); x=np.zeros(n)
    for f0b,r in [(110,1.0),(130,1.2),(210,1.1),(185,.9)]:
        x+=norm(voz_silabas(8.5,f0b,r,VOC),.5)
    x=lp(x,3800,2)
    return norm(loop(x,int(.6*SR)),0.6)
def blip(var):
    # "habla" de personaje: 6-9 sílabas muy cortas con tono propio (estilo texto que se escribe)
    f0b=[160,230,120][var]; n=int(0.9*SR); x=np.zeros(n); pos=0
    for _ in range(rng.integers(6,9)):
        L=int(rng.uniform(.06,.09)*SR); t=np.arange(L)/SR
        f=f0b*rng.uniform(.85,1.35)*(1+0.1*t/ (L/SR))
        s=glottal(f,0.05,0.05); y=formant(s,VOC[rng.integers(5)],[110,150,250],[1,.5,.2])
        x[pos:pos+L]+=y*np.sin(np.pi*np.arange(L)/L)**.8; pos+=L+int(rng.uniform(.01,.04)*SR)
    return norm(x[:pos+int(.05*SR)],0.6)

# ---------- PASOS ----------
def paso_hierba(var):
    n=int(0.28*SR); t=np.arange(n)/SR
    # roce de briznas: ruido medio-agudo con ataque lento (~40 ms) y cola de hojas
    env=np.clip(t/0.04,0,1)**1.5*np.exp(-t/0.07)
    x=bp(noise(n),1500+300*var,7000,2)*env
    x+=0.5*bp(noise(n),300,1200,2)*np.exp(-t/0.05)*np.clip(t/0.01,0,1)   # peso del pie sobre la tierra
    x+=0.35*pops(n,60,3000,8000,0.004,1.0)*np.exp(-t/0.1)                 # briznas que crujen
    return norm(x,0.55)
def paso_roca(var):
    n=int(0.3*SR); t=np.arange(n)/SR
    # impacto seco: golpe breve grave + chasquido de grava + resonancia de piedra
    golpe=np.sin(2*np.pi*(110+12*var)*t*(1-0.3*t/0.3))*np.exp(-t/0.03)
    click=bp(noise(n),2000,9000,2)*np.exp(-t/0.006)
    res=bp(noise(n),900+150*var,1800+250*var,3)*np.exp(-t/0.04)
    grava=pops(n,25,1500,6500,0.005,1.0)*np.exp(-t/0.12)
    x=norm(golpe)*0.8+norm(click)*0.5+norm(res)*0.55+norm(grava)*0.25
    return norm(x,0.7)

OUT={}
OUT['fuego_loop']=fuego(); OUT['agua_loop']=agua()
for i in range(3): OUT[f'goblin_grito_{i}']=goblin(i)
for i in range(2): OUT[f'gato_maullido_{i}']=maullido(i)
OUT['conversacion_murmullo_loop']=murmullo()
for i in range(3): OUT[f'conversacion_voz_{i}']=blip(i)
for i in range(4): OUT[f'paso_hierba_{i}']=paso_hierba(i)
for i in range(4): OUT[f'paso_roca_{i}']=paso_roca(i)
os.makedirs(sys.argv[1] if len(sys.argv)>1 else 'out',exist_ok=True); os.chdir(sys.argv[1] if len(sys.argv)>1 else 'out')
for k,v in OUT.items():
    wav(k,v)
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',k+'.wav','-c:a','libvorbis','-q:a','4',k+'.ogg'],check=True)
    print(k, round(len(v)/SR,2),'s', 'pico',round(float(np.max(np.abs(v))),2),'rms',round(float(np.sqrt(np.mean(v**2))),3))
