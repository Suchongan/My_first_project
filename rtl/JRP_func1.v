module JRP_func1(
                     dat_in, dat_out,RSTN,CLK,pipe_en
                    );

//dat_out = 32*log2(dat_in)


input  [9:0]  dat_in;
output [8:0]  dat_out;//0~320
input         RSTN, CLK ,pipe_en;

//-----------------------------------------------------------
wire [10:0] b_tmp = {1'b0, dat_in} + 1;//(X+1)

//(b_tmp[11] == 1'b1) ? 4'd8 :
wire [3:0] a_tmp = (b_tmp[10] == 1'b1) ? 4'd7 :
                   (b_tmp[9]  == 1'b1) ? 4'd6 :
                   (b_tmp[8]  == 1'b1) ? 4'd5 :
                   (b_tmp[7]  == 1'b1) ? 4'd4 :
                   (b_tmp[6]  == 1'b1) ? 4'd3 :
                   (b_tmp[5]  == 1'b1) ? 4'd2 :
                   (b_tmp[4]  == 1'b1) ? 4'd1 : 4'd0;


//-----------------------------------------------------------
//(b_tmp[11]) ? b_tmp[11:8] :
wire [3:0] b_tmp2 =  (b_tmp[10]) ? b_tmp[10:7] :
                     (b_tmp[9] ) ? b_tmp[9:6]  :
                     (b_tmp[8] ) ? b_tmp[8:5]  :
                     (b_tmp[7] ) ? b_tmp[7:4]  :
                     (b_tmp[6] ) ? b_tmp[6:3]  :
                     (b_tmp[5] ) ? b_tmp[5:2]  :
                     (b_tmp[4] ) ? b_tmp[4:1]  : b_tmp[3:0];
                                   

//wire [5:0]  table_adr_t = {1'd0,b_tmp2} - 4'd1;
//wire [3:0]  table_adr   = table_adr_t[3:0];

wire [3:0]  table_adr   = b_tmp2;

reg [6:0] table1;
always@(*)
begin
   case(table_adr)
     4'd01 :   table1 = 7'd0  ;
     4'd02 :   table1 = 7'd32 ;
     4'd03 :   table1 = 7'd51 ;
     4'd04 :   table1 = 7'd64 ;
     4'd05 :   table1 = 7'd74 ;
     4'd06 :   table1 = 7'd83 ;
     4'd07 :   table1 = 7'd90 ;
     4'd08 :   table1 = 7'd96 ;
     4'd09 :   table1 = 7'd101;
     4'd10 :   table1 = 7'd106;
     4'd11 :   table1 = 7'd111;
     4'd12 :   table1 = 7'd115;
     4'd13 :   table1 = 7'd118;
     4'd14 :   table1 = 7'd122;
     4'd15 :   table1 = 7'd125;
     
     default : table1 = 7'd0;
 endcase
end

wire [8:0] A_sft5      = {a_tmp, 5'd0};
wire [9:0] A_add_table = {1'd0, A_sft5} + {3'd0, table1};

reg [8:0] func1_out;
always@(negedge RSTN or posedge CLK)
begin
   if(~RSTN)         func1_out  <= 9'd0;
   else if(pipe_en)  func1_out  <= A_add_table[8:0];
end


wire [8:0] dat_out = func1_out;

endmodule