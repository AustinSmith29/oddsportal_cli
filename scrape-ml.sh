#!/bin/bash
#
# This script will fetch all moneyline odds (in decimal) for every game in a nba 
# season from an endpoint behind oddsportal.com.
#
# The output of this script will print out a line for every game in the form:
# Home Team Odds,Away Team Odds,Home Team,Away Team,Status,Timestamp,Final Home Score, Final Away Score
# With the range of `Status` being 0,1,2. 0 = Not Completed | 1 = Home Win | 2 = Away Win
# With `Timestamp` being the unix epoch time in seconds.
# If `Status` = 0, then Home Score and Away Score will both be set to 0.

version="v0.1.0\n"
usage="Usage: scrape-ml [OPTION]... LEAGUE
Fetch all moneyline odds from oddsportal.com for every game in the given league.

Uses decimal odds.

Supported LEAGUE options: mlb, nba
  -h    display this help and exit
  -v    output version information and exit
"

LEAGUE=$1

while getopts "hvy:" arg; do
  case $arg in
    h)
      echo "$usage"
      exit
      ;;
    v)
      echo -e $version
      exit
      ;;
    *)
      echo "$usage"
      exit
  esac
done

declare -A league_codes
league_codes["mlb"]="Sj67Y5TK"
league_codes["nba"]="IoGXixRr"

if [ -z $LEAGUE ]; then
    echo "Error: No league was given. Exiting."
    echo "$usage"
    exit
fi

if [ -z ${league_codes[$LEAGUE]} ]; then
    echo "Error: Unknown league [$LEAGUE] was given. Exiting."
    echo "$usage"
    exit
fi

# Lets get some user cookies, which are needed to hit the odds api.
# Some question remains whether or not the method to fetch user cookies,
# will work at some future point in time as I suspect that weird string 
# sequence in the url is tied to some expiration token generated server side.
curl \
  --cookie-jar cookies.txt \
  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0" \
   https://www.oddsportal.com/ajax-user-data/t/72955/?1708659794032abcd424b4312e7087f434ef1c0094 > /dev/null

# The odds api uses a trailing time parameter, in ms since the start of unix 
# epoch, I'm guessing to timeout old requests, so we will need to generate a 
# time.
let t_ms=$(date +%s)*1000

# The odds api pages the results so we need to keep track of which page we're on
page=1
while :
do
    # Now we should be able to hit the api and save the output to a file.
    curl "https://www.oddsportal.com/ajax-sport-country-tournament-archive_/3/${league_codes[$LEAGUE]}/X0/1/0/page/$page/?_=$t_ms" \
    --cookie cookies.txt \
    --compressed \
    -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate, br' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H 'Content-Type: application/json' \
    -H 'Connection: keep-alive' \
    -H 'Referer: https://www.oddsportal.com/basketball/usa/nba/results/' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Sec-GPC: 1' \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    -H 'TE: trailers' | jq '.' > odds.json

    jq -rc '.d.rows[] | [
        .odds[0].avgOdds,
        .odds[1].avgOdds,
        .["home-name"],
        .["away-name"],
        if .["home-winner"] == null then 0 elif .["home-winner"] == "win" then 1 else 2 end, 
        .["date-start-timestamp"],
        .homeResult,
        .awayResult
    ]' < odds.json > output.txt
    tr -d []\" < output.txt

    # If there are no bets then we break from the loop because we are assuming we went past the paging limit
    n_bets=$(wc -l output.txt | cut -f1 -d' ')
    total_bets=$(echo "${n_bets} + ${total_bets}" | bc)
    if [ $n_bets -eq "0" ]
    then
        break
    fi
    page=$(echo "${page} + 1" | bc)
done

# cleanup
rm cookies.txt
rm output.txt
rm odds.json