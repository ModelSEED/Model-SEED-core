package ModelSEEDHandler;
use strict;
use warnings;
use FIG_Config;
use Carp;
use Digest::MD5 qw( md5 ); # For databaseConnections cache keys

sub new {
    my ($type, $objectConfigFiles, $databaseConfigFiles) = @_;
    my $self = {
        'databases' => {},
        'disabledDatabases' => {},
        'objects' => {},
        'disabledObjects' => {},
        'databaseConnections' => {}, 
    };
    bless $self;
    # Load default configuration file
    if(defined($FIG_Config::ModelSEEDHandlerDatabaseConfig) && defined($FIG_Config::ModelSEEDHandlerObjectConfig)) {
        for(my $i=0; $i<@{$FIG_Config::ModelSEEDHandlerDatabaseConfig}; $i++) {
            my $dbConfigFile = $FIG_Config::ModelSEEDHandlerDatabaseConfig->[$i];
            $self->_databaseConfigParser($dbConfigFile);
        }
        for(my $i=0; $i<@{$FIG_Config::ModelSEEDHandlerObjectConfig}; $i++) {
            my $objectConfigFile = $FIG_Config::ModelSEEDHandlerObjectConfig->[$i];
            $self->_objectConfigParser($objectConfigFile);
        }
    }
    # Load user specified configuration files
    if(defined($databaseConfigFiles) && ref($databaseConfigFiles) eq "ARRAY") {
        for(my $i=0; $i<@$databaseConfigFiles; $i++) {
            my $dbConfigFile = $databaseConfigFiles->[$i];
            $self->_databaseConfigParser($dbConfigFile);
        }
    } elsif (defined($databaseConfigFiles)) {
        $self->_databaseConfigParser($databaseConfigFiles);
    }
    # Load user specified configuration objects
    if(defined($objectConfigFiles) && ref($objectConfigFiles) eq "ARRAY") {
        for(my $i=0; $i<@$databaseConfigFiles; $i++) {
            my $dbConfigFile = $databaseConfigFiles->[$i];
            _objectConfigParser($dbConfigFile);
        }
    } elsif (defined($objectConfigFiles)) {
        _objectConfigParser($objectConfigFiles);
    }
    # Check for objects with missing databases
    $self->_disableUnresolvedObjects();
    return $self;
} 

sub get_objects {
    my $self = shift;
    return $self->get(@_);
}

sub get {
    # Basic getter, has syntax 
    # Arg 1:
    #   [ obj1Kind, obj2Kind, ... ] where objKind is string
    #   objKind
    # Arg 2:
    #   { obj2Kind.attr => "searchString", obj1Kind.attr => "searchString", ...}
    #   { obj2Kind.attr => ["a", "b", "c", ...] } << WHERE IN STATEMENT
    my ($self, $arg1, $arg2) = @_;  
    if (not defined($arg2)) {
        # Getting by object id
        my $id = $arg1;
        my $objectType = $self->_getObjectTypeFromId($id); 
        return $self->get($objectType, {'id' => $id});
    }
    
    if (ref($arg1) eq "ARRAY") {
        # Join of multiple things
    } else {
        # Single query
        my $objects = $self->object($arg1);
        if(@$objects > 1) {
            #... 
        } else {
            my $objectMeta = $objects->[0];
            Confess("Unknown object $arg1!") unless defined($objectMeta);
            # Get the object package if it is not BaseObject
            my $objectPackage = $objectMeta->{'objectType'};
            if ($objectPackage ne "ModelSEEDObject") {
                {
                    $objectPackage = "ModelSEEDObject::".$objectPackage;
                    no strict;
                    eval("require $objectPackage");
                    die("Failure on require of $objectPackage: $@") if ($@);
                }
            }
            my $objectDatabaseTable = $objectMeta->{'objectTable'};
            # Get the database, load package
            my $dbName = $objectMeta->{'objectDatabase'};
            my $dbMeta = $self->database($dbName);
            Confess("Unknown database $dbName!") unless(@$dbMeta > 0) ;
            my $results = [];
            for(my $i=0; $i<@$dbMeta; $i++) {
                # Try retriving database handler from cache
                my $digest = md5($dbMeta->[$i]->{'databaseBackendConfig'});
                my $db = $self->{'databaseConnections'}->{$digest};
                warn "Got cache $digest!" if(defined($db));
                unless(defined($db)) {
                    # Otherwise create new handler for this database
                    my $dbPackage = "ModelSEEDHandler::" . $dbMeta->[$i]->{'databaseBackendType'}; # ModelSEEDPPO 
                    {
                        no strict;
                        eval("require $dbPackage");
                        die("Failure on require of $dbPackage: $@") if ($@);
                    }
                    $db = $dbPackage->new($dbMeta->[0]->{'databaseBackendConfig'});
                    $self->{'databaseConnections'}->{$digest} = $db;
                }
                # Now get the results, cast to objectPackage if not BaseObject
                push(@$results, $db->get($objectDatabaseTable, $arg2));
            }
            unless($objectPackage eq "ModelSEEDObject") {
                for(my $i=0; $i<@$results; $i++) {
                    $results->[$i] = $objectPackage->new($results->[$i]);
                }
            }
            return $results; 
        }
    }
        
}


sub databases {
    my ($self) = @_;
    return $self->{'databases'};
}

sub database {
    my ($self, $databaseName, $a) = @_;
    my $rtv = [];
    if(defined($self->{'databases'}->{$databaseName})) {
        push(@$rtv, $self->{'databases'}->{$databaseName});
    }
    if (defined($a) && $a =~ /a/) { # all
        if (defined($self->{'disabledDatabases'}->{$databaseName})) {
            push(@$rtv, @{$self->{'disabledDatabases'}->{$databaseName}});
        } 
    }
    return $rtv;
}

sub objects {
    my ($self) = @_;
    return $self->{'objects'};
}

sub object {
    my ($self, $objectName, $a) = @_;
    my $rtv = [];
    if(defined($self->{'objects'}->{$objectName})) {
        push(@$rtv, @{$self->{'objects'}->{$objectName}});
    }
    if(defined($a) && $a =~ /a/ &&
        defined($self->{'disabledObjects'}->{$objectName})) {
        push(@$rtv, @{$self->{'disabledObjects'}->{$objectName}});
    }
    return $rtv;
}


sub _databaseConfigParser {
    my ($self, $configFile) = @_;
    if(-e $configFile) {
        open(my $configFH, "<", $configFile);
        unless(defined($configFH)) {
            warn "Unable to open configuration file: $configFile";
            return;
        }
        while ( <$configFH> ) {
            chomp $_;
            my @arr = split(/\t/, $_);
            unless ( @arr !=  4 ) {
                warn "Unable to load object from configuration: $_";
                return;
            }
            my $result = {
                'databaseName' => $arr[0],
                'databaseBackendType' => $arr[1],
                'databaseBackendConfig' => $arr[2],
                'databaseDescription' => $arr[3],
            };
            if(defined($self->{'databases'}->{$arr[0]})) {
                if(not defined($self->{'disabledDatabases'}->{$arr[0]})) {
                    $self->{'disabledDatabases'}->[$arr[0]] = [];
                }
                push(@{$self->{'disabledDatabases'}->{$arr[0]}}, $result);
            }
            $self->{'databases'}->{$arr[0]} = $result; 
                
        }
        close($configFH);
    } else {
        warn "Unable to find configuration file: $configFile\n";
    } 
}

sub _objectConfigParser {
    my ($self, $configFile) = @_;
    if(defined($configFile) && -e $configFile) {
        open(my $configFH, "<", $configFile);
        unless(defined($configFH)) {
            warn "Unable to open configuration file: $configFile";
            return;
        }
        while ( <$configFH> ) {
            chomp $_;
            my @arr = split(/\t/, $_);
            unless ( @arr !=  6 ) {
                warn "Unable to load object from configuration: $_";
                return;
            }
            my $result = {
                'objectName' => $arr[0],
                'objectTable' => $arr[1],
                'objectIdRegex' => $arr[2],
                'objectType'    => $arr[3],
                'objectDatabase' => $arr[4]    || "",
                'objectDescription' => $arr[5] || "",
            };
            if(defined($self->{'objects'}->{$arr[0]})) {
                push(@{$self->{'objects'}->{$arr[0]}}, $result);
            } else {
                $self->{'objects'}->{$arr[0]} = [$result];
            }
        }
        close($configFH);
    } else {
        warn "Unable to find configuration file: $configFile\n";
    } 
}

sub _disableUnresolvedObjects {
    my ($self) = @_;
    foreach my $key (keys %{$self->{'objects'}}) {
        my $objectConfigs = $self->{'objects'}->{$key};
        my @toRemove;
        for(my $i=0; $i<@$objectConfigs; $i++) {
            my $dbName = $objectConfigs->[$i]->{'objectDatabase'};
            if(not defined($self->{"databases"}->{$dbName})) {
                warn "Unknown database reference for object: $key, removing from database.\n";
                push(@toRemove, $i);
            }
        }
        my $offset = 0;
        for(my $i=0; $i<@toRemove; $i++) {
            my $index = $toRemove[$i];
            if(not defined($self->{'disabledObjects'}->{$key})) {
                $self->{'disabledObjects'}->{$key} = [];
            }
            $self->{'objects'}->{$key}->[$index + $offset]->{'disabled'} = 1;
            push(@{$self->{'disabledObjects'}->{$key}},
                $self->{'objects'}->{$key}->[$index + $offset]);
            splice(@{$self->{'objects'}->{$key}}, $index + $offset, 1);
            $offset--;
        }
    }
}

sub _getObjectTypeFromId {
    my ($self, $id) = @_;
    my @types;
    foreach my $key (keys %{$self->{'objects'}}) {
        my $object = $self->object($key);
        for(my $i=0; $i<@$object; $i++) {
            my $regex = $object->[$i]->{'objectIdRegex'}; 
            if($regex eq '') {
                next;
            }
            if($id =~ m/$regex/) {
                push(@types, $key);
                last;
            }
        }
    }
    if (@types > 1) {
        warn "Multiple object types returned for id: $id\n".
            "Got types: ". join(', ', @types) . "\n";
    }
    return $types[0];
}
    

1;
