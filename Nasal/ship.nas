var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var alt = "position/altitude-ft";
var heading = "orientation/heading-deg";
var roll_deg = "orientation/roll-deg";
var speed = "velocities/airspeed-kt";
var pitch = "orientation/pitch-deg";
var max_speed= "sim/SDM/max-speed-kt";
var max_rudder_d = "sim/SDM/max-rudder-deflection-deg";
var rudder_adv = "sim/SDM/max-rudder-advance";
var roll_factor = "sim/SDM/roll-factor";
var glide_factor = "sim/SDM/glide-factor";
var pitch_factor = "sim/SDM/pitch-factor";
var plane_speed = "sim/SDM/plane-speed";
var rudder_pos = "sim/SDM/controls/rudder-pos-norm";
var throttle = "controls/engines/engine[0]/throttle";
var aileron = "controls/flight/aileron-filtered";
var aileron0 = "controls/flight/aileron0";
var ele = "controls/flight/elevator";
var lat = "position/latitude-deg";
var lon = "position/longitude-deg";
var bow_x = "sim/SDM/ship[0]/bow-x";
var bow_lat = "sim/SDM/bow-lat-deg";
var bow_lon = "sim/SDM/bow-lon-deg";
var stern_x = "sim/SDM/ship[0]/stern-x";
var stern_y = "sim/SDM/ship[0]/stern-y";
var looptime = 0.05;


var init = func {
		#setprop ("ai/models/aircraft[0]/position/latitude-deg" , (getprop ("/position/latitude-deg")));
		#setprop ("ai/models/aircraft[0]/position/longitude-deg" , (getprop ("/position/longitude-deg")));
		#setprop ("ai/models/aircraft[0]/position/altitude-ft" , (getprop ("/position/altitude-ft")));
		#setprop ("ai/models/aircraft[0]/orientation/true-heading-deg" , (getprop ("/orientation/heading-deg")));
		setprop ("controls/flight/lateral-mode","roll");
		main_loop();
}

var main_loop = func {
		update_controls ();
		update_throttle ();
		update_orientation ();
		check_ground();
		update_waveloop();
		update_AI_position ();
		rate = looptime;
 		settimer(main_loop, rate);
}

var update_AI_position = func {
		var tspeed = getprop("controls/flight/target-spd");
		var cspeed = getprop("velocities/airspeed-kt");
		if (cspeed<tspeed) {
			cspeed += looptime;
		} else {
			cspeed -= looptime;
		}
		setprop("velocities/airspeed-kt",cspeed);
		setprop("velocities/groundspeed-kt",cspeed);
		var coord = geo.aircraft_position();
		var push = getprop("sim/model/pushback/target-speed-fps");
		if (push == nil) push = 0;
		var push2 = getprop("sim/model/pushback/position-norm");
		if (push2 == nil) push2 = 0;
		if (push2 != 1) push2 = 0;
		push *= push2;
		coord.apply_course_distance(getprop ("orientation/heading-deg"), looptime*cspeed*NM2M/(60*60)+looptime*push*FT2M);
		setprop ("position/latitude-deg", coord.lat());
		setprop ("position/longitude-deg", coord.lon());
		#setprop ("position/altitude-ft" , 0);
		#setprop ("orientation/pitch-deg", 0);
}

var update_controls = func {
	
		var ail = getprop (aileron);

		var head = getprop ("orientation/heading-deg");
		#print(head);
		#print(head+ail*getprop(rudder_adv));
		var push = getprop("sim/model/pushback/target-speed-fps");
		if (push == nil) push = 0;
		var push2 = getprop("sim/model/pushback/position-norm");
		if (push2 == nil) push2 = 0;		
 		interpolate ("orientation/heading-deg", head+ail*getprop(rudder_adv)*push2*getprop (throttle)*0.5+ail*getprop(rudder_adv)*push2*push, looptime);
		
	}

var update_orientation = func {
		#adjust roll
		var roll = getprop(roll_factor) * getprop (speed)* getprop (speed) * getprop (aileron)*getprop(rudder_adv);
		#print (roll);
		setprop (roll_deg, roll);
		# adjust climb while planing

		# adjust pitch
		var pitchup = getprop (pitch_factor)* getprop (speed) + (getprop ("sim/SDM/environment/waveloop-norm")*0.5);
		setprop (pitch, pitchup);
}

var update_throttle = func {
		# just a simple throttle for now
		var rev = getprop("controls/rev");
		if (rev == nil) rev = 1;
		var throttle = getprop ("controls/flight/throttle-filtered") * getprop(max_speed);
		throttle =throttle * getprop("sim/speed-up");

		setprop ("controls/flight/target-spd", throttle*rev);
}

var check_ground = func {
		# set Boat to Sea Level and rise a bit when planing, check wether we are in water at all
		var ground = geodinfo(getprop (lat), getprop (lon));
		var alt0 = getprop("position/altitude-ft");
		#print ("Alt0: ", alt0);

		if (ground != nil and ground[1] != nil) {
				var solid = ground[1].solid;
				var type = ground[1].names[0];
				if ( solid ) {
						setprop (speed, 0);
						print ("Ran aground");
						alt0 = ground[0] *M2FT;
				}
		} 
		#var alt1 = (alt0+10.2)*FT2M;
		#alt0 = 0;
		var elev = geo.elevation(getprop (lat), getprop (lon));
		if (elev != nil) {
			alt0 = elev*M2FT;
		}
		if (getprop (speed) > getprop (plane_speed)) {
				# print ("planing");
				var climb = getprop(glide_factor) * ( getprop (speed) - getprop (plane_speed));
				alt0 = alt0+climb;
		}
		if (alt0 < 0) {
			#alt0 = 0; some waters are below 0
		}
		setprop ("position/altitude-ft",alt0);
		#print (getprop (lat)," ",type," ",alt0);
}

var update_waveloop = func () {
		var wave_amp = getprop ("sim/SDM/environment/wave-amp");
		var wave_count = getprop ("sim/SDM/environment/waveloop-count");
		var wave_norm = getprop ("sim/SDM/environment/waveloop-norm");
		var wind = getprop("environment/wind-speed-kt");
		#print (wave_norm);
		var next = wave_count + wave_amp;
		setprop ("sim/SDM/environment/waveloop-count", next);
		setprop ("sim/SDM/environment/waveloop-norm",math.sin( next )*wind*0.2);
}

setlistener("/sim/signals/fdm-initialized",init);

########### Thunder sounds (from c172p) ###################

var speed_of_sound = func (t, re) {
    # Compute speed of sound in m/s
    #
    # t = temperature in Celsius
    # re = amount of water vapor in the air

    # Compute virtual temperature using mixing ratio (amount of water vapor)
    # Ratio of gas constants of dry air and water vapor: 287.058 / 461.5 = 0.622
    var T = 273.15 + t;
    var v_T = T * (1 + re/0.622)/(1 + re);

    # Compute speed of sound using adiabatic index, gas constant of air,
    # and virtual temperature in Kelvin.
    return math.sqrt(1.4 * 287.058 * v_T);
};

var thunder_listener = func {
    var thunderCalls = 0;

    var lightning_pos_x = getprop("/environment/lightning/lightning-pos-x");
    var lightning_pos_y = getprop("/environment/lightning/lightning-pos-y");
    var lightning_distance = math.sqrt(math.pow(lightning_pos_x, 2) + math.pow(lightning_pos_y, 2));

    # On the ground, thunder can be heard up to 16 km. Increase this value
    # a bit because the aircraft is usually in the air.
    if (lightning_distance > 20000)
        return;

    var t = getprop("/environment/temperature-degc");
    var re = getprop("/environment/relative-humidity") / 100;
    var delay_seconds = lightning_distance / speed_of_sound(t, re);

    # Maximum volume at 5000 meter
    var lightning_distance_norm = std.min(1.0, 1 / math.pow(lightning_distance / 5000.0, 2));

    settimer(func {
        var thunder1 = getprop("sound/thunder1");
        var thunder2 = getprop("sound/thunder2");
        var thunder3 = getprop("sound/thunder3");

        if (!thunder1) {
            thunderCalls = 1;
            setprop("sound/dist-thunder1", lightning_distance_norm *  1.5);
        }
        else if (!thunder2) {
            thunderCalls = 2;
            setprop("sound/dist-thunder2", lightning_distance_norm * 1.5);
        }
        else if (!thunder3) {
            thunderCalls = 3;
            setprop("sound/dist-thunder3", lightning_distance_norm * 1.5);
        }
        else
            return;

        # Play the sound (sound files are about 9 seconds)
        play_thunder("thunder" ~ thunderCalls, 9.0, 0);
    }, delay_seconds);
};

var play_thunder = func (name, timeout=0.1, delay=0) {
    var sound_prop = "sound/" ~ name;

    settimer(func {
        # Play the sound
        setprop(sound_prop, 1);

        # Reset the property after timeout so that the sound can be
        # played again.
        settimer(func {
            setprop(sound_prop, 0);
        }, timeout);
    }, delay);
};

setlistener("/environment/lightning/lightning-pos-y", thunder_listener);