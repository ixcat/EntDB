
# User::EntDB::User
#
# user representation class
# partial-(view)wrapper around User::pwent currently
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

use User::pwent;

sub new;
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

sub convertUserListToSQL;

# hmm.. really should inherit from User::pwent -
#   for now, just wrap.

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;
	return $self;
}

sub fromPwent {
	my $self = User::EntDB::User->new();
	my $pwent = shift;
	$self->{pwent} = $pwent;	
	return $self; 
}

# create an sqlite insert statement -
# specifically *not* using DBI here to allow for 'text output' case.

sub toSQLite {

	my $self = shift;
	my $pwent = $self->{pwent};

	# v7 fields for max compat.
	my $name = $pwent->name;
	my $passwd = $pwent->passwd;
	my $uid = $pwent->uid;
	my $gid = $pwent->gid;
	(my $gecos = $pwent->gecos) =~ s:':'':; # escape commas
	my $dir = $pwent->dir;
	my $shell = $pwent->shell;

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
	
	my $r = $p->{uname}
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

	my $r = $p->{uname}
		. ':##' . $p->{uname}
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

	my $r = $p->{uname}
		. ':' . $p->{passwd}
		. ':1' # lastchange - 0 implies changenow
		. ':0' # minage
		. ':99999' # empty disables aging
		. ':7' # expiry warning period
		. ':' # inactivity grace period - blank off
		. ':' # expiry date (unixdays)
		. ':'; # reserved

	return $r;
}

sub toPasswdAdjunct {
	my $self = shift;
	my $p = $self->{pwent};

	my $r = $p->{uname}
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
		push @{$ulist}, User::EntDB::User::fromPwent($u);
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

	push @{$sqlist}, 
		"insert into hashes_default select uname,passwd from users;\n";
	push @{$sqlist},
		"insert into hashes_bcrypt select uname,passwd from users;\n";
	push @{$sqlist},
		"insert into hashes_md5 select uname,passwd from users;\n";

	# todo: verify adjunct '*' properly works before deploying this..
	push @{$sqlist}, "update users set passwd= '##' || uname;\n";

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

1;
