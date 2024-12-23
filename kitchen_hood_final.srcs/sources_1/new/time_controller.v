`timescale 1ns / 1ps

module time_controller (
    input wire clk,                             // Clock input
    input wire rst_n,                           // Active-low reset
    input wire power_state,                     // Indicates if the device is powered on
    input wire hour_increment,                  // Signal to increment the hour
    input wire minute_increment,                // Signal to increment the minute
    input wire [2:0] current_mode,             // Current operational mode
    output reg [5:0] hours,                     // Output for hours (0-23)
    output reg [5:0] minutes,                   // Output for minutes (0-59)
    output reg [5:0] seconds                    // Output for seconds (0-59)
);
    parameter DEBOUNCE_LIMIT = 50_000_000;     // Debounce limit for button presses
    parameter STANDBY = 3'b001;                 // Standby mode identifier
    
    reg [25:0] hour_debounce_counter;           // Counter for hour button debouncing
    reg [25:0] minute_debounce_counter;         // Counter for minute button debouncing
    reg hour_stable;                            // Indicates stable hour increment
    reg minute_stable;                          // Indicates stable minute increment
    reg prev_hour_stable;                       // Previous state of hour stability
    reg prev_minute_stable;                     // Previous state of minute stability
    reg [26:0] clk_counter;                     // Counter for second counting

    // Hour debouncing logic
    always @(posedge clk) begin
        if (!rst_n || !power_state) begin        // Reset or power off condition
            hour_debounce_counter <= 0;         // Reset debounce counter
            hour_stable <= 0;                   // Reset hour stability
        end
        else begin
            if (hour_increment && current_mode == STANDBY) begin  
                if (hour_debounce_counter >= DEBOUNCE_LIMIT) begin
                    hour_stable <= 1;            // Set hour stable after debounce
                end
                else begin
                    hour_debounce_counter <= hour_debounce_counter + 1; // Increment counter
                end
            end
            else begin
                hour_debounce_counter <= 0;     // Reset counter if button not pressed
                hour_stable <= 0;               // Reset hour stability
            end
        end
    end

    // Minute debouncing logic
    always @(posedge clk) begin
        if (!rst_n || !power_state) begin        // Reset or power off condition
            minute_debounce_counter <= 0;       // Reset debounce counter
            minute_stable <= 0;                  // Reset minute stability
        end
        else begin
            if (minute_increment && current_mode == STANDBY) begin  
                if (minute_debounce_counter >= DEBOUNCE_LIMIT) begin
                    minute_stable <= 1;          // Set minute stable after debounce
                end
                else begin
                    minute_debounce_counter <= minute_debounce_counter + 1; // Increment counter
                end
            end
            else begin
                minute_debounce_counter <= 0;    // Reset counter if button not pressed
                minute_stable <= 0;              // Reset minute stability
            end
        end
    end

    // Main time counting and adjustment logic
    always @(posedge clk) begin
        if (!rst_n) begin                        // System reset
            hours <= 6'd0;                      // Initialize hours to 0
            minutes <= 6'd0;                    // Initialize minutes to 0
            seconds <= 6'd0;                    // Initialize seconds to 0
            clk_counter <= 27'd0;                // Initialize clock counter
            prev_hour_stable <= 0;              // Reset previous hour stability
            prev_minute_stable <= 0;            // Reset previous minute stability
        end
        else if (!power_state) begin             // Power off state
            hours <= 6'd0;                      // Reset hours to 0
            minutes <= 6'd0;                    // Reset minutes to 0
            seconds <= 6'd0;                    // Reset seconds to 0
            clk_counter <= 27'd0;                // Reset clock counter
            prev_hour_stable <= 0;              // Reset previous hour stability
            prev_minute_stable <= 0;            // Reset previous minute stability
        end
        else begin                                // Normal operation when powered on
            prev_hour_stable <= hour_stable;    // Update previous hour stability
            prev_minute_stable <= minute_stable; // Update previous minute stability

            // Handle hour increment
            if (current_mode == STANDBY && hour_stable && !prev_hour_stable) begin
                hours <= (hours == 23) ? 0 : hours + 1; // Increment hours with wraparound
            end

            // Handle minute increment
            if (current_mode == STANDBY && minute_stable && !prev_minute_stable) begin
                minutes <= (minutes == 59) ? 0 : minutes + 1; // Increment minutes with wraparound
            end

            // Normal time counting logic
            if (clk_counter >= 100000000 - 1) begin 
                clk_counter <= 27'd0;               // Reset clock counter
                if (seconds >= 59) begin
                    seconds <= 0;                   // Reset seconds
                    if (minutes >= 59) begin
                        minutes <= 0;               // Reset minutes
                        if (hours >= 23) begin
                            hours <= 0;              // Reset hours
                        end
                        else begin
                            hours <= hours + 1;      // Increment hours
                        end
                    end
                    else begin
                        minutes <= minutes + 1;      // Increment minutes
                    end
                end
                else begin
                    seconds <= seconds + 1;          // Increment seconds
                end
            end
            else begin
                clk_counter <= clk_counter + 1;      // Increment clock counter
            end
        end
    end
endmodule
