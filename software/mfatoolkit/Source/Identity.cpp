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

Identity::Identity() {
	Kill = false;
	Mark = false;
	Index = 0;
	Entry = 0;
}

Identity::~Identity(){

}

void Identity::AddErrorMessage(const char* NewMessage) {
	if (ErrorMessage.find(NewMessage) != ErrorMessage.npos) {
		return;
	}
	if (ErrorMessage.length() > 0) {
		ErrorMessage.append("|");
	}
	ErrorMessage.append(NewMessage);
}

string Identity::FErrorMessage() {
	return ErrorMessage;
}

int Identity::FIndex(){
	return Index;
}

int Identity::FEntry(){
	return Entry;
}

string Identity::FCode() {
	return Code;
}

bool Identity::FMark() {
	return Mark;
}

bool Identity::FKill() {
	return Kill;
}

int Identity::FObjectType() {
	return ObjectType;
}

void Identity::SetIndex(int InIndex){
	Index = InIndex;
}

void Identity::SetEntry(int InEntry){
	Entry = InEntry;
}

void Identity::SetMark(bool InMark) {
	Mark = InMark;
}

void Identity::SetKill(bool InKill) {
	Kill = InKill;
}

void Identity::SetObjectType(int InType) {
	ObjectType = InType;
}

void Identity::InitializeEntryIndexDatabase(int InEntry,int InIndex,string InDatabase) {
	SetEntry(InEntry);
	SetIndex(InIndex);
	if (InDatabase.length() == 0) {
		InDatabase.assign(itoa(InEntry));
	}
	AddData("DATABASE",InDatabase.data(),STRING);
}

void Identity::SetCode(string InCode) {
	if (InCode.compare("Unknown") == 0 || InCode.compare("None") == 0) {
		InCode.assign("");
	}
	Code.assign(InCode);
};

bool Identity::AddData(const char* DBName, const char* DBID, int Object, bool RemoveDuplicates) {
	string StrDBName(DBName);
	string StrDBID(DBID);
	vector<string>* Strings = StringToStrings(DBID,"|\t");
	bool OneAdded = false;

	bool SecondDB = false;
	if (StrDBName.compare("STRUCTURE_FILE") == 0) {
		SecondDB = true;
	}	

	if (Object == STRING) {
		bool Add = true;
		for (int j=0; j < int(Strings->size()); j++) {
			//I eliminate spaces that might be at the beginning or ending of a data item
			if ((*Strings)[j].length() > 0 && (*Strings)[j].substr(0,1).compare(" ") == 0) {
				(*Strings)[j] = (*Strings)[j].substr(1,(*Strings)[j].length()-1);
			}

			if ((*Strings)[j].length() > 0 && (*Strings)[j].substr((*Strings)[j].length()-1,1).compare(" ") == 0) {
				(*Strings)[j] = (*Strings)[j].substr(0,(*Strings)[j].length()-1);
			}
			vector<string>& CurrentData = StringData[StrDBName];
			if (RemoveDuplicates) {
				for (int i=0; i < int(CurrentData.size()); i++) {
					if (CurrentData[i].compare((*Strings)[j]) == 0) {
						Add = false;
					}
				}
			}
			if (Add) {
				OneAdded = true;
				CurrentData.push_back((*Strings)[j]);
				if (SecondDB) {
					string Extension;
					if ((*Strings)[j].length() > 4 ) {
						Extension = (*Strings)[j].substr((*Strings)[j].length()-4,4);
					}
					if (Extension.length() == 0) {
						AddData("SMILES",(*Strings)[j].data(),STRING);
					} else if (Extension.compare(".mol") == 0) {
						AddData("MOLFILE",(*Strings)[j].data(),STRING);
					} else if (Extension.compare(".dat") == 0 || Extension.compare(".gds") == 0) {
						AddData("DATFILE",(*Strings)[j].data(),STRING);
					}
				}
			}
		}
	} else if (Object == DATABASE_LINK) {
		bool Add = true;
		for (int j=0; j < int(Strings->size()); j++) {
			vector<string>& CurrentData = DatabaseLinks[StrDBName];
			//I eliminate spaces that might be at the beginning or ending of a data item
			if ((*Strings)[j].substr(0,1).compare(" ") == 0) {
				(*Strings)[j] = (*Strings)[j].substr(1,(*Strings)[j].length()-1);
			}

			if ((*Strings)[j].substr((*Strings)[j].length()-1,1).compare(" ") == 0) {
				(*Strings)[j] = (*Strings)[j].substr(0,(*Strings)[j].length()-1);
			}
			if (RemoveDuplicates) {
				for (int i=0; i < int(CurrentData.size()); i++) {
					if (CurrentData[i].compare((*Strings)[j]) == 0) {
						Add = false;
					}
				}
			}
			if (Add) {
				OneAdded = true;
				CurrentData.push_back((*Strings)[j]);
			}
		}
	} else if (Object == DOUBLE) {
		bool Add = true;
		for (int j=0; j < int(Strings->size()); j++) {
			double CurrentDouble = atof((*Strings)[j].data());	
			vector<double>& CurrentData = DoubleData[StrDBName];
			if (RemoveDuplicates) {
				for (int i=0; i < int(CurrentData.size()); i++) {
					if (CurrentData[i] == CurrentDouble) {
						Add = false;
					}
				}
			}
			if (Add) {
				OneAdded = true;
				CurrentData.push_back(CurrentDouble);
			}
		}
	}

	delete Strings;
	return OneAdded;
};

void Identity::AddData(const char* DBName, double Data, bool RemoveDuplicates) {
	string StrDataName(DBName);

	vector<double>& CurrentData = DoubleData[StrDataName];
	if (RemoveDuplicates) {
		for (int i=0; i < int(CurrentData.size()); i++) {
			if (CurrentData[i] == Data) {
				return;
			}
		}
	}
	CurrentData.push_back(Data);
};

void Identity::SetData(const char* DBName, const char* Data, int Object, int InIndex) {
	if (Object == STRING) {
		vector<string>& CurrentData = StringData[DBName];
		for (int i=int(CurrentData.size()); i < InIndex+1; i++) {
			CurrentData.push_back("");
		}
		CurrentData[InIndex].assign(Data);
	} else if (Object == DATABASE_LINK) {
		vector<string>& CurrentData = DatabaseLinks[DBName];
		for (int i=int(CurrentData.size()); i < InIndex+1; i++) {
			CurrentData.push_back("");
		}
		CurrentData[InIndex].assign(Data);
	} else {
		return;
	}
}

void Identity::SetData(const char* DBName, double Data, int InIndex) {
	vector<double>& CurrentData = DoubleData[DBName];
	for (int i=int(CurrentData.size()); i < InIndex+1; i++) {
		CurrentData.push_back(FLAG);
	}
	CurrentData[InIndex] = Data;
}

string Identity::GetGenericData(const char* DataName, int DataIndex) {
	string Temp = GetData(DataName,STRING,DataIndex);
	if (Temp.length() == 0) {
		Temp = GetData(DataName,DATABASE_LINK,DataIndex);
	}

	return Temp;
}

string Identity::GetData(const char* DataName, int Object, int DataIndex) {
	string StrDataName(DataName);

	vector<string> CurrentData;
	if (Object == STRING) {
		CurrentData = StringData[StrDataName];
	} else if (Object == DATABASE_LINK) {
		CurrentData = DatabaseLinks[StrDataName];
	} 

	if (DataIndex >= int(CurrentData.size())) {
		StrDataName.clear();
		return StrDataName;
	}
	return CurrentData[DataIndex];
};

double Identity::GetDoubleData(const char* DataName, int DataIndex) {
	string StrDataName(DataName);

	vector<double> CurrentData = DoubleData[StrDataName];

	if (DataIndex >= int(CurrentData.size())) {
		return FLAG;
	}
	return CurrentData[DataIndex];
};

int Identity::GetNumData(const char* DataName,int Object) {
	if (Object == STRING) {
		return int(StringData[DataName].size());
	} else if (Object == DATABASE_LINK) {
		return int(DatabaseLinks[DataName].size());
	} else {
		return int(DoubleData[DataName].size());
	}
};

vector<double> Identity::GetAllData(const char* DataName) {
	string StrDataName(DataName);
	return DoubleData[StrDataName];
};

vector<string> Identity::GetAllData(const char* DataName, int Object) {
	string StrDataName(DataName);
	
	if (Object == STRING) {
		return StringData[StrDataName];
	} else if (Object == DATABASE_LINK) {
		return DatabaseLinks[StrDataName];
	}

	vector<string> Temp;
	return Temp;
};

string Identity::GetAllDataString(const char* DataName, int Object) {
	string Combined;

	if (Object == DOUBLE) {
		vector<double> Data = GetAllData(DataName);
		for (int i=0; i < int(Data.size()); i++) {
			Combined.append(dtoa(Data[i]));
			if (i < int(Data.size()-1)) {
				Combined.append("\t");
			}
		}
	} else {
		vector<string> Data = GetAllData(DataName, Object);
		for (int i=0; i < int(Data.size()); i++) {
			Combined.append(Data[i]);
			if (i < int(Data.size()-1)) {
				Combined.append("\t");
			}
		}
	}

	return Combined;
};

string Identity::GetCombinedData(int Object) {
	map<string, vector<string> , std::less<string> >::iterator MapITLink = DatabaseLinks.begin();
	map<string, vector<double> , std::less<string> >::iterator MapITDoub = DoubleData.begin();
	map<string, vector<string> , std::less<string> >::iterator MapITString = StringData.begin();
	
	string Combined;
	
	int Mapsize = 0;
	if (Object == STRING) {
		Mapsize = int(StringData.size());
	} else if (Object == DATABASE_LINK) {
		Mapsize = int(DatabaseLinks.size());
	} else if (Object == DOUBLE) {
		Mapsize = int(DoubleData.size());
	}

	for(int i=0; i < Mapsize; i++) {
		int DataSize = 0;
		if (Object == STRING) {
			DataSize = int(MapITString->second.size());
		} else if (Object == DATABASE_LINK) {
			DataSize = int(MapITLink->second.size());
		} else if (Object == DOUBLE) {
			DataSize = int(MapITDoub->second.size());
		}
		
		if (DataSize > 0) {
			if (Object == STRING) {
				Combined.append(MapITString->first);
			} else if (Object == DATABASE_LINK) {
				Combined.append(MapITLink->first);
			} else if (Object == DOUBLE) {
				Combined.append(MapITDoub->first);
			}

			Combined.append(":");
			for (int j=0; j < DataSize; j++) {
				if (Object == STRING) {
					Combined.append(MapITString->second[j]);
				} else if (Object == DATABASE_LINK) {
					Combined.append(MapITLink->second[j]);
				} else if (Object == DOUBLE) {
					Combined.append(dtoa(MapITDoub->second[j]));
				}

				if (j < DataSize-1) {
					Combined.append(":");
				}
			}
			Combined.append("\t");
		}
		
		if (Object == STRING) {
			MapITString++;
		} else if (Object == DATABASE_LINK) {
			MapITLink++;
		} else if (Object == DOUBLE) {
			MapITDoub++;
		}
	}

	if (Combined.length() > 0 && Combined.substr(Combined.length()-1,1).compare("\t") == 0) {
		Combined = Combined.substr(0,Combined.length()-1);
	}

	return Combined;
};

void Identity::ParseCombinedData(string InData, int Object, bool Reverse) {
	vector<string>* Strings = StringToStrings(InData,"|\t");
	for (int i=0; i < int(Strings->size()); i++) {
		vector<string>* StringsTwo = StringToStrings((*Strings)[i],":");
		for (int j=1; j < int(StringsTwo->size()); j++) {
			if (Object == DOUBLE) {
				AddData((*StringsTwo)[0].data(),atof((*StringsTwo)[j].data()));
			} else {
				if (Reverse) {
					(*StringsTwo)[j].append("(r)");
				}
				AddData((*StringsTwo)[0].data(),(*StringsTwo)[j].data(),Object);
			}
		}
		delete StringsTwo;
	}
	delete Strings;
}

void Identity::ClearData(const char* DatabaseName, int Object) {
	string StrDatabaseName(DatabaseName);

	if (Object == STRING) {
		StringData[StrDatabaseName].clear();
	} else if (Object == DATABASE_LINK) {
		DatabaseLinks[StrDatabaseName].clear();
	} else if (Object == DOUBLE) {
		DoubleData[StrDatabaseName].clear();
	} 
};