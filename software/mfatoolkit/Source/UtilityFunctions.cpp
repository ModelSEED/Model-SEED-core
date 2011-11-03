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

string itoaString;

vector<double> TimeOutTime;
vector<double> StartTime;

map<string, vector<string>, std::less<string> > FileLineData;

const char* itoa(int InNum) {
	ostringstream strout;
	strout << InNum;
	itoaString = strout.str();
	return itoaString.data();
}

const char* dtoa(double InNum) {
	ostringstream strout;
	strout << InNum;
	itoaString = strout.str();
	return itoaString.data();
}

string FDate() {
	time_t rawtime;
	struct tm* timeinfo;
	time(&rawtime);
	timeinfo = localtime(&rawtime);
	
	ostringstream strout;
	
	strout << (1900+timeinfo->tm_year);
	if(timeinfo->tm_mon < 10) {
		strout << 0 << (timeinfo->tm_mon+1);
	}
	else {
		strout << (timeinfo->tm_mon+1);
	}
	if(timeinfo->tm_mday < 10) {
		strout << 0 << timeinfo->tm_mday;
	}
	else {
		strout << timeinfo->tm_mday;
	}
	
	string Time = strout.str();
	return Time;
};

string GetFileLine(ifstream &Input) {
	string Buff; 
	getline( Input, Buff );
	return Buff;
}

string CheckFilename(string Filename) {
	if (Filename.substr(1,1).compare(":") != 0 && Filename.substr(0,1).compare("/") != 0) {
		Filename.insert(0,FProgramPath());
	}
	if (Filename.substr(0,12).compare("/cygdrive/c/") == 0) {
		Filename = "C:/" + Filename.substr(12);
	}
	return Filename;
}

vector<string>* GetStringsFileline(ifstream &Input, const char* Delim, bool TreatConsecutiveDelimAsOne) {
	string Buff = GetFileLine(Input);
	return StringToStrings(Buff, Delim, TreatConsecutiveDelimAsOne);
}

vector<string>* StringToStrings(string FullString, const char* Delim, bool TreatConsecutiveDelimAsOne) {
	vector<string>* NewVect = new vector<string>;
	string Buff(FullString);

	int Location;
	do {
		Location = int(Buff.find_first_of(Delim));
		if (Location != -1) {
			if (Location == 0) {
				if (!TreatConsecutiveDelimAsOne) {
					string NewString;
					NewVect->push_back(NewString);
				}
				Buff = Buff.substr(Location+1, Buff.length()-(Location+1));
			} else {
				string NewString = Buff.substr(0, Location);
				NewVect->push_back(NewString);
				Buff = Buff.substr(Location+1, Buff.length()-(Location+1));
			}
		}
	} while(Location != -1);
	
	if (Buff.length() != 0 || !TreatConsecutiveDelimAsOne) {
		NewVect->push_back(Buff);
	}
	
	return NewVect;
}

void findandreplace(string &source, string find, string replace) {
	size_t j;
	for (;(j = source.find( find )) != source.npos;) {
		source.replace( j, find.length(), replace );
	}
}

int ParseDigit(int FullNumber, int Digit) {
	return int(floor((FullNumber%int(pow(double(10),Digit)))/pow(double(10),Digit-1)));
}

bool CompareNumVector(int* InOne, int* InTwo, int Length) {
	for (int i=0 ; i < Length; i++) {
		if (InOne[i] != InTwo[i]) {
			return false;
		}
	}
	return true;
}

int* CopyNumVector(int* InOne, int Length) {
	int* NewVector = new int[Length];
	for (int i=0; i < Length; i++) {
		NewVector[i] = InOne[i];
	}
	return NewVector;
}

vector<string> ReadStringsFromFile(string Filename, bool EntryNumber) {
	ifstream Input;
	vector<string> Result;
	if (!OpenInput(Input, Filename)) {
		return Result;
	}

	string Buff;

	if (EntryNumber) {
		int NumEntries;
		Input >> NumEntries;
		Buff = GetFileLine(Input);

		for (int i=0; i < NumEntries; i++) {
			Buff = GetFileLine(Input);
			Result.push_back(Buff);
		}
	} else {
		do {
			Buff = GetFileLine(Input);
			Result.push_back(Buff);
		} while (!Input.eof());
	}

	Input.close();

	return Result;
}

vector< vector<string> >* LoadMultipleColumnFile(string InFilename, string Delimiter) {
	ifstream Input;
	if (!OpenInput(Input, InFilename)) {
		return NULL;
	}
	
	vector< vector<string> >* Result = new vector< vector<string> >;
	do {
		vector<string>* Strings = GetStringsFileline(Input,Delimiter.data());
		if (Strings->size() > 0) {
			vector<string> Temp;
			Result->push_back(Temp);
			(*Result)[Result->size()-1] = (*Strings);
		}
		delete Strings;
	} while (!Input.eof());

	Input.close();

	return Result;
}

string ConvertToMolFormula(string Buff) {
	string Find(" ");
	string Replace("");
	findandreplace(Buff, Find, Replace); 
	
	string Formula;
	int CurrentNum = 1;
	Formula.assign(Buff.substr(0,1));

	int i;
	for (i=1; i < int(Buff.length()); i++) {
		if (Buff.substr(i-1,1).compare(Buff.substr(i,1)) == 0) {
			CurrentNum++;
		}
		else {
			if (CurrentNum > 1) {
				Formula.append(itoa(CurrentNum));
			}
			CurrentNum = 1;
			Formula.append(Buff.substr(i,1));
		}
	}

	return Formula;
}

vector<string> GetDirectoryFileList(string Directory) {
	ostringstream strout;
	if (GetParameter("os").compare("linux") == 0) {
		strout << "ls " << Directory << " > " << FOutputFilepath() << "DirectoryFileList.txt";
	} else {
		strout << "dir " << Directory << " /A:-D /B > " << FOutputFilepath() << "DirectoryFileList.txt";
	}
	system(strout.str().data());
	vector<string> Files = ReadStringsFromFile(FOutputFilepath()+"DirectoryFileList.txt", false);
	strout.str("");
	if (GetParameter("os").compare("linux") == 0) {
		strout << "rm " << FOutputFilepath()+"DirectoryFileList.txt";
	} else {
		strout << "del " << FOutputFilepath()+"DirectoryFileList.txt";
	}
	system(strout.str().data());
	return Files;
}

string StringReplace(const char* Destination, const char* Target, const char* Substitution) {
	string Dest(Destination);
	string Targ(Target);
	string Sub(Substitution);

	int Location;
	do {
		Location = int(Dest.find(Targ));
		if (Location != Dest.npos) {
			Dest.replace(Location, Targ.length(),Substitution);
		}
	} while(Location != Dest.npos);

	return Dest;
}


string ConvertToLower(string InString) {
	string NewString(InString);
	for (int i=0; i < int(InString.length()); i++) {
		NewString[i] = tolower(InString[i]);
	}
	return NewString;
}

string ConvertToUpper(string InString) {
	string NewString(InString);
	for (int i=0; i < int(InString.length()); i++) {
		NewString[i] = toupper(InString[i]);
	}
	return NewString;
}

double ConvertKToDG(double InTemperature, double InK) {
	return -InTemperature*GAS_CONSTANT*log(InK);
}

double AverageVector(double &StdDev, vector<double> &InVector) {
	if (InVector.size() == 0) {
		StdDev = FLAG;
		return FLAG;
	}
	
	int TotalData = 0;
	double Average = 0;
	StdDev = 0;
	for (int i=0; i < int(InVector.size()); i++) {
		if (InVector[i] != FLAG) {
			TotalData++;
			Average += InVector[i];
		}
	}
	Average = Average/TotalData;
	for (int i=0; i < int(InVector.size()); i++) {
		if (InVector[i] != FLAG) {
			StdDev += (InVector[i]-Average)*(InVector[i]-Average);
		}
	}
	StdDev = StdDev/TotalData;
	StdDev = sqrt(StdDev);
	return Average;
}

void MakeDirectory(const char* InFilename) {
	string Filename(InFilename);
	Filename = CheckFilename(Filename);
	int Position = int(Filename.rfind("/"));
	if (Position < int(Filename.rfind("\\"))) {
		Position = int(Filename.rfind("\\"));
	}

	Filename = Filename.substr(0,Position);
	FLogFile() << "Path for output file: " << InFilename << " did not exist. Creating path..." << endl;
	ostringstream strout;
	string One("/");
	string Two("\\");
	if (GetParameter("os").compare("linux") == 0) {
		findandreplace(Filename,Two,One);
	} else {
		findandreplace(Filename,One,Two);
	}
	
	strout << "mkdir " << Filename;
	system(strout.str().data());
}

bool OpenInput(ifstream& Input, string Filename) {
	Filename = CheckFilename(Filename);
	
	Input.open(Filename.data());
	if (!Input.is_open()) {
		cout << "Could not open " << Filename << endl;
		FErrorFile() << "Could not open " << Filename << endl;
		return false;
	}
	else {
		return true;
	}
}

bool OpenOutput(ofstream& Output, string Filename, bool Append) {
	Filename = CheckFilename(Filename);
	
	if (!Append) {
		Output.open(Filename.data());
	} else {
		Output.open(Filename.data(),ios::app);
	}
	if (!Output.is_open()) {
		MakeDirectory(Filename.data());
		Output.open(Filename.data());
		if (!Output.is_open()) {
			cout << "Could not open " << Filename << endl;
			FErrorFile() << "Could not open " << Filename << endl;
			return false;
		}
		return true;
	}
	else {
		return true;
	}
}

char* ConvertStringToCString(string InString) {
	char* Temp = new char[InString.length()+10];
	strcpy(Temp,InString.data());
	return Temp;
}

int Sum(vector<int> InVector) {
	int Total = 0;
	for (int i=0; i < int(InVector.size()); i++) {
		Total += InVector[i];
	}
	return Total;
}

//This function returns every possible mapping of the items in the ItemsOne vector to the items in the ItemsTwo vector
//There can be more of item two than item one and vice versa
//Mappings[MAPPING INDEX][ITEM ONE INDEX] = ITEM TWO INDEX = AllPossibleMappings(ItemsOne[ITEM INDEX] = ITEM TYPE, ItemsTwo[ITEM INDEX] = ITEM TYPE, Mapable[ITEM TWO INDEX] = TRUE IF THIS INDEX HAS NOT YET BEEN USED, ExcludedCombinations[ITEM ONE TYPE][ITEM TWO TYPE] = 0 if this combination is excluded)
vector<vector<int> > AllPossibleMappings(vector<int>& ItemsOne, vector<int>& ItemsTwo, int CurrentLocation, bool* Mapable, map<int, map<int, bool, std::less<int> >, std::less<int> >* ExcludedCombinations) {
	//Mappings[MAPPING INDEX][ITEM ONE INDEX] = ITEM TWO INDEX or -1 if there are more item ones than item twos
	vector<vector<int> > Mappings;

	//Ensuring that the input vectors are the same size
	int OriginalOneSize = int(ItemsOne.size());
	int OriginalTwoSize = int(ItemsTwo.size());
	for (int i=int(ItemsOne.size()); i < int(ItemsTwo.size()); i++) {
		ItemsOne.push_back(1000);
	}
	for (int i=int(ItemsTwo.size()); i < int(ItemsOne.size()); i++) {
		ItemsTwo.push_back(1000);
	}

	//Allocating the mapable vector if it has not been allocated yet
	if (Mapable == NULL) {
		Mapable = new bool[ItemsTwo.size()];
		for (int i=0; i < int(ItemsTwo.size()); i++) {
			Mapable[i] = true;
		}
	}

	//Creating and populating the exluded combinations map
	if (ExcludedCombinations == NULL) {
		ExcludedCombinations = new map<int, map<int, bool, std::less<int> >, std::less<int> >;
		for (int i=0; i < int(ItemsOne.size()); i++) {
			for (int j=0; j < int(ItemsTwo.size()); j++) {
				(*ExcludedCombinations)[ItemsOne[i]][ItemsTwo[j]] = false;
			}
		}
	}

	//Pairing up the item at current location with every possible available item type
	for (int i=0; i < int(ItemsTwo.size()); i++) {
		if (Mapable[i] && !(*ExcludedCombinations)[(ItemsOne[CurrentLocation])][(ItemsTwo[i])]) {
			if (CurrentLocation < int(ItemsOne.size()-1)) {
				//Removing this object from the pool
				Mapable[i] = false;
				vector<vector<int> > NewMaps = AllPossibleMappings(ItemsOne,ItemsTwo,CurrentLocation+1,Mapable,ExcludedCombinations);
				//Copying all returned maps and adding the current combination to them
				for (int j=0; j < int(NewMaps.size()); j++) {
					NewMaps[j][CurrentLocation] = i;
				}
				Mappings.insert(Mappings.end(),NewMaps.begin(),NewMaps.end());
				//Adding the object back into the pool
				Mapable[i] = true;
				//Adding this combination to the excluded list
				(*ExcludedCombinations)[(ItemsOne[CurrentLocation])][(ItemsTwo[i])] = true;
			} else {
				//Initializing a brand new map since this is the last location
				vector<int> NewMap(ItemsOne.size(),-1);
				NewMap[CurrentLocation] = i;
				Mappings.push_back(NewMap);
				break;
			}
		}
	}

	//Adjusting the output maps if the size of the input item vectors was altered
	if (OriginalOneSize != int(ItemsOne.size())) {
		for (int i=0; i < int(Mappings.size()); i++) {
			for (int j=OriginalOneSize; j < int(ItemsOne.size()); j++) {
				Mappings[i].pop_back();
			}
		}
	}
	if (OriginalTwoSize != int(ItemsTwo.size())) {
		for (int i=0; i < int(Mappings.size()); i++) {
			for (int j=OriginalTwoSize; j < int(ItemsTwo.size()); j++) {
				for (int k=0; k < int(Mappings[i].size()); k++) {
					if (Mappings[i][k] == j) {
						Mappings[i][k] = -1;
					}
				}
			}
		}
	}

	//Deallocating Mapable vector
	if (CurrentLocation == 0) {
		delete [] Mapable;
		delete ExcludedCombinations;
	}

	return Mappings;
}

//This is a flexible counting function: if given the counting vector 1;9, the maxes 9;9, and the mins 0;0, it will change the counting vector to 2;0
void IterateCount(vector<int>& CurrentCount, vector<int>& Maxes, vector<int>& Mins) {
	int Position = int(CurrentCount.size()-1);
	do {
		CurrentCount[Position]++;
		if (CurrentCount[Position] > Maxes[Position]) {
			CurrentCount[Position] = Mins[Position]-1;
			Position--;
		} else {
			Position++;
		}
	} while(Position < int(CurrentCount.size()) && Position > -1);
}

map<string, string, std::less<string> > LoadStringTranslation(string InFilename, const char* Delimiter) {
	map<string, string, std::less<string> > Result;

	ifstream Input;
	if (!OpenInput(Input,InFilename)) {
		return Result;
	}
	
	do {
		vector<string>* Strings = GetStringsFileline(Input, Delimiter);
		if (Strings->size() >= 2) {
			Result[(*Strings)[0]] = (*Strings)[1];
		}
		delete Strings;
	} while (!Input.eof());

	Input.close();

	return Result;
}

void CreateFileList(const char* Directory, const char* Wildcard) {
	ostringstream Command;
	Command << GetParameter("perl directory") << " " << GetParameter("scripts directory") << "CreateFilenamesFile.pl " << Directory << " " <<  Wildcard;
	system(Command.str().data());
}


string RemoveExtension(string InFilename) {
	int Position = int(InFilename.find("."));
	
	if (Position != -1) {
		return InFilename.substr(0,Position);
	}
	return InFilename;
}

string RemovePath(string InFilename) {
	int Position = int(InFilename.rfind("/"));
	if (Position < int(InFilename.rfind("\\"))) {
		Position = int(InFilename.rfind("\\"));
	}

	if (Position != -1) {
		return InFilename.substr(Position+1,InFilename.length()-Position-1);
	}
	return InFilename;
}

int StartClock(int ClockIndex) {
	if (ClockIndex == -1 || ClockIndex >= int(StartTime.size())) {
		ClockIndex = -1;
		for (int i=0; i < int(StartTime.size()); i++) {
			if (StartTime[i] == -1) {
				ClockIndex = i;
				break;
			}
		}
		if (ClockIndex == -1) {
			StartTime.push_back(-1);
			ClockIndex = int(StartTime.size()-1);
		}
	}
	
	StartTime[ClockIndex] = double(time(NULL));
	return ClockIndex;
}

bool TimedOut(int ClockIndex) {
	if (ClockIndex < int(StartTime.size()) && ClockIndex < int(TimeOutTime.size()) && (time(NULL)-StartTime[ClockIndex]) > TimeOutTime[ClockIndex] && TimeOutTime[ClockIndex] != -1) {
		return true;
	} else {
		return false;
	}	
}

void SetTimeout(int ClockIndex, double InTime) {
	for(int i=int(TimeOutTime.size()); i <= ClockIndex; i++) {
		TimeOutTime.push_back(-1);
	}
	TimeOutTime[ClockIndex] = InTime;
}

void ClearClock(int ClockIndex) {
	SetTimeout(ClockIndex,-1);
	if (ClockIndex < int(StartTime.size())) {
		StartTime[ClockIndex] = -1;
	}
}

double ElapsedTime(int ClockIndex) {
	if (ClockIndex >= int(StartTime.size())) {
		return FLAG;
	}
	return double(time(NULL)-StartTime[ClockIndex]);
}

int GetNumberOfLinesInFile(string Filename) {
	ifstream Input;
	if (!OpenInput(Input,Filename)) {
		return 0;
	}

	int LineNumber = 0;

	do {
		string Fileline = GetFileLine(Input);
		if (Fileline.length() > 0) {
			LineNumber++;
		}
	} while(!Input.eof());

	return LineNumber;
}

bool FileExists(string InFilename) {
	InFilename = CheckFilename(InFilename);
	ifstream Input;
	Input.open(InFilename.data());
	if (Input.is_open()) {
		Input.close();
		return true;
	}
	return false;
}

void AddLineToFile(const char* Filename,string InLine) {
	FileLineData[Filename].push_back(InLine);
}

void PrintFileLineOutput() {
	for (map<string, vector<string>, std::less<string> >::iterator MapIT = FileLineData.begin(); MapIT != FileLineData.end(); MapIT++) {
		ofstream Output;

		string FullFilename(FOutputFilepath());
		FullFilename.append(MapIT->first);
		
		if (!OpenOutput(Output,FullFilename)) {
			return;
		}
		
		for (int i=0; i < int(MapIT->second.size()); i++) {
			Output << MapIT->second[i] << endl;	
		}
		
		Output.close();
	}
}

map<string, vector<string>, std::less<string> > LoadHorizontalHeadingFile(string InFilename, const char* Delimiter) {
	map<string, vector<string>, std::less<string> > Result;

	ifstream Input;
	if (!OpenInput(Input,InFilename)) {
		return Result;
	}

	while (!Input.eof()) {
		vector<string>* Strings = GetStringsFileline(Input, Delimiter);

		if (Strings->size() > 1) {
			for (int i=1; i < int(Strings->size()); i++) {
				Result[(*Strings)[0]].push_back((*Strings)[i]);
			}
		}

		delete Strings;
	}
	
	Input.close();
	return Result;
}

void ClearDirectory(string Filename) {
	ostringstream Command;
	Command << GetParameter("perl directory") << " " << GetParameter("scripts directory") << "ClearDirectory.pl " <<  Filename;
	system(Command.str().data());
}
