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


lastbank = array('B')
fpo = open(sys.argv[2], 'wb')

i = 1
bi = 1
overhead = 0
fnformat = sys.argv[1]
fn1 = fnformat % (i)
fn2 = fnformat % (i + 1)
while os.path.isfile(fn1) and os.path.isfile(fn2):
  image1 = prepareImage(fn1)
  image2 = prepareImage(fn2)
  
  print("\033[1G\033[KReading frame %d... (current bank = %d)" % (i, bi), 
        end="", flush=True)
  nextf = encodeImagePair(image1, image2)
  prevlastbanklen = len(lastbank)
  lastbank.extend(nextf)
  
  if len(lastbank) > 0x4000:
    newbank = array('B')
    
    for endslice in [144, 576, 144, 576, 144, 576, 144, 576]:
      tmp = lastbank[-endslice:]
      tmp.extend(newbank)
      newbank = tmp
      lastbank = lastbank[:-endslice]
      if len(lastbank) <= 0x4000:
        break
      
    overhead += 0x4000 - len(lastbank)
    lastbank.extend([0] * (0x4000 - len(lastbank)))
    
    if bi >= 0x1FF:
      print("Too much data; stopping at 8 MiB")
      break
    fpo.write(lastbank)
    lastbank = newbank
    bi += 1;
    
  i += 2
  fn1 = fnformat % (i)
  fn2 = fnformat % (i + 1)

lastbank.extend([0] * (0x4000 - len(lastbank)))
fpo.write(lastbank)
print("\033[1G\033[KWrote %d frames in %d banks" % (i-2, bi))
print("Bankswitch overhead = %d B" % (overhead))

