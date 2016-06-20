
package User::EntDB;

$VERSION = 0.01;

use strict;
use warnings;

use Carp;

use DBI;
use DBD::SQLite;

use User::EntDB::Schema::SQLite;

# Interface
# ---------

# connection mgmt

sub new;
sub connect;
sub createdb;
sub schema;

sub begintxn;
sub do;
sub endtxn;

# object methods

sub addUser;		# not implemented
sub addGroup;		# not implemented

sub sethashfmt;		# set hash dispatch
sub _checkhashfmt; 	# ensure hash format selected
sub storehashes;	# store password hashes in db

# Unix & User::pwent-alikes
#
# Note:
#
#   getpwent/getgrent simply query all available records on 1st use,
#   and then return individual results until/unless setpwent/setgrent
#   is called to repeat the query. 

sub getpwent;
sub getpwnam;
sub getpwuid;
sub setpwent;

sub getgrent;
sub getgrnam;
sub getgruid;
sub setgrent;

sub nextnetgrent;	# INPROG
sub getnetgrent;	# NI (dependant on _ng_addgroup for expansion 1st)
sub innetgr;		# NI
sub setnetgrent;	# INPROG (for local 'null' arg version)
sub endnetgrent;	# NI
sub _ng_addgroup;	# expansion routine in OB, called from setnetgrent
sub _ng_lookup;		# called within addgroup to get raw group data per group
sub _ng_fetchall;	# local raw data query

# generic key/value tables

sub _kv_fetchall;	# fetch all rows in key/value table of tablename

# Implementation
# --------------

sub new {
	my $class = shift;
	my $fname = shift;

	my $self = {};
	$self->{dbh} = undef;
	$self->{dburi} = undef;
	$self->{hashfmt} = 'default';

	$self->{npwents} = undef;
	$self->{pwents} = undef;

	$self->{ngrents} = undef;
	$self->{grents} = undef;

	$self->{nnetgrents} = undef;
	$self->{netgrents} = undef;

	if($fname) {
		User::EntDB::connect($self,$fname) or return undef;
	}

	bless $self,$class;
	return $self;
}

sub connect {
	my ($self,$fname) = @_;

	my $dburi = "dbi:SQLite:$fname";
	my $dbh = DBI->connect($dburi);

	if(!$dbh) {
		carp "unable to connect to $dburi: $!\n";
		return undef;
	}

	$dbh->do('pragma journal_mode = truncate');

	$self->{dburi} = $dburi;
	$self->{dbh} = $dbh;

	return $dbh;
}

sub createdb {
        my $self = shift;

        my ($dbh,$sth);
        my $schema = User::EntDB::Schema::SQLite::getSchema();

        $dbh = $self->{dbh};

        if(!$dbh) {
                carp "createdb on unconnected object";
                return 1;
        }

	$self->do($schema);

        return 0;
}

sub schema {
	return User::EntDB::Schema::SQLite::getSchema();
}

sub begintxn {
	my $self = shift;
	my $dbh = $self->{dbh};

	if(!$dbh) {
		carp "begintxn on unconnected object";
		return 1;
	}

	$dbh->do('begin transaction');
}

# hackish simple wrapper for dbd 'do' with newline splitting
# TOTAL HACK
# ... to allow single-string hackish querying.
# ... and also keeping ::Schema intact, 
#     and concievablly/eventually in separate file..
#     for now, ensure there are no semicolons in SQL comments..
#     and all should be well.

sub do { 
	my $self = shift;
	my $sql = shift;
	my $dbh = $self->{dbh};
	if(!$dbh) {
		carp "begintxn on unconnected object";
		return 1;
	}
	foreach (split ';', $sql) {
		chomp;
		next if $_ =~ m:^$:;
        	$dbh->do($_);
	}
}

sub endtxn {
	my $self = shift;
	my $dbh = $self->{dbh};

	if(!$dbh) {
		carp "begintxn on unconnected object";
		return 1;
	}

	$dbh->do('commit');
}

# XXX: todo - document this much more
#
# - 'default as ingest', 
# - use of 'default selection' in generation/updating
# - assumption that all defined tables have some value for valid users
#   so 'update' statement works
# - use of hardcoded md5 in bin/dbpass 
#

sub sethashfmt {
	my ($self,$desired) = @_;
	my ($dbh,$sth,$hcfg,$fmttab);
	$dbh = $self->{dbh};

	if(!$dbh) {
		carp "sethashfmt on unconnected object";
		return 1;
	}

	if(!$desired) {
		$desired = 'default';
	}

	$sth = $dbh->prepare("select * from hash_cfg");
	$sth->execute;

	$hcfg = $sth->fetchall_hashref('platform'); # return tmp hashes
	$fmttab = $hcfg->{$desired}->{type};

	if(!$fmttab) { # check desired, fall back to default
		carp "no hash format table configuration"
			. "for desired format $desired\n";
		$desired = 'default';
		$fmttab = $hcfg->{$desired}->{type};
	}

	if(!$fmttab) { # no desired or default
		croak "no suitable hash format table available";
	}

	$self->{hashfmt} = $desired;
	$self->{fmttab} = $fmttab;

	return 0;
}

sub _checkhashfmt { # ensure a hash format is selected for use
	my $self = shift;
	my $fmttab = $self->{fmttab};
	if(!$fmttab) {
		$self->sethashfmt();
	}
}

sub storehashes {
	my ($self, $args) = @_;
	my $dbh = $self->{dbh};

	my ($uname);

	if(!$dbh) {
		carp "storehashes on unconnected object";
		return 1;
	}

	$self->_checkhashfmt();

	# verify user exists (and eventually, is not *deliberately* locked)

	$uname = $args->{uname};
	return 1 unless $self->getpwnam($uname); # FIXME: ENOENT

	# and update password for all hash types

	while(my ($fmt,$hpw) = each %{$args->{hashes}}) {

		my $sth = $dbh->prepare("
			update hashes_$fmt
			set passwd=? 
			where uname=?
		");
	
		my $result = $sth->execute($hpw,$uname);
		return 1 if $result < 1;
	}

	return 0;
}

sub getpwent {
	my $self = shift;

	my ($pwents,$npwents) = undef;
	$npwents = $self->{npwents};

	if(!defined($npwents)) {	# 1st call - initialize iteration
		$self->setpwent;
		$npwents = $self->{npwents};
	}

	if ($npwents > 0) {
		$self->{npwents}--;
		return shift @{$self->{pwents}};
	}
	else {
		return undef; # done iterating
	}
}

sub getpwnam {
	my ($self,$desired) = @_;

	my ($pwents, $npwents) = undef;

	$npwents = $self->{npwents};

	if(!defined($npwents)) {	# 1st call - initialize iteration
		$self->setpwent;
		$npwents = $self->{npwents};
	}
	if ($npwents > 0) {
		foreach my $ent (@{$self->{pwents}}) {
			return $ent if $ent->{uname} eq $desired;
		}
		return undef; # done iterating
	}
	return undef; # no pwents
}

sub getpwuid; # TODO

sub setpwent { # setpwent: reset internal pwent handle
	my $self = shift;
	my ($dbh,$sth,$fmttab,$pwents);

	$dbh = $self->{dbh};

	if(!$dbh) {
                carp "setpwent on unconnected object";
                return 1;
        }

	$self->_checkhashfmt();
	$fmttab = $self->{fmttab};

	$sth = $dbh->prepare("
		select u.uname, p.passwd, u.uid, u.gid, u.gecos, u.dir, u.shell
		from users u, hashes_$fmttab p
		where u.uname = p.uname
	");

	$sth->execute;

	$pwents = $sth->fetchall_arrayref({}); # return hashes

	if(!defined($pwents)) {
		$self->{npwents} = undef;
	}
	else {
		$self->{npwents} = scalar $pwents;
	}

	$self->{pwents} = $pwents;
}

sub getgrent { # getgrent: 
	my $self = shift;

	my ($grents,$ngrents) = undef;
	$ngrents = $self->{ngrents};

	if(!defined($ngrents)) {	# 1st call - initialize iteration
		$self->setgrent;
		$ngrents = $self->{ngrents};
	}

	if ($ngrents > 0) {
		$self->{ngrents}--;
		return shift @{$self->{grents}};
	}
	else {
		return undef; # done iterating
	}
}

sub setgrent { # setgrent: reset internal grent handle

	my $self = shift;
	my ($dbh,$sth,$tgrents,$hgrents,$gseq,$rgrents);

	$dbh = $self->{dbh};

	if(!$dbh){ 
		carp "setgrent on unconnected object";
		return 1;
	}

	$sth = $dbh->prepare("select * from etc_group");

	$sth->execute;

	$tgrents = $sth->fetchall_arrayref({}); # return tmp hashes

	if(!defined($tgrents)) {
		$self->{ngrents} = undef;
	}
	else {
		# Synthesize grents from list of members
		#
		# XXX: we assume singular gid for gname -
		#    this matches getgrnam(3) lookup,
		#    and would align with both getgrent(3), which
		#    reads sequentially, and getgruid(3), which
		#    finds the first matching uid, given a numerically
		#    sorted /etc/group.

		my ($tg,$gn,$gi,$un);

		foreach $tg (@{$tgrents}) {

	 		$gn = $tg->{gname};
	 		$gi = $tg->{gid};
	 		$un = $tg->{uname};

			if(!defined $hgrents->{$gn}) { # make actual grent
				$hgrents->{$gn} = {
					'name' => $gn,
					'gid' => $gi,
					'members' => []
				};
				push @{$gseq}, $gn; # keeping sequence
			}
			push @{$hgrents->{$gn}->{members}}, $un if $un;
		}
		foreach $gn (@{$gseq}) { # and rebuild the sequence
			push @{$rgrents}, $hgrents->{$gn};
		}
		$self->{ngrents} = scalar $rgrents;
		$self->{grents} = $rgrents;
	}
}

sub nextnetgrent {
	my $self = shift;

	my ($netgrents,$nnetgrents) = undef;
	$nnetgrents = $self->{nnetgrents};

	if(!defined($nnetgrents)) {	# 1st call - initialize iteration
		$self->setnetgrent();
		$nnetgrents = $self->{nnetgrents};
	}

	if ($nnetgrents > 0) {
		$self->{nnetgrents}--;
		return shift @{$self->{netgrents}};
	}
	else {
		return undef; # done iterating
	}

}

sub setnetgrent {
	my $self = shift;
	my $curgroup = shift;
	my ($dbh,$sth,$rows,$seq,$ngs,$ret);

	if($curgroup) { # TODO: proper netgroup api
		carp "setnetgrent group selection not implemented\n";
		return undef;
	}

	# load and rebuild netgroup items

	$dbh = $self->{dbh};

	if(!$dbh) {
		carp "setnetgrent on unconnected object";
		return undef;
	}

	$sth = $dbh->prepare("select * from netgrent");

	$sth->execute;

	$rows = $sth->fetchall_arrayref({}); # return temp hashes

	return undef if scalar $rows < 1;

	$seq = [];
	$ngs = {};
	$ret = [];

	foreach my $row (@{$rows}) {
		my $ngname = $row->{netgroup};

                my $mem = {
                        'ref' => $row->{ref},
                        'host' => $row->{host},
                        'user' => $row->{user},
                        'domain' => $row->{domain}
                };

                if(!exists $ngs->{$ngname}) {
                        $ngs->{$ngname} = {
                                'netgroup' => $ngname,
                                'entries' => [ $mem ]
                        };
                        push @{$seq}, $ngname;
                }
                else {
                        push @{$ngs->{$ngname}->{entries}}, $mem;
                }
        }

        foreach my $ngname (@{$seq}) {
                push @{$ret}, $ngs->{$ngname};
        }

	$self->{nnetgrents} = scalar $ret;
	$self->{netgrents} = $ret;

}



# fetch all data from netgroup table

sub _ng_fetchall  {

	my $self = shift;
	my ($dbh,$sth,$rows,$seq,$ngs,$ret);

	$dbh = $self->{dbh};

	if(!$dbh){ 
		carp "_ng_fetchall on unconnected object";
		return undef;
	}

	$sth = $dbh->prepare("select * from netgrent");

	$sth->execute;

	$rows = $sth->fetchall_arrayref({}); # return tmp hashes

	return undef if scalar $rows < 1;

	$seq = [];
	$ngs = {};
	$ret = [];

	foreach my $row (@{$rows}) {
		my $ngname = $row->{netgroup};

		my $mem = {
			'ref' => $row->{ref},
			'host' => $row->{host},
			'user' => $row->{user},
			'domain' => $row->{domain}
		};

		if(!exists $ngs->{$ngname}) {
			$ngs->{$ngname} = {
				'netgroup' => $ngname,
				'entries' => [ $mem ]
			};
			push @{$seq}, $ngname;
		}
		else {
			push @{$ngs->{$ngname}->{entries}}, $mem;
		}
	}

	foreach my $ngname (@{$seq}) {
		push @{$ret}, $ngs->{$ngname};
	}
	return $ret;
}

sub _kv_fetchall {
	my $self = shift;
	my $tname = shift;

	if(!$tname) {
		carp "_kv_fetchall - no table name given\n";
		return undef;
	}

	my ($dbh,$sth,$rows);

	$dbh = $self->{dbh};

	if(!$dbh) {
		carp "_kv_fetchall on unconnected object";
		return undef;
	}

	$sth = $dbh->prepare("select * from $tname");

	$sth->execute;

	$rows = $sth->fetchall_arrayref({}); # return tmp hashes

	return undef if scalar $rows < 1;

	return $rows;
}

1;
__DATA__
