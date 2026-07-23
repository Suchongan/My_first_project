//-----------------------------------------------------------------------------
// Self-checking SystemVerilog testbench for JRP_CONV.
//
// JRP_CONV is a synchronous-enable ("freeze") 3-stage pipeline over a 5x5
// pixel window. Two output groups have different latencies from a sampled
// window: CR1..CR4 are 2 cycles, Gx/Gy/Gx_abs/Gy_abs/C1/Ls0..Ls8 are 3
// cycles. The module also expects Pxd_window_5x5_pipe1/pipe2 to be
// externally pre-delayed copies of Pxd_window_5x5_pipe0 (by 1 and 2
// *enabled* clocks respectively) so that internal combinational stages can
// re-read the raw window without re-registering all 250 bits — the
// testbench reproduces that external delay-line contract itself.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module jrp_conv_tb;

  import jrp_conv_ref_pkg::*;

  //---------------------------------------------------------------------
  // Clock / reset
  //---------------------------------------------------------------------
  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic rstn;
  logic pipe_en;
  logic [DBIT*25-1:0] win_pipe0, win_pipe1, win_pipe2;

  logic [10:0] Gx, Gy;
  logic [9:0]  Gx_abs, Gy_abs;
  logic [11:0] CR1, CR2, CR3, CR4;
  logic [9:0]  C1;
  logic [9:0]  Ls0, Ls1, Ls2, Ls3, Ls4, Ls5, Ls6, Ls7, Ls8;

  //---------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------
  JRP_CONV #(.HBit(11), .VBit(11), .DBit(DBIT)) dut (
    .Pxd_window_5x5_pipe0 (win_pipe0),
    .Pxd_window_5x5_pipe1 (win_pipe1),
    .Pxd_window_5x5_pipe2 (win_pipe2),
    .RSTN                 (rstn),
    .CLK                  (clk),
    .pipe_en              (pipe_en),
    .Gx                   (Gx),
    .Gy                   (Gy),
    .Gx_abs               (Gx_abs),
    .Gy_abs               (Gy_abs),
    .CR1                  (CR1),
    .CR2                  (CR2),
    .CR3                  (CR3),
    .CR4                  (CR4),
    .C1                   (C1),
    .Ls0                  (Ls0),
    .Ls1                  (Ls1),
    .Ls2                  (Ls2),
    .Ls3                  (Ls3),
    .Ls4                  (Ls4),
    .Ls5                  (Ls5),
    .Ls6                  (Ls6),
    .Ls7                  (Ls7),
    .Ls8                  (Ls8)
  );

  //---------------------------------------------------------------------
  // Golden model, evaluated combinationally on the window currently
  // presented on pipe0. Note this deliberately does NOT read win_pipe1/
  // win_pipe2: those buses exist only so the DUT's internal stages (which
  // re-fetch raw pixels rather than carrying the full 250-bit window
  // through registers) see the *same* logical window S[k] again, several
  // cycles later. Small_corner/Small_cross/Center_4x etc. are properties
  // of sample S[k] itself, so the model computes them straight from
  // win_pipe0 — the 1-/2-cycle bus lag is a DUT-internal wiring detail,
  // not a different logical sample.
  //---------------------------------------------------------------------
  jrp_result_t model_now;
  always_comb model_now = jrp_conv_model(win_pipe0, win_pipe0, win_pipe0);

  //---------------------------------------------------------------------
  // Scoreboard: 3-deep shadow pipeline, gated identically to the DUT.
  // shadow_pipe[1] aligns with the 2-cycle-latency CR1..CR4.
  // shadow_pipe[2] aligns with the 3-cycle-latency remaining outputs.
  //---------------------------------------------------------------------
  jrp_result_t shadow_pipe [0:2];
  localparam jrp_result_t ZERO_RESULT = '{default: 0};

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      shadow_pipe[0] <= ZERO_RESULT;
      shadow_pipe[1] <= ZERO_RESULT;
      shadow_pipe[2] <= ZERO_RESULT;
    end else if (pipe_en) begin
      shadow_pipe[2] <= shadow_pipe[1];
      shadow_pipe[1] <= shadow_pipe[0];
      shadow_pipe[0] <= model_now;
    end
  end

  int num_checks = 0;
  int num_fail   = 0;

  always @(negedge clk) begin
    if (rstn) begin
      bit fail;
      fail = 0;
      num_checks++;
      if (CR1 !== shadow_pipe[1].cr1) begin fail = 1; $display("[%0t] CR1 mismatch: got %0d exp %0d", $time, CR1, shadow_pipe[1].cr1); end
      if (CR2 !== shadow_pipe[1].cr2) begin fail = 1; $display("[%0t] CR2 mismatch: got %0d exp %0d", $time, CR2, shadow_pipe[1].cr2); end
      if (CR3 !== shadow_pipe[1].cr3) begin fail = 1; $display("[%0t] CR3 mismatch: got %0d exp %0d", $time, CR3, shadow_pipe[1].cr3); end
      if (CR4 !== shadow_pipe[1].cr4) begin fail = 1; $display("[%0t] CR4 mismatch: got %0d exp %0d", $time, CR4, shadow_pipe[1].cr4); end
      if (Gx     !== shadow_pipe[2].gx)     begin fail = 1; $display("[%0t] Gx mismatch: got %0d exp %0d", $time, Gx, shadow_pipe[2].gx); end
      if (Gy     !== shadow_pipe[2].gy)     begin fail = 1; $display("[%0t] Gy mismatch: got %0d exp %0d", $time, Gy, shadow_pipe[2].gy); end
      if (Gx_abs !== shadow_pipe[2].gx_abs) begin fail = 1; $display("[%0t] Gx_abs mismatch: got %0d exp %0d", $time, Gx_abs, shadow_pipe[2].gx_abs); end
      if (Gy_abs !== shadow_pipe[2].gy_abs) begin fail = 1; $display("[%0t] Gy_abs mismatch: got %0d exp %0d", $time, Gy_abs, shadow_pipe[2].gy_abs); end
      if (C1     !== shadow_pipe[2].c1)     begin fail = 1; $display("[%0t] C1 mismatch: got %0d exp %0d", $time, C1, shadow_pipe[2].c1); end
      if (Ls0 !== shadow_pipe[2].ls0) begin fail = 1; $display("[%0t] Ls0 mismatch: got %0d exp %0d", $time, Ls0, shadow_pipe[2].ls0); end
      if (Ls1 !== shadow_pipe[2].ls1) begin fail = 1; $display("[%0t] Ls1 mismatch: got %0d exp %0d", $time, Ls1, shadow_pipe[2].ls1); end
      if (Ls2 !== shadow_pipe[2].ls2) begin fail = 1; $display("[%0t] Ls2 mismatch: got %0d exp %0d", $time, Ls2, shadow_pipe[2].ls2); end
      if (Ls3 !== shadow_pipe[2].ls3) begin fail = 1; $display("[%0t] Ls3 mismatch: got %0d exp %0d", $time, Ls3, shadow_pipe[2].ls3); end
      if (Ls4 !== shadow_pipe[2].ls4) begin fail = 1; $display("[%0t] Ls4 mismatch: got %0d exp %0d", $time, Ls4, shadow_pipe[2].ls4); end
      if (Ls5 !== shadow_pipe[2].ls5) begin fail = 1; $display("[%0t] Ls5 mismatch: got %0d exp %0d", $time, Ls5, shadow_pipe[2].ls5); end
      if (Ls6 !== shadow_pipe[2].ls6) begin fail = 1; $display("[%0t] Ls6 mismatch: got %0d exp %0d", $time, Ls6, shadow_pipe[2].ls6); end
      if (Ls7 !== shadow_pipe[2].ls7) begin fail = 1; $display("[%0t] Ls7 mismatch: got %0d exp %0d", $time, Ls7, shadow_pipe[2].ls7); end
      if (Ls8 !== shadow_pipe[2].ls8) begin fail = 1; $display("[%0t] Ls8 mismatch: got %0d exp %0d", $time, Ls8, shadow_pipe[2].ls8); end
      if (fail) num_fail++;
    end
  end

  //---------------------------------------------------------------------
  // Stimulus: external-delay-line emulation for pipe1/pipe2.
  //---------------------------------------------------------------------
  logic [DBIT*25-1:0] win_prev1, win_prev2; // S[b-1], S[b-2]

  task automatic do_reset();
    rstn      = 0;
    pipe_en   = 0;
    win_pipe0 = '0;
    win_pipe1 = '0;
    win_pipe2 = '0;
    win_prev1 = '0;
    win_prev2 = '0;
    repeat (3) @(posedge clk);
    rstn = 1;
    @(posedge clk);
  endtask

  task automatic drive_window(input logic [DBIT*25-1:0] neww, input bit en);
    win_pipe0 = neww;
    win_pipe1 = win_prev1;
    win_pipe2 = win_prev2;
    pipe_en   = en;
    @(posedge clk);
    if (en) begin
      win_prev2 = win_prev1;
      win_prev1 = neww;
    end
  endtask

  function automatic logic [DBIT*25-1:0] flat_window(input int val);
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = val;
    return pack_window(p);
  endfunction

  function automatic logic [DBIT*25-1:0] impulse_window(input int cx, input int cy, input int hi, input int lo);
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = (x == cx && y == cy) ? hi : lo;
    return pack_window(p);
  endfunction

  function automatic logic [DBIT*25-1:0] checkerboard_window(input bit invert);
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = (((x + y) % 2 == 0) ^ invert) ? 1023 : 0;
    return pack_window(p);
  endfunction

  function automatic logic [DBIT*25-1:0] ramp_x_window();
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = (x - 1) * 255;
    return pack_window(p);
  endfunction

  function automatic logic [DBIT*25-1:0] ramp_y_window();
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = (y - 1) * 255;
    return pack_window(p);
  endfunction

  function automatic logic [DBIT*25-1:0] random_window();
    int p[1:5][1:5];
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p[x][y] = $urandom_range(0, 1023);
    return pack_window(p);
  endfunction

  //---------------------------------------------------------------------
  // Packing self-test: unpack(pack(p)) must reproduce p exactly, so a
  // bug in the pack/unpack bit-order convention (which both the model
  // and the stimulus generators depend on) is caught immediately rather
  // than masquerading as a JRP_CONV mismatch.
  //---------------------------------------------------------------------
  initial begin : packing_self_test
    int p_in[1:5][1:5];
    int p_out[1:5][1:5];
    logic [DBIT*25-1:0] w;
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        p_in[x][y] = (x - 1) * 50 + (y - 1) * 7 + 3;
    w = pack_window(p_in);
    unpack_window(w, p_out);
    for (int x = 1; x <= 5; x++)
      for (int y = 1; y <= 5; y++)
        if (p_in[x][y] !== p_out[x][y]) begin
          $display("PACKING SELF-TEST FAILED at x=%0d y=%0d: in=%0d out=%0d", x, y, p_in[x][y], p_out[x][y]);
          $fatal(1);
        end
    $display("Packing self-test passed.");
  end

  //---------------------------------------------------------------------
  // Test sequence
  //---------------------------------------------------------------------
  initial begin
    $dumpfile("jrp_conv_tb.vcd");
    $dumpvars(0, jrp_conv_tb);

    do_reset();

    // --- Directed corner-case windows -----------------------------------
    drive_window(flat_window(0),    1);
    drive_window(flat_window(1023), 1);
    drive_window(flat_window(512),  1);
    for (int cx = 1; cx <= 5; cx++)
      for (int cy = 1; cy <= 5; cy++)
        drive_window(impulse_window(cx, cy, 1023, 0), 1);
    drive_window(checkerboard_window(0), 1);
    drive_window(checkerboard_window(1), 1);
    drive_window(ramp_x_window(), 1);
    drive_window(ramp_y_window(), 1);
    repeat (8) drive_window(random_window(), 1); // flush pipeline

    // --- Directed: freeze behaviour ---------------------------------------
    drive_window(flat_window(200), 1);
    drive_window(flat_window(800), 1);
    repeat (6) drive_window(random_window(), 0); // pipe_en low -> frozen
    repeat (8) drive_window(random_window(), 1); // resume, flush

    // --- Directed: mid-stream reset ----------------------------------------
    repeat (4) drive_window(random_window(), 1);
    do_reset();
    repeat (8) drive_window(random_window(), 1);

    // --- Randomized regression ----------------------------------------------
    for (int i = 0; i < 4000; i++) begin
      bit en;
      en = ($urandom_range(0, 9) != 0);
      drive_window(random_window(), en);
    end

    repeat (8) drive_window(flat_window(0), 1); // flush tail

    if (num_fail == 0) begin
      $display("=====================================================");
      $display(" JRP_CONV TB PASSED: %0d checks, 0 mismatches", num_checks);
      $display("=====================================================");
    end else begin
      $display("=====================================================");
      $display(" JRP_CONV TB FAILED: %0d/%0d checks mismatched", num_fail, num_checks);
      $display("=====================================================");
    end

    $finish;
  end

  initial begin
    #4_000_000;
    $display("ERROR: testbench timeout");
    $finish;
  end

endmodule
