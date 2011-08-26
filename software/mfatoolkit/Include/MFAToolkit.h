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

#ifndef MFAToolkit_H
#define MFAToolkit_H

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

#include "Definitions.h"
#include "AtomCPP.h"
#include "AtomType.h"
#include "Data.h"
#include "Reaction.h"
#include "Species.h"
#include "GlobalFunctions.h"
#include "InterfaceFunctions.h"
#include "UtilityFunctions.h"
#include "MFAProblem.h"
#include "SolverInterface.h"
#include "GLPKapi.h"
#include "CPLEXapi.h"
#include "LINDOapi.h"
#include "SCIPapi.h"
#include "Gene.h"
#include "GeneInterval.h"
#include "stringDB.h"

#endif
