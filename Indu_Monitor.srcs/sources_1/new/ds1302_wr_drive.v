/*
	DS1302完整 读、写传输  控制模块
*/
module ds1302_wr_drive(
    input  wire                         ds1302_clk               ,
    input  wire                         ds1302_rst               ,

//用户写数据接口
    input  wire        [   7: 0]        write_second             ,
    input  wire        [   7: 0]        write_minute             ,
    input  wire        [   7: 0]        write_hour               ,
    input  wire        [   7: 0]        write_date               ,
    input  wire        [   7: 0]        write_month              ,
    input  wire        [   7: 0]        write_week               ,
    input  wire        [   7: 0]        write_year               ,

    input  wire                         write_time_req           ,//完整写操作的     写请求
    output wire                         write_time_ack           ,//完整读操作完成   应答信号

//用户读数据接口
    output reg         [   7: 0]        read_second             ,
    output reg         [   7: 0]        read_minute             ,
    output reg         [   7: 0]        read_hour               ,
    output reg         [   7: 0]        read_date               ,
    output reg         [   7: 0]        read_month              ,
    output reg         [   7: 0]        read_week               ,
    output reg         [   7: 0]        read_year               ,

    input  wire                         read_time_req            ,//完整读操作的 读请求
    output wire                         read_time_ack            ,//完整读操作完成 应答信号

//DS1302物理IO
    output wire                         ds1302_ce                ,//DS1302 复位引脚
    output wire                         ds1302_sclk              ,//DS1302 时钟引脚
    inout  wire                         ds1302_data               //DS1302 双向数据引脚  
);

//状态机 状态定义
    localparam                          IDLE                 	 = 0     ;
//写状态
    localparam                          WRITE_WP                 = 1     ;//写保护 
    localparam                          WRITE_YEAR               = 2     ;
    localparam                          WRITE_WEEK               = 3     ;
    localparam                          WRITE_MON                = 4     ;
    localparam                          WRITE_DATE               = 5     ;
    localparam                          WRITE_HOUR               = 6     ;
    localparam                          WRITE_MIN                = 7     ;
    localparam                          WRITE_SEC                = 8     ;
//读状态
    localparam                          READ_YEAR                = 9     ;
    localparam                          READ_WEEK                = 10    ;
    localparam                          READ_MON                 = 11    ;
    localparam                          READ_DATE                = 12    ;
    localparam                          READ_HOUR                = 13    ;
    localparam                          READ_MIN                 = 14    ;
    localparam                          READ_SEC                 = 15    ;
    localparam                          ACK                      = 16    ;	

//状态机
    reg                [   4: 0]        state                     ;
//写
    reg                [   7: 0]        write_addr                ;//写 数据地址
    reg                [   7: 0]        write_data                ;//写 数据
    reg                                 write_req                 ;//写 请求
	wire                                write_req_ack             ;//写 完整写操作 完成应答信号

//读
    reg                [   7: 0]        read_addr                 ;//读 数据地址
	wire               [   7: 0]        read_data                 ;//读 数据
    reg                                 read_req                  ;//读 请求
	wire                                read_req_ack              ;//读 完整读操作 完成应答信号

    assign                              write_time_ack            = (state == ACK); //完整写数据 完成 应答脉冲
    assign                              read_time_ack             = (state == ACK); //完整读数据 完整 应答脉冲


/****************************第一段状态机 状态逻辑的跳转**************************************/

//状态机第一段  写、读数据状态机
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
		state <= IDLE;
	else begin 
		case(state)
			IDLE  	  : state <= write_time_req ? WRITE_WP  : 
								 read_time_req  ? READ_YEAR : IDLE  ;
			WRITE_WP  : state <= write_req_ack ? WRITE_YEAR : WRITE_WP   ;
			WRITE_YEAR: state <= write_req_ack ? WRITE_WEEK : WRITE_YEAR ;
			WRITE_WEEK: state <= write_req_ack ? WRITE_MON  : WRITE_WEEK ;
			WRITE_MON : state <= write_req_ack ? WRITE_DATE : WRITE_MON  ;
			WRITE_DATE: state <= write_req_ack ? WRITE_HOUR : WRITE_DATE ;
			WRITE_HOUR: state <= write_req_ack ? WRITE_MIN  : WRITE_HOUR ;
			WRITE_MIN : state <= write_req_ack ? WRITE_SEC  : WRITE_MIN  ;
			WRITE_SEC : state <= write_req_ack ? ACK        : WRITE_SEC  ;

			READ_YEAR: state <= read_req_ack  ? READ_WEEK : READ_YEAR ;
			READ_WEEK: state <= read_req_ack  ? READ_MON  : READ_WEEK ;
			READ_MON : state <= read_req_ack  ? READ_DATE : READ_MON  ;
			READ_DATE: state <= read_req_ack  ? READ_HOUR : READ_DATE ;
			READ_HOUR: state <= read_req_ack  ? READ_MIN  : READ_HOUR ;
			READ_MIN : state <= read_req_ack  ? READ_SEC  : READ_MIN  ;
			READ_SEC : state <= read_req_ack  ? ACK       : READ_SEC  ;

			ACK   	 : state <= IDLE;
			default  : state <= IDLE;
		endcase
	end
end


/****************************第二段状态机 写状态下操作**************************************/

//write_req 在以下状态下 启动write操作
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
		write_req <= 1'b0;
	else if(write_req_ack)
		write_req <= 1'b0;
	else
		case(state)
            WRITE_WP  ,
			WRITE_YEAR,
			WRITE_WEEK,
			WRITE_MON ,
			WRITE_DATE,
			WRITE_HOUR,
			WRITE_MIN ,
            WRITE_SEC : write_req <= 1'b1; 
		endcase
end

//写操作下 在不同写状态下对 地址、数据 进行赋值
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)begin
			write_addr <= 8'h00;
			write_data <= 8'h00;
	end
	else
		case(state)
			WRITE_WP  :begin write_addr <= 8'h8e; write_data <= 8'h00        ; end
			WRITE_YEAR:begin write_addr <= 8'h8c; write_data <= write_year   ; end
			WRITE_WEEK:begin write_addr <= 8'h8a; write_data <= write_week   ; end
			WRITE_MON :begin write_addr <= 8'h88; write_data <= write_month  ; end
			WRITE_DATE:begin write_addr <= 8'h86; write_data <= write_date   ; end
			WRITE_HOUR:begin write_addr <= 8'h84; write_data <= write_hour   ; end
			WRITE_MIN :begin write_addr <= 8'h82; write_data <= write_minute ; end
			WRITE_SEC :begin write_addr <= 8'h80; write_data <= write_second ; end
			default   :begin write_addr <= 8'h00; write_data <= 8'h00        ; end
		endcase
end


/****************************第二段状态机 读状态下操作**************************************/

//read_req 在以下状态下 启动read操作
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
		read_req <= 1'b0;
	else if(read_req_ack)
		read_req <= 1'b0;
	else
		case(state)
			READ_YEAR ,
			READ_WEEK ,
			READ_MON  ,
			READ_DATE ,
			READ_HOUR ,
			READ_MIN  ,
			READ_SEC  : read_req <= 1'b1;
		endcase
end


//读取数据时 需要先发送的 数据地址
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)
		read_addr <= 8'h00;
	else
		case(state)
			READ_YEAR : read_addr <= 8'h8d;
			READ_WEEK : read_addr <= 8'h8b;
			READ_MON  : read_addr <= 8'h89;
			READ_DATE : read_addr <= 8'h87;
			READ_HOUR : read_addr <= 8'h85;
			READ_MIN  : read_addr <= 8'h83;
			READ_SEC  : read_addr <= 8'h81;
			default   : read_addr <= read_addr;
		endcase
end

//在读应答时 将接收要读取的数据
always@(posedge ds1302_clk or posedge ds1302_rst)	begin
	if(ds1302_rst)begin
        read_year   <= 8'h00;
        read_week   <= 8'h00;
        read_month  <= 8'h00;
        read_date   <= 8'h00;
        read_hour   <= 8'h00;
        read_minute <= 8'h00;
        read_second <= 8'h00;
	end
	else if(read_req_ack) begin
		case(state)
			READ_YEAR : read_year   <=  read_data ;    
			READ_WEEK : read_week   <=  read_data ;
			READ_MON  : read_month  <=  read_data ; 
			READ_DATE : read_date   <=  read_data ;
			READ_HOUR : read_hour   <=  read_data ;
			READ_MIN  : read_minute <=  read_data ;  
			READ_SEC  : read_second <=  read_data ;  
		endcase
	end
end


//ds1302 module
ds1302_io_convert ds1302_io_convert_inst(
.ds1302_clk                             (ds1302_clk              ),
.ds1302_rst                             (ds1302_rst              ),
//写
.ds1302_write_addr                      (write_addr              ),// 写 数据地址
.ds1302_write_data                      (write_data              ),// 写 数据
.ds1302_write_en                        (write_req               ),// 写 使能
.ds1302_write_ack                       (write_req_ack           ),// 写 完整写过程完成
//读
.ds1302_read_addr                       (read_addr               ),// 读 数据地址
.ds1302_read_data                       (read_data               ),// 读 数据
.ds1302_read_en                         (read_req                ),// 读 使能
.ds1302_read_ack                        (read_req_ack            ),// 读 完整读过程完成
//DS1302物理IO
.ds1302_ce                              (ds1302_ce               ),
.ds1302_sclk                            (ds1302_sclk             ),
.ds1302_data                            (ds1302_data             )
);

endmodule