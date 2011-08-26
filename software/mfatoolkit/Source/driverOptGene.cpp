#include "MFAToolkit.h"
 
using namespace std;

int main ( int argc, char **argv) {
	SetProgramPath(argv[0]);
	SetParameter("output index","0");
	
	if (argc == 1) {
		SetInputParametersFile(STATIC_INPUT_FILE);
		if (LoadParameters() == FAIL) {
			return 1;
		}
		ClearParameterDependance("CLEAR ALL PARAMETER DEPENDANCE");
		if (Initialize() == FAIL) {
			return 1;
		}
		LoadFIGMODELParameters();
		ClearParameterDependance("CLEAR ALL PARAMETER DEPENDANCE");
		DriverOptions();
	} else {
		vector<string> Arguments;
		for (int i=0; i < argc; i++) {
			string Buff(argv[i]);
			Arguments.push_back(Buff);
		}
		CommandlineInterface(Arguments);
	}
	
	Cleanup();
	return 0;
};

void DriverOptions() {
	LoadDatabaseFile("");
};