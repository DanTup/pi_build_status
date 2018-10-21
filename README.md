# Raspberry Pi Build Status

Some simple scripts to show project build statuses on my Pi's Unicorn Hat HD. This project is not intended to be usable by others directly, but is public in case the code is useful.

It runs on my Pi in a cron job via Docker during office hours:

```
0,15,30,45  7,8,9,10,11,12,13,14,15,16,17 * * 1,2,3,4 docker run --rm dantup/pi_build_status
0 18 * * 1,2,3,4 docker run --rm dantup/pi_build_status bin/off.dart
```

![Raspberry Pi with Dart Code and Flutter Build Statuses](https://user-images.githubusercontent.com/1078012/47268938-f0dd4b00-d54e-11e8-8c61-47acc9d462b9.jpg)

<img width="1410" alt="Web based Build Statuses for Dart Code and Flutter" src="https://user-images.githubusercontent.com/1078012/47268939-f0dd4b00-d54e-11e8-9a06-c532b28132f2.png">
