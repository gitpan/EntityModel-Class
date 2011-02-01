package EntityModel::Class::Accessor::Hash;
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.10.0;
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

