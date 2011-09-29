/* glpapi17.c (basic graph and network routines) */

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

/* CAUTION: DO NOT CHANGE THE LIMITS BELOW */

#define NV_MAX 100000000 /* = 100*10^6 */
/* maximal number of vertices in the graph */

#define NA_MAX 500000000 /* = 500*10^6 */
/* maximal number of arcs in the graph */

/***********************************************************************
*  NAME
*
*  glp_create_graph - create graph
*
*  SYNOPSIS
*
*  glp_graph *glp_create_graph(int v_size, int a_size);
*
*  DESCRIPTION
*
*  The routine creates a new graph, which initially is empty, i.e. has
*  no vertices and arcs.
*
*  The parameter v_size specifies the size of data associated with each
*  vertex of the graph (0 to 256 bytes).
*
*  The parameter a_size specifies the size of data associated with each
*  arc of the graph (0 to 256 bytes).
*
*  RETURNS
*
*  The routine returns a pointer to the graph created. */

static void create_graph(glp_graph *G, int v_size, int a_size)
{     G->pool = dmp_create_pool();
      G->name = NULL;
      G->nv_max = 50;
      G->nv = G->na = 0;
      G->v = xcalloc(1+G->nv_max, sizeof(glp_vertex *));
      G->index = NULL;
      G->v_size = v_size;
      G->a_size = a_size;
      return;
}

glp_graph *glp_create_graph(int v_size, int a_size)
{     glp_graph *G;
      if (!(0 <= v_size && v_size <= 256))
         xerror("glp_create_graph: v_size = %d; invalid size of vertex "
            "data\n", v_size);
      if (!(0 <= a_size && a_size <= 256))
         xerror("glp_create_graph: a_size = %d; invalid size of arc dat"
            "a\n", a_size);
      G = xmalloc(sizeof(glp_graph));
      create_graph(G, v_size, a_size);
      return G;
}

/***********************************************************************
*  NAME
*
*  glp_set_graph_name - assign (change) graph name
*
*  SYNOPSIS
*
*  void glp_set_graph_name(glp_graph *G, const char *name);
*
*  DESCRIPTION
*
*  The routine glp_set_graph_name assigns a symbolic name specified by
*  the character string name (1 to 255 chars) to the graph.
*
*  If the parameter name is NULL or an empty string, the routine erases
*  the existing symbolic name of the graph. */

void glp_set_graph_name(glp_graph *G, const char *name)
{     if (G->name != NULL)
      {  dmp_free_atom(G->pool, G->name, strlen(G->name)+1);
         G->name = NULL;
      }
      if (!(name == NULL || name[0] == '\0'))
      {  int j;
         for (j = 0; name[j] != '\0'; j++)
         {  if (j == 256)
               xerror("glp_set_graph_name: graph name too long\n");
            if (iscntrl((unsigned char)name[j]))
               xerror("glp_set_graph_name: graph name contains invalid "
                  "character(s)\n");
         }
         G->name = dmp_get_atom(G->pool, strlen(name)+1);
         strcpy(G->name, name);
      }
      return;
}

/***********************************************************************
*  NAME
*
*  glp_add_vertices - add new vertices to graph
*
*  SYNOPSIS
*
*  int glp_add_vertices(glp_graph *G, int nadd);
*
*  DESCRIPTION
*
*  The routine glp_add_vertices adds nadd vertices to the specified
*  graph. New vertices are always added to the end of the vertex list,
*  so ordinal numbers of existing vertices remain unchanged.
*
*  Being added each new vertex is isolated (has no incident arcs).
*
*  RETURNS
*
*  The routine glp_add_vertices returns an ordinal number of the first
*  new vertex added to the graph. */

int glp_add_vertices(glp_graph *G, int nadd)
{     int i, nv_new;
      if (nadd < 1)
         xerror("glp_add_vertices: nadd = %d; invalid number of vertice"
            "s\n", nadd);
      if (nadd > NV_MAX - G->nv)
         xerror("glp_add_vertices: nadd = %d; too many vertices\n",
            nadd);
      /* determine new number of vertices */
      nv_new = G->nv + nadd;
      /* increase the room, if necessary */
      if (G->nv_max < nv_new)
      {  glp_vertex **save = G->v;
         while (G->nv_max < nv_new)
         {  G->nv_max += G->nv_max;
            xassert(G->nv_max > 0);
         }
         G->v = xcalloc(1+G->nv_max, sizeof(glp_vertex *));
         memcpy(&G->v[1], &save[1], G->nv * sizeof(glp_vertex *));
         xfree(save);
      }
      /* add new vertices to the end of the vertex list */
      for (i = G->nv+1; i <= nv_new; i++)
      {  glp_vertex *v;
         G->v[i] = v = dmp_get_atom(G->pool, sizeof(glp_vertex));
         v->i = i;
         v->name = NULL;
         v->entry = NULL;
         if (G->v_size == 0)
            v->data = NULL;
         else
         {  v->data = dmp_get_atom(G->pool, G->v_size);
            memset(v->data, 0, G->v_size);
         }
         v->temp = NULL;
         v->in = v->out = NULL;
      }
      /* set new number of vertices */
      G->nv = nv_new;
      /* return the ordinal number of the first vertex added */
      return nv_new - nadd + 1;
}

/***********************************************************************
*  NAME
*
*  glp_add_arc - add new arc to graph
*
*  SYNOPSIS
*
*  glp_arc *glp_add_arc(glp_graph *G, int i, int j);
*
*  DESCRIPTION
*
*  The routine glp_add_arc adds a new arc to the specified graph.
*
*  The parameters i and j specify the ordinal numbers of, resp., tail
*  and head vertices of the arc. Note that self-loops and multiple arcs
*  are allowed.
*
*  RETURNS
*
*  The routine glp_add_arc returns a pointer to the arc added. */

glp_arc *glp_add_arc(glp_graph *G, int i, int j)
{     glp_arc *a;
      if (!(1 <= i && i <= G->nv))
         xerror("glp_add_arc: i = %d; tail vertex number out of range\n"
            , i);
      if (!(1 <= j && j <= G->nv))
         xerror("glp_add_arc: j = %d; head vertex number out of range\n"
            , j);
      if (G->na == NA_MAX)
         xerror("glp_add_arc: too many arcs\n");
      a = dmp_get_atom(G->pool, sizeof(glp_arc));
      a->tail = G->v[i];
      a->head = G->v[j];
      if (G->a_size == 0)
         a->data = NULL;
      else
      {  a->data = dmp_get_atom(G->pool, G->a_size);
         memset(a->data, 0, G->a_size);
      }
      a->temp = NULL;
      a->t_prev = NULL;
      a->t_next = G->v[i]->out;
      if (a->t_next != NULL) a->t_next->t_prev = a;
      a->h_prev = NULL;
      a->h_next = G->v[j]->in;
      if (a->h_next != NULL) a->h_next->h_prev = a;
      G->v[i]->out = G->v[j]->in = a;
      G->na++;
      return a;
}

/***********************************************************************
*  NAME
*
*  glp_erase_graph - erase graph content
*
*  SYNOPSIS
*
*  void glp_erase_graph(glp_graph *G, int v_size, int a_size);
*
*  DESCRIPTION
*
*  The routine glp_erase_graph erases the content of the specified
*  graph. The effect of this operation is the same as if the graph
*  would be deleted with the routine glp_delete_graph and then created
*  anew with the routine glp_create_graph, with exception that the
*  handle (pointer) to the graph remains valid. */

static void delete_graph(glp_graph *G)
{     dmp_delete_pool(G->pool);
      xfree(G->v);
      if (G->index != NULL) avl_delete_tree(G->index);
      return;
}

void glp_erase_graph(glp_graph *G, int v_size, int a_size)
{     if (!(0 <= v_size && v_size <= 256))
         xerror("glp_erase_graph: v_size = %d; invalid size of vertex d"
            "ata\n", v_size);
      if (!(0 <= a_size && a_size <= 256))
         xerror("glp_erase_graph: a_size = %d; invalid size of arc data"
            "\n", a_size);
      delete_graph(G);
      create_graph(G, v_size, a_size);
      return;
}

/***********************************************************************
*  NAME
*
*  glp_delete_graph - delete graph
*
*  SYNOPSIS
*
*  void glp_delete_graph(glp_graph *G);
*
*  DESCRIPTION
*
*  The routine glp_delete_graph deletes the specified graph and frees
*  all the memory allocated to this program object. */

void glp_delete_graph(glp_graph *G)
{     delete_graph(G);
      xfree(G);
      return;
}

/***********************************************************************
*  NAME
*
*  glp_read_graph - read graph from plain text file
*
*  SYNOPSIS
*
*  int glp_read_graph(glp_graph *G, const char *fname);
*
*  DESCRIPTION
*
*  The routine glp_read_graph reads a graph from a plain text file.
*
*  RETURNS
*
*  If the operation was successful, the routine returns zero. Otherwise
*  it prints an error message and returns non-zero. */

int glp_read_graph(glp_graph *G, const char *fname)
{     _glp_data *data;
      jmp_buf jump;
      int nv, na, i, j, k, ret;
      glp_erase_graph(G, G->v_size, G->a_size);
      xprintf("Reading graph from `%s'...\n", fname);
      data = _glp_sds_open(fname);
      if (data == NULL)
      {  ret = 1;
         goto done;
      }
      if (setjmp(jump))
      {  ret = 1;
         goto done;
      }
      _glp_sds_jump(data, jump);
      nv = _glp_sds_int(data);
      if (nv < 0)
         _glp_sds_error(data, "invalid number of vertices\n");
      na = _glp_sds_int(data);
      if (na < 0)
         _glp_sds_error(data, "invalid number of arcs\n");
      xprintf("Graph has %d vert%s and %d arc%s\n",
         nv, nv == 1 ? "ex" : "ices", na, na == 1 ? "" : "s");
      if (nv > 0) glp_add_vertices(G, nv);
      for (k = 1; k <= na; k++)
      {  i = _glp_sds_int(data);
         if (!(1 <= i && i <= nv))
            _glp_sds_error(data, "tail vertex number out of range\n");
         j = _glp_sds_int(data);
         if (!(1 <= j && j <= nv))
            _glp_sds_error(data, "head vertex number out of range\n");
         glp_add_arc(G, i, j);
      }
      xprintf("%d lines were read\n", _glp_sds_line(data));
      ret = 0;
done: if (data != NULL) _glp_sds_close(data);
      return ret;
}

/***********************************************************************
*  NAME
*
*  glp_write_graph - write graph to plain text file
*
*  SYNOPSIS
*
*  int glp_write_graph(glp_graph *G, const char *fname).
*
*  DESCRIPTION
*
*  The routine glp_write_graph writes the specified graph to a plain
*  text file.
*
*  RETURNS
*
*  If the operation was successful, the routine returns zero. Otherwise
*  it prints an error message and returns non-zero. */

int glp_write_graph(glp_graph *G, const char *fname)
{     XFILE *fp;
      glp_vertex *v;
      glp_arc *a;
      int i, count, ret;
      xprintf("Writing graph to `%s'...\n", fname);
      fp = xfopen(fname, "w"), count = 0;
      if (fp == NULL)
      {  xprintf("Unable to create `%s' - %s\n", fname, xerrmsg());
         ret = 1;
         goto done;
      }
      xfprintf(fp, "%d %d\n", G->nv, G->na), count++;
      for (i = 1; i <= G->nv; i++)
      {  v = G->v[i];
         for (a = v->out; a != NULL; a = a->t_next)
            xfprintf(fp, "%d %d\n", a->tail->i, a->head->i), count++;
      }
      xfflush(fp);
      if (xferror(fp))
      {  xprintf("Write error on `%s' - %s\n", fname, xerrmsg());
         ret = 1;
         goto done;
      }
      xprintf("%d lines were written\n", count);
      ret = 0;
done: if (fp != NULL) xfclose(fp);
      return ret;
}

/* eof */
