# =============================================================================
# fwd_dist.s - Dependencias a distancia 1 y 2, por el operando A y por el B
#
# Se usa sub (no add) para que el orden de los operandos importe: si A y B se
# cruzan, o si solo existe ForwardAE, el resultado cambia.
#
# Estado esperado:
#   x1 = 7   x2 = 3   x3 = 4   x4 = -1 (0xFFFFFFFF)   x5 = 4   x6 = 1
#   x7 = -1  x8 = -1
# =============================================================================
    addi  x1, x0, 7         # x1 = 7
    addi  x2, x0, 3         # x2 = 3
    sub   x3, x1, x2        # A a distancia 2 (x1), B a distancia 1 (x2): 4
    sub   x4, x2, x3        # A a distancia 2 (x2), B a distancia 1 (x3): -1
    sub   x5, x3, x0        # A a distancia 2 (x3): 4
    sub   x6, x0, x4        # B a distancia 2 (x4): 1
    sub   x7, x0, x6        # B a distancia 1 (x6): -1
    add   x8, x7, x0        # A a distancia 1 (x7): -1
    nop
    nop
fin:
    beq   x0, x0, fin
