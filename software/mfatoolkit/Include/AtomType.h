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

#ifndef ATOMTYPE_H
#define ATOMTYPE_H

class AtomType {
private:
	//ID of the atom type (C for carbon, N for nitrogen etc)
	string ID;
	//Mass of atom type
	int Mass;
	//Expected number of bonds for atom type
	int ExpectedBondNumber;
	//Number of valence electrons for atom type
	int ValenceElectrons;
	//This is just an index of the atom type in the main datastructure
	int Index;
	//Sometimes the atom type is a restricted wild. The ID of this atom type can be any of the strings in this vector.
	vector<string>* AtomAlternatives;
public:
	AtomType(string InID, int InMass, int InValence, int InExpectedBonds, int InIndex);
	~AtomType();

	//Input
	void SetIndex(int InIndex);

	//Output
	int FMass();
	int FValence();
	int FExpectedBondNumber(int NumberOfBonds);
	int FIndex();
	string FID();
	bool CompareType(AtomType* InType);
	int FNumAtomAlternatives();
	string GetAlternative(int InIndex);
	bool HAlternative();
};

#endif
