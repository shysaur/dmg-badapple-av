#!/usr/bin/env python3

from PIL import Image
from array import array
from argparse import ArgumentParser
import sys
import os.path
import itertools
import functools


VERBOSE = False
MAINTAIN_ASPECT = False
FIT_VERT = False
WIDTH = 160
HEIGHT = 144
HBLK_BYTES = 576
VBLK_BYTES = 144

HBLK_PACKETS = 144
VBLK_PACKETS = 36


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
  res = bytearray()
  for coarsex in range(0, WIDTH, 8):
    for y in range(0, HEIGHT//2):
      res.append(encodeSliver(image1, (coarsex, y)))
      res.append(encodeSliver(image2, (coarsex, y)))
  return res
  

def diffFrames(old, new):
  assert len(old) == len(new)
  
  if len(old) % 3 != 0:
    pad = bytes([0] * (3 - len(old) % 3))
    old = bytes(old) + pad
    new = bytes(new) + pad

  res = bytearray()
  lastskip = 0
  i = 0
  while old[i:] != new[i:]:
    p1 = old[i:i+3]
    p2 = new[i:i+3]
    if p1 == p2 and lastskip < 255:
      lastskip += 3
    else:
      res += bytes([lastskip])
      res += p2
      lastskip = 0
    i += 3
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

  
def generateBlocks(inputfns):
  global HBLK_PACKETS, VBLK_PACKETS
  
  def compressedBlock(_head, _body, lastInBank):
    return _head + bytes([len(_body)//4, 1 if lastInBank else 0, 0, 0]) + _body
    
  def literalBlock(_head, _body, lastInBank):
    return _head + _body
    
  def stopBlock(lastInBank):
    return bytes([1, 0, 0, 0])
    
  i = 0
  
  oldf1, oldf2 = None, None
  for i in range(0, len(inputfns), 2):
    image1 = prepareImage(inputfns[i])
    image2 = prepareImage(inputfns[i+1])
  
    nextf = encodeImagePair(image1, image2)
    
    oldf = oldf1 if i % 4 == 0 else oldf2
    compress = False
    if oldf:
      diff = diffFrames(oldf, nextf)
      if len(diff) + 8*4 >= (HBLK_BYTES + VBLK_BYTES) * 4:
        data = nextf
      else:
        compress = True
        data = diff
    else:
      data = nextf
      
    # frame head
    framehead = bytes([0, 0x18 if compress else 0x3E, 0, 0])
    
    if compress:
      # compressed frame
      
      # redistribute the dead time across the entirety of the frame
      npackets = len(data)//4
      margin = (HBLK_PACKETS + VBLK_PACKETS) * 4 - npackets
      hblmargin = int(margin * HBLK_PACKETS / (HBLK_PACKETS + VBLK_PACKETS))
      vblmargin = margin - hblmargin
      hblmargin /= 4
      vblmargin /= 4
      
      vblpackets, vblme, hblpackets, hblme = 0, 0, 0, 0
      blocksizes = []
      for k in range(4):
        a = HBLK_PACKETS - int(hblmargin+hblme)
        b = VBLK_PACKETS - int(vblmargin+vblme)
        vblpackets += a
        hblpackets += b
        blocksizes += [a*4, b*4]
        vblme = (vblme + vblmargin) % 1
        hblme = (hblme + hblmargin) % 1
      
      assert vblpackets + hblpackets == npackets
      
      prev_slice_end = 0
      for cur_slice_len in blocksizes:
        if prev_slice_end + cur_slice_len >= len(data):
          cur_slice_len = len(data) - prev_slice_end
        
        body = data[prev_slice_end : prev_slice_end+cur_slice_len]
        yield functools.partial(compressedBlock, framehead, body), i
        
        prev_slice_end += cur_slice_len
        framehead = bytes()
        
    else:
      # literal frame
      prev_slice_end = 0
      for cur_slice_len in [HBLK_BYTES, VBLK_BYTES] * 4:
        body = data[prev_slice_end : prev_slice_end+cur_slice_len]
        yield functools.partial(literalBlock, framehead, body), i
        
        prev_slice_end += cur_slice_len
        framehead = bytes()
        
    if i % 4 == 0:
      oldf1 = nextf
    else:
      oldf2 = nextf

  yield stopBlock, i


def encode(inputfns, outputfn):
  lastbank = bytearray()
  if outputfn != None:
    fpo = open(outputfn, 'wb')
  else:
    fpo = sys.stdout.buffer
    
  def lookahead(gen):
    prevv = next(gen)
    for nextv in gen:
      yield prevv[0], prevv[1], len(nextv[0](False))
      prevv = nextv
    yield prevv[0], prevv[1], 0

  bi = 1
  overhead = 0
  for blockf, i, nextblocksize in lookahead(generateBlocks(inputfns)):
    vprint("\033[1G\033[KReading frame %d... (output @ %d:%04X)" % \
          (i+1, bi, len(lastbank) + 0x4000), \
          end="", flush=True)
          
    blocksize = len(blockf(False))
    
    if len(lastbank) + blocksize <= 0x4000:
      nextwillofl = len(lastbank) + blocksize + nextblocksize > 0x4000
      lastbank.extend(blockf(nextwillofl))
      
    else:
      if bi >= 0x1FF:
        vprint("\nToo much data; stopping at 8 MiB")
        break
        
      overhead += 0x4000 - len(lastbank)
      lastbank.extend([0] * (0x4000 - len(lastbank)))
      fpo.write(lastbank)
      
      bi += 1
      lastbank = bytearray()
      nextwillofl = len(lastbank) + blocksize + nextblocksize > 0x4000
      lastbank.extend(blockf(nextwillofl))

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
