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

GeneInterval::GeneInterval(int InStartCoord, int InEndCoord, int InTotalGenes, double ExpGrowth, Data* InData) {
	MainData = InData;

	StartCoord = InStartCoord;
	EndCoord = InEndCoord;
	TotalGenes = InTotalGenes;
	ExperimentalGrowth = ExpGrowth;

	//Identifying the genes in the interval based on the input interval coordinates
	for (int i=0; i < InData->FNumGenes(); i++) {
		if (InData->GetGene(i)->GetDoubleData("START COORD") < InEndCoord && InStartCoord < InData->GetGene(i)->GetDoubleData("END COORD")) {
			GeneList.push_back(InData->GetGene(i));
			InData->GetGene(i)->AddInterval(this);
		}
	}

	IntervalUseVariable = NULL;
}

GeneInterval::~GeneInterval() {

}

//Output
int GeneInterval::FNumLoadedGenes() {
	return int(GeneList.size());
}

int GeneInterval::FNumTotalGenes() {
	return TotalGenes;
}

double GeneInterval::FExperimentalGrowth() {
	return ExperimentalGrowth;
}

int GeneInterval::FStartCoord() {
	return StartCoord;
}

int GeneInterval::FEndCoord() {
	return EndCoord;
}

Gene* GeneInterval::GetGene(int InIndex) {
	return GeneList[InIndex];
}

//Metabolic flux analysis functions
MFAVariable* GeneInterval::CreateMFAVariable(OptimizationParameter* InParameters) {
	IntervalUseVariable = InitializeMFAVariable();

	IntervalUseVariable->UpperBound = 1;
	IntervalUseVariable->LowerBound = 0;
	if (ExperimentalGrowth == 0) {
		IntervalUseVariable->UpperBound = 0;
	}
	IntervalUseVariable->Binary = true;
	IntervalUseVariable->Type = INTERVAL_USE;
	IntervalUseVariable->AssociatedInterval = this;
	IntervalUseVariable->Name = GetData("NAME",STRING);

	return IntervalUseVariable;
}

MFAVariable* GeneInterval::GetMFAVar() {
	return IntervalUseVariable;
}

void GeneInterval::ClearMFAVariables(bool DeleteThem) {
	if (DeleteThem && IntervalUseVariable != NULL) {
		delete IntervalUseVariable;
	}
	IntervalUseVariable = NULL;
}