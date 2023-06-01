package Tb;

import gna::*;

(*synthesize*)
module mkTb(Empty);

    Ifc_gna dut <- mkGNA;

    Reg#(int) x <- mkReg(4);
    Reg#(int) y <- mkReg(4);
    Reg#(int) n <- mkReg(1);
    Reg#(int) kh <- mkReg(3);
    Reg#(int) kl <- mkReg(3);
    Reg#(int) m <- mkReg(4);
    Reg#(int) cntr <- mkReg(0);
    Reg#(int) cycle_cntr <- mkReg(0);

    rule load_inputs(cntr == 0);
        // dut.reset_input_buffer();
        $display("\nInputs1: H = %d, L = %d N = %d\n", x, y, n);    
        dut.get_weight_size(kh, kl, m);
        dut.get_input_size(x, y, n);
        cntr <= cntr + 1;
    endrule 

    rule read_output(cntr == 1);
        let res_kkl = dut.check_kkl();
        let res_n = dut.check_n();
        let res_l = dut.check_l();
        let res_kkh = dut.check_kkh();
        let res_m = dut.check_m();
        let res_h = dut.check_h();
        let inp = dut.read_check();
        $display("%d\n",inp);
        cntr <= dut.done();
        cycle_cntr <= cycle_cntr + 1;
        $display("h = %d, m = %d, kkh = %d, l = %d, n = %d, kkl = %d\n",res_h, res_m, res_kkh, res_l, res_n, res_kkl);
        // $display("m = %d, kkh = %d, l = %d, n = %d, kkl = %d\n",res_m, res_kkh, res_l, res_n, res_kkl);
    endrule

    rule end_op(cntr == 2);
        let state = dut.state_check();
        $display("%d %d",cycle_cntr,state);
        $finish(0);
    endrule
    


endmodule

endpackage
