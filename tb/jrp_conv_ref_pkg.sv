//-----------------------------------------------------------------------------
// Independent golden reference model for JRP_CONV.
//
// JRP_CONV takes three time-aligned copies of the same 5x5 pixel window
// (Pxd_window_5x5_pipe0/1/2 — pipe1 must equal pipe0 delayed by 1 enabled
// clock, pipe2 by 2) and computes, over a 3-stage synchronous-enable
// ("freeze") pipeline gated uniformly by pipe_en:
//   - CR1..CR4  : four diagonal 2x2-corner-block difference magnitudes
//                 (2-cycle latency — registered once, at the TwoPixSum
//                 stage's output)
//   - Gx, Gy, Gx_abs, Gy_abs, C1, Ls0..Ls8 : gradient/local-structure
//                 outputs (3-cycle latency)
//
// This model re-derives the same arithmetic independently, using a
// generic p[col][row] pixel array and TS[col][row] adjacent-pair-sum
// array instead of the RTL's individually named wires, so a mis-wired
// pixel or wrong bit range in the RTL surfaces as a scoreboard mismatch.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
package jrp_conv_ref_pkg;

  localparam int DBIT = 10;

  typedef struct packed {
    logic [10:0] gx;
    logic [10:0] gy;
    logic [9:0]  gx_abs;
    logic [9:0]  gy_abs;
    logic [11:0] cr1;
    logic [11:0] cr2;
    logic [11:0] cr3;
    logic [11:0] cr4;
    logic [9:0]  c1;
    logic [9:0]  ls0;
    logic [9:0]  ls1;
    logic [9:0]  ls2;
    logic [9:0]  ls3;
    logic [9:0]  ls4;
    logic [9:0]  ls5;
    logic [9:0]  ls6;
    logic [9:0]  ls7;
    logic [9:0]  ls8;
  } jrp_result_t;

  function automatic int abs_int(input int v);
    return (v < 0) ? -v : v;
  endfunction

  // Bit layout matches the RTL's `{p11,p12,...,p55} = window` assign:
  // p_x_y occupies group g=(x-1)*5+(y-1) counting from the MSB.
  function automatic void unpack_window(input logic [DBIT*25-1:0] w, output int p[1:5][1:5]);
    int g;
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++) begin
        g = (x - 1) * 5 + (y - 1);
        p[x][y] = int'(w[(25 - g) * DBIT - 1 -: DBIT]);
      end
  endfunction

  function automatic logic [DBIT*25-1:0] pack_window(input int p[1:5][1:5]);
    logic [DBIT*25-1:0] w;
    int g;
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++) begin
        g = (x - 1) * 5 + (y - 1);
        w[(25 - g) * DBIT - 1 -: DBIT] = p[x][y][DBIT-1:0];
      end
    return w;
  endfunction

  function automatic jrp_result_t jrp_conv_model(
      input logic [DBIT*25-1:0] win0,
      input logic [DBIT*25-1:0] win1,
      input logic [DBIT*25-1:0] win2
  );
    int p[1:5][1:5];
    int pd1[1:5][1:5];
    int pd2[1:5][1:5];
    int ts[1:4][1:5];
    jrp_result_t r;

    int cr1_t0, cr1_t1, cr2_t0, cr2_t1, cr3_t0, cr3_t1, cr4_t0, cr4_t1;
    int gradx_l0, gradx_l1, gradx_r0, gradx_r1, gradx_l, gradx_r, gradx_t, gradx_sft;
    int grady_u0, grady_d0, grady_u_t0, grady_d_t0, grady_u_t1, grady_d_t1;
    int grady_u_t2, grady_d_t2, grady_t, grady_sft;
    int small_corner, small_cross, c1_t0, c1_t1v, c1_sft;
    int ls_lr[0:8], ls_m[0:8], ls_t0[0:8], ls_sft[0:8];

    unpack_window(win0, p);
    unpack_window(win1, pd1);
    unpack_window(win2, pd2);

    for (int x = 1; x <= 4; x++)
      for (int y = 1; y <= 5; y++)
        ts[x][y] = p[x][y] + p[x+1][y];

    // --- Corner responses (2-cycle latency) ---------------------------
    cr1_t0 = ts[1][1] + ts[1][2];
    cr1_t1 = ts[1][4] + ts[1][5];
    r.cr1  = 12'(abs_int(cr1_t0 - cr1_t1));

    cr2_t0 = ts[4][1] + ts[4][2];
    cr2_t1 = ts[4][4] + ts[4][5];
    r.cr2  = 12'(abs_int(cr2_t0 - cr2_t1));

    cr3_t0 = ts[1][1] + ts[1][2];
    cr3_t1 = ts[4][1] + ts[4][2];
    r.cr3  = 12'(abs_int(cr3_t0 - cr3_t1));

    cr4_t0 = ts[1][4] + ts[1][5];
    cr4_t1 = ts[4][4] + ts[4][5];
    r.cr4  = 12'(abs_int(cr4_t0 - cr4_t1));

    // --- Gx (3-cycle latency) ------------------------------------------
    gradx_l0 = ts[1][1] + ts[2][1] + ts[3][1] + ts[4][1];
    gradx_l1 = ts[2][2] + ts[3][2];
    gradx_r0 = ts[1][5] + ts[2][5] + ts[3][5] + ts[4][5];
    gradx_r1 = ts[2][4] + ts[3][4];
    gradx_l  = gradx_l0 + (gradx_l1 << 1);
    gradx_r  = gradx_r0 + (gradx_r1 << 1);
    gradx_t  = gradx_r - gradx_l;
    gradx_sft = gradx_t >>> 4;
    r.gx     = 11'(gradx_sft);
    r.gx_abs = 10'(abs_int(gradx_sft));

    // --- Gy (3-cycle latency) -------------------------------------------
    grady_u0   = ts[1][2] + ts[1][3] + ts[1][4];
    grady_d0   = ts[4][2] + ts[4][3] + ts[4][4];
    grady_u_t0 = (grady_u0 << 1) + (pd2[2][3] << 1);
    grady_d_t0 = (grady_d0 << 1) + (pd2[4][3] << 1);
    grady_u_t1 = grady_u_t0 + (pd2[1][1] + pd2[1][5]);
    grady_d_t1 = grady_d_t0 + (pd2[5][1] + pd2[5][5]);
    grady_u_t2 = grady_u_t1 & 32'h3FFF;
    grady_d_t2 = grady_d_t1 & 32'h3FFF;
    grady_t    = grady_d_t2 - grady_u_t2;
    grady_sft  = grady_t >>> 4;
    r.gy       = 11'(grady_sft);
    r.gy_abs   = 10'(abs_int(grady_sft));

    // --- C1 (3-cycle latency, raw truncated — no abs, can wrap) --------
    small_corner = pd1[2][2] + pd1[2][4] + pd1[4][2] + pd1[4][4];
    small_cross  = pd1[2][3] + pd1[3][2] + pd1[4][3] + pd1[3][4];
    c1_t0  = (pd2[3][3] << 2) + small_corner;
    c1_t1v = (small_cross << 1) - c1_t0;
    c1_sft = c1_t1v >>> 4;
    r.c1   = 10'(c1_sft);

    // --- Ls0..Ls8 (3-cycle latency) -------------------------------------
    ls_lr[0] = ts[1][1] + ts[2][1] + ts[1][3] + ts[2][3];
    ls_lr[1] = ts[1][2] + ts[2][2] + ts[1][4] + ts[2][4];
    ls_lr[2] = ts[1][3] + ts[2][3] + ts[1][5] + ts[2][5];
    ls_lr[3] = ts[2][1] + ts[3][1] + ts[2][3] + ts[3][3];
    ls_lr[4] = ts[2][2] + ts[3][2] + ts[2][4] + ts[3][4];
    ls_lr[5] = ts[2][3] + ts[3][3] + ts[2][5] + ts[3][5];
    ls_lr[6] = ts[3][1] + ts[4][1] + ts[3][3] + ts[4][3];
    ls_lr[7] = ts[3][2] + ts[4][2] + ts[3][4] + ts[4][4];
    ls_lr[8] = ts[3][3] + ts[4][3] + ts[3][5] + ts[4][5];

    ls_m[0] = ts[1][2] + ts[2][2];
    ls_m[1] = ts[1][3] + ts[2][3];
    ls_m[2] = ts[1][4] + ts[2][4];
    ls_m[3] = ts[2][2] + ts[3][2];
    ls_m[4] = ts[2][3] + ts[3][3];
    ls_m[5] = ts[2][4] + ts[3][4];
    ls_m[6] = ts[3][2] + ts[4][2];
    ls_m[7] = ts[3][3] + ts[4][3];
    ls_m[8] = ts[3][4] + ts[4][4];

    for (int i = 0; i < 9; i++) begin
      ls_t0[i]  = ls_lr[i] + (ls_m[i] << 1) + 8;
      ls_sft[i] = ls_t0[i] >> 4;
    end
    r.ls0 = 10'(ls_sft[0]);
    r.ls1 = 10'(ls_sft[1]);
    r.ls2 = 10'(ls_sft[2]);
    r.ls3 = 10'(ls_sft[3]);
    r.ls4 = 10'(ls_sft[4]);
    r.ls5 = 10'(ls_sft[5]);
    r.ls6 = 10'(ls_sft[6]);
    r.ls7 = 10'(ls_sft[7]);
    r.ls8 = 10'(ls_sft[8]);

    return r;
  endfunction

endpackage
