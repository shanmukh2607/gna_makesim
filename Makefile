# Variables for details related to the files
GNA-TB_MODULE	:= mkTb
GNA-TB_FILE	:= Tb
GNA-TOP_FILE	:= gna
VERILOG_FILES	:= verilog
BSV_BUILD		:= bsv_build
EXE				:= a.out

# The steps-warn-interval can be increased or decreased to adjust the display of "Prelude" warning
BSCFLAGS := +RTS -K400M -RTS -steps-warn-interval 8000000 \
-steps-max-intervals 10000000

BSC_CMD          := bsc -vdir $(VERILOG_FILES) -bdir $(BSV_BUILD) $(BSCFLAGS) -show-range-conflict -verilog
BSC_SIM          := bsc $(BSCFLAGS) -e 

GNA_test: $(BSV_BUILD)/$(GNA-TOP_FILE).bo $(GNA-TB_FILE).bsv
	@echo "GNA-test: Compiling and running TestBench for GNA Modules..."
	@$(BSC_CMD) $(GNA-TB_FILE).bsv
	@cd $(VERILOG_FILES) && $(BSC_SIM) $(GNA-TB_MODULE) $(GNA-TB_MODULE).v
	@mv $(VERILOG_FILES)/$(EXE) .
	@./a.out

GNA_main $(BSV_BUILD)/$(GNA-TOP_FILE).bo: $(GNA-TOP_FILE).bsv 
	@echo "GNA-main: Compiling" $< "..."
	@$(BSC_CMD) $(GNA-TOP_FILE).bsv

# Keccak-main $(BSV_BUILD)/$(KECCAK_MODULE).bo: $(KECCAK_MODULE).bsv $(BSV_BUILD)/Wire_functions.bo $(BSV_BUILD)/KeccakConstants.bo
# 	@echo "Keccak-main: Compiling" $< "..."
# 	@$(BSC_CMD) $(KECCAK_MODULE).bsv

all: GNA_main GNA_test
	@echo "all: Running all files..."

# prereq $(BSV_BUILD)/Wire_functions.bo $(BSV_BUILD)/KeccakConstants.bo: Wire_functions.bsv KeccakConstants.bsv
# 	@echo "prereq: Compiling prerequisite files..."
# 	@$(BSC_CMD) KeccakConstants.bsv
# 	@$(BSC_CMD) Wire_functions.bsv

clean:
	@echo "Cleaning up..."
	rm $(BSV_BUILD)/*.bo $(VERILOG_FILES)/*.v a.out