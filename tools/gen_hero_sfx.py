"""Synthesised sound effects for Hoshimi Miyabi (frost swordswoman) and Luong Tho (twin gunblades).

Usage: python3 tools/gen_hero_sfx.py Assets/Audio   -> Assets/Audio/Miyabi/*.wav, Assets/Audio/LuongTho/*.wav
Everything is generated from noise / sine partials with numpy + scipy (no samples), deterministic
(fixed seeds), 32 kHz mono 16-bit PCM with a 44-byte header, loudness-matched to the Yugi set.
"""
import os, sys, wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 32000
OUT = sys.argv[1]
rng = np.random.default_rng(20261123)


# ----------------------------------------------------------------------------- building blocks
def n_of(dur):
    return int(round(dur * SR))


def t_axis(dur):
    return np.arange(n_of(dur)) / SR


def noise(dur):
    return rng.standard_normal(n_of(dur))


def _sos(kind, f, order=4):
    if kind == "band":
        lo, hi = max(20.0, f[0]), min(SR / 2 - 100, f[1])
        return butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return butter(order, min(f, SR / 2 - 100), btype=kind, fs=SR, output="sos")


def band(x, lo, hi, order=4):
    return sosfilt(_sos("band", (lo, hi), order), x)


def lowp(x, f, order=4):
    return sosfilt(_sos("low", f, order), x)


def highp(x, f, order=4):
    return sosfilt(_sos("high", f, order), x)


def env_ad(n, attack, tau, hold=0.0):
    """Attack (s) -> hold (s) -> exponential decay with time constant tau (s)."""
    t = np.arange(n) / SR
    e = np.where(t < attack, t / max(attack, 1e-6), np.exp(-np.maximum(t - attack - hold, 0.0) / tau))
    return e


def env_bell(n, peak_at, width):
    """Smooth swell (gaussian) peaking at peak_at seconds - the shape of a blade whoosh."""
    t = np.arange(n) / SR
    return np.exp(-0.5 * ((t - peak_at) / width) ** 2)


def sweep_band(x, f0, f1, q=2.5, frames=64):
    """Band-pass whose centre glides from f0 to f1 (overlap-add of short frames)."""
    n = len(x)
    hop = max(1, n // frames)
    win = np.hanning(hop * 2)
    out = np.zeros(n + hop * 2)
    for i in range(0, n, hop):
        seg = x[i:i + hop * 2]
        if len(seg) < hop * 2:
            seg = np.pad(seg, (0, hop * 2 - len(seg)))
        frac = i / max(n - 1, 1)
        fc = f0 * (f1 / f0) ** frac
        bw = fc / q
        y = sosfilt(_sos("band", (fc - bw / 2, fc + bw / 2), 2), seg)
        out[i:i + hop * 2] += y * win
    return out[:n]


def tone(freq, dur, phase=0.0):
    """Sine whose frequency may be a constant or an array (glide)."""
    n = n_of(dur)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)[:n]
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def glide(f0, f1, dur, curve=1.0):
    t = np.linspace(0, 1, n_of(dur)) ** curve
    return f0 * (f1 / f0) ** t


def partials(f0, dur, ratios, amps, taus, detune=0.0):
    """Inharmonic struck partials (metal / glass), each with its own decay."""
    n = n_of(dur)
    x = np.zeros(n)
    for r, a, tau in zip(ratios, amps, taus):
        f = f0 * r * (1 + detune * rng.uniform(-1, 1))
        x += a * tone(f, dur, rng.uniform(0, 6.28)) * env_ad(n, 0.0015, tau)
    return x


def place(dst, src, at, gain=1.0):
    i = n_of(at)
    if i >= len(dst):
        return dst
    m = min(len(src), len(dst) - i)
    dst[i:i + m] += src[:m] * gain
    return dst


def canvas(dur):
    return np.zeros(n_of(dur))


def reverb(x, size=0.35, damp=5000.0, mix=0.18):
    """Cheap room: convolution with exponentially decaying, low-passed noise."""
    ir = lowp(noise(size), damp, 2) * np.exp(-np.arange(n_of(size)) / (SR * size / 5.0))
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(x, ir)
    dry = np.pad(x, (0, len(wet) - len(x)))
    return dry * (1 - mix) + wet * mix


def soft_clip(x, drive):
    if drive <= 0:
        return x
    return np.tanh(x * (1 + drive)) / np.tanh(1 + drive)


# ----------------------------------------------------------------------------- frost elements
def ice_ping(f0, dur=0.35, tau=0.09):
    """One glassy ping: high inharmonic partials with a very fast attack."""
    return partials(f0, dur, (1.0, 2.32, 3.87, 5.61), (1.0, 0.55, 0.32, 0.18), (tau, tau * 0.7, tau * 0.5, tau * 0.35), 0.01)


def ice_crackle(dur, density, lo=2500.0, hi=9000.0, ping_mix=0.5):
    """Sparkling crackle: random clicks plus small glass pings spread over dur."""
    x = canvas(dur + 0.3)
    count = max(1, int(density * dur))
    for _ in range(count):
        at = rng.uniform(0, dur)
        click = highp(noise(0.006), 3500) * env_ad(n_of(0.006), 0.0005, 0.0015)
        place(x, click, at, rng.uniform(0.3, 1.0))
        if rng.random() < ping_mix:
            place(x, ice_ping(rng.uniform(lo, hi), 0.2, rng.uniform(0.02, 0.06)), at, rng.uniform(0.15, 0.45))
    return x


def frost_air(dur, f0, f1, peak_at, width, q=2.2):
    """Cold airy whoosh: noise through a gliding band-pass with a swell envelope."""
    x = sweep_band(noise(dur), f0, f1, q)
    return x * env_bell(len(x), peak_at, width)


def blade_shing(f0=2300.0, dur=0.6, tau=0.16):
    """Metallic ring of a blade edge."""
    ring = partials(f0, dur, (1.0, 1.51, 2.37, 3.11, 4.73), (1.0, 0.7, 0.45, 0.3, 0.15),
                    (tau, tau * 0.8, tau * 0.6, tau * 0.45, tau * 0.3), 0.004)
    scrape = band(noise(dur), 3000, 9000) * env_ad(n_of(dur), 0.002, 0.03)
    return ring + scrape * 0.6


# ----------------------------------------------------------------------------- Miyabi
def miyabi_slash(variant):
    # quick blade whoosh (peaks right away: played on the hit frame) + icy sparkle trailing it
    f0, f1 = (1400, 5200) if variant == 1 else (5000, 1500)
    x = canvas(0.42)
    place(x, frost_air(0.26, f0, f1, 0.05, 0.035, 2.0), 0.0, 1.0)
    place(x, blade_shing(2600 if variant == 1 else 2900, 0.3, 0.05), 0.03, 0.18)
    place(x, ice_crackle(0.12, 70, 4000, 9000, 0.6), 0.05, 0.22)
    return reverb(x, 0.25, 7000, 0.12)


def miyabi_slash_heavy():
    # third swing: bigger, lower whoosh, then the target freezes with a crack
    x = canvas(0.75)
    place(x, frost_air(0.38, 900, 4200, 0.07, 0.05, 1.8), 0.0, 1.0)
    place(x, lowp(noise(0.12), 900) * env_ad(n_of(0.12), 0.002, 0.03), 0.04, 0.6)
    place(x, blade_shing(2100, 0.5, 0.09), 0.04, 0.22)
    crack = highp(noise(0.03), 1800) * env_ad(n_of(0.03), 0.0008, 0.006)
    place(x, crack, 0.08, 0.9)
    place(x, ice_crackle(0.25, 90, 3000, 8000, 0.7), 0.09, 0.35)
    return reverb(x, 0.3, 6500, 0.15)


def miyabi_dash():
    # dash slash: very fast doppler-ish swish (low -> high -> low) with a bright cut through the middle
    x = canvas(0.5)
    swish = sweep_band(noise(0.3), 700, 7000, 2.4) * env_bell(n_of(0.3), 0.07, 0.04)
    place(x, swish, 0.0, 1.0)
    place(x, frost_air(0.25, 6000, 2500, 0.06, 0.04, 2.5), 0.06, 0.5)
    place(x, blade_shing(3100, 0.4, 0.07), 0.07, 0.3)
    place(x, ice_crackle(0.2, 60, 5000, 10000, 0.5), 0.09, 0.2)
    return reverb(x, 0.25, 7000, 0.12)


def miyabi_charge():
    # charging: a cold breath gathering into a rising crystalline shimmer (~0.9 s)
    dur = 0.9
    n = n_of(dur)
    env = np.minimum(1.0, np.arange(n) / (SR * 0.6)) * np.where(np.arange(n) > SR * 0.8, np.exp(-(np.arange(n) - SR * 0.8) / (SR * 0.04)), 1.0)
    air = sweep_band(noise(dur), 600, 3500, 3.0) * env * 0.7
    shimmer = np.zeros(n)
    for k, ratio in enumerate((1.0, 1.5, 2.0, 3.0)):
        f = glide(700 * ratio, 1400 * ratio, dur, 0.8)
        trem = 0.6 + 0.4 * np.sin(2 * np.pi * (9 + k * 2.3) * np.arange(n) / SR)
        shimmer += tone(f, dur) * trem * (0.45 / (k + 1))
    x = air + shimmer * env
    x = x + ice_crackle(dur, 25, 3500, 9000, 0.8)[:n] * np.linspace(0.2, 1.0, n) * 0.5
    return reverb(x, 0.35, 6000, 0.2)


def miyabi_charge_full():
    # fully charged: a bright glassy chime (a triad of ice pings) - "ready" cue
    x = canvas(0.8)
    for at, f in ((0.0, 2637.0), (0.035, 3322.0), (0.07, 3951.0)):
        place(x, ice_ping(f, 0.7, 0.22), at, 0.8)
    place(x, ice_crackle(0.15, 80, 5000, 10000, 0.4), 0.0, 0.25)
    return reverb(x, 0.45, 8000, 0.25)


def miyabi_wave(full):
    # Frost Wave released: a cutting gust; the full-charge wave adds a deep frozen body and crackle
    dur = 0.75 if full else 0.55
    x = canvas(dur)
    place(x, frost_air(dur * 0.8, 3500, 900, 0.07, 0.07 if full else 0.05, 1.7), 0.0, 1.0)
    place(x, frost_air(dur * 0.6, 6500, 2500, 0.05, 0.04, 3.0), 0.0, 0.5)
    if full:
        body = tone(glide(240, 110, 0.45), 0.45) * env_ad(n_of(0.45), 0.01, 0.12)
        place(x, body, 0.02, 0.55)
        place(x, ice_crackle(0.5, 110, 2500, 8000, 0.7), 0.05, 0.45)
    else:
        place(x, ice_crackle(0.3, 50, 4000, 9000, 0.5), 0.05, 0.25)
    return reverb(x, 0.35, 6000, 0.18)


def miyabi_ice_spikes():
    # Frost Bloom: blade stabbed into the ground (thud) then spikes burst out in a row (~0.45 s)
    x = canvas(1.0)
    thud = lowp(noise(0.15), 400) * env_ad(n_of(0.15), 0.002, 0.04)
    place(x, thud, 0.0, 1.0)
    place(x, tone(glide(140, 55, 0.25), 0.25) * env_ad(n_of(0.25), 0.003, 0.07), 0.0, 0.8)
    for i, at in enumerate(np.linspace(0.02, 0.43, 6)):   # one burst per growth frame (14 fps)
        burst = band(noise(0.09), 1500 + i * 250, 7000) * env_ad(n_of(0.09), 0.001, 0.02)
        place(x, burst, at, 0.7)
        crack = highp(noise(0.02), 2000) * env_ad(n_of(0.02), 0.0005, 0.004)
        place(x, crack, at + 0.004, 0.8)
        place(x, ice_ping(rng.uniform(1800, 3200) * (1 + i * 0.05), 0.3, 0.07), at + 0.006, 0.35)
        place(x, lowp(noise(0.06), 700) * env_ad(n_of(0.06), 0.002, 0.018), at, 0.35)
    place(x, ice_crackle(0.5, 60, 3000, 9000, 0.5), 0.05, 0.3)
    return reverb(x, 0.4, 5500, 0.2)


def miyabi_ice_shatter():
    # the spike line breaks: glass-like shatter with falling shards
    x = canvas(1.0)
    hit = highp(noise(0.05), 1200) * env_ad(n_of(0.05), 0.0008, 0.012)
    place(x, hit, 0.0, 1.0)
    place(x, band(noise(0.25), 2500, 11000) * env_ad(n_of(0.25), 0.001, 0.06), 0.0, 0.6)
    for _ in range(40):
        at = abs(rng.normal(0.08, 0.12))
        place(x, ice_ping(rng.uniform(2500, 9000), 0.25, rng.uniform(0.02, 0.07)), at, rng.uniform(0.1, 0.4) * np.exp(-at * 3))
    place(x, ice_crackle(0.6, 60, 4000, 10000, 0.3), 0.02, 0.4)
    return reverb(x, 0.5, 7000, 0.22)


def miyabi_spirit_bolt():
    # ice spirit shot (every 2 s, so kept soft and short): a small magical "pew" with a chime
    x = canvas(0.4)
    pew = tone(glide(2400, 950, 0.16, 0.6), 0.16) * env_ad(n_of(0.16), 0.004, 0.05)
    place(x, pew, 0.0, 0.8)
    place(x, ice_ping(3500, 0.3, 0.06), 0.0, 0.25)
    place(x, frost_air(0.15, 4000, 2000, 0.03, 0.03, 3.0), 0.0, 0.3)
    return reverb(x, 0.3, 7000, 0.2)


# ----------------------------------------------------------------------------- Luong Tho
def lt_blade(f0=1900.0):
    return blade_shing(f0, 0.45, 0.07)


def lt_stab():
    # long thrust: tight, fast whoosh forward + metallic edge
    x = canvas(0.45)
    place(x, sweep_band(noise(0.18), 1200, 4500, 3.0) * env_bell(n_of(0.18), 0.035, 0.025), 0.0, 1.0)
    place(x, lt_blade(2050), 0.02, 0.28)
    place(x, lowp(noise(0.05), 1200) * env_ad(n_of(0.05), 0.001, 0.012), 0.03, 0.35)
    return reverb(x, 0.25, 6000, 0.12)


def lt_swing():
    # tonfa-blade sweep: wide whoosh with a heavier metal body
    x = canvas(0.5)
    place(x, sweep_band(noise(0.3), 600, 3200, 2.0) * env_bell(n_of(0.3), 0.06, 0.045), 0.0, 1.0)
    place(x, lt_blade(1650), 0.04, 0.24)
    place(x, partials(420, 0.3, (1.0, 2.7, 5.1), (1.0, 0.5, 0.2), (0.06, 0.04, 0.03)), 0.04, 0.12)
    return reverb(x, 0.25, 5500, 0.12)


def lt_smash():
    # ground smash: weapons slam the floor - boom, metal clang, cracked stone and debris
    x = canvas(1.0)
    place(x, sweep_band(noise(0.15), 500, 2500, 2.0) * env_bell(n_of(0.15), 0.04, 0.03), 0.0, 0.5)
    hit_at = 0.04
    boom = tone(glide(110, 38, 0.5, 0.7), 0.5) * env_ad(n_of(0.5), 0.002, 0.13)
    place(x, boom, hit_at, 1.0)
    place(x, lowp(noise(0.3), 600) * env_ad(n_of(0.3), 0.001, 0.07), hit_at, 0.9)
    place(x, partials(780, 0.6, (1.0, 1.58, 2.42, 3.9), (1.0, 0.6, 0.4, 0.2), (0.15, 0.11, 0.07, 0.05), 0.005), hit_at, 0.25)
    place(x, highp(noise(0.03), 1500) * env_ad(n_of(0.03), 0.0005, 0.006), hit_at, 0.7)
    for _ in range(25):                                        # debris
        at = hit_at + abs(rng.normal(0.12, 0.12))
        place(x, band(noise(0.02), 800, 5000) * env_ad(n_of(0.02), 0.0008, 0.005), at, rng.uniform(0.08, 0.3))
    return soft_clip(reverb(x, 0.45, 4500, 0.22), 0.6)


def gunshot(body_f=95.0, crack_lo=1500.0, brightness=1.0):
    x = canvas(0.6)
    crack = highp(noise(0.012), crack_lo) * env_ad(n_of(0.012), 0.0003, 0.0025)
    place(x, crack, 0.0, 1.0)
    blast = band(noise(0.12), 300, 6000 * brightness) * env_ad(n_of(0.12), 0.0006, 0.018)
    place(x, blast, 0.0, 0.9)
    thump = tone(glide(body_f * 1.6, body_f * 0.5, 0.15), 0.15) * env_ad(n_of(0.15), 0.001, 0.035)
    place(x, thump, 0.0, 0.9)
    tail = lowp(noise(0.5), 1800) * env_ad(n_of(0.5), 0.005, 0.11)
    place(x, tail, 0.01, 0.22)
    return x


def lt_shot(moon):
    # Twin Barrels: both barrels fire a hair apart, then a mechanical clack (the White Moon
    # rounds sound brighter with a pale energy ring)
    x = canvas(0.85)
    place(x, gunshot(100, 1400, 1.0 if not moon else 1.4), 0.0, 1.0)
    place(x, gunshot(88, 1300, 1.0 if not moon else 1.4), 0.045, 0.85)
    clack = partials(2600, 0.12, (1.0, 1.9, 3.3), (1.0, 0.6, 0.3), (0.012, 0.01, 0.008))
    place(clack, highp(noise(0.02), 3000) * env_ad(n_of(0.02), 0.0005, 0.004), 0.0)
    place(x, clack, 0.2, 0.25)
    if moon:
        ring = partials(1320, 0.6, (1.0, 2.0, 3.01, 4.2), (1.0, 0.5, 0.3, 0.15), (0.2, 0.15, 0.1, 0.07))
        place(x, ring, 0.0, 0.22)
        place(x, tone(glide(3000, 1200, 0.25), 0.25) * env_ad(n_of(0.25), 0.002, 0.07), 0.0, 0.15)
    return soft_clip(reverb(x, 0.5, 5000, 0.2), 0.8)


def lt_transform():
    # White Moon (1 s): a rising, shimmering swell that resolves into a bright moon-bell
    dur = 1.6
    n = n_of(dur)
    x = np.zeros(n)
    rise = n_of(0.95)
    env = np.zeros(n)
    env[:rise] = (np.arange(rise) / rise) ** 1.6
    env[rise:] = np.exp(-(np.arange(n - rise)) / (SR * 0.25))
    for k, ratio in enumerate((1.0, 1.25, 1.5, 2.0, 3.0)):     # rising major chord pad
        f = glide(220 * ratio, 440 * ratio, dur, 0.5)
        f = np.where(np.arange(n) < rise, f, f[rise - 1])
        pad = tone(f * (1 + 0.003 * k), dur) + 0.5 * tone(f * 2.003, dur)
        x += pad * env * (0.35 / (1 + 0.5 * k))
    x += sweep_band(noise(dur), 400, 7000, 2.5) * env * 0.35
    for _ in range(45):                                        # sparkles thickening towards the peak
        at = 0.95 * np.sqrt(rng.random())
        place(x, ice_ping(rng.uniform(3000, 9000), 0.2, rng.uniform(0.02, 0.05)), at, rng.uniform(0.05, 0.2))
    bell = partials(880, 1.0, (1.0, 2.0, 2.76, 4.07, 5.4), (1.0, 0.6, 0.45, 0.25, 0.15), (0.6, 0.45, 0.3, 0.2, 0.12))
    place(x, bell, 0.95, 0.75)
    place(x, highp(noise(0.08), 2000) * env_ad(n_of(0.08), 0.002, 0.02), 0.95, 0.3)
    return reverb(x, 0.8, 6000, 0.3)


def lt_revert():
    # the white form fades: a short descending shimmer
    dur = 0.6
    n = n_of(dur)
    env = env_ad(n, 0.02, 0.18)
    x = np.zeros(n)
    for k, ratio in enumerate((1.0, 1.5, 2.0)):
        x += tone(glide(880 * ratio, 330 * ratio, dur, 0.7), dur) * (0.4 / (k + 1))
    x = x * env + sweep_band(noise(dur), 5000, 600, 2.5) * env * 0.4
    return reverb(x, 0.5, 5000, 0.25)


def lt_block():
    # a hit shrugged off by the White Moon form: a light crystal "ting"
    x = canvas(0.45)
    place(x, partials(1760, 0.4, (1.0, 2.0, 3.0, 4.16), (1.0, 0.4, 0.25, 0.12), (0.12, 0.09, 0.06, 0.04)), 0.0, 1.0)
    place(x, highp(noise(0.01), 3000) * env_ad(n_of(0.01), 0.0005, 0.002), 0.0, 0.5)
    return reverb(x, 0.35, 7000, 0.2)


def lt_draw():
    # weapons drawn from the back to fight: a soft metal unsheathe
    x = canvas(0.45)
    scrape = band(noise(0.22), 2500, 8000) * env_bell(n_of(0.22), 0.1, 0.05)
    place(x, scrape, 0.0, 0.6)
    place(x, lt_blade(2400) * 0.5, 0.17, 0.5)
    place(x, partials(900, 0.08, (1.0, 2.3), (1.0, 0.5), (0.01, 0.008)), 0.18, 0.3)
    return reverb(x, 0.2, 6000, 0.1)


# ----------------------------------------------------------------------------- output
TARGET_RMS = 0.17
PEAK = 0.89


def active_rms(a):
    win = int(SR * 0.02)
    k = len(a) // win
    if k == 0:
        return float(np.sqrt(np.mean(a ** 2)) + 1e-9)
    frames = np.sqrt(np.mean(a[: k * win].reshape(k, win) ** 2, axis=1))
    loud = frames[frames > frames.max() * 0.1]
    return float(np.sqrt(np.mean(loud ** 2)) + 1e-9)


def finish(x, gain_db=0.0):
    x = highp(x, 35, 2)                                        # no DC / sub rumble
    thr = np.abs(x).max() * 10 ** (-55 / 20)
    idx = np.where(np.abs(x) > thr)[0]
    x = x[: idx[-1] + 1]
    fi, fo = n_of(0.002), min(n_of(0.03), len(x) // 2)
    x[:fi] *= np.linspace(0, 1, fi)
    x[-fo:] *= np.linspace(1, 0, fo)
    target = TARGET_RMS * 10 ** (gain_db / 20)
    # transient-heavy sounds (cracks, shots) may go up to +6 dB past peak normalisation; the
    # excess is rounded off by a soft knee limiter instead of being clipped
    gain = min(target / active_rms(x), 2.0 * PEAK / np.abs(x).max())
    return limit(x * gain)


def limit(x, ceiling=PEAK, knee=0.6):
    k = ceiling * knee
    a = np.abs(x)
    over = a > k
    y = x.copy()
    y[over] = np.sign(x[over]) * (k + (ceiling - k) * np.tanh((a[over] - k) / (ceiling - k)))
    return y


def write(path, x):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)


SOUNDS = {
    "Miyabi": {
        "miyabi_slash_1": (lambda: miyabi_slash(1), 0.0),
        "miyabi_slash_2": (lambda: miyabi_slash(2), 0.0),
        "miyabi_slash_3": (miyabi_slash_heavy, 0.0),
        "miyabi_dash": (miyabi_dash, 0.0),
        "miyabi_charge": (miyabi_charge, -3.0),
        "miyabi_charge_full": (miyabi_charge_full, -2.0),
        "miyabi_wave": (lambda: miyabi_wave(False), 0.0),
        "miyabi_wave_full": (lambda: miyabi_wave(True), 0.0),
        "miyabi_ice_spikes": (miyabi_ice_spikes, 0.0),
        "miyabi_ice_shatter": (miyabi_ice_shatter, -1.0),
        "miyabi_spirit_bolt": (miyabi_spirit_bolt, -7.0),
    },
    "LuongTho": {
        "lt_stab": (lt_stab, 0.0),
        "lt_swing": (lt_swing, 0.0),
        "lt_smash": (lt_smash, 2.0),
        "lt_shot": (lambda: lt_shot(False), 3.0),
        "lt_shot_moon": (lambda: lt_shot(True), 3.0),
        "lt_transform": (lt_transform, 0.0),
        "lt_revert": (lt_revert, -2.0),
        "lt_block": (lt_block, -4.0),
        "lt_draw": (lt_draw, -8.0),
    },
}

if __name__ == "__main__":
    for folder, sounds in SOUNDS.items():
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        for name, (fn, gain_db) in sounds.items():
            x = finish(fn(), gain_db)
            p = os.path.join(OUT, folder, name + ".wav")
            write(p, x)
            print("%-9s %-20s %5.2fs peak=%.2f rms=%.3f" % (folder, name, len(x) / SR, np.abs(x).max(), active_rms(x)))
