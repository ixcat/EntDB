
package User::EntDB::Command::LoadMailAliases;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::MailAlias;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;

	my $longhelp = "loadmailaliases db [file]\n\n"
	. "Load aliases(5) file 'file' into database 'db'.\n\n"
	. "If not given, 'file' defaults to '/etc/mail/aliases'\n\n";

	my $self = {
		'app' => $app,
		'cmdname' => 'loadmailaliases',
		'shorthelp' =>
		"loadmailaliases db [file]: load db with aliases(5) data\n",
		'longhelp' => "zee long help\n"
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
	my $aliases = shift @{$args};
	$aliases = '/etc/mail/aliases' unless $aliases;

	if(!($dbfname && $aliases)) {
                $self->{app}->help($self->{cmdname});
                return 0;
	}

	$kvargs->{fname} = $aliases;

	my $kv = User::EntDB::MailAlias->new($kvargs);
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
