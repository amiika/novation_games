# Nyan cat animator for Novation Launchpad mini and Sonic Pi

# 1. Select color with controls from right
# 2. Paint frame
# 3. Create new frame from "Session"
# 4. Paint new frame or copy last frame using "Drums"
# 5. Navigate frames with left/right arrows
# 6. Start animation from "User"
# 7. Change animation speed from up/down arrows
# 8. Enjoy indefinetly or stop from "User" and start again

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
define :set_colors do |arr, rgb|
  pad_colors = []
  arr.each do |cell|
    cell_color = [0x03, cell, *rgb]
    pad_colors = pad_colors+cell_color
  end
  led_sysex pad_colors
end

# Set colors for the whole matrix
define :set_pad_colors do |matrix|
  pad_colors = []
  matrix.length.times do |x|
    row = matrix[x]
    row.length.times do |y|
      cell = matrix[x][y]
      cell_color = [0x00, ((matrix.length-x).to_s+(y+1).to_s).to_i, cell]
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

define :set_color_palette do
  palette = [0,3,5,13,23,37,45,95]
  set :palette, palette
  pads = [19,29,39,49,59,69,79,89]
  pad_colors = []
  pads.each.with_index do |c,i|
    pad_colors+=[0x00, c, *palette[i]]
  end
  led_sysex pad_colors
end

# Write your game settings here
define :start_game do
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  $board = Array.new(8) { Array.new(8) { 0 } } # Create new board
  $frames = [$board]
  set_pad_colors $board
  set_color_palette
  set :state, :relax
  set :game_over, false
  set :color, 3
  set :frame, 0
  set :sleep, 0.5
  set :loop, false
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
      # sleep 0.5
    else
      
    end
  elsif type=="control_change"
    
    if get_pad_status(19) and get_pad_status(91) then
      print "Starting new game"
      start_game # Start new game
    end
    if [19,29,39,49,59,69,79,89].include?(pad)
      p = get :palette
      set :color, p[x-1]
    end
    if touch==0
      set_pad_status pad, false
      if pad==94
        cue :push_event, type: :next_frame
      end
      if pad==93
        cue :push_event, type: :last_frame
      end
      if pad==91
        cue :push_event, type: :sleep, value: -0.05
      end
      if pad==92
        cue :push_event, type: :sleep, value: 0.05
      end
      if pad==95
        cue :push_event, type: :new
      end
      if pad==96
        cue :push_event, type: :copy
      end
      if pad==98
        cue :push_event, type: :loop
      end
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
  current_color = get :color
  
  if event
    x = event[:x]
    y = event[:y]
    
    if event[:type]==:sleep
      set :sleep, (get(:sleep)-event[:value]) if (get(:sleep)-event[:value])>0.05
      print "Sleep: "+(get :sleep).to_s
    end
    
    if event[:type]==:loop
      set :loop, !get(:loop)
      if get(:loop)
        print "Animating:"
        print $frames
      end
    end
    
    if event[:type]==:new
      $board =  Array.new(8) { Array.new(8) { 0 } } # Create new board
      set :frame, $frames.length
      $frames.push($board)
      set_pad_colors $board
    end
    
    if event[:type]==:copy and ($frames.length-2)>=0
      $board = Marshal.load(Marshal.dump($frames[$frames.length-2]))
      $frames[get(:frame)] = $board
      set_pad_colors $board
    end
    
    if event[:type]==:push
      # Get board value for this push
      $board = $frames[get :frame]
      cell_value = $board[x-1][y-1]
      # Do something
      $board[8-x][y-1] = current_color
      set_cell_color_from_palette x, y, current_color
    end
    
    if event[:type]==:next_frame and (get(:frame)+1)<$frames.length
      print "Frame: "+(get :frame).to_s
      set :frame, get(:frame)+1
      $board = $frames[get(:frame)]
      set_pad_colors $board
    end
    
    if event[:type]==:last_frame and (get(:frame)-1)>=0
      print "Frame: "+(get :frame).to_s
      set :frame, get(:frame)-1
      $board = $frames[get(:frame)]
      set_pad_colors $board
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
    # Or write any music. Here Nyan cat for the rainbow theme
    part1 = [[:ds5,0.125],[:e5,0.125],[:fs5,0.25],[:b5,0.25],[:ds5,0.125],[:e5,0.125],[:fs5,0.125],[:b5,0.125],[:cs6,0.125],[:ds6,0.125],[:cs6,0.125],[:as5,0.125],[:b5,0.25],[:fs5,0.25],[:ds5,0.125],[:e5,0.125],[:fs5,0.25],[:b5,0.25],[:cs6,0.125],[:as5,0.125],[:b5,0.125],[:cs6,0.125],[:e6,0.125],[:ds6,0.125],[:e6,0.125],[:cs6,0.125]]
    part2 = [[:fs5,0.25],[:gs5,0.25],[:ds5,0.125],[:ds5,0.25],[:b4,0.125],[:d5,0.125],[:cs5,0.125],[:b4,0.25],[:b4,0.25],[:cs5,0.25],[:d5,0.25],[:d5,0.125],[:cs5,0.125],[:b4,0.125],[:cs5,0.125],[:ds5,0.125],[:fs5,0.125],[:gs5,0.125],[:ds5,0.125],[:fs5,0.125],[:cs5,0.125],[:ds5,0.125],[:b4,0.125],[:cs5,0.125],[:b4,0.125],[:ds5,0.25],[:fs5,0.25],[:gs5,0.125],[:ds5,0.125],[:fs5,0.125],[:cs5,0.125],[:ds5,0.125],[:b4,0.125],[:d5,0.125],[:ds5,0.125],[:d5,0.125],[:cs5,0.125],[:b4,0.125],[:cs5,0.125],[:d5,0.25],[:b4,0.125],[:cs5,0.125],[:ds5,0.125],[:fs5,0.125],[:cs5,0.125],[:ds5,0.125],[:cs5,0.125],[:b4,0.125],[:cs5,0.25],[:b4,0.25],[:cs5,0.25]]
    part3 = [[:b4,0.25],[:fs4,0.125],[:gs4,0.125],[:b4,0.25],[:fs4,0.125],[:gs4,0.125]]
    part4 = [[:b4,0.125],[:cs5,0.125],[:ds5,0.125],[:b4,0.125],[:e5,0.125],[:ds5,0.125],[:e5,0.125],[:fs5,0.125],[:b4,0.25],[:b4,0.25],[:fs4,0.125],[:gs4,0.125],[:b4,0.125],[:fs4,0.125],[:e5,0.125],[:ds5,0.125],[:cs5,0.125],[:b4,0.125],[:fs4,0.125],[:ds4,0.125],[:e4,0.125],[:fs4,0.125]]
    part5 = [[:b4,0.125],[:b4,0.125],[:cs5,0.125],[:ds5,0.125],[:b4,0.125],[:fs4,0.125],[:gs4,0.125],[:fs4,0.125],[:b4,0.25],[:b4,0.125],[:as4,0.125],[:b4,0.125],[:fs4,0.125],[:gs4,0.125],[:b4,0.125],[:e5,0.125],[:ds5,0.125],[:e5,0.125],[:fs5,0.125],[:b4,0.25],[:as4,0.25]]
    parts = [part1,part2,part2,part3,part4,part3,part5,part3,part4,part3,part5]
    with_fx :reverb, room: 0.5 do
      parts.each do |part|
        part.each do |n|
          synth :blade, vibrato_delay: 0.05, attack: 0.1, release: 0.1, amp: 0.5, note: n[0]
          sleep n[1]
        end
      end
    end
  end
end

# Rainbow colors for the sides
live_loop :rainbow do |cells=[91,92,93,94,95,96,97,98,99]|
  pad_colors = []
  n = tick
  cells.each.with_index do |c,i|
    pad_colors+=[0x03, c, *rainbow_colors[n-i]]
  end
  led_sysex pad_colors
  sleep 0.1
end

live_loop :animation do
  loop = get :loop
  s = get :sleep
  if loop
    frame = tick % $frames.length
    set :frame, frame
    $board = $frames[frame]
    set_pad_colors $board
  end
  sleep s
end
