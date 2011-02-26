package EntityModel::Class::Accessor;
BEGIN {
  $EntityModel::Class::Accessor::VERSION = '0.005';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;
use feature ();

=head1 NAME

EntityModel::Class::Accessor - generic class accessor

=head1 VERSION

version 0.005

=head1 SYNOPSIS

See L<EntityModel::Class>.

=head1 DESCRIPTION

See L<EntityModel::Class>.

=cut

=head2 add_to_class

Returns (method name, coderef) pairs for new methods to add.

=cut

sub add_to_class {
	my ($class, $pkg, $k, $v) = @_;

	return $k => $class->method_list(
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

=head2 method_list

Returns the coderef for the method that should be applied to the requesting class.

=cut

sub method_list {
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
#		logStack("Had readonly instance %s", $self) if Scalar::Util::readonly($self);
#		logStack("Had readonly value %s for key %s", $self->{$k}, $k) if Scalar::Util::readonly($self->{$k});
		$self->{$k};
	};
}

1;

__END__

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2008-2011. Licensed under the same terms as Perl itself.