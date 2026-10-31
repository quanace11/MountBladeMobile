# Bản Python của các tiếng va chạm trong src/audio/sfx_synth.gd (cùng thuật toán, khác bộ sinh số ngẫu nhiên),
# để nghe thử hoặc chỉnh tiếng mà không cần mở Godot:
#   python3 tools/sfx_preview.py <thư mục ra>
# Sửa thông số ở đây thì nhớ sửa giống hệt bên sfx_synth.gd.
import math, random, struct, wave, sys

TAU = 2*math.pi

class Rng:
    def __init__(s, seed): s.r = random.Random(seed)
    def f(s, a, b): return s.r.uniform(a, b)

def buf(rate, dur): return [0.0]*int(rate*dur)

def add_modes(d, rate, start, freqs, decays, amps):
    for f, tau, a in zip(freqs, decays, amps):
        w = TAU*f/rate
        if w >= math.pi*0.95: continue
        r = math.exp(-1.0/(tau*rate)); c1 = 2*r*math.cos(w); c2 = -r*r
        y = a*math.sin(w); yp = 0.0
        end = min(len(d), start+int(tau*rate*7))
        for i in range(start, end):
            d[i] += y; yn = c1*y + c2*yp; yp = y; y = yn

def res_coef(f, bw, rate):
    r = math.exp(-math.pi*bw/rate); w = TAU*f/rate
    return 2*r*math.cos(w), -r*r, (1-r)*2*math.sin(w) if w < math.pi else 0.0

def noise_burst(d, rate, rng, start, tau, amp, hp=True, lp_a=1.0):
    # nhiễu tắt nhanh; hp: lấy hiệu (bỏ trầm) ; lp_a: hệ số lọc thông thấp
    lp = 0.0; lp2 = 0.0
    end = min(len(d), start+int(tau*rate*7))
    for i in range(start, end):
        t = (i-start)/rate
        lp += (rng.f(-1,1)-lp)*lp_a
        v = lp
        if hp:
            lp2 += (lp-lp2)*0.35; v = lp-lp2
        d[i] += amp*v*math.exp(-t/tau)

def band_noise(d, rate, rng, start, dur, f0, f1, bw, amp, attack, tau, grain=0.0):
    y1 = y2 = 0.0; g = 0.0; n = int(dur*rate)
    for k in range(n):
        i = start+k
        if i >= len(d): break
        x = k/n; t = k/rate
        if k % 32 == 0:
            c1, c2, gg = res_coef(f0*(f1/f0)**x, bw, rate)
        y = gg*rng.f(-1,1) + c1*y1 + c2*y2
        y2 = y1; y1 = y
        env = min(1.0, t/attack) * math.exp(-t/tau)
        if grain > 0:
            g += (abs(rng.f(-1,1)) - g)*grain
            env *= 0.4 + 1.6*g
        d[i] += amp*y*env

def sweep_sine(d, rate, start, f0, f1, glide, tau, amp, attack=0.002):
    ph = 0.0
    end = min(len(d), start+int(tau*rate*7))
    for i in range(start, end):
        t = (i-start)/rate
        f = f1 + (f0-f1)*math.exp(-t/glide)
        ph += TAU*f/rate
        d[i] += amp*math.sin(ph)*min(1.0, t/attack)*math.exp(-t/tau)

def reverb(d, rate, wet, tail):
    n0 = len(d); d.extend([0.0]*int(tail*rate))
    out = [0.0]*len(d)
    for ms, fb in ((29.7,0.78),(37.1,0.76),(41.1,0.74),(43.7,0.72)):
        D = int(ms*rate/1000); line = [0.0]*D; p = 0; lp = 0.0
        for i in range(len(d)):
            y = line[p]; lp += (y-lp)*0.45
            line[p] = d[i] + lp*fb; p = (p+1) % D
            out[i] += y*0.25
    for ms in (5.0, 1.7):
        D = int(ms*rate/1000); line = [0.0]*D; p = 0
        for i in range(len(out)):
            b = line[p]; x = out[i]; y = -0.7*x + b
            line[p] = x + 0.7*y; p = (p+1) % D; out[i] = y
    for i in range(len(d)): d[i] += wet*out[i]

# ---------- các tiếng ----------

def blade_clash(seed, base):
    rate = 32000; rng = Rng(seed); d = buf(rate, 1.1)
    j = lambda: rng.f(0.97, 1.03)
    ratios = [1.0, 1.58, 2.76, 3.47, 5.40, 6.93, 8.93]
    decays = [0.85, 0.65, 0.5, 0.38, 0.24, 0.17, 0.11]
    amps   = [0.5, 0.3, 0.45, 0.3, 0.3, 0.2, 0.18]
    fs = [base*r*j() for r in ratios]
    add_modes(d, rate, 0, fs, decays, amps)
    add_modes(d, rate, 0, [f*1.0035 for f in fs], decays, [a*0.7 for a in amps])
    noise_burst(d, rate, rng, 0, 0.0025, 2.2)
    band_noise(d, rate, rng, 0, 0.06, 3800, 3000, 1800, 2.0, 0.0005, 0.012)
    # xiiing: hai lưỡi miết vào nhau
    band_noise(d, rate, rng, int(0.012*rate), 0.26, 6500, 2600, 700, 1.8, 0.01, 0.09, grain=0.02)
    sweep_sine(d, rate, 0, 260, 170, 0.02, 0.03, 0.5)
    reverb(d, rate, 0.22, 0.5)
    return d, rate

def haft_hit(seed, base=1.0):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.35)
    j = lambda: rng.f(0.94, 1.06)
    add_modes(d, rate, 0, [f*base*j() for f in (380, 820, 1350, 2100, 3050)],
              [0.07, 0.045, 0.03, 0.02, 0.012], [1.0, 0.7, 0.55, 0.4, 0.3])
    noise_burst(d, rate, rng, 0, 0.0015, 2.0)
    noise_burst(d, rate, rng, 0, 0.02, 1.2, hp=False, lp_a=0.25)
    # tiếng "cạch" nhỏ của lưỡi đao bên kia
    add_modes(d, rate, 0, [2600*j(), 4300*j(), 6900*j()], [0.09, 0.06, 0.04], [0.24, 0.16, 0.1])
    sweep_sine(d, rate, 0, 150, 100, 0.02, 0.05, 0.8)
    for k in range(4):  # thớ gỗ dập
        noise_burst(d, rate, rng, int(rng.f(0.002, 0.022)*rate), 0.0008, rng.f(0.6, 1.2))
    reverb(d, rate, 0.14, 0.35)
    return d, rate

def shield_hit(seed):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.5)
    j = lambda: rng.f(0.93, 1.07)
    add_modes(d, rate, 0, [f*j() for f in (92, 150, 228, 310, 455, 640)],
              [0.16, 0.11, 0.08, 0.06, 0.04, 0.03], [1.0, 0.8, 0.6, 0.45, 0.3, 0.2])
    noise_burst(d, rate, rng, 0, 0.045, 2.2, hp=False, lp_a=0.08)
    noise_burst(d, rate, rng, 0, 0.012, 0.8, hp=False, lp_a=0.3)
    noise_burst(d, rate, rng, 0, 0.002, 1.2)
    sweep_sine(d, rate, 0, 120, 70, 0.03, 0.09, 1.0)
    for k in range(3):  # đinh tán, vành sắt lách cách
        add_modes(d, rate, int((0.002 + k*0.035 + rng.f(0, 0.015))*rate), [rng.f(2600, 3800), rng.f(4500, 5600)],
                  [0.03, 0.02], [0.12/(k+1), 0.06/(k+1)])
    reverb(d, rate, 0.16, 0.4)
    return d, rate

def wet_grains(d, rate, rng, count, t_max, f_lo, f_hi, amp):
    for k in range(count):
        u = rng.f(0, 1); t0 = 0.004 + t_max*u*u
        ln = rng.f(0.006, 0.02); f = rng.f(f_lo, f_hi)
        a = amp*(1.0 - 0.6*u)
        c1, c2, g = res_coef(f, 180, rate)
        y1 = y2 = 0.0; n = int(ln*rate); s = int(t0*rate)
        for m in range(n):
            i = s+m
            if i >= len(d): break
            y = g*rng.f(-1,1) + c1*y1 + c2*y2; y2 = y1; y1 = y
            d[i] += a*y*math.sin(math.pi*m/n)

def flesh_slash(seed, heavy=False):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.4)
    band_noise(d, rate, rng, 0, 0.11, 4800*rng.f(0.9,1.1), 1300, 1400, 2.4, 0.004, 0.05)
    noise_burst(d, rate, rng, 0, 0.03, 0.5)
    sweep_sine(d, rate, int(0.008*rate), 95, 45, 0.04, 0.07, 1.2)
    noise_burst(d, rate, rng, int(0.006*rate), 0.06, 4.0, hp=False, lp_a=0.06)
    wet_grains(d, rate, rng, 14, 0.17, 250, 1000, 4.5)
    for k in range(3):  # giáp lá
        add_modes(d, rate, int((0.002 + k*0.016 + rng.f(0, 0.01))*rate), [rng.f(2400, 4200)], [rng.f(0.012, 0.02)], [0.12])
    if heavy:
        for k in range(6):  # xương gãy
            noise_burst(d, rate, rng, int((0.012 + rng.f(0, 0.025))*rate), 0.0012, rng.f(0.8, 1.5))
        sweep_sine(d, rate, int(0.01*rate), 70, 38, 0.05, 0.11, 1.0)
    reverb(d, rate, 0.1, 0.3)
    return d, rate

def flesh_stab(seed):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.42)
    band_noise(d, rate, rng, 0, 0.05, 2800, 1800, 1200, 1.6, 0.002, 0.016)
    sweep_sine(d, rate, int(0.004*rate), 80, 40, 0.05, 0.09, 1.4)
    noise_burst(d, rate, rng, int(0.004*rate), 0.09, 2.6, hp=False, lp_a=0.05)
    wet_grains(d, rate, rng, 18, 0.24, 200, 700, 6.5)
    reverb(d, rate, 0.1, 0.3)
    return d, rate

def norm(d, gain):
    p = max(1e-4, max(abs(v) for v in d))
    return [v/p*gain for v in d]

def write(path, d, rate, gain):
    d = norm(d, gain)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1,min(1,v))*32767)) for v in d))

def stats(name, d, rate):
    p = max(abs(v) for v in d)
    rms = math.sqrt(sum(v*v for v in d[:int(0.05*rate)])/int(0.05*rate))
    print(f"{name:14s} peak={p:7.3f} rms50ms/peak={rms/p:.3f} len={len(d)/rate:.2f}s")


if __name__ == '__main__':
    import os
    out = sys.argv[1] if len(sys.argv) > 1 else "sfx_preview"; os.makedirs(out, exist_ok=True)
    items = [
     ("1_luoi_cham_luoi_a", lambda: blade_clash(21, 1250), 0.9),
     ("1_luoi_cham_luoi_b", lambda: blade_clash(22, 1080), 0.9),
     ("2_chem_vao_can_a", lambda: haft_hit(31), 0.95),
     ("2_chem_vao_can_b", lambda: haft_hit(32, 0.88), 0.95),
     ("3_chem_vao_khien_a", lambda: shield_hit(41), 0.95),
     ("3_chem_vao_khien_b", lambda: shield_hit(42), 0.95),
     ("4_chem_trung_thit_a", lambda: flesh_slash(51), 0.95),
     ("4_chem_trung_thit_b", lambda: flesh_slash(52), 0.95),
     ("5_dam_trung_thit", lambda: flesh_stab(61), 0.95),
     ("6_don_chi_mang", lambda: flesh_slash(71, True), 1.0),
    ]
    for name, fn, g in items:
        d, rate = fn(); stats(name, d, rate); write(f"{out}/{name}.wav", d, rate, g)
