# =============================================================================
# salto.s - Saltos tomados con instrucciones detras que escriben algo visible
# (registros y memoria). Si falta FlushD o FlushE, dejan rastro.
#
# Cubre beq, bne, blt, bge, bltu, bgeu (tomados y no tomados) y jal.
#
# Estado esperado:
#   x1 = 3  x2 = 3  x3 = 3  x4 = 7  x5 = -1  x6 = 1
#   x21 = 6 (uno por cada condicional no tomado)
#   x28 = x29 = x30 = x31 = 0       Mem[0] = Mem[1] = 0
# =============================================================================
    addi  x1, x0, 3
    addi  x2, x0, 3
    add   x3, x1, x0
    beq   x3, x2, destino   # tomado (con forwarding de x3 a distancia 1)
    addi  x30, x0, 99       # ranura 1: no debe dejar rastro
    sw    x1, 0(x0)         # ranura 2: no debe escribir memoria
destino:
    addi  x4, x0, 7
    jal   x0, sig           # salto incondicional: tambien vacia dos ranuras
    addi  x31, x0, 99
    sw    x1, 4(x0)
sig:
    addi  x5, x0, -1
    addi  x6, x0, 1
    # --- Los seis condicionales, tomados: cada ranura escribiria x28/x29 ---
    bne   x5, x6, t1
    addi  x28, x0, 1
    addi  x29, x0, 1
t1: blt   x5, x6, t2        # -1 < 1 con signo
    addi  x28, x0, 2
    addi  x29, x0, 2
t2: bge   x6, x5, t3        # 1 >= -1 con signo
    addi  x28, x0, 3
    addi  x29, x0, 3
t3: bltu  x6, x5, t4        # 1 < 0xFFFFFFFF sin signo
    addi  x28, x0, 4
    addi  x29, x0, 4
t4: bgeu  x5, x6, t5        # 0xFFFFFFFF >= 1 sin signo
    addi  x28, x0, 5
    addi  x29, x0, 5
t5:
    # --- Los seis, NO tomados: cada uno suma 1 a x21 ---
    beq   x5, x6, mal
    addi  x21, x21, 1
    bne   x1, x2, mal
    addi  x21, x21, 1
    blt   x6, x5, mal
    addi  x21, x21, 1
    bge   x5, x6, mal
    addi  x21, x21, 1
    bltu  x5, x6, mal
    addi  x21, x21, 1
    bgeu  x6, x5, mal
    addi  x21, x21, 1
    nop
    nop
fin:
    beq   x0, x0, fin
mal:
    addi  x31, x0, 66
    beq   x0, x0, fin
