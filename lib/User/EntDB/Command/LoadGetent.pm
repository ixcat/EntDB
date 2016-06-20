
package User::EntDB::Command::LoadGetent;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::User;
use User::EntDB::Group;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "loadgetent: db\n\n"
	. "load database file 'db' using system getent(3) calls.\n"
	. "\n"
	. "This command uses native getpwent(3) and getgrent(3) calls to\n"
	. "populate the database file given in the 'db' argument.\n";

	my $self = {
		'app' => $app,
		'cmdname' => 'loadgetent',
		'shorthelp' => "loadgetent db: load db from getent data\n",
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my $fname = shift @{$args};
	if (!$fname) {
		print $self->{app}->help($self->{cmdname});
                return 0;
	}

	my $err = 0;

	$err = 1 if !defined(
		User::EntDB::User::loadAllUsersFromSystem($fname)
	);
	$err = 1 if !defined(
		User::EntDB::Group::loadAllGroupsFromSystem($fname)
	);

	return $err;
}

1;

