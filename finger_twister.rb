# Finger twister for Novation Launchpad Mini and Sonic Pi

# Rules: Each player presses pads with different colors with one or more hands. One who has pressed all pads after the last coloured pad appears wins. Play at your own risk. Game developer is not responsible for any broken fingers.

# Game settings: Defaults are 2 players with one hand. Optionally 2/10 is also fun ... or whatever depending on number of players and available fingers to sacrifice :)
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

# Helper method for defining midi rgb
# Nice color picker: https://www.rapidtables.com/web/color/html-color-codes.html
define :rgb do |r,g,b|
  [((127*r)/255),((127*g/255)),((127*b)/255)]
end

# Stop scrolling text
define :stop_text do
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x07, 0xf7
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

# Flash multiple cells from color palette
define :remove_pressed_cells do |arr|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x00, cell[:id], 0]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Flash multiple cells from color palette
define :flash_missing_cells do |cells|
  cells.each do |cell|
    set_cell_flash cell[:x], cell[:y], 0, cell[:color]
  end
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
  set :game_over, false
  set :state, :relax
  set :pads_left, 0
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  $board = (1..8).map {|x| (1..8).map {|y| {id: ((9-x).to_s+y.to_s).to_i, x: 9-x, y: y, value: nil}}} # Create new board
  clear_pads
  players = get :players
  $times = (1..players).map {|p| 0.0 }
  relax = (scale :d3, :kumoi).shuffle
  
  in_thread do
    use_random_seed = Time.now.to_i
    SecureRandom.random_number(1000).times { rand }
    players = get :players
    fingers = get :fingers
    spots = players * fingers
    spots.times do |i|
      x = rrand_i(0,7)
      y = rrand_i(0,7)
      
      until $board[x][y][:value]==nil
        x = rrand_i(0,7)
        y = rrand_i(0,7)
      end
      
      $board[x][y][:value] = (i%players)
      $board[x][y][:color] = player_color(i%players)
      print $board[x][y]
      set_cell_color_from_palette 8-x, y+1, player_color(i%players)
      synth :dull_bell, note: relax[tick]
      sleep 1
      
    end
    sleep 1
    set :game_over, true
    pressed = $board.map {|row| row.select {|cell| cell[:press] } }.flatten
    not_pressed = $board.map {|row| row.select {|cell| cell[:value] and !cell[:press] } }.flatten
    set :not_pressed, not_pressed.length
    if not_pressed.length>0
      set :state, :sad
    else
      set :state, :happy
      scroll_text "=) Yall win! (=", 1, 15, rgb(255,255,0)
      sleep 1
    end
    remove_pressed_cells pressed
    flash_missing_cells not_pressed
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
      cue :push, type: :off, x: 8-x, y: y-1
      # sleep 0.5
    else
      if get(:game_over) # Start new game
        stop_text
        sleep 2
        start_game
      end
      
      cue :push, type: :on, x: 8-x, y: y-1
    end
  elsif type=="control_change"
    if get_pad_status(19) and get_pad_status(91) then
      print "Starting new game"
      if get(:game_over)
        stop_text
        sleep 2
        start_game
      end
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
  
  if event
    x = event[:x]
    y = event[:y]
    
    if event[:type] == :on
      if $board[x][y][:value]
        $board[x][y][:press]=true
        print $board
      end
    elsif event[:type] == :off
      if $board[x][y][:value]
        $board[x][y][:press]=false
      end
    end
    
  end
end

# Set different scales for different states
happy = (scale :a4, :major_pentatonic).shuffle
sad = (scale :c3, :blues_minor).shuffle

live_loop :music do
  state = get :state
  if state == :happy
    synth :chiplead, note: happy[tick]
    sleep 0.25
  elsif state == :sad
    (get :not_pressed).times do
      synth :hollow, note: sad[tick], attack: rand(0.5), release: 3, amp: rrand(0.50, 1)
      sleep rand(0.5)
    end
    sleep rrand(1.5, 3.0)
  else
    sleep 0.25
  end
  if rand>0.2
    happy = happy.shuffle
    sad = sad.shuffle
  end
end

start_game