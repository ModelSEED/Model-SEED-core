#ifndef GENEINTERVAL_H
#define GENEINTERVAL_H

#include "Identity.h"

class Gene;
class Data;
struct OptimizationParameter;
struct MFAVariable;

class GeneInterval : public Identity{
private:
	Data* MainData;

	vector<Gene*> GeneList;
	
	int StartCoord;
	int EndCoord;
	int TotalGenes;
	double ExperimentalGrowth;

	MFAVariable* IntervalUseVariable;
public:
	GeneInterval(int InStartCoord, int InEndCoord, int InTotalGenes, double ExpGrowth, Data* InData);
	~GeneInterval();
	
	//Input

	//Output
	int FNumLoadedGenes();
	int FNumTotalGenes();
	double FExperimentalGrowth();
	int FStartCoord();
	int FEndCoord();
	Gene* GetGene(int InIndex);

	//Metabolic flux analysis functions
	MFAVariable* CreateMFAVariable(OptimizationParameter* InParameters);
	MFAVariable* GetMFAVar();
	void ClearMFAVariables(bool DeleteThem);
};

#endif
