`timescale 1ns / 1ps
module tb;
reg clk = 0, rst = 0, newd = 0, op;
reg [6:0] addr;
reg [7:0]din;
reg [7:0]dout;
wire busy, ack_err;
wire done;

i2c_top dut(.clk(clk), .rst(rst), .newd(newd), .op(op), .addr(addr), .din(din), .dout(dout), .busy(busy), .ack_err(ack_err), .done(done));

always #5 clk = ~clk;
 initial begin
    rst = 1;
    repeat(5)@(posedge clk);
    rst = 0;
    repeat(40)@(posedge clk);
    
    ////write operation
    for(int i = 0; i < 10; i++)begin
        newd = 1;
        op = 0;
        addr = $urandom_range(1,4);
        din = $urandom_range(1,5);
        repeat(5)@(posedge clk);
        newd <= 1'b0;
        @(posedge done);
        $display("[WR] din: %0d addr: %0d", din, addr);
        @(posedge clk);
    end
    
    ////read operation
    for(int i = 0; i < 10; i++)begin
        newd = 1;
        op = 1;
        addr = $urandom_range(1,4);
        din = 0;
        repeat(5)@(posedge clk);
        newd <= 1'b0;
        @(posedge done);
        $display("[RD] dout: %0d addr: %0d", dout, addr);
        @(posedge clk);
    end
    
    repeat(10)@(posedge clk);
    $stop;
 end
 
endmodule
