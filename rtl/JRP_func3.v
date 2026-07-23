
module JRP_func3(
                       RESETN, ISP_CLK,pipe_en,
                       dat_in, dat_out
                      );

input         RESETN;
input         ISP_CLK;
input         pipe_en;
input  [11:0] dat_in;
output [16:0] dat_out;

//-----------------------------------------------------------
wire [3:0] a_tmp = (dat_in[11:8] > 4'd14) ? 4'd14 : dat_in[11:8];//max 14
wire [3:0] b_tmp = dat_in[7:4];
wire [3:0] c_tmp = dat_in[3:0];

// table1 (base) and table2 (slope) share the same b_tmp key, so they are
// decoded together in a single parallel `case` instead of two independent
// priority-mux ternary chains. This gives the synthesizer one balanced
// 16:1 decode of b_tmp (matching the `shifta` case style used later in
// this module) and halves b_tmp's decode fanout, shortening the stage-1
// combinational path without changing function.
reg [13:0] table1;
reg [6:0]  table2;
always@(*)
begin
   case(b_tmp)
     4'd00 :  begin table1 = 14'd0     ; table2 = 7'd45 ; end
     4'd01 :  begin table1 = 14'd725   ; table2 = 7'd47 ; end
     4'd02 :  begin table1 = 14'd1482  ; table2 = 7'd49 ; end
     4'd03 :  begin table1 = 14'd2273  ; table2 = 7'd51 ; end
     4'd04 :  begin table1 = 14'd3099  ; table2 = 7'd53 ; end
     4'd05 :  begin table1 = 14'd3962  ; table2 = 7'd56 ; end
     4'd06 :  begin table1 = 14'd4863  ; table2 = 7'd58 ; end
     4'd07 :  begin table1 = 14'd5804  ; table2 = 7'd61 ; end
     4'd08 :  begin table1 = 14'd6786  ; table2 = 7'd64 ; end
     4'd09 :  begin table1 = 14'd7812  ; table2 = 7'd66 ; end
     4'd10 :  begin table1 = 14'd8883  ; table2 = 7'd69 ; end
     4'd11 :  begin table1 = 14'd10002 ; table2 = 7'd73 ; end
     4'd12 :  begin table1 = 14'd11170 ; table2 = 7'd76 ; end
     4'd13 :  begin table1 = 14'd12390 ; table2 = 7'd79 ; end
     4'd14 :  begin table1 = 14'd13664 ; table2 = 7'd83 ; end
     default: begin table1 = 14'd14994 ; table2 = 7'd86 ; end
   endcase
end


reg [3:0]  a_tmp_d1;
reg [3:0]  c_tmp_d1;
reg [13:0] table1_d1;
reg [6:0]  table2_d1;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
      a_tmp_d1  <= 4'd0;
      c_tmp_d1  <= 4'd0;

      table1_d1 <= 14'd0;
      table2_d1 <= 7'd0;
   end
   else if(pipe_en)
   begin
      a_tmp_d1  <= a_tmp; 
      c_tmp_d1  <= c_tmp; 

      table1_d1 <= table1; 
      table2_d1 <= table2;
   end
end



//7x4
wire [10:0] mtp_out = table2_d1 * {3'd0, c_tmp_d1};

wire [14:0] t1t2c_t1 = table1_d1 + {3'd0, mtp_out};//max 14994+(86x3)=15252
 


reg [3:0]  a_tmp_d2;
reg [14:0] t1t2c_d2;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
      a_tmp_d2  <=  0;
      t1t2c_d2  <=  0;
 
   end
   else if(pipe_en)
   begin
      a_tmp_d2  <= a_tmp_d1 ;
      t1t2c_d2  <= t1t2c_t1 ;
 
   end
end

//(1<<A)
reg [15:0] shifta; 
always@(*)
begin
   case(a_tmp_d2)
     4'd0 :    begin  shifta =  16'b0000_0000_0000_0001 ; end
     4'd1 :    begin  shifta =  16'b0000_0000_0000_0010 ; end
     4'd2 :    begin  shifta =  16'b0000_0000_0000_0100 ; end
     4'd3 :    begin  shifta =  16'b0000_0000_0000_1000 ; end
     4'd4 :    begin  shifta =  16'b0000_0000_0001_0000 ; end
     4'd5 :    begin  shifta =  16'b0000_0000_0010_0000 ; end
     4'd6 :    begin  shifta =  16'b0000_0000_0100_0000 ; end
     4'd7 :    begin  shifta =  16'b0000_0000_1000_0000 ; end
     4'd8 :    begin  shifta =  16'b0000_0001_0000_0000 ; end
     4'd9 :    begin  shifta =  16'b0000_0010_0000_0000 ; end
     4'd10:    begin  shifta =  16'b0000_0100_0000_0000 ; end
     4'd11:    begin  shifta =  16'b0000_1000_0000_0000 ; end
     4'd12:    begin  shifta =  16'b0001_0000_0000_0000 ; end
     4'd13:    begin  shifta =  16'b0010_0000_0000_0000 ; end
     4'd14:    begin  shifta =  16'b0100_0000_0000_0000 ; end
     4'd15:    begin  shifta =  16'b1000_0000_0000_0000 ; end
     default : begin  shifta =  16'b0000_0000_0000_0000 ; end
 endcase
end


//(T1+T2*C)>>(14-A)
wire [4:0] A_14_diff_t = 5'd14 - {1'd0,a_tmp_d2};
wire [3:0] A_14_diff   = A_14_diff_t[3:0];


wire [14:0] t1t2c_tmp = (t1t2c_d2 >> A_14_diff);

wire [16:0] dat_out_t0 = shifta + t1t2c_tmp;
wire [17:0] dat_out_t1 = dat_out_t0 - 17'd1;



reg [16:0] dat_out_d3;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
      dat_out_d3  <=  0;
 
   end
   else if(pipe_en)
   begin
      dat_out_d3  <= dat_out_t1[16:0] ;
 
   end
end




assign dat_out = dat_out_d3 ;












endmodule













