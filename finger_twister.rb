# Finger twister for Novation Launchpad Mini and Sonic Pi

# Try to bend your fingers to same color spots. No points for now, just for fun.

set :players, 2
set :fingers, 5

use_debug false
use_midi_logging false

# Randomize seed and starting point
use_random_seed = Time.now.to_i
SecureRandom.random_number(1000).times { rand }
print rand

# Change here for your inputs and outputs. See Sonic Pi's Prefs/IO for ports.
launchpad_in = "/midi:midiin2_(lpminimk3_midi)_1:1/*"
launchpad_out = "midiout2_(lpminimk3_midi)_2"

# This is used mainly for setting how lights flash
midi_clock_beat 0.1, port: launchpad_out

# Set novation mini to programmer mode
define :set_programmer_mode do
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x01, 0xf7
end

# Light up multiple leds from novation launchpad
define :led_sysex do |values|
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x03, *values, 0xf7, port: launchpad_out
end

# Stop scrolling text
define :stop_text do
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x07, 0xf7
end

# Helper method for defining midi rgb
# Nice color picker: https://www.rapidtables.com/web/color/html-color-codes.html
define :rgb do |r,g,b|
  [((127*r)/255),((127*g/255)),((127*b)/255)]
end

# Scroll text on novation launchpad
define :scroll_text do |text, loop=0x01,speed=0x07,rgb=[127,127,127]|
  text = text.chars.map { |b| b.ord }
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x07, loop, speed, 0x01, *rgb, *text, 0xf7
end

# Set single cell flashing from color palette
define :set_cell_flash do |x, y, c1, c2|
  cell = (x.to_s+y.to_s).to_i
  values = [0x01, cell, c1, c2]
  led_sysex values
end

# Flash multiple cells from color palette
define :flash_cells do |cells, a, b|
  cells.each do |cell|
    set_cell_flash cell[:x], cell[:y], a, b
  end
end

# Ring of rainbow colors
define :rainbow_colors do
  rainbows = (ring rgb(255, 0, 0), rgb(255, 128, 0), rgb(255, 255, 0), rgb(128, 255, 0), rgb(0, 255, 0), rgb(0, 255, 128), rgb(0, 255, 255), rgb(0, 128, 255), rgb(0, 0, 255),rgb(128, 0, 255), rgb(255, 0, 255), rgb(255, 0, 128))
end

# Set single cell color from predefined palette
define :set_cell_color_from_palette do |x, y, num|
  cell = (x.to_s+y.to_s).to_i
  values = [0x00, cell, num]
  led_sysex values
end

# Set multiple cells
define :set_colors_from_palette do |arr, number|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x00, cell, number]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Set single cell color as rgb
define :set_cell_color do |x, y, rgb|
  cell = (x.to_s+y.to_s).to_i
  values = [0x03, cell, *rgb]
  led_sysex values
end

# Set multiple cells
define :clear_pads do
  pad_colors = []
  8.times do |x|
    8.times do |y|
      cell = (x+1).to_s+(y+1).to_s
      cell_color = [0x00, cell, 0]
      pad_colors = pad_colors+cell_color
    end
  end
  led_sysex pad_colors
end

# Set multiple cells
define :set_colors do |arr, rgb|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x03, cell, *rgb]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Set colors for the whole matrix
define :set_pad_colors_from_list do |matrix,list,s=0|
  pad_colors = []
  matrix.length.times do |x|
    row = matrix[x]
    row.length.times do |y|
      cell = matrix[x][y]
      cell_color = [0x03, ((matrix.length-x).to_s+(y+1).to_s).to_i, *list[(y+ (s==0 ? (x*row.length) : (x+s)))%list.length]]
      pad_colors = pad_colors+cell_color
    end
  end
  led_sysex pad_colors
end

# Defines color gradient array using sin
define :get_color_gradient do |fr1, fr2, fr3, ph1, ph2, ph3, len=50, center=128, width=127|
  colors = (1..len).map do |i|
    red = [(Math.sin(fr1*i+ph1) * width + center).to_i,255].min
    grn = [(Math.sin(fr2*i*ph2) * width + center).to_i,255].min
    blue = [(Math.sin(fr3*i*ph3) * width + center).to_i,255].min
    rgb(red,grn,blue)
  end
end

# Set colors for the whole matrix
define :set_pad_colors do |matrix,rgb|
  pad_colors = []
  matrix.length.times do |x|
    row = matrix[x]
    row.length.times do |y|
      cell = matrix[x][y]
      cell_color = [0x03, ((matrix.length-x).to_s+(y+1).to_s).to_i, *rgb]
      pad_colors = pad_colors+cell_color
    end
  end
  led_sysex pad_colors
end

# Get player color
define :player_color do |p|
  # TODO / OPTIONAL: Color choosing from board?
  colors = [45,76,74,72,100,95,2,103]
  colors[p]
end


# Get sync type from the midi call
define :sync_type do |address|
  v = get_event(address).to_s.split(",")[6]
  if v != nil
    return v[3..-2].split("/")[1]
  else
    return "error"
  end
end

# Write your game settings here
define :start_game do
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  $board = (1..8).map {|x| (1..8).map {|y| {x: x, y: y, value: nil}}} # Create new board
  print $board
  clear_pads
  players = get :players
  $times = (1..players).map {|p| 0.0 }
  set :state, :relax
  set :game_over, false
  
  in_thread do
    use_random_seed = Time.now.to_i
    SecureRandom.random_number(1000).times { rand }
    players = get :players
    spots = players * 5
    spots.times do |i|
      x = rrand_i(0,7)
      y = rrand_i(0,7)
      
      until $board[x][y][:value]==nil
        x = rrand_i(0,7)
        y = rrand_i(0,7)
      end
      
      $board[x][y][:value] = (i%players)
      set_cell_color_from_palette x+1, y+1, player_color(i%players)
      
      sleep 1
    end
  end
  
end

# Thread for listening events from the novation launchpad
live_loop :event_listener do
  use_real_time
  # midi note is touch position 11, 12, 13 ...
  # midi velocity is touch 127=on 0=off
  pad, touch = sync launchpad_in
  # note_on = pads, control_change = options
  type = sync_type launchpad_in
  
  xy = pad.to_s.chars
  x = xy[0].to_i
  y = xy[1].to_i
  
  if type=="note_on"
    if touch==0 # Touch off
      cue :push, type: :off, x: x, y: y
      # sleep 0.5
    else
      cue :push, type: :on, x: x, y: y
    end
  elsif type=="control_change"
    if get_pad_status(19) and get_pad_status(91) then
      print "Starting new game"
      start_game # Start new game
    end
    if touch==0
      set_pad_status pad, false
    else
      set_pad_status pad, true
    end
  end
end

define :set_pad_status do |id, bool|
  set ("pad_"+id.to_s).to_sym, bool
end

define :get_pad_status do |id|
  get ("pad_"+id.to_s).to_sym
end


# Thread for keeping up the score
live_loop :fingertwister do
  use_real_time
  event = sync :push
  game_over = get :game_over
  
  if event
    x = event[:x]
    y = event[:y]
    
    if event[:type]==:on
      # Do something
    end
    
    if game_over
      set :state, :happy
      # Or sad
      in_thread do # In separate thread to enable sleeping
        if get :game_over # If new game hasnt started yet
          scroll_text (turn+1).to_s+" WINS !", 1, 15, rgb(255,255,0)
          sleep 3
          start_game
        end
      end
    end
  end
end

# Set different scales for different states
relax = (scale :d3, :kumoi).shuffle
happy = (scale :a4, :major_pentatonic).shuffle

live_loop :music do
  state = get :state
  if state == :relax then
    synth :dull_bell, note: relax[tick]
  end
  sleep 1
end

start_game