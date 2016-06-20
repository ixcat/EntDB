
package User::EntDB::Command::LoadKeyValue;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::KeyValue;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "loadkeyvalue db file [table] [splitrx] [multirx]\n\n"
	. "Load 'file' into database 'db', table 'table'.\n\n"
	. "The keys/values are split according to splitrx,\n"
	. "and multiple value strings optionally split by multirx.\n\n"
	. "If not given, table defaults to the table 'kv',\n"
	. "with splitrx splitting according to whitespace,\n"
	. "and multirx not being utilized to split multiple values.\n"
	;

	my $self = {
		'app' => $app,
		'cmdname' => 'loadkeyvalue',
		'shorthelp' => 
		"loadkeyvalue db file [table] [splitrx] [multirx]: "
		. "load db with key/value data\n",
		'longhelp' => $longhelp
	};

	bless $self,$class;
	$app->register($self);
	return $self;
}

sub do {
	my $self = shift;
	my $args = shift;
	my $kvargs = {};

	my $dbfname = shift @{$args};
	my $fname = shift @{$args};

	if(!($dbfname && $fname)) {
		print $self->{app}->help($self->{cmdname});
		return 0;
	}

	my $tname = shift @{$args};
	my $rx = shift @{$args};
	my $multi = shift @{$args};

	$kvargs->{fname} = $fname;

	$kvargs->{tname} = $tname if defined $tname;
	$kvargs->{rx} = $rx if defined $rx;
	$kvargs->{multi} = $multi if defined $multi;

	my $kv = User::EntDB::KeyValue->new($kvargs);

	if(!$kv) {
		print STDERR "error: $!\n";
		return 1;
	}

	if(!defined($kv->loadAllKeyValuesFromFile($dbfname))) {
		print STDERR "error: $!\n";
		return 1;
	}
	return 0;

}

1;

