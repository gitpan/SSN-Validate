# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 27 };
use SSN::Validate;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $ssn = new SSN::Validate;

my %ssns = (
            '044-56-2283' 	=> [1, 'CT'],
            '444l63749'	 	=> [0, 'OK'],
            '666-56-3749'	=> [0, ''],
            '000-56-3749'	=> [0, ''],
            '144563349'		=> [1, 'NJ'],
            '123 56 3749'	=> [1, 'NY'],
            '444-00-3749'	=> [0, 'OK'],
            '748010000'		=> [0, ''],
            '801-33-2245'	=> [0, ''],
            '580-22-1345'	=> [1, 'VI'],
            '258-22-1345'	=> [1, 'GA'],
						'612-40-3145'   => [1, '??'],
            '764-40-3145'   => [1, '??'],
            '586-22-7722'   => [1, 'PI'],
            '710-22-7722'   => [1, 'RB'],
            );

for my $num (keys %ssns) {
	ok($ssn->valid_ssn($num), $ssns{$num}->[0]);
	ok($ssn->get_state($num), $ssns{$num}->[1]);
}
