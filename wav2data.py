#!/usr/bin/env python3

import sys
import soundfile as sf
import random as rand
from math import *
from pathlib import Path
import numpy as np

def quantize_one(mixed):
    dither = 0  # (rand.random() - rand.random()) / 2
    in_k = 5 / 8
    out_k = 7 / 8
    if mixed > in_k:
        compressed = ((mixed - in_k) * (1 - in_k) * (1 - out_k) + out_k)
    elif -in_k < mixed and mixed <= in_k:
        compressed = (mixed / in_k * out_k)
    else:
        compressed = ((mixed + in_k) * (1 - in_k) * (1 - out_k) - out_k)
    scaled_sa = (compressed / 2) * 8 + 7 / 2
    return max(0, min(floor(scaled_sa + dither), 7))

def quantize(sa):
    s1, s2 = sa
    return quantize_one(s1), quantize_one(s2)

def byte_generator(samples):
    for (s1, s2) in samples:
        yield (s1 << 4) + s2

def main():
    data, samplerate = sf.read(sys.argv[1])
    quantized = map(quantize, data)
    packed = bytes(byte_generator(quantized))
    Path(sys.argv[2]).write_bytes(packed)

if __name__ == '__main__':
    main()

