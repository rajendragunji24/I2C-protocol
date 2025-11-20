module i2c_bus_model(
    inout tri SDA,
    inout tri SCL
);
    pullup(SDA);
    pullup(SCL);
endmodule

// =======================================================
// CORRECTED SIMPLE I2C MASTER  (single-byte write)
// All FSM state names renamed to avoid conflicts
// =======================================================
module i2c_master(
    input  logic clk,
    input  logic rst,
    output tri   SCL,
    inout  tri   SDA
);

    // --------------------------------------------
    // Slow SCL generator (open drain)
    // --------------------------------------------
    logic scl_drive;
    assign SCL = scl_drive ? 1'b0 : 1'bz;

    logic [7:0] divider;
    always_ff @(posedge clk) begin
        divider   <= divider + 1;
        scl_drive <= divider[4];     // slow down SCL
    end

    // --------------------------------------------
    // SDA open-drain driver
    // --------------------------------------------
    logic sda_en, sda_out;
    assign SDA = sda_en ? sda_out : 1'bz;

    // --------------------------------------------
    // FSM: Renamed ALL states to avoid any clash
    // --------------------------------------------
    typedef enum logic [3:0] {
        M_ST_IDLE,
        M_ST_START,
        M_ST_ADDR,
        M_ST_ADDR_ACK,
        M_ST_REG,
        M_ST_REG_ACK,
        M_ST_DATA,
        M_ST_DATA_ACK,
        M_ST_STOP
    } mstate_t;

    mstate_t mstate, next_mstate;

    logic [7:0] byte_to_send;
    logic [2:0] bit_cnt;

    // --------------------------------------------
    // FSM sequential logic
    // --------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            mstate <= M_ST_IDLE;
        else
            mstate <= next_mstate;
    end

    // --------------------------------------------
    // FSM next state logic
    // --------------------------------------------
    always_comb begin
        next_mstate = mstate;

        case (mstate)

            M_ST_IDLE:      next_mstate = M_ST_START;

            M_ST_START:     next_mstate = M_ST_ADDR;

            M_ST_ADDR:
                if (bit_cnt == 0)
                    next_mstate = M_ST_ADDR_ACK;

            M_ST_ADDR_ACK:  next_mstate = M_ST_REG;

            M_ST_REG:
                if (bit_cnt == 0)
                    next_mstate = M_ST_REG_ACK;

            M_ST_REG_ACK:   next_mstate = M_ST_DATA;

            M_ST_DATA:
                if (bit_cnt == 0)
                    next_mstate = M_ST_DATA_ACK;

            M_ST_DATA_ACK:  next_mstate = M_ST_STOP;

            M_ST_STOP:      next_mstate = M_ST_IDLE;

        endcase
    end

    // --------------------------------------------
    // Byte Transmission Logic
    // --------------------------------------------
    always_ff @(posedge clk) begin

        case (mstate)

            // START condition
            M_ST_START: begin
                sda_en       <= 1;
                sda_out      <= 0;      // SDA goes LOW while SCL HIGH
                bit_cnt      <= 3'd7;
                byte_to_send <= {7'h42, 1'b0};  // slave = 0x42, write=0
            end

            // Send Slave Address + R/W
            M_ST_ADDR: begin
                sda_en  <= 1;
                sda_out <= byte_to_send[bit_cnt];

                if (bit_cnt != 0)
                    bit_cnt <= bit_cnt - 1;
                else
                    bit_cnt <= 3'd7;
            end

            // Send Register Address
            M_ST_REG: begin
                byte_to_send <= 8'h10; // register = 0x10
                sda_en       <= 1;
                sda_out      <= byte_to_send[bit_cnt];

                if (bit_cnt != 0)
                    bit_cnt <= bit_cnt - 1;
                else
                    bit_cnt <= 3'd7;
            end

            // Send Data Byte
            M_ST_DATA: begin
                byte_to_send <= 8'hAA;
                sda_en       <= 1;
                sda_out      <= byte_to_send[bit_cnt];

                if (bit_cnt != 0)
                    bit_cnt <= bit_cnt - 1;
            end

            // STOP condition
            M_ST_STOP: begin
                sda_en  <= 1;
                sda_out <= 1; // SDA goes HIGH while SCL HIGH
            end

        endcase

    end

endmodule

module i2c_slave #(
    parameter SLAVE_ADDR = 7'h42
)(
    input  logic clk,
    input  logic rst,
    inout  tri   SDA,
    input  logic SCL,

    output logic [7:0] memory_out,
    output logic [7:0] reg_addr_out,
    output logic       wr_rd
);

    logic sda_en, sda_out;
    assign SDA = sda_en ? sda_out : 1'bz;

    logic sda_q, scl_q;
    always_ff @(posedge clk) begin
        sda_q <= SDA;
        scl_q <= SCL;
    end

    wire start_cond = (SDA==0 && sda_q==1 && SCL==1);
    wire stop_cond  = (SDA==1 && sda_q==0 && SCL==1);

    // ************ FIXED ENUM – ALL STATE NAMES RENAMED ************
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_START,
        ST_SLAVE_ADDR,
        ST_SLAVE_ACK,
        ST_REG_ADDR,
        ST_REG_ACK,
        ST_WR_DATA,
        ST_WR_DATA_ACK,
        ST_RD_DATA,
        ST_RD_DATA_ACK,
        ST_STOP_WAIT
    } state_t;

    state_t state, next_state;

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;
    logic [7:0] reg_addr;
    logic [7:0] mem[0:255];

    assign memory_out   = mem[reg_addr];
    assign reg_addr_out = reg_addr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= ST_IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case(state)
            ST_IDLE:        if (start_cond) next_state = ST_START;
            ST_START:       next_state = ST_SLAVE_ADDR;
            ST_SLAVE_ADDR:  if (bit_cnt==0) next_state = ST_SLAVE_ACK;
            ST_SLAVE_ACK:   next_state = ST_REG_ADDR;
            ST_REG_ADDR:    if (bit_cnt==0) next_state = ST_REG_ACK;
            ST_REG_ACK:     next_state = ST_WR_DATA;
            ST_WR_DATA:     if (bit_cnt==0) next_state = ST_WR_DATA_ACK;
            ST_WR_DATA_ACK: next_state = ST_STOP_WAIT;
            ST_RD_DATA:     if (bit_cnt==0) next_state = ST_RD_DATA_ACK;
            ST_RD_DATA_ACK: next_state = ST_STOP_WAIT;
            ST_STOP_WAIT:   if (stop_cond) next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge SCL or posedge rst) begin
        if (rst) begin
            bit_cnt <= 7;
            shift_reg <= 0;
        end 
        else begin
            if (state==ST_SLAVE_ADDR ||
                state==ST_REG_ADDR ||
                state==ST_WR_DATA)
            begin
                shift_reg[bit_cnt] <= SDA;
                if (bit_cnt != 0) bit_cnt <= bit_cnt-1;
            end
        end
    end

    always_comb begin
        sda_en  = 0;
        sda_out = 1;

        case(state)
            ST_SLAVE_ACK,
            ST_REG_ACK,
            ST_WR_DATA_ACK:
                begin sda_en=1; sda_out=0; end

            ST_RD_DATA:
                begin sda_en=1; sda_out=memory_out[bit_cnt]; end
        endcase
    end

    always_ff @(posedge clk) begin
        if (state==ST_REG_ADDR && bit_cnt==0)
            reg_addr <= {shift_reg[7:1], SDA};

        if (state==ST_WR_DATA && bit_cnt==0)
            mem[reg_addr] <= {shift_reg[7:1], SDA};
    end

    assign wr_rd = (state == ST_RD_DATA);

endmodule
