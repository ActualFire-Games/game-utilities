--!strict
-- Dynamic Octree System (DOS), by plasma_node, using Octree by Quenty
-- Creates Octrees that are able to remember objects, useful for
-- grids where objects will need to move or disappear.
-- Slightly modified by @crusherfire for type support

local Octree = require(script._Octree)
local R = Random.new(os.clock() * os.time());

--- This
local DOS = {};

--- Const
local OCTREE_DEFAULTS = {
    Depth = 4;
    Size = 512;
};

--- Grid Class
local Grid = {};
Grid.__index = Grid;
type fields = {
	Name: string,
	Tree: any,
	Update: any,
	Entries: any,
	Tracked: any,
	_trash: any,
}
export type DynamicOctree = typeof(setmetatable({} :: fields, Grid))

-- Used to add items which will not
-- be destroyed or moved within the lifespan
-- of the DOS grid
function Grid:AddStatic (Item: any, Position: Vector3?)
    table.insert(self._trash, self.Tree:CreateNode(Position or Vector3.zero, Item));
end

function Grid:Add (Item: any, Position: Vector3?)
    self.Entries[Item] = self.Tree:CreateNode(Position or Vector3.zero, Item);
end

function Grid:RadiusSearch(pos: Vector3, radius: number): ({ any }, { number })
	return self.Tree:RadiusSearch(pos, radius)
end

--[=[
    Track object:

    This function will automatically update the objects position, and
    automatically remove stale nodes.

    ! WARNING ! Not intended for large scale use, as it will cause perf issues
	
    Usage:
    ```lua
    local cleanup = Grid:Track(Model, 0.1);
    task.wait(2);
    cleanup();
    ```
]=]
function Grid:Track (Item: Instance, Interval: number): () -> ()
    assert(typeof(Item) == "Instance", "Object must be an instance");

    local operate = true;
    Interval = math.clamp(Interval or 0.1, 0, 10);

	if (Item:IsA("PVInstance")) then
        task.defer(function ()
            while self.Update and operate do
                pcall(function ()
                    self.Tracked[Item]:Destroy();
                end);
                self.Tracked[Item] = self.Tree:CreateNode(Item:GetPivot().Position, Item);
                task.wait(Interval);
            end
        end);
	else
		error(`don't know how to handle instance: '{Item}'`, 2)
	end

	return function ()
		operate = false;
		task.wait(Interval);
		pcall(function () self.Tracked[Item]:Destroy(); end);
		self.Tracked[Item] = nil
	end
end

function Grid:Remove (Item: any)
    if (self.Entries[Item]) then
        self.Entries[Item]:Destroy();
    end
    self.Entries[Item] = nil;
end

function Grid:UpdateFor (Item: any, Position: Vector3)
    if (self.Entries[Item]) then
        self.Entries[Item]:Destroy();
    end
    self:Add(Item, Position);
end

-- Destroy the grid
function Grid:Destroy ()
    self.Update = false;

    for _, g in self._trash do
        g:Destroy();
    end
    
    for _, entry in self.Entries do
        entry:Destroy();
    end

    self.Tree = nil;
end

function Grid:_init ()
    self.Update = true;
end


---- DOS ----

function DOS.new (Name: string?, Depth: number?, Size: number?): DynamicOctree
    local grid = {
        Name = Name or ("Unnamed DOS Grid ~~"..R:NextInteger(1000,9999)); -- Not a unique ID, just helps to distinguish things in the log if something goes wrong
        Tree = Octree.new(Depth or OCTREE_DEFAULTS.Depth, Size or OCTREE_DEFAULTS.Size);
        Update = false;

        Entries = {}; -- List of all objects/items stored
        Tracked = {}; -- List of all objects being tracked

        _trash = {};
    }

    grid = setmetatable(grid, Grid);
    grid:_init();
    
    return grid;
end

return DOS;