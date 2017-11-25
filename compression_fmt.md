# Compression Format

FrameHead := Stop + Compressed + `00 00`

Stop := `00` | `01`

Compressed := `00` | `01`

BlockHead := NumPackets + BankInc + `00 00`

Packet := Skip + Data

Skip := `xx` (# of bytes to skip before write)

Data := `xx xx xx` (data to write after skip)

Block := BlockHead + Packet ^ NumPackets

MetaFrame := FrameHead + Block * 8 (compressed == 1) | FrameHead + Data (compressed == 0)

## Limits

NumPackets max = 36 for vblank, 144 for hblank

Bankswitches are allowed only between blocks.