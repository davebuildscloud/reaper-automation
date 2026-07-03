# reaper-automation
A set of .lua scripts for the Reaper DAW to automate the processing of recordings.

To use, save these files to your local workstation.  In Reaper, open the Actions window (type a `?` on mac), click `New Action`, then `Load ReaScript`
Select each of the 9 .lua files one at a time and click `OK` to add them to the action list.

Once they are in the list, create a new Reaper project and drag/drop your .wav files into Reaper as a single track.  From there, go back to the actions menu and run the lua commands in order.

Concert-Recording-1.lua will set the project standards and save it with the name you specify.
Concert-Recording-2.lua will rename your initial multi-file track to Source and confirm the number of files making up the track
Concert-Recording-3.lua will explode the polyphonic .wav files into one track per channel in the source files.  It also sets the source folder depth to 0 to remove hierarchy.
Concert-Recording-4.lua will set the pan values per track.  These are set based on my recording setup and preferences.  Edit to meet your requirements.
Concert-Recording-5.lua will set the mix levels for the final master output.  Again, based on my setup and preferences.
Concert-Recording-6.lua will adds an EQ profile that I created "concert-recording".  Again, this is tuned on my recording setup and what sounds best to my ear.
Concert-Recording-7.lua will normalize the audio - helpful when you're using different types of microphones and have variable levels in a given recording.
Concert-Recording-8.lua validates that the previous steps have all completed successfully and that you'll get good output.
Concert-Recording-9 exports the final product to a single .flac file.  You can track this out further as needed.

A few things worth noting:
1. This was based on my system - a Zoom F8NPro, 2 Neumann KM-184 (cardioids), 2 Neumann KM-185 (hyper-cardioids), and 2 DPA 4017-B shotgun mics (super-cardioid).
2. The goal here was to be able to get an entire concert set lightly edited and converted to flac between performances at a festival.  20 shows in one weekend generates a lot of data.
3. Best practice : never work from your only copy of a recording.  Preserve your originals and work from a secondary copy.  These don't delete any files, but if it alters your recordings in a way you don't like, make sure you can recover.
4. I'm sharing this to be a nice guy.  Feel free to share it with others, but include my original scripts if/when you do.
5. Use at your own risk.  I'm not responsible for anything bad that happens.
