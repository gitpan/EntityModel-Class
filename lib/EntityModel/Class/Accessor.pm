package EntityModel::Class::Accessor;
BEGIN {
  $EntityModel::Class::Accessor::VERSION = '0.002';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;
use feature ();

=pod

=cut

use EntityModel::Log ':all';
use Scalar::Util;

=head2 C<addToClass>

Add hooks for hash accessors.

=over 4

=item * $pkg - Package to add accessors to

=item * $k - Key

=item * $v - Value

=back

=cut

sub addToClass {
	my ($class, $pkg, $k, $v) = @_;

	return $k => $class->methodList(
		pkg => $pkg,
		k => $k,
		pre => $v->{pre},
		post => $v->{post},
		allowed => $v->{valid},
		validate => defined $v->{valid}
		 ? ref $v->{valid} eq 'CODE'
		 ? $v->{valid} : sub { $_[0] ~~ $v->{valid} }
		 : undef
	);
}

sub methodList {
	my ($self, %opt) = @_;	
	my $k = delete $opt{k};
	return sub {
		my $self = shift;
		die "Instance method for $k, self is " . ($self // 'undef') unless ref $self;
		if($opt{pre}) {
			$opt{pre}->($self, @_)
			 or return;
		}
		if(@_) {
			die $_[0] . ' is invalid' if $opt{validate} && !$opt{validate}->($_[0]);
			my $v = shift;
			# Readonly values can be problematic, make a copy if we can - but don't trash refs.
			$v = "$v" if Scalar::Util::readonly($self->{$k}) && !ref $v;
			$self->{$k} = $v;
		}
		$opt{post}->($self, @_) if $opt{post};
		return $self if @_;
		logStack("Had readonly instance %s", $self) if Scalar::Util::readonly($self);
		logStack("Had readonly value %s for key %s", $self->{$k}, $k) if Scalar::Util::readonly($self->{$k});
		$self->{$k};
	};
}

1;
