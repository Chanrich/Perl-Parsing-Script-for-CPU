#!/usr/local/bin/perl
#use strict;
#use warnings;

my $golden_result = 0;
my $actual_result = 0;

my $file = 'cmd.txt';
open (my $fhc, "<$file");
$file = 'vector_test.txt';
open (OUT, ">$file");

my @cmd_read;
while(<$fhc>){
 chomp;
 push @cmd_read, $_;
}
close $fhc;

my $cmd_loop_ind = 0;
my $cmd_read_length = scalar(@cmd_read); # find number of command lines
my @cmd_array;
#print "Comparison starts!\n";
my $command_number = 1;
my $error_code = 0;
my $cmd_array_length = 0;
my $addr_str = 0;

my $time_per_line = 1;	#1ns per line;
my $threshold = 0.8;	#logical threshold;

for (my $i = 0; $i < $cmd_read_length; $i++) {
	 #print "command read = $cmd_read[$i]\n\n\n";
	 @cmd_array = split(/\s+/,  $cmd_read[$i]);
	 $cmd_array_length = scalar(@cmd_array);

	$error_code = 0;

	#print $cmd_array[2];
	my $bl_number = sprintf("%d", $cmd_array[2]);
	if(substr($cmd_array[1], 0,1) eq 'H'){
	$addr_str = substr($cmd_array[1], -2);
	$addr_str = hex($addr_str);
	}
	else {
	$addr_str = substr($cmd_array[1], -6);
	$addr_str = oct("0b$addr_str");
	}

	#if ($bl_number != 4){
	#print $bl_number;}

	#print "bl_number = $bl_number\n";
	#print "addr_str = $addr_str\n";
	if (($cmd_array[0] eq "STORE") && (substr($cmd_array[2], 0, 1)  ne '#')) {
		if ($bl_number != 2 && $bl_number != 4){    # if this column is specifying data length
		$error_code = 1; }
		if ( ($bl_number == 2 &&  $cmd_array_length != 5) || ($bl_number == 4 && $cmd_array_length != 7)  ){    # if correct data number is not given
		$error_code = 2; }
		if ( ($bl_number == 2 && ($addr_str&1) != 0) || ($bl_number == 4 &&   ($addr_str&3) != 0) ){    # if correct start address is not given
		$error_code = 3; }
	}
	
	if (($cmd_array[0] eq "LOAD") && (substr($cmd_array[2], 0, 1)  eq [1..9])) {
		if ($bl_number != 2 && $bl_number != 4){    # if this column is specifying data length
		$error_code = 1; }
		if ( ($bl_number == 2 && ($addr_str&1) != 0) || ($bl_number == 4 &&   ($addr_str&3) != 0) ){    # if correct start address is not given
		$error_code = 3; }
	}
#	$addr_bin = sprintf("%X", substr($cmd_array[1], -2));
	#print "Error code: $error_code\n";
	use Switch;
	switch ($error_code){

    		case 0 {
    			my $data_ind = 0;
    			my $store_ind = 0;
    			if ($cmd_array[0] eq "STORE"){    # for store command
    				$data_ind = 1;
    				$store_ind = 1;
				if (substr($cmd_array[2], 0, 1) ne '#'){    # if this column is specifying data length
					$cmd_loop_ind = $cmd_array[2];
					$data_ind = 3;}
				else{
					$cmd_loop_ind = 1;
					$data_ind = 2;
				}
			}

			else{    #for load command
    				$data_ind = 1;
    				$store_ind = 0;
				if ($cmd_array[2] == 2 || $cmd_array[2] == 4){    # if this column is specifying data length
					$cmd_loop_ind = $cmd_array[2];}
				else{
					$cmd_loop_ind = 1;
				}
			}
			#printf "it begins...%d\n", $cmd_loop_ind;
			my $data_sram;

			for (my $j = 0; $j < $cmd_loop_ind; $j++){
					print OUT "$command_number ";    # first column prints command line number
					$command_number = $command_number +1;
					if ($store_ind == 1){
						print OUT "STORE ";    # STORE
					}
					else {
						print OUT "LOAD ";	# LOAD
					}
					my $addr_str2 = $addr_str + $j;

					# print out address 5:4, 3:0, and inverted address 5:4, 3:0
					printf OUT "%X ", $addr_str2; # take the 2 LSBs from the first letter of A
					$data_sram = hex(substr($cmd_array[$j+$data_ind], -4));
					printf OUT "%X ", $data_sram; # data[15:12]

					print OUT  "; $cmd_read[$i]\n";
			}
		}

    		case 1 {print "Error000: Command $cmd_read[$i] has invalid burst length.\n";}
		case 2 {print "Error001: Command $cmd_read[$i] does not provide sufficient data.\n";}
    		case 3 {print "Error002: Command $cmd_read[$i] does not have appropriate starting address.\n";}

	}
}

close OUT;

$file = 'vector_test.txt';
open (my $fhc, "<$file");

$file = 'golden_result_sram.txt';
open (OUT, ">$file");

my @cmd_read;
while(<$fhc>){
 chomp;
 push @cmd_read, $_;
}
close $fhc;

$cmd_read_length = scalar(@cmd_read); # find number of command lines
my @cmd_array;
my @cmd_array2;
for (my $i = 0; $i < $cmd_read_length; $i++) {
	 #print "command read = $cmd_read[$i]\n\n\n";
	 @cmd_array = split(/\s+/,  $cmd_read[$i]);
	 $cmd_array_length = scalar(@cmd_array);
	if ($cmd_array[1] eq "LOAD"){
		for (my $j = $i; $j > -1; $j--){
	 		@cmd_array2 = split(/\s+/,  $cmd_read[$j]);
			if (($cmd_array2[1] eq "STORE") && ($cmd_array2[2] == $cmd_array[2])){
				printf OUT "%d %X\n", $cmd_array[0],hex($cmd_array2[3]);
				last;
			}
		} 
	} 
}

close OUT;

open (my $fhc, "<$file");

my @cmd_read;
while(<$fhc>){
 chomp;
 push @cmd_read, $_;
}
close $fhc;

$cmd_read_length = scalar(@cmd_read); # find number of command lines

$file = 'cadence_result.csv';
open (my $fhc, "<$file");
$file = 'actual_result_sram.txt';
open (OUT, ">$file");

my @cadence_read;
while(<$fhc>){
 chomp;
 push @cadence_read, $_;
}
close $fhc;

my $time_per_line = 1; #10ns per line;
my $threshold = 0.8;    #logical threshold;

$cadence_read_length = scalar(@cadence_read); # find number of command lines
$cadence_column_length = 0; # cadence output column number

my @cmd_array;
my @cmd_array2;
my $read_time = 0;
my $col_ind =0;
for (my $i = 0; $i < $cmd_read_length; $i++) {
         @cmd_array = split(/\s+/,  $cmd_read[$i]);
         $read_time = (($cmd_array[0])*3+2)*$time_per_line;
                for (my $j = $cadence_read_length; $j > 1; $j--){ #first line is not data (signal names)
                        @cmd_array2 = split(',',  $cadence_read[$j-1]);
                        $cadence_column_length = scalar(@cmd_array2); # find number of command lines
                        #print "reading $j line: $cadence_read[$j]\n";
                        if (sprintf("%.15f", $cmd_array2[0])*1e9 < $read_time){
                                my $asd = sprintf("%.15f", $cmd_array2[0])*1e9;
                                print "for read at $read_time, we found:   $asd, column: $cadence_column_length, line number: $j\n";
                                for ($col_ind = 1; $col_ind < $cadence_column_length; $col_ind++){
                               # print "$col_ind\n";
                                        if (sprintf("%.15f", $cmd_array2[$col_ind]) < $threshold){
                                                printf OUT "0";}
                                        else{
                                                printf OUT "1";}
                                }
                        printf OUT "\n";
                        last;
                        }

                }
}

close OUT;

#final verification

$file = 'golden_result_sram.txt';
open (my $fhc, "<$file");
$file = 'actual_result_sram.txt';
open (my $fha, "<$file");

my @cmd_read;
while(<$fhc>){
 chomp;
 push @cmd_read, $_;
}
close $fhc;

$cmd_read_length = scalar(@cmd_read); # find number of command lines

my @cadence_read;
while(<$fha>){
 chomp;
 push @cadence_read, $_;
}
close $fha;

$cadence_read_length = scalar(@cadence_read); # find number of command lines

print "Data comparison ***********\n\n\n";
my @cmd_array;
my $cmd_array2;
for (my $i = 0; $i < $cmd_read_length; $i++) {
         @cmd_array = split(/\s+/,  $cmd_read[$i]);
         if (hex($cmd_array[1]) != oct("0b$cadence_read[$i]") ){
		$cmd_array2 = hex($cmd_array[1]);
		print "data $i: error\n";
		printf "golden: %X, ", $cmd_array2;
		printf "actual_raw: $cadence_read[$i]";
		$cmd_array2 = oct("0b$cadence_read[$i]");
		printf "actual: %X\n", $cmd_array2;
	}
	else{
		$cmd_array2 = hex($cmd_array[1]);
		print "data $i: correct\n";
		printf "golden: %X, ", $cmd_array2;
		$cmd_array2 = oct("0b$cadence_read[$i]");
		printf "actual: %X\n", $cmd_array2;

	}
}
