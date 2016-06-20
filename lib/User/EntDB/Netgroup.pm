
package User::EntDB::Netgroup;

use strict;
use warnings;

use User::Netgroup;

sub new;

sub fromNetgroup;

sub toSQLite;
sub toEtcNetgroup;

sub getSysNetgroupList;
sub getDBNetgroupList;

sub loadAllNetgroupsFromSystem;

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;
	return $self;
}

sub fromNetgroup {
	my $self = User::EntDB::Netgroup->new();
	my $ng = shift;
	$self->{ng} = $ng;
	return $self;
}

sub toSQLite {
	my $self = shift;
	my $ng = $self->{ng};

	return undef unless $ng;

	my $ngname = $ng->{netgroup};

	my $q = '';

	foreach my $mem (@{$ng->{entries}}) {


		my ($r,$h,$u,$d);

		$r = $mem->{'ref'} ?
			"'" . $mem->{'ref'} . "'"
			: 'NULL';
		$h = $mem->{'host'} ?
			"'" . $mem->{'host'} . "'"
			: 'NULL';
		$u = $mem->{'user'} ?
			"'" . $mem->{'user'} . "'"
			: 'NULL';
		$d = $mem->{'domain'} ?
			"'" . $mem->{'domain'} . "'"
			: 'NULL';

		$q .= "insert into netgrent values ("
			. " '$ngname',"
			. " $r,"
			. " $h,"
			. " $u,"
			. " $d"
			. ");\n";
	}

	return undef if $q eq '';
	return $q;

}

sub toEtcNetgroup {

	my $self = shift;
	my $ng = $self->{ng};

	return undef unless $ng;

	my $ngname = $ng->{netgroup};

	my $q = '';

	foreach my $mem (@{$ng->{entries}}) {

		if($mem->{'ref'}) {
			$q .= " \\\n " . $mem->{'ref'};
		}
		else {
			my ($h,$u,$d);

			$h = $mem->{'host'} ?
				$mem->{'host'}
				: '';
			$u = $mem->{'user'} ?
				$mem->{'user'}
				: '';
			$d = $mem->{'domain'} ?
				$mem->{'domain'}
				: '';

			$q .= " \\\n ($h,$u,$d)";
		}
	}

	return undef if $q eq '';
	return $ngname . $q;

}

sub getSysNetgroupList {
	my $nglist = [];
	while(my $rec = User::Netgroup::nextnetgrent()) {
		my $ng = User::EntDB::Netgroup::fromNetgroup($rec);
		push @{$nglist}, $ng;
	}
	return $nglist;
}

sub getDBNetgroupList {
	my $entdb = shift;
	my $nglist = [];

	while( my $rec = $entdb->nextnetgrent() ) {
		push @{$nglist}, User::EntDB::Netgroup::fromNetgroup($rec);
	}
	return $nglist;
}

sub convertNetgroupListToSQL {
	my $nglist = shift;
	my $sqlist = [];
	foreach my $ng (@{$nglist}) {
		my $stmt = $ng->toSQLite();
		push @{$sqlist}, $stmt;
	}
	return $sqlist;
}

sub loadAllNetgroupsFromSystem {
	my $fname = shift;

	return undef unless $fname;

	my $entdb = User::EntDB->new($fname);
	my $nglist = User::EntDB::Netgroup::getSysNetgroupList();
	my $sqlist = User::EntDB::Netgroup::convertNetgroupListToSQL($nglist);

	$entdb->begintxn();
	foreach my $ngsql (@{$sqlist}) {
		$entdb->do($ngsql);
	}
	$entdb->endtxn();
}

1;

