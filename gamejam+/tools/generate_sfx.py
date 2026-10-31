#!/usr/bin/env python3
"""Gera os SFX placeholder do jogo (estilo sfxr/jsfxr) em assets/audio/sfx/*.wav.

Só usa a biblioteca padrão. Para trocar um som, gere outro no jsfxr com o mesmo nome
(.wav ou .ogg; o .ogg tem preferência no AudioManager) ou ajuste os parâmetros abaixo e rode:
    python3 tools/generate_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")


def synth(wave_type, freq, slide, duration, attack=0.005, sustain=0.0, volume=0.5,
          vibrato=0.0, vibrato_speed=0.0, arp=None, seed=1):
    """wave_type: square, saw, sine, noise, triangle. slide: oitavas por segundo (negativo desce)."""
    rng = random.Random(seed)
    total = int(duration * RATE)
    samples = []
    phase = 0.0
    noise_val = 0.0
    for i in range(total):
        t = i / RATE
        f = freq * (2.0 ** (slide * t))
        if arp is not None and t >= arp[0]:
            f *= arp[1]
        if vibrato > 0.0:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vibrato_speed * t)
        f = max(f, 20.0)
        prev = phase
        phase = (phase + f / RATE) % 1.0
        if wave_type == "square":
            s = 1.0 if phase < 0.5 else -1.0
        elif wave_type == "saw":
            s = 2.0 * phase - 1.0
        elif wave_type == "triangle":
            s = 4.0 * abs(phase - 0.5) - 1.0
        elif wave_type == "sine":
            s = math.sin(2 * math.pi * phase)
        else:
            if phase < prev:
                noise_val = rng.uniform(-1.0, 1.0)
            s = noise_val
        # Envelope: ataque linear, sustentação e decaimento exponencial-ish
        if t < attack:
            env = t / attack
        elif t < attack + sustain:
            env = 1.0
        else:
            rest = (t - attack - sustain) / max(duration - attack - sustain, 1e-4)
            env = max(1.0 - rest, 0.0) ** 2
        samples.append(s * env * volume)
    return samples


def mix(*layers):
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def write(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))
    print("[SFX] -", path)


SOUNDS = {
    "shoot": lambda: synth("square", 880, -3.0, 0.09, volume=0.35),
    "hit": lambda: mix(synth("noise", 2200, -2.0, 0.07, volume=0.4), synth("square", 300, -4.0, 0.06, volume=0.2)),
    "crit": lambda: mix(synth("square", 1200, -1.5, 0.16, volume=0.3, arp=(0.05, 1.5)), synth("noise", 3000, -3.0, 0.1, volume=0.35)),
    "enemy_die": lambda: mix(synth("noise", 900, -2.5, 0.22, volume=0.45), synth("square", 260, -3.0, 0.18, volume=0.2)),
    "elite_die": lambda: mix(synth("noise", 500, -1.5, 0.5, volume=0.55, sustain=0.05), synth("saw", 160, -1.5, 0.45, volume=0.3)),
    "player_hurt": lambda: mix(synth("saw", 420, -2.5, 0.25, volume=0.4), synth("noise", 1200, -2.0, 0.12, volume=0.3)),
    "player_die": lambda: mix(synth("saw", 300, -1.2, 0.9, volume=0.4, sustain=0.1, vibrato=0.05, vibrato_speed=12), synth("noise", 600, -1.0, 0.6, volume=0.3)),
    "wall_hit": lambda: synth("noise", 1600, -3.0, 0.05, volume=0.3),
    "pickup": lambda: synth("square", 700, 0.0, 0.18, volume=0.3, arp=(0.06, 1.5)),
    "potion_swap": lambda: synth("triangle", 500, 3.0, 0.1, volume=0.4),
    "brew": lambda: mix(synth("noise", 400, 1.0, 0.45, volume=0.35, attack=0.05), synth("sine", 300, 2.5, 0.45, volume=0.35, vibrato=0.1, vibrato_speed=20)),
    "room_lock": lambda: mix(synth("square", 140, -0.5, 0.35, volume=0.35, sustain=0.05), synth("noise", 300, -1.0, 0.25, volume=0.4)),
    "room_clear": lambda: synth("square", 520, 0.0, 0.45, volume=0.3, sustain=0.1, arp=(0.15, 1.335)),
    "mimic_wake": lambda: mix(synth("saw", 200, 2.0, 0.25, volume=0.35), synth("noise", 800, 0.0, 0.15, volume=0.25)),
    "synergy": lambda: mix(synth("square", 660, 0.0, 0.6, volume=0.25, sustain=0.15, arp=(0.2, 1.5)), synth("sine", 1320, 0.0, 0.6, volume=0.2, vibrato=0.02, vibrato_speed=8)),
    "ui_click": lambda: synth("square", 1000, 0.0, 0.04, volume=0.3),
    "ui_hover": lambda: synth("sine", 1400, 0.0, 0.03, volume=0.25),
}


if __name__ == "__main__":
    for sfx_name, build in SOUNDS.items():
        write(sfx_name, build())
