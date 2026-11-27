# =============================================================================
# doble.s - Doble hazard: dos escrituras seguidas al mismo registro y una
# lectura. Debe ganar EX/MEM (la mas reciente). Se prueba por A y por B.
#
# Estado esperado:
#   x5 = 70  x6 = 71  x7 = 70  x8 = 71
# Con la prioridad invertida saldria x6 = 4 y x8 = 4: plausible y equivocado.
# =============================================================================
    addi  x1, x0, 1
    addi  x2, x0, 2
    addi  x3, x0, 30
    addi  x4, x0, 40
    add   x5, x1, x2        # x5 = 3
    add   x5, x3, x4        # x5 = 70   (vuelve a escribir x5)
    add   x6, x5, x1        # lee x5 por A: 71
    add   x7, x1, x2        # x7 = 3
    add   x7, x3, x4        # x7 = 70
    add   x8, x1, x7        # lee x7 por B: 71
    nop
    nop
fin:
    beq   x0, x0, fin
