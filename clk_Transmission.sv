`timescale 1ns / 1ps

//%%%%%%%%%%% Testbench to verify master module %%%%%%%%%%%%%%%%%%%%%%%%%

//module tb();
//reg clk = 0;
//reg rst = 0;
//reg tx_enable = 0;
//wire mosi;
//wire ss;
//wire sclk;

//always #5 clk = ~clk;

//initial begin
//    rst = 1;
//    repeat(5)@(posedge clk);
//    rst = 0;
//end

//initial begin
//    tx_enable = 0;
//    repeat(5)@(posedge clk);
//     tx_enable = 1;
//end

//fsm_spi dut(
//    .clk(clk),
//    .rst(rst),.tx_enable(tx_enable),
//    .mosi(mosi),
//    .cs(ss),
//    .sclk(sclk)
//);


//endmodule

//%%%%%%%%%%%%% Testbench to verify the Slave Module %%%%%%%%%%%%%%%%%%%%%%%%%%%%

module tb;
    reg clk = 0;
    reg rst = 0;
    reg tx_enable = 0;
    wire [7:0] dout;
    
    top dut(
        .clk(clk), .rst(rst), .tx_enable(tx_enable), .dout(dout),
        .done(done)
     );
    
    always #5 clk = ~clk;
    
    initial begin
       rst = 1;
       repeat(5)@(posedge clk);
       rst = 0; 
    end
    
    initial begin
        tx_enable = 0;
        repeat(5)@(posedge clk);
        tx_enable = 1;
    end
    
endmodule