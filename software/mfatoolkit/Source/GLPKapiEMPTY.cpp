#include "MFAToolkit.h"

int InitializeGLPKVariables() {
	return FAIL;
}

int GLPKInitialize() {
	return FAIL;
}

int GLPKCleanup() {
	return FAIL;
}

int GLPKClearSolver() {
	return FAIL;
}

int GLPKPrintFromSolver() {
	return FAIL;
}

OptSolutionData* GLPKRunSolver(int ProbType) {
	return NULL;
}

int GLPKLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	return FAIL;
}

int GLPKLoadObjective(LinEquation* InEquation, bool Max) {
	return FAIL;
}

int GLPKAddConstraint(LinEquation* InEquation) {
	return FAIL;
}
