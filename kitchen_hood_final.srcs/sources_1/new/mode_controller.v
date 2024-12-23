`timescale 1ns / 1ps

module mode_controller (
    input wire clk,                                // Clock input
    input wire rst_n,                             // Active low reset input
    input wire power_state,                        // Power state signal
    input wire menu_btn,                           // Menu button input
    input wire level1_btn,                         // Level 1 button input
    input wire level2_btn,                         // Level 2 button input
    input wire level3_btn,                         // Level 3 button input
    input wire self_clean_btn,                     // Self-cleaning button input
    input wire manual_reset_btn,                   // Manual reset button input
    input wire query_upper_accumulated_time_switch, // Query upper accumulated time switch
    input wire upper_hour_increase_switch,         // Hour increase switch
    input wire power_left_right_control,           // Power left/right control
    input wire query_accumulated_time_switch,      // New input for querying accumulated time
    output reg [31:0] accumulated_seconds,         // Output for accumulated seconds
    output reg display_accumulated_time,           // Output for displaying accumulated time
    output reg [4:0] query_leds,                   // Output for query LEDs
    output reg [2:0] current_mode,                 // Output for current mode
    output reg [1:0] extraction_level,             // Output for extraction level
    output reg [7:0] countdown_seconds,             // Output for countdown seconds
    output reg cleaning_active,                     // Output for cleaning active status
    output reg reminder_led,                        // Output for reminder LED
    output reg display_countdown                    // Output for displaying countdown
);
    localparam POWER_OFF      = 3'b000;           // Power off mode
    localparam STANDBY        = 3'b001;           // Standby mode
    localparam EXTRACTION     = 3'b010;           // Extraction mode
    localparam SELF_CLEANING  = 3'b011;           // Self-cleaning mode
    localparam LEVEL_OFF = 2'b00;                  // Level off
    localparam LEVEL_1   = 2'b01;                  // Level 1
    localparam LEVEL_2   = 2'b10;                  // Level 2
    localparam LEVEL_3   = 2'b11;                  // Level 3
    localparam ONE_SECOND = 100000000;             // One second in clock cycles
    parameter DEBOUNCE_LIMIT = 50_000_000;        // 0.5 second debounce limit (100MHz clock)

    reg [31:0] counter;                            // Counter for timing
    reg prev_menu_btn;                             // Previous state of the menu button
    reg in_hurricane_exit;                         // Flag for hurricane exit mode
    reg [7:0] hurricane_exit_counter;              // Counter for hurricane exit duration
    reg [7:0] level3_counter;                      // Counter for level 3 extraction
    reg [31:0] accumulated_seconds;                // Accumulated seconds counter
    reg hurricane_used_internal;                   // Flag for internal hurricane usage
    reg [25:0] hour_increase_counter;              // Counter for hour increase
    reg hour_increase_stable;                      // Status for hour increase stability
    reg prev_hour_increase_stable;                 // Previous stable state of hour increase
    reg [5:0] reminder_hours;                       // Hours for reminder setting

    reg [2:0] next_mode;                           // Next mode state
    reg [1:0] next_extraction_level;               // Next extraction level state
    reg [7:0] next_countdown_seconds;               // Next countdown seconds state
    reg next_cleaning_active;                       // Next cleaning active status
    reg next_hurricane_used_internal;              // Next internal hurricane usage status
    reg [31:0] next_counter;                        // Next counter value
    reg next_prev_menu_btn;                         // Next previous menu button state
    reg next_in_hurricane_exit;                     // Next state for hurricane exit
    reg [7:0] next_hurricane_exit_counter;         // Next hurricane exit counter
    reg [7:0] next_level3_counter;                 // Next level 3 counter
    reg [31:0] next_accumulated_seconds;           // Next accumulated seconds value
    reg next_reminder_led;                          // Next reminder LED status
    reg next_display_countdown;                     // Next countdown display status

    // 0.5s debouncing block
    always @(posedge clk) begin
        if (!rst_n || !power_state) begin
            hour_increase_counter <= 0;             // Reset counter and stable flag on reset or power off
            hour_increase_stable <= 0;
        end
        else begin
            if (upper_hour_increase_switch && current_mode == STANDBY) begin  
                if (hour_increase_counter >= DEBOUNCE_LIMIT) begin
                    hour_increase_stable <= 1;      // Set stable if counter exceeds limit
                end
                else begin
                    hour_increase_counter <= hour_increase_counter + 1; // Increment counter
                end
            end
            else begin
                hour_increase_counter <= 0;        // Reset counter if switch is not pressed
                hour_increase_stable <= 0;
            end
        end
    end

    // Hour increase handling block
    always @(posedge clk) begin
        if (!rst_n || !power_state) begin
            prev_hour_increase_stable <= 0;       // Reset previous stable flag
            reminder_hours <= 6'd10;               // Default reminder hours to 10
        end
        else begin
            prev_hour_increase_stable <= hour_increase_stable; // Update previous stable flag
            if (current_mode == STANDBY && hour_increase_stable && !prev_hour_increase_stable) begin
                if (reminder_hours >= 32) begin
                    reminder_hours <= 6'd1;         // Wrap around reminder hours
                end
                else begin
                    reminder_hours <= reminder_hours + 1; // Increment reminder hours
                end
            end
        end
    end

    always @(*) begin
        next_mode = current_mode;                   // Default next mode
        next_extraction_level = extraction_level;   // Default next extraction level
        next_countdown_seconds = countdown_seconds;  // Default next countdown seconds
        next_cleaning_active = cleaning_active;      // Default next cleaning active status
        next_hurricane_used_internal = hurricane_used_internal; // Default next hurricane usage status
        next_counter = counter;                      // Default next counter value
        next_prev_menu_btn = menu_btn;              // Default next previous menu button state
        next_in_hurricane_exit = in_hurricane_exit; // Default next hurricane exit state
        next_hurricane_exit_counter = hurricane_exit_counter; // Default next hurricane exit counter
        next_level3_counter = level3_counter;       // Default next level 3 counter
        next_accumulated_seconds = accumulated_seconds; // Default next accumulated seconds
        next_reminder_led = reminder_led;          // Default next reminder LED status
        next_display_countdown = display_countdown;  // Default next countdown display status
        query_leds = 5'b00000;                      // Default query LEDs off
        display_accumulated_time = 0;               // Default display accumulated time off

        if (current_mode == STANDBY && query_accumulated_time_switch) begin
            display_accumulated_time = 1;           // Set display when querying accumulated time
        end

        if (current_mode == STANDBY && query_upper_accumulated_time_switch) begin
            query_leds = reminder_hours[4:0];       // Set query LEDs based on reminder hours
        end

        if (manual_reset_btn && current_mode == STANDBY) begin
            next_accumulated_seconds = 0;           // Reset accumulated seconds on manual reset
            next_reminder_led = 0;                   // Reset reminder LED
        end

        if (!power_state) begin
            next_mode = POWER_OFF;                   // Transition to power off mode
            next_extraction_level = LEVEL_OFF;      // Set extraction level to off
            next_countdown_seconds = 0;               // Reset countdown seconds
            next_cleaning_active = 0;                 // Turn off cleaning
            next_accumulated_seconds = 0;             // Reset accumulated seconds
            next_reminder_led = 0;                    // Reset reminder LED
            next_hurricane_used_internal = 0;         // Reset hurricane usage
            next_display_countdown = 0;                // Turn off countdown display
        end
        else begin
            case (current_mode)
                POWER_OFF: begin
                    if (power_state) begin
                        next_mode = STANDBY;           // Transition to standby mode
                        next_extraction_level = LEVEL_OFF; // Set extraction level to off
                        next_countdown_seconds = 0;    // Reset countdown
                        next_cleaning_active = 0;      // Turn off cleaning
                    end
                end

                STANDBY: begin
                    if (menu_btn && !power_left_right_control) begin
                        if (level1_btn) begin
                            next_mode = EXTRACTION;     // Set mode to extraction level 1
                            next_extraction_level = LEVEL_1;
                            next_in_hurricane_exit = 0;
                        end
                        else if (level2_btn) begin
                            next_mode = EXTRACTION;     // Set mode to extraction level 2
                            next_extraction_level = LEVEL_2;
                            next_in_hurricane_exit = 0;
                        end
                        else if (level3_btn && !hurricane_used_internal) begin
                            next_mode = EXTRACTION;     // Set mode to extraction level 3
                            next_extraction_level = LEVEL_3;
                            next_level3_counter = 60;   // Set level 3 counter
                            next_countdown_seconds = 60; // Set countdown for level 3
                            next_hurricane_used_internal = 1; // Mark hurricane used
                            next_in_hurricane_exit = 0; // Not in hurricane exit
                            next_display_countdown = 1;  // Show countdown
                        end
                        else if (self_clean_btn) begin
                            next_mode = SELF_CLEANING;   // Transition to self-cleaning mode
                            next_countdown_seconds = 180; // Set countdown for self-cleaning
                            next_display_countdown = 1;   // Show countdown
                        end
                    end
                end

                EXTRACTION: begin
                    if (extraction_level == LEVEL_3 && !in_hurricane_exit) begin
                        next_display_countdown = 1;   // Show countdown if in level 3 extraction
                    end
                    if (in_hurricane_exit) begin
                        next_display_countdown = 1;   // Show countdown if in hurricane exit
                    end
                    if (counter >= ONE_SECOND) begin
                        next_counter = 0;              // Reset counter every second
                        next_accumulated_seconds = accumulated_seconds + 1; // Increment accumulated seconds
                        if (accumulated_seconds >= (reminder_hours - 1)) begin // Check for reminder
                            next_reminder_led = 1;      // Activate reminder LED
                        end
                    end
                    else begin
                        next_counter = counter + 1;    // Increment counter
                    end

                    if (extraction_level == LEVEL_3 && !in_hurricane_exit) begin
                        if (counter >= ONE_SECOND) begin
                            if (level3_counter > 0) begin
                                next_level3_counter = level3_counter - 1; // Decrement level 3 counter
                                next_countdown_seconds = level3_counter - 1; // Update countdown seconds
                            end
                            else begin
                                next_extraction_level = LEVEL_2; // Transition to level 2
                                next_display_countdown = 0;       // Turn off countdown display
                            end
                        end
                    end

                    if (in_hurricane_exit) begin
                        if (counter >= ONE_SECOND) begin
                            if (hurricane_exit_counter > 0) begin
                                next_hurricane_exit_counter = hurricane_exit_counter - 1; // Decrement hurricane exit counter
                                next_countdown_seconds = hurricane_exit_counter - 1; // Update countdown seconds
                            end
                            else begin
                                next_mode = STANDBY;          // Transition to standby mode
                                next_extraction_level = LEVEL_OFF; // Set extraction level to off
                                next_in_hurricane_exit = 0;  // Reset hurricane exit flag
                                next_countdown_seconds = 0;   // Reset countdown seconds
                                next_display_countdown = 0;   // Turn off countdown display
                            end
                        end
                    end

                    if (menu_btn && !power_left_right_control) begin
                        if (level1_btn && extraction_level != LEVEL_3)
                            next_extraction_level = LEVEL_1; // Switch to level 1
                        else if (level2_btn && extraction_level != LEVEL_3)
                            next_extraction_level = LEVEL_2; // Switch to level 2
                    end
                    else if (!menu_btn && prev_menu_btn) begin
                        if (extraction_level == LEVEL_3 && level3_counter > 0) begin
                            next_in_hurricane_exit = 1; // Enter hurricane exit mode
                            next_hurricane_exit_counter = 60; // Set exit counter
                            next_countdown_seconds = 60; // Set countdown for exit
                            next_display_countdown = 1;  // Show countdown
                        end
                        else if (extraction_level != LEVEL_3) begin
                            next_mode = STANDBY;         // Transition to standby mode
                            next_extraction_level = LEVEL_OFF; // Set extraction level to off
                            next_countdown_seconds = 0;  // Reset countdown seconds
                            next_display_countdown = 0;  // Turn off countdown display
                        end
                    end
                end

                SELF_CLEANING: begin
                    if (counter >= ONE_SECOND) begin
                        next_counter = 0;                // Reset counter every second
                        if (countdown_seconds > 0) begin
                            next_countdown_seconds = countdown_seconds - 1; // Decrement countdown
                        end
                        else begin
                            next_mode = STANDBY;         // Transition to standby mode
                            next_cleaning_active = 1;    // Mark cleaning as active
                            next_accumulated_seconds = 0; // Reset accumulated seconds
                            next_reminder_led = 0;       // Reset reminder LED
                            next_display_countdown = 0;   // Turn off countdown display
                        end
                    end
                    else begin
                        next_counter = counter + 1;      // Increment counter
                    end
                end

                default: next_mode = STANDBY;             // Default to standby mode
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_mode <= STANDBY;                  // Initialize to standby mode
            extraction_level <= LEVEL_OFF;            // Initialize extraction level to off
            countdown_seconds <= 0;                    // Initialize countdown seconds
            cleaning_active <= 0;                       // Initialize cleaning active status
            hurricane_used_internal <= 0;               // Initialize hurricane usage status
            counter <= 0;                              // Initialize counter
            prev_menu_btn <= 0;                        // Initialize previous menu button state
            in_hurricane_exit <= 0;                    // Initialize hurricane exit flag
            hurricane_exit_counter <= 0;               // Initialize hurricane exit counter
            level3_counter <= 0;                       // Initialize level 3 counter
            accumulated_seconds <= 0;                  // Initialize accumulated seconds
            reminder_led <= 0;                         // Initialize reminder LED
            display_countdown <= 0;                    // Initialize countdown display
        end
        else begin
            current_mode <= next_mode;                 // Update current mode
            extraction_level <= next_extraction_level; // Update extraction level
            countdown_seconds <= next_countdown_seconds; // Update countdown seconds
            cleaning_active <= next_cleaning_active;    // Update cleaning active status
            hurricane_used_internal <= next_hurricane_used_internal; // Update hurricane usage
            counter <= next_counter;                    // Update counter value
            prev_menu_btn <= next_prev_menu_btn;       // Update previous menu button state
            in_hurricane_exit <= next_in_hurricane_exit; // Update hurricane exit state
            hurricane_exit_counter <= next_hurricane_exit_counter; // Update hurricane exit counter
            level3_counter <= next_level3_counter;     // Update level 3 counter
            accumulated_seconds <= next_accumulated_seconds; // Update accumulated seconds
            reminder_led <= next_reminder_led;         // Update reminder LED status
            display_countdown <= next_display_countdown; // Update countdown display status
        end
    end
endmodule
