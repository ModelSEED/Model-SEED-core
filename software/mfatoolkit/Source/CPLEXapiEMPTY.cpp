#include "MFAToolkit.h"

int InitializeCPLEXVariables() {
	return FAIL;
}

int CPLEXInitialize() {
	return FAIL;
}

int CPLEXCleanup() {
	return FAIL;
}

int CPLEXClearSolver() {
	return FAIL;
}

int CPLEXPrintFromSolver() {
	return FAIL;
}

OptSolutionData* CPLEXRunSolver(int ProbType) {
	return NULL;
}

int CPLEXLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	return FAIL;
}

int CPLEXLoadObjective(LinEquation* InEquation, bool Max) {
	return FAIL;
}

int CPLEXAddConstraint(LinEquation* InEquation) {
	return FAIL;
}

int CPLEXDelConstraint(LinEquation* InEquation) {
	return FAIL;
}