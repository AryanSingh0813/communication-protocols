`timescale 1ns / 1ps

module tb;
reg clk = 0 , newd = 0;
reg [7:0] din = 0;
wire [7:0] dout;
 
daisy_c dut(clk, newd, din, dout);
 
always #5 clk = ~clk;
 
initial begin
    repeat(5) @(posedge clk);
        newd = 1;
        din = $urandom;
    @(posedge dut.master.sclk);//Putting back the newd to zero as soon as a random 8 bit data is generated
        newd = 0;
    @(posedge dut.master.cs);//stoping the simulation as during sim. cs was at 0 lvl
        $stop;
     
end
 
 
 
endmodule