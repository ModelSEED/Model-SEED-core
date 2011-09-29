/* glpbfd.c (LP basis factorization driver) */

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

#define GLPBFD_PRIVATE
#include "glpbfd.h"
#include "glplib.h"
#define xfault xerror

/* CAUTION: DO NOT CHANGE THE LIMIT BELOW */

#define M_MAX 100000000 /* = 100*10^6 */
/* maximal order of the basis matrix */

/***********************************************************************
*  NAME
*
*  bfd_create_it - create LP basis factorization
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  BFD *bfd_create_it(void);
*
*  DESCRIPTION
*
*  The routine bfd_create_it creates a program object, which represents
*  a factorization of LP basis.
*
*  RETURNS
*
*  The routine bfd_create_it returns a pointer to the object created. */

BFD *bfd_create_it(void)
{     BFD *bfd;
      bfd = xmalloc(sizeof(BFD));
      bfd->valid = 0;
      bfd->type = BFD_TFT;
      bfd->fhv = NULL;
      bfd->lpf = NULL;
      bfd->lu_size = 0;
      bfd->piv_tol = 0.10;
      bfd->piv_lim = 4;
      bfd->suhl = 1;
      bfd->eps_tol = 1e-15;
      bfd->max_gro = 1e+10;
      bfd->nfs_max = 50;
      bfd->upd_tol = 1e-6;
      bfd->nrs_max = 50;
      bfd->rs_size = 1000;
      bfd->upd_lim = -1;
      bfd->upd_cnt = 0;
      return bfd;
}

/***********************************************************************
*  NAME
*
*  bfd_factorize - compute LP basis factorization
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  int bfd_factorize(BFD *bfd, int m, int bh[], int (*col)(void *info,
*     int j, int ind[], double val[]), void *info);
*
*  DESCRIPTION
*
*  The routine bfd_factorize computes the factorization of the basis
*  matrix B specified by the routine col.
*
*  The parameter bfd specified the basis factorization data structure
*  created with the routine bfd_create_it.
*
*  The parameter m specifies the order of B, m > 0.
*
*  The array bh specifies the basis header: bh[j], 1 <= j <= m, is the
*  number of j-th column of B in some original matrix. The array bh is
*  optional and can be specified as NULL.
*
*  The formal routine col specifies the matrix B to be factorized. To
*  obtain j-th column of A the routine bfd_factorize calls the routine
*  col with the parameter j (1 <= j <= n). In response the routine col
*  should store row indices and numerical values of non-zero elements
*  of j-th column of B to locations ind[1,...,len] and val[1,...,len],
*  respectively, where len is the number of non-zeros in j-th column
*  returned on exit. Neither zero nor duplicate elements are allowed.
*
*  The parameter info is a transit pointer passed to the routine col.
*
*  RETURNS
*
*  0  The factorization has been successfully computed.
*
*  BFD_ESING
*     The specified matrix is singular within the working precision.
*
*  BFD_ECOND
*     The specified matrix is ill-conditioned.
*
*  For more details see comments to the routine luf_factorize. */

int bfd_factorize(BFD *bfd, int m, const int bh[], int (*col)
      (void *info, int j, int ind[], double val[]), void *info)
{     LUF *luf;
      int nov, ret;
      if (m < 1)
         xfault("bfd_factorize: m = %d; invalid parameter\n", m);
      if (m > M_MAX)
         xfault("bfd_factorize: m = %d; matrix too big\n", m);
      /* invalidate the factorization */
      bfd->valid = 0;
      /* create the factorization, if necessary */
      nov = 0;
      switch (bfd->type)
      {  case BFD_TFT:
            if (bfd->lpf != NULL)
               lpf_delete_it(bfd->lpf), bfd->lpf = NULL;
            if (bfd->fhv == NULL)
               bfd->fhv = fhv_create_it(), nov = 1;
            break;
         case BFD_TBG:
         case BFD_TGR:
            if (bfd->fhv != NULL)
               fhv_delete_it(bfd->fhv), bfd->fhv = NULL;
            if (bfd->lpf == NULL)
               bfd->lpf = lpf_create_it(), nov = 1;
            break;
         default:
            xfault("bfd_factorize: bfd->type = %d; invalid factorizatio"
               "n type\n", bfd->type);
      }
      /* set control parameters specific to LUF */
      if (bfd->fhv != NULL)
         luf = bfd->fhv->luf;
      else if (bfd->lpf != NULL)
         luf = bfd->lpf->luf;
      else
         xassert(bfd != bfd);
      if (nov) luf->new_sva = bfd->lu_size;
      luf->piv_tol = bfd->piv_tol;
      luf->piv_lim = bfd->piv_lim;
      luf->suhl = bfd->suhl;
      luf->eps_tol = bfd->eps_tol;
      luf->max_gro = bfd->max_gro;
      /* set control parameters specific to FHV */
      if (bfd->fhv != NULL)
      {  if (nov) bfd->fhv->hh_max = bfd->nfs_max;
         bfd->fhv->upd_tol = bfd->upd_tol;
      }
      /* set control parameters specific to LPF */
      if (bfd->lpf != NULL)
      {  if (nov) bfd->lpf->n_max = bfd->nrs_max;
         if (nov) bfd->lpf->v_size = bfd->rs_size;
      }
      /* try to factorize the basis matrix */
      if (bfd->fhv != NULL)
      {  switch (fhv_factorize(bfd->fhv, m, col, info))
         {  case 0:
               break;
            case FHV_ESING:
               ret = BFD_ESING;
               goto done;
            case FHV_ECOND:
               ret = BFD_ECOND;
               goto done;
            default:
               xassert(bfd != bfd);
         }
      }
      else if (bfd->lpf != NULL)
      {  switch (lpf_factorize(bfd->lpf, m, bh, col, info))
         {  case 0:
               /* set the Schur complement update type */
               switch (bfd->type)
               {  case BFD_TBG:
                     /* Bartels-Golub update */
                     bfd->lpf->scf->t_opt = SCF_TBG;
                     break;
                  case BFD_TGR:
                     /* Givens rotation update */
                     bfd->lpf->scf->t_opt = SCF_TGR;
                     break;
                  default:
                     xassert(bfd != bfd);
               }
               break;
            case LPF_ESING:
               ret = BFD_ESING;
               goto done;
            case LPF_ECOND:
               ret = BFD_ECOND;
               goto done;
            default:
               xassert(bfd != bfd);
         }
      }
      else
         xassert(bfd != bfd);
      /* the basis matrix has been successfully factorized */
      bfd->valid = 1;
      bfd->upd_cnt = 0;
      ret = 0;
done: /* return to the calling program */
      return ret;
}

/***********************************************************************
*  NAME
*
*  bfd_ftran - perform forward transformation (solve system B*x = b)
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  void bfd_ftran(BFD *bfd, double x[]);
*
*  DESCRIPTION
*
*  The routine bfd_ftran performs forward transformation, i.e. solves
*  the system B*x = b, where B is the basis matrix, x is the vector of
*  unknowns to be computed, b is the vector of right-hand sides.
*
*  On entry elements of the vector b should be stored in dense format
*  in locations x[1], ..., x[m], where m is the number of rows. On exit
*  the routine stores elements of the vector x in the same locations. */

void bfd_ftran(BFD *bfd, double x[])
{     if (!bfd->valid)
         xfault("bfd_ftran: the factorization is not valid\n");
      if (bfd->fhv != NULL)
         fhv_ftran(bfd->fhv, x);
      else if (bfd->lpf != NULL)
         lpf_ftran(bfd->lpf, x);
      else
         xassert(bfd != bfd);
      return;
}

/***********************************************************************
*  NAME
*
*  bfd_btran - perform backward transformation (solve system B'*x = b)
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  void bfd_btran(BFD *bfd, double x[]);
*
*  DESCRIPTION
*
*  The routine bfd_btran performs backward transformation, i.e. solves
*  the system B'*x = b, where B' is a matrix transposed to the basis
*  matrix B, x is the vector of unknowns to be computed, b is the vector
*  of right-hand sides.
*
*  On entry elements of the vector b should be stored in dense format
*  in locations x[1], ..., x[m], where m is the number of rows. On exit
*  the routine stores elements of the vector x in the same locations. */

void bfd_btran(BFD *bfd, double x[])
{     if (!bfd->valid)
         xfault("bfd_btran: the factorization is not valid\n");
      if (bfd->fhv != NULL)
         fhv_btran(bfd->fhv, x);
      else if (bfd->lpf != NULL)
         lpf_btran(bfd->lpf, x);
      else
         xassert(bfd != bfd);
      return;
}

/***********************************************************************
*  NAME
*
*  bfd_update_it - update LP basis factorization
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  int bfd_update_it(BFD *bfd, int j, int bh, int len, const int ind[],
*     const double val[]);
*
*  DESCRIPTION
*
*  The routine bfd_update_it updates the factorization of the basis
*  matrix B after replacing its j-th column by a new vector.
*
*  The parameter j specifies the number of column of B, which has been
*  replaced, 1 <= j <= m, where m is the order of B.
*
*  The parameter bh specifies the basis header entry for the new column
*  of B, which is the number of the new column in some original matrix.
*  This parameter is optional and can be specified as 0.
*
*  Row indices and numerical values of non-zero elements of the new
*  column of B should be placed in locations ind[1], ..., ind[len] and
*  val[1], ..., val[len], resp., where len is the number of non-zeros
*  in the column. Neither zero nor duplicate elements are allowed.
*
*  RETURNS
*
*  0  The factorization has been successfully updated.
*
*  BFD_ESING
*     New basis matrix is singular within the working precision.
*
*  BFD_ECHECK
*     The factorization is inaccurate.
*
*  BFD_ELIMIT
*     Factorization update limit has been reached.
*
*  BFD_EROOM
*     Overflow of the sparse vector area.
*
*  In case of non-zero return code the factorization becomes invalid.
*  It should not be used until it has been recomputed with the routine
*  bfd_factorize. */

int bfd_update_it(BFD *bfd, int j, int bh, int len, const int ind[],
      const double val[])
{     int ret;
      if (!bfd->valid)
         xfault("bfd_update_it: the factorization is not valid\n");
      /* try to update the factorization */
      if (bfd->fhv != NULL)
      {  switch (fhv_update_it(bfd->fhv, j, len, ind, val))
         {  case 0:
               break;
            case FHV_ESING:
               bfd->valid = 0;
               ret = BFD_ESING;
               goto done;
            case FHV_ECHECK:
               bfd->valid = 0;
               ret = BFD_ECHECK;
               goto done;
            case FHV_ELIMIT:
               bfd->valid = 0;
               ret = BFD_ELIMIT;
               goto done;
            case FHV_EROOM:
               bfd->valid = 0;
               ret = BFD_EROOM;
               goto done;
            default:
               xassert(bfd != bfd);
         }
      }
      else if (bfd->lpf != NULL)
      {  switch (lpf_update_it(bfd->lpf, j, bh, len, ind, val))
         {  case 0:
               break;
            case LPF_ESING:
               bfd->valid = 0;
               ret = BFD_ESING;
               goto done;
            case LPF_ELIMIT:
               bfd->valid = 0;
               ret = BFD_ELIMIT;
               goto done;
            default:
               xassert(bfd != bfd);
         }
      }
      else
         xassert(bfd != bfd);
      /* the factorization has been successfully updated */
      /* increase the update count */
      bfd->upd_cnt++;
      ret = 0;
done: /* return to the calling program */
      return ret;
}

/***********************************************************************
*  NAME
*
*  bfd_delete_it - delete LP basis factorization
*
*  SYNOPSIS
*
*  #include "glpbfd.h"
*  void bfd_delete_it(BFD *bfd);
*
*  DESCRIPTION
*
*  The routine bfd_delete_it deletes LP basis factorization specified
*  by the parameter fhv and frees all memory allocated to this program
*  object. */

void bfd_delete_it(BFD *bfd)
{     if (bfd->fhv != NULL) fhv_delete_it(bfd->fhv);
      if (bfd->lpf != NULL) lpf_delete_it(bfd->lpf);
      xfree(bfd);
      return;
}

/* eof */
