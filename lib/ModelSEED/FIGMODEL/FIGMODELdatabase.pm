use strict;
use ModelSEED::FIGMODEL::FIGMODELdata;
use DBMaster;

package ModelSEED::FIGMODEL::FIGMODELdatabase;
use Fcntl qw/:DEFAULT :seek :flock/;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1

=head2 Introduction
Module for loading and altering data in the model database.
There will be a local and remote version of this module.
The remote version will be implemented using the server technology.

=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELdatabase = FIGMODELdatabase->new(); Description:
	This is the constructor for the FIGMODELdatabase object.
=cut

sub new {
	my ($class,$DatabaseDirectory,$figmodel) = @_;
	my $self;
	$self->{"_database root directory"}->[0] = $DatabaseDirectory;
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
sub figmodel {
	my ($self) = @_;
	return $self->{"_figmodel"}->[0];
}

=head3 fail
Definition:
	-1 = FIGMODEL->fail();
Description:
	Standard return for failed functions.
=cut
sub fail {
	my ($self) = @_;
	return $self->figmodel()->fail();
}

=head3 success
Definition:
	1 = FIGMODEL->success();
Description:
	Standard return for successful functions.
=cut
sub success {
	my ($self) = @_;
	return $self->figmodel()->success();
}

=head3 config
Definition:
	ref::key value = FIGMODELdatabase->config(string::key);
Description:
	Trying to avoid using calls that assume configuration data is stored in a particular manner.
	Call this function to get file paths etc.
=cut

sub config {
	my ($self,$key) = @_;

	return $self->figmodel()->config($key);
}

=head3 error_message
Pass through to the error_message function in FIGMODEL
=cut
sub error_message {
	my ($self,$args) = @_;
	$args->{"package"} = "FIGMODELdatabase";
    return $self->figmodel()->new_error_message($args);
}
=head3 getCache
Pass through to the getCache function in FIGMODEL
=cut
sub getCache {
	my ($self,$key) = @_;
	return $self->figmodel()->getCache({package=>"FIGMODELdatabase",id=>$self->figmodel()->user(),key=>$key});
}
=head3 setCache
Pass through to the setCache function in FIGMODEL
=cut
sub setCache {
	my ($self,$key,$data) = @_;
	return $self->figmodel()->setCache({package=>"FIGMODELdatabase",id=>$self->figmodel()->user(),key=>$key,data=>$data});
}
=head3 clearAllMatchingCache
Pass through to the clearAllMatchingCache function in FIGMODEL
=cut
sub clearAllMatchingCache {
	my ($self,$key) = @_;
	return $self->figmodel()->clearAllMatchingCache({package=>"FIGMODELdatabase",id=>$self->figmodel()->user(),key=>$key});
}
=head3 get_object_manager
Definition:
	databasehandle:database handle for input object type = FIGMODELdatabase->get_object_manager(string::type);
Description:
=cut
sub get_object_manager {
	my ($self,$type) = @_;
	#Checking on the status of the database and returned undefined if the status is zero
	if (!defined($self->config("PPO_tbl_".$type)) || $self->config("PPO_tbl_".$type)->{status}->[0] == 0) {
		return undef;
	}
    my $config = $self->config("PPO_tbl_".$type);
    my $db_type = $config->{type}->[0];
	#Checking if a database connection exists for the desired object type
	if (!defined($self->{_dbhandles}->{$config->{name}->[0]}) || # test for database disconnect if PPO
        ($db_type eq "PPO" && !$self->{_dbhandles}->{$config->{name}->[0]}->db_handle()->ping)) {
		if (defined($self->{_dbhandles}->{$config->{name}->[0]}) && $db_type eq "PPO") {
			$self->figmodel()->error_message("Database connection with ".$config->{name}->[0]." lost.");
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
            return undef;
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
	if (!defined($objMgr)) {
		return undef;	
	}
	return $objMgr->create($attributes);
}

=head3 get_object
Definition:
	PPOobject:first object matching specified type and query = FIGMODELdatabase->get_object(string::type,{}:query);
Description:
=cut
sub get_object {
	my ($self,$type,$query) = @_;
	my $objs = $self->get_objects($type,$query);
	if (!defined($objs->[0])) {
		return undef;	
	}
	return $objs->[0];
}
=head3 get_objects
Definition:
	[PPOobject]:objects matching specified type and query = FIGMODELdatabase->get_object(string::type,{}:query);
Description:
=cut
sub get_objects {
	my ($self,$type,$query,$cacheBehavior) = @_;
	#By default, the cache behavior is not to use the cache; cache is used if cacheBehavior = 1; cache is reset if cacheBehavior = 2; ONLY cache is used if cacheBehavior = 3; 
	if (!defined($cacheBehavior)) {
		$cacheBehavior = 0;
	}
	my $cacheKey = "get_objects:".$type;
	if ($cacheBehavior > 0) {
		foreach my $paramKey (keys(%{$query})) {
			$cacheKey .= ":".$paramKey.":".$query->{$paramKey};
		}
	}
	if (($cacheBehavior == 1 || $cacheBehavior == 3) && defined($self->getCache($cacheKey))) {
		return $self->getCache($cacheKey);
	}
	if ($cacheBehavior == 3) {
		return undef;	
	}
	my $objMgr = $self->get_object_manager($type);
	if (!defined($objMgr)) {
		return undef;	
	}
	my $objs = $objMgr->get_objects($query);
	if (defined($objs->[0]) && defined($self->figmodel()->config("objects with rights")->{$type})) {
		my $finalObjs;
		for (my $i=0; $i < @{$objs}; $i++) {
            my $rights = $self->get_object_rights($objs->[$i], $type);
            if(keys %$rights > 0) {
				push(@{$finalObjs}, ModelSEED::FIGMODEL::FIGMODELdata->new($objs->[$i], $self->figmodel(), $type));
			}
		}
		$objs = $finalObjs;
	}
	if ($cacheBehavior > 0) {
		$self->setCache($cacheKey,$objs);
	}
	return $objs;
}
=head3 clear_object_cache
Definition:
	FIGMODELdatabase->clear_object_cache(string::type,{}:query);
Description:
=cut
sub clear_object_cache {
	my ($self,$type,$query) = @_;
	my $cacheKey = "get_objects:".$type;
	foreach my $paramKey (keys(%{$query})) {
		$cacheKey .= ":".$paramKey.":".$query->{$paramKey};
	}
	$self->clearAllMatchingCache($cacheKey);
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
	if (defined($args->{error})) {return $self->error_message({function => "delete_object",args => $args});}
	print "DELETING ".$args->{type}." ".$args->{object}->_id()."\n";
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
			print "DELETING right: ".$objs->[$i]->scope()->name()." ".$objs->[$i]->data_type()." \n";
			$objs->[$i]->delete();
		}
	}
	$args->{object}->delete();
	$self->clear_object_cache($args->{type});
}
=head3 has_rights
Definition:
	0/1 = FIGMODELdatabase->has_rights(string:type)
Description:
=cut
sub has_rights {
	my ($self,$type) = @_;
	if (defined($self->figmodel()->config("objects with rights")->{$type})) {
		return 1;	
	}
	return 0;
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
    	useCache => 0
    });
	if (defined($args->{error})) {return $self->error_message({function => "get_object_hash",args => $args});}
	my $cacheBehavior = 0;
	if ($args->{useCache} == 1) {
		$cacheBehavior = 1;
	}
	my $hash;
	my $cacheKey;
	if ($cacheBehavior > 0) {
		$cacheKey = "get_object_hash:".$args->{type}.":".$args->{attribute}.":";
		foreach my $keyVal (keys(%{$args->{parameters}})) {
			$cacheKey .= $keyVal.":".$args->{parameters}->{$keyVal};
		}
		$hash = $self->getCache($cacheKey);
	}
	if (!defined($hash)) {
		my $objs = $self->get_objects($args->{type},$args->{parameters},$args->{useCache},$cacheBehavior);
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
		}
		
	}
	if (defined($hash) && $cacheBehavior > 0) {
		$self->setCache($cacheKey,$hash);
	}
	return $hash;
}

sub get_object_rights {
    my ($self, $object, $type) = @_;
    my $login = $self->figmodel()->user();
    my $user = $self->figmodel()->userObj();
    my $rights = {};
    if(defined($self->figmodel()->config("model administrators")->{$login})) {
        return { admin => 1};
    }
    if(not defined($self->figmodel()->config("objects with rights")->{$type})) {
        return { view => 1};
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
	my $data = $self->{_dbhandles}->{id}->backend()->dbh->selectrow_arrayref('select id,prefix,digits from '.
        $database.'.CURRENTID where (object = "'.$type.'") for update;');
	#Iterate the ID
	$self->{_dbhandles}->{id}->backend()->dbh->do('UPDATE '.
        $database.'.CURRENTID SET id = id + 1 WHERE (object = "'.$type.'");');
    $self->{_dbhandles}->{id}->backend()->dbh->commit();
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
	if (defined($self->figmodel()->config("object types")->{$type})) {
		return 1;
	}
	return 0;
}

=head3 set_cache
Definition:
	FIGMODELdatabase->set_cache(string::key,ref::data);
Description:
	Caching data
=cut
sub set_cache {
	my ($self,$key,$data) = @_;

	$self->{CACHE}->{$key} = $data;
}

=head3 get_cache
Definition:
	ref::data = FIGMODELdatabase->get_cache(string::key);
Description:
	Caching data
=cut

sub get_cache {
	my ($self,$key) = @_;

	return $self->{CACHE}->{$key};
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
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			my $Data = [$Line];
			if (length($Delimiter) > 0) {
				$Data = [split(/$Delimiter/,$Line)];
			}
			push(@{$DataArrayRefArrayRef},$Data);
		}
		close(INPUT);
	} else {
		$self->figmodel()->error_message("FIGMODELdatabase->load_multiple_column_file(".$Filename.",".$Delimiter."): could not load file!");
	}
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
	if (!defined($Delimiter)) {
		$Delimiter = "";	
	}
	my $DataArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			if (length($Delimiter) > 0) {
				my @Data = split(/$Delimiter/,$Line);
				$Line = $Data[0];
			}
			push(@{$DataArrayRef},$Line);
		}
		close(INPUT);
	} else {
		$self->figmodel()->error_message("FIGMODELdatabase->load_single_column_file(".$Filename.",".$Delimiter."): could not load file!");
	}
	return $DataArrayRef;
}

=head3 load_table
Definition:
	FIGMODELTable = FIGMODELdatabase->load_table(string::filename,string::delimiter,string::item delimiter,int::heading line,[string]::hash columns);
Description:
	Uses the input arguments to load the specified table.
=cut
sub load_table {
	my ($self,$Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns) = @_;
	if (!-e $Filename) {
		return undef;	
	}
	return ModelSEED::FIGMODEL::FIGMODELTable::load_table($Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns);
}

=head3 create_table
Definition:
	FIGMODELTable = FIGMODELdatabase->create_table(string::table name);
Description:
	Creating table based on name
=cut
sub create_table {
	my ($self,$TableName) = @_;
	my $NewTable;
	if ($TableName eq "BIOMASS TABLE") {
		if (!-e $self->config("Reaction database directory")->[0]."masterfiles/BiomassReactionTable.txt") {
			$NewTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["DATABASE","REACTANTS","EQUATION","ORGANISMS","ESSENTIAL REACTIONS"],$self->config("Reaction database directory")->[0]."masterfiles/BiomassReactionTable.txt",["DATABASE","REACTANTS","ORGANISMS"],";","|",undef);
		}
	}
	if (defined($NewTable)) {
		$NewTable->save();
	}
	return $NewTable;
}

=head3 genericLock
Definition:
	FIGMODELdatabase->genericLock(string::lock name);
Description:
	This function locks the database for a given lock name.
=cut
sub genericLock {
	my($self,$name) = @_;
	#Making the directory if it does not already exist
	my $ltdirs = $self->config("locked table list filename");
	my $ltdir = $ltdirs->[0];
	if (!-d $ltdir) {
	    system("mkdir ".$ltdir);
	}
	#Creating the lock file
	my $lock = $ltdir.$name.".lock";
	while(-e $lock) {
		sleep(2);
	}
	$self->print_array_to_file($lock,["LOCKED"]);
	return $self->figmodel()->success();
}

=head3 genericUnlock
Definition:
	FIGMODELdatabase->genericUnlock(string::lock name);
Description:
	This function unlocks the database for a given lock name.
=cut
sub genericUnlock {
	my($self,$name) = @_;
	#Deleting the lock file
	my $ltdirs = $self->config("locked table list filename");
	my $ltdir = $ltdirs->[0];
	my $lock = $ltdir.$name.".lock";
	unlink($lock);
	return $self->figmodel()->success();
}

=head3 ManageFileLocking
Definition:
	FIGMODELdatabase->ManageFileLocking($FileHandle,$Operation,$UseFcntl);
Description:
	This function handles all file locking for the FIGMODELdatabase package. Possible values for $Operation are:
	LOCK_EX: exclusive lock for writing
	LOCK_SH: shared lock for simultaneous reading
	LOCK_UN: removes the lock
Example:
=cut

sub ManageFileLocking {
    my($self,$FileHandle,$Operation,$UseFcntl) = @_;

	#Qualifying the filehandle
    $FileHandle = FIGMODEL::qualify_to_ref($FileHandle, caller());

	#Implementing the lock using flock
    if (!defined($UseFcntl) || $UseFcntl == 0) {
		if ($Operation == LOCK_EX) {
			my $arg = pack("ssll", F_WRLCK, SEEK_SET, 0, 0);
			my $rc = fcntl($FileHandle, F_SETLKW, $arg);
			return $rc;
		} elsif ($Operation == LOCK_SH) {
			my $arg = pack("ssll", F_RDLCK, SEEK_SET, 0, 0);
			my $rc = fcntl($FileHandle, F_SETLKW, $arg);
			return $rc;
		} elsif ($Operation == LOCK_UN) {
			my $arg = pack("ssll", F_UNLCK, SEEK_SET, 0, 0);
			my $rc = fcntl($FileHandle, F_SETLKW, $arg);
			return $rc;
		}
	} else {
		return CORE::flock($FileHandle, $Operation);
	}
}

=head3 update_row
Definition:
	status(1/0) = FIGMODELdatabase->update_row(string::table,{string=>[string]}::row,string::unique key);
Description:
	Updates the input row in the specified table
=cut
sub update_row {
	my ($self,$tablename,$row,$key) = @_;

	#Checking that a table and query have been provided
	if (!defined($tablename) || !defined($row) || !defined($key) || !defined($row->{$key}->[0])) {
		$self->figmodel()->error_message("FIGMODELdatabase:update_row:Must provide table, key, and value.");
		return $self->figmodel()->fail();
	}

	#Getting the database table:may be pulled from a flat file or from SQL
	my $table = $self->LockDBTable($tablename);
	if (!defined($table)) {
		$self->figmodel()->error_message("FIGMODEL:update_row:".$tablename." not found in database.");
		return $self->figmodel()->fail();
	}

	#Querying to see if the row is already in the table
	$row->{"last_modified"}->[0] = time();
	my $ExistingRow = $table->get_row_by_key($row->{$key}->[0],$key);
	if (defined($ExistingRow)) {
		$table->replace_row($ExistingRow,$row);
	} else {
		$table->add_row($row);
	}

	#Saving updated table to database
	$table->save();
	$self->UnlockDBTable($tablename);

	return $self->figmodel()->success();
}

=head3 save_table
Definition:
	FIGMODELdatabase->save_table(FIGMODELTable::table);
Description:
	Saves the input table to file
=cut

sub save_table {
	my ($self,$table,$filename,$delimiter,$itemdelimiter,$prefix) = @_;

	$table->save($filename,$delimiter,$itemdelimiter,$prefix);
}

=head3 check_user
Definition:
	(1/0) = FIGMODELdatabase->check_user([string]::authorized user list,string::user ID);
Description:
	Checks to see if the input user is authorized to view an object based on the authorized user list 
=cut
sub check_user {
	my ($self,$users,$user) = @_;
	
	for (my $i=0; $i < @{$users}; $i++) {
		if (lc($users->[$i]) eq "all" || $users->[$i] eq $user)	{
			return 1;
		}
	}
	
	return 0;
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
	if (!defined($self->figmodel()->config($TableName))) {
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
	if (!defined($self->figmodel()->config($TableName))) {
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

=head3 GetProtectVariable
Definition:
	string::variable value = FIGMODELdatabase->GetProtectVariable(string::variable name,0/1::delete variable);
Description:
	getting the value of the specified protected variable
=cut
sub GetProtectVariable {
	my ($self,$VariableName,$DeleteVariable) = @_;
	if (defined($self->{"PROTECTED VARIABLES"}->{$VariableName}->[0])) {
		my $Variable = $self->{"PROTECTED VARIABLES"}->{$VariableName}->[0];
		if (defined($DeleteVariable) && $DeleteVariable == 1) {
			delete $self->{"PROTECTED VARIABLES"}->{$VariableName};
		}
		return $Variable;
	}
	return undef;
}

=head3 SetProtectedVariable
Definition:
	FIGMODELdatabase->SetProtectedVariable(string::variable name,string::variable value);
Description:
	setting the value of the specified protected variable
=cut
sub SetProtectedVariable {
	my ($self,$VariableName,$VariableValue) = @_;
	$self->{"PROTECTED VARIABLES"}->{$VariableName}->[0] = $VariableValue;
}

=head3 GetDBModelGenes
Definition:
	FIGMODELTable = FIGMODELdatabase->GetDBModelGenes(string::model id);
Description:
	returns a FIGMODELTable with the model genes
=cut
sub GetDBModelGenes {
	my ($self,$modelID) = @_;

	#Getting model data
	my $model = $self->figmodel()->get_model($modelID);
	if (!defined($model)) {
		print STDERR "FIGMODELdatabase:GetDBModelGenes:Could not find model ".$modelID." in database!";
		return undef;
	}
	return $model->feature_table();
}

=head3 save_cpd_translation
Definition:
	FIGMODELdatabase->save_cpd_translation({string::model ID => string::cpd id},string::model id);
Description:
	saving the compound translation file for a model
=cut
sub save_cpd_translation {
	my ($self,$tanslation,$model) = @_;

	my $filename = $self->figmodel()->config("Translation directory")->[0]."CpdTo".$model.".txt";
	my $filedata;
	my @cpds = keys(%{$tanslation});
	for (my $i=0; $i < @cpds; $i++) {
		push(@{$filedata},$tanslation->{$cpds[$i]}."\t".$cpds[$i]);
	}
	$self->print_array_to_file($filename,$filedata);
}

=head3 save_rxn_translation
Definition:
	FIGMODELdatabase->save_rxn_translation({string::model ID => string::cpd id},string::model id);
Description:
	saving the reaction translation file for a model
=cut
sub save_rxn_translation {
	my ($self,$tanslation,$model) = @_;

	my $filename = $self->figmodel()->config("Translation directory")->[0]."RxnTo".$model.".txt";
	my $filedata;
	my @rxns = keys(%{$tanslation});
	for (my $i=0; $i < @rxns; $i++) {
		push(@{$filedata},$tanslation->{$rxns[$i]}."\t".$rxns[$i]);
	}
	$self->print_array_to_file($filename,$filedata);
}

=head3 print_array_to_file
Definition:
	FIGMODELdatabase->print_array_to_file(string::filename,[string::file lines],0/1::append);
Description:
	saving array to file
=cut
sub print_array_to_file {
	my ($self,$filename,$arrayRef,$Append) = @_;

	if (defined($Append) && $Append == 1) {
		open (OUTPUT, ">>$filename");
	} else {
		open (OUTPUT, ">$filename");
	}
	foreach my $Item (@{$arrayRef}) {
		if (length($Item) > 0) {
			print OUTPUT $Item."\n";
		}
	}
	close(OUTPUT);
}

=head3 print_multicolumn_array_to_file
Definition:
	FIGMODELdatabase->print_multicolumn_array_to_file(string::filename,[string::file lines],string::delimiter);
Description:
	saving array to file
=cut
sub print_multicolumn_array_to_file {
	my ($self,$Filename,$ArrayRef,$Delimiter) = @_;

	if (open (OUTPUT, ">$Filename")) {
		foreach my $Item (@{$ArrayRef}) {
			if (@{$Item} > 0) {
				print OUTPUT join($Delimiter,@{$Item})."\n";
			}
		}
		close(OUTPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
}

=head3 mg_model_data
Definition:
	MGRAST::Metadata::meta data for model = FIGMODELdatabase->mg_model_data(string::metagenome id);
Description:
	Returns the metadata object for the specified genome id
=cut
sub mg_model_data {
	my($self,$genome_id) = @_;

	if (!defined($self->{_mg_model_data})) {
		require MGRAST::Metadata;
		my $mddb = MGRAST::Metadata->new();
		my $results = $mddb->_handle()->Search->get_objects({});
		foreach (@$results){
			$self->{_mg_model_data}->{$_->job()->genome_id} = $_;
		}
	}

	return $self->{_mg_model_data}->{$genome_id};
}

=head3 ConsolidateMediaFiles
Definition:
	FIGMODELdatabase->ConsolidateMediaFiles();
Description:
	This function consolidates all of the various media formulations in the Media directory into a single file.
	This file is formated as a FIGMODELTable, and it is used by the mpifba code to determine media formulations.
	The file will be in the masterfiles directory names: MediaTable.txt.
=cut
sub ConsolidateMediaFiles {
	my ($self) = @_;

	#Creating a new media table
	my $names = $self->config("Reaction database directory");
	my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["NAME","NAMES","COMPOUNDS","MAX","MIN"],$names->[0]."masterfiles/MediaTable.txt",["NAME","COMPOUNDS"],";","|",undef);
	#Loading media formulations into table
	my $mediadir = $self->config("Media directory");
	my @Filenames = glob($mediadir->[0]."*");
	foreach my $Filename (@Filenames) {
		if ($Filename !~ m/Test/ && $Filename =~ m/\/([^\/]+)\.txt/) {
			my $MediaName = $1;
			my $MediaFormulation = $self->load_table($Filename,";","",0,undef);
			my ($CompoundList,$NameList,$MaxList,$MinList);
			if (defined($MediaFormulation)) {
				for (my $i=0; $i < $MediaFormulation->size(); $i++) {
					if ($MediaFormulation->get_row($i)->{"VarName"}->[0] =~ m/cpd\d\d\d\d\d/) {
						push(@{$CompoundList},$MediaFormulation->get_row($i)->{"VarName"}->[0]);
						my $CompoundData = $self->get_compound($MediaFormulation->get_row($i)->{"VarName"}->[0]);
						if (defined($CompoundData) && defined($CompoundData->{NAME}->[0])) {
							push(@{$NameList},$CompoundData->{NAME}->[0]);
						}
						push(@{$MinList},$MediaFormulation->get_row($i)->{"Min"}->[0]);
						push(@{$MaxList},$MediaFormulation->get_row($i)->{"Max"}->[0]);
					}
				}
				$MediaTable->add_row({"NAME" => [$MediaName],"NAMES" => $NameList,"COMPOUNDS" => $CompoundList,"MAX" => $MaxList,"MIN" => $MinList});
			} else {
				print STDERR "Failed to load media file ".$Filename."\n";
			}	
		}
	}

	#Saving the table
	$MediaTable->save();

	return $MediaTable;
}

=head3 FillInMissingMediaFiles
Definition:
	FIGMODELdatabase->FillInMissingMediaFiles();
Description:
=cut

sub FillInMissingMediaFiles {
	my($self) = @_;
	
	my $tbl = $self->GetDBTable("MEDIA");
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if (!-e $self->figmodel()->config("Media directory")->[0].$row->{NAME}->[0].".txt") {
			my $output = ["VarName;VarType;VarCompartment;Min;Max"];
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				push(@{$output},$row->{COMPOUNDS}->[$j].";DRAIN_FLUX;e;".$row->{MIN}->[$j].";".$row->{MAX}->[$j]);
			}
			$self->print_array_to_file($self->figmodel()->config("Media directory")->[0].$row->{NAME}->[0].".txt",$output);
		}
	}
}

=head3 ProcessDatabaseWithMFAToolkit
Definition:
	FIGMODELdatabase->ProcessDatabaseWithMFAToolkit(string||[string]::list of entities to be processed);
Description:
	This function uses the MFAToolkit to process the entire reaction database. This involves balancing reactions, calculating thermodynamic data, and parsing compound structure files for charge and formula.
	This function should be run when reactions are added or changed, or when structures are added or changed.
	The database should probably be backed up before running the function just in case something goes wrong.
=cut

sub ProcessDatabaseWithMFAToolkit {
	my($self,$processlist) = @_;
	#Checking that the processlist exists
	if (!defined($processlist) || $processlist eq "ALL") {
		my @FilenameList = glob($self->config("compound directory")->[0]."cpd*");
		for (my $j=0; $j < @FilenameList; $j++) {
			if ($FilenameList[$j] =~ m/(cpd\d\d\d\d\d)/) {
				push(@{$processlist},$1);
			}
		}
		@FilenameList = glob($self->config("reaction directory")->[0]."rxn*");
		for (my $j=0; $j < @FilenameList; $j++) {
			if ($FilenameList[$j] =~ m/(rxn\d\d\d\d\d)/) {
				push(@{$processlist},$1);
			}
		}
	}
	#Getting unique directory for output
	my $outputfolder = $self->figmodel()->filename();
	#Ensuring that the newcompounds and newreactions directories exist
	if (!-d $self->config("Reaction database directory")->[0]."newreactions/") {
		system("mkdir ".$self->config("Reaction database directory")->[0]."newreactions/");
	}
	if (!-d $self->config("Reaction database directory")->[0]."newcompounds/") {
		system("mkdir ".$self->config("Reaction database directory")->[0]."newcompounds/");
	}
	if (!-d $self->config("Reaction database directory")->[0]."oldreactions/") {
		system("mkdir ".$self->config("Reaction database directory")->[0]."oldreactions/");
	}
	if (!-d $self->config("Reaction database directory")->[0]."oldcompounds/") {
		system("mkdir ".$self->config("Reaction database directory")->[0]."oldcompounds/");
	}
	#Printing the process list to file if it exists
	$self->print_array_to_file($self->config("MFAToolkit input files")->[0].$outputfolder."-processList.txt",$processlist);
	#Eliminating the mfatoolkit errors from the compound and reaction files
	for (my $j=0; $j < @{$processlist}; $j++) {
		my $Data = $self->figmodel()->LoadObject($processlist->[$j]);
		for (my $i=0; $i < @{$Data->{"orderedkeys"}}; $i++) {
			if ($Data->{"orderedkeys"}->[$i] eq "MFATOOLKIT ERRORS") {
				splice(@{$Data->{"orderedkeys"}},$i,1);
				last;
			}
		}
		$self->figmodel()->SaveObject($Data);
	}
	#Running the mfatoolkit
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($outputfolder,"processdatabase","NONE",["ArgonneProcessing"],{"entities to process" => $outputfolder."-processList.txt"},"DBProcessing-".$outputfolder.".log"));
	#Backing up the current reaction and compound directories
	for (my $i=0; $i < @{$processlist}; $i++) {
		if ($processlist->[$i] =~ m/cpd\d\d\d\d\d/) {
			system("cp ".$self->config("compound directory")->[0].$processlist->[$i]." ".$self->config("Reaction database directory")->[0]."oldcompounds/".$processlist->[$i]);
			system("cp ".$self->config("Reaction database directory")->[0]."newcompounds/".$processlist->[$i]." ".$self->config("compound directory")->[0].$processlist->[$i]);
		} elsif ($processlist->[$i] =~ m/rxn\d\d\d\d\d/) {
			system("cp ".$self->config("reaction directory")->[0].$processlist->[$i]." ".$self->config("Reaction database directory")->[0]."oldreactions/".$processlist->[$i]);
			system("cp ".$self->config("Reaction database directory")->[0]."newreactions/".$processlist->[$i]." ".$self->config("reaction directory")->[0].$processlist->[$i]);
		}
	}
	system("rm ".$self->config("MFAToolkit input files")->[0].$outputfolder."-processList.txt");
	$self->figmodel()->clearing_output($outputfolder,"DBProcessing-".$outputfolder.".log");
	return $self->figmodel()->success();
}

=head3 check_for_file
Definition:
    [string]:filelines = FIGMODELdatabase->check_for_file([string]:filename)
Description:
=cut
sub check_for_file {
	my ($self,$input) = @_;
	
	if (@{$input} == 1 && -e $input->[0]) {
		return $self->load_single_column_file($input->[0]);
	}
	return $input;
}

=head3 convert_ids_to_search_terms
Definition:
    {string:term => [string]:IDs} = FIGMODELdatabase->convert_ids_to_search_terms([string]:IDs)
Description:
=cut
sub convert_ids_to_search_terms {
	my ($self,$IDList) = @_;

	#Converting the $IDList into a flat array ref of IDs
	my $NewIDList;
	if (defined($IDList) && ref($IDList) ne 'ARRAY') {
		my @TempArray = split(/,/,$IDList);
		for (my $j=0; $j < @TempArray; $j++) {
			push(@{$NewIDList},$TempArray[$j]);
		}
	} elsif (defined($IDList)) {
		for (my $i=0; $i < @{$IDList}; $i++) {
			my @TempArray = split(/,/,$IDList->[$i]);
			for (my $j=0; $j < @TempArray; $j++) {
				push(@{$NewIDList},$TempArray[$j]);
			}
		}
	}

	#Determining the type of each ID
	my $TypeLists;
	if (defined($NewIDList)) {
		for (my $i=0; $i < @{$NewIDList}; $i++) {
			if ($NewIDList->[$i] ne "ALL") {
				if ($NewIDList->[$i] =~ m/^fig\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"feature"}},$NewIDList->[$i]);
				} elsif ($NewIDList->[$i] =~ m/^figint\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"interval"}},$2);
				} elsif ($NewIDList->[$i] =~ m/^figstr\|(\d+\.\d+)\.(.+)$/) {
					push(@{$TypeLists->{"strain"}},$2);
				} elsif ($NewIDList->[$i] =~ m/^figmodel\|(.+)$/) {
					push(@{$TypeLists->{"model"}},$2);
				} elsif ($NewIDList->[$i] =~ m/^fig\|(\d+\.\d+)$/ || $NewIDList->[$i] =~ m/^(\d+\.\d+)$/) {
					push(@{$TypeLists->{"genome"}},$1);
				} elsif ($NewIDList->[$i] =~ m/^(rxn\d\d\d\d\d)$/) {
					push(@{$TypeLists->{"reaction"}},$1);
				} elsif ($NewIDList->[$i] =~ m/^(cpd\d\d\d\d\d)$/) {
					push(@{$TypeLists->{"compound"}},$1);
				} else {
					push(@{$TypeLists->{"model"}},$NewIDList->[$i]);
				}
			}
		}
	}

	return $TypeLists;
}

=head3 get_erdb_table
Definition:
     = FIGMODELdatabase->get_erdb_table()
Description:
=cut
sub get_erdb_table {
#	my ($self) = @_;
#	my $obj = Sapling->new();
#	
#	my @ids = $obj->GetFlat("Model","Model(class) = ? and Model(totalGenes) > ?",["Gram positive","1000"],"id");
#	print "All ids:".join(",",@ids)."\n";
#	
#	my @objects = $obj->GetList("Model","Model(class) = ? and Model(totalGenes) > ?",["Gram positive","1000"]);
#	
#	#Changing feild
#	$obj->UpdateEntity("Model",$objects[0]->PrimaryValue("id"),%$hash);
#	
#	#Inserting new object
#	$obj->InsertObject("Model",%$hash);
#	
#	#Deleting element and everything attached to element
#	$obj->Delete("Model","iJR904");
#	
#	my @ids = $obj->GetFlat("Model","Model(class) = ? and Model(totalGenes) > ?",["Gram positive","1000"],"id");
#	
#	my @value = $objects[0]->Value("id");
#	print "Single value:".$value[0]."\n";
#	print "Single value:".$objects[0]->PrimaryValue("id")."\n";
#	
#	my @info = $obj->GetAll("Model","Model(class) = ? and Model(totalGenes) > ?",["Gram positive","1000"],["id","totalGenes"]);
#	print "ID:".$info[0]->[0]."\tTotal genes:".$info[0]->[1]."\n";
}

sub load_ppo {
	my($self,$object) = @_;
	if ($object eq "media") {
		my $mediaTbl = $self->figmodel()->database()->get_table("MEDIA");
		for (my $i=0; $i < $mediaTbl->size(); $i++) {
			my $row = $mediaTbl->get_row($i);
			my $aerobic = 0;
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				if ($row->{COMPOUNDS}->[$j] eq "cpd00007" && $row->{MAX}->[$j] > 0) {
					$aerobic = 1;
					last;
				}
			}
			my $mediaMgr = $self->figmodel()->database()->get_object_manager("media");
			$mediaMgr->create({id=>$row->{NAME}->[0],owner=>"master",modificationDate=>time(),creationDate=>time(),aerobic=>$aerobic});
		}
	} elsif ($object eq "keggmap") {
		my $tbl = $self->get_table("KEGGMAPDATA");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			if (defined($row->{NAME}->[0]) && defined($row->{ID}->[0])) {
				my $obj = $self->get_object("diagram",{type => "KEGG",altid => $row->{ID}->[0]});
				if (!defined($obj)) {
					my $newIDs = $self->check_out_new_id("diagram");
					$obj = $self->create_object("diagram",{id => $newIDs,type => "KEGG",altid => $row->{ID}->[0],name => $row->{NAME}->[0]});
				}
				if (defined($row->{REACTIONS})) {
					for (my $j=0; $j < @{$row->{REACTIONS}}; $j++) {
						my $dgmobj = $self->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "reaction",entity => $row->{REACTIONS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $self->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "reaction",entity => $row->{REACTIONS}->[$j]});
						}
					}
				}
				if (defined($row->{COMPOUNDS})) {
					for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
						my $dgmobj = $self->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "compound",entity => $row->{COMPOUNDS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $self->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "compound",entity => $row->{COMPOUNDS}->[$j]});
						}
					}
				}
				if (defined($row->{ECNUMBERS})) {
					for (my $j=0; $j < @{$row->{ECNUMBERS}}; $j++) {
						my $dgmobj = $self->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "enzyme",entity => $row->{ECNUMBERS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $self->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "enzyme",entity => $row->{ECNUMBERS}->[$j]});
						}
					}
				}
			}
		}
	} elsif ($object eq "rxnmdl") {
		my $objects = $self->get_objects("model");
		for (my $i=0; $i < @{$objects}; $i++) {
			my $mdl = $self->figmodel()->get_model($objects->[$i]->id());
			my $rxntbl = $mdl->reaction_table();
			if (defined($rxntbl)) {
				my $rxnhash;
				my $rxnobjects = $self->get_objects("rxnmdl",{MODEL=>$mdl->id()});
				for (my $j=0; $j < @{$rxnobjects}; $j++) {
					my $row = $rxntbl->get_row_by_key($rxnobjects->[$j]->REACTION(),"LOAD");
					if (defined($row)) {
						$rxnhash->{$rxnobjects->[$j]->REACTION()}->{$rxnobjects->[$j]->directionality().$rxnobjects->[$j]->compartment()} = 1;
						$rxnobjects->[$j]->directionality($row->{DIRECTIONALITY}->[0]);
						$rxnobjects->[$j]->compartment($row->{COMPARTMENT}->[0]);
						if (defined($row->{"ASSOCIATED PEG"}->[0])) {
							$rxnobjects->[$j]->pegs(join("|",@{$row->{"ASSOCIATED PEG"}}));
						} else {
							$rxnobjects->[$j]->pegs("UNKNOWN");
						}
						if (defined($row->{CONFIDENCE}->[0])) {
							$rxnobjects->[$j]->confidence($row->{CONFIDENCE}->[0]);
						} else {
							$rxnobjects->[$j]->confidence(5);
						}
					} else {
						$rxnobjects->[$j]->delete();
					}
				}
				for (my $j=0; $j < $rxntbl->size(); $j++) {
					my $row = $rxntbl->get_row($j);
					if (defined($row->{LOAD}->[0]) && !defined($rxnhash->{$row->{LOAD}->[0]}->{$row->{DIRECTIONALITY}->[0].$row->{COMPARTMENT}->[0]})) {
						$rxnhash->{$row->{LOAD}->[0]}->{$row->{DIRECTIONALITY}->[0].$row->{COMPARTMENT}->[0]} = 1;
						my $confidence = 5;
						if (defined($row->{CONFIDENCE}->[0])) {
							$confidence = $row->{CONFIDENCE}->[0];
						}
						my $mdlrxnMgr = $self->get_object_manager("rxnmdl");
						$mdlrxnMgr->create({directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],REACTION=>$row->{LOAD}->[0],MODEL=>$mdl->id(),pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),confidence=>$confidence});
					}
				}
			}
		}
	} elsif ($object eq "mediacpd") {
		my $mediaTbl = $self->figmodel()->database()->get_table("MEDIA");
		for (my $i=0; $i < $mediaTbl->size(); $i++) {
			my $row = $mediaTbl->get_row($i);
			my $alreadySeed;
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				if (!defined($alreadySeed->{$row->{COMPOUNDS}->[$j]})) {
					$alreadySeed->{$row->{COMPOUNDS}->[$j]} = 1;
					my $max = 100;
					my $conc = 0.001;
					if (defined($row->{MAX}->[$j])) {
						$max = $row->{MAX}->[$j];
					}
					my $mediaMgr = $self->figmodel()->database()->get_object_manager("mediacpd");
					$mediaMgr->create({MEDIA=>$row->{NAME}->[0],COMPOUND=>$row->{COMPOUNDS}->[$j],concentration=>$conc,maxFlux=>$max});
				} else {
					print "Compound ".$row->{COMPOUNDS}->[$j]." repeated in ".$row->{NAME}->[0]." media!\n";
				}
			}
		}
	} elsif ($object eq "compound") {
		my $tbl = $self->figmodel()->database()->get_table("COMPOUNDS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $name = $row->{NAME}->[0];
			for (my $j=1; $j < @{$row->{NAME}}; $j++) {
				if (length($name) > 32) {
					$name = $row->{NAME}->[$j];
					last;
				}
			}
			if (length($name) > 32) {
				$name = substr($name,32);
			}
			my $dataHash = {id=>$row->{DATABASE}->[0],name=>$name,owner=>"master",users=>"all",modificationDate=>time(),creationDate=>time()};
			if (defined($row->{STRINGCODE}->[0])) {
				$dataHash->{stringcode} = $row->{STRINGCODE}->[0];
			}
			if (defined($row->{DELTAG}->[0])) {
				$dataHash->{deltaG} = $row->{DELTAG}->[0];
			}
			if (defined($row->{DELTAGERR}->[0])) {
				$dataHash->{deltaGErr} = $row->{DELTAGERR}->[0];
			}
			if (defined($row->{FORMULA}->[0])) {
				$dataHash->{formula} = $row->{FORMULA}->[0];
			}
			if (defined($row->{MASS}->[0])) {
				$dataHash->{mass} = $row->{MASS}->[0];
			}
			if (defined($row->{CHARGE}->[0])) {
				$dataHash->{charge} = $row->{CHARGE}->[0];
			}
			my $fileData = ModelSEED::FIGMODEL::FIGMODELObject->load($self->config("compound directory")->[0].$row->{DATABASE}->[0],"\t");		
			if (defined($fileData->{PKA})) {
				$dataHash->{pKa} = join(";",@{$fileData->{PKA}});
			}
			if (defined($fileData->{PKB})) {
				$dataHash->{pKb} = join(";",@{$fileData->{PKB}});
			}
			if (defined($fileData->{STRUCTURAL_CUES})) {
				$dataHash->{structuralCues} = join(";",@{$fileData->{STRUCTURAL_CUES}});
			}
			my $cpdMgr = $self->figmodel()->database()->get_object_manager("compound");
			$cpdMgr->create($dataHash);
		}
	} elsif ($object eq "cpdals") {
		my $aliasHash;
		my $tbl = $self->figmodel()->database()->get_table("COMPOUNDS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			for (my $j=0; $j < @{$row->{NAME}}; $j++) {
				if (!defined($aliasHash->{$row->{DATABASE}->[0]}->{name}->{lc($row->{NAME}->[$j])})) {
					$aliasHash->{$row->{DATABASE}->[0]}->{name}->{lc($row->{NAME}->[$j])} = 1;
					my $cpdMgr = $self->figmodel()->database()->get_object_manager("cpdals");
					$cpdMgr->create({COMPOUND=>$row->{DATABASE}->[0],alias=>$row->{NAME}->[$j],type=>"name"});
					my @searchNames = $self->figmodel()->ConvertToSearchNames($row->{NAME}->[$j]);
					for (my $k=0; $k < @searchNames; $k++) {
						if (!defined($aliasHash->{$row->{DATABASE}->[0]}->{searchname}->{lc($searchNames[$k])})) {
							$aliasHash->{$row->{DATABASE}->[0]}->{searchname}->{lc($searchNames[$k])} = 1;
							my $cpdMgr = $self->figmodel()->database()->get_object_manager("cpdals");
							$cpdMgr->create({COMPOUND=>$row->{DATABASE}->[0],alias=>lc($searchNames[$k]),type=>"searchname"});
						}
					}
				}
			}
		}
		my @files = glob($self->figmodel()->config("Translation directory")->[0]."CpdTo*");
		for (my $i=0; $i < @files; $i++) {
			if ($files[$i] !~ m/CpdToAll/ && $files[$i] =~ m/CpdTo(.+)\.txt/) {
				my $type = $1;
				my $data = $self->load_multiple_column_file($files[$i],"\t");
				for (my $j=0; $j < @{$data}; $j++) {
					my $cpdMgr = $self->figmodel()->database()->get_object_manager("cpdals");
					$cpdMgr->create({COMPOUND=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>$type});
				}
			}
		}
		my $data = $self->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."ObsoleteCpdIDs.txt","\t");
		for (my $j=0; $j < @{$data}; $j++) {
			my $cpdMgr = $self->figmodel()->database()->get_object_manager("cpdals");
			$cpdMgr->create({COMPOUND=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>"obsolete"});
		}
	} elsif ($object eq "reaction") {
		my $tbl = $self->figmodel()->database()->get_table("REACTIONS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $name = $row->{DATABASE}->[0];
			if (defined($row->{NAME}->[0])){
				$name = $row->{NAME}->[0];
				for (my $j=1; $j < @{$row->{NAME}}; $j++) {
					if (length($name) > 250 && length($row->{NAME}->[$j]) < 32) {
						$name = $row->{NAME}->[$j];
						last;
					}
				}
				if (length($name) > 250) {
					$name = substr($name,250);
				}
			}
			my $rxnObj = $self->figmodel()->LoadObject($row->{DATABASE}->[0]);
			my $thermodynamicReversibility = "<=>";
			my $definition = "NONE";
			if (defined($rxnObj) && defined($rxnObj->{DEFINITION}->[0])) {
				$definition = $rxnObj->{DEFINITION}->[0];
			}
			if (defined($rxnObj) && defined($rxnObj->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
				$thermodynamicReversibility = $rxnObj->{"THERMODYNAMIC REVERSIBILITY"}->[0];
			}
			my $dataHash = {id=>$row->{DATABASE}->[0],name=>$name,thermoReversibility=>$thermodynamicReversibility,reversibility=>$self->figmodel()->reversibility_of_reaction($row->{DATABASE}->[0]),definition=>$definition,code=>$row->{CODE}->[0],equation=>$row->{EQUATION}->[0],owner=>"master",users=>"all",modificationDate=>time(),creationDate=>time()};
			if (defined($row->{ENZYME}->[0])) {
				$dataHash->{enzyme} = "|".join("|",@{$row->{ENZYME}})."|";
			}
			if (defined($row->{DELTAG}->[0])) {
				$dataHash->{deltaG} = $row->{DELTAG}->[0];
			}
			if (defined($row->{DELTAGERR}->[0])) {
				$dataHash->{deltaGErr} = $row->{DELTAGERR}->[0];
			}
			
			if (defined($rxnObj->{STRUCTURAL_CUES})) {
				$dataHash->{structuralCues} = "|".join("|",@{$rxnObj->{STRUCTURAL_CUES}})."|";
			}
			my $rxnMgr = $self->figmodel()->database()->get_object_manager("reaction");
			$rxnMgr->create($dataHash);
			my ($reactants,$products) = $self->figmodel()->GetReactionSubstrateDataFromEquation($row->{EQUATION}->[0]);
			if (defined($reactants)) {
				for (my $j=0; $j < @{$reactants}; $j++) {
					my $cpdrxnMgr = $self->figmodel()->database()->get_object_manager("cpdrxn");
					$cpdrxnMgr->create({COMPOUND=>$reactants->[$j]->{DATABASE}->[0],REACTION=>$row->{DATABASE}->[0],coefficient=>-1*$reactants->[$j]->{COEFFICIENT}->[0],compartment=>$reactants->[$j]->{COMPARTMENT}->[0],cofactor=>"false"});
				}
			}
			if (defined($products)) {
				for (my $j=0; $j < @{$products}; $j++) {
					my $cpdrxnMgr = $self->figmodel()->database()->get_object_manager("cpdrxn");
					$cpdrxnMgr->create({COMPOUND=>$products->[$j]->{DATABASE}->[0],REACTION=>$row->{DATABASE}->[0],coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],cofactor=>"false"});
				}
			}
		}
	} elsif ($object eq "cofactor") {
		my $cpdobjs = $self->get_objects("cpdrxn");
		for (my $i=0; $i < @{$cpdobjs}; $i++) {
			$cpdobjs->[$i]->cofactor(1);
		}
		my $objs = $self->get_objects("reaction");
		print "Processing reactions...\n";
		for (my $j=0; $j < @{$objs}; $j++) {
			my $obj = $self->figmodel()->LoadObject($objs->[$j]->id());
			if ($obj eq "0") {
				print $objs->[$j]->id()." not found!\n";
				next;
			}
			my $main;
			if (defined($obj->{"MAIN EQUATION"}->[0])) {
				$main = $obj->{"MAIN EQUATION"}->[0];
			} else {
				$main = $obj->{"EQUATION"}->[0];
				$main =~ s/\d*(\s*)cpd00001\s\+\s/$1/;
				$main =~ s/\d*(\s*)cpd00067\s\+\s/$1/;
				$main =~ s/\s\+\s\d*(\s*)cpd00067/$1/;
				$main =~ s/\s\+\s\d*(\s*)cpd00001/$1/;
			}
			my ($reactants,$products) = $self->figmodel()->GetReactionSubstrateDataFromEquation($main);
			if (defined($reactants)) {
				for (my $i=0; $i < @{$reactants}; $i++) {
					my $cpdobj = $self->get_objects("cpdrxn",{REACTION=>$objs->[$j]->id(),COMPOUND=>$reactants->[$i]->{DATABASE}->[0],compartment=>$reactants->[$i]->{COMPARTMENT}->[0]});
					if (defined($cpdobj->[0]) && $cpdobj->[0]->coefficient() < 0) {
						$cpdobj->[0]->cofactor("false");
					} elsif (defined($cpdobj->[1]) && $cpdobj->[1]->coefficient() < 0) {
						$cpdobj->[1]->cofactor("false");
					}
				}
			}
			if (defined($products)) {
				for (my $i=0; $i < @{$products}; $i++) {
					my $cpdobj = $self->get_objects("cpdrxn",{REACTION=>$objs->[$j]->id(),COMPOUND=>$products->[$i]->{DATABASE}->[0],compartment=>$products->[$i]->{COMPARTMENT}->[0]});
					if (defined($cpdobj->[0]) && $cpdobj->[0]->coefficient() > 0) {
						$cpdobj->[0]->cofactor("false");
					} elsif (defined($cpdobj->[1]) && $cpdobj->[1]->coefficient() > 0) {
						$cpdobj->[1]->cofactor("false");
					}
				}
			}
		}
	} elsif ($object eq "rxnals") {
		my @files = glob($self->figmodel()->config("Translation directory")->[0]."RxnTo*");
		for (my $i=0; $i < @files; $i++) {
			if ($files[$i] !~ m/RxnToAll/ && $files[$i] =~ m/RxnTo(.+)\.txt/) {
				my $type = $1;
				my $data = $self->load_multiple_column_file($files[$i],"\t");
				for (my $j=0; $j < @{$data}; $j++) {
					my $rxnMgr = $self->figmodel()->database()->get_object_manager("rxnals");
					$rxnMgr->create({REACTION=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>$type});
				}
			}
		}
		my $data = $self->load_multiple_column_file($self->figmodel()->config("Translation directory")->[0]."ObsoleteRxnIDs.txt","\t");
		for (my $j=0; $j < @{$data}; $j++) {
			my $rxnMgr = $self->figmodel()->database()->get_object_manager("rxnals");
			$rxnMgr->create({REACTION=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>"obsolete"});
		}
	} elsif ($object eq "complex") {
		#Storing current complex data in a hash
		my $cpxHash;
		my $inDBHash;
		my $cpxRoleLoaded;
		my $rxncpxs = $self->get_objects("rxncpx");
		for (my $i=0; $i < @{$rxncpxs}; $i++) {
			my $cpxroles = $self->get_objects("cpxrole",{COMPLEX=>$rxncpxs->[$i]->COMPLEX()});
			my $roles;
			for (my $j=0; $j < @{$cpxroles}; $j++) {
				push(@{$roles},$cpxroles->[$j]->ROLE());
			}
			$cpxHash->{join("|",sort(@{$roles}))}->{$rxncpxs->[$i]->REACTION()} = $rxncpxs->[$i];
			$inDBHash->{join("|",sort(@{$roles}))}->{$rxncpxs->[$i]->REACTION()} = 0;
		}
		#Translating roles in mapping table to role IDs
		my $ftrTbl = $self->get_table("ROLERXNMAPPING");
		my $hash;
		for (my $i=0; $i < $ftrTbl->size(); $i++) {
			my $row = $ftrTbl->get_row($i);
			my $role = 	$row->{ROLE}->[0];
			if (defined($row->{ROLE}->[0])) {
				$role = $self->figmodel()->convert_to_search_role($role);
				my $roleobj = $self->get_object("role",{searchname => $role});
				if (!defined($roleobj)) {
					my $newRoleID = $self->check_out_new_id("role");
					my $roleMgr = $self->get_object_manager("role");
					$roleobj = $roleMgr->create({id=>$newRoleID,name=>$row->{ROLE}->[0],searchname=>$role});
				}
				$hash->{$row->{REACTION}->[0]}->{$row->{COMPLEX}->[0]}->{$roleobj->id()} = $row->{MASTER}->[0];
			}
		}
		#Loading new complexes into the database
		my @rxns = keys(%{$hash});
		for (my $i=0; $i < @rxns; $i++) {
			my @cpxs = keys(%{$hash->{$rxns[$i]}});
			for (my $j=0; $j < @cpxs; $j++) {
				my $sortedRoleList = join("|",sort(keys(%{$hash->{$rxns[$i]}->{$cpxs[$j]}})));
				#Determining whether the complex is in the master list
				my $master = 0;
				my @roles = keys(%{$hash->{$rxns[$i]}->{$cpxs[$j]}});
				for (my $k=0; $k < @roles; $k++) {
					if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} > 0) {
						$master = 1;
					}
				}
				#Creating a new complex
				my $cpxID;
				if (!defined($cpxHash->{$sortedRoleList})) {
					$cpxID = $self->check_out_new_id("complex");
					my $cpxMgr = $self->get_object_manager("complex");
					my $newCpx = $cpxMgr->create({id=>$cpxID});
					#Adding roles to new complex
					for (my $k=0; $k < @roles; $k++) {
						my $type = "G";
						if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 0) {
							$type = "N";
						} elsif ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 2) {
							$type = "L";
						}
						my $cpxRoleMgr = $self->get_object_manager("cpxrole");
						$cpxRoleMgr->create({COMPLEX=>$cpxID,ROLE=>$roles[$k],type=>$type});
						$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
					}
				} else {
					#Checking to make sure the status of each role in the complex has not changed
					my @cpxRxns = keys(%{$cpxHash->{$sortedRoleList}});
					my $firstRxn = $cpxRxns[0];					
					$cpxID = $cpxHash->{$sortedRoleList}->{$firstRxn}->COMPLEX();
					for (my $k=0; $k < @roles; $k++) {
						my $type = "G";
						if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 0) {
							$type = "N";
						} elsif ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 2) {
							$type = "L";
						}				
						my $cpxRole = $self->get_object("cpxrole",{COMPLEX=>$cpxID,ROLE=>$roles[$k]});
						if (!defined($cpxRole)) {
							my $cpxRoleMgr = $self->get_object_manager("cpxrole");
							$cpxRoleMgr->create({COMPLEX=>$cpxID,ROLE=>$roles[$k],type=>$type});
							$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
						} else {
							if (defined($cpxRoleLoaded->{$cpxID}->{$roles[$k]}) && $cpxRoleLoaded->{$cpxID}->{$roles[$k]} ne "N" && $type eq "N") {
								$type = $cpxRoleLoaded->{$cpxID}->{$roles[$k]};
							}
							$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
							$cpxRole->type($type);
						}
					}
				}
				#Adding complex to reaction table
				if (!defined($cpxHash->{$sortedRoleList}->{$rxns[$i]})) {
					my $rxncpxMgr = $self->get_object_manager("rxncpx");
					$cpxHash->{$sortedRoleList}->{$rxns[$i]} = $rxncpxMgr->create({REACTION=>$rxns[$i],COMPLEX=>$cpxID,master=>$master});
				} else {
					#Checking to make sure the "master" status of the complex has not changed
					$cpxHash->{$sortedRoleList}->{$rxns[$i]}->master($master);
				}
				$inDBHash->{$sortedRoleList}->{$rxns[$i]} = 1;
			}
		}
		#Now we go through the database and look for complexes that no longer exist
		my @complexKeys = keys(%{$cpxHash});
		my $deletedComplexes;
		for (my $i=0; $i < @complexKeys; $i++) {
			if ($inDBHash->{$complexKeys[$i]} == 0) {
				$deletedComplexes->{$cpxHash->{$complexKeys[$i]}->COMPLEX()} = 1;
				$cpxHash->{$complexKeys[$i]}->delete();
			}
		}
		#Deleting any complexes that are no longer mapped to any reactions in the database
		my @deletedComplexArray = keys(%{$deletedComplexes});
		for (my $i=0; $i < @deletedComplexArray; $i++) {
			if (!defined($self->get_object("rxncpx",{COMPLEX=>$deletedComplexArray[$i]}))) {
				$self->get_object("cpx",{id=>$deletedComplexArray[$i]})->delete();
				my $cpxroles = $self->get_objects("cpxrole",{COMPLEX=>$deletedComplexArray[$i]});
				for (my $j=0; $j < @{$cpxroles}; $j++) {
					$cpxroles->[$j]->delete();
				} 
			}	
		}
	} elsif ($object eq "esssets") {
		my @genomes = glob($self->figmodel()->config("experimental data directory")->[0]."*");
		for (my $i=0; $i < @genomes; $i++) {
			my $genome;
			if (-e $genomes[$i]."/Essentiality.txt" && $genomes[$i] =~ m/(\d+\.\d+$)/) {
				$genome = $1;
				my $data = $self->load_single_column_file($genomes[$i]."/Essentiality.txt");
				my $media;
				for (my $j=1; $j < @{$data}; $j++) {
					my @results = split(/\t/,$data->[$j]);
					$media->{$results[1]}->{genes}->{$results[0]} = $results[2];
					$media->{$results[1]}->{reference} = $results[3];
				}
				my @mediaList = keys(%{$media});
				for (my $j=0; $j < @mediaList; $j++) {
					#Adding the esssets object
					my $obj = $self->get_object("esssets",{GENOME=>$genome,MEDIA=>$mediaList[$j]});
					if (!defined($obj)) {
						$obj = $self->create_object("esssets",{id=>-1,GENOME=>$genome,MEDIA=>$mediaList[$j]});
						$obj->id($obj->_id());
					}
					#Adding the literature references
					my @references = keys(%{$media->{$mediaList[$j]}->{reference}});
					for (my $k=0; $k < @references; $k++) {
						my $refobj = $self->get_object("reference",{objectID=>$obj->_id(),DBENTITY=>"esssets",pubmedID=>$references[$k]});
						if (!defined($refobj)) {
							$refobj = $self->create_object("reference",{objectID=>$obj->_id(),DBENTITY=>"esssets",pubmedID=>$references[$k],notation=>"none",date=>time()});
						}	
					}
					my @geneList = keys(%{$media->{$mediaList[$j]}->{genes}});
					for (my $k=0; $k < @geneList; $k++) {
						my $subobj = $self->get_object("essgenes",{ESSENTIALITYSET=>$obj->id(),FEATURE=>$geneList[$k]});
						if (!defined($subobj)) {
							$subobj = $self->create_object("essgenes",{essentiality=>$media->{$mediaList[$j]}->{genes}->{$geneList[$k]},ESSENTIALITYSET=>$obj->id(),FEATURE=>$geneList[$k]});
						} else {
							$subobj->essentiality($media->{$mediaList[$j]}->{genes}->{$geneList[$k]});
						}
					}
				}
			}
		}
	} elsif ($object eq "abbrev") {
		#Load compound abbreviations
		my $cpdAbbrevHash;
		my $cpdObjs = $self->figmodel()->database()->get_objects("compound");
		for (my $i=0; $i < @{$cpdObjs}; $i++) {
			my $aliasObjs = $self->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$cpdObjs->[$i]->id()});
			my $abbrev;
			my $name;
			for (my $j=0; $j < @{$aliasObjs}; $j++) {
				if ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "name" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($cpdAbbrevHash->{$aliasObjs->[$j]->alias()})) {
						$abbrev = $aliasObjs->[$j]->alias();
					}
				} elsif ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($name) || length($aliasObjs->[$j]->alias()) < length($name)) {
						$name = $aliasObjs->[$j]->alias();	
					}
				}
			}
			if (defined($abbrev)) {
				$cpdObjs->[$i]->abbrev($abbrev);
			} else {
				$cpdObjs->[$i]->abbrev($name);
			}
		}
		#Load reaction abbreviations
		my $rxnAbbrevHash;
		my $rxnObjs = $self->figmodel()->database()->get_objects("reaction");
		for (my $i=0; $i < @{$rxnObjs}; $i++) {
			my $rxnFileData = $self->figmodel()->LoadObject($rxnObjs->[$i]->id());
			if (ref($rxnFileData) eq "HASH" && defined($rxnFileData->{NAME})) {
				for (my $j=0; $j < @{$rxnFileData->{NAME}}; $j++) {
					my $aliasObj = $self->figmodel()->database()->get_object("rxnals",{type=>"name",alias=>$rxnFileData->{NAME}->[$j],REACTION=>$rxnObjs->[$i]->id()});
					if (!defined($aliasObj)) {
						$self->figmodel()->database()->create_object("rxnals",{REACTION=>$rxnObjs->[$i]->id(),type=>"name",alias=>$rxnFileData->{NAME}->[$j]});
					}
					my @searchNames = $self->figmodel()->convert_to_search_name($rxnFileData->{NAME}->[$j]);
					for (my $k=0; $k < @searchNames; $k++) {
						my $aliasObj = $self->figmodel()->database()->get_object("rxnals",{type=>"searchname",alias=>$searchNames[$k],REACTION=>$rxnObjs->[$i]->id()});
						if (!defined($aliasObj)) {
							$self->figmodel()->database()->create_object("rxnals",{REACTION=>$rxnObjs->[$i]->id(),type=>"searchname",alias=>$searchNames[$k]});
						}
					}
				}
			}
			my $aliasObjs = $self->figmodel()->database()->get_objects("rxnals",{REACTION=>$rxnObjs->[$i]->id()});
			my $abbrev;
			my $name;
			for (my $j=0; $j < @{$aliasObjs}; $j++) {
				if ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "name" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($rxnAbbrevHash->{$aliasObjs->[$j]->alias()})) {
						$abbrev = $aliasObjs->[$j]->alias();
					}
				} elsif ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($name) || length($aliasObjs->[$j]->alias()) < length($name)) {
						$name = $aliasObjs->[$j]->alias();	
					}
				}
			}
			if (defined($abbrev)) {
				$rxnObjs->[$i]->abbrev($abbrev);
			} else {
				$rxnObjs->[$i]->abbrev($name);
			}
			if ($rxnObjs->[$i]->abbrev() eq "all") {
				$rxnObjs->[$i]->abbrev($rxnObjs->[$i]->id());	
			}
		}
	} elsif ($object eq "bof") {
		my $aliasHash;
		my $tbl = $self->figmodel()->database()->get_table("BIOMASS");
		my $botTempTbl = $self->figmodel()->database()->GetDBTable("BIOMASS TEMPLATE");
		my $groupHash;
		my $grpIndex = {L=>"pkg00001",W=>"pkg00001",C=>"pkg00001"};
		my $mdlMgr = $self->figmodel()->database()->get_object_manager("model");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $cpdMgr = $self->figmodel()->database()->get_object_manager("bof");
			my $data = {id=>$row->{DATABASE}->[0],name=>"Biomass",equation=>$row->{EQUATION}->[0],protein=>"0.5284",DNA=>"0.026",RNA=>"0.0655",lipid=>"0.075",cellWall=>"0.25",cofactor=>"0.10",modificationDate=>time(),creationDate=>time()};
			$data->{owner} = "master";
			$data->{users}  = "all";
			my $mdlObjs = $mdlMgr->get_objects({biomassReaction=>$row->{DATABASE}->[0]});
			if (defined($mdlObjs->[0]) && !defined($mdlObjs->[1])) {
				$data->{owner} = $mdlObjs->[0]->owner();
				$data->{users}  = $mdlObjs->[0]->users();
			}
			my ($lccdata,$coef,$package);
			my ($reactants,$products) = $self->figmodel()->GetReactionSubstrateDataFromEquation($row->{EQUATION}->[0]);
			#Populating the compound biomass table
			my $hash;
			for (my $j=0; $j < @{$reactants}; $j++) {
				my $category = "U";#Unknown
				my $tempRow = $botTempTbl->get_row_by_key($reactants->[$j]->{DATABASE}->[0],"ID");
				if (defined($tempRow) && $tempRow->{CLASS}->[0] eq "LIPIDS") {
					$category = "L";#Lipid
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "CELL WALL") {
					$category = "W";#Cell wall
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "COFACTOR") {
					$category = "C";#Cofactor
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "ENERGY") {
					$category = "E";#Energy
				} elsif (defined($tempRow)) {
					$category = "M";#Macromolecule
				}
				$lccdata->{$category}->{$reactants->[$j]->{DATABASE}->[0]} = "-".$reactants->[$j]->{COEFFICIENT}->[0];
				if (!defined($hash->{$reactants->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$reactants->[$j]->{COMPARTMENT}->[0]})) {
					$hash->{$reactants->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$reactants->[$j]->{COMPARTMENT}->[0]} = 1;
					my $cpdbofMgr = $self->figmodel()->database()->get_object_manager("cpdbof");
					$cpdbofMgr->create({COMPOUND=>$reactants->[$j]->{DATABASE}->[0],BIOMASS=>$row->{DATABASE}->[0],coefficient=>(-1*$reactants->[$j]->{COEFFICIENT}->[0]),compartment=>$reactants->[$j]->{COMPARTMENT}->[0],category=>$category});	
				}
			}
			for (my $j=0; $j < @{$products}; $j++) {
				my $category = "U";#Unknown
				my $tempRow = $botTempTbl->get_row_by_key($products->[$j]->{DATABASE}->[0],"ID");
				if (defined($tempRow) && $tempRow->{CLASS}->[0] eq "LIPIDS") {
					$category = "L";#Lipid
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "CELL WALL") {
					$category = "W";#Cell wall
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "COFACTOR") {
					$category = "C";#Cofactor
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "ENERGY") {
					$category = "E";#Energy
				} elsif (defined($tempRow)) {
					$category = "M";#Macromolecule
				}
				$lccdata->{$category}->{$products->[$j]->{DATABASE}->[0]} = "-".$products->[$j]->{COEFFICIENT}->[0];
				if (!defined($hash->{$products->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$products->[$j]->{COMPARTMENT}->[0]})) {
					$hash->{$products->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$products->[$j]->{COMPARTMENT}->[0]} = 1;
					my $cpdbofMgr = $self->figmodel()->database()->get_object_manager("cpdbof");
					$cpdbofMgr->create({COMPOUND=>$products->[$j]->{DATABASE}->[0],BIOMASS=>$row->{DATABASE}->[0],coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],category=>$category});	
				}
			}
			my $types = ["L","C","W"];
			my $typeNames = {L=>"Lipid",C=>"Cofactor",W=>"CellWall"};
			for (my $j=0; $j < @{$types}; $j++) {
				if (!defined($lccdata->{$types->[$j]})) {
					$coef->{$types->[$j]} = "NONE";
					$package->{$types->[$j]} = "NONE";
				} else {
					my @list = sort(keys(%{$lccdata->{$types->[$j]}}));
					for (my $k=0; $k < @list; $k++) {
						$coef->{$types->[$j]} .= $lccdata->{$types->[$j]}->{$list[$k]}.";";
					}
					my $key = join(";",@list);
					if (!defined($groupHash->{$types->[$j]}->{$key})) {
						$groupHash->{$types->[$j]}->{$key} = $grpIndex->{$types->[$j]};
						for (my $k=0; $k < @list; $k++) {
							print "Creating compound group:";
							my $cpdGrpMgr = $self->figmodel()->database()->get_object_manager("cpdgrp");
							$cpdGrpMgr->create({COMPOUND=>$list[$k],grouping=>$grpIndex->{$types->[$j]},type=>$typeNames->{$types->[$j]}."Package"});
							print "DONE\n";
						}
						$grpIndex->{$types->[$j]}++;
					}
					$package->{$types->[$j]} = $groupHash->{$types->[$j]}->{$key};
				}
			}
			$data->{cofactorPackage} = $package->{"C"};
			$data->{lipidPackage} = $package->{"L"};
			$data->{cellWallPackage} = $package->{"W"};
			$data->{DNACoef} = "-0.284|1|-0.216|-0.216|-0.284";
			$data->{RNACoef} = "1|-0.262|-0.323|-0.199|-0.215";
			$data->{proteinCoef} = "1|-0.0637|-0.0999|-0.0653|-0.0790|-0.0362|-0.0472|-0.0637|-0.0529|-0.0277|-0.0133|-0.0430|-0.0271|-0.0139|-0.0848|-0.0200|-0.0393|-0.0362|-0.0751|-0.0456|-0.0660";
			$data->{lipidCoef} = $coef->{"L"};
			$data->{cellWallCoef} = $coef->{"W"};
			$data->{cofactorCoef} = $coef->{"C"};
			$data->{energy} = 40;
			if (defined($row->{"ESSENTIAL REACTIONS"})) {
				$data->{essentialRxn} = join("|",@{$row->{"ESSENTIAL REACTIONS"}});
			}
			print "Creating biomass reaction.";
			$cpdMgr->create($data);
			print "Done.\n";
		}
	}
}

=head3 add_biomass_reaction_from_equation
Definition:
	(success/fail) = FIGMODELdatabase>add_biomass_reaction_from_equation(string:equation,optional string:biomass ID);
Description:
	This function adds a biomass reaction to the database based on its equation. If an ID is specified, that ID is used. Otherwise, a new ID is checked out from the database.
=cut
sub add_biomass_reaction_from_equation {
	my($self,$equation,$biomassID) = @_;
	#If no ID is provided, and ID is checked out of the database
	if (!defined($biomassID)) {
		$biomassID = $self->check_out_new_id("bof");	
	} else {
		#Deleting elements in cpdbof table associated with this ID
		my $objs = $self->get_objects("cpdbof",{BIOMASS=>$biomassID});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();
		}
	}	
	#Parsing equation
	my ($reactants,$products) = $self->figmodel()->GetReactionSubstrateDataFromEquation($equation);
	#Populating the compound biomass table
	my $energy = 0;
	my $compounds;
	$compounds->{RNA} = {cpd00002=>0,cpd00012=>0,cpd00038=>0,cpd00052=>0,cpd00062=>0};
	$compounds->{protein} = {cpd00001=>0,cpd00023=>0,cpd00033=>0,cpd00035=>0,cpd00039=>0,cpd00041=>0,cpd00051=>0,cpd00053=>0,cpd00054=>0,cpd00060=>0,cpd00065=>0,cpd00066=>0,cpd00069=>0,cpd00084=>0,cpd00107=>0,cpd00119=>0,cpd00129=>0,cpd00132=>0,cpd00156=>0,cpd00161=>0,cpd00322=>0};
	$compounds->{DNA} = {cpd00012=>0,cpd00115=>0,cpd00241=>0,cpd00356=>0,cpd00357=>0};
	for (my $j=0; $j < @{$reactants}; $j++) {
		my $category = "U";
		if ($reactants->[$j]->{DATABASE}->[0] eq "cpd00002" || $reactants->[$j]->{DATABASE}->[0] eq "cpd00001") {
			$category = "E";
			if ($energy < $reactants->[$j]->{COEFFICIENT}->[0]) {
				$energy = $reactants->[$j]->{COEFFICIENT}->[0];
			}
		}
		if (defined($compounds->{protein}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{protein}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "P";
		} elsif (defined($compounds->{RNA}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{RNA}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "R";
		} elsif (defined($compounds->{DNA}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{DNA}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "D";
		} else {
			my $obj = $self->get_object("cpdgrp",{type=>"CofactorPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
			if (defined($obj)) {
				$compounds->{Cofactor}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
				$category = "C";
			} else { 
				$obj = $self->get_object("cpdgrp",{type=>"LipidPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
				if (defined($obj)) {
					$compounds->{Lipid}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
					$category = "L";
				} else {
					$obj = $self->get_object("cpdgrp",{type=>"CellWallPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
					if (defined($obj)) {
						$compounds->{CellWall}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
						$category = "W";
					} else {
						$compounds->{Unknown}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
						$category = "U";
					}
				}
			}
		}
		$self->create_object("cpdbof",{COMPOUND=>$reactants->[$j]->{DATABASE}->[0],BIOMASS=>$biomassID,coefficient=>-1*$reactants->[$j]->{COEFFICIENT}->[0],compartment=>$reactants->[$j]->{COMPARTMENT}->[0],category=>$category});
	}
	for (my $j=0; $j < @{$products}; $j++) {
		my $category = "U";
		if ($products->[$j]->{DATABASE}->[0] eq "cpd00008" || $products->[$j]->{DATABASE}->[0] eq "cpd00009" || $products->[$j]->{DATABASE}->[0] eq "cpd00067") {
			$category = "E";
			if ($energy < $products->[$j]->{COEFFICIENT}->[0]) {
				$energy = $products->[$j]->{COEFFICIENT}->[0];
			}
		} elsif ($products->[$j]->{DATABASE}->[0] eq "cpd11416") {
			$category = "M";
		}
		$self->create_object("cpdbof",{COMPOUND=>$products->[$j]->{DATABASE}->[0],BIOMASS=>$biomassID,coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],category=>$category});
	}
	my $package = {Lipid=>"NONE",CellWall=>"NONE",Cofactor=>"NONE",Unknown=>"NONE"};
	my $coef = {protein=>"NONE",DNA=>"NONE",RNA=>"NONE",Lipid=>"NONE",CellWall=>"NONE",Cofactor=>"NONE",Unknown=>"NONE"};
	my $types = ["protein","DNA","RNA","Lipid","CellWall","Cofactor","Unknown"];
	my $packages;
	my $packageHash;
	for (my $i=0; $i < @{$types}; $i++) {
		my @entities = sort(keys(%{$compounds->{$types->[$i]}}));
		if (@entities > 0) {
			$coef->{$types->[$i]} = "";
		}
		if (@entities > 0 && ($types->[$i] eq "Lipid" || $types->[$i] eq "CellWall" || $types->[$i] eq "Cofactor" || $types->[$i] eq "Unknown")) {
			my $cpdgrpObs = $self->get_objects("cpdgrp",{type=>$types->[$i]."Package"});
			for (my $j=0; $j < @{$cpdgrpObs}; $j++) {
				$packages->{$types->[$i]}->{$cpdgrpObs->[$j]->grouping()}->{$cpdgrpObs->[$j]->COMPOUND()} = 1;
			}
			my @packageList = keys(%{$packages->{$types->[$i]}});
			for (my $j=0; $j < @packageList; $j++) {
				$packageHash->{join("|",sort(keys(%{$packages->{$types->[$i]}->{$packageList[$j]}})))} = $packageList[$j];
			}
			if (defined($packageHash->{join("|",@entities)})) {
				$package->{$types->[$i]} = $packageHash->{join("|",@entities)};
			} else {
				$package->{$types->[$i]} = $self->check_out_new_id($types->[$i]."Package");
				my @cpdList = keys(%{$compounds->{$types->[$i]}});
				for (my $j=0; $j < @cpdList; $j++) {
					$self->create_object("cpdgrp",{COMPOUND=>$cpdList[$j],grouping=>$package->{$types->[$i]},type=>$types->[$i]."Package"});
				}
			}
		}
		for (my $j=0; $j < @entities; $j++) {
			if ($j > 0) {
				$coef->{$types->[$i]} .= "|";
			}
			$coef->{$types->[$i]} .= $compounds->{$types->[$i]}->{$entities[$j]};
		}
	}
    my $data = { essentialRxn => "NONE", owner => "master", name => "Biomass",
                 equation => $equation, modificationDate => time(), creationDate => time(),
                 id => $biomassID, cofactorPackage => $package->{Cofactor}, lipidPackage => $package->{Lipid},
                 cellWallPackage => $package->{CellWall}, unknownCoef => $coef->{Unknown},
                 unknownPackage => $package->{Unknown}, protein => "0", DNA => "0", RNA => "0",
                 lipid => "0", cellWall => "0", cofactor => "0", proteinCoef => $coef->{protein},
                 DNACoef => $coef->{DNA}, RNACoef => $coef->{RNA}, lipidCoef => $coef->{Lipid},
                 cellWallCoef => $coef->{CellWall}, cofactorCoef => $coef->{Cofactor}, energy => $energy };
	my $bofobj = $self->get_object("bof",{id=>$biomassID});
	if (!defined($bofobj)) {
		$bofobj = $self->create_object("bof",$data);
	} else {
		$bofobj->owner($data->{owner});
		$bofobj->name($data->{name});
		$bofobj->equation($data->{equation});
		$bofobj->modificationDate($data->{modificationDate});
		$bofobj->cofactorPackage($data->{cofactorPackage});
		$bofobj->lipidPackage($data->{lipidPackage});
		$bofobj->cellWallPackage($data->{cellWallPackage});
		$bofobj->unknownPackage($data->{unknownPackage});
		$bofobj->protein($data->{protein});
		$bofobj->DNA($data->{DNA});
		$bofobj->RNA($data->{RNA});
		$bofobj->lipid($data->{lipid});
		$bofobj->cellWall($data->{cellWall});
		$bofobj->cofactor($data->{cofactor});
		$bofobj->proteinCoef($data->{proteinCoef});
		$bofobj->DNACoef($data->{DNACoef});
		$bofobj->RNACoef($data->{RNACoef});
		$bofobj->lipidCoef($data->{lipidCoef});
		$bofobj->cellWallCoef($data->{cellWallCoef});
		$bofobj->cofactorCoef($data->{cofactorCoef});
		$bofobj->unknownCoef($data->{unknownCoef});
		$bofobj->energy($data->{energy});
		$bofobj->essentialRxn("none");
	}
    return $bofobj;
}

=head3 add_biomass_reaction_from_file
definition:
	(success/fail) = figmodeldatabase>add_biomass_reaction_from_file(string:biomass id);
=cut
sub add_biomass_reaction_from_file {
	my($self,$biomassid) = @_;
	my $object = $self->figmodel()->loadobject($biomassid);
	$self->add_biomass_reaction_from_equation($object->{equation}->[0],$biomassid);
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

=head3 makeCompoundObsolete
Definition:
    Removes oldCompound from the database, substituting newCompoundId
    where needed.  Returns success() on success, fail() on failure.

	bool = FIGMODELdatabase->([string]:oldCompoundId, [string]:newCompoundId);
=cut
sub makeCompoundObsolete { 
    my ($self, $oldId, $newId) = @_;
    # Compound Alias
    my $oldAliases = $self->get_objects("cpdals", { 'COMPOUND' => $oldId });
    my $newAliases = $self->get_objects("cpdals", { 'COMPOUND' => $newId });
    my %newAliasHash = map { $_->type() => $_->alias() } @$newAliases;
    # If new compound already has the alias, delete the old, otherwise set the old to the new id
    foreach my $als (@$oldAliases) {
        if(defined($newAliasHash{$als->type()}) &&
            $newAliasHash{$als->type()} eq $als->alias()) {
            $als->delete();
        } else {
            $als->COMPOUND($newId);
        }
    }
    # Compound Reaction, Reaction
    # First get all reactions of new compound, hash by reaction code
    my $newCpdRxns = $self->get_objects("cpdrxn", { 'COMPOUND' => $newId });
    my $newRxns = [];
    foreach my $cpdRxn (@$newCpdRxns) {
        next unless(defined($cpdRxn));
        push(@$newRxns, @{$self->get_objects("reaction", { 'id' => $cpdRxn->REACTION() })});
    }
    my %newRxnCodeHash = map { $_->code() => $_ } @$newRxns;
    # Now foreach reaction containing the old compound: 
    my $oldCpdRxns = $self->get_objects("cpdrxn", { 'COMPOUND' => $oldId });
    my $oldRxns = [];
    foreach my $cpdRxn (@$oldCpdRxns) {
        next unless(defined($cpdRxn));
        push(@$oldRxns, @{$self->get_objects("reaction", { 'id' => $cpdRxn->REACTION() })});
    }
    my $oldToNewCpd = { $oldId => $newId };
    foreach my $rxn (@$oldRxns) {
        my ($direction, $code, $revCode, $eq, $compartment, $error) =
            $self->figmodel()->ConvertEquationToCode($rxn->equation(), $oldToNewCpd);
        if ($error) {
            next; #FIXME
        }
        my $existingRxn; # Either the reaction exists (compare on code replacing the obsolete id)
        if (defined($newRxnCodeHash{$code}) || defined($newRxnCodeHash{$revCode})){
            $existingRxn = defined($newRxnCodeHash{$code}) ? $newRxnCodeHash{$code} : $newRxnCodeHash{$revCode};
            my $status = $self->makeReactionObsolete($rxn->id(), $existingRxn->id());
            if ($status == $self->fail()) {
                next; #FIXME
            }
        } else { # or it must be linked to the new compound id
            my $rxnCpd = $self->get_object('cpdrxn', { 'REACTION' => $rxn->id(), 'COMPOUND' => $oldId });
            $rxnCpd->COMPOUND($newId);
            $rxn->equation($code);
            $rxn->code($code);
        }
    }
    # Compound Biomass
    my $newCpdBofs = $self->get_objects("cpdbof", { 'COMPOUND' => $newId });
    my %newCpdBofsHash = map { $_->BIOMASS() => $_} @$newCpdBofs;
    my $oldCpdBofs = $self->get_objects("cpdbof", { 'COMPOUND' => $oldId });
    foreach my $cpdbof (@$oldCpdBofs) {
        # Both compounds in the same biomass formulation (probably rare)
        if (defined($newCpdBofsHash{$cpdbof->BIOMASS}) && 
            $newCpdBofsHash{$cpdbof->BIOMASS}->compartment() eq $cpdbof->compartment()) {
            # Alter the coefficient values of the new cpdbof entry
            my $newCoff = $newCpdBofsHash{$cpdbof->BIOMASS}->coefficient();
            $newCoff += $cpdbof->coefficient(); 
            $newCpdBofsHash{$cpdbof->BIOMASS}->coefficient($newCoff);
            $cpdbof->delete();
        } else {
            $cpdbof->COMPOUND($newId);
        }
    }
    # Compound Grouping
    my $newCpdGrps = $self->get_objects("cpdgrp", { 'COMPOUND' => $newId });
    my %newCpdGrpsHash = map { $_->grouping() => $_->type() } @$newCpdGrps;
    my $oldCpdGrps = $self->get_objects("cpdgrp", { 'COMPOUND' => $oldId});
    foreach my $cpdGrp (@$oldCpdGrps) {
        if (defined($newCpdGrpsHash{$cpdGrp->grouping()}) &&
            $newCpdGrpsHash{$cpdGrp->grouping()} eq $cpdGrp->type()) {
            $cpdGrp->delete();
        } else {
            $cpdGrp->COMPOUND($newId);
        }
    }
    # Now delete the compound
    my $oldcpds = $self->get_objects("compound", { "id" => $oldId});
    $oldcpds->[0]->delete() if(@$oldcpds > 0);    
    # Now construct the obsolete alias
    my $cpdalsObs = $self->get_object('cpdals',{ 'COMPOUND' => $newId, 'type' => 'obsolete', 'alias' => $oldId});
    unless(defined($cpdalsObs)) {
        $self->create_object('cpdals', { 'COMPOUND' => $newId, 'type' => 'obsolete', 'alias' => $oldId});
    }
    return $self->success();
}

=head3 makeReactionObsolete
Definition:
    Removes oldReaction from the database, replacing all references
    with newReaction. Returns success() on success, fail() on failure.
 
	bool = FIGMODELdatabase->([string]:oldReactionId, [string]:newReactionId);
=cut
sub makeReactionObsolete {
    my ($self, $oldId, $newId) = @_;
    # Reaction Alias
    my $newAliases = $self->get_objects("rxnals", { 'REACTION' => $newId });
    my %newAliasHash = map { $_->type() => $_->alias() } @$newAliases;
    my $oldAliases = $self->get_objects("rxnals", { 'REACTION' => $oldId });
    foreach my $als (@$oldAliases) {
        if(defined($newAliasHash{$als->type()}) &&
            $newAliasHash{$als->type()} eq $als->alias()) {
            $als->delete();
        } else {
            $als->REACTION($newId);
        }
    }
    # Reaction Compound
    my $oldRxnCpds = $self->get_objects("cpdrxn", { 'REACTION' => $oldId});
    foreach my $rxnCpd (@$oldRxnCpds) {
        $rxnCpd->delete();
    }
    # Reaction Grouping
    my $newRxnGrps = $self->get_objects("rxngrp", { "REACTION" => $newId});
    my %newRxnGrpHash = map { $_->grouping() => $_->type() } @$newRxnGrps;
    my $oldRxnGrps = $self->get_objects("rxngrp", { "REACTION" => $oldId});
    foreach my $rxnGrp (@$oldRxnGrps) {
        if (defined($newRxnGrpHash{$rxnGrp->grouping()}) &&
            $newRxnGrpHash{$rxnGrp->grouping()} eq $rxnGrp->type()) {
            $rxnGrp->delete();
        } else {
            $rxnGrp->REACTION($newId);
        }
    }
    # Reaction Complex
    my $newRxnCpxs = $self->get_objects("rxncpx", { "REACTION" => $newId});
    my %newRxnCpxHash = map { $_->COMPLEX() => $_ } @$newRxnCpxs;
    my $oldRxnCpxs = $self->get_objects("rxncpx", { "REACTION" => $oldId});
    foreach my $rxnCpx (@$oldRxnCpxs) {
        if(defined($newRxnCpxHash{$rxnCpx->COMPLEX()})) {
            $rxnCpx->delete();
        } else {
            $rxnCpx->REACTION($newId);
        }
    }
    # Reaction Model
    my $newRxnMdls = $self->get_objects("rxnmdl", { "REACTION" => $newId});
    my %newRxnMdlHash = map { $_->MODEL() => $_->compartment() } @$newRxnMdls;
    my $oldRxnMdls = $self->get_objects("rxnmdl", { "REACTION" => $oldId});
    foreach my $rxnMdl (@$oldRxnMdls) {
        if(defined($newRxnMdlHash{$rxnMdl->MODEL()}) &&
            $newRxnMdlHash{$rxnMdl->MODEL()} eq $rxnMdl->compartment()) {
            $rxnMdl->delete();
        } else {
            $rxnMdl->REACTION($newId);
        }
    }
    # Now delete the old reaction
    my $oldRxns = $self->get_objects("reaction", { "id" => $oldId});
    $oldRxns->[0]->delete() if(@$oldRxns > 0);
    # Now create the obsolete alias 
    my $rxnalsObs = $self->get_object("rxnals", { "REACTION" => $newId, "type" => "obsolete", "alias" => $oldId});
    unless(defined($rxnalsObs)) {
        $self->create_object("rxnals", { "REACTION" => $newId, "type" => "obsolete", "alias" => $oldId});
    }
    return $self->success();
}

sub validateModelDB {
    my ($self) = @_;
    my $output = "";    
    # Find compounds and reaction model aliases that
    # contradict eachother
#    my $publishedModels = [];
#    my $models = $self->get_objects("models", {});
#    foreach my $model (@$models) {
#        if ($model->source() =~ /^PMID/) {
#            push(@$publishedModels, $model->id());
#        }
#    }
#    my $cpdAlsHash = {};
#    my $badAlses = [];
#    foreach my $model (@$publishedModels) {
#        my $cpdAlses = $self->get_objects("cpdals", { "type" => $model->id() });
#        foreach my $cpdals (@$cpdAlses) {
#            if (defined($cpdAlsHash{$cpdals->alias()}) &&
#                $cpdAlshash{$cpdals->alias()}->type() ne $cpdals->type()) {
#                push(@$badAlses, $cpdals);
#            } elsif (defined($cpdAlsHash{$cpdals->alias()})) 
#                next;
#            } else {
#                $cpdAlsHash{$cpdals->alias()} = $cpdals;
#            }
#        }
#    }
#    foreach my $als (@badAlses) {
#        $output .= $als->COMPOUND() . "\t" . $als->type() . "\t" . $als->alias() . "\n";
#    }
                
    # Find reactions that differ by only one or 2 compounds
    my $allCpds = $self->get_objects("compound", {});
    my %allCpdsHash = map { $_->id() => 1 } @$allCpds;
    my $cpdPos = 0;
    foreach my $cpd (sort keys %allCpdsHash) {
        $allCpdsHash{$cpd} = $cpdPos;
        $cpdPos++;
    }
    my $allRxns = $self->get_objects("reaction", {});
    my %rxnPosHash;
    my $rxnCpdMatrix = [];
    my $pos = 0;
    my @emptyRxnArray = map { 0 } (0 .. scalar(keys %allCpdsHash));
    foreach my $rxn (@$allRxns) {
        $rxnPosHash{$pos} = $rxn->id();
        $pos++; 
        my $eq = $rxn->equation();
        my @rxnRow = @emptyRxnArray;
        while ( $eq =~ /(cpd\d\d\d\d\d)/g) {
            $rxnRow[$allCpdsHash{$1}] = 1;
        }
        push(@$rxnCpdMatrix, join('',@rxnRow));
    }
#    my $gobalBitString = join('', @$rxnCpdMatrix);
    my @interestingRxns;
#    {
#        use Bit::Vector;
#        for(my $i=0; $i<@$rxnCpdMatrix; $i++) {
#            my $diff = $rxnCpdMatrix->[$i] ^ $rxnCpdMatrix->[$j];
#            my $a = Bit::Vector->new_Bin(length($rxnCpdMatrix->[$i]), $rxnCpdMatrix->[$i]);
#            my $b = Bit::Vector->new_Bin(length($rxnCpdMatrix->[$j]), $rxnCpdMatrix->[$j]);
#            $a->Xor($a,$b); 
#            my $count = 0;
#            while(!$a->is_empty()) {
#                $count++;
#                $b->Copy($a);
#                $b->decrement();
#                $a->And($a, $b);
#            }
#            if ($count > 0 && $count < 3) {
#                push(@interestingRxns, [$rxnPosHash{$i}, $rxnPosHash{$j}])
#            }
#        }
#    }
    return \@interestingRxns;
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
=head3 parseMetagenomeDataTable
Definition:
	Output {} = FIGMODELgenome->parseMetagenomeDataTable({
		filename => string:name of the file with the metagenome data
	});
	Output = {};
Description:
=cut
sub parseMetagenomeDataTable {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	if (defined($args->{error})) {return $self->error_message({function => "parseMetagenomeDataTable",args => $args});}
	my $data = $self->figmodel()->database()->load_single_column_file($args->{filename},"");
	my $metagenomeData;
	for (my $i=1; $i < @{$data}; $i++) {
		my @array = split(/\t/,$data->[$i]);
		push(@{$metagenomeData->{$array[0]}},[@array]);
	}
	foreach my $genome (keys(%{$metagenomeData})) {
		my $currentPeg = 1;
		my $output = ["ID\tGENOME\tROLES\tSOURCE\tABUNDANCE\tAVG EVALUE\tAVG IDENTITY\tAVG ALIGNMENT\tPROTEIN COUNT"];
		for (my $i=0; $i < @{$metagenomeData->{$genome}}; $i++) {
			my $line = "mgrast|".$genome.".peg.".$currentPeg."\t".$genome."\t".$metagenomeData->{$genome}->[$i]->[4]."\tMGRAST\t";
			$line .= $metagenomeData->{$genome}->[$i]->[5]."\t".$metagenomeData->{$genome}->[$i]->[6]."\t";
			$line .= $metagenomeData->{$genome}->[$i]->[7]."\t".$metagenomeData->{$genome}->[$i]->[8]."\t";
			$line .= $metagenomeData->{$genome}->[$i]->[9];
			push(@{$output},$line);
			$currentPeg++;
		}
		$self->figmodel()->database()->print_array_to_file($self->figmodel()->config("Metagenome directory")->[0].$genome.".tbl",$output);
	}
}
=head3 printMFAToolkitDatabaseTables
Definition:
	undef = FIGMODELdatabase->printMFAToolkitDatabaseTables({});
Description:
=cut
sub printMFAToolkitDatabaseTables {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $functionHash = {
		"get_reaction" => undef,
		"get_compound" => undef,
		"get_media" => {printList=>["ALL"]},
	};
	foreach my $function (keys(%{$functionHash})) {
		$self->figmodel()->$function()->printDatabaseTable($functionHash->{$function});
	}
}
=head3 createIntegratedBiochemistryTables
Definition:
	undef = FIGMODELdatabase->createIntegratedBiochemistryTables({});
Description:
=cut
sub createIntegratedBiochemistryTables {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $functionHash = {
		"get_reaction" => undef,
		"get_compound" => undef,
		"get_media" => {printList=>["ALL"]},
	};
	foreach my $function (keys(%{$functionHash})) {
		$self->figmodel()->$function()->printDatabaseTable($functionHash->{$function});
	}
}

1;
