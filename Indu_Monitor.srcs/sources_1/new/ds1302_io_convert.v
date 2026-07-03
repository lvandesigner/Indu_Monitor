/*
    DS1302数据传输时的 读、写 数据转换模块
    1.由于DS1302的数据手册规定数据传输有限LSB 为了对接底层的SPI的MSB优先传输的规定 故增添此模块用来 数据转换
    2.由于DS1302只有一个IO端口进行数据传输    而底层的标准SPI接口有两个数据端口    故增添此模块用来 端口转换
    3.DS1302是通过置 高电平 来选择通信        与标准SPI通信协议逻辑相反                            
*/
module ds1302_io_convert
(  
    input  wire                         ds1302_clk                            , 
    input  wire                         ds1302_rst                            ,
//写
    input  wire        [   7: 0]        ds1302_write_addr                     , //写 数据地址
    input  wire        [   7: 0]        ds1302_write_data                     , //写 数据
    input  wire                         ds1302_write_en                       , //写 使能 
    output wire                         ds1302_write_ack                      , //写 完整写过程完成
//读
    input  wire        [   7: 0]        ds1302_read_addr                      , //读 数据地址 
    output reg         [   7: 0]        ds1302_read_data                      , //读 数据
    input  wire                         ds1302_read_en                        , //读 使能
    output wire                         ds1302_read_ack                       , //读 完整读过程完成
//DS1302物理IO
    output wire                         ds1302_ce                             , //片选端口
    output wire                         ds1302_sclk                           , //SPI时钟
    inout  wire                         ds1302_data                             //用于构建三态门
);


//状态机参数定义
    localparam                          IDLE                     = 0         ; //空闲状态 
    localparam                          CE_HIGH                  = 1         ; //将CE拉高

    localparam                          READ_ADDR                = 2         ; //发送读地址
    localparam                          READ_DATA                = 3         ; //发送读数据

    localparam                          WRITE_ADDR               = 4         ; //发送写地址
    localparam                          WRITE_DATA               = 5         ; //发送写数据

    localparam                          ACK                      = 6         ; //结束 应答
    localparam                          CE_LOW                   = 7         ; //将CE拉低

// Reg define
    reg                [   3: 0]        state                                ;

    reg                [  19: 0]        delay_cnt                            ;
    reg                                 cs_ctrl                              ;
    reg                                 wr_req                               ;
    reg                                 ds1302_io_ctrl                       ;
    reg                [   7: 0]        send_data                            ;

    wire                                ds1302_mosi                          ;//输出
    wire                                ds1302_miso                          ;//输入

    wire                                wr_ack                               ;
    wire               [   7: 0]        receive_data                         ;
    
    assign                              ds1302_data              = ~ds1302_io_ctrl ? ds1302_mosi       : 1'bz;
    assign                              ds1302_miso              =  ds1302_io_ctrl ? ds1302_data       : 1'b0;
    

assign                                  ds1302_read_ack          = (state == ACK);//读完数据 应答
assign                                  ds1302_write_ack         = (state == ACK);//写完数据 应答

/****************************第一段状态机 状态逻辑的跳转**************************************/
always@(posedge ds1302_clk or posedge ds1302_rst)   begin
    if(ds1302_rst)
        state <= IDLE;
    else begin
        case(state)
            IDLE       :
                if(ds1302_write_en || ds1302_read_en)
                    state <= CE_HIGH;
                else 
                    state <= IDLE;
            CE_HIGH    : //将CE拉高
                if(delay_cnt == 20'd255)
                    state <=  ds1302_read_en ? READ_ADDR :  WRITE_ADDR;
                else 
                    state <= CE_HIGH;

            READ_ADDR  : //发送读地址
                if(wr_ack)
                    state <= READ_DATA;
                else
                    state <= READ_ADDR;
            READ_DATA  :
                if(wr_ack)
                    state <= ACK;
                else 
                    state <= READ_DATA;

            WRITE_ADDR :
                if(wr_ack)
                    state <= WRITE_DATA;
                else 
                    state <= WRITE_ADDR;
                    
            WRITE_DATA :
                if(wr_ack)
                    state <= ACK;
                else 
                    state <= WRITE_DATA;
            
            ACK        :  state <= CE_LOW;
            CE_LOW     :  
                if(delay_cnt == 20'd255)
                    state <= IDLE;
                else 
                    state <= CE_LOW;
            default:state <= IDLE;
        endcase
    end
end

/****************************第二段状态机 信号操作**************************************/

//delay_cnt 用于提前对CS片选进行一段时间的操作
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
		delay_cnt <= 'd0;
    else if(state ==CE_HIGH || state ==CE_LOW)
        delay_cnt <= delay_cnt + 1'b1;
    else 
        delay_cnt <= 'd0 ;
end

//cs_ctrl 控制片选
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
        cs_ctrl <= 'd0;
    else if(state == CE_HIGH)
        cs_ctrl <= 'd1;
    else if(state == CE_LOW)
        cs_ctrl <= 'd0 ;
    else 
        cs_ctrl <= cs_ctrl;
end

//wr_req 传输请求
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
        wr_req <= 'd0;
    else if(wr_ack) 
        wr_req <= 'd0;
    else if(state == READ_ADDR || state == READ_DATA || state == WRITE_ADDR ||state == WRITE_DATA)
        wr_req <= 'd1;
    else 
        wr_req <= wr_req;
end

//ds1302_io_ctrl 三态门控制端口
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
        ds1302_io_ctrl <= 1'b0;
	else
	    ds1302_io_ctrl <= (state == READ_DATA);
end

//ds1302_read_data 读取到的8位数据进行数据转换
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
        ds1302_read_data <= 8'h00;
	else if(state == READ_DATA && wr_ack)
        ds1302_read_data <= {receive_data[0],receive_data[1],receive_data[2],receive_data[3],
                         receive_data[4],receive_data[5],receive_data[6],receive_data[7]};
end

//send_data:发送的数据进行格式转换
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
        send_data <= 'd0;
	else if(state == READ_ADDR)
        send_data <= {ds1302_read_addr[0],ds1302_read_addr[1],ds1302_read_addr[2],ds1302_read_addr[3],
                        ds1302_read_addr[4],ds1302_read_addr[5],ds1302_read_addr[6],ds1302_read_addr[7]};
    else if(state == WRITE_ADDR)
        send_data <= {ds1302_write_addr[0],ds1302_write_addr[1],ds1302_write_addr[2],ds1302_write_addr[3],
                        ds1302_write_addr[4],ds1302_write_addr[5],ds1302_write_addr[6],ds1302_write_addr[7]};
        else if(state == WRITE_DATA)
        send_data <= {ds1302_write_data[0],ds1302_write_data[1],ds1302_write_data[2],ds1302_write_data[3],
                        ds1302_write_data[4],ds1302_write_data[5],ds1302_write_data[6],ds1302_write_data[7]};
end


spi_master#(
    .SYS_CLK                             (28'd50_000_000          ),
    .SPI_SCLK                            (28'd100_000             ),
    .SPI_CPOL                            (1'b0                    ),
    .SPI_CPHA                            (1'b0                    ) 
)
spi_master_inst(
    .spi_clk                             (ds1302_clk              ),
    .spi_rst                             (ds1302_rst              ),
    .spi_cs_ctrl                         (cs_ctrl                 ),// 片选控制端口
    .spi_wr_en                           (wr_req                  ),// 传输使能
    .spi_data_in                         (send_data               ),// 数据输入
    .spi_data_out                        (receive_data            ),// 数据输出
    .spi_wr_ack                          (wr_ack                  ),// 传输结束应答
//SPI物理端口
    .ds1302_ce                           (ds1302_ce               ),// 片选端口
    .ds1302_sclk                         (ds1302_sclk             ),// SPI时钟
    .spi_mosi                            (ds1302_mosi             ),// 用三态门进行构建
    .spi_miso                            (ds1302_miso             ) 
);

endmodule
