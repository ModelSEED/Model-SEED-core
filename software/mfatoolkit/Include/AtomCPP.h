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

#ifndef ATOMCPP_H
#define ATOMCPP_H

class AtomType;
class MoleculeStructure;
class Species;
struct MatchConfiguration;

struct BondOrder {
	unsigned Order : 3;
};

class AtomCPP {
private:
	//Array of pointers to atoms this atom is bonded to
	vector<AtomCPP*> Bonds;
	//Array of bond orders of the bonds
	vector<BondOrder> BondOrders;

	//Charge on the atom
	signed Charge : 4;
	unsigned Radical : 4;
	//Index of the atom in the molecule
	unsigned Index : 12;
	//Canonical index of the atom in the molecule
	signed CanonicalIndex : 16;
	//Number of nonbonded electrons
	unsigned NonbondedElectrons : 4;
	//The index of the mavrovouniotis group to which this atom belongs
	unsigned Group : 16;
	//The index corresponding to this atom in the mavrovouniotis group
	unsigned GroupIndex : 8;
	//this datastructure holds all information about the cycles this atom participates in
	unsigned int CycleID;
	//Index of the parent of this atom
	long long ParentID;
	//A marker used when exploring the molecule
	bool Mark;
	//Flag indicating if the atom has been labeled as part of a substructure fingerprint
	bool Labeled;

	//A pointer to the molecule that this atom is a part of
	Species* Owner;
	//A pointer to the type of the atom (carbon, sulfur, etc.)
	AtomType* Type;
	//A pointer to a string where portions of the string code are stored as it's built
	string* Code;
public:
	AtomCPP(AtomType* InType, int InIndex, Species* InSpecies);
	~AtomCPP();
	
	void ReplicateBonds(AtomCPP* InAtom, Species* InSpecies);
	void Clone(AtomCPP* InAtom, Species* InSpecies);

	//Input
	void ChangeBondOrder(AtomCPP* InAtom, int BondOrderChange);
	void SetIndex(int InIndex);
	void SetCanonicalIndex(int InIndex);
	void SetMark(bool InMark);
	void SetGroupData(int InGroup, int InGroupAtom);
	void SetGroupData(string InGroup, int InGroupAtom);
	void SetCycleID(int InID);
	void SetCharge(int InCharge);
	void SetRadical(int InRadical);
	void SetType(AtomType* InType);
	void SetOwner(Species* InSpecies);
	void AddCycle(int CycleType);
	void SetParentID(long long InParentID);
	void SetLabeled(bool InLabeled);

	//Output
	int FNumBonds();
	int FTotalBondOrder();
	int FCharge();
	int FRadical();
	int FIndex();
	int FCanonicalIndex();
	bool FMark();
	AtomType* FType();
	Species* FOwner();
	AtomCPP* GetBond(int InIndex);
	int GetBondOrder(int InIndex);
	int GetBondOrder(AtomCPP* InAtom);
	int FNonbondedElectrons();
	int FGroup();
	string FGroupString();
	long long FParentID();
	int FGroupIndex();
	int FCycleID();
	bool FLabeled();
	MatchConfiguration* MatchAtom(AtomCPP* InAtom);
	bool MatchCycleID(int InCycleID);
	bool LabelAtoms(AtomCPP* InAtom);
	string FCode();
	bool FMemberOfAromaticRing();
	
	//Manipulation
	void Explore();
	void CalculateCharge();
	void FillOutH(AtomType* HType);
	void ClearBonds();
	void InterpretCycleString(string InCycleData);
	void LabelAtoms(MatchConfiguration* InConfig);
	void AromatizeBonds();
	bool MakeStringCode(bool CycleID, bool GroupData, bool FullyProtonate, bool DoubleBonds, bool Hydrogen, bool Charges, bool CisTrans, bool Stereo);
	string MakeMorganStringCode(AtomCPP* CallingAtom);
	void AddCycleClosure();
	void DeleteCode();
	unsigned long long DeterminePrimaryIndex();
	unsigned long long DeterminSecondaryIndex();
	void Neutralize();
	int IndexAtoms(int InputIndex);
	int MorganIndexAtoms(int InputIndex);
};

//This holds a possible match configuration for the substructure matching algorithm
struct MatchConfiguration {
	AtomCPP* MatchingAtom;
	int NumChildren;
	MatchConfiguration** Children;
};

//Deallocates the memmory associated with the match configuration structure.
void DeleteMatchingConfig(MatchConfiguration* InConfig);

#endif
