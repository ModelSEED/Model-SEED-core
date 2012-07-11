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

Reaction::Reaction(vector<string>* InHeaders, string Fileline, Data* InData) {
	EstDeltaG = FLAG;
	EstDeltaGUncertainty = FLAG;
	MainData = InData;
	SetIndex(InData->FNumReactions());
	SetEntry(InData->FNumReactions()+1);
	SetKill(false);
	SetMark(false);
	SetCode("");
	Type = REVERSIBLE; //Default is reversible
	NumReactants = 0;
	PathwayList = NULL;
	GeneRootNode = NULL;
	
	ReadFromFileline(InHeaders,Fileline);
	AddToReactants();
	PerformAllCalculations();
};

Reaction::Reaction(string Filename, Data* InData) {
	GeneRootNode = NULL;
	EstDeltaG = FLAG;
	EstDeltaGUncertainty = FLAG;
	MainData = InData;
	SetIndex(InData->FNumReactions());
	SetEntry(InData->FNumReactions()+1);
	SetKill(false);
	SetMark(false);
	SetCode("");
	SetData("STATUS","OK",STRING);
	Type = REVERSIBLE; //Default is reversible
	NumReactants = 0;
	PathwayList = NULL;
	if (Filename.length() > 0) {
		LoadReaction(Filename);
		AddToReactants();
	}
	PerformAllCalculations();
};

Reaction::~Reaction() {
	if (PathwayList != NULL) {
		list<Pathway*>::iterator ListIT = PathwayList->begin();
		for (int i=0; i < int(PathwayList->size()); i++) {
			delete [] (*ListIT)->Intermediates;
			delete [] (*ListIT)->Reactions;
			delete [] (*ListIT)->Directions;
			delete (*ListIT);
			ListIT++;
		}
		delete PathwayList;
	}

	for (int i=0; i < int(LogicNodes.size()); i++) {
		if (LogicNodes[i] != NULL) {
			delete LogicNodes[i];
		}
	}
};

//Input
void Reaction::AddReactant(Species* InReactant, double ICoef, int InCompartment, bool InCofactor) {
	if (MainData != NULL) {
		if (InCompartment == 100) {
			MainData->AddCompartment(Compartment);
		} else {
			MainData->AddCompartment(InCompartment);
		}
	}

	int OriginalCompartment = InCompartment;
	if (OriginalCompartment >= 1000) {
		OriginalCompartment = OriginalCompartment - 1000;
	}

	if (InCompartment == 100) {
		InReactant->AddCompartment(Compartment);
	} else {
		InReactant->AddCompartment(InCompartment);
	}
		
	if ((InReactant->FCofactor() || InCofactor) && InCompartment < 1000) {
		InCompartment = InCompartment + 1000;
	}

	if (ICoef == 0) {
		cout << "Coefficient of zero entered while parsing reaction: " << GetData("DATABASE",STRING) << endl;
	}

	for (int i = 0; i < int(Reactants.size()); i++) {
		if (InReactant == Reactants[i] && OriginalCompartment == GetReactantCompartment(i)) {
			if (ReactCoef[i] < 0) {
				NumReactants--;
			}
			double NewCoef = ReactCoef[i] + ICoef;
			Reactants.erase(Reactants.begin()+i,Reactants.begin()+i+1);
			ReactCoef.erase(ReactCoef.begin()+i,ReactCoef.begin()+i+1);
			ReactCompartments.erase(ReactCompartments.begin()+i,ReactCompartments.begin()+i+1);
			if (NewCoef != 0) {
				AddReactant(InReactant,NewCoef,InCompartment);
			}
			return;
		}
	}
	for (int i = 0; i < int(Reactants.size()); i++) {
		if (ICoef < 0) {
			if (ReactCoef[i] < 0 && InReactant->FEntry() < Reactants[i]->FEntry()) {
				NumReactants++;
				Reactants.insert(Reactants.begin()+i, InReactant);
				ReactCoef.insert(ReactCoef.begin()+i, ICoef);
				ReactCompartments.insert(ReactCompartments.begin()+i, InCompartment);
				return;
			}
			else if (ReactCoef[i] > 0) {
				Reactants.insert(Reactants.begin()+i, InReactant);
				ReactCoef.insert(ReactCoef.begin()+i, ICoef);
				ReactCompartments.insert(ReactCompartments.begin()+i, InCompartment);
				NumReactants++;
				return;
			}
		}
		if (ICoef > 0) {
			if (ReactCoef[i] > 0 && InReactant->FEntry() < Reactants[i]->FEntry()) {
				Reactants.insert(Reactants.begin()+i, InReactant);
				ReactCoef.insert(ReactCoef.begin()+i, ICoef);
				ReactCompartments.insert(ReactCompartments.begin()+i, InCompartment);
				return;
			}
		}
	}
	if (ICoef < 0) {
		NumReactants++;
	}
	Reactants.push_back(InReactant);
	ReactCoef.push_back(ICoef);
	ReactCompartments.push_back(InCompartment);
};

void Reaction::SetEstDeltaG(double InDG) {
	EstDeltaG = InDG;
};

void Reaction::AddComponentReaction(Reaction* InReaction, double Coeff) {
	ComponentReactions.push_back(InReaction);
	ComponentReactionCoeffs.push_back(Coeff);
};

void Reaction::AddStructuralCue(Species* InCue, double Coeff) {
	StructuralCues.push_back(InCue);
	NumStructuralCues.push_back(Coeff);
};

void Reaction::SetReactantToCofactor(int InIndex, bool Cofactor) {
	if (Cofactor) {
		if (ReactCompartments[InIndex] < 1000) {
			ReactCompartments[InIndex] += 1000;
		}
	} else {
		if (ReactCompartments[InIndex] >= 1000) {
			ReactCompartments[InIndex] += -1000;
		}
	}
};

void Reaction::RemoveCompound(Species* InSpecies, int InCompartment) {
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i) == InSpecies && GetReactantCompartment(i) == InCompartment) {
			if (ReactCoef[i] < 0) {
				NumReactants--;
			}
			Reactants.erase(Reactants.begin()+i,Reactants.begin()+i+1);
			ReactCoef.erase(ReactCoef.begin()+i,ReactCoef.begin()+i+1);
			ReactCompartments.erase(ReactCompartments.begin()+i,ReactCompartments.begin()+i+1);
			i--;
		}
	}
}

void Reaction::ResetReactant(int InIndex, Species* InSpecies) {
	Reactants[InIndex] = InSpecies;
};

void Reaction::SetType(int InType) {
	Type = InType;
};

void Reaction::SetCoef(Species* InSpecies, int InCompartment, double InCoeff) {
	int i;
	for (i=0; i < FNumReactants(); i++) {
		if (GetReactant(i) == InSpecies && GetReactantCompartment(i) == InCompartment) {
			ReactCoef[i] = InCoeff;
			return;
		}
	}
};

int Reaction::ParseReactionEquation(string InString) {
	//In case the reaction has the --> or <-- notation, I replace all instances of -- with =
	InString = StringReplace(InString.data(),"--","=");
	//Now I break up the reaction string into substrings using the delimiters []+=
	vector<string>* DataList = StringToStrings(InString, " []+=");
	//I set the type to reversible by default
	Type = REVERSIBLE;

	int CoeffSign = -1;
	Species* Reactant = NULL;
	double Coeff = 1;
	//Setting the default compartment for the reaction and the reactants based on the specified default in the compartments file
	int SpeciesCompartment = 100;
	Compartment = GetDefaultCompartment()->Index;
	
	//I set that the species is not a cofactor by default
	bool CofactorSpecies = false;
	
	//I'm redesigning this parser because I really want a parser that can handle compound names with spaces and other special characters in them 
	for (int i=0; i < int(DataList->size()); i++) {
		string Current = (*DataList)[i];
		//I remove spaces that are at the beginning and end of Current
		if (Current.substr(0,1).compare(" ") == 0) {
			Current = Current.substr(1,Current.length()-1);
		}
		if (Current.substr(Current.length()-1,1).compare(" ") == 0) {
			Current = Current.substr(0,Current.length()-1);
		}

		//If the whole string is in (), then I probably have a coefficient and I can remove the ()
		if (Current.substr(0,1).compare("(") == 0 && Current.substr(Current.length()-1,1).compare(")") == 0) {
			Current = Current.substr(1,Current.length()-2);
		}

		if (Current.compare(":") == 0) {
			continue;
		}
		
		//I check to see if the current string is specifying a compartment
		CellCompartment* NewCompartment = GetCompartment(ConvertToLower((*DataList)[i]).data());
		if (NewCompartment != NULL) {
			if (Reactant == NULL) {
				Compartment = NewCompartment->Index;
				SpeciesCompartment = 100;
			} else {
				SpeciesCompartment = NewCompartment->Index;
				CofactorSpecies = false;
				if (NewCompartment->Abbreviation.compare((*DataList)[i]) != 0) {
					CofactorSpecies = true;
				}
			}
		//Now I check to see if I'm looking at part of the <=>, =>, or <= signs
		} else if (Current.compare("<") == 0) {
			Type = REVERSE;
			if (Reactant != NULL) {
				AddReactant(Reactant,CoeffSign*Coeff,SpeciesCompartment,CofactorSpecies);
				CofactorSpecies = false;
				Reactant = NULL;
				Coeff = 1;
				SpeciesCompartment = 100;
			}
			CoeffSign = 1;
		} else if (Current.compare(">") == 0) {
			if (Type == REVERSE) {
				Type = REVERSIBLE;
			} else {
				Type = FORWARD;
				if (Reactant != NULL) {
					AddReactant(Reactant,CoeffSign*Coeff,SpeciesCompartment,CofactorSpecies);
					CofactorSpecies = false;
					Reactant = NULL;
					Coeff = 1;
					SpeciesCompartment = 100;
				}
				CoeffSign = 1;
			}
		//Now I check to see if I'm looking at a coefficient
		} else if (Current.find_first_of(ALPHABET) == -1) {
			if (Reactant != NULL) {
				AddReactant(Reactant,CoeffSign*Coeff,SpeciesCompartment,CofactorSpecies);
				CofactorSpecies = false;
				Reactant = NULL;
				SpeciesCompartment = 100;
			}
			Coeff = atof(Current.data());
		//If the string matched none of the above criteria, it must be a compound identifier of some kind
		} else {
			if (Reactant != NULL) {
				AddReactant(Reactant,CoeffSign*Coeff,SpeciesCompartment,CofactorSpecies);
				CofactorSpecies = false;
				Reactant = NULL;
				Coeff = 1;
				SpeciesCompartment = 100;
			}
			Reactant = MainData->FindSpecies("DATABASE;NAME;ENTRY",Current.data());
			if (Reactant == NULL) {
				Reactant = MainData->AddSpecies(Current);
			}
			if (Reactant == NULL && Current.substr(Current.length()-1,1).compare("e") == 0) {
				SpeciesCompartment = GetCompartment("e")->Index;
				Current = Current.substr(0,Current.length()-1);
				Reactant = MainData->FindSpecies("DATABASE;NAME;ENTRY",Current.data());
				if (Reactant == NULL) {
					Reactant = MainData->AddSpecies(Current);
				}
			}
			//If the reactant still does not exist, I print an error message
			if (Reactant == NULL) {
				cout << "Could not find reactant: " << Current << " when parsing reaction: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ")" << endl;
				FErrorFile() << "Could not find reactant: " << Current << " when parsing reaction: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ")" << endl;
				FlushErrorFile();
				delete DataList;
				return FAIL;
			}
		}
	}

	if (Reactant != NULL) {
		AddReactant(Reactant,CoeffSign*Coeff,SpeciesCompartment,CofactorSpecies);
	}

	//if (FNumReactants(REACTANT) == 0 || FNumReactants(PRODUCT) == 0) {
	//	Compartment = EXCHANGE;
	//}
	delete DataList;

	return SUCCESS;
};

void Reaction::ClearStructuralCues() {
	StructuralCues.clear();
	NumStructuralCues.clear();
};

int Reaction::ParseStructuralCueList(string InList) {
        if(InList.compare("nogroups")==0){
	  return SUCCESS;
        }
	vector<string>* Strings = StringToStrings(InList,"\t|:");
	for (int i=0; i < int(Strings->size()); i++) {
		Species* NewCue = MainData->FindStructuralCue("NAME;DATABASE;ENTRY",(*Strings)[i].data());
		i++;
		double CueCoeff = atof((*Strings)[i].data());
		if (NewCue == NULL) {
			FErrorFile() << "MISSING STRUCTURAL CUE: Structural cue " << (*Strings)[i].data() << " not found." << endl;
			FlushErrorFile();
			AddData("TEMP_CUES",(*Strings)[i].data(),STRING);
			AddData("TEMP_CUE_COEFS",CueCoeff);
		} else {
			AddStructuralCue(NewCue,CueCoeff);
		}
	}
	delete Strings;
	return SUCCESS;
}

int Reaction::ParseReactionList(string InList) {
	vector<string>* Strings = StringToStrings(InList,"|\t:");
	for (int i=0; i < int(Strings->size()); i++) {
		Reaction* NewReaction = MainData->FindReaction("DATABASE",(*Strings)[i].data());
		i++;
		double ReactionCoeff = atof((*Strings)[i].data());
		AddComponentReaction(NewReaction,ReactionCoeff);
	}
	return SUCCESS;
}

int Reaction::ReadFromFileline(vector<string>* InHeaders, string Fileline) {
	vector<string>* Strings = StringToStrings(Fileline,";",false);
	//if (Strings->size() != InHeaders->size()) {
	//	delete Strings;
	//	FErrorFile() << "File header size does not match data header size for: " << Fileline << endl;
	//	FlushErrorFile();
	//	return FAIL;
	//}

	for (int i=0; i < int(InHeaders->size()); i++) {
		if ((*InHeaders)[i].compare("LOAD") != 0) {
			AddData("INPUT_HEADER",(*InHeaders)[i].data(),STRING);
		}
		if (i < int(Strings->size())) {
			vector<string>* SubStrings = StringToStrings((*Strings)[i],"|");
			for (int j=0; j < int(SubStrings->size()); j++) {
				Interpreter((*InHeaders)[i],(*SubStrings)[j],true);
			}
			delete SubStrings;
		}
	}

	if (GetData("FILENAME",STRING).length() == 0) {
		string Filename("rxn");
		Filename.append(MainData->GetData("NAME",STRING));
		Filename.append(itoa(MainData->FNumReactions()));
		AddData("FILENAME",Filename.data(),STRING);
	}

	delete Strings;
	return SUCCESS;
}

int Reaction::AddGene(Gene* InGene, int ComplexIndex) {
	//Adding the reactions to the gene in case the gene is not being loaded from file
	InGene->AddReaction(this);

	//Checking to see if this gene has already been assigned to this reaction
	if (GeneIndecies.count(InGene) > 0) {
		//Checking to see if the input complex index if valid and differs from the current index of the input gene
		if (ComplexIndex != -1 && GeneIndecies[InGene] != ComplexIndex && ComplexIndex < int(GeneDependency.size())) {
			//Remove the gene from the complex it is currently a part of, and place it in the input complex
			int CurrentIndex = GeneIndecies[InGene];
			for (int i=0; i < int(GeneDependency[CurrentIndex].size()); i++) {
				if (GeneDependency[CurrentIndex][i] == InGene) {
					GeneDependency[CurrentIndex].erase(GeneDependency[CurrentIndex].begin()+i,GeneDependency[CurrentIndex].begin()+i+1);
					break;
				}
			}
			GeneDependency[ComplexIndex].push_back(InGene);
			GeneIndecies[InGene] = ComplexIndex;
		}
		return GeneIndecies[InGene];
	}
	
	//Adding the gene to the reaction
	if (ComplexIndex == -1) {
		vector<Gene*> Temp;
		Temp.push_back(InGene);
		GeneDependency.push_back(Temp);
		GeneIndecies[InGene] = int(GeneDependency.size()-1);
		ComplexIndex = int(GeneDependency.size()-1);
	}

	return ComplexIndex;
}

int Reaction::ParseGeneString(string InGeneString) {
	//Ensuring that the gene string contains some content
	if (InGeneString.length() == 0) {
		return FAIL;
	}
	//Removing the ( and ) from the beginning and end of the string
	if (InGeneString.substr(0,1).compare("(") == 0 && InGeneString.length() > 0 && InGeneString.substr(InGeneString.length()-1).compare(")") == 0) {
		InGeneString = InGeneString.substr(1,InGeneString.length()-2);
	}
	//Standardizing characters
	string NewGeneString = StringReplace(InGeneString.data(),"|"," or ");
	NewGeneString = StringReplace(NewGeneString.data(),","," or ");
	NewGeneString = StringReplace(NewGeneString.data(),"+"," and ");
	//Placing spaces around perenthesis
	NewGeneString = StringReplace(NewGeneString.data(),"("," | ");
	NewGeneString = StringReplace(NewGeneString.data(),"|"," ( ");
	NewGeneString = StringReplace(NewGeneString.data(),")"," | ");
	NewGeneString = StringReplace(NewGeneString.data(),"|"," ) ");
	NewGeneString = "( " + NewGeneString + " )";
	//Storing the complete gene string in the string storage structure
	AddData("ASSOCIATED PEG",NewGeneString.data(),STRING);
	//Break file line up into words using "space" as a delimiter
	vector<string>* Strings = StringToStrings(NewGeneString," ",true);
	//Now we parse the conditions
	int Level = 0;
	GeneLogicNode* Node = NULL;
	GeneLogicNode* NewRoot = NULL;
	vector<GeneLogicNode*> NodeAtLevel;
	for (int i=0; i < int(Strings->size()); i++) {	
		//Getting the current word from the Strings vector
		string Current = (*Strings)[i];
		//Checking for logic terms first
		if (ConvertToLower(Current).compare("and") == 0 ) {
			Node->Logic = AND;
		} else if (ConvertToLower(Current).compare("or") == 0) {
			Node->Logic = OR;
		} else if (ConvertToLower(Current).compare("(") == 0) {
			Level++;
		} else if (ConvertToLower(Current).compare(")") == 0) {
			if (Node != NULL && Node->Level >= 2) {
				//Saving the old node pointer before we overwrite it
				GeneLogicNode* OldNode = Node;
				NodeAtLevel[OldNode->Level-1] = NULL;
				//Getting the new node
				Node = NodeAtLevel[OldNode->Level-2];
				if (Node == NULL) {
					Node = new GeneLogicNode;
					Node->Level = Level-1;
					if (Node->Level == 1) {
						NewRoot = Node;
					}
					Node->Logic = OR;
					//Saving the new node in the nodes vector
					LogicNodes.push_back(Node);
					//Saving the node at the current level
					NodeAtLevel[OldNode->Level-2] = Node;
				}
				//add the current node to the new logic node
				Node->LogicNodes.push_back(OldNode);
			}
			Level--;
		} else { //if (Current.find_first_of("abcdefghijklmnopqrstuvwxyz0123456789") != -1)
			Gene* Temp = MainData->FindGene("DATABASE;NAME",Current.data());
			if (Temp == NULL) {
				Temp = MainData->AddGene(Current);
			}
			Temp->AddReaction(this);
			//Instantiating and initializing nodes
			if (Node == NULL || Level > Node->Level) {
				//Creating a new node
				Node = new GeneLogicNode;
				Node->Level = Level;
				if (Node->Level == 1) {
					NewRoot = Node;
				}
				Node->Logic = OR;
				//Saving the new node in the nodes vector
				LogicNodes.push_back(Node);
				//Saving the node at the current level
				if (int(NodeAtLevel.size()) <= Node->Level) {
					for (int j=int(NodeAtLevel.size()); j <= Node->Level; j++) {
						NodeAtLevel.push_back(NULL);
					}
				}
				NodeAtLevel[Node->Level-1] = Node;
			}
			//Adding gene to the logic node
			Node->Genes.push_back(Temp);
		}
	}
	//Checking syntax
	if (Level != 0) {
		if (Level > 0) {
			cerr << "Missing ) on line " << NewGeneString << endl;
		} else {
			cerr << "Missing ( on line " << NewGeneString << endl;
		}
	}
	//Adjusting root node
	if (NewRoot != NULL) {
		if (GeneRootNode == NULL) {
			GeneRootNode = NewRoot;
		} else if (GeneRootNode->Logic == OR || GeneRootNode->Logic == -1) {
			GeneRootNode->Logic = OR;
			GeneRootNode->LogicNodes.push_back(NewRoot);
		} else {
			GeneLogicNode* Temp = GeneRootNode;
			GeneRootNode = new GeneLogicNode;
			LogicNodes.push_back(GeneRootNode);
			GeneRootNode->Logic = OR;
			GeneRootNode->LogicNodes.push_back(NewRoot);
			GeneRootNode->LogicNodes.push_back(Temp);
		}
		//Consolidating nodes
		if (GeneRootNode != NULL) {
			for (int i=0; i < int(LogicNodes.size()); i++) {
				if (LogicNodes[i] != NULL) {
					bool Change = false;
					for (int j=0; j < int(LogicNodes[i]->LogicNodes.size()); j++) {
						GeneLogicNode* Temp = LogicNodes[i]->LogicNodes[j];
						if ((Temp->Genes.size()+Temp->LogicNodes.size()) == 1 || Temp->Logic ==  LogicNodes[i]->Logic) {
							Change = true;
							for (int k=0; k < int(Temp->Genes.size()); k++) {
								LogicNodes[i]->Genes.push_back(Temp->Genes[k]);
							}
							for (int k=0; k < int(Temp->LogicNodes.size()); k++) {
								LogicNodes[i]->LogicNodes.push_back(Temp->LogicNodes[k]);
							}
							for (int k=0; k < int(LogicNodes.size()); k++) {
								if (LogicNodes[k] == Temp) {
									delete LogicNodes[k];
									LogicNodes[k] = NULL;
								}
							}
							LogicNodes[i]->LogicNodes.erase(LogicNodes[i]->LogicNodes.begin()+j,LogicNodes[i]->LogicNodes.begin()+j+1);
							j--;
						}
					}
					if (Change) {
						i--;
					}
				}
			}
		}
	}
	//Deleting vector
	delete Strings;
	return SUCCESS;
}

//Output functions
int Reaction::FType() {
	return Type;	
};

Data* Reaction::FMainData() {
	return MainData;
}

bool Reaction::IsReactantCofactor(int InIndex) {
	if (ReactCompartments[InIndex] >= 1000) {
		return true;
	} else {
		return false;
	}
};

int Reaction::FNumReactants(int ProductOrReactant){
	if (ProductOrReactant == REACTANT) {
		return NumReactants;
	} else if (ProductOrReactant == PRODUCT) {
		return int(Reactants.size()-NumReactants);
	} else {
		return int(Reactants.size());
	}
};

Species* Reaction::GetReactant(int InIndex) {
	return Reactants[InIndex];
};

double Reaction::GetReactantCoef(int InIndex) {
	return ReactCoef[InIndex];
};

int Reaction::GetReactantCompartment(int InIndex) {
	int ReturnCompartment = ReactCompartments[InIndex];
	if (ReturnCompartment >= 1000) {
		ReturnCompartment = ReturnCompartment - 1000; 
	}
	if (ReturnCompartment == 100) {
		ReturnCompartment = Compartment;
	}
	return ReturnCompartment;
};

double Reaction::GetReactantCoef(Species* InSpecies) {
	for (int i=0; i < FNumReactants(); i++) {
		if (Reactants[i] == InSpecies) {
			return ReactCoef[i]; 
		}
	}
	return 0;
};

int Reaction::CheckForReactant(Species* InSpecies) {
	int i;
	for(i=0; i < int(Reactants.size()); i++) {
		if (Reactants[i] == InSpecies) {
			return i;
		}
	}
	return -1;
};

double Reaction::FEstDeltaG(double pH, double IonicStr) {
	
	double AdjEstDeltaG = 0;

	// if the conditions are the same as our reference then we simply return our EstDeltaG value
	
	if (pH == 7 && IonicStr == 0) {
		return EstDeltaG;
	} 
	// or we adjust the rxn deltaG based on the pHs and ionic strengths of the reactants based on the compartment they are in
	else if (pH == FLAG && IonicStr == FLAG) {

		for (int i=0; i < FNumReactants(); i++){
			Species* Reactant = GetReactant(i);
			CellCompartment* RCompartment = GetCompartment(GetReactantCompartment(i));

			double ComppH = RCompartment->pH;
			double CompIonicStr = RCompartment->IonicStrength;

			// if reactant is H+ we need to NOT include the adjustment

			if ( Reactant->FFormula().compare("H") != 0 ) {
				AdjEstDeltaG += GetReactantCoef(i)*(Reactant->AdjustedDeltaG(CompIonicStr,ComppH,298.15));
			}
		}
		return AdjEstDeltaG;
	}
	// another case would be to specify a common pH and ionic strength for ALL REACTANTS to be adjusted for
	else {
		for (int i=0; i < FNumReactants(); i++){
			Species* Reactant = GetReactant(i);

				if (Reactant->FFormula().compare("H") != 0 ) {
					AdjEstDeltaG += GetReactantCoef(i)*(Reactant->AdjustedDeltaG(IonicStr,pH,298.15));
				}
		}
		return AdjEstDeltaG;
	}
};

double Reaction::FEstDeltaGUncertainty() {
	if (FEstDeltaG() == FLAG) {
		return FLAG;
	}
	
	if (EstDeltaGUncertainty != FLAG) {
		return 	EstDeltaGUncertainty;
	}

	EstDeltaGUncertainty = 0;
	for (int i=0; i < FNumStructuralCues(); i++) {
		EstDeltaGUncertainty += GetStructuralCueNum(i)*GetStructuralCueNum(i)*GetStructuralCue(i)->FEstDeltaGUncertainty()*GetStructuralCue(i)->FEstDeltaGUncertainty();
	}
	EstDeltaGUncertainty = pow(EstDeltaGUncertainty,0.5);
	
	//Added this for the small amount of error for reactions with zero group change
	if (EstDeltaGUncertainty == 0) {
		EstDeltaGUncertainty = 2;
	}

	return EstDeltaGUncertainty;
};	

bool Reaction::AllKegg() {
	int i;
	for (i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->GetData("KEGG",DATABASE_LINK).length() == 0) {
			return false;
		}
	}
	return true;
};

Reaction* Reaction::GetReverse() {
	string Filename;
	Reaction* NewReaction = new Reaction(Filename, MainData);
	for (int i=0; i < FNumReactants(); i++) {
		NewReaction->AddReactant(GetReactant(i), -GetReactantCoef(i), GetReactantCompartment(i), IsReactantCofactor(i));
	}

	NewReaction->SetType(REVREVERSIBLE);
	NewReaction->ParseCombinedData(GetCombinedData(STRING),STRING,true);
	NewReaction->ParseCombinedData(GetCombinedData(DATABASE_LINK),DATABASE_LINK,true);
	NewReaction->PerformAllCalculations();
	
	Type = FORREVERSIBLE;

	return NewReaction;
}

Reaction* Reaction::Clone() {
	string Filename;
	Reaction* NewReaction = new Reaction(Filename, MainData);
	for (int i=0; i < FNumReactants(); i++) {
		NewReaction->AddReactant(GetReactant(i), GetReactantCoef(i), GetReactantCompartment(i), IsReactantCofactor(i));
	}

	NewReaction->SetType(FType());
	NewReaction->ParseCombinedData(GetCombinedData(STRING),STRING,false);
	NewReaction->ParseCombinedData(GetCombinedData(DATABASE_LINK),DATABASE_LINK,false);
	NewReaction->PerformAllCalculations();

	return NewReaction;
}

int Reaction::ContainsUnknownStructures() {
	int NumUnknown = 0;
	for (int i =0; i < FNumReactants(); i++) {
		if (GetReactant(i)->GetData("STRUCTURE_FILE",STRING).length() == 0 && GetReactant(i)->FCode().length() == 0) {
			if (GetReactant(i)->FFormula().length() >= 4 || GetReactant(i)->FFormula().length() == 0) {
				NumUnknown++;
			}
		}
	}
	if (NumUnknown > 0) {
		AddErrorMessage("Involves unknown structures");
		FErrorFile() << "UNKNOWN STRUCTURES: Reaction " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") contains " << NumUnknown << " unknown structures." << endl;
		FlushErrorFile();
	}
	return NumUnknown;
};

bool Reaction::ContainsStructuresWithNoEnergy() {
	for (int i =0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FEstDeltaG() == FLAG) {
			return true;
		}
	}

	return false;
}

bool Reaction::ContainsNoUnidentifiedGroups() {
	for (int i =0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FNumNoIDGroups() > 0) {
			return false;
		}
	}
	return true;
}

//The idea of this code is to make a unique string by which reactions may be identified and compared
void Reaction::MakeCode(const char* DBID, bool CofactorsOnly) {
	string StrDBID(DBID);
	
	string NewCode;
	int Multiplier = -1;
	map<string , int , std::less<string> > IDSorting;
	for (int i = 0; i <= int(Reactants.size()); i++) {		
		//I check to see if I have reached the reaction products yet
		if (i == int(Reactants.size()) || (ReactCoef[i] > 0 && Multiplier == -1)) {
			//This block of code only gets run if our reaction code contains database IDs
			if (StrDBID.length() > 0) {
				//I scan through the ordered ids in the map and add the ids to the code
				map<string , int , std::less<string> >::iterator MapIT = IDSorting.begin();
				for (int j=0; j < int(IDSorting.size()); j++) {
					if (j > 0) {
						NewCode.append("+");
					}
					if (Multiplier*GetReactantCoef((*MapIT).second) != 1) {
						NewCode.append("(");
						NewCode.append(dtoa(Multiplier*GetReactantCoef((*MapIT).second)));
						NewCode.append(")");
					}
					NewCode.append((*MapIT).first);
					MapIT++;
				}
				IDSorting.clear();
			}
			
			//This code gets run regardless of whether we're making entry code or database ID code
			if (i < int(Reactants.size())) {
				Multiplier = 1;
				if (FType() == REVERSIBLE) {
					NewCode.append("<=>");
				} else if (FType() == FORWARD) {
					NewCode.append("=>");
				} else if (FType() == REVERSE) {
					NewCode.append("<=");
				}
			}
		}

		//This code adds the compound IDs and indexes to the ID map for sorting
		if (i < int(Reactants.size()) && (!CofactorsOnly || !IsReactantCofactor(i))) {
			if (StrDBID.length() > 0) {
				string ID = Reactants[i]->GetGenericData(StrDBID.data());
				if (ID.length() == 0) {
					ID = Reactants[i]->GetData("DATABASE",STRING);
				}
				IDSorting[ID] = i;
			} else {
				IDSorting[itoa(Reactants[i]->FEntry())] = i;
			}
		}
	}

	//I overwrite the current code with the new code
	SetCode(NewCode);
}

void Reaction::ReverseCode(const char* DBID, bool CofactorsOnly) {
	MakeCode(DBID, CofactorsOnly);
	vector<string>* Strings = StringToStrings(FCode(),"=");
	string NewCode;
	if (Strings->size() > 1) {
		NewCode.append((*Strings)[1]);
		if (NewCode.substr(0,1).compare(">") == 0) {
			NewCode = NewCode.substr(1,NewCode.length()-1);
			NewCode.append("<");
		}
	}
	NewCode.append("=");
	if (Strings->size() > 0) {
		if ((*Strings)[0].substr((*Strings)[0].length()-1,1).compare("<") == 0) {
			NewCode.append(">");
			NewCode.append((*Strings)[0].substr((*Strings)[0].length()-1,1));
		} else {
			NewCode.append((*Strings)[0]);
		}		
	}
	AddData("REVERSE_CODE",NewCode.data(),STRING);
	delete Strings;
}

bool Reaction::Compare(Reaction* InReaction) {
	if (FCode().compare(InReaction->FCode()) == 0) {
		return true;
	}
	return false;
}

int Reaction::FNumStructuralCues() {
	return int(StructuralCues.size());
};

Species* Reaction::GetStructuralCue(int GroupIndex) {
	return StructuralCues[GroupIndex];
};

double Reaction::GetStructuralCueNum(int GroupIndex) {
	return NumStructuralCues[GroupIndex];
};

string Reaction::CreateReactionEquation(string EquationType, bool PrintCofactors) {
	ostringstream TempString;
	string EquationString;

	if (GetCompartment(Compartment) != GetDefaultCompartment()) {
		TempString << "[" << GetCompartment(Compartment)->Abbreviation << "] : ";
	}
	
	double CoeffSign = -1;
	bool First = true;
	for (int i=0; i < int(Reactants.size()); i++) {
		if (!IsReactantCofactor(i) || PrintCofactors) {
			if (ReactCoef[i]*CoeffSign < 0) {
				CoeffSign = 1;
				First = true;
				if (Type == FORWARD) {
					TempString << " => ";
				} else if (Type == REVERSIBLE) {
					TempString << " <=> ";
				} else if (Type == REVERSE) {
					TempString << " <= ";
				}
			} else if (!First) {
				TempString << " + ";	
			}

			First = false;
			if (GetReactantCoef(i)*CoeffSign != 1) {
				TempString << dtoa(GetReactantCoef(i)*CoeffSign) << " ";
			}
			
			string ID = GetReactant(i)->GetData(EquationType.data(),STRING);
			if (ID.length() == 0) {
				ID = GetReactant(i)->Query(EquationType);
			}
			if (ID.length() == 0) {
				ID = GetReactant(i)->GetData("DATABASE",STRING);
			}

			TempString << ID;

			if (IsReactantCofactor(i) && GetParameter("indicate cofactors in reaction equation").compare("1") == 0) {
				TempString << "[" << ConvertToUpper(GetCompartment(GetReactantCompartment(i))->Abbreviation.data()) << "]";
			} else {
				if (GetReactantCompartment(i) != Compartment) {
					TempString << "[" << GetCompartment(GetReactantCompartment(i))->Abbreviation << "]";
				}
			}
		}
	}

	EquationString = TempString.str();
	return EquationString;
};

bool Reaction::SpeciesCancels(Species* InSpecies) {
	double NetCoeff = 0;
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i) == InSpecies) {
			NetCoeff += GetReactantCoef(i);
		}
	}
	if (NetCoeff == 0) {
		return true;
	}
	return false;
}

double Reaction::FindMarkDifference() {
	double MarkDiff = 0;
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FMark()) {
			MarkDiff += GetReactantCoef(i);
		}
	}
	return MarkDiff;
}

bool Reaction::ContainsMarkedReactants() {
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FMark()) {
			return true;
		}
	}
	return false;
}

bool Reaction::ContainsKilledReactants() {
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FKill()) {
			return true;
		}	
	}

	return false;
}

Reaction* Reaction::GetComponentReaction(int InIndex) {
	return ComponentReactions[InIndex];
}

double Reaction::GetComponentReactionCoeff(int InIndex) {
	return ComponentReactionCoeffs[InIndex];
}

int Reaction::FNumComponentReactions() {
	return int(ComponentReactions.size());
}

double Reaction::FEstDeltaGMin(bool Transport) {
	double Temperature = atof(GetParameter("Temperature").data());
	double DeltaGMin = FEstDeltaG();
		
	if (DeltaGMin == FLAG) {
		return FLAG;
	}

	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FFormula().compare("H2O") != 0 ) {
			if (GetReactantCoef(i) < 0) {
				DeltaGMin += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(GetReactant(i)->GetMaxConcentration(GetCompartment(GetReactantCompartment(i))->Abbreviation.data()));
			} else {
				DeltaGMin += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(GetReactant(i)->GetMinConcentration(GetCompartment(GetReactantCompartment(i))->Abbreviation.data()));
			}
		}
	}

	//DELTAGTRANSPORT
	if (Transport) {
		double HextCoeff = 0;
		double HinCoeff = 0;
		double MinExtpH = atof(GetParameter("Min external pH").data());
		double MaxExtpH = atof(GetParameter("Max external pH").data());
		double IntpH = atof(GetParameter("pH").data());
		for (int i=0; i < NumReactants; i++) {
			for (int j=NumReactants; j < FNumReactants(); j++) {
				if (GetReactant(i) == GetReactant(j)) {
					double MolsTransported = 0;
					if (GetReactantCompartment(i) != GetCompartment("c")->Index && GetReactantCompartment(j) == GetCompartment("c")->Index) {
						MolsTransported = GetReactantCoef(i);
						if (GetReactantCoef(j) < GetReactantCoef(i)) {
							MolsTransported = GetReactantCoef(j);
						}
					} else if (GetReactantCompartment(i) == GetCompartment("c")->Index && GetReactantCompartment(j) != GetCompartment("c")->Index) {
						MolsTransported = -GetReactantCoef(i);
						if (GetReactantCoef(j) < GetReactantCoef(i)) {
							MolsTransported = -GetReactantCoef(j);
						}
					}
					double Charge = GetReactant(i)->FCharge();
					DeltaGMin -= MolsTransported*Charge*DPSI_CONST;	
					if (GetReactant(i)->FFormula().compare("H") == 0) {
						HextCoeff -= (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
						HinCoeff += (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
					}
					else {
						HextCoeff -= DPSI_COEFF*Charge*MolsTransported;
						HinCoeff += DPSI_COEFF*Charge*MolsTransported;
					}
				}
			}
		}
		if (HinCoeff < 0) {
			DeltaGMin += -HinCoeff*IntpH + -HextCoeff*MaxExtpH;
		}
		else {
			DeltaGMin += -HinCoeff*IntpH + -HextCoeff*MinExtpH;
		}
	}
	
	return DeltaGMin;
}

double Reaction::FEstDeltaGMax(bool Transport) {
	double Temperature = atof(GetParameter("Temperature").data());
	double DeltaGMax = FEstDeltaG();
		
	if (DeltaGMax == FLAG) {
		return FLAG;
	}

	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FFormula().compare("H2O") != 0 && GetReactant(i)->FFormula().compare("H") != 0) {
			if (GetReactantCoef(i) < 0) {
				DeltaGMax += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(GetReactant(i)->GetMinConcentration(GetCompartment(GetReactantCompartment(i))->Abbreviation.data()));
			} else {
				DeltaGMax += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(GetReactant(i)->GetMaxConcentration(GetCompartment(GetReactantCompartment(i))->Abbreviation.data()));
			}
		}
	}

	//DELTAGTRANSPORT
	if (Transport) {
		double HextCoeff = 0;
		double HinCoeff = 0;
		double MinExtpH = atof(GetParameter("Min external pH").data());
		double MaxExtpH = atof(GetParameter("Max external pH").data());
		double IntpH = atof(GetParameter("pH").data());
		for (int i=0; i < NumReactants; i++) {
			for (int j=NumReactants; j < FNumReactants(); j++) {
				if (GetReactant(i) == GetReactant(j)) {
					double MolsTransported = 0;
					if (GetReactantCompartment(i) != GetCompartment("c")->Index && GetReactantCompartment(j) == GetCompartment("c")->Index) {
						MolsTransported = GetReactantCoef(i);
						if (GetReactantCoef(j) < GetReactantCoef(i)) {
							MolsTransported = GetReactantCoef(j);
						}
					} else if (GetReactantCompartment(i) == GetCompartment("c")->Index && GetReactantCompartment(j) != GetCompartment("c")->Index) {
						MolsTransported = -GetReactantCoef(i);
						if (GetReactantCoef(j) < GetReactantCoef(i)) {
							MolsTransported = -GetReactantCoef(j);
						}
					}
					double Charge = GetReactant(i)->FCharge();
					DeltaGMax -= MolsTransported*Charge*DPSI_CONST;	
					if (GetReactant(i)->FFormula().compare("H") == 0) {
						HextCoeff -= (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
						HinCoeff += (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
					}
					else {
						HextCoeff -= DPSI_COEFF*Charge*MolsTransported;
						HinCoeff += DPSI_COEFF*Charge*MolsTransported;
					}
				}
			}
		}
		if (HinCoeff < 0) {
			DeltaGMax += -HinCoeff*IntpH + -HextCoeff*MinExtpH;
		}
		else {
			DeltaGMax += -HinCoeff*IntpH + -HextCoeff*MaxExtpH;
		}
	}
	
	return DeltaGMax;
}

double Reaction::FmMDeltaG(bool Transport) {
	double Temperature = atof(GetParameter("Temperature").data());
	double mMDeltaG = FEstDeltaG();

	if (mMDeltaG == FLAG) {
		return FLAG;
	}

	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FFormula().compare("H2O") != 0 && GetReactant(i)->FFormula().compare("H") != 0) {
			if (GetReactant(i)->FFormula().compare("CO2") == 0) {
				mMDeltaG += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(0.0001);
			} else if (GetReactant(i)->FFormula().compare("H2") == 0 || GetReactant(i)->FFormula().compare("O2") == 0) {
				mMDeltaG += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(0.000001);
			} else {
				mMDeltaG += GetReactantCoef(i)*GAS_CONSTANT*Temperature*log(0.001);
			}
		}
	}


	//DELTAGTRANSPORT
	if (Transport) {
		double HextCoeff = 0;
		double HinCoeff = 0;
		double IntpH = atof(GetParameter("pH").data());
		for (int i=0; i < NumReactants; i++) {
			for (int j=NumReactants; j < FNumReactants(); j++) {
				if (GetReactant(i) == GetReactant(j)) {
					double MolsTransported = 0;
					if (GetReactantCompartment(i) != GetCompartment("c")->Index && GetReactantCompartment(j) == GetCompartment("c")->Index) {
						MolsTransported = GetReactantCoef(i);
						if (GetReactantCoef(j) < -GetReactantCoef(i)) {
							MolsTransported = -GetReactantCoef(j);
						}
					} else if (GetReactantCompartment(i) == GetCompartment("c")->Index && GetReactantCompartment(j) != GetCompartment("c")->Index) {
						MolsTransported = -GetReactantCoef(i);
						if (GetReactantCoef(j) < -GetReactantCoef(i)) {
							MolsTransported = GetReactantCoef(j);
						}
					}
					double Charge = GetReactant(i)->FCharge();
					mMDeltaG -= MolsTransported*Charge*DPSI_CONST;	
					if (GetReactant(i)->FFormula().compare("H") == 0) {
						HextCoeff -= (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
						HinCoeff += (DPSI_COEFF-Temperature*GAS_CONSTANT*1)*MolsTransported;
					}
					else {
						HextCoeff -= DPSI_COEFF*Charge*MolsTransported;
						HinCoeff += DPSI_COEFF*Charge*MolsTransported;
					}
				}
			}
		}
		if (HinCoeff < 0) {
			mMDeltaG += -HinCoeff*IntpH + -HextCoeff*(IntpH+0.5);
		}
		else {
			mMDeltaG += -HinCoeff*IntpH + -HextCoeff*(IntpH+0.5);
		}
	}

	return mMDeltaG;
}

bool Reaction::CheckForTransportOrStereo(bool& Transport, bool& Stereo) {
	Transport = false;
	Stereo = false;
	int MatchCount = 0;
	for (int i=0; i < NumReactants; i++) {
		bool Match = false;
		for (int j=NumReactants; j < FNumReactants(); j++) {
			if (GetReactant(i)->FCode().compare(GetReactant(j)->FCode()) == 0) {
				if (GetReactantCompartment(i) != GetReactantCompartment(j)) {
					Transport = true;
				} else {
					Stereo = true;
				}
				MatchCount++;
				Match = true;
				j = FNumReactants();
			}
		}
		if (!Match) {
			return false;
		}
	}

	if (MatchCount > 1 && !Transport) {
		return false;
	}

	return true;
}

vector<double> Reaction::GetTransportCoefficient(vector<int>& InCompartments, double& TotalConstant,OptimizationParameter* InParameters) {
	//This term holds the total constant terms for all tranport
	TotalConstant = 0;
	vector<double> Coefficients;
	for (int i=0; i < FNumReactants(REACTANT); i++) {
		for (int j=FNumReactants(REACTANT); j < FNumReactants(); j++) {
			if (GetReactant(i) == GetReactant(j) && GetReactantCompartment(i) != GetReactantCompartment(j)) {
				//The charge that is actually transported is the charge in the reactant's compartment
				//This may method of calculation may need to be altered when transport reactions are operating in reverse, but it will work for now.
				double TransportPH = GetCompartment(GetReactantCompartment(i))->pH;
				for (int k=0; k < int(InParameters->UserBounds->VarName.size()); k++) {
					if (InParameters->UserBounds->VarType[k] == LOG_CONC || InParameters->UserBounds->VarType[k] == CONC) {
						Species* Compound = MainData->FindSpecies("DATABASE;NAME;ENTRY",InParameters->UserBounds->VarName[k].data());
						if (Compound != NULL && Compound->FFormula().compare("H") == 0) {
							if (InParameters->UserBounds->VarType[k] == LOG_CONC) {
								TransportPH = (-log10(exp(InParameters->UserBounds->VarMin[k]))-log10(exp(InParameters->UserBounds->VarMax[k])))/2;
							} else {
								TransportPH = (-log10(InParameters->UserBounds->VarMin[k])-log10(InParameters->UserBounds->VarMax[k]))/2;
							}
						}
					}
				}
				int SpeciesCharge = GetReactant(i)->CalculatePredominantIon(TransportPH);
				//I now determine the number of ions transported
				double AmountTransported = 0;
				if (-GetReactantCoef(i) < GetReactantCoef(j)) {
					AmountTransported = GetReactantCoef(j);
				} else {
					AmountTransported = -GetReactantCoef(i);
				}
				double DeltaPsiConstant = GetCompartment(GetReactantCompartment(j))->DPsiConst - GetCompartment(GetReactantCompartment(i))->DPsiConst;
				double DeltaPsiCoef = GetCompartment(GetReactantCompartment(j))->DPsiCoef - GetCompartment(GetReactantCompartment(i))->DPsiCoef;
				if (SpeciesCharge != 0 && AmountTransported != 0) {
					//I add the constant term for the current transport to Total constant
					TotalConstant += DeltaPsiConstant*AmountTransported*SpeciesCharge*FARADAY;
					//I calculate the ln[H] coefficient for this transport
					double Coef = FARADAY*AmountTransported*SpeciesCharge*DeltaPsiCoef/PHTOLNH;
					if (GetReactant(i)->FFormula().compare("H") == 0) {
						Coef += AmountTransported*GAS_CONSTANT*InParameters->Temperature;
					}
					//I add the coefficients for the current transport to the coefficients for the compartments
					bool Foundi = false;
					bool Foundj = false;
					for (int k=0; k < int(InCompartments.size()); k++) {
						if (InCompartments[k] == GetReactantCompartment(i)) {
							Coefficients[k] += -Coef;
							Foundi = true;
						} else if (InCompartments[k] == GetReactantCompartment(j)) {
							Coefficients[k] += Coef;				
							Foundj = true;
						}
					}
					//If the compartments aren't already in the list of compartments involved in this tranport, then I add them
					if (!Foundj) {
						InCompartments.push_back(GetReactantCompartment(j));
						Coefficients.push_back(Coef);
					}
					if (!Foundi) {
						InCompartments.push_back(GetReactantCompartment(i));
						Coefficients.push_back(-Coef);
					}
				}
			}	
		}
	}

	return Coefficients;
}

string Reaction::Query(string InDataName) {
	//I will always reuse a previously calculated query value if it is available
	string Result = GetAllDataString(InDataName.data(),STRING);
	if (Result.length() > 0) {
		return Result;
	}
	
	//The CGI_ID is a consistent ID assigned to a compound coming from other databases in the following order of priority: KEGG, Palsson, misc
	if (InDataName.compare("CGI_ID") == 0) {
		//Determine if the current database ID is a KEGG database ID
		string DatabaseID = GetData("DATABASE",STRING);
		if (DatabaseID.length() == 6 && DatabaseID.substr(0,1).compare("R") == 0) {
			AddData("CGI_ID",DatabaseID.data(),STRING);
				return DatabaseID;
		}
		//Check for KEGG database ID
		DatabaseID = GetData("KEGG",DATABASE_LINK);
		if (DatabaseID.length() == 6 && DatabaseID.substr(0,1).compare("R") == 0) {
			AddData("CGI_ID",DatabaseID.data(),STRING);
				return DatabaseID;
		}
		//Check for Palsson database ID
		DatabaseID = GetData("PALSSON",DATABASE_LINK);
		if (DatabaseID.length() > 0) {
			AddData("CGI_ID",DatabaseID.data(),STRING);
				return DatabaseID;
		}
		//Resort to the current database ID
		DatabaseID = GetData("DATABASE",STRING);
		AddData("CGI_ID",DatabaseID.data(),STRING);
		return DatabaseID;
	}

	//THERMODYNAMIC REVERSIBILITY is an indication of the thermodynamically feasible direction of operator for the reaction
	if (InDataName.compare("THERMODYNAMIC REVERSIBILITY") == 0) {
		string Result;
		int Reversibility = CalculateDirectionalityFromThermo(); 
		if (Reversibility == FORWARD) {
			Result.assign("=>");
		} else if (Reversibility == REVERSIBLE) {
			Result.assign("<=>");
		} else {
			Result.assign("<=");
		}
		AddData("THERMODYNAMIC REVERSIBILITY",Result.data(),STRING);
		return Result;

	}

	//MAIN EQUATION is a printout of the reaction equation without the cofactor compounds
	if (InDataName.compare("MAIN EQUATION") == 0) {
		string Result;
		//Running the cofactor labeling code if it has not already been run
		if (MainData->GetData("COFACTORS LABELED",STRING).length() == 0) {
			MainData->LabelKEGGCofactorPairs();
			MainData->LabelKEGGSingleCofactors();
		}
		//Printing the main equation
		Result = CreateReactionEquation("DATABASE",false);
		AddData("MAIN EQUATION",Result.data(),STRING);
		return Result;

	}

	//The SHORTNAME is the shortest name on file for this compound often used in reaction definitions
	if (InDataName.compare("SHORTNAME") == 0) {
		vector<string> Names = GetAllData("NAME",STRING);
		if (Names.size() == 0) {
			AddData("SHORTNAME",GetData("DATABASE",STRING).data(),STRING);
			return GetData("DATABASE",STRING);	
		}
		string ShortestName(Names[0]);
		for (int i=1; i < int(Names.size()); i++) {
			if (ShortestName.length() > Names[i].length()) {
				ShortestName.assign(Names[i]);
			}
		}
		AddData("SHORTNAME",ShortestName.data(),STRING);
		return ShortestName;
	}

	//REACTANTS is a | delimited list of the CGI_IDs for the reactants involved in the reaction
	if (InDataName.compare("REACTANTS") == 0) {
		string ReactantsString;
		if (FNumReactants() == 0) {
			return ReactantsString;
		}
		ReactantsString.append(GetReactant(0)->Query("CGI_ID"));
		for (int i=0; i < FNumReactants(); i++) {
			ReactantsString.append("|");
			ReactantsString.append(GetReactant(i)->Query("CGI_ID"));
		}
		AddData("REACTANTS",ReactantsString.data(),STRING);
		return ReactantsString;
	}

	if (InDataName.compare("GENE") == 0) {
		string GeneString = GetData("BSUBPEG",DATABASE_LINK);
		if (GeneString.length() == 0) {
			GeneString = GetData("BGNUMBER",DATABASE_LINK);
		}
		AddData("GENE",GeneString.data(),STRING);		
		return GeneString;
	}

	if (InDataName.compare("TRANSPORT") == 0) {
		string Result = "no";
		for (int i=1; i < FNumReactants(); i++) {
			if (GetReactantCompartment(i) != GetReactantCompartment(0)) {
				Result.assign("yes");
				break;
			}
		}
		return Result;
	}
	
	//NEXT is a list of the CGI_IDs for the reactions that consume the noncofactor products of this reaction
	if (InDataName.compare("NEXT") == 0) {
		string Next;
		bool First = true;
		for (int i=FNumReactants(REACTANT); i < FNumReactants(); i++) {
			if (!IsReactantCofactor(i)) {
				list<Reaction*> ReactionList = GetReactant(i)->GetReactionList();
				for (list<Reaction*>::iterator ListIT = ReactionList.begin(); ListIT != ReactionList.end(); ListIT++) {
					int ReactantID = (*ListIT)->CheckForReactant(GetReactant(i));
					if (ReactantID != -1) {
						if (!(*ListIT)->IsReactantCofactor(ReactantID)) {
							if (!First) {
								Next.append("|");
							}
							if ((*ListIT)->GetReactantCoef(ReactantID) > 0) {
								Next.append("-");
							}
							Next.append((*ListIT)->Query("CGI_ID"));
							First = false;
						}
					}
				}
			}
		}
		AddData("NEXT",Next.data(),STRING);
		return Next;
	}

	//PREVIOUS is a list of the CGI_IDs for the reactions that produce the noncofactor reactants for this reaction
	if (InDataName.compare("PREVIOUS") == 0) {
		string Previous;
		bool First = true;
		for (int i=0; i < FNumReactants(REACTANT); i++) {
			if (!IsReactantCofactor(i)) {
				list<Reaction*> ReactionList = GetReactant(i)->GetReactionList();
				for (list<Reaction*>::iterator ListIT = ReactionList.begin(); ListIT != ReactionList.end(); ListIT++) {
					int ReactantID = (*ListIT)->CheckForReactant(GetReactant(i));
					if (ReactantID != -1) {
						if (!(*ListIT)->IsReactantCofactor(ReactantID)) {
							if (!First) {
								Previous.append("|");
							}
							if ((*ListIT)->GetReactantCoef(ReactantID) < 0) {
								Previous.append("-");
							}
							Previous.append((*ListIT)->Query("CGI_ID"));
							First = false;
						}
					}
				}
			}
		}
		AddData("PREVIOUS",Previous.data(),STRING);
		return Previous;
	}

	if (InDataName.compare("BALANCED") == 0) {
		if (BalanceReaction(false,false)) {
			Result.assign("yes");
		} else {
			Result.assign("no");
		}
	} else if (InDataName.compare("MMDELTAG") == 0) {
		Result.assign(dtoa(FmMDeltaG(false)));
	} else if (InDataName.compare("TRANSMMDELTAG") == 0) {
		Result.assign(dtoa(FmMDeltaG(true)));;
	} else if (InDataName.compare("MINDELTAG") == 0) {
		Result.assign(dtoa(FEstDeltaGMin(false)));;
	} else if (InDataName.compare("MAXDELTAG") == 0) {
		Result.assign(dtoa(FEstDeltaGMax(false)));;
	} else if (InDataName.compare("TRANSMINDELTAG") == 0) {
		Result.assign(dtoa(FEstDeltaGMin(true)));;
	} else if (InDataName.compare("TRANSMAXDELTAG") == 0) {
		Result.assign(dtoa(FEstDeltaGMax(false)));;
	} else if (InDataName.compare("DEFINITION") == 0) {
		Result.assign(CreateReactionEquation("SHORTNAME"));;
	}

	return Result;
}
	
string Reaction::CreateReactionList() {
	string CombinedList;
	for (int i=0; i < FNumComponentReactions(); i++) {
		CombinedList.append(GetComponentReaction(i)->GetData("DATABASE",STRING));
		CombinedList.append(":");
		CombinedList.append(dtoa(GetComponentReactionCoeff(i)));
		CombinedList.append("\t");
	}
	return CombinedList;
}

string Reaction::CreateStructuralCueList() {
	string CombinedList;
	for (int i=0; i < FNumStructuralCues(); i++) {
		CombinedList.append(GetStructuralCue(i)->GetData("NAME",STRING));
		CombinedList.append(":");
		CombinedList.append(dtoa(GetStructuralCueNum(i)));
		CombinedList.append("\t");
	}
	return CombinedList;
}

string Reaction::PrintRequestedDataToString(vector<string>* Headers) {
	string Result;
	vector<string> InputHeader;
	for (int j=0; j < int(Headers->size()); j++) {
		if ((*Headers)[j].compare("INPUT_HEADER") == 0) {
			InputHeader = GetAllData("INPUT_HEADER",STRING);
			for (int i=0; i < int(InputHeader.size()); i++) {
				bool AlreadyPrinted = false;
				for (int k=0; k < j; k++) {
					if ((*Headers)[k].compare(InputHeader[i]) == 0) {
						AlreadyPrinted = true;
					}
				}
				if (!AlreadyPrinted) {
					string PrintData;
					Interpreter(InputHeader[i],PrintData,false); 
					Result.append(PrintData);
					Result.append(";");
				}
			}
		} else {
			bool AlreadyPrinted = false;
			for (int i=0; i < int(InputHeader.size()); i++) {
				if ((*Headers)[j].compare(InputHeader[i]) == 0) {
					AlreadyPrinted = true;
					break;
				}
			}
			if (!AlreadyPrinted) {
				string PrintData;
				Interpreter((*Headers)[j],PrintData,false); 
				Result.append(PrintData);
				Result.append(";");
			}
		}
	}
	Result = Result.substr(0,Result.length()-1);
	return Result;
}

int Reaction::GetReactionClass() {
	double Min=0;
	double Max=0;
	
	MFAVariable* NewVariable = GetMFAVar(FLUX);
	if (NewVariable != NULL) {
		Min = NewVariable->Min;
		Max = NewVariable->Max;
	} else {
		NewVariable = GetMFAVar(FORWARD_FLUX);
		if (NewVariable != NULL) {
			Min = NewVariable->Min;
			Max = NewVariable->Max;
		}
		NewVariable = GetMFAVar(REVERSE_FLUX);
		if (NewVariable != NULL) {
			if (NewVariable->Min > 0) {
				Max = -NewVariable->Min;
			} 
			if (NewVariable->Max > 0) {
				Min = -NewVariable->Max;
			}
		}
	}

	if (Min > MFA_ZERO_TOLERANCE) {
		return CLASS_P;
	} else if (Max < -MFA_ZERO_TOLERANCE) {
		return CLASS_N;
	} else if (fabs(Min) < MFA_ZERO_TOLERANCE) {
		if (fabs(Max) < MFA_ZERO_TOLERANCE) {
			return CLASS_B;
		} else {
			return CLASS_PV;
		}
	} else {
		if (fabs(Max) < MFA_ZERO_TOLERANCE) {
			return CLASS_NV;
		} else {
			return CLASS_V;
		}
	}

	return CLASS_V;
}

int Reaction::FNumGeneGroups() {
	return int(GeneDependency.size());
}

bool Reaction::CheckForKO(GeneLogicNode* InNode) {
	if (GetParameter("new gene handling").compare("1") == 0) {
		if (InNode == NULL && GeneRootNode != NULL) {
			return CheckForKO(GeneRootNode);
		} else if (InNode != NULL) {
			if (InNode->Logic == OR) {
				for (int i=0; i < int(InNode->Genes.size()); i++) {
					if (InNode->Genes[i] != NULL && !InNode->Genes[i]->FMark()) {
						return false;
					}
				}
				for (int i=0; i < int(InNode->LogicNodes.size()); i++) {
					if (InNode->LogicNodes[i] != NULL && !CheckForKO(InNode->LogicNodes[i])) {
						return false;
					}
				}
				return true;
			} else {
				for (int i=0; i < int(InNode->Genes.size()); i++) {
					if (InNode->Genes[i] != NULL && InNode->Genes[i]->FMark()) {
						return true;
					}
				}
				for (int i=0; i < int(InNode->LogicNodes.size()); i++) {
					if (InNode->LogicNodes[i] != NULL && CheckForKO(InNode->LogicNodes[i])) {
						return true;
					}
				}
				return false;
			}
		}
		return false;
	} else {
		if (GeneDependency.size() == 0) {
			return false;
		}

		for (int i=0; i < int(GeneDependency.size()); i++) {
			bool Marked = false;
			for (int j=0; j < int(GeneDependency[i].size()); j++) {
				if (GeneDependency[i][j]->FMark()) {
					Marked = true;
					break;
				}
			}
			if (!Marked) {
				return false;
			}
		}
		return true;
	}
	return false;
}

bool Reaction::AllReactantsMarked() {
	for (int i=0; i < FNumReactants(REACTANT); i++) {
		if (!GetReactant(i)->FMark()) {
			return false;
		}
	}
	return true;
}

int Reaction::FCompartment() {
	return Compartment;
}

bool Reaction::IsBiomassReaction() {
	if (GetData("DATABASE",STRING).length() == 8 && GetData("DATABASE",STRING).compare("bio") == 0) {
		return true;
	}
	for (int i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->GetData("DATABASE",STRING).compare("cpd11416") == 0) {
			return true;
		}
	}
	if (this == MainData->FindReaction("NAME","Biomass")) {
		return true;
	}
	return false;
}

//File Input
//This function uses the data item headings listed in the input files to determine where the data in those files should be added 
int Reaction::Interpreter(string DataName, string& DataItem, bool Input) {
	int DataID = TranslateFileHeader(DataName,REACTION);
	
	if (DataID == -1) {
		AddData(DataName.data(),DataItem.data(),STRING);
		//FErrorFile() << "UNRECOGNIZED REFERENCE: " << GetData("FILENAME",STRING) << " data reference: " << DataName << " not recognized." << endl;
		//FlushErrorFile();
		return FAIL;
	}
	
	switch (DataID) {
		case RXN_EQUATION: {
			if (Input) {
				return ParseReactionEquation(DataItem);
			} else {
				DataItem = CreateReactionEquation(GetParameter("data type to print in reactions"));
			}
			break;
		} case RXN_DBLINK: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DATABASE_LINK);
			} else {
				DataItem = GetAllDataString(DataName.data(),DATABASE_LINK);
			}
			break;
		} case RXN_ALLDBLINKS: {
			if (Input) {
				ParseCombinedData(DataItem,DATABASE_LINK);
			} else {
				DataItem = GetCombinedData(DATABASE_LINK);
			}
			break;
		} case RXN_STRUCTURALCUES: {
			if (Input) {
				return ParseStructuralCueList(DataItem);
			} else {
				DataItem = CreateStructuralCueList();
			}
			break;
		} case RXN_DOUBLE: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DOUBLE);
			} else {
				DataItem = GetAllDataString(DataName.data(),DOUBLE);
			}
			break;
		} case RXN_DELTAG: {
			if (Input) {
				EstDeltaG = atof(DataItem.data());
			} else {
				DataItem.assign(dtoa(EstDeltaG));
			}
			break;
		} case RXN_DELTAGERR: {
			if (Input) {
				EstDeltaGUncertainty = atof(DataItem.data());
			} else {
				DataItem.assign(dtoa(EstDeltaGUncertainty));
			}
			break;
		} case RXN_COMPONENTS: {
			if (Input) {
				return ParseReactionList(DataItem);
			} else {
				DataItem = CreateReactionList();
			}
			break;
		}  case RXN_CODE: {
			if (Input) {
				SetCode(DataItem);
			} else {
				DataItem = FCode();
			}
			break;
		}  case RXN_ERRORMSG: {
			if (Input) {
				AddErrorMessage(DataItem.data());
			} else {
				DataItem = FErrorMessage();
			}
			break;
		} case RXN_STRING: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),STRING);
			} else {
				DataItem = GetAllDataString(DataName.data(),STRING);
			}
			break;
		} case RXN_DIRECTION: {
			if (Input) {
				if (DataItem.compare("<=>") == 0) {
					Type = REVERSIBLE;
				} else if (DataItem.compare("=>") == 0) {
					Type = FORWARD;
				} else if (DataItem.compare("<=") == 0) {
					Type = REVERSE;
				}
			} else {
				if (Type == REVERSIBLE) {
					DataItem.assign("<=>");
				} else if (Type == FORWARD) {
					DataItem.assign("=>");
				} else if (Type == REVERSE) {
					DataItem.assign("<=");
				}
			}
			break;
		} case RXN_COMPARTMENT: {
			if (Input) {
				if (DataItem.length() == 3) {
					DataItem = DataItem.substr(1,1);
				}
				int OldCompartment = Compartment;
				Compartment = GetCompartment(DataItem.data())->Index;
				if (OldCompartment != Compartment) {
					if (MainData != NULL) {
						MainData->AddCompartment(Compartment);
					}
					for (int i=0; i < FNumReactants(); i++) {
						if (ReactCompartments[i] == 100 || ReactCompartments[i] == 1100) {
							GetReactant(i)->AddCompartment(Compartment);
						}
					}
				}
			} else {
				DataItem.assign(GetCompartment(Compartment)->Abbreviation);
			}
			break;
		} case RXN_GENE: {
			if (Input) {
				if (GetParameter("new gene handling").compare("1") == 0) {
					ParseGeneString(DataItem);
				} else {
					vector<string>* Strings = StringToStrings(DataItem,"\t,");
					//This system differentiates gene IDs from comments based on the idea that comments will never contain numbers or lowercase letters
					if ((*Strings)[0].find_first_of("abcdefghijklmnopqrstuvwxyz0123456789") == -1) {
						AddData("ASSOCIATED PEG",(*Strings)[0].data(),STRING);
					} else {
						for (int i=0; i < int(Strings->size()); i++) {
							vector<Gene*> TempArray;
							vector<string>* StringsTwo = StringToStrings((*Strings)[i],"+");
							for (int j=0; j < int(StringsTwo->size()); j++) {
								Gene* Temp = MainData->FindGene("DATABASE;NAME",(*StringsTwo)[j].data());
								if (Temp == NULL) {
									Temp = MainData->AddGene((*StringsTwo)[j]);
								}
								if (Temp != NULL) {
									TempArray.push_back(Temp);
								}
								Temp->AddReaction(this);
							}
							delete StringsTwo;
							GeneDependency.push_back(TempArray);
						}
					}
					delete Strings;
				}
			} else {
				if (GetParameter("new gene handling").compare("1") == 0) {
					DataItem = GetData("ASSOCIATED PEG",STRING);
				} else {
					for (int i=0; i < int(GeneDependency.size()); i++) {
						for (int j=0; j < int(GeneDependency[i].size()); j++) {
							DataItem.append(GeneDependency[i][j]->GetData("DATABASE",STRING));
							if (j < int(GeneDependency[i].size()-1)) {
								DataItem.append("+");
							}
						}
						if (i < int(GeneDependency.size()-1)) {
							DataItem.append("\t");
						}
					}
					//If no genes are stored in the gene dependancy array, there may be gene comments stored somewhere
					if (DataItem.length() == 0) {
						DataItem = GetData("ASSOCIATED PEG",STRING);
					}
				}
			}
			break;
		} case RXN_QUERY: {
			if (Input) {
				if (GetParameter("save query data on input").compare("1") == 0) {
					AddData(DataName.data(),DataItem.data(),STRING);
				}
			} else {
				DataItem = Query(DataName);
			}
			break;
		} case RXN_LOAD: {
			if (Input) {
				LoadReaction(DataItem);			
			} else {
				DataItem = GetData("DATABASE",STRING);
			}
			break;
		} default: {
			//FErrorFile() << "UNRECOGNIZED DATA ID: Data ID: " << DataID << " input for data reference: " << DataName << " not recognized. Check reaction code.";
			//FlushErrorFile();
			return FAIL;
		}
	}	
	
	return SUCCESS;
};

int Reaction::LoadReaction(string InFilename) {
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
	//Obtaining parsed text object for reaction from StringDB
	StringDBObject* reactionObj = GetStringDB()->get_object("reaction",GetStringDB()->get_table("reaction")->get_id_column(),InFilename);
	if (reactionObj == NULL) {
		SetKill(true);
		return FAIL;
	}
	SetData("FILENAME",InFilename.data(),STRING);
	Reactants.clear();
	ReactCoef.clear();
	ReactCompartments.clear();
	NumReactants = 0;
	for (int i=0; i < reactionObj->get_table()->number_of_attributes();i++) {
		string attribute = reactionObj->get_table()->get_attribute(i);
		vector<string>* data = reactionObj->getAll(i);
		if (data != NULL && data->size() > 0) {
			AddData("INPUT_HEADER",attribute.data(),STRING);
			for (int j=0; j < int(data->size()); j++) {
				Interpreter(attribute,(*data)[j],true);
			}
		}
	}
	if (GetData("DATABASE",STRING).length() == 0) {
		AddData("DATABASE",RemoveExtension(RemovePath(InFilename)).data(),STRING);
	}
	if (MainData != NULL && MainData->GetData("DATABASE",STRING).length() > 0 && GetData("DATABASE",STRING).length() > 0) {
		AddData(MainData->GetData("DATABASE",STRING).data(),GetData("DATABASE",STRING).data(),DATABASE_LINK);
	}
	return SUCCESS;
};

//File Output functions
int Reaction::SaveReaction(string InFilename) {
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
		//InFilename = GetDatabaseDirectory(GetParameter("database"),"new reaction directory")+InFilename;
		InFilename = FOutputFilepath()+"reactions/"+InFilename;
	}
	
	ofstream Output;
	if (!OpenOutput(Output,InFilename)) {
		return FAIL;
	}

	//First I check to see if the user specified that the input headers be printed in the output file
	vector<string>* FileHeader = StringToStrings(GetParameter("reaction data to print"),";");
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

	delete FileHeader;
	Output.close();
	return SUCCESS;
}

void Reaction::PrintExpaInputFileLine(ofstream& Output) {
	Output << GetData("NAME",STRING);
	if (FType() == FORWARD) {
		Output << " I";
	}
	else {
		Output << " R";
	}
	for (int i=0; i < FNumReactants(); i++) {
		Output << " " << GetReactantCoef(i) << " " << GetReactant(i)->GetData("NAME",STRING);
		if (GetReactantCompartment(i) == GetCompartment("e")->Index) {
			Output << "[e]";
			GetReactant(i)->SetKill(true);
		}
		else {
			GetReactant(i)->SetMark(true);
		}
	}
	Output << endl;
}

//Manipultion	
void Reaction::PerformAllCalculations(){
	if (GetParameter("balance reactions").compare("1") == 0) {
		BalanceReaction(GetParameter("automatically add H to balance").compare("1") ==0,GetParameter("automatically add electrons to balance").compare("1") ==0);
	}
	MakeCode("DATABASE",false);
	if (GetData("DEFINITION",STRING).length() == 0) {
		Query("DEFINITION");
	}
	if (GetParameter("calculate group change").compare("1") == 0) {
		CalculateGroupChange();
	} 
	if (GetParameter("calculate energy from groups").compare("1") == 0) {
		CalculateEnergyFromGroups();
		FEstDeltaGUncertainty();
	}
	if (GetParameter("calculate directionality from thermodynamics").compare("1") == 0) {
		Type = CalculateDirectionalityFromThermo();
	}
	if (GetParameter("Calculations:Reactions:transported atoms").compare("1") == 0) {
		this->CalculateTransportedAtoms();
	}
}

void Reaction::AdjustDeltaGpH(double NewpH, double OriginalpH, double ionicStr) {
	if (NewpH == OriginalpH || FEstDeltaG() == FLAG) {
		return;
	}
	
	EstDeltaG += CalcpHAdj(NewpH, OriginalpH, ionicStr);
}

double Reaction::CalcpHAdj(double NewpH, double OriginalpH,double ionicStr) {
	if (NewpH == OriginalpH) {
		return 0;
	}
	
	//FLogFile() << "Adjusting reaction " << GetData("NAME",STRING) << endl;
	double AdjustmentFactor = 1;
	double RefH = 0;
	for (int i=0; i < FNumReactants(); i++) {
		if ((GetReactant(i)->FFormula().compare("H2O") != 0) || (GetReactant(i)->FFormula().compare("H") != 0)) {
			vector<double> pKa = GetReactant(i)->GetpKaValues();
			//CAUTION!! THIS FUNCTION ASSUMES THAT THE H+ CURRENTLY PRESENT IN THE REACTION IS THE APPROPRIATE AMOUNT FOR PH 7
			RefH += GetReactantCoef(i)*GetReactant(i)->FRefHChange();
			AdjustmentFactor = AdjustmentFactor*pow(GetReactant(i)->FBindingPolynomial(NewpH,pKa),GetReactantCoef(i))*pow(GetReactant(i)->FBindingPolynomial(OriginalpH,pKa),-GetReactantCoef(i));
			//FLogFile() << "(" << GetReactantCoef(i) << ";" << GetReactant(i)->GetData("NAME",STRING) << ";" << RefH << ";" << AdjustmentFactor << ")" << endl;
		}
	}
	AdjustmentFactor = AdjustmentFactor*pow(pow(10,-OriginalpH)/pow(10,-NewpH),RefH);
	double Temperature = atof(GetParameter("Temperature").data());
	//FLogFile() << "Final adjustment: " << GAS_CONSTANT*Temperature*log(AdjustmentFactor) << endl;
	return GAS_CONSTANT*Temperature*log(AdjustmentFactor);
}

double Reaction::CalcIonicStrAdj(double NewIonicStrength, double OriginalIonicStrength) {
	if (NewIonicStrength == OriginalIonicStrength) {
		return 0;
	}
	
	double Temperature = atof(GetParameter("Temperature").data()); 

	double TotalAdjustment = 0;
	if (NewIonicStrength != 0) {
		for (int i=0; i < FNumReactants(); i++) {
			TotalAdjustment += -2.303*GAS_CONSTANT*Temperature*DEBYE_HUCKEL_A*GetReactantCoef(i)*pow(GetReactant(i)->FCharge(),2.0)*pow(NewIonicStrength,0.5)/(1+DEBYE_HUCKEL_B*pow(NewIonicStrength,0.5));
		}
	}

	if (OriginalIonicStrength != 0) {
		for (int i=0; i < FNumReactants(); i++) {
			TotalAdjustment += 2.303*GAS_CONSTANT*Temperature*DEBYE_HUCKEL_A*GetReactantCoef(i)*pow(GetReactant(i)->FCharge(),2.0)*pow(OriginalIonicStrength,0.5)/(1+DEBYE_HUCKEL_B*pow(OriginalIonicStrength,0.5));
		}
	}
	
	return TotalAdjustment;
}

void Reaction::ReverseReaction() {
	vector<int> Comp;
	vector<double> Coef;
	vector<Species*> Spec;
	for (int i=0; i < FNumReactants(REACTANT); i++) {
		Comp.push_back(GetReactantCompartment(i));
		Coef.push_back(GetReactantCoef(i));
		Spec.push_back(GetReactant(i));
		if ((FNumReactants(REACTANT)+i)<FNumReactants()) {
			Reactants[i] = Reactants[FNumReactants(REACTANT)+i];
			ReactCoef[i] = -ReactCoef[FNumReactants(REACTANT)+i];
			ReactCompartments[i] = ReactCompartments[FNumReactants(REACTANT)+i];
		}
	}
	for(int i = 0; i < int(Spec.size()); i++) {
		Reactants[i+FNumReactants(PRODUCT)] = Spec[i];
		ReactCoef[i+FNumReactants(PRODUCT)] = -Coef[i];
		ReactCompartments[i+FNumReactants(PRODUCT)] = Comp[i];
	}
	NumReactants = FNumReactants(PRODUCT);
}

void Reaction::CalculateGroupChange() {
	vector<Species*> OldStructuralCues;
	vector<double> OldNumStructuralCues;

	if (StructuralCues.size() > 0) {
		OldStructuralCues = StructuralCues;
		OldNumStructuralCues = NumStructuralCues;
		StructuralCues.clear();
		NumStructuralCues.clear();
	}

	if (GetParameter("overide errors").compare("0") == 0 && FErrorMessage().length() > 0) {
		return;
	}

	int i, j, k;
	for (i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FNumNoIDGroups() > 0 && !SpeciesCancels(GetReactant(i))) {
			FErrorFile() << "UNIDENTIFIED GROUPS: Reaction " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") involves unidentified groups" << endl;
			FlushErrorFile();
			AddLineToFile("ReactionsWithUnlabeledAtoms.txt",GetData("DATABASE",STRING));
			EstDeltaG = FLAG;
			return;
		}
		if ((GetReactant(i)->FFormula().length() >= 4 || GetReactant(i)->FFormula().length() == 0) && GetReactant(i)->GetData("STRUCTURE_FILE",STRING).length() == 0 && GetReactant(i)->FCode().length() == 0 && !SpeciesCancels(GetReactant(i))) {
			FErrorFile() << "UNKNOWN STRUCTURES: Reaction " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") involves unknown structures" << endl;
			FlushErrorFile();
			AddLineToFile("ReactionsWithUnknownStuctures.txt",GetData("DATABASE",STRING));
			EstDeltaG = FLAG;
			return;
		}
	}

	bool AllSpeciesCancel = true;
	for (i=0; i < FNumReactants(); i++) {
		if (!SpeciesCancels(GetReactant(i))) {
			AllSpeciesCancel = false;
			for (j=0; j < GetReactant(i)->FNumStructuralCues(); j++) {
				for (k=0; k < FNumStructuralCues(); k++) {
					if (GetStructuralCue(k) == GetReactant(i)->GetStructuralCue(j)) {
						NumStructuralCues[k] += GetReactantCoef(i)*GetReactant(i)->GetStructuralCueNum(j);
						break;
					}
				}
				if (k == FNumStructuralCues()) {
					NumStructuralCues.push_back(GetReactantCoef(i)*GetReactant(i)->GetStructuralCueNum(j));
					StructuralCues.push_back(GetReactant(i)->GetStructuralCue(j));
				}
			}
		}
	}

	if (AllSpeciesCancel == true) {
		EstDeltaGUncertainty = 0;
	}
	else {
		FEstDeltaGUncertainty();
	}
	
	for (k=0; k < FNumStructuralCues(); k++) {
		if (NumStructuralCues[k] == 0) {
			StructuralCues.erase(StructuralCues.begin()+k,StructuralCues.begin()+k+1);
			NumStructuralCues.erase(NumStructuralCues.begin()+k,NumStructuralCues.begin()+k+1);
			k--;
		}
	}

	if (OldStructuralCues.size() > 0) {
		for (j=0; j < int(StructuralCues.size()); j++) {
			for (i=0; i < int(OldStructuralCues.size()); i++) {
				if (StructuralCues[j] == OldStructuralCues[i]) {
					double Diff = (NumStructuralCues[j] - OldNumStructuralCues[i]);
					if (Diff != 0) {
						FErrorFile() << "REACTION GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << Diff << " more " << StructuralCues[j]->GetData("NAME",STRING) << endl;
						FlushErrorFile();
					}
					OldNumStructuralCues[i] = 0;
					i = int(OldStructuralCues.size()+10);
				}	
			}
			if (i != int(OldStructuralCues.size()+11)) {
				FErrorFile() << "REACTION GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << NumStructuralCues[j] << " of new group " << StructuralCues[j]->GetData("NAME",STRING) << endl;
				FlushErrorFile();
			}
		}
		for (i=0; i < int(OldStructuralCues.size()); i++) {
			if (OldNumStructuralCues[i] != 0) {
				FErrorFile() << "REACTION GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << -OldNumStructuralCues[i] << " more " << OldStructuralCues[i]->GetData("NAME",STRING) << endl;
				FlushErrorFile();
			}	
		}
	}
}

bool Reaction::BalanceReaction(bool AddH, bool AddE) {
	int i, j, k;

	bool Balanced = true;

	vector<AtomType*> AtomVector;
	vector<double> NumAtoms;
	double Charge = 0;

	if (GetParameter("load compound structure").compare("1") == 0 && ContainsUnknownStructures() > 0) {
		if (GetParameter("calculate energy from groups").compare("1") == 0) {
			CalculateEnergyFromGroups();
			FEstDeltaGUncertainty();
		}
		return false;
	}

	//Check first for any problems with TranslateFormulaToAtoms
	for (i=0; i < FNumReactants(); i++) {
	  if (GetReactant(i)->FNumAtoms() == 0) {
	    GetReactant(i)->TranslateFormulaToAtoms();
	    if (GetReactant(i)->FNumAtoms() == 0) {
	      return false;  //if translation is still false, then either "noformula" or "*2"
	    }
	  }
	}
	
	for (i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FNumAtoms() == 0) {
			GetReactant(i)->TranslateFormulaToAtoms();
		}
		Charge += GetReactantCoef(i)*GetReactant(i)->FCharge();
		for (j=0; j < GetReactant(i)->FNumAtoms(); j++) {
			for (k=0; k < int(AtomVector.size()); k++) {
				if (GetReactant(i)->GetAtom(j)->FType() == AtomVector[k]) {
					NumAtoms[k] += GetReactantCoef(i);
					break;
				}
			}
			if (k >= int(AtomVector.size())) {
				AtomVector.push_back(GetReactant(i)->GetAtom(j)->FType());
				NumAtoms.push_back(GetReactantCoef(i));
			}
		}
	}
	
	if (Charge != 0) {
		if (GetData("NAME",STRING).length() > 0) {
			FErrorFile() << "CHARGE IMBALANCE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") is charge imbalanced: " << Charge << endl;
			FlushErrorFile();
		}
		else {
			FErrorFile() << "CHARGE IMBALANCE: " << GetData("DATABASE",STRING) << " is charge imbalanced: " << Charge << endl;
			FlushErrorFile();
		}
	}

	bool HEOnly = true;
	double NumH = 0;
	double NumE = 0;
	string status = "";
	for (i=0; i < int(AtomVector.size()); i++) {
		if (NumAtoms[i] != 0) {
			FErrorFile() << "MASS IMBALANCE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") is missbalanced: " << NumAtoms[i] << " " << AtomVector[i]->FID() << endl;
			FlushErrorFile();
			if (AtomVector[i]->FID().compare("H") == 0) {
				NumH = -NumAtoms[i];
			} else if (AtomVector[i]->FID().compare("E") == 0) {
				NumE = -NumAtoms[i];
			} else {
				if (status.length() == 0) {
					status += "MI:";
				} else {
					status += "/";
				}
				status = status + AtomVector[i]->FID() + dtoa(NumAtoms[i]);
				HEOnly = false;
			}
		}
	}

	if (HEOnly && NumH != 0 && AddH) {
		for (j=0; j< MainData->FNumSpecies(); j++) {
			if (MainData->GetSpecies(j)->FFormula().compare("H") == 0) {
				AddReactant(MainData->GetSpecies(j),NumH,Compartment); 
				FErrorFile() << "** Added " << NumH << " H+ **" << endl;
				FlushErrorFile();
				break;
			}
		}
		if (j == MainData->FNumSpecies()) {
			Species* NewSpecies = MainData->FindSpecies("NAME","H+");
			if (NewSpecies != NULL) {
				AddReactant(NewSpecies,NumH,Compartment); 
				FErrorFile() << "** Added " << NumH << " H+ **" << endl;
				FlushErrorFile();
			}
		}
		NumH = 0;
	} else if (!HEOnly) {
		Balanced = false;
		AddErrorMessage("Atoms imbalanced");
		AddLineToFile("MassImblancedReactions.txt",GetData("DATABASE",STRING));
	}

	Charge = 0;
	for (i=0; i < FNumReactants(); i++) {
		Charge += GetReactantCoef(i)*GetReactant(i)->FCharge();
	}	

	if (HEOnly && Charge != 0 && AddE) {
		for (j=0; j< MainData->FNumSpecies(); j++) {
			if (MainData->GetSpecies(j)->FFormula().compare("E") == 0) {
				AddReactant(MainData->GetSpecies(j),Charge,Compartment); 
				FErrorFile() << "** Added " << Charge << " E- **" << endl;
				FlushErrorFile();
				break;
			}
		}
		if (j == MainData->FNumSpecies()) {
			Species* NewSpecies = MainData->FindSpecies("NAME","e-");
			if (NewSpecies != NULL) {
				AddReactant(NewSpecies,Charge,Compartment); 
				FErrorFile() << "** Added " << Charge << " E- **" << endl;
				FlushErrorFile();
			}
		}
		Charge = 0;
	}	

	if (Charge != 0) {
		if (status.length() > 0) {
			status.append("|");
		}
		status = status + "CI:"+dtoa(Charge);
		Balanced = false;
		AddErrorMessage("Charge imbalanced");
		if (GetData("NAME",STRING).length() > 0) {
			FErrorFile() << "CHARGE IMBALANCE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") is charge imbalanced: " << Charge << endl;
			FlushErrorFile();
		} else {
			FErrorFile() << "CHARGE IMBALANCE: " << GetData("DATABASE",STRING) << " is charge imbalanced: " << Charge << endl;
			FlushErrorFile();
		}
		AddLineToFile("ChargeImblancedReactions.txt",GetData("DATABASE",STRING));
	}

	if (NumH != 0) {
		if (status.length() > 0) {
			status.append("|");
		}
		status = status + "HI:"+dtoa(NumH);
		Balanced = false;
		AddErrorMessage("H imbalanced");
		AddLineToFile("HImblancedReactions.txt",GetData("DATABASE",STRING));
		if (GetData("NAME",STRING).length() > 0) {
			FErrorFile() << "H IMBALANCE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") is H+ imbalanced: " << NumH << endl;
			FlushErrorFile();
		} else {
			FErrorFile() << "H IMBALANCE: " << GetData("DATABASE",STRING) << " is H+ imbalanced: " << NumH << endl;
			FlushErrorFile();
		}
	}
	if (status.length() > 0) {
		this->SetData("STATUS",status.data(),STRING);
	}
	return Balanced;
}

void Reaction::CalculateEnergyFromGroups() {
	EstDeltaG = 0;

	if (GetParameter("overide errors").compare("0") == 0 && FErrorMessage().length() > 0) {
		return;
	}

	int i;
	for (i=0; i < FNumReactants(); i++) {
		if (GetReactant(i)->FNumNoIDGroups() > 0 && !SpeciesCancels(GetReactant(i))) {
			AddErrorMessage("Involves compounds with unlabeded atoms");
			EstDeltaG = FLAG;
			return;
		}
		if (GetReactant(i)->FNumStructuralCues() == 0 && !SpeciesCancels(GetReactant(i))) {
			AddErrorMessage("Involves compounds that were not decomposed into groups");
			EstDeltaG = FLAG;
			return;
		}
	}

	for (i=0; i < FNumStructuralCues(); i++) {
		if (GetStructuralCue(i)->FEstDeltaG() == -10000 || GetStructuralCue(i)->FEstDeltaG() == FLAG) {
			AddErrorMessage("Involves groups with unknown energies");
			AddLineToFile("ReactionsWithUnknownEnergyGroups.txt",GetData("DATABASE",STRING));
			EstDeltaG = FLAG;
			return;
		} else {
			EstDeltaG += GetStructuralCueNum(i)*GetStructuralCue(i)->FEstDeltaG();
		}
	}

	EstDeltaGUncertainty = FLAG;
	FEstDeltaGUncertainty();
}

void Reaction::AddToReactants() {
	for(int i=0; i < FNumReactants(); i++) {
		GetReactant(i)->AddReaction(this);
	}
}

bool Reaction::MarkProducts() {
	for (int i=0; i < NumReactants; i++) {
		if (!GetReactant(i)->FMark()) {
			return false;
		}
	}

	SetKill(true);
	bool NewMarks = false;
	for (int i=NumReactants; i < FNumReactants(); i++) {
		if (!GetReactant(i)->FMark()) {
			NewMarks = true;
			GetReactant(i)->SetKill(true);
		}
	}

	return NewMarks;
}

void Reaction::ReplaceAllLinkedReactants() {
	vector<Reaction*> NewReactions;
	SetMark(false);
	for (int i=0; i < FNumReactants(); i++) {
		string ForeignDBName = GetReactant(i)->GetData("FOREIGN",STRING);
		if (ForeignDBName.length() > 0) {
			vector<string> Links = GetReactant(i)->GetAllData("LINK",STRING);
			bool MatchFound = false;
			for (int j=0; j < int(Links.size()); j++) {
				if (ForeignDBName.compare(Links[j]) == 0) {
					Reaction* NewReaction = Clone();
					NewReaction->AddReactant(MainData->GetSpecies(int(GetReactant(i)->GetDoubleData("LINK_ID"))),GetReactantCoef(i),GetReactantCompartment(i),IsReactantCofactor(i));
					NewReaction->RemoveCompound(GetReactant(i),GetReactantCompartment(i));
					string DBID = NewReaction->GetData("DATABASE",STRING);
					NewReaction->ClearData("DATABASE",STRING);
					DBID.append("-");
					DBID.append(itoa(j));
					NewReaction->AddData("DATABASE",DBID.data(),STRING);
					if (NewReaction->ContainsMarkedReactants()) {
						NewReaction->ReplaceAllLinkedReactants();
						if (!NewReaction->FMark()) {
							NewReactions.push_back(NewReaction);
						}
					} else {
						NewReactions.push_back(NewReaction);
					}
					SetMark(true);
				}
			}
			if (FMark()) {
				for (int j=0; j < int(NewReactions.size()); j++) {
					MainData->AddReaction(NewReactions[j]);
				}
				return;
			}
		}
	}
}

void Reaction::FormGeneComplexesFromNeighbors() {
	int OriginalGeneCount = int(GeneDependency.size());
	//I move through the list of supposedly independant genes and see if an earlier gene is neighboring a later gene
	for (int i=0; i < int(GeneDependency.size()-1); i++) {
		//First I store the list of neighbors for each gene complex cluster
		vector<string> NextNeighbors;
		vector<string> PreviousNeighbors;
		for (int j=0; j < int(GeneDependency[i].size()); j++) {
			if (GeneDependency[i][j]->GetData("FORWARD NEIGHBOR",STRING).length() > 0) {
				NextNeighbors.push_back(GeneDependency[i][j]->GetData("FORWARD NEIGHBOR",STRING));
			}
			if (GeneDependency[i][j]->GetData("PREVIOUS NEIGHBOR",STRING).length() > 0) {
				PreviousNeighbors.push_back(GeneDependency[i][j]->GetData("PREVIOUS NEIGHBOR",STRING));
			}
		}
		//Then I determine if any of the neighbors in the list are a part of another gene complex cluster assigned to the same reaction
		for (int k=i+1; k < int(GeneDependency.size()); k++) {
			bool Combine = false;
			for (int j=0; j < int(GeneDependency[k].size()); j++) {
				for (int m=0; m < int(NextNeighbors.size()); m++) {
					if (NextNeighbors[m].compare(GeneDependency[k][j]->GetData("DATABASE",STRING)) == 0) {
						Combine = true;
						break;
					}
				}
				if (Combine) {
					break;
				}
				for (int m=0; m < int(PreviousNeighbors.size()); m++) {
					if (PreviousNeighbors[m].compare(GeneDependency[k][j]->GetData("DATABASE",STRING)) == 0) {
						Combine = true;
						break;
					}
				}
			}
			if (Combine) {
				//A matching neighbor was found in this gene cluster, so I add this gene cluster to the current reference gene cluster then delete this gene cluster
				for (int j=0; j < int(GeneDependency[k].size()); j++) {
					GeneDependency[i].push_back(GeneDependency[k][j]);
					//I also add the neighbors of this new portion of the cluster
					if (GeneDependency[k][j]->GetData("FORWARD NEIGHBOR",STRING).length() > 0) {
						NextNeighbors.push_back(GeneDependency[k][j]->GetData("FORWARD NEIGHBOR",STRING));
					}
					if (GeneDependency[k][j]->GetData("PREVIOUS NEIGHBOR",STRING).length() > 0) {
						PreviousNeighbors.push_back(GeneDependency[k][j]->GetData("PREVIOUS NEIGHBOR",STRING));
					}
				}
				//Deleting this gene cluster
				GeneDependency.erase(GeneDependency.begin()+k,GeneDependency.begin()+k+1);
				//Finally I restart the search since the neighbor list has been expanded now
				k = i;
			}
		}
	}

	if (OriginalGeneCount > int(GeneDependency.size())) {
		SetMark(true);
		FLogFile() << GetData("DATABASE",STRING) << " reaction genes combined from " << OriginalGeneCount << " to " << GeneDependency.size() << endl;
	}
}

int Reaction::CalculateDirectionalityFromThermo() {
	int NewType = Type;
	//Finding ATP, Pi, ADP, AMP, PPi
	if (GetParameter("Always reversible reactions").find(GetData("DATABASE",STRING)) != -1) {
		return REVERSIBLE;
	}
	if (GetParameter("Always forward reactions").find(GetData("DATABASE",STRING)) != -1) {
		return FORWARD;
	}
	Species* ATP = MainData->FindSpecies("DATABASE","cpd00002");
	Species* Pi = MainData->FindSpecies("DATABASE","cpd00009");
	Species* ADP = MainData->FindSpecies("DATABASE","cpd00008");
	Species* PPi = MainData->FindSpecies("DATABASE","cpd00012");
	Species* AMP = MainData->FindSpecies("DATABASE","cpd00018");
	double ATPCoeff = GetReactantCoef(ATP);
	double ADPCoeff = GetReactantCoef(ADP);
	double AMPCoeff = GetReactantCoef(AMP);
	double PiCoeff = GetReactantCoef(Pi);
	double PPiCoeff = GetReactantCoef(PPi);
	double ATPContent = 0;
	//If ATP is consumed and ADP and Pi are produced, this reaction involves hydolysis
	if (ATPCoeff*ADPCoeff < 0 && ATPCoeff*PiCoeff < 0) {
		if (fabs(ATPCoeff) < fabs(ADPCoeff)) {
			if (fabs(ATPCoeff) < fabs(PiCoeff)) {
				ATPContent = fabs(ATPCoeff);
			} else {
				ATPContent = fabs(PiCoeff);
			}
		} else if (fabs(ADPCoeff) < fabs(PiCoeff)) {
			ATPContent = fabs(ADPCoeff);
		} else {
			ATPContent = fabs(PiCoeff);
		}
	} else if (ATPCoeff*AMPCoeff < 0 && ATPCoeff*PPiCoeff < 0) {
		if (fabs(ATPCoeff) < fabs(AMPCoeff)) {
			if (fabs(ATPCoeff) < fabs(PPiCoeff)) {
				ATPContent = fabs(ATPCoeff);
			} else {
				ATPContent = fabs(PPiCoeff);
			}
		} else if (fabs(AMPCoeff) < fabs(PPiCoeff)) {
			ATPContent = fabs(AMPCoeff);
		} else {
			ATPContent = fabs(PPiCoeff);
		}
	}
	
	//Finding other low energy species and adding up the points
	double Points = ATPContent*ATPCoeff;
	vector<string>* Strings = StringToStrings(GetParameter("Low energy compounds"),";");
	string CofactorList;
	CofactorList.append(dtoa(ATPContent));
	CofactorList.append("|");
	for (int i=0; i < int(Strings->size()); i++) {
		double CurrentCoeff = GetReactantCoef(MainData->FindSpecies("DATABASE",(*Strings)[i].data()));
		Points = Points + -1*CurrentCoeff;
		CofactorList.append(dtoa(CurrentCoeff));
		CofactorList.append("|");
	}
	delete Strings;
	SetData("REACTION_TYPE_DATA",CofactorList.data(),STRING);
	
	bool Forward = false;
	bool Reverse = false;
	if (FEstDeltaGMin(true) < 0) {
		Forward = true;
	}
	if (FEstDeltaGMax(true) > 0) {
		Reverse = true;
	}
	if ((Forward && Reverse) || FEstDeltaG() == FLAG) {
		NewType = REVERSIBLE;
	} else if (Forward) {
		SetData("THERMO_CLASS","IRREVERSIBLE_BY_DELTAG_MINMAX",STRING);
		NewType = FORWARD;
		return NewType;
	} else {
		SetData("THERMO_CLASS","IRREVERSIBLE_BY_DELTAG_MINMAX",STRING);
		NewType = REVERSE;
		return NewType;
	}

	if (NewType == REVERSIBLE && GetParameter("Use directionality rules of thumb").compare("1") == 0) {
		//If this is a transport reaction involving ATP hydrolysis, it is irreversible unless H+ is transported
		if (ATPContent > 0) {
			bool Cytosol = false;
			bool Noncytosol = false;
			for (int i=0; i < FNumReactants(); i++) {
				if (GetReactantCompartment(i) == GetCompartment("c")->Index) {
					Cytosol = true;
				} else {
					Noncytosol = true;
					if (GetReactant(i)->GetData("DATABASE",STRING).compare("cpd00067") == 0) {
						//This is ATP synthase and should be reversible
						SetData("THERMO_CLASS","REVERSIBLE_ATP_SYNTHASE",STRING);
						return NewType;
					}
				}
			}
			//ABC transporters are irreversible
			if (Cytosol && Noncytosol && ATPContent != 0 && ATPCoeff < 0) {
				NewType = FORWARD;
				SetData("THERMO_CLASS","IRREVERSIBLE_ABC_TRANSPORTER",STRING);
				return NewType;
			} else if (Cytosol && Noncytosol && ATPContent != 0 && ATPCoeff > 0) {
				SetData("THERMO_CLASS","IRREVERSIBLE_ABC_TRANSPORTER",STRING);
				NewType = REVERSE;
				return NewType;
			}
		}

		//Now that we're sure this is not an ABC transporter, we calculating mM deltaG
		double mMDeltaG = FmMDeltaG(true);
		if (mMDeltaG >= -2 && mMDeltaG <= 2) {
			SetData("THERMO_CLASS","REVERSIBLE_BY_MM_DELTAG",STRING);	
			return NewType;
		}

		if (Points < 0 && mMDeltaG < 0 && mMDeltaG != FLAG) {
			SetData("THERMO_CLASS","IRREVERSIBLE_BY_POINTS",STRING);
			NewType = FORWARD;
			return NewType;
		} else if (Points > 0 && mMDeltaG > 0 && mMDeltaG != FLAG) {
			SetData("THERMO_CLASS","IRREVERSIBLE_BY_POINTS",STRING);
			NewType = REVERSE;
			return NewType;
		} else {
			if (Points == 0) {
				SetData("THERMO_CLASS","REVERSIBLE_BY_POINTS",STRING);
			} else if (mMDeltaG != FLAG) {
				SetData("THERMO_CLASS","REVERSIBLE_BY_POINT_DELTAG_CONFLICT",STRING);
			} else {
				SetData("THERMO_CLASS","REVERSIBLE_BY_POINT_UNKNOWN_DELTAG",STRING);
			}
			return NewType;
		}
	}
	return NewType;
}

string Reaction::CalculateTransportedAtoms() {
	map<string,double> atomCount;
	for (int i=0; i < FNumReactants(); i++) {
		if (GetCompartment(GetReactantCompartment(i))->Name.compare("extracellular") == 0) {
			if (GetReactant(i)->FNumAtoms() == 0) {
				GetReactant(i)->TranslateFormulaToAtoms();
			}
			for (int j=0; j < GetReactant(i)->FNumAtoms(); j++) {
				if (atomCount.count(GetReactant(i)->GetAtom(j)->FType()->FID()) == 0) {
					atomCount[GetReactant(i)->GetAtom(j)->FType()->FID()] = 0;
				}
				atomCount[GetReactant(i)->GetAtom(j)->FType()->FID()] += GetReactantCoef(i);
			}
		}
	}
	string result;
	for (map<string,double>::iterator IT = atomCount.begin();IT != atomCount.end(); IT++) {
		if (result.length() > 0) {
			result.append("|");
		}
		result.append(IT->first+":"+dtoa(IT->second));
	}
	this->SetData("TRANSATOMS",result.data(),STRING);
	if (result.length() > 0) {
		this->AddData("INPUT_HEADER","TRANSATOMS",STRING);
	}
	return result;
}

//Pathway functions
bool Reaction::AddPathway(Pathway* InPathway, bool ShortestOnly) {
	if (PathwayList == NULL) {
		PathwayList = new list<Pathway*>;
		PathwayList->push_back(InPathway);
		return true;
	} else {
		if (ShortestOnly) {
			if (InPathway->Length == (*PathwayList->begin())->Length) {
				PathwayList->push_back(InPathway);
				return true;
			} else if (InPathway->Length < (*PathwayList->begin())->Length) {
				cout << "Longer pathways need to be cleared!" << endl;
				list<Pathway*>::iterator ListIT = PathwayList->begin();
				for (int i=0; i < int(PathwayList->size()); i++) {
					delete [] (*ListIT)->Intermediates;
					delete [] (*ListIT)->Reactions;
					delete [] (*ListIT)->Directions;
					delete (*ListIT);
					ListIT++;
				}
				PathwayList->clear();
				PathwayList->push_back(InPathway);
				return true;
			}
		} else {
			PathwayList->push_back(InPathway);
			return true;
		}
	}
	return false;
}

Pathway* Reaction::GetLinearPathway(int InIndex) {
	if (PathwayList == NULL) {
		return NULL;
	}
	list<Pathway*>::iterator PathwayListIT = PathwayList->begin();
	for (int i=0; i < InIndex; i++) {
		PathwayListIT++;
	}

	return (*PathwayListIT);
}

int Reaction::FNumLinearPathways() {
	if (PathwayList == NULL) {
		return 0;
	} else {
		return int(PathwayList->size());
	}
}

int Reaction::FPathwayLength() {
	if (PathwayList == NULL) {
		return -1;
	} else {
		return (*PathwayList->begin())->Length;
	}
}

//Metabolic flux analysis functions
void Reaction::CreateReactionDrainFluxes() {
	for (int i=0; i < this->FNumReactants(); i++) {
		MFAVariable* DrainVariable = this->GetReactant(i)->GetMFAVar(DRAIN_FLUX,this->GetReactantCompartment(i));
		if (DrainVariable == NULL) {
			DrainVariable = this->GetReactant(i)->CreateMFAVariable(DRAIN_FLUX,this->GetReactantCompartment(i),-100,0);
		}
		if (this->GetReactantCoef(i) < 0) {
			DrainVariable->UpperBound = 0;
			DrainVariable->LowerBound = -100;
		} else {
			DrainVariable->UpperBound = 100;
			DrainVariable->LowerBound = 0;
		}
	}
}

void Reaction::CreateMFAVariables(OptimizationParameter* InParameters) {
	MFAVariable* NewVariable = NULL;
	if (InParameters->MassBalanceConstraints) {
		if (!FMark()) {
			if (Type == REVERSIBLE || InParameters->AllReversible) {
				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				if (InParameters->DecomposeReversible) {
					NewVariable->Type = FORWARD_FLUX;
					MFAVariables[FORWARD_FLUX] = NewVariable;
					if (InParameters->MaxFlux > 0) {
						NewVariable->UpperBound = InParameters->MaxFlux;
					}
					if (InParameters->MinFlux < 0) {
						NewVariable->LowerBound = 0;
					} else {
						NewVariable->LowerBound = InParameters->MinFlux;
					}
					NewVariable = InitializeMFAVariable();
					NewVariable->Name = GetData("DATABASE",STRING);
					NewVariable->AssociatedReaction = this;
					NewVariable->Type = REVERSE_FLUX;
					MFAVariables[REVERSE_FLUX] = NewVariable;
					if (InParameters->MaxFlux < 0) {
						NewVariable->LowerBound = -InParameters->MaxFlux;
					} else {
						NewVariable->LowerBound = 0;
					}
					if (InParameters->MinFlux < 0) {
						NewVariable->UpperBound = -InParameters->MinFlux;
					}
				} else {
					NewVariable->Type = FLUX;
					MFAVariables[FLUX] = NewVariable;
					NewVariable->UpperBound = InParameters->MaxFlux;
					NewVariable->LowerBound = InParameters->MinFlux;
				}
			} else if (Type == FORWARD) {
				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				NewVariable->Type = FLUX;
				MFAVariables[FLUX] = NewVariable;
				NewVariable->UpperBound = InParameters->MaxFlux;
				NewVariable->LowerBound = 0;
			} else if (Type == REVERSE) {
				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				if (InParameters->DecomposeReversible) {
					NewVariable->Type = REVERSE_FLUX;
					MFAVariables[REVERSE_FLUX] = NewVariable;
					if (InParameters->MaxFlux < 0) {
						NewVariable->LowerBound = -InParameters->MaxFlux;
					} else {
						NewVariable->LowerBound = 0;
					}
					if (InParameters->MinFlux < 0) {
						NewVariable->UpperBound = -InParameters->MinFlux;
					}
				} else {
					NewVariable->Type = FLUX;
					MFAVariables[FLUX] = NewVariable;
					NewVariable->UpperBound = 0;
					NewVariable->LowerBound = InParameters->MinFlux;
				}
			}
		}
	}
	
	if (InParameters->ThermoConstraints) {
		//Creating the delta G variable
		NewVariable = InitializeMFAVariable();
		NewVariable->Name = GetData("DATABASE",STRING);
		NewVariable->AssociatedReaction = this;
		NewVariable->Type = DELTAG;
		MFAVariables[DELTAG] = NewVariable;
		NewVariable->LowerBound = -MFA_THERMO_CONST;
		NewVariable->UpperBound = MFA_THERMO_CONST;
		if (FEstDeltaG() != FLAG && InParameters->DeltaGError) {
			//Creating the delta G error variable
			NewVariable = InitializeMFAVariable();
			NewVariable->Name = GetData("DATABASE",STRING);
			NewVariable->AssociatedReaction = this;
			NewVariable->Type = REACTION_DELTAG_ERROR;
			MFAVariables[REACTION_DELTAG_ERROR] = NewVariable;
			if (InParameters->MaxError == FLAG) {
				NewVariable->UpperBound = InParameters->ErrorMult*FEstDeltaGUncertainty();
				NewVariable->LowerBound = -InParameters->ErrorMult*FEstDeltaGUncertainty();
			} else {
				NewVariable->UpperBound = InParameters->MaxError;
				NewVariable->LowerBound = -InParameters->MaxError;
			}
			//Adding use variables for errors if they are to be included
			if (InParameters->ReactionErrorUseVariables) {
				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				NewVariable->Type = REACTION_DELTAG_PERROR;
				MFAVariables[REACTION_DELTAG_PERROR] = NewVariable;
				if (InParameters->MaxError == FLAG) {
					NewVariable->UpperBound = InParameters->ErrorMult*FEstDeltaGUncertainty();
					NewVariable->LowerBound = 0;
				} else {
					NewVariable->UpperBound = InParameters->MaxError;
					NewVariable->LowerBound = 0;
				}

				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				NewVariable->Type = REACTION_DELTAG_NERROR;
				MFAVariables[REACTION_DELTAG_NERROR] = NewVariable;
				if (InParameters->MaxError == FLAG) {
					NewVariable->UpperBound = InParameters->ErrorMult*FEstDeltaGUncertainty();
					NewVariable->LowerBound = 0;
				} else {
					NewVariable->UpperBound = InParameters->MaxError;
					NewVariable->LowerBound = 0;
				}
				
				NewVariable = InitializeMFAVariable();
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedReaction = this;
				NewVariable->Type = SMALL_DELTAG_ERROR_USE;
				MFAVariables[SMALL_DELTAG_ERROR_USE] = NewVariable;
				NewVariable->LowerBound = 0;
				NewVariable->UpperBound = 1;
				NewVariable->Binary = true;
				if (InParameters->MaxError != FLAG) {
					//NewVariable = InitializeMFAVariable();
					//NewVariable->Name = GetData("DATABASE",STRING);
					//NewVariable->AssociatedReaction = this;
					//NewVariable->Type = LARGE_DELTAG_ERROR_USE;
					//MFAVariables[LARGE_DELTAG_ERROR_USE] = NewVariable;
					//NewVariable->LowerBound = 0;
					//NewVariable->UpperBound = 1;
					//NewVariable->Binary = true;
				}
			}
		}
		if (FMark()) {
			NewVariable = InitializeMFAVariable();
			NewVariable->AssociatedReaction = this;
			NewVariable->Binary = true;
			NewVariable->Type = LUMP_USE;
			MFAVariables[LUMP_USE] = NewVariable;
			NewVariable->LowerBound = 0;
			NewVariable->UpperBound = 1;
		}
	}

	if (InParameters->GeneConstraints) {
		for (int i=0; i < FNumGeneGroups(); i++) {
			if (GeneDependency[i].size() > 1) {
				MFAVariable* NewComplexVariable = InitializeMFAVariable();
				NewComplexVariable->Name = GetData("DATABASE",STRING);
				NewComplexVariable->UpperBound = 1;
				NewComplexVariable->LowerBound = 0;
				NewComplexVariable->Binary = true;
				NewComplexVariable->Type = COMPLEX_USE;
				NewComplexVariable->AssociatedReaction = this;

				ComplexMFAVariables.push_back(NewComplexVariable);
			} else {
				ComplexMFAVariables.push_back(NULL);
			}
		}
	}
}

void Reaction::UpdateBounds(int VarType, double Min, double Max, bool ApplyToMinMax) {
	MFAVariable* NewVariable = NULL;
	
	NewVariable = MFAVariables[VarType];
	if (NewVariable != NULL) {
		if (ApplyToMinMax) {
			NewVariable->Max = Max;
			NewVariable->Min = Min;
		} else {
			NewVariable->UpperBound = Max;
			NewVariable->LowerBound = Min;
		}
	} else {
		if (VarType == FLUX) {
			NewVariable = MFAVariables[FORWARD_FLUX];
			if (NewVariable != NULL) {
				if (ApplyToMinMax) {
					if (Max > 0) {
						NewVariable->Max = Max;
					} else {
						NewVariable->Max = 0;
					}
					if (Min > 0) {
						NewVariable->Min = Min;
					} else {
						NewVariable->Min = 0;
					}
				} else {
					if (Max > 0) {
						NewVariable->UpperBound = Max;
					} else {
						NewVariable->UpperBound = 0;
					}
					if (Min > 0) {
						NewVariable->LowerBound = Min;
					} else {
						NewVariable->LowerBound = 0;
					}
				}
			}
			NewVariable = MFAVariables[REVERSE_FLUX];
			if (NewVariable != NULL) {
				if (ApplyToMinMax) {
					if (Max < 0) {
						NewVariable->Min = -Max;
					} else {
						NewVariable->Min = 0;
					}
					if (Min < 0) {
						NewVariable->Max = -Min;
					} else {
						NewVariable->Max = 0;
					}
				} else {
					if (Max < 0) {
						NewVariable->LowerBound = -Max;
					} else {
						NewVariable->LowerBound = 0;
					}
					if (Min < 0) {
						NewVariable->UpperBound = -Min;
					} else {
						NewVariable->UpperBound = 0;
					}
				}
			}
		} else if (VarType == FORWARD_FLUX) {
			NewVariable = MFAVariables[FLUX];
			if (NewVariable != NULL) {
				if (ApplyToMinMax) {
					NewVariable->Max = Max;
					if (Min > 0) {
						NewVariable->Min = Min;
					}
				} else {
					NewVariable->UpperBound = Max;
					if (Min > 0) {
						NewVariable->LowerBound = Min;
					}
				}
			}
		} else if (VarType == REVERSE_FLUX) {
			NewVariable = MFAVariables[FLUX];
			if (ApplyToMinMax) {
				if (NewVariable != NULL) {
					if (Min > 0) {
						NewVariable->Max = -Min;
					}
					NewVariable->Min = -Max;
				}
			} else {
				if (NewVariable != NULL) {
					if (Min > 0) {
						NewVariable->UpperBound = -Min;
					}
					NewVariable->LowerBound = -Max;
				}
			}
		}
	}
}

void Reaction::AddUseVariables(OptimizationParameter* InParameters) {
	if (InParameters == NULL) {
		return;
	}
	if (InParameters->ReactionsUse && !FMark()) {
		MFAVariable* NewVariable = MFAVariables[FLUX];
		if (NewVariable != NULL) {
			if (InParameters->AllReactionsUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
				bool IncludeUseVariable = true;
				if (InParameters->BlockedReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->BlockedReactions[GetData("DATABASE",STRING)] != -1) {
					IncludeUseVariable = false;
				}
				if (InParameters->AlwaysActiveReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->AlwaysActiveReactions[GetData("DATABASE",STRING)] != -1) {
					IncludeUseVariable = false;
				}
				if (IncludeUseVariable) {
					NewVariable = InitializeMFAVariable();
					NewVariable->AssociatedReaction = this;
					NewVariable->Type = REACTION_USE;
					NewVariable->Name.assign("+");
					NewVariable->Name.append(GetData("DATABASE",STRING));
					MFAVariables[REACTION_USE] = NewVariable;
					NewVariable->Binary = true;
					NewVariable->UpperBound = 1;
					NewVariable->LowerBound = 0;
				}
			}
		} else {
			NewVariable = MFAVariables[FORWARD_FLUX];
			if (NewVariable != NULL) {
				if (InParameters->AllDrainUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
					bool IncludeUseVariable = true;
					if (InParameters->BlockedReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->BlockedReactions[GetData("DATABASE",STRING)] != -1) {
						IncludeUseVariable = false;
					}
					if (InParameters->AlwaysActiveReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->AlwaysActiveReactions[GetData("DATABASE",STRING)] != -1) {
						IncludeUseVariable = false;
					}
					if (IncludeUseVariable) {
						NewVariable = InitializeMFAVariable();
						NewVariable->AssociatedReaction = this;
						NewVariable->Name.assign("+");
						NewVariable->Name.append(GetData("DATABASE",STRING));
						NewVariable->Type = FORWARD_USE;
						MFAVariables[FORWARD_USE] = NewVariable;
						NewVariable->Binary = true;
						NewVariable->UpperBound = 1;
						NewVariable->LowerBound = 0;
					}
				}
			}
			NewVariable = MFAVariables[REVERSE_FLUX];
			if (NewVariable != NULL) {
				if (InParameters->AllDrainUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
					bool IncludeUseVariable = true;
					if (InParameters->BlockedReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->BlockedReactions[GetData("DATABASE",STRING)] != 1) {
						IncludeUseVariable = false;
					}
					if (InParameters->AlwaysActiveReactions.count(GetData("DATABASE",STRING)) > 0 && InParameters->AlwaysActiveReactions[GetData("DATABASE",STRING)] != 1) {
						IncludeUseVariable = false;
					}
					if (IncludeUseVariable) {
						NewVariable = InitializeMFAVariable();
						NewVariable->AssociatedReaction = this;
						NewVariable->Name.assign("-");
						NewVariable->Name.append(GetData("DATABASE",STRING));
						NewVariable->Type = REVERSE_USE;
						MFAVariables[REVERSE_USE] = NewVariable;
						NewVariable->Binary = true;
						NewVariable->UpperBound = 1;
						NewVariable->LowerBound = 0;
					}
				}
			}
		}
	}
}

MFAVariable* Reaction::GetMFAVar(int InType) {
	return MFAVariables[InType];
}

void Reaction::GetAllMFAVariables(vector<MFAVariable*>& InVector) {
	for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MFAVariables.begin(); MapITT != MFAVariables.end(); MapITT++) {
		if (MapITT->second != NULL) {
			InVector.push_back(MapITT->second);
		}
	}
	for (int i=0; i < int(ComplexMFAVariables.size()); i++) {
		if (ComplexMFAVariables[i] != NULL) {
			InVector.push_back(ComplexMFAVariables[i]);
		}
	}
}

void Reaction::ClearMFAVariables(bool DeleteThem) {
	if (DeleteThem) {
		for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MFAVariables.begin(); MapITT != MFAVariables.end(); MapITT++) {
			delete MapITT->second;
		}
		for (int i=0; i < int(ComplexMFAVariables.size()); i++) {
			if (ComplexMFAVariables[i] != NULL) {
				delete ComplexMFAVariables[i];
			}
		}
	}
	MFAVariables.clear();
	ComplexMFAVariables.clear();
}

void Reaction::ResetFluxBounds(double Min,double Max,MFAProblem* InProblem) {
	MFAVariable* CurrentVariable = GetMFAVar(FLUX);
	if (CurrentVariable != NULL) {
		CurrentVariable->LowerBound = Min;
		CurrentVariable->UpperBound = Max;
		if (InProblem != NULL && InProblem->FProblemLoaded()) {
			InProblem->LoadVariable(CurrentVariable->Index);
		}
		return;
	}

	CurrentVariable = GetMFAVar(FORWARD_FLUX);
	if (CurrentVariable != NULL) {
		if (Max >= 0) {
			CurrentVariable->UpperBound = Max;
		} else {
			CurrentVariable->UpperBound = 0;
		}
		if (Min >= 0) {
			CurrentVariable->LowerBound = Min;	
		} else {
			CurrentVariable->LowerBound = 0;	
		}
		if (InProblem != NULL && InProblem->FProblemLoaded()) {
			InProblem->LoadVariable(CurrentVariable->Index);
		}
	}

	CurrentVariable = GetMFAVar(REVERSE_FLUX);
	if (CurrentVariable != NULL) {
		if (Max <= 0) {
			CurrentVariable->LowerBound = Max;
		} else {
			CurrentVariable->LowerBound = 0;
		}
		if (Min <= 0) {
			CurrentVariable->UpperBound = -Min;	
		} else {
			CurrentVariable->UpperBound = 0;	
		}
		if (InProblem != NULL && InProblem->FProblemLoaded()) {
			InProblem->LoadVariable(CurrentVariable->Index);
		}
	}
}

double Reaction::FluxLowerBound() {
	MFAVariable* CurrentVariable = GetMFAVar(FLUX);
	if (CurrentVariable != NULL) {
		return CurrentVariable->LowerBound;
	}

	CurrentVariable = GetMFAVar(REVERSE_FLUX);
	if (CurrentVariable != NULL) {
		return -CurrentVariable->UpperBound;
	}

	CurrentVariable = GetMFAVar(FORWARD_FLUX);
	if (CurrentVariable != NULL) {
		return CurrentVariable->LowerBound;
	}

	return FLAG;
}

double Reaction::FluxUpperBound() {
	MFAVariable* CurrentVariable = GetMFAVar(FLUX);
	if (CurrentVariable != NULL) {
		return CurrentVariable->UpperBound;
	}

	CurrentVariable = GetMFAVar(FORWARD_FLUX);
	if (CurrentVariable != NULL) {
		return CurrentVariable->UpperBound;
	}

	CurrentVariable = GetMFAVar(REVERSE_FLUX);
	if (CurrentVariable != NULL) {
		return -CurrentVariable->LowerBound;
	}

	return FLAG;
}

double Reaction::FFlux(OptSolutionData* InSolution) {
	MFAVariable* CurrentVariable = GetMFAVar(FLUX);
	if (CurrentVariable != NULL) {
		if (InSolution == NULL) {
			return CurrentVariable->Value;
		} else {
			return InSolution->SolutionData[CurrentVariable->Index];
		}
	}

	double Flux = FLAG;
	CurrentVariable = GetMFAVar(FORWARD_FLUX);
	if (CurrentVariable != NULL) {
		if (InSolution == NULL) {
			Flux = CurrentVariable->Value;
		} else {
			Flux = InSolution->SolutionData[CurrentVariable->Index];
		}
	}
	CurrentVariable = GetMFAVar(REVERSE_FLUX);
	if (CurrentVariable != NULL) {
		if (Flux == FLAG) {
			Flux = 0;
		}
		if (InSolution == NULL) {
			Flux += -CurrentVariable->Value;
		} else {
			Flux += -InSolution->SolutionData[CurrentVariable->Index];
		}
	}

	return Flux;
}

string Reaction::FluxClass() {
	double MaxFlux = 0;
	double MinFlux = 0;
	MFAVariable* CurrentVariable = GetMFAVar(FLUX);
	if (CurrentVariable != NULL) {
		MaxFlux = CurrentVariable->Max;
		MinFlux = CurrentVariable->Min;
	} else {
		CurrentVariable = GetMFAVar(FORWARD_FLUX);
		if (CurrentVariable != NULL) {
			MaxFlux = CurrentVariable->Max;
			MinFlux = CurrentVariable->Min;
		} else {
			MaxFlux = 0;
			MinFlux = 0;
		}
		CurrentVariable = GetMFAVar(REVERSE_FLUX);
		if (CurrentVariable != NULL) {
			if (CurrentVariable->Max > MFA_ZERO_TOLERANCE) {
				MinFlux = -CurrentVariable->Max;
				if (CurrentVariable->Min > MFA_ZERO_TOLERANCE) {
					MaxFlux = -CurrentVariable->Min;
				}
			}
		}
	}

	if (MaxFlux < -MFA_ZERO_TOLERANCE) {
		return "N";
	} else if (MinFlux > MFA_ZERO_TOLERANCE) {
		return "P";
	} else if (MaxFlux > MFA_ZERO_TOLERANCE) {
		if (MinFlux < -MFA_ZERO_TOLERANCE) {
			return "V";
		} else {
			return "PV";
		}
	} else if (MinFlux < -MFA_ZERO_TOLERANCE) {
		return "NV";
	} else {
		return "B";
	}
}

vector<LinEquation*> Reaction::CreateGeneReactionConstraints() {
	vector<LinEquation*> AllConstraints;
	if (GetParameter("new gene handling").compare("1") == 0) {
		//Only creating these constraints if the reaction has at least one gene mapped to it
		if (GeneRootNode == NULL) {
			return AllConstraints;
		}
		//Creating variables for logic nodes
		map<GeneLogicNode*,MFAVariable*> NodeVarMap;
		for (int i=0; i < int(LogicNodes.size()); i++) {
			if (LogicNodes[i] != NULL) {
				MFAVariable* NodeVar = InitializeMFAVariable();
				NodeVar->LowerBound=0;
				NodeVar->UpperBound=1;
				NodeVar->Type=COMPLEX_USE;
				NodeVar->Binary=true;
				NodeVar->Name.assign("LN_");
				NodeVar->Name.append(GetData("DATABASE",STRING)+"_");
				NodeVar->Name += itoa(i);
				NodeVarMap[LogicNodes[i]]=NodeVar;
			}
		}
		//Creating constraints
		for (int i=0; i < int(LogicNodes.size()); i++) { 
			if(LogicNodes[i] != NULL && LogicNodes[i]->Logic == OR) {
				//0 < summation Ci - x
				LinEquation* NewLowerConstraint = InitializeLinEquation("Gene-reaction mapping or lower constraint",0,GREATER);
				//summation Ci - Kx < 0
				LinEquation* NewUpperConstraint = InitializeLinEquation("Gene-reaction mapping or upper constraint",0,LESS);
				//Adding the reaction use variables to the gene reaction constraint
				MFAVariable* ReactionUseVariable = NULL;
				if (LogicNodes[i] == GeneRootNode) {
					ReactionUseVariable = GetMFAVar(REACTION_USE);
					if (ReactionUseVariable != NULL) {
						NewLowerConstraint->Variables.push_back(ReactionUseVariable);
						NewLowerConstraint->Coefficient.push_back(-1);
						NewUpperConstraint->Variables.push_back(ReactionUseVariable);
						NewUpperConstraint->Coefficient.push_back(-1*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
					} else {
						ReactionUseVariable = GetMFAVar(FORWARD_USE);
						if (ReactionUseVariable != NULL) {
							NewLowerConstraint->Variables.push_back(ReactionUseVariable);
							NewLowerConstraint->Coefficient.push_back(-1);
							NewUpperConstraint->Variables.push_back(ReactionUseVariable);
							NewUpperConstraint->Coefficient.push_back(-1*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
						}
						ReactionUseVariable = GetMFAVar(REVERSE_USE);
						if (ReactionUseVariable != NULL) {
							NewLowerConstraint->Variables.push_back(ReactionUseVariable);
							NewLowerConstraint->Coefficient.push_back(-1);
							NewUpperConstraint->Variables.push_back(ReactionUseVariable);
							NewUpperConstraint->Coefficient.push_back(-1*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
						}
					}
				} else {
					ReactionUseVariable = NodeVarMap[LogicNodes[i]];
					NewLowerConstraint->Variables.push_back(ReactionUseVariable);
					NewLowerConstraint->Coefficient.push_back(-1);
					NewUpperConstraint->Variables.push_back(ReactionUseVariable);
					NewUpperConstraint->Coefficient.push_back(-1*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
				}
				
				for(int j=0; j < int(LogicNodes[i]->LogicNodes.size());j++ ){
					NewLowerConstraint->Variables.push_back(NodeVarMap[LogicNodes[i]->LogicNodes[j]]);
					NewLowerConstraint->Coefficient.push_back(1);
					NewUpperConstraint->Variables.push_back(NodeVarMap[LogicNodes[i]->LogicNodes[j]]);
					NewUpperConstraint->Coefficient.push_back(1);
				}
				for(int j=0; j < int(LogicNodes[i]->Genes.size());j++ ){
					MFAVariable* GeneVar = LogicNodes[i]->Genes[j]->GetMFAVar();
					if (GeneVar != NULL) {
						NewLowerConstraint->Variables.push_back(GeneVar);
						NewLowerConstraint->Coefficient.push_back(1);
						NewUpperConstraint->Variables.push_back(GeneVar);
						NewUpperConstraint->Coefficient.push_back(1);
					}
				}
				AllConstraints.push_back(NewLowerConstraint);
				AllConstraints.push_back(NewUpperConstraint);
			//AND constrains
			} else if (LogicNodes[i] != NULL) {
				//-1 < 2Summation Ci - 2Kx
				LinEquation* NewLowerConstraint = InitializeLinEquation("Gene-reaction mapping and lower constraint",-1,GREATER);
				//2Summation Ci - 2Kx < (2K-1) 
				LinEquation* NewUpperConstraint = InitializeLinEquation("Gene-reaction mapping and lower constraint",(2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()))-1,LESS);				
				//Adding the reaction use variables to the gene reaction constraint
				MFAVariable* ReactionUseVariable = NULL;
				if (LogicNodes[i] == GeneRootNode) {
					ReactionUseVariable = GetMFAVar(REACTION_USE);
					if (ReactionUseVariable != NULL) {
						NewLowerConstraint->Variables.push_back(ReactionUseVariable);
						NewLowerConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
						NewUpperConstraint->Variables.push_back(ReactionUseVariable);
						NewUpperConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
					} else {
						ReactionUseVariable = GetMFAVar(FORWARD_USE);
						if (ReactionUseVariable != NULL) {
							NewLowerConstraint->Variables.push_back(ReactionUseVariable);
							NewLowerConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
							NewUpperConstraint->Variables.push_back(ReactionUseVariable);
							NewUpperConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
						}
						ReactionUseVariable = GetMFAVar(REVERSE_USE);
						if (ReactionUseVariable != NULL) {
							NewLowerConstraint->Variables.push_back(ReactionUseVariable);
							NewLowerConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
							NewUpperConstraint->Variables.push_back(ReactionUseVariable);
							NewUpperConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
						}
					}
				} else {
					ReactionUseVariable = NodeVarMap[LogicNodes[i]];
					NewLowerConstraint->Variables.push_back(ReactionUseVariable);
					NewLowerConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
					NewUpperConstraint->Variables.push_back(ReactionUseVariable);
					NewUpperConstraint->Coefficient.push_back(-2*int(LogicNodes[i]->Genes.size()+LogicNodes[i]->LogicNodes.size()));
				}
				
				for(int j=0; j < int(LogicNodes[i]->LogicNodes.size());j++ ){
					NewLowerConstraint->Variables.push_back(NodeVarMap[LogicNodes[i]->LogicNodes[j]]);
					NewLowerConstraint->Coefficient.push_back(2);
					NewUpperConstraint->Variables.push_back(NodeVarMap[LogicNodes[i]->LogicNodes[j]]);
					NewUpperConstraint->Coefficient.push_back(2);
				}
				for(int j=0; j < int(LogicNodes[i]->Genes.size());j++ ){
					MFAVariable* GeneVar = LogicNodes[i]->Genes[j]->GetMFAVar();
					if (GeneVar != NULL) {
						NewLowerConstraint->Variables.push_back(GeneVar);
						NewLowerConstraint->Coefficient.push_back(2);
						NewUpperConstraint->Variables.push_back(GeneVar);
						NewUpperConstraint->Coefficient.push_back(2);
					}
				}
				AllConstraints.push_back(NewLowerConstraint);
				AllConstraints.push_back(NewUpperConstraint);
			}
		}
	} else {
		//Only creating these constraints if the reaction has at least one gene mapped to it
		if (FNumGeneGroups() == 0) {
			return AllConstraints;
		}

		//Need a constraint to link the reaction use variable to the reaction genes
		LinEquation* GeneReactionConstraint = InitializeLinEquation("Gene-reaction mapping constraint",0,LESS,LINEAR);
		GeneReactionConstraint->AssociatedReaction = this;

		//Adding the genes and constraints to the gene reaction constriant
		for (int i=0; i < FNumGeneGroups(); i++) {
			if (GeneDependency[i].size() == 1) {
				//Adding the single gene to the gene reaction constraint
				GeneReactionConstraint->Variables.push_back(GeneDependency[i][0]->GetMFAVar());
				GeneReactionConstraint->Coefficient.push_back(-1);
			} else {
				//Adding the complex to the gene reaction constraint
				GeneReactionConstraint->Variables.push_back(ComplexMFAVariables[i]);
				GeneReactionConstraint->Coefficient.push_back(-1);

				//Creating the complex-gene constraint for thise constraint
				LinEquation* GeneComplexConstraint = InitializeLinEquation("Gene-complex constraint",0,GREATER,LINEAR);
				GeneComplexConstraint->AssociatedReaction = this;
				GeneComplexConstraint->Variables.push_back(ComplexMFAVariables[i]);
				GeneComplexConstraint->Coefficient.push_back(-int(GeneDependency[i].size()));
				for (int j=0; j <int(GeneDependency[i].size()); j++) {
					GeneComplexConstraint->Variables.push_back(GeneDependency[i][j]->GetMFAVar());
					GeneComplexConstraint->Coefficient.push_back(1);
				}
				AllConstraints.push_back(GeneComplexConstraint);
			}
		}

		//Adding the gene reaction mapping constraint to the constraint vector
		AllConstraints.push_back(GeneReactionConstraint);
	}
	return AllConstraints;
}

//Returns (Upper bound,LowerBound,Max,Min,Value)
vector<double> Reaction::RetrieveData(int VarType,OptSolutionData* InSolution) {
	//Initializing the result vector
	vector<double> Result(5,FLAG);
	
	//Retrieving the compartment
	MFAVariable* PosVar = NULL;
	MFAVariable* NegVar = NULL;

	//Testing for exact variable match
	PosVar = MFAVariables[VarType];
	
	//Handling cases when nonexact variable match will occur
	if (PosVar == NULL) {
		if (VarType == FLUX) {
			PosVar = MFAVariables[FORWARD_FLUX];
			NegVar = MFAVariables[REVERSE_FLUX];
		} else if (VarType == REACTION_USE) {
			PosVar = MFAVariables[FORWARD_USE];
			NegVar = MFAVariables[REVERSE_USE];
		}
	}

	//Filling in the data
	if (PosVar != NULL) {
		Result[0] = PosVar->UpperBound;
		Result[1] = PosVar->LowerBound;
		Result[2] = PosVar->Max;
		Result[3] = PosVar->Min;
		if (InSolution == NULL) {
			Result[4] = PosVar->Value;
		} else {
			Result[4] = InSolution->SolutionData[PosVar->Index];
		}
	}
	if (NegVar != NULL) {
		if (Result[0] == FLAG || NegVar->LowerBound > 0) {
			Result[0] = -NegVar->LowerBound;
		}
		if (Result[1] == FLAG || NegVar->UpperBound > 0) {
			Result[1] = -NegVar->UpperBound;
		}
		if (Result[2] == FLAG || NegVar->Min > 0) {
			Result[2] = -NegVar->Min;
		}
		if (Result[3] == FLAG || NegVar->Max > 0) {
			Result[3] = -NegVar->Max;
		}
		if (InSolution == NULL) {
			if (Result[4] == FLAG) {
				Result[4] = -NegVar->Value;
			} else {
				Result[4] = Result[4] - NegVar->Value;
			}
		} else {
			if (Result[4] == FLAG) {
				Result[4] = -InSolution->SolutionData[NegVar->Index];
			} else {
				Result[4] = Result[4] - InSolution->SolutionData[NegVar->Index];
			} 
		}
	}

	//Returning the result
	return Result;
}
