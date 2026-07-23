module JRP_func4(
                     dat_in, 
                     dat_out,
                     RSTN,
                     CLK,
                     pipe_en
                    );




input  [7:0]  dat_in;
output [6:0]  dat_out;
input         RSTN, CLK ,pipe_en;


wire [8:0] b_tmp = {1'b0, dat_in} + 1;//(X+1)


wire [2:0] a_tmp = (b_tmp[8]  == 1'b1) ? 3'd5 :
                   (b_tmp[7]  == 1'b1) ? 3'd4 :
                   (b_tmp[6]  == 1'b1) ? 3'd3 :
                   (b_tmp[5]  == 1'b1) ? 3'd2 :
                   (b_tmp[4]  == 1'b1) ? 3'd1 : 3'd0;
                   

wire [3:0] b_tmp2 =  (b_tmp[8] ) ? b_tmp[8:5]  :
                     (b_tmp[7] ) ? b_tmp[7:4]  :
                     (b_tmp[6] ) ? b_tmp[6:3]  :
                     (b_tmp[5] ) ? b_tmp[5:2]  :
                     (b_tmp[4] ) ? b_tmp[4:1]  : b_tmp[3:0];
                     

/////////////////////////////////////          
reg [2:0] a_tmp_d1;
reg [3:0] b_tmp_d1;
always@(negedge RSTN or posedge CLK) 
begin
   if(~RSTN)
   begin
     a_tmp_d1 <=  0;
     b_tmp_d1 <=  0;


   end
   else if(pipe_en) 
   begin
     a_tmp_d1 <=  a_tmp;
     b_tmp_d1 <=  b_tmp2;
   end
end

wire [4:0] b_tmp_d1_minus_1 = {1'd0,b_tmp_d1} - 5'd1; //0~14
wire [3:0] table1_sel       = b_tmp_d1_minus_1[3:0];

reg [5:0] table1;
always@(*)
begin
   case(table1_sel)
     4'd00 :   table1 =  6'd0  ;
     4'd01 :   table1 =  6'd8  ;
     4'd02 :   table1 =  6'd13 ;
     4'd03 :   table1 =  6'd16 ;
     4'd04 :   table1 =  6'd19 ;
     4'd05 :   table1 =  6'd21 ;
     4'd06 :   table1 =  6'd23 ;
     4'd07 :   table1 =  6'd24 ;
     4'd08 :   table1 =  6'd26 ;
     4'd09 :   table1 =  6'd27 ;
     4'd10 :   table1 =  6'd28 ;
     4'd11 :   table1 =  6'd29 ;
     4'd12 :   table1 =  6'd30 ;
     4'd13 :   table1 =  6'd31 ;
     4'd14 :   table1 =  6'd32 ;
     default : table1 =  6'd32 ;
 endcase
end



/////////////////////////////////////
reg [2:0] a_tmp_d2;
reg [5:0] table1_d2;
always@(negedge RSTN or posedge CLK) 
begin
   if(~RSTN)
   begin
     a_tmp_d2  <=  0;
     table1_d2 <=  0;
   end
   else if(pipe_en) 
   begin
     a_tmp_d2  <=  a_tmp_d1;
     table1_d2 <=  table1;
   end
end

wire [5:0] a_tmp_d2_8x = {a_tmp_d2,3'd0};


wire [6:0] Y_t = {4'd0,a_tmp_d2_8x} + {1'd0,table1_d2};



/////////////////////////////////////
reg [6:0] Y_d3;
always@(negedge RSTN or posedge CLK) 
begin
   if(~RSTN)
   begin
     Y_d3  <=  0;

   end
   else if(pipe_en) 
   begin
     Y_d3  <=  Y_t;

   end
end

assign dat_out = Y_d3;



endmodule



