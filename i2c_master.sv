`timescale 1ns / 1ps

module i2c_master(
    input clk, rst, newd,
    input [6:0] addr,
    input op, // 1 - for reading and 0 for writing
    inout sda, //As for both master and slave it acts as an i/p as well as o/p
    output scl,
    input [7:0] din,
    output [7:0] dout,
    output reg busy, ack_err, done
    );
    reg scl_t = 0, sda_t = 0; //temp variables for scl and sda
    
    parameter sys_freq = 40000000; //40 Mhz(assumed working frequency of an FPGA)
    parameter i2c_freq = 100000;//100k frequency decided for the protocol to work on
    
    parameter clk_count4 = (sys_freq/i2c_freq);//bit duration 400 (pulse duration) 
    parameter clk_count1 = clk_count4/4;//dividing bit duration into 4 parts each of 100 durations
    
    integer count1 = 0;//will keep the count of duration of parts of pulse duration
    reg i2c_clk = 0; //final clock for the utilized by master and slave for tranmission
    
    ///SCL
    reg [1:0]pulse = 0;
    always@(posedge clk)begin
        if(rst)begin
            pulse <= 0;
            count1 <= 0;
        end
        else if(busy == 1'b0)begin//Pulse count starts only after newd
            pulse <= 0;
            count1 <= 0;
        end
        else if(count1 == clk_count1-1)begin//for range 0 to 99(100-1)
            pulse <= 1;//Pulse value is update for 1 which has duration from 100 to 199 
            count1 <= count1 + 1;//99+1 = 100(pulse 1 begins)
        end
        else if(count1 == clk_count1*2-1)begin//for range 100 to 199(200-1)
            pulse <= 2;//Pulse value is update for 2 which has duration from 200 to 399 
            count1 <= count1 + 1;//199+1 = 200(pulse 2 begins)
        end
        else if(count1 == clk_count1*3-1)begin//for range 200 to 299(300-1)
            pulse <= 3;//Pulse value is update for 1 which has duration from 200 to 299 
            count1 <= count1 + 1;//99+1 = 100(pulse 4 begins)
        end
        else if(count1 == clk_count1*4-1)begin//for range 300 to 399(400-1)
            pulse <= 0;//Pulse value is rested and updatd for 0  
            count1 <= 0;//count1 is reset to 0;
        end
        else begin
        count1 <= count1 + 1; 
        end    
    end
     
//////////////
reg [3:0] bitcount = 0;
reg [7:0] data_addr = 0, data_tx = 0;

reg r_ack = 0; //temporary acknowledgement     
reg [7:0] rx_data = 0;
reg sda_en = 0;

typedef enum logic[3:0]{
    idle = 0, start = 1, write_addr = 2, ack_1 = 3, write_data = 4,
    read_data = 5, stop = 6, ack_2 = 7, master_ack = 8 
}state_type;
state_type state = idle;

always@(posedge clk)begin
    if(rst)begin
        bitcount <= 0;
        data_addr <= 0;
        data_tx <= 0;
        scl_t <= 1;
        sda_t <= 1;
        state <= idle;
        busy <= 1'b0;
        ack_err <= 1'b0;
        done <= 1'b0;
    end
    else begin
        case(state)
            idle:begin
                done <= 1'b0;
                if(newd == 1'b1)begin
                    data_addr <= {addr,op};//sending the address as well the operation, msb of the address followed by other bits then opcode
                    data_tx <= din;
                    busy <= 1'b1;
                    state <= start;
                    ack_err <= 1'b0;
                end
                else begin
                    data_addr <= 0;
                    data_tx <= 0;
                    busy <= 1'b0;
                    state <= idle;
                    ack_err <= 1'b0;
                end
            end
            
            start:begin
                sda_en <= 1'b1; //send start to slave
                case(pulse)
                    0: begin scl_t <= 1'b1; sda_t <= 1'b1;end
                    1: begin scl_t <= 1'b1; sda_t <= 1'b1;end
                    2: begin scl_t <= 1'b1; sda_t <= 1'b0;end
                    3: begin scl_t <= 1'b1; sda_t <= 1'b0;end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    state <= write_addr;
                    scl_t <= 1'b0;
                end
                else state <= start;
            end
            
            write_addr:begin
                sda_en <= 1'b1;///send addr to slave
                if(bitcount <= 7)begin
                    case(pulse)
                        0: begin scl_t <= 1'b0; sda_t <= 1'b0;end
                        1: begin scl_t <= 1'b0; sda_t <= data_addr[7 - bitcount];end //changing the data on sda in the first pulse i.e. negative pulse
                        2: begin scl_t <= 1'b1;end//not allowed to change the data when scl is high
                        3: begin scl_t <= 1'b1;end//not allowed to change the data when scl is high
                    endcase
                    if(count1 == clk_count1*4 - 1)begin
                        state <= write_addr;
                        scl_t <= 1'b0;
                        bitcount = bitcount + 1;
                    end
                    else state <= write_addr;
                end
                else begin
                    state <= ack_1;
                    bitcount <= 0;
                    sda_en <= 1'b0;
                end
            end
            ///////
            ack_1:begin
                sda_en <= 1'b0;///recv ack from slave
                case(pulse)
                    0:begin scl_t <= 1'b0; sda_t <= 1'b0;end
                    1:begin scl_t <= 1'b0; sda_t <= 1'b0;end
                    2:begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda;end///recv ack from slave
                    3:begin scl_t <= 1'b0; end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    if(r_ack == 1'b0 && data_addr[0] == 1'b0)begin  //Lsb bit of the data_addr is decideing the operation
                        state <= write_data;
                        sda_t <= 1'b0;
                        sda_en <= 1'b1;///write data to slave
                        bitcount <= 0;
                    end
                else if(r_ack == 1'b0 && data_addr[0] == 1'b1)begin
                    state <= read_data;
                    sda_t <= 1'b1; //transmission of data for dout(reading) 
                    sda_en = 1'b0;
                    bitcount <= 0;
                end
                else begin
                    state <= stop; sda_en = 1'b1; ack_err <= 1'b1;
                end
                end
                else state <= ack_1;
            end
            
            write_data:begin
                //write data to slave
                if(bitcount <= 7)begin
                    case(pulse)
                        0: begin scl_t <= 1'b0; end
                        1: begin scl_t <= 1'b0; sda_en <= 1'b1; sda_t <= data_tx[7 - bitcount];end
                        2: begin scl_t <= 1'b1; end
                        3: begin scl_t <= 1'b1; end 
                    endcase
                    if(count1 == clk_count1*4 - 1)begin
                        state <= write_data;
                        scl_t <= 1'b0;
                        bitcount <= bitcount + 1;
                    end
                    else begin
                        state <= write_data;
                    end
                end
                else begin
                    state <= ack_2;
                    bitcount <= 0;
                    sda_en <= 1'b0;///read from slave
                end
            end
           
           read_data:begin 
            sda_en <= 1'b0; //read from slave
            if(bitcount <= 7)begin
                case(pulse)
                    0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                    1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                    2: begin scl_t <= 1'b1; rx_data[7:0] <= (count1 == 200) ? {rx_data[6:0],sda}: rx_data; end
                    3: begin scl_t <= 1'b1; end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    state <= read_data;
                    scl_t <= 1'b0;
                    bitcount <= bitcount + 1;
                end
                else begin
                    state <= read_data;
                end
            end
            else begin
                state <= master_ack;
                bitcount <= 0;
                sda_en <= 1'b1; // master will send ack to slave
            end 
           end
            
            ///master ack ----> send nack(negative acknowledgement)
            master_ack:begin
                sda_en <= 1'b1;
                case(pulse)
                    0: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                    1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                    2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                    3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    sda_t <= 1'b0;
                    state <= stop;
                    sda_en <= 1'b1;//send stop to slave
                end
                else begin
                    state <= master_ack;
                end
            end
            
            ////ack2
            ack_2:begin
                sda_en <= 1'b0;///recv ack from slave
                case(pulse)
                    0:begin scl_t <= 1'b0; sda_t <= 1'b0;end
                    1:begin scl_t <= 1'b0; sda_t <= 1'b0;end
                    2:begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda; end ///recv ack from slave
                    3:begin scl_t <= 1'b1; end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    sda_t <= 1'b0;
                    sda_en <= 1'b1;//send stop to slave
                    if(r_ack == 1'b0)begin
                        state <= stop;
                        ack_err <= 1'b0;
                    end
                    else begin
                        state <= stop;
                        ack_err <= 1'b1;
                    end
                end
                else  begin 
                    state <= ack_2;
                end
            end
            
            ////////////////////stop
            stop:begin
                sda_en <= 1'b1; //send stop to slave
                case(pulse)
                    0: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                    1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                    2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                    3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                endcase
                if(count1 == clk_count1*4 - 1)begin
                    state <= idle;
                    scl_t <= 1'b0;
                    busy <= 1'b0;
                    sda_en <= 1'b1;///send start to slave
                    done <= 1'b1;
                end
                else state <= stop;
            end
            default: state <= idle;
        endcase
    end
end

//assign sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'bz : 1'bz;//concept of open drain interface
 
 assign sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'b1 : 1'bz; //modified master whenever wanted to aplly high on sda manually adding 1.
 
 assign scl = scl_t;
 assign dout = rx_data;
 
endmodule

//Testbench

//module tb;
//    reg clk = 0, rst = 0 , newd = 0;
//    reg [6:0] addr = 0;
//    reg op = 0; 
//    wire sda; 
//    wire scl;
//    reg [7:0] din;
//    wire [7:0] dout;
//    wire busy, ack_err;
    
//    i2c_master dut(.clk(clk), .rst(rst), .newd(newd), .addr(addr), .op(op), .sda(sda), .scl(scl), .din(din), .dout(dout), .busy(busy), .ack_err(ack_err));
    
//    always #5 clk = ~clk;
    
//    initial begin
//        rst = 1;
//        repeat(5)@(posedge clk);
//        rst = 0;
//        newd = 1;
//        op = 0;
//        addr = 7'b1111000;
//        din = 8'hff;
//        @(negedge busy);//for busy equals to low marks the completion of an operation
//        repeat(5)@(posedge clk);
//        $stop;
//    end
    
//endmodule