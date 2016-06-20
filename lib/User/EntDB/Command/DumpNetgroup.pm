
package User::EntDB::Command::DumpNetgroup;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::Netgroup;

sub new;
sub do;

sub new {
	my $class = shift;
	my $app = shift;
	my $self = {
		'app' => $app,
		'cmdname' => 'dumpnetgroup',
		'shorthelp' => "dumpnetgroup dbfile: dump /etc/netgroup file\n",
		'longhelp' => "dumpnetgroup dbfile\n"
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

	my $nglist = User::EntDB::Netgroup::getDBNetgroupList($entdb);

        print "# /etc/netgroup\n";
        print "# generated by "
		. $self->{app}->{appname} 
		. " from $fname\n";

	foreach my $ng (@{$nglist}) {
		print $ng->toEtcNetgroup() . "\n";
	}
	return 0;
}

1;

