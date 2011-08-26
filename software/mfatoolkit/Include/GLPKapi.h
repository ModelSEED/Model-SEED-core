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

#ifndef GLPKAPI_H
#define GLPKAPI_H

int InitializeGLPKVariables();

int GLPKInitialize();

int GLPKCleanup();

int GLPKClearSolver();

int GLPKPrintFromSolver();

OptSolutionData* GLPKRunSolver(int ProbType);

int GLPKLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds);

int GLPKLoadObjective(LinEquation* InEquation, bool Max);

int GLPKAddConstraint(LinEquation* InEquation);

#endif