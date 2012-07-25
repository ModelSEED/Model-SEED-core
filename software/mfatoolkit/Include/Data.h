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

#ifndef DATA_H
#define DATA_H

class Species;
class Reaction;
struct Pathway;
class Gene;
class GeneInterval;
struct OptimizationParameter;

#include "Identity.h"

class Data : public Identity  {
private:
	int LastSpeciesIndex;
	int LastReactionIndex;
	int LastGeneIndex;
	list<Reaction*>::iterator ReactionIT;
	list<Species*>::iterator SpeciesIT;
	list<Gene*>::iterator GeneIT;
	list<Reaction*> ReactionList;
	list<Species*> SpeciesList;
	list<Gene*> GeneList;

	Species* HydrogenSpecies;

	//TODO:ultimately I would like to add pegs, functional roles, complexes, etc to the database

	vector<Species*> StructuralCues;
	vector<Species*> SortedMoleculeGroups;
	vector<Species*> SortedSearchableGroups;
	vector<GeneInterval*> GeneIntervals;

	bool* RepresentedCompartments;  

	//These maps are used to look up species, reactions, and structural cues by any type of data
	map<string, map<string, Reaction*, std::less<string> >, std::less<string> > RxnDatabaseLinks;
	map<string, map<string, Species*, std::less<string> >, std::less<string> > CpdDatabaseLinks;
	map<string, map<string, Species*, std::less<string> >, std::less<string> > CueDatabaseLinks;
	map<string, map<string, Gene*, std::less<string> >, std::less<string> > GeneDatabaseLinks;
	map<string, GeneInterval*, std::less<string> > IntervalNameMap;
public:
	Data(int InIndex);
	~Data();

	//File input
	int LoadSystem(string Filename, bool StructCues = false);
	int LoadStructuralCues();

	//Input
	Species* AddSpecies(string Filename);
	Reaction* AddReaction(string Filename);
	Species* AddStructuralCue(string Filename);
	Gene* AddGene(string Filename);
	Species* AddSpecies(vector<string>* InHeaders, string Fileline);
	Reaction* AddReaction(vector<string>* InHeaders, string Fileline);
	Species* AddStructuralCue(vector<string>* InHeaders, string Fileline);
	Species* AddSpecies(Species* NewSpecies);
	Reaction* AddReaction(Reaction* NewReaction);
	Species* AddStructuralCue(Species* NewSpecies);
	void ClearCompounds(int DeleteThem = ALL);
	void ClearReactions(int DeleteThem = ALL);
	void ClearStructuralCues();
	void ClearGenes(int DeleteThem = ALL);
	void ResetAllBools(bool NewMark, bool ResetMark, bool NewKill, bool ResetKill, bool ResetReactions, bool ResetSpecies, bool ResetCues);
	void AddCompartment(int InIndex);
	void RemoveMarkedReactions(bool DeleteThem);
	void RemoveMarkedSpecies(bool DeleteThem);
	void InsertSpeciesDatabaseLinks(Species* InSpecies);
	void InsertReactionDatabaseLinks(Reaction* InReaction);
	void InsertGeneDatabaseLinks(Gene* InGene);
	void InsertCombinedData(string InData, Species* InSpecies, Reaction* InReaction, Gene* InGene);
	void ReindexSpecies();
	void ReindexReactions();
	void ClearSpeciesDatabaseLinks();
	void LoadGeneIntervals();
	void AddAlias(int Type,string One,string Two);
	void LoadGeneDictionary();

	//Output
	//Structural cue query functions
	Species* GetStructuralCue(int InIndex);
	int FNumStructuralCues();
	//Compound query functions
	Species* GetSpecies(int InIndex);
	int FNumSpecies();
	//Reaction query functions
	Reaction* GetReaction(int InIndex);
	int FNumReactions();
	//Gene query functions
	Gene* GetGene(int InIndex);
	int FNumGenes();
	//Interval query functions
	int FNumGeneIntervals();
	GeneInterval* GetGeneInterval(int InIndex);
	GeneInterval* FindInterval(string InIntervalName);
	//Query functions required to label atoms with structural cues
	int FNumFullMoleculeGroups();
	Species* GetFullMoleculeGroup(int InIndex);
	int FNumSearchableGroups();
	Species* GetSearchableGroup(int InIndex);
	//Query functions related to the cellular compartments
	bool CompartmentRepresented(int InIndex);
	Species* FindSpecies(const char* DatabaseName,const char* DataID);
	Reaction* FindReaction(const char* DatabaseName,const char* DataID);
	Species* FindStructuralCue(const char* DatabaseName,const char* DataID);
	Gene* FindGene(const char* DatabaseName,const char* DataID);
	Species* GetHydrogenSpecies();

	//Analysis functions
	void PerformAllRequestedTasks();
	map<Species* , list<Pathway*> , std::less<Species*> >* FindPathways(Species* Source, vector<Species*> Targets, int MaxLength, int TimeInterval, bool AddReverseConnections, int LengthInterval, int &ClockIndex);
	void SearchForPathways();
	void PerformMFA();
	void PollStructuralCues();
	void FindDeadEnds();
	void IdentifyCompoundWithIdenticalStructures();
	void LabelKEGGSingleCofactors();
	void LabelKEGGCofactorPairs();
	void MergeReactants();
	void RunWebGCM(string InputFilename,string OutputFilename);
	void SequenceGenes();
	void IdentifyCompoundsByStringcode();
	void AutomaticallyCreateGeneIntervals(OptimizationParameter* InParameters);
	void GenerateBNICESubnetwork();

	//File output
	int SaveSystem();
	void PrintLumpingExpaInputFile(string Filename);
	void PrintNeutralFormulas();
	void PrintRequestedData();
	void PrintReactionNetwork();
	void ProcessWebInterfaceModel();
	void PrintStructures();
};

//This template class is required so the template remove function for lists can be used to removed marked reactions and compounds
template <class T>
class RemoveMarkedFunctor {
	public:
	bool DeleteThem;
	bool operator()(T* InData) {
		if (InData->FMark()) {
			if (DeleteThem) {
				delete InData;		
			}
			return 1;
		}
		return 0;
	}	  
};

//Stores the minimal pathway data: reactions and intermediates.
struct Pathway {
	int Index;
	int Length;
	Species** Intermediates;
	Reaction** Reactions;
	bool* Directions;
	Reaction* OverallReaction;
};

//This class is needed to use the STL::list remove function to remove undesired pathways
class RemovePathsOutsideLengthInterval {
	public:
	int LengthInterval;
	int ShortestPathLength;
	bool operator()(Pathway* InPath) {
		if((InPath->Length-ShortestPathLength) > LengthInterval) {
			delete [] InPath->Intermediates;
			delete [] InPath->Reactions;
			delete [] InPath->Directions;
			delete InPath;
			return 1;
		}
		return 0;
	}	  
};

//Stores compound connectivity data
struct Node {
	int ID;
	Species* Identity;
	list<Node*> Children;
	list<Reaction*> EdgeLables;
	list<bool> ForwardDirection;
};

//This structure contains all data required to efficiently explore the network in a DFS fashion with no cyclical pathways generated.
struct TreeClimber {
	int CurrentPathLength;
	int ShortestPathLength;
	Node* CurrentPathway[MAX_PATH_LENGTH];
	Reaction* CurrentPathEdgeLabels[MAX_PATH_LENGTH];
	bool CurrentPathEdgeDirections[MAX_PATH_LENGTH];
	list<Node*>::iterator CurrentPathwayIterators[MAX_PATH_LENGTH];
	list<Reaction*>::iterator CurrentPathwayLabelIterators[MAX_PATH_LENGTH];
	list<bool>::iterator CurrentPathwayDirectionIterators[MAX_PATH_LENGTH];
	bool* NodesVisited;
	int NumberOfPaths;
};

#endif
