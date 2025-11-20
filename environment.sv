`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
// ======================================================================
// I2C ENVIRONMENT (UVM-Lite)
// - Instantiates generator, driver, monitor, scoreboard
// - Connects all via mailboxes and interface
// - Runs all concurrently
// ======================================================================

class i2c_environment;

    // Virtual Interface Handle
    virtual i2c_if vif;

    // Environment Components
    i2c_generator   gen;
    i2c_driver      drv;
    i2c_monitor     mon;
    i2c_scoreboard  scb;

    // Mailboxes
    mailbox gen2drv;
    mailbox mon2scb;

    // Number of transactions
    int num_txn;

    // Constructor
    function new(virtual i2c_if vif, int num_txn = 10);
        this.vif      = vif;
        this.num_txn  = num_txn;

        // Instantiate mailboxes
        gen2drv = new();
        mon2scb = new();

        // Instantiate env components
        gen = new(gen2drv, num_txn, 1);    // random_mode=1
        drv = new(gen2drv, vif.MASTER);    // driver uses MASTER modport
        mon = new(vif.MONITOR, mon2scb);   // monitor uses MONITOR modport
        scb = new(mon2scb);                // scoreboard
    endfunction


    // ==================================================================
    // RUN THE ENVIRONMENT
    // ==================================================================
    task run();
        $display("\n===============================");
        $display("   I2C ENVIRONMENT STARTED");
        $display("===============================\n");

        fork
            gen.run();  // Generate transactions
            drv.run();  // Drive interface to DUT
            mon.run();  // Passive observation
            scb.run();  // Check correctness
        join_any

        $display("\n===============================");
        $display("  I2C ENVIRONMENT FINISHED");
        $display("===============================\n");
    endtask

endclass
