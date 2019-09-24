`include "defines.v"
`timescale 1ns/1ps

module openmips_sopc_tb();
  reg     CLOCK_50;
  reg     rst;
  
  //时钟脉冲信号     
  initial begin
    CLOCK_50 = 1'b0;
    forever #10 CLOCK_50 = ~CLOCK_50;
  end
  
  //195~1000期间进行仿真
  initial begin
    rst = `RstEnable;
    #195 rst= `RstDisable;
    #4000 $stop;
  end

  //SOPC实例
  sopc sopc0(
		.clk(CLOCK_50),
		.rst(rst)	
	);

endmodule