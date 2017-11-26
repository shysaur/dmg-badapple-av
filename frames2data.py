#!/usr/bin/env python3

from PIL import Image, ImageOps
from array import array
from argparse import ArgumentParser
import sys
import os.path
import itertools
import functools


VERBOSE = False
ASPECT = 'auto'
WIDTH = 160
HEIGHT = 144
HBLK_BYTES = 576
VBLK_BYTES = 144

HBLK_PACKETS = 144
VBLK_PACKETS = 36


def vprint(*args, **kwargs):
  if VERBOSE == True: print(*args, file=sys.stderr, **kwargs)
  
  
def prepareImage(filename):
  image = Image.open(filename).convert("L")
  if ASPECT != 'no':
    # auto chooses the fit that fills the whole screen
    bestfit_is_vert = (image.width / image.height * HEIGHT) >= WIDTH
    
    if ASPECT == 'fit-vertical' or (ASPECT == 'auto' and bestfit_is_vert):
      destw = WIDTH * image.height // HEIGHT
      desth = image.height
    elif ASPECT == 'fit-horizontal' or (ASPECT == 'auto' and not bestfit_is_vert):
      destw = image.width
      desth = HEIGHT * image.width // WIDTH
      
    tmp = Image.new("L", (destw, desth))
    tmp.paste(image, ((destw - image.width) // 2, (desth - image.height) // 2))
    image = tmp
  
  image = image.resize((WIDTH, HEIGHT//2), Image.BILINEAR)
  return ImageOps.invert(image).convert("1", None, Image.NONE)


def linearizeSingleImage(image):
  out = Image.new('1', (8, image.height * (image.width//8)))
  for x in range(0, image.width, 8):
    out.paste(image.crop((x, 0, x+8, image.height)), (0, (x//8)*image.height))
  return out
  
  
def encodeImagePair(image1, image2):
  ei1, ei2 = linearizeSingleImage(image1), linearizeSingleImage(image2)
  out = Image.new('1', (16, ei1.height))
  out.paste(ei1, (0, 0))
  out.paste(ei2, (8, 0))
  return out.tobytes()
  

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
  
  
def generateBlocksForMetaframe(oldf, nextf):
  def compressedBlock(_head, _body, lastInBank):
    return _head + bytes([len(_body)//4, 1 if lastInBank else 0, 0, 0]) + _body
    
  def literalBlock(_head, _body, lastInBank):
    return _head + _body
    
  if oldf:
    diff = diffFrames(oldf, nextf)
    if len(diff) + 8*4 >= (HBLK_BYTES + VBLK_BYTES) * 4:
      compress = False
      data = nextf
    else:
      compress = True
      data = diff
  else:
    compress = False
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
      yield functools.partial(compressedBlock, framehead, body)
      
      prev_slice_end += cur_slice_len
      framehead = bytes()
      
  else:
    # literal frame
    prev_slice_end = 0
    for cur_slice_len in [HBLK_BYTES, VBLK_BYTES] * 4:
      body = data[prev_slice_end : prev_slice_end+cur_slice_len]
      yield functools.partial(literalBlock, framehead, body)
      
      prev_slice_end += cur_slice_len
      framehead = bytes()

  
def generateBlocks(inputimgs):
  global HBLK_PACKETS, VBLK_PACKETS
    
  def stopBlock(lastInBank):
    return bytes([1, 0, 0, 0])
    
  metaframes = [None, None]
  metaframes += inputimgs
  
  for i, oldmf, thismf in zip(itertools.count(0, 2), metaframes[0:], metaframes[2:]):
    for block in generateBlocksForMetaframe(oldmf, thismf):
      yield block, i

  yield stopBlock, i


def encode(inputimgs, outputfn):
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
  for blockf, i, nextblocksize in lookahead(generateBlocks(inputimgs)):
    vprint("\033[1G\033[KOutputting frame %d @ %d:%04X" % \
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
  
  
def _processOnePair(fn1, fn2):
  image1 = prepareImage(fn1)
  image2 = prepareImage(fn2)
  return encodeImagePair(image1, image2)
    
def readImages(imagefns):
  from multiprocessing import Pool
  
  imagefnpairs = list(zip(imagefns[0::2], imagefns[1::2]))
  # duplicate the last image twice because when the video stops the player will 
  # freeze before switching to the last metaframe
  imagefnpairs.append((imagefns[-1], imagefns[-1]))
  
  p = Pool()
  return p.starmap(_processOnePair, imagefnpairs)


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
                      choices=['no', 'fit-horizontal', 'fit-vertical', 'auto'],
                      default='auto', help="specifies if and how to scale each " +
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
  ASPECT = options.aspect
  WIDTH = options.width
  HEIGHT = options.height
  VBLK_BYTES = options.vblkbytes
  HBLK_BYTES = ((WIDTH // 8) * ((HEIGHT // 2) // 8)) * 16 // 4 - VBLK_BYTES
  
  if len(options.files) == 1:
    allfiles = scanFiles(options.files[0])
  else:
    allfiles = options.files
  vprint('Reading images...')
  encimages = readImages(allfiles)
  
  encode(encimages, options.outputfn)
  

if __name__ == "__main__":
    main()
