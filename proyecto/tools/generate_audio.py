#!/usr/bin/env python3
"""Genera los archivos de audio del proyecto.

Todo el audio se sintetiza desde cero (sin samples de terceros), así que es
libre de derechos y se puede regenerar en cualquier momento:

    python3 tools/generate_audio.py

Salidas:
    audio/music/background.ogg   (bucle de chiptune, ~55 s)
    audio/sfx/jump.wav
    audio/sfx/checkpoint.wav
    audio/sfx/finish.wav
    audio/sfx/fall.wav

Requiere ffmpeg para codificar la música a OGG Vorbis.
"""

import math
import random
import shutil
import subprocess
import sys
import wave
from array import array
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MUSIC_DIR = PROJECT_ROOT / "audio" / "music"
SFX_DIR = PROJECT_ROOT / "audio" / "sfx"

SR = 44100            # sample rate
BPM = 140             # music tempo
SPB = 60.0 / BPM      # seconds per beat
PHRASE_BARS = 32      # 4 phrases of 8 bars -> ~55 s loop

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


# --------------------------------------------------------------------------
# Música
# --------------------------------------------------------------------------

# Un acorde por compás (ciclo de 8 compases).
CHORDS = [
    ("C", ["C5", "E5", "G5"]),
    ("G", ["G4", "B4", "D5"]),
    ("A", ["A4", "C5", "E5"]),
    ("F", ["F4", "A4", "C5"]),
    ("C", ["C5", "E5", "G5"]),
    ("G", ["G4", "B4", "D5"]),
    ("F", ["F4", "A4", "C5"]),
    ("G", ["G4", "B4", "D5"]),
]
BASS_ROOTS = ["C2", "G2", "A2", "F2", "C2", "G2", "F2", "G2"]

# Patrón de bajo en corcheas (beat, grado).
BASS_PATTERN = [(0.0, 0), (0.5, 0), (1.0, 1), (1.5, 0),
                (2.0, 0), (2.5, 0), (3.0, 1), (3.5, 2)]
BASS_SHIFT = {0: 0, 1: 7, 2: 12}  # raíz, quinta, octava

# Melodías: por compás, lista de (beat, nota, duración en beats).
MELODY_A = [
    [(0.0, "E5", 0.5), (0.5, "G5", 0.5), (1.0, "C6", 1.0), (2.0, "G5", 0.5), (2.5, "E5", 0.5), (3.0, "G5", 1.0)],
    [(0.0, "D5", 0.5), (0.5, "G5", 0.5), (1.0, "B5", 1.0), (2.0, "G5", 0.5), (2.5, "D5", 0.5), (3.0, "B4", 1.0)],
    [(0.0, "A4", 0.5), (0.5, "C5", 0.5), (1.0, "E5", 1.0), (2.0, "C5", 0.5), (2.5, "A4", 0.5), (3.0, "E5", 1.0)],
    [(0.0, "F4", 0.5), (0.5, "A4", 0.5), (1.0, "C5", 1.0), (2.0, "F5", 1.0), (3.0, "E5", 1.0)],
    [(0.0, "E5", 0.5), (0.5, "G5", 0.5), (1.0, "C6", 1.0), (2.0, "B5", 0.5), (2.5, "A5", 0.5), (3.0, "G5", 1.0)],
    [(0.0, "D5", 0.5), (0.5, "G5", 0.5), (1.0, "B5", 1.0), (2.0, "D6", 1.0), (3.0, "B5", 1.0)],
    [(0.0, "C5", 0.5), (0.5, "F5", 0.5), (1.0, "A5", 2.0), (3.0, "G5", 1.0)],
    [(0.0, "B4", 0.5), (0.5, "D5", 0.5), (1.0, "G5", 1.0), (2.0, "G5", 0.5), (2.5, "F5", 0.5), (3.0, "E5", 0.5), (3.5, "D5", 0.5)],
]
MELODY_B = [
    [(0.0, "C6", 1.0), (1.0, "G5", 0.5), (1.5, "E5", 0.5), (2.0, "C6", 1.0), (3.0, "E6", 1.0)],
    [(0.0, "B5", 1.0), (1.0, "G5", 0.5), (1.5, "D5", 0.5), (2.0, "B5", 1.0), (3.0, "D6", 1.0)],
    [(0.0, "E5", 1.0), (1.0, "C5", 0.5), (1.5, "A4", 0.5), (2.0, "E5", 1.0), (3.0, "A5", 1.0)],
    [(0.0, "A5", 1.0), (1.0, "F5", 0.5), (1.5, "C5", 0.5), (2.0, "A5", 1.0), (3.0, "F5", 0.5), (3.5, "G5", 0.5)],
    [(0.0, "C6", 0.5), (0.5, "B5", 0.5), (1.0, "A5", 0.5), (1.5, "G5", 0.5), (2.0, "E5", 2.0)],
    [(0.0, "D6", 0.5), (0.5, "B5", 0.5), (1.0, "G5", 0.5), (1.5, "D5", 0.5), (2.0, "B5", 2.0)],
    [(0.0, "F5", 0.5), (0.5, "A5", 0.5), (1.0, "C6", 1.0), (2.0, "A5", 0.5), (2.5, "F5", 0.5), (3.0, "C5", 1.0)],
    [(0.0, "G5", 1.0), (1.0, "B5", 1.0), (2.0, "D6", 1.0), (3.0, "G5", 1.0)],
]

STRUCTURE = ["A", "A", "B", "A"]


def render_music():
    random.seed(SEED)
    n = int(PHRASE_BARS * 4 * SPB * SR)
    out = _empty(n)
    kick, snare = drum_kick(), drum_snare()
    hat, hat_soft = drum_hat(0.05), drum_hat(0.03)

    for bar in range(PHRASE_BARS):
        bar_start = bar * 4 * SPB * SR
        section = STRUCTURE[(bar // 8) % len(STRUCTURE)]
        idx = bar % 8
        triad = CHORDS[idx][1]

        # Melodía
        melody = MELODY_A if section == "A" else MELODY_B
        for beat, name, beats in melody[idx]:
            amp = 0.30 if section == "A" else 0.28
            mix(out, bar_start + beat * SPB * SR,
                render_note("square", freq(name), beats * SPB * 0.92, amp,
                            duty=0.28, attack=0.006, release=0.05, detune=0.25,
                            vib=0.004, vib_hz=6.0))

        # Bajo
        for beat, degree in BASS_PATTERN:
            note = transpose(BASS_ROOTS[idx], BASS_SHIFT[degree])
            mix(out, bar_start + beat * SPB * SR,
                render_note("triangle", freq(note), SPB * 0.42, 0.34,
                            attack=0.004, release=0.03, decay=0.22))

        # Acordes (stabs en los tiempos 1 y 3)
        for beat in (0.0, 2.0):
            for voice in triad:
                mix(out, bar_start + beat * SPB * SR,
                    render_note("triangle", freq(voice), SPB * 1.7, 0.075,
                                attack=0.02, release=0.25, decay=0.9))

        # Batería
        for beat in (0.0, 2.0):
            mix(out, bar_start + beat * SPB * SR, kick)
        for beat in (1.0, 3.0):
            mix(out, bar_start + beat * SPB * SR, snare)
        for eighth in range(8):
            seg = hat if eighth % 2 == 0 else hat_soft
            mix(out, bar_start + eighth * 0.5 * SPB * SR, seg)

    fade_edges(out, ms=2.0)  # bucle sin clicks en los extremos
    return out


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    if shutil.which("ffmpeg") is None:
        print("ERROR: se necesita ffmpeg para codificar background.ogg", file=sys.stderr)
        return 1

    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)

    print("Generando SFX...")
    random.seed(SEED)
    write_wav(SFX_DIR / "jump.wav", sfx_jump(), peak=0.92)
    write_wav(SFX_DIR / "checkpoint.wav", sfx_checkpoint(), peak=0.92)
    write_wav(SFX_DIR / "finish.wav", sfx_finish(), peak=0.95)
    write_wav(SFX_DIR / "fall.wav", sfx_fall(), peak=0.90)

    print("Generando música (~%d s)..." % int(PHRASE_BARS * 4 * SPB))
    tmp = MUSIC_DIR / "_background_tmp.wav"
    write_wav(tmp, render_music(), peak=0.88)
    ogg = MUSIC_DIR / "background.ogg"
    # `-fflags +bitexact` en la salida fija el número de serie de las páginas
    # Ogg, de modo que el .ogg resultante es byte a byte reproducible.
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp),
         "-c:a", "libvorbis", "-q:a", "5", "-ac", "1",
         "-fflags", "+bitexact", str(ogg)],
        check=True,
    )
    tmp.unlink()
    print("  %-42s %5.2f s" % (ogg.relative_to(PROJECT_ROOT),
                               PHRASE_BARS * 4 * SPB))
    print("Listo. Abre el proyecto en Godot para que importe los archivos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
