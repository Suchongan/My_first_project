# LSC_Func1 Verification Environment

A self-checking SystemVerilog testbench for `LSC_Func1`, simulated with
[Verilator](https://www.veripool.org/verilator/).

## What is `LSC_Func1`

`LSC_Func1` (`rtl/LSC_Func1.v`) is a 4-stage, synchronous-enable ("freeze")
pipeline that computes a fixed-point piecewise-linear approximation of
`log2(dat_in + 1)`, scaled by 2^11:

```
dat_out ≈ a_tmp * 2048 + interpolated_fraction(dat_in)
```

Every internal register is gated by the same `pipe_en & RS_LSC_EnH_FB`
condition, so the pipeline advances one stage per cycle only when that
condition is high; otherwise every stage holds ("freezes") together.
Latency from a sampled input to the corresponding `dat_out` is exactly 4
clock edges.

## Directory layout

```
rtl/LSC_Func1.v          DUT
tb/lsc_func1_ref_pkg.sv  Independent golden reference model
tb/lsc_func1_tb.sv       Testbench: stimulus, scoreboard, reset/freeze tests
tb/Makefile              Verilator build/run/wave targets
```

## Verification approach

- **Reference model** (`lsc_func1_ref_pkg.sv`): re-derives the same
  arithmetic result as the DUT, but implemented independently — using
  variable shifts/masks instead of the RTL's per-index `case` statements —
  so a bug in any single RTL `case` branch (wrong bit range, off-by-one,
  wrong default) surfaces as a mismatch rather than being silently
  mirrored. It reuses `table1`/`table2` LUT contents because those are
  design constants (the intended transfer function), not implementation
  logic.
- **Scoreboard**: a 4-deep shadow shift register in the testbench, gated by
  the identical `pipe_en & RS_LSC_EnH_FB` enable as the DUT, so it
  reproduces the DUT's exact freeze/latency behavior without needing
  separate pipeline-fill or bubble-tracking logic. Every cycle, `dat_out`
  is compared against the shadow pipeline's output.
- **Stimulus**: directed corner cases (leading-bit-index boundaries at
  every power of two, min/max `dat_in`, `b_tmp` saturation), directed
  freeze/enable-gating and mid-stream reset scenarios, followed by 5000
  constrained-random cycles (random `dat_in`, `pipe_en`, `RS_LSC_EnH_FB`).

The environment was validated with a mutation test: deliberately
corrupting one `table1` LUT entry in the DUT causes the testbench to
report hundreds of mismatches, confirming the scoreboard actually checks
values rather than trivially passing.

## Running

Requires Verilator (tested with 5.020) and, for waveform viewing, GTKWave.

```sh
cd tb
make run     # build + simulate; prints PASS/FAIL summary
make waves   # open the VCD waveform in GTKWave
make clean   # remove build artifacts
```

## Adapting to other DUTs

Swap in a different Verilog file under `rtl/`, write a matching reference
model under `tb/`, and update the DUT instantiation and shadow-pipeline
depth in `tb/lsc_func1_tb.sv` to match the new design's latency and enable
structure.
