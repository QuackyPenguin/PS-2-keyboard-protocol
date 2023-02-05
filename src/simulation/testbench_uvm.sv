`include "uvm_macros.svh"
import uvm_pkg::*;

// Sequence Item
class ps2_item extends uvm_sequence_item;

	rand bit ps2_clk;
	rand bit in;
	bit [7:0] out_hex1;
	bit [7:0] out_hex2;
	
	`uvm_object_utils_begin(ps2_item)
		`uvm_field_int(ps2_clk, UVM_DEFAULT)
		`uvm_field_int(in, UVM_DEFAULT)
		`uvm_field_int(out_hex1, UVM_DEFAULT)
		`uvm_field_int(out_hex2, UVM_DEFAULT)
	`uvm_object_utils_end
	
	function new(string name = "ps2_item");
		super.new(name);
	endfunction
	
	virtual function string my_print();
		return $sformatf(
			"ps2_clk = %1b in = %1b out_hex1 = %8b out_hex2 = %8b",
			ps2_clk, in, out_hex1, out_hex2
		);
	endfunction

endclass

// Sequence
class generator extends uvm_sequence;

	`uvm_object_utils(generator)
	
	function new(string name = "generator");
		super.new(name);
	endfunction
	
	int num = 20000;
	
	virtual task body();
		for (int i = 0; i < num; i++) begin
			ps2_item item = ps2_item::type_id::create("item");
			start_item(item);
			item.randomize();
			`uvm_info("Generator", $sformatf("Item %0d/%0d created", i+1, num), UVM_LOW)
			item.print();
			finish_item(item);
		end
	endtask
	
endclass

// Driver
class driver extends uvm_driver #(ps2_item);
	
	`uvm_component_utils(driver)
	
	function new(string name = "driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Driver", "No interface.")
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			ps2_item item;
			seq_item_port.get_next_item(item);
			`uvm_info("Driver", $sformatf("%s", item.my_print()), UVM_LOW)
			vif.ps2_clk <= item.ps2_clk;
			vif.in <= item.in;
			@(posedge vif.clk);
			seq_item_port.item_done();
		end
	endtask
	
endclass

// Monitor

class monitor extends uvm_monitor;
	
	`uvm_component_utils(monitor)
	
	function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;
	uvm_analysis_port #(ps2_item) mon_analysis_port;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Monitor", "No interface.")
		mon_analysis_port = new("mon_analysis_port", this);
	endfunction
	
	virtual task run_phase(uvm_phase phase);	
		super.run_phase(phase);
		@(posedge vif.clk);
		forever begin
			ps2_item item = ps2_item::type_id::create("item");
			@(posedge vif.clk);
			item.ps2_clk = vif.ps2_clk;
			item.in = vif.in;
			item.out_hex1 = vif.out_hex1;
			item.out_hex2 = vif.out_hex2;
			`uvm_info("Monitor", $sformatf("%s", item.my_print()), UVM_LOW)
			mon_analysis_port.write(item);
		end
	endtask
	
endclass

// Agent
class agent extends uvm_agent;
	
	`uvm_component_utils(agent)
	
	function new(string name = "agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	driver d0;
	monitor m0;
	uvm_sequencer #(ps2_item) s0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		d0 = driver::type_id::create("d0", this);
		m0 = monitor::type_id::create("m0", this);
		s0 = uvm_sequencer#(ps2_item)::type_id::create("s0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d0.seq_item_port.connect(s0.seq_item_export);
	endfunction
	
endclass

// Scoreboard
class scoreboard extends uvm_scoreboard;
	
	`uvm_component_utils(scoreboard)
	
	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	uvm_analysis_imp #(ps2_item, scoreboard) mon_analysis_imp;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_analysis_imp = new("mon_analysis_imp", this);
	endfunction
	
	bit [7:0] ps2_1 = 8'h00;
	bit [7:0] ps2_2 = 8'h00;
	bit [7:0] reg1 = 8'h00;
	bit [7:0] reg2 = 8'h00;

	bit last_ps2_clk = 1'b0;
	bit [2:0] counter = 3'b000;
	bit [1:0] state = 2'b00;
	bit parity = 1'b0;
	bit parity_check = 1'b0;
	integer i;
	
	virtual function write(ps2_item item);
		if (ps2_1 == item.out_hex1 && ps2_2 == item.out_hex2)
			`uvm_info("Scoreboard", $sformatf("PASS! %8b %b", reg1, parity), UVM_LOW)
		else
			`uvm_error("Scoreboard", $sformatf("FAIL! expected = %8b and %8b, got = %8b and %8b", ps2_1, ps2_2, item.out_hex1, item.out_hex2))
		
		if(last_ps2_clk == 1'b1 && item.ps2_clk == 1'b0)  begin //falling edge of ps2_clk
			case (state)
				2'b00: begin //init
					if(item.in == 0) begin
						state = 2'b01;
						if(reg1 == 8'he0 || reg1 == 8'hf0) begin
							reg2= reg1;
							reg1=8'h00;
						end
						else begin
							reg1 = 8'h00;
							reg2 = 8'h00;
						end

						counter = 3'b000;
					end	
				end
				2'b01: begin //data
					reg1[counter] = item.in;
					if(counter == 3'b111) begin
						counter = 3'b000;
						state = 2'b10;
					end
					else begin
						counter = counter + 1;
					end
				end 
				2'b10: begin //parity
					state = 2'b11;
					parity = item.in;
				end
				2'b11: begin
					parity_check = 1'b0;
                	for(i =0; i<8; i=i+1) begin
                    	parity_check = parity_check ^ reg1[i];
                	end
                	parity_check = parity_check ^ parity;
                	parity = 1'b0;

					if(item.in == 1'b0 || parity_check == 1'b0) begin
						reg1=8'h00;
						reg2=8'h00;
					end
					else begin
						if(reg1 != 8'he0 && reg1 != 8'hf0) begin
							ps2_1=reg1;
							ps2_2=reg2;
						end
					end
					state = 2'b00;
				end
			endcase
		end

		last_ps2_clk = item.ps2_clk;
	endfunction
	
endclass

// Environment
class env extends uvm_env;
	
	`uvm_component_utils(env)
	
	function new(string name = "env", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	agent a0;
	scoreboard sb0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		a0 = agent::type_id::create("a0", this);
		sb0 = scoreboard::type_id::create("sb0", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		a0.m0.mon_analysis_port.connect(sb0.mon_analysis_imp);
	endfunction
	
endclass

// Test
class test extends uvm_test;

	`uvm_component_utils(test)
	
	function new(string name = "test", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	virtual ps2_if vif;

	env e0;
	generator g0;
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if (!uvm_config_db#(virtual ps2_if)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("Test", "No interface.")
		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction
	
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		vif.rst_n <= 0;
		#20 vif.rst_n <= 1;
		
		g0.start(e0.a0.s0);
		phase.drop_objection(this);
	endtask

endclass

// Interface
interface ps2_if (
	input bit clk
);

	logic rst_n;
	logic ps2_clk;
    logic in;
    logic [7:0] out_hex1;
    logic [7:0] out_hex2;

endinterface

// Testbench
module testbench_uvm;

	reg clk;
	
	ps2_if dut_if (
		.clk(clk)
	);
	
	ps2 dut (
		.clk(clk),
		.rst_n(dut_if.rst_n),
		.ps2_clk(dut_if.ps2_clk),
		.in(dut_if.in),
		.out_hex1(dut_if.out_hex1),
		.out_hex2(dut_if.out_hex2)
	);

	initial begin
		clk = 0;
		forever begin
			#10 clk = ~clk;
		end
	end

	initial begin
		uvm_config_db#(virtual ps2_if)::set(null, "*", "ps2_vif", dut_if);
		run_test("test");
	end

endmodule
