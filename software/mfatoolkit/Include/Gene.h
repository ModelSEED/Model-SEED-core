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

#ifndef GENE_H
#define GENE_H

#include "Identity.h"

class Reaction;
class Data;

#define GENE_DBLINK 0
#define GENE_COORD 2
#define GENE_REACTION 3
#define GENE_PARALOG 4
#define GENE_ORTHOLOG 5
#define GENE_DOUBLE 6
#define GENE_STRING 7
#define GENE_QUERY 8
#define GENE_LOAD 9

class Gene : public Identity{
private:
	bool Active;
	
	Data* MainData;

	vector<Reaction*> ReactionList;
	vector<GeneInterval*> IntervalList;

	MFAVariable* GeneUseVariable;

	Gene* Next;
	Gene* Previous;
public:
	Gene(string InFilename, Data* InData);
	~Gene();
	
	//Input
	void AddReaction(Reaction* InReaction);
	void AddInterval(GeneInterval* InInterval);
	void SetPrevious(Gene* InGene);
	void SetNext(Gene* InGene);
	void ClearIntervals();

	//Output
	int FNumReactions();
	Reaction* GetReaction(int InIndex);
	string Query(string InQuery);
	int FNumIntervals();
	Gene* NextGene();
	Gene* PreviousGene();
	GeneInterval* GetInterval(int InIndex);

	//Fileinput
	int Interpreter(string DataName, string& DataItem, bool Input);
	int LoadGene(string InFilename);

	//Fileoutput
	int SaveGene(string InFilename);

	//Metabolic flux analysis functions
	MFAVariable* CreateMFAVariable(OptimizationParameter* InParameters);
	MFAVariable* GetMFAVar();
	void ClearMFAVariables(bool DeleteThem);
	LinEquation* CreateIntervalDeletionConstraint();
};

#endif
