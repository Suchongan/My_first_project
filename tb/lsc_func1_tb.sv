//-----------------------------------------------------------------------------
// Self-checking SystemVerilog testbench for LSC_Func1.
//
// LSC_Func1 is a synchronous-enable ("freeze") pipeline: every internal
// register is gated by the same (pipe_en & RS_LSC_EnH_FB) condition, so
// when that condition is low the whole pipeline holds; when high, every
// stage advances together. Latency from a sampled input to the
// corresponding dat_out is exactly 4 clock edges.
//
// The scoreboard mirrors that exact structure with a 4-deep shadow shift
// register, gated the same way, whose stage-0 input is produced by an
// independently written reference model (lsc_func1_ref_pkg). It is
// compared against dat_out every cycle.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module lsc_func1_tb;

  import lsc_func1_ref_pkg::*;

  //---------------------------------------------------------------------
  // Clock / reset
  //---------------------------------------------------------------------
  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic        rstn;
  logic        pipe_en;
  logic        rs_lsc_enh_fb;
  logic [22:0] dat_in;
  logic [15:0] dat_out;

  //---------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------
  LSC_Func1 dut (
    .dat_out       (dat_out),
    .dat_in        (dat_in),
    .pipe_en       (pipe_en),
    .clk           (clk),
    .rstn          (rstn),
    .RS_LSC_EnH_FB (rs_lsc_enh_fb)
  );

  //---------------------------------------------------------------------
  // Scoreboard: 4-deep shadow pipeline, gated identically to the DUT.
  //---------------------------------------------------------------------
  logic [15:0] shadow_pipe [0:3];

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      shadow_pipe[0] <= 16'd0;
      shadow_pipe[1] <= 16'd0;
      shadow_pipe[2] <= 16'd0;
      shadow_pipe[3] <= 16'd0;
    end else if (pipe_en && rs_lsc_enh_fb) begin
      shadow_pipe[3] <= shadow_pipe[2];
      shadow_pipe[2] <= shadow_pipe[1];
      shadow_pipe[1] <= shadow_pipe[0];
      shadow_pipe[0] <= lsc_func1_model(dat_in);
    end
  end

  int num_checks = 0;
  int num_fail   = 0;

  // Compare on the negative edge, once both dat_out and shadow_pipe have
  // settled from the same posedge's nonblocking updates.
  always @(negedge clk) begin
    if (rstn) begin
      num_checks++;
      if (dat_out !== shadow_pipe[3]) begin
        num_fail++;
        $display("[%0t] MISMATCH #%0d: dat_in=%0d (0x%06h) dat_out=%0d expected=%0d",
                  $time, num_checks, dat_in, dat_in, dat_out, shadow_pipe[3]);
      end
    end
  end

  //---------------------------------------------------------------------
  // Stimulus helpers
  //---------------------------------------------------------------------
  task automatic do_reset();
    rstn          = 0;
    pipe_en       = 0;
    rs_lsc_enh_fb = 0;
    dat_in        = '0;
    repeat (3) @(posedge clk);
    rstn = 1;
    @(posedge clk);
  endtask

  task automatic drive(input logic [22:0] din, input bit en, input bit fb);
    dat_in        = din;
    pipe_en       = en;
    rs_lsc_enh_fb = fb;
    @(posedge clk);
  endtask

  //---------------------------------------------------------------------
  // Test sequence
  //---------------------------------------------------------------------
  initial begin
    $dumpfile("lsc_func1_tb.vcd");
    $dumpvars(0, lsc_func1_tb);

    do_reset();

    // --- Directed: idx/table boundary corner cases -------------------
    // dat_in = 2^k - 1 and 2^k crosses the leading-bit index boundary.
    for (int k = 0; k <= 22; k++) begin
      drive((1 << k) - 1, 1, 1);
      drive((1 << k),     1, 1);
    end
    drive(23'd0,       1, 1);
    drive(23'd1,       1, 1);
    drive(23'h7FFFFE,  1, 1);
    drive(23'h7FFFFF,  1, 1); // max value, exercises b_tmp saturation
    repeat (8) drive(23'($urandom()), 1, 1); // flush pipeline with junk

    // --- Directed: freeze behaviour -----------------------------------
    // Hold enable high for a few known inputs, then freeze the pipeline
    // (enable low) while changing dat_in; frozen cycles must not affect
    // dat_out, which the scoreboard verifies automatically.
    drive(23'h000010, 1, 1);
    drive(23'h000020, 1, 1);
    repeat (6) drive(23'($urandom()), 0, 1); // pipe_en low -> frozen
    repeat (6) drive(23'($urandom()), 1, 0); // RS_LSC_EnH_FB low -> frozen
    repeat (8) drive(23'($urandom()), 1, 1); // resume, flush

    // --- Directed: mid-stream reset ------------------------------------
    repeat (4) drive(23'($urandom_range(0, (1 << 23) - 1)), 1, 1);
    rstn = 0;
    repeat (2) @(posedge clk);
    rstn = 1;
    @(posedge clk);
    repeat (8) drive(23'($urandom()), 1, 1);

    // --- Randomized regression ------------------------------------------
    for (int i = 0; i < 5000; i++) begin
      logic [22:0] din;
      bit          en, fb;
      din = 23'($urandom_range(0, (1 << 23) - 1));
      // Bias heavily towards enabled so the pipeline mostly moves, but
      // exercise freeze cycles too.
      en  = ($urandom_range(0, 9) != 0);
      fb  = ($urandom_range(0, 9) != 0);
      drive(din, en, fb);
    end

    // Flush and let the final randomized inputs propagate through.
    repeat (8) drive(23'd0, 1, 1);

    if (num_fail == 0) begin
      $display("=====================================================");
      $display(" LSC_Func1 TB PASSED: %0d checks, 0 mismatches", num_checks);
      $display("=====================================================");
    end else begin
      $display("=====================================================");
      $display(" LSC_Func1 TB FAILED: %0d/%0d checks mismatched", num_fail, num_checks);
      $display("=====================================================");
    end

    $finish;
  end

  // Safety timeout in case something hangs.
  initial begin
    #2_000_000;
    $display("ERROR: testbench timeout");
    $finish;
  end

endmodule
