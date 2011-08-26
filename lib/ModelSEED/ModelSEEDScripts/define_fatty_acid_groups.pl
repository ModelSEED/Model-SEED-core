use strict;
use Data::Dumper;
use ModelSEED::FBAMODEL;

my $fm = ModelSEED::FBAMODEL->new();
my ($groupObj, $ans);

print STDERR "Setting compound group for higher fatty acids\n";
# including cpd00049, which is just fatty acid
# including cpd11653, which is a duplicate
$groupObj = { 'grouping' => 'cpd00487', 'compounds' => ['cpd03847','cpd15298','cpd00214','cpd15237','cpd15269','cpd01080','cpd01741','cpd00049','cpd11653','cpd11430','cpd11438','cpd11436','cpd11440','cpd11433','cpd11431','cpd03846','cpd15240','cpd05235','cpd15270']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 6.2.1.20\n";
# left out rxn08021 and rxn08022 because they don't have correspondents in the following reactions
$groupObj = { 'grouping' => 'rxn05996', 'reactions' => [ 'rxn08014', 'rxn08015', 'rxn08016', 'rxn08017', 'rxn08018', 'rxn08019', 'rxn08020' ]}; 
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Acyl-ACP\n";
$groupObj = { 'grouping' => 'cpd11628', 'compounds' => ['cpd11466','cpd15294','cpd15277','cpd15239','cpd11825','cpd15268','cpd11468' ]};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.3.1.15\n";
$groupObj = { 'grouping' => 'rxn14401', 'reactions' => ['rxn08546','rxn08547','rxn08548','rxn08549','rxn08550','rxn08551','rxn08552']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 1-acyl-g3p\n";
$groupObj = { 'grouping' => 'cpd00517', 'compounds' => ['cpd15325','cpd15331','cpd15330','cpd15327','cpd15326','cpd15329','cpd15328','cpd15671','cpd15672','cpd15673','cpd15674','cpd15675','cpd15676']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.3.1.51\n";
$groupObj = { 'grouping' => 'rxn14402', 'reactions' => ['rxn08083','rxn08084','rxn08085','rxn08086','rxn08087','rxn08088','rxn08089']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 1,2-diacyl-g3p\n";
$groupObj = { 'grouping' => 'cpd11422', 'compounds' => ['cpd15521','cpd15522','cpd15523','cpd15524','cpd15525','cpd15526','cpd15527','cpd15677','cpd15678','cpd15679','cpd15680','cpd15681','cpd15682']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.7.7.41\n";
$groupObj = { 'grouping' => 'rxn06043', 'reactions' => [ 'rxn08306','rxn08307','rxn08308','rxn08309','rxn08310','rxn08311','rxn08312','rxn10220','rxn10221','rxn10222','rxn10223','rxn10224','rxn10225' ]};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for cdp-diacyl-g\n";
$groupObj = { 'grouping' => 'cpd11427', 'compounds' => ['cpd15417','cpd15423','cpd15422','cpd15419','cpd15418','cpd15421','cpd15420','cpd15683','cpd15684','cpd15685','cpd15686','cpd15687','cpd15688']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.7.8.5\n";
$groupObj = { 'grouping' => 'rxn06045', 'reactions' => ['rxn09108','rxn09109','rxn09110','rxn09111','rxn09112','rxn09113','rxn09114','rxn10259','rxn10260','rxn10261','rxn10262','rxn10263','rxn10264' ]};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for pgp\n";
$groupObj = { 'grouping' => 'cpd11454', 'compounds' => ['cpd15542','cpd15543','cpd15544','cpd15545','cpd15546','cpd15547','cpd15548','cpd15716','cpd15717','cpd15718','cpd15719','cpd15720','cpd15721']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 3.1.3.27\n";
$groupObj = { 'grouping' => 'rxn06080', 'reactions' => ['rxn09101','rxn09102','rxn09103','rxn09104','rxn09105','rxn09106','rxn09107','rxn10265','rxn10266','rxn10267','rxn10268','rxn10269','rxn10270' ]};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for pg\n";
$groupObj = { 'grouping' => 'cpd11652', 'compounds' => ['cpd15535','cpd15536','cpd15537','cpd15538','cpd15539','cpd15540','cpd15541','cpd15722','cpd15723','cpd15724','cpd15725','cpd15726','cpd15727']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for cardiolipin synthase\n";
$groupObj = { 'grouping' => 'rxn07267', 'reactions' => [ 'rxn08226','rxn08227','rxn08228','rxn08229','rxn08230','rxn08231','rxn08232','rxn10334','rxn10335','rxn10336','rxn10337','rxn10338','rxn10339','rxn10340','rxn10341','rxn10342' ]};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for cardiolipin\n";
$groupObj = { 'grouping' => 'cpd12801', 'compounds' => ['cpd15425','cpd15426','cpd15427','cpd15428','cpd15429','cpd15430','cpd15431','cpd15792','cpd15793','cpd15794','cpd15795','cpd15796','cpd15797','cpd15798','cpd15799']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 1-acyl-g3p-phosphoethanolamine\n";
# cpd12547 is mapped to KEGG C04438, but does not have an R group
$groupObj = { 'grouping' => 'cpd12547', 'compounds' => ['cpd15313','cpd15314','cpd15315','cpd15316','cpd15317','cpd12547']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1-acyl-gcp-phosphoethanolamine aldehydohydrolase\n";
$groupObj = { 'grouping' => 'rxn06375', 'reactions' => [ 'rxn08803','rxn08804','rxn08805','rxn08806','rxn08807','rxn08808','rxn08809']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 1-acyl-glycerophosphoglycerol\n";
# No abstract compound so use myristic acid version
$groupObj = { 'grouping' => 'cpd15319', 'compounds' => ['cpd15318','cpd15319','cpd15320','cpd15321','cpd15322','cpd15323','cpd15324']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1-acyl-glycerophosphoglycerol hydrolysis\n";
# No abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn08811', 'reactions' => [ 'rxn08810','rxn08811','rxn08812','rxn08813','rxn08814','rxn08815','rxn08816']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 2-acyl-g3p\n";
$groupObj = { 'grouping' => 'cpd12439', 'compounds' => ['cpd15350','cpd15363','cpd15362','cpd15355','cpd15354','cpd15358','cpd15357']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2-acyl-g3p hydrolysis\n";
# No abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn08818', 'reactions' => [ 'rxn08817','rxn08818','rxn08819','rxn08820','rxn08821','rxn08822','rxn08823']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 2-acyl-g3p-phosphoethanolamine\n";
$groupObj = { 'grouping' => 'cpd03557', 'compounds' => ['cpd15336','cpd15337','cpd15338','cpd15339','cpd15340','cpd15341','cpd15342']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2-acyl-gcp-phosphoethanolamine aldehydohydrolase\n";
$groupObj = { 'grouping' => 'rxn02450', 'reactions' => [ 'rxn08838','rxn08839','rxn08840','rxn08841','rxn08842','rxn08843','rxn08844']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 2-acyl-glycerophosphoglycerol\n";
# No abstract compound so use myristic acid version
$groupObj = { 'grouping' => 'cpd15344', 'compounds' => ['cpd15343','cpd15344','cpd15345','cpd15346','cpd15347','cpd15348','cpd15349']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2-acyl-glycerophosphoglycerol hydrolysis\n";
# No abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn08846', 'reactions' => [ 'rxn08845','rxn08846','rxn08847','rxn08848','rxn08849','rxn08850','rxn08851']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1,2-diacyl-glycerophosphate hydrolysis\n";
# No abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn09124', 'reactions' => [ 'rxn09123','rxn09124','rxn09125','rxn09126','rxn09127','rxn09128','rxn09129']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for phosphatidylethanolamine\n";
$groupObj = { 'grouping' => 'cpd11456', 'compounds' => ['cpd15528','cpd15529','cpd15530','cpd15531','cpd15532','cpd15533','cpd15534','cpd15695','cpd15696','cpd15697','cpd15698','cpd15699','cpd15700']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for phosphatidylethanolamine hydrolysis (3.1.1.32)\n";
$groupObj = { 'grouping' => 'rxn06089', 'reactions' => [ 'rxn09130','rxn09131','rxn09132','rxn09133','rxn09134','rxn09135','rxn09136']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1,2-diacyl-phosphoglycerolphosphate hydrolysis\n";
# use myristic acid version
$groupObj = { 'grouping' => 'rxn09138', 'reactions' => [ 'rxn09137','rxn09138','rxn09139','rxn09140','rxn09141','rxn09142','rxn09143']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Acyl-CoA\n";
$groupObj = { 'grouping' => 'cpd11611', 'compounds' => ['cpd00134','cpd01695','cpd00327','cpd11432','cpd11434','cpd11435','cpd11437','cpd11439','cpd11441','cpd15274','cpd15272','cpd15297','cpd15241','cpd01335']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.3.1.15 (Acyl-CoA)\n";
$groupObj = { 'grouping' => 'rxn05901', 'reactions' => ['rxn10202','rxn10203','rxn10204','rxn10205','rxn10206','rxn10207','rxn10208','rxn10209','rxn10210']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.3.1.51 (Acyl-CoA)\n";
$groupObj = { 'grouping' => 'rxn06140', 'reactions' => ['rxn10211','rxn10212','rxn10213','rxn10214','rxn10215','rxn10216','rxn10217','rxn10218','rxn10219']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 3.6.1.26\n";
$groupObj = { 'grouping' => 'rxn06041', 'reactions' => ['rxn08199','rxn08200','rxn08201','rxn08202','rxn08203','rxn08204','rxn08205']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Phosphatidylserine\n";
$groupObj = { 'grouping' => 'cpd11455', 'compounds' => ['cpd15552','cpd15553','cpd15555','cpd15555','cpd15556','cpd15557','cpd15558','cpd15689','cpd15690','cpd15691','cpd15692','cpd15593','cpd15594']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.7.8.8\n";
$groupObj = { 'grouping' => 'rxn06044', 'reactions' => ['rxn09205','rxn09206','rxn09207','rxn09208','rxn09209','rxn09210','rxn09211','rxn10226','rxn10227','rxn10228','rxn10229','rxn10230','rxn10231']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 4.1.1.65\n";
$groupObj = { 'grouping' => 'rxn06090', 'reactions' => ['rxn09197','rxn09198','rxn09199','rxn09200','rxn09201','rxn09202','rxn09203','rxn10232','rxn10233','rxn10234','rxn10235','rxn10236','rxn10237']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1,2-diacyl-g3p hydrolysis\n";
# no abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn09145', 'reactions' => ['rxn09144','rxn09145','rxn09146','rxn09147','rxn09148','rxn09149','rxn09150']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for phosphatidylethanolamine hydrolysis (3.1.1.4)\n";
$groupObj = { 'grouping' => 'rxn06088', 'reactions' => [ 'rxn09151','rxn09152','rxn09153','rxn09154','rxn09155','rxn09156','rxn09157']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for phosphatidylglycerol hydrolysis\n";
# no abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn09159', 'reactions' => ['rxn09158','rxn09159','rxn09160','rxn09161','rxn09162','rxn09163','rxn09164']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 1-acyl-g3p hydrolysis\n";
# No abstract reaction so use myristic acid version
$groupObj = { 'grouping' => 'rxn08797', 'reactions' => [ 'rxn08796','rxn08797','rxn08798','rxn08799','rxn08800','rxn08801','rxn08802']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.7.1.107\n";
$groupObj = { 'grouping' => 'rxn06139', 'reactions' => [ 'rxn08294','rxn08295','rxn08296','rxn08297','rxn08298','rxn08299','rxn08300','rxn10253','rxn10254','rxn10255','rxn10256','rxn10257','rxn10258']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 3.1.3.4\n";
$groupObj = { 'grouping' => 'rxn06138', 'reactions' => [ 'rxn09062','rxn09063','rxn09064','rxn09065','rxn09066','rxn09067','rxn09068','rxn10238','rxn10239','rxn10240','rxn10241','rxn10242','rxn10243']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for 1,2,diacyl-glycerol\n";
$groupObj = { 'grouping' => 'cpd11423', 'compounds' => ['cpd15306','cpd15307','cpd15308','cpd15309','cpd15310','cpd15311','cpd15312','cpd15701','cpd15702','cpd15703','cpd15704','cpd15705','cpd15706']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 6.2.1.3\n";
$groupObj = { 'grouping' => 'rxn05830', 'reactions' => [ 'rxn00947','rxn05247','rxn05248','rxn05249','rxn05250','rxn05251','rxn05252','rxn05736','rxn09444','rxn09445','rxn09446','rxn09447','rxn09448','rxn09449','rxn09450','rxn09451','rxn09452','rxn09453']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.4.1.52\n";
$groupObj = { 'grouping' => 'rxn06565', 'reactions' => [ 'rxn10298','rxn10299','rxn10300','rxn10301','rxn10302','rxn10303','rxn10304','rxn10305','rxn10306']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for (Glycerophosphate)n\n";
$groupObj = { 'grouping' => 'cpd12183', 'compounds' => ['cpd15746','cpd15747','cpd15748','cpd15749','cpd15750','cpd15751','cpd15752','cpd15753','cpd15754']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Glucosylpoly(Glycerophosphate)\n";
$groupObj = { 'grouping' => 'cpd12563', 'compounds' => ['cpd15755','cpd15756','cpd15757','cpd15758','cpd15759','cpd15760','cpd15761','cpd15762','cpd15763']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for 2.7.8.12\n";
# rxn06566 is messed up so map to stearoyl version
$groupObj = { 'grouping' => 'rxn10291', 'reactions' => [ 'rxn10289','rxn10290','rxn10291','rxn10292','rxn10293','rxn10294','rxn10295','rxn10296','rxn10297']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Diglucosyl-1,2-diacylglycerol\n";
$groupObj = { 'grouping' => 'cpd11428', 'compounds' => ['cpd15728','cpd15729','cpd15730','cpd15731','cpd15732','cpd15733','cpd15734','cpd15735','cpd15736']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for UDP-glucosyltransferase (diglucosyl)\n";
$groupObj = { 'grouping' => 'rxn12668', 'reactions' => [ 'rxn10271','rxn10272','rxn10273','rxn10274','rxn10275','rxn10276','rxn10277','rxn10278','rxn10279']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for Monoglucosyl-1,2-diacylglycerol\n";
$groupObj = { 'grouping' => 'cpd11450', 'compounds' => ['cpd15737','cpd15738','cpd15739','cpd15740','cpd15741','cpd15742','cpd15743','cpd15744','cpd15745']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for UDP-glucosyltransferase (monoglucosyl)\n";
$groupObj = { 'grouping' => 'rxn12667', 'reactions' => [ 'rxn10280','rxn10281','rxn10282','rxn10283','rxn10284','rxn10285','rxn10286','rxn10287','rxn10288']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for UDP-N-acetylglucosaminyl 1-phosphate transferase (2.7.8.-)\n";
# using stearoyl version as abstract reaction
$groupObj = { 'grouping' => 'rxn10309', 'reactions' => [ 'rxn10307','rxn10308','rxn10309','rxn10310','rxn10311','rxn10312','rxn10313','rxn10314','rxn10315']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for N-acetyl-D-glucosamine linked teichoic acid\n";
# using stearoyl version as abstract compound
$groupObj = { 'grouping' => 'cpd15766', 'compounds' => ['cpd15764','cpd15765','cpd15766','cpd15767','cpd15768','cpd15769','cpd15770','cpd15771','cpd15772']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting reaction group for polyglycerophosphate D-alaninee transfer\n";
# using stearoyl version as abstract reaction
$groupObj = { 'grouping' => 'rxn10318', 'reactions' => [ 'rxn10316','rxn10317','rxn10318','rxn10319','rxn10320','rxn10321','rxn10322','rxn10323','rxn10324']};
$ans = $fm->set_abstract_reaction_group({'group' => $groupObj});
print Dumper($ans);

print STDERR "Setting compound group for D-alanine linked teichoic acid\n";
# using stearoyl version as abstract compound
$groupObj = { 'grouping' => 'cpd15775', 'compounds' => ['cpd15773','cpd15774','cpd15775','cpd15776','cpd15777','cpd15778','cpd15779','cpd15780','cpd15781']};
$ans = $fm->set_abstract_compound_group({'group' => $groupObj});
print Dumper($ans);

