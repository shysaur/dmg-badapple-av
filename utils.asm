

        INCLUDE "utils.inc"
        
        
        SECTION "utils", ROM0



Copy:   inc c
        dec c                   ;Test low byte of the size
        jr z,.copyb             ;If it's zero, decrement the high byte and copy 256 bytes
.copyl: ld a,[hl+]
        ld [de],a
        inc de                  ;Copy one byte
        dec c
        jr nz,.copyl            ;Continue copying until low byte is zero
.copyb: dec b                   ;Decrement high byte
        bit 7,b
        jr z,.copyl             ;If it did not overflow continue copying
        ret                     ;Otherwise return
        
        
        
        ;HL = end source address 
        ;DE = end destination address
ReverseCopy:
        dec hl
        inc c
        dec c                   ;Test low byte of the size
        jr z,.copyb             ;If it's zero, decrement the high byte and copy 256 bytes
.copyl: dec de
        ld a,[hl-]
        ld [de],a               ;Copy one byte
        dec c
        jr nz,.copyl            ;Continue copying until low byte is zero
.copyb: dec b                   ;Decrement high byte
        bit 7,b
        jr z,.copyl             ;If it did not overflow continue copying
        ret                     ;Otherwise return
        
        
        
        ;C=rect w
        ;B=rect h
        ;HL=src
        ;DE=dest in VRAM
RectCopy:
.lb:    push de
        push bc
.wloop: ld a,[hl+]
        ld [de],a
        inc e
        dec c
        jr nz,.wloop
        pop bc
        pop de
        
        ld a,e
        add $20
        ld e,a
        jr nc,.noc
        inc d
.noc:   dec b
        jr nz,.lb
        ret
        
        
        ;C=rect w
        ;B=rect h
        ;HL=dest in VRAM
        ;E=fill byte
RectFill:
.wlh:   push bc
        push hl
        ld a,e
.wloop: ld [hl+],a
        dec c
        jr nz,.wloop
        pop hl
        pop bc
        
        ld a,l
        add $20
        ld l,a
        jr nc,.noc
        inc h
.noc:   dec b
        jr nz,.wlh
        ret
        
        
        ;C=rect w
        ;B=rect h
        ;HL=dest in VRAM
        ;E=fill start byte
        ;Layout:  0  1  2 ..
        ;        10 11 12 ..
        ;        20 22 23 ..
        ;        .. .. .. 
MakePictureRectangle1:
.wlh:   push bc
        push hl
        ld a,e
.wloop: ld [hl+],a
        inc a
        dec c
        jr nz,.wloop
        pop hl
        pop bc
        
        add $10
        and $F0
        ld e,a
        
        ld a,l
        add $20
        ld l,a
        jr nc,.noc
        inc h
.noc:   dec b
        jr nz,.wlh
        ret
        
        
        ;C=rect w
        ;B=rect h
        ;HL=dest in VRAM
        ;E=fill start byte
        ;Layout:  0  1  2
        ;         3  4  5
        ;         6  7  8 ...
MakePictureRectangle2:
.wlh:   push bc
        push hl
        ld a,e
.wloop: ld [hl+],a
        inc a
        dec c
        jr nz,.wloop
        pop hl
        pop bc
        ld e,a
        
        ld a,l
        add $20
        ld l,a
        jr nc,.noc
        inc h
.noc:   dec b
        jr nz,.wlh
        ret
        
        
        
        
        ;C=rect w
        ;B=rect h
        ;HL=dest in VRAM
        ;E=fill start byte
        ;Layout:  0  3  6 
        ;         1  4  7
        ;         2  5  8
        ;               ..
MakePictureRectangle3:
        ld d,b
.wlh:   push bc
        push hl
        ld a,e
.wloop: ld [hl+],a
        add b
        dec c
        jr nz,.wloop
        pop hl
        pop bc
        inc e
        
        ld a,l
        add $20
        ld l,a
        jr nc,.noc
        inc h
.noc:   dec d
        jr nz,.wlh
        ret
        
        
        
Fill:   inc c
        dec c
        jr z,.fillb
.filll: ld [hl+],a
        dec c
        jr nz,.filll
.fillb: dec b
        bit 7,b
        jr z,.filll
        ret
        

    
ColumnFill:    
        ld [hl],a
        add hl,de
        dec c
        jr nz,ColumnFill
        ret
        
        