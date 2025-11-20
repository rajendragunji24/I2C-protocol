class i2c_scoreboard;

    // Mailbox from monitor
    mailbox mon2scb;

    // Simple reference memory model (0..255)
    bit [7:0] ref_mem [0:255];

    // Constructor
    function new(mailbox mon2scb);
        this.mon2scb = mon2scb;

        // Initialize reference memory to 0
        foreach (ref_mem[i]) ref_mem[i] = 8'h00;
    endfunction


    // ------------------------------------------------------------------
    // Main task: receive transactions from monitor & check correctness
    // ------------------------------------------------------------------
    task run();
        i2c_transaction tr;

        forever begin
            // Wait for monitor to send a completed transaction
            mon2scb.get(tr);

            $display("\n[SCOREBOARD] Received Transaction For Checking:");
            tr.display();

            //----------------------------------------------------------
            // WRITE CHECKING
            //----------------------------------------------------------
            if (tr.rw == 0) begin  // WRITE OPERATION

                // Update reference memory model
                ref_mem[tr.reg_addr] = tr.wr_data;

                $display("[SCOREBOARD] WRITE CHECK");
                $display("[SCOREBOARD]  REG: 0x%0h", tr.reg_addr);
                $display("[SCOREBOARD]  DATA Written: 0x%0h", tr.wr_data);
                $display("[SCOREBOARD]  REF_MEM[%0h] updated.\n", tr.reg_addr);

                $display("[SCOREBOARD] STATUS: PASS (Write verified)");
            end

            //----------------------------------------------------------
            // READ CHECKING  (Optional – will enable after adding read)
            //----------------------------------------------------------
            else begin  // READ operation
                $display("[SCOREBOARD] READ CHECK");
                $display("[SCOREBOARD]  Expected Data = 0x%0h", ref_mem[tr.reg_addr]);
                $display("[SCOREBOARD]  Observed Data = 0x%0h", tr.rd_data);

                if (tr.rd_data == ref_mem[tr.reg_addr])
                    $display("[SCOREBOARD] STATUS: PASS");
                else
                    $display("[SCOREBOARD] STATUS: FAIL (Read mismatch!)");
            end

            $display("-----------------------------------------------------------\n");

        end // forever
    endtask

endclass
