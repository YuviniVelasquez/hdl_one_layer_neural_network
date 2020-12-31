module MyDesign
(
	//Control Signals
	input wire			go,		//Start processing
	output reg			busy,	//Let's know when thing is busy
	input wire 			reset,		//Active low Reset
	input wire			clk,		//Clock

	//To output SRAM, SRAM write interface tied
	output reg signed [15:0]	write_data,
	output reg [11:0]	write_address,
	output reg 			write_enable,

	//SRAM interface
	output reg [11:0]	read_input_address,	//SRAM read address
	input wire [15:0]	read_input_data,	//SRAM read data
	output reg [11:0]	read_weight_address,	//SRAM read address
	input wire [15:0]	read_weight_data	//SRAM read data
);

	
	//Reg declaration
	reg [7:0]			size_count;				//Count of data to be read from SRAM//
	reg signed [15:0]	current_data;			//Value of input//
	reg signed [15:0]	current_weight;			//Values of current weight//
    reg [15:0]       	mult_counter_up;		//counts multiplications made//
	reg [7:0]       	convolution_counter_up;	//counts multiplications made//
	reg signed [15:0]	accumulator;		//Accumulator//

	//FSM regs
	reg [3:0]		current_state;				//FSM current state//
	reg [3:0]		next_state;					//FSM next state//

	//Bit selectors (usually for muxes)
	reg [1:0]    	data_input_enable;			//Select line for mux to get data from input//
	reg [1:0]		weight_input_enable;		//Select line for mux to read data from weight//
    reg [1:0]       finish_sum_mult_sel;        //selects when to output to SRAM//
    reg [1:0]		counter_mux_sel;			//Select line for mux to control counter of remaining multiplication//
	reg [1:0]		counter_convolution_sel;	//Select line for mux to control counter of remaining multiplication//
	reg [1:0]		address_input_mux_sel;		//Select line for mux input//
	reg [1:0]		address_weight_mux_sel;		//Select line for mux weight//	
	reg [1:0]		size_count_mux_sel;			//Select line for mux when to receive the size to count//	
	reg [1:0]       ref_mux_sel;                //Select line to control mux for reference_address//
	reg [1:0]		accum_n_enable;				//manages mux for accumulator//Accumulator reg selector//

	//Address refs regs
	reg [9:0]		reference_address;			//address to refer back when counter ends//

	//Wire declaration 
   	wire signed [7:0] 	input_n0 , input_n1; 	//Two inputs per word
   	wire signed [1:0]	weight_n0, weight_n1;	//Selecting two weights to multiply to word
	wire signed [9:0]	input_mul_weight;		//Input*weight
	wire [7:0]      	weight_selector;        //Modulo of counter
    
	//Byte selector for input//

	assign input_n1 = current_data[15:8];
	assign input_n0 = current_data[7:0];

	//Modulo 8//
	assign weight_selector = {{mult_counter_up[15:2] & 14'b0} , mult_counter_up[1:0]};
	
	//Selecting weights
	assign {weight_n1,weight_n0} = current_weight >> 4*weight_selector; 
    
	//Multiplication
	assign input_mul_weight = input_n1 *weight_n1 + input_n0*weight_n0;

    //Parameters
	//FSM greycode
	localparam s0  = 3'b000;
	localparam s1  = 3'b001;
	localparam s2  = 3'b010;
	localparam s3  = 3'b011;
	localparam s4  = 3'b100;
	localparam s5  = 3'b101;
	localparam s6  = 3'b110;
	localparam s7  = 3'b111;
	localparam s8  = 4'b1000;

	//--------------code start--------------//
	//Control Path
		
	//FSM
	always @(posedge clk or negedge reset) begin
		if (!reset)
			current_state <= 4'b0;
		else
			current_state <= next_state;
	end

	always @(*) begin
		casex (current_state)
			s0 : begin								//S0:	clear every register

                data_input_enable = 2'b0;           //clearing current_data reg
                weight_input_enable = 2'b0;         //clearing current_weight reg

                accum_n_enable  = 2'b0;             //clearing accumulator reg
                counter_mux_sel = 2'b0;             //clearing mult_counter_up register
				counter_convolution_sel = 2'b0;		//clearing convolution_counter_up register;

                address_input_mux_sel = 2'b0;       //clearing addres_input_reader,     reading address 0 on next state
                address_weight_mux_sel = 2'b0;      //clearing address_counter_reader,  reading address 0 on next state

                size_count_mux_sel = 2'b0;          //clearing size_count, number of inputs
                ref_mux_sel  = 2'b0;                //clearing ref_address
                finish_sum_mult_sel = 2'b00;        //not ready for writting to SRAM
				busy = 1'b0;

				if (go == 1'b1)
					next_state = s1;
				else
					next_state = s0;
			end
			s1 : begin								//S1: Setup ref_address, setup size_count, Reading from SRAM
                data_input_enable = 2'b01;          //reading from SRAM
                weight_input_enable = 2'b01;        //reading from SRAM

                accum_n_enable  = 2'b00;             //Clearing accumulator
                counter_mux_sel = 2'b10;            //counter_up = counter_up
				counter_convolution_sel = 2'b10;	// convolution_counter_up = convolution_counter_up;

                address_input_mux_sel = 2'b00;      //=0, cannot request SRAM bc it is dependen on ref_address
                address_weight_mux_sel = 2'b00;     //=0

                size_count_mux_sel = 2'b01;         //reading and setting up size_count 
                ref_mux_sel  = 2'b01;               //increase reference address
                finish_sum_mult_sel = 2'b00;         //not ready for writting to SRAM
				busy = 1'b1;

				next_state 	= s2;
			end
			s2 : begin                              //S2: Setting up request from SRAM using reference address, May ooptimize later
                data_input_enable = 2'b10;          //=
                weight_input_enable = 2'b10;        //=
				
                accum_n_enable  = 2'b10;            //=
                counter_mux_sel = 2'b10;            //counter_up = counter_up
				counter_convolution_sel = 2'b10;	// convolution_counter_up = convolution_counter_up;

                address_input_mux_sel = 2'b01;       //Requesting to SRAM address_imput + reference address
                address_weight_mux_sel = 2'b01;      //Requesting to SRAM address_weight + reference address

                size_count_mux_sel = 2'b10;         //=
                ref_mux_sel  = 2'b11;               //=
                finish_sum_mult_sel = 2'b00;         //not ready for writting to SRAM
				busy = 1'b1;

				next_state 	= s3;
			end
			s3 : begin
													//S3:Requesting from SRAM	
                data_input_enable = 2'b01;          //Enable Read from SRAM
                weight_input_enable = 2'b01;        //Enable Read from, SRAM	

				accum_n_enable  = 2'b10;            //=
				counter_mux_sel = 2'b10;            //counter_up = counter_up
				counter_convolution_sel = 2'b10;	// convolution_counter_up = convolution_counter_up;

                address_input_mux_sel = 2'b11;       //SRAM address =
                address_weight_mux_sel = 2'b11;      //SRAM address =

				size_count_mux_sel = 2'b10;         //=
				ref_mux_sel  = 2'b11;               //=
				finish_sum_mult_sel = 2'b10;         //not ready for writting to SRAM but keeping ref address
				busy = 1'b1;

				next_state 	= s4;

			end
			s4 : begin								//enabling Accumulator
													//S4:waitng for SRAM Information
                data_input_enable = 2'b01;          //Enable Read from SRAM
                weight_input_enable = 2'b01;        //Enable Read from, SRAM	
				
				accum_n_enable  = 2'b10;            //=yes
				counter_mux_sel = 2'b10;            //counter_up = counter_up
				counter_convolution_sel = 2'b10;	// convolution_counter_up = convolution_counter_up;


                address_input_mux_sel = 2'b11;       //SRAM address =
                address_weight_mux_sel = 2'b11;      //SRAM address =

				size_count_mux_sel = 2'b10;         //=
				ref_mux_sel  = 2'b11;               //=
				finish_sum_mult_sel = 2'b10;         //not ready for writting to SRAM, but storing previous ref address
				busy = 1'b1;

				next_state 	= s5;
			end
			s5 : begin
				data_input_enable = 2'b10;          //Data from SRAM=
                weight_input_enable = 2'b10;        //Data from SRAM=

				accum_n_enable  = 2'b01;            //yes
				counter_mux_sel = 2'b01;            //counter_up++
				counter_convolution_sel = 2'b01;	//convolution_counter_up +;

				size_count_mux_sel = 2'b10;         //=
				ref_mux_sel  = 2'b11;               //=
				
				finish_sum_mult_sel = 2'b10;         //not ready for writting to SRAM, but storing previous ref address
				busy = 1'b1;

				if (weight_selector == 8'b00000011) 		// if weight selector read 3 times weight
				    address_weight_mux_sel = 2'b10;      	//Requesting to SRAM address_weight + 1
				else
					address_weight_mux_sel = 2'b11;      	//SRAM address =
				
				if (2*(convolution_counter_up) < size_count-2)		//completed all vector of data? 
					begin	
				    	address_input_mux_sel = 2'b10;      //Requesting to SRAM address_input + 1
						next_state = s3;
					end
				else
					begin
						if ( (2*mult_counter_up)+2 == (size_count*size_count) )	//all multiplications completed?
								address_input_mux_sel = 2'b10;      //Requesting to SRAM address_input + 1
						else	
								address_input_mux_sel = 2'b01;       //Request to SRAM reference address information
						begin		
							next_state = s6;					
						end
					end
			end
			s6 : begin			//writing stuff out, verifying if I completed all the multiplications?

				accum_n_enable  = 2'b00;            //clearing for next accumulation
				counter_mux_sel = 2'b10;            //=
				counter_convolution_sel = 2'b00;	//=

                address_input_mux_sel = 2'b11;       //SRAM address =
                address_weight_mux_sel = 2'b11;      //SRAM address =	

				size_count_mux_sel = 2'b10;         //=size_count_mux_sel 	
				ref_mux_sel  = 2'b11;               //=
				finish_sum_mult_sel = 2'b01;         //ready for writting to SRAM
				busy = 1'b1;
				
			if ( (2*mult_counter_up) == (size_count*size_count) )	//if all multiplications have completed
				begin
					data_input_enable = 2'b00;          //clear current_input
                	weight_input_enable = 2'b00;        //clear current_weight
					next_state = s7;					//Prepare for next set of items
				end
			else
				begin
					data_input_enable = 2'b10;          //Data from SRAM=
                	weight_input_enable = 2'b10;        //Data from SRAM=
					next_state = s4;					//go back to accumulating
				end
			end
			s7 : begin // Setting up for next interation of is not the end of the inputs
				data_input_enable = 2'b10;          //Data from SRAM=
                weight_input_enable = 2'b10;        //Data from SRAM=

			    accum_n_enable  = 2'b00;            //Clearing accumulator
				counter_mux_sel = 2'b00;            //Clearing Counter mux
				counter_convolution_sel = 2'b00;	//clear convolution counter;

                address_input_mux_sel = 2'b10;      //Requesting to SRAM reference address +1
                address_weight_mux_sel = 2'b10;     //Requesting to SRAM reference address +1

                size_count_mux_sel = 2'b01;         //reading and setting up new size_count 
                ref_mux_sel  = 2'b10;               //increase reference address with + older size_count

				finish_sum_mult_sel = 2'b10;        //not ready for writting to SRAM, but storing previous ref address
				busy = 1'b1;

				if(read_input_data[7:0]== 8'b11111111)	//if everything completed
					next_state 	= s8;
				else
					begin
						next_state = s3;
					end
			end
			s8 : begin // ending state
				data_input_enable = 2'b10;          //Data from SRAM=
                weight_input_enable = 2'b10;        //Data from SRAM=

			    accum_n_enable  = 2'b10;            //=
				counter_mux_sel = 2'b10;            //=
				counter_convolution_sel = 2'b10;	//=

				address_input_mux_sel = 2'b11;      //=
                address_weight_mux_sel = 2'b11;     //=

				size_count_mux_sel = 2'b10;         //=
                ref_mux_sel  = 2'b11;               //=
				finish_sum_mult_sel = 2'b10;        //not ready for writting to SRAM, but storing previous ref address
				
				busy = 1'b0;
				next_state 	= s0;
			end
			default : begin
                data_input_enable = 2'b0;           //clearing current_data reg
                weight_input_enable = 2'b0;         //clearing current_weight reg
                accum_n_enable  = 2'b0;             //clearing accumulator reg
                counter_mux_sel = 2'b0;             //clearing mult_counter_up register
				counter_convolution_sel = 2'b00;	//clear convolution counter;

                address_input_mux_sel = 2'b0;       //clearing addres_input_reader,     reading address 0 on next clock
                address_weight_mux_sel = 2'b0;      //clearing address_counter_reader,  reading address 0 on next clock
                size_count_mux_sel = 2'b0;          //clearing size_count, number of inputs
                ref_mux_sel  = 2'b0;                //clearing ref_address
                finish_sum_mult_sel = 2'b00;         //not ready for writting to SRAM
                busy = 1'b1;
				next_state 	= s0;
			end
		endcase 
	end

	//Data Path
	
	//Input and weight word registers// 
	always @(posedge clk) 
    begin
			if (data_input_enable == 2'b0) 
				current_data <= 16'b0;              //clear
			else if (data_input_enable == 2'b01)
				current_data <= read_input_data;    //read from SRAM
			else if (data_input_enable == 2'b10)
				current_data <= current_data;       //=
	end

    always @(posedge clk) 
    begin
			if (weight_input_enable == 2'b0) 
				current_weight <= 16'b0;            //clear   
			else if (weight_input_enable == 2'b01)
				current_weight <= read_weight_data; //read from SRAM
    		else if (weight_input_enable == 2'b10)
				current_weight <= current_weight;   //=
	end

	//Accumulator register//

	always @(posedge clk) 
	begin
			if (accum_n_enable == 2'b0)
				accumulator <= 16'b0;							//clear
			else if (accum_n_enable == 2'b01)
				accumulator <= accumulator + input_mul_weight;	//adding multiplication to accumulator
			else if(accum_n_enable == 2'b10)
				accumulator <= accumulator;						//=
	end

	//Mult counter (counter up)//

	always @(posedge clk) 
	begin
			if (counter_mux_sel == 2'b0)
				mult_counter_up <= 16'b0;					//clear
			else if (counter_mux_sel == 2'b01)
				mult_counter_up <= mult_counter_up + 8'b01;	//up
			else if (counter_mux_sel == 2'b10)
				mult_counter_up <= mult_counter_up;			//=
    end	

	//Convolution counter (counter up)//

	always @(posedge clk) 
	begin
			if (counter_convolution_sel == 2'b0)
				convolution_counter_up <= 8'b0;								//clear
			else if (counter_convolution_sel == 2'b01)
				convolution_counter_up <= convolution_counter_up + 8'b01;	//up
			else if (counter_convolution_sel == 2'b10)
				convolution_counter_up <= convolution_counter_up;			//=
    end	

	//Read number of inputs//

	always @(posedge clk) 
	begin
			if (size_count_mux_sel == 2'b0)			//clear size_count
				size_count <= 8'b0;
			else if (size_count_mux_sel == 2'b01)	//read  data to size_cout	
				size_count <= read_input_data[7:0];
			else if (size_count_mux_sel == 2'b10)	//keep data to size_count
				size_count <= size_count;
	end

    //Set reference address

	always @(posedge clk) 
	begin
			if (ref_mux_sel == 2'b00)	        		//clear reference_address
				reference_address <= 10'b0;
			else if (ref_mux_sel == 2'b01)	            //inccrease reference_address	
				reference_address <= reference_address + 1'b1;
			else if (ref_mux_sel == 2'b10)	            //set new reference_address for  next reading, this includes +1 from size_input, size>>1 for past size /2
				reference_address <= reference_address + (size_count>>1) + 1'b1;
			else if (ref_mux_sel == 2'b11)	            // =
				reference_address <= reference_address;
	end

	//Read input SRAM register//

	always @(posedge clk) 
	begin
			if (address_input_mux_sel == 2'b00)
                read_input_address <= 11'b0;                          //clear
            else if (address_input_mux_sel == 2'b01)
				read_input_address <= reference_address;              //set to ref address
			else if (address_input_mux_sel == 2'b10)
				read_input_address <= read_input_address + 1'b1;    //counter + 1
			else if (address_input_mux_sel == 2'b11)
				read_input_address <= read_input_address;           //=
	end


	//Read weight SRAM register//

	always @(posedge clk) 
	begin
			if (address_weight_mux_sel == 2'b00)
				read_weight_address <= 11'b0;                        //clear
			else if (address_weight_mux_sel == 2'b01)
				read_weight_address <= reference_address;            //set to ref address
            else if (address_weight_mux_sel == 2'b10)
				read_weight_address <= read_weight_address + 1'b1; //counter + 1 
			else if (address_weight_mux_sel == 2'b11)
				read_weight_address <= read_weight_address;         //=
	end

	//Write enable Mux to output//

    always@(posedge clk)
    begin
        if (finish_sum_mult_sel == 2'b0 )begin			//clearing
            write_enable = 1'b0;
            write_address = 12'b111111111111;   
            write_data = 16'b0;
		end
        else if (finish_sum_mult_sel == 2'b01 )begin	//write enable and change of address for next writting 
            	write_enable = 1'b1;
            	write_address = write_address + 1'b1;
           		write_data = accumulator;
		end
		else if(finish_sum_mult_sel == 2'b10 )			//=
		begin
			write_enable = 1'b0;
			write_address = write_address;
			write_data = write_data; 
		end
    end
endmodule	//SK
