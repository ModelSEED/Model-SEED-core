#!/usr/bin/perl 
use strict;
use warnings;
use ModelSEED::FIGMODEL;
use Data::Dumper;
use File::stat;
use Digest::MD5;
use Time::localtime;

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

sub pwarn {
    my ($string) = @_;
    if($FINAL) {
        warn $string;
    } elsif($DEBUG) {
        print $string;
    } else {
         
    }
}

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

my $NEGATIVE_ALIAS_HASH = {}; # If "type"."alias" in hash, and !$FINAL, not in real database
my $POSITIVE_ALIAS_HASH = {}; # Add to POSITIVE ALIAS HASH iff !$FINAL && not in real database

sub addAlias {
    my ($type, $alias, $id) = @_;
    my $existingAlias = $figmodel->database()->get_object("rxnals",
        {"type" => $type, "alias" => $alias});
    if (!$FINAL && defined($POSITIVE_ALIAS_HASH->{$type.$alias})) {
        return 0;
    } elsif(!$FINAL && $existingAlias) {
        if(defined($NEGATIVE_ALIAS_HASH->{$type.$alias})) {
            $POSITIVE_ALIAS_HASH->{$type.$alias} = $id;
            return 1;
        } else {
            return 0;
        }
    } elsif($FINAL && $existingAlias) {
        return 0;
    } elsif($FINAL) {
        $figmodel->database()->create_object("rxnals",
            {"type" => $type, "alias" => $alias, "REACTION" => $id });
        return 1;
    } else {
        $POSITIVE_ALIAS_HASH->{$type.$alias} = $id;
        return 1;
    }
}

sub removeAlias {
    my ($type, $alias, $id) = @_;
    my $existingAlias = $figmodel->database()->get_object("rxnals",
        {"type" => $type, "alias" => $alias});
    if(!$FINAL && !defined($existingAlias)) {
        if(defined($POSITIVE_ALIAS_HASH->{$type.$alias})) {
            $POSITIVE_ALIAS_HASH->{$type.$alias}->delete();
            $NEGATIVE_ALIAS_HASH->{$type.$alias} = $id;
            return 1;
        }
        return 0;
    } elsif(!$FINAL && defined($existingAlias) ) {
        $POSITIVE_ALIAS_HASH->{$type.$alias}->delete() if(defined($POSITIVE_ALIAS_HASH->{$type.$alias}));
        $NEGATIVE_ALIAS_HASH->{$type.$alias} = $id;
        return 1;
    } elsif($FINAL && !defined($existingAlias)) {
        return 0;
    } elsif($FINAL && defined($existingAlias)) {
        $existingAlias->delete();
        return 1;
    }
}


sub parseKEGGReactionFile {
    my ($reactionFile) = @_;
    if (!-e $reactionFile) {
        warn "Could not find KEGG compound file at $reactionFile!\n";
        exit();
    }
    open(my $reactionFH, "<", $reactionFile);
    my $KeggIdToObj = {};
    my $currEntryId  = "";
    my $currMode = "";
    while(<$reactionFH>) {
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
        if ($currEntryId eq "" && $currMode =~ /ENTRY/ && $valueStr =~ /(R\d\d\d\d\d)/){ # New entry
            $currEntryId = $1;
            $KeggIdToObj->{$currEntryId} = {
                "id" => $currEntryId,
                "tmpName" => "",
                "eq" => "",
                "names" => [],
                "enzyme" => "",
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
        } elsif ($currEntryId ne "" && $currMode =~ /EQUATION/) {
            chomp($valueStr);
            $KeggIdToObj->{$currEntryId}->{"eq"} .= " " .$valueStr;
        } elsif ($currEntryId ne "" && $currMode =~ /ENZYME/) {
            chomp($valueStr);
            $KeggIdToObj->{$currEntryId}->{"enzyme"} .= " " . $valueStr;
        } elsif ($currEntryId ne "" && $currMode =~ /DEFINITION/) {
            chomp($valueStr);
            $KeggIdToObj->{$currEntryId}->{"definition"} .= " " . $valueStr;
        }
    }
    return $KeggIdToObj;
}

my $savedAliasMappings = {};

sub safeCreateAlias {
    my ($type, $alias, $reaction) = @_;
    my $existingAlias = $figmodel->database()->get_object("rxnals", { "type" => $type, "alias" => $alias });
    if(defined($existingAlias)) {
        warn "Alias $alias for reaction $reaction already defined with reaction: " . $existingAlias->REACTION() . "\n";
        return;
    } else {
        if($FINAL) {
            $figmodel->database()->create_object("rxnals",
                { "type" => $type, "alias" => $alias, "REACTION" => $reaction });
        }
    }
}

my $RXN_NO_NAME_FAILURES = [];
my $RXN_ERR_FAILURES = [];
sub createReaction {
    my ($rxnObj, $SeedCpdKtoS) = @_;
    if(@{$rxnObj->{"names"}} == 0) {
        pwarn("No name defined for reaction ".$rxnObj->{"id"} . " skipping!\n");
        push(@$RXN_NO_NAME_FAILURES, $rxnObj->{"id"});
        return;
    }
    my $rxnId = "placeholder";
    if($FINAL) {
       $rxnId = $figmodel->database()->check_out_new_id("reaction");
    }
    my ($dir, $code, $revCode, $eq, $compartment, $error) =
        $figmodel->ConvertEquationToCode($rxnObj->{"eq"}, $SeedCpdKtoS);
    if($error) {
        pwarn("Failure to parse equation for " . $rxnObj->{"id"} . "\n");
        push(@$RXN_ERR_FAILURES, $rxnObj->{"id"});
        return;
    }
    my $rxnName = $rxnObj->{"names"}->[0];
    my $i = 0;
    while(length($rxnName) > 255 && @{$rxnObj->{"names"}} > $i) {
       $rxnName = $rxnObj->{"names"}->[$i];
       $i++;
    }
    my $time = time();
    my $SeedRxnObj = {
        "id" => $rxnId,
        "name" => $rxnName,
        "abbrev" => $rxnName,
        "enzyme" => $rxnObj->{"enzyme"},
        "definition" => $rxnObj->{"definition"},
        "code" => $code,
        "equation" => $eq,
        "reversibility" => $dir,
        "owner" => "master",
        "scope" => $SCOPE_VARIABLE,
        "modificationDate" => $time,
        "creationDate" => $time,
        "public" => 1,
        "status" => "OK",
    };
    unless(addAlias("KEGG", $rxnObj->{"id"}, $rxnId)) {
        pwarn("Unable to create KEGG alias for $rxnId " . $rxnObj->{"id"} . "\n");
    }
    if($FINAL) {
        $figmodel->database()->create_object("reaction", $SeedRxnObj);
    } else {
        print "Creating reaction for KEGG id " . $rxnObj->{"id"} . "\n";
    }
    foreach my $name (@{$rxnObj->{"names"}}) {
        addAlias("name", $name, $rxnId);
        my @searchNames = $figmodel->convert_to_search_name($name);
        foreach my $searchName (@searchNames) {
            addAlias("searchname", $searchName, $rxnId);
        }
    }
    my @eqParts = split(/ /, $eq);
    my $coefficient = 1;
    my $CurrCompartment = $compartment; 
    my $coeffSign = "-";
    my $cpd = "";
    my $reset = 1;
    foreach my $part (@eqParts) {
        if($reset) {
            $CurrCompartment = $compartment;
            $coefficient = 1;
            $reset = 0;
        }
        if($part =~ /(cpd\d\d\d\d\d)\[(.)\]/ ) {
            $cpd = $1;
            $compartment = $2;
            if($FINAL) {
                $figmodel->database()->create_object("cpdrxn",
                    { "cofactor" => 0, "compartment" => $compartment,
                      "REACTION" => $rxnId, "COMPOUND" => $cpd,
                      "coefficient" => $coeffSign . $coefficient, });
            } 
            $reset = 1;
        } elsif ($part =~ /(cpd\d\d\d\d\d)/) {
            $cpd = $1;
            if($FINAL) {
                $figmodel->database()->create_object("cpdrxn",
                    { "cofactor" => 0, "compartment" => $compartment,
                      "REACTION" => $rxnId, "COMPOUND" => $cpd,
                      "coefficient" => $coeffSign . $coefficient, });
            }
            $reset = 1;
        } elsif ($part =~ /\((\d+)\)/) {
            $coefficient = $1;
        } elsif ($part =~ /(\d+)/) {
            $coefficient = $1;
        } elsif ($part =~ /\<\=\>/) {
            $coeffSign = "";
        } elsif ($part =~ /\+/) {
            $reset = 1;
        } else {
            pwarn("Unknown error in parsing $eq at $part!\n");
        }
    }
    return;    
}

 
# Build mapping from Cpd to kegg compound ids to convert seed equations into kegg equations
my $SeedCpdStoK = {};
my $SeedCpdKtoS = {};
my $allSeedCompoundKeggAliases = $figmodel->database()->get_objects('cpdals', {'type' => 'KEGG'});
foreach my $cpdAls (@$allSeedCompoundKeggAliases) {
    $SeedCpdStoK->{$cpdAls->COMPOUND()} = $cpdAls->alias();
    $SeedCpdKtoS->{$cpdAls->alias()} = $cpdAls->COMPOUND();
}

my $SeedEqCodeToId = {}; # In KEGG compound ids
my $SeedIdToEqCode = {}; # In KEGG compound ids

my $allSeedReactions = $figmodel->database()->get_objects('reaction', { 'public' => '1' });
my $allSeedRxnAliases = $figmodel->database()->get_objects('rxnals', { 'type' => 'KEGG' });
my $publicReactionHash = {}; # cpd as key if compound is public and non-scoped
foreach my $rxn (@$allSeedReactions) {
    if((!defined($rxn->scope()) || ($rxn->scope() eq $SCOPE_VARIABLE)) &&
        $rxn->public() == 1) {
        $publicReactionHash->{$rxn->id()} = 1;
        my ($dir, $code, $revCode, $eq, $compartment, $error) =
            $figmodel->ConvertEquationToCode($rxn->equation());
        $SeedEqCodeToId->{$code} = $rxn->id();
        $SeedIdToEqCode->{$rxn->id()} = $code;

    }
}
my $SeedRxnKtoS = {};  # KEGG REACTION => SEED reaction
my $SeedRxnStoK = {};
foreach my $rxnals (@$allSeedRxnAliases) {
    next unless(defined($publicReactionHash->{$rxnals->REACTION()}));
    $SeedRxnKtoS->{$rxnals->alias()} = $rxnals->REACTION();
    $SeedRxnStoK->{$rxnals->REACTION()} = $rxnals->alias();
}

# Parse KEGG Reaction File into hash of compound objects
my $reactionFile = $importDir . "ligand/reaction/reaction";
my $KeggIdToObj = parseKEGGReactionFile($reactionFile);

sub printGreeting {
    my ($rxnFile) = @_;
    my $ckSum = Digest::MD5->new();
    open(my $fh, "<", $rxnFile);
    while(<$fh>) {
       $ckSum->add($_);
    }
    close($fh);
    print "Parsing KEGG reactions contained in ligand database from " .
        ctime(stat($rxnFile)->mtime) . " with md5: \n" . $ckSum->hexdigest() . "\n";
}
printGreeting($reactionFile);

my $obsoleteKEGGReactions = [];
my $obsoleteKEGGReactionsInSEED = [];
my $DeNovoRxnKtoS = {};
my $KeggRxnsNotFound = [];
my $KeggRxnsChanged = [];
my $GlycanContainingRxns = [];
my $SubscriptedRxns = [];

foreach my $keggId (keys %$KeggIdToObj) {
    if (defined($KeggIdToObj->{$keggId}) && $KeggIdToObj->{$keggId}->{"obsolete"} == 1) {
        if(not defined($SeedRxnKtoS->{$keggId})) {
            push(@$obsoleteKEGGReactions, $keggId);    
        } else {
            push(@$obsoleteKEGGReactionsInSEED, $keggId);
        }
        next; 
    }
    my $equation = $KeggIdToObj->{$keggId}->{"eq"};
    my ($dir, $code, $revCode, $eq, $compartment, $error) =
        $figmodel->ConvertEquationToCode($equation, $SeedCpdKtoS);
    if (defined($SeedEqCodeToId->{$code})) {
        $DeNovoRxnKtoS->{$keggId} = $SeedEqCodeToId->{$code};
    } elsif(defined($SeedEqCodeToId->{$revCode})) {
        $DeNovoRxnKtoS->{$keggId} = $SeedEqCodeToId->{$revCode};
    # Now moving on to exclusions from mappings
    } elsif ($code =~ /G\d\d\d\d\d/) {
        push(@$GlycanContainingRxns, $keggId);
    } elsif ($code =~ /\(n\)/ || $code =~ /\(m\)/) {
        push(@$SubscriptedRxns, $keggId);
    } elsif ($code =~ /ncpd/) {
        push(@$SubscriptedRxns, $keggId);
    } else {
#        my $oldMapping = $SeedRxnKtoS->{$keggId};
#        if(defined($oldMapping)) {
#            print "$keggId has equation: \n    " . $code .
#                "\n    Was orriginally mapped to $oldMapping with code\n    ".
#                $SeedIdToEqCode->{$oldMapping} . "\n";
#        } else {
#            print "$keggId has equation: \n    " . $code .
#                "\n    Was not mapped to any existing SEED reaction.\n";
#        }
        push(@$KeggRxnsNotFound, $keggId);
    }
}
print scalar(@$allSeedReactions) . " reactions in the SEED, with " . scalar(keys %$SeedRxnKtoS) . " reactions mapped to KEGG reactions.\n";
print scalar(keys %$KeggIdToObj) . " reactions in the KEGG.\n";
print "Obsolete entries not listed in SEED: " . scalar(@$obsoleteKEGGReactions) . "\n"; 
print "Obsolete enteries present in SEED: " . scalar(@$obsoleteKEGGReactionsInSEED) . "\n";
print scalar(@$GlycanContainingRxns) . " contain compounds from the GLYCAN KEGG database and are excluded.\n";
print scalar(@$SubscriptedRxns) . " reactions use the subscript notation and are excluded.\n";
print "Reactions not found in SEED: " . scalar(@$KeggRxnsNotFound) . "\n";
#print "reactions that have changed mappings: " . scalar(@$KeggRxnsChanged) . "\n";
print scalar(keys %$DeNovoRxnKtoS) . " mappings found de Novo from identical equations, with the following breakdown\n";
my ($OldRxnKtoS, $CommonRxnKtoS, $NewRxnKtoS) = compare($SeedRxnKtoS, $DeNovoRxnKtoS);
print "    " . scalar( grep { defined($OldRxnKtoS->{$_}) } keys %$OldRxnKtoS) . " mappings that are now invalid.\n";
print "    " . scalar( grep { defined($CommonRxnKtoS->{$_}) } keys %$CommonRxnKtoS) . " mappings that remain the same.\n";
print "    " . scalar( grep { defined($NewRxnKtoS->{$_})} keys %$NewRxnKtoS) . " new mappings that need to be added.\n";
foreach my $keggId (keys %$OldRxnKtoS) {
    next unless(defined($OldRxnKtoS->{$keggId}));
    if (defined($NewRxnKtoS->{$keggId})) {
        if($FINAL) {
            my $rxnAls = $figmodel->database()->get_object('rxnals', { 'type' => "KEGG",
                "alias" => $keggId});
            editHistory($rxnAls, "rxnals", "REACTION", $rxnAls->REACTION(), "sdevoid",
                "Changing reaction alias for KEGG id $keggId from ".$rxnAls->REACTION().
                " to " . $NewRxnKtoS->{$keggId});
            $rxnAls->REACTION($NewRxnKtoS->{$keggId});
            delete($NewRxnKtoS->{$keggId});
        } else {
            print "        " . $keggId . " switches from " . $OldRxnKtoS->{$keggId} .
                " to " . $NewRxnKtoS->{$keggId} . "\n";
            removeAlias("KEGG", $keggId, $OldRxnKtoS->{$keggId});
            addAlias("KEGG", $keggId, $NewRxnKtoS->{$keggId});
        }
    } elsif($FINAL) {
        my $rxnAls = $figmodel->database()->get_object('rxnals', { 'type' => "KEGG",
            "alias" => $keggId});
        editHistory($rxnAls, "rxnals", "REACTION", $rxnAls->REACTION(), "sdevoid",
            "Removing reaction alias for KEGG id $keggId from ".$rxnAls->REACTION());
        $rxnAls->delete();
    } else {
        removeAlias("KEGG", $keggId, $OldRxnKtoS->{$keggId});
    }
}

foreach my $keggId (keys %$NewRxnKtoS) {
    next unless(defined($NewRxnKtoS->{$keggId}));
    addAlias("KEGG", $keggId, $NewRxnKtoS->{$keggId});
}

# Create Missing Reactions, if not final, does not create
foreach my $keggId (@$KeggRxnsNotFound) {
    createReaction($KeggIdToObj->{$keggId}, $SeedCpdKtoS);
}
print "Of the " . scalar(@$KeggRxnsNotFound) . " reactions to be added, " .
    scalar(@$RXN_NO_NAME_FAILURES) . " reactions could not be added as they were unnamed. " .
    "In addition, " . scalar(@$RXN_ERR_FAILURES) . " reactions could not be added because of " .
    "an error in parsing the equation.\n";
