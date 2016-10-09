#!/usr/bin/env python3

from PIL import Image
from array import array
from argparse import ArgumentParser
import sys
import os.path


VERBOSE = False
MAINTAIN_ASPECT = False
FIT_VERT = False
WIDTH = 160
HEIGHT = 144
HBLK_BYTES = 576
VBLK_BYTES = 144


def vprint(*args, **kwargs):
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
  for coarsex in range(0, WIDTH, 8):
    for y in range(0, HEIGHT//2):
      res.append(encodeSliver(image1, (coarsex, y)))
      res.append(encodeSliver(image2, (coarsex, y)))
  return res
      

def prepareImage(filename):
  image = Image.open(filename).convert("L")
  if MAINTAIN_ASPECT:
    if FIT_VERT:
      destw = WIDTH * image.height // HEIGHT
      desth = image.height
    else:
      destw = image.width
      desth = HEIGHT * image.width // WIDTH
    tmp = Image.new("L", (destw, desth))
    tmp.paste(image, ((destw - image.width) // 2, (desth - image.height) // 2))
    image = tmp
  
  image = image.resize((WIDTH, HEIGHT//2), Image.BILINEAR)
  return image.convert("1", None, Image.NONE)


def encode(inputfns, outputfn):
  lastbank = array('B')
  if outputfn != None:
    fpo = open(outputfn, 'wb')
  else:
    fpo = sys.stdout.buffer

  bi = 1
  overhead = 0
  i = 0
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
    
      for endslice in [VBLK_BYTES, HBLK_BYTES] * 4:
        tmp = lastbank[-endslice:]
        tmp.extend(newbank)
        newbank = tmp
        lastbank = lastbank[:-endslice]
        if len(lastbank) <= 0x4000:
          break
      
      overhead += 0x4000 - len(lastbank)
      lastbank.extend([0] * (0x4000 - len(lastbank)))
    
      if bi >= 0x1FF:
        vprint("\nToo much data; stopping at 8 MiB")
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
  vprint("Found %d" % (i-1))
  return allfiles


def main():
  global VERBOSE, MAINTAIN_ASPECT, FIT_VERT
  global WIDTH, HEIGHT, VBLK_BYTES, HBLK_BYTES
  
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
  parser.add_argument("-p", "--mantain-aspect", dest="aspect",
                      choices=['no', 'fit-horizontal', 'fit-vertical'],
                      default='no', help="specifies if and how to scale each " +
                      "frame to make them fit the screen")
  parser.add_argument("-x", "--width", dest="width", type=int,
                      default=WIDTH, help="the encoded video's width")
  parser.add_argument("-y", "--height", dest="height", type=int,
                      default=HEIGHT, help="the encoded video's height")
  parser.add_argument("-i", "--vblk-bytes", dest="vblkbytes", type=int,
                      default=VBLK_BYTES, help="the amount of video bytes " +
                      "copied in vblank")
  options = parser.parse_args()

  VERBOSE = options.verbose
  if options.aspect != 'no':
    MAINTAIN_ASPECT = True
    if options.aspect == 'fit-vertical':
      FIT_VERT = True
  WIDTH = options.width
  HEIGHT = options.height
  VBLK_BYTES = options.vblkbytes
  HBLK_BYTES = ((WIDTH // 8) * ((HEIGHT // 2) // 8)) * 16 // 4 - VBLK_BYTES
  
  if len(options.files) == 1:
    allfiles = scanFiles(options.files[0])
  else:
    allfiles = options.files
  
  encode(allfiles, options.outputfn)
  

if __name__ == "__main__":
    main()
