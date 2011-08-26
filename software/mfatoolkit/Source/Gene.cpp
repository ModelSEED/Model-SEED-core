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

Gene::Gene(string InFilename, Data* InData) {
	MainData = InData;

	if (InFilename.length() > 0) {
		AddData("DATABASE",InFilename.data(),STRING);
		AddData("FILENAME",InFilename.data(),STRING);
		if (GetParameter("Load genes").compare("1") == 0) {
			LoadGene(InFilename);
		}
	}

	GeneUseVariable = NULL;
	Next = NULL;
	Previous = NULL;
}

Gene::~Gene() {

}

//Input
void Gene::AddReaction(Reaction* InReaction) {
	for (int i=0; i < int(ReactionList.size()); i++) {
		if (InReaction == ReactionList[i]) {
			return;
		}
	}
	
	ReactionList.push_back(InReaction);
}

void Gene::AddInterval(GeneInterval* InInterval) {
	IntervalList.push_back(InInterval);
}

void Gene::SetPrevious(Gene* InGene) {
	Previous = InGene;
}

void Gene::SetNext(Gene* InGene) {
	Next = InGene;
}

void Gene::ClearIntervals() {
	IntervalList.clear();
}

//Output
int Gene::FNumReactions() {
	return int(ReactionList.size());
}

Reaction* Gene::GetReaction(int InIndex) {
	if (InIndex >= int(ReactionList.size())) {
		return NULL;
	}

	return ReactionList[InIndex];
}

string Gene::Query(string InQuery) {
	string Result = "";

	return Result;
}

int Gene::FNumIntervals() {
	return int(IntervalList.size());
}

Gene* Gene::NextGene() {
	return Next;
}

Gene* Gene::PreviousGene() {
	return Previous;
}

GeneInterval* Gene::GetInterval(int InIndex) {
	if (InIndex >= int(IntervalList.size())) {
		return NULL;
	}
	return IntervalList[InIndex];
}

//Fileinput
int Gene::Interpreter(string DataName, string& DataItem, bool Input) {
	int DataID = TranslateFileHeader(DataName,GENE);
	
	if (DataID == -1) {
		AddData(DataName.data(),DataItem.data(),STRING);
		//FErrorFile() << "UNRECOGNIZED REFERENCE: " << GetData("FILENAME",STRING) << " data reference: " << DataName << " not recognized." << endl;
		//FlushErrorFile();
		return FAIL;
	}
	
	switch (DataID) {
		case GENE_DBLINK: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DATABASE_LINK);
			} else {
				DataItem = GetAllDataString(DataName.data(),DATABASE_LINK);
			}
			break;
		} case GENE_COORD: {
			if (Input) {
				vector<string>* Strings = StringToStrings(DataItem,".");
				if (Strings->size() >= 2) {
					AddData("START COORD",atof((*Strings)[0].data()));
					AddData("END COORD",atof((*Strings)[1].data()));
				}
				delete Strings;
			} else {
				double Start = GetDoubleData("START COORD");
				double End = GetDoubleData("END COORD");
				if (Start != FLAG && End != FLAG) {
					DataItem.assign(dtoa(Start));
					DataItem.append("..");
					DataItem.append(dtoa(End));

				}
			}
			break;
		} case GENE_REACTION: {
			if (Input) {
				//Do nothing... reactions will add themselves to the genes
			} else {
				for (int i=0; i < int(ReactionList.size()); i++) {
					DataItem.append(ReactionList[i]->GetData("DATABASE",STRING));
					if (i < int(ReactionList.size()-1)) {
						DataItem.append("\t");
					}
				}
			}
			break;
		} case GENE_PARALOG: {
			if (Input) {
				vector<string>* Strings = StringToStrings(DataItem,"\t ");
				for (int i=0; i < int(Strings->size()); i += 2) {
					if (AddData("PARALOGS",(*Strings)[i].data(),STRING)) {;
						AddData("PARA SIMS",atof((*Strings)[i+1].data()),false);
					}
				}
				delete Strings;
			} else {
				vector<string> AllParalogs = GetAllData("PARALOGS",STRING);
				vector<double> AllSims = GetAllData("PARA SIMS");
				for (int i=0; i < int(AllParalogs.size()); i++) {
					DataItem.append(AllParalogs[i]);
					DataItem.append(" ");
					DataItem.append(dtoa(AllSims[i]));
					if (i < int(AllParalogs.size()-1)) {
						DataItem.append("\t");
					}
				}
			}
			break;
		} case GENE_ORTHOLOG: {
			if (Input) {
				vector<string>* Strings = StringToStrings(DataItem,"\t ");
				for (int i=0; i < int(Strings->size()); i += 2) {
					if (AddData("ORTHOLOGS",(*Strings)[i].data(),STRING)) {;
						AddData("ORTHO SIMS",atof((*Strings)[i+1].data()),false);
					}
				}
				delete Strings;
			} else {
				vector<string> AllParalogs = GetAllData("ORTHOLOGS",STRING);
				vector<double> AllSims = GetAllData("ORTHO SIMS");
				for (int i=0; i < int(AllParalogs.size()); i++) {
					DataItem.append(AllParalogs[i]);
					DataItem.append(" ");
					DataItem.append(dtoa(AllSims[i]));
					if (i < int(AllParalogs.size()-1)) {
						DataItem.append("\t");
					}
				}
			}
			break;
		} case GENE_DOUBLE: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DOUBLE);
			} else {
				DataItem = GetAllDataString(DataName.data(),DOUBLE);
			}
			break;
		} case GENE_STRING: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),STRING);
			} else {
				DataItem = GetAllDataString(DataName.data(),STRING);
			}
			break;
		} case GENE_QUERY: {
			if (Input) {
				if (GetParameter("save query data on input").compare("1") == 0) {
					AddData(DataName.data(),DataItem.data(),STRING);
				}
			} else {
				DataItem = Query(DataName);
			}
			break;
		} case GENE_LOAD: {
			if (Input) {
				LoadGene(DataItem);			
			} else {
				DataItem = GetData("DATABASE",STRING);
			}
			break;
		} default: {
			//FErrorFile() << "UNRECOGNIZED DATA ID: Data ID: " << DataID << " input for data reference: " << DataName << " not recognized. Check gene code.";
			//FlushErrorFile();
			return FAIL;
		}
	}	
	
	return SUCCESS;
}

int Gene::LoadGene(string InFilename) {
	if (InFilename.length() == 0) {
		InFilename = GetData("FILENAME",STRING);
		if (InFilename.length() == 0) {
			InFilename = GetData("DATABASE",STRING);
			if (InFilename.length() == 0) {
				return FAIL;
			}
		}
	}
	if (InFilename.length() == 0) {
		return FAIL; 
	}
	SetData("FILENAME",InFilename.data(),STRING);

	if (!FileExists(InFilename)) {
		InFilename = GetDatabaseDirectory(GetParameter("database"),"gene directory")+InFilename;
		if (!FileExists(InFilename)) {
			return FAIL;
		}
	}

	ifstream Input;
	if (!OpenInput(Input,InFilename)) {
		SetKill(true);
		return FAIL;
	}
	
	do {
		vector<string>* Strings = GetStringsFileline(Input,"\t");
		if (Strings->size() >= 2) {
			//I save the input headings so I can print out the same headings when it's time to save the file
			AddData("INPUT_HEADER",(*Strings)[0].data(),STRING);
			for (int i=1; i < int(Strings->size()); i++) {
				Interpreter((*Strings)[0],(*Strings)[i],true);
			}
		}
		delete Strings;
	} while(!Input.eof());

	if (GetData("DATABASE",STRING).length() == 0) {
		AddData("DATABASE",InFilename.data(),STRING);
	}
	if (MainData != NULL && MainData->GetData("DATABASE",STRING).length() > 0 && GetData("DATABASE",STRING).length() > 0) {
		AddData(MainData->GetData("DATABASE",STRING).data(),GetData("DATABASE",STRING).data(),DATABASE_LINK);
	}

	Input.close();
	return SUCCESS;
}

//Fileoutput
int Gene::SaveGene(string InFilename) {
	if (InFilename.length() == 0) {
		InFilename = GetData("FILENAME",STRING);
		if (InFilename.length() == 0) {
			InFilename = GetData("DATABASE",STRING);
			if (InFilename.length() == 0) {
				return FAIL;
			}
		}
	}
	
	if (InFilename.substr(1,1).compare(":") != 0 && InFilename.substr(0,1).compare("/") != 0) {
		InFilename = GetDatabaseDirectory(GetParameter("database"),"new gene directory")+InFilename;
	}

	ofstream Output;
	if (!OpenOutput(Output,InFilename)) {
		return FAIL;
	}

	//First I check to see if the user specified that the input headers be printed in the output file
	vector<string>* FileHeader = StringToStrings(GetParameter("gene data to print"),";");
	vector<string> InputHeaders;
	for (int i=0; i < int(FileHeader->size()); i++) {
		if ((*FileHeader)[i].compare("INPUT_HEADER") == 0) {
			InputHeaders = GetAllData("INPUT_HEADER",STRING);
			break;
		}
	}

	for (int i=0; i < int(InputHeaders.size()); i++) {
		string Data;
		Interpreter(InputHeaders[i],Data,false);
		Output << InputHeaders[i] << "\t" << Data << endl;
	}

	for (int i=0; i < int(FileHeader->size()); i++) {
		//I check to see if the current file header has already been printed to file
		if ((*FileHeader)[i].compare("INPUT_HEADER") != 0) {
			int j =0;
			for (j=0; j < int(InputHeaders.size()); j++) {
				if (InputHeaders[j].compare((*FileHeader)[i]) == 0) {
					break;
				}
			}
			if (j == int(InputHeaders.size())) {
				//If the current file header has not already been printed to file, it is printed now
				string Data;
				Interpreter((*FileHeader)[i],Data,false);
				if (Data.length() > 0) {
					Output << (*FileHeader)[i] << "\t" << Data << endl;
				}
			}
		}
	}

	Output.close();
	return SUCCESS;
}

//Metabolic flux analysis functions
MFAVariable* Gene::CreateMFAVariable(OptimizationParameter* InParameters) {
	GeneUseVariable = InitializeMFAVariable();

	GeneUseVariable->UpperBound = 1;
	GeneUseVariable->LowerBound = 0;
	if (GetData("ESSENTIAL",STRING).compare("Kobyashi et al.") == 0 || GetData("ESSENTIAL",STRING).compare("Noirot et al.") == 0) {
		GeneUseVariable->LowerBound = 1;
	}
	GeneUseVariable->Binary = true;
	GeneUseVariable->Type = GENE_USE;
	GeneUseVariable->AssociatedGene = this;
	GeneUseVariable->Name = GetData("DATABASE",STRING);

	return GeneUseVariable;
}

MFAVariable* Gene::GetMFAVar() {
	return GeneUseVariable;
}

void Gene::ClearMFAVariables(bool DeleteThem) {
	if (DeleteThem && GeneUseVariable != NULL) {
		delete GeneUseVariable;
	}
	GeneUseVariable = NULL;
}

LinEquation* Gene::CreateIntervalDeletionConstraint() {
	//If this gene is not in any intervals, then this constraint is not added
	if (IntervalList.size() == 0) {
		return NULL;
	}
	
	LinEquation* NewConstraint = InitializeLinEquation("Interval deletion constraint",0,LESS,LINEAR);
	NewConstraint->Variables.push_back(GeneUseVariable);
	NewConstraint->Coefficient.push_back(1);

	for (int i=0; i < int(IntervalList.size()); i++) {
		NewConstraint->Variables.push_back(IntervalList[i]->GetMFAVar());
		NewConstraint->Coefficient.push_back(-1);
	}

	return NewConstraint;
}