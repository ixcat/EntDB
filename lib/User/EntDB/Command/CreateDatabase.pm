
package User::EntDB::Command::CreateDatabase;

use strict;
use warnings;

use User::EntDB;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;
	my $self = {
		'app' => $app,
		'cmdname' => 'createdb',
		'shorthelp' => "createdb dbfile: create a database in dbfile\n",
		'longhelp' => "createdb dbfile\n"
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
	my $entdb = User::EntDB->new($fname) or return 1; # hmm: $! ? 
	return $entdb->createdb();
}

1;

