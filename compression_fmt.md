# Compression Format

FrameHead := Stop + Compressed + UncBankInc `00`

Stop := `00` | `01`

Compressed := `3E` | `18`

BlockHead := NumPackets + BankInc + `00 00`

Packet := Skip + Data

Skip := `xx` (# of bytes to skip before write)

Data := `xx xx xx` (data to write after skip)

Block := BlockHead + Packet ^ NumPackets

MetaFrame := FrameHead + Block * 8 (compressed == 1) | FrameHead + Data (compressed == 0)

## Limits

NumPackets max = 36 for vblank, 144 for hblank

Bankswitches are allowed only between blocks.

Compressed is `3E` when the data is NOT compressed, and `18` when it IS compressed.

If the frame is uncompressed, UncBankInc is `01` if at the end of the frame
a bankswitch occurs; otherwise it is zero. If the frame is compressed, UncBankInc
is ignored.
