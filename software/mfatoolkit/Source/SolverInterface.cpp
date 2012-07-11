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

vector<MFAVariable*> Variables;

int SolverVariableSize() {
	return int(Variables.size());
}

void AddSolverVariable(MFAVariable* InVariable) {
	if (InVariable->Index < int(Variables.size())) {
		Variables[InVariable->Index] = InVariable;
	} else {	
		Variables.push_back(InVariable);
	}
}

vector<MFAVariable*> SolverVariables() {
	return Variables;
}

MFAVariable* GetSolverVariable(int index) {
	return Variables[index];
}

void ClearSolverVariables() {
	Variables.clear();
}

int SelectSolver(int ProbType, int CurrentSolver) {
	if (CurrentSolver == CPLEX) {
		bool licenseFound = false;
		char* licenseCString = getenv("ILOG_LICENSE_FILE");
		if (licenseCString != NULL) {
			string licenseString(licenseCString);
			if (FileExists(licenseString)) {
				licenseFound = true;
			}
		}
		if (licenseFound) {
			return CPLEX;
		} else {
			if (ProbType == LP) {
				return GLPK;
			} else {
				return SOLVER_SCIP;
			}
		}
	}
	if (ProbType == MILP || ProbType == LP) {
		return CurrentSolver;
	} else if (ProbType == QP || ProbType == MIQP) {
		return CPLEX;
	} else if (ProbType == NP || ProbType == MINP) {
		return LINDO;
	}
	return GLPK;
}

int GlobalInitializeSolver(int Solver) {
	ClearSolverVariables();
	if (Solver == CPLEX) {
		CPLEXClearSolver();
		return CPLEXInitialize();
	} else if (Solver == LINDO) {
		LINDOClearSolver();
		return LINDOInitialize();
	} else if (Solver == GLPK) {
		GLPKClearSolver();
		return GLPKInitialize();
	} else if (Solver == SOLVER_SCIP) {
		SCIPClearSolver();
		return SCIPInitialize();
	} else {
		FErrorFile() << "Failed to initialize solver due unrecognized solver." << endl;
		FlushErrorFile();
		return FAIL;
	}
}

OptSolutionData* GlobalRunSolver(int Solver, int ProbType) {
	if (GetParameter("print lp files rather than solve").compare("1") == 0) {
		ofstream JobFileOutput;
		string LPFilename = GetParameter("LP filename");
		if (GetParameter("LP file index").length() == 0) {
			OpenOutput(JobFileOutput,FOutputFilepath()+"MFAOutput/LPFiles/JobFile.txt",false);
			SetParameter("LP file index","0");
			MakeDirectory((FOutputFilepath()+"MFAOutput/LPFiles/").data());
			//ClearDirectory((FOutputFilepath()+"MFAOutput/LPFiles/"));
		} else {
			OpenOutput(JobFileOutput,FOutputFilepath()+"MFAOutput/LPFiles/JobFile.txt",true);
		}
		int count = atoi(GetParameter("LP file index").data());
		JobFileOutput << GetParameter("LP solver filename") << " -s " << GetParameter("LP job directory") << "ScipSettings.txt -f " << GetParameter("LP job directory") << "LPFiles/" << count << ".lp > " << GetParameter("LP job directory") << "Output/OutputFile" << count << ".txt" << endl;
		JobFileOutput.close();
		SetParameter("LP file index",itoa(count+1));
		string Temp("MFAOutput/LPFiles/");
		SetParameter("LP filename",(Temp+itoa(count)+".lp").data());
		GlobalWriteLPFile(Solver);
		SetParameter("LP filename",LPFilename.data());
		return NULL;
	} else if (GetParameter("use solver output files").compare("1") == 0) {
		if (GetParameter("LP file index").length() == 0) {
			SetParameter("LP file index","0");
		}
		int count = atoi(GetParameter("LP file index").data());
		SetParameter("LP file index",itoa(count+1));
		string Temp("MFAOutput/LPFiles/");
		OptSolutionData* NewSolution = ParseSCIPSolution((Temp+"OutputFile"+itoa(count)+".txt").data(),Variables);
		if (NewSolution != NULL) {
			cout << "Objective value: " << NewSolution->Objective << endl;
		}
		return NewSolution;
	}

	if (Solver == CPLEX) {
		return CPLEXRunSolver(ProbType);
	} else if (Solver == LINDO) {
		return LINDORunSolver(ProbType);
	} else if (Solver == GLPK) {
		return GLPKRunSolver(ProbType);
	} else if (Solver == SOLVER_SCIP) {
		return SCIPRunSolver(ProbType);
	}
	FErrorFile() << "Could not run solver. Solver no recognized: " << Solver << endl;
	FlushErrorFile();
	return NULL;
}

int GlobalLoadVariable(int Solver, MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	AddSolverVariable(InVariable);
	if (Solver == CPLEX) {
		return CPLEXLoadVariables(InVariable, RelaxIntegerVariables, UseTightBounds);
	} else if (Solver == LINDO) {
		return LINDOLoadVariables(InVariable, RelaxIntegerVariables, UseTightBounds);
	} else if (Solver == GLPK) {
		return GLPKLoadVariables(InVariable, RelaxIntegerVariables, UseTightBounds);
	} else if (Solver == SOLVER_SCIP) {
		return SCIPLoadVariables(InVariable, RelaxIntegerVariables, UseTightBounds);
	}
	FErrorFile() << "Could not load variable. Solver no recognized: " << Solver << endl;
	FlushErrorFile();
	return FAIL;
}

int GlobalResetSolver(int Solver) {
	ClearSolverVariables();
	if (Solver == CPLEX) {
		return CPLEXClearSolver();
	} else if (Solver == LINDO) {
		return LINDOClearSolver();
	} else if (Solver == GLPK) {
		return GLPKClearSolver();
	} else if (Solver == SOLVER_SCIP) {
		return SCIPClearSolver();
	}
	FErrorFile() << "Could not clear solver. Solver no recognized: " << Solver << endl;
	FlushErrorFile();
	return FAIL;
}

int GlobalLoadObjective(int Solver, LinEquation* InEquation, bool Max) {
	if (Solver == CPLEX) {
		return CPLEXLoadObjective(InEquation, Max);
	} else if (Solver == LINDO) {
		return LINDOLoadObjective(InEquation, Max);
	} else if (Solver == GLPK) {
		return GLPKLoadObjective(InEquation, Max);
	} else if (Solver == SOLVER_SCIP) {
		return SCIPLoadObjective(InEquation, Max);
	}
	FErrorFile() << "Could not load objective. Solver no recognized: " << Solver << endl;
	FlushErrorFile();
	return FAIL;
}

int GlobalWriteLPFile(int Solver) {
	if (Solver == CPLEX) {
		return CPLEXPrintFromSolver();
	} else if (Solver == LINDO) {
		return LINDOPrintFromSolver();
	} else if (Solver == GLPK) {
		return GLPKPrintFromSolver();
	} else if (Solver == SOLVER_SCIP) {
		return SCIPPrintFromSolver();
	} else {
		return FAIL;
	}
}

int GlobalAddConstraint(int Solver, LinEquation* InConstraint) {
	if (Solver == CPLEX) {
		return CPLEXAddConstraint(InConstraint);
	} else if (Solver == LINDO) {
		return LINDOAddConstraint(InConstraint);
	} else if (Solver == GLPK) {
		return GLPKAddConstraint(InConstraint);
	} else if (Solver == SOLVER_SCIP) {
		return SCIPAddConstraint(InConstraint);
	}
	FErrorFile() << "Could not load constraint. Solver not recognized: " << Solver << endl;
	FlushErrorFile();
	return FAIL;
}

int GlobalRemoveConstraint(int Solver, LinEquation* InConstraint) {
	if (Solver == CPLEX) {
		return CPLEXDelConstraint(InConstraint);
	} else if (Solver == LINDO) {
		cout << "GlobalRemoveConstraint not implemented for LINDO yet." << endl;
		return FAIL;
	} else if (Solver == GLPK) {
		cout << "GlobalRemoveConstraint not implemented for GLPK yet." << endl;
		return FAIL;
	} else if (Solver == SOLVER_SCIP) {
		cout << "GlobalRemoveConstraint not implemented for SCIP yet." << endl;
		return FAIL;
	}
	FErrorFile() << "Could not remove constraint. Solver not recognized: " << Solver << endl;
	FlushErrorFile();
	return FAIL;
}