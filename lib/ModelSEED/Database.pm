package ModelSEED::Database;

use Moose::Role;

requires 'has_object';

requires 'get_object';

requires 'save_object';

requires 'delete_object';

requires 'set_alias';

requires 'remove_alias';

requires 'get_permissions';

requires 'set_permissions';

requires 'get_user_uuids';

requires 'get_user_aliases';

requires 'add_user';

requires 'get_user';

requires 'authenticate_user';

requires 'remove_user';

1;
