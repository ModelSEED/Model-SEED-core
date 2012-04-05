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

Species::Species(vector<string>* InHeaders, string Fileline, Data* InData, bool InCue) {
	Cue = InCue;
	SetDefaults();

	MainData = InData;

	ReadFromFileline(InHeaders,Fileline);
}

Species::Species(string InFilename, Data* InData, bool InCue) {
	Cue = InCue;
	SetDefaults();
	
	MainData = InData;
	if (InFilename.length() > 0) {
		LoadSpecies(InFilename);
	}
}

Species::Species(int InEntry, int InIndex, Species* InSpecies, bool InCue) {
	Cue = InCue;
	SetEntry(InEntry);
	SetIndex(InIndex);
	SetDefaults();

	CopyData(InSpecies);

	for (int i=0; i< InSpecies->FNumAtoms(); i++) {
		AtomCPP* NewAtomCopy = new AtomCPP(InSpecies->GetAtom(i)->FType(),i,this);
		NewAtomCopy->Clone(InSpecies->GetAtom(i), this);
		AddAtom(NewAtomCopy);
	}

	for (int i=0; i< InSpecies->FNumAtoms(); i++) {
		Atoms[i]->ReplicateBonds(InSpecies->GetAtom(i), this);
	}
}

void Species::SetDefaults() {
	PathwayMark = 0;
	MolecWeight = FLAG;
	MainData = NULL;
	SetCode("");
	Formula.assign("");
	EstDeltaGUncertainty = FLAG;
	EstDeltaG = FLAG;
	NumNoIDGroups = 0;
	Cofactor = false;
	Coa = false;
	
	Charge = 0;
	NumHeteroRings = 0;
	ThreeMemberRings = 0;
	NumLargeCycles = 0;
	SetEntry(-1);
	NuetralpHCharge = int(FLAG);
}

Species::~Species() {
	for (int i=0; i < FNumAtoms(); i++) {
		delete Atoms[i];
	}
	for (int i=0; i < int(Cycles.size()); i++) {
		delete Cycles[i];
	}
	for (map<int , SpeciesCompartment* , std::less<int> >::iterator MapIT = Compartments.begin(); MapIT != Compartments.end(); MapIT++) {
		delete MapIT->second;
	}
};

//Input
void Species::SetEstDeltaG(double InEnergy) {
	EstDeltaG = InEnergy;
};

void Species::SetEstDeltaGUncertainty(double InError) {
	EstDeltaGUncertainty = InError;
};	

void Species::SetCoa(bool InCoa) {
	Coa = InCoa;
}

void Species::SetCue(bool InCue) {
	Cue = InCue;
}

void Species::SetSmallMolec(bool InSmallMolec) {
	SmallMolec = InSmallMolec;
}

void Species::SetCharge(int InCharge) {
	if (InCharge == FLAG) {
		InCharge = 0;
	}
	Charge = InCharge;
}

void Species::SetNuetralpHCharge(int InCharge) {
	NuetralpHCharge = InCharge;
}

void Species::SetFormula(string InFormula) {
	Formula.assign(InFormula);
}

void Species::SetMW(double InMass) {
	MolecWeight = InMass;
}

void Species::SetCofactor(bool InCofactor) {
	Cofactor = InCofactor;
}

//This allows the user to set the number of unlabeled atoms manually. Use this with caution.
void Species::SetNumNoIDGroups(int InNum) {
	NumNoIDGroups = InNum;
}; //End void Species::SetNumNoIDGroups(int InNum)

void Species::AddAtom(AtomCPP* InAtom) {
	if (InAtom->FType()->FID().compare("R") == 0 || InAtom->FType()->FID().compare("X") == 0) {
		AddErrorMessage("Contains psuedo atoms");
		AddLineToFile("CompoundsWithPsuedoAtoms.txt",GetData("DATABASE",STRING));
	}
	Atoms.push_back(InAtom);
	InAtom->SetIndex(FNumAtoms()-1);
};

void Species::AddReaction(Reaction* InReaction) {
	for (list<Reaction*>::iterator IT = ReactionList.begin(); IT != ReactionList.end(); IT++) {
		if (InReaction == (*IT)) {
			return;
		}
	}
	ReactionList.push_back(InReaction);
}

void Species::AddCompartment(int InCompartment) {
	if (InCompartment >= 1000) {
		InCompartment += -1000;
	}

	SpeciesCompartment* Temp = Compartments[InCompartment];
	if (Temp == NULL) {
		Temp = new SpeciesCompartment;
		Temp->Compartment = GetCompartment(InCompartment);
		Temp->Charge = CalculatePredominantIon(GetCompartment(InCompartment)->pH);
		Compartments[InCompartment] = Temp;
		CompartmentVector.push_back(Temp);
	}
}

//This function accepts a string of pKa or pKb values as input and parses the string into the vectors pKa and pKb
//each pKa value in a string consists of the pKa value and the index of the atom with the pKa, separated by a :
//The delimiters of the pKa values in the string are "|"
void Species::AddpKab(string InpKaString, bool pKaInput) {
	//Separate the pKa values into a vector of strings
	vector<string>* Strings = StringToStrings(InpKaString, "|",true);
	for (int i=0; i < int(Strings->size()); i++) {
		//Separate the pKa from the atom index for each supplied pKa value
		vector<string>* SubStrings = StringToStrings((*Strings)[i], ":",true);
		if (pKaInput) {
			pKa.push_back(atof((*SubStrings)[0].data()));
			if (atoi((*SubStrings)[1].data()) < FNumAtoms()) {
				pKaAtoms.push_back(atoi((*SubStrings)[1].data()));
			} else {
				pKaAtoms.push_back(NULL);
			}
		} else {
			pKb.push_back(atof((*SubStrings)[0].data()));
			if (atoi((*SubStrings)[1].data()) < FNumAtoms()) {
				pKbAtoms.push_back(atoi((*SubStrings)[1].data()));
			} else {
				pKbAtoms.push_back(NULL);
			}
		}
		delete SubStrings;
	}
	delete Strings;
}

void Species::AddpKab(double InpKa, int AtomNumber, bool pKaInput) {
	if (pKaInput) {
		pKa.push_back(InpKa);
		pKaAtoms.push_back(AtomNumber);
	} else {
		pKb.push_back(InpKa);
		pKbAtoms.push_back(AtomNumber);
	}
}

//This sets all of the booleans in the atom structure called mark to false.
void Species::ResetAtomMarks(bool InMark) {
	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetMark(InMark);
	}
}; //void Species::ResetAtomMarks() 

void Species::CheckForCoa() {
	int i;
	int NumN = 0;
	int NumC = 0;
	int NumP = 0;
	int NumS = 0;
	int NumO = 0;
	for (i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare(COA_ID) == 0) {
			Coa = true;
			return; 
		}
		if (GetAtom(i)->FType()->FID().compare("S") == 0) {
			NumS++;		
		}
		if (GetAtom(i)->FType()->FID().compare("N") == 0) {
			NumN++;		
		}
		if (GetAtom(i)->FType()->FID().compare("P") == 0) {
			NumP++;		
		}
		if (GetAtom(i)->FType()->FID().compare("C") == 0) {
			NumC++;		
		}
		if (GetAtom(i)->FType()->FID().compare("O") == 0) {
			NumO++;		
		}
	}

	if (NumC < 21 || NumS < 1 || NumN < 7 || NumP < 3 || NumO < 16) {
		Coa = false;
		return;
	}
	//This is not an exhaustive function by any stretch of the imagination, but it works for my purposes.
	Coa = true;
}

void Species::CopyData(Species* InSpecies) {
	//These functions ensure that there are no repeats
	ParseCombinedData(InSpecies->GetCombinedData(STRING),STRING);
	ParseCombinedData(InSpecies->GetCombinedData(DATABASE_LINK),DATABASE_LINK);
	
	if (InSpecies->FFormula().length() > 0) {
		SetFormula(InSpecies->FFormula());
	}

	if (InSpecies->FCode().length() > 0) {
		SetCode(InSpecies->FCode());
	}

	if (InSpecies->FCoa()) {
		SetCoa(InSpecies->FCoa());
	}

	if (InSpecies->FCofactor()) {
		SetCofactor(InSpecies->FCofactor());
	}

	SetCharge(InSpecies->FCharge());

	if (InSpecies->FNuetralpHCharge() != FLAG) {
		SetNuetralpHCharge(InSpecies->FNuetralpHCharge());
	}

	MainData = InSpecies->FMainData();
	SetNumNoIDGroups(InSpecies->FNumNoIDGroups());

	if (FEstDeltaG() == FLAG && InSpecies->FEstDeltaG() != FLAG) {
		SetEstDeltaG(InSpecies->FEstDeltaG());
		SetEstDeltaGUncertainty(InSpecies->FEstDeltaGUncertainty());

		for (int i=0; i < InSpecies->FNumStructuralCues(); i++) {
			StructuralCues.push_back(InSpecies->GetStructuralCue(i));
			NumStructuralCues.push_back(InSpecies->GetStructuralCueNum(i));
		}
	}

	for (int i=0; i < InSpecies->FNumpKab(true); i++) {
		bool Match = false;
		for (int j=0; j < FNumpKab(true); j++) {
			if (GetpKab(j,true) == InSpecies->GetpKab(i,true)) {
				Match = true;
				j = FNumpKab(true);
			}
		}
		if (!Match) {
			AddpKab(InSpecies->GetpKab(i,true),InSpecies->GetpKabAtom(i,true)->FIndex(),true);
		}
	}
}

void Species::ClearCycles() {
	for (int i=0; i < int(Cycles.size()); i++) {
		delete Cycles[i];
	}
	Cycles.clear();
}

int Species::ParseStructuralCueList(string InList) {
        if(InList.compare("nogroups")==0){
	  return SUCCESS;
        }
	vector<string>* Strings = StringToStrings(InList,"\t|:");
	for (int i=0; i < int(Strings->size()); i++) {
		Species* NewCue = MainData->FindStructuralCue("NAME;DATABASE;ENTRY",(*Strings)[i].data());
		i++;
		double CueCoeff = atof((*Strings)[i].data());
		if (NewCue == NULL) {
			if (!FCue()) {
				FErrorFile() << "MISSING STRUCTURAL CUE: Structural cue " << (*Strings)[i-1].data() << " not found." << endl;
				FlushErrorFile();
			}
			AddData("TEMP_CUES",(*Strings)[i-1].data(),STRING);
			AddData("TEMP_CUE_COEFS",CueCoeff,false);
		} else {
			AddStructuralCue(NewCue,CueCoeff);
		}
	}
	delete Strings;
	return SUCCESS;
}

void Species::AddStructuralCue(Species* InCue, double InCueCoef) {
	StructuralCues.push_back(InCue);
	NumStructuralCues.push_back(int(InCueCoef));
}

void Species::FillInTempStructuralCue() {
	//This function exists in case a hybrid structural cue is loaded before the structural cues that make up the hybrid are loaded
	//If this happens, the constituent cues are stored in the hybrid as strings, and they can be added later once every cue has been loaded
	vector<string> TempCues = GetAllData("TEMP_CUES",STRING);
	vector<double> TempCueCoefs = GetAllData("TEMP_CUE_COEFS");

	for (int i=0; i < int(TempCues.size()); i++) {
		Species* NewCue = MainData->FindStructuralCue("NAME;DATABASE;ENTRY",TempCues[i].data());
		if (NewCue != NULL) {
			//The temporary cue has been found and can now be added
			AddStructuralCue(NewCue,TempCueCoefs[i]);
		} else {
			//If the temporary cue is not found now, then there is a problem
			FErrorFile() << "Failed to add constituent structural cue " << TempCues[i] << " to the hybrid structural cue " << GetData("NAME",STRING) << "." << endl;
			FlushErrorFile();
		}
	}

	//Now I clear the temporary data as it is no longer needed
	ClearData("TEMP_CUES",STRING);
	ClearData("TEMP_CUE_COEFS",DOUBLE);
}

int Species::ReadFromFileline(vector<string>* InHeaders, string Fileline) {
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
		string Filename("cpd");
		Filename.append(FMainData()->GetData("NAME",STRING));
		Filename.append(itoa(FMainData()->FNumSpecies()));
		AddData("FILENAME",Filename.data(),STRING);
	}
	//If the parameter file says to load the compound structure, then I load it here
	if (!FCue() && GetParameter("load compound structure").compare("1") == 0) {
		//First I check to see if the compound has a valid structure filename
		if (GetData("STRUCTURE_FILE",STRING).length() == 0) {
			//If no valid structure name is present, I assume it is available in the KEGG
			string StructureFilename("Kegg/pH7/");
			StructureFilename.append(GetData("KEGG",DATABASE_LINK));
			StructureFilename.append(".mol");
			AddData("STRUCTURE_FILE",StructureFilename.data(),STRING);
		}
		ReadStructure();	
	}

	delete Strings;
	return SUCCESS;
}

//Output
double Species::FEstDeltaG() {
	return EstDeltaG;
};

double Species::FEstDeltaGUncertainty() {
	if (EstDeltaGUncertainty != FLAG) {
		return EstDeltaGUncertainty;
	}
	
	if (FEstDeltaG() == FLAG) {
		return FLAG;
	}
	
	EstDeltaGUncertainty = 0;
	for (int i=0; i < FNumStructuralCues(); i++) {
		EstDeltaGUncertainty += GetStructuralCueNum(i)*GetStructuralCueNum(i)*GetStructuralCue(i)->FEstDeltaGUncertainty()*GetStructuralCue(i)->FEstDeltaGUncertainty();
	}
	EstDeltaGUncertainty = pow(EstDeltaGUncertainty,0.5);

	return EstDeltaGUncertainty;
};

double Species::FMW() {
	if(MolecWeight == FLAG) {
		if (FNumAtoms() == 0) {
			TranslateFormulaToAtoms();
		}
		
		MolecWeight = 0;
		for (int i=0; i < FNumAtoms(); i++) {
			MolecWeight += GetAtom(i)->FType()->FMass();
		}
	}
	
	return MolecWeight;
};

bool Species::FCofactor() {
	return Cofactor;
};

bool Species::FCue() {
	return Cue;
};

bool Species::FSmallMolec() {
	return SmallMolec;
}

string Species::FFormula() {
	return Formula;
};

int Species::FCharge() {
	return Charge;
}

int Species::FNuetralpHCharge() {
	return NuetralpHCharge;
}

int Species::FNumAtoms(){
	return int(Atoms.size());
};

int Species::FNumNoIDGroups() {
	for (int i=0; i < FNumStructuralCues(); i++) {
		if (GetStructuralCue(i)->GetData("DATABASE",STRING).compare("cue_NoGroup") == 0) {
			return GetStructuralCueNum(i);
		}
	}
	
	return NumNoIDGroups;
};

AtomCPP* Species::GetAtom(int InIndex){
	return Atoms[InIndex];
};

Data* Species::FMainData() {
	return MainData;	
};

int Species::FNumStructuralCues() {
	return int(StructuralCues.size());
};

Species* Species::GetStructuralCue(int GroupIndex) {
	return StructuralCues[GroupIndex];
};

int Species::GetStructuralCueNum(int GroupIndex) {
	return NumStructuralCues[GroupIndex];
};

int Species::FNumNonHAtoms() {
	int NumNonHAtoms = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare("H") != 0) {
			NumNonHAtoms++;
		}
	}
	
	return NumNonHAtoms;
};

AtomCPP* Species::GetRootAtom() {
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FParentID() == ROOT_ATOM) {
			return GetAtom(i);
		}
	}

	return NULL;
};

bool Species::FCoa() {
	return Coa;
};

int Species::FNumReactions() {
	return int(ReactionList.size());
}

multimap<Species*, Reaction*, std::less<Species*> >* Species::GetNeighborMap(bool CofactorsIncluded) {
	multimap<Species*, Reaction*, std::less<Species*> >* NewMap = new multimap<Species*, Reaction*, std::less<Species*> >;

	typedef pair <Species*, Reaction*> Datapair;
	for (int i=0; i < MainData->FNumReactions(); i++) {
		if (MainData->GetReaction(i)->GetReactantCoef(this) < 0 && (CofactorsIncluded || MainData->GetReaction(i)->GetReactantCompartment(MainData->GetReaction(i)->CheckForReactant(this)) > 0)) {	
			for (int j= MainData->GetReaction(i)->FNumReactants(REACTANT); j < MainData->GetReaction(i)->FNumReactants(); j++) {
				if (CofactorsIncluded || MainData->GetReaction(i)->GetReactantCompartment(j) > 0) {
					NewMap->insert(Datapair(MainData->GetReaction(i)->GetReactant(j),MainData->GetReaction(i)));
				}
			}
		}
	}

	return NewMap;
};

int Species::CountAtomType(const char* ID) {
	int Count = 0;
	if (this->FNumAtoms() == 0 && this->FFormula().length() > 0) {
		this->TranslateFormulaToAtoms();
	}
	for(int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare(ID) == 0) {
			Count++;
		}
	}
	return Count;
}

int Species::GetCycleNum(int InCycleType) {
	int CycleCount = 0;
	for (int i=0; i < int(Cycles.size()); i++) {
		if (InCycleType == BENZENE && Cycles[i]->Class == BENZENE) {
			CycleCount++;
		} else if (InCycleType == SIX_MEMBER && Cycles[i]->CycleAtoms.size() == 6) {
			CycleCount++;
		} else if (InCycleType == FIVE_MEMBER && Cycles[i]->CycleAtoms.size() == 5) {
			CycleCount++;
		} else if (InCycleType == FOUR_MEMBER && Cycles[i]->CycleAtoms.size() == 4) {
			CycleCount++;
		} else if (InCycleType == THREE && Cycles[i]->CycleAtoms.size() == 3) {
			CycleCount++;
		} else if (InCycleType == LARGE_CYCLE && Cycles[i]->CycleAtoms.size() > 6) {
			CycleCount++;
		}
		if (InCycleType == HETERO && Cycles[i]->Class == HETERO) {
			CycleCount++;
		}
		if (InCycleType == NONBENZENE && Cycles[i]->Class != BENZENE) {
			CycleCount++;
		}
		if (InCycleType == FUSED) {
			for (int j=0; j < int(Cycles[i]->FusedCycles.size()); j++) {
				if (Cycles[i]->FusedCycles[j] != NULL) {
					CycleCount++;
				}
			}
			CycleCount = CycleCount/2;
		}
	}
	return CycleCount;
};

int Species::FNumpKab(bool InpKa) {
	if (InpKa) {
		return int(pKa.size());
	}
	return int(pKb.size());
};

vector<double> Species::GetpKaValues() {

	return pKa;

}
double Species::GetpKab(int InIndex, bool InpKa) {
	if (InpKa) {
		if (InIndex >= int(pKa.size())) {
			return FLAG;
		}
		return pKa[InIndex];
	}
	if (InIndex >= int(pKb.size())) {
		return FLAG;
	}
	return pKb[InIndex];
};

AtomCPP* Species::GetpKabAtom(int InIndex, bool InpKa) {
	if (InpKa) {
		if (InIndex >= int(pKaAtoms.size())) {
			return NULL;
		}
		return GetAtom(pKaAtoms[InIndex]);
	}
	if (InIndex >= int(pKbAtoms.size())) {
		return NULL;
	}
	return GetAtom(pKbAtoms[InIndex]);
};

double Species::FBindingPolynomial(double InpH, vector<double> pKaValues) {
	double HConc = pow(10,-InpH);
	double Denominator = 1;
	double BindingPolynomial = 1;

	for (int i=0; i < int(pKaValues.size()); i++) {
		double Numerator = pow(HConc,(i+1));
		double K = pow(10,-pKaValues[i]);
		Denominator = Denominator*K;
		BindingPolynomial += Numerator/Denominator;
	}

	return BindingPolynomial;
}

//This function specifies the difference between the number of protons attached to the
//molecule at pH 7 versus the fully protonated form at the maximum stored pKa or pKb value.
double Species::FRefHChange() {
	//If the molecule is H, then I return a one so the hydrogens at pH 7 are accounted for
	if (FFormula().compare("H") == 0) {
		return 1;
	}
	
	//I add 1 to the change in protonation for every pKa or pKb value over 7.
	double RefChange = 0;
	for (int i=0; i < int(pKaAtoms.size()); i++) {
		if (pKa[i] > 7) {
			RefChange++;
		}
	}
	for (int i=0; i < int(pKbAtoms.size()); i++) {
		if (pKb[i] > 7) {
			RefChange++;
		}
	}
	return RefChange;
}

string Species::GetUnlabeledFormula() {
	int* NumTypes = new int[FNumAtomTypes()];
	int* LargeNumTypes = new int[FNumAtomTypes()];
	
	for (int i=0; i < FNumAtomTypes(); i++) {
		NumTypes[i] = 0;
		LargeNumTypes[i] = 0;
	}	

	for (int i=0; i < FNumAtoms(); i++) {
		if (!GetAtom(i)->FLabeled()) {
			if (ParseDigit(GetAtom(i)->FCycleID(),1)>0) {
				LargeNumTypes[Atoms[i]->FType()->FIndex()]++;
			} else {
				NumTypes[Atoms[i]->FType()->FIndex()]++;
			}
		}
	}

	string UnlabeledFormula;
	for (int i=0; i < FNumAtomTypes(); i++) {
		if (NumTypes[i] > 0) {
			UnlabeledFormula.append(GetAtomType(i)->FID());
			if (NumTypes[i] > 1) {
				UnlabeledFormula.append(itoa(NumTypes[i]));
			}
		}
	}
	
	bool First = true;
	for (int i=0; i < FNumAtomTypes(); i++) {
		if (LargeNumTypes[i] > 0) {
			if (First) {
				UnlabeledFormula.append("L:");
			}
			First = false;
			UnlabeledFormula.append(GetAtomType(i)->FID());
			if (LargeNumTypes[i] > 1) {
				UnlabeledFormula.append(itoa(LargeNumTypes[i]));
			}
		}
	}

	delete [] NumTypes;
	delete [] LargeNumTypes;

	if (!First) {
		vector<int> SizeDist;
		for (int i=0; i < int(Cycles.size()); i++) {
			while (Cycles[i]->CycleAtoms.size() >= SizeDist.size()) {
				SizeDist.push_back(0);
			}
			SizeDist[Cycles[i]->CycleAtoms.size()]++;
		}

		UnlabeledFormula.append("(");
		for (int i=0; i < int(SizeDist.size()); i++) {
			if (SizeDist[i] > 0) {
				UnlabeledFormula.append(itoa(i));
				UnlabeledFormula.append(itoa(SizeDist[i]));
			}
		}
		UnlabeledFormula.append(")");
	}

	return UnlabeledFormula;
}

bool Species::ContainsAtom(string ID) {
	if (Formula.find(ID.data()) == Formula.npos) {
		return false;
	}
	else {
		return true;
	}
};

string Species::CreateStructuralCueList() {
	string CombinedList;
	for (int i=0; i < FNumStructuralCues(); i++) {
		CombinedList.append(GetStructuralCue(i)->GetData("NAME",STRING));
		CombinedList.append(":");
		CombinedList.append(dtoa(GetStructuralCueNum(i)));
		CombinedList.append("\t");
	}

	if (CombinedList.length() > 0 && CombinedList.substr(CombinedList.length()-1,1).compare("\t") == 0) {
		CombinedList = CombinedList.substr(0,CombinedList.length()-1);
	}

	return CombinedList;
}

double Species::GetMaxConcentration(const char* Compartment) {
	CellCompartment* Temp = GetCompartment(Compartment);
	
	if (Temp == NULL) {
		Temp = GetDefaultCompartment();
	}

	vector<string> Names = GetAllData("NAME",STRING);
	for (int i=0; i < int(Names.size()); i++) {
		double* Range = Temp->SpecialConcRanges[Names[i]];
		if (Range != NULL) {
			return Range[1];
		}
	}

	return Temp->MaxConc;
}

double Species::GetMinConcentration(const char* Compartment) {
	CellCompartment* Temp = GetCompartment(Compartment);
	
	if (Temp == NULL) {
		Temp = GetDefaultCompartment();
	}

	vector<string> Names = GetAllData("NAME",STRING);
	for (int i=0; i < int(Names.size()); i++) {
		double* Range = Temp->SpecialConcRanges[Names[i]];
		if (Range != NULL) {
			return Range[0];
		}
	}

	return Temp->MinConc;
}

string Species::PrintRequestedDataToString(vector<string>* Headers) {
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

bool Species::FExtracellular() {
	if (Compartments[GetCompartment("e")->Index] != NULL) {
		return true;
	}
	return false;
}

list<Reaction*> Species::GetReactionList() {
	return ReactionList;	
}

int Species::FNumCompartments() {
	return int(CompartmentVector.size());
}

SpeciesCompartment* Species::GetSpeciesCompartment(int InIndex) {
	return CompartmentVector[InIndex];
}

//File Output
int Species::SaveSpecies(string InFilename) {
	if (InFilename.length() == 0) {
		InFilename = GetData("FILENAME",STRING);
		if (InFilename.length() == 0) {
			InFilename = GetData("DATABASE",STRING);
			if (InFilename.length() == 0) {
				return FAIL;
			}
		}
	}

	string Entity("compound");
	if (Cue) {
		Entity.assign("cue");
	}

	if (InFilename.substr(1,1).compare(":") != 0 && InFilename.substr(0,1).compare("/") != 0) {
		InFilename = GetDatabaseDirectory(GetParameter("database"),"new "+Entity+" directory")+InFilename;
	}

	ofstream Output;
	if (!OpenOutput(Output,InFilename)) {
		return FAIL;
	}

	vector<string>* FileHeader;
	if (Cue) {
		FileHeader = StringToStrings(GetParameter("structural cue data to print"),";");
	} else {
		FileHeader = StringToStrings(GetParameter("compound data to print"),";");
	}

	//First I check to see if the user specified that the input headers be printed in the output file
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
		if (Data.length() > 0) {
			Output << InputHeaders[i] << "\t" << Data << endl;
		}
	}

	for (int i=0; i < int(FileHeader->size()); i++) {
		//I check to see if the current file header has already been printed to file
		int j =0;
		if ((*FileHeader)[i].compare("INPUT_HEADER") != 0) {
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

void Species::PrintMol(string Filename) {
	if (Filename.length() == 0 || Filename.rfind("/") == (Filename.length()-1)) {
		Filename.append(GetGenericData(GetParameter("Molfile/datfile naming style").data()));
	}	
	if(Filename.length() == 0) {
		Filename = GetData("DATABASE",STRING);
		if (Filename.length() == 0) {
			FErrorFile() << "Could not find appropriate name for molfile for compound " << GetData("NAME",STRING) << endl;
			FlushErrorFile();
			return;
		}
		Filename.append(".mol");
	} else if (Filename.length() <= 4 || (Filename.substr(Filename.length()-4,4).compare(".mol") != 0)) {
		Filename.append(".mol");
	}
	//int PathLocation = int(Filename.rfind("/"));
	//if (PathLocation != -1) {
		//Filename = Filename.substr(PathLocation+1,Filename.length()-PathLocation-1);
	//}
	AddData("MOLFILE",Filename.data(),STRING);
	AddData("STRUCTURE_FILE",Filename.data(),STRING);
	
	int* NewIndecies = new int[FNumAtoms()];

	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	Output << FFormula() << endl << endl << endl;
	
	int i, j;
	int TotalBonds = 0;
	int NumberNonHAtoms = 0;
	
	for (i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare("H") != 0) {
			NumberNonHAtoms++;
			NewIndecies[i] = NumberNonHAtoms;
			for (j=0; j < GetAtom(i)->FNumBonds(); j++) {
				if (GetAtom(i)->GetBond(j)->FType()->FID().compare("H") != 0) {
					TotalBonds++;
				}
			}		
		}
	}
	
	TotalBonds = TotalBonds/2;

	if (NumberNonHAtoms < 10) {
		Output << "  ";
	}	
	else if (NumberNonHAtoms < 100) {
		Output << " ";
	}
	Output << NumberNonHAtoms;

	if (TotalBonds < 10) {
		Output << "  ";
	}	
	else if (TotalBonds < 100) {
		Output << " ";
	}
	Output << TotalBonds;

	Output << "  0  0  0  0" << endl;

	for (i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare("H") != 0) {
			Output << "    0.0000    0.0000    0.0000 " << Atoms[i]->FType()->FID() << "   0  0  0  0  0  0  0" << endl;
		}
	}
	for (i=0; i < FNumAtoms(); i++) {
		for (j=0; j < Atoms[i]->FNumBonds(); j++) {
			if (Atoms[i]->FIndex() < Atoms[i]->GetBond(j)->FIndex() && GetAtom(i)->GetBond(j)->FType()->FID().compare("H") != 0 && GetAtom(i)->FType()->FID().compare("H") != 0) {
				if (NewIndecies[Atoms[i]->FIndex()] < 10) {
					Output << "  ";
				}	
				else if (NewIndecies[Atoms[i]->FIndex()] < 100) {
					Output << " ";
				}
				Output << NewIndecies[Atoms[i]->FIndex()];
				
				if (NewIndecies[Atoms[i]->GetBond(j)->FIndex()] < 10) {
					Output << "  ";
				}	
				else if (NewIndecies[Atoms[i]->GetBond(j)->FIndex()] < 100) {
					Output << " ";
				}
				Output << NewIndecies[Atoms[i]->GetBond(j)->FIndex()];

				Output << "  " << Atoms[i]->GetBondOrder(j) << "  0  0  0" << endl;
			}
		}
	}
	
	delete [] NewIndecies;
	
	int ChargeCout = 0;
	string ChargeData;
	int RemainingSpaces = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FCharge() != 0) {
			ChargeCout++;
			for (int j=0; j < RemainingSpaces; j++) {
				ChargeData.append(" ");
			}
			ChargeData.append(itoa(i+1));
			if (i < 10) {
				ChargeData.append("  ");
			} else if (i < 100) {
				ChargeData.append(" ");
			}
			if (GetAtom(i)->FCharge() > 0) {
				ChargeData.append(" ");
			}
			RemainingSpaces = 3;
			ChargeData.append(itoa(GetAtom(i)->FCharge()));
		}
	}
	if (ChargeCout > 0) {
		if (ChargeCout < 10) {
			Output << "M  CHG  " << ChargeCout << "   " << ChargeData << endl;
		} else {
			Output << "M  CHG  " << ChargeCout << "  " << ChargeData << endl;
		}
	}
	Output << "M  END" << endl << endl << endl;
	Output.close();
};

string Species::Query(string InDataName) {
	//I will always reuse a previously calculated query value if it is available
	string Result = GetAllDataString(InDataName.data(),STRING);
	if (Result.length() > 0) {
		return Result;
	}
	
	if (InDataName.compare("ACTIVE CARBON") == 0) {
		return "0";
	}

	//The CGI_ID is a consistent ID assigned to a compound coming from other databases in the following order of priority: KEGG, Palsson, misc
	if (InDataName.compare("CGI_ID") == 0) {
		//Determine if the current database ID is a KEGG database ID
		string DatabaseID = GetData("DATABASE",STRING);
		if (DatabaseID.length() == 6 && DatabaseID.substr(0,1).compare("C") == 0) {
			AddData("CGI_ID",DatabaseID.data(),STRING);
				return DatabaseID;
		}
		//Check for KEGG database ID
		DatabaseID = GetData("KEGG",DATABASE_LINK);
		if (DatabaseID.length() == 6 && DatabaseID.substr(0,1).compare("C") == 0) {
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

	//TRANSPORT will equal yes if the compound is transported and no if the compound is not transported
	if (InDataName.compare("TRANSPORT") == 0) {
		if (FExtracellular()) {
			AddData("TRANSPORT","yes",STRING);
			string Temp("yes");
			return Temp;	
		} else {
			AddData("TRANSPORT","no",STRING);
			string Temp("no");
			return Temp;
		}
	}

	if (InDataName.compare("STDDEVEXPENERGY") == 0) {
		vector<double> ExpEnergy = GetAllData("EXPENERGY");
		double Ave = 0;
		for (int i=0; i < int(ExpEnergy.size()); i++) {
			Ave += ExpEnergy[i];
		}
		Ave = Ave/double(ExpEnergy.size());
		double Total = 0;
		for (int i=0; i < int(ExpEnergy.size()); i++) {
			Total += pow((ExpEnergy[i]-Ave),2);
		}
		Total = Total/double(ExpEnergy.size());
		Total = sqrt(Total);
		Result.assign(dtoa(Total));
	} else if (InDataName.compare("AVEEXPENERGY") == 0) {
		vector<double> ExpEnergy = GetAllData("EXPENERGY");
		double Total = 0;
		for (int i=0; i < int(ExpEnergy.size()); i++) {
			Total += ExpEnergy[i];
		}
		Result.assign(dtoa(Total/double(ExpEnergy.size())));
	} else if (InDataName.compare("NITROGEN") == 0) {
		Result.assign(itoa(CountAtomType("N")));
	} else if (InDataName.compare("PHOSPHOROUS") == 0) {
		Result.assign(itoa(CountAtomType("P")));
	} else if (InDataName.compare("SULFUR") == 0) {
		Result.assign(itoa(CountAtomType("S")));
	} else if (InDataName.compare("OXYGEN") == 0) {
		Result.assign(itoa(CountAtomType("O")));
	} else if (InDataName.compare("CARBON") == 0) {
		Result.assign(itoa(CountAtomType("C")));
	} else if (InDataName.compare("CYCLE_DATA") == 0) {
		
	} else if (InDataName.compare("NEIGHBORS") == 0) {
		multimap<Species*, Reaction*, std::less<Species*> >* NeighborMap = GetNeighborMap(false);
		multimap<Species*, Reaction*, std::less<Species*> >::iterator MapIT = NeighborMap->begin();
		for (int i =0; i < int(NeighborMap->size()); i++) {
			Result.append(MapIT->first->GetData("DATABASE",STRING));
			Result.append("|");
			MapIT++;
		}
	} else if (InDataName.compare("REACTIONS") == 0) {
		list<Reaction*>::iterator ListIT = ReactionList.begin();
		for (int i=0; i < int(ReactionList.size()); i++) {
			Result.append((*ListIT)->GetData("DATABASE",STRING));
			Result.append("\t");
			ListIT++;
		}
	} else if (InDataName.compare("COA") == 0) {
		CheckForCoa();
		if (FCoa()) {
			Result.assign("yes");
		} else {
			Result.assign("no");
		}
	}

	return Result;
}	

//File input
int Species::LoadSpecies(string InFilename) {
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
	string Entity("compound");
	if (Cue) {
		Entity.assign("cue");
		if (InFilename.substr(0,4).compare("cue_") == 0) {
			InFilename = InFilename.substr(4);
		}
	}
	StringDBObject* compoundObj = GetStringDB()->get_object(Entity,GetStringDB()->get_table(Entity)->get_id_column(),InFilename);
	if (compoundObj == NULL) {
		SetKill(true);
		return FAIL;
	}
	SetData("FILENAME",InFilename.data(),STRING);
	for (int i=0; i < compoundObj->get_table()->number_of_attributes();i++) {
		string attribute = compoundObj->get_table()->get_attribute(i);
		vector<string>* data = compoundObj->getAll(i);
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
	if (!FCue() && GetParameter("load compound structure").compare("1") == 0) {
		if (GetData("STRUCTURE_FILE",STRING).length() == 0) {
			if (FileExists(GetDatabaseDirectory(GetParameter("database"),"molfile directory")+"pH7/"+GetData("DATABASE",STRING)+".mol")) {
				SetData("STRUCTURE_FILE",(GetDatabaseDirectory(GetParameter("database"),"molfile directory")+"pH7/"+GetData("DATABASE",STRING)+".mol").data(),STRING);
			} else if (FileExists(GetDatabaseDirectory(GetParameter("database"),"molfile directory")+GetData("DATABASE",STRING)+".mol")) {
				SetData("STRUCTURE_FILE",(GetDatabaseDirectory(GetParameter("database"),"molfile directory")+GetData("DATABASE",STRING)+".mol").data(),STRING);
				AddErrorMessage("No pH7 molfile exists for this compound.");
				FErrorFile() << "No pH7 molfile exists for compound: " << GetData("DATABASE",STRING) << endl;	
				FlushErrorFile();
			}
		}
		if (!FileExists(GetData("STRUCTURE_FILE",STRING))) {
			FErrorFile() << "No molfile exists for compound: " << GetData("DATABASE",STRING) << endl;
			FlushErrorFile();
			AddErrorMessage("No molfile exists for this compound.");
		}
		ReadStructure();
	}
	return SUCCESS;
}

int Species::Interpreter(string DataName, string& DataItem, bool Input) {
	int DataID = TranslateFileHeader(DataName,COMPOUND);
	
	if (DataID == -1) {
		//FErrorFile() << "MISSING DATA REFERENCE: " << GetData("FILENAME",STRING) << " data reference: " << DataName << " not recognized." << endl;
		//FlushErrorFile();
		return FAIL;
	}
	switch (DataID) {
		case CPD_DBLINK: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DATABASE_LINK);
			} else {
				DataItem = GetAllDataString(DataName.data(),DATABASE_LINK);
			}
			break;
		} case CPD_FORMULA: {
			if (Input) {
				SetFormula(DataItem);
			} else {
				DataItem = FFormula();
			}
			break;
		} case CPD_NEUTRAL_CHARGE: {
			if (Input) {
				SetNuetralpHCharge(atoi(DataItem.data()));
				SetCharge(FNuetralpHCharge());
			} else {
				DataItem.assign(itoa(FNuetralpHCharge()));
			}
			break;
		} case CPD_COFACTOR: {
			if (Input) {
				if (DataItem.compare("yes") == 0) {
					SetCofactor(true);
				} else {
					SetCofactor(false);
				}
			} else {
				if (FCofactor()) {
					DataItem.assign("yes");
				} else {
					DataItem.assign("no");
				}
			}
			break;
		} case CPD_DELTAG: {
			if (Input) {
				SetEstDeltaG(atof(DataItem.data()));
			} else {
				DataItem.assign(dtoa(FEstDeltaG()));
			}
			break;
		} case CPD_DELTAGERR: {
			if (Input) {
				SetEstDeltaGUncertainty(atof(DataItem.data()));
			} else {
				DataItem.assign(dtoa(FEstDeltaGUncertainty()));
			}
			break;
		} case CPD_MW: {
			if (Input) {
				SetMW(atof(DataItem.data()));
			} else {
				DataItem.assign(dtoa(FMW()));
			}
			break;
		} case CPD_PKA: {
			if (Input) {
				vector<string>* Strings = StringToStrings(DataItem,"\t:");
				for (int i=0; i < int(Strings->size()); i++) {
					if (int(Strings->size()) > (i+1)) {
						pKa.push_back(atof((*Strings)[i].data()));
						pKaAtoms.push_back(atoi((*Strings)[i+1].data()));
						i++;
					}
				}
				delete Strings;
			} else {
				DataItem.assign("");
				for (int i=0; i < int(pKa.size()); i++) {
					if (i > 0) {
						DataItem.append("\t");
					}
					DataItem = DataItem + dtoa(pKa[i])+":"+itoa(pKaAtoms[i]);
				}
			}
			break;
		} case CPD_PKB: {
			if (Input) {
				vector<string>* Strings = StringToStrings(DataItem,"\t:");
				for (int i=0; i < int(Strings->size()); i++) {
					if (int(Strings->size()) > (i+1)) {
						pKb.push_back(atof((*Strings)[i].data()));
						pKbAtoms.push_back(atoi((*Strings)[i+1].data()));
						i++;
					}
				}
				delete Strings;
			} else {
				DataItem.assign("");
				for (int i=0; i < int(pKb.size()); i++) {
					if (i > 0) {
						DataItem.append("\t");
					}
					DataItem = DataItem + dtoa(pKb[i])+":"+itoa(pKbAtoms[i]);
				}
			}
			break;
		} case CPD_STRUCTURALCUES: {
			if (Input) {
				return ParseStructuralCueList(DataItem);
			} else {
				DataItem = CreateStructuralCueList();
			}
			break;
		} case CPD_DOUBLE: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),DOUBLE);
			} else {
				DataItem = GetAllDataString(DataName.data(),DOUBLE);
			}
			break;
		} case CPD_CUE: {
			if (Input) {
				if (DataItem.compare("yes") == 0) {
					SetCue(true);
				} else {
					SetCue(false);
				}
			} else {
				if (FCue()) {
					DataItem.assign("yes");
				} else {
					DataItem.assign("no");
				}
			}
			break;
		} case CPD_STRINGCODE: {
			if (Input) {
				SetCode(DataItem);
			} else {
				DataItem = FCode();
			}
			break;
		} case CPD_CHARGE: {
			if (Input) {
				SetCharge(atoi(DataItem.data()));
			} else {
				DataItem.assign(itoa(FCharge()));
			}
			break;
		} case CPD_SMALLMOLEC: {
			if (Input) {
				if (DataItem.compare("1") == 0 || DataItem.compare("yes") == 0) {
					SetSmallMolec(true);
				} else {
					SetSmallMolec(false);
				}
			} else {
				if (FSmallMolec()) {
					DataItem.assign("yes");
				} else {
					DataItem.assign("no");
				}
			}
			break;
		} case CPD_STRING: {
			if (Input) {
				AddData(DataName.data(),DataItem.data(),STRING);
			} else {
				DataItem = GetAllDataString(DataName.data(),STRING);
			}
			break;
		} case CPD_ERRORMSG: {
			if (Input) {
				AddErrorMessage(DataItem.data());
			} else {
				DataItem = FErrorMessage();
			}
			break;
		} case CPD_ALLDBLINKS: {
			if (Input) {
				ParseCombinedData(DataItem,DATABASE_LINK);
			} else {
				DataItem = GetCombinedData(DATABASE_LINK);
			}
			break;
		} case CPD_QUERY: {
			if (Input) {
				if (GetParameter("save query data on input").compare("1") == 0) {
					AddData(DataName.data(),DataItem.data(),STRING);
				}
			} else {
				DataItem = Query(DataName);
			}
			break;
		} case CPD_LOAD: {
			if (Input) {
				LoadSpecies(DataItem);			
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

void Species::ReadStructure() {
	string Filename = GetData("STRUCTURE_FILE",STRING);
	if (Filename.compare("Unknown") == 0) {
		return;
	}
	if (Filename.length() > 0) {
		if (Filename.length() > 4) {
			if (Filename.substr(Filename.length()-4,4).compare(".mol") == 0) {
				ReadFromMol(Filename);
			} else if (Filename.substr(Filename.length()-4,4).compare(".dat") == 0) {
				ReadFromDat(Filename);
			} else if (Filename.substr(Filename.length()-4,4).compare(".gds") == 0) {
				ReadFromDat(Filename);
			} else {
				//ReadFromSmiles(Filename);
				return;
			}
		} else {
			//ReadFromSmiles(Filename);
			return;
		}
	}
}

void Species::ReadFromMol(string InFilename) {
	ifstream Input;

	if (FFormula().length() > 0 && FFormula().length() < 3) {
		ClearAtomList(true);
		TranslateFormulaToAtoms();
		vector<string> Names = GetAllData("NAME",STRING);
		if (FNumAtoms() > 1) {
			ClearAtomList(true);
		} else if (FNumAtoms() > 0) {
			for (int i=0; i < int(Names.size()); i++) {
				string TempName = Names[i];
				int SignLoc = int(TempName.find_first_of("+-"));
				int Sign = 1;
				int NewCharge = 0;
				if (SignLoc != TempName.npos) {
					if (TempName.substr(SignLoc,1).compare("+") != 0) {
						Sign = -1;
					}
					int NumberLoc = int(TempName.find_first_of("123456789"));
					if (NumberLoc == TempName.npos && SignLoc == int(TempName.length()-1)) {
						NewCharge = 1*Sign;
					} else if (abs(NumberLoc-SignLoc) == 1) {
						NewCharge = atoi(TempName.substr(NumberLoc,1).data())*Sign;
					}
					if (NewCharge != 0) {
						GetAtom(0)->SetCharge(NewCharge);
						i = int(Names.size());
					}
				}		
			}
			return;
		}
	}

	if (!FileExists(InFilename)) {
		InFilename = GetDatabaseDirectory(GetParameter("database"),"molfile directory")+"pH7/"+InFilename;
		if (!FileExists(InFilename)) {
			InFilename = GetDatabaseDirectory(GetParameter("database"),"molfile directory")+InFilename;
		}
		if (FileExists(InFilename)) {
			SetData("STRUCTURE_FILE",InFilename.data(),STRING);
		}
	}

	if (!OpenInput(Input, InFilename)) {
		ClearData("STRUCTURE_FILE",STRING);
		AddErrorMessage("Structure unknown");
		AddLineToFile("CompoundsWithUnknownStructures.txt",GetData("DATABASE",STRING));
		return;
	}

	ReadFromMol(Input);

	Input.close();
}

void Species::ReadFromMol(ifstream &Input) {
	bool VersionThree = false;
	
	ClearAtomList(true);
	ClearCycles();
	
	string Buff;
	AtomCPP* NewAtom;
	AtomType* NewAtomType;
	string AtomLabel;
	int NumberAtoms, NumberEdges, i;

	Buff = GetFileLine(Input); //Typically the formula is on this line
	
	vector<string>* FileLine;
	//This line must be delineated with ";" and can include comments slashes "\"
	FileLine = StringToStrings(Buff,"\\;");

	//Looking through datfile tags
	for (int i=0; i < int(FileLine->size()); i++) {
		//If I see the cofactor flag, I mark as a cofactor
		if ((*FileLine)[i].compare("cofactor") == 0) {
			Cofactor = true;
		}
		//If I see the NAME flag, then I know the next string is the name
		else if ((*FileLine)[i].compare("NAME") == 0) {
			AddData("NAME",(*FileLine)[i+1].data(),STRING);
		}
	}
	delete FileLine;

	Buff = GetFileLine(Input); //Typically some random file info
	Buff = GetFileLine(Input); //Typically a blank line

	if (Input.eof()) {
		FErrorFile() << "Possibly an incorrectly formatted mol file." << endl;
		FlushErrorFile();
		return;
	}

	FileLine = GetStringsFileline(Input, " "); //The usable data starts here
	
	if (FileLine->size() >= 2) {
		NumberAtoms = atoi((*FileLine)[0].data());
		NumberEdges = atoi((*FileLine)[1].data());
	} else {
		FErrorFile() << "Possibly an incorrectly formatted mol file." << endl;
		FlushErrorFile();
		return;
	}

	//Checking if this is a version 3 molfile
	if ((*FileLine)[FileLine->size()-1].length() >= 2 && (*FileLine)[FileLine->size()-1].substr(0,2).compare("V3") == 0) {
		VersionThree = true;
		//Atom number and bond number are located in different places in this molfile
		Buff = GetFileLine(Input); //Typically "M  V30 BEGIN CTAB"
		delete FileLine;
		FileLine = GetStringsFileline(Input, " "); //Typically "M  V30 COUNTS 66 68 0 0 0"
		if (FileLine->size() >= 5) {
			NumberAtoms = atoi((*FileLine)[3].data());
			NumberEdges = atoi((*FileLine)[4].data());
		} else {
			FErrorFile() << "Possibly an incorrectly formatted mol file." << endl;
			FlushErrorFile();
			return;
		}
		Buff = GetFileLine(Input); //Typically "M  V30 BEGIN ATOM"
	}
	
	//Dealing with empty proton mofiles
	if (NumberAtoms == 0) {
		NewAtom = new AtomCPP(GetAtomType("H"), 0, this);
		NewAtom->SetCharge(1);
		Atoms.push_back(NewAtom);
		Input.close();
		return;
	}

	//Parsing the atom number and edge number information
	if (NumberAtoms > 10000) {
		if (NumberAtoms < 20000) {
			int Temp = NumberAtoms/100;
			NumberEdges = NumberAtoms-Temp*100;
			NumberAtoms = Temp;
		}
		else if (NumberAtoms < 100000) {
			int Temp = NumberAtoms/1000;
			NumberEdges = NumberAtoms-Temp*1000;
			NumberAtoms = Temp;
		}
		else {
			int Temp = NumberAtoms/1000;
			NumberEdges = NumberAtoms-Temp*1000;
			NumberAtoms = Temp;
		}
	}

	delete FileLine;

	//This section of code reads in the atom data and inputs the data into the atom datastructures
	for (i=0; i < NumberAtoms; i++) {
		FileLine = GetStringsFileline(Input, " "); //The usable data starts here
		AtomLabel = (*FileLine)[3];
		if (AtomLabel.length() == 2 && AtomLabel.substr(1,1).compare("#") == 0) {
			AtomLabel = AtomLabel.substr(0,1);
		}
		NewAtom = new AtomCPP(GetAtomType(AtomLabel.data()), i, this);
		Atoms.push_back(NewAtom);
		if (VersionThree) {
			//The charge data is stored in this section too and must be parsed
			if ((*FileLine)[FileLine->size()-1].length() >= 5 && (*FileLine)[FileLine->size()-1].substr(0,4).compare("CHG=") == 0) {
				int Charge = atoi((*FileLine)[FileLine->size()-1].substr(4,(*FileLine)[FileLine->size()-1].length()-4).data());
				NewAtom->SetCharge(Charge);
			}
		}
		delete FileLine;
	}
	
	if (VersionThree) {
		Buff = GetFileLine(Input); //Typically "M  V30 END ATOM"
		Buff = GetFileLine(Input); //Typically "M  V30 BEGIN BOND"
	}

	//This section of code reads in the bond data and inputs the data into the atom datastructures
	for (i=0; i < NumberEdges; i++) {
		int AtomOne, AtomTwo, BondOrder;
		
		FileLine = GetStringsFileline(Input, " "); //The usable data starts here
		if (VersionThree) {
			AtomOne = atoi((*FileLine)[4].data());
			AtomTwo = atoi((*FileLine)[5].data());
			BondOrder = atoi((*FileLine)[3].data());
		} else {
			AtomOne = atoi((*FileLine)[0].data());
			if (AtomOne > 999) {
				AtomTwo = AtomOne-int(1000*floor(double(AtomOne/1000)));
				AtomOne = int(floor(double(AtomOne/1000)));
				BondOrder = atoi((*FileLine)[1].data());
			}		
			else {		
				AtomTwo = atoi((*FileLine)[1].data());
				BondOrder = atoi((*FileLine)[2].data());
			}
		}
		
		if (BondOrder == 4) {
			if (Atoms[AtomOne-1]->FMark() == false && Atoms[AtomTwo-1]->FMark() == false) {
				BondOrder = 2;
				Atoms[AtomOne-1]->SetMark(true);
				Atoms[AtomTwo-1]->SetMark(true);
			}
			else {
				BondOrder = 1;
			}
		}

		delete FileLine;
		Atoms[AtomTwo-1]->ChangeBondOrder(Atoms[AtomOne-1], BondOrder);
		Atoms[AtomOne-1]->ChangeBondOrder(Atoms[AtomTwo-1], BondOrder);
	}

	//This section of code reads in the ionic charge information from the molfile and applies the charges to the atoms
	if (!VersionThree) {
		do {
			FileLine = GetStringsFileline(Input, " ");
			if ((*FileLine)[1].compare("CHG") == 0) {
				int NumberCharge = atoi((*FileLine)[2].data());
				for (i=0; i < NumberCharge; i++) {
					GetAtom(atoi((*FileLine)[3+2*i].data())-1)->SetCharge(atoi((*FileLine)[3+2*i+1].data()));
				}
				delete FileLine;
			} else if ((*FileLine)[1].compare("RAD") == 0) {
				int NumberCharge = atoi((*FileLine)[2].data());
				for (i=0; i < NumberCharge; i++) {
					GetAtom(atoi((*FileLine)[3+2*i].data())-1)->SetRadical(1);
				}
				delete FileLine;
			} else {
				break;
			}
		}while(1);
		delete FileLine;
	}

	//Finding the atom type data structure for hydrogen so hydrogens can be added to the molfile in the next section of code
	NewAtomType = GetAtomType("H");

	if (NumberAtoms > 1 || GetAtom(0)->FType()->FID().compare("C") == 0 || GetAtom(0)->FType()->FID().compare("O") == 0 || GetAtom(0)->FType()->FID().compare("S") == 0 || GetAtom(0)->FType()->FID().compare("Se") == 0 || GetAtom(0)->FType()->FID().compare("N") == 0) {
		for (i=0; i < NumberAtoms; i++) {
			//This code exists to eliminate stray disconnected atoms that sometimes appear in molfiles; these are usually mistakes
			if (GetAtom(i)->FNumBonds() == 0 && NumberAtoms > 1) {
				FErrorFile() << "LONE ATOM: " << GetData("NAME",STRING) << " " << GetData("DATABASE",STRING) << ": " << GetAtom(i)->FType()->FID() << " atom found with no bonds. Eliminating atom." << endl;
				FlushErrorFile();
				RemoveAtom(i);
				i--;
				NumberAtoms--;
			}
			//This code exists to fill out the hydrogens on the atoms since molfiles typically do not contain hydrogens
			else {
				GetAtom(i)->FillOutH(NewAtomType);
			}
		}
	}

	if (NumberAtoms == 0) {
		ClearData("STRUCTURE_FILE",STRING);
		return;
	}
};

double Species::AdjustedDeltaG(double ionicStr,double pH,double Temperature) {

	double Temp = atof(GetParameter("Temperature").data());
	double pKMin = atof(GetParameter("minimum pKa").data());
	double pKMax = atof(GetParameter("maximum pKa").data());
	double DGAdjust;

	int spCharge = 0;
	int cpdNH = 0;
	int spNH = 0;

	vector<double> AcceptedPk;
	vector<double> Kvalue;

	for (int i=0; i < int(pKa.size()); i++) {

		if (pKa[i] < pKMax) {
			spCharge = spCharge - 1;

			if (pKa[i] > pKMin) {
				AcceptedPk.push_back(pKa[i]);
			}
		}
	}
	// First find the number of H atoms in the compound
	if (FNumAtoms() == 0){
		TranslateFormulaToAtoms();
	}

	for (int i=0; i < FNumAtoms(); i++){
		if (GetAtom(i)->FType()->FID().compare("H") == 0){
			cpdNH++;
		}
	}
	
	spNH = cpdNH + spCharge - Charge;

	//Sorting in ascending order BUT WE WANT PKas in DESCENDING ORDER
	sort(AcceptedPk.rbegin(),AcceptedPk.rend());

	// Calculate charge of "most negatively" charged specie of the compound
	// Another case would be when the molecule is positively charged
	// This specie is used as the starting point for Alberty's calculations

	if (AcceptedPk.size() == 0) {
	// if the compound does not have any pKa values we can adjust it for the pH and ionic str and return directly
	// note that we use the compound's charge and not the specie charge

		double bindingP = 1;
		double DeltaGf = EstDeltaG;
		double t1 = cpdNH*GAS_CONSTANT*Temp*log(pow(10,-pH));
		double t2 = (2.91482*((Charge*Charge)-cpdNH)*sqrt(ionicStr))/(1+DEBYE_HUCKEL_B*sqrt(ionicStr))/4.184;
		DeltaGf = DeltaGf - t1 - t2;
		DGAdjust = DeltaGf - GAS_CONSTANT*Temp*log(bindingP);

		return DGAdjust;		
	}

	// we also check if the specie in the compound database is already in the desired state
	// by comparing the charges. If it is, we can just adjust the pKa values based on the ionicStr
	// to derive the adjusted deltaG of formation. Note that in this case, the spCharge = Charge and also numHs

	else if ((Charge == spCharge) && (AcceptedPk.size() > 0)) {

		vector<double> adjustedpKa = AdjustpKa(AcceptedPk,ionicStr,spCharge);
		double bindingP = FBindingPolynomial(pH, adjustedpKa);
		
		int sqCharge = spCharge^2;
		double deltaGF = EstDeltaG - (spNH*GAS_CONSTANT*Temp*log(pow(10,-pH))) - ((2.91482/4.184)*(sqCharge - spNH)*sqrt(ionicStr))/(1+DEBYE_HUCKEL_B*sqrt(ionicStr));
		double DGAdjust = deltaGF - GAS_CONSTANT*Temp*log(bindingP);
		return DGAdjust;
	} 

	else {

	// if the current specie is not the basic specie then we have to calculate the properties of the basic specie
	// from the current one
		int num_iter = 0;

		if (abs(Charge - spCharge) > int(AcceptedPk.size())){
			num_iter = int(AcceptedPk.size());
		} else {
			num_iter = abs(Charge - spCharge);
		}

		double DeltaGf = EstDeltaG;
		vector<double> pKList;

		for (int i=0; i < num_iter; i++) {
			double pKaValue = AcceptedPk[i];
			double Kvalue = pow(10,-pKaValue);
			double Adjust = (-GAS_CONSTANT*Temp*log(Kvalue));
			DeltaGf = DeltaGf + Adjust;
			pKList.push_back(pKaValue);
		}

		// Adjust the pKa values for ionic strength before calculating the binding polynomial
		pKList = AdjustpKa(pKList,ionicStr,spCharge);
		double bindingP = FBindingPolynomial(pH,pKList);

		double t1 = spNH*GAS_CONSTANT*Temp*log(pow(10,-pH));
		double t2 = ((2.91482/4.184)*((spCharge*spCharge)-spNH)*sqrt(ionicStr))/(1+DEBYE_HUCKEL_B*sqrt(ionicStr));
		DeltaGf = DeltaGf - t1 - t2;
		DGAdjust = DeltaGf - GAS_CONSTANT*Temp*log(bindingP);

		return DGAdjust;
	}
}

vector<double> Species::AdjustpKa(vector<double> pKa, double ionicStr, int spCharge) {

   int sigmanusq = 2*spCharge;
   int pH = 7;
   vector<double> adjustedpKa;
   
   for (int i=0;i < int(pKa.size());i++) {
		double lnkzero = log(pow(10,-pKa[i]));
		double base = 10;
		double pKaAdjusted = -(lnkzero - (1.17582*sqrt(ionicStr)*sigmanusq/(1+1.6*sqrt(ionicStr))))/log(base);
		adjustedpKa.push_back(pKaAdjusted);
   }
   return adjustedpKa;
}
double Species::AdjustpKa(double pKa, double ionicStr, int spCharge) {
	
	int sigmanusq = 2*spCharge;
	int pH = 7;
   
	double lnkzero = log(pow(10,-pKa));
	double base = 10;
	double pKaAdjusted = -(lnkzero - (1.17582*sqrt(ionicStr)*sigmanusq/(1+1.6*sqrt(ionicStr))))/log(base);

	return pKaAdjusted;

}

void Species::CalculateFormula() {
	int i;
	int* NumTypes = new int[FNumAtomTypes()];
	
	for (i=0; i < FNumAtomTypes(); i++) {
		NumTypes[i] = 0;
	}	

	MolecWeight = 0;
	for (i=0; i < FNumAtoms(); i++) {
		NumTypes[Atoms[i]->FType()->FIndex()]++;
		MolecWeight += GetAtom(i)->FType()->FMass();
	}

	Formula.clear();
	for (i=0; i < FNumAtomTypes(); i++) {
		if (NumTypes[i] > 0) {
			Formula.append(GetAtomType(i)->FID());
			if (NumTypes[i] > 1) {
				Formula.append(itoa(NumTypes[i]));
			}
		}
	}

	delete [] NumTypes;
};

void Species::ClearAtomList(bool Delete) {
	if (Delete == true) {
		for (int i=0; i < FNumAtoms(); i++) {
			delete Atoms[i];
		}
	}
	Atoms.clear();
};

void Species::PerformAllCalculations(bool Decompose, bool FindStringCode, bool LookForCycles, bool CalcProperties, bool FindFormula) {
	bool CheckCharge = true;

	if (FNumAtoms() == 1) {
		if (GetAtom(0)->FType()->FID().compare("H") == 0) {
			GetAtom(0)->SetCharge(1);
		}
		CheckCharge = false;
	}

	if (FNumAtoms() == 0) {
		return;
	}

	if (GetData("SHORTNAME",STRING).length() == 0) {
		Query("SHORTNAME");
	}

	Charge = 0;
	//Checking the charge on all atoms and adding up the charge for the compound.
	for (int i=0; i < FNumAtoms(); i++) {
		//Setting some compound information for the atoms
		GetAtom(i)->SetOwner(this);
		GetAtom(i)->SetIndex(i);
		GetAtom(i)->SetMark(false);
		GetAtom(i)->SetLabeled(false);

		//Saving the original charge before it is changed
		if (CheckCharge) {
			//Calculating atom charge according to valence rules
			GetAtom(i)->CalculateCharge();
		}

		//Adding up the charges for the compound
		Charge += GetAtom(i)->FCharge();
	}

	if (LookForCycles) {
		if (IsTree() == false) {
			FindCycles();
		} else {
			for (int i=0; i < FNumAtoms(); i++) {
				GetAtom(i)->SetCycleID(0);
			}
		}
	}

	//Calculating the formula based on the atoms in the molecular structure
	if (FindFormula) {
		CalculateFormula();
	}

	if (FindStringCode) {
		SetCode(CreateStringcode(false, false));
	}
	
	if (Decompose) {
		//I added this code to compare the heteroaromatic ring determination schemes of Matt and me
		int Temp = NumHeteroRings;
		//Running the atom labeling algorithm
		LabelAtoms();
		CountStructuralCues();
		//Printing a warning message if the number of heteromaromatic rings changes
		if (Temp != NumHeteroRings) {
			ostringstream strout;
			strout << GetData("NAME",STRING) << " " << GetData("DATABASE",STRING) << ": " << "Hetero ring missmatch: " << Temp << " reassigned to " << NumHeteroRings;  
		}
	}

	if (CalcProperties) {
		//Counting the groups if necessary and calculating energy and charge from the groups
		CalculateEnergyFromGroups();	
		CalculateChargeFromGroups();
	}

	SetNuetralpHCharge(FCharge());

	CheckForCoa();
};

void Species::ReadFromDat(string InFilename) {
	if (InFilename.length() == 0 || InFilename.substr(InFilename.length()-1,1).compare("/") == 0) {
		InFilename.append(GetData("DATABASE",STRING)+".dat");
	}
	if ((InFilename.length() >= 4 && InFilename.substr(InFilename.length()-4,1).compare(".") != 0) || InFilename.length() < 4)  {
		if (FCue()) {
			InFilename.append(".gds");
		} else {
			InFilename.append(".dat");
		}
	}
	
	if (!FileExists(InFilename)) {
		if (InFilename.substr(InFilename.length()-4).compare(".gds") == 0) {
			if (FileExists(GetDatabaseDirectory(GetParameter("database"),"cue directory")+"StructureFiles/"+InFilename)) {
				InFilename = GetDatabaseDirectory(GetParameter("database"),"cue directory")+"StructureFiles/"+InFilename;
			}
		}
	}

	Atoms.clear();
	
	ifstream Input;
	if (!OpenInput(Input, InFilename)) {
		FErrorFile() << "Structure file not found for: " << InFilename << endl;
		FlushErrorFile();
		ClearData("STRUCTURE_FILE",STRING);
		AddErrorMessage("Structure unknown");
		AddLineToFile("CompoundsWithUnknownStructures.txt",GetData("DATABASE",STRING));
		return;
	}
	
	//Checking to see if I'm reading in a group dat file which is a little different
	bool Group = false;
	if (InFilename.substr(InFilename.length()-3,3).compare("gds") == 0) {
		Group = true;
	}

	//Reading the first line with names and flages
	vector<string>* Strings;
	string Buff = GetFileLine(Input);
	//This line must be delineated with ";" and can include comments slashes "\"
	Strings = StringToStrings(Buff,"\\;");

	//Looking through datfile tags
	for (int i=0; i < int(Strings->size()); i++) {
		//If I see the cofactor flag, I mark as a cofactor
		if ((*Strings)[i].compare("cofactor") == 0) {
			Cofactor = true;
		}else if ((*Strings)[i].compare("NAME") == 0) {
		//If I see the NAME flag, then I know the next string is the name
			AddData("NAME",(*Strings)[i+1].data(),STRING);
		} else if ((*Strings)[i].compare("GROUP") == 0) {
		//If I see the GROUP flag, I know this is a group (not necessary if file is .gds)
			Group = true;
		}
	}

	//Reading in number of atoms and allocating atoms
	delete Strings;
	Buff = GetFileLine(Input);
	Strings = StringToStrings(Buff, "\n ,{}()");
	Atoms.resize(atoi((*Strings)[0].data()));
	AtomType* NewType = NULL;
	for (int i =0; i < FNumAtoms(); i++) {
		Atoms[i] = new AtomCPP(NewType,i,this);
	}

	for (int i =0; i < FNumAtoms(); i++) {
		delete Strings;
		Buff = GetFileLine(Input);
		Strings = StringToStrings(Buff, "\n ,{}()");
		//Setting the atom type of the atom
		Atoms[i]->SetType(GetAtomType((*Strings)[2].data()));
		
		//Reading in the second data item which I use to set the atom as active or inactive
		int Temp = atoi((*Strings)[1].data());
		if(Temp == -1 && !Group) {
			Temp = 0;
		}
		else if (Group) {
			Atoms[i]->SetParentID(atoi((*Strings)[1].data()));
		}

		//Looking for additional information in the dat file
		int CurrentString = 4;
		if ((*Strings)[3].compare(":") != 0) {
			if (Group) {
				//Input special group atom labeling data
				Atoms[i]->InterpretCycleString((*Strings)[5]);
				Atoms[i]->SetGroupData(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",(*Strings)[3].data())->FEntry(), atoi((*Strings)[4].data()));
				CurrentString = 7;
			}
			else {
				//Inputing group labeling data
				if ((*Strings)[3].substr(0,1).compare("[") == 0) {
					GetAtom(i)->SetCycleID(atoi((*Strings)[3].substr(1,(*Strings)[3].length()-2).data()));
					GetAtom(i)->SetGroupData((*Strings)[4], atoi((*Strings)[5].data()));
					CurrentString = 7;
				}	
				else {
					GetAtom(i)->SetGroupData((*Strings)[3], atoi((*Strings)[4].data()));
					CurrentString = 6;
				}
			}
		}
		
		//Inputing bond data
		for (int j=CurrentString; j < int(Strings->size()); j++) {
			if ((*Strings)[j].compare(";") == 0) {
				j++;
			}
			else {
				Atoms[i]->ChangeBondOrder(Atoms[atoi((*Strings)[j].data())], atoi((*Strings)[j+1].data()));
				j++;
			}
		}

		Atoms[i]->CalculateCharge();
	}// End for loop  
	delete Strings;
};

void Species::ReadFromSmiles(string InSmiles) {
	int i;

	int CursorPosition = 0;
	int CurrentParent = 0;
	int CurrentBond = 1;
	bool Aromatic = false;
	bool Ion = false;
	//This is a flag indicating additional work must be done to deal with aromatic bonds
	bool AromaticCompound = false;

	AtomCPP* CycleReturnAtoms[1024] = {NULL};
	AtomCPP* ParentAtoms[1024] = {NULL};
	
	//Finding the atom type data structure for hydrogen, carbon, nitrogen, sulfur, and oxygen to handle aromatic rings
	AtomType* CarbonType = GetAtomType("C");
	AtomType* NitrogenType = GetAtomType("N");
	AtomType* OxygenType = GetAtomType("O");
	AtomType* SulfurType = GetAtomType("S");
	AtomType* HType = GetAtomType("H");

	AtomCPP* CurrentAtom = NULL;
	do {
		if (InSmiles.substr(CursorPosition,1).compare("(") == 0) {
			//Store the parent atom so I can return to it late when I find a )
			ParentAtoms[CurrentParent] = CurrentAtom;
			CurrentParent++;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare(")") == 0) {
			//Return to the last parent atom
			CurrentParent--;
			CurrentAtom = ParentAtoms[CurrentParent];
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("-") == 0) {
			if (Ion == true) {
				//This dash has to do with charge, not bonds
				if (InSmiles.substr(CursorPosition+1,1).find_first_of("0123456789") != -1) {
					//This dash specifies a negative charge larger than one: determine the charge, set the charge, move the cursor by 2 and move on
					int NegCharge = -atoi(InSmiles.substr(CursorPosition+1,1).data());
					CurrentAtom->SetCharge(NegCharge);
					CursorPosition += 2;
				}
				else { 
					//This dash just represents a single negative charge
					CurrentAtom->SetCharge(CurrentAtom->FCharge()-1);
					CursorPosition++;
				}
			}
			else {
				//This dash specifies a single bond: move the cursor and move on
				CurrentBond = 1;
				CursorPosition++;
			}
		}
		else if (InSmiles.substr(CursorPosition,1).compare("+") == 0) {
			if (Ion == true) {
				//This plus has to do with charge
				if (InSmiles.substr(CursorPosition+1,1).find_first_of("0123456789") != -1) {
					//This plus specifies a positive charge larger than one: determine the charge, set the charge, move the cursor by 2 and move on
					int NegCharge = atoi(InSmiles.substr(CursorPosition+1,1).data());
					CurrentAtom->SetCharge(NegCharge);
					CursorPosition += 2;
				}
				else { 
					//This plus just represents a single positive charge
					CurrentAtom->SetCharge(CurrentAtom->FCharge()+1);
					CursorPosition++;
				}
			}
			else {
				//I don't know the meaning of this plus if it's not for charge... print error message
				FErrorFile() << "Unhandled + found in smiles string for compound " << GetData("DATABASE",STRING) << ": " << GetData("NAME",STRING) << endl;
				FlushErrorFile();
				CursorPosition++;
			}
		}
		else if (InSmiles.substr(CursorPosition,1).compare("=") == 0) {
			//This = specifies a double bond: move the cursor and move on
			CurrentBond = 2;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("#") == 0) {
			//This = specifies a double bond: move the cursor and move on
			CurrentBond = 3;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare(":") == 0) {
			//I mark all atoms participating in aromatic bonds so I can deal with them later
			AromaticCompound = true;
			Aromatic = true;
			CurrentAtom->SetMark(true);
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("%") == 0) {
			//This symbol signifies a cycle with an index > 10.
			int CycleID = atoi(InSmiles.substr(CursorPosition+1,2).data());
			//If the cycle array is empty at the specified cycle ID, then this is the start of a new cycle and I store the atom in the tree
			if (CycleReturnAtoms[CycleID] == NULL) {
				CycleReturnAtoms[CycleID] = CurrentAtom;
			}
			//If the cycle array contains an atom at the specified cycle ID, then this is the end of a new cycle, and I connect the current atom to the parent atom and empty the cycle array
			else {
				CycleReturnAtoms[CycleID]->ChangeBondOrder(CurrentAtom,CurrentBond);
				CurrentAtom->ChangeBondOrder(CycleReturnAtoms[CycleID],CurrentBond);
				if (Aromatic) {
					Aromatic = false;
					CurrentAtom->SetMark(true);
				}
			}
			CursorPosition += 3;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("[") == 0) {
			//This bracket signifies that the upcoming atom is charged
			Ion = true;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("]") == 0) {
			//This bracket signifies that the charge information is complete
			Ion = false;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("c") == 0) {
			//Aromatic carbon
			AtomCPP* NewAtom = new AtomCPP(CarbonType,FNumAtoms(),this);
			//I mark all atoms participating in aromatic bonds so I can deal with them later
			NewAtom->SetMark(true);
			CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
			NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
			CurrentAtom = NewAtom;
			CurrentBond = 1;
			Aromatic = false;
			AromaticCompound = true;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("o") == 0) {
			//Aromatic carbon
			AtomCPP* NewAtom = new AtomCPP(OxygenType,FNumAtoms(),this);
			//I mark all atoms participating in aromatic bonds so I can deal with them later
			NewAtom->SetMark(true);
			CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
			NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
			CurrentAtom = NewAtom;
			CurrentBond = 1;
			Aromatic = false;
			AromaticCompound = true;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("s") == 0) {
			//Aromatic sulfur
			AtomCPP* NewAtom = new AtomCPP(SulfurType,FNumAtoms(),this);
			//I mark all atoms participating in aromatic bonds so I can deal with them later
			NewAtom->SetMark(true);
			CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
			NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
			CurrentAtom = NewAtom;
			CurrentBond = 1;
			Aromatic = false;
			AromaticCompound = true;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("n") == 0) {
			//Aromatic nitrogen
			AtomCPP* NewAtom = new AtomCPP(NitrogenType,FNumAtoms(),this);
			//I mark all atoms participating in aromatic bonds so I can deal with them later
			NewAtom->SetMark(true);
			CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
			NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
			CurrentAtom = NewAtom;
			CurrentBond = 1;
			Aromatic = false;
			AromaticCompound = true;
			CursorPosition++;
		}
		else if (InSmiles.substr(CursorPosition,1).compare("H") == 0) {
			//I'm only going to pay attention to hydrogens if they are in ions
			if (Ion == true) {
				//I just want to skip over this data. I'll add hydrogens to the atoms later
				CursorPosition++;
				if (InSmiles.substr(CursorPosition+1,1).find_first_of("0123456789") != -1) {
					CursorPosition++;
				}				
			}
		}
		else if (InSmiles.substr(CursorPosition,1).find_first_of("0123456789") != -1) {
			//These numbers must signify a cycle.
			int CycleID = atoi(InSmiles.substr(CursorPosition,1).data());
			//If the cycle array is empty at the specified cycle ID, then this is the start of a new cycle and I store the atom in the tree
			if (CycleReturnAtoms[CycleID] == NULL) {
				CycleReturnAtoms[CycleID] = CurrentAtom;
			}
			//If the cycle array contains an atom at the specified cycle ID, then this is the end of a new cycle, and I connect the current atom to the parent atom and empty the cycle array
			else {
				CycleReturnAtoms[CycleID]->ChangeBondOrder(CurrentAtom,CurrentBond);
				CurrentAtom->ChangeBondOrder(CycleReturnAtoms[CycleID],CurrentBond);
				if (Aromatic) {
					Aromatic = false;
					CurrentAtom->SetMark(true);
				}
			}
			CursorPosition++;
		}
		else {
			bool Match = false;
			//If none of the other tags match, then this part of the string must encode an atom
			//I look for matches to atom IDs involving 2 letters first
			for (int i=0; i < FNumAtomTypes(); i++) {
				if (GetAtomType(i)->FID().length() == 2 && int(InSmiles.length()-CursorPosition) >= 2 && InSmiles.substr(CursorPosition,2).compare(GetAtomType(i)->FID()) == 0) {
					AtomCPP* NewAtom = new AtomCPP(GetAtomType(i),FNumAtoms(),this);
					CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
					NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
					if (Aromatic) {
						Aromatic = false;
						NewAtom->SetMark(true);
					}
					CurrentAtom = NewAtom;
					CurrentBond = 1;
					CursorPosition += 2;
					i = FNumAtomTypes();
				}
			}
			if (!Match) {
				//Now I look for matches to atom IDs involving 1 letter
				for (int i=0; i < FNumAtomTypes(); i++) {
					if (GetAtomType(i)->FID().length() == 1 && int(InSmiles.length()-CursorPosition) >= 1 && InSmiles.substr(CursorPosition,1).compare(GetAtomType(i)->FID()) == 0) {
						AtomCPP* NewAtom = new AtomCPP(GetAtomType(i),FNumAtoms(),this);
						CurrentAtom->ChangeBondOrder(NewAtom,CurrentBond);
						NewAtom->ChangeBondOrder(CurrentAtom,CurrentBond);
						if (Aromatic) {
							Aromatic = false;
							NewAtom->SetMark(true);
						}
						CurrentAtom = NewAtom;
						CurrentBond = 1;
						CursorPosition++;
						i = FNumAtomTypes();
					}
				}
			}
			if (!Match) {
				//If no match is found, print an error message and proceed
				FErrorFile() << "Unable to find match for character " << InSmiles.substr(CursorPosition,1) << " in smiles code of compound " << GetData("DATABASE",STRING) << ": " << GetData("NAME",STRING) << endl; 
				FlushErrorFile();
				CursorPosition++;
			}
		}
	}while(CursorPosition < int(InSmiles.length()));

	if (AromaticCompound) {
		//I choose to represent aromatic bonds as consecutive single and double bonds
		//I want to start aromatizing bonds from any aromatic oxygens or sulfurs
		for (i=0; i < FNumAtoms(); i++) {
			if (GetAtom(i)->FMark() && (GetAtom(i)->FType()->FID().compare("O") == 0 || GetAtom(i)->FType()->FID().compare("S") == 0)) {
				GetAtom(i)->AromatizeBonds();
			}
		}
		//Now I aromatize any remaining atoms that need to be aromatized
		//Atoms will unmark themselves as they aromatize themselves
		for (i=0; i < FNumAtoms(); i++) {
			if (GetAtom(i)->FMark()) {
				GetAtom(i)->AromatizeBonds();
			}
		}
	}

	if (FNumAtoms() > 1) {
		for (i=0; i < FNumAtoms(); i++) {
			//This code exists to eliminate stray disconnected atoms that sometimes appear in molfiles; these are usually mistakes or ions the code is not built to handle
			if (GetAtom(i)->FNumBonds() == 0) {
				FErrorFile() << "LONE ATOM: " << GetData("NAME",STRING) << " " << GetData("DATABASE",STRING) << ": " << GetAtom(i)->FType()->FID() << " atom found with no bonds. Eliminating atom." << endl;
				FlushErrorFile();
				RemoveAtom(i);
				i--;
			}
			//This code exists to fill out the hydrogens on the atoms since molfiles typically do not contain hydrogens
			else {
				GetAtom(i)->FillOutH(HType);
			}
		}
	}
}

void Species::CountStructuralCues() {
	vector<int> IdentifyingIndex;
	vector<Species*> OldStructuralCues;
	vector<int> OldNumStructuralCues;

	if (StructuralCues.size() > 0) {
		OldStructuralCues = StructuralCues;
		OldNumStructuralCues = NumStructuralCues;
		StructuralCues.clear();
		NumStructuralCues.clear();
	}
	
	int i, j, k;
	for (i=0; i < int(Atoms.size()); i++) {
		for (j=0; j < int(StructuralCues.size()); j++) {
			if (StructuralCues[j]->FEntry() == Atoms[i]->FGroup()) {
				if (IdentifyingIndex[j] == Atoms[i]->FGroupIndex()) {
					NumStructuralCues[j]++;
				}
				break;
			}
		}
		if (j >= int(StructuralCues.size())) {
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",itoa(Atoms[i]->FGroup())));
			IdentifyingIndex.push_back(Atoms[i]->FGroupIndex());
			NumStructuralCues.push_back(1);
		}
	}

	for (i=0; i < FNumStructuralCues(); i++) {
		for (j=0; j < GetStructuralCue(i)->FNumStructuralCues(); j++) {
			for (k=0; k < FNumStructuralCues(); k++) {
				if (k != i && GetStructuralCue(i)->GetStructuralCue(j)->FIndex() == GetStructuralCue(k)->FIndex()) {
					NumStructuralCues[k] = NumStructuralCues[k]+GetStructuralCue(i)->GetStructuralCueNum(j)*GetStructuralCueNum(i);
					break;
				}
			}
			if (k >= FNumStructuralCues()) {
				StructuralCues.push_back(GetStructuralCue(i)->GetStructuralCue(j));
				NumStructuralCues.push_back(GetStructuralCue(i)->GetStructuralCueNum(j)*GetStructuralCueNum(i));
			}
		}
		if (j > 0) {
			StructuralCues.erase(StructuralCues.begin()+i,StructuralCues.begin()+i+1);
			NumStructuralCues.erase(NumStructuralCues.begin()+i,NumStructuralCues.begin()+i+1);
			i--;
		}
	}
	
	if (FNumStructuralCues() > 1 || !GetStructuralCue(0)->FSmallMolec()) {
		string Label("Origin");
		StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
		NumStructuralCues.push_back(1);
		for (i=0; i < FNumAtoms(); i++) {
			if (GetAtom(i)->FType()->FID().compare("H") != 0 && GetAtom(i)->FType()->FID().compare("C") != 0) {
				i = FNumAtoms()+1;
			}
		}
		CountConjugates();
		CountVicinalChlorines();
		if (i < FNumAtoms()+1) {
			Label.assign("Hydrocarbon");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(1);
		}
		if (NumHeteroRings > 0) {
			Label.assign("HeteroAromatic");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(NumHeteroRings);
		}
		if (ThreeMemberRings > 0) {
			Label.assign("threemember");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(ThreeMemberRings);
		}
		if (FCode().compare("C(H)(C(HO(H))(C(HO(P(O(H)O(H)O)))(C(HC(H2O(P(O(P(O(H)O(C(H2C(C(HO(H)C(ON(HC(H2C(H2C(ON(HC(H2C(H2S(H))))))))))C(H3)C(H3))))O))O(H)O))))(O(){1})))N(C(H)(N(C(C(N(C(H)(N(C(N(H2))(){5})))){2})<5>)))<2>)<1>") ==  0) {
			Label.assign("COA");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(1);
		}
		if (FCode().compare("N(C(C(C(C(H3)C(H3)C(H2O(P(OOO(R)))))HO(H))O)C(C(C(N(C(C(H2S(H))H2)H)O)H2)H2)H)") ==  0) {
			Label.assign("ACP");
			//StructuralCues.push_back(MainData->GetStructuralCue(Label));
			//NumStructuralCues.push_back(1);
		}
		if (FCode().compare("C(H2)(C(H)(C(HO(H))(C(HO(H))(C(H)(N(C(H)(N(C(C(N(C(H)(N(C(N(H2))(){9})))){6})<9>)))<6>O(){2}))))<2>O(P(O(H)O)(O(P(O(H)O)(O(C(H2)(C(H)(C(HO(H))(C(HO(H))(C(H)(N(C(H)(C(H)(C(H2)(C(C(ON(H2)))(C(H)(){12})))))<12>O(){8}))))<8>)))))))") ==  0) {
			Label.assign("NADH");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(1);
		}
		if (FCode().compare("C(H2)(C(H)(C(HO(H))(C(HO(P(O(H)O(H)O)))(C(H)(N(C(H)(N(C(C(N(C(H)(N(C(N(H2))(){9})))){6})<9>)))<6>O(){2}))))<2>O(P(O(H)O)(O(P(O(H)O)(O(C(H2)(C(H)(C(HO(H))(C(HO(H))(C(H)(N(C(H)(C(H)(C(H2)(C(C(ON(H2)))(C(H)(){12})))))<12>O(){8}))))<8>)))))))") ==  0) {
			Label.assign("NADH");
			StructuralCues.push_back(MainData->FindStructuralCue("NAME;DATABASE;ENTRY",Label.data()));
			NumStructuralCues.push_back(1);
		}
	}

	if (OldStructuralCues.size() > 0) {
		for (j=0; j < int(StructuralCues.size()); j++) {
			for (i=0; i < int(OldStructuralCues.size()); i++) {
				if (StructuralCues[j] == OldStructuralCues[i]) {
					int Diff = (NumStructuralCues[j] - OldNumStructuralCues[i]);
					if (Diff != 0) {
						FErrorFile() << "GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << Diff << " more " << StructuralCues[j]->GetData("NAME",STRING) << endl;
						FlushErrorFile();
					}
					OldNumStructuralCues[i] = 0;
					i = int(OldStructuralCues.size()+10);
				}	
			}
			if (i != int(OldStructuralCues.size()+11)) {
				FErrorFile() << "GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << NumStructuralCues[j] << " of new group " << StructuralCues[j]->GetData("NAME",STRING) << endl;
				FlushErrorFile();
			}
		}
		for (i=0; i < int(OldStructuralCues.size()); i++) {
			if (OldNumStructuralCues[i] != 0) {
				FErrorFile() << "GROUP CHANGE: " << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") now has " << -OldNumStructuralCues[i] << " more " << OldStructuralCues[i]->GetData("NAME",STRING) << endl;
				FlushErrorFile();
			}	
		}
	}
};

void Species::CalculateEnergyFromGroups() {
	double OldEnergy = EstDeltaG;
	
	EstDeltaG = 0;

	if (FNumStructuralCues() == 0) {
		CountStructuralCues();
	}

	if (FNumNoIDGroups() > 0) {
		EstDeltaG = FLAG;
		return;
	}

	for (int i=0; i < FNumStructuralCues(); i++) {
		if (StructuralCues[i]->FEstDeltaG() == -10000) {
			AddErrorMessage("Involves groups with unknown energy");
			AddLineToFile("CompoundsWithUnknownEnergyGroups.txt",GetData("DATABASE",STRING));
			EstDeltaG = FLAG;
			return;
		}
		EstDeltaG += NumStructuralCues[i]*StructuralCues[i]->FEstDeltaG();
	}

	if (fabs(OldEnergy - EstDeltaG) > 2) {
		ostringstream strout;
		strout << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") energy changed from " << OldEnergy << " to " << EstDeltaG;
	}
};

void Species::CalculateChargeFromGroups() {
	if (int(StructuralCues.size()) == 0) {
		CountStructuralCues();
	}

	if (FNumNoIDGroups() > 0) {
		return;
	}
	
	double OldCharge = Charge;
	Charge = 0;
	for (int i=0; i < FNumStructuralCues(); i++) {
		Charge = Charge + GetStructuralCueNum(i)*GetStructuralCue(i)->FCharge();
	}

	if (Charge != OldCharge) {
		ChangeNumHydrogen(int(Charge-OldCharge));
		ostringstream strout;
		strout << GetData("NAME",STRING) << " (" << GetData("DATABASE",STRING) << ") charge changed from " << OldCharge << " to " << Charge;
	}
};

void Species::SetFormulaToNeutral() {
	ChangeNumHydrogen(-Charge);
};

void Species::CorrectStructuralCues() {
	for (int i=0; i < FNumStructuralCues(); i++) {
		if (StructuralCues[i]->FEntry() == -1) {
			Species* Temp = MainData->FindStructuralCue("NAME;DATABASE;ENTRY",StructuralCues[i]->GetData("NAME",STRING).data());
			if (Temp == NULL) {
				cout << "uh oh" << endl;
			}
			delete StructuralCues[i];
			StructuralCues[i] = Temp;
		}
	}
}

void Species::RemoveAtom(int InIndex) {
	Atoms.erase(Atoms.begin()+InIndex,Atoms.begin()+InIndex+1);
	Reindex();
}

void Species::Reindex() {
	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetIndex(i);
	}
}

void Species::TranslateFormulaToAtoms() {
	if (FNumAtoms() == 0) {
		int i, j;
		
		int Location;
		string Temp(Formula);
		string TempTemp;
		string AtomLabel;

		if(Formula.compare("None") == 0 || Formula.compare("Unknown") == 0 || Formula.compare("") == 0) {
			return;
		}

		vector<double> NumAtoms;
		vector<AtomType*> AtomTypes;
		while(Temp.length() > 0) {
			Location = int(Temp.find_first_of("1234567890."));
			if (Location == int(Temp.npos)) {
				Location = int((Temp.length()+1));
			}
			if (Location > 0) {
				if (TempTemp.length() > 0) {
					NumAtoms.push_back(atof(TempTemp.data()));
					TempTemp.assign("");
				}
				int BestMatch = -1;
				int MatchLength = 0;
				for (i=0; i < FNumAtomTypes(); i++) {
					if (GetAtomType(i)->FID().length() <= Temp.length() && GetAtomType(i)->FID().compare(Temp.substr(0,GetAtomType(i)->FID().length())) == 0 && int(GetAtomType(i)->FID().length()) > MatchLength) {
						BestMatch = i;
						MatchLength = int(GetAtomType(i)->FID().length());
					}
				}
				if (BestMatch != -1) {
					AtomTypes.push_back(GetAtomType(BestMatch));
					Temp = Temp.substr(GetAtomType(BestMatch)->FID().length(), Temp.length()-GetAtomType(BestMatch)->FID().length());
					if (Location > int(GetAtomType(BestMatch)->FID().length())) {
						NumAtoms.push_back(1);
					}
				} else {
					cout << "Alert, unidentified group " << Temp << endl;
					return;
				}
			}
			else {
				TempTemp.append(Temp.substr(0, 1));
				Temp = Temp.substr(1, Temp.length()-1);
			}
		}
		if (TempTemp.length() > 0) {
			NumAtoms.push_back(atof(TempTemp.data()));
		}
		
		for (i=0; i< int(AtomTypes.size()); i++) {
			for (j=0; j< int(NumAtoms[i]); j++) {
				AtomCPP* NewAtom = new AtomCPP(AtomTypes[i],FNumAtoms(),this);
				AddAtom(NewAtom);
			}
		}
	}
}

void Species::ChangeNumHydrogen(int ChangeInH) {
	int i, j;
	AtomType* HType =GetAtomType("H");
	
	if (FNumAtoms() == 0) {
		TranslateFormulaToAtoms();
	}

	if (ChangeInH > 0) {
		for (i=0; i< ChangeInH; i++) {
			AtomCPP* NewH = new AtomCPP(HType, FNumAtoms(), this);
			AddAtom(NewH);
		}
	}
	else if (ChangeInH < 0) {
		for (i=0; i< -ChangeInH; i++) {
			for (j=0; j< FNumAtoms(); j++) {
				if (GetAtom(j)->FType() == HType) {
					GetAtom(j)->ClearBonds();
					RemoveAtom(j);
					break;
				}
			}
		}
	}
	CalculateFormula();
}

//Much data can be stored in the stringcode. All of the boolean arguments specify exactly what will be stored in the string code.
bool AtomCodeGreater ( AtomCPP* One, AtomCPP* Two ) {
   return One->FCode() > Two->FCode();
}

string Species::CreateStringcode(bool CycleID, bool GroupData, bool FullyProtonate, bool DoubleBonds, bool Hydrogen, bool Charges, bool CisTrans, bool Stereo) {
	int i,j;

	for (i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetLabeled(false);
		//I set all marks to zero because I am going to explore the molecule in this way
		GetAtom(i)->SetMark(false);
		//This is where the morgan number is stored, and this needs to be initialized to zero
		GetAtom(i)->SetParentID(0);
	}

	int NumMarked = 0;
	//This boolean indicates if any new atoms have been marked on a given iteration of the algorithm
	bool First = true;
	//This is a set of booleans indicating which atoms are marked during the current iteration
	bool* NewMarks = new bool[FNumAtoms()];
	//I initialize the marks array to false so that the hydrogens can be marked as true. 
	for (i=0; i < FNumAtoms(); i++) {
		NewMarks[i] = false;
	}
	//First I want to process through hydrogens specifically. This is to prevent two different charged forms of the same molecule from generating different stringcodes.
	for (i=0; i < FNumAtoms(); i++) {
		//Setting the canonical index of all atoms to -1
		GetAtom(i)->SetCanonicalIndex(-1);
		if (GetAtom(i)->FType()->FID().compare("H") == 0 && GetAtom(i)->MakeStringCode(CycleID,GroupData,FullyProtonate,DoubleBonds,Hydrogen,Charges,CisTrans,Stereo)) {
			NewMarks[i] = true;
			GetAtom(i)->SetMark(true);
			NumMarked++;
		}
	}
	//Now I process through the rest of the molecule. Note the stringcodes generated will be different if you do not process the hydrogens separately. Group like =O will be marked at the same time as the hydrogens.
	do {
		//Initiallizing first as true
		First = true;
		for (i=0; i < FNumAtoms(); i++) {
			//I call the makestringcode function for each unmarked atom. If the atom only has one unmarked neighbor, then it makes its string code from the stringcodes of its neighbors and returns true. Else it returns false.
			if (!GetAtom(i)->FMark() && GetAtom(i)->MakeStringCode(CycleID,GroupData,FullyProtonate,DoubleBonds,Hydrogen,Charges,CisTrans,Stereo)) {
				if (First) {
					//If first is still true, this is the first atom marked during this iteration
					//Clear the marks array here. I donot clear it at the end of each iteration because I need the information in the marked array at the end of the algorithm
					for (j=0; j < FNumAtoms(); j++) {
						NewMarks[j] = false;
					}
					//Set first to false
					First = false;
				}
				//Set the marks to true for this atom
				NewMarks[i] = true;
				NumMarked++;
			}
		}
	
		//Now I set the mark in the atom datastructure to true for all atoms marked during this iteration
		for (i=0; i < FNumAtoms(); i++) {
			if (NewMarks[i]) {
				GetAtom(i)->SetMark(true);
			}
		}
		//If first equals false here, no new atoms were marked this round and NewMarks contains a marked list of all atoms marked in the final round. These are the roots for a linear molecule.
	}while(First == false);
	
	//If all atoms are marked, this is a noncyclical molecule and I can make the stringcode directly
	if (NumMarked == FNumAtoms()) {
		string NewCode;
		
		AtomCPP* RootAtom = NULL;
		AtomCPP* SecondRootAtom = NULL;
		for (i=0; i < FNumAtoms(); i++) {
			if (NewMarks[i] && NewCode.length() == 0) {
				//Set the stringcode for the molecule to the string code for the root
				NewCode.assign(GetAtom(i)->FCode());
				RootAtom = GetAtom(i);
			} else if (NewMarks[i]) {
				//Incase there are two roots, I have to sort the codes for the roots and put () around the code.
				if(NewCode > GetAtom(i)->FCode()) {
					NewCode.insert(0,GetAtom(i)->FCode());
					SecondRootAtom = RootAtom;
					RootAtom = GetAtom(i);
				} else {
					NewCode.append(GetAtom(i)->FCode());
					SecondRootAtom = GetAtom(i);
				}
				NewCode.insert(0,"(");
				NewCode.append(")");
			}
		}
		//Setting the canonical index for the atoms in the molecule
		if (SecondRootAtom != NULL) {
			SecondRootAtom->SetCanonicalIndex(FNumAtoms()+1);
		}
		int CanonicalIndex = RootAtom->IndexAtoms(0);
		if (SecondRootAtom != NULL) {
			CanonicalIndex = SecondRootAtom->IndexAtoms(CanonicalIndex+1);
		}
		//Resetting all atom parameters
		for (i=0; i < FNumAtoms(); i++) {
			GetAtom(i)->DeleteCode();
			GetAtom(i)->SetMark(false);
			GetAtom(i)->SetLabeled(false);
			//This is where the morgan number is stored, and this needs to be initialized to zero
			GetAtom(i)->SetParentID(0);
		}
		//Since this is a linear molecule, the algorithm is finished here.
		delete [] NewMarks;
		return NewCode;
	}
	delete [] NewMarks;

	//If the code reaches this point, then this molecule ivolves cycles, and all the remaining atoms are part of a single biconnected component. I use morgan's algorithm to determine the unique root.
	//First I determine the lexicographical rank of all atoms using a map
	map<string, list<AtomCPP*>*, std::less<string> > LexicoSortingMap;
	multimap<long long , AtomCPP*, std::less<long long> > IndexSortingMap;
	typedef pair <long long, AtomCPP*> Datapair;
	vector<AtomCPP*> SortedAtoms;
	for (i=0; i < FNumAtoms(); i++) {
		if (!GetAtom(i)->FMark()) {
			//All biconnected component atoms need to have their canonical index set to -2
			GetAtom(i)->SetCanonicalIndex(-2);
			SortedAtoms.push_back(GetAtom(i));
			GetAtom(i)->SetParentID(-1);
			GetAtom(i)->MakeStringCode(CycleID,GroupData,FullyProtonate,DoubleBonds,Hydrogen,Charges,CisTrans,Stereo);
			list<AtomCPP*>* Result = LexicoSortingMap[ GetAtom(i)->FCode() ];
			if (Result == NULL) {
				Result = new list<AtomCPP*>;
				LexicoSortingMap[ GetAtom(i)->FCode() ] = Result;
			}
			Result->push_back(GetAtom(i));
		}
	}
		
	//Now I store the lexicographical rank of each atom in its parent ID and calculate it primary index and rank the primary index using a map
	map<string, list<AtomCPP*>*>::iterator LexMapIT = LexicoSortingMap.begin();
	list<AtomCPP*>::iterator ListIT;
	for (i=0; i < int(LexicoSortingMap.size()); i++) {
		list<AtomCPP*>* TempList = LexMapIT->second;
		ListIT = TempList->begin();
		for (j=0; j < int(TempList->size()); j++) {
			(*ListIT)->SetParentID(i+1);
			IndexSortingMap.insert(Datapair((*ListIT)->DeterminePrimaryIndex(),(*ListIT)));
			ListIT++;
		}
		delete TempList;
		LexMapIT++;
	}
	LexicoSortingMap.clear();
	
	//Now I store the index rank of each atom in parent ID
	multimap<long long, AtomCPP*>::iterator MapIT = IndexSortingMap.begin();
	long long LastValue = MapIT->first;
	int CurrentRank = 1;
	for (i=0; i < int(IndexSortingMap.size()); i++) {
		if (MapIT->first != LastValue) {
			CurrentRank++;
		}
		LastValue = MapIT->first;
		MapIT->second->SetParentID(CurrentRank);
		MapIT++;
	}
	IndexSortingMap.clear();

	vector<int> RankSet(SortedAtoms.size()+1);
	int FirstTie = -1;
	//I repeatedly calculate ranking based on secondary index until there are no more ties
	do {
		bool Change = false;
		//I repeatedly calculate and rank the secondary indexes until the ranks don't change.
		do {
			//Now I calculate the secondary index and rank the atoms using a map
			for (i=0; i < int(SortedAtoms.size()); i++) {
				IndexSortingMap.insert(Datapair(SortedAtoms[i]->DeterminSecondaryIndex(),SortedAtoms[i]));
			}

			Change = false;
			//Now I store the index rank of each atom in parent ID
			MapIT = IndexSortingMap.begin();
			LastValue = MapIT->first;
			CurrentRank = 1;
			for (i=0; i < int(IndexSortingMap.size()); i++) {
				if (MapIT->first != LastValue) {
					LastValue = MapIT->first;
					CurrentRank++;
				}
				if (MapIT->second->FParentID() != CurrentRank) {
					Change = true;					
					MapIT->second->SetParentID(CurrentRank);
				}
				MapIT++;
			}
			IndexSortingMap.clear();
		} while(Change == true);
		
		//Now I check for ties
		for (i=0; i < int(SortedAtoms.size()); i++) {
			RankSet[i+1] = -1;
		}
		FirstTie = -1;
		for (i=0; i < int(SortedAtoms.size()); i++) {
			if (RankSet[int(SortedAtoms[i]->FParentID())] == -1) {
				RankSet[int(SortedAtoms[i]->FParentID())] = i;
			}
			else {
				if (FirstTie == -1 || FirstTie > SortedAtoms[i]->FParentID()) {
					FirstTie = int(SortedAtoms[i]->FParentID());
				}
			}
		}
	
		//I have two atoms that have the same secondary index ranking. I iterate the first tie I find by one, and repeat the analysis.
		if (FirstTie != -1) {
			for (i=0; i < int(SortedAtoms.size()); i++) {
				if (SortedAtoms[i]->FParentID() >= FirstTie && i != RankSet[FirstTie]) {
					SortedAtoms[i]->SetParentID(SortedAtoms[i]->FParentID()+1);
				}
			}
		}
	} while (FirstTie != -1);
	
	string NewCode = SortedAtoms[RankSet[1]]->MakeMorganStringCode(NULL);
	SortedAtoms[RankSet[1]]->MorganIndexAtoms(0);
	for (i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->DeleteCode();
		GetAtom(i)->SetMark(false);
		GetAtom(i)->SetLabeled(false);
		//This is where the morgan number is stored, and this needs to be initialized to zero
		GetAtom(i)->SetParentID(0);
	}

	return NewCode;
};
//END FUNCTION: string CreateStringcode

void Species::MakeNeutral() {
	AtomType* HType = GetAtomType("H");
	int HToAdd = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FCharge() < 0 && GetAtom(i)->FType()->FID().compare("CoA") != 0) {
			HToAdd = -GetAtom(i)->FCharge();
			for (int j=0; j < HToAdd; j++) {
				AtomCPP* NewAtom = new AtomCPP(HType,FNumAtoms(),this);
				Atoms.push_back(NewAtom);
				GetAtom(i)->ChangeBondOrder(NewAtom,1);
				NewAtom->ChangeBondOrder(GetAtom(i),1);
				NewAtom->SetGroupData(GetAtom(i)->FGroup(),GetAtom(i)->FGroupIndex());
			}
			GetAtom(i)->SetCharge(0);
		}
		else if (GetAtom(i)->FCharge() > 0) {
			GetAtom(i)->Neutralize();
		}
	}
}

//In order to save memmory and make molecule pictures more veiwable, the CoA structure is often replaced with the text CoA.
//This function searches for the text CoA and replaces it with the CoA structure. This allows for correct stringcode generation
//and comparison with structures where this replacement has not occurred. While this function exists, I chose to go the other 
//way around and always replace the CoA structure with CoA for my comparisons.
void Species::ReplaceCoAWithFullMolecule() {
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare(COA_ID) == 0) {
			AtomCPP* CoAAtom = GetAtom(i);
			AtomCPP* CoASulfurAtom = GetAtom(i)->GetBond(0);
			for (int j=0; j < CoASulfurAtom->FNumBonds(); j++) {
				CoASulfurAtom->ChangeBondOrder(CoAAtom,-1);
				CoAAtom->ChangeBondOrder(CoASulfurAtom,-1);
				RemoveAtom(CoAAtom->FIndex());
				delete CoAAtom;
			}
			
			string Filename(GetDatabaseDirectory(GetParameter("database"),"molfile directory")+GetParameter("CoA structure file location"));
			string EmptyString;
			Species* NewSpecies = new Species(EmptyString,MainData);
			if (Filename.substr(Filename.length()-3,3).compare("dat") == 0) {
				NewSpecies->ReadFromDat(Filename);
			} else if (Filename.substr(Filename.length()-3,3).compare("mol") == 0) {
				NewSpecies->ReadFromMol(Filename);
			} else {
				FErrorFile() << "Unrecognized format for CoA structure file. Could not add CoA." << endl;
				FlushErrorFile();
				return;
			}
			
			AtomCPP* HAtomToDelete = NULL;
			for (int j=0; j < NewSpecies->FNumAtoms(); j++) {
				if (NewSpecies->GetAtom(j)->FType()->FID().compare("S") == 0) {
					for (int k=0; k < NewSpecies->GetAtom(j)->FNumBonds(); k++) {
						if (NewSpecies->GetAtom(j)->GetBond(k)->FType()->FID().compare("H") == 0) {
							HAtomToDelete = NewSpecies->GetAtom(j)->GetBond(k);
						} else {
							NewSpecies->GetAtom(j)->GetBond(k)->ChangeBondOrder(NewSpecies->GetAtom(j),-1);
							CoASulfurAtom->ChangeBondOrder(NewSpecies->GetAtom(j)->GetBond(k),1);
							NewSpecies->GetAtom(j)->GetBond(k)->ChangeBondOrder(CoASulfurAtom,1);
						}
					}
					delete NewSpecies->GetAtom(j);
				} else {
					AddAtom(NewSpecies->GetAtom(j));
					NewSpecies->GetAtom(j)->SetOwner(this);
				}
			}
			NewSpecies->ClearAtomList();
			delete NewSpecies;
			RemoveAtom(HAtomToDelete->FIndex());
			delete HAtomToDelete;
		}
	}
} //End void Species::ReplaceCoAWithFullMolecule()

void Species::ReplaceFullCoAMoleculeWithCoAAtom() {
	CheckForCoa();
	if (FCoa() && CountAtomType(COA_ID) == 0) {
		AtomType* CoAType = GetAtomType(COA_ID);
		for (int i=0; i < FNumAtoms(); i++) {
			if (GetAtom(i)->FType()->FID().compare("S") == 0) {
				if (GetAtom(i)->FNumBonds() == 2) {
					AtomCPP* SulfurAtom = GetAtom(i);
					for (int j=0; j < SulfurAtom->FNumBonds(); j++) {
						if (SulfurAtom->GetBond(j)->FType()->FID().compare("C") == 0) {
							ResetAtomMarks();
							SulfurAtom->SetMark(true);
							SulfurAtom->GetBond(j)->Explore();
						}
						int Count = 0;
						for (int k=0; k < FNumAtoms(); k++) {
							if (GetAtom(k)->FMark() && GetAtom(k)->FType()->FID().compare("H") != 0) {
								Count++;
							}
						}
						if (Count == NUM_NON_H_COA_ATOMS) {
							SulfurAtom->ChangeBondOrder(GetAtom(i)->GetBond(j),-1);
							for (int k=0; k < FNumAtoms(); k++) {
								if (GetAtom(k)->FMark() && GetAtom(k)->FType()->FID().compare("S") != 0) {
									delete GetAtom(k);
									RemoveAtom(k);
									k--;
								}
							}
							AtomCPP* NewAtom = new AtomCPP(CoAType,FNumAtoms(),this);
							AddAtom(NewAtom);
							SulfurAtom->ChangeBondOrder(NewAtom,1);
							NewAtom->ChangeBondOrder(SulfurAtom,1);
							j = SulfurAtom->FNumBonds();
						}
					}
				}
			}
		}
	}
} //End void Species::ReplaceFullCoAMoleculeWithCoAAtom()

void Species::CountConjugates() {
	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetMark(false);
	}
	
	//This naming scheme for the conjugation groups works as follows: OCCO = O=C-C=O, OCCC = O=C-C=C- etc...
	int OCCO = 0;
	int OCCC = 0;
	int OCCN = 0;
	int OCNC = 0;
	int NCCN = 0;
	int NCNC = 0;
	int CCCN = 0;
	int CCNC = 0;
	int CCCC = 0;
	int CNNC = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		//I start by looking for a carbon with at least one double bond
		//I'm generally going to be looking for the carbon in the second position of the various conjugation groups
		if (GetAtom(i)->FType()->FID().compare("C") == 0 && GetAtom(i)->FNumBonds() < 4) {
			GetAtom(i)->SetMark(true);
			for (int j=0; j < GetAtom(i)->FNumBonds(); j++) {
				if (GetAtom(i)->GetBondOrder(j) == 2) {
					if (GetAtom(i)->GetBond(j)->FType()->FID().compare("O") == 0) {
						//Looking for: OCCO, OCCC, OCCN, OCNC, found O=C...
						for (int k=0; k < GetAtom(i)->FNumBonds(); k++) {
							if (GetAtom(i)->GetBond(k)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: OCCO, OCCC, OCCN, found O=C-C...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: OCCC, found O=C-C=C...
										OCCC++;
									} else if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("O") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2 && !GetAtom(i)->GetBond(k)->FMark()) {
										//Looking for: OCCO, found O=C-C=O... (because this is a symmetrical conjugation, I make sure the second carbon atom is unmarked)
										OCCO++;
									} else if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: OCCN, found O=C-C=N...
										OCCN++;
									} else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: O=C-C double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							} else if (GetAtom(i)->GetBond(k)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: OCNC, found O=C-N...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: OCNC, found O=C-N=C...
										OCNC++;
									}  else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: O=C-N double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							}
						}
					} else if (GetAtom(i)->GetBond(j)->FType()->FID().compare("C") == 0) {
						//Looking for: CCCN, CCNC, CCCC, found C=C...
						for (int k=0; k < GetAtom(i)->FNumBonds(); k++) {
							if (GetAtom(i)->GetBond(k)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: CCCN, CCCC, found C=C-C...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2 && !GetAtom(i)->GetBond(k)->FMark()) {
										//Looking for: CCCC, found C=C-C=C...(because this is a symmetrical conjugation, I make sure the second carbon atom is unmarked)
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											CCCC++;
										}
									} else if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: CCCN, found C=C-C=N...
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											CCCN++;
										}
									} else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2 && GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("O") != 0 && GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") != 0) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: C=C-C double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							} else if (GetAtom(i)->GetBond(k)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: CCNC, found C=C-N...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: CCNC, found C=C-N=C...
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											CCNC++;
										}
									}  else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: O=C-N double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							}
						}
					} else if (GetAtom(i)->GetBond(j)->FType()->FID().compare("N") == 0) {
						//Looking for: NCCN, NCNC, found N=C...
						for (int k=0; k < GetAtom(i)->FNumBonds(); k++) {
							if (GetAtom(i)->GetBond(k)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: NCCN, found N=C-C...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2 && !GetAtom(i)->GetBond(k)->FMark()) {
										//Looking for: NCCN, found N=C-C=N...(because this is a symmetrical conjugation, I make sure the second carbon atom is unmarked)
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											NCCN++;
										}
									} else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2 && GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("O") != 0 && GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") != 0) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: N=C-C double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							} else if (GetAtom(i)->GetBond(k)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBondOrder(k) == 1) {
								//Looking for: CCNC, found C=C-N...
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: CCNC, found C=C-N=C...
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											CCNC++;
										}
									}  else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: O=C-N double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							}
						}
					} else {
						FErrorFile() << "NEW CONJUGATION: " << GetData("NAME",STRING) << " (C:" << GetData("DATABASE",STRING) << "): Possibly new unaccounted type of conjugation: C double bonded to " << GetAtom(i)->GetBond(j)->FType()->FID() << endl;
						FlushErrorFile();
					}
				}
			}
		} else if (GetAtom(i)->FType()->FID().compare("N") == 0 && GetAtom(i)->FNumBonds() < 4) {
			GetAtom(i)->SetMark(true);
			for (int j=0; j < GetAtom(i)->FNumBonds(); j++) {
				if (GetAtom(i)->GetBondOrder(j) == 2) {
					if (GetAtom(i)->GetBond(j)->FType()->FID().compare("C") == 0) {
						//Looking for: CNNC, found C=N...
						for (int k=0; k < GetAtom(i)->FNumBonds(); k++) {
							if (GetAtom(i)->GetBond(k)->FType()->FID().compare("N") == 0 && GetAtom(i)->GetBondOrder(k) == 1 && !GetAtom(i)->GetBond(k)->FMark()) {
								//Looking for: CNNC, found C=N-N...(because this is a symmetrical conjugation, I make sure the second carbon atom is unmarked)
								for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
									if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("C") == 0 && GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//Looking for: CNNC, found C=N-N=C...
										//I also make sure both double bonds are not part of an aromatic ring
										if (!(GetAtom(i)->FMemberOfAromaticRing()*GetAtom(i)->GetBond(k)->FMemberOfAromaticRing())) {
											CNNC++;
										}
									} else if (GetAtom(i)->GetBond(k)->GetBondOrder(l) == 2) {
										//FErrorFile() << GetData("NAME",STRING) << " (C:" << FEntry() << "): Possibly new unaccounted type of conjugation: C=N-N double bonded to " << GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID() << endl;
									}
								}
							}
						}
					}
				}
			}
		}
	}

	Species* NewStructCue = NULL;
	if (OCCO > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","OCCO");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(OCCO);
		}
	}
	if (OCCC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","OCCC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(OCCC);
		}
	}
	if (OCCN > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","OCCN");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(OCCN);
		}
	}
	if (OCNC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","OCNC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(OCNC);
		}
	}
	if (NCCN > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","NCCN");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(NCCN);
		}
	}
	if (NCNC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","NCNC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(NCNC);
		}
	}
	if (CCCN > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","CCCN");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(CCCN);
		}
	}
	if (CCNC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","CCNC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(CCNC);
		}
	}
	if (CCCC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","CCCC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(CCCC);
		}
	}
	if (CNNC > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","CNNC");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(CNNC);
		}
	}

	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetMark(false);
	}
};

//This function counts the number of vicinal chlorine atoms in the molecule for the VicinalCl correction factor
void Species::CountVicinalChlorines() {
	//I initiallize the atoms markers
	bool* OriginalLabel = new bool[FNumAtoms()];
	for (int i=0; i < FNumAtoms(); i++) {
		OriginalLabel[i] = GetAtom(i)->FLabeled();
		GetAtom(i)->SetMark(false);
	}
	
	int VicinalChlorines = 0;
	int BinaryVicinalChlorines  = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FType()->FID().compare("C") == 0) {
			bool ChlorineFound = false;
			//The "Labeled" marker is used to make sure I don't count the same neighbor chlorine twice
			for (int j=0; j < FNumAtoms(); j++) {
				GetAtom(j)->SetLabeled(false);
			}
			for (int j=0; j < GetAtom(i)->FNumBonds(); j++) {
				if (GetAtom(i)->GetBond(j)->FType()->FID().compare("Cl") == 0) {
					for (int k=0; k < GetAtom(i)->FNumBonds(); k++) {
						if (GetAtom(i)->GetBond(k)->FType()->FID().compare("C") == 0) {
							for (int l=0; l < GetAtom(i)->GetBond(k)->FNumBonds(); l++) {
								if (GetAtom(i)->GetBond(k)->GetBond(l)->FType()->FID().compare("Cl") == 0 && GetAtom(i)->GetBond(k)->GetBond(l)->FMark() == false && GetAtom(i)->GetBond(k)->GetBond(l)->FLabeled() == false) {
									if (!ChlorineFound) {
										BinaryVicinalChlorines++;
									}
									VicinalChlorines++;
									//I mark this neighbor chlorine so I know I've already counted it
									GetAtom(i)->GetBond(k)->GetBond(l)->SetLabeled(true);
									l = GetAtom(i)->GetBond(k)->FNumBonds();
								}
							}
						}
					}
					GetAtom(i)->GetBond(j)->SetMark(true);
					ChlorineFound = true;
				}
			}
		}
	}

	//Now I add the VicinalCl correction factor to the list of groups
	Species* NewStructCue = NULL;
	if (VicinalChlorines > 0) {
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","BinaryVicinalCl");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(BinaryVicinalChlorines);
		}
		NewStructCue = MainData->FindStructuralCue("DATABASE;NAME;ENTRY","DistinctVicinalCl");
		if (NewStructCue != NULL) {
			StructuralCues.push_back(NewStructCue);
			NumStructuralCues.push_back(VicinalChlorines);
		}
	}

	//I reinitiallize the atoms markers
	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetLabeled(OriginalLabel[i]);
		GetAtom(i)->SetMark(false);
	}
	delete [] OriginalLabel;
};

//This function returns the charge of the molecule at the input pH assuming the current charge is the charge at pH 7
int Species::CalculatePredominantIon(double InpH) {
	int NewCharge = Charge;

	for (int i=0; i < int(pKaAtoms.size()); i++) {
		if (pKa[i] > 7 && pKa[i] < InpH) {
			NewCharge--;
		} else if (pKa[i] > InpH && pKa[i] < 7) {
			NewCharge++;
		}
	}
	for (int i=0; i < int(pKbAtoms.size()); i++) {
		if (pKb[i] > 7 && pKb[i] < InpH) {
			NewCharge--;
		} else if (pKb[i] > InpH && pKb[i] < 7) {
			NewCharge++;
		}
	}
	return NewCharge;
}

bool Species::PropagateMarks() {
	int NumProducers = 0;
	int NumConsumers = 0;
	int Count = 0;
	int TotalProducers = 0;
	int TotalConsumers = 0;

	//I do not mark extracellular metabolites
	if (FExtracellular()) {
		return false;
	}

	vector<string> Names = GetAllData("NAME",STRING);
	for (int i=0; i < int(Names.size()); i++) {
		if (Names[i].find("Biomass") != -1) {
			return false;
		}
	}
	
	//I count the number of unmarked reactions this metabolite is involved in 
	for (list<Reaction*>::iterator IT = ReactionList.begin(); IT != ReactionList.end(); IT++) {
		if (!(*IT)->FMark()) {
			Count++;
			if ((*IT)->FType() == REVERSIBLE) {
				NumProducers++;
				TotalProducers++;
				NumConsumers++;
				TotalConsumers++;
			} else if ((*IT)->FType() == REVERSE) {
				if ((*IT)->GetReactantCoef(this) < 0) {
					NumProducers++;
					TotalProducers++;
				} else {
					NumConsumers++;
					TotalConsumers++;
				}
			} else if ((*IT)->FType() == FORWARD) {
				if ((*IT)->GetReactantCoef(this) < 0) {
					NumConsumers++;
					TotalConsumers++;
				} else {
					NumProducers++;
					TotalProducers++;
				}
			}
		} else {
			if ((*IT)->FType() == REVERSIBLE) {
				TotalProducers++;
				TotalConsumers++;
			} else if ((*IT)->FType() == REVERSE) {
				if ((*IT)->GetReactantCoef(this) < 0) {
					TotalProducers++;
				} else {
					TotalConsumers++;
				}
			} else if ((*IT)->FType() == FORWARD) {
				if ((*IT)->GetReactantCoef(this) < 0) {
					TotalConsumers++;
				} else {
					TotalProducers++;
				}
			}
		}
	}

	if (FNumReactions() <= 1 || TotalConsumers == 0 || TotalProducers == 0) {
		SetKill(true);
	}

	//If the metabolite is involved in one or fewer unmarked reactions, it is dead
	if (Count <= 1 || NumProducers == 0 || NumConsumers == 0) {
		SetMark(true);
		for (list<Reaction*>::iterator IT = ReactionList.begin(); IT != ReactionList.end(); IT++) {
			(*IT)->SetMark(true);
		}
		return true;
	}
	return false;
}

//Structure evaluating functions
//This function determines if the molecule contains any cycles
bool Species::IsTree() {
	ResetAtomMarks();
	//First we count the number of distinct edges
	double NumberOfEdges = 0;
	for (int i=0; i < FNumAtoms(); i++) {
		for (int j=0; j < GetAtom(i)->FNumBonds(); j++) {
			if (!GetAtom(i)->GetBond(j)->FMark()) {
				NumberOfEdges++;
			}
		}
		GetAtom(i)->SetMark(true);
	}

	//Reseting all atom marks back to false
	ResetAtomMarks();

	if (NumberOfEdges >= FNumAtoms()) {
		return false;
	}	
	return true;
};
//End IsTree()

//This function is necessary for sorting the cycles by size
bool MoleculeCycleGreater ( MoleculeCycle* One, MoleculeCycle* Two ) {
   return One->CycleAtoms.size() > Two->CycleAtoms.size();
}

//This function finds all of the cycles in the molecule and stores them in the vector Cycles
void Species::FindCycles() {
	int MaximumTime = 300;
	int i, CylceIndex;
	
	if (Cycles.size() > 0) {
		return;
	}	

	CylceIndex = 0;
	map<string , int , std::less<string> > SortedCycles;

	MoleculeExp* Explorer = new MoleculeExp;
	Explorer->VisitedAtomPosition = new int[FNumAtoms()];
	Explorer->PathwayList = new int[FNumAtoms()];
	Explorer->CurrentBond = new int[FNumAtoms()];
	Explorer->Length = 0;

	for(i=0; i < FNumAtoms(); i++) {
		Explorer->VisitedAtomPosition[i] = -1;
		Explorer->PathwayList[i] = -1;
		Explorer->CurrentBond[i] = -1;
	}

	Explorer->PathwayList[Explorer->Length] = GetAtom(0)->FIndex();
	Explorer->CurrentBond[Explorer->Length] = 0;
	Explorer->VisitedAtomPosition[GetAtom(0)->FIndex()] = 0;
	time_t StartTime = time(NULL);
	do {
		if ((time(NULL)-StartTime) > MaximumTime) {
			FErrorFile() << "Timed out finding cycles in: " << GetData("DATABASE",STRING) << endl;
			FlushErrorFile();
			break;
		}
		if (Explorer->Length == 0 && Explorer->CurrentBond[Explorer->Length] >= GetAtom(Explorer->PathwayList[Explorer->Length])->FNumBonds()) {
			break;
		}
		else if (Explorer->CurrentBond[Explorer->Length] >= GetAtom(Explorer->PathwayList[Explorer->Length])->FNumBonds()) {
			Explorer->VisitedAtomPosition[Explorer->PathwayList[Explorer->Length]] = -1;
			Explorer->PathwayList[Explorer->Length] = -1;
			Explorer->Length--;
		}
		else {
			int ChildAtomID = GetAtom(Explorer->PathwayList[Explorer->Length])->GetBond(Explorer->CurrentBond[Explorer->Length])->FIndex();
			Explorer->CurrentBond[Explorer->Length]++;
			if (Explorer->VisitedAtomPosition[ChildAtomID] != -1) {
				//Checking to make sure the parent isn't the child... that would indicate backtracking
				if (Explorer->PathwayList[Explorer->Length-1] != ChildAtomID) {
					//Cycle found!
					MoleculeCycle* cycleTmp = new MoleculeCycle;
					cycleTmp->Class = UNKNOWN;
					int CycleAtomCount = Explorer->Length+1-Explorer->VisitedAtomPosition[ChildAtomID];
					cycleTmp->CycleAtoms.resize(CycleAtomCount);
					int Lowest = Explorer->PathwayList[Explorer->VisitedAtomPosition[ChildAtomID]];
					int LowIndex = 0;
					for (i=0 ; i < CycleAtomCount; i++) {
						cycleTmp->CycleAtoms[i] = GetAtom(Explorer->PathwayList[Explorer->VisitedAtomPosition[ChildAtomID]+i]);
						if (cycleTmp->CycleAtoms[i]->FIndex() < Lowest) {
							Lowest = cycleTmp->CycleAtoms[i]->FIndex();
							LowIndex = i;
						}
					}
					
					//Putting atomIDs in order to start from lowest ID, and then run around the ring in order
					int NextIndex = LowIndex+1;
					int LastIndex = LowIndex-1;
					if (LastIndex == -1) {
						LastIndex = CycleAtomCount-1;
					}
					if (NextIndex == CycleAtomCount) {
						NextIndex = 0;
					}
					if (cycleTmp->CycleAtoms[LastIndex]->FIndex() < cycleTmp->CycleAtoms[NextIndex]->FIndex()) {
						int j = 0;
						for (i=CycleAtomCount ; i > 0; i--) {
							int Index = LowIndex+i;
							if (Index >= CycleAtomCount) {
								Index = Index-CycleAtomCount;
							}
							cycleTmp->CycleAtoms[j] = GetAtom(Explorer->PathwayList[Explorer->VisitedAtomPosition[ChildAtomID]+Index]);
							j++;
						}
					}
					else {
						for (i=0 ; i < CycleAtomCount; i++) {
							int Index = LowIndex+i;
							if (Index >= CycleAtomCount) {
								Index = Index-CycleAtomCount;
							}
							cycleTmp->CycleAtoms[i] = GetAtom(Explorer->PathwayList[Explorer->VisitedAtomPosition[ChildAtomID]+Index]);
						}
					}
					//Creating unique code for the cycle for this molecule with atoms in this order
					cycleTmp->CycleCode.clear();
					for (i=0 ; i < CycleAtomCount; i++) {
						cycleTmp->CycleCode.append(itoa(cycleTmp->CycleAtoms[i]->FIndex()));
						cycleTmp->CycleCode.append(";");
					}
					//Checking cycle uniqueness using cycle code;
					if (SortedCycles[cycleTmp->CycleCode] == 0) {
						cycleTmp->FusedCycles.resize(CycleAtomCount);
						cycleTmp->FusedBonds.resize(CycleAtomCount);
						for (i=0 ; i < CycleAtomCount; i++) {
							cycleTmp->FusedCycles[i] = NULL;
							cycleTmp->FusedBonds[i] = -1;
						}
						CylceIndex++;
						SortedCycles[cycleTmp->CycleCode] = CylceIndex;
						Cycles.push_back(cycleTmp);
					}
					else {
						delete cycleTmp;
					}
				}
			}
			else {
				Explorer->Length++;
				Explorer->PathwayList[Explorer->Length] = ChildAtomID;
				Explorer->CurrentBond[Explorer->Length] = 0;
				Explorer->VisitedAtomPosition[ChildAtomID] = Explorer->Length;
			}
		}
	} while(1);

	//Placing cycles in the list in decending order
	sort(Cycles.begin( ),Cycles.end( ), MoleculeCycleGreater);

	delete [] Explorer->PathwayList;
	delete [] Explorer->CurrentBond;
	delete [] Explorer->VisitedAtomPosition;
	delete Explorer;

	ReduceCycles();
	CycleLabeling();
}

void Species::ReduceCycles() {
	int i, j, k,l;
	
	//First I erase all cycles that donot contain any bonds that are not a part of smaller cycles
	map< int, int, std::less<int> > SortedBonds;
	for (i=0; i < FNumAtoms(); i++) {
		for (j=0; j < GetAtom(i)->FNumBonds(); j++) {
			if (GetAtom(i)->GetBond(j)->FIndex() > GetAtom(i)->FIndex()) {
				SortedBonds[GetAtom(i)->FIndex()*1000+GetAtom(i)->GetBond(j)->FIndex()] = 0;
			}
		}
	}

	for (i=int(Cycles.size()-1); i >= 0; i--) {
		bool Smallest = false;
		for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
			int NextCycleAtom = j+1;
			if (NextCycleAtom >= int(Cycles[i]->CycleAtoms.size())) {
				NextCycleAtom = 0;
			}
			int Temp =0;
			if (Cycles[i]->CycleAtoms[j]->FIndex() < Cycles[i]->CycleAtoms[NextCycleAtom]->FIndex()) {
				Temp = SortedBonds[Cycles[i]->CycleAtoms[j]->FIndex()*1000+Cycles[i]->CycleAtoms[NextCycleAtom]->FIndex()];
				if (Temp == 0 || int(Cycles[i]->CycleAtoms.size()) < Temp) {
					SortedBonds[Cycles[i]->CycleAtoms[j]->FIndex()*1000+Cycles[i]->CycleAtoms[NextCycleAtom]->FIndex()] = int(Cycles[i]->CycleAtoms.size());
					Smallest = true;
				}
			}
			else {
				Temp = SortedBonds[Cycles[i]->CycleAtoms[NextCycleAtom]->FIndex()*1000+Cycles[i]->CycleAtoms[j]->FIndex()];
				if (Temp == 0 || int(Cycles[i]->CycleAtoms.size()) < Temp) {
					SortedBonds[Cycles[i]->CycleAtoms[NextCycleAtom]->FIndex()*1000+Cycles[i]->CycleAtoms[j]->FIndex()] = int(Cycles[i]->CycleAtoms.size());
					Smallest = true; 
				}
			}
			if (int(Cycles[i]->CycleAtoms.size()) == Temp) {
				Smallest = true;
			}
		}
		if (!Smallest) {
			delete Cycles[i];
			Cycles.erase(Cycles.begin()+i,Cycles.begin()+i+1);
		}
	}
	
	//Now I set all fused cycle data
	for (i=0; i < int(Cycles.size()); i++) {
		for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
			for (k=i+1; k < int(Cycles.size()); k++) {
				for (l=0; l < int(Cycles[k]->CycleAtoms.size()); l++) {	
					if (Cycles[i]->CycleAtoms[j] == Cycles[k]->CycleAtoms[l]) {
						int NextCycleAtom = j+1;
						if (NextCycleAtom >= int(Cycles[i]->CycleAtoms.size())) {
							NextCycleAtom = 0;
						}
						int NextOtherCycleAtom = l+1;
						if (NextOtherCycleAtom >= int(Cycles[k]->CycleAtoms.size())) {
							NextOtherCycleAtom = 0;
						}
						int PrevOtherCycleAtom = l-1;
						if (PrevOtherCycleAtom < 0) {
							PrevOtherCycleAtom = int(Cycles[k]->CycleAtoms.size()-1);
						}
						if (Cycles[i]->CycleAtoms[NextCycleAtom] == Cycles[k]->CycleAtoms[NextOtherCycleAtom]) {
							Cycles[i]->FusedCycles[j] = Cycles[k];
							Cycles[i]->FusedBonds[j] = l;
							Cycles[k]->FusedCycles[l] = Cycles[i];
							Cycles[k]->FusedBonds[l] = j;
						}
						else if (Cycles[i]->CycleAtoms[NextCycleAtom] == Cycles[k]->CycleAtoms[PrevOtherCycleAtom]) {
							Cycles[i]->FusedCycles[j] = Cycles[k];
							Cycles[i]->FusedBonds[j] = PrevOtherCycleAtom;
							Cycles[k]->FusedCycles[PrevOtherCycleAtom] = Cycles[i];
							Cycles[k]->FusedBonds[PrevOtherCycleAtom] = j;
						}
					}
				}
			}
		}
	}
};

void Species::CycleLabeling() {
	int i,j;

	NumHeteroRings = 0;
	ThreeMemberRings = 0;
	NumLargeCycles = 0;

	for (i=0; i < int(Cycles.size()); i++) {
		//Classify the ring with respect to aromaticity
		NewClassifyRing(Cycles[i]);
		if (Cycles[i]->CycleAtoms.size() > 6) {
			NumLargeCycles++;
			if (Cycles[i]->CycleAtoms.size() < SAME_AS_LINEAR) {
				for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
					if (Cycles[i]->CycleAtoms.size() <= SAME_AS_SIX) {
						if (Cycles[i]->CycleAtoms.size() > 6) {
							//FErrorFile() << "Assuming cycle with " << Cycles[i]->CycleAtoms.size() << " atoms behaves the same as a six member cycle for " << GetData("NAME",STRING) << " " << FEntry() << endl; 
						}
						Cycles[i]->CycleAtoms[j]->AddCycle(SIX_MEMBER);
						Cycles[i]->CycleAtoms[j]->AddCycle(NONBENZENE);
					}
					else {
						Cycles[i]->CycleAtoms[j]->AddCycle(LARGE_CYCLE);
					}
				}	
			} else {
				//FErrorFile() << "Assuming cycle with " << Cycles[i]->CycleAtoms.size() << " atoms behaves linearly for " << GetData("NAME",STRING) << " " << FEntry() << endl; 
			}
		}
		else if (Cycles[i]->CycleAtoms.size() == 3) {
			ThreeMemberRings++;
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(NONBENZENE);
			}
		}
		else if (Cycles[i]->CycleAtoms.size() == 4) {
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(FOUR_MEMBER);
				Cycles[i]->CycleAtoms[j]->AddCycle(NONBENZENE);
			}
		}
		else if (Cycles[i]->Class == BENZENE) {
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(BENZENE);
			}
		}
		else if (Cycles[i]->Class == HETERO) {
			NumHeteroRings++;
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(HETERO);
			}
		}

		//Check these separately from HETERO because rings can be both
		if (Cycles[i]->CycleAtoms.size() == 5) {
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(FIVE_MEMBER);
				Cycles[i]->CycleAtoms[j]->AddCycle(NONBENZENE);
			}
		}
		else if (Cycles[i]->CycleAtoms.size() == 6 && Cycles[i]->Class != BENZENE) {
			for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
				Cycles[i]->CycleAtoms[j]->AddCycle(SIX_MEMBER);
				Cycles[i]->CycleAtoms[j]->AddCycle(NONBENZENE);
			}
		}
		
		for (j=0; j < int(Cycles[i]->CycleAtoms.size()); j++) {
			if (Cycles[i]->FusedBonds[j] != -1 && Cycles[i]->CycleAtoms.size() < SAME_AS_LINEAR && Cycles[i]->FusedCycles[j]->CycleAtoms.size() < SAME_AS_LINEAR) {
				Cycles[i]->CycleAtoms[j]->AddCycle(FUSED);
				if (j < int(Cycles[i]->CycleAtoms.size()-1)) {
					Cycles[i]->CycleAtoms[j+1]->AddCycle(FUSED);
				}else {
					Cycles[i]->CycleAtoms[0]->AddCycle(FUSED);
				}
			}
		}
	}
}

void Species::LabelAtoms() {
	if (FNumAtoms() == 0 && FFormula().length() < 3) {
		TranslateFormulaToAtoms();
	}

	if (FNumAtoms() == 0) {
		return;
	}
	for (int i=0; i < FNumAtoms(); i++) {
		//I set all marks to zero because I am going to explore the molecule in this way
		GetAtom(i)->SetMark(false);
	}

	if (FNuetralpHCharge() == FLAG) {
		SetNuetralpHCharge(FCharge());
	}

	if (FNumAtoms() == 1 || FNumAtoms() == 2) {
		for(int i=0; i < MainData->FNumStructuralCues(); i++) {
			if (FFormula().compare(MainData->GetStructuralCue(i)->FFormula()) == 0 && FNuetralpHCharge() == MainData->GetStructuralCue(i)->FCharge() &&  MainData->GetStructuralCue(i)->FSmallMolec()) {
				GetAtom(0)->SetGroupData(MainData->GetStructuralCue(i)->FEntry(),0);
				if (FNumAtoms() == 2) {
					GetAtom(1)->SetGroupData(MainData->GetStructuralCue(i)->FEntry(),1);
				}
				return;
			}
		}
		string EmptyString;
		Species* NewGroup = new Species(EmptyString,MainData,true);
		NewGroup->SetSmallMolec(true);
		string GroupName(FFormula());
		if (abs(FCharge()) > 1) {
			GroupName.append(itoa(abs(FCharge())));
		}
		if (FCharge() > 0) {
			GroupName.append("+");
		} else if (FCharge() < 0) {
			GroupName.append("-");
		}
		NewGroup->AddData("NAME",GroupName.data(),STRING);
		NewGroup->SetFormula(FFormula());
		NewGroup->SetEstDeltaG(-10000);
		NewGroup->SetCharge(FCharge());
		string DatabaseID("cue_");
		DatabaseID.append(GroupName);
		NewGroup->AddData("DATABASE",GroupName.data(),STRING);
		NewGroup->AddData("FILENAME",DatabaseID.data(),STRING);
		NewGroup = MainData->AddStructuralCue(NewGroup);
		NewGroup->SaveSpecies(DatabaseID);
		FLogFile() << "New single molecule groups: " << NewGroup->GetData("NAME",STRING) << ";1;" << NewGroup->FEstDeltaG() << ";" << NewGroup->FCharge() << ";0;" << NewGroup->FFormula() << ";" << ";{}" << endl;
		GetAtom(0)->SetGroupData(NewGroup->FEntry(),0);
		if (FNumAtoms() == 2) {
			GetAtom(1)->SetGroupData(NewGroup->FEntry(),1);
		}
		return;
	}

	for(int i=0; i < MainData->FNumFullMoleculeGroups(); i++) {
		Species* CurrentGroup = MainData->GetFullMoleculeGroup(i);
		if (CurrentGroup->FEntry() < 1000) {
			if (CurrentGroup->FNumNonHAtoms() == FNumNonHAtoms()) {
				for (int j=0; j < FNumAtoms(); j++) {
					if (GetAtom(j)->LabelAtoms(CurrentGroup->GetRootAtom())) {
						return;
					}
				}
			}
		}
	}

	for(int i=0; i < MainData->FNumSearchableGroups(); i++) {
		Species* CurrentGroup = MainData->GetSearchableGroup(i);
		if (CurrentGroup->FEntry() < 1000) {
			for (int j=0; j < FNumAtoms(); j++) {
				if (GetAtom(j)->FLabeled()== false) {
					GetAtom(j)->LabelAtoms(CurrentGroup->GetRootAtom());
				}
			}
		}
	}

	NumNoIDGroups = 0;
	for(int i=0; i < FNumAtoms(); i++) {
		if (GetAtom(i)->FLabeled() == false) {
			GetAtom(i)->SetGroupData(255,0);
			NumNoIDGroups++;
		}
	}

	if (NumNoIDGroups > 0) {
		AddErrorMessage("Unlabled atoms");
		AddLineToFile("CompoundsWithUnlabeledAtoms.txt",GetData("DATABASE",STRING));
		FErrorFile() << "UNLABELED ATOMS: " << GetData("NAME",STRING) << " " << GetData("DATABASE",STRING) << ": " << NumNoIDGroups << " out of " << FNumAtoms() << " unlabeled." << endl;
		FlushErrorFile();
		AddUnlabeledFormula(this);
	}

	for (int i=0; i < FNumAtoms(); i++) {
		GetAtom(i)->SetMark(false);
	}
}

//Metabolic flux analysis functions
void Species::CreateMFAVariables(OptimizationParameter* InParameters) {
	ClearMFAVariables(false);
	if (InParameters == NULL) {
		return;
	}

	if (InParameters->ThermoConstraints && InParameters->DeltaGError) {
		MFAVariable* NewVariable = InitializeMFAVariable();
		NewVariable->AssociatedSpecies = this;
		NewVariable->Name = GetData("DATABASE",STRING);
		NewVariable->Type = DELTAGF_PERROR;
		MFAVariables[DELTAGF_PERROR] = NewVariable;
		NewVariable->LowerBound = 0;
		if (FEstDeltaGUncertainty() != FLAG) {
			NewVariable->UpperBound = InParameters->ErrorMult*FEstDeltaGUncertainty();
		} else {
			NewVariable->UpperBound = InParameters->ErrorMult*DEFAULT_DELTAGF_ERROR;
		}
		NewVariable = InitializeMFAVariable();
		NewVariable->AssociatedSpecies = this;
		NewVariable->Name = GetData("DATABASE",STRING);
		NewVariable->Type = DELTAGF_NERROR;
		MFAVariables[DELTAGF_NERROR] = NewVariable;
		NewVariable->LowerBound = 0;
		if (FEstDeltaGUncertainty() != FLAG) {
			NewVariable->UpperBound = InParameters->ErrorMult*FEstDeltaGUncertainty();
		} else {
			NewVariable->UpperBound = InParameters->ErrorMult*DEFAULT_DELTAGF_ERROR;
		}
	}

	if (InParameters->ThermoConstraints) {
		//Every compartment represented in the current model must have a variable for the hydrogen ion concentration
		if (FFormula().compare("H") == 0) {
			for (int i=0; i < FNumCompartments(); i++) {
				if (FMainData()->CompartmentRepresented(i)) {
					AddCompartment(i);
				}
			}
		}
		
		for (map<int , SpeciesCompartment* , std::less<int> >::iterator MapIT = Compartments.begin(); MapIT != Compartments.end(); MapIT++) {
			MFAVariable* NewVariable = InitializeMFAVariable();
			NewVariable->AssociatedSpecies = this;
			NewVariable->Name = GetData("DATABASE",STRING);
			NewVariable->Compartment = MapIT->second->Compartment->Index;
			NewVariable->Type = POTENTIAL;
			MapIT->second->MFAVariables[POTENTIAL] = NewVariable;
			if (FFormula().compare("H2O") == 0) {
				NewVariable->LowerBound = AdjustedDeltaG(GetCompartment(NewVariable->Compartment)->IonicStrength,GetCompartment(NewVariable->Compartment)->pH,InParameters->Temperature);
				NewVariable->UpperBound = AdjustedDeltaG(GetCompartment(NewVariable->Compartment)->IonicStrength,GetCompartment(NewVariable->Compartment)->pH,InParameters->Temperature);
			} else {
				NewVariable->LowerBound = InParameters->MinPotential;
				NewVariable->UpperBound = InParameters->MaxPotential;
			}
			if (!InParameters->SimpleThermoConstraints || FFormula().compare("H") == 0) {
				NewVariable = InitializeMFAVariable();
				NewVariable->AssociatedSpecies = this;
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->Compartment = MapIT->second->Compartment->Index;
				NewVariable->Type = LOG_CONC;
				MapIT->second->MFAVariables[LOG_CONC] = NewVariable;
				NewVariable->LowerBound = log(MapIT->second->Compartment->MinConc);
				NewVariable->UpperBound = log(MapIT->second->Compartment->MaxConc);
			}
		}
	}

	vector<int> DrainCompartments;
	vector<double> DrainMaxes;
	vector<double> DrainMins;
	DrainCompartments.push_back(InParameters->DefaultExchangeComp);
	DrainMaxes.push_back(InParameters->MaxDrainFlux);
	DrainMins.push_back(InParameters->MinDrainFlux);

	for (int j=0; j < int(InParameters->ExchangeSpecies.size()); j++) {
		if (FMainData()->FindSpecies("NAME;DATABASE;ENTRY",InParameters->ExchangeSpecies[j].data()) == this) {
			if (InParameters->ExchangeComp[j] != InParameters->DefaultExchangeComp) {
				DrainCompartments.push_back(InParameters->ExchangeComp[j]);
				DrainMaxes.push_back(InParameters->ExchangeMax[j]);
				DrainMins.push_back(InParameters->ExchangeMin[j]);
			}
		}
	}
		
	for (int i=0; i < int(DrainCompartments.size()); i++) {
		SpeciesCompartment* Temp = Compartments[DrainCompartments[i]];
		if (Temp != NULL) {
			MFAVariable* NewVariable = InitializeMFAVariable();
			NewVariable->Name = GetData("DATABASE",STRING);
			NewVariable->AssociatedSpecies = this;
			NewVariable->Compartment = DrainCompartments[i];
			if (InParameters->DecomposeDrain) {
				NewVariable->Type = FORWARD_DRAIN_FLUX;
				Temp->MFAVariables[FORWARD_DRAIN_FLUX] = NewVariable;
				if (DrainMaxes[i] > 0) {
					NewVariable->UpperBound = DrainMaxes[i];
				} else {
					NewVariable->UpperBound = 0;
				}
				if (DrainMins[i] > 0) {
					NewVariable->LowerBound = DrainMins[i];
				} else {
					NewVariable->LowerBound = 0;
				}
				NewVariable = InitializeMFAVariable();
				NewVariable->Compartment = DrainCompartments[i];
				NewVariable->Name = GetData("DATABASE",STRING);
				NewVariable->AssociatedSpecies = this;
				NewVariable->Type = REVERSE_DRAIN_FLUX;
				Temp->MFAVariables[REVERSE_DRAIN_FLUX] = NewVariable;
				if (DrainMaxes[i] < 0) {
					NewVariable->LowerBound = -DrainMaxes[i];
				} else {
					NewVariable->LowerBound = 0;
				}
				if (DrainMins[i] < 0) {
					NewVariable->UpperBound = -DrainMins[i];
				} else {
					NewVariable->UpperBound = 0;
				}
			} else {
				NewVariable->Type = DRAIN_FLUX;
				Temp->MFAVariables[DRAIN_FLUX] = NewVariable;
				NewVariable->LowerBound = DrainMins[i];
				NewVariable->UpperBound = DrainMaxes[i];
			}
		}
	}
}

MFAVariable* Species::CreateMFAVariable(int InType,int InCompartment,double Min, double Max) {
	MFAVariable* NewVariable = InitializeMFAVariable();
	NewVariable->UpperBound = Max;
	NewVariable->LowerBound = Min;
	NewVariable->AssociatedSpecies = this;
	NewVariable->Compartment = InCompartment;
	NewVariable->Type = InType;

	if (InCompartment == -1) {
		MFAVariables[InType] = NewVariable;
	} else {
		SpeciesCompartment* NewCompartment = Compartments[InCompartment];
		if (NewCompartment == NULL) {
			delete NewVariable;
			return NULL;
		} else {
			NewCompartment->MFAVariables[InType] = NewVariable;
		}
	}

	return NewVariable;
}

void Species::UpdateBounds(int VarType, double Min, double Max, int Compartment, bool ApplyToMinMax) {
	MFAVariable* NewVariable = NULL;
	if (Compartment == -1) {
		NewVariable = MFAVariables[VarType];
		if (NewVariable != NULL) {
			if (ApplyToMinMax) {
				NewVariable->Max = Max;
				NewVariable->Min = Min;
			} else {
				NewVariable->UpperBound = Max;
				NewVariable->LowerBound = Min;
			}
			return;
		}

		if (VarType == DELTAGF_ERROR) {
			NewVariable = MFAVariables[DELTAGF_PERROR];
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
			NewVariable = MFAVariables[DELTAGF_NERROR];
			if (NewVariable != NULL) {
				if (ApplyToMinMax) {
					if (Max > 0) {
						NewVariable->Min = 0;
					} else {
						NewVariable->Min = -Max;
					}
					if (Min > 0) {
						NewVariable->Max = 0;
					} else {
						NewVariable->Max = -Min;
					}
				} else {
					if (Max > 0) {
						NewVariable->LowerBound = 0;
					} else {
						NewVariable->LowerBound = -Max;
					}
					if (Min > 0) {
						NewVariable->UpperBound = 0;
					} else {
						NewVariable->UpperBound = -Min;
					}
				}
			}
			return;
		} else if (VarType == DRAIN_FLUX || VarType == FORWARD_DRAIN_FLUX || VarType == REVERSE_DRAIN_FLUX) {
			Compartment = GetCompartment(GetParameter("default exchange compartment").data())->Index;
		}
	}
	
	if (Compartment == -1) {
		FErrorFile() << "MISSING VARIABLE TYPE: Species " << GetData("NAME",STRING) << " does not have variable type " << VarType << " with no associated compartment." << endl;
		FlushErrorFile();
		return;
	}

	SpeciesCompartment* NewCompartment = Compartments[Compartment];
	if (NewCompartment == NULL) {
		FErrorFile() << "SPECIES NOT PRESENT IN COMPARTMENT: Species " << GetData("NAME",STRING) << " does not exist in a compartment of type " << Compartment << endl;
		FlushErrorFile();
		return;
	}
	
	if (NewCompartment->Compartment->Abbreviation.compare("e") == 0 && (VarType == FORWARD_DRAIN_FLUX || VarType == DRAIN_FLUX) && GetParameter("Base compound regulation on media files").compare("1") == 0) {
		MFAVariable* UseVariable = NewCompartment->MFAVariables[DRAIN_USE];
		if (UseVariable == NULL) {
			UseVariable = NewCompartment->MFAVariables[FORWARD_DRAIN_USE];
		}
		if (UseVariable != NULL) {
			if (Max > 0) {
				UseVariable->LowerBound = 1;
				UseVariable->UpperBound = 1;
			} else {
				UseVariable->LowerBound = 0;
				UseVariable->UpperBound = 0;
			}
		}	
	}

	NewVariable = NewCompartment->MFAVariables[VarType];
	if (NewVariable != NULL) {
		if (ApplyToMinMax) {
			NewVariable->Max = Max;
			NewVariable->Min = Min;
		} else {
			NewVariable->UpperBound = Max;
			NewVariable->LowerBound = Min;
		}
		return;
	}
	
	if (VarType == DRAIN_FLUX) {
		NewVariable = NewCompartment->MFAVariables[FORWARD_DRAIN_FLUX];
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
		NewVariable = NewCompartment->MFAVariables[REVERSE_DRAIN_FLUX];
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
	} else if (VarType == FORWARD_DRAIN_FLUX) {
		NewVariable = NewCompartment->MFAVariables[DRAIN_FLUX];
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
	} else if (VarType == REVERSE_DRAIN_FLUX) {
		NewVariable = NewCompartment->MFAVariables[DRAIN_FLUX];
		if (NewVariable != NULL) {
			if (ApplyToMinMax) {
				if (Min > 0) {
					NewVariable->Max = -Min;
				}
				NewVariable->Min = -Max;
			} else {
				if (Min > 0) {
					NewVariable->UpperBound = -Min;
				}
				NewVariable->LowerBound = -Max;
			}
		}
	} else if (VarType == CONC) {
		NewVariable = NewCompartment->MFAVariables[LOG_CONC];
		if (NewVariable != NULL) {
			if (ApplyToMinMax) {
				NewVariable->Max = log(Max);
				NewVariable->Min = log(Min);
			} else {
				NewVariable->UpperBound = log(Max);
				NewVariable->LowerBound = log(Min);
			}
		}
	} else if (VarType == LOG_CONC) {
		NewVariable = NewCompartment->MFAVariables[CONC];
		if (NewVariable != NULL) {
			if (ApplyToMinMax) {
				NewVariable->Max = exp(Max);
				NewVariable->Min = exp(Min);
			} else {
				NewVariable->UpperBound = exp(Max);
				NewVariable->LowerBound = exp(Min);
			}
		}
	}
}

void Species::AddUseVariables(OptimizationParameter* InParameters) {
	if (InParameters == NULL) {
		return;
	}
	
	if (!InParameters->DrainUseVar) {
		return;
	}

	for (map<int , SpeciesCompartment* , std::less<int> >::iterator MapIT = Compartments.begin(); MapIT != Compartments.end(); MapIT++) {
		if (MapIT->second != NULL) {
			MFAVariable* NewVariable = MapIT->second->MFAVariables[DRAIN_FLUX];
			if (NewVariable != NULL) {
				if (InParameters->AllDrainUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
					NewVariable = InitializeMFAVariable();
					NewVariable->AssociatedSpecies = this;
					NewVariable->Type = DRAIN_USE;
					MapIT->second->MFAVariables[DRAIN_USE] = NewVariable;
					NewVariable->Compartment = MapIT->second->Compartment->Index;
					NewVariable->Binary = true;
					NewVariable->UpperBound = 1;
					NewVariable->LowerBound = 0;
				}
			} else {
				NewVariable = MapIT->second->MFAVariables[FORWARD_DRAIN_FLUX];
				if (NewVariable != NULL) {
					if (InParameters->AllDrainUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
						NewVariable = InitializeMFAVariable();
						NewVariable->AssociatedSpecies = this;
						NewVariable->Type = FORWARD_DRAIN_USE;
						MapIT->second->MFAVariables[FORWARD_DRAIN_USE] = NewVariable;
						NewVariable->Binary = true;
						NewVariable->Compartment = MapIT->second->Compartment->Index;
						NewVariable->UpperBound = 1;
						NewVariable->LowerBound = 0;
					}
				}
				NewVariable = MapIT->second->MFAVariables[REVERSE_DRAIN_FLUX];
				if (NewVariable != NULL) {
					if (InParameters->AllDrainUse || (NewVariable->UpperBound > MFA_ZERO_TOLERANCE && NewVariable->LowerBound < MFA_ZERO_TOLERANCE)) {
						NewVariable = InitializeMFAVariable();
						NewVariable->AssociatedSpecies = this;
						NewVariable->Type = REVERSE_DRAIN_USE;
						MapIT->second->MFAVariables[REVERSE_DRAIN_USE] = NewVariable;
						NewVariable->Binary = true;
						NewVariable->Compartment = MapIT->second->Compartment->Index;
						NewVariable->UpperBound = 1;
						NewVariable->LowerBound = 0;
					}
				}
			}
		}
	}
}

MFAVariable* Species::GetMFAVar(int InType, int InCompartment) {
	if (InCompartment == -1) {
		return MFAVariables[InType];
	} else {
		SpeciesCompartment* NewCompartment = Compartments[InCompartment];
		if (NewCompartment != NULL) {
			return NewCompartment->MFAVariables[InType];
		}
	}
	return NULL;
}

void Species::GetAllMFAVariables(vector<MFAVariable*>& InVector) {	
	for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MFAVariables.begin(); MapITT != MFAVariables.end(); MapITT++) {
		if (MapITT->second != NULL) {
			InVector.push_back(MapITT->second);
		}
	}

	for (map<int , SpeciesCompartment* , std::less<int> >::iterator MapIT = Compartments.begin(); MapIT != Compartments.end(); MapIT++) {
		if (MapIT->second != NULL) {
			for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MapIT->second->MFAVariables.begin(); MapITT != MapIT->second->MFAVariables.end(); MapITT++) {
				if (MapITT->second != NULL) {
					InVector.push_back(MapITT->second);
				}
			}
		}
	}
}

void Species::ClearMFAVariables(bool DeleteThem) {
	if (DeleteThem) {
		for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MFAVariables.begin(); MapITT != MFAVariables.end(); MapITT++) {
			if (MapITT->second != NULL) {
				delete MapITT->second;
			}
		}
	}

	MFAVariables.clear();
	for (map<int , SpeciesCompartment* , std::less<int> >::iterator MapIT = Compartments.begin(); MapIT != Compartments.end(); MapIT++) {
		if (MapIT->second != NULL) {
			if (DeleteThem) {
				for (map<int , MFAVariable* , std::less<int> >::iterator MapITT = MapIT->second->MFAVariables.begin(); MapITT != MapIT->second->MFAVariables.end(); MapITT++) {
					if (MapITT->second != NULL) {
						delete MapITT->second;
					}
				}
			}
			MapIT->second->MFAVariables.clear();
		}
	}
}

//Returns (Upper bound,LowerBound,Max,Min,Value)
vector<double> Species::RetrieveData(int VarType,int VarCompartment,OptSolutionData* InSolution) {
	//Initializing the result vector
	vector<double> Result(5,FLAG);
	
	//Retrieving the compartment
	SpeciesCompartment* CurrentCompartment = Compartments[VarCompartment];
	MFAVariable* PosVar = NULL;
	MFAVariable* NegVar = NULL;

	//Testing for exact variable match
	if (VarType == DRAIN_FLUX || VarType == POTENTIAL || VarType == LOG_CONC) {
		if (CurrentCompartment == NULL) {
			return Result;
		}
		PosVar = CurrentCompartment->MFAVariables[VarType];
	} else if (VarType == DELTAGF_ERROR) {
		PosVar = MFAVariables[DELTAGF_PERROR];
		NegVar = MFAVariables[DELTAGF_NERROR];
	}

	//Handling cases when nonexact variable match will occur
	if (PosVar == NULL) {
		if (VarType == DRAIN_FLUX) {
			PosVar = CurrentCompartment->MFAVariables[FORWARD_DRAIN_FLUX];
			NegVar = CurrentCompartment->MFAVariables[REVERSE_DRAIN_FLUX];
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
		} else if (PosVar->Index < int(InSolution->SolutionData.size())) {
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
				Result[4] = NegVar->Value;
			} else {
				Result[4] = Result[4] + NegVar->Value;
			}
		} else {
			if (NegVar->Index < int(InSolution->SolutionData.size())) {
				if (Result[4] == FLAG) {
					Result[4] = InSolution->SolutionData[NegVar->Index];
				} else {
					Result[4] = Result[4] + InSolution->SolutionData[NegVar->Index];
				} 
			}
		}
	}

	//Converting log concentration to concentration
	if (VarType == LOG_CONC) {
		if (Result[0] != FLAG) {
			Result[0] = exp(Result[0]);
		}
		if (Result[1] != FLAG) {
			Result[1] = exp(Result[1]);
		}
		if (Result[2] != FLAG) {
			Result[2] = exp(Result[2]);
		}
		if (Result[3] != FLAG) {
			Result[3] = exp(Result[3]);
		}
		if (Result[4] != FLAG) {
			Result[4] = exp(Result[4]);
		}
	}

	//Returning the result
	return Result;
}

//This is the new ring classification scheme for use with Chris Henry's group contribution scheme
void NewClassifyRing(MoleculeCycle* InCycle) {
	if (InCycle->Class == UNKNOWN) {
		if (InCycle->CycleAtoms.size() > 6 || InCycle->CycleAtoms.size() < 5) {
			InCycle->Class = NONE;
			return;
		}		
		InCycle->Class = TESTING;
		for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
			InCycle->CycleAtoms[i]->SetMark(false);
		}
		if (InCycle->CycleAtoms.size() == 5) {
			//First I check to see if there are two double bonds in the ring or fused aromatic rings
			int NumberDoubleBonds = 0;
			int NumSingleHeteroAtoms =0;
			for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
				if (!InCycle->CycleAtoms[i]->FMark()) {
					int Prev = i-1;
					if (Prev == -1) {
						Prev = int(InCycle->CycleAtoms.size()-1);
					}
					int Next = i+1;
					if (Next == int(InCycle->CycleAtoms.size())) {
						Next = 0;
					}
					if (InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Next]) == 2) {
						InCycle->CycleAtoms[i]->SetMark(true);
						InCycle->CycleAtoms[Next]->SetMark(true);
						NumberDoubleBonds++;
					} else if (InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Prev]) == 2) {
						InCycle->CycleAtoms[i]->SetMark(true);
						InCycle->CycleAtoms[Prev]->SetMark(true);
						NumberDoubleBonds++;
					} else if (InCycle->FusedCycles[i] != NULL) {
						if (InCycle->FusedCycles[i]->Class == UNKNOWN) {
							NewClassifyRing(InCycle->FusedCycles[i]);
						} 
						if (InCycle->FusedCycles[i]->Class == HETERO || InCycle->FusedCycles[i]->Class == BENZENE) {
							InCycle->CycleAtoms[i]->SetMark(true);
							InCycle->CycleAtoms[Next]->SetMark(true);
							NumberDoubleBonds++;	
						} else if (InCycle->CycleAtoms[i]->FType()->FID().compare("N") == 0) {
							bool InvolvedInDoubleBonds = false;
							for (int j=0; j < InCycle->CycleAtoms[i]->FNumBonds(); j++) {
								if (InCycle->CycleAtoms[i]->GetBondOrder(j) == 2) {
									InvolvedInDoubleBonds = true;
								}
							}
							if (!InvolvedInDoubleBonds && InCycle->CycleAtoms[i]->FNumBonds() < 4) {
								NumSingleHeteroAtoms++;
								InCycle->CycleAtoms[i]->SetMark(true);
								if (NumSingleHeteroAtoms > 1) {
									InCycle->Class = NONE;
									return;
								}
							}
						} else {
							InCycle->Class = NONE;
							return;
						}
					} else if (InCycle->FusedCycles[Prev] != NULL) {
						if (InCycle->FusedCycles[Prev]->Class == UNKNOWN) {
							NewClassifyRing(InCycle->FusedCycles[Prev]);
						} 
						if (InCycle->FusedCycles[Prev]->Class == HETERO || InCycle->FusedCycles[Prev]->Class == BENZENE) {
							InCycle->CycleAtoms[i]->SetMark(true);
							InCycle->CycleAtoms[Prev]->SetMark(true);
							NumberDoubleBonds++;	
						} else if (InCycle->CycleAtoms[i]->FType()->FID().compare("N") == 0) {
							bool InvolvedInDoubleBonds = false;
							for (int j=0; j < InCycle->CycleAtoms[i]->FNumBonds(); j++) {
								if (InCycle->CycleAtoms[i]->GetBondOrder(j) == 2) {
									InvolvedInDoubleBonds = true;
								}
							}
							if (!InvolvedInDoubleBonds && InCycle->CycleAtoms[i]->FNumBonds() < 4) {
								NumSingleHeteroAtoms++;
								InCycle->CycleAtoms[i]->SetMark(true);
								if (NumSingleHeteroAtoms > 1) {
									InCycle->Class = NONE;
									return;
								}
							}
						} else {
							InCycle->Class = NONE;
							return;
						}
					} else if (InCycle->CycleAtoms[i]->FType()->FID().compare("N") == 0) {
						bool InvolvedInDoubleBonds = false;
						for (int j=0; j < InCycle->CycleAtoms[i]->FNumBonds(); j++) {
							if (InCycle->CycleAtoms[i]->GetBondOrder(j) == 2) {
								InvolvedInDoubleBonds = true;
							}
						}
						if (!InvolvedInDoubleBonds && InCycle->CycleAtoms[i]->FNumBonds() < 4) {
							NumSingleHeteroAtoms++;
							InCycle->CycleAtoms[i]->SetMark(true);
							if (NumSingleHeteroAtoms > 1) {
								InCycle->Class = NONE;
								return;
							}
						}
					} else if (InCycle->CycleAtoms[i]->FType()->FID().compare("O") == 0 || InCycle->CycleAtoms[i]->FType()->FID().compare("S") == 0) {
						NumSingleHeteroAtoms++;
						InCycle->CycleAtoms[i]->SetMark(true);
						if (NumSingleHeteroAtoms > 1) {
							InCycle->Class = NONE;
							return;
						}
					} else {
						InCycle->Class = NONE;
						return;
					}
				}
			}
			if (NumSingleHeteroAtoms == 1 && NumberDoubleBonds == 2) {
				InCycle->Class = HETERO;
				return;
			}
		} else {
			//In six member rings, I'm only classifying rings with three double bonds (or two double bonds and fused to an aromatic ring) as heteroaromatic
			int NumberDoubleBonds = 0;
			int NumHeteroAtoms =0;
			for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
				if (InCycle->CycleAtoms[i]->FType()->FID().compare("C") != 0) {
					NumHeteroAtoms++;
				}
				if (!InCycle->CycleAtoms[i]->FMark()) {
					int Prev = i-1;
					if (Prev == -1) {
						Prev = int(InCycle->CycleAtoms.size()-1);
					}
					int Next = i+1;
					if (Next == int(InCycle->CycleAtoms.size())) {
						Next = 0;
					}
					if (InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Next]) == 2) {
						InCycle->CycleAtoms[i]->SetMark(true);
						InCycle->CycleAtoms[Next]->SetMark(true);
						NumberDoubleBonds++;
					} else if (InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Prev]) == 2) {
						InCycle->CycleAtoms[i]->SetMark(true);
						InCycle->CycleAtoms[Prev]->SetMark(true);
						NumberDoubleBonds++;
					} else if (InCycle->FusedCycles[i] != NULL) {
						if (InCycle->FusedCycles[i]->Class == UNKNOWN) {
							NewClassifyRing(InCycle->FusedCycles[i]);
						} 
						if (InCycle->FusedCycles[i]->Class == HETERO || InCycle->FusedCycles[i]->Class == BENZENE) {
							InCycle->CycleAtoms[i]->SetMark(true);
							InCycle->CycleAtoms[Next]->SetMark(true);
							NumberDoubleBonds++;	
						} else {
							InCycle->Class = NONE;
							return;
						}
					} else if (InCycle->FusedCycles[Prev] != NULL) {
						if (InCycle->FusedCycles[Prev]->Class == UNKNOWN) {
							NewClassifyRing(InCycle->FusedCycles[Prev]);
						} 
						if (InCycle->FusedCycles[Prev]->Class == HETERO || InCycle->FusedCycles[Prev]->Class == BENZENE) {
							InCycle->CycleAtoms[i]->SetMark(true);
							InCycle->CycleAtoms[Prev]->SetMark(true);
							NumberDoubleBonds++;	
						} else {
							InCycle->Class = NONE;
							return;
						}
					} else {
						InCycle->Class = NONE;
						return;
					}
				}
			}
			if (NumberDoubleBonds == 3) {
				if (NumHeteroAtoms > 0) {
					InCycle->Class = HETERO;
				} else {
					InCycle->Class = BENZENE;
				}
			}	
		}	
	}
}//End void ClassifyRing(MoleculeCycle* InCycle)

void NewNewClassifyRing(MoleculeCycle* InCycle) {
	if (InCycle->Class != UNKNOWN) {
		return;
	}
	if (InCycle->CycleAtoms.size() > 6 || InCycle->CycleAtoms.size() < 5) {
		InCycle->Class = NONE;
		InCycle->PieElectrons = 0;
		return;
	}
	bool Hetero = false;
	InCycle->Class = TESTING;
	InCycle->PieElectrons = 0;
	bool* Mark = new bool[InCycle->CycleAtoms.size()];
	for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
		Mark[i] = false;
	}
	for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
		//First I check to see if the current atom is a hetero atom
		if (InCycle->CycleAtoms[i]->FType()->FID().compare("C") != 0) {
			Hetero = true;
		}
		//Next I determine the indecies of the next and previous atom in the cycle
		int Prev = i-1;
		if (Prev == -1) {
			Prev = int(InCycle->CycleAtoms.size()-1);
		}
		int Next = i+1;
		if (Next == int(InCycle->CycleAtoms.size())) {
			Next = 0;
		}
		//Now I look for double bonds inside the cycle
		if (!Mark[i] && !Mark[Prev] && InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Prev]) == 2) {
			InCycle->PieElectrons += 2;
			Mark[i] = true;
			Mark[Prev] = true;
		} else if (!Mark[i] && !Mark[Next] && InCycle->CycleAtoms[i]->GetBondOrder(InCycle->CycleAtoms[Next]) == 2) {
			InCycle->PieElectrons += 2;
			Mark[i] = true;
			Mark[Next] = true;
		} else if (!Mark[i] && (InCycle->CycleAtoms[i]->FType()->FID().compare("S") == 0 || InCycle->CycleAtoms[i]->FType()->FID().compare("O") == 0)) {
			Mark[i] = true;
			InCycle->PieElectrons += 2;
		} else if (!Mark[i] && InCycle->CycleAtoms[i]->FType()->FID().compare("N") == 0) {
			bool DblFound = false;
			for (int j=0; j < InCycle->CycleAtoms[i]->FNumBonds(); j++) {
				if (InCycle->CycleAtoms[i]->GetBondOrder(j) == 2) {
					DblFound = true;
					j = InCycle->CycleAtoms[i]->FNumBonds();
				}
			}
			if (!DblFound) {
				Mark[i] = true;
				InCycle->PieElectrons += 2;
			}
		}
	}
	for (int i=0; i < int(InCycle->CycleAtoms.size()); i++) {
		int Prev = i-1;
		if (Prev == -1) {
			Prev = int(InCycle->CycleAtoms.size()-1);
		}
		int Next = i+1;
		if (Next == int(InCycle->CycleAtoms.size())) {
			Next = 0;
		}
		if (!Mark[i] && !Mark[Next]) {
			if (InCycle->FusedCycles[i] != NULL && InCycle->FusedCycles[i]->Class == UNKNOWN) {
				NewClassifyRing(InCycle->FusedCycles[i]);
			}
			if (InCycle->FusedCycles[i] != NULL && (InCycle->FusedCycles[i]->Class == HETERO || InCycle->FusedCycles[i]->Class == BENZENE)) {
				Mark[i] = true;
				Mark[Prev] = true;
				InCycle->PieElectrons += 2;
			}	
		}
	}

	if (!Hetero && InCycle->PieElectrons == 6) {
		InCycle->Class = BENZENE;
	} else if (InCycle->PieElectrons == 6) {
		InCycle->Class = HETERO;
	} else {
		InCycle->Class = NONE;
	}
				
	delete [] Mark;
}//End void ClassifyRing(MoleculeCycle* InCycle)

bool HuckelNumber(int InPieElect) {
	if (InPieElect == 0 || InPieElect == 2) {
		return false;
	}
	if ((InPieElect-2)%4 == 0) {
		return true;
	}
	return false;
}
