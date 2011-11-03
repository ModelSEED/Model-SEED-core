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

extern "C" {
#include "glpk.h"
}

LPX* GLPKModel;

int InitializeGLPKVariables() {
	GLPKModel = NULL;
	return SUCCESS;
}

int GLPKInitialize() {
	if (GLPKModel != NULL) {
		if (GLPKClearSolver() == FAIL) {
			return FAIL;	
		}
	}

	GLPKModel = lpx_create_prob();
	//lpx_set_int_parm(GLPKModel, LPX_K_BFTYPE,3);
	lpx_set_class(GLPKModel, LPX_LP);
	
	return SUCCESS;
}

int GLPKCleanup() {
	return GLPKClearSolver();
}

int GLPKClearSolver() {
	if (GLPKModel != NULL) {
		lpx_delete_prob(GLPKModel);
		GLPKModel = NULL;
	}

	return SUCCESS;
}

int GLPKPrintFromSolver() {
	if (GLPKModel == NULL) {
		FErrorFile() << "Cannot print problem because problem does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	string Filename = CheckFilename(FOutputFilepath()+GetParameter("LP filename"));
	int Status = lpx_write_cpxlp(GLPKModel,ConvertStringToCString(Filename));

	if (Status) {
		FErrorFile() << "Unable to write problem to file due to error in writing function." << endl;
		FlushErrorFile();
		return FAIL;
	}

	return SUCCESS;
}

OptSolutionData* GLPKRunSolver(int ProbType) {
	OptSolutionData* NewSolution = NULL;

	int NumVariables = lpx_get_num_cols(GLPKModel);

	int Status = 0;
	if (ProbType == MILP) {
		Status = lpx_simplex(GLPKModel);
		if (Status != LPX_E_OK) {
			FErrorFile() << "Failed to optimize problem." << endl;
			FlushErrorFile();
			return NULL;
		}
		Status = lpx_integer(GLPKModel);
		if (Status != LPX_E_OK) {
			FErrorFile() << "Failed to optimize problem." << endl;
			FlushErrorFile();
			return NULL;
		}
		NewSolution = new OptSolutionData;

		Status = lpx_mip_status(GLPKModel);
		if (Status == LPX_I_UNDEF || Status == LPX_I_NOFEAS) {
			NewSolution->Status = INFEASIBLE;
			return NewSolution;
		} else if (Status == LPX_I_FEAS) {
			NewSolution->Status = UNBOUNDED;
			return NewSolution;
		} else if (Status == LPX_I_OPT) {
			NewSolution->Status = SUCCESS;
		} else {
			delete NewSolution;
			FErrorFile() << "Problem status unrecognized." << endl;
			FlushErrorFile();
			return NULL;
		}

		NewSolution->Objective = lpx_mip_obj_val(GLPKModel);
	
		NewSolution->SolutionData.resize(NumVariables);
		for (int i=0; i < NumVariables; i++) {
			NewSolution->SolutionData[i] = lpx_mip_col_val(GLPKModel, i+1);
		}
	} else if (ProbType == LP) {
		//First we check the basis matrix to ensure it is not sigular
		if (lpx_warm_up(GLPKModel) != LPX_E_OK) {
			lpx_adv_basis(GLPKModel);
		}
		Status = lpx_simplex(GLPKModel);
		if (Status == LPX_E_FAULT) {
			Status = lpx_warm_up(GLPKModel);
			if (Status == LPX_E_BADB) {  /* the basis is invalid; build some valid basis */
				lpx_adv_basis(GLPKModel);
				Status = lpx_simplex(GLPKModel);
			}
		}
		if (Status != LPX_E_OK) {
			FErrorFile() << "Failed to optimize problem." << endl;
			FlushErrorFile();
			return NULL;
		}
		NewSolution = new OptSolutionData;

		Status = lpx_get_status(GLPKModel);
		if (Status == LPX_INFEAS || Status == LPX_NOFEAS || Status == LPX_UNDEF) {
			cout << "Model is infeasible" << endl;
			FErrorFile() << "Model is infeasible" << endl;
			FlushErrorFile();
			NewSolution->Status = INFEASIBLE;
			return NewSolution;
		} else if (Status == LPX_FEAS || Status == LPX_UNBND) {
			cout << "Model is unbounded" << endl;
			FErrorFile() << "Model is unbounded" << endl;
			FlushErrorFile();
			NewSolution->Status = UNBOUNDED;
			return NewSolution;
		} else if (Status == LPX_OPT) {
			NewSolution->Status = SUCCESS;
		} else {
			delete NewSolution;
			FErrorFile() << "Problem status unrecognized." << endl;
			FlushErrorFile();
			return NULL;
		}

		NewSolution->Objective = lpx_get_obj_val(GLPKModel);
	
		NewSolution->SolutionData.resize(NumVariables);
		for (int i=0; i < NumVariables; i++) {
			NewSolution->SolutionData[i] = lpx_get_col_prim(GLPKModel, i+1);
		}
	} else {
		FErrorFile() << "Optimization problem type cannot be handled by GLPK solver." << endl;
		FlushErrorFile();
		return NULL;
	}

	return NewSolution;
}

int GLPKLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	if (GLPKModel == NULL) {
		FErrorFile() << "Could not add variable because GLPK object does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	int NumColumns = lpx_get_num_cols(GLPKModel);

	if (InVariable->Index >= NumColumns) {
		lpx_add_cols(GLPKModel, 1);
		string Name = GetMFAVariableName(InVariable);
		char* Temp = new char[Name.length()+1];
		strcpy(Temp,Name.data());
		lpx_set_col_name(GLPKModel,InVariable->Index+1,Temp);
	}


	double LowerBound = InVariable->LowerBound;
	double UpperBound = InVariable->UpperBound;
	if (UseTightBounds) {
		LowerBound = InVariable->Min;
		UpperBound = InVariable->Max;
	}
	if (LowerBound != UpperBound) {
		lpx_set_col_bnds(GLPKModel, InVariable->Index+1, LPX_DB, InVariable->LowerBound, InVariable->UpperBound);
	} else {
		lpx_set_col_bnds(GLPKModel, InVariable->Index+1, LPX_FX, InVariable->LowerBound, InVariable->UpperBound);
	}

	if (InVariable->Binary && !RelaxIntegerVariables) {
		lpx_set_class(GLPKModel, LPX_MIP);
		lpx_set_col_kind(GLPKModel, InVariable->Index+1,LPX_IV);
	}

	return SUCCESS;
}

int GLPKLoadObjective(LinEquation* InEquation, bool Max) {
	if (InEquation->QuadCoeff.size() > 0) {
		FErrorFile() << "GLPK solver cannot accept quadratic objectives." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (GLPKModel == NULL) {
		FErrorFile() << "Could not add objective because GLPK object does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (!Max) {
		lpx_set_obj_dir(GLPKModel, LPX_MIN);
	} else {
		lpx_set_obj_dir(GLPKModel, LPX_MAX);
	}
	
	int NumColumns = lpx_get_num_cols(GLPKModel);

	for (int i=0; i < NumColumns; i++) {
		lpx_set_obj_coef(GLPKModel, i+1, 0);
	}
	for (int i=0; i < int(InEquation->Variables.size()); i++) {
		if (NumColumns > InEquation->Variables[i]->Index) {
			lpx_set_obj_coef(GLPKModel, InEquation->Variables[i]->Index+1, InEquation->Coefficient[i]);
		} else {
			FErrorFile() << "Variable index specified in objective was out of the range of variables added to the GLPK problem object." << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	return SUCCESS;
}

int GLPKAddConstraint(LinEquation* InEquation) {
	if (InEquation->QuadCoeff.size() > 0) {
		FErrorFile() << "GLPK solver cannot accept quadratic constraints." << endl;
		FlushErrorFile();
		return FAIL;
	}

	if (GLPKModel == NULL) {
		FErrorFile() << "Could not add constraint because GLPK object does not exist." << endl;
		FlushErrorFile();
		return FAIL;
	}

	int NumRows = lpx_get_num_rows(GLPKModel);

	if (InEquation->Index >= NumRows) {
		lpx_add_rows(GLPKModel, 1);
	}

	if (InEquation->EqualityType == EQUAL) {
		lpx_set_row_bnds(GLPKModel, InEquation->Index+1, LPX_FX, InEquation->RightHandSide, InEquation->RightHandSide);
	} else if (InEquation->EqualityType == GREATER) {
		lpx_set_row_bnds(GLPKModel, InEquation->Index+1, LPX_LO, InEquation->RightHandSide, InEquation->RightHandSide);
	} else if (InEquation->EqualityType == LESS) {
		lpx_set_row_bnds(GLPKModel, InEquation->Index+1, LPX_UP, InEquation->RightHandSide, InEquation->RightHandSide);
	} else {
		FErrorFile() << "Could not add constraint because the constraint type was not recognized." << endl;
		FlushErrorFile();
		return FAIL;
	}

	int NumColumns = lpx_get_num_cols(GLPKModel);

	int* Indecies = new int[int(InEquation->Variables.size())+1];
	double* Coeff = new double[int(InEquation->Variables.size())+1];
	for (int i=0; i < int(InEquation->Variables.size()); i++) {
		if (InEquation->Variables[i]->Index < NumColumns) {
			Coeff[i+1] = InEquation->Coefficient[i];
			Indecies[i+1] = InEquation->Variables[i]->Index+1;
		} else {
			FErrorFile() << "Variable index found in constraint is out of the range found in GLPK problem" << endl;
			FlushErrorFile();
			return FAIL;
		}
	}

	lpx_set_mat_row(GLPKModel, InEquation->Index+1, int(InEquation->Variables.size()), Indecies, Coeff);

	delete [] Indecies;
	delete [] Coeff;

	return SUCCESS;
}