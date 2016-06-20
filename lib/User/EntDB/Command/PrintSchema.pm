
package User::EntDB::Command::PrintSchema;

use strict;
use warnings;

use User::EntDB;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "schema\n"
	. " print the reference SQLite3 schema for the EntDB database\n";

	my $self = {
		'app' => $app,
		'cmdname' => 'schema',
		'shorthelp' => "schema: dump reference db schema\n",
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	print User::EntDB->new()->schema();
	return 0;
}

1;

