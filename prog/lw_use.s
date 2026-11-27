# =============================================================================
# lw_use.s - load-use por rs1 y por rs2, un load con una instruccion
# independiente antes del uso (distancia 2: no debe parar) y un load -> store.
#
# Los datos viven en direcciones distintas de su valor (21 en la 16, 4 en la
# 20): asi un uso que reciba la direccion en vez del dato se nota.
#
# Paradas esperadas: exactamente 3 (rs1, rs2 y el lw -> sw).
#
# Estado esperado:
#   x1 = 21  x2 = 4  x3 = 21  x4 = 21  x5 = 4  x6 = 4  x7 = 21  x8 = 42
#   x9 = 1   x12 = 21
#   Mem[4] = 21   Mem[5] = 4   Mem[6] = 21
# =============================================================================
    addi  x1, x0, 21
    sw    x1, 16(x0)        # store a distancia 1 del addi: el dato se adelanta
    addi  x2, x0, 4
    sw    x2, 20(x0)
    lw    x3, 16(x0)
    add   x4, x3, x0        # load-use por rs1: x4 = 21   (1 parada)
    lw    x5, 20(x0)
    add   x6, x0, x5        # load-use por rs2: x6 = 4    (1 parada)
    lw    x7, 16(x0)
    addi  x9, x0, 1         # independiente
    add   x8, x7, x7        # distancia 2: sin parada, x8 = 42
    lw    x12, 16(x0)
    sw    x12, 24(x0)       # load -> store: el dato del sw depende del lw (1 parada)
    nop
    nop
fin:
    beq   x0, x0, fin
