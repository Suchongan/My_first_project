//-----------------------------------------------------------------------------
// Independent golden reference model for JRP_func3.
//
// JRP_func3 is a piecewise-linear (segment + slope + fine-interpolation)
// expansion curve: 3-stage synchronous-enable ("freeze") pipeline, gated
// uniformly by pipe_en. The 12-bit input splits into three nibbles:
//   a = min(dat_in[11:8], 14)   -- segment / exponent (clamped to 14)
//   b = dat_in[7:4]             -- selects a base value (table1) and a
//                                  slope (table2)
//   c = dat_in[3:0]             -- fine position inside the segment
// Result = (1<<a) + ((table1[b] + table2[b]*c) >> (14 - a)) - 1.
//
// Independence from the RTL:
//   * The RTL derives the one-hot (1<<a) with an explicit 16-way `case`
//     that literally writes out each one-hot pattern; this model instead
//     computes `1 << a` arithmetically, so a single wrong bit in the RTL's
//     hand-written one-hot table would surface as a mismatch here rather
//     than being reproduced verbatim.
//   * The RTL builds table1/table2 as long nested ternary chains keyed on
//     b; this model indexes them as flat `case` lookups, so a mis-ordered
//     or mis-keyed branch in the chain is not silently duplicated.
//   * The `a` clamp, the >>(14-a) scaling and the final -1 are re-derived
//     with plain integer arithmetic rather than the RTL's sized-vector
//     slices.
// The LUT constants themselves are treated as design spec (data, not
// implementation logic) and reused verbatim.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
package jrp_func3_ref_pkg;

  function automatic int table1_lut(int b);
    unique case (b)
      0  : table1_lut = 0;
      1  : table1_lut = 725;
      2  : table1_lut = 1482;
      3  : table1_lut = 2273;
      4  : table1_lut = 3099;
      5  : table1_lut = 3962;
      6  : table1_lut = 4863;
      7  : table1_lut = 5804;
      8  : table1_lut = 6786;
      9  : table1_lut = 7812;
      10 : table1_lut = 8883;
      11 : table1_lut = 10002;
      12 : table1_lut = 11170;
      13 : table1_lut = 12390;
      14 : table1_lut = 13664;
      default: table1_lut = 14994;   // b == 15
    endcase
  endfunction

  function automatic int table2_lut(int b);
    unique case (b)
      0  : table2_lut = 45;
      1  : table2_lut = 47;
      2  : table2_lut = 49;
      3  : table2_lut = 51;
      4  : table2_lut = 53;
      5  : table2_lut = 56;
      6  : table2_lut = 58;
      7  : table2_lut = 61;
      8  : table2_lut = 64;
      9  : table2_lut = 66;
      10 : table2_lut = 69;
      11 : table2_lut = 73;
      12 : table2_lut = 76;
      13 : table2_lut = 79;
      14 : table2_lut = 83;
      default: table2_lut = 86;      // b == 15
    endcase
  endfunction

  function automatic logic [16:0] jrp_func3_model(input logic [11:0] dat_in);
    int raw_a, a_val, b_val, c_val;
    int t1, t2, mtp, t1t2c;
    int shifta, diff, shifted, out_t0, out_t1;

    raw_a = int'(dat_in[11:8]);
    a_val = (raw_a > 14) ? 14 : raw_a;      // clamp, independent of RTL slice
    b_val = int'(dat_in[7:4]);
    c_val = int'(dat_in[3:0]);

    t1  = table1_lut(b_val);
    t2  = table2_lut(b_val);
    mtp = t2 * c_val;                        // 7x4 multiply
    t1t2c = t1 + mtp;

    shifta  = 1 << a_val;                     // arithmetic, not a one-hot LUT
    diff    = 14 - a_val;
    shifted = t1t2c >> diff;

    out_t0 = shifta + shifted;
    out_t1 = out_t0 - 1;

    return out_t1[16:0];                      // final 17-bit truncation
  endfunction

endpackage
