package Array::Virtual;

# POD documentation is at the bottom

require 5.005;
use strict;

use Tie::Array;
use SDBM_File;
use Fcntl;

use vars qw($VERSION @ISA);
@ISA = qw(Tie::Array);
$VERSION = '0.04';

# All methods in this class are called automatically by the tied array
# magician.
# Edit history:
#   fall 2000: created
#   July 2001: corrected EXISTS so it offsets properly
#   Sept 2001: switched to SDBM_File since that is universal to Perl
#   Sept 2001: changed tying sequence so file existence is not used to
#              determine whether the array is already no the disk
#              this makes the module less dependent on the underlying DBM
#   Apr  2002: added support for negative indices
#              corrected problems with indices outside original range

sub TIEARRAY {
  my $class = shift;
  my $name  = shift || "default";
  my $perms = shift || 0666;
  my $new = 0;  # we'll assume it's not the first time
  my %indices;

  unless (tie %indices, "SDBM_File", "$name.array", O_RDWR, $perms) {
    tie %indices, "SDBM_File", "$name.array", O_RDWR|O_CREAT, $perms;
    $new = 1;
  }

  if ($new) {
    $indices{COUNT} = 0;
    $indices{FRONT} = 0;
    $indices{BACK} = -1;
  }

  my $self = \%indices;

  return bless $self, $class;
}

sub FETCH {
  my $self = shift;
  my $index = shift;

  if ($index < 0) {
    $index = $$self{BACK} + 1 + $index;
  }
  else {
    $index += $$self{FRONT};
  }

  if ($index > $$self{BACK} or $index < $$self{FRONT}) {
    return undef;
  } else {
    return $$self{$index};
  }
}

sub FETCHSIZE {
  my $self = shift;

  return $$self{COUNT};
}

sub STORE {
  my $self  = shift;
  my $index = shift;
  my $value = shift;

  if ($index < 0) {  # What happens if this goes off the front of the array?
                     # I want it to be the analog of running off the back.
    $index = $$self{BACK} + 1 + $index;
  }
  else {
    $index += $$self{FRONT};
  }

  if ($index > $$self{BACK}) {
    $$self{BACK}  = $index;
    $$self{COUNT} = $$self{BACK} - $$self{FRONT} + 1;
  }
  # Perl 5.6 actually calls an error in this case (it checks with FETCHSIZE)
  # It says:
  #   Modification of non-creatable array value attempted, subscript nn...
  elsif ($index < $$self{FRONT}) {
    $$self{FRONT} = $index;
    $$self{COUNT} = $$self{BACK} - $$self{FRONT} + 1;
  }
  $$self{$index} = $value;
}

sub STORESIZE {
  my $self  = shift;
  my $count = shift;

  $$self{COUNT} = $count;
  $$self{BACK} = $$self{FRONT} + $count - 1;
}

sub DESTROY {
  my $self = shift;

  untie %{$self};
}

sub EXISTS {
  my $self  = shift;
  my $index = shift;

  if ($index < 0) {
    $index = $$self{BACK} + 1 + $index;
  }
  else {
    $index += $$self{FRONT};
  }
  return 0 if ($index > $$self{BACK} or $index < $$self{FRONT});
  return defined $$self{$index};
}

sub EXTEND {
# since we are using a tied hash for implementation, there is no nice way
# to implement an extension request
# warn "Array::Virtual takes no action in response to extend requests.";
}

sub SHIFT {
  my $self = shift;
  my $retval;
  
  if ($$self{FRONT} > $$self{BACK}) {  # list already empty
    $$self{FRONT} = 0;
    $$self{BACK} = -1;
    $$self{COUNT} = 0;
    return undef;
  }
  $retval = $$self{$$self{FRONT}};
  $$self{FRONT}++;
  $$self{COUNT}--;

  if ($$self{COUNT} == 0) {  # list made empty by this shift
    $$self{FRONT} = 0;
    $$self{BACK} = -1;
  }

  return $retval;
}

sub POP {
  my $self = shift;
  my $retval;
  
  if ($$self{FRONT} > $$self{BACK}) {  # list already empty
    $$self{FRONT} = 0;
    $$self{BACK} = -1;
    $$self{COUNT} = 0;
    return undef;
  }
  $retval = $$self{$$self{BACK}};
  $$self{BACK}--;
  $$self{COUNT}--;

  if ($$self{COUNT} == 0) {  # list made empty by this pop
    $$self{FRONT} = 0;
    $$self{BACK} = -1;
  }

  return $retval;
}

sub PUSH {
  my $self = shift;

  while (@_) {
    $$self{++$$self{BACK}} = shift;
    $$self{COUNT} = $$self{BACK} - $$self{FRONT} + 1;
  }
}

sub UNSHIFT {
  my $self = shift;

  while (@_) {
    $$self{--$$self{FRONT}} = pop;
    $$self{COUNT} = $$self{BACK} - $$self{FRONT} + 1;
  }
}

sub CLEAR {
  my $self = shift;

  $$self{FRONT} = 0;
  $$self{BACK}  = -1;
  $$self{COUNT} = 0;
}

# other methods currently inherited from Tie::Array:
# sub SPLICE { ... }
# sub DELETE { ... }  croaks

sub _show_values {
# for debugging only
  my $self = shift;

  for (my $i = $$self{FRONT}; $i <= $$self{BACK}; $i++) {
    print "$i: $$self{$i}\n";
  }
}

1;

__END__

=head1 NAME

Array::Virtual - Provides disk based arrays implemented via tied hashes

=head1 VERSION

This documentation covers version 0.04 of Array::Virtual released May, 2002.

=head1 SYNOPSIS

   use Array::Virtual;

   tie @myarray, "Array::Virtual", "diskname", 0664;
   push @myarray, "value";
   my $stackpop = pop @myarray;
   unshift @myarray, "value1";
   my $queuefront = shift @myarray;
   .
   .
   .
   etc.

=head1 DESCRIPTION

This module allows a user to tie an array to a disk file.  The actual
storage scheme is a hash tied via SDBM_File.

The module optimizes push, pop, shift, and unshift for speed.  For SPLICE,
it uses the method inherited from Tie::Array.  Splicing requires
moving elements around.  Since there is really no short cut for that, there
is not a real way to optimize this routine, thus it is borrowed.  Genuine
DELETE is not yet supported.  Attempting to call DELETE will result in the
inherited croak from Tie::Array.

Once you issue a line like
   tie @myarray, "Virtual", "diskname", 0664;
you may use @myarray just as you would any other array.  The array will be
stored in a pair of files called diskname.array.dir and diskname.array.pag.
Any path is preserved through the call, but .array.... is always appended.
(This module puts on the array extension, SDBM_File puts on the other
extensions.)

If the disk files for the array already exists, the array is opened and its
contents are the same as the last time the disk array was used.  If you
want to purge the disk array, simply unlink its files either inside
or outside of perl.  Say something like C<unlink \<diskname.array.*\>>.

If the files cannot be found, they are created with the given permissions
if supplied (or with 0666 modified by your umask by default).

=head1 DEPENDENCIES

This package inherits from Tie::Array from the standard distribution.

It uses the standard pragma strict.

In addition, it uses Fcntl out of laziness, and SDBM_File out of necessity.
Both of these are from the standard distribution.

=head1 BUGS

Normally when you down size an array, you permanently loose the elements
which are outside the new range.  Later enlarging is not supposed
to recover the lost elements.  Array::Virtual restores them as if they
were never lost.  You might consider this a feature.  It does save time.

This module never uses arrays in its implementation.  It does not pay any
attention to the deprecated $[ variable which allows arrays to begin at
non-zero indices.  If you use this variable, Array::Virtual will likely
become confused.

=head1 CORRECTED BUGS

Negative indices were not handled at all.  All attempts to say things like
$array[-1] yielded unpredictable results.  Corrected in version 0.04.

Storing in slots outside the current range failed in most cases.  For example,
if an array was empty the following commands didn't work as expected:
 push @array, 1;
 push @array, 2;
 $array[7] = 3;
The results of the last statement were unexpected and unpredictable.
Corrected in version 0.04.

=head1 EXPORT

This module exports nothing.  Everything in it is called transparently by
the tie magician.

=head1 AUTHOR

Phil Crow philcrow2000@yahoo.com

=head1 COPYRIGHT

Copyright (c) 2001-2002  Philip Crow.  All rights reserved.  This program
is free and may be redributed under the same terms as Perl itself.

=cut

