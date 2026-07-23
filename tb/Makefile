RTL_DIR := ../rtl

VERILATOR_FLAGS := --binary --timing --trace -Wall \
                    -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
                    -Wno-BLKSEQ -Wno-SYNCASYNCNET -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

.PHONY: all run run-jrp run-jrp4 waves clean

all: run-jrp run-jrp4

# --- JRP_CONV ----------------------------------------------------------------
JRP_TOP     := jrp_conv_tb
JRP_OBJ_DIR := obj_dir_jrp
JRP_RTL     := $(RTL_DIR)/JRP_CONV.v
JRP_TB      := jrp_conv_ref_pkg.sv jrp_conv_tb.sv

run-jrp:
	verilator $(VERILATOR_FLAGS) --top-module $(JRP_TOP) -Mdir $(JRP_OBJ_DIR) $(JRP_TB) $(JRP_RTL)
	./$(JRP_OBJ_DIR)/V$(JRP_TOP)

# --- JRP_func4 -----------------------------------------------------------
JRP4_TOP     := jrp_func4_tb
JRP4_OBJ_DIR := obj_dir_jrp4
JRP4_RTL     := $(RTL_DIR)/JRP_func4.v
JRP4_TB      := jrp_func4_ref_pkg.sv jrp_func4_tb.sv

# One-shot: exhaustive sim + scoreboard, then plot the transfer curve.
run-jrp4:
	verilator $(VERILATOR_FLAGS) --top-module $(JRP4_TOP) -Mdir $(JRP4_OBJ_DIR) $(JRP4_TB) $(JRP4_RTL)
	./$(JRP4_OBJ_DIR)/V$(JRP4_TOP)
	python3 plot_jrp_func4.py

# Default `make run` picks JRP_CONV for backward compatibility; use
# run-jrp / run-jrp4 explicitly to pick one.
run: run-jrp

waves-jrp:
	gtkwave $(JRP_OBJ_DIR)/jrp_conv_tb.vcd &

waves-jrp4:
	gtkwave $(JRP4_OBJ_DIR)/jrp_func4_tb.vcd &

clean:
	rm -rf $(JRP_OBJ_DIR) $(JRP4_OBJ_DIR) obj_dir *.vcd jrp_func4_sweep.csv jrp_func4_transfer.png
