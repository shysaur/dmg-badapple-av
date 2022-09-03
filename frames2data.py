#!/usr/bin/env python3

from PIL import Image, ImageOps
from array import array
from argparse import ArgumentParser
import sys
import os.path
import itertools


VERBOSE = False
ASPECT = 'auto'
WIDTH = 160
HEIGHT = 144
HBLK_BYTES = 576
VBLK_BYTES = 144

HBLK_PACKETS = [144] * 4
VBLK_PACKETS = [12, 12, 12, 10]


def vprint(*args, **kwargs):
  if VERBOSE == True: print(*args, file=sys.stderr, **kwargs)
  
  
def prepareImage(opts, filename):
  image = Image.open(filename).convert("L")
  if opts.aspect != 'no':
    # auto chooses the fit that fills the whole screen
    bestfit_is_vert = (image.width / image.height * opts.height) >= opts.width
    
    if opts.aspect == 'fit-vertical' or (opts.aspect == 'auto' and bestfit_is_vert):
      destw = opts.width * image.height // opts.height
      desth = image.height
    elif opts.aspect == 'fit-horizontal' or (opts.aspect == 'auto' and not bestfit_is_vert):
      destw = image.width
      desth = opts.height * image.width // opts.width
      
    tmp = Image.new("L", (destw, desth))
    tmp.paste(image, ((destw - image.width) // 2, (desth - image.height) // 2))
    image = tmp
  
  image = image.resize((opts.width, opts.height//2), Image.BILINEAR)
  image = image.point(lambda p: 255 if p > 180 else 0)
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
  
  last = bytearray()
  res = bytearray()
  lastskip = 0
  i = 0
  while i < len(new):
    if old[i] == new[i] and lastskip < 255:
      lastskip += 1
      i += 1
    else:
      last += bytes([lastskip])
      last += new[i:i+3]
      last += bytes([0] * ((4 - (len(last) % 4)) % 4))
      lastskip = 0
      if old[i:i+3] != new[i:i+3]:
        res += last
        last = bytearray()
      i += 3
  return res
  
  
class Block:
  def __init__(self, body):
    self.body = bytes(body)
    self.compressed = None
    self.image = None
    
  def __len__(self):
    return len(self(0, 99))
    
  def __call__(self, posInBank, bankLength):
    return self.body
    
  def __repr__(self):
    return '<' + type(self).__name__ + ', len=' + str(len(self)) + '>'
  
  
class CompressedBlock(Block):
  def __init__(self, body, hasHead):
    super().__init__(body)
    self.hasHead = hasHead
    self.compressed = True
    
  def __call__(self, posInBank, bankLength):
    mfhead = bytes([0, 0x18, 0, 0]) if self.hasHead else bytes()
    bhead = bytes([len(self.body)//4, (1 if posInBank == bankLength-1 else 0), 0, 0])
    return mfhead + bhead + self.body
         
             
class LiteralBlock(Block):
  def __init__(self, body, hasHead):
    super().__init__(body)
    self.hasHead = hasHead
    self.compressed = False
    
  def __call__(self, posInBank, bankLength):
    mfhead = bytes([0, 0x3E, (1 if posInBank == bankLength-8 else 0), 0]) \
             if self.hasHead else bytes()
    return mfhead + self.body
      
  
def generateBlocksForMetaframe(opts, oldf, nextf):
  res = []
  
  if oldf:
    diff = diffFrames(oldf, nextf)
    if len(diff) + 8*4 >= (opts.hblkbytes + opts.vblkbytes) * 4 or len(diff)//4 > sum(HBLK_PACKETS+VBLK_PACKETS):
      compress = False
      data = nextf
    else:
      compress = True
      data = diff
  else:
    compress = False
    data = nextf
  
  if compress:    # compressed frame
    # redistribute the dead time across the entirety of the frame
    npackets = len(data)//4
    #hblpackets = min(npackets, sum(HBLK_PACKETS))
    #vblpackets = npackets - hblpackets
    vblpackets = min(npackets, sum(VBLK_PACKETS))
    hblpackets = npackets - vblpackets
    
    vbl_left, hbl_left, chk_numpackets = vblpackets, hblpackets, 0
    blocksizes = []
    for hbllimit, vbllimit in zip(HBLK_PACKETS, VBLK_PACKETS):
      hbl = int(hblpackets * hbllimit / sum(HBLK_PACKETS))
      vbl = int(vblpackets * vbllimit / sum(VBLK_PACKETS))
      blocksizes += [hbl*4, vbl*4]
      hbl_left -= hbl
      vbl_left -= vbl
      chk_numpackets += hbl + vbl
    while hbl_left > 0 or vbl_left > 0:
      olda, oldb = hbl_left, vbl_left
      for k, hbllimit, vbllimit in zip(range(4), HBLK_PACKETS, VBLK_PACKETS):
        prev_hbl, prev_vbl = blocksizes[k*2]//4, blocksizes[k*2+1]//4
        hbl, vbl = min(1, hbl_left, hbllimit-prev_hbl), min(1, vbl_left, vbllimit-prev_vbl)
        blocksizes[k*2] += hbl*4
        blocksizes[k*2+1] += vbl*4
        hbl_left -= hbl
        vbl_left -= vbl
        chk_numpackets += hbl + vbl
      assert olda > hbl_left or hbl_left == 0
      assert oldb > vbl_left or vbl_left == 0
    
    if chk_numpackets != npackets:
      print("ALLOCATION ERROR", vblpackets, hblpackets, npackets, chk_numpackets, blocksizes)
    assert chk_numpackets == npackets
    
    prev_slice_end = 0
    for cur_slice_len, i in zip(blocksizes, itertools.count()):
      if prev_slice_end + cur_slice_len >= len(data):
        cur_slice_len = len(data) - prev_slice_end
      
      body = data[prev_slice_end : prev_slice_end+cur_slice_len]
      res.append(CompressedBlock(body, i == 0))
      
      prev_slice_end += cur_slice_len
      
  else:     # literal frame
    prev_slice_end = 0
    for cur_slice_len in [opts.hblkbytes, opts.vblkbytes] * 4:
      body = data[prev_slice_end:]
      if len(body) < cur_slice_len:
        body += bytes([0] * (cur_slice_len - len(body)))
      else:
        body = body[0:cur_slice_len]
      res.append(LiteralBlock(body, prev_slice_end == 0))
      prev_slice_end += cur_slice_len
  
  return res

  
def generateBlocks(opts, inputimgs):
  from multiprocessing import Pool
  
  metaframes = [None, None]
  metaframes += inputimgs
  
  imgpairs = [(opts, a, b) for a, b in zip(metaframes[0:], metaframes[2:])]
  p = Pool()
  encimgs = p.starmap(generateBlocksForMetaframe, imgpairs)
  
  for i, blocks in zip(itertools.count(0, 2), encimgs):
    for block in blocks:
      block.image = i
      yield block

  yield Block([1, 0, 0, 0])


def encode(opts, inputimgs, outputfn):
  vprint('Data generation...')

  overhead = 0
  
  banks = []
  curBank, curBankSize = [], 0
  for block, i in zip(generateBlocks(opts, inputimgs), itertools.count()):
    
    if len(block) + curBankSize > 0x4000:
      overhead += 0x4000 - curBankSize
      curBank.append(Block([0] * (0x4000 - curBankSize)))
      banks.append(curBank)
      curBank, curBankSize = [], 0
      
    curBankSize += len(block)
    curBank.append(block)
    
  curBank.append(Block([0] * (0x4000 - curBankSize)))
  banks.append(curBank)
    
  vprint("Allocated", i, "blocks in", len(banks), "banks for", len(inputimgs), "metaframes")
  n_compressed = sum([1 if block.compressed else 0 for bank in banks for block in bank])
  c_ratio = 1.0 - sum([len(block) if block.image else 0 for bank in banks for block in bank]) / (len(inputimgs) * (opts.hblkbytes + opts.vblkbytes) * 4)
  vprint("Compressed", n_compressed, 'blocks (global compression ratio', c_ratio * 100, '%)')
  vprint("Bankswitch overhead", overhead, 'B')
  
  if outputfn != None:
    fpo = open(outputfn, 'wb')
  else:
    fpo = sys.stdout.buffer
  
  for bank in banks:
    c = len(bank) - 1   # do not count the final padding block
    for block, i in zip(bank, itertools.count()):
      fpo.write(block(i, c))
  return len(banks)
      
    
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
  
  
def _processOnePair(opts, fn1, fn2):
  image1 = prepareImage(opts, fn1)
  image2 = prepareImage(opts, fn2)
  return encodeImagePair(image1, image2)
    
def readImages(opts, imagefns):
  from multiprocessing import Pool

  imagefnpairs = list([(opts, b, c) for b, c in zip(imagefns[0::2], imagefns[1::2])])
  # duplicate the last image twice because when the video stops the player will
  # freeze before switching to the last metaframe
  imagefnpairs.append((opts, imagefns[-1], imagefns[-1]))
  
  p = Pool()
  return p.starmap(_processOnePair, imagefnpairs)
  
  
def adjustTimebase(imagefns, timebase):
  i = 0
  accum = 0.0
  res = []
  while i < len(imagefns):
    res.append(imagefns[i])
    accum += timebase
    if accum >= 1.0:
      i += int(accum)
      accum = accum % 1
  return res


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
  #parser.add_argument("-x", "--width", dest="width", type=int,
  #                    default=160, help="the encoded video's width")
  #parser.add_argument("-y", "--height", dest="height", type=int,
  #                    default=144, help="the encoded video's height")
  #parser.add_argument("-i", "--vblk-bytes", dest="vblkbytes", type=int,
  #                    default=144, help="the amount of video bytes " +
  #                    "copied in vblank")
  parser.add_argument("-k", "--config", dest="config", choices=['0', '1', '2'], default='0', help="configuration")
  parser.add_argument("-c", "--timebase", dest="timebase", type=float,
                      default=1.0, help="the relative speed of the output " +
                      "(> 1 skips frames, < 1 duplicates frames)")
  parser.add_argument('-d', '--include', dest='include', default=None,
                      help='write number of banks to FILE', metavar='FILE')
  opts = parser.parse_args()
  
  VERBOSE = opts.verbose
  #ASPECT = options.aspect
  #WIDTH = options.width
  #HEIGHT = options.height
  #VBLK_BYTES = options.vblkbytes
  #HBLK_BYTES = ((WIDTH // 8) * ((HEIGHT // 2) // 8)) * 16 // 4 - VBLK_BYTES
  hsize = 20
  if opts.config == '0':
    vsize = 9
    bytesPerHline = 5
  elif opts.config == '1':
    vsize = 8
    bytesPerHline = 5
  else:
    vsize = 7
    bytesPerHline = 4
  opts.width = hsize * 8
  opts.height = vsize * 16
  opts.hblkbytes = 144 * bytesPerHline
  opts.vblkbytes = max(0, ((hsize * vsize) * 16 // 4) - opts.hblkbytes)
  opts.hblkpadding = max(0, opts.hblkbytes * 4 - (hsize * vsize) * 16)
  print("width =", opts.width)
  print("height =", opts.height)
  print("hblkbytes =", opts.hblkbytes)
  print("vblkbytes =", opts.vblkbytes)
  print("hblkpadding =", opts.hblkpadding)
  
  if len(opts.files) == 1:
    allfiles = scanFiles(opts.files[0])
  else:
    allfiles = opts.files
  allfiles = adjustTimebase(allfiles, opts.timebase)
  vprint('Adjusted timebase to ', len(allfiles), ' frames')
  vprint('Reading images...')
  encimages = readImages(opts, allfiles)
  
  n_banks = encode(opts, encimages, opts.outputfn)
  if opts.include:
    with open(opts.include, "w") as f:
      f.write('DEF NUM_VIDEO_BANKS = ' + str(n_banks) + '\n')
  

if __name__ == "__main__":
    main()
