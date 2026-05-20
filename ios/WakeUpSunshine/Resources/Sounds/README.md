# Alarm Sound Files

Place the 4 custom `.caf` audio files here:

| Filename       | ID       | Display Name   |
|----------------|----------|----------------|
| sunrise.caf    | sunrise  | Sunrise        |
| birds.caf      | birds    | Morning Birds  |
| bells.caf      | bells    | Temple Bells   |
| classic.caf    | classic  | Classic Alarm  |

The app falls back to a system sound if a file is missing.
To convert MP3/WAV to CAF: `afconvert -f caff -d LEI16 input.wav output.caf`
