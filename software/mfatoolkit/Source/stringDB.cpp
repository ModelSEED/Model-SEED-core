#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <sstream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
#include <iterator>
#include <list>
#include <map>
#include <math.h>
#include <time.h>
#include <iomanip>
#include <functional>
#include <algorithm>

//using namespace std;
using std::fstream;
using std::ifstream;
using std::ofstream;
using std::string;
using std::cout;
using std::cerr;
using std::cin;
using std::endl;
using std::getline;
using std::vector;
using std::list;
using std::iterator;
using std::left;
using std::setw;
using std::ios;
using std::set;
using std::ostringstream;
using std::map;
using std::multimap;
using std::less;
using std::pair;
#define SUCCESS 0
#define FAIL -1
#include "stringDB.h"

//DONE
namespace STRINGDB {
	string GetFileLine(ifstream &Input) {
		string Buff; 
		getline( Input, Buff );
		return Buff;
	}
	//DONE
	vector<string>* StringToStrings(string FullString, const char* Delim, bool TreatConsecutiveDelimAsOne) {
		vector<string>* NewVect = new vector<string>;
		if (FullString.length() == 0) {
			NewVect->push_back(FullString);
			return NewVect;
		}
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
	//DONE
	vector<string>* GetStringsFileline(ifstream &Input, const char* Delim, bool TreatConsecutiveDelimAsOne) {
		string Buff = GetFileLine(Input);
		return StringToStrings(Buff, Delim, TreatConsecutiveDelimAsOne);
	}
}

//***************************************************************************************
//StringDB Objects
StringDB::StringDB(string INfilename,string INprogramPath) {
	set_programPath(INprogramPath); 
	this->loadDatabase(this->checkFilename(INfilename));
};
//DONE
StringDB::~StringDB() {
	for (int i=0; i < int(tables.size()); i++) {
		delete tables[i];
	}
};
//DONE
string StringDB::checkFilename(string INfilename) {
	if (INfilename.length() == 0) {
		return INfilename;
	}
	string newFilename;
	vector<string>* strings = STRINGDB::StringToStrings(INfilename,"$",false);
	for (int i=0; i < int(strings->size());i++) {
		if (int(strings->size()) > i+2) {
			newFilename.append((*strings)[i]);
			char* temp = getenv((*strings)[i+1].data());
			if (temp != NULL) {
				newFilename.append(temp);
			}
			newFilename.append((*strings)[i+2]);
			i++;
			i++;
		} else {
			newFilename.append((*strings)[i]);
		}
	} 
	delete strings;
	if (newFilename.substr(1,1).compare(":") != 0 && newFilename.substr(0,1).compare("/") != 0) {
		newFilename.insert(0,this->get_programPath());
	}
	if (newFilename.substr(0,12).compare("/cygdrive/c/") == 0) {
		newFilename = "C:/" + newFilename.substr(12);
	}
	return newFilename;
}
//DONE
int StringDB::loadDatabase(string INfilename) {
	filename = INfilename;
	int status = this->loadDatabaseTable("DATABASESPECS","SINGLEFILE","Name",filename,"","\t",";",STRINGDB::StringToStrings("Table name","|",false),true);
	if (status == FAIL) {
		this->print_error("failed to load database specs","get_attribute");
		return FAIL;
	}
	for (int i=0; i < this->get_table("DATABASESPECS")->number_of_objects(); i++) {
		cout << "Loading Database File\t"<<this->get_table("DATABASESPECS")->get_object(i)->get("Filename") << endl;
		this->loadDatabaseTable(this->get_table("DATABASESPECS")->get_object(i));
	}
	return SUCCESS;
}
//DONE
void StringDB::print_error(string message,string function) {
	cerr << "StringDB:" << function << ":" << message << endl;
};
//DONE
StringDBObject* StringDB::get_object(string table,string attribute,string value) {
	if (this->get_table(table) == NULL) {
		this->print_error("requested table not found","get_object");
		return NULL;
	}
	return this->get_table(table)->get_object(attribute,value);
};
//DONE
list<StringDBObject*>* StringDB::get_objects(string table,string attribute,string value) {
	if (this->get_table(table) == NULL) {
		this->print_error("requested table not found","get_objects");
		return NULL;
	}
	return this->get_table(table)->get_objects(attribute,value);
};
//DONE
int StringDB::loadDatabaseTable(StringDBObject* tableObject) {
	string delimiter = tableObject->get("Delimiter");
	string itemDelimiter = tableObject->get("Item delimiter");
	if (delimiter.compare("TAB") == 0) {
		delimiter.assign("\t");
	} else if (delimiter.compare("SC") == 0) {
		delimiter.assign(";");
	}
	if (itemDelimiter.compare("TAB") == 0) {
		itemDelimiter.assign("\t");
	} else if (itemDelimiter.compare("SC") == 0) {
		itemDelimiter.assign(";");
	}
	return this->loadDatabaseTable(tableObject->get("Name"),tableObject->get("Type"),tableObject->get("ID attribute"),this->checkFilename(tableObject->get("Filename")),this->checkFilename(tableObject->get("Path")),delimiter,itemDelimiter,tableObject->getAll("Indexed columns"),false);
};
//DONE
int StringDB::loadDatabaseTable(string name,string type,string idColumn,string filename,string path,string delimiter,string itemDelimiter,vector<string>* indexedAttributes,bool unique) {
	StringDBTable* newTable = new StringDBTable(this,name,type,idColumn,filename,path,delimiter,itemDelimiter,indexedAttributes,unique);
	tables.push_back(newTable);
	tableMap[name] = int(tables.size()-1);
	return SUCCESS;
};
//DONE
int StringDB::number_of_tables() {
	return int(tables.size());
};
//DONE
StringDBTable* StringDB::get_table(string table) {
	if (this->tableMap.count(table) == 0) {
		return NULL;
	}
	return this->get_table(this->tableMap[table]);
};
//DONE
StringDBTable* StringDB::get_table(int table) {
	return this->tables[table];
};
string StringDB::get_programPath() {
	return this->programPath;
};
int StringDB::set_programPath(string input) {
	programPath = input;
	return SUCCESS;
};
//***************************************************************************************
//StringDBTable Objects
StringDBTable::StringDBTable(StringDB* INparentDB,string INname,string INtype,string INidColumn,string INfilename,string INpath,string INdelimiter,string INitemDelimiter,vector<string>* INindexedAttributes,bool unique) {
	this->parentDB = INparentDB;
	this->resetIterator();
	this->set_name(INname);
	this->set_type(INtype);
	this->set_id_column(INidColumn);
	if (INfilename.length() > 0 && INtype.compare("SINGLEFILE") == 0) {
		loadFromFile(INfilename,INpath,INdelimiter,INitemDelimiter,INindexedAttributes,unique);
	} else {
		this->set_filename(INfilename);
		this->set_path(INpath);
		this->set_delimiter(INdelimiter);
		this->set_itemDelimiter(INitemDelimiter);
		this->set_indexed_attributes(INindexedAttributes);
		this->add_atribute(INidColumn,true);
	}
};
//DONE
StringDBTable::~StringDBTable() {
	for (int i=0; i < this->number_of_objects(); i++) {
		StringDBObject* newObject = this->get_object(i);
		delete newObject;
	}
	for (map<int,map<string,list<StringDBObject*>*,std::less<string> >*,std::less<int> >::iterator IT = attributeHash.begin(); IT != attributeHash.end(); IT++) {
		this->clear_attribute_hash(IT->first);
	}
	if (indexed_attributes != NULL) {
		delete indexed_attributes;
	}
};

//DONE
void StringDBTable::print_error(string message,string function) {
	cerr << "StringDBTable:" << function << ":" << message << endl;
};

//DONE
int StringDBTable::loadFromFile(string INfilename,string INpath,string INdelimiter,string INitemDelimiter,vector<string>* INindexedAttributes,bool unique) {
	if (INfilename.length() == 0) {
		INfilename = this->get_filename();
	}
	this->set_filename(INfilename);
	if (INpath.length() == 0) {
		INpath = this->get_path();
	}
	this->set_path(INpath);
	if (INdelimiter.length() == 0) {
		INdelimiter = this->get_delimiter();
	}
	this->set_delimiter(INdelimiter);
	if (INitemDelimiter.length() == 0) {
		INitemDelimiter = this->get_itemDelimiter();
	}
	this->set_itemDelimiter(INitemDelimiter);
	if (INindexedAttributes == NULL) {
		INindexedAttributes = this->get_indexed_attributes();
	}
	this->set_indexed_attributes(INindexedAttributes);
	ifstream input(INfilename.data());
	if (!input.is_open()) {
		this->print_error("could not open table file "+INfilename,"loadFromFile");
		return FAIL;
	}
	string Buff = STRINGDB::GetFileLine(input);
	if (Buff.length() == 0) {
		this->print_error("no headers in file","loadFromFile");
		return FAIL;
	}
	vector<string>* strings = STRINGDB::StringToStrings(Buff, INdelimiter.data(), false);
	for (int i=0; i < int(strings->size()); i++) {
		bool indexed = false;
		for (int j=0; j < int(INindexedAttributes->size()); j++) {
			if ((*INindexedAttributes)[j].compare((*strings)[i]) == 0) {
				indexed = true;
				break;
			}
		}
		this->add_atribute((*strings)[i],indexed);
	}
	delete strings;
	while (!input.eof()) {
		string Buff = STRINGDB::GetFileLine(input);
		if (Buff.length() > 0) {
			strings = STRINGDB::StringToStrings(Buff, delimiter.data(), false);
			StringDBObject* newObject = new StringDBObject(this);
			int maxIndex = int(strings->size());
			if (maxIndex > this->number_of_attributes()) {
				maxIndex = this->number_of_attributes();
			}
			for (int i=0; i < maxIndex; i++) {
				vector<string>* stringsTwo = STRINGDB::StringToStrings((*strings)[i],itemDelimiter.data(),false);
				for (int j=0; j < int(stringsTwo->size()); j++) {
					newObject->set(i,(*stringsTwo)[j],-1,unique);
				}
				delete stringsTwo;
			}
			delete strings;
			newObject->set_loaded(true);
			this->add_object(newObject);
		}
	}
	input.close();
	return SUCCESS;
};
//DONE
int StringDBTable::resetIterator() {
	objectIT = objects.begin();
	currentSelection = 0;
	return SUCCESS;
};
//DONE
string StringDBTable::get_name() {
	return name;
};
int StringDBTable::set_name(string input) {
	name = input;
	return SUCCESS;
};
string StringDBTable::get_filename() {
	return filename;
};
int StringDBTable::set_filename(string input) {
	filename = input;
	return SUCCESS;
};
string StringDBTable::get_path() {
	return path;
};
int StringDBTable::set_path(string input) {
	path = input;
	return SUCCESS;
};
string StringDBTable::get_type() {
	return type;
};
int StringDBTable::set_type(string input) {
	type = input;
	return SUCCESS;
};
string StringDBTable::get_delimiter() {
	return delimiter;
};
int StringDBTable::set_delimiter(string input) {
	delimiter = input;
	return SUCCESS;
};
string StringDBTable::get_itemDelimiter() {
	return itemDelimiter;
};
int StringDBTable::set_itemDelimiter(string input) {
	itemDelimiter = input;
	return SUCCESS;
};
string StringDBTable::get_id_column() {
	return idColumn;
};
int StringDBTable::set_id_column(string input) {
	idColumn = input;
	return SUCCESS;
};
vector<string>* StringDBTable::get_indexed_attributes() {
	return indexed_attributes;
};
int StringDBTable::set_indexed_attributes(vector<string>* input) {
	indexed_attributes = input;
	return SUCCESS;
};
//DONE
int StringDBTable::number_of_attributes() {
	return int(attributes.size());
};
//DONE
string StringDBTable::get_attribute(int attributeIndex) {
	if (attributeIndex < 0 || attributeIndex >= int(attributes.size())) {
		this->print_error("attribute out of range","get_attribute");
		return "";
	}
	return attributes[attributeIndex];
};
//DONE
int StringDBTable::find_attribute(string attribute) {
	if (attributeMap.count(attribute) == 0) {
		return -1;
	}
	return attributeMap[attribute];
};
//DONE
int StringDBTable::add_atribute(string attribute,bool indexed) {
	if (this->find_attribute(attribute) != -1) {
		return this->set_attribute_index(this->find_attribute(attribute),indexed);
	}
	this->attributes.push_back(attribute);
	this->attributeMap[attribute] = int(this->attributes.size()-1);
	for (int i=0;i < this->number_of_objects(); i++) {
		this->get_object(i)->sync_with_attributes();
	}
	if (indexed) {
		return this->reset_attribute_hash(int(this->attributes.size()-1));
	}
	return SUCCESS;
};
//DONE
int StringDBTable::set_attribute_index(string attribute,bool indexed) {
	return this->set_attribute_index(this->find_attribute(attribute),indexed);
};
//DONE
int StringDBTable::set_attribute_index(int attributeIndex,bool indexed) {
	if (indexed) {
		if (this->attributeHash[attributeIndex] != NULL) {
			return SUCCESS;
		}
		return this->reset_attribute_hash(attributeIndex);
	} else if (this->attributeHash[attributeIndex] != NULL) {
		this->clear_attribute_hash(attributeIndex);
	}
	return SUCCESS;
};
//DONE
int StringDBTable::reset_attribute_hash(int attributeIndex) {
	this->clear_attribute_hash(attributeIndex);
	this->attributeHash[attributeIndex] = new map<string,list<StringDBObject*>*,std::less<string> >;
	for (int i=0; i < this->number_of_objects(); i++) {
		StringDBObject* object = this->get_object(i);
		vector<string>* objectData = object->getAll(i);
		if (objectData != NULL) {
			for (int j=0; j < int(objectData->size()); j++) {
				add_object_data_to_hash(i,(*objectData)[j],object);
			}
		}
	}
	return SUCCESS;
};
//DONE
int StringDBTable::clear_attribute_hash(int attributeIndex) {
	if (this->attributeHash[attributeIndex] != NULL) {
		for (map<string,list<StringDBObject*>*,std::less<string> >::iterator IT = this->attributeHash[attributeIndex]->begin();IT != this->attributeHash[attributeIndex]->end();IT++) {
			delete IT->second;
		}
		delete this->attributeHash[attributeIndex];
		this->attributeHash[attributeIndex] = NULL;
	}
	return SUCCESS;
};
//DONE
int StringDBTable::add_object(StringDBObject* newObject) {
	objects.push_back(newObject);
	this->resetIterator();
	return SUCCESS;
};
//DONE
int StringDBTable::delete_object(StringDBObject* newObject,bool deleteObject) {
	for (list<StringDBObject*>::iterator IT = objects.begin(); IT != objects.end(); IT++) {
		if (newObject == (*IT)) {
			objects.erase(IT);
		}
	}
	for (int i=0; i < this->number_of_attributes(); i++) {
		newObject->removeAll(i,NULL);
	}
	if (deleteObject) {
		delete newObject;
	}
	this->resetIterator();
	return SUCCESS;
};
//DONE
int StringDBTable::add_object_data_to_hash(int attribute,string inData,StringDBObject* inObject) {
	if (attribute < 0 || attribute >= this->number_of_attributes()) {
		this->print_error("attribute out of range","add_object_data_to_hash");
		return FAIL;
	}
	if (attributeHash[attribute] == NULL) {
		return FAIL;
	}
	if ((*attributeHash[attribute])[inData] == NULL) {
		(*attributeHash[attribute])[inData] = new list<StringDBObject*>;
	}
	list<StringDBObject*>* hashObjects = (*attributeHash[attribute])[inData];
	for (list<StringDBObject*>::iterator IT = hashObjects->begin();IT != hashObjects->end(); IT++) {
		if ((*IT) == inObject) {
			return SUCCESS;
		}
	}
	hashObjects->push_back(inObject);
	return SUCCESS;
};
//DONE
int StringDBTable::remove_object_data_from_hash(int attribute,string inData,StringDBObject* inObject) {
	if (attribute < 0 || attribute >= this->number_of_attributes() || attributeHash[attribute] == NULL || (*attributeHash[attribute])[inData] == NULL) {
		return FAIL;
	}
	list<StringDBObject*>* hashObjects = this->get_objects(attribute,inData);
	for (list<StringDBObject*>::iterator IT = hashObjects->begin();IT != hashObjects->end(); IT++) {
		if ((*IT) == inObject) {
			hashObjects->erase(IT);
		}
	}
	if (hashObjects->size() == 0) {
		delete hashObjects;
		(*this->attributeHash[attribute])[inData] = NULL;
	}
	return SUCCESS;
};
//DONE
StringDBObject* StringDBTable::get_object(string attribute,string value) {
	return this->get_object(this->find_attribute(attribute),value);
};
//DONE
StringDBObject* StringDBTable::get_object(int attribute,string value) {
	list<StringDBObject*>* resultList = this->get_objects(attribute,value);
	if (resultList != NULL && resultList->size() > 0) {
		return (*resultList->begin());
	}
	return NULL;
};
//DONE
list<StringDBObject*>* StringDBTable::get_objects(string attribute,string value) {
	return this->get_objects(this->find_attribute(attribute),value);
};
//DONE
list<StringDBObject*>* StringDBTable::get_objects(int attribute,string value) {
	if (this->attributeHash[attribute] == NULL) {
		this->print_error("no hash exists for query attribute","get_object");
		return NULL;
	}
	if ((*this->attributeHash[attribute])[value] == NULL) {
		if (this->get_path().length() > 0 && this->get_id_column().compare(this->get_attribute(attribute)) == 0) {
			StringDBObject* newObject = new StringDBObject(this);
			newObject->load_object_from_file(value);
			this->add_object(newObject);
			return (*this->attributeHash[attribute])[value];
		}
		this->print_error("no object exists with input value","get_object");
		return NULL;
	}
	return (*this->attributeHash[attribute])[value];
};
//DONE
int StringDBTable::number_of_objects() {
	return int(this->objects.size());
};
//DONE
StringDBObject* StringDBTable::get_object(int index) {
	if (index < 0 || index >= this->number_of_objects()) {
		this->print_error("input index out of range","get_object");
		return NULL;
	}
	if (index > currentSelection) {
		for (int i=currentSelection; i <  index; i++) {
			objectIT++;
			currentSelection++;
		}
	} else if (index < currentSelection) {
		for (int i=currentSelection; i >  index; i--) {
			objectIT--;
			currentSelection--;
		}
	}
	return (*objectIT);
};
//***************************************************************************************
//StringDBObject Objects
StringDBObject::StringDBObject(StringDBTable* parent) {
	this->loaded = false;
	this->parentTable = parent;
	this->data.resize(parentTable->number_of_attributes());
	for (int i=0; i < int(this->data.size()); i++) {
		this->data[i] = new vector<string>;
	}
};
//DONE
StringDBObject::~StringDBObject() {
	for (int i=0; i < int(this->data.size()); i++) {
		delete this->data[i];
	}
};
//DONE
int StringDBObject::load_object_from_file(string filename) {
	string itemDelimiter = this->get_table()->get_itemDelimiter();
	if (this->get_table()->get_type().compare("SINGLEFILE") == 0) {
		itemDelimiter = "\t";
	}
	vector<string>* indexedAttributes = this->get_table()->get_indexed_attributes();
	this->set(this->get_table()->find_attribute(this->get_table()->get_id_column()),filename);
	ifstream input((this->get_table()->get_path()+filename).data());
	if (!input.is_open()) {
		return FAIL;
	}
	this->loaded = true;
	while (!input.eof()) {
		vector<string>* strings = STRINGDB::GetStringsFileline(input,itemDelimiter.data(),false);
		string attribute = (*strings)[0];
		if (attribute.length() > 0 && attribute.compare(this->get_table()->get_id_column()) != 0) {
			int attributeIndex = this->get_table()->find_attribute(attribute);
			if (attributeIndex == -1) {
				bool indexed = false;
				for (int i=0; i < int(indexedAttributes->size()); i++) {
					if ((*indexedAttributes)[i].compare(attribute) == 0) {
						indexed = true;
						break;
					}
				}
				this->get_table()->add_atribute(attribute,indexed);
				attributeIndex = this->get_table()->find_attribute(attribute);
			}
			for (int i=1; i < int(strings->size()); i++) {
				this->set(attributeIndex,(*strings)[i]);
			}
		}
		delete strings;
	}
	input.close();
	return SUCCESS;
};
//DONE
bool StringDBObject::objectLoaded() {
	return loaded;
};
//DONE
int StringDBObject::set_loaded(bool input) {
	loaded = input;
	return SUCCESS;
};
//DONE
void StringDBObject::print_error(string message,string function) {
	cerr << "StringDBObject:" << function << ":" << message << endl;
};
//DONE
StringDBTable* StringDBObject::get_table() {
	return this->parentTable;
};
//DONE
vector<string>* StringDBObject::getAll(string attribute) {
	return this->getAll(this->get_table()->find_attribute(attribute));
};
//DONE
vector<string>* StringDBObject::getAll(int attribute) {
	if (attribute < 0 || int(this->data.size()) <= attribute) {
		this->print_error("attribute out of range","getAll");
		return NULL;
	}
	return this->data[attribute];
};
//DONE
string StringDBObject::get(string attribute,int index) {
	return this->get(this->get_table()->find_attribute(attribute),index);
};
//DONE
string StringDBObject::get(int attribute,int index) {
	vector<string>* strings = this->getAll(attribute);
	if (strings == NULL || int(strings->size()) <= index) {
		this->print_error("attribute index out of range","get");
		return NULL;
	}
	return (*strings)[index];
}
//DONE
int StringDBObject::get_data_index(string attribute,string value) {
	return this->get_data_index(this->get_table()->find_attribute(attribute),value);
};
//DONE
int StringDBObject::get_data_index(int attribute,string value) {
	if (attribute < 0 || attribute >= int(this->data.size())) {
		this->print_error("attribute not found in object","get_data_index");
		return -1;
	}
	if (data[attribute] != NULL) {
		for (int i=0; i < int(data[attribute]->size()); i++) {
			if ((*data[attribute])[i].compare(value) == 0) {
				return i;
			}
		}
		return -1;
	}
	return -1;
};
//DONE
int StringDBObject::set(string attribute,string indata,int index,bool unique) {
	return this->set(this->get_table()->find_attribute(attribute),indata,index,unique);
};
//DONE
int StringDBObject::set(int attribute,string indata,int index,bool unique) {
	if (attribute < 0) {
		this->print_error("attribute not found in object","set");
		return FAIL;
	}
	if (attribute >= int(this->data.size())) {
		for (int i=int(this->data.size()); i <= attribute; i++) {
			vector<string>* strings = new vector<string>;
			data.push_back(strings);
		}
	}
	if (int(this->data[attribute]->size()) < index) {
		this->print_error("attribute index out of range","set");
		return FAIL;
	}
	if (unique) {
		for (int i=0; i < int(this->data[attribute]->size()); i++) {
			if ((*this->data[attribute])[i].compare(indata) == 0) {
				return SUCCESS;
			}
		}
	}
	if (index == -1 || index == this->data[attribute]->size()) {
		this->data[attribute]->push_back(indata);
		this->get_table()->add_object_data_to_hash(attribute,indata,this);	
	} else {
		this->remove(attribute,index,indata);
	}
	return SUCCESS;
};
//DONE
int StringDBObject::setAll(string attribute,vector<string>* indata) {
	return this->setAll(this->get_table()->find_attribute(attribute),indata);
};
//DONE
int StringDBObject::setAll(int attribute,vector<string>* indata) {
	if (attribute < 0) {
		this->print_error("attribute not found in object","setAll");
		return FAIL;
	}
	if (attribute >= int(this->data.size())) {
		for (int i=int(this->data.size()); i <= (attribute-1); i++) {
			vector<string>* strings = new vector<string>;
			data.push_back(strings);
		}
		data.push_back(indata);
	} else {
		this->removeAll(attribute,indata);
	}
	return SUCCESS;
};
//DONE
int StringDBObject::remove(string attribute,string value,string replacement) {
	return this->remove(this->get_table()->find_attribute(attribute),value,replacement);
};
//DONE
int StringDBObject::remove(int attribute,string value,string replacement) {
	return this->remove(attribute,this->get_data_index(attribute,value),replacement);
};
//DONE
int StringDBObject::remove(string attribute,int value,string replacement) {
	return this->remove(this->get_table()->find_attribute(attribute),value,replacement);
};
//DONE
int StringDBObject::remove(int attribute,int value,string replacement) {
	if (attribute < 0 || attribute >= int(this->data.size())) {
		this->print_error("attribute not found in object","remove");
		return FAIL;
	}
	if (data[attribute] == NULL || value < 0 || value >= int(data[attribute]->size())) {
		this->print_error("data not found in attribute of object","remove");
		return FAIL;
	}
	this->get_table()->remove_object_data_from_hash(attribute,(*data[attribute])[value],this);
	if (replacement.length() == 0) {
		data[attribute]->erase(data[attribute]->begin()+value,data[attribute]->begin()+value+1);
	} else {
		(*data[attribute])[value] = replacement;
		this->get_table()->add_object_data_to_hash(attribute,replacement,this);
	}
	return SUCCESS;
};
//DONE
int StringDBObject::removeAll(string attribute,vector<string>* replacement) {
	return this->removeAll(this->get_table()->find_attribute(attribute),replacement);
};
//DONE
int StringDBObject::removeAll(int attribute,vector<string>* replacement) {
	if (attribute < 0 || attribute >= int(this->data.size())) {
		this->print_error("attribute not found in object","removeAll");
		return FAIL;
	}
	if (data[attribute] != NULL) {
		for (int i=0; i < int(data[attribute]->size()); i++) {
			this->get_table()->remove_object_data_from_hash(attribute,(*data[attribute])[i],this);
		}
		if (replacement != NULL) {
			delete data[attribute];
			data[attribute] = replacement;
			for (int i=0; i < int(data[attribute]->size()); i++) {
				this->get_table()->add_object_data_to_hash(attribute,(*data[attribute])[i],this);
			}
		} else {
			data[attribute]->clear();
		}
		return SUCCESS;
	}
	return FAIL;
};

int StringDBObject::sync_with_attributes() {
	if (this->get_table()->number_of_attributes() > int(this->data.size())) {
		for (int i = int(this->data.size());i < this->get_table()->number_of_attributes();i++) {
			vector<string>* newData = new vector<string>;
			data.push_back(newData);
		}

	}
	return SUCCESS;
};
