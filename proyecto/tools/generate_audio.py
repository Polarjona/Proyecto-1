#!/usr/bin/env python3
"""Genera los archivos de audio del proyecto.

Todo el audio se sintetiza desde cero (sin samples de terceros), así que es
libre de derechos y se puede regenerar en cualquier momento:

    python3 tools/generate_audio.py

Salidas:
    audio/music/menu_theme.wav   (tema alegre de menú, bucle de ~38 s)
    audio/sfx/jump.wav
    audio/sfx/step.wav
    audio/sfx/checkpoint.wav
    audio/sfx/finish.wav
    audio/sfx/fall.wav
    audio/sfx/land.wav
    audio/sfx/impact.wav
    audio/sfx/coin.wav
    audio/sfx/ui.wav
    audio/sfx/countdown.wav
    audio/sfx/wind.wav           (bucle para el túnel de viento)
    audio/sfx/cannon.wav
    audio/sfx/creak.wav          (balancín)
    audio/sfx/boing.wav          (trampolín)
    audio/sfx/whoosh.wav         (martillos y barras)

La música se escribe directamente en WAV: no hace falta ffmpeg y el bucle
queda garantizado al marcar `loop_mode` en Godot.
"""

import math
import random
import sys
import wave
from array import array
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MUSIC_DIR = PROJECT_ROOT / "audio" / "music"
SFX_DIR = PROJECT_ROOT / "audio" / "sfx"

SR = 44100            # sample rate
BPM = 150             # music tempo
SPB = 60.0 / BPM      # seconds per beat
PHRASE_BARS = 24      # intro + A + B + A -> ~38 s loop

SEED = 20260924       # hace reproducible el ruido (batería, whoosh)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def _empty(n):
    """Array de n doubles a cero (compacto, sin numpy)."""
    return array("d", bytes(8 * n))


def _envelope(n, attack, release, decay=0.0):
    """Ganancia por muestra: rampa de ataque, decaimiento exponencial y release."""
    env = _empty(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    k = 1.0 / (decay * SR) if decay > 0.0 else 0.0
    for i in range(n):
        g = i / a if i < a else 1.0
        if k:
            g *= math.exp(-i * k)
        tail = n - i
        if tail < r:
            g *= tail / r
        env[i] = g
    return env


def render_note(kind, freq, dur, amp, duty=0.5, attack=0.005, release=0.03,
                decay=0.0, vib=0.0, vib_hz=5.0, detune=0.0, sweep=None):
    """Sintetiza una nota. kind: 'square' | 'triangle' | 'sine'.

    `sweep` es un callable u -> Hz (u = progreso normalizado 0..1) para glissandos.
    """
    n = max(1, int(dur * SR))
    out = _empty(n)
    env = _envelope(n, attack, release, decay)
    two_pi = 2.0 * math.pi
    ratio = freq / SR
    phase = 0.0
    for i in range(n):
        f = sweep(i / n) / SR if sweep is not None else ratio
        if vib:
            f *= 1.0 + vib * math.sin(two_pi * vib_hz * i / SR)
        phase += f
        p = phase % 1.0
        if kind == "square":
            s = 1.0 if p < duty else -1.0
            if detune:
                p2 = (phase + detune) % 1.0
                s = 0.5 * (s + (1.0 if p2 < duty else -1.0))
        elif kind == "triangle":
            s = 4.0 * abs(p - 0.5) - 1.0
        else:
            s = math.sin(two_pi * p)
        out[i] = s * env[i] * amp
    return out


def mix(buf, start, seg):
    """Suma `seg` dentro de `buf` a partir de la muestra `start` (recorta al final)."""
    start = int(start)
    if start >= len(buf):
        return
    n = min(len(seg), len(buf) - start)
    for i in range(n):
        buf[start + i] += seg[i]


def normalize(samples, peak=0.95):
    top = 0.0
    for v in samples:
        av = -v if v < 0.0 else v
        if av > top:
            top = av
    if top <= 0.0:
        return samples
    g = peak / top
    if abs(g - 1.0) < 1e-6:
        return samples
    for i in range(len(samples)):
        samples[i] *= g
    return samples


def fade_edges(samples, ms=2.0):
    """Microrrampas en los extremos para que el bucle no haga 'click'."""
    n = max(1, int(SR * ms / 1000.0))
    n = min(n, len(samples) // 2)
    for i in range(n):
        g = i / n
        samples[i] *= g
        samples[-1 - i] *= g


def write_wav(path, samples, peak=0.95):
    normalize(samples, peak)
    pcm = array("h", [0] * len(samples))
    for i, v in enumerate(samples):
        x = int(round(v * 32767.0))
        pcm[i] = -32768 if x < -32768 else (32767 if x > 32767 else x)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print("  %-42s %5.2f s" % (path.relative_to(PROJECT_ROOT), len(samples) / SR))


# --------------------------------------------------------------------------
# Notas y acordes
# --------------------------------------------------------------------------

_SEMITONES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
              "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(name):
    return (int(name[-1]) + 1) * 12 + _SEMITONES[name[:-1]]


def freq(name):
    return 440.0 * 2.0 ** ((midi(name) - 69) / 12.0)


def transpose(name, semis):
    m = midi(name) + semis
    return "%s%d" % (_NAMES[m % 12], m // 12 - 1)


# --------------------------------------------------------------------------
# Percusión
# --------------------------------------------------------------------------

def drum_kick():
    n = int(0.18 * SR)
    out = _empty(n)
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += (160.0 * math.exp(-4.0 * t) + 48.0) / SR
        body = math.sin(2.0 * math.pi * phase) * math.exp(-6.0 * t)
        click = math.exp(-70.0 * t) * 0.30 * random.uniform(-1.0, 1.0)
        out[i] = (body + click) * 0.95
    return out


def drum_snare():
    n = int(0.14 * SR)
    out = _empty(n)
    for i in range(n):
        t = i / n
        body = math.sin(2.0 * math.pi * 190.0 * i / SR) * math.exp(-22.0 * t) * 0.45
        noise = random.uniform(-1.0, 1.0) * math.exp(-13.0 * t) * 0.75
        out[i] = body + noise
    return out


def drum_hat(dur=0.045):
    n = int(dur * SR)
    out = _empty(n)
    prev = 0.0
    for i in range(n):
        t = i / n
        x = random.uniform(-1.0, 1.0)
        out[i] = (x - prev) * math.exp(-30.0 * t) * 0.5  # ruido agudo (high-pass crudo)
        prev = x
    return out


# --------------------------------------------------------------------------
# Efectos de sonido
# --------------------------------------------------------------------------

def sfx_jump():
    dur = 0.17

    def sweep(u):
        return 300.0 * math.exp(math.log(3.2) * u)  # 300 Hz -> ~960 Hz

    return render_note("square", 300.0, dur, 0.9, duty=0.35, attack=0.004,
                       release=0.035, decay=0.075, detune=0.35, sweep=sweep)


def sfx_checkpoint():
    dur = 0.75
    out = _empty(int(dur * SR))
    hits = [(0.0, "E5"), (0.07, "G5"), (0.14, "C6")]
    for start, name in hits:
        buf = _empty(int(0.55 * SR))
        f = freq(name)
        for i in range(len(buf)):
            t = i / SR
            mod = math.sin(2.0 * math.pi * f * 3.51 * t) * 2.2 * math.exp(-t * 9.0)
            att = min(1.0, t / 0.004)
            buf[i] = math.sin(2.0 * math.pi * f * t + mod) * math.exp(-t / 0.26) * att * 0.8
        mix(out, start * SR, buf)
    return out


def sfx_finish():
    dur = 1.6
    out = _empty(int(dur * SR))
    lead = 0.11
    for k, name in enumerate(["C5", "E5", "G5"]):
        mix(out, k * lead * SR,
            render_note("square", freq(name), lead * 0.95, 0.32, duty=0.3,
                        attack=0.004, release=0.02))
    tail = 1.0
    dur_chord = [("C6", 0.30), ("E6", 0.24), ("G6", 0.20), ("C3", 0.36)]
    for name, amp in dur_chord:
        mix(out, (3 * lead) * SR,
            render_note("triangle", freq(name), tail, amp, attack=0.01,
                        release=0.18, decay=0.55, vib=0.006))
    for name, amp in [("C5", 0.12), ("G5", 0.10)]:
        mix(out, (3 * lead + 0.02) * SR,
            render_note("square", freq(name), 0.35, amp, duty=0.35,
                        attack=0.004, release=0.1, decay=0.2))
    mix(out, (3 * lead) * SR, drum_kick())
    return out


def sfx_fall():
    dur = 0.8
    n = int(dur * SR)
    out = _empty(n)
    y = 0.0
    phase = 0.0
    for i in range(n):
        t = i / n
        fc = 6200.0 * math.exp(-3.0 * t) + 260.0
        alpha = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += alpha * (random.uniform(-1.0, 1.0) - y)
        phase += (660.0 * math.exp(-2.3 * t) + 70.0) / SR
        env = math.sin(math.pi * min(1.0, t * 1.18)) ** 0.7
        out[i] = (y * 1.6 + math.sin(2.0 * math.pi * phase) * 0.35) * env
    return out


def sfx_land():
    """Golpe sordo de aterrizaje."""
    dur = 0.2
    n = int(dur * SR)
    out = _empty(n)
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += (115.0 * math.exp(-3.2 * t) + 45.0) / SR
        body = math.sin(2.0 * math.pi * phase) * math.exp(-9.0 * t)
        noise = random.uniform(-1.0, 1.0) * math.exp(-26.0 * t) * 0.35
        out[i] = (body + noise) * 0.9
    return out


def sfx_impact():
    """Impacto seco con más cuerpo que el aterrizaje."""
    dur = 0.24
    n = int(dur * SR)
    out = _empty(n)
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += (90.0 * math.exp(-4.0 * t) + 38.0) / SR
        body = math.sin(2.0 * math.pi * phase) * math.exp(-8.0 * t)
        crack = random.uniform(-1.0, 1.0) * math.exp(-34.0 * t) * 0.55
        out[i] = (body + crack) * 1.0
    return out


def sfx_coin():
    dur = 0.45
    out = _empty(int(dur * SR))
    for k, name in enumerate(["E6", "B6"]):
        mix(out, k * 0.07 * SR,
            render_note("triangle", freq(name), 0.4, 0.5,
                        attack=0.004, release=0.12, decay=0.35))
    return out


def sfx_ui():
    return render_note("square", 760.0, 0.07, 0.5, duty=0.3,
                       attack=0.002, release=0.02, decay=0.12)


def sfx_countdown():
    return render_note("sine", 880.0, 0.16, 0.6,
                       attack=0.004, release=0.05, decay=0.18)


def sfx_step():
    """Pisada corta y seca; el pitch variable evita el efecto metralleta."""
    dur = 0.11
    n = int(dur * SR)
    out = _empty(n)
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += (150.0 * math.exp(-3.0 * t) + 62.0) / SR
        body = math.sin(2.0 * math.pi * phase) * math.exp(-16.0 * t) * 0.85
        click = random.uniform(-1.0, 1.0) * math.exp(-55.0 * t) * 0.45
        out[i] = body + click
    return out


def sfx_wind():
    """Ráfaga continua y bucle: ruido filtrado con dos LFO y un silbido."""
    dur = 3.0
    n = int(dur * SR)
    out = _empty(n)
    low = 0.0
    band = 0.0
    for i in range(n):
        t = i / n
        x = random.uniform(-1.0, 1.0)
        # Dos capas de ruido filtrado: cuerpo grave y siseo agudo.
        low += (x - low) * 0.012
        band += (x - band) * 0.10
        gust = 0.72 + 0.28 * math.sin(2.0 * math.pi * 2.0 * t)
        flutter = 0.85 + 0.15 * math.sin(2.0 * math.pi * 5.0 * t + 0.7)
        whistle_f = 520.0 + 70.0 * math.sin(2.0 * math.pi * 3.0 * t)
        whistle = math.sin(2.0 * math.pi * whistle_f * i / SR) * 0.10
        out[i] = (low * 2.3 + band * 0.55 + whistle) * gust * flutter * 0.85
    fade_edges(out, ms=25.0)
    return out


def sfx_cannon():
    """Cañonazo: golpe grave, soplo de pólvora y cola de retumbe."""
    dur = 0.85
    n = int(dur * SR)
    out = _empty(n)
    phase = 0.0
    low = 0.0
    for i in range(n):
        t = i / n
        phase += (120.0 * math.exp(-5.0 * t) + 32.0) / SR
        boom = math.sin(2.0 * math.pi * phase) * math.exp(-7.0 * t)
        x = random.uniform(-1.0, 1.0)
        low += (x - low) * 0.05
        blast = low * math.exp(-14.0 * t) * 2.1
        rumble = low * math.exp(-3.0 * t) * 0.35
        out[i] = boom * 1.1 + blast + rumble
    return out


def sfx_creak():
    """Crujido de madera del balancín al volcar."""
    dur = 0.55
    n = int(dur * SR)
    out = _empty(n)
    phase = 0.0
    low = 0.0
    for i in range(n):
        t = i / n
        f = 210.0 + 60.0 * math.sin(2.0 * math.pi * 3.2 * t) + 90.0 * t
        phase += f / SR
        p = phase % 1.0
        saw = 2.0 * p - 1.0
        x = random.uniform(-1.0, 1.0)
        low += (x - low) * 0.2
        env = math.sin(math.pi * min(1.0, t * 1.1)) ** 0.6
        out[i] = (saw * 0.32 + low * 0.5) * env
    return out


def sfx_boing():
    """Trampolín: subida de tono con rebote elástico."""
    dur = 0.55
    n = int(dur * SR)
    out = _empty(n)
    for i in range(n):
        t = i / n
        f = 240.0 + 520.0 * math.sin(math.pi * min(1.0, t * 1.7)) - 120.0 * t
        vibrato = 1.0 + 0.06 * math.sin(2.0 * math.pi * 18.0 * i / SR)
        env = math.exp(-5.0 * t) * min(1.0, t / 0.01)
        out[i] = math.sin(2.0 * math.pi * f * vibrato * i / SR) * env * 0.8
    return out


def sfx_whoosh():
    """Paso de un objeto grande: ruido con banda que sube y baja."""
    dur = 0.42
    n = int(dur * SR)
    out = _empty(n)
    low = 0.0
    band = 0.0
    for i in range(n):
        t = i / n
        x = random.uniform(-1.0, 1.0)
        low += (x - low) * (0.02 + 0.05 * math.sin(math.pi * t))
        band += (x - band) * (0.12 + 0.22 * math.sin(math.pi * t))
        env = math.sin(math.pi * t) ** 1.2
        out[i] = (low * 1.2 + band * 0.9) * env
    return out


# --------------------------------------------------------------------------
# Música
# --------------------------------------------------------------------------

# Progresión de 24 compases: intro, A (8), B (8) y vuelta a A (4 + vuelta).
CHORDS = [
    ("C", ["C5", "E5", "G5"]), ("G", ["G4", "B4", "D5"]),
    ("A", ["A4", "C5", "E5"]), ("F", ["F4", "A4", "C5"]),
    ("C", ["C5", "E5", "G5"]), ("G", ["G4", "B4", "D5"]),
    ("F", ["F4", "A4", "C5"]), ("G", ["G4", "B4", "D5"]),
    ("F", ["F4", "A4", "C5"]), ("G", ["G4", "B4", "D5"]),
    ("E", ["E4", "G4", "B4"]), ("A", ["A4", "C5", "E5"]),
    ("F", ["F4", "A4", "C5"]), ("G", ["G4", "B4", "D5"]),
    ("C", ["C5", "E5", "G5"]), ("C", ["C5", "E5", "G5"]),
    ("C", ["C5", "E5", "G5"]), ("G", ["G4", "B4", "D5"]),
    ("A", ["A4", "C5", "E5"]), ("F", ["F4", "A4", "C5"]),
    ("C", ["C5", "E5", "G5"]), ("G", ["G4", "B4", "D5"]),
    ("F", ["F4", "A4", "C5"]), ("G", ["G4", "B4", "D5"]),
]
BASS_ROOTS = ["C2", "G2", "A2", "F2", "C2", "G2", "F2", "G2",
              "F2", "G2", "E2", "A2", "F2", "G2", "C2", "C2",
              "C2", "G2", "A2", "F2", "C2", "G2", "F2", "G2"]

# Patrón funky de bajo en corcheas con contratiempos (beat, semitonos).
BASS_PATTERN = [(0.0, 0), (0.75, 0), (1.5, 7), (2.0, 0),
                (2.75, 12), (3.5, 7)]

# Melodías: por compás, lista de (beat, nota, duración en beats).
MELODY_A = [
    [(0.0, "G4", 0.5), (0.5, "C5", 0.5), (1.0, "E5", 0.5), (1.5, "G5", 0.5), (2.0, "E5", 0.5), (2.5, "C5", 0.5), (3.0, "D5", 0.5), (3.5, "E5", 0.5)],
    [(0.0, "D5", 1.0), (1.0, "B4", 0.5), (1.5, "D5", 0.5), (2.0, "G5", 1.0), (3.0, "F5", 0.5), (3.5, "D5", 0.5)],
    [(0.0, "C5", 0.5), (0.5, "E5", 0.5), (1.0, "A5", 1.0), (2.0, "G5", 0.5), (2.5, "E5", 0.5), (3.0, "C5", 0.5), (3.5, "A4", 0.5)],
    [(0.0, "F4", 0.5), (0.5, "A4", 0.5), (1.0, "C5", 0.5), (1.5, "F5", 0.5), (2.0, "A5", 1.0), (3.0, "G5", 0.5), (3.5, "F5", 0.5)],
    [(0.0, "E5", 0.5), (0.5, "G5", 0.5), (1.0, "C6", 1.0), (2.0, "B5", 0.5), (2.5, "G5", 0.5), (3.0, "E5", 1.0)],
    [(0.0, "D5", 0.5), (0.5, "G5", 0.5), (1.0, "B5", 1.0), (2.0, "A5", 0.5), (2.5, "G5", 0.5), (3.0, "D5", 1.0)],
    [(0.0, "C5", 0.5), (0.5, "F5", 0.5), (1.0, "A5", 1.0), (2.0, "G5", 0.5), (2.5, "F5", 0.5), (3.0, "E5", 0.5), (3.5, "D5", 0.5)],
    [(0.0, "B4", 0.5), (0.5, "D5", 0.5), (1.0, "G5", 1.5), (2.5, "F5", 0.5), (3.0, "D5", 0.5), (3.5, "B4", 0.5)],
]
MELODY_B = [
    [(0.0, "A5", 0.5), (0.5, "C6", 0.5), (1.0, "A5", 0.5), (1.5, "F5", 0.5), (2.0, "C5", 1.0), (3.0, "F5", 0.5), (3.5, "A5", 0.5)],
    [(0.0, "B5", 0.5), (0.5, "D6", 0.5), (1.0, "B5", 0.5), (1.5, "G5", 0.5), (2.0, "D5", 1.0), (3.0, "G5", 0.5), (3.5, "B5", 0.5)],
    [(0.0, "G5", 0.5), (0.5, "B5", 0.5), (1.0, "E6", 1.0), (2.0, "D6", 0.5), (2.5, "B5", 0.5), (3.0, "G5", 1.0)],
    [(0.0, "A4", 0.5), (0.5, "C5", 0.5), (1.0, "E5", 1.0), (2.0, "A5", 1.0), (3.0, "G5", 0.5), (3.5, "E5", 0.5)],
    [(0.0, "F5", 0.5), (0.5, "A5", 0.5), (1.0, "C6", 0.5), (1.5, "A5", 0.5), (2.0, "F5", 1.0), (3.0, "E5", 0.5), (3.5, "D5", 0.5)],
    [(0.0, "G5", 0.5), (0.5, "B5", 0.5), (1.0, "D6", 0.5), (1.5, "B5", 0.5), (2.0, "G5", 1.0), (3.0, "F5", 0.5), (3.5, "D5", 0.5)],
    [(0.0, "C6", 1.0), (1.0, "G5", 0.5), (1.5, "E5", 0.5), (2.0, "C5", 1.0), (3.0, "E5", 1.0)],
    [(0.0, "G5", 0.5), (0.5, "E5", 0.5), (1.0, "C6", 2.0)],
]

# 0..7 = A, 8..15 = B, 16..23 = vuelta a A.
STRUCTURE = ["A", "A", "B", "A"]

# Un acorde de paso para el "boing" de la vuelta.
BOING_NOTES = ["C6", "B5", "A5", "G5", "F5", "E5", "D5", "C5"]


def render_menu_theme():
    """Tema de menú: alegre, saltarín y con aire de carrera de obstáculos."""
    random.seed(SEED)
    n = int(PHRASE_BARS * 4 * SPB * SR)
    out = _empty(n)
    kick, snare = drum_kick(), drum_snare()
    hat, hat_soft = drum_hat(0.05), drum_hat(0.03)
    shaker = drum_hat(0.025)

    for bar in range(PHRASE_BARS):
        bar_start = bar * 4 * SPB * SR
        section = STRUCTURE[bar // 8]
        idx = bar % 8
        triad = CHORDS[bar][1]
        melody = MELODY_A if section == "A" else MELODY_B

        # Melodía principal: square brillante y staccato.
        for beat, name, beats in melody[idx]:
            amp = 0.27 if section == "A" else 0.25
            mix(out, bar_start + beat * SPB * SR,
                render_note("square", freq(name), beats * SPB * 0.82, amp,
                            duty=0.32, attack=0.005, release=0.035,
                            vib=0.0 if beats < 0.75 else 0.004,
                            detune=0.22))
            # Silbato una octava arriba en la sección B.
            if section == "B" and beats >= 0.5:
                mix(out, bar_start + beat * SPB * SR,
                    render_note("sine", freq(name) * 2.0, beats * SPB * 0.7, 0.09,
                                attack=0.006, release=0.04))

        # Bajo saltarín.
        for beat, semis in BASS_PATTERN:
            note = transpose(BASS_ROOTS[bar], semis)
            mix(out, bar_start + beat * SPB * SR,
                render_note("triangle", freq(note), SPB * 0.30, 0.36,
                            attack=0.004, release=0.025, decay=0.26))

        # Stabs de acorde en los contratiempos, al estilo de una banda de ska.
        for beat in (0.5, 1.5, 2.5, 3.5):
            for voice in triad:
                mix(out, bar_start + beat * SPB * SR,
                    render_note("triangle", freq(voice), SPB * 0.22, 0.05,
                                attack=0.008, release=0.05, decay=0.5))

        # Batería bailable.
        for beat in (0.0, 1.5, 2.0, 3.25):
            mix(out, bar_start + beat * SPB * SR, kick)
        for beat in (1.0, 3.0):
            mix(out, bar_start + beat * SPB * SR, snare)
        for eighth in range(8):
            # Swing suave: los contratios llegan un pelín tarde.
            offset = 0.055 if eighth % 2 == 1 else 0.0
            seg = hat if eighth % 4 == 0 else hat_soft
            mix(out, bar_start + (eighth * 0.5 + offset) * SPB * SR, seg)
            mix(out, bar_start + (eighth * 0.5 + offset) * SPB * SR, shaker)

        # Plato al empezar cada bloque.
        if bar in (0, 8, 16):
            mix(out, bar_start, hat_soft)
            mix(out, bar_start, drum_hat(0.18))

    # Redoble de entrada y "boing" de silbato en la última vuelta.
    bar_start = 16 * 4 * SPB * SR
    for i, name in enumerate(BOING_NOTES):
        mix(out, bar_start + (0.25 * i) * SPB * SR,
            render_note("sine", freq(name), SPB * 0.28, 0.10,
                        attack=0.004, release=0.04, vib=0.01, vib_hz=12.0))

    fade_edges(out, ms=3.0)  # bucle sin clicks en los extremos
    return out


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)

    print("Generando SFX...")
    random.seed(SEED)
    write_wav(SFX_DIR / "jump.wav", sfx_jump(), peak=0.92)
    write_wav(SFX_DIR / "step.wav", sfx_step(), peak=0.75)
    write_wav(SFX_DIR / "checkpoint.wav", sfx_checkpoint(), peak=0.92)
    write_wav(SFX_DIR / "finish.wav", sfx_finish(), peak=0.95)
    write_wav(SFX_DIR / "fall.wav", sfx_fall(), peak=0.90)
    write_wav(SFX_DIR / "land.wav", sfx_land(), peak=0.86)
    write_wav(SFX_DIR / "impact.wav", sfx_impact(), peak=0.9)
    write_wav(SFX_DIR / "coin.wav", sfx_coin(), peak=0.9)
    write_wav(SFX_DIR / "ui.wav", sfx_ui(), peak=0.8)
    write_wav(SFX_DIR / "countdown.wav", sfx_countdown(), peak=0.85)
    write_wav(SFX_DIR / "wind.wav", sfx_wind(), peak=0.75)
    write_wav(SFX_DIR / "cannon.wav", sfx_cannon(), peak=0.95)
    write_wav(SFX_DIR / "creak.wav", sfx_creak(), peak=0.80)
    write_wav(SFX_DIR / "boing.wav", sfx_boing(), peak=0.85)
    write_wav(SFX_DIR / "whoosh.wav", sfx_whoosh(), peak=0.75)

    print("Generando música (~%d s)..." % int(PHRASE_BARS * 4 * SPB))
    theme = MUSIC_DIR / "menu_theme.wav"
    write_wav(theme, render_menu_theme(), peak=0.86)
    print("Listo. Abre el proyecto en Godot para que importe los archivos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
