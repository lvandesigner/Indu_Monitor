module spi_master
#(
    parameter                           SYS_CLK                  = 28'd50_000_000   , //系统时钟频率
    parameter                           SPI_SCLK                 = 28'd100_000      , //SPI_SCLK频率
    parameter                           SPI_CPOL                 = 1'b0             , //时钟极性
    parameter                           SPI_CPHA                 = 1'b0               //时钟相位
)
(
    input                               spi_clk                                     ,
    input                               spi_rst                                     ,

    input  wire                         spi_cs_ctrl                                 ,//片选控制端口
    input  wire                         spi_wr_en                                   ,//传输使能
    input  wire        [   7: 0]        spi_data_in                                 ,//数据输入
    output wire        [   7: 0]        spi_data_out                                ,//数据输出
    output wire                         spi_wr_ack                                  ,//传输结束应答

//SPI物理端口
    output wire                         ds1302_ce                                    ,//片选端口
    output reg                          ds1302_sclk                                  ,//SPI时钟
    output wire                         spi_mosi                                     ,//用三态门进行构建
    input  wire                         spi_miso                  
);

    localparam                          IDLE                     = 0                 ; //空闲状态
    localparam                          H_SCLK_IDLE              = 1                 ; //SCLK前半周期
    localparam                          SCLK_EDGE                = 2                 ; //SCLK边沿时刻
    localparam                          L_HALF_CYCLE             = 3                 ; //SCLK后半周期
    localparam                          ACK                      = 4                 ; //应答
    localparam                          ACK_WAIT                 = 5                 ;     
    
    reg                [   3: 0]        spi_state                                    ;
    reg                [  27: 0]        spi_sclk_cnt                                 ;
    reg                [  27: 0]        spi_edge_cnt                                 ;

    reg                [   7: 0]        mosi_shift                                   ;
    reg                [   7: 0]        miso_shift                                   ;

    assign                              spi_mosi                 = mosi_shift[7]     ;
    assign                              spi_data_out             = miso_shift        ;
    assign                              ds1302_ce                = spi_cs_ctrl       ;
    assign                              spi_wr_ack               = (spi_state == ACK); 

always@(posedge spi_clk or posedge spi_rst) begin
    if(spi_rst)
        spi_state <= IDLE;
    else begin
        case(spi_state)
            IDLE      :
                if(spi_wr_en)
                    spi_state <= H_SCLK_IDLE;
                else
                    spi_state <= IDLE;
            H_SCLK_IDLE :
                if(spi_sclk_cnt == 'd50)
                    spi_state <= SCLK_EDGE;
                else 
                    spi_state <= H_SCLK_IDLE;
            SCLK_EDGE :
                if(spi_edge_cnt == 'd15)
                    spi_state <= L_HALF_CYCLE;
                else 
                    spi_state <= H_SCLK_IDLE; 
            L_HALF_CYCLE:
                if(spi_sclk_cnt == 'd50)
                    spi_state <= ACK;
                else 
                    spi_state <= L_HALF_CYCLE;
            ACK       :spi_state <= ACK_WAIT;
            ACK_WAIT  :spi_state <= IDLE;
            default:spi_state <= IDLE;
        endcase
    end
end

//ds1302_sclk SPI_SLCK时钟翻转
always@(posedge spi_clk or posedge spi_rst)	begin
	if(spi_rst)
        ds1302_sclk <= 'd0;
    else if(spi_state == IDLE)
        ds1302_sclk <= SPI_CPOL;
    else if(spi_state == SCLK_EDGE)
        ds1302_sclk <= ~ds1302_sclk;
    else 
        ds1302_sclk <= ds1302_sclk;
end

//spi_sclk_cnt: SPI_SLCK产生分频计数器
always@(posedge spi_clk or posedge spi_rst)	begin
	if(spi_rst)
        spi_sclk_cnt <= 'd0;
    else if(spi_state == IDLE)
        spi_sclk_cnt <= 'd0;
    else if(spi_state == H_SCLK_IDLE || spi_state == L_HALF_CYCLE)
        spi_sclk_cnt <= spi_sclk_cnt + 1'b1;
    else 
        spi_sclk_cnt <= 'd0;
end

//spi_edge_cnt:SPI_SCLK边沿计数器
always@(posedge spi_clk or posedge spi_rst)	begin
	if(spi_rst)
        spi_edge_cnt <= 'd0;
    else if(spi_state == IDLE)
        spi_edge_cnt <= 'd0;
    else if(spi_state == SCLK_EDGE)
        spi_edge_cnt <= spi_edge_cnt + 1'b1;
    else 
        spi_edge_cnt <= spi_edge_cnt;
end

//MOSI
always@(posedge spi_clk or posedge spi_rst)	begin
	if(spi_rst)
        mosi_shift <= 'd0;
    else if(spi_state == IDLE && spi_wr_en)
        mosi_shift <= spi_data_in;
    else if((spi_state == SCLK_EDGE) && (SPI_CPHA == 1'b0) && (spi_edge_cnt[0] == 1'b1))
        mosi_shift <= {mosi_shift[6:0],mosi_shift[7]};
    else if((spi_state == SCLK_EDGE) && (SPI_CPHA == 1'b1) && (spi_edge_cnt[0] == 1'b0) && (spi_edge_cnt != 'd0))
        mosi_shift <= {mosi_shift[6:0],mosi_shift[7]};
end

//MISO
always@(posedge spi_clk or posedge spi_rst)	begin
	if(spi_rst)
        miso_shift <= 'd0;
    else if(spi_state == IDLE && spi_wr_en)
        miso_shift <= 'd0;
    else if((spi_state == SCLK_EDGE) && (spi_edge_cnt[0] == 1'b0) && (SPI_CPHA == 1'b0))
        miso_shift <= {miso_shift[6:0],spi_miso};
    else if((spi_state == SCLK_EDGE) && (spi_edge_cnt[0] == 1'b1) && (SPI_CPHA == 1'b1))
        miso_shift <= {miso_shift[6:0],spi_miso};
end

endmodule 