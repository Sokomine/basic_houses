-- Features:
--   * each house has a door and one mese lamp per floor
--   * houses can have multiple floors
--   * each house comes with a ladder for access to all floors
--   * normal saddle roofs and flat roofs supported
--   * trees, plants and snow inside the house are not cleared
--     -> the houses look abandoned (ready for players to move in)
--   * houses look acceptable but leave a lot of room for improvement
--     through their future inhabitants
--     (no windows in gable, no decoration, no cellar, no furniture,
--     no mini-house for elevator/ladder on top of skyscrapers, ...)
-- Technical stuff:
--   * used function from handle_schematics to mark parts of the heightmap as used
--   * glass panes, glass and obisidan glass are more common than bars
--   * windows are no longer "filled" (param2 now set to 0)
--   * doors are sourrounded by wall node and not glass panes or bars
--     (would look strange and leave gaps otherwise)
-- Known issues:
--   * cavegen may eat holes into the ground below the house
--   * houses may very seldom overlap

simple_houses = {};

-- generate at max this many houses per mapchunk;
-- Note: This amount will likely only spawn if your mapgen is very flat.
--       Else you will see far less houses.
simple_houses.max_per_mapchunk = 20;



-- build either the two walls of the box that forms the house in x or z direction;
-- windows are added randomly
-- parameters:
--    p           starting point of these walls
--    sizex       length of the entire building in x direction
--    sizez       same for z direction
--    in_x_direction  do we have to build the two walls in x direction or the two in z direction?
--    materials   needs to contain at least the fields
--                   walls   node name of wall material
--                   glass   node name of glass material
--                   color   optional; param2-color-value for wall node
--    rotation_1  param2 for materials.wall nodes for the first wall
--    rotation_2  param2 for materials.wall nodes for the second wall
--    vm          voxel manipulator
simple_houses.build_two_walls = function( p, sizex, sizez, in_x_direction,
		materials, rotation_1, rotation_2, window_at_height, vm)

	-- param2 (orientation or color) for the first two walls;
	-- tree logs need to be orientated correctly, colored nodes have to keep their color;
	local node_wall_1  = {name=materials.walls, param2 = (materials.color or rotation_1)};
	local node_wall_2  = {name=materials.walls, param2 = (materials.color or rotation_2)};
	-- glass panes and metal bars need the correct rotation and no color value
	local node_glass_1 = {name=materials.glass, param2 = rotation_1};
	local node_glass_2 = {name=materials.glass, param2 = rotation_2};
	-- solid glass needs a rotation of 0 (else it would be interpreted as level)
	if( minetest.registered_nodes[ materials.glass ]
	  and minetest.registered_nodes[ materials.glass ].paramtype2 == "glasslikeliquidlevel") then
		node_glass_1.param2 = 0;
		node_glass_2.param2 = 0;
	end

	local w1_x;
	local w2_x;
	local w1_z;
	local w2_z;
	local size;
	if( in_x_direction ) then
		w1_x = p.x;
		w2_x = p.x;
		w1_z = p.z;
		w2_z = p.z+sizez;
		size = sizex+1;
	else
		w1_x = p.x;
		w2_x = p.x+sizex;
		w1_z = p.z;
		w2_z = p.z;
		size = sizez+1;
	end

	-- place windows at even or odd rows? -> create some variety
	local window_at_odd_row = false;
	if( math.random(1,2)==1 ) then
		window_at_odd_row = true;
	end

	-- place where a door or ladder might be added (no window there);
	-- we need to avid adding ladders directly in front of windows or
	-- placing doors right next to glass panes because that would look ugly
	local special_wall_1 = math.random(3,size-3);
	local special_wall_2 = math.random(3,size-3);
	if( special_wall_2 == special_wall_1 ) then
		special_wall_2 = special_wall_2 - 1;
		if( special_wall_2 < 3 ) then
			special_wall_2 = 4;
		end
	end

	local wall_height = #window_at_height;
	for lauf = 1, size do
		local wall_1_has_window = false;
		local wall_2_has_window = false;
		-- the corners never get glass
		if( lauf>1 and lauf<size ) then
			-- *one* of the walls may get a window - never both (would look odd to
			-- be able to see through the house)
			local not_special = ( (lauf ~= special_wall_1) and (lauf ~= special_wall_2));
			if( window_at_odd_row == (lauf%2==1)) then
				wall_1_has_window = (not_special and ( math.random(1,3)~=3));
			else
				wall_2_has_window = (not_special and ( math.random(1,3)~=3));
			end
		end
		-- actually build the wall from bottom to top
		for height = 1,wall_height do
			-- if there is a window in this wall...
			if( window_at_height[ height ]==1 and wall_1_has_window) then
				node = node_glass_1;
			else
				node = node_wall_1;
			end
			vm:set_node_at( {x=w1_x, y=p.y+height, z=w1_z}, node);

			-- ..or in the other wall
			if( window_at_height[ height ]==1 and (wall_2_has_window)) then
				node = node_glass_2;
			else
				node = node_wall_2;
			end
			vm:set_node_at( {x=w2_x, y=p.y+height, z=w2_z}, node);
		end

		if( in_x_direction ) then
			w1_x = w1_x + 1;
			w2_x = w1_x;
		else
			w1_z = w1_z + 1;
			w2_z = w1_z;
		end
	end
	return {special_wall_1, special_wall_2, window_at_odd_row};
end


-- roofs may extend in x or z direction
local pswap = function( pos, swap )
	if( not( swap )) then
		return pos;
	else
		return {x=pos.z, y=pos.y, z=pos.x};
	end
end


-- builds a roof with gable;
-- takes the same parameters as simple_houses.build_two_walls (apart from the
-- window_at_height parameter which is unnecessary here)
simple_houses.build_roof_and_gable = function( p_orig, sizex, sizez, in_x_direction,
		materials, rotation_1, rotation_2, vm)

	local p = {x=p_orig.x, y=p_orig.y, z=p_orig.z};
	local node_side_1 = {name=materials.roof, param2=rotation_1};
	local node_side_2 = {name=materials.roof, param2=rotation_2};
	local swap = false;
	local dy = p.y;

	-- do the swapping
	if( not( in_x_direction )) then
		local help = sizex;
		sizex = sizez;
		sizez = help;
		p.x = p_orig.z;
		p.z = p_orig.x;
		swap = true;
	end

	local xhalf = math.floor( sizex/2 );
	for dx = 0,xhalf do
		for dz = p.z, p.z+sizez do
			vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=dz}, swap), node_side_1 );
			vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=dz}, swap), node_side_2 );
		end
		dy = dy+1;
	end

	-- if sizex is not even, then we need to use slabs at the heighest point
	local node_slab = {name=materials.roof_middle};
	if( sizex%2==0 ) then
		for dz = p.z, p.z+sizez do
			vm:set_node_at( pswap({x=p.x+xhalf,y=p.y+xhalf,z=dz},swap), node_slab );
		end
	end

	-- Dachgiebel (=gable)
	local node_gable = { name   = materials.gable,
		             param2 = (materials.color or 0 )}; -- color of the gable
	for dx = 0,xhalf do
		for dy = p.y, p.y-1+dx do
			vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=p.z+sizez-1}, swap), node_gable );
			vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=p.z+sizez-1}, swap), node_gable );

			vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=p.z      +1}, swap), node_gable );
			vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=p.z      +1}, swap), node_gable );
		end
	end
end


-- four places have been reserved previously (=no window placed) and
-- can be used for ladders, doors etc.
simple_houses.get_random_place = function( p, sizex, sizez, places, use_this_one, already_used, offset )
	local i = math.random(1,4);
	if( i==already_used) then
		if( i>1) then
			i = i-1;
		else
			i = i+1;
		end
	end
	-- ladders need to be placed on the right side so that people can climb up
	if( use_this_one and places[use_this_one]) then
		i = use_this_one;
	end
	local at_odd_row = (places[i]%2==1);
	if(     (i==1 or i==2) and (places[5]==at_odd_row)) then
		return {x=p.x+places[i],      y=p.y, z=p.z+1+offset, p2=5, used=i};
	elseif( (i==1 or i==2) and (places[5]~=at_odd_row)) then
		return {x=p.x+places[i],      y=p.y, z=p.z-1-offset+sizez, p2=4, used=i};
	elseif( (i==3 or i==4) and (places[6]==at_odd_row)) then
		return {x=p.x+1+offset,       y=p.y, z=p.z+places[i], p2=3, used=i};
	elseif( (i==3 or i==4) and (places[6]~=at_odd_row)) then
		return {x=p.x-1-offset+sizex, y=p.y, z=p.z+places[i], p2=2, used=i};
	else
		return {x=p.x, y=p.y, z=p.z, used=0};
	end
end


-- add a ladder from bottom to top (staircases would be nicer but are too difficult to do well)
-- if flat_roof is false, the ladder needs to be placed on the smaller side so that people can
--   actually climb it;
-- ladder_places are the special places simple_houses.build_two_walls(..) has reserved
simple_houses.place_ladder = function( p, sizex, sizez, ladder_places, ladder_height, flat_roof, vm )
	-- place the ladder at the galbe side in houses with a real roof (else
	-- climbing the ladder up to the roof would fail due to lack of room)
	local use_place = nil;
	if(     not( flat_roof) and (sizex <  sizez )) then
		use_place = math.random(1,2);
	elseif( not( flat_roof) and (sizex >= sizez )) then
		use_place = math.random(3,4);
	end
	-- select one of the four reserved places
	local res = simple_houses.get_random_place( p, sizex, sizez, ladder_places, use_place, -1, 1 );
	local ladder_node = {name="default:ladder_steel", param2 = res.p2};
	-- actually place the ladders
	for height=p.y+1, p.y + ladder_height do
		vm:set_node_at( {x=res.x, y=height, z=res.z}, ladder_node );
	end
	return res.used;
end


-- place the door into one of the reserved places
simple_houses.place_door = function( p, sizex, sizez, door_places, wall_with_ladder, floor_height, vm )

	local res = simple_houses.get_random_place( p, sizex, sizez, door_places, -1, wall_with_ladder, 0 );
	vm:set_node_at( {x=res.x, y=p.y+1, z=res.z}, {name="doors:door_wood_a", param2 = 0 });
	vm:set_node_at( {x=res.x, y=p.y+2, z=res.z}, {name="doors:hidden"});
	-- light so that the door can be found
	vm:set_node_at( {x=res.x, y=p.y+3, z=res.z}, {name="default:meselamp"});

	-- add some light to the upper floors as well
	for i,height in ipairs( floor_height ) do
		if( i>2) then
			vm:set_node_at( {x=res.x,y=height-1,z=res.z},{name="default:meselamp"});
		end
	end
	return res.used;
end


-- locate a place for the "hut" and place it
simple_houses.simple_hut_find_place_and_build = function( heightmap, minp, maxp, sizex, sizez, minheight, maxheight )

	local res = handle_schematics.find_flat_land_get_candidates_fast( heightmap, minp, maxp,
		sizex, sizez, minheight, maxheight );

--	print( "Places found of size "..tostring( sizex ).."x"..tostring(sizez)..": "..tostring( #res.places_x )..
--			       " and "..tostring( sizez ).."x"..tostring(sizex)..": "..tostring( #res.places_z )..
--		".");

	if( (#res.places_x + #res.places_z )< 1 ) then
--		print( "  Aborting. No place found.");
		return nil;
	end

	-- select a random place - either sizex x sizez or sizez x sizex
	local c = math.random( 1, #res.places_x + #res.places_z );
	local i = 1;
	if( c > #res.places_x ) then
		i = res.places_z[ c-#res.places_x ];
		-- swap x and z due to rotation of 90 or 270 degree
		local tmp = sizex;
		sizex = sizez;
		sizez = tmp;
		tmp = nil;
	else
		i = res.places_x[ c ];
	end

	local chunksize = maxp.x - minp.x + 1;
	-- translate index back into coordinates
	local p = {x=minp.x+(i%chunksize)-1, y=heightmap[ i ], z=minp.z+math.floor(i/chunksize), i=i};

	local wood_types = {"", "jungle", "acacia_", "aspen_", "pine_"};
	-- wooden roof
	local wood  = wood_types[ math.random( #wood_types )];
	local wood1 = wood_types[ math.random( #wood_types )];
	local wood2 = wood_types[ math.random( #wood_types )];
	-- ceiling of main room (which is also the floor of the room below the roof)
	local wood3 = wood_types[ math.random( #wood_types )];
	-- the walls can be wooden planks, tree trunks, painted clay or painted wall (=coral)
	local walls = "default:"..wood1.."wood";
	local color = nil;
	local gable = "default:"..wood2.."wood";
	if( plasterwork and math.random(1,2)==1) then
		walls = plasterwork.node_list[ math.random(1, #plasterwork.node_list)];
		color = math.random(0,255);
	else
		local r = math.random(1,5);
		if(r==1 or r==2) then
			walls = "default:"..wood1.."tree";
		end
	end
	if( math.random(1,2)==1) then
		gable = walls;
	end
	-- glass can be glass panes, iron bars or solid glass
	local glass_materials = {"xpanes:pane_flat","xpanes:pane_flat","xpanes:pane_flat",
			"default:glass","default:glass",
			"default:obsidian_glass",
			"xpanes:bar_flat"};
	local glass = glass_materials[ math.random( 1,#glass_materials )];
	local materials = {
		walls = walls,
		floor = "default:brick",
		gable = gable,
		ceiling = "default:"..wood3.."wood",
		roof = "stairs:stair_"..wood.."wood",
		roof_middle = "stairs:slab_"..wood.."wood",
		glass = glass,
		"xpanes:pane_flat", --"default:glass",
		color = color,
		};
	return simple_houses.simple_hut_place_hut( p, sizex, sizez, materials, heightmap );
end


-- actually build the "hut"
simple_houses.simple_hut_place_hut = function( p, sizex, sizez, materials, heightmap )

	sizex = sizex-1;
	sizez = sizez-1;
	-- house too small or too large
	if( sizex < 3 or sizez < 3 or sizex>64 or sizez>64) then
		return nil;
	end

	local vm = minetest.get_voxel_manip();
	local minp2, maxp2 = vm:read_from_map(
		{x=p.x - sizex, y=p.y-1, z=p.z - sizez },
		{x=p.x, y=p.y+math.max(sizex,sizez)*2, z=p.z});

--	print( "  Placing house at "..minetest.pos_to_string( p ));

	local window_at_height = {0,0,0,0,0};
	local r = math.random(1,6);
	if(     r==1 or r==2) then
		window_at_height = {0,1,1,1,0};
	elseif( r==3 or r==4 or r==5) then
		window_at_height = {0,0,1,1,0};
	else
		window_at_height = {0,0,1,0,0};
	end
	-- how many floors will the house have?
	local floors = 1;
	local floor_materials = {{name="default:brick"}};
	local floor_height = {p.y};
	-- TODO: buildings with colored materials ought to have more floors and more often a flat roof
	-- TODO: logcabin-style houses ought to have at max 2 floors and almost never a flat roof
	-- TODO: houses with wood ought to have 1-3 floors at max
	floors = math.random(1,5);
	local flat_roof = false;
	if( math.random(1,2)==1) then
		flat_roof = true;
	end

	local first_floor_height = #window_at_height;
	for i=1,floors-1 do
		for k=2,first_floor_height do
			table.insert( window_at_height, window_at_height[k]);
		end
		table.insert( floor_height, floor_height[ #floor_height] + first_floor_height-1);
		table.insert( floor_materials, {name=materials.ceiling});
	end
	table.insert( floor_height, floor_height[ #floor_height] + first_floor_height-1);
	if( flat_roof ) then
		table.insert( floor_materials, {name=materials.walls, param2 = (materials.color or 12)});
		table.insert( window_at_height, 0 );
	else
		table.insert( floor_materials, {name=materials.walls, param2 = (materials.color or 12)});
	end

	local p_start = {x=p.x-sizex+1, y=p.y-1, z=p.z-sizez+1};
	-- build the two walls in x direction
	local s1 = simple_houses.build_two_walls(p_start, sizex-2, sizez-2, true,  materials, 12, 18, window_at_height, vm );
	-- build the two walls in z direction
	local s2 = simple_houses.build_two_walls(p_start, sizex-2, sizez-2, false, materials,  9,  7, window_at_height, vm );

	-- each floor is 4 blocks heigh
	local roof_starts_at = p.y + (4*floors);
	p_start = {x=p.x-sizex, y=roof_starts_at, z=p.z-sizez};
	-- build the roof
	if( flat_roof ) then
		-- build a flat roof
	elseif( sizex < sizez ) then
		simple_houses.build_roof_and_gable(p_start, sizex, sizez, true,  materials, 1, 3, vm );
	else
		simple_houses.build_roof_and_gable(p_start, sizex, sizez, false, materials, 0, 2, vm );
	end

	local do_ceiling = ( math.min( sizex, sizez )>4 );
	-- floor and ceiling
	for dx = p.x-sizex+2, p.x-2 do
	for dz = p.z-sizez+2, p.z-2 do
		for i,height in ipairs( floor_height ) do
			vm:set_node_at( {x=dx,y=height,z=dz},floor_materials[i]);
		end
	end
	end

	-- index 1 and 2 are offsets in any of the walls; index 3 indicates if the
	-- windows start at odd indices or not
	local reserved_places = {s1[1], s1[2], s2[1], s2[2], s1[3], s2[3]};
	p_start = {x=p.x-sizex, y=p.y, z=p.z-sizez};
	local wall_with_ladder = simple_houses.place_ladder( p_start, sizex, sizez,
		reserved_places, #window_at_height-1, flat_roof, vm);

	simple_houses.place_door( p_start, sizex, sizez, reserved_places, wall_with_ladder, floor_height, vm );

	vm:write_to_map(true);
	-- return where the hut has been placed
	return {p1={x=p.x - sizex, y=p.y, z=p.z - sizez }, p2=p};
end


simple_houses.simple_hut_generate = function( heightmap, minp, maxp)
	if( minp.y < -64 or minp.y > 500 or not(heightmap)) then
		return;
	end
	-- halfway reasonable house sizes
	local maxsize = 13;
	if( math.random(1,5)==1) then
		maxsize = 17;
	end
-- TODO: if more than 2-3 houses are placed, get voxelmanip for entire area instead of for each house
-- TODO: avoid overlapping with mg_villages if that one is installed
	local sizex = math.random(8,maxsize);
	local sizez = math.max( 8, math.min( maxsize, math.random( math.floor(sizex/4), sizex*2 )));
	-- chooses random materials and a random place without destroying the landscape
	-- minheight 2: one above water level; avoid below water level and places on ice
	return simple_houses.simple_hut_find_place_and_build( heightmap, minp, maxp, sizex, sizez, 2, 1000 );
end

minetest.register_on_generated(function(minp, maxp, seed)
	local heightmap = minetest.get_mapgen_object('heightmap');
	for i=1,simple_houses.max_per_mapchunk do
		local res = simple_houses.simple_hut_generate( heightmap, minp, maxp);
		if( res and res.p1 and res.p2 ) then
			handle_schematics.mark_flat_land_as_used(heightmap, minp, maxp,
					res.p2.i,
					(res.p2.x-res.p1.x),
					(res.p2.z-res.p1.z));
		end
	end
end);
