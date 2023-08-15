//-----------------------------------------------------------------------------
// File:    axis_siggen_pkg.sv.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Enumerate modes supported by axis_siggen
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

package axis_siggen_pkg;
    
    typedef enum integer
                 {
                  SQUAREWAVE,
                  RAMP,
                  SINUSOID,
                  NOISE
                  } siggen_mode;

endpackage : axis_siggen_pkg
