#!/usr/bin/env python3
"""Reproducible original procedural SFX, mono 22.05 kHz PCM; no dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'

def render(name, duration, tones=(), noise=0, decay=7):
    rng = random.Random(name)
    samples = []
    low = 0.0
    for i in range(round(RATE * duration)):
        t = i / RATE
        low += .18 * (rng.uniform(-1, 1) - low)
        value = noise * low * math.exp(-decay*t)
        for freq, end, onset, amplitude in tones:
            if t < onset:
                continue
            u = t-onset
            phase = 2*math.pi*(freq*u + (end-freq)*u*u/(2*duration))
            value += amplitude*math.sin(phase)*min(1,u/.006)*math.exp(-decay*u)
        value *= min(1,t/.004)*min(1,(duration-t)/.025)
        samples.append(value)
    peak = max(abs(v) for v in samples) or 1
    gain = .55/peak
    with wave.open(str(OUT / (name+'.wav')), 'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',round(v*gain*32767)) for v in samples))


def render_move():
    """Light brushed swish: no pitched oscillator or percussive bass attack."""
    duration = .12
    rng = random.Random('move-swish')
    samples = []
    slow = fast = 0.0
    for i in range(round(RATE * duration)):
        source = rng.uniform(-1, 1)
        slow += .08 * (source - slow)
        fast += .55 * (source - fast)
        envelope = math.sin(math.pi * i / (round(RATE * duration) - 1)) ** 2
        samples.append((fast - slow) * envelope)
    gain = .23 / max(abs(v) for v in samples)
    with wave.open(str(OUT / 'move.wav'), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', round(v * gain * 32767)) for v in samples))


def render_pipe():
    """Air drawn into a hollow metal tube, with a short resonant tail."""
    duration = .32
    count = round(RATE * duration)
    rng = random.Random('pipe-metal-air')
    samples = []
    phase = low = fast = 0.0
    delay = round(.026 * RATE)
    for i in range(count):
        t = i / RATE
        phase += 2 * math.pi * (420 + 780 * math.exp(-t * 14)) / RATE
        source = rng.uniform(-1, 1)
        low += .07 * (source - low)
        fast += .4 * (source - fast)
        attack = 1 - math.exp(-t * 95)
        air = (fast - low) * attack * math.exp(-t * 13)
        ring = (math.sin(phase) + .22 * math.sin(phase * 2.73))
        ring *= .16 * attack * math.exp(-t * 16)
        value = air + ring
        if i >= delay:
            value += .24 * samples[i - delay]
        samples.append(value)
    peak = max(abs(v) for v in samples)
    with wave.open(str(OUT / 'pipe.wav'), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', round(
            v / peak * .4 * 32767 * min(1, (count - 1 - i) / (RATE * .03))
        )) for i, v in enumerate(samples)))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    render('select',.09,[(780,520,0,.5)],.12,35)
    render_move()
    render('match',.5,[(784,784,0,.5),(1175,1175,.045,.3),(1568,1568,.09,.15)],decay=11)
    render('unlock',.35,[(1500,1250,0,.3),(2250,2250,.04,.15),(900,900,.09,.3)],.15,18)
    render_pipe()
    render('teleport',.55,[(350,1600,0,.3),(525,2000,.04,.15)],.08,5)
    render('splash',.4,[(700,170,0,.2),(1000,300,.05,.1)],1,10)
    render('sizzle',.5,noise=1,decay=6)
    render('bomb',.6,[(85,32,0,.8),(140,50,0,.3)],1.4,9)
    render('complete',1.1,[(523,523,0,.3),(659,659,.12,.3),(784,784,.24,.3),(1047,1047,.4,.4)],decay=5)
    print('Generated 10 sounds:',sum(p.stat().st_size for p in OUT.glob('*.wav')),'bytes')

if __name__ == '__main__':
    main()
