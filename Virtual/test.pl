# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Array::Virtual;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

{
  my @names;
  my $success = 1;

  tie @names, "Array::Virtual", "testarray", 0644;

  push @names, "Spot", "Dick";
  unshift @names, "Jane", "Charlie";
  if (@names == 4) {
    print "ok 2\n";
  }
  else {
    $success = 0;
    print "not ok 2, push or unshift failed\n";
  }

  my $first = shift @names;
  my $second = pop @names;

  if ($first eq "Jane") {
    print "ok 3\n";
  } else {
    $success = 0;
    print "not ok 3, shift failed\n";
  }
  if ($second eq "Dick") {
    print "ok 4\n";
  } else {
    $success = 0;
    print "not ok 4, pop failed\n";
  }

  if ($success) {
    print "All tests of Array::Virtual succeeded.\n";
  }
  else {
    print "Array::Virtual test failed.\n";
    exit 1;
  }

}

# depending on your NDBM you may have db or dir and pag, here we clean them all
unlink "testarray.array.db";
unlink "testarray.array.dir";
unlink "testarray.array.pag";
