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
	setVerbose(false);
	if (argc == 1) {
		cout << "Insufficient arguments! Usage: mfatoolkit parameterfile <new filename> resetparameter <parameter name> <parameter value> LoadCentralSystem <model name> -verbose" << endl;
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
			system(("move "+OutputPath+" "+GetDatabaseDirectory(false)).data());
		} else {
			system(("cp -r  "+OutputPath+" "+GetDatabaseDirectory(false)).data());
			system(("rm -rf "+OutputPath).data());
		}
	}
	return 0;
};
