# FearConditioning

This program is used to perform standard associative fear conditioning in animals. The program itself has gone through several versions and has had multiple contributors over the years. The current version is considered version 3.2, and is more-or-less a complete re-write of previous versions.

The basic purpose of the program is to perform associative fear conditioning in rats. In other words, a sound is played and a foot shock is given at the same time. When the rats hear the sound and feel the foot shock at the same time, they associate they sound with the foot shock. Therefore, they will present fearful behavior (typically "freezing" behavior) on future presentations of the sound (even if the sound is not paired with the foot-shock again).

There are multiple hardware components that are necessary in order for this software to work. Here are all of the components:

1. A cage with a shock-floor - these are commercially available, or you can build your own.
2. A shock stimulation unit - we like to be able to send the unit a TTL pulse as a signal to initiate the shock
3. A "sound board" - we are using an Arduino Uno connected to an Adafruit "Music Maker" MP3 shield. There are 2 Arduinos in the entire hardware setup, and this Arduino that controls the sounds is considered the "slave" Arduino. It receives commands from the master Arduino as to which sounds to play. An SD card inserted in the Adafruit Music Maker MP3 shield contains the actual audio files.
4. A "master" Arduino board which controls signals being sent to the "sound board" as well as to the shock unit and the VNS stimulator.
5. A neural stimulator if you plan on using it in your study. We use an AM Systems 2100 stimulator to deliver vagus nerve stimulation (VNS).
6. A computer running Matlab

In the current version of the code that is present in this repository, the Arduino code was written by a multiple people from TxBDC including Phillip Gonzalez, Eric Meyers, and David Pruitt. The Matlab code in previous versions was primarily written by Eric Meyers, but for this version (version 3.0 and onward) a complete re-write was performed by David Pruitt. Any questions about this repository may be directed towards David Pruitt.
