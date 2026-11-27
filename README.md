# Taller 3 — Procesador RV32I segmentado

Arquitectura de Computadores · UTP · Juan Pablo Loaiza Bedoya, Javier Parra Gonzales y Estiven Muñoz Montoya

El procesador monociclo del Taller 2 cortado en cinco etapas (IF, ID, EX, MEM, WB), con
unidad de forwarding (en EX) y unidad de detección de riesgos (en ID). Los módulos del
Taller 2 se reutilizan sin cambios.

## Archivos nuevos

| Archivo | Qué es |
|---|---|
| `rtl/pipe_reg.sv` | registro de segmentación parametrizable: `en`, `clr` y `rst` síncronos |
| `rtl/forwarding_unit.sv` | `ForwardAE` / `ForwardBE` (00 banco, 10 EX/MEM, 01 MEM/WB) |
| `rtl/hazard_unit.sv` | load-use (`StallF`, `StallD`, `FlushE`) y salto tomado (`FlushD`, `FlushE`) |
| `rtl/riscv_segmentado.sv` | los cuatro registros de segmentación y el cableado completo |
| `tb/tb_unidades.sv` | las tres piezas por separado, contra las tablas de las secciones 6 y 12 |
| `tb/tb_pipeline.sv` | 11 programas en el segmentado y en el monociclo; estado final idéntico y ciclos |
| `tb/tb_traza.sv` | (opcional) imprime en qué etapa está cada instrucción, ciclo a ciclo |
| `prog/*.s` | 8 programas dirigidos (sección 19) + los 3 del Taller 2 |
| `INFORME.txt` | el informe corto que pide la guía |

## Cómo correrlo

```
make              # los 7 testbenches
make unidades     # pipe_reg, forwarding_unit, hazard_unit
make pipeline     # los 11 programas y la tabla de ciclos
```

Requiere Icarus Verilog (`iverilog -g2012`) y Python 3.

## Resultado

| Testbench | Pruebas | Errores |
|---|---|---|
| Los 5 del Taller 2 | 86 | 0 |
| tb_unidades | 78 | 0 |
| tb_pipeline | 75 | 0 |

Ver `INFORME.txt` para las situaciones probadas, los errores encontrados y la comparación de ciclos.

## Informe

`docs/taller3.pdf` (y su fuente `docs/taller3.tex`): explicacion paso a paso del taller.
