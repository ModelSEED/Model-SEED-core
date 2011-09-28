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

#ifndef STRINGDB_H
#define STRINGDB_H

class StringDBTable;
class StringDBObject;

class StringDB  {
private:
	map<string,int,std::less<string> > tableMap;
	vector<StringDBTable*> tables;
	string filename;
	string programPath;
public:
	StringDB(string INfilename,string INprogramPath);
	~StringDB();
	int loadDatabase(string INfilename);
	void print_error(string message,string function);
	StringDBObject* get_object(string table,string attribute,string value);
	list<StringDBObject*>* get_objects(string table,string attribute,string value);
	int loadDatabaseTable(string name,string type,string idColumn,string filename,string path,string delimiter,string itemDelimiter,vector<string>* indexedAttributes,bool unique = false);
	int loadDatabaseTable(StringDBObject* tableObject);
	int number_of_tables();
	StringDBTable* get_table(string table);
	StringDBTable* get_table(int table);
	string get_programPath();
	int set_programPath(string input);
	string checkFilename(string INfilename);
};

class StringDBTable {
private:
	StringDB* parentDB;
	vector<string> attributes;
	map<string,int,std::less<string> > attributeMap;
	list<StringDBObject*> objects;
	list<StringDBObject*>::iterator objectIT;
	int currentSelection;
	map<int,map<string,list<StringDBObject*>*,std::less<string> >*,std::less<int> > attributeHash;
	string name;
	string filename;
	string path;
	string type;
	string delimiter;
	string itemDelimiter;
	string idColumn;
	vector<string>* indexed_attributes;
public:
	StringDBTable(StringDB* INparentDB,string INname,string INtype,string INidColumn,string INfilename = "",string INpath = "",string INdelimiter = "",string INitemDelimiter = "",vector<string>* INindexedAttributes = NULL,bool unique = false);
	~StringDBTable();
	void print_error(string message,string function);
	int loadFromFile(string INfilename = "",string INpath = "",string INdelimiter = "",string INitemDelimiter = "",vector<string>* INindexedAttributes = NULL,bool unique = false);
	int resetIterator();

	string get_name();
	int set_name(string input);
	string get_filename();
	int set_filename(string input);
	string get_path();
	int set_path(string input);
	string get_type();
	int set_type(string input);
	string get_delimiter();
	int set_delimiter(string input);
	string get_itemDelimiter();
	int set_itemDelimiter(string input);
	string get_id_column();
	int set_id_column(string input);
	vector<string>* get_indexed_attributes();
	int set_indexed_attributes(vector<string>* input);

	int number_of_attributes();
	string get_attribute(int attributeIndex);
	int find_attribute(string attribute);

	int add_atribute(string attribute,bool indexed = false);
	int set_attribute_index(string attribute,bool indexed);
	int set_attribute_index(int attributeIndex,bool indexed);
	int reset_attribute_hash(int attributeIndex);
	int clear_attribute_hash(int attributeIndex);

	int add_object(StringDBObject* newObject);
	int delete_object(StringDBObject* newObject,bool deleteObject);
	int add_object_data_to_hash(int attribute,string inData,StringDBObject* inObject);
	int remove_object_data_from_hash(int attribute,string inData,StringDBObject* inObject);

	StringDBObject* get_object(string attribute,string value);
	StringDBObject* get_object(int attribute,string value);
	list<StringDBObject*>* get_objects(string attribute,string value);
	list<StringDBObject*>* get_objects(int attribute,string value);

	int number_of_objects();
	StringDBObject* get_object(int index);
};

class StringDBObject {
private:
	StringDBTable* parentTable;
	vector<vector<string>*> data;
	bool loaded;
public:
	StringDBObject(StringDBTable* inParent);
	~StringDBObject();
	int load_object_from_file(string filename);
	bool objectLoaded();
	int set_loaded(bool input);

	void print_error(string message,string function);
	StringDBTable* get_table();

	vector<string>* getAll(string attribute);
	vector<string>* getAll(int attribute);
	string get(string attribute,int index = 0);
	string get(int attribute,int index = 0);
	
	int get_data_index(string attribute,string value);
	int get_data_index(int attribute,string value);
	
	int set(string attribute,string indata,int index = -1,bool unique = true);
	int set(int attribute,string indata,int index = -1,bool unique = true);
	int setAll(string attribute,vector<string>* indata);
	int setAll(int attribute,vector<string>* indata);
	int remove(string attribute,string value,string replacement);
	int remove(int attribute,string value,string replacement);
	int remove(string attribute,int value,string replacement);
	int remove(int attribute,int value,string replacement);
	int removeAll(string attribute,vector<string>* replacement);
	int removeAll(int attribute,vector<string>* replacement);
	int sync_with_attributes();
};

#endif
