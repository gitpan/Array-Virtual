package Array::Virtual;

# documentation is at the bottom

require 5.005;
use strict;

use Tie::Array;
use NDBM_File;
use Fcntl;

use vars qw($VERSION @ISA);
@ISA = qw(Tie::Array);
$VERSION = '0.02';

# All methods in this class are called automatically by the tied array
# magician.
# Edit history:
#   fall 2000: created
#   July 2001: corrected EXISTS so it offsets properly

sub TIEARRAY {
  my $class = shift;
  my $name  = shift || "default";
  my $perms = shift || 0644;
  my $new = 1;  # we'll assume it's the first time
  my %indices;

  if (-f "$name.array.db" or -f "$name.array.pag") {
    $new = 0;
    tie %indices, "NDBM_File", "$name.array", O_RDWR, $perms;
  } else {
    tie %indices, "NDBM_File", "$name.array", O_WRONLY|O_CREAT, $perms;
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

  $index += $$self{FRONT};
  if ($index > $$self{BACK}) {
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
  my $self = shift;
  my $index = shift;
  my $value = shift;

  $index += $$self{FRONT};

  if ($index > $$self{BACK}) {
    $$self{COUNT}++;
    $$self{BACK}++;
  }
  $$self{$index} = $value;
}

sub STORESIZE {
  my $self = shift;
  my $count = shift;

  $$self{COUNT} = $count;
  $$self{BACK} = $$self{FRONT} + $count - 1;
}

sub DESTROY {
  my $self = shift;

  untie %{$self};
}

sub EXISTS {
  my $self = shift;
  my $index = shift;

  $index += $$self{FRONT};
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

Array::Virtual - A perl extension providing disk based arrays implemented via tied hashes

=head1 VERSION

This documentation covers version 0.01 of Array::Virtual released July, 2001.

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
storage scheme is a hash tied via NDBM_File.

The module optimizes push, pop, shift and unshift for speed.  For SPLICE,
it uses the method inherited from Tie::Array.  Splicing requires
moving elements around.  Since there is really no short cut for that, there
is not a real way to optimize this routine, thus it is borrowed.  Genuine
DELETE is not yet supported.  Attempting to call DELETE will result in the
inherited croak from Tie::Array.

Once you issue a line like
   tie @myarray, "Virtual", "diskname", 0664;
you may use @myarray just as you would any other array.
The array will be stored in a file called diskname.array.db
or a pair of files diskname.array.dir and diskname.array.pag,
depending on the verion of NDBM_File you are using.  Any path
is preserved through the call, but .array.... is always appended.  (This
module puts on the array extension, NDBM_File puts on the other extension(s).)

If the disk file(s) for the array already exists, it is opened and its
contents are the same as the last time the disk array was used.  If you
want to purge the disk array, simply unlink its file(s) either inside
or outside of perl.  Say something like C<unlink \<diskname.array.*\>>.

If the file(s) cannot be found, it(they) is(are) created with the
given permissions if supplied (or with 0644 by default).

=head1 DEPENDENCIES

This package inherits from Tie::Array from the standard distribution.

It uses the standard pragma strict.

In addition it uses Fcntl out of laziness, and NDBM_File out of necessity.
Both of these are from the standard distribution.

=head1 BUGS

Normally when you down size an array, you permanently loose the elements
which are outside the new range.  Later enlarging is not supposed
to recover the lost elements.  This Array::Virtual restores them as if they
were never lost.  You might consider this a feature.  It does save time.

=head1 NOTE WELL

This module never uses arrays in its implementation.  It does not pay any
attention to the deprecated $[ variable which allows arrays to begin at
non-zero indices.

=head1 EXPORT

This module exports nothing.  Everything in it is called transparently by
the tie magician.

=head1 AUTHOR

Phil Crow crow@qns.com

=head1 COPYRIGHT

Copyright (c) 2001  Philip Crow.  All rights reserved.  This program
is free and may be redributed in the same manner as Perl itself.

=cut

