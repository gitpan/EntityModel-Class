package EntityModel::Hash;
BEGIN {
  $EntityModel::Hash::VERSION = '0.002';
}
use strict;
use warnings;
use 5.010;

use EntityModel::Log ':all';

=pod

=cut

use overload
	'%{}' => sub {
		my $self = shift;
		return $self->hashref;
	},
	fallback => 1;

sub new {
	my ($class, $data) = @_;
	bless { data => ($data // { }) }, $class;
}

sub count {
	my $self = shift;
	return scalar keys %{$self->hashref};
}

sub list {
	my $self = shift;
	return unless $self->hashref;
	return values %{$self->hashref};
}

sub set {
	my $self = shift;
	my ($k, $v) = @_;
	unless(defined $k) {
		# logStack("No k?");
		return $self;
	}
	if(ref($k) && ref($k) eq 'HASH') {
		$self->hashref->{$_} = $k->{$_} foreach keys %$k;
	} else {
		$self->hashref->{$k} = $v;
	}
	return $self;
}

sub erase {
	my $self = shift;
	my ($k) = @_;
	delete $self->hashref->{$k};
	return $self;
}

sub get {
	my ($self, $k) = @_;
	return $self->hashref->{$k};
}

sub hashref {
	my $self = shift;
	my $class = ref $self;
	bless $self, 'overload::dummy';
	my $out = $self->{data};
	bless $self, $class;
	return $out;
}

sub exists : method {
	my ($self, $k) = @_;
	return exists($self->hashref->{$k});
}

sub keys : method {
	my $self = shift;
	return keys %{$self->hashref};
}

sub clear : method {
	my $self = shift;
	my $class = ref $self;
	bless $self, 'overload::dummy';
	$self->{data} = { };
	bless $self, $class;
	return $self;
}

sub is_empty {
	my $self = shift;
	return !$self->keys;
}

1;
