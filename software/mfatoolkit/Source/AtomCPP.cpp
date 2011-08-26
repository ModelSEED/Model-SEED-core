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

//Constructor
AtomCPP::AtomCPP(AtomType* InType, int InIndex, Species* InSpecies){
	Type = InType;
	Index = InIndex;
	Owner = InSpecies;
	Mark = false;
	Labeled = false;
	ParentID = -1;
	CycleID = 0;
	GroupIndex = 0;
	Group = 255;
	NonbondedElectrons = 0;
	Charge = 0;
	Code = NULL;
	Radical = 0;
};

void AtomCPP::ReplicateBonds(AtomCPP* InAtom, Species* InSpecies) {
	//This function is designed to replicate this atom's bond structure in a copy atom in another molecular structure
	//This is essential for cloning the molecular structure
	for (int i =0; i < InAtom->FNumBonds(); i++) {
		ChangeBondOrder(InSpecies->GetAtom(InAtom->GetBond(i)->FIndex()),InAtom->GetBondOrder(i));
	}
	CalculateCharge();
};

void AtomCPP::Clone(AtomCPP* InAtom, Species* InSpecies) {
	//This function is designed to make an exact copy of all data stored in the argutment atom
	Index = InAtom->FIndex();
	Owner = InSpecies;
	Mark = false;
	Labeled = false;
	ParentID = InAtom->FParentID();
	CycleID = InAtom->FCycleID();
	GroupIndex = InAtom->FGroupIndex();
	Group = InAtom->FGroup();
	Charge = InAtom->FCharge();
	NonbondedElectrons = InAtom->FNonbondedElectrons();
	Type = InAtom->FType();
	Code = NULL;
	Radical = InAtom->FRadical();
};

AtomCPP::~AtomCPP(){
	//Atom destructor: no deletion are necessary as there is no dynamically stored data
	if (Code != NULL) {
		delete Code;
	}
};

//Input
void AtomCPP::ChangeBondOrder(AtomCPP* InAtom, int BondOrderChange){
	//Rather than have a deletebond or create bond command, all is handled with the change bond order command.
	for (int i=0; i < FNumBonds(); i++) {
		if (Bonds[i] == InAtom) {
			if ((BondOrders[i].Order + BondOrderChange) < 4) {
				BondOrders[i].Order = BondOrders[i].Order + BondOrderChange;
			}
			else {
				BondOrders[i].Order = 3;
			}
			if (BondOrders[i].Order <= 0) {
				Bonds.erase(Bonds.begin()+i, Bonds.begin()+i+1);
				BondOrders.erase(BondOrders.begin()+i, BondOrders.begin()+i+1);
			}
			return;
		}
	}
	if (BondOrderChange > 0) {
		BondOrder NewBondOrder;
		if (BondOrderChange < 4) {
			NewBondOrder.Order = BondOrderChange;
		}
		else {
			NewBondOrder.Order = 3;
		}

		Bonds.push_back(InAtom);
		BondOrders.push_back(NewBondOrder);
	}
}

void AtomCPP::SetIndex(int InIndex){
	Index = InIndex;
}

void AtomCPP::SetCanonicalIndex(int InIndex){
	CanonicalIndex = InIndex;
}

void AtomCPP::SetMark(bool InMark){
	Mark = InMark;
}

//Output
int AtomCPP::FIndex() {
	return int(Index);
};

int AtomCPP::FCanonicalIndex() {
	return int(CanonicalIndex);
};

int AtomCPP::FNumBonds(){
	return int(Bonds.size());
};

AtomCPP* AtomCPP::GetBond(int InIndex){
	return Bonds[InIndex];
};

int AtomCPP::GetBondOrder(int InIndex){
	return int(BondOrders[InIndex].Order);
};

bool AtomCPP::FMark() {
	return Mark;
};

bool AtomCPP::FLabeled() {
	return Labeled;	
};

AtomType* AtomCPP::FType(){
	return Type;
};

Species* AtomCPP::FOwner() {
	return Owner;
}

int AtomCPP::FCycleID(){
	return CycleID;
};

int AtomCPP::FGroupIndex(){
	return int(GroupIndex);
};

long long AtomCPP::FParentID(){
	return ParentID;
};

int AtomCPP::FGroup(){
	return int(Group);
};

string AtomCPP::FGroupString() {
	if (Labeled) {
		return FOwner()->FMainData()->FindStructuralCue("ENTRY",itoa(FGroup()))->GetData("NAME",STRING);
	}
	else {
		string Temp("NoGroup");
		return Temp;
	}
};

int AtomCPP::FNonbondedElectrons(){
	return int(NonbondedElectrons);
};

int AtomCPP::FCharge(){
	return int(Charge);
};

int AtomCPP::FRadical() {
	return int(Radical);
};

//Manipulation
void AtomCPP::Explore() {
	//This just explores the network marking all atoms connected to this atom by at least one path
	//This is used to determine if a compound has broken into two separate molecules during a reaction
	Mark = true;
	for(int i=0; i < FNumBonds(); i++) {
		if (GetBond(i)->FMark() == false) {
			GetBond(i)->Explore();
		}
	}
};

void AtomCPP::ClearBonds() {
	//Erase bonds from this atom to other atoms and from other atoms to this atom
	int i;
	for (i=FNumBonds()-1; i >= 0 ; i--) {
		AtomCPP* Temp = GetBond(i);
		int BondOrder = GetBondOrder(i);
		ChangeBondOrder(Temp, -BondOrder);
		Temp->ChangeBondOrder(this,-BondOrder);
	}
}

void AtomCPP::InterpretCycleString(string InCycleData) {
	//This functions takes in the cycle data string and turns it into the cycle ID number.
	//This is important to interpret cycle data stored in the operator and substructure flat files
	CycleID = 0;
	if (InCycleData.compare("0") == 0) {
		return;
	}
	
	int Benzene = 0;
	int Nonbenzene = 0;
	int Fused = 0;
	int SixMember = 0;
	int FiveMember = 0;
	int FourMember = 0;
	int Hetero = 0;
	int MoreThanSix = 0;
	
	vector<string>* CycleTypes = StringToStrings(InCycleData,";");
	for (int i =0;i < int(CycleTypes->size()); i++) {
		if ((*CycleTypes)[i].substr(0,1).compare("B") == 0) {
			Benzene = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("N") == 0) {
			Nonbenzene = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("F") == 0) {
			Fused = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("6") == 0) {
			SixMember = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("5") == 0) {
			FiveMember = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("4") == 0) {
			FourMember = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("H") == 0) {
			Hetero = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("L") == 0) {
			MoreThanSix = atoi((*CycleTypes)[i].substr(1,(*CycleTypes)[i].length()-1).data());
		}
		else if ((*CycleTypes)[i].substr(0,1).compare("W") == 0) {
			Benzene = 9;
			Nonbenzene = 9;
			Fused = 9;
			SixMember = 9;
			FiveMember = 9;
			FourMember = 9;
			Hetero = 9;
			MoreThanSix = 9;
		}
	}
	delete CycleTypes;

	CycleID += 10000000*Benzene;
	CycleID += 1000000*Nonbenzene;
	CycleID += 100000*Fused;
	CycleID += 10000*SixMember;
	CycleID += 1000*FiveMember;
	CycleID += 100*FourMember;
	CycleID += 10*Hetero;
	CycleID += MoreThanSix;
}

int AtomCPP::FTotalBondOrder() {
	//Sums up all of the bondorders to get the total bond order.
	int NetBonds = 0;
	for (int i=0; i < FNumBonds(); i++) {
		NetBonds += BondOrders[i].Order;
	}
	return NetBonds;
}

void AtomCPP::CalculateCharge() {
	//Uses the  expected bond number stored in the atomtype class to determine the charge on the atom
	int NetBonds = FTotalBondOrder();
	
	if (Type->FID().compare("CoA") == 0) {
		Charge = -3;
		return;
	}

	if (Owner->FNumAtoms() == 1) { 
		if (Type->FID().compare("H") == 0) {
			Charge = 1;
		}
		return;
	}

	if (Type->FID().compare("H") == 0) {
		Charge = 1 - NetBonds;
	} else if (Type->FID().compare("Fe") == 0) {
		return;
	} else if (Type->FID().compare("Co") == 0) {
		return;
	} else if (Type->FID().compare("H+") == 0) {
		Charge = 1;
	} else {
		Charge = NetBonds - Type->FExpectedBondNumber(NetBonds) + Radical;
	}	
};

void AtomCPP::SetGroupData(int InGroup, int InGroupAtom) {
	//Stores data about what molecular substructure this atom belongs to 
	Group = InGroup;
	GroupIndex = InGroupAtom;
}

void AtomCPP::SetGroupData(string InGroup, int InGroupAtom) {
	//Stores data about what molecular substructure this atom belongs to from the group name which is reinterpreted into an integer using the database
	Species* NamedGroup = Owner->FMainData()->FindStructuralCue("NAME;DATABASE;ENTRY",InGroup.data());
	if (NamedGroup == NULL) {
		Group = NO_GROUP;
		GroupIndex = 0;
	}
	else {
		GroupIndex = InGroupAtom;
		Group = NamedGroup->FEntry();
	}
}

void AtomCPP::SetCycleID(int InID) {
	CycleID = InID;
}

void AtomCPP::SetCharge(int InCharge) {
	Charge = InCharge;
}

void AtomCPP::SetRadical(int InRadical) {
	Radical = InRadical;
}

void AtomCPP::SetType(AtomType* InType) {
	Type = InType;
}

int AtomCPP::GetBondOrder(AtomCPP* InAtom) {
	//Returns the order of the bond between this atom and inatom.
	for (int i = 0; i < FNumBonds(); i++) {
		if (InAtom == GetBond(i)) {
			return GetBondOrder(i);
		}	
	}
	return 0;
}

void AtomCPP::SetOwner(Species* InSpecies) {
	Owner = InSpecies;
}

void AtomCPP::AddCycle(int CycleType) {
	CycleID += int(pow(10,double(CycleType-1)));
}

void AtomCPP::SetParentID(long long InParentID) {
	ParentID = InParentID;
}

void AtomCPP::SetLabeled(bool InLabeled) {
	Labeled = InLabeled;
}

void AtomCPP::FillOutH(AtomType* HType) {
	//Molfiles donot contain hydrogens, but they do contain charges. This fills out the hydrogens based on the charge of the molecule
	int NetBonds = FTotalBondOrder();
	int NumHNeeded = 0;
	
	if (Type->FID().compare("H") == 0) {
		NumHNeeded = 1 - Charge - NetBonds;
	}
	if (Type->FID().compare("Fe") == 0) {
		return;
	}
	if (Type->FID().compare("Co") == 0) {
		return;
	}
	else {
		NumHNeeded = Type->FExpectedBondNumber(NetBonds) + Charge - NetBonds - Radical;
	}

	for (int i=0 ; i < NumHNeeded; i++) {
		AtomCPP* NewH = new AtomCPP(HType, Owner->FNumAtoms(), Owner);
		ChangeBondOrder(NewH,1);
		NewH->ChangeBondOrder(this,1);
		Owner->AddAtom(NewH);
	}
}

MatchConfiguration* AtomCPP::MatchAtom(AtomCPP* InAtom) {
	//This function is responsible for substructure search. It determines if the input atom has exactly the same structure as this atom.
	int i,j;

	//Atomtypes donot have to match exactly since there are wildcards in the atomtype.
	if (!FType()->CompareType(InAtom->FType())) {
		//Cannot be a match if the atomtypes conflict
		return NULL;
	}

	//Cycle IDs donot have to be the same since there are wildcards in the cycleID
	if (!MatchCycleID(InAtom->FCycleID())) {
		//Cannot be a match if the cycle IDs conflict
		return NULL;	
	}

	//If the input atom has no bonds that have not already been matched and this atom is a match, then this portion of the substructure matches.
	MatchConfiguration* MyConfig = new MatchConfiguration;
	MyConfig->MatchingAtom = InAtom;
	if (InAtom->FNumBonds() == 0 || (InAtom->FNumBonds() == 1 && InAtom->GetBond(0)->FMark() == true)) {
		MyConfig->Children = NULL;
		return MyConfig;
	}

	if (InAtom->FNumBonds() != FNumBonds() && InAtom->FCharge() == FCharge()) {
		//If the charges are equal and the number of distinct bonds are not, there can be no match.
		delete MyConfig;
		return NULL;
	}

	//I deal with hydrogens first
	//I breakdown hydrogens into four types: "add H atoms" meaning they do not need to be present, but should be added if they are not present,
	//"remove H atoms" meaning they should be removed if they are present, "wild H atoms" meaning the atom in the substructure could be H or some other atomtype, and 
	//"other H atoms" which are essential and must be present for a match to exist.
	vector<AtomCPP*> OtherHAtoms;
	vector<AtomCPP*> AddHAtoms;
	vector<AtomCPP*> RemoveHAtoms;
	vector<AtomCPP*> WildHAtoms;
	int NumNonH = 0;
	int NumWildH = 0;
	for (i = 0; i < InAtom->FNumBonds(); i++) {
		if (InAtom->GetBond(i)->FType()->FID().compare("H") == 0) {
			if (InAtom->GetBond(i)->FParentID() == HYDROGEN_TO_ADD) {
				AddHAtoms.push_back(InAtom->GetBond(i));
			}
			if (InAtom->GetBond(i)->FParentID() == HYDROGEN_TO_REMOVE) {
				RemoveHAtoms.push_back(InAtom->GetBond(i));
			}
			if (InAtom->GetBond(i)->FParentID() == ESSENTIAL_HYDROGEN || InAtom->GetBond(i)->FParentID() == 0) {
				OtherHAtoms.push_back(InAtom->GetBond(i));
			}
		}
		else if (InAtom->GetBond(i)->FType()->HAlternative()) {
			WildHAtoms.push_back(InAtom->GetBond(i));
			NumWildH++;
		}
		else {
			NumNonH++;
		}
	}

	//Now I search for matches to all of the different types of H atoms 
	bool Failed = false;
	MyConfig->Children = new MatchConfiguration*[FNumBonds()];
	MyConfig->NumChildren = FNumBonds();
	vector<AtomCPP*> MarkedWilds;
	for (i = 0; i < FNumBonds(); i++) {
		MyConfig->Children[i] = NULL;
		if (GetBond(i)->FType()->FID().compare("H") == 0) {
			//Essential H atoms are matched first
			if (OtherHAtoms.size() > 0) {
				MyConfig->Children[i] = new MatchConfiguration;
				MyConfig->Children[i]->MatchingAtom = OtherHAtoms.back();
				MyConfig->Children[i]->Children = NULL;
				OtherHAtoms.pop_back();
			}
			//H atoms to add are matched second since they will not need to be added if they are present.
			else if (AddHAtoms.size() > 0) {
				MyConfig->Children[i] = new MatchConfiguration;
				MyConfig->Children[i]->MatchingAtom = AddHAtoms.back();
				MyConfig->Children[i]->Children = NULL;
				AddHAtoms.pop_back();
			}
			//H atoms to remove are matched third.
			else if (RemoveHAtoms.size() > 0) {
				MyConfig->Children[i] = new MatchConfiguration;
				MyConfig->Children[i]->MatchingAtom = RemoveHAtoms.back();
				MyConfig->Children[i]->Children = NULL;
				RemoveHAtoms.pop_back();
			}
			//wild H atoms are matched last.
			else if (WildHAtoms.size() > 0) {
				MyConfig->Children[i] = new MatchConfiguration;
				MyConfig->Children[i]->MatchingAtom = WildHAtoms.back();
				MyConfig->Children[i]->MatchingAtom->SetMark(true);
				MarkedWilds.push_back(MyConfig->Children[i]->MatchingAtom);
				MyConfig->Children[i]->Children = NULL;
				WildHAtoms.pop_back();
			}
			//If all substructure H atoms are exhausted and still more H atoms exist on this atom, then this is not a match
			else {
				//Too many hydrogens on this atom for this to be a match
				Failed = true;
			}
		}
		else {
			//I also check to make sure number of nonH atoms are a match.
			if (NumNonH > 0) {
				NumNonH--;
			}
			else if (NumWildH > 0) {
				NumWildH--;
			}
			else {
				//Bonded to too many non-hydrogen atoms
				Failed = true;
			}
		}
	}

	//If some essential H atoms have not been matched, this cannot be a match
	if (OtherHAtoms.size() > 0) {
		//Not enough hydrogen atoms
		Failed = true;
	}
	
	if (Failed == false) {
		//If the algorithm reaches this point, then the atom has the appropriate cycle, type, and number of hydrogens.
		SetMark(true);
		InAtom->SetMark(true);
		MatchConfiguration*** MatchingPairs = new MatchConfiguration**[FNumBonds()];
		//I create a matrix of the bonds on the substructure atom and this atom that match. NULL elements in the matrix signify no match or a hydrogen or marked atom.
		for (i = 0; i < FNumBonds(); i++) {
			if (MyConfig->Children[i] == NULL && GetBond(i)->FMark() == false) {
				MatchingPairs[i] = new MatchConfiguration*[InAtom->FNumBonds()];
				for (j = 0; j < InAtom->FNumBonds(); j++) {
					if (InAtom->GetBond(j)->FType()->FID().compare("H") == 0 || InAtom->GetBond(j)->FMark() == true || (InAtom->GetBond(j)->FGroupIndex() != 255 && GetBond(i)->FLabeled())) {
						MatchingPairs[i][j] = NULL;
					}
					else {
						if (GetBondOrder(i) == InAtom->GetBondOrder(j)) {
							MatchingPairs[i][j] = GetBond(i)->MatchAtom(InAtom->GetBond(j));	
						}
						else {
							MatchingPairs[i][j] = NULL;
						}
					}
				}
			}
			else {
				MatchingPairs[i] = NULL;
			}
		}
		
		int* Config = new int[InAtom->FNumBonds()];
		for (j = 0; j < InAtom->FNumBonds(); j++) {
			Config[j] = 0;
		}
		int CurrentChild = 0;
		bool Problem = false;
		//Now I look for an arrangement where every bond in this atom and the substructure atom has a matching partner (non-NULL matrix element). This is the match configuration.
		do {
			if (InAtom->GetBond(CurrentChild)->FType()->FID().compare("H") == 0 || InAtom->GetBond(CurrentChild)->FMark() == true) {
				Config[CurrentChild] = -1;
				CurrentChild++;
			}
			else {
				Problem = false;
				do {
					Problem = false;
					for (j = 0; j < CurrentChild; j++) {
						if (Config[j] == Config[CurrentChild]) {
							Config[CurrentChild]++;
							Problem = true;
						}
					}
				} while(Problem == true && Config[CurrentChild] < FNumBonds());
				Problem = false;
				if (Config[CurrentChild] >= FNumBonds()) {
					if (CurrentChild == 0) {
						Failed = true;
					}
					else {
						for (j = CurrentChild; j < InAtom->FNumBonds(); j++) {
							Config[j] = 0;
						}
						CurrentChild--;
						for (j = CurrentChild; j >= 0; j--) {
							if (Config[j] != -1) {
								Config[j]++;
								CurrentChild = j;
								j = -2;
							}
						}
						if (j == -1) {
							Failed = true;
						}
					}
				}
				else if (GetBond(Config[CurrentChild])->FType()->FID().compare("H") == 0 || GetBond(Config[CurrentChild])->FMark() == true || MatchingPairs[Config[CurrentChild]][CurrentChild] == NULL) {
					Config[CurrentChild]++;
				}
				else {
					CurrentChild++;
				}
			}
		} while (CurrentChild < InAtom->FNumBonds() && Failed == false);
	
		//If I didn't fail, then I found a working configuration and I should load the config
		if (Failed == false) {
			for (i = 0; i < InAtom->FNumBonds(); i++) {
				if (Config[i] != -1) {
					MyConfig->Children[Config[i]] = MatchingPairs[Config[i]][i];
					//I set this to NULL so I don't accidentally delete this config later
					MatchingPairs[Config[i]][i] = NULL;
				}
			}	
		}
		delete [] Config;

		//I'm leaving this function now, so this node should no longer be marked
		SetMark(false);
		InAtom->SetMark(false);
		
		//I must delete all the matching configs I don't use
		for (i = 0; i < FNumBonds(); i++) {
			if (MatchingPairs[i] != NULL) {
				for (j = 0; j < InAtom->FNumBonds(); j++) {
					if (MatchingPairs[i][j] != NULL) {
						DeleteMatchingConfig(MatchingPairs[i][j]);
					}
				}
				delete [] MatchingPairs[i];
			}
		}
		delete [] MatchingPairs;
		
		for (i=0; i < int(MarkedWilds.size()); i++) {
			MarkedWilds[i]->SetMark(false);
		}
		
		//If I found a working configuration, I return it
		if (Failed == false) {
			return MyConfig;
		}
	}

	//If I could not find a working configuration, I delete the configuration
	DeleteMatchingConfig(MyConfig);
	return NULL;
}

//This checks to see if this atom's cycle ID agrees with the input cycle ID allowing for differences only if wildcards are present.
bool AtomCPP::MatchCycleID(int InCycleID) {
	if (FCycleID() == InCycleID) {
		return true;
	}
	else {
		int IDOne = FCycleID();
		int IDTwo = InCycleID;
		for (int i=0; i < 8; i++) {
			int ModOne = IDOne%10;
			int ModTwo = IDTwo%10;
			if (ModOne != 9 && ModTwo != 9 && ModOne != ModTwo) {
				return false;
			}
			IDOne = int(IDOne/10);
			IDTwo = int(IDTwo/10);
		}
	}
	return true;
}

//This functions attempts to label the atom with the input substructure
bool AtomCPP::LabelAtoms(AtomCPP* InAtom) {
	MatchConfiguration* Config = MatchAtom(InAtom);
	if (Config == NULL) {
		return false;
	}
	
	LabelAtoms(Config);
	//Owner->SetMark(true);
	DeleteMatchingConfig(Config);
	return true;
}

string AtomCPP::FCode() {
	return *Code;
}

bool AtomCPP::FMemberOfAromaticRing() {
	if (ParseDigit(FCycleID(),BENZENE) > 0 || ParseDigit(FCycleID(),HETERO) > 0) {
		return true;
	}
	return false;
}

//This code is designed to take the matching configuration and label the atoms accordingly
//This is necessary to identify the atoms as belonging to a particular substructure
void AtomCPP::LabelAtoms(MatchConfiguration* InConfig) {
	if (InConfig->MatchingAtom->FGroupIndex() != 255) { 
		Group = InConfig->MatchingAtom->FGroup();
		GroupIndex = InConfig->MatchingAtom->FGroupIndex();
		SetLabeled(true);
	}
	for (int i=0; i < FNumBonds(); i++) {
		if (GetBond(i)->FLabeled() != true && InConfig->Children != NULL && InConfig->Children[i] != NULL) {
			GetBond(i)->LabelAtoms(InConfig->Children[i]);
		}
	}
}

//This function is required to properly read in smiles code. Bonds are not treated as aromatic, but explicitly single or double bonds.
//If the atom is involved in aromatic bonding, it will have been marked as true.
void AtomCPP::AromatizeBonds() {
	//If the atom is oxygen or sulfure, it cannot have a double bond and be aromatic.
	if (FType()->FID().compare("O") == 0 || FType()->FID().compare("S") == 0) {
		Mark = false;
	} else{
		//I check to see if this atom has a double bond already in which case it should not be changed
		for (int i=0; i < FNumBonds(); i++) {
			if (GetBondOrder(i) == 2) {
				//This atom is already aromatized
				Mark = false;
			}
		}
	}

	//Now I scan for marked aromatic nieghbors and either add a double bond if needed or tell the neighbors to aromatize their bonds
	for (int i=0; i < FNumBonds(); i++) {
		if (GetBond(i)->FMark()) {
			if(FMark() && GetBond(i)->FType()->FID().compare("O") != 0 && GetBond(i)->FType()->FID().compare("S") != 0) {
				//If the atom contains no double bonds, then I need to add a double bond between this atom and an aromatic nieghbor
				//Increase the bondorder by one to make the single bond a doulbe bond
				ChangeBondOrder(GetBond(i), 1);
				GetBond(i)->ChangeBondOrder(this,1);
				Mark = false;
			}
			GetBond(i)->AromatizeBonds();
		}
	}
}

//This function is responsible for producing the string code for this atom. It returns false if the atoms has multiple unmarked neighbors with the same parentID.
bool AtomCPP::MakeStringCode(bool CycleID, bool GroupData, bool FullyProtonate, bool DoubleBonds, bool Hydrogen, bool Charges, bool CisTrans, bool Stereo) {
	int NumUnmarked = 0;
	int NumHydrogen = 0;
	for (int i = 0; i < FNumBonds(); i++) {
		//I count the number of unmarked neighbor atoms
		if (!GetBond(i)->FMark()) {
			NumUnmarked++;
		}
		//I count the number of hydrogens
		if (GetBond(i)->FType()->FID().compare("H") == 0) {
			NumHydrogen++;
		}
	}

	if (NumUnmarked <= 1 || FParentID() != 0) {
		//This atom is ready to make it's stringcode, and there is no need to consider the parent I
		Code = new string;
		//First I append the data for this atom
		Code->append(FType()->FID());
		
		//Now I make adjust the number of hydrogens to make the atom full protonated if this is called for.
		int StringCodeCharge = Charge;
		if (FullyProtonate) {
			if (Charge > NumHydrogen) {
				NumHydrogen = 0;
				StringCodeCharge = Charge - NumHydrogen;
			}
			else {
				StringCodeCharge = 0;
				if (FType()->FID().compare("CoA") != 0) {
					NumHydrogen = NumHydrogen - Charge;
				}
			}
		}
		
		//Now I prepare and append the special data string according to the input boolean arguments
		string AdditionalData("[");
		if (Charges && StringCodeCharge != 0) {
			if (StringCodeCharge > 0) {
				AdditionalData.append("+");
				AdditionalData.append(itoa(StringCodeCharge));
			}
			else {
				AdditionalData.append(itoa(StringCodeCharge));
			}
		}
		if (CycleID && CycleID != 0) {
			AdditionalData.append("C");
			AdditionalData.append(itoa(CycleID));
		}
		if (GroupData && Labeled) {
			AdditionalData.append("G");
			AdditionalData.append(FGroupString());
			AdditionalData.append(",");
			AdditionalData.append(itoa(GroupIndex));
		}
		AdditionalData.append("]");
		//I don't bother appending the string if it contains no data
		if (AdditionalData.size() > 2) {
			Code->append(AdditionalData);
		}

		if (NumHydrogen > 0) {
			Code->append("H");
			if (NumHydrogen > 1) {
				Code->append(itoa(NumHydrogen));
			}
		}

		//Now I prepare and append the children strings
		string ChilddrenData("(");

		//Now I append the stringcodes of all marked children in alphabetical order
		bool* Appended = new bool[FNumBonds()];
		int NumToAppend = 0;
		for (int i = 0; i < FNumBonds(); i++) {
			if (GetBond(i)->FMark() && GetBond(i)->FType()->FID().compare("H") != 0) {
				Appended[i] = false;
				NumToAppend++;
			}
			else {
				Appended[i] = true;
			}
		}
		
		for (int j=0; j < NumToAppend; j++) {
			int Largest = -1;
			for (int i = 0; i < FNumBonds(); i++) {
				if (!Appended[i]) {
					if (Largest == -1 || GetBond(i)->FCode() > GetBond(Largest)->FCode()) {
						Largest = i;
					}
				}
			}
			if (GetBondOrder(Largest) == 2 && DoubleBonds) {
				ChilddrenData.append("=");
			}
			else if (GetBondOrder(Largest) == 3 && DoubleBonds) {
				ChilddrenData.append("#");
			}
			ChilddrenData.append(GetBond(Largest)->FCode().data());
			Appended[Largest] = true;
		}
	
		ChilddrenData.append(")");
		//I don't bother appending the string if it contains no data
		if (ChilddrenData.size() > 2) {
			Code->append(ChilddrenData);
		}

		delete [] Appended;
		//This atom's stringcode is now complete unless it contains unmarked neighbors
		return true;
	}

	//If the function reaches this point, then this atom is not ready to make its stringcode
	return false;
}
//END FUNCTION: bool MakeStringCode

//This code sets the canonical index of each non-biconnected component atom based on the order of appearance in the stringcode
int AtomCPP::IndexAtoms(int InputIndex) {
	//Setting the canonical index of this atom to the input index
	CanonicalIndex = InputIndex;
	
	//Calling the IndexAtoms() functions on all marked children in alphabetical order
	bool* Appended = new bool[FNumBonds()];
	int NumToAppend = 0;
	for (int i = 0; i < FNumBonds(); i++) {
		if (GetBond(i)->FCanonicalIndex() == -1 && GetBond(i)->FType()->FID().compare("H") != 0) {
			Appended[i] = false;
			NumToAppend++;
		} else {
			Appended[i] = true;
		}
	}
		
	for (int j=0; j < NumToAppend; j++) {
		int Largest = -1;
		for (int i = 0; i < FNumBonds(); i++) {
			if (!Appended[i] && (Largest == -1 || GetBond(i)->FCode() > GetBond(Largest)->FCode())) {
				Largest = i;
			}
		}
		
		InputIndex = GetBond(Largest)->IndexAtoms(InputIndex+1);
		
		Appended[Largest] = true;
	}

	delete [] Appended;
	return InputIndex;
}
//END FUNCTION: bool IndexAtoms

//This code sets the canonical index of each bioconnected component atom
int AtomCPP::MorganIndexAtoms(int InputIndex) {
	//Calling IndexAtoms() on this atom so this atom and all of this atom's children will be indexed
	InputIndex = IndexAtoms(InputIndex);
	
	//Now calling MorganIndexAtoms on the bioconnected component atoms that are attached to this atom
	int SmallestIndex = -1;
	do {
		SmallestIndex = -1;
		for (int i = 0; i < FNumBonds(); i++) {
			if (GetBond(i)->FCanonicalIndex() == -2 && (SmallestIndex == -1 || GetBond(SmallestIndex)->FParentID() > GetBond(i)->FParentID())) {
				SmallestIndex = i;
			}
		}
		if (SmallestIndex != -1) {
			InputIndex = GetBond(SmallestIndex)->MorganIndexAtoms(InputIndex+1);
		}
	} while (SmallestIndex != -1);	

	return InputIndex;
}
//END FUNCTION: bool MakeStringCode

//This code completes the stringcode for the final bioconnected component
string AtomCPP::MakeMorganStringCode(AtomCPP* CallingAtom) {
	SetMark(true);
	int SmallestIndex = -1;

	//Saving the original code so I can determine if a cycle closure has been added
	string OriginalCode(*Code);
	string CycleClosure("{");
	do {
		SmallestIndex = -1;
		for (int i = 0; i < FNumBonds(); i++) {
			if (!GetBond(i)->FLabeled() && GetBond(i)->FMark() && GetBond(i)->FParentID() != 0 && CallingAtom != GetBond(i) && (SmallestIndex == -1 || GetBond(SmallestIndex)->FParentID() > GetBond(i)->FParentID())) {
				SmallestIndex = i;
			}
		}
		if (SmallestIndex != -1) {
			if (CycleClosure.length() > 1) {
				CycleClosure.append(",");
			}
			CycleClosure.append(itoa(int(GetBond(SmallestIndex)->FParentID())));
			GetBond(SmallestIndex)->AddCycleClosure();
			GetBond(SmallestIndex)->SetLabeled(true);
		}
	} while (SmallestIndex != -1);
	CycleClosure.append("}");

	string Appendcode;
	do {
		SmallestIndex = -1;
		for (int i = 0; i < FNumBonds(); i++) {
			if (!GetBond(i)->FMark() && (SmallestIndex == -1 || GetBond(SmallestIndex)->FParentID() > GetBond(i)->FParentID())) {
				SmallestIndex = i;
			}
		}
		if (SmallestIndex != -1) {
			Appendcode.append(GetBond(SmallestIndex)->MakeMorganStringCode(this));
		}
	} while (SmallestIndex != -1);	

	if (Appendcode.length() > 0) {
		if (Code->substr(OriginalCode.length()-1,1).compare(")") == 0) {
			Code->insert(OriginalCode.length()-1,Appendcode);
		} else {
			Appendcode.insert(0,"(");
			Appendcode.append(")");
			Code->insert(OriginalCode.length(),Appendcode);
		}
	}

	if (CycleClosure.length() > 2) {
		Code->append(CycleClosure);
	}
	return (*Code);
}
//END FUNCTION: bool MakeStringCode

void AtomCPP::AddCycleClosure() {
	if (Code->substr(Code->length()-1,1).compare(">") != 0) {
		Code->append("<");
		Code->append(itoa(int(FParentID())));
		Code->append(">");
	}
}

void AtomCPP::DeleteCode() {
	if (Code != NULL) {
		delete Code;
		Code = NULL;
	}
}

unsigned long long AtomCPP::DeterminePrimaryIndex() {
	//I start with an integer that uniquely identifies the atom type equivalent to atomic number which is used in the stringcode papers
	 unsigned long long PrimaryIndex = (FType()->FIndex()*1e9);
	//this is the formal charge element of the primary index
	if (Charge > 0) {
		PrimaryIndex += (Charge*1e8);
	}
	if (Charge < 0) {
		PrimaryIndex += ((10+Charge)*1e8);
	}

	int NumDoubleBonds =0;
	int NumHydrogen = 0;
	for (int i=0; i < FNumBonds(); i++) {
		if (GetBond(i)->FType()->FID().compare("H") == 0) {
			NumHydrogen++;
		}
		if (GetBondOrder(i) == 2) {
			NumDoubleBonds++;
		}
	}

	PrimaryIndex += (NumDoubleBonds*1e7);
	//I'm leaving the nonbonding electron element off the list. I just don't see how this discriminates between atoms of the same type.
	PrimaryIndex += ((FNumBonds()-NumHydrogen)*1e6);
	PrimaryIndex += (NumHydrogen*1e5);
	//Here I use the parentID which is currently equal to the lexicographical rank
	//I provide 3 digits for this number
	PrimaryIndex += (ParentID*1e2);
	
	int NumThreeMember = ParseDigit(FCycleID(),NONBENZENE)-ParseDigit(FCycleID(),SIX_MEMBER)-ParseDigit(FCycleID(),FIVE_MEMBER)-ParseDigit(FCycleID(),FOUR_MEMBER);
	if (ParseDigit(FCycleID(),NONBENZENE) != 0 || ParseDigit(FCycleID(),BENZENE) != 0) {
		if (NumThreeMember > 0) {
			PrimaryIndex += 3*10;
		}
		else if (ParseDigit(FCycleID(),FOUR_MEMBER) > 0) {
			PrimaryIndex += 4*10;
		}
		else if (ParseDigit(FCycleID(),FIVE_MEMBER) > 0) {
			PrimaryIndex += 5*10;
		}
		else if (ParseDigit(FCycleID(),SIX_MEMBER) > 0 || ParseDigit(FCycleID(),BENZENE) > 0) {
			PrimaryIndex += 6*10;
		}
		else if ((FCycleID()%10) > 0) {
			PrimaryIndex += 9*10;
		}
	}
	//The number of connected neighbors is equal to the number of three member cycles.
	PrimaryIndex += NumThreeMember;

	return PrimaryIndex;
}

unsigned long long AtomCPP::DeterminSecondaryIndex() {
	unsigned long long SecondaryIndex = 0;

	SecondaryIndex = (pow(double(10),(SI_DIGITS-3))*ParentID);

	bool* Appended = new bool[FNumBonds()];
	int NumToAppend = 0;
	for (int i = 0; i < FNumBonds(); i++) {
		if (GetBond(i)->FParentID() != 0) {
			Appended[i] = false;
			NumToAppend++;
		}
		else {
			Appended[i] = true;
		}
	}
	
	for (int j=0; j < NumToAppend; j++) {
		int Smallest = -1;
		for (int i = 0; i < FNumBonds(); i++) {
			if (!Appended[i]) {
				if (Smallest == -1 || GetBond(i)->FParentID() < GetBond(Smallest)->FParentID()) {
					Smallest = i;
				}
			}
		}
		//Output error message if the double precision variable has insufficient digits.
		if ((SI_DIGITS-3*(j+2)) < 0) {
			FErrorFile() << "Too many bicomp neighbors for string code algorithm to handle for compound " << FOwner()->FEntry() << endl;
			FlushErrorFile();
		}
		SecondaryIndex += (pow(double(10),(SI_DIGITS-3*(j+2)))*GetBond(Smallest)->FParentID());
		Appended[Smallest] = true;
	}
	delete [] Appended;

	return SecondaryIndex;
}

void AtomCPP::Neutralize() {
	for (int i=(FNumBonds()-1); i >= 0; i--) {
		if (Charge > 0 && GetBond(i)->FType()->FID().compare("H") ==0) {
			AtomCPP* TempH = GetBond(i);
			ChangeBondOrder(TempH,-1);
			FOwner()->RemoveAtom(TempH->FIndex());
			delete TempH;
			Charge--;
		}
	}
}

//Deletes the configuration trees used in the group matching program
void DeleteMatchingConfig(MatchConfiguration* InConfig) {
	if (InConfig->Children != NULL) {
		for (int i=0; i < InConfig->NumChildren; i++) {
			if (InConfig->Children[i] != NULL) {
				DeleteMatchingConfig(InConfig->Children[i]);
			}
		}
		delete [] InConfig->Children;
	}
	delete InConfig;
}//End DeleteMatchingConfig
