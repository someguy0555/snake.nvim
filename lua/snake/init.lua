---@class M
local M = {}

---@class WindowInfo Information that is important to the window.
--- Exists to group together common information.
---@field x_size integer Actual width in spaces
---@field y_size integer Actual height in spaces
---@field x_offset integer
---@field y_offset integer
---@field buf number Name (a numeric value) of a buffer.
---@field window number Window that is supposed to display 'Snake'
---@field is_closed boolean Whether the window is closed or not
---@field snake_info SnakeInfo Contains information pertaining to game logic. Local to the current window.

---@class SnakeInfo Contains information pertaining to game logic.
---@field is_over boolean Is the game over? (Currently, only ever becomes true when the snake collides with itself)
---@field snake Snake
---@field food Vec2D
---@field direction Direction 
---@field width integer The amount of tiles on the x axis the board has (different form WindowInfo.x_size).
---@field height integer The amount of tiles on the y axis the board has (different from WindowInfo.y_size).

---@class Vec2D Used to contain tile coordinates
---@field x integer
---@field y integer

---@class Snake Contains coordinates for all the snake parts
---@field body Vec2D[]
---@field size integer
local Snake = {}
Snake.__index = Snake

---@param head Vec2D
function Snake.new(head)
    local self = setmetatable({}, Snake)
    self.body = { head }
    self.size = 1
    return self
end
---@return Snake

-- function Snake:get_size()
--    return self.size
-- end
-- ---@return integer
--
-- function Snake:get_body()
--    return self.body
-- end
-- ---@return Vec2D[]

---@param pos Vec2D
function Snake:is_colliding(pos)
    for _, ipos in pairs(self.body) do
        if ipos.x == pos.x and ipos.y == pos.y then
            return true
        end
    end
    return false
end
---@return boolean

function Snake:is_colliding_with_head()
    ---@type Vec2D
    local head = self.body[1]
    for key, pos in pairs(self.body) do
        if key > 1 and pos.x == head.x and pos.y == head.y then
            return true
        end
    end

    return false
end
---@return boolean

local Direction = {
    UP = 0,
    DOWN = 1,
    RIGHT = 2,
    LEFT = 3,
} -- Should be used with direction alias.
---@alias Direction 0|1|2|3


--- Function that returns a new food position.
--- This implementation is ASS, plz fix later
---@param snake Snake
---@param width number
---@param height number
local function place_food(snake, width, height)
    if snake.size >= width * height then
        return nil -- grid is full
    end

    local pos
    repeat
        local rand = math.random(0, width * height - 1)
        local x = (rand % width) + 1
        local y = math.floor(rand / width) + 1
        pos = { x = x, y = y }
    -- until not tile_occupied_by_snake(snake, pos)
    until not snake:is_colliding(pos)

    return pos
end
---@return Vec2D?

---@param sinfo SnakeInfo
---@param buf number
local function print_snake(sinfo, buf)
    local lines = {}
    for i = 1, sinfo.height, 1 do
        local line = {}
        for j = 1, sinfo.width do
            if sinfo.snake:is_colliding({ x = j, y = i }) then
                table.insert(line, "██")
                -- table.insert(line, 'S')
            elseif sinfo.food.x == j and sinfo.food.y == i then
                table.insert(line, "░░")
                -- table.insert(line, 'F')
            else
                table.insert(line, "  ")
            end
        end
        table.insert(lines, table.concat(line))
    end

    vim.schedule(
        function()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        end
    )
end

---@param sinfo SnakeInfo
local function move_snake_by_one(sinfo)
    --@type Vec2D
    local head = { x = sinfo.snake.body[1].x, y = sinfo.snake.body[1].y }

    if     sinfo.direction == Direction.UP    then head.y = head.y - 1
    elseif sinfo.direction == Direction.DOWN  then head.y = head.y + 1
    elseif sinfo.direction == Direction.RIGHT then head.x = head.x + 1
    elseif sinfo.direction == Direction.LEFT  then head.x = head.x - 1
    else assert(false) end

    ---@type function
    ---@param n number
    ---@param max number
    local function wrap(n, max)
        return ((n - 1) % max) + 1
    end
    ---@return number

    head.x = wrap(head.x, sinfo.width)
    head.y = wrap(head.y, sinfo.height)

    ---@type Snake
    local new_snake = Snake.new(head)
    new_snake.size = sinfo.snake.size + 1

    for i, pos in pairs(sinfo.snake.body) do
        new_snake.body[i + 1] = pos
    end

    if head.x ~= sinfo.food.x or head.y ~= sinfo.food.y then
        new_snake.body[new_snake.size] = nil
        new_snake.size = new_snake.size - 1
    end

    return new_snake
end
---@return Snake

---@type boolean
local instance_already_exists = false

---@param winfo WindowInfo
local function run_snake(winfo)
    assert(winfo.buf ~= 0)
    assert(winfo.window ~= 0)

    ---@type uv_timer_t
    local game_timer = vim.uv.new_timer()
    ---@type integer
    local pause_interval = 120 -- milliseconds
    ---@type SnakeInfo
    local sinfo = winfo.snake_info

    ---@type function
    local function cleanup()
        vim.schedule(
            function()
                vim.api.nvim_buf_delete(winfo.buf, { force = true })
                -- vim.api.nvim_win_close(winfo.window, true) -- Apparently, you don't need this?
            end
        )
    end

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        callback = function(args)
            if args.event == "WinClosed" and tonumber(args.match) == winfo.window then
                winfo.is_closed = true
                -- instance_already_exists = false
                winfo.snake_info.is_over = true
                instance_already_exists = false
                return true
            end
        end,
    })
    vim.api.nvim_set_current_win(winfo.window)

    -- *****************************************
    -- Setting movement keymaps for each buffer
    -- *****************************************

    vim.keymap.set('n', 'h', function()
        if sinfo.direction ~= Direction.RIGHT or sinfo.snake.size == 1 then
            sinfo.direction = Direction.LEFT
        end
    end, { buffer = winfo.buf })

    vim.keymap.set('n', 'j', function()
        if sinfo.direction ~= Direction.UP or sinfo.snake.size == 1 then
            sinfo.direction = Direction.DOWN
        end
    end, { buffer = winfo.buf })

    vim.keymap.set('n', 'k', function()
        if sinfo.direction ~= Direction.DOWN or sinfo.snake.size == 1 then
            sinfo.direction = Direction.UP
        end
    end, { buffer = winfo.buf })

    vim.keymap.set('n', 'l', function()
        if sinfo.direction ~= Direction.LEFT or sinfo.snake.size == 1 then
            sinfo.direction = Direction.RIGHT
        end
    end, { buffer = winfo.buf })


    -- ---@type integer
    -- local iteration = 0 -- Debug variable

    local function game_tick()
        -- iteration = iteration + 1
        print("X: " .. sinfo.snake.body[1].x .. "; Y: " .. sinfo.snake.body[1].y .. "; Score: " .. sinfo.snake.size)

        if sinfo.is_over then
            cleanup()
            game_timer:stop()
            game_timer:close()
            return
        else
            local prev_size = sinfo.snake.size

            sinfo.snake = move_snake_by_one(sinfo)

            if sinfo.snake:is_colliding_with_head() then
                sinfo.is_over = true
            end

            if sinfo.snake.size ~= prev_size then -- Snake ate food
                local tmp_food = place_food(sinfo.snake, sinfo.width, sinfo.height)
                assert(tmp_food ~= nil)
                sinfo.food = tmp_food
            end -- Snake didn't eat anything
            print_snake(sinfo, winfo.buf)
        end
    end

    local tmp_food = place_food(sinfo.snake, sinfo.width, sinfo.height)
    assert(tmp_food ~= nil)
    sinfo.food = tmp_food

    game_timer:start(0, pause_interval, game_tick)
end

local function init_snake()
    ---@type WindowInfo
    local winfo = {
        x_size = math.floor(vim.o.columns / 2),
        y_size = math.floor(vim.o.lines / 2),
        x_offset = math.floor((vim.o.columns) / 4),
        y_offset = math.floor((vim.o.lines ) / 4),
        window = 0,
        buf = 0,
        is_closed = false,
        snake_info = { -- Default behaviours
            is_over = false,
            snake = Snake.new({ x = 1, y = 1 }),
            food = { x = 4, y = 5 }, -- Place holder value, should probably be set randomly every time.
            direction = Direction.RIGHT,
            width = math.floor(vim.o.columns / 4),
            height = math.floor(vim.o.lines / 2)
        }
    }

    -- print("width: " .. winfo.snake_info.width)
    -- print("height: " .. winfo.snake_info.height)

    -- assert(not (winfo.snake_info.width < 15 or winfo.snake_info.height < 20))

    winfo.buf = vim.api.nvim_create_buf(false, true)  -- Create a scratch buffer
    assert(winfo.buf ~= 0)

    winfo.window = vim.api.nvim_open_win(winfo.buf, false,
        {
            relative='win',
            row=winfo.y_offset,
            col=winfo.x_offset,
            width=winfo.x_size,
            height=winfo.y_size,
            style='minimal',
            border='single'
        }
    )
    assert(winfo.window ~= 0)

    run_snake(winfo)
end

M.setup = function ()
    vim.api.nvim_create_user_command("Snake", function ()
       if not instance_already_exists then
           instance_already_exists = true
           init_snake()
       end
    end, {})
end

return M
