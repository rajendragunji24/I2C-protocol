interface i2c_if(input logic clk, input logic rst);

    tri SDA;
    tri SCL;

    logic sda_out_m, sda_oe_m;
    logic scl_out_m, scl_oe_m;

    logic sda_out_s, sda_oe_s;
    logic scl_out_s, scl_oe_s;

    assign SDA = (sda_oe_m ? sda_out_m :
                  sda_oe_s ? sda_out_s :
                             1'bz);

    assign SCL = (scl_oe_m ? scl_out_m :
                  scl_oe_s ? scl_out_s :
                             1'bz);

    clocking cb_master @(posedge clk);
        output sda_out_m, sda_oe_m;
        output scl_out_m, scl_oe_m;
        input  SDA, SCL;
    endclocking

    clocking cb_slave @(posedge clk);
        output sda_out_s, sda_oe_s;
        input  SDA, SCL;
    endclocking

    modport MASTER (
        clocking cb_master,
        input SDA, input SCL,
        input clk, input rst
    );

    modport SLAVE (
        clocking cb_slave,
        input SDA, input SCL,
        input clk, input rst
    );

    modport MONITOR (
        input SDA, input SCL,
        input clk, input rst
    );

    // ====================================================
    //                     ASSERTIONS
    // ====================================================

    // 1. START condition: SDA FALL when SCL = 1
    property p_start_cond;
        @(posedge clk)
            (SCL==1 && $fell(SDA));
    endproperty
    a_start_condition: assert property(p_start_cond)
        else $error("I2C START condition violated");

    // 2. STOP condition: SDA RISE when SCL = 1
    property p_stop_cond;
        @(posedge clk)
            (SCL==1 && $rose(SDA));
    endproperty
    a_stop_condition: assert property(p_stop_cond)
        else $error("I2C STOP condition violated");

    // 3. SDA must remain stable when SCL = 1 (except START/STOP)
    property p_sda_stable;
        @(posedge clk)
            (SCL==1 && !$fell(SDA) && !$rose(SDA))
            |-> $stable(SDA);
    endproperty
    a_sda_stable: assert property(p_sda_stable)
        else $error("SDA changed while SCL=1 - protocol violation");

    // 4. No device should drive SDA=1 (I2C is open-drain)
    property p_no_drive_high_m;
        @(posedge clk)
            !(sda_oe_m && sda_out_m==1);
    endproperty
    a_no_high_drive_master: assert property(p_no_drive_high_m)
        else $error("Master drove SDA HIGH (illegal in I2C)");

    property p_no_drive_high_s;
        @(posedge clk)
            !(sda_oe_s && sda_out_s==1);
    endproperty
    a_no_high_drive_slave: assert property(p_no_drive_high_s)
        else $error("Slave drove SDA HIGH (illegal in I2C)");

    // 5. SDA should only change when SCL=0
    property p_sda_change_only_scl_low;
        @(posedge clk)
            $changed(SDA) |-> (SCL==0);
    endproperty
    a_sda_change_only_scl_low: assert property(p_sda_change_only_scl_low)
        else $error("SDA changed while SCL high");

endinterface
