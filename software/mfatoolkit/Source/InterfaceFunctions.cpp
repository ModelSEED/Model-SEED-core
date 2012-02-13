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

void CommandlineInterface(vector<string> Arguments) {
	bool InputArgument = false;	
	vector<string> ParameterFiles;
	for (int i=0; i < int(Arguments.size()); i++) {
		if (Arguments[i].compare("inputfilelist") == 0) {
			if (int(Arguments.size()) >= i+2) {
				InputArgument = true;
				SetInputParametersFile(Arguments[i+1].data());
			}
		} if (Arguments[i].compare("parameterfile") == 0) {
			if (int(Arguments.size()) >= i+2) {
				ParameterFiles.push_back(Arguments[i+1].data());
				i++;
			}
		} 
	}
	if (!InputArgument) {
		SetInputParametersFile(COMMANDLINE_INPUT_FILE);
	}
	LoadParameters();
	for(int i=0; i < int(ParameterFiles.size()); i++) {
		LoadParameterFile(ParameterFiles[i]);
	}
	for (int i=0; i < int(Arguments.size()); i++) {
		if (Arguments[i].compare("resetparameter") == 0) {
			if (int(Arguments.size()) >= i+3) {
				string ParameterName = Arguments[i+1];
				findandreplace(ParameterName,"_"," ");
				SetParameter(ParameterName.data(),Arguments[i+2].data());		
			}
		} 
	}
	ClearParameterDependance("CLEAR ALL PARAMETER DEPENDANCE");
	if (Initialize() != SUCCESS) {
		return;
	}
	LoadFIGMODELParameters();
	ClearParameterDependance("CLEAR ALL PARAMETER DEPENDANCE");
	for (int i=0; i < int(Arguments.size()); i++) {
		if (Arguments[i].compare("stringcode") == 0) {
			if (int(Arguments.size()) < i+3) {
				cout << "Insufficient arguments" << endl;
				FErrorFile() << "Insufficient arguments" << endl;
				FlushErrorFile();
			} else {
				CreateStringCode(Arguments[i+1],Arguments[i+2]);
				i += 2;
			}
		} else if (Arguments[i].compare("LoadCentralSystem") == 0 || Arguments[i].compare("LoadDecentralSystem") == 0) {
			if (int(Arguments.size()) < i+2) {
				cout << "Insufficient arguments" << endl;
				FErrorFile() << "Insufficient arguments" << endl;
				FlushErrorFile();
			} else {
				LoadDatabaseFile(Arguments[i+1].data());		
			}
		} else if (Arguments[i].compare("ProcessDatabase") == 0) {
			ProcessDatabase();
		} else if (Arguments[i].compare("metabolites") == 0) {
			if (int(Arguments.size()) < i+2) {
				cout << "Insufficient arguments" << endl;
				FErrorFile() << "Insufficient arguments" << endl;
				FlushErrorFile();
			} else {
				SetParameter("metabolites to optimize",Arguments[i+1].data());		
			}
		} else if (Arguments[i].compare("WebGCM") == 0) {
			if (int(Arguments.size()) < i+3) {
				cout << "Insufficient arguments" << endl;
				FErrorFile() << "Insufficient arguments" << endl;
				FlushErrorFile();
			} else {
				RunWebGCM(Arguments[i+1].data(),Arguments[i+2].data());		
			}
		} else if (Arguments[i].compare("ProcessMolfiles") == 0) {
			if (int(Arguments.size()) < i+3) {
				cout << "Insufficient arguments" << endl;
				FErrorFile() << "Insufficient arguments" << endl;
				FlushErrorFile();
			} else {
				ProcessMolfileDirectory(Arguments[i+1].data(),Arguments[i+2].data());		
			}
		} else if (Arguments[i].compare("ProcessMolfileList") == 0) {
			ProcessMolfiles();
		}
	}
}

void RunWebGCM(string InputFilename,string OutputFilename) {
	Data* NewData = new Data(0);

	NewData->RunWebGCM(InputFilename,OutputFilename);

	delete NewData;
}

void CreateStringCode(string InputFilename, string OutputFilename) {
	Data* NewData = new Data(0);
	string TempFilename;
	Species* NewSpecies = new Species(TempFilename,NewData);
	
	if (InputFilename.length() > 3 && InputFilename.substr(InputFilename.length()-3,3).compare("mol") == 0) {
		NewSpecies->ReadFromMol(InputFilename);
	} else if (InputFilename.length() > 3 && InputFilename.substr(InputFilename.length()-3,3).compare("dat") == 0) {
		NewSpecies->ReadFromDat(InputFilename);
	} else {
		NewSpecies->ReadFromSmiles(InputFilename);
	}

	NewSpecies->MakeNeutral();
	NewSpecies->PerformAllCalculations(false,true,true,false,false);

	ofstream Output;
	if (!OpenOutput(Output,OutputFilename)) {
		return;
	}

	Output << NewSpecies->FCode();

	Output.close();
	delete NewData;
}

void LoadDatabaseFile(const char* DatabaseFilename) {
	if (GetParameter("Network output location").compare("none") != 0 && GetParameter("Network output location").length() > 0) {
		if (GetParameter("os").compare("windows") == 0) {
			system(("move "+GetDatabaseDirectory(GetParameter("database"),"output directory")+GetParameter("output folder")+" "+GetParameter("Network output location")).data());
		} else {
			system(("cp -r "+GetDatabaseDirectory(GetParameter("database"),"output directory")+GetParameter("output folder")+" "+GetParameter("Network output location")).data());
		}
	}
	
	//Getting filename that all compound and reaction data will be saved into
	string Filename(DatabaseFilename);	
	if (Filename.length() == 0) {
		Filename = AskString("Input filename for database: ");
	}
	
	//Creating datastructure for all program data
	Data* NewData = new Data(0);
	NewData->ClearData("NAME",STRING);
	NewData->AddData("NAME",RemoveExtension(RemovePath(Filename)).data(),STRING);

	//Loading data from file
	if (NewData->LoadSystem(Filename) == FAIL) {
		delete NewData;
		return;
	}
	//Performing a variety of tasks according to the parameters in the parameters files including KEGG lookup, reaction and compound printing etc.
	NewData->PerformAllRequestedTasks();
	// Test for Adjustment of DeltaGs for PH for COMPOUNDS
	bool TestCpds = 0;

	if (TestCpds){

		double IonicS = 0.25;
		FErrorFile() << "Std Transformed Gibbs Energy of Formation vs pH" << endl;
		
		for (int i=0; i < NewData->FNumSpecies(); i++){
			
			string CompoundID = NewData->GetSpecies(i)->GetData("DATABASE",STRING); // gets the cpdID
			string Name = NewData->GetSpecies(i)->GetData("NAME",STRING); // gets the name of the cpd

			Species* Temp = NewData->FindSpecies("DATABASE",CompoundID.data());
			
			//if (CompoundID.compare("cpd00003") == 0 || CompoundID.compare("cpd00004") == 0 || CompoundID.compare("cpd00002") == 0) {
			double AdjDeltaG5 = Temp->AdjustedDeltaG(IonicS,5,298.15);
			double AdjDeltaG5_kJ = 4.184*AdjDeltaG5;

			double AdjDeltaG6 = Temp->AdjustedDeltaG(IonicS,6,298.15);
			double AdjDeltaG6_kJ = 4.184*AdjDeltaG6;

			double AdjDeltaG7 = Temp->AdjustedDeltaG(IonicS,7,298.15);
			double AdjDeltaG7_kJ = 4.184*AdjDeltaG7;

			double AdjDeltaG8 = Temp->AdjustedDeltaG(IonicS,8,298.15);
			double AdjDeltaG8_kJ = 4.184*AdjDeltaG8;

			double AdjDeltaG9 = Temp->AdjustedDeltaG(IonicS,9,298.15);
			double AdjDeltaG9_kJ = 4.184*AdjDeltaG9;

			FErrorFile() << CompoundID << "\t" << AdjDeltaG5_kJ << "\t" << AdjDeltaG6_kJ << "\t" << AdjDeltaG7_kJ << "\t" << AdjDeltaG8_kJ << "\t" << AdjDeltaG9_kJ << endl;
			//}
		}

		FlushErrorFile();
	}
	// Test for Adjustment of DeltaGs for IONIC STRENGTH for COMPOUNDS
	bool TestCpdsIS = 0;

	if (TestCpdsIS){
	
		FErrorFile() << "Std Transformed Gibbs Energy of Formation vs Ionic Strength" << endl;

		for (int i=0; i < NewData->FNumSpecies(); i++){

			string CompoundID = NewData->GetSpecies(i)->GetData("DATABASE",STRING); // gets the cpdID
			string Name = NewData->GetSpecies(i)->GetData("NAME",STRING); // gets the name of the cpd

			Species* Temp = NewData->FindSpecies("DATABASE",CompoundID.data());

			double AdjDeltaG_IS0 = Temp->AdjustedDeltaG(0,7,298.15);
			double AdjDeltaG_IS0_kJ = 4.184*AdjDeltaG_IS0;

			double AdjDeltaG_IS10 = Temp->AdjustedDeltaG(0.1,7,298.15);
			double AdjDeltaG_IS10_kJ = 4.184*AdjDeltaG_IS10;

			double AdjDeltaG_IS25 = Temp->AdjustedDeltaG(0.25,7,298.15);
			double AdjDeltaG_IS25_kJ = 4.184*AdjDeltaG_IS25;

			FErrorFile() << CompoundID << "\t" << AdjDeltaG_IS0_kJ << "\t" << AdjDeltaG_IS10_kJ << "\t" << AdjDeltaG_IS25_kJ << endl;
		
		}

		FlushErrorFile();
	}
	// Test for Adjustment of DeltaGs for pH for REACTIONS
	bool TestRxns = 0;

	if (TestRxns){
		
		double IonicS = 0.25;
		//double pH = 7;
		FErrorFile() << "Std Transformed Gibbs Energy of Reaction (kJmol-1) vs pH" << endl;

		for (int i=0; i < NewData->FNumReactions(); i++){
			Reaction* Rxn = NewData->GetReaction(i);
			string RxnID = Rxn->GetData("DATABASE",STRING);
			string Name = Rxn->GetData("NAME",STRING);
		
			double DG5 = Rxn->FEstDeltaG(5,IonicS)*4.184;
			double DG6 = Rxn->FEstDeltaG(6,IonicS)*4.184;
			double DG7 = Rxn->FEstDeltaG(7,IonicS)*4.184;
			double DG8 = Rxn->FEstDeltaG(8,IonicS)*4.184;
			double DG9 = Rxn->FEstDeltaG(9,IonicS)*4.184;
			
			FErrorFile() << RxnID << "\t" << DG5 << "\t" << DG6 << "\t" << DG7 << "\t" << DG8 << "\t" << DG9 << endl;
		}
		FlushErrorFile();
	}
	// Test for Adjustment of DeltaGs for IONIC STRENGTH for REACTIONS
	bool TestRxnsIS = 0;

	if (TestRxnsIS){
		
		FErrorFile() << "Std Transformed Gibbs Energy of Reaction (kJmol-1) vs Ionic Strength" << endl;
		
		for (int i=0; i < NewData->FNumReactions(); i++){
			Reaction* Rxn = NewData->GetReaction(i);
			string RxnID = Rxn->GetData("DATABASE",STRING);
			string Name = Rxn->GetData("NAME",STRING);
			
			double DG_IS0 = Rxn->FEstDeltaG(7,0.25)*4.184;
			double DG_IS10 = Rxn->FEstDeltaG(7,0.15)*4.184;
			double DG_IS25 = Rxn->FEstDeltaG(7,0.25)*4.184;
			
			FErrorFile() << RxnID << "\t" << DG_IS0 << "\t" << DG_IS10 << "\t" << DG_IS25 << endl;

		}
		// FlushErrorFile();
	}
	delete NewData;
};

void ProcessDatabase() {
	//Creating datastructure for all program data
	Data* NewData = new Data(0);
	NewData->ProcessEntireDatabase();
	delete NewData;
};

void ProcessWebInterfaceModels() {
	string Filename(GetParameter("web interface model directory"));
	Filename.append("ModelList.txt");
	vector<string> Lines = ReadStringsFromFile(Filename,false);

	//this database will hold a combination of all of the model compounds and reactions
	Data* CompleteDatabase = new Data(0);

	//the following structures will hold the data for the various models as they are read in
	vector<Data*> Models;
	vector< map<string, Identity*, std::less<string> > > ModelGenes;
	map<string, vector<string>, std::less<string> > ReactionGenes;
	map<string, vector<string>, std::less<string> > ReactionModels;
	map<string, vector<string>, std::less<string> > CompoundModels;
	//Reading in the models and storing the data in the above structures
	for (int i=1; i < int(Lines.size()); i++) {
		cout << i << endl;
		//Parsing the model list line
		vector<string>* Strings = StringToStrings(Lines[i], "\t");
		
		if (Strings->size() >= 4) {
			Filename.assign(GetParameter("web interface model directory"));
			Filename.append((*Strings)[3]);
		}

		//Loading each model from the combined model file
		if (FileExists(Filename)) {
			map<string, Identity*, std::less<string> > CurrentGeneData;
			ModelGenes.push_back(CurrentGeneData);
			Data* NewData = new Data(0);
			Models.push_back(NewData);
			NewData->AddData("NAME",(*Strings)[0].data(),STRING);
			NewData->AddData("AUTHORS",(*Strings)[1].data(),STRING);
			NewData->AddData("ORGANISMS NAME",(*Strings)[2].data(),STRING);
			NewData->AddData("FILENAME",(*Strings)[3].data(),STRING);
			NewData->LoadSystem(Filename);
			//Loading additional data on compounds and reactions from the centralized database
			int TotalTransported = 0;
			for (int j=0; j < NewData->FNumSpecies(); j++) {
				if (NewData->GetSpecies(j)->FExtracellular()) {
					TotalTransported++;
				}
				NewData->GetSpecies(j)->LoadSpecies(NewData->GetSpecies(j)->GetData("DATABASE",STRING));
				CompoundModels[NewData->GetSpecies(j)->Query("CGI_ID")].push_back((*Strings)[0]);
				if (CompleteDatabase->FindSpecies("DATABASE;CGI_ID",NewData->GetSpecies(j)->Query("CGI_ID").data()) == NULL && CompleteDatabase->FindSpecies("DATABASE;CGI_ID",NewData->GetSpecies(j)->GetData("DATABASE",STRING).data()) == NULL) {
					CompleteDatabase->AddSpecies(NewData->GetSpecies(j));
				}
			}
			//Note that the reaction equation that was read in was cleared in favor of the database equation... this could lead to problems
			int TotalReactionsWithGenes = 0;
			for (int j=0; j < NewData->FNumReactions(); j++) {
				NewData->GetReaction(j)->LoadReaction(NewData->GetReaction(j)->GetData("DATABASE",STRING));
				ReactionModels[NewData->GetReaction(j)->Query("CGI_ID")].push_back((*Strings)[0]);
				//Capturing the gene data for entry into the gene hash
				vector<string> GeneData = NewData->GetReaction(j)->GetAllData("ASSOCIATED PEG",DATABASE_LINK);
				if (GeneData.size() > 0) {
					TotalReactionsWithGenes++;
				}
				for (int k=0; k < int(GeneData.size()); k++) {
					//Adding the gene to the reaction gene hash
					string GeneName((*Strings)[2]);
					GeneName.append(":");
					GeneName.append(GeneData[k]);
					ReactionGenes[NewData->GetReaction(j)->Query("CGI_ID")].push_back(GeneName);
					//Finding the gene and creating a new gene if the gene does not currently exist
					Identity* CurrentGene = ModelGenes[ModelGenes.size()-1][GeneData[k]];
					if (CurrentGene == NULL) {
						CurrentGene = new Identity;
						ModelGenes[ModelGenes.size()-1][GeneData[k]] = CurrentGene;
					}
					//Adding the reaction data to the gene data
					CurrentGene->AddData("REACTIONS",NewData->GetReaction(j)->Query("CGI_ID").data(),STRING);
					vector<string> EnzymeData = NewData->GetReaction(j)->GetAllData("ENZYME",DATABASE_LINK);
					for (int l=0; l < int(EnzymeData.size()); l++) {
						CurrentGene->AddData("ENZYME",EnzymeData[l].data(),STRING);
					}
					EnzymeData = NewData->GetReaction(j)->GetAllData("PATHWAYS",STRING);
					for (int l=0; l < int(EnzymeData.size()); l++) {
						CurrentGene->AddData("PATHWAY",EnzymeData[l].data(),STRING);
					}

				}
				//Adding all unique reactions to the complete database
				if (CompleteDatabase->FindReaction("DATABASE;CGI_ID",NewData->GetReaction(j)->Query("CGI_ID").data()) == NULL && CompleteDatabase->FindReaction("DATABASE;CGI_ID",NewData->GetReaction(j)->GetData("DATABASE",STRING).data()) == NULL) {
					CompleteDatabase->AddReaction(NewData->GetReaction(j));
				}
			}
			//Searching the model for dead compounds and reactions
			NewData->FindDeadEnds();
			NewData->AddData("TRANSPORTED COMPOUNDS",double(TotalTransported));
			NewData->AddData("REACTION WITH GENES",double(TotalReactionsWithGenes));
		}

		delete Strings;
	}

	//Printing the combined compounds table
	Filename.assign(GetParameter("web interface model directory"));
	Filename.append("AllCompoundsTable.txt");
	ofstream CompleteOutput;
	if (!OpenOutput(CompleteOutput,Filename)) {
		return;
	}
	CompleteOutput << "ID	SHORTNAME	NAMES	STATUS IN MODEL	MODELS	FORMULA	MASS	CHARGE(pH7)	DELTA G(kcal/mol)	PATHWAY	DATABASE LINKS	REACTIONS" << endl;
	for (int i=0; i < CompleteDatabase->FNumSpecies(); i++) {
		CompleteOutput << CompleteDatabase->GetSpecies(i)->Query("CGI_ID") << "\t";
		CompleteOutput << CompleteDatabase->GetSpecies(i)->Query("SHORTNAME") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetSpecies(i)->GetAllDataString("NAME",STRING).data(),"\t",", ") << "\t";
		CompleteOutput << "Not in model" << "\t";
		vector<string> ModelList = CompoundModels[CompleteDatabase->GetSpecies(i)->Query("CGI_ID")];
		for (int j=0; j < int(ModelList.size()-1); j++) {
			CompleteOutput << ModelList[j] << ", ";
		}
		CompleteOutput << ModelList[ModelList.size()-1] << "\t";		CompleteOutput << CompleteDatabase->GetSpecies(i)->FFormula() << "\t";
		CompleteOutput << CompleteDatabase->GetSpecies(i)->FMW() << "\t";
		CompleteOutput << CompleteDatabase->GetSpecies(i)->FCharge() << "\t";
		CompleteOutput << CompleteDatabase->GetSpecies(i)->FEstDeltaG() << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetSpecies(i)->GetAllDataString("PATHWAYS",STRING).data(),"\t",", ") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetSpecies(i)->GetCombinedData(DATABASE_LINK).data(),"\t",", ") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetSpecies(i)->Query("REACTIONS").data(),"\t",", ") << endl;
	}
	CompleteOutput.close();

	//Printing the combined reactions table
	Filename.assign(GetParameter("web interface model directory"));
	Filename.append("AllReactionsTable.txt");
	if (!OpenOutput(CompleteOutput,Filename)) {
		return;
	}
	CompleteOutput << "ID	SHORTNAME	NAMES	STATUS IN MODEL	MODELS	DEFINITION	EQUATION	EC NUMBER	ASSIGNED FUNCTIONS	ASSIGNED GENES	DELTA G(kcal/mol)	PATHWAY	PREVIOUS REACTIONS	NEXT REACTIONS" << endl;
	for (int i=0; i < CompleteDatabase->FNumReactions(); i++) {
		CompleteOutput << CompleteDatabase->GetReaction(i)->Query("CGI_ID") << "\t";
		CompleteOutput << CompleteDatabase->GetReaction(i)->Query("SHORTNAME") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetReaction(i)->GetAllDataString("NAME",STRING).data(),"\t",", ") << "\t";
		CompleteOutput << "Not in model" << "\t";
		vector<string> ModelList = ReactionModels[CompleteDatabase->GetReaction(i)->Query("CGI_ID")];
		for (int j=0; j < int(ModelList.size()-1); j++) {
			CompleteOutput << ModelList[j] << ", ";
		}
		CompleteOutput << ModelList[ModelList.size()-1] << "\t";
		CompleteOutput << CompleteDatabase->GetReaction(i)->Query("DEFINITION") << "\t";
		CompleteOutput << CompleteDatabase->GetReaction(i)->CreateReactionEquation("CGI_ID") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetReaction(i)->GetAllDataString("ENZYME",DATABASE_LINK).data(),"\t",", ") << "\t";
		CompleteOutput << "No data" << "\t";
		vector<string> AssignedGenes = ReactionGenes[CompleteDatabase->GetReaction(i)->Query("CGI_ID")];
		if (AssignedGenes.size() >= 1) {
			for (int j=0; j < int(AssignedGenes.size()-1); j++) {
				CompleteOutput << AssignedGenes[j] << ", ";
			}
			CompleteOutput << AssignedGenes[AssignedGenes.size()-1] << "\t";
		} else {
			CompleteOutput << "None" << "\t";
		}
		CompleteOutput << CompleteDatabase->GetReaction(i)->FEstDeltaG() << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetReaction(i)->Query("PATHWAYS").data(),"\t",", ") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetReaction(i)->Query("PREVIOUS").data(),"\t",", ") << "\t";
		CompleteOutput << StringReplace(CompleteDatabase->GetReaction(i)->Query("NEXT").data(),"\t",", ") << endl;
	}
	CompleteOutput.close();

	//Printing the compounds, reactions, and genes tables for each model and the model table
	Filename.assign(GetParameter("web interface model directory"));
	Filename.append("ModelTable.txt");
	if (!OpenOutput(CompleteOutput,Filename)) {
		return;
	}
	CompleteOutput << "ID	MODEL AUTHORS	ORGANISMS NAME	TOTAL COMPOUNDS	TRANSPORTED COMPOUNDS	DEAD COMPOUNDS	TOTAL REACTIONS	REACTIONS WITH GENES	DEAD REACTIONS	NUMBER OF GENES" << endl;
	for (int j=0; j < int(Models.size()); j++) {
		//Printing the model data into the model table
		CompleteOutput << Models[j]->GetData("NAME",STRING) << "\t";
		CompleteOutput << Models[j]->GetData("AUTHORS",STRING) << "\t";
		CompleteOutput << Models[j]->GetData("ORGANISMS NAME",STRING) << "\t";
		CompleteOutput << Models[j]->FNumSpecies() << "\t";
		CompleteOutput << Models[j]->GetDoubleData("TRANSPORTED COMPOUNDS") << "\t";
		CompleteOutput << Models[j]->GetDoubleData("DEAD COMPOUNDS") << "\t";
		CompleteOutput << Models[j]->FNumReactions() << "\t";
		CompleteOutput << Models[j]->GetDoubleData("REACTION WITH GENES") << "\t";
		CompleteOutput << Models[j]->GetDoubleData("DEAD REACTIONS") << "\t";
		CompleteOutput << ModelGenes[j].size() << endl;
		
		ofstream ModelOutput;
		Filename.assign(GetParameter("web interface model directory"));
		Filename.append(Models[j]->GetData("NAME",STRING));
		Filename.append("CompoundsTable.txt");
		if (!OpenOutput(ModelOutput,Filename)) {
			return;
		}
		ModelOutput << "ID	SHORTNAME	NAMES	STATUS IN MODEL	MODELS	FORMULA	MASS	CHARGE(pH7)	DELTA G(kcal/mol)	PATHWAY	DATABASE LINKS	REACTIONS" << endl;
		for (int i=0; i < Models[j]->FNumSpecies(); i++) {
			ModelOutput << Models[j]->GetSpecies(i)->Query("CGI_ID") << "\t";
			ModelOutput << Models[j]->GetSpecies(i)->Query("SHORTNAME") << "\t";
			ModelOutput << StringReplace(Models[j]->GetSpecies(i)->GetAllDataString("NAME",STRING).data(),"\t",", ") << "\t";
			ModelOutput << Models[j]->GetSpecies(i)->GetData("CLASS",STRING) << "\t";
			vector<string> ModelList = ReactionModels[Models[j]->GetSpecies(i)->Query("CGI_ID")];
			if (ModelList.size() > 0) {
				for (int k=0; k < int(ModelList.size()-1); k++) {
					ModelOutput << ModelList[k] << ", ";
				}
				ModelOutput << ModelList[ModelList.size()-1] << "\t";
			} else {
				ModelOutput << "No data" << "\t";
			}
			ModelOutput << Models[j]->GetSpecies(i)->FFormula() << "\t";
			ModelOutput << Models[j]->GetSpecies(i)->FMW() << "\t";
			ModelOutput << Models[j]->GetSpecies(i)->FCharge() << "\t";
			ModelOutput << Models[j]->GetSpecies(i)->FEstDeltaG() << "\t";
			ModelOutput << StringReplace(Models[j]->GetSpecies(i)->GetAllDataString("PATHWAYS",STRING).data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(Models[j]->GetSpecies(i)->GetCombinedData(DATABASE_LINK).data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(Models[j]->GetSpecies(i)->Query("REACTIONS").data(),"\t",", ") << endl;
		}
		ModelOutput.close();

		Filename.assign(GetParameter("web interface model directory"));
		Filename.append(Models[j]->GetData("NAME",STRING));
		Filename.append("ReactionsTable.txt");
		if (!OpenOutput(ModelOutput,Filename)) {
			return;
		}
		ModelOutput << "ID	SHORTNAME	NAMES	STATUS IN MODEL	MODELS	DEFINITION	EQUATION	EC NUMBER	ASSIGNED FUNCTIONS	ASSIGNED GENES	DELTA G(kcal/mol)	PATHWAY	PREVIOUS REACTIONS	NEXT REACTIONS" << endl;
		for (int i=0; i < Models[j]->FNumReactions(); i++) {
			ModelOutput << Models[j]->GetReaction(i)->Query("CGI_ID") << "\t";
			ModelOutput << Models[j]->GetReaction(i)->Query("SHORTNAME") << "\t";
			ModelOutput << StringReplace(Models[j]->GetReaction(i)->GetAllDataString("NAME",STRING).data(),"\t",", ") << "\t";
			ModelOutput << Models[j]->GetReaction(i)->GetData("CLASS",STRING) << "\t";
			vector<string> ModelList = ReactionModels[Models[j]->GetReaction(i)->Query("CGI_ID")];
			if (ModelList.size() > 0) {
				for (int k=0; k < int(ModelList.size()-1); k++) {
					ModelOutput << ModelList[k] << ", ";
				}
				ModelOutput << ModelList[ModelList.size()-1] << "\t";
			}else {
				ModelOutput << "No data" << "\t";
			}
			ModelOutput << Models[j]->GetReaction(i)->Query("DEFINITION") << "\t";
			ModelOutput << Models[j]->GetReaction(i)->CreateReactionEquation("CGI_ID") << "\t";
			ModelOutput << StringReplace(Models[j]->GetReaction(i)->GetAllDataString("ENZYME",DATABASE_LINK).data(),"\t",", ") << "\t";
			ModelOutput << "No data" << "\t";
			vector<string> AssignedGenes = ReactionGenes[Models[j]->GetReaction(i)->Query("CGI_ID")];
			if (AssignedGenes.size() >= 1) {
				bool First = true;
				for (int k=0; k < int(AssignedGenes.size()); k++) {
					if (AssignedGenes[k].length() > Models[j]->GetData("ORGANISMS NAME",STRING).length() && AssignedGenes[k].substr(0,Models[j]->GetData("ORGANISMS NAME",STRING).length()).compare(Models[j]->GetData("ORGANISMS NAME",STRING)) == 0) {
						if (!First) {
							ModelOutput << ", ";
						}
						First = false;
						ModelOutput << AssignedGenes[k].substr(Models[j]->GetData("ORGANISMS NAME",STRING).length()+1,AssignedGenes[k].length()-Models[j]->GetData("ORGANISMS NAME",STRING).length()-1);
					}
				}
				ModelOutput << "\t";
			} else {
				ModelOutput << "None" << "\t";
			}
			ModelOutput << Models[j]->GetReaction(i)->FEstDeltaG() << "\t";
			ModelOutput << StringReplace(Models[j]->GetReaction(i)->Query("PATHWAYS").data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(Models[j]->GetReaction(i)->Query("PREVIOUS").data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(Models[j]->GetReaction(i)->Query("NEXT").data(),"\t",", ") << endl;
		}
		ModelOutput.close();

		Filename.assign(GetParameter("web interface model directory"));
		Filename.append(Models[j]->GetData("NAME",STRING));
		Filename.append("GenesTable.txt");
		if (!OpenOutput(ModelOutput,Filename)) {
			return;
		}
		ModelOutput << "ID	SHORTNAME	NAMES	ASSIGNED FUNCTIONS	STATUS IN ORGANISM	PARALOGS	COORDINATES	DIRECTIONALITY	EC NUMBER	PATHWAY	REACTIONS" << endl;
		for (map<string, Identity*, std::less<string> >::iterator MapIT = ModelGenes[j].begin(); MapIT != ModelGenes[j].end(); MapIT++) {
			ModelOutput << MapIT->first << "\t";
			ModelOutput << MapIT->first << "\t";
			ModelOutput << MapIT->first << "\t";
			ModelOutput << "No data" << "\t";
			ModelOutput << "No data" << "\t";
			ModelOutput << "No data" << "\t";
			ModelOutput << "No data" << "\t";
			ModelOutput << "No data" << "\t";
			ModelOutput << StringReplace(MapIT->second->GetAllDataString("ENZYME",STRING).data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(MapIT->second->GetAllDataString("PATHWAY",STRING).data(),"\t",", ") << "\t";
			ModelOutput << StringReplace(MapIT->second->GetAllDataString("REACTIONS",STRING).data(),"\t",", ") << endl;
		}
		ModelOutput.close();
	}
	CompleteOutput.close();
}

void ProcessMolfileDirectory(string Directory,string OutputDirectory) {
	vector<string> DirectoryList = GetDirectoryFileList(Directory);

	Data* NewData = new Data(0);
	for (int i=0; i < int(DirectoryList.size()); i++) {
		cout << DirectoryList[i] << endl;
		Species* NewSpecies = new Species("", NewData, false);
		if (DirectoryList[i].length() > 0) {
			NewSpecies->ReadFromMol(Directory+DirectoryList[i]);
			NewSpecies->LabelAtoms();
			string FileRoot = RemovePath(RemoveExtension(DirectoryList[i]));
			ofstream Output;
			if (OpenOutput(Output,OutputDirectory+FileRoot+".txt")) {
				Output << "Atom index;Group;GroupIndex" << endl;
				for (int j=0; j < NewSpecies->FNumAtoms(); j++) {
					Output << j << ";" << NewSpecies->GetAtom(j)->FGroupString() << ";" << NewSpecies->GetAtom(j)->FGroupIndex() << endl;
				}
				Output.close();
			}
		}
		delete NewSpecies;
	}
}

void ProcessMolfiles() {
	string fullfile = FOutputFilepath()+"MolfileInput.txt";
	ifstream Input;
	if (!OpenInput(Input,fullfile)) {
		return;	
	}
	ofstream Output;
	string outfile = FOutputFilepath()+"MolfileOutput.txt";
	if (OpenOutput(Output,outfile)) {
		Data* NewData = new Data(0);
		Output << "id\tmolfile\tgroups\tcharge\tformula\tstringcode\tmass\tdeltaG\tdeltaGerr" << endl;
		GetStringsFileline(Input,"\t",false);
		while(!Input.eof()) {
			vector<string>* strings = GetStringsFileline(Input,"\t",false);
			if (strings->size() >= 2) {
				Species* NewSpecies = new Species("", NewData, false);
				NewSpecies->ReadFromMol(FOutputFilepath()+"molfiles/"+(*strings)[1]);
				NewSpecies->PerformAllCalculations(true,true,true,true,true);
				string cues = NewSpecies->CreateStructuralCueList();
				findandreplace(cues,"\t","|");
				Output << (*strings)[0] << "\t" << (*strings)[1] << "\t" << cues << "\t" << NewSpecies->FCharge() << "\t" << NewSpecies->FFormula() << "\t";
				Output << NewSpecies->FCode() << "\t" << NewSpecies->FMW() << "\t" << NewSpecies->FEstDeltaG() << "\t" << NewSpecies->FEstDeltaGUncertainty() << endl;
				delete NewSpecies;
			}
			delete strings;
		}
		Output.close();
	}
	Input.close();
}