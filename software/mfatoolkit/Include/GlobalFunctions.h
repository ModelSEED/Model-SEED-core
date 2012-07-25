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

#ifndef GLOBALFUNCTIONS_H
#define GLOBALFUNCTIONS_H

class StringDB;
class Species;
struct Pathway;
struct LinEquation;
struct MFAVariable;
struct ConstraintsToAdd;
struct ConstraintsToModify;
struct FileBounds;
struct OptimizationParameter;
struct MapData;

bool verbose();

void setVerbose(bool inVerbose);

string AskString(const char* Question);

bool Ask(const char* Question);

double AskNum(const char* Question);

void CloseIOFiles();

int Initialize();

void InitializeInternalReferences();

int TranslateFileHeader(string& InHeader, int Object);

int LoadFileReferences();

void ClearParameterDependance(string InParameterName);

string GetDatabaseDirectory(bool inputdir);

void Cleanup();

int LoadParameterFile(string Filename);

string GetParameter(const char* ParameterLabel);

void SetParameter(const char* ParameterLabel,const char* NewValue);

string FOutputFilepath();

string FProgramPath();

void SetProgramPath(const char* InPath);

void SetInputParametersFile(const char* InPath);

string FInputParameterFile();

ofstream& FLogFile();

void FlushErrorFile();

ostringstream& FErrorFile();

void ProduceChargedMolfiles(string MolfileDirectory);

bool PrintPathways(map<Species* , list<Pathway*> , std::less<Species*> >* InPathways, Species* Source);

string ConvertCycleIDToString(int InID);

int ReadCompartmentFile();

int LoadAtomTypes();

void AddAtomType(AtomType* InType);

AtomType* GetAtomType(int InIndex);

AtomType* GetAtomType(const char* InID, bool CreateMissingAtoms = true);

int FNumAtomTypes();

CellCompartment* GetCompartment(const char* Abbrev);

CellCompartment* GetCompartment(int InIndex);

CellCompartment* GetDefaultCompartment();

int FNumCompartments();

LinEquation* InitializeLinEquation(const char* Meaning = "",double RHS = 0,int Equality = EQUAL, int Type = LINEAR);

MFAVariable* InitializeMFAVariable();

MFAVariable* CloneVariable(MFAVariable* InVariable);

LinEquation* CloneLinEquation(LinEquation* InLinEquation);

int ReadConstraints(const char* ConstraintFilename, struct ConstraintsToAdd* AddConstraints, struct ConstraintsToModify* ModConstraints);

int ConvertVariableType(string TypeName);

string ConvertVariableType(int Type);

FileBounds* ReadBounds(string mediaName);

void LoosenBounds(FileBounds* InBounds);

OptimizationParameter* ReadParameters();

void ClearParameters(OptimizationParameter* InParameters);

void RectifyOptimizationParameters(OptimizationParameter* InParameters);

void ParseKEGG(Data* InData, ifstream &Input);

void AnalyzeStringCode(Data* InData);

void AddUnlabeledFormula(Species* InSpecies);

void PrintUnlabeledFormulas();

vector<string> CombineMaps(vector<string> Maps);

string CreateMapString(MapData* InMapData,bool DeleteMap);

MapData* ParseMapString(string InMap);

string ReverseMapString(string InMap);

string GetMFAVariableName(MFAVariable* InVariable);

string GetConstraintName(LinEquation* InEquation);

OptSolutionData* ParseSCIPSolution(string Filename,vector<MFAVariable*> Variables);

int printOutput(string filename,string output);

int LoadStringDB();

StringDB* GetStringDB();

struct MapData {
	vector<string> Reactants;
	vector<string> Products;
	vector<vector<int> > AtomToProducts;
	vector<vector<int> > AtomToAtom;
};

struct FileReferenceData {
	string FileReference;
	string ConsistentName;
	int DataID;
};

struct CellCompartment {
	double DPsiConst;
	double DPsiCoef;
	double pH;
	double IonicStrength;
	double MaxConc;
	double MinConc;
	string Abbreviation;
	string Name;
	int Index;
	map<string, double*, std::less<string> > SpecialConcRanges;
};

struct MFAVariable {
	double Start;
	double Value;
	double Max;
	double Min;
	double UpperBound;
	double LowerBound;
	double LoadedUpperBound;
	double LoadedLowerBound;
	bool Binary;
	Species* AssociatedSpecies;
	Reaction* AssociatedReaction;
	Gene* AssociatedGene;
	GeneInterval* AssociatedInterval;
	int Type;
	int Compartment;
	int Index;
	bool Integer;
	bool Loaded;
	bool Mark;
	string Name;

	bool Primal;

	LinEquation* DualConstraint;
	MFAVariable* UpperBoundDualVariable;
	MFAVariable* LowerBoundDualVariable;
};

struct LinEquation {
	double RightHandSide;
	double LoadedRightHandSide;
	int LoadedEqualityType;
	int EqualityType;
	vector<double> Coefficient;
	vector<MFAVariable*> Variables;
	vector<MFAVariable*> QuadOne;
	vector<MFAVariable*> QuadTwo;
	vector<double> QuadCoeff;
	int ConstraintType; //linear,nonlinear,quadratic
	Species* AssociatedSpecies;
	Reaction* AssociatedReaction;
	string ConstraintMeaning; //mass balance,Gibbs free energy,feasibility,reaction use
	int Index;
	bool Loaded;
	bool Mark;
	bool Primal;

	MFAVariable* DualVariable;
	LinEquation* DualConstraint;
};

struct OptSolutionData {
	vector<double> SolutionData;
	int Status;
	double Objective;
	int NumVariables;

	map<int , vector<double> , std::less<int> > ConcentrationStats;
	string Notes;
};

struct ConstraintsToAdd {
	vector< vector<double> > VarCoef;
	vector< vector<string> > VarName;
	vector< vector<string> > VarCompartment;
	vector< vector<int> > VarType;
	vector<double> RHS;
	vector<int> EqualityType;
};

struct ConstraintsToModify {
	vector<string> ConstraintName;
	vector< vector<double> > VarCoef;
	vector< vector<string> > VarName;
	vector< vector<string> > VarCompartment;
	vector< vector<int> > VarType;
	vector<double> RHS;
	vector<int> EqualityType;
};

struct FileBounds {
	string Filename;
	vector<string> VarName;
	vector<int> VarType;
	vector<string> VarCompartment;
	vector<double> VarMin;
	vector<double> VarMax;
};

struct OptimizationParameter {
	bool DoCalculateSensitivity;
	bool DetermineMinimalMedia;
	bool DoMinimizeFlux;
	bool DoMinimizeReactions;
	bool DoMILPCoessentiality;
	bool DoFluxCouplingAnalysis;
	bool CheckReactionEssentiality;
	bool SimultaneouslyMinReactionsMaxObjective;
	bool MassBalanceConstraints;
	bool DecomposeReversible;
	bool ThermoConstraints;
	bool SimpleThermoConstraints;
	bool CheckPotentialConstraints;
	bool AllReactionsUse;
	bool ReactionsUse;
	bool DeltaGError;
	bool LoadTightBounds;
	bool LoadForeignDB;
	bool MinimizeForeignReactions;
	bool RelaxIntegerVariables;
	bool AlwaysReoptimizeOriginalObjective;
	bool PerformSingleKO;
	bool PerformIntervalKO;
	bool PerformIntervalStrainExperiments;
	bool PerformGeneStrainExperiments;
	bool OptimizeMediaWhenZero;
	bool DoRecursiveMILPStudy;
	bool ExcludeCurrentMedia;
	bool IncludeDeadEnds;
	bool ReoptimizeSubOptimalObjective;
	bool GapFilling;
	bool GapGeneration;
	bool ReactionErrorUseVariables;
	bool MinimizeDeltaGError;
	bool AlternativeSolutionAlgorithm;
	bool DetermineCoEssRxns;
	double DeadEndCoefficient;

	bool AddLumpedReactions;
	bool AllDrainUse;
	bool DrainUseVar;
	bool DecomposeDrain;
	bool AllReversible;
	bool OptimizeMetabolitesWhenZero;
	//Indicates if gene use variables and gene constraints should be used
	bool GeneConstraints;
	//Indicates if interval use variables and interval constraints should be used
	bool IntervalOptimization;
	//Indicates if deletions should be optimized
	bool DeletionOptimization;
	//Indicates that a gene minimization study should be performed
	bool GeneOptimization;

	double Temperature;
	double MaxFlux;
	double MinFlux;
	double MaxPotential;
	double MinPotential;
	double MaxDrainFlux;
	double MinDrainFlux;
	double MaxError;
	double OptimalObjectiveFraction;
	int SolutionSizeInterval;
	int RecursiveMILPSolutionLimit;
	int ErrorMult;
	
	int DefaultExchangeComp;
	vector<int> RecursiveMILPTypes;
	vector<string> ExchangeSpecies;
	vector<string> UnremovableMedia;
	vector<int> ExchangeComp;
	vector<double> ExchangeMax;
	vector<double> ExchangeMin;
	vector<vector<string> > ExplorationNames;
	vector<vector<int> > ExplorationTypes;
	vector<vector<double> > ExplorationCoefficients;
	vector<double> ExplorationMin;
	vector<double> ExplorationMax;
	vector<double> ExplorationIteration;
	vector<vector<string> > TargetReactions;
	vector<vector<string> > UnviableIntervalCombinations;
	//FBA experiment sets
	vector<vector<string> > KOSets;
	vector<string> mediaConditions;
	vector<string> labels;
	
	vector<string> KOReactions;
	vector<string> KOGenes;
	map<string, int, std::less<string> > BlockedReactions;
	map<string, int, std::less<string> > AlwaysActiveReactions;
	map<string, double> Conditions;
	map<string, int, std::less<string> > PotentialEnergyCompounds;
	bool PotentialEnergyCompoundsInclusive;
	ConstraintsToAdd* AddConstraints;
	ConstraintsToModify* ModConstraints;
	FileBounds* UserBounds;

	bool PrintSolutions;
	bool ClearSolutions;
};

struct LogicNode {
	int Logic;
	int Level;
	vector<int> Entities;
	vector<bool> EntityOn;
	vector<bool> IsLogicNode;
};

struct ProblemState {
	bool IntegerRelation;

	bool Max;

	LinEquation* Objective;

	vector<double> LowerBound;
	vector<double> UpperBound;
	vector<MFAVariable*> Variables;
	
	vector<double> RHS;
	vector<int> EqualityType;
	vector<LinEquation*> Constraints;

	vector<OptSolutionData*> Solutions;
};

struct DataNode {
	map<int,DataNode*,std::less<int> > children;
	double data;
};

struct SavedBounds {
	vector<MFAVariable*> variables;
	vector<double> upperBounds;
	vector<double> lowerBounds;
};

#endif
