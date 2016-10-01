#!/usr/bin/env python3

from PIL import Image
from array import array
import sys
import os.path


def encodeSliver(image, origin):
  coarsex, y = origin
  next = 0
  for x in range(coarsex, coarsex+8):
    next *= 2
    next += 1 if image.getpixel((x, y)) < 128 else 0
  return next
  
  
def encodeImagePair(image1, image2):
  res = array('B')
  for coarsex in range(0, 160, 8):
    for y in range(0, 144//2):
      res.append(encodeSliver(image1, (coarsex, y)))
      res.append(encodeSliver(image2, (coarsex, y)))
  return res
      

def prepareImage(filename):
  image = Image.open(filename).convert("L")
  image = image.resize((160, 144//2), Image.BILINEAR)
  return image.convert("1", None, Image.NONE)


databanks = array('B')

i = 1
fnformat = sys.argv[1]
fn1 = fnformat % (i)
fn2 = fnformat % (i + 1)
while os.path.isfile(fn1) and os.path.isfile(fn2):
  image1 = prepareImage(fn1)
  image2 = prepareImage(fn2)
  
  nextf = encodeImagePair(image1, image2)
  if len(databanks) % 0x4000 + len(nextf) > 0x4000:
    databanks.extend([0] * (0x4000 - len(databanks)))
  databanks.extend(nextf)
  
  i += 2
  print("\033[1G\033[KReading frame %d..." % (i), end="", flush=True)
  fn1 = fnformat % (i)
  fn2 = fnformat % (i + 1)

print("\033[1G\033[KWriting %d frames" % (i))
fpo = open(sys.argv[2], 'wb')
fpo.write(databanks)
