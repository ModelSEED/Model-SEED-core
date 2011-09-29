/* glpapi19.c (flow network problems) */

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
#include "glpnet.h"

/***********************************************************************
*  NAME
*
*  glp_mincost_lp - convert minimum cost flow problem to LP
*
*  SYNOPSIS
*
*  void glp_mincost_lp(glp_prob *lp, glp_graph *G, int names,
*     int v_rhs, int a_low, int a_cap, int a_cost);
*
*  DESCRIPTION
*
*  The routine glp_mincost_lp builds an LP problem, which corresponds
*  to the minimum cost flow problem on the specified network G. */

void glp_mincost_lp(glp_prob *lp, glp_graph *G, int names, int v_rhs,
      int a_low, int a_cap, int a_cost)
{     glp_vertex *v;
      glp_arc *a;
      int i, j, type, ind[1+2];
      double rhs, low, cap, cost, val[1+2];
      if (!(names == GLP_ON || names == GLP_OFF))
         xerror("glp_mincost_lp: names = %d; invalid parameter\n",
            names);
      if (v_rhs >= 0 && v_rhs > G->v_size - (int)sizeof(double))
         xerror("glp_mincost_lp: v_rhs = %d; invalid offset\n", v_rhs);
      if (a_low >= 0 && a_low > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_lp: a_low = %d; invalid offset\n", a_low);
      if (a_cap >= 0 && a_cap > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_lp: a_cap = %d; invalid offset\n", a_cap);
      if (a_cost >= 0 && a_cost > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_lp: a_cost = %d; invalid offset\n", a_cost)
            ;
      glp_erase_prob(lp);
      if (names) glp_set_prob_name(lp, G->name);
      if (G->nv > 0) glp_add_rows(lp, G->nv);
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         if (names) glp_set_row_name(lp, i, v->name);
         if (v_rhs >= 0)
            memcpy(&rhs, (char *)v->data + v_rhs, sizeof(double));
         else
            rhs = 0.0;
         glp_set_row_bnds(lp, i, GLP_FX, rhs, rhs);
      }
      if (G->na > 0) glp_add_cols(lp, G->na);
      for (i = 1, j = 0; i <= G->nv; i++)
      {  v = G->v[i];
         for (a = v->out; a != NULL; a = a->t_next)
         {  j++;
            if (names)
            {  char name[50+1];
               sprintf(name, "x[%d,%d]", a->tail->i, a->head->i);
               xassert(strlen(name) < sizeof(name));
               glp_set_col_name(lp, j, name);
            }
            if (a->tail->i != a->head->i)
            {  ind[1] = a->tail->i, val[1] = +1.0;
               ind[2] = a->head->i, val[2] = -1.0;
               glp_set_mat_col(lp, j, 2, ind, val);
            }
            if (a_low >= 0)
               memcpy(&low, (char *)a->data + a_low, sizeof(double));
            else
               low = 0.0;
            if (a_cap >= 0)
               memcpy(&cap, (char *)a->data + a_cap, sizeof(double));
            else
               cap = 1.0;
            if (cap == DBL_MAX)
               type = GLP_LO;
            else if (low != cap)
               type = GLP_DB;
            else
               type = GLP_FX;
            glp_set_col_bnds(lp, j, type, low, cap);
            if (a_cost >= 0)
               memcpy(&cost, (char *)a->data + a_cost, sizeof(double));
            else
               cost = 0.0;
            glp_set_obj_coef(lp, j, cost);
         }
      }
      xassert(j == G->na);
      return;
}

/**********************************************************************/

int glp_mincost_okalg(glp_graph *G, int v_rhs, int a_low, int a_cap,
      int a_cost, double *sol, int a_x, int v_pi)
{     /* find minimum-cost flow with out-of-kilter algorithm */
      glp_vertex *v;
      glp_arc *a;
      int nv, na, i, k, s, t, *tail, *head, *low, *cap, *cost, *x, *pi,
         ret;
      double sum, temp;
      if (v_rhs >= 0 && v_rhs > G->v_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: v_rhs = %d; invalid offset\n",
            v_rhs);
      if (a_low >= 0 && a_low > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: a_low = %d; invalid offset\n",
            a_low);
      if (a_cap >= 0 && a_cap > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: a_cap = %d; invalid offset\n",
            a_cap);
      if (a_cost >= 0 && a_cost > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: a_cost = %d; invalid offset\n",
            a_cost);
      if (a_x >= 0 && a_x > G->a_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: a_x = %d; invalid offset\n", a_x);
      if (v_pi >= 0 && v_pi > G->v_size - (int)sizeof(double))
         xerror("glp_mincost_okalg: v_pi = %d; invalid offset\n", v_pi);
      /* s is artificial source node */
      s = G->nv + 1;
      /* t is artificial sink node */
      t = s + 1;
      /* nv is the total number of nodes in the resulting network */
      nv = t;
      /* na is the total number of arcs in the resulting network */
      na = G->na + 1;
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         if (v_rhs >= 0)
            memcpy(&temp, (char *)v->data + v_rhs, sizeof(double));
         else
            temp = 0.0;
         if (temp != 0.0) na++;
      }
      /* allocate working arrays */
      tail = xcalloc(1+na, sizeof(int));
      head = xcalloc(1+na, sizeof(int));
      low = xcalloc(1+na, sizeof(int));
      cap = xcalloc(1+na, sizeof(int));
      cost = xcalloc(1+na, sizeof(int));
      x = xcalloc(1+na, sizeof(int));
      pi = xcalloc(1+nv, sizeof(int));
      /* construct the resulting network */
      k = 0;
      /* (original arcs) */
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         for (a = v->out; a != NULL; a = a->t_next)
         {  k++;
            tail[k] = a->tail->i;
            head[k] = a->head->i;
            if (tail[k] == head[k])
            {  ret = GLP_EDATA;
               goto done;
            }
            if (a_low >= 0)
               memcpy(&temp, (char *)a->data + a_low, sizeof(double));
            else
               temp = 0.0;
            if (!(0.0 <= temp && temp <= (double)INT_MAX &&
                  temp == floor(temp)))
            {  ret = GLP_EDATA;
               goto done;
            }
            low[k] = (int)temp;
            if (a_cap >= 0)
               memcpy(&temp, (char *)a->data + a_cap, sizeof(double));
            else
               temp = 1.0;
            if (!((double)low[k] <= temp && temp <= (double)INT_MAX &&
                  temp == floor(temp)))
            {  ret = GLP_EDATA;
               goto done;
            }
            cap[k] = (int)temp;
            if (a_cost >= 0)
               memcpy(&temp, (char *)a->data + a_cost, sizeof(double));
            else
               temp = 0.0;
            if (!(fabs(temp) <= (double)INT_MAX && temp == floor(temp)))
            {  ret = GLP_EDATA;
               goto done;
            }
            cost[k] = (int)temp;
         }
      }
      /* (artificial arcs) */
      sum = 0.0;
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         if (v_rhs >= 0)
            memcpy(&temp, (char *)v->data + v_rhs, sizeof(double));
         else
            temp = 0.0;
         if (!(fabs(temp) <= (double)INT_MAX && temp == floor(temp)))
         {  ret = GLP_EDATA;
            goto done;
         }
         if (temp > 0.0)
         {  /* artificial arc from s to original source i */
            k++;
            tail[k] = s;
            head[k] = i;
            low[k] = cap[k] = (int)(+temp); /* supply */
            cost[k] = 0;
            sum += (double)temp;
         }
         else if (temp < 0.0)
         {  /* artificial arc from original sink i to t */
            k++;
            tail[k] = i;
            head[k] = t;
            low[k] = cap[k] = (int)(-temp); /* demand */
            cost[k] = 0;
         }
      }
      /* (feedback arc from t to s) */
      k++;
      xassert(k == na);
      tail[k] = t;
      head[k] = s;
      if (sum > (double)INT_MAX)
      {  ret = GLP_EDATA;
         goto done;
      }
      low[k] = cap[k] = (int)sum; /* total supply/demand */
      cost[k] = 0;
      /* find minimal-cost circulation in the resulting network */
      ret = okalg(nv, na, tail, head, low, cap, cost, x, pi);
      switch (ret)
      {  case 0:
            /* optimal circulation found */
            ret = 0;
            break;
         case 1:
            /* no feasible circulation exists */
            ret = GLP_ENOPFS;
            break;
         case 2:
            /* integer overflow occured */
            ret = GLP_ERANGE;
            goto done;
         case 3:
            /* optimality test failed (logic error) */
            ret = GLP_EFAIL;
            goto done;
         default:
            xassert(ret != ret);
      }
      /* store solution components */
      /* (objective function = the total cost) */
      if (sol != NULL)
      {  temp = 0.0;
         for (k = 1; k <= na; k++)
            temp += (double)cost[k] * (double)x[k];
         *sol = temp;
      }
      /* (arc flows) */
      if (a_x >= 0)
      {  k = 0;
         for (i = 1; i <= G->nv; i++)
         {  v = G->v[i];
            for (a = v->out; a != NULL; a = a->t_next)
            {  temp = (double)x[++k];
               memcpy((char *)a->data + a_x, &temp, sizeof(double));
            }
         }
      }
      /* (node potentials = Lagrange multipliers) */
      if (v_pi >= 0)
      {  for (i = 1; i <= G->nv; i++)
         {  v = G->v[i];
            temp = - (double)pi[i];
            memcpy((char *)v->data + v_pi, &temp, sizeof(double));
         }
      }
done: /* free working arrays */
      xfree(tail);
      xfree(head);
      xfree(low);
      xfree(cap);
      xfree(cost);
      xfree(x);
      xfree(pi);
      return ret;
}

/***********************************************************************
*  NAME
*
*  glp_maxflow_lp - convert maximum flow problem to LP
*
*  SYNOPSIS
*
*  void glp_maxflow_lp(glp_prob *lp, glp_graph *G, int names, int s,
*     int t, int a_cap);
*
*  DESCRIPTION
*
*  The routine glp_maxflow_lp builds an LP problem, which corresponds
*  to the maximum flow problem on the specified network G. */

void glp_maxflow_lp(glp_prob *lp, glp_graph *G, int names, int s,
      int t, int a_cap)
{     glp_vertex *v;
      glp_arc *a;
      int i, j, type, ind[1+2];
      double cap, val[1+2];
      if (!(names == GLP_ON || names == GLP_OFF))
         xerror("glp_maxflow_lp: names = %d; invalid parameter\n",
            names);
      if (!(1 <= s && s <= G->nv))
         xerror("glp_maxflow_lp: s = %d; source node number out of rang"
            "e\n", s);
      if (!(1 <= t && t <= G->nv))
         xerror("glp_maxflow_lp: t = %d: sink node number out of range "
            "\n", t);
      if (s == t)
         xerror("glp_maxflow_lp: s = t = %d; source and sink nodes must"
            " be distinct\n", s);
      if (a_cap >= 0 && a_cap > G->a_size - (int)sizeof(double))
         xerror("glp_maxflow_lp: a_cap = %d; invalid offset\n", a_cap);
      glp_erase_prob(lp);
      if (names) glp_set_prob_name(lp, G->name);
      glp_set_obj_dir(lp, GLP_MAX);
      glp_add_rows(lp, G->nv);
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         if (names) glp_set_row_name(lp, i, v->name);
         if (i == s)
            type = GLP_LO;
         else if (i == t)
            type = GLP_UP;
         else
            type = GLP_FX;
         glp_set_row_bnds(lp, i, type, 0.0, 0.0);
      }
      if (G->na > 0) glp_add_cols(lp, G->na);
      for (i = 1, j = 0; i <= G->nv; i++)
      {  v = G->v[i];
         for (a = v->out; a != NULL; a = a->t_next)
         {  j++;
            if (names)
            {  char name[50+1];
               sprintf(name, "x[%d,%d]", a->tail->i, a->head->i);
               xassert(strlen(name) < sizeof(name));
               glp_set_col_name(lp, j, name);
            }
            if (a->tail->i != a->head->i)
            {  ind[1] = a->tail->i, val[1] = +1.0;
               ind[2] = a->head->i, val[2] = -1.0;
               glp_set_mat_col(lp, j, 2, ind, val);
            }
            if (a_cap >= 0)
               memcpy(&cap, (char *)a->data + a_cap, sizeof(double));
            else
               cap = 1.0;
            if (cap == DBL_MAX)
               type = GLP_LO;
            else if (cap != 0.0)
               type = GLP_DB;
            else
               type = GLP_FX;
            glp_set_col_bnds(lp, j, type, 0.0, cap);
            if (a->tail->i == s)
               glp_set_obj_coef(lp, j, +1.0);
            else if (a->head->i == s)
               glp_set_obj_coef(lp, j, -1.0);
         }
      }
      xassert(j == G->na);
      return;
}

int glp_maxflow_ffalg(glp_graph *G, int s, int t, int a_cap,
      double *sol, int a_x, int v_cut)
{     /* find maximal flow with Ford-Fulkerson algorithm */
      glp_vertex *v;
      glp_arc *a;
      int nv, na, i, k, flag, *tail, *head, *cap, *x, ret;
      char *cut;
      double temp;
      if (!(1 <= s && s <= G->nv))
         xerror("glp_maxflow_ffalg: s = %d; source node number out of r"
            "ange\n", s);
      if (!(1 <= t && t <= G->nv))
         xerror("glp_maxflow_ffalg: t = %d: sink node number out of ran"
            "ge\n", t);
      if (s == t)
         xerror("glp_maxflow_ffalg: s = t = %d; source and sink nodes m"
            "ust be distinct\n", s);
      if (a_cap >= 0 && a_cap > G->a_size - (int)sizeof(double))
         xerror("glp_maxflow_ffalg: a_cap = %d; invalid offset\n",
            a_cap);
      if (v_cut >= 0 && v_cut > G->v_size - (int)sizeof(int))
         xerror("glp_maxflow_ffalg: v_cut = %d; invalid offset\n",
            v_cut);
      /* allocate working arrays */
      nv = G->nv;
      na = G->na;
      tail = xcalloc(1+na, sizeof(int));
      head = xcalloc(1+na, sizeof(int));
      cap = xcalloc(1+na, sizeof(int));
      x = xcalloc(1+na, sizeof(int));
      if (v_cut < 0)
         cut = NULL;
      else
         cut = xcalloc(1+nv, sizeof(char));
      /* copy the flow network */
      k = 0;
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         for (a = v->out; a != NULL; a = a->t_next)
         {  k++;
            tail[k] = a->tail->i;
            head[k] = a->head->i;
            if (tail[k] == head[k])
            {  ret = GLP_EDATA;
               goto done;
            }
            if (a_cap >= 0)
               memcpy(&temp, (char *)a->data + a_cap, sizeof(double));
            else
               temp = 1.0;
            if (!(0.0 <= temp && temp <= (double)INT_MAX &&
                  temp == floor(temp)))
            {  ret = GLP_EDATA;
               goto done;
            }
            cap[k] = (int)temp;
         }
      }
      xassert(k == na);
      /* find maximal flow in the flow network */
      ffalg(nv, na, tail, head, s, t, cap, x, cut);
      ret = 0;
      /* store solution components */
      /* (objective function = total flow through the network) */
      if (sol != NULL)
      {  temp = 0.0;
         for (k = 1; k <= na; k++)
         {  if (tail[k] == s)
               temp += (double)x[k];
            else if (head[k] == s)
               temp -= (double)x[k];
         }
         *sol = temp;
      }
      /* (arc flows) */
      if (a_x >= 0)
      {  k = 0;
         for (i = 1; i <= G->nv; i++)
         {  v = G->v[i];
            for (a = v->out; a != NULL; a = a->t_next)
            {  temp = (double)x[++k];
               memcpy((char *)a->data + a_x, &temp, sizeof(double));
            }
         }
      }
      /* (node flags) */
      if (v_cut >= 0)
      {  for (i = 1; i <= G->nv; i++)
         {  v = G->v[i];
            flag = cut[i];
            memcpy((char *)v->data + v_cut, &flag, sizeof(int));
         }
      }
done: /* free working arrays */
      xfree(tail);
      xfree(head);
      xfree(cap);
      xfree(x);
      if (cut != NULL) xfree(cut);
      return ret;
}

/* eof */
