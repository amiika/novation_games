# Sonic Tic Tac Toe

# Change these for more players. Best options: 2/5, 3/3, 4/3 up to 8/3.
# 8/2 is also fun with single player (Try not to win)

set :players, 2
set :to_win, 5

use_debug false
use_midi_logging false

# Midi ports for the launchpad
launchpad_in = "/midi:midiin2_(lpminimk3_midi)_1:1/*"
launchpad_out = "midiout2_(lpminimk3_midi)_2"

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
define :set_colors do |arr, rgb|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x03, cell, *rgb]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Get all diagonals from matrix
define :get_diagonals do |arr|
  padding = [*0..(arr.length - 1)].map { |i| [nil] * i }
  padded = padding.reverse.zip(arr).zip(padding).map(&:flatten)
  padded.transpose.map(&:compact)
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

# Get sync type from the midi call
define :sync_type do |address|
  v = get_event(address).to_s.split(",")[6]
  if v != nil
    return v[3..-2].split("/")[1]
  else
    return "error"
  end
end

define :check_row do |row, player|
  to_win = get :to_win
  consecutive = row.slice_when {|prev,cur| cur[:value] != prev[:value]}.to_a
  points = consecutive.filter {|v| v[0][:value]==player}.max {|v| v.length }
  return points if points and points.length >= to_win
  return nil
end

define :check_score do |p|
  
  $board.each do |row|
    result = check_row row, p
    return result if result
  end
  
  transposed = $board.transpose
  transposed.each do |row|
    result = check_row row, p
    return result if result
  end
  
  diagonals = get_diagonals $board
  diagonals.each do |row|
    result = check_row row, p
    return result if result
  end
  
  antidiagonals = get_diagonals $board.reverse
  antidiagonals.each do |row|
    result = check_row row, p
    return result if result
  end
  
  return nil
end

# Get player color
define :player_color do |p|
  # TODO / OPTIONAL: Color choosing from board?
  colors = [45,76,74,72,100,95,2,103]
  colors[p]
end

# Game settings
define :start_game do
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  $board = (1..8).map {|x| (1..8).map {|y| {x: x, y: y, value: nil}}} # Create new board
  set_pad_colors $board, rgb(0,0,0) # Set color
  set_colors_from_palette [91,92,93,94,95,96,97,98,89,79,69,59,49,39,29,19], player_color(0) # Set side colors
  set :state, :relax
  set :turn, 0
  set :winner, nil
end

# Start a new game
start_game

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
      cue :push_event, type: :push, x: x, y: y
      sleep 0.5 # Miss some events to prevent accidental pushes
    end
  elsif type=="control_change"
    if get_pad_status(19) and get_pad_status(91) then
      print "Starting new game"
      $game = start_game # Start new game
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
live_loop :tictatoe do
  use_real_time
  event = sync :push_event
  
  turn = get :turn
  players = get :players
  winner = get :winner
  
  if event
    x = event[:x]
    y = event[:y]
    
    if event[:type]==:push
      cell_value = $board[x-1][y-1][:value]
      if cell_value==nil # Empty cells only
        blips = [:elec_wood, :elec_blip, :elec_bong, :elec_flip, :glitch_perc2, :glitch_perc3, :ambi_choir, :glitch_perc5, :glitch_perc1]
        sample blips[tick%blips.length]
        $board[x-1][y-1][:value] = turn
        print "Setting cell color"
        set_cell_color_from_palette x, y, player_color(turn)
        next_turn = (turn+1) % players
        set :turn, next_turn
        set_colors_from_palette [91,92,93,94,95,96,97,98,89,79,69,59,49,39,29,19], player_color(next_turn)
        winner = check_score turn
        set :winner, winner if winner
      end
    end
    
    if winner
      set :state, :happy
      in_thread do # In separate thread to enable sleeping
        flash_cells winner, 13, player_color(turn)
        sleep 3
        if get :winner # If new game hasnt started yet
          scroll_text (turn+1).to_s+" WINS !", 1, 15, rgb(255,255,0)
          sleep 3
          start_game
        end
      end
    end
    
  end
end

relax = (scale :d3, :kumoi).shuffle
happy = (scale :a4, :major_pentatonic).shuffle

# Thread for creating exiting music from the game state
live_loop :music do
  state = get(:state)
  tick
  synth :mod_sine, mod_phase: (line 0.5, 1.5, step: 0.05).mirror.look, amp: 0.5,  note: relax.look if spread(8,12).look and state==:relax
  synth :chiplead, note: happy.look if state==:happy
  synth :fm, note: relax.look-3, pitch: -12, amp: 0.5 if spread(4,16).look and state==:relax
  sample :bd_klub if spread(3,8).look
  sleep 0.25
  if rand>0.5
    relax = relax.shuffle
    happy = happy.shuffle
  end
end
