package EntityModel::Array;
BEGIN {
  $EntityModel::Array::VERSION = '0.007';
}
use strict;
use warnings;
use 5.010;
use EntityModel::Log ':all';

=head1 NAME

EntityModel::Array - wrapper object for dealing with arrayrefs

=head1 VERSION

version 0.007

=head1 SYNOPSIS

See L<EntityModel::Class>.

=head1 DESCRIPTION

Primarily intended as an abstract interface for use with L<EntityModel> backend storage.

=head1 METHODS

=cut

use overload
	'@{}' => sub {
		my $self = shift;
		return $self->{data};
	},
	fallback => 1;

=head2 C<new>

Instantiates with the given arrayref

=cut

sub new {
	my ($class, $data, %opt) = @_;
	bless {
		%opt,
		data => ($data // [ ]),
	}, $class;
}

=head2 C<count>

Returns the number of items in the arrayref.

=cut

sub count {
	my $self = shift;
	return scalar @{$self->{data}};
}

=head2 C<list>

Returns all items from the arrayref.

=cut

sub list {
	my $self = shift;
	return unless $self->{data};
	return @{$self->{data}};
}

=head2 C<push>

Push the requested value onto the end of the arrayref.

=cut

sub push : method {
	my $self = shift;
	push @{$self->{data}}, @_;
	if($self->{onchange}) {
		logDebug("We have change");
		foreach my $w (@{$self->{onchange}}) {
			$w->(add => $_) foreach @_;
		}
	}
	return $self;
}

=head2 watch

Add a coderef to be called when the array changes.

=cut

sub add_watch : method {
	my $self = shift;
	$self->{onchange} ||= [];
	push @{$self->{onchange}}, @_;
	return $self;
}

sub remove_watch : method {
	my $self = shift;
	return $self unless $self->{onchange};
	foreach my $code (@_) {
		@{ $self->{onchange} } = grep { $_ != $code } @{ $self->{onchange} };
	}
	return $self;
}

=head2 C<shift>

Shift the first value out of the arrayref.

=cut

sub shift : method {
	my $self = shift;
	my $v = shift(@{$self->{data}});
	if($self->{onchange}) {
		logDebug("We have change");
		foreach my $w (@{$self->{onchange}}) {
			$w->(drop => $v);
		}
	}
	return $v;
}

=head2 C<pop>

Pops the last value from the arrayref.

=cut

sub pop : method {
	my $self = shift;
	my $v = pop(@{$self->{data}});
	if($self->{onchange}) {
		logDebug("We have change");
		foreach my $w (@{$self->{onchange}}) {
			$w->(drop => $v);
		}
	}
	return $v;
}

=head2 C<unshift>

Unshifts a value onto the start of the arrayref.

=cut

sub unshift : method {
	my $self = shift;
	my $v = unshift @{$self->{data}}, @_;
	if($self->{onchange}) {
		logDebug("We have change");
		foreach my $w (@{$self->{onchange}}) {
			$w->(add => $_) foreach @_;
		}
	}
	return $v;
}

=head2 C<join>

Joins the entries in the arrayref using the given value and returns as a scalar.

=cut

sub join : method {
	my $self = shift;
	return join(shift, @{$self->{data}});
}

=head2 C<each>

Perform coderef on each entry in the arrayref.

=cut

sub each : method {
	my ($self, $code) = @_;
	foreach my $v (@{$self->{data}}) {
		$code->($v);
	}
	return $self;
}

=head2 C<first>

Returns the first entry in the arrayref.

=cut

sub first {
	my ($self, $match) = @_;
	return $self->{data}[0] unless defined $match;
	if(ref $match eq 'CODE') {
		my ($first) = grep { $match->($_) } @{$self->{data}};
		return $first;
	}
	my ($first) = grep $match, @{$self->{data}};
	return $first;
}

=head2 C<last>

Returns the last entry in the arrayref.

=cut

sub last {
	my ($self, $match) = @_;
	return $self->{data}[-1] unless defined $match;
	if(ref $match eq 'CODE') {
		my ($last) = reverse grep { $match->($_) } @{$self->{data}};
		return $last;
	}
	my ($last) = reverse grep $match, @{$self->{data}};
	return $last;
}

=head2 C<grep>

Calls the coderef on each entry in the arrayref and returns the entries for which it returns true.

=cut

sub grep : method {
	my ($self, $match) = @_;
	return grep { $match->($_) } @{$self->{data}};
}

=head2 C<remove>

Remove entries from the array.

Avoid rebuilding the array in case we have weak refs, just splice out the values
indicated.

=cut

sub remove : method {
	my ($self, $check) = @_;
	my $idx = 0;
	while($idx < scalar @{$self->{data}}) {
		my $match;
		if(ref $check eq 'CODE') {
			$match = $check->($self->{data}->[$idx]);
		} else {
			$match = ($self->{data}->[$idx]) ~~ $check;
		}
		if($match) {
			my ($el) = splice @{$self->{data}}, $idx, 1;
			if($self->{onchange}) {
				foreach my $w (@{$self->{onchange}}) {
					$w->(drop => $el);
				}
			}
		} else {
			++$idx;
		}
	}
	return $self;
}

=head2 C<clear>

Empty the arrayref.

=cut

sub clear : method {
	my $self = shift;
	if($self->{onchange}) {
		my @el = @{ $self->{data} };
		foreach my $w (@{$self->{onchange}}) {
			$w->(drop => $_) for @el;
		}
	}
	$self->{data} = [ ];
	return $self;
}

=head2 C<arrayref>

Returns the arrayref directly.

=cut

sub arrayref {
	my ($self) = @_;
	return $self->{data};
}

=head2 C<is_empty>

Returns true if there's nothing in the arrayref.

=cut

sub is_empty {
	my $self = shift;
	return !$self->count;
}

1;

__END__

=head1 SEE ALSO

Use L<autobox> instead.

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2008-2011. Licensed under the same terms as Perl itself.