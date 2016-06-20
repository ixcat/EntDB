
package User::EntDB::Command::DumpGroup;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::Group;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;
	my $self = {
		'app' => $app,
		'cmdname' => 'dumpgroup',
		'shorthelp' => "dumpgroup dbfile: dump /etc/group file\n",
		'longhelp' => "dumpgroup dbfile\n"
		. " where: dbfile is the path to the desired database file\n"
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

	my $entdb = User::EntDB->new($fname);
	if(!$entdb) {
		print STDERR "error: $!\n";
		return 1;
	}

	my $glist = User::EntDB::Group::getDBGroupList($entdb);

	foreach my $group (@{$glist}) {
		print $group->toGroup() . "\n";
	}
	return 0;
}

1;

