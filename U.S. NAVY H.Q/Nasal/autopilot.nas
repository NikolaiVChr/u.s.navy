## BOEING 717 NASAL AUTOPILOT FUNCTIONS
#######################################

var heading_prop = props.globals.getNode("autopilot/settings/heading", 1);
var pitch_prop = props.globals.getNode("autopilot/settings/altitude", 1);
var speed_prop = props.globals.getNode("autopilot/settings/speed", 1);

var set_heading = func(setting)
 {
 if (heading_prop.getValue() == setting)
  {
  heading_prop.setValue("dg-heading-hold");
  }
 else
  {
  heading_prop.setValue(setting);
  }
 };
var set_pitch = func(setting)
 {
 if (pitch_prop.getValue() == setting)
  {
  pitch_prop.setValue("altitude-hold");
  }
 else
  {
  pitch_prop.setValue(setting);
  }
 };
var set_speed = func(setting)
 {
 if (speed_prop.getValue() == setting)
  {
  speed_prop.setValue("");
  }
 else
  {
  speed_prop.setValue(setting);
  }
 };

var open_dialog = func
 {
 var dialog = gui.Dialog.new("sim/gui/dialogs/autopilot/dialog", "Aircraft/717/Systems/autopilot-dlg.xml");
 dialog.open();
 };

var set_vert_speed = func
 {
 var altitude = props.globals.getNode("instrumentation/altimeter[0]/indicated-altitude-ft", 1);
 var altitude_setting = props.globals.getNode("autopilot/settings/target-altitude-ft", 1);
 var vertspeed_setting = props.globals.getNode("autopilot/settings/vertical-speed-fpm", 1);

 if (altitude.getValue() != nil and altitude_setting.getValue() != nil and vertspeed_setting.getValue() != nil and math.abs(altitude.getValue() - altitude_setting.getValue()) > 100)
  {
  if (altitude.getValue() > altitude_setting.getValue() and vertspeed_setting.getValue() >= 0)
   {
   vertspeed_setting.setValue(-1000);
   }
  elsif (altitude.getValue() < altitude_setting.getValue() and vertspeed_setting.getValue() <= 0)
   {
   vertspeed_setting.setValue(1800);
   }
  }
 };
setlistener("autopilot/settings/target-altitude-ft", set_vert_speed, 1, 0);
