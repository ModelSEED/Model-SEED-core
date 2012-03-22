#===============================================================================
#
#         FILE: Biochemistry.t
#
#  DESCRIPTION: Tests for Biochemistry import factory
#               that imports Biochemistries from PPO / files
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 03/21/2012 15:24:54
#     REVISION: ---
#===============================================================================
use strict;
use warnings;
use ModelSEED::MS::Factories::Biochemistry;
use ModelSEED::MS::Compound;
use ModelSEED::TestingHelpers;
use Data::Dumper;
use File::Temp qw(tempfile);
use Test::More;

my $testCount = 0;

{
    my $bio = ModelSEED::MS::Biochemistry->new();
    my $fact = ModelSEED::MS::Factories::Biochemistry->new();
    my $config = {
        array         => [],
        delimiter     => "\t",
        itemDelimiter => ";",
        filename => (tempfile())[1],
    };
    # Testing conversion of comaprtments
    my $compartmentTableText = <<QXQ;
id	name	outside
c	Cytosol	p/e
p	Periplasm	e
g	Golgi apparatus	c
e	Extracellular	NONE
r	Endoplasmic reticulum	c
l	Lysosome	c
n	Nucleus	c
h	Chloroplast	c
m	Mitochondria	c
x	Peroxisome	c
v	Vacuole	c
d	Plastid	c
w	Cell wall	e
QXQ
    $config->{array} = [split(/\n/, $compartmentTableText)];
    my $compartmentTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table_from_array($config);
    for (my $i = 0; $i < $compartmentTable->size(); $i++) {
        my $row = $compartmentTable->get_row($i);
        my $dat = $fact->convert("compartment", $row, $bio);
        my $obj = ModelSEED::MS::Compartment->new($dat);
        $bio->add("Compartment", $obj);
        ok defined($obj), "Should create object for " . Dumper $dat;
        $testCount += 1;
    }
    # Testing conversion of compounds
    my $compoundTableText = <<QXQ;
abbrev	abstractCompound	charge	creationDate	deltaG	deltaGErr	formula	id	mass	modificationDate	name	owner	pKa	pKb	public	scope	stringcode	structuralCues
h2o		0	1280902170	-56.687	0.5	H2O	cpd00001	18	1280902170	H2O	master	15.70:1	-1.80:1	1		OH2	H2O:1
atp		-3	1280902170	-673.85	3.04314	C10H13N5O13P3	cpd00002	504	1280902170	ATP	master	0.84:26;1.83:29;2.95:22;7.72:30;13.03:14	3.97:15;-3.48:6;-3.66:14;-9.18:9	1		CH(CH(OHCH(OHCH(CH2(O(P(OHO(P(OHO(P(OHOHO))O))O)))O{1})))N(CH(N(C(C(N(CH(N(C(NH2){7})))){10})<7>)))<10>)<1>	RWWNW:1;TWWCdblW:2;RWCHWW:4;RWCHdblW:2;RWdblNW:3;RWOW:1;RWCdblWW:1;PrimOH:2;WNH2:1;WCH2W:1;mid_phos:2;prim_phos:1;Origin:1;HeteroAromatic:2
nad		-1	1280902170	-529.59	4.35693	C21H26N7O14P2	cpd00003	662	1280902170	NAD	master	1.80:17;2.56:18;11.56:25;12.32:6;13.12:35	3.94:41;-1.17:25;-3.48:37;-3.66:35;-3.98:6;-9.18:43	1		CH2(CH(CH(OHCH(OHCH(N(CH(N(C(C(N(CH(N(C(NH2){17})))){21})<17>)))<21>O{3}))))<3>O(P(OHOO(P(OHOO(CH2(CH(CH(OHCH(OHCH(N[+1](CH(CH(CH(C(C(ONH2)CH{25})))))<25>O{4}))))<4>)))))))	RWCHWW:8;RWOW:2;PrimOH:4;WCH2W:2;WRdNWRW:1;WPO4nW:1;mid_phos:1;RWCHdblW:6;RWCdblWW:2;WketoneW:1;RWWNW:1;RWdblNW:3;TWWCdblW:2;WNH2:2;amide:1;Origin:1;OCCC:1;HeteroAromatic:3
nadh		-2	1280902170	-524.32	4.26795	C21H27N7O14P2	cpd00004	663	1280902170	NADH	master	1.80:22;2.56:26;12.69:36;13.31:14;14.30:18	3.94:15;-3.48:9;-3.51:18;-3.60:36;-3.66:14;-9.18:6	1		CH2(CH(CH(OHCH(OHCH(N(CH(N(C(C(N(CH(N(C(NH2){17})))){21})<17>)))<21>O{4}))))<4>O(P(OHOO(P(OHOO(CH2(CH(CH(OHCH(OHCH(N(CH(CH(CH2(C(C(ONH2)CH{22})))))<22>O{5}))))<5>)))))))	RWWNW:2;TWWCdblW:2;RWCHWW:8;RWCHdblW:5;RWdblNW:3;RWOW:2;RWCdblWW:2;PrimOH:4;WNH2:2;WCH2W:2;WPO4nW:1;mid_phos:1;RWCH2W:1;WketoneW:1;amide:1;Origin:1;OCCC:1;HeteroAromatic:2
nadph		-3	1280902170	-736.82	4.25788	C21H27N7O17P3	cpd00005	742	1280902170	NADPH	master	1.45:26;2.00:18;2.61:30;6.71:19;13.16:40	3.94:22;-3.48:12;-3.60:40;-9.18:11	1		CH2(CH(CH(OHCH(O(P(OHOHO))CH(N(CH(N(C(C(N(CH(N(C(NH2){17})))){21})<17>)))<21>O{4}))))<4>O(P(OHOO(P(OHOO(CH2(CH(CH(OHCH(OHCH(N(CH(CH(CH2(C(C(ONH2)CH{22})))))<22>O{5}))))<5>)))))))	RWCHWW:8;RWWNW:2;RWOW:2;TWWCdblW:2;RWCHdblW:5;prim_phos:1;RWdblNW:3;PrimOH:3;WCH2W:2;RWCdblWW:2;WPO4nW:1;WNH2:2;mid_phos:1;RWCH2W:1;WketoneW:1;amide:1;Origin:1;OCCC:1;HeteroAromatic:2
nadp		-2	1280902170	-742.09	4.34706	C21H26N7O17P3	cpd00006	741	1280902170	NADP	master	1.45:30;2.00:19;2.61:26;6.71:18;11.66:47	3.94:22;-1.17:47;-3.48:12;-9.18:11	1		CH2(CH(CH(OHCH(O(P(OHOHO))CH(N(CH(N(C(C(N(CH(N(C(NH2){17})))){21})<17>)))<21>O{3}))))<3>O(P(OHOO(P(OHOO(CH2(CH(CH(OHCH(OHCH(N[+1](CH(CH(CH(C(C(ONH2)CH{25})))))<25>O{4}))))<4>)))))))	RWCHWW:8;RWWNW:1;RWOW:2;TWWCdblW:2;RWCHdblW:6;prim_phos:1;RWdblNW:3;PrimOH:3;WCH2W:2;RWCdblWW:2;WPO4nW:1;WNH2:2;mid_phos:1;WRdNWRW:1;WketoneW:1;amide:1;Origin:1;OCCC:1;HeteroAromatic:3
o2		0	1280902170	3.9197	0.5	O2	cpd00007	32	1280902170	O2	master			1		(OO)	O2:1
adp		-2	1280902170	-465.85	3.03579	C10H13N5O10P2	cpd00008	425	1280902170	ADP	master	1.72:25;2.50:22;7.12:26;12.87:14;14.27:18	3.94:15;-3.48:9;-3.51:18;-3.66:14;-9.18:6	1		CH(CH(OHCH(OHCH(CH2(O(P(OHO(P(OHOHO))O)))O{1})))N(CH(N(C(C(N(CH(N(C(NH2){7})))){10})<7>)))<10>)<1>	RWWNW:1;TWWCdblW:2;RWCHWW:4;RWCHdblW:2;RWdblNW:3;RWOW:1;RWCdblWW:1;PrimOH:2;WNH2:1;WCH2W:1;mid_phos:1;prim_phos:1;Origin:1;HeteroAromatic:2
pi		-2	1280902171	-261.974	0.5	HO4P	cpd00009	96	1280902171	Phosphate	master	1.80:3;6.95:2;12.90:4		1		P(OHOHOHO)	orthophosphate:1
QXQ
    $config->{array} = [split(/\n/, $compoundTableText)];
    my $compoundTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table_from_array($config);
    for (my $i = 0; $i < $compoundTable->size(); $i++) {
        my $row = $compoundTable->get_row($i);
        my $dat = $fact->convert("compound", $row, $bio);
        my $obj = ModelSEED::MS::Compound->new($dat);
        ok defined($obj), "Should create object for " . Dumper $dat;
        $testCount += 1;
    }
    # Testing the conversion of compound aliases
    my $cpdalsText = <<XQX;
COMPOUND	alias	type
cpd00001	oh-	searchname
cpd00001	OH-	name
cpd00001	ho-	searchname
cpd00001	HO-	name
cpd00001	water	searchname
cpd00001	Water	name
cpd00001	h2o	searchname
cpd00001	H2O	name
cpd00001	WATER	iAbaylyiv4
cpd00001	h2o	iAF1260
cpd00001	h2o	iAF692
cpd00001	cbs_1	iAG612
cpd00001	cbs_152	iAG612
cpd00001	cll_9	iAO358
cpd00001	h2o	iIN800
cpd00001	h2o	iIT341
cpd00001	h2o	iJN746
cpd00001	h2o	iJR904
cpd00001	h2o	iMEO21
cpd00001	h2o	iMM904
cpd00001	h2o	iND750
cpd00001	h2o	iNJ661
cpd00001	h2o	iPS189
cpd00001	h2o	iSB619
cpd00001	h2o	iSO783
cpd00001	h2o	iYO844
cpd00001	C00001	KEGG
cpd00001	cpd00969	obsolete
cpd00001	h2o	iMO1056
cpd00001	h2o	iGT196
cpd00001	C01328	KEGG
cpd00001	h2o	iMO1053-PAO1
cpd00001	h2o	iJR904.45632
cpd00001	C00001	iRS1563.45632
cpd00001	H20	nameMaizeCyc.45632
cpd00001	h20	searchnameMaizeCyc.45632
cpd00001	WATER	MaizeCyc.45632
cpd00002	adenosine5triphosphate	searchname
cpd00002	Adenosine 5'-triphosphate	name
cpd00002	atp	searchname
cpd00002	ATP	name
cpd00002	ATP	iAbaylyiv4
cpd00002	atp	iAF1260
cpd00002	atp	iAF692
cpd00002	cbs_274	iAG612
cpd00002	cbs_42	iAG612
cpd00002	cll_0	iAO358
cpd00002	atp	iIN800
cpd00002	atp	iIT341
cpd00002	atp	iJN746
cpd00002	atp	iJR904
cpd00002	atp	iMEO21
cpd00002	atp	iMM904
cpd00002	atp	iND750
cpd00002	atp	iNJ661
cpd00002	atp	iPS189
cpd00002	atp	iSB619
cpd00002	atp	iSO783
cpd00002	atp	iYO844
cpd00002	C00002	KEGG
cpd00002	atp	iMO1056
cpd00002	atp	iGT196
cpd00002	atp	iMO1053-PAO1
cpd00002	atp	iJR904.45632
cpd00002	C00002	iRS1563.45632
cpd00003	Nicotinamideadeninedinucleotide	name
cpd00003	nadide	searchname
cpd00003	Nadide	name
cpd00003	diphosphopyridinenucleotide	searchname
cpd00003	Diphosphopyridine nucleotide	name
cpd00003	dpn	searchname
cpd00003	DPN	name
cpd00003	nicotinamideadeninedinucleotide	searchname
cpd00003	Nicotinamide adenine dinucleotide	name
cpd00003	nad	searchname
cpd00003	NAD	name
cpd00003	nad+	searchname
cpd00003	NAD+	name
cpd00003	NAD	iAbaylyiv4
cpd00003	nad	iAF1260
cpd00003	nad	iAF692
cpd00003	cbs_61	iAG612
cpd00003	cbs_35	iAG612
cpd00003	cbs_150	iAG612
cpd00003	cll_22	iAO358
cpd00003	nad+	iIN800
cpd00003	nad	iIT341
cpd00003	nad	iJN746
cpd00003	nad	iJR904
cpd00003	nad	iMEO21
cpd00003	nad	iMM904
cpd00003	nad	iND750
cpd00003	nad	iNJ661
cpd00003	nad	iPS189
cpd00003	nad	iSB619
cpd00003	nad	iSO783
cpd00003	nad	iYO844
cpd00003	C00003	KEGG
cpd00003	nad	iMO1056
cpd00003	nad	iGT196
cpd00003	nad	iMO1053-PAO1
cpd00003	nad	iJR904.45632
cpd00003	C00003	iRS1563.45632
cpd00003	S_NAD+_p	AraGEM.45632
cpd00001	oh-	searchname
cpd00001	OH-	name
cpd00001	ho-	searchname
cpd00001	HO-	name
cpd00001	water	searchname
cpd00001	Water	name
cpd00001	h2o	searchname
cpd00001	H2O	name
cpd00001	WATER	iAbaylyiv4
cpd00001	h2o	iAF1260
cpd00001	h2o	iAF692
cpd00001	cbs_1	iAG612
cpd00001	cbs_152	iAG612
cpd00001	cll_9	iAO358
cpd00001	h2o	iIN800
cpd00001	h2o	iIT341
cpd00001	h2o	iJN746
cpd00001	h2o	iJR904
cpd00001	h2o	iMEO21
cpd00001	h2o	iMM904
cpd00001	h2o	iND750
cpd00001	h2o	iNJ661
cpd00001	h2o	iPS189
cpd00001	h2o	iSB619
cpd00001	h2o	iSO783
cpd00001	h2o	iYO844
cpd00001	C00001	KEGG
cpd00001	cpd00969	obsolete
cpd00001	h2o	iMO1056
cpd00001	h2o	iGT196
cpd00001	C01328	KEGG
cpd00001	h2o	iMO1053-PAO1
cpd00001	h2o	iJR904.45632
cpd00001	C00001	iRS1563.45632
cpd00001	H20	nameMaizeCyc.45632
cpd00001	h20	searchnameMaizeCyc.45632
cpd00001	WATER	MaizeCyc.45632
cpd00002	adenosine5triphosphate	searchname
cpd00002	Adenosine 5'-triphosphate	name
cpd00002	atp	searchname
cpd00002	ATP	name
cpd00002	ATP	iAbaylyiv4
cpd00002	atp	iAF1260
cpd00002	atp	iAF692
cpd00002	cbs_274	iAG612
cpd00002	cbs_42	iAG612
cpd00002	cll_0	iAO358
cpd00002	atp	iIN800
cpd00002	atp	iIT341
cpd00002	atp	iJN746
cpd00002	atp	iJR904
cpd00002	atp	iMEO21
cpd00002	atp	iMM904
cpd00002	atp	iND750
cpd00002	atp	iNJ661
cpd00002	atp	iPS189
cpd00002	atp	iSB619
cpd00002	atp	iSO783
cpd00002	atp	iYO844
cpd00002	C00002	KEGG
cpd00002	atp	iMO1056
cpd00002	atp	iGT196
cpd00002	atp	iMO1053-PAO1
cpd00002	atp	iJR904.45632
cpd00002	C00002	iRS1563.45632
cpd00003	Nicotinamideadeninedinucleotide	name
cpd00003	nadide	searchname
cpd00003	Nadide	name
cpd00003	diphosphopyridinenucleotide	searchname
cpd00003	Diphosphopyridine nucleotide	name
cpd00003	dpn	searchname
cpd00003	DPN	name
cpd00003	nicotinamideadeninedinucleotide	searchname
cpd00003	Nicotinamide adenine dinucleotide	name
cpd00003	nad	searchname
cpd00003	NAD	name
cpd00003	nad+	searchname
cpd00003	NAD+	name
cpd00003	NAD	iAbaylyiv4
cpd00003	nad	iAF1260
cpd00003	nad	iAF692
cpd00003	cbs_61	iAG612
cpd00003	cbs_35	iAG612
cpd00003	cbs_150	iAG612
cpd00003	cll_22	iAO358
cpd00003	nad+	iIN800
cpd00003	nad	iIT341
cpd00003	nad	iJN746
cpd00003	nad	iJR904
cpd00003	nad	iMEO21
cpd00003	nad	iMM904
cpd00003	nad	iND750
cpd00003	nad	iNJ661
cpd00003	nad	iPS189
cpd00003	nad	iSB619
cpd00003	nad	iSO783
cpd00003	nad	iYO844
cpd00003	C00003	KEGG
cpd00003	nad	iMO1056
cpd00003	nad	iGT196
cpd00003	nad	iMO1053-PAO1
cpd00003	nad	iJR904.45632
cpd00003	C00003	iRS1563.45632
cpd00003	S_NAD+_p	AraGEM.45632
XQX
    my $cpdalsTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table_from_array($config);
    for (my $i = 0; $i < $cpdalsTable->size(); $i++) {
        my $row = $cpdalsTable->get_row($i);
    }
}


done_testing($testCount);

