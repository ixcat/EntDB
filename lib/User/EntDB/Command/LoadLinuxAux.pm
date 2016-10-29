
#
# load linux-specific /etc/shadow aux account information
#
# (e.g. expiry, changedate, etc)
#
# Requires the getent(1) utility be installed to retrieve the 
# information from the system.
# 

package User::EntDB::Command::LoadLinuxAux;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::User;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $shorthelp = "loadlinuxaux db: load aux password information\n";
	my $longhelp = "loadlinuxaux: db\n\n"
	. "load aux linux password information into database file 'db'\n"
	. "\n"
	. "This command parses output from the getent(1) command to ingest\n"
	. "extra linux-specific password information into the database.\n"
	. "\n"
	. "This information is stored in the aux_users table and is used to\n"
	. "supplement information collected by the 'loadgetent' command.\n";

	my $self = {
		'app' => $app,
		'cmdname' => 'loadlinuxaux',
		'shorthelp' => $shorthelp,
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

	# FIXME: doesn't err if table not present? herm.
	$err = 1 if !defined(
		User::EntDB::User::loadAllLinuxAuxDataFromSystem($fname)
	);

	return $err;
}

1;

