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

# ---------- các tiếng (chất Mount & Blade 2: ngắn, chắc, nặng, khô; ít ngân, ít vọng) ----------

def whoosh(seed, dur=0.28, bright=1.0):
    rate = 22050; rng = Rng(seed); n = int(rate*dur); d = [0.0]*n
    lp = lp2 = 0.0
    for i in range(n):
        x = i/n; shape = math.sin(math.pi*x)
        cut = (0.05 + 0.25*shape)*bright
        lp += (rng.f(-1,1)-lp)*cut; lp2 += (lp-lp2)*cut
        d[i] = (lp-lp2)*shape*shape
    return d, rate

def splinters(d, rate, rng, count, t0, t1, a0, a1):
    for k in range(count):
        noise_burst(d, rate, rng, int(rng.f(t0, t1)*rate), 0.0008, rng.f(a0, a1))

def blade_clash(seed, base):
    rate = 32000; rng = Rng(seed); d = buf(rate, 0.55)
    j = lambda: rng.f(0.97, 1.03)
    ratios = [1.0, 1.58, 2.76, 3.47, 5.40, 6.93, 8.93]
    decays = [0.34, 0.26, 0.2, 0.15, 0.1, 0.07, 0.05]
    amps   = [0.5, 0.3, 0.45, 0.3, 0.3, 0.2, 0.18]
    fs = [base*r*j() for r in ratios]
    add_modes(d, rate, 0, fs, decays, amps)
    add_modes(d, rate, 0, [f*1.0035 for f in fs], decays, [a*0.7 for a in amps])
    noise_burst(d, rate, rng, 0, 0.003, 2.2)
    band_noise(d, rate, rng, 0, 0.06, 3200, 2400, 2000, 2.6, 0.0005, 0.015)
    band_noise(d, rate, rng, int(0.01*rate), 0.1, 6000, 3000, 800, 0.8, 0.005, 0.04, grain=0.03)
    add_modes(d, rate, 0, [420*j(), 900*j()], [0.05, 0.03], [0.8, 0.5])
    sweep_sine(d, rate, 0, 200, 120, 0.02, 0.04, 0.9)
    reverb(d, rate, 0.08, 0.25)
    return d, rate

def haft_hit(seed, base=1.0):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.3)
    j = lambda: rng.f(0.94, 1.06)
    add_modes(d, rate, 0, [f*base*j() for f in (380, 820, 1350, 2100, 3050)],
              [0.07, 0.045, 0.03, 0.02, 0.012], [1.0, 0.7, 0.55, 0.4, 0.3])
    noise_burst(d, rate, rng, 0, 0.002, 2.4)
    noise_burst(d, rate, rng, 0, 0.025, 1.6, hp=False, lp_a=0.25)
    add_modes(d, rate, 0, [1900*j(), 2600*j(), 4300*j(), 6900*j()], [0.08, 0.07, 0.05, 0.035], [0.3, 0.35, 0.25, 0.15])
    sweep_sine(d, rate, 0, 160, 95, 0.02, 0.06, 1.2)
    splinters(d, rate, rng, 4, 0.002, 0.022, 0.6, 1.2)
    reverb(d, rate, 0.08, 0.25)
    return d, rate

def shield_hit(seed):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.4)
    j = lambda: rng.f(0.93, 1.07)
    add_modes(d, rate, 0, [f*j() for f in (140, 235, 360, 520, 760, 1050)],
              [0.09, 0.07, 0.05, 0.035, 0.025, 0.018], [1.0, 0.9, 0.75, 0.55, 0.4, 0.25])
    noise_burst(d, rate, rng, 0, 0.03, 2.6, hp=False, lp_a=0.15)
    noise_burst(d, rate, rng, 0, 0.01, 1.0, hp=False, lp_a=0.4)
    noise_burst(d, rate, rng, 0, 0.002, 1.6)
    sweep_sine(d, rate, 0, 110, 65, 0.03, 0.07, 1.2)
    splinters(d, rate, rng, 8, 0.001, 0.03, 0.5, 1.0)
    for k in range(2):  # vành sắt
        add_modes(d, rate, int((0.002 + k*0.03 + rng.f(0, 0.01))*rate), [rng.f(2600, 3800)], [0.025], [0.08])
    reverb(d, rate, 0.08, 0.3)
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

def armour(d, rate, rng, plates, gap, amp):
    # giáp lá: các mảnh sắt nhỏ va nhau lách cách ngay lúc trúng
    for k in range(plates):
        at = int((0.001 + k*gap + rng.f(0, gap*0.7))*rate)
        add_modes(d, rate, at, [rng.f(1800, 3200), rng.f(3800, 5200)], [rng.f(0.02, 0.04), 0.015],
                  [amp/(1 + 0.3*k), amp*0.4])

def flesh_slash(seed, heavy=False):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.35)
    band_noise(d, rate, rng, 0, 0.06, 3500*rng.f(0.9,1.1), 1500, 1500, 1.2, 0.003, 0.025)
    band_noise(d, rate, rng, 0, 0.08, 600, 350, 500, 3.0, 0.001, 0.025)
    sweep_sine(d, rate, int(0.004*rate), 130, 55, 0.03, 0.08, 1.7)
    noise_burst(d, rate, rng, int(0.004*rate), 0.05, 3.5, hp=False, lp_a=0.06)
    wet_grains(d, rate, rng, 8, 0.1, 250, 800, 3.0)
    armour(d, rate, rng, 5, 0.012, 0.28)
    if heavy:
        splinters(d, rate, rng, 8, 0.008, 0.035, 1.0, 1.8)
        sweep_sine(d, rate, int(0.01*rate), 80, 40, 0.05, 0.12, 1.3)
    reverb(d, rate, 0.06, 0.25)
    return d, rate

def flesh_stab(seed):
    rate = 22050; rng = Rng(seed); d = buf(rate, 0.35)
    band_noise(d, rate, rng, 0, 0.04, 2400, 1600, 1200, 1.2, 0.002, 0.012)
    band_noise(d, rate, rng, 0, 0.08, 500, 300, 450, 2.6, 0.001, 0.03)
    sweep_sine(d, rate, int(0.004*rate), 110, 45, 0.04, 0.09, 1.8)
    noise_burst(d, rate, rng, int(0.004*rate), 0.07, 3.5, hp=False, lp_a=0.05)
    wet_grains(d, rate, rng, 10, 0.15, 200, 600, 4.0)
    armour(d, rate, rng, 2, 0.015, 0.2)
    reverb(d, rate, 0.06, 0.25)
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
 ("0_vung_dao_nang", lambda: whoosh(3, 0.42, 0.55), 0.6),
 ("0_vung_kiem_nhe", lambda: whoosh(4, 0.24, 1.2), 0.6),
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
