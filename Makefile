IVERILOG = iverilog
VVP      = vvp
FLAGS    = -g2012

RTL_ALU     = rtl_ve/alu/alu.v rtl_ve/alu/alu_array.v
RTL_REG     = rtl_ve/vregfile/vregisters.v
RTL_PIPE    = rtl_ve/pipeline/hazard_unit.v rtl_ve/pipeline/issue.v rtl_ve/pipeline/execute.v rtl_ve/pipeline/mem.v rtl_ve/pipeline/writeback.v
RTL_LSU     = rtl_ve/lsu/vlsu.v
RTL_TOP     = rtl_ve/ve_top.v
RTL_DECODE  = risc-v_RV32I/core/Modified_DecodeUnit.v
RTL_ALL     = $(RTL_ALU) $(RTL_REG) $(RTL_PIPE) $(RTL_LSU) $(RTL_TOP)
RTL_SCALAR  = risc-v_RV32I/core/FetchUnit.v risc-v_RV32I/core/RegisterFile.v risc-v_RV32I/memory/ICache.v risc-v_RV32I/core/ExecuteUnit.v risc-v_RV32I/core/MemoryUnit.v risc-v_RV32I/core/WriteBack.v risc-v_RV32I/core/Modified_DecodeUnit.v
RTL_INTEGRATED = $(RTL_ALL) $(RTL_SCALAR) risc-v_RV32I/memory/DCache.v rtl_ve/ve_integrated.v

.PHONY: all tb_alu tb_vregfile tb_ve_top tb_vlsu_integration tb_ve_integrated tb_scalar_perf tb_scalar_fwd tb_vector_perf tb_scalar_n8 tb_vector_n8 tb_scalar_n16 tb_vector_n16 tb_vector_fwd_n4 tb_vector_fwd_n8 tb_vector_fwd_n16 clean

all: tb_alu tb_vregfile tb_ve_top tb_vlsu_integration tb_ve_integrated tb_scalar_perf tb_scalar_fwd tb_vector_perf tb_scalar_n8 tb_vector_n8 tb_scalar_n16 tb_vector_n16 tb_vector_fwd_n4 tb_vector_fwd_n8 tb_vector_fwd_n16

tb_alu:
	$(IVERILOG) $(FLAGS) -o sim_alu $(RTL_ALU) testbench/tb_alu.v
	$(VVP) sim_alu
	@echo "Waveform: gtkwave tb_alu.vcd"

tb_vregfile:
	$(IVERILOG) $(FLAGS) -o sim_vregisters $(RTL_REG) testbench/tb_vregfile.v
	$(VVP) sim_vregisters
	@echo "Waveform: gtkwave tb_vregfile.vcd"

tb_ve_top:
	$(IVERILOG) $(FLAGS) -o sim_ve_top $(RTL_ALL) $(RTL_DECODE) testbench/tb_ve_top.v
	$(VVP) sim_ve_top
	@echo "Waveform: gtkwave tb_ve_top.vcd"

tb_vlsu_integration:
	$(IVERILOG) $(FLAGS) -o sim_vlsu_integration $(RTL_LSU) testbench/tb_vlsu_integration.v
	$(VVP) sim_vlsu_integration
	@echo "Waveform: gtkwave tb_vlsu_integration.vcd"

tb_ve_integrated:
	$(IVERILOG) $(FLAGS) -o sim_ve_integrated $(RTL_INTEGRATED) testbench/tb_ve_integrated.v
	$(VVP) sim_ve_integrated
	@echo "Waveform: gtkwave tb_ve_integrated.vcd"

tb_scalar_perf:
	$(IVERILOG) $(FLAGS) -o sim_scalar_perf $(RTL_INTEGRATED) testbench/tb_scalar_perf.v
	$(VVP) sim_scalar_perf
	@echo "Waveform: gtkwave tb_scalar_perf.vcd"

tb_scalar_fwd:
	$(IVERILOG) $(FLAGS) -o sim_scalar_fwd $(RTL_INTEGRATED) testbench/tb_scalar_fwd.v
	$(VVP) sim_scalar_fwd
	@echo "Waveform: gtkwave tb_scalar_fwd.vcd"

tb_vector_perf:
	$(IVERILOG) $(FLAGS) -o sim_vector_perf $(RTL_INTEGRATED) testbench/tb_vector_perf.v
	$(VVP) sim_vector_perf
	@echo "Waveform: gtkwave tb_vector_perf.vcd"

tb_scalar_n8:
	$(IVERILOG) $(FLAGS) -o sim_scalar_n8 $(RTL_INTEGRATED) testbench/tb_scalar_n8.v
	$(VVP) sim_scalar_n8
	@echo "Waveform: gtkwave tb_scalar_n8.vcd"

tb_vector_n8:
	$(IVERILOG) $(FLAGS) -o sim_vector_n8 $(RTL_INTEGRATED) testbench/tb_vector_n8.v
	$(VVP) sim_vector_n8
	@echo "Waveform: gtkwave tb_vector_n8.vcd"

tb_scalar_n16:
	$(IVERILOG) $(FLAGS) -o sim_scalar_n16 $(RTL_INTEGRATED) testbench/tb_scalar_n16.v
	$(VVP) sim_scalar_n16
	@echo "Waveform: gtkwave tb_scalar_n16.vcd"

tb_vector_fwd_n4:
	$(IVERILOG) $(FLAGS) -o sim_vector_fwd_n4 $(RTL_INTEGRATED) testbench/tb_vector_fwd_n4.v
	$(VVP) sim_vector_fwd_n4
	@echo "Waveform: gtkwave tb_vector_fwd_n4.vcd"

tb_vector_fwd_n8:
	$(IVERILOG) $(FLAGS) -o sim_vector_fwd_n8 $(RTL_INTEGRATED) testbench/tb_vector_fwd_n8.v
	$(VVP) sim_vector_fwd_n8
	@echo "Waveform: gtkwave tb_vector_fwd_n8.vcd"

tb_vector_fwd_n16:
	$(IVERILOG) $(FLAGS) -o sim_vector_fwd_n16 $(RTL_INTEGRATED) testbench/tb_vector_fwd_n16.v
	$(VVP) sim_vector_fwd_n16
	@echo "Waveform: gtkwave tb_vector_fwd_n16.vcd"

clean:
	rm -f sim* *.vcd
