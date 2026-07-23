
module LSC_Func1(/*AUTOARG*/
   // Outputs
   dat_out,
   // Inputs
   dat_in, pipe_en, clk, rstn , RS_LSC_EnH_FB
                       );

input  [ 22:0] dat_in;
input          pipe_en;
input          clk;
input          rstn;
input          RS_LSC_EnH_FB;

output reg [15:0] dat_out;

//-----------------------------------------------------------
wire [23:0] b_tmp_t = {1'b0, dat_in} + 1;//X=X+1
wire [22:0] b_tmp   = b_tmp_t[23] ? 23'h7FFFFF : b_tmp_t[22:0];

//-----------------------------------------------------------


function [4:0] lead_idx;
    input [22:0] v;
    integer i;
    begin
        lead_idx = 5'd4;                 // default: no set bit in [22:5]
        for (i = 5; i <= 22; i = i + 1)  // ascending -> highest set bit wins
            if (v[i]) lead_idx = i[4:0];
    end
endfunction

wire [4:0] idx   = lead_idx(b_tmp);
wire [4:0] a_tmp = idx - 5'd4;   // idx==4 -> 0, else idx-4 (== original)

reg [4:0] a_tmp_reg;
reg [4:0] a_tmp_reg_d1;
reg [4:0] a_tmp_reg_d2;
always@(posedge clk or negedge rstn) begin
    if(~rstn)                         a_tmp_reg <= 5'd0;
    else if(pipe_en & RS_LSC_EnH_FB)  a_tmp_reg <= a_tmp;
end
always@(posedge clk or negedge rstn) begin
    if(~rstn)                         a_tmp_reg_d1 <= 5'd0;
    else if(pipe_en & RS_LSC_EnH_FB)  a_tmp_reg_d1 <= a_tmp_reg;
end
always@(posedge clk or negedge rstn) begin
    if(~rstn)                         a_tmp_reg_d2 <= 5'd0;
    else if(pipe_en & RS_LSC_EnH_FB)  a_tmp_reg_d2 <= a_tmp_reg_d1;
end


//a_tmp = 0~17
//(B>>1)
//while (B >= 32), B>>1
// Same 5-bit window as before, now selected by the shared idx.
reg [4:0] B_shift;
always@(*) begin
    case(idx) // synopsys parallel_case
    5'd22  : B_shift = b_tmp[ 22: 18];
    5'd21  : B_shift = b_tmp[ 21: 17];
    5'd20  : B_shift = b_tmp[ 20: 16];
    5'd19  : B_shift = b_tmp[ 19: 15];
    5'd18  : B_shift = b_tmp[ 18: 14];
    5'd17  : B_shift = b_tmp[ 17: 13];
    5'd16  : B_shift = b_tmp[ 16: 12];
    5'd15  : B_shift = b_tmp[ 15: 11];
    5'd14  : B_shift = b_tmp[ 14: 10];
    5'd13  : B_shift = b_tmp[ 13: 9 ];
    5'd12  : B_shift = b_tmp[ 12: 8 ];
    5'd11  : B_shift = b_tmp[ 11: 7 ];
    5'd10  : B_shift = b_tmp[ 10: 6 ];
    5'd9   : B_shift = b_tmp[ 9 : 5 ];
    5'd8   : B_shift = b_tmp[ 8 : 4 ];
    5'd7   : B_shift = b_tmp[ 7 : 3 ];
    5'd6   : B_shift = b_tmp[ 6 : 2 ];
    5'd5   : B_shift = b_tmp[ 5 : 1 ];
    default: B_shift = b_tmp[ 4 : 0 ]; // idx==4
    endcase
end

//C = ( X + 1 - ( B << A )) >> ( A - M )
// Same 7-bit field as before, now selected by the shared idx.
reg [6:0] c_tmp1;
always@(*) begin
    case(idx) // synopsys parallel_case
    5'd22  : c_tmp1 = {     b_tmp[17:11]};
    5'd21  : c_tmp1 = {     b_tmp[16:10]};
    5'd20  : c_tmp1 = {     b_tmp[15:9 ]};
    5'd19  : c_tmp1 = {     b_tmp[14:8 ]};
    5'd18  : c_tmp1 = {     b_tmp[13:7 ]};
    5'd17  : c_tmp1 = {     b_tmp[12:6 ]};
    5'd16  : c_tmp1 = {     b_tmp[11:5 ]};
    5'd15  : c_tmp1 = {     b_tmp[10:4 ]};
    5'd14  : c_tmp1 = {     b_tmp[9 :3 ]};
    5'd13  : c_tmp1 = {     b_tmp[8 :2 ]}; //a_tmp = 9 >>2
    5'd12  : c_tmp1 = {     b_tmp[7 :1 ]}; //a_tmp = 8 >>1
    5'd11  : c_tmp1 = {     b_tmp[6 :0 ]}; //a_tmp = 7 >>0
    5'd10  : c_tmp1 = {1'd0,b_tmp[5 :0 ]}; //a_tmp = 6 >>0
    5'd9   : c_tmp1 = {2'd0,b_tmp[4 :0 ]};
    5'd8   : c_tmp1 = {3'd0,b_tmp[3 :0 ]};
    5'd7   : c_tmp1 = {4'd0,b_tmp[2 :0 ]};
    5'd6   : c_tmp1 = {5'd0,b_tmp[1 :0 ]};
    5'd5   : c_tmp1 = {6'd0,b_tmp[   0 ]};
    default: c_tmp1 = 7'd0;                 // idx==4
    endcase
end

//-----------------------------------------------------------
//wire [4:0] table_adr = B_shift - 5'd1;
//wire [4:0] table_adr = B_shift;
reg [4:0] table_adr;
always@(posedge clk or negedge rstn) begin
    if(~rstn)                         table_adr <= 5'd0;
    else if(pipe_en & RS_LSC_EnH_FB)  table_adr <= B_shift;
end

reg [13:0] table1;
always@(*) begin
    case(table_adr) // synopsys parallel_case
    5'd1     : begin table1 = 14'd0 ;   end
    5'd2     : begin table1 = 14'd2048; end
    5'd3     : begin table1 = 14'd3247; end
    5'd4     : begin table1 = 14'd4096; end
    5'd5     : begin table1 = 14'd4756; end
    5'd6     : begin table1 = 14'd5295; end
    5'd7     : begin table1 = 14'd5750; end
    5'd8     : begin table1 = 14'd6144; end
    5'd9     : begin table1 = 14'd6493; end
    5'd10    : begin table1 = 14'd6804; end
    5'd11    : begin table1 = 14'd7085; end
    5'd12    : begin table1 = 14'd7343; end
    5'd13    : begin table1 = 14'd7579; end
    5'd14    : begin table1 = 14'd7798; end
    5'd15    : begin table1 = 14'd8002; end
    5'd16    : begin table1 = 14'd8192; end
    5'd17    : begin table1 = 14'd8372; end
    5'd18    : begin table1 = 14'd8541; end
    5'd19    : begin table1 = 14'd8700; end
    5'd20    : begin table1 = 14'd8852; end
    5'd21    : begin table1 = 14'd8996; end
    5'd22    : begin table1 = 14'd9133; end
    5'd23    : begin table1 = 14'd9265; end
    5'd24    : begin table1 = 14'd9391; end
    5'd25    : begin table1 = 14'd9511; end
    5'd26    : begin table1 = 14'd9627; end
    5'd27    : begin table1 = 14'd9739; end
    5'd28    : begin table1 = 14'd9846; end
    5'd29    : begin table1 = 14'd9950; end
    5'd30    : begin table1 = 14'd10050;end
    5'd31    : begin table1 = 14'd10147;end
    default :  begin table1 = 14'd0;    end
    endcase
end

reg [13:0] table1_reg;
always@(posedge clk or negedge rstn) begin
    if(~rstn)                                table1_reg <= 14'd0;
    else if(pipe_en & RS_LSC_EnH_FB)         table1_reg <= table1;
end


reg [11:0] table2;
always@(*) begin
    case(table_adr) // synopsys parallel_case
        5'd1   : begin table2 = 12'd2048; end
        5'd2   : begin table2 = 12'd1199; end
        5'd3   : begin table2 = 12'd850;  end
        5'd4   : begin table2 = 12'd660;  end
        5'd5   : begin table2 = 12'd539;  end
        5'd6   : begin table2 = 12'd456;  end
        5'd7   : begin table2 = 12'd395;  end
        5'd8   : begin table2 = 12'd349;  end
        5'd9   : begin table2 = 12'd312;  end
        5'd10  : begin table2 = 12'd282;  end
        5'd11  : begin table2 = 12'd258;  end
        5'd12  : begin table2 = 12'd237;  end
        5'd13  : begin table2 = 12'd219;  end
        5'd14  : begin table2 = 12'd204;  end
        5'd15  : begin table2 = 12'd191;  end
        5'd16  : begin table2 = 12'd180;  end
        5'd17  : begin table2 = 12'd169;  end
        5'd18  : begin table2 = 12'd160;  end
        5'd19  : begin table2 = 12'd152;  end
        5'd20  : begin table2 = 12'd145;  end
        5'd21  : begin table2 = 12'd138;  end
        5'd22  : begin table2 = 12'd132;  end
        5'd23  : begin table2 = 12'd126;  end
        5'd24  : begin table2 = 12'd121;  end
        5'd25  : begin table2 = 12'd116;  end
        5'd26  : begin table2 = 12'd112;  end
        5'd27  : begin table2 = 12'd108;  end
        5'd28  : begin table2 = 12'd104;  end
        5'd29  : begin table2 = 12'd101;  end
        5'd30  : begin table2 = 12'd97;   end
        5'd31  : begin table2 = 12'd94;   end
        default: begin table2 = 12'd2048; end
    endcase
end
//UInt16 Table2[31] = { 128, 75, 54, 42, 34, 29, 25, 22, 20, 18, 17, 15, 14, 13, 12 ,12 ,11, 10, 10, 10, 9, 9, 8, 8, 8, 7, 7, 7, 7, 7, 6 };


reg [11:0] table2_reg;
reg [6:0] c_tmp1_reg;
reg [6:0] c_tmp1_reg_d1;

always@(posedge clk or negedge rstn) begin
    if(~rstn)                            table2_reg <= 12'd0;
    else if(pipe_en & RS_LSC_EnH_FB)     table2_reg <= table2;
end
wire        table2_eq2048 = table2_reg[11];
wire [10:0] table2_mul    = table2_reg[10:0]; //94~1199


always@(posedge clk or negedge rstn) begin
    if(~rstn)                         c_tmp1_reg <= 7'd0;
    else if(pipe_en & RS_LSC_EnH_FB)  c_tmp1_reg <= c_tmp1;
end
always@(posedge clk or negedge rstn) begin
    if(~rstn)                           c_tmp1_reg_d1 <= 7'd0;
    else if(pipe_en & RS_LSC_EnH_FB)    c_tmp1_reg_d1 <= c_tmp1_reg;
end

wire [17:0] mul_p_t = {7'd0, table2_mul} * {11'd0,c_tmp1_reg_d1}; //11bit * 7bit
wire [17:0] mul_p   = table2_eq2048 ? {c_tmp1_reg_d1,11'd0} : mul_p_t;

//========================================================================================
reg [17:0] mul;
always@(posedge clk or negedge rstn) begin
    if(~rstn)                           mul <= 18'd0;
    else if(pipe_en & RS_LSC_EnH_FB)    mul <= mul_p;
end

reg [13:0] table1_reg_d1;
always@(posedge clk or negedge rstn) begin
    if(~rstn)                                table1_reg_d1 <= 14'd0;
    else if(pipe_en & RS_LSC_EnH_FB)         table1_reg_d1 <= table1_reg;
end


reg [10:0] c_tmp2;
//a_tmp_reg_d1 = 0~17
always@(*) begin
    case(a_tmp_reg_d2)
        5'd0   : c_tmp2 = mul[10 :0  ];
        5'd1   : c_tmp2 = mul[11 :1  ];
        5'd2   : c_tmp2 = mul[12 :2  ];
        5'd3   : c_tmp2 = mul[13 :3  ];
        5'd4   : c_tmp2 = mul[14 :4  ];
        5'd5   : c_tmp2 = mul[15 :5  ]; //a_tmp = 5  M=5
        5'd6   : c_tmp2 = mul[16 :6  ]; //a_tmp = 6  M=6
        5'd7   : c_tmp2 = mul[17 :7  ]; //a_tmp = 7  M=7
        5'd8   : c_tmp2 = mul[17 :7  ]; //a_tmp = 8  M=7
        5'd9   : c_tmp2 = mul[17 :7  ]; //a_tmp = 9  M=7
        5'd10  : c_tmp2 = mul[17 :7  ];
        5'd11  : c_tmp2 = mul[17 :7  ];
        5'd12  : c_tmp2 = mul[17 :7  ];
        5'd13  : c_tmp2 = mul[17 :7  ];
        5'd14  : c_tmp2 = mul[17 :7  ];
        5'd15  : c_tmp2 = mul[17 :7  ];
        5'd16  : c_tmp2 = mul[17 :7  ];
        5'd17  : c_tmp2 = mul[17 :7  ];
        default: c_tmp2 = mul[17 :7  ];
    endcase
end


// a_tmp_reg   5  bit
// table1_reg  14 bit
// c_tmp2      11 bit

wire [15:0] a_tmp_sft11_add_c_tmp2 = {a_tmp_reg_d2,c_tmp2};
wire [16:0] dat_out_t1             = {1'd0,a_tmp_sft11_add_c_tmp2} + {3'd0,table1_reg_d1}; //16bit + 14bit


//assign dat_out = dat_out_t1[15:0]; //0~45056 16bit



always@(posedge clk or negedge rstn) begin
    if(~rstn)                           dat_out <= 0;
    else if(pipe_en & RS_LSC_EnH_FB)    dat_out <= dat_out_t1[15:0];
end








endmodule
