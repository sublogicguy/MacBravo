-- HoneycombBravoMacHelper - a Honeycomb Bravo Apple silicon driver
-- Based on HoneycombBravoHelper for Linux https://gitlab.com/honeycomb-xplane-linux
-- Author:		Daniel Peukert
-- Verion:		0.0.3
-- License:		GNU GPLv3
-- Modified for MacOS by Joe Milligan

local bitwise = require 'bit'

-- Helper functions
function int_to_bool(value)
	if value == 0 then
		return false
	else
		return true
	end
end

function get_ap_state(array)
	if array[0] >= 1 then
		return true
	else
		return false
	end
end

function array_has_true(array)
	for i = 0, 7 do
		if array[i] == 1 then
			return true
		end
	end

	return false
end

-- LED definitions
local LED_FCU_HDG =			{1, 1}
local LED_FCU_NAV =			{1, 2}
local LED_FCU_APR =			{1, 3}
local LED_FCU_REV =			{1, 4}
local LED_FCU_ALT =			{1, 5}
local LED_FCU_VS =			{1, 6}
local LED_FCU_IAS =			{1, 7}
local LED_FCU_AP =			{1, 8}
local LED_LDG_L_GREEN =		{2, 1}
local LED_LDG_L_RED =		{2, 2}
local LED_LDG_N_GREEN =		{2, 3}
local LED_LDG_N_RED =		{2, 4}
local LED_LDG_R_GREEN =		{2, 5}
local LED_LDG_R_RED =		{2, 6}
local LED_ANC_MSTR_WARNG =	{2, 7}
local LED_ANC_ENG_FIRE =	{2, 8}
local LED_ANC_OIL =			{3, 1}
local LED_ANC_FUEL =		{3, 2}
local LED_ANC_ANTI_ICE =	{3, 3}
local LED_ANC_STARTER =		{3, 4}
local LED_ANC_APU =			{3, 5}
local LED_ANC_MSTR_CTN =	{3, 6}
local LED_ANC_VACUUM =		{3, 7}
local LED_ANC_HYD =			{3, 8}
local LED_ANC_AUX_FUEL =	{4, 1}
local LED_ANC_PRK_BRK =		{4, 2}
local LED_ANC_VOLTS =		{4, 3}
local LED_ANC_DOOR =		{4, 4}

-- Support variables & functions for sending LED data via HID
local bravo = hid_open(10571, 6401)

if bravo == nil then
	logMsg('HoneycombBravoMacHelper | Error: Unable to connect to the Honeycomb Bravo throttle quadrant')
else
	local buffer = {}

	local master_state = false
	local buffer_modified = false

	function get_led(led)
		return buffer[led[1]][led[2]]
	end

	function set_led(led, state)
		if state ~= get_led(led) then
			buffer[led[1]][led[2]] = state
			buffer_modified = true
		end
	end

	function all_leds_off()
		for bank = 1, 4 do
			buffer[bank] = {}
			for bit = 1, 8 do
				buffer[bank][bit] = false
			end
		end

		buffer_modified = true
	end

	function send_hid_data()
		local data = {}

		for bank = 1, 4 do
			data[bank] = 0

			for bit = 1, 8 do
				if buffer[bank][bit] == true then
					data[bank] = bitwise.bor(data[bank], bitwise.lshift(1, bit - 1))
				end
			end
		end

		local bytes_written = hid_send_filled_feature_report(bravo, 0, 65, data[1], data[2], data[3], data[4]) -- 65 = 1 byte (report ID) + 64 bytes (data)

		if bytes_written == -1 then
			logMsg('HoneycombBravoMacHelper | Error: Feature report write failed, an error occured')
		elseif bytes_written < 65 then
			logMsg('HoneycombBravoMacHelper | Error: Feature report write failed, only '..bytes_written..' bytes written')
		else
			buffer_modified = false
		end
	end

	-- Initialize our default state
	all_leds_off()
	send_hid_data()
	hid_open(10571, 6401) -- MacOS Bravo must be reopened for .joy axes to operate

	-- Change LEDs when their underlying dataref changes
	-- Bus voltage as a master LED switch
	local bus_voltage = dataref_table('sim/cockpit2/electrical/bus_volts')

    -- Configure the dataref(s) below to match the correct modes needed for your aircraft in xPlane settings HJM

	-- Autopilot
	local hdg = dataref_table('sim/cockpit2/autopilot/heading_mode')
	local nav = dataref_table('sim/cockpit2/autopilot/nav_status')
	local apr = dataref_table('sim/cockpit2/autopilot/approach_status')
	local rev = dataref_table('sim/cockpit2/autopilot/backcourse_status')
	local alt = dataref_table('sim/cockpit2/autopilot/altitude_hold_status')
	local vs = dataref_table('sim/cockpit2/autopilot/vvi_status')
	local ias = dataref_table('sim/cockpit2/autopilot/autothrottle_on')

	local ap = dataref_table('sim/cockpit2/autopilot/servos_on')

	-- Landing gear LEDs
	local gear = dataref_table('sim/flightmodel2/gear/deploy_ratio')

	-- Annunciator panel - top row
	local master_warn = dataref_table('sim/cockpit2/annunciators/master_warning')
	local fire = dataref_table('sim/cockpit2/annunciators/engine_fires')
	local oil_low_p = dataref_table('sim/cockpit2/annunciators/oil_pressure_low')
	local fuel_low_p = dataref_table('sim/cockpit2/annunciators/fuel_pressure_low')
	local anti_ice = dataref_table('sim/cockpit2/annunciators/pitot_heat')
	local starter = dataref_table('sim/cockpit2/engine/actuators/starter_hit')
	local apu = dataref_table('sim/cockpit2/electrical/APU_running')

	-- Annunciator panel - bottom row
	local master_caution = dataref_table('sim/cockpit2/annunciators/master_caution')
	local vacuum = dataref_table('sim/cockpit2/annunciators/low_vacuum')
	local hydro_low_p = dataref_table('sim/cockpit2/annunciators/hydraulic_pressure')
	local aux_fuel_pump_l = dataref_table('sim/cockpit2/fuel/transfer_pump_left')
	local aux_fuel_pump_r = dataref_table('sim/cockpit2/fuel/transfer_pump_right')
	local parking_brake = dataref_table('sim/cockpit2/controls/parking_brake_ratio')
	local volt_low = dataref_table('sim/cockpit2/annunciators/low_voltage')
	local canopy = dataref_table('sim/flightmodel2/misc/canopy_open_ratio')
	local doors = dataref_table('sim/flightmodel2/misc/door_open_ratio')
	local cabin_door = dataref_table('sim/cockpit2/annunciators/cabin_door_open')

	function handle_led_changes()
		if bus_voltage[0] > 0 then
			master_state = true

			-- HDG
			set_led(LED_FCU_HDG, get_ap_state(hdg))

			-- NAV
			set_led(LED_FCU_NAV, get_ap_state(nav))

			-- APR
			set_led(LED_FCU_APR, get_ap_state(apr))

			-- REV
			set_led(LED_FCU_REV, get_ap_state(rev))

			-- ALT
			local alt_bool

			if alt[0] > 1 then
				alt_bool = true
			else
				alt_bool = false
			end

			set_led(LED_FCU_ALT, alt_bool)

			-- VS
			set_led(LED_FCU_VS, get_ap_state(vs))

			-- IAS
			set_led(LED_FCU_IAS, get_ap_state(ias))

			-- AUTOPILOT
			set_led(LED_FCU_AP, int_to_bool(ap[0]))

			-- Landing gear
			local gear_leds = {}

			for i = 1, 3 do
				gear_leds[i] = {nil, nil} -- green, red

				if gear[i - 1] == 0 then
					-- Gear stowed
					gear_leds[i][1] = false
					gear_leds[i][2] = false
				elseif gear[i - 1] == 1 then
					-- Gear deployed
					gear_leds[i][1] = true
					gear_leds[i][2] = false
				else
					-- Gear moving
					gear_leds[i][1] = false
					gear_leds[i][2] = true
				end
			end

			set_led(LED_LDG_N_GREEN, gear_leds[1][1])
			set_led(LED_LDG_N_RED, gear_leds[1][2])
			set_led(LED_LDG_L_GREEN, gear_leds[2][1])
			set_led(LED_LDG_L_RED, gear_leds[2][2])
			set_led(LED_LDG_R_GREEN, gear_leds[3][1])
			set_led(LED_LDG_R_RED, gear_leds[3][2])

			-- MASTER WARNING
			set_led(LED_ANC_MSTR_WARNG, int_to_bool(master_warn[0]))

			-- ENGINE FIRE
			set_led(LED_ANC_ENG_FIRE, array_has_true(fire))

			-- LOW OIL PRESSURE
			set_led(LED_ANC_OIL, array_has_true(oil_low_p))

			-- LOW FUEL PRESSURE
			set_led(LED_ANC_FUEL, array_has_true(fuel_low_p))

			-- ANTI ICE
			set_led(LED_ANC_ANTI_ICE, not int_to_bool(anti_ice[0]))

			-- STARTER ENGAGED
			set_led(LED_ANC_STARTER, array_has_true(starter))

			-- APU
			set_led(LED_ANC_APU, int_to_bool(apu[0]))

			-- MASTER CAUTION
			set_led(LED_ANC_MSTR_CTN, int_to_bool(master_caution[0]))

			-- VACUUM
			set_led(LED_ANC_VACUUM, int_to_bool(vacuum[0]))

			-- LOW HYD PRESSURE
			set_led(LED_ANC_HYD, int_to_bool(hydro_low_p[0]))

			-- AUX FUEL PUMP
			local aux_fuel_pump_bool

			if aux_fuel_pump_l[0] == 2 or aux_fuel_pump_r[0] == 2 then
				aux_fuel_pump_bool = true
			else
				aux_fuel_pump_bool = false
			end

			set_led(LED_ANC_AUX_FUEL, aux_fuel_pump_bool)

			-- PARKING BRAKE
			local parking_brake_bool

			if parking_brake[0] > 0 then
				parking_brake_bool = true
			else
				parking_brake_bool = false
			end

			set_led(LED_ANC_PRK_BRK, parking_brake_bool)

			-- LOW VOLTS
			set_led(LED_ANC_VOLTS, int_to_bool(volt_low[0]))

			-- DOOR
			local door_bool = false

			if canopy[0] > 0.01 then
				door_bool = true
			end

			if door_bool == false then
				for i = 0, 9 do
					if doors[i] > 0.01 then
						door_bool = true
						break
					end
				end
			end

			if door_bool == false then
				door_bool = int_to_bool(cabin_door[0])
			end

			set_led(LED_ANC_DOOR, door_bool)
		elseif master_state == true then
			-- No bus voltage, disable all LEDs
			master_state = false
			all_leds_off()
		end

		-- If we have any LED changes, send them to the device
		if buffer_modified == true then
			send_hid_data()
		end
	end

	do_every_frame('handle_led_changes()')

	function exit_handler()
		all_leds_off()
		send_hid_data()
	end

	do_on_exit('exit_handler()')
end

-- Register commands for switching autopilot modes used by the rotary encoder
local mode = 'IAS'

function setMode(modeString)
	mode = modeString
end

create_command(
	'HoneycombBravoMacHelper/mode_ias',
	'Set autopilot rotary encoder mode to IAS.',
	'setMode("IAS")',
	'',
	''
)

create_command(
	'HoneycombBravoMacHelper/mode_crs',
	'Set autopilot rotary encoder mode to CRS.',
	'setMode("CRS")',
	'',
	''
)

create_command(
	'HoneycombBravoMacHelper/mode_hdg',
	'Set autopilot rotary encoder mode to HDG.',
	'setMode("HDG")',
	'',
	''
)

create_command(
	'HoneycombBravoMacHelper/mode_vs',
	'Set autopilot rotary encoder mode to VS.',
	'setMode("VS")',
	'',
	''
)

create_command(
	'HoneycombBravoMacHelper/mode_alt',
	'Set autopilot rotary encoder mode to ALT.',
	'setMode("ALT")',
	'',
	''
)

-- Register commands for changing values of the selected autopilot mode with the rotary encoder
local airspeed_is_mach = dataref_table('sim/cockpit2/autopilot/airspeed_is_mach')
local airspeed = dataref_table('sim/cockpit2/autopilot/airspeed_dial_kts_mach')
local course = dataref_table('sim/cockpit2/radios/actuators/nav1_obs_deg_mag_pilot')
local heading = dataref_table('sim/cockpit2/autopilot/heading_dial_deg_mag_pilot')
local vs = dataref_table('sim/cockpit2/autopilot/vvi_dial_fpm')
local altitude = dataref_table('sim/cockpit2/autopilot/altitude_dial_ft')

function change_value(increase)
	local sign

	if increase == true then
		sign = 1
	else
		sign = -1
	end

	if mode == 'IAS' then
		if airspeed_is_mach[0] == 1 then
			-- Float math is not precise, so we have to round the result
			airspeed[0] = math.max(0, (math.floor((airspeed[0] * 100) + 0.5) + sign) / 100)
		else
			airspeed[0] = math.max(0, (math.floor(airspeed[0] / 10) + sign) * 10)
		end
	elseif mode == 'CRS' then
		if course[0] == 0 and sign == -1 then
			course[0] = 359
		else
			course[0] = (course[0] + sign) % 360
		end
	elseif mode == 'HDG' then
		if heading[0] == 0 and sign == -1 then
			heading[0] = 359
		else
			heading[0] = (heading[0] + sign) % 360
		end
	elseif mode == 'VS' then
		vs[0] = math.floor((vs[0] / 100) + sign) * 100
	elseif mode == 'ALT' then
		altitude[0] = math.floor((altitude[0] / 100) + sign) * 100
	end
end

create_command(
	'HoneycombBravoMacHelper/increase',
	'Increase the value of the autopilot mode selected with the rotary encoder.',
	'change_value(true)',
	'',
	''
)

create_command(
	'HoneycombBravoMacHelper/decrease',
	'Decrease the value of the autopilot mode selected with the rotary encoder.',
	'change_value(false)',
	'',
	''
)

-- Register commands for keeping thrust reversers (all or separate engines) on while the commands are active
local reversers = dataref_table('sim/cockpit2/engine/actuators/prop_mode')

function get_prop_mode(state)
	if state == true then
		return 3
	else
		return 1
	end
end

function reversers_all(state)
	for i = 0, 7 do
		reversers[i] = get_prop_mode(state)
	end
end

function reverser(engine, state)
	reversers[engine - 1] = get_prop_mode(state)
end

create_command(
	'HoneycombBravoMacHelper/thrust_reversers',
	'Hold all thrust reversers on.',
	'reversers_all(true)',
	'',
	'reversers_all(false)'
)

for i = 1, 8 do
	create_command(
		'HoneycombBravoMacHelper/thrust_reverser_'..i,
		'Hold thrust reverser #'..i..' on.',
		'reverser('..i..', true)',
		'',
		'reverser('..i..', false)'
	)
end
