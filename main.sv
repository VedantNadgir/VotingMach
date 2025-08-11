//Main purpose of this program is to write a hardware design for a voting machine
//The Hardware design has been catered to Altera DE2-115
//Single vote per person
//Once candidate vote has been registered the slider for that candidate must be reversed by the User Manually.
//Top level module

module VoteMach (
  input logic CLOCK_50,
  input logic [3:0] KEY, // KEY[3]: Reset, KEY[0]: Confirm, KEY[1]: Show Tally
  input logic [17:0] SW, // SW[0]: Mode, SW[16:1]: Candidates 
  output logic [17:0] LEDG, //LED[0]--> Shows Mode, LED[16:1] Candidate selection, LED[17]--> Session Status
  output logic [7:0] HEX0, HEX1, HEX2, HEX3 //Display output only during ERRor or Tally result (MAX count--> 9999)
);
  
  logic slow_clk;
  ClockDivider #(25_000_000) clkdiv (.clk(CLOCK_50), .slow_clk(slow_clk));
  //FSM 
  typedef enum logic [2:0]{
    RESET, IDLE, SESSION_ACTIVE, VOTE_CONFIRMED, TIMEOUT, TALLY
  } state_t;
  
  state_t curr_state, next_state;
  //Internal Registers
  logic [7:0] vote_count [15:0]; // Vote counters for 16 candidates
  logic [3:0] selected_candidate; 
  logic candidate_valid;
  logic [4:0] timeout_counter;
  logic session_on;
  logic blink;
  logic [2:0] vote_blink_counter; // 3-bit counter for up to 8 slow_clk cycles

  // Previous key states for edge detection
    logic prev_key0, prev_key1, prev_key3;
    logic key0_pressed, key1_pressed, key3_pressed;
  
  // Generate blink signal for visual feedback
    always_ff @(posedge slow_clk) begin
        blink <= ~blink;
    end
  
  // Hex digits for display
    logic [3:0] digit0, digit1, digit2, digit3;
    HexDisplay hd0 (.hex_digit(digit0), .seg(HEX0));
    HexDisplay hd1 (.hex_digit(digit1), .seg(HEX1));
    HexDisplay hd2 (.hex_digit(digit2), .seg(HEX2));
    HexDisplay hd3 (.hex_digit(digit3), .seg(HEX3));

  // Instantiate candidate selector
   CandidateSelector selector (
     .sw(SW[16:1]),
     .selected(selected_candidate),
     .valid(candidate_valid)
   );
  assign LEDG[16] = SW[0];
  assign LEDG[17] = session_on;
   
  // LEDG[0-15] feedback
    always_comb begin
      for (int i = 0; i < 16; i++) begin
        if (SW[i+1])
                LEDG[i] = 1; // candidate selected
            else if (current_state == VOTE_CONFIRMED && selected_candidate == i)
                LEDG[i] = blink; // blink for vote confirmation
            else
                LEDG[i] = 0;
        end
    end
  
  // FSM Sequential Logic
    always_ff @(posedge CLOCK_50 or negedge KEY[3]) begin
        if (!KEY[3]) begin    //Push buttons are active Low
            curr_state <= RESET;
        end else begin
            curr_state <= next_state;
        end
    end
  
  // Edge detection for buttons
    always_comb begin
        key0_pressed = prev_key0 && ~KEY[0];
        key1_pressed = prev_key1 && ~KEY[1];
        key3_pressed = prev_key3 && ~KEY[3];
    end
  
  //FSM Combinational Logic
  always_comb begin
    next_state = curr_state;
    case(next_state)
      RESET: begin
        next_state = IDLE;
      end
      IDLE: begin
        if(SW[0] == 0)
          next_state = SESSION_ACTIVE;
        else if(SW[0]==1)
          next_state = TALLY;
      end
      SESSION_ACTIVE: begin
        if (key0_pressed && candidate_valid)//Check 
          next_state = VOTE_CONFIRMED;
        else if (timeout_counter == 30)
          next_state = TIMEOUT;
      end
      VOTE_CONFIRMED: begin
		if (vote_blink_counter >= 6) // 3 blinks → 6 transitions
        	next_state = IDLE;
    	else
        	next_state = VOTE_CONFIRMED;
      end
      TIMEOUT: begin
        next_state = IDLE;
      end
      TALLY: begin
        if (key3_pressed)//Check
          next_state = RESET;
      end
    endcase
  end
  //Output + Vote Register Logic
  always_ff @(posedge CLOCK_50) begin
    case(curr_state) begin
      		RESET: begin
                for (int i = 0; i < 16; i++) vote_count[i] <= 0;
                session_on <= 0;
                digit3 <= 4'hC; // r
                digit2 <= 4'h5; // S
                digit1 <= 4'hB; // t
                digit0 <= 4'hF; // blank or filler
              	vote_blink_counter <= 0;
              	timeout_counter <= 0;
            end
            IDLE: begin
                session_on <= 0;
                digit3 <= 4'hF;
                digit2 <= 4'hF;
                digit1 <= 4'hF;
                digit0 <= 4'hF;
              	vote_blink_counter <= 0;
              	timeout_counter <= 0;
            end
            SESSION_ACTIVE: begin
                session_on <= 1;
                if (timeout_counter < 30)
                    timeout_counter <= timeout_counter + 1;
            end
      
            VOTE_CONFIRMED: begin
                if (vote_blink_counter == 0)
                    vote_count[selected_candidate] <= vote_count[selected_candidate] + 1;

                session_on <= 0;
                digit3 <= 4'hD; // D
                digit2 <= 4'hA; // N
                digit1 <= 4'hE; // E
                digit0 <= 4'hF;

                if (slow_clk)
                    vote_blink_counter <= vote_blink_counter + 1;

                timeout_counter <= 0;
            end

            TIMEOUT: begin
                session_on <= 0;
                digit3 <= 4'hB; // t
                digit2 <= 4'h0; // O
                digit1 <= 4'hE; // E
                digit0 <= 4'hF; // blank
                timeout_counter <= 0;
            end
            TALLY: begin
              if (key1_pressed && candidate_valid) begin
                	digit3 <= vote_count[selected_candidate] / 1000 % 10;
                    digit2 <= vote_count[selected_candidate] / 100 % 10;
                    digit1 <= vote_count[selected_candidate] / 10 % 10;
                    digit0 <= vote_count[selected_candidate] % 10;
              end
            end
        endcase
        prev_key0 <= KEY[0];
    	prev_key3 <= KEY[3];
    	prev_key1 <= KEY[1];
    end
endmodule
// CandidateSelector module
module CandidateSelector(
    input  logic [16:1] sw,
    output logic [3:0]  selected,
    output logic valid
);
    logic [3:0] count = 0;
    logic [3:0] index = 0;
    always_comb begin
        count = 0;
        valid = 0;
        selected = 0;
        for (int i = 1; i <= 16; i++) begin
            if (sw[i]) begin
                count++;
                index = i - 1;
            end
        end
        if (count == 1) begin
            selected = index;
            valid = 1;
        end
    end
endmodule

// ClockDivider module
module ClockDivider #(parameter DIV = 25_000_000) (
    input  logic clk,
    output logic slow_clk
);
    logic [$clog2(DIV)-1:0] counter = 0;
    always_ff @(posedge clk) begin
        counter <= (counter == DIV - 1) ? 0 : counter + 1;
        slow_clk <= (counter < DIV / 2);
    end
endmodule
      
// HexDisplay module
module HexDisplay(
    input  logic [3:0] hex_digit,
    output logic [6:0] seg
);
    always_comb begin
        case (hex_digit)
            4'h0: seg = 7'b0000001;
            4'h1: seg = 7'b1001111;
            4'h2: seg = 7'b0010010;
            4'h3: seg = 7'b0000110 ;
            4'h4: seg = 7'b1001100 ;
            4'h5: seg = 7'b0100100 ;
            4'h6: seg = 7'b0100000 ;
            4'h7: seg = 7'b0001111 ;
            4'h8: seg = 7'b0000000 ;
            4'h9: seg = 7'b0000100 ;
            4'hA: seg = 7'b1101010;//N
            4'hB: seg = 7'b1110000;//t
            4'hC: seg = 7'b0110001;//r
            4'hD: seg = 7'b1000010;//D
            4'hE: seg = 7'b0110000;//E
            4'hF: seg = 7'b1111111; // Blank
            default: seg = 7'b1111111;
        endcase
    end
endmodule