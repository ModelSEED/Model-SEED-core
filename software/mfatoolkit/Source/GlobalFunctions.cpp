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

ofstream OuputLog;

StringDB* stringDatabase;

//This is a simple two-D text-based database loaded from a flat file
map<string, map<string, map<string, string, std::less<string> >, std::less<string> >, std::less<string> > CompleteDatabase;

//These are all of the global data that is available throughout the program through the access functions listed here
map<string , string , std::less<string> > Parameters;

vector<FileReferenceData*> FileReferences;

map<string , int, std::less<string> > InternalReferenceConversion;

map<string, FileReferenceData*, std::less<string> > RxnFileReferences;

map<string, FileReferenceData*, std::less<string> > CpdFileReferences;

map<string, FileReferenceData*, std::less<string> > GeneFileReferences;

map<string , CellCompartment* , std::less<string> > CompartmentsByAbbrev;

vector<CellCompartment*> CompartmentVector;

CellCompartment* DefaultCompartment;

vector<AtomType*> AtomData;

map< string, string, std::less<string> > BasicCodes;

vector<string> HybridKey;

vector<string> HybridCodes;

map< string, vector<Species*>, std::less<string> > UnlabeledFormulas;

map< string, MFAVariable*, std::less<string> > variableNames;
map< string, LinEquation*, std::less<string> > constraintNames;

vector<int> PrimeNumbers;

string ProgramPath;
string InputParameters;
string CompleteErrors;

ostringstream ErrorFile;

ifstream GlobalInput;
ofstream GlobalOutput;

void CloseIOFiles() {
	if (GlobalInput.is_open()) {
		GlobalInput.close();
	}
	if (GlobalOutput.is_open()) {
		GlobalOutput.close();
	}
}

string AskString(const char* Question) {
	string Suffix;
	cout << Question << " ";
	
	if (!GlobalInput.is_open()) {
		cin >> Suffix;
		if (GlobalOutput.is_open()) {
			GlobalOutput << Suffix << endl;
		}
	}
	else {
		GlobalInput >> Suffix;
		cout << Suffix;
	}

	cout << endl;
	return Suffix;
};

bool Ask(const char* Question) {
	string Buff;
	cout << Question << " (y/n): ";
	
	if (!GlobalInput.is_open()) {
		cin >> Buff;
		if (GlobalOutput.is_open()) {
			GlobalOutput << Buff << endl;
		}
	}
	else {
		GlobalInput >> Buff;
		cout << Buff;
	}
	
	cout << endl << endl;
	if (Buff.compare("y") == 0) {
		return true;
	}
	else {
		return false;
	}
}

double AskNum(const char* Question) {
	double Temp;
	cout << Question;
	
	if (!GlobalInput.is_open()) {
		cin >> Temp;
		if (GlobalOutput.is_open()) {
			GlobalOutput << Temp << endl;
		}
	}
	else {
		GlobalInput >> Temp;
		cout << Temp;
	}	
	
	cout << endl << endl;
	return Temp;
}

int LoadStringDB() {
	char* temp = getenv ("ModelSeedDBSpec");
	if (temp != NULL) {
		stringDatabase = new StringDB(CheckFilename(temp),FProgramPath());
		cout<< "Loading Database Table MSDBS\t"<<temp<<endl;
		return SUCCESS;
	}
	
	cout<< "Loading Database Table DBSF\t"<<GetParameter("database spec file")<<endl;

	stringDatabase = new StringDB(GetParameter("database spec file"),FProgramPath());
	return SUCCESS;
}

StringDB* GetStringDB() {
	return stringDatabase;
}

//This function is reponsible for reading in all of the global data
int Initialize() {
	LoadTextDatabase();
	LoadStringDB();
	string OutputIndex = GetParameter("output index");
	string Filename(FOutputFilepath());
	Filename.append("ErrorLog");
	Filename.append(OutputIndex);
	Filename.append(".txt");
	Filename = CheckFilename(Filename);
	SetParameter("Error filename",Filename.data());
	ofstream Output(Filename.data());
	Output.close();
	
	Filename.assign(FOutputFilepath());
	Filename.append("Output");
	Filename.append(OutputIndex);
	Filename.append(".txt");
	if (!OpenOutput(OuputLog,Filename)) {
		return FAIL;	
	}

	ClearSolverVariables();
	InitializeInternalReferences();
	InitializeGLPKVariables();
	InitializeCPLEXVariables();
	InitializeSCIPVariables();
	InitializeLINDOVariables();

	if (LoadFileReferences() == FAIL) {
		return FAIL;
	}
	if (LoadAtomTypes() == FAIL) {
		return FAIL;
	}
	if (ReadCompartmentFile() == FAIL) {
		return FAIL;
	}

	return SUCCESS;
}

//This function establishes the links between internal constants and written out constants.
void InitializeInternalReferences() {
	InternalReferenceConversion["RXN_EQUATION"] = RXN_EQUATION;
	InternalReferenceConversion["RXN_DBLINK"] = RXN_DBLINK;
	InternalReferenceConversion["RXN_STRUCTURALCUES"] = RXN_STRUCTURALCUES;
	InternalReferenceConversion["RXN_DOUBLE"] = RXN_DOUBLE;
	InternalReferenceConversion["RXN_DELTAG"] = RXN_DELTAG;
	InternalReferenceConversion["RXN_DELTAGERR"] = RXN_DELTAGERR;
	InternalReferenceConversion["RXN_COMPONENTS"] = RXN_COMPONENTS;
	InternalReferenceConversion["RXN_CODE"] = RXN_CODE;
	InternalReferenceConversion["RXN_ERRORMSG"] = RXN_ERRORMSG;
	InternalReferenceConversion["RXN_STRING"] = RXN_STRING;
	InternalReferenceConversion["RXN_ALLDBLINKS"] = RXN_ALLDBLINKS;
	InternalReferenceConversion["RXN_QUERY"] = RXN_QUERY;
	InternalReferenceConversion["RXN_GENE"] = RXN_GENE;
	InternalReferenceConversion["RXN_LOAD"] = RXN_LOAD;
	InternalReferenceConversion["RXN_DIRECTION"] = RXN_DIRECTION;
	InternalReferenceConversion["RXN_COMPARTMENT"] = RXN_COMPARTMENT;

	InternalReferenceConversion["GENE_DBLINK"] = GENE_DBLINK;
	InternalReferenceConversion["GENE_COORD"] = GENE_COORD;
	InternalReferenceConversion["GENE_REACTION"] = GENE_REACTION;
	InternalReferenceConversion["GENE_PARALOG"] = GENE_PARALOG;
	InternalReferenceConversion["GENE_ORTHOLOG"] = GENE_ORTHOLOG;
	InternalReferenceConversion["GENE_DOUBLE"] = GENE_DOUBLE;
	InternalReferenceConversion["GENE_STRING"] = GENE_STRING;
	InternalReferenceConversion["GENE_QUERY"] = GENE_QUERY;
	InternalReferenceConversion["GENE_LOAD"] = GENE_LOAD;

	InternalReferenceConversion["CPD_DBLINK"] = CPD_DBLINK;
	InternalReferenceConversion["CPD_FORMULA"] = CPD_FORMULA;
	InternalReferenceConversion["CPD_NEUTRAL_CHARGE"] = CPD_NEUTRAL_CHARGE;
	InternalReferenceConversion["CPD_COFACTOR"] = CPD_COFACTOR;
	InternalReferenceConversion["CPD_DELTAG"] = CPD_DELTAG;
	InternalReferenceConversion["CPD_DELTAGERR"] = CPD_DELTAGERR;
	InternalReferenceConversion["CPD_MW"] = CPD_MW;
	InternalReferenceConversion["CPD_PKA"] = CPD_PKA;
	InternalReferenceConversion["CPD_PKB"] = CPD_PKB;
	InternalReferenceConversion["CPD_STRUCTURALCUES"] = CPD_STRUCTURALCUES;
	InternalReferenceConversion["CPD_DOUBLE"] = CPD_DOUBLE;
	InternalReferenceConversion["CPD_CUE"] = CPD_CUE;
	InternalReferenceConversion["CPD_STRINGCODE"] = CPD_STRINGCODE;
	InternalReferenceConversion["CPD_CHARGE"] = CPD_CHARGE;
	InternalReferenceConversion["CPD_SMALLMOLEC"] = CPD_SMALLMOLEC;
	InternalReferenceConversion["CPD_STRING"] = CPD_STRING;
	InternalReferenceConversion["CPD_ERRORMSG"] = CPD_ERRORMSG;
	InternalReferenceConversion["CPD_ALLDBLINKS"] = CPD_ALLDBLINKS;
	InternalReferenceConversion["CPD_QUERY"] = CPD_QUERY;
	InternalReferenceConversion["CPD_LOAD"] = CPD_LOAD;
}

int LoadTextDatabase() {
	string Filename(GetParameter("input directory")+GetParameter("database")+".txt");
	ifstream Input;
	if (!OpenInput(Input,Filename)) {
		return FAIL;
	}
	cout << Filename << "\tfile!" << endl;
	bool New = false;
	string CurrentObject;
	string CurrentObjectID;
	while (!Input.eof()) {
		vector<string>* Strings = GetStringsFileline(Input, "|");
		
		if (Strings->size() == 1 && (*Strings)[0].compare("NEW") == 0) {
			cout << (*Strings)[0] << "\tValue1" << endl;		
			New = true;
		} else if (Strings->size() == 2) {
			cout << (*Strings)[0] << "\tValue2" << endl;
			if (New) {
				CurrentObject = (*Strings)[0];
				CurrentObjectID = (*Strings)[1];
				New = false;
			} else {
				if ((*Strings)[1].find("{") != (*Strings)[1].npos) {
					vector<string>* StringsTwo = StringToStrings((*Strings)[1],"{}",false);
					string NewParameterValue;
					for (int i=0; i < int(StringsTwo->size()); i++) {
						NewParameterValue.append((*StringsTwo)[i]);
						i++;
						if (i != int(StringsTwo->size())) {
							if ((*StringsTwo)[i].substr(0,1).compare("$") == 0) {
								string Temp = (*StringsTwo)[i].substr(1,(*StringsTwo)[i].length()-1);
								NewParameterValue.append(getenv(Temp.data()));
							} else {
								string SubParameterValue = GetParameter((*StringsTwo)[i].data());
								NewParameterValue.append(SubParameterValue);
							}
						}
					}
					(*Strings)[1] = NewParameterValue;
					delete StringsTwo;
				}
				CompleteDatabase[CurrentObject][CurrentObjectID][(*Strings)[0]] = (*Strings)[1];
			}
		}

		delete Strings;
	}

	Input.close();
	return SUCCESS;
}

void ClearParameterDependance(string InParameterName) {
	if (InParameterName.compare("CLEAR ALL PARAMETER DEPENDANCE") == 0) {
		//Scanning through the parameters and removing any cases where one parameter depends on the value of another
		for (map<string , string , std::less<string> >::iterator MapIT = Parameters.begin(); MapIT != Parameters.end(); MapIT++) {
			ClearParameterDependance(MapIT->first);
		}
	} else {
		string ParameterValue = GetParameter(InParameterName.data());
		if (ParameterValue.find("{") != ParameterValue.npos) {
			vector<string>* Strings = StringToStrings(ParameterValue,"{}",false);
			string NewParameterValue;
			for (int i=0; i < int(Strings->size()); i++) {
				NewParameterValue.append((*Strings)[i]);
				i++;
				if (i != int(Strings->size())) {
					string SubParameterValue = GetParameter((*Strings)[i].data());
					if (SubParameterValue.find("{") != SubParameterValue.npos) {
						ClearParameterDependance((*Strings)[i]);
						SubParameterValue = GetParameter((*Strings)[i].data());
					}
					NewParameterValue.append(SubParameterValue);
				}
			}
			SetParameter(InParameterName.data(),NewParameterValue.data());
			delete Strings;
		}
	}
}

string QueryTextDatabase(string Object, string ObjectID, string Subobject) {
	return CompleteDatabase[Object][ObjectID][Subobject];
}

vector<string> GetTextDatabaseObjectList(string Object) {
	vector<string> Result;

	for (map<string, map<string, string, std::less<string> >, std::less<string> >::iterator MapIT; MapIT != CompleteDatabase[Object].end(); MapIT++) {
		Result.push_back(MapIT->first);
	}

	return Result;
}

int TranslateFileHeader(string& InHeader, int Object) {
	FileReferenceData* NewReference = NULL;
	if (Object == REACTION) {
		NewReference = RxnFileReferences[InHeader];
	} else if (Object == COMPOUND) {
		NewReference = CpdFileReferences[InHeader];
	} else {
		NewReference = GeneFileReferences[InHeader];
	}

	if (NewReference != NULL) {
		InHeader = NewReference->ConsistentName;
		return NewReference->DataID;
	}

	return -1;
}

//This functions reads in the data that allows the input file headers to be interpreted by the parser
int LoadFileReferences() {
	ifstream Input;
	if (!OpenInput(Input,GetParameter("input directory")+GetParameter("filename for file reference data"))) {
		return FAIL;
	}

	//These boolean identify which file references we are currently reading in
	bool CompoundReferences = false;
	bool ReactionReferences = false;

	string Fileline = GetFileLine(Input);
	do {
		string Fileline = GetFileLine(Input);
		if (Fileline.compare("REACTIONS") == 0) {
			CompoundReferences = false;
			ReactionReferences = true;
		} else if (Fileline.compare("COMPOUNDS") == 0) {
			CompoundReferences = true;
			ReactionReferences = false;
		} else if (Fileline.compare("GENES") == 0) {
			CompoundReferences = false;
			ReactionReferences = false;
		} else {
			//Add data to the datareference map 
			vector<string>* Strings = StringToStrings(Fileline,";",false);
			for (int i=1; i < int(Strings->size()); i++) {
				FileReferenceData* NewReference = new FileReferenceData;
				NewReference->ConsistentName = (*Strings)[0];
				if (i == 1) {
					NewReference->FileReference = (*Strings)[0];
				} else {
					NewReference->FileReference = (*Strings)[i];
				}
				if (InternalReferenceConversion.count((*Strings)[1].data()) == 0) {
					//FErrorFile() << "Unrecognized internal ID: " << (*Strings)[1] << " used in file reference file." << endl; 
					//FlushErrorFile();
					NewReference->DataID = -1;
				} else {
					NewReference->DataID = InternalReferenceConversion[(*Strings)[1].data()];
				}
				if (CompoundReferences) {
					CpdFileReferences[NewReference->FileReference] = NewReference;
					FileReferences.push_back(NewReference);
				} else if (ReactionReferences) {
					RxnFileReferences[NewReference->FileReference] = NewReference;
					FileReferences.push_back(NewReference);
				} else {
					GeneFileReferences[NewReference->FileReference] = NewReference;
					FileReferences.push_back(NewReference);
				}
			}
			delete Strings;
		}
	} while (!Input.eof());

	Input.close();

	return SUCCESS;
}

int LoadFIGMODELParameters() {
	if (FileExists(GetDatabaseDirectory(GetParameter("database"),"root directory")+GetParameter("FIGMODEL config file"))) {
		ifstream Input;
		if (!OpenInput(Input,GetDatabaseDirectory(GetParameter("database"),"root directory")+GetParameter("FIGMODEL config file"))) {
			return FAIL;
		}
		do {
			vector<string>* Strings  = GetStringsFileline(Input,"|");
			if (Strings->size() > 0 && (*Strings)[0].length() > 0 && (*Strings)[0].substr(0,1).compare("%") != 0) {
				if ((*Strings)[0].substr(0,1).compare(".") == 0) {
					(*Strings)[0] = (*Strings)[0].substr(1,(*Strings)[0].length()-1);
					if ((*Strings)[1].length() > 11 && (*Strings)[1].substr(0,11).compare("ReactionDB/") == 0) {
						(*Strings)[1] = (*Strings)[1].substr(11);
					}
					(*Strings)[1].insert(0,GetDatabaseDirectory(GetParameter("database"),"root directory"));
				}
				(*Strings)[0].insert(0,"FIGMODEL ");
				Parameters[ (*Strings)[0] ] = (*Strings)[1];
			}
			delete Strings;
		} while(!Input.eof());
		Input.close();
	}
	return SUCCESS;
}

void Cleanup() {
	FlushErrorFile();
	OuputLog.close();
	
	for (int i=0; i < int(FileReferences.size()); i++) {
		delete FileReferences[i];
	}
	
	for (int i=0; i < int(AtomData.size()); i++) {
		delete AtomData[i];
	}

	for (int i=0; i < int(CompartmentVector.size()); i++) {
		for (map<string, double*, std::less<string> >::iterator mapIT = CompartmentVector[i]->SpecialConcRanges.begin(); mapIT != CompartmentVector[i]->SpecialConcRanges.end(); mapIT++) {
			delete [] mapIT->second;
		}
		delete CompartmentVector[i];
	}

	PrintFileLineOutput();
}

int LoadParameters() {
	//Open the file containing a list of all text files which contain various input parameters for this software
	ifstream Input;
	string Filename(FProgramPath());
	Filename.append(FInputParameterFile());
	if (!OpenInput(Input, Filename)) {
		return FAIL;
	}

	//Read in the filename of each text file containing input parameters, open the files and read in the parameters
	do {
		string Line = GetFileLine(Input);
		if (Line.length() > 3) {
			LoadParameterFile(Line);
		}
	} while(!Input.eof());
	//Close the file listing all of the input parameter filenames
	Input.close();

	return SUCCESS;
}

int LoadParameterFile(string Filename) {
	ifstream Input;
	if (!OpenInput(Input, Filename)) {
		return FAIL;
	}

	cout<<"Reading parameter file: "<< Filename << endl;

	//Read in the parameters and store them
	do {
		vector<string>* Strings = GetStringsFileline(Input, "|",false);
		if (Strings->size() >= 2) {
			if(Parameters[ (*Strings)[0] ].length()==0){
			  cout << "Reading parameter: "<<(*Strings)[0]<<" with value: "<<(*Strings)[1]<<" from file: "<<Filename<<endl;
			}else{
			  cout << "Overwriting parameter: "<<(*Strings)[0]<<" with value: "<<(*Strings)[1]<<" from file: "<<Filename<<endl;
			}
			Parameters[ (*Strings)[0] ] = (*Strings)[1];
		}
		delete Strings;
	} while(!Input.eof());

	//Close the input parameters file
	Input.close();
	return SUCCESS;
}

string GetParameter(const char* ParameterLabel) {
	string Label(ParameterLabel);
	string Result = Parameters[Label];
	if (Result.length() == 0) {
		FErrorFile() << "Could not find parameter: " << Label << endl;
		FlushErrorFile();
	}	
	return Result;
}

void SetParameter(const char* ParameterLabel,const char* NewValue) {
	string NewValueString(NewValue);
	string Label(ParameterLabel);
	Parameters[Label] = NewValueString;
}

string FOutputFilepath() {
	string Temp(GetDatabaseDirectory(GetParameter("database"),"output directory"));
	if (GetParameter("Network output location").compare("none") != 0 && GetParameter("Network output location").length() > 0) {
		Temp.assign(GetParameter("Network output location"));
	}
	Temp.append(GetParameter("output folder"));
	if (Temp.substr(0,12).compare("/cygdrive/c/") == 0) {
		Temp = "C:/" + Temp.substr(12);
	}
	return Temp;
}

string FProgramPath() {
	return ProgramPath;
}

void SetProgramPath(const char* InPath) {
	ProgramPath = StringReplace(InPath,"\\","/");
	int Location = int(ProgramPath.rfind("/"));
	int LocationTwo = int(ProgramPath.rfind("\\"));
	if (Location == LocationTwo) {
		ProgramPath.assign("");
	} else if (Location > LocationTwo) {
		ProgramPath = ProgramPath.substr(0,Location+1);
	} else if (Location < LocationTwo) {
		ProgramPath = ProgramPath.substr(0,LocationTwo+1);
	}
}

void SetInputParametersFile(const char* InPath) {
	InputParameters.assign(InPath);
}

string FInputParameterFile() {
	return InputParameters;
}

ofstream& FLogFile() {
	return OuputLog;
}

ostringstream& FErrorFile() {
	return ErrorFile;
}

void FlushErrorFile() {
	CompleteErrors.append(ErrorFile.str());
	ofstream Output(GetParameter("Error filename").data(),ios::app);
	Output << ErrorFile.str();
	Output.close();
	ErrorFile.str("");
}

void ProduceChargedMolfiles(string MolfileDirectory) {
	ostringstream Command;
	Command << GetParameter("perl directory") << " " << GetParameter("scripts directory") << "ChargeMolfiles.pl " << MolfileDirectory << " " <<  MolfileDirectory << "pH7/";
	system(Command.str().data());
}

bool PrintPathways(map<Species* , list<Pathway*> , std::less<Species*> >* InPathways, Species* Source) {
	string PathwayPath(FOutputFilepath());
	PathwayPath.append("Pathways/");
	PathwayPath.append(Source->GetData("NAME",STRING));
	PathwayPath.append(".txt");

	ofstream Output;
	if (!OpenOutput(Output,PathwayPath)) {
		return false;
	}
	
	double Temperature = atof(GetParameter("Temperature").data());
	bool PrintmMDeltaG = (GetParameter("print mM delta G").compare("1") == 0);
	Output << "Index|Length|Names|Intermediates|Reaction Entries|Reaction Operators|Reactions with names|Reactions with entries|Cumulative DeltaG|Cumulative Uncertainty|Overall reaction with entries|Overall reaction with names" << endl;

	int MaxPrintPathways = atoi(GetParameter("max pathways to print").data());
	map<Species* , list<Pathway*> , std::less<Species*> >::iterator MapIT = InPathways->begin();
	for(int i=0; i < int(InPathways->size()); i++) {
		Output << "Target compound: (" << MapIT->first->FEntry() << ") " << MapIT->first->GetData("NAME",STRING) << endl;
		vector<int> LengthDistribution;
		list<Pathway*>::iterator ListIT = MapIT->second.end();
		ListIT--;
		LengthDistribution.resize((*ListIT)->Length+1);
		for (int j=0; j <= (*ListIT)->Length; j++) {
			LengthDistribution[j] = 0;
		}
		ListIT = MapIT->second.begin();
		map<string , Reaction* , std::less<string> > OverallReactions;
		for (int j=0; j < int(MapIT->second.size()); j++) {
			LengthDistribution[(*ListIT)->Length]++;
			int k;
			string EquationType("name");
			if (j < MaxPrintPathways) {
				Output << j << "|" << (*ListIT)->Length << "|";
				for (k=0; k < (*ListIT)->Length; k++) {
					Output << (*ListIT)->Intermediates[k]->GetData("NAME",STRING) << ";";
				}
				Output << (*ListIT)->Intermediates[k]->GetData("NAME",STRING) << "|";
				for (k=0; k < (*ListIT)->Length; k++) {
					Output << (*ListIT)->Intermediates[k]->FEntry() << ";";
				}
				Output << (*ListIT)->Intermediates[k]->FEntry() << "|";
				for (k=0; k < (*ListIT)->Length-1; k++) {
					Output << (*ListIT)->Reactions[k]->FEntry() << ";";
				}
				Output << (*ListIT)->Reactions[k]->FEntry() << "|";
				for (k=0; k < (*ListIT)->Length-1; k++) {
					Output << (*ListIT)->Reactions[k]->CreateReactionEquation(EquationType) << ";";
				}
				Output << (*ListIT)->Reactions[k]->CreateReactionEquation(EquationType) << "|";
				for (k=0; k < (*ListIT)->Length-1; k++) {
					Output << (*ListIT)->Reactions[k]->CreateReactionEquation(EquationType.assign("entry")) << ";";
				}
				Output << (*ListIT)->Reactions[k]->CreateReactionEquation(EquationType.assign("entry")) << "|";
				double CumulativeEnergy = 0;
				Output << CumulativeEnergy;
				for (k=0; k < (*ListIT)->Length; k++) {
					if (PrintmMDeltaG) {
						CumulativeEnergy += (*ListIT)->Reactions[k]->FmMDeltaG(false);
					} else {
						CumulativeEnergy += (*ListIT)->Reactions[k]->FEstDeltaG();
					}
					Output << ";" << CumulativeEnergy;
				}
				Output << "|0" << endl;
			}/*
			Reaction* CumulativeReaction = new Reaction(0,Source->FMainData());
			for (k=0; k < (*ListIT)->Length; k++) {
				for (int l=0; l < (*ListIT)->Reactions[k]->FNumReactants(); l++) {
					CumulativeReaction->AddReactant((*ListIT)->Reactions[k]->GetReactant(l),(*ListIT)->Reactions[k]->GetReactantCoef(l),(*ListIT)->Reactions[k]->GetReactantCompartment(l));
				}			
				if (j < MaxPrintPathways) {
					CumulativeReaction->CalculateGroupChange();
					Output << ";" << CumulativeReaction->FEstDeltaGUncertainty();
					CumulativeReaction->ClearStructuralCues();
				}	
			}
			if (j < MaxPrintPathways) {
				Output << "|" << CumulativeReaction->CreateReactionEquation(EquationType.assign("entry")) << "|" << CumulativeReaction->CreateReactionEquation(EquationType.assign("name")) << endl;
			}
			CumulativeReaction->MakeCode("NAME",false);
			Reaction* Temp = OverallReactions[CumulativeReaction->FCode()];
			if (Temp == NULL) {
				OverallReactions[CumulativeReaction->FCode()] = CumulativeReaction;
				Temp = CumulativeReaction;
			} else {
				delete CumulativeReaction;
			}
			(*ListIT)->Index = j;
			Temp->AddPathway((*ListIT),false);*/
			ListIT++;
		}
		MapIT++;		/*
		Output << "Overall reactions:" << endl;
		map<string , Reaction* , std::less<string> >::iterator OverMapIT = OverallReactions.begin();
		for (int j=0; j < int(OverallReactions.size()); j++) {
			string Type("entry");
			Output << OverMapIT->second->CreateReactionEquation(Type) << "|";
			Output << OverMapIT->second->CreateReactionEquation(Type.assign("name")) << "|";
			if (PrintmMDeltaG) {
				Output << OverMapIT->second->FmMDeltaG(false) << "|";
			} else {
				Output << OverMapIT->second->FEstDeltaG() << "|";
			}
			for (int k=0; k < OverMapIT->second->FNumLinearPathways(); k++) {
				Output << OverMapIT->second->GetLinearPathway(k)->Index << ";";
			}
			Output << endl;
			OverMapIT++;
		}*/
		Output << "Pathway distribution:" << endl;
		for (int j=0; j < int(LengthDistribution.size()); j++) {
			Output << LengthDistribution[j] << "|";
		}
		Output << endl;
	}
	
	Output.close();
	return true;
}

string ConvertCycleIDToString(int InID) {
	ostringstream Result;
	if (InID == 0) {
		Result << "0";
		return Result.str();
	} else if (InID == 999999999) {
		Result << "W";
		return Result.str();
	} else {
		int Temp = ParseDigit(InID,9);
		if (Temp > 0) {
			Result << "B" << Temp << ";";
		}
		Temp = ParseDigit(InID,8);
		if (Temp > 0) {
			Result << "N" << Temp << ";";
		}
		Temp = ParseDigit(InID,7);
		if (Temp > 0) {
			Result << "F" << Temp << ";";
		}
		Temp = ParseDigit(InID,6);
		if (Temp > 0) {
			Result << "6" << Temp << ";";
		}
		Temp = ParseDigit(InID,5);
		if (Temp > 0) {
			Result << "5" << Temp << ";";
		}
		Temp = ParseDigit(InID,4);
		if (Temp > 0) {
			Result << "4" << Temp << ";";
		}
		Temp = ParseDigit(InID,3);
		if (Temp > 0) {
			Result << "H" << Temp << ";";
		}
		Temp = ParseDigit(InID,2);
		if (Temp > 0) {
			Result << "L" << Temp << ";";
		}
		Temp = ParseDigit(InID,1);
		if (Temp > 0) {
			Result << "3" << Temp << ";";
		}
	}
	return Result.str();
}

int ReadCompartmentFile() {
	DefaultCompartment = NULL;
	string Filename = GetParameter("input directory")+GetParameter("compartments file");
	
	ifstream Input;
	if (!OpenInput(Input,Filename)) {
		return FAIL;
	}

	string Temp = GetFileLine(Input); //Reading in the file header
	do {
		vector<string>* Strings = GetStringsFileline(Input, ";");
		if (Strings->size() >= 10) {
			CellCompartment* NewCompartment = new CellCompartment;
			NewCompartment->Index = int(CompartmentVector.size());
			NewCompartment->Abbreviation = (*Strings)[1];
			NewCompartment->Name = (*Strings)[2];
			NewCompartment->IonicStrength = atof((*Strings)[3].data());
			NewCompartment->pH = atof((*Strings)[4].data());
			NewCompartment->MaxConc = atof((*Strings)[5].data());
			NewCompartment->MinConc = atof((*Strings)[6].data());
			NewCompartment->DPsiCoef = atof((*Strings)[7].data());
			NewCompartment->DPsiConst = atof((*Strings)[8].data());
			if ((*Strings)[9].compare("1") == 0) {
				DefaultCompartment = NewCompartment;
			}
			if ((*Strings)[10].length() > 0) {
				vector<string>* StringsTwo = StringToStrings((*Strings)[10],"|");
				for (int i=0; i < int(StringsTwo->size()); i++) {
					vector<string>* StringsThree = StringToStrings((*StringsTwo)[i],":");
					if (StringsThree->size() == 3) {
						double* Range = new double[2];
						NewCompartment->SpecialConcRanges[(*StringsThree)[0]] = Range;
						Range[0] = atof((*StringsThree)[1].data());
						Range[1] = atof((*StringsThree)[2].data());
					}
					delete StringsThree;
				}
				delete StringsTwo;
			}


			CompartmentVector.push_back(NewCompartment);
			CompartmentsByAbbrev[NewCompartment->Abbreviation] = NewCompartment;
		}
		delete Strings;
	} while(!Input.eof());

	Input.close();
	return SUCCESS;
}

//Load the atom types such as C, N, H, O...
int LoadAtomTypes() {
	ifstream Input;
	string Filename = GetParameter("input directory")+GetParameter("atom types filename");
	
	if (!OpenInput(Input,Filename)) {
		return FAIL;
	}
	string Buff;
	int Mass;
	string AtomID;
	int Valence;
	int ExpectedBonds;
	AtomType* NewType;

	Input >> Buff >> Buff >> Buff >> Buff;

	do {
		AtomID.clear();
		Input >> AtomID;
		if (AtomID.length() == 0) {
			break;
		}
		Input >> Mass;
		Input >> Valence;
		Input >> ExpectedBonds;
		NewType = new AtomType(AtomID, Mass, Valence, ExpectedBonds, FNumAtomTypes());
		AddAtomType(NewType);
	} while (!Input.eof());

	Input.close();
	return SUCCESS;
};

void AddAtomType(AtomType* InType) {
	InType->SetIndex(FNumAtomTypes());
	AtomData.push_back(InType);
};

AtomType* GetAtomType(int InIndex) {
	return AtomData[InIndex];
};

AtomType* GetAtomType(const char* InID, bool CreateMissingAtoms) {
	for	(int i=0; i < FNumAtomTypes(); i++) {
		if (GetAtomType(i)->FID().compare(InID) == 0) {
			return GetAtomType(i);
		}
	}	
	
	if (CreateMissingAtoms) {
		FErrorFile() << InID << " is not a known atom type. Need to add this atomtype to list." << endl;
		FlushErrorFile();
		AtomType* NewAtomType = new AtomType(InID,1,1,1,FNumAtomTypes());
		AddAtomType(NewAtomType);
		return NewAtomType;
	}

	return NULL;
};

int FNumAtomTypes() {
	return int(AtomData.size());
};

CellCompartment* GetCompartment(const char* Abbrev) {
	string Temp(Abbrev);
	return CompartmentsByAbbrev[Temp];
}

CellCompartment* GetCompartment(int InIndex) {
	if (InIndex < 0) {
		return GetDefaultCompartment();
	} else if (InIndex >= int(CompartmentVector.size())) {
		return GetDefaultCompartment();
	}
	return CompartmentVector[InIndex];
}

CellCompartment* GetDefaultCompartment() {
	return DefaultCompartment;
}

int FNumCompartments() {
	return int(CompartmentVector.size());
}
//Allocating LinEquation and initiallizing all variables to their default values
LinEquation* InitializeLinEquation(const char* Meaning,double RHS,int Equality, int Type) {
	LinEquation* NewLinEquation = new LinEquation;
	NewLinEquation->Loaded = false;
	NewLinEquation->LoadedRightHandSide = FLAG;
	NewLinEquation->LoadedEqualityType = int(FLAG);
	NewLinEquation->ConstraintMeaning.assign(Meaning);
	NewLinEquation->RightHandSide = RHS;
	NewLinEquation->EqualityType = Equality;
	NewLinEquation->AssociatedSpecies = NULL;
	NewLinEquation->AssociatedReaction = NULL;
	NewLinEquation->Index = 0;
	NewLinEquation->ConstraintType = Type;
	NewLinEquation->Primal = true;
	NewLinEquation->DualVariable = NULL;
	return NewLinEquation;
}

//Allocating MFAVariable and initiallizing all variables to their default values
MFAVariable* InitializeMFAVariable() {
	MFAVariable* NewVariable = new MFAVariable;
	NewVariable->LoadedLowerBound = FLAG;
	NewVariable->LoadedUpperBound = FLAG;
	NewVariable->Loaded = false;
	NewVariable->Start = 0;
	NewVariable->Value = FLAG;
	NewVariable->Max = FLAG;
	NewVariable->Min = FLAG;
	NewVariable->UpperBound = FLAG;
	NewVariable->LowerBound = -FLAG;
	NewVariable->Binary = false;
	NewVariable->Integer = false;
	NewVariable->Mark = false;
	NewVariable->AssociatedSpecies = NULL;
	NewVariable->AssociatedReaction = NULL;
	NewVariable->AssociatedGene = NULL;
	NewVariable->AssociatedInterval = NULL;
	NewVariable->Type = -1;
	NewVariable->Compartment = -1;
	NewVariable->Index = -1;
	NewVariable->Primal = true;
	NewVariable->DualConstraint = NULL;
	NewVariable->LowerBoundDualVariable = NULL;
	NewVariable->UpperBoundDualVariable = NULL;
	return NewVariable;
}

MFAVariable* CloneVariable(MFAVariable* InVariable) {
	MFAVariable* NewVariable = InitializeMFAVariable();
	NewVariable->UpperBound = InVariable->UpperBound;
	NewVariable->LowerBound = InVariable->LowerBound;
	NewVariable->Binary = InVariable->Binary;
	NewVariable->Integer = InVariable->Integer;
	NewVariable->Mark = InVariable->Mark;
	NewVariable->AssociatedSpecies = InVariable->AssociatedSpecies;
	NewVariable->AssociatedReaction = InVariable->AssociatedReaction;
	NewVariable->AssociatedGene = InVariable->AssociatedGene;
	NewVariable->AssociatedInterval = InVariable->AssociatedInterval;
	NewVariable->Type = InVariable->Type;
	NewVariable->Compartment = InVariable->Compartment;
	NewVariable->Index = InVariable->Index;
	NewVariable->Primal = InVariable->Primal;
	NewVariable->DualConstraint = InVariable->DualConstraint;
	NewVariable->LowerBoundDualVariable = InVariable->LowerBoundDualVariable;
	NewVariable->UpperBoundDualVariable = InVariable->UpperBoundDualVariable;
	return NewVariable;
}

LinEquation* CloneLinEquation(LinEquation* InLinEquation) {
	LinEquation* NewEquation = InitializeLinEquation();

	NewEquation->RightHandSide = InLinEquation->RightHandSide;
	NewEquation->EqualityType = InLinEquation->EqualityType;
	NewEquation->ConstraintType = InLinEquation->ConstraintType;
	NewEquation->AssociatedSpecies = InLinEquation->AssociatedSpecies;
	NewEquation->AssociatedReaction = InLinEquation->AssociatedReaction;
	NewEquation->ConstraintMeaning = InLinEquation->ConstraintMeaning;
	NewEquation->Index = InLinEquation->Index;

	for (int i=0; i < int(InLinEquation->Variables.size()); i++) {
		NewEquation->Coefficient.push_back(InLinEquation->Coefficient[i]);
		NewEquation->Variables.push_back(InLinEquation->Variables[i]);
	}

	for (int i=0; i < int(InLinEquation->QuadOne.size()); i++) {
		NewEquation->QuadOne.push_back(InLinEquation->QuadOne[i]);
		NewEquation->QuadTwo.push_back(InLinEquation->QuadTwo[i]);
		NewEquation->QuadCoeff.push_back(InLinEquation->QuadCoeff[i]);
	}


	return NewEquation;
}

int ReadConstraints(const char* ConstraintFilename, struct ConstraintsToAdd* AddConstraints, struct ConstraintsToModify* ModConstraints) {
	
	string ConstraintsFilename(ConstraintFilename);
	if (ConstraintsFilename.length() == 0) {
		ConstraintsFilename = GetDatabaseDirectory(GetParameter("database"),"input directory")+GetParameter("user constraints filename");
		if (ConstraintsFilename.compare("none") == 0) {
			delete AddConstraints;
			delete ModConstraints;
			return FAIL;
		}
	}

	ifstream Input;
	if (!OpenInput(Input,ConstraintsFilename)) {
		delete AddConstraints;
		delete ModConstraints;
		return FAIL;
	}
		
	//Reading in file header
	string Temp = GetFileLine(Input);
	//Reading each constraint
	int Count = 0;
	do {
		vector<string>* Strings = GetStringsFileline(Input,";");
		if (Strings->size() > 0) {
			string action = (*Strings)[0].data();

			if (action.compare("Add") == 0) {
				if (Strings->size() > 2) {
					AddConstraints->RHS.push_back(atof((*Strings)[2].data()));
					if ((*Strings)[3].compare("<") == 0) {
						AddConstraints->EqualityType.push_back(GREATER);
					} else if ((*Strings)[3].compare(">") == 0) {
						AddConstraints->EqualityType.push_back(LESS);
					} else {
						AddConstraints->EqualityType.push_back(EQUAL);
					}
					vector<double> NewVector;
					AddConstraints->VarCoef.push_back(NewVector);
					vector<string> NewVectorTwo;
					AddConstraints->VarName.push_back(NewVectorTwo);
					vector<string> NewVectorThree;
					AddConstraints->VarCompartment.push_back(NewVectorThree);
					vector<int> NewVectorFour;
					AddConstraints->VarType.push_back(NewVectorFour);
					for (int i=2; i < int(Strings->size()); i++) {
						vector<string>* StringsTwo = StringToStrings((*Strings)[i],"|");
						if (StringsTwo->size() >= 4) {
							AddConstraints->VarName[Count].push_back((*StringsTwo)[0]);
							AddConstraints->VarCoef[Count].push_back(atof((*StringsTwo)[1].data()));
							AddConstraints->VarCompartment[Count].push_back((*StringsTwo)[2]);
							AddConstraints->VarType[Count].push_back(ConvertVariableType((*StringsTwo)[3]));
						}
						delete StringsTwo;
					}
					
					Count++;
				}
				delete Strings;
			} else if (action.compare("Modify") == 0) {
				if (Strings->size() > 2) {
					ModConstraints->ConstraintName.push_back((*Strings)[1].data());
					ModConstraints->RHS.push_back(atof((*Strings)[2].data()));
					if ((*Strings)[3].compare("<") == 0) {
						ModConstraints->EqualityType.push_back(GREATER);
					} else if ((*Strings)[3].compare(">") == 0) {
						ModConstraints->EqualityType.push_back(LESS);
					} else {
						ModConstraints->EqualityType.push_back(EQUAL);
					}
					vector<double> NewVector;
					ModConstraints->VarCoef.push_back(NewVector);
					vector<string> NewVectorTwo;
					ModConstraints->VarName.push_back(NewVectorTwo);
					vector<string> NewVectorThree;
					ModConstraints->VarCompartment.push_back(NewVectorThree);
					vector<int> NewVectorFour;
					ModConstraints->VarType.push_back(NewVectorFour);
					for (int i=2; i < int(Strings->size()); i++) {
						vector<string>* StringsTwo = StringToStrings((*Strings)[i],"|");
						if (StringsTwo->size() >= 4) {
							ModConstraints->VarName[Count].push_back((*StringsTwo)[0]);
							ModConstraints->VarCoef[Count].push_back(atof((*StringsTwo)[1].data()));
							ModConstraints->VarCompartment[Count].push_back((*StringsTwo)[2]);
							ModConstraints->VarType[Count].push_back(ConvertVariableType((*StringsTwo)[3]));
						}
						delete StringsTwo;
					}		
					Count++;
				}
			} else {
				FErrorFile() << action << " not recognized." << endl;
			}
		}
		delete Strings;
	} while (!Input.eof());

	Input.close();

	return SUCCESS;
}

//Translates from the MFA variable type string to the variable type index
int ConvertVariableType(string TypeName) {
	if (TypeName.compare("FLUX") == 0) {
		return FLUX;	
	} else if (TypeName.compare("FORWARD_FLUX") == 0) {
		return FORWARD_FLUX;	
	} else if (TypeName.compare("REVERSE_FLUX") == 0) {
		return REVERSE_FLUX;	
	} else if (TypeName.compare("REACTION_USE") == 0) {
		return REACTION_USE;	
	} else if (TypeName.compare("FORWARD_USE") == 0) {
		return FORWARD_USE;	
	} else if (TypeName.compare("REVERSE_USE") == 0) {
		return REVERSE_USE;
	} else if (TypeName.compare("DELTAG") == 0) {
		return DELTAG;	
	} else if (TypeName.compare("CONC") == 0) {
		return CONC;	
	} else if (TypeName.compare("LOG_CONC") == 0) {
		return LOG_CONC;	
	} else if (TypeName.compare("DELTAGF_ERROR") == 0) {
		return DELTAGF_ERROR;	
	} else if (TypeName.compare("DRAIN_FLUX") == 0) {
		return DRAIN_FLUX;		
	} else if (TypeName.compare("FORWARD_DRAIN_FLUX") == 0) {
		return FORWARD_DRAIN_FLUX;	
	} else if (TypeName.compare("REVERSE_DRAIN_FLUX") == 0) {
		return REVERSE_DRAIN_FLUX;	
	} else if (TypeName.compare("FORWARD_DRAIN_USE") == 0) {
		return FORWARD_DRAIN_USE;	
	} else if (TypeName.compare("REVERSE_DRAIN_USE") == 0) {
		return REVERSE_DRAIN_USE;	
	} else if (TypeName.compare("DRAIN_USE") == 0) {
		return DRAIN_USE;	
	} else if (TypeName.compare("COMPLEX_USE") == 0) {
		return COMPLEX_USE;
	} else if (TypeName.compare("GENE_USE") == 0) {
		return GENE_USE;
	} else if (TypeName.compare("INTERVAL_USE") == 0) {
		return INTERVAL_USE;
	} else if (TypeName.compare("REACTION_DELTAG_ERROR") == 0) {
		return REACTION_DELTAG_ERROR;	
	} else if (TypeName.compare("GENOME_CUTS") == 0) {
		return GENOME_CUTS;	
	} else if (TypeName.compare("DELTAGF_PERROR") == 0) {
		return DELTAGF_PERROR;
	} else if (TypeName.compare("DELTAGF_NERROR") == 0) {
		return DELTAGF_NERROR;
	} else if (TypeName.compare("POTENTIAL") == 0) {
		return POTENTIAL;
	} else if (TypeName.compare("SMALL_DELTAG_ERROR_USE") == 0) {
		return SMALL_DELTAG_ERROR_USE;
	} else if (TypeName.compare("LARGE_DELTAG_ERROR_USE") == 0) {
		return LARGE_DELTAG_ERROR_USE;
	} else if (TypeName.compare("LUMP_USE") == 0) {
		return LUMP_USE;
	}

	FErrorFile() << "Unrecognized MFA variable type: " << TypeName << endl;
	FlushErrorFile();
	return -1;
}

//Translates from the MFA variable type index to the variable type string
string ConvertVariableType(int Type) {
	string TypeName;
	
	if (Type == FLUX) {
		TypeName.assign("FLUX");	
	} else if (Type == FORWARD_FLUX) {
		TypeName.assign("FORWARD_FLUX");	
	} else if (Type == REVERSE_FLUX) {
		TypeName.assign("REVERSE_FLUX");	
	} else if (Type == REACTION_USE) {
		TypeName.assign("REACTION_USE");	
	} else if (Type == FORWARD_USE) {
		TypeName.assign("FORWARD_USE");	
	} else if (Type == REVERSE_USE) {
		TypeName.assign("REVERSE_USE");	
	} else if (Type == DELTAG) {
		TypeName.assign("DELTAG");	
	} else if (Type == CONC) {
		TypeName.assign("CONC");	
	} else if (Type == LOG_CONC) {
		TypeName.assign("LOG_CONC");	
	} else if (Type == DELTAGF_ERROR) {
		TypeName.assign("DELTAGF_ERROR");	
	} else if (Type == DRAIN_FLUX) {
		TypeName.assign("DRAIN_FLUX");	
	} else if (Type == FORWARD_DRAIN_FLUX) {
		TypeName.assign("FORWARD_DRAIN_FLUX");	
	} else if (Type == REVERSE_DRAIN_FLUX) {
		TypeName.assign("REVERSE_DRAIN_FLUX");	
	} else if (Type == FORWARD_DRAIN_USE) {
		TypeName.assign("FORWARD_DRAIN_USE");	
	} else if (Type == REVERSE_DRAIN_USE) {
		TypeName.assign("REVERSE_DRAIN_USE");	
	} else if (Type == DRAIN_USE) {
		TypeName.assign("DRAIN_USE");
	} else if (Type == COMPLEX_USE) {
		TypeName.assign("COMPLEX_USE");	
	} else if (Type == GENE_USE) {
		TypeName.assign("GENE_USE");	
	} else if (Type == INTERVAL_USE) {
		TypeName.assign("INTERVAL_USE");
	} else if (Type == REACTION_DELTAG_ERROR) {
		TypeName.assign("REACTION_DELTAG_ERROR");
	} else if (Type == GENOME_CUTS) {
		TypeName.assign("GENOME_CUTS");	
	} else if (Type == DELTAGF_PERROR) {
		TypeName.assign("DELTAGF_PERROR");	
	} else if (Type == DELTAGG_ENERGY) {
		TypeName.assign("DELTAGG_ENERGY");	
	} else if (Type == DELTAGF_NERROR) {
		TypeName.assign("DELTAGF_NERROR");
	} else if (Type == REACTION_DELTAG_PERROR) {
		TypeName.assign("REACTION_DELTAG_PERROR");
	} else if (Type == REACTION_DELTAG_NERROR) {
		TypeName.assign("REACTION_DELTAG_NERROR");
	} else if (Type == POTENTIAL) {
		TypeName.assign("POTENTIAL");
	} else if (Type == SMALL_DELTAG_ERROR_USE) {
		TypeName.assign("SMALL_DELTAG_ERROR_USE");
	} else if (Type == LARGE_DELTAG_ERROR_USE) {
		TypeName.assign("LARGE_DELTAG_ERROR_USE");
	} else if (Type == LUMP_USE) {
		TypeName.assign("LUMP_USE");
	} else {
		FErrorFile() << "Unrecognized MFA variable type number: " << Type << endl;
		FlushErrorFile();
	}

	return TypeName;
}

//Reads the special user bounds from the file specified in the parameters file
FileBounds* ReadBounds(string mediaName) {
	if (mediaName.length() == 0) {
		mediaName = GetParameter("user bounds filename");
	}
	if (mediaName.length() > 4 && mediaName.substr(mediaName.length()-4,4).compare(".txt") == 0) {
		mediaName = mediaName.substr(0,mediaName.length()-4);
	}
	StringDBObject* mediaObj = GetStringDB()->get_object("media",GetStringDB()->get_table("media")->get_id_column(),mediaName);
	FileBounds* InputBounds = new FileBounds;
	vector<string>* vars = mediaObj->getAll("VARIABLES");
	vector<string>* types = mediaObj->getAll("TYPES");
	vector<string>* mins = mediaObj->getAll("MIN");
	vector<string>* maxes = mediaObj->getAll("MAX");
	vector<string>* comps = mediaObj->getAll("COMPARTMENTS");
	for (int i=0; i < int(vars->size()); i++) {
		if ((*vars)[i].length() > 0) {
			InputBounds->VarName.push_back((*vars)[i]);
			InputBounds->VarCompartment.push_back((*comps)[i]);
			InputBounds->VarMax.push_back(atof((*maxes)[i].data()));
			InputBounds->VarMin.push_back(atof((*mins)[i].data()));
			InputBounds->VarType.push_back(ConvertVariableType((*types)[i]));
		}
	}
	return InputBounds;
}

void LoosenBounds(FileBounds* InBounds) {
	for(int i=0; i < int(InBounds->VarMax.size()); i++) {
		if (InBounds->VarMin[i] != 0) {
			InBounds->VarMin[i] = InBounds->VarMin[i]-BOUND_LOOSENING_FACTOR*fabs(InBounds->VarMin[i]);
			if (InBounds->VarMin[i] < -100) {
				InBounds->VarMin[i] = -100;
			}
		} else {
			//InBounds->VarMin[i] = -MFA_ZERO_TOLERANCE;
		}
		if (InBounds->VarMax[i] != 0) {
			InBounds->VarMax[i] = InBounds->VarMax[i]+BOUND_LOOSENING_FACTOR*fabs(InBounds->VarMax[i]);
			if (InBounds->VarMax[i] > 100) {
				InBounds->VarMax[i] = 100;
			}
		} else {
			//InBounds->VarMax[i] = MFA_ZERO_TOLERANCE;
		}
	}
}

//Loads the MFA parameters from the parameters file
OptimizationParameter* ReadParameters() {
	OptimizationParameter* NewParameters = new OptimizationParameter;
	NewParameters->GeneConstraints = false;
	NewParameters->AlternativeSolutionAlgorithm = false;
	NewParameters->DoMinimizeFlux = false;
	NewParameters->DetermineMinimalMedia = false;
	if (GetParameter("flux minimization").compare("1") == 0) {
		NewParameters->DoMinimizeFlux = true;
	}
	if (GetParameter("calculate flux sensitivity").compare("1") == 0) {
		NewParameters->DoCalculateSensitivity= true;
	}
	if (GetParameter("determine minimal required media").compare("1") == 0) {
		NewParameters->DetermineMinimalMedia= true;
	}

	//I load all parameters from the parameters map
	NewParameters->Temperature = atof(GetParameter("Temperature").data());
	NewParameters->MaxFlux = atof(GetParameter("Max flux").data());
	NewParameters->MinFlux = atof(GetParameter("Min flux").data());
	if (GetParameter("Max deltaG error").compare("DEFAULT") == 0) {
		NewParameters->MaxError = FLAG;
	} else {
		NewParameters->MaxError = atof(GetParameter("Max deltaG error").data());
	}
	
	NewParameters->SimpleThermoConstraints = (GetParameter("simple thermo constraints").compare("1") == 0);
	NewParameters->GapFilling = (GetParameter("Perform gap filling").compare("1") == 0);
	NewParameters->GapGeneration = (GetParameter("Perform gap generation").compare("1") == 0);
	NewParameters->MaxDrainFlux = atof(GetParameter("Default max drain flux").data());
	NewParameters->MinDrainFlux = atof(GetParameter("Default min drain flux").data());
	NewParameters->MaxPotential = atof(GetParameter("Max potential").data());
	NewParameters->MinPotential = atof(GetParameter("Min potential").data());
	NewParameters->OptimalObjectiveFraction = atof(GetParameter("Constrain objective to this fraction of the optimal value").data());
	NewParameters->SolutionSizeInterval = atoi(GetParameter("Recursive MILP solution size interval").data());
	NewParameters->RecursiveMILPSolutionLimit = atoi(GetParameter("Recursive MILP solution limit").data());
	NewParameters->ErrorMult = atoi(GetParameter("error multiplier").data());
	NewParameters->AlwaysReoptimizeOriginalObjective = (NewParameters->OptimalObjectiveFraction<1);

	NewParameters->MassBalanceConstraints = (GetParameter("Mass balance constraints").compare("1") == 0);
	NewParameters->DecomposeReversible = (GetParameter("Decompose reversible reactions").compare("1") == 0);
	NewParameters->ThermoConstraints = (GetParameter("Thermodynamic constraints").compare("1") == 0);
	NewParameters->CheckPotentialConstraints = (GetParameter("Check potential constraints feasibility").compare("1") == 0);
	NewParameters->ReactionsUse = (GetParameter("Reactions use variables").compare("1") == 0);
	NewParameters->DeltaGError = (GetParameter("Account for error in delta G").compare("1") == 0);
	NewParameters->LoadTightBounds = (GetParameter("Load tight bounds").compare("1") == 0);
	NewParameters->AllReactionsUse = (GetParameter("Force use variables for all reactions").compare("1") == 0);
	NewParameters->LoadForeignDB = (GetParameter("Load foreign reaction database").compare("1") == 0);
	NewParameters->MinimizeForeignReactions = (GetParameter("Minimize the number of foreign reactions").compare("1") == 0);
	NewParameters->ReoptimizeSubOptimalObjective = (GetParameter("Reoptimize suboptimal objective during recursive MILP").compare("1") == 0);
	NewParameters->DetermineCoEssRxns = (GetParameter("find coessential reactions for nonviable deletions").compare("1") == 0);

	NewParameters->AddLumpedReactions = (GetParameter("Add lumped reactions").compare("1") == 0);
	NewParameters->AllDrainUse = (GetParameter("Force use variables for all drain fluxes").compare("1") == 0);
	NewParameters->DrainUseVar = (GetParameter("Add use variables for any drain fluxes").compare("1") == 0);
	NewParameters->DecomposeDrain = (GetParameter("Decompose reversible drain fluxes").compare("1") == 0);
	NewParameters->AllReversible = (GetParameter("Make all reactions reversible in MFA").compare("1") == 0);
	NewParameters->OptimizeMetabolitesWhenZero = (GetParameter("optimize metabolite production if objective is zero").compare("1") == 0);
	NewParameters->RelaxIntegerVariables = (GetParameter("relax integer variables when possible").compare("1") == 0);

	NewParameters->ExcludeCurrentMedia = (GetParameter("exclude input media components from media optimization").compare("1") == 0);
	NewParameters->IncludeDeadEnds = (GetParameter("uptake dead end compounds during media optimization").compare("1") == 0);
	NewParameters->DeadEndCoefficient = atof(GetParameter("coefficient for dead end compound uptake").data());
	NewParameters->PerformSingleKO = (GetParameter("perform single KO experiments").compare("1") == 0);
	NewParameters->PerformIntervalKO = (GetParameter("perform interval KO experiments").compare("1") == 0);
	NewParameters->PerformIntervalStrainExperiments = (GetParameter("perform interval strain experiments").compare("1") == 0);
	NewParameters->PerformGeneStrainExperiments = (GetParameter("perform gene strain experiments").compare("1") == 0);
	NewParameters->OptimizeMediaWhenZero = (GetParameter("optimize media when objective is zero").compare("1") == 0);
	NewParameters->CheckReactionEssentiality  = (GetParameter("check for reaction essentiality").compare("1") == 0);
	NewParameters->DoFluxCouplingAnalysis  = (GetParameter("do flux coupling analysis").compare("1") == 0);
	NewParameters->DoMILPCoessentiality  = (GetParameter("do MILP coessentiality analysis").compare("1") == 0);
	NewParameters->DoMinimizeReactions  = (GetParameter("Minimize reactions").compare("1") == 0);
	NewParameters->DoRecursiveMILPStudy = (GetParameter("do recursive MILP study").compare("1") == 0);
	NewParameters->GeneOptimization = (GetParameter("optimize organism genes").compare("1") == 0);
	NewParameters->IntervalOptimization = (GetParameter("optimize organism intervals").compare("1") == 0);
	NewParameters->DeletionOptimization = (GetParameter("optimize deletions").compare("1") == 0);
	NewParameters->ReactionErrorUseVariables = (GetParameter("include error use variables").compare("1") == 0);
	NewParameters->MinimizeDeltaGError = (GetParameter("minimize deltaG error").compare("1") == 0);
	NewParameters->PrintSolutions = true;
	NewParameters->ClearSolutions = true;

	string ReactionKO = GetParameter("Reactions to knockout");
	if (ReactionKO.length() > 0 && ReactionKO.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ReactionKO,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			NewParameters->KOReactions.push_back((*Strings)[i]);
		}
		delete Strings;
	}

	string PCompounds = GetParameter("Compounds to have potential constraint");
	NewParameters->PotentialEnergyCompoundsInclusive = true;
	if (PCompounds.length() == 0 || PCompounds.compare("ALL") == 0) {
		NewParameters->PotentialEnergyCompoundsInclusive = false;
		PCompounds = GetParameter("Compounds excluded from potential constraints");
		if (PCompounds.length() > 0 && PCompounds.compare("none") != 0) {
			if (PCompounds.compare("NoPConstraintList.txt") == 0) {
				string PConsFilename = GetDatabaseDirectory(GetParameter("database"),"input directory")+"NoPConstraintList.txt";
				vector<string> PCompoundsList = ReadStringsFromFile(PConsFilename);
				for (int i=0; i < int(PCompoundsList.size()); i++) {
					NewParameters->PotentialEnergyCompounds[PCompoundsList[i]] = true;
				}
			} else {
				vector<string>* Strings = StringToStrings(PCompounds,";,");
				for (int i=0; i < int(Strings->size()); i++) {
					NewParameters->PotentialEnergyCompounds[(*Strings)[i]] = true;
				}
				delete Strings;
			}
		}
	} else if (PCompounds.compare("PConstraintList.txt") == 0) {
		string PConsFilename = GetDatabaseDirectory(GetParameter("database"),"input directory")+GetParameter("Compounds to have potential constraint");
		vector<string> PCompoundsList = ReadStringsFromFile(PConsFilename);
		for (int i=0; i < int(PCompoundsList.size()); i++) {
			NewParameters->PotentialEnergyCompounds[PCompoundsList[i]] = true;
		}
	} else {
		vector<string>* Strings = StringToStrings(PCompounds,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			NewParameters->PotentialEnergyCompounds[(*Strings)[i]] = true;
		}
		delete Strings;
	}

	ReactionKO = GetParameter("Unremovable media components");
	if (ReactionKO.length() > 0 && ReactionKO.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ReactionKO,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			NewParameters->UnremovableMedia.push_back((*Strings)[i]);
		}
		delete Strings;
	}

	ReactionKO = GetParameter("Reactions that should always be active");
	if (ReactionKO.length() > 0 && ReactionKO.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ReactionKO,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			if ((*Strings)[i].length() > 0) {
				if ((*Strings)[i].substr(0,1).compare("+") == 0) {
					NewParameters->AlwaysActiveReactions[(*Strings)[i].substr(1,(*Strings)[i].length()-1)] = 1;
				} else if ((*Strings)[i].substr(0,1).compare("-") == 0) {
					NewParameters->AlwaysActiveReactions[(*Strings)[i].substr(1,(*Strings)[i].length()-1)] = -1;
				} else {
					NewParameters->AlwaysActiveReactions[(*Strings)[i]] = 0;
				}
			}
		}
		delete Strings;
	}

	ReactionKO = GetParameter("Reactions that are always blocked");
	if (ReactionKO.length() > 0 && ReactionKO.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ReactionKO,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			if ((*Strings)[i].length() > 0) {
				if ((*Strings)[i].substr(0,1).compare("+") == 0) {
					NewParameters->BlockedReactions[(*Strings)[i].substr(1,(*Strings)[i].length()-1)] = 1;
				} else if ((*Strings)[i].substr(0,1).compare("-") == 0) {
					NewParameters->BlockedReactions[(*Strings)[i].substr(1,(*Strings)[i].length()-1)] = -1;
				} else {
					NewParameters->BlockedReactions[(*Strings)[i]] = 0;
				}
			}
		}
		delete Strings;
	}

	ReactionKO = GetParameter("Genes to knockout");
	if (ReactionKO.length() > 0 && ReactionKO.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ReactionKO,";,");
		for (int i=0; i < int(Strings->size()); i++) {
			NewParameters->KOGenes.push_back((*Strings)[i]);
		}
		delete Strings;
	}

	string CoessentialityTargets = GetParameter("target reactions for coessentiality analysis");
	if (CoessentialityTargets.length() > 0 && CoessentialityTargets.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(CoessentialityTargets,";");
		for (int i=0; i < int(Strings->size()); i++) {
			vector<string>* StringsTwo = StringToStrings((*Strings)[i],",");
			if (StringsTwo->size() >= 1) {
				vector<string> TempList;
				for (int j=0; j < int(StringsTwo->size()); j++) {
					TempList.push_back((*StringsTwo)[j]);
				}
				NewParameters->TargetReactions.push_back(TempList);
			}
			delete StringsTwo;
		}
		delete Strings;
	}

	//Loading FBA experiment data from file if specified
	if (GetParameter("FBA experiment file").length() > 0 && ConvertToLower(GetParameter("FBA experiment file")).compare("none") != 0) {
		vector<string> lines = ReadStringsFromFile(GetDatabaseDirectory(GetParameter("database"),"output directory")+GetParameter("output folder")+GetParameter("FBA experiment file"),false);
		string temp = "";
		for (int i=1; i < int(lines.size()); i++) {
			if (temp.length() > 0) {
				temp.append(";");
			}
			vector<string>* strings = StringToStrings(lines[i],"\t");
			if (strings != NULL && strings->size() >= 3) {
				(*strings)[1] = StringReplace((*strings)[1].data(),";",",");
				temp.append((*strings)[0]+":"+(*strings)[2]+":"+(*strings)[1]);
			}
			delete strings;
		}
		SetParameter("deletion experiments",temp.data());
	
	}
	//Loading FBA experiment data from parameter
	if (GetParameter("deletion experiments").length() > 0 && ConvertToLower(GetParameter("deletion experiments")).compare("none") != 0) {
		vector<string>* strings = StringToStrings(GetParameter("deletion experiments"),";");
		for (int i=0; i < int(strings->size()); i++) {
			if ((*strings)[i].length() > 0) {
				vector<string>* stringsTwo = StringToStrings((*strings)[i],":");
				if (stringsTwo != NULL && stringsTwo->size() >= 3) {
					NewParameters->labels.push_back((*stringsTwo)[0]);
					NewParameters->mediaConditions.push_back((*stringsTwo)[1]);
					vector<string>* stringsThree = StringToStrings((*stringsTwo)[2],",");
					vector<string> newSet;
					for (int j=0; j < int(stringsThree->size()); j++) {
						newSet.push_back((*stringsThree)[j]);
					}
					NewParameters->KOSets.push_back(newSet);
					delete stringsTwo;
					delete stringsThree;
				}
			}
		}
		delete strings;
	}

	string RecursiveMILPVariables = GetParameter("recursive MILP variables");
	if (RecursiveMILPVariables.length() > 0 && RecursiveMILPVariables.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(RecursiveMILPVariables,";");
		for (int i=0; i < int(Strings->size()); i++) {
			int Type = ConvertVariableType((*Strings)[i]);
			if (Type != -1) {
				NewParameters->RecursiveMILPTypes.push_back(Type);
			}
		}
		delete Strings;
	}

	string AnalysisString = GetParameter("exploration analysis parameters");
	if (AnalysisString.length() > 0) {
		vector<string>* Strings = StringToStrings(AnalysisString,";");
		for (int i=0; i < int(Strings->size()); i++) {
			vector<string>* StringsTwo = StringToStrings((*Strings)[i],"<()[]+:");
			if (StringsTwo->size() >= 6 && int(StringsTwo->size())%3==0) {
				NewParameters->ExplorationMin.push_back(atof((*StringsTwo)[0].data()));
				NewParameters->ExplorationIteration.push_back(atof((*StringsTwo)[StringsTwo->size()-1].data()));
				NewParameters->ExplorationMax.push_back(atof((*StringsTwo)[StringsTwo->size()-2].data()));
				vector<string> NewNames;
				vector<int> NewTypes;
				vector<double> NewCoefs;
				for (int j=1; j < int(StringsTwo->size()-2); j+=3) {
					NewNames.push_back((*StringsTwo)[j+1]);
					NewTypes.push_back(atoi((*StringsTwo)[j+2].data()));
					NewCoefs.push_back(atof((*StringsTwo)[j].data()));
				}
				NewParameters->ExplorationNames.push_back(NewNames);
				NewParameters->ExplorationTypes.push_back(NewTypes);
				NewParameters->ExplorationCoefficients.push_back(NewCoefs);
			}
			delete StringsTwo;
		}
		delete Strings;
	}

	string ParameterValue = GetParameter("exchange species");
	if (ParameterValue.compare("none") != 0) {
		vector<string>* Strings = StringToStrings(ParameterValue,";");
		for (int i=0; i < int(Strings->size()); i++) {
			vector<string>* StringsTwo = StringToStrings((*Strings)[i],":");
			int Compartment = GetDefaultCompartment()->Index;
			if ((*StringsTwo)[0].substr((*StringsTwo)[0].length()-1,1).compare("]") == 0) {
				Compartment = GetCompartment((*StringsTwo)[0].substr((*StringsTwo)[0].length()-2,1).data())->Index;
				(*StringsTwo)[0] = (*StringsTwo)[0].substr(0,(*StringsTwo)[0].length()-3);
			}
			NewParameters->ExchangeSpecies.push_back((*StringsTwo)[0]);
			NewParameters->ExchangeComp.push_back(Compartment);
			if (StringsTwo->size() >= 3) {
				NewParameters->ExchangeMin.push_back(atof((*StringsTwo)[1].data()));
				NewParameters->ExchangeMax.push_back(atof((*StringsTwo)[2].data()));
			} else {
				NewParameters->ExchangeMin.push_back(NewParameters->MinDrainFlux);
				NewParameters->ExchangeMax.push_back(NewParameters->MaxDrainFlux);
			}
			delete StringsTwo;
		}
		delete Strings;
	}
	
	string ConditionsFile = GetParameter("Regulation conditions");
	if (FileExists(ConditionsFile)) {
		vector< vector<string> >* LoadedData = LoadMultipleColumnFile(ConditionsFile,"\t");
		for (int i=0; i < int(LoadedData->size()); i++) {
			if ((*LoadedData)[i].size() >= 2) {
				NewParameters->Conditions[(*LoadedData)[i][0]] = atof((*LoadedData)[i][1].data());
			}
		}
		delete LoadedData;
	}

	// Loading user-set constraints
	string Filename = GetDatabaseDirectory(GetParameter("database"),"input directory")+GetParameter("user constraints filename");
	
	NewParameters->ModConstraints = new ConstraintsToModify;
	NewParameters->AddConstraints = new ConstraintsToAdd;

	if (Filename.compare("none") != 0) {
		int Status = ReadConstraints(Filename.data(), (NewParameters->AddConstraints), (NewParameters->ModConstraints));
	}

	//Loading user-set bounds on variables
	Filename = GetParameter("user bounds filename");
	NewParameters->UserBounds = NULL;
	if (Filename.compare("none") != 0) {
		NewParameters->UserBounds = ReadBounds(Filename.data());
	}
	NewParameters->DefaultExchangeComp = GetCompartment(GetParameter("default exchange compartment").data())->Index;

	//Some parameter settings require other settings to be a certain way... this function ensures that all parameters are set properly
	RectifyOptimizationParameters(NewParameters);

	return NewParameters;
}

void ClearParameters(OptimizationParameter* InParameters) {
	if (InParameters->UserBounds != NULL) {
		delete InParameters->UserBounds;
	}
	if (InParameters->AddConstraints != NULL) {
		delete InParameters->AddConstraints;
	}
	if (InParameters->ModConstraints != NULL) {
		delete InParameters->ModConstraints;
	}
	delete InParameters;
}

//Some parameter settings require other settings to be a certain way... this function ensures that all parameters are set properly
void RectifyOptimizationParameters(OptimizationParameter* InParameters){
	if (GetParameter("classify model genes").compare("1") == 0) {
		if (GetParameter("Combinatorial deletions").compare("none") == 0) {
			SetParameter("Combinatorial deletions","1");
		}
		SetParameter("find tight bounds","1");
	}
	//If the uptake of atoms is restricted, uptake fluxes must be decomposed
	if (GetParameter("uptake limits").compare("none") != 0) {
		InParameters->DecomposeDrain = true;
	}
	if (InParameters->IntervalOptimization || InParameters->GeneOptimization || GetParameter("Add regulatory constraint to problem").compare("1") == 0) {
		InParameters->GeneConstraints = true;
	}
	if (GetParameter("Add regulatory constraint to problem").compare("1") == 0) {
		InParameters->DrainUseVar = true;
		InParameters->AllDrainUse = true;
	}
	if (InParameters->GeneConstraints) {
		InParameters->AllReactionsUse = true;
	}
	if (InParameters->GeneConstraints || InParameters->ThermoConstraints || (InParameters->LoadForeignDB && InParameters->MinimizeForeignReactions)) {
		InParameters->ReactionsUse = true;
	}
	if (InParameters->ReactionsUse) {
		InParameters->DecomposeReversible = true;
	}
	if (InParameters->DrainUseVar) {
		InParameters->DecomposeDrain = true;
	}
	if (InParameters->DoMinimizeFlux) {
		InParameters->DecomposeReversible = true;
	}
	if (InParameters->DetermineMinimalMedia) {
		InParameters->DecomposeDrain = true;
		InParameters->AllDrainUse = true;
		InParameters->DrainUseVar = true;
		InParameters->MaxDrainFlux = 10000;
		InParameters->MinDrainFlux = -10000;
	}
}

void AddUnlabeledFormula(Species* InSpecies) {
	UnlabeledFormulas[InSpecies->GetUnlabeledFormula()].push_back(InSpecies);
}

void PrintUnlabeledFormulas() {
	bool* Marks = new bool[UnlabeledFormulas.size()];
	for (int i=0; i < int(UnlabeledFormulas.size()); i++) {
		Marks[i] = false;
	}
	int Count = 0;
	FLogFile() << "Large cycles" << endl;
	for (map< string, vector<Species*>, std::less<string> >::iterator MapIT = UnlabeledFormulas.begin(); MapIT != UnlabeledFormulas.end(); MapIT++) {
		if (!Marks[Count] && MapIT->first.find("L") != MapIT->first.npos) {
			FLogFile() << MapIT->first << ";" << MapIT->second.size() << ";";
			for (int i=0; i< int(MapIT->second.size()); i++) {
				FLogFile() << MapIT->second[i]->GetData("FILENAME",STRING) << "|";
			}
			FLogFile() << endl;
			Marks[Count] = true;
		}
		Count++;
	}
	Count = 0;
	FLogFile() << "Psuedoatoms" << endl;
	for (map< string, vector<Species*>, std::less<string> >::iterator MapIT = UnlabeledFormulas.begin(); MapIT != UnlabeledFormulas.end(); MapIT++) {
		if (!Marks[Count] && MapIT->first.find_first_of("*RX") != MapIT->first.npos) {
			FLogFile() << MapIT->first << ";" << MapIT->second.size() << ";";
			for (int i=0; i< int(MapIT->second.size()); i++) {
				FLogFile() << MapIT->second[i]->GetData("FILENAME",STRING) << "|";
			}
			FLogFile() << endl;
			Marks[Count] = true;
		}
		Count++;
	}
	Count = 0;
	FLogFile() << "Organics" << endl;
	for (map< string, vector<Species*>, std::less<string> >::iterator MapIT = UnlabeledFormulas.begin(); MapIT != UnlabeledFormulas.end(); MapIT++) {
		if (!Marks[Count] && MapIT->first.find_first_not_of("0123456789CNOSHP") != MapIT->first.npos) {
			FLogFile() << MapIT->first << ";" << MapIT->second.size() << ";";
			for (int i=0; i< int(MapIT->second.size()); i++) {
				FLogFile() << MapIT->second[i]->GetData("FILENAME",STRING) << "|";
			}
			FLogFile() << endl;
			Marks[Count] = true;
		}
		Count++;
	}
	Count = 0;
	FLogFile() << "Metals" << endl;
	for (map< string, vector<Species*>, std::less<string> >::iterator MapIT = UnlabeledFormulas.begin(); MapIT != UnlabeledFormulas.end(); MapIT++) {
		if (!Marks[Count]) {
			FLogFile() << MapIT->first << ";" << MapIT->second.size() << ";";
			for (int i=0; i< int(MapIT->second.size()); i++) {
				FLogFile() << MapIT->second[i]->GetData("FILENAME",STRING) << "|";
			}
			FLogFile() << endl;
			Marks[Count] = true;
		}
		Count++;
	}
	delete [] Marks;
}

vector<string> CombineMaps(vector<string> Maps) {
	//Converting the input map strings into map data structures
	vector<MapData*> AllMaps;
	for (int i=0; i < int(Maps.size()); i++) {
		AllMaps.push_back(ParseMapString(Maps[i]));
	}

	//ReactantSourceData[GLOBAL REACTANT INDEX][0] = REACTANT MAP INDEX
	//ReactantSourceData[GLOBAL REACTANT INDEX][0] = LOCAL REACTANT INDEX
	vector< vector<int> > ReactantSourceData;
	//ProductSourceData[GLOBAL PRODUCT INDEX][0] = PRODUCT MAP INDEX
	//ProductSourceData[GLOBAL PRODUCT INDEX][0] = LOCAL PRODUCT INDEX
	vector< vector<int> > ProductSourceData;
	//Reactants[REACTANT DBID][REACTANT DEGENERATE STRING][DEGENERATE REACTION INDEX] = GLOBAL REACTANT INDEX
	map<string, map<string, vector<int> , std::less<string> > , std::less<string> > Reactants;
	//Products[PRODUCT DBID][PRODUCT DEGENERATE STRING][DEGENERATE PRODUCT INDEX] = GLOBAL PRODUCT INDEX
	map<string, map<string, vector<int> , std::less<string> > , std::less<string> > Products;
	//Filling the reactants and products maps with data
	for (int i=0; i < int(AllMaps.size()); i++) {
		//ProductDegenerateStringData[LOCAL PRODUCT INDEX][PRODUCT ATOM INDEX] = LOCAL REACTANT INDEX
		vector<vector<int> > ProductDegenerateStringData(AllMaps[i]->Products.size());
		//ProductDegenerateAtomData[LOCAL PRODUCT INDEX][PRODUCT ATOM INDEX] = REACTANT ATOM INDEX
		vector<vector<int> > ProductDegenerateAtomData(AllMaps[i]->Products.size());
		for (int k=0; k < int(AllMaps[i]->Reactants.size()); k++) {
			//Creating the degenerate string for the reactant
			string DegenerateString;
			int LastProduct = -1;
			for (int j=0; j < int(AllMaps[i]->AtomToProducts[k].size()); j++) {
				if (AllMaps[i]->AtomToProducts[k][j] != LastProduct) {
					LastProduct = AllMaps[i]->AtomToProducts[k][j];
					if (j > 0) {
						DegenerateString.append(";");
					}
					DegenerateString.append(AllMaps[i]->Products[AllMaps[i]->AtomToProducts[k][j]]);
					DegenerateString.append(":");
				} else {
					if (j > 0) {
						DegenerateString.append(",");
					}
				}
				DegenerateString.append(itoa(AllMaps[i]->AtomToAtom[k][j]));
				for (int m=int(ProductDegenerateStringData[AllMaps[i]->AtomToProducts[k][j]].size()); m <= AllMaps[i]->AtomToAtom[k][j]; m++) {
					ProductDegenerateStringData[AllMaps[i]->AtomToProducts[k][j]].push_back(-1);
					ProductDegenerateAtomData[AllMaps[i]->AtomToProducts[k][j]].push_back(-1);
				}
				ProductDegenerateStringData[AllMaps[i]->AtomToProducts[k][j]][AllMaps[i]->AtomToAtom[k][j]] = k;
				ProductDegenerateAtomData[AllMaps[i]->AtomToProducts[k][j]][AllMaps[i]->AtomToAtom[k][j]] = j;
			}
			vector<int> Temp(2);
			Temp[0] = i;
			Temp[1] = k;
			ReactantSourceData.push_back(Temp);
			Reactants[AllMaps[i]->Reactants[k]][DegenerateString].push_back(int(ReactantSourceData.size()-1));
		}
		for (int k=0; k < int(AllMaps[i]->Products.size()); k++) {
			//Creating the degenerate string for the product
			string DegenerateString;
			int LastProduct = -1;
			for (int j=0; j < int(ProductDegenerateStringData[k].size()); j++) {
				if (ProductDegenerateStringData[k][j] != -1) {			
					if (ProductDegenerateStringData[k][j] != LastProduct) {
						LastProduct = ProductDegenerateStringData[k][j];
						if (j > 0) {
							DegenerateString.append(";");
						}
						DegenerateString.append(AllMaps[i]->Reactants[ProductDegenerateStringData[k][j]]);
						DegenerateString.append(":");
					} else {
						if (j > 0) {
							DegenerateString.append(",");
						}
					}
					DegenerateString.append(itoa(ProductDegenerateAtomData[k][j]));
				}
			}
			//Saving the product source data into the source data vector and in the product map
			vector<int> Temp(2);
			Temp[0] = i;
			Temp[1] = k;
			ProductSourceData.push_back(Temp);
			Products[AllMaps[i]->Products[k]][DegenerateString].push_back(int(ProductSourceData.size()-1));
		}
	}

	//UniversalReactants[COMBINED MAP LOCAL REACTANT INDEX] = REACTANT DBID
	vector<string> UniversalReactants;
	//UniversalProducts[COMBINED MAP LOCAL PRODUCT INDEX] = PRODUCT DBID
	vector<string> UniversalProducts;
	//ProductIndecies[PRODUCT TYPE][PRODUCT TYPE INDEX] = PRODUCT GLOBAL INDEX
	vector< vector<int> > ProductIndecies;
	//ReactantIndecies[REACTANT TYPE][REACTANT TYPE INDEX] = REACTANT GLOBAL INDEX
	vector< vector<int> > ReactantIndecies;
	//ReactantType[REACTANT GLOBAL INDEX] = REACTANT TYPE
	vector<int> ReactantType(ReactantSourceData.size());
	//ReactantTypeIndex[REACTANT GLOBAL INDEX] = REACTANT TYPE INDEX
	vector<int> ReactantTypeIndex(ReactantSourceData.size());
	//ReactantToProductMap[REACTANT TYPE][REACTANT TYPE INDEX] = PRODUCT GLOBAL INDEX
	vector< vector<int> > ReactantToProductMap;
	//AllProductToReactantMaps[PRODUCT TYPE][PRODUCT TYPE INDEX][SOLUTION INDEX] = REACTANT GLOBAL INDEX
	vector< vector< vector<int> > > AllProductToReactantMaps;
	
	//Intializing all reactant vectors
	for (map<string, map<string, vector<int> , std::less<string> > , std::less<string> >::iterator MapIT=Reactants.begin(); MapIT != Reactants.end(); MapIT++) {
		//CurrentTypeIndecies[REACTANT TYPE INDEX] = REACTANT GLOBAL INDEX
		vector<int> CurrentTypeIndecies;
		//CurrentTypeReactantToProductMap[REACTANT TYPE INDEX] = -1 (intializing this vector to -1)
		vector<int> CurrentTypeReactantToProductMap;
		//NumResidual = NUMBER OF REACTANTS OF THIS TYPE THAT DONOT HAVE CORRESPONDING PRODUCTS OF AN IDENTICAL TYPE
		int NumResidual = 0;
		for (map<string, vector<int>, std::less<string> >::iterator MapITT=MapIT->second.begin(); MapITT != MapIT->second.end(); MapITT++) {
			NumResidual += int(MapITT->second.size());
			for (int i=0; i < int(MapITT->second.size()); i++) {
				ReactantType[MapITT->second[i]] = int(ReactantIndecies.size());
				ReactantTypeIndex[MapITT->second[i]] = int(CurrentTypeIndecies.size());
				CurrentTypeIndecies.push_back(MapITT->second[i]);
				CurrentTypeReactantToProductMap.push_back(-1);
			}
		}
		if (Products.count(MapIT->first) != 0) {
			for (map<string, vector<int>, std::less<string> >::iterator MapITT=Products[MapIT->first].begin(); MapITT != Products[MapIT->first].end(); MapITT++) {
				NumResidual -= int(MapITT->second.size());
			}
		}
		//Storing the appropriate number of this type of reactant DBID
		for (int i=0; i < NumResidual; i++) {
			UniversalReactants.push_back(MapIT->first);
		}
		ReactantIndecies.push_back(CurrentTypeIndecies);
		ReactantToProductMap.push_back(CurrentTypeReactantToProductMap);
	}
	//Initializing all product vectors and generating all alternative product->reactant mapping alternatives
	for (map<string, map<string, vector<int> , std::less<string> > , std::less<string> >::iterator MapIT=Products.begin(); MapIT != Products.end(); MapIT++) {
		//CurrentTypeMapping[PRODUCT TYPE INDEX][SOLUTION INDEX] = REACTANT GLOBAL INDEX
		vector< vector<int> > CurrentTypeMapping;
		//ProductDegenerateTypes[PRODUCT TYPE INDEX] = PRODUCT DEGENERATE CLASS
		vector<int> ProductDegenerateTypes;
		int DegenerateClass = 0;
		//CurrentTypeIndecies[PRODUCT TYPE INDEX] = PRODUCT GLOBAL INDEX
		vector<int> CurrentTypeIndecies;
		int NumResidual = 0;
		for (map<string, vector<int>, std::less<string> >::iterator MapITT=MapIT->second.begin(); MapITT != MapIT->second.end(); MapITT++) {
			NumResidual += int(MapITT->second.size());
			for (int i=0; i < int(MapITT->second.size()); i++) {
				vector<int> DefaultMapping(1,-1);
				CurrentTypeMapping.push_back(DefaultMapping);
				CurrentTypeIndecies.push_back(MapITT->second[i]);
				ProductDegenerateTypes.push_back(DegenerateClass);
			}
			DegenerateClass++;
		}
		if (Reactants.count(MapIT->first) != 0) {
			vector<int> ReactantGlobalIndecies;
			vector<int> ReactantDegenerateTypes;
			DegenerateClass = 0;
			for (map<string, vector<int>, std::less<string> >::iterator MapITT=Reactants[MapIT->first].begin(); MapITT != Reactants[MapIT->first].end(); MapITT++) {
				NumResidual -= int(MapITT->second.size());
				for (int i=0; i < int(MapITT->second.size()); i++) {
					ReactantGlobalIndecies.push_back(MapITT->second[i]);
					ReactantDegenerateTypes.push_back(DegenerateClass);
				}
				DegenerateClass++;
			}
			//Obtaining every possible mapping of products to reactants
			vector<vector<int> > AlternativeMappings = AllPossibleMappings(ProductDegenerateTypes,ReactantDegenerateTypes,0,NULL,NULL);
			//Rearranging the mappings into the datastructure utilized in this function
			for (int i=0; i < int(AlternativeMappings.size()); i++) {
				for (int j=0; j < int(AlternativeMappings[i].size()); j++) {
					if (i==0) {
						if (AlternativeMappings[i][j] == -1) {
							CurrentTypeMapping[j][0] = -1;
						} else {
							CurrentTypeMapping[j][0] = ReactantGlobalIndecies[(AlternativeMappings[i][j])];
						}
					} else {
						if (AlternativeMappings[i][j] == -1) {
							CurrentTypeMapping[j].push_back(-1);
						} else {
							CurrentTypeMapping[j].push_back(ReactantGlobalIndecies[(AlternativeMappings[i][j])]);
						}
					}
				}
			}
		}
		//Storing the appropriate number of this type of reactant DBID
		for (int i=0; i < NumResidual; i++) {
			UniversalProducts.push_back(MapIT->first);
		}
		ProductIndecies.push_back(CurrentTypeIndecies);
		AllProductToReactantMaps.push_back(CurrentTypeMapping);
	}

	//ProductToReactantMap[PRODUCT MAP][PRODUCT LOCAL INDEX][0] = REACTANT MAP (or -1 if the product is a product in the combined reaction)
	//ProductToReactantMap[PRODUCT MAP][PRODUCT LOCAL INDEX][1] = REACTANT LOCAL INDEX (or -1 if the product is a product in the combined reaction)
	vector< vector< vector<int> > > ProductToReactantMap;
	ProductToReactantMap.resize(AllMaps.size());
	for (int i=0; i < int(AllMaps.size()); i++) {
		ProductToReactantMap[i].resize(AllMaps[i]->Products.size());
		for (int j=0; j < int(AllMaps[i]->Products.size()); j++) {
			ProductToReactantMap[i][j].resize(2);
		}
	}
	//CombinedMaps[MAP INDEX] = ONE POSSIBLE OVERALL MAPPING THAT CAN RESULT FROM THE COMBINATION OF THESE MAPS
	vector<MapData*> CombinedMaps;
	//CurrentValues[PRODUCT TYPE] = SOLUTION INDEX 
	vector<int> CurrentValues(AllProductToReactantMaps.size(),0);
	do {
		//Initializing ReactantToProductMap to -1
		for (int i=0; i < int(ReactantToProductMap.size()); i++) {
			//i = REACTANT TYPE
			for (int j=0; j < int(ReactantToProductMap[i].size()); j++) {
				//j = REACTANT TYPE INDEX
				ReactantToProductMap[i][j] = -1;
			}
		}
		//Filling the ProductToReactantMap structure
		int Count = 0;
		for (int i=0; i < int(AllProductToReactantMaps.size()); i++) {
			//i = PRODUCT TYPE
			for (int j=0; j < int(AllProductToReactantMaps[i].size()); j++) {
				//j = PRODUCT TYPE INDEX
				if (AllProductToReactantMaps[i][j][(CurrentValues[i])] >= 0) {
					//This is an intermediate product of the combined reaction
					ProductToReactantMap[(ProductSourceData[(ProductIndecies[i][j])][0])][(ProductSourceData[(ProductIndecies[i][j])][1])][0] = ReactantSourceData[(AllProductToReactantMaps[i][j][(CurrentValues[i])])][0];
					ProductToReactantMap[(ProductSourceData[(ProductIndecies[i][j])][0])][(ProductSourceData[(ProductIndecies[i][j])][1])][1] = ReactantSourceData[(AllProductToReactantMaps[i][j][(CurrentValues[i])])][1];
					ReactantToProductMap[(ReactantType[(AllProductToReactantMaps[i][j][(CurrentValues[i])])])][(ReactantTypeIndex[(AllProductToReactantMaps[i][j][(CurrentValues[i])])])] = (ProductIndecies[i][j]);
				} else {
					//This is a final product of the combined reaction
					ProductToReactantMap[(ProductSourceData[(ProductIndecies[i][j])][0])][(ProductSourceData[(ProductIndecies[i][j])][1])][0] = -1;
					ProductToReactantMap[(ProductSourceData[(ProductIndecies[i][j])][0])][(ProductSourceData[(ProductIndecies[i][j])][1])][1] = Count;
					Count++;
				}
			}
		}
		//Creating the first map
		MapData* NewMapData = new MapData;
		NewMapData->Reactants = UniversalReactants;
		NewMapData->Products = UniversalProducts;
		NewMapData->AtomToProducts.resize(NewMapData->Reactants.size());
		NewMapData->AtomToAtom.resize(NewMapData->Reactants.size());
		//Creating map
		Count = 0;
		for (int i=0; i < int(ReactantToProductMap.size()); i++) {
			//i = REACTANT TYPE
			for (int j=0; j < int(ReactantToProductMap[i].size()); j++) {
				//j = REACTANT TYPE INDEX
				if (ReactantToProductMap[i][j] == -1) {
					//This is a final reactant of the combined reaction
					//Copying the original mapping data for this reactant
					NewMapData->AtomToProducts[Count] = AllMaps[(ReactantSourceData[(ReactantIndecies[i][j])][0])]->AtomToProducts[(ReactantSourceData[(ReactantIndecies[i][j])][1])];
					NewMapData->AtomToAtom[Count] = AllMaps[(ReactantSourceData[(ReactantIndecies[i][j])][0])]->AtomToAtom[(ReactantSourceData[(ReactantIndecies[i][j])][1])];
					//Converting the original mapping to the combined mapping based on the translation information
					for (int k=0; k < int(NewMapData->AtomToProducts[Count].size()); k++) {
						int MapIndex = ReactantSourceData[ReactantIndecies[i][j]][0];
						int ProductIndex = NewMapData->AtomToProducts[Count][k];
						int ProductAtom = NewMapData->AtomToAtom[Count][k];
						while(ProductToReactantMap[MapIndex][ProductIndex][0] != -1) {
							int OriginalProductIndex = ProductIndex;
							ProductIndex = ProductToReactantMap[MapIndex][OriginalProductIndex][1];
							MapIndex = ProductToReactantMap[MapIndex][OriginalProductIndex][0];
							int OriginalProductAtom = ProductAtom;
							ProductAtom = AllMaps[MapIndex]->AtomToAtom[ProductIndex][OriginalProductAtom];
							ProductIndex = AllMaps[MapIndex]->AtomToProducts[ProductIndex][OriginalProductAtom];
						}
						NewMapData->AtomToProducts[Count][k] = ProductToReactantMap[MapIndex][ProductIndex][1];
						NewMapData->AtomToAtom[Count][k] = ProductAtom;
					}
					//Iterating the count to move on to the next reactant
					Count++;
				}
			}
		}
		//Saving the new combined map
		CombinedMaps.push_back(NewMapData);
		//Now iterating the solution indecies 
		int CurrentIndex = int(CurrentValues.size()-1);
		do {
			if (CurrentValues[CurrentIndex] < int(AllProductToReactantMaps[CurrentIndex][0].size()-1)) {
				CurrentValues[CurrentIndex]++;
				CurrentIndex++;
			} else {
				CurrentValues[CurrentIndex] = -1;
				CurrentIndex--;
			}
		} while(CurrentIndex < int(CurrentValues.size()) && CurrentIndex != -1);
		if (CurrentIndex == -1) {
			break;
		}
	} while(1);

	//Deleting the maps created
	for (int i=0; i < int(AllMaps.size()); i++) {
		delete AllMaps[i];
	}

	//Converting the combined maps back into strings
	vector<string> NewMaps;
	for (int i=0; i < int(CombinedMaps.size()); i++) {
		string NewMap = CreateMapString(CombinedMaps[i],true);
		//Checking that the new map is unique
		for (int j=0; j < int(NewMaps.size()); j++) {
			if (NewMaps[j].compare(NewMap) == 0) {
				NewMap.clear();
				break;
			}
		}
		if (NewMap.length() > 0) {
			NewMaps.push_back(NewMap);
		}
	}

	return NewMaps;
}

string CreateMapString(MapData* InMapData, bool DeleteMap) {
	//Reactants will be stored in lexographical order while products will be stored in the order of appearence
	//Ordering reactant database IDs and spotting DBID degeneracy using a map of vectors
	map<string, vector<int>, std::less<string> > ReactantIDs;
	for (int i=0; i < int(InMapData->Reactants.size()); i++) {
		ReactantIDs[InMapData->Reactants[i]].push_back(i);
	}

	//Scanning through the now sorted reactant database IDs to find and deal with degeneracy
	vector<int> NewReactantOrder;
	for (map<string, vector<int>, std::less<string> >::iterator MapIT = ReactantIDs.begin(); MapIT != ReactantIDs.end(); MapIT++) {
		if (MapIT->second.size() == 1) {
			NewReactantOrder.push_back(MapIT->second[0]);
		} else {
			//Degenerate database IDs exist and must be differentiated based on their mappings
			map<string, vector<int>, std::less<string> > DegenerateMap;
			for (int i=0; i < int(MapIT->second.size()); i++) {
				string DegenerateString;
				int LastProduct = -1;
				for (int j=0; j < int(InMapData->AtomToProducts[MapIT->second[i]].size()); j++) {
					if (InMapData->AtomToProducts[MapIT->second[i]][j] != LastProduct) {
						LastProduct = InMapData->AtomToProducts[MapIT->second[i]][j];
						if (j > 0) {
							DegenerateString.append(";");
						}
						DegenerateString.append(InMapData->Products[InMapData->AtomToProducts[MapIT->second[i]][j]]);
						DegenerateString.append(":");
					} else {
						if (j > 0) {
							DegenerateString.append(",");
						}
					}
					DegenerateString.append(itoa(InMapData->AtomToAtom[MapIT->second[i]][j]));
				}
				DegenerateMap[DegenerateString].push_back(MapIT->second[i]);
			}

			//If items have the same string here, then they are completely degenerate and it does not matter what order they are placed in the map string
			for (map<string, vector<int>, std::less<string> >::iterator MapITT = DegenerateMap.begin(); MapITT != DegenerateMap.end(); MapITT++) {
				for (int i=0; i < int(MapITT->second.size()); i++) {
					NewReactantOrder.push_back(MapITT->second[i]);
				}
			}
		}
	}

	//Using the uniquely ordered reactants, the reactant portion of the unique map string is created
	string Map;
	vector<int> NewProductOrder;
	for (int i=0; i < int(NewReactantOrder.size()); i++) {
		//Appending the reactant DB ID first
		Map.append(InMapData->Reactants[NewReactantOrder[i]]);
		Map.append("(");
		int LastProduct = -1;
		for (int j=0; j < int(InMapData->AtomToProducts[NewReactantOrder[i]].size()); j++) {
			if (InMapData->AtomToProducts[NewReactantOrder[i]][j] != LastProduct) {
				LastProduct = InMapData->AtomToProducts[NewReactantOrder[i]][j];
				//Checking to see if this product has shown up previously
				int NewID = -1;
				for (int k=0; k < int(NewProductOrder.size()); k++) {
					if (NewProductOrder[k] == InMapData->AtomToProducts[NewReactantOrder[i]][j]) {
						NewID = k;
						break;
					}
				}
				if (NewID == -1) {
					NewID = int(NewProductOrder.size());
					NewProductOrder.push_back(InMapData->AtomToProducts[NewReactantOrder[i]][j]);
				}
				if (j > 0) {
					Map.append(";");
				}
				Map.append(itoa(NewID));
				Map.append(":");
			} else {
				if (j > 0) {
					Map.append(",");
				}
			}
			Map.append(itoa(InMapData->AtomToAtom[NewReactantOrder[i]][j]));
		}
		Map.append(")");
	}
	Map.append("/");
	
	//Now that the products have been sequenced in order of appearance in the reactant string, the product portion of the unique map string is created
	for (int i=0; i < int(NewProductOrder.size()); i++) {
		Map.append(InMapData->Products[NewProductOrder[i]]);
		Map.append(".");
	}

	//Deleting the original map datastructure as requested
	if (DeleteMap) {
		delete InMapData;
	}
	
	return Map;
}

MapData* ParseMapString(string InMap) {
	//Alocating the map data
	MapData* NewMapData = new MapData;

	//Breaking up the map into reactant and product strings
	vector<string>* Strings = StringToStrings(InMap, "/");
	string Reactants = (*Strings)[0];
	string Products = (*Strings)[1];
	delete Strings;

	//Parsing product data
	Strings = StringToStrings(Products,".");
	for (int i=0; i < int(Strings->size()); i++) {
		if ((*Strings)[i].length() > 0) {
			NewMapData->Products.push_back((*Strings)[i]);
		}
	}
	delete Strings;

	//Parsing reactant data
	Strings = StringToStrings(Reactants,")");
	for (int i=0; i < int(Strings->size()); i++) {
		if ((*Strings)[i].length() > 0) {
			vector<string>* StringsTwo = StringToStrings((*Strings)[i],"(;");
			if ((*StringsTwo)[0].length() > 0) {
				NewMapData->Reactants.push_back((*StringsTwo)[0]);
				vector<int> ProductIndecies;
				vector<int> ProductAtoms;
				for (int j=1; j < int(StringsTwo->size()); j++) {
					if ((*StringsTwo)[j].length() > 0) {
						vector<string>* StringsThree = StringToStrings((*StringsTwo)[j],":,");
						if ((*StringsThree)[0].length() > 0) {
							int ProductIndex = atoi((*StringsThree)[0].data());
							for (int m=1; m < int(StringsThree->size()); m++) {
								ProductIndecies.push_back(ProductIndex);
								ProductAtoms.push_back(atoi((*StringsThree)[m].data()));
							}
						}
						delete StringsThree;
					}
				}
				NewMapData->AtomToAtom.push_back(ProductAtoms);
				NewMapData->AtomToProducts.push_back(ProductIndecies);
			}
			delete StringsTwo;
		}
	}
	delete Strings;

	return NewMapData;
}

string ReverseMapString(string InMap) {
	MapData* NewMapData = ParseMapString(InMap);

	//Reversed map data
	vector<string> Reactants = NewMapData->Products;
	vector<string> Products = NewMapData->Reactants;
	vector<vector<int> > AtomToProducts(Reactants.size());
	vector<vector<int> > AtomToAtom(Reactants.size());
	
	//Populating reverse data
	for (int i=0; i < int(NewMapData->Reactants.size()); i++) {
		for (int j=0; j < int(NewMapData->AtomToAtom[i].size()); j++) {
			for (int k = int(AtomToAtom[NewMapData->AtomToProducts[i][j]].size()); k <= int(NewMapData->AtomToAtom[i][j]); k++) {
				AtomToAtom[NewMapData->AtomToProducts[i][j]].push_back(-1);
				AtomToProducts[NewMapData->AtomToProducts[i][j]].push_back(-1);
			}
			AtomToAtom[NewMapData->AtomToProducts[i][j]][NewMapData->AtomToAtom[i][j]] = j;
			AtomToProducts[NewMapData->AtomToProducts[i][j]][NewMapData->AtomToAtom[i][j]] = i;
		}
	}

	//Storing reverse data
	NewMapData->Products = Products;
	NewMapData->Reactants = Reactants;
	NewMapData->AtomToProducts = AtomToProducts;
	NewMapData->AtomToAtom = AtomToAtom;

	return CreateMapString(NewMapData,true);
}

string GetMFAVariableName(MFAVariable* InVariable) {
	string TypeName;
	if (GetParameter("use simple variable and constraint names").compare("1") == 0) {
		TypeName.assign("x");
		TypeName.append(itoa(InVariable->Index+1));
		return TypeName;
	}
	
	int InType = InVariable->Type;
	if (InType == FLUX) {
		TypeName.assign("F");	
	} else if (InType == FORWARD_FLUX) {
		TypeName.assign("FF");	
	} else if (InType == REVERSE_FLUX) {
		TypeName.assign("RF");	
	} else if (InType == REACTION_USE) {
		TypeName.assign("FU");	
	} else if (InType == FORWARD_USE) {
		TypeName.assign("FFU");	
	} else if (InType == REVERSE_USE) {
		TypeName.assign("RFU");	
	} else if (InType == DELTAG) {
		TypeName.assign("DG");	
	} else if (InType == CONC) {
		TypeName.assign("C");	
	} else if (InType == LOG_CONC) {
		TypeName.assign("LC");	
	} else if (InType == DELTAGF_ERROR) {
		TypeName.assign("DFE");	
	} else if (InType == DRAIN_FLUX) {
		TypeName.assign("D");	
	} else if (InType == FORWARD_DRAIN_FLUX) {
		TypeName.assign("FD");	
	} else if (InType == REVERSE_DRAIN_FLUX) {
		TypeName.assign("RD");	
	} else if (InType == FORWARD_DRAIN_USE) {
		TypeName.assign("FDU");	
	} else if (InType == REVERSE_DRAIN_USE) {
		TypeName.assign("RDU");	
	} else if (InType == DRAIN_USE) {
		TypeName.assign("DU");
	} else if (InType == COMPLEX_USE) {
		TypeName.assign("GCU");	
	} else if (InType == REACTION_DELTAG_PERROR) {
		TypeName.assign("DGEP");	
	} else if (InType == REACTION_DELTAG_NERROR) {
		TypeName.assign("DGEN");	
	} else if (InType == GENE_USE) {
		TypeName.assign("GU");	
	} else if (InType == INTERVAL_USE) {
		TypeName.assign("GIU");
	} else if (InType == REACTION_DELTAG_ERROR) {
		TypeName.assign("DGE");
	} else if (InType == GENOME_CUTS) {
		TypeName.assign("GC");	
	} else if (InType == DELTAGF_PERROR) {
		TypeName.assign("DFPE");	
	} else if (InType == DELTAGG_ENERGY) {
		TypeName.assign("DGGE");	
	} else if (InType == DELTAGF_NERROR) {
		TypeName.assign("DFNE");	
	} else if (InType == POTENTIAL) {
		TypeName.assign("P");
	} else if (InType == SMALL_DELTAG_ERROR_USE) {
		TypeName.assign("SDGEU");
	} else if (InType == LARGE_DELTAG_ERROR_USE) {
		TypeName.assign("LDGEU");
	} else if (InType == LUMP_USE) {
		TypeName.assign("LU");
	} else {
		FErrorFile() << "Unrecognized MFA variable type number: " << InType << endl;
		FlushErrorFile();
	}
	TypeName.append("_");

	if (InVariable->AssociatedReaction != NULL) {
		TypeName.append(InVariable->AssociatedReaction->GetData("DATABASE",STRING));
	} else if (InVariable->AssociatedSpecies != NULL) {
		TypeName.append(InVariable->AssociatedSpecies->GetData("DATABASE",STRING));
	} else if (InVariable->AssociatedGene != NULL) {
		TypeName.append(InVariable->AssociatedGene->GetData("DATABASE",STRING));
	} else {
		TypeName.append(InVariable->Name);
	}

	if (InVariable->Compartment != -1) {
		TypeName.append("_"+GetCompartment(InVariable->Compartment)->Abbreviation);
	}

	TypeName = StringReplace(TypeName.data(), "<=>", "RV");
	TypeName = StringReplace(TypeName.data(), "cue_", "");
	TypeName = StringReplace(TypeName.data(), "=>", "F");
	TypeName = StringReplace(TypeName.data(), "<=", "R");
	TypeName = StringReplace(TypeName.data(), "[", "_");
	TypeName = StringReplace(TypeName.data(), "]", "");

	if (TypeName.length() > 16) {
		TypeName = TypeName.substr(0,16);
	}
	
	if (TypeName.compare("FFU_") == 0) {
		cout << "problem" << endl;
	}

	if (variableNames[TypeName] != NULL && variableNames[TypeName] != InVariable) {
	  if(InVariable->Type == DRAIN_FLUX){
	    cout <<"Renaming drain flux from "<<variableNames[TypeName]->Name<<" to "<<InVariable->Name<<endl;
	  }else{
	    cout <<"Error naming variable!"<<"\t"<<InVariable->Name<<"\t"<<variableNames[TypeName]->Name<<endl;
	  }
	}
	variableNames[TypeName] = InVariable;
	return TypeName;
}

string GetConstraintName(LinEquation* InEquation) {
	string Name;
	string Compartment;
	if (GetParameter("use simple variable and constraint names").compare("1") == 0) {
		Name.assign("c");
		Name.append(itoa(InEquation->Index+1));
		return Name;
	}

	if (InEquation->ConstraintMeaning.find("_mass_balance") != -1) {
		Name.assign("M_");
		Compartment = InEquation->ConstraintMeaning.substr(0,1);
	} else if (InEquation->ConstraintMeaning.compare("reaction deltaG error decomposition") == 0) {
		Name.assign("DED_");
	} else if (InEquation->ConstraintMeaning.length() > 28 && InEquation->ConstraintMeaning.substr(0,28).compare("Regulatory Lower Constraint ") == 0) {
		Name.assign("RLC_");
		Name.append(InEquation->ConstraintMeaning.substr(28));
	} else if (InEquation->ConstraintMeaning.length() > 28 && InEquation->ConstraintMeaning.substr(0,28).compare("Regulatory Upper Constraint ") == 0) {
		Name.assign("RUC_");
		Name.append(InEquation->ConstraintMeaning.substr(28));
	} else if (InEquation->ConstraintMeaning.compare("reaction deltaG error use variable constraint") == 0) {
		Name.assign("DEU_");
	} else if (InEquation->ConstraintMeaning.compare("reaction deltaG error constraint") == 0) {
		Name.assign("DGE_");
	} else if (InEquation->ConstraintMeaning.compare("thermo feasibility constraint") == 0) {
		Name.assign("F_");
	} else if (InEquation->ConstraintMeaning.compare("gibbs energy constraint") == 0) {
		Name.assign("G_");
	} else if (InEquation->ConstraintMeaning.compare("reverse thermo feasibility constraint") == 0) {
		Name.assign("RF_");
	} else if (InEquation->ConstraintMeaning.compare("chemical potential constraint") == 0) {
		for (int i=0; i < int(InEquation->Variables.size()); i++) {
			if (InEquation->Variables[i]->Type == POTENTIAL) {
				Compartment = GetCompartment(InEquation->Variables[i]->Compartment)->Abbreviation;
			}
		}
		Name.assign("P_");
	} else if (InEquation->ConstraintMeaning.compare("Enforcing use variable") == 0) {
		Name.assign("U_");
	} else {
		//FLogFile() << InEquation->ConstraintMeaning << endl;
	}

	if (InEquation->AssociatedReaction != NULL) {
		Name.append(InEquation->AssociatedReaction->GetData("DATABASE",STRING));
	} else if (InEquation->AssociatedSpecies != NULL) {
		Name.append(InEquation->AssociatedSpecies->GetData("DATABASE",STRING));
	}

	Name = StringReplace(Name.data(), "<=>", "RV");
	Name = StringReplace(Name.data(), "cue_", "");
	Name = StringReplace(Name.data(), "=>", "F");
	Name = StringReplace(Name.data(), "<=", "R");
	Name = StringReplace(Name.data(), "[", "_");
	Name = StringReplace(Name.data(), "]", "");

	if (Compartment.length() > 0) {
		Name.append("_"+Compartment);
	}

	if (Name.length() > 16) {
		Name = Name.substr(0,16);
	}

	if (constraintNames[Name] != NULL) {
		int index = 1;
		string temp = Name+itoa(index);
		while (constraintNames[temp] != NULL) {
			index++;
			temp = Name+itoa(index);
		}
		Name = temp;
	}
	constraintNames[Name] = InEquation;

	if (Name.compare("U_") == 0) {
		cout << "problem" << endl;
	}
	Name.assign("c");
	Name.append(itoa(InEquation->Index));
	return Name;
}

OptSolutionData* ParseSCIPSolution(string Filename,vector<MFAVariable*> Variables) {
	//Parsing the output file generated by SCIP
	ifstream Input;
	if (!OpenInput(Input,(FOutputFilepath()+Filename).data())) {
		cout << "Could not open scip output file!" << endl;
		return NULL;
	}
	bool ReadingSolution = false;
	OptSolutionData* NewSolution = new OptSolutionData;
	for (int i=0; i < int(Variables.size()); i++) {
		NewSolution->SolutionData.push_back(0);
		if (Variables[i]->UpperBound == Variables[i]->LowerBound) {
			NewSolution->SolutionData.push_back(Variables[i]->UpperBound);
		}
	}
	
	NewSolution->Status = FAIL;
	while(!Input.eof()) {
		vector<string>* Strings = GetStringsFileline(Input," ",true);
		if (!ReadingSolution) {
			if (Strings->size() >= 9 && (*Strings)[0].compare("SCIP") == 0 && (*Strings)[1].compare("Status") == 0) {
				if (((*Strings)[2]+(*Strings)[3]+(*Strings)[4]+(*Strings)[5]+(*Strings)[6]+(*Strings)[7]+(*Strings)[8]).compare(":problemissolved[optimalsolutionfound]") == 0) {
					NewSolution->Status = SUCCESS;
				}
			} else if (Strings->size() >= 3 && (*Strings)[0].compare("objective") == 0 && (*Strings)[1].compare("value:") == 0) {
				NewSolution->Objective = atof((*Strings)[2].data());
				ReadingSolution = true;
			}
		} else {
			if (Strings->size() == 0 || (*Strings)[0].length() == 0) {
				break;
			} else if (Strings->size() >= 2 && (*Strings)[0].substr(0,1).compare("x") == 0) {
				int VarIndex = atoi((*Strings)[0].substr(1).data());
				if (VarIndex <= int(NewSolution->SolutionData.size())) {
					NewSolution->SolutionData[VarIndex-1] = atof((*Strings)[1].data());
				}
			}
		}
		delete Strings;
	}
	return NewSolution;
}

string GetDatabaseDirectory(string Database,string Entity) {
	if (Entity.compare("root directory") != 0) {
		return QueryTextDatabase("database",Database,"root directory")+QueryTextDatabase("database",Database,Entity);
	} else {
		return QueryTextDatabase("database",Database,Entity);
	}
}

int printOutput(string filename,string output) {
	if (GetParameter("print all output to stdout").compare("1") == 0) {
		cout << "STARTFILE:" << filename << endl;
		cout << output << endl;
		cout << "ENDFILE:" << filename << endl;
		return SUCCESS;
	}
	ofstream outputStream;
	if (!OpenOutput(outputStream,filename)) {
		return FAIL;
	}
	outputStream << output << endl;
	outputStream.close();
	return SUCCESS;
}
