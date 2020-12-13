`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish_clock, fish2_clock, fish3_clock, fish1c_clock, fish1d_clock;
wire [9:0]  pos, pos2, pos3, pos1c, pos1d;
wire        fish_region, fish2_region, fish3_region, fish1c_region, fish1d_region;

// declare SRAM control signals
wire [16:0] sram_addr, sram_addr_fish1, sram_addr_fish2, sram_addr_fish3, sram_addr_fish1c, sram_addr_fish1d;
wire [11:0] data_in;
wire [11:0] data_out, data_out_fish1, data_out_fish2, data_out_fish3, data_out_fish1c, data_out_fish1d;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel

// Application-specific VGA signals
reg  [17:0] pixel_addr, pixel_addr_fish1, pixel_addr_fish2, pixel_addr_fish3, pixel_addr_fish1c, pixel_addr_fish1d;

integer speed1 = 0, speed2 = 0, speed3 = 0, speed4 = 0, speed5 = 0;
integer move_delay = 0;
reg pause;
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH_W      = 64; // Width of the fish.
localparam FISH_H      = 32; // Height of the fish.
reg [17:0] fish_addr[0:2];   // Address array for up to 8 fish images.
//// fish 2
localparam FISH2_VPOS   = 150;
localparam FISH2_W      = 64;
localparam FISH2_H      = 44;
reg [17:0] fish2_addr[0:2];
//// fish 3
localparam FISH3_VPOS   = 120;
localparam FISH3_W      = 64;
localparam FISH3_H      = 72;
reg [17:0] fish3_addr[0:2];
//// fish 1 complex
localparam FISH1c_VPOS   = 30;
reg [17:0] fish1c_addr[0:2];
localparam FISH1d_VPOS   = 140;
reg [17:0] fish1d_addr[0:2];

// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish_addr[0] = 18'd0;//VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
  fish_addr[1] = FISH_W*FISH_H;//VBUF_W*VBUF_H + FISH_W*FISH_H; /* Addr for fish image #2 */
  fish2_addr[0] = 18'd0;
  fish2_addr[1] = FISH2_W*FISH2_H;
  fish3_addr[0] = 18'd0;
  fish3_addr[1] = FISH3_W*FISH3_H;
  fish1c_addr[0] = 18'd0;
  fish1c_addr[1] = FISH_W*FISH_H;
  fish1d_addr[0] = 18'd0;
  fish1d_addr[1] = FISH_W*FISH_H;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit fish1 image, plus two 64x32 fish images.
// VBUF_W*VBUF_H+
// FISH_W*FISH_H*2
sram_seabed #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H*6))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_fish1), .data_i(data_in), .data_o(data_out_fish1));

sram_fish2 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH2_W*FISH2_H*3))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_fish2), .data_i(data_in), .data_o(data_out_fish2));

sram_fish3 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH3_W*FISH3_H*4))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_fish3), .data_i(data_in), .data_o(data_out_fish3));

sram_fish1c #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H*6))
  ram4 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_fish1c), .data_i(data_in), .data_o(data_out_fish1c));

sram_fish1d #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H*6))
  ram5 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_fish1d), .data_i(data_in), .data_o(data_out_fish1d));
// 3435
assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign sram_addr_fish1 = pixel_addr_fish1;
assign sram_addr_fish1c = pixel_addr_fish1c;
assign sram_addr_fish1d = pixel_addr_fish1d;
assign sram_addr_fish2 = pixel_addr_fish2;
assign sram_addr_fish3 = pixel_addr_fish3;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
assign pos = fish_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign pos2 = fish2_clock[31:20];
assign pos3 = fish3_clock[31:20];
assign pos1c = fish1c_clock[31:20];
assign pos1d = fish1d_clock[31:20];

always @(posedge clk) begin
  if (~reset_n) begin
    speed1 = 0;
  end 
  else if (speed1 >= 1) speed1 <= 0;
  else speed1 <= speed1 + 1;
end

always @(posedge clk) begin
  if (~reset_n) begin
    speed2 = 0;
  end 
  else if (speed2 >= 2) speed2 <= 0;
  else speed2 <= speed2 + 1;
end

always @(posedge clk) begin
  if (~reset_n) begin
    speed3 = 0;
  end
  else if (speed3 >= 3) speed3 <= 0;
  else speed3 <= speed3 + 1;
end

always @(posedge clk) begin
  if (~reset_n) begin
    speed4 = 0;
  end
  else if (speed4 >= 4) speed4 <= 0;
  else speed4 <= speed4 + 1;
end

always @(posedge clk) begin
  if (~reset_n) begin
    speed5 = 0;
  end
  else if (speed5 >= 10) speed5 <= 0;
  else speed5 <= speed5 + 1;
end

always @(posedge clk) begin
  if (~reset_n || fish_clock[31:21] > VBUF_W + FISH_W)
    fish_clock <= 0;
  else if (speed1 == 0)
    fish_clock <= fish_clock + 1;
end

always @(posedge clk) begin
  if (~reset_n || fish2_clock[31:21] > VBUF_W + FISH2_W)
    fish2_clock <= 0;
  else if (speed2 == 0)
    fish2_clock <= fish2_clock + 1;
end

always @(posedge clk) begin
  if (~reset_n || fish3_clock[31:21] == 0)
    fish3_clock <= 32'hffffffff;
  else if (speed3 == 0)
    fish3_clock <= fish3_clock - 1;
end

always @(posedge clk) begin
  if (~reset_n || fish1c_clock[31:21] > VBUF_W + FISH_W)
    fish1c_clock <= 0;
  else if (speed3 == 0)
      fish1c_clock <= fish1c_clock + 1;
end

always @(posedge clk) begin
  if (~reset_n || fish1d_clock[31:21] > VBUF_W + FISH_W)
    fish1d_clock <= 0;
  else if (speed4 == 0)
      fish1d_clock <= fish1d_clock + 1;
end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish_region =
           pixel_y >= (FISH_VPOS<<1) && pixel_y < (FISH_VPOS+FISH_H)<<1 &&
           (pixel_x + 127) >= pos && pixel_x < pos + 1;
assign fish2_region =
           pixel_y >= (FISH2_VPOS<<1) && pixel_y < (FISH2_VPOS+FISH2_H)<<1 &&
           (pixel_x + 127) >= pos2 && pixel_x < pos2 + 1;
assign fish3_region =
           pixel_y >= (FISH3_VPOS<<1) && pixel_y < (FISH3_VPOS+FISH3_H)<<1 &&
           (pixel_x + 127) >= pos3 && pixel_x < pos3 + 1;
assign fish1c_region =
           pixel_y >= (FISH1c_VPOS<<1) && pixel_y < (FISH1c_VPOS+FISH_H)<<1 &&
           (pixel_x + 127) >= pos1c && pixel_x < pos1c + 1;
assign fish1d_region =
           pixel_y >= (FISH1d_VPOS<<1) && pixel_y < (FISH1d_VPOS+FISH_H)<<1 &&
           (pixel_x + 127) >= pos1d && pixel_x < pos1d + 1;

always @ (posedge clk) begin
  if (~reset_n)
    pixel_addr <= 0;
  else
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

always @ (posedge clk) begin
  if (~reset_n) pixel_addr_fish1 <= 0;
  else if (fish_region)
    pixel_addr_fish1 <= fish_addr[fish_clock[23]] +
                      ((pixel_y>>1)-FISH_VPOS)*FISH_W +
                      ((pixel_x +(FISH_W*2-1)-pos)>>1);
  else pixel_addr_fish1 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

always @ (posedge clk) begin
  if (~reset_n) pixel_addr_fish2 <= 0;
  else if (fish2_region)
    pixel_addr_fish2 <= fish2_addr[fish2_clock[23]] +
                      ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                      ((pixel_x +(FISH2_W*2-1)-pos2)>>1);
  else pixel_addr_fish2 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

always @ (posedge clk) begin
  if (~reset_n) pixel_addr_fish3 <= 0;
  else if (fish3_region)
    pixel_addr_fish3 <= fish3_addr[fish3_clock[23]] +
                      ((pixel_y>>1)-FISH3_VPOS)*FISH3_W +
                      ((pixel_x +(FISH3_W*2-1)-pos3)>>1);
  else pixel_addr_fish3 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

always @ (posedge clk) begin
  if (~reset_n) pixel_addr_fish1c <= 0;
  else if (fish1c_region)
    pixel_addr_fish1c <= fish1c_addr[fish1c_clock[23]] +
                      ((pixel_y>>1)-FISH1c_VPOS)*FISH_W +
                      ((pixel_x +(FISH_W*2-1)-pos1c)>>1);
  else pixel_addr_fish1c <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end

always @ (posedge clk) begin
  if (~reset_n) pixel_addr_fish1d <= 0;
  else if (fish1d_region)
    pixel_addr_fish1d <= fish1d_addr[fish1d_clock[23]] +
                      ((pixel_y>>1)-FISH1d_VPOS)*FISH_W +
                      ((pixel_x +(FISH_W*2-1)-pos1d)>>1);
  else pixel_addr_fish1d <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else begin
    if (fish1c_region && fish_region) begin
      if (data_out_fish1c != 12'h0f0 && data_out_fish1 != 12'h0f0) rgb_next = data_out_fish1c;
      else if (data_out_fish1c != 12'h0f0) rgb_next = data_out_fish1c;
      else if (data_out_fish1 != 12'h0f0) rgb_next = data_out_fish1;
      else rgb_next = data_out;
    end
    else if (fish1d_region && fish2_region && fish3_region) begin
      if (data_out_fish1d != 12'h0f0 && data_out_fish2 != 12'h0f0 && data_out_fish3 != 12'h0f0)
        rgb_next = data_out_fish1d;
      else if (data_out_fish1d != 12'h0f0 && data_out_fish2 != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish1d != 12'h0f0 && data_out_fish3 != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish2 != 12'h0f0 && data_out_fish3 != 12'h0f0) rgb_next = data_out_fish2;
      else if (data_out_fish1d != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish2 != 12'h0f0) rgb_next = data_out_fish2;
      else if (data_out_fish3 != 12'h0f0) rgb_next = data_out_fish3;
      else rgb_next = data_out;
    end
    else if (fish1d_region && fish3_region) begin
      if (data_out_fish1d != 12'h0f0 && data_out_fish3 != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish1d != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish3 != 12'h0f0) rgb_next = data_out_fish3;
      else rgb_next = data_out;
    end
    else if (fish1d_region && fish2_region) begin
      if (data_out_fish1d != 12'h0f0 && data_out_fish2 != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish1d != 12'h0f0) rgb_next = data_out_fish1d;
      else if (data_out_fish2 != 12'h0f0) rgb_next = data_out_fish2;
      else rgb_next = data_out;
    end
    else if (fish2_region && fish3_region) begin
      if (data_out_fish2 != 12'h0f0 && data_out_fish3 != 12'h0f0) rgb_next = data_out_fish2;
      else if (data_out_fish2 != 12'h0f0) rgb_next = data_out_fish2;
      else if (data_out_fish3 != 12'h0f0) rgb_next = data_out_fish3;
      else rgb_next = data_out;
    end
    else if (fish_region) begin
      if (data_out_fish1 != 12'h0f0) rgb_next = data_out_fish1;
      else rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
    end
    else if (fish1c_region) begin
      if (data_out_fish1c != 12'h0f0) rgb_next = data_out_fish1c;
      else rgb_next = data_out;
    end
    else if (fish1d_region) begin
      if (data_out_fish1d != 12'h0f0) rgb_next = data_out_fish1d;
      else rgb_next = data_out;
    end
    else if (fish2_region) begin
      if (data_out_fish2 != 12'h0f0) rgb_next = data_out_fish2;
      else rgb_next = data_out;
    end
    else if (fish3_region) begin
      if (data_out_fish3 != 12'h0f0) rgb_next = data_out_fish3;
      else rgb_next = data_out;
    end
    else rgb_next = data_out;
  end
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
