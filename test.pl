# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;

BEGIN { plan tests => 117 };
use SSN::Validate;
ok(1);    # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $ssn = new SSN::Validate;

my %ssns = (
    '044-56-2283' => [ 1, 'CT' ],
    '444l63749'   => [ 0, 'OK' ],
    '666-56-3749' => [ 1, '??' ],
    '000-56-3749' => [ 0, '' ],
    '144563349'   => [ 1, 'NJ' ],
    '123 56 3749' => [ 1, 'NY' ],
    '444-00-3749' => [ 0, 'OK' ],
    '748010000'   => [ 0, '' ],
    '801-33-2245' => [ 1, '??' ],
    '580-22-1345' => [ 1, 'VI' ],
    '258-22-1345' => [ 1, 'GA' ],
    '612-40-3145' => [ 1, '??' ],
    '764-32-3145' => [ 1, '??' ],
    '764-40-3145' => [ 0, '??' ],
    '586-22-7722' => [ 1, '??' ],
    '710-18-7722' => [ 1, 'RB' ],
    '710-22-7722' => [ 0, 'RB' ],
    '900-44-1234' => [ 0, '??' ], # Tax range
    '900-71-1234' => [ 1, '??' ], # Tax range
    '900-93-1234' => [ 1, '??' ], # Tax range
    '550-19-1234' => [ 0, 'CA' ], # Bad Combo
    '212-09-9999' => [ 1, '' ],
    '042-10-3580' => [ 0, 'CT' ],
    '062-36-0749' => [ 0, NY ],
    '078-05-1120' => [ 0, NY ],
    '095-07-3645' => [ 0, NY ],
    '128-03-6045' => [ 0, NY ],
    '135-01-6629' => [ 0, NJ ],
    '141-18-6941' => [ 0, NJ ],
    '165-16-7999' => [ 0, 'PA' ],
    '165-18-7999' => [ 0, 'PA' ],
    '165-20-7999' => [ 0, 'PA' ],
    '165-22-7999' => [ 0, 'PA' ],
    '165-24-7999' => [ 0, 'PA' ],
    '189-09-2294' => [ 0, 'PA' ],
    '212-09-7694' => [ 0, 'MD' ],
    '212-09-9999' => [ 0, 'MD' ],
    '306-30-2348' => [ 0, 'IN' ],
    '308-12-5070' => [ 0, 'IN' ],
    '468-28-8779' => [ 0, 'MN' ],
    '549-24-1889' => [ 0, 'CA' ],
    '987654320'   => [ 0, '??' ], # Ad
    '987654321'   => [ 0, '??' ], # Ad
    '987654322'   => [ 0, '??' ], # Ad
    '987654323'   => [ 0, '??' ], # Ad
    '987654324'   => [ 0, '??' ], # Ad
    '987654325'   => [ 0, '??' ], # Ad
    '987654326'   => [ 0, '??' ], # Ad
    '987654327'   => [ 0, '??' ], # Ad
    '987654328'   => [ 0, '??' ], # Ad
    '987654329'   => [ 0, '??' ], # Ad
    '586191234'   => [ 0, '??' ], # Bad combo
    '586291234'   => [ 0, '??' ], # Bad combo
    '586591234'   => [ 0, '??' ], # Bad combo
    '586791234'   => [ 0, '??' ], # Bad combo
    '586801234'   => [ 0, '??' ], # Bad combo
    '586831234'   => [ 0, '??' ], # Bad combo
    '586991234'   => [ 0, '??' ], # Bad combo
    #'660991234'   => [ 0, ''], # Unassigned
    '699451234'   => [ 0, ''], # Unassigned
);

for my $num ( sort { $a cmp $b } keys %ssns ) {

    #print "Trying $num\n";
    ok( $ssn->valid_ssn($num), $ssns{$num}->[0] );
    ok( $ssn->get_state($num), $ssns{$num}->[1] );
}
