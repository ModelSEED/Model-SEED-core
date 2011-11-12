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

#ifndef MFAPROBLEM_H
#define MFAPROBLEM_H

struct LinEquation;
struct MFAVariable;
struct OptSolutionData;
struct FileConstraints;
struct SavedBounds;

class MFAProblem{
private:
	bool Max;
	int Solver;
	int ProbType;	
	int NumLocalSolve;
	int ProblemIndex;
	bool ProblemLoaded;

	bool RelaxIntegerVariables;
	bool LoadedRelaxation;
	bool UseTightBounds;

	Data* SourceDatabase;
	LinEquation* ObjFunct;
	vector<LinEquation*> Constraints;
	map<string, int> ConstraintIndexMap;
	vector<MFAVariable*> Variables;
	vector<OptSolutionData*> Solutions;
	vector<ProblemState*> ProblemStates;
	int MFAProblemClockIndex;
public:
	MFAProblem();
	~MFAProblem();
	
	//Input functions
	void SetMax();
	void SetMin();
	void SetSolver(const char* InSolver);
	void SetNumLocalSolve(int InNumLocalSolve);
	void ResetIndecies();
	void ClearSolutions(int Start = 0, int End = -1, bool DeleteThem = true);
	int AddVariable(MFAVariable* InVariable);
	int AddConstraint(LinEquation* InConstraint);
	void AddObjective(LinEquation* InObjective);
	void AddOptimizeVariableObjective(MFAVariable* InVariable, bool InMax);
	void ClearObjective(bool DeleteThem = true);
	void ClearConstraints(bool DeleteThem = true);
	void ClearVariables(bool DeleteThem = true);
	void DetermineProbType();
	void AddSumObjective(int VarType, bool Quadratic, bool Append, double Coeff, bool ForeignOnly); 
	void AddMassBalanceConstraints(Data* InData);
	LinEquation* AddSumConstraint(int VarType, bool Quadratic, double Coeff, double RHS, int EqualityType);
	LinEquation* AddUseSolutionConst(OptSolutionData* SolutionData, vector<int> VariableTypes, OptimizationParameter* InParameters);
	void EnforceIntergerSolution(OptSolutionData* SolutionData, vector<int> VariableTypes, bool ForeignOnly, bool RefreshSolver);
	void RelaxSolutionEnforcement(vector<int> VariableTypes, bool ForeignOnly, bool RefreshSolver);
	LinEquation* MakeObjectiveConstraint(double Value, int Equality = EQUAL);
	int BuildMFAProblem(Data* InData, OptimizationParameter*& InParameters);
	int BuildDualMFAProblem(MFAProblem* InProblem, Data* InData, OptimizationParameter*& InParameters);
	int ApplyInputBounds(FileBounds* InBounds, Data* InData, bool ApplyToMinMax = false);
	int ApplyInputConstraints(ConstraintsToAdd* AddConstraints, Data* InData);
	int ModifyInputConstraints(ConstraintsToModify* ModConstraints, Data* InData);
	void InputSolution(OptSolutionData* InSolution);
	LinEquation* CreateUseVariableConstraint(MFAVariable* InVariable,OptimizationParameter*& InParameters);
	LinEquation* CreateUseVariablePositiveConstraint(MFAVariable* InVariable,OptimizationParameter*& InParameters);
	LinEquation* CreateGibbsEnergyConstraint(Reaction* InReaction, OptimizationParameter*& InParameters);
	LinEquation* CreateReactionErrorConstraint(Reaction* InReaction, OptimizationParameter*& InParameters);
	void CreateSpeciesGibbsEnergyConstraint(Species* InSpecies, OptimizationParameter*& InParameters);
	LinEquation* ConvertStringToObjective(string ObjString, Data* InData);
	void RemoveConstraint(int ConstraintIndex, bool DeleteConstraint = true);
	void RelaxConstraint(int ConstraintIndex);
	int SaveState();
	void ClearState(int InState);
	void LoadState(int InState, bool Bounds, bool Constraints, bool Objective, bool SaveSolutions, bool Parameters);
	void ResetVariableMarks(bool InMark);
	void ResetConstraintMarks(bool InMark);

	//Output functions
	bool FMax();
	int FSolver();
	int FNumConstraints();
	int FNumSolutions();
	int FNumVariables();
	MFAVariable* GetVariable(int InIndex);
	OptSolutionData* GetSolution(int InIndex);
	LinEquation* GetConstraint(int InIndex);
	LinEquation* GetObjective();
	bool FProblemLoaded();
	string fluxToString();
	
	//Solver interaction
	int LoadSolver(bool PrintFromSolver = true);
	OptSolutionData* RunSolver(bool SaveSolution,bool InInputSolution,bool WriteProblem);
	int LoadConstToSolver(int ConstraintNumber);
	int LoadAllConstToSolver() ;
	int LoadAllVariables();
	int LoadObjective();
	int LoadVariable(int InIndex);
	int ResetSolver();
	int UpdateLoadSolver();
	SavedBounds* saveBounds();
	int loadBounds(SavedBounds* inBounds,bool loadProblem = true);
	int loadChangedBoundsIntoSolver(SavedBounds* inBounds);
	int loadMedia(string media, Data* inData,bool loadIntoSolver = true);
	int clearOldMedia(OptimizationParameter* InParameters);

	//Analysis functions
	map<int , vector<double> , std::less<int> >* CalcConcMeanIonicStrength();
	void ProcessSolution(OptSolutionData* InSolution);
	int FindTightBounds(Data* InData,OptimizationParameter*& InParameters, bool SaveSolution, bool UseSpecifiedSearchTypes);
	int FindTightBounds(Data* InData,OptimizationParameter*& InParameters,string Note);
	int RecursiveMILP(Data* InData,OptimizationParameter*& InParameters, vector<int> VariableTypes,bool PrintSolutions);
	vector<OptSolutionData*> RecursiveMILP(OptimizationParameter* InParameters, string ProblemNote,bool ForeignOnly,vector<int> VariableTypes,double MinSolution,int ClockIndex,LinEquation* OriginalObjective);
	int CheckIndividualMetaboliteProduction(Data* InData, OptimizationParameter* InParameters, vector<Species*> Metabolites, vector<int> Compartments, bool FindTightBounds, bool MinimizeForeignReactions, bool MakeAllDrainsSimultaneously, string Note, bool SubProblem);
	int CheckIndividualMetaboliteProduction(Data* InData, OptimizationParameter* InParameters, string InMetaboliteList, bool DoFindTightBounds, bool MinimizeForeignReactions, string Note, bool SubProblem);
	int RunDeletionExperiments(Data* InData, OptimizationParameter* InParameters);
	int RunMediaExperiments(Data* InData, OptimizationParameter* InParameters, double WildTypeObjective, bool DoOptimizeSingleObjective, bool DoFindTightBounds, bool MinimizeForeignReactions, bool OptimizeMetaboliteProduction);
	int DetermineMinimalFeasibleMedia(Data* InData,OptimizationParameter* InParameters);
	int OptimizeSingleObjective(Data* InData, OptimizationParameter* InParameters, string InObjective, bool FindTightBounds, bool MinimizeForeignReactions, double &ObjectiveValue, string Note);
	int OptimizeSingleObjective(Data* InData, OptimizationParameter* InParameters, bool FindTightBounds, bool MinimizeForeignReactions, double &ObjectiveValue, string Note, bool SubProblem);
	int CheckPotentialConstraints(Data* InData, OptimizationParameter* InParameters, double &ObjectiveValue, string Note);
	int OptimizeIndividualForeignReactions(Data* InData, OptimizationParameter* InParameters, bool FindTightBounds, bool OptimizeMetaboliteProduction);
	int FindSpecificExtremePathways(Data* InData, OptimizationParameter* InParameters);
	int FluxCouplingAnalysis(Data* InData, OptimizationParameter* InParameters, bool DoFindTightBounds, string &InNote, bool SubProblem);
	int ExploreSplittingRatios(Data* InData, OptimizationParameter* InParameters, bool FindTightBounds, bool MinimizeForeignReactions);
	int MILPCoessentialityAnalysis(Data* InData, OptimizationParameter* InParameters, bool DoFindTightBounds, string &InNote, bool SubProblem);	
	int RecursiveMILPStudy(Data* InData, OptimizationParameter* InParameters, bool DoFindTightBounds);
	int IdentifyReactionLoops(Data* InData, OptimizationParameter* InParameters);
	int LoadGapFillingReactions(Data* InData, OptimizationParameter* InParameters);
	int GapFilling(Data* InData, OptimizationParameter* InParameters, string Label = "NONE");
	int CompleteGapFilling(Data* InData, OptimizationParameter* InParameters);
	int CalculateGapfillCoefficients(Data* InData,OptimizationParameter* InParameters,map<string,Reaction*,std::less<string> > InactiveVar,map<MFAVariable*,double,std::less<MFAVariable*> >& VariableCoefficients);
	int GapGeneration(Data* InData, OptimizationParameter* InParameters);
	int SolutionReconciliation(Data* InData, OptimizationParameter* InParameters);
	string MediaSensitivityExperiment(Data* InData, OptimizationParameter* InParameters, vector<MFAVariable*> CurrentKO, vector<MFAVariable*> NonessentialMedia);
	int FitMicroarrayAssertions(Data* InData);
	int GenerateMinimalReactionLists(Data* InData);
	int ParseRegExp(OptimizationParameter* InParameters, Data* InData, string Expression);
	int AddRegulatoryConstraints(OptimizationParameter* InParameters, Data* InData);
	void AddVariableToRegulationConstraint(LinEquation* InEquation,double Coefficient,string VariableName,Data* InData,OptimizationParameter* InParameters);
	int CalculateFluxSensitivity(Data* InData,vector<MFAVariable*> variables,double objective);
	double optimizeVariable(MFAVariable* currentVariable,bool maximize);
	
	//FBA extension studies
	int CombinatorialKO(int maxDeletions,Data* InData, bool reactions);

	//File IO Functions
	void PrintProblemReport(double SingleObjective,OptimizationParameter* InParameters, string InNote);
	int LoadTightBounds(Data* InData, bool SetBoundToTightBounds);
	void SaveTightBounds();
	void PrintSolutions(int StartIndex, int EndIndex,bool tightbounds = false);
	void PrintVariableKey();
	void WriteLPFile();
};

struct RegLogicNode {
	int Logic;
	int Level;
	vector<string> Object;
	vector<RegLogicNode*> LogicNodes;
	vector<bool> LogicOn;
	vector<bool> ObjectOn;
};

#endif
