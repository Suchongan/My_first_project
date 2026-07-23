
module JRP_func2(
                          RESETN, ISP_CLK, pipe_en,
                          dat_in, dat_out
                         );

input         RESETN ;
input         ISP_CLK;
input         pipe_en;
input  [16:0] dat_in ;
output [16:0] dat_out;

//-----------------------------------------------------------
//wire [23:0] b_tmp = {1'b0, dat_in} + 1;//B=X+1
wire [16:0] b_tmp = dat_in;
 
wire [3:0] a_tmp = (b_tmp[16] == 1'b1) ? 4'd13 :
                   (b_tmp[15] == 1'b1) ? 4'd12 :
                   (b_tmp[14] == 1'b1) ? 4'd11 :
                   (b_tmp[13] == 1'b1) ? 4'd10 :
                   (b_tmp[12] == 1'b1) ? 4'd9  :
                   (b_tmp[11] == 1'b1) ? 4'd8  :
                   (b_tmp[10] == 1'b1) ? 4'd7  :
                   (b_tmp[ 9] == 1'b1) ? 4'd6  :
                   (b_tmp[ 8] == 1'b1) ? 4'd5  :
                   (b_tmp[ 7] == 1'b1) ? 4'd4  :
                   (b_tmp[ 6] == 1'b1) ? 4'd3  :
                   (b_tmp[ 5] == 1'b1) ? 4'd2  :
                   (b_tmp[ 4] == 1'b1) ? 4'd1  : 4'd0;

reg [16:0] b_tmp2;
always@(*)
begin
   case(a_tmp)
     4'd0    : b_tmp2 =         b_tmp; 
     4'd1    : b_tmp2 =  {1'd0 ,b_tmp[16:1 ] };
     4'd2    : b_tmp2 =  {2'd0 ,b_tmp[16:2 ] };
     4'd3    : b_tmp2 =  {3'd0 ,b_tmp[16:3 ] };
     4'd4    : b_tmp2 =  {4'd0 ,b_tmp[16:4 ] };
     4'd5    : b_tmp2 =  {5'd0 ,b_tmp[16:5 ] };
     4'd6    : b_tmp2 =  {6'd0 ,b_tmp[16:6 ] };
     4'd7    : b_tmp2 =  {7'd0 ,b_tmp[16:7 ] };
     4'd8    : b_tmp2 =  {8'd0 ,b_tmp[16:8 ] };
     4'd9    : b_tmp2 =  {9'd0 ,b_tmp[16:9 ] };
     4'd10   : b_tmp2 =  {10'd0,b_tmp[16:10] };
     4'd11   : b_tmp2 =  {11'd0,b_tmp[16:11] };
     4'd12   : b_tmp2 =  {12'd0,b_tmp[16:12] };
     4'd13   : b_tmp2 =  {13'd0,b_tmp[16:13] };
     default : b_tmp2 =  {13'd0,b_tmp[16:13] };
 endcase
end

reg [6:0] c_tmp ; //(( X + 1 ) - ( B << A )) >> ( A - M )
always@(*)
begin
   case(a_tmp)
     4'd0    : c_tmp =    7'd0                ;  // A=0  M=0  A-M = 0
     4'd1    : c_tmp =  { 6'd0 ,b_tmp[    0] };  // A=1  M=1  A-M = 0
     4'd2    : c_tmp =  { 5'd0 ,b_tmp[ 1: 0] };  // A=2  M=2  A-M = 0
     4'd3    : c_tmp =  { 4'd0 ,b_tmp[ 2: 0] };  // A=3  M=3  A-M = 0
     4'd4    : c_tmp =  { 3'd0 ,b_tmp[ 3: 0] };  // A=4  M=4  A-M = 0
     4'd5    : c_tmp =  { 2'd0 ,b_tmp[ 4: 0] };  // A=5  M=5  A-M = 0
     4'd6    : c_tmp =  { 1'd0 ,b_tmp[ 5: 0] };  // A=6  M=6  A-M = 0
     4'd7    : c_tmp =  {       b_tmp[ 6: 0] };  // A=7  M=7  A-M = 0
     4'd8    : c_tmp =  {       b_tmp[ 7: 1] };  // A=8  M=7  A-M = 1
     4'd9    : c_tmp =  {       b_tmp[ 8: 2] };  // A=9  M=7  A-M = 2
     4'd10   : c_tmp =  {       b_tmp[ 9: 3] };  // A=10 M=7  A-M = 3
     4'd11   : c_tmp =  {       b_tmp[10: 4] };  // A=11 M=7  A-M = 4
     4'd12   : c_tmp =  {       b_tmp[11: 5] };  // A=12 M=7  A-M = 5
     4'd13   : c_tmp =  {       b_tmp[12: 6] };  // A=13 M=7  A-M = 6
     default : c_tmp =  {       b_tmp[12: 6] };
 endcase
end


//-----------------------------------------------------------
reg [ 3:0] a_tmp_d1;
reg [16:0] b_tmp2_d1;
reg [ 6:0] c_tmp_d1;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
     a_tmp_d1  <=  0;
     b_tmp2_d1 <=  0;
     c_tmp_d1  <=  0;
   end
   else if(pipe_en)
   begin
     a_tmp_d1  <= a_tmp;  
     b_tmp2_d1 <= b_tmp2;  
     c_tmp_d1  <= c_tmp;  
   end
end


//-----------------------------------------------------------
// table_adr used directly (no -1 subtractor on the critical path);
// table1/table2 are re-indexed by +1 to compensate. table_adr==4'h0
// (old underflow case) reuses the old default (last-segment) value.
wire [3:0] table_adr = b_tmp2_d1[3:0];

reg [9:0] table1;
always@(*)
begin
   case(table_adr)
     4'h1    : table1 =  10'd0    ;
     4'h2    : table1 =  10'd256  ;
     4'h3    : table1 =  10'd406  ;
     4'h4    : table1 =  10'd512  ;
     4'h5    : table1 =  10'd595  ;
     4'h6    : table1 =  10'd662  ;
     4'h7    : table1 =  10'd719  ;
     4'h8    : table1 =  10'd768  ;
     4'h9    : table1 =  10'd812  ;
     4'ha    : table1 =  10'd851  ;
     4'hb    : table1 =  10'd886  ;
     4'hc    : table1 =  10'd918  ;
     4'hd    : table1 =  10'd948  ;
     4'he    : table1 =  10'd975  ;
     4'hf    : table1 =  10'd1001 ;
     default : table1 =  10'd1001 ; // table_adr == 4'h0
   endcase
end

reg [8:0] table2;
always@(*)
begin
   case(table_adr)
     4'h1    : table2 =  9'd256 ;
     4'h2    : table2 =  9'd150 ;
     4'h3    : table2 =  9'd107 ;
     4'h4    : table2 =  9'd83  ;
     4'h5    : table2 =  9'd68  ;
     4'h6    : table2 =  9'd57  ;
     4'h7    : table2 =  9'd50  ;
     4'h8    : table2 =  9'd44  ;
     4'h9    : table2 =  9'd39  ;
     4'ha    : table2 =  9'd36  ;
     4'hb    : table2 =  9'd33  ;
     4'hc    : table2 =  9'd30  ;
     4'hd    : table2 =  9'd28  ;
     4'he    : table2 =  9'd26  ;
     4'hf    : table2 =  9'd24  ;
     default : table2 =  9'd24  ; // table_adr == 4'h0
   endcase
end


//===================================
reg [9:0] table1_d2;
reg [8:0] table2_d2;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
      table1_d2 <= 10'd0;
      table2_d2 <= 9'd0;
   end
   else if(pipe_en)
   begin
      table1_d2 <= table1; 
      table2_d2 <= table2;
   end
end
                
reg [ 3:0] a_tmp_d2;
reg [ 6:0] c_tmp_d2;
always@(negedge RESETN or posedge ISP_CLK)
begin
   if(~RESETN)
   begin
     a_tmp_d2  <=  0;
     c_tmp_d2  <=  0;
   end
   else if(pipe_en)
   begin
     a_tmp_d2  <= a_tmp_d1 ;
     c_tmp_d2  <= c_tmp_d1 ;
   end
end


wire [15:0] c_t = table2_d2 * c_tmp_d2;

reg [15:0] C_sft_M;
always@(*)
begin
   case(a_tmp_d2) // 0~13
     4'd0    : C_sft_M =          c_t; 
     4'd1    : C_sft_M =  { 1'd0 ,c_t[15: 1] };
     4'd2    : C_sft_M =  { 2'd0 ,c_t[15: 2] };
     4'd3    : C_sft_M =  { 3'd0 ,c_t[15: 3] };
     4'd4    : C_sft_M =  { 4'd0 ,c_t[15: 4] };
     4'd5    : C_sft_M =  { 5'd0 ,c_t[15: 5] };
     4'd6    : C_sft_M =  { 6'd0 ,c_t[15: 6] };
     4'd7    : C_sft_M =  { 7'd0 ,c_t[15: 7] };
     default : C_sft_M =  { 7'd0 ,c_t[15: 7] };
 endcase
end

wire [11:0] A_sft_8 = {a_tmp_d2,8'd0};

wire [16:0] dat_out_t = A_sft_8 + C_sft_M + table1_d2;


//===================================
reg [16:0] dat_out_d3;
always@(negedge RESETN or posedge ISP_CLK) if(~RESETN) dat_out_d3 <= 0; else if(pipe_en) dat_out_d3 <= dat_out_t;

                  
assign dat_out = dat_out_d3;

endmodule