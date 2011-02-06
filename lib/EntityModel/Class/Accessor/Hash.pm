package EntityModel::Class::Accessor::Hash;
BEGIN {
  $EntityModel::Class::Accessor::Hash::VERSION = '0.002';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;
use feature ();

use parent qw{EntityModel::Class::Accessor};
use EntityModel::Hash;

=pod

=cut

=head2 C<methodList>

Returns a hash of method definitions.

=cut

sub methodList {
	my ($class, %opt) = @_;
	my $k = $opt{k};
	return sub {
		my $self = shift;

		if($opt{pre}) {
			$opt{pre}->($self, @_)
			 or return;
		}
		if(@_) {
			$self->{$k} = $_[0];
		}
		$self->{$k} ||= { };
		return EntityModel::Hash->new($self->{$k});
	};
}

1;

