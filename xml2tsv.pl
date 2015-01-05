#!/usr/bin/perl -w
use strict;
use XML::Twig; # This module provides a way to process XML documents. It is build on top of XML::Parser.
use Getopt::Long;
my ($xmlfile,$tsvfile,$rowtag, $depth);
GetOptions("in=s"=>\$xmlfile, "out=s"=>\$tsvfile, 'row=s'=>\$rowtag, 'depth=i'=>\$depth);
my $usage = "xlm2tsv converts generic xml file to tab delimited format (tsv). The program automatically generate column names for the table based on the xml tags.
Usage: xml2tsv.pl -i xmlfile -o tsvfile -row rowtag 
[-in xmlfile] input xml file
[-out tsvfile] output tsv file
[-row rowtag] tag (which should occure multiple times) that is used as rows in tsv
[-depth depth] default=1, the absolute depth of the rowtag within the xml, relative to root (depth 0)
example: xml2tsv.pl -i drugbank.xml 
by Yong Fuga Li @ stanford, 20130414\n\n";

defined $xmlfile or die "Wrong usage!\n\n$usage\n";
$rowtag = 'drug' if (not defined $rowtag);
$depth = 1 if (not defined $depth);
## get input files
my $XML;
open $XML, $xmlfile or die "Cannot open $xmlfile.\n";
$xmlfile =~ /^(.+)\.[^\.]+$/;
my $tag = $1;
$tsvfile = $1.'.tsv' if (not defined $tsvfile or $tsvfile eq '');

## pass 1: get field names
my %one; # one row with field names to values 
my $rowIn = 0; # within a row start-tag end-tag pair 
print("Generating column names ...\n");
my $d = 0; # depth
my @tagStack = (); # stack of the tags encountered
my ($key,$value, $attributes, @attributes,$akey,$avalue, $cname, $tmp);
my @line;
# $/ = "<\/$rowtag>"; # 
use File::Stream;
my $XML1 = File::Stream->new($XML);
$/ = qr/>\s*</;

@tagStack = ();
$rowIn = 0;
my @columns = ();
my $xml = '';
while (<$XML1>){
	# chomp;
	s/>\s*<$//;
	s/^<//; # 20141207
	s/[\n\r]//g;
	# print "$_ xxxxxx\n";

	## get tag attributes
	if (/^([^\s<>=\/\\]+)\s*((?:\s+[^\s<>=\/\\]+\=["'].*["'])*)\s*(?:>([^<>]*)<[^<>]+)?$/){
		$key = $1;
		push @tagStack, $key; # record all the preceding tags
		$rowIn = 1 if ($key eq $rowtag && $#tagStack == $depth);
		# print "push: $key; $#tagStack; $rowIn\n";
		$attributes = $2;
		if ($attributes){
			$attributes =~ s/["\s]*$//;
			$attributes =~ s/^\s*//;
			# print "$attributes\n";
			# sleep 1;
			@attributes = split('" ',$attributes);
			for my $a (@attributes){
				($akey, $avalue) = split('="',$a);
				$cname = join('.',@tagStack[1..$#tagStack]).'.'.$akey;
				if ($rowIn && not exists $one{$cname}){
					$one{$cname} = '';
					push @columns, $cname;  
				}
				# print "$akey, $avalue;\n";
				# sleep 1;
			}
		}
		$value = '';
		if (defined $3){ # have value and end tab
			$value = $3;
			$cname = join('.',@tagStack[1..$#tagStack]);
			if ($rowIn && not exists $one{$cname}){
				$one{$cname} = '';
				push @columns, $cname;  
			}
			$tmp = pop @tagStack;
			$rowIn = 0 if ($tmp eq $rowtag && $#tagStack+1 == $depth);
			# print "pop: $tmp; $#tagStack; $rowIn\n";
			# sleep 1;
		}
		#print "$1, $2,";
		#print $3 if (defined $3);
		#print " \n";
		#sleep 1;
	}elsif (/^\//){
			if ($#tagStack>=0){
				$tmp = pop @tagStack;
				$rowIn = 0 if ($tmp eq $rowtag && $#tagStack+1 == $depth);
				# print "pop: $tmp; $#tagStack; $rowIn\n";
				# sleep 1;
			}
	}
}

my %template = %one;
close $XML;
close $XML1;
my $XML2;
open $XML2, $xmlfile or die "Cannot open $xmlfile.\n";
$XML1 = File::Stream->new($XML2);
$/ = qr/>\s*</;
open OUT, ">$tsvfile" or die("Can not open $tsvfile\n");	
print OUT join("\t",@columns)."\n";

print("Generating output file ...\n");
$rowIn = 0;
while (<$XML1>){
	# chomp;
	s/>\s*<$//;
	s/^<//; # 20141207
	s/[\n\r]//g;
	# print "$_ xxxxxx\n";

	## get tag attributes
	if (/^([^\s<>=\/\\]+)\s*((?:\s+[^\s<>=\/\\]+\=["'].*["'])*)\s*(?:>([^<>]*)<[^<>]+)?$/){
		$key = $1;
		push @tagStack, $key; # record all the preceding tags
		if ($key eq $rowtag && $#tagStack == $depth){
			$rowIn = 1;
			%one = %template;
		}
		# print "push: $key; $#tagStack; $rowIn\n";
		$attributes = $2;
		if ($attributes){
			$attributes =~ s/["\s]*$//;
			$attributes =~ s/^\s*//;
			# print "$attributes\n";
			# sleep 1;
			@attributes = split('" ',$attributes);
			for my $a (@attributes){
				($akey, $avalue) = split('="',$a);
				$cname = join('.',@tagStack[1..$#tagStack]).'.'.$akey;
				$avalue =~ s/[\t\n\r]//g;
				$one{$cname} .= ($one{$cname}?';':'').$avalue if ($rowIn);
				# print "$cname, $avalue\n"
				# print "$akey, $avalue;\n";
				# sleep 1;
			}
		}
		$value = '';
		if (defined $3){ # have value and end tab
			$value = $3;
			$cname = join('.',@tagStack[1..$#tagStack]);
			$value =~ s/[\t\n\r]//g;
			$one{$cname} .= ($one{$cname}?';':'').$value  if ($rowIn);
			$tmp = pop @tagStack;
			if ($tmp eq $rowtag && $#tagStack+1 == $depth){
				$rowIn = 0; 
				print OUT join("\t",@one{@columns})."\n";
			}
			# print "pop: $tmp; $#tagStack; $rowIn\n";
			# sleep 1;
		}
		#print "$1, $2,";
		#print $3 if (defined $3);
		#print " \n";
		#sleep 1;
	}elsif (/^\//){
			if ($#tagStack>=0){
				$tmp = pop @tagStack;
				if ($tmp eq $rowtag && $#tagStack+1 == $depth){
					$rowIn = 0; 
					print OUT join("\t",@one{@columns})."\n";
				}
				# print "pop: $tmp; $#tagStack; $rowIn\n";
				# sleep 1;
			}
	}
}
close OUT;
# print $/;
=a
for (<XML>){
	chomp;
	s/[\n\r]//g;
	@line = split '>\s*<';
	$rowIn = 0;
	@tagStack = ();
	for my $l (@line){
		$rowIn = 1 if ($l =~ /^$rowtag/);
		next if (not $rowIn);
		# print "$l\n";
		
		## get tag attributes
		if ($l =~ /^([^\s<>=\/\\]+)\s*((?:\s+[^\s<>=\/\\]+\=["'].*["'])*)\s*(?:>([^<>]*)<[^<>]+)?$/){
			$key = $1;
			push @tagStack, $key; # record all the preceding tags
			print "push: $key\n";
			$attributes = $2;
			if ($attributes){
				$attributes =~ s/["\s]*$//;
				$attributes =~ s/^\s*//;
				print $attributes;
				# sleep 1;
				@attributes = split('" ',$attributes);
				for my $a (@attributes){
					($akey, $avalue) = split('="',$a);
					$one{join('.',@tagStack).'.'.$akey} = $avalue;
					# print "$akey, $avalue;\n";
					# sleep 1;
				}
			}
			$value = '';
			if (defined $3){ # have value and end tab
				$value = $3;
				$one{join('.',@tagStack)} = $value;
				my $tmp = pop @tagStack;
				print "pop: $tmp\n";
				# sleep 1;
			}
			#print "$1, $2,";
			#print $3 if (defined $3);
			#print " \n";
			#sleep 1;
		}elsif ($l=~ /^\//){
				my $tmp = pop @tagStack;
				print "pop: $tmp\n";
				# sleep 1;
		}

	}
}

## pass 2: get field values and print
my @columns = sort keys(%one);
my %template = %one;
for (@columns){
	print "$_\n";
}
=cut
