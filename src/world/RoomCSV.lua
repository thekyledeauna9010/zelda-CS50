--[[
    GD50
    Legend of Zelda

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

RoomCSV = Class{}

function RoomCSV:init(player, room)
    MAP_WIDTH = 20
    MAP_HEIGHT = 10

    MAP_RENDER_OFFSET_X = 32
    MAP_RENDER_OFFSET_Y = 28

    MAP_COLLISION_OFFSET = 3

    self.width = MAP_WIDTH
    self.height = MAP_HEIGHT

    self.tiles = {}
    self.objects = {}
    self.entities = {}

    self:generateWallsAndFloors(room)

    -- entities in the room
    self:generateEntities(room)

    -- game objects in the room
    self.switchesCount = 0
    self:generateObjects(room)

    -- doorways that lead to other dungeon rooms
    self.doorways = {}
    table.insert(self.doorways, Doorway('top', false, self))
    table.insert(self.doorways, Doorway('bottom', false, self))
    table.insert(self.doorways, Doorway('left', false, self))
    table.insert(self.doorways, Doorway('right', false, self))

    -- reference to player for collisions, etc.
    self.player = player
    self:initPlayerCoordinates(room)

    -- used for centering the dungeon rendering
    self.renderOffsetX = MAP_RENDER_OFFSET_X
    self.renderOffsetY = MAP_RENDER_OFFSET_Y

    -- used for drawing when this room is the next room, adjacent to the active
    self.adjacentOffsetX = 0
    self.adjacentOffsetY = 0

    self.player:goInvulnerable(1.5)

    self.projectiles = {}
end

--[[
    Randomly creates an assortment of enemies for the player to fight.
]]
function RoomCSV:generateEntities(room)

    for y = 2, self.height-1 do
        for x = 2, self.width-1 do
            if room[y][x] == CSV_SKELETON then
                self:generateEntity('skeleton', x ,y)
            elseif room[y][x] == CSV_GHOST then
                self:generateEntity('ghost', x ,y)
            elseif room[y][x] == CSV_SLIME then
                self:generateEntity('slime', x ,y)
            end

        end
    end
end

function RoomCSV:generateEntity(type, x ,y)

    local entity = Entity {
        animations = ENTITY_DEFS[type].animations,
        walkSpeed = ENTITY_DEFS[type].walkSpeed or 20,

        -- ensure X and Y are within bounds of the map
        x = MAP_RENDER_OFFSET_X + x*TILE_SIZE - TILE_SIZE,
        y = MAP_RENDER_OFFSET_Y + y*TILE_SIZE - TILE_SIZE,
        
        width = 16,
        height = 16,

        health = 1
    }

    table.insert(self.entities, entity)

    entity.stateMachine = StateMachine {
        ['walk'] = function() return EntityWalkState(entity, self) end,
        ['idle'] = function() return EntityIdleState(entity, self) end
    }

    entity:changeState('walk')
end

--[[
    Randomly creates an assortment of obstacles for the player to navigate around.
]]
function RoomCSV:generateObjects(room)

    for y = 2, self.height-1 do
        for x = 2, self.width-1 do
            if room[y][x] == CSV_SWITCH and self.switchesCount < 1 then
                local switch = GameObject(
                    GAME_OBJECT_DEFS['switch'],
                    MAP_RENDER_OFFSET_X + x*TILE_SIZE - TILE_SIZE,
                    MAP_RENDER_OFFSET_Y + y*TILE_SIZE - TILE_SIZE
                )

                -- define a function for the switch that will open all doors in the room
                switch.onCollide = function()
                    if switch.state == 'unpressed' then
                        switch.state = 'pressed'
                        
                        -- open every door in the room if we press the switch
                        for k, doorway in pairs(self.doorways) do
                            doorway.open = true
                        end

                        gSounds['door']:play()
                    end
                end

                table.insert(self.objects, switch)

                self.switchesCount = self.switchesCount + 1

            elseif room[y][x] == CSV_POT then
                local pot = GameObjectThrowable(
                    GAME_OBJECT_DEFS['pot'],
                    MAP_RENDER_OFFSET_X + x*TILE_SIZE - TILE_SIZE,
                    MAP_RENDER_OFFSET_Y + y*TILE_SIZE - TILE_SIZE
                )
        
                table.insert(self.objects, pot)
            end
        end
    end 
end

--[[
    Generates the walls and floors of the room, randomizing the various varieties
    of said tiles for visual variety.
]]
function RoomCSV:generateWallsAndFloors(room)
    for y = 1, self.height do
        table.insert(self.tiles, {})

        for x = 1, self.width do

            local id = TILE_EMPTY

            if x == 1 and y == 1 then
                id = TILE_TOP_LEFT_CORNER
            elseif x == 1 and y == self.height then
                id = TILE_BOTTOM_LEFT_CORNER
            elseif x == self.width and y == 1 then
                id = TILE_TOP_RIGHT_CORNER
            elseif x == self.width and y == self.height then
                id = TILE_BOTTOM_RIGHT_CORNER
            
            -- random left-hand walls, right walls, top, bottom, and floors
            elseif x == 1 then
                id = TILE_LEFT_WALLS[math.random(#TILE_LEFT_WALLS)]
            elseif x == self.width then
                id = TILE_RIGHT_WALLS[math.random(#TILE_RIGHT_WALLS)]
            elseif y == 1 then
                id = TILE_TOP_WALLS[math.random(#TILE_TOP_WALLS)]
            elseif y == self.height then
                id = TILE_BOTTOM_WALLS[math.random(#TILE_BOTTOM_WALLS)]
            else
                id = TILE_FLOORS[math.random(#TILE_FLOORS)]
                if room[y][x] == CSV_WALL then
                    id = TILE_CENTER_WALLS[math.random(#TILE_CENTER_WALLS)]
                    local wall = GameObject(
                        GAME_OBJECT_DEFS['wall'],
                        MAP_RENDER_OFFSET_X + x*TILE_SIZE - TILE_SIZE,
                        MAP_RENDER_OFFSET_Y + y*TILE_SIZE - TILE_SIZE
                    )

                    table.insert(self.objects, wall)
                end
            end
            
            table.insert(self.tiles[y], {
                id = id
            })
        end
    end
end

function RoomCSV:initPlayerCoordinates(room)
    for y = 2, self.height-1 do
        for x = 2, self.width-1 do
            if room[y][x] == CSV_PLAYER then   
               self.player.x = MAP_RENDER_OFFSET_X + (x-1)*self.player.width
               self.player.y = MAP_RENDER_OFFSET_Y +(y-1)*self.player.width - 6
            end
        end
    end
end

function RoomCSV:update(dt)
    -- don't update anything if we are sliding to another room (we have offsets)
    if self.adjacentOffsetX ~= 0 or self.adjacentOffsetY ~= 0 then return end

    self.player:update(dt)

    for i = #self.entities, 1, -1 do
        local entity = self.entities[i]

        -- remove entity from the table if health is <= 0
        if entity.health <= 0 then
            entity.dead = true
            if not entity.dropped then
               if rnd(10) == 1 then 
                    table.insert(self.objects, GameObjectConsumable(GAME_OBJECT_DEFS['heart'], entity.x, entity.y)) 
                end
                entity.dropped = true
            end
        elseif not entity.dead then
            entity:processAI({room = self}, dt)
            entity:update(dt)
        end

        -- collision between the player and entities in the room
        if not entity.dead and not entity.projectile and self.player:collides(entity) and not self.player.invulnerable then
            gSounds['hit-player']:play()
            self.player:damage(1)
            self.player:goInvulnerable(1.5)

            if self.player.health == 0 then
                gStateMachine:change('game-over')
            end
        end
    end

    for k, object in pairs(self.objects) do
        object:update(dt)

        -- trigger collision callback on object
        if self.player:collides(object) then
            object:onCollide()
            if object.type == 'consumable' then object:onConsume(self, k) end
        end
    end

    for k, projectile in pairs(self.projectiles) do
        projectile:update(dt)

        for k, entity in pairs(self.entities) do
            if entity:collides(projectile) then
                projectile:destroy()
                entity:damage(1)
            end
        end

        for k, obj in pairs(self.objects) do
            if obj.type == 'switch' and obj:collides(projectile) then
                obj:onCollide()
            end
        end
    end
end

function RoomCSV:render()
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self.tiles[y][x]
            love.graphics.draw(gTextures['tiles'], gFrames['tiles'][tile.id],
                (x - 1) * TILE_SIZE + self.renderOffsetX + self.adjacentOffsetX, 
                (y - 1) * TILE_SIZE + self.renderOffsetY + self.adjacentOffsetY)
        end
    end

    -- render doorways; stencils are placed where the arches are after so the player can
    -- move through them convincingly
    for k, doorway in pairs(self.doorways) do
        doorway:render(self.adjacentOffsetX, self.adjacentOffsetY)
    end

    for k, object in pairs(self.objects) do
        object:render(self.adjacentOffsetX, self.adjacentOffsetY)
    end

    for k, projectile in pairs(self.projectiles) do
        projectile:render(self.adjacentOffsetX, self.adjacentOffsetY)
    end

    for k, entity in pairs(self.entities) do
        if not entity.dead then entity:render(self.adjacentOffsetX, self.adjacentOffsetY) end
    end

    -- stencil out the door arches so it looks like the player is going through
    love.graphics.stencil(function()
        -- left
        love.graphics.rectangle('fill', -TILE_SIZE - 6, MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2) * TILE_SIZE - TILE_SIZE,
            TILE_SIZE * 2 + 6, TILE_SIZE * 2)
        
        -- right
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH * TILE_SIZE) - 6,
            MAP_RENDER_OFFSET_Y + (MAP_HEIGHT / 2) * TILE_SIZE - TILE_SIZE, TILE_SIZE * 2 + 6, TILE_SIZE * 2)
        
        -- top
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2) * TILE_SIZE - TILE_SIZE,
            -TILE_SIZE - 6, TILE_SIZE * 2, TILE_SIZE * 2 + 12)
        
        --bottom
        love.graphics.rectangle('fill', MAP_RENDER_OFFSET_X + (MAP_WIDTH / 2) * TILE_SIZE - TILE_SIZE,
            VIRTUAL_HEIGHT - TILE_SIZE - 6, TILE_SIZE * 2, TILE_SIZE * 2 + 12)
    end, 'replace', 1)

    love.graphics.setStencilTest('less', 1)
    
    if self.player then
        self.player:render()
    end

    love.graphics.setStencilTest()
end