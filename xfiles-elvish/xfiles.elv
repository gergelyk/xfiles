#!/usr/bin/env elvish
use path
use str

fn is-atty []{ put ?(test -t 0) }

fn get-stdin-args []{
  if (is-atty) {
    put
  } else {
    cat
  }
}

fn normalize [path]{
  var path-expanded = $path
  var sep = '/'
  set parts = [(str:split $sep $path)]
  if (!=s '' $parts[0]) {
    if (==s '~' $parts[0][0]) {
      var home-expanded = (elvish -c 'echo '$parts[0] )
      var parts1 = $parts[1..]
      var parts-expanded = [$home-expanded $@parts1]
      set path-expanded = (str:join $sep $parts-expanded)
    }
  }
  set clean = (path:clean $path-expanded)
  set absolute = (path:abs $clean)
  put $absolute
}

fn unique [ei]{
  var eo = []
  for e $ei {
    if (not (has-value $eo $e)) {
      set eo = [$@eo $e]
    }
  }
  put $eo
}

fn Selection []{

  var storage = '/dev/shm'
  if (not (path:is-dir $storage)) {
    storage = '/tmp'
  }
  storage = $storage/xfiles

  var self = [
    &read-items~={ try { put (cat $storage 2> /dev/null ) } except { $self[clear~] } }
    &write-items~=[items]{ print (str:join "\n" $items) > $storage }
    &show~={ print (str:join "" [(put ($self[read-items~]) | each [line]{ put $line"\n" })]) }
    &show-path~={ echo $storage }
    &add~=[items]{
      var old-items = [($self[read-items~])]
      var all-items = [$@old-items $@items]
      var all-items-norm = [(each [x]{ normalize $x } $all-items)]
      var unique-items = (unique $all-items-norm)
      var nonempty-items = [(each [x]{ if (!=s $x '') { put $x } } $unique-items)]
      $self[write-items~] $nonempty-items
    }
    &remove~=[items]{
      var old-items = [($self[read-items~])]
      var nonempty-items = [(each [x]{ if (!=s $x '') { put $x } } $items)]
      var items-norm = [(each [x]{ normalize $x } $nonempty-items)]
      var all-items = [(each [x]{ if (not (has-value $items-norm $x)) { put $x } } $old-items)]
      $self[write-items~] $all-items
    }
    &clear~={ print "" > $storage }
  ]

  put $self
}

var selection = (Selection)
var stdin-args = [(get-stdin-args)]

if (< 0 (count $args)) {
  var cmd = $args[0]
  var cmd-args = $args[1..]
  if (== 0 (count $cmd-args)) {
    set cmd-args = $stdin-args
  }

  if (==s $cmd '+') {
    $selection[add~] $cmd-args
    $selection[show~]
  } elif (==s $cmd '-') {
    $selection[remove~] $cmd-args
    $selection[show~]
  } elif (==s $cmd '++') {
    $selection[show-path~]
  } elif (==s $cmd '--') {
    $selection[clear~]
  } else {
    $selection[clear~]
    $selection[add~] $args
    $selection[show~]
  }

} else {
  if (!= 0 (count $stdin-args)) {
    $selection[clear~]
    $selection[add~] $stdin-args
  }
  $selection[show~]
}
