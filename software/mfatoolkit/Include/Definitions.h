////////////////////////////////////////////////////////////////////////////////
//    MFAToolkit: Software for running flux balance analysis on stoichiometric models
//    Software developer: Christopher Henry (chenry@mcs.anl.gov), MCS Division, Argonne National Laboratory
//    Copyright (C) 2007  Argonne National Laboratory/University of Chicago. All Rights Reserved.
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.
//    For more information on MFAToolkit, see <http://bionet.mcs.anl.gov/index.php/Model_analysis>.
////////////////////////////////////////////////////////////////////////////////

#ifndef DEFINITIONS_H
#define DEFINITIONS_H

//Fundamental database objects
#define REACTION 0
#define COMPOUND 1
#define STRUCTURAL_CUE 2
#define GENE 3

#define ID_NUMBER 0
#define FILENAME 1
#define NAME 2
#define ENTRY 4

#define FLAG 1e7
#define ON 1
#define OFF -1
#define NEUTRAL 0
#define SI_DIGITS 18
#define ALL_DATABASES -1
#define SUCCESS 0
#define FAIL -1
#define NO_MATCH -2
#define UNBOUNDED 1
#define INFEASIBLE 2

//Deletion experiment type
#define SINGLE_KO 0
#define INTERVAL 1
#define FILE_SPECIFIED 2

//Reaction direction indicators
#define FORWARD 1
#define REVERSE 2
#define REVERSIBLE 0
#define FORREVERSIBLE 3
#define REVREVERSIBLE 4
#define DATA 0
#define COA_ID "CoA"
#define NUM_NON_H_COA_ATOMS 48
#define MAX_PATH_LENGTH 50
#define ERROR_LOG "Error.log"
#define OUTPUT_LOG "Output.log"

#define EXCHANGE 3
#define NORMAL 1
#define ALL 3
#define NO_COFACTOR -2
#define UNMARKED 2

//Special references made throughout the program to make it more readable
#define ENZYME -1000
#define PATHWAY -999
#define REACTANT -998
#define PRODUCT -997
#define FROM_FILENAME -996
#define FROM_KEGG -995
#define READ_NO_STRUCTURES -994
#define PRODUCTS_AND_REACTANTS -993
#define INDEX 1

#define ALPHABET "abcdfghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
#define CODES " `1234567890-=qwertyuiop[]asdfghjklzxcvbnm,/~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:ZXCVBNM<>?\""

//Different cycle IDs
#define NUM_CYCLE_TYPES 9
#define BENZENE 8
#define NONBENZENE 7
#define FUSED 6
//Benzene rings not counted in six member rings
#define SIX_MEMBER 5
#define FIVE_MEMBER 4
#define FOUR_MEMBER 3
#define HETERO 2
//Large cycles do not get counted as nonbenzene rings
#define LARGE_CYCLE 1
#define THREE 0 
#define UNKNOWN -1
#define TESTING -2
#define NONE -3
//Ring Mimmicking
#define SAME_AS_SIX 8
#define SAME_AS_LINEAR 20

//Different group atom specifiers
#define HYDROGEN_TO_REMOVE 4
#define HYDROGEN_TO_ADD 5
#define ESSENTIAL_HYDROGEN 6
#define NO_GROUP 255
#define ROOT_ATOM 1000
#define NOT_TO_BE_LABELED 0

//Different physical constants used within the program
#define GAS_CONSTANT 0.0019858775
#define CELL_VOLUME 1.86e-16
#define CELL_MASS 2.84e-13
#define DPSI_COEFF 0.333949
#define DPSI_CONST -3.30299
#define DEBYE_HUCKEL_A 0.5093
#define DEBYE_HUCKEL_B 1.6
#define FARADAY 0.02307
#define PHTOLNH -2.3

//Reaction classes
#define CLASS_P 0
#define CLASS_N 1
#define CLASS_PV 2
#define CLASS_NV 3
#define CLASS_V 4
#define CLASS_B 5

//MFA variable types
#define FLUX 0
#define FORWARD_FLUX 1
#define REVERSE_FLUX 2
#define REACTION_USE 3
#define FORWARD_USE 4
#define REVERSE_USE 5
#define DELTAG 6
#define CONC 7
#define LOG_CONC 8
#define DELTAGF_ERROR 9
#define DRAIN_FLUX 10
#define DELTAGG_ENERGY 11
#define FORWARD_DRAIN_FLUX 12
#define REVERSE_DRAIN_FLUX 13
#define FORWARD_DRAIN_USE 14
#define REVERSE_DRAIN_USE 15
#define DRAIN_USE 16
#define LUMP_USE 17
#define OBJECTIVE_TERMS 18
#define COMPLEX_USE 19
#define GENE_USE 20
#define INTERVAL_USE 21
#define REACTION_DELTAG_ERROR 22
#define GENOME_CUTS 23
#define REACTION_DELTAG_PERROR 24
#define REACTION_DELTAG_NERROR 25
#define DELTAGF_PERROR 26
#define DELTAGF_NERROR 27
#define POTENTIAL 28
#define SMALL_DELTAG_ERROR_USE 29
#define LARGE_DELTAG_ERROR_USE 30

//Logic types
#define AND 0
#define OR 1

//MFA equality types
#define EQUAL 0
#define GREATER 1
#define LESS 2

//Constraint and variable types
#define LINEAR 0
#define NONLINEAR 1
#define QUADRATIC 2
#define LP 3
#define QP 4
#define NP 5
#define MILP 6
#define MIQP 7
#define MINP 8

//MFA constants
#define CRITICAL_FRACTION 0.5
#define MFA_THERMO_CONST 1000
#define MFA_MAX_FEASIBLE_DELTAG -0.001
#define MFA_ZERO_TOLERANCE 1e-9
#define SHADOW_ZERO_TOLERANCE 1e-5
#define SHADOW_MAX_PERTURBATION 0.1
#define BOUND_LOOSENING_FACTOR 0.2
#define DEFAULT_DELTAGF_ERROR 5
// #define ERROR_MULT 4
#define GLPK 0
#define CPLEX 2
#define LINDO 3
#define SOLVER_SCIP 1

#endif
