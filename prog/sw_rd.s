# =============================================================================
# sw_rd.s - Un sw (y un branch) cuyos bits 11:7 coinciden con un registro que
# se lee justo despues.
#
# "sw x10, 8(x0)" tiene instr[11:7] = 8: sin la condicion RegWrite se anuncia
# como escritura a x8 y adelanta la direccion (8) en vez del contenido de x8.
#
# Estado esperado:
#   x8 = 100   x10 = 4   x12 = 55   x11 = 100   x13 = 55   x14 = 100
#   Mem[2] (dir 8) = 4   Mem[3] (dir 12) = 4
# =============================================================================
    addi  x8,  x0, 100      # x8 = 100
    addi  x12, x0, 55       # x12 = 55
    addi  x10, x0, 4        # x10 = 4
    nop
    nop
    nop
    sw    x10, 8(x0)        # bits 11:7 = 8  -> "rd" falso x8
    add   x11, x8, x0       # x8 por A a distancia 1: 100 (mal: 8)
    sw    x10, 12(x0)       # bits 11:7 = 12 -> "rd" falso x12
    nop
    add   x13, x0, x12      # x12 por B a distancia 2: 55 (mal: 12)
    bne   x0, x0, 8         # no tomado; bits 11:7 = 8 -> "rd" falso x8
    add   x14, x0, x8       # x8 por B a distancia 1: 100 (mal: 0, el resultado del sub)
    nop
    nop
fin:
    beq   x0, x0, fin
