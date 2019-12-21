var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var alt = "position/altitude-ft";
var heading = "orientation/heading-deg";
var roll_deg = "orientation/model/roll-deg";
var speed = "ai/models/aircraft[0]/velocities/true-airspeed-kt";
var pitch = "ai/models/aircraft[0]/orientation/pitch-deg";
var max_speed= "sim/SDM/max-speed-kt";
var max_rudder_d = "sim/SDM/max-rudder-deflection-deg";
var rudder_adv = "sim/SDM/max-rudder-advance";
var roll_factor = "sim/SDM/roll-factor";
var glide_factor = "sim/SDM/glide-factor";
var pitch_factor = "sim/SDM/pitch-factor";
var plane_speed = "sim/SDM/plane-speed";
var rudder_pos = "sim/SDM/controls/rudder-pos-norm";
var throttle = "controls/engines/engine[0]/throttle";
var aileron = "controls/flight/aileron";
var aileron0 = "controls/flight/aileron0";
var ele = "controls/flight/elevator";
var lat = "position/latitude-deg";
var lon = "position/longitude-deg";
var bow_x = "sim/SDM/ship[0]/bow-x";
var bow_lat = "sim/SDM/bow-lat-deg";
var bow_lon = "sim/SDM/bow-lon-deg";
var stern_x = "sim/SDM/ship[0]/stern-x";
var stern_y = "sim/SDM/ship[0]/stern-y";
var looptime = 0.01;


var init = func {
		setprop ("ai/models/aircraft[0]/position/latitude-deg" , (getprop ("/position/latitude-deg")));
		setprop ("ai/models/aircraft[0]/position/longitude-deg" , (getprop ("/position/longitude-deg")));
		setprop ("ai/models/aircraft[0]/position/altitude-ft" , (getprop ("/position/altitude-ft")));
		setprop ("ai/models/aircraft[0]/orientation/true-heading-deg" , (getprop ("/orientation/heading-deg")));
		setprop ("ai/models/aircraft[0]/controls/flight/lateral-mode","roll");
		main_loop();
}

var main_loop = func {
		update_AI_position ();
		update_controls ();
		update_throttle ();
		update_orientation ();
		check_ground();
		update_waveloop();		rate = looptime / getprop( "sim/speed-up");
 		settimer(main_loop, rate);
}

var update_AI_position = func {
		setprop ("position/latitude-deg" , (getprop ("ai/models/aircraft[0]/position/latitude-deg")));
		setprop ("position/longitude-deg" , (getprop ("ai/models/aircraft[0]/position/longitude-deg")));
		#setprop ("position/altitude-ft" , (getprop ("/ai/models/aircraft[0]/position/altitude-ft")));
		setprop ("orientation/pitch-deg" , (getprop ("ai/models/aircraft[0]/orientation/pitch-deg")));
		if ( getprop ("ai/models/aircraft[0]/velocities/true-airspeed-kt") > 1) {
				setprop ("orientation/heading-deg" , (getprop ("ai/models/aircraft[0]/orientation/true-heading-deg")));
		} else {
				setprop ("ai/models/aircraft[0]/orientation/true-heading-deg", getprop ("orientation/heading-deg") );
		}
}

var update_controls = func {
		# first damp the control input a bit

		var ail = getprop (aileron);

		var head = getprop ("ai/models/aircraft[0]/orientation/true-heading-deg");
		#print(head);
		#print(getprop(speed));

		var ail1 = getprop (rudder_pos);
		var rudderadv = getprop (rudder_adv);
		var aildiff = abs (ail1 - ail);
		#print (aildiff);
		if (aildiff > rudderadv) {
				adv = getprop ( rudder_adv );
				if ( ail > ail1 ) {
						ail1 = ail1 + adv;
				} else {
						ail1 = ail1 - adv;
				}
				setprop ( rudder_pos , ail1);
		}	
		#print (ail1, " ", ail);
		var steer = head + 0.02*ail1 * (getprop (speed));
		if (steer > 360 ) { 
				steer = steer - 360;
		}
		if (steer < 0 ) {
				steer =steer + 360;
		}
		#print (steer);

 		interpolate ("ai/models/aircraft[0]/orientation/true-heading-deg", steer, looptime);
		setprop (aileron0, ail);
	}

var update_orientation = func {
		#adjust roll
		var roll = getprop(roll_factor) * getprop (speed)* getprop (speed) * getprop (rudder_pos);
		#print (roll);
		setprop (roll_deg, roll);
		# adjust climb while planing

		# adjust pitch
		var pitchup = getprop (pitch_factor)* getprop (speed) + (getprop ("sim/SDM/environment/waveloop-norm")*0.42);
		setprop (pitch, pitchup);
}

var update_throttle = func {
		# just a simple throttle for now
		var throttle = getprop ("controls/engines/engine[0]/throttle") * getprop(max_speed);
				throttle =throttle * getprop("sim/speed-up");

		setprop ("ai/models/aircraft[0]/controls/flight/target-spd", throttle);
}

var check_ground = func {
		# set Boat to Sea Level and rise a bit when planing, check wether we are in water at all
		var ground = geodinfo(getprop (lat), getprop (lon));
		var solid = ground[1].solid;
		var type = ground[1].names[0];
		if ( solid ) {
				setprop (speed, 0);
				print ("ALARM ! cpt we Ran aground");
		}

		var alt0 = ground[0] *M2FT;
		if (getprop (speed) > getprop (plane_speed)) {
				# print ("planing");
				var climb = getprop(glide_factor) * ( getprop (speed) - getprop (plane_speed));
				alt0 = alt0+climb;
		}
		setprop ("position/altitude-ft",alt0);
		#print (getprop (lat)," ",type," ",alt0);


}

var update_waveloop = func () {
		var wave_amp = getprop ("sim/SDM/environment/wave-amp");
		var wave_count = getprop ("sim/SDM/environment/waveloop-count");
		var wave_norm = getprop ("sim/SDM/environment/waveloop-norm");
		#print (wave_norm);
		var next = wave_count + wave_amp;
		setprop ("sim/SDM/environment/waveloop-count", next);
		setprop ("sim/SDM/environment/waveloop-norm",math.sin( next ));
}

setlistener("/sim/signals/fdm-initialized",init);






