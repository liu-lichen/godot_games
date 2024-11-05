extends Node

enum MapCellState {IDLE, WALL, SNAKE_HEAD, SNAKE_BODY, FOOD}
enum SnakeMoveDirection {UP, DOWN, LEFT, RIGHT}
enum GameState {IDLE, START, SUCCESS, FAILURE}

@warning_ignore("integer_division")
const SNAKE_HEAD_INIT_COORD_X: int = Configs.MAP_CELL_SIZE_X / 2
@warning_ignore("integer_division")
const SNAKE_HEAD_INIT_COORD_Y: int = Configs.MAP_CELL_SIZE_Y / 2
const SNAKE_DEFAULT_MOVE_DIR: SnakeMoveDirection = SnakeMoveDirection.RIGHT

@export var snake_head_scene_: PackedScene = null
@export var snake_body_scene_: PackedScene = null
@export var snake_move_timer_: Timer = null
@export var snake_nodes_: Node2D = null
@export var food_scene_: PackedScene = null
@export var result_panel_: Node = null
@export var result_panel_text_: Node = null
var cell_data_: Array = []
var snake_head_: Node2D = null
var snake_bodies_: Array[Node2D] = []
var snake_cur_move_dir_: SnakeMoveDirection = SNAKE_DEFAULT_MOVE_DIR
var snake_next_move_dir_: SnakeMoveDirection = SNAKE_DEFAULT_MOVE_DIR
var food_: Node2D = null
var game_state_: GameState = GameState.IDLE

# Called when the node enters the scene tree for the first time
func _ready() -> void:
  update_game_state(GameState.IDLE)

# Called during the physics processing step of the main loop
func _physics_process(_delta: float) -> void:
  if Input.get_action_strength(Configs.ACTION_SNAKE_LEFT):
    snake_next_move_dir_ = SnakeMoveDirection.LEFT
  elif Input.get_action_strength(Configs.ACTION_SNAKE_RIGHT):
    snake_next_move_dir_ = SnakeMoveDirection.RIGHT
  elif Input.get_action_strength(Configs.ACTION_SNAKE_UP):
    snake_next_move_dir_ = SnakeMoveDirection.UP
  elif Input.get_action_strength(Configs.ACTION_SNAKE_DOWN):
    snake_next_move_dir_ = SnakeMoveDirection.DOWN

# Snake move timer timeout event
func _on_snake_move_timer_timeout() -> void:
  if game_state_ != GameState.START:
    return
  # If next direction is opposite to current, ignore it
  if not check_next_move_dir_valid():
    # Restore the next move direction
    snake_next_move_dir_ = snake_cur_move_dir_
  else:
    snake_cur_move_dir_ = snake_next_move_dir_
  var cur_coord: Vector2i = calc_coord_from_pos(snake_head_.position)
  var next_coord: Vector2i = calc_next_coord(cur_coord)
  if not check_coord_valid(next_coord):
    update_game_state(GameState.FAILURE)
    return
  if check_coord_has_food(next_coord):
    refresh_food_node()
    add_new_body_node(cur_coord)
  else:
    # Move the tail snake body node to right after head node
    move_snake_tail_node(cur_coord)
  move_snake_head_node(next_coord)

func _on_start_button__button_down() -> void:
  update_game_state(GameState.START)

# Initialize the state of map cells
func init_map_cell_state() -> void:
  cell_data_.clear()
  for x in range(0, Configs.MAP_CELL_SIZE_X):
    var column_data: Array = []
    column_data.push_back(MapCellState.WALL)
    for y in range(1, Configs.MAP_CELL_SIZE_Y - 1):
      if x == 0 or x == Configs.MAP_CELL_SIZE_X - 1:
        column_data.push_back(MapCellState.WALL)
      else:
        column_data.push_back(MapCellState.IDLE)
    column_data.push_back(MapCellState.WALL)
    cell_data_.push_back(column_data)

# Initialize the snake head and bodies
func init_snake_node() -> void:
  if not is_instance_valid(snake_head_):
    snake_head_ = snake_head_scene_.instantiate()
    snake_nodes_.add_child(snake_head_)
  move_snake_head_node(Vector2i(SNAKE_HEAD_INIT_COORD_X, SNAKE_HEAD_INIT_COORD_Y))
  # Remove all snake body nodes that were added in previous game
  for body in snake_bodies_:
    snake_nodes_.remove_child(body)
  snake_bodies_.clear()
  # Then add the initial body nodes
  for i in Configs.SNAKE_BODY_INIT_LENGTH:
    add_body_to_tail(Vector2i(SNAKE_HEAD_INIT_COORD_X - i - 1, SNAKE_HEAD_INIT_COORD_Y))

# Initialize or refresh the food node at a random position
func refresh_food_node() -> void:
  # Get all the idle map cell
  var idle_cells: Array[Vector2i] = []
  for x in range(1, Configs.MAP_CELL_SIZE_X - 1):
    for y in range(1, Configs.MAP_CELL_SIZE_Y - 1):
      if cell_data_[x][y] == MapCellState.IDLE:
        idle_cells.push_back(Vector2i(x, y))
  if idle_cells.size() == 0:
    update_game_state(GameState.SUCCESS)
  # Get a random coordinate from the idle cells
  var rand_index: int = randi_range(0, idle_cells.size() - 1)
  var next_coord: Vector2i = idle_cells[rand_index]
  if not is_instance_valid(food_):
    food_ = food_scene_.instantiate()
    add_child(food_)
  else:
    var cur_coord: Vector2i = calc_coord_from_pos(food_.position)
    cell_data_[cur_coord.x][cur_coord.y] = MapCellState.IDLE
  food_.position = calc_pos_from_coord(next_coord)
  cell_data_[next_coord.x][next_coord.y] = MapCellState.FOOD

# Move the snake head node to the next coordinate
func move_snake_head_node(next_coord: Vector2i) -> void:
  snake_head_.position = calc_pos_from_coord(next_coord)
  cell_data_[next_coord.x][next_coord.y] = MapCellState.SNAKE_HEAD

# Move the snake tail node to the place that right after the head node
func move_snake_tail_node(next_coord: Vector2i) -> void:
  var snake_tail: Node2D = snake_bodies_.pop_back()
  var cur_coord = calc_coord_from_pos(snake_tail.position)
  snake_tail.position = calc_pos_from_coord(next_coord)
  snake_bodies_.push_front(snake_tail)
  cell_data_[cur_coord.x][cur_coord.y] = MapCellState.IDLE
  cell_data_[next_coord.x][next_coord.y] = MapCellState.SNAKE_BODY

# Add a new snake body node right after the head node
func add_new_body_node(coord: Vector2i) -> void:
  var snake_body: Node2D = snake_body_scene_.instantiate()
  snake_body.position = calc_pos_from_coord(coord)
  snake_bodies_.push_front(snake_body)
  snake_nodes_.add_child(snake_body)
  cell_data_[coord.x][coord.y] = MapCellState.SNAKE_BODY
  if snake_bodies_.size() >= Configs.SNAKE_BODY_MAX_LENGTH:
    update_game_state(GameState.SUCCESS)

# Update the game state, show or hide the result panel and update the label on it
func update_game_state(state: GameState) -> void:
  game_state_ = state
  match game_state_:
    GameState.IDLE:
      snake_move_timer_.stop()
      result_panel_text_.text = Configs.GAME_START_IDLE
      result_panel_.show()
    GameState.START:
      reset_game_scene()
      snake_move_timer_.start()
      result_panel_.hide()
    GameState.SUCCESS:
      reset_game_scene()
      snake_move_timer_.stop()
      result_panel_text_.text = Configs.GAME_END_SUCCESS
      result_panel_.show()
    GameState.FAILURE:
      reset_game_scene()
      init_snake_node()
      snake_move_timer_.stop()
      result_panel_text_.text = Configs.GAME_END_FAILURE
      result_panel_.show()
    _:
      pass

# Reset the game scene to idle
func reset_game_scene() -> void:
  init_map_cell_state()
  init_snake_node()
  refresh_food_node()
  snake_cur_move_dir_ = SNAKE_DEFAULT_MOVE_DIR
  snake_next_move_dir_ = SNAKE_DEFAULT_MOVE_DIR

# Calculate the position from coordinate
func calc_pos_from_coord(coord: Vector2i) -> Vector2:
  var pos_x: float = Configs.MAP_CELL_WIDTH * coord.x
  var pos_y: float = Configs.MAP_CELL_WIDTH * coord.y
  return Vector2(pos_x, pos_y)

# Calculate the coordinate from position
func calc_coord_from_pos(pos: Vector2) -> Vector2i:
  var coord_x: int = int(pos.x / Configs.WALL_WIDTH)
  var coord_y: int = int(pos.y / Configs.WALL_WIDTH)
  return Vector2i(coord_x, coord_y)

# Calculate the next coordinate by current coordinate and direction
func calc_next_coord(coord: Vector2i) -> Vector2i:
  match (snake_cur_move_dir_):
    SnakeMoveDirection.UP:
      coord.y -= 1
    SnakeMoveDirection.DOWN:
      coord.y += 1
    SnakeMoveDirection.LEFT:
      coord.x -= 1
    SnakeMoveDirection.RIGHT:
      coord.x += 1
    _:
      pass
  return coord

# Check if the next move direction is valid or not
func check_next_move_dir_valid() -> bool:
  if snake_cur_move_dir_ == SnakeMoveDirection.LEFT && snake_next_move_dir_ == SnakeMoveDirection.RIGHT:
    return false
  if snake_cur_move_dir_ == SnakeMoveDirection.RIGHT && snake_next_move_dir_ == SnakeMoveDirection.LEFT:
    return false
  if snake_cur_move_dir_ == SnakeMoveDirection.UP && snake_next_move_dir_ == SnakeMoveDirection.DOWN:
    return false
  if snake_cur_move_dir_ == SnakeMoveDirection.DOWN && snake_next_move_dir_ == SnakeMoveDirection.UP:
    return false
  return true

# Check if the coordinate is valid or not
func check_coord_valid(coord: Vector2i) -> bool:
  if coord.x < 0 || coord.x >= Configs.MAP_CELL_SIZE_X:
    return false
  if coord.y < 0 || coord.y >= Configs.MAP_CELL_SIZE_Y:
    return false
  if cell_data_[coord.x][coord.y] == MapCellState.WALL:
    return false
  if cell_data_[coord.x][coord.y] == MapCellState.SNAKE_BODY:
    return false
  if cell_data_[coord.x][coord.y] == MapCellState.SNAKE_HEAD:
    return false
  return true

# Check if the coordinate has food on it
func check_coord_has_food(coord: Vector2i) -> bool:
  return cell_data_[coord.x][coord.y] == MapCellState.FOOD

# Append a new snake body to the tail
func add_body_to_tail(coord: Vector2i) -> void:
  var snake_body: Node2D = snake_body_scene_.instantiate()
  snake_body.position = calc_pos_from_coord(coord)
  snake_bodies_.push_back(snake_body)
  snake_nodes_.add_child(snake_body)

func get_snake_length() -> int:
  return snake_bodies_.size()

# Get the tail node of snake
func get_tail_node() -> Node2D:
  if get_snake_length() == 0:
    return snake_head_
  return snake_bodies_.back()
