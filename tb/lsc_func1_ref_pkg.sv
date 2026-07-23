//-----------------------------------------------------------------------------
// Independent (non-RTL-derived) golden reference model for LSC_Func1.
//
// LSC_Func1 computes a piecewise-linear fixed-point approximation of
// log2(dat_in + 1), scaled by 2^11 (Q11 in the integer/exponent part):
//   result = a_tmp * 2048 + interpolated_fraction
// where a_tmp is (roughly) the bit position of the MSB of (dat_in+1), and
// the fractional part is refined via two lookup tables (table1 = base
// offset, table2 = interpolation slope) addressed by a 5-bit mantissa
// window.
//
// This model reproduces the same arithmetic *result* using variable
// shifts/casts instead of the RTL's per-index case statements, so a bug in
// any single RTL case-statement branch (wrong bit range, off-by-one, wrong
// default) will surface as a mismatch against this model rather than being
// silently mirrored.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
package lsc_func1_ref_pkg;

  function automatic int table1_lut(int adr);
    case (adr)
      1  : table1_lut = 0;
      2  : table1_lut = 2048;
      3  : table1_lut = 3247;
      4  : table1_lut = 4096;
      5  : table1_lut = 4756;
      6  : table1_lut = 5295;
      7  : table1_lut = 5750;
      8  : table1_lut = 6144;
      9  : table1_lut = 6493;
      10 : table1_lut = 6804;
      11 : table1_lut = 7085;
      12 : table1_lut = 7343;
      13 : table1_lut = 7579;
      14 : table1_lut = 7798;
      15 : table1_lut = 8002;
      16 : table1_lut = 8192;
      17 : table1_lut = 8372;
      18 : table1_lut = 8541;
      19 : table1_lut = 8700;
      20 : table1_lut = 8852;
      21 : table1_lut = 8996;
      22 : table1_lut = 9133;
      23 : table1_lut = 9265;
      24 : table1_lut = 9391;
      25 : table1_lut = 9511;
      26 : table1_lut = 9627;
      27 : table1_lut = 9739;
      28 : table1_lut = 9846;
      29 : table1_lut = 9950;
      30 : table1_lut = 10050;
      31 : table1_lut = 10147;
      default: table1_lut = 0;
    endcase
  endfunction

  function automatic int table2_lut(int adr);
    case (adr)
      1  : table2_lut = 2048;
      2  : table2_lut = 1199;
      3  : table2_lut = 850;
      4  : table2_lut = 660;
      5  : table2_lut = 539;
      6  : table2_lut = 456;
      7  : table2_lut = 395;
      8  : table2_lut = 349;
      9  : table2_lut = 312;
      10 : table2_lut = 282;
      11 : table2_lut = 258;
      12 : table2_lut = 237;
      13 : table2_lut = 219;
      14 : table2_lut = 204;
      15 : table2_lut = 191;
      16 : table2_lut = 180;
      17 : table2_lut = 169;
      18 : table2_lut = 160;
      19 : table2_lut = 152;
      20 : table2_lut = 145;
      21 : table2_lut = 138;
      22 : table2_lut = 132;
      23 : table2_lut = 126;
      24 : table2_lut = 121;
      25 : table2_lut = 116;
      26 : table2_lut = 112;
      27 : table2_lut = 108;
      28 : table2_lut = 104;
      29 : table2_lut = 101;
      30 : table2_lut = 97;
      31 : table2_lut = 94;
      default: table2_lut = 2048;
    endcase
  endfunction

  // Position of the highest set bit within v[22:5]; 4 if none set.
  function automatic int find_idx(int unsigned v);
    int idx;
    idx = 4;
    for (int i = 5; i <= 22; i++) if (v[i]) idx = i;
    return idx;
  endfunction

  function automatic logic [15:0] lsc_func1_model(logic [22:0] dat_in);
    int unsigned b_tmp_t;
    int unsigned b_tmp;
    int idx, a_tmp, b_shift, c_tmp1;
    int t1, t2, shift_amt, c_tmp2, sum;
    longint mul;

    b_tmp_t = int'(dat_in) + 1;
    b_tmp   = (b_tmp_t >= (1 << 23)) ? 32'h7FFFFF : b_tmp_t;

    idx   = find_idx(b_tmp);
    a_tmp = idx - 4;

    // 5-bit mantissa window: b_tmp[idx -: 5]
    b_shift = (b_tmp >> (idx - 4)) & 32'h1F;

    // 7-bit interpolation field below the window, zero-padded on top.
    if (idx <= 4)      c_tmp1 = 0;
    else if (idx < 11) c_tmp1 = b_tmp & ((1 << (idx - 4)) - 1);
    else               c_tmp1 = (b_tmp >> (idx - 11)) & 32'h7F;

    t1 = table1_lut(b_shift);
    t2 = table2_lut(b_shift);
    mul = longint'(c_tmp1) * longint'(t2);

    shift_amt = (a_tmp <= 7) ? a_tmp : 7;
    c_tmp2 = int'(mul >>> shift_amt) & 32'h7FF;

    sum = (a_tmp * 2048) + c_tmp2 + t1;
    return sum[15:0];
  endfunction

endpackage
