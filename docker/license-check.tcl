# Minimal synthesis run that requires a Kintex-7 (xc7k410t) license.
read_verilog /opt/x310-aurora/license-check.v
synth_design -top stub -part xc7k410tffg900-2
puts "LICENSE_CHECK_OK"
