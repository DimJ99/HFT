# Out-of-context Vivado synthesis + timing for one block.
# Invoked by `make synth`; args: <top> <part> <clk_port> <period_ns> <outdir> <src>...
lassign $argv top part clk period outdir
set srcs [lrange $argv 5 end]

file mkdir $outdir
set_part $part
foreach f $srcs {
    if {[string match *.sv $f]} { read_verilog -sv $f } else { read_verilog $f }
}
synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy rebuilt

create_clock -name clk -period $period [get_ports $clk]
set_input_delay  0 -clock clk [get_ports -filter "DIRECTION == IN && NAME != $clk"]
set_output_delay 0 -clock clk [all_outputs]

opt_design
place_design
route_design

report_utilization    -file $outdir/utilization.rpt
report_timing_summary -file $outdir/timing.rpt -max_paths 10
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "== $top @ [format %.2f [expr {1000.0/$period}]] MHz on $part: WNS = $wns ns"
if {$wns < 0} { exit 1 }
