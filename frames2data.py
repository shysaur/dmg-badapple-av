#!/usr/bin/env python3

from PIL import Image
from array import array
from argparse import ArgumentParser
import sys
import os.path


VERBOSE = False


def vprint(*args, **kwargs):
  global VERBOSE
  if VERBOSE == True: print(*args, file=sys.stderr, **kwargs)


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


def encode(inputfns, outputfn):
  lastbank = array('B')
  if outputfn != None:
    fpo = open(outputfn, 'wb')
  else:
    fpo = sys.stdout.buffer

  bi = 1
  overhead = 0
  for i in range(0, len(inputfns), 2):
    image1 = prepareImage(inputfns[i])
    image2 = prepareImage(inputfns[i+1])
  
    vprint("\033[1G\033[KReading frame %d... (current bank = %d)" % (i+1, bi), 
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
        vprint("Too much data; stopping at 8 MiB")
        break
      fpo.write(lastbank)
      lastbank = newbank
      bi += 1;

  lastbank.extend([0] * (0x4000 - len(lastbank)))
  fpo.write(lastbank)
  if outputfn != None:
    fpo.close()
  vprint("\033[1G\033[KWrote %d frames in %d banks" % (i+2, bi))
  vprint("Bankswitch overhead = %d B" % (overhead))
    
    
def scanFiles(fnpattern):
  vprint("Scanning available frames...")
  allfiles = []
  i = 1
  fn = fnpattern % i
  while os.path.isfile(fn):
    allfiles.append(fn)
    i += 1
    fn = fnpattern % i
  return allfiles


def main():
  parser = ArgumentParser()
  parser.add_argument("-o", "--output", dest="outputfn", default=None,
                      help="write encoded data to FILE", metavar="FILE")
  parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                      help="log progress to stderr")
  parser.add_argument("files", nargs='+', metavar='frame-image',
                      help="a frame to be encoded, or a format string for " +
                      "generating filenames for all the frames that should " +
                      "contain a single formatting specification suitable for " +
                      "an integer number (such as %%d)")
  options = parser.parse_args()

  global VERBOSE
  VERBOSE = options.verbose
  
  if len(options.files) == 1:
    allfiles = scanFiles(options.files[0])
  else:
    allfiles = options.files
  
  encode(allfiles, options.outputfn)
  

if __name__ == "__main__":
    main()
