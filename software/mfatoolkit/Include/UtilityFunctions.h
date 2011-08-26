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

#ifndef UTILITYFUNCTIONS_H
#define UTILITYFUNCTIONS_H

//Turns an integer into a constant char
const char* itoa(int InNum);

//Turns a double into a constant char
const char* dtoa(double InNum);

//Returns today's date
string FDate();

//Reads in a fileline and returns it as a string
string GetFileLine(ifstream &Input);

//This function ensures that the input filename is a complete filename
string CheckFilename(string Filename);

//Reads in a fileline and returns it as a vector of strings for each element separated by delimiters in delim
vector<string>* GetStringsFileline(ifstream &Input, const char* Delim, bool TreatConsecutiveDelimAsOne = true);

//Splits the input string into a vector of strings using the elements in delim as the delimiters
vector<string>* StringToStrings(string FullString, const char* Delim, bool TreatConsecutiveDelimAsOne = true);

//Replaces find with replace in string source
void findandreplace(string &source, string find, string replace);

//returns the digit of "FullNumber" specified by Digit
int ParseDigit(int FullNumber, int Digit);

//Compares two number vectors and returns true if they are identical
bool CompareNumVector(int* InOne, int* InTwo, int Length);

//Copies the input vector into a new number vector which is returned
int* CopyNumVector(int* InOne, int Length);

//This reads a file containing a list of strings and returns those strings in a vector. The file must begin with the number of strings to be read in
vector<string> ReadStringsFromFile(string Filename, bool EntryNumber = true);

vector< vector<string> >* LoadMultipleColumnFile(string InFilename, string Delimiter);

string ConvertToMolFormula(string Buff);

vector<string> GetDirectoryFileList(string Directory);

//This function replaces any instances of the target string in the destination string with the substitute string
string StringReplace(const char* Destination, const char* Target, const char* Substitution);

string ConvertToLower(string InString);

string ConvertToUpper(string InString);

double ConvertKToDG(double InTemperature, double InK);

double AverageVector(double &StdDev, vector<double> &InVector);

void MakeDirectory(const char* InFilename);

bool OpenOutput(ofstream& Output, string Filename, bool Append = false);

bool OpenInput(ifstream& Input, string Filename);

char* ConvertStringToCString(string InString);

int Sum(vector<int> InVector);

vector<vector<int> >	AllPossibleMappings(vector<int>& ItemsOne, vector<int>& ItemsTwo, int CurrentLocation, bool* Mapable, map<int, map<int, bool, std::less<int> >, std::less<int> >* ExcludedCombinations);

void IterateCount(vector<int>& CurrentCount, vector<int>& Maxes, vector<int>& Mins);

list<vector<vector<int> > > ObjectBinAssignment(vector<vector<int> > StartingAssignments,vector<int> ItemSpecs, vector<int> RemainingItems, vector<int> BinSizes);

map<string, string, std::less<string> > LoadStringTranslation(string InFilename, const char* Delimiter);

string RemoveExtension(string InFilename);

string RemovePath(string InFilename);

int StartClock(int ClockIndex);

bool TimedOut(int ClockIndex);

void SetTimeout(int ClockIndex, double InTime);

void ClearClock(int ClockIndex);

double ElapsedTime(int ClockIndex);

int GetNumberOfLinesInFile(string Filename);

bool FileExists(string InFilename);

void AddLineToFile(const char* Filename,string InLine);

void PrintFileLineOutput();

map<string, vector<string>, std::less<string> > LoadHorizontalHeadingFile(string InFilename, const char* Delimiter);

void ClearDirectory(string Filename);

#endif
