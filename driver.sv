
class i2c_driver;

    // Virtual interface for controlling SDA/SCL
    virtual i2c_if.MASTER vif;

    // Mailbox from generator
    mailbox gen2drv;

    // Constructor
    function new(mailbox gen2drv, virtual i2c_if.MASTER vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    // ------------------------------------------------------------------
    // Utility Tasks for I2C signaling
    // ------------------------------------------------------------------

    // I2C START: SDA goes LOW while SCL HIGH
    task i2c_start();
        vif.cb_master.sda_out_m <= 1;
        vif.cb_master.sda_oe_m  <= 1;
        @(posedge vif.clk);

        // SDA low, SCL high
        vif.cb_master.sda_out_m <= 0;
        vif.cb_master.sda_oe_m  <= 1;
        @(posedge vif.clk);
    endtask

    // I2C STOP: SDA goes HIGH while SCL HIGH
    task i2c_stop();
        vif.cb_master.sda_out_m <= 0;
        vif.cb_master.sda_oe_m  <= 1;
        @(posedge vif.clk);

        // SDA high
        vif.cb_master.sda_out_m <= 1;
        @(posedge vif.clk);
    endtask

    // Drive 1 byte (MSB first)
    task send_byte(input [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            vif.cb_master.sda_out_m <= data[i];
            vif.cb_master.sda_oe_m  <= 1;
            @(posedge vif.clk);
        end
    endtask

    // Release SDA and check for ACK from slave
    task recv_ack(output bit ack);
        vif.cb_master.sda_oe_m <= 0; // Release SDA
        @(posedge vif.clk);
        ack = vif.cb_master.SDA; // 0 = ACK, 1 = NACK
        @(posedge vif.clk);
    endtask

    // ------------------------------------------------------------------
    // Main driver task
    // ------------------------------------------------------------------
    task run();
        i2c_transaction tr;
        bit ack;

        forever begin
            // Get transaction from generator
            gen2drv.get(tr);
            $display("[DRIVER] Executing Transaction:");
            tr.display();

            // ============ START CONDITION ================
            i2c_start();

            // ============ SLAVE ADDRESS ==================
            send_byte({tr.slave_addr, tr.rw});
            recv_ack(ack);
            if (ack) $display("[DRIVER] NACK on SLAVE ADDRESS!");

            // ============ REGISTER ADDRESS ================
            send_byte(tr.reg_addr);
            recv_ack(ack);
            if (ack) $display("[DRIVER] NACK on REG ADDRESS!");

            // ============ WRITE OPERATION =================
            if (tr.rw == 0) begin
                send_byte(tr.wr_data);
                recv_ack(ack);
                if (ack)
                    $display("[DRIVER] NACK on WRITE DATA!");
            end

            // (READ implementation can be added next)
            // ------------------------------------------------

            // ============ STOP CONDITION ====================
            i2c_stop();

            // Sample coverage
            tr.cg_i2c.sample();

            @(posedge vif.clk);
        end // forever
    endtask
endclass

endclass
