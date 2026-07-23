//-----------------------------------------------------------------------------
// Self-checking, exhaustive SystemVerilog testbench for JRP_func4.
//
// dat_in is only 8 bits wide (256 possible values), so unlike LSC_Func1
// and JRP_CONV this testbench sweeps every possible input exactly once
// instead of sampling randomly. pipe_en is held high throughout the sweep
// (freeze/reset control-path behavior is not covered here). Every
// dat_in -> dat_out pair is also written to a CSV for the transfer-curve
// plot (tb/plot_jrp_func4.py).
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module jrp_func4_tb;

  import jrp_func4_ref_pkg::*;

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
  logic [7:0] dat_in;
  logic [6:0] dat_out;

  //---------------------------------------------------------------------
  // DUT
  //---------------------------------------------------------------------
  JRP_func4 dut (
    .dat_in  (dat_in),
    .dat_out (dat_out),
    .RSTN    (rstn),
    .CLK     (clk),
    .pipe_en (pipe_en)
  );

  //---------------------------------------------------------------------
  // Scoreboard: 3-deep shadow pipeline, gated identically to the DUT.
  // dat_in_pipe rides alongside it purely so mismatch messages and the
  // CSV can report which input a given output corresponds to.
  //---------------------------------------------------------------------
  logic [6:0] shadow_pipe [0:2];
  logic [7:0] dat_in_pipe [0:2];
  bit         valid_pipe  [0:2];

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      shadow_pipe[0] <= '0; shadow_pipe[1] <= '0; shadow_pipe[2] <= '0;
      dat_in_pipe[0] <= '0; dat_in_pipe[1] <= '0; dat_in_pipe[2] <= '0;
      valid_pipe[0]  <= 0;  valid_pipe[1]  <= 0;  valid_pipe[2]  <= 0;
    end else if (pipe_en) begin
      shadow_pipe[2] <= shadow_pipe[1];
      shadow_pipe[1] <= shadow_pipe[0];
      shadow_pipe[0] <= jrp_func4_model(dat_in);
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
  int csv_fd;
  int logged_count = 0;

  always @(negedge clk) begin
    if (rstn && valid_pipe[2]) begin
      num_checks++;
      if (dat_out !== shadow_pipe[2]) begin
        num_fail++;
        $display("[%0t] MISMATCH: dat_in=%0d dat_out=%0d expected=%0d",
                  $time, dat_in_pipe[2], dat_out, shadow_pipe[2]);
      end
      if (logged_count < 256) begin
        $fdisplay(csv_fd, "%0d,%0d", dat_in_pipe[2], dat_out);
        logged_count++;
      end
    end
  end

  //---------------------------------------------------------------------
  // Stimulus: exhaustive sweep over all 256 possible dat_in values.
  //---------------------------------------------------------------------
  initial begin
    csv_fd = $fopen("jrp_func4_sweep.csv", "w");
    $fdisplay(csv_fd, "dat_in,dat_out");

    rstn    = 0;
    pipe_en = 0;
    dat_in  = 8'd0;
    repeat (3) @(posedge clk);
    rstn = 1;
    @(posedge clk);

    pipe_en = 1;
    for (int i = 0; i < 256; i++) begin
      dat_in = i[7:0];
      @(posedge clk);
    end
    repeat (5) begin // flush the last 3 samples through the pipeline
      dat_in = 8'd0;
      @(posedge clk);
    end

    $fclose(csv_fd);

    if (num_fail == 0) begin
      $display("=====================================================");
      $display(" JRP_func4 TB PASSED: %0d checks, 0 mismatches (256/256 dat_in values covered)", num_checks);
      $display("=====================================================");
    end else begin
      $display("=====================================================");
      $display(" JRP_func4 TB FAILED: %0d/%0d checks mismatched", num_fail, num_checks);
      $display("=====================================================");
    end

    $finish;
  end

  initial begin
    #100_000;
    $display("ERROR: testbench timeout");
    $finish;
  end

endmodule
