# Populate Vivado's per-user Tcl app store ($HOME/.Xilinx) in a single process.
# The IP flow loads these apps on demand; when several first-run Vivado
# processes do that concurrently in a fresh HOME they race on the store and
# fail with "Tcl app ... is out of date" / "Unable to load Tcl app".
foreach app {aldec::riviera} {
    catch {::tclapp::install $app}
    catch {::tclapp::load_app $app}
}
puts "VIVADO_WARMUP_OK"
