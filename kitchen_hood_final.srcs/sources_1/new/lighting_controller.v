`timescale 1ns / 1ps

module lighting_controller (
    input wire clk,                 // Clock input
    input wire rst_n,              // Active low reset input
    input wire power_state,         // Power state signal
    input wire lighting_switch,     // Switch input instead of button
    output reg lighting_state       // Output for lighting state
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lighting_state <= 0;        // Reset lighting state to off
    end
    else if (!power_state) begin
        lighting_state <= 0;        // Turn off lighting if power is off
    end
    else begin
        lighting_state <= lighting_switch; // Set lighting state based on switch input
    end
end
endmodule
