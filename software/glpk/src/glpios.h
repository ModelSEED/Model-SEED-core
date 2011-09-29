/* glpios.h (integer optimization suite) */

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

#ifndef GLPIOS_H
#define GLPIOS_H

#define GLP_TREE
typedef struct glp_tree glp_tree;

#include "glpapi.h"
#include "glpscg.h"

typedef struct IOSLOT IOSLOT;
typedef struct IOSNPD IOSNPD;
typedef struct IOSBND IOSBND;
typedef struct IOSTAT IOSTAT;
typedef struct IOSROW IOSROW;
typedef struct IOSAIJ IOSAIJ;
typedef struct IOSPOOL IOSPOOL;
typedef struct IOSCUT IOSCUT;
typedef struct IOSRIB IOSRIB;

struct glp_tree
{     /* branch-and-bound tree */
      DMP *pool;
      /* memory pool to store IOS components */
      int n;
      /* number of columns (variables) */
      /*--------------------------------------------------------------*/
      /* problem components corresponding to the original MIP and its
         LP relaxation (used to restore the original problem object on
         exit from the solver) */
      int orig_m;
      /* number of rows */
      int *orig_type; /* int orig_type[1+orig_m+n]; */
      /* types of all variables */
      double *orig_lb; /* double orig_lb[1+orig_m+n]; */
      /* lower bounds of all variables */
      double *orig_ub; /* double orig_ub[1+orig_m+n]; */
      /* upper bounds of all variables */
      int *orig_stat; /* int orig_stat[1+orig_m+n]; */
      /* statuses of all variables */
      double *orig_prim; /* double orig_prim[1+orig_m+n]; */
      /* primal values of all variables */
      double *orig_dual; /* double orig_dual[1+orig_m+n]; */
      /* dual values of all variables */
      double orig_obj;
      /* optimal objective value for LP relaxation */
      /*--------------------------------------------------------------*/
      /* branch-and-bound tree */
      int nslots;
      /* length of the array of slots (enlarged automatically) */
      int avail;
      /* index of the first free slot; 0 means all slots are in use */
      IOSLOT *slot; /* IOSLOT slot[1+nslots]; */
      /* array of slots:
         slot[0] is not used;
         slot[p], 1 <= p <= nslots, either contains a pointer to some
         node of the branch-and-bound tree, in which case p is used on
         API level as the reference number of corresponding subproblem,
         or is free; all free slots are linked into single linked list;
         slot[1] always contains a pointer to the root node (it is free
         only if the tree is empty) */
      IOSNPD *head;
      /* pointer to the head of the active list */
      IOSNPD *tail;
      /* pointer to the tail of the active list */
      /* the active list is a doubly linked list of active subproblems
         which correspond to leaves of the tree; all subproblems in the
         active list are ordered chronologically (each a new subproblem
         is always added to the tail of the list) */
      int a_cnt;
      /* current number of active nodes (including the current one) */
      int n_cnt;
      /* current number of all (active and inactive) nodes */
      int t_cnt;
      /* total number of nodes including those which have been already
         removed from the tree; this count is increased by one whenever
         a new node is created and never decreased */
      /*--------------------------------------------------------------*/
      /* problem components corresponding to the root subproblem */
      int root_m;
      /* number of rows */
      int *root_type; /* int root_type[1+root_m+n]; */
      /* types of all variables */
      double *root_lb; /* double root_lb[1+root_m+n]; */
      /* lower bounds of all variables */
      double *root_ub; /* double root_ub[1+root_m+n]; */
      /* upper bounds of all variables */
      int *root_stat; /* int root_stat[1+root_m+n]; */
      /* statuses of all variables */
      /*--------------------------------------------------------------*/
      /* current subproblem and its LP relaxation */
      IOSNPD *curr;
      /* pointer to the current subproblem (which can be only active);
         NULL means the current subproblem does not exist */
      glp_prob *mip;
      /* original problem object passed to the solver; if the current
         subproblem exists, its LP segment corresponds to LP relaxation
         of the current subproblem; if the current subproblem does not
         exist, its LP segment corresponds to LP relaxation of the root
         subproblem (note that the root subproblem may differ from the
         original MIP, because it may be preprocessed and/or may have
         additional rows) */
      int solved;
      /* this count shows how many times LP relaxation of the current
         subproblem is solved */
      int *non_int; /* int non_int[1+n]; */
      /* these column flags are set each time when LP relaxation of the
         current subproblem is solved;
         non_int[0] is not used;
         non_int[j], 1 <= j <= n, is j-th column flag; if this flag is
         set, corresponding variable is required to be integer, but its
         value in basic solution is fractional */
      /*--------------------------------------------------------------*/
      /* problem components corresponding to the parent (predecessor)
         subproblem for the current subproblem (used to inspect changes
         on freezing the current subproblem) */
      int pred_m;
      /* number of rows */
      int pred_max;
      /* length of the following four arrays (enlarged automatically),
         pred_max >= pred_m + n */
      int *pred_type; /* int pred_type[1+pred_m+n]; */
      /* types of all variables */
      double *pred_lb; /* double pred_lb[1+pred_m+n]; */
      /* lower bounds of all variables */
      double *pred_ub; /* double pred_ub[1+pred_m+n]; */
      /* upper bounds of all variables */
      int *pred_stat; /* int pred_stat[1+pred_m+n]; */
      /* statuses of all variables */
      /*--------------------------------------------------------------*/
      /* cut generator (under construction) */
      IOSPOOL *local;
      /* local cut pool */
      int first_attempt;
      int max_added_cuts;
      double min_eff;
      int miss;
      int just_selected;
      void *mir_gen;
      /* pointer to working area used by the MIR cut generator */
      void *clq_gen;
      /* pointer to working area used by the clique cut generator */
      int round;
      /* round number; shows how many times the cut generating routine
         is called for the same subproblem; 1 means call for the first
         time */
      /*--------------------------------------------------------------*/
      /* conflict graph for the current subproblem, or, if it does not
         exists, for the root subproblem */
      int *n_ref; /* int n_ref[1+n]; */
      /* n_ref[j], 1 <= j <= n, is the number of a node corresponding
         to binary variable x[j]; n_ref[j] = 0 means that the node is
         not assigned yet */
      int *c_ref; /* int c_ref[1+n]; */
      /* c_ref[j], 1 <= j <= n, is the number of a node corresponding
         to complemented binary variable x'[j]; c_ref[j] = 0 means that
         the node is not assigned yet */
      SCG *g;
      /* conflict graph for the current or root subproblem */
      int *j_ref; /* int j_ref[1+g->n_max]; */
      /* j_ref[k], 1 <= k <= g->n, is the number of a binary variable,
         which refers to node k, that is, j_ref[k] = j if n_ref[j] = k
         or c_ref[j] = k */
      /*--------------------------------------------------------------*/
      void *pcost;
      /* pointer to working area used on pseudocost branching */
      int *iwrk; /* int iwrk[1+n]; */
      /* working array */
      double *dwrk; /* double dwrk[1+n]; */
      /* working array */
      /*--------------------------------------------------------------*/
      /* control parameters and statistics */
      const glp_iocp *parm;
      /* copy of control parameters passed to the solver */
      xlong_t tm_beg;
      /* starting time of the search, in seconds; the total time of the
         search is the difference between xtime() and tm_beg */
      xlong_t tm_lag;
      /* the most recent time, in seconds, at which the progress of the
         the search was displayed */
      int sol_cnt;
      /* number of integer feasible solutions found */
      /*--------------------------------------------------------------*/
      /* advanced solver interface */
      int reason;
      /* flag indicating the reason why the callback routine is being
         called (see glpk.h) */
      int reopt;
      /* flag indicating that the current LP relaxation needs to be
         re-optimized */
      int br_var;
      /* the number of variable chosen to branch on */
      int br_sel;
      /* flag indicating which branch (subproblem) should be selected
         to continue the search:
         GLP_DN_BRNCH - select down-branch
         GLP_UP_BRNCH - select up-branch
         GLP_NO_BRNCH - use general selection technique */
      IOSNPD *btrack;
      /* pointer to active subproblem selected to continue the search;
         NULL means no subproblem has been selected */
      int terminate;
      /* flag indicating that the callback routine requires premature
         termination of the search */
};

struct IOSLOT
{     /* node subproblem slot */
      IOSNPD *node;
      /* pointer to subproblem descriptor; NULL means free slot */
      int next;
      /* index of another free slot (only if this slot is free) */
};

struct IOSNPD
{     /* node subproblem descriptor */
      int p;
      /* subproblem reference number (it is the index to corresponding
         slot, i.e. slot[p] points to this descriptor) */
      IOSNPD *up;
      /* pointer to the parent subproblem; NULL means this node is the
         root of the tree, in which case p = 1 */
      int level;
      /* node level (the root node has level 0) */
      int count;
      /* if count = 0, this subproblem is active; if count > 0, this
         subproblem is inactive, in which case count is the number of
         its child subproblems */
      IOSBND *b_ptr;
      /* linked list of rows and columns of the parent subproblem whose
         types and bounds were changed;
         this list is destroyed on reviving and built anew on freezing
         the subproblem */
      IOSTAT *s_ptr;
      /* linked list of rows and columns of the parent subproblem whose
         statuses were changed;
         this list is destroyed on reviving and built anew on freezing
         the subproblem */
      IOSROW *r_ptr;
      /* linked list of rows (cuts) added to the parent subproblem;
         this list is destroyed on reviving and built anew on freezing
         the subproblem */
      /*--------------------------------------------------------------*/
      /* changes in the conflict graph for this subproblem */
      int own_nn;
      /* number of nodes added for this subproblem */
      int own_nc;
      /* number of cliques added for this subproblem */
      IOSRIB *e_ptr;
      /* linked list of new edges added for this subproblem, where both
         endpoints were added in some ancestor subproblem */
      /*--------------------------------------------------------------*/
#if 1 /* 04/X-2008 */
      double lp_obj;
      /* optimal objective value to LP relaxation of this subproblem;
         on creating a subproblem this value is inherited from its
         parent; for the root subproblem, which has no parent, this
         value is initially set to -DBL_MAX (minimization) or +DBL_MAX
         (maximization); each time the subproblem is re-optimized, this
         value is appropriately changed */
#endif
      double bound;
      /* local lower (minimization) or upper (maximization) bound for
         integer optimal solution to *this* subproblem; this bound is
         local in the sense that only subproblems in the subtree rooted
         at this node cannot have better integer feasible solutions;
         on creating a subproblem its local bound is inherited from its
         parent and then can be made stronger (never weaker); for the
         root subproblem its local bound is initially set to -DBL_MAX
         (minimization) or +DBL_MAX (maximization) and then improved as
         the root LP relaxation has been solved */
#if 1 /* 04/X-2008 */
      int br_var;
      /* ordinal number of branching variable, 1 <= br_var <= n, used
         to split this subproblem; 0 means that either this subproblem
         is active or branching was made on a constraint */
      double br_val;
      /* (fractional) value of branching variable in optimal solution
         to final LP relaxation of this subproblem */
#endif
      /* if this subproblem is inactive, the following two quantities
         correspond to final optimal solution of its LP relaxation; for
         active subproblems these quantities are undefined */
      int ii_cnt;
      /* number of columns (structural variables) of integer kind whose
         primal values are fractional */
      double ii_sum;
      /* the sum of integer infeasibilities */
      void *data; /* char data[tree->cb_size]; */
      /* pointer to the application-specific data */
      IOSNPD *temp;
      /* auxiliary pointer used by some routines */
      IOSNPD *prev;
      /* pointer to previous subproblem in the active list */
      IOSNPD *next;
      /* pointer to next subproblem in the active list */
};

struct IOSBND
{     /* bounds change entry */
      int k;
      /* ordinal number of corresponding row (1 <= k <= m) or column
         (m+1 <= k <= m+n), where m and n are the number of rows and
         columns, resp., in the parent subproblem */
      int type;
      /* new type */
      double lb;
      /* new lower bound */
      double ub;
      /* new upper bound */
      IOSBND *next;
      /* pointer to next entry for the same subproblem */
};

struct IOSTAT
{     /* status change entry */
      int k;
      /* ordinal number of corresponding row (1 <= k <= m) or column
         (m+1 <= k <= m+n), where m and n are the number of rows and
         columns, resp., in the parent subproblem */
      int stat;
      /* new status */
      IOSTAT *next;
      /* pointer to next entry for the same subproblem */
};

struct IOSROW
{     /* row (cut) addition entry */
      char *name;
      /* row name or NULL */
#if 1 /* 20/IX-2008 */
      unsigned char origin;
      unsigned char klass;
#endif
      int type;
      /* row type */
      double lb;
      /* row lower bound */
      double ub;
      /* row upper bound */
      IOSAIJ *ptr;
      /* pointer to the coefficient list */
      double rii;
      /* row scale factor */
      int stat;
      /* row status */
      IOSROW *next;
      /* pointer to next entry for the same subproblem */
};

struct IOSAIJ
{     /* constraint coefficient */
      int j;
      /* column number */
      double val;
      /* coefficient value */
      IOSAIJ *next;
      /* pointer to next coefficient for the same row */
};

struct IOSPOOL
{     /* cut pool */
      int size;
      /* pool size = number of cuts in the pool */
      IOSCUT *head;
      /* pointer to the first cut row */
      IOSCUT *tail;
      /* pointer to the last cut row */
      int ord;
      /* ordinal number of the current cut row, 1 <= ord <= size */
      IOSCUT *curr;
      /* pointer to the current cut row */
};

struct IOSCUT
{     /* cut row (cutting plane constraint) */
#if 1 /* 20/IX-2008 */
      char *name;
      unsigned char klass;
#endif
      IOSAIJ *ptr;
      /* pointer to the list of row coefficients */
      int type;
      /* row type:
         GLP_LO: sum a[j] * x[j] >= b
         GLP_UP: sum a[j] * x[j] <= b
         GLP_FX: sum a[j] * x[j]  = b */
      double rhs;
      /* row right-hand side */
      IOSCUT *prev;
      /* pointer to the previous cut row */
      IOSCUT *next;
      /* pointer to the next cut row */
};

struct IOSRIB
{     /* conflict edge addition entry */
      int j1;
      /* first variable number (j1 < 0 means complement) */
      int j2;
      /* second variable number (j2 < 0 means complement) */
      SCGRIB *e;
      /* pointer to the edge descriptor (NULL means the edge is missing
         in the current graph) */
      IOSRIB *next;
      /* pointer to next entry for the same subproblem */
};

#define ios_create_tree _glp_ios_create_tree
glp_tree *ios_create_tree(glp_prob *mip, const glp_iocp *parm);
/* create branch-and-bound tree */

#define ios_revive_node _glp_ios_revive_node
void ios_revive_node(glp_tree *tree, int p);
/* revive specified subproblem */

#define ios_freeze_node _glp_ios_freeze_node
void ios_freeze_node(glp_tree *tree);
/* freeze current subproblem */

#define ios_clone_node _glp_ios_clone_node
void ios_clone_node(glp_tree *tree, int p, int nnn, int ref[]);
/* clone specified subproblem */

#define ios_delete_node _glp_ios_delete_node
void ios_delete_node(glp_tree *tree, int p);
/* delete specified subproblem */

#define ios_delete_tree _glp_ios_delete_tree
void ios_delete_tree(glp_tree *tree);
/* delete branch-and-bound tree */

#define ios_eval_degrad _glp_ios_eval_degrad
void ios_eval_degrad(glp_tree *tree, int j, double *dn, double *up);
/* estimate obj. degrad. for down- and up-branches */

#define ios_round_bound _glp_ios_round_bound
double ios_round_bound(glp_tree *tree, double bound);
/* improve local bound by rounding */

#define ios_is_hopeful _glp_ios_is_hopeful
int ios_is_hopeful(glp_tree *tree, double bound);
/* check if subproblem is hopeful */

#define ios_best_node _glp_ios_best_node
int ios_best_node(glp_tree *tree);
/* find active node with best local bound */

#define ios_relative_gap _glp_ios_relative_gap
double ios_relative_gap(glp_tree *tree);
/* compute relative mip gap */

#define ios_solve_node _glp_ios_solve_node
int ios_solve_node(glp_tree *tree);
/* solve LP relaxation of current subproblem */

#define ios_create_pool _glp_ios_create_pool
IOSPOOL *ios_create_pool(glp_tree *tree);
/* create cut pool */

#define ios_add_row _glp_ios_add_row
int ios_add_row(glp_tree *tree, IOSPOOL *pool,
      const char *name, int klass, int flags, int len, const int ind[],
      const double val[], int type, double rhs);
/* add row (constraint) to the cut pool */

#define ios_find_row _glp_ios_find_row
IOSCUT *ios_find_row(IOSPOOL *pool, int i);
/* find row (constraint) in the cut pool */

#define ios_del_row _glp_ios_del_row
void ios_del_row(glp_tree *tree, IOSPOOL *pool, int i);
/* remove row (constraint) from the cut pool */

#define ios_clear_pool _glp_ios_clear_pool
void ios_clear_pool(glp_tree *tree, IOSPOOL *pool);
/* remove all rows (constraints) from the cut pool */

#define ios_delete_pool _glp_ios_delete_pool
void ios_delete_pool(glp_tree *tree, IOSPOOL *pool);
/* delete cut pool */

#define ios_add_edge _glp_ios_add_edge
void ios_add_edge(glp_tree *tree, int j1, int j2);
/* add new edge to the conflict graph */

#define ios_preprocess_node _glp_ios_preprocess_node
int ios_preprocess_node(glp_tree *tree, int max_pass);
/* preprocess current subproblem */

#define ios_driver _glp_ios_driver
int ios_driver(glp_tree *tree);
/* branch-and-bound driver */

/**********************************************************************/

typedef struct IOSVEC IOSVEC;

struct IOSVEC
{     /* sparse vector v = (v[j]) */
      int n;
      /* dimension, n >= 0 */
      int nnz;
      /* number of non-zero components, 0 <= nnz <= n */
      int *pos; /* int pos[1+n]; */
      /* pos[j] = k, 1 <= j <= n, is position of (non-zero) v[j] in the
         arrays ind and val, where 1 <= k <= nnz; pos[j] = 0 means that
         v[j] is structural zero */
      int *ind; /* int ind[1+n]; */
      /* ind[k] = j, 1 <= k <= nnz, is index of v[j] */
      double *val; /* double val[1+n]; */
      /* val[k], 1 <= k <= nnz, is a numeric value of v[j] */
};

#define ios_create_vec _glp_ios_create_vec
IOSVEC *ios_create_vec(int n);
/* create sparse vector */

#define ios_check_vec _glp_ios_check_vec
void ios_check_vec(IOSVEC *v);
/* check that sparse vector has correct representation */

#define ios_get_vj _glp_ios_get_vj
double ios_get_vj(IOSVEC *v, int j);
/* retrieve component of sparse vector */

#define ios_set_vj _glp_ios_set_vj
void ios_set_vj(IOSVEC *v, int j, double val);
/* set/change component of sparse vector */

#define ios_clear_vec _glp_ios_clear_vec
void ios_clear_vec(IOSVEC *v);
/* set all components of sparse vector to zero */

#define ios_clean_vec _glp_ios_clean_vec
void ios_clean_vec(IOSVEC *v, double eps);
/* remove zero or small components from sparse vector */

#define ios_copy_vec _glp_ios_copy_vec
void ios_copy_vec(IOSVEC *x, IOSVEC *y);
/* copy sparse vector (x := y) */

#define ios_linear_comb _glp_ios_linear_comb
void ios_linear_comb(IOSVEC *x, double a, IOSVEC *y);
/* compute linear combination (x := x + a * y) */

#define ios_delete_vec _glp_ios_delete_vec
void ios_delete_vec(IOSVEC *v);
/* delete sparse vector */

/**********************************************************************/

#define ios_gmi_gen _glp_ios_gmi_gen
void ios_gmi_gen(glp_tree *tree);
/* generate Gomory's mixed integer cuts */

#define ios_mir_init _glp_ios_mir_init
void *ios_mir_init(glp_tree *tree);
/* initialize MIR cut generator */

#define ios_mir_gen _glp_ios_mir_gen
void ios_mir_gen(glp_tree *tree, void *gen);
/* generate MIR cuts */

#define ios_mir_term _glp_ios_mir_term
void ios_mir_term(void *gen);
/* terminate MIR cut generator */

#define ios_cov_gen _glp_ios_cov_gen
void ios_cov_gen(glp_tree *tree);
/* generate mixed cover cuts */

#define ios_clq_init _glp_ios_clq_init
void *ios_clq_init(glp_tree *tree);
/* initialize clique cut generator */

#define ios_clq_gen _glp_ios_clq_gen
void ios_clq_gen(glp_tree *tree, void *gen);
/* generate clique cuts */

#define ios_clq_term _glp_ios_clq_term
void ios_clq_term(void *gen);
/* terminate clique cut generator */

#define ios_pcost_branch _glp_ios_pcost_branch
void ios_pcost_branch(glp_tree *tree);
/* choose branching variable using hybrid pseudocost technique */

#define ios_pcost_free _glp_ios_pcost_free
void ios_pcost_free(glp_tree *tree);
/* free working area used on pseudocost branching */

#define ios_feas_pump _glp_ios_feas_pump
void ios_feas_pump(glp_tree *T);
/* feasibility pump heuristic */

#endif

/* eof */
