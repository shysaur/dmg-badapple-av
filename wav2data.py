#!/usr/bin/env python3

import sys
import soundfile as sf
import random as rand
from math import *
from pathlib import Path
import numpy as np
from argparse import ArgumentParser

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
    parser = ArgumentParser()
    parser.add_argument("-o", "--output", dest="outputfn", default=None,
                        help="write encoded data to FILE", metavar="FILE")
    parser.add_argument("inputfn", nargs='?', metavar='FILE',
                        help="an audio file to be encoded")
    parser.add_argument('-d', '--include', dest='include', default=None,
                        help='write number of banks to FILE', metavar='FILE')
    opts = parser.parse_args()
    
    data, samplerate = sf.read(opts.inputfn)
    quantized = map(quantize, data)
    packed = bytes(byte_generator(quantized))
    if opts.include:
        n_banks = (len(packed) + 0x3FFF) // 0x4000
        with open(opts.include, "w") as f:
            f.write('DEF NUM_AUDIO_BANKS = ' + str(n_banks) + '\n')
    Path(opts.outputfn).write_bytes(packed)

if __name__ == '__main__':
    main()

