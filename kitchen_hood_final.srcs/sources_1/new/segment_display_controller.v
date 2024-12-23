`timescale 1ns / 1ps

module segment_display_controller (
   input wire clk,
   input wire rst_n,
   input wire [5:0] hours,                       // Input for hours (0-59)
   input wire [5:0] minutes,                     // Input for minutes (0-59)
   input wire [5:0] seconds,                     // Input for seconds (0-59)
   input wire display_countdown,                  // Control signal to display countdown
   input wire [7:0] countdown_seconds,           // Input for countdown seconds
   input wire [7:0] gesture_countdown,           // Input for gesture countdown
   input wire display_gesture_countdown,         // Control signal to display gesture countdown
   input wire [31:0] accumulated_seconds,         // New input for accumulated seconds
   input wire display_accumulated_time,           // Control signal to display accumulated time
   input wire power_state,                        // Indicates power state (on/off)
   output reg [7:0] seg_en,                       // Segment enable signals
   output reg [7:0] seg_out0,                     // Segment output for the first display
   output reg [7:0] seg_out1                      // Segment output for the second display
);

   reg [31:0] refresh_counter;                   // Counter for refresh timing
   reg [2:0] scan_cnt;                           // Counter for scanning segments
   
   // Decode hours, minutes, seconds for display
   wire [3:0] hour_tens = hours / 10;          // Tens of hours
   wire [3:0] hour_ones = hours % 10;          // Ones of hours
   wire [3:0] min_tens = minutes / 10;         // Tens of minutes
   wire [3:0] min_ones = minutes % 10;         // Ones of minutes
   wire [3:0] sec_tens = seconds / 10;         // Tens of seconds
   wire [3:0] sec_ones = seconds % 10;         // Ones of seconds

   // Decode countdown time for display
   wire [3:0] countdown_min_tens = countdown_seconds / 60 / 10; // Tens of countdown minutes
   wire [3:0] countdown_min_ones = (countdown_seconds / 60) % 10; // Ones of countdown minutes
   wire [3:0] countdown_sec_tens = (countdown_seconds % 60) / 10; // Tens of countdown seconds
   wire [3:0] countdown_sec_ones = (countdown_seconds % 60) % 10; // Ones of countdown seconds

   // Decode accumulated time for display
   wire [5:0] acc_hours = accumulated_seconds / 3600; // Total hours from accumulated seconds
   wire [5:0] acc_minutes = (accumulated_seconds % 3600) / 60; // Total minutes from accumulated seconds
   wire [5:0] acc_seconds = accumulated_seconds % 60; // Total seconds from accumulated seconds
   wire [3:0] acc_hour_tens = acc_hours / 10;         // Tens of accumulated hours
   wire [3:0] acc_hour_ones = acc_hours % 10;         // Ones of accumulated hours
   wire [3:0] acc_min_tens = acc_minutes / 10;       // Tens of accumulated minutes
   wire [3:0] acc_min_ones = acc_minutes % 10;       // Ones of accumulated minutes
   wire [3:0] acc_sec_tens = acc_seconds / 10;       // Tens of accumulated seconds
   wire [3:0] acc_sec_ones = acc_seconds % 10;       // Ones of accumulated seconds

   // Function to convert a digit to 7-segment display encoding
   function [7:0] seven_seg;
       input [3:0] digit;
       begin
           case (digit)
               4'd0: seven_seg = 8'b11111100; // 0
               4'd1: seven_seg = 8'b01100000; // 1
               4'd2: seven_seg = 8'b11011010; // 2
               4'd3: seven_seg = 8'b11110010; // 3
               4'd4: seven_seg = 8'b01100110; // 4
               4'd5: seven_seg = 8'b10110110; // 5
               4'd6: seven_seg = 8'b10111110; // 6
               4'd7: seven_seg = 8'b11100000; // 7
               4'd8: seven_seg = 8'b11111110; // 8
               4'd9: seven_seg = 8'b11110110; // 9
               default: seven_seg = 8'b00000000; // Default case
           endcase
       end
   endfunction

   // Refresh control for segment scanning
   always @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
           refresh_counter <= 0;                // Reset refresh counter
           scan_cnt <= 0;                        // Reset scan counter
       end
       else begin
           refresh_counter <= refresh_counter + 1; // Increment refresh counter
           if (refresh_counter >= 32'd100000) begin  // Refresh every 100000 cycles
               refresh_counter <= 0;            // Reset counter
               if (scan_cnt == 3'd7)
                   scan_cnt <= 0;               // Wrap around to first segment
               else
                   scan_cnt <= scan_cnt + 1;    // Increment scan counter
           end
       end
   end

   // Enable signals for segment display
   always @(scan_cnt) begin
       case(scan_cnt)
           3'b000: seg_en = 8'h01;               // Enable first segment
           3'b001: seg_en = 8'h02;               // Enable second segment
           3'b010: seg_en = 8'h04;               // Enable third segment
           3'b011: seg_en = 8'h08;               // Enable fourth segment
           3'b100: seg_en = 8'h10;               // Enable fifth segment
           3'b101: seg_en = 8'h20;               // Enable sixth segment
           3'b110: seg_en = 8'h40;               // Enable seventh segment
           3'b111: seg_en = 8'h80;               // Enable eighth segment
           default: seg_en = 8'h00;              // Default case (disable all)
       endcase
   end

   // Output segment values based on current display mode
   always @(*) begin
       if (!power_state) begin
           // Turn off all segments when power is off
           seg_out0 = 8'b00000000;
           seg_out1 = 8'b00000000;
       end   
       else if (display_gesture_countdown) begin
           // Display gesture countdown
           case (scan_cnt)
               3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5: begin 
                   seg_out0 = 8'b00000000;      // Clear output
                   seg_out1 = 8'b00000000;      // Clear output
               end
               3'd6: begin
                   seg_out0 = seven_seg(gesture_countdown / 10); // Tens of gesture countdown
                   seg_out1 = seven_seg(gesture_countdown / 10); // Tens of gesture countdown
               end
               3'd7: begin
                   seg_out0 = seven_seg(gesture_countdown % 10); // Ones of gesture countdown
                   seg_out1 = seven_seg(gesture_countdown % 10); // Ones of gesture countdown
               end
               default: begin
                   seg_out0 = 8'b00000000;      // Default case
                   seg_out1 = 8'b00000000;      // Default case
               end
           endcase
       end
       else if (display_accumulated_time) begin
           // Display accumulated time
           case (scan_cnt)
               3'd0: begin 
                   seg_out0 = seven_seg(acc_hour_tens); // Tens of accumulated hours
                   seg_out1 = seven_seg(acc_hour_tens); // Tens of accumulated hours
               end
               3'd1: begin
                   seg_out0 = seven_seg(acc_hour_ones); // Ones of accumulated hours
                   seg_out1 = seven_seg(acc_hour_ones); // Ones of accumulated hours
               end
               3'd2: begin
                   seg_out0 = 8'b00000010;              // Separator (e.g., colon)
                   seg_out1 = 8'b00000010;              // Separator (e.g., colon)
               end
               3'd3: begin
                   seg_out0 = seven_seg(acc_min_tens); // Tens of accumulated minutes
                   seg_out1 = seven_seg(acc_min_tens); // Tens of accumulated minutes
               end
               3'd4: begin
                   seg_out0 = seven_seg(acc_min_ones); // Ones of accumulated minutes
                   seg_out1 = seven_seg(acc_min_ones); // Ones of accumulated minutes
               end
               3'd5: begin
                   seg_out0 = 8'b00000010;              // Separator (e.g., colon)
                   seg_out1 = 8'b00000010;              // Separator (e.g., colon)
               end
               3'd6: begin
                   seg_out0 = seven_seg(acc_sec_tens); // Tens of accumulated seconds
                   seg_out1 = seven_seg(acc_sec_tens); // Tens of accumulated seconds
               end
               3'd7: begin
                   seg_out0 = seven_seg(acc_sec_ones); // Ones of accumulated seconds
                   seg_out1 = seven_seg(acc_sec_ones); // Ones of accumulated seconds
               end
               default: begin
                   seg_out0 = 8'b00000000;              // Default case
                   seg_out1 = 8'b00000000;              // Default case
               end
           endcase
       end
       else if (!display_countdown || countdown_seconds == 0) begin
           // Display current time if countdown is not active or seconds are zero
           case (scan_cnt)
               3'd0: begin 
                   seg_out0 = seven_seg(hour_tens);   // Tens of hours
                   seg_out1 = seven_seg(hour_tens);   // Tens of hours
               end
               3'd1: begin
                   seg_out0 = seven_seg(hour_ones);   // Ones of hours
                   seg_out1 = seven_seg(hour_ones);   // Ones of hours
               end
               3'd2: begin
                   seg_out0 = 8'b00000010;              // Separator (e.g., colon)
                   seg_out1 = 8'b00000010;              // Separator (e.g., colon)
               end
               3'd3: begin
                   seg_out0 = seven_seg(min_tens);     // Tens of minutes
                   seg_out1 = seven_seg(min_tens);     // Tens of minutes
               end
               3'd4: begin
                   seg_out0 = seven_seg(min_ones);     // Ones of minutes
                   seg_out1 = seven_seg(min_ones);     // Ones of minutes
               end
               3'd5: begin
                   seg_out0 = 8'b00000010;              // Separator (e.g., colon)
                   seg_out1 = 8'b00000010;              // Separator (e.g., colon)
               end
               3'd6: begin
                   seg_out0 = seven_seg(sec_tens);     // Tens of seconds
                   seg_out1 = seven_seg(sec_tens);     // Tens of seconds
               end
               3'd7: begin
                   seg_out0 = seven_seg(sec_ones);     // Ones of seconds
                   seg_out1 = seven_seg(sec_ones);     // Ones of seconds
               end
               default: begin
                   seg_out0 = 8'b00000000;              // Default case
                   seg_out1 = 8'b00000000;              // Default case
               end
           endcase
       end
       else begin
           // Display countdown time
           case (scan_cnt)
               3'd0, 3'd1: begin 
                   seg_out0 = 8'b00000000;              // Clear output
                   seg_out1 = 8'b00000000;              // Clear output
               end
               3'd2: begin
                   seg_out0 = 8'b00000010;              // Separator (e.g., colon)
                   seg_out1 = 8'b00000010;              // Separator (e.g., colon)
               end
               3'd3: begin
                   seg_out0 = seven_seg(countdown_min_tens); // Tens of countdown minutes
                   seg_out1 = seven_seg(countdown_min_tens); // Tens of countdown minutes
