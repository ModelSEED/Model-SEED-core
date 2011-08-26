#include "MFAToolkit.h"
#include "BNICEFunctions.h"
#include "ReactionOperator.h"
#include "BNICEInterfaceFunctions.h"

map<string , vector<Reaction*>* , std::less<string> > UnstableSpeciesReactions;
map<string, int, std::less<string> > OperatorsByName;
list<ReactionOperator*> OperatorList;
Species* UnstableCompoundMarker;

void RunNetGen(const char* SystemOutputFile) {
	//Getting filename that all compound and reaction data will be saved into
	string Filename(SystemOutputFile);
	if (Filename.length() == 0) {
		Filename = GetSuffix("Input filename for data flatfile output: ");
	}
	
	//Creating datastructure for all program data
	Data* NewData = new Data(0);
	
	//This loads all of the start compounds into the datastructure
	NewData->AddData("FILENAME",Filename.data(),STRING);
	LoadStartCompounds(NewData);
	
	//This loads the operators from file
	LoadOperators();
	RunNetGenAlg(atoi(GetParameter("rank limit").data()),atoi(GetParameter("carbon limit").data()),atoi(GetParameter("compound limit").data()),NewData);
	NewData->PerformAllRequestedTasks(Filename);
	GenerateRunStatistics(Filename,NewData);

	delete NewData;
};

//Atom functions
list<int*>* SiteFinderDFS(int NumSiteAtoms, int FirstSiteIndex, bool** Compatibility, int** BondMatrix, int SitePosition, bool* AlreadyMatched, AtomCPP* InAtom) {
	list<int*>* Result = new list<int*>;
	//If this is the first atom to be called, I have some initialization taskes to perform
	bool First = false;
	if (AlreadyMatched == NULL) {
		AlreadyMatched = new bool[NumSiteAtoms];
		for (int i=0; i < NumSiteAtoms; i++) {
			AlreadyMatched[i] = false;
		}
		First = true;
	}
	
	//I mark this atom and site location so they are not used in any child configurations
	InAtom->SetMark(true);
	AlreadyMatched[SitePosition] = true;

	//First I identify every possible child configuration that matches the site bond structure
	vector< list<int*> > Configurations;
	for (int i=0; i < NumSiteAtoms; i++) {
		if (!AlreadyMatched[i] && BondMatrix[FirstSiteIndex+SitePosition][FirstSiteIndex+i] != 0) {
			list<int*> CurrentConfig;
			for (int j=0; j < InAtom->FNumBonds(); j++) {
				if (!InAtom->GetBond(j)->FMark() && InAtom->GetBondOrder(j) == BondMatrix[FirstSiteIndex+SitePosition][FirstSiteIndex+i] && Compatibility[i][InAtom->GetBond(j)->FIndex()]) {
					list<int*>* ChildConfigs = SiteFinderDFS(NumSiteAtoms,FirstSiteIndex,Compatibility,BondMatrix,i,AlreadyMatched,InAtom->GetBond(j));
					CurrentConfig.splice(CurrentConfig.end(),(*ChildConfigs));
					delete ChildConfigs;
				}
			}
			Configurations.push_back(CurrentConfig);
			//Now I check to see if any valid configurations exist for this bond of the site
			//If none exist, then this atom will produce no sites and I return an empty configuration list
			if (CurrentConfig.size() == 0) {
				for (int k=0; k < int(Configurations.size()); k++) {
					list<int*>::iterator ListIT = Configurations[k].begin();
					for (int j=0; j < int(Configurations[k].size()); j++) {
						delete [] (*ListIT);
						ListIT++;
					}
				}
				AlreadyMatched[SitePosition] = false;
				if (First) {
					delete [] AlreadyMatched;
				}
				InAtom->SetMark(false);
				return Result;
			}
		}
	}
	
	//If the configurations vector is empty, it means this atom is the end point in the site... I create a single new configuration and pass it upwards
	if (Configurations.size() == 0) {
		int* NewConfig = new int[NumSiteAtoms];
		for (int i=0; i < NumSiteAtoms; i++) {
			NewConfig[i] = -1;
		}
		NewConfig[SitePosition] = FIndex();
		Result->push_back(NewConfig);
		AlreadyMatched[SitePosition] = false;
		if (First) {
			delete [] AlreadyMatched;
		}
		SetMark(false);
		return Result;
	}

	//First I want to see if two different lists in the Configurations vector produce any overlapp in the assigned configuration positions
	//This means the site has a cycle in it and I only need to worry about the configurations from one of the lists
	//This array tells me what atoms have been assigned to each site position storing the data for the current configuration
	int* AssignedPositions = new int[NumSiteAtoms];
	for (int i=0; i < NumSiteAtoms; i++) {
		AssignedPositions[i] = -1;
	}
	for (int i=0; i < int(Configurations.size()); i++) {
		for (int k=0; k < NumSiteAtoms; k++) {
			if ((*Configurations[i].begin())[k] != -1) {
				if (AssignedPositions[k] != -1) {
					//I found two cofigurations matching the same site location... they must be opposite ends of a cycle... I eliminate one of the configurations
					list<int*>::iterator ListIT = Configurations[i].begin();
					for (int j=0; j < int(Configurations[i].size()); j++) {
						delete [] (*ListIT);
						ListIT++;
					}
					Configurations.erase(Configurations.begin()+i,Configurations.begin()+i+1);
					i--;
					k = NumSiteAtoms;
				} else {
					AssignedPositions[k] = i;
				}
			}
		}
	}
	delete [] AssignedPositions;

	//If there is only one child configuration, this this site position only has one child. I add this atom to all compatible configurations in the list and pass the configurations on upwards.
	if (Configurations.size() == 1) {
		list<int*>::iterator ListIT = Configurations[0].begin();
		for (int j=0; j < int(Configurations[0].size()); j++) {
			(*ListIT)[SitePosition] = FIndex();
			ListIT++;
		}
		Result->splice(Result->end(),Configurations[0]);
		AlreadyMatched[SitePosition] = false;
		if (First) {
			delete [] AlreadyMatched;
		}
		InAtom->SetMark(false);
		return Result;
	}

	//Next I combine the configurations in every possible way without using the same atom in two positions
	//This array tells me what atoms have already been assigned in other cofigurations and prevent assignment of the same atom to two different slots in the configuration
	bool* AtomMarks = new bool[InAtom->FOwner()->FNumAtoms()];
	//This array tracks the current list being examined in each configuration site for this atom
	list<int*>::iterator* ConfigurationIterators = new list<int*>::iterator[Configurations.size()];
	int* ConfigurationIndecies = new int[Configurations.size()];
	//I initialize the current indecies to -1
	for (int i=0; i < int(Configurations.size()); i++) {
		ConfigurationIterators[i] = Configurations[i].begin();
		ConfigurationIndecies[i] = 0;
	}

	int CurrentIndex = int(Configurations.size());
	do {
		if (CurrentIndex == int(Configurations.size())) {
			//Here is the code that specifically combines the child configurations into the complete configurations in every feasible combination
			int* NewConfiguration = new int[NumSiteAtoms];
			for (int i=0; i < InAtom->FOwner()->FNumAtoms(); i++) {
				AtomMarks[i] = InAtom->FOwner()->GetAtom(i)->FMark();
			}
			for (int i=0; i < NumSiteAtoms; i++) {
				NewConfiguration[i] = -1;
			}
			for (int i=0; i < int(Configurations.size()); i++) {
				for (int j=0; j < NumSiteAtoms; j++) {
					if ((*ConfigurationIterators[i])[j] != -1) {
						if (!AtomMarks[(*ConfigurationIterators[i])[j]]) {
							AtomMarks[(*ConfigurationIterators[i])[j]] = true;
							NewConfiguration[j] = (*ConfigurationIterators[i])[j];
						} else {
							delete [] NewConfiguration;
							NewConfiguration = NULL;
							i = int(Configurations.size());
							j = NumSiteAtoms;
						}
					}
				}
			}
			if (NewConfiguration != NULL) {
				//This is a valid configuration, so I add it to the result
				NewConfiguration[SitePosition] = InAtom->FIndex();
				Result->push_back(NewConfiguration);
			}
			CurrentIndex--;
		} else {
			//This it the code for counting through all of the possible configuration combinations
			if (ConfigurationIndecies[CurrentIndex] < int(Configurations[CurrentIndex].size()-1)) {
				if (ConfigurationIndecies[CurrentIndex] != -1) {
					ConfigurationIterators[CurrentIndex]++;
				}
				ConfigurationIndecies[CurrentIndex]++;
				CurrentIndex++;
			} else {
				ConfigurationIterators[CurrentIndex] = Configurations[CurrentIndex].begin();
				ConfigurationIndecies[CurrentIndex] = -1;
				CurrentIndex--;
			}
		}
	} while (CurrentIndex >= 0);
	delete [] ConfigurationIterators;
	delete [] ConfigurationIndecies;
	delete [] AtomMarks;

	//Now I must delete every single child configuration as I do not need this data any longer
	for (int i=0; i < int(Configurations.size()); i++) {
		list<int*>::iterator ListIT = Configurations[i].begin();
		for (int j=0; j < int(Configurations[i].size()); j++) {
			delete [] (*ListIT);
			ListIT++;
		}
	}

	//I unmark this atom and site location so they are free for use again
	AlreadyMatched[SitePosition] = false;
	SetMark(false);

	//If this is the first atom in the site, I delete the marking array
	if (First) {
		delete [] AlreadyMatched;
	}
	return Result;
}

//This is a simpler atom matching routine used to determine if the atom is part of a reactive site for a reaction rule
//This only checks to see that the atom has the required bond neighborhood as specified in the reaciton rule.
bool AtomCPP::MatchesGroupAtom(GroupAtom* InGroupAtom) {
	int NumberHydrogens = 0;
	int NumberSingleBonds = 0;
	int NumberDoubleBonds = 0;
	int NumberTripleBonds = 0;
	
	for (int i=0; i < FNumBonds(); i++) {
		if (GetBondOrder(i) == 1) {
			if (GetBond(i)->FType()->FID().compare("H") == 0) {
				NumberHydrogens++;
			}
			else {
				NumberSingleBonds++;
			}
		}
		else if (GetBondOrder(i) == 2) {
			NumberDoubleBonds++;
		}
		else if (GetBondOrder(i) == 3) {
			NumberTripleBonds++;
		}
	}

	for (int i=0; i < InGroupAtom->NumAlternatives; i++) {
		if (FType()->CompareType(InGroupAtom->GroupAtomType[i]) && MatchCycleID(InGroupAtom->CycleData[i])) {
			if (NumberHydrogens == InGroupAtom->NumberHydrogens[i] || InGroupAtom->NumberHydrogens[i] == 9) {
				if (NumberSingleBonds == InGroupAtom->NumberSingleBonds[i] || InGroupAtom->NumberSingleBonds[i] == 9) {
					if (NumberDoubleBonds == InGroupAtom->NumberDoubleBonds[i] || InGroupAtom->NumberDoubleBonds[i] == 9) {
						if (NumberTripleBonds == InGroupAtom->NumberTripleBonds[i] || InGroupAtom->NumberTripleBonds[i] == 9) {
							return true;
						}
					}
				}
			}
		}
	}

	return false;
}

//Data functions
void Data::LoadOperators(int OperatorType) {
	//Load all normal operators from file
	if (OperatorType == NORMAL || OperatorType == ALL) {
		string OperatorListFilename(FProgramPath());
		OperatorListFilename.append(GetParameter("operator list filename"));
		vector<string> Filenames = ReadStringsFromFile(OperatorListFilename);

		for (int i=0; i < int(Filenames.size()); i++) {
			ReactionOperator* NewOp = new ReactionOperator(Filenames[i], this);
			if (NewOp->FNumAtoms() != 0) {
				OperatorList.push_back(NewOp);
				OperatorsByName[NewOp->FName()] = NewOp->FEntry();
			}
		}
	}

	//Load all retrosynthesis operators from file
	if (OperatorType == RETROSYNTHESIS || OperatorType == ALL) {
		string OperatorListFilename(FProgramPath());
		OperatorListFilename.append(GetParameter("retrosynthesis operator list filename"));
		vector<string> Filenames = ReadStringsFromFile(OperatorListFilename);

		for (int i=0; i < int(Filenames.size()); i++) {
			ReactionOperator* NewOp = new ReactionOperator(Filenames[i], this);
			if (NewOp->FNumAtoms() != 0) {
				OperatorList.push_back(NewOp);
				OperatorsByName[NewOp->FName()] = NewOp->FEntry();
			}
		}
	}
}

int Data::GetOperatorIDByName(string InName) {
	int Temp = OperatorsByName[InName];
	if (Temp == 0) {
		OperatorsByName[InName] = int(OperatorsByName.size());
		return int(OperatorsByName.size());
	}
	else {
		return Temp;
	}
}	

ReactionOperator* Data::GetOperator(int InIndex) {
	if (InIndex >= int(OperatorList.size())) {
		return NULL;
	}
	
	list<ReactionOperator*>::iterator OpIT = OperatorList.begin();
	for (int i=0; i < InIndex; i++) {
		OpIT++;
	}
	return *OpIT;
}

//This function returns the reaction that consumes an unstable molecule with the input stringcode and produces stable products
vector<Reaction*>* Data::GetUnstableSpeciesReaction(string UnstableSpeciesStringcode) {
	return UnstableSpeciesReactions[ UnstableSpeciesStringcode ];
}

void Data::RunNetGenAlg(int RankLimit, int CarbonLimit, int CompoundLimit) {
	double MaximumNetGenTime = atof(GetParameter("maximum time to run NetGen algorithm(sec)").data());
	cout << "Generation\tNumber compounds\tNumber reactions\tTime" << endl;
	//FLogFile() << "Generation\tNumber compounds\tNumber reactions\tTime" << endl;
	
	list<Species*>::iterator SpeciesIT = SpeciesList.begin();
	SortedSpecies.clear();
	for (int k = 0; k < FNumSpecies(); k++) {
		GetSpecies(k)->MakeNeutral();
		SortedSpecies[GetSpecies(k)->FCode()] = GetSpecies(k);
		if (GetSpecies(k)->FFilename().compare("") == 0 || GetSpecies(k)->FFilename().compare("Unknown") == 0 || GetSpecies(k)->FFilename().compare("None") == 0) {
			string Filename(itoa((*SpeciesIT)->FEntry()));
			Filename.append(".mol");
			(*SpeciesIT)->SetFilename(Filename);
		}
		CheckSpeciesForSites((*SpeciesIT));
		SpeciesIT++;
	}
	PrintStructures(GetParameter("print mol").compare("1") == 0,GetParameter("print dat").compare("1") == 0);
	cout << 0 << "\t" << SpeciesList.size() << "\t" << ReactionList.size() << "\t0" << endl;
	//FLogFile() << 0 << "\t" << SpeciesList.size() << "\t" << ReactionList.size() << "\t0" << endl;
	time_t StartTime = time(NULL);
	SetEntry(-1);
	for (int i=0; i < RankLimit; i++) {
		//Store number of species before running the algorithm
		int NumSpecies = int(SpeciesList.size());
		int NumReaction = int(ReactionList.size());
		//Iterate through the operators
		list<ReactionOperator*>::iterator OpIT = OperatorList.begin();
		for (int j =0; j < int(OperatorList.size()); j++) {
			//Iterate through the species
			list<Species*>::iterator SpeciesIT = SpeciesList.begin();
			for (int k = 0; k < NumSpecies; k++) {
				//Only react the species created in the last generation
				if ((*SpeciesIT)->FGeneration() == i) {
					if (!(*OpIT)->FInstantaneous()) {
						(*OpIT)->DoReaction((*SpeciesIT), this, CarbonLimit);
					}
				}
				//Stopping the algorithm if I hit the compound limit
				if (FNumSpecies() > CompoundLimit) {
					FErrorFile() << "Hit compound limit before finishing generation " << i << "." << endl;
					k = NumSpecies;
					j = int(OperatorList.size());
					RankLimit = i-1;
				}
				//Stopping the algorithm if I hit the time limit
				if ((time(NULL)-StartTime) > MaximumNetGenTime && MaximumNetGenTime > 0) {
					FErrorFile() << "NetGen timed out on generation " << i << endl;
					k = NumSpecies;
					j = int(OperatorList.size());
					RankLimit = i-1;
				}
				SpeciesIT++;
			}
			OpIT++;
		}
		
		//Checking all of the new compounds for sites
		list<Species*>::iterator SpeciesIT = SpeciesList.begin();
		if (i+1 < RankLimit) {
			for (int k = 0; k < int(SpeciesList.size()); k++) {
				if ((*SpeciesIT)->FGeneration() == i+1) {
					CheckSpeciesForSites((*SpeciesIT));
				}
				SpeciesIT++;
				//Stopping the algorithm if I hit the time limit
				if ((time(NULL)-StartTime) > MaximumNetGenTime && MaximumNetGenTime > 0) {
					FErrorFile() << "NetGen timed out on generation " << i << endl;
					SetEntry(i);
					k = int(SpeciesList.size());
					RankLimit = i-1;
				}
			}
		}
		
		if (GetParameter("progressive print").compare("1") == 0) {
			PrintSystemFile(Filename, GetParameter("Data to print in reaction"),true,true,false,true);
		}

		cout << i+1 << "\t" << SpeciesList.size() << "\t" << ReactionList.size() << "\t" << (time(NULL)-StartTime) << endl;
		//FLogFile() << i+1 << "\t" << SpeciesList.size() << "\t" << ReactionList.size() << "\t" << (time(NULL)-StartTime) << endl;
		//Break out of the function if no new chemistry is evolved
		if (NumSpecies == int(SpeciesList.size()) && NumReaction == int(ReactionList.size())) {
			RankLimit = i-1;
		}
	}

	if (GetParameter("process through marvin").compare("1") == 0) {
		ProduceChargedMolfiles();
		string NewPath(GetParameter("output folder"));
		for (int i=0; i < FNumSpecies(); i++) {
			string NewFilename(NewPath);
			NewFilename.append(itoa(GetSpecies(i)->FEntry()));
			NewFilename.append(".mol");
			GetSpecies(i)->SetFilename(NewFilename);
			GetSpecies(i)->ClearAtomList(true);
			GetSpecies(i)->ReadStructure();
			GetSpecies(i)->PerformAllCalculations(GetParameter("label atoms with groups").compare("1") == 0,false, true, GetParameter("calculate properties from groups").compare("1") == 0, true);
		}
		if (GetParameter("balance reactions").compare("1") == 0) {
			for (int i=0; i < FNumReactions(); i++) {
				GetReaction(i)->BalanceReaction();
			}
		}
	}
}

void Data::BidirectionalNetGen(Data*& ForwardDB, Data*& ReverseDB, vector<Species*> CofactorCompounds, vector<Species*> StartCompounds, vector<Species*> TargetCompounds) {
	//If the databases donot exist, I create them. If they do exist, I clear the current data out of them
	if (ForwardDB == NULL) {
		ForwardDB = new Data(0);
		for (int i=0; i < int(CofactorCompounds.size()); i++) {
			ForwardDB->AddSpeciesNameCheck(CofactorCompounds[i]);
		}
		ForwardDB->LoadOperators();
	} else {
		ForwardDB->ClearCompounds();
		ForwardDB->ClearReactions();
		ForwardDB->ClearOperatorSites();
		for (int i=0; i < int(CofactorCompounds.size()); i++) {
			ForwardDB->AddSpeciesNameCheck(CofactorCompounds[i]);
		}
	}
	if (ReverseDB == NULL) {
		ReverseDB = new Data(0);
		for (int i=0; i < int(CofactorCompounds.size()); i++) {
			ReverseDB->AddSpeciesNameCheck(CofactorCompounds[i]);
		}
		ReverseDB->LoadOperators(RETROSYNTHESIS);
	} else {
		ReverseDB->ClearCompounds();
		ReverseDB->ClearReactions();
		ReverseDB->ClearOperatorSites();
		for (int i=0; i < int(CofactorCompounds.size()); i++) {
			ReverseDB->AddSpeciesNameCheck(CofactorCompounds[i]);
		}
	}

	//Now I add the start compounds to the forward databases and the target compounds to the reverse database
	for (int i=0; i < int(StartCompounds.size()); i++) {
		ForwardDB->AddSpecies(StartCompounds[i],false);
	}
	for (int i=0; i < int(TargetCompounds.size()); i++) {
		ReverseDB->AddSpecies(TargetCompounds[i],false);
	}

	//This functions runs the NetGen algorithm for the number of iterations specified on the reactants of every reaction in the database. Then it runs them on the products of every reaction in the database.
	cout << "Exploring forward:" << endl;
	ForwardDB->RunNetGenAlg(atoi(GetParameter("rank limit").data()),atoi(GetParameter("carbon limit").data()),atoi(GetParameter("compound limit").data()));
	cout << "Exploring backward:" << endl;
	ReverseDB->RunNetGenAlg(atoi(GetParameter("retro rank limit").data()),atoi(GetParameter("carbon limit").data()),atoi(GetParameter("compound limit").data()));
	//Now I combine the forward reactions with the reverse of the retrosynthesis reactions
	ReverseDB->ResetAllSpeciesMark(false);
	for (int i=0; i < ReverseDB->FNumSpecies(); i++) {
		if (ReverseDB->GetSpecies(i) == ForwardDB->AddSpecies(ReverseDB->GetSpecies(i),false)) {
			ReverseDB->GetSpecies(i)->SetMark(true);
		}
	}

	for (int i=0; i < ReverseDB->FNumReactions(); i++) {
		Reaction* NewReaction = new Reaction(ForwardDB->FNumReactions()+1,ForwardDB);
		for (int j=0; j < ReverseDB->GetReaction(i)->FNumReactants(); j++) {
			NewReaction->AddReactant(ForwardDB->GetSpeciesByCode(ReverseDB->GetReaction(i)->GetReactant(j)->FCode()),-ReverseDB->GetReaction(i)->GetReactantCoef(j),ReverseDB->GetReaction(i)->GetReactantCompartment(j));			
		}
		for (int j=0; j < ReverseDB->GetReaction(i)->FNumOperators(); j++) {
			NewReaction->AddOperator(ReverseDB->GetReaction(i)->GetOperator(j));
		}
		NewReaction->MakeCode();
		Reaction* Temp = ForwardDB->AddReaction(NewReaction);
		if (Temp != NewReaction) {
			delete NewReaction;
		}
	}
	ReverseDB->RemoveMarkedSpecies(false);
}

void Data::OperatorCheck() {
	int NoOperatorFound = 0;
	FLogFile() << "Entry;Name;Number of reactions;Operators;Exact match?;Forward match?" << endl;

	//First I replace all coa structures in the input data with CoA atom.
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->ReplaceFullCoAMoleculeWithCoAAtom();
		GetSpecies(i)->MakeNeutral();
		GetSpecies(i)->PerformAllCalculations(false,true,true,false,true);
	}

	//Next I set the nucleotides pairs in all of the reactions as cofactors
	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->SetNucleotideCofactors();
	}

	//Creating databases that will perform all the NetGen runs
	Data* StartCompoundDatabase = new Data(0);
	StartCompoundDatabase->LoadStartCompounds();
	Data* FowardReactionData = NULL;
	Data* ReverseReactionData = NULL;
	vector<Species*> CofactorCompounds;
	string MissingStructure("Missing structures");
	for (int j=0; j < StartCompoundDatabase->FNumSpecies(); j++) {
		StartCompoundDatabase->GetSpecies(j)->SetGeneration(0);
		CofactorCompounds.push_back(StartCompoundDatabase->GetSpecies(j));
	}
	for (int i=0; i < FNumReactions(); i++) {
		cout << "Currently attempting to reproduce reaction " << i << endl;
		if (GetReaction(i)->FNumOperators() == 0) {
			if (!GetReaction(i)->CheckForTransportOrStereo()) {
				vector<Species*> StartCompounds;
				vector<Species*> TargetCompounds;
				bool AllStructures = true;
				for (int j=0; j < GetReaction(i)->FNumReactants(); j++) {
					if (GetReaction(i)->GetReactantCompartment(j) < 1000) {
						if (GetReaction(i)->GetReactant(j)->FNumAtoms() == 0) {
							GetReaction(i)->AddOperator(MissingStructure);
							AllStructures = false;
							j = GetReaction(i)->FNumReactants();
						} else {
							GetReaction(i)->GetReactant(j)->SetGeneration(0);
							if (GetReaction(i)->GetReactantCoef(j) < 0) {
								StartCompounds.push_back(GetReaction(i)->GetReactant(j));
							} else { 
								TargetCompounds.push_back(GetReaction(i)->GetReactant(j));
							}
						}
					}
				}

				if (AllStructures) {
					bool ExactMatch = false;
					bool ForwardMatch = false;
					BidirectionalNetGen(FowardReactionData,ReverseReactionData,CofactorCompounds,StartCompounds,TargetCompounds);
					if (FowardReactionData->FEntry() != -1) {
						FLogFile() << GetReaction(i)->FEntry() << "|timed out in generation " << FowardReactionData->FEntry() << " of the forward NetGenAlgorithm" << endl;
					} 
					if (ReverseReactionData->FEntry() != -1) {
						FLogFile() << GetReaction(i)->FEntry() << "|timed out in generation " << ReverseReactionData->FEntry() << " of the retro NetGenAlgorithm" << endl;
					}
					FowardReactionData->AttemptToMatchReactionThree(GetReaction(i), ExactMatch, ForwardMatch,true);
					FowardReactionData->ResetAllReactionMark(false);
					ReverseReactionData->ResetAllReactionMark(false);
					FowardReactionData->ClearCompounds();
					FowardReactionData->ClearReactions();
					FowardReactionData->ClearOperatorSites();
					ReverseReactionData->ClearCompounds();
					ReverseReactionData->ClearReactions();
					ReverseReactionData->ClearOperatorSites();
				}	
			} else {
				FLogFile() << GetReaction(i)->FEntry() << ";" << GetReaction(i)->FName() << ";0;" << GetReaction(i)->FAllOperators() << ";y;y" << endl;
			}
		}
		if (GetReaction(i)->FNumOperators() == 0) {
			NoOperatorFound++;
		}
	}

	FLogFile() << "No operator assigned to " << NoOperatorFound << " potential reactions." << endl;

	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->SetEntry(i+1);
	}

	delete FowardReactionData;
	delete ReverseReactionData;
	delete StartCompoundDatabase;
}

bool Data::CheckSpeciesForSites(Species* InSpecies, bool InstantaneousOnly) {
	list<ReactionOperator*>::iterator OpIT = OperatorList.begin();
	bool SiteFound = false;
	for (int i =0; i < int(OperatorList.size()); i++) {
		//Iterate through the species
		if ((InstantaneousOnly && (*OpIT)->FInstantaneous()) || !InstantaneousOnly) {
			if ((*OpIT)->FindSites(InSpecies,atoi(GetParameter("carbon limit").data()))) {
				SiteFound = true;
			}
		}
		OpIT++;
	}
	return SiteFound;
}

void Data::DetermineAffectOfElimination(string OperatorName, int &TotalReactions, int &TotalCompounds) {
	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->SetMark(false);
		GetReaction(i)->SetKill(false);
		for (int j=0; j < GetReaction(i)->FNumOperators(); j++) {
			bool Match = false;
			vector<string>* Strings = StringToStrings(GetReaction(i)->GetOperator(j),"+");
			for (int k=0; k < int(Strings->size()); k++) {
				if ((*Strings)[k].compare(OperatorName) == 0) {
					Match = true;
				}
			}
			if (!Match) {
				GetReaction(i)->SetMark(true);
			}
		}
	}
	
	int MaxGeneration = 0;
	for (int i=0; i < FNumSpecies(); i++) {
		GetSpecies(i)->SetMark(false);
		GetSpecies(i)->SetKill(false);
		if (GetSpecies(i)->FGeneration() == 0) {
			GetSpecies(i)->SetMark(true);
		}
		if (GetSpecies(i)->FGeneration() > MaxGeneration) {
			MaxGeneration = GetSpecies(i)->FGeneration();
		}
	}

	bool NewMarks = false;
	for (int i=0; i < MaxGeneration; i++) {
		for (int i=0; i < FNumReactions(); i++) {
			if (GetReaction(i)->FMark()) {
				GetReaction(i)->MarkProducts();
			}
		}
		for (int i=0; i < FNumSpecies(); i++) {
			if (GetSpecies(i)->FKill()) {
				GetSpecies(i)->SetMark(true);
			}
		}
	}

	TotalCompounds = 0;
	for (int i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FMark()) {
			TotalCompounds++;
		}
	}
	TotalReactions = 0;
	for (int i=0; i < FNumReactions(); i++) {
		if (GetReaction(i)->FKill()) {
			TotalReactions++;
		}
	}
}

//This function is used to determine if a single reaction matches the input reaction
bool Data::AttemptOneToOneReactionMatching(Reaction* InReaction, bool &ExactMatch, bool &ForwardMatch, bool PrintToLogfile) {
	bool AllSpeciesPresent = true;
	ExactMatch = false;
	ForwardMatch = false;
	Reaction* BestMatch = NULL;
	Reaction* TargetReaction = new Reaction(0,this);
	for (int i=0; i < InReaction->FNumReactants(); i++) {
		Species* Temp = GetSpeciesByCode(InReaction->GetReactant(i)->FCode());
		if (Temp == NULL && InReaction->GetReactantCompartment(i) >= 1000) {
			AllSpeciesPresent = false;
		} else if (Temp == NULL && InReaction->GetReactantCompartment(i) < 1000) {
			delete TargetReaction;
			return false;
		} else {
			TargetReaction->AddReactant(InReaction->GetReactant(i),InReaction->GetReactantCoef(i),InReaction->GetReactantCompartment(i));
		}
	}
	
	vector<string> CandidateStrings;
	vector<bool> ExactMatches;
	vector<bool> ForwardMatches;
	if (AllSpeciesPresent) {
		TargetReaction->MakeCode();
		CandidateStrings.push_back(TargetReaction->FCode());
		TargetReaction->ReverseCode();
		CandidateStrings.push_back(TargetReaction->FCode());
		ExactMatches.push_back(true);
		ExactMatches.push_back(true);
		ForwardMatches.push_back(true);
		ForwardMatches.push_back(false);
	}

	TargetReaction->MakeCode(NO_COFACTOR);
	if (!AllSpeciesPresent || TargetReaction->FCode().compare(CandidateStrings[0]) != 0) {
		CandidateStrings.push_back(TargetReaction->FCode());
		ExactMatches.push_back(false);
		ForwardMatches.push_back(true);
	}
	TargetReaction->ReverseCode(NO_COFACTOR);
	if (!AllSpeciesPresent || TargetReaction->FCode().compare(CandidateStrings[1]) != 0) {
		CandidateStrings.push_back(TargetReaction->FCode());
		ExactMatches.push_back(false);
		ForwardMatches.push_back(false);
	}
	
	for (int i=0; i < FNumReactions(); i++) {
		GetReaction(i)->MakeCode();
		for (int j=0; j < int(CandidateStrings.size()); j++) {
			if (ExactMatches[j] && ForwardMatches[j]) {
				if (GetReaction(i)->FCode().compare(CandidateStrings[j]) == 0) {
					ExactMatch = true;
					ForwardMatch = true;
					InReaction->AddOperator(GetReaction(i)->FAllOperators());
					if (PrintToLogfile) {
						FLogFile() << InReaction->FEntry() << ";" << InReaction->FName() << ";" << 1 << ";" << InReaction->FAllOperators() << ";y;y" << endl; 
					}
					return true;
				}
			} else if (BestMatch == NULL || (ExactMatches[j] && !ExactMatch) || (!ExactMatch && ForwardMatches[j] && !ForwardMatch))  {
				if (GetReaction(i)->FCode().compare(CandidateStrings[j]) == 0) {
					ExactMatch = ExactMatches[j];
					ForwardMatch = ForwardMatches[j];
					BestMatch = GetReaction(i);
				}
			} 
		}
	}
	
	if (BestMatch != NULL) {
		//Potential single matching reaction found
		InReaction->AddOperator(BestMatch->FAllOperators());
		if (PrintToLogfile) {
			FLogFile() << InReaction->FEntry() << ";" << InReaction->FName() << ";" << 1 << ";" << InReaction->FAllOperators();
			if (ExactMatch) {
				FLogFile() << ";y;n" << endl; 
			} else if (ForwardMatch) {
				FLogFile() << ";n;y" << endl; 
			} else {
				FLogFile() << ";n;n" << endl; 
			}
		}
		return true;
	} else {
		//No single matching reaction found	
		return false;
	}
}

void Data::AttemptToMatchReactionTwo(Reaction* InReaction, int NumberOfCombinations) {
	//This is a far less naive, but far more complicated function for finding a reaction combination that matches the input reaction
	//This function involves finding all of the linear pathways from each of the reactants to each of the products
	//The the overall reactions for all pathways found are compared to the input reaction, then combined and compared to the input reaction
	//I added the time schemes to prevent certain challenging reactions from slowing down the mapping process as a whole
	double ReactionMatchingTimeout = atof(GetParameter("maximum time to spend matching reaction").data());
	time_t StartTime = time(NULL);
	SetEntry(-1);

	//Step one: load the products of the input reaction into the target reaction and the list of pathway targets
	vector<Species*> Targets;
	Reaction* TargetReaction = new Reaction(0,this);
	for (int i=InReaction->FNumReactants(REACTANT); i < InReaction->FNumReactants(); i++) {
		if (InReaction->GetReactantCompartment(i) > 0) {
			Species* CurrentProduct = GetSpeciesByCode(InReaction->GetReactant(i)->FCode());
			if (CurrentProduct != NULL) {
				TargetReaction->AddReactant(CurrentProduct,InReaction->GetReactantCoef(i),GetCompartment("c")->Index);
				Targets.push_back(CurrentProduct);
			} else {
				FErrorFile() << "Not all products found in the NetGen network generated while recreating reaction: " << InReaction->FName() << " (" << InReaction->FEntry() << "). This should not happen." << endl;
				return;
			}
		}
	}
	
	//Step two: load the reactants of the input reaction into the target reaction (this loading is done by stringcode in case the compounds in the input reaction are a different instance of the compounds in the database
	for (int i=0; i < InReaction->FNumReactants(REACTANT); i++) {
		if (InReaction->GetReactantCompartment(i) > 0) {
			Species* CurrentProduct = GetSpeciesByCode(InReaction->GetReactant(i)->FCode());
			if (CurrentProduct != NULL) {
				TargetReaction->AddReactant(CurrentProduct,InReaction->GetReactantCoef(i),GetCompartment("c")->Index);
			} else {
				FErrorFile() << "Not all reactants found in the NetGen network generated while recreating reaction: " << InReaction->FName() << " (" << InReaction->FEntry() << "). This should not happen." << endl;
				return;
			}
		}
	}

	//Step three: prepare a bunch of datastructures that will allow me to gather all of the pathway data in an organized manner
	//I have the target reaction make its code based on the compound entry numbers
	TargetReaction->MakeCode(NO_COFACTOR);
	//This is a map mapping the reaction codes for the pathway overall reactions to the overall reaction pointers
	map<string, Reaction*,std::less<string> > OverallReactionCodes;
	//This is a map mapping the strings that specify the pathways uniquely to the overall reactions for the pathways
	map<string, Pathway*,std::less<string> > PathwayCodes;

	//I store my target reaction in the reaction codes map so I can identify pathways whose overall reaction matches the target reaction immediately
	OverallReactionCodes[TargetReaction->FCode()] = TargetReaction;
	
	//Step four: find every linear pathway from each reactant to each product, and compare the resulting overall reactions with the target reaction
	string EquationType;
	for (int i=0; i < TargetReaction->FNumReactants(REACTANT); i++) {
		map<Species* , list<Pathway*> >* Pathways = FindPathways(TargetReaction->GetReactant(i),Targets,NumberOfCombinations,-1,true,1);
		for (int j=0; j < int(Targets.size()); j++) {
			list<Pathway*> PathList = (*Pathways)[Targets[j]];
			list<Pathway*>::iterator ListIT = PathList.begin();
			for (int k=0; k < int(PathList.size()); k++) {
				string PathCode;
				for (int l=0; l < (*ListIT)->Length; l++) {
					PathCode.append(itoa((*ListIT)->Reactions[l]->FEntry()));
					PathCode.append(";");
				}
				Pathway* MatchingPathway = PathwayCodes[PathCode];
				if (MatchingPathway == NULL) {
					PathwayCodes[PathCode] = (*ListIT);
					Reaction* OverallReaction = new Reaction(0,this);
					for (int l=0; l < (*ListIT)->Length; l++) {
						for (int m=0; m < (*ListIT)->Reactions[l]->FNumReactants(); m++) {
							if ((*ListIT)->Directions[l]) {
								OverallReaction->AddReactant((*ListIT)->Reactions[l]->GetReactant(m),(*ListIT)->Reactions[l]->GetReactantCoef(m),(*ListIT)->Reactions[l]->GetReactantCompartment(m));
							} else {
								OverallReaction->AddReactant((*ListIT)->Reactions[l]->GetReactant(m),-(*ListIT)->Reactions[l]->GetReactantCoef(m),(*ListIT)->Reactions[l]->GetReactantCompartment(m));
							}
						}
					}
					OverallReaction->MakeCode(NO_COFACTOR);
					Reaction* TempReaction = OverallReactionCodes[OverallReaction->FCode()];
					if (TempReaction == NULL) {
						OverallReactionCodes[OverallReaction->FCode()] = OverallReaction;
						OverallReaction->AddPathway((*ListIT),true);
					} else {
						if (TempReaction == TargetReaction) {
							FLogFile() << InReaction->FEntry() << "|" << InReaction->CreateReactionEquation(EquationType.assign("name")) << "|" << OverallReaction->CreateReactionEquation(EquationType.assign("name")) << "|";
							FLogFile() << "{";
							for (int m=0; m < (*ListIT)->Length; m++) {
								FLogFile() << (*ListIT)->Reactions[m]->FAllOperators();
								if ((*ListIT)->Directions[m] == false) {
									FLogFile() << "(r)";
								}
								if (m+1 < (*ListIT)->Length) {
									FLogFile() << "-->";
								}
							}
							FLogFile() << "}|" << (*ListIT)->Length << "|single pathway match" <<  endl;
						}
						delete OverallReaction;
						OverallReaction = TempReaction;
						OverallReaction->AddPathway((*ListIT),true);
						if (TempReaction == TargetReaction) {
							if (NumberOfCombinations > TargetReaction->FPathwayLength()) {
								NumberOfCombinations = TargetReaction->FPathwayLength();
							}
						}
					}
				} else {
					//If two stereo isomers are produced in one reaction, it may be added twice to the target array
					//Thus the pathways would match, and we don't want to erase the reactions
					if (MatchingPathway != (*ListIT)) {
						delete [] (*ListIT)->Intermediates;
						delete [] (*ListIT)->Reactions;
						delete [] (*ListIT)->Directions;
						delete (*ListIT);
					}
				}
				ListIT++;
			}
			if ((time(NULL)-StartTime) > ReactionMatchingTimeout && ReactionMatchingTimeout > 0) {
				FLogFile() << InReaction->FEntry() << "|timed out during pathway determination phase" << endl;
				SetEntry(0);
				j = int(Targets.size());
				i = TargetReaction->FNumReactants(REACTANT);
			}
		}
		delete Pathways;
	}

	//Step five: If none of the single pathway overall reactions matched exactly, then add the overall reactions from multiple pathways together until you reproduce your target reaction
	cout << "Number of overall reactions: " << OverallReactionCodes.size() << endl;
	if (FEntry() < 0) {
		//First I check to see if the target reaction was the overall reaction for any pathways
		if (TargetReaction->FNumLinearPathways() > 0) {
			//The target reaction does have operators. I transfer these to the input reaction.
			TargetReaction->SetOperatorsFromPathway();
			for (int i=0; i < TargetReaction->FNumOperators(); i++) {
				InReaction->AddOperator(TargetReaction->GetOperator(i));
			}
		} else if (OverallReactionCodes.size() > 1) {
			//I populate a vector with my overall reactions
			bool** SpeciesPresent = new bool*[int(OverallReactionCodes.size())-1];
			vector<Reaction*> OverallReactions(int(OverallReactionCodes.size()-1));
			map<string, Reaction* >::iterator MapIT = OverallReactionCodes.begin();
			int Count = 0;
			for (int i=0; i < int(OverallReactionCodes.size()); i++) {
				if (MapIT->second != TargetReaction) {				
					SpeciesPresent[Count] = new bool[TargetReaction->FNumReactants()];
					OverallReactions[Count] = MapIT->second;
					OverallReactions[Count]->SetOperatorsFromPathway();
					bool EverFalse = false;
					for (int j=0; j < TargetReaction->FNumReactants(); j++) {
						if (OverallReactions[Count]->CheckForReactant(TargetReaction->GetReactant(j)) == -1) {
							SpeciesPresent[Count][j] = false;
							EverFalse = true;
						} else {
							SpeciesPresent[Count][j] = true;
						}
					}			
					if (!EverFalse) {
						FErrorFile() << "Houston, we have a problem with our algorithm. Complete match found with extra species for reaction " << InReaction->FEntry() << " " << InReaction->FName() << endl;
					}
					Count++;
				}
				MapIT++;
			}
			sort(OverallReactions.begin( ),OverallReactions.end( ), ReactionPathwayShorter);
		
			vector<int> IndeciesOfCombinedReactions(NumberOfCombinations);
			int CurrentMaxLength = 2*OverallReactions[0]->FPathwayLength();
			bool MatchFound = false;
			bool Continue = true;
			do {
				Continue = true;
				int CurrentIndex = 0;
				for (int i=0; i < NumberOfCombinations; i++) {
					IndeciesOfCombinedReactions[i] = -1;
				}
				IndeciesOfCombinedReactions[0] = 0;
				int CurrentLength = OverallReactions[IndeciesOfCombinedReactions[CurrentIndex]]->FPathwayLength();
				do {
					while(IndeciesOfCombinedReactions[CurrentIndex] >= int(OverallReactions.size()) && CurrentIndex >= 0) {
						IndeciesOfCombinedReactions[CurrentIndex] = -1;
						CurrentIndex--;
						if (CurrentIndex >= 0) {
							IndeciesOfCombinedReactions[CurrentIndex]++;
						}
					}
					CurrentLength = 0;
					for (int i=0; i < NumberOfCombinations; i++) {
						if (IndeciesOfCombinedReactions[i] == -1) {
							i = NumberOfCombinations;
						} else {
							CurrentLength += OverallReactions[IndeciesOfCombinedReactions[i]]->FPathwayLength();
						}
					}
					while (CurrentLength != CurrentMaxLength && CurrentIndex >= 0) {
						if (CurrentLength < CurrentMaxLength && IndeciesOfCombinedReactions[CurrentIndex] < int(OverallReactions.size()-1)) {
							IndeciesOfCombinedReactions[CurrentIndex+1]=IndeciesOfCombinedReactions[CurrentIndex]+1;
							CurrentLength += OverallReactions[IndeciesOfCombinedReactions[CurrentIndex+1]]->FPathwayLength();
							CurrentIndex++;
						} else {
							IndeciesOfCombinedReactions[CurrentIndex] = -1;
							CurrentIndex--;
							if (CurrentIndex >= 0) {
								IndeciesOfCombinedReactions[CurrentIndex]++;
							}
						} 
					}
					if (CurrentLength != CurrentMaxLength || CurrentIndex < 0) {
						Continue = false;
					} else {
						bool AllSpeciesPresent = true;
						for (int i=0; i < TargetReaction->FNumReactants(); i++) {
							bool AnyTrue = false;
							for (int j=0; j <= CurrentIndex; j++) {
								if (SpeciesPresent[IndeciesOfCombinedReactions[j]]) {
									AnyTrue = true;	
									j = CurrentIndex+1;
								}
							}
							if (!AnyTrue) {
								AllSpeciesPresent = false;
								i = TargetReaction->FNumReactants();
							}
						}
						
						if (AllSpeciesPresent) {
							Reaction* NewReaction = new Reaction(0,this);
							for (int i=0; i <= CurrentIndex; i++) {
								for (int j=0; j < OverallReactions[IndeciesOfCombinedReactions[i]]->FNumReactants(); j++) {
									NewReaction->AddReactant(OverallReactions[IndeciesOfCombinedReactions[i]]->GetReactant(j),OverallReactions[IndeciesOfCombinedReactions[i]]->GetReactantCoef(j),OverallReactions[IndeciesOfCombinedReactions[i]]->GetReactantCompartment(j));
								}
							}
							NewReaction->MakeCode(NO_COFACTOR);
							if (NewReaction->FCode().compare(TargetReaction->FCode()) == 0) {
								MatchFound = true;
								string Operator;
								FLogFile() << InReaction->FEntry() << "|" << InReaction->CreateReactionEquation(EquationType.assign("name")) << "|" << NewReaction->CreateReactionEquation(EquationType.assign("name")) << "|";
								for (int i=0; i < NumberOfCombinations; i++) {
									if (IndeciesOfCombinedReactions[i] >=0) {
										Operator.append("{");
										for (int j=0; j < OverallReactions[IndeciesOfCombinedReactions[i]]->FNumOperators(); j++) {
											Operator.append(OverallReactions[IndeciesOfCombinedReactions[i]]->GetOperator(j));
											if (j < (OverallReactions[IndeciesOfCombinedReactions[i]]->FNumOperators()-1)) {
												Operator.append("/");
											}
										}
										Operator.append("}");
										if (i < (CurrentIndex-1)) {
											Operator.append("+");
										}
									}
								}
								FLogFile() << Operator << "|" << CurrentMaxLength << "|multi pathway match" << endl;
								InReaction->AddOperator(Operator);
							} else {
								//Here I deal with the possibility of two pathways sharing the same reaction (overlapping pathways)
								vector<Reaction*> RepeatedReactions;
								//This structure tracks the combinations of pathways I have tested
								//There are multiple combinations because each overall reaction may be associated with multiple pathways
								//I must check every possible combination of the multiple pathways
								int* PathwayIndecies = new int[CurrentIndex+1];
								for (int i=0; i <= CurrentIndex; i++) {
									PathwayIndecies[i] = 0;
								}
								int CursorPosition = CurrentIndex;
								
								do {
									//First I check to see if a reaction is used twice in the current combination of pathways
									vector<Reaction*> RepeatedReactions;
									vector<bool> RepeatedReactionDirections;
									ResetAllReactionKill(false);
									for (int i=0; i <= CurrentIndex; i++) {
										for (int j=0; j< OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Length; j++) {
											if (!OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Reactions[j]->FKill()) {
												OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Reactions[j]->SetKill(true);
											} else {
												RepeatedReactions.push_back(OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Reactions[j]);
												RepeatedReactionDirections.push_back(OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Directions[j]);
											}
										}
									}
									
									if (RepeatedReactions.size() > 0) {
										//If there are repeated reactions, I remove their stoichiometry from the overall reaction and check again for a match
										ResetAllReactionKill(false);
										for (int i=0; i < int(RepeatedReactions.size()); i++) {
											RepeatedReactions[i]->SetKill(true);
											for (int j=0; j < RepeatedReactions[i]->FNumReactants(); j++) {
												if (RepeatedReactionDirections[i]) {
													NewReaction->AddReactant(RepeatedReactions[i]->GetReactant(j),-RepeatedReactions[i]->GetReactantCoef(j),RepeatedReactions[i]->GetReactantCompartment(j));
												} else {
													NewReaction->AddReactant(RepeatedReactions[i]->GetReactant(j),RepeatedReactions[i]->GetReactantCoef(j),RepeatedReactions[i]->GetReactantCompartment(j));
												}
											}
										}
										
										//I check again for a match
										NewReaction->MakeCode(NO_COFACTOR);
										if (NewReaction->FCode().compare(TargetReaction->FCode()) == 0) {
											string Operator;
											FLogFile() << InReaction->FEntry() << "|" << InReaction->CreateReactionEquation(EquationType.assign("name")) << "|" << NewReaction->CreateReactionEquation(EquationType.assign("name")) << "|";
											MatchFound = true;
											int BranchingLength = 0;
											for (int i=0; i < NumberOfCombinations; i++) {
												if (IndeciesOfCombinedReactions[i] >=0) {
													Operator.append("{");
													for (int j=0; j < OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Length; j++) {
														//I removed any instance of any of the repeated reactions from the operator initially
														if (!OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Reactions[j]->FKill()) {
															Operator.append(OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Reactions[j]->FAllOperators());
															if (!OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Directions[j]) {
																Operator.append("(r)");	
															}
															BranchingLength++;
														}
														if (j < OverallReactions[IndeciesOfCombinedReactions[i]]->GetLinearPathway(PathwayIndecies[i])->Length-1) {
															Operator.append("-->");
														}
													}
													Operator.append("}+");
												}
											}
											//Now I add a single instance of each repeated reaction to the operator instead of multiple instances
											for (int i=0; i < int(RepeatedReactions.size()); i++) {
												//This if statement is here because it is possible for a repeated reaction to be repeated more than 2 times.
												if (RepeatedReactions[i]->FKill()) {
													BranchingLength++;
													RepeatedReactions[i]->SetKill(false);
													Operator.append("B[");
													Operator.append(RepeatedReactions[i]->FAllOperators());
													if (!RepeatedReactionDirections[i]) {
														Operator.append("(r)");
													}
													Operator.append("]");
													if (i < int(RepeatedReactions.size()-1)) {
														Operator.append("+");
													}
												}
											}
											InReaction->AddOperator(Operator);
											FLogFile() << Operator << "|" << BranchingLength << "|multi pathway with branching" << endl;
										}
										//Now I undo the changes I made to NewReaction
										for (int i=0; i < int(RepeatedReactions.size()); i++) {
											for (int j=0; j < RepeatedReactions[i]->FNumReactants(); j++) {
												if (RepeatedReactionDirections[i]) {
													NewReaction->AddReactant(RepeatedReactions[i]->GetReactant(j),RepeatedReactions[i]->GetReactantCoef(j),RepeatedReactions[i]->GetReactantCompartment(j));
												} else {
													NewReaction->AddReactant(RepeatedReactions[i]->GetReactant(j),-RepeatedReactions[i]->GetReactantCoef(j),RepeatedReactions[i]->GetReactantCompartment(j));
												}
											}
										}
									}

									//I iterate to a new combination of pathways
									CursorPosition = CurrentIndex;
									do {
										if ((PathwayIndecies[CursorPosition]+1) >= OverallReactions[IndeciesOfCombinedReactions[CursorPosition]]->FNumLinearPathways()) {
											PathwayIndecies[CursorPosition] = -1;
											CursorPosition--;
										} else {
											PathwayIndecies[CursorPosition]++;
											CursorPosition++;
										}
									} while(CursorPosition < CurrentIndex && CursorPosition != -1);
								} while(CursorPosition != -1);
								delete [] PathwayIndecies;
							} //Ending the check for overlapping pathways
							delete NewReaction;
						}
						IndeciesOfCombinedReactions[CurrentIndex]++;
					}
					if ((time(NULL)-StartTime) > ReactionMatchingTimeout && ReactionMatchingTimeout > 0) {
						FLogFile() << InReaction->FEntry() << "|timed out during overall reaction combination phase" << endl;
						Continue = false;
						CurrentMaxLength = NumberOfCombinations+1;
					}
				} while (Continue);
				CurrentMaxLength++;
			} while (CurrentMaxLength <= NumberOfCombinations && !MatchFound);

			for (int i=0; i < int(OverallReactions.size()); i++) {
				delete [] SpeciesPresent[i];
			}
			delete [] SpeciesPresent;
		}
	}
	
	//I have to reset the generation on all target reaction compounds to zero so they will not be erased
	for (int i=0; i < TargetReaction->FNumReactants(); i++) {
		TargetReaction->GetReactant(i)->SetGeneration(0);
	}

	//I remove all of the overall reactions from memory which includes the target reaction
	//All of the pathways are deleted with their overall reactions
	map<string, Reaction* >::iterator MapIT = OverallReactionCodes.begin();
	for (int i=0; i < int(OverallReactionCodes.size()); i++) {
		delete MapIT->second;
		MapIT++;
	}
}

void Data::AttemptToMatchReactionThree(Reaction* InReaction, bool &ExactMatch, bool &ForwardMatch, bool PrintToLogfile) {
	MFAProblem* NewProblem = new MFAProblem();
	NewProblem->MFAMatchReaction(this,InReaction,ExactMatch,ForwardMatch,PrintToLogfile);
	delete NewProblem;
}

void Data::GenerateReverseOperators() {
	if (FNumOperators() == 0) {
		LoadOperators();
	}
	for (int i=0; i < FNumOperators(); i++) {
		GetOperator(i)->ConvertToReverseOperator();
		GetOperator(i)->PrintReactionOperator();
	}
};

void Data::GenerateRunStatistics(string Filename) {
	Filename.insert(0,"Stats");
	Filename.insert(0,FOutputFilepath());
	Filename.append(".txt");

	ofstream Output;
	if (!OpenOutput(Output,Filename)) {
		return;
	}

	int NumKeggCompounds = 0;
	int NumKeggReactions = 0;
	int NumCASCompounds = 0;
	int NumEcoliCompounds = 0;
	int NumEcoliReactions = 0;
	int CurrentGeneration = 0;
	vector<int> Generation;
	vector<int> Compounds;
	vector<int> Reactions;
	vector<int> KeggCompounds;
	vector<int> EcoliCompounds;
	vector<int> CASCompounds;
	vector<int> KeggReactions;
	vector<int> EcoliReactions;
	int i;
	for (i=0; i < FNumSpecies(); i++) {
		if (GetSpecies(i)->FGeneration() > CurrentGeneration) {
			CASCompounds.push_back(NumCASCompounds);
			Generation.push_back(CurrentGeneration);
			Compounds.push_back(i);
			KeggCompounds.push_back(NumKeggCompounds);
			EcoliCompounds.push_back(NumEcoliCompounds);
			CurrentGeneration++;
		}
		if (GetSpecies(i)->GetDatabaseID("KEGG").compare("") != 0) {
			NumKeggCompounds++;
		}
		if (GetSpecies(i)->GetDatabaseID("CAS").compare("") != 0) {
			NumCASCompounds++;
		}
		if (GetSpecies(i)->GetDatabaseID("IAFMODEL").compare("") != 0) {
			NumEcoliCompounds++;
		}
	}
	CASCompounds.push_back(NumCASCompounds);
	Generation.push_back(CurrentGeneration);
	Compounds.push_back(i);
	KeggCompounds.push_back(NumKeggCompounds);
	EcoliCompounds.push_back(NumEcoliCompounds);

	CurrentGeneration = 0;
	for (i=0; i < FNumReactions(); i++) {
		if (GetReaction(i)->FGeneration() > CurrentGeneration) {
			CurrentGeneration++;
			Reactions.push_back(i);
			KeggReactions.push_back(NumKeggReactions);
			EcoliReactions.push_back(NumEcoliReactions);
		}
		if (GetReaction(i)->GetDatabaseID("KEGG").compare("") != 0) {
			NumKeggReactions++;
		}
		if (GetReaction(i)->GetDatabaseID("IAFMODEL").compare("") != 0) {
			NumEcoliReactions++;
		}
	}
	Reactions.push_back(i);
	KeggReactions.push_back(NumKeggReactions);
	EcoliReactions.push_back(NumEcoliReactions);
	
	Output << "Total compound statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << Compounds[i] << " ";
	}
	Output << endl;
	Output << "KEGG compound statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << KeggCompounds[i] << " ";
	}
	Output << endl;
	Output << "CAS compound statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << CASCompounds[i] << " ";
	}
	Output << endl;
	Output << "Ecoli compound statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << EcoliCompounds[i] << " ";
	}
	Output << endl;
	Output << "Total reaction statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << Reactions[i] << " ";
	}
	Output << endl;
	Output << "KEGG reaction statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << KeggReactions[i] << " ";
	}
	Output << endl;
	Output << "Ecoli reaction statistics:" << endl;
	for (i=0; i < int(Generation.size()); i++) {
		Output << EcoliReactions[i] << " ";
	}
	Output << endl;
	Output << "Operator_name Reactions_generated_by_this_operator Total_compounds_if_eliminated Total_reactions_if_eliminated" << endl;
	for (i=0; i < FNumOperators(); i++) {
		int TotalReactionsIfEliminated = 0;
		int TotalCompoundsIfEliminated = 0;
		DetermineAffectOfElimination(GetOperator(i)->FName(), TotalReactionsIfEliminated, TotalCompoundsIfEliminated);
		Output << GetOperator(i)->FName() << " " << GetOperator(i)->FNumReactions() << " " << TotalCompoundsIfEliminated << " " << TotalReactionsIfEliminated << endl;
	}

	Output.close();
}

