module JRP_funcR(
           RSTN, CLK,pipe_en,
           dat_in, dat_out
       );
input             CLK;
input             RSTN;
input             pipe_en;
input  [9:0]      dat_in;
output reg [6:0]  dat_out;

//-----------------------------------------------------------

wire [8:0] L;

JRP_func1 JRP_func1(
          .dat_in  (dat_in    ),
          .dat_out (L         ),
          .RSTN    (RSTN      ),
          .CLK     (CLK       ),
          .pipe_en (pipe_en   )

);//1T



//-------------------Delay 1T-------------------------------
wire [2:0] A = L[8:6]; //0~5
wire [5:0] B = L[5:0]; //0~63


reg [6:0] TB; //T[B] + 32
always@(*)
begin
   case(B)
     6'd00 :   TB = 7'd32;
     6'd01 :   TB = 7'd32;
     6'd02 :   TB = 7'd33;
     6'd03 :   TB = 7'd34;
     6'd04 :   TB = 7'd35;
     6'd05 :   TB = 7'd35;
     6'd06 :   TB = 7'd36;
     6'd07 :   TB = 7'd37;
     6'd08 :   TB = 7'd38;
     6'd09 :   TB = 7'd38;
     6'd10 :   TB = 7'd39;
     6'd11 :   TB = 7'd40;
     6'd12 :   TB = 7'd41;
     6'd13 :   TB = 7'd42;
     6'd14 :   TB = 7'd42;
     6'd15 :   TB = 7'd43;
     6'd16 :   TB = 7'd44;
     6'd17 :   TB = 7'd45;
     6'd18 :   TB = 7'd46;
     6'd19 :   TB = 7'd46;
     6'd20 :   TB = 7'd47;
     6'd21 :   TB = 7'd48;
     6'd22 :   TB = 7'd49;
     6'd23 :   TB = 7'd50;
     6'd24 :   TB = 7'd51;
     6'd25 :   TB = 7'd52;
     6'd26 :   TB = 7'd53;
     6'd27 :   TB = 7'd54;
     6'd28 :   TB = 7'd55;
     6'd29 :   TB = 7'd55;
     6'd30 :   TB = 7'd56;
     6'd31 :   TB = 7'd57;
     6'd32 :   TB = 7'd58;
     6'd33 :   TB = 7'd59;
     6'd34 :   TB = 7'd60;
     6'd35 :   TB = 7'd61;
     6'd36 :   TB = 7'd62;
     6'd37 :   TB = 7'd63;
     6'd38 :   TB = 7'd64;
     6'd39 :   TB = 7'd65;
     6'd40 :   TB = 7'd67;
     6'd41 :   TB = 7'd68;
     6'd42 :   TB = 7'd69;
     6'd43 :   TB = 7'd70;
     6'd44 :   TB = 7'd71;
     6'd45 :   TB = 7'd72;
     6'd46 :   TB = 7'd73;
     6'd47 :   TB = 7'd74;
     6'd48 :   TB = 7'd76;
     6'd49 :   TB = 7'd77;
     6'd50 :   TB = 7'd78;
     6'd51 :   TB = 7'd79;
     6'd52 :   TB = 7'd80;
     6'd53 :   TB = 7'd81;
     6'd54 :   TB = 7'd83;
     6'd55 :   TB = 7'd84;
     6'd56 :   TB = 7'd85;
     6'd57 :   TB = 7'd87;
     6'd58 :   TB = 7'd88;
     6'd59 :   TB = 7'd89;
     6'd60 :   TB = 7'd91;
     6'd61 :   TB = 7'd92;
     6'd62 :   TB = 7'd93;
     6'd63 :   TB = 7'd95;
     
     default : TB = 7'd32;
 endcase
end


//-------------------Delay 2T-------------------------------
reg [6:0] TB_r; 
reg [2:0] A_r;
always@(negedge RSTN or posedge CLK) 
begin
   if(~RSTN)
   begin
     TB_r   <=  0;
     A_r    <=  0;
   end
   else if(pipe_en) 
   begin
     TB_r   <= TB;
     A_r    <=  A;
   end
end


reg [6:0] R_tmp ;
always@(*)
begin
   case(A_r)
     3'd0    :   R_tmp =  {5'd0,TB_r[6:5]};
     3'd1    :   R_tmp =  {4'd0,TB_r[6:4]};
     3'd2    :   R_tmp =  {3'd0,TB_r[6:3]};
     3'd3    :   R_tmp =  {2'd0,TB_r[6:2]};
     3'd4    :   R_tmp =  {1'd0,TB_r[6:1]};
     3'd5    :   R_tmp =  {     TB_r[6:0]};
     default :   R_tmp =  {     TB_r[6:0]};
 endcase
end

//-------------------Delay 3T-------------------------------




always@(negedge RSTN or posedge CLK) 
begin
   if(~RSTN)
   begin
     dat_out   <=  0;
   end
   else if(pipe_en) 
   begin
     dat_out   <= R_tmp;
   end
end










endmodule
