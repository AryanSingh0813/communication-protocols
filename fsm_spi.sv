`timescale 1ns / 1ps

module fsm_spi(
input wire clk,
input wire rst,
input wire tx_enable,
output reg mosi, ///Serial bit output
output reg cs,
output wire sclk//serial clock for SPI
    );
    
    typedef enum logic[1:0]{ idle = 0, start_tx = 1, tx_data = 2, end_tx = 3}state_type;
    state_type state, next_state;
    
    reg [7:0]din = 8'b01010101;
    reg spi_clk = 0;
    reg [2:0] ccount = 0;
    reg [2:0] count = 0; ///time interval for sclk to be high(0-7) & low(0-7)
    
    integer bit_count = 0;//Keeping the count for the bits transferred
     
    //generating spi_clk;
    always@(posedge clk)begin
        
        case(next_state)
            idle:begin
                spi_clk = 0;
            end                                                             

            start_tx:begin                                              
                if(count < 3'b011 || count == 3'b111 ) spi_clk = 1; ///spi_clk rmains high for half clock period i.e 0-3 (1) 4-7(0)and then after 7 again(1)
                else spi_clk = 0;
            end
            
            tx_data:begin
                 if(count < 3'b011 || count == 3'b111 ) spi_clk = 1;
                 else spi_clk = 0;
            end
            
            end_tx:begin
                 if(count < 3'b011 ) spi_clk = 1;
                 else spi_clk = 0;
            end
            default :  spi_clk = 0;
        endcase  
    end
    
    //sensing reset 
    always@(posedge clk)begin
        if(rst) state <= idle;
        else state <= next_state;
    end
    
    //next_state decoder
    always@(*)begin
    case(state)
        idle: begin
            mosi = 1'b0;
            cs = 1'b1;
            if(tx_enable) next_state = start_tx;
            else next_state = idle;
        end
        
        start_tx:begin
            cs = 1'b0;
            if(count == 3'b111 ) next_state = tx_data;
            else next_state = start_tx;
        end
        
        tx_data:begin
            mosi = din[7-bit_count];
            if(bit_count != 8) next_state = tx_data;
            else begin
                next_state = end_tx;
                mosi = 1'b0;
            end
        end
        
        end_tx:begin
            cs = 1'b1;
            mosi = 1'b0;
            if(count == 3'b111) next_state = idle;
            else next_state = end_tx;
        end
        default: next_state = idle;
    endcase
    end
    
    ///counter
    always@(posedge clk)begin
        case(state)
            
            idle:begin 
                count <= 0 ; 
                bit_count <= 0;
            end
            
            start_tx : count <= count + 1;
            
            tx_data:begin
                if(bit_count != 8)begin 
                    if(count < 3'b111) count <= count + 1;
                    else begin
                        count <= 0;
                        bit_count <= bit_count + 1;
                    end  
                end  
            end
            
            end_tx:begin
                count <= count + 1;
                bit_count <= 0;
            end
            
            default:begin
                count <= 0;
                bit_count <= 0;
            end
            
        endcase
    end
    
    assign sclk = spi_clk;
    
endmodule

///slave////

module spi_slave(
    input sclk, mosi, cs,
    output [7:0]dout,
    output reg done
);

    integer count = 0; //keeps account for the overall period of one sclk
    typedef enum logic[1:0]{
        idle = 0, sample = 1
    }state_type;
    state_type state;
    
    reg [7:0] data = 0; //Temporarily store the output data
    
    always@(negedge sclk)begin
        case(state)
            idle:begin
                done <= 1'b0;
                if(cs == 1'b0) state <= sample;
                else state <= idle;
            end
            sample:begin
                if(count < 8)begin
                    count = count + 1;//Increases the value of count till 7 after 7 exits the "if" loop
                    data <= {data[6:0], mosi};//left shift operation as Master sends MSB first
                    state <= sample;
                end
                else begin
                    count <= 0;
                    state <= idle;
                    done <= 1'b1;
                end
            end
            default: state <= idle;
        endcase
    end 
    
    assign dout = data;
    
endmodule

////Top Module////
 module top(
    input clk, rst, tx_enable,
    output [7:0] dout,
    output done
 );
    wire mosi, ss, sclk;
    
    fsm_spi spi_m(.clk(clk), .rst(rst), .tx_enable(tx_enable), .mosi(mosi), .cs(ss), .sclk(sclk));
    spi_slave spi_s(.sclk(sclk), .mosi(mosi), .cs(ss), .dout(dout), .done(done));
    
 endmodule
