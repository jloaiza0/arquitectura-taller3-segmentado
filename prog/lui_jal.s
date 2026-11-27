# =============================================================================
# lui_jal.s - Instrucciones que escriben en rd algo que NO paso por la ALU
# (lui, jal, jalr) o que la ALU calcula con el PC (auipc), seguidas de un uso
# a distancia 1 y 2.
#
# Si EX/MEM solo lleva el resultado de la ALU, se adelanta basura.
#
# Estado esperado (las direcciones son las de este programa):
#   x1 = 0x12345000   x2 = 0x12345678   x3 = 0xABCDE000   x4 = 0xABCDE000
#   x5 = 0x14 (PC+4 del jal en 0x10)    x6 = 0x14
#   x7 = 0x18 (auipc en 0x18)           x8 = 0x1C
#   x9 = 0x28 (PC+4 del jalr en 0x24)   x10 = 0x28
# =============================================================================
    lui   x1, 0x12345       # 0x00  x1 = 0x12345000
    addi  x2, x1, 0x678     # 0x04  distancia 1 desde lui: 0x12345678
    lui   x3, 0xABCDE       # 0x08  x3 = 0xABCDE000
    add   x4, x0, x3        # 0x0C  distancia 1 por B: 0xABCDE000
    jal   x5, sig           # 0x10  x5 = 0x14
sig:
    addi  x6, x5, 0         # 0x14  distancia 1 desde jal: 0x14
    auipc x7, 0             # 0x18  x7 = 0x18
    addi  x8, x7, 4         # 0x1C  distancia 1 desde auipc: 0x1C
    addi  x11, x0, 0x2C     # 0x20  direccion de "ret_aqui"
    jalr  x9, 0(x11)        # 0x24  x9 = 0x28, salta a 0x2C
    addi  x20, x0, 99       # 0x28  ranura: no debe ejecutarse
ret_aqui:
    addi  x10, x9, 0        # 0x2C  distancia 1 desde jalr: 0x28
    nop
    nop
fin:
    beq   x0, x0, fin
