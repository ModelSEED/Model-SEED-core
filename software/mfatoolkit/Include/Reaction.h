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

#ifndef REACTION_H
#define REACTION_H

class Species;
class Data;
class MFAProblem;
struct MFAVariable;
struct OptimizationParameter;
struct OptSolutionData;
class Gene;
struct LinEquation;
struct GeneLogicNode;

#include "Identity.h"

#define RXN_EQUATION 0
#define RXN_DBLINK 1
#define RXN_STRUCTURALCUES 2
#define RXN_DOUBLE 3
#define RXN_DELTAG 4
#define RXN_DELTAGERR 5
#define RXN_COMPONENTS 6
#define RXN_CODE 7
#define RXN_ERRORMSG 8
#define RXN_STRING 9
#define RXN_ALLDBLINKS 10
#define RXN_GENE 11
#define RXN_LOAD 12
#define RXN_DIRECTION 13
#define RXN_COMPARTMENT 14
#define RXN_QUERY 100

class Reaction : public Identity{
private:
	Data* MainData;
	
	//This is the fundamental data relating to the reaction stoichiometry
	vector<Species*> Reactants;
	vector<double> ReactCoef;
	vector<int> ReactCompartments;

	int Type; //0 for reversible, 1 for forward, 2 for backward
	int Compartment;
	int NumReactants;
	
	//This is the fundamental data relating to the thermodynamic estimation for the reaction
	vector<Species*> StructuralCues;
	vector<double> NumStructuralCues;

	//This is where the gene dependancies for the reaction are stored
	//This first vector hold independant genes while each second vector contains gene components of a complex
	vector<vector<Gene*> > GeneDependency;
	map<Gene*, int, std::less<Gene*> > GeneIndecies;
	vector<GeneLogicNode*> LogicNodes;
	GeneLogicNode* GeneRootNode;

	//This is the fundamental data relating to how this reaction can be broken into multiple subreactions
	vector<Reaction*> ComponentReactions;
	vector<double> ComponentReactionCoeffs;

	double EstDeltaG;
	double EstDeltaGUncertainty;
	
	list<Pathway*>* PathwayList;
	map<int , MFAVariable* , std::less<int> > MFAVariables;
	vector<MFAVariable*> ComplexMFAVariables;
public:
	Reaction(vector<string>* InHeaders, string Fileline, Data* InData);
	Reaction(string Filename, Data* InData);
	~Reaction();

	//Input functions
	void AddReactant(Species* IReactant, double ICoef, int InCompartment, bool InCofactor = false);
	void SetEstDeltaG(double InDG);
	void AddComponentReaction(Reaction* InReaction, double Coeff);
	void AddStructuralCue(Species* InCue, double Coeff);
	void SetReactantToCofactor(int InIndex, bool Cofactor);
	void RemoveCompound(Species* InSpecies, int InCompartment);
	void ResetReactant(int InIndex, Species* InSpecies);
	void SetType(int InType);
	void SetCoef(Species* InSpecies, int InCompartment, double InCoeff);
	int ParseReactionEquation(string InString);
	void ClearStructuralCues();
	int ParseStructuralCueList(string InList);
	int ParseReactionList(string InList);
	int ReadFromFileline(vector<string>* InHeaders, string Fileline);
	int AddGene(Gene* InGene, int ComplexIndex);
	int ParseGeneString(string InGeneString);

	//Output functions
	int FType();
	Data* FMainData();
	bool IsReactantCofactor(int InIndex);
	int FNumReactants(int ProductOrReactant = PRODUCTS_AND_REACTANTS);
	Species* GetReactant(int InIndex);
	double GetReactantCoef(int InIndex);
	int GetReactantCompartment(int InIndex);
	double GetReactantCoef(Species* InSpecies);
	int CheckForReactant(Species* InSpecies);
	double FEstDeltaG(double pH = 7, double IonicStrength = 0);
	double FEstDeltaGUncertainty();
	bool AllKegg();
	Reaction* GetReverse();
	Reaction* Clone();
	int ContainsUnknownStructures();
	bool ContainsStructuresWithNoEnergy();
	bool ContainsNoUnidentifiedGroups();
	void MakeCode(const char* DBID, bool CofactorsOnly);
	void ReverseCode(const char* DBID, bool CofactorsOnly);
	bool Compare(Reaction* InReaction);
	int FNumStructuralCues();
	Species* GetStructuralCue(int GroupIndex);
	double GetStructuralCueNum(int InIndex);
	string CreateReactionEquation(string EquationType, bool PrintCofactors = true);
	bool SpeciesCancels(Species* InSpecies);
	double FindMarkDifference();
	bool ContainsMarkedReactants();
	bool ContainsKilledReactants();
	Reaction* GetComponentReaction(int InIndex);
	double GetComponentReactionCoeff(int InIndex);
	int FNumComponentReactions();
	double FEstDeltaGMin(bool Transport);
	double FEstDeltaGMax(bool Transport);
	double FmMDeltaG(bool Transport);
	bool CheckForTransportOrStereo(bool& Transport, bool& Stereo);
	vector<double> GetTransportCoefficient(vector<int>& InCompartments, double& TotalConstant,OptimizationParameter* InParameters);
	string Query(string InDataName);
	string CreateReactionList();
	string CreateStructuralCueList();
	string PrintRequestedDataToString(vector<string>* Headers);
	int GetReactionClass();
	int FNumGeneGroups();
	bool CheckForKO(GeneLogicNode* InNode = NULL);
	bool AllReactantsMarked();
	int FCompartment();
	bool IsBiomassReaction();

	//File input functions
	int Interpreter(string DataName, string& DataItem, bool Input);
	int LoadReaction(string InFilename);
	
	//File Output functions
	int SaveReaction(string InFilename);
	void PrintExpaInputFileLine(ofstream& Output);		

	//Manipultion
	void PerformAllCalculations();
	void AdjustDeltaGpH(double NewpH, double OriginalpH = 7, double ionicStr = 0); //This function adjusts the reaction delta G from the original pH reference state to the new pH reference state
	double CalcpHAdj(double NewpH, double OriginalpH = 7, double ionicStr = 0); //This function returns the amount that delta G will change if adjusted from the original pH refernce state to the new pH reference state. The units are kcal/mol.
	double CalcIonicStrAdj(double NewIonicStrength, double OriginalIonicStrength = 0); //This function returns the amount that delta G will change if adjusted from the original ionic refernce state to the new ionic strength reference state. The units are kcal/mol.
	void ReverseReaction();
	void CalculateGroupChange();
	bool BalanceReaction(bool AddH, bool AddE);
	void CalculateReactionEnthalpy(double MinTempDiff, double MaxPhDiff);
	void CalculateEnergyFromGroups();
	void AddToReactants();
	bool MarkProducts();
	void ReplaceAllLinkedReactants();
	void FormGeneComplexesFromNeighbors();
	int CalculateDirectionalityFromThermo();
	string CalculateTransportedAtoms();

	//Pathway functions
	bool AddPathway(Pathway* InPathway, bool ShortestOnly);
	void SetOperatorsFromPathway();
	Pathway* GetLinearPathway(int InIndex);
	int FNumLinearPathways();
	int FPathwayLength();

	//Metabolic flux analysis functions
	void CreateReactionDrainFluxes();
	void CreateMFAVariables(OptimizationParameter* InParameters);
	void UpdateBounds(int VarType, double Min, double Max, bool ApplyToMinMax = false);
	void AddUseVariables(OptimizationParameter* InParameters);
	MFAVariable* GetMFAVar(int InType);
	void GetAllMFAVariables(vector<MFAVariable*>& InVector);
	void ClearMFAVariables(bool DeleteThem);
	void ResetFluxBounds(double Min,double Max,MFAProblem* InProblem);
	double FluxLowerBound();
	double FluxUpperBound();
	double FFlux(OptSolutionData* InSolution);
	string FluxClass();
	vector<LinEquation*> CreateGeneReactionConstraints();
	vector<double> RetrieveData(int VarType,OptSolutionData* InSolution);
};

struct GeneLogicNode {
	int Logic;
	int Level;
	vector<Gene*> Genes;
	vector<GeneLogicNode*> LogicNodes;
};

#endif
