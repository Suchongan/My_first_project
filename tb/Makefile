RTL_DIR := ../rtl

VERILATOR_FLAGS := --binary --timing --trace -Wall \
                    -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
                    -Wno-BLKSEQ -Wno-SYNCASYNCNET -Wno-WIDTHEXPAND

.PHONY: all run run-lsc run-jrp waves clean

all: run-lsc run-jrp

# --- LSC_Func1 -------------------------------------------------------------
LSC_TOP     := lsc_func1_tb
LSC_OBJ_DIR := obj_dir_lsc
LSC_RTL     := $(RTL_DIR)/LSC_Func1.v
LSC_TB      := lsc_func1_ref_pkg.sv lsc_func1_tb.sv

run-lsc:
	verilator $(VERILATOR_FLAGS) --top-module $(LSC_TOP) -Mdir $(LSC_OBJ_DIR) $(LSC_TB) $(LSC_RTL)
	./$(LSC_OBJ_DIR)/V$(LSC_TOP)

# --- JRP_CONV ----------------------------------------------------------------
JRP_TOP     := jrp_conv_tb
JRP_OBJ_DIR := obj_dir_jrp
JRP_RTL     := $(RTL_DIR)/JRP_CONV.v
JRP_TB      := jrp_conv_ref_pkg.sv jrp_conv_tb.sv

run-jrp:
	verilator $(VERILATOR_FLAGS) --top-module $(JRP_TOP) -Mdir $(JRP_OBJ_DIR) $(JRP_TB) $(JRP_RTL)
	./$(JRP_OBJ_DIR)/V$(JRP_TOP)

# Default `make run` picks LSC_Func1 for backward compatibility; use
# run-lsc / run-jrp explicitly to pick one.
run: run-lsc

waves-lsc:
	gtkwave $(LSC_OBJ_DIR)/lsc_func1_tb.vcd &

waves-jrp:
	gtkwave $(JRP_OBJ_DIR)/jrp_conv_tb.vcd &

clean:
	rm -rf $(LSC_OBJ_DIR) $(JRP_OBJ_DIR) obj_dir *.vcd
