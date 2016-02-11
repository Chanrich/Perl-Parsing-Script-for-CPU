#!/usr/local/bin/perl
print "Perl Command Parsing Script\n";
open(FILE1, "cmd_new.txt") || die "Error: $!\n";
open(FILE2, "top.vec") || die "Error: $!\n";
open(my $outputFile, '>', "solution.txt");
open(my $goldenresult, '>', "goldenresult.txt");
my @registers = ();
my $verifycount = 0;
my @golden_memory_address;
my %mem;
my $store_addr_54, $store_addr_30;
$registers[9] = 0;
my $index;
for($index=0;$index<=8;$index++){
	$registers[$index] = 0;
}	
while (my $loadline = <FILE2>){
	my @arg = split " " , $loadline;
	if (@arg[1] eq "1" and @arg[6] eq "1" and @arg[7] eq "1" and @arg[8] eq "0"){
		## Load $0 line
		$golden_memory_address[$verifycount] = @arg[13].@arg[14];
		$verifycount++;
		printf $goldenresult "%s\n", @arg[0];
	}
}
while (my $line = <FILE1>) {
	my @arg = split " " , $line;
	my $arraySize = @arg;
	if (@arg[0] eq "STOREI"){
		## STOREI {bl} xxH #xxxxxxxx {#xxxxxxxx #xxxxxxxx }
		## Store xxxx into word xxH
		my $a; my $max_a;	
		my $offset = 0;
		my $burst;
		## Check for burst
		if (@arg[1] == 2 && $arraySize == 5){
			my @addhex = split "", @arg[2];
			if (hex(@addhex[1]) % 2 != 0 && @addhex[2] eq "H"){
				##
				print $outputFile "Error002: Command doesn’t have an appropriate starting address\n";		
				next;		
			}
			if ( (@addhex[7] ne "0") && @addhex[8] eq "B"){
				##
				print $outputFile "Error002: Command … doesn’t have an appropriate starting address\n";		
				next;		
			} 
			$max_a = 2;
			$offset = 1;

		} elsif (@arg[1] == 4 && $arraySize == 7){
			# Burst of 4
			my @addhex = split "", @arg[2];
			if (hex(@addhex[1]) % 4 != 0 && @addhex[2] eq "H"){
				##
				print $outputFile "Error002: Command … doesn’t have an appropriate starting address\n";		
				next;		
			} 
			if ( (@addhex[7] ne "0" || @addhex[6] ne "0") && @addhex[0] eq "B"){
				##
				print $outputFile "Error002: Command … doesn’t have an appropriate starting address\n";		
				next;		
			} 
			$max_a = 4;
			$offset = 1;
		} elsif ($arraySize == 3) {
			# Burst of 1
			$max_a = 1;
		} else {
			## Error
			if (@arg[2] == 2 || @arg[2] == 4){
				print $outputFile "Error001: Command …doesn’t provide sufficient data.\n";
				next;
			} else {
				print $outputFile "Error000: Command … has invalid burst length.\n";
				next;
			}
		}
		$burst = 0;
		if ( load_store_address(@arg[1 + $offset]) lt 0){
			next;
		}
		for ($a = 0; $a < $max_a; $a++){
			if ($a > 0){
				## increment store address for busrt
				$store_addr_30 = $store_addr_30 + 2;
				if ($store_addr_30 == hex(10)){
					## overflow
					$store_addr_54 += 1;
					$store_addr_30 = 0;
				}
			} 
			$mem{oct("0x".$store_addr_54.$store_addr_30)} = get_data(@arg[2+$offset+$a]);
			printf $outputFile "data at %s%X%X is %d\n", "0x",$store_addr_54,$store_addr_30, 	$mem{oct("0x".$store_addr_54.$store_addr_30)};
		}

	} elsif (@arg[0] eq "STORE"){
		#STORE xxH $R 		Store data from register $R into word xxH
		# or binart address 00000000B
		my @register_temp = split '\$', @arg[2];
		load_store_address(@arg[1]);
		$mem{oct("0x".$store_addr_54.$store_addr_30)} = $register[hex(@register_temp[1])];
		printf $outputFile "Store: Reg[%X] into Mem[%s%X%X] now has %d\n",hex(@register_temp[1]), "0x",$store_addr_54,$store_addr_30,$mem{oct("0x".$store_addr_54.$store_addr_30)};

	} elsif (@arg[0] eq "LOAD"){
		## LOAD $R xxH
		## Load word xxH into register $R
		my @register_temp = split '\$', @arg[1];
		load_store_address(@arg[2]);
		$register[hex(@register_temp[1])] = $mem{oct("0x".$store_addr_54.$store_addr_30)};
		printf $outputFile "Updated Register %X with %d\n", @register_temp[1], $register[hex(@register_temp[1])];
		## Also check if we are loading into $0 , save those value to a file
		if (hex(@register_temp[1]) == 0) {
			printf $goldenresult "SRAM[%X]: %X\n" ,oct("0x".$store_addr_54.$store_addr_30), $mem{oct("0x".$store_addr_54.$store_addr_30)};

		}
	} elsif (@arg[0] eq "AND"){
		## AND $x $y $z
		## Bitwise AND value in register y with value in register z, save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], @register_temp_z[1], $register[@register_temp_z[1]];
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] & $register[@register_temp_z[1]];
		printf $outputFile "AND operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];

	} elsif (@arg[0] eq "ANDI"){
		## ANDI $x $y #xxxxxxxx
		## Bitwise AND value in register y with value xxxxxxxx, save the result in register x
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[%d] : %d, Im : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] & get_data(@arg[3]);
		printf $outputFile "ANDI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];

	} elsif (@arg[0] eq "OR"){
		## OR $x $y $z 
		## Bitwise OR value in register y with value in register z, save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], @register_temp_z[1], $register[@register_temp_z[1]];
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] | $register[@register_temp_z[1]];
		printf $outputFile "OR operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "ORI"){
		## ORI $x $y #xxxxxxxx
		## Bitwise OR value in register y with value xxxxxxxx, save the result in register x
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[y] : %d, R[z] : %d\n", $register[@register_temp_y[1]], get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] | get_data(@arg[3]);
		printf $outputFile "ORI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "XOR"){
		## XOR $x $y $z
		## Bitwise XOR value in register y with value in register z, save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], @register_temp_z[1], $register[@register_temp_z[1]];
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] ^ $register[@register_temp_z[1]];
		printf $outputFile "XOR operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "XORI"){
		## XORI $x $y #xxxxxxxx
		## Bitwise XOR value in register y with value xxxxxxxx, save the result in register x
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[%d] : %d, Im : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] ^ get_data(@arg[3]);
		printf $outputFile "XORI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "NOP"){
		## No operation
	} elsif (@arg[0] eq "ADD"){
		## ADD $x $y $z
		## ADD value in register y with value in register z, save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], @register_temp_z[1], $register[@register_temp_z[1]];
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] + $register[@register_temp_z[1]];
		printf $outputFile "ADD operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "ADDI"){
		## ADDI $x $y #xxxxxxxx
		## ADD value in register y with value xxxxxxxx, save the result in register
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[%d] : %d, Im : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] + get_data(@arg[3]);
		printf $outputFile "ADDI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "SUBTR"){
		## SUBTR $x $y $z
		## SUBTRACT value in register y with the value in register z, save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], @register_temp_z[1], $register[@register_temp_z[1]];
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] - $register[@register_temp_z[1]];
		printf $outputFile "SUBTR operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "SUBTRI"){
		## SUBTRI $x $y #xxxxxxxx
		## SUBTRACT value in register y with value xxxxxxxx, save the result in register x.
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[%d] : %d, Im : %d\n", @register_temp_y[1], $register[@register_temp_y[1]], get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = $register[@register_temp_y[1]] - get_data(@arg[3]);
		printf $outputFile "SUBTRI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "MUL"){
		## MUL $x $y $z
		## MUL value in register y (lower 8bits) with value in register z (lower 8bits), save the result in register x
		my @register_temp_y = split '\$', @arg[2];
		my @register_temp_z = split '\$', @arg[3];
		my @register_temp_x = split '\$', @arg[1];
		printf $outputFile "R[%d] : %d, R[%d] : %d\n", @register_temp_y[1], ($register[@register_temp_y[1]] & 255), @register_temp_z[1], ($register[@register_temp_z[1]] & 255);
		$register[hex(@register_temp_x[1])] = ($register[@register_temp_y[1]]& 255) * ($register[@register_temp_z[1]]& 255);
		printf $outputFile "MuL operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	} elsif (@arg[0] eq "MULI"){
		## MULI $x $y #xx
		## MUL value in register y (lower 8bits) with value xx, save the result in register
		my @register_temp_x = split '\$', @arg[1];
		my @register_temp_y = split '\$', @arg[2];
		printf $outputFile "R[%d] : %d, Im : %d\n", @register_temp_y[1], ($register[@register_temp_y[1]] & 255), get_data(@arg[3]);
		$register[hex(@register_temp_x[1])] = ($register[@register_temp_y[1]]& 255) * get_data(@arg[3]);
		printf $outputFile "MULI operation; Reg[%X] with %d\n", @register_temp_x[1], $register[hex(@register_temp_x[1])];
	}

}
close($goldenresult);
##open $myresult, '<', "goldenresult.txt";
open(FILE3,  "goldenresult.txt"); ## Read the csv file
my $loop;
my @timing;
for ($loop = 0; $loop < $verifycount; $loop++){
	## Get timing number
	my $linebyline = <FILE3>;
	$timing[$loop] = $linebyline + 8 ; ## add 8 for result offset
	printf "Number from file:%d\n", $timing[$loop];
}
my @goldennumber;
for ($loop = 0; $loop < $verifycount; $loop++){
	## Get golden result values
	my $linebyline = <FILE3>;
	my @number = split " ", $linebyline;
	$goldennumber[$loop] = hex(@number[1]);
	printf "Values from file :%d at goldennumber[%d]\n", @goldennumber[$loop], $loop;
}
close FILE3;
print "====Data Comparison Start====\n";
print "Verifycount: $verifycount\n";
for ($loop = 0; $loop < $verifycount; $loop++){
	printf "#$loop Load \$0 [%s]\n", $golden_memory_address[$loop];
	## Get golden result values
	open(CSV, "top1.csv");
	my $firstline = 0;
	while ($csvline = <CSV>){
		## Find the time that match
		$my_actual_value = "";
		my @segments = split ",", $csvline;
		$segments_counts = scalar(@segments);
		if ( (($segments[0]*1e9)) <=  $timing[$loop]+3.5 and (($segments[0]*1e9)) >= $timing[$loop] and $firstline ne 0) {
			##print "Found a match, size of the line is $segments_counts\n";
			printf "The match is at %d and my timing number is %d\n", (($segments[0]*1e9)), $timing[$loop] ;
			my $wordcount;
			for ($wordcount = 1; $wordcount < $segments_counts; $wordcount++){
				if ($segments[$wordcount] > 0.8){
					$my_actual_value = $my_actual_value.'1';
				} else {
					$my_actual_value = $my_actual_value.'0';
				}
			}
			#printf "Comparing my real number %d with sim value %d [%s]\n", $goldennumber[$loop], unpack('i', pack('I', oct("0b$my_actual_value"))) , $my_actual_value;
			if ($goldennumber[$loop] == unpack('i', pack('I', oct("0b$my_actual_value"))) ){
				print "Value $my_actual_value is correct\n";
				last;
			} else {
				if ($my_actual_value eq ""){
					print "Time Mismatch\n";
				} else {
					printf "Actual Value: %d | Calculated Value: %d\n", unpack('i', pack('I', oct("0b$my_actual_value"))), $goldennumber[$loop];
				}

			}
			last;
		}
		if (eof){
			if ($my_actual_value eq ""){
				print "Time Mismatch\n";
			} else {
				printf "Value %d is not correct\n", unpack('i', pack('I', oct("0b$my_actual_value")));
			}
		}
		$firstline = 1;

	}
}

# for($index=0;$index<=8;$index++){
#      printf $outputFile "Register[%d]: 0x%X\n", $index, $register[$index];
#  }

#  foreach (sort keys %mem) {
#     print $outputFile "mem[0x$_] : $mem{$_}\n";
#   }

sub get_data {
	my ($dataline) = @_;
	my @data_split = split "#", $dataline;
	return unpack('i', pack('I', hex(@data_split[1])));
}

sub load_store_address{
	## load a 6 bits store address
	my ($dataline) = @_;
	my @data_split = split "", $dataline;
	if (@data_split[2] eq "H"){
		## Data is in Hex, check for limit
		if (hex(@data_split[0]) gt 3){
			## Greater than 3 too big
			printf $outputFile "Error: Memory address is greater than 3F\n";
			return -1;
		} else {
			$store_addr_54 = hex(@data_split[0]);
			$store_addr_30 = hex(@data_split[1]);
		}
	} elsif (@data_split[8] eq "B"){
		if (@data_split[0] eq "1" or @data_split[1] eq "1"){
			## Too big
			printf $outputFile "Error: Memory address is greater than 00111111\n";
			return -1;
		} else {
			$store_addr_54 = oct("0b".@data_split[2].@data_split[3]);
			$store_addr_30 = oct("0b".@data_split[4].@data_split[5].@data_split[6].@data_split[7]);
		}
	}
	return 1;
}

sub get_reg_hex {
	my ($input_text) = @_;
	my @register_temp = split '\$', $input_text;
	printf $outputFile "REGHEX: %X\n", hex(@register_temp[1]);
	return hex(@register_temp[1]);
}

