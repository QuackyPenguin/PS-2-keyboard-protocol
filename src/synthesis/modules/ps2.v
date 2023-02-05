module ps2(input ps2_clk,
           input clk,
           input in,
           input rst_n,
           output wire [7:0] out_hex1,
           output wire [7:0] out_hex2);
    
    wire ps2_clk_deb;
    deb deb_clk (clk, rst_n, ps2_clk, ps2_clk_deb);
    
    reg [1:0] state_reg, state_next;
    reg [2:0] counter_reg, counter_next;
    reg ODD_parity_next, ODD_parity_reg;
    integer i, parity_check;
    
    localparam init_state   = 2'b00;
    localparam data_state   = 2'b01;
    localparam parity_state = 2'b10;
    localparam stop_state   = 2'b11;
    
    reg [7:0] output_reg [2:0];
    reg [7:0] output_next [2:0];
    reg [7:0] output_rel [2:0];
    reg valid_parity= 1'b0;
    reg valid_code  = 1'b0;
    wire valid;
    
    assign valid    = valid_code & valid_parity;
    assign out_hex1 = output_rel[0];
    assign out_hex2 = output_rel[1];
    
    
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            output_reg[0] <= 8'h00;
            output_reg[1] <= 8'h00;
            output_rel[0] <= 8'h00;
            output_rel[1] <= 8'h00;
            ODD_parity_reg<= 1'b0;
        end
        else begin
            output_reg[0] <= output_next[0];
            output_reg[1] <= output_next[1];
            ODD_parity_reg <= ODD_parity_next;
            if (valid) begin
                output_rel[0] <= output_next[0];
                output_rel[1] <= output_next[1];
            end
            
            state_reg   = state_next; 
            counter_reg = counter_next;
        end
    end
    
    always @(negedge ps2_clk_deb) begin
        counter_next   = counter_reg;
        state_next     = state_reg;
        output_next[1] = output_reg[1];
        output_next[0] = output_reg[0];
        valid_code = 0;
        valid_parity = 0;
        ODD_parity_next = ODD_parity_reg;

        case (state_reg)
            init_state: begin
                if (in == 0) begin
                    state_next = data_state;
                    
                    if(output_reg[0]==8'he0 || output_reg[0]==8'hf0) begin
                        output_next[1]=output_reg[0];
                        output_next[0]=8'h00;
                    end
                    else begin
                        output_next[0]=8'h00;
                        output_next[1]=8'h00;
                    end

                    counter_next = 3'b000;
                end
            end
            data_state: begin
                output_next[0][counter_reg] = in;
                if (counter_reg == 3'b111) begin
                    counter_next = 3'b000;
                    state_next   = parity_state;
                end
                else begin
                    counter_next = counter_reg + 1;
                end
            end
            parity_state: begin
                state_next = stop_state;
                ODD_parity_next = in;
            end
            stop_state: begin
                
                parity_check = 0;
                for(i =0; i<8; i=i+1) begin
                    parity_check = parity_check ^ output_reg[0][i];
                end
                parity_check = parity_check ^ ODD_parity_reg;
                ODD_parity_next = 1'b0;
                
                if(parity_check == 1) begin
                    valid_parity = 1'b1;
                end
                else begin
                    valid_parity = 1'b0;
                end
                if (in == 1'b0) begin
                    valid_code = 1'b0;
                end
                else begin
                    if(output_reg[0]==8'he0 || output_reg[0]==8'hf0) begin
                        valid_code = 0;
                    end
                    else begin
                        valid_code = 1;
                    end
                end
                state_next = init_state;
            end
        endcase
    end
    
endmodule
