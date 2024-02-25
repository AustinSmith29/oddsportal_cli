#!/bin/bash

# This script will print out the data collected from the `scrape-ml` script
# in a more human readable way.

while read line
do
    home_odds=$(echo "$line" | cut -d, -f1)
    away_odds=$(echo "$line" | cut -d, -f2)
    home_team=$(echo "$line" | cut -d, -f3)
    away_team=$(echo "$line" | cut -d, -f3)
    away_team=$(echo "$line" | cut -d, -f4)
    game_time=$(echo "$line" | cut -d, -f6)
    home_score=$(echo "$line" | cut -d, -f7)
    away_score=$(echo "$line" | cut -d, -f8)
    echo "$(date -d @$game_time -Idate) $away_team ($away_odds) @ $home_team ($home_odds) $away_score - $home_score"
done