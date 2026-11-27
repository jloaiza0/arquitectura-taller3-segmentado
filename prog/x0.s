# =============================================================================
# x0.s - Instrucciones que escriben en x0 seguidas de lecturas de x0
#
# Sin la condicion rs != 0, el resultado tirado a x0 se adelanta y x0 deja de
# valer cero.
#
# Estado esperado:
#   x0 = 0   x1 = 5   x2 = 5   x3 = 1   x4 = 5
# =============================================================================
    addi  x1, x0, 5         # x1 = 5
    addi  x0, x0, 77        # escribe en x0: se tira
    add   x2, x0, x1        # x0 por A a distancia 1: x2 = 5 (mal: 82)
    addi  x0, x1, 9         # otra escritura a x0 (14)
    addi  x3, x0, 1         # x0 por A a distancia 1: x3 = 1 (mal: 15)
    add   x4, x1, x0        # x0 por B a distancia 2: x4 = 5 (mal: 19)
    nop
    nop
fin:
    beq   x0, x0, fin
