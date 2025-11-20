class i2c_transaction;

    // -------------------------------------------------------------
    // Transaction fields
    // -------------------------------------------------------------
    rand bit        start;
    rand bit [6:0]  slave_addr;
    rand bit [7:0]  reg_addr;
    rand bit        rw;
    rand bit [7:0]  wr_data;
         bit [7:0]  rd_data;

    // -------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------
//     constraint C_start      { start == 1; }
//     constraint C_addr_range { slave_addr inside {[7'h00 : 7'h7F]}; }
//     constraint C_rw         { rw inside {0,1}; }

    // -------------------------------------------------------------
    // Functional Coverage — NO clock needed
    // -------------------------------------------------------------
covergroup cg_i2c;
  option.per_instance = 1;

  // One bin per range (NOT an array of bins)
  cp_slave_addr : coverpoint slave_addr {
    bins low_range  = {[7'h00 : 7'h1F]};
    bins mid_range  = {[7'h20 : 7'h5F]};
    bins high_range = {[7'h60 : 7'h7F]};
  }

  cp_rw : coverpoint rw {
    bins write = {0};
    bins read  = {1};
  }

  cp_reg_addr : coverpoint reg_addr {
    bins control_regs = {[8'h00 : 8'h1F]};
    bins data_regs    = {[8'h20 : 8'hDF]};
    bins special_regs = {[8'hE0 : 8'hFF]};
  }

  // Make "others" a single range bin (no [])
  cp_wr_data : coverpoint wr_data {
    bins zero        = {8'h00};
    bins all_one     = {8'hFF};
    bins alternating = {8'hAA, 8'h55};
    bins others      = {[8'h01 : 8'hFE]} with (!(item inside {8'hAA,8'h55}));
  }

  cx_rw_reg_addr : cross cp_rw, cp_reg_addr;
endgroup


    // -------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------
    function new();
        cg_i2c = new();
    endfunction

    // -------------------------------------------------------------
    // Display method
    // -------------------------------------------------------------
    function void display();
        $display("-------------------------------------------------");
        $display(" I2C TRANSACTION");
        $display("  SLAVE ADDR     = 0x%0h", slave_addr);
        $display("  REG ADDR       = 0x%0h", reg_addr);
        $display("  RW             = %0s", rw ? "READ" : "WRITE");
        $display("  WRITE DATA     = 0x%0h", wr_data);
        $display("  READ  DATA     = 0x%0h", rd_data);
        $display("-------------------------------------------------");
    endfunction

endclass
