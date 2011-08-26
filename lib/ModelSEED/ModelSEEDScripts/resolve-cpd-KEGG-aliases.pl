#!/usr/bin/perl 
use strict;
use warnings;
use ModelSEED::FIGMODEL;
use Data::Dumper;
use File::stat;
use Time::localtime;
use Digest::MD5;

my $DEBUG = 0;
my $FINAL = 0;
my $SCOPE_VARIABLE = "KEGGimport";

if(@ARGV) {
    if($ARGV[0] eq "-v") {
        $DEBUG = 1;
    } elsif ($ARGV[0] eq "-f") {
        $FINAL = 1;
    }
}
    
   

my $figmodel = ModelSEED::FIGMODEL->new();
my $importDir = "/vol/seed-anno-mirror/FIG/Data/KEGG/";

sub addNameToLookupTables {
    my ($id, $name, $NameToIdsHash, $IdToNamesHash) = @_;
    my @searchNames = $figmodel->convert_to_search_name($name);
    foreach my $searchName (@searchNames) {
        $NameToIdsHash->{$searchName} = [] unless(defined($NameToIdsHash->{$searchName}));
        $IdToNamesHash->{$id} = [] unless(defined($IdToNamesHash->{$id}));
        push(@{$NameToIdsHash->{$searchName}}, $id);
        push(@{$IdToNamesHash->{$id}}, $searchName);
    }
    return ($NameToIdsHash, $IdToNamesHash);
}

sub compareLists {
    my ($a, $b) = @_;
    my ($ah, $bh) = {};
    foreach my $aa (@$a) {
        $ah->{$aa} = 1;
    }
    foreach my $bb (@$b) {
        $bh->{$bb} = 1;
    }
    my ($Ah, $ABh, $Bh) = compareHashes($ah, $bh);
    # Get all the keys (list entries) that have defined values 
    my @A  = grep { defined($Ah->{$_}) } keys %$Ah;
    my @AB = grep { defined($ABh->{$_}) } keys %$ABh;
    my @B  = grep { defined($Bh->{$_}) } keys %$Bh;
    return (\@A, \@AB, \@B);
}

sub compare {
    my ($a, $b) = @_;
    if ((not defined($a)) || (not defined($b))) {
        return ($a, undef, $b);
    }
    if (ref($a) && ref($b)) {
        if(ref($a) eq 'HASH' && ref($b) eq 'HASH') {
            return compareHashes($a, $b);
        } elsif(ref($a) eq 'ARRAY' && ref($b) eq 'ARRAY') {
            return compareLists($a, $b);
        } else {
            return ($a, undef, $b);
        }
    } else {
        if ($a eq $b) {
            return (undef, $a, undef);
        } else {
            return ($a, undef, $b);
        }
    }
}
        
sub compareHashes {
    my ($a, $b) = @_;
    my ($A, $B, $AB) = {};
    foreach my $key (keys %$a) {
        my ($iA, $iAB, $iB) = compare($a->{$key}, $b->{$key});
        if(defined($b->{$key})) {
            $AB->{$key} = $iAB;
            $A->{$key} = $iA;
            $B->{$key} = $iB;
        } else {
            $A->{$key} = $iA;
        }
    }
    foreach my $key (keys %$b) {
        if(defined($a->{$key})) {
            next;
        } else {
            $B->{$key} = $b->{$key};
        }
    }
    return ($A, $AB, $B);
}

sub hashOfListsHistogram {
    my ($hashOfLists, $keys) = @_;
    my $bins = [];
    my @tmpArr = keys %$hashOfLists; 
    $keys = \@tmpArr unless(defined($keys));
    foreach my $key (@$keys) {
        my $myBin = scalar(@{$hashOfLists->{$key}}); # size of list
        $bins->[$myBin] = [] unless(defined($bins->[$myBin]));
        push(@{$bins->[$myBin]}, $key);
    }
    my $retArrays = [];
    for(my $i=0; $i<@$bins; $i++) {
       next if(not defined($bins->[$i])); 
       push(@$retArrays, [$i, $bins->[$i]]);
    }
    return $retArrays;
}

sub preserveBijection {
    my ($mapXtoY, $mapYtoX, $x, $y) = @_;
    if (defined($mapXtoY->{$x}) && $mapXtoY->{$x} ne $y) {
        return ($mapXtoY, $mapYtoX, 0);
    } elsif (defined($mapYtoX->{$y}) && $mapYtoX->{$y} ne $x) {
        return ($mapXtoY, $mapYtoX, 0);
    } else {
        $mapXtoY->{$x} = $y;
        $mapYtoX->{$y} = $x;
        return ($mapXtoY, $mapYtoX, 1);
    }
}

sub editHistory {
    my ($object, $objectType, $objectAttribute, $objectOldValue, $user, $comment) = @_;
    my $entities = $figmodel->database()->get_objects('entity', 
        { "attribute" => $objectAttribute, "objectType" => $objectType });
    if(!defined($entities) || scalar(@$entities) < 1) {
        $entities = [$figmodel->database()->create_object("entity",  
            { "attribute" => $objectAttribute, "objectType" => $objectType })];
    }
    $figmodel->database()->create_object("history", {
        "modificationDate" => time(),
        "oldValue" => $objectOldValue,
        "objectID" => $object->_id(),
        "explanation" => $comment,
        "user" => $user,
        "DBENTITY" => $entities->[0]->_id(),
    });
}

# preserveUniqueAliases is an idempotent function
# that returns 1 if the conditions are held, zero otherwise.
# The conditions are:
# preserveUniqueAlias: The tuple (type, alias) maps to one and only one compound / reaction.
#
my $ALIAS_HASH = {};
sub preserveUniqueAliases {
    my ($type, $alias, $compound) = @_;
    if (defined($ALIAS_HASH->{$type.$alias}) &&
        $ALIAS_HASH->{$type.$alias} ne $compound) {
        return 0;
    } else {
        $ALIAS_HASH->{$type.$alias} = $compound;
        return 1;
    }
}

sub safeAddNewAlias {
    my ($type, $alias, $compound) = @_;
    my $aliases = $figmodel->database()->get_objects('cpdals', { 'type' => $type, 'alias' => $alias });
    if(@$aliases > 0) {
        warn "Failed to create alias $type $alias $compound, already exists in the database\n";
    } elsif(!preserveUniqueAliases($type, $alias, $compound)) { 
        warn "Failed to create alias $type $alias $compound, reserved by another compound\n";
    } else {
        $figmodel->database()->create_object('cpdals', { 'type' => $type, 'alias' => $alias, 'COMPOUND' => $compound }); 
    }
}

sub createCompound {
    my ($keggObj) = @_;
    my $success = 1;
    my $keggId = $keggObj->{"id"};
    # Set the name, abbrv to be smaller than 32 chars
    my $minName = $keggObj->{"names"}->[0];
    my $i = 0;
    while(length($minName) > 32 && $i < @{$keggObj->{"names"}}) {
       $minName = $keggObj->{"names"}->[$i];
       $i++;
    }
    my $cpdId = $figmodel->database()->check_out_new_id('compound');
    $figmodel->database()->create_object("compound", {
        "name" => $minName,
        "abbrev" => $minName,
        "owner" => "master",
        "modificationDate" => time(),
        "creationDate" => time(),
        "formula" => $keggObj->{"formula"},
        "public" => 1,
        "scope" => $SCOPE_VARIABLE,
        "id" => $cpdId,
    });
    safeAddNewAlias('KEGG', $keggId, $cpdId);
    foreach my $name (@{$keggObj->{"names"}}) {
        safeAddNewAlias('name', $name, $cpdId);
        my @searchNames = $figmodel->convert_to_search_name($name);
        foreach my $searchName (@searchNames) {
            safeAddNewAlias('searchname', $searchName, $cpdId);
        }
    }
    return $success;
}

sub parseKEGGCompoundFile {
    my ($compoundFile) = @_;
    if (!-e $compoundFile) {
        warn "Could not find KEGG compound file at $compoundFile!\n";
        exit();
    }
    open(my $compoundFH, "<", $compoundFile);
    my $KeggIdToObj = {};
    my $currEntryId  = "";
    my $currMode = "";
    while(<$compoundFH>) {
        if ($_ =~ /^\/\/\/$/) { # End of entry
            my @names = split(/;/, $KeggIdToObj->{$currEntryId}->{"tmpName"});  # Save the names
            push(@{$KeggIdToObj->{$currEntryId}->{"names"}}, @names);
            delete($KeggIdToObj->{$currEntryId}->{"tmpName"});
            # Now cleanup
            $currEntryId = "";
            $currMode = "";
            next;
        } 
        # Setting key : value pairs. Key is always 12 charachters long
        # (but is chomped anyhow). Need to set currMode. If key is empty,
        # currMode is same as in the previous line.
        my $valueStr;
        my $keyStr = substr($_, 0, 12); # Get the key
        if ($keyStr ne "            ") {
            chomp($keyStr);
            $currMode = $keyStr;
        }
        next if (length($_) < 13); # No Value string, next
        $valueStr = substr($_, 12, length($_)-13); # 12 + 1
        # Now only care about mode's ENTRY and NAME 
        if ($currEntryId eq "" && $currMode =~ /ENTRY/ && $valueStr =~ /(C\d\d\d\d\d)/){ # New entry
            $currEntryId = $1;
            $KeggIdToObj->{$currEntryId} = {
                "id" => $currEntryId,
                "tmpName" => "",
                "names" => [],
                "obsolete" => 0,
            };
            if ($valueStr =~ /Obsolete/) {
                $KeggIdToObj->{$currEntryId}->{"obsolete"} = 1;
            }
        } elsif ($currEntryId ne "" && $currMode =~ /NAME/) { 
            # Getting names and storing in temporary position until end of entry
            chomp($valueStr);
            $KeggIdToObj->{$currEntryId}->{"tmpName"} .= $valueStr;
        } elsif ($currEntryId ne "" && $currMode =~ /FORMULA/) {
            chomp($valueStr);
            $KeggIdToObj->{$currEntryId}->{"formula"} .= $valueStr;
        }
    }
    return $KeggIdToObj;
}
 
my $aliasMapKtoS = {};  # KEGG COMPOUND => listof(cpds)
my $aliasMapStoK = {};  # cpd => listof(Kegg compound)

my $cpdToSearchNames = {};
my $searchNameToCpd = {};
my $searchNameToCpds = {};

my $allSeedCompounds = $figmodel->database()->get_objects('compound', { 'public' => '1' });
my $allSeedCpdAliases = $figmodel->database()->get_objects('cpdals', {});
my $publicCompoundHash = {}; # cpd as key if compound is public and non-scoped
foreach my $cpd (@$allSeedCompounds) {
    if((!defined($cpd->scope()) || ($cpd->scope() eq $SCOPE_VARIABLE)) &&
        $cpd->public() == 1) {
        $publicCompoundHash->{$cpd->id()} = 1;
    }
}
foreach my $cpdals (@$allSeedCpdAliases) {
    next unless(defined($publicCompoundHash->{$cpdals->COMPOUND()}));
    if($cpdals->type() eq "KEGG") {
        $aliasMapKtoS->{$cpdals->alias()} = [] unless(defined($aliasMapKtoS->{$cpdals->alias()}));
        push(@{$aliasMapKtoS->{$cpdals->alias()}}, $cpdals->COMPOUND());
        $aliasMapStoK->{$cpdals->COMPOUND()} = [] unless(defined($aliasMapStoK->{$cpdals->COMPOUND()}));
        push(@{$aliasMapStoK->{$cpdals->COMPOUND()}}, $cpdals->alias());
    } elsif($cpdals->type() eq "name") {
        my @searchNames = $figmodel->convert_to_search_name($cpdals->alias());
        $cpdToSearchNames->{$cpdals->COMPOUND()} = [] unless(defined($cpdToSearchNames->{$cpdals->COMPOUND()}));
        push(@{$cpdToSearchNames->{$cpdals->COMPOUND()}}, @searchNames);
        foreach my $searchName (@searchNames) {
            if(not defined($searchNameToCpd->{$searchName})) {
                $searchNameToCpd->{$searchName} = $cpdals->COMPOUND()
            } else {
                $searchNameToCpd->{$searchName} = "-1"; # invlaidate 
            }
        }
        foreach my $searchName (@searchNames) {
            $searchNameToCpds->{$searchName} = [] unless(defined($searchNameToCpds->{$searchName}));
            push(@{$searchNameToCpds->{$searchName}}, $cpdals->COMPOUND());
        }
    }
}
# Remove invalid search name to cpd entries
foreach my $name (keys %$searchNameToCpd) {
    if ($searchNameToCpd->{$name} eq "-1") {
        delete($searchNameToCpd->{$name});
    }
}

# Parse KEGG Compound File into hash of compound objects
my $compoundFile = $importDir . "ligand/compound/compound";
my $KeggIdToObj = parseKEGGCompoundFile($compoundFile);
# Now build two important lookup tables
my $KEGGNameToId = {};
my $KEGGIdToName = {};
foreach my $KeggCompoundId (keys %$KeggIdToObj) {
    my @names = @{$KeggIdToObj->{$KeggCompoundId}->{"names"}};
    foreach my $name (@names) {
        ($KEGGNameToId, $KEGGIdToName) = addNameToLookupTables($KeggCompoundId, $name, $KEGGNameToId, $KEGGIdToName);
    }
}

sub printGreeting {
    my ($compoundFile) = @_;
    my $ckSum = Digest::MD5->new();
    open(my $fh, "<", $compoundFile);
    while(<$fh>) {
       $ckSum->add($_);
    } 
    close($fh);   
    print "Parsing KEGG compounds contained in ligand database from " .
        ctime(stat($compoundFile)->mtime) . " with md5: \n" . $ckSum->hexdigest() . "\n"; 
}
printGreeting($compoundFile);

# For each kegg id, take it's search names and lookup all cpdids matching
# that searchname, if all ids == 1, we should be good...
my $obsoleteKEGGCompounds = [];
my $obsoleteKEGGCompoundsInSEED = [];
my $exactMatches = [];
my $noEntriesCount = 0;
my $matchOnKidCount = 0;
my $matchOnKid = {};
my $tooManyEntriesCount = 0;
my $tooManyKeys = [];
my $noEntries = [];
my $KeggIdToCpdId = {};
my $KeggStoK = {};
my $MappedKtoSInvariant = {};

foreach my $keggId (keys %$KEGGIdToName) {
    if (defined($KeggIdToObj->{$keggId}) && $KeggIdToObj->{$keggId}->{"obsolete"} == 1) {
        if(not defined($aliasMapKtoS->{$keggId})) {
            push(@$obsoleteKEGGCompounds, $keggId);    
        } else {
            push(@$obsoleteKEGGCompoundsInSEED, $keggId);
        }
        next; 
    }
    my @keggNames;
    foreach my $name (@{$KeggIdToObj->{$keggId}->{"names"}}) {
        push(@keggNames, $figmodel->convert_to_search_name($name));
    }
    my $cpds2 = undef;
    my $cpds = {};
    foreach my $keggName (@keggNames) {
        if(defined($searchNameToCpds->{$keggName})) {
            my %currSearchNameCpds = map { $_ => 1 } @{$searchNameToCpds->{$keggName}}; # Get list of compounds that match this name
            if (not defined($cpds2)) { # First time through, just get all candidate compounds
                $cpds2 = \%currSearchNameCpds;
            } else {
                my ($foo, $bar) = undef;
                ($foo, $cpds2, $bar) = compare($cpds2, \%currSearchNameCpds); # then only take those compounds that intersect other candidate lists
            }
        }
        if(defined($searchNameToCpd->{$keggName})) {
            $cpds->{$searchNameToCpd->{$keggName}} = 0 unless(defined($cpds->{$searchNameToCpd->{$keggName}}));
            $cpds->{$searchNameToCpd->{$keggName}}++;
        }
    }
    my @cpdList = keys %$cpds2;
    $KeggIdToCpdId->{$keggId} = \@cpdList;
    if(scalar(keys %$cpds2) == 1) {
        my $cpd = (keys %$cpds2)[0];
        $KeggStoK->{$cpd} = [] unless(defined($KeggStoK->{$cpd}));
        push(@{$KeggStoK->{$cpd}}, $keggId);
        push(@$exactMatches, keys %$cpds2);
    } elsif(scalar(keys %$cpds2) == 0) {
        # If we can't find the entry, try checking if the Kid is already aliased 
        if(defined($aliasMapKtoS->{$keggId}) && @{$aliasMapKtoS->{$keggId}} == 1) {
            $matchOnKidCount++;         
            $matchOnKid->{$keggId} = $aliasMapKtoS->{$keggId}->[0];
        } elsif (defined($aliasMapKtoS->{$keggId})) {
            print $keggId . " maps to " . scalar(@{$aliasMapKtoS->{$keggId}}) . " entries\n";
        } else {
            push(@$noEntries, $keggId);
            $noEntriesCount++;
        }
    } else {
        $tooManyEntriesCount++;
        push(@$tooManyKeys, $keggId);
    }
}
sub printMappings {
    my ($MappingHash) = @_;
    foreach my $cpd (sort keys %$MappingHash) {
        if (scalar(@{$MappingHash->{$cpd}}) == 0) {
            next;
        } else {
            print "        " . $cpd . " : " . join(' ', @{$MappingHash->{$cpd}}) . "\n";
        } 
    }
}

sub checkKSMappings {
    my ($MappingsHash) = @_;
    foreach my $cpd (sort keys %$MappingsHash) {
        foreach my $kegg (@{$MappingsHash->{$cpd}}) {
            unless(preserveUniqueAliases("KEGG", $kegg, $cpd)) {
                print "        $cpd : $kegg is not uniuqe!\n";
            }
        }
    } 
}
    
sub printTruncated {
    my ($MappingsHash, $max) = @_;
    my @keys = keys %$MappingsHash;
    my @empty;
    my @randKeys = map { $keys[$_] } # get $max random keys
        map { rand(scalar(@keys)) } @empty[1..$max]; # ranging over size of mappingsHash
    my %newHash = map { $_ => $MappingsHash->{$_} } @randKeys;
    printMappings(\%newHash);
}
   
sub printSummary {
    my ($aliasMapStoK, $KeggStoK, $OldMapStoK, $CommonMapStoK, $NewMapStoK) = @_;
    my $counts = [];
    foreach my $mapStoK ($aliasMapStoK, $KeggStoK, $OldMapStoK, $CommonMapStoK, $NewMapStoK) {
        my $count = 0;
        foreach my $values (values (%$mapStoK)) {
            $count += scalar(@$values);
        }
        push(@$counts, $count);
    }
    print "There were " . $counts->[0] . " original mappings. Now we have " .
        ($counts->[3] + $counts->[4]) . " new or unchanged mappings; a " .
    sprintf("%.2f", 100*($counts->[3] + $counts->[4])/$counts->[0]) . "% change\n";
    print "    " . $counts->[3] . " go unchanged (".
        sprintf("%.2f", 100*($counts->[3]/$counts->[0])) . "%)\n";
    print " Printing 10 of these (for sanity).\n" if($DEBUG);
    printTruncated($CommonMapStoK, 10) if($DEBUG);
    print "    with the following changes in the mapping rules from SEED compounds to KEGG compounds:\n";
    print "    Remove ". $counts->[2] ." old mappings: \n";
    print "    (cpd Id) : (KEGG ids to remove)\n" if($DEBUG);
    printMappings($OldMapStoK) if($DEBUG);
    print "    Add ". $counts->[4] ." new mappings: \n";
    print "    (cpd Id) : (KEGG ids to add)\n" if($DEBUG);
    printMappings($NewMapStoK) if($DEBUG);
    print "    Mappings that violate the unique KEGG alias requirement will be printed below (one per KEGG id):\n";
    checkKSMappings($CommonMapStoK);
    checkKSMappings($NewMapStoK);
}
print "Obsolete entries not listed in SEED: " . scalar(@$obsoleteKEGGCompounds) . "\n"; 
print "Obsolete enteries present in SEED:   " . scalar(@$obsoleteKEGGCompoundsInSEED) . "\n";
print "Exact matches: " . scalar(@$exactMatches) . ", producing a set of SEED compound -> [KEGG compound] mappings...\n";
my ($OldMapStoK, $CommonMapStoK, $NewMapStoK) = compare($aliasMapStoK, $KeggStoK);
printSummary($aliasMapStoK, $KeggStoK, $OldMapStoK, $CommonMapStoK, $NewMapStoK);

sub rerunMappings {
    my ($targetKegg, $targetCpd, $newName, $oldMappings) = @_;
    my $newMappings = {};
    foreach my $keggId (keys %$KeggIdToObj) {
        if (defined($KeggIdToObj->{$keggId}) && $KeggIdToObj->{$keggId}->{"obsolete"} == 1) {
            next;
        }
        my @keggNames;
        foreach my $name (@{$KeggIdToObj->{$keggId}->{"names"}}) {
            push(@keggNames, $figmodel->convert_to_search_name($name));
        }
        push(@keggNames, $newName) if($keggId eq $targetKegg);
        my $cpds2 = undef;
        foreach my $keggName (@keggNames) {
            if(defined($searchNameToCpds->{$keggName})) {
                # Get list of compounds that match this name
                my %currSearchNameCpds = map { $_ => 1 } @{$searchNameToCpds->{$keggName}};
                if (not defined($cpds2)) {
                    # First time through, just get all candidate compounds
                    $cpds2 = \%currSearchNameCpds;
                } else {
                    my ($foo, $bar) = undef;
                    # then only take those compounds that intersect other candidate lists
                    ($foo, $cpds2, $bar) = compare($cpds2, \%currSearchNameCpds); 
                }
            }
        }
        my @cpdList = keys %$cpds2;
        if(scalar(keys %$cpds2) == 1) {
            my $cpd = (keys %$cpds2)[0];
            $newMappings->{$cpd} = [] unless(defined($newMappings->{$cpd}));
            push(@{$newMappings->{$cpd}}, $keggId);
        } 
    }
    my ($a, $b, $c) = compare($oldMappings, $newMappings);
    my $status = 0;
    foreach my $value (values %$a) {
        $status += scalar(@$value);
    }
    if (defined($c->{$targetCpd}) &&  $status == 0) {
        $status = 1;  
    } else {
        warn "got $status for $targetKegg $newName\n";
        $status = 0;
        #print keys %$a;
    }
    return ($status, $newMappings);
}
    

# Now attempting to add back aliases that were dropped    
#print "There were " . $matchOnKidCount . " old mappings that could not be found\n".
#"with searchnames. Using the old mappings, attempting to add one name to each\n".
#" compound while not breaking uniqueness rules on compound names and searchnames.\n".
#" Also making sure that any existing mappings are preserved\n";
#my $oldMappings = $KeggStoK;
#foreach my $kegg (sort keys %$matchOnKid) {
#    my $cpd = $matchOnKid->{$kegg};     
#    my $found = 0;
#    unless(preserveUniqueAliases("KEGG", $kegg, $cpd)) {
#        print "    $cpd : $kegg Unable to map, $kegg already aliased.\n";
#        next;
#    }
#    foreach my $name (@{$KeggIdToObj->{$kegg}->{"names"}}) {
#        my ($status, $newMappings) = rerunMappings($kegg, $cpd, $name, $oldMappings);
#        if($status == 1) {
#            $oldMappings = $newMappings;
#            $found = 1;
#            print "    $cpd : $kegg maps correctly if $name is added to compound!\n";
#            last;
#        }
#    }
#    if(!$found) {
#        print "    $cpd : $kegg unable to find good name in KEGG entry!\n";
#    }
#}

print "Of the " . scalar(keys %$KeggIdToObj) . " KEGG compounds we have:\n";
my $oldSize = 0;
foreach my $values (values %$CommonMapStoK) {
    map { $MappedKtoSInvariant->{$_} = 1 } @$values;
}
print "    " . scalar(keys %$MappedKtoSInvariant) . " are associated with SEED compounds (unchanged mappings)\n";
$oldSize = scalar(keys %$MappedKtoSInvariant);
foreach my $values (values %$NewMapStoK) {
    map { $MappedKtoSInvariant->{$_} = 1 } @$values;
}
print "    " . (scalar(keys %$MappedKtoSInvariant)-$oldSize) . " are associated with SEED compounds (new mappings)\n";
$oldSize = scalar(keys %$MappedKtoSInvariant);
map { $MappedKtoSInvariant->{$_} = 1 } @$noEntries;
print "    " . (scalar(keys %$MappedKtoSInvariant)-$oldSize) . " are new (need to be added to the database)\n";
$oldSize = scalar(keys %$MappedKtoSInvariant);
map { $MappedKtoSInvariant->{$_} = 1 } @$obsoleteKEGGCompounds;
print "    " . (scalar(keys %$MappedKtoSInvariant)-$oldSize) . " are obsolete and not in the SEED\n"; 
$oldSize = scalar(keys %$MappedKtoSInvariant);
map { $MappedKtoSInvariant->{$_} = 1 } @$obsoleteKEGGCompoundsInSEED;
print "    " . (scalar(keys %$MappedKtoSInvariant)-$oldSize) . " are obsolete and need to be removed from the SEED\n";
$oldSize = scalar(keys %$MappedKtoSInvariant);
map { $MappedKtoSInvariant->{$_} = 1 } keys %$matchOnKid;
print "    " . (scalar(keys %$MappedKtoSInvariant)-$oldSize) . " that have existing mappings that will be removed\n";
print "This leaves " . (scalar(keys %$KEGGIdToName) - scalar(keys %$MappedKtoSInvariant)) .  " unaccounted for KEGG compounds...\n";
# Changing old mappings
my $NewMapStoKbyK = {};
foreach my $seedId (keys %$NewMapStoK) {
    foreach my $keggId (@{$NewMapStoK->{$seedId}}) {
        if(defined($NewMapStoKbyK->{$keggId})) {
           warn "Two mappings for a single KEGG ID $keggId\n"; 
        } else {
            $NewMapStoKbyK->{$keggId} = $seedId;
        }
    }
}
if($FINAL) {
    foreach my $seedId (keys %$OldMapStoK) {
        foreach my $keggId (@{$OldMapStoK->{$seedId}}) {
            my $alias = $figmodel->database()->get_object("cpdals",
                { "type" => "KEGG", "alias" => $keggId });
            unless(defined($alias)) {
                warn "Could not find alias for KEGG id $keggId\n";
                next;
            }
            if(defined($NewMapStoKbyK->{$keggId})) {
                my $newSeedId = $NewMapStoKbyK->{$keggId};
                editHistory($alias, "cpdals", "COMPOUND", $alias->COMPOUND(), "sdevoid", 
                    "Switching mapping for KEGG id $keggId to $newSeedId.");
                $alias->COMPOUND($newSeedId);
                # Now remove the entry from NewMapStoK since we've already done it
                my $pendingKeggIds = $NewMapStoK->{$newSeedId};
                my $otherKeggIds = [];
                foreach my $pendingKeggId (@$pendingKeggIds) {
                    if($pendingKeggId ne $keggId) {
                        push(@$otherKeggIds, $pendingKeggId);
                    }
                }
                $NewMapStoK->{$newSeedId} = $otherKeggIds;
                print "    Switched kegg Id $keggId from $seedId to $newSeedId\n";
            } else {
                editHistory($alias, "cpdals", "alias", $alias->alias(), "sdevoid", 
                    "Removing KEGG id $keggId from $seedId as it is no longer matched by the KEGG.");
                $alias->delete();
                print "    Removed alias $keggId from $seedId\n";
            }
        }
    }
    foreach my $seedId (keys %$NewMapStoK) {
        foreach my $keggId (@{$NewMapStoK->{$seedId}}) {
            my $existingAliases = $figmodel->database()->get_objects('cpdals',
                { "type" => "KEGG", "alias" => $keggId }); 
            if(@$existingAliases > 0) {
                warn "Alias $keggId already exists in the database! Aborting!\n";
                next;
            }
            my $alias = $figmodel->database()->create_object("cpdals",
                { "type" => "KEGG", "alias" => $keggId, "COMPOUND" => $seedId });
            if(defined($alias)) {
                print "    Created alias for KEGG id " . $alias->alias() . " to compound " . $alias->COMPOUND() . "\n";
            }
        } 
    }
} elsif($DEBUG) {
    print "These KEGG ids change mappings from one compound to another:\n";
    my $counter = 0;
    foreach my $seedId (keys %$OldMapStoK) {
        foreach my $keggId (@{$OldMapStoK->{$seedId}}) {
            if(defined($NewMapStoKbyK->{$keggId})) {
                print "    $keggId : $seedId => ". $NewMapStoKbyK->{$keggId} ."\n";
                $counter++;
            }
        }
    }
    print "    Leaving " . (scalar( grep { scalar(@{$OldMapStoK->{$_}}) > 0 } keys %$OldMapStoK)
        - $counter) . " mappings that will be removed and\n";
    print "    leaving " . (scalar( grep { scalar(@{$NewMapStoK->{$_}}) > 0 } keys %$NewMapStoK)
        - $counter) . " mappings that will be added.\n";
}
# Creating new compounds
if($FINAL) {
    print "Creating " . scalar(@$noEntries) . " compounds...\n";
    foreach my $keggId (sort @$noEntries) {
        createCompound($KeggIdToObj->{$keggId});
        print "Created SEED compound for KEGG compound " . $keggId. "\n";
    }
} elsif($DEBUG) {
    print "And the compounds with no entries are: \n" . join(", ", sort @$noEntries) . "\n";
}
# OBSOLETE COMPOUNDS IN KEGG
if($DEBUG) {
    print "And compounds that are now obsolete (".scalar(@$obsoleteKEGGCompoundsInSEED).") are:\n";
    foreach my $keggId (@$obsoleteKEGGCompoundsInSEED) {
        my $seedId = "";
        (defined($aliasMapKtoS->{$keggId})) ? $seedId = $aliasMapKtoS->{$keggId} : $seedId = "";
        print "    $keggId\t$seedId\n";
    }
} elsif($FINAL) {
    print "Removing " . scalar(@$obsoleteKEGGCompoundsInSEED) . " compound KEGG aliases because the KEGG id is obsolete.\n";
    foreach my $keggId (@$obsoleteKEGGCompoundsInSEED) { 
        my $aliases = $figmodel->database()->get_objects("cpdals", { "type" => "KEGG", "alias" => $keggId});
        unless(@$aliases == 1) {
            warn "   Could not find obsolete alias for KEGG id $keggId\n";
            next;
        }
        my $alias = $aliases->[0];
        my $compound = $alias->COMPOUND();
        editHistory($alias, "cpdals", "alias", $alias->alias(), "sdevoid", 
            "Removing $keggId alias from compound $compound because it is listed as obsolete in KEGG."
        );
        $alias->delete();
        print "    Removed alias $keggId from $compound\n";
    }
}
