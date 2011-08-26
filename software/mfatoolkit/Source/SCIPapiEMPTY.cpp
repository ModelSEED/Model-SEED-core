#include "MFAToolkit.h"

int InitializeSCIPVariables() {
	return FAIL;
}

int SCIPInitialize() {
	return FAIL;
}

int SCIPCleanup() {
	return FAIL;
}

int SCIPClearSolver() {
	return FAIL;
}

int SCIPPrintFromSolver() {
	return FAIL;
}

OptSolutionData* SCIPRunSolver(int ProbType) {
	return NULL;
}

int SCIPLoadVariables(MFAVariable* InVariable, bool RelaxIntegerVariables,bool UseTightBounds) {
	return FAIL;
}

int SCIPLoadObjective(LinEquation* InEquation, bool Max) {
	return FAIL;
}

int SCIPAddConstraint(LinEquation* InEquation) {
	return FAIL;
}