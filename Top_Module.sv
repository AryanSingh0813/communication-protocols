`timescale 1ns / 1ps

module i2c_top(
    input clk, rst, newd, op,
    input [6:0] addr,
    input [7:0]din,
    output [7:0]dout,
    output busy, ack_err,
    output done
);
wire sda, scl;
wire ack_errm, ack_errs;

i2c_master master(.clk(clk), .rst(rst), .newd(newd), .addr(addr), .op(op), .sda(sda), .scl(scl), .din(din), .dout(dout),
                     .busy(busy), .ack_err(ack_errm), .done(done)
                 );                 
i2c_slave slave( .scl(scl), .clk(clk), .rst(rst), .sda(sda), .ack_err(ack_errs), .done(done));

assign ack_err = ack_errs | ack_errm;

endmodule

/////////////////////
interface i2c_if;
logic clk;
logic rst;
logic newd;
logic op;
logic [7:0]din;
logic [6:0]addr;
logic [7:0]dout;
logic done;
logic busy, ack_err;
endinterface