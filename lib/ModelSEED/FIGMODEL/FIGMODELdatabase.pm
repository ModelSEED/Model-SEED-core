use strict;
use ModelSEED::FIGMODEL::FIGMODELdata;
use File::Path qw(make_path);
use File::NFSLock;
#use CHI;
use DBMaster;
use Storable;

package ModelSEED::FIGMODEL::FIGMODELdatabase;
use Fcntl qw/:DEFAULT :seek :flock LOCK_EX LOCK_NB/;
use Scalar::Util qw(weaken);
use Carp qw(cluck);
use Data::Dumper;

=head1

=head2 Introduction
Module for loading and altering data in the model database.  There
will be a local and remote version of this module.  The remote
version will be implemented using the server technology.

=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELdatabase = FIGMODELdatabase->new(); Description:
	This is the constructor for the FIGMODELdatabase object.
=cut

sub new {
	my ($class,$config, $figmodel) = @_;
	my $self;
    $self->{_config} = $config;
	$self->{"_figmodel"}->[0] = $figmodel;
    weaken($self->{"_figmodel"}->[0]);
	bless $self;
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELdatabase->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel { return $_[0]->{"_figmodel"}->[0]; }

=head3 config
    If key is supplied, return key's value || undef. Otherwise,
    return complete config as hash ref.
=cut
sub config {
    return $_[0]->{_config}->{$_[1]} || undef if(@_ > 1);
    return $_[0]->{_config};
}

=head2 Cache Commands
There are three internal cache commands: getCache($key) setCache($key,
$val) and clearCache($key). These do what you would expect. You
must supply keys with a prefix "type:$type" where $type would be
accepted by get_object($type, {}).  clearCache($key) will "invalidate"
all entries with prefix "type:$type".

Configuration for the Cache is passed into FIGMODELdatabase under
the parameter 'CacheSettings' and are the parameters used to configure
a standard 'use CHI; CHI->new($config);' call.

Implementation notes:
1) By default, we use a RawMemory cache. Right now any other format
will cause Serialization problems as we are passing in CODE refs.
E.g. PPO, FIGMODELdata. We need to fix this to use other caches.

2) CHI keys are not garunteed to be stored the same way they are
given.  This would normally make namespaced keys (and invalidating
a whole set of keys) pretty hard. The _cache_namespace() function
avoids this.
=cut

sub _cache {
    my ($self) = @_;
    return $self->{_cache} if(defined($self->{_cache}));
    my $settings = ($self->config('CacheSettings')->[0]) ?
        $self->config('CacheSettings') : { driver => 'RawMemory', global => 1 };
    return $self->{_cache} = CHI->new(%$settings);
}

sub _cache_namespace {
    my ($self, $key, $update) = @_;
    my $ns = undef;
    if($key =~ /(^[^:]+:[^:]+)/) {
        my $type = $1;
        $ns = $self->_cache->get($type);
        if(!defined($ns) || $update) {
            $ns = $self->_cache->set($type, "namespace:".time().":");
        }
    }
    return $ns;
}
    
sub getCache {
    my ($self, $key) = @_;
    my $ns = $self->_cache_namespace($key);
    return undef unless(defined($ns));
    return $self->_cache()->get($ns.$key);
}

sub setCache {
    my ($self, $key, $val) = @_;
    my $ns = $self->_cache_namespace($key);
    return undef unless(defined($ns));
    return $self->_cache()->set($ns.$key, $val);
}

sub clearCache {
    my ($self, $key) = @_;
    my $ns = $self->_cache_namespace($key,"update");
}

=head3 get_object_manager
Definition:
	databasehandle:database handle for input object type = FIGMODELdatabase->get_object_manager(string::type);
Description:
=cut
sub get_object_manager {
	my ($self,$type) = @_;
	#Checking on the status of the database and returned undefined if the status is zero
    my $config = $self->config("PPO_tbl_".$type);
	if (!defined($config)) { 
        ModelSEED::FIGMODEL::FIGMODELERROR("Unable to find database configuration for $type");
	} elsif($config->{status}->[0] == 0) {
        ModelSEED::FIGMODEL::FIGMODELERROR("Database for $type has status=0, disabled!");
    } 
    my $db_type = $config->{type}->[0];
	#Checking if a database connection exists for the desired object type
	if (!defined($self->{_dbhandles}->{$config->{name}->[0]}) || # test for database disconnect if PPO
        ($db_type eq "PPO" && !$self->{_dbhandles}->{$config->{name}->[0]}->db_handle()->ping)) {
		if (defined($self->{_dbhandles}->{$config->{name}->[0]}) && $db_type eq "PPO") {
			$self->{_dbhandles}->{$config->{name}->[0]}->DESTROY();
		}
        if ($db_type eq 'PPO') {
            # Either have a mySQL database (has user, port and socket) 
            # Or just have database host =  filename, which indicates SQLite
            if( defined($config->{host}) && defined($config->{user}) &&
                defined($config->{port}) && defined($config->{socket})) {
                my $temp = DBMaster->new(
                    -database => $config->{name}->[0],
                    -host     => $config->{host}->[0],
                    -user     => $config->{user}->[0],
                    -password => $config->{password}->[0],
                    -port     => $config->{port}->[0],
                    -socket   => $config->{"socket"}->[0]);
                $self->{_dbhandles}->{$config->{name}->[0]} = $temp;
            } elsif( defined($config->{host}->[0]) && -f $config->{host}->[0] ) {
                my $temp = DBMaster->new(-database => $config->{host}->[0], -backend => 'SQLite');
                $self->{_dbhandles}->{$config->{name}->[0]} = $temp;
            } else {
                ModelSEED::FIGMODEL::FIGMODELERROR("Unable to find database configuration for " . $config->{name}->[0] . " " . $config->{table}->[0]);
            }
        } elsif ($db_type eq 'FIGMODELTable') {
            my $params = {
                filename  => $config->{name}->[0],
                delimiter => $config->{delimiter}->[0] || undef,
                headings => $config->{headings} || undef,
                itemDelimiter => $config->{itemDelimiter}->[0] || undef,
                headingLine => $config->{headingLine} || undef,
                hashColumns => $config->{hashColumns} || undef,
                prefix => $config->{prefix}->[0] || undef,
            };
            if(-e $config->{name}->[0]) {
                $self->{_dbhandles}->{$config->{name}->[0]} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($params);
            } else {
                $self->{_dbhandles}->{$config->{name}->[0]} = ModelSEED::FIGMODEL::FIGMODELTable->new($params);
            }
        } else {
            ModelSEED::FIGMODEL::FIGMODELERROR("Unknown database type $db_type for object type ".$config->{name}->[0]);
        }
	}
    if($db_type eq "PPO") {
        my $table = $config->{table}->[0];
        return $self->{_dbhandles}->{$config->{name}->[0]}->$table() || undef;
    } elsif($db_type eq "FIGMODELTable") {
        return $self->{_dbhandles}->{$config->{name}->[0]} || undef;
    }
}

=head3 freezeFileSyncing
Definition:
   FIGMODELdatabase->freezeFileSyncing(string::type)
Description:
=cut
sub freezeFileSyncing {
    my ($self, $type) = @_;
    my $config = $self->config("PPO_tbl_".$type);
    my $db_type = $config->{type}->[0];
    if ($db_type eq 'FIGMODELTable') {
    	my $objMgr = $self->get_object_manager($type);
    	$objMgr->{_freezeFileSyncing} = 1;
    }
}

=head3 unfreezeFileSyncing
Definition:
   FIGMODELdatabase->unfreezeFileSyncing(string::type)
Description:
=cut
sub unfreezeFileSyncing {
    my ($self, $type) = @_;
    my $config = $self->config("PPO_tbl_".$type);
    my $db_type = $config->{type}->[0];
    if ($db_type eq 'FIGMODELTable') {
    	my $objMgr = $self->get_object_manager($type);
    	delete $objMgr->{_freezeFileSyncing};
    	$objMgr->save();
    }
}

=head3 get_config
Definition:
   {} = FIGMODELdatabase->get_config(string::type)
Description:
    Returns the config associated with a particular object type.
=cut
sub get_config {
    my ($self, $type) = @_;
    $type = $self->config("PPO_tbl_".$type);
    return $type || undef;
}

=head3 create_object
Definition:
	PPOobject:object created by the input hash of attributes = FIGMODELdatabase->create_object(string::type,{}:attributes);
Description:
=cut
sub create_object {
	my ($self,$type,$attributes) = @_;
	my $objMgr = $self->get_object_manager($type);
    $self->clearCache($type);
	return $objMgr->create($attributes);
}

=head3 get_object
Definition:
	PPOobject:first object matching specified type and query = FIGMODELdatabase->get_object(string::type,{}:query);
Description:
=cut
sub get_object {
	my ($self,$type,$query) = @_;
	my $objs = $self->get_objects($type, $query);
    return undef unless(defined($objs->[0]));
	return $objs->[0];
}
=head3 sudo_get_object
Definition:
	PPOobject:first object matching specified type and query = FIGMODELdatabase->sudo_get_object(string::type,{}:query);
Description:
=cut
sub sudo_get_object {
	my ($self,$type,$query) = @_;
	my $objs = $self->sudo_get_objects($type,$query);
    return undef unless(defined($objs->[0]));
	return $objs->[0];
}
=head3 sudo_get_objects
Definition:
	[PPOobject]:objects matching specified type and query = FIGMODELdatabase->sudo_get_objects(string::type,{}:query);
Description:
	Obtains objects with no caching and no rights management. Needed for processig objects before permissions have been established or adjusted.
=cut
sub sudo_get_objects {
	my ($self,$type,$query) = @_;
	my $objMgr = $self->get_object_manager($type);
	return $objMgr->get_objects($query);
}

=head3 get_objects
Definition:
	[PPOobject]:objects matching specified type and query = FIGMODELdatabase->get_object(string::type,{}:query);
Description:
=cut
sub get_objects {
	my ($self,$type,$query,$cacheBehavior) = @_;
	# By default, the cache behavior is not to use the cache;
	# cache is used if cacheBehavior = 1; cache is reset if
	# cacheBehavior = 2; ONLY cache is used if cacheBehavior = 3;
    $cacheBehavior = $self->config("CacheBehavior")->[0] || 0 unless(defined($cacheBehavior));
    $cacheBehavior = 0;#Will fix once we got CHI working properly.
    $query = {} unless(defined($query));
    my %queryCpy = %$query;
	my $cacheKey = "type:$type".
        join(":", map { $_ = $_.":".$queryCpy{$_} } keys %queryCpy);
    if($cacheBehavior == 2) {
        $self->clearCache($cacheKey);
    }
    my $objs;
    $objs = $self->getCache($cacheKey) unless($cacheBehavior == 0);
    return $objs if($cacheBehavior == 3 || defined($objs));
	$objs = $self->sudo_get_objects($type,$query);
	if (defined($objs->[0]) && defined($self->config("objects with rights")->{$type})) {
		my $finalObjs;
		for (my $i=0; $i < @{$objs}; $i++) {
            my $rights = $self->get_object_rights($objs->[$i], $type);
            if(keys %$rights > 0) {
				push(@{$finalObjs}, ModelSEED::FIGMODEL::FIGMODELdata->new($objs->[$i], $self->figmodel(), $type));
			}
		}
		$objs = $finalObjs;
	}
    $self->setCache($cacheKey,$objs) unless($cacheBehavior == 0);
	return $objs;
}
=head3 change_permissions
Definition:
	void FIGMODELdatabase->change_permissions({
		objectID => string,
		permission => string,
		user => string,
		type => string
	});
Description:
=cut
sub change_permissions {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[
		"objectID",
		"permission",
		"user",
		"type"
	],{});
	my $permObj = $self->get_object("permissions",{
		id => $args->{objectID},
		user => $args->{user},
		type => $args->{type}
	});
	if (!defined($permObj)) {
		$self->create_object("permissions",{
			id => $args->{objectID},
			user => $args->{user},
			permission => $args->{permission},
			type => $args->{type}
		});
	} elsif (lc($args->{permission}) eq "none") {
		$permObj->delete();
	} else {
		$permObj->permission($args->{permission});
	}
}

=head3 delete_object
Definition:
	{} = FIGMODELdatabase->delete_object({
		type => string,
		object => PPO:object,
		recursive => 0/1
	});
Description:
=cut
sub delete_object {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["type","object"],{recursive => 0});
	#Checking for recursive deletion
	if ($args->{recursive} == 1) {
		my $linkObjs = $self->get_objects("dblinks",{refEntity => $args->{type}});
		for (my $i=0; $i < @{$linkObjs}; $i++) {
			my $function = $linkObjs->[$i]->refAttribute();
			my $objs = $self->get_objects($linkObjs->[$i]->linkEntity(),{$linkObjs->[$i]->linkAttribute() => $args->{object}->$function()});
			for (my $j=0; $j < @{$objs}; $j++) {
				print $linkObjs->[$i]->linkEntity()."\n";
				$self->delete_object({type=>$linkObjs->[$i]->linkEntity(),object => $objs->[$j],recursive=>1});
			}
		}
	}
	#Deleting the rights
	if ($self->has_rights($args->{type}) == 1) {
		my $objs = $self->get_objects("right",{data_type => $args->{type},data_id => $args->{object}->_id()});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();
		}
	}
	$args->{object}->delete();
	$self->clearCache("type:".$args->{type});
}
=head3 has_rights
Definition:
	0/1 = FIGMODELdatabase->has_rights(string:type)
Description:
=cut
sub has_rights {
    return 0 if(@_ < 2);
    return (defined($_[0]->config("object with rights")->{$_[1]})) ? 1 : 0;
}
=head3 get_object_hash
Definition:
	{string:attributes => PPO:retrieved objects} = FIGMODELdatabase->get_object_hash({
		type => string,
		attribute => string,
		parameters => {},
		useCache => 0/1,
	})
Description:
=cut
sub get_object_hash {
	my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,["type","attribute"],{
    	parameters => {},
    	useCache => $self->config("CacheBehavior")->[0] || 0,
    });
    $args->{useCache} = 0;#TODO change this once caching is fixed
	my $hash;
    my @paramKeysCopy = keys %{$args->{parameters}};
    my $cacheKey = "type:".$args->{type}.":method:get_object_hash:attribute:";
    $cacheKey .= (ref($args->{attribute}) eq "CODE") ? "CODE" : $args->{attribute};
    $cacheKey .= join(":", map { $_ = $_ . ":" . $args->{parameters}->{$_} } @paramKeysCopy);
    if($args->{useCache} != 0) {
		$hash = $self->getCache($cacheKey);
        return $hash if(defined($hash));
	}
    my $objs = $self->get_objects($args->{type},$args->{parameters},$args->{useCache});
    my $function = $args->{attribute};	
    if (defined($objs) && ref($function) eq 'CODE') {
        for (my $i=0; $i < @{$objs}; $i++) {
            my $key = &$function($objs->[$i]);
            if(defined($key)) {
                push(@{$hash->{$key}}, $objs->[$i]);
            }
        }
    } elsif(defined($objs)) {
        for (my $i=0; $i < @{$objs}; $i++) {
            if (defined($objs->[$i]->$function())) {
                push(@{$hash->{$objs->[$i]->$function()}},$objs->[$i]);
            }
        }
        if(defined($hash) && $args->{useCache} != 0) {
            $self->getCache($cacheKey,$hash);
        }
    }
	return $hash;
}

sub get_object_rights {
    my ($self, $object, $type) = @_;
    my $login = $self->figmodel()->user();
    my $user = $self->figmodel()->userObj();
    my $rights = {};
    if(defined($self->config("model administrators")->{$login})) {
        return { admin => 1};
    }
    if(not defined($self->config("objects with rights")->{$type})) {
        return { view => 1};
    }
    if ($object->owner() eq $login) {
    	return { admin => 1};
    }
    if (defined($object->attributes()->{public}) && $object->public() eq 1) {
        $rights->{view} = 1;
    }
    if($login ne "PUBLIC" && defined($user) && defined($object->attributes()->{id})) {
        my $permission = $self->get_object("permissions", { type => $type, id => $object->id(), user => $login});
        if(defined($permission)) {
            $rights = {};
            $rights->{$permission->permission()} = 1;
        }
    }
    return $rights;
}
                
=head3 check_out_new_id
Definition:
	databasehandle:database handle for input object type = FIGMODELdatabase->check_out_new_id(string::type);
Description:
=cut
sub check_out_new_id {
	my ($self,$type) = @_;
	#If this is an sqllite database
	my $data;
	if (!defined($self->config("PPO_tbl_id")->{user})) {
		my $idobj = $self->get_object("id",{object => $type});
		$data = [$idobj->id()];
		$idobj->id($data->[0]+1);
		$data->[1] = $idobj->prefix();
		$data->[2] = $idobj->digits();
	} else {
		if (!defined($self->{_dbhandles}->{id})) {
			$self->{_dbhandles}->{id} = DBMaster->new(-database => $self->config("PPO_tbl_id")->{name}->[0],
	    	                   -host     => $self->config("PPO_tbl_id")->{host}->[0],
	                           -user     => $self->config("PPO_tbl_id")->{user}->[0],
	                           -password => $self->config("PPO_tbl_id")->{password}->[0],
	                           -port     => $self->config("PPO_tbl_id")->{port}->[0],
	                           -socket   => $self->config("PPO_tbl_id")->{"socket"}->[0]);
		}
		#Get the id
	    my $database = $self->config("PPO_tbl_id")->{name}->[0];
		$data = $self->{_dbhandles}->{id}->backend()->dbh->selectrow_arrayref('select id,prefix,digits from '.
	        $database.'.CURRENTID where (object = "'.$type.'") for update;');
		#Iterate the ID
		$self->{_dbhandles}->{id}->backend()->dbh->do('UPDATE '.
	        $database.'.CURRENTID SET id = id + 1 WHERE (object = "'.$type.'");');
	    $self->{_dbhandles}->{id}->backend()->dbh->commit();
	}
 	#Creating the id
 	while (length($data->[0]) < $data->[2]) {
 		$data->[0] = "0".$data->[0];
 	}
 	return $data->[1].$data->[0];
}

=head3 is_type
Definition:
	(0/1) = FIGMODELdatabase->is_type(string::type);
Description:
	Checks if the input string is an object type in the database. "1" for yes, "0" for no.
=cut
sub is_type {
	my ($self,$type) = @_;
	return 1 if(defined($self->config("object types")->{$type}));
    return 0;
}

=head3 known_types
Definition:
    [string] = FIGMODELdatabase->known_types();
Description:    
    Returns a list of the known types for the current database
    instantiation.
=cut
sub known_types {
    return [keys %{$_[0]->config("object types")}];
}

=head3 load_multiple_column_file
Definition:
	[[string]] = FIGMODELdatabase->load_multiple_column_file(string::filename,string::delimiter);
Description:
	Parses the two dimensional file specified by the input filename
=cut
sub load_multiple_column_file {
	my ($self,$Filename,$Delimiter) = @_;
	my $DataArrayRefArrayRef = [];
	open (my $fh, "<", $Filename) ||
        ModelSEED::FIGMODEL::FIGMODELERROR("Unable to open File $Filename: $@");
    while (my $Line = <$fh>) {
        chomp($Line);
		my $Data = [$Line];
		if (length($Delimiter) > 0) {
			$Data = [split(/$Delimiter/,$Line)];
	    }
		push(@{$DataArrayRefArrayRef},$Data);
	}
	close($fh);
	return $DataArrayRefArrayRef;
}

=head3 load_single_column_file
Definition:
	[string] = FIGMODELdatabase->load_single_column_file(string::filename,string::delimiter);
Description:
	Parses the single column file specified by the input filename
=cut
sub load_single_column_file {
	my ($self,$Filename,$Delimiter) = @_;
    $Delimiter = "" unless(defined($Delimiter));
    my $DataArrayRef = $self->load_multiple_column_file($Filename, $Delimiter);
    return [map { $_->[0] } @$DataArrayRef];
}

=head3 genericLock
Definition:
	FIGMODELdatabase->genericLock(string::lock name);
Description:
	This function locks the database for a given lock name.
=cut
sub genericLock {
	my($self,$name,$type,$secondsTimeout,$maxTimeout) = @_;
    $type = "NB" unless(defined($type));
	my $ltdir = $self->config("locked table list filename")->[0];
    File::Path::make_path $ltdir if (!-d $ltdir);
    my $lock = File::NFSLock->new("$ltdir$name.lock",$type,$secondsTimeout,$maxTimeout);
    return ($lock) ? $self->{_locks}->{$name} = $lock : undef;
}

=head3 genericUnlock
Definition:
	FIGMODELdatabase->genericUnlock(string::lock name);
Description:
	This function unlocks the database for a given lock name.
=cut
sub genericUnlock {
	my($self,$name) = @_;
    my $lock = $self->{_locks}->{$name};
    if(defined($lock)) {
       $lock->uncache;
       $lock->unlock();
       delete $self->{_locks}->{$name};
    } 
	my $ltdir = $self->config("locked table list filename")->[0];
	unlink("$ltdir$name.lock") if(-e "$ltdir$name.lock");
	return 1;
}

=head3 create_table_prototype

Definition:
	FIGMODELTable::table = FIGMODELdatabase->create_table_prototype(string::table);
Description:
	Returns a empty FIGMODELTable with all the metadata associated with the input table name
	
=cut
sub create_table_prototype {
	my ($self,$TableName) = @_;
	
	#Checking if the table definition exists in the FIGMODELconfig file
	if (!defined($self->config($TableName))) {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:Definition not found for ".$TableName);
		return undef;
	}
	#Checking that this is a database table
	if (!defined($self->config($TableName)->{tabletype}) || $self->config($TableName)->{tabletype}->[0] ne "DatabaseTable") {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:".$TableName." is not a database table!");
		return undef;
	}
	if (!defined($self->config($TableName)->{delimiter})) {
		$self->config($TableName)->{delimiter}->[0] = ";";
	}
	if (!defined($self->config($TableName)->{itemdelimiter})) {
		$self->config($TableName)->{itemdelimiter}->[0] = "|";
	}
	my $prefix;
	if (defined($self->config($TableName)->{prefix})) {
		$prefix = join("\n",@{$self->config($TableName)->{prefix}});
	}
	my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new($self->config($TableName)->{columns},$self->config("Reaction database directory")->[0].$self->config($TableName)->{filename}->[0],$self->config($TableName)->{hashcolumns},$self->config($TableName)->{delimiter}->[0],$self->config($TableName)->{itemdelimiter}->[0],$prefix);
	return $tbl;
}

=head3 get_table

Definition:
	FIGMODELTable::table = FIGMODELdatabase->get_table(string::table);
Description:
	Returns the requested FIGMODELTable
	
=cut
sub get_table {
	my ($self,$TableName,$NoCache) = @_;
	
	if ((!defined($NoCache) || $NoCache == 0) && defined($self->{_cache}->{$TableName})) {
		return $self->{_cache}->{$TableName};
	}
	#Checking if the table definition exists in the FIGMODELconfig file
	if (!defined($self->config($TableName))) {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:Definition not found for ".$TableName);
		return undef;
	}
	#Checking that this is a database table
	if (!defined($self->config($TableName)->{tabletype}) || $self->config($TableName)->{tabletype}->[0] ne "DatabaseTable") {
		$self->figmodel()->error_message("FIGMODELdatabase:create_table_prototype:".$TableName." is not a database table!");
		return undef;
	}
	if (!defined($self->config($TableName)->{headingline})) {
		$self->config($TableName)->{headingline}->[0] = 0;
	}
	if (!defined($self->config($TableName)->{columndelimiter})) {
		$self->config($TableName)->{columndelimiter}->[0] = "\t";
	} elsif ($self->config($TableName)->{columndelimiter}->[0] eq "SC") {
		$self->config($TableName)->{columndelimiter}->[0] = ";";
	}
	$self->config($TableName)->{delimiter}->[0] = $self->config($TableName)->{columndelimiter}->[0];
	if (!defined($self->config($TableName)->{itemdelimiter})) {
		$self->config($TableName)->{itemdelimiter}->[0] = "|";
	}
	#Loading the table
	$self->{_cache}->{$TableName} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->config("Reaction database directory")->[0].$self->config($TableName)->{filename}->[0],$self->config($TableName)->{delimiter}->[0],$self->config($TableName)->{itemdelimiter}->[0],$self->config($TableName)->{headingline}->[0],$self->config($TableName)->{hashcolumns}); 
	return $self->{_cache}->{$TableName};
}

=head3 print_array_to_file
Definition:
	FIGMODELdatabase->print_array_to_file(string::filename,[string::file lines],0/1::append);
Description:
	saving array to file
=cut
sub print_array_to_file {
	my ($self,$filename,$arrayRef,$Append) = @_;
    my $writeParam = ($Append) ? ">>" : ">";
    open(my $fh, $writeParam, $filename) || die("Could not open file: $filename, $@");
    print $fh join("\n", @$arrayRef);
    close($fh);
}

=head3 print_multicolumn_array_to_file
Definition:
	FIGMODELdatabase->print_multicolumn_array_to_file(string::filename,[string::file lines],string::delimiter);
Description:
	saving array to file
=cut
sub print_multicolumn_array_to_file {
	my ($self,$Filename,$ArrayRef,$Delimiter) = @_;
    my @ArrayRefCp = @$ArrayRef;
    $self->print_array_to_file($Filename,
        [map { $_ = join($Delimiter, @$_) } @ArrayRefCp]);
}

=head3 updateCompoundFilesFromDb
definition:
    for each passed compound id, updates the compound files to the current database settings.
    Returns a hash of compound id => boolean indicating success or failure.
	(hashref:compound id => boolean status) = figmodel->updatecompoundFilesFromDb([string]:rxnids);
=cut
sub updateCompoundFilesFromDb {
    my ($self, $cpds) = @_;
    my $cpdStatus = {};
    foreach my $id (@$cpds) {
        my $filename = $self->config("compound directory")->[0].$id;
        my $obj = $self->get_object('compound', {'id' => $id});
        warn $filename;
        if(not defined($obj)) {
            $cpdStatus->{$id} = 0;
            next;
        }
        my ($names, $formula, $mass, $charge, $cues, $stringcode, $dblinks) = undef;
        (defined($obj->name())) ? $names = [$obj->name()] : $names = [];
        push(@$names, map { $_->alias() }
            @{$self->get_objects('cpdals', { 'type' => 'name', 'COMPOUND' => $id})});
        $names = join("\t", @$names);
        $formula = $obj->formula(); 
        unless(defined($names) && defined($formula)) {
            $cpdStatus->{$id} = 0;
            next;
        }            
        $mass = $obj->mass();
        $charge = $obj->charge();
        $cues = $obj->structuralCues();
        $stringcode = $obj->stringcode();
        $dblinks = {'ARGONNE' => $id};
        foreach my $alias ('KEGG') {
            my $als = $self->get_object('cpdals', { 'type' => $alias, 'COMPOUND' => $id});
            if(defined($als)) {
                $dblinks->{$alias} = $als->alias();
            }
        }
        $dblinks = join("\t", map { $_ = $_.":".$dblinks->{$_} } keys %$dblinks);
        my $existingValues = {}; # a hashlist
        if(-e $filename) {
            open(my $fh,"<", $filename) || die($@);
            while(<$fh>) {
                my @parts = split(/\t/, $_);
                map { chomp $_ } @parts;
                $existingValues->{shift @parts} = @parts;
            }
            close($fh);
        }
        my $file_keys = ["DATABASE", "NAME", "FORMULA", "MASS", "CHARGE", "STRUCTURAL_CUES", "STRINGCODE", "DBLINKS"];
        my $dbValues = {"DATABASE" => $id, "NAME" => $names, "FORMULA" => $formula, "MASS" => $mass,
                         "CHARGE" => $charge, "STRUCTURAL_CUES" => $cues, "STRINGCODE" => $stringcode,
                         "DBLINKS" => $dblinks};       
        open(my $fh, ">", $filename) || die($@);
        foreach my $file_key (@$file_keys) {
            if(defined($dbValues->{$file_key})) {
                print $fh $file_key."\t".$dbValues->{$file_key}."\n";
            } elsif(defined($existingValues->{$file_key})) {
                print $fh $file_key."\t".$existingValues->{$file_key}."\n";
            }
        }
        close($fh);
        system("chmod 664 $filename");
        $cpdStatus->{$id} = 1;
    }
    return $cpdStatus;
}           
=head3 updateReactionFilesFromDb
definition:
    for each passed reaction id, updates the reaction files to the current database settings.
    Returns a hash of reaction id => boolean indicating success or failure.
	(hashref:compound id => boolean status) = figmodel->updateReactionFilesFromDb([string]:rxnids);
=cut
sub updateReactionFilesFromDb {
    my ($self, $rxns) = @_;
    my $rxnStatus = {};
    foreach my $id (@$rxns) {
        my $filename = $self->{"reaction directory"}->[0].$id;
        my $obj = $self->get_object('compound', {'id' => $id});
        if(not defined($obj)) {
            $rxnStatus->{$id} = 0;
            next;
        }
        my $keyMappings = { 'MINORG ENTRY' => 'id', 'NAME' => 'name', 'DEFINITION' => 'definition',
                            'EQUATION' => 'equation', 'ENZYME' => 'enzyme', 'DELTAG' => 'deltaG',
                            'DELTAGERR' => 'deltaGErr', 'STRUCTURAL_CUES' => 'structuralCues',
                            'THERMODYNAMIC REVERSIBILITY' => 'thermoReversibility', };
        my $keyOrder = [ 'MINORG ENTRY','NAME','DEFINITION','EQUATION','ENZYME','DELTAG',
                          'DELTAGERR','STRUCTURAL_CUES','THERMODYNAMICREVERSIBILITY',];
        my $existingValues = {}; # a hashlist
        if(-e $filename) {
            open(my $fh,"<", $filename);
            while(<$fh>) {
                my @parts = split(/\t/, $_);
                map { chomp $_ } @parts;
                $existingValues->{shift @parts} = @parts;
            }
            close($fh);
        }
        open(my $fh, ">", $filename);
        # do most of data from keyMappings
        foreach my $file_key (@$keyOrder) {
            my $value = undef;
            my $db_key = $keyMappings->{$file_key};
            if(defined($db_key) && defined($value = $obj->$db_key())) {
                print $fh $file_key."\t".$value."\n";
            } elsif(defined($existingValues->{$file_key})) {
                print $fh $file_key."\t".join("\t", @{$existingValues->{$file_key}})."\n";
            }
        }
        # now do reaction aliases
        my $dblinks = {'ARGONNE' => $id};
        foreach my $alias ('KEGG') {
            my $als = $self->get_objects('rxnals', { 'type' => $alias, 'COMPOUND' => $id});
            if(defined($als)) {
                $dblinks->{$alias} = $als->alias();
            }
        }
        $dblinks = join("\t", map { $_ = $_.":".$dblinks->{$_} } keys %$dblinks);
        print $fh "DBLINKS\t".$dblinks if(defined($dblinks));
        close($fh);
        system("chmod 664 $filename");
        $rxnStatus->{$id} = 1;
    }
    return $rxnStatus;
}

sub updateReactionDbFromFiles {
    my ($self, $rxns) = @_;
    my $rxnStatus = {};
    foreach my $id (@$rxns) {
        my $filename = $self->figmodel()->{"reaction directory"}->[0].$id;
        unless( -e $filename ) {
            $rxnStatus->{$id} = 0;
            next;
        }
        my $rxnObj = $self->get_object('reaction', { 'id' => $id });
        unless(defined($rxnObj)) {
            $rxnStatus->{$id} = 0;
            next;
        }
        my $keyMappings = { 'DELTAG' => 'deltaG', 'DELTAGERR' => 'deltaGErr', 
                            'THERMODYNAMIC REVERSIBILITY' => 'thermoReversibility', };
        open(my $fh, "<", $filename);
        while(<$fh>) {
            chomp $_;
            my @parts = split(/\t/, $_);
            next unless(defined($keyMappings->{$parts[0]}));
            next unless(@parts > 1 && $parts[1] ne "");
            my $key = shift @parts;
            my $value = shift @parts;
            my $dbKey = $keyMappings->{$key};
            if(defined($dbKey)) {
                $rxnObj->$dbKey($value); 
            }
        }
        close($fh);
        $rxnStatus->{$id} = 1;
    }
    return $rxnStatus;
}

sub updateCompoundDbFromFiles {
    my ($self, $cpds) = @_;
    my $cpdStatus = {};
    foreach my $id (@$cpds) {
        my $filename = $self->config("compound directory")->[0].$id;
        unless( -e $filename ) {
            $cpdStatus->{$id} = 0;
            next;
        }
        my $cpdObj = $self->get_object('compound', { 'id' => $id });
        unless(defined($cpdObj)) {
            $cpdStatus->{$id} = 0;
            next;
        }
        my $keyMappings = { 'DELTAG' => 'deltaG', 'DELTAGERR' => 'deltaGErr', 
                            'MASS' => 'mass', 'CHARGE' => 'charge',};
        open(my $fh, "<", $filename);
        while(<$fh>) {
            chomp $_;
            my @parts = split(/\t/, $_);
            next unless(defined($keyMappings->{$parts[0]}));
            next unless(@parts > 1 && $parts[1] ne "");
            my $key = shift @parts;
            my $value = shift @parts;
            my $dbKey = $keyMappings->{$key};
            if(defined($dbKey)) {
                $cpdObj->$dbKey($value); 
            }
        }
        close($fh);
        $cpdStatus->{$id} = 1;
    }
    return $cpdStatus;
}

=head3 addnewcompoundfilestodb 
definition:
    looks at all compound files in the compound directory. for any compound that is
    not already in the database, this function reads the compound file and loads it into
    the database. this returns a hash of compound id to status, which can be "added",
    "exists", "failed" or "obsolete". if a string "scope" is passed, the compound is created with that
    scope. this is useful when creating custom compounds for a single imported model.

	(hashref:compound status) = figmodeldatabase>addnewcompoundfilestodb([string]:cpdids, string:scope);
=cut
sub addNewCompoundFilesToDb {
    my ($self, $cpdsToAdd, $importScope) = @_;
    my $cpdStatus = {};
    foreach my $cpdid (@$cpdsToAdd) {
        my $filename = $self->config("compound directory")->[0].$cpdid;
        next unless ( -e $filename);
        my $cpds = $self->get_objects('compound', {'id' => $cpdid});
        if (@$cpds > 0) {
            $cpdStatus->{$cpdid} = "exists";
            next;
        } else {
            # don't add compound files that are listed as obsolete in the database
            my $obsoletecpd = $self->get_objects('cpdals', {'type' => 'obsolete', 'alias' => $cpdid });
            if(@$obsoletecpd > 0) {
                $cpdStatus->{$cpdid} = "obsolete";
                next;
            }
            my $attrhash = { 'database' => "", 'stringcode' => "",
                            'deltag' => "", 'deltagerr' => "",
                            'name' => "", 'formula' => "",
                            'mass' => "", 'charge' => "",
                            'pka' => "", 'pkb' => "",
                            'structural_cues' => "", 'dblinks' => "",
                          };
            open(my $cpdFH, "<", $filename);
            unless(defined($cpdFH)) {
                $cpdStatus->{$cpdid} = "failed fh"; 
                next;
            };
            while(<$cpdFH>) {
                chomp $_;
                my @parts = split(/\t/, $_);
                next unless(defined($attrhash->{$parts[0]}));
                next unless(@parts > 1 && $parts[1] ne "");
                my $key = shift @parts;
                if ( $key eq 'database' || $key eq 'charge' || $key eq 'mass' || $key eq 'formula') {
                    $attrhash->{$key} = $parts[0]; # single item in these attributes
                } else {
                    $attrhash->{$key} = join(';', @parts); # attribute can be in list
                }
            }
            # now copy into new hash that has keys that the databse knows about
            my $keymappings = { 'database' => 'id', 'pkb' => 'pkb', 'deltag' => 'deltag',
                              'name' => 'name', 'structural_cues' => 'structuralcues',
                              'pka' => 'pka', 'formula' => 'formula', 'charge' => 'charge',
                               'stringcode' => 'stringcode', 'deltagerr' => 'deltagerr', 'dblinks' => 'dblinks' };
            my $databaseHash = {};
            foreach my $key (keys %$keymappings) {
                # remove keys that haven't been defined at the same time
                if ( not defined($attrhash->{$key}) || $attrhash->{$key} eq "") {
                    next;
                }
                $databaseHash->{$keymappings->{$key}} = $attrhash->{$key};
            }
            unless(defined($databaseHash->{'name'}) && defined($databaseHash->{'id'})) {
                $cpdStatus->{$cpdid} = "failed attr";
                next;
            }
            # fix the name, build list of name / searchname hashes to add to compound_alias
            my $primaryname = undef;
            my $compoundNamesAlias = [];
            foreach my $name (split(/;/, $databaseHash->{'name'})) {
                if ( length $name < 32 && not defined($primaryname)) {
                    $primaryname = $name;
                }
                push(@$compoundNamesAlias, { 'compound' => $databaseHash->{'id'},
                                             'type' => 'name', 'alias' => $name });
            }
            if ( not defined($primaryname)) {
                $primaryname = (split(/;/, $databaseHash->{'name'}))[0];
            }
            $databaseHash->{'name'} = $primaryname;
            my $compoundSearchNamesAlias = [];
            for(my $k=0; $k<@$compoundNamesAlias; $k++) {
                my @names = $self->figmodel()->convert_to_search_name($compoundNamesAlias->[$k]->{'alias'});
                for my $name (@names) {
                    push(@$compoundSearchNamesAlias, { 'compound' => $databaseHash->{'id'},
                        'type' => 'searchname', 'alias' => $name });
                }
            }
            # add the dblink alias
            if(defined($databaseHash->{'dblinks'})) {
                foreach my $link (split(/;/, $databaseHash->{'dblinks'})) {
                    my ($type, $value) = split(/:/, $link);
                    push(@$compoundNamesAlias, { 'compound' => $databaseHash->{'id'},
                            'type' => $type, 'alias' => $value });
                }
                delete $databaseHash->{'dblinks'};
            }
            # combine all aliases
            push(@$compoundNamesAlias, @$compoundSearchNamesAlias);
            # set other things that need to be done:
            # creationDate, modificationDate, owner, user, scope 
            my $currTime = time;
            $databaseHash->{'creationDate'} = $currTime;
            $databaseHash->{'modificationDate'} = $currTime;
            $databaseHash->{'owner'} = 'master';
            $databaseHash->{'users'} = 'all';
            if(defined($importScope)) {
                $databaseHash->{'scope'} = $importScope;
            }
            my $createdObject = $self->create_object('compound', $databaseHash);
            unless(defined($createdObject)) {
                $cpdStatus->{$cpdid} = "failed nc";
                close($cpdFH);
                next;
            }
            # Now create the alias links
            foreach my $aliasHash (@$compoundNamesAlias) {
                $self->create_object('cpdals', $aliasHash);
            }
            $cpdStatus->{$cpdid} = "created";
            close($cpdFH);
        }
    }
    return $cpdStatus;
}


=head3 addNewReactionFilesToDB 
Definition:
    Looks at all reaction files in the reaction directory. For any reaction that is
    not already in the database, this function reads the reaction file and loads it into
    the database. This returns a hash of reaction ID to status, which can be "added",
    "exists", "failed" or "obsolete". If a string "scope" is passed, the reaction is created with that
    scope. This is useful when creating custom reactions for a single imported model.

	(hashref:reaction status) = FIGMODELdatabase>addNewReactionFilesToDB([string]:rxnIds, string:scope);
=cut
sub addNewReactionFilesToDB {
    my ($self, $rxnsToAdd, $importScope) = @_;
    my $rxnStatus = {};
    foreach my $rxnId (@$rxnsToAdd) {
        my $Filename = $self->figmodel()->{"reaction directory"}->[0].$rxnId;
        next unless ( -e $Filename);
        my $rxns = $self->get_objects('reaction', {'id' => $rxnId});
        if (@$rxns > 0) {
            $rxnStatus->{$rxnId} = "exists";
            next;
        } else {
            # Don't add compound files that are listed as obsolete in the database
            my $obsoleteRxn = $self->get_objects('rxnals', {'type' => 'obsolete', 'alias' => $rxnId });
            if(@$obsoleteRxn > 0) {
                $rxnStatus->{$rxnId} = "obsolete";
                next;
            }
            my $attrHash = { 'MINORG ENTRY' => "", 'NAME' => "",
                             'DEFINITION' => "", 'EQUATION' => "",
                             'ENZYME' => "", 'PATHWAY' => "",
                             'DBLINKS' => "", 'DELTAG' => "",
                             'DELTAGERR' => "", 'STRUCTURAL_CUES' => "",
                             'THERMODYNAMIC REVERSIBILITY' => "", 
                          };
            open(my $rxnFH, "<", $Filename);
            unless(defined($rxnFH)) {
                $rxnStatus->{$rxnId} = "failed fh"; 
                next;
            };
            while(<$rxnFH>) {
                chomp $_;
                my @parts = split(/\t/, $_);
                next unless(defined($attrHash->{$parts[0]}));
                next unless(@parts > 1 && $parts[1] ne "");
                my $key = shift @parts;
                if ( $key eq 'MINORG ENTRY' || $key eq 'DELTAG' || $key eq 'GELTAGERR' || 
                     $key eq 'EQUATION' || $key eq 'DEFINITION' ) {
                    $attrHash->{$key} = $parts[0]; # single item in these attributes
                } else {
                    $attrHash->{$key} = join(';', @parts); # attribute can be in list
                }
            }
            # now copy into new hash that has keys that the databse knows about
            my $keyMappings = { 'MINORG ENTRY' => 'id', 'NAME' => 'name', 'DEFINITION' => 'definition',
                                'EQUATION' => 'equation', 'ENZYME' => 'enzyme', 'DELTAG' => 'deltaG',
                                'DELTAGERR' => 'deltaGErr', 'STRUCTURAL_CUES' => 'structurealCues',
                                'THERMODYNAMIC REVERSIBILITY' => 'thermoReversibility', 'DBLINKS' => 'DBLINKS',
                              };
            my $databaseHash = {};
            foreach my $key (keys %$keyMappings) {
                # remove keys that haven't been defined at the same time
                if ( not defined($attrHash->{$key}) || $attrHash->{$key} eq "") {
                    next;
                }
                $databaseHash->{$keyMappings->{$key}} = $attrHash->{$key};
            }
            $databaseHash->{'code'} = $attrHash->{'EQUATION'}; # code is same as equation
            unless(defined($databaseHash->{'name'}) && defined($databaseHash->{'id'}) &&
                defined($databaseHash->{'equation'})) {
                $rxnStatus->{$rxnId} = "failed attr";
                next;
            }
            my $reactionNamesAlias = [];
            # add the DBLINK alias
            if(defined($databaseHash->{'DBLINKS'}) && defined($importScope)) {
                foreach my $link (split(/;/, $databaseHash->{'DBLINKS'})) {
                    my ($importScope, $value) = split(/:/, $link);
                    push(@$reactionNamesAlias, { 'REACTION' => $databaseHash->{'id'},
                            'type' => $importScope, 'alias' => $value });
                }
                delete $databaseHash->{'DBLINKS'};
            }
            # set other things that need to be done:
            # creationDate, modificationDate, owner, user, scope 
            my $currTime = time;
            $databaseHash->{'creationDate'} = $currTime;
            $databaseHash->{'modificationDate'} = $currTime;
            $databaseHash->{'owner'} = 'master';
            $databaseHash->{'users'} = 'all';
            $databaseHash->{'thermoReversibility'} = "<=>" if (not defined($databaseHash->{'thermoReversibility'}));
            if(defined($importScope)) {
                $databaseHash->{'scope'} = $importScope;
            }
            my $createdObject = $self->create_object('reaction', $databaseHash);
            unless(defined($createdObject)) {
                $rxnStatus->{$rxnId} = "failed nc";
                close($rxnFH);
                next;
            }
            # Now create the alias links
            foreach my $aliasHash (@$reactionNamesAlias) {
                $self->create_object('rxnals', $aliasHash);
            }
            $rxnStatus->{$rxnId} = "created";
            close($rxnFH);
        }
    }
    return $rxnStatus;
}

=head3 ppo_rows_to_table
Definition:
    FIGMODELTable_Object = FIGMODELdatabase->ppo_rows_to_table({table_config}, [rows])
Description:
    Converts an array ref of ppo objects into a FIGMODELTable object. The first argument
    is a hashref of configuration for the table (if {}) is provided, this generally does the
    right thing. Returns the FIGMODELTable object.
=cut
sub ppo_rows_to_table {
    my ($self, $config, $rows) = @_;
    my ($fh, $filename) = File::Temp::tempfile();
    close($fh);
    $config = { 'filename' =>  $config->{'filename'} || $filename,
                'hash_headings' => $config->{'hash_headings'} || [],
                'delimiter' => $config->{'delimiter'} || ';',
                'item_delimiter' => $config->{'item_delimiter'} || '|',
                'prefix' => $config->{'prefix'} || '',
                'heading_remap' => $config->{'heading_remap'} || undef,
              };
    # Set headings unless already defined
    unless(defined($config->{'headings'})) {
        my $all_keys = {};
        foreach my $row (@$rows) {
            my $attrHash = $row->attributes();
            map { $all_keys->{$_} = 1; } keys %$attrHash;
        }
        my @headings = keys %$all_keys;
        $config->{'headings'} = \@headings;
    }
    # Map existing ppo headings to themselves unless we defined a map
    unless(defined($config->{'heading_remap'})) {
        $config->{'heading_remap'} = { map { $_ => $_ } @{$config->{'headings'}} };
    }
    # Now create the table object
    my $table = ModelSEED::FIGMODEL::FIGMODELTable->new({
        headings => [sort values %{$config->{'heading_remap'}}],
        filename => $config->{'filename'},
        hashHeadings => $config->{'hash_headings'},
        delimiter => $config->{'delimiter'},
        itemdelimiter => $config->{'item_delimiter'},
        prefix => $config->{'prefix'},
        });
    # split $obj->key() on item_delimiter if item_delimiter is defined
    my $item_del = $config->{'item_delimiter'};
    my $re = qr/\Q$item_del/ unless(!defined($item_del) || $item_del eq '');
    # Now add the rows, testing if the row object has each attribute
    foreach my $row (@$rows) {
        my %rowHash = map { $_ => [] } values %{$config->{'heading_remap'}};
        foreach my $key (keys %{$config->{'heading_remap'}}) {
            my $value = $config->{'heading_remap'}->{$key};
            if($row->_knows_attribute($key) && defined($row->$key())) {
               push(@{$rowHash{$value}}, ($re) ? split($re, $row->$key()) : $row->$key());
            }
        }
        $table->add_row(\%rowHash);
    }
    return $table;
}

1;
