<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project turns a VGA monitor into a two-channel "oscilloscope" that shows Fourier synthesis of a square wave in real time. The design has no frame buffer. Every pixel colour is computed on the fly from the current beam position (`pix_x`, `pix_y`) supplied by a standard 640×480 @ 60 Hz `hvsync_generator`.

**Sine generation.** A 64-entry quarter-wave lookup table stores 6-bit amplitudes (0–63). Using quarter-wave symmetry, an 8-bit phase p gives one full period of 256 samples:

- p[6] mirrors the table index,
- p[7] negates the result (two's complement).

**Phases and harmonics.** The fundamental phase is ph1 = pix_x[7:0] + 2·frame. Each period is therefore 256 pixels wide (2.5 periods across the screen), and the waveform scrolls 2 pixels per frame. The harmonics are derived exactly from the same phase using shifts and adds only:

- ph3 = 3·ph1 (mod 256)
- ph5 = 5·ph1 (mod 256)

**Fourier coefficients.** The ideal square-wave coefficients 1/3 and 1/5 are approximated with shift-and-add, so no multipliers are needed:

- 1/3 ≈ 1/4 + 1/16 + 1/64 = 21/64 ≈ 0.328
- 1/5 ≈ 1/8 + 1/16 + 1/64 = 13/64 ≈ 0.203

The bottom trace is the partial sum

sq(x) = sin(x) + (1/3)·sin(3x) [+ (1/5)·sin(5x)]

where the 5th-harmonic term is added only while bit 7 of the frame counter is set. This term toggles every 128 frames (≈ 2.1 s), so the viewer sees the waveform alternate between the 2-term and the 3-term approximation and become visibly squarer.

**Drawing.** A trace is drawn wherever |pix_y − (centre − s)| is within a small band: ±2 px for the fundamental, ±1 px for the harmonic and ±3 px for the sum. All arithmetic is done in 12-bit two's complement with explicit sign extension.

**Screen layout**

| Region | Content | Colour |
|---|---|---|
| Top panel (centre y = 128) | Fundamental sin(x) | Yellow |
| Top panel (centre y = 128) | Scaled 3rd harmonic (1/3)·sin(3x) | Cyan |
| Bottom panel (centre y = 352) | Partial sum, 2 terms | White |
| Bottom panel (centre y = 352) | Partial sum, 3 terms (adds 5th harmonic) | Magenta |
| Background | 32-pixel graticule | Dark green |
| Panel centres | Zero axes with ticks every 8 px | Grey |
| y = 238–241 | Panel divider | Blue |

The frame counter (`frame`) increments on every rising edge of VSYNC and is cleared by `rst_n`. It drives both the scrolling and the 5th-harmonic toggle.

## How to test

1. Plug a TinyVGA PMOD (or a compatible 2-bit-per-channel resistor DAC) into the output PMOD header and connect it to a VGA monitor.
2. Set the project clock to 25.175 MHz (the standard 640×480 @ 60 Hz pixel clock; 25 MHz also works on most monitors).
3. Pulse `rst_n` low and release it.
4. Check that the monitor shows:
   - the yellow fundamental and the cyan 3rd harmonic in the top panel, both scrolling to the left;
   - their sum in the bottom panel, an approximate square wave with Gibbs-like ripple on the flat sections;
   - the bottom trace switching between white (sin x + sin 3x / 3) and magenta (+ sin 5x / 5) roughly every 2 seconds, with the magenta version showing steeper edges and more, smaller ripples.

No inputs are used: `ui_in` and `uio_in` are ignored, and `uio` is configured entirely as inputs.

The design can also be simulated in the Tiny Tapeout VGA Playground.

## External hardware

- **TinyVGA PMOD** (or equivalent VGA DAC), connected to the dedicated outputs `uo_out[7:0]`:

| Pin | Signal |
|---|---|
| uo[0] | R1 |
| uo[1] | G1 |
| uo[2] | B1 |
| uo[3] | VSYNC |
| uo[4] | R0 |
| uo[5] | G0 |
| uo[6] | B0 |
| uo[7] | HSYNC |

- **VGA monitor** that supports 640×480 @ 60 Hz.
