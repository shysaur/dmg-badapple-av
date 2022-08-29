#!/usr/bin/env python3

import sys
import soundfile as sf
import random as rand
from math import *
from pathlib import Path
import numpy as np

def quantize(sa):
    mixed = sum(list(sa)) / len(sa)
    scaled_sa = ((mixed + 1) / 2) * 16
    return max(0, min(round(scaled_sa + rand.random() / 2), 15))

def byte_generator(samples):
    lsamples=list(samples)
    iterators = (lsamples[i::32] for i in range(0,32))
    for subframe in zip(*iterators):
        fixed_subframe = subframe[31:32] + subframe[0:31]
        for sa1, sa2 in zip(fixed_subframe[0::2], fixed_subframe[1::2]):
            yield (sa1 << 4) + sa2

def main():
    data, samplerate = sf.read(sys.argv[1])
    quantized = map(quantize, data)
    packed = bytes(byte_generator(quantized))
    Path(sys.argv[2]).write_bytes(packed)

if __name__ == '__main__':
    main()

