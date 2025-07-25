`timescale 1ns / 1ps

module i2c_slave(
    input scl, clk, rst,
    inout sda,
    output reg ack_err, done
    );
    
    typedef enum logic [3:0] {
        idle = 0, read_addr = 1, send_ack1 = 2, send_data = 3, master_ack = 4,
        read_data = 5, send_ack2 = 6, wait_p = 7, detect_stop = 8
    }state_type;
    state_type state;
    
    reg [7:0]mem[128]; //8 bit memory having 128 locations
    reg [7:0] r_addr;
    reg [6:0] addr;
    reg r_mem = 0;
    reg w_mem = 0;
    reg [7:0]dout;
    reg[7:0]din;
    reg sda_t;
    reg sda_en;
    reg [3:0] bitcnt = 0;
    
    ///initializing mem
    always@(posedge clk)begin
        if(rst)begin
            for(int i = 0; i < 128; i++)begin
                mem[i] = i;
            end
            dout <= 8'h0;
        end
        else if(r_mem == 1'b1)begin
            dout <= mem[addr];
        end
        else if(w_mem == 1'b1)begin
            mem[addr] <= din;
        end
    end
    
      
    parameter sys_freq = 40000000; //40 Mhz(assumed working frequency of an FPGA)
    parameter i2c_freq = 100000;//100k frequency decided for the protocol to work on
    
    parameter clk_count4 = (sys_freq/i2c_freq);//bit duration 400 (pulse duration) 
    parameter clk_count1 = clk_count4/4;//dividing bit duration into 4 parts each of 100 durations
    
    integer count1 = 0;//will keep the count of duration of parts of pulse duration
    reg i2c_clk = 0; //final clock for the utilized by master and slave for tranmission
    
    ///SCL
    reg [1:0]pulse = 0;
    reg busy;
    always@(posedge clk)begin
        if(rst)begin
            pulse <= 0;
            count1 <= 0;
        end
        else if(busy == 1'b0)begin//Pulse count starts only after newd
            pulse <= 2;
            count1 <= 202;
        end
        else if(count1 == clk_count1 - 1)begin//for range 0 to 99(100-1)
            pulse <= 1;//Pulse value is update for 1 which has duration from 100 to 199 
            count1 <= count1 + 1;//99+1 = 100(pulse 1 begins)
        end
        else if(count1 == clk_count1*2 - 1)begin//for range 100 to 199(200-1)
            pulse <= 2;//Pulse value is update for 2 which has duration from 200 to 399 
            count1 <= count1 + 1;//199+1 = 200(pulse 2 begins)
        end
        else if(count1 == clk_count1*3 - 1)begin//for range 200 to 299(300-1)
            pulse <= 3;//Pulse value is update for 1 which has duration from 200 to 299 
            count1 <= count1 + 1;//99+1 = 100(pulse 4 begins)
        end
        else if(count1 == clk_count1*4 - 1)begin//for range 300 to 399(400-1)
            pulse <= 0;//Pulse value is rested and updatd for 0  
            count1 <= 0;//count1 is reset to 0;
        end
        else begin
        count1 <= count1 + 1; 
        end    
    end
    
    reg scl_t;
    wire start;
    always@(posedge clk)begin
        scl_t <= scl;
    end
    assign start = ~scl & scl_t;
    reg r_ack;
    
    always@(posedge clk)begin
        if(rst)begin
            bitcnt <= 0;
            state <= idle;
            r_addr <= 7'b0000000;
            sda_en <= 1'b0;
            sda_t <= 1'b0;
            addr <= 0;
            r_mem <= 0;
            din <= 8'h00;
            ack_err <= 0;
            done <= 1'b0;
            busy <= 1'b0;
        end
        else begin
            case(state)
                idle:begin
                    if(scl == 1'b1 && sda == 1'b0)begin
                        busy <= 1'b1;
                        state <= wait_p;
                    end
                    else begin
                        state <= idle;
                    end
                end//-
                
                wait_p:begin
                    if(pulse == 2'b11 && count1 == 399) state <= read_addr;
                    else state <= wait_p;
                end//-
                
                read_addr:begin
                    sda_en <= 1'b0;
                    if(bitcnt <= 7)begin
                        case(pulse)
                            0: begin end
                            1: begin end
                            2: begin r_addr <= (count1 == 200) ? {r_addr[6:0], sda}: r_addr; end
                            3: begin end
                        endcase
                        if(count1 == clk_count1*4 - 1)begin
                            state <= read_addr;
                            bitcnt <= bitcnt + 1;
                        end
                        else begin
                            state <= read_addr;
                        end
                    end
                    else begin
                        state <= send_ack1;
                        bitcnt <= 0;
                        sda_en <= 1'b1;
                        addr <= r_addr[7:1];
                    end
                end //-
                
                send_ack1:begin
                    case(pulse)
                        0: begin sda_t <= 1'b0; end
                        1: begin end
                        2: begin end
                        3: begin end
                    endcase
                    if(count1 == clk_count1*4 - 1)begin
                       if(r_addr[0] == 1'b1)begin
                        state <= send_data;
                        r_mem <= 1'b1;
                       end
                       else begin
                        state <= read_data;
                        r_mem <= 1'b0;
                       end
                    end
                    else state <= send_ack1;
                end//-
                
                read_data:begin
                    sda_en <= 1'b0;
                    if(bitcnt <= 7)begin
                        case(pulse)
                            0: begin end
                            1: begin end
                            2: begin din <= (count1 == 200) ? {din[6:0], sda} : din;end
                            3: begin end
                        endcase
                        if(count1 == clk_count1*4 - 1)begin
                            state <= read_data;
                            bitcnt <= bitcnt + 1;
                        end
                        else state <= read_data;
                    end
                    else begin
                        state <= send_ack2;
                        bitcnt <= 0;
                        sda_en <= 1'b1;
                        w_mem <= 1'b1;
                    end 
                end//-
                
                send_ack2:begin
                    case(pulse)
                        0:begin sda_t <= 1'b0; end
                        1:begin w_mem <= 1'b0; end
                        2:begin end
                        3:begin end
                    endcase
                    if(count1 == clk_count1*4 - 1)begin
                        state <= detect_stop;
                        sda_en <= 1'b0;
                    end
                    else state <= send_ack2;
                end//-
                
                send_data:begin
                    sda_en <= 1'b1;
                    if(bitcnt <= 7)begin
                        r_mem <= 1'b0;
                        case(pulse)
                            0: begin end
                            1: begin sda_t <= (count1 == 100) ? dout[7 - bitcnt]: sda_t; end
                            2: begin end
                            3: begin end
                        endcase
                        if(count1 == clk_count1*4 - 1)begin
                            state <= send_data;
                            bitcnt <= bitcnt + 1;
                        end
                        else state <= send_data;
                    end
                    else begin
                        state <= master_ack;
                        bitcnt <= 0;
                        sda_en <= 1'b0;
                    end
                end//-
                
                master_ack:begin
                    case(pulse)
                        0: begin end
                        1: begin end
                        2: begin r_ack <= (count1 == 200) ? sda : r_ack;end
                        3:begin end
                    endcase
                    if(count1 == clk_count1*4 - 1)begin
                        if(r_ack == 1'b1)begin
                            ack_err = 1'b0;
                            state <= detect_stop;
                            sda_en <= 1'b0;
                        end
                        else begin
                            ack_err <= 1'b1;
                            state <= detect_stop;
                            sda_en <= 1'b0;
                        end
                    end
                    else state <= master_ack;
                end//-
                
                detect_stop:begin
                    if(pulse == 2'b11 && count1 == 399)begin
                        state <= idle;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                    else state <= detect_stop;
                end//-
                
                default : state <= idle;
                
            endcase
        end
    end
        assign sda = (sda_en == 1'b1) ? sda_t : 1'bz;
endmodule