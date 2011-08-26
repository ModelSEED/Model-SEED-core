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

//This is the constructor for the atom type. It loads in the data.
AtomType::AtomType(string InID, int InMass, int InValence, int InExpectedBonds, int InIndex){
	ID.assign(InID);
	Mass = InMass;
	ExpectedBondNumber = InExpectedBonds;
	ValenceElectrons = InValence;
	Index = InIndex;
	AtomAlternatives = NULL;

	//If the atom can be a number of different types, this parses the string where the allowable types are delimited by a ";"
	if (InID.find(";") != -1) {
		AtomAlternatives = StringToStrings(InID,";");
	}
};

//Destroying the dynamically alocated string vector in the destructor
AtomType::~AtomType(){
	if (AtomAlternatives != NULL) {
		delete AtomAlternatives;
	}
};

//Input
void AtomType::SetIndex(int InIndex) {
	Index = InIndex;
}

//Output
int AtomType::FMass(){
	return Mass;
};

int AtomType::FValence(){
	return ValenceElectrons;
};

string AtomType::FID(){
	return ID;
};

//This compares the atomtypes looking for wildcards.
bool AtomType::CompareType(AtomType* InType) {
	if (InType->FID().compare(FID()) == 0) {
		return true;
	}
	 
	//Checking for special W wildcard
	if (InType->FID().compare("W") == 0) {
		if (FID().compare("H") != 0) {
			return true;
		}
		else {
			return false;
		}
	}

	//Checking for wildcards
	if (FNumAtomAlternatives() == 0 && InType->FNumAtomAlternatives() == 0) {
		return false;
	}

	//Dealing with wildcards if they exist
	if (FNumAtomAlternatives() == 0) {
		for (int i=0; i < InType->FNumAtomAlternatives(); i++) {
			if (FID().compare(InType->GetAlternative(i)) == 0) {
				return true;
			}
		}
		return false;
	}
	if (InType->FNumAtomAlternatives() == 0) {
		for (int i=0; i < FNumAtomAlternatives(); i++) {
			if (GetAlternative(i).compare(InType->FID()) == 0) {
				return true;
			}
		}
		return false;
	}
	for (int i=0; i < InType->FNumAtomAlternatives(); i++) {
		for (int j=0; j < FNumAtomAlternatives(); j++) {
			if (GetAlternative(j).compare(InType->GetAlternative(i)) == 0) {
				return true;
			}
		}
	}
	return false;
};

int AtomType::FIndex() {
	return Index;
};

int AtomType::FExpectedBondNumber(int NumberOfBonds) {
	//Sometimes atoms can have multiple electron states and multiple bond expectations. This code deals with this instance.
	//For example, nitrogen can be bonded to either 3 or 5 things.
	if (ExpectedBondNumber >= 10) {
		double ExpectedBonds = ExpectedBondNumber;
		double Remainder = 0;
		do {
			Remainder = ExpectedBonds - floor(double(ExpectedBonds/10))*10;
			if (NumberOfBonds >= Remainder) {
				return int(Remainder);
			}
			ExpectedBonds = floor(double(ExpectedBonds/10));
		} while(ExpectedBonds > 0);
		return int(Remainder);
	}
	return ExpectedBondNumber;
};

int AtomType::FNumAtomAlternatives() {
	if (AtomAlternatives == NULL) {
		return 0;
	}

	return int(AtomAlternatives->size());
}
	
string AtomType::GetAlternative(int InIndex) {
	return (*AtomAlternatives)[InIndex];
}

//this just returns a true if this is a wildcard atom that can be a hydrogen
bool AtomType::HAlternative() {
	for (int i=0; i < FNumAtomAlternatives(); i++) {
		if (GetAlternative(i).compare("H") == 0){
			return true;
		}
	}
	return false;
}
