-- Known issues:
--   * cavegen may eat holes into the ground below the house
--   * panes (glass or bars) right next to a door look bad
--   * wall parts where glass panes might be will sometimes be colored strangely
--     (which actually looks intresting most of the time)
--   * glass windows look wrong due to their param2 not beeing 0 (they are
--     "filled" partly)
--   * trees, plants and snow inside the house are not cleared

simple_houses = {};

-- generate at max this many houses per mapchunk;
-- Note: This amount will likely only spawn if your mapgen is very flat.
--       Else you will see far less houses.
simple_houses.max_per_mapchunk = 20;

-- used for adding colored clay and coral as material for house walls
local palette = "unifieddyes_palette_extended.png";

--[[
-- trouble with that: digging clay only gives you the uncolored lumps,
-- and there is no way to craf the colored one yet; repairs to houses
-- would be impossible; additionally, the default node would get some
-- unwanted color attched and no longer be white
--
minetest.override_item( "default:clay", {
                        paramtype2 = "color",
                        palette = palette,
		});

minetest.override_item( "default:coral_skeleton", {
                        paramtype2 = "color",
                        palette = palette,
		});
--]]

-- these two nodes look very good when colored
minetest.register_node("simple_houses:painted_clay", {
        description = "Painted clay",
        tiles = {"default_clay.png"},
        is_ground_content = false,
        groups = {oddly_breakable_by_hand=3,cracky=3,snappy=3,sappy=3},
        paramtype2 = "color",
        palette = palette,
        });

minetest.register_node("simple_houses:painted_wall", {
        description = "Painted house wall",
        tiles = {"default_coral_skeleton.png"},
        is_ground_content = false,
        groups = {oddly_breakable_by_hand=3,cracky=3,snappy=3,sappy=3},
        paramtype2 = "color",
        palette = palette,
        });


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
	local r = math.random(1,5);
	if(r==1) then
		walls = "default:"..wood1.."tree";
	elseif(r==2) then
		walls = "simple_houses:painted_clay";
		color = math.random(0,255);
	elseif(r==3) then
		walls = "simple_houses:painted_wall";
		color = math.random(0,255);
	end
	local gable = "default:"..wood2.."wood";
	if( math.random(1,2)==1) then
		gable = walls;
	end
	-- glass can be glass panes, iron bars or solid glass
	local glass_materials = {"xpanes:pane_flat","default:glass","xpanes:bar_flat"};
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
	local window_at_odd_row = false;
	if( math.random(1,2)==1 ) then
		window_at_odd_row = true;
	end

	local dz = p.z;
	for dx = p.x-sizex+1, p.x-1 do
	local m1 = materials.walls;
	local m2 = materials.walls;
	if( dx>p.x-sizex+1 and dx<p.x-2 and (window_at_odd_row == (dx%2==1))) then
		if( math.random(1,2)==1) then
			m1 = materials.glass;
		end
		if( math.random(1,2)==1) then
			m2 = materials.glass;
		end
	end
	-- param2 (orientation or color) for the first two walls
	local w1_c = (materials.color or 12); -- wall 1 color
	local w2_c = (materials.color or 18); -- wall 2 color
	for dy = p.y, p.y+4 do
		-- build two walls in x direction
		if( window_at_height[ dy-p.y+1 ]==1 and (m1==materials.glass or m2==materials.glass)) then
			vm:set_node_at( {x=dx,y=dy,z=dz-1      }, {name=m1, param2=12});
			vm:set_node_at( {x=dx,y=dy,z=dz-sizez+1}, {name=m2, param2=18});
		else
			vm:set_node_at( {x=dx,y=dy,z=dz-1      }, {name=materials.walls, param2=w1_c});
			vm:set_node_at( {x=dx,y=dy,z=dz-sizez+1}, {name=materials.walls, param2=w2_c});
		end
	end
	end
	local dx = p.x;
	for dz = p.z-sizez+1, p.z-1 do
	local m1 = materials.walls;
	local m2 = materials.walls;
	if( dz>p.z-sizez+1 and dz<p.z-2 and ( window_at_odd_row == (dz%2==1))) then
		if( math.random(1,2)==1) then
			m1 = materials.glass;
		end
		if( math.random(1,2)==1) then
			m2 = materials.glass;
		end
	end
	-- param2 (orientation or color) for the other two walls
	local w3_c = (materials.color or 9); -- wall 3 color
	local w4_c = (materials.color or 7); -- wall 4 color
	for dy = p.y, p.y+4 do
		-- build two walls in z direction
		if( window_at_height[ dy-p.y+1 ]==1 and (m1==materials.glass or m2==materials.glass)) then
			vm:set_node_at( {x=dx-1,      y=dy,z=dz}, {name=m1, param2=9});
			vm:set_node_at( {x=dx-sizex+1,y=dy,z=dz}, {name=m2, param2=7});
		else
			vm:set_node_at( {x=dx-1,      y=dy,z=dz}, {name=materials.walls, param2=w3_c});
			vm:set_node_at( {x=dx-sizex+1,y=dy,z=dz}, {name=materials.walls, param2=w4_c});
		end
	end
	end

	local do_ceiling = ( math.min( sizex, sizez )>4 );
	-- floor and ceiling
	for dx = p.x-sizex+2, p.x-2 do
	for dz = p.z-sizez+2, p.z-2 do
		-- a brick roof
		vm:set_node_at( {x=dx,y=p.y,  z=dz}, {name=materials.floor});
		if( do_ceiling ) then
			vm:set_node_at( {x=dx,y=p.y+4,z=dz}, {name=materials.ceiling});
		end
	end
	end

	-- we need a door
	local door_pos = {x=p.x-1, y=p.y+1, z=p.z-1};
	local r = math.random(1,4);
	-- door is in x wall
	if( r==1 or r==2 ) then
		door_pos.x = math.random( p.x-sizex+2, p.x-2 );
		if( r==2 ) then
			door_pos.z = p.z-sizez+1;
		else
			door_pos.z = p.z-1;
		end
	-- dor is in z wall
	else
		door_pos.z = math.random( p.z-sizez+2, p.z-2 );
		if( r==2 ) then
			door_pos.x = p.x-sizex+1;
		else
			door_pos.x = p.x-1;
		end
	end
	vm:set_node_at( door_pos, {name="doors:door_wood_a", param2 = 0 });
	vm:set_node_at( {x=door_pos.x, y=door_pos.y+1, z=door_pos.z}, {name="doors:hidden"});
	-- light so that the door can be found
	vm:set_node_at( {x=door_pos.x, y=door_pos.y+2, z=door_pos.z}, {name="default:meselamp"});

	-- roof
	local g_color = materials.color or 0; -- color of the gable
	if( sizex <= sizez ) then
		local xhalf = math.floor( sizex/2 );
		local dy = p.y+5;
		for dx = 0,xhalf do
		for dz = p.z-sizez, p.z do
			vm:set_node_at( {x=p.x-sizex+dx,y=dy,z=dz}, {name=materials.roof, param2=1});
			vm:set_node_at( {x=p.x-      dx,y=dy,z=dz}, {name=materials.roof, param2=3});
		end
		dy = dy+1;
		end

		-- if sizex is not even, then we need to use slabs at the heighest point
		if( sizex%2==0 ) then
		for dz = p.z-sizez, p.z do
			vm:set_node_at( {x=p.x-xhalf,y=p.y+6+xhalf-1,z=dz}, {name=materials.roof_middle});
		end
		end
	
		-- Dachgiebel (=gable)
		for dx = 0,xhalf do
		for dy = p.y+5, p.y+4+dx do
			vm:set_node_at( {x=p.x-sizex+dx,y=dy,z=p.z-sizez+1}, {name=materials.gable, param2=g_color});
			vm:set_node_at( {x=p.x-      dx,y=dy,z=p.z-sizez+1}, {name=materials.gable, param2=g_color});
	
			vm:set_node_at( {x=p.x-sizex+dx,y=dy,z=p.z      -1}, {name=materials.gable, param2=g_color});
			vm:set_node_at( {x=p.x-      dx,y=dy,z=p.z      -1}, {name=materials.gable, param2=g_color});
		end
		end
	else
		local zhalf = math.floor( sizez/2 );
		local dy = p.y+5;
		for dz = 0,zhalf do
		for dx = p.x-sizex, p.x do
			vm:set_node_at( {x=dx,y=dy,z=p.z-sizez+dz}, {name=materials.roof, param2=0});
			vm:set_node_at( {x=dx,y=dy,z=p.z-      dz}, {name=materials.roof, param2=2});
		end
		dy = dy+1;
		end

		-- if sizex is not even, then we need to use slabs at the heighest point
		if( sizez%2==0 ) then
		for dx = p.x-sizex, p.x do
			vm:set_node_at( {x=dx,y=p.y+6+zhalf-1,z=p.z-zhalf}, {name=materials.roof_middle});
		end
		end
	
		-- Dachgiebel (=gable)
		for dz = 0,zhalf do
		for dy = p.y+5, p.y+4+dz do
			vm:set_node_at( {x=p.x-sizex+1,y=dy,z=p.z-sizez+dz}, {name=materials.gable, param2=g_color});
			vm:set_node_at( {x=p.x-sizex+1,y=dy,z=p.z-      dz}, {name=materials.gable, param2=g_color});
	
			vm:set_node_at( {x=p.x      -1,y=dy,z=p.z-sizez+dz}, {name=materials.gable, param2=g_color});
			vm:set_node_at( {x=p.x      -1,y=dy,z=p.z-      dz}, {name=materials.gable, param2=g_color});
		end
		end
	end
		
	vm:write_to_map(true);
	-- return where the hut has been placed
	return {p1={x=p.x - sizex, y=p.y, z=p.z - sizez }, p2=p};
end

simple_houses.simple_hut_generate = function( heightmap, minp, maxp)
	if( minp.y < -64 or minp.y > 500 or not(heightmap)) then
		return;
	end
	-- halfway reasonable house sizes
	local maxsize = 14;
	if( math.random(1,5)==1) then
		maxsize = 18;
	end
	local sizex = math.random(7,maxsize);
	local sizez = math.max( 7, math.min( maxsize, math.random( math.floor(sizex/4), sizex*2 )));
	-- chooses random materials and a random place without destroying the landscape
	-- minheight 2: one above water level; avoid below water level and places on ice
	return simple_houses.simple_hut_find_place_and_build( heightmap, minp, maxp, sizex, sizez, 2, 1000 );
end

minetest.register_on_generated(function(minp, maxp, seed)
	local heightmap = minetest.get_mapgen_object('heightmap');
	for i=1,simple_houses.max_per_mapchunk do
		local res = simple_houses.simple_hut_generate( heightmap, minp, maxp);
		if( res and res.p1 and res.p2 ) then
			local offset = maxp.x - minp.x - (res.p2.x-res.p1.x);
			local i = res.p2.i;
			-- mark the place where the house has been spawned as unusable (occupied)
			for dz = res.p1.z, res.p2.z do
				for dx = res.p1.x, res.p2.x do
					heightmap[ i ] = -1000;
					i = i-1;
				end
				i = i - offset;
			end
		else
			return;
		end
	end
end);
