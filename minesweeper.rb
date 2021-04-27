# Sonic Mines - Minesweeper for Sonic Pi
# Created for Novation Launchpad Mini Mk3

use_debug false
use_midi_logging false

# Randomize seed and starting point
use_random_seed = Time.now.to_i
SecureRandom.random_number(1000).times { rand }

# Midi ports for the launchpad
launchpad_in = "/midi:midiin2_(lpminimk3_midi)_1:1/*"
launchpad_out = "midiout2_(lpminimk3_midi)_2"

midi_clock_beat 0.5, port: launchpad_out

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

# Rainbow colors for the sides
live_loop :rainbow do
  rainbows = (ring rgb(255, 0, 0), rgb(255, 128, 0), rgb(255, 255, 0), rgb(128, 255, 0), rgb(0, 255, 0), rgb(0, 255, 128), rgb(0, 255, 255), rgb(0, 128, 255), rgb(0, 0, 255),rgb(128, 0, 255), rgb(255, 0, 255), rgb(255, 0, 128))
  cells = [91,92,93,94,95,96,97,98,89,79,69,59,49,39,29,19]
  pad_colors = []
  n = tick
  cells.each.with_index do |c,i|
    pad_colors+=[0x03, c, *rainbows[n-i]]
  end
  led_sysex pad_colors
  sleep 0.1
end

# Set single cell flashing
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

# Set single cell color
define :set_cell_color do |x, y, rgb|
  cell = (x.to_s+y.to_s).to_i
  values = [0x03, cell, *rgb]
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

# Creates rgb from probability based on the color scheme
define :prob_to_color do |prob|
  
  # Coloring scheme for propabilities
  colors = [
    rgb(255,0,0),
    rgb(255,0,255),
    rgb(55,55,55)
  ]
  
  index = colors.index.with_index do |col,i|
    prob <= i.to_f/(colors.length-1)
  end
  
  lower = colors[index-1]
  upper = colors[index]
  upperProb = index.to_f/(colors.length-1)
  lowerProb = (index-1).to_f/(colors.length-1)
  u = (prob - lowerProb) / (upperProb - lowerProb)
  l = 1 - u
  [(lower[0]*l + upper[0]*u).to_i, (lower[1]*l + upper[1]*u).to_i, (lower[2]*l + upper[2]*u).to_i].map {|color| ((127*color)/255) }
end

define :set_neighbor_colors do |matrix, x, y|
  n = []
  
  (x-1).upto(x+1) do |a|
    (y-1).upto(y+1) do |b|
      n.push([a,b]) if !(a==x and b==y) and matrix[a] and matrix[a][b]
    end
  end
  
  #TODO: Color neighbors based on lowest value or something
  #l = n.min {|a,b| matrix[a[0]][a[1]][:value] <=> matrix[b[0]][b[1]][:value] }
  #lowest = matrix[l[0]][l[1]][:value] if l
  
  n.each do |xy|
    prob = matrix[xy[0]][xy[1]][:value]
    set_cell_color xy[0]+1, xy[1]+1, prob_to_color(prob) if prob
  end
  
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

# Explode mine
define :explode do |x,y|
  sample :ambi_choir, attack: 1.5, decay: 3.0, beat_stretch: 4
  sample :misc_cineboom, start: 0.2
  sample :vinyl_rewind
  set_cell_flash x, y, 72, 6
end

# Evade mine
define :evade do |x,y|
  sample :guit_harmonics, amp: 3
  sample :mehackit_robot3
  set_cell_color x, y, rgb(0,255,0)
  set_neighbor_colors $game[:board], x-1, y-1
end

define :start_game do
  # Change this to make game harder
  chance_to_explode = 0.15
  # Init new game
  stop_text # Stop texts if running
  set_programmer_mode # Set programmer mode
  board = (1..8).map {|x| (1..8).map {|y| {x: x, y: y, value: rand}}} # Create new board
  set_pad_colors board, rgb(0,0,0) # Set color
  set_colors_from_palette [91,92,93,94,95,96,97,98,89,79,69,59,49,39,29,19], 45
  set :state, :relax
  set :game_over, false
  mines = board.map{|row| row.select {|x| x[:value]<0.15 }}.flatten
  new_game = {board: board, hits: 0, explode_prob: chance_to_explode, hits_to_win: 64-mines.length, mines: mines }
  new_game
end

# Start a new game
$game = start_game

# Thread for listening events from the novation launchpad
live_loop :sonicmines do
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
    cell_prob = $game[:board][x-1][y-1][:value]
    if touch==0 # Touch off
      if cell_prob # Visited cell
        if cell_prob < $game[:explode_prob]
          cue :game_event, type: :explosion, x: x, y: y
        else
          cue :game_event, type: :evade, x: x, y: y
        end
      end
    else # Touch on
      if cell_prob
        set_cell_flash x, y, 18, 5
        set :state, :exited
      end
    end
  elsif type=="control_change"
    if get_pad_status(19) and get_pad_status(91) and
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
live_loop :check_events do
  use_real_time
  
  event = sync :game_event # Get game event
  x = event[:x]
  y = event[:y]
  
  game_over = get :game_over
  
  if !game_over then
    
    in_thread do
      sleep 2 # Exitement
      
      if event[:type] == :explosion then
        explode x, y
        set :game_over, true
        flash_cells $game[:mines], 72, 6
        sleep 3
        if get(:game_over) then # If new game hasnt started yet
          scroll_text "BOOM !", 1, 15, rgb(178,34,34)
          sleep 3
          $game = start_game
        end
      else
        
        evade x, y
        $game[:hits]+=1
        $game[:board][x-1][y-1][:value] = nil # Add visit to matrix
        
        if $game[:hits]>=$game[:hits_to_win] then
          game_over = true
          set :state, :happy
          sleep 3
          if (get :game_over) then
            scroll_text "WINNER! \^.^/", 1, 15, rgb(255,255,0)
            sleep 3
            $game = start_game
          end
        else
          print "Hits remaining: "+($game[:hits_to_win]-$game[:hits]).to_s
          set :state, :relax
        end
        
      end
    end
  end
  
end

exited = (ring 75,76,77,76)
relax = (scale :a3, :gong).shuffle
happy = (scale :a4, :major_pentatonic).shuffle
sad = (scale :a3, :acem_asiran).shuffle

# Thread for creating exiting music from the game state
live_loop :music do
  state = get(:state)
  tick
  synth :dull_bell, note: exited.look if state==:exited
  synth :pretty_bell, amp: 0.5, note: relax.look if state==:relax
  synth :chiplead, note: happy.look if state==:happy
  synth :dark_ambience, note: sad.look if state==:explosion
  sample :drum_heavy_kick if spread(1,4).look
  sample :drum_tom_hi_soft, amp: 0.5 if spread(4,23).rotate(1).look
  sample :glitch_perc3, amp: 0.5 if spread(1,36).rotate(-6).look
  sample :elec_pop, amp: 0.5 if spread(1, 16).rotate(3).look
  sleep 0.25
  if rand>0.5
    relax = relax.shuffle
    happy = happy.shuffle
    sad = sad.shuffle
  end
end
