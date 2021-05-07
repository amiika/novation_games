# Sonic memory game

# Defaults to Windows system sounds
# For mac use: /System/Library/Sounds/
# For linux maybe: /usr/share/sounds/ or some subdirectory from there
# Or any directory with at least 32 different samples in it
samples_folder = "C:/Windows/Media"

# 1-5 pairs with the same color
difficulty = 2

# Randomize seed and starting point
use_random_seed = Time.now.to_i
SecureRandom.random_number(1000).times { rand }


number_of_samples = Dir[samples_folder+"/*.{wav,aif,aiff,aifc,flac}"].length
game_colors = (1..127).to_a.shuffle.first(32)
game_sounds = (0..number_of_samples).to_a.shuffle.first(32)
set :last_cell, nil

use_debug false
use_midi_logging false

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

# Scroll text on novation launchpad
define :scroll_text do |text, loop=0x01,speed=0x07,rgb=[127,127,127]|
  text = text.chars.map { |b| b.ord }
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x07, loop, speed, 0x01, *rgb, *text, 0xf7
end

# Ring of rainbow colors
define :rainbow_colors do
  rainbows = (ring rgb(255, 0, 0), rgb(255, 128, 0), rgb(255, 255, 0), rgb(128, 255, 0), rgb(0, 255, 0), rgb(0, 255, 128), rgb(0, 255, 255), rgb(0, 128, 255), rgb(0, 0, 255),rgb(128, 0, 255), rgb(255, 0, 255), rgb(255, 0, 128))
end

# Helper method for defining midi rgb
define :rgb do |r,g,b|
  [((127*r)/255),((127*g/255)),((127*b)/255)]
end

# Set single cell color as rgb
define :set_pad_rpg do |x, y, rgb|
  cell = (x.to_s+y.to_s).to_i
  values = [0x03, cell, *rgb]
  led_sysex values
end

# Set multiple cells
define :set_pad_colors_rpg do |arr, rgb|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x03, cell[:id], *rgb]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Set single cell color from predefined palette
define :set_cell_color do |cell|
  values = [0x00, (cell[:x].to_s+cell[:y].to_s).to_i, cell[:color]]
  led_sysex values
end

# Set single cell color from predefined palette
define :set_pad_color do |x, y, num|
  values = [0x00, (x.to_s+y.to_s).to_i, num]
  led_sysex values
end

# Set multiple cells
define :set_cell_colors do |arr, number|
  pad_colors = []
  arr.each do |row|
    row.each do |cell|
      cell_color = [0x00, cell[:id], number]
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

# Write your game settings here
define :start_game do
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  random_positions = []
  
  matching_pairs = [difficulty,6].min
  (2**matching_pairs).times do
    random_positions += (0..(64/(2**matching_pairs))-1).to_a
  end
  
  random_positions = random_positions.shuffle
  
  $board = (1..8).map {|x| (1..8).map {|y| pos = random_positions.pop; {id: ((9-x).to_s+y.to_s).to_i, x: 9-x, y: y, color: game_colors[pos], sound: game_sounds[pos], found: false }}} # Create new board
  set_cell_colors $board, 0 # Set color
  set :state, :relax
  set :game_over, false
  set :found, 0
  set :clicks, 0
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
      cue :push_event, type: :push, x: 8-x, y: y-1
      #sleep 0.25
      set :clicks, get(:clicks)+1
    else
      
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
live_loop :game do
  use_real_time
  event = sync :push_event
  game_over = get :game_over
  last_cell = get :last_cell
  
  if event
    x = event[:x]
    y = event[:y]
    cell = $board[x][y]
    
    if event[:type]==:push
      set_cell_color cell
      sample samples_folder, cell[:sound], attack: 0.1, sustain: 1.0, decay: 0.5, amp: 1.5, release: 0.1
      
      if !cell[:found] and last_cell and last_cell[:id] != cell[:id]
        if last_cell[:color] != cell[:color]
          cell_x = cell[:x]
          cell_y = cell[:y]
          in_thread do
            sleep 1
            set_pad_color cell_x, cell_y, 0
            set_pad_color last_cell[:x], last_cell[:y], 0
          end
        else
          $board[8-last_cell[:x]][last_cell[:y]-1][:found] = true
          cell[:found] = true
          total_found = get(:found)+1
          set :found, total_found
          print "FOUND: "+total_found.to_s
          set :game_over, true if total_found>31
        end
        cell = nil
      end
      
      if cell and cell[:found]
        print "Already found"
      else
        set :last_cell, cell
      end
      
    end
    
    if get :game_over
      set :state, :happy
      # Or sad
      in_thread do # In separate thread to enable sleeping
        if get :game_over # If new game hasnt started yet
          scroll_text (get :clicks).to_s+"", 1, 15, rgb(255,255,0)
          sleep 6
          start_game
        end
      end
    end
  end
end

# Set different scales for different states
relax = (scale :e, :gong).shuffle
happy = (scale :a4, :major_pentatonic).shuffle

live_loop :music do
  
  # Randomize seed and starting point
  use_random_seed = Time.now.to_i
  SecureRandom.random_number(1000).times { rand }
  
  state = get :state
  if state == :relax then
    
    n = rrand_i(0,number_of_samples)
    
    with_fx :echo, phase: rand, mix: rand do
      with_fx :reverb, room: rand, mix: rand do
        with_fx :panslicer, phase: rand, probability: 0.3, smooth: 0.1 do
          with_fx :autotuner do |c|
            sample samples_folder, n, amp: 0.1, beat_stretch: rrand_i(6,10), rate: rand(2.0)
            # now start changing note: to get robot voice behaviour
            control c, note: relax.tick
          end
        end
      end
    end
    sleep (sample_duration samples_folder,n)/rrand_i(1,16)
  end
  
  if state == :happy
    synth :chiplead, note: relax[tick]
    sleep 0.25
  end
  
  
  relax.shuffle if rand<0.1
end
