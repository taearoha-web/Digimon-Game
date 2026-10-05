#!/usr/bin/env bash
# Helper used during development: filters noisy audio-driver lines from Godot output.
filter_godot() {
  grep -v "^$" | grep -iv "alsa\|audio driver\|libpulse\|dummy driver\|audio_server.cpp\|init_output_device\|snd_\|pcm.c\|confmisc\|conf.c:"
}
