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

Data::Data(int InIndex) {
	HydrogenSpecies = NULL;
	RepresentedCompartments = new bool[FNumCompartments()];
	for (int i=0; i < FNumCompartments(); i++) {
		RepresentedCompartments[i] = false;
	}
	LastSpeciesIndex = 0;
	LastReactionIndex = 0;
	ReactionIT = ReactionList.begin();
	SpeciesIT = SpeciesList.begin();

	//Sets the index-this is just a numerial identifier in case you have multiple datasets
	SetIndex(InIndex);
	//This loads the database of structural cues to be used
	if (GetParameter("load structural cues").compare("1") == 0) {
		LoadStructuralCues();
	}
}

Data::~Data() {
	delete [] RepresentedCompartments;
	
	//Erase all reactions, compounds, and operators from memmory
	ClearCompounds();
	ClearReactions();
	ClearStructuralCues();
	ClearGenes();
}

//File Input
int Data::LoadSystem(string Filename, bool StructCues) {
	if (Filename.compare("NONE") == 0 || Filename.compare("") == 0) {
		return FAIL;
	}
	
	ifstream Input;
	SetData("FILENAME",RemovePath(Filename).data(),STRING);
	
	cout << "Loading System: "<<Filename<<endl;

	//Checking if the filename specified is Complete indicating the complete database should be loaded
	if (Filename.compare("Complete") == 0) {
		vector<string> ReactionList;
		StringDBTable* rxntbl = GetStringDB()->get_table("reaction");
		for (int i=0; i < rxntbl->number_of_objects();i++) {
			StringDBObject* rxnobj = rxntbl->get_object(i);
			ReactionList.push_back(rxnobj->get("id"));
		}
		vector<string>* AllowedUnbalancedReactions = StringToStrings(GetParameter("Allowable unbalanced reactions"),",");
		vector<string>* DissapprovedCompartments = NULL;
		if (GetParameter("dissapproved compartments").compare("none") != 0) {
			DissapprovedCompartments = StringToStrings(GetParameter("dissapproved compartments"),";");
		}
		//Iterating through the list and loading any reaction that is not already present in the model
		for (int i=0; i < int (ReactionList.size()); i++) {
			Reaction* NewReaction = new Reaction(ReactionList[i],this);
			//Checking that only approved compartments are involved in the reaction
			bool ContainsDissapprovedCompartments = false;
			if (DissapprovedCompartments != NULL) {
				for (int j=0; j < NewReaction->FNumReactants(); j++) {
					for (int k=0; k < int(DissapprovedCompartments->size()); k++) {
						if ((*DissapprovedCompartments)[k].compare(GetCompartment(NewReaction->GetReactantCompartment(j))->Abbreviation) == 0) {
							ContainsDissapprovedCompartments = true;
						}
					}
				}
			}
			
			if (!ContainsDissapprovedCompartments) {
				//Checking if the reaction is balanced
				if (!NewReaction->BalanceReaction(false,false)) {
					NewReaction->AddData("UNBALANCED","YES",STRING);
				}
				if (GetParameter("Balanced reactions in gap filling only").compare("0") == 0 || NewReaction->GetData("UNBALANCED",STRING).length() == 0) {
					NewReaction->SetType(NewReaction->CalculateDirectionalityFromThermo());
					AddReaction(NewReaction);
				} else {
					for (int j=0; j < int(AllowedUnbalancedReactions->size()); j++) {
						if (NewReaction->GetData("DATABASE",STRING).compare((*AllowedUnbalancedReactions)[j]) == 0) {
							NewReaction->SetType(NewReaction->CalculateDirectionalityFromThermo());
							AddReaction(NewReaction);
							break;
						}
					}
				}
			}
		}
		delete DissapprovedCompartments;
		delete AllowedUnbalancedReactions;

		if (GetParameter("Complete model biomass reaction").compare("NONE") != 0) {
			Reaction* NewReaction = new Reaction(GetParameter("Complete model biomass reaction"),this);
			AddReaction(NewReaction);
		}
	} else {
		if (!StructCues && Filename.substr(1,1).compare(":") != 0 && Filename.substr(0,1).compare("/") != 0) {
			Filename = GetDatabaseDirectory(GetParameter("database"),"model directory") + Filename;
		}

		if (!OpenInput(Input,Filename)) {
			return FAIL;
		}

		AddData("NAME",RemoveExtension(RemovePath(Filename)).data(),STRING);

		bool Reactions = false;
		bool Compounds = false;
		bool StructuralCues = false;
		
		bool LabelAtoms = GetParameter("label atoms").compare("1") == 0;
		bool Stringcode = GetParameter("determine stringcode").compare("1") == 0;
		bool FindCycles = GetParameter("look for cycles").compare("1") == 0;
		bool CalcProperties = GetParameter("calculate properties from groups").compare("1") == 0;
		bool CalcFormula = GetParameter("determine formula from structure file").compare("1") == 0;

		vector<string>* Headers = NULL; 
		do {
			string Fileline = GetFileLine(Input);
			if (Fileline.length() > 0) {
				if (Fileline.compare("REACTIONS") == 0) {
					if (Headers != NULL) {
						delete Headers;
					}
					Headers = GetStringsFileline(Input,";");
					Reactions = true;
					Compounds = false;
					StructuralCues = false;
				} else if (Fileline.compare("COMPOUNDS") == 0) {
					if (Headers != NULL) {
						delete Headers;
					}
					Headers = GetStringsFileline(Input,";");
					Reactions = false;
					Compounds = true;
					StructuralCues = false;
				} else if (Fileline.compare("STRUCTURAL_CUES") == 0) {
					if (Headers != NULL) {
						delete Headers;
					}
					Headers = GetStringsFileline(Input,";");
					Reactions = false;
					Compounds = false;
					StructuralCues = true;
				} else {
					if (Reactions) {
						Reaction* Temp = AddReaction(Headers,Fileline);
						Temp->PerformAllCalculations();
					} else if (Compounds) {
						Species* Temp = AddSpecies(Headers,Fileline);
						Temp->PerformAllCalculations(LabelAtoms,Stringcode,FindCycles,CalcProperties,CalcFormula);
					}  else if (StructuralCues) {
						AddStructuralCue(Headers,Fileline);
					} 
				}
			}
		} while(!Input.eof());

		if (Headers != NULL) {
			delete Headers;
		}
		if (FNumGenes() > 0) {
			LoadGeneDictionary();
		}
	}
	if (!StructCues && GetParameter("print model genes").compare("1") == 0) {
		ofstream Output;
		string outputFilename = FOutputFilepath()+"GeneList.txt";
		if (!OpenOutput(Output,outputFilename)) {
			return FAIL;
		}
		for (int i=0; i < this->FNumGenes(); i++) {
			Output << this->GetGene(i)->GetData("DATABASE",STRING) << "\t";
			for (int j = 0; j < this->GetGene(i)->FNumReactions(); j++) {
				if (j > 0) {
					Output << ", ";
				}
				Output << this->GetGene(i)->GetReaction(j)->GetData("DATABASE",STRING);
			}
			Output << endl;
		}
		Output.close();
	}
	
	return SUCCESS;
}

int Data::LoadStructuralCues() {
	string Filename = GetParameter("input directory")+GetParameter("structural cue database file");

	int Result = LoadSystem(Filename,true);
	
	for (int i=0; i < FNumStructuralCues(); i++) {
		GetStructuralCue(i)->FillInTempStructuralCue();
		if (GetParameter("load cue structures").compare("1") == 0) {
			GetStructuralCue(i)->ReadStructure();
			if (GetStructuralCue(i)->FNumAtoms() > 0) {
				if (GetStructuralCue(i)->FSmallMolec()) {
					SortedMoleculeGroups.push_back(GetStructuralCue(i));
				} else {
					SortedSearchableGroups.push_back(GetStructuralCue(i));
				}
			}
		}
	}

	Species* NoGroupCue = FindStructuralCue("NAME;DATABASE;ENTRY","NoGroup");
	if (NoGroupCue != NULL) {
		NoGroupCue->SetEntry(255);
		CueDatabaseLinks["ENTRY"]["255"] = NoGroupCue;
	}

	return Result;
}

void Data::LoadNonmetabolicGenes() {
	//Getting a list of every gene in the gene database	
	vector<string> Filenames = GetDirectoryFileList(GetDatabaseDirectory(GetParameter("database"),"gene directory"));
	//Scanning through the gene list and loading any genes that are not already loaded
	for (int i=0; i < int(Filenames.size()); i++) {
		if (Filenames[i].length() > 4 && Filenames[i].substr(0,4).compare("peg.") == 0) {
			if (FindGene("DATABASE",Filenames[i].data()) == NULL) {
				AddGene(Filenames[i]);
			}
		}
	}
	//Setting Gene Next and Previous parameters
	//First searching for the gene with the lowest start coordinate
	Gene* FirstGene = NULL;
	double LowestCoord = FLAG;
	for (int i=0; i < FNumGenes(); i++) {
		if (LowestCoord > GetGene(i)->GetDoubleData("START COORD")) {
			LowestCoord = GetGene(i)->GetDoubleData("START COORD");
			FirstGene = GetGene(i);
		}
	}
	//Now iterating through the genome searching for the next gene neighbor
	Gene* CurrentGene = FirstGene;
	do {
		Gene* NextGene = NULL;
		LowestCoord = FLAG;
		for (int i=0; i < FNumGenes(); i++) {
			if (GetGene(i)->GetDoubleData("START COORD") > CurrentGene->GetDoubleData("END COORD") && LowestCoord > GetGene(i)->GetDoubleData("START COORD")) {
				LowestCoord = GetGene(i)->GetDoubleData("START COORD");
				NextGene = GetGene(i);
			}
		}
		if (NextGene == NULL) {
			CurrentGene->SetNext(FirstGene);
			FirstGene->SetPrevious(CurrentGene);
		} else {
			CurrentGene->SetNext(NextGene);
			NextGene->SetPrevious(CurrentGene);
		}
		CurrentGene = NextGene;
	} while (CurrentGene != NULL);
}

Species* Data::AddSpecies(string Filename) {
	Species*& Temp = CpdDatabaseLinks["FILENAME"][Filename];
	if (Temp == NULL) {
		Temp = new Species(Filename,this);
		if (Temp->FKill()) {
			delete Temp;
			Temp = NULL;
			return NULL;
		}
		if (GetData("NAME",STRING).length() > 0) {
			Temp->AddData(GetData("NAME",STRING).data(),Temp->GetData("DATABASE",STRING).data(),DATABASE_LINK);
		}
		Temp->SetEntry(FNumSpecies()+1);
		Temp->SetIndex(FNumSpecies());
		InsertSpeciesDatabaseLinks(Temp);
		SpeciesList.push_back(Temp);
		SpeciesIT = SpeciesList.begin();
		LastSpeciesIndex = 0;
	}

	return Temp;
}

Reaction* Data::AddReaction(string Filename) {
	Reaction*& Temp = RxnDatabaseLinks["FILENAME"][Filename];
	if (Temp == NULL) {
		Temp = new Reaction(Filename,this);
		if (Temp->FKill()) {
			delete Temp;
			return NULL;
		}
		if (GetData("NAME",STRING).length() > 0) {
			Temp->AddData(GetData("NAME",STRING).data(),Temp->GetData("DATABASE",STRING).data(),DATABASE_LINK);
		}
		Temp->SetEntry(FNumReactions()+1);
		Temp->SetIndex(FNumReactions());
		InsertReactionDatabaseLinks(Temp);
		ReactionList.push_back(Temp);
		ReactionIT = ReactionList.begin();
		LastReactionIndex = 0;
	}

	return Temp;
}

Species* Data::AddStructuralCue(string Filename) {
	Species*& Temp = CueDatabaseLinks["Filename"][Filename];
	if (Temp == NULL) {
		Temp = new Species(Filename,this,true);
		if (Temp->FKill()) {
			delete Temp;
			return NULL;
		}
		Temp->SetEntry(FNumStructuralCues()+1);
		Temp->SetIndex(FNumStructuralCues());
		InsertSpeciesDatabaseLinks(Temp);
		StructuralCues.push_back(Temp);
	}

	return Temp;
}

Gene* Data::AddGene(string Filename) {
	Gene*& Temp = GeneDatabaseLinks["FILENAME"][Filename];
	if (Temp == NULL) {
		Temp = new Gene(Filename,this);
		if (Temp->FKill()) {
			delete Temp;
			Temp = NULL;
			return NULL;
		}
		if (GetData("NAME",STRING).length() > 0) {
			Temp->AddData(GetData("NAME",STRING).data(),Temp->GetData("DATABASE",STRING).data(),DATABASE_LINK);
		}
		Temp->SetEntry(FNumGenes()+1);
		Temp->SetIndex(FNumGenes());
		InsertGeneDatabaseLinks(Temp);
		GeneList.push_back(Temp);
		GeneIT = GeneList.begin();
		LastGeneIndex = 0;
	}

	return Temp;
}

Species* Data::AddSpecies(vector<string>* InHeaders, string Fileline) {
	Species* NewSpecies = new Species(InHeaders, Fileline,this);

	return AddSpecies(NewSpecies);
}

Reaction* Data::AddReaction(vector<string>* InHeaders, string Fileline) {
	Reaction* NewReaction = new Reaction(InHeaders, Fileline,this);

	return AddReaction(NewReaction);
}

Species* Data::AddStructuralCue(vector<string>* InHeaders, string Fileline) {
	Species* NewSpecies = new Species(InHeaders, Fileline,this,true);

	return AddStructuralCue(NewSpecies);
}

Species* Data::AddSpecies(Species* NewSpecies) {
	string ID = NewSpecies->GetData("DATABASE",STRING);
	Species* Temp = CpdDatabaseLinks["DATABASE"][ID];
	if (Temp == NULL) {
		Temp = NewSpecies;
		if (GetData("NAME",STRING).length() > 0) {
			Temp->AddData(GetData("NAME",STRING).data(),Temp->GetData("DATABASE",STRING).data(),DATABASE_LINK);
		}
		NewSpecies->SetEntry(FNumSpecies()+1);
		NewSpecies->SetIndex(FNumSpecies());
		InsertSpeciesDatabaseLinks(NewSpecies);
		SpeciesList.push_back(NewSpecies);
		SpeciesIT = SpeciesList.begin();
		LastSpeciesIndex = 0;
	} else {
		delete NewSpecies;
	}

	return Temp;
}

Reaction* Data::AddReaction(Reaction* NewReaction) {
	string ID = NewReaction->GetData("DATABASE",STRING);
	Reaction* Temp = RxnDatabaseLinks["DATABASE"][ID];
	if (Temp == NULL) {
		Temp = NewReaction;
		if (GetData("NAME",STRING).length() > 0) {
			Temp->AddData(GetData("NAME",STRING).data(),Temp->GetData("DATABASE",STRING).data(),DATABASE_LINK);
		}
		NewReaction->SetEntry(FNumReactions()+1);
		NewReaction->SetIndex(FNumReactions());
		InsertReactionDatabaseLinks(NewReaction);
		ReactionList.push_back(NewReaction);
		ReactionIT = ReactionList.begin();
		LastReactionIndex = 0;
	} else {
		if (Temp->FCompartment() != NewReaction->FCompartment()) {
			NewReaction->SetData("DATABASE",(ID+"["+GetCompartment(NewReaction->FCompartment())->Abbreviation+"]").data(),STRING);
			AddReaction(NewReaction);
		} else if (Temp->FType() != NewReaction->FType()) {
			if (NewReaction->FType() == FORWARD) {
				NewReaction->SetData("DATABASE",(ID+"=>").data(),STRING);
			} else if (NewReaction->FType() == REVERSE) {
				NewReaction->SetData("DATABASE",(ID+"<=").data(),STRING);
			} else {
				NewReaction->SetData("DATABASE",(ID+"<=>").data(),STRING);
			}
			AddReaction(NewReaction);
		} else {
			delete NewReaction;
		}
	}

	return Temp;
}

Species* Data::AddStructuralCue(Species* NewSpecies) {
	vector<string> Names = NewSpecies->GetAllData("NAME",STRING);
	Species* Temp = NULL;
	for (int i=0; i < int(Names.size()); i++) {
		Temp = CueDatabaseLinks["NAME"][Names[i]];
	}
	if (Temp == NULL) {
		Temp = NewSpecies;
		NewSpecies->SetEntry(FNumStructuralCues()+1);
		NewSpecies->SetIndex(FNumStructuralCues());
		InsertSpeciesDatabaseLinks(NewSpecies);
		StructuralCues.push_back(NewSpecies);
	} else {
		delete NewSpecies;
	}
	return Temp;
}

void Data::ClearGenes(int DeleteThem) {
	for (int i=0;i < FNumGenes(); i++) {
		if (DeleteThem == ALL || (DeleteThem == UNMARKED && !GetGene(i)->FMark())) {
			delete GetGene(i);
		}
	}

	GeneDatabaseLinks.clear();
	GeneList.clear();
	GeneIT = GeneList.begin();
	LastGeneIndex = 0;
}

void Data::ClearCompounds(int DeleteThem) {
	for (int i=0;i < FNumSpecies(); i++) {
		if (DeleteThem == ALL || (DeleteThem == UNMARKED && !GetSpecies(i)->FMark())) {
			delete GetSpecies(i);
		}
	}

	CpdDatabaseLinks.clear();
	SpeciesList.clear();
	SpeciesIT = SpeciesList.begin();
	LastSpeciesIndex = 0;
}

void Data::ClearReactions(int DeleteThem) {
	for (int i=0;i < FNumReactions(); i++) {
		if (DeleteThem == ALL || (DeleteThem == UNMARKED && !GetReaction(i)->FMark())) {
			delete GetReaction(i);
		}
	}

	RxnDatabaseLinks.clear();
	ReactionList.clear();
	ReactionIT = ReactionList.begin();
	LastReactionIndex = 0;
}

void Data::ClearStructuralCues() {
	for (int i=0;i < FNumStructuralCues(); i++) {
		delete GetStructuralCue(i);
	}

	CueDatabaseLinks.clear();
	StructuralCues.clear();
}

void Data::ResetAllBools(bool NewMark, bool ResetMark, bool NewKill, bool ResetKill, bool ResetReactions, bool ResetSpecies, bool ResetCues) {
	if (ResetSpecies) {
		for (int i=0; i < FNumSpecies(); i++) {
			if (ResetMark) {
				GetSpecies(i)->SetMark(NewMark);
			} 
			if (ResetKill) {
				GetSpecies(i)->SetKill(NewKill);
			}
		}
	}
	if (ResetReactions) {
		for (int i=0; i < FNumReactions(); i++) {
			if (ResetMark) {
				GetReaction(i)->SetMark(NewMark);
			}
			if (ResetKill) {
				GetReaction(i)->SetKill(NewKill);
			}
		}
	}
	if (ResetCues) {
		for (int i=0; i < FNumStructuralCues(); i++) {
			if (ResetMark) {
				GetStructuralCue(i)->SetMark(NewMark);
			}
			if (ResetKill) {
				GetStructuralCue(i)->SetKill(NewKill);
			}
		}
	}
}

void Data::AddCompartment(int InIndex) {
	if (InIndex > 0 && InIndex < FNumCompartments()) {
		RepresentedCompartments[InIndex] = true;
	}
}

void Data::RemoveMarkedReactions(bool DeleteThem) {
	RemoveMarkedFunctor<Reaction> RemovalFunctor;
	RemovalFunctor.DeleteThem = DeleteThem;
	ReactionList.remove_if(RemovalFunctor);
}

void Data::RemoveMarkedSpecies(bool DeleteThem) {
	RemoveMarkedFunctor<Species> RemovalFunctor;
	RemovalFunctor.DeleteThem = DeleteThem;
	SpeciesList.remove_if(RemovalFunctor);
}

void Data::InsertSpeciesDatabaseLinks(Species* InSpecies) {
	InsertCombinedData(InSpecies->GetCombinedData(STRING),InSpecies,NULL,NULL);
	InsertCombinedData(InSpecies->GetCombinedData(DATABASE_LINK),InSpecies,NULL,NULL);
	if (InSpecies->FCue()) {
		CueDatabaseLinks["ENTRY"][itoa(InSpecies->FEntry())] = InSpecies;
	} else {
		CpdDatabaseLinks["ENTRY"][itoa(InSpecies->FEntry())] = InSpecies;
	}
}

void Data::InsertReactionDatabaseLinks(Reaction* InReaction) {
	InsertCombinedData(InReaction->GetCombinedData(STRING),NULL,InReaction,NULL);
	InsertCombinedData(InReaction->GetCombinedData(DATABASE_LINK),NULL,InReaction,NULL);
	RxnDatabaseLinks["ENTRY"][itoa(InReaction->FEntry())] = InReaction;
}

void Data::InsertGeneDatabaseLinks(Gene* InGene) {
	InsertCombinedData(InGene->GetCombinedData(STRING),NULL,NULL,InGene);
	InsertCombinedData(InGene->GetCombinedData(DATABASE_LINK),NULL,NULL,InGene);
	GeneDatabaseLinks["ENTRY"][itoa(InGene->FEntry())] = InGene;
}

void Data::InsertCombinedData(string InData, Species* InSpecies, Reaction* InReaction, Gene* InGene) {
	vector<string>* DatabaseLinkList = StringToStrings(InData,"\t");
	for (int i = 0; i < int(DatabaseLinkList->size()); i++) {
		vector<string>* SingleDBList = StringToStrings((*DatabaseLinkList)[i],":");
		for (int j=1; j < int(SingleDBList->size()); j++) {
			if ((*SingleDBList)[0].compare("INPUT_HEADER") != 0) {
				if (InSpecies != NULL && InSpecies->FCue()) {
					Species*& Temp = CueDatabaseLinks[(*SingleDBList)[0]][(*SingleDBList)[j]];
					if (Temp == NULL) {
						Temp = InSpecies;
					} else {
						InSpecies->AddData("LINK",(*SingleDBList)[0].data(),STRING,false);
						InSpecies->AddData((*SingleDBList)[0].data(),double(Temp->FIndex()),false);
					}
				} else if (InSpecies != NULL) {
					Species*& Temp = CpdDatabaseLinks[(*SingleDBList)[0]][(*SingleDBList)[j]];
					if (Temp == NULL) {
						Temp = InSpecies;
					} else {
						InSpecies->AddData("LINK",(*SingleDBList)[0].data(),STRING,false);
						InSpecies->AddData("LINK_ID",double(Temp->FIndex()),false);
					}
				} else if (InReaction != NULL) {
					Reaction*& Temp = RxnDatabaseLinks[(*SingleDBList)[0]][(*SingleDBList)[j]];
					if (Temp == NULL) {
						Temp = InReaction;
					} else {
						InReaction->AddData("LINK",(*SingleDBList)[0].data(),STRING,false);
						InReaction->AddData("LINK_ID",double(Temp->FIndex()),false);
					}
				} else if (InGene != NULL) {
					Gene*& Temp = GeneDatabaseLinks[(*SingleDBList)[0]][(*SingleDBList)[j]];
					if (Temp == NULL) {
						Temp = InGene;
					} else {
						InGene->AddData("LINK",(*SingleDBList)[0].data(),STRING,false);
						InGene->AddData("LINK_ID",double(Temp->FIndex()),false);
					}
				}
			}
		}
		delete SingleDBList;
	}
	delete DatabaseLinkList;
}

void Data::ReindexSpecies() {
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->SetIndex(i);
	}
}

void Data::ReindexReactions() {
	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->SetIndex(i);
	}
}

void Data::ClearSpeciesDatabaseLinks() {
	CpdDatabaseLinks.clear();
}

void Data::LoadGeneIntervals() {
	ifstream Input;
	string MFAInputFilename = GetDatabaseDirectory(GetParameter("database"),"root directory")+GetParameter("interval experiment list file");
	if (!OpenInput(Input,MFAInputFilename)) {
		return;
	}
	
	do {
		vector<string>* Strings = GetStringsFileline(Input,"\t _");
		if (Strings->size() >= 3) {
			//Setting the total number of genes for the interval
			int TotalGenes = 0;
			if (Strings->size() >= 5) {
				TotalGenes = atoi((*Strings)[4].data());
			}
			double Growth = atof((*Strings)[3].data());
			//Initializing the interval object
			GeneInterval* NewInterval = new GeneInterval(atoi((*Strings)[0].data()),atoi((*Strings)[1].data()),TotalGenes,Growth,this);
			//Saving the interval name
			NewInterval->AddData("NAME",(*Strings)[2].data(),STRING);
			//Adding the interval by name to the interval name map
			IntervalNameMap[(*Strings)[2]] = NewInterval;
			//Adding the interval to the gene intervals vector
			GeneIntervals.push_back(NewInterval);
		}
		delete Strings;
	} while(!Input.eof());

	Input.close();
}

void Data::AddAlias(int Type,string One,string Two) {
	string MappedName = Two;
	string OriginalName = One;
	if (Type == GENE) {
		Gene* Current = FindGene("DATABASE;NAME",One.data());
		Gene* Other = FindGene("DATABASE;NAME",Two.data());
		if (Current == NULL) {
			Current = FindGene("DATABASE;NAME",Two.data());
			Other = NULL;
			MappedName = One;
			OriginalName = Two;
		}
		if (Current != NULL) {
			if (Other != NULL && Current != Other) {
				FErrorFile() << MappedName << " previously mapped to " << Other->GetData("DATABASE",STRING) << " now mapped to " << Current->GetData("DATABASE",STRING) << " via " << OriginalName << endl;
				FlushErrorFile();
			}
			GeneDatabaseLinks["NAME"][MappedName] = Current;
		} else {
			FErrorFile() << MappedName << " and " << OriginalName << " not found." << endl;
			FlushErrorFile();
		}
	} else if (Type == COMPOUND) {
		Species* Current = FindSpecies("DATABASE;NAME",One.data());
		Species* Other = FindSpecies("DATABASE;NAME",Two.data());
		if (Current == NULL) {
			Current = FindSpecies("DATABASE;NAME",Two.data());
			Other = NULL;
			MappedName = One;
			OriginalName = Two;
		}
		if (Current != NULL) {
			if (Other != NULL && Current != Other) {
				FErrorFile() << MappedName << " previously mapped to " << Other->GetData("DATABASE",STRING) << " now mapped to " << Current->GetData("DATABASE",STRING) << " via " << OriginalName << endl;
				FlushErrorFile();
			}
			CpdDatabaseLinks["NAME"][MappedName] = Current;
		} else {
			FErrorFile() << MappedName << " and " << OriginalName << " not found." << endl;
			FlushErrorFile();
		}
	} else if (Type == REACTION) {
		Reaction* Current = FindReaction("DATABASE;NAME",One.data());
		Reaction* Other = FindReaction("DATABASE;NAME",Two.data());
		if (Current == NULL) {
			Current = FindReaction("DATABASE;NAME",Two.data());
			Other = NULL;
			MappedName = One;
			OriginalName = Two;
		}
		if (Current != NULL) {
			if (Other != NULL && Current != Other) {
				FErrorFile() << MappedName << " previously mapped to " << Other->GetData("DATABASE",STRING) << " now mapped to " << Current->GetData("DATABASE",STRING) << " via " << OriginalName << endl;
				FlushErrorFile();
			}
			RxnDatabaseLinks["NAME"][MappedName] = Current;
		} else {
			FErrorFile() << MappedName << " and " << OriginalName << " not found." << endl;
			FlushErrorFile();
		}
	}
};

void Data::LoadGeneDictionary() {
	string Filename = GetDatabaseDirectory(GetParameter("database"),"input directory")+GetParameter("Gene dictionary");
	if (FileExists(Filename)) {
		vector< vector<string> >* GeneDictionaryData = LoadMultipleColumnFile(Filename,";");
		for (int i=0; i < int(GeneDictionaryData->size()); i++) {
			if ((*GeneDictionaryData)[i].size() > 1) {
				Gene* CurrentGene = NULL;
				for (int j=0; j < int((*GeneDictionaryData)[i].size()); j++) {
					CurrentGene = FindGene("DATABASE;NAME",(*GeneDictionaryData)[i][j].data());
					if (CurrentGene != NULL) {
						break;
					}
				}
				if (CurrentGene == NULL) {
					CurrentGene = AddGene((*GeneDictionaryData)[i][0]);
				}
				for (int j=0; j < int((*GeneDictionaryData)[i].size()); j++) {
					if ((*GeneDictionaryData)[i][j].compare(CurrentGene->GetData("DATABASE",STRING)) != 0) {
						AddAlias(GENE,CurrentGene->GetData("DATABASE",STRING),(*GeneDictionaryData)[i][j]);
					}
				}	
			}
		}
		delete GeneDictionaryData;
	}
};

//Output
Species* Data::GetStructuralCue(int InIndex) {
	return StructuralCues[InIndex];
};

int Data::FNumStructuralCues() {
	return int(StructuralCues.size());
};

Species* Data::GetSpecies(int InIndex) {
	if (InIndex < LastSpeciesIndex) {
		LastSpeciesIndex = 0;
		SpeciesIT = SpeciesList.begin();
	}
	
	for (int i = LastSpeciesIndex; i < InIndex; i++) {
		SpeciesIT++;
		LastSpeciesIndex++;
	}
	return (*SpeciesIT);
};

int Data::FNumSpecies() {
	return int(SpeciesList.size());
};

Reaction* Data::GetReaction(int InIndex) {
	if (InIndex < LastReactionIndex || InIndex == 0 || LastReactionIndex == 0) {
		LastReactionIndex = 0;
		ReactionIT = ReactionList.begin();
	}
	
	for (int i = LastReactionIndex; i < InIndex; i++) {
		ReactionIT++;
		LastReactionIndex++;
	}
	return (*ReactionIT);
};

int Data::FNumReactions() {
	return int(ReactionList.size());
};

Gene* Data::GetGene(int InIndex) {
	if (InIndex < LastGeneIndex || InIndex == 0 || LastGeneIndex == 0) {
		LastGeneIndex = 0;
		GeneIT = GeneList.begin();
	}
	
	for (int i = LastGeneIndex; i < InIndex; i++) {
		GeneIT++;
		LastGeneIndex++;
	}
	return (*GeneIT);
};	

int Data::FNumGenes() {
	return int(GeneList.size());
};

int Data::FNumGeneIntervals() {
	return int(GeneIntervals.size());
}

GeneInterval* Data::GetGeneInterval(int InIndex) {
	if (InIndex >= FNumGeneIntervals()) {
		FErrorFile() << "Interval index too high." << endl;
		FlushErrorFile();
		return NULL;
	}
	return GeneIntervals[InIndex];
}

GeneInterval* Data::FindInterval(string InIntervalName) {
	return IntervalNameMap[InIntervalName];
}

int Data::FNumFullMoleculeGroups() {
	return int(SortedMoleculeGroups.size());
};

Species* Data::GetFullMoleculeGroup(int InIndex) {
	return SortedMoleculeGroups[InIndex];
};

int Data::FNumSearchableGroups() {
	return int(SortedSearchableGroups.size());
};

Species* Data::GetSearchableGroup(int InIndex) {
	return SortedSearchableGroups[InIndex];
};

bool Data::CompartmentRepresented(int InIndex) {
	if (InIndex > 0 && InIndex < FNumCompartments()) {
		return RepresentedCompartments[InIndex];
	}
	return false;
}

Species* Data::FindSpecies(const char* DatabaseName,const char* DataID) {
	string StrDataID(DataID);
	string StrDBName(DatabaseName);
	vector<string>* Strings = StringToStrings(StrDBName,";");
	for (int i=0; i < int(Strings->size()); i++) {
		Species* Temp = CpdDatabaseLinks[(*Strings)[i]][StrDataID];
		if (Temp != NULL) {
			delete Strings;
			return Temp;
		}
	}
	delete Strings;
	return NULL;	
}

Reaction* Data::FindReaction(const char* DatabaseName,const char* DataID) {
	string StrDataID(DataID);
	string StrDBName(DatabaseName);
	vector<string>* Strings = StringToStrings(StrDBName,";");
	for (int i=0; i < int(Strings->size()); i++) {
		Reaction* Temp = RxnDatabaseLinks[(*Strings)[i]][StrDataID];
		if (Temp != NULL) {
			delete Strings;
			return Temp;
		}
	}
	delete Strings;
	return NULL;
}

Species* Data::FindStructuralCue(const char* DatabaseName,const char* DataID) {
	string StrDataID(DataID);
	string StrDBName(DatabaseName);
	vector<string>* Strings = StringToStrings(StrDBName,";");
	for (int i=0; i < int(Strings->size()); i++) {
		Species* Temp = CueDatabaseLinks[(*Strings)[i]][StrDataID];
		if (Temp != NULL) {
			delete Strings;
			return Temp;
		}
	}
	delete Strings;
	return NULL;
}

Gene* Data::FindGene(const char* DatabaseName,const char* DataID) {
	string StrDataID(DataID);
	string StrDBName(DatabaseName);
	vector<string>* Strings = StringToStrings(StrDBName,";");
	for (int i=0; i < int(Strings->size()); i++) {
		Gene* Temp = GeneDatabaseLinks[(*Strings)[i]][StrDataID];
		if (Temp != NULL) {
			delete Strings;
			return Temp;
		}
	}
	delete Strings;
	return NULL;
}

Species* Data::GetHydrogenSpecies() {
	if (HydrogenSpecies == NULL) {
		for (int i=0; i < FNumSpecies(); i++) {
			if (GetSpecies(i)->FFormula().compare("H") == 0 && GetSpecies(i)->FCharge() == 1) {
				HydrogenSpecies = GetSpecies(i);
				break;
			}
		}
	}
	
	return HydrogenSpecies;
}

//Analysis functions
void Data::PerformAllRequestedTasks() {
	if (GetParameter("Generate subnetwork").compare("1") == 0) {
		GenerateBNICESubnetwork();
	}
	if (GetParameter("search for pathways").compare("1") == 0) {
		SearchForPathways();
	}
	if (GetParameter("Sequence genes").compare("1") == 0) {
		SequenceGenes();
	}
	if (GetParameter("perform MFA").compare("1") == 0) {
		PerformMFA();
	}
	if (GetParameter("poll structural cues").compare("1") == 0) {
		PollStructuralCues();
	}
	if (GetParameter("identify dead ends").compare("1") == 0) {
		FindDeadEnds();
	}
	if (GetParameter("print model data").compare("1") == 0) {
		PrintRequestedData();
	}
	if (GetParameter("print model network").compare("1") == 0) {
		LabelKEGGCofactorPairs();
		PrintReactionNetwork();
	}
}

//This function is necessary for sorting the cycles by size
bool PathwayGreater ( Pathway* One, Pathway* Two ) {
	return One->Length < Two->Length;
}

map<Species* , list<Pathway*> , std::less<Species*> >* Data::FindPathways(Species* Source, vector<Species*> Targets, int MaxLength, int TimeInterval, bool AddReverseConnections, int LengthInterval, int &ClockIndex) {
	Node* CurrentNode = NULL;
	vector<Node*> MyTree(FNumSpecies());

	//I create and initialize the tree climber which explores the network looking for pathways
	TreeClimber* NewClimber = new TreeClimber;
	NewClimber->NodesVisited = new bool[FNumSpecies()];
	for (int i=0; i < int(FNumSpecies()); i++) {
		GetSpecies(i)->SetMark(false);
		Node* NewNode = new Node;
		NewNode->ID = i;
		NewNode->Identity = GetSpecies(i);
		GetSpecies(i)->SetIndex(i);
		NewClimber->NodesVisited[i] = false;
		MyTree[i] = NewNode;
	}
	for (int i=0; i < int(FNumReactions()); i++) {
		for (int j=0; j < GetReaction(i)->FNumReactants(REACTANT); j++) {
			if (!GetReaction(i)->IsReactantCofactor(j)) {
				for (int k=GetReaction(i)->FNumReactants(REACTANT); k < GetReaction(i)->FNumReactants(); k++) {
					if (!GetReaction(i)->IsReactantCofactor(k)) {
						MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->Children.push_back(MyTree[GetReaction(i)->GetReactant(k)->FIndex()]);
						MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->EdgeLables.push_back(GetReaction(i));
						MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->ForwardDirection.push_back(true);
					}
				}
			}
		}
		if (AddReverseConnections) {
			for (int j=GetReaction(i)->FNumReactants(REACTANT); j < GetReaction(i)->FNumReactants(); j++) {
				if (!GetReaction(i)->IsReactantCofactor(j)) {
					for (int k=0; k < GetReaction(i)->FNumReactants(REACTANT); k++) {
						if (!GetReaction(i)->IsReactantCofactor(k)) {
							MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->Children.push_back(MyTree[GetReaction(i)->GetReactant(k)->FIndex()]);
							MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->EdgeLables.push_back(GetReaction(i));
							MyTree[GetReaction(i)->GetReactant(j)->FIndex()]->ForwardDirection.push_back(false);
						}
					}
				}
			}
		}
	}

	for (int i=0; i < MAX_PATH_LENGTH; i++) {
		NewClimber->CurrentPathway[i] = NULL;
		NewClimber->CurrentPathEdgeLabels[i] = NULL;
		NewClimber->CurrentPathEdgeDirections[i] = true;
	}
	NewClimber->CurrentPathLength = 0;
	NewClimber->NumberOfPaths = 0;

	for (int i=0; i < int(Targets.size()); i++) {
		Targets[i]->SetMark(true);
		Targets[i]->PathwayMark = -1;
	}

	ClockIndex = StartClock(ClockIndex);
	SetTimeout(ClockIndex,atof(GetParameter("max search time").data()));
	
	map<Species* , list<Pathway*> , std::less<Species*> >* Pathways = new map<Species* , list<Pathway*> , std::less<Species*> >;
	CurrentNode = MyTree[Source->FIndex()];

	//I initialize the starting and target node.
	do {
		if (TimedOut(ClockIndex)) {
			break;
		}
		int CurrentPathLength = NewClimber->CurrentPathLength;
		//If this is a new node, then we enter into the code block below and initialize everything.
		if (NewClimber->NodesVisited[CurrentNode->ID] == false) {
			NewClimber->CurrentPathway[CurrentPathLength] = CurrentNode;
			NewClimber->CurrentPathwayIterators[CurrentPathLength] = CurrentNode->Children.begin();
			NewClimber->CurrentPathwayLabelIterators[CurrentPathLength] = CurrentNode->EdgeLables.begin();
			NewClimber->CurrentPathwayDirectionIterators[CurrentPathLength] = CurrentNode->ForwardDirection.begin();
			NewClimber->NodesVisited[CurrentNode->ID] = true;
		}
		
		//If this is the target node, I save the pathway data for printing later.
		if (CurrentNode->Identity->FMark()) {
			bool Shortest = false;
			if (CurrentNode->Identity->PathwayMark == -1 || CurrentNode->Identity->PathwayMark > CurrentPathLength) {
				Shortest = true;
				CurrentNode->Identity->PathwayMark = CurrentPathLength;
			}
			if (LengthInterval >= (NewClimber->CurrentPathLength - CurrentNode->Identity->PathwayMark)) {
				NewClimber->NumberOfPaths++;
				Pathway* NewPathway = new Pathway;
				NewPathway->Length = NewClimber->CurrentPathLength;
				NewPathway->Intermediates = new Species*[NewPathway->Length+1];
				NewPathway->Reactions = new Reaction*[NewPathway->Length];
				NewPathway->Directions = new bool[NewPathway->Length];
				NewPathway->Intermediates[0] = NewClimber->CurrentPathway[0]->Identity;
				NewPathway->OverallReaction = new Reaction("",this);
				for (int i=1; i <= NewPathway->Length; i++) {
					NewPathway->Intermediates[i] = NewClimber->CurrentPathway[i]->Identity;
					NewPathway->Reactions[i-1] = NewClimber->CurrentPathEdgeLabels[i-1];
					NewPathway->Directions[i-1] = NewClimber->CurrentPathEdgeDirections[i-1];
					for (int j=0; j < NewClimber->CurrentPathEdgeLabels[i-1]->FNumReactants(); j++) {
						NewPathway->OverallReaction->AddReactant(NewClimber->CurrentPathEdgeLabels[i-1]->GetReactant(j),NewClimber->CurrentPathEdgeLabels[i-1]->GetReactantCoef(j),NewClimber->CurrentPathEdgeLabels[i-1]->GetReactantCompartment(j),NewClimber->CurrentPathEdgeLabels[i-1]->IsReactantCofactor(j));
					}
				}

				(*Pathways)[CurrentNode->Identity].push_back(NewPathway);
			}
		}

		//I immediately retreat from this node if i have explored all of its children, if its the target node, or if I'm already at my pathway length limit.
		if (CurrentPathLength == MaxLength || NewClimber->CurrentPathwayIterators[CurrentPathLength] == CurrentNode->Children.end() || CurrentNode->Identity->FMark()) {
			NewClimber->CurrentPathway[CurrentPathLength] = NULL;
			NewClimber->CurrentPathEdgeLabels[CurrentPathLength] = NULL;
			NewClimber->CurrentPathEdgeDirections[CurrentPathLength] = true;
			NewClimber->NodesVisited[CurrentNode->ID] = false;
			NewClimber->CurrentPathLength--;
			if (CurrentPathLength != -1) {
				CurrentNode = NewClimber->CurrentPathway[NewClimber->CurrentPathLength];
			}
		} else {
			//Setting everything up to explore the node's child.
			if (!NewClimber->NodesVisited[(*NewClimber->CurrentPathwayIterators[CurrentPathLength])->ID]) {
				//Changing the current node to the node child.
				CurrentNode = (*NewClimber->CurrentPathwayIterators[CurrentPathLength]);
				//Changing the iterator and pathlength
				NewClimber->CurrentPathEdgeLabels[CurrentPathLength] = (*NewClimber->CurrentPathwayLabelIterators[CurrentPathLength]);
				NewClimber->CurrentPathEdgeDirections[CurrentPathLength] = (*NewClimber->CurrentPathwayDirectionIterators[CurrentPathLength]);
				NewClimber->CurrentPathwayIterators[CurrentPathLength]++;
				NewClimber->CurrentPathwayLabelIterators[CurrentPathLength]++;
				NewClimber->CurrentPathwayDirectionIterators[CurrentPathLength]++;
				NewClimber->CurrentPathLength++;
			} else {
				NewClimber->CurrentPathwayIterators[CurrentPathLength]++;
				NewClimber->CurrentPathwayLabelIterators[CurrentPathLength]++;
				NewClimber->CurrentPathwayDirectionIterators[CurrentPathLength]++;
			}
		}
	} while(NewClimber->CurrentPathLength != -1);

	map<Species* , list<Pathway*> >::iterator MapIt = Pathways->begin();
	for (int i=0; i < int(Pathways->size()); i++) {
		RemovePathsOutsideLengthInterval RemovalFunctor;
		RemovalFunctor.LengthInterval = LengthInterval;
		RemovalFunctor.ShortestPathLength = int(MapIt->first->PathwayMark);
		MapIt->second.remove_if(RemovalFunctor);
		MapIt->second.sort(PathwayGreater);
		MapIt++;
	}

	for (int i=0; i < int(FNumSpecies()); i++) {
		delete MyTree[i];
	}

	delete [] NewClimber->NodesVisited;
	delete NewClimber;
	
	return Pathways;
}

void Data::SearchForPathways() {
	vector<string>* TargetStrings = StringToStrings(GetParameter("pathway starting compounds"),";");
	
	vector<Species*> Sources;
	vector<Species*> Targets;
	if (GetParameter("Remove pathways with unqualified overall reactions").compare("1") == 0) {
		for (int i=0; i < FNumSpecies(); i++) {
			GetSpecies(i)->SetKill(true);
			if (GetSpecies(i)->GetGenericData(GetParameter("Qualified intermediates database").data()).length() > 0) {
				GetSpecies(i)->SetKill(false);
			}
		}
	}
	
	for (int i=0; i < int(TargetStrings->size()); i++) {
		Species* TempCompound = FindSpecies("NAME;DATABASE;ENTRY",(*TargetStrings)[i].data());
		if (TempCompound == NULL) {
			FErrorFile() << "Source compound for pathway search " << (*TargetStrings)[i] << " not found in system." << endl;
			FlushErrorFile();
		} else {
			Sources.push_back(TempCompound);
			TempCompound->SetKill(false);
		}
	}

	delete TargetStrings;
	TargetStrings = StringToStrings(GetParameter("pathway target compounds"),";");
	for (int i=0; i < int(TargetStrings->size()); i++) {
		Species* TempCompound = FindSpecies("NAME;DATABASE;ENTRY",(*TargetStrings)[i].data());
		if (TempCompound == NULL) {
			FErrorFile() << "Target compound for pathway search " << (*TargetStrings)[i] << " not found in system." << endl;
			FlushErrorFile();
		} else {
			Targets.push_back(TempCompound);
			TempCompound->SetKill(false);
		}
	}
	
	map<string, Reaction*, std::less<string> > DistinctOverallReactions;
	map<string, int, std::less<string> > OverallReactionShortestLength;
	map<Species* , map<Species*, vector<string>, std::less<Species*> >, std::less<Species*> > TargetSourceOverReactions;

	int MaxLength = atoi(GetParameter("max pathway length").data());
	int LengthInterval = atoi(GetParameter("max length interval").data());
	int MaxTime = atoi(GetParameter("max search time").data());
	for (int i=0; i < int(Sources.size()); i++) {
		for (int j=0; j < int(Targets.size()); j++) {
			vector<Species*> TempTarget;
			TempTarget.push_back(Targets[j]);
			int ClockIndex = -1;
			map<Species* , list<Pathway*> , std::less<Species*> >* Pathways = FindPathways(Sources[i], TempTarget, MaxLength, MaxTime, false, LengthInterval,ClockIndex);
			if (TimedOut(ClockIndex)) {
				cout << Sources[i]->GetData("DATABASE",STRING) << " " << Targets[j]->GetData("DATABASE",STRING) << " timeout!" << endl;			
			} else {
				cout << Sources[i]->GetData("DATABASE",STRING) << " " << Targets[j]->GetData("DATABASE",STRING) << endl;			
			}
			ClearClock(ClockIndex);
			if (GetParameter("Print overall reaction data").compare("1") == 0) {
				for (map<Species* , list<Pathway*> , std::less<Species*> >::iterator MapIT = Pathways->begin(); MapIT != Pathways->end(); MapIT++) {
					for (list<Pathway*>::iterator ListIT = MapIT->second.begin(); ListIT != MapIT->second.end(); ListIT++) {
						if (!(*ListIT)->OverallReaction->ContainsKilledReactants()) { 
							(*ListIT)->OverallReaction->MakeCode("DATABASE",false);
							if (DistinctOverallReactions[(*ListIT)->OverallReaction->FCode()] == NULL) {
								OverallReactionShortestLength[(*ListIT)->OverallReaction->FCode()] = (*ListIT)->Length;
								DistinctOverallReactions[(*ListIT)->OverallReaction->FCode()] = (*ListIT)->OverallReaction;
								TargetSourceOverReactions[MapIT->first][Sources[i]].push_back((*ListIT)->OverallReaction->FCode());
							} else if ((*ListIT)->Length < OverallReactionShortestLength[(*ListIT)->OverallReaction->FCode()]) {
								OverallReactionShortestLength[(*ListIT)->OverallReaction->FCode()] = (*ListIT)->Length;
							}
						}
					}
				}
			}
			PrintPathways(Pathways,Sources[i]);
			delete Pathways;
		}
	}

	if (GetParameter("Print overall reaction data").compare("1") == 0) {
		string PathwayPath(FOutputFilepath());
		PathwayPath.append("Pathways/OverallReactions.txt");
		ofstream Output;
		if (!OpenOutput(Output,PathwayPath)) {
			return;
		}
		
		for (map<Species* , map<Species*, vector<string>, std::less<Species*> >, std::less<Species*> >::iterator MapIT = TargetSourceOverReactions.begin(); MapIT != TargetSourceOverReactions.end(); MapIT++) {
			Output << "Overall reactions for pathways producing:\t" << MapIT->first->GetData("DATABASE",STRING) << endl;
			for (map<Species*, vector<string>, std::less<Species*> >::iterator MapITT = MapIT->second.begin(); MapITT != MapIT->second.end(); MapITT++) {
				Output << "Overall reactions for pathways emerging from:\t" << MapITT->first->GetData("DATABASE",STRING) << endl;
				for (int i=0; i < int(MapITT->second.size()); i++) {
					Output << DistinctOverallReactions[MapITT->second[i]]->CreateReactionEquation(GetParameter("Qualified intermediates database")) << ";" << OverallReactionShortestLength[MapITT->second[i]] << endl;
				}
			}
		}

		Output.close();
	}
}

void Data::PerformMFA() {
	MakeDirectory((FOutputFilepath()+"MFAOutput/").data());
	
	//Reading in the user-set parameters for the MFA
	OptimizationParameter* NewParameters = ReadParameters();
	
	cout << "Parameters read" << endl;
	//Creating MFA problem object
	MFAProblem* NewProblem = new MFAProblem();

	//Running the gap generation
	if (GetParameter("Perform gap generation").compare("1") == 0) {
		NewProblem->GapGeneration(this,NewParameters);
		ClearParameters(NewParameters);
		delete NewProblem;
		return;
	}

	//Running the solution reconciliation
	if (GetParameter("Perform solution reconciliation").compare("1") == 0) {
		NewProblem->SolutionReconciliation(this,NewParameters);
		ClearParameters(NewParameters);
		delete NewProblem;
		return;
	}

	//Fitting microarray data
	if (GetParameter("Microarray assertions").length() > 0 && GetParameter("Microarray assertions").compare("NONE") != 0) {
		NewProblem->FitMicroarrayAssertions(this);
		delete NewProblem;
		return;
	}

	//Fitting gimme data
	if (GetParameter("Gene Inactivity Moderated by Metabolism and Expression").length() > 0 && GetParameter("Gene Inactivity Moderated by Metabolism and Expression").compare("NONE") != 0) {
		NewProblem->FitGIMME(this);
		delete NewProblem;
		return;
	}

	//Do soft constraint, then report flux.
	if (GetParameter("Soft Constraint").length() > 0 && GetParameter("Soft Constraint").compare("NONE") != 0) {
		NewProblem->SoftConstraint(this);
		delete NewProblem;
		return;
	}

	//Generating pathways to objective
	if (GetParameter("Generate pathways to objective").compare("1") == 0) {
		NewProblem->GenerateMinimalReactionLists(this);
		delete NewProblem;
		return;
	}	

	//Running the gap filling
	if (GetParameter("Perform gap filling").compare("1") == 0) {
		//Writing the header to the gap filling solution table
		if (!FileExists(FOutputFilepath()+"GapFillingSolutionTable.txt")) {
			ofstream Output;
			OpenOutput(Output,FOutputFilepath()+"GapFillingSolutionTable.txt");
			Output << "Experiment;Solution index;Solution cost;Solution reactions" << endl;
			Output.close();
			Output.clear();
			OpenOutput(Output,FOutputFilepath()+"GapFillingReport.txt");
			Output << "Run label;Number of solutions;SolutionCosts;Solutions;media;reaction KO" << endl;
			Output.close();
		}
		SetParameter("Reactions knocked out in gap filling","none");
		
		//Running the gap filling algorithm
		if (GetParameter("Complete gap filling").compare("1") == 0) {
			NewProblem->CompleteGapFilling(this,NewParameters);
			ClearParameters(NewParameters);
			delete NewProblem;
		} else if (GetParameter("Gap filling runs").compare("none") == 0) {
			NewProblem->GapFilling(this,NewParameters);
			ClearParameters(NewParameters);
			delete NewProblem;
		} else {
			vector<string>* Runs = StringToStrings(GetParameter("Gap filling runs"),";");
			vector<string> OriginalKOReaction = NewParameters->KOReactions;
			for (int i =0; i < int(Runs->size()); i++) {
				//Parsing run specification into label, media, and reaction list
				vector<string>* RunData = StringToStrings((*Runs)[i],":");
				vector<string>* ReactionList = StringToStrings((*RunData)[2],",");
				//Setting the media
				SetParameter("Reactions knocked out in gap filling",(*RunData)[2].data());
				NewParameters->UserBounds = ReadBounds((*RunData)[1].data());
				if (NewParameters->UserBounds != NULL) {
					for (int j=0; j < int(ReactionList->size()); j++) {
						if ((*ReactionList)[j].compare("none") != 0 && FindReaction("DATABASE",(*ReactionList)[j].data()) != NULL) {
							NewParameters->KOReactions.push_back((*ReactionList)[j]);
						}
					}
					//Running the gap filling
					NewProblem->GapFilling(this,NewParameters,(*RunData)[0]);
					//Deleting the vectors
					delete ReactionList;
					delete RunData;
					//Restoring the KO list
					NewParameters->KOReactions = OriginalKOReaction;
				} else {
					FErrorFile() << "Could not load media " << (*RunData)[1] << endl;
					FlushErrorFile();
				}
			}
			ClearParameters(NewParameters);
			delete NewProblem;
			delete Runs;
		}
		return;
	}
	//Building MFA object based on user settings and database
	NewProblem->BuildMFAProblem(this,NewParameters);

	double ObjectiveValue = FLAG;
	if (GetParameter("run media experiments").compare("1") == 0) {
		NewProblem->RunMediaExperiments(this,NewParameters,ObjectiveValue,GetParameter("maximize single objective").compare("1") == 0,GetParameter("find tight bounds").compare("1") == 0,GetParameter("Minimize the number of foreign reactions").compare("1") == 0,GetParameter("maximize individual metabolite production").compare("1") == 0);	
		ClearParameters(NewParameters);
		delete NewProblem;
		return;
	}

	if (NewParameters->DoRecursiveMILPStudy && GetParameter("maximize single objective").compare("1") != 0) {
		NewProblem->RecursiveMILPStudy(this,NewParameters,false);
	}

	if (GetParameter("identify type 3 pathways").compare("1") == 0) {
		NewProblem->IdentifyReactionLoops(this,NewParameters);
	}
	
	if (GetParameter("maximize single objective").compare("1") == 0) {
		string Note;
		NewParameters->RelaxIntegerVariables = (GetParameter("relax integer variables when possible").compare("1") == 0);
		NewProblem->OptimizeSingleObjective(this,NewParameters,GetParameter("objective"),GetParameter("find tight bounds").compare("1") == 0,GetParameter("Minimize the number of foreign reactions").compare("1") == 0,ObjectiveValue,Note);	
	}

	if (GetParameter("run reaction addition experiments").compare("1") == 0) {
		NewProblem->OptimizeIndividualForeignReactions(this,NewParameters,GetParameter("find tight bounds").compare("1") == 0,GetParameter("maximize individual metabolite production").compare("1") == 0);
	}

	if (GetParameter("maximize single objective").compare("1") == 0 && GetParameter("run exploration experiments").compare("1") == 0) {
		NewProblem->ExploreSplittingRatios(this,NewParameters,GetParameter("find tight bounds").compare("1") == 0,GetParameter("Minimize the number of foreign reactions").compare("1") == 0);	
	}

	//Finding tight bounds if the user has requested
	if (GetParameter("find tight bounds").compare("1") == 0 && GetParameter("maximize single objective").compare("1") != 0) {
		string Note;
		NewProblem->FindTightBounds(this,NewParameters,Note);
	}

	if (NewParameters->DoFluxCouplingAnalysis && GetParameter("run media experiments").compare("1") != 0 && GetParameter("maximize single objective").compare("1") != 0) {
		string Note;
		NewProblem->FluxCouplingAnalysis(this,NewParameters,true,Note,false);
	}

	if (GetParameter("maximize individual metabolite production").compare("1") == 0) {
		string Note;
		NewProblem->CheckIndividualMetaboliteProduction(this,NewParameters,GetParameter("metabolites to optimize"),GetParameter("find tight bounds").compare("1") == 0,GetParameter("Minimize the number of foreign reactions").compare("1") == 0,Note,false);
	}

	if (GetParameter("optimize individual foreign reactions").compare("1") == 0 && GetParameter("Load foreign reaction database").compare("1") == 0) {
		string Note;
		NewProblem->OptimizeIndividualForeignReactions(this,NewParameters,GetParameter("find tight bounds").compare("1") == 0,GetParameter("maximize individual metabolite production").compare("1") == 0);
	}
	//Clearing memmory
	ClearParameters(NewParameters);
	delete NewProblem;
}

void Data::PollStructuralCues() {
	string Filename = FOutputFilepath();
	Filename.append("GroupPoll.txt");
	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}
	
	for (int i=0; i < FNumStructuralCues(); i++) {
		GetStructuralCue(i)->AddData("count unique compounds",0);
		GetStructuralCue(i)->AddData("count compound instances",0);
		GetStructuralCue(i)->AddData("count unique reactions",0);
		GetStructuralCue(i)->AddData("count reaction instances",0);
	}

	for (int i=0; i < FNumSpecies(); i++) {
		for (int j=0; j < GetSpecies(i)->FNumStructuralCues(); j++) {
			GetSpecies(i)->GetStructuralCue(j)->AddData("count unique compounds",GetSpecies(i)->GetStructuralCue(j)->GetDoubleData("count unique compounds")+1);
			GetSpecies(i)->GetStructuralCue(j)->AddData("count compound instances",GetSpecies(i)->GetStructuralCue(j)->GetDoubleData("count compound instances")+GetSpecies(i)->GetStructuralCueNum(j));
		}
	}

	for (int i=0; i < FNumReactions(); i++) {
		for (int j=0; j < GetReaction(i)->FNumStructuralCues(); j++) {
			GetReaction(i)->GetStructuralCue(j)->AddData("count unique reactions",GetReaction(i)->GetStructuralCue(j)->GetDoubleData("count unique reactions")+1);
			GetReaction(i)->GetStructuralCue(j)->AddData("count reaction instances",GetReaction(i)->GetStructuralCue(j)->GetDoubleData("count reaction instances")+abs(GetReaction(i)->GetStructuralCueNum(j)));
		}
	}
	
	Output << "Group name;Energy;Number of compounds;Number of instances in compounds;Number of reactions;Number of instances in reactions;Total compounds and reactions;Total instances" << endl;
	for (int i=0; i < FNumStructuralCues(); i++) {
		Output << GetStructuralCue(i)->GetData("NAME",STRING) << ";" << GetStructuralCue(i)->FEstDeltaG() << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count unique compounds") << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count compound instances") << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count unique reactions") << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count reaction instances") << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count unique reactions") + GetStructuralCue(i)->GetDoubleData("count unique compounds") << ";";
		Output << GetStructuralCue(i)->GetDoubleData("count reaction instances") + GetStructuralCue(i)->GetDoubleData("count compound instances") << endl;
	}

	Output.close();
}

void Data::ProcessEntireDatabase() {
	//Processing compounds first
	if (GetParameter("Calculations:compounds:process list").compare("NONE") != 0) {
		string Database = GetParameter("database to process");
		SetData("DATABASE",Database.data(),STRING);
		SetData("FILENAME",Database.data(),STRING);
		int FilenameLength = atoi(QueryTextDatabase("database",Database,"compound filename length").data());
		string FilenamePrefix = QueryTextDatabase("database",Database,"compound filename prefix");
		string input = GetParameter("Calculations:compounds:process list");
		vector<string> ids;
		if (input.compare("ALL") == 0) {
			ids = GetDirectoryFileList(GetDatabaseDirectory(Database,"compound directory"));
		} else if (input.length() > 5 && input.substr(0,5).compare("LIST:") == 0) {
			string input = input.substr(5);
			ids = (*StringToStrings(input, ";",true));
		} else {
			ids = ReadStringsFromFile(input,false);
		}
		//Loading each compound and performing all calculations
		for (int i=0; i < int(ids.size()); i++) {
			if (ids[i].compare("Filenames.txt") != 0 && ids[i].compare("Combined.txt") != 0) {
				if (FilenameLength == -1 || FilenameLength == ids[i].length()) {
					if (FilenamePrefix.compare("NONE") == 0 || (ids[i].length() >= FilenamePrefix.length() && ids[i].substr(0,FilenamePrefix.length()).compare(FilenamePrefix) == 0)) {
						Species* NewSpecies = new Species(ids[i],this,false);
						NewSpecies->AddData(Database.data(),NewSpecies->GetData("DATABASE",STRING).data(),DATABASE_LINK);
						NewSpecies->PerformAllCalculations(GetParameter("label atoms").compare("1") == 0,GetParameter("determine stringcode").compare("1") == 0,GetParameter("look for cycles").compare("1") == 0,GetParameter("calculate properties from groups").compare("1") == 0,GetParameter("determine formula from structure file").compare("1") == 0);
						AddSpecies(NewSpecies);
					}
				}
			}
		}
		//Now I identify and note all of the compounds with identical 2D structures so I can eliminate synonymous compounds from the DB
		LabelKEGGSingleCofactors();
		if (GetParameter("Calculations:reactions:process list").compare("NONE") == 0) {
			IdentifyCompoundWithIdenticalStructures();
			for (int i=0; i < FNumSpecies(); i++) {
				GetSpecies(i)->SaveSpecies(GetSpecies(i)->GetData("FILENAME",STRING));
			}
		}
	}
	//Processing reactions second
	if (GetParameter("Calculations:reactions:process list").compare("NONE") != 0) {
		string Database = GetParameter("database to process");
		SetData("DATABASE",Database.data(),STRING);
		SetData("FILENAME",Database.data(),STRING);
		int FilenameLength = atoi(QueryTextDatabase("database",Database,"reaction filename length").data());
		string FilenamePrefix = QueryTextDatabase("database",Database,"reaction filename prefix");
		string input = GetParameter("Calculations:reactions:process list");
		vector<string> ids;
		if (input.compare("ALL") == 0) {
			ids = GetDirectoryFileList(GetDatabaseDirectory(Database,"reaction directory"));
		} else if (input.length() > 5 && input.substr(0,5).compare("LIST:") == 0) {
			input = input.substr(5,input.length()-5);
			vector<string>* temp = StringToStrings(input, ";",true);
			ids = (*temp);
			delete temp;
		} else {
			ids = ReadStringsFromFile(input,false);
		}
		//Now I load each reaction file, run all requested calculations, and save the file again
		for (int i=0; i < int(ids.size()); i++) {
			if (ids[i].compare("Filenames.txt") != 0 && ids[i].compare("Combined.txt") != 0) {
				if (FilenameLength == -1 || FilenameLength == ids[i].length()) {
					if (FilenamePrefix.compare("NONE") == 0 || (ids[i].length() >= FilenamePrefix.length() && ids[i].substr(0,FilenamePrefix.length()).compare(FilenamePrefix) == 0)) {
						Reaction* NewReaction = new Reaction(ids[i],this);
						NewReaction->AddData(Database.data(),NewReaction->GetData("DATABASE",STRING).data(),DATABASE_LINK);
						AddReaction(NewReaction);
					}
				}
			}
		}
		MergeReactants();
		for (int i=0; i < FNumReactions(); i++) {
			GetReaction(i)->PerformAllCalculations();
		}
		LabelKEGGCofactorPairs();
		for (int i=0; i < FNumSpecies(); i++) {
			GetSpecies(i)->SaveSpecies(GetSpecies(i)->GetData("FILENAME",STRING));
		}
		IdentifyCompoundWithIdenticalStructures();
		for (int i=0; i < FNumReactions(); i++) {
			GetReaction(i)->SaveReaction(GetReaction(i)->GetData("FILENAME",STRING));
		}
	}
}

//Identifies the dead end metabolites and reactions in the model
void Data::FindDeadEnds() {
	ResetAllBools(false,true,false,false,true,true,false);
	bool NewMarks = false;
	
	int DeadCompounds = 0;
	int DeadReactions = 0;
	vector<Species*> DeadEnds;

	do {
		NewMarks = false;
		for (int i=0; i < FNumSpecies(); i++) {
			if (!GetSpecies(i)->FMark() && GetSpecies(i)->PropagateMarks()) {
				NewMarks = true;
			}
		}
	}while(NewMarks == true);

	ofstream Output;
	string Filename(FOutputFilepath());
	Filename.append("DeadEndMetabolites.txt");
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FKill()) {
			DeadCompounds++;
			GetSpecies(i)->AddData("DEAD","yes",STRING);
			GetSpecies(i)->AddData("CLASS","DEADEND",STRING);
			Output << GetSpecies(i)->GetData("DATABASE",STRING) << endl;
		}
	}

	Output.close();

	Filename.assign(FOutputFilepath());
	Filename.append("DeadMetabolites.txt");
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FMark()) {
			DeadCompounds++;
			GetSpecies(i)->AddData("DEAD","yes",STRING);
			GetSpecies(i)->AddData("CLASS","DEAD",STRING);
			Output << GetSpecies(i)->GetData("DATABASE",STRING) << endl;
		}
	}

	Output.close();

	Filename.assign(FOutputFilepath());
	Filename.append("ExtracellularMetabolites.txt");
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FExtracellular()) {
			Output << GetSpecies(i)->GetData("DATABASE",STRING) << endl;
		}
	}

	Output.close();

	Filename.assign(FOutputFilepath());
	Filename.append("DeadReactions.txt");
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	for (int i=0; i < FNumReactions(); i++) {
		if (GetReaction(i)->FMark()) {
			DeadReactions++;
			GetReaction(i)->AddData("CLASS","DEAD",STRING);
			GetReaction(i)->AddData("DEAD","yes",STRING);
			Output << GetReaction(i)->GetData("DATABASE",STRING) << endl;
		}
	}

	Output.close();

	AddData("DEAD COMPOUNDS",double(DeadCompounds));
	AddData("DEAD REACTIONS",double(DeadReactions));
}

//This function identifies every set of compounds that share a common 2-D structure based on the stringcode
void Data::IdentifyCompoundWithIdenticalStructures() {
	map<string, vector<Species*>, std::less<string> > StringcodeMap;

	//First I input all of the species into the stringcode map
	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FCode().length() > 0) {
			StringcodeMap[GetSpecies(i)->FCode()].push_back(GetSpecies(i));
		}
	}

	ofstream Output;
	string Filename(FOutputFilepath());
	Filename.append("CompoundSetsWithCommonStructures.txt");
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	//Now I search through the stringcode map to identify species with common structures
	for (map<string, vector<Species*>, std::less<string> >::iterator MapIT = StringcodeMap.begin(); MapIT != StringcodeMap.end(); MapIT++) {
		if (MapIT->second.size() > 1) {
			int NumItems = 0;
			int First = -1;
			int TotalReactions = 0;
			for	(int i=0; i < int(MapIT->second.size()); i++) {
				TotalReactions = TotalReactions + MapIT->second[i]->FNumReactions();
				if (MapIT->second[i]->FNumReactions() > 0) {
					NumItems++;
					if (First == -1) {
						First = i;
					}
				}
			}
			if (NumItems > 1) {
				Output << TotalReactions << "\t" << MapIT->second[First]->GetData("DATABASE",STRING) << ";" << MapIT->second[First]->GetData("NAME",STRING) << ";" << MapIT->second[First]->FNumReactions();
				for	(int i=First+1; i < int(MapIT->second.size()); i++) {
					if (MapIT->second[i]->FNumReactions() > 0) {
						Output << "\t" << MapIT->second[i]->GetData("DATABASE",STRING) << ";" << MapIT->second[i]->GetData("NAME",STRING) << ";" << MapIT->second[i]->FNumReactions();
					}
				}
				Output << endl;
			}
		}
	}

	Output.close();
}

void Data::LabelKEGGSingleCofactors() {
	AddData("COFACTORS LABELED","YES",STRING);
	vector<string>* KEGGCofactors = StringToStrings(GetParameter("kegg cofactors"),";");

	for (int i=0; i < int(KEGGCofactors->size()); i++) {
		Species* Temp = FindSpecies("DATABASE",(*KEGGCofactors)[i].data());
		if (Temp != NULL) {
			Temp->SetCofactor(true);
		}
	}

	delete KEGGCofactors;
}

void Data::LabelKEGGCofactorPairs() {
	AddData("COFACTORS LABELED","YES",STRING);
	vector<string>* KEGGCofactorPairs = StringToStrings(GetParameter("kegg cofactor pairs"),";");
	
	for (int i=0; i < int(KEGGCofactorPairs->size()); i++) {
		vector<string>* CofactorPair = StringToStrings((*KEGGCofactorPairs)[i]," ");
		if (CofactorPair->size() >= 2) {
			Species* Temp = FindSpecies("DATABASE",(*CofactorPair)[0].data());
			Species* TempTwo = FindSpecies("DATABASE",(*CofactorPair)[1].data());
			if (Temp != NULL && TempTwo != NULL) {
				for (int j=0; j < FNumReactions(); j++) {
					if (GetReaction(j)->GetReactantCoef(Temp)*GetReaction(j)->GetReactantCoef(TempTwo) < 0) {
						GetReaction(j)->SetReactantToCofactor(GetReaction(j)->CheckForReactant(Temp), true);
						GetReaction(j)->SetReactantToCofactor(GetReaction(j)->CheckForReactant(TempTwo), true);
					}
				}
			}
		}
		delete CofactorPair;
	}
	delete KEGGCofactorPairs;
}

void Data::MergeReactants() {
	vector<string>* MergedReactantSets = StringToStrings(GetParameter("reactants to merge"),";");
	
	for (int i=0; i < int(MergedReactantSets->size()); i++) {
		vector<string>* ReactantSet = StringToStrings((*MergedReactantSets)[i]," ");
		if (ReactantSet->size() >= 2) {
			Species* Replacer = FindSpecies("DATABASE",(*ReactantSet)[0].data());
			if (Replacer != NULL) {
				for (int k=1; k < int(ReactantSet->size()); k++) {
					Species* Replaced = FindSpecies("DATABASE",(*ReactantSet)[k].data());
					if (Replaced != NULL) {
						string NewComment("Merged into compound: ");
						NewComment.append((*ReactantSet)[0]);
						Replaced->AddData("COMMENTS",NewComment.data(),STRING);
						for (int j=0; j < FNumReactions(); j++) {
							int ReactantIndex = GetReaction(j)->CheckForReactant(Replaced);
							while (ReactantIndex != -1) {
								bool Cofactor = GetReaction(j)->IsReactantCofactor(ReactantIndex);
								double Coefficient = GetReaction(j)->GetReactantCoef(ReactantIndex);
								int Compartment = GetReaction(j)->GetReactantCompartment(ReactantIndex);
								GetReaction(j)->RemoveCompound(Replaced,Compartment);
								GetReaction(j)->AddReactant(Replacer,Coefficient,Compartment,Cofactor);
								ReactantIndex = GetReaction(j)->CheckForReactant(Replaced);
							}
						}
					}
				}
			}
		}
		delete ReactantSet;
	}
	delete MergedReactantSets;
}

//This function is utilized by the web interface for the group contribution method
void Data::RunWebGCM(string InputFilename,string OutputFilename) {
	ifstream Input;
	ofstream Output;
	if (!OpenInput(Input,InputFilename)) {
		return;
	}
	if (!OpenOutput(Output,OutputFilename)) {
		return;
	}
	
	int Count = 0;
	Output << "ESTIMATED ENERGY;ESTIMATE UNCERTAINTY;GROUPS;MOLECULAR CHARGE DETERMINED FROM GROUPS;MOLECULAR CHARGE FROM INPUT FILE;MOLECULAR FORMULA;NOTES" << endl;
	bool NewMolfile = false;
	do {
		//Reading in a molfile
		string EmptyFilename;
		Species* NewSpecies = new Species(EmptyFilename,this);
		NewSpecies->ReadFromMol(Input);
		
		if (NewSpecies->FNumAtoms() == 0) {
			delete NewSpecies;
			Output << "Error reading in molecular structure. No atoms read in. Check molfile." << endl;
			break;
		}

		//Read in the molecule data
		NewMolfile = false;
		do {
			vector<string>* Strings = GetStringsFileline(Input, " ><");
			if (Strings->size() > 0 && (*Strings)[0].length() >=4 && (*Strings)[0].substr(0,4).compare("$$$$") == 0) {
				NewMolfile = true;
			}
			delete Strings;
		} while (NewMolfile == false && !Input.eof());

		int MolfileCharge = NewSpecies->FCharge();
		NewSpecies->PerformAllCalculations(true,true,true,true, true);
		map<string, string, std::less<string> > StringTranslation = LoadStringTranslation(GetParameter("input directory")+"GroupTranslation.txt",";");
		if (NewSpecies->FEstDeltaG() == FLAG || NewSpecies->FNumNoIDGroups() > 0) {
			Output << "NONE;NONE;";
		} else {
			Output << NewSpecies->FEstDeltaG() << ";" << 2*NewSpecies->FEstDeltaGUncertainty() << ";";
		}	

		string UnknownEnergyGroups;
		for (int i=0; i < NewSpecies->FNumStructuralCues(); i++) {
			string Temp = StringTranslation[NewSpecies->GetStructuralCue(i)->GetData("NAME",STRING)];
			if (Temp.length() == 0) {
				Temp = NewSpecies->GetStructuralCue(i)->GetData("NAME",STRING);
			}
			Output << Temp << ":" << NewSpecies->GetStructuralCueNum(i) << "|";
			if (NewSpecies->GetStructuralCue(i)->FEstDeltaG() == -10000 && NewSpecies->GetStructuralCue(i)->GetData("NAME",STRING).compare("NoGroup") != 0) {
				UnknownEnergyGroups.append(Temp);
				UnknownEnergyGroups.append(":");
				UnknownEnergyGroups.append(itoa(NewSpecies->GetStructuralCueNum(i)));
				UnknownEnergyGroups.append("|");
			}
		}
	
		Output << NewSpecies->FCharge() << ";" << MolfileCharge << ";" << NewSpecies->FFormula() << ";";
		
		if (NewSpecies->FNumNoIDGroups() > 0) {
			Output << "Formation energy not estimated due to the presence of " << NewSpecies->FNumNoIDGroups() << " atoms that could not be assigned to any of the existing set of structural groups. ";
		}
		if (UnknownEnergyGroups.length() > 0) {
			Output << "Formation energy not estimated due to the presence of the following structural groups with unknown group contribution energies: " << UnknownEnergyGroups;
		}
		if (NewSpecies->FNumNoIDGroups() == 0 && UnknownEnergyGroups.length() == 0) {
			Output << "No special notes for this compound.";
		}

		Output << endl;
		Count++;
		delete NewSpecies;
	} while (NewMolfile && Count < 10000);

	Output.close();
	Input.close();
} //End of function: RunWebGCM(string InputFilename,string OutputFilename, int CoumpoundLimit)

//This function sets the order parameters of the gene objects to the sequence of the gene in the organism genome. Also sets the neighbors of the gene if they are present. Also converts neighboring genes assigned to the same reaction into complexes.
void Data::SequenceGenes() {
	//Sequencing gene pointers by their starting coordinates
	map<double, Gene*, std::less<double> > GeneSequence;
	for (int i=0; i < FNumGenes(); i++) {
		if (GetGene(i)->GetDoubleData("START COORD") != FLAG) {
			GeneSequence[GetGene(i)->GetDoubleData("START COORD")] = GetGene(i);
		}
	}
	double GeneNeighborThreshold = atof(GetParameter("Gene neighbor threshold").data());
	double CurrentGene = 0;
	Gene* PreviousGene = NULL;

	//Setting gene order and setting gene neighbors
	for (map<double, Gene*, std::less<double> >::iterator MapIT = GeneSequence.begin(); MapIT != GeneSequence.end(); MapIT++) {
		MapIT->second->AddData("GENE NUMBER",CurrentGene);
		if (PreviousGene != NULL && PreviousGene->GetDoubleData("END COORD") != FLAG && MapIT->second->GetDoubleData("START COORD") != FLAG && MapIT->second->GetDoubleData("START COORD") - PreviousGene->GetDoubleData("END COORD") < GeneNeighborThreshold) {
			double GapSize = MapIT->second->GetDoubleData("START COORD") - PreviousGene->GetDoubleData("END COORD");
			PreviousGene->AddData("FORWARD NEIGHBOR",MapIT->second->GetData("DATABASE",STRING).data(),STRING);
			PreviousGene->AddData("FORWARD GAP",GapSize);
			MapIT->second->AddData("PREVIOUS NEIGHBOR",PreviousGene->GetData("DATABASE",STRING).data(),STRING);
			MapIT->second->AddData("PREVIOUS GAP",GapSize);
		}
		PreviousGene = MapIT->second;
		CurrentGene++;
	}

	//Combining neighboring genes assigned to the same reaction into a complex
	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->FormGeneComplexesFromNeighbors();
	}
}

void Data::IdentifyCompoundsByStringcode() {
	string TranslationFileName(GetParameter("input directory")+GetParameter("stringcode translation file"));
	
	vector<string> TranslationLines = ReadStringsFromFile(TranslationFileName,false);

	map<string, string, std::less<string> > StringcodeMap;
	for (int i=0; i < int(TranslationLines.size()); i++) {
		vector<string>* Strings = StringToStrings(TranslationLines[i], "\t");
		if (Strings->size() >= 2) {
			StringcodeMap[(*Strings)[0]] = (*Strings)[1];
		}
		delete Strings;
	}

	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->ReplaceCoAWithFullMolecule();
		GetSpecies(i)->SetCode(GetSpecies(i)->CreateStringcode(false, false));
		if (StringcodeMap.count(GetSpecies(i)->FCode()) > 0) {
			string CompoundID = StringcodeMap[GetSpecies(i)->FCode()];
			Species* NewSpecies = new Species(CompoundID,this);
			GetSpecies(i)->ParseCombinedData(NewSpecies->GetCombinedData(DATABASE_LINK),DATABASE_LINK);
			GetSpecies(i)->SetData("DATABASE",NewSpecies->GetData("DATABASE",STRING).data(),STRING);
			vector<string> Names = NewSpecies->GetAllData("NAME",STRING);
			for (int j=0; j < int(Names.size()); j++) {
				GetSpecies(i)->AddData("NAME",Names[j].data(),STRING);
			}
			delete NewSpecies;
		}
	}
}

void Data::AutomaticallyCreateGeneIntervals(OptimizationParameter* InParameters) {
	//First we should clear any existing intervals
	IntervalNameMap.clear();
	GeneIntervals.clear();
	Gene* StartingGene = NULL;
	for (int i=0; i < FNumGenes(); i++) {
		GetGene(i)->ClearIntervals();
		if (StartingGene == NULL && GetGene(i)->GetDoubleData("START COORD") != FLAG) {
			StartingGene = GetGene(i);
		}
		//Marking the genes that are mentioned in constraints
		GetGene(i)->SetMark(false);
		for (int i=0; i < int(InParameters->UnviableIntervalCombinations.size()); i++) {
			for (int j=0; j < int(InParameters->UnviableIntervalCombinations[i].size()); j++) {
				if (GetGene(i)->GetData("DATABASE",STRING).compare(InParameters->UnviableIntervalCombinations[i][j]) == 0) {
					GetGene(i)->SetMark(true);
				}
			}
		}
	}
	//Next we iterate around the genome creating an interval for every continuous segment of nonessential/nonmetabolic/nonconstrained genes
	Gene* CurrentGene = StartingGene;
	vector<Gene*> CurrentIntervalGeneList;
	bool First = true;
	do {
		if (CurrentGene->FNumReactions() == 0 && CurrentGene->GetData("ESSENTIAL",STRING).compare("Kobyashi et al.") != 0 && !CurrentGene->FMark()) {
			if (!First) {
				CurrentIntervalGeneList.push_back(CurrentGene);
			}
		} else {
			//I set first to true which will allow me to start creating intervals since I know I am not currently in the middle of an interval
			if (First) {
				First = false;
				StartingGene = CurrentGene;
			} else if (CurrentIntervalGeneList.size() > 0) {
				//Creating a new interval out of the list
				GeneInterval* NewInterval = new GeneInterval(int(CurrentIntervalGeneList[0]->GetDoubleData("START COORD")),int(CurrentIntervalGeneList[CurrentIntervalGeneList.size()-1]->GetDoubleData("END COORD")),int(CurrentIntervalGeneList.size()),-1,this);
				GeneIntervals.push_back(NewInterval);
				string IntervalName(itoa(NewInterval->FStartCoord()));
				IntervalName.append("_");
				IntervalName.append(itoa(NewInterval->FEndCoord()));
				NewInterval->AddData("NAME",IntervalName.data(),STRING);
				NewInterval->AddData("DATABASE",IntervalName.data(),STRING);
				IntervalNameMap[IntervalName] = NewInterval;
				//Clearing the list so the new interval may begin
				CurrentIntervalGeneList.clear();
			}
		}
		CurrentGene = CurrentGene->NextGene();
	} while (CurrentGene != StartingGene);
}

void Data::GenerateBNICESubnetwork() {
	vector<string>* AllowedRules = StringToStrings(GetParameter("Allowed reaction rules"),";");

	Data* Subnetwork = new Data(0);

	//First seed the starting network
	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->GetDoubleData("GENERATION",0) == 0) {
			GetSpecies(i)->SetMark(true);
			Subnetwork->AddSpecies(GetSpecies(i));
		}
	}

	//Now we progressively build out the subnetwork by expanding marked species
	bool Changes = true;
	int Generation = 1;
	while (Changes) {
		Changes = false;
		for (int i=0; i < FNumReactions(); i++) {
			if (!GetReaction(i)->FMark() && GetReaction(i)->AllReactantsMarked()) {			
				vector<string> OperatorList = GetReaction(i)->GetAllData("OPERATORS",STRING);
				bool Match = false;
				for (int j=0; j < int(OperatorList.size()); j++) {
					bool CompleteMatch = true;
					vector<string>* SubOperators = StringToStrings(OperatorList[j],"+");
					for (int k=0; k < int(SubOperators->size()); k++) {
						bool MatchFound = false;
						for (int m=0; m < int(AllowedRules->size()); m++) {
							if ((*AllowedRules)[m].compare((*SubOperators)[k]) == 0) {
								MatchFound = true;
								break;
							}
						}
						if (!MatchFound) {
							CompleteMatch = false;
							break;
						}
					}
					delete SubOperators;
					if (CompleteMatch) {
						Match = true;
						break;
					}
				}
				if (Match) {
					GetReaction(i)->SetMark(true);
					GetReaction(i)->SetData("GENERATION",double(Generation));
					Subnetwork->AddReaction(GetReaction(i));
					for (int k=GetReaction(i)->FNumReactants(REACTANT); k < GetReaction(i)->FNumReactants(); k++) {
						if (!GetReaction(i)->GetReactant(k)->FMark()) {
							GetReaction(i)->GetReactant(k)->SetKill(true);
							GetReaction(i)->GetReactant(k)->SetData("GENERATION",double(Generation));
							Changes = true;
						}
					}
				}
			}
		}
		for (int i=0; i < FNumSpecies();i++) {
			if (GetSpecies(i)->FKill()) {
				GetSpecies(i)->SetKill(false);
				GetSpecies(i)->SetMark(true);
				Subnetwork->AddSpecies(GetSpecies(i));
			}
		}
		Generation++;
	}

	Subnetwork->PrintRequestedData();

	delete Subnetwork;
	delete AllowedRules;
}

//File output
//This function creates the database file which consists of a single text file listing all of the reactions and/or compounds that make up this database
int Data::SaveSystem() {
	ofstream Output;
	
	//I'm assuming we will store all reaction or peg lists (which basically amount to databases) in some directory somewhere
	string Filename = "New"+GetData("FILENAME",STRING);
	if (GetData("ParentDB",STRING).length() > 0) {
		Filename = GetDatabaseDirectory(GetData("ParentDB",STRING),"model directory") + Filename;
	} else {
		Filename = GetDatabaseDirectory(GetParameter("database"),"model directory") + Filename;
	}

	//This code snippet adds the file extension
	if (Filename.length() < 4 || Filename.substr(Filename.length()-4,4).compare(".txt") != 0) {
		Filename.append(".txt");
	}

	if (!OpenOutput(Output,Filename)) {
		return FAIL;
	}

	//I save all reaction filenames to the file
	if (FNumReactions() > 0) {
		Output << "REACTIONS" << endl;
		for (int i=0; i < FNumReactions(); i++) {
			Output << GetReaction(i)->GetData("FILENAME",STRING) << endl;
		}
	}

	//I save all compound filenames to the file as well... although this is not necessary, it allows us to have databases that consist of only compounds
	if (FNumSpecies() > 0) {
		Output << "COMPOUNDS" << endl;
		for (int i=0; i < FNumSpecies(); i++) {
			Output << GetSpecies(i)->GetData("FILENAME",STRING) << endl;
		}
	}

	Output.close();

	return  SUCCESS;
}

//This function enables us to create the lumped reactions around parts of the metabolic network for which we donot have thermodynamic data
void Data::PrintLumpingExpaInputFile(string Filename) {
	int i;
	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	ResetAllBools(false,true,false,true,true,true,false);

	Output << "(Internal Fluxes)" << endl;
	for (i = 0; i < FNumReactions(); i++) {
		if (GetReaction(i)->ContainsStructuresWithNoEnergy()) {
			GetReaction(i)->PrintExpaInputFileLine(Output);
		}
	}
	Output << "(Exchange Fluxes)" << endl;
	for (i = 0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FMark()) {
			if (GetSpecies(i)->FEstDeltaG() != FLAG) {
				Output << GetSpecies(i)->GetData("NAME",STRING) << " Free" << endl;
			}
		}
		if (GetSpecies(i)->FKill()) {
			if (GetSpecies(i)->FEstDeltaG() != FLAG) {
				Output << GetSpecies(i)->GetData("NAME",STRING) << "[e] Free" << endl;
			}
		}
	}

	Output.close();
}

void Data::PrintNeutralFormulas() {
	string Filename(FOutputFilepath());
	Filename.append("NeutralFormulas.txt");

	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}	
	
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->SetFormulaToNeutral();
		Output << GetSpecies(i)->FFormula() << endl;
	}

	Output.close();
}

void Data::PrintRequestedData() {
	string Filename(FOutputFilepath());
	Filename.append(GetData("FILENAME",STRING));
	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	string FileHeader;
	if (GetParameter("print compounds").compare("1") == 0) {
		Output << "COMPOUNDS" << endl;
		FileHeader = GetParameter("compound data to print");
		Output << FileHeader << endl;
		vector<string>* Headers = StringToStrings(FileHeader,";");
		
		for (int i=0; i < FNumSpecies(); i++) {
			string Fileline = GetSpecies(i)->PrintRequestedDataToString(Headers);
			findandreplace(Fileline,"\t","|");
			Output << Fileline << endl;
		}	
	
		delete Headers;
	}

	if (GetParameter("print mol").compare("1") == 0) {
		string NewPath(FOutputFilepath());
		NewPath.append("mol/");
		for (int i=0; i < FNumSpecies(); i++) {
			GetSpecies(i)->PrintMol(NewPath);
		}	
	}

	if (GetParameter("print reactions").compare("1") == 0) {
		Output << "REACTIONS" << endl;
		FileHeader = GetParameter("reaction data to print");
		Output << FileHeader << endl;
		vector<string>* Headers = StringToStrings(FileHeader,";");
		
		for (int i=0; i < FNumReactions(); i++) {
			string Fileline = GetReaction(i)->PrintRequestedDataToString(Headers);
			findandreplace(Fileline,"\t","|");
			Output << Fileline << endl;
		}	
	
		delete Headers;
	}

	if (GetParameter("print structural cues").compare("1") == 0) {
		FileHeader = GetParameter("structural cue data to print");
		Output << FileHeader << endl;
		vector<string>* Headers = StringToStrings(FileHeader,";");
		
		for (int i=0; i < FNumStructuralCues(); i++) {
			Output << GetStructuralCue(i)->PrintRequestedDataToString(Headers);
			Output << endl;
		}	
	
		delete Headers;
	}
	
	Output.close();
}

void Data::PrintReactionNetwork() {
	bool PrintBipartite = false;
	bool PrintCofactors = false;
	if (GetParameter("Print bipartite network").compare("1") == 0) {
		PrintBipartite = true;
	}

	if (GetParameter("Print cofactors in network").compare("1") == 0) {
		PrintCofactors = true;
	}
	
	//I format the filename and open the network file
	string Filename(FOutputFilepath());
	Filename.append(GetData("FILENAME",STRING));
	if (Filename.length() > 4 && Filename.substr(Filename.length()-4,1).compare(".") == 0) {
		Filename = Filename.substr(0,Filename.length()-4);
	}
	Filename.append(".net");
	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	//I count out distinct compounds in the database that occur at least once as noncofactors in reactions
	int NumVectors = 1;
	vector<Species*> Verticies;
	vector<string> VertexCompartments;
	for (int i=0; i < FNumReactions(); i++) {
		for (int j=0; j < GetReaction(i)->FNumReactants(); j++) {
			if (PrintCofactors || !GetReaction(i)->IsReactantCofactor(j)) {
				string VertexID = "VERTEX";
				VertexID.append(GetCompartment(GetReaction(i)->GetReactantCompartment(j))->Abbreviation);
				if (GetReaction(i)->GetReactant(j)->GetDoubleData(VertexID.data()) == FLAG) {
					Verticies.push_back(GetReaction(i)->GetReactant(j));
					VertexCompartments.push_back(GetCompartment(GetReaction(i)->GetReactantCompartment(j))->Abbreviation);
					GetReaction(i)->GetReactant(j)->AddData(VertexID.data(),double(NumVectors));
					NumVectors++;
				}
			}
		}
	}
	NumVectors--;

	//I add the reaction vectors to the count
	if (PrintBipartite) {
		NumVectors = NumVectors-1+FNumReactions();
	}

	//I print the vertex line
	Output << "*Vertices " << NumVectors << endl;
	//I print the compound nodes
	vector<string>* Labels = StringToStrings(GetParameter("Compound labels"),";");
	for (int i=0; i < int(Verticies.size()); i++) {
		Output << i+1 << " " << '"';
		string LabelData;
		bool First = true;
		for (int j=0; j < int(Labels->size()); j++) {
			LabelData.assign(Verticies[i]->GetGenericData((*Labels)[j].data()));
			if (LabelData.length() > 0) {
				if (!First) {
					Output << ";";
				}
				First = false;
				Output << LabelData;
			}
		}
		Output << '"' << " ellipse ic ";
		if (VertexCompartments[i].compare("e") == 0) {
			Output << GetParameter("extracellular compound color");
		} else if (Verticies[i]->GetData("CLASS",STRING).compare("DEADEND") == 0) {
			Output << GetParameter("deadend compound color");
		} else if (Verticies[i]->GetData("CLASS",STRING).compare("DEAD") == 0) {
			Output << GetParameter("dead compound color");
		} else {
			Output << GetParameter("default compound color");
		}
		Output << endl;
	}
	delete Labels;

	//I print the reaction nodes if the user requested a bipartite network
	if (PrintBipartite) {
		Labels = StringToStrings(GetParameter("Reaction labels"),";");
		for (int i=0; i < FNumReactions(); i++) {
			Output << int(Verticies.size())+i+1 << ' "';
			GetReaction(i)->AddData("VERTEX",double(Verticies.size()+i+1));
			string LabelData;
			bool First = true;
			for (int j=0; j < int(Labels->size()); j++) {
				LabelData.assign(GetReaction(i)->GetGenericData((*Labels)[j].data()));
				if (LabelData.length() > 0) {
					if (!First) {
						Output << ";";
					}
					First = false;
					Output << LabelData;
				}
			}
			Output << '"' << " box ic ";
			if (GetReaction(i)->GetData("CLASS",STRING).compare("DEAD") == 0) {
				Output << GetParameter("dead reaction color");
			} else if (GetReaction(i)->GetData("CLASS",STRING).compare("ESSENTIAL") == 0) {
				Output << GetParameter("essential reaction color");
			} else if (GetReaction(i)->GetData("CLASS",STRING).compare("VARIABLE") == 0) {
				Output << GetParameter("variable reaction color");
			} else if (GetReaction(i)->GetData("CLASS",STRING).compare("BLOCKED") == 0) {
				Output << GetParameter("blocked reaction color");
			} else if (GetReaction(i)->GetData("CLASS",STRING).compare("OPTESSENTIAL") == 0) {
				Output << GetParameter("optimal essential reaction color");
			} else {
				Output << GetParameter("default reaction color");
			}
			Output << endl;
		}
		delete Labels;
	}

	Output << "*Arcs" << endl;
	if (PrintBipartite) {
		for (int i=0; i < FNumReactions(); i++) {
			for (int j=0; j < GetReaction(i)->FNumReactants(); j++) {
				if (PrintCofactors || !GetReaction(i)->IsReactantCofactor(j)) {
					string VertexID = "VERTEX";
					VertexID.append(GetCompartment(GetReaction(i)->GetReactantCompartment(j))->Abbreviation);
					if (GetReaction(i)->FType() == REVERSIBLE || (GetReaction(i)->FType() == FORWARD && GetReaction(i)->GetReactantCoef(j) < 0) ||  (GetReaction(i)->FType() == REVERSE && GetReaction(i)->GetReactantCoef(j) > 0)) {
						Output << GetReaction(i)->GetReactant(j)->GetDoubleData(VertexID.data()) << " " << GetReaction(i)->GetDoubleData("VERTEX") << " 1" << endl;
					}
					if (GetReaction(i)->FType() == REVERSIBLE || (GetReaction(i)->FType() == FORWARD && GetReaction(i)->GetReactantCoef(j) > 0) ||  (GetReaction(i)->FType() == REVERSE && GetReaction(i)->GetReactantCoef(j) < 0)) {
						Output << GetReaction(i)->GetDoubleData("VERTEX") << " " << GetReaction(i)->GetReactant(j)->GetDoubleData(VertexID.data()) << " 1" << endl;
					}
				}
			}
		}
	} else {
		Labels = StringToStrings(GetParameter("Reaction labels"),";");
		for (int i=0; i < FNumReactions(); i++) {
			for (int j=0; j < GetReaction(i)->FNumReactants(REACTANT); j++) {
				if (PrintCofactors || !GetReaction(i)->IsReactantCofactor(j)) {
					string Color;
					if (GetReaction(i)->GetData("CLASS",STRING).compare("DEAD") == 0) {
						Color = GetParameter("dead reaction color");
					} else if (GetReaction(i)->GetData("CLASS",STRING).compare("ESSENTIAL") == 0) {
						Color = GetParameter("essential reaction color");
					} else if (GetReaction(i)->GetData("CLASS",STRING).compare("VARIABLE") == 0) {
						Color = GetParameter("variable reaction color");
					} else if (GetReaction(i)->GetData("CLASS",STRING).compare("BLOCKED") == 0) {
						Color = GetParameter("blocked reaction color");
					} else if (GetReaction(i)->GetData("CLASS",STRING).compare("OPTESSENTIAL") == 0) {
						Color = GetParameter("optimal essential reaction color");
					} else {
						Color = GetParameter("default reaction color");
					}
					string Label;
					string LabelData;
					bool First = true;
					for (int k=0; k < int(Labels->size()); k++) {
						LabelData.assign(GetReaction(i)->GetGenericData((*Labels)[k].data()));
						if (LabelData.length() > 0) {
							if (!First) {
								Label.append(";");
							}
							First = false;
							Label.append(LabelData);
						}
					}
					string VertexID = "VERTEX";
					VertexID.append(GetCompartment(GetReaction(i)->GetReactantCompartment(j))->Abbreviation);
					for (int k=GetReaction(i)->FNumReactants(REACTANT); k < GetReaction(i)->FNumReactants(); k++) {
						if (PrintCofactors || !GetReaction(i)->IsReactantCofactor(k)) {
							string ProdVertexID = "VERTEX";
							ProdVertexID.append(GetCompartment(GetReaction(i)->GetReactantCompartment(k))->Abbreviation);
							if (GetReaction(i)->FType() == REVERSIBLE || GetReaction(i)->FType() == FORWARD) {
								Output << GetReaction(i)->GetReactant(j)->GetDoubleData(VertexID.data()) << " " << GetReaction(i)->GetReactant(k)->GetDoubleData(ProdVertexID.data()) << " 1 ";
								if (Label.length() > 0) {
									Output << " l " << '"' << Label << '"';
								}
								Output << " c " << Color << endl;
							}
							
							if (GetReaction(i)->FType() == REVERSIBLE || GetReaction(i)->FType() == REVERSE) {
								Output << GetReaction(i)->GetReactant(k)->GetDoubleData(ProdVertexID.data()) << " " << GetReaction(i)->GetReactant(j)->GetDoubleData(VertexID.data()) << " 1 ";
								if (Label.length() > 0) {
									Output << " l " << '"' << Label << '"';
								}
								Output << " c " << Color << endl;
							}
						}
					}
				}
			}
		}
		delete Labels;
	}

	Output << "*Edges" << endl;

	Output.close();
}

//In this function I do all of the preprocessing required for each Hope model
void Data::ProcessWebInterfaceModel() {	
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->LoadSpecies(GetSpecies(i)->GetData("DATABASE",STRING));
	}

	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->LoadReaction(GetReaction(i)->GetData("DATABASE",STRING));
	}

	PerformAllRequestedTasks();
}

void Data::PrintStructures() {
	string Path = FOutputFilepath();
	Path.append("mol/");
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->PrintMol(Path);
	}
}
