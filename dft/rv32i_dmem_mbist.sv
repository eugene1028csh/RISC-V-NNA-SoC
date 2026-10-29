module dmem_mbist #(
    parameter int ADDR_WIDTH = 8
    // ADDR_WIDTH is a configurable paramter and its default value is 8
    //By default, this MBIST assumes the memory address counter needs 8 bits, covering 256 address locations
)(
    input logic     clk,
    input logic     reset,
    input logic     start,

    output logic    busy,
    output logic    done,
    output logic    pass,
    output logic    fail,

    output logic    mem_we, //write enable
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input logic [31:0] mem_rdata,

    output logic [31:0] fail_addr
);
    
    logic [ADDR_WIDTH-1:0] addr_counter;
    localparam logic [ADDR_WIDTH-1:0] LAST_ADDR = {ADDR_WIDTH{1'b1}};
    logic   lfsr_enable;
    logic   lfsr_load_seed;
    logic [31:0] lfsr_value;

    typedef enum logic [4:0] {
        IDLE,

        WRITE_0_UP,
        READ_0_UP,
        WRITE_1_UP,

        READ_1_DOWN,
        WRITE_0_DOWN,
        READ_0_FINAL,

        WRITE_AA_UP,
        READ_AA_UP,
        WRITE_55_UP,

        READ_55_DOWN,
        WRITE_AA_DOWN,
        READ_AA_FINAL,

        LFSR_SEED_WRITE,
        LFSR_WRITE_UP,

        LFSR_SEED_READ,
        LFSR_READ_UP,

        FINISH
    } state_t;

    state_t state, next_state;

    lfsr32 lfsr_inst (
        .clk       (clk),
        .reset     (reset),
        .enable    (lfsr_enable),
        .load_seed (lfsr_load_seed),
        .rvalue    (lfsr_value)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    //fsm 
    always_comb begin
        next_state =  state;
        case (state)

            IDLE: begin
                if (start)
                    next_state = WRITE_0_UP;
            end

            WRITE_0_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = READ_0_UP;
            end

            READ_0_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = WRITE_1_UP;
            end

            WRITE_1_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = READ_1_DOWN;
            end

            READ_1_DOWN: begin
                if (addr_counter == 0)
                    next_state = WRITE_0_DOWN;
            end

            WRITE_0_DOWN: begin
                if (addr_counter == 0)
                    next_state = READ_0_FINAL;
            end

            READ_0_FINAL: begin
                if (addr_counter == LAST_ADDR)
                    next_state = WRITE_AA_UP;
            end


            WRITE_AA_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = READ_AA_UP;
            end

            READ_AA_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = WRITE_55_UP;
            end

            WRITE_55_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = READ_55_DOWN;
            end

            READ_55_DOWN: begin
                if (addr_counter == 0)
                    next_state = WRITE_AA_DOWN;
            end

            WRITE_AA_DOWN: begin
                if (addr_counter == 0)
                    next_state = READ_AA_FINAL;
            end

            READ_AA_FINAL: begin
                if (addr_counter == LAST_ADDR)
                    next_state = LFSR_SEED_WRITE;
            end


            LFSR_SEED_WRITE: begin
                next_state = LFSR_WRITE_UP;
            end

            LFSR_WRITE_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = LFSR_SEED_READ;
            end

            LFSR_SEED_READ: begin
                next_state = LFSR_READ_UP;
            end

            LFSR_READ_UP: begin
                if (addr_counter == LAST_ADDR)
                    next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //address counter
    always_ff @(posedge clk) begin
        if (reset) begin
            addr_counter <= '0;

        end else begin
            case (state)

                IDLE: begin
                    addr_counter <= '0;
                end

                // Upward pass
                WRITE_0_UP,
                READ_0_UP,
                READ_0_FINAL,
                WRITE_AA_UP,
                READ_AA_UP,
                READ_AA_FINAL,
                LFSR_WRITE_UP,
                LFSR_READ_UP: begin

                    if (addr_counter == LAST_ADDR)
                        addr_counter <= '0;
                    else
                        addr_counter <= addr_counter + 1'b1;
                    end


                // Downward pass
                READ_1_DOWN,
                READ_55_DOWN: begin

                if (addr_counter == 0)
                    addr_counter <= LAST_ADDR;
                else
                    addr_counter <= addr_counter - 1'b1;
                end

                //boundary depends on the direction of the next state, hence...
                // up to down transition:
                // finish at LAST_ADDR and keep it there
                WRITE_1_UP,
                WRITE_55_UP: begin
                    if (addr_counter == LAST_ADDR)
                        addr_counter <= LAST_ADDR;
                    else
                        addr_counter <= addr_counter + 1'b1;
                end

                // down to up transition:
                // finish at 0 and keep it there
                WRITE_0_DOWN,
                WRITE_AA_DOWN: begin
                    if (addr_counter == 0)
                        addr_counter <= '0;
                    else
                        addr_counter <= addr_counter - 1'b1;
                end


                // lfsr setup
                LFSR_SEED_WRITE: begin
                    addr_counter <= '0;
                end

                LFSR_SEED_READ: begin
                    addr_counter <= '0;
                end

                FINISH: begin
                    addr_counter <= '0;
                end

                default: begin
                    addr_counter <= '0;
                end

            endcase
        end
    end

    //Drive memory
    always_comb begin

        // Defaults
        mem_addr = {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00}
        mem_wdata       = 32'h0000_0000;
        mem_we          = 1'b0;

        lfsr_enable     = 1'b0;
        lfsr_load_seed  = 1'b0;

        busy            = 1'b1;
        done            = 1'b0;

        case (state)

            IDLE: begin
                busy = 1'b0;
            end


            // 0/1 test

            WRITE_0_UP: begin
                mem_we    = 1'b1;
                mem_wdata = 32'h0000_0000;
            end

            READ_0_UP: begin
                mem_we = 1'b0;
            end

            WRITE_1_UP: begin
                mem_we    = 1'b1;
                mem_wdata = 32'hFFFF_FFFF;
            end

            READ_1_DOWN: begin
                mem_we = 1'b0;
            end

            WRITE_0_DOWN: begin
                mem_we    = 1'b1;
                mem_wdata = 32'h0000_0000;
            end

            READ_0_FINAL: begin
                mem_we = 1'b0;
            end


            // checkerboard

            WRITE_AA_UP: begin
                mem_we    = 1'b1;
                mem_wdata = 32'hAAAA_AAAA;
            end

            READ_AA_UP: begin
                mem_we = 1'b0;
            end

            WRITE_55_UP: begin
                mem_we    = 1'b1;
                mem_wdata = 32'h5555_5555;
            end

            READ_55_DOWN: begin
                mem_we = 1'b0;
            end

            WRITE_AA_DOWN: begin
                mem_we    = 1'b1;
                mem_wdata = 32'hAAAA_AAAA;
            end

            READ_AA_FINAL: begin
                mem_we = 1'b0;
            end


            // lfsr

            LFSR_SEED_WRITE: begin
                lfsr_load_seed = 1'b1;
            end

            LFSR_WRITE_UP: begin
                mem_we      = 1'b1;
                mem_wdata   = lfsr_value;
                lfsr_enable = 1'b1;
            end

            LFSR_SEED_READ: begin
                lfsr_load_seed = 1'b1;
            end

            LFSR_READ_UP: begin
                mem_we      = 1'b0;
                lfsr_enable = 1'b1;
            end


            FINISH: begin
                busy = 1'b0;
                done = 1'b1;
            end

            default: begin
                busy = 1'b0;
            end

        endcase
    end

    //fail detecttion logic
    always_ff @(posedge clk) begin
        if (reset) begin
            fail      <= 1'b0;
            pass      <= 1'b0;
            fail_addr <= 32'h0000_0000;

        end else begin

            // Starting a new MBIST clears the previous result
            if ((state == IDLE) && start) begin
                fail      <= 1'b0;
                pass      <= 1'b0;
                fail_addr <= 32'h0000_0000;
            end

            else begin
                case (state)

                    READ_0_UP,
                    READ_0_FINAL: begin
                        if ((mem_rdata != 32'h0000_0000) && !fail) begin
                            fail      <= 1'b1;
                            fail_addr <= {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00};
                        end
                    end


                    READ_1_DOWN: begin
                        if ((mem_rdata != 32'hFFFF_FFFF) && !fail) begin
                            fail      <= 1'b1;
                            fail_addr <= {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00};
                        end
                    end


                    READ_AA_UP,
                    READ_AA_FINAL: begin
                        if ((mem_rdata != 32'hAAAA_AAAA) && !fail) begin
                            fail      <= 1'b1;
                            fail_addr <= {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00};
                        end
                    end


                    READ_55_DOWN: begin
                        if ((mem_rdata != 32'h5555_5555) && !fail) begin
                            fail      <= 1'b1;
                            fail_addr <= {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00};
                        end
                    end


                    LFSR_READ_UP: begin
                        if ((mem_rdata != lfsr_value) && !fail) begin
                            fail      <= 1'b1;
                            fail_addr <= {{(32-ADDR_WIDTH-2){1'b0}}, addr_counter, 2'b00};

                        end else if ((addr_counter == LAST_ADDR) && !fail) begin
                            pass <= 1'b1;
                        end
                    end

                    default: begin
                        // Hold current pass/fail state
                    end

                endcase
            end
        end
    end



endmodule
