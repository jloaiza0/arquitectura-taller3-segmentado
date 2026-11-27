# =============================================================================
# acumulador.s - lw seguido de uso dentro de un bucle con acumulador.
#
# Si se para sin meter burbuja, el add se ejecuta dos veces por vuelta: la
# primera con la DIRECCION del lw adelantada desde EX/MEM y la segunda con el
# dato. Por eso el dato vive en la direccion 16 y no en la 0: con direccion 0
# la ejecucion repetida sumaria cero y el defecto quedaria invisible (es lo
# que paso en la primera version de este programa).
#
# Estado esperado:
#   x1 = 5   x2 = 15 (3 vueltas de +5)   x3 = 0   x4 = 5
#   x5 = 3 (una vez por vuelta)          Mem[4] = 5   Mem[5] = 15
# =============================================================================
    addi  x1, x0, 5
    sw    x1, 16(x0)        # Mem[4] (dir 16) = 5
    addi  x2, x0, 0         # acumulador
    addi  x3, x0, 3         # contador
    addi  x5, x0, 0
bucle:
    lw    x4, 16(x0)
    add   x2, x2, x4        # load-use con acumulador
    addi  x5, x5, 1         # otro acumulador
    addi  x3, x3, -1
    bne   x3, x0, bucle     # tomado 2 veces
    sw    x2, 20(x0)        # Mem[5] (dir 20) = 15
    nop
    nop
fin:
    beq   x0, x0, fin
