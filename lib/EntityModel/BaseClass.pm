package EntityModel::BaseClass;
BEGIN {
  $EntityModel::BaseClass::VERSION = '0.005';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;

use Scalar::Util ();

=pod

=cut

sub new {
	my $class = shift;
	my %data;
	if(ref($_[0]) eq 'HASH') {
		%data = %{$_[0]};
	} else {
		if(@_ % 2) {
			use EntityModel::Log ':all';
			logStack("Bad element list for [%s] - %s", $class, join(',', map { $_ // 'undef' } @_));
		}
		%data = @_;
	}
	foreach my $attr (grep { !exists $data{$_} } $class->ATTRIBS) {
		my $def = EntityModel::Class::_attrib_info($class, $attr);
		if(exists $def->{default}) {
			my $v = $def->{default};
			$v = $v->() if ref $v ~~ 'CODE';
			$data{$attr} = $v;
		}
	}

	bless(\%data, $class);
}

sub clone {
	my $self = shift;
	return bless { %$self }, ref $self;
}

=head2 C<dump>

Simple method to dump out this object and all attributes.

=cut

sub dump {
	my $self = shift;
	my $out = shift || sub {
		my $k = shift;
		my $depth = shift;
		my $v = shift // '';
		print((' ' x $depth) . "$k = $v\n");
	};
	my $depth = shift // 0;

	$out->(ref($self), $depth, $self);
	foreach my $k (sort $self->ATTRIBS) {
		my $v = $self->$k();
		if(eval { $v->can('dump'); }) {
			$out->($k, $depth + 1, ':');
			$v->dump($out, $depth + 1);
		} elsif(ref $v eq 'ARRAY') {
			$out->($k, $depth + 1, '[' . join(',', @$v) . ']');
		} elsif(ref $v eq 'HASH') {
			$out->($k, $depth + 1, '{' . (map { $_ . ' => ' . $v->{$_} } sort keys %$v) . '}');
		} else {
			$out->($k, $depth + 1, $v);
		}
	}
	$self;
}

=head2 C<sap>

Generate a coderef that takes a weakened value of $self.

Usage:

 push @handler, $obj->sap(sub {
 	my $self = shift;
	$self->do_something;
 });

=cut

sub sap {
	my ($self, $sub) = @_;
	Scalar::Util::weaken $self;
	return sub {
		$self->$sub(@_);
	};
}

1;
