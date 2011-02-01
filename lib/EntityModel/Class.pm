package EntityModel::Class;
# ABSTRACT: Helper module for generating class definitions
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;
use feature ();

use IO::Handle;

our $VERSION = 0.001;

=head1 NAME

EntityModel::Class - define class definition

=head1 SYNOPSIS

 package Thing;
 use EntityModel::Class {
 	_version => '$Rev: 338 $',
	_isa => [ 'ThingBase' ],
 	name => { type => 'string' }
 };

 package main;
 my $thing = Thing->new();
 $thing->name('A thing');
 1;

=head1 DESCRIPTION

Applies a class definition to a package. Automatically includes strict, warnings, error handling and other
standard features without needing to copy and paste boilerplate code.

=head1 USAGE

Add EntityModel::Class near the top of the target package:

 package Test;
 use EntityModel::Class { };

The hashref parameter contains the class definition. Each key is the name of an attribute for the class,
with the exception of the following underscore-prefixed keys:

=over 4

=item * C<_vcs> - version control system information, a plain string containing information about the last
changed revision and author for this file.

 use EntityModel::Class { _version => '$Id$' };

=item * C<_isa> - set up the parents for this class, similar to use parent.

 use EntityModel::Class { _isa => 'DateTime' };

=back

An attribute definition will typically create an accessor with the same name, and depending on type may
also include some additional helper methods.

Available types include:

=over 4

=item * C<string> - simple string scalar value

 use EntityModel::Class { name => { type => 'string' } };

=item * C<array> - an array of objects, provide the object type as the subclass parameter

 use EntityModel::Class { childNodes => { type => 'array', subclass => 'Node' } };

=item * C<hash> - hash of objects of subclass type

 use EntityModel::Class { authorMap => { type => 'hash', subclass => 'Author' } };

=back

If the type (or subclass) contains '::', or starts with a Capitalised letter, then it will be treated
as a class. All internal type names are lowercase.

You can also set the scope on a variable, which defines whether it should be include when exporting or
importing:

=over 4

=item * C<private> - private attributes are not exported or visible in attribute lists

 use EntityModel::Class { authorMap => { type => 'hash', subclass => 'Author', scope => 'private' } };

=item * C<public> (default) - public attributes are included in export/import, and will be visible when listing attributes for the class

 use EntityModel::Class { name => { type => 'string', scope => 'public' } };

=back

You can also specify actions to take when a variable is changed, to support internal attribute observers,
by specifying the C<watch> parameter. This takes a hashref with key corresponding to the attribute to watch,
and value indicating the method on that object. For example, C<page => 'path'> would update whenever the
C<path> mutator is called on the C<page> attribute. This is intended for use with hash and array containers,
rather than classes or simple types.

 use EntityModel::Class {
 	authors => { type => 'array', subclass => 'Author' },
 	authorByName => { type => 'hash', subclass => 'Author', scope => 'private', watch => { authors => 'name' } }
 };

=cut

use Check::UnitCheck;
use Try::Tiny;
use Scalar::Util qw(refaddr);
use overload;

use EntityModel::Log ':all';
use EntityModel::Array;
use EntityModel::Hash;
use EntityModel::Error;
use EntityModel::Class::Accessor;
use EntityModel::Class::Accessor::Array;
use EntityModel::Class::Accessor::Hash;

my %classInfo;

=head2 import

Apply supplied attributes, and load in the following modules:

=over 4

=item use strict;

=item use warnings;

=item use feature;

=item use 5.010;

=back

=cut

sub import {
	my $class = __PACKAGE__;
	my $called_on = shift;
	my $pkg = caller(0);

	my $info = (ref $_[0] ~~ 'HASH') ? $_[0] : { @_ };  # support list of args or hashref
	# Expand 'string' to { type => 'string' }
	$_ = { type => $_ } foreach grep { !ref($_) && /^[a-z]/i } values %$info;

# Bail out early if we already have inheritance or have recorded this entry in the master list
	return if $classInfo{$pkg} || $pkg->isa('EntityModel::BaseClass');

# Basic setup, including strict and other pragmas
	$class->setup($pkg);
	$class->applyInheritance($pkg, $info);
	$class->loadDependencies($pkg, $info);
	$class->applyLogging($pkg, $info);
	$class->applyVersion($pkg, $info);
	$class->applyAttributes($pkg, $info);
	$class->recordClass($pkg, $info);
	1;
}

sub recordClass {
	my ($class, $pkg, $info) = @_;
	my @attribs = grep { !/^_/ } keys %$info;
	{ no strict 'refs'; *{$pkg . '::ATTRIBS'} = sub () { @attribs }; }
	$classInfo{$pkg} = $info;
}

sub applyInheritance {
	my ($class, $pkg, $info) = @_;
# Inheritance
	my @inheritFrom = @{ $info->{_isa} // [] };
	push @inheritFrom, 'EntityModel::BaseClass';
	foreach my $parent (@inheritFrom) {
		my $file = $parent;
		$file =~ s{::|'}{/}g;
		require $file . '.pm';
	}
	{ no strict 'refs'; push @{$pkg . '::ISA'}, @inheritFrom; }
	delete $info->{_isa};
}

=head2 loadDependencies

Load all modules required for classes

=cut

sub loadDependencies {
	my ($class, $pkg, $info) = @_;
	my @attribs = grep { !/^_/ && !/~~/ } keys %$info;
	my @classList = grep { $_ && /:/ } map { $info->{$_}->{subclass} // $info->{$_}->{type} } grep { !$info->{$_}->{defer} } @attribs;
	foreach my $c (@classList) {
		my $file = $c;
		$file =~ s{::|'}{/}g;
		$file .= '.pm';
		if($INC{$file}) {
			logDebug("Already in INC: $file");
			next;
		}
		eval {
			logDebug("Not found: $file") unless -f $file && -r $file;
			require $file;
#			eval "package $pkg; $c->import;package $class;";
		};
		logWarning($@) if $@;
	}
}

=head2 applyLogging

=cut

sub applyLogging {
	my ($class, $pkg, $info) = @_;
# Support logging methods by default, unless explicitly disabled
	EntityModel::Log->export_to_level(2, $pkg, ':all')
	 if $info->{_log} || !exists $info->{_log};
# Apply any log-level overrides first at package level
	if(exists $info->{_logMask}->{default}) {
		$EntityModel::Log::LogMask{$pkg}->{level} = EntityModel::Log::levelFromString($info->{_logMask}->{default});
	}

# ... then at method level
	if(exists $info->{_logMask}->{methods}) {
		my %meth = %{$info->{_logMask}->{methods}};
		foreach my $k (keys %meth) {
			$EntityModel::Log::LogMask{$pkg . '::' . $k}->{level} = EntityModel::Log::levelFromString($meth{$k});
		}
	}
}

=head2 applyVersion

=cut

sub applyVersion {
	my ($class, $pkg, $info) = @_;
# Typically version is provided as an SVN Rev property wrapped in $ signs.
	if(exists $info->{_vcs}) {
		my $v = delete $info->{_vcs};
		$class->vcs($pkg, $v);
	}
}

sub applyAttributes {
	my ($class, $pkg, $info) = @_;
	my %methodList;
	my @attribs = grep { !/^_/ } keys %$info;

# Smart match support
	if(my $match = delete $info->{'~~'}) {
		$class->addMethod($pkg, '()', sub () { });
		if(ref $match) {
			$class->addMethod($pkg, '(~~', $match);
		} else {
			$class->addMethod($pkg, '(~~', sub {
				my ($self, $target) = @_;
				return 0 unless defined($self) && defined($target);
				return 0 unless ref($self) && ref($target);
				return 0 unless $self->isa($pkg);
				return 0 unless $target->isa($pkg);
				return 0 unless refaddr($self) == refaddr($target);
				return 1;
			});
		}
	}

# Anything else is an accessor, set it up
	foreach my $attr (@attribs) {
		given($info->{$attr}->{type}) {
			when('array') { %methodList = (%methodList, EntityModel::Class::Accessor::Array->addToClass($pkg, $attr => $info->{$attr})) }
			when('hash') { %methodList = (%methodList, EntityModel::Class::Accessor::Hash->addToClass($pkg, $attr => $info->{$attr})) }
			default { %methodList = (%methodList, EntityModel::Class::Accessor->addToClass($pkg, $attr => $info->{$attr})) }
		}
	}

# Apply watchers after we've defined the fields - each watcher is field => method
	foreach my $watcher (grep { exists $info->{$_}->{watch} } @attribs) {
		my $w = $info->{$watcher}->{watch};
		foreach my $watched (keys %$w) {
			$class->addWatcher($pkg, $watcher, $watched, $info->{$watched}, $w->{$watched});
		}
	}

	Check::UnitCheck::unitcheckify(sub {
		# FIXME Can't call any log functions within UNITCHECK
		local $::DISABLE_LOG = 1;
		my %ml = %methodList;
		$class->addMethod($pkg, $_, $ml{$_}) foreach keys %ml;
		$class->addMethod($pkg, 'import', sub { }) unless $pkg->can('import');
	}) if %methodList;
}

sub addMethod {
	my $class = shift;
	my ($pkg, $name, $method) = @_;
	my $sym = $pkg . '::' . $name;
	logDebug("Add method $sym");
	{ no strict 'refs'; *$sym = $method unless *$sym{CODE}; }
	return $sym;
}

=head2 vcs

Add a version control system tag to the class.

=cut

sub vcs {
	my $class = shift;
	my $pkg = shift;
	my $v = shift;

	# Define with empty prototype, which should mean we compile to a constant
	my $versionSub = sub () { $v };
	my $sym = $pkg . '::VCS_INFO';
	{ no strict 'refs'; *$sym = $versionSub unless *$sym{CODE}; }
}

=head2 setup

Standard module setup - enable strict and warnings, and disable 'import' fallthrough.

=cut

sub setup {
	my ($class, $pkg) = @_;

	{
		no strict 'refs';
#		*{$pkg . '::import'} = sub { }
#		 unless 'import' ~~ [ keys %{$pkg. '::'} ];
		push @{$pkg . '::ISA'}, $class;
	}

	strict->import;

# Currently 'redefine' is non-fatal, although perhaps this isn't strict enough
	warnings->import(FATAL => 'all', NONFATAL => 'redefine');
	feature->import(':5.10');
	Try::Tiny->export_to_level(2); # package -> import -> setup

	foreach my $m (qw/trim now restring/) {
		no strict 'refs';
		*{$pkg . '::' . $m} = \&$m;
	}
}


=head2 validator

Basic validation function.

=cut

sub validator {
	my $v = shift;
	my $allowed = $v->{valid};
	return defined $allowed
	 ? ref $allowed eq 'CODE'
	 ? $allowed : sub { $_[0] ~~ $allowed }
	 : undef;
}

=head2 trim

Helper function to trim all leading and trailing whitespace from the given string.

=cut

sub trim { my $str = shift; return '' unless defined $str && length("$str"); $str =~ s/^\s*(.*?)\s*$/$1/gs; return $str; }

=head2 now

Get L<DateTime> value for current time

=cut

sub now { DateTime->from_epoch(epoch => Time::HiRes::time); }

=head2 restring

Helper method for expanding a string

=cut

sub restring {
	my $str = shift;
	return
	  (ref($_[0]) ~~ /^CODE/)
	? ($str . ($_[0]->()))
	: ((@_ > 0)
	? sprintf($str, map { $_ // 'undef' } @_)
	: $str);
}

=head2 _attribInfo

Returns attribute information for a given package's attribute.

=cut

sub _attribInfo {
	my $self = shift;
	my $attr = shift;
	# return unless ref $self;
	return $classInfo{ref $self || $self}->{$attr};
}

=head2 addWatcher

Add watchers as required for all package definitions.

Call this after all the class definitions have been loaded.

=cut

sub addWatcher {
	my $class = shift;
	my ($pkg, $obj, $target, $attrDef, $meth) = @_;

# The watcher is called with the new value as add|drop => $v
	my $sub = sub {
		my $self = shift;
		my ($action, $v) = @_;
		return unless $v;
		my $k = $meth ? $v->$meth : $v;
		logDebug("%s for %s with %s", $action, $k, $v);
		given($action) {
			when('add') {
				$self->$obj->set($k, $v);
			}
			when('drop') {
				$self->$obj->erase($k);
			}
			default { logError("Don't know %s", $_); }
		}
		return $self;
	};

	given($attrDef->{type}) {
		when('array') {
			EntityModel::Class::Accessor::Array->addWatcher($pkg, $target, $sub);
		}
		default { die "Unknown type " . ($_ // 'undef'); }
	}
}

1;
