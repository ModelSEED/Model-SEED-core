#include "MFAToolkit.h"
#include "lindo.h"

pLSenv Lindoenv;
pLSmodel LindoModel;
int NumberLindoVariables;
int NumberLindoConstraints;

int InitializeLINDOVariables() {
	Lindoenv = NULL;
	LindoModel = NULL;
	NumberLindoVariables = 0;
	NumberLindoConstraints = 0;
	return SUCCESS;
}

int LINDOInitialize() {
	int Status = 0;
	
	NumberLindoVariables = 0;
	NumberLindoConstraints = 0;

	//First I open the CPLEX environment if it is not already open
	if (Lindoenv == NULL) {
		char LicenseKey[1024];
		Status = LSloadLicenseString(ConvertStringToCString(GetParameter("Lindo license")),LicenseKey);
		if (Status) {
			FErrorFile() << "Failed to read lindo license file" << endl;
			FlushErrorFile();
			return FAIL;
		} 
		Lindoenv = LScreateEnv(&Status,LicenseKey);
	}
	if (Lindoenv == NULL || Status) {
		FErrorFile() << "Failed to initialize Lindo environment. Check Lindo license." << endl;
		FlushErrorFile();
		return FAIL;
	} 

	//Now I set any environment variables
	Status = LSsetEnvDouParameter(Lindoenv,LS_DPARAM_SOLVER_FEASTOL,1e-9);
	if (Status) {
		FErrorFile() << "Failed to set parameter in Lindo environment." << endl;
		FlushErrorFile();
		return FAIL;
	} 
	Status = LSsetEnvDouParameter(Lindoenv,LS_DPARAM_SOLVER_OPTTOL,1e-9);
	if (Status) {
		FErrorFile() << "Failed to set parameter in Lindo environment." << endl;
		FlushErrorFile();
		return FAIL;
	}
	Status = LSsetEnvDouParameter(Lindoenv,LS_DPARAM_MIP_INTTOL,1e-9);
	if (Status) {
		FErrorFile() << "Failed to set parameter in Lindo environment." << endl;
		FlushErrorFile();
		return FAIL;
	}

	//Next I clear out any models that currently exist
	if (LINDOClearSolver() != SUCCESS) {
		return FAIL; //error message already printed	
	}

	//Now I create a new Lindo model
	LindoModel = LScreateModel(Lindoenv, &Status);
	if (Status || LindoModel == NULL) {
		FErrorFile() << "Failed to create new Lindo model." << endl;
		FlushErrorFile();
		return FAIL;
	}

	return SUCCESS;
}

int LINDOCleanup() {
	int Status = 0;

	if (LINDOClearSolver() != SUCCESS) {
		return FAIL; //error message already printed	
	}

	if (Lindoenv != NULL) {
		Status = LSdeleteEnv(&Lindoenv);
		if (Status || Lindoenv != NULL) {
			FErrorFile() << "Failed to delete lindo environment." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	return SUCCESS;
}

int LINDOClearSolver() {
	NumberLindoVariables = 0;
	NumberLindoConstraints = 0;
	
	if (LindoModel != NULL) {
		int Status = LSdeleteModel(&LindoModel);
		if (Status || LindoModel != NULL) {
			FErrorFile() << "Failed to delete lindo model." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	return SUCCESS;
}

int LINDOPrintFromSolver() {
	if (LindoModel == NULL) {
		FErrorFile() << "Failed to write lindo model to file because model does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	char* Temp = ConvertStringToCString(GetParameter("LP filename"));
	int Status = LSwriteMPSFile(LindoModel, Temp, LS_FORMATTED_MPS);
	delete [] Temp;
	if (Status) {
		FErrorFile() << "Failed to write lindo model to file." << endl;
		FlushErrorFile();
		return FAIL;
	}
	return SUCCESS;
}

OptSolutionData* LINDORunSolver(int ProbType) {
	int Status = 0;
	OptSolutionData* NewSolution = NULL;
	
	if (LindoModel == NULL) {
		FErrorFile() << "Cannot optimize because model does not exist." << endl;
		FlushErrorFile();
		return NULL;
	}

	int TempStatus = 0;
	if (ProbType == MILP || ProbType == MIQP || ProbType == MINP) {
		Status = LSsolveMIP(LindoModel,&TempStatus);
	} else if (ProbType == LP || ProbType ==  QP) {
		Status = LSoptimize(LindoModel,LS_METHOD_FREE,&TempStatus);
	} else if (ProbType == NP) {
		Status = LSsolveGOP(LindoModel,&TempStatus);
	} else {
		FErrorFile() << "Unrecognized problem type." << endl;
		FlushErrorFile();
		return NULL;
	}
	if (Status) {
		FErrorFile() << "Failed to optimize model using Lindo." << endl;
		FlushErrorFile();
		return NULL;
	}

	NewSolution = new OptSolutionData;
	if (TempStatus == LS_STATUS_UNBOUNDED) {
		cout << "Model is unbounded" << endl;
		FErrorFile() << "Model is unbounded" << endl;
		FlushErrorFile();
		NewSolution->Status = UNBOUNDED;
		return NewSolution;
	} else if (TempStatus == LS_STATUS_INFEASIBLE) {
		cout << "Model is infeasible" << endl;
		FErrorFile() << "Model is infeasible" << endl;
		FlushErrorFile();
		NewSolution->Status = INFEASIBLE;
		return NewSolution;
	} else if (TempStatus == LS_STATUS_INFORUNB ) {
		cout << "Model is infeasible or unbounded" << endl;
		FErrorFile() << "Model is infeasible or unbounded" << endl;
		FlushErrorFile();
		NewSolution->Status = INFEASIBLE;
		return NewSolution;
	} else {
		NewSolution->Status = SUCCESS;
	}

	double* VariableValues = new double[NumberLindoVariables];
	if (ProbType == MILP || ProbType == MIQP || ProbType == MINP) {
		double* Objective = new double[1];
		Status = LSgetInfo(LindoModel,LS_DINFO_MIP_OBJ,Objective);
		if (Status) {
			FErrorFile() << "Failed to obtain objective data from Lindo." << endl;
			FlushErrorFile();
			return NULL;
		}
		NewSolution->Objective = Objective[0];
		delete [] Objective;
		cout << "Objective = " << NewSolution->Objective << endl;
		Status = LSgetMIPPrimalSolution(LindoModel, VariableValues);
	} else if (ProbType == LP || ProbType ==  QP || ProbType == NP) {
		double* Objective = new double[1];
		Status = LSgetInfo(LindoModel,LS_DINFO_POBJ,Objective);
		if (Status) {
			FErrorFile() << "Failed to obtain objective data from Lindo." << endl;
			FlushErrorFile();
			return NULL;
		}
		NewSolution->Objective = Objective[0];
		delete [] Objective;
		cout << "Objective = " << NewSolution->Objective << endl;
		Status = LSgetPrimalSolution(LindoModel, VariableValues);
	} else {
		FErrorFile() << "Unrecognized problem type." << endl;
		FlushErrorFile();
		return NULL;
	}
	if (Status) {
		FErrorFile() << "Failed to obtain solution data from Lindo." << endl;
		FlushErrorFile();
		return NULL;
	}

	NewSolution->NumVariables = NumberLindoVariables;
	NewSolution->SolutionData.resize(NumberLindoVariables);
	for (int i=0; i < NumberLindoVariables; i++) {
		NewSolution->SolutionData[i] = VariableValues[i];
	}
	delete [] VariableValues;
	
	return NewSolution;
}

int LINDOLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	int Status = 0;
	
	double* UpperBound = new double[1];
	UpperBound[0] = InVariable->UpperBound;
	double* LowerBound = new double[1];
	LowerBound[0] = InVariable->LowerBound;
	if (UseTightBounds) {
		UpperBound[0] = InVariable->Max;
		LowerBound[0] = InVariable->Min;
	}

	char* Type = new char[1];
	if (InVariable->Binary) {
		Type[0] = 'B';
	} else {
		Type[0] = 'C';
	}

	if (InVariable->Index >= NumberLindoVariables) {
		double* ObjCoef = new double[1];
		ObjCoef[0] = 0;
		int* Columns = new int[2];
		Columns[0] = 0;
		Columns[1] = 0;

		Status = LSaddVariables(LindoModel, 1, Type, NULL, NULL,Columns,  NULL,  NULL, ObjCoef,LowerBound, UpperBound);
		if (Status) {
			FErrorFile() << "Failed to add variable to Lindo model." << endl;
			FlushErrorFile();
			return FAIL;
		}

		NumberLindoVariables++;
		delete [] ObjCoef;
		delete [] Columns;
	} else {
		//I am not adding a new variable but modifying an existing one
		//Modfying variable bounds
		int* VariableIndex = new int[1];
		VariableIndex[0] = InVariable->Index;
		Status = LSmodifyLowerBounds(LindoModel, 1, VariableIndex, LowerBound);	
		if (Status) {
			FErrorFile() << "Failed to modify variable lower bound." << endl;
			FlushErrorFile();
			return FAIL;
		}
		Status = LSmodifyUpperBounds(LindoModel, 1, VariableIndex, UpperBound);	
		if (Status) {
			FErrorFile() << "Failed to modify variable upper bound." << endl;
			FlushErrorFile();
			return FAIL;
		}

		//Modfying variable type
		Status = LSmodifyVariableType(LindoModel, 1, VariableIndex, Type);
		if (Status) {
			FErrorFile() << "Failed to modify variable type." << endl;
			FlushErrorFile();
			return FAIL;
		}
		delete [] VariableIndex;
	}

	delete [] LowerBound;
	delete [] UpperBound;
	delete [] Type;

	return SUCCESS;
}

int LINDOLoadObjective(LinEquation* InEquation, bool Max) {
	if (InEquation->QuadCoeff.size() > 0) {
		FErrorFile() << "Support for quadratic objectives in LINDO has not yet been added." << endl;
		FlushErrorFile();
		return FAIL;
	}

	int Status = 0;

	if (LindoModel == NULL) {
		FErrorFile() << "Failed to add objective because Lindo model does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (Max) {
		Status = LSsetModelIntParameter(LindoModel,LS_IPARAM_OBJSENSE,LS_MAX);
	} else {
		Status = LSsetModelIntParameter(LindoModel,LS_IPARAM_OBJSENSE,LS_MIN);
	}
	if (Status) {
		FErrorFile() << "Failed to set parameter in Lindo model." << endl;
		FlushErrorFile();
		return FAIL;
	}

	//Resetting all objective coefficients to zero
	double* Coeff = new double[NumberLindoVariables];
	int* Indecies = new int[NumberLindoVariables];
	for (int i=0; i < NumberLindoVariables; i++) {
		Coeff[i] = 0;
		Indecies[i] = i;
	}
	Status = LSmodifyObjective(LindoModel, NumberLindoVariables, Indecies, Coeff);
	if (Status) {
		FErrorFile() << "Failed to set objective coefficients in Lindo model." << endl;
		FlushErrorFile();
		return FAIL;
	}
	delete [] Coeff;
	delete [] Indecies;

	//Setting new non-zero objective coefficients
	Coeff = new double[InEquation->Variables.size()];
	Indecies = new int[InEquation->Variables.size()];
	for (int i=0; i < int(InEquation->Variables.size()); i++) {
		Coeff[i] = InEquation->Coefficient[i];
		if (Indecies[i] = InEquation->Variables[i]->Index < NumberLindoVariables) {
			Indecies[i] = InEquation->Variables[i]->Index;
		} else {
			FErrorFile() << "Objective index out of the range of variables indecies for model." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}
	Status = LSmodifyObjective(LindoModel, int(InEquation->Variables.size()), Indecies, Coeff);
	if (Status) {
		FErrorFile() << "Failed to set objective coefficients in Lindo model." << endl;
		FlushErrorFile();
		return FAIL;
	}
	delete [] Coeff;
	delete [] Indecies;

	return SUCCESS;
}

int LINDOAddConstraint(LinEquation* InEquation) {
	if (InEquation->QuadCoeff.size() > 0) {
		FErrorFile() << "Support for quadratic constraints in LINDO has not yet been added." << endl;
		FlushErrorFile();
		return FAIL;
	}
	
	int Status = 0;
	
	char* Type = new char[1];
	if (InEquation->EqualityType == EQUAL) {
		Type[0] = 'E';
	} else if (InEquation->EqualityType == GREATER) {
		Type[0] = 'G';
	} else if (InEquation->EqualityType == LESS) {
		Type[0] = 'L';
	} else {
		FErrorFile() << "Unrecognized equality type." << endl;
		FlushErrorFile();
		return FAIL;
	}

	double* RHS = new double[1];
	RHS[0] = InEquation->RightHandSide;
	
	if (InEquation->Index >= NumberLindoConstraints) {
		if (InEquation->Variables.size() > 0) {
			double* Coeff = new double[InEquation->Variables.size()];
			int* Columns = new int[InEquation->Variables.size()];
			int* Rows = new int[2];
			Rows[0] = 0;
			Rows[1] = int(InEquation->Variables.size());
			for (int i=0; i < int(InEquation->Variables.size()); i++) {
				if (InEquation->Variables[i]->Index < NumberLindoVariables) {
					Coeff[i] = InEquation->Coefficient[i];
					Columns[i] = InEquation->Variables[i]->Index;
				} else {
					FErrorFile() << "Index in constraint is out of the range of variables in Lindo problem." << endl;
					FlushErrorFile();
					return FAIL;
				}
			}

			Status = LSaddConstraints(LindoModel, 1, Type, NULL, Rows, Coeff, Columns, RHS);
			//Status = LSaddConstraints(LindoModel, 1, Type, Names, Rows, Coeff, Columns, RHS);
			NumberLindoConstraints++;

			delete [] Coeff;
			delete [] Columns;
			delete [] Rows;
		}
	} else {
		//We are not adding a new constraint but modifying an existing one
		//First I modify the constraint coefficients
		for(int i=0; i < NumberLindoVariables; i++) {
			Status = LSmodifyAij(LindoModel,InEquation->Index,i,0);
			if (Status) {
				FErrorFile() << "Failed to modify constraint coefficient." << endl;
				FlushErrorFile();
				return FAIL;
			}
		}
		for(int i=0; i < int(InEquation->Variables.size()); i++) {
			Status = LSmodifyAij(LindoModel,InEquation->Index,InEquation->Variables[i]->Index,InEquation->Coefficient[i]);
			if (Status) {
				FErrorFile() << "Failed to modify constraint coefficient." << endl;
				FlushErrorFile();
				return FAIL;
			}
		}

		//Now I modify the constraint type and the RHS
		int* ConstraintIndex = new int[1];
		ConstraintIndex[0] = InEquation->Index;
		Status = LSmodifyConstraintType(LindoModel, 1, ConstraintIndex, Type);
		if (Status) {
			FErrorFile() << "Failed to modify constraint type." << endl;
			FlushErrorFile();
			return FAIL;
		}
		Status = LSmodifyRHS(LindoModel, 1, ConstraintIndex,RHS);
		if (Status) {
			FErrorFile() << "Failed to modify constraint RHS." << endl;
			FlushErrorFile();
			return FAIL;
		}

		delete [] ConstraintIndex;
	}

	delete [] Type;
	delete [] RHS;

	return SUCCESS;
}