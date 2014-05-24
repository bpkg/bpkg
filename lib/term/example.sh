#!/bin/bash

## include
. term.sh

## data
declare -a data=( 0 2 3 1 3 3 3 8 2 12 4 2 4 3 )

## clean up everything
cleanup () {
  ## clear
  term clear screen
  ## bring back cursor
  term cursor show
  return 0
}

## on SIGINT signal
onsigint () {
  cleanup
  exit 1
}

## clear screen
term clear screen

## position to top left
term move 0 0

## clear line
term clear line

## hide cursor
term cursor hide

## catch sigint
trap "onsigint" SIGINT


## main loop
{
  let pad=3
  let n=0
  let w=($(tput cols))
  let h=($(tput lines))
  let x=0
  let y=0
  let len="${#data[@]}"

  term clear screen

  term move ${pad} 1

  ## y axis
  for (( n = 0; n < (h - pad - 1); n += 2 )); do
    term transition 0 2
    term color gray
    printf "."
  done

  y=( ${h} - 2 )
  term move ${pad} ${y}

  ## x axis
  for (( n = 0; n < (w - pad * 3); n += 6)); do
    term color gray
    printf "."
    term transition 6 0
  done

  x=0
  for (( i = 0; i < len; ++i )); do
    let n="${data[$i]}"
    while (( n-- )); do
      if (( n < 0 )); then
        break
      fi
      let a=( ${x} * 6 + ${pad} )
      let b=( ${h} - ${n} + ${pad} )
      #echo $a $b
      term move ${a} ${b}
      term reset
      printf "█"
    done
    (( x++ ))
    sleep .5
  done

  h=( ${h} - 1)
  term move ${w} ${h}
}

## clean up terminal
cleanup

## exit
exit $?

