## SmoothCam

SmoothCam is a cinematic utility for Garry's Mod which provides smooth and precise camera movement along defined paths.

One of the main features of this utility is that the smoothing can be framerate-locked, allowing for the guaranteed rendering of every single frame. However, third-party video editing software must be used to remove any duplicate frames as a result of lag.

### Usage

```
] smoothcam help
SmoothCam: Made by Billy (STEAM_0:1:40314158)

SmoothCam: TIP: You can press E (your +use bind) to cancel playing a sequence
SmoothCam: TIP: Sine in/out easing is on by default. To turn it off for a linear sequence, use the linear command.

SmoothCam: help
SmoothCam: Shows this list of commands

SmoothCam: play
SmoothCam: Plays the currently setup sequence

SmoothCam: reset
SmoothCam: Resets all smooth camera points

SmoothCam: add
SmoothCam: Adds a new camera point where you are standing & looking

SmoothCam: remove
SmoothCam: Removes the last camera point

SmoothCam: remove <index>
SmoothCam: Removes the camera point at the given index

SmoothCam: list
SmoothCam: Lists all setup camera points

SmoothCam: time <seconds>
SmoothCam: Sets the playback time in seconds for the entire sequence.

SmoothCam: fps <frames>
SmoothCam: Locks the FPS for the entire sequence.
SmoothCam: Set this to 0 to unlock the framerate.
SmoothCam: sv_cheats must be on for FPS < 30

SmoothCam: ease
SmoothCam: Enables easeInOutSine easing for each point.

SmoothCam: linear
SmoothCam: Disables any easing.

SmoothCam: save <name>
SmoothCam: Saves the camera points to a file with the given name

SmoothCam: load <name>
SmoothCam: Loads the camera points from the file with the given name

SmoothCam: forget <name>
SmoothCam: Deletes the camera points file with the given name

SmoothCam: saved
SmoothCam: Lists all saved camera point files
```