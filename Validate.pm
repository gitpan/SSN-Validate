package SSN::Validate;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.17';

# Preloaded methods go here.

# Data won't change, no need to _init() for every object
my $SSN = _init();

## "Within each area, the group number (middle two (2) digits) 
##  range from 01 to 99 but are not assigned in consecutive 
##  order. For administrative reasons, group numbers issued 
##  first consist of the ODD numbers from 01 through 09 and 
##  then EVEN numbers from 10 through 98, within each area 
##  number allocated to a State. After all numbers in group 98 
##  of a particular area have been issued, the EVEN Groups 02 
##  through 08 are used, followed by ODD Groups 11 through 99."
##
##  ODD - 01, 03, 05, 07, 09 
##  EVEN - 10 to 98
##  EVEN - 02, 04, 06, 08 
##  ODD - 11 to 99
my $GROUP_ORDER = [
    '01', '03', '05', '07', '09', 10,   12, 14, 16, 18, 20, 22,
    24,   26,   28,   30,   32,   34,   36, 38, 40, 42, 44, 46,
    48,   50,   52,   54,   56,   58,   60, 62, 64, 66, 68, 70,
    72,   74,   76,   78,   80,   82,   84, 86, 88, 90, 92, 94,
    96,   98,   '02', '04', '06', '08', 11, 13, 15, 17, 19, 21,
    23,   25,   27,   29,   31,   33,   35, 37, 39, 41, 43, 45,
    47,   49,   51,   53,   55,   57,   59, 61, 63, 65, 67, 69,
    71,   73,   75,   77,   79,   81,   83, 85, 87, 89, 91, 93,
    95,   97,   99
];

my $ADVERTISING_SSN = [
	'042103580', 
	'062360749', 
	'078051120', 
	'095073645', 
	128036045, 
	135016629, 
	141186941, 
	165167999, 
	165187999, 
	165207999, 
	165227999, 
	165247999, 
	189092294, 
	212097694, 
	212099999, 
	306302348, 
	308125070, 
	468288779, 
	549241889, 
  987654320,
  987654321,
  987654322,
  987654323,
  987654324,
  987654325,
  987654326,
  987654327,
  987654328,
  987654329,
];

my $BAD_COMBO = [
	55019,
	58619,
	58629,
	58659,
	58659,
	58679..58699
];

sub new {
    my ( $proto, $args ) = @_;

    my $class = ref($proto) || $proto;
    my $self = {};
    bless( $self, $class );

    $self->{'SSN'}                = $SSN;
    $self->{'GROUP_ORDER'}        = $GROUP_ORDER;
    $self->{'AD_SSN'}             = $ADVERTISING_SSN;
    $self->{'BAD_COMBO'}          = $BAD_COMBO;
    $self->{'BAD_COMBO_IGNORE'}   = $args->{'ignore_bad_combo'} || 0;

    return $self;
}

sub valid_ssn {
    my ( $self, $ssn ) = @_;

    $ssn =~ s!\D!!g;

    if ( length $ssn != 9 ) {
        $self->{'ERROR'} = "Bad SSN length";
        return 0;
    }

	# Check for known invalid SSNs
	# Start with Advertising SSNs. The SSA suggests the range of
	# 987-65-4320 thru 987-65-4329 but these have also been used
	# in ads.

	if (in_array($ssn, $self->{'AD_SSN'})) {
		$self->{'ERROR'} = 'Advertising SSN';
		return 0;
	}

    my $area   = substr( $ssn, 0, 3 );
    my $group  = substr( $ssn, 3, 2 );
    my $serial = substr( $ssn, 5, 4 );

	# Some groups are invalid with certain areas.
	# Rhyme and reason are not a part of the SSA.

	if (!$self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
		$self->{'ERROR'} = 'Invalid area/group combo';
		return 0;
	}
				
    if ( !$self->valid_area($area) ) {
        $self->{'ERROR'} = "Bad Area";
        return 0;
    }
    elsif ( !$self->valid_group($ssn) ) {
        $self->{'ERROR'} = "Bad Group";
        return 0;
    }
    elsif ( !$self->valid_serial($serial) ) {
        $self->{'ERROR'} = "Bad Serial";
        return 0;
    }
    else {
        return 1;
    }

}

sub valid_area {
    my ( $self, $area ) = @_;

		$area = substr( $area, 0, 3) if length $area > 3;

    return exists $self->{'SSN'}->{$area}->{valid} ? 1 : 0;
}

sub valid_group {
    my ( $self, $group ) = @_;

		$group =~ s!\D!!g;

    #if ( length $group == 9 ) {
    if ( length $group > 2 ) {
        my $area = substr( $group, 0, 3 );
        $group = substr( $group, 3, 2 );
        return 0 if $group eq '00';

				if (!$self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
					$self->{'ERROR'} = 'Invalid area/group combo';
					return 0;
				}

        if ( defined $self->{'SSN'}{$area}{'highgroup'} ) {
						# We're igno
					  if ($self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
							return 1;
						}

            return in_array( $group,
                $self->get_group_range( $self->{'SSN'}{$area}{'highgroup'} ) );
        }
        elsif ( defined $self->{'SSN'}{$area}{'group_range'} ) {
            return in_array( $group, $self->{'SSN'}{$area}{'group_range'} );
        }
        else {
            return 1;
        }

    }
    return $group eq '00' ? 0 : 1;
}

sub valid_serial {
    my ( $self, $serial ) = @_;

    return $serial eq '0000' ? 0 : 1;
}

sub get_state {
    my ( $self, $ssn ) = @_;

    my $area = substr( $ssn, 0, 3 );

    if ( $self->valid_area($area) ) {
        return defined $self->{'SSN'}->{$area}->{'state'} 
        	     ? $self->{'SSN'}->{$area}->{'state'} : '';
    }
    else {
        return '';
    }
}

sub get_description {
    my ( $self, $ssn ) = @_;

    my $area = substr( $ssn, 0, 3 );

    if ( $self->valid_area($area) ) {
        return $self->{'SSN'}->{$area}->{'description'};
    }
    else {
        return 0;
    }
}

## given a high group number, generate a list of valid
## group numbers using that wild and carazy SSA algorithm.
sub get_group_range {
    my ( $self, $highgroup ) = @_;

    for ( my $i = 0 ; $i < 100 ; $i++ ) {
        if (
            sprintf( "%02d", $self->{'GROUP_ORDER'}[$i] ) ==
            sprintf( "%02d", $highgroup ) )
        {
            return [ @{ $self->{'GROUP_ORDER'} }[ 0 .. $i + 1 ] ]; # array slice
        }
    }

    return [];
}

sub in_array {
    my ( $needle, $haystack ) = @_;

    foreach my $hay (@$haystack) {
        return 1 if $hay == $needle;
    }
    return 0;
}

sub _init {
    my %by_ssn;

    no warnings 'once';

    # parse data into memory...
    while (<DATA>) {
        chomp;

        # skip stuff that doesn't "look" like our data
        next unless m/^[0-9]{3}/;

        if (/^(\d{3}),(\d{2})\-*(\d*)\D*$/) {
            if ( !defined $3 || $3 eq '' ) {
                $by_ssn{$1}->{'highgroup'} = $2;
            }
            else {
                if ( defined $by_ssn{$1}->{'group_range'} ) {
                    push @{ $by_ssn{$1}->{'group_range'} }, ( $2 .. $3 );
                }
                else {
                    $by_ssn{$1}->{'group_range'} = [ $2 .. $3 ];
                }
            }
            next;
        }

        my ( $numeric, $state_abbr, $description ) = split /\s+/, $_, 3;

        # deal with the numeric stuff...
        $numeric =~ s/[^0-9,-]//;    # sanitize for fun

        # loop over , groups, if any...
        for my $group ( split ',', $numeric ) {

					  # Skip over invalid ranges. Although they may be assigned
						# if they are not yet issued, then no one has an area from
						# it, so it is invalid by the SSA. 
						# May make a 'loose' bit to allow these to validate
						next if $description =~ /not yet issued/i;

            # pull apart hypened ranges
            my ( $min, $max ) = split '-', $group;

            # see whether a range to deal with exists...
            if ( defined $max ) {
                for my $number ( $min .. $max ) {
                    $by_ssn{$number} = {
                        'state'       => $state_abbr,
                        'description' => $description,
												'valid'			  => 1,
                    };
                }
            }
            else {
                $by_ssn{$min} = {
                    'state'       => $state_abbr,
                    'description' => $description,
										'valid'			  => 1,
                };
            }
        }
    }

    return \%by_ssn;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

=pod

=head1 NAME

SSN::Validate - Perl extension to do SSN Validation

=head1 SYNOPSIS

  use SSN::Validate;

  my $ssn = new SSN::Validate;

  or 

  my $ssn = SSN::Validate->new({'ignore_bad_combo' => 1});

  if ($ssn->valid_ssn("123-45-6789")) {
    print "It's a valid SSN";
  }

  my $state = $ssn->get_state("123456789");	
  my $state = $ssn->get_state("123");	

	print $ssn->valid_area('123') ? "Valid" : "Invalid";
	print $ssn->valid_area('123-56-7890') ? "Valid" : "Invalid";

=head1 DESCRIPTION

This module is intented to do some Social Security Number validation (not
verification) beyond just seeing if it contains 9 digits and isn't all 0s. The
data is taken from the Social Security Admin. website, specifically:

http://www.ssa.gov/foia/stateweb.html

As of this initial version, SSNs are validated by ensuring it is 9 digits, the
area, group and serial are not all 0s, and that the area is within a valid
range used by the SSA.

It will also return the state which the SSN was issues, if that data is known
(state of "??" for unknown states/regions).

A SSN is formed by 3 parts, the area (A), group (G) and serial (S):

AAAA-GG-SSSS

=head2 METHODS

=over 4

=item new();

You can pass an arg of 'ignore_bad_combo' as true if you wish to ignore
any defined bad AAAA-GG combinations. Things will be on the list until
I see otherwise on the SSA website or some other means of proof.

=item valid_ssn($ssn);

The SSN can be of any format (111-11-1111, 111111111, etc...). All non-digits
are stripped.

This method will return true if it is valid, and false if it isn't. It
uses the below methods to check the validity of each section.

=item valid_area($ssn);

This will see if the area is valid by using the ranges in use by the SSA. You
can pass this method a full SSN, or just the 3 digit area.

=item valid_group($group);

Will make sure that the group isn't "00", as well as check the
AREA/GROUP combo for known invalid ones, and the SSA High Groups.

If given a 2 digit GROUP, it will only make sure that that GROUP isn't
"00".

If given a number in length above 2 digits, it will attempt to split
into an AREA and GROUP and do further validation.

=item valid_serial($serial);

This is currently only making sure the serial isn't "0000", and that's all it
will ever do. From my reading, "0000" is the only non-valid serial.

This is also semi-useful right now, as it expects only 4 digits. Later it will
take both 4 digits or a full serial.

=item get_state($ssn);

You can give this a full SSN or 3 digit area. It will return the state, if
known, from where the given area is issued. Invalid areas will return
false.

=item get_description($ssn);

If there is a description associated with the state or region, this will return
it.. or will return an empty string.

=back

=head2 TODO

* Change how the data is stored. I don't like how it is done now... but works.

* Find out state(s) for areas which aren't known right now.

* Automate this module almost as completely as possible for
  distribution. 

* Consider SSN::Validate::SSDI for Social Security Death Index (SSDI)

* Possibly change how data is stored (first on TODO), and provide my
	extract script for people to run on their own. This way, maybe they
	could update the SSA changes on their own, instead of being dependant
	on the module for this, or having to update the module when the SSA
	makes changes. I think I like this idea.

=head2 EXPORT

None by default.

=head1 BUGS

Please let me know if something doesn't work as expected.

You can report bugs via the CPAN RT:
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SSN-Validate>

If you are feeling nice, and would like quicker fixes, please provide a
diff against F<Validate.pm> and the appropriate test file(s). If you
are making something invalid which is currently valid, or vice versa,
please provide a reference to why the change is needed. Thanks!

Patches Welcome!

=head1 AUTHOR

Kevin Meltzer, E<lt>kmeltz@cpan.orgE<gt>

=head1 LICENSE

SSN::Validate is free software which you can redistribute and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://www.ssa.gov/foia/stateweb.html>,
L<http://www.irs.gov/pub/irs-utl/1346atta.pdf>,
L<http://www.ssa.gov/employer/highgroup.txt>.

=cut

# store SSN information inside the script down here...
#
# format is simple, three bits of data separated by tabs:
# numeric_range   state_abbr   description
#
# Leave state_abbr empty if not applicable.  numeric_range consits
# of three-digit numbers, with -'s to denote ranges and ,'s to denote
# series of numbers or ranges.
__DATA__
001-003 NH  New Hampshire
004-007 ME  Maine
008-009 VT  Vermont
010-034 MA  Massachusetts
035-039 RI  Rhode Island
040-049 CT  Connecticut
050-134 NY  New York
135-158 NJ  New Jersey
159-211 PA  Pennsylvania
212-220 MD  Maryland
221-222 DE  Delaware
223-231 VA  Virginia
232 NC  North Carolina
232-236 WV West Virginia
237-246	??	Unknown
247-251 SC  South Carolina
252-260 GA  Georgia
261-267 FL  Florida
268-302 OH  Ohio
303-317 IN  Indiana
318-361 IL  Illinois
362-386 MI  Michigan
387-399 WI  Wisconsin
400-407 KY  Kentucky
408-415 TN  Tennessee
416-424 AL  Alabama
425-428 MS  Mississippi
429-432 AR  Arkansas
433-439 LA  Louisiana
440-448 OK  Oklahoma
449-467 TX  Texas
468-477 MN  Minnesota
478-485 IA  Iowa
486-500 MO  Missouri
501-502 ND  North Dakota
503-504 SD  South Dakota
505-508 NE  Nebraska
509-515 KS  Kansas
516-517 MT  Montana
518-519 ID  Idaho
520 WY  Wyoming
521-524 CO  Colorado
525 NM  New Mexico
585 NM  New Mexico
526-527 AZ  Arizona
528-529 UT  Utah
530 NV  Nevada
531-539 WA  Washington
540-544 OR  Oregon
545-573 CA  California
574 AK  Alaska
575-576 HI  Hawaii
577-579 DC  District of Columbia
580     VI Virgin Islands or Puerto Rico
581-584 PR  Puerto Rico
#586     GU Guam
#586     AS American Somoa
#586     PI Philippine Islands
586     ?? Guam, American Samoa, or Philippine Islands
587	?? Unknown
588     ?? New area allocated, but not yet issued
589-595	?? Unknown
596-599	??	Unknown
600-601	?? Unknown
602-626	?? Unknown
627-645	?? Unknown
646-647	?? Unknown
648-649	?? Unknown
650-653 ?? New area allocated, but not yet issued
654-658	?? Unknown
659-665 ?? New area allocated, but not yet issued
#666     ?? Unknown
667-675	?? Unknown
676-679 ?? New area allocated, but not yet issued
680	?? Unknown
681-690 ?? New area allocated, but not yet issued
691-699 ?? New area allocated, but not yet issued
700-728  RB   Railroad Board (discontinued July 1, 1963)
750-751 ?? New area allocated, but not yet issued
752-755 ?? New area allocated, but not yet issued
756-763 ?? New area allocated, but not yet issued
764-899	?? Unknown
#765	?? Unknown
900-999 ?? Taxpayer Identification Number
## high groups
# This is scraped directly from
# http://www.ssa.gov/employer/highgroup.txt
001,06
002,06
003,04
004,08
005,08
006,08
007,06
008,90
009,90
010,90
011,90
012,90
013,90
014,90
015,90
016,90
017,90
018,90
019,90
020,90
021,90
022,90
023,90
024,90
025,90
026,90
027,90
028,90
029,90
030,90
031,90
032,88
033,88
034,88
035,72
036,72
037,72
038,72
039,70
040,11
041,11
042,11
043,11
044,11
045,11
046,11
047,11
048,11
049,11
050,96
051,96
052,96
053,96
054,96
055,96
056,96
057,96
058,96
059,96
060,96
061,96
062,96
063,96
064,96
065,96
066,96
067,96
068,96
069,96
070,96
071,96
072,96
073,96
074,96
075,96
076,96
077,96
078,96
079,96
080,96
081,96
082,96
083,96
084,96
085,96
086,96
087,96
088,96
089,96
090,96
091,96
092,96
093,96
094,96
095,96
096,96
097,96
098,96
099,96
100,96
101,96
102,96
103,96
104,96
105,96
106,96
107,96
108,96
109,96
110,96
111,96
112,96
113,96
114,96
115,96
116,96
117,96
118,96
119,96
120,96
121,96
122,96
123,96
124,96
125,94
126,94
127,94
128,94
129,94
130,94
131,94
132,94
133,94
134,94
135,19
136,19
137,19
138,19
139,19
140,19
141,19
142,19
143,19
144,19
145,19
146,19
147,19
148,19
149,17
150,17
151,17
152,17
153,17
154,17
155,17
156,17
157,17
158,17
159,84
160,84
161,84
162,84
163,84
164,84
165,84
166,84
167,84
168,84
169,84
170,84
171,84
172,84
173,84
174,84
175,84
176,84
177,84
178,84
179,84
180,84
181,84
182,84
183,84
184,84
185,82
186,82
187,82
188,82
189,82
190,82
191,82
192,82
193,82
194,82
195,82
196,82
197,82
198,82
199,82
200,82
201,82
202,82
203,82
204,82
205,82
206,82
207,82
208,82
209,82
210,82
211,82
212,79
213,79
214,79
215,79
216,79
217,79
218,79
219,79
220,79
221,06
222,04
223,99
224,99
225,99
226,99
227,99
228,99
229,99
230,99
231,99
232,53
233,53
234,53
235,53
236,53
237,99
238,99
239,99
240,99
241,99
242,99
243,99
244,99
245,99
246,99
247,99
248,99
249,99
250,99
251,99
252,99
253,99
254,99
255,99
256,99
257,99
258,99
259,99
260,99
261,99
262,99
263,99
264,99
265,99
266,99
267,99
268,13
269,13
270,13
271,13
272,13
273,13
274,13
275,13
276,13
277,13
278,13
279,13
280,13
281,13
282,13
283,13
284,13
285,13
286,13
287,13
288,13
289,13
290,11
291,11
292,11
293,11
294,11
295,11
296,11
297,11
298,11
299,11
300,11
301,11
302,11
303,33
304,33
305,33
306,31
307,31
308,31
309,31
310,31
311,31
312,31
313,31
314,31
315,31
316,31
317,31
318,06
319,06
320,06
321,06
322,06
323,06
324,06
325,06
326,06
327,06
328,06
329,06
330,06
331,06
332,06
333,06
334,06
335,06
336,06
337,06
338,06
339,06
340,06
341,06
342,06
343,06
344,06
345,06
346,06
347,06
348,06
349,06
350,06
351,06
352,06
353,06
354,06
355,04
356,04
357,04
358,04
359,04
360,04
361,04
362,35
363,35
364,35
365,35
366,35
367,35
368,35
369,33
370,33
371,33
372,33
373,33
374,33
375,33
376,33
377,33
378,33
379,33
380,33
381,33
382,33
383,33
384,33
385,33
386,33
387,29
388,29
389,29
390,29
391,29
392,29
393,29
394,29
395,27
396,27
397,27
398,27
399,27
400,69
401,67
402,67
403,67
404,67
405,67
406,67
407,67
408,99
409,99
410,99
411,99
412,99
413,99
414,99
415,99
416,63
417,63
418,61
419,61
420,61
421,61
422,61
423,61
424,61
425,99
426,99
427,99
428,99
429,99
430,99
431,99
432,99
433,99
434,99
435,99
436,99
437,99
438,99
439,99
440,23
441,23
442,23
443,23
444,23
445,23
446,23
447,23
448,21
449,99
450,99
451,99
452,99
453,99
454,99
455,99
456,99
457,99
458,99
459,99
460,99
461,99
462,99
463,99
464,99
465,99
466,99
467,99
468,51
469,51
470,51
471,51
472,51
473,49
474,49
475,49
476,49
477,49
478,37
479,37
480,37
481,37
482,37
483,37
484,37
485,37
486,25
487,25
488,25
489,25
490,25
491,25
492,25
493,25
494,25
495,25
496,25
497,25
498,25
499,23
500,23
501,33
502,33
503,41
504,39
505,53
506,53
507,51
508,51
509,29
510,27
511,27
512,27
513,27
514,27
515,27
516,45
517,43
518,79
519,77
520,55
521,99
522,99
523,99
524,99
525,99
526,99
527,99
528,99
529,99
530,99
531,63
532,63
533,63
534,63
535,61
536,61
537,61
538,61
539,61
540,75
541,75
542,73
543,73
544,73
545,99
546,99
547,99
548,99
549,99
550,99
551,99
552,99
553,99
554,99
555,99
556,99
557,99
558,99
559,99
560,99
561,99
562,99
563,99
564,99
565,99
566,99
567,99
568,99
569,99
570,99
571,99
572,99
573,99
574,51
575,99
576,99
577,45
578,45
579,45
580,37
581,99
582,99
583,99
584,99
585,99
586,61
587,99
588,03
589,99
590,99
591,99
592,99
593,99
594,99
595,99
596,84
597,84
598,84
599,84
600,99
601,99
602,67
603,67
604,67
605,67
606,67
607,67
608,67
609,67
610,65
611,65
612,65
613,65
614,65
615,65
616,65
617,65
618,65
619,65
620,65
621,65
622,65
623,65
624,65
625,65
626,65
627,13
628,13
629,13
630,13
631,11
632,11
633,11
634,11
635,11
636,11
637,11
638,11
639,11
640,11
641,11
642,11
643,11
644,11
645,11
646,98
647,96
648,46
649,44
650,46
651,46
652,46
653,46
654,28
655,26
656,26
657,26
658,26
659,16
660,16
661,16
662,14
663,14
664,14
665,14
667,36
668,36
669,34
670,34
671,34
672,34
673,34
674,34
675,34
676,14
677,14
678,14
679,12
680,92
681,14
682,14
683,14
684,14
685,14
686,12
687,12
688,12
689,12
690,12
691,09
692,09
693,09
694,07
695,07
696,07
697,07
698,07
699,07
700,18
701,18
702,18
703,18
704,18
705,18
706,18
707,18
708,18
709,18
710,18
711,18
712,18
713,18
714,18
715,18
716,18
717,18
718,18
719,18
720,18
721,18
722,18
723,18
724,28
725,18
726,18
727,10
728,14
729,12
730,10
731,10
732,10
733,10
750,09
751,09
752,03
753,01
756,05
757,05
758,05
759,05
760,05
761,05
762,05
763,03
764,84
765,84
766,66
767,66
768,66
769,66
770,66
771,66
772,64
900,70-80 ## Individual Taxpayer Identification Number
900,93-93 ## Adoption Taxpayer Identification Number
