#!/usr/bin/perl

if($ARGV[0] eq "bitmap") {
	$bitmap=1;
} else {
	$bitmap=0;
}

$i=1;

print "struct integer_map $ARGV[1]\[\] = {\n";

while(<STDIN>) {

	chomp;
	@symbols = split;

	foreach $sym (@symbols) {
		print "#ifdef $sym\n";
		if( $bitmap==1 ) { 
			printf "\t{ $sym,\t0x%x,\t\"$sym\"},\n", $i;
		} else {
			printf "\t{ $sym,\t%d,\t\"$sym\"},\n", $i;
		}
		print "#endif\n";
	}

	if( $bitmap==1 ) {
		$i=$i*2;	
	} else {
		$i++;
	}
}

print "\t{-1,\t-1,\t0},\n";
print "};\n";
