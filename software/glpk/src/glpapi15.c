/* glpapi15.c (reading/writing data in CPLEX LP format) */

/***********************************************************************
*  This code is part of GLPK (GNU Linear Programming Kit).
*
*  Copyright (C) 2000,01,02,03,04,05,06,07,08,2009 Andrew Makhorin,
*  Department for Applied Informatics, Moscow Aviation Institute,
*  Moscow, Russia. All rights reserved. E-mail: <mao@mai2.rcnet.ru>.
*
*  GLPK is free software: you can redistribute it and/or modify it
*  under the terms of the GNU General Public License as published by
*  the Free Software Foundation, either version 3 of the License, or
*  (at your option) any later version.
*
*  GLPK is distributed in the hope that it will be useful, but WITHOUT
*  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
*  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
*  License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with GLPK. If not, see <http://www.gnu.org/licenses/>.
***********************************************************************/

#include "glpapi.h"
#include "glpcpx.h"

/***********************************************************************
*  NAME
*
*  glp_read_lp - read problem data in CPLEX LP format
*
*  SYNOPSIS
*
*  int glp_read_lp(glp_prob *lp, const void *parm, const char *fname);
*
*  DESCRIPTION
*
*  The routine glp_read_lp reads problem data in CPLEX LP format from
*  a text file.
*
*  The parameter parm is reserved for use in the future and must be
*  specified as NULL.
*
*  The character string fname specifies a name of the text file to be
*  read.
*
*  Note that before reading data the current content of the problem
*  object is completely erased with the routine glp_erase_prob.
*
*  RETURNS
*
*  If the operation was successful, the routine glp_read_lp returns
*  zero. Otherwise, it prints an error message and returns non-zero. */

int glp_read_lp(glp_prob *lp, const void *parm, const char *fname)
{     if (parm != NULL)
         xerror("glp_read_lp: parm = %p; invalid parameter\n", parm);
      return read_cpxlp(lp, fname);
}

/***********************************************************************
*  NAME
*
*  glp_write_lp - write problem data in CPLEX LP format
*
*  SYNOPSIS
*
*  int glp_write_lp(glp_prob *lp, const void *parm, const char *fname);
*
*  DESCRIPTION
*
*  The routine glp_write_lp writes problem data in MPS format to a text
*  file.
*
*  The parameter parm is reserved for use in the future and must be
*  specified as NULL.
*
*  The character string fname specifies a name of the text file to be
*  written.
*
*  RETURNS
*
*  If the operation was successful, the routine glp_write_lp returns
*  zero. Otherwise, it prints an error message and returns non-zero. */

int glp_write_lp(glp_prob *lp, const void *parm, const char *fname)
{     if (parm != NULL)
         xerror("glp_write_lp: parm = %p; invalid parameter\n", parm);
      return write_cpxlp(lp, fname);
}

/* eof */
