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

//#include "vld.h"
#include "MFAToolkit.h"
 
using namespace std;

int main ( int argc, char **argv) {
	SetProgramPath(argv[0]);
	SetParameter("output index","0");
	SetParameter("Error filename","stderr.log");
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

	//Moving the output
	string OutputPath = FOutputFilepath();
	OutputPath = OutputPath.substr(0,OutputPath.length()-1);
	if (GetParameter("Network output location").compare("none") != 0 && GetParameter("Network output location").length() > 0) {
		if (GetParameter("os").compare("windows") == 0) {
			system(("move "+OutputPath+" "+GetDatabaseDirectory(GetParameter("database"),"output directory")).data());
		} else {
			system(("cp -r  "+OutputPath+" "+GetDatabaseDirectory(GetParameter("database"),"output directory")).data());
			system(("rm -rf "+OutputPath).data());
		}
	}
	return 0;
};

void DriverOptions() {
	int Choice;
	cout << "File manipulation options:" << endl;
	cout << "1: Load a model from the centralized database" << endl;
	cout << "2: Process entire database" << endl;
	cout << "3: " << endl;
	cout << "4: Process models for MFAToolkitCGI" << endl;
	cout << "5: " << endl;
	cout << "6: " << endl;
	cout << "7: " << endl;
	cout << endl;
	Choice = int(AskNum("Input choice : "));

	switch (Choice) {
		case 1: {
			LoadDatabaseFile("");
			break;
		}
		case 2: {
			ProcessDatabase();
			break;
		}
		case 3: {
			break;
		}
		case 4: {
			ProcessWebInterfaceModels();
			break;
		}
		case 5: {
			break;
		}
		case 6: {
			break;
		}
		case 7: {
			break;
		}
		case 8: {
			break;
		}
		case 9: {
			break;
		}
		case 10: {
			break;
		}
		case 11: {
			break;
		}
		case 12: {
			break;
		}
		default: {
			cout << endl << "Choice not recognized. Ending program...";
		}
	}
};