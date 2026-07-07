#!/usr/bin/env python3
"""종이 구기는 소리 합성 → App/crumple.wav
짧은 크링클(noise grain)들을 무작위로 겹쳐 종이 구기는 질감을 만든다."""
import wave, struct, random, math

SR = 44100
DUR = 0.45
N = int(SR * DUR)
random.seed(7)

buf = [0.0] * N

# 여러 개의 크링클 grain. 시간이 갈수록 밀도/세기 감소.
num_grains = 90
for _ in range(num_grains):
    # 앞쪽에 더 몰리도록 (구기는 순간 와르륵 → 잦아듦)
    t0 = (random.random() ** 1.6) * (DUR - 0.02)
    start = int(t0 * SR)
    tau = random.uniform(0.003, 0.012)        # 3~12ms 빠른 감쇠
    glen = int(min(0.04, tau * 5) * SR)
    gain = random.uniform(0.2, 1.0) * (1.0 - t0 / DUR) ** 0.5
    prev = 0.0
    for i in range(glen):
        if start + i >= N:
            break
        white = random.uniform(-1, 1)
        # 차분(high-pass)으로 바삭한 고역 강조
        hp = white - prev
        prev = white
        env = math.exp(-i / (tau * SR))
        buf[start + i] += hp * env * gain

# 전체 페이드 아웃 꼬리
fade = int(0.06 * SR)
for i in range(fade):
    idx = N - fade + i
    buf[idx] *= (1 - i / fade)

# 정규화
peak = max(1e-6, max(abs(x) for x in buf))
scale = 0.62 / peak

with wave.open("App/crumple.wav", "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for x in buf:
        v = int(max(-1.0, min(1.0, x * scale)) * 32767)
        frames += struct.pack("<h", v)
    w.writeframes(bytes(frames))

print("wrote App/crumple.wav", N, "samples")
