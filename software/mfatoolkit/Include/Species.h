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

#ifndef SPECIES_H
#define SPECIES_H

struct ChemGraph;
struct MoleculeCycle;
class Data;
class AtomCPP;

struct MFAVariable;
struct SpeciesCompartment;
struct CellCompartment;
struct OptSolutionData;

#include "Identity.h"

#define CPD_DBLINK 0
#define CPD_FORMULA 1
#define CPD_NEUTRAL_CHARGE 2
#define CPD_COFACTOR 3
#define CPD_DELTAG 4
#define CPD_DELTAGERR 5
#define CPD_MW 6
#define CPD_PKA 7
#define CPD_STRUCTURALCUES 8
#define CPD_DOUBLE 9
#define CPD_CUE 10
#define CPD_STRINGCODE 12
#define CPD_CHARGE 13
#define CPD_SMALLMOLEC 14
#define CPD_STRING 15
#define CPD_ERRORMSG 16
#define CPD_ALLDBLINKS 17
#define CPD_LOAD 18
#define CPD_PKB 19
#define CPD_QUERY 100

class Species : public Identity {
private:
	//Link to the main datastructure
	Data* MainData;

	//Data items typically read from file
	string Formula;
	int NuetralpHCharge;
	bool Cofactor;
	double EstDeltaG;
	double EstDeltaGUncertainty;
	double MolecWeight;

	//Molecule structure data
	vector<AtomCPP*> Atoms;

	//pKa data
	vector<double> pKa;
	vector<int> pKaAtoms;
	vector<double> pKb;
	vector<int> pKbAtoms;
	
	//Data items typically calculated
	int Charge;
	int NumHeteroRings;
	int ThreeMemberRings;
	int NumLargeCycles;
	int NumNoIDGroups;
	bool Coa;
	bool Cue;
	bool SmallMolec;

	vector<Species*> StructuralCues;
	vector<int> NumStructuralCues;
	vector<MoleculeCycle*> Cycles;
	list<Reaction*> ReactionList;

	vector<SpeciesCompartment*> CompartmentVector;
	map<int , MFAVariable* , std::less<int> > MFAVariables;
	map<int , SpeciesCompartment* , std::less<int> > Compartments;  
public:
	int PathwayMark;
	
	Species(vector<string>* InHeaders, string Fileline, Data* InData, bool InCue = false);
	Species(string InFilename, Data* InData, bool InCue = false);
	Species(int InEntry, int InIndex, Species* InSpecies, bool InCue = false);
	void SetDefaults();
	~Species();

	//Input
	void SetEstDeltaG(double InEnergy);
	void SetEstDeltaGUncertainty(double InError);
	void SetCoa(bool InCoa);
	void SetCue(bool InCue);
	void SetSmallMolec(bool InSmallMolec);
	void SetCharge(int InCharge);
	void SetNuetralpHCharge(int InCharge);
	void SetFormula(string InFormula);
	void SetMW(double InMass);
	void SetCofactor(bool InCofactor);
	void SetNumNoIDGroups(int InNum);
	void AddAtom(AtomCPP* InAtom);
	void AddReaction(Reaction* InReaction);
	void AddCompartment(int InCompartment);
	void AddpKab(string InpKaString, bool pKaInput);
	void AddpKab(double InpKa, int AtomNumber, bool pKaInput);
	void ResetAtomMarks(bool InMark = false);
	void CheckForCoa();
	void CopyData(Species* InSpecies);
	void ClearCycles();
	int ParseStructuralCueList(string InList);
	void AddStructuralCue(Species* InCue, double InCueCoef);
	void FillInTempStructuralCue();
	int ReadFromFileline(vector<string>* InHeaders, string Fileline);

	//Output
	double FEstDeltaG();
	double FEstDeltaGUncertainty();
	double FMolarWeight();
	bool FCofactor();
	bool FCue();
	bool FSmallMolec();
	string FFormula();
	int FCharge();
	double FMW();
	int FNuetralpHCharge();
	int FNumAtoms();
	int FNumNoIDGroups();
	AtomCPP* GetAtom(int InIndex);
	Data* FMainData();
	int FNumStructuralCues();
	Species* GetStructuralCue(int GroupIndex);
	int GetStructuralCueNum(int InIndex);
	int FNumNonHAtoms();
	AtomCPP* GetRootAtom();
	bool FCoa();
	int FNumReactions();
	multimap<Species*, Reaction*, std::less<Species*> >* GetNeighborMap(bool CofactorsIncluded);
	int CountAtomType(const char* ID);
	int GetCycleNum(int InCycleType);
	int FNumpKab(bool InpKa);
	double GetpKab(int InIndex, bool InpKa);
	AtomCPP* GetpKabAtom(int InIndex, bool InpKa);
	double FBindingPolynomial(double InpH, vector<double> pKaValues);
	double FRefHChange();
	string GetUnlabeledFormula();
	bool ContainsAtom(string ID);
	string CreateStructuralCueList();
	double GetMaxConcentration(const char* Compartment);
	double GetMinConcentration(const char* Compartment);
	string PrintRequestedDataToString(vector<string>* Headers);
	bool FExtracellular();
	list<Reaction*> GetReactionList();
	int FNumCompartments();
	SpeciesCompartment* GetSpeciesCompartment(int InIndex);
	vector<double> GetpKaValues();

	//Complex calculations
	double AdjustedDeltaG(double IonicStrength,double pH,double Temperature);
	vector<double> AdjustpKa(vector<double> pKa, double ionicStr, int spCharge);
	double AdjustpKa(double pKa, double ionicStr, int spCharge);
	void CalculateFormula();
	void ClearAtomList(bool Delete = false);
	void PerformAllCalculations(bool Decompose, bool FindStringCode, bool LookForCycles, bool CalcProperties, bool FindFormula);
	void CountStructuralCues();
	void CalculateEnergyFromGroups();
	void CalculateChargeFromGroups();
	void SetFormulaToNeutral();
	void CorrectStructuralCues();
	void RemoveAtom(int InIndex);
	void Reindex();
	void TranslateFormulaToAtoms();
	void ChangeNumHydrogen(int ChangeInH);
	string CreateStringcode(bool CycleID, bool GroupData, bool FullyProtonate = true, bool DoubleBonds = false, bool Hydrogen = true, bool Charges = true, bool CisTrans = false, bool Stereo = false);
	void MakeNeutral();
	void ReplaceCoAWithFullMolecule();
	void ReplaceFullCoAMoleculeWithCoAAtom();
	void CountConjugates();
	void CountVicinalChlorines();
	int CalculatePredominantIon(double InpH);
	bool PropagateMarks();

	//File Output
	int SaveSpecies(string Filename);
	void PrintMol(string InPath);
	string Query(string InDataName);

	//File Input
	int LoadSpecies(string Filename);
	int Interpreter(string DataName, string& DataItem, bool Input);
	void ReadStructure();
	void ReadFromMol(string Filename);
	void ReadFromMol(ifstream &Input);
	void ReadFromDat(string Filename);
	void ReadFromSmiles(string InSmiles);

	//Structure evaluating functions
	bool IsTree();
	void FindCyclesTwo();
	void FindCycles();
	void ReduceCycles();
	void CycleLabeling();
	void LabelAtoms();

	//Metabolic flux analysis functions
	void CreateMFAVariables(OptimizationParameter* InParameters);
	MFAVariable* CreateMFAVariable(int InType,int InCompartment,double Min, double Max);
	void UpdateBounds(int VarType, double Min, double Max, int Compartment = -1, bool ApplyToMinMax = false);
	void AddUseVariables(OptimizationParameter* InParameters);
	MFAVariable* GetMFAVar(int InType, int InCompartment = -1);
	void GetAllMFAVariables(vector<MFAVariable*>& InVector);
	void ClearMFAVariables(bool DeleteThem);
	vector<double> RetrieveData(int VarType,int VarCompartment,OptSolutionData* InSolution);
};

struct SpeciesCompartment {
	map<int , MFAVariable* , std::less<int> > MFAVariables;
	int Charge;
	CellCompartment* Compartment;
};

struct MoleculeCycle {
	//Holds the aromaticity information for the cycle
	int Class;
	//Holds the atoms in the cycle
	vector<AtomCPP*> CycleAtoms;
	//Holds a link to any ring fused to atoms i and i+1
	vector<MoleculeCycle*> FusedCycles;
	vector<int> FusedBonds;
	int PieElectrons;
	//A unique identification code for the cycle
	string CycleCode;
};

void NewClassifyRing(MoleculeCycle* InCycle);
void NewNewClassifyRing(MoleculeCycle* InCycle);
bool HuckelNumber(int InPieElect);


struct MoleculeExp {
	int* VisitedAtomPosition;
	int* PathwayList;
	int* CurrentBond;
	int Length;
};
/*
struct CycleExplorer {
	//This is a vector of all current Explorers
	vector<CycleExplorer*>* AllExplorers;
	
	//When multiple explorers must be carried, this contains information on the link to the master explorer
	CycleExplorer* MasterExplorer;
	int MasterLinkPosition;
	
	//For a master explorers, this is the link to the slave explorers
	map< CycleExplorer*, int, std::less<CycleExplorer*> > SlaveExplorers;

	//This is just a pointer to my geneology tree (see find cycle two function for an explanation)
	map< CycleExplorer*, map< CycleExplorer*, int, std::less<CycleExplorer*> >, std::less<CycleExplorer*> >* Geneology;

	//I track the last split position to determine if an explorer is obselete after a collision
	int LastSplitPosition;

	vector<int> BrotherExplorers;
	vector<int> BrotherPositions;
		
	vector<CycleExplorer*> Brothers;

	vector<int> IncludedAtomPaths;
	vector<AtomCPP*> SplittingPoints;
	vector<AtomCPP*> UnitingPoints;
	vector<int> IncludedAtomPaths;
	vector<double> IncludedAtomPosition;
	vector<int> BridgeStarts;
	vector<int> BridgeEnds;
	vector<int> BridgeStartPathway;
	int CurrentLength;
	int NumberOfBridges;
	AtomCPP* CurrentAtom;
};

CycleExplorer* InitializeExplorer(AtomCPP* InAtom, CycleExplorer* InExplorer);

list<CycleExplorer*> IterateExplorer(CycleExplorer* InExplorer, CycleExplorer** ExplorerList);

void HandleCollision(CycleExplorer* One, CycleExplorer* Two);
*/
#endif
