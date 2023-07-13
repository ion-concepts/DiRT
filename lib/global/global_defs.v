//-------------------------------------------------------------------------------
// File:   global_defs.v
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Global Definitions for the DiRT library.
//
//  License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------//

`timescale 1ns/1ps

// Booleans
`define FALSE 1'b0
`define TRUE 1'b1

// LOG2 function
`define LOG2(N) (\
                 N < 2 ? 0 : \
                 N < 4 ? 1 : \
                 N < 8 ? 2 : \
                 N < 16 ? 3 : \
                 N < 32 ? 4 : \
                 N < 64 ? 5 : \
                 N < 128 ? 6 : \
                 N < 256 ? 7 : \
                 N < 512 ? 8 : \
                 N < 1024 ? 9 : \
                 N < 2048 ? 10 : \
                 N < 4096 ? 11 : \
                 N < 8192 ? 12 : \
                 N < 16384 ? 13 : \
                 N < 32768 ? 14 : \
                 N < 65536 ? 15 : \
                 16)


