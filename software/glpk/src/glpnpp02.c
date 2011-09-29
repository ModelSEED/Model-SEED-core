/* glpnpp02.c */

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

#include "glpnpp.h"

/***********************************************************************
*  FREE ROW
*
*  Let row p be free, i.e. have no bounds:
*
*     -inf < sum a[p,j] * x[j] < +inf.
*
*  This "constraint" can never be active, so the free row is redundant
*  and therefore can be removed from the problem. */

struct free_row
{     /* free row */
      int p;
      /* reference number of the row */
      NPPLFE *ptr;
      /* list of non-zero coefficients a[p,j] */
};

static void rcv_free_row(NPP *npp, void *info);

void npp_free_row(NPP *npp, NPPROW *row)
{     /* process free row */
      struct free_row *info;
      NPPAIJ *aij;
      NPPLFE *lfe;
      /* the row must be free */
      xassert(row->lb == -DBL_MAX && row->ub == +DBL_MAX);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_free_row, sizeof(struct free_row));
      info->p = row->i;
      info->ptr = NULL;
      /* save the row coefficients */
      for (aij = row->ptr; aij != NULL; aij = aij->r_next)
      {  lfe = dmp_get_atom(npp->stack, sizeof(NPPLFE));
         lfe->ref = aij->col->j;
         lfe->val = aij->val;
         lfe->next = info->ptr;
         info->ptr = lfe;
      }
      /* remove the row from the problem */
      npp_del_row(npp, row);
      return;
}

static void rcv_free_row(NPP *npp, void *_info)
{     /* recover free row */
      struct free_row *info = _info;
      NPPLFE *lfe;
      double sum;
      if (npp->sol == GLP_SOL)
      {  /* the free row is non-active */
         npp->r_stat[info->p] = GLP_BS;
      }
      /* compute auxiliary variable x[p] = sum a[p,j] * x[j] */
      sum = 0.0;
      for (lfe = info->ptr; lfe != NULL; lfe = lfe->next)
         sum += lfe->val * npp->c_prim[lfe->ref];
      npp->r_prim[info->p] = sum;
      /* reduced cost of x[p] is obviously zero */
      if (npp->sol != GLP_MIP)
         npp->r_dual[info->p] = 0.0;
      return;
}

/***********************************************************************
*  ROW OF 'GREATER THAN OR EQUAL TO' TYPE
*
*  Let row p be a 'greater than or equal to' inequality constraint:
*
*     L[p] <= sum a[p,j] * x[j] (<= U[p]).
*
*  Then it can be converted to equality constraint as follows:
*
*     sum a[p,j] * x[j] - s = L[p],
*
*     0 <= s (<= U[p] - L[p]),
*
*  where s is a surplus variable. */

struct ineq_row
{     /* inequality constraint row */
      int p;
      /* reference number of the row */
      int s;
      /* reference number of slack/surplus variable */
};

static void rcv_gteq_row(NPP *npp, void *info);

void npp_gteq_row(NPP *npp, NPPROW *row)
{     /* process row of 'greater than or equal to' type */
      struct ineq_row *info;
      NPPCOL *col;
      /* the row must have lower bound */
      xassert(row->lb != -DBL_MAX);
      /* create surplus variable */
      col = npp_add_col(npp);
      col->lb = 0.0;
      col->ub = (row->ub == +DBL_MAX ? +DBL_MAX : row->ub - row->lb);
      /* and add it to the transformed problem */
      npp_add_aij(npp, row, col, -1.0);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_gteq_row, sizeof(struct ineq_row));
      info->p = row->i;
      info->s = col->j;
      /* convert the row to equality constraint */
      row->ub = row->lb;
      return;
}

static void rcv_gteq_row(NPP *npp, void *_info)
{     /* recover row of 'greater than or equal to' type */
      struct ineq_row *info = _info;
      if (npp->sol == GLP_SOL)
      {  if (npp->r_stat[info->p] == GLP_BS)
            /* degenerate case; x[p] remains basic */;
         else if (npp->c_stat[info->s] == GLP_BS)
            npp->r_stat[info->p] = GLP_BS;
         else if (npp->c_stat[info->s] == GLP_NL)
            npp->r_stat[info->p] = GLP_NL;
         else if (npp->c_stat[info->s] == GLP_NU)
            npp->r_stat[info->p] = GLP_NU;
         else
            xassert(npp != npp);
      }
      /* compute auxiliary variable x[p] = sum a[p,j] * x[j] =
         = (sum a[p,j] * x[j] - s) + s = x'[p] + s */
      npp->r_prim[info->p] += npp->c_prim[info->s];
      /* determine reduced cost of x[p] */
      if (npp->sol != GLP_MIP)
         npp->r_dual[info->p] = + npp->c_dual[info->s];
      return;
}

/***********************************************************************
*  ROW OF 'LESS THAN OR EQUAL TO' TYPE
*
*  Let row p be a 'less than or equal to' inequality constraint:
*
*     (L[p] <=) sum a[p,j] * x[j] <= U[p].
*
*  Then it can be converted to equality constraint as follows:
*
*     sum a[p,j] * x[j] + s = U[p],
*
*     0 <= s (<= U[p] - L[p]),
*
*  where s is a slack variable. */

static void rcv_lteq_row(NPP *npp, void *info);

void npp_lteq_row(NPP *npp, NPPROW *row)
{     /* process row of 'less than or equal to' type */
      struct ineq_row *info;
      NPPCOL *col;
      /* the row must have upper bound */
      xassert(row->ub != +DBL_MAX);
      /* create slack variable */
      col = npp_add_col(npp);
      col->lb = 0.0;
      col->ub = (row->lb == -DBL_MAX ? +DBL_MAX : row->ub - row->lb);
      /* and add it to the transformed problem */
      npp_add_aij(npp, row, col, +1.0);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_lteq_row, sizeof(struct ineq_row));
      info->p = row->i;
      info->s = col->j;
      /* convert the row to equality constraint */
      row->lb = row->ub;
      return;
}

static void rcv_lteq_row(NPP *npp, void *_info)
{     /* recover row of 'less than or equal to' type */
      struct ineq_row *info = _info;
      if (npp->sol == GLP_SOL)
      {  if (npp->r_stat[info->p] == GLP_BS)
            /* degenerate case; x[p] remains basic */;
         else if (npp->c_stat[info->s] == GLP_BS)
            npp->r_stat[info->p] = GLP_BS;
         else if (npp->c_stat[info->s] == GLP_NL)
            npp->r_stat[info->p] = GLP_NU;
         else if (npp->c_stat[info->s] == GLP_NU)
            npp->r_stat[info->p] = GLP_NL;
         else
            xassert(npp != npp);
      }
      /* compute auxiliary variable x[p] = sum a[p,j] * x[j] =
         = (sum a[p,j] * x[j] + s) - s = x'[p] - s */
      npp->r_prim[info->p] -= npp->c_prim[info->s];
      /* determine reduced cost of x[p] */
      if (npp->sol != GLP_MIP)
         npp->r_dual[info->p] = - npp->c_dual[info->s];
      return;
}

/***********************************************************************
*  FREE COLUMN
*
*  Let column q be free:
*
*     -inf < x[q] < +inf.                                           (18)
*
*  Then it can be replaced by the following difference:
*
*     x[q] = x' - x''                                               (19)
*
*  where x', x'' are non-negative variables. */

struct free_col
{     /* free column */
      int q;
      /* reference number of column x[q] that becomes x' */
      int j;
      /* reference number of column x'' */
};

static void rcv_free_col(NPP *npp, void *info);

void npp_free_col(NPP *npp, NPPCOL *col)
{     /* process free column */
      struct free_col *info;
      NPPCOL *ccc;
      NPPAIJ *aij;
      /* the column must be free */
      xassert(col->lb == -DBL_MAX && col->ub == +DBL_MAX);
      /* variable x[q] becomes x' */
      col->lb = 0.0, col->ub = +DBL_MAX;
      /* create variable x'' */
      ccc = npp_add_col(npp);
      ccc->lb = 0.0, ccc->ub = +DBL_MAX;
      /* duplicate objective coefficient */
      ccc->coef = - col->coef;
      /* duplicate column of the constraint matrix */
      for (aij = col->ptr; aij != NULL; aij = aij->c_next)
         npp_add_aij(npp, aij->row, ccc, - aij->val);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_free_col, sizeof(struct free_col));
      info->q = col->j;
      info->j = ccc->j;
      return;
}

static void rcv_free_col(NPP *npp, void *_info)
{     /* recover free column */
      struct free_col *info = _info;
      if (npp->sol == GLP_SOL)
      {  if (npp->c_stat[info->q] == GLP_NL &&
             npp->c_stat[info->j] == GLP_NL)
         {  /* denegerate case; x[q] remains non-basic (super basic) */
            npp->c_stat[info->q] = GLP_NF;
         }
         else
         {  /* note that x' and x'' cannot be both basic due to linear
               dependence */
            npp->c_stat[info->q] = GLP_BS;
         }
      }
      /* compute variable x[q] = x' - x'' */
      npp->c_prim[info->q] -= npp->c_prim[info->j];
      /* since x[q] has no bounds, in any optimal and therefore dual
         feasible solution its reduced cost must be zero */
      if (npp->sol != GLP_MIP)
         npp->c_dual[info->q] = 0.0;
      return;
}

/***********************************************************************
*  COLUMN WITH LOWER BOUND
*
*  Let column q have lower bound:
*
*     l[q] <= x[q] (<= u[q]).
*
*  Then it can be substituted as follows:
*
*     x[q] = l[q] + x',
*
*  where 0 <= x' (<= u[q] - l[q]).
*
*  Substitution into the objective function gives:
*
*     z = sum c[j] * x[j] + c0 =
*          j
*
*       = sum c[j] * x[j] + c[q] * x[q] + c0 =
*         j!=q
*
*       = sum c[j] * x[j] + c[q] * (l[q] + x') + c0 =
*         j!=q
*
*       = sum c[j] * x[j] + c[q] * x' + (c0)',
*         j!=q
*
*  where (c0)' = c0 + c[q] * l[q].
*
*  Substitution into i-th row, 1 <= i <= m, a[i,q] != 0, gives:
*
*     L[i] <= sum a[i,j] * x[j] <= U[i]  ==>
*              j
*
*     L[i] <= sum a[i,j] * x[j] + a[i,q] * x[q] <= U[i]  ==>
*             j!=q
*
*     L[i] <= sum a[i,j] * x[j] + a[i,q] * (l[q] + x') <= U[i]  ==>
*             j!=q
*
*     L'[i] <= sum a[i,j] * x[j] + a[i,q] * x' <= U'[i],
*
*  where L'[i] = L[i] - a[i,q] * l[q], U'[i] = U[i] - a[i,q] * l[q]. */

struct bnd_col
{     /* bounded column */
      int q;
      /* reference number of column x[q] that becomes x' */
      double b;
      /* lower/upper bound of column x[q] */
      NPPLFE *ptr;
      /* list of non-zero coefficients a[i,q] */
};

static void rcv_lbnd_col(NPP *npp, void *info);

void npp_lbnd_col(NPP *npp, NPPCOL *col)
{     /* process column with lower bound */
      struct bnd_col *info;
      NPPROW *row;
      NPPAIJ *aij;
      NPPLFE *lfe;
      /* the column must have lower bound */
      xassert(col->lb != -DBL_MAX);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_lbnd_col, sizeof(struct bnd_col));
      info->q = col->j;
      info->b = col->lb;
      info->ptr = NULL;
      /* substitute x[q] into the objective function */
      npp->c0 += col->coef * col->lb;
      /* substitute x[q] into rows and save the column coefficients */
      for (aij = col->ptr; aij != NULL; aij = aij->c_next)
      {  row = aij->row;
         if (row->lb == row->ub)
            row->ub = (row->lb -= aij->val * col->lb);
         else
         {  if (row->lb != -DBL_MAX)
               row->lb -= aij->val * col->lb;
            if (row->ub != +DBL_MAX)
               row->ub -= aij->val * col->lb;
         }
         lfe = dmp_get_atom(npp->stack, sizeof(NPPLFE));
         lfe->ref = row->i;
         lfe->val = aij->val;
         lfe->next = info->ptr;
         info->ptr = lfe;
      }
      /* column x[q] becomes column x' */
      if (col->ub != +DBL_MAX)
         col->ub -= col->lb;
      col->lb = 0.0;
      return;
}

static void rcv_lbnd_col(NPP *npp, void *_info)
{     /* recover column with lower bound */
      struct bnd_col *info = _info;
      NPPLFE *lfe;
      if (npp->sol == GLP_SOL)
      {  /* x[q] has the same status as x' (NL, NU, or BS) */
         npp->c_stat[info->q] = npp->c_stat[info->q];
      }
      /* compute variable x[q] = l[q] + x' */
      npp->c_prim[info->q] = info->b + npp->c_prim[info->q];
      /* compute auxiliary variables x[i] = x'[i] + a[i,q] * l[q] */
      for (lfe = info->ptr; lfe != NULL; lfe = lfe->next)
         npp->r_prim[lfe->ref] += lfe->val * info->b;
      /* determine reduced cost of x[q] */
      if (npp->sol != GLP_MIP)
         npp->c_dual[info->q] = + npp->c_dual[info->q];
      return;
}

/***********************************************************************
*  COLUMN WITH UPPER BOUND
*
*  Let column q have upper bound:
*
*     (l[q] <=) x[q] <= u[q].
*
*  Then it can be substituted as follows:
*
*     x[q] = u[q] - x',
*
*  where 0 <= x' (<= u[q] - l[q]).
*
*  Substitution into the objective function gives:
*
*     z = sum c[j] * x[j] + c0 =
*          j
*
*       = sum c[j] * x[j] + c[q] * x[q] + c0 =
*         j!=q
*
*       = sum c[j] * x[j] + c[q] * (u[q] - x') + c0 =
*         j!=q
*
*       = sum c[j] * x[j] - c[q] * x' + (c0)',
*         j!=q
*
*  where (c0)' = c0 + c[q] * u[q].
*
*  Substitution into i-th row, 1 <= i <= m, a[i,q] != 0, gives:
*
*     L[i] <= sum a[i,j] * x[j] <= U[i]  ==>
*              j
*
*     L[i] <= sum a[i,j] * x[j] + a[i,q] * x[q] <= U[i]  ==>
*             j!=q
*
*     L[i] <= sum a[i,j] * x[j] + a[i,q] * (u[q] - x') <= U[i]  ==>
*             j!=q
*
*     L'[i] <= sum a[i,j] * x[j] - a[i,q] * x' <= U'[i],
*
*  where L'[i] = L[i] - a[i,q] * u[q], U'[i] = U[i] - a[i,q] * u[q]. */

static void rcv_ubnd_col(NPP *npp, void *info);

void npp_ubnd_col(NPP *npp, NPPCOL *col)
{     /* process column with upper bound */
      struct bnd_col *info;
      NPPROW *row;
      NPPAIJ *aij;
      NPPLFE *lfe;
      /* the column must have upper bound */
      xassert(col->ub != +DBL_MAX);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_ubnd_col, sizeof(struct bnd_col));
      info->q = col->j;
      info->b = col->ub;
      info->ptr = NULL;
      /* substitute x[q] into the objective function */
      npp->c0 += col->coef * col->ub;
      col->coef = - col->coef;
      /* substitute x[q] into rows and save the column coefficients */
      for (aij = col->ptr; aij != NULL; aij = aij->c_next)
      {  row = aij->row;
         if (row->lb == row->ub)
            row->ub = (row->lb -= aij->val * col->ub);
         else
         {  if (row->lb != -DBL_MAX)
               row->lb -= aij->val * col->ub;
            if (row->ub != +DBL_MAX)
               row->ub -= aij->val * col->ub;
         }
         lfe = dmp_get_atom(npp->stack, sizeof(NPPLFE));
         lfe->ref = row->i;
         lfe->val = aij->val, aij->val = - aij->val;
         lfe->next = info->ptr;
         info->ptr = lfe;
      }
      /* column x[q] becomes column x' */
      if (col->lb != -DBL_MAX)
         col->ub -= col->lb;
      else
         col->ub = +DBL_MAX;
      col->lb = 0.0;
      return;
}

static void rcv_ubnd_col(NPP *npp, void *_info)
{     /* recover column with upper bound */
      struct bnd_col *info = _info;
      NPPLFE *lfe;
      if (npp->sol == GLP_BS)
      {  if (npp->c_stat[info->q] == GLP_BS)
            /* x[q] remains basic */;
         else if (npp->c_stat[info->q] == GLP_NL)
            npp->c_stat[info->q] = GLP_NU;
         else if (npp->c_stat[info->q] == GLP_NU)
            npp->c_stat[info->q] = GLP_NL;
         else
            xassert(npp != npp);
      }
      /* compute variable x[q] = u[q] - x' */
      npp->c_prim[info->q] = info->b - npp->c_prim[info->q];
      /* compute auxiliary variables x[i] = x'[i] + a[i,q] * u[q] */
      for (lfe = info->ptr; lfe != NULL; lfe = lfe->next)
         npp->r_prim[lfe->ref] += lfe->val * info->b;
      /* determine reduced cost of x[q] */
      if (npp->sol != GLP_MIP)
         npp->c_dual[info->q] = - npp->c_dual[info->q];
      return;
}

/***********************************************************************
*  DOUBLE-BOUNDED COLUMN
*
*  Let column q be double-bounded with zero lower bound:
*
*     0 <= x[q] <= u[q].
*
*  Then its upper bound u[q] can be replaced by the following equality
*  constraint:
*
*     x[q] + x' = u[q],
*
*  where x' is a non-negative variable. */

struct dbnd_col
{     /* double-bounded column */
      int q;
      /* reference number of column x[q] */
      int j;
      /* reference number of column x' */
};

static void rcv_dbnd_col(NPP *npp, void *info);

void npp_dbnd_col(NPP *npp, NPPCOL *col)
{     /* process double-bounded column */
      struct dbnd_col *info;
      NPPROW *row;
      NPPCOL *ccc;
      /* the column must be double-bounded */
      xassert(col->lb == 0.0 && col->ub != +DBL_MAX);
      /* create variable x' */
      ccc = npp_add_col(npp);
      ccc->lb = 0.0, ccc->ub = +DBL_MAX;
      /* create equality constraint x[q] + x' = u[q] */
      row = npp_add_row(npp);
      row->lb = row->ub = col->ub;
      npp_add_aij(npp, row, col, +1.0);
      npp_add_aij(npp, row, ccc, +1.0);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_dbnd_col, sizeof(struct dbnd_col));
      info->q = col->j;
      info->j = ccc->j;
      /* remove upper bound of x[q] */
      col->ub = +DBL_MAX;
      return;
}

static void rcv_dbnd_col(NPP *npp, void *_info)
{     struct dbnd_col *info = _info;
      if (npp->sol == GLP_BS)
      {  /* note that x[q] and x' cannot be both non-basic */
         if (npp->c_stat[info->q] == GLP_NL)
            npp->c_stat[info->q] = GLP_NL;
         else if (npp->c_stat[info->j] == GLP_NL)
            npp->c_stat[info->q] = GLP_NU;
         else
            npp->c_stat[info->q] = GLP_BS;
      }
      /* variable x[q] is already computed */
      /* compute reduced cost of x[q] */
      if (npp->sol != GLP_MIP)
         npp->c_dual[info->q] -= npp->c_dual[info->j];
      return;
}

/***********************************************************************
*  FIXED COLUMN
*
*  Let column q be fixed:
*
*     x[q] = s[q].
*
*  where s[q] is a given value. Then it can be substituted and thereby
*  removed from the problem.
*
*  Substitution into the objective function gives:
*
*     z = sum c[j] * x[j] + c0 =
*          j
*
*       = sum c[j] * x[j] + c[q] * s[q] + c0 =
*         j!=q
*
*       = sum c[j] * x[j] + (c0)',
*         j!=q
*
*  where (c0)' = c0 + c[q] * s[q].
*
*  Substitution into i-th row, 1 <= i <= m, a[i,q] != 0, gives:
*
*     L[i] <= sum a[i,j] * x[j] <= U[i]  ==>
*              j
*
*     L[i] <= sum a[i,j] * x[j] + a[i,q] * s[q] <= U[i]  ==>
*             j!=q
*
*     L'[i] <= sum a[i,j] * x[j] + a[i,q] * x' <= U'[i],
*
*  where L'[i] = L[i] - a[i,q] * s[q], U'[i] = U[i] - a[i,q] * s[q].
*
*  Since x[q] is fixed, it is non-basic. Reduced cost of x[q] can be
*  computed using the dual equality constraint:
*
*     sum a[i,q] * pi[i] + lambda[q] = c[q],
*      i
*
*  from which it follows that:
*
*     lambda[q] = c[q] - sum a[i,q] * pi[i],
*                         i
*
*  where c[q] is objective coefficient at x[q], pi[i] are reduced costs
*  of corresponding auxiliary variables. */

struct fixed_col
{     /* fixed column */
      int q;
      /* reference number of the column */
      double s;
      /* value, at which the column is fixed */
      double c;
      /* objective coefficient */
      NPPLFE *ptr;
      /* list of non-zero coefficients a[i,q] */
};

static void rcv_fixed_col(NPP *npp, void *info);

void npp_fixed_col(NPP *npp, NPPCOL *col)
{     /* process fixed column */
      struct fixed_col *info;
      NPPROW *row;
      NPPAIJ *aij;
      NPPLFE *lfe;
      /* the column must be fixed */
      xassert(col->lb == col->ub);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_fixed_col, sizeof(struct fixed_col));
      info->q = col->j;
      info->s = col->lb;
      info->c = col->coef;
      info->ptr = NULL;
      /* substitute x[q] into the objective function */
      npp->c0 += col->coef * col->lb;
      /* substitute x[q] into rows and save the column coefficients */
      for (aij = col->ptr; aij != NULL; aij = aij->c_next)
      {  row = aij->row;
         if (row->lb == row->ub)
            row->ub = (row->lb -= aij->val * col->lb);
         else
         {  if (row->lb != -DBL_MAX)
               row->lb -= aij->val * col->lb;
            if (row->ub != +DBL_MAX)
               row->ub -= aij->val * col->lb;
         }
         lfe = dmp_get_atom(npp->stack, sizeof(NPPLFE));
         lfe->ref = aij->row->i;
         lfe->val = aij->val;
         lfe->next = info->ptr;
         info->ptr = lfe;
      }
      /* remove x[q] from the problem */
      npp_del_col(npp, col);
      return;
}

static void rcv_fixed_col(NPP *npp, void *_info)
{     /* recover fixed column */
      struct fixed_col *info = _info;
      NPPLFE *lfe;
      double sum;
      if (npp->sol == GLP_SOL)
      {  /* the fixed column is non-basic */
         npp->c_stat[info->q] = GLP_NS;
      }
      /* determine variable x[q] = s[q] */
      npp->c_prim[info->q] = info->s;
      /* compute auxiliary variables x[i] = x'[i] + a[i,q] * s[q] */
      for (lfe = info->ptr; lfe != NULL; lfe = lfe->next)
         npp->r_prim[lfe->ref] += lfe->val * info->s;
      /* compute reduced cost of x[q] */
      if (npp->sol != GLP_MIP)
      {  sum = info->c;
         for (lfe = info->ptr; lfe != NULL; lfe = lfe->next)
            sum -= lfe->val * npp->r_dual[lfe->ref];
         npp->c_dual[info->q] = sum;
      }
      return;
}

/***********************************************************************
*  EMPTY ROW
*
*  Let row p be empty:
*
*     L[p] <= sum 0 * x[j] <= U[p].
*
*  If L[p] <= 0 <= U[p], then the row is redundant and can be removed
*  from the problem. Otherwise, the row is primal infeasible. */

struct empty_row
{     /* empty row */
      int p;
      /* reference number of the row */
};

static void rcv_empty_row(NPP *npp, void *info);

int npp_empty_row(NPP *npp, NPPROW *row)
{     /* process empty row */
      struct empty_row *info;
      double eps = 1e-6;
      /* the row must be empty */
      xassert(row->ptr == NULL);
      /* check for primal feasibility */
      if (row->lb > +eps || row->ub < -eps)
         return 1;
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_empty_row, sizeof(struct empty_row));
      info->p = row->i;
      /* remove the row from the problem */
      npp_del_row(npp, row);
      return 0;
}

static void rcv_empty_row(NPP *npp, void *_info)
{     /* recover empty row */
      struct empty_row *info = _info;
      if (npp->sol == GLP_SOL)
      {  /* the empty row is non-active */
         npp->r_stat[info->p] = GLP_BS;
      }
      /* auxiliary variable x[p] is zero */
      npp->r_prim[info->p] = 0.0;
      /* and its reduced cost is also zero */
      if (npp->sol != GLP_MIP)
         npp->r_dual[info->p] = 0.0;
      return;
}

/***********************************************************************
*  EMPTY COLUMN
*
*  Let column q be empty, i.e. have zero coefficients in all rows.
*
*  If c[q] = 0, x[q] can be fixed at any feasible value. If c[q] < 0,
*  x[q] must be fixed at its lower bound, and if c[q] > 0, x[q] must be
*  fixed at its upper bound. If x[q] has no appropriate lower/upper
*  bound to be fixed at, the column is dual infeasible. */

struct empty_col
{     /* empty column */
      int q;
      /* reference number of the column */
      int stat;
      /* status in basic solution */
};

static void rcv_empty_col(NPP *npp, void *info);

int npp_empty_col(NPP *npp, NPPCOL *col)
{     /* process empty column */
      struct empty_col *info;
      double eps = 1e-6;
      /* the column must be empty */
      xassert(col->ptr == NULL);
      /* check for dual feasibility */
      if (col->coef > +eps && col->lb == -DBL_MAX)
         return 1;
      if (col->coef < -eps && col->ub == +DBL_MAX)
         return 1;
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_empty_col, sizeof(struct empty_col));
      info->q = col->j;
      /* fix the column */
      if (col->lb == -DBL_MAX && col->ub == +DBL_MAX)
      {  /* free variable */
         info->stat = GLP_NS;
         col->lb = col->ub = 0.0;
      }
      else if (col->ub == +DBL_MAX)
lo:   {  /* variable with lower bound */
         info->stat = GLP_NL;
         col->ub = col->lb;
      }
      else if (col->lb == -DBL_MAX)
up:   {  /* variable with upper bound */
         info->stat = GLP_NU;
         col->lb = col->ub;
      }
      else if (col->lb != col->ub)
      {  /* double-bounded variable */
         if (col->coef > 0.0) goto lo;
         if (col->coef < 0.0) goto up;
         if (fabs(col->lb) <= fabs(col->ub)) goto lo; else goto up;
      }
      else
      {  /* fixed variable */
         info->stat = GLP_NS;
      }
      /* process fixed column */
      npp_fixed_col(npp, col);
      return 0;
}

static void rcv_empty_col(NPP *npp, void *_info)
{     /* recover empty column */
      struct empty_col *info = _info;
      if (npp->sol == GLP_SOL)
         npp->c_stat[info->q] = (char)info->stat;
      return;
}

/***********************************************************************
*  ROW SINGLETON (EQUALITY CONSTRAINT)
*
*  Let row p be an equality constraint having the only column:
*
*     a[p,q] * x[q] = b[p].
*
*  Then it implies fixing x[q]:
*
*     x[q] = b[p] / a[p,q].
*
*  If this implied value of x[q] does not conflict with its bounds, it
*  can be fixed, in which case row p becomes redundant. Otherwise, the
*  row is primal infeasible.
*
*  On entry to the recovering routine the column q is already recovered
*  as if it were a fixed column, i.e. it is non-basic with primal value
*  x[q] and reduced cost lambda[q]. The routine makes it basic with the
*  same primal value and zero reduced cost.
*
*  Then the recovering routine makes the row p non-basic, and computes
*  its primal value x[p] = a[p,q] * x[q] as well as its reduced cost:
*
*     lambda[p] = lambda[q] / a[p,q],
*
*  where lambda[q] is a dual value, which the column q has on entry to
*  the recovering routine. */

struct sngl_row
{     /* row singleton (equality constraint) */
      int p;
      /* reference number of the row */
      int q;
      /* reference number of the column */
      double apq;
      /* constraint coefficient */
};

static void rcv_sngl_row(NPP *npp, void *info);

int npp_sngl_row(NPP *npp, NPPROW *row)
{     /* process row singleton (equality constraint) */
      struct sngl_row *info;
      NPPCOL *col;
      NPPAIJ *aij;
      double val, eps;
      /* the row must be singleton equality constraint */
      xassert(row->lb == row->ub);
      xassert(row->ptr != NULL && row->ptr->r_next == NULL);
      /* compute the implied value of x[q] */
      aij = row->ptr;
      val = row->lb / aij->val;
      /* check for primal feasibility */
      col = aij->col;
      if (col->lb != -DBL_MAX)
      {  eps = 1e-6 + 1e-9 * fabs(col->lb);
         if (val < col->lb - eps) return 1;
      }
      if (col->ub != +DBL_MAX)
      {  eps = 1e-6 + 1e-9 * fabs(col->ub);
         if (val > col->ub + eps) return 1;
      }
      /* check for integrality */
      if (npp->sol == GLP_MIP && col->kind == GLP_IV)
         xassert(npp != npp);
      /* create transformation entry */
      info = npp_push_tse(npp,
         rcv_sngl_row, sizeof(struct sngl_row));
      info->p = row->i;
      info->q = col->j;
      info->apq = aij->val;
      /* remove the row from the problem */
      npp_del_row(npp, row);
      /* fix the column and process it */
      col->lb = col->ub = val;
      npp_fixed_col(npp, col);
      return 0;
}

static void rcv_sngl_row(NPP *npp, void *_info)
{     /* recover row singleton (equality constraint) */
      struct sngl_row *info = _info;
      /* x[q] is already recovered */
      if (npp->sol == GLP_SOL)
      {  xassert(npp->c_stat[info->q] == GLP_NS);
         npp->r_stat[info->p] = GLP_NS;
         npp->c_stat[info->q] = GLP_BS;
      }
      /* compute auxiliary variable x[p] */
      npp->r_prim[info->p] = info->apq * npp->c_prim[info->q];
      /* compute reduced cost of x[p] and x[q] */
      if (npp->sol != GLP_MIP)
      {  npp->r_dual[info->p] = npp->c_dual[info->q] / info->apq;
         npp->c_dual[info->q] = 0.0;
      }
      return;
}

/* eof */
