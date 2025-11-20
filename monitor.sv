
class i2c_monitor;

    // Monitor interface (read-only)
    virtual i2c_if.MONITOR vif;

    // Mailbox to send observed transactions to Scoreboard
    mailbox mon2scb;

    // Internal sampling states
    typedef enum {IDLE, START_DETECTED, BYTE_SHIFT, ACK_BIT} mon_state_t;
    mon_state_t mstate;

    int bit_cnt;
    byte current_byte;
    bit [7:0] slave_addr;
    bit [7:0] reg_addr;
    bit [7:0] wr_data;
    bit rw;

    // Constructor
    function new(virtual i2c_if.MONITOR vif, mailbox mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        mstate       = IDLE;
    endfunction


    // Detect START: SDA falling while SCL high
    function bit start_condition();
        return (vif.SDA == 0 && vif.SCL == 1);
    endfunction

    // Detect STOP: SDA rising while SCL high
    function bit stop_condition();
        return (vif.SDA == 1 && vif.SCL == 1);
    endfunction


    // ------------------------------------------------------------------
    // MAIN MONITOR TASK
    // ------------------------------------------------------------------
    task run();
        i2c_transaction tr;

        forever begin
            @(posedge vif.SCL); // Sample on SCL rising edge

            case (mstate)

                // ======================================================
                // WAIT FOR START CONDITION
                // ======================================================
                IDLE: begin
                    if (start_condition()) begin
                        mstate  = START_DETECTED;
                        bit_cnt = 7;
                        current_byte = 0;
                        $display("[MONITOR] START detected");
                    end
                end

                // ======================================================
                // SHIFT SLAVE ADDRESS BYTE (7 bits + R/W)
                // ======================================================
                START_DETECTED: begin
                    current_byte[bit_cnt] = vif.SDA;

                    if (bit_cnt == 0) begin
                        slave_addr = current_byte[7:1];
                        rw         = current_byte[0];
                        $display("[MONITOR] SLAVE ADDR = 0x%0h, RW=%0b", slave_addr, rw);
                        mstate = ACK_BIT;
                    end
                    else bit_cnt--;
                end

                // ======================================================
                // ACK BIT AFTER SLAVE ADDRESS
                // ======================================================
                ACK_BIT: begin
                    // Just skip ACK cycle (monitor does not drive)
                    @(posedge vif.clk);
                    bit_cnt = 7;
                    current_byte = 0;

                    // Move to REG_ADDR state
                    mstate = BYTE_SHIFT;
                end

                // ======================================================
                // SHIFT REGISTER ADDRESS + SHIFT WRITE-DATA
                // ======================================================
                BYTE_SHIFT: begin
                    current_byte[bit_cnt] = vif.SDA;

                    if (bit_cnt == 0) begin
                        // First byte = Register Address
                        if (reg_addr === 'x) begin
                            reg_addr = current_byte;
                            $display("[MONITOR] REG ADDR = 0x%0h", reg_addr);
                        end
                        else begin
                            // Second byte = Write Data
                            wr_data = current_byte;
                            $display("[MONITOR] WRITE DATA = 0x%0h", wr_data);
                        end

                        mstate = ACK_BIT;
                    end
                    else bit_cnt--;
                end

                default: mstate = IDLE;

            endcase

            // ==========================================================
            // STOP CONDITION → Transaction Complete
            // ==========================================================
            if (stop_condition()) begin

                tr = new();
                tr.start      = 1;
                tr.slave_addr = slave_addr;
                tr.reg_addr   = reg_addr;
                tr.rw         = rw;
                tr.wr_data    = wr_data;

                tr.cg_i2c.sample(); // sample coverage

                $display("\n[MONITOR] COMPLETE TRANSACTION:");
                tr.display();

                mon2scb.put(tr);

                // Reset state machine
                reg_addr = 'x;
                wr_data  = 'x;
                mstate   = IDLE;
            end

        end // forever
    endtask

endclass
