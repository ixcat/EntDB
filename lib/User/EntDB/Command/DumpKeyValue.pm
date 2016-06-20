
package User::EntDB::Command::DumpKeyValue;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::KeyValue;

sub new;
sub do;

my $def_fmt = 'sub { my ($k,$v) = @_; return "$k $v\n" }';

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "dumpkeyvalue db [multi] [table] [fmtstr]\n\n"
	. "Dump key/value table 'table' from database 'db',\n"
	. "according to the multiplicity indicator multi.\n\n"
	. "and the optional subroutine text 'fmtstr'.\n\n"
	. "If not given, multi is not defined,\n"
	. "table defaults to the table 'kv',\n"
	. "and fmtstr defaults to the value:\n\n"
	. " '$def_fmt'\n";
	;

	my $self = {
		'app' => $app,
		'cmdname' => 'dumpkeyvalue',
		'shorthelp' => 
		"dumpkeyvalue db [multi] [table] [fmtstr]: "
		. "dump K/V data in db table with fmtstr\n",
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

	if(!$dbfname) {
                print $self->{app}->help($self->{cmdname});
                return 0;
	}

	my $multi = shift @{$args};
	my $tname = shift @{$args};
	my $fmtstr = shift @{$args};

	$multi = undef unless $multi;
	$tname = 'kv' unless $tname;

	$fmtstr = 'sub { my ($k,$v) = @_; return "$k $v\n" }'
		unless $fmtstr;

	my $fmtsub = eval $fmtstr;

	$kvargs->{multi} = $multi;
	$kvargs->{tname} = $tname;
	$kvargs->{txtfn} = $fmtsub;

	my $kv = User::EntDB::KeyValue->new($kvargs);
	if(!$kv) {
		print STDERR "error: $!\n";
		return 1;
	}

	if(!defined($kv->dumpAllKeyValues($dbfname))) {
		print STDERR "error: $!\n";
		return 1;
	}
	return 0;

}

1;

