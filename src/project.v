`default_nettype none

module tt_um_jact31_signaldisplay(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  wire hsync;
  wire vsync;
  reg  [1:0] R;
  reg  [1:0] G;
  reg  [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  reg [7:0] frame;
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) frame <= 0;
    else        frame <= frame + 1;
  end

  function [5:0] qsin(input [5:0] i);
    case (i)
      6'd0:  qsin = 6'd1;   6'd1:  qsin = 6'd2;   6'd2:  qsin = 6'd4;   6'd3:  qsin = 6'd5;
      6'd4:  qsin = 6'd7;   6'd5:  qsin = 6'd8;   6'd6:  qsin = 6'd10;  6'd7:  qsin = 6'd12;
      6'd8:  qsin = 6'd13;  6'd9:  qsin = 6'd15;  6'd10: qsin = 6'd16;  6'd11: qsin = 6'd18;
      6'd12: qsin = 6'd19;  6'd13: qsin = 6'd20;  6'd14: qsin = 6'd22;  6'd15: qsin = 6'd23;
      6'd16: qsin = 6'd25;  6'd17: qsin = 6'd26;  6'd18: qsin = 6'd28;  6'd19: qsin = 6'd29;
      6'd20: qsin = 6'd30;  6'd21: qsin = 6'd32;  6'd22: qsin = 6'd33;  6'd23: qsin = 6'd34;
      6'd24: qsin = 6'd36;  6'd25: qsin = 6'd37;  6'd26: qsin = 6'd38;  6'd27: qsin = 6'd39;
      6'd28: qsin = 6'd41;  6'd29: qsin = 6'd42;  6'd30: qsin = 6'd43;  6'd31: qsin = 6'd44;
      6'd32: qsin = 6'd45;  6'd33: qsin = 6'd46;  6'd34: qsin = 6'd47;  6'd35: qsin = 6'd48;
      6'd36: qsin = 6'd49;  6'd37: qsin = 6'd50;  6'd38: qsin = 6'd51;  6'd39: qsin = 6'd52;
      6'd40: qsin = 6'd53;  6'd41: qsin = 6'd54;  6'd42: qsin = 6'd54;  6'd43: qsin = 6'd55;
      6'd44: qsin = 6'd56;  6'd45: qsin = 6'd57;  6'd46: qsin = 6'd57;  6'd47: qsin = 6'd58;
      6'd48: qsin = 6'd58;  6'd49: qsin = 6'd59;  6'd50: qsin = 6'd60;  6'd51: qsin = 6'd60;
      6'd52: qsin = 6'd61;  6'd53: qsin = 6'd61;  6'd54: qsin = 6'd61;  6'd55: qsin = 6'd62;
      6'd56: qsin = 6'd62;  6'd57: qsin = 6'd62;  6'd58: qsin = 6'd62;  6'd59: qsin = 6'd63;
      6'd60: qsin = 6'd63;  6'd61: qsin = 6'd63;  6'd62: qsin = 6'd63;  6'd63: qsin = 6'd63;
    endcase
  endfunction

  function [7:0] sin8(input [7:0] p);
    reg [5:0] idx;
    reg [7:0] mag;
    begin
      idx  = p[6] ? ~p[5:0] : p[5:0];
      mag  = {2'b00, qsin(idx)};
      sin8 = p[7] ? (~mag + 8'd1) : mag;
    end
  endfunction

  wire [7:0] ph1 = pix_x[7:0] + {frame[6:0], 1'b0};
  wire [7:0] ph3 = ph1 + {ph1[6:0], 1'b0};
  wire [7:0] ph5 = ph3 + {ph1[6:0], 1'b0};

  wire [7:0] s1 = sin8(ph1);
  wire [7:0] s3 = sin8(ph3);
  wire [7:0] s5 = sin8(ph5);

  wire _unused_ok = &{ena, ui_in, uio_in, pix_x[9:8], s3[1:0], s5[2:0]};

  wire [11:0] e1  = {{4{s1[7]}}, s1};
  wire [11:0] h3  = {{6{s3[7]}}, s3[7:2]} + {{8{s3[7]}}, s3[7:4]} + {{10{s3[7]}}, s3[7:6]};
  wire [11:0] h5  = {{7{s5[7]}}, s5[7:3]} + {{8{s5[7]}}, s5[7:4]} + {{10{s5[7]}}, s5[7:6]};
  wire [11:0] sq  = e1 + h3 + (frame[7] ? h5 : 12'd0);

  wire [11:0] y   = {2'b00, pix_y};
  wire [11:0] d1  = y - 12'd128 + e1;
  wire [11:0] d3  = y - 12'd128 + h3;
  wire [11:0] dsq = y - 12'd352 + sq;

  wire hit1  = (d1  + 12'd2) < 12'd5;
  wire hit3  = (d3  + 12'd1) < 12'd3;
  wire hitsq = (dsq + 12'd3) < 12'd7;

  wire grid    = (pix_x[4:0] == 5'd0) || (pix_y[4:0] == 5'd0);
  wire ticks   = (pix_x[2:0] == 3'd0) && ((pix_y == 10'd127) || (pix_y == 10'd129) ||
                                          (pix_y == 10'd351) || (pix_y == 10'd353));
  wire axis    = (pix_y == 10'd128) || (pix_y == 10'd352);
  wire divider = (pix_y >= 10'd238) && (pix_y <= 10'd241);

  always @* begin
    {R, G, B} = 6'b00_00_00;
    if (video_active) begin
      if (grid || ticks)  {R, G, B} = 6'b00_01_00;
      if (axis)           {R, G, B} = 6'b01_01_01;
      if (divider)        {R, G, B} = 6'b01_01_10;
      if (hit3)           {R, G, B} = 6'b00_11_11;
      if (hit1)           {R, G, B} = 6'b11_11_00;
      if (hitsq)          {R, G, B} = frame[7] ? 6'b11_00_11 : 6'b11_11_11;
    end
  end

endmodule
