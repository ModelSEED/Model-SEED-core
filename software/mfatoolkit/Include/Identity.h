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

#ifndef IDENTITY_H
#define IDENTITY_H

#define STRING 0
#define DATABASE_LINK 1
#define DOUBLE 2

class Identity {
private:
	bool Kill; // spare boolean marker
	bool Mark; // multipurpose boolean marker
	int Index; // to track position
	int Entry;
	int ObjectType;
	string Code;
	string ErrorMessage;
	map<string, vector<string> , std::less<string> > DatabaseLinks;
	map<string, vector<double>, std::less<string> > DoubleData;
	map<string, vector<string> , std::less<string> > StringData;
public:
	Identity();
	~Identity();

	void AddErrorMessage(const char* NewMessage);
	string FErrorMessage();
	
	int FIndex();
	int FEntry();
	string FCode();
	bool FMark();
	bool FKill();
	int FObjectType();

	void SetIndex(int InIndex);
	void SetEntry(int InEntry);
	void SetMark(bool InMark);
	void SetKill(bool InKill);
	void SetCode(string InCode);
	void SetObjectType(int InType);
	void InitializeEntryIndexDatabase(int InEntry,int InIndex,string InDatabase);

	bool AddData(const char* DBName, const char* Data, int Object, bool RemoveDuplicates = true);
	void AddData(const char* DBName, double Data, bool RemoveDuplicates = true);
	void SetData(const char* DBName, const char* Data, int Object, int InIndex = 0);
	void SetData(const char* DBName, double Data, int InIndex = 0);

	string GetGenericData(const char* DataName, int DataIndex = 0);
	string GetData(const char* DataName, int Object, int DataIndex = 0);
	double GetDoubleData(const char* DataName, int DataIndex = 0);
	int GetNumData(const char* DataName,int Object);

	vector<double> GetAllData(const char* DataName);
	vector<string> GetAllData(const char* DataName, int Object);
	string GetAllDataString(const char* DataName, int Object);
	
	string GetCombinedData(int Object);
	void ParseCombinedData(string InData, int Object, bool Reverse = false);
	
	void ClearData(const char* DatabaseName, int Object);
};

#endif
