
package User::EntDB::Command::LoadNetgroup;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::Netgroup;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "loadnetgroup db [file]\n\n"
	. "load 'file' or /etc/netgroup into database file 'db'.\n"
	. "\n"
	. "This command directly parses the input file \n"
	. "populate the database file given in the 'db' argument.\n";

	my $self = {
		'app' => $app,
		'cmdname' => 'loadnetgroup',
		'shorthelp' => 
			"loadnetgroup db [file]: load db with netgroup data\n",
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my $dbfname = shift @{$args};
	my $ngfname = shift @{$args} or undef;
	if (!$dbfname) {
		print $self->{app}->help($self->{cmdname});
                return 0;
	}

	if($ngfname) {
		$User::Netgroup::NETGROUPFILE = $ngfname;
	}

	my $err = 0;	
	$err = 1 if !defined(
		User::EntDB::Netgroup::loadAllNetgroupsFromSystem($dbfname)
	);

	return $err;
}

1;

