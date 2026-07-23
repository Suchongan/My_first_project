//-----------------------------------------------------------------------------
// Self-checking, exhaustive SystemVerilog testbench for JRP_func3.
//
// dat_in is 12 bits (4096 possible values), small enough to sweep every
// input exactly once rather than sampling randomly. pipe_en is held high
// throughout the sweep. The scoreboard is a 3-deep shadow pipeline gated
// identically to the DUT (single 3-cycle latency), fed by the independent
// reference model jrp_func3_model().
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module jrp_func3_tb;

  import jrp_func3_ref_pkg::*;

  //---------------------------------------------------------------------
  // Clock / reset
  //---------------------------------------------------------------------
  logic clk;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  logic        resetn;
  logic        pipe_en;
  logic [11:0] dat_in;
  logic [16:0] dat_out;

  //---------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------
  JRP_func3 dut (
    .RESETN  (resetn),
    .ISP_CLK (clk),
    .pipe_en (pipe_en),
    .dat_in  (dat_in),
    .dat_out (dat_out)
  );

  //---------------------------------------------------------------------
  // Scoreboard: 3-deep shadow pipeline, gated identically to the DUT.
  // dat_in_pipe rides alongside purely so mismatch messages can report
  // which input a given output corresponds to.
  //---------------------------------------------------------------------
  logic [16:0] shadow_pipe [0:2];
  logic [11:0] dat_in_pipe [0:2];
  bit          valid_pipe  [0:2];

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      shadow_pipe[0] <= '0; shadow_pipe[1] <= '0; shadow_pipe[2] <= '0;
      dat_in_pipe[0] <= '0; dat_in_pipe[1] <= '0; dat_in_pipe[2] <= '0;
      valid_pipe[0]  <= 0;  valid_pipe[1]  <= 0;  valid_pipe[2]  <= 0;
    end else if (pipe_en) begin
      shadow_pipe[2] <= shadow_pipe[1];
      shadow_pipe[1] <= shadow_pipe[0];
      shadow_pipe[0] <= jrp_func3_model(dat_in);
      dat_in_pipe[2] <= dat_in_pipe[1];
      dat_in_pipe[1] <= dat_in_pipe[0];
      dat_in_pipe[0] <= dat_in;
      valid_pipe[2]  <= valid_pipe[1];
      valid_pipe[1]  <= valid_pipe[0];
      valid_pipe[0]  <= 1'b1;
    end
  end

  int num_checks = 0;
  int num_fail   = 0;

  always @(negedge clk) begin
    if (resetn && valid_pipe[2]) begin
      num_checks++;
      if (dat_out !== shadow_pipe[2]) begin
        num_fail++;
        $display("[%0t] MISMATCH: dat_in=%0d dat_out=%0d expected=%0d",
                  $time, dat_in_pipe[2], dat_out, shadow_pipe[2]);
      end
    end
  end

  //---------------------------------------------------------------------
  // Stimulus: exhaustive sweep over all 4096 possible dat_in values.
  //---------------------------------------------------------------------
  initial begin
    resetn  = 0;
    pipe_en = 0;
    dat_in  = 12'd0;
    repeat (3) @(posedge clk);
    resetn = 1;
    @(posedge clk);

    pipe_en = 1;
    for (int i = 0; i < 4096; i++) begin
      dat_in = i[11:0];
      @(posedge clk);
    end
    repeat (5) begin // flush the last samples through the pipeline
      dat_in = 12'd0;
      @(posedge clk);
    end

    if (num_fail == 0) begin
      $display("=====================================================");
      $display(" JRP_func3 TB PASSED: %0d checks, 0 mismatches (4096/4096 dat_in values covered)", num_checks);
      $display("=====================================================");
    end else begin
      $display("=====================================================");
      $display(" JRP_func3 TB FAILED: %0d/%0d checks mismatched", num_fail, num_checks);
      $display("=====================================================");
    end

    $finish;
  end

  initial begin
    #500_000;
    $display("ERROR: testbench timeout");
    $finish;
  end

endmodule
