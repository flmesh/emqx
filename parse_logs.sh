docker-compose logs $@ --no-log-prefix emqx | awk '
/tag: AUTHZ/ {
  clientid = username = topic = reason = msg ""

  if (match($0, /clientid: [^,]+/)) {
    clientid = substr($0, RSTART + 10, RLENGTH - 10)
  }
  if (match($0, /username: [^,]+/)) {
    username = substr($0, RSTART + 10, RLENGTH - 10)
  }
  if (match($0, /topic: [^,]+/)) {
    topic = substr($0, RSTART + 7, RLENGTH - 7)
  }
  if (match($0, /reason: [^,]+/)) {
    reason = substr($0, RSTART + 8, RLENGTH - 8)
  }
  if (match($0, /msg: [^,]+/)) {
    msg = substr($0, RSTART + 5, RLENGTH - 5)
  }

  # combine intelligently
  if (msg != "" && reason != "") {
    event = msg " (" reason ")"
  } else if (msg != "") {
    event = msg
  } else if (reason != "") {
    event = reason
  } else {
    event = ""
  }

  if (event != "") {
    printf "clientid=%s username=%s topic=%s event=%s\n",
      clientid, username, topic, event
    fflush()
  }
}
'
