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
--   * if the saddle roof does not fit into the height volume that is
--     reserved for the house, the top of the roof is made flat
--   * some random houses receive a chest with further building material
--     for the house the chest spawned in
--   * houses made out of plasterwork nodes may receive a machine from
--     plasterwork instead of a chest
--   * can be used with the RealTest game as well
-- Technical stuff:
--   * used function from handle_schematics to mark parts of the heightmap as used
--   * glass panes, glass and obisidan glass are more common than bars
--   * windows are no longer "filled" (param2 now set to 0)
--   * doors are sourrounded by wall node and not glass panes or bars
--     (would look strange and leave gaps otherwise)
-- Known issues:
--   * cavegen may eat holes into the ground below the house
--   * houses may very seldom overlap

basic_houses = {};

-- generate count of building each 80x80 mapchunk, if chunk is assigned to village
-- Note: This amount will likely only spawn if your mapgen is very flat.
--       Else you will see far less houses.
basic_houses.min_per_mapchunk = 10;
basic_houses.max_per_mapchunk = 20;

-- Villages average distance in nodes (4x80)
basic_houses.village_average = 160

-- Villages min/max size in nodes (radius)
basic_houses.village_min_size = 20
basic_houses.village_max_size = 100

-- materials the houses can be made out of
-- allows to reach upper floors
basic_houses.ladder = "default:ladder_steel";
-- gets placed over the door
basic_houses.lamp   = "default:meselamp";
-- floor at the entrance level of the house
basic_houses.floor = "default:brick";
-- placed randomly in some houses
basic_houses.chest = "default:chest";
-- glass can be glass panes, iron bars or solid glass
basic_houses.glass = {"xpanes:pane_flat","xpanes:pane_flat","xpanes:pane_flat",
			"default:glass","default:glass",
			"default:obsidian_glass",
			"xpanes:bar_flat"};
-- some walls are tree logs, some wooden planks, some colored plasterwork (if installed)
-- - and some nodes are made out of these materials here
basic_houses.walls = {"default:brick", "default:stonebrick", "default:desert_stonebrick",
	"default:sandstonebrick", "default:desert_stonebrick", "default:silver_sandstone_brick",
	"default:obsidianbrick", "default:stone_block", "default:sandstone_block",
	"default:desert_sandstone_block", "default:silver_sandstone_block", "default:obsidian_block"};
-- doors
basic_houses.door_bottom = "doors:door_wood_a";
basic_houses.door_top    = "doors:hidden";
-- make sure the place in front of the door will not get griefed by mapgen
basic_houses.around_house = {"default:stone_block","default:sandstone_block",
	"default:desert_sandstone_block", "default:silver_sandstone_block"};


-- if the realtest game is choosen: adjust materials
if( minetest.get_modpath("core") and minetest.get_modpath("trees")) then
	basic_houses.ladder = "trees:pine_ladder";
	basic_houses.lamp   = "light:streetlight";
	basic_houses.glass  = {"xpanes:pane_5","xpanes:pane_5","xpanes:pane_5",
			"default:glass","default:glass"};
	basic_houses.walls = {"default:clay", "default:stone", "default:stone_bricks", "default:stone_flat",
		"default:stone_macadam", "default:desert_stone", "default:desert_stone_bricks",
		"default:desert_stone_flat", "default:desert_stone_macadam", "decorations:malachite_block",
		"decorations:cinnabar_block", "decorations:gypsum_block", "decorations:jet_block",
		"decorations:lazurite_block", "decorations:olivine_block", "decorations:petrified_wood_block",
		"decorations:satinspar_block", "decorations:selenite_block", "decorations:serpentine_block"};
	basic_houses.door_bottom = "doors:door_pine_b_1";
	basic_houses.door_top    = "doors:door_pine_t_1";
	basic_houses.around_house = basic_houses.walls;
-- if the MineClone2 game is choosen: adjust materials
elseif( minetest.get_modpath("mcl_core")) then
	local colors = {"red", "green", "blue", "light_blue", "black", "white",
			"yellow", "brown", "orange"; "pink", "grey", "lime", "silver",
			"magenta", "purple", "cyan"};
	basic_houses.ladder = "mcl_core:ladder";
	basic_houses.lamp   = "mcl_ocean:sea_lantern";
	basic_houses.floor  = "mcl_core:brick_block";
	basic_houses.chest  = "mcl_chests:chest";

	basic_houses.glass = {"mcl_core:glass", "mcl_core:glass", "mcl_core:glass",
			"xpanes:bar_flat"};
	for i,k in ipairs( colors ) do
		table.insert( basic_houses.glass, "mcl_core:glass_"..k );
		table.insert( basic_houses.glass, "xpanes:pane_"..k.."_flat" );
	end

	basic_houses.walls = {"mcl_core:brick_block",
		"mcl_core:stonebrick", "mcl_core:stonebrickcarved", "mcl_core:stonebrickcracked",
		"mcl_core:stonebrickmossy","mcl_core:sandstonecarved", "mcl_core:sandstonesmooth2",
		"mcl_core:redsandstonecarved"};
	for i,k in ipairs( colors ) do
		table.insert( basic_houses.walls, "mcl_colorblocks:glazed_terracotta_"..k );
		table.insert( basic_houses.walls, "mcl_colorblocks:hardened_clay_"..k );
	end
	basic_houses.around_house = { "mcl_core:stone_smooth", "mcl_core:granite_smooth",
		"mcl_core:andesite_smooth", "mcl_core:diorite_smooth", "mcl_core:sandstonesmooth",
		"mcl_core:sandstonecarved", "mcl_core:sandstonesmooth2",
		"mcl_core:redsandstonesmooth", "mcl_core:redsandstonesmooth2"};
	basic_houses.door_bottom = "mcl_doors:wooden_door_b_1";
	basic_houses.door_top    = "mcl_doors:wooden_door_t_1";
end

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
basic_houses.build_two_walls = function( p, sizex, sizez, in_x_direction, materials, vm, pr)

	local v = 0;
	if( not( in_x_direction )) then
		v = 2;
	end
	-- param2 (orientation or color) for the first two walls;
	-- tree logs need to be orientated correctly, colored nodes have to keep their color;
	local node_wall_1  = {name=materials.walls, param2 = (materials.color or materials.wall_orients[1+v])};
	local node_wall_2  = {name=materials.walls, param2 = (materials.color or materials.wall_orients[2+v])};
	-- glass panes and metal bars need the correct rotation and no color value
	local node_glass_1 = {name=materials.glass, param2 = materials.glass_orients[1+v]};
	local node_glass_2 = {name=materials.glass, param2 = materials.glass_orients[2+v]};
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
	if( pr:next(1,2)==1 ) then
		window_at_odd_row = true;
	end

	-- place where a door or ladder might be added (no window there);
	-- we need to avid adding ladders directly in front of windows or
	-- placing doors right next to glass panes because that would look ugly
	local special_wall_1 = pr:next(3,math.max(3,size-3));
	local special_wall_2 = pr:next(3,math.max(3,size-3));
	if( special_wall_2 == special_wall_1 ) then
		special_wall_2 = special_wall_2 - 1;
		if( special_wall_2 < 3 ) then
			special_wall_2 = 4;
		end
	end

	local wall_height = #materials.window_at_height;
	for lauf = 1, size do
		local wall_1_has_window = false;
		local wall_2_has_window = false;
		-- the corners never get glass
		if( lauf>1 and lauf<size ) then
			-- *one* of the walls may get a window - never both (would look odd to
			-- be able to see through the house)
			local not_special = ( (lauf ~= special_wall_1) and (lauf ~= special_wall_2));
			if( window_at_odd_row == (lauf%2==1)) then
				wall_1_has_window = (not_special and ( pr:next(1,3)~=3));
			else
				wall_2_has_window = (not_special and ( pr:next(1,3)~=3));
			end
		end
		-- actually build the wall from bottom to top
		for height = 1,wall_height do
			local node = nil;
			-- if there is a window in this wall...
			if( materials.window_at_height[ height ]==1 and wall_1_has_window) then
				node = node_glass_1;
			else
				node = node_wall_1;
			end
			vm:set_node_at( {x=w1_x, y=p.y+height, z=w1_z}, node);

			-- ..or in the other wall
			if( materials.window_at_height[ height ]==1 and (wall_2_has_window)) then
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
-- takes the same parameters as basic_houses.build_two_walls (apart from the
-- window_at_height parameter which is unnecessary here)
basic_houses.build_roof_and_gable = function( p_orig, sizex, sizez, in_x_direction,
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

	local node_slab = {name=materials.roof_middle};

	local xhalf = math.floor( sizex/2 );
	for dx = 0,xhalf do
		for dz = p.z, p.z+sizez do
			-- normal saddle roof
			if( dy < p_orig.ymax ) then
				vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=dz}, swap), node_side_1 );
				vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=dz}, swap), node_side_2 );
			-- flatten the top of the saddle roof
			else
				vm:set_node_at( pswap({x=p.x+      dx,y=p_orig.ymax,z=dz}, swap), node_slab );
				vm:set_node_at( pswap({x=p.x+sizex-dx,y=p_orig.ymax,z=dz}, swap), node_slab );
			end
		end
		dy = dy+1;
	end

	-- if sizex is not even, then we need to use slabs at the heighest point
	if( sizex%2==0 ) then
		for dz = p.z, p.z+sizez do
			if( dy <= p_orig.ymax ) then
				vm:set_node_at( pswap({x=p.x+xhalf,y=p.y+xhalf,z=dz},swap), node_slab );
			else
				vm:set_node_at( pswap({x=p.x+xhalf,y=p_orig.ymax,z=dz},swap), node_slab );
			end
		end
	end

	-- Dachgiebel (=gable)
	local node_gable = { name   = materials.gable,
		             param2 = (materials.color or 0 )}; -- color of the gable
	for dx = 0,xhalf do
		for dy = p.y, p.y-1+dx do
			if( dy < p_orig.ymax ) then
				vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=p.z+sizez-1}, swap), node_gable );
				vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=p.z+sizez-1}, swap), node_gable );

				vm:set_node_at( pswap({x=p.x+sizex-dx,y=dy,z=p.z      +1}, swap), node_gable );
				vm:set_node_at( pswap({x=p.x+      dx,y=dy,z=p.z      +1}, swap), node_gable );
			end
		end
	end
end


-- four places have been reserved previously (=no window placed) and
-- can be used for ladders, doors etc.
basic_houses.get_random_place = function( p, sizex, sizez, places, use_this_one, already_used, offset, pr )
	local i = pr:next(1,4);
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
-- ladder_places are the special places basic_houses.build_two_walls(..) has reserved
basic_houses.place_ladder = function( p, sizex, sizez, ladder_places, ladder_height, flat_roof, vm, pr )
	-- place the ladder at the galbe side in houses with a real roof (else
	-- climbing the ladder up to the roof would fail due to lack of room)
	local use_place = nil;
	if(     not( flat_roof) and (sizex <  sizez )) then
		use_place = pr:next(1,2);
	elseif( not( flat_roof) and (sizex >= sizez )) then
		use_place = pr:next(3,4);
	end
	-- select one of the four reserved places
	local res = basic_houses.get_random_place( p, sizex, sizez, ladder_places, use_place, -1, 1, pr );
	local ladder_node = {name=basic_houses.ladder, param2 = res.p2};
	-- actually place the ladders
	for height=p.y+1, p.y + ladder_height do
		vm:set_node_at( {x=res.x, y=height, z=res.z}, ladder_node );
	end
	return res.used;
end

-- place the door into one of the reserved places
basic_houses.place_door = function( p, sizex, sizez, door_places, wall_with_ladder, floor_height, vm, pr )

	local res = basic_houses.get_random_place( p, sizex, sizez, door_places, -1, wall_with_ladder, 0, pr );
	vm:set_node_at( {x=res.x, y=p.y+1, z=res.z}, {name=basic_houses.door_bottom, param2 = 0 });
	vm:set_node_at( {x=res.x, y=p.y+2, z=res.z}, {name=basic_houses.door_top, param2 = 0});
	-- light so that the door can be found
	vm:set_node_at( {x=res.x, y=p.y+3, z=res.z}, {name=basic_houses.lamp});

	-- add some light to the upper floors as well
	for i,height in ipairs( floor_height ) do
		if( i>2) then
			vm:set_node_at( {x=res.x,y=height-1,z=res.z},{name=basic_houses.lamp});
		end
	end
	return res.used;
end

-- the chest is placed on one of the upper floors; it contains
-- additional building material
basic_houses.place_chest = function( p, sizex, sizez, chest_places, wall_with_ladder, floor_height, vm, materials, pr )
	-- not each building needs a chest
	if( pr:next(1,2)>1 ) then
		return;
	end

	local res = basic_houses.get_random_place( p, sizex, sizez, chest_places, -1, wall_with_ladder, 1, pr );
	local height = floor_height[ pr:next(2,math.max(2,#floor_height))];
	-- translate wallmounted (for ladder) to facedir for chest
	res.p2 = res.p2;
	if(     res.p2 == 5 ) then
		res.p2n = 2;
	elseif( res.p2 == 4 ) then
		res.p2n = 0;
	elseif( res.p2 == 3 ) then
		res.p2n = 3;
	elseif( res.p2 == 2 ) then
		res.p2n = 1;
	end
	-- determine target position
	local pos = {x=res.x, y=height+1, z=res.z};
	-- if plasterwork is installed: place a machine
	if( materials.color and minetest.global_exists("plasterwork")) then -- and pr:next(1,10)==1) then
		vm:set_node_at( pos, {name=materials.walls, param2 = materials.color});
		local pos2 = {x=res.x, y=height+2, z=res.z};
		vm:set_node_at( pos2, {name="plasterwork:machine", param2 = res.p2n});
		-- if we are operating inside handle_schematics, pos2 will not relate to the real world;
		-- it will just be a data structure. Therefore, we can't change the world at those coordinates.
		if( not( vm.is_fake_vm )) then
			minetest.registered_nodes[  "plasterwork:machine" ].after_place_node(pos2, nil, nil);
			local meta = minetest.get_meta( pos2);
			meta:set_string( "target_node",  materials.walls );
			meta:set_int(    "target_color", materials.color );
		end
		return;
	end
	-- place the chest
	vm:set_node_at( pos, {name=basic_houses.chest, param2 = res.p2n});
	-- if we are operating inside handle_schematics, positions do not directly correspond
	-- to real map positions; we can't change the map directly at this time. Therefore,
	-- we're finished for now.
	if( vm.is_fake_vm ) then
		return;
	end
	-- fill chest with building material
	minetest.registered_nodes[ basic_houses.chest ].on_construct( pos );
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory();
	local c = pr:next(1,4);
	for i=1,c do
		local stack_name = materials.walls.." "..pr:next(1,99);
		if( materials.color ) then
			stack_name = minetest.itemstring_with_palette( stack_name, materials.color );
		end
		inv:add_item( "main", stack_name );
	end
	inv:add_item( "main", materials.first_floor.." "..pr:next(1,49) );
	c = pr:next(1,2);
	for i=1,c do
		inv:add_item( "main", materials.ceiling.." "..pr:next(1,99) );
	end
	inv:add_item( "main", materials.glass.." "..pr:next(1,20) );
	if( not( materials.roof_flat )) then
		inv:add_item( "main", materials.roof.." "..pr:next(1,99) );
		inv:add_item( "main", materials.roof_middle.." "..pr:next(1,49) );
	end
end


-- locate a place for the "hut"
basic_houses.simple_hut_find_place = function( heightmap, minp, maxp, sizex, sizez, minheight, maxheight )

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
	return {p1={x=p.x - sizex, y=p.y, z=p.z - sizez }, p2=p, sizex=sizex, sizez=sizez};
end


-- chooses random materials, amount of floors etc.;
-- sets data.materials and data.p2.ymax
basic_houses.simple_hut_get_materials = function( data, amount_in_this_mapchunk, chunk_ends_at_height, pr )
	-- select some random materials, height etc.
	-- wood is always useful
	local wood_types = replacements_group['wood'].found;
	local wood       = wood_types[ pr:next(1,math.max(1,#wood_types))];
	local wood_roof  = wood_types[ pr:next(1,math.max(1,#wood_types))];
	-- choose random materials
	local materials = {
		walls = nil,
		color = nil,
		gable = nil,
		glass         = basic_houses.glass[ pr:next( 1,math.max(1,#basic_houses.glass ))],
		roof          = replacements_group['wood'].data[ wood_roof ][7], -- stair
		roof_middle   = replacements_group['wood'].data[ wood_roof ][8], -- slab
		first_floor   = basic_houses.floor,
		ceiling       = wood_types[ pr:next(1,math.max(1,#wood_types))],
		wall_orients  = {0,1,2,3},
		glass_orients = {12,18,9,7},
	};

	-- windows 3 nodes high, 2 high, or just 1?
	local r = pr:next(1,6);
	if(     r==1 or r==2) then
		materials.window_at_height = {0,1,1,1,0};
	elseif( r==3 or r==4 or r==5) then
		materials.window_at_height = {0,0,1,1,0};
	else
		materials.window_at_height = {0,0,1,0,0};
	end

	-- how many floors will the house have?
	local max_floors_possible = math.floor((chunk_ends_at_height-1-data.p2.y)/#materials.window_at_height);
	if( pr:next(1,5)==1) then
		materials.floors = pr:next(1,math.min(8,math.max(1,max_floors_possible-1)));
	else
		materials.floors = pr:next(1,math.min(4,math.max(1,max_floors_possible-1)));
	end


	-- some houses may have a flat roof instead of a saddle roof
	materials.flat_roof = false;
	if( pr:next(1,2)==1) then
		materials.flat_roof = true;
	end

	-- path around the house so that the door is accessible
	materials.around_house = basic_houses.around_house[ pr:next(1, #basic_houses.around_house )];
	-- which wall material shall be used?
	if( minetest.global_exists("plasterwork") and pr:next(1,2)==1 ) then
		-- colored plasterwork
		materials.walls = plasterwork.node_list[ pr:next(1, #plasterwork.node_list)];
		materials.color = pr:next(0,255);
	else
		local r = pr:next(1,3);
		-- wooden house
		if(     r==1 ) then
			materials.walls = wood;
			-- wooden houses with more than 3 floors would be strange
			materials.floors = pr:next(1, math.min( 3, math.max(3,max_floors_possible-1 )));
			-- flat roofs do not look good on them either
			materials.flat_roof = false;
			-- vertical wood is also pretty decorative
			if( pr:next(1,2)==1 ) then
				materials.wall_orients = {12,18,9,7};
			end
		-- tree logs
		elseif( r==2 ) then
			materials.walls = replacements_group['wood'].data[ wood ][4]; -- tree trunk
			-- log cabins with more than 2 floors are unlikely
			materials.floors = pr:next(1, math.min( 2, math.max(2,max_floors_possible-1 )));
			-- log cabins do not have a flat roof either
			materials.flat_roof = false;
			materials.wall_orients = {12,18,9,7};
		else
			materials.walls = basic_houses.walls[ pr:next(1,#basic_houses.walls)];
		end
	end
	-- if there are less than three houses in a mapchunk: do not place skyscrapers
	if( amount_in_this_mapchunk < 3 ) then
		-- use saddle roof instead of flat one
		materials.roof_flat = false;
		-- at max two floors
		materials.floors = math.min( 2, materials.floors );
	end

	materials.gable = materials.walls;
	if( pr:next(1,3)==1 ) then
		materials.gable = wood_types[ pr:next(1,#wood_types)];
	end

	local height = materials.floors * #materials.window_at_height +1;
	if( materials.flat_roof ) then
		data.p2.ymax = math.min( chunk_ends_at_height, data.p2.y + height + math.ceil( math.min( data.sizex, data.sizez )/2 ));
	else
		data.p2.ymax = math.min( chunk_ends_at_height, data.p2.y + height + 4);
	end
	data.p2.ymax = math.min( chunk_ends_at_height, data.p2.ymax );
	data.materials = materials;


	-- place windows at even or odd rows? -> create some variety
	local window_at_odd_row = false;
	if( pr:next(1,2)==1 ) then
		window_at_odd_row = true;
	end

	-- place where a door or ladder might be added (no window there);
	-- we need to avid adding ladders directly in front of windows or
	-- placing doors right next to glass panes because that would look ugly
	local special_wall_1 = pr:next(3,math.max(3,math.min(data.sizex,data.sizez)-3));
	local special_wall_2 = pr:next(3,math.max(3,math.min(data.sizex,data.sizez)-3));
	if( special_wall_2 == special_wall_1 ) then
		special_wall_2 = special_wall_2 - 1;
		if( special_wall_2 < 3 ) then
			special_wall_2 = 4;
		end
	end

--[[
	local wall_height = #materials.window_at_height;
-- TODO: size (1x x, 1x z)
	for lauf = 1, size do
		local wall_1_has_window = false;
		local wall_2_has_window = false;
		-- the corners never get glass
		if( lauf>1 and lauf<size ) then
			-- *one* of the walls may get a window - never both (would look odd to
			-- be able to see through the house)
			local not_special = ( (lauf ~= special_wall_1) and (lauf ~= special_wall_2));
			if( window_at_odd_row == (lauf%2==1)) then
				wall_1_has_window = (not_special and ( pr:next(1,3)~=3));
			else
				wall_2_has_window = (not_special and ( pr:next(1,3)~=3));
			end
		end
	end
--]]
	-- aliases would have no content_id for placement
	for k, v in pairs(data.materials) do
		if(v and type(v)=="string") then
			if(minetest.registered_aliases[v]) then
				data.materials[k] = minetest.registered_aliases[v]
			end
			-- avoid crashes - even if that requires placing air
			if(not(minetest.registered_nodes[data.materials[k]])) then
				data.materials[k] = "air"
			end
		end
	end
	return data;
end


-- actually build the "hut"
-- parameter:
--   data.p2                    end point
--   data.sizex, data.sizez     size in x and z direction
--   materials.window_at_height table containing window positions (vertically)
--   materials.walls            node type of the walls
--   materials.color            0-255; color of the walls (if materials.walls uses hardware coloring)
--   materials.first_floor      node type for the bottommost floor
--   materials.ceiling          node type for the floors/ceilings
--   materials.around_house     node type for one node wide path around the house
--   materials.floors           how many floors does the house have?
--   materials.flat_roof        if true: add a flat roof; else saddle roof
--   pr                         PseudoRandom number generator for reproducability
basic_houses.simple_hut_place_hut_using_vm = function( data, materials, vm, pr )
	local p = data.p2;
	local sizex = data.sizex-1;
	local sizez = data.sizez-1;
	-- house too small or too large
	if( sizex < 3 or sizez < 3 or sizex>64 or sizez>64) then
		return nil;
	end

	-- replaicate the pattern of windows for the other floors
	local first_floor_height = #materials.window_at_height;
	local floor_height = {p.y};
	local floor_materials = {{name=materials.first_floor}};
	for i=1,materials.floors-1 do
		for k=2,first_floor_height do
			table.insert( materials.window_at_height, materials.window_at_height[k]);
		end
		table.insert( floor_height, floor_height[ #floor_height] + first_floor_height-1);
		table.insert( floor_materials, {name=materials.ceiling});
	end
	table.insert( floor_height, floor_height[ #floor_height] + first_floor_height-1);
	if( materials.flat_roof ) then
		-- the upper floor will form the roof of the house and is made out of
		-- its wall material
		table.insert( floor_materials, {name=materials.walls, param2 = (materials.color or 12)});
		table.insert( materials.window_at_height, 0 );
	else
		-- the house uses a saddle roof; the ceiling will use wood
		table.insert( floor_materials, {name=materials.ceiling, param2 = (materials.color or 12)});
	end

	local p_start = {x=p.x-sizex+1, y=p.y-1, z=p.z-sizez+1};
	-- build the two walls in x direction
	local s1 = basic_houses.build_two_walls(p_start, sizex-2, sizez-2, true,  materials, vm, pr ); --12, 18, vm );
	-- build the two walls in z direction
	local s2 = basic_houses.build_two_walls(p_start, sizex-2, sizez-2, false, materials, vm, pr ); -- 9,  7, vm );

	-- each floor is 4 blocks heigh
	local roof_starts_at = p.y + (4*materials.floors);
	p_start = {x=p.x-sizex, y=roof_starts_at, z=p.z-sizez, ymax = p.ymax};
	-- make the roof one higher - so that players/mobs can stay upright on
	-- each roof floor node - this makes it easier to build staircases
	p_start.y = p_start.y+1;
	-- build the roof
	if( materials.flat_roof ) then
		-- build a flat roof
		p_start.y = p_start.y-1; -- no need to make that higher
	elseif( sizex < sizez ) then
		basic_houses.build_roof_and_gable(p_start, sizex, sizez, true,  materials, 1, 3, vm );
	else
		basic_houses.build_roof_and_gable(p_start, sizex, sizez, false, materials, 0, 2, vm );
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

	local around_house_node = {name=materials.around_house, param2=0};
	local air_node = {name="air"};
	for dx = p.x-sizex, p.x do
		-- path around the house
		vm:set_node_at( {x=dx, y=p.y,   z=p.z-sizez}, around_house_node );
		vm:set_node_at( {x=dx, y=p.y,   z=p.z      }, around_house_node );
		-- make sure there is no snow blocking entrance
		vm:set_node_at( {x=dx, y=p.y+1, z=p.z-sizez}, air_node );
		vm:set_node_at( {x=dx, y=p.y+1, z=p.z      }, air_node );
	end
	for dz = p.z-sizez+1, p.z-1 do
		-- path around the house
		vm:set_node_at( {x=p.x-sizex, y=p.y,   z=dz}, around_house_node );
		vm:set_node_at( {x=p.x,       y=p.y,   z=dz}, around_house_node );
		-- make sure there is no snow blocking entrance
		vm:set_node_at( {x=p.x-sizex, y=p.y+1, z=dz}, air_node );
		vm:set_node_at( {x=p.x,       y=p.y+1, z=dz}, air_node );
	end


	-- index 1 and 2 are offsets in any of the walls; index 3 indicates if the
	-- windows start at odd indices or not
	local reserved_places = {s1[1], s1[2], s2[1], s2[2], s1[3], s2[3]};
	p_start = {x=p.x-sizex, y=p.y, z=p.z-sizez};
	local wall_with_ladder = basic_houses.place_ladder( p_start, sizex, sizez,
		reserved_places, #materials.window_at_height-1, materials.flat_roof, vm, pr );

	basic_houses.place_door( p_start, sizex, sizez, reserved_places, wall_with_ladder, floor_height, vm, pr );
	basic_houses.place_chest( p_start, sizex, sizez, reserved_places, wall_with_ladder, floor_height, vm, materials, pr );

	-- return where the hut has been placed
	return {p1={x=p.x - sizex, y=p.y, z=p.z - sizez }, p2=p};
end


-- get the voxelmanip object and place the house in there
basic_houses.simple_hut_place_hut = function( data, materials, pr )
	local p = data.p2;
	local sizex = data.sizex-1;
	local sizez = data.sizez-1;
	-- house too small or too large
	if( sizex < 3 or sizez < 3 or sizex>64 or sizez>64) then
		return nil;
	end
	print( "  Placing house at "..minetest.pos_to_string( p ));

	local vm = minetest.get_voxel_manip();
	vm:read_from_map(
		{x=p.x - sizex, y=p.y-1, z=p.z - sizez },
		{x=p.x, y=p.ymax, z=p.z});
	basic_houses.simple_hut_place_hut_using_vm( data, materials, vm, pr )
	vm:write_to_map(true);
end


basic_houses.simple_hut_get_size_and_place = function( heightmap, minp, maxp)
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
	return basic_houses.simple_hut_find_place( heightmap, minp, maxp, sizex, sizez, 2, 1000 );
end

local villages = {}

local function get_village_info(minp, maxp)
	local half_avg = math.floor(basic_houses.village_average/2)
	local anchor_pos_x = minp.x - (minp.x % basic_houses.village_average) + half_avg
	local anchor_pos_z = minp.z - (minp.z % basic_houses.village_average) + half_avg

	local seed = minetest.get_mapgen_params().seed + (anchor_pos_x * 65536 + anchor_pos_z) * 10
	if villages[seed] then
		return villages[seed]
	end

	local rng = PseudoRandom(seed)
	local ret = {
			seed = seed,
			pos_x = anchor_pos_x + rng:next(-half_avg, half_avg),
			pos_z = anchor_pos_z + rng:next(-half_avg, half_avg),
			size = rng:next(basic_houses.village_min_size, basic_houses.village_max_size),
			anz_houses = rng:next(basic_houses.min_per_mapchunk, basic_houses.max_per_mapchunk)
	}
	print("basic_houses: possible village "..seed.." at ("..ret.pos_x.." x "..ret.pos_z.."), size:"..ret.size..", desity: "..ret.anz_houses)
	villages[seed] = ret
	return ret
end

local function check_pos(village, pos)
	local distance = math.hypot(village.pos_x - pos.x, village.pos_z - pos.z)
	if distance <= village.size then
		return true
	end
end


-- mg_villages takes precedence; however, both mods can work together; it's just that mg_villages
-- has to take care of all the things at mapgen time
if(not(minetest.get_modpath("mg_villages"))) then
   minetest.register_on_generated(function(minp, maxp, seed)
	if( minp.y < -64 or minp.y > 500) then
		return;
	end
	local village = get_village_info(minp, maxp)

	if village.pos_x < minp.x or village.pos_x > maxp.x or
			village.pos_z < minp.z or village.pos_z > maxp.z then
		return
	end

	local heightmap = minetest.get_mapgen_object('heightmap');
	local houses_placed = 0;
	local house_data = {};
	for i=1, village.anz_houses do
		local res = basic_houses.simple_hut_get_size_and_place( heightmap, minp, maxp);
--		print(village.seed, i, res)
		if( res and res.p1 and res.p2
				and res.p2.x>=minp.x and res.p2.z>=minp.z
				and res.p2.x<=maxp.x and res.p2.z<=maxp.z) then
			if check_pos(village, res.p2) then
				handle_schematics.mark_flat_land_as_used(heightmap, minp, maxp,
						res.p2.i,
						(res.p2.x-res.p1.x),
						(res.p2.z-res.p1.z));
				table.insert( house_data, res );
				houses_placed = houses_placed + 1;
			end
		end
	end
	-- use the same material around the houses in the entire mapchunk
	local around_house_material = nil;
	for i,data in ipairs( house_data ) do
		-- initialize pseudorandom number generator
		local pr = PseudoRandom( data.p2.x + data.p2.z );
		local res = basic_houses.simple_hut_get_materials( data, #house_data, maxp.y+16, pr );
		if( not( around_house_material )) then
			around_house_material = res.materials.around_house;
		else
			res.materials.around_house = around_house_material;
		end
		basic_houses.simple_hut_place_hut( data, res.materials, pr );
	end

	if houses_placed > 0 then
		print("basic_houses: Placed building in chunk:"..houses_placed)
	end
   end);
end


-- interface for handle_schematics for manual generation of houses
basic_houses.get_parameter = function( pos, sizex, sizez, sizey, pr )
	local data = { p2={x=pos.x+sizex, y=pos.y, z=pos.z+sizez}, sizex=sizex, sizez=sizez, sizey=sizey};
	-- it needs at least 3 houses in this mapchunk in order to generate a flat roof
	local amount_in_this_mapchunk = 100;
	-- how heigh can the building become at max?
	local chunk_ends_at_height = data.p2.y+1+sizey;
	-- suggest random materials and other values
	local res = basic_houses.simple_hut_get_materials( data, amount_in_this_mapchunk, chunk_ends_at_height, pr )
	-- these parameters are needed as well
	res.p2    = data.p2;
	res.sizex = data.sizex;
	res.sizez = data.sizez;
	res.sizey = data.sizey;
	return res;
end


-- for manual placement with handle_schematics and/or mg_villages;
-- vm may be a fake VoxelManip data structure
-- returns a value != nil (actually the start and end position) if successful
basic_houses.generate_random_hut_at_pos = function( pos, sizex, sizez, sizey, seed, vm )
	-- prepare the data structure containing position and size
	local data = { p2 = {x=pos.x+sizex, y=pos.y, z=pos.z+sizez}, sizex = sizex, sizez = sizez };
	-- initialize pseudorandom number generator for reproducability
	local pr = PseudoRandom( seed );
	-- if the second parameter is greater than 3, houses with a flat roof can be generated
	local res = basic_houses.simple_hut_get_materials( data, 4, pos.y+sizey+1, pr );
	-- no need to assure a walkable path to the entrance if we are dealing with mods
	-- that ensure that by diffrent means (mg_villages = flat land; build chest from
	-- handle_schematics = player places manually); dirt with grass is a general
	-- placeholder for the biome surface
	res.materials.around_house = "default:dirt_with_grass";
	-- place the house into the vm data structure
	local res = basic_houses.simple_hut_place_hut_using_vm( data, data.materials, vm, pr )
	-- the structure is burried one node deep (=floor)
	vm.yoff = 0;
	-- the fake voxelmanip data structure contains all the data we need
	return vm;
end


build_chest.add_entry( {'generate building','basic_houses', 'basic_houses.generator'});
build_chest.add_building( 'basic_houses.generator',
	{ generator=basic_houses.generate_random_hut_at_pos,
	} );
