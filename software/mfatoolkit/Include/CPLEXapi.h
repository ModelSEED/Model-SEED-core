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

#ifndef CPLEXAPI_H
#define CPLEXAPI_H

int InitializeCPLEXVariables();

int CPLEXInitialize();

int CPLEXCleanup();

int CPLEXClearSolver();

int CPLEXPrintFromSolver();

OptSolutionData* CPLEXRunSolver(int ProbType);

int CPLEXLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds);

int CPLEXLoadObjective(LinEquation* InEquation, bool Max);

int CPLEXAddConstraint(LinEquation* InEquation);

int CPLEXDelConstraint(LinEquation* InEquation);

#endif