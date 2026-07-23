//-----------------------------------------------------------------------------
// Independent golden reference model for JRP_func4.
//
// JRP_func4 is a small fixed-point log2-ish compressor: 3-stage
// synchronous-enable ("freeze") pipeline, gated uniformly by pipe_en.
// b_tmp = dat_in + 1 (9-bit, dat_in is only 8 bits so b_tmp never
// saturates). It finds the highest set bit among b_tmp[8:4] (a 5-level
// priority encoder), uses that to pick a_tmp (the bit's offset from bit 3)
// and a 4-bit mantissa window, looks up a 6-bit LUT indexed by
// (mantissa - 1), and outputs a_tmp*8 + LUT value.
//
// The RTL implements the priority encoder as a 5-level nested ternary
// chain. This model re-derives it with a `unique casez` priority-encoder
// pattern instead, so a wrong threshold bit in the RTL's chain (an
// off-by-one on which bit gates which branch) surfaces as a mismatch
// rather than being reproduced verbatim.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
package jrp_func4_ref_pkg;

  function automatic int table1_lut(int adr);
    unique case (adr)
      0  : table1_lut = 0;
      1  : table1_lut = 8;
      2  : table1_lut = 13;
      3  : table1_lut = 16;
      4  : table1_lut = 19;
      5  : table1_lut = 21;
      6  : table1_lut = 23;
      7  : table1_lut = 24;
      8  : table1_lut = 26;
      9  : table1_lut = 27;
      10 : table1_lut = 28;
      11 : table1_lut = 29;
      12 : table1_lut = 30;
      13 : table1_lut = 31;
      14 : table1_lut = 32;
      default: table1_lut = 32;
    endcase
  endfunction

  function automatic logic [6:0] jrp_func4_model(input logic [7:0] dat_in);
    logic [8:0] b_tmp;
    logic [4:0] hi5;
    int idx;         // position (4..8) of the highest set bit in hi5, or -1
    int a_tmp_val;
    int b_tmp2_val;
    int table1_sel;
    int table1_val;
    int sum;

    b_tmp = {1'b0, dat_in} + 9'd1;
    hi5   = b_tmp[8:4];

    unique casez (hi5)
      5'b1????: idx = 8;
      5'b01???: idx = 7;
      5'b001??: idx = 6;
      5'b0001?: idx = 5;
      5'b00001: idx = 4;
      5'b00000: idx = -1;
    endcase

    if (idx == -1) begin
      a_tmp_val  = 0;
      b_tmp2_val = int'(b_tmp) & 'hF;
    end else begin
      a_tmp_val  = idx - 3;
      b_tmp2_val = (int'(b_tmp) >> (idx - 3)) & 'hF;
    end

    table1_sel = (b_tmp2_val - 1) & 'hF;
    table1_val = table1_lut(table1_sel);

    sum = (a_tmp_val << 3) + table1_val;
    return 7'(sum);
  endfunction

endpackage
