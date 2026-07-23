TOP     := lsc_func1_tb
RTL_DIR := ../rtl
OBJ_DIR := obj_dir

RTL_SRCS := $(RTL_DIR)/LSC_Func1.v
TB_SRCS  := lsc_func1_ref_pkg.sv lsc_func1_tb.sv

VERILATOR_FLAGS := --binary --timing --trace -Wall \
                    -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
                    -Wno-BLKSEQ -Wno-SYNCASYNCNET \
                    --top-module $(TOP) -Mdir $(OBJ_DIR)

.PHONY: all run waves clean

all: run

run:
	verilator $(VERILATOR_FLAGS) $(TB_SRCS) $(RTL_SRCS)
	./$(OBJ_DIR)/V$(TOP)

waves:
	gtkwave $(OBJ_DIR)/lsc_func1_tb.vcd &

clean:
	rm -rf $(OBJ_DIR) *.vcd
