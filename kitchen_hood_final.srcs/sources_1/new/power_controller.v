`timescale 1ns / 1ps

module power_controller (
    input wire clk,
    input wire rst_n,
    input wire power_btn_raw,
    input wire power_left_right_control,
    input wire level1_btn_raw,
    input wire level2_btn_raw,
    input wire increase_gesture_time,
    input wire query_gesture_time,
    output reg power_state,
    output reg [7:0] gesture_countdown,
    output reg display_gesture_countdown,
    output reg [2:0] query_gesture_time_value
);

    // States for gesture control
    localparam IDLE = 2'b00;                     // Idle state
    localparam WAIT_FOR_RIGHT = 2'b01;           // Waiting for right gesture
    localparam WAIT_FOR_LEFT = 2'b10;            // Waiting for left gesture
    
    reg [31:0] power_press_counter;               // Counter for power button press duration
    wire power_btn_debounced;                     // Debounced power button signal
    reg prev_power_btn;                           // Previous state of power button
    reg [26:0] countdown_counter;                 // Countdown timer for gestures
    reg [1:0] gesture_state;                      // Current state of gesture control
    reg long_press_detected;                       // Flag for long press detection
    reg waiting_for_release;                       // Flag to wait for button release
    reg left_btn_prev;                            // Previous state of level 1 button
    reg right_btn_prev;                           // Previous state of level 2 button
    wire level1_btn_debounced;                    // Debounced level 1 button signal
    wire level2_btn_debounced;                    // Debounced level 2 button signal
    
    // Gesture time control
    reg [2:0] current_gesture_time;               // Current gesture duration
    reg [25:0] time_increase_counter;             // Counter for gesture time increase
    reg time_increase_stable;                     // Stable state for gesture time increase
    reg prev_time_increase_stable;                // Previous stable state for gesture time increase
    reg in_standby;                               // Flag indicating if in standby mode
    
    // Constants
    localparam LONG_PRESS_TIME = 32'd300_000_000; // Long press duration (3 seconds)
    localparam ONE_SECOND = 32'd100_000_000;      // One second in clock cycles
    parameter GESTURE_TIME_DEBOUNCE_LIMIT = 50_000_000;  // 0.5 second debounce limit

    // Button debouncers for power and level buttons
    button_debouncer_controller power_btn_debouncer (
        .clk(clk),
        .btn_in(power_btn_raw),
        .btn_out(power_btn_debounced)
    );

    button_debouncer_controller left_btn_debouncer (
        .clk(clk),
        .btn_in(level1_btn_raw),
        .btn_out(level1_btn_debounced)
    );

    button_debouncer_controller right_btn_debouncer (
        .clk(clk),
        .btn_in(level2_btn_raw),
        .btn_out(level2_btn_debounced)
    );

    // Determine if we're in standby mode
    always @(*) begin
        in_standby = (power_state && gesture_state == IDLE && !display_gesture_countdown);
    end

    // 0.5s debouncing block for gesture time increase
    always @(posedge clk) begin
        if (!rst_n) begin
            time_increase_counter <= 0;            // Reset time increase counter
            time_increase_stable <= 0;              // Reset stable flag
        end
        else begin
            if (increase_gesture_time && in_standby) begin  // Only in standby mode
                if (time_increase_counter >= GESTURE_TIME_DEBOUNCE_LIMIT) begin
                    time_increase_stable <= 1;    // Set stable if counter exceeds limit
                end
                else begin
                    time_increase_counter <= time_increase_counter + 1; // Increment counter
                end
            end
            else begin
                time_increase_counter <= 0;      // Reset counter if not increasing
                time_increase_stable <= 0;       // Reset stable flag
            end
        end
    end

    // Gesture time handling block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_gesture_time <= 3'd5;      // Default gesture time to 5 seconds
            prev_time_increase_stable <= 0;    // Reset previous stable flag
            query_gesture_time_value <= 3'd0;   // Reset query value
        end
        else begin
            prev_time_increase_stable <= time_increase_stable;
            
            // Handle gesture time increase - only in standby mode
            if (in_standby && time_increase_stable && !prev_time_increase_stable) begin
                if (current_gesture_time >= 3'd7) begin
                    current_gesture_time <= 3'd0; // Wrap around gesture time
                end
                else begin
                    current_gesture_time <= current_gesture_time + 1; // Increment gesture time
                end
            end
            
            // Handle query display - only in standby mode
            if (query_gesture_time && in_standby) begin
                query_gesture_time_value <= current_gesture_time; // Set query value
            end
            else begin
                query_gesture_time_value <= 3'd0; // Reset query value
            end
        end
    end
    
    // Main power control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_press_counter <= 0;            // Reset power press counter
            prev_power_btn <= 0;                  // Reset previous power button state
            gesture_state <= IDLE;                 // Set gesture state to idle
            gesture_countdown <= 0;                // Reset gesture countdown
            display_gesture_countdown <= 0;       // Turn off countdown display
            countdown_counter <= 0;                // Reset countdown timer
            long_press_detected <= 0;              // Reset long press flag
            waiting_for_release <= 0;              // Reset waiting for release flag
            left_btn_prev <= 0;                    // Reset left button previous state
            right_btn_prev <= 0;                   // Reset right button previous state
        end
        else begin
            prev_power_btn <= power_btn_debounced; // Update previous power button state
            left_btn_prev <= level1_btn_debounced;  // Update previous left button state
            right_btn_prev <= level2_btn_debounced; // Update previous right button state
            
            // Power button handling
            if (power_btn_debounced) begin
                if (power_state && !waiting_for_release) begin
                    power_press_counter <= power_press_counter + 1; // Increment press counter
                    if (power_press_counter >= LONG_PRESS_TIME) begin
                        power_state <= 0;         // Turn off power on long press
                        waiting_for_release <= 1; // Set waiting for release flag
                        long_press_detected <= 1;  // Set long press detected flag
                    end
                end
            end
            else if (!power_btn_debounced) begin
                if (prev_power_btn) begin
                    if (!waiting_for_release && !long_press_detected && 
                        power_press_counter < LONG_PRESS_TIME) begin
                        if (!power_state) begin
                            power_state <= 1;      // Turn on power if it was off
                        end
                    end
                end
                power_press_counter <= 0;            // Reset power press counter
                if (!prev_power_btn) begin
                    long_press_detected <= 0;        // Reset long press detected flag
                    waiting_for_release <= 0;        // Reset waiting for release flag
                end
            end
            
            // Gesture control
            if (power_left_right_control) begin
                // Update countdown timer
                if (countdown_counter >= ONE_SECOND) begin
                    countdown_counter <= 0;          // Reset countdown counter
                    if (gesture_countdown > 0) begin
                        gesture_countdown <= gesture_countdown - 1; // Decrement gesture countdown
                    end
                end
                else begin
                    countdown_counter <= countdown_counter + 1; // Increment countdown counter
                end

                case (gesture_state)
                    IDLE: begin
                        if (!power_state && level1_btn_debounced && !left_btn_prev) begin
                            gesture_state <= WAIT_FOR_RIGHT; // Transition to wait for right gesture
                            gesture_countdown <= current_gesture_time; // Set countdown
                            display_gesture_countdown <= 1; // Show countdown
                            countdown_counter <= 0; // Reset countdown
                        end
                        else if (power_state && level2_btn_debounced && !right_btn_prev) begin
                            gesture_state <= WAIT_FOR_LEFT; // Transition to wait for left gesture
                            gesture_countdown <= current_gesture_time; // Set countdown
                            display_gesture_countdown <= 1; // Show countdown
                            countdown_counter <= 0; // Reset countdown
                        end
                    end

                    WAIT_FOR_RIGHT: begin
                        if (gesture_countdown == 0) begin
                            gesture_state <= IDLE;     // Back to idle if countdown is zero
                            display_gesture_countdown <= 0; // Turn off countdown display
                        end
                        else if (level2_btn_debounced && !right_btn_prev) begin
                            power_state <= 1;          // Turn on power for right gesture
                            gesture_state <= IDLE;     // Back to idle
                            display_gesture_countdown <= 0; // Turn off countdown display
                        end
                    end

                    WAIT_FOR_LEFT: begin
                        if (gesture_countdown == 0) begin
                            gesture_state <= IDLE;     // Back to idle if countdown is zero
                            display_gesture_countdown <= 0; // Turn off countdown display
                        end
                        else if (level1_btn_debounced && !left_btn_prev) begin
                            power_state <= 0;          // Turn off power for left gesture
                            gesture_state <= IDLE;     // Back to idle
                            display_gesture_countdown <= 0; // Turn off countdown display
                        end
                    end

                    default: gesture_state <= IDLE;         // Default to idle state
                endcase
            end
            else begin
                gesture_state <= IDLE;                  // Reset gesture state to idle
                display_gesture_countdown <= 0;        // Turn off countdown display
            end
        end
    end

endmodule
