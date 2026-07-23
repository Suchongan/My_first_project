module JRP_func2_19bit(
                          RESETN, ISP_CLK, pipe_en,
                          dat_in, dat_out
                         );

//===========================================================
// 256 * log2(X) approximation, extended for 19-bit input.
//   - Input  : 19-bit  [18:0]  (was 17-bit [16:0])
//   - Output : 17-bit  [16:0]  (unchanged: max value ~ 256*log2(2^19-1) ~= 4864, fits in 13 bits)
// The MSB can now sit at bit 18/17, so the leading-one detector,
// the mantissa right-shift (b_tmp2) and the residual field (c_tmp)
// are extended. Tables and the back-end stay unchanged because the
// +768 (=3*256) offset baked into table1 still holds: a_tmp = MSB-3.
//===========================================================

input         RESETN ;
input         ISP_CLK;
input         pipe_en;
input  [18:0] dat_in ;   // 19-bit input
output [16:0] dat_out;

//-----------------------------------------------------------
//wire [23:0] b_tmp = {1'b0, dat_in} + 1;//B=X+1
wire [18:0] b_tmp = dat_in;

// Leading-one position -> characteristic (a_tmp = MSB_position - 3)
wire [3:0] a_tmp = (b_tmp[18] == 1'b1) ? 4'd15 :   // new for 19-bit
                   (b_tmp[17] == 1'b1) ? 4'd14 :   // new for 19-bit
                   (b_tmp[16] == 1'b1) ? 4'd13 :
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

// Normalized mantissa = X >> a_tmp  (only [3:0] is used downstream)
reg [18:0] b_tmp2;
always@(*)
begin
   case(a_tmp)
     4'd0    : b_tmp2 =         b_tmp; 
     4'd1    : b_tmp2 =  {1'd0 ,b_tmp[18:1 ] };
     4'd2    : b_tmp2 =  {2'd0 ,b_tmp[18:2 ] };
     4'd3    : b_tmp2 =  {3'd0 ,b_tmp[18:3 ] };
     4'd4    : b_tmp2 =  {4'd0 ,b_tmp[18:4 ] };
     4'd5    : b_tmp2 =  {5'd0 ,b_tmp[18:5 ] };
     4'd6    : b_tmp2 =  {6'd0 ,b_tmp[18:6 ] };
     4'd7    : b_tmp2 =  {7'd0 ,b_tmp[18:7 ] };
     4'd8    : b_tmp2 =  {8'd0 ,b_tmp[18:8 ] };
     4'd9    : b_tmp2 =  {9'd0 ,b_tmp[18:9 ] };
     4'd10   : b_tmp2 =  {10'd0,b_tmp[18:10] };
     4'd11   : b_tmp2 =  {11'd0,b_tmp[18:11] };
     4'd12   : b_tmp2 =  {12'd0,b_tmp[18:12] };
     4'd13   : b_tmp2 =  {13'd0,b_tmp[18:13] };
     4'd14   : b_tmp2 =  {14'd0,b_tmp[18:14] };   // new for 19-bit
     4'd15   : b_tmp2 =  {15'd0,b_tmp[18:15] };   // new for 19-bit
     default : b_tmp2 =  {15'd0,b_tmp[18:15] };
 endcase
end

// Residual field below the 4 mantissa bits, 7-bit (M=7)
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
     4'd14   : c_tmp =  {       b_tmp[13: 7] };  // A=14 M=7  A-M = 7   // new for 19-bit
     4'd15   : c_tmp =  {       b_tmp[14: 8] };  // A=15 M=7  A-M = 8   // new for 19-bit
     default : c_tmp =  {       b_tmp[14: 8] };
 endcase
end

//-----------------------------------------------------------
reg [ 3:0] a_tmp_d1;
reg [18:0] b_tmp2_d1;   // widened to 19-bit (only [3:0] used)
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
wire [4:0] table_adr_t = {1'd0,b_tmp2_d1[3:0]} - 5'd1;
wire [3:0] table_adr   = table_adr_t[3:0];

wire [9:0] table1 = ( table_adr == 4'h0) ?  10'd0    :
                    ( table_adr == 4'h1) ?  10'd256  :
                    ( table_adr == 4'h2) ?  10'd406  :
                    ( table_adr == 4'h3) ?  10'd512  :
                    ( table_adr == 4'h4) ?  10'd595  :
                    ( table_adr == 4'h5) ?  10'd662  :
                    ( table_adr == 4'h6) ?  10'd719  :
                    ( table_adr == 4'h7) ?  10'd768  :
                    ( table_adr == 4'h8) ?  10'd812  :
                    ( table_adr == 4'h9) ?  10'd851  :
                    ( table_adr == 4'ha) ?  10'd886  :
                    ( table_adr == 4'hb) ?  10'd918  :
                    ( table_adr == 4'hc) ?  10'd948  :
                    ( table_adr == 4'hd) ?  10'd975  :
                    ( table_adr == 4'he) ?  10'd1001 : 10'd1001 ;

wire [8:0] table2 = ( table_adr == 4'h0) ?  9'd256  :
                    ( table_adr == 4'h1) ?  9'd150  :
                    ( table_adr == 4'h2) ?  9'd107  :
                    ( table_adr == 4'h3) ?  9'd83   :
                    ( table_adr == 4'h4) ?  9'd68   :
                    ( table_adr == 4'h5) ?  9'd57   :
                    ( table_adr == 4'h6) ?  9'd50   :
                    ( table_adr == 4'h7) ?  9'd44   :
                    ( table_adr == 4'h8) ?  9'd39   :
                    ( table_adr == 4'h9) ?  9'd36   :
                    ( table_adr == 4'ha) ?  9'd33   :
                    ( table_adr == 4'hb) ?  9'd30   :
                    ( table_adr == 4'hc) ?  9'd28   :
                    ( table_adr == 4'hd) ?  9'd26   :
                    ( table_adr == 4'he) ?  9'd24   : 9'd24 ;


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

// Slope-scaled interpolation term. For A>=7 the extra (A-7) shift was
// already applied inside c_tmp, so here the shift saturates at 7.
// a_tmp_d2 = 14/15 both fall into 'default' (shift by 7), which is correct.
reg [15:0] C_sft_M;
always@(*)
begin
   case(a_tmp_d2) // 0~15
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

wire [11:0] A_sft_8 = {a_tmp_d2,8'd0};   // a_tmp_d2 up to 15 -> max 3840

wire [16:0] dat_out_t = A_sft_8 + C_sft_M + table1_d2;


//===================================
reg [16:0] dat_out_d3;
always@(negedge RESETN or posedge ISP_CLK) if(~RESETN) dat_out_d3 <= 0; else if(pipe_en) dat_out_d3 <= dat_out_t;

                  
assign dat_out = dat_out_d3;

endmodule