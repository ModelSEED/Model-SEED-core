/* glpapi18.c (graph and network analysis routines) */

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
*  glp_weak_comp - find all weakly connected components of graph
*
*  SYNOPSIS
*
*  int glp_weak_comp(glp_graph *G, int v_num);
*
*  DESCRIPTION
*
*  The routine glp_weak_comp finds all weakly connected components of
*  the specified graph.
*
*  The parameter v_num specifies an offset of the field of type int
*  in the vertex data block, to which the routine stores the number of
*  a (weakly) connected component containing that vertex. If v_num < 0,
*  no component numbers are stored.
*
*  The components are numbered in arbitrary order from 1 to nc, where
*  nc is the total number of components found, 0 <= nc <= |V|.
*
*  RETURNS
*
*  The routine returns nc, the total number of components found. */

int glp_weak_comp(glp_graph *G, int v_num)
{     glp_vertex *v;
      glp_arc *a;
      int f, i, j, nc, nv, pos1, pos2, *prev, *next, *list;
      if (v_num >= 0 && v_num > G->v_size - (int)sizeof(int))
         xerror("glp_weak_comp: v_num = %d; invalid offset\n", v_num);
      nv = G->nv;
      if (nv == 0)
      {  nc = 0;
         goto done;
      }
      /* allocate working arrays */
      prev = xcalloc(1+nv, sizeof(int));
      next = xcalloc(1+nv, sizeof(int));
      list = xcalloc(1+nv, sizeof(int));
      /* if vertex i is unlabelled, prev[i] is the index of previous
         unlabelled vertex, and next[i] is the index of next unlabelled
         vertex; if vertex i is labelled, then prev[i] < 0, and next[i]
         is the connected component number */
      /* initially all vertices are unlabelled */
      f = 1;
      for (i = 1; i <= nv; i++)
         prev[i] = i - 1, next[i] = i + 1;
      next[nv] = 0;
      /* main loop (until all vertices have been labelled) */
      nc = 0;
      while (f != 0)
      {  /* take an unlabelled vertex */
         i = f;
         /* and remove it from the list of unlabelled vertices */
         f = next[i];
         if (f != 0) prev[f] = 0;
         /* label the vertex; it begins a new component */
         prev[i] = -1, next[i] = ++nc;
         /* breadth first search */
         list[1] = i, pos1 = pos2 = 1;
         while (pos1 <= pos2)
         {  /* dequeue vertex i */
            i = list[pos1++];
            /* consider all arcs incoming to vertex i */
            for (a = G->v[i]->in; a != NULL; a = a->h_next)
            {  /* vertex j is adjacent to vertex i */
               j = a->tail->i;
               if (prev[j] >= 0)
               {  /* vertex j is unlabelled */
                  /* remove it from the list of unlabelled vertices */
                  if (prev[j] == 0)
                     f = next[j];
                  else
                     next[prev[j]] = next[j];
                  if (next[j] == 0)
                     ;
                  else
                     prev[next[j]] = prev[j];
                  /* label the vertex */
                  prev[j] = -1, next[j] = nc;
                  /* and enqueue it for further consideration */
                  list[++pos2] = j;
               }
            }
            /* consider all arcs outgoing from vertex i */
            for (a = G->v[i]->out; a != NULL; a = a->t_next)
            {  /* vertex j is adjacent to vertex i */
               j = a->head->i;
               if (prev[j] >= 0)
               {  /* vertex j is unlabelled */
                  /* remove it from the list of unlabelled vertices */
                  if (prev[j] == 0)
                     f = next[j];
                  else
                     next[prev[j]] = next[j];
                  if (next[j] == 0)
                     ;
                  else
                     prev[next[j]] = prev[j];
                  /* label the vertex */
                  prev[j] = -1, next[j] = nc;
                  /* and enqueue it for further consideration */
                  list[++pos2] = j;
               }
            }
         }
      }
      /* store component numbers */
      if (v_num >= 0)
      {  for (i = 1; i <= nv; i++)
         {  v = G->v[i];
            memcpy((char *)v->data + v_num, &next[i], sizeof(int));
         }
      }
      /* free working arrays */
      xfree(prev);
      xfree(next);
      xfree(list);
done: return nc;
}

/***********************************************************************
*  NAME
*
*  glp_strong_comp - find all strongly connected components of graph
*
*  SYNOPSIS
*
*  int glp_strong_comp(glp_graph *G, int v_num);
*
*  DESCRIPTION
*
*  The routine glp_strong_comp finds all strongly connected components
*  of the specified graph.
*
*  The parameter v_num specifies an offset of the field of type int
*  in the vertex data block, to which the routine stores the number of
*  a strongly connected component containing that vertex. If v_num < 0,
*  no component numbers are stored.
*
*  The components are numbered in arbitrary order from 1 to nc, where
*  nc is the total number of components found, 0 <= nc <= |V|. However,
*  the component numbering has the property that for every arc (i->j)
*  in the graph the condition num(i) >= num(j) holds.
*
*  RETURNS
*
*  The routine returns nc, the total number of components found. */

int glp_strong_comp(glp_graph *G, int v_num)
{     glp_vertex *v;
      glp_arc *a;
      int i, k, last, n, na, nc, *icn, *ip, *lenr, *ior, *ib, *lowl,
         *numb, *prev;
      if (v_num >= 0 && v_num > G->v_size - (int)sizeof(int))
         xerror("glp_strong_comp: v_num = %d; invalid offset\n",
            v_num);
      n = G->nv;
      if (n == 0)
      {  nc = 0;
         goto done;
      }
      na = G->na;
      icn = xcalloc(1+na, sizeof(int));
      ip = xcalloc(1+n, sizeof(int));
      lenr = xcalloc(1+n, sizeof(int));
      ior = xcalloc(1+n, sizeof(int));
      ib = xcalloc(1+n, sizeof(int));
      lowl = xcalloc(1+n, sizeof(int));
      numb = xcalloc(1+n, sizeof(int));
      prev = xcalloc(1+n, sizeof(int));
      k = 1;
      for (i = 1; i <= n; i++)
      {  v = G->v[i];
         ip[i] = k;
         for (a = v->out; a != NULL; a = a->t_next)
            icn[k++] = a->head->i;
         lenr[i] = k - ip[i];
      }
      xassert(na == k-1);
      nc = mc13d(n, icn, ip, lenr, ior, ib, lowl, numb, prev);
      if (v_num >= 0)
      {  xassert(ib[1] == 1);
         for (k = 1; k <= nc; k++)
         {  last = (k < nc ? ib[k+1] : n+1);
            xassert(ib[k] < last);
            for (i = ib[k]; i < last; i++)
            {  v = G->v[ior[i]];
               memcpy((char *)v->data + v_num, &k, sizeof(int));
            }
         }
      }
      xfree(icn);
      xfree(ip);
      xfree(lenr);
      xfree(ior);
      xfree(ib);
      xfree(lowl);
      xfree(numb);
      xfree(prev);
done: return nc;
}

/* eof */
