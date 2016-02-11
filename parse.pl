
#!/usr/local/bin/perl
print "Perl Command Parsing Script\n";
open(FILE1, "cmd_TA.txt") || die "Error: $!\n";
open(my $outputFile, '>', "top.vec");
print $outputFile "radix 1 4 1 1  1 1 1  3 3 3 3 3  2 4   4 4 4 4  4 4 4 4\n";
print $outputFile "io    i i i i  i i i  i i i i i  i i      i i i i  i i i i\n";
print $outputFile "vname clk op_code<[3:0]> ex mem   mem_write mem_read write_back    addr<[2:0]> R1<[2:0]> ~R1<[2:0]> R2<[2:0]> ~R2<[2:0]> store_addr<[5:4]> store_addr<[3:0]> ";
print $outputFile "data_in<[31:28]> data_in<[27:24]> data_in<[23:20]> data_in<[19:16]> data_in<[15:12]> data_in<[11:8]> data_in<[7:4]> data_in<[3:0]>\n";
print $outputFile "slope 0.01\n";
print $outputFile "vih 1.8\n";
print $outputFile "tunit 1ns\n\n";


my $ns = 0;
my $clk_period = 2;
# Declaring register variables
my $r1, $r2, $r3, $r2_not, $r3_not;
my $write_back;
# Controlling bits
my $clk;
## Opcode op<1:0>  00 - Mult
## 01 - XOR
## 10 - ADD
## 11 - AND
## Opcode op<2> - select immediate value
## 0 - immediate
## 1 - DATA2
my $op_code, $ex, $mem;
# Memory bits
my $mem_write, $mem_read;
my $store_addr_54, $store_addr_30;
# Data bits
my $data_in_31_28 ,$data_in_27_24 ,$data_in_23_20 ,$data_in_19_16 ,$data_in_15_12 ,$data_in_11_8 ,$data_in_7_4 ,$data_in_3_0;
## Dependency Check
my @last_few_registers = ('10', '10', '10');
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
			## shift the register for dependency check
			unshift @last_few_registers, "10";
			no_writeback_write_sram();
			zero_out_reg();
			$op_code = "0110";
			$ex = 0;
			$mem = 1;
			get_data(@arg[2+$offset+$a]);
			print_commands_to_file();
		}
	} elsif (@arg[0] eq "STORE"){
		#STORE xxH $R 		Store data from register $R into word xxH
		# or binart address 00000000B
		$r1 = 0;
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		$r3 = 0;
		$r3_not = 7;
		## Control bits
		$op_code = "0010";
		$ex = 0;
		$mem = 0;
		no_writeback_write_sram();
		set_data_zero();
		## Dependency Check
		load_dependency_check($r2, $r2, "10");
		## if address bit produces error, don't print
		if (load_store_address(@arg[1]) != -1){
			print_commands_to_file();
		}
	} elsif (@arg[0] eq "LOAD"){
		## LOAD $R xxH
		## Load word xxH into register $R
		$r1 = get_reg_hex(@arg[1]);
		$r2 = 0;
		$r2_not = 7;
		$r3 = 0;
		$r3_not = 7;
		$op_code = "0110";
		$ex = 0;
		$mem = 0;
		writeback_read_sram();
		set_data_zero();
		unshift @last_few_registers, $r1;
		if (load_store_address(@arg[2]) != -1){
			print_commands_to_file();
		}
		
	} elsif (@arg[0] eq "AND"){
		## AND $x $y $z
		## Bitwise AND value in register y with value in register z, save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "0111";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "ANDI"){
		## ANDI $x $y #xxxxxxxx
		## Bitwise AND value in register y with value xxxxxxxx, save the result in register x
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		$op_code = "0011";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		get_data(@arg[3]);
		print_commands_to_file();
	} elsif (@arg[0] eq "OR"){
		## OR $x $y $z 
		## Bitwise OR value in register y with value in register z, save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "1100";
		$ex = 0;
		$mem = 0;		
		set_writeback_sram_no_operation();
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "ORI"){
		## ORI $x $y #xxxxxxxx
		## Bitwise OR value in register y with value xxxxxxxx, save the result in register x
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		get_data(@arg[3]);
		$ex = 0;
		$mem = 0;
		$op_code = "1000";
		set_writeback_sram_no_operation();
		print_commands_to_file();
	} elsif (@arg[0] eq "XOR"){
		## XOR $x $y $z
		## Bitwise XOR value in register y with value in register z, save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "0101";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();

		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "XORI"){
		## XORI $x $y #xxxxxxxx
		## Bitwise XOR value in register y with value xxxxxxxx, save the result in register x
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		get_data(@arg[3]);
		
		$op_code = "0001";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		print_commands_to_file();
	} elsif (@arg[0] eq "NOP"){
		## No operation
		$op_code = "0000";
		$r1 = 0;
		$r2 = 0;
		$r3 = 0;
		$r2_not = 7;
		$r3_not = 7;
		$mem_write = 0;
		$ex = 0;
		$mem = 0;
		$mem_read = 0;
		$store_addr_54 = 0;
		$store_addr_30 = 0;
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "ADD"){
		## ADD $x $y $z
		## ADD value in register y with value in register z, save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "0110";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "ADDI"){
		## ADDI $x $y #xxxxxxxx
		## ADD value in register y with value xxxxxxxx, save the result in register
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		get_data(@arg[3]);
		
		$op_code = "0010";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		print_commands_to_file();
	} elsif (@arg[0] eq "SUBTR"){
		## SUBTR $x $y $z
		## SUBTRACT value in register y with the value in register z, save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "0110";
		$ex = 1;
		$mem = 0;
		set_writeback_sram_no_operation();
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "SUBTRI"){
		## SUBTRI $x $y #xxxxxxxx
		## SUBTRACT value in register y with value xxxxxxxx, save the result in register x.
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		get_data(@arg[3]);
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		$op_code = "0010";
		$ex = 1;
		$mem = 0;
		set_writeback_sram_no_operation();
		print_commands_to_file();
	} elsif (@arg[0] eq "MUL"){
		## MUL $x $y $z
		## MUL value in register y (lower 8bits) with value in register z (lower 8bits), save the result in register x
		## Get registers
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r3 = get_reg_hex(@arg[3]);
		$r2_not = 7 - $r2;
		$r3_not = 7 - $r3;
		## Dependency Check
		load_dependency_check($r2, $r3, $r1);
		## Control bits
		$op_code = "0100";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		set_data_zero();
		print_commands_to_file();
	} elsif (@arg[0] eq "MULI"){
		## MULI $x $y #xx
		## MUL value in register y (lower 8bits) with value xx, save the result in register
		$r1 = get_reg_hex(@arg[1]);
		$r2 = get_reg_hex(@arg[2]);
		$r2_not = 7 - $r2;
		## Dependency Check
		load_dependency_check($r2, $r2, $r1);
		## Special case, reset data bits first then get 8 bits data.
		set_data_zero();
		my @data_split = split "", @arg[3];
		$data_in_7_4 = @data_split[1];
		$data_in_3_0 = @data_split[2];
		$op_code = "0000";
		$ex = 0;
		$mem = 0;
		set_writeback_sram_no_operation();
		print_commands_to_file();
	}
} 
print "File Saved as vector.txt\n";

sub get_reg_hex {
	my ($input_text) = @_;
	my @register_temp = split '\$', $input_text;
	return @register_temp[1];
}

sub zero_out_reg {
	$r1 = 0;
	$r2 = 0;
	$r3 = 0;
	$r2_not = 7;
	$r3_not = 7;
}

sub set_writeback_sram_no_operation {
	$mem_write = 0;
	$mem_read = 0;
	$store_addr_54 = 0;
	$store_addr_30 = 0;
	$write_back = 1;
	return;
}

sub no_writeback_write_sram {
	$mem_write = 1;
	$mem_read = 0;
	$write_back = 0;
	return;
}

sub writeback_read_sram {
	$mem_write = 0;
	$mem_read = 1;
	$write_back = 1;
	return;
}

sub get_data {
	my ($dataline) = @_;
	my @data_split = split "", $dataline;
	$data_in_31_28 = @data_split[1];
	$data_in_27_24 = @data_split[2];
	$data_in_23_20 = @data_split[3];
	$data_in_19_16 = @data_split[4];
	$data_in_15_12 = @data_split[5];
	$data_in_11_8 = @data_split[6];
	$data_in_7_4 = @data_split[7];
	$data_in_3_0 = @data_split[8];
	return;
}

sub set_data_zero {
	$data_in_31_28 = "0";
	$data_in_27_24 = "0";
	$data_in_23_20 = "0";
	$data_in_19_16 = "0";
	$data_in_15_12 = "0";
	$data_in_11_8 = "0";
	$data_in_7_4 = "0";
	$data_in_3_0 = "0";
	return;
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

sub insert_NOP{
	## No operation
	$mem_write = 0;
	$mem_read = 0;
	$write_back = 0;
	print_commands_to_file("NOP");
}

sub load_dependency_check{
	my ($current_register) = @_[0];
	my ($current_register2) = @_[1];
	if (@last_few_registers[0] eq $current_register or @last_few_registers[0] eq $current_register2){
		## insert NoP
		insert_NOP();
		insert_NOP();
		insert_NOP();
	} elsif (@last_few_registers[1] eq $current_register or @last_few_registers[1] eq $current_register2){
		insert_NOP();
		insert_NOP();
	} elsif (@last_few_registers[2] eq $current_register or @last_few_registers[2] eq $current_register2){
		insert_NOP();
	}
	unshift @last_few_registers, @_[2];
	return;
}

sub print_commands_to_file{
	if (@_[0] eq "NOP"){
		## Comment NOP at the end of line
		$clk = 1;
		$ns = $ns + $clk_period;
		print_command_row_no_newline();
		printf $outputFile "; --- |\n";
		$clk = 0;
		$ns = $ns + $clk_period;
		print_command_row_no_newline();
		printf $outputFile "; NOP |\n";
	} else {
		$clk = 1;
		$ns = $ns + $clk_period;
		print_command_row_no_newline();
		printf $outputFile "\n";
		$clk = 0;
		$ns = $ns + $clk_period;
		print_command_row_no_newline();
		printf $outputFile "\n";
	}
}
sub print_command_row_no_newline{
	printf $outputFile "%s %s %X  %X %X  %X %X %X  %X %X %X %X %X  %X %X  ", $ns, $clk, oct("0b".$op_code), $ex, $mem, $mem_write, $mem_read, $write_back, $r1 ,$r2, $r2_not, $r3, $r3_not, $store_addr_54, $store_addr_30;
	printf $outputFile "%s %s %s %s %s %s %s %s", $data_in_31_28 ,$data_in_27_24 ,$data_in_23_20 ,$data_in_19_16 ,$data_in_15_12 ,$data_in_11_8 ,$data_in_7_4 ,$data_in_3_0;
}

sub print_starting_line{
	$ns = 0;
	print_command_row_no_newline();
	printf $outputFile "\n";
}



