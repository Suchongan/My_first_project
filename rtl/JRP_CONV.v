module JRP_CONV
#(
    parameter   HBit = 11,
    parameter   VBit = 11,
    parameter   DBit = 10
)
(

input [DBit*25-1:0]Pxd_window_5x5_pipe0,
input [DBit*25-1:0]Pxd_window_5x5_pipe1,
input [DBit*25-1:0]Pxd_window_5x5_pipe2,
input              RSTN,
input              CLK,
input              pipe_en,

output [DBit  :0] Gx  , //sign
output [DBit  :0] Gy  , //sign
output [DBit-1:0] Gx_abs,
output [DBit-1:0] Gy_abs,
output [DBit+1:0] CR1 ,
output [DBit+1:0] CR2 ,
output [DBit+1:0] CR3 ,
output [DBit+1:0] CR4 ,
output [DBit-1:0] C1  ,
output [DBit-1:0] Ls0 ,
output [DBit-1:0] Ls1 ,
output [DBit-1:0] Ls2 ,
output [DBit-1:0] Ls3 ,
output [DBit-1:0] Ls4 ,
output [DBit-1:0] Ls5 ,
output [DBit-1:0] Ls6 ,
output [DBit-1:0] Ls7 ,
output [DBit-1:0] Ls8

);

wire [DBit-1:0]  p11, p12, p13, p14, p15,
                 p21, p22, p23, p24, p25,
                 p31, p32, p33, p34, p35,
                 p41, p42, p43, p44, p45,
                 p51, p52, p53, p54, p55;

assign  { p11, p12, p13, p14, p15,
          p21, p22, p23, p24, p25,
          p31, p32, p33, p34, p35,
          p41, p42, p43, p44, p45,
          p51, p52, p53, p54, p55 } = Pxd_window_5x5_pipe0;

wire [DBit-1:0]  p11_d1, p12_d1, p13_d1, p14_d1, p15_d1,
                 p21_d1, p22_d1, p23_d1, p24_d1, p25_d1,
                 p31_d1, p32_d1, p33_d1, p34_d1, p35_d1,
                 p41_d1, p42_d1, p43_d1, p44_d1, p45_d1,
                 p51_d1, p52_d1, p53_d1, p54_d1, p55_d1;

assign  { p11_d1, p12_d1, p13_d1, p14_d1, p15_d1,
          p21_d1, p22_d1, p23_d1, p24_d1, p25_d1,
          p31_d1, p32_d1, p33_d1, p34_d1, p35_d1,
          p41_d1, p42_d1, p43_d1, p44_d1, p45_d1,
          p51_d1, p52_d1, p53_d1, p54_d1, p55_d1 } = Pxd_window_5x5_pipe1;


wire [DBit-1:0]   p11_d2, p12_d2, p13_d2, p14_d2, p15_d2,
                  p21_d2, p22_d2, p23_d2, p24_d2, p25_d2,
                  p31_d2, p32_d2, p33_d2, p34_d2, p35_d2,
                  p41_d2, p42_d2, p43_d2, p44_d2, p45_d2,
                  p51_d2, p52_d2, p53_d2, p54_d2, p55_d2;

assign  { p11_d2, p12_d2, p13_d2, p14_d2, p15_d2,
          p21_d2, p22_d2, p23_d2, p24_d2, p25_d2,
          p31_d2, p32_d2, p33_d2, p34_d2, p35_d2,
          p41_d2, p42_d2, p43_d2, p44_d2, p45_d2,
          p51_d2, p52_d2, p53_d2, p54_d2, p55_d2  } = Pxd_window_5x5_pipe2;

// 0 5 10 15 20
// 1 6 11 16 21
// 2 7 12 17 22
// 3 8 13 18 23
// 4 9 14 19 24

wire [DBit:0] TwoPixSum_00_01_t = p11 + p21;
wire [DBit:0] TwoPixSum_01_02_t = p21 + p31;
wire [DBit:0] TwoPixSum_02_03_t = p31 + p41;
wire [DBit:0] TwoPixSum_03_04_t = p41 + p51;

wire [DBit:0] TwoPixSum_05_06_t = p12 + p22;
wire [DBit:0] TwoPixSum_06_07_t = p22 + p32;
wire [DBit:0] TwoPixSum_07_08_t = p32 + p42;
wire [DBit:0] TwoPixSum_08_09_t = p42 + p52;

wire [DBit:0] TwoPixSum_10_11_t = p13 + p23;
wire [DBit:0] TwoPixSum_11_12_t = p23 + p33;
wire [DBit:0] TwoPixSum_12_13_t = p33 + p43;
wire [DBit:0] TwoPixSum_13_14_t = p43 + p53;

wire [DBit:0] TwoPixSum_15_16_t = p14 + p24;
wire [DBit:0] TwoPixSum_16_17_t = p24 + p34;
wire [DBit:0] TwoPixSum_17_18_t = p34 + p44;
wire [DBit:0] TwoPixSum_18_19_t = p44 + p54;

wire [DBit:0] TwoPixSum_20_21_t = p15 + p25;
wire [DBit:0] TwoPixSum_21_22_t = p25 + p35;
wire [DBit:0] TwoPixSum_22_23_t = p35 + p45;
wire [DBit:0] TwoPixSum_23_24_t = p45 + p55;


//========================Deley 1T==============================
reg [DBit:0] TwoPixSum_00_01 ;
reg [DBit:0] TwoPixSum_01_02 ;
reg [DBit:0] TwoPixSum_02_03 ;
reg [DBit:0] TwoPixSum_03_04 ;
reg [DBit:0] TwoPixSum_05_06 ;
reg [DBit:0] TwoPixSum_06_07 ;
reg [DBit:0] TwoPixSum_07_08 ;
reg [DBit:0] TwoPixSum_08_09 ;
reg [DBit:0] TwoPixSum_10_11 ;
reg [DBit:0] TwoPixSum_11_12 ;
reg [DBit:0] TwoPixSum_12_13 ;
reg [DBit:0] TwoPixSum_13_14 ;
reg [DBit:0] TwoPixSum_15_16 ;
reg [DBit:0] TwoPixSum_16_17 ;
reg [DBit:0] TwoPixSum_17_18 ;
reg [DBit:0] TwoPixSum_18_19 ;
reg [DBit:0] TwoPixSum_20_21 ;
reg [DBit:0] TwoPixSum_21_22 ;
reg [DBit:0] TwoPixSum_22_23 ;
reg [DBit:0] TwoPixSum_23_24 ;

always@(negedge RSTN or posedge CLK)
begin
   if(~RSTN)
   begin
     TwoPixSum_00_01 <= 0;
     TwoPixSum_01_02 <= 0;
     TwoPixSum_02_03 <= 0;
     TwoPixSum_03_04 <= 0;
     TwoPixSum_05_06 <= 0;
     TwoPixSum_06_07 <= 0;
     TwoPixSum_07_08 <= 0;
     TwoPixSum_08_09 <= 0;
     TwoPixSum_10_11 <= 0;
     TwoPixSum_11_12 <= 0;
     TwoPixSum_12_13 <= 0;
     TwoPixSum_13_14 <= 0;
     TwoPixSum_15_16 <= 0;
     TwoPixSum_16_17 <= 0;
     TwoPixSum_17_18 <= 0;
     TwoPixSum_18_19 <= 0;
     TwoPixSum_20_21 <= 0;
     TwoPixSum_21_22 <= 0;
     TwoPixSum_22_23 <= 0;
     TwoPixSum_23_24 <= 0;

   end
   else if(pipe_en)
   begin
     TwoPixSum_00_01 <= TwoPixSum_00_01_t;
     TwoPixSum_01_02 <= TwoPixSum_01_02_t;
     TwoPixSum_02_03 <= TwoPixSum_02_03_t;
     TwoPixSum_03_04 <= TwoPixSum_03_04_t;
     TwoPixSum_05_06 <= TwoPixSum_05_06_t;
     TwoPixSum_06_07 <= TwoPixSum_06_07_t;
     TwoPixSum_07_08 <= TwoPixSum_07_08_t;
     TwoPixSum_08_09 <= TwoPixSum_08_09_t;
     TwoPixSum_10_11 <= TwoPixSum_10_11_t;
     TwoPixSum_11_12 <= TwoPixSum_11_12_t;
     TwoPixSum_12_13 <= TwoPixSum_12_13_t;
     TwoPixSum_13_14 <= TwoPixSum_13_14_t;
     TwoPixSum_15_16 <= TwoPixSum_15_16_t;
     TwoPixSum_16_17 <= TwoPixSum_16_17_t;
     TwoPixSum_17_18 <= TwoPixSum_17_18_t;
     TwoPixSum_18_19 <= TwoPixSum_18_19_t;
     TwoPixSum_20_21 <= TwoPixSum_20_21_t;
     TwoPixSum_21_22 <= TwoPixSum_21_22_t;
     TwoPixSum_22_23 <= TwoPixSum_22_23_t;
     TwoPixSum_23_24 <= TwoPixSum_23_24_t;
   end
end


wire [DBit+1:0] CR1_t0  = sum2conv_element(TwoPixSum_00_01,TwoPixSum_05_06);
wire [DBit+1:0] CR1_t1  = sum2conv_element(TwoPixSum_15_16,TwoPixSum_20_21);
wire [DBit+2:0] CR1_t2  = CR1_t0 - CR1_t1;
wire [DBit+1:0] CR1_abs = Abs_13bit(CR1_t2);

wire [DBit+1:0] CR2_t0  = sum2conv_element(TwoPixSum_03_04,TwoPixSum_08_09);
wire [DBit+1:0] CR2_t1  = sum2conv_element(TwoPixSum_18_19,TwoPixSum_23_24);
wire [DBit+2:0] CR2_t2  = CR2_t0 - CR2_t1;
wire [DBit+1:0] CR2_abs = Abs_13bit(CR2_t2);

wire [DBit+1:0] CR3_t0  = sum2conv_element(TwoPixSum_00_01,TwoPixSum_05_06);
wire [DBit+1:0] CR3_t1  = sum2conv_element(TwoPixSum_03_04,TwoPixSum_08_09);
wire [DBit+2:0] CR3_t2  = CR3_t0 - CR3_t1;
wire [DBit+1:0] CR3_abs = Abs_13bit(CR3_t2);

wire [DBit+1:0] CR4_t0  = sum2conv_element(TwoPixSum_15_16,TwoPixSum_20_21);
wire [DBit+1:0] CR4_t1  = sum2conv_element(TwoPixSum_18_19,TwoPixSum_23_24);
wire [DBit+2:0] CR4_t2  = CR4_t0 - CR4_t1;
wire [DBit+1:0] CR4_abs = Abs_13bit(CR4_t2);

wire [DBit+2:0] GradX_L0    = sum4conv_element(TwoPixSum_00_01,TwoPixSum_01_02,TwoPixSum_02_03,TwoPixSum_03_04);
wire [DBit+1:0] GradX_L1    = sum2conv_element(TwoPixSum_06_07,TwoPixSum_07_08);
wire [DBit+2:0] GradX_L1_2x = {GradX_L1,1'd0};
wire [DBit+2:0] GradX_R0    = sum4conv_element(TwoPixSum_20_21,TwoPixSum_21_22,TwoPixSum_22_23,TwoPixSum_23_24);
wire [DBit+1:0] GradX_R1    = sum2conv_element(TwoPixSum_16_17,TwoPixSum_17_18);
wire [DBit+2:0] GradX_R1_2x = {GradX_R1,1'd0};
wire [DBit+3:0] GradX_L_tmp = {1'd0,GradX_L0} + {1'd0,GradX_L1_2x};
wire [DBit+3:0] GradX_R_tmp = {1'd0,GradX_R0} + {1'd0,GradX_R1_2x};


wire [DBit+2:0] GradY_U0_t = sum3conv_element(TwoPixSum_05_06,TwoPixSum_10_11,TwoPixSum_15_16);
wire [DBit+2:0] GradY_D0_t = sum3conv_element(TwoPixSum_08_09,TwoPixSum_13_14,TwoPixSum_18_19);

wire [DBit+1:0] Small_corner_t = sum4pix(p22_d1,p24_d1,p42_d1,p44_d1);
wire [DBit+1:0] Small_cross_t  = sum4pix(p23_d1,p32_d1,p43_d1,p34_d1);//0~4092

wire [DBit+2:0] Ls0_LR_t  = sum4conv_element(TwoPixSum_00_01,TwoPixSum_01_02,TwoPixSum_10_11,TwoPixSum_11_12);
wire [DBit+2:0] Ls1_LR_t  = sum4conv_element(TwoPixSum_05_06,TwoPixSum_06_07,TwoPixSum_15_16,TwoPixSum_16_17);
wire [DBit+2:0] Ls2_LR_t  = sum4conv_element(TwoPixSum_10_11,TwoPixSum_11_12,TwoPixSum_20_21,TwoPixSum_21_22);
wire [DBit+2:0] Ls3_LR_t  = sum4conv_element(TwoPixSum_01_02,TwoPixSum_02_03,TwoPixSum_11_12,TwoPixSum_12_13);
wire [DBit+2:0] Ls4_LR_t  = sum4conv_element(TwoPixSum_06_07,TwoPixSum_07_08,TwoPixSum_16_17,TwoPixSum_17_18);
wire [DBit+2:0] Ls5_LR_t  = sum4conv_element(TwoPixSum_11_12,TwoPixSum_12_13,TwoPixSum_21_22,TwoPixSum_22_23);
wire [DBit+2:0] Ls6_LR_t  = sum4conv_element(TwoPixSum_02_03,TwoPixSum_03_04,TwoPixSum_12_13,TwoPixSum_13_14);
wire [DBit+2:0] Ls7_LR_t  = sum4conv_element(TwoPixSum_07_08,TwoPixSum_08_09,TwoPixSum_17_18,TwoPixSum_18_19);
wire [DBit+2:0] Ls8_LR_t  = sum4conv_element(TwoPixSum_12_13,TwoPixSum_13_14,TwoPixSum_22_23,TwoPixSum_23_24);

wire [DBit+1:0] Ls0__M_t  = sum2conv_element(TwoPixSum_05_06,TwoPixSum_06_07);
wire [DBit+1:0] Ls1__M_t  = sum2conv_element(TwoPixSum_10_11,TwoPixSum_11_12);
wire [DBit+1:0] Ls2__M_t  = sum2conv_element(TwoPixSum_15_16,TwoPixSum_16_17);
wire [DBit+1:0] Ls3__M_t  = sum2conv_element(TwoPixSum_06_07,TwoPixSum_07_08);
wire [DBit+1:0] Ls4__M_t  = sum2conv_element(TwoPixSum_11_12,TwoPixSum_12_13);
wire [DBit+1:0] Ls5__M_t  = sum2conv_element(TwoPixSum_16_17,TwoPixSum_17_18);
wire [DBit+1:0] Ls6__M_t  = sum2conv_element(TwoPixSum_07_08,TwoPixSum_08_09);
wire [DBit+1:0] Ls7__M_t  = sum2conv_element(TwoPixSum_12_13,TwoPixSum_13_14);
wire [DBit+1:0] Ls8__M_t  = sum2conv_element(TwoPixSum_17_18,TwoPixSum_18_19);


//========================Deley 2T==============================
reg [DBit+1:0] CR1_reg,CR2_reg,CR3_reg,CR4_reg;
reg [DBit+3:0] GradX_L,GradX_R;
reg [DBit+2:0] GradY_U0;
reg [DBit+2:0] GradY_D0;
reg [DBit+1:0] Small_corner;
reg [DBit+1:0] Small_cross;
reg [DBit+2:0] Ls0_LR;
reg [DBit+2:0] Ls1_LR;
reg [DBit+2:0] Ls2_LR;
reg [DBit+2:0] Ls3_LR;
reg [DBit+2:0] Ls4_LR;
reg [DBit+2:0] Ls5_LR;
reg [DBit+2:0] Ls6_LR;
reg [DBit+2:0] Ls7_LR;
reg [DBit+2:0] Ls8_LR;
reg [DBit+1:0] Ls0__M;
reg [DBit+1:0] Ls1__M;
reg [DBit+1:0] Ls2__M;
reg [DBit+1:0] Ls3__M;
reg [DBit+1:0] Ls4__M;
reg [DBit+1:0] Ls5__M;
reg [DBit+1:0] Ls6__M;
reg [DBit+1:0] Ls7__M;
reg [DBit+1:0] Ls8__M;
always@(negedge RSTN or posedge CLK)
begin
   if(~RSTN)
   begin
     CR1_reg      <=  0;
     CR2_reg      <=  0;
     CR3_reg      <=  0;
     CR4_reg      <=  0;
     GradX_L      <=  0;
     GradX_R      <=  0;
     GradY_U0     <=  0;
     GradY_D0     <=  0;
     Small_corner <=  0;
     Small_cross  <=  0;
     Ls0_LR       <=  0;
     Ls1_LR       <=  0;
     Ls2_LR       <=  0;
     Ls3_LR       <=  0;
     Ls4_LR       <=  0;
     Ls5_LR       <=  0;
     Ls6_LR       <=  0;
     Ls7_LR       <=  0;
     Ls8_LR       <=  0;
     Ls0__M       <=  0;
     Ls1__M       <=  0;
     Ls2__M       <=  0;
     Ls3__M       <=  0;
     Ls4__M       <=  0;
     Ls5__M       <=  0;
     Ls6__M       <=  0;
     Ls7__M       <=  0;
     Ls8__M       <=  0;

   end
   else if(pipe_en)
   begin
     CR1_reg      <= CR1_abs;
     CR2_reg      <= CR2_abs;
     CR3_reg      <= CR3_abs;
     CR4_reg      <= CR4_abs;
     GradX_L      <= GradX_L_tmp;
     GradX_R      <= GradX_R_tmp;
     GradY_U0     <= GradY_U0_t;
     GradY_D0     <= GradY_D0_t;
     Small_corner <= Small_corner_t;
     Small_cross  <= Small_cross_t;
     Ls0_LR       <= Ls0_LR_t;
     Ls1_LR       <= Ls1_LR_t;
     Ls2_LR       <= Ls2_LR_t;
     Ls3_LR       <= Ls3_LR_t;
     Ls4_LR       <= Ls4_LR_t;
     Ls5_LR       <= Ls5_LR_t;
     Ls6_LR       <= Ls6_LR_t;
     Ls7_LR       <= Ls7_LR_t;
     Ls8_LR       <= Ls8_LR_t;
     Ls0__M       <= Ls0__M_t;
     Ls1__M       <= Ls1__M_t;
     Ls2__M       <= Ls2__M_t;
     Ls3__M       <= Ls3__M_t;
     Ls4__M       <= Ls4__M_t;
     Ls5__M       <= Ls5__M_t;
     Ls6__M       <= Ls6__M_t;
     Ls7__M       <= Ls7__M_t;
     Ls8__M       <= Ls8__M_t;

   end
end

assign CR1 = CR1_reg;
assign CR2 = CR2_reg;
assign CR3 = CR3_reg;
assign CR4 = CR4_reg;

wire [DBit+4:0] GradX_t            = {1'd0,GradX_R} - {1'd0,GradX_L}; //-16368~16368

wire [DBit+3:0] GradY_U0_2x        = {GradY_U0,1'd0}; //0~8190
wire [DBit+3:0] GradY_D0_2x        = {GradY_D0,1'd0}; //0~8190
wire [DBit  :0] p23_d2_2x          = {p23_d2,1'd0};   //0~2046
wire [DBit  :0] p43_d2_2x          = {p43_d2,1'd0};   //0~2046
wire [DBit  :0] GradY_corner_sum_U = {1'd0,p11_d2} + {1'd0,p15_d2}; //0~2046
wire [DBit  :0] GradY_corner_sum_D = {1'd0,p51_d2} + {1'd0,p55_d2}; //0~2046

wire [DBit+4:0] GradY_sum_U_t0      =  {1'd0,GradY_U0_2x}     + {4'd0,p23_d2_2x}; //0~10236
wire [DBit+4:0] GradY_sum_D_t0      =  {1'd0,GradY_D0_2x}     + {4'd0,p43_d2_2x}; //0~10236
wire [DBit+5:0] GradY_sum_U_t1      =  {1'd0,GradY_sum_U_t0}  + {5'd0,GradY_corner_sum_U }; //0~12282
wire [DBit+5:0] GradY_sum_D_t1      =  {1'd0,GradY_sum_D_t0}  + {5'd0,GradY_corner_sum_D } ; //0~12282
wire [DBit+3:0] GradY_sum_U_t2      =  GradY_sum_U_t1[13:0]; //0~12282
wire [DBit+3:0] GradY_sum_D_t2      =  GradY_sum_D_t1[13:0]; //0~12282
wire [DBit+4:0] GradY_t             = {1'd0,GradY_sum_D_t2} - {1'd0,GradY_sum_U_t2}; //-12282~12282

wire [DBit+2:0] Small_cross_2x = {Small_cross,1'd0};
wire [DBit+1:0] Center_4x      = {p33_d2,2'd0};

wire [DBit+2:0] C1_t0 =  Center_4x  + Small_corner ; // 12bit + 12bit
wire [DBit+3:0] C1_t1 =  Small_cross_2x  -  C1_t0 ;  // 13bit - 13bit

wire [DBit:0] GradX_sft_t = GradX_t[14:4]; //-1023~1023
wire [DBit:0] GradY_sft_t = GradY_t[14:4]; //-767~767

wire [DBit-1:0] GradX_abs_t =  Abs_11bit(GradX_sft_t);
wire [DBit-1:0] GradY_abs_t =  Abs_11bit(GradY_sft_t);

wire [DBit+3:0] Ls0_t0 = MLs( Ls0_LR, {Ls0__M,1'd0} );
wire [DBit+3:0] Ls1_t0 = MLs( Ls1_LR, {Ls1__M,1'd0} );
wire [DBit+3:0] Ls2_t0 = MLs( Ls2_LR, {Ls2__M,1'd0} );
wire [DBit+3:0] Ls3_t0 = MLs( Ls3_LR, {Ls3__M,1'd0} );
wire [DBit+3:0] Ls4_t0 = MLs( Ls4_LR, {Ls4__M,1'd0} );
wire [DBit+3:0] Ls5_t0 = MLs( Ls5_LR, {Ls5__M,1'd0} );
wire [DBit+3:0] Ls6_t0 = MLs( Ls6_LR, {Ls6__M,1'd0} );
wire [DBit+3:0] Ls7_t0 = MLs( Ls7_LR, {Ls7__M,1'd0} );
wire [DBit+3:0] Ls8_t0 = MLs( Ls8_LR, {Ls8__M,1'd0} );

wire [DBit-1:0] Ls0_sft =  Ls0_t0[13:4];
wire [DBit-1:0] Ls1_sft =  Ls1_t0[13:4];
wire [DBit-1:0] Ls2_sft =  Ls2_t0[13:4];
wire [DBit-1:0] Ls3_sft =  Ls3_t0[13:4];
wire [DBit-1:0] Ls4_sft =  Ls4_t0[13:4];
wire [DBit-1:0] Ls5_sft =  Ls5_t0[13:4];
wire [DBit-1:0] Ls6_sft =  Ls6_t0[13:4];
wire [DBit-1:0] Ls7_sft =  Ls7_t0[13:4];
wire [DBit-1:0] Ls8_sft =  Ls8_t0[13:4];



//========================Deley 3T==============================
reg [DBit  :0] GradX_d3;
reg [DBit  :0] GradY_d3;
reg [DBit-1:0] GradX_abs_d3;
reg [DBit-1:0] GradY_abs_d3;
reg [DBit-1:0] C1_d3;
always@(negedge RSTN or posedge CLK)
begin
   if(~RSTN)
   begin
     GradX_d3     <=  0;
     GradY_d3     <=  0;
     GradX_abs_d3 <=  0;
     GradY_abs_d3 <=  0;
     C1_d3        <=  0;
   end
   else if(pipe_en)
   begin
     GradX_d3     <= GradX_sft_t;
     GradY_d3     <= GradY_sft_t;
     GradX_abs_d3 <= GradX_abs_t;
     GradY_abs_d3 <= GradY_abs_t;
     C1_d3        <= C1_t1[DBit+3:4];
   end
end

assign Gx     = GradX_d3;
assign Gy     = GradY_d3;
assign Gx_abs = GradX_abs_d3;
assign Gy_abs = GradY_abs_d3;
assign C1     = C1_d3;

reg [DBit-1:0] Ls0_d3;
reg [DBit-1:0] Ls1_d3;
reg [DBit-1:0] Ls2_d3;
reg [DBit-1:0] Ls3_d3;
reg [DBit-1:0] Ls4_d3;
reg [DBit-1:0] Ls5_d3;
reg [DBit-1:0] Ls6_d3;
reg [DBit-1:0] Ls7_d3;
reg [DBit-1:0] Ls8_d3;
always@(negedge RSTN or posedge CLK)
begin
   if(~RSTN)
   begin
     Ls0_d3 <= 0;
     Ls1_d3 <= 0;
     Ls2_d3 <= 0;
     Ls3_d3 <= 0;
     Ls4_d3 <= 0;
     Ls5_d3 <= 0;
     Ls6_d3 <= 0;
     Ls7_d3 <= 0;
     Ls8_d3 <= 0;

   end
   else if(pipe_en)
   begin
     Ls0_d3 <=  Ls0_sft;
     Ls1_d3 <=  Ls1_sft;
     Ls2_d3 <=  Ls2_sft;
     Ls3_d3 <=  Ls3_sft;
     Ls4_d3 <=  Ls4_sft;
     Ls5_d3 <=  Ls5_sft;
     Ls6_d3 <=  Ls6_sft;
     Ls7_d3 <=  Ls7_sft;
     Ls8_d3 <=  Ls8_sft;

   end
end

assign Ls0 = Ls0_d3;
assign Ls1 = Ls1_d3;
assign Ls2 = Ls2_d3;
assign Ls3 = Ls3_d3;
assign Ls4 = Ls4_d3;
assign Ls5 = Ls5_d3;
assign Ls6 = Ls6_d3;
assign Ls7 = Ls7_d3;
assign Ls8 = Ls8_d3;


/////////////////////////////////////
//
/////////////////////////////////////


//================================
function    [DBit+1:0]  sum2conv_element;
input       [DBit  :0]  D0, D1;

begin
 sum2conv_element  = {1'd0,D0} + {1'd0,D1};
end
endfunction

function    [DBit+2:0]  sum3conv_element;
input       [DBit  :0]  D0, D1 ,D2;

begin
 sum3conv_element  = {2'd0,D0} + {2'd0,D1} + {2'd0,D2};
end
endfunction

function    [DBit+2:0]  sum4conv_element;
input       [DBit:0]  D0, D1 ,D2 ,D3;
reg [DBit+3:0] sum4conv_element_sum0;
reg [DBit+2:0] sum4conv_element_sum1;
begin
 sum4conv_element_sum0 = {3'd0,D0} + {3'd0,D1} + {3'd0,D2} + {3'd0,D3};
 sum4conv_element_sum1 = sum4conv_element_sum0[DBit+2:0];
 sum4conv_element      = sum4conv_element_sum1;
end
endfunction



function [11:0] Abs_13bit;
    input [12:0] X;
    reg [12:0] Abs_13bit_t;
    begin
        Abs_13bit_t = X[12] ? -X[11:0] : {1'd0, X[11:0]};
        Abs_13bit   = Abs_13bit_t[11:0];
    end
endfunction

function [9:0] Abs_11bit;
    input [10:0] X;
    reg [10:0] Abs_11bit_t;
    begin
        Abs_11bit_t = X[10] ? -X[9:0] : {1'd0, X[9:0]};
        Abs_11bit   = Abs_11bit_t[9:0];
    end
endfunction

function    [11:0]  sum4pix;
input       [9:0]   D0, D1, D2, D3;
reg         [11:0]  sum4tmp0;

begin

    sum4pix = D0 + D1 + D2 + D3;
end
endfunction


function [DBit+3:0] MLs;
input    [DBit+2:0] DLR, DM;
reg [DBit+3:0] tmp0;
reg [DBit+4:0] tmp1;
   begin
      tmp0 = DLR + DM;
      tmp1 = tmp0 + 8;
      MLs  = tmp1[DBit+3:0];
   end
endfunction


endmodule
