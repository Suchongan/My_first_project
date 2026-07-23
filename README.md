# Verilog Verification Environment

Self-checking SystemVerilog testbenches, simulated with
[Verilator](https://www.veripool.org/verilator/). Each DUT gets its own
independently-derived golden reference model and a freeze-pipeline-aware
scoreboard, so bugs in the RTL's implementation (not just its intent)
surface as mismatches.

## DUTs

### `LSC_Func1` (`rtl/LSC_Func1.v`)

A 4-stage, synchronous-enable ("freeze") pipeline that computes a
fixed-point piecewise-linear approximation of `log2(dat_in + 1)`, scaled
by 2^11:

```
dat_out ≈ a_tmp * 2048 + interpolated_fraction(dat_in)
```

Every internal register is gated by `pipe_en & RS_LSC_EnH_FB`; when low,
the whole pipeline holds. Latency from a sampled input to `dat_out` is 4
clock edges.

### `JRP_CONV` (`rtl/JRP_CONV.v`)

A 3-stage, synchronous-enable pipeline over a 5x5 pixel window that
computes four diagonal corner-response magnitudes (`CR1..CR4`, 2-cycle
latency) and a set of gradient/local-structure outputs (`Gx`, `Gy`,
`Gx_abs`, `Gy_abs`, `C1`, `Ls0..Ls8`, 3-cycle latency). All registers are
gated by a single `pipe_en`. `Pxd_window_5x5_pipe1`/`pipe2` are expected
to be externally pre-delayed copies of `Pxd_window_5x5_pipe0` (by 1 and 2
*enabled* clocks), since the design re-reads raw pixels from those buses
at later pipeline stages instead of carrying the full 250-bit window
through internal registers.

## Directory layout

```
rtl/LSC_Func1.v            DUT 1
rtl/JRP_CONV.v              DUT 2
tb/lsc_func1_ref_pkg.sv     Independent golden reference model for LSC_Func1
tb/lsc_func1_tb.sv          Testbench: stimulus, scoreboard, reset/freeze tests
tb/jrp_conv_ref_pkg.sv      Independent golden reference model for JRP_CONV
tb/jrp_conv_tb.sv           Testbench: stimulus, scoreboard, reset/freeze tests
tb/Makefile                 Verilator build/run/wave targets for both
```

## Verification approach

- **Reference models**: re-derive the same arithmetic result as each DUT,
  but implemented independently (variable shifts/masks/array indexing
  instead of the RTL's per-index `case` statements or individually named
  wires), so a bug in a single RTL branch or a mis-wired signal surfaces
  as a mismatch rather than being silently mirrored. Lookup-table
  coefficients are reused where they represent design constants, not
  implementation logic.
- **Scoreboards**: a shadow shift register in each testbench, gated by
  the identical enable condition as the DUT, reproducing its exact
  freeze/latency behavior without separate pipeline-fill or bubble
  tracking. `JRP_CONV`'s scoreboard taps the shadow pipeline at two
  different depths (1 and 2 shifts) since `CR1..CR4` and the
  gradient/`Ls` outputs have different latencies.
- **Stimulus**: directed corner cases (bit-index/window boundary values,
  saturation, flat/impulse/checkerboard/ramp windows), directed
  freeze/enable-gating and mid-stream reset scenarios, followed by
  thousands of constrained-random cycles.

Both environments were validated with a mutation test: deliberately
injecting a one-line bug into the DUT (a wrong LUT constant, a swapped
pixel wire) causes the corresponding testbench to report hundreds of
mismatches — and only in the outputs that actually depend on the mutated
logic — confirming the scoreboards check real values rather than
trivially passing.

## Running

Requires Verilator (tested with 5.020) and, for waveform viewing, GTKWave.

```sh
cd tb
make run-lsc    # build + simulate LSC_Func1
make run-jrp    # build + simulate JRP_CONV
make waves-lsc  # open LSC_Func1's VCD waveform in GTKWave
make waves-jrp  # open JRP_CONV's VCD waveform in GTKWave
make clean      # remove build artifacts
```

## Adapting to other DUTs

Add the Verilog file under `rtl/`, write a matching reference model and
testbench under `tb/` following the existing pair as a template, and add
a `run-<name>` target to `tb/Makefile`.
