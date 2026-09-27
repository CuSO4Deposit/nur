{
  lib,
  writeShellApplication,
  android-tools,
  scrcpy,
  gawk,
}:

writeShellApplication {
  name = "scrcpy-connect";
  runtimeInputs = [
    android-tools
    scrcpy
    gawk
  ];
  text = builtins.readFile ./scrcpy-connect.sh;
  meta = {
    description = "Connect to an Android phone over USB or WiFi and start scrcpy";
    mainProgram = "scrcpy-connect";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
