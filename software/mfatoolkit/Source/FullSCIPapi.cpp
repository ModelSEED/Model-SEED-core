#include "objscip/objscip.h"
#include "objscip/objscipdefplugins.h"
#include "MFAToolkit.h"

SCIP* scippointer;
vector<SCIP_VAR*> SCIPVars;
vector<SCIP_CONS*> SCIPCons;
bool ScipSenseMax = false;

int InitializeSCIPVariables() {
	scippointer = NULL;

	return SUCCESS;
}

int SCIPInitialize() {
	if (scippointer == NULL) {
		SCIP_CALL( SCIPcreate(&scippointer) );
		SCIP_CALL( SCIPincludeDefaultPlugins(scippointer) );
	} else {
		SCIPClearSolver();
	}

	// initialize SCIP 
	SCIP_CALL( SCIPcreateProb(scippointer, "ProblemOne", 0, 0, 0, 0, 0, 0) );

	return SUCCESS;
}


int SCIPCleanup() {
	if (scippointer != NULL) {
		SCIP_CALL( SCIPfreeProb(scippointer) );
		SCIP_CALL( SCIPfree(&scippointer) );
		scippointer = NULL;
		//I may need to delete the variables as well, but I'm not sure
		SCIPVars.clear();
		SCIPCons.clear();
	}

	return SUCCESS;
}

int SCIPClearSolver() {
	if (scippointer != NULL) {
		SCIP_CALL( SCIPfreeProb(scippointer) );
		//I may need to delete the variables as well, but I'm not sure
		SCIPVars.clear();
		SCIPCons.clear();
	}

	return SUCCESS;
}

int SCIPPrintFromSolver() {
	int Status = 0;
	if (scippointer == NULL) {
		FErrorFile() << "Cannot print problem to file because SCIP environment is not open." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (SCIPVars.size() == 0) {
		FErrorFile() << "Cannot print problem to file because no SCIP model exists." << endl;
		FlushErrorFile();
		return FAIL;
	}
	
	cout << GetParameter("LP filename").data() << endl;
	SCIP_CALL(SCIPprintOrigProblem(scippointer, 0));
	//SCIP_CALL( SCIPwriteLP(scippointer,GetParameter("LP filename").data()));

	return SUCCESS;
}

OptSolutionData* SCIPRunSolver(int ProbType) {
	SCIPsolve(scippointer);
	
	SCIP_SOL* NewScipSolution = SCIPgetBestSol(scippointer);
	if (NewScipSolution == NULL) {
		return NULL;
	}

	OptSolutionData* NewSolution = new OptSolutionData;;
	NewSolution->Status = SUCCESS;
	SCIP_VAR** vars = new SCIP_VAR*[SCIPVars.size()];
	SCIP_Real* vals = new SCIP_Real[SCIPVars.size()];
	for (int i=0; i < int(SCIPVars.size()); i++) {
		vars[i] = SCIPVars[i];
	}

	SCIPgetVarSols(scippointer,int(SCIPVars.size()),vars,vals);

	NewSolution->NumVariables = int(SCIPVars.size());
	NewSolution->SolutionData.resize(int(SCIPVars.size()));
	for (int i=0; i < int(SCIPVars.size()); i++) {
		NewSolution->SolutionData[i] = vals[i];
	}
	delete [] vars;
	delete [] vals;

	NewSolution->Objective = SCIPgetLPObjval(scippointer);

	if (ScipSenseMax) {
		NewSolution->Objective = -NewSolution->Objective;
	}

	cout << "Objective value: " << NewSolution->Objective << endl;

	return NewSolution;
}

int SCIPLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	int Status = 0;
	
	double UpperBound = InVariable->UpperBound;
	double LowerBound = InVariable->LowerBound;
	if (UseTightBounds) {
		UpperBound = InVariable->Max;
		LowerBound = InVariable->Max;
	}

	//First I check the number of columns. If it's larger than the index, then this variable already exists and is only being changed
	int NumberColumns = int(SCIPVars.size());
	if (NumberColumns <= InVariable->Index) {
		string StrName("x");
		StrName.append(itoa(InVariable->Index+1));

		SCIP_VAR* NewVariable;
		
		if (InVariable->Binary && !RelaxIntegerVariables) { 
			SCIP_CALL( SCIPcreateVar(scippointer,&NewVariable,StrName.data(),LowerBound,UpperBound,0.0,SCIP_VARTYPE_BINARY,true,false,NULL,NULL,NULL,NULL));
		} else if (InVariable->Integer && !RelaxIntegerVariables) {
			SCIP_CALL( SCIPcreateVar(scippointer,&NewVariable,StrName.data(),LowerBound,UpperBound,0.0,SCIP_VARTYPE_INTEGER ,true,false,NULL,NULL,NULL,NULL));
		} else {
			SCIP_CALL( SCIPcreateVar(scippointer,&NewVariable,StrName.data(),LowerBound,UpperBound,0.0,SCIP_VARTYPE_CONTINUOUS,true,false,NULL,NULL,NULL,NULL));
		}
		
		SCIP_CALL( SCIPcaptureVar(scippointer, NewVariable) );
		SCIP_CALL( SCIPaddVar(scippointer, NewVariable) );
		
		SCIPVars.push_back(NewVariable);
	} else {
		SCIP_CALL( SCIPchgVarLb(scippointer, SCIPVars[InVariable->Index], LowerBound) );
		SCIP_CALL( SCIPchgVarUb(scippointer, SCIPVars[InVariable->Index], UpperBound) );
		
		if (InVariable->Binary && !RelaxIntegerVariables) { 
			SCIP_CALL( SCIPchgVarType(scippointer, SCIPVars[InVariable->Index], SCIP_VARTYPE_BINARY));
		} else if (InVariable->Integer && !RelaxIntegerVariables) {
			SCIP_CALL( SCIPchgVarType(scippointer, SCIPVars[InVariable->Index], SCIP_VARTYPE_INTEGER));
		} else {
			SCIP_CALL( SCIPchgVarType(scippointer, SCIPVars[InVariable->Index], SCIP_VARTYPE_CONTINUOUS));
		}
	}

	return SUCCESS;
}

int SCIPLoadObjective(LinEquation* InEquation, bool Max) {
	int NumCols = int(SCIPVars.size());

	if (Max) {
		SCIP_CALL( SCIPsetObjsense(scippointer, SCIP_OBJSENSE_MAXIMIZE) );
		ScipSenseMax = true;
	} else {
		SCIP_CALL( SCIPsetObjsense(scippointer, SCIP_OBJSENSE_MINIMIZE) );
		ScipSenseMax = false;
	}
	
	for (int i=0; i < int(SCIPVars.size()); i++) {
		SCIP_CALL( SCIPchgVarObj(scippointer, SCIPVars[i],0));
	}
	
	for (int i=0; i < int(InEquation->Variables.size()); i++) {
		if (InEquation->Variables[i]->Index >= int(SCIPVars.size())) {
			FErrorFile() << "Objective variable index out of the range of variable indecies currently loaded into the solver." << endl;
			FlushErrorFile();
			return FAIL;
		}
		SCIP_CALL( SCIPchgVarObj(scippointer, SCIPVars[InEquation->Variables[i]->Index], InEquation->Coefficient[i]));
	}
	
	return SUCCESS;
}

int SCIPAddConstraint(LinEquation* InEquation) {
	int Status = 0;
	
	if (InEquation->ConstraintType != LINEAR) {
		FErrorFile() << "This constraint type is not supported in SCIP: " << InEquation->ConstraintType << endl;
		FlushErrorFile();
		return FAIL;
	}

	//First I check the number of rows. If it's larger than the index, then this constraint already exists and is only being changed
	int NumberRows = int(SCIPCons.size());
	if (NumberRows <= InEquation->Index) {
		SCIP_Real lhs;
		SCIP_Real rhs;
		
		if (InEquation->EqualityType == EQUAL) {
			lhs = InEquation->RightHandSide;
			rhs = InEquation->RightHandSide;
		} else if (InEquation->EqualityType == LESS) {
			lhs = -SCIPinfinity(scippointer);
			rhs = InEquation->RightHandSide;
		} else if (InEquation->EqualityType == GREATER) {
			lhs = InEquation->RightHandSide;
			rhs = SCIPinfinity(scippointer);
		} else {
			FErrorFile() << "Unrecognized constraint type: " << InEquation->ConstraintType << endl;
			FlushErrorFile();
			return FAIL;
		}
		
		SCIP_VAR** vars = new SCIP_VAR*[InEquation->Variables.size()];
		SCIP_Real* coefs = new SCIP_Real[InEquation->Variables.size()];
		for (int i=0; i < int(InEquation->Variables.size()); i++) {
			if (InEquation->Variables[i]->Index >= int(SCIPVars.size())) {
				delete [] vars;
				delete [] coefs;
				FErrorFile() << "Constraint variable index out of the range of variable indecies currently loaded into the solver." << endl;
				FlushErrorFile();
				return FAIL;
			}
			coefs[i] = InEquation->Coefficient[i];
			vars[i] = SCIPVars[InEquation->Variables[i]->Index];
		}
		
		SCIP_CONS* NewConstraint;
		SCIP_CALL( SCIPcreateConsLinear(scippointer, &NewConstraint, itoa(InEquation->Index), int(InEquation->Variables.size()), vars, coefs, lhs, rhs,TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE));
		SCIP_CALL( SCIPaddCons(scippointer, NewConstraint) );
		SCIPCons.push_back(NewConstraint);
		
		delete [] vars;
		delete [] coefs;
	} else {
		//TODO
	}

	return SUCCESS;
}