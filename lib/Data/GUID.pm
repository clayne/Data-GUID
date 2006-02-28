package Data::GUID;

use warnings;
use strict;

use Carp ();
use Data::UUID;
use Sub::Install;

=head1 NAME

Data::GUID - globally unique identifiers

=head1 VERSION

version 0.02

 $Id$

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

  use Data::GUID;

  my $guid = Data::GUID->new;

  my $string = $guid->as_string; # or "$guid"

  my $other_guid = Data::GUID->from_string($string);

  if (($guid <=> $other_guid) == 0) {
    print "They're the same!\n";
  }

=head1 DESCRIPTION

Data::GUID provides a simple interface for generating and using globally unique
identifiers.

=head1 GETTING A NEW GUID

=head2 C< new >

  my $guid = Data::GUID->new;

This method returns a new globally unique identifier.

=cut

my $_uuid_gen = Data::UUID->new;
sub new {
  my ($class) = @_;

  return $class->from_data_uuid($_uuid_gen->create);
}

=head1 GUIDS FROM EXISTING VALUES

These method returns a new Data::GUID object for the given GUID value.  In all
cases, these methods throw an exception if given invalid input.

=head2 C< from_string >

  my $guid = Data::GUID->from_string("B0470602-A64B-11DA-8632-93EBF1C0E05A");

=head2 C< from_hex >

  # note that a hex guid is a guid string without hyphens and with a leading 0x
  my $guid = Data::GUID->from_hex("0xB0470602A64B11DA863293EBF1C0E05A");

=head2 C< from_base64 >

  my $guid = Data::GUID->from_base64("sEcGAqZLEdqGMpPr8cDgWg==");

=head2 C< from_data_uuid >

This method returns a new Data::GUID object if given a Data::UUID value.
Because Data::UUID values are not blessed and because Data::UUID provides no
validation method, this method will only throw an exception if the given data
is of the wrong size.

=cut

sub from_data_uuid {
  my ($class, $value) = @_;

  my $length = do { use bytes; defined $value ? length $value : 0; };
  Carp::croak "given value is not a valid Data::UUID value" if $length != 16;
  bless \$value => $class;
}

my $hex    = qr/[0-9A-F]/i;
my $base64 = qr{[A-Z0-9+/=]}i;

my %type = ( # uuid_method  validation_regex
  string => [ 'string',     qr/\A$hex{8}-(?:$hex{4}-){3}$hex{12}\z/, ],
  hex    => [ 'hexstring',  qr/\A0x$hex{32}\z/,                      ],
  base64 => [ 'b64string',  qr/\A$base64{24}\z/,                     ],
);

# provided for test scripts
sub __type_regex { shift; $type{$_[0]}[1] }

sub _install_from_method {
  my ($type, $alien_method, $regex) = @_;
  my $alien_from_method = "from_$alien_method";

  my $our_from_code = sub { 
    my ($class, $string) = @_;
    $string ||= ''; # to avoid (undef =~) warning
    Carp::croak qq{"$string" is not a valid $type GUID} if $string !~ $regex;
    $class->from_data_uuid( $_uuid_gen->$alien_from_method($string) );
  };

  Sub::Install::install_sub({ code => $our_from_code, as => "from_$type" });
}

sub _install_as_method {
  my ($type, $alien_method) = @_;

  my $alien_to_method = "to_$alien_method";

  my $our_to_method = sub { 
    my ($self) = @_;
    $_uuid_gen->$alien_to_method( $self->as_binary );
  };

  Sub::Install::install_sub({ code => $our_to_method, as => "as_$type" });
}

do {
  while (my ($type, $profile) = each %type) {
    _install_from_method($type, @$profile);
    _install_as_method  ($type, @$profile);
  }
};

sub _GUID {
  my ($class, $value) = @_;
  return $value if eval { $value->isa('Data::GUID') };

  # The only good ref is a blessed ref, and only into our denomination!
  return if (ref $value);
  
  for my $type ((keys %type), 'data_uuid') {
    my $from = "from_$type";
    my $guid = eval { $class->$from($value); };
    return $guid if $guid;
  }

  return;
}

=head1 GUIDS INTO STRINGS

These methods return various string representations of a GUID.

=head2 C< as_string >

This method returns a "traditional" GUID/UUID string representation.  This is
five hexadecimal strings, delimited by hyphens.  For example:

  B0470602-A64B-11DA-8632-93EBF1C0E05A

This method is also used to stringify Data::GUID objects.

=head2 C< as_hex >

This method returns a plain hexadecimal representation of the GUID, with a
leading C<0x>.  For example:

  0xB0470602A64B11DA863293EBF1C0E05A

=head2 C< as_base64 >

This method returns a base-64 string representation of the GUID.  For example:

  sEcGAqZLEdqGMpPr8cDgWg==

=cut

=head1 OTHER METHODS

=head2 C< compare_to_guid >

This method compares a GUID to another GUID and returns -1, 0, or 1, as do
other comparison routines.

=cut

sub compare_to_guid {
  my ($self, $other) = @_;

  my $other_binary
    = eval { $other->isa('Data::GUID') } ? $other->as_binary : $other;

  $_uuid_gen->compare($self->as_binary, $other_binary);
}

=head2 C< as_binary >

This method returns the packed binary representation of the GUID.  At present
this method relies on Data::GUID's underlying use of Data::UUID.  It is not
guaranteed to continue to work the same way, or at all.  I<Caveat invocator>.

=cut

sub as_binary {
  my ($self) = @_;
  $$self;
}

use overload
  q{""} => 'as_string',
  '<=>' => sub { ($_[2] ? -1 : 1) * $_[0]->compare_to_guid($_[1]) },
  fallback => 1;

=head1 IMPORTING

Data::GUID does not export any subroutines by default, but it provides four
routines which will be imported on request.  These routines may be called as
class methods, or may be imported to be called as subroutines.

=cut

=head2 C< guid >

  use Data::GUID qw(guid);

  my $guid_1 = Data::GUID->guid;
  my $guid_2 = guid;

This routine returns a new Data::GUID object.

=head2 C< guid_string >

This returns the string representation of a new GUID.

=head2 C< guid_hex >

This returns the hex representation of a new GUID.

=head2 C< guid_base64 >

This returns the base64 representation of a new GUID.

=cut

Sub::Install::install_sub({ code => 'new', as => 'guid' });

for my $type (keys %type) {
  my $method = "guid_$type";
  my $as     = "as_$type";

  no strict 'refs';
  *$method = sub {
    my ($class) = @_;
    $class->new->$as;
  }
}

my %exports = map { $_ => 1 } ('guid', map { "guid_$_" } keys %type);

$exports{_GUID} = 1;

sub import {
  my ($class, @to_export) = @_;
  my $into = caller(0);
  @to_export = keys %exports if grep { $_ eq ':all' } @to_export;
  
  for my $sub (@to_export) {
    Carp::croak qq{"$sub" is not exported by the Data::GUID module}
      unless $exports{ $sub };
    Sub::Install::install_sub({
      code => $exports{ $sub }->($class),
      into => $into,
      as   => $sub,
    });
  }
}

=head1 AUTHOR

Ricardo SIGNES, C<< <rjbs@cpan.org> >>

=head1 TODO

=over

=item * add namespace support

=item * remove dependency on wretched Data::UUID

=item * make it work on 5.005

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-data-guid@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 COPYRIGHT

Copyright 2006 Ricardo Signes, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
