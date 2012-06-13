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
#include "cplex.h"

CPXENVptr CPLEXenv;
CPXLPptr CPLEXModel;

int InitializeCPLEXVariables() {
	CPLEXenv = NULL;
	CPLEXModel = NULL;
	return SUCCESS;
}

int CPLEXInitialize() {
	int Status = 0;
	
	//First I open the CPLEX environment if it is not already open
	if (CPLEXenv == NULL) {
		CPLEXenv = CPXopenCPLEX (&Status);
	}
	if (CPLEXenv == NULL || Status) {
		FErrorFile() << "Failed to initialize CPLEX environment. Check license server on aterneus." << endl;
		FlushErrorFile();
		return FAIL;
	}

	//Now I set any environment variables
	Status = CPXsetintparam(CPLEXenv, CPX_PARAM_SCRIND, CPX_ON);
	Status = CPXsetdblparam(CPLEXenv, CPX_PARAM_WORKMEM, 50);
	Status = CPXsetstrparam(CPLEXenv, CPX_PARAM_WORKDIR, FOutputFilepath().data());
	Status = CPXsetintparam(CPLEXenv, CPX_PARAM_NODEFILEIND, 2);
	Status = CPXsetdblparam(CPLEXenv, CPX_PARAM_TRELIM, 50);

	if (Status) {
		FErrorFile() << "Failed to set screen indicators to on." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (GetParameter("CPLEX solver time limit").length() > 0 && GetParameter("CPLEX solver time limit").compare("none") != 0) { 
		Status = CPXsetdblparam (CPLEXenv, CPX_PARAM_TILIM, atof(GetParameter("CPLEX solver time limit").data()));
		if (Status) {
			FErrorFile() << "Failed to set CPLEX time limit." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	//I set the number of processors to run on if allowed to
	
	// SYSTEM_INFO sysinfo;
	// GetSystemInfo( &sysinfo );

	// int numCPU = sysinfo.dwNumberOfProcessors;

	Status = CPXsetintparam(CPLEXenv, CPX_PARAM_THREADS, 1);
	Status = CPXsetintparam(CPLEXenv, CPX_PARAM_PARALLELMODE, 0);
	Status = CPXsetintparam (CPLEXenv, CPX_PARAM_MIPDISPLAY, 0);

	//Next I clear out any models that currently exist
	if (CPLEXClearSolver() != SUCCESS) {
		return FAIL; //error message already printed	
	}

	//Now I create a new CPLEX model
	CPLEXModel = CPXcreateprob (CPLEXenv, &Status, "LPProb");
	Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_LP);
	if (Status || CPLEXModel == NULL) {
		FErrorFile() << "Failed to create new CPLEX model." << endl;
		FlushErrorFile();
		return FAIL;
	}

	return SUCCESS;
}


int CPLEXCleanup() {
	int Status = 0;
	if (CPLEXModel != NULL) {
		if (CPLEXClearSolver() != SUCCESS) {
			return FAIL;		
		}
	}
	
	if (CPLEXenv != NULL) {
		Status = CPXcloseCPLEX (&CPLEXenv);
		if (Status) {
			FErrorFile() << "Could not close CPLEX environment." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	return SUCCESS;
}

int CPLEXClearSolver() {
	int Status = 0;
	if (CPLEXModel != NULL) {
		Status = CPXfreeprob(CPLEXenv, &CPLEXModel);
	}

	if (Status || CPLEXModel != NULL) {
		FErrorFile() << "Failed to delete old CPLEX model." << endl;\
		FlushErrorFile();
		return FAIL;
	}

	return SUCCESS;
}

int CPLEXPrintFromSolver() {
	int Status = 0;
	if (CPLEXenv == NULL) {
		FErrorFile() << "Cannot print problem to file because CPLEX environment is not open." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (CPLEXModel == NULL) {
		FErrorFile() << "Cannot print problem to file because no CPLEX model exists." << endl;
		FlushErrorFile();
		return FAIL;
	}
	
	string Filename = CheckFilename(FOutputFilepath()+GetParameter("LP filename"));
	Status = CPXwriteprob (CPLEXenv, CPLEXModel,Filename.data(), "LP");

	if (Status) {
		FErrorFile() << "Cannot print problem to file for unknown reason." << endl;
		FlushErrorFile();
		return FAIL;
	}

	return SUCCESS;
}

OptSolutionData* CPLEXRunSolver(int ProbType) {
	OptSolutionData* NewSolution = NULL;
	int Status = 0;
	if (ProbType == LP) {
		Status = CPXsetintparam (CPLEXenv, CPX_PARAM_LPMETHOD, CPX_ALG_AUTOMATIC);
		if (Status) {
			FErrorFile() << "Failed to set the optimization method." << endl;
			FlushErrorFile();
			return NULL;
		}
		Status = CPXsetintparam (CPLEXenv, CPX_PARAM_SIMDISPLAY, 0);
		if (Status) {
			FErrorFile() << "Failed to set the optimization method." << endl;
			FlushErrorFile();
			return NULL;
		}
		Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_LP);
		Status = CPXlpopt(CPLEXenv, CPLEXModel);
	} else if(ProbType == MILP || ProbType == MIQP) {
		//Setting the bound tightening on high
		Status = CPXsetintparam (CPLEXenv, CPX_PARAM_BNDSTRENIND, 1);
		if (Status) {
			FErrorFile() << "Failed to set the optimization method." << endl;
			FlushErrorFile();
			return NULL;
		}
		//Setting tolerance to 1e-9 instead of 1e-6
		double tolerance = atof(GetParameter("Solver tolerance").data());
		Status = CPXsetdblparam(CPLEXenv,CPX_PARAM_EPRHS, 1e-9);
		if (Status) {
			FErrorFile() << "Failed to set the optimization method." << endl;
			FlushErrorFile();
			return NULL;
		}
		Status = CPXsetdblparam(CPLEXenv,CPX_PARAM_EPINT, 1e-9);
		if (Status) {
			FErrorFile() << "Failed to set the optimization method." << endl;
			FlushErrorFile();
			return NULL;
		}
		//Deactivates all messages from MIP solver
		Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_MILP);
		Status = CPXmipopt (CPLEXenv, CPLEXModel);
	} else if(ProbType == QP) {
		Status = CPXqpopt (CPLEXenv, CPLEXModel);
	}
	if (Status ) {
		cout << "Failed to optimize LP." << endl;
		return NULL;
	}
	int Temp = CPXgetstat (CPLEXenv, CPLEXModel);
	NewSolution = new OptSolutionData;
	if (Temp == CPX_STAT_UNBOUNDED) {
		cout << "Model is unbounded" << endl;
		FErrorFile() << "Model is unbounded" << endl;
		FlushErrorFile();
		NewSolution->Status = UNBOUNDED;
		return NewSolution;
	} else if (Temp == CPX_STAT_INFEASIBLE) {
		cout << "Model is infeasible" << endl;
		FErrorFile() << "Model is infeasible" << endl;
		FlushErrorFile();
		NewSolution->Status = INFEASIBLE;
		return NewSolution;
	} else if (Temp == CPX_STAT_INForUNBD ) {
		cout << "Model is infeasible or unbounded" << endl;
		FErrorFile() << "Model is infeasible or unbounded" << endl;
		FlushErrorFile();
		NewSolution->Status = INFEASIBLE;
		return NewSolution;
	} else {
		NewSolution->Status = SUCCESS;
	}

	int NumberColumns = CPXgetnumcols (CPLEXenv, CPLEXModel);
	int NumberRows = CPXgetnumrows (CPLEXenv, CPLEXModel);
	NewSolution->NumVariables = NumberColumns;
	NewSolution->SolutionData.resize(NumberColumns);

	double* x = new double[NumberColumns];
	
	if (ProbType == MILP || ProbType == MIQP) {
		Status = CPXgetmipobjval (CPLEXenv, CPLEXModel, &(NewSolution->Objective));
		Status = CPXgetmipx (CPLEXenv, CPLEXModel, x, 0, NumberColumns-1);
	} else {
		Status = CPXsolution(CPLEXenv,CPLEXModel,NULL,&(NewSolution->Objective),x,NULL,NULL,NULL);
	}
	
	if ( Status ) {
		cout << "Failed to obtain objective value." << endl;
		delete [] x;
		NewSolution->Status = INFEASIBLE;
		return NewSolution;
	}

	cout << "Objective value: " << NewSolution->Objective << endl;
	/*
	string* StrNames = new string[NumberColumns];
	char** Names = new char*[NumberColumns];
	char* NameStore = new char[7*NumberColumns];
	int Surplus = 0;

	Status = CPXgetcolname(CPLEXenv, CPLEXModel, Names, NameStore, 7*NumberColumns, &Surplus, 0, NumberColumns-1);
	if (Status) {
		FErrorFile() << "Failed to get column names." << endl;
		FlushErrorFile();
		delete [] StrNames;
		delete [] Names;
		delete [] NameStore;
		delete [] x;
		delete NewSolution;
		return NULL;
	}
	*/
	for (int i=0; i < NumberColumns; i++) {
		//StrNames[i].assign(Names[i]);
		//StrNames[i] = StrNames[i].substr(1, StrNames[i].length()-1);
		//NewSolution->SolutionData[atoi(StrNames[i].data())-1] = x[i];
		NewSolution->SolutionData[i] = x[i];
	}
	/*
	delete [] StrNames;
	delete [] Names;
	delete [] NameStore;
	*/
	delete [] x;

	return NewSolution;
}

int CPLEXLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	int Status = 0;
	
	//First I check the number of columns. If it's larger than the index, then this variable already exists and is only being changed
	int NumberColumns = CPXgetnumcols (CPLEXenv, CPLEXModel);
	if (NumberColumns <= InVariable->Index) {
		string StrName = GetMFAVariableName(InVariable);
		
		double* LB = new double;
		LB[0] = InVariable->LowerBound;
		double* UB = new double;
		UB[0] = InVariable->UpperBound;
		if (UseTightBounds) {
			LB[0] = InVariable->Min;
			UB[0] = InVariable->Max;
		}
		double* Obj = new double;
		Obj[0] = 0;
		char* Temp = new char;
		char** Name = new char*;
		Name[0] = new char[StrName.length()+1];
		strcpy(Name[0],StrName.data());
		
		if (InVariable->Binary && !RelaxIntegerVariables) {
			Temp[0] = CPX_BINARY;
			Status = CPXnewcols (CPLEXenv, CPLEXModel, 1, Obj, LB, UB, Temp, Name);
		} else if (InVariable->Integer && !RelaxIntegerVariables) {
			Temp[0] = CPX_INTEGER;
			Status = CPXnewcols (CPLEXenv, CPLEXModel, 1, Obj, LB, UB, Temp, Name);
		} else {
			Temp[0] = CPX_CONTINUOUS;
			Status = CPXnewcols (CPLEXenv, CPLEXModel, 1, Obj, LB, UB, Temp, Name);
		}

		delete LB;
		delete UB;
		delete Obj;
		delete Temp;
		delete [] Name[0];
		delete Name;

		if (Status ) {
			FErrorFile() << "Could not add variable " << InVariable->Index << endl;
			FlushErrorFile();
			return FAIL;
		}
	} else {
		double* Bounds = new double[2];
		Bounds[0] = InVariable->LowerBound;
		Bounds[1] = InVariable->UpperBound;
		
		int* Indices = new int[2];
		Indices[0] = InVariable->Index;
		Indices[1] = InVariable->Index;

		Status = CPXchgbds (CPLEXenv, CPLEXModel, 2, Indices, "LU", Bounds);
		
		delete [] Bounds;
		delete [] Indices;

		if (Status) {
			FErrorFile() << "Could not change bounds on variable " << InVariable->Index << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	return SUCCESS;
}

int CPLEXLoadObjective(LinEquation* InEquation, bool Max) {
	int NumCols = CPXgetnumcols(CPLEXenv, CPLEXModel);
	int Status = 0;

	if (Max) {
		CPXchgobjsen (CPLEXenv, CPLEXModel, CPX_MAX);
	} else {
		CPXchgobjsen (CPLEXenv, CPLEXModel, CPX_MIN);
	}
	
	int* Indeces = new int[NumCols];
	double* Coeffs = new double[NumCols];

	for (int i=0; i < NumCols; i++) {
		Indeces[i] = i;
		Coeffs[i] = 0;
	}
	for (int i=0; i < int(InEquation->Variables.size()); i++) {
		Coeffs[InEquation->Variables[i]->Index] = InEquation->Coefficient[i];
	}
	
	Status = CPXchgobj(CPLEXenv, CPLEXModel, NumCols, Indeces, Coeffs);
	delete [] Indeces;
	delete [] Coeffs;
	if (Status) {
		cout << "Failed to set objective coefficients. " << endl;
		return FAIL;
	}
	if (InEquation->QuadOne.size() > 0) {
		if (CPXgetprobtype(CPLEXenv, CPLEXModel) == CPXPROB_LP) {
			Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_QP);
		} else if (CPXgetprobtype(CPLEXenv, CPLEXModel) == CPXPROB_MILP) {
			Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_MIQP);
		}
		if (Status) {
			FErrorFile() << "Failed to change problem type." << endl;
			FlushErrorFile();
			return FAIL;
		}
		
		for (int i=0; i < NumCols; i++) {
			for (int j=0; j < NumCols; j++) {
				Status = CPXchgqpcoef(CPLEXenv, CPLEXModel, i, j, 0);
				if (Status) {
					FErrorFile() << "Failed to change quadratic coefficient." << endl;
					FlushErrorFile();
					return FAIL;
				}
			}
		}
		for (int i=0; i < int(InEquation->QuadOne.size()); i++) {
			Status = CPXchgqpcoef(CPLEXenv, CPLEXModel, InEquation->QuadOne[i]->Index, InEquation->QuadTwo[i]->Index, InEquation->QuadCoeff[i]);
			if (Status) {
				FErrorFile() << "Failed to change quadratic coefficient." << endl;
				FlushErrorFile();
				return FAIL;
			}
		}
	}	
	
	return SUCCESS;
}

int CPLEXAddConstraint(LinEquation* InEquation) {
	int Status = 0;
	
	if (InEquation->ConstraintType != QUADRATIC && InEquation->ConstraintType != LINEAR) {
		FErrorFile() << "This constraint type is not supported in CPLEX: " << InEquation->ConstraintType << endl;
		FlushErrorFile();
		return FAIL;
	}

	//First I check the number of rows. If it's larger than the index, then this constraint already exists and is only being changed
	int NumberRows = CPXgetnumrows (CPLEXenv, CPLEXModel);
	if (NumberRows <= InEquation->Index) {
		char* Sense = new char[1];
		if (InEquation->EqualityType == EQUAL) {
			if (InEquation->QuadOne.size() > 0) {
				delete [] Sense;
				FErrorFile() << "Quadratic constraints cannot be equivalent constraints in CPLEX." << endl;
				FlushErrorFile();
				return FAIL;
			} else {
				Sense[0] = 'E';
			}
		} else if (InEquation->EqualityType == LESS) {
			Sense[0] = 'L';
		} else if (InEquation->EqualityType == GREATER) {
			Sense[0] = 'G';
		} else {
			delete [] Sense;
			FErrorFile() << "Unrecognized constraint type: " << InEquation->ConstraintType << endl;
			FlushErrorFile();
			return FAIL;
		}

		double* Rhs = new double[1];
		Rhs[0] = InEquation->RightHandSide;
		
		int* ColInd = NULL;
		int* RowInd = NULL;
		double* Coeff = NULL;
		if (InEquation->Variables.size() > 0) {
			ColInd = new int[int(InEquation->Variables.size())];
			RowInd = new int[int(InEquation->Variables.size())];
			Coeff = new double[int(InEquation->Variables.size())];
			for (int i=0; i < int(InEquation->Variables.size()); i++) {
				Coeff[i] = InEquation->Coefficient[i];
				RowInd[i] = 0;
				ColInd[i] = InEquation->Variables[i]->Index;
			}
		}
		
		if (InEquation->QuadOne.size() > 0) {
			if (CPXgetprobtype(CPLEXenv, CPLEXModel) == CPXPROB_LP) {
				Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_QP);
			}
			else if (CPXgetprobtype(CPLEXenv, CPLEXModel) == CPXPROB_MILP) {
				Status = CPXchgprobtype(CPLEXenv, CPLEXModel, CPXPROB_MIQP);
			}
	
			int *QuadCol = new int[int(InEquation->QuadOne.size())];
			int *QuadRow = new int[int(InEquation->QuadTwo.size())];
			double *QuadCoeff = new double[int(InEquation->QuadCoeff.size())];
			for (int i=0; i < int(InEquation->QuadOne.size()); i++) {
				QuadCol[i] = InEquation->QuadOne[i]->Index;
				QuadRow[i] = InEquation->QuadTwo[i]->Index;
				QuadCoeff[i] = InEquation->QuadCoeff[i];
			}

			Status = CPXaddqconstr(CPLEXenv, CPLEXModel, int(InEquation->Variables.size()), int(InEquation->QuadOne.size()), Rhs[0], int(Sense[0]), ColInd, Coeff, QuadRow, QuadCol, QuadCoeff, NULL);

			delete [] QuadCol;
			delete [] QuadRow;
			delete [] QuadCoeff;
		} else if (InEquation->Variables.size() > 0) {	
			string StrName = GetConstraintName(InEquation);
			char** Name = new char*;
			Name[0] = new char[StrName.length()+1];
			strcpy(Name[0],StrName.data());

			if ((InEquation->ConstraintMeaning.compare("chemical potential constraint") == 0) && (InEquation->Loaded == false) && (GetParameter("Check potential constraints feasibility").compare("1") == 0)) {
				Rhs[0] = InEquation->LoadedRightHandSide;
				Sense[0] = 'L';
			} else if ((InEquation->ConstraintMeaning.compare("chemical potential constraint") == 0) && (InEquation->Loaded == false) && (InEquation->RightHandSide > 0.9*FLAG)){
				Rhs[0] = FLAG;
				Sense[0] = 'L';
			}

			Status = CPXaddrows(CPLEXenv, CPLEXModel, 0, 1, int(InEquation->Variables.size()), Rhs, Sense, RowInd, ColInd, Coeff, NULL, Name);
			delete [] Name[0];
			delete [] Name;
			delete [] ColInd;
			delete [] RowInd;
			delete [] Coeff;	
		}
		delete [] Rhs;
		delete [] Sense;

		if (Status) {
			FErrorFile() << "Failed to add constraint: " << InEquation->Index << endl;
			FlushErrorFile();
			return FAIL;
		}
	} else {
		if (InEquation->QuadOne.size() > 0) {
			FErrorFile() << "Cannot change a quadratic constraint." << endl;
			FlushErrorFile();
			return FAIL;
		} else {
			int NumberOfColumns = CPXgetnumcols(CPLEXenv, CPLEXModel);
			//First I reset all of the coefficients to zero
			for (int i=0; i < NumberOfColumns; i++) {
				Status = CPXchgcoef (CPLEXenv, CPLEXModel, InEquation->Index, i, 0);
				if (Status) {
					FErrorFile() << "Failed to change constraint: " << InEquation->Index << endl;
					FlushErrorFile();
					return FAIL;
				}
			}
			//Next I set all of the nonzero coefficients according to the input equation
			for (int i=0; i < int(InEquation->Variables.size()); i++) {
				Status = CPXchgcoef (CPLEXenv, CPLEXModel, InEquation->Index, InEquation->Variables[i]->Index, InEquation->Coefficient[i]);
				if (Status) {
					FErrorFile() << "Failed to change constraint: " << InEquation->Index << endl;
					FlushErrorFile();
					return FAIL;
				}
			}
			
			char* Sense = new char[1];
			
			if (InEquation->ConstraintMeaning.compare("chemical potential constraint") == 0 && InEquation->Loaded == false) {
				Sense[0] = 'L';
				
				Status = CPXchgcoef (CPLEXenv, CPLEXModel, InEquation->Index, -1, InEquation->LoadedRightHandSide);
				Status = CPXchgsense (CPLEXenv, CPLEXModel, 1, &(InEquation->Index), Sense);
				
			} else {
			
				//Now I change the RHS of the constraint
				Status = CPXchgcoef (CPLEXenv, CPLEXModel, InEquation->Index, -1, InEquation->RightHandSide);
	
				//Also change the sense of the constraint if nec
				
				if (InEquation->EqualityType == EQUAL) {
					if (InEquation->QuadOne.size() > 0) {
						delete [] Sense;
						FErrorFile() << "Quadratic constraints cannot be equivalent constraints in CPLEX." << endl;
						FlushErrorFile();
						return FAIL;
					} else {
						Sense[0] = 'E';
					}
				} else if (InEquation->EqualityType == LESS) {
					Sense[0] = 'L';
				} else if (InEquation->EqualityType == GREATER) {
					Sense[0] = 'G';
				} else {
					delete [] Sense;
					FErrorFile() << "Unrecognized constraint type: " << InEquation->ConstraintType << endl;
					FlushErrorFile();
					return FAIL;
				}
	
				Status = CPXchgsense (CPLEXenv, CPLEXModel, 1, &(InEquation->Index), Sense);
				if (Status) {
					FErrorFile() << "Failed to change constraint: " << InEquation->Index << endl;
					FlushErrorFile();
					return FAIL;
				}
			}
		}
	}
	return SUCCESS;
}

int CPLEXDelConstraint(LinEquation* InEquation) {
	int Status = 0;
	int rowIndex = InEquation->Index;
	int* indexPtr;
	string ConstraintName = GetConstraintName(InEquation);

	Status = CPXgetrowindex(CPLEXenv, CPLEXModel, ConstraintName.data(), indexPtr);

	if (Status) {
		FErrorFile() << "Failed to get constraint index for deletion." << endl;
		FlushErrorFile();
		return FAIL;
	}

	Status = CPXdelrows(CPLEXenv, CPLEXModel, rowIndex, rowIndex);

	if (Status) {
		FErrorFile() << "Failed to delete constraint " << ConstraintName << endl;
		FlushErrorFile();
		return FAIL;
	} else {
		return SUCCESS;
	}
	
}