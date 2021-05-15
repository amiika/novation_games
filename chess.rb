use_debug false
use_midi_logging false
use_bpm 60

# Change here for your inputs and outputs. See Sonic Pi's Prefs/IO for ports.
launchpad_in = "/midi:midiin2_(lpminimk3_midi)_1:1/*"
launchpad_out = "midiout2_(lpminimk3_midi)_2"

# This is used mainly for setting how lights flash
midi_clock_beat 0.25, port: launchpad_out

# Set novation mini to programmer mode
define :set_programmer_mode do
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x01, 0xf7
end

# Light up multiple leds from novation launchpad
define :led_sysex do |values|
  midi_sysex 0xf0, 0x00, 0x20, 0x29, 0x02, 0x0d, 0x03, *values, 0xf7, port: launchpad_out
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

define :get_possible_moves do |cell|
  piece = cell[:piece]
  x = cell[:x]
  y = cell[:y]
  player = piece[:player]
  move_type = piece[:move_type]
  possible_moves = []
  if piece[:type] == :pawn
    p_pos = player==0 ? 1 : -1
    nx1 = x+1*p_pos
    yr =  y+1*p_pos
    yl = y-1*p_pos
    possible_moves << {type: :move, cell: $board[nx1][y]} if !$board[nx1][y][:piece] # Single step
    possible_moves << {type: :move, cell: $board[x+2*p_pos][y]} if ((player==0 and x==1) or (player==1 and x==6) and !$board[nx1][y][:piece]) # Double step
    pos_left = $board[nx1][yl] if yl>=0 # Attack
    pos_right = $board[nx1][yr]
    passant_left = $board[x][yl] if yl>=0 # En passant
    passant_right = $board[x][yr]
    possible_moves << {type: :attack, cell: pos_left} if pos_left and pos_left[:piece] and pos_left[:piece][:player] != player
    possible_moves << {type: :attack, cell: pos_right} if pos_right and pos_right[:piece] and pos_right[:piece][:player] != player
    possible_moves << {type: :passant, cell: pos_left, kill: passant_left} if pos_left and !pos_left[:piece] and passant_left and passant_left[:piece] and passant_left[:piece][:player] != player
    possible_moves << {type: :passant, cell: pos_right, kill: passant_right} if pos_right and !pos_right[:piece] and passant_right and passant_right[:piece] and passant_right[:piece][:player] != player
  else
    all_moves = piece[:moves]
    if move_type == :slide
      all_moves.each do |move|
        nx = x + move[0]
        ny = y + move[1]
        while true
          break if nx<0 or nx>7 or ny<0 or ny>7 or ($board[nx][ny][:piece] and $board[nx][ny][:piece][:player] == player)
          if ($board[nx][ny][:piece] and $board[nx][ny][:piece][:player] != player)
            possible_moves << {type: :attack, cell: $board[nx][ny]}
            break
          end
          possible_moves << {type: :move, cell: $board[nx][ny]}
          nx = nx + move[0]
          ny = ny + move[1]
        end
      end
    else
      all_moves.each do |move|
        nx = x + move[0]
        ny = y + move[1]
        if (nx>=0 and ny<=7 and nx<=7 and ny>=0)
          possible_moves << {type: :move, cell: $board[nx][ny]} if !$board[nx][ny][:piece]
          possible_moves << {type: :attack, cell: $board[nx][ny]} if ($board[nx][ny][:piece] and $board[nx][ny][:piece][:player] != player)
        end
      end
    end
  end
  if piece[:type] == :king # Castling rules
    print cell[:id]
    if cell[:id] == "e1" and ($board[0][0][:piece] and $board[0][0][:piece][:type] == :rook) and !$board[0][1][:piece] and !$board[0][2][:piece] and !$board[0][3][:piece]
      possible_moves << {type: :castle, cell: $board[0][1], rook_from: $board[0][0], rook_to: $board[0][2]}
    elsif cell[:id] == "e1" and ($board[0][7][:piece] and $board[0][7][:piece][:type] == :rook) and !$board[0][5][:piece] and !$board[0][6][:piece]
      possible_moves << {type: :castle, cell: $board[0][6], rook_from: $board[0][7], rook_to: $board[0][5]}
    elsif cell[:id] == "e8" and ($board[7][0][:piece] and $board[7][0][:piece][:type] == :rook) and !$board[7][1][:piece] and !$board[7][2][:piece] and !$board[7][3][:piece]
      possible_moves << {type: :castle, cell: $board[7][1], rook_from: $board[7][0], rook_to: $board[7][2]}
    elsif cell[:id] == "e8" and ($board[7][7][:piece] and $board[7][7][:piece][:type] == :rook) and !$board[7][5][:piece] and !$board[7][6][:piece]
      possible_moves << {type: :castle, cell: $board[7][6], rook_from: $board[7][7], rook_to: $board[7][5]}
    end
  end
  possible_moves
end

DIAGONALS = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
ORTHOGONALS = [[0, 1], [1, 0], [0, -1], [-1, 0]]
HOPS = [[-1, -2], [-2, -1], [-2, +1], [-1, +2], [+1, -2], [+2, -1], [+2, +1], [+1, +2]]

pieces = {
  :pawn => { type: :pawn, colors: [113,71], sample: :tabla_ghe1},
  :rook => { type: :rook, colors: [3,63], sample: :tabla_te_ne, move_type: :slide, moves: ORTHOGONALS},
  :knight => { type: :knight, colors: [37,127], sample: :tabla_te_ne, move_type: :step, moves: HOPS },
  :bishop => { type: :bishop, colors: [44, 121], sample: :tabla_re, move_type: :slide, moves: DIAGONALS },
  :queen => { type: :queen, colors: [54,5], sample: :tabla_na_s, move_type: :slide, moves: DIAGONALS+ORTHOGONALS },
  :king => { type: :king, colors: [45,13], sample: :tabla_ghe8, move_type: :step, moves: DIAGONALS+ORTHOGONALS }
}

select_sounds = [:mehackit_phone3,:mehackit_phone4,:mehackit_robot3,:glitch_perc2]
attack_sounds = [:mehackit_robot6,:mehackit_robot5]
move_sounds = [:mehackit_phone1,:mehackit_robot1,:mehackit_robot2,:mehackit_robot4]

define :set_up_board do |board|
  [1,6].each.with_index do |r,i|
    board[r].each do |cell|
      cell[:piece] = pieces[:pawn].dup
      cell[:piece][:player] = i
      cell[:color] = pieces[:pawn][:colors][i]
    end
  end
  line_1 = [:rook,:knight,:bishop,:queen,:king,:bishop,:knight,:rook]
  [0,7].each.with_index do |x,i|
    8.times do |y|
      player_piece = pieces[line_1[y]].dup
      player_piece[:player] = i
      board[x][y][:piece] = player_piece
      board[x][y][:color] = pieces[line_1[y]][:colors][i]
    end
  end
end

# Set multiple cells
define :set_board_colors do |board|
  pad_colors = []
  board.each do |row|
    row.each do |cell|
      cell_color = [0x00, cell[:pos], cell[:color]]
      pad_colors = pad_colors+cell_color
    end
  end
  led_sysex pad_colors
end

# Set single cell color from predefined palette
define :set_pad_color do |cell|
  values = [0x00, cell[:pos], cell[:color]]
  led_sysex values
end

define :set_colors do |arr,colors, type=0|
  pad_colors = []
  arr.each.with_index do |pos,i|
    cell_color = [type, pos, colors[i%colors.length]]
    pad_colors = pad_colors+cell_color
  end
  print pad_colors
  led_sysex pad_colors
end

define :start_game do
  set_programmer_mode
  $board = (1..8).map {|x| ('a'..'h').map.with_index {|y,i| { pos: (x.to_s+(i+1).to_s).to_i,id: (y+x.to_s), x: x-1, y: i, piece: nil, color: 0 }}}
  $history = []
  set_up_board $board
  set_board_colors $board
  set :turn, 0
  set :selected_pad, nil
  turn_cell = { pos: 99, color: pieces[:pawn][:colors][0]  }
  set_pad_color turn_cell
  set :wait_for_promote, nil
  set :game_over, false
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
  x = xy[0].to_i-1
  y = xy[1].to_i-1
  
  if type=="note_on"
    if touch==0 # Touch off
      cue :push, type: :pad_off, id: pad, x: x, y: y
      sleep 0.25
    else
      cue :push, type: :pad_on, id: pad, x: x, y: y
    end
  elsif type=="control_change"
    if get_pad_status(19) and get_pad_status(91) then
      print "Starting new game"
      start_game # Start new game
    end
    if touch==0
      cue :push, type: :c_off, id: pad, x: x, y: y
      set_pad_status pad, false
    else
      cue :push, type: :c_on, id: pad, x: x, y: y
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

# Set single cell flashing from color palette
define :set_cell_flash do |pos, c1, c2|
  values = [0x01, pos, c1, c2]
  led_sysex values
end

# Set single cell flashing from color palette
define :set_cell_pulse do |pos, color|
  values = [0x02, pos, color]
  led_sysex values
end

# Flash multiple cells from color palette
define :flash_cells do |cells, color|
  cells.each do |cell|
    player = get :turn
    piece = cell[:piece]
    if piece
      set_cell_flash cell[:pos], cell[:color], color
    else
      set_cell_pulse cell[:pos], color
    end
  end
end

define :remove_piece_from_cell do |cell|
  cell[:color] = 0
  cell[:piece] = nil
  set_pad_color cell
end

define :change_turn do |turn|
  next_turn = (turn+1)%2
  set :turn, next_turn
  turn_cell = { pos: 99, color: pieces[:pawn][:colors][next_turn]  }
  set_pad_color turn_cell
end

defonce :init_chess do
  start_game
end

# Start a new game
init_chess

live_loop :game do
  use_real_time
  event = sync :push
  selected_pad = get :selected_pad
  turn = get :turn
  promote = get :wait_for_promote
  game_over = get :game_over
  
  id = event[:id]
  x = event[:x]
  y = event[:y]
  
  if event and !game_over
    if event[:type]==:c_off
      if id==93
        last_state = $history.pop
        if last_state
          turn = last_state[:player]
          set :turn, turn
          selected_pad = nil
          set :selected_pad, nil
          $board = Marshal.load(last_state[:state])
          set_board_colors $board
        end
      end
      if promote
        options = {89=>:rook, 79=>:knight, 69=>:bishop, 59=>:queen}
        promote_to = options[id]
        if promote_to
          print "Promoting to "+promote_to.to_s
          new_type = pieces[promote_to].dup
          new_type[:player] = turn
          $board[promote[:x]][promote[:y]][:piece] = new_type
          $board[promote[:x]][promote[:y]][:color] = new_type[:colors][turn]
          set_pad_color $board[promote[:x]][promote[:y]]
          change_turn turn
          set :wait_for_promote, nil
          set_colors [89,79,69,59], [0]
        end
      end
    end
    if event[:type]==:pad_off and !promote
      pad = $board[x][y]
      if pad[:piece] and pad[:piece][:player]==turn
        if !selected_pad or pad[:id]!=selected_pad[:id]
          sample select_sounds.choose
          set :selected_pad, pad
          set_board_colors $board
          moves = get_possible_moves pad
          set :possible_moves, moves
          flash_cells moves.map {|c| c[:cell] }, pad[:color]
        else
          set :selected_pad, nil
          set_board_colors $board
        end
      elsif selected_pad and (!pad[:piece] or pad[:piece][:player]!=turn)
        moves = get :possible_moves
        moves_ids = moves.map {|c| c[:cell][:pos] }
        move_id = moves_ids.index(id)
        if move_id
          print selected_pad[:piece][:type].to_s+ " from "+selected_pad[:id].to_s+" to "+pad[:id].to_s
          s_x = selected_pad[:x]
          s_y = selected_pad[:y]
          move = moves[move_id]
          case move[:type]
          when :attack
            sample attack_sounds.choose, beat_stretch: rrand(1.0,2.0), amp: 0.5
            set :game_over, true if pad[:piece][:type]==:king
          when :passant
            sample attack_sounds.choose, beat_stretch: rrand(1.0,2.0), amp: 0.5
            kill = move[:kill]
            remove_piece_from_cell $board[kill[:x]][kill[:y]]
          when :move
            sample move_sounds.choose
          when :castle
            remove_piece_from_cell $board[move[:rook_from][:x]][move[:rook_from][:y]]
            $board[move[:rook_to][:x]][move[:rook_to][:y]][:piece] = move[:rook_from][:piece]
            $board[move[:rook_to][:x]][move[:rook_to][:y]][:color] = move[:rook_from][:color]
            set_pad_color $board[x][y]
          end
          
          set_board_colors $board # Remove all flashing cells etc.
          $history.push({player: turn, move: [selected_pad[:id],pad[:id]], state: Marshal.dump($board) })
          $board[x][y][:piece] = $board[s_x][s_y][:piece] # Move piece
          $board[x][y][:color] = $board[s_x][s_y][:color] # Change cell color from board
          remove_piece_from_cell $board[s_x][s_y] # Remove old piece
          set_pad_color $board[x][y] # Set new cell color
          
          if selected_pad[:piece][:type] == :pawn and (pad[:x] == 0 or pad[:x] == 7)
            set :wait_for_promote, $board[x][y] # Pawn promotion
            set_colors [89,79,69,59], [pieces[:rook][:colors][turn],pieces[:knight][:colors][turn],pieces[:bishop][:colors][turn],pieces[:queen][:colors][turn]], 2
            print "Waiting for promotion"
          else
            set :selected_pad, nil # Change turn
            change_turn turn
          end
          
        else
          print "Illegal move"
          set :selected_pad, nil
          set_board_colors $board
        end
      elsif !selected_pad
        if pad[:piece]
          print "Inspecting enemy moves"
          enemy_moves = get_possible_moves pad
          set_board_colors $board
          flash_cells enemy_moves.map {|c| c[:cell] }, pad[:color]
        else
          set :selected_pad, nil
          set_board_colors $board
        end
      end
    end
  end
end

live_loop :music do
  game_over = get :game_over
  if game_over
    sample :ambi_glass_hum, pitch: (scale :C1, :minor)[tick] - note((ring :C1, :C3, :C2)[look]), attack: 0.5, sustain: 3.0, decay: 1.0
    sleep 2.0
  else
    boardt = $board.transpose
    boardt.each do |row|
      row.each do |cell|
        if cell[:piece]
          piece = cell[:piece]
          with_fx :ring_mod, freq: rrand_i(1,60), mod_amp: rand, amp: 0.5 do
            sample (get :game_over) ? attack_sounds.choose : piece[:sample]
          end
          sleep 0.25
        end
      end
    end
  end
end