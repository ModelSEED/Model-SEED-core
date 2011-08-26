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

#include "MFAToolkit.h"

int InitializeSCIPVariables() {
	return SUCCESS;
}

int SCIPInitialize() {
	return GLPKInitialize();
}

int SCIPCleanup() {
	return GLPKCleanup();
}

int SCIPClearSolver() {
	return GLPKClearSolver();
}

int SCIPPrintFromSolver() {
	return GLPKPrintFromSolver();
}

OptSolutionData* SCIPRunSolver(int ProbType) {
	//Printing setting file with scip timelimit
	ofstream Output;
	if (!OpenOutput(Output,FOutputFilepath()+"ScipSettings.txt")) {
		return NULL;
	}
	Output << "limits/time = " << GetParameter("CPLEX solver time limit") << endl;
	Output.close();
	//Printing the problem to an LP file in the output directory
	string CurrentFilename = GetParameter("LP filename");
	SetParameter("LP filename","Problem.lp");
	if (GLPKPrintFromSolver() != SUCCESS) {
		SetParameter("LP filename",CurrentFilename.data());
		return NULL;	
	}
	//Calling the scrip executable
	system((GetParameter("scip executable")+" -s "+FOutputFilepath()+"ScipSettings.txt -f "+FOutputFilepath()+GetParameter("LP filename")+" > "+FOutputFilepath()+"ScipOutput.out").data());
	SetParameter("LP filename",CurrentFilename.data());
	OptSolutionData* NewSolution = ParseSCIPSolution("ScipOutput.out",SolverVariables());
	if (NewSolution != NULL) {
		cout << "Objective value: " << NewSolution->Objective << endl;
	}
	return NewSolution;
}

int SCIPLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	return GLPKLoadVariables(InVariable,RelaxIntegerVariables,UseTightBounds);
}

int SCIPLoadObjective(LinEquation* InEquation, bool Max) {
	return GLPKLoadObjective(InEquation,Max);
}

int SCIPAddConstraint(LinEquation* InEquation) {
	return GLPKAddConstraint(InEquation);
}