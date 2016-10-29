
# User::EntDB::User
#
# user representation class
# partial-(view)wrapper around User::pwent currently
#
# TODO: 
#
# EntDB::User uses User::pwent for ingest but hashes for dumps
# ... and fields are inconsistent btw User::pwent & database struct items
# ... so needs rework in schema, object use, possible doc updates
#     and potentially emulation of User::pwent api later if hoping to
#     keep this compatible.
#     ... think for now, the usage was simply incongruent since were only
#         dealing with completely separate load/store operations.
#         now, since we are synthesizing new records in UserAdd.pm,
#         need proper support for code generated records, which highlights
#         the problem with the previous approaches.
#
# NOTE/FIXME:
#
#   - password multi-hash storage currently somewhat hacked on -
#     fresh database builds will store return value of getpwent() 
#     in all format tables.
#
# $Id$

package User::EntDB::User;

use strict;
use warnings;

use Carp;

use User::pwent;

sub new;
sub fromPrec;
sub fromPwent;

sub toSQLite;
sub toBSDPasswd;
sub toLinuxPasswd;
sub toLinuxShadow;
sub toPasswdAdjunct;

# hmm..
#
# thinking all of the UserList stuff would make a simple class
# which is an array wrapper & also implements various toFormat
# aggregate functions.
#

sub getDBUserList;
sub getSysUserList; 

sub loadAllUsersFromSystem;
sub loadAllLinuxAuxDataFromSystem;

sub convertUserListToSQL;

# hmm.. really should inherit from User::pwent -
#   for now, just wrap.

sub new {
	my $class = shift;
	my $self = {};
	$self->{pwent} = undef;
	bless $self,$class;
	return $self;
}

sub fromPrec { # construct from k:v hash of User::pwent-like attributes
	my $self = User::EntDB::User->new();
	my $prec = shift;
	$self->{pwent} = $prec;
	return $self;
}

sub fromPwent { # construct from actual User::pwent objects
	my $self = User::EntDB::User->new();
	my $pwent = shift;
	my $prec = {};

	$prec->{name} = $pwent->name();
	$prec->{passwd} = $pwent->passwd();
	$prec->{uid} = $pwent->uid();
	$prec->{gid} = $pwent->gid();
	$prec->{gid} = $pwent->gid();
	($prec->{gecos} = $pwent->gecos()) =~ s:':'':; # escape hyphens
	$prec->{dir} = $pwent->dir();
	$prec->{shell} = $pwent->shell();

	$self->{pwent} = $prec;	
	return $self; 
}

# create an sqlite insert statement -
# specifically *not* using DBI here to allow for 'text output' case.

sub toSQLite {

	my $self = shift;
	my $pwent = $self->{pwent};

	# v7 fields for max compat.
	my $name = $pwent->{name};
	my $passwd = $pwent->{passwd};
	my $uid = $pwent->{uid};
	my $gid = $pwent->{gid};
	my $gecos = $pwent->{gecos};
	my $dir = $pwent->{dir};
	my $shell = $pwent->{shell};

	my $q .= "insert into users values ("
	. "'" . $name . "'"
	. ",'" . $passwd . "'"
	. ",'" . $uid . "'"
	. ",'" . $gid . "'"
	. ",'" . $gecos . "'"
	. ",'" . $dir . "'"
	. ",'" . $shell . "'"
	. ");\n";

	return $q;

}

sub toBSDPasswd {
	my $self = shift;
	my $p = $self->{pwent};
	
	my $r = $p->{name}
	. ':' . $p->{passwd}
	. ':' . $p->{uid}
	. ':' . $p->{gid}
	. ':'  # got no class. a classless society. yuk
	. ':0' # changetime herm
	. ':0' # expire
	. ':' . $p->{gecos}
	. ':' . $p->{dir}
	. ':' . $p->{shell};

	return $r;
}

sub toLinuxPasswd {
	my $self = shift;
	my $p = $self->{pwent};

	my $r = $p->{name}
		. ':##' . $p->{name}
		. ':' . $p->{uid}
		. ':' . $p->{gid}
		. ':' . $p->{gecos}
		. ':' . $p->{dir}
		. ':' . $p->{shell};

	return $r;
}

sub toLinuxShadow {
	my $self = shift;
	my $p = $self->{pwent};

	my $fix = sub {
		return defined($_[0]) ? $_[0] : $_[1];
	};

	my $r = $p->{name}
		. ':' . $p->{passwd}
		. ":" . $fix->($p->{lastchg},'1')
		. ":" . $fix->($p->{minage},'0')
		. ":" . $fix->($p->{maxage},'99999') # 0 -> disable
		. ":" . $fix->($p->{warning},'7')
		. ":" . $fix->($p->{inactivity},'') # blank -> off
		. ":" . $fix->($p->{expiration},'')
		. ":" . $fix->($p->{reserved},'')
	;

	return $r;
}

sub toPasswdAdjunct {
	my $self = shift;
	my $p = $self->{pwent};

	my $r = $p->{name}
		. ':' . $p->{passwd}
		. ':' # min-label
		. ':' # max-label
		. ':' # default-label
		. ':' # always-audit-flags
		. ':'; # never-audit-flags

	return $r;
}

sub getDBUserList {
	my $entdb = shift;

	my $ulist = [];

	while(my $u = $entdb->getpwent()) {
		push @{$ulist}, User::EntDB::User::fromPrec($u);
	}
	return $ulist;
}

sub getSysUserList { # static. returns arrayref of User::EntDB::User objects
	my $ulist = [];
	while (my $rec = User::pwent::getpwent()) {
		my $u = User::EntDB::User::fromPwent($rec);
		push @{$ulist}, $u;
	}
	return $ulist;
}

sub convertUserListToSQL { # generate array of SQL cmds to build user tables

# XXX: including HACKED multi-hash stuff

	my $ulist = shift;
	my $sqlist = [];
	foreach my $u (@{$ulist}) {
		my $stmt = $u->toSQLite();
		push @{$sqlist}, $stmt;
	}

	# FIXME : race condition on secondary updates 
	# hashes will be zapped on second call of this function on same DB
	# .. so now using temp table - but will yield dupes..

	push @{$sqlist},
		"create temporary table _convertUserListToSQLu"
		. " (user text);\n"
	;

	foreach my $u (@{$ulist}) {
		push @{$sqlist}, "insert into _convertUserListToSQLu"
			. "(user) values ('" . $u->{pwent}->{name} . "');\n";
	}

	push @{$sqlist}, 
		"delete from hashes_default where name in"
		. " (select * from _convertUserListToSQLu)"
		. ";\n"
	;
	push @{$sqlist}, 
		"insert into hashes_default select name,passwd from users"
		. " where name in (select * from _convertUserListToSQLu)"
		. ";\n"
	;

	push @{$sqlist}, 
		"delete from hashes_bcrypt where name in"
		. " (select * from _convertUserListToSQLu)"
		. ";\n"
	;
	push @{$sqlist}, 
		"insert into hashes_bcrypt select name,passwd from users"
		. " where name in (select * from _convertUserListToSQLu)"
		. ";\n"
	;

	push @{$sqlist}, 
		"delete from hashes_md5 where name in"
		. " (select * from _convertUserListToSQLu)"
		. ";\n"
	;
	push @{$sqlist}, 
		"insert into hashes_md5 select name,passwd from users"
		. " where name in (select * from _convertUserListToSQLu)"
		. ";\n"
	;

	# todo: verify adjunct '*' properly works before deploying this..
	push @{$sqlist}, "update users set passwd= '##' || name"
		. " where name in (select * from _convertUserListToSQLu)"
		. ";\n"
	;

	push @{$sqlist}, "drop table _convertUserListToSQLu;\n";

	return $sqlist;
}

sub loadAllUsersFromSystem { # full getent->sqlite conversion of all users
	my $fname = shift;

	return undef unless $fname;

	my $entdb = User::EntDB->new($fname);
	my $ulist = User::EntDB::User::getSysUserList();
	my $sqlist = User::EntDB::User::convertUserListToSQL($ulist);

	$entdb->begintxn();
	foreach my $usersql (@{$sqlist}) {
		$entdb->do($usersql);
	}
	$entdb->endtxn();
}

sub loadAllLinuxAuxDataFromSystem {
	my $fname = shift;

	return undef unless $fname;

	my $entdb = User::EntDB->new($fname);

	if ($^O ne 'linux') {
		carp "loadAllLinuxAuxDataFromSystem on non-linux system..";
		return 1;
	}

	my $gefh = undef;
	if(!open($gefh, "getent shadow |" )) {
		$gefh = undef;
		return $gefh;
	}

	# fields
	my $name = 0;		# accountname
	my $passwd = 1;		# enc pass (not used here - see hash tables)
	my $lastchg = 2;	# last change
	my $minage = 3;		# min days before rechange
	my $maxage = 4;		# max days before change
	my $warning = 5;	# pending change warning days
	my $inactivity = 6;	# days allowed after expire
	my $expiration = 7;	# account expiration date
	my $reserved = 8;	# unused

	my $fix = sub {
		return defined($_[0]) ? $_[0] : $_[1];
	};

	$entdb->begintxn();
	while (<$gefh>) {
		chomp;
		my $items = [ split /:/, $_ ];

		my $q = "insert into aux_users_linux values ("
			. $fix->("'" . $items->[$name] . "'",'null') . ","
			. $fix->($items->[$lastchg],'null'). ","
			. $fix->($items->[$minage],,'null') . ","
			. $fix->($items->[$maxage],'null') . ","
			. $fix->($items->[$warning],'null') . ","
			. $fix->($items->[$inactivity],'null') . ","
			. $fix->($items->[$expiration],'null') . ","
			. $fix->($items->[$reserved],'null')
		. ");\n";
		$entdb->do($q);
	}
	$entdb->endtxn();

	my $err = 0;
}

1;

